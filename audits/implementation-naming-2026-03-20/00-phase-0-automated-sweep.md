# Phase 0: Automated Sweep — swift-primitives

Date: 2026-03-20
Skills: `/implementation`, `/naming`
Scope: All 131 packages in swift-primitives (2,796 source files, 435 modules, 13,262 public symbols)

## Violation Heat Map

### [PRIM-FOUND-001] Foundation Imports

| Location | Count | Status |
|----------|-------|--------|
| Sources/ | **0** | CLEAN |
| Tests/ | 19 | All in `.build/checkouts/` (third-party deps, not our code) |

**Verdict**: No Foundation violations in production source. This requirement is fully satisfied.

---

### [API-ERR-001] Untyped Throws

| Package | Untyped `throws ->` | Notes |
|---------|---------------------|-------|
| swift-cache-primitives | 7 | Async pool/cache APIs |
| swift-witness-primitives | 6 | Witness protocol conformances |
| swift-pool-primitives | 3 | Bounded pool acquire APIs |
| swift-standard-library-extensions | 1 | Result extension |
| swift-clock-primitives | 1 | Clock.Any |
| **Total** | **18** | |

**Verdict**: Low count, concentrated in 5 packages. Cache and witness are the primary targets. Pool was partially converted in prior session. These are all in async/concurrency-adjacent code where typed throws meets `Task.checkCancellation()`.

---

### [IMPL-002] / [PATTERN-017] `.rawValue` at Call Sites

| Package | `.rawValue` count | Classification |
|---------|-------------------|----------------|
| swift-geometry-primitives | 252 | **HOT** — likely legitimate geometry math |
| swift-dimension-primitives | 192 | **HOT** — tagged dimension arithmetic |
| swift-windows-primitives | 86 | Platform interop boundary |
| swift-kernel-primitives | 68 | Platform interop boundary |
| swift-binary-primitives | 59 | Binary format parsing |
| swift-linux-primitives | 57 | Platform interop boundary |
| swift-affine-primitives | 49 | Affine arithmetic infrastructure |
| swift-ordinal-primitives | 41 | Core infrastructure (expected) |
| swift-time-primitives | 33 | Date/time computation |
| swift-algebra-linear-primitives | 31 | Linear algebra math |
| swift-affine-geometry-primitives | 27 | Geometry + affine intersection |
| swift-x86-primitives | 24 | Platform interop |
| swift-decimal-primitives | 19 | IEEE 754 format manipulation |
| swift-darwin-primitives | 19 | Platform interop |
| swift-cardinal-primitives | 19 | Core infrastructure (expected) |
| All others | ~220 | Distributed across remaining packages |
| **Total** | **~1,196** | ~1,164 excluding experiments/StdLib integration |

**`.rawValue.rawValue` double-chains (worst signal)**:

| Package | Count | Notes |
|---------|-------|-------|
| swift-affine-primitives | 15 | Missing operators between tagged layers |
| swift-binary-primitives | 6 | Binary cursor arithmetic |
| swift-buffer-primitives | 5 | Buffer offset/count computation |
| swift-queue-primitives | 4 | Queue convenience methods |
| swift-kernel-primitives | 3 | Kernel address computation |
| swift-source-primitives | 2 | Source location |
| swift-memory-primitives | 2 | Memory address |
| Others | 4 | 1 each: text, heap, binary-parser, algebra-modular |
| **Total** | **41** | Each is a missing operator/overload |

**Verdict**: `.rawValue` usage is expected in infrastructure packages (ordinal, cardinal, affine, identity) where the boundary overloads are *defined*. The concerning signal is `.rawValue` in *consumer* packages (geometry, dimension, time, decimal) and especially `.rawValue.rawValue` chains anywhere — each chain is a concrete missing operator per [IMPL-000]. The 41 double-chains are the highest-priority targets.

---

### [IMPL-010] / [PATTERN-018] `Int(bitPattern:)` Outside Boundaries

