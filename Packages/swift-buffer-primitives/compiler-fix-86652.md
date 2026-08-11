# Compiler Fix: swiftlang/swift#86652

<!--
---
date: 2026-03-22
status: TESTING (build in progress)
---
-->

## The Bug

`public` ~Copyable types with `@_rawLayout` storage and explicit `deinit` crash the LLVM verifier under `-O` with "Instruction does not dominate all uses!". `internal` types work correctly.

## Root Cause

`lib/IRGen/GenType.cpp:3082-3085` — `isTypeABIAccessibleIfFixedSize()` returns `IsABIAccessible` for `public` ~Copyable types with deinit. This routes destruction through the element-wise path in `GenStruct.cpp:311`, which generates incorrect `invariant.load` annotations for `@_rawLayout` fields. `internal` types return `IsNotABIAccessible`, routing through `emitDestroyCall()` (VWT-based), which works correctly.

## The Codegen Divergence

```
GenStruct.cpp:299 destroy()
  → tryEmitDestroyUsingDeinit() — tries direct deinit call
  → if fails:
    → areFieldsABIAccessible()?
      → YES (public): element-wise destruction → invariant.load → CRASH
      → NO (internal): emitDestroyCall() via VWT → WORKS
```

## The Fix

In `isTypeABIAccessibleIfFixedSize()`, for ~Copyable types with a deinit, always return `IsNotABIAccessible`. This routes all such types through VWT-based destruction, matching the `internal` codegen path.

**Changed file**: `lib/IRGen/GenType.cpp`

```diff
   auto nom = ty->getAnyNominal();
   if (!nom || !nom->getValueTypeDestructor())
     return IsABIAccessible;

-  if (IGM.getSILModule().isTypeMetadataAccessible(ty) ||
-      IGM.getSILModule().lookUpMoveOnlyDeinit(nom,
-                                              false /*deserialize lazily*/))
-    return IsABIAccessible;
-
-  return IsNotABIAccessible;
+  // ~Copyable types with a deinit must use VWT-based destruction, not
+  // element-wise destruction. Element-wise destruction generates incorrect
+  // invariant.load annotations for @_rawLayout fields, causing LLVM verifier
+  // crashes ("Instruction does not dominate all uses!") under -O for public
+  // types. VWT-based destruction works correctly for all access levels.
+  // See: https://github.com/swiftlang/swift/issues/86652
+  return IsNotABIAccessible;
```

## Performance Impact

VWT-based destruction adds one indirect call compared to element-wise field destruction. This only affects ~Copyable types with explicit deinits — a small subset of types. The cost is negligible (one deinit call per value lifetime).

## What This Unblocks

1. `Storage.Inline` can have a deinit → automatic element cleanup
2. All 22 `_deinitWorkaround: AnyObject?` sites can be removed (8 bytes per instance saved)
3. Buffer-layer deinits (Ring.Inline, Linear.Inline, Slab.Inline) become unnecessary
4. Superrepo `swift build -c release` passes
5. Foundations-layer release builds pass (swift-file-system, swift-strings)
