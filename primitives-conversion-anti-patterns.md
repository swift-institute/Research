# Primitives Conversion Anti-Patterns

<!--
---
version: 1.2.0
last_updated: 2026-03-10
status: SUPERSEDED
changelog:
  - 1.2.0: SUPERSEDED by implementation skill [IMPL-*]
  - 1.1.0: Added section on intermediate property access (.position) anti-patterns
  - 1.0.0: Initial research on .rawValue chain anti-patterns
---
-->

## Context

AI agents writing implementations and tests for packages using primitives frequently produce multi-layer type conversions (e.g., `Int(bitPattern: index.position.rawValue)`) where clean API calls should be used. This creates verbose, fragile code that obscures intent.

**Trigger**: Storage-primitives tests contain widespread `.rawValue` chain patterns where direct APIs exist.

**Scope**: Primitives-wide — affects any package consuming index-primitives, ordinal-primitives, cardinal-primitives, memory-primitives, cyclic-primitives, or their dependents.

## Question

Where should `.rawValue` and `.position` access occur, and what patterns should call-sites use instead?

## Analysis

### Core Design Principle

**`.rawValue` and intermediate property access (`.position`) belong exclusively in extension initializers and same-package implementations.**

The primitives architecture provides a layered type system:
```
Index<T> = Tagged<T, Ordinal>
Ordinal.rawValue: UInt

Index<T>.Cyclic<N> = Tagged<T, Cyclic.Group<N>.Element>
Cyclic.Group<N>.Element.position: Ordinal
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

### Intermediate Property Access is Also an Anti-Pattern

**New Analysis (v1.1.0)**: After the Cyclic.Group refactoring to use `position: Ordinal`, a subtler anti-pattern emerged: accessing intermediate properties like `.position` at call-sites, even without chaining to `.rawValue`.

The principle extends: **every layer boundary should be crossed via extension initializers, not property access at call-sites**.

#### The Anti-Pattern Hierarchy

| Pattern | Severity | Location |
|---------|----------|----------|
| `index.position.rawValue` | Severe | Never at call-sites |
| `element.position.rawValue` | Severe | Never at call-sites |
| `cyclicIndex.rawValue.position` | Severe | Never at call-sites |
| `index.rawValue` (for comparison) | Moderate | Never at call-sites — use `index == literal` |
| `cyclicIndex.rawValue` (for comparison) | Moderate | Never at call-sites — use `cyclicIndex == literal` |
| `index.position` | Moderate | Only in extension inits or same-package |
| `element.position` | Moderate | Only in extension inits or same-package |

#### Why `.position` Access Is Also Wrong at Call-Sites

Consider `Cyclic.Group<N>.Element`:

```swift
// ❌ WRONG at call-site — crosses layer boundary
#expect(element.position == 3)

// ✓ CORRECT — uses literal conformance via Test Support
#expect(element == 3)
```

The reasoning:
1. `.position` is an implementation detail of how `Cyclic.Group.Element` stores its value
2. Future refactoring might change this representation
3. Test Support provides `ExpressibleByIntegerLiteral` specifically to avoid this
4. Call-sites should use the semantic type, not peek at its internals

#### Justified vs Unjustified Access

| Access Pattern | At Extension Init | At Same-Package Impl | At Higher-Layer Test | At Call-Site |
|----------------|-------------------|---------------------|---------------------|--------------|
| `.rawValue` | ✓ Yes | ✓ Yes | ✗ Never | ✗ Never |
| `.position` | ✓ Yes | ✓ Yes | ✗ Never | ✗ Never |
| `.position.rawValue` | ✓ Rarely | ✗ Avoid | ✗ Never | ✗ Never |

**"Same-package implementation"** means:
- `Cyclic Primitives` accessing `Cyclic.Group.Element.position` in arithmetic implementations
- `Ordinal Primitives` accessing `Ordinal.rawValue` in extension inits
- NOT: `Cyclic Index Primitives` accessing `Cyclic.Group.Element.position` (that's a higher-layer package)

**"Extension init"** means conversion APIs like:
```swift
extension Ordinal {
    public init<let N: Int>(_ element: Cyclic.Group<N>.Element) {
        self = element.position  // ✓ .position access justified here
    }
}
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
Cyclic Primitives Test Support
    ↓ provides ExpressibleByIntegerLiteral for Cyclic.Group.Element
