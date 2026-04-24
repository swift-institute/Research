# View vs Span: Borrowed Access Types for Null-Terminated Storage

<!--
---
version: 1.0.0
last_updated: 2026-02-28
status: DECISION
---
-->

## Context

During the Tagged migration (Phase 2: `Kernel.Path = Tagged<Kernel, Path>`), a cross-module ambiguity arose with `View` typealiases on Tagged. Before solving the ambiguity (via a `Viewable` protocol), we need to answer a prior question: **does the View type need to exist at all?**

Both `Path` and `String` in primitives follow the same pattern:
- An **owned** type (`Path`, `String`) — `~Copyable`, owns a `Memory.Contiguous<Char>` buffer
- A **view** type (`Path.View`, `String.View`) — `~Copyable, ~Escapable`, holds a single `UnsafePointer<Char>`
- **Span** (`Span<Char>`) — stdlib type, holds pointer + count, `~Escapable`

The question is whether View is a distinct concept or merely a less-capable Span.

**Trigger**: Architecture choice during Tagged migration. [RES-001]

**Scope**: Primitives-wide — affects path-primitives, string-primitives, identity-primitives, and the Tagged forwarding architecture. [RES-002a]

**Tier**: 2 (Standard) — affects multiple packages, establishes semantic contract, reversible but costly. [RES-020]

## Question

Is `View` (`Path.View` / `String.View`) a necessary type, or should it be replaced by `Span<Char>`?

## Analysis

### What each type represents

Starting from first principles, a null-terminated byte sequence admits three **distinct** borrowed access levels:

| Property | `View` | `Span<Char>` | `UnsafePointer<Char>` |
|----------|--------|--------------|----------------------|
| Null-termination guarantee | Yes | No | No |
| Known length | No (O(n) scan) | Yes (O(1)) | No |
| Bounds-checked access | No | Yes | No |
| `~Escapable` (lifetime-safe) | Yes | Yes | No |
| Safe C string extraction | Yes | No | No |
| Can be created without allocation | Yes | Yes | Yes |

The key insight: **View guarantees null-termination. Span guarantees bounded length. These are orthogonal invariants.** Neither subsumes the other.

### Why null-termination matters

The entire reason `Path` and `String` exist in primitives is C interop — syscalls (POSIX, Windows) expect null-terminated strings. Every syscall boundary needs a pointer that is guaranteed null-terminated.

Empirical evidence from the codebase (33 function signatures taking View as a parameter):

| Usage pattern | Count | What it needs |
|---------------|-------|---------------|
| Extract pointer for C syscall (`open`, `stat`, `unlink`, `rmdir`, etc.) | 28 | Null-terminated pointer |
| Convert to `Swift.String` via `String(cString:)` | 3 | Null-terminated pointer |
| Bridge to another View type | 1 | Null-terminated pointer |
| Copy bytes (`pointer` + `length`) | 1 | Pointer + count |

**31 of 33 consumers need the null-termination guarantee.** Only 1 needs length.

### Why Span cannot replace View

If a function accepts `Span<UInt8>`, it gets a pointer + count but **no guarantee about what follows the bounded region**. To pass the pointer to a C function expecting `const char*`, it would need to assume (without type-level proof) that `span.baseAddress[span.count] == 0`. This is unsound.

```swift
// With View — sound:
func delete(_ path: borrowing Path.View) throws(Error) {
    path.withUnsafePointer { cString in  // guaranteed null-terminated
        unlink(cString)
    }
}

// With Span — unsound:
func delete(_ path: borrowing Span<UInt8>) throws(Error) {
    // path.baseAddress points to `count` bytes...
    // but is path.baseAddress[path.count] == 0? No guarantee.
    unlink(path.baseAddress!)  // ← undefined behavior if not null-terminated
}
```

### Why View cannot replace Span

Span provides O(1) bounds-checked element access. View stores only a pointer — it has no count until it scans (O(n)). For algorithms that iterate, slice, or index into bytes, Span is the correct type.

### Where Views are created (the non-owned source argument)

If Views were only created from owned types, we could argue "just borrow the owned type." But Views are also created from **raw syscall pointers** that are NOT owned:

| Source | API | Why View is needed |
|--------|-----|-------------------|
| `dlerror()` | Returns `const char*` — transient, owned by libc | Can't wrap in owned String without allocation |
| `getenv()` | Returns `const char*` — owned by environment | Can't wrap in owned String without allocation |
| `realpath()` | Returns `char*` — caller must free | View borrows until `free()`, no allocation needed |
| `readlink()` | Fills stack buffer | View borrows stack, no heap allocation |

Without View, these sites would need to **allocate an owned type** just to pass a pointer to the next function. View avoids this allocation entirely.

### Option A: Keep View as-is

View stores a single pointer. Count is O(n).

**Advantages**: Minimal (1 word). Clear distinction from Span. Exists today.

**Disadvantages**: `.count` and `.span` are O(n) — must scan for null terminator every time.

### Option B: Eliminate View, use Span everywhere

Replace all `Path.View` / `String.View` parameters with `Span<Char>`.

