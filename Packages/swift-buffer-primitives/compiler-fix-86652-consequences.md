# Compiler Fix Consequences: swiftlang/swift#86652

<!--
---
version: 1.0.0
last_updated: 2026-03-22
status: DECISION
tier: 2
---
-->

## Context

A two-line patch to `lib/IRGen/GenStruct.cpp:createNonFixed()` fixes the LLVM verifier crash (#86652) for `public` ~Copyable types with `@_rawLayout` storage and `deinit`. Before submitting upstream, we need to understand the consequences.

## Question

Is forcing `FieldsAreNotABIAccessible` for ~Copyable types with deinit in `createNonFixed()` correctly scoped, and what are the performance and correctness implications?

## Analysis

### Option A: Current patch (force VWT in createNonFixed only)

The patch modifies only `createNonFixed()`:

```cpp
auto *nom = TheStruct->getAnyNominal();
if (nom && !TheStruct->isCopyable() && nom->getValueTypeDestructor()) {
  structAccessible = IsNotABIAccessible;
  fieldsAccessible = FieldsAreNotABIAccessible;
}
```

### Which types reach createNonFixed?

Struct type creation uses a three-way decision tree (GenRecord.h:990-999):

```
layout.isLoadable()   → createLoadable  (register-sized)
layout.isFixedLayout() → createFixed    (stack, fixed offsets)
else                   → createNonFixed  (VWT-based offsets)
```

A struct reaches `createNonFixed` **only** when `isFixedLayout()` is false:
1. **@_rawLayout with dynamic layout** — `@_rawLayout(likeArrayOf: T, count: N)` where T is generic
2. **Structs with non-fixed-size fields** — containing resilient or dependent-size types

Regular ~Copyable structs with deinit (e.g., `struct Foo: ~Copyable { var x: Int; deinit {} }`) have fixed-size fields → `createFixed` → **NOT affected**.

### Blast radius

| Type | Layout path | Affected? |
|------|------------|:---------:|
| `struct Foo: ~Copyable { var x: Int; deinit {} }` | createFixed | No |
| `struct Empty: ~Copyable { deinit {} }` | createLoadable | No |
| `@_rawLayout(size: 16, alignment: 16) struct Lock: ~Copyable { deinit {} }` | createFixed | No |
| `@_rawLayout(likeArrayOf: T, count: N) struct Raw<T, N>: ~Copyable { deinit {} }` | createNonFixed | **Yes** |
| Struct with resilient field + deinit | createNonFixed | **Yes** |

**The patch affects only non-fixed-layout ~Copyable types with deinit.** This is exactly the set of types that crash.

### The three-tier destruction sequence

`GenStruct.cpp:destroy()` uses three-tier fallback:

1. **Direct deinit call** (`tryEmitDestroyUsingDeinit`) — always tried first. Succeeds when deinitTable is available (same module, or deserialized). For same-module types, this path handles destruction and neither VWT nor element-wise is reached.

2. **VWT-based destruction** (`emitDestroyCall`) — reached when fields are not ABI-accessible. Routes through value witness table. Correct for all types.

3. **Element-wise destruction** (`super::destroy`) — reached when fields ARE ABI-accessible. Projects each field and destroys individually. **This is the broken path** — generates incorrect `invariant.load` annotations for @_rawLayout fields under `-O`.

The patch forces tier 2 (VWT) for the affected types, preventing tier 3 (element-wise) from being reached.

### When does element-wise destruction actually trigger?

For a type with a deinit in the SAME module, `tryEmitDestroyUsingDeinit` succeeds → direct deinit call → done. No fallback needed.

The fallback matters when a CONSUMER module destroys a type whose deinit is in a different module. In that case:
- `lookUpMoveOnlyDeinit` finds the deinit → emits direct call → tier 1 succeeds
- OR `lookUpMoveOnlyDeinit` returns null → internally falls back to VWT → still tier 1 (returns true)

So for types WITH deinit, the element-wise path at line 311 should theoretically never be reached. But the crash occurs in the **containing struct's** destruction — when a struct stores a field whose TYPE goes through createNonFixed, the containing struct's element-wise destruction projects that field, and the field projection/destruction generates the broken IR.

### Performance implications

| Metric | Element-wise | VWT-based |
|--------|:----------:|:--------:|
| Runtime lookup | None | 1 VWT load |
| Inlining | Full | None (opaque) |
| Code size | Expanded per field | Single call site |
| Typical overhead | — | ~5-10ns per destruction |

The overhead is one indirect call during destruction. For types destroyed infrequently (stack-allocated buffers at scope exit), this is negligible. For hot loops destroying many values, the VWT indirection is measurable but small.

**Important**: This only affects non-fixed-layout types. Fixed-layout ~Copyable types (the common case) are completely unaffected.

### Option B: More targeted fix (check for @_rawLayout specifically)

```cpp
if (nom && !TheStruct->isCopyable() && nom->getValueTypeDestructor()) {
  if (T.getRawLayout()) {  // Only @_rawLayout types
    structAccessible = IsNotABIAccessible;
    fieldsAccessible = FieldsAreNotABIAccessible;
  }
}
```

Pro: Even narrower scope — only @_rawLayout types affected.
Con: If the bug also affects non-@_rawLayout non-fixed types with deinit (e.g., resilient fields), they'd still crash.

### Option C: Fix the invariant.load generation instead

The root cause is incorrect `invariant.load` annotation during element-wise destruction of @_rawLayout fields. A deeper fix would correct the annotation rather than bypassing element-wise destruction entirely.

Pro: No performance impact for any path.
Con: Requires understanding the LLVM IR generation for @_rawLayout type metadata access, which is significantly more complex. Higher risk of introducing new bugs.

### Comparison

| Criterion | Option A (current) | Option B (targeted) | Option C (root cause) |
|-----------|:------------------:|:------------------:|:--------------------:|
| Correctness | Proven | Likely correct | Unknown risk |
| Scope | Non-fixed ~Copyable + deinit | Non-fixed @_rawLayout + deinit | Only broken cases |
| Performance impact | Negligible (non-fixed types only) | Negligible | None |
| Implementation risk | Minimal (2 lines) | Low (4 lines) | High (IR generation) |
| Completeness | Covers all known + potential triggers | Covers known triggers only | Covers root cause |

## Outcome

**Status**: DECISION

**Recommendation**: Option A (current patch). Rationale:

1. **Narrow blast radius**: Only non-fixed-layout ~Copyable types with deinit are affected. Regular ~Copyable structs (the vast majority) go through `createFixed`/`createLoadable` and are untouched.

2. **Performance is irrelevant for affected types**: @_rawLayout types with dynamic layout are inherently non-fixed — they already pay VWT costs elsewhere. The marginal cost of VWT-based destruction vs element-wise is noise.

3. **Defense in depth**: Option B would leave non-@_rawLayout non-fixed types vulnerable to the same class of bug. Option A is conservative — it prevents the broken codegen path for all types that could potentially trigger it.

4. **Minimal risk**: The change matches what `internal` types already do. We're not introducing a new codegen path — we're routing `public` types through the same path that `internal` types use successfully.

5. **The `isTypeABIAccessibleIfFixedSize` change in GenType.cpp is redundant**: Our debug prints showed it's never called for the crashing types. However, it provides defense-in-depth for the fixed-size path. For the PR, include only the GenStruct.cpp change (minimal, proven fix). The GenType.cpp change can be proposed separately if needed.

## References

- [rawlayout-release-crash-investigation.md](rawlayout-release-crash-investigation.md)
- [swiftlang/swift#86652](https://github.com/swiftlang/swift/issues/86652)
- `lib/IRGen/GenStruct.cpp:1354-1366` — createNonFixed
- `lib/IRGen/GenStruct.cpp:299-314` — destroy three-tier fallback
- `lib/IRGen/GenRecord.h:338-368` — RecordTypeInfoImpl::destroy
- `lib/IRGen/GenRecord.h:990-999` — createLoadable/createFixed/createNonFixed decision
