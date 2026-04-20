# IP Address Value Type Memory Layout

<!--
---
version: 1.0.0
last_updated: 2026-04-20
status: RECOMMENDATION
tier: 2
scope: cross-layer
---
-->

## Context

Resolving [PLAT-ARCH-008e] Finding #17 (swift-kernel audit, 2026-04-20) uncovered
a cross-platform surface gap for `Kernel.Socket.Connect.connect(_:, address:)`:
the four typed-address overloads (`Storage+length`, `IPv4`, `IPv6`, `Unix`) are
declared in `swift-iso-9945` (L2 POSIX) and therefore absent on Windows. The
Windows path wraps raw `UnsafePointer<sockaddr>` instead, which is not an option
for the L3 unifier surface (unsafe API in public position is forbidden per the
ecosystem's safe-API rules).

The architectural fix discussed during remediation is to make the RFC value
types (`RFC_791.IPv4.Address`, `RFC_4291.IPv6.Address`) the portable currency:
each platform's L2 sockaddr wrapper (iso-9945 for POSIX, windows-standard for
Windows) accepts the RFC value and marshals it into the platform-native
`sockaddr_in` / `sockaddr_in6` / Windows equivalent.

A follow-up question arose: **should the RFC value types' memory layout be
aligned with POSIX `in_addr` / `in6_addr` to enable zero-copy unification**, or
should marshalling at the API boundary be accepted?

An empirical experiment (`swift-rfc-4291/Experiments/ipv6-address-alignment/`,
commit 44b326f) measured the current layouts:

| Type                       | Size | Alignment | Byte order |
|----------------------------|------|-----------|------------|
| `RFC_4291.IPv6.Address`    | 16   | 2         | host       |
| `in6_addr` (Darwin/Linux)  | 16   | 4         | network    |
| `RFC_791.IPv4.Address`     | 4    | 4         | host       |
| `in_addr` (Darwin/Linux)   | 4    | 4         | network    |

Direct reinterpret-cast from RFC → sockaddr is UB on little-endian hosts (wrong
byte order AND, for IPv6, insufficient alignment). Reverse direction (sockaddr
→ RFC) is safe alignment-wise for IPv6 but still wrong byte-order.

## Question

Should `RFC_791.IPv4.Address` and `RFC_4291.IPv6.Address` change their internal
storage to match POSIX `in_addr` / `in6_addr` memory layout — enabling
zero-copy reinterpret-cast at the sockaddr boundary — or should the RFC types'
storage be treated as an implementation detail and sockaddr marshalling be
accepted as the composition mechanism?

## Analysis

### Option A — Keep host-order storage; fix docstring; marshal at boundary

Current `RFC_791.IPv4.Address` stores `rawValue: UInt32` in host byte order.
The docstring incorrectly claims "network byte order" but the init code path
stores whatever integer the caller passed (e.g., `0xC0A80101` for 192.168.1.1
is stored numerically, giving bytes `01 01 a8 c0` on little-endian).
`RFC_4291.IPv6.Address` stores `segments: (UInt16 × 8)` — host-order, align 2.

Marshalling happens at the `Binary.Serializable.serialize(...)` boundary (and
would happen at any future iso-9945 / windows-standard boundary that
constructs a sockaddr from an RFC value).

- **Pros**: no RFC package changes; minimal churn; matches Rust's explicit
  choice (see Prior Art); conversion cost is negligible on non-hot paths.
- **Cons**: docstring inaccuracy remains unless separately fixed; marshalling
  required at every sockaddr boundary.

### Option B — Network-order storage, no layout-compat guarantee

Change the RFC types' internal storage to be network-order bytes (e.g., store
`_storage: UInt32` where `_storage = host.bigEndian`). Keep `rawValue` /
`segments` as **computed** accessors that return host-order values.

Size matches POSIX (4 / 16). Byte order matches POSIX (network). But alignment
of the Swift type's storage may or may not match `in_addr` / `in6_addr`
depending on chosen tuple types (e.g., `(UInt32 × 4)` backing would give
align 4 for IPv6).

