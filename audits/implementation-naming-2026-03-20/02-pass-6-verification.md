# Pass 6 Verification: File Organization (One-Type-Per-File)

**Date**: 2026-03-20
**Rule**: [API-IMPL-005] Each `.swift` file MUST contain exactly one type declaration.
**Scope**: Top offenders identified in the initial audit.

## Verdict: NOT SPLIT

Pass 6 has **not been applied**. All original multi-type files remain in their pre-audit state. No file splits were performed in any of the 7 checked packages.

---

## 1. swift-queue-primitives

**Path**: `swift-primitives/swift-queue-primitives/Sources/Queue Primitives Core/`

### Queue.swift — 9 type declarations (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 83 | `public struct Queue<Element: ~Copyable>` |
| 115 | `public struct Fixed` (nested) |
| 172 | `public struct Linked` (nested) |
| 212 | `public struct Fixed` (Linked.Fixed, nested) |
| 244 | `public struct DoubleEnded` (nested) |
| 250 | `public enum Position` (nested) |
| 271 | `public struct Fixed` (DoubleEnded.Fixed, nested) |
| 384 | `public struct Inline<let capacity: Int>` (nested) |
| 421 | `public struct Small<let inlineCapacity: Int>` (nested) |

**Assessment**: All 9 types are nested inside `Queue` or its subtypes. Splitting is blocked by Swift's requirement that nested types be declared in the same file as their parent generic type. This is a **language-forced exception**, not a violation.

### Queue.Error.swift — 11 error enums (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 29 | `public enum __QueueError` |
| 37 | `public enum __QueueBoundedError` |
| 48 | `public enum __QueueStaticError` |
| 56 | `public enum __QueueLinkedError` |
| 67 | `public enum __QueueLinkedBoundedError` |
| 81 | `public enum __QueueLinkedInlineError` |
| 92 | `public enum __QueueLinkedSmallError` |
| 100 | `public enum __QueueDoubleEndedError` |
| 111 | `public enum __QueueDoubleEndedFixedError` |
| 122 | `public enum __QueueDoubleEndedStaticError` |
| 130 | `public enum __QueueDoubleEndedSmallError` |

**Assessment**: These are hoisted error types (module-level) with typealiases back to the generic parent. File documents the exception explicitly via `[API-EXC-001]` — Swift disallows nested types inside generic types from being easily accessed. **Splittable** into 11 separate files (e.g., `Queue.Error.swift`, `Queue.Bounded.Error.swift`, ...) since they are top-level enums.

### Queue DoubleEnded Primitives — 2 files with multi-type

- `Queue.DoubleEnded Copyable.swift`: 3 type declarations
- `Queue.DoubleEnded.Accessor.swift`: 3 type declarations

---

## 2. swift-hash-table-primitives

**Path**: `swift-primitives/swift-hash-table-primitives/Sources/Hash Table Primitives Core/`

### Hash.Table.swift — 7 type declarations (UNCHANGED, was reported as 8)

| Line | Declaration |
|------|-------------|
| 63 | `public struct Table<Element: ~Copyable>` |
| 68 | `public struct Bucket` (nested) |
| 73 | `public enum Ops` (nested in Bucket) |
| 77 | `public enum ForEach` (nested tag type) |
| 80 | `public enum Remove` (nested tag type) |
| 83 | `public enum Positions` (nested tag type) |
| 184 | `public struct Static<let bucketCapacity: Int>` (nested) |

**Assessment**: All types are nested inside `Hash.Table`. Splitting is blocked by Swift generic-type nesting rules. **Language-forced exception.** The remaining files (Hash.Occupied.swift, Hash.Occupied.Static.swift, Hash.Occupied.View.swift, etc.) each contain exactly 1 type declaration — already compliant.

---

## 3. swift-dictionary-primitives

**Path**: `swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/`

