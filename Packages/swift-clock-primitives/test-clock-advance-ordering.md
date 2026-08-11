# Test Clock Advance Ordering

<!--
---
version: 3.0.0
last_updated: 2026-03-01
status: DECISION
tier: 1
---
-->

## Context

The test `advance resumes multiple sleeps in order` fails intermittently. Two tasks sleep
with different deadlines (2s and 4s), a single `advance(by: .seconds(5))` resumes both,
and the test asserts the post-sleep bodies execute in deadline order (`[1, 2]`). The observed
failure is `[2, 1]`.

We provided `nonisolated(nonsending)` overloads of `withCheckedContinuation` and
`withTaskCancellationHandler` in `swift-standard-library-extensions`, wired them into
`clock-primitives` via `@_exported public import`, and observed: the test still fails
intermittently. The nonsending overloads are necessary infrastructure but do not fix this
problem. This document analyzes why.

## Question

Why does `Clock.Test.advance(to:)` produce nondeterministic post-resume execution order,
and why don't `nonisolated(nonsending)` continuation overloads fix it?

## Analysis

### Layer 1: `advance(to:)` fires all resumes in a synchronous loop

```swift
// Clock.Test.swift:114-126
public func advance(to deadline: Instant) {
    let toResume: [CheckedContinuation<Void, Never>] = state.withLock { st in
        st.now = deadline
        st.suspensions.sort { $0.deadline < $1.deadline }
        var ready: [CheckedContinuation<Void, Never>] = []
        while let head = st.suspensions.first, head.deadline <= deadline {
            ready.append(head.continuation)
            st.suspensions.removeFirst()
        }
        return ready
    }
    for c in toResume { c.resume() }
}
```

Continuations are collected in deadline order (sorted). The `for` loop calls `resume()` in
that order. But `CheckedContinuation.resume()` does **not** execute the continuation body
inline — it **enqueues** the continuation onto an executor. After the loop completes, all
continuation bodies are enqueued simultaneously and race for execution.

### Layer 2: `resume()` enqueues on the continuation's executor

When `resume()` is called on a `CheckedContinuation`, the Swift runtime schedules the
continuation body on the executor that was captured when `withCheckedContinuation` was
called. Which executor is captured depends on the isolation context at the call site.

The continuation is created inside `Clock.Test.sleep`:

```swift
nonisolated(nonsending)
public func sleep(until deadline: Instant, ...) async throws {
    // ...
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        state.withLock { st in
            st.suspensions.append(State.Entry(id: id, deadline: deadline, continuation: continuation))
        }
    }
    // ...
}
```

The `withCheckedContinuation` call resolves to our nonsending overload (from
`Standard_Library_Extensions`), which calls `_Concurrency.withCheckedContinuation`. The
stdlib function has signature:

```swift
public func withCheckedContinuation<T>(
    isolation: isolated (any Actor)? = #isolation,
    function: String = #function,
    _ body: (CheckedContinuation<T, Never>) -> Void
) async -> T
```

