# Generic Parameter Placement in Reference Semantics Primitives: A Comprehensive Analysis
<!--
---
version: 1.0.0
last_updated: 2026-01-17
status: DECISION
---
-->

**Technical Design Document**
**Version 2.0 — Final**
**Date: January 2026**

---

## Abstract

This paper presents a comprehensive analysis of generic parameter placement strategies for the `Reference` type family in Swift. We examine two competing designs: (1) namespace-based organization with per-type generics (`Reference.Box<T>`), and (2) outer-generic organization where the primary type carries the generic parameter (`Reference<T>`).

Through theoretical analysis, empirical usage measurement, and critical review, **we conclude that the namespace pattern (`enum Reference {}`) is the correct abstraction for this codebase.** The outer-generic pattern would require asserting that "immutable strong box is the canonical Reference" — a premise that is empirically false given actual usage patterns where `Indirect` (mutable) dominates `Box` (immutable) by a factor of 2.6×.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Background](#2-background)
3. [Current Design Analysis](#3-current-design-analysis)
4. [Alternative Design: Reference\<T\>](#4-alternative-design-referencet)
5. [The Constraint Propagation Problem](#5-the-constraint-propagation-problem)
6. [Empirical Usage Survey](#6-empirical-usage-survey)
7. [Critical Review](#7-critical-review)
8. [Sendable Policy](#8-sendable-policy)
9. [Naming Analysis](#9-naming-analysis)
10. [Final Recommendation](#10-final-recommendation)
11. [Appendices](#11-appendices)

---

## 1. Introduction

The design of generic type hierarchies in Swift requires careful consideration of where generic parameters are placed within the type structure. This decision has implications for API ergonomics, type inference behavior, constraint expressibility, and conceptual clarity.

The `Reference` module provides a family of primitives for reference semantics in Swift:

- Strong immutable references (boxing)
- Strong mutable references (indirection)
- Weak references
- Unowned references
- Atomic slot storage
- Ownership transfer mechanisms

This paper evaluates whether the generic parameter should be placed on `Reference` itself (`Reference<T>`) or on each nested type individually (`Reference.Box<T>`, `Reference.Indirect<T>`, etc.).

**Key finding:** The decision hinges on a single premise — whether "strong immutable box" is the canonical meaning of "Reference to T." Empirical measurement shows this premise is false for this codebase, therefore the namespace pattern is correct.

---

## 2. Background

### 2.1 Swift Generic Patterns

Swift supports two primary patterns for organizing generic type families:

**Outer-Generic Pattern (`Array<Element>`):**
```swift
public struct Array<Element> {
    // Array<Element> IS the usable type
}

extension Array {
    public struct Iterator: IteratorProtocol { ... }  // Uses Element
}
```

The outer type is the primary abstraction; nested types are derived/auxiliary.

**Namespace Pattern (`Unicode`):**
```swift
public enum Unicode {
    public struct Scalar { ... }
    public enum UTF8 { ... }
    public enum UTF16 { ... }
}
```

The enum groups heterogeneous peer types with different constraints/semantics.

### 2.2 Decision Rule

- **Outer-generic** works when the outer type is the primary abstraction and nested types are accessories.
- **Namespace** works when grouping heterogeneous peer types with different constraints/semantics.

---

## 3. Current Design Analysis

### 3.1 Architecture

The current design uses `Reference` as a namespace (caseless enum):

```swift
public enum Reference {}

extension Reference {
    public final class Box<Value: ~Copyable & Sendable>: @unchecked Sendable { ... }
    public final class Indirect<Value: ~Copyable> { ... }
    public struct Weak<Object: AnyObject>: Sendable where Object: Sendable { ... }
    public struct Unowned<Object: AnyObject>: @unchecked Sendable { ... }
    public final class Slot<Value: ~Copyable & Sendable>: @unchecked Sendable { ... }
    public enum Transfer { ... }
}
```

### 3.2 Type Inventory

| Type | Kind | Constraints | Sendable |
|------|------|-------------|----------|
| `Box<V>` | final class | `~Copyable & Sendable` | `@unchecked Sendable` |
| `Indirect<V>` | final class | `~Copyable` | Conditional (`where V: Sendable`) |
| `Weak<O>` | struct | `AnyObject` | `where O: Sendable` |
| `Unowned<O>` | struct | `AnyObject` | `@unchecked Sendable` |
| `Slot<V>` | final class | `~Copyable & Sendable` | `@unchecked Sendable` |

### 3.3 Constraint Heterogeneity

The types have incompatible constraint requirements:

| Constraint | Box | Indirect | Weak | Unowned | Slot |
|------------|-----|----------|------|---------|------|
| `~Copyable` | ✓ | ✓ | ✗ | ✗ | ✓ |
| `Sendable` | ✓ | ✗ | varies | ✗ | ✓ |
| `AnyObject` | ✗ | ✗ | ✓ | ✓ | ✗ |

This heterogeneity is a strong indicator that the namespace pattern is appropriate.

---

## 4. Alternative Design: Reference\<T\>

### 4.1 Proposed Transformation

Transform `Reference` from namespace to primary generic type:

```swift
public final class Reference<Value: ~Copyable> {
    public let value: Value
    public init(_ value: consuming Value) { ... }
}

extension Reference: @unchecked Sendable where Value: Sendable {}

extension Reference where Value: AnyObject {
    public struct Weak { ... }
    public struct Unowned { ... }
}

extension Reference {
    public final class Indirect { ... }
    public final class Slot where Value: Sendable { ... }
}
```

### 4.2 The Hidden Premise

This design requires accepting:

> **"Reference" means a strong, immutable, heap-allocated box. Mutability, weak ownership, and move semantics are capabilities added via nested types, not peer alternatives.**

If this premise is true, `Reference<T>` is defensible.
If this premise is false, the namespace pattern is correct.

---

## 5. The Constraint Propagation Problem

### 5.1 The Sendable Divergence

- **Box**: Requires `Value: Sendable` for Sendable conformance
- **Indirect**: Deliberately does **not** require `Value: Sendable`

The `Indirect` type's design enables boxing non-Sendable async iterators for closure capture. This is an intentional capability that must be preserved.

### 5.2 Resolution

If `Reference<T>` were adopted, it must use minimal constraints:

```swift
public final class Reference<Value: ~Copyable> { ... }
extension Reference: @unchecked Sendable where Value: Sendable {}
```

This preserves `Indirect`'s ability to wrap non-Sendable types.

---

## 6. Empirical Usage Survey

### 6.1 Methodology

Grep-based count of type occurrences across the workspace:

```bash
rg -c "Reference\.Box" --type swift
rg -c "Reference\.Indirect" --type swift
# ... etc
```

### 6.2 Results

| Type | Occurrences | Files |
|------|-------------|-------|
| `Reference.Box` | 8 | 4 |
| `Reference.Indirect` | 21 | 5 |
| `Reference.Weak` | 1 | 1 |
| `Reference.Unowned` | 1 | 1 |
| `Reference.Slot` | 13 | 2 |
| `Reference.Transfer` | 37 | 9 |

### 6.3 Analysis

- **Indirect (21) > Box (8)** — mutable references are used 2.6× more than immutable
- **Slot (13)** — atomic move semantics are non-trivial usage
- **Transfer (37)** — ownership transfer dominates surface usage
- **Weak/Unowned (1 each)** — negligible; ergonomic cost of `Reference<T>.Weak` is minimal

### 6.4 Conclusion

**The premise "immutable strong box is canonical" is empirically false for this codebase.**

`Indirect` is the workhorse, not `Box`. The types are genuine peers serving different use cases, not a hierarchy rooted at "immutable box."

---

## 7. Critical Review

### 7.1 Two-Axis Structure

The types vary on two orthogonal axes:

|  | Immutable | Mutable | Move/Take |
|--|-----------|---------|-----------|
| **Strong** | `Box` | `Indirect` | `Slot` |
| **Weak** | — | `Weak` | — |
| **Unowned** | `Unowned` | — | — |

This is a matrix, not a tree rooted at "strong immutable." The namespace pattern correctly represents this structure.

### 7.2 Type Inference Regression

With `Reference<T>`, nested types lose inference from constructor arguments:

```swift
// Current: infers T from argument
let weak = Reference.Weak(obj)

// With Reference<T>: requires explicit T
let weak = Reference<MyClass>.Weak(obj)
```

Given that `Weak`/`Unowned` are rarely used (1 occurrence each), this cost is acceptable. However, it's still a regression with no offsetting benefit since the premise doesn't hold.

### 7.3 Ergonomic Benefit Is Minimal

The motivation for `Reference<T>` was shorter syntax:

```swift
Reference(value)      // vs
Reference.Box(value)
```

This saves 4 characters. The structural and migration cost far exceeds this benefit.

---

## 8. Sendable Policy

### 8.1 Current Design (Correct)

- `Reference.Indirect` is **conditionally Sendable** (`where Value: Sendable`)
- `Reference.Indirect.Unchecked` is **explicit opt-in** for unsafe cross-boundary capture

This is the correct pattern: conservative defaults with explicit unsafe escape hatches.

### 8.2 Policy Rule

**No general-purpose mutable reference wrapper in this module will be unconditionally `@unchecked Sendable` unless it provides synchronization or actor isolation by construction.**

Only explicitly-unsafe types (named `Unchecked` or `Unsafe`) may bypass Sendable checking for mutable shared state.

### 8.3 Async Iterator Helper

The async iterator extension on `Reference.Indirect.Unchecked` is acceptable but must be documented as:

- **Single-consumer only**
- **NOT thread-safe**
- **Do not capture in multiple concurrent tasks**

Alternatively, keep the helper local to `swift-async` rather than exposing it as a general primitive.

---

## 9. Naming Analysis

### 9.1 Should Box Be Renamed to Strong?

**No.** `Strong` doesn't distinguish `Box` from `Indirect` — both are strong references. The distinction is mutability:

| Type | Ownership | Mutability |
|------|-----------|------------|
| `Box` | Strong | Immutable |
| `Indirect` | Strong | Mutable |
| `Weak` | Weak | — |
| `Unowned` | Unowned | — |

### 9.2 Should Indirect Be Renamed?

`Indirect` describes mechanism (indirection), not the distinguishing property (mutability). More semantically precise alternatives:

| Current | Alternative | Rationale |
|---------|-------------|-----------|
| `Indirect` | `Cell` | Rust terminology; interior mutability |
| `Indirect` | `Mutable` | Explicit about distinction |
| `Indirect` | `Var` | Swift idiom (`let`/`var`) |

### 9.3 Recommendation

**Keep `Box` and `Indirect` for now.**

- `Box` is established (Rust, Haskell, functional programming)
- `Indirect` mirrors Swift's `indirect` keyword
- `Cell`/`Var` import foreign semantics or read as keywords
- Rename only as part of a deliberate repo-wide vocabulary pass, not opportunistically

---

## 10. Final Recommendation

### 10.1 Generic Placement

**Keep `enum Reference {}` as namespace.**

The empirical data settles the question: `Indirect` is the workhorse, not `Box`. The types are genuine peers, not a hierarchy. The namespace pattern correctly represents this structure.

### 10.2 Sendable Policy

Enforce the rule: **unchecked Sendable only on explicit Unsafe/Unchecked types.**

Current design already follows this pattern with `Reference.Indirect.Unchecked`.

### 10.3 Naming

**Keep `Box` and `Indirect`.** Do not rename opportunistically.

### 10.4 Async Iterator Helper

Keep local to `swift-async` with explicit single-consumer documentation, or remove entirely.

### 10.5 Summary Table

| Decision | Outcome |
|----------|---------|
| Generic placement | **Namespace** (`enum Reference {}`) |
| Rename Box → Strong | **No** |
| Rename Indirect → Cell/Var | **No** |
| Sendable policy | Enforce: unchecked only on Unsafe/Unchecked types |
| Async iterator helper | Document as single-consumer or keep local to swift-async |

---

## 11. Appendices

### Appendix A: Module Documentation

```swift
/// Reference Primitives
///
/// This module provides a family of reference semantics primitives for Swift.
/// Each type offers a distinct ownership, mutability, or concurrency contract.
/// Choose the type whose contract matches your use case.
///
/// ## Types
///
/// | Type | Ownership | Mutability | Sendable |
/// |------|-----------|------------|----------|
/// | `Reference.Box` | Strong | Immutable | When `Value: Sendable` |
/// | `Reference.Indirect` | Strong | Mutable | When `Value: Sendable` |
/// | `Reference.Weak` | Weak | N/A | When `Object: Sendable` |
/// | `Reference.Unowned` | Unowned | N/A | `@unchecked` |
/// | `Reference.Slot` | Strong | Move semantics | `@unchecked` |
/// | `Reference.Transfer` | One-shot | Move-only | Sendable |
///
/// ## Design Philosophy
///
/// This module provides capabilities with distinct ownership/mutability/transfer
/// contracts. There is no single default; choose by contract:
///
/// - Need immutable heap storage? → `Reference.Box`
/// - Need mutable shared state? → `Reference.Indirect`
/// - Need weak back-references? → `Reference.Weak`
/// - Need atomic move semantics? → `Reference.Slot`
/// - Need cross-boundary ownership transfer? → `Reference.Transfer`
///
/// ## Sendable Policy
///
/// Default wrapper types are Sendable only when their payload is Sendable.
/// Only explicitly-unsafe types (named `Unchecked` or `Unsafe`) may be
/// `@unchecked Sendable` for mutable shared state. This prevents
/// "just add unchecked Sendable to make it compile" regressions.
public enum Reference {}
```

### Appendix B: Empirical Data Collection Commands

```bash
# Count occurrences
rg -c "Reference\.Box" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
rg -c "Reference\.Indirect" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
rg -c "Reference\.Weak" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
rg -c "Reference\.Unowned" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
rg -c "Reference\.Slot" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
rg -c "Reference\.Transfer" --type swift 2>/dev/null | awk -F: '{sum += $2} END {print sum}'
```

### Appendix C: Type Hierarchy Diagram

```
Reference (enum namespace)
├── Box<Value: ~Copyable & Sendable>
│   └── @unchecked Sendable
├── Indirect<Value: ~Copyable>
│   ├── Sendable where Value: Sendable
│   └── .Unchecked (@unchecked Sendable, explicit opt-in)
├── Weak<Object: AnyObject>
│   └── Sendable where Object: Sendable
├── Unowned<Object: AnyObject>
│   └── @unchecked Sendable
├── Slot<Value: ~Copyable & Sendable>
│   └── @unchecked Sendable
└── Transfer (namespace)
    ├── Cell<Value: ~Copyable & Sendable>
    ├── Storage<Value: ~Copyable & Sendable>
    ├── Retained<Object: AnyObject & Sendable>
    └── Box (type-erased)
```

---

**Document Control:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | January 2026 | Engineering | Initial analysis recommending `Reference<T>` |
| 2.0 | January 2026 | Engineering | **Revised after empirical measurement and critical review. Final recommendation: keep namespace pattern.** |

---

*End of Document*
