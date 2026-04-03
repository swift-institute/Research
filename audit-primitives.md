# Primitives Pre-Publication Audit — swift-file-system Dependency Tree

**Date**: 2026-04-03
**Scope**: All primitives packages transitively reachable from `swift-file-system` (73 packages via BFS from 26 direct primitives dependencies through 6 foundations packages)
**Exclusion**: `swift-base62-primitives` (already audited and fixed)

---

## Summary

| Priority | Check | Violations | Severity |
|----------|-------|------------|----------|
| P0 | Foundation imports | **0** in-tree | Clean |
| P1 | Multi-type files [API-IMPL-005] | **5 files** across 5 packages | Moderate — all are error-type groupings |
| P1 | Compound type names [API-NAME-001] | **3 types** across 3 packages | Low-moderate |
| P2 | Methods in type body [API-IMPL-008] | **6 files** across 5 packages | Mixed — some intentional |

**Verdict**: No P0 blockers. P1 findings are limited to error-type grouping files and a single top-level compound name. P2 findings are concentrated in platform packages and one ~Copyable type with an explicit design justification.

---

## P0: Foundation Imports

**Result: CLEAN** — Zero Foundation imports in any package within the dependency tree.

Foundation imports exist only in `swift-structured-queries-primitives` (12 files), which is a standalone package with zero dependents and is NOT in the swift-file-system dependency tree.

---

## P1: Multi-Type Files [API-IMPL-005]

All violations follow the same pattern: multiple `__`-prefixed error enums grouped in a single `*.Error.swift` file. Each enum corresponds to a different variant of the parent data structure.

### queue-primitives — Queue.Error.swift (11 types, 177 lines)

`/Users/coen/Developer/swift-primitives/swift-queue-primitives/Sources/Queue Primitives Core/Queue.Error.swift`

| Line | Type |
|------|------|
| 29 | `__QueueError` |
| 37 | `__QueueBoundedError` |
| 48 | `__QueueStaticError` |
| 56 | `__QueueLinkedError` |
| 67 | `__QueueLinkedBoundedError` |
| 81 | `__QueueLinkedInlineError` |
| 92 | `__QueueLinkedSmallError` |
| 100 | `__QueueDoubleEndedError` |
| 111 | `__QueueDoubleEndedFixedError` |
| 122 | `__QueueDoubleEndedStaticError` |
| 130 | `__QueueDoubleEndedSmallError` |

### set-primitives — Set.Ordered.Error.swift (3 types, 170 lines)

`/Users/coen/Developer/swift-primitives/swift-set-primitives/Sources/Set Primitives Core/Set.Ordered.Error.swift`

| Line | Type |
|------|------|
| 22 | `__SetOrderedError<Element>` |
| 58 | `__SetOrderedFixedError<Element>` |
| 118 | `__SetOrderedInlineError<Element>` |

Plus nested `InvalidCapacity` structs within each (line 96).

### dictionary-primitives — Dictionary.Ordered.Error.swift (3 types, 192 lines)

`/Users/coen/Developer/swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Error.swift`

| Line | Type |
|------|------|
| 28 | `__DictionaryOrderedError<Key>` |
| 79 | `__DictionaryOrderedBoundedError<Key>` |
| 99 | `__DictionaryOrderedInlineError<Key>` |

### list-primitives — List.Linked.Error.swift (4 types, 115 lines)

`/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Primitives Core/List.Linked.Error.swift`

| Line | Type |
|------|------|
| 30 | `__ListLinkedError` |
| 41 | `__ListLinkedBoundedError` |
| 55 | `__ListLinkedInlineError` |
| 66 | `__ListLinkedSmallError` |

### stack-primitives — Stack.Error.swift (2 types, 77 lines)

`/Users/coen/Developer/swift-primitives/swift-stack-primitives/Sources/Stack Primitives Core/Stack.Error.swift`

| Line | Type |
|------|------|
| 28 | `__StackBoundedError<Element>` |
| 45 | `__StackStaticError<Element>` |

### Assessment

These are all `__`-prefixed internal error enums hoisted to module scope for typed throws. The grouping is arguably justified: each file contains related error types for variants of the same data structure, and they share documentation context. Splitting to one file per `__`-prefixed error enum would create 23 additional files with low individual value.

**Recommendation**: Accept as-is or split only the largest (Queue.Error.swift with 11 types). The `__` prefix already signals these are implementation infrastructure, not public API surface.

---

## P1: Compound Type Names [API-NAME-001]

### handle-primitives — `SlotAddress` (top-level)

`/Users/coen/Developer/swift-primitives/swift-handle-primitives/Sources/Handle Primitives/SlotAddress.swift:31`

```swift
public struct SlotAddress: Hashable, Sendable {
```

This is a top-level public type with a compound name. Per [API-NAME-001], should be `Slot.Address` nested under a `Slot` namespace, or restructured as `Handle.Slot.Address`.

**In dependency tree via**: binary-parser-primitives -> machine-primitives -> handle-primitives

### binary-primitives — `SignDisplayStrategy` (nested)

`/Users/coen/Developer/swift-primitives/swift-binary-primitives/Sources/Binary Format Primitives/Binary.Format.Radix.swift:74`

```swift
public struct SignDisplayStrategy: Sendable {
```

