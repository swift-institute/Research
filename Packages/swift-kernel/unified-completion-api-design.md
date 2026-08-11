# Unified Kernel Completion API Design

<!--
---
version: 2.0.0
last_updated: 2026-04-09
status: IN_PROGRESS
tier: 2
related:
  - swift-io/Research/io-uring-integration-architecture.md
  - swift-io/Research/perfect-api.md
  - swift-io/Research/completion-queue-ownership-redesign.md
  - swift-kernel/Research/audit.md
  - swift-primitives/HANDOFF-kernel-event-consolidation.md
---
-->

## Context

Three layers of witness drivers compose:

```
IO.Driver (swift-io, L3)
    ├── IO.Blocking.Driver        → thread pool
    ├── IO.Event.Driver           → wraps Kernel.Event.Driver
    └── IO.Completion.Driver      → wraps Kernel.Completion.Driver

Kernel.Event.Driver (swift-kernel, L3)
    ├── +Kqueue                   → Darwin kqueue
    └── +Epoll                    → Linux epoll

Kernel.Completion.Driver (swift-kernel, L3)
    ├── +IOUring                  → Linux io_uring
    └── +IOCP                     → Windows (future)
```

Each layer translates its types and delegates to the layer below. The consumer
(`IO.run`) never sees the kernel witnesses. The IO driver wraps the kernel
driver. The kernel driver wraps platform syscalls. Witnesses all the way down.

The Readiness pattern (Kernel.Event.Driver with kqueue/epoll backends) is
proven. This document designs the symmetric Kernel.Completion.Driver to the
same standard, informed by the IO-level consumer needs.

## Question

What should `Kernel.Completion` + `Kernel.Completion.Driver` look like, designed
backward from IO.Event.Loop's integration needs and composing from L1 primitives?

## Consumer Perspective: IO.Event.Loop

The integrated event loop (per `io-uring-integration-architecture.md`) runs
one thread per platform:

```
Darwin:  epoll → kqueue
Linux:   epoll + io_uring CQ drain (via eventfd bridge)
Windows: IOCP (IS the loop)
```

On Linux, the Loop does this every iteration:

```
drain jobs from MPSC queue
    → for each: completion.submit(submission, target: fd)
    → completion.flush()

epoll_wait(deadline) → events
for event in events:
    if event is io_uring_notification:
        completion.drain { event in
            entryTable[event.token].resolve(with: event)
        }
    else:
        dispatchReadiness(event)
```

What the Loop needs from `Kernel.Completion`:

| Need | Operation | Detail |
|------|-----------|--------|
| Enqueue operations | `submit` | SQE ring write, non-blocking |
| Commit to kernel | `flush` | `io_uring_enter`, batched |
| Drain completions | `drain` | CQ ring read, callback per event |
| Notification fd | `notification` | eventfd for epoll registration |
| Teardown | `close` | unmap, close fds |

## Proposed API

### L1: Kernel.Completion (resource)

```swift
public struct Completion: ~Copyable {
    /// The operational witness.
    public let driver: Driver

    /// The kernel descriptor (io_uring fd / IOCP handle).
    @_spi(Internal)
    public let descriptor: Kernel.Descriptor

    /// Notification descriptor for event loop integration.
    ///
    /// The Loop registers this with its readiness selector (epoll)
    /// to receive completion signals. When the selector fires for
    /// this descriptor, the Loop calls `drain`.
    ///
    /// On Linux: eventfd registered with io_uring.
    /// -1 when the platform has no separate notification (IOCP).
    @_spi(Internal)
    public let notification: Int32

    /// Thread-safe channel for interrupting blocking waits.
    public let wakeup: Kernel.Wakeup.Channel
}
```

**Change from current**: Added `notification: Int32` — the raw eventfd descriptor
that IO.Event.Loop registers with epoll. Raw Int32 because `Kernel.Event.Descriptor`
is ~Copyable and owned by the state class; the Loop only needs the fd number for
`epoll_ctl`. Same pattern as the wakeup channel (captures raw `efd`).

