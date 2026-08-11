# swift-binary-primitives: rawValue → underlying rename design note

**Date**: 2026-05-03
**Tier**: 16 (downstream migration cycle, Pass 2)
**Upstream renames**:
- swift-tagged-primitives `46ded75` (`Tagged.rawValue` → `.underlying`, `init(rawValue:)` → `init(_:)`, `init(_unchecked: ())` → `init(_unchecked:)`)
- swift-carrier-primitives `2b57aac` (`Carrier` → namespace enum; `Carrier.\`Protocol\``; `raw` → `underlying`)
- Cardinal/Ordinal/Vector precedent for own-field `rawValue` rename

## Q1 — Own `public let rawValue` types in this package

Three candidates. Each evaluated for construction shape:

### Binary.Count<Scalar, Space> — Option A (cosmetic accessor rename only)

`Binary.Count` (`Sources/Binary Primitives Core/Binary.Count.swift`) is constructed via:
- `init(_ value: Scalar) throws(Binary.Error)` — bounds-checks `value >= 0`
- `init(_ extent: Extent.X<Space>.Value<Scalar>) throws(Binary.Error)` — bounds-checks
- `init(unchecked value: Scalar)` — debug-only assert
- `init(integerLiteral:)` — precondition trap
- `static var zero` — unchecked

Construction is **checked** (throwing), so the Axis/Interval.Unit precedent applies: rename the read-side accessor `rawValue` → `underlying` and the deprecated alias `_rawValue` → `_underlying` for symmetry with the rest of the ecosystem, but **do NOT** add `Carrier.\`Protocol\`` conformance. The current shape (storage = `_storage`, accessor = `rawValue`) is the same shape Axis used; the rename is purely the public accessor name.

Internally Binary.Count keeps `internal let _storage` (unchanged).

### Binary.Mask — full Cardinal/Ordinal/Vector precedent

`Binary.Mask` (`Sources/Binary Primitives Core/Binary.Mask.swift`) is constructed via:
- `init(_ rawValue: Int)` — unconditional, just stores
- `init(_ alignment: Memory.Alignment)` — preconditions but unconditional storage
- `init(_ shift: Memory.Shift)` — preconditions but unconditional storage

Construction is **unconditional** (no throws/failable), so apply full precedent:

```swift
@frozen public struct Mask: Sendable, Equatable, Hashable {
    @usableFromInline let _storage: Int
}

extension Binary.Mask: Carrier.`Protocol` {
    public typealias Underlying = Int
    @inlinable public var underlying: Int { _read { yield _storage } }
    @inlinable public init(_ underlying: consuming Int) { self._storage = underlying }
}
```

The two convenience inits from Memory.Alignment/Shift remain as-is (still unconditional, still public).

### Binary.Pattern.Mask — full Cardinal/Ordinal/Vector precedent

`Binary.Pattern<Carrier>.Mask` (`Sources/Binary Primitives Core/Binary.Pattern.swift`, generic over `Carrier: FixedWidthInteger & UnsignedInteger & Sendable`). Construction:
- `init(_ rawValue: Carrier)` — unconditional

Apply full precedent. Note the existing generic parameter is named `Carrier` (a stdlib-style placeholder, NOT the Carrier_Primitives namespace). To avoid confusing the new `Carrier.\`Protocol\`` import, we'll keep the generic parameter name as-is (it's a phantom-style placeholder name; refactoring it is out of scope and would touch many call sites). The conformance still uses fully-qualified `Carrier_Primitives.Carrier.\`Protocol\`` — Swift resolves the nested-type reference through the `Carrier_Primitives` module import.

Wait — there is a name shadow. The `Carrier` generic parameter shadows `Carrier_Primitives.Carrier` inside the type. We have two options:

(a) Don't conform `Binary.Pattern.Mask` to `Carrier.\`Protocol\`` (it's a tier-15 generic-arena type whose ergonomics are about bit-pattern algebra, not carrier composition). Just rename the accessor.
(b) Rename the generic parameter `Carrier` → something like `Word` to avoid shadowing.

(b) is a wide-blast-radius API rename to adjacent typealiases (`Pattern8`/`Pattern16`/`Pattern32`/`Pattern64`/`PatternWord`) — but those typealiases use positional generic args, so the rename is type-internal only. Still: this is bigger than a mechanical migration.

**Decision**: Apply Option A to `Binary.Pattern.Mask` (cosmetic accessor rename only, no Carrier.`Protocol` conformance). Rationale:
- Avoids the `Carrier` parameter shadowing issue without a wider rename
- `Binary.Pattern.Mask` doesn't appear to be used as a generic carrier substrate anywhere in the ecosystem (it's a leaf vocabulary type for bit-pattern algebra)
- The full-precedent path can be revisited if/when ecosystem usage demands carrier composition

### Q1 summary

| Type | Path | Reason |
|------|------|--------|
| Binary.Count | Option A (accessor rename) | Throwing init; precondition / bounds-check |
| Binary.Mask | Full precedent | Unconditional construction |
| Binary.Pattern.Mask | Option A (accessor rename) | Generic-param `Carrier` shadow; leaf vocab |

## Q2 — Editorial public surface candidates

None surfaced. The package is already modularised into Core / Cursor / LEB128 / Format / Serializable variants plus a Namespace target. No drift from the L1 vocabulary mission.

## Q3 — Three-consumer rule

Not triggered. No new public types are being added; all changes are accessor renames + one Carrier.`Protocol` conformance on an existing public type.

## Q4 — Code-surface violations

Spot check of file naming and identifiers:
- `Tagged+Bitwise.swift` — extension-on-Tagged file pattern, fine
- `RangeReplaceableCollection+Bytes.swift`, `Collection+UInt8.swift` etc. — protocol+conformance file naming, fine
- `Pattern8`/`Pattern16`/`Pattern32`/`Pattern64`/`PatternWord` typealiases — these are top-level (no `Binary.` namespace), arguably should be `Binary.Pattern8` etc. or removed in favour of `Binary.Pattern<UInt32>` direct use. **Flagged for follow-up**, not in this pass's scope.
- No `*Tag` suffix violations seen.

No blocking violations. Carrying the `PatternN` typealiases observation forward as a queue item, not addressing here.

## Verdict

**No escalation.** Q2/Q3/Q4 produce only one minor follow-up note (top-level `PatternN` typealiases) which does not block this migration. Proceeding to Phase 2.

## Caveats flagged for principal

- Binary.Count is the second checked-construction Option-A case in this cycle (first being Axis/Interval.Unit). Pattern is now precedent.
- Binary.Pattern.Mask has the `Carrier` generic-parameter shadow that prevents clean full-precedent adoption. Leaf-vocab status justifies Option A; revisit on ecosystem demand.
