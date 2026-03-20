# Pass 4 Verification: Compound Type Renames

**Date**: 2026-03-20
**Scope**: All 9 packages listed in the rename plan
**Method**: Grep for old compound names in Sources/ and Tests/, read new type declarations

---

## Summary

| # | Package | Old Names Gone? | New Names In Place? | Files Renamed? | Notes |
|---|---------|:-:|:-:|:-:|-------|
| 1 | swift-pool-primitives | YES | YES | YES | All 9 renames complete |
| 2 | swift-cache-primitives | YES | YES | YES | Renamed to `Cache.Evict` / `Cache.Compute` |
| 3 | swift-parser-primitives | YES | YES | PARTIAL | Type names correct; see details |
| 4 | swift-geometry-primitives | YES | YES | PARTIAL | File names retain old compound forms |
| 5 | swift-ordering-primitives | N/A | YES | NO | File name still `Ordering.PartialComparator.swift` |
| 6 | swift-formatting-primitives | YES | YES | YES | Clean Nest.Name throughout |
| 7 | swift-ascii-primitives | YES | YES | PARTIAL | File names retain old compound forms |
| 8 | swift-base62-primitives | YES | YES | NO | File names retain `IntegerWrapper`/`StringWrapper`/`CollectionWrapper` |
| 9 | swift-standard-library-extensions | YES | N/A | N/A | `CaseInsensitive` not found anywhere; likely removed or never existed |

**Overall verdict**: All compound type names have been eliminated from type declarations. The Nest.Name pattern is consistently applied. File naming lags behind in several packages.

---

## Package Details

### 1. swift-pool-primitives (tier 20) -- COMPLETE

All 9 planned renames executed. Old compound names produce zero grep hits across Sources/ and Tests/.

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `TryAcquire` | `Pool.Bounded.Acquire.Try` | `Pool.Bounded.Acquire.Try.swift` | DONE |
| `CallbackAcquire` | `Pool.Bounded.Acquire.Callback` | `Pool.Bounded.Acquire.Callback.swift` | DONE |
| `TimeoutAcquire` | `Pool.Bounded.Acquire.Timeout` | `Pool.Bounded.Acquire.Timeout.swift` | DONE |
| `AcquireAction` | `Pool.Bounded.Acquire.Action` | `Pool.Bounded.Acquire.swift` | DONE |
| `ReleaseAction` | `Pool.Bounded.Release.Action` | `Pool.Bounded.Acquire.swift` (L307-323) | DONE |
| `TryAcquireAction` | `Pool.Bounded.Acquire.Try.Action` | `Pool.Bounded.Acquire.Try.swift` (L58-71) | DONE |
| `CallbackAcquireAction` | `Pool.Bounded.Acquire.Callback.Action` | `Pool.Bounded.Acquire.Callback.swift` (L67-80) | DONE |
| `CommitAction` | `Pool.Bounded.Fill.Commit` | `Pool.Bounded.Fill.swift` (L82-95) | DONE |
| `DrainAction` | `Pool.Bounded.Shutdown.Drain` | `Pool.Bounded.Shutdown.swift` (L46-56) | DONE |

**Design decisions differing from plan**:
- `CommitAction` became `Fill.Commit` (not `Fill.Action`) -- better semantics since Fill already has `Fill.Action` for the initial fill decision.
- `DrainAction` became `Shutdown.Drain` (not `Shutdown.Action`) -- semantically clear.
- `Pool.Acquire` and `Pool.Release` in Core are Effect types (not action enums), living at the Pool level for Effect.Protocol conformance.

### 2. swift-cache-primitives (tier 20) -- COMPLETE

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `__CacheEvict` | `Cache.Evict` | `Cache.Evict.swift` | DONE |
| `__CacheCompute` | `Cache.Compute` | `Cache.Compute.swift` | DONE |

Old names only survive in `Experiments/cache-effect-type-nesting/` (design exploration, not production code). Both types are `Effect.Protocol` conformances nested in the `Cache` namespace.

