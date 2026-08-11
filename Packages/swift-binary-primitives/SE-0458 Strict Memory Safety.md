# Swift Strict Memory Safety: Comprehensive Overview
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: COMPLETE
---
-->

> A PhD-level reference document on Swift's strict memory safety features, based on SE-0458 and related proposals.

## Core Framework: SE-0458 (Opt-in Strict Memory Safety Checking)

Swift 6.2 introduces an **opt-in strict memory safety mode** that identifies and flags all uses of unsafe constructs. This is NOT intended to become the default language mode—it's designed for codebases where memory safety is an absolute requirement (security-critical libraries, elevated-privilege code).

### Five Dimensions of Memory Safety

| Dimension | Mechanism | Status |
|-----------|-----------|--------|
| **Lifetime Safety** | ARC, memory exclusivity | Default |
| **Bounds Safety** | Runtime bounds checking | Default |
| **Type Safety** | Safe casting operators | Default |
| **Initialization Safety** | Definite initialization | Default |
| **Thread Safety** | Strict concurrency (Swift 6) | Opt-in complete |

---

## Enabling Strict Memory Safety

**Compiler flag:**
```bash
swiftc -strict-memory-safety
```

**Swift Package Manager:**
```swift
.target(
    name: "MyTarget",
    swiftSettings: [.strictMemorySafety()]
)
```

**Conditional compilation:**
```swift
#if hasFeature(StrictMemorySafety)
// Strict mode specific code
#endif
```

---

## The `@unsafe` and `@safe` Attributes

**`@unsafe`** — marks declarations as unsafe to use:
```swift
@unsafe
public struct UnsafeBufferPointer<Element> { ... }
```

**`@safe`** — indicates a declaration is safe despite having unsafe types in its signature:
```swift
extension Array {
    @safe func withUnsafeBufferPointer<R>(
        _ body: (UnsafeBufferPointer<Element>) throws -> R
    ) rethrows -> R
}
```

---

## `unsafe` Expression Syntax

Similar to `try` and `await`, the `unsafe` keyword acknowledges unsafe operations:

```swift
func sum(_ array: [Int]) -> Int {
    array.withUnsafeBufferPointer { buffer in
        unsafe crc32(0, buffer.baseAddress, buffer.count)
    }
}
```

Key design principle: **unsafety does NOT propagate outward**—a `@safe` function can contain `unsafe` expressions internally.

---

## What Triggers Unsafe Diagnostics

### Language Constructs
- `unowned(unsafe)`
- `nonisolated(unsafe)`
- `@exclusivity(unchecked)`
- `unsafeAddressor` / `unsafeMutableAddressor`
- `@preconcurrency` imports

### Standard Library Types (marked `@unsafe`)
- `UnsafePointer`, `UnsafeMutablePointer`
- `UnsafeRawPointer`, `UnsafeMutableRawPointer`
- `UnsafeBufferPointer`, `UnsafeMutableBufferPointer`
- `unsafeBitCast`, `unsafeDowncast`
- `Optional.unsafelyUnwrapped`
- `UnsafeContinuation`, `Unmanaged`

### Unsafe Compiler Flags (error under strict mode)
- `-Ounchecked`
- `-enforce-exclusivity=unchecked` or `=none`
- `-strict-concurrency` != `complete`
- `-disable-access-control`

### C/C++ Interoperability
- Imported C functions with pointers → implicitly `@unsafe`
- C structs containing pointers → inferred `@unsafe`

---

## Safe Alternatives: The `Span` Type (SE-0447)

`Span<Element>` is the **safe replacement for `UnsafeBufferPointer`**:

```swift
extension Array {
    var span: Span<Element> { get }  // SE-0456
}
```

**Key properties:**
- Non-escapable (SE-0446) — cannot outlive creating scope
- Bounds-checked at compile time with **zero runtime overhead**
- Eliminates use-after-free and out-of-bounds access by construction

---

## Safe C/C++ Interoperability

**Bounds annotations** enable safe Swift projections:

```c
// C header
int calculate_sum(
    const int * __counted_by(len) values __noescape,
    int len
);
```

**Generated Swift overload:**
```swift
func calculate_sum(_ values: Span<Int32>) -> Int32
```

**Key annotations:**

| Annotation | Purpose |
|------------|---------|
| `__counted_by(n)` | Pointer has `n` elements → maps to `Span<T>` |
| `__sized_by(n)` | Pointer has `n` bytes → maps to `RawSpan` |
| `__noescape` | Parameter doesn't escape function scope |
| `__lifetimebound` | Return value's lifetime tied to parameter |

**Enable with:**
```bash
-enable-experimental-feature SafeInteropWrappers
```

---

## Incremental Adoption Model

The design ensures **isolation**:

1. Modules not enabling strict checking see **zero diagnostics** from dependencies that do
2. `@unsafe` is NOT part of the type system—no propagation through generics
3. Any unsafe use can be addressed locally:
   - **Encapsulate** via `@safe(unchecked)` (rare)
   - **Propagate** with `@unsafe`
   - **Acknowledge** with `unsafe { }` expression

---

## Key Design Principles

| Principle | Rationale |
|-----------|-----------|
| **Expression-level granularity** | Narrowest possible unsafe scope (unlike Rust's blocks) |
| **No ABI impact** | Compile-time only; retroactive adoption possible |
| **Auditability** | Tooling can enumerate all `unsafe` expressions in a module |
| **Not default** | Safe APIs (`Span`) need ecosystem adoption time; C interop needs annotations |

---

## Related Proposals

| SE | Title | Status |
|----|-------|--------|
| [SE-0446](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable-types.md) | Non-escapable Types | Accepted |
| [SE-0447](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) | Span: Safe Access to Contiguous Storage | Accepted |
| [SE-0456](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) | Span-providing Properties | Accepted |
| [SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md) | Opt-in Strict Memory Safety | Accepted |

---

## Sources

- [SE-0458: Opt-in Strict Memory Safety Checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)
- [Memory Safety Vision Document](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md)
- [Swift 6.2 Released](https://www.swift.org/blog/swift-6.2-released/)
- [Safely Mixing Swift and C/C++](https://www.swift.org/documentation/cxx-interop/safe-interop/)
- [SE-0447: Span Proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