### L1: Kernel.Completion.Driver (witness)

```swift
public struct Driver {
    public let capabilities: Capabilities

    /// Enqueue an operation in the submission ring.
    public let _submit: (
        borrowing Kernel.Descriptor,   // ring fd
        borrowing Kernel.Descriptor,   // target fd
        Submission
    ) throws(Kernel.Completion.Error) -> Void

    /// Commit accumulated submissions to the kernel.
    public let _flush: (
        borrowing Kernel.Descriptor
    ) throws(Kernel.Completion.Error) -> Int

    /// Drain completed operations via callback.
    ///
    /// Acknowledges the notification (reads eventfd if applicable),
    /// then iterates the completion queue, calling visitor for each event.
    /// Non-blocking on Linux (shared-memory CQ read).
    public let _drain: (
        borrowing Kernel.Descriptor,
        (Kernel.Completion.Event) -> Void
    ) -> Int

    /// Driver-specific cleanup. Does NOT close the ring fd.
    public let _close: (borrowing Kernel.Descriptor) -> Void
}
```

**Changes from current**:

| Current | Proposed | Why |
|---------|----------|-----|
| `_harvest(Descriptor, Deadline?, inout [Event]) → Int` | `_drain(Descriptor, (Event) → Void) → Int` | Callback composes with L1 `drainCompletions(visitor:)`. No intermediate array allocation. Loop processes events inline. |
| `_drain(Descriptor) → Void` | `_close(Descriptor) → Void` | `drain` now means "iterate CQ." `close` means "teardown." |
| No notification | `notification: Int32` on resource | Loop needs eventfd for epoll registration |
| `Deadline?` on harvest | Removed | epoll handles blocking (Linux). IOCP IS the loop (Windows). Completion CQ drain is always non-blocking. |

### L1: Kernel.Completion public API

```swift
extension Kernel.Completion {
    public func submit(
        _ submission: Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Error) {
        try driver._submit(descriptor, target, submission)
    }

    @discardableResult
    public func flush() throws(Error) -> Int {
        try driver._flush(descriptor)
    }

    /// Drain completed operations.
    ///
    /// Calls visitor for each completed event. The Loop typically
    /// resolves continuations in the visitor:
    /// ```swift
    /// completion.drain { event in
    ///     entryTable[event.token].resolve(with: event)
    /// }
    /// ```
    @discardableResult
    public func drain(
        _ visitor: (Event) -> Void
    ) -> Int {
        driver._drain(descriptor, visitor)
    }

    public consuming func close() {
        driver._close(descriptor)
    }
}
```

### How IO.Event.Loop composes with this

```swift
// Setup (once)
var readiness = try Kernel.Readiness.epoll()
var completion = try Kernel.Completion.iouring(entries: 256)

// Register io_uring notification with epoll
let notifEvent = Kernel.Event.Poll.Event(
    events: [.in, .et],
    data: .init(registrationID: completionSentinelID)
)
try Kernel.Event.Poll.ctl(
    readiness.descriptor, op: .add,
    rawFd: completion.notification,
    event: notifEvent
)

// Main loop
while !shouldHalt {
    // Submit pending operations
    for submission in mpscQueue.drain() {
        try completion.submit(submission.kernel, target: submission.fd)
    }
    try completion.flush()

    // Wait for events
    let count = try readiness.poll(deadline: deadline, into: &events)
    for i in 0..<count {
        if events[i].id == completionSentinelID {
            completion.drain { event in
                entryTable[event.token].resolve(with: event)
            }
        } else {
            dispatchReadiness(events[i])
        }
    }
}

// Teardown
completion.close()
readiness.close()
```

### How IO.Completion.Driver wraps Kernel.Completion.Driver

```swift
// IO level (swift-io)
extension IO.Completion {
    struct Driver {
        let completion: Kernel.Completion

