# Remediation Plan — swift-primitives Implementation & Naming Compliance

**Date**: 2026-03-20
**Scope**: All 132 packages, ~700 findings from `00-synthesis.md`
**Strategy**: Multi-pass, foundation-first then downstream, easiest first, build-verify each step

---

## Practical Constraints

### Build model
- swift-primitives is a **superrepo**: 132 independent Package.swift files, NOT one unified build
- Each package builds independently: `cd swift-X-primitives && swift build`
- Build time: ~13s (cached mid-tier) to ~35s (cold leaf with deep deps)
- Test time: ~28s per package
- No single "build all" command — must build each affected package

### Dependency tiers
- **21 tiers** (0-20), computed by `Scripts/compute-tiers.sh`
- Tier 0 = foundation (algebra, identity, ownership, property, etc.) — no dependencies, everything depends on these
- Tier 20 = deepest consumers (cache, pool, binary-parser, parser-machine, rendering, test) — depend on everything, nothing depends on them
- A rename in tier 0 cascades through all 132 packages. A rename in tier 20 cascades to nothing.

### Tier listing (from `Scripts/compute-tiers.sh`)

```
Tier 0  (15 pkgs): algebra, ascii, base62, coder, decimal, error, identity, lifetime, ownership, positioning, property, random, reference, serializer, stdlib-extensions
Tier 1  (9 pkgs):  ascii-serializer, dependency, equation, formatting, locale, logic, numeric, outcome, scalar
Tier 2  (4 pkgs):  comparison, continuation, effect, witness
Tier 3  (8 pkgs):  algebra-magma, cardinal, clock, hash, optic, ordering, predicate, state
Tier 4  (3 pkgs):  algebra-monoid, ordinal, system
Tier 5  (3 pkgs):  affine, algebra-group, algebra-semiring
Tier 6  (5 pkgs):  algebra-affine, algebra-cardinal, algebra-ring, index, text
Tier 7  (5 pkgs):  algebra-field, sequence, source, symbol, token
Tier 8  (11 pkgs): abstract-syntax-tree, algebra-module, bitset, collection, cyclic, diagnostic, finite, lexer, module, syntax, type
Tier 9  (8 pkgs):  algebra-modular, bit, cyclic-index, dimension, driver, input, intermediate-representation, vector
Tier 10 (11 pkgs): algebra-law, algebra-linear, backend, bit-index, complex, handle, infinite, range, region, slice, time
Tier 11 (5 pkgs):  affine-geometry, bit-pack, matrix, sample, symmetry
Tier 12 (4 pkgs):  bit-vector, geometry, space, transform
Tier 13 (2 pkgs):  layout, memory
Tier 14 (3 pkgs):  binary, storage, string
Tier 15 (5 pkgs):  buffer, cpu, endian, loader, path
Tier 16 (10 pkgs): abi, arm, array, hash-table, heap, list, riscv, slab, stack, x86
Tier 17 (4 pkgs):  kernel, parser, queue, set
Tier 18 (8 pkgs):  ascii-parser, darwin, dictionary, graph, linux, network, terminal, windows
Tier 19 (3 pkgs):  async, machine, tree
Tier 20 (6 pkgs):  binary-parser, cache, parser-machine, pool, rendering, test
```

### Cross-repo impact
- swift-standards and swift-foundations depend on swift-primitives packages
- Any public API rename in primitives must also be updated in standards/foundations
- This plan covers primitives only. A follow-up plan handles consumer repos.

### Direction: Foundation-first, then downstream

**All passes go Tier 0 → Tier 20.** Fix the foundation package first, then build the next tier — if it breaks, fix it. Continue tier by tier. The compiler is your checklist: build errors at each tier tell you exactly what to update.

This works because:
1. Foundations define the patterns — fix them first so every downstream fix is consistent
2. Build errors cascade predictably — each tier only breaks from changes in the tier above
3. No backtracking — once a tier is green, it stays green

---

## Pass 1: Zero-Cascade Mechanical Fixes

**Direction**: Tier 0 → Tier 20
**Risk**: None — changes are intra-package, no public API changes visible to consumers
**Build verification**: `swift build && swift test` in the changed package only

