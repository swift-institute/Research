# Primitives Conversion Anti-Patterns

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: DECISION
---
-->

## Context

AI agents writing implementations and tests for packages using primitives frequently produce multi-layer type conversions (e.g., `Int(bitPattern: index.position.rawValue)`) where clean API calls should be used. This creates verbose, fragile code that obscures intent.

**Trigger**: Storage-primitives tests contain widespread `.rawValue` chain patterns where direct APIs exist.

**Scope**: Primitives-wide — affects any package consuming index-primitives, ordinal-primitives, cardinal-primitives, memory-primitives, or their dependents.

## Question

Where should `.rawValue` access occur, and what patterns should call-sites use instead?

## Analysis

### Core Design Principle

**`.rawValue` access belongs exclusively in extension initializers.**

The primitives architecture provides a layered type system:
```
Index<T> = Tagged<T, Ordinal>
Ordinal.rawValue: UInt
```

To convert between layers, packages define extension initializers that encapsulate the unwrapping:

```swift
// In Ordinal Primitives — hides .rawValue access
extension Int {
    public init(bitPattern position: Ordinal) {
        self = Int(bitPattern: position.rawValue)  // ✓ .rawValue here
    }
}

// In Tagged+Ordinal — delegates to Ordinal extension
extension Int {
    public init<Tag: ~Copyable>(bitPattern position: Tagged<Tag, Ordinal>) {
        self = Int(bitPattern: position.rawValue)  // Delegates to Ordinal version
    }
}
```

**Call-sites pass higher types directly**:
```swift
// ✓ CORRECT: Clean call-site
let i = Int(bitPattern: index)

// ❌ WRONG: Manually unwrapping at call-site
let i = Int(bitPattern: index.position.rawValue)
```

### Test Support Architecture

Test Support modules form a dependency chain that propagates literal conformances:

```
Identity Primitives Test Support (SOURCE)
    ↓ provides ExpressibleByIntegerLiteral for Tagged
Cardinal Primitives Test Support
    ↓ re-exports Cardinal
Ordinal Primitives Test Support
    ↓ re-exports Cardinal Test Support
Affine Primitives Test Support
    ↓ re-exports Ordinal + Cardinal Test Support
Index Primitives Test Support (HUB)
    ↓ re-exports Identity + Ordinal + Cardinal + Affine Test Support
Pointer Primitives Test Support
    ↓ re-exports Index Test Support
Storage Primitives Test Support
    ↓ re-exports Index + Pointer Test Support
```

**Single Source**: `Identity_Primitives_Test_Support` provides all literal conformances:

```swift
// Identity Primitives Test Support — the ONLY source
extension Tagged: ExpressibleByIntegerLiteral
where Tag: ~Copyable, RawValue: ExpressibleByIntegerLiteral {
    @_disfavoredOverload
    public init(integerLiteral value: RawValue.IntegerLiteralType) {
        self = .init(__unchecked: (), RawValue(integerLiteral: value))
    }
}
// Also: ExpressibleByFloatLiteral, ExpressibleByStringLiteral, etc.
```

**Hub Pattern**: `Index_Primitives_Test_Support` re-exports all upstream Test Support, making it available to all higher packages.

**Implication**: Any package importing its own Test Support already has `ExpressibleByIntegerLiteral` for:
- `Index<T>` (via `Tagged<T, Ordinal>` + `Ordinal: ExpressibleByIntegerLiteral`)
- `Index<T>.Offset` (via `Tagged<T, Affine.Discrete.Vector>`)
- `Index<T>.Count` (via `Tagged<T, Cardinal>`)
- `Cardinal`, `Ordinal` directly

This enables test convenience:
```swift
let index: Index<Int> = 5           // Via Test Support literal conformance
let offset: Index<Int>.Offset = -3  // Via Test Support literal conformance
#expect(index == 5)                 // Comparison via literal
```

**Critical**: Storage-primitives tests import `Storage_Primitives_Test_Support`, which re-exports `Index_Primitives_Test_Support`. The literal conformances are **already available** — the anti-patterns are using `.rawValue` chains when literals would work.

**Note**: These are `@_disfavoredOverload` and documented as "bypasses domain-specific validation" — test convenience only, not production code.

### Anti-Pattern Categories

#### 1. Multi-Layer rawValue Chains

