# @_rawLayout Release Crash Investigation

<!--
---
version: 4.0.0
date: 2026-03-22
status: RESOLVED (Bug 1: field-ordering; Bug 2: removed ~Escapable from Property.View — root cause fix, zero @_optimize(none))
consolidates:
  - release-crash-fix-handoff.md
  - release-crash-resolution-handoff.md
  - release-build-fresh-eyes-handoff.md
  - release-build-resolution-handoff-v2.md
  - per-variant-core-split-instructions.md
  - rawlayout-experiment-consolidation-handoff.md
  - storage-inline-deinit-handoff.md
  - storage-inline-deinit-investigation-results.md
  - github-issue-86652-comment-draft.md
---
-->

## Summary

Two compiler bugs block `swift build -c release` for types combining `~Copyable` structs, `@_rawLayout` stored fields, and explicit `deinit`.

**Bug 1 (LLVM verifier) — RESOLVED via field ordering.** The compiler generates composite value witnesses that load `stride` inside an element-iteration loop but use `stride * capacity` outside the loop to reach fields that follow the variable-size `@_rawLayout` storage. When the loop is skipped (capacity ≤ 0), `stride` is undefined, violating LLVM SSA dominance. **Fix**: place `@_rawLayout` storage as the last stored property at every nesting level, so no fields require stride-based offset computation post-loop.

**Bug 2 (SIL ownership) — RESOLVED by removing `~Escapable` from Property.View.** Root cause: `~Escapable` + `@_lifetime(borrow base)` on Property.View generates `mark_dependence` instructions in SIL classified as `PointerEscape` (see `OSSACanonicalizeOwned.cpp:40-46`). CopyPropagation's canonicalizer mishandles these across control flow joins, producing double `end_lifetime`. Fix: removed `~Escapable` from 7 Property.View types — the `_read`/`_modify` coroutine scope already provides lifetime confinement. All 149 `@_optimize(none)` annotations removed. Previously suppressed with `@_optimize(none)` on 149 functions across 12 sub-repos.

**Authoritative diagnosis**: [release-mode-llvm-verifier-crash-diagnosis.md](release-mode-llvm-verifier-crash-diagnosis.md) (v3.0.0, Steps 1-8)
**Ranked workaround options**: [release-build-options-v2.md](release-build-options-v2.md)
**Experiment corpus**: [rawlayout-llvm-verifier-crash/](../Experiments/rawlayout-llvm-verifier-crash/), [rawlayout-sil-ownership-crash/](../Experiments/rawlayout-sil-ownership-crash/), [rawlayout-deinit-alternatives/](../Experiments/rawlayout-deinit-alternatives/), [rawlayout-minimal-reproducer/](../Experiments/rawlayout-minimal-reproducer/)

## Timeline

| Date | Event | Outcome |
|------|-------|---------|
| 2026-02-15 | LLVM verifier crash discovered in buffer-primitives release build | File-split hypothesis proposed → invalidated by clean builds (Step 6) |
| 2026-02-15 | Per-variant Core module split attempted | Invalidated by [MOD-004] constraint poisoning (Step 7) and cross-module boundary (Step 8) |
| 2026-03-20 | Constraint triangle documented | All modularization approaches proven impossible. "Candidate B" (reduce to ≤2 deinits) identified as viable. |
| 2026-03-20 | Workaround branch created (`workaround/struct-body-inline-types`) | Ring.Inline + Linear.Inline deinits removed. Slab.Inline + Arena.Inline retained. 391 tests pass. |
| 2026-03-21 | 14 scattered experiments consolidated into 4 | [rawlayout-experiment-consolidation-handoff.md] — corpus organized for systematic investigation |
| 2026-03-21 | Minimal reproducer found for Bug 1 | 3-module chain, 2+ cross-module @_rawLayout fields. Consumer module crashes, defining module fine. |
| 2026-03-21 | Storage.Inline deinit investigated → **provably impossible** | 2-field rule discovered. 9 approaches tested, all fail. |
| 2026-03-21 | Tested on Swift 6.4-dev (main snapshot 2026-03-16) | **Still broken.** |
| 2026-03-22 | **Field-ordering root cause discovered** | `@_rawLayout` storage must be the last stored property. Composite value witnesses compute `stride * capacity` post-loop only when fixed-size fields follow the variable-size storage. Reordering eliminates the crash entirely. |
| 2026-03-22 | Field reorder applied across 11 sub-repos | Storage.Inline, Storage.Pool.Inline, Storage.Arena.Inline, Buffer.Linked.Inline reordered. `_deinitWorkaround` moved before `_buffer` in 19 data structure types. Debug build passes (3779 modules). |

## The Two Bugs

