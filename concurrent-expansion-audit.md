# @concurrent Expansion Audit

<!--
---
version: 1.0.0
created: 2026-02-25
scope: swift-io, swift-kernel, swift-async-primitives, swift-async
status: complete
---
-->

## Context

With `NonisolatedNonsendingByDefault` enabled, nonisolated async functions now default to **nonsending** (inheriting caller isolation per SE-0461). Functions that genuinely execute on a **different executor** than the caller must be explicitly marked `@concurrent`.

**Current state**: `@concurrent` is used ONLY in `IO.Blocking.Lane.swift` (8 sites: 4 stored closure type annotations + 4 method declarations).

## Audit Criterion

A function needs `@concurrent` if and only if it genuinely executes on a different executor than the caller. This includes:
- Thread pool dispatch (submits work to dedicated OS threads)
- Event loop methods bound to a specific executor thread
- Blocking I/O wrappers that must NOT run on the caller's actor
- Functions that create their own execution context

Functions that should NOT be `@concurrent`:
- Actor-isolated methods (actors already own their executor)
- Functions that merely `await` an actor method (the hop is on the callee side)
- AsyncSequence `next()` methods (should inherit caller isolation)
- Functions that delegate to an already-`@concurrent` function

## Findings

### Package 1: swift-io

#### Already annotated (IO.Blocking.Lane.swift) — 4 method-level sites

| Line | Signature | Status |
|------|-----------|--------|
| 87 | `@concurrent internal func run<T, E>(deadline:_:) async throws` | Correct |
| 111 | `@concurrent public func run<T, E>(deadline:_:) async throws` | Correct |
| 139 | `@concurrent public func run<T>(deadline:_:) async throws` | Correct |
| 154 | `@concurrent public func shutdown() async` | Correct |

These are correct: `Lane.run` dispatches the operation closure to a dedicated OS thread pool and awaits completion. The async suspension crosses the cooperative pool → OS thread boundary.

#### Candidates requiring `@concurrent`

| # | File | Line | Current Signature | Rationale |
|---|------|------|-------------------|-----------|
| 1 | `.../IO Blocking Threads/IO.Blocking.Threads.swift` | 93 | `public func runBoxed(deadline:_:) async throws(IO.Lifecycle.Error<IO.Blocking.Lane.Error>) -> UnsafeMutableRawPointer` | This is the core thread pool dispatch function. It enqueues work into a bounded job queue consumed by dedicated OS threads, then suspends the caller via `withCheckedContinuation` until the worker thread completes. The continuation is resumed from a different OS thread than the caller. Without `@concurrent`, under nonsending defaults the compiler would require this to inherit caller isolation, which is incorrect — the whole point is to escape the caller's executor. |
| 2 | `.../IO Blocking Threads/IO.Blocking.Threads.swift` | 254 | `public func shutdown() async` | Shutdown drains the job queue and joins all worker OS threads. It uses `withCheckedContinuation` that is resumed from a condvar wait on worker threads. The caller must not be tied to the cooperative pool during the join phase. Consistent with `Lane.shutdown()` which is already `@concurrent`. |
| 3 | `.../IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.swift` | 27 | `func run(deadline:_:) async throws(IO.Lifecycle.Error<IO.Blocking.Lane.Error>) -> UnsafeMutableRawPointer` | Dispatches to abandoning worker threads. Same cross-isolation pattern as `Threads.runBoxed`: enqueues to OS threads, suspends via continuation, resumed from worker thread. |
| 4 | `.../IO Blocking/IO.Blocking.Lane.Abandoning.Runtime.swift` | 110 | `func shutdown() async` | Signals shutdown and waits on condvar for worker threads to drain. Resumed from OS thread context. |
| 5 | `.../IO/IO.run.swift` | 59 | `public static func run<T>(on:deadline:_:) async throws(IO.Lane.Error) -> T` | Public entry point that dispatches blocking work to a Lane (OS thread pool). Delegates to `lane._backing.run()` which is `@concurrent`. This function itself crosses isolation: the caller suspends on the cooperative pool and the work executes on a dedicated thread. Should be `@concurrent` to declare that it does not inherit caller isolation. |
| 6 | `.../IO/IO.run.swift` | 105 | `public static func run<T, E>(on:deadline:_:) async throws(IO.Failure.Work<IO.Lane.Error, E>) -> T` | Same as above, throwing variant. |
| 7 | `.../IO/IO.Executor.run.swift` | 49 | `internal static func run<T, E>(on:deadline:_:) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T` | Internal fast-path that bypasses actor hop and submits directly to a Lane. Crosses executor boundary. |
| 8 | `.../IO/IO.Executor.run.swift` | 84 | `internal static func run<T>(on:deadline:_:) async throws(IO.Lifecycle.Error<IO.Blocking.Error>) -> T` | Non-throwing variant, same pattern. |
| 9 | `.../IO/IO.open.swift` | 113 | `public static func open<Resource, T, CreateError, BodyError>(on:deadline:_:body:) async throws(IO.Failure.Scope<...>) -> T` | Dispatches create, body, and close to a Lane (OS thread pool). The entire scoped lifecycle runs on a different executor. |
| 10 | `.../IO/IO.Ready.swift` | 104 | `public func callAsFunction<T, BodyError>(_:) async throws(IO.Failure.Scope<...>) -> T` | Builder execution that dispatches to `lane.run()`. Crosses to OS thread pool. |
| 11 | `.../IO/IO.Blocking.Lane.open.swift` | 76 | `public func open<Resource, T, CreateError, BodyError>(_:_:) async throws(IO.Failure.Scope<...>) -> T` | Convenience that dispatches scoped lifecycle to a blocking lane. |