**Anti-Pattern**:
```swift
// ❌ WRONG: Chain of .rawValue/.position accesses at call-site
Int(bitPattern: index.position.rawValue)
address.rawValue.rawValue
index.position.rawValue * 5
```

**Root Cause**: AI agents don't recognize that extension inits exist for these conversions.

**Correct Pattern**:
```swift
// ✓ CORRECT: Use extension init
Int(bitPattern: index)

// ✓ CORRECT: If Int needed, use direct API
try Int(index)
Int(exactly: index)
```

#### 2. Index-Derived Test Values

**Anti-Pattern**:
```swift
// ❌ WRONG: Converting index to compute test values
storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)
#expect(value == Int(bitPattern: index.position.rawValue) * 10)
```

**Correct Pattern**: Use external counter or leverage literal conformance.
```swift
// ✓ CORRECT: External counter
var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}

// ✓ CORRECT: Verify against counter
var i = 0
(.zero..<count).forEach { index in
    #expect(storage.move(at: index) == i * 10)
    i += 1
}
```

#### 3. Position Access for Comparison

**Anti-Pattern**:
```swift
// ❌ WRONG: Unwrapping for comparison
#expect(next.position.rawValue == 1)
index.position.rawValue == 5
```

**Correct Pattern**: Use literal conformance or semantic comparison.
```swift
// ✓ CORRECT: Via Test Support literal conformance
#expect(next == 1)
#expect(index.position == 5)

// ✓ CORRECT: Explicit construction
#expect(next == try Index(1))
```

### Where .rawValue IS Appropriate

`.rawValue` access is justified **only** in:

1. **Extension initializers** (the designated location):
   ```swift
   extension Int {
       public init(bitPattern position: Ordinal) {
           self = Int(bitPattern: position.rawValue)  // ✓
       }
   }
   ```

2. **Primitives package implementations** (same package that defines the type):
   ```swift
   // In Memory.Address implementation
   extension UnsafeRawPointer {
       public init(_ address: Memory.Address) {
           unsafe self = UnsafeRawPointer(bitPattern: address.rawValue.rawValue)!
       }
   }
   ```

3. **Bit-pattern verification tests within the defining package**:
   ```swift
   // In Memory Primitives Tests — testing Memory.Address arithmetic
   #expect(advanced.rawValue.rawValue == base.rawValue.rawValue &+ 3)
   ```

**Never** in:
- Higher-layer package tests (e.g., storage-primitives testing should not access memory-primitives internals)
- Application code
- Test value computation

### Available Extension APIs

#### Index<T> / Tagged<Tag, Ordinal>

| Conversion | API | Notes |
|------------|-----|-------|
| `Index<T>` → `Int` (unchecked) | `Int(bitPattern: index)` | Bit reinterpret |
| `Index<T>` → `Int` (throwing) | `try Int(index)` | Throws if > Int.max |
| `Index<T>` → `Int` (optional) | `Int(exactly: index)` | nil if > Int.max |
| `Index<T>` → `Ordinal` | `.position` | Direct property |
| `Int` → `Index<T>` (throwing) | `try Index(int)` | Throws if negative |
| Literal → `Index<T>` | `let i: Index<T> = 5` | Test Support only |

#### Cardinal / Index<T>.Count

| Conversion | API | Notes |
|------------|-----|-------|
| `Cardinal` → `Int` (unchecked) | `Int(bitPattern: cardinal)` | |
| `Cardinal` → `Int` (throwing) | `try Int(cardinal)` | |
| `Int` → `Cardinal` (throwing) | `try Cardinal(int)` | Throws if negative |
| Literal → `Cardinal` | `let c: Cardinal = 5` | Via literal conformance |

### Comparison: Correct vs Incorrect

#### Storage Tests (INCORRECT)
```swift
// From Storage.Inline Tests.swift — anti-pattern
(.zero..<count).forEach { index in
    storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)
}
(.zero..<count).reversed().forEach { index in
    #expect(value == Int(bitPattern: index.position.rawValue) * 10)
}
```

#### Pointer Tests (CORRECT)
```swift
// From Pointer Arithmetic Tests.swift — correct pattern
var i = 0
(.zero..<count).forEach { idx in
    ptr[idx] = i * 10
    i += 1
}
```

