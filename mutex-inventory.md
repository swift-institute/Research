# Mutex Inventory

Cross-repo inventory of all Mutex usage in `Sources/` directories across `swift-primitives` and `swift-foundations`.

**Scope**: `**/Sources/**/*.swift` only. Excludes `.build/`, `Tests/`, `Benchmarks/`, `Experiments/`.

**Date**: 2026-03-30

---

## Mutex Type Legend

| Short Name | Fully Qualified | Origin |
|------------|----------------|--------|
| `Synchronization.Mutex` | `Synchronization.Mutex<Value>` | Swift stdlib `Synchronization` module |
| `Async.Mutex` | Typealias to `Synchronization.Mutex` (or `Kernel.Thread.Mutex.Value` / embedded no-op) | `swift-async-primitives` |
| `Kernel.Thread.Mutex` | `ISO_9945.Kernel.Thread.Mutex` (POSIX) / `Windows.Kernel.Thread.Mutex` (Windows) | Platform-specific, manual lock/unlock |
| `Mutex` (bare) | Resolves to `Synchronization.Mutex` via `import Synchronization` or `@_exported import` | Context-dependent |

---

## swift-primitives

### swift-async-primitives (Async Primitives Core)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Async.Mutex.swift | 13 | Import | `@_exported public import Synchronization` | Re-exports Synchronization module |
| Async.Mutex.swift | 19 | Declaration (typealias) | `Async.Mutex = Synchronization.Mutex` | Platform-conditional typealias definition |
| Async.Mutex.swift | 30 | Declaration (typealias) | `Async.Mutex = Kernel.Thread.Mutex.Value` | Fallback typealias for non-Synchronization platforms |
| Async.Mutex.swift | 40 | Declaration (class) | `Async.Mutex<Value>` (embedded) | No-op mutex class for embedded platforms |
| Async.Mutex+Deque.swift | 13 | Import | `public import Synchronization` | For Mutex constraint extensions |
| Async.Mutex+Deque.swift | 39 | Usage (extension) | `Async.Mutex` | Queue operations (enqueue/dequeue/drain) on Mutex-wrapped Deque |
| Async.Promise.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Async.Promise.swift | 62 | Declaration (stored property) | `Async.Mutex<State>` | Protects promise fulfillment state and waiters |
| Async.Promise.swift | 71 | Declaration (init) | `Async.Mutex(State())` | Initializes mutex-protected state |
| Async.Completion.swift | 17 | Import | `public import Synchronization` | For Mutex usage |
| Async.Completion.swift | 74 | Declaration (stored property) | `Mutex<CheckedContinuation<Result, Never>?>` | Protects single-resume continuation |
| Async.Completion.swift | 79 | Declaration (init) | `Mutex(nil)` | Initializes nil continuation |
| Async.Barrier.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Async.Barrier.swift | 61 | Declaration (stored property) | `Async.Mutex<State>` | Protects barrier arrival count and waiters |
| Async.Barrier.swift | 77 | Declaration (init) | `Async.Mutex(State())` | Initializes barrier state |
| Async.Publication.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Async.Publication.swift | 73 | Declaration (stored property) | `Async.Mutex<Value?>` | Protects published value |
| Async.Publication.swift | 79 | Declaration (init) | `Async.Mutex(initial)` | Initializes with optional initial value |
| Async.Bridge.swift | 17 | Import | `import Synchronization` | For Mutex usage |
| Async.Bridge.swift | 60 | Declaration (stored property) | `Mutex<State>` | Protects sync-to-async bridge state |
| Async.Bridge.swift | 73 | Declaration (init) | `Mutex(State())` | Initializes bridge state |

### swift-async-primitives (Async Channel Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Async.Channel.Unbounded.Storage.swift | 16 | Import | `public import Synchronization` | For Mutex usage |
| Async.Channel.Unbounded.Storage.swift | 23 | Declaration (stored property) | `Mutex<State>` | Protects unbounded channel send/receive state |
| Async.Channel.Unbounded.Storage.swift | 32 | Declaration (init) | `Mutex(State())` | Initializes channel state |
| Async.Channel.Bounded.Storage.swift | 16 | Import | `public import Synchronization` | For Mutex usage |
| Async.Channel.Bounded.Storage.swift | 27 | Declaration (stored property) | `Ownership.Mutable<Mutex<State>>.Unchecked` | Protects bounded channel state via reference wrapper |
| Async.Channel.Bounded.Storage.swift | 36 | Declaration (init) | `Mutex(State(capacity: capacity))` | Initializes capacity-constrained channel |

