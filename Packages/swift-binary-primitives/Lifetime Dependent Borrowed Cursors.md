# Lifetime-Dependent Borrowed Cursors in Swift: A Comprehensive Analysis of Non-Escapable Types, Closure Integration Gaps, and the Non-Closure Runner Surface
<!--
---
version: 1.0.0
last_updated: 2026-01-19
status: RECOMMENDATION
---
-->

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

### 5.4 Attempted Workarounds That Failed

**Attempt 1**: Adding `borrowing` to the bytes parameter
```swift
func withBorrowed(_ bytes: borrowing [UInt8], ...) // ❌ Still fails
```

**Attempt 2**: Adding `@_lifetime` to the closure parameter
```swift
@_lifetime(borrow bytes) _ body: (inout Input.View) ... // ❌ Attribute not applicable
```

**Attempt 3**: Using `withoutActuallyEscaping`
```swift
// Not applicable - that's for closure-to-closure, not value-to-closure
```

None of these work because the fundamental type-system integration is missing.

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

### 7.4 Closure Sugar via Adapter

For ergonomic closure-based usage, we create an adapter:

```swift
extension Binary.Bytes {
    /// Adapter that wraps a closure as a parser.
    @usableFromInline
    internal struct ClosureParser<Output, Failure: Swift.Error>: Parser {
        @usableFromInline
        let body: (inout Input.View) throws(Failure) -> Output

        @inlinable
        internal init(_ body: @escaping (inout Input.View) throws(Failure) -> Output) {
            self.body = body
        }

        @inlinable
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output {
            try body(&input)
        }
    }
}
```

Wait—this stores the closure! Doesn't that violate our principle?

**Critical Observation**: The closure is stored, but the borrowed `Input.View` is neither captured nor stored—only passed at invocation time.

The closure's type is:
```swift
(inout Input.View) throws(Failure) -> Output
```

This is an **escaping closure** that will be called later. But:
1. When called, it receives `Input.View` via normal method parameter passing
2. The `Input.View` is not captured—it's passed at call time
3. By the time `parse()` is called, `view` exists and is valid

The closure may escape, but the borrowed value never does.

### 7.5 The Convenience Overload

> **API Classification**:
> - **Canonical API**: `withBorrowed(_:parser:)` — the parser-object overload
> - **Convenience API**: `withBorrowed(_:body:)` — the closure overload (syntactic sugar only)
>
> The closure-based overload is syntactic sugar only. All safety guarantees rely on the parser-object overload.

```swift
extension Binary.Bytes {
    /// Execute closure with borrowed view from byte array.
    ///
    /// Convenience wrapper that adapts a closure to the parser protocol.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to borrow.
    ///   - body: A closure that parses from the borrowed view.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`.
    @inlinable
    public static func withBorrowed<T, E: Swift.Error>(
        _ bytes: [UInt8],
        _ body: @escaping (inout Input.View) throws(E) -> T
    ) throws(E) -> T {
        var parser = ClosureParser(body)
        return try withBorrowed(bytes, &parser)
    }
}
```

### 7.6 Why This Design Is Correct

1. **Preserves Type Invariants**: `Input.View` remains purely Span-backed and `~Escapable`. No immortal backdoor.

2. **Compiler Assistance Intact**: Every use of `Input.View` is lifetime-checked. The compiler prevents misuse.

3. **Audit Simplicity**: There is no internal initializer that undermines safety. The type's safety comes from its definition, not from careful use of escape hatches.

4. **Future Compatibility**: When Swift adds closure parameter lifetime annotations, the closure sugar will "just work" more directly. The parser protocol remains valid.

5. **Structurally Required, Not a Workaround**: This is not a stylistic choice or a compromise. If you want `Input.View` to be `~Escapable`, some non-closure runner surface is **required** by the language. The protocol is simply the cleanest, most composable expression of that requirement.

---

## 8. Existing Parsing Infrastructure Analysis

### 8.1 swift-parsing-primitives Architecture

The codebase already contains a sophisticated parsing infrastructure:

**Core Protocol** (`Parsing.Parser`):
```swift
public protocol Parser<Input, Output, Failure> {
    associatedtype Input
    associatedtype Output
    associatedtype Failure: Swift.Error

