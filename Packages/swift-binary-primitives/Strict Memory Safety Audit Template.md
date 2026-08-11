# Strict Memory Safety Audit Template
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: COMPLETE
---
-->

> Reusable methodology for auditing Swift packages against SE-0458 strict memory safety standards.

## Pre-Audit Setup

### 1. Enable Strict Memory Safety

Add to `Package.swift`:
```swift
let settings: [SwiftSetting] = [
    // ... existing settings
    .strictMemorySafety(),
]
```

### 2. Build and Capture Warnings

```bash
swift build 2>&1 | tee build-output.txt
```

---

## Audit Checklist

### Phase 1: Architecture Review

#### 1.1 API Surface Analysis

| Question | Answer | Notes |
|----------|--------|-------|
| Does the package expose raw pointers in its public API? | | |
| Are there `Span<T>` equivalents for pointer-based APIs? | | |
| Is there a clear safe/unsafe distinction in naming or structure? | | |

#### 1.2 Protocol Design

| Pattern | Present | Location |
|---------|---------|----------|
| Safe normative API (e.g., `Span<T>`) | | |
| Unsafe escape hatch (clearly marked) | | |
| `~Copyable` / `~Escapable` where appropriate | | |

---

### Phase 2: Warning Resolution

#### 2.1 Common Warning Categories

| Warning Type | Action Required |
|--------------|-----------------|
| "expression uses unsafe constructs but is not marked with 'unsafe'" | Add `unsafe` expression |
| "no unsafe operations occur within 'unsafe' expression" | Remove unnecessary `unsafe` |
| "reference to unsafe type 'UnsafeXXX'" | Acknowledge with `unsafe` at assignment |
| "'@unsafe' conformance of X to protocol Y involves unsafe code" | Add `unsafe` to protocol method call |

#### 2.2 Warning Resolution Patterns

**Pattern A: Unsafe method call**
```swift
// Before
destination.withBytes.mutable { ptr in ... }

// After
unsafe destination.withBytes.mutable { ptr in ... }
```

**Pattern B: Unsafe type assignment**
```swift
// Before
let ptr = buffer.baseAddress

// After
let ptr = unsafe buffer.baseAddress
// OR if inside unsafe closure and type involves UnsafePointer:
let ptr = unsafe srcBase
```

**Pattern C: Unsafe protocol conformance**
```swift
// Before
guard !source.isEmpty else { return }

// After (when source is UnsafeRawBufferPointer)
guard unsafe !source.isEmpty else { return }
```

**Pattern D: Nested unsafe not needed**
```swift
// Before (over-specified)
unsafe outer.method { inner in
    unsafe inner.property  // Warning: no unsafe operations
}

// After
unsafe outer.method { inner in
    inner.property  // OK - already in unsafe context for method call
}
```

---

### Phase 3: Type-Level Safety Annotations

#### 3.1 `@unsafe` Struct/Enum

Use when the type **deliberately exposes unsafe operations**:
```swift
@unsafe
public struct WithBytes: ~Copyable, ~Escapable {
    // This type exists as an escape hatch to raw pointers
}
```

#### 3.2 `@safe` Struct

Use when the type **encapsulates unsafe storage in a safe interface**:
```swift
@safe
public struct Input: @unchecked Sendable {
    @unsafe
    internal enum Storage {
        case owned([UInt8])
        case borrowed(UnsafeBufferPointer<UInt8>)
    }
}
```

#### 3.3 Decision Matrix

| Scenario | Annotation |
|----------|------------|
| Type is an escape hatch to unsafe APIs | `@unsafe struct` |
| Type has safe API but unsafe internal storage | `@safe struct` with `@unsafe` internal members |
| Type's internal enum has unsafe cases | `@unsafe enum` |
| Individual unsafe method on otherwise safe type | `@unsafe func` |

---

### Phase 4: Verification

#### 4.1 Build Check

```bash
swift build 2>&1 | grep -E "(warning|error).*unsafe"
```

Expected output: **No warnings**

#### 4.2 Test Suite

```bash
swift test
```

Expected: All tests pass (no behavioral changes from safety annotations)

#### 4.3 Documentation Review

Verify unsafe constructs are documented:
- [ ] `@unchecked Sendable` usage documented with rationale
- [ ] `@unsafe` methods have doc comments explaining safety requirements
- [ ] Any `@safe(unchecked)` usage has justification

---

## Common Pitfalls

### 1. Over-applying `unsafe`

**Wrong:**
```swift
unsafe source.withBytes { srcBuffer in
    guard let srcBase = unsafe srcBuffer.baseAddress else { return }
    let count = unsafe srcBuffer.count
}
```

**Correct:**
```swift
unsafe source.withBytes { srcBuffer in
    guard let srcBase = srcBuffer.baseAddress else { return }
    let count = srcBuffer.count
}
```

Inside an `unsafe` closure, only mark operations that are themselves unsafe (like `copyMemory`, `load(as:)`).

### 2. Arithmetic with unsafe types

**Wrong:**
```swift
offset + unsafe source.count  // Error: cannot appear to right of operator
```

**Correct:**
```swift
let sourceCount = source.count  // Extract first if safe property
offset + sourceCount
```

### 3. Confusing safe property access vs unsafe type reference

| Operation | Unsafe? | Why |
|-----------|---------|-----|
| `buffer.count` on `UnsafeBufferPointer` | No | Property access is safe |
| `buffer.isEmpty` on `UnsafeRawBufferPointer` | Yes | Collection conformance is `@unsafe` |
| `let ptr = buffer.baseAddress` | Yes | Assigning to pointer type |
| `ptr.copyMemory(...)` | Yes | Memory operation |

---

## Audit Report Template

```markdown
# SE-0458 Strict Memory Safety Audit: [Package Name]

## Summary
- **Package:** [name]
- **Version:** [version]
- **Audit Date:** [date]
- **Status:** [Compliant / Non-Compliant / Needs Work]

## Findings

### Warnings Resolved
| File | Line | Warning | Resolution |
|------|------|---------|------------|
| | | | |

### Type Annotations Added
| Type | Annotation | Rationale |
|------|------------|-----------|
| | | |

### Remaining Issues
| Issue | Severity | Notes |
|-------|----------|-------|
| | | |

## Verification
- [ ] `swift build` completes with no strict memory safety warnings
- [ ] `swift test` passes
- [ ] Documentation updated

## Recommendations
[List any architectural recommendations]
```

---

## References

- [SE-0458: Opt-in Strict Memory Safety](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)
- [SE-0446: Non-escapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-nonescapable-types.md)
- [SE-0447: Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [Memory Safety Vision](https://github.com/swiftlang/swift-evolution/blob/main/visions/memory-safety.md)
