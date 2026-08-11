# Platform-Adaptive String Representation for Operating System Interfaces
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: RECOMMENDATION
---
-->

## Abstract

This paper presents a type design for representing operating system native strings in Swift, addressing the fundamental incompatibility between POSIX byte-oriented paths and Windows UTF-16 paths. We introduce `String_Primitives.String` with a platform-conditional character type: `CChar` on POSIX systems and `UInt16` on Windows. This design enables type-safe interaction with OS APIs while maintaining a unified programming model. We employ Swift's non-copyable types (`~Copyable`) and non-escapable types (`~Escapable`) to encode ownership and lifetime invariants, preventing common memory safety bugs in systems programming. The design complements `swift-iso-9899` for ISO C semantics and integrates with `swift-strings` for high-level bridging.

## 1. Introduction

Operating system interfaces present a fundamental string representation challenge: POSIX and Windows have incompatible path encoding requirements.

**POSIX** (macOS, Linux, BSD): File system paths are byte sequences, conventionally UTF-8 encoded, passed to system calls as `char*`. The kernel treats paths as opaque byte strings with `/` as separator and `\0` as terminator.

**Windows**: Unicode-correct path handling requires UTF-16 encoding via wide-character APIs (`wchar_t*`). The narrow `char*` APIs use the Active Code Page (ACP), a legacy mechanism that cannot represent arbitrary Unicode text and varies by system locale.

A cross-platform systems library must address this divergence. Naive approaches fail:

- **Always use bytes**: Breaks Unicode paths on Windows.
- **Always use UTF-16**: Inefficient on POSIX, semantic mismatch with kernel expectations.
- **Always use Swift.String**: Overhead for every syscall, doesn't address the underlying type mismatch.

This work presents a platform-adaptive type that matches OS expectations on each platform while providing a unified Swift API.

## 2. Background

### 2.1 POSIX Path Semantics

POSIX.1-2017 specifies paths as "strings" composed of bytes, with interpretation largely left to individual file systems. The kernel APIs (`open`, `stat`, `readdir`) accept `char*` parameters. While modern practice uses UTF-8 encoding, the kernel performs no encoding validation—paths are byte sequences.

Key characteristics:
- Character type: `char` (typically `signed char` on x86, `unsigned char` on ARM)
- Terminator: null byte (`'\0'`)
- Encoding: conventionally UTF-8, but not enforced
- Maximum length: `PATH_MAX` (typically 4096 bytes including terminator)

### 2.2 Windows Path Semantics

Windows NT-based systems use Unicode internally. The wide-character APIs (`CreateFileW`, `_wfopen`) accept `wchar_t*` parameters containing UTF-16 encoded text. The ANSI APIs (`CreateFileA`, `fopen`) perform internal conversion from the Active Code Page to UTF-16.

Key characteristics:
- Character type: `wchar_t` (16-bit on Windows)
- Terminator: null `wchar_t` (`L'\0'`)
- Encoding: UTF-16LE (with surrogate pairs for characters outside BMP)
- Maximum length: approximately 32,767 characters for extended-length paths

Using ANSI APIs on Windows is problematic:
1. ACP varies by system locale (e.g., Windows-1252 in Western Europe, Shift-JIS in Japan).
2. Characters outside the ACP cannot be represented.
3. Paths created by other applications (using Unicode) may be inaccessible.

### 2.3 Relationship to ISO C Strings

ISO C's `<string.h>` functions operate on `char*` byte sequences. These functions work identically on all platforms—`strlen` counts bytes, `strcpy` copies bytes. This is distinct from OS path semantics:

- ISO C `strlen("/path/file.txt")` returns 14 on all platforms.
- Windows `_wcslen(L"/path/file.txt")` returns 14 (UTF-16 code units).
- These are different operations with different types.

The `swift-iso-9899` package addresses ISO C byte strings with `Char = UInt8` always. This package addresses OS-native path strings with platform-conditional `Char`.

## 3. Design Principles

**P1. Match Platform Expectations**: The character type must match what OS APIs expect. POSIX expects `char*`; Windows (for Unicode correctness) expects `wchar_t*`.

**P2. Unified API Surface**: Despite different underlying types, the Swift API should be consistent across platforms. Code that doesn't inspect `Char` directly should compile unchanged.

**P3. Ownership Safety**: Null-terminated strings are a common source of memory bugs. The type system should prevent use-after-free and double-free.

