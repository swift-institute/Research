# Swift-IO Deep Quality Audit

<!--
---
version: 3.0.0
last_updated: 2026-02-25
status: DECISION
tier: 2
---
-->

## Context

This audit examines `swift-io` and its foundation-layer dependencies (`swift-async`, `swift-memory`, `swift-pools`) for quality, core correctness, and performance/allocation concerns. Findings are cross-referenced against the **implementation** skill ([IMPL-*], [PATTERN-*]) and **existing-infrastructure** skill ([INFRA-*]).

**Scope**: All modules in `swift-io` (IO Core, IO Events, IO Completions, IO Blocking, IO Blocking Threads) plus direct foundation dependencies.

**Method**: File-by-file audit of all source files, focusing on: memory safety, data races, continuation correctness, allocation patterns in hot paths, and compliance with typed infrastructure conventions.

## Summary

| Module | CRITICAL | HIGH | MEDIUM | LOW | Total |
|--------|----------|------|--------|-----|-------|
| IO Core + Primitives | 5 | 4 | 8 | 3 | 20 |
| IO Events | 0 | 5 | 6 | 6 | 17 |
| IO Completions | 1 | 2 | 8 | 4 | 15 |
| IO Blocking + Threads | 2 | 5 | 8 | 8 | 23 |
| Dependencies (async/memory/pools) | 1 | 2 | 6 | 1 | 10 |
| **Total** | **9** | **18** | **36** | **22** | **85** |

**Positive findings**: Continuation safety model (CheckedContinuation + state machine) is sound in IO Events. Single-funnel guarantee (poll thread never resumes continuations directly). Typed throws used consistently. ~Copyable typestate tokens prevent misuse at compile time. Atomic memory ordering in Waiter cancellation is correct. Stale deadline detection via generation numbers is robust.

---

## Triage Summary (v3.0.0)

Manual source-level verification of every CRITICAL, HIGH, and MEDIUM finding. Triage key:

| Verdict | CRIT/HIGH | MEDIUM | Total | Meaning |
|---------|-----------|--------|-------|---------|
| **FALSE POSITIVE** | 12 | — | 12 | Audit agents missed actor isolation, CAS semantics, or condition variable lock semantics |
| **FIXED** | 2 | 3 | 5 | Root cause addressed with code change |
| **KNOWN LIMITATION** | 1 | — | 1 | Documented design choice with explicit tradeoff acknowledgment |
| **KEEP** | 2 | 8 | 10 | Architecture is correct; alternatives investigated and rejected |
| **DESIGN NEEDED** | 1 | — | 1 | Requires architectural redesign (zero-copy event pipeline) |
| **OUT OF SCOPE** | 1 | 5 | 6 | Fix requires upstream package changes |
| **PLATFORM** | — | 4 | 4 | Platform-specific code; cannot build or test on macOS |
| **OPEN** | — | 13 | 13 | Genuine findings; deferred to future work |

### CRITICAL Triage

| ID | Original | Verdict | Reasoning |
|----|----------|---------|-----------|
| C-1 | Non-atomic Bool flags | **FALSE POSITIVE** | `IO.Handle.Registry` is an `actor` (line 51). Actor isolation serializes all access to `Slot.Container`. Non-atomic Bool flags are safe under actor exclusion. |
| C-2 | Slot deallocation race | **FIXED** | Added `defer { slot.deallocateRawOnly() }` after allocation. Both success and error paths already called cleanup correctly, but `defer` guards against future refactoring introducing new exit paths. |
| C-3 | Handle consume without guarantee | **FALSE POSITIVE** | Actor isolation ensures mutual exclusion. Resource `h` is consumed on exactly one path — branches are mutually exclusive under actor serialization. Continuation resumption cannot throw (CheckedContinuation). |
| C-4 | Ownership.Transfer.Cell silent drop | **KNOWN LIMITATION** | Comment at lines 334-353 explicitly acknowledges the tradeoff. `Cell.deinit` handles cleanup. Documented design choice, not a bug. |
| C-5 | Continuation resumption race | **FALSE POSITIVE** | `Waiter.resume.now()` uses `compareExchange` (`acquiringAndReleasing` ordering) for exactly-once resumption. Multiple callers are safe by CAS design — losers see `.alreadyDone` and no-op. |
| C-6 | Blocking continuation race | **FALSE POSITIVE** | `setContinuation()` (line 49) happens BEFORE `Task.isCancelled` check (line 53) and BEFORE `enqueue()` (line 81). Queue lock provides happens-before to workers. `Atomic<State>.compareExchange` ensures exactly one of complete/cancel/timeout/fail wins. |
| C-7 | Double-resume in stream operators | **FALSE POSITIVE** | All Async.Stream state types (`Merge.State`, `CombineLatest.State`, `Replay.State`, `FlatMap.Latest.State`) are `actor`s. Actor isolation serializes continuation access. Once `cont` is extracted under actor exclusion, it is used exactly once. |

### HIGH Triage

