# `ISO_9899.String` Extraction to L1 `swift-c-string-primitives` — REJECTED

**Status**: REJECTED
**Decision context**: string-primitives correction cycle (2026-04-18), disagreement Δ2, settled by user
**Disposition**: type stays at L2 `swift-iso-9899` (spec authority). Duplication with `String_Primitives.String` is acknowledged and addressed by D5 (centralize length scan at L1).

---

## The proposal (modularization perspective)

Extract `ISO_9899.String` and `ISO_9899.String.View` from `swift-iso-9899` (L2) into a new L1 package `swift-c-string-primitives`. Keep `<string.h>` function shims (`Length.strlen`, `Comparison.strcmp`, `Copy.strcpy`, etc.) at L2. Maintain a namespace-adoption typealias `ISO_9899.String = C_String_Primitives.String` for source compat.

Rationale offered:
- The type's storage shape (raw `UnsafeMutablePointer<UInt8>` + count + hand-rolled deinit) is L1-shaped — pure ownership/storage with no spec content
- Modularization rules `[MOD-DOMAIN]`, `[MOD-008]`: type and function shims have different dependency sets and serve different semantic domains
- Cleaning the L3 `swift-strings → swift-iso-9899` umbrella import would become trivial (replaced by L3 → new-L1, legal by default)

## Why rejected

**User position (binding)**: L2 ISO 9899 SHOULD own the C string type. The modularization argument under-weighted spec authority — the C standard *defines* the convention "char array terminated by `\0`" as the C string. The struct that materializes that convention belongs with the spec, not in a new L1 sibling.

**Additional observation**: `String_Primitives.String` already IS what `ISO_9899.String` would be on POSIX — both are owned, NUL-terminated, single-heap-block UInt8 buffers. The only divergence is Windows: `String_Primitives.String.Char = UInt16` there, but ISO 9899's `char` is always 8-bit on every platform we target. So the "duplication" the modularization perspective flagged is real, but the right fix is not extraction — it's either accepting the duplication with shared canonical algorithms (D5) or making `String_Primitives.String` generic over `Char` (a separate future cycle).

## Resolution applied in this cycle

D5 (Wave 1 PR 1b): the L2 Swift duplicate `ISO_9899.String.length(of:)` was deleted; the canonical scan is `String_Primitives.String.length(of:)` at L1. ISO 9899's internal callers route to `Length.strlen` (the C-shim) which is spec-faithful. This addresses the duplication-of-algorithms concern without moving the type.

The remaining structural duplication (two L1/L2 owned types with near-identical shape) is **accepted** as a function of two distinct authorities (OS-platform-string vocabulary at L1; ISO C spec at L2).

## Future option: generic `String_Primitives.String<Char>`

If at some later point the duplication becomes a maintenance burden, the cleaner fix is to generalize:

```swift
// Hypothetical future shape
public struct String<Char: UnsignedInteger & FixedWidthInteger>: ~Copyable { ... }

// L1 platform string (current behavior)
public typealias PlatformString = String<Char>  // Char = UInt8 POSIX / UInt16 Windows

// L2 ISO 9899 alias
extension ISO_9899 {
    public typealias String = String_Primitives.String<UInt8>
}
```

This would:
- Eliminate the structural duplication at the type level
- Preserve `ISO_9899.String` as the spec-anchored entry point (typealias)
- Touch every consumer of the platform-typealias `Char` (large refactor)

This is **not** scoped into the string-correction cycle. It would warrant its own ecosystem-correction cycle if pursued.

## Related

- Q2, Q7 in `string-type-ecosystem-model.md`
- D5 (resolved Wave 1 PR 1b) in synthesis output
- User direction: "L2 spec iso 9899 should own the c string type"