    func parse(_ input: inout Input) throws(Failure) -> Output
}
```

**Input Protocol** (`Parsing.Input`):
```swift
public protocol Input: Parsing.Streaming, ~Copyable {
    associatedtype Checkpoint

    var checkpoint: Checkpoint { get }
    mutating func restore(to checkpoint: Checkpoint)
    var count: Int { get }
    mutating func removeFirst(_ n: Int)
    var remaining: Self { get }
}
```

**Streaming Protocol** (`Parsing.Input.Streaming`):
```swift
public protocol Streaming: ~Copyable {
    associatedtype Element

    var isEmpty: Bool { get }
    var first: Element? { get }
    mutating func removeFirst() -> Element
}
```

### 8.2 Binary-Specific Parsing

**`Binary.Bytes.Input`** conforms to `Parsing.Input`:
```swift
extension Binary.Bytes.Input: Parsing.Input {
    public typealias Element = UInt8
    public typealias Checkpoint = Int

    var checkpoint: Checkpoint { position }
    mutating func restore(to checkpoint: Checkpoint) { position = checkpoint }
    var remaining: Self { self }
}
```

**`Binary.Parse.Access<P>`** provides ergonomic API:
```swift
extension Parsing.Parser where Self: Sendable, Input == Binary.Bytes.Input {
    public var parse: Binary.Parse.Access<Self> { .init(self) }
}

// Usage:
let value = try parser.parse.whole(bytes)
let result = try parser.parse.prefix(bytes)
```

### 8.3 Parser Combinators

The infrastructure includes:

- **Sequential**: `Parsing.Take.Two<P0, P1>` - run two parsers in sequence
- **Alternative**: `Parsing.OneOf.Two<P0, P1>` - try first, fallback to second
- **Transform**: `Parsing.Map.Transform<P, NewOutput>` - map output
- **FlatMap**: `Parsing.FlatMap<P0, P1>` - monadic chaining
- **Filter**: `Parsing.Filter<P>` - predicate filtering

### 8.4 Machine System (Defunctionalization)

For unbounded recursion, the infrastructure provides:

```swift
public struct Parsing.Machine.Parser<Input, Output, Failure>: Parsing.Parser {
    let program: Program<Input, Failure>
    let root: Node<Input, Failure>.ID

    public func parse(_ input: inout Input) throws(Failure) -> Output {
        try program.run(root: root, input: &input, as: Output.self)
    }
}
```

This uses defunctionalization to avoid stack overflow for recursive grammars.

### 8.5 The Two Canonical Worlds Architecture

The fundamental constraint is a triangle:

1. **Reuse existing combinators** (Parsing.Parser infrastructure)
2. **Keep Input.View `~Escapable`** (compile-time lifetime safety)
3. **Keep zero-copy borrowed parsing** (no copying)

You cannot have all three in Swift 6.2. The language limitation is:

> Swift 6.2 does not allow `~Escapable` constraints on protocol associated types.

This is explicitly documented in `Parsing.Parser`:

```swift
/// For bytes parsing, use `Parsing.Bytes.Input` (an escapable cursor type)
/// rather than `Span<UInt8>` directly. Swift 6.2 does not allow `~Escapable`
/// constraints on protocol associated types.
associatedtype Input
```

**The Two Worlds**:

| World | Input Type | Protocol | Safety | Performance |
|-------|-----------|----------|--------|-------------|
| **Owned** | `Binary.Bytes.Input` | `Parsing.Parser` | Runtime contract | Copies on non-array inputs |
| **Borrowed** | `Binary.Bytes.Input.View` | `Binary.Bytes.Parser` | Compile-time enforced | True zero-copy |

**Why This Is Not a Workaround**:

If you insist on `Input.View` being Span-backed + `~Escapable`, then some non-closure, non-associated-type dispatch mechanism is **structurally required**. Whether you call it a protocol, a generic struct with a parse method, or a functor, the shape is unavoidable. The "protocol approach" is simply the cleanest expression of this unavoidable shape.

**What Is Unacceptable**:

Using the owned `Binary.Bytes.Input` (which copies) as the "borrowed" API. The borrowed path must be truly borrowed. `withInput` exists for the owned/copying path when that's what you need. `withBorrowed` must deliver true zero-copy.

### 8.6 Reuse Strategies

Two strategies preserve combinator reuse while maintaining the two-world separation:

**Strategy 1: Bridge Layer**

Keep `Parsing.Parser` for owned `Binary.Bytes.Input`. Introduce bridge combinators that wrap owned parsers for borrowed execution:

```swift
/// Bridge that adapts an owned parser to work with borrowed views.
/// The bridge copies data only when the underlying parser is invoked.
struct BridgedParser<P: Parsing.Parser>: Binary.Bytes.Parser
where P.Input == Binary.Bytes.Input {
    let owned: P

    mutating func parse(_ input: inout Binary.Bytes.Input.View) throws(P.Failure) -> P.Output {
        // Copy remaining bytes to owned input
        var ownedInput = input.copyToOwned()
        let result = try owned.parse(&ownedInput)
        // Advance view by amount consumed
        input.removeFirst(input.count - ownedInput.count)
        return result
    }
}
```

This allows parser definitions to be shared between worlds, with explicit bridge points where copying occurs.

**Strategy 2: Defunctionalized Machine Execution**

If you want to avoid adding a new protocol to the public API, use data-driven parsing:

```swift
/// A borrowed-world program that doesn't require Input: Parsing.Input.
/// Interprets node graph against Input.View directly.
struct BorrowedProgram<Failure: Error> {
    var nodes: [BorrowedNode<Failure>]