**P4. Zero-Overhead Abstraction**: Wrapper types should not impose runtime cost beyond the underlying operations.

## 4. Type Design

### 4.1 Platform-Conditional Character Type

```swift
extension String {
    #if os(Windows)
    public typealias Char = UInt16
    #else
    public typealias Char = CChar
    #endif

    @inlinable
    public static var terminator: Char { 0 }
}
```

On POSIX, `Char = CChar` matches the `char` type expected by system calls. On Windows, `Char = UInt16` matches `wchar_t` for wide-character APIs.

We use `UInt16` rather than `CWideChar` on Windows for consistency with Swift conventions and to avoid C type leakage in the Windows-specific case.

### 4.2 Owned String Type

```swift
public struct String: ~Copyable {
    @usableFromInline
    internal let pointer: UnsafeMutablePointer<Char>

    public let count: Int

    @inlinable
    deinit {
        pointer.deallocate()
    }
}
```

The owned string type manages heap-allocated null-terminated sequences. Key design elements:

**`~Copyable`**: Prevents implicit copying, enforcing unique ownership. This eliminates double-free bugs where copied pointers lead to multiple deallocations.

**`deinit`**: Automatic deallocation ensures no memory leaks for values that go out of scope normally.

**`count`**: Caches the length (excluding terminator) to avoid repeated traversal.

### 4.3 View Type (Borrowed Access)

```swift
extension String {
    public struct View: ~Copyable, ~Escapable {
        public let pointer: UnsafePointer<Char>

        @inlinable
        @_lifetime(borrow pointer)
        public init(_ pointer: UnsafePointer<Char>) {
            self.pointer = pointer
        }
    }
}
```

The `View` type provides borrowed access to null-terminated sequences without ownership transfer. The `~Escapable` constraint, using Swift's experimental Lifetimes feature, ensures compile-time prevention of escaping references.

This enables safe patterns like:

```swift
func process(_ view: borrowing String.View) {
    // view cannot escape this function
    let len = view.length  // safe: computed during valid lifetime
}

owned.withView { view in
    process(view)  // safe: view lifetime bounded by closure
}
```

### 4.4 Length Computation

```swift
extension String {
    @inlinable
    public static func length(of pointer: UnsafePointer<Char>) -> Int {
        var current = pointer
        while current.pointee != terminator {
            current = current.successor()
        }
        return current - pointer
    }
}
```

Length computation is defined as a static function operating on pointers, usable with both owned strings and views. The implementation is platform-agnostic—it works correctly whether `Char` is `CChar` or `UInt16`.

## 5. Platform-Specific Considerations

### 5.1 POSIX Implementation

On POSIX systems, `String_Primitives.String` is byte-oriented:

```swift
// Creating from C string literal
let path = String_Primitives.String(copying: cStringPointer)

// Passing to system call
let fd = open(path.pointer, O_RDONLY)
```

The `pointer` property yields `UnsafePointer<CChar>`, directly usable with POSIX APIs.

### 5.2 Windows Implementation

On Windows, `String_Primitives.String` is UTF-16 oriented:

```swift
// Creating from Swift.String (UTF-16 encoded)
let path = String_Primitives.String(swiftString)

// Passing to wide-character API
let handle = CreateFileW(
    path.pointer,  // UnsafePointer<UInt16>
    GENERIC_READ,
    0, nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    nil
)
```

The `pointer` property yields `UnsafePointer<UInt16>`, usable with Windows wide-character APIs after appropriate casting to `LPCWSTR`.

### 5.3 Cross-Platform Code

Code that operates abstractly on `String_Primitives.String` without assuming a specific `Char` type compiles on both platforms:

```swift
func logPath(_ path: borrowing String_Primitives.String.View) {
    print("Path length: \(path.length)")  // Works on both platforms
}
```

Code that must handle encoding explicitly can use conditional compilation:

```swift
#if os(Windows)
// UTF-16 specific handling
#else
// UTF-8/byte specific handling
#endif
```

## 6. Integration with String Ecosystem

### 6.1 Relationship to ISO_9899.String

`ISO_9899.String` (from `swift-iso-9899`) represents ISO C byte strings with `Char = UInt8` always. The distinction is semantic:

| Package | Domain | Char Type | Purpose |
|---------|--------|-----------|---------|
| swift-string-primitives | OS paths | `CChar`/`UInt16` | File system operations |
| swift-iso-9899 | ISO C | `UInt8` | C library interop |

