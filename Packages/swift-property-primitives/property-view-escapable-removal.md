# Property.View ~Escapable Removal

<!--
---
version: 1.0.0
last_updated: 2026-03-22
status: DECISION
---
-->

## Context

Property.View (and all 6 variants: View.Typed, View.Read, View.Read.Typed, View.Typed.Valued, View.Typed.Valued.Valued, View.Read.Typed.Valued) were originally declared as `~Copyable, ~Escapable` with `@_lifetime(borrow base)` on their initializers and `@_lifetime(&self)` on mutating extension methods.

The `~Escapable` annotation provided compile-time enforcement that the view does not outlive its base pointer. This was defense-in-depth: the `_read`/`_modify` coroutine scope (`begin_apply`/`end_apply`) already confines the yielded view's lifetime at the SIL level.

In release builds (`swift build -c release`), the `~Escapable` + `@_lifetime(borrow base)` combination triggered a SIL CopyPropagation false positive that required 149 `@_optimize(none)` annotations across 12 consumer sub-repos, with unbounded growth as new `@inlinable` functions were added.

## Question

Should Property.View retain `~Escapable`, or should it be removed to eliminate the CopyPropagation crash?

## Analysis

### The Compiler Bug Mechanism

`~Escapable` + `@_lifetime(borrow base)` on an initializer causes the Swift SIL lowering to emit `mark_dependence` instructions that track the lifetime dependency between the view and its base. These `mark_dependence` instructions are classified as `OperandOwnership::PointerEscape` by the operand ownership classifier (`OperandOwnership.cpp:699-720`), unless they carry the `[nonescaping]` flag.

The `OSSACanonicalizeOwned` utility in CopyPropagation bails out entirely when it encounters a `PointerEscape` use (`OSSACanonicalizeOwned.cpp:216-219`). In deep `@inlinable` chains (5+ layers of cross-module inlining), this partial bailout leaves the SIL in an inconsistent state, producing double `end_lifetime` for `~Copyable ~Escapable` values across control flow joins (if/else, try/catch).

The compiler team acknowledges this limitation in a TODO comment at `OSSACanonicalizeOwned.cpp:40-46`:

> "Canonicalization currently bails out if any uses of the def has OperandOwnership::PointerEscape. Once project_box is protected by a borrow scope and mark_dependence is associated with an end_dependence, those will no longer be represented as PointerEscapes, and canonicalization will naturally work everywhere as intended."

### Option A: Keep `~Escapable`, suppress with `@_optimize(none)` on consumers

**Description**: Retain `~Escapable` + `@_lifetime(borrow base)`. Every `@inlinable` function that uses a Property.View across control flow paths receives `@_optimize(none)`.

| Criterion | Assessment |
|-----------|------------|
| Compile-time safety | Full — compiler enforces view doesn't outlive base |
| Maintenance cost | **Unbounded** — every new @inlinable consumer is a potential crash site |
| Performance | Degraded — `@_optimize(none)` disables all optimization in annotated functions |
| Predictability | Low — new crashes appear unpredictably in release builds |
| Annotation count | 149 at time of removal, growing |

### Option B: Keep `~Escapable`, suppress with `@_optimize(none)` on `_read` accessors

**Description**: Retain `~Escapable`, but put `@_optimize(none)` on the `_read`/`_modify` accessors that yield Property.View, preventing inlining of the `mark_dependence` into consumer functions.

| Criterion | Assessment |
|-----------|------------|
| Compile-time safety | Full |
| Maintenance cost | Bounded — only new accessor definitions need annotation |
| Performance | Minor — accessor body (`yield unsafe View(&self)`) not inlined |
| Predictability | High — rule: every `_read` yielding Property.View gets `@_optimize(none)` |
| Annotation count | ~30-50 (one per accessor definition) |

### Option C: Remove `~Escapable` from Property.View

**Description**: Declare Property.View as `~Copyable` only. Remove `@_lifetime(borrow base)` from inits and `@_lifetime(&self)` from extension methods. No `mark_dependence` instructions generated in SIL.

| Criterion | Assessment |
|-----------|------------|
| Compile-time safety | Partial — `_read`/`_modify` coroutine scope still provides runtime confinement; `~Copyable` prevents copying. Only theoretical escape via direct `Property.View(&ptr)` construction (already `unsafe`). |
| Maintenance cost | **Zero** — no annotations needed anywhere |
| Performance | **Zero impact** — full optimization of all consumer functions |
| Predictability | **Perfect** — no new crashes possible from this mechanism |
| Annotation count | 0 |