### swift-async-primitives (Async Broadcast Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Async.Broadcast.swift | 17 | Import | `import Synchronization` | For Mutex usage |
| Async.Broadcast.swift | 80 | Declaration (stored property) | `Mutex<State>` | Protects broadcast subscriber list and sequence counter |
| Async.Broadcast.swift | 90 | Declaration (init) | `Mutex(State())` | Initializes broadcast state |

### swift-async-primitives (Async Waiter Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Async.Waiter.swift | 12 | Import | `import Synchronization` | For Atomic usage (no Mutex declarations) |
| Async.Waiter.Flag.swift | 12 | Import | `public import Synchronization` | For Atomic usage (no Mutex declarations) |

### swift-pool-primitives (Pool Bounded Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Pool.Bounded.swift | 2 | Import | `public import Synchronization` | For Mutex usage |
| Pool.Bounded.swift | 31 | Declaration (stored property) | `Async.Mutex<State>` | Protects pool bookkeeping (available items, waiters, lifecycle) |
| Pool.Bounded.swift | 78 | Declaration (init) | `Async.Mutex(State(capacity:))` | Initializes pool with capacity |
| Pool.Bounded.swift | 110 | Declaration (init) | `Async.Mutex(State(capacity:))` | Secondary initializer |
| Pool.Bounded.Acquire.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Pool.Bounded.Acquire.Timeout.swift | 15 | Import | `import Synchronization` | For Mutex usage |
| Pool.Bounded.Acquire.Try.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Pool.Bounded.Acquire.Callback.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Pool.Bounded.Fill.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Pool.Bounded.Shutdown.swift | 13 | Import | `import Synchronization` | For Mutex usage |

### swift-pool-primitives (Pool Primitives Core)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Pool.Scope.swift | 5 | Import | `import Synchronization` | For Mutex usage |
| Pool.Scope.swift | 11 | Declaration (module-level) | `Async.Mutex<UInt64>` | Global scope ID counter |

### swift-cache-primitives

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Cache.Storage.swift | 21 | Declaration (stored property) | `Ownership.Mutable<Async.Mutex<State>>.Unchecked` | Protects cache entry storage via reference wrapper |
| Cache.Storage.swift | 25 | Declaration (init) | `Async.Mutex(State())` | Initializes cache state |

### swift-test-primitives (Test Primitives Core)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Test.Attachment.Collector.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| Test.Attachment.Collector.swift | 31 | Declaration (stored property) | `Mutex<[Test.Attachment]>` | Protects collected test attachments |

### swift-clock-primitives

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Clock.Immediate.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| Clock.Immediate.swift | 39 | Declaration (stored property) | `Mutex<State>` | Protects clock now/resolution state |
| Clock.Immediate.swift | 42 | Declaration (init) | `Mutex(State(now:, minimumResolution:))` | Initializes immediate clock |
| Clock.Test.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| Clock.Test.swift | 58 | Declaration (stored property) | `Mutex<State>` | Protects test clock time and suspension list |
| Clock.Test.swift | 61 | Declaration (init) | `Mutex(State(now:, minimumResolution:))` | Initializes test clock |

### swift-kernel-primitives (Kernel Thread Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Kernel.Thread.Mutex.swift | 14-22 | Comment only | `Kernel.Thread.Mutex` | Documents that implementation lives in platform-specific packages |