On POSIX, both are byte-oriented but with different character types (`CChar` vs `UInt8`). On Windows, they diverge completely (`UInt16` vs `UInt8`).

Direct conversion between these types is provided on POSIX only, where the underlying representation is compatible:

```swift
#if !os(Windows)
extension ISO_9899.String.Owned {
    public init(_ view: borrowing String_Primitives.String.View) {
        // Byte-to-byte copy (CChar to UInt8)
    }
}
#endif
```

On Windows, conversion requires going through `Swift.String` to handle encoding:

```swift
// Windows: Primitives (UTF-16) -> Swift.String -> ISO_9899 (UTF-8 bytes)
let primitives: String_Primitives.String = ...
let swift = Swift.String(primitives)
let iso = ISO_9899.String.Owned(swift)
```

### 6.2 Relationship to swift-strings

The `swift-strings` package provides the bridging layer between string domains:

```swift
// swift-strings provides these extension inits:
extension Swift.String {
    public init(_ view: borrowing String_Primitives.String.View)
    public init(_ owned: consuming String_Primitives.String)
}

extension String_Primitives.String {
    public init(_ string: Swift.String)
}
```

This enables ergonomic conversion:

```swift
let swift: Swift.String = "/path/to/file"
let native = String_Primitives.String(swift)  // Platform-appropriate encoding
```

## 7. Memory Safety Analysis

### 7.1 Ownership Invariants

The `~Copyable` constraint on `String` ensures:

1. **No aliasing**: Only one owner exists for any allocation.
2. **Deterministic deallocation**: `deinit` runs exactly once when the owner is consumed or goes out of scope.
3. **Transfer semantics**: Ownership transfer is explicit via `consuming` parameters.

### 7.2 Lifetime Invariants

The `~Escapable` constraint on `View` ensures:

1. **No escaping**: A view cannot be stored in a property or returned from a function.
2. **Bounded lifetime**: The view's lifetime is statically bounded by its source.
3. **Safe borrowing**: The compiler rejects code that could access a view after its backing storage is invalidated.

### 7.3 Bug Classes Prevented

| Bug Class | Prevention Mechanism |
|-----------|---------------------|
| Double-free | `~Copyable` prevents multiple owners |
| Use-after-free | `~Escapable` prevents escaping views |
| Memory leak | `deinit` ensures deallocation |
| Buffer overread | Length caching avoids repeated traversal |

## 8. Performance Considerations

### 8.1 Allocation Strategy

The current design allocates via `UnsafeMutablePointer<Char>.allocate(capacity:)`. For performance-critical applications, custom allocators could be supported:

```swift
public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int)
```

This initializer adopts an existing allocation, enabling use with arena allocators or memory pools.

### 8.2 Inline Optimization

All public methods are marked `@inlinable`, enabling cross-module optimization. The `@inline(__always)` annotation on critical paths ensures no function call overhead.

### 8.3 Zero-Copy Views

The `View` type provides zero-copy borrowed access. Combined with `~Escapable`, this enables safe patterns without defensive copying:

```swift
path.withView { view in
    // No allocation, just pointer access
    syscall(view.pointer)
}
```

## 9. Limitations and Future Work

**Experimental Dependencies**: The `~Escapable` constraint requires Swift's experimental Lifetimes feature, limiting portability until stabilization.

**Encoding Validation**: The current design does not validate UTF-8 (POSIX) or UTF-16 (Windows) well-formedness. Invalid sequences could propagate to OS APIs.

**Extended-Length Paths**: Windows extended-length paths (`\\?\` prefix) require special handling not currently addressed.

**Symbolic Links**: Path traversal involving symbolic links may require encoding-aware handling on mixed-encoding file systems.

## 10. Conclusion

We have presented a platform-adaptive string type for operating system interfaces that:

1. Matches platform expectations with conditional `Char` types.
2. Provides a unified API surface for cross-platform code.
3. Encodes ownership and lifetime invariants in the type system.
4. Integrates cleanly with ISO C strings and Swift.String via layered architecture.

The design demonstrates that platform divergence can be addressed through careful type design, enabling safe systems programming in Swift without sacrificing platform correctness.

## References

1. IEEE Std 1003.1-2017. POSIX.1-2017: System Interfaces.
2. Microsoft Docs. Naming Files, Paths, and Namespaces.
3. The Swift Programming Language: Ownership.
4. swift-iso-9899: ISO C byte string representation.
5. swift-strings: String domain bridging layer.
