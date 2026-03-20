# swift-storage-primitives — Implementation & Naming Audit

**Date**: 2026-03-20
**Auditor**: Claude (read-only)
**Scope**: 53 source files across 10 modules
**Skills**: [API-NAME-001], [API-NAME-002], [IMPL-002], [IMPL-010], [PATTERN-017], [PATTERN-021], [API-IMPL-005]

## Summary Table

| ID | Severity | Rule | File | Line | Description |
|----|----------|------|------|------|-------------|
| STOR-001 | LOW | [IMPL-010] | Storage.Heap ~Copyable.swift | 28 | `Int(bitPattern:)` at ManagedBuffer boundary — acceptable |
| STOR-002 | LOW | [IMPL-010] | Storage.Split ~Copyable.swift | 49 | `Int(bitPattern:)` at ManagedBuffer boundary — acceptable |
| STOR-003 | MEDIUM | [API-IMPL-005] | Storage.swift | 31,59 | `Storage` enum and `Storage.Initialization` enum share one file |

## Findings

### STOR-001 — `Int(bitPattern:)` at ManagedBuffer Boundary [ACCEPTABLE]

**File**: `Sources/Storage Heap Primitives/Storage.Heap ~Copyable.swift`, line 28
**Rule**: [IMPL-010]

```swift
Storage.Heap.create(
    minimumCapacity: Int(bitPattern: minimumCapacity)
) { _ in Storage.Heap.Header() }
```

`Int(bitPattern:)` is used to cross from the typed `Index<Element>.Count` domain into `ManagedBuffer.create(minimumCapacity:)` which requires `Int`. This is a legitimate boundary overload — the conversion occurs at the stdlib interop edge. **Acceptable per [IMPL-010]**.

### STOR-002 — `Int(bitPattern:)` at ManagedBuffer Boundary [ACCEPTABLE]

**File**: `Sources/Storage Split Primitives/Storage.Split ~Copyable.swift`, line 49
**Rule**: [IMPL-010]

```swift
Storage.Split<Lane>.create(minimumCapacity: Int(bitPattern: bytes.cardinal)) { ... }
```

Same pattern as STOR-001 — crossing from typed cardinal to `ManagedBuffer.create`. **Acceptable per [IMPL-010]**.

### STOR-003 — Two Types in One File

**File**: `Sources/Storage Primitives Core/Storage.swift`
**Rule**: [API-IMPL-005]

The file contains both `Storage<Element>` (the namespace enum, line 31) and `Storage<Element>.Initialization` (the initialization tracking enum, line 59). Per [API-IMPL-005], `Initialization` should live in its own file. Note that `Storage.Initialization.swift` already exists in the same module containing computed properties and methods — so the type declaration itself (lines 59-72) could be moved to the top of that file.

Additionally, lines 76-107 contain `Storage.Heap` extension methods (`pointer(at:)`) which belong in the Heap module files, not in `Storage.swift`. This is extension code for a type defined in a different file within the same module, so it is permissible, but relocating it to `Storage.Heap ~Copyable.swift` or a dedicated pointer-access file would improve locality.

## Clean Areas

### Naming ([API-NAME-001], [API-NAME-002])

All types follow the `Nest.Name` pattern correctly:
- `Storage.Heap`, `Storage.Inline`, `Storage.Split`, `Storage.Pool`, `Storage.Arena`, `Storage.Slab`
- `Storage.Pool.Inline`, `Storage.Arena.Inline`
- `Storage.Heap.Header`, `Storage.Split.Header`
- `Storage.Field`, `Storage.Initialization`
- Tag types: `Storage.Move`, `Storage.Copy`, `Storage.Deinitialize`, `Storage.Initialize`
- `Storage.Pool.Error`, `Storage.Error`
- No compound type names anywhere.

All methods and properties follow [API-NAME-002]:
- `storage.initialize.next(to:)`, `storage.move.last()`, `storage.deinitialize.all()`
- `storage.copy(range:to:at:)`, `storage.field.lane`, `storage.field.element`
- No compound method names.

### .rawValue Usage ([IMPL-002], [PATTERN-017])

No `.rawValue` access at call sites. All typed arithmetic flows through Index, Cardinal, Ordinal, and Affine primitives.

### Typed Arithmetic ([PATTERN-021])

No `__unchecked` usage anywhere. All arithmetic uses typed operations:
- `Index<Element>.Offset(fromZero:)` for pointer arithmetic
- `.retag()` for cross-domain conversions
- `.map(Ordinal.init)` for cardinal-to-ordinal conversions
- `.subtract.saturating()` for safe subtraction

### One Type Per File ([API-IMPL-005])

With the exception noted in STOR-003, all files follow one-type-per-file. Extension files correctly use the `Type+Aspect.swift` or `Type Constraint.swift` naming convention.

## Verdict

**Excellent**. The package demonstrates exemplary adherence to all audited rules. The only substantive finding (STOR-003) is a nested enum declaration cohabiting with its parent namespace. All naming, `.rawValue` confinement, typed arithmetic, and `Int(bitPattern:)` boundary patterns are correct.
