# Pass 4: Compound Type Renames — Handoff Prompt

Read `Research/audits/implementation-naming-2026-03-20/01-remediation-plan.md` for full context. This prompt executes **Pass 4: Compound Type Renames**.

## Context

Passes 1, 2, 3, and 6 are complete. This is the first pass that changes **public API**. Each rename may break downstream consumers within the superrepo, and potentially in swift-standards and swift-foundations.

## Rule

**[API-NAME-001]**: All types MUST use the `Nest.Name` pattern. Compound type names are FORBIDDEN.

## Direction

Tier 0 → Tier 20 (foundation-first). A rename in tier N may break tiers N+1 through 20. After renaming, build downstream to find and fix all breakage before committing.

## Tier listing for reference

```
Tier 0  (15 pkgs): algebra, ascii, base62, coder, decimal, error, identity, lifetime, ownership, positioning, property, random, reference, serializer, stdlib-extensions
Tier 1  (9 pkgs):  ascii-serializer, dependency, equation, formatting, locale, logic, numeric, outcome, scalar
Tier 3  (8 pkgs):  algebra-magma, cardinal, clock, hash, optic, ordering, predicate, state
Tier 12 (4 pkgs):  bit-vector, geometry, space, transform
Tier 17 (4 pkgs):  kernel, parser, queue, set
Tier 20 (6 pkgs):  binary-parser, cache, parser-machine, pool, rendering, test
```

## Execution strategy

For each rename (working tier 0 → tier 20):

1. **Grep the entire superrepo** first: `grep -rn 'OldName' swift-*/Sources/ swift-*/Tests/` to find all usage sites
2. **Also grep cross-repo**: `grep -rn 'OldName' https://github.com/swift-standards*/Sources/ https://github.com/swift-foundations*/Sources/` — note cross-repo usage but do NOT fix it in this pass (separate follow-up)
3. **Rename the declaration** in the declaring package
4. **Update all usage sites** within swift-primitives (Sources AND Tests)
5. **Build the declaring package**: `cd swift-X-primitives && swift build`
6. **Build downstream consumers** tier by tier until tier 20 — fix any breakage
7. **Test the declaring package**: `swift test`
8. **Test any consumer packages** that were changed
9. **Commit** all changes atomically: `[audit] Pass 4: rename OldName → New.Name — swift-X-primitives`

## Renames by tier

### Tier 0

**swift-ascii-primitives** (4 renames):

| Old | New | Notes |
|-----|-----|-------|
| `GraphicCharacters` | `Graphic` | Already nested in `ASCII` → becomes `ASCII.Graphic` |
| `ControlCharacters` | `Control` | Already nested in `ASCII` → becomes `ASCII.Control` |
| `CaseConversion` | Needs design: `ASCII.Case` may conflict with existing concepts | Check if `ASCII.Case` exists; if so, consider `ASCII.Conversion.Case` |
| `LineEnding` | `Line.Ending` | Requires `ASCII.Line` namespace enum to exist |

**swift-base62-primitives** (3 renames):

| Old | New | Notes |
|-----|-----|-------|
| `IntegerWrapper` | `Integer` | Already nested in `Base62_Primitives` |
| `StringWrapper` | `String` | Nested — but `String` shadows Swift.String. Consider `Text` or `Encoded` instead |
| `CollectionWrapper` | `Bytes` | Already nested in `Base62_Primitives` |

**swift-standard-library-extensions** (1 rename):

| Old | New | Notes |
|-----|-----|-------|
| `CaseInsensitive` | Design needed: `String.Case` already exists as a transformation struct. `Case.Insensitive` requires `Case` to become a namespace. | Check current `String.Case` usage before renaming |

### Tier 1

**swift-formatting-primitives** (4 renames):

| Old | New | Notes |
|-----|-----|-------|
| `FormatStyle` | `Format.Style` | Protocol — all conformers need updating. `Format` namespace enum must exist. |
| `FloatingPoint` | `Format.Decimal` or `Format.Real` | Current name shadows `Swift.FloatingPoint`. Pick name that doesn't shadow. |
| `SignDisplayStrategy` | `Sign.Strategy` | Already nested in `Format.Numeric` → becomes `Format.Numeric.Sign.Strategy` |
| `DecimalSeparatorStrategy` | `Separator.Strategy` | → `Format.Numeric.Separator.Strategy` |

