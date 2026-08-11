# swift-affine-primitives — rawValue → underlying rename design

**Status**: DEFERRED (status updated 2026-05-09 per cohort-wide amendment C1)
**Date**: 2026-05-03
**Cycle**: Downstream of `swift-tagged-primitives@46ded75` + `swift-carrier-primitives@2b57aac` + cardinal/ordinal precedent (`ac7f308` / `e42df9f`).

## Resolution (2026-05-09)

Cohort-wide policy C1 (data-structures cohort, Story 1 readiness): defer the rename. Story 1 (cardinal / ordinal / affine) launches at the current `rawValue` shape; the rename is scheduled but unscoped for a future major version. The trivial-self-carrier shape (`Affine.Discrete.Vector.Underlying = Affine.Discrete.Vector`) is preserved across 0.x for cohort coherence — cascading the rename mid-readiness destabilizes three packages, and the cosmetic critique is recoverable post-launch. The framing supporting this position: *cardinal, ordinal, and affine are three kinds of number, not Int wrappers* — the trivial-self-carrier shape is consistent with the trichotomy framing of the cohort.

The analysis below remains the canonical reference for what the rename *would* entail when it eventually lands. It is preserved for the future revisit; the cascade-implications and mechanical-rename-scope sections are the load-bearing artifacts.

## Q1 — Own `public let rawValue` types

YES — `Affine.Discrete.Vector` has a public stored `rawValue: Int`. Pre-authorized for rename per the v3 cycle brief.

**Current shape** (about to be rewritten):
```swift
extension Affine.Discrete {
    public struct Vector: Hashable, Comparable, Sendable {
        public let rawValue: Int
        @inlinable public init(_ rawValue: Int) { self.rawValue = rawValue }
        // ...explicit ==, <, <=, >, >= reading rawValue
    }
}
```

**Sibling `Carrier` conformance** (current — trivial self-carrier, `Underlying = Self`):
```swift
extension Affine.Discrete.Vector: Carrier {
    public typealias Underlying = Affine.Discrete.Vector
    // underlying + init(_:) inherited from `Carrier where Underlying == Self`
}
```

**Plan** — mirror cardinal/ordinal precedent exactly, but over `Int` (not `UInt`):

```swift
extension Affine.Discrete {
    @frozen
    public struct Vector {
        @usableFromInline
        let _storage: Int
    }
}

extension Affine.Discrete.Vector: Hashable {}
extension Affine.Discrete.Vector: Comparable {}
extension Affine.Discrete.Vector: Sendable {}

// In Affine.Discrete.Vector+Carrier.swift:
extension Affine.Discrete.Vector: Carrier.`Protocol` {
    public typealias Underlying = Int
    @inlinable public var underlying: Int { _read { yield _storage } }
    @inlinable public init(_ underlying: consuming Int) { self._storage = underlying }
}
```

The signed underlying carries through. Per the brief, `@_lifetime` annotations are NOT repeated — they are inherited from `_CarrierProtocol`.

