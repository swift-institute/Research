# Lifetime-Dependent Borrowed Cursors in Swift: A Comprehensive Analysis of Non-Escapable Types, Closure Integration Gaps, and the Non-Closure Runner Surface

**A Technical Research Paper on Safe Zero-Copy Parsing APIs**

---

## Abstract

This paper presents a comprehensive analysis of Swift's non-escapable type system (`~Escapable`), lifetime dependency annotations (`@_lifetime`), and their integration with higher-order functions. We examine the fundamental tension between closure-based APIs and non-escapable values, demonstrating why the closure integration gap exists in Swift 6.2.

The key finding is that if `Input.View` is `~Escapable`, then some non-closure, non-associated-type dispatch mechanism is **structurally required** by Swift 6.x—this is not a stylistic choice but a language constraint. We propose the non-closure runner surface (expressed as a protocol with a `parse` method) as the canonical solution for borrowed cursor types.

Through detailed analysis of Swift Evolution proposals (SE-0446, SE-0447, SE-0456, SE-0474), existing parsing infrastructure, and standard library patterns, we establish that this approach is not a workaround but the currently semantically correct public API design for lifetime-dependent borrowed cursors. We also present two strategies for preserving combinator reuse across the owned and borrowed worlds: bridge layers and defunctionalized machine execution.

---

## Table of Contents

