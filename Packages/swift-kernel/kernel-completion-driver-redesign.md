# Kernel Completion Driver Redesign

> Tier 2 — Cross-package, reversible but precedent-adjacent.
> Depends on: unified-completion-api-design.md, kernel-event-driver-zero-allocation-redesign.md

## Context

`Kernel.Completion` is the proactor witness — the completion-based counterpart to the
reactor-based `Kernel.Event`. The Event target was redesigned from first principles and
is now the reference implementation. This document analyzes six open design questions
that are specific to the proactor paradigm and cannot be mechanically derived from the
Event pattern.

### What the Event Pattern Settles

These are validated and not up for debate:

1. `~Copyable` Driver enforces single-ownership
2. State class local to factory (inside `iouring()`)
3. `package` visibility for Driver closures and init
4. Thread-confined — no Mutex/Atomic
5. Normative doc comments written first
6. Backend-local helpers stay file-private
7. L1 instance methods, L3 uses them
8. Zero `@_spi(Syscall)` in L3

### What's Different About Proactor

The reactor pattern (Event) has a symmetry: register interest → poll for readiness →
re-arm. Operations are stateless — the kernel tells you what's ready, you decide what
to do.

The proactor pattern (Completion) inverts this: submit work → kernel does I/O →
collect results. Operations carry state — the kernel holds your buffers, your tokens,
your completion contexts. This creates questions the reactor never faces:

- **Ownership flows outward**: Submissions carry descriptors, buffers, addresses into
  the kernel. The reactor never sends resources out.
- **Results are definitive**: A CQE says "I did the read, here's the data." A readiness
  event says "you can try a read now." Staleness is different.
- **Multishot breaks 1:1**: One SQE can produce N CQEs. The reactor has no equivalent.
- **Flush is a real operation**: Submissions accumulate in shared memory (SQ ring).
  Flushing (`io_uring_enter`) is a syscall that commits them. The reactor's register
  is immediate.

## Open Design Questions

### Q1: Callback Drain Semantics

**Question**: The research proposes `drain(_ visitor: (Event) -> Void) -> Int`. What
are the precise semantics?

**Analysis**:

The L1 `drainCompletions(limit:_:)` already uses a callback pattern:

```swift
// L1 (Linux Kernel IO Uring Primitives)
mutating func drainCompletions(limit: UInt32, _ body: (Completion.Queue.Entry) -> Void) -> UInt32
```

This is a shared-memory iteration — no syscall, just reading CQEs from the CQ ring
and advancing the head pointer. The body is called once per CQE.

**Sub-question 1a: Can the visitor throw?**

No. The CQ ring head is advanced as entries are consumed. If the visitor throws after
N of M entries, the remaining M-N entries are acknowledged (head advanced) but
unvisited. They are lost — the kernel will overwrite them.

This is not hypothetical. L1 `drainCompletions` takes a non-throwing closure. The
shared-memory protocol requires consuming all entries up to the limit. Throwing
mid-drain would mean either:
- (a) Not advancing head → kernel thinks entries are unconsumed → CQ overflow
- (b) Advancing head → entries lost

Both are wrong. The visitor must be non-throwing.

If a higher layer needs error handling, it should catch within the visitor and record
the error for post-drain processing.

**Sub-question 1b: borrowing or consuming Event?**

`borrowing`. The Event is a small value type (token + result + flags). The visitor
inspects it to resolve continuations. No ownership transfer occurs — the Event is
stack-allocated, read-only from the visitor's perspective.

If Event ever becomes `~Copyable` (for zero-copy buffer references via provided buffer
groups), `borrowing` is still correct — the visitor borrows the reference, processes
the data, and the drain loop retains ownership to advance the CQ pointer.

The research's `(Event) -> Void` signature is compatible with this — for Copyable
types, pass-by-value is equivalent to borrowing. If Event becomes `~Copyable`, the
signature would change to `(borrowing Event) -> Void`.

**Decision**: Keep `(Event) -> Void` now. The Copyable Event is passed by value.
Future `~Copyable` transition changes the signature; this is unavoidable regardless
of today's choice.

**Sub-question 1c: Multishot?**

The visitor sees N events for one token. This is correct and requires no special
handling at the drain level — each CQE is an independent completion result. The
`IORING_CQE_F_MORE` flag is in `Event.Flags` and visible to the caller.

Multishot state tracking (is this token still active?) belongs at the caller boundary,
not in the drain. The drain is pure translation — CQE → Event → visitor. Whether
the caller maintains a dispatch table of active multishot operations is its concern.