### Tier 3

**swift-ordering-primitives** (1 rename):

| Old | New | Notes |
|-----|-----|-------|
| `PartialComparator` | `Comparator.Partial` | Already nested in `Ordering` → becomes `Ordering.Comparator.Partial` |

### Tier 12

**swift-geometry-primitives** (4 renames):

| Old | New | Notes |
|-----|-----|-------|
| `EdgeInsets` | `Insets` | Already nested in `Geometry` → becomes `Geometry.Insets`. Or `Edge.Insets` if `Geometry.Edge` namespace exists. |
| `BezierSegment` | `Bezier.Segment` | `Geometry.Bezier` already exists — nest `Segment` inside it |
| `CardinalDirection` | `Direction` | Already nested in `Geometry` → becomes `Geometry.Direction`. The 4 cardinal cases make "Cardinal" redundant. |
| `AffineTransform` | `Transform` | Typealias to `Affine.Continuous.Transform` — the "Affine" is redundant in the alias name |

### Tier 17

**swift-parser-primitives** (6 renames):

| Old | New | Notes |
|-----|-----|-------|
| `ParserPrinter` | `Bidirectional` or `Invertible` | Protocol combining Parser + Printer. Nested in `Parser`. |
| `LocatedError` | `Located` (protocol) | Already nested in `Parser.Error` → `Parser.Error.Located` |
| `EndOfInput` | `End` | Already nested in `Parser` → `Parser.End` |
| `CollectionInput` | `Input.Collection` | Typealias — nest under `Parser.Input` |
| `ByteInput` | `Input.Bytes` | Typealias |
| `ByteStream` | `Input.Stream` | Typealias |

### Tier 20 (zero cascading — safest, do these first as warm-up)

**swift-pool-primitives** (9 renames):

| Old | New | Notes |
|-----|-----|-------|
| `TryAcquire` | `Acquire.Try` | `Pool.Bounded.Acquire` namespace exists |
| `CallbackAcquire` | `Acquire.Callback` | |
| `TimeoutAcquire` | `Acquire.Timeout` | |
| `AcquireAction` | `Acquire.Action` | |
| `ReleaseAction` | `Release.Action` | Needs `Release` namespace |
| `TryAcquireAction` | `Acquire.Try.Action` | |
| `CallbackAcquireAction` | `Acquire.Callback.Action` | |
| `CommitAction` | `Fill.Action` | Needs `Fill` namespace |
| `DrainAction` | `Shutdown.Action` | Needs `Shutdown` namespace |

**swift-cache-primitives** (2 renames):

| Old | New | Notes |
|-----|-----|-------|
| `__CacheEvict` | Internalize — remove hoisting, make nested `Cache.Evict` | If compiler allows (check generic nesting) |
| `__CacheCompute` | Internalize — remove hoisting, make nested `Cache.Compute` | Same |

## Recommended execution order

Start with **Tier 20** (pool, cache) as warm-up — zero cascading risk. Then work upward:

1. **Tier 20**: pool (9 renames), cache (2 renames) — no downstream consumers
2. **Tier 17**: parser (6 renames) — consumers in tiers 18-20
3. **Tier 12**: geometry (4 renames) — consumers in tiers 13-20
4. **Tier 3**: ordering (1 rename) — consumers in tiers 4-20
5. **Tier 1**: formatting (4 renames) — consumers in tiers 2-20
6. **Tier 0**: ascii (4), base62 (3), stdlib-extensions (1) — consumers in tiers 1-20

This is opposite to the plan's "tier 0 first" because starting at leaves lets you build confidence with zero-risk renames before tackling cascading ones.

## Execution status

### Tier 20 — COMPLETE

**swift-pool-primitives** (9 renames) — all done, 62 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `TryAcquire` | `Acquire.Try` | Moved from `extension Pool.Bounded` to `extension Pool.Bounded.Acquire` |
| `CallbackAcquire` | `Acquire.Callback` | Same pattern |
| `TimeoutAcquire` | `Acquire.Timeout` | Same pattern |
| `AcquireAction` | `Acquire.Action` | Moved to `extension Pool.Bounded.Acquire`; `Slot.Index` required full qualification |
| `TryAcquireAction` | `Acquire.Try.Action` | Nested inside renamed `Acquire.Try` |
| `CallbackAcquireAction` | `Acquire.Callback.Action` | Nested inside renamed `Acquire.Callback` |
| `ReleaseAction` | `Release.Action` | New `Release` namespace enum created |
| `CommitAction` | `Fill.Commit` | Already inside `Fill`; just renamed |
| `DrainAction` | `Shutdown.Drain` | Already inside `Shutdown`; just renamed |

