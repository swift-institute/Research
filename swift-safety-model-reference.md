# Swift Safety Model Reference

<!--
---
version: 1.0.0
last_updated: 2026-03-25
status: DECISION
tier: 2
---
-->

## Context

Swift 6.2 introduces SE-0458 (Opt-in Strict Memory Safety Checking), a comprehensive safety model that identifies and flags all uses of unsafe constructs at compile time. This research document provides the definitive reference for the Swift Institute ecosystem on how to correctly use `@safe`, `@unsafe`, and `unsafe` expressions, derived from the compiler source (`swiftlang/swift`), the official user documentation, compiler test suite, and prior ecosystem audit experience.

**Trigger**: Preparation for a systematic safety audit across the Swift Institute ecosystem (swift-primitives, swift-standards, swift-foundations).

**Scope**: Ecosystem-wide (all Swift Institute packages).

**Prior art in ecosystem**: `swift-binary-primitives/Research/SE-0458 Strict Memory Safety.md` and `SE-0458 Audit Methodology.md` document initial findings. This document supersedes both as the canonical reference by incorporating compiler source analysis and additional patterns discovered across the ecosystem.

## Question

How should the Swift Institute ecosystem correctly use Swift's safety model (`@safe`, `@unsafe`, `unsafe` expressions, and related constructs) to achieve full SE-0458 compliance while maintaining clean, auditable code?

---

## 1. The Swift Safety Model

### 1.1 Enabling Strict Memory Safety

**Compiler flag:**
```bash
swiftc -strict-memory-safety source.swift
```

**Package.swift:**
```swift
.target(
    name: "MyTarget",
    swiftSettings: [.strictMemorySafety()]
)
```

**Conditional compilation:**
```swift
#if hasFeature(StrictMemorySafety)
// Strict mode code
#endif
```

**Compiler implementation**: `StrictMemorySafety` is defined as `MIGRATABLE_OPTIONAL_LANGUAGE_FEATURE` at `Features.def:311` with feature ID 458. The attribute definitions for `@unsafe` (ID 160) and `@safe` (ID 164) are separate from the feature flag and available even without strict memory safety enabled — they are accepted by the compiler regardless (verified by `test/Unsafe/unsafe_feature.swift`).

### 1.2 Five Dimensions of Memory Safety

| Dimension | Mechanism | Default |
|-----------|-----------|---------|
| Lifetime Safety | ARC, memory exclusivity | Yes |
| Bounds Safety | Runtime bounds checking | Yes |
| Type Safety | Safe casting operators | Yes |
| Initialization Safety | Definite initialization | Yes |
| Thread Safety | Strict concurrency (Swift 6) | Opt-in |

SE-0458 adds a sixth dimension: **explicit unsafe acknowledgment**.

### 1.3 Design Principles

| Principle | Detail |
|-----------|--------|
| Expression-level granularity | `unsafe` applies to the immediately following expression, narrower than Rust's `unsafe { }` blocks |
| No propagation | Unsafety does NOT propagate outward through function boundaries |
| No ABI impact | Purely compile-time; `@safe` and `@unsafe` are `ABIStableToAdd | ABIStableToRemove` |
| Auditability | Tooling can enumerate all `unsafe` expressions in a module |
| Not default | Opt-in via `-strict-memory-safety` flag |

---

## 2. The Three Safety Annotations

### 2.1 `@unsafe` — Marks Declarations as Unsafe

**Meaning**: "Using this declaration can undermine memory safety. Callers must acknowledge with `unsafe`."

**Applicable to** (from `DeclAttr.def:846`):
- Functions (`OnAbstractFunction`)
- Subscripts (`OnSubscript`)
- Variables (`OnVar`)
- Macros (`OnMacro`)
- Nominal types (`OnNominalType`)
- Extensions (`OnExtension`)
- Type aliases (`OnTypeAlias`)
- Enum elements (`OnEnumElement`)
- Imports (`OnImport`)

```swift
@unsafe func dangerousOperation(_ ptr: UnsafeMutablePointer<Int>) { ... }

// Call site:
unsafe dangerousOperation(ptr)
```

**Critical behavior**: `@unsafe` on a declaration does NOT exempt the declaration's body from safety checking. Internal unsafe operations still need `unsafe` expressions:

```swift
@unsafe func wrapper() {
    unsafe c_function(ptr)  // Still needs `unsafe` internally
}
```

### 2.2 `@safe` — Marks Safe Encapsulation

**Meaning**: "This declaration is safe despite having unsafe types in its implementation or signature."

**Applicable to** (from `DeclAttr.def:867`):
- Functions (`OnAbstractFunction`)
- Subscripts (`OnSubscript`)
- Variables (`OnVar`)
- Macros (`OnMacro`)
- Nominal types (`OnNominalType`)
- Extensions (`OnExtension`)
- Enum elements (`OnEnumElement`)

Note: `@safe` does NOT apply to type aliases or imports (unlike `@unsafe`).

```swift
@safe
struct SecureBuffer {
    private var storage: UnsafeMutablePointer<UInt8>

    subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count)
        return unsafe storage[index]  // Internal unsafe ops still marked
    }
}
```

**Argument suppression**: When a function or member is `@safe`, callers of that function do not need `unsafe` even when passing `@unsafe` types as arguments. This is verified by `test/Unsafe/safe_argument_suppression.swift`:

```swift
@unsafe class NotSafe {
    @safe func memberFunc(_: NotSafe) { }
    @safe subscript(ns: NotSafe) -> Int { 5 }
    @safe static func doStatically(_: NotSafe.Type) { }
    @safe init(_: NotSafe) { }
}

@safe func testImpliedSafety(ns: NotSafe) {
    ns.memberFunc(ns)           // OK: @safe suppresses argument unsafety
    _ = ns[ns]                  // OK
    _ = NotSafe(ns)             // OK
    NotSafe.doStatically(NotSafe.self) // OK

    ns.stillUnsafe()            // WARNING: not @safe
}
```