**Sub-question 1d: Return count semantics?**

Return the count of CQEs consumed from the ring (= entries visited). These are the
same number because the visitor is non-throwing — every consumed entry is visited.
L1 returns this count already.

**Proposed signature**:

```swift
package let _drain: ((Kernel.Completion.Event) -> Void) throws(Error) -> Int
```

Note: the _drain closure itself can throw (for ring-level errors like overflow
detection), but the visitor cannot. The Error is for infrastructure failures, not
per-event errors.

Wait — can drain itself fail? L1 `drainCompletions` is non-throwing. The only
infrastructure failure would be overflow detection, which is a monitoring concern,
not an operational error. Simplify:

```swift
package let _drain: ((Kernel.Completion.Event) -> Void) -> Int
```

Non-throwing. Returns count of events drained.

### Q2: Descriptor Ownership

**Question**: If descriptor is absorbed into the State class (like Event), how does
the notification fd reach `IO.Event.Loop` for epoll registration?

**Analysis**:

In the Event pattern, `Kernel.Event.Source` exposes `wakeup: Kernel.Wakeup.Channel`
as a public `Sendable` value. The wakeup channel is extracted before the Source is
transferred to the poll thread:

```swift
let source = try Kernel.Event.Source.platform()
let wakeup = source.wakeup  // Extract Sendable value before transfer
loop.start(source: source)   // consuming transfer
// wakeup is still available for cross-thread signaling
```

The Completion analog needs the same pattern for the notification fd. The notification
fd (eventfd registered with io_uring) must be available to `IO.Event.Loop` for epoll
registration.

**Option A: Public `notification: Int32` on Completion**

```swift
public struct Completion: ~Copyable {
    public let driver: Driver
    public let wakeup: Kernel.Wakeup.Channel
    public let notification: Int32  // raw eventfd for epoll
}
```

Simple. The raw fd value is extracted before transfer (same pattern as wakeup). But
it's a raw `Int32` — no type safety, no lifecycle guarantees.

**Option B: Wakeup returns both Channel + notification descriptor**

The wakeup method on L1 creates the eventfd, registers it with io_uring, and returns
both the `Wakeup.Channel` (for signaling) and a descriptor value (for epoll).

```swift
public struct Completion: ~Copyable {
    public let driver: Driver
    public let wakeup: Kernel.Wakeup.Channel
    public let notification: Kernel.Event.Descriptor  // typed, for epoll registration
}
```

Better type safety. But `Kernel.Event.Descriptor` is `~Copyable` — who owns it?
If Completion owns it, it's consumed on close. But epoll needs it to live as long as
the Loop, not as long as the Completion.

Actually — the eventfd's lifetime is tied to the io_uring ring. When the ring closes,
the eventfd registration is implicitly removed. The raw fd itself must be kept open
until after the ring is closed. The Completion resource should own the eventfd
descriptor; the notification value exposed for epoll is a raw fd number, not an
owned handle.

**Option C: Notification is a separate concern**

The notification fd is created during factory construction and stored in the State
class. A raw fd value (Int32) is captured in the Completion for epoll registration.
No ownership transfer — just a value copy of the fd number.

This matches how `Kernel.Wakeup.Channel` works: it captures a raw fd value, not an
owned descriptor. The State class owns the eventfd descriptor; the Channel/notification
hold copies of the fd number.

**Decision**: Option C. Expose `notification: Kernel.Event.Descriptor` on Completion
where `Kernel.Event.Descriptor` stores a raw fd value (not owning). The State class
owns the actual eventfd descriptor via its stored `Kernel.IO.Uring` instance or a
separate field. The `notification` field is a non-owning handle that can be freely
copied and registered with epoll.

Wait — let me check what `Kernel.Event.Descriptor` actually is. From the current
code, the IOUring backend stores `nonisolated(unsafe) var eventfd: Kernel.Event.Descriptor?`
in the Ring class. And `Kernel.Wakeup.Channel` captures a raw Int32.

