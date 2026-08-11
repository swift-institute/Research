# Mutable Cross-Module Ambiguity: Experiment Results

<!--
---
status: COMPLETE
version: 2.0.0
date: 2026-01-28
author: Swift Institute
applies_to: [pointer-primitives, memory-primitives]
experiment: Experiments/mutable-cross-module-ambiguity/
---
-->

## Executive Summary

Two `Mutable` typealiases on different constrained extensions of `Tagged` cause cross-module
ambiguity errors in Swift 6.2. The compiler finds both `Mutable` members regardless of constraint
satisfaction, producing `ambiguous type name 'Mutable'` in every file that references
`Pointer<T>.Mutable` or `Memory.Address.Mutable`.

Eight variants (A-H) were tested. **Variant H is the confirmed solution**: move the mutable
address typealias from a `Tagged` extension to the `Memory.Mutable` enum, making it
`Memory.Address` instead of `Memory.Address.Mutable`. This ensures only ONE `Mutable`
exists on any `Tagged` extension (`Pointer<T>.Mutable`), eliminating the collision.

---

## 1. Problem Statement

### Root Cause

Swift's generic type member lookup finds ALL members with matching names across ALL constrained
extensions of a generic type, regardless of whether the constraints are satisfied at the use site.

Two `Mutable` definitions on `Tagged`:

```swift
// In memory-primitives (Memory.Address.Mutable):
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public typealias Mutable = Tagged<Memory.Mutable, Ordinal>
}

// In pointer-primitives (Pointer<T>.Mutable):
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Mutable = Tagged<Tag, Memory.Address.Mutable>
}
```

When resolving `.Mutable` on any `Tagged` type, the compiler finds both and reports ambiguity.

### Errors Produced

All errors are `ambiguous type name 'Mutable' in 'Tagged<...>'`:
- Extension constraints: `RawValue == Memory.Address.Mutable` fails
- Type references in bodies: `Memory.Address.Mutable(pointer)` fails
- Return types: `-> Memory.Address.Mutable` fails
- Parameter types: `source: Pointer<Tag>.Mutable` fails

### Constraints on Solution

1. `Pointer<T>` MUST remain a `Tagged` typealias (affine arithmetic reuse)
2. `Pointer<T>.Mutable` MUST be available in all type positions (expression, parameter, return, annotation)
3. No top-level typealiases or protocols as workarounds
4. Follow naming requirements ([API-NAME-001] `Nest.Name` pattern)

---

## 2. Experiment Design

**Location**: `Experiments/mutable-cross-module-ambiguity/`

**Structure**: Three-module layered package mirroring the real dependency chain:
- `MemoryLayer` -> minimal reproduction of memory-primitives types
- `PointerLayer` -> minimal reproduction of pointer-primitives types
- `Consumer` -> cross-module consumer tests

**Toolchain**: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
**Platform**: macOS 26.2 (arm64)

Variants are selected via `#if VARIANT_X` compile flags.

---

## 3. Experiment Results

### 3.1 Variant A: Two Mutable Typealiases (Current Production)

**Hypothesis**: Will FAIL cross-module due to ambiguous `.Mutable` lookup.

**Definition**:
```swift
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Mutable = Tagged<Tag, Memory.Address.Mutable>
}
```

**Result**: **REFUTED** (fails as hypothesized)
```
error: ambiguous type name 'Mutable' in 'Tagged<Tag, Tagged<Memory, Ordinal>>'
```

### 3.2 Variant B: Fully Qualify Constraint Only

**Hypothesis**: Qualifying the constraint but keeping `.Mutable` in type refs will still fail.

**Definition**: Same typealias, but constraint uses `Tagged<Memory.Mutable, Ordinal>`:
```swift
extension Tagged where RawValue == Tagged<Memory.Mutable, Ordinal>, Tag: ~Copyable {
    // body still uses Memory.Address.Mutable
}
```

**Result**: **REFUTED** (constraint compiles, but type references inside body still ambiguous)

### 3.3 Variant C: Fully Qualify EVERYWHERE

**Hypothesis**: No ambiguous `.Mutable` lookup if every reference is fully qualified.

**Definition**: All references use `Tagged<Memory.Mutable, Ordinal>` directly.

**Result**: **CONFIRMED for library code, but REFUTED for consumers**
- Library compiles
- Consumers CANNOT write `Pointer<Int>.Mutator` in type annotations — the typealias definition itself uses `.Mutable` which is ambiguous when resolved

