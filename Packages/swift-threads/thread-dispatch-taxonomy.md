# Thread Dispatch Taxonomy: Executor, Sharded, and Pool

<!--
---
version: 1.0.0
last_updated: 2026-04-14
status: DRAFT — initial framing
tier: 2
related:
  - swift-executors/Sources/Executors/Kernel.Thread.Executor.swift
  - swift-executors/Sources/Executors/Kernel.Thread.Executor.Sharded.swift
  - swift-executors/Sources/Executors/Kernel.Thread.Pool.swift
  - swift-foundations/HANDOFF-kernel-type-relocation-research.md
  - swift-foundations/Research/kernel-type-relocation.md
---
-->

## Context

swift-executors now contains three types in the `Kernel.Thread` namespace that all describe "something that runs work on OS threads":

| Type | Role | Conforms to `SerialExecutor`? | Introduced |
|------|------|-------------------------------|------------|
| `Kernel.Thread.Executor` | Serial executor wrapping one OS thread | **Yes** | 2026-04-08 (moved from swift-kernel) |
| `Kernel.Thread.Executor.Sharded` | Round-robin selector over N executors | No (has `.next()` for extraction) | 2026-04-08 (moved from swift-kernel) |
| `Kernel.Thread.Pool` | Admission-gated closure dispatch over a Sharded | No (has `.run { }` for submission) | 2026-04-14 (moved from swift-io) |

The naming suggests a hierarchy: `Executor` → `Executor.Sharded` → `Pool`. But inspection reveals that only `Executor` is actually an executor. `Sharded` and `Pool` are *containers/schedulers* with different submission APIs:

| Type | Submission API | Storage |
|------|----------------|---------|
| `Executor` | `Task(executorPreference: executor) { … }` (via `asUnownedSerialExecutor`) | 1 OS thread + job queue |
| `Executor.Sharded` | `sharded.next()` → `Kernel.Thread.Executor` → submit | N `Executor` instances + round-robin counter |
| `Pool` | `pool.run { … }` (async closure submission with admission gate) | 1 `Executor.Sharded` + `Async.Semaphore` |

The name `Executor.Sharded` promises "a sharded executor variant" but delivers "a selector that hands out executors." This mismatch was noted during the 2026-04-14 IO.Blocking → Pool extraction and triggered this research.

## Question

Given three types in the same namespace with three different abstraction levels, what is the correct taxonomy?

Specifically:

