---
date: 2026-03-22
session_objective: Investigate whether Storage.Inline can have its own deinit, eliminating element leaks from Ring.Inline and Linear.Inline
packages:
  - swift-storage-primitives
  - swift-buffer-primitives
  - swift-list-primitives
  - swift-queue-primitives
  - swift-stack-primitives
  - swift-array-primitives
  - swift-heap-primitives
  - swift-set-primitives
  - swift-dictionary-primitives
  - swift-tree-primitives
  - swift-slab-primitives
status: pending
---

# From "Provably Impossible" to Compiler Fix in One Session

## What Happened

Started with a research handoff asking whether Storage.Inline could have its own deinit. The handoff proposed 7 investigation paths. Systematically tested all 7, plus 2 additional approaches (shared deinit wrapper, transitive pre-compilation). All failed.

Discovered the **2-field rule**: a struct with @_rawLayout field + any other field + deinit crashes under -O, regardless of module isolation, wrappers, or nesting. This was more specific than the previous "threshold" understanding.

Then discovered that encoding the bitmap within the @_rawLayout region via `@_rawLayout(like: CombinedLayout)` reduces Storage.Inline to 1 field — and a 1-field type with deinit builds in release. Verified empirically.

Then discovered the **access-level trigger**: `internal` types work, `public` types crash. Since Storage.Inline must be public, the combined layout approach was blocked.

Filed the access-level finding on swiftlang/swift#86652. Then located the exact bug in the Swift compiler source (`lib/IRGen/GenStruct.cpp:createNonFixed`): public ~Copyable types with deinit use element-wise destruction, which generates broken `invariant.load` LLVM IR for @_rawLayout fields. Internal types use VWT-based destruction, which works.

Wrote and validated a 21-line compiler fix. Tested against 2,284 compiler tests (0 failures). Built the Swift compiler from source, verified our reproducer passes, and confirmed zero LLVM verifier crashes in the swift-primitives superrepo release build.

Also reorganized the experiment and research corpus: deleted 14 superseded experiments, consolidated 9 handoff documents into 1, moved a cross-cutting experiment, updated 21 workaround comments across 10 packages with removal test instructions.

## What Worked and What Didn't

**What worked**:
- Systematic binary search for the crash trigger. Each test isolated one variable (field count, deps, access level, nesting). This produced a clear constraint model in ~2 hours.
- Building the Swift compiler from source. The fix-test cycle (edit GenStruct.cpp → ninja → test) was ~30 seconds per iteration once LLVM was built.
- The access-level finding was the breakthrough. Without it, the bug looked like a fundamental @_rawLayout limitation. With it, the bug narrowed to one codegen path difference between `public` and `internal`.

**What didn't work**:
- The initial investigation spent significant time on module isolation approaches that could never work (the 2-field rule is structural, not module-dependent).
- The combined @_rawLayout approach was a false positive — worked in the standalone test (internal, zero deps) but failed in production (public, deps). Should have tested with `public` access immediately.
- First compiler fix attempt targeted `GenType.cpp:isTypeABIAccessibleIfFixedSize` — a function that was never called for the crashing types. Debug prints revealed this. The actual entry point was `GenStruct.cpp:createNonFixed`, which uses a separate accessibility check.
- First narrowed fix was too broad (fired on all ~Copyable with deinit in createNonFixed), breaking `_Cell` tests. Needed further narrowing to only types containing @_rawLayout fields.
- Attempting to fix 6.4-dev compatibility issues in swift-primitives simultaneously with validating the compiler patch was a mistake. These are separate work items that should not be interleaved.

## Patterns and Root Causes

**The "one bug, wide blast radius" pattern**: swiftlang/swift#86652 is a single IRGen codegen divergence (element-wise vs VWT destruction for public ~Copyable types with @_rawLayout). But it cascades through the entire type hierarchy: Storage.Inline can't have deinit → buffer types need workaround deinits → data structure types need workaround deinits → 22 sites across 10 packages with `_deinitWorkaround: AnyObject?`. The fix is 21 lines in the compiler. The workaround is hundreds of lines spread across the ecosystem.

**The "standalone reproducer trap"**: Testing in isolation gives false positives. The standalone experiment (zero deps, internal types, one file) passed, leading to hours of investigation into why the production build still failed. The production context (public types, many modules, WMO) is qualitatively different. Future experiments should immediately test with `public` access and real dependencies.

**The "layer at which to fix" question**: We explored fixing at every layer — storage-primitives, buffer-primitives, new modules, new packages. All failed because the bug is in the compiler, not in our code. The right answer was to fix the compiler. The reluctance to touch compiler source cost several hours of workaround exploration. When a bug is proven to be in the compiler, fix the compiler.

**Experiment corpus maintenance matters**: The 14 superseded experiments and 9 handoff documents were making it hard to find the actual current state of knowledge. Consolidation into a single investigation record with a clear timeline made the access-level discovery possible — the constraint model was visible in one place instead of scattered across 9 documents.

## Action Items

- [ ] **[skill]** implementation: Add guidance that when a compiler bug is identified and the compiler source is available, investigating a compiler fix should be attempted early rather than as a last resort. The source-level fix was 21 lines; the workaround exploration was 2 days.
- [ ] **[research]** What is the full set of 6.4-dev compatibility changes needed for swift-primitives? The `@_lifetime` on Escapable rejection, static property resolution in protocol extensions, and closure IRGen crash need systematic cataloguing, not one-at-a-time fixing.
- [ ] **[package]** swift-buffer-primitives: Once the compiler fix lands upstream, implement the ideal architecture: add deinit to Storage.Inline (combined @_rawLayout layout), remove all 22 `_deinitWorkaround` sites, remove buffer-layer deinits. The rawlayout-access-level-trigger experiment is the canary.
