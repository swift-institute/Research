---
title: Async.Barrier ideal-API investigation
date: 2026-04-25
context: forums-review Q3 follow-through; user asked for "thorough investigation on what the ideal api is"
status: research — DRAFT
provenance: c9 review post 3 (`Research/forums-review-simulation-2026-04-24.md:93`); cross-language API survey commissioned 2026-04-25
---

# Async.Barrier ideal-API investigation

## 1. The triggering question

The c9 simulation reviewer (`Research/forums-review-simulation-2026-04-24.md:93`) asked:

> Async.Barrier.arrive() at Sources/Async Barrier Primitives/Async.Barrier.swift:95 — is the party count fixed at init, or can it grow? If a barrier is waiting for N arrivals and a task is cancelled before its arrival, does the barrier become un-releasable and deadlock the other waiters, or is there a release path for cancelled-before-arrival? This is the class of question that's easy to get wrong silently; Rust's `parking_lot` barrier, for comparison, offers a `wait_timeout` but not a cancellation-release path, and a cancellation-release path is arguably the more Swift-idiomatic shape.

Earlier in this cycle we shipped a documentation-only response (commit `5422f6e3`), pinning the contract "barrier deadlocks if any party is cancelled before `arrive()`." The user has since reopened the question: can we instead deliver a strict improvement that closes the deadlock case at the API level?

This document surveys the design space, applies the `/implementation` skill's foundational axioms, and proposes candidate shapes with trade-offs.

## 2. Cross-language design landscape

(Detailed survey commissioned 2026-04-25; abridged here. Sources: `java.util.concurrent.{CountDownLatch, CyclicBarrier, Phaser}`, `std::sync::Barrier`, `parking_lot::Barrier`, `tokio::sync::Barrier`, `sync.WaitGroup`, `threading.Barrier`, `asyncio.Barrier`, `kotlinx.coroutines`, Erlang/OTP supervision.)

| Pattern | Languages | Missing-party policy |
|---|---|---|
| **Deadlock-acceptance** | Rust (std/parking_lot/tokio), Go (`WaitGroup`), Java (`CountDownLatch`) | Caller's problem. Block forever. Tokio's silent-future-drop documented as a pitfall. |
| **Broken-state** | Java (`CyclicBarrier`), Python (`threading.Barrier`, `asyncio.Barrier`) | Cancellation/timeout/abort puts barrier into a `broken` state; current+future waiters throw `BrokenBarrierError`. Recovery via `reset()`. |
| **Dynamic deregistration** | Java (`Phaser`) | Parties register/deregister at runtime. Cancellation = `arriveAndDeregister()`. No broken state — the count adjusts. |
| **Structural-concurrency** | Erlang/OTP, Kotlin coroutines | No barrier primitive. Use process supervision / structured task scopes. Cancellation tears down siblings; deadlock structurally prevented. |

Three observations:

1. **Two distinct primitives in Java's stdlib**: `CountDownLatch` (one-shot, asymmetric — explicit `countDown()` from non-waiter parties) and `CyclicBarrier` (cyclic, symmetric — every party calls `await()`). They aren't substitutes; they answer different questions.
2. **Python's broken-state model is the cleanest API-wise** — every failure mode (cancel / timeout / abort / action-throw) converges on the same `.broken` state with one recovery call (`reset()`).
3. **Kotlin's deliberate omission is informative** — structured concurrency makes the missing-party question moot when the barrier lives inside a task scope that itself manages cancellation.

## 3. Ecosystem-local prior art