### swift-windows-primitives (Windows Kernel Primitives)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Windows.Kernel.Thread.Mutex.swift | 40 | Declaration (class) | `Windows.Kernel.Thread.Mutex` | SRWLOCK-based mutex class definition |
| Windows.Kernel.Thread.Mutex.swift | 55 | Usage (extension) | `Windows.Kernel.Thread.Mutex` | Lock/unlock operations |
| Windows.Kernel.Thread.Mutex.swift | 73 | Declaration (nested struct) | `Windows.Kernel.Thread.Mutex.Lock` | Lock accessor with blocking/immediate variants |
| Windows.Kernel.Thread.Mutex.swift | 76 | Declaration (stored property) | `Windows.Kernel.Thread.Mutex` | Stored reference within Lock accessor |
| Windows.Kernel.Thread.Mutex.swift | 121 | Usage (method) | `Windows.Kernel.Thread.Mutex` | `withLock` implementation |
| Windows.Kernel.Thread.Mutex.swift | 130 | Usage (extension) | `Windows.Kernel.Thread.Mutex` | Internal SRWLOCK pointer access for Condition |
| Windows.Kernel.Thread.Condition.swift | 68 | Usage (parameter) | `Windows.Kernel.Thread.Mutex` | `wait(mutex:)` parameter for condition variable |
| Windows.Kernel.Thread.Condition.swift | 83 | Usage (parameter) | `Windows.Kernel.Thread.Mutex` | `wait(mutex:timeout:)` Duration overload |
| Windows.Kernel.Thread.Condition.swift | 99 | Usage (parameter) | `Windows.Kernel.Thread.Mutex` | `wait(mutex:milliseconds:)` raw overload |

---

## swift-foundations

### swift-io (IO Core)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| exports.swift | 10 | Import | `@_exported import Synchronization` | Re-exports Synchronization for all IO targets |

