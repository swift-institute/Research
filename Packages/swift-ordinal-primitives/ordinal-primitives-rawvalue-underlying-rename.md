# Ordinal Primitives — `rawValue` → `underlying` Rename Design Note

**Date**: 2026-05-03 (drafted) / 2026-05-09 (DEFERRED-WITH-RATIONALE per cohort policy C3)
**Status**: DEFERRED-WITH-RATIONALE — rescheduled to a future cohort-wide major-version break.
**Cycle**: Tier 3 cascade-drop downstream migration
**Upstream commits**: tagged@`46ded75`, carrier@`2b57aac`, cardinal@`ac7f308`
**Pass-1 baseline**: `43b5daa` (broken against current upstreams; consumer-side mechanical rename, but missed `Carrier<...>` → `Carrier.\`Protocol\`<...>`, `count.cardinal` → `count.underlying`, and own-field `Ordinal.rawValue`)

## Resolution (2026-05-09)

Cohort policy C3 (2026-05-09 release-readiness dispatch for the data-structures launch cohort) defers this rename:

- `Ordinal` keeps `public let rawValue: UInt` across the 0.x line.
- The trivial-self-Carrier shape (`Underlying = Ordinal`) is preserved, mirroring cardinal's same-decision.
- The `rawValue` → `underlying` rename, the `_storage`-private collapse, and the cascade through Standard Library Integration / Tests is rescheduled to a future cohort-wide major-version break — when cardinal / ordinal / affine coordinate a joint break, not unilaterally.

Rationale for deferral:

- Without tags (per `feedback_no_tags_in_current_plan`), there is no SemVer-breaking concern; the deferred rename is a freedom, not a risk.
- The cosmetic critique surfaced by forums-review reception (a name-shape mismatch between Ordinal's `rawValue` and the upstream Carrier protocol's `underlying`) is recoverable post-launch.
- Cascading the rename mid-readiness destabilizes three packages (cardinal + ordinal + affine) at once; the joint-break model lands a single coordinated breaking change later, not three rolling ones now.

The mechanical-change matrix below remains accurate as the FUTURE plan; it is preserved here as the canonical reference for when the rename does land. No code changes apply this design note in its current form.

---

## Q1 — Own `public let rawValue` types

**Status**: One. `Ordinal.rawValue: UInt` (`Sources/Ordinal Primitives Core/Ordinal.swift:41`).

**Plan** (mirrors cardinal `ac7f308` exactly):

```swift
@frozen
public struct Ordinal {
    /// The underlying unsigned integer storage.
    ///
    /// Exposed publicly via the `Carrier.\`Protocol\``-derived
    /// `underlying: UInt` accessor in `Ordinal+Carrier.swift`.
    @usableFromInline
    let _storage: UInt
}

extension Ordinal: Carrier.`Protocol` {
    public typealias Underlying = UInt

    @inlinable
    public var underlying: UInt {
        _read { yield _storage }
    }

    @inlinable
    public init(_ underlying: consuming UInt) {
        self._storage = underlying
    }
}
```

The current `extension Ordinal: Carrier.\`Protocol\` { typealias Underlying = Ordinal }` (trivial-self-Carrier shape) is REPLACED by the non-trivial `Underlying = UInt` shape — same collapse cardinal performed.

`@_lifetime(borrow self)` and `@_lifetime(copy underlying)` are NOT repeated: they are inherited from `_CarrierProtocol`'s requirement signatures (per dispatch instruction).

`Hashable`/`Comparable`/`Sendable` conformances stay where they are; their bodies (rewrite to `lhs._storage < rhs._storage` etc.) are mechanical.

**Constants**: `static var zero` re-anchors on bare `Ordinal` (used by both `Ordinal.zero` and `Tagged<Tag, Ordinal>.zero` via the existing Tagged-`where Underlying == Ordinal` extension which already says `.init(_unchecked: .zero)`). No `static var one` exists on `Ordinal` (semantically `Ordinal.zero` is the only canonical anchor; advances are computed). No additional `extension Carrier.\`Protocol\` where Underlying == Ordinal` lift is needed for constants — `.zero` is bare-Ordinal-only by design.

**`init(_ value: UInt)`** is the same signature as the Carrier-required `init(_ underlying: consuming UInt)`; the Carrier conformance subsumes it. The current free-standing `init(_ value: UInt)` is removed.

**`init(_ ordinal: Ordinal)` on `Ordinal.\`Protocol\`** (identity init): kept on the bare-Ordinal `Ordinal.\`Protocol\`` conformance (the protocol still requires `init(_ ordinal: Ordinal)` distinct from the Carrier init — the protocol is a SIBLING, not Carrier-derived).

**`var ordinal: Ordinal { self }`** on bare `Ordinal` and **`var ordinal: Ordinal { underlying.ordinal }`** on `Tagged: Ordinal.\`Protocol\``: kept verbatim (these are `Ordinal.\`Protocol\``-protocol-required, not Carrier-derived, and they return `Ordinal` not `UInt`).