Pointer Primitives Test Support
    ↓ re-exports Index Test Support
Storage Primitives Test Support
    ↓ re-exports Index + Pointer Test Support
```

**Single Source**: `Identity_Primitives_Test_Support` provides all literal conformances for Tagged types.

**Cyclic Extension**: `Cyclic_Primitives_Test_Support` provides literal conformance for `Cyclic.Group.Element`:

```swift
extension Cyclic.Group.Element: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = try! Self(Ordinal(UInt(value)))
    }
}
```

**Implication**: Any package importing Test Support already has literal conformances. The anti-patterns are using property access when literals would work.

### Anti-Pattern Categories

#### 1. Multi-Layer rawValue Chains

**Anti-Pattern**:
```swift
// ❌ WRONG: Chain of .rawValue/.position accesses at call-site
Int(bitPattern: index.position.rawValue)
element.position.rawValue
index.position.rawValue * 5
```

**Correct Pattern**:
```swift
// ✓ CORRECT: Use extension init
Int(bitPattern: index)

// ✓ CORRECT: If Int needed, use direct API
try Int(index)
Int(exactly: index)
```

#### 2. Single-Level Property Access

**Anti-Pattern**:
```swift
// ❌ WRONG: Intermediate property access at call-site
#expect(element.position == 3)
#expect(index.rawValue.position == 3)
```

**Correct Pattern**:
```swift
// ✓ CORRECT: Via Test Support literal conformance
#expect(element == 3)
#expect(index.rawValue == 3)  // if rawValue is the semantic type (e.g., Cyclic.Group.Element)
```

#### 3. Index-Derived Test Values

**Anti-Pattern**:
```swift
// ❌ WRONG: Converting index to compute test values
storage.initialize(to: Int(bitPattern: index.position.rawValue) * 10, at: index)
#expect(value == Int(bitPattern: index.position.rawValue) * 10)
```

**Correct Pattern**: Use external counter.
```swift
// ✓ CORRECT: External counter
var i = 0
(.zero..<count).forEach { index in
    storage.initialize(to: i * 10, at: index)
    i += 1
}
```

#### 4. Position Access for Cyclic Elements

**Anti-Pattern**:
```swift
// ❌ WRONG: Accessing .position to compare
#expect(cyclicElement.position == 5)
#expect(cyclicIndex.rawValue.position == 5)
```

**Correct Pattern**:
```swift
// ✓ CORRECT: Use literal conformance
#expect(cyclicElement == 5)
#expect(cyclicIndex.rawValue == 5)  // rawValue is Cyclic.Group.Element, compare to literal
```

### Where Property Access IS Appropriate

Property access (`.rawValue`, `.position`) is justified **only** in:

1. **Extension initializers** (the designated location):
   ```swift
   extension Ordinal {
       public init<let N: Int>(_ element: Cyclic.Group<N>.Element) {
           self = element.position  // ✓
       }
   }
   ```

2. **Same-package implementations**:
   ```swift
   // In Cyclic.Group+Arithmetic.swift (same package)
   public static func + (lhs: Self, rhs: Self) -> Self {
       let sum = lhs.position + Cardinal(rhs.position)  // ✓
       // ...
   }
   ```

3. **Bit-pattern verification tests within the defining package**:
   ```swift
   // In Cyclic Primitives Tests — testing Element internals
   let element = try Cyclic.Group<5>.Element(Ordinal(3))
   #expect(element.position == 3)  // ✓ Same-package, verifying internals
   ```

**Never** in:
- Higher-layer package tests (e.g., cyclic-index-primitives should not access cyclic-primitives internals)
- Application code
- Test value computation

### Special Case: Index<T>.Cyclic<N>

For `Index<T>.Cyclic<N>` (which is `Tagged<T, Cyclic.Group<N>.Element>`):

| Access | Level | Justified At Call-Site |
|--------|-------|----------------------|
| Direct comparison | `Index<T>.Cyclic<N>` | ✓ Yes — semantic type |
| `index.rawValue` | Cyclic.Group.Element | ✗ No — internal |
| `index.rawValue.position` | Ordinal | ✗ No — internal |
| `index.rawValue.position.rawValue` | UInt | ✗ Never |

The correct pattern for comparisons:
```swift
// ✓ CORRECT: Compare Tagged index directly to literal
#expect(cyclicIndex == 3)

