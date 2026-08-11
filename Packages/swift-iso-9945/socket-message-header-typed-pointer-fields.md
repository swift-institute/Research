# Socket.Message.Header Typed Pointer-Field Wrappers Investigation

Date: 2026-04-22
Scope: package-local (`swift-iso-9945`); cross-reference to `swift-kernel-primitives` and `swift-foundations/swift-sockets` for consumer context
Audit finding: P2.4 #8 — `Kernel.Socket.Message.Header.{Name, Vectors, Control}` expose `pointer: UnsafeMutableRawPointer?` + length fields; should wrap in typed ecosystem types per [PLAT-ARCH-005a].
Status: **OPTIONS MATRIX — decision escalates to principal**

This document surveys options for resolving the raw-pointer leak in the three sub-structs of `Kernel.Socket.Message.Header`. It does not commit a decision; each recommendation below names what remains for the principal.

## Problem Statement

`swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Socket/ISO 9945.Kernel.Socket.Message.Header.swift:18` defines `Kernel.Socket.Message.Header` — an L2 binary-compatible wrapper around POSIX `struct msghdr`. It exposes three sub-struct types as its typed field surface:

- **`Header.Name`** at `.Message.Header.Name.swift:5` — socket-address descriptor, fields `pointer: UnsafeMutableRawPointer?` + `length: UInt32`.
- **`Header.Vectors`** at `.Message.Header.Vectors.swift:8` — scatter/gather I/O vector descriptor, fields `pointer: UnsafeMutableRawPointer?` + `count: Int`.
- **`Header.Control`** at `.Message.Header.Control.swift:5` — ancillary data descriptor, fields `pointer: UnsafeMutableRawPointer?` + `length: Int`.

Per [PLAT-ARCH-005a] "No Platform C Types in Public API", raw `UnsafeMutableRawPointer?` is a C-layer leak in a public L2 API. The audit's finding #8 asks: *"wrap `pointer: UnsafeMutableRawPointer?` + length fields in typed ecosystem types."* The finding's `Recommended structural fix` elaborates: *"wrap iovec tuples in `Kernel.IO.Vector.Segment` (type already exists per file listing); wrap msghdr pointer+length fields in typed ecosystem types."*

The finding is silent on exactly WHAT typed ecosystem types to use for each slot (one candidate exists for Vectors; Name has a candidate; Control has no pre-existing ecosystem type). The silence is the design space.

## Constraints Inventory

1. **`Kernel.Socket.Message.Header` is L2-defined (not L1).** `rg "public struct Header" swift-kernel-primitives` returns nothing; the only `Header` definition in the ecosystem is at `swift-iso-9945/Sources/ISO 9945 Kernel Socket/ISO 9945.Kernel.Socket.Message.Header.swift:18`. This differs materially from Doc 1 (File.Handle was L1) — Doc 1's "method-level split" option (Option 5) derived its elegance from the L1 type being cross-layer-visible; here, any L3-facing reshape has to either export across the layer boundary or accept that Header is exclusively an L2 surface.

2. **`msghdr` is borrowed storage, not owned.** The C contract: the user allocates storage for the socket address, iovec array, and control buffer; fills in msghdr's pointers; calls sendmsg/recvmsg. msghdr does NOT own those buffers. Any Swift wrapper must preserve this: the Header is a *descriptor*, not a container. Wrapping "pointer" as an owned typed value (e.g., `Kernel.Socket.Address.Storage` — which owns a `sockaddr_storage` by value) changes the ownership semantics and would require copy-in/copy-out at the syscall boundary.

