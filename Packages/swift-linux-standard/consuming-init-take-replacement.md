# Handoff: Replace `take()` Methods with Consuming Init on Target Type

> Pattern established in step 6 of the io_uring refactor:
> `Kernel.Descriptor(consume eventDescriptor)` replaces `eventDescriptor.take()`.
> The init lives on the TARGET type, consuming the SOURCE type.

## Pattern

**Before** (take method on source):
```swift
extension SourceType {
    public consuming func take() -> TargetType {
        innerProperty
    }
}
// call site: let target = source.take()
```

**After** (consuming init on target):
```swift
extension TargetType {
    public init(_ source: consuming SourceType) {
        self = source.innerProperty
    }
}
// call site: let target = TargetType(consume source)
```

Per [PATTERN-012]: type transformations live in initializers on the target type.

## Candidates

### Replaceable — wrapper extracts a single inner type

| # | Source Type | `take()` Location | Return Type | Status |
|---|-----------|-------------------|-------------|--------|
| 1 | `Kernel.Event.Descriptor` | `Linux.Kernel.Event.Descriptor.swift:158` | `Kernel.Descriptor` | **DONE** — `Kernel.Descriptor(consume eventDescriptor)` |
| 2 | `Async.Channel.Unbounded` | `Async.Channel.Unbounded.swift:113` | `Take` | Init already exists (`Take(channel: consume self)`). Remove `take()` — it's a redundant forwarding method. |
| 3 | `Async.Channel.Bounded` | `Async.Channel.Bounded.swift:112` | `Take` | Same as #2. Init already exists. Remove `take()`. |

### NOT replaceable — structural mismatch

| # | Source Type | `take()` Location | Return Type | Why Not |
|---|-----------|-------------------|-------------|---------|
| 4 | `Memory.Contiguous<E>` | `Memory.Contiguous.swift:85` | `(pointer, count)` | Returns tuple — no target type for init. Uses `discard self` to bypass deinit. This is raw decomposition, not wrapper extraction. |
| 5 | `Path` | `Path.swift:140` | `(pointer, count)` | Delegates to `Memory.Contiguous.take()`. Same tuple issue. |
| 6 | `String` | `String.swift:170` | `(pointer, count)` | Delegates to `Memory.Contiguous.take()`. Same tuple issue. |
| 7 | `Tagged<String>` | `Tagged+String.swift:93` | `(pointer, count)` | Delegates to `String.take()`. Same tuple issue. |
| 8 | `Tagged<Path>` | `Tagged+Path.swift:100` | `(pointer, count)` | Delegates to `Path.take()`. Same tuple issue. |
| 9 | `Bit.Vector` | `Bit.Vector+take.swift:24` | `Bit.Vector` | Mutating swap pattern — returns same type with original data, leaves self empty. Not a wrapper extraction. |
| 10 | `Bit.Vector.Bounded` | `Bit.Vector.Bounded+take.swift:24` | `Bit.Vector.Bounded` | Same swap pattern as #9. |
| 11 | `Ownership.Unique<V>` | `Ownership.Unique.swift:92` | `Value` | Generic — can't add `init(consuming Ownership.Unique<Self>)` to arbitrary Value types without a protocol requirement. Mutating (deallocates storage). |

### Excluded — infrastructure types where `take()` IS the API

- `Optional.take()` — stdlib-equivalent pattern, stays as-is
- `Ownership.Transfer.Cell.take()`, `Storage.take()`, `Retained.take()` — one-shot transfer infrastructure
- `Ownership.Slot.Store.take()` — reusable atomic slot
- `Async.Publication.take()` — class-based, not ~Copyable wrapper

## Decision Criteria

A `take()` method is replaceable with a consuming init when ALL of:
1. The return type is a **single named type** (not a tuple)
2. The operation is a **wrapper extraction** (not decomposition, swap, or generic box)
3. The target type is **known and concrete** (init can be placed on it)
4. No `discard self` is needed (consuming init runs implicit memberwise deinit)

## Next Steps

1. Remove `take()` from `Async.Channel.Unbounded` and `Async.Channel.Bounded` (#2, #3) — the `Take(channel:)` init already exists.
2. Audit future ~Copyable wrapper types for the pattern: prefer consuming init on target over `take()` on source.
3. The tuple-returning cases (#4–8) are a different pattern — they're raw resource decomposition for C interop. `discard self` is load-bearing. Leave as-is.