// ❌ WRONG: Access rawValue for comparison
#expect(cyclicIndex.rawValue == 3)

// ❌ WRONG: Peek at position
#expect(cyclicIndex.rawValue.position == 3)
```

**Key insight**: Test Support provides `ExpressibleByIntegerLiteral` for `Tagged<T, RawValue>` when `RawValue: ExpressibleByIntegerLiteral`. This means `Index<T>.Cyclic<N>` can be compared directly to integer literals — no `.rawValue` access needed.

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: **implementation** skill [IMPL-*] (absorbed into skill)
This research was absorbed into the implementation skill. It remains as historical rationale.

**Previous Status**: DECISION

### Conventions

#### [CONV-001] rawValue Access Location

**Statement**: `.rawValue` access MUST be confined to extension initializers and same-package implementations. Call-sites MUST use the extension APIs.

| Instead of | Use |
|------------|-----|
| `Int(bitPattern: index.position.rawValue)` | `Int(bitPattern: index)` |
| `index.position.rawValue * 5` | External counter or computed value |
| `address.rawValue.rawValue` | Extension-provided conversions |

#### [CONV-001a] Intermediate Property Access Location

**Statement**: Intermediate property access (`.position`, `.rawValue`) MUST be confined to extension initializers and same-package implementations. Higher-layer packages and call-sites MUST compare at the semantic type level using literal conformances.

| Instead of | Use |
|------------|-----|
| `element.position == 3` | `element == 3` (literal) |
| `index.rawValue == 3` | `index == 3` (literal) |
| `cyclicIndex.rawValue == 3` | `cyclicIndex == 3` (literal) |
| `cyclicIndex.rawValue.position == 3` | `cyclicIndex == 3` (literal) |

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
#expect(cyclicElement == 3)    // ✓ Literal comparison
```

#### [CONV-004] Cross-Package Boundary

**Statement**: A package's tests SHOULD NOT access `.rawValue` or `.position` of types from dependency packages. Use the semantic APIs those packages export.

| Package Under Test | Should NOT access |
|--------------------|-------------------|
| storage-primitives | `index.position.rawValue` (from ordinal-primitives) |
| pointer-primitives | `address.rawValue.rawValue` (from memory-primitives) |
| cyclic-index-primitives | `element.position` (from cyclic-primitives) |

### Packages Requiring Remediation

| Package | Issue | Instances |
|---------|-------|-----------|
| swift-storage-primitives | `Int(bitPattern: index.position.rawValue)` | ~20+ |
| swift-cyclic-index-primitives | `.rawValue.position` comparisons | Updated in v1.1.0 |
| swift-bit-primitives | `.rawValue.rawValue` in location tests | ~10+ |

### Packages Demonstrating Correct Patterns

| Package | Pattern |
|---------|---------|
| swift-pointer-primitives | External counters, semantic comparisons |
| swift-index-primitives | Literal conformance, `.position` comparisons (same-package) |
| swift-cyclic-primitives | `.position` in same-package only, literal comparisons in tests |
| swift-memory-primitives | `.rawValue` only in same-package implementation tests |

## References

- `/Users/coen/Developer/swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives/Tagged+Ordinal.swift` — Extension init APIs
- `/Users/coen/Developer/swift-primitives/swift-identity-primitives/Tests/Support/Identity Primitives Test Support.swift` — Literal conformances
- `/Users/coen/Developer/swift-primitives/swift-cyclic-primitives/Tests/Support/Cyclic.Group.Element+Literals.swift` — Cyclic literal conformance
- `/Users/coen/Developer/swift-primitives/swift-pointer-primitives/Tests/Pointer Primitives Tests/Pointer Arithmetic Tests.swift` — Correct test patterns
