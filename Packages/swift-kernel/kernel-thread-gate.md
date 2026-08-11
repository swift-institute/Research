# Kernel.Thread.Gate

<!--
---
version: 1.0.0
last_updated: 2026-03-20
status: DECISION (SUPERSEDED 2026-04-14 — type relocated, design findings still valid)
---
-->

> **Supersession note (2026-04-14)**: `Kernel.Thread.Gate` was extracted
> from swift-kernel to the `Thread Gate` target in swift-threads as part
> of the strict-mission refactor (swift-kernel = syscall-adjacent wrappers
> only; thread-layer compositions live in swift-threads). The design
> decisions documented below remain authoritative for the type's
> semantics and API. Only the package location changed.
>
> Consumers now import via `import Thread_Gate` or the `Threads` umbrella.

## Context

`Kernel.Thread` provides synchronization primitives for OS-thread coordination:

| Primitive | Semantics | API |
|-----------|-----------|-----|
| `Barrier` | N-thread rendezvous — all must arrive before any proceed | `arrive(timeout:) -> Bool` |
| `Synchronization<N>` | Mutex + N condition variables | `lock/unlock/wait/signal/broadcast` |

The missing primitive was a **gate**: N threads block on `wait()`, a single `open()` releases all current and future waiters. Once opened, the gate stays open permanently — subsequent `wait()` calls return immediately.

**Trigger**: IO benchmark fixtures needed to block dedicated worker threads (via `lane.run { gate.wait() }`) to saturate a thread pool for rejection latency measurement. The previous workaround was a `BlockerLatch` using `Thread.sleep(forTimeInterval: 0.0001)` spin-sleep — wasteful and Foundation-dependent. A gate backed by condvar is the principled solution.

**Production scope**: Not test-only. Production uses include server startup coordination, initialization gates, graceful shutdown signals, and any "wait for ready" pattern on OS threads.

**Discovery**: `Kernel.Thread.Gate` **already exists** and is in production use. This research retroactively documents the design decisions, verifies correctness, and identifies one remaining issue (test support duplication).

## Question

What should the design, semantics, and implementation of `Kernel.Thread.Gate` be?

Seven sub-questions:
1. One-shot vs resettable?
2. Timeout on `wait()`?
3. Naming (`open/wait` vs `signal/wait` vs `release/await`)?
4. State query (`isOpen`)?
5. Backing implementation?
6. File placement?
7. `~Copyable`?

## Analysis

### Existing Implementation

`Kernel.Thread.Gate` at `Sources/Kernel/Kernel.Thread.Gate.swift`:

```swift
public final class Gate: @unchecked Sendable {
    private var _isOpen: Bool = false
    private let sync = SingleSync()

    public init() {}

    public func open() { ... }          // idempotent broadcast
    public func wait() { ... }          // indefinite block
    public func wait(timeout: Duration) -> Bool { ... }
    public var isOpen: Bool { ... }     // non-blocking query
}
```

**Consumers** (verified 2026-03-20):
- `swift-io/Tests/IO Blocking Threads Tests/IO.Blocking.Threads Tests.swift:132` — 1 call site
- `swift-pools/Tests/Pool Tests/Pool.Blocking Tests.swift` — 23 call sites across 7 test functions

### Prior Art

| Language | Primitive | One-shot? | Timeout? | Blocking model |
|----------|-----------|-----------|----------|----------------|
| Java | `CountDownLatch(1)` | Yes | `await(timeout, unit)` | Thread-blocking |
| Go | `chan struct{}` + `close()` | Yes (close is permanent) | `select` with `time.After` | Goroutine-blocking |
| Rust | Manual `Condvar` + `Mutex<bool>` | Configurable | `wait_timeout()` | Thread-blocking |
| pthreads | `pthread_cond_broadcast` + flag | Configurable | `pthread_cond_timedwait` | Thread-blocking |
| C# | `ManualResetEvent` | Resettable (`Reset()`) | `WaitOne(timeout)` | Thread-blocking |
| Python | `threading.Event` | Resettable (`clear()`) | `wait(timeout)` | Thread-blocking |