| Package | Count | Classification |
|---------|-------|----------------|
| swift-buffer-primitives | 57 | Data structure internals — should be in boundary overloads |
| swift-binary-primitives | 44 | Binary format I/O |
| swift-hash-table-primitives | 18 | Hash table operations |
| swift-dictionary-primitives | 17 | Dictionary operations |
| swift-binary-parser-primitives | 17 | Parser internals |
| swift-queue-primitives | 16 | Queue operations |
| swift-linux-primitives | 14 | Platform syscall boundary (expected) |
| swift-input-primitives | 12 | Input stream operations |
| swift-finite-primitives | 11 | Finite ordinal infrastructure |
| swift-bit-vector-primitives | 10 | Bit vector operations |
| swift-tree-primitives | 9 | Tree navigation |
| swift-heap-primitives | 8 | Heap operations |
| All others | ~78 | Distributed |
| **Total** | **~411** (307 excluding StdLib integration) | |

**Verdict**: Platform packages (linux, windows, darwin) are expected to have `Int(bitPattern:)` at syscall boundaries. The concerning packages are data structure internals (buffer, hash-table, dictionary, queue, tree, heap) where these should live in boundary overloads, not at call sites. The StdLib integration modules (104 occurrences) are correct — that's exactly where the conversions belong.

---

### [PATTERN-021] / [IMPL-002] `__unchecked` Construction

| Package | Count | Classification |
|---------|-------|----------------|
| swift-dimension-primitives | 206 | **EXTREME** — tagged dimension arithmetic |
| swift-finite-primitives | 47 | Finite ordinal construction |
| swift-geometry-primitives | 36 | Geometry construction |
| swift-binary-primitives | 32 | Binary format construction |
| swift-cyclic-primitives | 31 | Cyclic group arithmetic |
| swift-affine-primitives | 22 | Affine arithmetic |
| swift-algebra-linear-primitives | 20 | Linear algebra |
| swift-cyclic-index-primitives | 19 | Cyclic index operations |
| swift-time-primitives | 17 | Time construction |
| swift-parser-primitives | 15 | Parser result construction |
| swift-darwin-primitives | 15 | Platform types |
| swift-hash-table-primitives | 12 | Hash table slots |
| swift-test-primitives | 11 | Test framework |
| All others | ~159 | Distributed |
| **Total** | **642** | |

**Verdict**: `swift-dimension-primitives` at 206 is the standout — this is 32% of all `__unchecked` usage in the entire ecosystem. This likely indicates missing typed constructors and operators on dimension types. Geometry (36) and algebra-linear (20) have the same pattern. These three packages share a domain (mathematical types with tagged wrappers) and likely share root causes.

---

### [API-NAME-001] Compound Type Names

~58 compound type names found. Key candidates after filtering standard patterns:

| Type | Package | Verdict |
|------|---------|---------|
| `GraphicCharacters` | ascii | Should be `Graphic.Characters` or similar |
| `CaseConversion` | ascii | Should be nested |
| `ControlCharacters` | ascii | Should be `Control.Characters` |
| `LineEnding` | ascii | Should be `Line.Ending` |
| `EdgeInsets` | geometry | Should be `Edge.Insets` |
| `BezierSegment` | geometry | Should be `Bezier.Segment` |
| `CardinalDirection` | geometry | Should be `Cardinal.Direction` |
| `SlotAddress` | handle | Should be `Slot.Address` |
| `VectorSpace` | algebra-module | Should be `Vector.Space` |
| `FormatStyle` | formatting | Protocol — should be `Format.Style` |
| `FloatingPoint` | formatting | Conflicts with Swift.FloatingPoint |
| `SignDisplayStrategy` | formatting/binary | Should be nested |
| `DecimalSeparatorStrategy` | formatting | Should be nested |
| `IntegerWrapper` | base62 | Should be nested |
| `StringWrapper` | base62 | Should be nested |
| `CollectionWrapper` | base62 | Should be nested |
| `WithBorrowed` | binary-parser | Should be nested |
| `InvalidCapacity` | bitset | Already nested in Error — acceptable |
| `ContiguousProtocol` | memory | Should be `Contiguous.Protocol` or nested |
| `PartialComparator` | ordering | Should be `Partial.Comparator` |
| `RawID` | machine-capture | Should be nested |
| `LocatedError` | parser | Should be nested |
| `ParserPrinter` | parser | Should be `Parser.Printer` |
| `ConversionError` | path | Already nested — acceptable |
| `PeekAccessor` | queue | Should be `Peek.Accessor` or removed |
| `MinMax` | heap | Acceptable — standard CS term |