### 2.3 `unsafe` Expression — Acknowledges Unsafe Operations

**Meaning**: "I acknowledge this operation is unsafe and take responsibility."

**Parsing rules** (from `ParseExpr.cpp:426-445`): The `unsafe` keyword is parsed as a contextual keyword prefix when:
- Not followed by a line break
- Not followed by closing delimiters (`)`, `}`, `]`)
- Not followed by `.`, `=`, `:`, `,`
- Not followed by binary/postfix operators

```swift
let value = unsafe ptr.pointee
unsafe destination.copyMemory(from: source, byteCount: count)
```

**Syntax constraint**: `unsafe` cannot appear to the right of a non-assignment operator:

```swift
3 + unsafe unsafeInt()  // ERROR: 'unsafe' cannot appear to the right of a non-assignment operator

// Correct: extract to variable
let n = unsafe unsafeInt()
3 + n
```

**Redundancy warning**: The compiler warns when no unsafe operations occur within an `unsafe` expression (`no_unsafe_in_unsafe` diagnostic):

```swift
unsafe g()  // WARNING if g() is not actually unsafe
```

### 2.4 Mutual Exclusion

A declaration cannot be both `@safe` and `@unsafe`. This is a hard error:

```swift
@safe @unsafe
struct Confused { }  // ERROR: struct 'Confused' cannot be both '@safe' and '@unsafe'
```

### 2.5 `ExplicitSafety` Enum

The compiler represents safety state as a three-valued enum (`Decl.h:243`):

```
ExplicitSafety::Unspecified  — No annotation (most declarations)
ExplicitSafety::Safe         — Annotated with @safe
ExplicitSafety::Unsafe       — Annotated with @unsafe
```

---

## 3. What Triggers Unsafe Diagnostics

The compiler classifies 14 kinds of unsafe uses (`UnsafeUse.h:32-63`):

| Kind | Description | Example |
|------|-------------|---------|
| `Override` | Unsafe decl overrides safe superclass method | `@unsafe override func f()` |
| `Witness` | Unsafe decl witnesses safe protocol requirement | `@unsafe func protoMethod()` satisfying `P.protoMethod()` |
| `TypeWitness` | Unsafe type satisfies safe associated type | `typealias Ptr = UnsafePointer<Int>` for safe `associatedtype Ptr` |
| `UnsafeConformance` | `@unsafe` or `@unchecked` conformance | `struct S: @unsafe P { }` |
| `UnownedUnsafe` | Reference to `unowned(unsafe)` entity | `_ = s2` where `s2` is `unowned(unsafe)` |
| `ExclusivityUnchecked` | Reference to `@exclusivity(unchecked)` entity | `value += 1` where `value` is `@exclusivity(unchecked)` |
| `NonisolatedUnsafe` | Reference to `nonisolated(unsafe)` in concurrent code | `counter += 1` in detached task |
| `ReferenceToUnsafe` | Reference to `@unsafe` declaration | `unsafeF()` |
| `ReferenceToUnsafeStorage` | Reference to storage of unsafe type | Reading field with `UnsafePointer` type |
| `ReferenceToUnsafeThroughTypealias` | Typealias with unsafe underlying type | `typealias T = UnsafePointer<Int>` |
| `CallToUnsafe` | Call to `@unsafe` declaration | `unsafeBitCast(...)` |
| `CallArgument` | Unsafe argument passed in call | `f(&i)` where parameter is `UnsafePointer<Int>?` |
| `PreconcurrencyImport` | `@preconcurrency` import | `@preconcurrency import M` |
| `TemporarilyEscaping` | `withoutActuallyEscaping` lacking enforcement | Using non-escaping closure as escaping |

### 3.1 Standard Library Types Marked `@unsafe`

- `UnsafePointer<T>`, `UnsafeMutablePointer<T>`
- `UnsafeRawPointer`, `UnsafeMutableRawPointer`
- `UnsafeBufferPointer<T>`, `UnsafeMutableBufferPointer<T>`
- `UnsafeRawBufferPointer`, `UnsafeMutableRawBufferPointer`
- `Unmanaged<T>`, `UnsafeContinuation`
- `OpaquePointer`

### 3.2 Unsafe Operations

- `unsafeBitCast(_:to:)`, `unsafeDowncast(_:to:)`
- `Optional.unsafelyUnwrapped`
- `withUnsafePointer(to:_:)`, `withUnsafeBytes(of:_:)`
- `.load(as:)`, `.copyMemory(from:byteCount:)`
- `.initializeMemory(as:repeating:count:)`
- `.assumingMemoryBound(to:)`, `.bindMemory(to:capacity:)`

### 3.3 Unsafe Language Constructs

| Construct | Diagnostic |
|-----------|-----------|
| `unowned(unsafe) var x` | "reference to unowned(unsafe) property is unsafe" |
| `nonisolated(unsafe) var x` | "reference to nonisolated(unsafe) var is unsafe in concurrently-executing code" |
| `@exclusivity(unchecked) var x` | "reference to @exclusivity(unchecked) property is unsafe" |
| `@preconcurrency import M` | "'@preconcurrency' import is not memory-safe because it can silently introduce data races" |
| `@unchecked Sendable` | Conformance needs `@unsafe` |
| `withoutActuallyEscaping` | Temporarily escaping lacks enforcement |

### 3.4 Unsafe Storage

When a type has stored properties involving unsafe types, the compiler diagnoses:

```
struct MyBuffer has storage involving unsafe types
```

With two fix-it suggestions:
- `add '@unsafe' if this type is also unsafe to use`
- `add '@safe' if this type encapsulates the unsafe storage in a safe interface`

### 3.5 C/C++ Interoperability

