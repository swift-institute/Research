# Temporal Operator Determinism

<!--
---
version: 1.1.0
last_updated: 2026-02-25
status: IN_PROGRESS
tier: 2
trigger: Pointfree #355 analysis — NonsendingClock and deterministic temporal testing
---
-->

## Context

Pointfree Episode #355 (Feb 23, 2026) — "Beyond Basics: Isolation, ~Copyable, ~Escapable" — demonstrated that their `ImmediateClock` with `nonisolated(nonsending)` sleep achieved 100% deterministic testing (10,000 runs, 0 failures). The key insight: the standard `Clock` protocol's `sleep` is `async`, which forces a suspension point and thread hop even when the clock is immediate. By creating a `NonsendingClock` protocol with `nonisolated(nonsending) func sleep(...)`, the sleep becomes a synchronous no-op on immediate clocks, eliminating all nondeterminism from thread scheduling.

Their findings:
- TCA1 had 11 `Task.yield()` calls; Clocks library had 6 — all were eliminated in TCA2
- `NonsendingClock` is backwards-compatible with `Clock` (retroactive conformance via default implementations)
- Swift still needs `nonisolated(nonsending)` variants of `withUnsafeContinuation` and `withTaskCancellationHandler` for full test clock support

Our temporal operators at `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/` must be assessed for deterministic testability under this new paradigm.

## Experiment Validation

**Experiment**: `swift-institute/Experiments/nonsending-blocker-validation/`
**Negative experiment**: `swift-institute/Experiments/nonsending-blocker-validation-negative/`
**Toolchain**: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21), macOS 26.0 (arm64)

The research hypotheses from the initial analysis were empirically validated. Seven blockers (B1–B5) were tested. Key results:

### B5: NonsendingClock is viable TODAY

A `NonsendingClock` protocol refining `Clock` with `nonisolated(nonsending) func sleep(until:tolerance:)` compiles and works. An `ImmediateNonsendingClock` was tested — `MainActor.assertIsolated` passed after `clock.sleep`, confirming zero thread hop. The clock's `sleep` completes without creating a suspension point or scheduling a thread hop, exactly as hypothesized.

```swift
protocol NonsendingClock<Duration>: Clock {
    nonisolated(nonsending)
    func sleep(until deadline: Instant, tolerance: Duration?) async throws
}
```

This is immediately implementable — no language evolution proposals needed.

### B2: withCheckedContinuation already propagates isolation

The document's original "Gap" about continuation functions is **not a real blocker**. `withCheckedContinuation` uses `isolation: isolated (any Actor)? = #isolation` and preserves caller isolation. `MainActor.assertIsolated` passed inside both `withCheckedContinuation` and `withUnsafeContinuation` bodies when called from a `@MainActor` function.

### B3: withTaskCancellationHandler has full nonsending overload

`withTaskCancellationHandler` has a `nonisolated(nonsending)` overload. `MainActor.assertIsolated` passed inside its operation closure.

### B1d: nonisolated(nonsending) is async-only

`nonisolated(nonsending)` cannot be applied to synchronous function types. The compiler emits: "cannot use 'nonisolated(nonsending)' on non-async function type". This means `ContinuousClock.now` comparisons in throttle (which are sync) do not benefit from nonsending. Only `clock.sleep(until:)` benefits since it is async.

### Impact on Phases

- **Phase 1 (clock parameterization)**: UNBLOCKED TODAY. No language evolution needed.
- **Phase 2 (NonsendingClock protocol)**: UNBLOCKED TODAY. Compiles and works on current toolchain.
- **Phase 3 (deterministic tests for linear operators)**: UNBLOCKED TODAY. Follows directly from Phases 1–2.
- **Phase 4 (race-based operator redesign)**: Still requires structural redesign — the task group race pattern remains the barrier, not the clock.

## Question

Can our temporal stream operators achieve 100% deterministic testing, and what changes are required?

## Analysis

### Operator-by-Operator Assessment

#### 1. `debounce(_ duration: Duration)` — Async.Stream.Debounce.State