1. [Introduction: The Problem Space](#1-introduction-the-problem-space)
2. [Theoretical Foundations: Swift's Ownership and Lifetime System](#2-theoretical-foundations-swifts-ownership-and-lifetime-system)
3. [SE-0446: Non-Escapable Types](#3-se-0446-non-escapable-types)
4. [SE-0447: Span and Safe Contiguous Access](#4-se-0447-span-and-safe-contiguous-access)
5. [The Closure Integration Gap: A Detailed Analysis](#5-the-closure-integration-gap-a-detailed-analysis)
6. [Anti-Pattern: The Immortal Pointer Escape Hatch](#6-anti-pattern-the-immortal-pointer-escape-hatch)
7. [The Non-Closure Runner Surface: Canonical Solution](#7-the-non-closure-runner-surface-canonical-solution)
8. [Existing Parsing Infrastructure Analysis](#8-existing-parsing-infrastructure-analysis)
9. [Implementation Design](#9-implementation-design)
10. [Standard Library Precedents](#10-standard-library-precedents)
11. [Future Directions](#11-future-directions)
12. [Conclusion](#12-conclusion)
13. [References](#13-references)

---

## 1. Introduction: The Problem Space

### 1.1 The Zero-Copy Parsing Imperative

Modern systems programming demands zero-copy parsing: the ability to process binary data without materializing intermediate copies. This requirement is driven by:

1. **Memory bandwidth constraints** - Copying data is often the bottleneck
2. **Latency requirements** - Memory allocation introduces unpredictable pauses
3. **Resource-constrained environments** - Embedded systems cannot afford copies
4. **Protocol processing** - Network packets must be parsed in-place

Traditional Swift APIs for borrowed access use closure-based patterns:

```swift
bytes.withUnsafeBufferPointer { buffer in
    // Process buffer here
    // buffer is only valid within this scope
}
```

This pattern has a critical safety gap: the compiler provides **no guarantee** that the buffer pointer doesn't escape the closure. It is merely a runtime contract.

### 1.2 The Vision: Compiler-Enforced Lifetime Safety

Swift 6.2 introduces the machinery for compiler-enforced lifetime safety through:

- **`~Escapable` types**: Values that cannot escape their lexical scope
- **`Span<T>`**: A non-escapable view into contiguous memory
- **`@_lifetime` annotations**: Explicit lifetime dependency declarations

The ideal API would look like:

```swift
Binary.Bytes.withBorrowed(data) { view in
    let header = view.parseUInt32(.big)
    let length = view.parseUInt16(.big)
    // view cannot escape this closure
}
```

Where `view` is a `Binary.Bytes.Input.View` that:
- Stores `Span<UInt8>` (not raw pointer)
- Is `~Escapable` (cannot be stored or returned)
- Is `~Copyable` (prevents aliasing bugs)
- Is NOT `Sendable` (cannot cross task boundaries)

### 1.3 The Problem: Closure Integration Gap

When we attempt to implement this API:

```swift
public static func withBorrowed<T, E: Swift.Error>(
    _ bytes: [UInt8],
    _ body: (inout Input.View) throws(E) -> T
) throws(E) -> T {
    var view = Input.View(bytes.span)  // view depends on bytes.span
    return try body(&view)             // ❌ COMPILER ERROR
}
```

The Swift 6.2 compiler produces:

```
error: lifetime-dependent variable 'view' escapes its scope
21 |         var view = Input.View(bytes.span)
   |             |                       `- note: it depends on the lifetime of this parent value
   |             `- error: lifetime-dependent variable 'view' escapes its scope
22 |         return try body(&view)
   |                    `- note: this use of the lifetime-dependent value is out of scope
```

This paper explains why this occurs and demonstrates the correct solution.

---

## 2. Theoretical Foundations: Swift's Ownership and Lifetime System

### 2.1 The Escapable Capability

Prior to Swift 6, all types in Swift implicitly possessed an **Escapable capability**—the ability to exist beyond their immediate lexical scope. A value is **escapable** if it can:

1. Be assigned to a global or static variable
2. Be returned from a function
3. Be captured by an escaping closure
4. Be stored in any data structure

Note: Escapability is not modeled as a protocol in Swift, but as an implicit capability that all types have by default. Swift 6 introduces the ability to suppress this implicit capability:

```swift
struct MyNonEscapable: ~Escapable {
    // Cannot escape its lexical scope
}
```

### 2.2 Lifetime Dependencies

A **lifetime dependency** is a compile-time relationship between two values where one value's validity is tied to another's lifetime. In mathematical terms:

Let `v` be a value with lifetime `L(v)`. If `w` has a lifetime dependency on `v`, then:

```
L(w) ⊆ L(v)
```

That is, `w` cannot outlive `v`. The compiler enforces this at every use site.

### 2.3 The Borrowing Relationship

When we write:

```swift
@_lifetime(borrow source)
public init(_ source: Span<UInt8>) { ... }
```

We establish that the initialized value borrows from `source`. The compiler tracks this dependency and prevents:

1. Returning the value from a scope where `source` is no longer valid
2. Storing the value in a location that outlives `source`
3. Passing the value to contexts that could extend its lifetime

### 2.4 The Non-Escaping Closure Contract

Swift closures are **non-escaping by default** in function parameters. A non-escaping closure:

1. Cannot be stored beyond the function call
2. Cannot be captured by escaping closures
3. Must complete before the function returns

This seems compatible with `~Escapable` semantics. However, as we will see, the type systems are not yet integrated.

---

## 3. SE-0446: Non-Escapable Types

### 3.1 Proposal Overview

SE-0446, accepted in October 2024, introduced non-escapable types to Swift. From the proposal:

> "This proposal adds a new type constraint `~Escapable` that marks types whose values are restricted in scope. Such values can be used locally, but cannot be assigned to variables, passed to arbitrary functions, or returned from functions without additional constraints."

### 3.2 Design Principles

The proposal establishes several key principles:

1. **Propagation**: Any type containing a non-escapable value must itself be non-escapable
2. **Composability**: Non-escapable types can conform to protocols and have methods
3. **Local Copying**: Non-escapable values CAN be locally copied (unlike `~Copyable`)
4. **Lifetime Annotation**: Functions returning non-escapable types require `@_lifetime` annotations

### 3.3 What SE-0446 Deliberately Excluded

The proposal explicitly deferred closure integration:

> "This proposal intentionally left out the ability for functions and properties to return values of these types, pending a future proposal to add lifetime dependencies."

And more critically:

> "Nonescaping function types are still separate from `~Escapable` in the type system. They should probably be considered as suppressing `Escapable`—that would make sense and would be extremely useful—but we haven't handled that yet."

This is the **root cause** of the closure integration gap.

### 3.4 The Closure Gap Explained

Consider the type of a non-escaping closure parameter:

```swift
func withValue(_ body: (MyType) -> Void) { ... }
```

The closure type `(MyType) -> Void` is itself a type. This type:
- Has no `@escaping` attribute
- Cannot be stored beyond the function call
- Must complete before the function returns

However, `MyType` in the parameter position has **no lifetime relationship** to the closure's scope. The compiler sees:

```
Closure lifetime: bounded to function call
MyType lifetime: potentially unbounded (if Escapable)
```

When `MyType: ~Escapable`, the compiler should understand:

```
Closure lifetime: bounded to function call
MyType lifetime: bounded to ≤ closure lifetime (because ~Escapable)
```

But this relationship is **not yet encoded** in Swift's type system. The compiler conservatively assumes passing `~Escapable` values to closures is escaping them.

---

## 4. SE-0447: Span and Safe Contiguous Access

### 4.1 The Safety Problem with UnsafeBufferPointer

SE-0447 identifies the core problem with existing closure-based APIs:

> "The pointer itself is unsafe and unmanaged"
> "Subscript access is only bounds-checked in debug builds of client code"
> "It might escape the duration of the closure"

The `withUnsafeBufferPointer` pattern provides **no compile-time safety** for lifetime violations.

### 4.2 Span as the Solution

`Span<T>` is a non-escapable abstraction for safe contiguous memory access:

```swift
public struct Span<Element>: ~Escapable {
    // Internal representation
    // Cannot escape its scope
    // Bounds-checked subscript in all builds
}
```

Key properties:
- **Spatial safety**: Guaranteed bounds validation always
- **Temporal safety**: Enforced via `~Escapable`
- **Type safety**: Generics, not raw pointers
- **Container-agnostic**: Works with Array, Data, String, etc.

### 4.3 Span-Based Property Pattern

SE-0456 introduces the canonical pattern for Span access:

```swift
extension Array {
    @_lifetime(borrow self)
    var span: Span<Element> {
        get { ... }
    }
}
```

Usage:
```swift
let array = [1, 2, 3]
let span = array.span  // span borrows from array
use(span)              // OK within this scope
// span cannot escape
```

This replaces the closure-based pattern with a **property-based** pattern where lifetime is expressed through `@_lifetime` annotations.

---

## 5. The Closure Integration Gap: A Detailed Analysis

### 5.1 Why the Gap Exists

The closure integration gap is not a bug—it's a deliberate staging decision. From the Swift forums:

> "The development of that feature may take a few releases."

The reasons are technical:

1. **Closure Representation**: Non-escaping closures can use stack-based representations. Adding lifetime constraints may require heap allocation in some cases.

2. **Multiple Captures**: "Multiple nonescaping closure values can capture exclusive access to the same `inout` parameters or mutable variables, so long as it isn't possible for both closures to be executing at the same time." This creates complex analysis requirements.

3. **Inference Complexity**: Automatically inferring lifetime relationships in closures requires sophisticated analysis not yet implemented.

### 5.2 What Would Be Required

To enable `~Escapable` parameters in closures, Swift would need:

```swift
// Hypothetical future syntax
func withBorrowed<T, E: Error>(
    _ bytes: borrowing [UInt8],
    @_lifetime(borrow bytes) _ body: (inout Input.View) throws(E) -> T
) throws(E) -> T
```

Where `@_lifetime(borrow bytes)` on the closure parameter means:
- The closure's parameter (`Input.View`) has a lifetime dependency on `bytes`
- The closure cannot store the parameter beyond its execution
- The compiler tracks this through the call

This syntax **does not exist** in Swift 6.2.

### 5.3 Current Compiler Behavior

When we write:

```swift
var view = Input.View(bytes.span)  // view depends on bytes.span
return try body(&view)             // Passing to closure
```

The compiler sees:
1. `view` has lifetime dependency on `bytes.span`
2. `body` is a closure (even if non-escaping)
3. Passing `&view` to `body` is "escaping" the value

The compiler cannot verify that `body` won't store `view` in some global or return it, because closure parameter lifetime annotations don't exist.

**There is currently no way to express "this closure parameter may not store its arguments" in Swift's type system.** This is not a bug or oversight—it is simply a feature that has not yet been implemented.

---

## 6. Anti-Pattern: The Immortal Pointer Escape Hatch

### 6.1 The Tempting Workaround

One might consider adding an internal initializer that bypasses lifetime checking:

```swift
// ANTI-PATTERN - DO NOT DO THIS
@unsafe
@inlinable
@_lifetime(immortal)
internal init(_unsafeStart pointer: UnsafePointer<UInt8>, count: Int) {
    self.span = unsafe Span(_unsafeStart: pointer, count: count)
    self.position = 0
}
```

With `@_lifetime(immortal)`, the view claims it lives forever, breaking the lifetime dependency chain.

### 6.2 Why This Is Wrong

This approach has severe problems:

**1. Type Semantics Become Lies**

The type claims to be `~Escapable` with Span-backed storage implying compile-time lifetime safety. But the `immortal` initializer creates instances that violate this invariant. Users see `Input.View` is `~Escapable` and trust the compiler will catch misuse—but the `immortal` path defeats this.

**2. Maintenance Trap**

Future developers will see the internal initializer and use it for "convenience" outside the intended borrow scope:

```swift
// Six months later, different developer
func getView() -> Input.View {
    let data = loadData()
    return Input.View(_unsafeStart: data.pointer, count: data.count)
    // ❌ data goes out of scope, view is dangling
}
```

The compiler cannot help because `@_lifetime(immortal)` disabled checking.

**3. Audit Difficulty**

Memory safety audits must now track every use of the internal initializer. The invariant "Input.View is safe because it's Span-backed" becomes "Input.View is safe EXCEPT when constructed via the internal initializer."

**4. Philosophical Violation**

The purpose of `~Escapable` and `Span` is to move safety from runtime contracts to compile-time guarantees. The immortal initializer moves it back to "trust the programmer"—exactly what we're trying to escape.

### 6.3 The Correct Principle

If the API shape cannot be made safe under current Swift, **change the API shape**—don't add unsafe escape hatches.

**Any design that requires audit-by-discipline instead of audit-by-compiler has already failed.**

---

## 7. The Non-Closure Runner Surface: Canonical Solution

### 7.1 Core Insight

The closure integration gap exists because:
1. We're trying to pass `~Escapable` values to closure parameters
2. Closure parameter lifetime annotations don't exist

The solution: **Don't pass `~Escapable` values to closures**.

If `Input.View` is `~Escapable`, then some non-closure, non-associated-type dispatch mechanism is **structurally required**. Whether you call it a protocol, a generic struct with a parse method, or a functor, the shape is unavoidable.

The cleanest expression of this shape is a protocol:
1. Define a protocol for parser objects
2. Call the parser's method directly with the `~Escapable` value
3. The `~Escapable` value never appears in a closure parameter position

This is not a stylistic preference—it's a structural necessity under Swift 6.2.

### 7.2 The Parser Protocol

```swift
extension Binary.Bytes {
    /// A parser that consumes bytes from a borrowed input view.
    public protocol Parser<Output, Failure> {
        associatedtype Output
        associatedtype Failure: Swift.Error

        /// Parse from the borrowed view.
        ///
        /// - Parameter input: The borrowed byte view to parse from.
        /// - Returns: The parsed output.
        /// - Throws: Parsing failure.
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output
    }
}
```

Key design points:
- `mutating func` allows stateful parsers
- `inout Input.View` passes the non-escapable view directly
- Typed throws (`throws(Failure)`) for precise error handling
- Protocol enables combinator composition

### 7.3 The Canonical withBorrowed

```swift
extension Binary.Bytes {
    /// Execute parser with borrowed view from byte array.
    ///
    /// Zero-copy: the view borrows directly from the array's contiguous storage.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to borrow.
    ///   - parser: The parser to execute.
    /// - Returns: The parser's output.
    /// - Throws: The parser's failure.
    @inlinable
    public static func withBorrowed<P: Parser>(
        _ bytes: [UInt8],
        _ parser: inout P
    ) throws(P.Failure) -> P.Output {
        var view = Input.View(bytes.span)
        return try parser.parse(&view)
    }
}
```

**Why This Works**:

1. `view` is created from `bytes.span` with proper lifetime dependency
2. `view` is passed to `parser.parse()` as an `inout` parameter
3. `parser.parse()` is a **method call**, not a closure invocation
4. The compiler knows `view` cannot escape the method call
5. After `parse()` returns, `view` goes out of scope

No closure parameter ever receives the `~Escapable` value!

**Key insight**: Method invocation does not introduce a capture boundary; parameters are passed directly and cannot be retained beyond the call. This is fundamentally different from closure invocation, where the closure itself could store references.

---

## 8. Conclusion

### 8.1 Summary of Findings

1. **The Closure Integration Gap Is Real**: Swift 6.2's `~Escapable` type system does not integrate with closure parameter types. Passing non-escapable values to closures triggers escape errors.

2. **The Gap Is Deliberate**: Swift's Language Steering Group staged the implementation, deferring closure integration for future releases.

3. **Immortal Pointer Workarounds Are Wrong**: Adding `@_lifetime(immortal)` internal initializers defeats the purpose of `~Escapable` and creates maintenance traps.

4. **The Parser-Object Pattern Is Correct**: By using a protocol with a method that takes `inout Input.View`, we avoid passing `~Escapable` values to closure parameters entirely.

5. **This Is Not a Workaround**: The protocol-based approach is the semantically correct design for non-escapable borrowed cursors under current Swift.

### 8.2 Recommendations

1. **Implement `Binary.Bytes.Parser`** protocol with `parse(_ input: inout Input.View)`
2. **Implement canonical `withBorrowed`** overloads that take `inout Parser`
3. **Optionally implement closure sugar** via `ClosureParser` adapter
4. **Keep `Input.View` purely Span-backed** with no unsafe initializers
5. **Document the design rationale** for future maintainers

### 8.3 Final Principle

> When the desired API shape cannot be made safe under current language constraints, **change the API shape**—don't add unsafe escape hatches that defeat type system guarantees.

The parser-object pattern achieves:
- Zero-copy parsing with compiler-enforced safety
- Clean, composable API surface
- Future compatibility with closure lifetime annotations
- No unsafe internal backdoors

This is the correct design for lifetime-dependent borrowed cursors in Swift 6.2.

---

## References

### Swift Evolution Proposals

1. **SE-0446**: Nonescapable Types - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
2. **SE-0447**: Span: Safe Access to Contiguous Storage - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
3. **SE-0456**: Add Span-providing Properties to Standard Library Types - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md
4. **SE-0465**: Nonescapable Standard Library Primitives - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md
5. **SE-0474**: Yielding Accessors - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0474-yielding-accessors.md
6. **SE-0377**: Parameter Ownership Modifiers - https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md

### Swift Forums

7. Pitch #2: Lifetime dependencies for non-Escapable values - https://forums.swift.org/t/pitch-2-lifetime-dependencies-for-non-escapable-values/78821
8. Experimental support for lifetime dependencies in Swift 6.2 and beyond - https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638
9. SE-0446 Acceptance - https://forums.swift.org/t/accepted-with-modifications-se-0446-nonescapable-types/75504

### External Resources

10. Michael Tsai - Lifetime Dependencies in Swift 6.2 and Beyond - https://mjtsai.com/blog/2025/03/19/lifetime-dependencies-in-swift-6-2-and-beyond/
11. Swift Standard Library Source - https://github.com/swiftlang/swift/tree/main/stdlib/public/core

---

*Document version 1.0.0 — 2026-01-27 — Status: RESEARCH*