Lesson: bare `Slot.Index` is not accessible from `extension Pool.Bounded.Acquire` — must use `Pool.Bounded<Resource>.Slot.Index`.

**swift-cache-primitives** (2 renames → nested) — all done, 11 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `__CacheEvict` | `Cache.Evict` | Nested inside `Cache`. Uses `_Value` typealias to capture outer `Value` before `typealias Value = Void` shadows it. |
| `__CacheCompute` | `Cache.Compute<E>` | Nested inside `Cache`. Uses `_Value` typealias with `typealias Value = _Value` to satisfy `Effect.Protocol.Value`. |

Lesson: `Effect.Protocol` requires `associatedtype Value` which can't be inferred from outer generic parameters. Workaround: add `typealias _Value = Value` on `Cache` before the nested type shadows `Value`.

### Tier 17 — IN PROGRESS

**swift-parser-primitives** (6 renames) — design decisions resolved, implementation pending:

| Old | New | Status | Notes |
|-----|-----|--------|-------|
| `ParserPrinter` | `Bidirectional` | pending | Protocol rename. Nested in `Parser`. Small scope (~8 occurrences). |
| `LocatedError` | `Located.Protocol` | pending | Hoist protocol, add `typealias Protocol` on `Parser.Error.Located<E>`. **Experiment confirmed** this works — see `Experiments/generic-nested-typealias/`. Requirements: (1) struct must use `Swift.Error` not bare `Error`, (2) declaring module conformance uses hoisted name, (3) consumers use typealias path. |
| `EndOfInput` | **needs design** | blocked | `Parser.End<Input>` already exists as a generic parser struct. Nesting `EndOfInput.Error` inside it creates per-instantiation error types (different type for each `Input`). Options: (a) restructure `End` into namespace, (b) find non-compound single-word name, (c) accept compound name as domain term. |
| `CollectionInput` | **needs design** | blocked | `Parser.Input` is a typealias to `Input_Primitives.Input.Protocol`, not a namespace. Can't nest under it without restructuring. |
| `ByteInput` | **needs design** | blocked | Same issue as `CollectionInput`. 559 occurrences across 46 files. |
| `ByteStream` | **needs design** | blocked | Same issue as `CollectionInput`. |

### Tier 12 — COMPLETE

**swift-geometry-primitives** (4 renames) — all done, 382 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `EdgeInsets` | `Insets` | Already nested in `Geometry` |
| `BezierSegment` | `Bezier.Segment` | Moved from `Geometry.Ball` to `Geometry.Bezier` |
| `CardinalDirection` | `Direction` | Cardinal implicit from 4 cases |
| `AffineTransform` | `Transform` | Affine redundant, aliases `Affine.Continuous.Transform` |

Cross-repo: `EdgeInsets` referenced in swift-standards (PDF) and swift-foundations (PDF rendering) — noted, not fixed.

### Tier 3 — COMPLETE

**swift-ordering-primitives** (1 rename) — all done, 45 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `PartialComparator` | `Comparator.Partial` | Nested inside generic `Comparator<T>`. Usage: `Ordering.Comparator<Double>.Partial { ... }` |

### Tier 1 — COMPLETE

**swift-formatting-primitives** (4 renames) — all done, 12 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `FormatStyle` | `Format.Style` | Protocol. Associated types `FormatInput`/`FormatOutput` → `Input`/`Output`. |
| `FloatingPoint` | `Format.Decimal` | Avoids `Swift.FloatingPoint` shadow |
| `SignDisplayStrategy` | `Sign` | Already in `Format.Numeric` |
| `DecimalSeparatorStrategy` | `Separator` | Already in `Format.Numeric` |

Downstream consumers updated: swift-time-primitives, swift-algebra-linear-primitives.
Cross-repo: one file in swift-foundations (swift-translating) — noted, not fixed.

### Tier 0 — PARTIAL