**No `var position: Ordinal` synonym lift needed**: `Tagged<Tag, Ordinal>` already has `var position: Ordinal { underlying }` in `Tagged+Ordinal.swift` (and after the rename, `.underlying` correctly returns `Ordinal` per Tagged's immediate Carrier shape). The accessor stays — it's a domain-meaning rename ("position", not "underlying"), not a redundant cardinal-style synonym.

## Q2 — Editorial public surface

**Status**: No moves required.

The SLI target hosts `Int+Ordinal.swift`, `Atomic+Ordinal.swift`, `*Span+Tagged.Ordinal.swift`, `Unsafe*Pointer+Ordinal.swift` — all properly placed: they bridge stdlib types (`Int`, `Synchronization.Atomic`, `Span`, `MutableSpan`, `OutputSpan`, `UnsafePointer` family) to Ordinal/Tagged. Removing the SLI target would forbid those bridges; the split is correct.

Ordinal-Cardinal cross-type operators in `Ordinal Primitives Core/Ordinal+Cardinal.swift` belong in Core (both types are core L1 vocabulary, no stdlib coupling).

## Q3 — Three-consumer rule

Reviewed each public init/accessor/method:

| Member | Conformer/Caller sites |
|---|---|
| `Ordinal.init(_ value: UInt)` | All ordinal construction; consumers everywhere |
| `Ordinal.zero` | `Tagged<_, Ordinal>.zero`, tests, downstream |
| `Ordinal.successor/predecessor/advance/distance/retreat` | Distinct policy accessors, all used in tests + downstream |
| `Ordinal.Protocol.+/+=` | Used by both bare Ordinal and `Tagged<_, Ordinal>` |
| Cross-type `<`,`>`,`<=`,`>=`,`+`,`%` | Free-function form for arbitrary `Carrier.\`Protocol\`<Cardinal>` pairing |
| `init(_ count: Cardinal)` and `Cardinal.init(_ position: Ordinal)` | Cross-type conversion |
| Tagged `var position: Ordinal` | Tagged-specific accessor |

All public surface has multiple expected consumers (in-package + downstream tier 4-5 consumers via `swift-index-primitives`, `swift-buffer-primitives`). No surface to prune.

## Q4 — Compound identifiers, `*Tag` suffixes, code-surface violations

- **Compound identifiers**: None. All multi-word concepts are nested (`Ordinal.Successor`, `Ordinal.Predecessor`, `Ordinal.Advance`, `Ordinal.Retreat`, `Ordinal.Distance`, `Ordinal.Error`, `Ordinal.\`Protocol\``).
- **`*Tag` suffix**: None. Tag types are `Successor`, `Predecessor`, etc. — bare nouns inside `Ordinal`, no `*Tag` suffix.
- **Specification mirroring**: N/A (Ordinal is original vocabulary, not a specification implementation).
- **One type per file**: Verified across all source files.
- **Typed throws**: All throwing functions use `throws(Ordinal.Error)` or `throws(E)` where `E: Error` is a generic param. No erased `throws`.

No code-surface violations.

## Verdict

PASS — proceed to Phase 2 mechanical + own-field rename. No escalation.

## Phase 2 — Discovered design issue & resolution

During mechanical migration, the cascade-drop surfaced a structural break in `Ordinal.\`Protocol\``.Count's upper bound:

**Pre-cascade**: `associatedtype Count: Carrier<Cardinal>` matched both bare `Cardinal` (trivial-self-Carrier shape, `Underlying == Cardinal`) and `Tagged<T, Cardinal>` (conditional Carrier).

**Post-cascade**:
- `Cardinal: Carrier.\`Protocol\`` now has `Underlying == UInt` (not `Underlying == Cardinal`); cardinal collapsed the trivial-self shape into the proper non-trivial form.
- `Tagged<T, Cardinal>: Carrier.\`Protocol\`` has `Underlying == Cardinal` (immediate).

Therefore `Count: Carrier.\`Protocol\`<Cardinal>` would EXCLUDE bare `Cardinal` (the Count for bare `Ordinal`).

**Resolution applied** (mirroring how cardinal split its lifts):

1. Drop the upper bound on `Count`: `associatedtype Count` (unconstrained).
2. Split the typed-advance operator into two specialized extensions on `Ordinal.\`Protocol\``:
   - `where Count == Cardinal { static func + (Self, Cardinal) -> Self }` — bare path; reads `rhs.underlying: UInt`.
   - `where Count: Carrier.\`Protocol\`<Cardinal> { static func + (Self, Count) -> Self }` — Tagged path; reads `rhs.underlying: Cardinal`, then `.underlying: UInt`.
3. Apply the same split to `Property where Tag == Ordinal.Distance, Base.Count == Cardinal` vs `… Base.Count: Carrier.\`Protocol\`<Cardinal>` for `forward(to:) -> Base.Count`.
4. Apply the same split to `Range<Bound: Ordinal.\`Protocol\`>.count` and `init(start:count:)` in the SLI target.
5. `Property where Tag == Ordinal.Advance` exposes `saturating(by:)`/`exact(by:)`/`clamped(by:to:)` as a pair: a primary overload taking bare `Cardinal` and a `@_disfavoredOverload` taking `some Carrier.\`Protocol\`<Cardinal>` that delegates through `count.underlying`. This preserves the prior call site shape for both bare and Tagged callers.

This deviates from the dispatch's "exact mirror of cardinal" only insofar as cardinal had no analog of `Count: Carrier<Cardinal>` to migrate; the split-by-where-clause is the natural way to preserve the original semantics under the cascade-drop. No new public types or protocols were introduced.

## Mechanical change matrix

| Pattern | Sites | Replacement |
|---|---|---|
| `public let rawValue: UInt` declaration in Ordinal.swift | 1 | `@usableFromInline let _storage: UInt` |
| `init(_ value: UInt) { self.rawValue = value }` | 1 | dropped (Carrier-derived) |
| In-package read `ordinal.rawValue` (Ordinal Primitives Core) | many | `ordinal._storage` for bare Ordinal sites; `count.underlying` where `count` is a generic `Carrier.\`Protocol\`<Cardinal>` |
| `lhs.cardinal.rawValue` / `count.cardinal.rawValue` (Cardinal field-rawValue + cardinal-accessor) | 8 | `lhs.underlying` / `count.underlying` (Cardinal `.underlying` is `UInt`) |
| `count.rawValue` on `Cardinal` (Ordinal.Retreat.swift) | 4 | `count.underlying` |
| `some Carrier<Cardinal>` (parameter shape) | 5 | `some Carrier.\`Protocol\`<Cardinal>` |
| `O: Ordinal.\`Protocol\`, C: Carrier<Cardinal>` (generic constraint) | 9 | `C: Carrier.\`Protocol\`<Cardinal>` (and on `Self.Count` too) |
| `Base.Count(Cardinal(other.ordinal.rawValue - base.ordinal.rawValue))` | 2 | `Base.Count(Cardinal(other.ordinal._storage - base.ordinal._storage))` (in-package, Core) |
| `Tagged<T, Ordinal>.Count(Cardinal(other.ordinal.rawValue - base.ordinal.rawValue))` (in `Tagged+Ordinal.Distance.swift` — non-Core) | 1 | `Tagged<T, Ordinal>.Count(Cardinal(other.ordinal.underlying - base.ordinal.underlying))` (cross-target read; uses public `.underlying`) |
| `count.cardinal` (Tagged-derived accessor) in SLI files | 7 | `count.underlying` (Tagged's `.underlying` returns Cardinal — `Tagged<Tag, Cardinal>.Underlying == Cardinal`) |
| `value.rawValue` / `position.rawValue` in SLI (`Ordinal+AtomicRepresentable`, `Int+Ordinal`) | 6 | `value.underlying` / `position.underlying` (cross-target — SLI imports Ordinal Primitives Core, uses public API) |
| `value.ordinal.rawValue` (`Tagged+Ordinal.AtomicRepresentable`) | 1 | `value.ordinal.underlying` |
| `description: String { rawValue.description }` (in-package Core) | 1 | `_storage.description` |
| Tests — `position.rawValue` | 2 | `position.underlying` (cross-target read; tests target uses public API) |

## In-package vs cross-package boundary

**In-package (`Ordinal Primitives Core` target reading own fields)** uses `_storage`:
- `Ordinal.swift` operators (all `lhs.rawValue` / `rhs.rawValue` → `_storage`)
- `Ordinal+CustomStringConvertible.swift`
- `Ordinal.Predecessor.swift`, `Ordinal.Successor.swift`, `Ordinal.Retreat.swift` where `base: Ordinal` and `count: Cardinal` (BUT for Cardinal, `count` is cross-package — must use `count.underlying`)
- `Ordinal.Distance.swift`, `Ordinal.Advance.swift`, `Ordinal+Cardinal.swift`, `Ordinal.Protocol.swift` — `base.ordinal._storage` (own field) but `count.underlying` (Cardinal cross-package)
- `Cardinal+Ordinal.swift`, `Ordinal+Cardinal.Count.swift` — Cardinal-side reads use `.underlying`; Ordinal-side construction uses `init(_:)`

**Cross-package (other targets/tests reading Ordinal)** uses `underlying`:
- `Ordinal Primitives` (Tagged-related target) — `Tagged+Ordinal.Distance.swift` reads `ordinal.underlying`
- `Ordinal Primitives Standard Library Integration` — all `position.rawValue` / `value.rawValue` → `.underlying`
- `Ordinal Primitives Tests` — `position.rawValue` → `position.underlying`
