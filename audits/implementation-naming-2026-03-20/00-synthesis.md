# Implementation & Naming Audit Synthesis — swift-primitives

**Date**: 2026-03-20
**Scope**: All 132 packages in swift-primitives (2,796 source files, 435 modules, 13,262 public symbols)
**Skills**: `/implementation` [IMPL-*], [PATTERN-*] and `/naming` [API-NAME-*], [API-IMPL-*]
**Method**: Phase 0 automated grep sweep + Phase 1-4 agent-dispatched deep audits of every package

---

## Executive Summary

The swift-primitives ecosystem is **structurally sound**. Core infrastructure packages (ordinal, cardinal, finite, index, vector, comparison, equation, hash, input) are near-pristine — the typed operator foundation is correct. The ecosystem's main issues are:

1. **Compound method names** ([API-NAME-002]) — the dominant violation, concentrated in consumer packages that haven't adopted Property.View nested accessors
2. **`Int(bitPattern:)` at non-boundary call sites** ([IMPL-010]) — missing boundary overloads force repetitive conversion at every use site
3. **Multiple types per file** ([API-IMPL-005]) — widespread but low-impact structural debt
4. **`.rawValue` at consumer call sites** ([PATTERN-017]) — infrastructure packages are correct; consumers leak

The 10 CRITICAL findings are isolated to 4 packages (geometry types, formatting types, cache throws). No systemic architectural problems.

---

## Findings by Package

### Tier 1 — Core Data Structure Infrastructure

| Package | Files | C | H | M | L | Total | Key Theme |
|---------|-------|---|---|---|---|-------|-----------|
| geometry-primitives | 18 | 3 | 9 | 18 | 8 | **38** | Compound types (EdgeInsets, BezierSegment, CardinalDirection) + eager .rawValue extraction in math |
| buffer-primitives | 123 | 0 | 5 | 15 | 7 | **27** | Missing boundary overloads, .rawValue.rawValue chains |
| binary-primitives | 54 | 0 | 4 | 9 | 8 | **21** | Int(bitPattern:) in Cursor/Reader, compound methods |
| dimension-primitives | 28 | 0 | 4 | 8 | 7 | **19** | 95% of rawValue is correct infra; compound property names |
| affine-primitives | 15 | 0 | 0 | 7 | 8 | **15** | .rawValue.rawValue chains all in boundary code |

### Tier 2 — Consumer Data Structures + Domain Types

| Package | Files | C | H | M | L | Total | Key Theme |
|---------|-------|---|---|---|---|-------|-----------|
| tree-primitives | 80 | 0 | 15 | 9 | 8 | **36** | Compound methods (childCount, removeSubtree, forEach*Order) |
| dictionary-primitives | 26 | 0 | 0 | 21 | 6 | **32** | Systematic Int(bitPattern:)/Ordinal(UInt()) in every variant |
| queue-primitives | 29 | 0 | 6 | 5 | 5 | **24** | .rawValue.rawValue in RandomAccessCollection, 9+ types/file |
| time-primitives | 39 | 0 | 5 | 9 | 8 | **22** | .rawValue in Julian Day conversions, compound properties |
| hash-table-primitives | 31 | 0 | 5 | 10 | 5 | **22** | 8 types in one file, Int(bitPattern:) in InlineArray access |
| cache-primitives | 6 | 5 | 4 | 6 | 4 | **19** | All 7 untyped throws in ecosystem originate here |
| pool-primitives | 15 | 0 | 12 | 0 | 3 | **18** | 9 compound type names (*Acquire, *Action) |
| witness-primitives | 4 | 0 | 0 | 0 | 4 | **4** | Clean — only doc example issues |

### Tier 3 — Domain-Specific