#### NOT candidates (correctly nonsending)

| File | Function | Why NOT @concurrent |
|------|----------|---------------------|
| `IO.Handle.Registry.swift` — `run()` (lines 265, 290) | `nonisolated func run<T, E>(...) async throws` | These are `nonisolated` on an actor. They delegate to `lane.run()` which is already `@concurrent`. The nonisolated method itself just does an atomic lifecycle check then awaits the lane. The executor hop happens inside `lane.run()`. However — **see discussion below**. |
| `IO.Handle.Registry.swift` — `register()` (line 508) | Actor-isolated | Runs on the actor's custom executor, not crossing boundaries. |
| `IO.Handle.Registry.swift` — `transaction()` (line 693) | Actor-isolated | Runs on the actor's custom executor. Delegates lane work to `lane.run()`. |
| `IO.Handle.Registry.swift` — `shutdown()` (line 335) | Actor-isolated | Runs on the actor's executor. |
| `IO.Handle.Registry.swift` — `withHandle()` (line 923) | Actor-isolated | Delegates to `transaction()`. |
| `IO.Handle.Registry.swift` — `withExecutorPreference()` (line 238) | Wrapper around stdlib | Just calls `withTaskExecutorPreference`. |
| `IO.Event.Selector` — all methods | Actor-isolated | The Selector is an actor pinned to a `Kernel.Thread.Executor`. All methods are actor-isolated and run on that executor. No `@concurrent` needed. |
| `IO.Event.Selector` — `runEventLoop()`, `runReplyLoop()` | Actor-isolated | Run on the selector's executor. |
| `IO.Event.Selector.shared()` | Returns cached value | Just awaits an actor property. |
| `IO.Completion.Queue` — all methods | Actor-isolated | The Queue is an actor. |
| `IO.Completion.Channel` — `read`, `write`, `accept`, `connect`, `close` | Delegates to actor | These `await queue.submit()` — the hop is on the actor side. |
| `IO.Executor.Shards` — all methods | Delegates to actor | `register`, `transaction`, `withHandle`, etc. all delegate to actor-isolated `Registry` methods. |
| `IO.Lane.shutdown()` | Delegates | Calls `_backing.shutdown()` which is already `@concurrent`. |

#### Discussion: `IO.Handle.Registry.run()` (nonisolated)

These two `nonisolated` async methods on an actor are an interesting edge case. They bypass actor isolation intentionally (atomic lifecycle check) and then call `lane.run()` which is `@concurrent`. Under nonsending defaults, these nonisolated methods would inherit caller isolation. Since they delegate to an `@concurrent` method, the compiler should allow the call — but the function itself is designed to NOT run on the caller's executor. It performs an atomic check and then crosses to the lane. Marking them `@concurrent` would be accurate to their intent. **Recommend: mark `@concurrent`**.

| # | File | Line | Current Signature | Rationale |
|---|------|------|-------------------|-----------|
| 12 | `.../IO/IO.Handle.Registry.swift` | 265 | `internal nonisolated func run<T, E>(_:) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T` | Nonisolated async on actor; performs atomic check then delegates to `@concurrent` lane.run(). Should be `@concurrent` to match its cross-isolation nature. |
| 13 | `.../IO/IO.Handle.Registry.swift` | 290 | `internal nonisolated func run<T, E>(deadline:_:) async throws(IO.Lifecycle.Error<IO.Error<E>>) -> T` | Same as above with deadline parameter. |

### Package 2: swift-kernel

**No candidates found.**

`swift-kernel` provides synchronous thread primitives:
- `Kernel.Thread.Executor` — `enqueue()` is synchronous; `runLoop()` is a synchronous blocking loop on a dedicated OS thread; `shutdown()` is synchronous (blocks to join).
- `Kernel.Thread.Executors` — `next()` is synchronous; `shutdown()` is synchronous.
- `Kernel.Thread.Worker` — `start()`, `stop()`, `join()` are all synchronous.
- `Kernel.Thread.spawn` — synchronous.
- `Kernel.Continuation` — namespace only, no async methods.

None of these have async methods. The kernel layer is intentionally synchronous, providing the building blocks that higher layers (swift-io) use to bridge into async.