### 3. swift-parser-primitives (tier 17) -- COMPLETE (types); PARTIAL (files)

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `ParserPrinter` | `Parser.Bidirectional` | `Parser.ParserPrinter.swift` | Type DONE, file name stale |
| `LocatedError` | `Parser.Error.Located` | `Parser.Error.Located.swift` | DONE |
| `EndOfInput` | `Parser.EndOfInput` | `Parser.EndOfInput.swift` | DONE (was already nested) |
| `CollectionInput` | `Parser.Input.Collection` (typealias) | `Parser.Input.swift` | DONE |
| `ByteInput` | `Parser.Input.Bytes` (typealias) | `Parser.Input.swift` | DONE |
| `ByteStream` | `Parser.Input.Stream` (typealias) | `Parser.Input.swift` | DONE |

**Design decisions**:
- `ParserPrinter` was renamed to `Parser.Bidirectional` (protocol), not a direct nesting under `Parser.Printer`. File `Parser.ParserPrinter.swift` retains old name.
- Input types are typealiases into `Input_Primitives` rather than standalone structs.
- A backward-compatibility `@available(*, deprecated)` typealias exists for `Parser.Located`.
- `Parseable` protocol exists at top level (not namespaced under `Parser`) -- this appears intentional as a protocol conformance attachment point.

### 4. swift-geometry-primitives (tier 12) -- COMPLETE (types); PARTIAL (files)

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `EdgeInsets` | `Geometry.Insets` | `Geometry.EdgeInsets.swift` | Type DONE, file name stale |
| `BezierSegment` | `Geometry.Bezier.Segment` | `Geometry.Bezier.swift` (nested) | DONE |
| `CardinalDirection` | Removed / moved to Region primitives | N/A | Not present in geometry-primitives |
| `AffineTransform` | `Geometry.Transform` (typealias to `Affine.Continuous.Transform`) | `Geometry.swift` L114 | DONE |

**Design decisions**:
- `EdgeInsets` became `Insets` (dropped compound prefix) nested under `Geometry`.
- `BezierSegment` became `Bezier.Segment` (proper nesting).
- `CardinalDirection` is not present -- cardinal direction types live in region-primitives (`Region.Cardinal`), which geometry re-exports.
- `AffineTransform` became a simple typealias `Transform` pointing to `Affine.Continuous.Transform`.

### 5. swift-ordering-primitives (tier 3) -- COMPLETE (type); NO (file)

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `PartialComparator` | `Ordering.Comparator.Partial` | `Ordering.PartialComparator.swift` | Type DONE, file name stale |

The type declaration is `public struct Partial: Sendable` nested inside `extension Ordering.Comparator`. Test code uses `Ordering.Comparator<Double>.Partial` correctly. The `@Suite("PartialComparator")` string label in tests is cosmetic, not a type reference.

### 6. swift-formatting-primitives (tier 1) -- COMPLETE

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `FormatStyle` | `Format.Style` | `FormatStyle.swift` | DONE (protocol nested in `Format`) |
| `FloatingPoint` (format) | `Format.Decimal` | `Format.FloatingPoint.swift` | Type DONE, file name stale |
| `SignDisplayStrategy` | `Format.Numeric.Sign` | `Format.Numeric.SignDisplayStrategy.swift` | Type DONE, file name stale |
| `DecimalSeparatorStrategy` | `Format.Numeric.Separator` | `Format.Numeric.DecimalSeparatorStrategy.swift` | Type DONE, file name stale |

**Design decisions**:
- `FormatStyle` became `Format.Style` (protocol with associated types `Input`/`Output`).
- `FloatingPoint` format became `Format.Decimal` to avoid collision with stdlib's `FloatingPoint`.
- `SignDisplayStrategy` became `Format.Numeric.Sign` (enum with `.automatic`, `.never`, `.always`).
- `DecimalSeparatorStrategy` became `Format.Numeric.Separator` (enum with `.automatic`, `.always`).