**File**: `Async.Stream.Debounce.State.swift` (lines 39–101)

**Time mechanism**:
- Uses `Task.sleep(for: self.duration)` (line 64) for the quiet-period timer
- Uses `withTaskGroup(of:)` (line 53) to race upstream `next()` against timer expiry

**Suspension points**:
1. `await self.box.next()` — upstream element fetch (line 55)
2. `try? await Task.sleep(for: self.duration)` — debounce timer (line 64)
3. `await group.next()` — waiting for first child task result (line 70)

**Task creation**: Yes. `withTaskGroup` creates 1–2 child tasks on every iteration: one for upstream, one (conditional) for the timer. Each `group.addTask` creates a new unstructured child task within the group.

**Determinism assessment**: **Not deterministic today.** The `withTaskGroup` race between upstream-next and timer creates scheduling nondeterminism. When `Task.sleep(for: .zero)` is used in tests, the timer child task and upstream child task race to complete first, with the winner determined by thread scheduling. Even with an immediate clock, the `async` nature of `Task.sleep` means a suspension + potential thread hop before returning `.timerExpired`.

**Structural barrier**: The `withTaskGroup` race pattern is the fundamental barrier. Even with a nonsending clock, the group still creates child tasks that are scheduled by the runtime.

---

#### 2. `throttle(_ duration: Duration)` — Async.Stream.Throttle.State

**File**: `Async.Stream.Throttle.State.swift` (lines 41–61)

**Time mechanism**:
- Uses `ContinuousClock.now` (line 47) for timestamp comparison
- Duration comparison: `elapsed < duration` (line 51)
- **No sleep, no task groups, no timer**

**Suspension points**:
1. `await box.next()` — upstream element fetch (line 45, inherited from upstream)

**Task creation**: No.

**Determinism assessment**: **Partially deterministic.** The operator itself introduces no scheduling nondeterminism. However, it hardcodes `ContinuousClock.now` (line 47), making it impossible to inject a test clock. In tests, `ContinuousClock.now` returns wall-clock time, so throttle behavior depends on actual execution speed. If the test runs fast enough, elapsed time is always < duration and all elements except the first are skipped.

**Structural barrier**: None from task creation. The barrier is the hardcoded `ContinuousClock` — a `Clock` parameter would fix this.

---

#### 3. `delay(_ duration: Duration)` — Async.Stream.Delay

**File**: `Async.Stream.Delay.swift` (lines 28–38)

**Time mechanism**:
- `try? await Task.sleep(for: duration)` (line 33)

**Suspension points**:
1. `await box.next()` — upstream element fetch (line 32)
2. `try? await Task.sleep(for: duration)` — delay sleep (line 33)

**Task creation**: No child tasks.

**Determinism assessment**: **Deterministic with a nonsending clock.** The operator has a linear structure: fetch upstream, sleep, return. No racing, no task groups. If `Task.sleep` were replaced with a clock-based sleep, and that clock were nonsending-immediate, the delay becomes a synchronous no-op and the operator becomes fully deterministic.

**Structural barrier**: None. This is the simplest temporal operator to fix.

---

#### 4. `timeout(_ duration: Duration)` — Async.Stream.Timeout

**File**: `Async.Stream.Timeout.swift` (lines 30–58)

**Time mechanism**:
- `try await Task.sleep(for: duration)` (line 41) in a throwing task group child
- `withThrowingTaskGroup(of:)` (line 36) to race upstream against timeout

**Suspension points**:
1. `await box.next()` — upstream element fetch (line 38)
2. `try await Task.sleep(for: duration)` — timeout timer (line 41)
3. `try await group.next()` — waiting for race winner (line 45)

**Task creation**: Yes. `withThrowingTaskGroup` creates 2 child tasks per iteration: one for upstream next, one for timeout sleep.

**Determinism assessment**: **Not deterministic today.** Identical structural issue to debounce: a task group race between upstream and timer. The timeout throws `CancellationError` when sleep completes first, but the order of completion is scheduler-dependent.

**Structural barrier**: The `withThrowingTaskGroup` race pattern. Same issue as debounce.

---