- C functions with pointer parameters are implicitly `@unsafe`
- C structs containing pointers are inferred `@unsafe`
- C unions with member access are `@unsafe` (accessing any member is unsafe)
- `SWIFT_SAFE` / `SWIFT_UNSAFE` macros available via `__attribute__((swift_attr("@safe")))` and `__attribute__((swift_attr("@unsafe")))`
- Reference-counted C types (via `SWIFT_SHARED_REFERENCE`) are safe
- C enums without pointers are safe
- C structs without pointers are safe

### 3.6 `nonisolated(unsafe)` Specifics

**Only diagnosed in concurrent code** (from `test/Unsafe/unsafe_concurrency.swift`): `nonisolated(unsafe)` is only flagged under `StrictConcurrency`. The diagnostic fires when:
1. Inside an `async` function
2. Inside a detached `Task { }`
3. Reading/writing a `nonisolated(unsafe)` variable from concurrent context

```swift
nonisolated(unsafe) var globalCounter = 0

func f() async {
    // WARNING: reference to nonisolated(unsafe) var is unsafe in concurrently-executing code
    counter += 1
}
```

---

## 4. Diagnostic Messages

All strict memory safety diagnostics are **grouped warnings** under the `StrictMemorySafety` group (from `DiagnosticsSema.def:8579-8625`), meaning they are only emitted when strict memory safety is enabled.

| Diagnostic ID | Message | Category |
|---------------|---------|----------|
| `decl_unsafe_storage` | "%kindbase0 has storage involving unsafe types" | Warning |
| `unsafe_superclass` | "%kindbase0 has superclass involving unsafe type %1" | Warning |
| `conformance_involves_unsafe` | "conformance of %0 to %kind1 involves unsafe code" | Warning |
| `override_safe_with_unsafe` | "override of safe %kindonly0 with unsafe %kindonly0" | Warning |
| `preconcurrency_import_unsafe` | "'@preconcurrency' import is not memory-safe..." | Warning |
| `unsafe_without_unsafe` | "expression uses unsafe constructs but is not marked with 'unsafe'" | Warning |
| `for_unsafe_without_unsafe` | "for-in loop uses unsafe constructs but is not marked with 'unsafe'" | Warning |
| `no_unsafe_in_unsafe` | "no unsafe operations occur within 'unsafe' expression" | Warning |
| `no_unsafe_in_unsafe_for` | "no unsafe operations occur within 'unsafe' for-in loop" | Warning |
| `safe_and_unsafe_attr` | "%kindbase0 cannot be both '@safe' and '@unsafe'" | **Error** |

---

## 5. Inheritance and Conformance Rules

### 5.1 Class Inheritance

When a subclass overrides a safe method with an `@unsafe` method, the compiler diagnoses it. The fix-it suggests making the entire class `@unsafe`:

```swift
class Super {
    func f() { }       // safe
}

class Sub: Super {      // NOTE: make class 'Sub' '@unsafe' to allow unsafe overrides
    @unsafe override func f() { }  // WARNING: override of safe instance method
}
```

If the class itself is `@unsafe`, the override is permitted:

```swift
@unsafe class Sub: Super {
    @unsafe override func f() { }  // OK
}
```

### 5.2 Unsafe Superclass

A class with an `@unsafe` superclass must itself be `@unsafe`:

```swift
@unsafe class UnsafeSuper { }
class UnsafeSub: UnsafeSuper { }  // WARNING: has superclass involving unsafe type
```

### 5.3 Protocol Conformance

There are three levels of conformance safety:

**1. Safe conformance with unsafe witness (error):**
```swift
protocol P { func f() }
struct S: P {           // WARNING: conformance involves unsafe code
    @unsafe func f() { }  // NOTE: unsafe method cannot satisfy safe requirement
}
```

**2. Unsafe conformance (acknowledged):**
```swift
struct S: @unsafe P {   // OK: conformance explicitly marked unsafe
    @unsafe func f() { }
}
```

**3. Unsafe type witness:**
```swift
protocol HasPtr { associatedtype Ptr }
struct S: HasPtr {      // WARNING: conformance involves unsafe code
    typealias Ptr = UnsafePointer<Int>  // NOTE: unsafe type cannot satisfy safe associated type
}
```

### 5.4 Extension-Level `@unsafe`

`@unsafe` on an extension makes function signatures involving unsafe types accepted within that extension, but does NOT suppress conformance diagnostics:

```swift
@unsafe
extension S4: P2 {     // WARNING: conformance still flagged
    @unsafe func proto2Method() { }
}
```

The correct form for suppressing conformance diagnostics is `@unsafe` on the protocol in the inheritance clause:

```swift
extension S4: @unsafe P2 {  // OK: conformance explicitly unsafe
    @unsafe func proto2Method() { }
}
```

### 5.5 Sendable Conformances

`@unchecked Sendable` is inherently unsafe. The enclosing type or extension must be `@unsafe`:

```swift
@unsafe class SendableC1: @unchecked Sendable { }

@unsafe
extension SendableC2: @unchecked Sendable { }
```

---

## 6. For-In Loop Safety

For-in loops have special safety handling because iteration involves two separate unsafe sites:

1. The sequence expression (conformance to `Sequence`)
2. The iterator's `next()` method call

Both sites must be independently covered:

```swift
struct UnsafeAsSequence: @unsafe Sequence, @unsafe IteratorProtocol {
    @unsafe mutating func next() -> Int? { nil }
}

// WRONG: only covers sequence expression
for _ in unsafe uas { }  // Still warns about for-in loop needing unsafe

// CORRECT: both expression and loop marked
for unsafe _ in unsafe uas { }  // OK

// REDUNDANCY: warns if no unsafe operations
for unsafe _ in [1, 2, 3] { }  // WARNING: no unsafe operations
```

When only the iterator is unsafe (not the sequence itself):