This intermediate option captures "accurate docstring + network-order storage"
without formally promising memory layout equivalence. Reinterpret-cast would
be practically safe on surveyed platforms but not guaranteed by the RFC type's
public contract.

- **Pros**: docstring becomes accurate; serializer becomes a byte-copy
  (simpler); storage semantics match the name the RFC community uses.
- **Cons**: ABI break for the RFC packages (stored property → computed);
  makes layout compatibility "coincidental," which is worse than either
  "documented" (Option C) or "explicitly opaque" (Option A).

### Option C — Full layout compat with sockaddr (alignment, byte order, guarantee)

Same as Option B plus: the RFC types formally guarantee memory-layout
compatibility with `in_addr` / `in6_addr`. Callers are documented to rely on
this for reinterpret-cast / `withUnsafeBytes` patterns.

This enables iso-9945 / windows-standard to store the RFC value directly in
`sockaddr_in.sin_addr` without copying, and to return slices of `sin_addr` as
`RFC_791.IPv4.Address` via reinterpret.

- **Pros**: zero-copy unification across iso-9945 / windows-standard / RFC;
  syscall-boundary overhead eliminated entirely for the address-value portion
  of sockaddr construction.
- **Cons**: normative commitment to a specific layout, which the RFC
  community did not grant the Swift type author; ties the RFC value type's
  evolution to POSIX struct evolution (e.g., if `in6_addr` alignment changes
  on a future platform, the RFC type must follow); rejected as a goal by
  every major language surveyed.

### Prior Art