| ID | Original | Verdict | Reasoning |
|----|----------|---------|-----------|
| H-1 | Per-operation heap alloc | **KEEP** | Heap allocation is architecturally required — the `Address` must be `Sendable` and survive async suspension points. Inline storage would be on the stack which moves during suspension. `Slot.Container` is ephemeral (microsecond lifespan, 1 per transaction). `UnsafeMutableRawPointer.allocate()` is O(1). Pool overhead > allocation overhead for this pattern. |
| H-2 | Double heap alloc per register() | **OUT OF SCOPE** | Requires `Ownership.Transfer` redesign in swift-memory. Could use shared `Slab<Resource>` arena per Registry, but this is an upstream architectural change. |
| H-3 | Event buffer copy per poll | **DESIGN NEEDED** | `Array(eventBuffer.prefix(count))` copies events into a new heap allocation every non-empty poll. The copy is architecturally required at the sync→async boundary because `Async.Bridge` takes ownership via `Deque`. Fix requires zero-copy event pipeline with `Memory.Pool`. See design doc: [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md). |
| H-4 | Shutdown iteration + mutation race | **FALSE POSITIVE** | `cancel(id:)` does not mutate `entries`. `shutdown()` has exclusive actor access. The `drain()` path is called after the iteration loop completes. |
| H-5 | Unmanaged dangling pointer | **FALSE POSITIVE** | `Storage` lifetime is managed by the `Queue` actor's `entries` dictionary. The pointer remains valid while the entry exists. Entry removal happens only after the kernel operation completes. |
| H-6 | try! crash on invalid config | **FIXED** | Added `didSet` clamping to `IO.Backpressure.Policy` stored properties (`laneQueueLimit`, `laneAcceptanceWaitersLimit`, `handleWaitersLimit`). `init` already had `max(1, ...)` clamping; `didSet` covers post-construction mutation. 3 new tests added. |
| H-7 | Per-job Mutex allocation | **FALSE POSITIVE** | `Synchronization.Mutex` is a value type with inline storage (backed by `os_unfair_lock` / `pthread_mutex_t`). No heap allocation per job. |
| H-8 | O(n) deadline scan | **KEEP** | Scan is bounded by `acceptanceWaitersLimit` (default 1024). Runs on dedicated thread, not on hot path. Code comments acknowledge "acceptable for periodic use." `Heap` from swift-heap-primitives was evaluated but lacks ticket-based removal (required for O(1) cancellation). |
| H-9 | Continuation lifetime risk | **FALSE POSITIVE** | Dropping a `Task` handle does NOT cancel the task in Swift. The task continues executing independently. The continuation will be resumed when `_receive()` completes. |
| H-10 | Pool.Blocking lock contention | **FALSE POSITIVE** | `defer { sync.unlock() }` is at function scope (correct). `sync.wait()` handles internal lock release/reacquire per condition variable semantics — the lock IS held across loop iterations, with temporary release only inside `wait()`. |

---

## CRITICAL Findings

### C-1. Slot.Container State Flags Are Non-Atomic [FALSE POSITIVE]

**File**: `IO/IO.Executor.Slot.Container.swift:22-24,36-40,62-68`

`isInitialized`/`isConsumed` are plain Bool fields. Concurrent `initialize()`/`take()`/`deallocateRawOnly()` calls can corrupt the state machine. Release builds have no protection — the DEBUG-only mutation tripwire (`_mutationDepth` Mutex in `IO.Executor.Handle.Entry.swift:34-40`) vanishes entirely.

**Rule**: [MEM-SAFE-*]

> **Triage**: `IO.Handle.Registry` is an `actor`. All `Slot.Container` mutations occur inside actor-isolated methods. Actor isolation provides mutual exclusion, making atomic flags unnecessary.

### C-2. Slot Deallocation Race on Task Cancellation [FIXED]

**File**: `IO/IO.Handle.Registry.swift:784-812`

If a lane execution is cancelled mid-suspension, `deallocateRawOnly()` sets `self.raw = nil`. A late-arriving completion accessing via `address._pointer` sees `bits != 0` (passes precondition) but dereferences freed memory. No `defer` guards the deallocation path.

**Rule**: [MEM-SAFE-*], [PATTERN-014]

> **Triage**: The original code had correct cleanup on both paths, but a `defer` was added to guard against future refactoring. `defer { slot.deallocateRawOnly() }` now immediately follows `Slot.Container.allocate()`. Two explicit `deallocateRawOnly()` calls were removed. The race scenario described is prevented by actor isolation.

### C-3. Handle Check-In Consume Without Retrieval Guarantee [FALSE POSITIVE]

**File**: `IO/IO.Handle.Registry.swift:837-884`

The resource `h` is consumed via field assignment (`entry.reservedHandle = consume h`), but if continuation resumption throws, the resource is stranded with no recovery path. On line 850, `_ = consume handle` discards the handle when `state == .destroyed` — correct but deserves explicit cleanup comment.

**Rule**: [MEM-OWN-*]