| Primitive | Location | Shape | Relevance |
|---|---|---|---|
| `Ownership.Latch<Value>` | `swift-ownership-primitives` | `~Copyable` value cell, atomic state machine, exactly-once `take()` | Vocabulary precedent (Latch ≠ Barrier; Latch is value-bearing); `~Copyable` exactly-once pattern is reusable |
| `Async.Gate` (= `Promise<Void>`) | `Async Promise Primitives/Async.Gate.swift` | One-shot signal, multi-waiter, non-cancellation-observing | Already in the package; covers the "broadcast a release once" case without per-party arrival |
| `Async.Promise<Value>` | `Async Promise Primitives/` | Single-value, multi-waiter, non-cancellation-observing | Same shape as Gate; Promise.value() is `async -> Value` (not throws) by deliberate design (gap fill #1) |
| `Async.Semaphore` | `Async Semaphore Primitives/` | FIFO admission counter | Adjacent — solves "max N concurrent" not "N together at once" |
| `Async.Barrier` | this package | N-party rendezvous, fixed-count, non-throwing arrive(), no cancellation-release path | the subject |
| (no `Async.Latch`) | — | — | The Java CountDownLatch slot is structurally vacant in this ecosystem |
| (no `Async.Phaser`) | — | — | Dynamic-deregistration slot is vacant |

The local landscape is consistent: every existing primitive uses non-throwing async accessors with explicit termination/release operations. No primitive currently routes cancellation through the type system.

## 4. Applying the /implementation skill axioms

### [IMPL-INTENT] — does the call site read as intent?

The current `await barrier.arrive()` reads as "I, this party, have arrived at the rendezvous." That's intent. ✓

The behavior on cancellation, however, leaks mechanism: the caller has to *know* that the barrier counts arrivals and that a cancelled-before-arrival party will deadlock the rest. The doc-only fix shifts that mechanism into prose; an API that closes the deadlock at the type level would keep intent at the call site without leaking the mechanism.

### [IMPL-COMPILE] — what could the compiler enforce?

Current contract requires runtime guarantees from the caller:
1. Each party calls `arrive()` exactly once.
2. Cancellation must not interrupt arrival.
3. Total arrivals == `parties` declared at init.

`/implementation` lists the relevant compile-time mechanism for "resource has exactly-once lifecycle":

> Resource has exactly-once lifecycle → `~Copyable` → [IMPL-064]

A `~Copyable` per-party handle that consumes itself on `arrive()` and runs deinit-deregistration on accidental drop would express the party-count invariant in the type system rather than in caller discipline. That's exactly the move [IMPL-COMPILE] argues for.

### [IMPL-001] — is the cancellation-release behavior a principled absence or a gap?

The current "deadlock on cancelled-before-arrival" is not a principled absence — it doesn't preserve a mathematical property. It's a gap: the runtime has the information needed (the cancelled party's failure to register), it just lacks an API to surface it. Per [IMPL-001], gaps SHOULD be closed.

### [IMPL-087] — does the component need to exist?

Yes — N-party rendezvous is a real coordination shape that neither `Async.Gate` (one signaler, many waiters) nor `Async.Semaphore` (admission counter) covers. The structured-concurrency dismissal ("just use TaskGroup") is too strong: barriers compose with task groups but also serve callback/actor-bridge cases where TaskGroup doesn't apply.

### Composite verdict

The doc-only resolution committed earlier (`5422f6e3`) is *honest* but *not ideal* against the skill's axioms. An ideal API would either (a) make the deadlock case impossible at the type system level via `~Copyable` handles, or (b) surface it via typed throws, allowing callers to recover. Both are preferable to "trust the caller; here's what goes wrong if they fail."

## 5. Candidate API shapes

### Shape A — minimal change: typed-throws on `arrive()`

```swift
extension Async.Barrier {
    /// Arrive at the barrier; throws if Task is cancelled before all parties arrive.
    nonisolated(nonsending)
    public func arrive() async throws(Async.Lifecycle.Error) {
        // If cancellation is observed:
        //   - decrement the expected party count (or mark this party as "won't arrive")
        //   - re-evaluate release condition (arrived == remainingExpected)
        //   - throw .cancelled
        // Other parties' arrive() releases immediately if the new condition is met.
    }
}
```

Behavior change:
- `arrive()` becomes `async throws(Async.Lifecycle.Error)`. Cancellation surfaces as `.cancelled`.
- Cancelled parties are *removed* from the expected count. Remaining parties release when `arrived == originalParties - cancelledCount`.
- Callback-based `arrive(_:)` stays unchanged (callbacks have no Task to cancel).

Pros:
- **Smallest API surface change.** Adds one `throws` to one method.
- **Closes the c9 deadlock case at the API level.** Cancelled party throws; remaining parties still release.
- Aligns with `Async.Lifecycle.Error` we just consolidated for Semaphore.
- The non-throwing callback `arrive(_:)` stays available for non-cancellation-aware code paths.

Cons:
- Every `await barrier.arrive()` call site now requires `try`. ABI break.
- Doesn't help the case where a party is cancelled BEFORE calling `arrive()` at all (the count is decremented only via `arrive() throws`). That requires structural-concurrency idioms.
- Still requires runtime accounting (cancellation count, party count). The type system doesn't enforce exactly-once.

### Shape B — `~Copyable` party handle (Phaser-flavored)

```swift
extension Async {
    public struct Barrier: ~Copyable, Sendable {
        public init(parties: Int) { ... }

        /// Register a party. Returns a ~Copyable handle for that party's
        /// participation. Handle's lifecycle drives the count.
        public consuming func party() -> Party { ... }

        public struct Party: ~Copyable {
            /// Arrive at the rendezvous. Consumes the handle.
            public consuming func arrive() async throws(Async.Lifecycle.Error)

            deinit {
                // If consumed before arrive(): decrement expected count;
                // peers release when arrived == remaining.
            }
        }
    }
}
```

Pros:
- **`~Copyable` enforces exactly-once participation per party at compile time.** A `Party` cannot be used twice; a `Party` cannot be ignored either (deinit fires).
- **Cancellation-before-`arrive()` is structurally handled** — Task cancellation drops the `Party`, deinit deregisters, peers release.
- Handle ownership pairs naturally with structured concurrency: spawn a child task with a captured `Party`; cancellation of the child drops the handle.
- Typed throws on `arrive()` makes the cancellation-during-arrive case explicit too.

Cons:
- **Significantly bigger API change.** New nested type, new construction shape.
- **Per-party registration adds ceremony** at call sites: `let party = barrier.party(); ... try await party.arrive()` vs the current single-line.
- The barrier itself becomes `~Copyable` — passing it to multiple tasks requires careful ownership patterns (the handles, not the barrier, are what's distributed).
- Deinit-driven side-effects (the deregister-on-drop) are subtle; a developer reading `let party = barrier.party()` followed by an early return won't necessarily expect peers to release.

### Shape C — broken-state model (Python-flavored)

```swift
extension Async.Barrier {
    public func arrive() async throws(Async.Lifecycle.Error) { ... }  // throws .cancelled when broken
    public func abort()  // any party can break the barrier; peers throw on next arrive
    public func reset()  // returns barrier to pristine state
    public var isBroken: Bool { ... }
}
```

Pros:
- Familiar from `threading.Barrier`/`asyncio.Barrier` — readers from Python know exactly what this does.
- Decouples cancellation, abort, and reset into named operations.
- Supports the "I now know I won't arrive" case explicitly via `abort()`.

Cons:
- **Largest API surface.** `abort` + `reset` + `isBroken` are real public API, all stateful.
- A reset is implicitly cyclic — but the current Barrier docstring says "A barrier can only be used once." Adopting reset means committing to cyclic semantics.
- Broken-state is a runtime concept; doesn't lift the contract into the type system the way Shape B does.
- Adds a class of subtle bugs: "is the barrier broken when I check, but unbroken by the time I act?" (TOCTOU). Python ships with these.

### Shape D — defer to structured concurrency (delete the primitive)

Delete `Async.Barrier`. Document the structured-concurrency idiom — multi-party rendezvous becomes "spawn N child tasks under a common scope; cancellation of the scope tears down siblings." Provide a `Async.Latch(count:)` (Java's CountDownLatch shape) for asymmetric coordination, since that one isn't replaceable by structured concurrency.

Pros:
- **Smallest primitive surface.** One fewer type to maintain.
- Cancellation-release becomes "the scope cancelled."
- Aligns with Kotlin's deliberate omission.

Cons:
- **Breaks the package's stated 13-primitive surface.** The simulation OP listed Barrier; consumers may already depend on it.
- Doesn't actually answer the question — c9 asked about Async.Barrier specifically. Deleting is "you shouldn't have asked."
- Multi-party rendezvous *outside* a TaskGroup (callback bridge, actor-rendezvous) is a real use case. Forcing TaskGroup is over-prescriptive.

## 6. Skill-axiom scoring

Scoring each shape against the relevant rules. ✓ = strong fit, ◐ = partial, ✗ = miss.

| Axiom / rule | Shape A (typed throws) | Shape B (~Copyable handle) | Shape C (broken state) | Shape D (delete + structural) |
|---|---|---|---|---|
| `[IMPL-INTENT]` call site reads as intent | ✓ | ◐ (more ceremony) | ✓ | ✓ |
| `[IMPL-COMPILE]` compile-time invariant enforcement | ◐ (typed throws only) | ✓ (~Copyable + typed throws) | ✗ (runtime state) | ✓ (structural) |
| `[IMPL-064]` types default to `~Copyable` | ✗ | ✓ | ✗ | n/a |
| `[IMPL-001]` close real gaps; preserve principled absences | ✓ | ✓ | ✓ | ◐ (closes question by removing it) |
| `[IMPL-087]` component existence justified | ✓ (improvement to existing) | ✓ (improvement to existing) | ✓ (improvement to existing) | ✗ (removes the component) |
| Ecosystem alignment (Pool, Async.Gate, Async.Semaphore patterns) | ✓ (typed throws, lifecycle-error reuse) | ◐ (handle pattern uncommon locally) | ✗ (broken-state runtime concept absent locally) | ✓ (structural concurrency idiom is universal) |
| Cost (LOC + ABI + concept count) | low | medium-high | high | high (downstream churn) |

## 7. Recommendation

**Shape A is the right pre-1.0 move; Shape B is worth a dedicated experiment to validate before adopting.**

Reasoning:

1. **Shape A closes the c9 deadlock case at minimal cost.** Cancellation surfaces as `Async.Lifecycle.Error.cancelled`; cancelled parties are removed from the expected count; peers release. The API change is one `throws` annotation. Aligns with the `Async.Lifecycle.Error` consolidation just landed in commit `0b1f79b`.

2. **Shape B is more aligned with `[IMPL-COMPILE]`** — `~Copyable` per-party handles enforce the exactly-once participation contract at compile time rather than asking callers for runtime discipline. But it's a significant API redesign and the handle-ownership model interacts with structured concurrency in ways that warrant an `Experiments/` package before committing.

3. **Shape C's broken-state model is well-known but lifts runtime state into public API**; a less Swift-native shape, defensible only if cyclic-barrier semantics are needed (they aren't currently — the package commits to one-shot).

4. **Shape D (delete) is over-prescriptive** for a package that markets a 13-primitive surface and where the OP simulation explicitly listed Barrier.

### Suggested execution

| Phase | Action |
|---|---|
| Phase 1 (this cycle) | Implement Shape A. Revise `arrive()` to `throws(Async.Lifecycle.Error)`; surface `.cancelled` when Task is cancelled. Adjust release condition (`arrived == originalParties - cancelledCount`). Update tests + Semantics article. |
| Phase 2 (deferred) | Spawn an `Experiments/barrier-handle-ownership` package validating Shape B's `~Copyable` Party handle pattern under representative use cases (TaskGroup integration, actor-bridge, callback-driven). If validation succeeds, propose Shape B as a 1.0 follow-up. |
| Phase 3 (deferred, optional) | If Shape B doesn't validate, revisit Shape C's broken-state model. |

The doc-only commit (`5422f6e3`) becomes the documented contract for the gap *between* the documentation pass and Shape A landing. Once Shape A lands, the documentation is updated to reflect the new contract: cancellation surfaces as a typed error, peers release.

## 8. Open questions for the user

`ask:` Shape A's "decrement expected count on cancellation" introduces a notion of "effective party count" that diverges from the constructor's `parties:`. Is the spec "barrier releases when *every party that called `arrive()` and didn't cancel* has arrived"? That's the natural reading but worth confirming.

`ask:` Should the callback-form `arrive(_:)` (which has no cancellation by design) gain a parallel "decline()" so that a non-async caller can also signal "I won't arrive"? That would close the asymmetry between the async and callback APIs.

`ask:` Phase 2's experiment-first approach for Shape B — is `Experiments/barrier-handle-ownership` worth the effort, or is the user satisfied with Shape A as the terminal state?

## 9. Cross-references

- `Research/forums-review-simulation-2026-04-24.md` — c9 review post 3.
- `Research/forums-review-objections-2026-04-24.md` — `Async.Barrier` not in top-5 angles, but cancellation lands under angle #3 Concurrency.
- `Research/typed-throws-audit-2026-04-24.md` — `Async.Lifecycle.Error` adoption mapping.
- `swift-ownership-primitives/Sources/Ownership Latch Primitives/Ownership.Latch.swift` — `~Copyable` exactly-once value-cell precedent.
- `Async.Promise.Gate.swift` — local one-shot signaling primitive.
- `swift-async-primitives/Sources/Async Primitives/Async Primitives.docc/Semantics.md` — Barrier's current cancellation row.
- `[IMPL-INTENT]`, `[IMPL-COMPILE]`, `[IMPL-001]`, `[IMPL-064]`, `[IMPL-087]` — `/implementation` skill foundational axioms applied.
