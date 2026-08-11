# io_uring SQE Pointer Elimination

<!--
---
version: 2.0.0
last_updated: 2026-04-12
status: DECISION
---
-->

## Context

The io_uring Prepare API exposes `UnsafeMutablePointer<Entry>` in the public API and lost `@inlinable` because Prepare method bodies reference `internal var cValue: io_uring_sqe`.

`Lifetimes` and `LifetimeDependence` are enabled in this package.

## Question

Can the SQE preparation API eliminate pointers from the public surface and restore @inlinable using `~Copyable ~Escapable` slot types?

## Analysis

### V3 (REFUTED): ~Escapable via function return

```swift
func nextEntry() -> Slot? { return Slot(pointer: ptr) }
```

Fails: `@lifetime(borrow self)` + `mutating func` = "invalid use of borrow dependence with inout ownership." And without @lifetime, "lifetime-dependent value escapes its scope." The compiler cannot trace lifetime through `UnsafeMutablePointer` indirection.

### V6 (CONFIRMED): ~Escapable via coroutine yield

```swift
public var next: Slot {
    mutating _read {
        yield unsafe Slot(pointer: entries.advanced(by: tail))
    }
}
```

The `_read` coroutine scope IS the lifetime boundary. No `@lifetime` annotation needed on the property — the coroutine semantics provide it. This is the same pattern `Property.View` uses throughout the ecosystem (599 sites per yielding-vs-returning research).

### Architecture

```
Ring.next        →  mutating _read   →  yields ~Escapable Slot
  Slot.entry     →  nonmutating _modify  →  yields inout Entry (writes through pointer)
    Entry.read() →  @inlinable mutating  →  accesses public/@usableFromInline accessors
```

Call site:
```swift
ring.next.entry.read(target: .descriptor(fd), buffer: buf, length: len, offset: .zero, data: id)
ring.next.entry.flags.insert(.link)  // same slot — tail unchanged
ring.advance()                       // explicit advance

ring.next.entry.timeout(link: timespec, clock: .monotonic, data: linkData)
ring.advance()

let n = ring.flush()
```

Each `ring.next` access is an independent `_read` coroutine — accesses the current tail slot. Multiple accesses without `advance()` hit the same slot (correct for setting flags after preparation). `advance()` is called explicitly after each SQE is fully configured.

### Why @inlinable works

Entry's mutating methods access `self.opcode`, `self.addr`, `self.len` — public typed accessors. Overloaded union fields via `@usableFromInline` internal accessors (`_fd`, `_rawLength`, `_rawFlags`, etc.). No `cValue` reference in any @inlinable body.

Chain: `@inlinable` Slot.entry (_modify) → `@inlinable` Entry.read (mutating) → public/`@usableFromInline` Entry accessors.

### What gets eliminated

| Current | After |
|---------|-------|
| Prepare type + 65 methods | **Eliminated** — 65 mutating methods on Entry |
| 21 planned view types | **Eliminated** |
| `UnsafeMutablePointer<Entry>` in public API | **Zero** — Slot hides it |
| `UnsafeMutablePointer.prepare` accessor | **Eliminated** — `ring.next.entry` |

### What's created

- `Kernel.IO.Uring.Slot` — 1 type (`~Copyable ~Escapable`, wraps pointer, 1 file)
- `Ring.next` — 1 `_read` coroutine property
- ~11 `@usableFromInline` computed properties on Entry (overloaded union field accessors)

## Outcome

**Status**: DECISION

**V6 architecture**: `~Copyable ~Escapable` Slot yielded via `mutating _read` coroutine. Preparation methods become `mutating` on Entry. The Prepare type and all view types are eliminated.

**Validated by**: `swift-institute/Experiments/escapable-slot-inlinable-sqe/` — V6 CONFIRMED, correct field values written through the coroutine chain.

### Implementation path

1. Add ~11 `@usableFromInline` raw field accessors to Entry
2. Move all 65 Prepare methods to `mutating` on Entry (with `@inlinable`)
3. Create `Kernel.IO.Uring.Slot` (`~Copyable ~Escapable`, 1 file)
4. Add `Ring.next: Slot` property (`mutating _read` coroutine)
5. Change `Target.apply(to:)` to take `inout Entry`
6. Delete Prepare type, `UnsafeMutablePointer.prepare` accessor, all view-type files
7. Restore `@usableFromInline` on `Clock.timeoutBits`, `Poll.Trigger.pollBits`, `File.Xattr.Disposition.rawBits`
8. Update tests

## References

- Experiment: `swift-institute/Experiments/escapable-slot-inlinable-sqe/`
- Ecosystem pattern: Property.View `_read`/`_modify` coroutine yield (599 sites)
- Research: `swift-primitives/Research/yielding-vs-returning-lifetime-models.md`
- Research: `swift-institute/Research/nonescapable-ecosystem-state.md`
- [PLAT-ARCH-005a], [IMPL-071], [IMPL-064], [IMPL-065], [IMPL-COMPILE]