**Verdict**: ~30 genuine [API-NAME-001] violations, concentrated in ascii, geometry, formatting, base62, parser, and ordering packages.

---

### [API-NAME-002] Compound Method/Property Names

Raw count: 1,401 compound public methods.
After filtering stdlib conventions (make/with/is/build/remove/pop/insert, etc.): ~470.
After filtering spec-mandated patterns: **~350 genuine candidates**.

**Top offending packages**:

| Package | Filtered count | Key patterns |
|---------|---------------|--------------|
| swift-windows-primitives | 74 | Platform syscall wrappers |
| swift-buffer-primitives | 50 | `setPosition`, `ensureCapacity`, `firstVacant` |
| swift-binary-primitives | 39 | `setReaderIndex`, `moveReaderIndex`, `withSerializedBytes` |
| swift-region-primitives | 20 | Domain-specific operations |
| swift-tree-primitives | 17 | `removeSubtree`, `childCount` |
| swift-predicate-primitives | 17 | Predicate combinators |
| swift-binary-parser-primitives | 16 | Parser operations |
| swift-sample-primitives | 15 | Statistics operations |
| swift-geometry-primitives | 14 | Geometry operations |
| swift-dictionary-primitives | 14 | Dictionary operations |
| swift-async-primitives | 14 | Async operations |
| swift-kernel-primitives | 12 | Kernel operations |

**Common violation patterns**:

| Pattern | Count | Should become |
|---------|-------|---------------|
| `setPosition`, `setWord`, `setAll`, `setReaderIndex` | 19 | `set.position()`, `set.word()`, `set.all()`, `set.reader.index()` |
| `firstVacant` | 11 | `first.vacant()` or property |
| `ensureCapacity` | 6 | `ensure.capacity()` or stdlib convention (debatable) |
| `removeSubtree` | 6 | `remove.subtree()` |
| `childCount` | 6 | `child.count` property |
| `moveReaderIndex` | 4 | `move.reader.index()` |
| `outlierCount` | 4 | `outlier.count` property |
| `multiplyAdd` | 4 | Math convention (fma) — debatable |
| `sendTo` | 3 | `send(to:)` with label |
| `peekFront`, `peekBack` | 6 | `peek.front()`, `peek.back()` |
| `alignUp`, `alignDown` | 6 | `align.up()`, `align.down()` |

**Verdict**: ~350 genuine compound method violations. Windows-primitives is the worst (74) but those are platform syscall wrappers where the compound name mirrors the OS API. Buffer, binary, and tree are the most impactful targets for remediation. Many patterns (set*, remove*, peek*, align*) are systematic and can be batch-fixed via Property.View refactoring.

**Exception analysis**:
- `with*` closure-scoping patterns are conventional Swift — not violations
- `is*` predicates are conventional — not violations
- `build*` result builder methods are protocol-mandated — not violations
- Platform syscall wrappers (windows, linux, darwin) may justify [API-NAME-003] spec-mirroring

---

## Prior Audit Coverage Map