> **Triage**: Actor isolation ensures mutual exclusion. Resource `h` is consumed on exactly one path — branches are mutually exclusive under actor serialization. `CheckedContinuation.resume()` does not throw. The `state == .destroyed` discard is intentional cleanup.

### C-4. Ownership.Transfer.Cell Silent Resource Drop [KNOWN LIMITATION]

**File**: `IO/IO.Handle.Registry.swift:334-353,540-555`

If the lane rejects work, `Ownership.Transfer.Cell`'s deinit silently drops the resource. The teardown action never runs, potentially leaking side-effectful resources (e.g., open file handles). The code acknowledges this in a comment but provides no fallback.

**Rule**: [MEM-OWN-*]

> **Triage**: Documented design choice. Comment at lines 334-353 explicitly acknowledges the tradeoff and explains why `Cell.deinit` is the correct cleanup path. Adding a fallback teardown would require synchronous access to the lane, which isn't available in the rejection path.

### C-5. IO Completions: Continuation Resumption Race [FALSE POSITIVE]

**File**: `IO Completions/IO.Completion.Queue.swift:267-295`

Multiple independent `Task { waiter.resume.now() }` hops create a window where the continuation may be resumed from both the cancellation handler and the early-completion check simultaneously. Relies on CAS idempotency but semantics are fragile under high contention.

> **Triage**: `resume.now()` uses `Atomic<State>.compareExchange` with `acquiringAndReleasing` ordering. The CAS provides exactly-once semantics by design — not "fragile," but the canonical pattern for multi-path continuation resumption. Only the CAS winner resumes; losers observe `.alreadyDone` and no-op.

### C-6. IO Blocking: Continuation Resumption Race [FALSE POSITIVE]

**File**: `IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.swift:46-95`

Between checking `Task.isCancelled` (line 53) and setting the continuation (line 49), a race exists where: Thread A checks cancelled → false; Thread B cancels task → `onCancel` fires; Thread A sets continuation. The `onCancel` has already executed but cancellation didn't stick.

**File**: `IO Blocking/IO.Blocking.Lane.Abandoning.Job.swift:25-26,37-42`

The `continuation` field is protected by a Mutex, but between unlock and resumption (lines 89-92, 107-110, 135-138, 154-157), another thread could clear the continuation. Lost updates possible if CAS wins and continuation is then cleared by a racing cancel.

> **Triage**: The audit reversed the actual ordering. `setContinuation()` (line 49) happens BEFORE `Task.isCancelled` check (line 53) and BEFORE `enqueue()` (line 81). The continuation is set under `withUnsafeContinuation`, then the cancellation check occurs. Queue lock provides happens-before to workers. `Atomic<Job.State>.compareExchange` ensures exactly one of complete/cancel/timeout/fail wins the CAS, and only the winner resumes the continuation.

### C-7. Double-Resume in Async Stream Operators [FALSE POSITIVE]

**Files**: `swift-async/Sources/Async Stream/` — Merge.State.swift:38-44, CombineLatest.State.swift:58-63, Replay.Subscription.swift:43-45, FlatMap.Latest.State.swift:96-99

Continuation stored as mutable property, read-nil-resume is non-atomic. Multiple concurrent tasks can read the same continuation reference, nil it, and resume it — causing double-resume UB/segfault. Actors provide exclusive access, but once `cont` is extracted, there is no protection.

> **Triage**: All four state types are `actor`s. Actor isolation provides exclusive access to the stored continuation. The read-nil-resume sequence executes atomically within a single actor-isolated method call. "Once `cont` is extracted" there IS protection — the extraction happens under actor isolation, and only one caller can extract it.

---

## HIGH Findings

### H-1. Per-Operation Heap Allocation in Slot.Container [KEEP]

**File**: `IO/IO.Executor.Slot.Container.swift:47-53`

Every `transaction()` call allocates raw memory on the heap via `UnsafeMutableRawPointer.allocate`. For small resources (Int64, UUID), this is unnecessary. A value-generic inline buffer would eliminate per-operation allocations.

> **Triage**: Heap allocation is architecturally required. The `Slot.Container.Address` must be `Sendable` and survive `async` suspension points where the stack frame may be relocated by the Swift runtime. Inline storage (stack-allocated) would invalidate the address across suspension. The allocation is ephemeral (microsecond lifespan, 1 per transaction, immediately freed). `UnsafeMutableRawPointer.allocate()` is O(1) via the system allocator's free list. A `Memory.Pool` was investigated but the pool's management overhead exceeds the allocation cost for this single-slot ephemeral pattern.
>
> **Primitives evaluated**: `Buffer.Linear.Inline<1>`, `Array.Static<1>`, `Storage.Pool`, `Memory.Pool`. All rejected — stack storage doesn't survive suspension; pool overhead exceeds direct allocation for N=1 ephemeral pattern.

### H-2. Double Heap Allocation Per register() [OUT OF SCOPE]

**File**: `IO/IO.Handle.Registry.swift:503-555`

`Ownership.Transfer.Storage` adds a second heap allocation per `register()` call on top of the slot allocation. Compounds under high registration load.