#### 5. `buffer.time(_ duration: Duration)` — Async.Stream.Buffer.Time.State

**File**: `Async.Stream.Buffer.Time.State.swift` (lines 39–102)

**Time mechanism**:
- `ContinuousClock.now + duration` for deadline computation (line 46)
- `ContinuousClock.now` for remaining-time computation (line 49)
- `try? await Task.sleep(for: remaining)` (line 71) in a task group child
- `withTaskGroup(of:)` (line 61) to race upstream against timer

**Suspension points**:
1. `await self.box.next()` — upstream element fetch (line 63)
2. `try? await Task.sleep(for: remaining)` — time window timer (line 71)
3. `await group.next()` — waiting for race winner (line 75)

**Task creation**: Yes. Task group with 2 child tasks per loop iteration.

**Determinism assessment**: **Not deterministic today.** Same task-group race pattern as debounce/timeout. Additionally hardcodes `ContinuousClock.now` for deadline arithmetic, preventing clock injection.

**Structural barrier**: Task group race + hardcoded ContinuousClock.

---

#### 6. `buffer.countOrTime(count:time:)` — Async.Stream.Buffer.CountOrTime.State

**File**: `Async.Stream.Buffer.CountOrTime.State.swift` (lines 48–124)

**Time mechanism**:
- `ContinuousClock.now + duration` for deadline (line 55)
- `ContinuousClock.now` for remaining-time computation (line 74)
- `try? await Task.sleep(for: remaining)` (line 96) in a task group child
- `withTaskGroup(of:)` (line 86) to race upstream against timer

**Suspension points**:
1. `await self.box.next()` — upstream element fetch (line 88)
2. `try? await Task.sleep(for: remaining)` — time window timer (line 96)
3. `await group.next()` — waiting for race winner (line 100)

**Task creation**: Yes. Task group with 2 child tasks.

**Determinism assessment**: **Not deterministic today.** Same structural pattern as buffer.time.

**Structural barrier**: Task group race + hardcoded ContinuousClock.

---

#### 7. `Async.Stream.interval(_ duration: Duration)` — Async.Stream.Interval.State

**File**: `Async.Stream.Interval.State.swift` (lines 39–53)

**Time mechanism**:
- `try? await Task.sleep(for: duration)` (line 45)

**Suspension points**:
1. `try? await Task.sleep(for: duration)` — interval sleep (line 45)

**Task creation**: No child tasks.

**Determinism assessment**: **Deterministic with a nonsending clock.** Linear structure: sleep, emit counter, repeat. No racing.

**Structural barrier**: None. Same category as delay.

---

#### 8. `Async.Stream.timer(after:)` — Async.Stream.Timer.State (Void)

**File**: `Async.Stream.Timer.State.swift` (lines 36–48)

**Time mechanism**:
- `try? await Task.sleep(for: delay)` (line 42)

**Suspension points**:
1. `try? await Task.sleep(for: delay)` — one-shot timer sleep (line 42)

**Task creation**: No child tasks.

**Determinism assessment**: **Deterministic with a nonsending clock.** Single sleep then emit. Simplest possible temporal operator.

**Structural barrier**: None.

---

#### 9. `Async.Stream.timer(after:value:)` — Async.Stream.Timer.Value.State

**File**: `Async.Stream.Timer.Value.State.swift` (lines 40–52)

**Time mechanism**:
- `try? await Task.sleep(for: delay)` (line 46)

**Suspension points**:
1. `try? await Task.sleep(for: delay)` — one-shot timer sleep (line 46)

**Task creation**: No child tasks.

**Determinism assessment**: **Deterministic with a nonsending clock.** Identical structure to Void timer.

**Structural barrier**: None.

---

#### 10. `Async.Stream.repeating(_:every:count:)` — Async.Stream.Repeat.Interval.State

**File**: `Async.Stream.Repeat.Interval.State.swift` (lines 44–61)

**Time mechanism**:
- `try? await Task.sleep(for: interval)` (line 54)

**Suspension points**:
1. `try? await Task.sleep(for: interval)` — inter-emission sleep (line 54)

