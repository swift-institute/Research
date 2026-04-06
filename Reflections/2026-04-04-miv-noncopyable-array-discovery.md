---
date: 2026-04-04
session_objective: Fix MemberImportVisibility errors in pool-primitives and cascade to swift-io building
packages:
  - swift-pool-primitives
  - swift-cache-primitives
  - swift-darwin-primitives
  - swift-kernel-primitives
  - swift-posix
  - swift-io
status: pending
---

# MIV Remediation: ~Copyable Array Discovery and Cross-Layer Cascade

## What Happened

Resumed from a handoff targeting pool-primitives MIV errors (~38 reported). The handoff prescribed `Swift.Array<T>` disambiguation for Array shadowing. Investigation revealed this was wrong: `Async.Waiter.Resumption` is `~Copyable`, making `Swift.Array` impossible. The actual fix was adding `Array_Dynamic_Primitives` (provides `.append()` and `.drain()` on the custom `Array_Primitives_Core.Array` type) plus `Array_Fixed_Primitives` for subscript access on `Array.Fixed` storage.

After pool-primitives built, swift-io exposed two more cascading packages: cache-primitives (same Async.Waiter + Array pattern) and swift-posix (missing Kernel variant imports in POSIX write/flush wrappers). Also fixed a `public`/`package` visibility mismatch in swift-io's `IO.Event.Selector.register()`. All 6 sub-repos committed. swift-io builds clean.

## What Worked and What Didn't

**Worked**: Reading source files and tracing type definitions before applying fixes. Discovering `Async.Waiter.Resumption: ~Copyable` before blindly applying `Swift.Array` disambiguation prevented a dead end that would have required backtracking.

**Worked**: Fixing packages bottom-up (pool first, then building swift-io to discover cascading issues in cache and posix). Each build cycle surfaced the next layer of problems.

**Didn't work**: The previous session's handoff diagnosis was wrong about the Array fix. It prescribed `Swift.Array` disambiguation without checking whether the element type was Copyable. This would have been a dead end if followed blindly.

## Patterns and Root Causes

**MIV cascades are not contained to one package.** Fixing pool-primitives exposed cache-primitives and swift-posix — packages that were previously invisible because they compiled before pool's errors halted the build. Any MIV remediation session should expect cascading discoveries and build the full downstream chain, not just the target package.

**Handoff diagnoses can be wrong about mechanism while being right about symptoms.** The handoff correctly identified Array shadowing as the problem and `.append()`/`.drain()` as the missing operations. But the prescribed fix (Swift.Array disambiguation) was wrong because it didn't account for ~Copyable element constraints. The lesson: handoff "fix suggestions" should be treated as hypotheses, not instructions. Verify the type constraints before applying.

**The custom Array ecosystem has a three-module split** that is non-obvious: `Array_Primitives_Core` (type definition + `.Fixed`), `Array_Dynamic_Primitives` (`.append()`, `.drain()`, `.remove()`), `Array_Fixed_Primitives` (subscripts, iterators on `.Fixed`). Any consumer using the custom Array operationally needs at least two of these three.

## Action Items

- [ ] **[skill]** implementation: Add guidance that handoff fix suggestions are hypotheses — verify type constraints (especially ~Copyable) before applying prescribed fixes
- [ ] **[doc]** Documentation.docc/Primitives Layering.md: Document the Array three-module split (Core/Dynamic/Fixed) and when each is needed
- [ ] **[package]** swift-array-primitives: Consider whether Array_Primitives_Core should re-export Array_Dynamic_Primitives, since any operational use of the custom Array requires both
