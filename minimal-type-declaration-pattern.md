# Minimal Type Declaration Pattern

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
tier: 2
---
-->

## Context

Swift Institute packages have evolved toward a consistent pattern: type declarations contain only stored properties and the canonical initializer, with all other functionality added via extensions. This research documents the pattern, its rationale, and the exception for `~Copyable` types.

**Trigger**: Skill audit revealed inconsistent application across packages. Some packages (swift-set-primitives, swift-stack-primitives) follow the pattern rigorously; others need alignment.

**Scope**: Ecosystem-wide convention affecting all Swift Institute packages.

---

## Question

What should be the canonical structure of type declarations, and what belongs in extensions?

---

## Analysis

### Option A: Everything in Type Body

All methods, computed properties, and protocol conformances declared in the type body.

```swift
public struct Buffer: Sequence, Sendable {
    private var storage: Storage
    private var count: Int

    public init() { ... }

    public var isEmpty: Bool { count == 0 }

    public func makeIterator() -> Iterator { ... }

    public mutating func append(_ element: Element) { ... }
}
```

**Advantages**:
- Single location for all type information
- No navigation required

**Disadvantages**:
- Large, unwieldy files for complex types
- Harder to scan for storage layout
- Protocol conformances mixed with implementation
- No clear separation of concerns

---

### Option B: Minimal Body + Extensions

Type body contains only stored properties and canonical init. Everything else in extensions.

```swift
// Buffer.swift
public struct Buffer {
    @usableFromInline
    var storage: Storage

    @usableFromInline
    var count: Int

    @inlinable
    public init() {
        self.storage = Storage()
        self.count = 0
    }
}

// Buffer+Sequence.swift
extension Buffer: Sequence {
    public func makeIterator() -> Iterator { ... }
}

// Buffer.swift (same file, after body)
extension Buffer {
    public var isEmpty: Bool { count == 0 }

    public mutating func append(_ element: Element) { ... }
}
```

**Advantages**:
- Storage layout immediately visible
- Clear separation: data vs behavior
- Protocol conformances isolated
- Smaller, focused files
- Easier code review (changes to behavior don't touch data layout)

**Disadvantages**:
- Multiple files to navigate
- Must understand extension pattern

---

### Option C: Minimal Body with ~Copyable Exception

Same as Option B, but `~Copyable` types MAY include additional content in the body to avoid constraint poisoning per [MEM-COPY-006].

```swift
// For ~Copyable types, nested types and conformances MAY be in body
public struct Container<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> { }

    @usableFromInline
    var storage: Storage

    @inlinable
    public init() { ... }
}

// Conformances still MUST be in same file to avoid poisoning
extension Container: Copyable where Element: Copyable { }
extension Container: Sendable where Element: Sendable { }
```

**Advantages**:
- All benefits of Option B
- Avoids ~Copyable constraint poisoning bugs
- Pragmatic accommodation of compiler limitations

**Disadvantages**:
- Exception adds complexity to the rule
- Must understand when exception applies

---

### Comparison

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Storage visibility | Poor | Excellent | Excellent |
| Separation of concerns | None | Strong | Strong |
| File size | Large | Small | Small |
| ~Copyable compatibility | N/A | Broken | Works |
| Rule complexity | Simple | Simple | Moderate |
| Adoption in primitives | Rare | Partial | Full |

---

## Evidence from Existing Packages

### swift-set-primitives (follows pattern)

**Set.Ordered.swift** — Type body contains:
- `ElementStorage` and `IndexStorage` nested classes
- Three stored properties
- `init()`
- Internal hash table helpers only

**Extensions add**:
- `Set.Ordered.Bounded.swift` — Bounded variant properties/operations
- `Set.Ordered.Algebra.swift` — Set algebra operations
- `Set.Ordered+Sequence.Consume.swift` — Iterator protocol
- `Set.Ordered+Memory.Contiguous.swift` — Span access

### swift-stack-primitives (follows pattern)

**Stack.swift** — Type body contains:
- `Storage` class (for ~Copyable, in body per exception)
- Stored properties
- `init()`

**Extensions add** all operations.

### swift-buffer-primitives (needs alignment)

Some types have methods in body that should be in extensions.

---

## Constraints

1. **[MEM-COPY-006]**: ~Copyable constraint poisoning requires nested types and conditional conformances in same file as declaration, often in type body
2. **[API-IMPL-005]**: One type per file — extensions of that type may be in same file or `Type+Protocol.swift` files
3. **Compiler behavior**: Separate-file conformances can poison ~Copyable generic parameters

---

## Outcome

**Status**: DECISION

**Decision**: Adopt Option C — Minimal type body with ~Copyable exception.

### Rule Statement

Type declarations MUST contain only:
1. Stored instance properties
2. The canonical initializer(s)

Everything else MUST be in extensions:
- Computed properties
- Methods
- Protocol conformances
- Static members
- Nested types (with exception below)

### Exception: ~Copyable Types

For types with `~Copyable` generic parameters, the following MAY be in the type body to avoid constraint poisoning per [MEM-COPY-006]:
- Nested storage types (e.g., `ManagedBuffer` subclasses)
- Nested types that reference the `~Copyable` parameter
- `deinit`

Conditional conformances (`Copyable where Element: Copyable`, `Sendable where Element: Sendable`) MUST be in the same file but SHOULD be in extensions after the type body.

### Rationale

1. **Scanability**: Opening a file immediately reveals the data layout
2. **Separation**: Storage is stable; behavior evolves
3. **Review**: Changes to behavior don't touch storage declarations
4. **Consistency**: Same pattern across all packages
5. **Pragmatism**: Exception accommodates known compiler limitations

### Implementation Path

1. Update `/code-organization` skill with new requirement [API-IMPL-008]
2. Audit packages for compliance (lower priority — fix during other work)
3. New code MUST follow pattern immediately

---

## References

- [MEM-COPY-006] ~Copyable Propagation Gotchas — **memory** skill
- [API-IMPL-005] One Type Per File — **code-organization** skill
- swift-set-primitives — Canonical example of pattern
- Swift Issue #86669 — Multi-file emit-module constraint poisoning