**Task creation**: No child tasks.

**Determinism assessment**: **Deterministic with a nonsending clock.** Linear sleep-emit loop.

**Structural barrier**: None.

---

#### 11. `Async.Stream.repeating(_:count:)` — Async.Stream.Repeat.State

**File**: `Async.Stream.Repeat.State.swift` (lines 37–47)

**Time mechanism**: **None.** This operator has no temporal behavior.

**Suspension points**: Only `Task.isCancelled` check (synchronous).

**Task creation**: No.

**Determinism assessment**: **Already deterministic.** No temporal dependency.

**Structural barrier**: None.

---

#### 12. `sample.on(_:)` — Async.Stream.Sample.State

**File**: `Async.Stream.Sample.State.swift` (lines 45–90)

**Time mechanism**: No direct time mechanism, but indirectly temporal when the trigger stream is time-based.

**Suspension points**:
1. `await triggerBox.next()` — waiting for trigger (line 74)
2. `await self.updateLatest(element)` — actor-isolated mutation (line 53)

**Task creation**: **Yes.** Creates an unstructured `Task` (line 50) to continuously drain the source stream: `sourceTask = Task { for await element in source { ... } }`. This is a long-lived background task.

**Determinism assessment**: **Not deterministic today.** The unstructured `Task` for source draining introduces a data race between the source task updating `latest` and the trigger-driven `next()` reading it. The actor serializes access, but the interleaving of source-task updates and trigger-driven reads is scheduler-dependent.

**Structural barrier**: Unstructured `Task` creation. This is the most structurally problematic operator because the background task must run concurrently to continuously update the latest value.

---

### Summary Table

| Operator | Time Mechanism | Task Creation | Deterministic Today? | Fixable with NonsendingClock? |
|---|---|---|---|---|
| `debounce` | Task.sleep + TaskGroup race | Yes (2 children/iter) | No | Partially — race remains |
| `throttle` | ContinuousClock.now comparison | No | No (hardcoded clock) | Yes — with clock parameter |
| `delay` | Task.sleep | No | No | Yes — linear structure |
| `timeout` | Task.sleep + ThrowingTaskGroup race | Yes (2 children/iter) | No | Partially — race remains |
| `buffer.time` | Task.sleep + TaskGroup race + ContinuousClock.now | Yes (2 children/iter) | No | Partially — race remains |
| `buffer.countOrTime` | Task.sleep + TaskGroup race + ContinuousClock.now | Yes (2 children/iter) | No | Partially — race remains |
| `interval` | Task.sleep | No | No | Yes — linear structure |
| `timer(Void)` | Task.sleep | No | No | Yes — linear structure |
| `timer(Value)` | Task.sleep | No | No | Yes — linear structure |
| `repeating(every:)` | Task.sleep | No | No | Yes — linear structure |
| `repeating` | None | No | **Yes** | N/A |
| `sample.on` | Indirect (trigger-driven) | Yes (unstructured Task) | No | No — structural barrier |

---

### NonsendingClock Integration Path

#### Phase 1: Clock Parameterization (Prerequisite)

All temporal operators currently use either `Task.sleep(for:)` or hardcoded `ContinuousClock.now`. Neither supports clock injection. The first step is to parameterize every temporal operator with a `Clock` type parameter.

Current signature:
```swift
public func delay(_ duration: Duration) -> Self
```

Required signature:
```swift
public func delay<C: Clock>(_ duration: C.Duration, clock: C) -> Self where C.Duration == Duration
```

This affects **10 operators** (all except `repeating` without interval and `sample`).

For `throttle` specifically, `ContinuousClock.now` on line 47 must be replaced with `clock.now`, and the state actor must store the clock instance.

#### Phase 2: NonsendingClock Protocol

Following the Pointfree pattern, define a `NonsendingClock` protocol:

```swift
public protocol NonsendingClock<Duration>: Clock {
    nonisolated(nonsending) func sleep(
        until deadline: Instant,
        tolerance: Duration?
    ) async throws
}
```