Key observations:
- **One-shot is the common default** for gate/latch semantics. Java's `CountDownLatch` and Go's channel-close are permanently triggered. Resettable variants (C# `ManualResetEvent`, Python `Event`) are separate types with explicit `Reset()`/`clear()`.
- **Timeout is universally supported** alongside an indefinite variant.
- **All are thread-blocking** (not async). This matches `Kernel.Thread`'s domain.

### Sub-Question Analysis

#### Q1: One-shot vs resettable

| Option | Pros | Cons |
|--------|------|------|
| **One-shot** (no `close()`) | Simpler, no TOCTOU race between close and wait, matches Java/Go | Cannot reuse for repeated cycles |
| **Resettable** (add `close()`) | More flexible | Race-prone (close while threads are waking), needs careful documentation, different primitive (more like ManualResetEvent) |

**Existing choice**: One-shot. Correct — a resettable gate is a fundamentally different primitive with different safety properties. If needed, it should be a separate type (`Kernel.Thread.Event` or similar).

#### Q2: Timeout on `wait()`

| Option | Pros | Cons |
|--------|------|------|
| `wait()` only | Simpler | Deadlock risk in tests, no escape hatch |
| `wait()` + `wait(timeout:) -> Bool` | Safe, matches `Barrier.arrive(timeout:)` | Two overloads |
| `wait(timeout:) -> Bool` only (with `.max` default) | Single entry point | Forced timeout semantics on every call |

**Existing choice**: Both `wait()` and `wait(timeout: Duration) -> Bool`. Correct — matches `Barrier`'s pattern where `arrive(timeout:)` defaults to 5 seconds. The indefinite `wait()` is appropriate for production use (e.g., startup gates that *must* open).

**Barrier comparison**: `Barrier.arrive(timeout: .seconds(5))` has a default timeout. `Gate.wait()` has no default timeout — this is correct because gates are semantically different. A barrier that never completes indicates a bug; a gate that hasn't opened yet is normal operation (waiting for initialization).

#### Q3: Naming

| Option | Precedent | Assessment |
|--------|-----------|------------|
| `open()` / `wait()` | Physical gate metaphor | Clear, intuitive, matches the type name |
| `signal()` / `wait()` | POSIX condvar, `Signal` test type | Ambiguous — `signal()` in condvar means "wake one" |
| `release()` / `await()` | Latch terminology | `await` conflicts with Swift concurrency keyword |
| `trigger()` / `wait()` | Event terminology | Less clear than `open` for a "gate" |

**Existing choice**: `open()` / `wait()`. Correct — the strongest option. `open` is semantically precise (a gate opens; once open it stays open), avoids the `signal` ambiguity with condvar terminology, and avoids the `await` keyword collision.

#### Q4: State query (`isOpen`)

| Option | Pros | Cons |
|--------|------|------|
| No query | Simpler, no TOCTOU temptation | No way to check without blocking |
| `isOpen: Bool` | Useful for polling, diagnostics, assertions | TOCTOU if misused as gate-skip |

**Existing choice**: `isOpen: Bool` with mutex protection. Acceptable — the property is useful for assertions in tests (`#expect(gate.isOpen)`) and diagnostic logging. TOCTOU risk is inherent in any concurrent state query and is documented by the "non-blocking check" comment.

#### Q5: Backing implementation

| Option | State | Wake mechanism | Overhead |
|--------|-------|----------------|----------|
| `Atomic<Bool>` + `Synchronization<1>` condvar | Atomic flag + condvar | `broadcast(condition: 0)` | One mutex + one condvar |
| `SingleSync` only (Bool under mutex) | Bool under mutex | `broadcast(condition: 0)` | One mutex + one condvar |
| `Atomic<Bool>` + futex/ulock | Atomic flag | OS futex wake | No mutex, but platform-specific |

**Existing choice**: `Bool` + `SingleSync()` (which is `Synchronization<1>`). Correct — minimal and consistent with `Barrier`'s identical backing. A futex-based implementation would avoid the mutex for the fast path (gate already open → atomic load → return) but would introduce platform-specific code into L3. Not worth the complexity.

**Correctness note**: The `wait(timeout:)` implementation correctly handles spurious wakeups by re-checking `_isOpen` in a loop. After timeout, it returns `_isOpen` (not `false`), which is correct — the gate may have opened between the timeout and the return.

#### Q6: File placement

`Kernel.Thread.Gate.swift` in `Sources/Kernel/`. Correct per [API-IMPL-005] — one type per file, filename mirrors the fully qualified name.

#### Q7: `~Copyable`

| Option | Assessment |
|--------|------------|
| `final class` (reference type, Copyable) | Sharing via reference is the natural model for synchronization primitives |
| `~Copyable struct` | Would require explicit borrowing, makes shared access harder |

**Existing choice**: `final class: @unchecked Sendable`. Correct — matches `Barrier`, `Synchronization<N>`, and all other `Kernel.Thread` synchronization primitives. Reference semantics are essential: multiple threads must refer to the same gate instance. `@unchecked Sendable` is correct because internal state is protected by the mutex inside `SingleSync`.

### Consistency Audit

| Property | Gate | Barrier | Synchronization |
|----------|------|---------|-----------------|
| Type kind | `final class` | `final class` | `final class` |
| Sendable | `@unchecked Sendable` | `@unchecked Sendable` | `@unchecked Sendable` |
| Backing | `SingleSync()` | `SingleSync()` | Mutex + InlineArray |
| Timeout type | `Duration` | `Duration` | `Duration` / `UInt64` |
| Timeout return | `Bool` | `Bool` | `Bool` |
| Namespace | `Kernel.Thread.Gate` | `Kernel.Thread.Barrier` | `Kernel.Thread.Synchronization<N>` |

Gate is fully consistent with the existing primitive family.

### Issue: Test Support Duplication

`Tests/Support/Kernel.Thread.Test.Primitives.swift` contains a **separate `Gate` class** (lines 61-88) that duplicates the production type:

| Property | Production `Kernel.Thread.Gate` | Test support `Gate` |
|----------|---------------------------------|---------------------|
| Backing | `SingleSync()` | Raw `Mutex` + `Condition` |
| `init(open:)` | No — always starts closed | Yes — configurable initial state |
| `wait(timeout:)` | Yes | No |
| `isOpen` query | Yes | No |
| Idempotent `open()` | Yes (early return) | No (always broadcasts) |

The test support `Gate` also contains a `Signal` class (lines 104-131) that is **semantically identical** to `Gate`: both are one-shot, both use broadcast, both have `wait()` that blocks until triggered. The only difference is method naming (`signal()` vs `open()`).

**Recommendation**: Replace test support `Gate` with the production `Kernel.Thread.Gate`. The `init(open:)` parameter could be added to the production type if needed — but no current consumer uses it. The test support `Signal` should also be replaced, since `Kernel.Thread.Gate` provides the same semantics.

### BlockerLatch Status

The `BlockerLatch` workaround (spin-sleep with `Thread.sleep(forTimeInterval: 0.0001)`) has been **fully eliminated**. It appears only in historical research documents:
- `swift-io/Benchmarks/io-bench/Research/io-bench-pattern-audit.md` (findings F-04, F-10)
- `swift-tests/Research/.ecosystem-metrics-survey.md` (inventory entry)

The `SaturatedLaneFixture` in Backpressure Benchmarks now uses `Kernel.Thread.Barrier` for worker coordination. Gate is available for future benchmark fixtures that need the "open permanently" semantic rather than the "all arrive then proceed" semantic.

## Outcome

**Status**: DECISION

`Kernel.Thread.Gate` is implemented, correct, and in production use. All seven design questions resolve in favor of the existing implementation:

| Question | Decision | Rationale |
|----------|----------|-----------|
| One-shot vs resettable | **One-shot** | Simpler, safer, matches Java `CountDownLatch(1)` / Go channel-close |
| Timeout | **Both `wait()` and `wait(timeout:) -> Bool`** | Matches `Barrier` pattern; indefinite wait is correct for production gates |
| Naming | **`open()` / `wait()`** | Precise metaphor, avoids `signal`/`await` ambiguity |
| State query | **`isOpen: Bool`** | Useful for assertions/diagnostics; TOCTOU risk is documented |
| Backing | **`Bool` + `SingleSync()`** | Minimal, consistent with `Barrier` |
| File placement | **`Kernel.Thread.Gate.swift`** | [API-IMPL-005] compliant |
| `~Copyable` | **`final class`** | Reference semantics essential for shared synchronization |

### Open Action Items

1. **Remove test support `Gate` duplication** — Replace `Tests/Support/Kernel.Thread.Test.Primitives.swift` `Gate` class with direct use of `Kernel.Thread.Gate`. Evaluate whether `init(open:)` should be added to the production type.
2. **Evaluate test support `Signal` redundancy** — `Signal` is semantically identical to `Gate`. Consider whether it adds clarity (different name = different intent) or should be consolidated.
3. **Remaining `Thread.sleep` call sites** — `swift-io/Tests/IO Blocking Threads Tests/` still uses `Thread.sleep(forTimeInterval:)` in 7 locations. These are candidates for Gate-based synchronization where the sleep is used as a "wait for condition" pattern.

## References

- Java `CountDownLatch`: `java.util.concurrent.CountDownLatch` — one-shot gate with `countDown()`/`await()`
- Go channel-close pattern: `close(ch)` permanently unblocks all `<-ch` receivers
- Rust `Condvar` + `Mutex<bool>`: manual gate pattern per `std::sync` documentation
- pthreads: `pthread_cond_broadcast` + shared flag is the classic C implementation
- io-bench pattern audit: `swift-io/Benchmarks/io-bench/Research/io-bench-pattern-audit.md` (F-10: BlockerLatch)