| Package | Prior Audit | Status |
|---------|-------------|--------|
| swift-decimal-primitives | Leaf audit Phase 2a | COMPLETE — fixes applied |
| swift-random-primitives | Leaf audit Phase 2a | COMPLETE |
| swift-reference-primitives | Leaf audit Phase 2a | COMPLETE |
| swift-locale-primitives | Leaf audit Phase 2b | COMPLETE (stub) |
| swift-ascii-serializer-primitives | Leaf audit Phase 2b | COMPLETE |
| swift-ascii-parser-primitives | Leaf audit Phase 2b | COMPLETE |
| swift-predicate-primitives | Leaf audit Phase 2b | COMPLETE |
| swift-algebra-law-primitives | Leaf audit Phase 2c | STARTED, not finished |
| swift-infinite-primitives | Leaf audit Phase 2c | STARTED, not finished |
| swift-range-primitives | Leaf audit Phase 2c | STARTED, not finished |
| swift-lexer-primitives | Leaf audit Phase 2c | STARTED, not finished |
| swift-bitset-primitives | Leaf audit Phase 2c | STARTED, not finished |
| Rendering stack (5 packages) | `audits/implementation-naming-2026-03-13/` | COMPLETE — 121 findings |
| swift-tests/swift-testing | `naming-implementation-audit-swift-tests-swift-testing.md` | IN_PROGRESS — 88 violations |
| All others (~115 packages) | **None** | NOT STARTED |

---

## Priority Ranking for Phase 1 Deep Audits

Ranked by (violation density × ecosystem impact × prior coverage gap):

### Tier 1 — Highest Impact (audit first)

| Package | Why | Estimated violations |
|---------|-----|---------------------|
| **swift-dimension-primitives** | 206 `__unchecked` + 192 `.rawValue` — 32% of all `__unchecked` in ecosystem. Core math infrastructure. | HIGH |
| **swift-geometry-primitives** | 252 `.rawValue` + 36 `__unchecked` + 14 compound methods + compound types (EdgeInsets, BezierSegment, CardinalDirection). Richest module (585 symbols). | HIGH |
| **swift-buffer-primitives** | 57 `Int(bitPattern:)` + 50 compound methods + 5 `.rawValue.rawValue`. Core data structure infra. | HIGH |
| **swift-binary-primitives** | 44 `Int(bitPattern:)` + 39 compound methods + 6 `.rawValue.rawValue`. Binary format backbone. | HIGH |
| **swift-affine-primitives** | 15 `.rawValue.rawValue` (highest double-chain count) + 49 `.rawValue`. Core arithmetic infra. | HIGH |

### Tier 2 — High Impact

| Package | Why |
|---------|-----|
| **swift-tree-primitives** | 17 compound methods + 9 `Int(bitPattern:)`. Complex data structure. |
| **swift-hash-table-primitives** | 18 `Int(bitPattern:)` + 12 `__unchecked`. Core hash infra. |
| **swift-queue-primitives** | 16 `Int(bitPattern:)` + 4 `.rawValue.rawValue`. |
| **swift-dictionary-primitives** | 17 `Int(bitPattern:)` + 14 compound methods. |
| **swift-time-primitives** | 33 `.rawValue` + 17 `__unchecked`. User-visible domain. |
| **swift-cache-primitives** | 7 untyped throws. Small, focused fix. |
| **swift-witness-primitives** | 6 untyped throws. Small, focused fix. |
| **swift-pool-primitives** | 3 untyped throws + partially converted. |

### Tier 3 — Medium Impact

| Package | Why |
|---------|-----|
| swift-ascii-primitives | 3+ compound type names (GraphicCharacters, ControlCharacters, etc.) |
| swift-formatting-primitives | Compound types (FormatStyle, FloatingPoint conflict) |
| swift-algebra-linear-primitives | 20 `__unchecked` + 31 `.rawValue` |
| swift-cyclic-primitives | 31 `__unchecked` |
| swift-region-primitives | 20 compound methods |
| swift-sample-primitives | 15 compound methods |
| swift-ordering-primitives | 9 compound methods + PartialComparator type |
| swift-base62-primitives | Compound types (IntegerWrapper, StringWrapper, CollectionWrapper) |
| swift-parser-primitives | 15 `__unchecked` + compound types (ParserPrinter, LocatedError) |

