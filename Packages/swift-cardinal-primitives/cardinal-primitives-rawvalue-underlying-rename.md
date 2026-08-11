# cardinal-primitives — rawValue → underlying rename

**Date**: 2026-05-03
**Status**: DEFERRED (status updated 2026-05-09 per cohort-wide amendment C1)
**Scope**: `swift-cardinal-primitives`, tier 2 of the downstream migration cascade (carrier 2b57aac, tagged 46ded75, ownership 0146d21, property c4bce7f).

## Resolution (2026-05-09)

Cohort-wide policy C1 (data-structures cohort, Story 1 readiness): defer the rename. Story 1 (cardinal / ordinal / affine) launches at the current `rawValue` shape; the rename is scheduled but unscoped for a future major version. The trivial-self-carrier shape (`Cardinal.Underlying = Cardinal`) is preserved across 0.x for cohort coherence — cascading the rename mid-readiness destabilizes three packages, and the cosmetic critique is recoverable post-launch. The framing supporting this position: *Cardinal is a kind of number, not a UInt wrapper* — the trivial-self-carrier shape is consistent with the trichotomy framing of the cohort (cardinal / ordinal / affine as three things stdlib calls Int).

The analysis below remains the canonical reference for what the rename *would* entail when it eventually lands. It is preserved for the future revisit; the consumer-migration table at lines 88-97 is the load-bearing artifact.

## Context

Three breaking renames have landed upstream:

1. **swift-carrier-primitives `2b57aac`** — `Carrier` is now a bare-namespace `enum`; the protocol moved to `Carrier.\`Protocol\`` (typealias to module-scope `_CarrierProtocol`); the accessor renamed `raw` → `underlying`.
2. **swift-tagged-primitives `46ded75`** — `Tagged<Tag, RawValue>` → `Tagged<Tag, Underlying>`; `tagged.rawValue` → `tagged.underlying`; `init(rawValue:)` → `init(_:)`; `init(_unchecked: (), rawValue: x)` → `init(_unchecked: x)`. **Tagged's Carrier conformance is now unconditional + immediate** — `Tagged<Tag, U>.Underlying == U` (no recursion). `init(_unchecked:)` is `public`.
3. Tier 0 (`swift-ownership-primitives 0146d21`) and tier 1 (`swift-property-primitives c4bce7f`) committed.

cardinal-primitives consumes property-primitives transitively through carrier and tagged. Pre-1.0 — no backward compatibility, no typealias bridges.

## Q1 — Does this package declare types with their own `public let rawValue`?

**YES.** `Sources/Cardinal Primitives Core/Cardinal.swift` line 39:

```swift
public struct Cardinal {
    public let rawValue: UInt
}
```

This is **the type's own UInt storage**, NOT a Tagged accessor. Pre-authorized for rename per v3 handoff Open Questions: Cardinal becomes a proper `Carrier.\`Protocol\`` conformer with `var underlying: UInt { get }`, dropping the separate `rawValue` field shape.

### Current shape (before rename)

`Cardinal` carries TWO separate bits of "underlying" semantics today:

1. The struct's own field `public let rawValue: UInt` (the actual UInt storage).
2. A `Carrier.\`Protocol\`` conformance with `Underlying = Cardinal` (a *trivial self-carrier*) — meaning `cardinal.underlying` returns `Cardinal`, not `UInt`. The default `extension Carrier where Underlying == Self` provides `_read { yield self }`.

These are inconsistent. The `cardinal.cardinal`/`cardinal.count` per-type accessors (defined on `Carrier where Underlying == Cardinal`) also return `Cardinal`. The actual UInt is reached only via `cardinal.rawValue`. Effectively, `Cardinal` is a UInt wrapper that pretends to be a self-carrier of itself.

### Target shape (after rename)

The cleanest correction: **`Cardinal` becomes a non-trivial Carrier of `UInt`**. The `public let rawValue: UInt` field is renamed to `_storage: UInt` (internal, `@usableFromInline`) with `public var underlying: UInt` exposed via the conformance. `Cardinal: Carrier.\`Protocol\`` with `Underlying = UInt`, `Domain = Never` (default).