**Bug 1 — LLVM Verifier Crash** ("Instruction does not dominate all uses!"):
- Trigger: `~Copyable` struct with `@_rawLayout` stored field(s) + explicit `deinit` + `-O`
- Root cause: `invariant.load` annotation on `let` stored property accesses mis-positioned relative to `@_rawLayout` destruction sequences in LLVM IR
- Tracked: swiftlang/swift#86652

**Bug 2 — SIL Ownership Crash** ("Found ownership error?!") — **RESOLVED 2026-03-22**:
- Root cause: `~Escapable` + `@_lifetime(borrow base)` on Property.View generates `mark_dependence` instructions classified as `PointerEscape` by `OperandOwnership.cpp:699-720`. CopyPropagation's `OSSACanonicalizeOwned` (line 216-219) bails out on PointerEscape, and in deep `@inlinable` chains this partial bailout produces double `end_lifetime` for `~Copyable ~Escapable` values across control flow joins.
- Compiler team TODO: `OSSACanonicalizeOwned.cpp:40-46` acknowledges the `mark_dependence`/PointerEscape limitation
- Fix: Removed `~Escapable` from 7 Property.View types in property-primitives. The `_read`/`_modify` coroutine scope already confines the yielded view's lifetime. This eliminated all `mark_dependence` instructions, preventing the CopyPropagation bug from triggering.
- All 149 `@_optimize(none)` annotations removed across 12 sub-repos. 4 extracted static methods in async-primitives inlined back into closures.
- Standalone reproducer: `Experiments/copypropagation-nonescapable-mark-dependence/` (3-module package, crashes reliably in release mode)
- Previous workaround (superseded): `@_optimize(none)` on 149 functions across 12 sub-repos

## The 2-Field Rule (Refined Trigger)

Discovered 2026-03-21 during Storage.Inline deinit investigation:

| Condition | Crash? |
|-----------|:------:|
| 1 @_rawLayout field + explicit deinit (even empty) + 0 deps | No |
| 1 @_rawLayout field + non-empty deinit + 0 deps | No |
| 2+ fields (1 @_rawLayout + others) + `deinit {}` (empty) + 0 deps | **YES** |
| 2+ fields (1 @_rawLayout + 1 Int) + `deinit { _ = capacity }` + 0 deps | **YES** |
| 1 field wrapping _Fields(2 fields) + `deinit {}` + 0 deps | **YES** (transitive) |
| 1 field (Storage.Inline from pre-compiled module) + `deinit {}` + 1 dep | **YES** |

The crash requires the **combination** of: (1) a `@_rawLayout` stored field at any depth in the destruction chain, (2) at least one OTHER stored field at the same nesting level, (3) an explicit `deinit` anywhere in the chain, (4) `-O` optimization.

## Why Storage.Inline Cannot Have a Deinit

Storage.Inline has 2 stored properties: `_storage: _Raw` (@_rawLayout) + `_slots: Bit.Vector.Static<4>`. This violates the 2-field rule.

**9 approaches tested, all fail:**
1. Direct deinit (enum-body pattern) → CRASH
2. `@_optimize(none)` on deinit → CRASH
3. Empty deinit body → CRASH (with 2 fields)
4. Separate module within storage-primitives → CRASH
5. Pre-compiled @_rawLayout cross-module → CRASH
6. `_Fields` wrapper (single stored property) → CRASH (transitive)
7. Top-level standalone type → CRASH
8. Shared deinit wrapper in Buffer Primitives Core → CRASH (multiplies transitive chain)
9. Wrapper in variant struct body → CRASH (same issue)

## Combined @_rawLayout Approach (Explored and Blocked 2026-03-21)

The 2-field rule only triggers when there are 2+ STORED FIELDS. Encoding the bitmap within the single `@_rawLayout` field reduces Storage.Inline to 1 stored field.

**Approach**: Use `@_rawLayout(like: _CombinedLayout)` where `_CombinedLayout` contains both element storage and bitmap in one raw region.

**Works with `internal` access, crashes with `public`**:

| Access Level | Deps | Result |
|--------------|------|--------|
| `internal` (default) | 0 | **Builds** |
| `internal` (default) | 4 (Index, Memory, BitVec, Finite) | **Builds** |
| `public` | 0 | **CRASH** |
| `public` | 4 | **CRASH** |

The crash is access-level-dependent. `internal` types work because the optimizer doesn't generate cross-module type metadata. `public` types crash because the optimizer generates the problematic `invariant.load` pattern for cross-module visibility.

**Since Storage.Inline must be `public`, the combined layout approach is blocked.** The combined layout is architecturally correct — it just can't be expressed with `public` types under the current compiler bug.

**Standalone reproducer** (works): `/tmp/rawlayout-test/` — `internal` types + combined layout + deinit builds and runs correctly in release.

**This is the strongest candidate for a compiler fix**: the combined layout produces correct IR for `internal` types. The `public` trigger path is a distinct codegen issue that could potentially be fixed independently.

