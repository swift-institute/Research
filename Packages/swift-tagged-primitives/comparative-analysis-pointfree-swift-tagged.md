# Comparative Analysis — swift-tagged-primitives vs pointfreeco/swift-tagged

<!--
---
version: 1.0.0
last_updated: 2026-02-26
status: DECISION
tier: 2
---
-->

## Context

`Tagged<Tag, Underlying>` in swift-tagged-primitives was inspired by Point-Free's [swift-tagged](https://github.com/pointfreeco/swift-tagged), which uses `Tagged<Tag, RawValue>` with stored `rawValue`. Both libraries solve the same fundamental problem: wrapping an underlying value with a phantom type parameter for compile-time type safety. However, the implementations have diverged significantly in design philosophy, capability, and rigor — including renaming the wrapped-value generic from `RawValue` (theirs) to `Underlying` (ours, aligning with `Carrier.\`Protocol\``).

This document provides a systematic comparison across eight dimensions. The goal is to document where the two implementations align, where they diverge, and whether each divergence is principled.

**Trigger**: [RES-012] Discovery — proactive documentation of design rationale for a working design that evolved from an external dependency.

**Scope**: Package-specific (swift-tagged-primitives). [RES-002a]

## Prior Art

Point-Free introduced swift-tagged in 2018 via [Episode #12](https://www.pointfree.co/episodes/ep12-tagged). The library popularized the phantom type wrapper pattern in the Swift ecosystem. It has a clean, pragmatic API.

Our implementation began as a fork of the same concept for the Swift Institute primitives ecosystem. Constraints of that ecosystem — Foundation-independence [PRIM-FOUND-001], `~Copyable` support, operator safety, and zero-cost verification — drove the divergence documented here.

## Analysis

### 1. Type Signature

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Declaration | `struct Tagged<Tag, RawValue>` | `struct Tagged<Tag: ~Copyable, Underlying: ~Copyable>: ~Copyable` |
| Tag constraint | `Tag: Copyable` (implicit) | `Tag: ~Copyable` |
| Wrapped-value name | `RawValue` | `Underlying` (aligned with `Carrier.\`Protocol\``) |
| Wrapped-value constraint | `RawValue: Copyable` (implicit) | `Underlying: ~Copyable` |
| Copyable conformance | Always (unconditional) | Conditional: `where Underlying: Copyable` |
| ~Copyable tag support | No | Yes — `Index<Element>` where `Element: ~Copyable` |
| ~Copyable wrapped-value support | No | Yes — `Tagged<Tag, Resource>` where `Resource: ~Copyable` |

**Assessment**: This is the most consequential divergence. swift-tagged's implicit `Copyable` constraint on both parameters means it cannot represent indices into containers of move-only types (`Index<MoveOnlyElement>`), nor can it wrap move-only resources. Our `Tag: ~Copyable` constraint on every extension ensures universality — the phantom type system does not silently exclude noncopyable types.

Experiment `tagged-noncopyable-rawvalue` (2026-01-24, CONFIRMED) verified that `Tagged` with `~Copyable` underlying values works correctly with `Equation.Protocol`, `Comparison.Protocol`, and `Hash.Protocol` from the respective primitives packages.

### 2. API Surface

#### Storage and Access

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Storage | `public var rawValue: RawValue` | `@usableFromInline package var _storage: Underlying` |
| Read access | Direct property access | Read-only `_read` coroutine on the `underlying` Carrier witness |
| Write access | Direct property access | None public; `package mutating modify(_:)` for in-package mutation |
| Package mutation | N/A | `package mutating func modify(_:)` |
| `@inlinable` | Not applied | Applied to all public API |
| `@usableFromInline` | Not needed (storage is public) | Applied to `_storage` |

swift-tagged exposes storage as a `public var`, which is the simplest approach but prevents future storage changes without ABI breakage. Our implementation uses `_read`/`_modify` coroutines for zero-copy access while keeping `_storage` internal. The `@inlinable` + `@usableFromInline` combination enables cross-module inlining, which is critical for the zero-cost guarantee.

#### Initialization

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Primary init | `init(rawValue:)` | `init(_ underlying:)` (public, supplied by `Carrier.\`Protocol\``) + `init(_unchecked:)` (public bypass init) |
| Convenience init | `init(_ rawValue)` (positional) | The Carrier-derived `init(_:)` IS the canonical public construction path |
| `consuming` parameter | No | Yes |
| `RawRepresentable` | Yes (conforms) | No |

The `_unchecked:` label signals that the initializer bypasses any Carrier-derived validation — the consumer is asserting the value is already suitable. The leading underscore + the explicit `_unchecked` label are sufficient hygiene for this; the access modifier is `public` so legitimate cross-package consumers (notably `Property.View`, which wraps `Tagged<Tag, Ownership.Inout<Base>>` where `Ownership.Inout` is a scoped projection that fundamentally cannot satisfy `Carrier.\`Protocol\``'s consuming init) can construct without resorting to redesign. The canonical path remains the Carrier-derived `init(_:)` for the common case where `Underlying` is itself a Carrier; `_unchecked:` is the escape hatch for the cases that aren't. swift-tagged's `init(rawValue:)` / `init(_:)` doesn't draw this distinction.

The `consuming` ownership annotation enables move-only underlying values and avoids unnecessary copies.

#### Functor Operations

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| `map` | Instance only: `func map<NewValue>(_ transform:) rethrows` | Static + instance per [IMPL-023] |
| Tag coercion | `func coerced(to:)` via `unsafeBitCast` | `static func retag(_:to:)` + instance `func retag(_:)` |
| Typed throws | `rethrows` | `throws(E)` where `E: Error` |
| `consuming` self | No | Yes |

Key divergences:

- **Static + instance split**: Per [IMPL-023], the static form `Tagged.map(tagged, transform:)` is the implementation; the instance form `tagged.map { }` delegates to it. This supports consuming semantics — the static form takes `consuming Tagged`, which is required for `~Copyable` underlying values where the instance method would need to consume `self`.

- **`retag` vs `coerced(to:)`**: swift-tagged implements tag coercion via `unsafeBitCast(self, to: Tagged<NewTag, RawValue>.self)`. Our `retag` constructs a new `Tagged` from `tagged._storage`, which the optimizer eliminates to the same no-op (verified in experiment `tagged-zero-cost-codegen`). The difference: `unsafeBitCast` is semantically unsafe and compiler-opaque, while our approach is safe Swift that the optimizer can reason about.

- **Typed throws**: Our `throws(E)` preserves the error type through the transform, per [API-ERR-001]. swift-tagged's `rethrows` erases the thrown error type to `any Error`.

#### Dynamic Member Lookup

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| `@dynamicMemberLookup` | Yes | No |

swift-tagged applies `@dynamicMemberLookup` to forward `KeyPath` subscripts to `rawValue`. This enables `tagged.someProperty` syntax without unwrapping. We deliberately omit this — it conflicts with the principle that phantom-typed values should be explicitly unwrapped before accessing underlying value members. Implicit forwarding obscures the type boundary.

### 3. What We Removed and Why

#### 3.1 `RawRepresentable` Conformance

swift-tagged conforms to `RawRepresentable`. We removed it.

**Reason**: `RawRepresentable` implies that `Tagged` is a raw-representable enum or option set. It introduces `init?(rawValue:)` (failable) alongside the non-failable init, creating two construction paths with different semantics. More importantly, `RawRepresentable` constrains its `RawValue: Copyable` (it is not `~Copyable`-aware), which would block our noncopyable support.

#### 3.2 `Strideable` Conformance

swift-tagged conditionally conforms to `Strideable where RawValue: Strideable`.

**Reason**: `Strideable` enables `Tagged` values to be used in `for x in a...b` ranges and implies a linear ordering with uniform stride. This is inappropriate for phantom-typed values — `Index<Graph>` should not be strideable because the stride semantics depend on the domain, not the underlying value. Domain-specific stride operations belong in domain-specific extensions (e.g., `Index Primitives`), not as a blanket forwarding.

#### 3.3 `Numeric` / `AdditiveArithmetic` / `SignedNumeric` Conformances

swift-tagged conditionally conforms to `AdditiveArithmetic`, `Numeric`, and `SignedNumeric`.

**Reason**: This is the operator forwarding problem. If `Tagged<Tag, Int>` conforms to `Numeric`, then `Index<Graph> + Index<Bit>` compiles — both are `Tagged<_, Int>` and `Int: Numeric`. The phantom type is supposed to prevent exactly this mixing. Arithmetic operations must be defined per-domain with matching `Tag` constraints. See documentation: `_Package-Insights.md` § "Tagged's Lack of Operator Forwarding Is a Feature."

#### 3.4 Blanket Literal Conformances (in Production) — UPDATED 2026-04-30

swift-tagged unconditionally provides `ExpressibleByIntegerLiteral`, `ExpressibleByFloatLiteral`, `ExpressibleByBooleanLiteral`, `ExpressibleByStringLiteral`, `ExpressibleByUnicodeScalarLiteral`, `ExpressibleByExtendedGraphemeClusterLiteral`, `ExpressibleByStringInterpolation`, `ExpressibleByArrayLiteral`, and `ExpressibleByDictionaryLiteral`.

**Original framing (2026-02-26)**: literal conformances quarantined to the `Tagged Primitives Test Support` module. The critical finding from `tagged-literal-conformances.md` (v2.0, DECISION) and `tagged-literal-conformances-fresh-perspective.md` was that blanket `ExpressibleByIntegerLiteral` on `Tagged` enables a silent overload-resolution footgun (`.map(Bit.Index.init)` resolves to a cross-domain conversion init, producing silently wrong results and runtime crashes). `@_disfavoredOverload` does not mitigate this because it only affects ranking when multiple candidates apply.

**Current state (2026-04-30, post-SLI)**: literal conformances ship in the opt-in `Tagged Primitives Standard Library Integration` target rather than in main, per [`sli-literal-vs-strideable-tradeoff.md`](./sli-literal-vs-strideable-tradeoff.md) (DECISION 2026-04-30). The trade-off:

- **Strideable** is **excluded from SLI** to keep the literal-conformance footgun dormant for SLI-only consumers (the footgun activates when both Strideable and `ExpressibleByIntegerLiteral` are in the same compilation unit).
- **Literals** ship via SLI; the footgun is residual when consumers also import a package that adds `Strideable` to a Tagged-aliased type (e.g. `swift-index-primitives`'s approved `Index: Strideable`), with narrower blast radius (specific types, not all Tagged).
- **Array + Dictionary literals** ship via a **documented `unsafeBitCast` carve-out** ([`principled-absence-array-dict-literal.md`](./principled-absence-array-dict-literal.md) v1.2.0) — the FIRST AND ONLY exception from the package's `[MEM-SAFE-001]` strict-memory-safety stance, bounded to these two specific bitcast call sites and marked with the `unsafe` expression keyword.

The Test Support module retains the literal ergonomics for tests via `@_exported import Tagged_Primitives_Standard_Library_Integration` in `Tests/Support/exports.swift` — test code's `let t: Tagged<Tag, Int> = 42` form continues to work without source change.

#### 3.5 `_rawValue` (Underscored Public Storage)

swift-tagged exposes `rawValue` as `public var` directly — no underscore. Some versions had `_rawValue` as an implementation detail.

**Reason**: We use `@usableFromInline package var _storage` with `underlying` supplied by the `Carrier.\`Protocol\`` conformance (read-only `_read` coroutine). This separates the storage representation from the access interface, allowing future storage changes without ABI breakage.

#### 3.6 `Collection` / `Sequence` Conformance

swift-tagged conditionally conforms to `Sequence where RawValue: Sequence` and `Collection where RawValue: Collection`.

**Reason**: A `Tagged<Tag, [Int]>` that itself conforms to `Collection` conflates the wrapper with its contents. If you want to iterate the underlying value, unwrap it: `tagged.underlying.forEach { ... }`. Making the wrapper itself iterable obscures the type boundary.

#### 3.7 `Error` / `LocalizedError` Conformance

swift-tagged conditionally conforms to `Error where RawValue: Error` and `LocalizedError` (via Foundation).

**Reason**: `Tagged` wrapping an error type is a niche use case that doesn't fit the primitives layer. The `LocalizedError` conformance requires Foundation, which violates [PRIM-FOUND-001].

#### 3.8 `Identifiable` Conformance

swift-tagged conditionally conforms to `Identifiable where RawValue: Identifiable`.

**Reason**: `Tagged` *is* an identity mechanism. Making it `Identifiable` by forwarding to `underlying.id` creates a semantic confusion — the tag is the identity discriminator, not the underlying value's `id` property. Domain types should conform to `Identifiable` directly.

#### 3.9 `LosslessStringConvertible`

swift-tagged conditionally conforms to `LosslessStringConvertible`.

**Reason**: `LosslessStringConvertible` implies a round-trip guarantee (`init?(_:) → description → init?(_:)`). This guarantee is about the underlying value, not the tagged value. The tag information is lost in the string representation, so the conversion is inherently lossy from the Tagged perspective.

#### 3.10 `CodingKeyRepresentable`

swift-tagged conditionally conforms to `CodingKeyRepresentable`.

**Reason**: Niche use case. Codable support is provided via the simpler `Codable` conditional conformance.

#### 3.11 `BitwiseCopyable`

swift-tagged conditionally conforms to `BitwiseCopyable`.

**Note**: We also conditionally conform to `BitwiseCopyable` (`where Tag: ~Copyable, Underlying: BitwiseCopyable`). This is not a removal — both libraries provide this conformance. The conditional gating on `Underlying: BitwiseCopyable` ensures noncopyable underlying values are not affected.

#### 3.12 `CustomPlaygroundDisplayConvertible`

swift-tagged conforms to `CustomPlaygroundDisplayConvertible`.

**Reason**: Playground-specific API. Not relevant to production primitives infrastructure.

### 4. What We Added and Why

#### 4.1 `@inlinable` on All Public API

Every public function and computed property is marked `@inlinable`. Combined with `@usableFromInline` on `_storage`, this enables complete cross-module inlining. Without this, the optimizer cannot eliminate the wrapper overhead across module boundaries — the "zero-cost" claim requires it.

swift-tagged does not use `@inlinable`, relying on whole-module optimization within the consuming module. This is insufficient for library code consumed as a binary dependency.

#### 4.2 `_read` / `_modify` Coroutines

```swift
public var underlying: Underlying {
    _read { yield _storage }
    _modify { yield &_storage }
}
```

These coroutines provide zero-copy read and write access to the stored value. For large `Underlying` types, this avoids the copy that a simple `get`/`set` pair would introduce. swift-tagged's `public var rawValue` has equivalent performance only because it's a stored property — if it were ever changed to computed, performance would degrade without coroutines.

#### 4.3 `package mutating func modify(_:)`

```swift
package mutating func modify<T>(_ body: (_ underlying: inout Underlying) -> T) -> T
```

Package-internal mutation access for performance-critical paths within the package where wrapping and unwrapping via `underlying` would be suboptimal. The `package` access level restricts this to the defining package, preventing misuse by downstream consumers.

swift-tagged has no equivalent — its `public var rawValue` allows direct mutation by anyone.

#### 4.4 Static + Instance Functor Split

Per [IMPL-023], the canonical implementation is the static form:

```swift
public static func map<E: Error, NewUnderlying: ~Copyable>(
    _ tagged: consuming Tagged,
    transform: (consuming Underlying) throws(E) -> NewUnderlying
) throws(E) -> Tagged<Tag, NewUnderlying>
```

The instance form delegates:

```swift
public consuming func map<E: Error, NewUnderlying: ~Copyable>(
    _ transform: (consuming Underlying) throws(E) -> NewUnderlying
) throws(E) -> Tagged<Tag, NewUnderlying> {
    try Self.map(self, transform: transform)
}
```

This split enables `consuming` semantics for `~Copyable` underlying values in the static form, while the instance form provides ergonomic call-site syntax. swift-tagged has only the instance form.

#### 4.5 `retag` (Safe Tag Coercion)

```swift
public static func retag<NewTag: ~Copyable>(
    _ tagged: consuming Tagged,
    to _: NewTag.Type = NewTag.self
) -> Tagged<NewTag, Underlying>
```

This replaces swift-tagged's `coerced(to:)`, which uses `unsafeBitCast`. Our implementation constructs a new `Tagged` from `tagged._storage`, which is safe Swift that the optimizer eliminates entirely. The name `retag` is more precise than `coerced` — it changes the phantom tag, not the value.

#### 4.6 `~Copyable` Support Throughout

Every extension specifies `Tag: ~Copyable` and `Underlying: ~Copyable` (or `Underlying: Copyable` for conformances that require it). This ensures the phantom type system does not exclude noncopyable types. swift-tagged has no `~Copyable` awareness.

#### 4.7 Conditional `Copyable` Conformance

```swift
extension Tagged: Copyable where Tag: ~Copyable, Underlying: Copyable {}
```

`Tagged` is `Copyable` when its underlying value is, and `~Copyable` when it isn't. This is the correct conditional behavior for a wrapper type. swift-tagged is unconditionally `Copyable`.

#### 4.8 `Sendable` with `~Copyable` Awareness

```swift
extension Tagged: Sendable where Tag: ~Copyable, Underlying: ~Copyable & Sendable {}
```

The `Tag: ~Copyable` ensures `Sendable` conformance applies to all tags, and `Underlying: ~Copyable & Sendable` enables sendable noncopyable underlying values. swift-tagged requires `Underlying: Sendable` (implicitly `Copyable`).

#### 4.9 `#if !hasFeature(Embedded)` Guard on Codable

```swift
#if !hasFeature(Embedded)
    extension Tagged: Codable where Tag: ~Copyable, Underlying: Codable {}
#endif
```

Embedded Swift has no Codable support. This guard prevents compilation failures in embedded contexts. swift-tagged has no embedded awareness.

#### 4.10 `static func max(_:_:)` / `static func min(_:_:)`

```swift
public static func max(_ a: Self, _ b: Self) -> Self
public static func min(_ a: Self, _ b: Self) -> Self
```

Convenience functions that avoid verbose `Swift.max(a, b)` type annotations that the compiler often requires for `Tagged` types. swift-tagged does not provide these.

### 5. What They Have That We Don't — UPDATED 2026-04-30

Per the per-protocol absence catalog (`Research/principled-absence-*.md`, 10 docs + 10 experiments authored 2026-04-30), each absence has been empirically verified. The "Where it lives now" column reflects the current package state (SLI-shipped vs absent).

| swift-tagged Feature | Where it lives now (2026-04-30) | Reason | Doc |
|---------------------|-------------------------------|--------|----|
| `@dynamicMemberLookup` | **Absent everywhere** | HARD: type-declaration attribute, not retroactively applicable via extension | [doc](./principled-absence-dynamicmemberlookup.md) |
| `RawRepresentable` | **Absent everywhere** | HARD: structural Swift-level blocker — protocol not `~Escapable`-aware; Tagged's structural `~Escapable` propagates through synthesized underlying getter witness | [doc](./principled-absence-rawrepresentable.md) |
| `Strideable` | **Absent everywhere (SLI-excluded by policy)** | SOFT structurally; SLI-excluded per `sli-literal-vs-strideable-tradeoff.md` (literal-conformance footgun trade-off) | [doc](./principled-absence-strideable.md) |
| `Numeric` / `AdditiveArithmetic` / `SignedNumeric` / `BinaryInteger` / `BinaryFloatingPoint` | **Absent everywhere** | SOFT structurally / HARD semantically — operator-forwarding footgun across all Tagged in compilation unit; per-domain conformance is the correct alternative | [doc](./principled-absence-additivearithmetic-family.md) |
| `Collection` / `Sequence` | **Shipped in SLI** | SOFT — wrapper-vs-content conflation cost is the consumer's accepted trade-off when importing SLI | [doc](./principled-absence-sequence-collection.md) |
| `Error` / `LocalizedError` | **Absent everywhere** | HARD-by-axiom: Foundation forbidden per `[PRIM-FOUND-001]` | [doc](./principled-absence-foundation-protocols.md) |
| `Identifiable` | **Shipped in SLI** | SOFT — identity-inversion cost documented; Tagged-as-id is the recommended pattern | [doc](./principled-absence-identifiable.md) |
| `LosslessStringConvertible` | **Shipped in SLI** | SOFT — lossy-from-Tagged-perspective cost; per-domain wrapper for cross-process serialization | [doc](./principled-absence-losslessstringconvertible.md) |
| `CodingKeyRepresentable` | **Absent everywhere** | HARD: niche — `Codable` already covers Tagged-as-value | [doc](./principled-absence-niche-protocols.md) |
| `BitwiseCopyable` | Yes (conditional, in main) | **Shared** — both libraries provide this conformance |  |
| `CustomPlaygroundDisplayConvertible` | **Absent everywhere** | HARD: niche / deprecated — `CustomStringConvertible` (in main) covers playground display | [doc](./principled-absence-niche-protocols.md) |
| Blanket integer / float / boolean / unicode-scalar / extended-grapheme / string literal conformances | **Shipped in SLI** | SOFT via SLI; `Strideable` correspondingly excluded to keep the literal-conformance footgun dormant | [tradeoff](./sli-literal-vs-strideable-tradeoff.md) |
| `ExpressibleByStringInterpolation` | **Shipped in SLI** | (with the literal family) |  |
| `ExpressibleByArrayLiteral` | **Shipped in SLI via documented `unsafeBitCast` carve-out** | SOFT-via-carve-out; the FIRST AND ONLY documented exception from `[MEM-SAFE-001]`, bounded scope, marked with `unsafe` keyword | [doc](./principled-absence-array-dict-literal.md) v1.2.0 |
| `ExpressibleByDictionaryLiteral` | **Shipped in SLI via documented `unsafeBitCast` carve-out** | (same carve-out as Array literal) | [doc](./principled-absence-array-dict-literal.md) v1.2.0 |
| `UUID` convenience inits | **Absent everywhere** | HARD-by-axiom: Foundation forbidden per `[PRIM-FOUND-001]` | [doc](./principled-absence-foundation-protocols.md) |
| TaggedMoney / TaggedTime nanolibraries | **Out of scope** | Domain-specific, not a primitives concern |  |
| Decodable fallback (`try Underlying(from: decoder)`) | **Absent everywhere** | HARD: anti-pattern — masks decoding errors; our simple conditional `Codable` is correct | [doc](./principled-absence-niche-protocols.md) |

**Assessment**: each absence was empirically verified in 2026-04-30 per-protocol experiments. The earlier (2026-02-26) characterization "Every absent feature is a principled removal" remains accurate, but the catalog now distinguishes:
- **HARD absences** (RawRepresentable, AdditiveArithmetic family, @dynamicMemberLookup, Foundation deps, niche/anti-pattern protocols, Strideable excluded by literal-trade-off policy) — never authorable by SLI; consumers' alternative is per-domain wrapper or canonical-init.
- **SOFT absences shipped in SLI** (Identifiable, LosslessStringConvertible, Sequence/Collection, Literals, Array/Dict via carve-out) — opt-in via `import Tagged_Primitives_Standard_Library_Integration`, with documented trade-off costs at each conformance.

### 6. Zero-Cost Verification

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Claim | "zero-cost" (README, documentation) | "zero-cost" (documentation) |
| `@inlinable` | Not applied | Applied to all public API |
| `@usableFromInline` | Not needed (public storage) | Applied to `_storage` |
| Assembly verification | None published | Experiment `tagged-zero-cost-codegen` (CONFIRMED, 2026-02-26) |
| MemoryLayout tests | None | 7 MemoryLayout proof tests (Int, UInt8, Double, Bool, UInt64, cross-tag, noncopyable) |

swift-tagged claims zero-cost but provides no proof. Their `public var rawValue` makes within-module optimization trivial, but cross-module consumers cannot verify the claim without `@inlinable`.

Our verification is rigorous:

**MemoryLayout proofs** (in test suite): Six tests verify that `Tagged<Tag, T>` has identical `size`, `stride`, and `alignment` to `T` for `Int`, `UInt8`, `Double`, `Bool`, `UInt64`, and a noncopyable `Resource` struct. A seventh test verifies that different tags produce identical layout.

**Codegen proof** (experiment `tagged-zero-cost-codegen`, Swift 6.2, -O): Four function pairs comparing Tagged paths to raw paths produced identical assembly:

| Function | Assembly |
|----------|----------|
| `rawTagged()` | `mov w0, #0x2a; ret` |
| `rawDirect()` | `mov w0, #0x2a; ret` |
| `retagTagged()` | `mov w0, #0x2a; ret` |
| `compareTagged()` | `mov w0, #0x1; ret` |
| `compareDirect()` | `mov w0, #0x1; ret` |
| `mapIdentityTagged()` | `mov w0, #0x2a; ret` |
| `mapIdentityDirect()` | `mov w0, #0x2a; ret` |

Every Tagged operation — init, underlying access, retag, Comparable delegation, map with identity — compiles to identical instructions as the raw equivalent.

### 7. Test Coverage

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Framework | XCTest | Swift Testing |
| Test count | ~20 tests | 54 tests |
| Test structure | Flat `XCTestCase` | Nested `@Suite` (Unit / EdgeCase / Integration / Performance) |
| MemoryLayout proofs | None | 7 tests (5 types + cross-tag + noncopyable) |
| Functor laws | None | Identity law + composition law |
| Total order properties | None | Irreflexivity, asymmetry, transitivity, equality-implies-not-less-than |
| ~Copyable paths | None | 5 tests (init, map, retag, modify, MemoryLayout) |
| Static/instance equivalence | None | 2 tests (map, retag) |
| Functor composition | None | 3 tests (map→retag, retag→map, order independence) |
| Throwing map | None | 1 test (error propagation) |
| Boundary values | None | 3 tests (zero, negative, empty string) |
| Collection interop | None (beyond Collection conformance) | 2 tests (sorted array, Set deduplication) |
| Codable tests | 6 tests (encode/decode/custom dates/optional/CodingKey) | Via conditional `Codable` conformance |
| Foundation-dependent tests | Yes (JSON, Date, UUID) | None (Foundation-free) |

swift-tagged's tests focus on conformance verification ("does it compile and produce the right value?"). Our tests additionally verify mathematical properties (functor laws, total order), layout invariants (MemoryLayout), and the `~Copyable` code paths that swift-tagged cannot test.

### 8. Ecosystem Integration

| Aspect | swift-tagged | swift-tagged-primitives |
|--------|-------------|--------------------------|
| Literal conformances | Production (blanket) | Opt-in via `Tagged Primitives Standard Library Integration` |
| Downstream operator pattern | Auto-forwarded via `Numeric`/`AdditiveArithmetic` | Per-domain with matching `Tag` constraints |
| Foundation dependency | Yes (`#if canImport(Foundation)` for UUID, LocalizedError) | No (Foundation-free per [PRIM-FOUND-001]) |
| Domain nanolibraries | TaggedMoney, TaggedTime (in same repo) | Domain types in separate primitives packages |
| Companion modules | None | `Tagged Primitives Standard Library Integration` (opt-in literals + Sequence/Collection/Identifiable/LosslessStringConvertible) |

The ecosystem integration philosophies differ fundamentally:

**swift-tagged**: Maximize convenience. Provide every conformance that could be useful. Let Tagged work as a drop-in substitute for the underlying value in most contexts. Trade type safety for ergonomics where the two conflict (arithmetic, literals, dynamic member lookup).

**swift-tagged-primitives**: Maximize type safety in the main target. Provide only conformances that preserve the phantom type's discrimination guarantee. Require explicit domain-specific extensions for operations that depend on the tag. Make convenience conformances (literals, Sequence/Collection, Identifiable, LosslessStringConvertible) opt-in via a separate Standard Library Integration target. The result is more boilerplate for domain types but stronger compile-time guarantees by default.

The `Tagged Primitives Standard Library Integration` target is the key architectural difference. By isolating opt-in conformances to a separate import (`import Tagged_Primitives_Standard_Library_Integration`), consumers explicitly choose the trade-off — `Strideable` is correspondingly excluded from SLI to keep the literal-conformance footgun (documented in `tagged-literal-conformances.md`) dormant. Test code re-exports SLI via `Tests/Support/exports.swift`, so test ergonomics (`let x: Tagged<Tag, Int> = 42`) remain available without main-target contamination.

## Comparison Summary

| Dimension | swift-tagged | swift-tagged-primitives |
|-----------|-------------|--------------------------|
| Philosophy | Convenience-first | Safety-first |
| `~Copyable` | Not supported | Full support (Tag + Underlying) |
| Inlining | No `@inlinable` | All public API `@inlinable` |
| Zero-cost proof | Claimed, not verified | Claimed and verified (assembly + MemoryLayout) |
| Operator forwarding | Blanket (`Numeric`, etc.) | Per-domain with Tag matching |
| Literal conformances | Production (blanket) | Test support only (quarantined) |
| Tag coercion | `unsafeBitCast` | Safe construction (optimizer-eliminated) |
| Error typing | `rethrows` (erased) | `throws(E)` (preserved) |
| Foundation dependency | Yes | No |
| Test rigor | Conformance verification | Mathematical properties + layout proofs |
| Conformance count | ~25 conditional conformances | 8 conditional conformances in main, additional opt-in via SLI |
| Source files | 2 (+ 2 nanolibraries) | Main + Standard Library Integration target |

> Note: The 8 conditional conformances are: Copyable, Sendable, BitwiseCopyable, Equatable, Hashable, Codable, Comparable, and CustomStringConvertible.

## Outcome

**Status**: DECISION

**Decision**: The divergences from swift-tagged are principled and should be maintained.

Every removal is justified by either:
1. **Type safety** — the conformance undermines phantom type discrimination (Numeric, Strideable, Sequence/Collection, dynamicMemberLookup, blanket literals)
2. **Foundation independence** — the conformance requires Foundation (LocalizedError, UUID, playground display) [PRIM-FOUND-001]
3. **Semantic precision** — the conformance creates misleading API surface (RawRepresentable, Identifiable, LosslessStringConvertible)
4. **~Copyable compatibility** — the conformance constrains to Copyable (RawRepresentable, BitwiseCopyable)

Every addition is justified by either:
1. **Zero-cost guarantee** — `@inlinable`, `@usableFromInline`, `_read`/`_modify` coroutines
2. **~Copyable support** — `consuming` parameters, conditional `Copyable`, Tag/Underlying `~Copyable`
3. **Type-safe operations** — static+instance functor split, safe `retag`, `package modify(_:)`
4. **Error precision** — typed throws per [API-ERR-001]

The two libraries serve different audiences. swift-tagged optimizes for adoption and convenience in application code. swift-tagged-primitives optimizes for correctness and composability in infrastructure code. Neither approach is wrong — they reflect different design priorities for different layers of the software stack.

## References

- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift` — our implementation
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged+CustomStringConvertible.swift` — our description conformance
- `swift-tagged-primitives/Sources/Tagged Primitives Standard Library Integration/` — opt-in literal/Sequence/Collection/Identifiable/LosslessStringConvertible conformances
- `swift-tagged-primitives/Tests/Support/exports.swift` — re-exports SLI for test ergonomics
- `swift-tagged-primitives/Tests/Tagged Primitives Tests/Tagged Tests.swift` — 54 tests
- `swift-tagged-primitives/Experiments/tagged-zero-cost-codegen/` — codegen verification (CONFIRMED)
- `swift-tagged-primitives/Experiments/tagged-noncopyable-rawvalue/` — ~Copyable verification (CONFIRMED)
- `swift-tagged-primitives/Research/tagged-literal-conformances.md` — literal conformance analysis (DECISION)
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged Primitives.docc/Tagged.md` — theoretical foundation
- `swift-tagged-primitives/Research/_Package-Insights.md` — operator non-forwarding rationale
- [pointfreeco/swift-tagged](https://github.com/pointfreeco/swift-tagged) `Sources/Tagged/Tagged.swift` — their implementation
- [pointfreeco/swift-tagged](https://github.com/pointfreeco/swift-tagged) `Tests/TaggedTests/TaggedTests.swift` — their tests
- [Point-Free Episode #12](https://www.pointfree.co/episodes/ep12-tagged) — original presentation