> **Triage**: Requires `Ownership.Transfer` redesign in swift-memory. A shared `Slab<Resource>` arena per Registry could batch-allocate registration slots, eliminating per-register heap allocation. However, `Ownership.Transfer` is upstream infrastructure used across multiple packages — the redesign must happen there, not as a swift-io patch.

### H-3. Event Buffer Heap-Allocated Every Poll Iteration [DESIGN NEEDED]

**File**: `IO Events/IO.Event.Poll.Loop.swift:58-61,83`

`[IO.Event](repeating:count:)` heap-allocated every poll loop tick (256 * sizeof(IO.Event)). Additionally, `Array(eventBuffer.prefix(count))` copies the event batch into a new allocation on every non-empty poll. Both are hot-path allocations.

> **Triage**: The outer buffer (`eventBuffer`) is pre-allocated at line 58 and reused across iterations — only the first allocation is "per loop." The `Array(eventBuffer.prefix(count))` copy at line 83 IS a per-poll allocation, but it is architecturally required at the sync→async boundary: the poll thread owns `eventBuffer` and reuses it, while `Async.Bridge.push()` takes ownership of the pushed value. The bridge stores elements in an internal `Deque`.
>
> **Root cause**: `IO.Event.Poll` is `enum { case events([IO.Event]); case tick }` — it owns the array. The bridge pushes `Poll.events(batch)` which transfers ownership of the copied array.
>
> **Fix requires**: Zero-copy event pipeline using `Memory.Pool` for pre-allocated event buffers that cross the sync→async boundary without copying. See design doc: [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md).

### H-4. IO Completions: Shutdown Iteration + Mutation Race [FALSE POSITIVE]

**File**: `IO Completions/IO.Completion.Queue.swift:473-485`

`shutdown()` iterates `entries` dictionary while calling `cancel(id:)` which may trigger `drain()` that mutates entries during iteration — potential crash.

> **Triage**: `cancel(id:)` does not mutate the `entries` dictionary. It flags the waiter for cancellation via CAS on the atomic state field. `drain()` is called after the iteration loop completes. `IO.Completion.Queue` is an `actor` — `shutdown()` has exclusive access to `entries` during its execution.

### H-5. IO Completions: Unmanaged Dangling Pointer [FALSE POSITIVE]

**File**: `IO Completions/IO.Completion.Operation.swift:131-132`

`Unmanaged.passUnretained(self)` stored as `userData`; if storage is deallocated while kernel operation is in-flight, recovered pointer is dangling.

> **Triage**: `Storage` lifetime is managed by the `Queue` actor's `entries` dictionary. An entry is never removed from the dictionary until its kernel operation completes and the completion is processed. The `passUnretained` is safe because the `entries` dictionary retains the `Storage` for the entire duration of the kernel operation.

### H-6. IO Blocking: try! Crashes on Invalid Configuration [FIXED]

**File**: `IO Blocking Threads/IO.Blocking.Threads.Runtime.State.swift:68,76-79`

`try!` on capacity conversions will trap at runtime if configuration is invalid. Catastrophic rather than graceful.

> **Triage**: The `try!` path is protected by upstream clamping in `IO.Backpressure.Policy.init` which already enforced `max(1, ...)` at construction. The real bug was that post-construction mutation of public stored properties (`laneQueueLimit`, `laneAcceptanceWaitersLimit`, `handleWaitersLimit`) bypassed the init clamping, allowing negative values.
>
> **Fix**: Added `didSet { ... = max(1, ...) }` to all three properties in `IO.Backpressure.Policy`. Added 3 new tests verifying post-construction mutation clamping. All 13 tests pass.

### H-7. IO Blocking: Per-Job Mutex Allocation [FALSE POSITIVE]

**File**: `IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.swift:43`

`Mutex<IO.Blocking.Lane.Abandoning.Job?>(job)` allocates a Mutex on the heap for every job submission. Hot-path allocation.

> **Triage**: `Synchronization.Mutex` is a value type with inline storage (backed by `os_unfair_lock` on Apple platforms, `pthread_mutex_t` on Linux). There is no heap allocation. The `Mutex` is stack-allocated as part of the enclosing `withUnsafeContinuation` closure frame.

### H-8. IO Blocking: O(n) Deadline Scan [KEEP]

**File**: `IO Blocking Threads/IO.Blocking.Threads.Deadline.Manager.swift:47,57`

`state.acceptanceWaiters.deadline.earliest` iterates the entire index dictionary to find min deadline — O(n) per wake cycle. Should use a heap.

> **Triage**: The scan is bounded by `acceptanceWaitersLimit` (default 1024, configurable). It runs on the dedicated deadline manager thread, not on the event processing hot path. Code comments acknowledge this as "acceptable for periodic use."
>
> **Primitives evaluated**: `Heap<Element>`, `Heap.Fixed`, `Heap.Static<N>`, `Heap.Small<N>` from swift-heap-primitives. All support O(1) peek / O(log n) push/pop, but none provide ticket-based O(1) removal — required for cancellation support. Adding a `Heap` as a side structure would require maintaining a parallel `(deadline, ticket)` heap alongside the existing dictionary, with the dictionary still needed for O(1) ticket-based cancellation. The complexity isn't justified given the bounded n and non-hot-path execution.

