# Storage.Inline Invariants

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: DECISION
tier: 2
---
-->

## Context

`Storage.Inline` is a fixed-capacity, stack-allocated storage primitive that supports `~Copyable` elements. After the `@_rawLayout` migration (2026-02-05), the implementation uses automatic layout computation for optimal memory efficiency.

This document catalogs all invariants — the constraints, guarantees, and design rules that the implementation must maintain and that consumers can rely upon.

## Question

What are all the invariants for `Storage.Inline` that must be preserved across modifications?

## Invariant Catalog

### INV-INLINE-001: Layout Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-001a | **Size**: `MemoryLayout<Storage.Inline<E, N>>.size == MemoryLayout<E>.stride × N + MemoryLayout<Initialization>.size` | `@_rawLayout` attribute |
| INV-INLINE-001b | **Alignment**: `MemoryLayout<Storage.Inline<E, N>>.alignment >= MemoryLayout<E>.alignment` | `@_rawLayout` attribute |
| INV-INLINE-001c | **Contiguous**: Elements are stored at offsets `0, stride, 2×stride, ..., (N-1)×stride` from `_storage` base | `@_rawLayout(likeArrayOf:count:)` |
| INV-INLINE-001d | **No padding between elements**: Slot `i` is at exactly `i × MemoryLayout<Element>.stride` bytes | Pointer arithmetic |

### INV-INLINE-002: Initialization State Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-002a | **Empty on construction**: `init()` sets `_initialization = .empty` | Constructor implementation |
| INV-INLINE-002b | **Caller updates state**: `initialize(to:at:)`, `move(at:)`, `deinitialize(at:)` do NOT update `_initialization` — caller must | Documentation + design |
| INV-INLINE-002c | **Bulk deinitialize updates state**: `deinitialize()` (no parameters) DOES update `_initialization` to `.empty` | Implementation |
| INV-INLINE-002d | **State reflects reality**: `_initialization` MUST accurately track which slots contain initialized values | Caller responsibility |

### INV-INLINE-003: Slot Access Preconditions

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-003a | **Read requires initialized**: `pointer(at:)` returning `UnsafePointer` requires slot to be initialized | Precondition (unchecked) |
| INV-INLINE-003b | **Move requires initialized**: `move(at:)` requires slot to be initialized | Precondition (unchecked) |
| INV-INLINE-003c | **Initialize requires uninitialized**: `initialize(to:at:)` requires slot to be uninitialized | Precondition (unchecked) |
| INV-INLINE-003d | **Deinitialize requires initialized**: `deinitialize(at:)` requires slot to be initialized | Precondition (unchecked) |
| INV-INLINE-003e | **Slot in bounds**: `slot.rawValue.rawValue < capacity` | Caller responsibility |

### INV-INLINE-004: Ownership Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-004a | **Always ~Copyable**: `Storage.Inline` is always `~Copyable`, even when `Element: Copyable` | `@_rawLayout` constraint |
| INV-INLINE-004b | **Conditional Sendable**: `Storage.Inline: Sendable` iff `Element: Sendable` | Conditional conformance |
| INV-INLINE-004c | **@unchecked Sendable**: Sendable conformance uses `@unchecked` due to `@_rawLayout` | Type constraint |
| INV-INLINE-004d | **Move semantics**: `move(at:)` transfers ownership; slot becomes uninitialized | Pointer.move() semantics |
| INV-INLINE-004e | **Consuming initialize**: `initialize(to:at:)` consumes the element | `consuming` parameter |

### INV-INLINE-005: Initialization Enum Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-005a | **Two-span ordering**: `.two(first:second:)` requires `first.lowerBound < second.lowerBound` | Documentation |
| INV-INLINE-005b | **Two-span disjoint**: `.two(first:second:)` requires `first.upperBound <= second.lowerBound` | Documentation |
| INV-INLINE-005c | **Empty semantics**: `.empty` means zero initialized slots | Enum case |
| INV-INLINE-005d | **One semantics**: `.one(range)` means exactly `range.count` contiguous initialized slots | Enum case |
| INV-INLINE-005e | **Two semantics**: `.two` means two disjoint ranges (ring buffer wrap-around) | Enum case |