These are changes entirely within one package. Direction doesn't strictly matter (no cascading), but we go T0→T20 for consistency and to build confidence in the foundation first.

### 1a. Filename corrections

| Package | Tier | Current | Correct |
|---------|------|---------|---------|
| swift-dimension-primitives | 9 | `Tagged+Arithmatic.swift` | `Tagged+Arithmetic.swift` |
| swift-algebra-linear-primitives | 10 | `Linear+Arithmatic.swift` | `Linear+Arithmetic.swift` |
| swift-geometry-primitives | 12 | `Geometry+Arithmatic.swift` | `Geometry+Arithmetic.swift` |

**Procedure**: `git mv` the file, build, test, commit.

### 1b. Remove duplicate compound properties (nested alternatives already exist)

| Package | Tier | Properties to remove | Nested alternative |
|---------|------|---------------------|-------------------|
| swift-dimension-primitives | 9 | `rightAngle`, `straightAngle`, `fullCircle`, `fortyFive` (Double + Float) | `.right.full`, `.straight.full`, `.full.full` |
| swift-dimension-primitives | 9 | `halfPi`, `twoPi`, `quarterPi` | `.pi.half`, `.pi.two`, `.pi.quarter` |

**Procedure**: Grep superrepo for each name first. Remove the compound statics, build, test. If a downstream consumer uses them, it will fail at its tier — fix it then.

### 1c. Unify `BinaryFloatingPoint`-constrained extensions

| Package | Tier | Change |
|---------|------|--------|
| swift-dimension-primitives | 9 | Merge duplicate Double + Float constant extensions into single `BinaryFloatingPoint` extension |

### 1d. Untyped throws → typed throws

| Package | Tier | Files | Change |
|---------|------|-------|--------|
| swift-pool-primitives | 20 | Pool.Bounded.Creation.swift, Pool.Bounded.swift | `throws` → `throws(Pool.Error)` on `create` closure |
| swift-cache-primitives | 20 | Cache.swift | `throws` → `throws(Cache.Error)` on 4 methods + closure parameter |

**Procedure per package**:
1. Change `throws` → `throws(ErrorType)` in declarations
2. Add typed throw annotations to closure parameters
3. `swift build` — verify
4. `swift test` — verify
5. Commit

### 1e. fatalError → typed throw

| Package | Tier | Location | Change |
|---------|------|----------|--------|
| swift-kernel-primitives | 17 | Kernel.Event.ID.swift:59 | `fatalError()` → `throws(Kernel.Event.ID.Error)` |

**Estimated effort**: ~2 hours for all of Pass 1.

---

## Pass 2: Additive Infrastructure (New Overloads & Operators)

**Direction**: Tier 0 → Tier 20 (foundations define the operators, consumers use them)
**Risk**: None — purely additive, no existing API changes
**Build verification**: `swift build` in the changed package

These are new overloads and operators. Nothing breaks. We add them in the infrastructure packages (low tiers) so that consumer packages (high tiers) can use them in Pass 3.

### 2a. Missing `.rawValue.rawValue` operators (41 chains → ~15 operators)

The 41 double-chains collapse into ~15 distinct missing operators. Add them where the Tagged layers are defined:

| Operator needed | Add to package | Tier | Eliminates chains in |
|----------------|---------------|------|---------------------|
| `Int(bitPattern: Tagged<Tag, Cardinal>)` via existing | swift-cardinal-primitives | 3 | buffer, queue, dictionary |
| `UInt32(Tagged<Tag, Cardinal>)` | swift-cardinal-primitives | 3 | buffer arena (2) |
| `Int(bitPattern: Tagged<Tag, Affine.Discrete.Vector>)` | swift-affine-primitives | 5 | affine (15), buffer (5), queue (4) |
| Operators for `Memory.Address` triple-chain | swift-memory-primitives | 13 | kernel (2) |

