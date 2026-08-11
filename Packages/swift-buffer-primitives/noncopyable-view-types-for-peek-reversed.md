# Non-Copyable View Types for Peek and Reversed

<!--
---
version: 1.0.0
last_updated: 2026-02-11
status: DECISION
tier: 1
---
-->

## Context

During the refactoring of `List.Linked` to delegate to `Buffer.Linked<N>`, the `Peek` and `Reversed` view types broke. These types provide the nested accessor API (`list.peek.first { }`, `list.reversed.forEach { }`) required by [API-NAME-002].

The original implementation stored `_storage: Storage` (a `ManagedBuffer` subclass, a class = always Copyable). This gave non-mutating, safe access because:

1. **Class reference = Copyable**: Peek/Reversed could store it regardless of Element's copyability.
2. **Live header**: `_storage.header` reflected current state (part of the class instance).
3. **CoW safety**: After `makeUnique()`, the old class instance remained consistent (Peek held a retaining reference).

With `Buffer.Linked<N>`, the storage model changed:

- `storage: Storage<Node>.Pool` — class reference, always Copyable
- `header: Header` — value type (struct), always Copyable
- `Buffer.Linked` itself — `~Copyable` (declared as such)

The header is no longer part of the class. It's a value type stored alongside the class reference. This changes the safety properties of snapshot-based views.

**Trigger**: Pattern selection — multiple patterns could apply. [RES-001]

**Constraints**:
- Swift 6.2 with `Lifetimes` experimental feature enabled
- `InternalImportsByDefault` and `MemberImportVisibility` enabled
- Must work for both `Copyable` and `~Copyable` elements
- `Buffer.Linked<N>.storage` and `.header` are `package` access (not visible cross-package)

## Question

How should `Peek` and `Reversed` view types be implemented to provide non-mutating (or minimally-mutating) nested accessor access to `Buffer.Linked<N>` elements when the buffer is `~Copyable`?

## Analysis

### Option A: Copyable-Internals Snapshot at Buffer Layer

Declare `Peek` and `Reversed` structs inside `Buffer.Linked` that store only the Copyable internals (`Storage<Node>.Pool` + `Header`). Always Copyable. Non-mutating `peek` property copies the class reference + header struct.

```swift
public struct Peek: Copyable, Sendable {
    let _storage: Storage<Node>.Pool
    let _header: Header
}

public var peek: Peek {
    Peek(_storage: storage, _header: header)
}
```

**Advantages**:
- Non-mutating property — works on `let` bindings
- Simple implementation — no pointers, no lifetime annotations
- Always Copyable — no `~Escapable` complexity
- [PATTERN-022] compliant — struct declared inside `Buffer.Linked` body

**Disadvantages**:
- **Unsound for `~Copyable` elements**: The `Header` is a snapshot. After list mutation, `_header.head` points to a potentially deallocated pool slot. For Copyable elements, CoW (`makeUnique()`) creates a new pool, keeping the old one consistent. For `~Copyable` elements, there is no CoW — the pool is mutated in place, creating a stale-header / live-pool mismatch.
- Peek is always Copyable (can be stored), so the unsoundness is reachable without `unsafe`.
- Duplicates peek logic at the buffer level (reads through Pool + Header directly).

**Soundness verdict**: **Unsound** for `~Copyable` elements. Sound for `Copyable` elements (CoW guarantees snapshot consistency).

### Option B: Property.View.Read at List Layer

Use `Property<Peek, List.Linked>.View.Read` with `mutating _read`. The view stores an `UnsafePointer<List.Linked>` with lifetime bounded by the `_read` coroutine.

```swift
extension List.Linked where Element: ~Copyable {
    enum Peek {}

    public var peek: Property<Peek, Self>.View.Read {
        mutating _read {
            yield unsafe Property<Peek, Self>.View.Read(
                UnsafePointer(Property<Peek, Self>.View(&self).base)
            )
        }
    }
}

extension Property.View.Read
where Tag == List<Element>.Linked<N>.Peek,
      Base == List<Element>.Linked<N>,
      Element: ~Copyable
{
    public func first<R>(_ body: (borrowing Element) -> R) -> R? {
        unsafe base.pointee._buffer.peekFront(body)
    }

    public func last<R>(_ body: (borrowing Element) -> R) -> R? {
        unsafe base.pointee._buffer.peekBack(body)
    }
}
```

**Advantages**:
- **Sound**: Pointer lifetime bounded by `_read` coroutine. `~Escapable` prevents storing the view.
- Follows established `Property.View.Read` pattern per [IMPL-021].
- No hand-rolled accessor structs — uses the Property primitives infrastructure.
- Single implementation for both Copyable and `~Copyable` elements.
- Methods access the live buffer through the pointer (no stale snapshot).