```swift
@frozen
public struct Cardinal {
    @usableFromInline
    let _storage: UInt
}

extension Cardinal: Carrier.`Protocol` {
    public typealias Underlying = UInt

    public var underlying: UInt {
        @_lifetime(borrow self)
        _read { yield _storage }
    }

    @_lifetime(copy underlying)
    public init(_ underlying: consuming UInt) {
        self._storage = underlying
    }
}
```

This collapses the two-layer accessor (`cardinal.rawValue` for UInt, `cardinal.underlying` for Cardinal-self) into a single canonical `cardinal.underlying: UInt`.

### API surface delta

**Removed**:
- `Cardinal.rawValue: UInt` (public stored field)
- `Cardinal: Carrier` with `Underlying = Cardinal` (trivial self-carrier conformance)
- `extension Carrier where Underlying == Cardinal { var cardinal: Cardinal }` (per-type alias accessor returning self)
- `extension Carrier where Underlying == Cardinal { var count: Cardinal }` (legacy per-type alias)

**Added**:
- `Cardinal: Carrier.\`Protocol\`` with `Underlying = UInt`
- `Cardinal.underlying: UInt` (via Carrier protocol)

**Unchanged**:
- `init(_ value: UInt)` continues to exist (now identical in shape to the Carrier-derived `init(_ underlying: consuming UInt)` — keep one, drop the other; the Carrier-derived one wins since it's protocol-required).
- `init<T: UnsignedInteger>(_ value: T)` in `Cardinal+UnsignedInteger.swift` — keep, delegates to UInt init.
- `init(_ value: Int) throws(Error)` in `Int+Cardinal.swift` — keep.
- All `Cardinal.zero`, `Cardinal.one`, `Cardinal.max` constants — re-anchor on `Cardinal` directly (not via the `Carrier where Underlying == Cardinal` extension, which goes away).
- The `+`, `-`, `<`, `==` operators on `Cardinal` itself.

### Consumer migration inside this package

Read sites of `cardinal.rawValue` (now `cardinal.underlying`):

| File | Line(s) | Current | After |
|------|---------|---------|-------|
| `Cardinal Primitives Core/Cardinal.swift` | 83, 99, 106, 110, 115, 120 | `lhs.rawValue == rhs.rawValue` etc | `lhs.underlying == rhs.underlying` |
| `Cardinal Primitives Core/Cardinal.Add.swift` | 29, 43 | `base.rawValue.addingReportingOverflow(other.rawValue)` | `base.underlying.addingReportingOverflow(other.underlying)` |
| `Cardinal Primitives Core/Cardinal.Subtract.swift` | 41, 54 | `base.rawValue - other.rawValue` | `base.underlying - other.underlying` |
| `Cardinal Primitives Core/Cardinal+CustomStringConvertible.swift` | 13 | `rawValue.description` | `underlying.description` |
| `Cardinal Primitives Standard Library Integration/Int+Cardinal.swift` | 31, 34, 48, 59 | `cardinal.rawValue` (and as bare `rawValue`) | `cardinal.underlying` |
| `Cardinal Primitives/Tagged+Cardinal.swift` | 47, 54, 62 | `count.rawValue` (where `count: Tagged<Tag, Cardinal>`) | `count.underlying.underlying` (Tagged.underlying yields Cardinal; then Cardinal.underlying yields UInt) |

The Tagged case is the spicy one: under the new `Tagged: Carrier.\`Protocol\`` (immediate, unconditional) shape, `Tagged<Tag, Cardinal>.Underlying == Cardinal`, so `count.underlying` is a `Cardinal`, not a `UInt`. The old `count.rawValue` returned `UInt` — that depended on Tagged's old cascade (`Underlying.Underlying`). With the immediate-Underlying form, the pattern is `count.underlying.underlying` (or `Int(...)` taking `some Carrier<Cardinal>` if available).

In `Tagged+Cardinal.swift`'s Int conversions (lines 47, 54, 62), `count.rawValue` (which previously cascaded to `UInt`) becomes `count.underlying.underlying` — `count.underlying` is `Cardinal`, then `.underlying` reaches `UInt`. Or rewrite to use the existing `Cardinal`-taking inits on `Int` (which already handle `Cardinal -> Int`):

```swift
public init<Tag: ~Copyable>(_ count: Tagged<Tag, Cardinal>) throws(Cardinal.Error) {
    self = try Int(count.underlying)  // count.underlying: Cardinal, then Int(Cardinal) is the existing throws init
}
```

This is cleaner — delegate to the existing `Int(Cardinal)` conversions rather than reach all the way to UInt.

### Per-type accessor recovery

The old `cardinal: Cardinal` and `count: Cardinal` accessors on `Carrier where Underlying == Cardinal` provided ergonomic per-domain reads. With the rename, `cardinal.underlying` returns `UInt` (the concrete carried value). For `Tagged<Tag, Cardinal>`, `tagged.underlying` returns `Cardinal` directly — so the old `tagged.cardinal: Cardinal` becomes simply `tagged.underlying: Cardinal`. **No new accessor needed.**

The bare-`Cardinal` consumer that wants "give me the `Cardinal` value back from a generic `some Carrier<Cardinal>`" is rare — the `Tagged<Tag, Cardinal>` consumer uses `.underlying`; the bare-`Cardinal` consumer is already holding `Cardinal`. So `cardinal: Cardinal` is dropped, not migrated.

The `count: Cardinal` accessor was a legacy alias from the now-deprecated `Cardinal.\`Protocol\``. Drop.

The constants `static var zero` and `static var one` — re-anchor as `extension Cardinal { static var zero: Cardinal { Cardinal(0) } }` directly on the type. Or define them on `Carrier.\`Protocol\` where Underlying == Cardinal` — but since the only Carrier-of-Cardinal is `Tagged<Tag, Cardinal>`, and `Tagged.zero` already needs the `Self(Cardinal(0))` shape, keep them constrained to `Carrier.\`Protocol\` where Underlying == Cardinal`. The Tagged form needs them.

Actually, the cleanest: define `.zero`/`.one` on `Cardinal` directly (the bare type) AND on `Carrier.\`Protocol\` where Underlying == Cardinal` (for Tagged). The latter delegates to the former.

## Q2 — Editorial public surface candidates

Audit the public API for items that lack three independent consumers and could move to a sibling target / SLI / opt-in.

Cardinal Primitives Core public surface:

- `Cardinal` (struct) — yes.
- `Cardinal.rawValue` → `Cardinal.underlying` — yes (via Carrier).
- `Cardinal.init(_: UInt)` — yes.
- `Cardinal.zero`, `Cardinal.one`, `Cardinal.max` — yes.
- `Cardinal.+`, `+=`, `==`, `<`, `<=`, `>`, `>=` — yes.
- `Cardinal.Error` (enum: overflow, underflow, negativeSource) — yes.
- `Cardinal.Add` (enum tag) + `Cardinal.add: Property<Add, Self>` + `.saturating`/`.exact` — yes.
- `Cardinal.Subtract` (enum tag) + `Cardinal.subtract: Property<Subtract, Self>` + `.saturating`/`.exact` — yes.
- `Cardinal: Hashable, Comparable, Sendable, Equation.\`Protocol\`, Comparison.\`Protocol\`, Carrier.\`Protocol\`, CustomStringConvertible` — all standard.

Cardinal Primitives Standard Library Integration:

- `Cardinal: ExpressibleByIntegerLiteral` — SLI, correct location.
- `Cardinal.init<T: UnsignedInteger>(_:)` — SLI, correct.
- `Cardinal.init(_: Int) throws` + `Int.init(_: Cardinal)` etc — SLI, correct.
- `UInt32.init(_ cardinal: some Carrier<Cardinal>)` — SLI, correct.
- `ContiguousArray.init(repeating:count:)` — SLI, correct.
- `Span/MutableSpan/OutputSpan/UnsafeBufferPointer/UnsafeMutableBufferPointer/UnsafeMutablePointer + Cardinal` — all SLI, correct.

Cardinal Primitives (umbrella + Tagged extensions):

- `Tagged where Underlying == Cardinal` inits, `Add`/`Subtract` tags, `+ Property` extensions, `Int.init(_ count: Tagged<Tag, Cardinal>)`. All belong in this target.

**Verdict**: No editorial surface candidates beyond Q1. The split between Core / SLI / umbrella is already correct. **Trivial.**

## Q3 — Three-consumer rule

For each public init/accessor/method, can three independent consumers be named? In a primitives package the audience is the entire `swift-primitives` ecosystem and downstream `swift-standards`/`swift-foundations`/etc.

- `Cardinal` itself — used in `swift-index-primitives`, `swift-buffer-primitives`, `swift-mark-primitives` (via Index/Count), and many more. Three+. ✓
- `Cardinal.add.saturating/exact`, `Cardinal.subtract.saturating/exact` — used in tier-1 collections wherever capacity arithmetic happens. Three+. ✓
- `Cardinal.zero`/`.one` — pervasive. ✓
- `Cardinal: ExpressibleByIntegerLiteral` — pervasive in literal contexts. ✓
- `Tagged where Underlying == Cardinal` arithmetic — used by Index<T>.Count, Buffer count, etc. ✓
- `Span/etc + Cardinal` SLI inits — used by SLI consumers (any package bridging stdlib stride-based types). ✓
- `UInt32.init(_ cardinal: some Carrier<Cardinal>)` — narrow but used in font metrics (16-bit count fields), encoding sizes. Three+ across standards/foundations. ✓
- `ContiguousArray.init(repeating:count:)` — used in collection bridges. Three+. ✓

**Verdict**: All public API surface meets the three-consumer rule. **Trivial.**

## Q4 — Compound identifiers / *Tag suffixes / code-surface violations

Scan for [API-NAME-001/002/003], [API-IMPL-005], [PRIM-FOUND-001] violations.

- `Cardinal.Add` (enum) and `Cardinal.Subtract` (enum) — these are legitimate phantom-tag domains, not "*Tag" suffixed names per [feedback_no_tag_suffix]. Naming is by concept (`Add`, `Subtract`), not `AddTag`. ✓
- File names: `Cardinal.Add.swift`, `Cardinal.Subtract.swift`, `Cardinal+Carrier.swift`, etc — match nesting. ✓
- One type per file: ✓ (Cardinal+Carrier.swift contains only the conformance + Carrier-where extensions, not standalone types.)
- No `import Foundation`. ✓
- No compound identifiers (e.g., no `cardinalRawValue`, no `addSaturating`). ✓
- Per-type accessor `cardinal.cardinal` and `cardinal.count` — these are **subjective** names that effectively mean "self/value" rather than nest-on-name. They're being removed in Q1's redesign anyway, so moot.
- The `var add: Property<Add, Self>` accessor is lowercase non-compound — correct.

One subtle note: the test file is named `CardinalCountTests.swift`, which is a compound identifier (`CardinalCount`). It should be `Cardinal.Count.Tests.swift` or `CardinalTests.swift`. **However**, this predates the rename cycle and isn't load-bearing for the rename — flag for future cleanup, not part of this cascade.

**Verdict**: No code-surface violations introduced or unfixed by the rename cycle. The test file name is a pre-existing compound that's out-of-scope. **Trivial.**

## Final verdict

- **Q1**: Pre-authorized — proceed with `Cardinal: Carrier.\`Protocol\`` over `UInt` (collapsing the field-rawValue + trivial-self-carrier dual-shape into a single non-trivial carrier).
- **Q2/Q3/Q4**: All trivial. **Proceed to Phase 2 without escalation.**

## Plan for Phase 2

1. `swift package update` (pull tier 0 + tier 1 + carrier + tagged migrations).
2. Rewrite `Cardinal.swift`: rename field `rawValue` → `_storage` (internal `@usableFromInline`), drop the bare `init(_: UInt)` (subsumed by Carrier-derived), keep operators rewritten to use `.underlying`.
3. Rewrite `Cardinal+Carrier.swift`: switch to `Carrier.\`Protocol\`` with `Underlying = UInt`, drop `cardinal`/`count` accessors, re-anchor `.zero`/`.one` on bare `Cardinal` AND on `Carrier.\`Protocol\` where Underlying == Cardinal` (for Tagged).
4. Mechanical sweep across all `.swift` files: `.rawValue` → `.underlying` (where the value is a Cardinal or Carrier-of-Cardinal); `Carrier` → `Carrier.\`Protocol\`` where it's a constraint; `init(_unchecked: (), x)` → `init(_unchecked: x)`; `RawValue` → `Underlying`; `init(rawValue:)` → `init(_:)` for Tagged paths.
5. Hand-fix the Tagged.+Cardinal.swift Int conversions to use the `Int(Cardinal)` SLI inits rather than reaching to UInt.
6. Build, test, commit (no push, no tag).
