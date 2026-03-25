# PredictableDeadAllocationElimination: Spurious destroy_value via Lifetime Completion

<!--
---
version: 1.0.0
last_updated: 2026-03-24
status: DECISION
---
-->

## Context

Our defense-in-depth fix for swiftlang/swift#88022 (SimplifyMarkDependence guard for ~Escapable types) works, but the deeper root cause is in PredictableDeadAllocationElimination. Before filing an issue or proposing a fix, we need to pinpoint the exact mechanism.

**Trigger**: [RES-001] — Design question arose during PR review feedback. @eeckstein may ask why we're not fixing the root cause.

**Prior work**: `compiler-pr-copypropagation-mark-dependence-handoff.md` (v2.0.0) identified PredictableDeadAllocationElimination as the source but attributed the destroy_value to `InstructionDeleter.forceDelete`. This was **wrong**.

## Question

Where exactly does the spurious `destroy_value` come from when PredictableDeadAllocationElimination promotes a mark_dependence base from alloc_stack to a trivial value?

## Analysis

### Prior hypothesis (REFUTED)

The handoff doc claimed: "During deletion of the old mark_dependence, the InstructionDeleter inserts a compensating destroy_value for the init result."

**Refutation**: `promoteMarkDepBase` (PredictableMemOpt.cpp:2344) calls `deleter.forceDelete(md)`. The `forceDelete` implementation (InstructionDeleter.cpp:387) passes `fixLifetimes=false` to `deleteWithUses`. The compensation logic at InstructionDeleter.cpp:274 (`if (fixLifetimes)`) is therefore SKIPPED. No destroy_value is inserted by forceDelete.

### Actual mechanism (FOUND)

The spurious destroy_value comes from `completeOSSALifetime`, called during alloc_stack removal:

**Step 1 — Collection** (PredictableMemOpt.cpp:2054-2079):
When removing a dead alloc_stack, `tryToRemoveDeadAllocation` iterates the uses of the allocation. For store instructions (`PMOUseKind::Initialization`), it adds the **source value** to `valuesNeedingLifetimeCompletion` (line 2066: `auto src = si->getSrc()`).

**Step 2 — Mark dependence promotion** (PredictableMemOpt.cpp:2331-2346):
`promoteMarkDepBase` creates a NEW mark_dependence consuming the dependent value, then `forceDelete`s the old one. After this, the dependent value is consumed by the new mark_dependence — its lifetime is complete.

**Step 3 — Spurious destroy insertion** (exact mechanism under investigation):
A `destroy_value` is inserted for the dependent value during alloc_stack removal. `completeOSSALifetime` is **eliminated** as the source for this case — trivial alloc_stacks trigger an early return at line 2236 before lifetime completion runs. The most likely mechanism is `cleanupDeadInstructions()` (line 2492), which processes tracked dead instructions with `fixLifetimes=true`. When an instruction tracked by `trackIfDead` has consuming operands, `deleteWithUses` inserts compensating `destroy_value` instructions. The exact instruction that gets tracked requires a debug-enabled build to identify.

**Result**: The dependent value now has TWO consumers — the new mark_dependence (ForwardingConsume) AND the spurious `destroy_value`. This is a double consume.

### The SIL sequence

```
// Before PredictableDeadAllocationElimination:
%alloc = alloc_stack
%r = apply %init(...)                          // @owned ~Escapable
store %r to [init] %alloc                      // stores value to alloc_stack
%base = load [take] %alloc
%md = mark_dependence [nonescaping] %r on %base
yield %md, resume bb1, unwind bb2
bb1: destroy_value %md
bb2: destroy_value %md

// After promotion (mark_dependence base promoted to trivial):
%r = apply %init(...)                          // @owned ~Escapable
%md = mark_dependence [nonescaping] %r on %trivial  // NEW, consumes %r
destroy_value %r                               // from completeOSSALifetime
yield %md, resume bb1, unwind bb2
bb1: destroy_value %md
bb2: destroy_value %md
```

### Why only ~Escapable types

The bug requires:
1. `mark_dependence [nonescaping]` — created for `@_lifetime(borrow)` on ~Escapable types
2. The base operand being an alloc_stack that gets promoted
3. The dependent value being stored to the alloc_stack (triggering its inclusion in `valuesNeedingLifetimeCompletion`)

For Escapable types, `mark_dependence` is classified as `PointerEscape` (not `[nonescaping]`), and the SIL patterns are different.

### Fix options

**Option A: Skip lifetime completion for values consumed by promoted mark_dependence**

In `tryToRemoveDeadAllocation`, after `promoteMarkDepBase` runs, track which values are now consumed by new mark_dependences. Remove them from `valuesNeedingLifetimeCompletion`.

Pros: Targeted fix, addresses exact issue.
Cons: Requires threading information between promotion and completion phases.

**Option B: Check for existing consumers in completeOSSALifetime**

Before inserting a destroy_value, verify the value doesn't already have a consuming use (the new mark_dependence).

Pros: General safety improvement.
Cons: Could mask other bugs; may be too conservative.

**~~Option C: Exclude from lifetime completion~~ (ELIMINATED)**

`completeOSSALifetime` does not run for trivial alloc_stacks (early return at line 2236). Not applicable.

### Comparison

| Criterion | Option A | Option B |
|-----------|----------|----------|
| Precision | High | Medium |
| Complexity | Medium | Low |
| Risk of masking bugs | Low | Low |
| Generality | Narrow | Broad |

### Constraints

- The fix must be in `lib/SILOptimizer/Mandatory/PredictableMemOpt.cpp` (mandatory pass)
- Must not affect non-mark_dependence alloc_stack promotion
- Must preserve OSSA invariants
- Needs validation against existing lifetime_dependence tests

## Outcome

**Status**: DECISION — Already fixed upstream

**Root cause found**: Commit `214be2dda06` by @eeckstein (2025-10-03) fixed this exact bug. The original code used `deleter.deleteIfDead(md)` which calls `deleteWithUses(md, fixLifetimes=true)` — inserting compensating `destroy_value` for consuming operands. The fix changed it to `deleter.forceDelete(md)` which uses `fixLifetimes=false`.

```diff
-  deleter.deleteIfDead(md);
+  deleter.forceDelete(md);
```

Commit message: "This was a wrong use of the InstructionDeleter. When replacing a mark_dependence with a new one the old one has to be deleted _without_ fixing its lifetime. Otherwise destroy_value instructions are inserted, which is obviously wrong."

**Why our static analysis was wrong**: We were reading the FIXED code (on the built compiler from `main` / 6.4-dev) while the bug exists in the SYSTEM TOOLCHAIN (6.2.4). The fixed code uses `forceDelete` (fixLifetimes=false); the broken code used `deleteIfDead` (fixLifetimes=true).

**Impact on our PRs**: The SimplifyMarkDependence guard is still valuable as defense-in-depth for users on 6.2.x toolchains. The guard comment should reference the upstream fix.

See: `swift-institute/Experiments/predictable-memopt-destroy-value-source/EXPERIMENT.md`

## References

- swiftlang/swift#88022 — CopyPropagation crash
- `compiler-pr-copypropagation-mark-dependence-handoff.md` — prior (partially incorrect) analysis
- `PredictableMemOpt.cpp:2331-2346` — promoteMarkDepBase
- `PredictableMemOpt.cpp:2054-2079` — value collection for lifetime completion
- `OSSALifetimeCompletion.cpp:565-598` — completeOSSALifetime
- `InstructionDeleter.cpp:383-388` — forceDelete (fixLifetimes=false)