        func submit(_ operation: IO.Completion.Operation) throws(IO.Error) {
            let submission = Kernel.Completion.Submission(
                opcode: operation.opcode.kernel,
                token: operation.token,
                address: operation.address,
                length: operation.length,
                offset: operation.offset,
                flags: operation.flags.kernel
            )
            try completion.submit(submission, target: operation.descriptor)
        }

        func flush() throws(IO.Error) {
            try completion.flush()
        }

        func drain(_ visitor: (Kernel.Completion.Event) -> Void) -> Int {
            completion.drain(visitor)
        }
    }
}
```

The IO driver translates IO-level types to Kernel-level types and delegates.
Same pattern as `IO.Event.Driver` wrapping `Kernel.Readiness`.

## L3 Backend: io_uring

### State class (file-private)

File-private class wrapping the ~Copyable ring via reference semantics.
Mirrors `Kernel.Readiness.Epoll.State`. No platform types in any API.

```swift
// Kernel.Completion+IOUring.swift
#if os(Linux)

private final class UringState {
    private var ring: Kernel.IO.Uring
    nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?

    init(ring: consuming Kernel.IO.Uring,
         eventfd: consuming Kernel.Event.Descriptor) {
        self.ring = consume ring
        self.eventfd = consume eventfd
    }
}
```

### Domain operations

```swift
extension UringState {
    func enqueue(
        _ submission: Kernel.Completion.Submission,
        target: borrowing Kernel.Descriptor
    ) throws(Kernel.Completion.Error) {
        guard let sqe = unsafe ring.nextEntry() else {
            throw .submissionQueueFull
        }
        unsafe fill(sqe, from: submission, target: target)
        ring.commitEntry()
    }

    func flush(
        _ ringFd: borrowing Kernel.Descriptor
    ) throws(Kernel.Completion.Error) -> Int {
        let pending = ring.pendingSubmissions
        guard pending > 0 else { return 0 }
        do throws(Kernel.IO.Uring.Error) {
            let submitted = try Kernel.IO.Uring.enter(
                ringFd, toSubmit: pending, minComplete: 0, flags: []
            )
            ring.resetPending()
            return submitted
        } catch {
            throw Kernel.Completion.Error(error)
        }
    }

    func drain(
        _ visitor: (Kernel.Completion.Event) -> Void
    ) -> Int {
        // Acknowledge notification (drain eventfd counter)
        if let eventfd {
            eventfd.drainCounter()  // non-blocking read
        }
        // Iterate CQ — composes directly with L1
        var count = 0
        _ = ring.drainCompletions(limit: .max) { cqe in
            visitor(Kernel.Completion.Event(
                token: cqe.data.map { UInt($0) }.retag(Kernel.Completion.self),
                result: Kernel.Completion.Event.Result(_rawValue: cqe.res),
                flags: cqe.flags.map { $0 }.retag(Kernel.Completion.Event.self)
            ))
            count += 1
        }
        return count
    }

    func teardown() {
        eventfd = nil
        // ring deinit unmaps SQ/CQ memory
    }
}
```

### Boundary conversion with .retag/.map

The CQE → Event conversion uses typed conversions instead of rawValue extraction:

```swift
// Token: Uring Operation.Data (Tagged<Operation, UInt64>)
//      → Completion.Token (Tagged<Completion, UInt64>)
cqe.data.map { UInt($0) }.retag(Kernel.Completion.self)

// Submission.Length (Tagged<Submission.Length, UInt32>?)
//      → Uring.Length (Tagged<Uring, UInt32>)
submission.length.map { UInt32($0) }.retag(Kernel.IO.Uring.self)