### Dictionary.Ordered.swift — 5 type declarations (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 86 | `public struct Dictionary<Key, Value: ~Copyable>` |
| 120 | `public struct Entry` (nested) |
| 204 | `public struct Ordered` (nested) |
| 215 | `public struct Entry` (Ordered.Entry, nested) |
| 277 | `public struct Bounded` (nested) |

**Assessment**: Nested inside generic parent. **Language-forced exception.**

### Dictionary.Ordered.Error.swift — 3 hoisted error enums + nested types (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 28 | `public enum __DictionaryOrderedError<Key>` |
| 39 | `public struct Bounds` (nested) |
| 51 | `public struct Empty` (nested) |
| 57 | `public struct Duplicate` (nested) |
| 79 | `public enum __DictionaryOrderedBoundedError<Key>` |
| 99 | `public enum __DictionaryOrderedInlineError<Key>` |
| 110 | `public struct Bounds` (nested) |

**Assessment**: 3 hoisted top-level error enums. **Splittable** into separate files.

### Dictionary.Ordered.Keys.swift — 2 declarations
### Dictionary.Ordered.Values.swift — 2 declarations

---

## 4. swift-cache-primitives

**Path**: `swift-primitives/swift-cache-primitives/Sources/Cache Primitives/`

### Current file listing (11 files)

```
Cache.Action.swift          Cache.Entry.State.swift    Cache.Evict.swift
Cache.Compute.swift         Cache.Entry.Waiters.swift  Cache.Error.swift
Cache.Entry.swift           Cache.State.swift          Cache.Storage.swift
Cache.swift                 exports.swift
```

**Assessment**: Already well-split compared to the audit's "4 types in Cache.swift, 3 types in Cache.Entry.swift" finding.

- `Cache.swift`: 1 type (`Cache`)
- `Cache.Entry.swift`: 1 type (`Entry`)
- `Cache.Entry.State.swift`: 1 type (`State`)
- `Cache.Entry.Waiters.swift`: 1 type (`Waiters`)
- `Cache.Evict.swift`: 2 types (`__CacheEvict` + nested `Reason`) — minor nested enum
- `Cache.Error.swift`: 1 type (nested `Error` enum)
- `Cache.Action.swift`: 1 type (nested `Action` enum)
- `Cache.State.swift`: 1 type (nested `State` struct)
- `Cache.Storage.swift`: 1 type (nested `Storage` struct)
- `Cache.Compute.swift`: 1 type (`__CacheCompute`)

**Verdict**: Cache was **already split** (possibly pre-audit or as part of original authoring). Largely compliant. `Cache.Evict.swift` has a nested `Reason` enum which is acceptable (tightly coupled).

---

## 5. swift-dimension-primitives

**Path**: `swift-primitives/swift-dimension-primitives/Sources/Dimension Primitives/`

### Current file listing (32 files — significantly expanded)

The module was expanded from the original ~4 type file into 32 individual files. However, several files contain multiple nested namespace enums:

| File | Count | Types |
|------|-------|-------|
| `Coordinate.swift` | 6 | `Coordinate`, `X`, `Y`, `Z`, `W`, `Vector` |
| `Displacement.swift` | 6 | `Displacement`, `X`, `Y`, `Z`, `W`, `Vector` |
| `Extent.swift` | 5 | `Extent`, `X`, `Y`, `Z`, `Vector` |
| `Angle.swift` | 3 | `Angle` + 2 nested |
| `Degree.swift` | 3 | `Degree` + 2 nested |
| `Axis.swift` | 2 | `Axis` + 1 nested |

**Assessment**: These are **namespace enums** with per-dimension tag types nested inside. The nesting is structurally required (e.g., `Coordinate.X<Space>` must be nested inside `Coordinate`). The sub-axes do have separate files (`Axis.Horizontal.swift`, `Axis.Vertical.swift`, etc.) showing partial splitting was done. The remaining multi-type files are **language-forced exceptions**.

---

## 6. swift-kernel-primitives

**Path**: `swift-primitives/swift-kernel-primitives/Sources/`

