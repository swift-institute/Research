# Pass 6b: Nested Type Splits — Handoff Prompt

Read `/Users/coen/Developer/swift-institute/Research/audits/implementation-naming-2026-03-20/01-remediation-plan.md` for full context. This prompt continues **Pass 6: File Organization** for packages that were previously deferred as "justified exceptions" due to Swift compiler limitations.

## Background

Pass 6 initially skipped 3 packages because nested types with value generics and `~Copyable` constraints couldn't be declared in extensions. Two experiments have since confirmed these compiler bugs are **FIXED in Swift 6.2.4**:

- `value-generic-nested-type-bug`: **FIXED** — nested types in extensions work with value generics
- `noncopyable-cross-module-propagation`: **FIXED** — cross-module `~Copyable` works

This means nested types CAN now be moved to extension-based declarations in separate files.

**Note**: The Sequence/Copyable *poisoning* bug (where conditional `Sequence` conformance leaks `Copyable` requirement to stored properties) is still present. But that bug is about *conformance poisoning*, not about *nested type declarations*. Splitting a nested `struct Fixed` into `extension Queue { struct Fixed {} }` in a separate file doesn't trigger poisoning — it's orthogonal.

## Rule

**[API-IMPL-005]**: Each `.swift` file MUST contain exactly one type declaration.

## Goal

Move nested type declarations from primary struct bodies into extensions in separate files. No API changes — types keep the same fully-qualified names.

## Packages to Fix (tier order)

### Tier 16: swift-hash-table-primitives

**File**: `Sources/Hash Table Primitives Core/Hash.Table.swift`
**Current**: 8 type declarations in one file.

**Types to split out** (each gets its own file as an extension of `Hash.Table`):

| Type | Lines | Target file |
|------|-------|-------------|
| `Hash.Table.Bucket` | ~7 lines (struct + Index typealias + Ops enum) | `Hash.Table.Bucket.swift` |
| `Hash.Table.ForEach` | 1 line (tag enum) | `Hash.Table.ForEach.swift` |
| `Hash.Table.Remove` | 1 line (tag enum) | `Hash.Table.Remove.swift` |
| `Hash.Table.Positions` | 1 line (tag enum) | `Hash.Table.Positions.swift` |
| `Hash.Table.Static<let bucketCapacity: Int>` | ~120 lines (substantial type with InlineArray storage) | `Hash.Table.Static.swift` |

**Keep in Hash.Table.swift**: The `Hash.Table<Element>` struct declaration with stored properties, sentinels, init, and `bucketCapacity(for:)` / `normalize(_:)` utility methods.

**Pattern for each split file**:
```swift
// Hash.Table.Bucket.swift
extension Hash.Table {
    public struct Bucket: ~Copyable {
        public typealias Index = Index_Primitives.Index<Bucket>
        public enum Ops {}
    }
}
```

**For `Hash.Table.Static`**: This has a value-generic parameter `<let bucketCapacity: Int>`. The old compiler bug prevented this from compiling in extensions. Per experiment `value-generic-nested-type-bug` (FIXED in 6.2.4), this should now work:
```swift
// Hash.Table.Static.swift
extension Hash.Table {
    public struct Static<let bucketCapacity: Int>: ~Copyable {
        // ... full Static implementation ...
    }
}
```

**Important**: `Static` references `Table.Bucket`, `Table.empty`, `Table.deleted`, `Table.normalize(_:)`. These must remain accessible. Since extensions are module-scoped, the references should resolve. If `Static` uses bare `Bucket` (without `Table.` prefix), update to `Table.Bucket` or just `Bucket` (sibling resolution in extensions).

**Build**: `cd swift-hash-table-primitives && swift build && swift test` (clean build: `rm -rf .build` first)

---

### Tier 17: swift-queue-primitives

**File**: `Sources/Queue Primitives Core/Queue.swift`
**Current**: 9+ type declarations in one file.

**Types to split out**:

| Type | Target file | Notes |
|------|-------------|-------|
| `Queue.Fixed` | `Queue.Fixed.swift` | Ring buffer variant |
| `Queue.Linked` | `Queue.Linked.swift` | Must include `Queue.Linked.Fixed` inside it (nested value-generic type) |
| `Queue.DoubleEnded` | `Queue.DoubleEnded.swift` | Must include `Queue.DoubleEnded.Position` and `Queue.DoubleEnded.Fixed` |

**Within `Queue.Linked`**: `Queue.Linked.Inline<let capacity: Int>` and `Queue.Linked.Small<let inlineCapacity: Int>` are declared in `extension Queue.Linked where Element: Copyable`. These have value-generic parameters and are currently at the bottom of `Queue.swift`. Move them to:
- `Queue.Linked.Inline.swift` — with `extension Queue.Linked where Element: Copyable { struct Inline<let capacity: Int> {} }`
- `Queue.Linked.Small.swift` — same pattern

**Keep in Queue.swift**: The `Queue<Element>` struct declaration with `_buffer` stored property and the two inits.

**Conditional Copyable conformances** (`extension Queue: Copyable where Element: Copyable {}` etc.) can stay in `Queue.swift` or move to a `Queue+Copyable.swift` — your judgment.

**Pattern**:
```swift
// Queue.Fixed.swift
extension Queue {
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Ring.Bounded

        public let capacity: Index.Count

        @inlinable
        public init(capacity: Index.Count) {
            self._buffer = Buffer<Element>.Ring.Bounded(minimumCapacity: capacity)
            self.capacity = capacity
        }
    }
}
```

**Build**: `cd swift-queue-primitives && rm -rf .build && swift build && swift test`

---

### Tier 18: swift-dictionary-primitives

**File**: `Sources/Dictionary Primitives Core/Dictionary.Ordered.swift`
**Current**: 5 type declarations.

**Types to split out**:

| Type | Target file |
|------|-------------|
| `Dictionary.Entry` | `Dictionary.Entry.swift` |
| `Dictionary.Ordered` | `Dictionary.Ordered.swift` (keep this file, remove others) |
| `Dictionary.Ordered.Entry` | `Dictionary.Ordered.Entry.swift` |
| `Dictionary.Ordered.Bounded` | `Dictionary.Ordered.Bounded.swift` |

**Keep in current file**: Rename to `Dictionary.swift` — just the `Dictionary<Key, Value>` struct with stored properties and init.

**Pattern**:
```swift
// Dictionary.Entry.swift
extension Dictionary {
    public struct Entry: ~Copyable {
        public let key: Key
        public var value: Value
        @inlinable
        public init(key: Key, value: consuming Value) { ... }
    }
}
```

**Build**: `cd swift-dictionary-primitives && rm -rf .build && swift build && swift test`

---

## Procedure

For each package (in tier order):

1. Read the source file containing multiple types
2. Create new files for each type, wrapping in `extension ParentType { ... }`
3. Remove the type declarations from the original file
4. **Always clean build** (`rm -rf .build`) — stale artifacts from the old inline declarations will cause linker errors
5. `swift build` — if the compiler says a type isn't visible, check:
   - Does the extension correctly name the parent type?
   - Are `@usableFromInline` / `package` access levels preserved?
   - For value-generic types: does the extension syntax compile? (Should be fixed per experiment)
6. `swift test` — verify no behavioral changes
7. Commit: `[audit] Pass 6b: split nested types to per-file extensions — swift-X-primitives`

## What NOT to change

- **Error types in Queue.Error.swift** — these are hoisted module-level types per [API-EXC-001], not nested. Leave as-is.
- **1-line namespace enums** (e.g., `Darwin.Identity`) — not worth a separate file.
- **Conditional Copyable conformances** — these are extensions, not type declarations. Can stay grouped.
- **Any public API surface** — types must keep identical fully-qualified names.

## If a split fails to compile

The value-generic bug fix is confirmed by experiment, but the production codebase may hit edge cases the experiment didn't cover. If `Hash.Table.Static` or `Queue.Linked.Inline` fail to compile in an extension:

1. Document the exact error
2. Leave that specific type in the primary declaration
3. Add a comment: `// Cannot be in extension: [error description] (Swift 6.2.4)`
4. Continue with the other splits

## Estimated effort

~2 hours across 3 packages.