**Procedure per operator**:
1. Add the operator/overload in the infrastructure package
2. `swift build` in that package
3. Do NOT update consumers yet (that's Pass 3)
4. Commit

### 2b. Boundary overloads on stdlib pointer types

These go in the `Standard Library Integration` modules that already exist in each infrastructure package:

| Overload | Add to package | Tier | Eliminates |
|----------|---------------|------|-----------|
| `UnsafePointer + Index<Element>` | swift-ordinal-primitives (StdLib Integration) | 4 | ~25 `Int(bitPattern:)` in buffer |
| `UnsafePointer + Index<Element>.Count` | swift-ordinal-primitives (StdLib Integration) | 4 | ~15 in buffer, binary |
| `UnsafeMutablePointer + Index<Element>` | same | 4 | ~20 in buffer, hash-table |
| `InlineArray.subscript(Index<Element>)` | swift-ordinal-primitives or swift-finite-primitives | 4/8 | ~20 in hash-table, buffer arena |
| `Array.subscript(Index<Element>)` | swift-ordinal-primitives (StdLib Integration) | 4 | ~10 in tree, dictionary |

**Procedure per overload**:
1. Add in the StdLib Integration module
2. `swift build` in that package
3. Commit
4. Consumers updated in Pass 3

**Estimated effort**: ~4 hours for all of Pass 2.

---

## Pass 3: Consumer Cleanup (Use New Infrastructure)

**Direction**: Tier 0 → Tier 20 (fix closest consumers first, then their consumers)
**Risk**: Low — replacing mechanism with calls to infrastructure added in Pass 2
**Build verification**: `swift build && swift test` in each changed package

Now that the operators and overloads exist (Pass 2), sweep through consumers tier by tier, replacing raw extraction with typed operations.

### 3a. Replace `.rawValue.rawValue` chains with new operators

Work tier by tier from foundation toward deepest consumers:

| Package | Tier | Chains | After |
|---------|------|--------|-------|
| swift-affine-primitives | 5 | 15 | Internal — use `Int(bitPattern:)` overload |
| swift-algebra-modular-primitives | 9 | 3 | Use typed multiply |
| swift-memory-primitives | 13 | 2 | Use Address operator |
| swift-binary-primitives | 14 | 6 | Use typed Offset→Int overload |
| swift-buffer-primitives | 15 | 5 | Use Cardinal→UInt32 overload |
| swift-queue-primitives | 17 | 4 | Use typed distance/index ops |
| swift-kernel-primitives | 17 | 2 (triple chain) | Use `Memory.Address` operator |
| swift-binary-parser-primitives | 20 | 1 | Use `Int(bitPattern:)` overload |

### 3b. Replace `Int(bitPattern:)` at non-boundary call sites

Sweep tier by tier:

| Package | Tier | Sites | Fix |
|---------|------|-------|-----|
| swift-binary-primitives | 14 | 44 | Use typed Cursor/Reader ops |
| swift-buffer-primitives | 15 | 57 | Use typed pointer ops |
| swift-hash-table-primitives | 16 | 18 | Use InlineArray subscript |
| swift-dictionary-primitives | 18 | 21 | Use typed subscript/Ordinal |
| swift-tree-primitives | 19 | 9 | Use typed Array subscript |
| swift-binary-parser-primitives | 20 | 17 | Use typed pointer ops |

**Procedure per package**:
1. Replace `Int(bitPattern: x)` calls with the new typed overloads
2. Replace `Ordinal(UInt(index))` chains with direct typed constructors
3. `swift build && swift test`
4. Commit

### 3c. Replace `__unchecked` with typed constructors where possible

| Package | Tier | Sites | Fix |
|---------|------|-------|-----|
| swift-buffer-primitives | 15 | 2 | Use Cardinal→Count typed init |
| swift-set-primitives | 17 | 5 | Use typed hash table insert |

**Estimated effort**: ~8 hours for all of Pass 3.

---

## Pass 4: Compound Type Renames

**Direction**: Tier 0 → Tier 20
**Risk**: Medium — public API change. Each rename in tier N may break tiers N+1 through 20.
**Build verification**: After renaming in tier N, build every tier from N through 20 to find and fix all breakage.

### Execution strategy

For each package (working tier 0 → tier 20):
1. Rename the type in the declaring package
2. `swift build` in that package — verify the declaration compiles
3. Build the next tier downstream — if it breaks, fix it
4. Continue building tier by tier until tier 20 — fix each break
5. `swift test` in every changed package
6. Commit all changes atomically (declaring package + all consumer updates)

Also grep swift-standards and swift-foundations for cross-repo usage — note but don't fix here (separate follow-up).

### Tier 0 renames

| Package | Old | New |
|---------|-----|-----|
| swift-ascii-primitives | `GraphicCharacters` | `ASCII.Graphic` |
| swift-ascii-primitives | `ControlCharacters` | `ASCII.Control` |
| swift-ascii-primitives | `CaseConversion` | `ASCII.Case.Conversion` |
| swift-ascii-primitives | `LineEnding` | `ASCII.Line.Ending` |
| swift-base62-primitives | `IntegerWrapper` | `Base62_Primitives.Integer` |
| swift-base62-primitives | `StringWrapper` | `Base62_Primitives.String` (nested) |
| swift-base62-primitives | `CollectionWrapper` | `Base62_Primitives.Bytes` |
| swift-standard-library-extensions | `CaseInsensitive` | `String.Case.Insensitive` |

After each rename: build tiers 1-20 to find and fix downstream breakage.

### Tier 1 renames

| Package | Old | New |
|---------|-----|-----|
| swift-formatting-primitives | `FormatStyle` | `Format.Style` |
| swift-formatting-primitives | `FloatingPoint` | `Format.Decimal` |
| swift-formatting-primitives | `SignDisplayStrategy` | `Format.Numeric.Sign.Strategy` |
| swift-formatting-primitives | `DecimalSeparatorStrategy` | `Format.Numeric.Separator.Strategy` |

After each rename: build tiers 2-20.

### Tier 3 renames

| Package | Old | New |
|---------|-----|-----|
| swift-ordering-primitives | `PartialComparator` | `Ordering.Comparator.Partial` |

After: build tiers 4-20.

### Tier 12 renames

| Package | Old | New |
|---------|-----|-----|
| swift-geometry-primitives | `EdgeInsets` | `Geometry.Insets` |
| swift-geometry-primitives | `BezierSegment` | `Geometry.Bezier.Segment` |
| swift-geometry-primitives | `CardinalDirection` | `Geometry.Direction` |
| swift-geometry-primitives | `AffineTransform` | `Geometry.Transform` |

After: build tiers 13-20.

### Tier 17 renames

| Package | Old | New |
|---------|-----|-----|
| swift-parser-primitives | `ParserPrinter` | `Parser.Bidirectional` |
| swift-parser-primitives | `LocatedError` | `Parser.Error.Located` |
| swift-parser-primitives | `EndOfInput` | `Parser.End` |
| swift-parser-primitives | `CollectionInput` | `Parser.Input.Collection` |
| swift-parser-primitives | `ByteInput` | `Parser.Input.Bytes` |
| swift-parser-primitives | `ByteStream` | `Parser.Input.Stream` |

After: build tiers 18-20.

### Tier 20 renames (zero cascading)

| Package | Old | New |
|---------|-----|-----|
| swift-pool-primitives | `TryAcquire` | `Acquire.Try` |
| swift-pool-primitives | `CallbackAcquire` | `Acquire.Callback` |
| swift-pool-primitives | `TimeoutAcquire` | `Acquire.Timeout` |
| swift-pool-primitives | `AcquireAction` | `Acquire.Action` |
| swift-pool-primitives | `ReleaseAction` | `Release.Action` |
| swift-pool-primitives | `TryAcquireAction` | `Acquire.Try.Action` |
| swift-pool-primitives | `CallbackAcquireAction` | `Acquire.Callback.Action` |
| swift-pool-primitives | `CommitAction` | `Fill.Action` |
| swift-pool-primitives | `DrainAction` | `Shutdown.Action` |
| swift-cache-primitives | `__CacheEvict` | Internalize (remove hoisting) |
| swift-cache-primitives | `__CacheCompute` | Internalize (remove hoisting) |

No downstream builds needed.

**Estimated effort**: ~6 hours for all of Pass 4.

---

## Pass 5: Property.View Compound Method Refactoring

**Direction**: Tier 0 → Tier 20
**Risk**: High — public API change affecting call sites in consumer packages and potentially in standards/foundations
**Build verification**: After refactoring in tier N, build every tier from N through 20 to find and fix all breakage.

This is the largest pass. Each compound method becomes a Property.View nested accessor. The pattern:

```
Before: instance.childCount(of: node)
After:  instance.child.count(of: node)
```

### Design decisions needed BEFORE starting Pass 5

1. **`is*` predicates** (`isHorizontal`, `isLeapYear`, `isCardinal`): Are these compound violations or conventional Swift predicate naming? If conventional → ~40 findings become accepted exceptions.

2. **Statistical terms** (`standardDeviation`, `coefficientOfVariation`, `medianAbsoluteDeviation`): Grant [API-NAME-003] exception for established domain vocabulary? If so → ~15 findings become accepted exceptions.

3. **stdlib-convention names** (`reserveCapacity`, `removeAll`, `popFirst`, `makeIterator`): Already accepted as non-violations. Confirm.

### Execution order (tier 0 → tier 20, grouped by domain)

#### 5a. Dimension compound names (tier 9)

Already partially addressed in Pass 1b (duplicate removal). Any remaining compound names.

#### 5b. Region/spatial (tier 10)

| Current | Proposed |
|---------|----------|
| `isHorizontal` | `is.horizontal` or accept as predicate convention |
| `isVertical` | `is.vertical` or accept |
| `rotateClockwise` | `rotate.clockwise` |
| `rotateCounterClockwise` | `rotate.counterClockwise` |
| `isCardinal` | `is.cardinal` or accept |
| `isIntercardinal` | `is.intercardinal` or accept |

After: build tiers 11-20.

#### 5c. Sample statistical terms (tier 11)

Depends on design decision #2. If refactoring:

| Current | Proposed |
|---------|----------|
| `standardDeviation` | `standard.deviation` |
| `coefficientOfVariation` | `coefficient.ofVariation` |
| `medianAbsoluteDeviation` | `median.absoluteDeviation` |
| `outlierCount` | `outlier.count` |
| `isRegression` | `is.regression` or accept |
| `isImprovement` | `is.improvement` or accept |
| `exceedsTolerance` | `exceeds.tolerance` |

After: build tiers 12-20.

#### 5d. Binary cursor (tier 14)

| Current | Proposed |
|---------|----------|
| `moveReaderIndex(...)` | `reader.move(...)` |
| `setReaderIndex(...)` | `reader.set(...)` |
| `moveWriterIndex(...)` | `writer.move(...)` |
| `setWriterIndex(...)` | `writer.set(...)` |
| `readableCount` | `readable.count` |
| `writableCount` | `writable.count` |
| `readableBytes` | `readable.bytes` |

After: build tiers 15-20.

#### 5e. Heap CS terms (tier 16)

| Current | Proposed | Note |
|---------|----------|------|
| `bubbleUp` | Keep — internal per [IMPL-024] | Verify access level is `package`/`internal` |
| `trickleDown` | Keep — internal per [IMPL-024] | Same |
| `removePriority` | `remove.priority` | Public API |
| `replacePriority` | `replace.priority` | Public API |

After: build tiers 17-20.

#### 5f. Queue/Set (tier 17)

Compound names in queue + set that aren't stdlib conventions.

After: build tiers 18-20.

#### 5g. Windows platform (tier 18)

~32 `get*/set*` compound methods → Property.View:

| Current | Proposed |
|---------|----------|
| `getOption(...)` | `option.get(...)` or `option(...)` |
| `setOption(...)` | `option.set(...)` |
| `standardInput` | `standard.input` |
| `standardOutput` | `standard.output` |
| `getCurrentId()` | `current.id` |
| `getExitCode()` | `exit.code` |
| etc. | etc. |

After: build tiers 19-20.

#### 5h. Tree navigation (tier 19)

| Current | Proposed | Count |
|---------|----------|-------|
| `childCount(of:)` | `child.count(of:)` | ×5 variants |
| `removeSubtree(at:)` | `remove.subtree(at:)` | ×5 variants |
| `leftmostChild(of:)` | `child.leftmost(of:)` | ×1 |
| `rightmostChild(of:)` | `child.rightmost(of:)` | ×1 |
| `forEachPreOrder` | `forEach.preOrder` | ×5 |
| `forEachPostOrder` | `forEach.postOrder` | ×5 |
| `forEachLevelOrder` | `forEach.levelOrder` | ×5 |
| `forEachInOrder` | `forEach.inOrder` | ×5 |

After: build tier 20.

#### 5i. Cache + other tier 20 (tier 20, zero cascading)

| Current | Proposed |
|---------|----------|
| `cachedValue(for:)` | `cached.value(for:)` or `value(for:)` |
| `setValue(_:for:)` | `set.value(_:for:)` or `set(_:for:)` |
| `removeValue(for:)` | `remove.value(for:)` or `remove(for:)` |
| `computeAndPublish(...)` | Internal — `compute.andPublish(...)` |

No downstream builds needed.

**Estimated effort**: ~16 hours for all of Pass 5 (largest pass).

---

## Pass 6: File Organization (One-Type-Per-File)

**Direction**: Tier 0 → Tier 20 (consistency, but order is irrelevant — no API changes)
**Risk**: None — file moves only, no API changes
**Build verification**: `swift build` in changed package

### Top offenders

| Package | Tier | Current | Split into |
|---------|------|---------|-----------|
| swift-dimension-primitives | 9 | Dimension.swift (4+ types) | 5+ files |
| swift-hash-table-primitives | 16 | Hash.Table.swift (8 types) | 8 files |
| swift-queue-primitives | 17 | Queue.swift (9 types) | 9 files |
| swift-queue-primitives | 17 | Queue.Error.swift (11 enums) | 11 files or per-variant error files |
| swift-kernel-primitives | 17 | Multiple files with 2-3 types | Split |
| swift-dictionary-primitives | 18 | Dictionary.Ordered.swift (5 types) | 5 files |
| swift-darwin-primitives | 18 | Darwin.Identity.UUID.swift (2 types) | 2 files |
| swift-cache-primitives | 20 | Cache.swift (4 types) | 4 files |
| swift-cache-primitives | 20 | Cache.Entry.swift (3 types) | 3 files |

**Procedure**: Create new files, move types, update any file-scoped access control, build, test, commit.

**Estimated effort**: ~4 hours for all of Pass 6.

---

## Execution Summary

| Pass | Description | Direction | Risk | Effort | Findings addressed | Status |
|------|-------------|-----------|------|--------|-------------------|--------|
| 1 | Mechanical fixes (throws, duplicates, filenames) | T0→T20 | None | ~2h | ~25 | **DONE** |
| 2 | Additive infrastructure (overloads, operators) | T0→T20 | None | ~4h | ~0 (enables Pass 3) | **DONE** (descoped) |
| 3 | Consumer cleanup (.rawValue, Int(bitPattern:), __unchecked) | T0→T20 | Low | ~8h | ~200 | **DONE** |
| 4 | Compound type renames | T0→T20 | Medium | ~6h | ~30 | Not started |
| 5 | Property.View method refactoring | T0→T20 | High | ~16h | ~250 | Not started |
| 6 | File organization (one-type-per-file) | T0→T20 | None | ~4h | ~60 | **DONE** |
| **Total** | | | | **~40h** | **~565** | |

### Pass 1 Completion Notes (2026-03-20)

Committed per tier across 6 submodules:

| Tier | Package | Commit | Changes |
|------|---------|--------|---------|
| 9 | swift-dimension-primitives | `d1b7c21` | Rename Arithmatic→Arithmetic (2 files), fix header, remove 7 compound statics, unify sixty/thirty into BinaryFloatingPoint |
| 10 | swift-algebra-linear-primitives | `e00168f` | Rename Arithmatic→Arithmetic, fix header |
| 12 | swift-geometry-primitives | `31fb44d` | Rename Arithmatic→Arithmetic, fix header, replace .halfPi/.twoPi→.pi.half/.pi.two in 6 files |
| 17 | swift-kernel-primitives | `4a5aa4b` | Replace fatalError() with __unchecked init in Event.ID.init(_ value: Int32) |
| 20 | swift-cache-primitives | `12a96d0` | throws→throws(Cache.Error) on 4 methods, single catch for continuation bridge |
| 20 | swift-pool-primitives | `13f1d1b` | DESIGN comment documenting intentional untyped throws on create closure |

**Pool typed throws descoped**: Changing `create` closure to `throws(Pool.Error)` would break consumer API (contradicts "zero cascade"). Documented with DESIGN comment per audit recommendation.

### Pass 2 Completion Notes (2026-03-20)

Committed per tier across 3 submodules:

| Tier | Package | Commit | Changes |
|------|---------|--------|---------|
| 3 | swift-cardinal-primitives | `119593f` | `UInt32.init<C: Cardinal.Protocol>` — generic overload for bare + tagged |
| 4 | swift-ordinal-primitives | `25bd738` | `Array.subscript` generalized from `Ordinal` to `Ordinal.Protocol` |
| 13 | swift-memory-primitives | `b82d20d` | `.bitPattern` property, generic pointer inits for `Tagged<Tag, Memory.Address>` |

**Descoped from plan based on [INFRA-200] principled absence**:
- `UnsafePointer + Index<Element>` / `+ Count` — "add vectors (offsets) to points, not scalars (counts)." Consumer cleanup should use existing affine offset operators or typed pointer subscripts.
- `InlineArray.subscript(Index<Element>)` — already exists as `Ordinal.Protocol`.
- `Int(bitPattern: Tagged<Tag, Cardinal>)` and `Int(bitPattern: Tagged<Tag, Affine.Discrete.Vector>)` — already exist.

### Pass 3a Completion Notes (2026-03-20)

**All `.rawValue.rawValue` chains eliminated from Sources/**: 0 remaining (was 42).

| Tier | Package | Commit | Sites fixed |
|------|---------|--------|-------------|
| 5 | swift-affine-primitives | `0b04f4b` | 6 pointer operator sites → `Int(bitPattern:)` |
| 7 | swift-source-primitives | `51a075e` | 1 site → `Int(bitPattern: position.column)` |
| 14 | swift-binary-primitives | `66aa856` | 6 sites in Cursor/Reader → `Int(bitPattern: offset)` |
| 15 | swift-buffer-primitives | `2cf392c6` | 2 arena sites → `UInt32(header.highWater)` |
| 17 | swift-kernel-primitives | `71a4c0f` | 3 triple-chain sites → `.bitPattern` |
| 17 | swift-queue-primitives | `f9e46d6` | 5 sites → `Int(bitPattern: index)` |
| 20 | swift-binary-parser-primitives | `8fbe932` | 1 site → `Int(bitPattern: offset)` |

**Justified (not changed):**
- swift-affine-primitives Tagged+Affine.swift (8 sites): same-package implementations with mixed conversion semantics (Count↔Offset, overflow checks). These are infrastructure boundary code per [CONV-002].
- swift-algebra-modular-primitives (1 site): overflow-reporting multiplication — no typed equivalent per [INFRA-200].
- swift-heap-primitives (1 site): Cardinal division — principled absence per [INFRA-200], documented in code.
- swift-source/text-primitives encoding sites: UInt encoding for Codable — boundary code.
- 3 commented-out lines in buffer-primitives.

### Pass 3b/3c Completion Notes (2026-03-20)

Swept all 12 packages from tier 5→20. Changes in 7 packages, 5 confirmed clean (boundary-only usage).

| Tier | Package | Commit | Changes |
|------|---------|--------|---------|
| 5 | swift-affine-primitives | `c7e3ad4` | 8 sites in Tagged+Affine.swift: `.rawValue.rawValue` → `.cardinal`/`.vector` semantic accessors + `Int(bitPattern:)` delegation |
| 9 | swift-algebra-modular-primitives | `a27e1f7` | 1 site: `.rawValue.rawValue` → `.ordinal.rawValue` |
| 15 | swift-buffer-primitives | user-fixed | `__unchecked` → `.retag()` typed init; `minimumCapacity` → `.retag(UInt8.self)` |
| 16 | swift-hash-table-primitives | `0a587ec` | 5 sites: `Int(bitPattern: bucket.position)` → typed `InlineArray[bucket]` subscript; `.position.rawValue` → `Int(bitPattern:)` |
| 17 | swift-queue-primitives | `3ee4a5b` | 2 sites: `Index(__unchecked: (), Ordinal(...))` → `Index(Ordinal(...))` via `Ordinal.Protocol` init |
| 17 | swift-set-primitives | `0c32e3a` | 1 site: `__unchecked` Count init → `Cardinal.Protocol` typed init |
| 20 | swift-binary-parser-primitives | `14b8f670` | 4 sites: `Int(bitPattern: count.rawValue)` → `Int(bitPattern: count)` using Tagged overload |

**Confirmed clean (no non-boundary changes needed):**
- Tier 13: swift-memory-primitives — all `Int(bitPattern:)` at stdlib boundaries
- Tier 14: swift-binary-primitives — all at arithmetic boundaries, proper Tagged overloads used
- Tier 17: swift-kernel-primitives — already clean from 3a
- Tier 18: swift-dictionary-primitives — all at stdlib boundaries (underestimatedCount, endIndex, subscript validation)
- Tier 19: swift-tree-primitives — all at boundary between typed indices and raw Int storage

### Pass 6 Completion Notes (2026-03-20)

Swept all packages listed in plan. 3 packages split, remainder justified as exceptions.

| Tier | Package | Commit | Changes |
|------|---------|--------|---------|
| 9 | swift-dimension-primitives | `a433ac7` | Split Dimension.swift → Spatial.swift, Coordinate.swift, Displacement.swift, Extent.swift, Measure.swift |
| 17 | swift-kernel-primitives | `e8b16a1` | Split Process.ID, Directory.Entry, Directory.Error to own files |
| 20 | swift-cache-primitives | `a62e936` | Split Cache Storage/State/Action and Entry State/Waiters to own files |

**Justified exceptions (not split):**
- **swift-hash-table-primitives**: `Hash.Table.Static` has value-generic parameter — must stay in primary declaration (Swift compiler limitation). Tag enums are 2-5 line trivials.
- **swift-queue-primitives**: All nested types must stay in primary declaration due to `~Copyable` constraint propagation compiler bug (MEM-COPY-006). Error types are hoisted module-level (API-EXC-001), 3-5 lines each.
- **swift-dictionary-primitives**: Nested types required for `~Copyable` constraint propagation.
- **swift-darwin-primitives**: Identity/UUID namespace enums are 1-line trivials.

### Remaining after all passes

~135 findings will remain as either:
- **Accepted exceptions**: `is*` predicates, stdlib-convention names, spec-mirroring
- **Design decisions pending**: statistical term conventions, geometry `.rawValue` density in coordinate-mixing algorithms
- **INFO/OK-level observations**: boundary-correct `.rawValue` usage documented but not violating

### Build verification cadence

| Scope | When | Command |
|-------|------|---------|
| Changed package | After every change | `cd swift-X-primitives && swift build && swift test` |
| All downstream tiers | After any public API change in tier N | Build every package in tiers N+1 through 20. Fix breakage at each tier before proceeding. |
| Cross-repo spot-check | After each pass completion | Grep swift-standards + swift-foundations for changed names |

### Git strategy

- One commit per tier per pass (all changes at one tier level in a single commit)
- Commit message: `[audit] Pass N: description — tier K (package list)`
- No amending — new commits only
- Consider a branch per pass for review

### Handoff

Each pass is a self-contained unit of work for a new conversation:

> Read `/Users/coen/Developer/swift-institute/Research/audits/implementation-naming-2026-03-20/01-remediation-plan.md` and execute Pass N. Work tier 0 → tier 20. For each tier, edit the code, run `swift build && swift test`, fix any downstream breakage at the next tier, and commit per tier.

For detailed findings per package, read the corresponding audit file in the same directory.