| Language | Type | Internal storage | Wire layout | POSIX-compat? |
|----------|------|------------------|-------------|---------------|
| Rust (post PR [#78802](https://github.com/rust-lang/rust/pull/78802)) | `std::net::Ipv4Addr` / `Ipv6Addr` | Opaque (private fields) | `octets()` → `[u8; 4]` / `[u8; 16]` (network order) | **Explicitly rejected** |
| Go | `net.IP` (pre-1.18) | `[]byte` slice (network order) | `[]byte` at any size | No — slice, not fixed struct |
| Go | `netip.Addr` (1.18+) | opaque, 128-bit packed repr | `As16()` / `As4()` network-order | No |
| .NET | `System.Net.IPAddress` | `long m_Address` (byte-reversed numeric → network-order bytes in little-endian memory) | `GetAddressBytes()` network-order | Partial (IPv4 only, implementation-internal) |
| Python | `ipaddress.IPv4Address` / `IPv6Address` | `_ip: int` (host-order Python int, variable-size) | `packed` → network-order bytes | No (Python int, not fixed-width) |
| Swift (current) | `RFC_791.IPv4.Address` / `RFC_4291.IPv6.Address` | Host-order UInt32 / (UInt16 × 8) | `Binary.Serializable.serialize` converts to network | No |

**The universal pattern**: every surveyed language exposes IP addresses via
fixed-width accessors (`octets()`, `GetAddressBytes()`, `packed`) that are
contractually network-order, while treating the INTERNAL storage as an
implementation detail. None guarantees layout compatibility with `in_addr` /
`in6_addr`.

**Rust's explicit rejection** ([PR #78802](https://github.com/rust-lang/rust/pull/78802))
is especially load-bearing. Rust's standard library originally WAS layout-compatible
with the C sockaddr family, then deliberately moved away. The maintainer's
argument on the PR — "conversion cost is negligible compared to syscall cost"
— is empirical: sockaddr marshalling happens at `connect` / `bind` / `accept`
(connection setup), never on the `read` / `write` data path. A few extra
cycles on a syscall that already costs thousands of cycles is unmeasurable.

The benefits Rust cited for breaking layout compat:
- enable migration to `core` (no C dependency),
- enable `const fn` on more methods,
- reduce memory footprint (`SocketAddrV4`: 16 → 6 bytes),
- enable structural equality.

These apply equally to the Swift RFC types.

**Python's outlier position** (host-order int) shows that even "implementation-
detail" storage is tolerable when the public accessor (`packed` bytes) is
contractually network-order. Python's design predates modern performance
concerns, but has not caused interoperability problems in practice.

### Contextualization step (per [RES-021])

Universal adoption of "network-order bytes via fixed-width accessor, opaque
storage" across 4/5 surveyed implementations (Python is the host-order
outlier) could be mistaken for "we must do this too." Contextualizing in the
Swift ecosystem's constraints:

- Swift has `MemoryLayout<T>` reflection, strong typed memory via
  `withUnsafeBytes` / `withMemoryRebound`, and `.bigEndian` / `.littleEndian`
  accessors on all integer types. Byte-order conversion is a single-instruction
  `bswap` on modern CPUs (negligible).
- Swift's `~Copyable` and strict memory safety conventions actively discourage
  layout-dependent code. Reinterpret-casts require `@unsafe` in strict-memory-safe
  modules, which is disallowed in public API per `feedback_no_unsafe_api_surface`.
- The Swift RFC packages are pre-1.0 and under single-author control. ABI
  commitments are not yet frozen.

The Swift ecosystem has NO structural reason to prefer layout compat that the
other surveyed languages had the opportunity to adopt and didn't. The arguments
for zero-copy layout compat are exactly those Rust considered and rejected.

### Performance consideration

Back-of-envelope: a `sockaddr_in` construction from an `RFC_791.IPv4.Address`
involves:
- one `UInt32` byte-swap (`bigEndian`) — ~1 cycle
- one memory assignment — ~1 cycle
- plus the fixed sockaddr_in struct initialization (family, port) — ~3 cycles

Total: ~5 cycles at the `connect` call site. A single `connect(2)` syscall is
~1000-10000 cycles (context switch + TCP handshake wait). The marshalling cost
is <0.1% of the syscall cost. **Zero-copy layout compat optimizes for a
negligible cost**.

### Docstring accuracy

Independent of the layout question, the current RFC docstrings are inaccurate:

```swift
// RFC_791.IPv4.Address:
/// The 32-bit address value in network byte order (big-endian)
public let rawValue: UInt32      // Actually stored in host order.

// RFC_4291.IPv6.Address:
/// Internally stored as eight UInt16 values in network byte order (big-endian).
public let segments: (UInt16, ...)   // Actually stored in host order.
```

Fixing the docstring is a separate, independently justifiable change (one-line
edit per type). It has no architectural implications and should happen
regardless of the layout decision.

### Comparison

| Criterion | A: host-order + docstring fix | B: network-order, no compat | C: full layout compat |
|-----------|------------------------------|----------------------------|-----------------------|
| Prior-art alignment | Rust, Python | .NET (partial), Go (by accident) | None surveyed |
| Perf win (sockaddr construction) | 0 cycles saved | 0 cycles saved | ~5 cycles saved (<0.1% of syscall cost) |
| Docstring accuracy | ✓ (after fix) | ✓ | ✓ |
| ABI change | No | Yes (stored → computed) | Yes (stored → computed) |
| Normative commitment to POSIX layout | No | No | **Yes** — RFC type ties to C ABI |
| Windows gap resolution | Via API-level marshal | Via API-level marshal | Via zero-copy reinterpret |
| Complexity | Minimal | Medium | Medium-high (layout tests, static asserts) |
| Reversibility | Trivial | Medium | Hard — consumers rely on layout |

### Constraints

- Rust has no layout stability for its IP types (opaque fields) and has
  survived fine. Other languages follow suit.
- The RFC specifications define wire format and semantics. They do NOT define
  in-memory layout of programming-language representations.
- Swift's `@unsafe` API discipline and strict memory safety make layout-
  dependent code harder to justify than in Rust (where `unsafe` is available
  in public API).
- Finding #17 and the future Socket.Accept/Send/Receive unifiers all need
  cross-platform typed overloads. The Windows gap is solvable by API-level
  composition regardless of layout choice.

## Outcome

**Status**: RECOMMENDATION

**Recommended**: Option A — keep host-order storage, fix the inaccurate
docstrings, use API-level composition for sockaddr construction.

**Rationale**:

1. **No performance motivation**. Marshalling cost is <0.1% of syscall cost.
   Rust evaluated this tradeoff empirically and rejected layout compat.
2. **No prior-art support**. Zero languages surveyed (Rust, Go, .NET, Python)
   guarantee POSIX layout compatibility for IP types. Rust actively moved
   AWAY from it. The "universal adoption" pattern here is AGAINST layout compat,
   not in favor of it.
3. **No RFC mandate**. The IETF specs define wire format; internal memory
   layout is an implementation choice.
4. **Architectural cost of normative commitment**. Option C ties the Swift RFC
   types to POSIX C struct evolution — a long-term coupling with no benefit.
5. **The Windows gap is solved anyway**. iso-9945 and windows-standard can
   both accept RFC values and marshal into their native sockaddr — API-level
   composition, which is what every surveyed language does.

**Implementation path** (for the Finding #17 follow-up work, not this research):

1. Fix RFC_791 and RFC_4291 docstrings: replace "in network byte order
   (big-endian)" with accurate "in host byte order; network-order bytes are
   produced by `Binary.Serializable.serialize` and `[UInt8](address)`". Cheap,
   independent PR.
2. Add `swift-rfc-791` and `swift-rfc-4291` as dependencies of `swift-iso-9945`
   (lateral L2-to-L2 dep, precedented by `swift-iso-9899`).
3. Add iso-9945 socket-endpoint inits that accept RFC values:
   `Kernel.Socket.Address.IPv4.init(address: RFC_791.IPv4.Address, port: UInt16)`
   etc. Marshal into `sockaddr_in.sin_addr.s_addr` via `.bigEndian`.
4. When addressing the future Windows unifier work: duplicate the same init
   pattern in windows-standard for Windows-native sockaddr.
5. Update the swift-kernel `Kernel.Socket.Connect+CrossPlatform.POSIX.swift`
   unifier (and the future Windows counterpart) to expose RFC-valued overloads:
   `Kernel.Socket.Connect.connect(_:, address: RFC_791.IPv4.Address, port: UInt16)`.

No changes to the RFC packages' storage are required or recommended.

**What would reopen this decision**:

- If a future hot-path use case emerges where sockaddr marshalling cost
  becomes measurable (e.g., a connectionless protocol that builds sockaddr per
  datagram) — revisit with benchmarks.
- If Swift's strict memory safety evolves to make reinterpret-cast trivially
  safe in public API (unlikely).
- If the RFC community starts mandating internal layout in implementation
  guidance documents (historically never).

## References

- [Rust PR #78802 — Implement network primitives with ideal Rust layout, not C system layout](https://github.com/rust-lang/rust/pull/78802)
- [Rust `Ipv4Addr` — core::net documentation](https://doc.rust-lang.org/stable/core/net/struct.Ipv4Addr.html)
- [Go `net.IP` — source](https://go.dev/src/net/ip.go)
- [Go `netip.Addr` — source](https://go.dev/src/net/netip/netip.go)
- [.NET `IPAddress` — runtime source](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Net.Primitives/src/System/Net/IPAddress.cs)
- [Python `ipaddress` — cpython source](https://github.com/python/cpython/blob/main/Lib/ipaddress.py)
- [RFC 791 — Internet Protocol (IPv4)](https://www.rfc-editor.org/rfc/rfc791.html)
- [RFC 4291 — IP Version 6 Addressing Architecture](https://www.rfc-editor.org/rfc/rfc4291.html)
- swift-rfc-4291 experiment: `Experiments/ipv6-address-alignment/` (commit 44b326f)
- swift-kernel audit: `swift-foundations/swift-kernel/Audits/audit.md` Finding #17 (resolved 6741b6a)
- Rust maintainer comment on conversion cost (PR #78802 discussion thread): marshalling cost "a tiny fraction of the time the entire syscall takes"