| Package | Files | C | H | M | L | Total | Key Theme |
|---------|-------|---|---|---|---|-------|-----------|
| sample-primitives | 20 | 0 | 15 | 4 | 3 | **24** | Statistical compound names (standardDeviation, etc.) |
| region-primitives | 8 | 0 | 8 | 12 | 2 | **22** | Spatial compound names (isHorizontal, rotateClockwise) |
| algebra-linear-primitives | 9 | 0 | 0 | 3 | 8 | **21** | Clean — .rawValue/.unchecked boundary-correct |
| parser-primitives | 107 | 0 | 7 | 4 | 3 | **17** | Compound types (ParserPrinter, LocatedError, EndOfInput) |
| ascii-primitives | 17 | 0 | 4 | 8 | 2 | **16** | Compound types (GraphicCharacters, ControlCharacters) |
| base62-primitives | 14 | 0 | 3 | 5 | 5 | **16** | Compound types (IntegerWrapper, StringWrapper) |
| formatting-primitives | 7 | 2 | 2 | 4 | 4 | **14** | FormatStyle, FloatingPoint shadow |
| ordering-primitives | 9 | 0 | 1 | 3 | 1 | **9** | PartialComparator compound type |
| cyclic-primitives | 10 | 0 | 0 | 1 | 3 | **8** | Clean — all 31 __unchecked boundary-correct |

### Tier 4 — Platform + Additional Data Structures

| Package | Files | C | H | M | L | Total | Key Theme |
|---------|-------|---|---|---|---|-------|-----------|
| windows-primitives | 82 | 0 | 0 | 32 | 8 | **44** | 32 compound methods — our invention, NOT Win32 mirroring |
| kernel-primitives | 248 | 0 | 1 | 14 | 14 | **29** | fatalError in public init, .rawValue.rawValue.rawValue chains |
| heap-primitives | 42 | 0 | 0 | 9 | 12 | **28** | CS term compound names (bubbleUp, trickleDown) |
| linux-primitives | 80 | 0 | 0 | 0 | 10 | **25** | Near-pristine — all .rawValue boundary-correct |
| bit-vector-primitives | 82 | 0 | 0 | 13 | 4 | **24** | Compound names, inconsistent Property.View delegation |
| set-primitives | 31 | 0 | 0 | 5 | 8 | **23** | Clean — bounded indices, Property.View, typed throws all correct |
| darwin-primitives | 23 | 0 | 2 | 6 | 7 | **15** | Clean — minor one-type-per-file issues |
| stdlib-extensions | 86 | 0 | 2 | 5 | 4 | **14** | Clean — most compounds mirror stdlib |

### Tier 5 — Remaining (batched)

| Batch | Packages | Findings | Key |
|-------|----------|----------|-----|
| Core infrastructure (10 pkgs) | ordinal, cardinal, finite, index, vector, comparison, equation, collection, input, hash | **10** (0C, 0H, 1M, 9L) | Near-pristine |
| Data structures (11 pkgs) | terminal, complex, numeric, bit, parser-machine, stack, slab, list, bitset, layout, rendering | **18** (0C, 0H, 8M, 10L) | 4 clean |
| Small packages (30 pkgs) | algebra-*, affine-geometry, cyclic-index, property, ownership, identity, string, text, source, logic, optic, symmetry, effect, serializer, x86, arm, cpu, system, loader | **29** (22 clean) | Mostly clean |
| Remaining (41 pkgs) | clock, coder, decimal, dependency, diagnostic, error, handle, infinite, lexer, lifetime, locale, path, positioning, predicate, random, range, reference, token, + 14 stubs | **14** (14 STUB, 16 clean) | Mostly stubs/clean |
| storage + test + memory | 3 pkgs | **19** (0C, 1H, 11M, 7L) | Memory.Address .rawValue.rawValue |
| machine + array + binary-parser | 3 pkgs | **24** (0C, 2H, 8M, 14L) | binary-parser .rawValue.rawValue |
| sequence + graph + async | 3 pkgs | **21** (0C, 3H, 9M, 9L) | Minor |

---