    func run<Output>(
        root: BorrowedNode<Failure>.ID,
        input: inout Binary.Bytes.Input.View,
        as: Output.Type
    ) throws(Failure) -> Output {
        // Interpreter loop - never puts Input.View into associated type position
    }
}
```

This is heavier to implement but keeps the protocol surface unchanged. The existing `Parsing.Machine` architecture provides the blueprint, but requires a parallel implementation specialized for `Input.View`.

**Recommendation**: Strategy 1 (bridge layer) is simpler and more auditable. Strategy 2 is appropriate if you need high-performance recursive grammars on borrowed input.

### 8.7 Integration Point Summary

The new `Binary.Bytes.Parser` protocol:
1. **Complements** (not replaces) `Parsing.Parser`
2. **Is specialized** for `Input.View` (the `~Escapable` borrowed cursor)
3. **Does NOT conform** to `Parsing.Parser` directly (impossible under Swift 6.2)
4. **Can bridge** to/from `Parsing.Parser` via explicit adapters where needed

---

## 9. Implementation Design

### 9.1 Type Hierarchy

```
Binary.Bytes
├── Input              (owned, Sendable, stores [UInt8])
│   └── View           (~Escapable, ~Copyable, stores Span<UInt8>)
└── Parser             (protocol for borrowed parsing)
```

### 9.2 Binary.Bytes.Input.View (Complete)

```swift
extension Binary.Bytes.Input {
    /// Borrowed input view for zero-copy bytes parsing.
    ///
    /// This type provides a scope-bound cursor over borrowed bytes using
    /// Swift's lifetime-checked `Span<UInt8>`. It cannot outlive the data it borrows.
    ///
    /// ## Invariants
    /// - `0 <= position <= span.count`
    /// - `count == span.count - position`
    /// - `consumedCount == position`
    ///
    /// ## Lifetime Safety
    /// `Input.View` is `~Copyable` and `~Escapable`. The compiler enforces that:
    /// - The view cannot escape the scope of the borrowed data
    /// - The borrowed data must outlive the view
    /// - No copies can be made (preventing aliasing bugs)
    ///
    /// ## NOT Sendable
    /// `Input.View` is explicitly NOT `Sendable`. Borrowed views must not cross
    /// task boundaries. Use `Binary.Bytes.Input` (owned) for concurrency.
    ///
    /// ## INVARIANT (for maintainers)
    /// No initializer of this type may accept a raw pointer or buffer without
    /// a lifetime-checked parent. This invariant is critical for memory safety.
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        let span: Span<UInt8>