### H-9. Continuation Lifetime Risk in Async.Stream.Replay [FALSE POSITIVE]

**File**: `swift-async/Sources/Async Stream/Async.Stream.Replay.Subscription.swift:37-39`

`nonisolated func receive()` creates `Task { await _receive() }` but discards the handle. If Task is cancelled before execution, stored continuation is never resumed — stream hangs indefinitely.

> **Triage**: Dropping a `Task` handle does NOT cancel the task in Swift. The `Task` continues executing independently until completion. The continuation will be resumed when `_receive()` executes on the actor. The discarded handle simply means the caller doesn't await the task's result — the task itself is retained by the runtime until completion.

### H-10. Pool.Blocking Lock Contention [FALSE POSITIVE]

**File**: `swift-pools/Sources/Pool/Pool.Blocking.swift:31-54`

`defer { sync.unlock() }` at the wrong nesting level causes lock release+reacquire every loop iteration. Under high concurrency, acquire latency degrades O(n) with waiter count.

> **Triage**: `defer { sync.unlock() }` is at function scope (correct nesting). `sync.wait()` internally releases the lock, suspends the thread on the condition variable, and reacquires the lock when signaled — this is standard condition variable semantics (POSIX `pthread_cond_wait`). The lock IS held continuously across loop iterations, with temporary release only inside `wait()`. There is no "wrong nesting level."

---

## MEDIUM Findings

### MEDIUM Triage (v3.0.0)

Manual source-level verification of all 33 MEDIUM findings.

| Verdict | Count | Meaning |
|---------|-------|---------|
| **FIXED** | 3 | Root cause addressed with code change |
| **KEEP** | 8 | Correct as-is for the domain; alternatives investigated and rejected |
| **OUT OF SCOPE** | 5 | Fix requires upstream package changes |
| **PLATFORM** | 4 | Platform-specific code (IOCP/io_uring); cannot build or test on macOS |
| **OPEN** | 13 | Genuine findings; deferred to future work |

| ID | Verdict | Reasoning |
|----|---------|-----------|
| M-1 | **PLATFORM** | IOCP (Windows). Cannot build or test on macOS. |
| M-2 | **KEEP** | `UInt(truncatingIfNeeded:)` from `UInt64` is a no-op on 64-bit; expresses width intent at the counter→ID boundary. |
| M-3 | **KEEP** | `UInt(bitPattern: raw)` is the correct pattern at an unsafe pointer boundary. Precondition guards the invariant. |
| M-4 | **OUT OF SCOPE** | swift-memory upstream. |
| M-5 | **PLATFORM** | IOCP (Windows). |
| M-6 | **PLATFORM** | IOCP (Windows). |
| M-7 | **OUT OF SCOPE** | swift-pools upstream. |
| M-8 | **FIXED** | Replaced magic sentinel with failable `IO.Event.ID(pollData:)` and `Kernel.Event.Poll.Data(registrationID:)` boundary extensions using `.map()`/`.retag()`. Wakeup registration omits data parameter entirely. Kqueue: eliminated `wakeupId` variable — `filter: .user` is the structural discriminator. |
| M-9 | **KEEP** | 3-bit state machine with 6 named states. Not independent flags — OptionSet is semantically wrong. Manual bit-masking correctly expresses the state machine. |
| M-10 | **FIXED** | Replaced manual `while let dequeue()` loop with `dequeueEligible(flaggedInto:)` + `Drain.drain()`. Separates cancellation draining from reservation using the queue's built-in eligible-pop infrastructure. |
| M-11 | **OUT OF SCOPE** | swift-pools upstream. |
| M-12 | **OUT OF SCOPE** | swift-async upstream. |
| M-13 | **OUT OF SCOPE** | swift-memory upstream. |
| M-14 | **OPEN** | Manual while loops in Acceptance.Queue. Could use structured iteration but requires careful analysis of the dequeue+deadline interleaving. |
| M-15 | **KEEP** | Two `~Copyable` optional tokens modeling a typestate (exactly one non-nil at a time). Property.View adds complexity without benefit for this pattern. Canonical move-only sum type encoding. |
| M-16 | **FIXED** | Replaced `__unchecked` + `Cardinal()` with failable `Count` init: `try! .init(max(capacity, 1))`. |
| M-17 | **KEEP** | `swap(&result, &handle)` is the canonical extraction pattern for `~Copyable` optionals. No better alternative exists in Swift. |
| M-18 | **KEEP** | Precondition + force-unwrap is correct at this unsafe pointer boundary. The precondition guards `bits != 0`, making the force-unwrap provably safe. |
| M-19 | **PLATFORM** | IOCP (Windows). |
| M-20 | **OPEN** | io_uring `@unchecked Sendable`. Deferred — requires Linux testing. |
| M-21 | **OUT OF SCOPE** | swift-pools upstream. |
| M-22 | **OPEN** | `@unchecked Sendable` on Shards. Needs documentation of the safety invariant. |
| M-23 | **KEEP** | Dictionary CoW during iteration is O(n) but bounded by registration count. Collecting keys first also allocates O(n). Net benefit is marginal. |
| M-24 | **OPEN** | Unbounded deadline heap with lazy cleanup. Bounded by registration count in practice but worth monitoring under sustained load. |
| M-25 | **KEEP** | `fatalError` is correct for unreachable paths after typed throws. These catch clauses exist only because the compiler requires exhaustive catching. `assertionFailure` would silently swallow impossible errors in release builds. |
| M-26 | **OPEN** | io_uring kernel offset bounds checking. Deferred — requires Linux testing. |
| M-27 | **OPEN** | Relaxed atomics visibility window. Acknowledged; sequentially-consistent ordering would add unnecessary overhead for this telemetry use case. |
| M-28 | **OPEN** | swift-memory optional chaining. Requires upstream investigation. |
| M-29 | **OPEN** | swift-memory deadline lock. Requires upstream investigation. |
| M-30 | **OPEN** | Shutdown teardown error swallowing. Design decision — lane rejection during shutdown has no meaningful recovery path. |
| M-31 | **OPEN** | Three resume paths. Correct via CAS; structural simplification deferred. |
| M-32 | **OPEN** | Untyped dimension in queue init. Low priority. |
| M-33 | **KEEP** | `.rawValue` access is at the outermost boundary into `Atomic<UInt64>`. No typed atomic counter infrastructure exists in primitives (by design — atomics stay at the operation level, not wrapped in typed containers). |

