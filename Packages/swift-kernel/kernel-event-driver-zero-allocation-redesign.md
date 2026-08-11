# Kernel Event Driver Zero-Allocation Redesign

<!--
---
version: 1.0.0
last_updated: 2026-04-09
status: DECISION
---
-->

## Context

WIP commit `c4f6cde` implements `Kernel.Event.Driver` with a witness pattern
(struct of closures wrapping backend-specific kernel operations with common
infrastructure). The architecture is sound but the implementation has four
issues identified in `HANDOFF.md`:

1. **Double-close**: Explicit `Kernel.Close.close()` calls on descriptors that
   are already `~Copyable` with `deinit` — redundant and dangerous.
2. **Heap allocation per poll**: Backend `poll` closure returns `[Kernel.Event]`
   (heap-allocated). Epoll also allocates a temporary `[Poll.Event]` per call.
3. **Kevent construction repetition**: The `(rawFd, interest, flags, id) →
   [Kqueue.Event]` pattern is duplicated across add/modify/remove/arm.
4. **Unnecessary complexity**: Registry interaction is correct but verbose.

Additionally, per user directive: zero-copy and zero-allocation on the hot path,
adherence to [IMPL-INTENT], [IMPL-002], [IMPL-064], [API-NAME-002].

## Questions

1. What should the backend poll closure signature be for zero-allocation?
2. How should descriptor lifecycle be managed given `~Copyable` ownership?
3. How should kevent construction be factored?

## Analysis

### Question 1: Backend Poll Signature

#### Option A: Return array (current)

```swift
poll: (Duration?, Int) throws(Error) -> [Kernel.Event]
```

- Heap-allocates `[Kernel.Event]` per poll cycle.
- Epoll also allocates `[Poll.Event]` per poll (separate from the result).
- Two allocations on every poll call — the hottest path in the system.

#### Option B: Backend fills caller's buffer via `inout [Kernel.Event]`

```swift
poll: (Duration?, inout [Kernel.Event]) throws(Error) -> Int
```

Backend responsibilities:
1. Calls platform syscall into its own **pre-allocated** scratch array
   (stored in state class, reused across polls — zero per-poll allocation).
2. Normalizes raw events → `Kernel.Event` and writes into caller's buffer
   via subscript access.
3. Returns count of events written.

Driver.init `_poll` then does in-place staleness compaction:

```swift
let rawCount = try poll(duration, &buffer)
return shared.registry.withLock { entries in
    var write = 0
    for read in 0..<rawCount {
        if entries.contains(buffer[read].id) {
            if write != read { buffer[write] = buffer[read] }
            write += 1
        }
    }
    return write
}
```

- Zero allocation on hot path (scratch arrays pre-allocated at factory time).
- **Zero `unsafe` code** — all access via `inout` arrays and subscripts.
- Backend owns normalization — correct, since it knows the platform types.
- Single closure per backend (no visitor/callback overhead).
- In-place compaction avoids separate filter buffer.

#### L1 API Compatibility

Both platforms provide `inout [Event]` poll APIs:
- kqueue: `Kernel.Kqueue.poll(_:into:timeout:)` → `inout [Event]`
- epoll: `Kernel.Event.Poll.wait(_:events:timeout:)` → `inout [Event]`

Pre-allocated arrays in state classes eliminate per-poll allocation without
requiring buffer-pointer variants at L1. No `unsafe`, no `Memory.Buffer.Mutable`.

**Decision: Option B.**

### Question 2: Descriptor Lifecycle

`Kernel.Descriptor` is `~Copyable` with:
```swift
deinit { guard isValid else { return }; _ = Darwin.close(_raw) }
```

`Registration` stores `let descriptor: Kernel.Descriptor`. When `Registration`
is dropped, `Kernel.Descriptor.deinit` fires → fd closed. Per [IMPL-064], the
type system enforces correct cleanup.

Current code has explicit `Kernel.Close.close()` in:
- `_register` error path — **wrong**: descriptor deinit already handles it.
- `_deregister` — **wrong**: removing Registration from dictionary → deinit.
- `_close` drain — **correct by omission**: drain receives `consuming Entry` →
  Registration consumed → deinit.

**Decision**: Remove all explicit `Kernel.Close.close()` calls. Lifecycle is
entirely managed by `~Copyable` cascading deinit.

### Question 3: Kevent Construction

The pattern repeats in add/modify/remove/arm:
```swift
var events: [Kernel.Kqueue.Event] = []
if interest.contains(.read) { events.append(Kqueue.Event(..., filter: .read, ...)) }
if interest.contains(.write) { events.append(Kqueue.Event(..., filter: .write, ...)) }
try Kernel.Kqueue.register(selector.descriptor, events: events)
```

Since `Kernel.Kqueue.register` takes `[Event]`, array allocation is inherent.
These operations (register, modify, deregister, arm) are **not on the hot path**
— they happen once per fd registration, not per poll cycle.

**Decision**: Extract a static helper:
```swift
private static func register(
    _ kq: borrowing Kernel.Descriptor,
    rawFd: Int32,
    id: Kernel.Event.ID,
    interest: Kernel.Event.Interest,
    flags: Kernel.Kqueue.Flags
) throws(Kernel.Event.Driver.Error)
```

This eliminates 4× duplication. Array allocation for register ops is acceptable.

## Outcome

**Status**: DECISION

### Architecture

```
Caller buffer: [Kernel.Event] (pre-allocated, passed as inout)
                    ↑ normalized events (zero-copy into caller's memory)
Backend scratch: platform-specific raw buffer (pre-allocated at factory time)
                    ↑ raw syscall events
Kernel: kevent() / epoll_wait()
```

### Witness Signature Change

```swift
// Before (allocates per poll)
poll: (Duration?, Int) throws(Error) -> [Kernel.Event]

// After (zero-allocation, no unsafe)
poll: (Duration?, inout [Kernel.Event]) throws(Error) -> Int
```

### Responsibility Split

| Concern | Owner |
|---------|-------|
| ID generation (plain counter, thread-confined) | Driver.init |
| Registry (Dictionary on thread-confined Shared class) | Driver.init |
| Deadline → duration | Driver.init |
| Staleness suppression (in-place compaction) | Driver.init |
| Descriptor lifecycle | ~Copyable deinit (no explicit close) |
| Scratch buffer ownership | Backend state class |
| Platform syscall | Backend closure |
| Raw → Kernel.Event normalization | Backend closure |

### Files Changed

All 7 files in `Sources/Kernel Event/`:
- `Driver.swift` — new poll signature, remove explicit close, in-place staleness
- `Source.swift` — no changes (poll signature already `inout [Kernel.Event]`)
- `Source+Kqueue.swift` — extract kevent helper, inout poll, remove close, remove unsafe
- `Source+Epoll.swift` — pre-allocate scratch array in state, remove close
- `Driver.Registration.swift` — unchanged (already correct)
- `Driver.Error.swift` — unchanged
- `exports.swift` — remove `Memory_Buffer_Primitives` import

## References

- `HANDOFF.md` — problem statement and open questions
- `Research/unified-completion-api-design.md` — parallel architecture for completions
- L1 kqueue API: `Kernel.Event.Queue.poll(_:into:timeout:)` buffer-pointer variant
- L1 epoll API: `Kernel.Event.Poll.wait(_:events:timeout:)` array-only