        @usableFromInline
        var position: Int

        /// Creates a borrowed input view from a span.
        @inlinable
        @_lifetime(borrow span)
        public init(_ span: Span<UInt8>) {
            self.span = span
            self.position = 0
        }
    }
}
```

**Note**: No unsafe initializer. Construction only via `Span`.

### 9.3 Binary.Bytes.Parser Protocol

```swift
extension Binary.Bytes {
    /// A parser that consumes bytes from a borrowed input view.
    ///
    /// Conforming types implement stateful parsing over a borrowed byte cursor.
    /// The parser mutates the input view to consume bytes as it parses.
    ///
    /// ## Design Rationale
    ///
    /// This protocol exists because `Input.View` is `~Escapable`, meaning it
    /// cannot be passed to closure parameters under current Swift (6.2). By
    /// using a protocol with a method call, the `~Escapable` value is passed
    /// via normal parameter passing, not closure capture.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct UInt32Parser: Binary.Bytes.Parser {
    ///     let endianness: Binary.Endianness
    ///
    ///     mutating func parse(_ input: inout Binary.Bytes.Input.View) throws(Failure) -> UInt32 {
    ///         guard input.count >= 4 else { throw .endOfInput }
    ///         let b0 = input.removeFirst()
    ///         let b1 = input.removeFirst()
    ///         let b2 = input.removeFirst()
    ///         let b3 = input.removeFirst()
    ///         switch endianness {
    ///         case .little: return UInt32(b0) | UInt32(b1) << 8 | UInt32(b2) << 16 | UInt32(b3) << 24
    ///         case .big:    return UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(b2) << 8 | UInt32(b3)
    ///         }
    ///     }
    /// }
    /// ```
    public protocol Parser<Output, Failure> {
        /// The type of value produced by successful parsing.
        associatedtype Output

        /// The type of error thrown on parsing failure.
        associatedtype Failure: Swift.Error

        /// Parse from the borrowed byte view.
        ///
        /// - Parameter input: The borrowed byte view to parse from.
        ///   The view is mutated to consume parsed bytes.
        /// - Returns: The parsed output value.
        /// - Throws: A failure if parsing cannot succeed.
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output
    }
}
```

### 9.4 withBorrowed Overloads

> **Policy**: Any overload that cannot guarantee contiguity must route to the owned (`withInput`) path, never the borrowed path. This prevents accidental regressions where someone adds a "borrowed" overload that allocates.

```swift
// MARK: - Borrowed APIs (zero-copy, pass Input.View)

extension Binary.Bytes {
    /// Execute parser with borrowed view from byte array.
    ///
    /// Zero-copy: the view borrows directly from the array's contiguous storage.
    @inlinable
    public static func withBorrowed<P: Parser>(
        _ bytes: [UInt8],
        _ parser: inout P
    ) throws(P.Failure) -> P.Output {
        var view = Input.View(bytes.span)
        return try parser.parse(&view)
    }

    /// Execute parser with borrowed view from contiguous storage.
    ///
    /// Works with any type providing contiguous byte access.
    @inlinable
    public static func withBorrowed<C: Binary.Contiguous, P: Parser>(
        _ source: borrowing C,
        _ parser: inout P
    ) throws(P.Failure) -> P.Output {
        var view = Input.View(source.bytes)
        return try parser.parse(&view)
    }

    /// Execute parser with borrowed view from unsafe buffer pointer.
    ///
    /// For interop with C APIs that provide buffer pointers.
    @unsafe
    @inlinable
    public static func withBorrowed<P: Parser>(
        _ buffer: UnsafeBufferPointer<UInt8>,
        _ parser: inout P
    ) throws(P.Failure) -> P.Output {
        guard let base = buffer.baseAddress else {
            // Empty buffer case
            var view = Input.View([].span)
            return try parser.parse(&view)
        }
        let span = unsafe Span(_unsafeStart: base, count: buffer.count)
        var view = Input.View(span)
        return try parser.parse(&view)
    }
}
```

### 9.5 Closure Sugar (If Needed)

```swift
extension Binary.Bytes {
    /// Adapter wrapping a closure as a Parser.
    @usableFromInline
    internal struct ClosureParser<Output, Failure: Swift.Error>: Parser {
        @usableFromInline
        let body: (inout Input.View) throws(Failure) -> Output