### 3.4 Variant D: Remove Pointer-Level Mutable Typealias Entirely

**Hypothesis**: With only ONE Mutable typealias (on `Memory.Address`), no ambiguity.

**Result**: **REFUTED** (compiles, but `Pointer<T>.Mutable` is not available — violates constraint #2)

### 3.5 Variant E: Module-Level Typealias Bridge

**Hypothesis**: `public typealias MutableAddress = Tagged<Memory.Mutable, Ordinal>` avoids the lookup path.

**Result**: **REFUTED** (violates constraint #3: no top-level typealiases as workarounds)

### 3.6 Variant F: Fully Qualified Tag Hierarchy

**Hypothesis**: Define `Mutable` typealias using fully-qualified underlying type, test if `Pointer<Tag>.Mutable` is usable in generic extension bodies.

**Result**: **REFUTED** (`Pointer<Tag>.Mutable` is always ambiguous inside any `Tagged` extension, regardless of how the typealias itself is defined)

### 3.7 Variant G: Mutable as Nested Struct

**Hypothesis**: A `struct Mutable` nested in a `Tagged` extension (like `Buffer.Mutable`) won't collide.

**Result**: **REFUTED** (struct on Tagged extension also participates in the same member lookup collision)

### 3.8 Variant H: Move Typealias to Memory.Mutable Enum

**Hypothesis**: If `Memory.Address` is a typealias on the `Memory.Mutable` enum (NOT on a Tagged extension), then `Pointer<T>.Mutable` is the ONLY `Mutable` on any Tagged extension. No collision possible.

**Definition**:
```swift
// MemoryLayer: typealias on enum, not on Tagged
extension Memory.Mutable {
    public typealias Address = Tagged<Memory.Mutable, Ordinal>
}

// PointerLayer: only Mutable on any Tagged extension
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    public typealias Mutable = Tagged<Tag, Memory.Address>
}

// Extensions use Memory.Address in constraints
extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    // all operations...
}
```

**Result**: **CONFIRMED**

All 7 consumer tests pass:

| Test | Type Position | Result |
|------|--------------|--------|
| 1 | Expression context (`PointerH<Int>.Mutable(...)`) | Pass |
| 2 | Function parameter (`_ ptr: PointerH<Int>.Mutable`) | Pass |
| 3 | Return type (`-> PointerH<Int>.Mutable`) | Pass |
| 4 | Local type annotation (`let x: PointerH<Int>.Mutable = ...`) | Pass |
| 5 | `MemoryH.Mutable.Address` in expression | Pass |
| 6 | `MemoryH.Address` (immutable) | Pass |
| 7 | Cross-type copy (immutable -> mutable) | Pass |

---

## 4. Why Variant H Works

The resolution path for `Pointer<T>.Mutable` under Variant H:

1. `Pointer<T>` -> `Tagged<T, Memory.Address>` (typealias on `Memory` enum)
2. `.Mutable` -> finds `Mutable` on `Tagged where RawValue == Memory.Address` -> `Tagged<T, Memory.Address>`
3. Only ONE `Mutable` exists on any `Tagged` extension, so no ambiguity

The resolution path for `Memory.Address`:

1. `Memory.Mutable` -> the enum (member of `Memory` enum, NOT on Tagged)
2. `.Address` -> typealias on `Memory.Mutable` enum -> `Tagged<Memory.Mutable, Ordinal>`
3. No Tagged member lookup involved, so no ambiguity

The key insight: `.Mutable` on `Memory` resolves through the enum's namespace, never through
Tagged's member lookup. Only `Pointer<T>.Mutable` goes through Tagged's member lookup, and it's
now the only `Mutable` there.

---

## 5. Migration Status

### Phase 1: memory-primitives (COMPLETED)

| File | Change | Status |
|------|--------|--------|
| `Memory.swift` | Added `extension Memory.Mutable { public typealias Address = ... }` | Done |
| `Memory.Address.swift` | Removed `Mutable` typealias from `Tagged where Tag == Memory` extension | Done |
| `Memory.Address.Mutable.swift` -> `Memory.Address.swift` | Renamed file, updated all `Memory.Address.Mutable` refs | Done |
| `Memory.Address.Buffer.Mutable.swift` | Updated `Memory.Address.Mutable` -> `Memory.Address` | Done |
| `Memory.Allocator.Protocol.swift` | Updated refs | Done |
| `Memory.Allocator.swift` | Updated refs | Done |
| `Memory.Arena.swift` | Updated `Address.Mutable` -> `Mutable.Address` (short form in Memory extension) | Done |
| `Memory.Arena Tests.swift` | Updated ref | Done |

**Build result**: memory-primitives builds successfully (only pre-existing warnings).

### Phase 2: pointer-primitives (COMPLETED)

| File | Change | Status |
|------|--------|--------|
| `Pointer.swift` | Updated `Mutable` typealias to use `Memory.Address` | Done |
| `Pointer.Mutable.swift` | Changed constraints from `Tagged<Memory.Mutable, Ordinal>` to `Memory.Address`; updated body refs | Done |
| `Pointer+Range.swift` | Updated constraint and return type | Done |
| `Pointer.Mutable+Allocator.swift` | Updated constraint | Done |
| `Pointer.Mutable+Strided.swift` | Changed to `extension Memory.Address` | Done |
| `Pointer.Buffer.Mutable.swift` | Updated `Memory.Address.Buffer.Mutable` -> `Memory.Buffer.Mutable` | Done |

### Phase 3: Buffer Ambiguity (COMPLETED)

The `Buffer` struct nested in `Tagged where RawValue == Memory.Address` collided with
`Memory.Address.Buffer` (a struct in memory-primitives on `Tagged where Tag == Memory`).
Same pattern as `Mutable` — two identically-named nested types on different constrained
`Tagged` extensions.

**Fix applied**: Same Variant H pattern — moved `Memory.Address.Buffer` off the Tagged
extension to the `Memory` enum directly:

```swift
// Before (on Tagged extension — causes collision):
extension Tagged where Tag == Memory, RawValue == Ordinal {
    public struct Buffer { ... }
}

// After (on Memory enum — no collision):
extension Memory {
    public struct Buffer { ... }
}
```

| File | Change | Status |
|------|--------|--------|
| `Memory.Address.Buffer.swift` -> `Memory.Buffer.swift` | Moved struct from Tagged extension to `extension Memory`; renamed file | Done |
| `Memory.Address.Buffer.Mutable.swift` -> `Memory.Buffer.Mutable.swift` | Updated parent from `Memory.Address.Buffer` to `Memory.Buffer`; renamed file | Done |
| `Memory.Arena.swift` | Updated `Address.Buffer.Mutable` -> `Buffer.Mutable` (short form) | Done |
| `Memory.Buffer Tests.swift` | Updated all refs; renamed file | Done |
| `Memory.Buffer.Mutable Tests.swift` | Updated all refs; renamed file | Done |
| `Pointer.Buffer.Mutable.swift` | Updated `Memory.Address.Buffer.Mutable` -> `Memory.Buffer.Mutable` | Done |

### Build & Test Results

- **memory-primitives**: Builds clean, all 57 tests pass
- **pointer-primitives**: Builds clean

---

## 6. Conclusions

1. **Variant H is correct and verified** for both the `Mutable` and `Buffer` ambiguities
2. The pattern is general: ANY two identically-named nested types on different constrained `Tagged` extensions will collide cross-module
3. The fix is structural: ensure each name exists on at most ONE `Tagged` extension, by moving alternatives to enum namespaces
4. Final type hierarchy after migration:
   - `Memory.Address` = `Tagged<Memory, Ordinal>` (unchanged)
   - `Memory.Address` = `Tagged<Memory.Mutable, Ordinal>` (was `Memory.Address.Mutable`)
   - `Memory.Buffer` = struct on `Memory` enum (was `Memory.Address.Buffer`)
   - `Memory.Buffer.Mutable` = struct nested in `Memory.Buffer` (was `Memory.Address.Buffer.Mutable`)
   - `Pointer<T>` = `Tagged<T, Memory.Address>` (unchanged)
   - `Pointer<T>.Mutable` = `Tagged<T, Memory.Address>` (was `Tagged<T, Memory.Address.Mutable>`)
   - `Pointer<T>.Buffer` = struct on `Tagged where RawValue == Memory.Address` (unchanged)
   - `Pointer<T>.Buffer.Mutable` = struct nested in `Pointer<T>.Buffer` (unchanged)