With a retroactive conformance of `Clock` through a default implementation, existing clocks continue to work. An `ImmediateClock` conforming to `NonsendingClock` would make its `sleep` a synchronous no-op — no suspension point, no thread hop.

#### Phase 3: Operators That Become Fully Deterministic

With a NonsendingClock + ImmediateClock, these **5 operators** achieve 100% determinism:

1. **delay** — Sleep becomes no-op, element passes through immediately
2. **throttle** — `clock.now` always returns the same instant (or advances deterministically), elapsed-time comparison is predictable
3. **interval** — Sleep becomes no-op, counter increments synchronously
4. **timer (Void and Value)** — Sleep becomes no-op, fires immediately
5. **repeating(every:)** — Sleep becomes no-op, emits all values synchronously

These operators share a common trait: **linear control flow with no task creation**. The only suspension point is the sleep itself, and with a nonsending clock, that suspension is eliminated.

#### Phase 4: Operators That Require Structural Redesign

These **5 operators** cannot be fixed by clock injection alone:

1. **debounce** — The `withTaskGroup` race pattern creates child tasks. Even if `Task.sleep` is replaced with `clock.sleep`, the task group still schedules children on the cooperative thread pool. The race outcome depends on scheduler ordering.

2. **timeout** — Same task group race issue as debounce.

3. **buffer.time** — Same task group race issue, compounded by hardcoded `ContinuousClock.now` for deadline arithmetic.

4. **buffer.countOrTime** — Same as buffer.time.

5. **sample.on** — Unstructured `Task` for background source draining. The actor provides serialization but not deterministic interleaving.

#### Structural Fix for Race-Based Operators

The Pointfree approach eliminates races by making time operations synchronous. For our race-based operators, the equivalent would be to **replace the task-group race with a single-threaded polling loop** when using an immediate clock:

```swift
// Current: nondeterministic race
let result = await withTaskGroup(of: Event.self) { group in
    group.addTask { await upstream() }      // child task 1
    group.addTask { try? await clock.sleep(for: d) }  // child task 2
    return await group.next()!
}

// Ideal: single-task polling with nonsending clock
// When clock.sleep is nonsending, the timer "fires" immediately
// and no race exists — the timer always wins (or upstream always wins)
```

However, this requires rethinking the operator semantics. A debounce with an immediate clock should:
- Receive element → start quiet period
- Quiet period is zero → immediately emit
- This means debounce(0) == passthrough (which is correct!)

The structural redesign would replace `withTaskGroup` races with a continuation-based approach:

```swift
// Proposed: continuation-based debounce with clock
actor State<C: Clock> where C.Duration == Duration {
    let clock: C
    var timerTask: Task<Void, Never>?
    var continuation: CheckedContinuation<Event, Never>?

    func next() async -> Element? {
        // ... use withCheckedContinuation to await either
        // upstream completion or timer expiry, with the timer
        // scheduled via clock.sleep
    }
}
```

But this still creates a child `Task` for the timer, reintroducing the race. The only truly deterministic approach is the Pointfree one: make `clock.sleep` itself nonsending so it completes synchronously without ever creating a separate execution context.

For race-based operators with a nonsending immediate clock:
- `clock.sleep(for: .zero)` returns immediately (no suspension)
- The "race" collapses: upstream element fetch is the only actual suspension
- Timer always fires before upstream can respond → debounce always emits immediately

This requires **restructuring the race so that the timer check happens synchronously before suspending on upstream**:

```swift
func next() async -> Element? {
    // Check timer first (synchronous with nonsending clock)
    if pending != nil {
        try? await clock.sleep(for: duration)  // no-op with immediate clock
        if !Task.isCancelled {
            let element = pending
            pending = nil
            return element
        }
    }
    // Then fetch upstream (actual suspension)
    guard let element = await box.next() else { ... }
    pending = element
    ...
}
```

This rewrite changes the semantics: instead of racing, it **serializes** timer and upstream. This is semantically correct for an immediate clock (where time passes instantly) but changes the real-time behavior (timer always takes priority over new upstream elements).

---

### Timer.Wheel as Foundation