        @inlinable
        init(_ body: @escaping (inout Input.View) throws(Failure) -> Output) {
            self.body = body
        }

        @inlinable
        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output {
            try body(&input)
        }
    }

    /// Execute closure with borrowed view from byte array.
    ///
    /// Convenience wrapper adapting closure to parser protocol.
    @inlinable
    public static func withBorrowed<T, E: Swift.Error>(
        _ bytes: [UInt8],
        _ body: @escaping (inout Input.View) throws(E) -> T
    ) throws(E) -> T {
        var parser = ClosureParser(body)
        return try withBorrowed(bytes, &parser)
    }
}
```

**Note**: If the `ClosureParser` approach still triggers compiler errors due to the escaping closure storing a reference to `Input.View`, the closure sugar should:
1. Be placed behind an underscored attribute (`@_spi(Experimental)`)
2. Or be deferred until Swift supports closure parameter lifetime annotations
3. The canonical parser-object API remains the public, documented API

---

## 10. Standard Library Precedents

### 10.1 The withUnsafeBufferPointer Pattern (Legacy)

```swift
extension Array {
    func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R
}
```

This is a **runtime contract** with no compile-time safety. The pointer is only valid during the closure, but the compiler provides no enforcement.

### 10.2 The Span Property Pattern (Modern)

SE-0456 replaces closure-based APIs with properties:

```swift
extension Array {
    @_lifetime(borrow self)
    var span: Span<Element> { get }
}
```

Usage:
```swift
let span = array.span  // Compiler-enforced lifetime
processSpan(span)      // OK
return span            // ❌ Compile error: escapes scope
```

This is the **canonical pattern** for borrowed access in modern Swift.

### 10.3 Yielding Accessors (Coroutines)

SE-0474 introduces yielding accessors:

```swift
var value: T {
    _read {
        yield borrowedValue
    }
    _modify {
        yield &mutableValue
    }
}
```

These are coroutines that:
1. Pause at `yield`
2. Allow caller to use the yielded value
3. Resume after caller finishes
4. Guarantee cleanup

This pattern guarantees the yielded value cannot escape because the coroutine controls its lifetime.

### 10.4 Our Pattern Aligns with Stdlib Direction

The parser-object pattern aligns with these precedents:

1. **No closure parameter for `~Escapable`**: Like Span properties avoiding closures
2. **Method call instead of callback**: Like yielding accessors
3. **Protocol-based extensibility**: Like `Sequence`, `Collection`, etc.

---

## 11. Future Directions

### 11.1 Closure Parameter Lifetime Annotations

When Swift adds this capability (potentially Swift 7+), the syntax might be:

```swift
func withBorrowed<T, E: Error>(
    _ bytes: borrowing [UInt8],
    @_lifetime(borrow bytes) _ body: (inout Input.View) throws(E) -> T
) throws(E) -> T
```

The `ClosureParser` adapter would become unnecessary, but the parser protocol remains valid and useful for combinator composition.

### 11.2 Integration with Parsing.Parser

A bridge conformance could unify the protocols:

```swift
extension Binary.Bytes.Parser where Self: Parsing.Parser, Input == Binary.Bytes.Input {
    // Provide parse(_: inout Binary.Bytes.Input) via parse(_: inout Input.View)
}
```

This allows existing parsers to work with both owned and borrowed inputs.

### 11.3 Async Parsing (Not Currently Supported)

Async borrowed parsing is intentionally not supported until Swift can guarantee non-escapable values cannot cross suspension points.

The challenge is that `async` functions may suspend, and across a suspension point, the borrowed storage could be deallocated. While `~Escapable` prevents explicit storage, the runtime mechanics of async/await introduce implicit capture that the compiler cannot yet verify.

Future work could extend to async contexts when Swift adds the necessary guarantees:

```swift
// HYPOTHETICAL - NOT CURRENTLY SAFE
public protocol AsyncParser<Output, Failure> {
    associatedtype Output
    associatedtype Failure: Swift.Error