### swift-io (IO Events)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| IO.Event.Registry.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| IO.Event.Registry.swift | 13 | Declaration (typealias) | `Synchronization.Mutex<[Int32: [IO.Event.ID: IO.Event.Registration.Entry]]>` | Fully-qualified typealias for event registry |
| IO.Event.Registry.swift | 17 | Declaration (static property) | `IO.Event.Registry` (Synchronization.Mutex) | Shared singleton fd-to-registrations map |
| IO.Event.Poll.Operations.swift | 11 | Import | `import Synchronization` | For Mutex usage |
| IO.Event.Poll.Operations.swift | 17 | Declaration (module-level) | `Mutex<[Int32: [IO.Event.ID: IO.Event.Registration.Entry]]>` | Linux epoll fd-to-registrations registry |
| IO.Event.Queue.Operations.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| IO.Event.Registration.Queue.swift | 8 | Import | `public import Synchronization` | For Mutex usage |
| IO.Event.Registration.Queue.swift | 16 | Declaration (typealias) | `Ownership.Mutable<Mutex<Deque<T>>>.Unchecked` | Shared queue protected by Mutex |
| IO.Event.Registration.Queue.swift | 21 | Usage (extension) | `Mutex<Deque<Element>>` | Dequeue operation |
| IO.Event.Registration.Queue.swift | 29 | Usage (extension) | `Mutex<Deque<Element>>` | Drain operation |
| IO.Event.Registration.Queue.swift | 40 | Usage (extension) | `Mutex<Deque<Element>>` | Enqueue operation |
| IO.Event.Buffer.Pool.swift | 8 | Import | `internal import Synchronization` | For Mutex usage |
| IO.Event.Buffer.Pool.swift | 33 | Declaration (stored property) | `Mutex<Memory.Pool>` | Protects shared buffer pool for event I/O |
| IO.Event.Buffer.Pool.swift | 67 | Declaration (init) | `Mutex(pool)` | Initializes buffer pool |
| IO.Event.Selector.swift | 12 | Import | `internal import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Event.Selector.Runtime.swift | 10 | Import | `internal import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Event.Channel.Storage.swift | 6 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-io (IO Completions)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| IO.Completion.Submit.Queue.swift | 6 | Import | `import Synchronization` | For Mutex usage |
| IO.Completion.Submit.Queue.swift | 16 | Declaration (typealias) | `Ownership.Mutable<Mutex<Deque<Entry>>>.Unchecked` | Shared submit queue |
| IO.Completion.Submit.Queue.swift | 21 | Usage (extension) | `Mutex<Deque<IO.Completion.Submit.Entry>>` | Enqueue/dequeue on submit queue |
| IO.Completion.Submission.Queue.swift | 8 | Import | `public import Synchronization` | For Mutex usage |
| IO.Completion.Submission.Queue.swift | 17 | Declaration (typealias) | `Ownership.Mutable<Mutex<Deque<IO.Completion.Operation.Storage>>>.Unchecked` | Shared submission queue |
| IO.Completion.Submission.Queue.swift | 22 | Usage (extension) | `Mutex<Deque<IO.Completion.Operation.Storage>>` | Enqueue/dequeue on submission queue |
| IO.Completion.Queue.ID.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| IO.Completion.Queue.ID.swift | 17 | Declaration (stored property) | `Ownership.Mutable<Mutex<UInt64>>.Unchecked` | Shared atomic ID counter |
| IO.Completion.Queue.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| IO.Completion.Queue.swift | 84 | Declaration (stored property) | `Ownership.Mutable<Mutex<UInt64>>.Unchecked` | ID counter in queue |
| IO.Completion.Queue.swift | 107 | Declaration (init) | `Mutex(Deque())` | Initializes submission queue |
| IO.Completion.Queue.swift | 110 | Declaration (init) | `Mutex(Deque())` | Initializes submit queue |
| IO.Completion.Queue.swift | 111 | Declaration (init) | `Mutex(1)` | Initializes ID counter at 1 |
| IO.Completion.Queue.Runtime.swift | 6 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Completion.Waiter.swift | 9 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Completion.Waiter.State.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Completion.Waiter.Take.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-io (IO Executor)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| IO.Executor.Handle.Entry.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| IO.Executor.Handle.Entry.swift | 39 | Declaration (stored property) | `Mutex<Int>` | Tracks mutation depth for reentrancy detection |
| IO.Executor.Slot.Pool.swift | 7 | Import | `internal import Synchronization` | For Mutex usage |
| IO.Executor.Slot.Pool.swift | 23 | Declaration (stored property) | `Mutex<Memory.Pool>` | Protects executor slot allocation pool |
| IO.Executor.Slot.Pool.swift | 46 | Declaration (init) | `Mutex(pool)` | Initializes slot pool |
| IO.Executor.Shards.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Executor.Counter.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Handle.Registry.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-io (IO Blocking Threads)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| IO.Blocking.Threads.swift | 10 | Import | `import Synchronization` | For Mutex usage |
| IO.Blocking.Threads.swift | 121 | Declaration (local variable) | `Mutex<Completion.Context?>` | Holds cancellation context between continuation and onCancel |
| IO.Blocking.Threads.Runtime.State.swift | 11 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Threads.Metrics.Counters.Cell.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Threads.Metrics.Counters.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Threads.Runtime.State.Gauge.Storage.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Lane.Sharded.Selector.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-io (IO Blocking)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| IO.Blocking.Lane.Abandoning.Job.swift | 8 | Import | `import Synchronization` | For Atomic usage |
| IO.Blocking.Lane.Abandoning.Job.swift | 32 | Declaration (stored property) | `Kernel.Thread.Mutex` | Protects job continuation for single-resume guarantee |
| IO.Blocking.Lane.Abandoning.Worker.swift | 8 | Import | `import Synchronization` | For Atomic usage |
| IO.Blocking.Lane.Abandoning.Worker.swift | 101 | Declaration (local variable) | `Kernel.Thread.Mutex` | Watchdog mutex for timeout condition signaling |
| IO.Blocking.Lane.Abandoning.Worker.swift | 110 | Usage (lock) | `Kernel.Thread.Mutex` | `watchdogMutex.lock()` in spawned watchdog thread |
| IO.Blocking.Lane.Abandoning.Worker.swift | 113 | Usage (wait) | `Kernel.Thread.Mutex` | `watchdogCondition.wait(mutex:timeout:)` with mutex |
| IO.Blocking.Lane.Abandoning.Worker.swift | 115 | Usage (unlock) | `Kernel.Thread.Mutex` | `watchdogMutex.unlock()` after wait |
| IO.Blocking.Lane.Abandoning.Worker.swift | 139 | Usage (lock) | `Kernel.Thread.Mutex` | `watchdogMutex.lock()` before signal |
| IO.Blocking.Lane.Abandoning.Worker.swift | 141 | Usage (unlock) | `Kernel.Thread.Mutex` | `watchdogMutex.unlock()` after signal |
| IO.Blocking.Lane.Abandoning.Runtime.swift | 9 | Import | `import Synchronization` | For Mutex usage |
| IO.Blocking.Lane.Abandoning.Runtime.swift | 44 | Declaration (local variable) | `Mutex<IO.Blocking.Lane.Abandoning.Job?>` | Holds job for cancellation handler |
| IO.Blocking.Lane.Abandoning.Job.State.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Lane.Abandoning.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Lane.Handle.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| IO.Blocking.Lane.swift | 14 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-memory

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Memory.Allocation.Peak.Tracker.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| Memory.Allocation.Peak.Tracker.swift | 38 | Declaration (stored property) | `Mutex<State>` | Protects peak allocation tracking (bytes, count, samples) |
| Memory.Allocation.Peak.Tracker.swift | 45 | Declaration (init) | `Mutex(State())` | Initializes tracker state |
| Memory.Allocation.Profiler.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| Memory.Allocation.Profiler.swift | 36 | Declaration (stored property) | `Mutex<[Memory.Allocation.Statistics]>` | Protects measurement history |
| Memory.Allocation.Profiler.swift | 40 | Declaration (init) | `Mutex([])` | Initializes empty measurement list |