### Kernel Outcome Primitives — Kernel.Outcome.swift: 4 declarations (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 52 | `public enum Outcome<Failure>` |
| 86 | `public enum Value<Success>` (nested in Outcome) |
| 118 | `public enum GetError` (nested in Outcome) |
| 144 | `public enum GetError` (nested in Outcome.Value) |

**Assessment**: All nested inside `Kernel.Outcome`. **Language-forced exception** (generic parent).

### Kernel Process Primitives — Kernel.Process.swift: 2 declarations (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 22 | `public enum Process` |
| 27 | `public enum Group` (nested) |

**Assessment**: `Group` is a namespace nested inside `Process`. **Splittable** — `Group` could be in `Kernel.Process.Group.swift`, but is already small (2 lines). Low priority.

### Kernel File Primitives — 15 files with 2+ declarations (UNCHANGED)

Notable multi-type files:
- `Kernel.File.Attributes.swift`: 5 types
- `Kernel.File.Chown.swift`: 5 types (namespace + Error + 3 sub-errors)
- `Kernel.File.Times.swift`: 5 types (namespace + Error + 3 sub-errors)
- `Kernel.File.Direct.Capability.swift`: 3 types
- `Kernel.File.Direct.Error.Operation.swift`: 3 types

Most follow the pattern: namespace enum + Error enum + subcategory error enums in the same file. These are tightly coupled but technically splittable.

---

## 7. swift-darwin-primitives

**Path**: `swift-primitives/swift-darwin-primitives/Sources/Darwin Kernel Primitives/`

### Darwin.Identity.UUID.swift — 2 declarations (UNCHANGED)

| Line | Declaration |
|------|-------------|
| 10 | `public enum Identity` (namespace) |
| 15 | `public enum UUID` (nested in Identity) |

**Assessment**: Two namespace enums in one file. **Splittable** into `Darwin.Identity.swift` + `Darwin.Identity.UUID.swift`. Low priority — the file is cohesive (UUID is the only member of Identity).

### Darwin.Kernel.File.Attributes.Extended.swift — 2 declarations

Namespace `Extended` + `Error`. Tightly coupled.

---

## Summary

| Package | Audit Finding | Current State | Pass 6 Applied? |
|---------|--------------|---------------|-----------------|
| swift-queue-primitives | Queue.swift: 9 types, Queue.Error.swift: 11 enums | **Unchanged** | No |
| swift-hash-table-primitives | Hash.Table.swift: 8 types | **Unchanged** (7 counted) | No |
| swift-dictionary-primitives | Dictionary.Ordered.swift: 5 types | **Unchanged** | No |
| swift-cache-primitives | Cache.swift: 4 types, Cache.Entry.swift: 3 types | **Already split** (pre-existing) | N/A (was already compliant) |
| swift-dimension-primitives | Dimension.swift: 4+ types | **Expanded to 32 files** but namespace files retain nested types | Partial |
| swift-kernel-primitives | Multiple files: 2-3 types | **Unchanged** (many files with 2-5 types) | No |
| swift-darwin-primitives | Darwin.Identity.UUID.swift: 2 types | **Unchanged** | No |

### Classification of Remaining Violations

**Language-forced exceptions** (cannot split — nested inside generic parent):
- `Queue.swift` (9 nested types in generic struct)
- `Hash.Table.swift` (7 nested types in generic struct)
- `Dictionary.Ordered.swift` (5 nested types in generic struct)
- `Kernel.Outcome.swift` (4 nested types in generic enum)
- Dimension namespace files (`Coordinate`, `Displacement`, `Extent`)

**Splittable but not split** (hoisted module-level types):
- `Queue.Error.swift` — 11 independent top-level enums
- `Dictionary.Ordered.Error.swift` — 3 independent top-level enums

**Splittable namespace+error pairs** (low priority):
- `Kernel.Process.swift` — namespace + nested namespace
- `Darwin.Identity.UUID.swift` — 2 namespace enums
- 15 files in Kernel File Primitives — namespace + error combos