#### Index Tests (CORRECT)
```swift
// From Index Tests.swift — leveraging literal conformance
let index: Index<Int> = try Index(5)
#expect(index.position == 5)  // Compare Ordinal to literal

// From Index.Offset Tests.swift
let offset: Index<IntTag>.Offset = 5
#expect(offset == 5)  // Literal comparison
```

## Outcome

**Status**: DECISION

### Conventions

#### [CONV-001] rawValue Access Location

**Statement**: `.rawValue` access MUST be confined to extension initializers and same-package implementations. Call-sites MUST use the extension APIs.

| Instead of | Use |
|------------|-----|
| `Int(bitPattern: index.position.rawValue)` | `Int(bitPattern: index)` |
| `index.position.rawValue * 5` | External counter or computed value |
| `address.rawValue.rawValue` | Extension-provided conversions |

#### [CONV-002] Test Value Computation

**Statement**: Tests MUST NOT derive values from index/ordinal conversions. Use external counters.

```swift
// ❌ Anti-pattern
storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)

// ✓ Correct
var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}
```

#### [CONV-003] Literal Conformance in Tests

**Statement**: Tests SHOULD leverage `ExpressibleByIntegerLiteral` from Test Support for construction and comparison.

```swift
let index: Index<Int> = 5      // ✓ Test Support literal
#expect(index == 5)            // ✓ Literal comparison
#expect(offset == -3)          // ✓ Literal comparison
```

#### [CONV-004] Cross-Package Boundary

**Statement**: A package's tests SHOULD NOT access `.rawValue` of types from dependency packages. Use the semantic APIs those packages export.

| Package Under Test | Should NOT access |
|--------------------|-------------------|
| storage-primitives | `index.position.rawValue` (from ordinal-primitives) |
| pointer-primitives | `address.rawValue.rawValue` (from memory-primitives) |

### Packages Requiring Remediation

| Package | Issue | Instances |
|---------|-------|-----------|
| swift-storage-primitives | `Int(bitPattern: index.position.rawValue)` | ~20+ |
| swift-cyclic-primitives | `.rawValue.rawValue` comparisons | ~15+ |
| swift-bit-primitives | `.rawValue.rawValue` in location tests | ~10+ |

### Packages Demonstrating Correct Patterns

| Package | Pattern |
|---------|---------|
| swift-pointer-primitives | External counters, semantic comparisons |
| swift-index-primitives | Literal conformance, `.position` comparisons |
| swift-memory-primitives | `.rawValue` only in same-package implementation tests |

### Test Support Target Inventory

| Package | Test Support Target | Provides | Re-exports |
|---------|--------------------|---------|-----------|
| swift-identity-primitives | Identity Primitives Test Support | All literal conformances for Tagged | — |
| swift-cardinal-primitives | Cardinal Primitives Test Support | — | Cardinal_Primitives |
| swift-ordinal-primitives | Ordinal Primitives Test Support | — | Cardinal Test Support |
| swift-affine-primitives | Affine Primitives Test Support | — | Ordinal + Cardinal Test Support |
| swift-index-primitives | Index Primitives Test Support | — | Identity + Ordinal + Cardinal + Affine Test Support |
| swift-range-primitives | Range Primitives Test Support | — | Index Test Support |
| swift-pointer-primitives | Pointer Primitives Test Support | — | Index Test Support |
| swift-memory-primitives | Memory Primitives Test Support | — | Index + Range + Ordinal + Cardinal + Affine + Identity Test Support |
| swift-storage-primitives | Storage Primitives Test Support | — | Pointer + Index Test Support |
| swift-cyclic-primitives | Cyclic Primitives Test Support | — | (check) |
| swift-kernel-primitives | Kernel Primitives Test Support | — | (check) |

**Key Insight**: Every package's Test Support has access to literal conformances via the re-export chain. The anti-patterns are inexcusable — the affordances are available but unused.

## References

- `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift` — Extension init APIs
- `/Users/coen/Developer/swift-primitives/swift-identity-primitives/Tests/Support/Identity Primitives Test Support.swift` — Literal conformances
- `/Users/coen/Developer/swift-primitives/swift-pointer-primitives/Tests/Pointer Primitives Tests/Pointer Arithmetic Tests.swift` — Correct test patterns
- `/Users/coen/Developer/swift-primitives/swift-storage-primitives/Tests/Storage Primitives Tests/Storage.Inline Tests.swift` — Anti-pattern examples