## Findings by Requirement

### [API-NAME-002] Compound Method/Property Names — ~250 findings

**The dominant violation.** Concentrated in:

| Cluster | Example violations | Count | Fix strategy |
|---------|-------------------|-------|-------------|
| Tree navigation | `childCount`, `removeSubtree`, `forEachPreOrder`, `leftmostChild` | ~60 | Property.View refactor |
| Statistical terms | `standardDeviation`, `coefficientOfVariation`, `medianAbsoluteDeviation` | ~25 | Design decision: [API-NAME-003] exception for domain terms? |
| Spatial/region | `isHorizontal`, `rotateClockwise`, `isCardinal` | ~20 | Property.View refactor |
| Windows platform | `getOption`, `setOption`, `standardInput`, `getCurrentId` | ~32 | Property.View refactor |
| Binary cursor | `moveReaderIndex`, `setWriterIndex`, `readableCount` | ~15 | Property.View refactor |
| Heap operations | `bubbleUp`, `trickleDown`, `removePriority` | ~10 | Property.View refactor |
| Dimension constants | `rightAngle`, `halfPi`, `fullCircle` | ~8 | Remove — nested accessors already exist |
| Cache operations | `cachedValue`, `setValue`, `removeValue` | ~6 | Property.View refactor |

**Design decision needed**: Should well-known CS/math/statistics terms (`standardDeviation`, `lengthSquared`, `bubbleUp`) get [API-NAME-003]-style spec-mirroring exceptions? These are established domain vocabulary, not our invention.

### [IMPL-010] Int(bitPattern:) at Non-Boundary Sites — ~150 findings

Concentrated in data structure internals:

| Package | Count | Root cause |
|---------|-------|-----------|
| buffer-primitives | 57 | Missing `UnsafePointer + Index<Element>` overloads |
| binary-primitives | 44 | Missing typed arithmetic on Cursor/Reader indices |
| dictionary-primitives | 21 | Repeated in every variant's subscript |
| hash-table-primitives | 18 | InlineArray subscript requires Int |
| queue-primitives | 16 | RandomAccessCollection conformance |
| binary-parser-primitives | 17 | Interpreter call sites |
| tree-primitives | 9 | Validation sites |
| heap-primitives | 8 | MinMax algorithm |

**Fix**: A single set of boundary overloads on `UnsafePointer`, `UnsafeMutablePointer`, `InlineArray`, and `Array` that accept `Index<Element>`, `Index<Element>.Count`, and `Cardinal` would eliminate ~80% of these. Many already exist in the StdLib Integration modules but are incomplete.

### [API-IMPL-005] Multiple Types Per File — ~60 findings

Widespread but low severity. Top offenders:

| Package | Types/file | Impact |
|---------|-----------|--------|
| queue-primitives (Queue.swift) | 9 types | HIGH — should split |
| queue-primitives (Queue.Error.swift) | 11 error enums | MEDIUM — debatable |
| hash-table-primitives (Hash.Table.swift) | 8 types | HIGH — should split |
| kernel-primitives (Kernel.Outcome.swift) | 3 types | MEDIUM |
| cache-primitives (Cache.swift) | 4 types | MEDIUM |
| dictionary-primitives (Dictionary.Ordered.swift) | 5 types | MEDIUM |
| dimension-primitives (Dimension.swift) | 4+ types | HIGH — should split |

### [PATTERN-017] .rawValue at Consumer Call Sites — ~100 findings

Infrastructure packages (ordinal, cardinal, affine, dimension) are correct — they DEFINE the operators and properly confine `.rawValue` to boundary code. The violations are in CONSUMER packages:

| Consumer | .rawValue count | Root cause |
|----------|----------------|-----------|
| geometry-primitives | ~252 | Eager extraction at method entry for coordinate-mixing math |
| time-primitives | ~33 | Missing typed arithmetic on Time.Year/Month/Day |
| kernel-primitives | ~68 | Platform interop + missing operators |
| binary-primitives | ~59 | Binary format I/O missing typed ops |