1. **Is `Kernel.Thread.Executor.Sharded` correctly named?** It passes the [API-NAME-001] "X is a kind of Y" test only if `Sharded` IS an `Executor` variant. Today it isn't.
2. **How should `Pool` relate to `Sharded`?** Composition (Pool wraps Sharded), absorption (Pool subsumes Sharded's role), or siblinghood (both exist independently)?
3. **Should "the executor role inside a pool" have a distinct name** (e.g., `Pool.Executor`)?

## Prior Art

### Rust

| Ecosystem | Type | Role |
|-----------|------|------|
| Tokio | `tokio::runtime::Runtime` | Admission + worker pool + task scheduler |
| Tokio | `tokio::task::spawn_blocking` | Submission API — admission-gated closure dispatch |
| rayon | `rayon::ThreadPool` | Worker pool with `.install { closure }` submission |
| rayon | `rayon::ThreadPoolBuilder` | Configuration |

Tokio distinguishes `Runtime` (the pool + scheduler) from `Handle` (a reference to a running Runtime). Both support `spawn`/`spawn_blocking`. The serial executor role — "one thread running one task at a time" — doesn't have a first-class name in Tokio; it's implicit inside the scheduler.

rayon has `ThreadPool` as the public type; the per-thread serial executor is internal. No `rayon::Executor` public type.

### Java

| Type | Role |
|------|------|
| `java.util.concurrent.Executor` | Base interface: single method `execute(Runnable)` |
| `java.util.concurrent.ExecutorService` | Extends `Executor` with lifecycle, submission, shutdown |
| `java.util.concurrent.ThreadPoolExecutor` | Concrete thread pool implementation of `ExecutorService` |
| `java.util.concurrent.Executors` | Factory namespace for common configurations |

Java's naming is hierarchical: `Executor` (interface) → `ExecutorService` (richer interface) → `ThreadPoolExecutor` (class). Every type has "Executor" in the name. A `ThreadPoolExecutor` **is** an `Executor` — the interface dispatch is the submission API.

This is the opposite approach to our current state: in Java, "thread pool" is a kind of executor. The name contains both concepts.

### Go

No analog. Go's runtime scheduler is opaque; consumers use `go func() { }` which has no user-facing type.

### Python

`concurrent.futures.ThreadPoolExecutor` follows Java's pattern — pool IS an executor. Submit API is `executor.submit(fn, *args)`.

### Summary of Prior Art

| Philosophy | Ecosystems | Implication |
|------------|------------|-------------|
| "Thread pool IS an executor" (pool ⊆ executor) | Java, Python | Name all pool types `*Executor`; Executor is the interface |
| "Thread pool HAS executors" (pool ⊇ executor) | rayon | Pool is top-level; per-thread executor is internal |
| "Runtime is its own concept" | Tokio | Runtime is the composition unit; executor role is implicit |

Swift's standard library takes the Java/Python path: `SerialExecutor`, `TaskExecutor` are protocols; concrete pools conform. Any type that dispatches work to threads and conforms to one of these protocols *is* an executor by that stdlib vocabulary.

## Analysis

### Option A: Sharded becomes a real `TaskExecutor`

Conform `Kernel.Thread.Executor.Sharded` to `TaskExecutor`. Work submission becomes:

```swift
Task(executorPreference: sharded) { /* runs on one of Sharded's threads */ }
```

`TaskExecutor` supports concurrent work (N threads), whereas `SerialExecutor` is 1-at-a-time. Sharded's round-robin matches `TaskExecutor` semantics naturally.

**Consequences**:
- The name `Executor.Sharded` becomes truthful — it IS a (task) executor variant.
- `.next()` becomes redundant at call sites — consumers submit to `sharded` directly rather than extracting a serial executor.
- `.next()` may still be useful for *actor pinning* (one `@Actor`'s `unownedExecutor` needs a `SerialExecutor`, not a `TaskExecutor`) — so `.next()` returns a serial executor for pinning, but direct submission uses the task executor.
- `Pool`'s internal `executors.next()` call remains — Pool still pins submissions via round-robin to get serial executors per invocation (matching today's behavior).

**Pros**:
- Name matches implementation.
- Consumers get idiomatic `Task(executorPreference: sharded)` without manual extraction.
- No rename; only a conformance addition.

**Cons**:
- Slight semantic overloading — Sharded is both a task executor (for submission) AND a serial-executor provider (for pinning via `.next()`).
- Requires verifying `TaskExecutor` conformance is compatible with the round-robin dispatch semantics (trivial — just implement `enqueue(_:)` by calling `next().enqueue(_:)`).

### Option B: Rename Sharded — `Executor.Group` or `Executor.Collection`

Keep Sharded's current implementation (not an executor, just a selector) but rename to reflect that honestly:

- `Kernel.Thread.Executor.Group` — "group of executors"
- `Kernel.Thread.Executor.Collection` — more neutral
- `Kernel.Thread.Executor.Pool` — conflicts with `Kernel.Thread.Pool`

**Pros**:
- Honest naming per [API-NAME-001].
- Minimal implementation change (rename only).

**Cons**:
- Breaking API change for consumers of `Executor.Sharded`.
- Doesn't add functionality, only renames for clarity.
- `Executor.Group` reads as "a group that IS an executor" — arguably still misleading under strict reading.

### Option C: Absorb Sharded into Pool

Make `Sharded` an implementation detail of `Pool`. Public surface:

```swift
public struct Kernel.Thread.Pool {
    // Construction with N workers + admission
    // .run { } for dispatch
    // .next() for raw executor extraction (replaces Sharded.next())
    // .shutdown()
}
```

Delete `Executor.Sharded` as a public type. Its responsibilities split:

- Round-robin selection → moves inside Pool.
- `.next()` for actor pinning → exposed on Pool (e.g., `pool.executor()`).
- Options (thread count) → merges into `Pool.Options`.

**Pros**:
- Single public pool concept per [MOD-DOMAIN].
- No naming paradox: Pool is the pool; Executor is the single-thread executor; no third in-between type.
- Matches rayon's approach: one `ThreadPool` public type.

**Cons**:
- Breaking change for all current Sharded consumers (swift-io uses Sharded directly today for actor pinning — `pool._executors.next()` in `IO+Blocking.swift`).
- Forces admission gating on all pool consumers, even those who don't want it (e.g., swift-io's witness factory, which doesn't use admission). Could be mitigated by splitting Pool into base (sharded selection) + variant (admission-gated dispatch).

### Option D: Status Quo — three sibling concepts under Thread

Accept that `Executor.Sharded` is a slightly-misleading name and leave it. Document that Sharded is a selector, not an executor variant, despite the name.

**Pros**:
- Zero disruption.

**Cons**:
- [API-NAME-001] violation persists.
- Future types ("Sharded what?") inherit the confusion.

## Preliminary Recommendation

**Leaning toward Option A (conform Sharded to `TaskExecutor`)** for these reasons:

1. **Name honesty with minimum breakage**: the current name becomes accurate via a conformance, not a rename. No consumer code changes beyond optional simplification (replacing manual `.next()` + `Task(executorPreference:)` with direct `Task(executorPreference: sharded)`).
2. **Prior art alignment**: Java and Python treat "pool IS an executor" as natural. Swift's stdlib already defines `TaskExecutor` as the protocol a multi-thread scheduler should conform to. Not conforming is the unusual position.
3. **Preserves Pool's distinct role**: Pool remains a separate concept — "admission-gated closure dispatch" — built atop a `TaskExecutor`. The separation between "executor (any kind)" and "admission-gated dispatch" is semantically clean.
4. **Doesn't block future work**: if later we want Option C (absorb into Pool), Option A doesn't preclude it — we can still deprecate Sharded and fold it into Pool.

### What remains to verify before committing to Option A

1. **Does `TaskExecutor` conformance compose cleanly with Sharded's existing `Sendable` + `final class` shape?** Expected yes (`TaskExecutor` has a single `enqueue(_: UnownedJob)` requirement plus `asUnownedTaskExecutor`).
2. **Does round-robin dispatch break any TaskExecutor semantic contracts?** `TaskExecutor` permits any scheduling policy; round-robin is fine.
3. **Does exposing both `TaskExecutor` submission AND `.next()` → `SerialExecutor` create confusion?** Possibly. Could document: "submit via `Task(executorPreference:)` for N-way parallelism; use `.next()` to pin an actor to one shard for single-threaded semantics."
4. **Does it affect Pool's internal implementation?** No. Pool still calls `executors.next()` to get a serial executor per `run` invocation (matching the current pattern inherited from IO.Blocking.Run.swift).

### Open questions for further research

- **Is there a `Pool.Executor` concept worth carving out?** i.e., should the executors *owned by a pool* be distinct from standalone `Kernel.Thread.Executor`? Today they're the same type; no strong reason to split. Defer.
- **Should Pool expose `.next()`?** Matches Sharded's API for actor pinning but duplicates it. If Sharded stays public (Option A), no need. If Sharded is absorbed (Option C), yes.

## Outcome

**Status: DRAFT — RECOMMENDATION PENDING VERIFICATION of Option A**

Next steps:

1. Verify Option A's technical questions (items 1–3 above) via minimal experiment in `swift-executors/Experiments/sharded-as-task-executor/`.
2. If verified, implement the conformance as a small follow-up PR.
3. Update this document with empirical results and finalize recommendation.

If Option A fails verification, fall back to Option B (rename) and re-evaluate.

## References

- `swift-executors/Sources/Executors/Kernel.Thread.Executor.swift`
- `swift-executors/Sources/Executors/Kernel.Thread.Executor.Sharded.swift`
- `swift-executors/Sources/Executors/Kernel.Thread.Pool.swift`
- `swift-foundations/HANDOFF-kernel-type-relocation-research.md` (parent investigation)
- `swift-foundations/Research/kernel-type-relocation.md` (2026-04-08 executor extraction rationale)
- [Swift Evolution SE-0417: Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md)
- [Swift Evolution SE-0392: Custom Actor Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md)
- Java `java.util.concurrent` package documentation
- Tokio `tokio::runtime::Runtime` and `tokio::task::spawn_blocking`
- rayon `rayon::ThreadPool`
