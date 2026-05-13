# swift-uuids L3 Unifier Design

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

Thread H.3 (File.Path.Temporary.randomized adoption) attempted to consume
`RFC_4122.UUID.v4()` from `swift-foundations/swift-file-system` and surfaced a
class-(c) ecosystem-wide escalation: `swift-rfc-4122` does not build standalone.
Concretely, four defects in its current shape:

1. **L2-to-L2 lateral dependencies** declared in `Package.swift`
   ([`/Users/coen/Developer/swift-ietf/swift-rfc-4122/Package.swift:24-26`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Package.swift)):
   ```swift
   .package(path: "../../swift-standards/swift-darwin-standard"),
   .package(path: "../../swift-linux-foundation/swift-linux-standard"),
   .package(path: "../../swift-microsoft/swift-windows-32")
   ```
   Per [ARCH-LAYER-001], L2 packages MUST depend only on layers below them.
   Lateral L2-to-L2 dependencies are FORBIDDEN. `swift-rfc-4122` is an L2 spec
   package; the three deps above are also L2 spec packages.

2. **Stale `Darwin_Primitives` / `Linux_Primitives` / `Windows_Primitives`
   imports** in
   [`RFC_4122.UUID.swift:7-16`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.swift):
   ```swift
   #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
   import Darwin_Primitives
   import Darwin_Kernel_Standard
   #elseif os(Linux)
   import Linux_Primitives
   import Linux_Kernel_Standard
   ...
   ```
   The `*-Primitives` modules were retired per
   `~/.claude/projects/-Users-coen-Developer/memory/project_platform_stack_l2_reclassification.md`:
   `linux-primitives → swift-linux-standard at L2`; `swift-windows-standard`
   replaces `swift-windows-primitives`; the Darwin/Linux/Windows platform stack
   no longer ships separate `*-Primitives` packages.

