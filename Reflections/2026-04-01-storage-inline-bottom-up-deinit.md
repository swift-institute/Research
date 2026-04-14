---
date: 2026-04-01
session_objective: Investigate Buffer.Arena.Inline storage alignment, then discover and validate bottom-up deinit for Storage.Inline
packages:
  - swift-storage-primitives
  - swift-buffer-primitives
  - swift-queue-primitives
  - swift-stack-primitives
  - swift-array-primitives
  - swift-heap-primitives
  - swift-set-primitives
  - swift-dictionary-primitives
  - swift-list-primitives
  - swift-slab-primitives
  - swift-tree-primitives
status: processed
---

# Storage.Inline Bottom-Up Deinit — From Workaround Cascade to One-Line Fix

## What Happened

Session began with an investigation handoff about Buffer.Arena.Inline hand-rolling its own @_rawLayout storage instead of composing Storage.Arena.Inline. Discovered two root causes: (1) Storage.Arena.Inline is a bump allocator, not a Meta-tracked arena — wrong model, (2) #86652 forced same-module @_rawLayout to avoid cross-module triggers.

This led to a broader architecture discussion about the 4-layer separation (Memory ← Storage ← Buffer ← DataStructure) and why inline types struggle with cleanup ownership. Explored three approaches:

1. **Top-down consuming pattern**: Data structure deinit calls `buffer.removeAll()` (consuming) → `storage.cleanup()` (consuming). Validated cross-module in a 4-module experiment. Key discovery: consuming method calls work in deinit bodies — the compiler allows consuming stored properties during destruction.

2. **Bottom-up Storage.Inline deinit**: Added `_deinitWorkaround: AnyObject?` + deinit to Storage.Inline. Field-ordering fix (already applied) resolves LLVM verifier crash. `_deinitWorkaround` resolves triviality misclassification. Tested cross-module, 3-layer, debug + release — works.

3. **Applied bottom-up to production**: Removed `_deinitWorkaround` + manual deinit from 18 data structure types across 8 packages. ~350 lines of workaround code removed. 8 bytes saved per instance. All existing deinit tests pass in release mode.

Initially two holdouts: Slab (signal 11) and Tree (Arena.Inline bypasses Storage.Inline). Both resolved via sub-agent investigation:

- **Slab**: Signal 11 was a double-free, not triviality misclassification. Buffer.Slab.Inline's deinit and Storage.Inline's deinit both fired on the same slots. Fix: removed Buffer.Slab.Inline's deinit entirely — Storage.Inline's bitvector already tracks Slab's slots correctly via Property.View accessors.
- **Tree**: Buffer.Arena.Inline needed its own `_deinitWorkaround` (it has @_rawLayout `_Elements` + deinit, same pattern as Storage.Inline). Added the field, removed Tree.N.Inline's workaround.

Final tally: 20 data structure types across 11 packages cleaned. Only two `_deinitWorkaround` fields remain in the ecosystem — Storage.Inline and Buffer.Arena.Inline (the two deinit owners). 1,320 tests pass in release mode. Also fixed pre-existing Storage.Pool test compile error (@Suite in generic extension) and converted all 4 buffer canary tests from withKnownIssue to positive regression tests.

Discovered one ecosystem gap: `Sequence.Protocol`'s `forEach` accessor is mutating-only, blocking borrowing iteration. Handoff written for investigation.

## What Worked and What Didn't

**Worked**: The bottom-up deinit is dramatically simpler than the consuming pattern. One change to Storage.Inline fixed 18 types at once. The consuming pattern (validated first) was technically correct but turned out to be unnecessary overhead — the investigation path was consuming → bottom-up, and bottom-up won decisively.

**Worked**: Questioning assumptions. The `rawlayout-release-crash-investigation.md` documented three "independent triggers" for #86652. The field-ordering fix (discovered 2026-03-22) resolved all three, but nobody retested the bottom-up model after the fix. One day's gap between the fix and the constraint documentation meant stale information persisted for 10 days.

**Didn't work initially**: Slab.Static crashed with signal 11. Incorrectly hypothesized as triviality misclassification. Sub-agent investigation revealed double-free: Buffer.Slab.Inline's bitmap-driven deinit used raw pointer deinitialize (bypassing `_slots` tracking), then Storage.Inline's deinit found `_slots` bits still set and deinitializes again. Fix was removing Buffer.Slab.Inline's deinit — the stale comment "Storage.Inline's initialization state stays .empty" was wrong; Property.View accessors already maintain `_slots`.

**Didn't work**: Assumed forEach ambiguity in tree tests was a test bug. It's an ecosystem gap — `Sequence.Protocol`'s `forEach` accessor is mutating-only, so `borrowing` parameters can't iterate. The test code is correct; the infrastructure is incomplete.

## Patterns and Root Causes

**Stale constraint assumptions are the most expensive kind of tech debt.** The #86652 constraint model was documented accurately for the state of the compiler on 2026-03-21. The field-ordering fix on 2026-03-22 invalidated the "blocked" status but the constraint documentation wasn't updated. For 10 days, every session that read that documentation assumed bottom-up deinit was impossible. The actual blocker was one `AnyObject?` field + field ordering — both already available.

**Pattern: investigate before propagating.** The consuming pattern was a valid intermediate step — it proved the concept and validated the cross-module chain. But the key question "is bottom-up actually blocked right now?" cut through the entire consuming architecture and arrived at a simpler answer. The session spent ~2 hours on consuming before asking that question. Earlier questioning would have saved time.

**Pattern: one-layer fix > N-layer workaround.** Adding deinit to Storage.Inline is a single change that fixes every consumer. Adding consuming cleanup to each buffer type requires per-type methods, per-data-structure deinits, and per-type testing. The leverage difference is 1:18.

## Action Items

- [x] ~~**[package]** swift-slab-primitives: Investigate Slab.Static signal 11~~ RESOLVED — double-free; removed Buffer.Slab.Inline's deinit
- [x] ~~**[package]** swift-tree-primitives: Investigate Tree.N.Inline deinit~~ RESOLVED — added _deinitWorkaround to Buffer.Arena.Inline
- [ ] **[research]** Borrowing forEach gap: Sequence.Protocol's forEach accessor is mutating-only, blocking `borrowing` parameter iteration. Handoff: `swift-sequence-primitives/HANDOFF-borrowing-foreach-gap.md`