**Disadvantages**:
- `mutating _read` required — `peek` cannot be called on `let` bindings.
- Tag enum (`Peek`) may trigger [PATTERN-022] constraint poisoning if declared in extension file. Must be in the Linked struct body or Core file.
- `Property.View.Read` is `~Copyable, ~Escapable` — callers cannot store the view (by design).

### Option C: Property.View.Read at Buffer Layer

Same as Option B but at the Buffer level. Buffer.Linked exposes `peek` as a `Property.View.Read`.

```swift
extension Buffer.Linked where Element: ~Copyable {
    enum Peek {}

    public var peek: Property<Peek, Self>.View.Read {
        mutating _read {
            yield unsafe Property<Peek, Self>.View.Read(
                UnsafePointer(Property<Peek, Self>.View(&self).base)
            )
        }
    }
}
```

List.Linked then exposes its own `peek` that delegates.

**Advantages**:
- Sound for same reasons as Option B.
- Centralizes the view logic at the buffer layer.
- Both List.Linked and Queue consumers can delegate.

**Disadvantages**:
- Same `mutating _read` requirement as B.
- Creates a `Property.View.Read` chain: List's peek yields a view whose method accesses `_buffer`, which would need its own `mutating _read`... This nests mutating contexts. Unclear if this compiles cleanly.
- Tag enum in Buffer might feel semantically misplaced (Peek is a consumer-level concept).

### Option D: Flatten the API

Remove Peek/Reversed structs. Provide direct methods on List.Linked:

```swift
extension List.Linked where Element: ~Copyable {
    public func peekFirst<R>(_ body: (borrowing Element) -> R) -> R? {
        _buffer.peekFront(body)
    }

    public func peekLast<R>(_ body: (borrowing Element) -> R) -> R? {
        _buffer.peekBack(body)
    }
}
```

**Advantages**:
- Simplest implementation — direct delegation.
- Non-mutating — works on `let` bindings.
- Sound — no intermediate view types, no snapshot issues.
- No [PATTERN-022] concerns — no nested type declarations.

**Disadvantages**:
- **Violates [API-NAME-002]**: `peekFirst` and `peekLast` are compound identifiers.
- Inconsistent with the nested accessor pattern used elsewhere in the codebase.
- Loses the conceptual grouping that `peek.first` / `peek.last` provides.

### Option E: ~Copyable + ~Escapable View with Non-Mutating _read

Make Peek `~Copyable, ~Escapable`, use a non-mutating `_read` coroutine, and borrow the buffer via pointer.

```swift
public struct Peek: ~Copyable, ~Escapable {
    let _ptr: UnsafePointer<Buffer<Element>.Linked<N>>

    @_lifetime(borrow ptr)
    init(_ptr: UnsafePointer<Buffer<Element>.Linked<N>>) {
        self._ptr = unsafe ptr
    }
}

public var peek: Peek {
    _read {
        // Need pointer to _buffer without &self...
        yield unsafe Peek(_ptr: ???)
    }
}
```

**Advantages**:
- Would be non-mutating if it compiled.
- `~Escapable` prevents storing the view.

**Disadvantages**:
- **Does not compile**: Getting an `UnsafePointer` inside a non-mutating `_read` requires `withUnsafePointer(to:)`, which is closure-scoped. The pointer cannot escape the closure to be yielded by the coroutine. Swift does not currently provide a coroutine-compatible borrow-to-pointer conversion without `&self` (which requires `mutating`).
- This is a fundamental Swift language limitation, not a design choice.

**Verdict**: **Not viable** with current Swift.

### Option F: Closure-Based API

Wrap the peek operation in a closure:

```swift
public func peek<R>(_ body: (PeekView) -> R) -> R {
    body(PeekView(_buffer: _buffer))
}
```

**Advantages**:
- Non-mutating.
- Sound (PeekView lifetime bounded by closure scope).

**Disadvantages**:
- Changes API shape: `list.peek { $0.first { } }` instead of `list.peek.first { }`.
- Double-nested closures for element access — poor ergonomics.
- Not consistent with the nested accessor pattern.

### Option G: Split Paths — Copyable Non-Mutating + ~Copyable Mutating

Provide two `peek` overloads based on Element's copyability:

- `where Element: Copyable`: Non-mutating, returns Copyable snapshot (safe due to CoW).
- `where Element: ~Copyable`: `mutating _read`, returns `Property.View.Read` (safe due to pointer lifetime).

**Advantages**:
- Copyable elements get the ideal ergonomics (non-mutating, `let` compatible).
- `~Copyable` elements get sound access (pointer-bounded).

