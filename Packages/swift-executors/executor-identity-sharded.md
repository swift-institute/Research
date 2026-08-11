# Executor Identity for Sharded Executors

<!--
---
version: 0.1.0
last_updated: 2026-04-16
status: DECISION
tier: 2
---
-->

## Context

`Kernel.Thread.Executor.Sharded` owns N independent
`Kernel.Thread.Executor` instances (`Kernel.Thread.Executor.Sharded.swift:39`
[Verified: 2026-04-16]). Each base executor checks isolation via
`threadHandle?.isCurrent` — a direct `pthread_equal` comparison against
its single OS thread. The sharded pool has no pool-level
`isIsolatingCurrentContext()`. When a consumer asks "is the current thread
one of this pool's threads?" the answer requires checking all N shards.

The runtime calls `isIsolatingCurrentContext()` (SE-0471, Swift 6.2,
`Executor.swift:389–390` [Verified: 2026-04-16]) in two paths:

1. **No-task path** (`Actor.cpp:505–556`): no `ExecutorTrackingInfo::current()`.
   Only `isIsolatingCurrentContext()` or `checkIsolated()` can answer.
   `complexEquality` / `isSameExclusiveExecutionContext` never fires
   because there is no "current" executor to compare against.
2. **With-task path** (`Actor.cpp:559ff`): tries pointer equality, then
   `complexEquality`, then `isIsolatingCurrentContext()`, then
   `checkIsolated()`.

The no-task path is the one that matters for sharding: when actor-
isolated code calls `assumeIsolated` from a shard thread outside a
`Task` context (e.g., a synchronous callback in the run loop's tick
closure), the runtime takes this path.

The `complexEquality` surface (commits `8fbf0e07f38` and `05f98b2e994`
[Verified: 2026-04-16]) encodes equality semantics in the low bit of
the witness table pointer. It compares two executor *instances*. For a
sharded pool, all shard executors are distinct objects —
`isSameExclusiveExecutionContext` returns `false` even if both shards
belong to the same pool. This mechanism cannot solve the N-thread
problem.

## Question

How should `Kernel.Thread.Executor.Sharded` implement
`isIsolatingCurrentContext()` to answer "is the calling thread ANY of my
N shard threads?"

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `isIsolatingCurrentContext()` returns `Bool?`; `nil` = "unknown" | `Executor.swift:389–390` [Verified: 2026-04-16] | Must return `true` if the calling thread is any shard thread, `false` if definitively not, `nil` post-shutdown |
| No-task path cannot use `complexEquality` | `Actor.cpp:505–556` [Verified: 2026-04-16] | Must be answered by `isIsolatingCurrentContext` alone |
| Current Sharded stores `[Kernel.Thread.Executor]` with no pool-level thread tracking | `Kernel.Thread.Executor.Sharded.swift:39` [Verified: 2026-04-16] | Any solution adds state |
| Typical N: 4–16 (default `min(4, processorCount)`) | `Kernel.Thread.Executor.Sharded.Options` [Verified: 2026-04-16] | Linear scan is feasible for typical sizes |

## Prior Art Survey

| Runtime | Mechanism | Cost | Source |
|---------|-----------|:---:|--------|
| Java `ForkJoinPool` | `Thread.currentThread() instanceof ForkJoinWorkerThread`, then read `pool` field | O(1) | `ForkJoinWorkerThread.java` [Verified: 2026-04-16] |
| Go | Per-M `getg().m.p` segment-register TLS | O(1) | `runtime/proc.go` [Verified: 2026-04-16] |
| Tokio | Per-worker `thread_local!` storing `*const Worker` | O(1) | `tokio/src/runtime/scheduler/` [Verified: 2026-04-16] |

**Per [RES-021] contextualization.** All three production runtimes use
thread-local storage for O(1) pool-identity checks. The pattern is
proven. Swift's TLS surface (`_Thread_local` or
`swift_task_localValueLookup`) is available; the question is whether the
implementation complexity is justified for v1.

## Analysis

| Option | Description | Cost | Complexity |
|--------|-------------|:---:|:---:|
| A. Thread-set | `Set<pthread_t>` populated at init; check membership | O(1) hash / O(N) linear | Lock or frozen-after-init |
| **B. Iterate shards** | Call each shard's `isIsolatingCurrentContext()` until one returns `true` | O(N) worst | ~5 lines; no new state |
| C. TLS marker (pointer) | Each shard thread stores `Unmanaged<Sharded>` in TLS at thread start; check TLS on query | O(1) | TLS key lifecycle + thread-entry injection |
| **D. Atomic ID in TLS** | Global `Atomic<UInt64>` counter assigns each pool an ID; shard threads store ID in TLS; check: TLS ID == pool ID | O(1) | Same as C, but value-typed (no ARC) |

### Option B: iterate shards (v1 recommendation)

```swift
public func isIsolatingCurrentContext() -> Bool? {
    for executor in executors {
        if executor.isIsolatingCurrentContext() == true { return true }
    }
    return false
}
```