**Advantages**: One fewer type. Simpler mental model.

**Disadvantages**: Loses null-termination guarantee at the type level. C interop becomes unsound (or requires unsafe cast). Functions can't declare "I need a C string" in their signature.

**Verdict**: Unsound. Rejected.

### Option C: Eliminate View, use `borrowing Path` / `borrowing String` directly

Replace all `Path.View` parameters with `borrowing Path`.

**Advantages**: One fewer type. Borrows are already safe.

**Disadvantages**: Cannot handle the 4 syscall-return sites where you have a raw pointer but no owned type. Would require allocating an owned type to wrap every `dlerror()`, `getenv()`, `realpath()`, `readlink()` result. Wasteful and defeats the purpose.

**Verdict**: Rejected for syscall-return sites.

### Option D: Eliminate View, use closure-based APIs only

Replace `borrowing Path.View` parameters with `path.withUnsafeCString { ptr in ... }` closures.

**Advantages**: One fewer type. Closures enforce scoping.

**Disadvantages**: Functions taking multiple paths become deeply nested closures:
```swift
source.withUnsafeCString { src in
    dest.withUnsafeCString { dst in
        clone(from: src, to: dst)  // raw UnsafePointer — no type safety
    }
}
```
The inner function takes `UnsafePointer` — losing both `~Escapable` safety and the null-termination type-level guarantee. The ISO 9945 layer has functions taking 2-3 path parameters; closure nesting becomes unwieldy.

**Verdict**: Rejected — loses type safety, poor ergonomics for multi-parameter functions.

### Option E: View with cached count (pointer + count)

View stores pointer + count (2 words). All operations become O(1).

**Advantages**: `.count` is O(1). `.span` is O(1). Still guarantees null-termination. Strictly more informative than Span (it's a "Span that also guarantees null-termination").

**Disadvantages**: 2 words instead of 1. Creation from syscall pointers requires a `strlen()` scan — but this is unavoidable regardless (any consumer needing the count must scan).

**Relationship to Span**: View(pointer+count) ⊃ Span. View can produce a Span in O(1) by dropping the null-termination guarantee. Span cannot produce a View (can't add the guarantee).

### Comparison

| Criterion | A: View (pointer) | B: Span only | C: borrowing Path | D: Closures only | E: View (ptr+count) |
|-----------|-------------------|-------------|-------------------|-------------------|---------------------|
| Null-termination guarantee | Yes | **No** | Yes | Raw pointer | Yes |
| O(1) count | **No** | Yes | Yes | N/A | Yes |
| Non-owned sources (syscall ptrs) | Yes | Yes | **No** | Yes | Yes |
| Multi-param function ergonomics | Yes | Yes | Yes | **No** | Yes |
| `~Escapable` safety | Yes | Yes | Yes | **No** | Yes |
| Type-safe C interop | Yes | **No** | Yes | **No** | Yes |
| Size (words) | 1 | 2 | N/A | 0 | 2 |

### Prior Art

**Rust**: `CStr` (borrowed null-terminated) vs `&[u8]` (borrowed slice) vs `CString` (owned null-terminated). Three distinct types — exactly our View/Span/Path distinction. `CStr` stores pointer only (length computed on demand), though there's ongoing discussion about caching length.

**C**: `const char*` serves as both View and Span — no type-level distinction. This is widely recognized as a deficiency (buffer overflows from missing length, null-termination assumptions).

**Swift stdlib**: `Span<T>` was introduced in Swift 6 as the safe borrowed contiguous access type. There is no stdlib equivalent of "null-terminated span" because the stdlib doesn't deal with C strings at the primitives level.

## Outcome

**Status**: DECISION

**View is necessary.** It occupies a unique and irreducible position in the type hierarchy:

```
Owned (Path/String)     — owns buffer, O(1) count, null-terminated
    ↓ borrow
View (Path.View)        — borrows pointer, null-terminated, ~Escapable
    ↓ drop null-termination guarantee
Span<Char>              — borrows pointer+count, bounded, ~Escapable
    ↓ drop bounds
UnsafePointer<Char>     — raw pointer, no safety
```

Each level drops exactly one guarantee. Removing View collapses two levels — losing either type-safe C interop (Option B), non-owned source support (Option C), or multi-parameter ergonomics (Option D).

**Recommendation: Option E (View with cached count)** is the ideal long-term design. It makes View a strict superset of Span's information content while preserving the null-termination invariant. However, this is a separate implementation decision from the existence question.

**Immediate implication for Tagged migration**: The `Viewable` protocol approach is correct — View is a real concept that Tagged should forward via `associatedtype View: ~Copyable, ~Escapable`.

## References

- Experiment: `swift-tagged-primitives/Experiments/tagged-view-struct/` — confirms Tagged.View struct approach
- Experiment: `swift-tagged-primitives/Experiments/tagged-view-protocol/` — confirms Viewable protocol approach
- Rust `CStr`: https://doc.rust-lang.org/std/ffi/struct.CStr.html
- Swift Evolution SE-0447: Span — contiguous access without ownership