### Tier 4 — Low Impact / Platform (audit last)

| Package | Why |
|---------|-----|
| swift-windows-primitives | 74 compound methods — but platform syscall wrappers |
| swift-linux-primitives | 57 `.rawValue` + 14 `Int(bitPattern:)` — platform boundary |
| swift-darwin-primitives | 19 `.rawValue` + 15 `__unchecked` — platform boundary |
| swift-kernel-primitives | 68 `.rawValue` — but much is infra definition |
| swift-x86-primitives | 24 `.rawValue` — ISA-level |
| swift-arm-primitives | 11 `.rawValue` — ISA-level |

### Already Covered (fold into tracking)

Leaf audit Phase 2a-2b packages (7 complete), Phase 2c (5 interrupted — resume).

---

## Systemic Patterns for Batch Remediation

These cross-package patterns can be fixed systematically rather than per-package:

### Pattern A: Missing Typed Operators in Dimension/Geometry/Algebra

The 206 `__unchecked` in dimension-primitives and 252 `.rawValue` in geometry-primitives likely share a root cause: missing typed arithmetic operators on `Degree`, `Radian`, `Geometry.Size`, `Geometry.Point`, etc. A single operator-lifting session could eliminate hundreds of violations across 3+ packages.

### Pattern B: `set.*` / `remove.*` / `peek.*` → Property.View

~40+ compound methods across buffer, binary, tree, queue, dictionary follow the `setX()` / `removeX()` / `peekX()` pattern. These are systematic Property.View refactoring candidates per [IMPL-020].

### Pattern C: `Int(bitPattern:)` in Data Structure Internals

~150 occurrences in buffer, hash-table, dictionary, queue, tree, heap. These should move into boundary overloads on `UnsafeMutablePointer`, `UnsafeBufferPointer`, etc. — many of which already exist in the StdLib integration modules but may be incomplete.

### Pattern D: `.rawValue.rawValue` Double Chains

All 41 occurrences are missing operators. Each one maps to a specific operator addition in the infrastructure layer.

---

## Recommended Phase 1 Execution Plan

### Approach: Hybrid (automated + agent-dispatched)

1. **Batch D first** (41 `.rawValue.rawValue` chains) — smallest count, highest signal. Each is a concrete missing operator. Fix in infra, then all consumer call sites improve.

2. **Batch A** (dimension/geometry/algebra operators) — highest volume. Fix operators in affine/ordinal/cardinal infrastructure, then sweep dimension + geometry.

3. **Tier 1 deep audits** (5 packages) — agent-dispatched, one per package. Each agent reads all source, evaluates against full skill checklist, writes findings document.

4. **Batch B** (Property.View refactoring) — after Tier 1 audits identify the full list.

5. **Batch C** (`Int(bitPattern:)` boundary push) — after Tier 1 audits confirm which boundary overloads are missing.

6. **Tier 2-4 deep audits** — agent-dispatched in batches.

### Estimated scope

| Phase | Packages | Estimated violations | Effort |
|-------|----------|---------------------|--------|
| Batch D | Cross-cutting | 41 | Small — add operators |
| Batch A | dimension, geometry, algebra-linear | ~400+ | Medium — operator design |
| Tier 1 audits | 5 packages | ~200+ | Large — full read + triage |
| Batch B | buffer, binary, tree, queue, dict | ~100+ | Medium — Property.View refactor |
| Batch C | buffer, hash-table, dict, queue | ~150 | Medium — boundary overloads |
| Tier 2-4 audits | ~20 packages | ~200+ | Large — full read + triage |
| Leaf audit resume | 5 interrupted + 12 remaining | ~50+ | Medium |