### Comparison

| Criterion | A: @_optimize(none) consumers | B: @_optimize(none) accessors | C: Remove ~Escapable |
|-----------|-------------------------------|-------------------------------|---------------------|
| Safety loss | None | None | Minimal (theoretical) |
| Annotation burden | 149+ (growing) | ~30-50 (stable) | **0** |
| Performance cost | High (entire functions unoptimized) | Low (trivial accessor body) | **None** |
| Future maintenance | Unpredictable new crashes | Predictable rule | **No maintenance** |
| Reversibility | Easy | Easy | Easy (re-add ~Escapable when compiler is fixed) |

### Why the safety loss is acceptable

1. **Coroutine scope provides confinement.** All Property.View usage goes through `_read`/`_modify` accessors. The `begin_apply`/`end_apply` SIL instructions confine the yielded value to the caller's scope. The view physically cannot escape this boundary regardless of `~Escapable`.

2. **`~Copyable` prevents copies.** The view cannot be duplicated, so the only way to "escape" it would be to move it, which requires consuming it out of the accessor scope — something the coroutine machinery prevents.

3. **Construction is already `unsafe`.** `Property.View(&self)` takes an `UnsafeMutablePointer`. Any code constructing a view directly is already in `unsafe` territory with no compiler guarantees about the pointer's validity.

4. **No real-world escape path exists.** In the entire codebase (114 extension files, 12 consumer sub-repos), no code stores or returns a Property.View outside its accessor scope.

## Outcome

**Status**: DECISION — Option C (remove `~Escapable`). **SUPERSEDED** by restoration on 2026-03-25 (commit `43247e3`) after Swift 6.3 fixed [swiftlang/swift#88022](https://github.com/swiftlang/swift/issues/88022). See [Resolution](#resolution-2026-03-25) below.

Applied 2026-03-22. Changes:
- 7 struct declarations: removed `~Escapable`
- 8 initializers: removed `@_lifetime(borrow base)`
- ~61 extension method files: removed `@_lifetime(&self)`
- 149 consumer functions: removed `@_optimize(none)`
- 4 async static methods: inlined back into closures (were extracted as workaround for `@_optimize(none)` not propagating to closures)
- `swift build -c release` passes clean with zero workarounds

### Resolution (2026-03-25)

Swift 6.3 shipped the fix for `mark_dependence` canonicalisation in CopyPropagation ([swiftlang/swift#88022](https://github.com/swiftlang/swift/issues/88022)) — the Resumption Trigger condition 1 below was met. `~Escapable` + `@_lifetime(borrow base)` was restored across all seven Property.View* types in commit `43247e3`, and all 149 `@_optimize(none)` workaround sites were removed. The 4 async static methods that were inlined as a further workaround were returned to their original extracted form. `swift test -c release` on Swift 6.3.1 passes with zero workarounds.

The sections below (Resumption Trigger, Monitoring) are preserved as the historical audit trail describing the conditions under which this restoration was planned and verified.

### Resumption Trigger

Re-add `~Escapable` + `@_lifetime(borrow base)` to Property.View when **either**:
1. The Swift compiler fixes `mark_dependence` canonicalization in CopyPropagation (the TODO at `OSSACanonicalizeOwned.cpp:40-46` is resolved), **or**
2. `mark_dependence` for `~Escapable` coroutine-yielded types is correctly classified as `[nonescaping]` rather than `[escaping]`

### Monitoring

Test with the standalone reproducer:
```bash
cd swift-buffer-primitives/Experiments/copypropagation-nonescapable-mark-dependence
# Restore ~Escapable + @_lifetime in Sources/Core/View.swift (V1 baseline)
rm -rf .build && swift build -c release
# If this builds → compiler fix landed, ~Escapable can be restored
```

## References

- `swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md` — Authoritative Bug 1 + Bug 2 investigation (v4.0.0)
- `swift-buffer-primitives/Experiments/copypropagation-nonescapable-mark-dependence/` — Standalone reproducer with 4 variants
- `swift-institute/Research/Reflections/2026-03-22-copypropagation-nonescapable-root-cause-and-fix.md` — Session reflection with full analysis
- `swiftlang/swift/lib/SILOptimizer/Utils/OSSACanonicalizeOwned.cpp:40-46` — Compiler team TODO
- `swiftlang/swift/lib/SIL/IR/OperandOwnership.cpp:699-720` — mark_dependence classification