**Cascade implications for the existing `Carrier where Underlying == Affine.Discrete.Vector` extensions** (in `Affine.Discrete.Vector+Carrier.swift`):
- These extensions currently apply to `Tagged<Tag, Affine.Discrete.Vector>` (via Tagged's unconditional `Carrier.Protocol<Affine.Discrete.Vector>` conformance) AND to bare `Affine.Discrete.Vector` (since under the old shape, bare Vector IS its own `Underlying`).
- After the rename, bare Vector has `Underlying == Int`, so it no longer satisfies `where Underlying == Affine.Discrete.Vector`. The existing extensions become Tagged-only.
- The bare-Vector path needs re-anchored constants (`.zero`, `.one`) and arithmetic (`+`, `-`, `+=`, `-=`, prefix `-`) on the concrete type — exact precedent: `Cardinal+Carrier.swift` declares bare `.zero`/`.one` on `extension Cardinal {}` and lifts via `extension Carrier.\`Protocol\` where Underlying == Cardinal {}`.
- Same pattern: declare bare `Affine.Discrete.Vector` arithmetic + constants on the concrete type, AND keep the `Carrier.\`Protocol\` where Underlying == Affine.Discrete.Vector` extensions for the Tagged<Tag, Vector> path.

## Q2 — Editorial public surface that should move

Reviewed the four targets:

- `Affine Namespace` — just declares `public enum Affine {}`. Fine.
- `Affine Primitives Core` — Vector, Ratio, arithmetic, error. Tagged+Affine.swift contains Tagged-shape extensions; correct because Tagged is a `public import`. No editorial surface to move.
- `Affine Primitives Standard Library Integration` — `Int+Affine.Discrete.Vector.swift`, `RandomAccessCollection+Tagged.Ordinal.Offset.swift`, `UnsafePointer+Tagged.Ordinal.swift`, `UnsafeMutablePointer+Tagged.Ordinal.swift`. All correct SLI placement.
- `Affine Primitives` (umbrella) — `@_exported public import` of Core + SLI. Standard pattern.

**Verdict**: No move-to-sibling-target / SLI escalation needed.

## Q3 — Three-consumer rule

Public surface in Core:
- `Affine.Discrete.Vector` itself + Hashable/Comparable/Sendable
- `Affine.Discrete.Vector.Error.unrepresentable`
- `Affine.Discrete.Ratio<From, To>` + `factor`, `init(_:)`, `init(_ count: Tagged<To, Cardinal>)`, `quotientAndRemainder(...)` overloads
- `Affine.Discrete` namespace
- Generic affine arithmetic: `+(O, Carrier<Vector>)`, `-(O, Carrier<Vector>)`, `-(O, O) → Vector`, `+=`, `-=`
- Cross-type Cardinal↔Vector comparisons (`<`, `<=`, `>`, `>=`) gated by `V.Domain == C.Domain`
- Tagged extensions for Vector/Ordinal/Cardinal interop
- Ordinal init from Vector
- Pointer + offset, RandomAccessCollection.index(_:offsetBy:)

The Vector type itself is THE foundational vocabulary type for affine displacements; it is consumed by every Tagged<Tag, Ordinal>.Offset alias and every cross-package consumer doing affine arithmetic on indices. The init/accessors/operators are all load-bearing.

**Verdict**: Three-consumer rule satisfied across the surface. No prunable surface.

## Q4 — Compound identifiers / `*Tag` suffix / code-surface violations

- No compound public identifiers found. All names follow `Nest.Name` (`Affine.Discrete.Vector`, `Affine.Discrete.Ratio`, `Affine.Discrete.Vector.Error`).
- No `*Tag` suffix anywhere.
- One type per file: confirmed (`Affine.Discrete.Vector.swift`, `Affine.Discrete.Vector.Error.swift`, `Affine.Discrete.Ratio.swift`, `Affine.Discrete.swift`).
- Typed throws used throughout (`throws(Ordinal.Error)`, `throws(Affine.Discrete.Vector.Error)`, `throws(Cardinal.Error)`).

**Verdict**: Clean. No violations.

## Mechanical rename scope

Within this package, the substitutions to apply:

1. `.rawValue` (read site) → `.underlying` — applies to `Cardinal`, `Ordinal`, and (newly) `Affine.Discrete.Vector`. For Tagged, also `.underlying`.
2. `Tagged where RawValue == X` → `Tagged where Underlying == X` (already partially applied — `Tagged where Underlying == Cardinal` etc. already in Tagged+Cardinal.swift, but `Tagged+Affine.swift` still uses `RawValue ==`).
3. `init(_unchecked: (), value)` → `init(_unchecked: value)` (single labeled arg).
4. `count.cardinal` (legacy bare per-type accessor on Cardinal) → already gone in upstream cardinal package. Replace with `.underlying`.
5. Vector own field: `rawValue` → `_storage` (internal/`@usableFromInline`), exposed via Carrier-derived `underlying`.
6. The five comparison operators in `Affine.Discrete.Vector.swift` read `lhs.rawValue` / `rhs.rawValue` — become `lhs._storage` / `rhs._storage`.
7. `description` reads `rawValue` → reads `_storage` (or `underlying`).
8. `magnitude` computed property reads `rawValue.magnitude` → `_storage.magnitude`.
9. `init(_ rawValue: Int)` becomes `init(_ underlying: consuming Int)` (Carrier-derived).
10. Existing `Carrier where Underlying == Affine.Discrete.Vector` extensions in `Affine.Discrete.Vector+Carrier.swift`: bodies use `lhs.vector.rawValue` → become `lhs.vector.underlying` (Vector's own `underlying: Int`). Note: `vector` here is the per-type synonym accessor on `Carrier where Underlying == Vector` — so for Tagged<Tag, Vector>, `tagged.vector` returns `Vector`, then `.underlying` returns `Int`.
11. Re-anchor `.zero`/`.one`/`+`/`-`/`+=`/`-=` for bare `Vector` (since it now has `Underlying == Int`, the existing `Carrier where Underlying == Vector` extensions no longer cover it).

## Phase 1 verdict

PROCEED to Phase 2. No escalation.