### swift-tests (Tests Core)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Test.Manifest.swift | 12 | Import | `import Synchronization` | For Mutex usage |
| Test.Manifest.swift | 38 | Declaration (static property) | `Mutex<[Swift.String]>` | Protects registered test factory names |
| Test.Expectation.Collector.swift | 10 | Import | `import Synchronization` | For Mutex usage |
| Test.Expectation.Collector.swift | 45 | Declaration (stored property) | `Mutex<[Test.Expectation]>` | Protects collected expectations |
| Test.Expectation+Factory.swift | 10 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-tests (Tests Reporter)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Test.Reporter.Terminal.swift | 15 | Import | `import Synchronization` | For Mutex usage |
| Test.Reporter.Terminal.swift | 38 | Declaration (stored property) | `Mutex<(passed: Int, failed: Int, skipped: Int, issues: Int)>` | Protects test result counters |
| Test.Reporter.Structured.swift | 11 | Import | `import Synchronization` | For Mutex usage |
| Test.Reporter.Structured.swift | 34 | Declaration (stored property) | `Mutex<[JSON]>` | Protects structured test records |
| Test.Reporter.JSON.swift | 21 | Import | `import Synchronization` | For Mutex usage |
| Test.Reporter.JSON.swift | 43 | Declaration (stored property) | `Mutex<[Test.Event]>` | Protects collected test events |

### swift-tests (Tests Inline Snapshot)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Test.Snapshot.Inline.State.swift | 9 | Import | `import Synchronization` | For Mutex usage |
| Test.Snapshot.Inline.State.swift | 30 | Declaration (stored property) | `Mutex<[Swift.String: [Entry]]>` | Protects inline snapshot entries by file |

### swift-tests (Tests Snapshot)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Test.Snapshot.Counter.swift | 10 | Import | `import Synchronization` | For Mutex usage |
| Test.Snapshot.Counter.swift | 28 | Declaration (stored property) | `Mutex<Void>` | Lock-only mutex (no protected value), guards file system counter |

### swift-tests (Tests Performance)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Tests.Diagnostic.Collector.swift | 8 | Import | `import Synchronization` | For Mutex usage |
| Tests.Diagnostic.Collector.swift | 21 | Declaration (stored property) | `Mutex<[Tests.Diagnostic]>` | Protects collected performance diagnostics |

### swift-effects (Effects Testing)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Effect.Test.Recorder.swift | 44 | Declaration (stored property) | `Async.Mutex<[Invocation]>` | Protects recorded effect invocations |
| Effect.Test.Spy.swift | 40 | Declaration (stored property) | `Async.Mutex<[Invocation]>` | Protects spy captured invocations |