3. **Stale `"Linux Kernel Standard"` product reference** in
   [`Package.swift:37-38`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Package.swift):
   ```swift
   .product(name: "Linux Kernel Standard", package: "swift-linux-standard", ...)
   ```
   `swift-linux-standard` decomposed its monolithic `"Linux Kernel Standard"`
   product into per-domain granular products
   ([`swift-linux-standard/Package.swift:16-31`](file:///Users/coen/Developer/swift-linux-foundation/swift-linux-standard/Package.swift)).
   The UUID parse surface lives in the `"Linux Kernel System Standard"`
   product at
   [`Linux Kernel System Standard/Linux.Identity.UUID.swift`](file:///Users/coen/Developer/swift-linux-foundation/swift-linux-standard/Sources/Linux%20Kernel%20System%20Standard/Linux.Identity.UUID.swift).

4. **Body-level call-site staleness**:
   [`RFC_4122.UUID.swift:153-163`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.swift)
   references `Darwin_Primitives.Darwin.Identity.UUID.parse(string)` etc., none
   of which resolve in the current ecosystem.

The L2 spec encoding (`RFC_4122.UUID`, `RFC_4122.Random`, `RFC_4122.Hash`,
`RFC_4122.UUID.v3/v4/v5`) is otherwise sound — the spec-mirroring is faithful
to RFC 4122 (and RFC 9562 builds cleanly on top via a typealias
`RFC_9562.UUID = RFC_4122.UUID` at
[`swift-rfc-9562/Sources/RFC 9562/RFC_9562.swift:23`](file:///Users/coen/Developer/swift-ietf/swift-rfc-9562/Sources/RFC%209562/RFC_9562.swift)).

The principal direction is a new L3 unifier `swift-uuids` composing the
spec-faithful L2 encoding with platform-specific L3-policy random sources per
[PLAT-ARCH-009]. This Research enumerates the design options and recommends a
shape.

### Existing ecosystem context (verified 2026-05-13)

The L3-unifier composition pattern is already proven by the canonical
`swift-random` package
([`swift-foundations/swift-random/Sources/Random/Exports.swift`](file:///Users/coen/Developer/swift-foundations/swift-random/Sources/Random/Exports.swift)),
which composes the three L3-policy packages exactly per [PLAT-ARCH-009]:

```swift
@_exported public import Random_Primitives

#if canImport(Darwin)
    @_exported public import Darwin_Kernel  // Brings Random.fill() for Darwin
#elseif canImport(Glibc) || canImport(Musl)
    @_exported public import Linux_Kernel   // Brings Random.fill() for Linux
#elseif os(Windows)
    @_exported public import Windows_Kernel // Brings Random.fill() for Windows
#endif
```

Each L3-policy package (`swift-darwin`, `swift-linux`, `swift-windows`) hosts
its own `Random.fill(_:)` implementation delegating to the L2 typed syscall
wrappers:

| L3-policy | L2 syscall wrapper | C primitive |
|-----------|--------------------|-------------|
| [`swift-darwin/Sources/Darwin Kernel/Darwin.Random.swift:38`](file:///Users/coen/Developer/swift-foundations/swift-darwin/Sources/Darwin%20Kernel/Darwin.Random.swift) | `Darwin.Kernel.Random.arc4random(_:)` | `arc4random_buf` |
| [`swift-linux/Sources/Linux Kernel Random/Linux.Random.swift:42`](file:///Users/coen/Developer/swift-foundations/swift-linux/Sources/Linux%20Kernel%20Random/Linux.Random.swift) | `Linux.Kernel.Random.getrandom(_:)` | `getrandom(2)` (EINTR retry, entropyNotReady mapping) |
| [`swift-windows/Sources/Windows Kernel/Windows.Random.swift:30`](file:///Users/coen/Developer/swift-foundations/swift-windows/Sources/Windows%20Kernel/Windows.Random.swift) | `Windows.\`32\`.Kernel.Random.bCryptGenRandom(_:)` | `BCryptGenRandom` (NTSTATUS mapping) |

A higher-level L3 package `swift-identities` ALREADY composes
`swift-rfc-9562` × `swift-random` to deliver typed identifier surface
([`swift-identities/Sources/Identities/Identity.UUID.swift:49`](file:///Users/coen/Developer/swift-foundations/swift-identities/Sources/Identities/Identity.UUID.swift)):

```swift
public static func random() throws(Random.Error) -> Self {
    var bytes: (UInt8, ..., UInt8) = (0, ..., 0)
    let outcome: Result<Void, Random.Error> = Swift.withUnsafeMutableBytes(of: &bytes) { buffer in
        do throws(Random.Error) { try Random.fill(buffer); return .success(()) }
        catch { return .failure(error) }
    }
    try outcome.get()
    bytes.6 = (bytes.6 & 0x0F) | 0x40  // version 4
    bytes.8 = (bytes.8 & 0x3F) | 0x80  // RFC 4122 variant
    return Self(bytes: bytes)
}
```

That is, the v4 random generation logic — bit-shift the version/variant
nibbles onto random bytes — is currently implemented as DEAD-CODE INLINE in
`swift-identities`, rather than being a callable affordance on
`RFC_4122.UUID` (which exists in `swift-rfc-4122` but cannot be linked
because the package fails to build). swift-uuids closes this gap by hosting
the spec-correct v4/v7 generators where they belong — at the L3 unifier
composing spec + random — and migrating `swift-identities` to consume it.

### Prior-research check ([RES-013] / [HANDOFF-013] / [RES-019])

Internal grep of `swift-institute/Research/` for `uuid`, `rfc-4122`,
`rfc_4122`, `swift-uuids`, `platform random`, `Identity.UUID`, and `UUID
layering` returns ZERO matches in
[`/Users/coen/Developer/swift-institute/Research/`](file:///Users/coen/Developer/swift-institute/Research/).
This is greenfield design — no superseded prior recommendation, no parallel
analysis, no existing decision to extend. The closest adjacent precedent is
the `swift-random` package architecture itself, which is implicit (not
codified in a Research doc) but mechanically verifiable at the package
sources above.

[RES-019] grep summary (executed 2026-05-13):
```bash
grep -rl -i "uuid\|rfc-4122\|rfc_4122\|swift-uuids" /Users/coen/Developer/swift-institute/Research/
# 0 matches in Research/*.md
```

## Question

The escalation surfaces four nested design questions:

| # | Question | Scope |
|---|----------|-------|
| Q1 | What is the **layering-repair shape** for swift-rfc-4122 that makes it build standalone without lateral L2-to-L2 deps? | Per-package |
| Q2 | What is **swift-uuids' composition strategy** — does it compose existing L3 packages (`swift-rfc-4122`, `swift-rfc-9562`, `swift-random`) or duplicate logic? | Ecosystem-wide |
| Q3 | Where does the **typed UUID value** live — at L2 (spec encoding) or at L3 (policy + random)? Which APIs surface where? | Cross-layer |
| Q4 | How does **File.Path.Temporary.randomized** consume swift-uuids, and what is the package boundary for randomized temp paths in `swift-file-system`? | Per-package consumer |

These four questions compose: Q1 governs Q3 (the L2 spec MUST be standalone-buildable
to be the canonical home for the UUID value); Q3 governs Q2 (where the value
lives constrains how swift-uuids must compose); Q2 governs Q4 (the swift-uuids
consumer surface dictates how `File.Path.Temporary.randomized` is authored).

## Analysis

### Tier classification

[RES-020] tier criteria:

| Criterion | swift-uuids assessment | Tier |
|-----------|------------------------|------|
| Scope | Ecosystem-wide (UUID is foundational, consumed transitively across most domain packages) | Tier 3 |
| Precedent-setting | Sets the canonical home for THE typed UUID value across the ecosystem; sets the layering pattern for future spec×random L3 unifiers (TLS PRG, CSRNG-consuming token generators, etc.) | Tier 3 |
| Semantic commitment | Normative — `swift-uuids` becomes the "if you want a UUID, import this" package; all upstream consumers (`swift-identities`, `swift-file-system`, future swift-jwt, swift-cookies, swift-cache-key, ...) depend on this answer | Tier 3 |
| Cost of error | Very high — wrong placement of v4/v7 random generators (e.g., at L2) would re-create the lateral-dep defect; wrong split between L2/L3 for the type itself would force a future relocation. | Tier 3 |
| Expected lifetime | Timeless infrastructure (UUID is an IETF-stable spec; Swift Institute's encoding will outlive any particular version) | Tier 3 |
| Formalization | Mandatory — Tier 3 per [RES-021/22/23/24] requires prior art, formal semantics, citations | Tier 3 |

CLASSIFICATION: **Tier 3** ecosystem-wide RECOMMENDATION.

### RFC 4122 / RFC 9562 algorithm shape (mechanically verified 2026-05-13)

The UUID specification family defines eight versions; each has different
input requirements:

| Version | Input | Pure compute? | Needs random source? | Needs clock? | Spec |
|---------|-------|---------------|----------------------|--------------|------|
| v1 | MAC address + 60-bit timestamp + 14-bit clock_seq | No | Yes (clock_seq seeded once) | Yes (UTC, 100-ns precision) | RFC 4122 §4.2 |
| v2 | POSIX UID/GID + truncated timestamp | No | Yes (clock_seq) | Yes | DCE 1.1 (skeleton in RFC 4122 §4.1.3) |
| v3 | namespace UUID + name (MD5) | **Yes** — pure compute | No | No | RFC 4122 §4.3 |
| v4 | 122 bits random | No | **Yes** — required | No | RFC 4122 §4.4 |
| v5 | namespace UUID + name (SHA-1) | **Yes** — pure compute | No | No | RFC 4122 §4.3 |
| v6 | reordered v1 timestamp (60-bit) + clock_seq + 62 random | No | Yes (clock_seq + random) | Yes (UTC, 100-ns precision) | RFC 9562 §5.6 |
| v7 | 48-bit Unix-ms timestamp + 12 rand_a + 62 random | No | **Yes** — required | Yes (Unix epoch, ms precision) | RFC 9562 §5.7 |
| v8 | application-specific 122 bits | (caller-controlled) | (caller-controlled) | (caller-controlled) | RFC 9562 §5.8 |

`swift-rfc-4122` currently implements **v3, v4, v5** at the L2 spec layer:
- v3, v5 are pure compute given a `HashProvider` (caller-injected MD5/SHA-1)
- v4 is parameterised by a `RandomProvider` protocol (caller-injected fill)

`swift-rfc-9562` adds **v6, v7, v8** via inheritance from `RFC_4122.UUID`.

Critically: **none** of v3/v4/v5/v6/v7/v8's L2 spec implementation needs to
*depend* on a platform random source. The L2 encoding parameterises over
random-byte-source and hash-source via `protocol RandomProvider` / `protocol
HashProvider`. The actual platform random is bound at the L3 composition
site. This is the cleanest possible separation and it is ALREADY the
architectural shape of the L2 packages — the only defect is the
build-time lateral L2-to-L2 deps for the `parse()` native-syscall fast-path,
which is a separable concern from generation.

### Platform random sources (verified 2026-05-13)

Mapped to current granular L2 products:

| Platform | C primitive | L2 spec package | L2 product | L3-policy wrapper |
|----------|-------------|-----------------|------------|-------------------|
| Darwin (macOS/iOS/tvOS/watchOS/visionOS) | `arc4random_buf` | `swift-darwin-standard` | `Darwin Kernel Standard` | [`swift-darwin/.../Darwin.Random.fill`](file:///Users/coen/Developer/swift-foundations/swift-darwin/Sources/Darwin%20Kernel/Darwin.Random.swift) |
| Linux | `getrandom(2)` (EINTR retry, EAGAIN→entropyNotReady) | `swift-linux-standard` | `Linux Kernel System Standard` | [`swift-linux/.../Linux.Random.fill`](file:///Users/coen/Developer/swift-foundations/swift-linux/Sources/Linux%20Kernel%20Random/Linux.Random.swift) |
| Windows | `BCryptGenRandom` (CNG; NTSTATUS mapping) | `swift-windows-32` | `Windows 32 Kernel System` | [`swift-windows/.../Windows.Random.fill`](file:///Users/coen/Developer/swift-foundations/swift-windows/Sources/Windows%20Kernel/Windows.Random.swift) |

All three are exposed via the unified L3 surface `Random.fill(_:)` in the
canonical `swift-random` package — which is exactly the affordance an
upstream UUID unifier needs.

### Prior art (per [RES-021])

| System | Pattern | Verified |
|--------|---------|----------|
| **RFC 4122** (Leach/Mealling/Salz, 2005) | Defines wire format + v1/v2/v3/v4/v5 algorithms; spec mandates "high-quality randomness" for v4 without prescribing source | [rfc-editor.org/rfc/rfc4122](https://www.rfc-editor.org/rfc/rfc4122) |
| **RFC 9562** (Davis/Peabody/Leach, 2024) | Obsoletes RFC 4122; adds v6/v7/v8; v7 recommended for new applications (sortable, ms-precision timestamp) | [rfc-editor.org/rfc/rfc9562](https://www.rfc-editor.org/rfc/rfc9562) |
| **Apple `Foundation.NSUUID`** | Single type owning spec encoding + v4 random generation; uses platform `CFUUIDCreate` → `uuid_generate_random` → `arc4random_buf` on Darwin; no separation between spec and policy | `Foundation/CFUUID.c` (open-source corelibs-foundation) |
| **Rust `uuid` crate v1.x** | `uuid` core crate is no_std + no platform deps; `uuid::Uuid` is pure value type; v4 generation feature-gated behind `"v4"` cargo feature which pulls in `getrandom` crate. Spec encoding and platform random are SEPARATE crates composed via feature flags. | [docs.rs/uuid](https://docs.rs/uuid/latest/uuid/) |
| **Boost.UUID** (C++) | `boost::uuids::uuid` core is platform-neutral; `boost::uuids::random_generator` is a separate template parameterised on a `URNG` (UniformRandomNumberGenerator); platform random source supplied at instantiation site | [boost.org/doc/libs/release/libs/uuid/](https://www.boost.org/doc/libs/release/libs/uuid/) |
| **Go `crypto/rand` + `github.com/google/uuid`** | `google/uuid` package's `NewRandom()` calls `io.ReadFull(rand.Reader, ...)` — same separation; spec encoding (`uuid` package) decoupled from platform random (`crypto/rand` stdlib package) | [pkg.go.dev/github.com/google/uuid](https://pkg.go.dev/github.com/google/uuid) |
| **Node.js `crypto.randomUUID`** | v4 generation bundled with the runtime crypto module; spec encoding not separately exposed; entire UUID generation is a single C++ binding | [nodejs.org/api/crypto.html#cryptorandomuuid](https://nodejs.org/api/crypto.html#cryptorandomuuiloptions) |
| **OpenSSL `RAND_bytes` + ad-hoc UUID** | Spec is well-known but OpenSSL doesn't ship a UUID type; consumers compose `RAND_bytes(16)` + bit-twiddling for version/variant nibbles inline | OpenSSL documentation |

**Contextualization step per [RES-021]** — would the prior-art pattern fit
this ecosystem?

| Pattern | Fits Swift Institute? | Why / why not |
|---------|----------------------|---------------|
| Apple Foundation: single type, single package | NO | Would couple L2 spec encoding to L1/L2 platform random; violates [ARCH-LAYER-001]. Apple Foundation is not layered; we are. |
| Rust uuid: separate crates, feature flags | **YES** | Maps directly: `swift-rfc-4122` = spec crate (no platform); `swift-uuids` = the feature-gated platform-random layer. Rust's `getrandom` crate is functionally equivalent to our `swift-random`. The feature-flag mechanism is just SwiftPM dependency selection. |
| Boost UUID: spec + URNG template parameter | **YES** | Already the shape of `RFC_4122.UUID.v4(using: R)` and `RFC_4122.UUID.v4(fillRandom:)` ([`RFC_4122.UUID.Generation.swift:256, 290`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.Generation.swift)). The L2 spec is already parameterised; we just need an L3 to bind the parameter. |
| Go: spec + io.ReadFull on platform random | **YES** | Same separation; the Swift equivalent is `RandomProvider.fill(_:)`. |
| Node crypto.randomUUID: monolithic binding | NO | Single non-decomposable binding; loses the spec/random separation that makes v3/v5 (pure-compute) consumable on Embedded targets without random. |
| OpenSSL: spec inlined at every consumer | NO | What `swift-identities` currently does — and the exact pain point swift-uuids exists to eliminate. |

**Verdict**: the Rust `uuid` / Boost / Go pattern is unanimous and structurally
aligned with Swift Institute's L2/L3 separation. Apple Foundation's monolithic
pattern is the ANTI-pattern; Node's monolithic binding is the same anti-pattern
at a different boundary.

### Theoretical grounding ([RES-022])

The L2 spec encoding × L3 policy composition is an instance of the well-known
**reader-monad / dependency-injection** pattern:

- `RFC_4122.UUID.v4<R: RandomProvider>(using: R) throws(R.RandomError) -> Self`
  is a function from `R: RandomProvider` to a UUID generator. Without binding
  `R`, the function is **parametrically polymorphic** over the random source —
  the L2 spec doesn't know, doesn't care, and CAN'T know (or it would close
  over a platform).

- An L3 unifier specialises that polymorphism at the composition site: bind
  `R = Random` (which is itself the platform-conditional L3-policy
  composition).

This is parallel to the universal pattern across Swift Institute's L2/L3
boundary:
- `swift-iso-9945`'s typed POSIX wrappers ARE the platform-parametrised spec;
- `swift-posix`'s policy wrappers ARE the same operations specialised with
  EINTR-retry policy bound;
- swift-uuids is the same shape, one tier up the random axis.

Formally, with `Spec` = RFC encoding and `Random` = platform CSPRNG:
- `Spec.v4 : RandomProvider → SpecError R.RandomError ⇒ UUID`
- `swift-uuids.v4 : Random.Error ⇒ UUID = Spec.v4(using: PlatformRandom)`

The composition collapses the universal quantifier to a single binding;
swift-uuids has no degrees of freedom left to expose to callers (intentional —
consumers want "give me a UUID" not "give me a UUID parameterised by random
source").

### Options enumeration

#### Option A: Minimal repair only — strip v4/v7 from swift-rfc-4122; no swift-uuids

**Shape**:
- Drop the three L2-to-L2 deps from `swift-rfc-4122/Package.swift`.
- Remove the `Darwin_Primitives`/`Linux_Primitives`/`Windows_Primitives` imports
  from `RFC_4122.UUID.swift` (they were only used for the native-syscall
  fast-path on `parse()`).
- Move the v4 / v7 generators that need random to a separate package OR
  delete them entirely; rely on consumers to inline bit-twiddling per
  `swift-identities`'s current pattern.
- v3 / v5 (pure-compute given `HashProvider`) stay at L2.

**Pros**:
- Smallest diff. Single-package change.
- Restores `swift-rfc-4122` to spec-faithful L2 (no random surface).
- Aligns with the strict "L2 = spec encoding only" reading.

**Cons**:
- **Does not solve the original Thread H.3 problem.** `File.Path.Temporary.randomized`
  needs a typed UUID generator. If we don't ship one, every consumer hand-rolls
  it (the `swift-identities` antipattern is the proof that this happens).
- **Loses the parametric `v4(using: R)` affordance** — power users (Wasm /
  Embedded / test injection) lose the ability to provide their own random
  source to generate spec-correct UUIDs.
- **Violates [ARCH-LAYER-011]** — the right response to an institute-foundation
  gap is to IMPROVE the foundation, not delete the affordance.
- **Loses v7** — RFC 9562's recommended-for-new-applications version requires
  random + timestamp. Without a home at L3, v7 also can't ship.

**Verdict**: REJECTED. Option A solves the build defect but creates a
functionality gap. The cost asymmetry per [RES-022] (structural correctness
vs. diff size) is decisive: the spec parameterises over random; we should
honor that parameterisation by binding it at L3, not drop it.

#### Option B: swift-uuids L3 unifier; pure-compute v3/v5 stay at L2; random v4/v7 land at L3

**Shape** (RECOMMENDED):

1. **Layering repair at swift-rfc-4122** (Phase 4.1):
   - Drop the three platform deps from `Package.swift`.
   - Remove the `#if os(...)` block from `RFC_4122.UUID.swift`.
   - Replace `RFC_4122.UUID.parse(_:)`'s native-syscall fast-path
     (lines 152-164) with the pure-Swift `parseUTF8` fallback (which already
     exists at lines 178-204). The fast-path was an optimization, not a
     correctness requirement; the spec-faithful pure-Swift path stays.
   - L2 surface unchanged: `RFC_4122.UUID`, `.Error`, `.Version`, `.Variant`,
     `protocol HashProvider`, `protocol RandomProvider`, `.Hash`, `.Random`,
     and `v3(...)/v4(using:)/v5(...)` parametric generators.
   - L2 retains the dependency-injected v3/v4/v5 surface via `Dependency.Key`
     conformance on `RFC_4122.Hash` and `RFC_4122.Random` — but the `liveValue`
     of `RFC_4122.Random` (currently `UInt8.random(in:)`, which is NOT CSPRNG
     and is a latent defect) is REMOVED. Power users at L2 can still inject
     a CSPRNG via `Dependency.Scope.with`; the convenience parameterless `v4()`
     overload (`RFC_4122.UUID+Dependency.swift:83`) becomes test-only at L2.
   - `swift-rfc-9562` is already clean (no platform deps) and inherits the
     repair transitively.

2. **New L3 package `swift-uuids`** at
   `swift-foundations/swift-uuids/` (Phase 4.2):
   - **Dependencies**: `swift-rfc-4122`, `swift-rfc-9562`, `swift-random`.
   - **Module name**: `UUIDs` (library/target).
   - **Top-level type**: re-export `RFC_4122.UUID` / `RFC_9562.UUID` (they are
     the same type — RFC 9562 typealiases to RFC 4122's storage). No new
     UUID nominal type is introduced. The spec-mirroring at L2 stays
     canonical per [API-NAME-003].
   - **L3 generators** (the unifier's content):
     ```swift
     extension RFC_4122.UUID {
         /// v4 random UUID using the platform CSPRNG via swift-random.
         public static func v4() throws(Random.Error) -> Self {
             try v4(fillRandom: Random.fill)
         }
     }

     extension RFC_9562.UUID {
         /// v7 UUID using the platform CSPRNG + a host-supplied epoch-ms timestamp.
         public static func v7(unixMilliseconds: UInt64) throws(Random.Error) -> Self {
             try v7(unixMilliseconds: unixMilliseconds, fillRandom: Random.fill)
         }
     }
     ```
     The bodies are 2-line wrappers: bind `fillRandom: Random.fill` and
     delegate to the existing L2 parametric `v4(fillRandom:)` /
     `v7(unixMilliseconds:fillRandom:)` overloads
     ([`RFC_4122.UUID.Generation.swift:290`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.Generation.swift), [`RFC_9562.UUID.Generation.swift:121`](file:///Users/coen/Developer/swift-ietf/swift-rfc-9562/Sources/RFC%209562/RFC_9562.UUID.Generation.swift)).
   - **`Exports.swift`** re-exports all three deps via `@_exported public import`:
     ```swift
     @_exported public import RFC_4122
     @_exported public import RFC_9562
     @_exported public import Random
     ```
   - Consumer experience: `import UUIDs` brings the canonical typed UUID +
     spec-correct v3/v4/v5/v6/v7/v8 generators on every platform.

3. **`swift-identities` migration** (Phase 4.2 follow-on):
   - `swift-identities/Package.swift` drops the direct `swift-random` dep,
     replaces `swift-rfc-9562` dep with `swift-uuids`.
   - `Identity.UUID.random()` body collapses from the 30-line inline
     bit-twiddle to `try RFC_4122.UUID.v4()`.

4. **`File.Path.Temporary.randomized` adoption** (Phase 4.3):
   - `swift-file-system/Sources/File System Core/File.Path.Temporary.swift`
     adds `randomized(prefix:suffix:)` that calls `RFC_4122.UUID.v4()`
     (via `import UUIDs`), unparses to its 36-char hyphenated form, and
     composes into a `File.Path`.

**Pros**:
- **Solves Thread H.3 root cause**: `File.Path.Temporary.randomized` gets a
  spec-correct typed UUID via a single import.
- **Restores `swift-rfc-4122` to standalone build**: zero platform deps; pure
  L2 spec encoding.
- **Mirrors the canonical `swift-random` L3-unifier shape**: identical
  Package.swift dep set, identical Exports.swift structure, identical
  composition discipline per [PLAT-ARCH-009].
- **Honors [ARCH-LAYER-011]**: when an institute foundation gap exists, we
  IMPROVE the institute package (create swift-uuids); we don't reach for
  Foundation.NSUUID or hand-roll.
- **Honors [API-NAME-003]**: the canonical UUID type stays at L2 with
  spec-mirroring (`RFC_4122.UUID`); the L3 unifier doesn't invent a new name.
- **Honors [RES-018]**: two consumers already identified (swift-identities
  migration; swift-file-system Thread H.3 adoption). Future v3 consumers
  (deterministic namespace IDs in caching/feature-flag systems) are
  pre-witnessed by the existing L2 parameterisation.
- **No degrees of freedom for caller mistakes**: the L3 v4/v7 functions take
  no parameters; platform random is auto-bound. Power users still have
  `v4(using: R)` / `v4(fillRandom: F)` at L2 if they want to inject.
- **Composes downward to swift-identities cleanly** — the existing
  Identity.UUID.random() inline pattern collapses to a 1-line delegate.
- **Removes the latent CSPRNG defect at L2** — currently
  `RFC_4122.Random.liveValue` uses non-cryptographic `UInt8.random(in:)`
  ([`RFC_4122.Random.swift:54`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.Random.swift));
  moving the live binding to L3 (where the real CSPRNG lives) is a security
  win as a side effect of the layering repair.

**Cons**:
- Adds one package (`swift-uuids`). Modest ecosystem footprint cost.
- Two layers of typealiases for the convenience overload chain — small
  cognitive overhead but mechanically transparent.
- Requires migration of `swift-identities` to consume swift-uuids
  (mechanical, ~30 LoC delete and one dep swap).

**Verdict**: RECOMMENDED. Option B is the smallest diff that honors all
applicable structural rules ([ARCH-LAYER-001], [ARCH-LAYER-011],
[PLAT-ARCH-009], [API-NAME-003], [RES-018]) AND solves the originating Thread
H.3 escalation.

#### Option C: swift-uuids fully owns the typed UUID surface

**Shape**:
- swift-uuids hosts a new `UUID` nominal type (or `UUIDs.UUID` namespace).
- `RFC_4122.UUID` typealiased TO `UUIDs.UUID` (inverted relationship).
- L3 owns the canonical name; L2 retains spec encoding mechanics behind the
  typealias.
- Single consumer import: `import UUIDs` brings the type, generators, parsing.

**Pros**:
- Single canonical name (`UUIDs.UUID`) at the consumer-facing layer.
- L3 ownership matches the "consumer's mental model" — UUIDs are a tool, not
  a spec.

**Cons**:
- **Violates [API-NAME-003]** — RFC 4122 IS the specification authority for
  the UUID format; the spec-mirroring name MUST live where the spec is
  encoded (L2). The institute's pattern (`RFC_4122.UUID`, `ISO_32000.Page`,
  `RFC_3986.URI`) consistently puts the spec name at L2.
- **Inverts the typealias direction** — currently `RFC_9562.UUID` typealiases
  TO `RFC_4122.UUID` because RFC 9562 inherits RFC 4122's wire format. If
  swift-uuids owns the canonical type, BOTH RFCs typealias INTO L3, which
  inverts the layered model: L2 SHOULD be the encoding authority, not a
  consumer of the L3 type.
- **Per [PLAT-ARCH-018]** (typealiased-namespace-path conflict rule): with
  the typealias chain `RFC_4122.UUID → UUIDs.UUID`, declaring
  `extension RFC_4122.UUID { static let myNamespace = ... }` adds the
  declaration to `UUIDs`'s namespace at compile time. This is the
  conflict-mode shape — confusing to authors, confusing to reviewers.
- **Breaks `swift-rfc-9562`'s self-contained spec encoding** —
  RFC 9562 currently builds with one dep (swift-rfc-4122). Option C makes
  `RFC_9562.UUID = RFC_4122.UUID = UUIDs.UUID`, which means
  `swift-rfc-9562` transitively depends on swift-uuids → swift-random →
  platform standards. The L2 spec package loses standalone-buildability
  in a different way than the current defect.

**Verdict**: REJECTED. Option C optimizes for consumer name aesthetics at the
cost of structural correctness ([API-NAME-003], [PLAT-ARCH-018],
[ARCH-LAYER-001]). The spec authority is RFC 4122/9562; the encoding lives
where the spec authority is named.

#### Option D: Per-version split (swift-uuid-v4, swift-uuid-v7, swift-uuid-name-based)

**Shape**:
- One L3 package per UUID version: swift-uuid-v4, swift-uuid-v7,
  swift-uuid-v3-v5 (name-based), etc.
- Each consumer picks-and-mixes.

**Pros**:
- Most fine-grained dependency surface.
- An Embedded consumer needing v3/v5 only would pull no platform random
  deps.

**Cons**:
- **Sprawl** — six L3 packages where one suffices. Each adds Package.swift +
  source tree + CI + maintenance cost.
- **No second consumer** for per-version packages — Thread H.3 needs v4;
  swift-identities needs v4; no current consumer has stated a need for
  Embedded-without-random-but-with-name-based-UUIDs. Per [RES-018], the
  fine-grained packaging is premature; the second-consumer hurdle is not met
  for the split.
- **Discoverability cost** — consumers wanting "a UUID generator" must
  research which version they want before they know which package to import.
  `import UUIDs` is the universally-expected ergonomic.
- **L2 / L3 boundary is already at the right granularity** — pure-compute
  (v3/v5) lives at L2 and is consumable on Embedded WITHOUT pulling swift-uuids.
  Embedded consumers needing only v3/v5 already have that affordance under
  Option B; per-version splitting at L3 solves a problem that doesn't exist.

**Verdict**: REJECTED. Sprawl without consumer-evidenced benefit. Option D
fails [RES-018]; the L2/L3 split in Option B already delivers the
Embedded-without-random affordance without per-version packaging.

### Comparison ([RES-005] / [RES-009])

| Criterion | Option A: minimal repair | Option B: swift-uuids L3 unifier (RECOMMENDED) | Option C: L3 owns canonical type | Option D: per-version split |
|-----------|--------------------------|------------------------------------------------|----------------------------------|------------------------------|
| Layering cleanliness | Good (L2 = spec only) | **Excellent** (L2 = spec; L3 = composition; [PLAT-ARCH-009] mirror) | Bad (L2 typealias INTO L3; inverts authority) | Good but fragmented |
| Consumer ergonomics | Bad — every consumer hand-rolls v4 | **Excellent** — `import UUIDs; UUID.v4()` | Excellent (single import) | Bad — discoverability problem |
| Cascade depth | 0 packages → 1 (just swift-rfc-4122) | 1 new package + 2 migrations | 1 new package + N typealias inversions across L2 | 4–6 new packages |
| Future-extensibility | Bad — random surface is missing from the ecosystem | **Excellent** — `swift-uuids` is the obvious home for future v7-pre-generators, RFC 9562 batch APIs, etc. | Medium — naming inversion confuses extension placement | Bad — each new version is another package |
| Conformance with [PLAT-ARCH-009] | N/A (no L3 unifier) | **Yes** — direct mirror of swift-random shape | Partial — composes but inverts spec authority | No — fragments unifier role |
| Conformance with [API-NAME-003] | Yes (L2 unchanged) | **Yes** — RFC_4122.UUID stays canonical | **No** — moves canonical name out of spec namespace | Yes (L2 unchanged) |
| Conformance with [ARCH-LAYER-001] | Yes (drops L2-L2 deps) | **Yes** — strict L1 < L2 < L3 ordering | Partial (typealias inversion is awkward but legal) | Yes |
| Conformance with [ARCH-LAYER-011] | **No** — abandons the affordance | **Yes** — improves institute foundation | Yes | Yes |
| Conformance with [RES-018] | N/A | **Yes** — two consumers (file-system, identities) | Yes | **No** — per-version 2nd consumer not met |
| Risk of future relocation | Low (no new package) | Low (precedent-aligned) | High (inversion may need un-inverting later) | High (consolidation pressure once cohort grows) |

### Empirical validation ([RES-025] cognitive dimensions)

Option B against the Cognitive Dimensions Framework:

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Visibility | Good | `import UUIDs` is one line; the version methods are statically discoverable on the type. |
| Consistency | Excellent | Mirrors `import Random` / `Random.fill(_:)` shape exactly; mirrors `import Strings` / `import Paths` package-level pattern. |
| Viscosity | Low — adding a future v9 (hypothetical) means adding one method on `swift-uuids` extension; no migration. |
| Role-expressiveness | Excellent | `RFC_4122.UUID.v4()` reads "UUID per RFC 4122, version 4". The spec authority is in the type name; the version is in the method name. |
| Error-proneness | Low — typed throws `throws(Random.Error)` makes the failure mode visible; the parameterless overload eliminates random-source confusion. |
| Abstraction | Right-sized — no abstraction at L3 (just binding); spec abstraction at L2 is via `protocol RandomProvider` which power users can reach for. |

## Outcome

**Status**: RECOMMENDATION (v1.0.0)

**RECOMMENDATION**: Adopt Option B — create `swift-uuids` L3 unifier
composing `swift-rfc-4122` × `swift-rfc-9562` × `swift-random` after
repairing `swift-rfc-4122` to drop its forbidden L2-to-L2 lateral
dependencies. This mirrors the canonical `swift-random` L3-unifier shape
([PLAT-ARCH-009]), keeps the typed UUID value at L2 per spec-mirroring
discipline ([API-NAME-003]), and unblocks Thread H.3's
`File.Path.Temporary.randomized` adoption.

### Wave 4 phase plan

Three sequential phases; each phase has a verifiable green-build gate.

#### Phase 4.1 — swift-rfc-4122 layering repair

**Scope**: per-package, single repo (`swift-ietf/swift-rfc-4122`).

**Diff shape**:

1. **`Package.swift`** — remove three deps + three product references:
   ```diff
   dependencies: [
       .package(path: "../../swift-primitives/swift-ascii-primitives"),
       .package(path: "../../swift-primitives/swift-standard-library-extensions"),
       .package(path: "../../swift-primitives/swift-dependency-primitives"),
   -   .package(path: "../../swift-standards/swift-darwin-standard"),
   -   .package(path: "../../swift-linux-foundation/swift-linux-standard"),
   -   .package(path: "../../swift-microsoft/swift-windows-32")
   ],
   ```
   And the three `.product(...)` references in the target deps.

2. **`Sources/RFC 4122/RFC_4122.UUID.swift`** —
   - Lines 7-16: delete the `#if os(...)` import block entirely.
   - Lines 152-164: delete the native-syscall fast-path. The
     pure-Swift `parseUTF8` path (lines 178-204) becomes the unconditional
     parse implementation. The native fast-path was an optimization, not a
     correctness requirement; the pure-Swift path is already tested and
     produces identical bytes (it's the L2 spec encoding).

3. **`Sources/RFC 4122/RFC_4122.Random.swift`** — change the `liveValue` to
   `fatalError("RFC_4122.Random.liveValue must be bound via Dependency.Scope; \
   import UUIDs and use RFC_4122.UUID.v4() for platform-default random.")`.
   This makes the latent CSPRNG defect explicit: L2 has no platform binding,
   period. Power users at L2 must inject explicitly; default consumers reach
   for swift-uuids.

4. **Tests**: keep all existing parse/generate tests; the test surface is
   unchanged (the tests use the pure-Swift parse path; the fast-path was
   never the surface under test).

**Green-build gate**: `swift build && swift test` in
`swift-ietf/swift-rfc-4122/` succeeds with ZERO platform deps. Sibling
`swift-rfc-9562/` inherits the repair and continues to build clean.

**Estimated diff size**: ~50 LoC delete; 2 LoC change. Single commit.

#### Phase 4.2 — swift-uuids package creation + swift-identities migration

**Scope**: cross-package; two repos
(`swift-foundations/swift-uuids` new; `swift-foundations/swift-identities`
migrated).

**Diff shape**:

1. **New package `swift-foundations/swift-uuids/`**:
   - `Package.swift` — pattern-match `swift-random/Package.swift` exactly.
     Deps: `../../swift-ietf/swift-rfc-4122`, `../../swift-ietf/swift-rfc-9562`,
     `../swift-random`. Single product `"UUIDs"`, single target `"UUIDs"`.
   - `Sources/UUIDs/Exports.swift`:
     ```swift
     @_exported public import RFC_4122
     @_exported public import RFC_9562
     @_exported public import Random
     ```
   - `Sources/UUIDs/RFC_4122.UUID+v4.swift`:
     ```swift
     extension RFC_4122.UUID {
         /// Generates a version 4 (random) UUID using the platform CSPRNG.
         public static func v4() throws(Random.Error) -> Self {
             try v4(fillRandom: Random.fill)
         }
     }
     ```
   - `Sources/UUIDs/RFC_9562.UUID+v7.swift`:
     ```swift
     extension RFC_9562.UUID {
         /// Generates a version 7 (Unix-ms-timestamp + random) UUID using
         /// the platform CSPRNG and a host-supplied epoch-ms timestamp.
         public static func v7(unixMilliseconds: UInt64) throws(Random.Error) -> Self {
             try v7(unixMilliseconds: unixMilliseconds, fillRandom: Random.fill)
         }
     }
     ```
   - Tests covering: v4 returns valid version+variant bits; v4 differs across
     calls; v7 timestamp encoding round-trips; v7 monotone-when-timestamp-monotone.
   - DocC: explain the L3-unifier role; cite RFC 4122 / RFC 9562; cross-reference
     RFC_4122 / RFC_9562 / Random.

2. **swift-identities migration**:
   - `Package.swift`: replace dep on `swift-rfc-9562` + `swift-random` with
     single dep on `swift-uuids`.
   - `Sources/Identities/Identity.UUID.swift`: replace the 30-LoC inline body
     of `random()` with `try RFC_4122.UUID.v4()`. Drop the redundant local
     bit-twiddle.

**Green-build gate**: `swift build && swift test` in both packages succeeds.
swift-identities's existing tests confirm `Identity.UUID.random()` still
returns spec-correct v4 UUIDs.

**Estimated diff size**: ~200 LoC new (Package.swift + 3 source files + tests +
DocC); ~25 LoC delete in swift-identities.

#### Phase 4.3 — File.Path.Temporary.randomized adoption

**Scope**: per-package
(`swift-foundations/swift-file-system`).

**Diff shape**:

1. **`Package.swift`**: add dep on `../swift-uuids` and product reference
   `"UUIDs"` to the relevant File System target.

2. **`Sources/File System Core/File.Path.Temporary.swift`** — add:
   ```swift
   internal import UUIDs

   extension File.Path.Temporary {
       /// A randomized temporary `File.Path` using a v4 UUID component.
       ///
       /// Composes `<TMPDIR>/<prefix><uuid-hyphenated><suffix>`.
       ///
       /// - Throws: `File.Path.Error` if path validation fails;
       ///   `Random.Error` if random byte generation fails.
       public static func randomized(
           prefix: Swift.String = "",
           suffix: Swift.String = ""
       ) throws -> File.Path {
           let uuid = try RFC_4122.UUID.v4()
           let component = prefix + uuid.unparsed() + suffix
           let temporaryDirectoryString = Environment.read("TMPDIR") ?? "/tmp"
           let temporaryDirectory = try File.Path(temporaryDirectoryString)
           let trailing = try File.Path(component)
           return temporaryDirectory.appending(trailing)
       }
   }
   ```
   (Final shape — error union, throws-clause, naming — to be finalized at
   the implementation dispatch; this Research only commits to the package
   boundary, not the exact signature.)

3. Tests: confirm two successive calls produce different paths; confirm
   prefix/suffix are honored; confirm the file is under `Environment.read("TMPDIR")`.

**Green-build gate**: `swift build && swift test` in
`swift-foundations/swift-file-system/` succeeds. Thread H.3's blocking
gate clears.

**Estimated diff size**: ~30 LoC new (Package.swift + extension + tests).

### Phase ordering invariant

Phases MUST execute in order 4.1 → 4.2 → 4.3.
- 4.2 requires 4.1's green build (swift-uuids depends on swift-rfc-4122).
- 4.3 requires 4.2's green build (file-system depends on swift-uuids).

The phases can be authored in parallel (separate commits, separate
sub-cycle dispatches) but the LANDING ORDER is sequential per the dep DAG.

### Composition-discipline citations

- [PLAT-ARCH-009] (L3 platform package responsibilities) — swift-uuids is an
  L3-unifier composing L3-policy `swift-random`; the unifier's role is
  composition, not policy.
- [PLAT-ARCH-008h] (within-L3 composition matrix) — swift-uuids fits the
  "L3-domain → L3-unifier" row (UUIDs is a domain L3; consumes the
  random L3-unifier). The matrix permits this composition.
- [ARCH-LAYER-001] (dependency direction) — swift-uuids at L3 depends
  on `swift-rfc-4122` / `swift-rfc-9562` (L2) and `swift-random` (L3-unifier).
  No upward, no lateral.
- [ARCH-LAYER-011] (improve institute foundation, don't reach for Apple
  Foundation) — the institute response to a UUID gap is swift-uuids, not
  `import Foundation; UUID()`. Honored.
- [API-NAME-003] (spec-mirroring names) — canonical type stays
  `RFC_4122.UUID` at L2; swift-uuids re-exports without renaming.
- [RES-018] (second-consumer hurdle) — two consumers (swift-identities,
  swift-file-system) confirm beyond the originating Thread H.3 site.

### Out of scope (explicitly deferred)

- **v1 / v2 / v6 generators**: v1/v2/v6 need clock_seq + node-id machinery
  that depends on a uniqueness oracle (MAC address, host ID). The ecosystem
  doesn't yet have a typed home for "stable host identifier"; v1/v2/v6
  generators are deferred to a future dispatch (likely cohabiting with
  `swift-systems` or a new `swift-host-id`). v3/v4/v5/v7/v8 cover ~99% of
  documented production use.
- **Batch generation** (RFC 9562's recommendations for high-throughput
  v7 batching with monotonicity guarantees) — deferred to future swift-uuids
  v1.1.0+ on demonstrated consumer demand.
- **MD5/SHA-1 `liveValue` for v3/v5** — currently CryptoKit-backed at
  `RFC_4122.Hash.liveValue` (Darwin-only). The cross-platform binding is
  a separate cascade through `swift-crypto` or equivalent and is not in
  the Thread H.3 critical path.

### Class-(c) issues surfaced during design exploration

During this analysis, two additional ecosystem-wide observations surfaced
beyond the originating Thread H.3 defect set:

1. **Latent CSPRNG defect at L2**: `RFC_4122.Random.liveValue` in
   [`RFC_4122.Random.swift:54`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.Random.swift)
   uses `UInt8.random(in: .min...max)` — backed by Swift's
   `SystemRandomNumberGenerator`. On Apple platforms this is documented as
   CSPRNG; on Linux Swift 6.3 it is documented as CSPRNG (uses
   `/dev/urandom`); on Windows it is documented as CSPRNG. The defect is
   semantic: the `liveValue` SHOULD be the explicit platform CSPRNG path
   (`arc4random_buf` / `getrandom` / `BCryptGenRandom`), not the stdlib
   RNG abstraction whose underlying source is documentation-dependent.
   The Phase 4.1 repair recommendation upgrades this to `fatalError` at L2,
   forcing the binding to L3 where the CSPRNG choice is mechanically
   verifiable. **Status**: addressed by Phase 4.1.

2. **`swift-identities` carries dead-code UUID generation inline**:
   the bit-twiddle logic in `Identity.UUID.random()` is a duplicate of
   what `RFC_4122.UUID.v4(fillRandom:)` already does. The duplication
   exists because swift-rfc-4122 doesn't currently build, forcing
   swift-identities to inline the logic against `swift-random.fill`.
   **Status**: addressed by Phase 4.2 migration.

Neither additional issue is independent of the Thread H.3 escalation; both
are sub-symptoms of the same layering defect and resolve in the same Wave 4
arc.

## References

- RFC 4122: A Universally Unique IDentifier (UUID) URN Namespace —
  Leach, Mealling, Salz, 2005.
  [rfc-editor.org/rfc/rfc4122](https://www.rfc-editor.org/rfc/rfc4122)
- RFC 9562: Universally Unique IDentifiers (UUIDs) — Davis, Peabody,
  Leach, 2024 (obsoletes RFC 4122).
  [rfc-editor.org/rfc/rfc9562](https://www.rfc-editor.org/rfc/rfc9562)
- Rust `uuid` crate documentation —
  [docs.rs/uuid](https://docs.rs/uuid/latest/uuid/)
- Boost.UUID library —
  [boost.org/doc/libs/release/libs/uuid/](https://www.boost.org/doc/libs/release/libs/uuid/)
- Google `uuid` Go package —
  [pkg.go.dev/github.com/google/uuid](https://pkg.go.dev/github.com/google/uuid)
- Node.js `crypto.randomUUID` —
  [nodejs.org/api/crypto.html](https://nodejs.org/api/crypto.html#cryptorandomuuiloptions)
- Apple `arc4random_buf(3)` manual —
  [developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/arc4random.3.html](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/arc4random.3.html)
- Linux `getrandom(2)` manual —
  [man7.org/linux/man-pages/man2/getrandom.2.html](https://man7.org/linux/man-pages/man2/getrandom.2.html)
- Microsoft `BCryptGenRandom` —
  [learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcryptgenrandom](https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcryptgenrandom)
- Internal sources (verified 2026-05-13):
  - [`swift-ietf/swift-rfc-4122/Package.swift`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Package.swift)
    (current defect site)
  - [`swift-ietf/swift-rfc-4122/Sources/RFC 4122/RFC_4122.UUID.swift`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.swift)
    (stale imports + native-syscall fast-path)
  - [`swift-ietf/swift-rfc-4122/Sources/RFC 4122/RFC_4122.UUID.Generation.swift`](file:///Users/coen/Developer/swift-ietf/swift-rfc-4122/Sources/RFC%204122/RFC_4122.UUID.Generation.swift)
    (v3/v4/v5 parametric generators — REUSED at swift-uuids unchanged)
  - [`swift-ietf/swift-rfc-9562/Sources/RFC 9562/RFC_9562.UUID.Generation.swift`](file:///Users/coen/Developer/swift-ietf/swift-rfc-9562/Sources/RFC%209562/RFC_9562.UUID.Generation.swift)
    (v7 parametric generator — REUSED at swift-uuids unchanged)
  - [`swift-foundations/swift-random/Sources/Random/Exports.swift`](file:///Users/coen/Developer/swift-foundations/swift-random/Sources/Random/Exports.swift)
    (canonical L3-unifier composition shape; swift-uuids mirrors this)
  - [`swift-foundations/swift-darwin/Sources/Darwin Kernel/Darwin.Random.swift`](file:///Users/coen/Developer/swift-foundations/swift-darwin/Sources/Darwin%20Kernel/Darwin.Random.swift)
  - [`swift-foundations/swift-linux/Sources/Linux Kernel Random/Linux.Random.swift`](file:///Users/coen/Developer/swift-foundations/swift-linux/Sources/Linux%20Kernel%20Random/Linux.Random.swift)
  - [`swift-foundations/swift-windows/Sources/Windows Kernel/Windows.Random.swift`](file:///Users/coen/Developer/swift-foundations/swift-windows/Sources/Windows%20Kernel/Windows.Random.swift)
  - [`swift-foundations/swift-identities/Sources/Identities/Identity.UUID.swift`](file:///Users/coen/Developer/swift-foundations/swift-identities/Sources/Identities/Identity.UUID.swift)
    (current dead-code inline duplication; collapses to delegate at Phase 4.2)
  - [`swift-foundations/swift-file-system/Sources/File System Core/File.Path.Temporary.swift`](file:///Users/coen/Developer/swift-foundations/swift-file-system/Sources/File%20System%20Core/File.Path.Temporary.swift)
    (Thread H.3 adoption site)
- Skill rules cited:
  - [ARCH-LAYER-001] (dependency direction)
  - [ARCH-LAYER-011] (improve institute foundation)
  - [API-NAME-003] (specification-mirroring names)
  - [PLAT-ARCH-009] (L3 platform package responsibilities)
  - [PLAT-ARCH-008h] (within-L3 composition matrix)
  - [PLAT-ARCH-018] (typealiased-namespace-path conflict rule)
  - [RES-018] (premature-primitive anti-pattern / second-consumer hurdle)
  - [RES-020] (research tier classification)
  - [RES-021] (prior art with contextualization)
  - [RES-022] (recommendation-section framing heuristic)
  - [RES-026] (citations)
- Memory entries cited:
  - `project_platform_stack_l2_reclassification.md` (linux-primitives →
    swift-linux-standard at L2; explains the stale imports defect)