**Disadvantages**:
- Two separate implementations and return types for the same `peek` property.
- Overload resolution may cause confusion or ambiguity.
- Maintenance burden — two code paths to keep in sync.
- The Copyable path's Peek struct still needs [PATTERN-022]-safe declaration.

### Comparison

| Criterion | A: Snapshot | B: Prop.View.Read (List) | C: Prop.View.Read (Buffer) | D: Flatten | E: Non-mut _read | F: Closure | G: Split |
|-----------|:-----------:|:------------------------:|:--------------------------:|:----------:|:-----------------:|:----------:|:--------:|
| Sound (~Copyable) | **No** | Yes | Yes | Yes | N/A | Yes | Yes |
| Sound (Copyable) | Yes | Yes | Yes | Yes | N/A | Yes | Yes |
| Non-mutating | Yes | **No** | **No** | Yes | N/A | Yes | Partial |
| `list.peek.first { }` API | Yes | Yes | Yes | **No** | N/A | **No** | Yes |
| [IMPL-021] compliant | Partial | Yes | Yes | N/A | N/A | N/A | Yes |
| [API-NAME-002] compliant | Yes | Yes | Yes | **No** | N/A | Yes | Yes |
| [PATTERN-022] safe | Yes (in body) | Needs care | Needs care | Yes | N/A | Yes | Needs care |
| Simplicity | High | Medium | Medium | High | N/A | Medium | Low |
| Compiles (Swift 6.2) | Yes | Yes | Unclear | Yes | **No** | Yes | Yes |

## Constraints

1. **Swift limitation**: Non-mutating `_read` cannot yield a pointer-based `~Escapable` type because `withUnsafePointer(to:)` is closure-scoped, not coroutine-scoped. This eliminates Option E.
2. **[PATTERN-022]**: Tag enums and view structs for `~Copyable`-generic parents must be declared in the same file as the parent type (inside its body) to avoid constraint poisoning.
3. **Existing API**: `list.first` and `list.last` already exist as non-mutating properties for Copyable elements. The `peek.first { }` closure-based API exists **specifically** for `~Copyable` elements that cannot be returned by value.
4. **Usage pattern**: `~Copyable` lists are always `var` (you must `prepend`/`append` to populate them). Requiring `var` for `peek` is not a practical ergonomic issue.

## Key Insight

The `peek.first { }` API exists exclusively for `~Copyable` elements. Copyable elements use `list.first` / `list.last` (non-mutating, return by value). So the `mutating _read` requirement of `Property.View.Read` only affects `~Copyable` use cases — which always use `var` anyway.

This means the non-mutating vs. mutating trade-off is **not a real trade-off**: the only users of `peek` are `~Copyable` element users who already have `var` access.

## Outcome

**Status**: DECISION

**Chosen**: **Option B — Property.View.Read at the List layer** (with `Read.Typed<Element>.Valued<N>` to avoid constraint poisoning)

Rationale:

1. **Sound** for both Copyable and `~Copyable` elements — no stale-header risk.
2. **Follows [IMPL-021]** — uses the established Property.View.Read infrastructure, no hand-rolled accessor structs.
3. **The `mutating _read` cost is zero in practice** — `peek` is only used for `~Copyable` elements, which are always `var`.
4. **Single implementation** — no split paths or overload complexity.
5. **Compositional** — the same pattern works for `Reversed`, `Peek`, and future view types.

Implementation notes:

- Tag enums (`Peek`, `Reversed`) declared inside the `Linked` struct body in `List.Linked.swift` (Core file) to satisfy [PATTERN-022].
- `Property.View.Read` extensions in `List.Linked ~Copyable.swift` and `List.Linked.Bounded.swift` (operations files).
- `list.first` / `list.last` remain as non-mutating Copyable convenience (already exist).
- Buffer.Linked retains `peekFront` / `peekBack` / `forEachReversed` as direct methods — the Property.View.Read extensions delegate to these.
- **Implementation note**: `Property.View.Read` alone is insufficient when both `Element` and `N` are generic — method-level generics on `Property.View.Read` extensions cause constraint poisoning through the `Tag == List<Element>.Linked<N>.Peek` path. The solution is `Property.View.Read.Typed<Element>.Valued<N>`, where `Element` and `N` are the type's own parameters, not method-level generics. This type was created in swift-property-primitives to solve this problem.

## References

- [IMPL-000] Call-Site-First Design
- [IMPL-021] Property vs Property.View
- [IMPL-022] _read + _modify for Mutating Property Accessors
- [API-NAME-002] No Compound Identifiers
- [PATTERN-022] ~Copyable Constraint Poisoning Prevents File Splitting
- Property.View.Read documentation in swift-property-primitives