### 7. swift-ascii-primitives (tier 0) -- COMPLETE (types); PARTIAL (files)

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `GraphicCharacters` | `ASCII.Character.Graphic` | `ASCII.GraphicCharacters.swift` | Type DONE, file name stale |
| `ControlCharacters` | `ASCII.Character.Control` | `ASCII.ControlCharacters.swift` | Type DONE, file name stale |
| `CaseConversion` | `ASCII.Case.Conversion` | `ASCII.CaseConversion.swift` | Type DONE, file name stale |
| `LineEnding` | `ASCII.Line.Ending` | `ASCII.LineEnding.swift` | Type DONE, file name stale |

**Design decisions**:
- Consistent pattern: `ASCII.Character.{Graphic,Control}`, `ASCII.Case.Conversion`, `ASCII.Line.Ending`.
- Each old compound name decomposed into a namespace + leaf name.

### 8. swift-base62-primitives (tier 0) -- COMPLETE (types); NO (files)

Note: Package is `swift-base62-primitives`, not `swift-base62-standard` as listed in the plan.

| Old Name | New Name | File | Status |
|----------|----------|------|--------|
| `IntegerWrapper` | `Base62_Primitives.Integer` | `Base62_Primitives.IntegerWrapper.swift` | Type DONE, file name stale |
| `StringWrapper` | `Base62_Primitives.Text` | `Base62_Primitives.StringWrapper.swift` | Type DONE, file name stale |
| `CollectionWrapper` | `Base62_Primitives.Bytes` | `Base62_Primitives.CollectionWrapper.swift` | Type DONE, file name stale |

**Design decisions**:
- `StringWrapper` became `Text` (not `String` to avoid shadowing stdlib).
- `CollectionWrapper` became `Bytes` (more domain-specific).
- `IntegerWrapper` became `Integer` (direct Nest.Name).

### 9. swift-standard-library-extensions (tier 0) -- N/A

`CaseInsensitive` was listed for rename but does not exist anywhere in the package (grep across Sources/ and Tests/ returns zero results). Either:
- It was removed entirely, or
- It never existed in this package (may have been in a different package), or
- The rename plan was based on stale data.

No file or type named `CaseInsensitive` found.

---

## File Name Staleness Summary

The following files have type names that no longer match their file names:

| Package | File Name | Should Be |
|---------|-----------|-----------|
| swift-parser-primitives | `Parser.ParserPrinter.swift` | `Parser.Bidirectional.swift` |
| swift-geometry-primitives | `Geometry.EdgeInsets.swift` | `Geometry.Insets.swift` |
| swift-ordering-primitives | `Ordering.PartialComparator.swift` | `Ordering.Comparator.Partial.swift` |
| swift-formatting-primitives | `Format.FloatingPoint.swift` | `Format.Decimal.swift` |
| swift-formatting-primitives | `Format.Numeric.SignDisplayStrategy.swift` | `Format.Numeric.Sign.swift` |
| swift-formatting-primitives | `Format.Numeric.DecimalSeparatorStrategy.swift` | `Format.Numeric.Separator.swift` |
| swift-ascii-primitives | `ASCII.GraphicCharacters.swift` | `ASCII.Character.Graphic.swift` |
| swift-ascii-primitives | `ASCII.ControlCharacters.swift` | `ASCII.Character.Control.swift` |
| swift-ascii-primitives | `ASCII.CaseConversion.swift` | `ASCII.Case.Conversion.swift` |
| swift-ascii-primitives | `ASCII.LineEnding.swift` | `ASCII.Line.Ending.swift` |
| swift-base62-primitives | `Base62_Primitives.IntegerWrapper.swift` | `Base62_Primitives.Integer.swift` |
| swift-base62-primitives | `Base62_Primitives.StringWrapper.swift` | `Base62_Primitives.Text.swift` |
| swift-base62-primitives | `Base62_Primitives.CollectionWrapper.swift` | `Base62_Primitives.Bytes.swift` |

This is a **[API-IMPL-005]** violation: file names must match the type they contain.