## Ideal Architecture

```
┌─────────────────────────┬──────────────────────────────────────────┐
│ Layer                   │ Cleanup responsibility                   │
├─────────────────────────┼──────────────────────────────────────────┤
│ Storage.Inline          │ Iterate _slots.ones, deinitialize        │
│ Buffer.*.Inline         │ None — delegate to Storage.Inline        │
│ Buffer.Arena.Inline     │ Own deinit — uses _Elements, not Inline  │
└─────────────────────────┴──────────────────────────────────────────┘
```

All buffer types use tracked methods (`storage.initialize`, `storage.move`, `storage.deinitialize`) which keep `_slots` in sync. Exception: Slab.Inline's deinit uses direct pointer deinitialize (would be removed in ideal architecture).

**Proposed deinit body** (for when the compiler bug is fixed):
```swift
deinit {
    for bitIndex in _slots.ones {
        let slot = bitIndex.retag(Element.self)
        unsafe withUnsafePointer(to: _storage) { base in
            let elementBase = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(base))
                .assumingMemoryBound(to: Element.self)
            unsafe (elementBase + Index<Element>.Offset(fromZero: slot))
                .deinitialize(count: 1)
        }
    }
}
```

## Field-Ordering Fix (2026-03-22)

### Root Cause

The "2-field rule" is actually a **field-ordering rule**: the crash occurs when fixed-size fields follow a variable-size `@_rawLayout` field in memory layout. The compiler generates composite value witnesses (`wxx` destroy, `wta` assignWithTake, `wet`/`wst` enum tag) that:

1. Iterate through `@_rawLayout` elements in a loop, loading `stride` from type metadata inside the loop body
2. After the loop, compute `stride * capacity` to find fields at higher offsets
3. When the loop is skipped (capacity ≤ 0), `stride` was never loaded → LLVM SSA dominance violation

### Fix

Place `@_rawLayout` storage as the **last stored property** at every nesting level:

| Type | Before (crashes) | After (works) |
|------|-------------------|---------------|
| `Storage.Inline` | `_storage`, `_slots` | `_slots`, **`_storage`** |
| `Storage.Pool.Inline` | `_storage`, `_slots`, `_allocated` | `_slots`, `_allocated`, **`_storage`** |
| `Storage.Arena.Inline` | `_storage`, `_slots`, `_allocated` | `_slots`, `_allocated`, **`_storage`** |
| `Buffer.Linked.Inline` | `header`, `storage`, `freeHead`, `nextUnused` | `header`, `freeHead`, `nextUnused`, **`storage`** |

For data structure types with `_deinitWorkaround: AnyObject?` + `_buffer`:

| Pattern | Before (crashes) | After (works) |
|---------|-------------------|---------------|
| All Inline/Static/Small types | `_buffer`, `_deinitWorkaround` | `_deinitWorkaround`, **`_buffer`** |
| Heap.Static/Small | `_buffer`, `order`, `_deinitWorkaround` | `_deinitWorkaround`, `order`, **`_buffer`** |
| Tree.N.Inline/Small | `_arena`, `_rootIndex`, `_deinitWorkaround` | `_deinitWorkaround`, `_rootIndex`, **`_arena`** |

### Why This Works

The fix prevents the broken codegen path from being triggered. When `@_rawLayout` storage is last, the composite value witnesses:
1. Handle all fixed-size fields at known offsets (no stride computation needed)
2. Enter the element loop with stride computation
3. After the loop, return — no post-loop stride usage required

### Verification (LLVM IR)

Before fix — `List.Linked.Inline` destroy witness (`wxx`):
```
entry:
  %capacity = load ...
  br i1 %capacity > 0, %loop, %exit    ; skip loop if empty

loop:
  %stride = load ... !invariant.load    ; stride only defined here
  call void %Destroy(ptr ...)
  br i1 %done, %exit, %loop

exit:                                   ; reached from entry OR loop
  %offset = mul i64 %stride, %capacity  ; ← BUG: %stride undefined from entry path
  ; ... access _deinitWorkaround at %offset
```

After fix — stride is never used post-loop because there are no fields after storage.

### Status