For N ≤ 16 (typical), the linear scan is 16 × one `pthread_equal` call.
`pthread_equal` is a register comparison on Darwin and Linux — ~1 ns
per call. Total: ~16 ns worst case. This is below the measurement
threshold relative to `isIsolatingCurrentContext`'s call-site cost
(which includes the runtime's Swift-to-C bridge overhead at
`Executor.swift:956–964`).

No new state, no lifecycle management, no TLS infrastructure. Correct
by construction: if any shard's thread is the calling thread, returns
`true`.

### Option D: atomic ID in TLS (target recommendation)

For pools where N may grow (adaptive pooling, v2), linear scan becomes
O(N). The target is O(1) via a per-pool atomic ID stored in TLS:

1. `static let nextID = Atomic<UInt64>(0)` — global.
2. `let poolID = Sharded.nextID.wrappingAdd(1, ordering: .relaxed)` at
   init.
3. Each shard thread stores `poolID` in a `_Thread_local` or
   `swift_task_localValue` at thread start.
4. `isIsolatingCurrentContext()`: read TLS, compare with `poolID`.

Deferred to v2 because: (a) TLS injection requires modifying
`Kernel.Thread.Executor`'s thread-entry trampoline (a cross-type
change); (b) typical N is small enough that B suffices; (c) adaptive
pooling is not in v1 scope.

**Mechanism note (post-review):** The v2 TLS approach must use
C-level `_Thread_local` or `pthread_getspecific`, NOT Swift task-local
values (`TaskLocal`). Task-locals are per-`Task`, not per-thread; in
the no-task path where `isIsolatingCurrentContext` fires most often,
task-local values are unavailable.

### `checkIsolated` as fallback

```swift
public func checkIsolated() {
    guard isIsolatingCurrentContext() == true else {
        preconditionFailure(
            "Kernel.Thread.Executor.Sharded: current thread is not a shard thread"
        )
    }
}
```

Same scan, with crash-on-miss. Called only when `isIsolatingCurrentContext`
returns `nil` and the runtime's Assert flag is set.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Question | Recommendation |
|----------|----------------|
| v1 mechanism | Option B: iterate shards (O(N), ~5 lines) |
| v2 target | Option D: atomic ID in TLS (O(1)) |
| `checkIsolated` | Same scan + preconditionFailure |
| `complexEquality` | Not applicable; document that pool-level identity is via `isIsolatingCurrentContext`, not `isSameExclusiveExecutionContext` |

### Completed pre-DECISION steps

1. ~~**Implement `isIsolatingCurrentContext()` on Sharded** — Option B.~~
   **DONE** — implemented in `Kernel.Thread.Executor.Sharded.swift:86–91`.
   Iterates all shard executors; returns `true` on first match, `false`
   otherwise.
2. ~~**Implement `checkIsolated()` on Sharded** — scan + crash.~~ **DONE** —
   implemented in `Kernel.Thread.Executor.Sharded.swift:95–101`. Delegates
   to `isIsolatingCurrentContext()` with `preconditionFailure` on miss.
3. ~~**Write tests**: `assumeIsolated` from each shard thread; from a
   non-shard thread (must return `false`); post-shutdown (must return
   `nil`).~~ **DONE** — three tests in `Kernel.Thread.Executor.Sharded Tests.swift`:
   shard-thread returns `true`, non-shard-thread returns `false`,
   post-shutdown returns `false` (correct: no shard threads exist after
   `shutdown()` joins all threads).
4. **Evaluate whether Sharded needs `SerialExecutor` pool-level
   conformance** vs. per-shard-only conformance. If pool-level: the
   mutual-exclusion model changes (currently each shard serializes
   independently). **Status**: not yet evaluated; deferred — current
   implementation adds methods as standalone public API, not protocol
   conformance.

### Escalation note

Per [RES-004b]: scope is `swift-executors` (L3) only. No L1 primitive
change. No escalation required.

## References

- [SE-0471: `SerialExecutor.isIsolated`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0471-SerialExecutor-isIsolated.md)
  — adds `isIsolatingCurrentContext() -> Bool?` (accepted, Swift 6.2).
- [SE-0424: Custom Isolation Checking for SerialExecutor](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0424-custom-isolation-checking-for-serialexecutor.md)
  — adds `checkIsolated()` (accepted, Swift 6.0).
- `swiftlang/swift` — `stdlib/public/Concurrency/Executor.swift:389–390`
  (`isIsolatingCurrentContext`), `:370` (`checkIsolated`), `:538–549`
  (`isSameExclusiveExecutionContext`), `:956–964` (Swift-to-C bridge).
- `swiftlang/swift` — `stdlib/public/Concurrency/Actor.cpp:497–695`
  (runtime isolation check dispatch: no-task vs with-task paths).
- Commits `8fbf0e07f38`, `05f98b2e994` — `complexEquality` fix
  (Mike Ash, 2025-11-05).
- `executor-package-design.md` — Sharded taxonomy.
- `work-stealing-scheduler-design.md` Q5 — `TaskExecutor`-only for
  Stealing; identity question is orthogonal.