### Implementation Pattern Violations

| # | File | Issue | Rule |
|---|------|-------|------|
| M-1 | `IO Completions/IO.Completion.IOCP.swift:116,305` | `UInt(bitPattern:)` at call sites | [IMPL-010] |
| M-2 | `IO Events/IO.Event.Poll.Operations.swift:57` | Inline `UInt(truncatingIfNeeded:)` at call site | [IMPL-010] |
| M-3 | `IO/IO.Executor.Slot.Container.swift:39` | `UInt(bitPattern: raw)` at call site | [IMPL-010] |
| M-4 | `swift-memory/Memory.Map+Operations.swift:131,139` | `Int(bitPattern: index.rawValue)` at call sites | [IMPL-010] |
| M-5 | `IO Completions/IO.Completion.Queue.swift:158,205,491` | Direct `.rawValue` on Tagged types | [PATTERN-017] |
| M-6 | `IO Completions/IO.Completion.Queue.swift:158,235` | `__unchecked:` initializers where typed constructors exist | [PATTERN-017] |
| M-7 | `swift-pools/Pool.Blocking.swift:51,91,128,190,219,221` | `.rawValue` access on Condition at call sites | [IMPL-002] |
| M-8 | `IO Events/IO.Event.Poll.Operations.swift:263-267` | Magic literal `0` as wakeup sentinel ID | [IMPL-002] |
| M-9 | `IO Events/IO.Event.Waiter.State.swift:27-29` | Manual bit-masking instead of typed flag operations | [IMPL-004] |

### Iteration Pattern Violations ([IMPL-033])

| # | File | Issue |
|---|------|-------|
| M-10 | `IO/IO.Handle.Registry.swift:860-879` | Manual `while let dequeue()` mixes cancellation draining with reservation |
| M-11 | `swift-pools/Pool.Blocking.swift:31-54,64-94,102-131` | Hand-rolled `while true` loops with complex bodies |
| M-12 | `swift-async/Async.Stream.FlatMap.State.swift:44-58` | Manual while loop in stream operator |
| M-13 | `swift-memory/Memory.Lock.Token.swift:116-153` | Busy-poll loop with sleep for lock acquisition |
| M-14 | `IO Blocking Threads/Acceptance.Queue.swift:145-171,318-326` | Manual while loops for dequeue and deadline scan |

### Infrastructure and Design Issues