// Buffer.Group → Uring.Buffer.Group
submission.bufferGroup.retag(Kernel.IO.Uring.Buffer.self)
```

Each conversion is one `.map` (value transform) + `.retag` (phantom type change).
No rawValue extraction. The type system tracks the domain transition.

### SQE fill (boundary layer)

```swift
extension UringState {
    @unsafe
    private func fill(
        _ sqe: UnsafeMutablePointer<Kernel.IO.Uring.Submission.Queue.Entry>,
        from submission: Kernel.Completion.Submission,
        target: borrowing Kernel.Descriptor
    ) {
        let data = submission.token
            .map { UInt64($0) }
            .retag(Kernel.IO.Uring.Operation.self)

        switch submission.opcode {
        case .nop:
            sqe.pointee.prepare.nop(data: data)
        case .read:
            unsafe sqe.pointee.prepare.read(
                fd: target,
                buffer: unsafe bufferPointer(submission.address),
                length: submission.length
                    .map { UInt32($0) }.retag(Kernel.IO.Uring.self),
                offset: submission.offset
                    .map { UInt64($0) }.retag(Kernel.IO.Uring.self),
                data: data
            )
        case .write:
            unsafe sqe.pointee.prepare.write(
                fd: target,
                buffer: UnsafeRawPointer(unsafe bufferPointer(submission.address)),
                length: submission.length
                    .map { UInt32($0) }.retag(Kernel.IO.Uring.self),
                offset: submission.offset
                    .map { UInt64($0) }.retag(Kernel.IO.Uring.self),
                data: data
            )
        // ... remaining opcodes follow same pattern
        }

        // SQE flags via retag
        var sqeFlags = Kernel.IO.Uring.Submission.Queue.Entry.Flags()
        if submission.flags.contains(.bufferSelect) { sqeFlags.insert(.bufferSelect) }
        if submission.flags.contains(.linked) { sqeFlags.insert(.ioLink) }
        if submission.flags.contains(.fixedFile) { sqeFlags.insert(.fixedFile) }
        sqe.pointee.flags = sqeFlags

        if submission.flags.contains(.bufferSelect) {
            sqe.pointee.buffer = .init(
                group: submission.bufferGroup
                    .retag(Kernel.IO.Uring.Buffer.self)
            )
        }
    }
}
```

### Factory

```swift
extension Kernel.Completion {
    public static func iouring(
        entries: UInt32 = 256
    ) throws(Error) -> Kernel.Completion {
        var params = Kernel.IO.Uring.Params()
        let descriptor = try createRingDescriptor(
            entries: entries, params: &params
        )
        let eventfd = try createEventfd()
        let efd = eventfd.descriptor._rawValue
        try registerEventfd(efd, with: descriptor)

        let uringRing: Kernel.IO.Uring
        do throws(Kernel.IO.Uring.Error) {
            uringRing = try Kernel.IO.Uring(
                descriptor: descriptor, params: params
            )
        } catch {
            throw Error(error)
        }

        let state = UringState(
            ring: consume uringRing, eventfd: consume eventfd
        )

        let wakeup = Kernel.Wakeup.Channel {
            Kernel.Event.Descriptor.signal(rawDescriptor: efd)
        }

        let driver = Driver(
            capabilities: Driver.Capabilities(
                ringSize: Int(params.sqEntries),
                multishot: true,
                providedBuffers: true
            ),
            submit: { ringFd, targetFd, submission in
                try state.enqueue(submission, target: targetFd)
            },
            flush: { ringFd in
                try state.flush(ringFd)
            },
            drain: { ringFd, visitor in
                state.drain(visitor)
            },
            close: { ringFd in
                state.teardown()
            }
        )

        return Kernel.Completion(
            driver: driver,
            descriptor: descriptor,
            notification: efd,
            wakeup: wakeup
        )
    }
}
```

## Symmetry: Kernel.Event ↔ Kernel.Completion

After the Readiness → Event rename (separate concern):

| Aspect | Kernel.Event | Kernel.Completion |
|--------|-------------|-------------------|
| Resource | `~Copyable, Sendable` | `~Copyable` (non-Sendable) |
| Driver | `Sendable` witness (6 closures) | Witness (4 closures) |
| Operations | register/modify/deregister/arm/poll/drain | submit/flush/drain/close |
| State | File-private class per backend | File-private class per backend |
| Factory | `.kqueue()`, `.epoll()` | `.iouring()`, `.iocp()` |
| Notification | Built-in (epoll IS the notifier) | Via `notification` descriptor |
| Error | `Kernel.Event.Error` | `Kernel.Completion.Error` |

The structural pattern is identical. The operational shape differs because
reactor and proactor are different paradigms — that's correct, not a gap.

## Fake Backend (testability)

```swift
extension Kernel.Completion {
    static func fake(
        ringSize: Int = 64,
        events: @escaping () -> [Event] = { [] }
    ) -> Kernel.Completion {
        var submissions: [Submission] = []

        let driver = Driver(
            capabilities: Driver.Capabilities(ringSize: ringSize),
            submit: { _, _, submission in submissions.append(submission) },
            flush: { _ in submissions.count },
            drain: { _, visitor in
                let batch = events()
                batch.forEach(visitor)
                return batch.count
            },
            close: { _ in submissions.removeAll() }
        )

        return Kernel.Completion(
            driver: driver,
            descriptor: .invalid,
            notification: -1,
            wakeup: Kernel.Wakeup.Channel { }
        )
    }
}
```

## Open Questions from Handoff

### Q1: ~Copyable state in closures

File-private state class. Reference semantics lets all 4 closures share one
instance. Same pattern as `Kernel.Readiness.Epoll.State`. Universal solution
across all proactor implementations.

### Q2: Should Completion own Uring directly?

No. Lateral L1 dependency. Completion transitively owns the ring via closure
capture. Same as Readiness transitively owning the registry.

### Q3: Event ↔ Completion symmetry

Structural symmetry: identical pattern (resource + driver + factory + state class).
Operational asymmetry: inherent to reactor vs proactor. Don't force convergence.

### Q4: Where does boundary conversion live?

In the state class. `fill(sqe)` writes into the SQE pointer from the ring.
`drain(visitor)` reads CQEs from the ring. Both use `.retag`/`.map` for
typed conversions instead of rawValue extraction.

## Outcome

**Status**: IN_PROGRESS

### L1 changes needed

| File | Change |
|------|--------|
| `Kernel.Completion.swift` | Add `notification: Int32` stored property |
| `Kernel.Completion.Driver.swift` | `_harvest` → `_drain` with callback. `_drain` → `_close`. Remove deadline. |
| `Kernel.Completion+Methods` (public API) | `harvest(into:)` → `drain(_ visitor:)`. `close()` unchanged. |

### L3 changes needed

| File | Change |
|------|--------|
| `Kernel.Completion+IOUring.swift` | Drop `IOUring` namespace. Class → file-private `UringState`. Callback drain. `.retag`/`.map` conversions. Factory sets `notification`. |

### Composition chain (complete picture)

```
Consumer calls IO.run(socket) { reader, writer in ... }
    IO selects backend (blocking / event / completion)
    IO.Completion.Driver wraps Kernel.Completion
        Kernel.Completion.Driver wraps platform witness
            io_uring: UringState → L1 Kernel.IO.Uring ring methods
            IOCP: IOCPState → L1 IOCP syscalls (future)
            fake: closures over arrays (testing)
```

Each witness does one thing: translate types and delegate down.

## References

- `swift-kernel/HANDOFF.md` — context and open questions
- `swift-io/Research/io-uring-integration-architecture.md` — integrated loop design
- `swift-io/Research/perfect-api.md` — consumer API (IO.run, IO.Reader, IO.Writer)
- `swift-io/Research/completion-queue-ownership-redesign.md` — poll thread authority
- `swift-kernel/Research/audit.md` — rawValue extraction findings (#15-20)
- `swift-primitives/HANDOFF-kernel-event-consolidation.md` — Uring IS the ring struct
- `Kernel.Readiness.Driver+Epoll.swift` — reference pattern
- `Kernel.Completion+IOUring.swift` — current backend