**Location**: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Timer.Wheel*.swift`

#### Current State

The `Async.Timer.Wheel<C: Clock>` is a hierarchical timer wheel data structure with:
- O(1) amortized schedule, cancel, and per-tick advance
- Multi-level hierarchy (default: 6 levels, 64 slots each) for range up to ~2.18 years at 1ms precision
- Slab-based storage with generation-counted IDs for ABA prevention
- Generic over `Clock` (the `C` parameter)
- `~Copyable` and `Sendable`

**However**, the public `schedule()`, `advance(to:)`, and `cancel()` methods are **not yet implemented**. The wheel currently has:
- Internal data structure: `Storage`, `Slot`, `Node`, `Level` (fully implemented)
- Internal operations: `slotAppend`, `slotRemove`, `slotPopFirst`, `allocate`, `deallocate` (fully implemented)
- Tick conversion: `tickNumber(for:)`, `currentSlot(level:)`, `level(for:)`, `slot(for:delta:)` (fully implemented)
- Configuration: `Config`, `Config.default` (fully implemented)
- Entry/ID types (fully implemented)

Missing: the public API that ties these internals together — `schedule(deadline:) -> ID?`, `advance(to: C.Instant, yield: (Entry) -> Void)`, `cancel(_ id: ID) -> Bool`.

#### Assessment for Deterministic Testing

The timer wheel is **Clock-generic** (`Wheel<C: Clock>`), which is the critical prerequisite for testability. If paired with an immediate or manual clock, the wheel's `advance(to:)` method would fire timers synchronously and deterministically, without any actual time passing.

The wheel is designed as a **callback-free, actor-owned building block** (as stated in `Async.Timer.swift` line 19: "These primitives are callback-free, actor-owned building blocks. Higher-level async sleep and timeout APIs are composed at the IO layer."). This design is ideal for deterministic testing because:

1. **The caller controls time**: `advance(to:)` is called with an explicit instant, not wall-clock time
2. **No internal async**: The wheel is a pure mutable struct — no suspension points, no tasks
3. **Deterministic ordering**: Timers fire in deadline order within a tick, which is a deterministic total order

The wheel could serve as the foundation for a deterministic temporal testing strategy:

```swift
// Hypothetical test using a manual clock and timer wheel
let clock = ManualClock()
var wheel = Async.Timer.Wheel(clock: clock)

let id = wheel.schedule(deadline: clock.now + .seconds(1))
// Advance time manually
clock.advance(by: .seconds(1))
wheel.advance(to: clock.now) { entry in
    // Timer fired — deterministic!
}
```

**Gap**: The wheel operates at the primitive level. Our stream operators at the foundations level use `Task.sleep(for:)` and task groups — they do not use the timer wheel at all. Bridging the wheel into the stream operators requires:

1. Completing the wheel's public API (`schedule`, `advance`, `cancel`)
2. Building an actor-based timer service that drives the wheel from a real or test clock
3. Replacing `Task.sleep(for:)` in stream operators with timer-wheel-based sleep
4. Or: keeping `Task.sleep` but parameterizing it via `Clock.sleep`, and using the wheel only for the IO layer's multiplexed timer management

The wheel is the right foundation for server-side timer management (e.g., connection timeouts in an event loop) but is **heavier than needed** for stream operator determinism. For stream operators, a simple clock parameter + nonsending clock protocol is sufficient.

---

### Gap Analysis

#### Gap 1: No Clock Parameterization — ACTIONABLE (no language blockers)

**Our state**: All temporal operators use `Task.sleep(for:)` or hardcoded `ContinuousClock.now`. Zero operators accept a clock parameter.

**Pointfree state**: All temporal operations are parameterized over `Clock` (or `NonsendingClock`), with a default of `ContinuousClock`.

**Impact**: We cannot inject any test clock today. All temporal tests must use real time (wall-clock sleeps).

**Update (2026-02-25)**: Experiment validation confirmed no language blockers exist. Clock parameterization is a pure API-design task — add a `Clock` type parameter to each operator's state actor, replace `Task.sleep(for:)` with `clock.sleep(until:)`, replace `ContinuousClock.now` with `clock.now`. Default to `ContinuousClock` for source compatibility. Implementable immediately.

---

#### Gap 2: No NonsendingClock Protocol — RESOLVED (implementable today)

**Our state**: No `NonsendingClock` concept exists in our codebase.

**Pointfree state**: `NonsendingClock` protocol defined with `nonisolated(nonsending) func sleep(...)`. `ImmediateClock` conforms. TCA2 uses this pervasively.

**Impact**: Even if we add clock parameters, `Clock.sleep` is still `async`, still causes suspension + potential thread hop.

**Update (2026-02-25)**: Experiment validation at `swift-institute/Experiments/nonsending-blocker-validation/` confirmed that a `NonsendingClock` protocol refining `Clock` with `nonisolated(nonsending) func sleep(until:tolerance:)` compiles and works on the current toolchain (Swift 6.2.3). An `ImmediateNonsendingClock` was tested — `MainActor.assertIsolated` passed after `clock.sleep`, confirming zero thread hop. The continuation functions (`withCheckedContinuation`, `withUnsafeContinuation`) already propagate caller isolation via `#isolation`, and `withTaskCancellationHandler` has a full `nonisolated(nonsending)` overload. This gap is no longer a blocker — the protocol can be defined and used immediately.