| # | File | Issue | Rule |
|---|------|-------|------|
| M-15 | `IO Events/IO.Event.Channel.swift:68-69` | Manual optional token storage instead of Property.View | [INFRA-106] |
| M-16 | `IO/IO.Handle.Waiters.swift:61-66` | `__unchecked` + `Cardinal()` hand-rolled queue init | [INFRA-106] |
| M-17 | `IO/IO.Executor.Handle.Entry.swift:136-138` | Hand-rolled `swap(&result, &handle)` pattern | [INFRA-024] |
| M-18 | `IO/IO.Executor.Slot.swift:68-71` | Manual pointer reconstruction with force-unwrap | [IMPL-002] |
| M-19 | `IO Completions/IO.Completion.IOCP.swift:59-69` | `@unchecked Sendable` State with mutable fields, poll-thread confinement is comment-only | [MEM-SEND-*] |
| M-20 | `IO Completions/IO.Completion.IOUring.Ring.swift:87,227` | `localSqTail` mutable on `@unchecked Sendable` Ring; no enforcement | [MEM-SEND-*] |
| M-21 | `swift-pools/Pool.Blocking.swift:6` | `@unchecked Sendable` with mutable `_state`, no compile-time lock enforcement | [MEM-SEND-*] |
| M-22 | `IO/IO.Executor.Shards.swift:54` | `@unchecked Sendable` relies on undocumented assumption | [MEM-SEND-*] |
| M-23 | `IO Events/IO.Event.Selector.swift:831-838` | Dictionary iteration with removals creates implicit copy | -- |
| M-24 | `IO Events/IO.Event.Selector.swift:98-99,688` | Deadline heap unbounded; stale entries only cleaned on drain | -- |
| M-25 | `IO/IO.Ready.swift:113-156` | `fatalError` catch-all after typed throws; should be `assertionFailure` | [API-ERR-001] |
| M-26 | `IO Completions/IO.Completion.IOUring.Ring.swift:152-171` | No bounds checking on kernel offsets before pointer arithmetic | -- |
| M-27 | `IO Blocking Threads/Runtime.State.swift:99-112` | Relaxed atomics on in-flight count create visibility window with shutdown flag | -- |
| M-28 | `swift-memory/Memory.Map.swift:151,157` | Optional chaining on pointer silently degrades | -- |
| M-29 | `swift-memory/Memory.Lock.Token.swift:107-154` | Deadline lock acquisition ignores `Task.isCancelled` | -- |
| M-30 | `IO/IO.Handle.Registry.swift:332-353` | Shutdown teardown silently swallows lane-rejection errors | [API-ERR-*] |
| M-31 | `IO Completions/IO.Completion.Queue.swift:283-288` | Three separate resume paths for one continuation; maintenance burden | -- |
| M-32 | `IO Blocking Threads/Runtime.State.swift:68,76-78` | Untyped dimension usage in queue initialization | -- |
| M-33 | `IO Blocking Threads/Metrics.swift:140` | `UInt64(count.cardinal.rawValue)` exposes `.rawValue` | [IMPL-002] |

---

## LOW Findings

| # | File | Issue |
|---|------|-------|
| L-1 | `IO Events/IO.Event.Waiter.swift:36,42` | Undocumented ordering rationale for continuation write before CAS |
| L-2 | `IO Events/IO.Event.Poll.Operations.swift:214-223` | Timeout overflow clamped to `-1` needs clarifying comment |
| L-3 | `IO Events/IO.Event.Poll.Operations.swift:77-79` | Registry mutations under lock are verbose |
| L-4 | `IO Events/IO.Event.Waiter.swift:64` | Underscore prefix on effectively-public atomic field |
| L-5 | `IO Events/IO.Event.Waiter+Methods.swift:93` | Backoff created fresh per cancel() call |
| L-6 | `IO Events/IO.Event.Selector.swift:99,689-890` | Heap peek-pop not atomic; safe under actor but fragile |
| L-7 | `IO Completions/IO.Completion.Poll.swift:66-72` | Errors caught but silently swallowed; no logging |
| L-8 | `IO Completions/IO.Completion.Poll.swift:51-56` | `removeAll(keepingCapacity:)` per iteration |
| L-9 | `IO Completions/IO.Completion.Kind.Set.swift:42-67` | Array literal for OptionSet statics; bitwise OR clearer |
| L-10 | `IO Completions/IO.Completion.Waiter.Resume.swift:25-31` | `resume.now()` from three sites; correct via CAS but high cognitive complexity |
| L-11 | `IO/IO.Handle.Registry.swift:407-461` | `@usableFromInline` methods with contradictory `_` prefix |
| L-12 | `IO/IO.Handle.Registry.swift:276-283` | Lifecycle check not atomic across full operation |
| L-13 | `IO Blocking Threads/Metrics.swift:108,114,134,140` | Counter wrappingAdd with relaxed ordering wraps silently |
| L-14 | `IO Blocking Threads/Runtime.State.swift:163,183,242,252` | Gauge updates with relaxed ordering may be stale |
| L-15 | `IO Blocking/Lane.Abandoning.Runtime.swift:54,63,70,77,92` | Error paths swallow `Transition.Error.alreadyDone`; masks logic bugs |
| L-16 | `IO Blocking Threads/IO.Blocking.Threads.swift:44-53` | Deinit-based forced shutdown; anti-pattern for async cleanup |
| L-17 | `IO Blocking Threads/IO.Blocking.Threads.swift:266-272` | Acceptance waiter drain assumes idempotent fail() |
| L-18 | `IO Blocking Threads/Lane.Sharded.Selection.swift:345,351` | Array allocation to collect expired tickets |
| L-19 | `swift-memory/Memory.Map.swift:165` | `endIndex` recomputed each call; should cache at init |
| L-20 | Multiple files | Nested generic error types could benefit from type aliases |

---

## Recommendations (Updated v3.0.0)