The `isolation:` parameter defaults to `#isolation`. Per SE-0461, `#isolation` inside a
`nonisolated(nonsending)` async function evaluates to the **implicit isolated parameter**
(the caller's actor), not always `nil`. So our wrapper correctly forwards isolation.

### Layer 3: The caller has no actor isolation

The isolation chain from test to continuation:

```
Test function                    → cooperative pool (no actor, #isolation = nil)
  └─ Task.immediate { }         → inherits test's isolation (nil)
       └─ clock.sleep()         → nonisolated(nonsending), inherits nil
            └─ our wrapper      → nonisolated(nonsending), inherits nil, #isolation = nil
                 └─ stdlib      → isolation: nil → continuation resumes on cooperative pool
```

`#isolation` correctly propagates through the nonsending wrapper (per SE-0461). But the
value being propagated is `nil` — because the test function itself has no actor isolation.
The continuation is created with `isolation: nil`, so `resume()` enqueues onto the
**cooperative thread pool**.

### Layer 4: The cooperative thread pool is not a serial executor

The cooperative thread pool is a multi-threaded work-stealing pool. When multiple items
are enqueued, **any available thread** can pick up any item. There is no FIFO guarantee
across threads.

After `advance(to:)` calls `resume()` for both continuations:
- Thread A might pick up task1's continuation → appends `1`
- Thread B might pick up task2's continuation → appends `2`
- Or Thread B picks up task2 first → appends `2` before `1`

The enqueue order is deterministic (deadline-sorted). The execution order is not.

### Layer 5: Why `nonisolated(nonsending)` overloads don't fix this

Our nonsending `withCheckedContinuation` wrapper prevents an **unnecessary executor hop**.
Without it, the stdlib's non-nonsending version would always schedule the continuation on
the cooperative pool regardless of the caller's isolation. With our wrapper, the continuation
resumes on the caller's executor — which is correct behavior.

But the fix only matters when the caller IS on a serial executor:

| Caller context | Without nonsending | With nonsending |
|---|---|---|
| `@MainActor` (serial) | Resumes on cooperative pool → nondeterministic | Resumes on MainActor → **deterministic (FIFO)** |
| Cooperative pool (no actor) | Resumes on cooperative pool → nondeterministic | Resumes on cooperative pool → **still nondeterministic** |

The test runs without actor isolation. The nonsending overloads correctly preserve the
caller's context — which is `nil` (no actor). So `resume()` still enqueues on the
cooperative pool. No ordering improvement.

### Empirical evidence

We ran the test suite 3 times after adding nonsending overloads:
1. **93/93 passed** (including the ordering test)
2. **93/93 passed** (after typed-throws fix)
3. **95/96 failed** — the ordering test failed with `[2, 1]`

The nonsending overloads may reduce the race window (by eliminating one executor hop) but
do not eliminate the nondeterminism. The failure is intermittent, confirming a race condition
rather than a deterministic bug.

### Contrast with Point-Free's approach

Point-Free Episode 355 claims `nonisolated(nonsending)` makes test clocks deterministic.
Their context differs from ours in one critical way: **TCA features run on `@MainActor`**.
Their tests inherit `@MainActor` isolation, so:

```
@MainActor test function         → MainActor (serial, #isolation = MainActor.shared)
  └─ Task.immediate { }          → inherits @MainActor
       └─ clock.sleep()          → nonisolated(nonsending), inherits @MainActor
            └─ withChecked...    → isolation: MainActor.shared → resumes on MainActor
```

On the MainActor (serial executor), FIFO ordering is guaranteed. Nonsending ensures the
continuation resumes on the MainActor rather than hopping to the cooperative pool. The
combination of **nonsending + serial executor** produces deterministic ordering.

Point-Free's statement is accurate for their use case but implicitly assumes a serial
executor. The general statement "nonsending makes clocks deterministic" is incomplete — it
should be "nonsending + serial executor makes clocks deterministic."

### Summary of the problem

The nondeterminism has **two independent causes**, both of which must be addressed:

1. **`advance(to:)` provides no serialization** — it fires all `resume()` calls in a tight
   synchronous loop. There is no mechanism to wait for one continuation's post-resume work
   to complete before resuming the next.

2. **The cooperative thread pool has no FIFO guarantee** — multiple enqueued items race for
   execution across threads. This is a fundamental property of the cooperative pool, not a
   bug.

The nonsending overloads address a **third**, separate problem: the stdlib's non-nonsending
`withCheckedContinuation` causes unnecessary executor hops even when the caller IS on a
serial executor. The nonsending overloads are necessary infrastructure for serial-executor
determinism but are orthogonal to the cooperative-pool ordering problem.

## Outcome

**Status**: DECISION — no source changes to `Clock.Test`; fix the tests.

### The clock is correct; the tests were wrong

The two causes identified above are not independent — cause 1 (batch resume) is only a
problem in combination with cause 2 (no FIFO). On a serial executor, FIFO guarantees
that batch-enqueued continuations execute in enqueue order. Since `advance(to:)` sorts
by deadline before calling `resume()`, the enqueue order is deadline order, and FIFO
preserves it.

Trace on `@MainActor`:

```
@MainActor test:
  advance(by: .seconds(5))          ← sync, runs on MainActor
    → resume(c1)                     ← enqueues c1 on MainActor
    → resume(c2)                     ← enqueues c2 on MainActor
    → returns

  try await task1.value              ← test suspends

  MainActor queue: [c1, c2]         ← FIFO
    → c1 dequeues: sleep returns, caller appends 1, task1 completes
    → c2 dequeues: sleep returns, caller appends 2, task2 completes

  result: [1, 2] ✓ deterministic
```

The two prerequisites are:

1. **`nonisolated(nonsending)` on `sleep()`** — ensures `resume()` targets the caller's
   executor rather than always hopping to the cooperative pool. Already in place via the
   nonsending `withCheckedContinuation` overload in `Standard_Library_Extensions`.

2. **A serial executor at the call site** — provides the FIFO guarantee. Tests that assert
   ordering of simultaneous resumes must use `@MainActor`.

### Rejected alternative: gate/serialization in `advance()`

Making `advance()` async with a gate/rendezvous pattern (each resume awaits a gate signal
from `sleep()` before firing the next) was considered and rejected:

- **Unnecessary on serial executors**: FIFO already serializes execution in enqueue order.
- **Insufficient on the cooperative pool**: the gate serializes `sleep()` itself but
  post-sleep caller work still races across threads — the cooperative pool's lack of FIFO
  is unfixable from inside the clock.
- **Breaks the synchronous API**: `advance()` and `run()` would become `async`, requiring
  `await` at every call site across the ecosystem.
- **Over-engineers the primitive**: deterministic ordering is a property of the execution
  context, not the clock. The clock's job is controllable time, not executor serialization.

### Changes applied

- Added `@MainActor` to 3 ordering tests that assert simultaneous-resume order:
  `advance resumes multiple sleeps in order`, `reverse-scheduled sleeps resume in deadline
  order`, `cancelled task does not disrupt ordering of remaining sleeps`.
- `sequential advances resume correct subsets in order` does NOT need `@MainActor` — each
  advance resumes exactly one task, and the test awaits completion before the next advance.
- No changes to `Clock.Test.swift`.

## Related Documents

In order of relevance:

1. **[Pre-Pitch: nonsending continuations](https://forums.swift.org/t/pre-pitch-updating-with-checked-unsafe-continuation-to-support-typed-throws-and-perhaps-nonisolated-nonsending/84770)** — The stdlib change that would make `withCheckedContinuation` natively `nonisolated(nonsending)` with typed throws. Necessary infrastructure for serial-executor determinism. Active implementation by ktoso.

2. **[SE-0461: Async function isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)** — Defines `#isolation` semantics in `nonisolated(nonsending)` functions. Confirms `#isolation` forwards the implicit isolated parameter (not always `nil`). This is why our wrapper correctly propagates isolation — but `nil` in, `nil` out.

3. **[Point-Free Episode 355: Beyond Basics](https://www.pointfree.co/episodes/ep355-beyond-basics-isolation-copyable-escapable)** — "Synchronous sleep" section (22:22–29:15). Demonstrates nonsending + `@MainActor` = deterministic test clocks. Key insight: their approach implicitly requires a serial executor; they don't test on the cooperative pool.

4. **[SE-0472: Task.immediate](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)** — Guarantees task body executes synchronously to first suspension point. Ensures sleep registration is deterministic; does not affect post-resume execution ordering.

5. **[instant-affine-arithmetic.md](instant-affine-arithmetic.md)** — The Tagged instant refactor that first exposed this test failure. Confirmed the failure is pre-existing, not a regression from the refactor.

6. **[SE-0420: Inheritance of actor isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)** — Introduced `#isolation` macro. Baseline semantics extended by SE-0461 for nonsending functions.

7. **[swiftlang/swift#83760](https://github.com/swiftlang/swift/issues/83760)** — Compiler bug: `nonisolated(nonsending)` to `@isolated(any)` conversion uses `nil` actor. Related but distinct from our case — our wrapper uses `#isolation` default parameter expansion, not `@isolated(any)` conversion. Open as of 2025-08-15.

8. **[Point-Free swift-clocks TestClock](https://github.com/pointfreeco/swift-clocks/blob/main/Sources/Clocks/TestClock.swift)** — 1.x approach using async `advance()` + `Task.megaYield()`. Explicitly rejected for primitives layer.