---

#### Gap 3: Race-Based Operator Architecture

**Our state**: 5 of 12 operators use `withTaskGroup`/`withThrowingTaskGroup` races to implement "sleep OR upstream" semantics.

**Pointfree state**: Pointfree eliminated all task-group races in TCA2 by making time synchronous. Their `Effect` system uses a fundamentally different architecture (reducers driven by a store, not stream-of-streams composition).

**Impact**: Even with NonsendingClock, our race-based operators need structural changes. The task group pattern is inherently nondeterministic because child tasks are scheduled on the cooperative pool.

---

#### Gap 4: Unstructured Task in Sample

**Our state**: `sample.on` creates an unstructured `Task` to drain the source stream.

**Pointfree state**: N/A (different architectural pattern).

**Impact**: This operator has a structural concurrency barrier that NonsendingClock cannot solve. The background task runs independently and its interleaving with trigger-driven reads is scheduler-dependent.

---

#### Gap 5: No Test Infrastructure

**Our state**: The test file (`Async.Stream Tests.swift`) contains 15 tests, all for non-temporal operators (from, just, empty, map, filter, compactMap, scan, reduce, concat, zip, flatMap, unfold, prefix, drop, first, last, distinctUntilChanged). Zero temporal operator tests exist.

**Pointfree state**: 10,000-run deterministic test suites with 0 failures.

**Impact**: We have no empirical data on our temporal operators' correctness or determinism.

---

#### Gap 6: Timer Wheel Incomplete

**Our state**: `Async.Timer.Wheel` has full internal data structures but no public `schedule`/`advance`/`cancel` API.