```swift
struct SequenceWithUnsafeIterator: Sequence {
    func makeIterator() -> UnsafeIterator { UnsafeIterator() }
}

for _ in swui { }         // WARNING: for-in loop uses unsafe constructs
for unsafe _ in swui { }  // OK: only the iterator part is unsafe
```

---

## 7. Type-Level Annotation Guidelines

### 7.1 Decision Matrix

| Scenario | Annotation | Rationale |
|----------|------------|-----------|
| Type deliberately exposes unsafe operations to callers | `@unsafe struct` | Callers must acknowledge |
| Type has safe API over unsafe storage | `@safe struct` | Encapsulation provides safety |
| Type has both safe and unsafe members | `@safe struct` + `@unsafe` escape hatches | Best granularity |
| Enum with cases containing unsafe types | `@unsafe enum` | Cannot know active case |
| Internal storage class with unsafe internals | `@safe class` | Safe encapsulation |
| Global sentinel with `nonisolated(unsafe)` | `@safe` on the let binding | Encapsulated |

### 7.2 Prefer `@safe` Struct Over `@unsafe` Struct

**Critical**: Marking a struct `@unsafe` makes `self` an unsafe type. Every access to `self` inside that type's methods — including `self.capacity`, `precondition(...)`, and other safe operations — triggers warnings. This creates excessive noise.

```swift
// PROBLEMATIC: @unsafe on struct
@unsafe struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        // WARNING: reference to 'self' involves unsafe type
        precondition(index < capacity)  // Warns about self.capacity!
    }
}

// CORRECT: @safe struct with @unsafe escape hatches
@safe struct Slab<Element> {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    func foo() {
        precondition(index < capacity)  // No warning
        unsafe (storage + index).initialize(to: value)  // Only actual unsafe ops
    }

    @unsafe
    func withUnsafePointer(_ body: (UnsafePointer<Element>) -> R) -> R { ... }
}
```

### 7.3 `@safe` Members Inside `@unsafe` Types

When a type must be `@unsafe`, individual members can be marked `@safe` to allow callers to use them without `unsafe`:

```swift
@unsafe class NotSafe {
    @safe var okay: Int { 0 }
    @safe var safeSelf: NotSafe { unsafe self }
    @safe func memberFunc(_: NotSafe) { }
    @safe subscript(ns: NotSafe) -> Int { 5 }
    @safe static func doStatically(_: NotSafe.Type) { }
    @safe init(_: NotSafe) { }

    func stillUnsafe() { }  // Inherits @unsafe from type
}
```

### 7.4 `@unsafe` Enum for Mixed-Safety Cases

When an enum has cases with unsafe associated values, the entire enum should be `@unsafe`:

```swift
@unsafe
internal enum Storage {
    case owned([UInt8])                       // Safe payload
    case borrowed(UnsafeBufferPointer<UInt8>) // Unsafe payload
}
```

Accessing this enum requires `unsafe` even for the safe case, because the compiler cannot statically determine which case is active.

### 7.5 `~Escapable` Types and Pointer Exposure

**Key insight**: On `~Escapable` types, public pointer properties are **structurally safe**. The view cannot outlive the source, so the pointer cannot dangle. The type system enforces the lifetime boundary that closures (`withUnsafePointer`) enforce by convention.

```swift
// STRUCTURALLY SAFE - ~Escapable prevents pointer from outliving source
@safe public struct View: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<Char>  // Cannot dangle by construction
    public var span: Span<Char> { ... }      // Still preferred for callers
}
```

This changes the severity assessment for pointer exposure:

| Containing type | Public pointer property | Severity | Rationale |
|----------------|------------------------|----------|-----------|
| `Escapable` type | Dangerous | HIGH | Pointer can escape and dangle |
| `~Escapable` type | Structurally safe | LOW | Type system prevents escape |
| Coroutine-scoped (no `~Escapable`) | Safe by convention | MEDIUM | `_read`/`_modify` scope prevents escape, but not enforced by type system |

**Why `@unsafe` is still recommended**: Even on `~Escapable` types, adding `@unsafe` to the pointer property communicates intent — "this is the escape hatch, prefer `span`." The annotation is documentation, not a safety requirement.

**Why coroutine-scoped is MEDIUM, not LOW**: Types like `Property.View` omit `~Escapable` due to a CopyPropagation compiler bug ([MEM-COPY-013]). They are safe by coroutine scope, but this safety depends on the usage pattern (yielded via `_read`/`_modify`), not the type definition. If someone constructs a `Property.View` outside a coroutine, the pointer could dangle.

---

## 8. Expression Placement Rules

### 8.1 Assignment Placement

When assigning to a stored property of unsafe type, `unsafe` wraps the entire assignment, not just the RHS:

```swift
// WRONG: unsafe only on RHS
self.storage = unsafe pointer  // Still warns about self.storage

// CORRECT: unsafe wraps entire assignment
unsafe self.storage = pointer

// CORRECT: unsafe on entire subscript assignment
unsafe pointer[index] = value
```

### 8.2 `.allocate()` Is Not Unsafe

`.allocate()` returns an unsafe type but the allocation call itself is not unsafe:

```swift
// WRONG: unnecessary unsafe on allocate
let storage = unsafe UnsafeMutablePointer<Element>.allocate(capacity: n)

// CORRECT: allocate is safe, assignment to unsafe storage needs unsafe
let storage = UnsafeMutablePointer<Element>.allocate(capacity: n)
unsafe self.storage = storage
```

### 8.3 Closure Bodies

`unsafe` does NOT propagate into closures. Both the outer call and inner operations need separate `unsafe`:

```swift
// WRONG: assumes outer unsafe covers closure body
unsafe array.withUnsafeBufferPointer { buffer in
    print(buffer)  // WARNING: reference to parameter involves unsafe type
}

// CORRECT: both outer call and closure body marked
unsafe array.withUnsafeBufferPointer { buffer in
    unsafe print(buffer)
}
```

### 8.4 String Interpolation

String interpolation with unsafe types needs `unsafe` on the outer expression:

```swift
// WARNING: expression uses unsafe constructs but is not marked with 'unsafe'
_ = "Hello \(unsafe ptr)"

// CORRECT: outer unsafe covers the interpolation expression
_ = unsafe "Hello \(unsafe ptr)"
```

### 8.5 Autoclosures

Both outer `unsafe` and inner `unsafe` work for autoclosures:

```swift
func takesAutoclosure<T>(_ body: @autoclosure () -> T) { }

// Option 1: outer unsafe
unsafe takesAutoclosure(unsafeFunction())

// Option 2: inner unsafe
takesAutoclosure(unsafe unsafeFunction())
```

### 8.6 Switch Expressions

When switching on an `@unsafe` enum, both the switch expression and case patterns need `unsafe`:

```swift
switch unsafe se {
case unsafe someEnumValue: break
default: break
}
```

### 8.7 Optional Binding

When unwrapping optional unsafe pointers, mark the binding:

```swift
if let pointer = unsafe storage.pointer { ... }
guard let storage = unsafe _storage else { return }
```

The compiler specifically suggests `unsafe` on the binding for shorthand `if let`:

```swift
if let pointer { }  // WARNING with fix-it: if let pointer = unsafe pointer { }
```

### 8.8 Yield Expressions

Yielding unsafe values in `_read`/`_modify` accessors needs `unsafe`:

```swift
var yielded: Int {
    _read {
        @unsafe let x = 5
        yield unsafe x
    }
    _modify {
        @unsafe var x = 5
        yield unsafe &x
    }
}
```

---

## 9. Underscore-Prefixed Safety Attributes

These are internal compiler attributes, not public API. Document them for awareness:

| Attribute | Status | Purpose |
|-----------|--------|---------|
| `@_unsafeInheritExecutor` | **DEPRECATED** | For async functions to inherit executor; replaced by `isolated` parameter with `#isolation` |
| `@_unsafeNonescapableResult` | Internal | Marks function result as unsafely non-escapable |
| `@_unsafeSelfDependentResult` | Internal | Accessor result dependency marker |
| `@_allowFeatureSuppression` | Internal | Suppress specific feature flags on declarations |

### Usage Rule

These should NOT be used in ecosystem code. If `@_unsafeNonescapableResult` appears in the ecosystem, it indicates a place where a proper lifetime annotation (`@_lifetime`) should be used instead.

---

## 10. C Interop Safety Patterns

### 10.1 C Type Safety Inference

| C Construct | Swift Safety Inference |
|-------------|----------------------|
| `struct` without pointers | Safe |
| `struct` with pointers | `@unsafe` (inferred) |
| `union` (any) | `@unsafe` for member access |
| `enum` (C enum) | Safe |
| Function with pointer params | `@unsafe` (inferred) |
| `SWIFT_SAFE` annotated struct | `@safe` (explicit) |
| `SWIFT_UNSAFE` annotated struct | `@unsafe` (explicit) |
| `SWIFT_SHARED_REFERENCE` type | Safe (reference counted) |

### 10.2 C Header Annotations

```c
#define SWIFT_SAFE __attribute__((swift_attr("@safe")))
#define SWIFT_UNSAFE __attribute__((swift_attr("@unsafe")))

struct HasPointers { float *numbers; };          // Inferred @unsafe
struct HasPointersSafe { float *numbers; } SWIFT_SAFE;  // Explicitly @safe
struct NoPointersUnsafe { float x; } SWIFT_UNSAFE;      // Explicitly @unsafe
```

### 10.3 Safe C Interop (SE-0447 Span)

Bounds-annotated C functions get safe Swift overloads:

```c
int calculate_sum(const int * __counted_by(len) values __noescape, int len);
```

Generated:
```swift
func calculate_sum(_ values: Span<Int32>) -> Int32  // Safe overload
```

| C Annotation | Swift Mapping |
|-------------|---------------|
| `__counted_by(n)` | `Span<T>` |
| `__sized_by(n)` | `RawSpan` |
| `__noescape` | Non-escaping parameter |
| `__lifetimebound` | Lifetime tied to parameter |

---

## 11. Behavior Without Strict Memory Safety

From `test/Unsafe/unsafe_nonstrict.swift` and `unsafe_feature.swift`:

- `@unsafe` and `@safe` attributes are **accepted** by the compiler without `-strict-memory-safety`
- No warnings are emitted for unsafe operations
- `unsafe` expressions are accepted and suppress the redundancy warning only when strict mode is off
- `#if hasFeature(StrictMemorySafety)` returns `false`
- `@unsafe` conformances (e.g., `struct X: @unsafe P`) are accepted

**Implication**: Packages can annotate their APIs with `@safe`/`@unsafe` proactively, before enabling strict mode. This is the recommended incremental adoption path.

---

## 12. Safe Alternatives: The Span Type

`Span<Element>` (SE-0447) is the safe replacement for `UnsafeBufferPointer<T>`:

| Legacy Pattern | Modern Replacement |
|----------------|-------------------|
| `withUnsafeBufferPointer { }` | `.span` property |
| `withUnsafeMutableBufferPointer { }` | `.mutableSpan` property |
| `func f(_ p: UnsafeBufferPointer<T>)` | `func f(_ s: Span<T>)` |
| `func f(_ p: UnsafeRawBufferPointer)` | `func f(_ s: Span<UInt8>)` or `RawSpan` |
| `UnsafeBufferPointer<T>` return | `Span<T>` return + `@_lifetime` |

Span properties require lifetime annotations:

```swift
public var bytes: Span<UInt8> {
    @_lifetime(borrow self)
    borrowing get { ... }
}

public var mutableBytes: MutableSpan<UInt8> {
    @_lifetime(&self)
    mutating get { ... }
}
```

---

## 13. Best Practice Patterns

### Pattern 1: Safe Public API + Unsafe Escape Hatch

