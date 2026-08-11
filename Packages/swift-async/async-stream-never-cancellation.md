# Async Stream Never Cancellation

<!--
---
version: 1.0.0
last_updated: 2026-02-25
status: RECOMMENDATION
---
-->

## Context

During test development for swift-async's temporal operators, the `Async.Stream.never` test hung indefinitely. The current implementation uses `withCheckedContinuation` and intentionally never resumes it:

```swift
public static var never: Self {
    Self {
        Iterator {
            await withCheckedContinuation { (_: CheckedContinuation<Element?, Never>) in
                // Never resume - stream hangs forever
            }
        }
    }
}
```

This triggers the runtime warning: `SWIFT TASK CONTINUATION MISUSE: never leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.`

**Trigger**: Test for `never` hung because `Task.cancel()` does not unblock a leaked continuation.

## Question

Is the current `never` implementation a bug? Should `Async.Stream.never` be cancellation-cooperative?

## Analysis

### Claim 1: Leaking a CheckedContinuation is a programming error

**Verdict: TRUE.**

SE-0300 (Continuations for interfacing async tasks with synchronous code) is unambiguous:

> "The task remains in the suspended state until it is resumed; if the continuation is discarded and never resumed, then the task will be left suspended until the process ends, **leaking any resources it holds**."

> "It is still a **serious programming error** if a `with*Continuation` operation misuses the continuation."

The runtime enforces this:
- Non-embedded: warning via `logFailedCheck()`
- Embedded: `fatalError` (crash)

The `CheckedContinuation` contract requires exactly-once resumption. The current `never` violates this contract.

### Claim 2: Async sequences should be cancellation-cooperative

**Verdict: De facto TRUE, but not formally mandated.**

| Source | Statement | Strength |
|--------|-----------|----------|
| SE-0298 (AsyncSequence) | "should use the cancellation primitives provided by Swift's Task API" | Advisory ("should") |
| SE-0304 (Structured Concurrency) | "cancellation has no effect at all unless something checks for cancellation" | Descriptive |
| Philippe Hausler (Apple) | "Ignoring cancellation is breaking expectations" | Authoritative opinion |
| `AsyncStream` implementation | Returns `nil` from `next()` when task is cancelled | Standard library precedent |

Every major reactive framework treats cancellation-cooperativeness as mandatory:

| Framework | "Never" Primitive | Responds to Cancellation? | Mechanism |
|-----------|-------------------|--------------------------|-----------|
| Swift `AsyncStream` | `AsyncStream { _ in }` | **Yes** | Returns `nil` from `next()` |
| Combine | `Empty(completeImmediately: false)` | **Yes** | `AnyCancellable.cancel()` teardown |
| RxSwift | `Observable.never()` | **Yes** (trivially) | Returns empty `Disposable` |
| ReactiveSwift | `Signal.never` | **Yes** | Sends `.interrupted` on disposal |

The only framework where cancellation-cooperativeness is not formally enforced is Swift's `AsyncSequence` — but the standard library's own `AsyncStream` IS cooperative, and Apple engineers consider non-cooperative behavior to be "breaking expectations."

### Current implementation consequences

1. **Permanent task suspension** — consuming task never resumes, even after cancellation
2. **Resource leak** — all resources held by the task are leaked until process exit
3. **Runtime warning** — `SWIFT TASK CONTINUATION MISUSE` on non-embedded, `fatalError` on embedded
4. **Untestable** — cannot write a test that consumes `never` and verifies it completes on cancellation

### Option A: Keep current implementation (never resumes)

- Matches the mathematical definition of "never" (a stream with no events, ever)
- Violates SE-0300 continuation contract
- Causes resource leaks
- Crashes on embedded platforms

### Option B: Make cancellation-cooperative (return nil on cancel)

- `never` suspends indefinitely but returns `nil` when the consuming task is cancelled
- Matches `AsyncStream { _ in }` semantics (Point-Free's pattern)
- Matches Combine, RxSwift, ReactiveSwift behavior
- No continuation leak, no runtime warning
- Testable

### Option C: Check cancellation before suspending, but don't respond mid-suspension

- Only helps if `Task.isCancelled` is already true before consuming
- Still hangs if cancelled after `for await` begins
- Half-measure — doesn't solve the core problem

### Comparison

| Criterion | A: Current | B: Cancellation-cooperative | C: Pre-check only |
|-----------|-----------|---------------------------|-------------------|
| SE-0300 compliance | No | Yes | No |
| Resource safety | Leaks | Clean | Leaks |
| Embedded safety | Crashes | Safe | Crashes |
| Testable | No | Yes | No |
| Prior art alignment | None | All frameworks | None |
| Semantic accuracy | "Never, period" | "Never, unless cancelled" | Inconsistent |

### Implementation of Option B

The simplest correct approach — `Task.sleep` throws `CancellationError` when cancelled:

```swift
public static var never: Self {
    Self {
        Iterator {
            try? await Task.sleep(for: .seconds(Int64.max))
            return nil
        }
    }
}
```

`Task.sleep(for: .seconds(Int64.max))` suspends for ~292 billion years. When the task is cancelled, `Task.sleep` throws `CancellationError`, `try?` catches it, and the iterator returns `nil` — cleanly terminating the stream.

No continuation leak. No `withTaskCancellationHandler` gymnastics. No shared atomic state.

## Outcome

**Status**: RECOMMENDATION

Option B — make `never` cancellation-cooperative. The current implementation violates SE-0300's continuation contract, leaks resources, crashes on embedded, and is the only reactive framework implementation that doesn't respond to cancellation. The `Task.sleep` pattern is simple, correct, and matches the behavior of `AsyncStream { _ in }`.

## References

- [SE-0298: Async/Await: Sequences](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0298-asyncsequence.md)
- [SE-0300: Continuations for interfacing async tasks with synchronous code](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0300-continuation.md)
- [SE-0304: Structured Concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [SE-0314: AsyncStream and AsyncThrowingStream](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)
- [Point-Free swift-concurrency-extras: AsyncStream.never](https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/AsyncStream.swift)
- [Swift Forums: AsyncSequences and cooperative task cancellation](https://forums.swift.org/t/asyncsequences-and-cooperative-task-cancellation/62657)
- [Swift Forums: What to expect from AsyncSequence cancellation?](https://forums.swift.org/t/what-to-expect-from-asyncsequence-cancellation/62541)