    mutating func parse(_ input: inout Input.View) async throws(Failure) -> Output
}
```

Until then, async parsing should use the owned `Binary.Bytes.Input` path, which copies the data and is safe across suspension points.

---

## 12. Conclusion

### 12.1 Summary of Findings

1. **The Closure Integration Gap Is Real**: Swift 6.2's `~Escapable` type system does not integrate with closure parameter types. Passing non-escapable values to closures triggers escape errors.

2. **The Gap Is Deliberate**: Swift's Language Steering Group staged the implementation, deferring closure integration for future releases.

3. **Immortal Pointer Workarounds Are Wrong**: Adding `@_lifetime(immortal)` internal initializers defeats the purpose of `~Escapable` and creates maintenance traps.

4. **The Parser-Object Pattern Is Correct**: By using a protocol with a method that takes `inout Input.View`, we avoid passing `~Escapable` values to closure parameters entirely.

5. **This Is Not a Workaround**: The protocol-based approach is the semantically correct design for non-escapable borrowed cursors under current Swift.

### 12.2 Recommendations

1. **Implement `Binary.Bytes.Parser`** protocol with `parse(_ input: inout Input.View)`
2. **Implement canonical `withBorrowed`** overloads that take `inout Parser`
3. **Optionally implement closure sugar** via `ClosureParser` adapter
4. **Keep `Input.View` purely Span-backed** with no unsafe initializers
5. **Document the design rationale** for future maintainers

### 12.3 Final Principle

> When the desired API shape cannot be made safe under current language constraints, **change the API shape**—don't add unsafe escape hatches that defeat type system guarantees.

The parser-object pattern achieves:
- Zero-copy parsing with compiler-enforced safety
- Clean, composable API surface
- Future compatibility with closure lifetime annotations
- No unsafe internal backdoors

This is the correct design for lifetime-dependent borrowed cursors in Swift 6.2.

---

## 13. References

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

### Codebase References

12. `swift-parsing-primitives/Sources/Parsing Primitives/Parsing.Parser.swift` - Core parser protocol
13. `swift-parsing-primitives/Sources/Parsing Primitives/Parsing.Input.swift` - Input protocol
14. `swift-binary-primitives/Sources/Binary Primitives/Binary.Bytes.Input.swift` - Bytes input type
15. `swift-binary-primitives/Sources/Binary Primitives/Binary.Bytes.Input.View.swift` - Borrowed view type
16. `swift-binary-primitives/Sources/Binary Primitives/Binary.Contiguous.swift` - Contiguous protocol

---

## Implementation Plan

Based on this analysis, the implementation should proceed as follows:

### Phase 1: Create Binary.Bytes.Parser Protocol

**File**: `Binary.Bytes.Parser.swift`

```swift
extension Binary.Bytes {
    public protocol Parser<Output, Failure> {
        associatedtype Output
        associatedtype Failure: Swift.Error

        mutating func parse(_ input: inout Input.View) throws(Failure) -> Output
    }
}
```

### Phase 2: Implement Canonical withBorrowed

**File**: `Binary.Bytes.withBorrowed.swift`

1. Parser-taking overload for `[UInt8]`
2. Parser-taking overload for `Binary.Contiguous`
3. Handle empty buffer cases safely (no force-unwrap of `baseAddress`)

### Phase 3: Add Closure Sugar (Optional)

**File**: `Binary.Bytes.withBorrowed.swift` or separate file

1. Internal `ClosureParser` adapter
2. Convenience closure-taking overload
3. If compiler errors persist, mark as `@_spi(Experimental)`

### Phase 4: Keep withInput for Owned Path

**File**: `Binary.Bytes.withBorrowed.swift` (already exists)

The existing `withInput` functions handle owned/copying semantics.

### Phase 5: Verification

```bash
cd /Users/coen/Developer/swift-primitives/swift-binary-primitives && swift build
```

---

*End of Paper*