3. **`Kernel.IO.Vector.Segment` already exists** at `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel File/ISO 9945.Kernel.IO.Vector.Segment.swift:38` — the natural "typed iovec" ecosystem type. Its own shape is `base: UnsafeMutableRawPointer? + length: Int` (identical to `Header.Vectors`'s shape, just renamed fields) with `@unsafe init`. Binary-compatible with `iovec`. This tells us: the ecosystem's existing answer to "typed pointer+length" is to keep the raw pointer but put a type around it and mark `@unsafe`. The audit's implicit endorsement ("type already exists per file listing") supports wrapping Vectors in `[Kernel.IO.Vector.Segment]` — but that wrap is descriptor-style, not pointer-type-narrowing.

4. **`Kernel.Socket.Address.Storage` exists** at `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Socket Address/ISO 9945.Kernel.Socket.Address.Storage.swift:17` as the typed cross-family sockaddr wrapper (holds `sockaddr_storage` by value; has `.family` accessor). It is the natural typed candidate for Name's `pointer` slot, but Storage is *owned* — its cValue is a member, not a pointer — which creates the Constraint 2 ownership mismatch.

5. **No typed control-message wrapper exists in the ecosystem.** `rg "struct .*Control|cmsghdr|ControlMessage"` across swift-kernel-primitives + iso-9945 returns nothing for cmsghdr. The audit's ask implicitly requires inventing one.

6. **swift-sockets' consumption is shallow.** `swift-foundations/swift-sockets/Sources/Sockets/Kernel.Socket.Send+CrossPlatform.POSIX.swift:105` and `.Receive+CrossPlatform.POSIX.swift:97` pass Header through by `inout` to the L3 unifier. swift-sockets does not touch the sub-struct fields; it's a conduit. Consumers BEYOND swift-sockets (higher-level socket libraries that use sendmsg/recvmsg for ancillary data like file descriptors over UNIX sockets, multicast source control, etc.) would be the ones feeling the sub-struct shape most — but those consumers aren't in this workspace to survey. Assumption: external consumers exist but are not currently identifiable.

7. **Finding #9 (sibling) already RESOLVED**: `Message.Header.flags: Int32` → `Kernel.Socket.Message.Options` typed OptionSet (swift-iso-9945 `e554f7a`, RESOLVED 2026-04-21 per the platform audit tracker). Precedent: Header's int fields are typeable via OptionSet without breaking msghdr binary compatibility. The pointer fields are structurally different — pointers can be typed-wrapped without layout break only if the wrapper itself remains pointer-layout-equivalent (see Option 1) or if layout equivalence is abandoned (see Options 3, 5).

8. **`@unchecked Sendable` on Header.** Header is `@unchecked Sendable` because it embeds `msghdr` (a C struct with raw pointers). Any typed-wrapping design that adds Swift reference/collection types to Header's field surface has to re-verify Sendable carefully — collections of typed wrappers must be Sendable themselves, and the "no ownership of pointed-to storage" invariant must still hold.

## Options Matrix

Five options. All three handoff-implicit options ("leave as-is", "wrap pointer in typed ecosystem type", "go full scope-based") plus two non-obvious candidates surfaced by pushing past the parent-handoff framing per principal's Doc 2 guidance.

### Option 1: Typed-container wrap in place (descriptor-style, matches Vector.Segment)

**Shape**: Keep `Header.Name`, `Header.Vectors`, `Header.Control` as sub-struct types. Replace each `pointer: UnsafeMutableRawPointer?` with a typed pointer, and mark the init + any mutation `@unsafe`:

```swift
// Name — typed pointer to sockaddr-family via Kernel.Socket.Address.Storage
public struct Name: @unchecked Sendable {
    @unsafe public var pointer: UnsafeMutablePointer<Kernel.Socket.Address.Storage>?
    public var length: UInt32
    @unsafe public init(pointer: UnsafeMutablePointer<Kernel.Socket.Address.Storage>? = nil, length: UInt32 = 0) { … }
}

// Vectors — typed pointer to Kernel.IO.Vector.Segment array
public struct Vectors: @unchecked Sendable {
    @unsafe public var pointer: UnsafeMutablePointer<Kernel.IO.Vector.Segment>?
    public var count: Int
    …
}

// Control — new typed opaque
public struct Control: @unchecked Sendable {
    @unsafe public var pointer: UnsafeMutableRawPointer?  // stays raw; no typed ecosystem partner
    public var length: Int
    …
}
```

**Middle-ground typing for Control's pointer (added after principal review)**: `UnsafeMutableRawBufferPointer?` is a stdlib-typed wrapper that carries `baseAddress` + `count` in a single value, preserves borrowed-storage semantics, and is strictly a refinement of the current `UnsafeMutableRawPointer? + length: Int` shape. It is not a typed *cmsghdr* wrapper (cmsghdr chain iteration per [CMSG_NXTHDR] requires dedicated design — see Open Question #3), but it IS a net-positive typing move that removes the separate-length-field surface and aligns with the principal's "move away from pointer code in favor of Span / stdlib buffer types" direction. Its caveat: `Span<UInt8>` would be even more modern, but `Span` is `~Escapable` and msghdr's borrowed-storage semantics require the Control slot to hold a value that can be constructed outside the syscall scope — `Span`'s lifetime constraints don't fit the descriptor-style use case. `UnsafeMutableRawBufferPointer?` is the correct compromise: stdlib-typed, length-carrying, scope-agnostic. Applying this to Name's sockaddr slot is the same call: `UnsafeMutableRawBufferPointer?` for the raw sockaddr memory, with the family discriminator read separately. Refined Refined Option 1' adopts this (see Recommendation).

**Pros**:
- Smallest delta from current code; binary layout preserved.
- Uses existing ecosystem types (Storage, Vector.Segment) where they fit.
- `@unsafe` markers signal the raw-memory boundary without reshaping the API.

**Cons**:
- Name's `UnsafeMutablePointer<Storage>` is a lie about ownership — msghdr's `msg_name` points to user-allocated memory that's typically a `sockaddr_in` or `sockaddr_in6`, not a `sockaddr_storage` by value. Reinterpreting that memory as `Storage*` can be layout-incompatible (Storage is `sockaddr_storage` — 128 bytes — whereas `sockaddr_in` is 16 bytes). The typed wrap is MISLEADING here.
- Control stays raw because no typed partner exists; the finding is only 2/3 addressed.
- Doesn't address the audit's deeper ask (finding says "wrap pointer+length in typed ecosystem types" — in place typed pointers are a wrap, but the pointer-length *pair* remains the public contract).

**Consumer impact**: Minor; in-ecosystem consumers that construct Header manually must cast their `sockaddr_in` pointers to `Storage*` (unsound layout-wise — see cons). External consumers likely broken.

### Option 2: Accessor-level replacement on Header (drop sub-struct types)

**Shape**: Delete `Header.Name`, `Header.Vectors`, `Header.Control` sub-struct types. Replace Header's accessors with typed-direct:

```swift
extension Kernel.Socket.Message.Header {
    // Owned typed address, copy-in/out to/from msghdr.msg_name
    public var address: Kernel.Socket.Address.Storage? {
        get { … unsafe read msg_name as sockaddr_storage; return Storage or nil … }
        set { … allocate + copy into an internal backing store; wire msg_name … }
    }

    public var vectors: [Kernel.IO.Vector.Segment] {
        get { … rehydrate from msg_iov + msg_iovlen … }
        set { … backing-store array; wire msg_iov + msg_iovlen … }
    }

    // Control stays — no typed ecosystem partner
    public var control: Control  // or similar compromise
}
```

Header would need private backing storage (`_addressBacking: Kernel.Socket.Address.Storage?`, `_vectorsBacking: [Kernel.IO.Vector.Segment]`) to own the memory that msg_name/msg_iov point at.

**Pros**:
- Eliminates the raw-pointer public surface for Name and Vectors — consumers set typed values; Header manages pointer wiring internally.
- Removes three sub-struct types from the public API (simplification).
- Maps naturally onto how Swift code would want to build a message: typed addresses, typed vector arrays.

**Cons**:
- Changes Header's fundamental semantics from *descriptor* to *owner*. The ownership shift (Constraint 2) is non-trivial: Header now allocates and copies; it's no longer pointer-equivalent to msghdr.
- Performance cost: copy-in/out on every access; allocation on mutation.
- Header is `@unchecked Sendable`; adding collection-typed backing storage forces re-verification of the Sendable contract (arrays of `Kernel.IO.Vector.Segment` are mutable; `@unchecked` is load-bearing).
- Control still escapes the typed wrap.
- Existing consumers that relied on descriptor semantics (set pointer to external buffer, call syscall) break; their borrowing-memory pattern no longer fits.

**Consumer impact**: High — descriptor-pattern consumers must restructure to owning-pattern.

### Option 3: L2 keeps raw sub-structs `@_spi(Syscall)`; L3 adds a typed construction API

**Shape** (method-level split, mirroring Doc 1's Option 5 adapted for a non-L1 type):
- L2 iso-9945: demote `Header.Name`, `Header.Vectors`, `Header.Control` and their pointer fields to `@_spi(Syscall)`. Header struct itself stays public; raw access is SPI.
- L3 swift-posix (or a new target): add typed-construction API. Two sub-options:
  - **3a — scope-based**: `POSIX.Kernel.Socket.Message.withHeader(address:..., vectors:..., control:...) { header throws(E) in … syscall(header) }`. Header never leaves the scope; typed inputs are converted to msghdr pointers internally.
  - **3b — typed accessor extension**: extensions on `Kernel.Socket.Message.Header` in swift-posix that set typed values via SPI pointer-manipulation. Consumer-facing get/set is typed; the SPI is hidden.

**Pros**:
- Strongest layer split: L2 is spec-literal msghdr, L3 is typed consumer API. Matches [PLAT-ARCH-008e] directly.
- No change to binary compatibility of L2 Header.
- SPI demotion signals "this is low-level syscall contract; use L3 for typed access."
- 3a specifically: scope ownership enforces msghdr's borrowed-storage semantics at the type level — Header can't outlive its typed inputs.

**Cons**:
- Cascade identical to P3.3 iso-9945 #10 (Socket.Address.Storage SPI demotion): the SPI gate on Header propagates through the re-export chain (`ISO_9945_Kernel_Socket` → `POSIX_Kernel_Socket` → `Kernel_Core` → `Kernel`), requiring `@_spi(Syscall) @_exported public import` upgrades at multiple hops. Prior Doc 1 work flagged this as a ~13-file cascade.
- **`@inlinable` incompatibility risk — potentially blocking** (elevated after principal review): if the current socket-side L3 unifiers `POSIX.Kernel.Socket.Send.message` / `Receive.message` (or their `Kernel.Socket.*.message` cross-platform delegates) are marked `@inlinable` (they likely are, by analogy with `Kernel.IO.Write.writeAll`'s `@inlinable` precedent), then SPI-gating `Kernel.Socket.Message.Header`'s sub-structs triggers exactly the trap documented in `Research/Reflections/2026-04-20-file-system-typed-path-and-l2-l3-io-ambiguity.md`: `@inlinable` function bodies cannot reference `@_spi` symbols from another module. The Read/Write family hit this wall after attempting `@_spi(Syscall)` on L2 raw and had to abandon the workaround; Option 3 risks the same outcome for Header. **This is not a minor implementation detail — it could rule out Option 3 after a cascade is half-built.** An implementation-cycle pre-check (try the `@_spi` demotion on a minimal Header subset and observe whether the L3 unifier builds) is mandatory before committing to Option 3 as a multi-package cycle.
- Adds a new L3 API surface (new files in swift-posix, or a new target); bigger scope than options 1, 2, 4.
- **3a-specific caveat**: the `withHeader(...)` scope-based construction API conflicts with the ecosystem direction captured in `feedback_escapable_over_with_closures` ("Don't add with* APIs; use ~Escapable — current infrastructure, not future"). Option 3b (typed accessor extension) avoids this. Option 5's ~Escapable pattern is the principled shape if scope-based lifetime safety is desired. Don't pick 3a without explicitly authorizing a deviation from this ecosystem feedback.

**Consumer impact**: Low for consumers using the L3 typed API. High for any current consumer that directly accessed the L2 sub-structs — they'd need `@_spi(Syscall)` import OR migrate to the L3 typed API.

### Option 4: Accept current state as the ecosystem's answer; close the finding with a codified explanation

**Shape**: No code change. Update `Header.Name/Vectors/Control` docs to explicitly state: "These are descriptor-style typed wrappers following the `Kernel.IO.Vector.Segment` pattern — the pointer-length pair IS the typing. Platform C types are not exposed because the sub-struct is the type; the pointer within is an `UnsafeMutableRawPointer?`, a Swift stdlib type, not a C `void*`." Add a cross-reference to Vector.Segment establishing this as the ecosystem's intentional choice for descriptor-style typed wrappers.

Additionally: codify the pattern in a [PLAT-ARCH-005a] clarification sub-rule: "descriptor-style typed wrappers (a struct wrapping `UnsafeMutableRawPointer?` + length for kernel ABI compatibility) satisfy [PLAT-ARCH-005a] if and only if the struct itself is ecosystem-typed and marked with `@unsafe` initializer."

**Pros**:
- Zero code disruption.
- Honest: the sub-structs ARE the typing in the descriptor-style idiom the ecosystem has adopted (Vector.Segment shares this exact shape).
- Codifies the pattern so future audits don't re-open this finding.

**Cons**:
- Defends current state; audit's finding stands as "not fixed" in spirit — the audit's `pointer: UnsafeMutableRawPointer?` callout is ratified, not addressed.
- The descriptor-style idiom is a weak interpretation of [PLAT-ARCH-005a]. [PLAT-ARCH-005a]'s stated decision test is: *"Can a consumer of this API write their code without importing the platform's C module?"* For Header.Name/Vectors/Control, a consumer can write code without importing Darwin/Glibc directly — the `UnsafeMutableRawPointer?` is stdlib. So Option 4 may be technically compliant already. Principal judgment call: is "doesn't import Darwin/Glibc" sufficient, or does [PLAT-ARCH-005a] ALSO want "doesn't expose raw pointers"?
- Control's pointer is still untyped in the sense that no ecosystem type describes what's at the other end; the documentation-only fix glosses this.

**Consumer impact**: Zero.

### Option 5: Replace sub-structs with `~Escapable` scoped views + L2 SPI

**Shape** (lifetime-safe, farther-reaching than Option 3):
- Introduce `~Escapable` typed views on each pointer slot:
  - `Header.Name.View` — `~Escapable`, lifetime-bound to a source `Kernel.Socket.Address.Storage`.
  - `Header.Vectors.View` — `~Escapable`, lifetime-bound to an `UnsafeBufferPointer<Kernel.IO.Vector.Segment>`.
  - `Header.Control.View` — `~Escapable`, lifetime-bound to an `UnsafeRawBufferPointer`.
- The raw Header struct becomes SPI; typed construction goes through `withHeader` closures that produce ~Escapable sub-views and the Header itself is ~Escapable for the duration of the syscall.
- Compile-time enforcement that msghdr pointers cannot outlive their source storage.

**Pros**:
- Strongest lifetime safety: the borrowed-storage semantics of msghdr become a compile-time invariant, not a discipline.
- Closes the raw-pointer leak completely — consumers don't see `UnsafeMutableRawPointer?` anywhere.
- Aligns with the ecosystem's broader push toward ~Escapable views for descriptor-style wrappers (Path.View, Span precedents).

**Cons**:
- Largest scope: new ~Escapable types + new L3 construction API + L2 SPI demotion + re-export-chain `@_spi` cascade.
- ~Escapable ecosystem tooling is still maturing; known gaps (`@_lifetime(&self)` + Escapable-result rule tightening on Swift 6.3 per memory records). Risk that the design hits compiler limitations.
- Performance overhead of the `withHeader` closure + view construction per syscall.
- Doc 1's Option 5 was a 1-file additive change; this is an ecosystem-shifting API redesign. Wrong mass for a P2 audit-finding remediation.

**Consumer impact**: Very high — all existing consumers migrate from raw pointer-descriptor to scoped-view construction.

## Evidence

### Grep results — prior research per [HANDOFF-013a]

```
$ rg -l "Message.Header|msghdr|Vectors|Control" swift-iso/swift-iso-9945/Research/
iso-9945-spec-coverage-gap-analysis.md     ← spec-coverage migration context; no typed-wrapper design discussion
system-decomposition.md                     ← target-boundary context, not API-shape
iso-9945-kernel-modularization.md           ← target-boundary context, not API-shape

$ rg -l "Message.Header|msghdr|Vectors|Control" swift-foundations/swift-sockets/Research/
(swift-sockets has no Research/ directory; the 2 Sockets/ hits are source files, not docs)

$ rg -l "msghdr|Message.Header|Vectors|ControlMessage" swift-institute/Research/
file-handle-writeall-l2-l3-layering.md     ← Doc 1 (self-hit, skip)
unified-geometry-types-research.md          ← checked, not materially relevant (Vectors as geometry, not socket)
Reflections/2026-04-12-iso-9945-posix-gap-analysis-and-implementation.md   ← migration history; no typed-wrapper design
Reflections/2026-04-12-io-uring-escapable-coroutine-discovery.md          ← ~Escapable context for Option 5 only
io-prior-art-per-system-reference.md        ← cross-system reference, no msghdr typed-wrapper convention
```

Prior research contains migration history (Message.Header moved FROM Linux Kernel Socket Standard TO iso-9945) and spec-coverage tracking, but no design-space discussion of typed pointer-field wrappers. This finding's design space is unexplored prior art; the options matrix is the first systematic survey.

### Current-state code citations

- Header definition: `ISO 9945.Kernel.Socket.Message.Header.swift:18` (`@unchecked Sendable` wrapping `cValue: msghdr`).
- Sub-struct definitions: `.Message.Header.Name.swift:5`, `.Message.Header.Vectors.swift:8`, `.Message.Header.Control.swift:5` — all `@unchecked Sendable`, all pointer+length fields.
- Parallel typed iovec: `ISO 9945.Kernel.IO.Vector.Segment.swift:38` — same pointer+length shape, `@unsafe init`, binary-compatible with iovec.
- Parallel typed sockaddr: `ISO 9945.Kernel.Socket.Address.Storage.swift:17` — owned `sockaddr_storage`, not pointer-style.
- swift-sockets consumption: `Kernel.Socket.Send+CrossPlatform.POSIX.swift:105`, `Kernel.Socket.Receive+CrossPlatform.POSIX.swift:97` — `inout Kernel.Socket.Message.Header`, passthrough only.
- Audit P2.4 #8: `swift-institute/Audits/platform-compliance-2026-04-21.md:96` (Pattern 2 evidence), `:304` (P2.4 finding listing).

### L1/L2/L3 type-location diagnostic (Doc 2 pattern)

Per Doc 1's forward-looking guidance, ran `rg "public struct Header|public enum Header" swift-primitives/swift-kernel-primitives/Sources` — zero hits. Confirms `Message.Header` is L2-exclusive. This is different from File.Handle (L1) and means the "L1 type + L2/L3 method-level split" pattern from Doc 1 does NOT apply here; Header's options are constrained to L2-internal changes or cross-layer API additions.

## Recommendation

**Option 1 (typed-container wrap in place) with a caveat → likely escalate to Option 3 (L3 typed construction API) if the `@unsafe` descriptor-style wrap is judged insufficient.**

Reasoning:
- The ecosystem's existing answer for "typed descriptor-style wrapper" is Kernel.IO.Vector.Segment. Applying the same pattern to Header.Name/Vectors/Control is structurally consistent. Option 1 is the narrowest code change that keeps Header binary-compatible with msghdr while moving the raw-pointer surface under typed wrappers and `@unsafe` initializers.
- Option 2 (owner-semantics on Header) is rejected because it breaks the borrowed-storage invariant (Constraint 2) — msghdr IS a pointer-to-external-storage descriptor, and making Header own a backing address/vector collection is a semantic change, not a typing change.
- Option 4 (codify current state) is a live alternative IF the principal judges [PLAT-ARCH-005a] as satisfied by "struct wrapping `UnsafeMutableRawPointer?` + length is typed ecosystem-native." Principal decision needed.
- Option 3 (L2 SPI + L3 typed construction) is the right answer if the principal judges that [PLAT-ARCH-005a]'s goal is to eliminate raw pointers entirely (not just keep them within typed wrappers). It is a cascade-scoped remediation comparable to P3.3 iso-9945 #10's SPI half — `@_spi` re-export propagation through ~13 files across 4 packages. If pursued, it should be paired with P3.3 #10's SPI work as a unified L2-socket-SPI-demotion cycle rather than as isolated per-finding cascades.
- Option 5 (~Escapable scoped views) is architecturally appealing but the scope mass (new ~Escapable types + new L3 API + SPI cascade + compiler-limitation risk) is wrong for a P2 remediation. Defer as a possible post-completion polish cycle.

**Caveat on Option 1's Name.pointer**: typed pointer `UnsafeMutablePointer<Kernel.Socket.Address.Storage>?` is layout-unsound because msg_name typically points to a `sockaddr_in` / `sockaddr_in6` (16 / 28 bytes) rather than `sockaddr_storage` (128 bytes). Consumers would cast, and the cast is valid because sockaddr_storage is designed to be interpretable-as-any-family. But the type claim reads stronger than it is. Alternative: leave Name's pointer as `UnsafeMutableRawPointer?` (still wrapped in the typed Name struct, which is what the ecosystem considers "typed"). The wrap is then semantically: *"this struct IS the type; the untyped pointer inside is irreducible because sendmsg accepts any sockaddr-family."* That matches Vector.Segment's precedent (Vector.Segment.base is `UnsafeMutableRawPointer?`, not typed to a specific buffer element).

**Refined Option 1' (second revision, after principal review)**:
- **Vectors.pointer** → `UnsafeMutablePointer<Kernel.IO.Vector.Segment>?` (iovec layout has fixed stride; typed-pointer contract satisfied; closes Vectors cleanly).
- **Name.pointer** → stays `UnsafeMutableRawPointer?` (msg_name can point at `sockaddr_in` / `sockaddr_in6` / `sockaddr_un` with varying strides; `UnsafeMutablePointer<Storage>` over a 16-byte allocation is genuine Swift UB because typed-pointer deref assumes stride-equal memory). The Name struct's typed identity IS the wrapper per Vector.Segment precedent.
- **Control.pointer + length** → collapse to `UnsafeMutableRawBufferPointer?` (stdlib-typed, length-in-type, preserves borrowed-storage semantics, aligns with the "move away from pointer code in favor of Span / stdlib buffer types" direction). This is strictly better than `UnsafeMutableRawPointer? + length: Int` — fewer fields, same layout, no need for cmsghdr design. `Span<UInt8>` would be the most modern choice but `Span` is `~Escapable` and msghdr-descriptor semantics require a value that can be constructed outside a specific scope; `UnsafeMutableRawBufferPointer?` is the correct compromise.

**Structural re-weighting (after principal review — Constraint #5 impact)**: Refined Option 1' closes Vectors fully (typed pointer) and Control substantially (single-field stdlib-typed buffer pointer). Name's raw-pointer retention is load-bearing (any typed alternative would be unsound). This is best described as a **partial close**, not a full close — the audit finding's surface-level ask ("wrap all three in typed ecosystem types") is only 2/3 satisfied because Name's typing is constrained by layout-soundness. Framing this honestly in the tracker preserves future-audit legibility: Name's typing can be re-opened if/when the ecosystem designs a family-discriminated typed sockaddr view. Control's typing can be sharpened further in a cmsghdr-design cycle (Open Question #3). Full close would require either Option 4 ratification or the cmsghdr-design cycle plus a family-discriminator solution for Name.

## Open Questions (escalating to principal)

1. **Primary decision**: approve Option 1' (narrow typed-pointer wrap on Vectors only; keep Name/Control pointer shape with codified rationale) OR Option 3 (L2 SPI + L3 typed construction API, ~13-file cascade comparable to P3.3 #10)? Option 1' is the minimum-change path consistent with ecosystem precedent; Option 3 is the strict-[PLAT-ARCH-005a] path with significant scope. Options 2, 4, 5 are rejected above with reasons.

2. **[PLAT-ARCH-005a] interpretation**: does the rule's text — *"public APIs MUST NOT expose C types in parameters, return types, associated types, or generic constraints"* — consider `UnsafeMutableRawPointer?` a "C type"? It's a Swift stdlib type, not imported from Darwin/Glibc, but semantically it is the raw-pointer C primitive. The options matrix's split between Options 1/4 (treat as compliant) and Option 3/5 (treat as non-compliant) turns on this interpretation. Principal's ruling binds future audit interpretations of the rule.

3. **Cmsghdr/Control typed wrapper design** (Option 3-conditional): no ecosystem type currently exists for typed ancillary-data buffers. POSIX `cmsghdr` is a variable-length structure (header + data) chained via `CMSG_NXTHDR`. A typed wrapper would need to represent this chain — either as `[Kernel.Socket.Control.Message]` (owned, copy-in/out) or as a scoped view. Does the principal want this designed in a subsequent cycle (blocking Option 3's full completion), or can Option 3 land Name/Vectors with Control documented as "pending typed-cmsghdr design"?

4. **Coordination with P3.3 iso-9945 #10 SPI cascade** (Option 3-conditional): if Option 3 is chosen, the `@_spi(Syscall)` re-export propagation required for Message.Header's sub-structs is the same cascade required for `Kernel.Socket.Address.Storage.withUnsafe[Mutable]Bytes` (P3.3 #10's deferred SPI half). Does the principal want these bundled as a single L2-socket-SPI-demotion cycle (landed together in one implementation slot), or as sequential cycles?

5. **Constraint mismatch evidence — layout soundness of `UnsafeMutablePointer<Kernel.Socket.Address.Storage>` for `msg_name`**: the Doc notes this is "unsound" because real msg_name allocations are typically `sockaddr_in`/`sockaddr_in6` (not `sockaddr_storage`). In practice, C APIs cast `(struct sockaddr *)` to/from family-specific sockaddr pointers and this is standard POSIX idiom. Is the concern load-bearing in Swift — does `UnsafeMutablePointer<Storage>` promise size-equal-to-Storage memory access on deref? Needs a compiler/type-system investigation or a minimal-experiment. Flagged as an implementation-cycle pre-check; does the principal want this investigation blocking the decision, or is "document as an open concern, ship Option 1' with Name's pointer staying `UnsafeMutableRawPointer?`" acceptable?

6. **Drive-by observation — Refined Option 1' leaves Control untyped**: the finding's wording ("wrap [all three] in typed ecosystem types") isn't fully satisfied. Does the principal view Refined Option 1' as "full close" (Control's typing is out of scope because no ecosystem type exists) or "partial close" (Control's typing is pending a future cycle that designs `Kernel.Socket.Control.Buffer`)? Tracker-note framing depends on the answer.

## Appendix — [SUPER-015] tactical decisions made during investigation

- Ran the L1-vs-L2 type-location diagnostic per principal's Doc 2 guidance; confirmed Header is L2-exclusive. Recorded as Constraint #1 because it MATERIALLY limits the option space (no Doc 1-Option-5 analog is available).
- Checked swift-sockets/Research/ per guidance; confirmed no such directory exists. Substituted direct grep of swift-sockets/Sources/ for consumer-side context.
- Pushed past the parent handoff's implicit 2-option framing ("wrap or leave alone") per principal's guidance; surfaced Options 2 (accessor-level replacement), 3 (L3 typed-construction API), 5 (~Escapable views) as non-obvious additions.
- Introduced "Refined Option 1'" to acknowledge that Option 1's Name-slot typed pointer is layout-unsound; chose to surface this in the Recommendation section rather than bury it, because the refinement is load-bearing for whether Option 1 is viable at all.
- Did NOT investigate the cmsghdr typed-wrapper design space in this doc (flagged as Open Question #3); the design would materially expand Doc 2's scope and is parallel to the "add typed-accessors" scope expansion the principal rejected during Doc 1 supervise.
- Did NOT run a consumer grep across the full ecosystem for direct usages of `Header.Name/Vectors/Control` field access (beyond swift-sockets); flagged as an implementation-cycle pre-check. Unlike Doc 1, the Headercase likely has more varied consumers (sendmsg/recvmsg is a standard idiom for ancillary data use cases), but the options matrix is decidable without the exact call-site enumeration.

## Principal Decisions (2026-04-22)

Principal reviewed Doc 2 after `88e5c57` landed; decisions on the 6 escalated open questions recorded here as the durable artifact. Decisions are binding on any implementation-cycle supervise block that carries forward this investigation.

| # | Question | Decision | Rationale (principal's words, compressed) |
|---|----------|----------|-------------------------------------------|
| 1 | Option 1' vs Option 3 vs Option 4 (primary) | **Refined Option 1' as primary**, with Q6 framed as partial close. | Vectors gets typed (Vector.Segment precedent applies cleanly); Name keeps `UnsafeMutableRawPointer?` under the "struct IS the typing" interpretation (because typed alternatives are layout-unsound — see Q5); Control collapses `pointer + length` to `UnsafeMutableRawBufferPointer?` (addresses weakness #1; aligns with the stdlib-buffer-over-raw-pointer direction). Option 3 is the fallback only if Q2 rules `UnsafeMutableRawPointer?` non-compliant. Option 4 is defensible for zero-code-change but the stdlib-buffer collapse for Control and the Vectors typing are both net positives worth landing. |
| 2 | [PLAT-ARCH-005a] — is `UnsafeMutableRawPointer?` a "C type"? | **Compliant when wrapped in an ecosystem-typed struct with `@unsafe` init.** | The rule's decision test is "can a consumer write code without importing Darwin/Glibc?" — `UnsafeMutableRawPointer?` is stdlib, doesn't force platform imports. The spirit ("typed wrappers over raw representations") is satisfied at the struct level (the sub-struct IS the typed wrapper); the pointer field inside is an implementation detail of descriptor-style wrappers. `Kernel.IO.Vector.Segment` is the established precedent. Non-compliant when `UnsafeMutableRawPointer?` appears directly as a function parameter or return type without a struct wrap — that is what [PLAT-ARCH-005a] Pattern 2 was actually catching. **Principal authorized codifying this as a [PLAT-ARCH-005a] clarifying sub-rule in the audit tracker to prevent future re-opens.** |
| 3 | cmsghdr / Control typed wrapper design | **Defer to a dedicated future cycle.** | Scope comparable to the typed-accessor design deferred in Doc 1. Cmsghdr's variable-length chain-iteration semantics (CMSG_NXTHDR / CMSG_DATA) require a dedicated design pass — either `[Kernel.Socket.Control.Message]` owned array or a `~Escapable` cursor view, each with its own trade-offs. **Do NOT block Refined Option 1' on this; do NOT bundle with the current remediation.** The `UnsafeMutableRawBufferPointer?` intermediate typing closes enough of the surface gap to ratify Refined Option 1'. |
| 4 | Bundling with P3.3 iso-9945 #10 SPI half | **If Option 3 had been chosen: YES, bundle. But Refined Option 1' avoids the cascade entirely, so Q4 is moot for the current cycle.** | Splitting Option 3 into two sequential cycles doubles the risk surface; bundling is the only sensible move IF Option 3 is chosen at all. |
| 5 | Layout soundness of `UnsafeMutablePointer<Storage>` for `msg_name` | **Load-bearing. Do NOT type Name's pointer.** | `MemoryLayout<sockaddr_storage>.stride = 128`; `MemoryLayout<sockaddr_in>.stride = 16`. `withMemoryRebound(to: sockaddr_storage.self, capacity: 1)` over a 16-byte allocation is UB. Swift's typed-pointer contract requires size-stride parity. C's `(struct sockaddr *)` cast idiom works only because C doesn't enforce stride. **This makes Refined Option 1' the correct shape**: type Vectors (iovec has fixed stride), keep Name raw, collapse Control to `UnsafeMutableRawBufferPointer?`. |
| 6 | Refined Option 1' leaves Control/Name partially typed — full vs partial close | **Partial close.** | Tracker entry: "P2.4 #8 partial — Vectors typed via Vector.Segment; Control collapsed to `UnsafeMutableRawBufferPointer?`; Name keeps raw-pointer typing pending a family-discriminated typed sockaddr view (currently unavailable); Control's cmsghdr-chain typing deferred pending dedicated cycle." Keeps ecosystem state legible; future audits can re-open the Name slot if/when a discriminated typed sockaddr view is designed. "Full close" would require either Option 4 ratification OR a cmsghdr design cycle PLUS a family-discriminator solution for Name. |

### Additional weaknesses principal flagged for the implementation cycle

- **`UnsafeRawBufferPointer?` middle-ground for Control** (flagged as doc weakness #1): integrated into Refined Option 1' — Control collapses to `UnsafeMutableRawBufferPointer?`, removing the separate length field and aligning with the "stdlib-buffer over raw-pointer" ecosystem direction.
- **Option 3's `@inlinable` cascade risk** (flagged as doc weakness #2): elevated in Option 3's cons above from "Pre-check required" to "potentially blocking"; Doc 1's Read/Write-family precedent cited. Implementation-cycle pre-check is mandatory if Option 3 is ever revisited.
- **Constraint #5 structural weight** (flagged as doc weakness #3): absorbed into Refined Option 1's Recommendation section as the "partial close" framing. No option in the matrix (1'/2/3/5) fully closes Control's typing without a dedicated cmsghdr design cycle; Option 4 (codify current state) is the only "full close" path absent that design.

### Ratified sub-rule for the audit tracker

The Q2 ruling is load-bearing for future audits. Principal authorized adding this clarifying sub-rule to [PLAT-ARCH-005a]'s Pattern 2 treatment in the platform audit tracker's Status Update section — not as an amendment to the platform skill itself (which is out of scope for this investigation) but as an audit-tracker clarification so future re-scans of Pattern 2 apply the same interpretation consistently.

### Forward-looking guidance to Doc 3 (from principal + session-conversation direction)

Principal flagged three siginfo_t-specific observations + two ecosystem-wide preferences that must be carried into Doc 3:

**siginfo_t-specific**:
1. **L1-vs-L2 diagnostic up-front again.** siginfo_t is almost certainly L2-exclusive (iso-9945 Signal scope). Confirm via `rg "public struct Information|Signal.Information" swift-primitives`. If confirmed, Doc 3's option space is constrained like Doc 2's, not like Doc 1's L1-enabled Option 5.
2. **Union-typed discriminator is the design center.** Unlike msghdr's pointer+length shape, siginfo_t's content is a C union dispatched on si_code: SIGCHLD's fields differ from SIGSEGV's differ from SIGPOLL's. A typed Swift wrapper must handle this — the ecosystem-native shape is an enum with associated values. Doc 3's most valuable analysis will be the union-to-enum mapping, not the layering question.
3. **Check swift-signals / iso-9945's Signal target for precedent.** There may already be enum-typed `Kernel.Signal.Information.Code` or similar typed discriminator that siginfo_t's wrapper should align with.

**Ecosystem-wide preferences (apply to Doc 3 and retroactively confirm Doc 2's direction)**:
4. **Move away from unsafe + pointer code in favor of modern Swift like Span types where possible.** Doc 2's Refined Option 1' partially honors this (Control collapses to stdlib buffer pointer); Doc 3 should push further where siginfo_t's union payload allows — e.g., typed enum + `Span<UInt8>` for byte-blob sub-cases rather than `UnsafePointer<T>` wrappers.
5. **Strict [API-NAME-002] no-compound-identifiers.** Doc 3's proposed type and method names must all go through the nested-accessor discipline. No `sendWith`, `receiveMessage`, `errorCode` etc. Nested forms only (`.send.with`, `.receive.message`, `.error.code`).
