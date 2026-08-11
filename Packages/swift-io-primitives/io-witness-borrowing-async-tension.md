# IO Witness: borrowing + async Closure Tension

<!--
---
version: 1.0.0
last_updated: 2026-04-13
status: OPEN
tier: 1
---
-->

## The Problem

The IO witness closures are `async` and take `borrowing Kernel.Descriptor`:

```swift
let _read: (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(Error) -> Int
```

For the blocking strategy, the implementation needs to dispatch the syscall to
a dedicated OS thread (not the cooperative pool). This requires passing the
descriptor to a `Task` on a blocking executor:

```swift
read: { descriptor, buffer in
    let executor = pool._executors.next()
    return await withCheckedContinuation { continuation in
        Task<Void, Never>(executorPreference: executor) {
            let count = try Kernel.IO.Read.read(descriptor, into: rawBuffer)
            //                                  ^^^^^^^^^^ borrowing captured in sending closure
            continuation.resume(returning: count)
        }
    }
}
```

**Compiler error**: `passing closure as a 'sending' parameter risks causing data
races between code in the current task and concurrent execution of the closure`

The `borrowing` parameter is a reference to the caller's stack. The Task closure
executes concurrently on another thread. The compiler correctly rejects sharing
a borrowed reference with concurrent work.

## Why This Is Fundamental

- `async` closures are inherently escaping — they must survive across suspension points.
- `borrowing Kernel.Descriptor` is a non-owning reference — it cannot escape.
- Dispatching to a blocking thread requires the descriptor to be accessible from that thread.
- `Kernel.Descriptor` is `~Copyable` — it cannot be copied to the thread.
- `Kernel.Descriptor` IS `Sendable` — it CAN cross isolation boundaries via `sending`.

The tension: the consumer borrows the descriptor (they want to use it again after
read returns). The blocking implementation needs the descriptor on another thread.
Borrowing + concurrent access = data race.

## Options

### A. Sync closures, async bridge outside

The witness closures are **sync**. The blocking strategy does the syscall
directly — the `async` suspension lives at a higher level:

```swift
let _read: (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) throws(Error) -> Int
```

For blocking: the syscall blocks the current thread. `IO.run(.blocking())`
ensures the body runs on a blocking-safe thread.

For reactor: the event loop polls for readiness, THEN calls the sync `_read`
knowing it won't block.

**Pro**: borrowing works — no escaping, no thread dispatch inside the closure.
**Con**: the async experience becomes the runtime's problem, not the witness's.
The witness can't control HOW it suspends. `IO.run` needs strategy awareness.

### B. The closures take `sending` (not `borrowing`)

```swift
let _read: (_ from: sending Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(Error) -> Int
```

The caller sends the descriptor to the closure. The closure owns it for the
duration. When the closure returns, the descriptor is sent back (implicitly,
via the call returning).

**Issue**: `sending` is a parameter convention, not a borrow. The caller gives
up their region. But the consumer wants to keep the descriptor — they call
read multiple times on the same socket.

This might work with `inout sending`:
```swift
let _read: (_ from: inout sending Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(Error) -> Int
```

The descriptor is exclusively transferred for the duration of the call, then
transferred back. No concurrent access.

**Pro**: ownership-correct, async works naturally.
**Con**: `inout` in closure types is unusual. Need to verify compiler support.
Call site becomes `try await io.read(from: &descriptor, into: buffer)`.

### C. The descriptor provides a scoped raw accessor

```swift
extension Kernel.Descriptor {
    public func withRawValue<R>(_ body: (Int32) throws -> R) rethrows -> R {
        body(_raw)
    }
}
```

The closure receives the raw fd (Int32, Copyable, Sendable) within a scoped
borrow. The raw fd can be captured and dispatched to the blocking thread.

**Pro**: the borrow is explicit and scoped.
**Con**: the raw fd is usable after the borrow ends (same lifetime issue).
The scoping is advisory, not enforced.

### D. withExtendedLifetime

Force the descriptor alive for the duration of the async operation:

```swift
read: { descriptor, buffer in
    return withExtendedLifetime(descriptor) {
        // dispatch to thread, use raw fd
    }
}
```

**Con**: does not compose with ~Copyable. `withExtendedLifetime` copies.

## Recommendation

**Option B (`inout sending`)** is the ownership-correct solution. It uses
Swift's region transfer to give the closure exclusive access to the descriptor
for the duration of the async call, then returns it.

If `inout sending` doesn't work in closure types, **Option A (sync closures)**
is the fallback — push the async bridge to the runtime level.

## Experiment Needed

1. Does `inout sending Kernel.Descriptor` work as a parameter in a closure type?
2. Does the @Witness macro handle `inout` parameters in closures?
3. Can `IO.run` compose with sync closures to provide an async experience?

## References

- `../../../swift-foundations/swift-io/Sources/IO Core/IO.swift` — IO witness definition
- `../../../swift-foundations/swift-io/Sources/IO Blocking/IO+Blocking.swift` — blocked factory
- Memory: `feedback_no_sendable_constraint_workaround.md` — fix region transfer, don't add Sendable
- Memory: `inout-sending-mechanism.md` — Mutex.withLock uses `inout sending`
