---
date: 2026-03-22
session_objective: Fix SIL CopyPropagation ownership crash (Bug 2) to get swift build -c release passing across all swift-primitives sub-repos and the full superrepo
packages:
  - swift-stack-primitives
  - swift-queue-primitives
  - swift-array-primitives
  - swift-heap-primitives
  - swift-set-primitives
  - swift-dictionary-primitives
  - swift-parser-primitives
  - swift-async-primitives
  - swift-graph-primitives
  - swift-buffer-primitives
status: SUPERSEDED
superseded_by: 2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md
---

# SIL CopyPropagation Bug 2: Scope Was 10x Wider Than Expected

> **SUPERSEDED (2026-03-22)**: This reflection documented the `@_optimize(none)` workaround. The root cause was subsequently identified and fixed by removing `~Escapable` from Property.View — all 149 `@_optimize(none)` annotations have been removed. See [2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md](2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md).

## What Happened

Session goal: get `swift build -c release` passing for 9 data structure sub-repos by fixing "Bug 2" — a SIL CopyPropagation false positive that aborts release builds. The handoff identified 5 direct crashes in data structure `clear`/`removeAll` functions following a `remove.all()` + conditional buffer reassignment pattern.

Applied `@_optimize(none)` to the 5 identified functions. Sub-repo builds passed. Then built the **full superrepo** — and discovered the crash surface was dramatically wider:

- **Data structures** (Stack, Queue, Array, Heap, Set, Dictionary): ~38 functions. Not just `clear` — also `insert`, `remove`, `drain`, `set`, `_grow`, `removeMin/Max`. Dictionary alone needed 18 annotations across 5 variants (base, Ordered, Bounded, Static, Small).
- **Parsers**: 10 functions. Every `parse`/`print` function with `input.restore.to(...)` across try/catch branches (Peek, Optionally, Not, Many.Simple, Many.Separated, OneOf.Two/Three/Any).
- **Async primitives**: ~12 functions. Bridge.push, Channel.Bounded.State (trySend, tryReceive, sendSuspended, receiveSuspended, close), Channel.Unbounded.State, Broadcast.State/Broadcast. Closures required extracting bodies to static `@_optimize(none)` methods.
- **Graph primitives**: 2 functions (subgraph overloads).

Total: ~60 functions across 9 sub-repos + research update in buffer-primitives.

Investigated whether a central fix in property-primitives was possible. Tested adding `@_optimize(none)` to the `all()` leaf method on `Property.View.Typed` for Buffer.Linear.Remove. **Failed** — the crash is at the accessor coroutine level (the `_read`/`_modify` that yields the Property.View), not the leaf method level.

## What Worked and What Didn't

**Worked well:**
- The `@_optimize(none)` workaround is reliable and surgical. Every annotated function stops crashing, callers retain full optimization.
- Sub-repo builds gave fast iteration (~13-30 seconds each). Building individual sub-repos was an effective first pass.
- The static method extraction pattern for closures (`Self._pushLocked(&state, element)`) cleanly preserves the fluent API inside the implementation while giving the closure body its own SIL function that can receive `@_optimize(none)`.

**What didn't work:**
- **Scope estimation was way off.** The handoff said "5 direct crashes, 2 transitive." Reality: 60+ functions across 9 repos. The sub-repo builds passed because they have shallower inlining depth than the superrepo. The full superrepo's compilation graph enables deeper cross-module inlining that exposes many more crash sites.
- **Central fix failed.** Annotating Property.View leaf methods doesn't help because the crash is in the accessor coroutine that creates/destroys the View, not in what the View's methods do internally.
- **`@_optimize(none)` doesn't propagate to closures.** Each closure is a separate SIL function. This required restructuring async code to extract closure bodies into named static methods.

## Patterns and Root Causes

**The crash trigger is broader than documented.** The handoff described it as "`remove.all()` + conditional buffer reassignment." That's one instance of a general pattern: **any `@inlinable`/`@usableFromInline` function that creates a `Property.View` (via `_read`/`_modify` accessor coroutine) across multiple control flow paths triggers a CopyPropagation false positive.** Specific manifestations:

1. **Accessor + reassignment** (data structures): `_buffer.remove.all()` creates View in one path, `_buffer = ...` reassigns in another.
2. **Accessor in try/catch** (parsers): `input.restore.to(...)` creates View in both try and catch paths.
3. **Accessor in if/else** (heaps, sets, dictionaries): Multiple `_buffer.swap(...)`, `_buffer[idx]` subscript accesses create Views across branches.
4. **Accessor in closure** (async): `state.buffer.back.push(element)` inside `withLock` closure — closure is separate SIL function, `@_optimize(none)` on outer function doesn't help.

**The root cause is `~Escapable` + `@_lifetime(borrow)` across control flow joins.** `Property.View` is `~Copyable, ~Escapable` with `@_lifetime(borrow base)`. When CopyPropagation processes a function where the View appears in multiple branches (try/catch, if/else), it generates double `end_lifetime` for the same value — a false positive.

**Sub-repo vs superrepo divergence.** Sub-repo builds compile fewer modules, so the SIL optimizer has less material to inline. The superrepo build has the full dependency graph, enabling deeper cross-module inlining that triggers the bug in functions that are fine in isolation. This means testing sub-repos alone is insufficient for release-mode validation.

## Action Items

- [x] **[research]** ~~Should we file a focused Swift bug report~~ → **Resolved**: Root cause identified and fixed. Standalone reproducer created at `Experiments/copypropagation-nonescapable-mark-dependence/`. Bug report still worth filing with the reproducer.
- [x] **[skill]** ~~implementation: @_optimize(none) closure guidance~~ → **Resolved**: The `@_optimize(none)` workaround is no longer needed. The extracted static methods in async-primitives have been inlined back into closures.
- [ ] **[package]** swift-primitives: Add a superrepo-level release build to CI/validation. Sub-repo release builds are necessary but not sufficient — the full superrepo exposes crashes that sub-repos miss due to shallower inlining depth.