**swift-ascii-primitives** (2 of 4 done):

| Old | New | Status | Notes |
|-----|-----|--------|-------|
| `GraphicCharacters` | `Graphic` | done | 230 occurrences updated. Downstream: swift-kernel-primitives updated. Cross-repo: 25+ in swift-foundations (SVG) — noted, not fixed. |
| `ControlCharacters` | `Control` | done | |
| `CaseConversion` | **needs design** | blocked | `ASCII.Case` already exists. Options: nest as `ASCII.Case.Conversion`, or rename to `ASCII.Conversion`. |
| `LineEnding` | **needs design** | blocked | Need `ASCII.Line` namespace. |

**swift-base62-primitives** (3 of 3 done) — 120 tests pass:

| Old | New | Notes |
|-----|-----|-------|
| `IntegerWrapper` | `Integer` | Already nested in `Base62_Primitives` |
| `StringWrapper` | `Text` | Avoids `Swift.String` shadow |
| `CollectionWrapper` | `Bytes` | Already nested in `Base62_Primitives` |

**swift-standard-library-extensions** (0 of 1):

| Old | New | Status | Notes |
|-----|-----|--------|-------|
| `CaseInsensitive` | **needs design** | blocked | `String.Case` already exists as a struct. Need to restructure to make `Case` a namespace. |

## Design decisions needed during execution

Several renames have ambiguity noted in the table. When you encounter these:

1. **Check what exists**: Before creating a namespace like `ASCII.Line`, verify no `Line` type already exists in `ASCII`.
2. ~~**Shadow avoidance**: `Base62_Primitives.String`~~: **RESOLVED** — renamed to `Text`.
3. ~~**Protocol renames**: `FormatStyle` → `Format.Style`~~: **RESOLVED** — conformers in time-primitives and algebra-linear-primitives updated.
4. ~~**Hoisting removal** (cache `__CacheEvict`/`__CacheCompute`)~~: **RESOLVED** — both nested via `_Value` typealias workaround.
5. **`EndOfInput` → `End` conflict**: `Parser.End<Input>` already exists. Nesting `Error` inside a generic struct creates per-instantiation types. Needs design decision.
6. **`CollectionInput`/`ByteInput`/`ByteStream` → `Input.*`**: `Parser.Input` is a typealias, not a namespace. Restructuring required before these can be nested.

## Discoveries (applied to this and future passes)

1. **Bare `Error` in `.Error` namespaces creates circular references.** Types nested inside namespaces named `Error` (like `Parser.Error.Located`) MUST use `Swift.Error` (fully qualified) in conformance/inheritance clauses.
2. **Generic nested typealiases work without specifying outer generic parameters.** `Parser.Error.Located.Protocol` (typealias on `Located<E>`) is accessible without specifying `E`. Confirmed via experiment.
3. **Self-referential conformance cycles.** `extension T: T.Alias` creates a cycle. Declaring module must conform via hoisted name; consumers use the typealias path.
4. **`_Value` capture pattern.** When a nested type needs the outer generic parameter but shadows it (e.g., `typealias Value = Void` shadows `Cache<Key, Value>.Value`), add `typealias _Value = Value` on the outer type before the shadow.

## What NOT to change in this pass

- **Compound method/property names** — that's Pass 5
- **File organization** — Pass 6 is complete
- **Cross-repo consumers** (swift-standards, swift-foundations) — note them, don't fix them

## Build verification

After each tier of renames:
```bash
# Build the declaring package
cd swift-X-primitives && swift build

# Build ALL downstream consumers that grep showed usage
# For tier 0 renames, this could be many packages
cd swift-Y-primitives && swift build
cd swift-Z-primitives && swift build
# ... etc

# Test declaring package + all changed consumers
cd swift-X-primitives && swift test
```

## Audit files for reference

Per-package audit details (exact line numbers, current code):
- `Research/audits/implementation-naming-2026-03-20/swift-ascii-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-base62-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-standard-library-extensions.md`
- `Research/audits/implementation-naming-2026-03-20/swift-formatting-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-ordering-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-geometry-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-parser-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-pool-primitives.md`
- `Research/audits/implementation-naming-2026-03-20/swift-cache-primitives.md`

## Estimated effort

~6 hours across 9 packages, ~30 type renames.
