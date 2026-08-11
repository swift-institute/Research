# Cooperative Yield Policy v2

<!--
---
version: 1.1.0
last_updated: 2026-04-29
status: DEFERRED
tier: 1
---
-->

## Context

`cooperative-donation-contract.md` v0.1.0 (DECISION, 2026-04-16) Q1
locked the v1 yield policy for `Executor.Cooperative.runUntil`:
**snapshot-then-check**. The decision rationale cited stdlib
parity with `CooperativeExecutor` post-bugfix (commits `0fbd382e9ca`
"Fix CooperativeExecutor to not loop forever" and `bd27a14ea00` "Fix
cooperative executor to return only after all jobs run"
[Verified in source: 2026-04-16]). The shipped implementation
(`Executor.Cooperative.swift:153-192` [Verified: 2026-04-29]) drains
a snapshot via `swap(&jobs, &drainBuffer)` between exit-condition
checks.

Bartlett's 2026-04-29 walkthrough of `DefaultActorImpl::defaultActorDrain`
([X post](https://x.com/jacobtechtavern/status/2049489712209862750))
documents the runtime's cooperative yielding via `shouldYieldThread()`
checked between jobs in the drain loop (`Actor.cpp:1697-1717`,
referenced from `priority-escalation-policy.md`). The runtime's
mechanism is **strictly richer** than snapshot-then-check: the runtime
yields the worker thread back to the global pool when libdispatch
decides the actor has held the thread long enough, on a per-job basis
rather than a per-snapshot basis.

This is not a defect in the v1 decision. The v1 mission per
`executor-package-design.md` ("complete, no-brainer,
theoretical-perfect") prioritized correctness and a single locked
behaviour over richer policy surfaces. Snapshot-then-check is the
correct v1 default — bounded work per check, infinite-drain bug
avoided.

The richer design space — per-job yield budgeting, time-slicing,
caller-supplied predicates — is a v2 question. This note scopes that
v2 question and parks the design until v2 work begins.

## Question

Should `Executor.Cooperative.runUntil` accept a yield-policy parameter
in v2, and what is its shape?

Two sub-questions:

1. **Where does the policy type live?** L1 (executor-primitives) as
   ecosystem vocabulary, or L3 (swift-executors) as package-local?
2. **What is the call-site surface?** Inline parameter on `runUntil`,
   or attached to the `Executor.Cooperative` instance?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| v1 yield policy is locked | `cooperative-donation-contract.md` Q1 (DECISION) | Any addition is v2; no v1 amendment |
| Snapshot-then-check must remain the default | Behavioural compatibility with v1 | The v2 default policy must preserve snapshot-then-check semantics |
| `Executor.Cooperative` is the only candidate consumer | `Kernel.Thread.Executor` owns its thread (no yield target); `Executor.Scheduled` is a wrapper (no drain loop); `Executor.Main` is libdispatch-bound on Darwin and a separate run loop elsewhere | Yield policy applies only to donated-thread executors |
| Single-consumer types should not become L1 primitives | [RES-018] | New L1 vocabulary requires a second consumer |
| Yield policy is platform-agnostic | No syscall, no platform-specific behavior | If introduced at L1, no platform layering concern |
| The donation contract is `RunLoopExecutor`-shaped | `cooperative-donation-contract.md` Q5 (DECISION) | Surface evolution must remain compatible with the protocol's three methods |

## Analysis

### Sub-question 1: Location

| Option | Layer | Position |
|--------|-------|----------|
| A | swift-executor-primitives (L1) | Ecosystem vocabulary; available to any L3 consumer |
| B | swift-executors (L3) | Package-local; promotion path to L1 if a second consumer arrives |

**Recommend B for v2.** [RES-018] Premature Primitive Anti-Pattern
requires a second consumer for new L1 vocabulary. Surveying the
swift-executors v1 taxonomy:

- `Executor.Cooperative` — donated thread; yield is meaningful.
- `Kernel.Thread.Executor.{Polling, Sharded, Stealing}` — own their
  threads; nothing to yield TO.
- `Executor.Scheduled` — thin wrapper; no drain loop of its own (drains
  pass through to the base executor).
- `Executor.Main` — libdispatch-bound on Darwin (runtime handles
  yielding); separate run loop on Linux/Windows where yield semantics
  are not required for the main thread.

Only one consumer in the v1 taxonomy — `Executor.Cooperative`. [RES-018]
fails on the second-consumer check at the L1 placement.

If a future executor introduces a second consumer (e.g., a
work-stealing pool with cooperative tick semantics, or a runtime-style
shared-pool drainer), promote the type to L1 then. The promotion is
mechanical — moving a self-contained enum from
`swift-executors/Sources/Executors/` to
`swift-executor-primitives/Sources/Executor Primitives Core/`.

### Sub-question 2: Surface

```swift
extension Executor {
    /// Cooperative yield policy for the donated-thread drain loop.
    public enum Yield: Sendable {
        /// Drain a snapshot to empty, then re-check the exit condition.
        /// v1 default behaviour; preserved as v2 default. Bound is the
        /// snapshot itself — new jobs enqueued during drain wait until
        /// the next snapshot.
        case snapshot

        /// Yield after `count` jobs, even if more pending in the snapshot.
        case budget(count: Index<UnownedJob>.Count)

        /// Yield once `slice` of wall-clock time has elapsed within the snapshot.
        case timeSlice(Duration)

        /// Caller-supplied predicate; yields when it returns `true`.
        case predicate(@Sendable () -> Bool)
    }
}
```

Call site:

```swift
public func runUntil(
    yieldOn yield: Executor.Yield = .snapshot,
    until exit: () -> Bool
)
```

[API-IMPL-012]: closure trails the signature. ✓
[API-IMPL-014]: configuration (modifier with default) precedes the
closure. ✓

**Why `.snapshot` and not `.exhaustSnapshot` or `.exhaust`:**
- `.exhaust` alone would suggest unbounded drain, which v1 explicitly
  rejected (constraint matrix in `cooperative-donation-contract.md`
  line 191-193: Option C drain-all-then-check has "unbounded delay
  if jobs enqueue more jobs").
- `.exhaustSnapshot` is a verb-noun compound — forbidden by
  [API-NAME-002] / [API-NAME-005] (the internal capital triggers
  re-verification per [API-NAME-007]).
- `.snapshot` names the bounding mechanism (the snapshot itself
  bounds drain) and reads as a single concept. The DocC comment
  explains the snapshot-then-check semantic. v2 default identical
  to v1 behaviour.

**Why a parameter on `runUntil` and not on the instance:**
Per-call yield policy lets the caller adjust granularity for different
phases of work. An instance-level setting would force the choice at
construction. A parameter with a default keeps v1 call sites
unchanged.

### Comparison

| Criterion | A: L1 vocabulary | B: L3 swift-executors-local |
|-----------|:----------------:|:---------------------------:|
| Second consumer exists today | ✗ | n/a |
| Promotion path if second consumer arrives | natural (already at L1) | mechanical move |
| Risk of premature primitive | high | low |
| Visibility across ecosystem | broad | scoped |

## Outcome

**Status: DEFERRED.**

For v1: no change. The snapshot-then-check decision in
`cooperative-donation-contract.md` stands as DECISION-status; this
note does not amend it.

For v2: the proposed shape is `Executor.Yield` enum (4 cases),
L3-local in swift-executors, consumed by
`Executor.Cooperative.runUntil(yieldOn:until:)`. The default
`.snapshot` preserves v1 behaviour exactly. v2 work
re-evaluates the L1-vs-L3 location per [RES-018] when v2 consumers
are known.

**Re-evaluate when:**

- v2 work begins, OR
- A second L3 consumer of richer yield policies surfaces (work-stealing
  with cooperative tick, runtime-pool-style drainer, etc.).

Until then, no implementation. The note exists to record the design
direction so that future v2 work can resume from a stamped starting
point rather than re-discovering the analysis.

## Changelog

- **v1.1.0 (2026-04-29).** Code-sketch compliance fix per /code-surface
  audit: `.exhaustSnapshot` case renamed to `.snapshot` ([API-NAME-002]
  / [API-NAME-005] verb-noun compound forbidden; [API-NAME-007]
  internal-capital trigger). Default also updated in the `runUntil`
  signature.
- **v1.0.0 (2026-04-29).** Initial DEFERRED note. Snapshot-then-check
  v1 contract preserved; richer yield policies parked for v2.

## References

### Internal
- `cooperative-donation-contract.md` v0.1.0 (DECISION, 2026-04-16) — Q1 Yield policy locked snapshot-then-check; this note's deferral is layered on that decision.
- `priority-escalation-policy.md` v0.6.0 (DECISION) — orthogonal axis (M3 thread QoS, not yield).
- `executor-package-design.md` — v1 mission "complete, no-brainer, theoretical-perfect."
- `swift-foundations/swift-executors/Sources/Executors/Executor.Cooperative.swift:153-192` — current `runUntil` implementation [Verified: 2026-04-29].

### External
- Bartlett, J. — ["How Swift uses your hardware to guarantee actor isolation"](https://x.com/jacobtechtavern/status/2049489712209862750), 2026-04-29 — describes runtime's `shouldYieldThread()` per-job check.
- `swiftlang/swift` — [`stdlib/public/Concurrency/Actor.cpp:1697-1717`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Actor.cpp) — runtime drain loop with `shouldYieldThread()`.
- `swiftlang/swift` — `stdlib/public/Concurrency/CooperativeExecutor.swift:323-324` — stdlib's snapshot-then-check via raw nanosleep [Verified in `cooperative-donation-contract.md`].