### INV-INLINE-006: Cross-Storage Operation Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-006a | **Move to heap linearizes**: `move(range:to:)` places elements at `0..<range.count` in destination | Implementation |
| INV-INLINE-006b | **Copy to heap linearizes**: `copy(range:to:)` places elements at `0..<range.count` in destination | Implementation |
| INV-INLINE-006c | **Move deinitializes source**: After `move(range:to:)`, source slots are uninitialized | Pointer.move() semantics |
| INV-INLINE-006d | **Copy preserves source**: After `copy(range:to:)`, source slots remain initialized | Pointer.pointee semantics |
| INV-INLINE-006e | **Destination must be uninitialized**: Target slots `0..<range.count` must be uninitialized | Precondition (unchecked) |

### INV-INLINE-007: Pointer Lifetime Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-007a | **Immutable pointer borrows self**: `pointer(at:) -> UnsafePointer` is `@_lifetime(borrow self)` | Attribute |
| INV-INLINE-007b | **Mutable pointer requires inout**: `pointer(at:) -> UnsafeMutablePointer` requires `mutating` | Function signature |
| INV-INLINE-007c | **Pointer escape forbidden**: Pointers must not outlive the storage | Lifetime system |

### INV-INLINE-008: Capacity Invariants

| ID | Invariant | Enforcement |
|----|-----------|-------------|
| INV-INLINE-008a | **Compile-time capacity**: `capacity` is a value generic parameter (`let capacity: Int`) | Type signature |
| INV-INLINE-008b | **Fixed capacity**: Capacity cannot change after type instantiation | Value generics |
| INV-INLINE-008c | **Valid slot range**: Slots `0..<capacity` are the only valid indices | Type definition |

## Invariant Categories

### Type-System Enforced (Compile-Time)

- INV-INLINE-001a,b,c (layout via `@_rawLayout`)
- INV-INLINE-004a (~Copyable)
- INV-INLINE-004e (consuming parameter)
- INV-INLINE-007a,b (lifetime attributes)
- INV-INLINE-008a,b (value generics)

### Implementation Enforced (Runtime)

- INV-INLINE-001d (pointer arithmetic correctness)
- INV-INLINE-002a,c (constructor and bulk deinit)
- INV-INLINE-004b,c (conditional conformance)
- INV-INLINE-006a,b,c,d (cross-storage operations)

### Caller Responsibility (Unchecked)

- INV-INLINE-002b,d (initialization state maintenance)
- INV-INLINE-003a,b,c,d,e (slot access preconditions)
- INV-INLINE-005a,b (two-span invariants)
- INV-INLINE-006e (destination uninitialized)
- INV-INLINE-007c (pointer lifetime)
- INV-INLINE-008c (valid slot range)

## Consequences of Violation

| Invariant Class | Consequence |
|-----------------|-------------|
| Layout | Memory corruption, undefined behavior |
| Initialization state | Double-free, use-after-free, memory leak |
| Slot access preconditions | Undefined behavior |
| Ownership | Compile error (type-system enforced) |
| Two-span ordering | Incorrect deinitialization (may leak or double-free) |
| Cross-storage | Memory corruption in destination |
| Pointer lifetime | Dangling pointer, undefined behavior |
| Capacity | Out-of-bounds access, undefined behavior |

## Testing Implications

| Invariant | Test Strategy |
|-----------|---------------|
| INV-INLINE-001 | `MemoryLayout` assertions in tests |
| INV-INLINE-002 | Tracker classes verifying deinit counts |
| INV-INLINE-003 | Cannot test directly (UB on violation) |
| INV-INLINE-004 | Compile-time — type system rejects violations |
| INV-INLINE-005 | Unit tests with two-span scenarios |
| INV-INLINE-006 | Cross-storage move/copy tests |
| INV-INLINE-007 | Compile-time — lifetime system rejects violations |
| INV-INLINE-008 | Compile-time — value generics |

## Prior Art

- **Rust `MaybeUninit<T>`**: Similar uninitialized storage with caller-tracked initialization
- **Swift `ManagedBuffer`**: Heap equivalent with header + elements pattern
- **C++ `std::aligned_storage`**: Fixed layout storage (deprecated in C++23)

## References

- `Storage.Inline.swift:44-72` — Type definition
- `Storage.Inline ~Copyable.swift:27-167` — Operations
- `Storage.Initialization.swift:12-98` — Initialization enum
- `Experiments/rawlayout-wrapper-validation/` — Layout verification (SUPERSEDED — consolidated into `swift-buffer-primitives/Experiments/rawlayout-llvm-verifier-crash/` V06-wrapper-patterns)
