# Synchronous Handoff to Actors

<!--
---
version: 1.0.0
last_updated: 2026-04-16
status: DECISION
tier: 2
---
-->

## Question

When a non-async, non-isolated caller has fire-and-forget work to deliver to
an actor that runs on a `swift-executors`-provided executor, which delivery
mechanism should the actor's owner expose?

The decision affects every consumer that bridges a synchronous boundary
(signal handlers, kqueue/epoll callbacks, IO completion handlers, FFI
callbacks, blocking-thread bridges) into actor-isolated state.

## Context

Four mechanisms are available in current Swift (6.2+):

1. **`Task { await actor.method(work) }`** — language-level fire-and-forget.
2. **`Task.immediate { await actor.method(work) }`** — SE-0472. Body runs
   synchronously on the caller's thread up to the first suspension.
3. **Direct `executor.enqueue(_ job: UnownedJob)`** — the public sync entry
   point on every `swift-executors` executor (e.g.,
   `Kernel.Thread.Executor.Polling.enqueue(_:)` at
   `Sources/Executors/Kernel.Thread.Executor.Polling.swift:193`).
4. **Channel-based handoff** — caller invokes
   `Async.Channel.Unbounded.Sender.send(_:)` from sync code; the actor owns a
   `for await` consumer.

Mechanisms (1) and (2) allocate a `Task` per message. Mechanism (3) accepts
only `UnownedJob`, which has no public constructor from a closure — it is a
forwarding entry point used by the runtime, not by user code. Mechanism (4)
allocates the channel once, then per-message cost is the channel send.

The `swift-io` codebase already commits to mechanism (4) for a related but
distinct case: `IO.Event.Actor` broadcasts kernel events from its polling
thread (running under `assumeIsolated`) to per-call
`Async.Channel<Kernel.Event>.Unbounded` senders held in the registration
table (`swift-io/Sources/IO Events/IO.Event.Actor.swift:330`). The
broadcast direction is owned-executor → awaiter rather than external-thread
→ actor, but the same primitive is used and the same scheduling cost is
paid.

## Trade-Off Matrix

| Mechanism | Per-message allocation | Ordering | Hops to actor | Cancellation/priority |
|-----------|:---:|:---:|:---:|:---:|
| `Task { }` | Task record | None across tasks | 2 (global executor → actor) | Per-task |
| `Task.immediate { }` | Task record | None across tasks | 1 (caller → actor) | Per-task |
| Direct `enqueue(UnownedJob)` | — | FIFO at the executor | 1 | None (runtime-level) |
| Channel-based | Per-element node | FIFO at the channel | 1 (consumer is already on actor) | Channel-level cancellation |

**Direct `enqueue(UnownedJob)` is unavailable** to user code because
`UnownedJob` has no public constructor that accepts a closure. It remains
in the table as the runtime's own delivery path; the public surface
`enqueue(_:)` exists for executor composition, not for posting work.

## Decision

**Channel-based handoff is the recommended pattern.**

Rationale:

1. **No `Task` allocation per message.** A pinned actor consumes from a
   single `Async.Channel.Unbounded` receiver in a `for await` loop on its
   own executor; senders are `Sendable` and can be held by any sync caller.
2. **FIFO ordering is preserved**, which `Task { }` and
   `Task.immediate { }` cannot guarantee — concurrently-enqueued tasks race
   to the actor's executor and the runtime decides arrival order.
3. **One scheduling hop**, not two. The send is synchronous and lock-free
   on the fast path; the receiver is already on the actor's executor.
4. **Backpressure is available** by switching to `Async.Channel.Bounded`,
   which `Task`-based delivery cannot provide.
5. **The pattern is already idiomatic in this ecosystem.** `IO.Event.Actor`
   uses the same `Async.Channel` primitive for its broadcast pathway. A
   single recommended pattern reduces cognitive load across consumers.

`Task.immediate` is the appropriate fallback when each message genuinely
requires its own cancellation token, priority, or task-local state — i.e.,
when the message is not "fire and forget" but "fire a structured task and
forget the handle."

`Task { }` is never the right answer when the caller is non-isolated and
non-async: it pays the global-executor bounce for no benefit over
`Task.immediate`.

Direct `enqueue(UnownedJob)` is unavailable as a user-level mechanism and
remains an internal/composition surface.

## Consequences

- Actor owners that need a sync-callable delivery point MUST expose a
  `Sender` (or wrap one in a domain-specific type) rather than an `async`
  method.
- The actor's main loop becomes a `for await element in receiver` body
  invoked once at construction; per-message dispatch happens inside that
  loop.
- Shutdown is modelled as channel close — the consumer loop terminates
  when the receiver yields `nil`, mirroring the existing
  `IO.Event.Actor` shutdown semantics.

## Alternatives Considered

### A. Recommend `Task.immediate` universally

Rejected. Pays per-message Task allocation, drops FIFO ordering, and
provides no backpressure.

### B. Expose a closure-accepting wrapper around `enqueue(UnownedJob)`

Rejected. There is no supported way to construct an `UnownedJob` from a
closure in user code; any such wrapper would itself allocate a `Task`
internally (via `Task.immediate`) to obtain a job, defeating the purpose.

### C. Per-actor custom executor with an internal sync queue

Available, but more invasive than necessary. Reserved for actors whose
delivery semantics cannot be expressed as a channel (e.g., priority-based
dispatch, deduplication, coalescing).