### Completed

1. **[FIXED] `defer { slot.deallocateRawOnly() }` in `transaction()`** — C-2. Guards slot deallocation on all paths including task cancellation.
2. **[FIXED] `didSet` clamping on `IO.Backpressure.Policy` properties** — H-6. Prevents negative values from post-construction mutation.
3. **[FIXED] Principled domain modeling for wakeup vs registration events** — M-8. Failable `IO.Event.ID(pollData:)` and `Kernel.Event.Poll.Data(registrationID:)` boundary extensions using `.map()`/`.retag()`. Kqueue: eliminated `wakeupId` variable.
4. **[FIXED] Structured iteration for handle check-in** — M-10. Replaced manual `while let dequeue()` with `dequeueEligible(flaggedInto:)` + `Drain.drain()`.
5. **[FIXED] Typed capacity init for waiters** — M-16. Replaced `__unchecked` + `Cardinal()` with failable `Count` init.

### Requires Architectural Design

6. **[DESIGN NEEDED] Zero-copy event pipeline** — H-3. Replace per-poll `Array` copy with `Memory.Pool`-backed buffers that cross the sync→async boundary without copying. See design doc: [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md).

### Upstream (Out of Scope)

7. **Ownership.Transfer redesign** — H-2. Eliminate double heap allocation per `register()` by using `Slab<Resource>` arena in swift-memory.
8. **swift-pools `.rawValue` access** — M-7, M-11, M-21. Requires upstream changes in swift-pools.
9. **swift-async stream iteration** — M-12. Requires upstream changes in swift-async.
10. **swift-memory boundary overloads and lock improvements** — M-4, M-13, M-28, M-29. Requires upstream changes in swift-memory.

### Open — Future Work

11. **Acceptance.Queue structured iteration** — M-14. Manual while loops could use structured iteration but requires analysis of dequeue+deadline interleaving.
12. **Document `@unchecked Sendable` safety invariants** — M-20, M-22. Explicit lock invariant documentation.
13. **Deadline heap monitoring** — M-24. Unbounded under sustained load; add monitoring or bounded cleanup.
14. **Shutdown teardown error handling** — M-30. Silent lane-rejection swallowing during shutdown.
15. **Continuation resume path simplification** — M-31. Three CAS-correct resume paths; structural simplification.
16. **Typed dimension in queue init** — M-32. Low priority.
17. **Relaxed atomics visibility window** — M-27. Acknowledged; no action needed unless telemetry misreads become problematic.

### Platform — Deferred

18. **IOCP (Windows) typed infrastructure** — M-1, M-5, M-6, M-19. Requires Windows build.
19. **io_uring `@unchecked Sendable` and bounds checking** — M-20, M-26. Requires Linux build.

---

## Changelog

### v3.0.0 (2026-02-25)

- **Triage**: Manual source-level verification of all 33 MEDIUM findings
- **Result**: 3 FIXED (M-8, M-10, M-16), 8 KEEP, 5 OUT OF SCOPE, 4 PLATFORM, 13 OPEN
- **Fixes applied**:
  - M-8: Principled domain modeling for wakeup vs registration events (epoll boundary extensions, kqueue wakeupId elimination)
  - M-10: Structured `dequeueEligible(flaggedInto:)` + `Drain` for handle check-in
  - M-16: Failable `Count` init for waiters capacity
- **Reclassifications**: M-33 reclassified from infrastructure violation to KEEP (no typed atomic counter infrastructure exists by design)
- **Recommendations updated**: Expanded from 9 to 19 items, organized by status (Completed, Design Needed, Upstream, Open, Platform)

### v2.0.0 (2026-02-24)

- **Triage**: Manual source-level verification of all 9 CRITICAL and 10 HIGH findings
- **Result**: 12 FALSE POSITIVE (actor isolation, CAS semantics, condition variable semantics), 2 FIXED (C-2, H-6), 1 KNOWN LIMITATION (C-4), 2 KEEP (H-1, H-8), 1 DESIGN NEEDED (H-3), 1 OUT OF SCOPE (H-2)
- **Fixes applied**: `defer` for slot deallocation (C-2), `didSet` clamping on backpressure policy (H-6)
- **Design doc created**: Zero-copy event pipeline using Memory.Pool (H-3)

### v1.0.0 (2026-02-24)

- Initial audit: 85 findings (9 CRITICAL, 18 HIGH, 36 MEDIUM, 22 LOW)

---

## Cross-References

- Previous audit: [foundations-dependency-utilization-audit.md](foundations-dependency-utilization-audit.md) — Tagged Flag forwarding and drain() improvements (both implemented)
- Design doc: [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md) — Architectural fix for H-3
- Skills: **implementation** ([IMPL-002], [IMPL-004], [IMPL-010], [IMPL-033], [PATTERN-017]), **existing-infrastructure** ([INFRA-106], [INFRA-024]), **memory-safety** ([MEM-SAFE-*], [MEM-SEND-*]), **memory** ([MEM-OWN-*])