The cleanest approach: `Completion` exposes `notification: Int32` (same type-level
commitment as `Kernel.Wakeup.Channel`'s internal raw fd). The State class owns the
actual eventfd descriptor.

Actually, the unified-completion-api research already proposes:
```swift
@_spi(Internal) public let notification: Int32
```

But the goal is zero SPI in L3. If we need notification to reach IO.Event.Loop
(which is in swift-io, also L3), and Kernel.Completion is also L3, then `notification`
needs `package` or `public` visibility.

The IO.Event.Loop needs the notification fd to register with epoll. This is a
legitimate L3→L3 dependency within the same package (swift-kernel). The fd value
is an implementation detail of the proactor — exposing it as `package` is appropriate.

**Revised decision**: `package let notification: Int32` on `Kernel.Completion`. State
class owns the eventfd descriptor. Notification is a raw fd value copy.

But actually — Kernel.Completion is in swift-kernel. IO.Event.Loop is in swift-io.
These are different packages. `package` won't reach swift-io.

Options:
1. `public let notification: Int32` — simple, slightly leaky
2. `@_spi(Internal) public let notification: Int32` — current pattern, but we want zero SPI
3. `public` on Completion, documented as "for event loop integration only"

The Event pattern avoids this entirely because kqueue/epoll don't need a separate
notification mechanism — they ARE the notification mechanism. The completion ring's
eventfd is structurally different.

**Final decision**: `public let notification: Int32`. Documented in the normative doc
comment as "the eventfd descriptor value for registering completion notifications
with the platform event notification mechanism." This is not SPI — it's a fundamental
part of the proactor resource's interface. Any consumer that needs to integrate
completion-driven I/O into an event loop needs this value.

### Q3: Flush as Witness Operation

**Question**: Is flush a Driver witness operation (closure), a direct L1 call, or both?

**Analysis**:

In the Event pattern, all operations go through witness closures. The closures add
infrastructure (ID generation, registry, staleness suppression) around backend calls.

Flush has no analogous infrastructure layer. It's a pure pass-through:
1. Submit accumulates SQEs in shared-memory ring (via `_submit` closure)
2. Flush calls `io_uring_enter()` to notify the kernel

There's no ID tracking, no registry lookup, no validation to wrap around flush.
The State class calls L1's `enter()` method directly.

**Option A: Witness closure (consistency)**

```swift
package let _flush: () throws(Error) -> Int
```

Pro: All operations go through the same pattern. Consumer calls `completion.flush()`.
Con: The closure is a trivial wrapper around `state.ring.enter(...)`. No value added.

**Option B: Direct L1 call (pragmatism)**

No `_flush` closure. The Completion resource calls L1 directly.
Pro: No unnecessary indirection.
Con: Breaks the witness pattern. Completion would need direct access to L1 state.

**Option C: Witness closure that wraps L1 with common infrastructure**

The flush closure could add infrastructure:
- Overflow detection (check CQ overflow counter before/after)
- Submission count tracking (for metrics/debugging)
- Error conversion (L1 error → Kernel.Completion.Error)

This is analogous to how Event's `_poll` adds staleness suppression around the
backend poll. The value-add isn't just pass-through — it's the error boundary.

**Decision**: Option A with Option C's insight. Flush is a witness closure for
consistency and error conversion. The closure wraps L1's enter() with:
- Error conversion (io_uring error → Kernel.Completion.Error)
- Return value: count of submissions accepted by kernel

```swift
package let _flush: () throws(Error) -> Int
```

Four witness closures total: `_submit`, `_flush`, `_drain`, `_close`.

Note: The current code passes `borrowing Kernel.Descriptor` to every closure. In the
redesign, the descriptor is captured by the State class (like Event). No descriptor
parameter needed.

### Q4: Token Lifecycle and Staleness

**Question**: Does Completion need staleness suppression equivalent to Event's
registry membership filter?

**Analysis**:

Event's staleness problem: After deregister, the kernel may still deliver events for
that fd (race between deregister and poll). The registry membership filter discards
these stale events.

Completion's situation is fundamentally different:

1. **Every CQE is a response to a specific SQE the caller submitted.** The caller
   owns the token (user_data). There are no "stale" completions in the Event sense —
   the kernel doesn't spontaneously generate CQEs.

2. **Cancelled operations produce CQEs.** If you cancel an SQE, the kernel sends a
   CQE with `res = -ECANCELED`. This is not stale — it's a valid completion result
   that the caller needs to handle (e.g., to release buffers or resolve continuations
   with cancellation).

3. **Multishot terminal CQEs.** When a multishot operation ends (last CQE without
   `IORING_CQE_F_MORE`), the token becomes dead. But the terminal CQE itself is
   valid and must be delivered.

The only scenario where a CQE could be "unexpected" is if:
- The caller's dispatch table was corrupted (bug, not normal operation)
- Ring overflow caused CQEs to be lost, and a late CQE arrives after the caller
  has forgotten the token (but ring overflow means earlier CQEs were lost, not
  that new ones appear for forgotten tokens)

**Key insight**: In the reactor model, the kernel generates events autonomously (fd
becomes readable). In the proactor model, the kernel only generates completions for
operations you submitted. There is no equivalent of "stale readiness."

**Decision**: No staleness suppression in the Driver. All CQEs are valid by
construction. The three-boundary model simplifies:

- **Backend**: raw CQE → `Kernel.Completion.Event` (translation)
- **Caller**: consumes events, resolves continuations

The Driver boundary has no filtering to do. This is correct — it reflects the
proactor's 1:1 submission-to-completion correspondence.

**However**: The Driver can still add value at the drain boundary:
- CQ overflow detection (check overflow counter, report via error or return value)
- Event count tracking

These are monitoring concerns, not validity concerns. They can be added without
breaking the witness pattern.

### Q5: Three-Boundary Model for Proactor

**Question**: Does the proactor need three boundaries, or does it simplify to two?

**Analysis**:

From Q4, the driver boundary has no filtering. The three-boundary model becomes:

**Event (reactor) — three boundaries:**
1. Backend: raw kevent/epoll_event → `Kernel.Event` (translation)
2. Driver: registry membership filter (staleness suppression)
3. Caller: consumes valid events

**Completion (proactor) — two boundaries:**
1. Backend: raw CQE → `Kernel.Completion.Event` (translation)
2. Caller: consumes events, resolves continuations

**Is this a problem?** No. The boundaries exist to add value, not for architectural
symmetry. If the driver boundary adds no value for proactor, omitting it is correct.
The witness still wraps the backend — the closure-based pattern is preserved. The
"driver layer" is just thinner.

**What the Driver init still does**:
- Captures State class (same as Event)
- Provides error conversion boundary (L1 errors → Kernel.Completion.Error)
- Holds close/teardown logic
- Could add overflow detection

The Driver is not empty — it just doesn't filter events. The init body creates the
State, builds closures, handles teardown. The structural role is the same.

**Decision**: Two semantic boundaries (backend translation → caller consumption).
The Driver struct and its closures still exist as the implementation mechanism, but
the driver boundary is transparent for event flow. Document this explicitly in the
normative doc comment:

"Unlike the readiness driver, the completion driver does not filter events. Every
completion queue entry corresponds to a previously submitted operation and is
delivered to the visitor. The backend boundary translates platform-specific entries;
the caller boundary consumes them."

### Q6: IOCP Stub Scope

**Question**: How much of the IOCP backend should be designed now?

**Analysis**:

IOCP (Windows) is the other proactor. It's structurally different from io_uring:
- No shared-memory ring (API-based, not mmap-based)
- No explicit flush (submissions are immediate syscalls)
- No SQ/CQ ring protocol
- Completion via `GetQueuedCompletionStatusEx` (blocks on completion port)

**What's shared between io_uring and IOCP**:
- Submit operation → wait for completion (proactor model)
- Token-based correlation (overlapped structure / user_data)
- Completion events carry results + status
- close/teardown

**What differs**:
- Flush: io_uring needs explicit flush; IOCP submits immediately
- Drain: io_uring drains shared-memory ring; IOCP blocks on completion port
- Ring setup: io_uring uses mmap; IOCP uses CreateIoCompletionPort

The witness surface should accommodate both without forcing IOCP into io_uring's
shape. The key question is whether `_flush` makes sense for IOCP.

**Option A: Flush is io_uring-specific, not in witness**

Remove `_flush` from the witness. io_uring's State class calls flush internally
(e.g., auto-flush after N submissions or on drain).

Problem: The caller (IO.Event.Loop) needs to control flush timing for batching.
Hiding it removes a performance knob.

**Option B: Flush in witness, IOCP returns 0**

```swift
_flush: () throws(Error) -> Int
```

IOCP's flush closure returns 0 (nothing to flush — already submitted). Simple,
consistent, no branching in the caller.

**Option C: Capabilities-driven**

```swift
capabilities.requiresFlush: Bool
```

Caller checks before calling flush. More explicit but adds branching.

**Decision**: Option B. Flush is a witness operation. IOCP's implementation is
`{ 0 }` (no-op returning zero). The caller calls flush unconditionally. The
witness absorbs the platform difference.

**IOCP factory stub**:

```swift
public static func iocp() throws(Error) -> Kernel.Completion
```

Signature only. Body is `fatalError("IOCP not yet implemented")` behind
`#if os(Windows)`. No Windows primitives exist yet — designing the full backend
now would be speculative.

The witness shape (submit/flush/drain/close) is IOCP-compatible:
- submit → `CreateIoCompletionPort` + `WSASend`/`WSARecv` (immediate)
- flush → no-op
- drain → `GetQueuedCompletionStatusEx` (blocks, returns completed operations)
- close → `CloseHandle`

## Proposed Witness Shape

```swift
public struct Driver: ~Copyable {
    package let _submit: (consuming Kernel.Completion.Submission, borrowing Kernel.Descriptor) throws(Error) -> Void
    package let _flush: () throws(Error) -> Int
    package let _drain: ((Kernel.Completion.Event) -> Void) -> Int
    package let _close: () -> Void
}
```

Four operations. No descriptor parameter (absorbed into State). Submit takes a
consuming Submission and a borrowing target descriptor (the fd being operated on).

**Comparison with current**:

| Current | Proposed | Change |
|---------|----------|--------|
| `_submit(borrowing Descriptor, borrowing Descriptor, Submission)` | `_submit(consuming Submission, borrowing Descriptor)` | Drop ring fd, consume Submission |
| `_flush(borrowing Descriptor)` | `_flush()` | Drop ring fd |
| `_harvest(borrowing Descriptor, Deadline?, inout [Event])` | `_drain((Event) -> Void)` | Callback, drop fd/deadline/array |
| `_drain(borrowing Descriptor)` | `_close()` | Rename, drop fd |
| Driver is Copyable | Driver is `~Copyable` | Single ownership |

## Proposed Resource Shape

```swift
public struct Completion: ~Copyable {
    package let driver: Driver
    public let wakeup: Kernel.Wakeup.Channel
    public let notification: Int32
    
    package init(driver: consuming Driver, wakeup: Kernel.Wakeup.Channel, notification: Int32)
    
    public func submit(_ submission: consuming Submission, target: borrowing Kernel.Descriptor) throws(Error)
    @discardableResult public func flush() throws(Error) -> Int
    @discardableResult public func drain(_ visitor: (Event) -> Void) -> Int
    public consuming func close()
}
```

## Proposed Factory Shape (io_uring)

```swift
extension Kernel.Completion {
    public static func iouring(entries: UInt32 = 256) throws(Error) -> Kernel.Completion
}
```

Inside the factory:
1. Create io_uring ring via L1
2. Create eventfd, register with io_uring
3. Create State class holding L1 ring + eventfd descriptor
4. Build 4 closures capturing State
5. Create `Kernel.Wakeup.Channel` from raw eventfd value
6. Return `Kernel.Completion(driver:wakeup:notification:)`

## Implementation Plan

Two commits per the handoff:

**Commit A: L3 implementation against current L1 API**
- Make Driver `~Copyable`
- Absorb descriptor into State class
- Replace harvest with callback drain
- Rename drain → close
- Add notification field
- Write normative doc comments first
- Zero SPI imports

**Commit B: L1 additions + L3 simplification**
- Add wakeup method to L1 io_uring
- Add `@safe` annotation
- Instance method audit
- Statics take `borrowing Self`
- Simplify L3 factory using new L1 methods

## Outcome

Status: CONVERGED

Collaborative discussion completed in 3 rounds (Claude + ChatGPT). All 6 questions resolved.
Implementation review identified 6 implementation-risk items; all addressed in the final plan.

Converged plan: `/tmp/kernel-completion-driver-redesign-converged.md`
Transcript: `/tmp/kernel-completion-driver-redesign-transcript.md`

### Converged Answers

1. **Callback drain**: Non-throwing visitor, protocol-semantic (CQ advancement), returns `Kernel.Completion.Event.Count` (phantom-tagged Cardinal). Drain-after-notification API — non-blocking.
2. **Descriptor ownership**: Ring descriptor absorbed into State. Notification owns its `Kernel.Descriptor` (`~Copyable, Sendable`). No raw fd in API surface.
3. **Flush**: Witness closure, returns `Kernel.Completion.Submission.Count`. IOCP returns `.zero`.
4. **Token lifecycle**: No staleness suppression. `.more` on Event.Flags normalizes multishot lifecycle.
5. **Boundaries**: Three — backend (translation + normalization), driver (lifecycle, error conversion, teardown — non-filtering), caller (consumption).
6. **IOCP**: Factory stub only. Witness shape IOCP-compatible. Lowest empirical confidence axis.