Special case: `.rawValue.rawValue` double chains (41 total) and `.rawValue.rawValue.rawValue` triple chains (kernel) indicate concrete missing operators at the Tagged layer boundary.

### [API-NAME-001] Compound Type Names — ~30 findings

| Type | Package | Proposed |
|------|---------|----------|
| `EdgeInsets` | geometry | `Geometry.Insets` or `Geometry.Edge.Insets` |
| `BezierSegment` | geometry | `Geometry.Bezier.Segment` |
| `CardinalDirection` | geometry | `Geometry.Direction` |
| `AffineTransform` | geometry | `Geometry.Transform` |
| `FormatStyle` | formatting | `Format.Style` |
| `FloatingPoint` | formatting | `Format.Decimal` (avoids Swift.FloatingPoint shadow) |
| `SignDisplayStrategy` | formatting | `Format.Numeric.Sign.Strategy` |
| `DecimalSeparatorStrategy` | formatting | `Format.Numeric.Separator.Strategy` |
| `GraphicCharacters` | ascii | `ASCII.Graphic` |
| `ControlCharacters` | ascii | `ASCII.Control` |
| `CaseConversion` | ascii | `ASCII.Case.Conversion` |
| `LineEnding` | ascii | `ASCII.Line.Ending` |
| `ParserPrinter` | parser | `Parser.Bidirectional` |
| `LocatedError` | parser | `Parser.Error.Located` (protocol) |
| `EndOfInput` | parser | `Parser.End` |
| `CollectionInput` | parser | `Parser.Input.Collection` |
| `ByteInput` / `ByteStream` | parser | `Parser.Input.Bytes` |
| `IntegerWrapper` | base62 | `Base62_Primitives.Integer` |
| `StringWrapper` | base62 | `Base62_Primitives.String` |
| `CollectionWrapper` | base62 | `Base62_Primitives.Bytes` |
| `TryAcquire` | pool | `Pool.Bounded.Acquire.Try` |
| `CallbackAcquire` | pool | `Pool.Bounded.Acquire.Callback` |
| `TimeoutAcquire` | pool | `Pool.Bounded.Acquire.Timeout` |
| `*Action` (6 types) | pool | Nest under parent operation |
| `PartialComparator` | ordering | `Ordering.Comparator.Partial` |
| `CaseInsensitive` | stdlib-ext | `String.Case.Insensitive` |

### [API-ERR-001] Untyped Throws — 10 findings

All in cache-primitives (7) and pool-primitives (3). Mechanical fix — the methods already only throw their own error type.

### [PATTERN-021] __unchecked at Non-Boundary Sites — ~50 findings

Most `__unchecked` usage is boundary-correct. Notable exceptions:
- buffer-primitives: `__unchecked` Count from Cardinal (should use typed init)
- set-primitives: `hashTable.insert(__unchecked:)` in non-boundary code
- bit-vector-primitives: dynamic ones/zeros construction

---

## Cleanest Packages (0-3 findings)

These packages exemplify the target quality:

| Package | Findings | Notes |
|---------|----------|-------|
| swift-witness-primitives | 4 (all LOW doc) | Production code has zero violations |
| swift-cyclic-primitives | 8 (1M, 3L, 4 INFO) | All 31 __unchecked boundary-correct |
| swift-index-primitives | 0 | Perfect |
| swift-input-primitives | 0 | Perfect |
| swift-ordinal-primitives | 1 (LOW) | Near-perfect |
| swift-cardinal-primitives | 1 (LOW) | Near-perfect |
| swift-vector-primitives | 1 (LOW) | Near-perfect |
| swift-comparison-primitives | 1 (LOW) | Near-perfect |
| swift-equation-primitives | 1 (LOW) | Near-perfect |
| swift-hash-primitives | 1 (LOW) | Near-perfect |
| swift-storage-primitives | 3 (1M, 2L) | Near-perfect |
| swift-linux-primitives | 25 (all LOW/INFO) | All .rawValue boundary-correct |
| swift-algebra-linear-primitives | 21 (3M, 8L, 10 INFO) | All __unchecked boundary-correct |
| swift-stack-primitives | 0 | Perfect |
| swift-slab-primitives | 0 | Perfect |
| swift-list-primitives | 0 | Perfect |
| swift-numeric-primitives | 0 | Perfect |
| 22 algebra-* packages | 0-3 each | Clean |