```swift
@safe
public struct Buffer<Element: ~Copyable>: ~Copyable {
    var storage: UnsafeMutablePointer<Element>
    let capacity: Int

    // Safe public API
    public subscript(index: Int) -> Element {
        precondition(index >= 0 && index < capacity)
        return unsafe storage[index]
    }

    // Escape hatch for C interop
    @unsafe
    public borrowing func withUnsafePointer<R: ~Copyable, E: Error>(
        _ body: (UnsafePointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(storage)
    }
}
```

### Pattern 2: `@safe` on `withUnsafe*` Wrappers

When wrapping stdlib `withUnsafe*` methods in a safe interface:

```swift
extension MyArray {
    @safe func withUnsafeBufferPointer<R, E: Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return unsafe try body(.init(start: nil, count: 0))
    }
}
```

Callers can use this without `unsafe`:

```swift
ints.withUnsafeBufferPointer { buffer in
    // buffer parameter is UnsafeBufferPointer — still needs unsafe inside
    let copy = unsafe buffer
    print(buffer.safeCount)         // @safe property: OK
    unsafe print(buffer.unsafeCount)  // @unsafe property: needs unsafe
}
```

### Pattern 3: COW Storage Class

```swift
@safe
@usableFromInline
final class Storage {
    var pointer: UnsafeMutablePointer<Element>?

    init(capacity: Int) {
        let ptr = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
        unsafe (self.pointer = ptr)
    }

    deinit {
        if let pointer = unsafe pointer {
            unsafe pointer.deinitialize(count: count)
            unsafe pointer.deallocate()
        }
    }
}
```

### Pattern 4: `nonisolated(unsafe)` for Global Sentinels

```swift
@safe
@usableFromInline
nonisolated(unsafe) let _emptyBufferSentinel: UnsafeMutablePointer<UInt8> = {
    .allocate(capacity: 0)
}()
```

### Pattern 5: C Interop Wrapper

```swift
@unsafe
public func compute(_ data: UnsafeRawBufferPointer) -> UInt32 {
    guard let base = unsafe data.baseAddress else { return 0 }
    return unsafe c_compute(base, CUnsignedInt(data.count))
}
```

### Pattern 6: Pointer Arithmetic Separation

Extract unsafe operations into named bindings for clarity:

```swift
let start = unsafe bytePointer.advanced(by: lower)
let span = unsafe Span(_unsafeStart: start, count: upper - lower)
```

### Pattern 7: Loop Body Pointer Access

Each pointer access in a loop body needs its own `unsafe`:

```swift
for i in 0..<count {
    try body(unsafe pointer[i])
}
```

---

## 14. Anti-Patterns to Avoid

### Anti-Pattern 1: `@unsafe` on Encapsulating Structs

```swift
// WRONG: makes self unsafe, causing cascading warnings
@unsafe struct Slab<Element> { ... }

// CORRECT: safe encapsulation
@safe struct Slab<Element> { ... }
```

### Anti-Pattern 2: `unsafe` on the Wrong Side of Assignment

```swift
// WRONG: unsafe only covers the RHS value
self.ptr = unsafe value

// CORRECT: unsafe covers the entire assignment including the LHS storage
unsafe (self.ptr = value)
// or equivalently:
unsafe self.ptr = value
```

### Anti-Pattern 3: `unsafe` on `.allocate()`

```swift
// WRONG: allocate() itself is not unsafe
let ptr = unsafe UnsafeMutablePointer<Int>.allocate(capacity: n)

// CORRECT: the assignment to storage is what's unsafe
let ptr = UnsafeMutablePointer<Int>.allocate(capacity: n)
unsafe self.storage = ptr
```

### Anti-Pattern 4: Missing `unsafe` in Closure Bodies

```swift
// WRONG: unsafe doesn't propagate into closures
unsafe data.withUnsafeBytes { buffer in
    compute(buffer)  // WARNING: still needs unsafe
}

// CORRECT
unsafe data.withUnsafeBytes { buffer in
    unsafe compute(buffer)
}
```

### Anti-Pattern 5: Over-Specified `unsafe`

```swift
// WRONG: count is Int (safe), not unsafe
let n = unsafe buffer.count

// CORRECT: only mark actually unsafe operations
let n = buffer.count  // .count is a safe property

// BUT: .first on UnsafeRawBufferPointer IS unsafe (protocol conformance)
let byte = unsafe bytes.first ?? 0
```

### Anti-Pattern 6: `@unsafe` Extension for Conformance Suppression

```swift
// WRONG: @unsafe on extension doesn't suppress conformance diagnostic
@unsafe
extension S4: P2 {         // Still warns about conformance
    @unsafe func proto2Method() { }
}

// CORRECT: @unsafe on the protocol in inheritance clause
extension S4: @unsafe P2 {  // Conformance suppressed
    @unsafe func proto2Method() { }
}
```

### Anti-Pattern 7: Double `unsafe`

```swift
// WRONG: redundant nested unsafe
let byte = unsafe unsafe bytes.first ?? 0  // Inner unsafe is redundant

// CORRECT: single unsafe covers the expression
let byte = unsafe bytes.first ?? 0
```

### Anti-Pattern 8: `unsafe` on Safe `.baseAddress`

```swift
// WRONG: .baseAddress is a safe property (returns optional)
let base = unsafe buffer.baseAddress

// CORRECT: baseAddress access is safe; using the result is what's unsafe
let base = buffer.baseAddress  // Returns UnsafePointer<T>?
if let ptr = unsafe base {     // Unwrapping to unsafe type needs unsafe
    unsafe ptr.pointee          // Dereferencing needs unsafe
}
```

---

## 15. Audit Checklist

For use when auditing any Swift Institute package:

```
[ ] 1. Add .strictMemorySafety() to Package.swift
[ ] 2. swift build 2>&1 — capture all warnings
[ ] 3. Categorize warnings by UnsafeUse kind (Section 3)
[ ] 4. For each type with unsafe storage:
        - Is it an escape hatch? → @unsafe
        - Does it encapsulate safely? → @safe
        - Prefer @safe with @unsafe escape hatches
[ ] 5. For each expression warning:
        - Is the operation actually unsafe? → add `unsafe`
        - Can it be replaced with Span? → migrate
        - Is the `unsafe` on the wrong expression? → move it
[ ] 6. For each conformance warning:
        - @unsafe on the protocol in inheritance clause
[ ] 7. For each override warning:
        - @unsafe on the subclass if needed
[ ] 8. Check for redundant `unsafe` (no_unsafe_in_unsafe warnings)
[ ] 9. Verify: swift build has zero warnings
[ ] 10. Verify: swift test passes
```

---

## 16. Ecosystem-Specific Patterns

### 16.1 Observed Ecosystem Usage (Verified 2026-03-25)

| Pattern | Locations | Count |
|---------|-----------|-------|
| `@unsafe` declarations | swift-path-primitives, swift-hash-table-primitives, swift-darwin-primitives, swift-windows-primitives, swift-linux-primitives | 80+ |
| `@safe` declarations | swift-path-primitives, swift-buffer-primitives, swift-foundations/swift-witnesses | 40+ |
| `unsafe` expressions | All three superrepos | 4,000+ |
| `nonisolated(unsafe)` | swift-memory-primitives, swift-storage-primitives, swift-loader-primitives, swift-tests, swift-io | 70+ |
| `withUnsafe*` calls | All three superrepos | 200+ |
| `unsafeBitCast` | swift-windows-primitives, swift-pdf-rendering, swift-tests, swift-loader | 7 |
| `withoutActuallyEscaping` | swift-tests | 3 |
| `@_rawLayout` | swift-buffer-primitives, swift-tree-primitives, swift-sequence-primitives | Multiple |
| `assumingMemoryBound` | swift-buffer-primitives, swift-hash-table-primitives, swift-machine-primitives, swift-io, swift-strings | 35+ |

### 16.2 Ecosystem Encapsulation Pattern

The ecosystem follows a consistent bifurcation:

```
@safe public struct/type
  ↓ contains
@unsafe internal escape hatch methods (withUnsafePointer etc.)
  ↓ which use
unsafe { ... } expressions (scoped to pointer operations)
```

### 16.3 Dense Unsafe Areas

Packages with the highest concentration of unsafe operations:
1. **swift-path-primitives** — Null-terminated C string handling, pointer arithmetic
2. **swift-buffer-primitives** — Ring, linear, linked, arena buffer implementations
3. **swift-io** — io_uring, kqueue, IOCP kernel I/O
4. **swift-hash-table-primitives** — Slot access via `assumingMemoryBound`
5. **Platform-specific primitives** — Windows, Linux, Darwin kernel bindings

---

## 17. Compiler Internals Reference

For contributors and advanced users.

### 17.1 Key Source Files

| File | Purpose |
|------|---------|
| `include/swift/AST/DeclAttr.def:846-870` | `@unsafe` and `@safe` attribute definitions |
| `include/swift/AST/TypeAttr.def:63` | `@unsafe` type attribute (for conformances) |
| `include/swift/AST/Decl.h:243-250` | `ExplicitSafety` enum |
| `include/swift/AST/UnsafeUse.h:32-63` | 14-kind unsafe use classification |
| `include/swift/Basic/Features.def:258,311` | `MemorySafetyAttributes` and `StrictMemorySafety` features |
| `include/swift/AST/DiagnosticsSema.def:8579-8625` | All safety diagnostics |
| `lib/Sema/TypeCheckUnsafe.cpp` | Core unsafe checking (`enumerateUnsafeUses`, `diagnoseUnsafeType`) |
| `lib/Sema/TypeCheckEffects.cpp:4503-4519` | `unsafe` expression checking |
| `lib/Sema/TypeCheckProtocol.cpp:2641+` | Conformance safety checking |
| `lib/Sema/TypeCheckDeclOverride.cpp:2228-2237` | Override safety checking |
| `lib/Parse/ParseExpr.cpp:426-445` | `unsafe` keyword parsing |
| `include/swift/AST/Expr.h:2210-2225` | `UnsafeExpr` AST node |
| `userdocs/diagnostics/strict-memory-safety.md` | Official user documentation |

### 17.2 Key Test Files

| Test File | What It Verifies |
|-----------|-----------------|
| `test/Unsafe/safe.swift` | `@safe`/`@unsafe` attributes, expression parsing, conformances |
| `test/Unsafe/unsafe.swift` | Witness matching, overrides, owned pointers, exclusivity |
| `test/Unsafe/unsafe-suppression.swift` | `@unsafe` suppression on types, conformances |
| `test/Unsafe/unsafe_concurrency.swift` | `nonisolated(unsafe)`, `@preconcurrency` import |
| `test/Unsafe/unsafe_stdlib.swift` | `withUnsafeBufferPointer` and stdlib interactions |
| `test/Unsafe/unsafe_c_imports.swift` | C interop type inference |
| `test/Unsafe/unsafe_nonstrict.swift` | Behavior without strict mode |
| `test/Unsafe/unsafe_feature.swift` | Feature flag availability |
| `test/Unsafe/safe_argument_suppression.swift` | `@safe` member argument suppression |

---

## 18. Isolation Philosophy

### 18.1 The Virality Problem

Without isolation, unsafety propagates virally through the call graph. If a type exposes a raw pointer as its primary API, every consumer needs `unsafe`, and their callers may too. One unsafe type at the bottom infects every layer above it.

```swift
// Viral: pointer escapes, every consumer needs unsafe
public struct Arena {
    public var start: UnsafeMutableRawPointer
}

func useArena(_ arena: Arena) {
    let ptr = unsafe arena.start         // infected
    let value = unsafe ptr.load(as: Int.self) // infected
}

func higherLevel() {
    unsafe useArena(Arena())             // infection spreads upward
}
```