- **Bug 1 (LLVM verifier)**: RESOLVED for types with field reorder applied
- **`_deinitWorkaround` retained**: Still needed to prevent deinit elision (#86652 triviality misclassification)
- **Bug 2 (SIL ownership)**: RESOLVED — root cause fixed by removing `~Escapable` from Property.View (2026-03-22). All 149 `@_optimize(none)` annotations removed. Standalone reproducer: `Experiments/copypropagation-nonescapable-mark-dependence/`. `swift build -c release` passes clean with zero workarounds.

## Previous Workaround (Superseded)

Branch: `workaround/struct-body-inline-types` (superseded by field-ordering fix)

1. Inline types moved from extension files into parent struct bodies (avoids extension-file trigger)
2. Ring.Inline and Linear.Inline deinits **removed** (elements leak for class-typed and ~Copyable)
3. Slab.Inline and Arena.Inline deinits **retained** (≤2 threshold satisfied)
4. `@_optimize(none)` on 4 functions for Bug 2
5. 391 tests pass, `swift build -c release` succeeds

**Known regression**: Ring.Inline and Linear.Inline silently leak elements when dropped without draining. Affects class-typed and ~Copyable elements only.

## Why the Previous Workaround Worked

1. Only 2 types have deinits with @_rawLayout in their destruction chain: Slab.Inline + Arena.Inline
2. Both in **variant struct bodies** (struct-body pattern)
3. Neither stores another type-with-deinit (they store Storage.Inline which has NO deinit)
4. Buffer.Aligned has a deinit but no @_rawLayout — doesn't count
5. Ring.Inline and Linear.Inline have no deinit — they leak, but the build succeeds

## Constraint Triangle

Three mutually exclusive constraints block all modularization approaches:

1. **Struct-body threshold**: ≤2 @_rawLayout+deinit types in struct-body pattern per module
2. **Extension-file pattern**: Even 1 type crashes when defined via extension
3. **Cross-module boundary**: Even 1 type crashes when extending a parent from a different module

Combined with [MOD-004] constraint poisoning (Copyable-requiring conformances in the same module as ~Copyable type definitions break stored properties), type definitions CANNOT move to variant modules.

## GitHub Issue #86652 — Consumer-Module Reproducer

### Minimal Reproduction (3 modules, zero external dependencies)

**Package.swift:**
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-consumer-crash",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Core", swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .target(name: "Middleware", dependencies: ["Core"],
                swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .executableTarget(name: "Consumer", dependencies: ["Core", "Middleware"],
                          swiftSettings: [.enableExperimentalFeature("RawLayout")]),
    ],
    swiftLanguageModes: [.v6]
)
```

**Sources/Core/Types.swift:**
```swift
public enum Container<Element: ~Copyable> {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    public struct Inline<let capacity: Int>: ~Copyable {
        public init() {}
        deinit {}
    }
}
```

**Sources/Middleware/Wrappers.swift** (crash site):
```swift
public import Core

public struct Buffer<Element: ~Copyable>: ~Copyable {
    var _a: Container<Element>.Inline<8>
    var _b: Container<Element>.Inline<4>   // ← Remove this field → crash disappears

    public init() {
        self._a = .init()
        self._b = .init()
    }
}
```

**Sources/Consumer/main.swift:**
```swift
import Middleware
do { let _ = Buffer<Int>() }
print("OK")
```

```bash
rm -rf .build && swift build -c release
# signal 6: "Instruction does not dominate all uses!"
```

### Consumer-module threshold

| Fields in Middleware struct | Debug | Release |
|---------------------------|-------|---------|
| 1 field (`_a` only) | Builds | Builds |
| 2 fields (`_a` + `_b`) | Builds | **Crash** |

No `@inlinable` or `@usableFromInline` required on either side. The crash is in the consumer module's implicit destructor.

## Monitoring

When new Swift toolchains are released:

```bash
# Test consumer-module trigger:
cd Experiments/rawlayout-minimal-reproducer/
rm -rf .build && swift build -c release --target Bug1Consumer
# If this builds → the consumer-module trigger is fixed

# Test Storage.Inline deinit (add deinit {} to Storage.Inline):
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives
rm -rf .build && swift build -c release
# If this builds → the 2-field trigger is fixed
```

## Cross-References

- [release-mode-llvm-verifier-crash-diagnosis.md](release-mode-llvm-verifier-crash-diagnosis.md) — Authoritative diagnosis (v3.0.0)
- [release-build-options-v2.md](release-build-options-v2.md) — Ranked workaround options
- [small-buffer-enum-compiler-workarounds.md](small-buffer-enum-compiler-workarounds.md) — Related DECISION: Small enum compiler bugs
- [rawlayout-llvm-verifier-crash/](../Experiments/rawlayout-llvm-verifier-crash/) — Bug 1 experiment corpus (8 variants)
- [rawlayout-sil-ownership-crash/](../Experiments/rawlayout-sil-ownership-crash/) — Bug 2 experiment corpus (3 variants) — SUPERSEDED by root cause fix
- [rawlayout-deinit-alternatives/](../Experiments/rawlayout-deinit-alternatives/) — Workaround alternatives (4 variants)
- [rawlayout-minimal-reproducer/](../Experiments/rawlayout-minimal-reproducer/) — Bug 1 standalone reproducer
- [copypropagation-nonescapable-mark-dependence/](../Experiments/copypropagation-nonescapable-mark-dependence/) — **Bug 2 standalone reproducer** (3 modules, reliably crashes in release mode)