**Pointfree state**: N/A (they don't use a timer wheel; their approach is clock-protocol-based).

**Impact**: The wheel cannot be used for anything yet. This is a Layer 1 primitive gap, not directly blocking stream operator testing, but blocking the IO layer's timer multiplexing.

---

### Priority-Ordered Recommendations

**Phases 1–3 are immediately actionable** — experiment validation (2026-02-25) confirmed no language evolution or toolchain changes are required.

1. **Clock parameterization** (Phase 1) — **UNBLOCKED**: Add a `Clock` type parameter to all 10 temporal operators. Default to `ContinuousClock`. This is pure additive API — no behavioral change. **Estimated effort**: Medium. Each operator's state actor must store the clock, and sleep calls must change from `Task.sleep(for:)` to `clock.sleep(until:)`. Note: `nonisolated(nonsending)` is async-only, so `ContinuousClock.now` comparisons in throttle (sync) do not benefit from nonsending — but `clock.sleep(until:)` does.

2. **NonsendingClock protocol** (Phase 2) — **UNBLOCKED**: Define `NonsendingClock` in `swift-async-primitives` (Layer 1). Provide `ImmediateNonsendingClock` implementation. Empirically validated: the protocol compiles, `MainActor.assertIsolated` passes after immediate sleep, zero thread hop confirmed. **Estimated effort**: Small. The protocol is ~10 lines; `ImmediateNonsendingClock` is ~20 lines.

3. **Temporal operator tests** (Phase 3) — **UNBLOCKED**: Write deterministic tests for all temporal operators using `ImmediateNonsendingClock`. Start with the 5 linear operators (delay, throttle, interval, timer, repeating). Run with 10,000 iterations to verify 0 failures. **Estimated effort**: Medium.

4. **Structural redesign of race operators** (Phase 4): Redesign debounce, timeout, buffer.time, buffer.countOrTime to avoid task-group races. This requires careful semantic analysis — the serialized approach changes real-time behavior. The task group race pattern remains the barrier, not the clock. **Estimated effort**: Large. This is the hardest step.

5. **Complete Timer.Wheel public API** (Phase 5): Implement `schedule`, `advance`, `cancel`. This enables the IO layer's timer service but is not on the critical path for stream operator determinism. **Estimated effort**: Medium.

6. **Redesign sample.on** (Phase 6): Replace unstructured `Task` with a structured approach. Possible designs: demand-driven (only fetch source when trigger arrives), or continuation-based (single task alternating between source and trigger). **Estimated effort**: Medium-Large (semantic change).

## Outcome

**Status**: IN_PROGRESS

Our temporal operators currently have **zero deterministic testability**. Of 12 operators (11 temporal + 1 non-temporal `repeating`), only `repeating` without interval is deterministic today. The remaining 10 temporal operators all depend on `Task.sleep(for:)` or hardcoded `ContinuousClock.now` with no clock injection point.

The operators divide into two categories:

- **5 linear operators** (delay, throttle, interval, timer, repeating-with-interval): These can achieve 100% determinism with clock parameterization + NonsendingClock. No structural changes needed — just replace `Task.sleep(for:)` with `clock.sleep(until:)` and `ContinuousClock.now` with `clock.now`.

- **6 race-based operators** (debounce, timeout, buffer.time, buffer.countOrTime, sample.on, plus indirectly combineLatest/merge/withLatestFrom when composed with temporal triggers): These have structural barriers from task-group races and unstructured tasks. NonsendingClock helps but does not fully solve the problem. Structural redesign is required.

The `Async.Timer.Wheel` primitive is the right foundation for server-side timer multiplexing but is orthogonal to stream operator determinism. Its public API should be completed independently.

**Update (2026-02-25)**: Experiment validation confirmed that **Phases 1–3 are immediately actionable** with the current toolchain (Swift 6.2.3). The `NonsendingClock` protocol compiles, `ImmediateNonsendingClock` preserves caller isolation (zero thread hop), continuation functions already propagate isolation, and `withTaskCancellationHandler` has a full `nonisolated(nonsending)` overload. The only remaining language limitation is that `nonisolated(nonsending)` is async-only, meaning sync timestamp comparisons (e.g., `ContinuousClock.now` in throttle) do not benefit — but `clock.sleep(until:)` does. The race-based operators (debounce, timeout, buffer.time, buffer.countOrTime) still require structural redesign — the task group race pattern is the barrier, not the clock.

## References

- Pointfree #355: Beyond Basics: Isolation, ~Copyable, ~Escapable (Feb 23, 2026)
- Swift Evolution SE-0430: `nonisolated(nonsending)` (accepted)
- TCA2 migration: elimination of `Task.yield()` calls via NonsendingClock
- Async.Stream temporal sources: `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/`
- Async.Timer.Wheel primitive: `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/Async.Timer.Wheel*.swift`
- Existing stream tests: `/Users/coen/Developer/swift-foundations/swift-async/Tests/Sources/Async Stream Tests/Async.Stream Tests.swift`
- Experiment validation (2026-02-25): `swift-institute/Experiments/nonsending-blocker-validation/`
- Negative experiment (2026-02-25): `swift-institute/Experiments/nonsending-blocker-validation-negative/`