### 18.2 The Isolation Mechanism: `@safe` Boundaries

SE-0458 provides exactly one tool to stop propagation: **`@safe`**. It tells the compiler "unsafety stops here — my callers are safe."

```swift
@safe
public struct Arena: ~Copyable {
    private var _storage: UnsafeMutableRawPointer

    // Safe public API — callers need NO unsafe keyword
    public func load<T>(at offset: Int, as type: T.Type) -> T {
        precondition(offset >= 0 && offset + MemoryLayout<T>.size <= _allocated)
        return unsafe _storage.load(fromByteOffset: offset, as: type)
    }

    // Escape hatch — callers MUST use unsafe keyword
    @unsafe public var start: UnsafeMutableRawPointer { unsafe _storage }
}
```

### 18.3 The Three Roles

Every declaration plays exactly one of three roles:

| Role | Annotation | Caller Obligation | Purpose |
|------|-----------|-------------------|---------|
| **Absorber** | `@safe` | None | Encapsulates unsafe internals behind a safe API |
| **Propagator** | `@unsafe` | Must use `unsafe` | Escape hatch that pushes safety responsibility to caller |
| **Unspecified** | (none) | Depends on signature | Compiler infers from types in signature |

The goal is to **maximize absorbers** and **minimize propagators**. Every `@unsafe` declaration is a leak in the safety boundary. Every `@safe` declaration is a firewall.

### 18.4 Boundary Placement Rule

**The `@safe` boundary should be as LOW as possible** — as close to the raw pointer operations as you can get. This minimizes the amount of code that must reason about safety.

```
┌──────────────────────────────────────────────────────┐
│  Layer N: Pure safe Swift                             │
│  No unsafe keyword appears anywhere                   │
│  (swift-standards is 100% this)                       │
├──────────────────────────────────────────────────────┤
│  @safe public types                                   │
│  Safe API: subscripts, Span properties, methods       │
│  @unsafe escape hatches: withUnsafePointer etc.       │
├──────────────────────────────────────────────────────┤
│  unsafe expressions                                   │
│  Pointer arithmetic, memory binding, C calls          │
│  Confined to method bodies of @safe types             │
└──────────────────────────────────────────────────────┘
```

### 18.5 Five Isolation Rules

**Rule 1: Never `@unsafe struct` for encapsulating types** [MEM-SAFE-021]

Marking a struct `@unsafe` makes `self` an unsafe type, infecting every method body — including safe operations like `precondition(index < capacity)`. Use `@safe struct` with `@unsafe` escape hatch methods instead.

**Rule 2: `@unsafe` only on escape hatches, never on the primary API** [MEM-SAFE-022]

If the primary API requires `unsafe` at the call site, isolation has failed. The `@unsafe` method should be the one callers reach for reluctantly (C interop, performance-critical paths), not by default.

**Rule 3: Private unsafe storage, never public pointers** [MEM-SAFE-023]

A public `UnsafePointer` property on a `@safe` type is a contradiction. The type claims to be safe but exposes the unsafe internals. Make pointer storage `private` or `internal`; expose `Span` as the normative public API.

**Rule 4: `@unchecked Sendable` requires `@unsafe`** [MEM-SAFE-024]

SE-0458 treats `@unchecked Sendable` as inherently unsafe — it removes the compiler's data-race prevention without proof of safety. Without `@unsafe`, the conformance silently passes through strict memory safety checking.

**Rule 5: `nonisolated(unsafe)` globals require `@safe` when encapsulated** [MEM-SAFE-025]

Safely encapsulated globals (allocated once, never mutated, used as sentinels) should have `@safe` to assert the invariant and prevent the `nonisolated(unsafe)` from propagating warnings to consumers.

### 18.6 The Acid Test

For any type with unsafe internals:

> Can a caller use this type's complete public API without ever writing the `unsafe` keyword?

If yes — the type is properly isolated. The unsafe code is contained.
If no — every caller that touches the unsafe API inherits the obligation, and their callers may too. Each `@unsafe` in the public API is a deliberate, documented escape hatch — not the primary interface.

---

## Outcome

**Status**: DECISION

The Swift safety model as implemented in SE-0458 provides a comprehensive, expression-level mechanism for identifying and acknowledging unsafe operations. The Swift Institute ecosystem should:

1. **Isolate unsafe code** — place `@safe` boundaries as low as possible, maximizing absorbers and minimizing propagators (Section 18)
2. **Never `@unsafe struct`** for encapsulating types — use `@safe struct` with `@unsafe` escape hatches
3. **Private unsafe storage** — never expose raw pointers as public properties; use `Span` as the normative interface
4. **`@unchecked Sendable` requires `@unsafe`** — every unchecked conformance must be explicitly marked
5. **Enable `.strictMemorySafety()`** in `Package.swift` for all packages
6. **Follow the expression placement rules** in Section 8 to avoid common pitfalls
7. **Avoid the anti-patterns** documented in Section 14
8. **Use the audit checklist** in Section 15 for systematic compliance verification

This document serves as the canonical reference for the ecosystem safety audit.

## References

1. [SE-0458: Opt-in Strict Memory Safety Checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)
2. [Swift Memory Safety Vision Document](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md)
3. [SE-0447: Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
4. [SE-0446: Non-escapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable-types.md)
5. [SE-0456: Span-providing Properties](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md)
6. Swift Compiler Source: `swiftlang/swift` — `include/swift/AST/UnsafeUse.h`, `lib/Sema/TypeCheckUnsafe.cpp`, `test/Unsafe/`
7. Prior ecosystem research: `swift-binary-primitives/Research/SE-0458 Strict Memory Safety.md`
8. Prior ecosystem research: `swift-binary-primitives/Research/SE-0458 Audit Methodology.md`