### swift-witnesses

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Witness.Cycle.swift | 14 | Import | `public import Synchronization` | For Mutex usage |
| Witness.Cycle.swift | 41 | Declaration (stored property) | `Mutex<Int>` | Protects cycling index through value sequence |
| Witness.Cycle.swift | 51 | Declaration (init) | `Mutex(0)` | Initializes cycle index at 0 |
| Witness.Recording.swift | 14 | Import | `public import Synchronization` | For Mutex usage |
| Witness.Recording.swift | 48 | Declaration (stored property) | `Mutex<[Args]>` | Protects recorded witness call arguments |
| Witness.Recording.swift | 59 | Declaration (init) | `Mutex([])` | Initializes empty call log |
| Witness.Sequence.swift | 14 | Import | `public import Synchronization` | For Mutex usage |
| Witness.Sequence.swift | 42 | Declaration (stored property) | `Mutex<Int>` | Protects sequential index through value array |
| Witness.Sequence.swift | 52 | Declaration (init) | `Mutex(0)` | Initializes sequence index at 0 |
| Witness.Preparation.Store.swift | 13 | Import | `import Synchronization` | For Mutex usage |
| Witness.Preparation.Store.swift | 42 | Declaration (stored property) | `Mutex<Void>` | Lock-only mutex guarding unsafe nonisolated(unsafe) storage |
| Witness.Preparation.Store.swift | 47 | Declaration (init) | `Mutex(())` | Initializes lock |

### swift-kernel (Kernel Thread)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Kernel.Thread.Synchronization.swift | 39 | Declaration (stored property) | `Kernel.Thread.Mutex` | Internal mutex within Synchronization<N> wrapper |
| Kernel.Thread.Worker.Token.swift | 12 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| Kernel.Thread.Worker.swift | 12 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |
| Kernel.Thread.Executors.swift | 8 | Import | `import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-kernel (Kernel Continuation)

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Kernel.Continuation.Context.swift | 8 | Import | `public import Synchronization` | For Atomic usage (no direct Mutex) |

### swift-environment

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Environment.swift | 12 | Import | `public import Synchronization` | For Mutex usage |
| Environment.swift | 36 | Declaration (static property) | `Mutex<Void>` | Lock-only mutex guarding environment variable read/write |
| Environment.Read.swift | 14 | Import | `internal import Synchronization` | For Mutex usage |
| Environment.Write.swift | 13 | Import | `internal import Synchronization` | For Mutex usage |

### swift-pools

| File | Line | Category | Mutex Type | Context |
|------|------|----------|------------|---------|
| Pool.Blocking.Cancellation.swift | 1 | Import | `internal import Synchronization` | For Atomic usage (no direct Mutex) |

---

## Summary

### Declaration Count by Mutex Type

| Mutex Type | Stored Properties | Local Variables | Typealiases | Static Properties | Class Declarations | Total |
|------------|------------------|-----------------|-------------|-------------------|--------------------|-------|
| `Synchronization.Mutex` (bare `Mutex`) | 22 | 2 | 3 | 3 | 0 | 30 |
| `Async.Mutex` | 5 | 0 | 2 | 0 | 1 (embedded) | 8 |
| `Kernel.Thread.Mutex` | 2 | 1 | 0 | 0 | 1 (Windows) | 4 |

### By Package (declaration sites only, excluding imports and pure usages)

| Package | Declarations |
|---------|-------------|
| swift-async-primitives | 14 |
| swift-io | 12 |
| swift-tests | 7 |
| swift-witnesses | 6 |
| swift-pool-primitives | 3 |
| swift-clock-primitives | 4 |
| swift-memory | 4 |
| swift-effects | 2 |
| swift-windows-primitives | 3 |
| swift-cache-primitives | 1 |
| swift-test-primitives | 1 |
| swift-kernel | 1 |
| swift-environment | 1 |

### Key Patterns Observed

1. **Dominant pattern**: Bare `Mutex<State>` (resolving to `Synchronization.Mutex`) as stored property protecting an inner state struct.
2. **Reference-wrapped pattern**: `Ownership.Mutable<Mutex<T>>.Unchecked` used when the mutex-protected state needs shared reference semantics (IO queues, channel storage, cache).
3. **Async.Mutex**: Used in async primitives and effects testing -- resolves to `Synchronization.Mutex` on standard platforms.
4. **Kernel.Thread.Mutex**: Manual lock/unlock pattern used only in IO blocking (watchdog threads, job continuation protection) and kernel synchronization internals where condition variables require it.
5. **Lock-only Mutex**: `Mutex<Void>` appears 3 times (snapshot counter, preparation store, environment) where only mutual exclusion is needed without value protection.