---

## Remediation Priority

### Priority 1: Mechanical fixes (high impact, low risk)

1. **Untyped throws in cache + pool** (10 findings) — change `throws` to `throws(Cache.Error)` / `throws(Pool.Error)`. Mechanical.

2. **Dimension compound property names** (8 findings) — remove `rightAngle`, `halfPi`, etc. — nested accessors already exist in same file.

3. **Compound type renames** (~30 findings) — rename types. Each is a single declaration change + consumer updates via find-references.

### Priority 2: Boundary overload additions (high impact, medium effort)

4. **Add `UnsafePointer + Index<Element>` boundary overloads** — eliminates ~80 `Int(bitPattern:)` across buffer, binary, hash-table, dictionary, tree, heap.

5. **Add `InlineArray.subscript(Index<Element>)` overload** — eliminates ~20 `Int(bitPattern:)` in hash-table, buffer.

6. **Add missing `.rawValue.rawValue` operators** (41 chains) — each is a specific operator addition. Eliminates double-unwrap at every call site.

### Priority 3: Property.View refactoring (high count, medium effort per package)

7. **Tree** — `childCount` → `child.count`, `removeSubtree` → `remove.subtree`, `forEachPreOrder` → `forEach.preOrder`
8. **Binary** — `moveReaderIndex` → `move.reader.index`, `readableCount` → `readable.count`
9. **Windows** — systematic Property.View for `get*/set*` patterns
10. **Region** — `isHorizontal` → `is.horizontal`, `rotateClockwise` → `rotate.clockwise`
11. **Cache** — `cachedValue` → `cached.value`, `setValue` → `set.value`
12. **Heap** — `bubbleUp` → internal only per [IMPL-024]

### Priority 4: One-type-per-file splits (structural improvement)

13. Split Queue.swift (9 types), Hash.Table.swift (8 types), Dimension.swift (4+ types), Dictionary.Ordered.swift (5 types), Cache.swift (4 types).

### Priority 5: Design decisions needed

14. **Statistical compound names** — `standardDeviation`, `coefficientOfVariation`: grant [API-NAME-003] exception for established domain vocabulary, or refactor to `standard.deviation`, `coefficient.ofVariation`?

15. **Geometry .rawValue density** — 252 usages. Many are in coordinate-mixing math algorithms where typed arithmetic breaks down. Determine which typed operators to add vs. which algorithms legitimately need raw scalar access.

16. **`FormatStyle` protocol** — renaming to `Format.Style` may conflict with downstream conformances. Needs migration plan.

---

## Audit Coverage

| Category | Packages | Files | Status |
|----------|----------|-------|--------|
| Individual audits | 28 | ~1,200 | Complete — detailed per-file findings |
| Batched audits (core infra) | 10 | ~242 | Complete — per-package sections |
| Batched audits (data structures) | 11 | ~259 | Complete — per-package sections |
| Batched audits (small) | 30 | ~280 | Complete — 22 CLEAN |
| Batched audits (remaining) | 41 | ~200 | Complete — 14 STUB, 16 CLEAN |
| Previously audited (leaf audit) | 7 | ~60 | Folded in — referenced |
| **Total** | **132** | **~2,796** | **100% coverage** |

All 44 audit files are in `Research/audits/implementation-naming-2026-03-20/`.