Nested inside `Binary.Format.Radix` extension. Full path is `Binary.Format.Radix.SignDisplayStrategy`. Per [API-NAME-001], should be `Sign.Display.Strategy` or decomposed into nested namespaces.

### test-primitives — `StructuralOperation` (nested)

`/Users/coen/Developer/swift-primitives/swift-test-primitives/Sources/Test Snapshot Primitives/Test.Snapshot.Diff.Result.StructuralOperation.swift:26`

```swift
public enum StructuralOperation: Sendable, Hashable, Codable {
```

Full path is `Test.Snapshot.Diff.Result.StructuralOperation`. Should be `Structural.Operation` or `Structure.Operation`.

### Borderline (not flagged)

- `Parser.Prefix.UpTo` — two-word concept name, arguably a single concept
- `Async.Broadcast.Subscription.AsyncIterator` — mirrors Swift stdlib convention
- `Queue.DoubleEnded` — mirrors standard CS terminology "double-ended queue"

---

## P2: Methods in Type Body [API-IMPL-008]

Only reporting files with 5+ methods/computed properties defined inside the primary type body (not in extensions). Threshold chosen to filter noise.

### vector-primitives — Vector.swift (30 items in body)

`/Users/coen/Developer/swift-primitives/swift-vector-primitives/Sources/Vector Primitives Core/Vector.swift`

The entire file (lines 94-415) is a single struct body with no extensions. Contains stored properties, nested types, computed properties, and methods all in one body.

**Mitigating factor**: The file contains an explicit design note (line 90-93) stating that nested types are declared inline for `~Copyable` constraint inheritance per [PATTERN-022]. The nested types (`Iterator`, `Reversed`, `ForEach`, `Drain`, `Error`) genuinely require this. However, the computed properties and methods (`isEmpty`, `makeIterator`, `reversed`, `forEach`, `drain`, `_borrowingForEach`, `_consumingDrain`) could be moved to extensions.

### ordinal-primitives — Ordinal.swift (6 items in body)

`/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.swift`

All operator overloads (`==`, `<`, `<=`, `>`, `>=`) and `zero` static property are defined inside the struct body (lines 39-88). No extensions exist in the file.

| Line | Item |
|------|------|
| 57 | `static var zero` |
| 63 | `static func ==` |
| 70 | `static func <` |
| 75 | `static func <=` |
| 80 | `static func >` |
| 85 | `static func >=` |

### linux-primitives — 3 files

All in `/Users/coen/Developer/swift-primitives/swift-linux-primitives/Sources/Linux Kernel Primitives/`:

| File | Items in body |
|------|---------------|
| `Linux.Kernel.IO.Uring.Submission.Queue.Entry.Prepare.swift` | 12 |
| `Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift` | 10 |
| `Linux.Kernel.IO.Uring.swift` | 7 |
| `Linux.Kernel.IO.Uring.Completion.Queue.Entry.swift` | 7 |

### windows-primitives — 3 files

All in `/Users/coen/Developer/swift-primitives/swift-windows-primitives/Sources/Windows Kernel Primitives/`:

| File | Items in body |
|------|---------------|
| `Kernel.IO.Completion.Port.swift` | 10 |
| `Kernel.IO.Completion.Port.Dequeue.swift` | 7 |
| `Kernel.IO.Completion.Port.Cancel.swift` | 7 |

### darwin-primitives — Darwin.Kernel.Kqueue.swift

`/Users/coen/Developer/swift-primitives/swift-darwin-primitives/Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.swift`

The `Kqueue` enum is declared inside an `extension Kernel { }` block with methods defined in further nested extensions. The initial detection was a false positive for the Kqueue type itself, but the `Darwin.Kernel.Kqueue.Event.swift` file (7 items in body) may be a legitimate finding.

### Assessment

The platform packages (linux, windows, darwin) consistently define methods inside struct/enum bodies rather than using extensions. This appears to be a systematic pattern in the platform layer, possibly because these are thin syscall wrappers where the extension pattern adds overhead without benefit.

**Recommendation**: 
- `Vector.swift`: Move methods to extensions; keep nested types inline per [PATTERN-022]
- `Ordinal.swift`: Move operators and static property to extensions
- Platform packages: Consider as a batch cleanup, but lower priority since these are platform-specific code

---

## Out-of-Tree Findings (for reference)

### swift-structured-queries-primitives (NOT in dependency tree)

This package has severe violations across all categories:
- **12 files** with `import Foundation` (P0 blocker if it were in-tree)
- **15+ files** with multiple top-level types
- Extensive compound naming
- No namespace nesting pattern

This package appears to be vendored/adapted code (SQLite query builder) that predates the current conventions. It is isolated with zero dependents.

---

## Packages Scanned

73 packages were reached via BFS from the 26 direct primitives dependencies of the 6 foundations packages (`swift-ascii`, `swift-environment`, `swift-kernel`, `swift-paths`, `swift-strings`, `swift-io`) plus 2 direct primitives dependencies of `swift-file-system` itself (`swift-algebra-primitives`, `swift-binary-primitives`).

The transitive closure expands to essentially all 134 packages in swift-primitives because `swift-kernel-primitives` has broad dependencies. All 134 were scanned for P0 (Foundation) and the results above include all findings regardless of tree position.