### Package 3: swift-async-primitives

**No candidates found.**

All async in this package involves cooperative suspension primitives (`withCheckedContinuation`, `withTaskCancellationHandler`) where the continuation is resumed from the same logical concurrency domain or by the waiter mechanism. These are **coordination primitives**, not cross-executor dispatch:

- `Async.Waiter` — cooperative suspension, resumed by whoever holds the waiter reference
- `Async.Channel.Bounded/Unbounded` — producer/consumer coordination
- `Async.Broadcast` — fan-out coordination
- `Async.Mutex` — async mutual exclusion
- `Async.Barrier` — async barrier
- `Async.Promise` — one-shot value delivery
- `Async.Bridge` — thread-safe push/pull bridge (the `next()` method suspends cooperatively)
- `Async.Timer.Wheel` — cooperative timer infrastructure

All of these should correctly inherit caller isolation. They do not create their own execution context or dispatch to a different executor.

### Package 4: swift-async

**No candidates found.**

This package contains `Async.Stream` operators (map, filter, merge, combineLatest, debounce, throttle, flatMap, etc.). All `next() async -> Element?` implementations:

1. Call the upstream's `next()` (inheriting isolation)
2. Use `Async.Waiter` or `Async.Channel` for coordination (cooperative)
3. Never dispatch to a different executor

Stream operators should inherit caller isolation — they are pure data-flow transformations. Marking any of these `@concurrent` would be incorrect.

## Summary Table: All Candidates

| # | Package | File | Line | Signature (abbreviated) | Reason |
|---|---------|------|------|-------------------------|--------|
| 1 | swift-io | `IO.Blocking.Threads.swift` | 93 | `runBoxed(deadline:_:) async throws` | Core thread pool dispatch; continuation resumed from OS thread |
| 2 | swift-io | `IO.Blocking.Threads.swift` | 254 | `shutdown() async` | Joins worker OS threads via condvar wait |
| 3 | swift-io | `IO.Blocking.Lane.Abandoning.Runtime.swift` | 27 | `run(deadline:_:) async throws` | Dispatches to abandoning worker threads |
| 4 | swift-io | `IO.Blocking.Lane.Abandoning.Runtime.swift` | 110 | `shutdown() async` | Condvar wait on worker threads |
| 5 | swift-io | `IO.run.swift` | 59 | `IO.run<T>(on:deadline:_:) async throws` | Public entry; dispatches to Lane (OS threads) |
| 6 | swift-io | `IO.run.swift` | 105 | `IO.run<T,E>(on:deadline:_:) async throws` | Public entry; throwing variant |
| 7 | swift-io | `IO.Executor.run.swift` | 49 | `Executor.run<T,E>(on:deadline:_:) async throws` | Fast-path lane dispatch |
| 8 | swift-io | `IO.Executor.run.swift` | 84 | `Executor.run<T>(on:deadline:_:) async throws` | Non-throwing variant |
| 9 | swift-io | `IO.open.swift` | 113 | `IO.open<...>(on:deadline:_:body:) async throws` | Scoped lifecycle on Lane |
| 10 | swift-io | `IO.Ready.swift` | 104 | `callAsFunction<T,BodyError>(_:) async throws` | Builder execution on Lane |
| 11 | swift-io | `IO.Blocking.Lane.open.swift` | 76 | `open<...>(_:_:) async throws` | Scoped lifecycle on Lane |
| 12 | swift-io | `IO.Handle.Registry.swift` | 265 | `nonisolated run<T,E>(_:) async throws` | Nonisolated actor method; delegates to @concurrent lane |
| 13 | swift-io | `IO.Handle.Registry.swift` | 290 | `nonisolated run<T,E>(deadline:_:) async throws` | Same with deadline |

**swift-kernel**: 0 candidates (no async functions)
**swift-async-primitives**: 0 candidates (cooperative coordination only)
**swift-async**: 0 candidates (stream operators inherit isolation)

## Priority

**High (must fix)**: Candidates 1-4 — these are the actual dispatch implementations where continuations are resumed from OS threads. Without `@concurrent`, nonsending semantics would incorrectly constrain them to the caller's isolation domain.

**Medium (should fix)**: Candidates 5-11 — public/internal API entry points that delegate to `@concurrent` lane methods. Marking these `@concurrent` makes the contract explicit at the API boundary and prevents the compiler from adding unnecessary isolation inheritance overhead.

**Low (recommend)**: Candidates 12-13 — nonisolated actor methods that delegate to `@concurrent` lane. Technically the compiler allows calling `@concurrent` from a nonsending function, but marking these `@concurrent` accurately documents their cross-isolation intent.

## Test Approach

After applying `@concurrent`:
1. `swift build` — verify no new compiler errors
2. `swift test` — verify existing tests pass
3. Spot-check that no `@concurrent` function is called from a context that requires isolation inheritance (e.g., actor-isolated closures that need to capture `self`)
