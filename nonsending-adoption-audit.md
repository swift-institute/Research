# Nonsending Adoption Audit

<!--
---
version: 1.2.0
last_updated: 2026-02-25
status: SUPERSEDED
superseded_by: ownership-transfer-conventions.md
tier: 2
trigger: Pointfree #355 analysis — nonisolated(nonsending) as default interface pattern
---
-->

> **SUPERSEDED** (2026-04-02) by [ownership-transfer-conventions.md](ownership-transfer-conventions.md).
> All findings consolidated into the topic-based document. This file retained as historical rationale.

## Context

Pointfree episode #355 ("Beyond Basics: Isolation, ~Copyable, ~Escapable", Feb 23, 2026) demonstrated a foundational insight: marking dependency closures as `nonisolated(nonsending)` instead of `@Sendable` allows isolation to propagate from caller to callee. This eliminates unnecessary thread hops and suspension points, enabling synchronous execution paths when the callee does not actually need to suspend. This is the foundation of their 100% deterministic testing story in TCA2.

The key mechanism: when a closure is `@Sendable`, the compiler must assume it crosses isolation domains, forcing an `await` at every call site even when the closure runs synchronously on the same actor. With `nonisolated(nonsending)`, the closure inherits the caller's isolation context. If the caller is `@MainActor`, the closure executes on `@MainActor` without hopping. If the closure body is synchronous, no suspension point is needed at all.

Our ecosystem uses `@Sendable` pervasively across both `swift-async-primitives` (Layer 1) and `swift-async` (Layer 3). Many of these sites are stream operator closures and callback wrappers where isolation propagation would be beneficial.

## Question

Where in the Swift Institute async ecosystem can `@Sendable` be replaced with or supplemented by `nonisolated(nonsending)` to preserve isolation propagation?

## Analysis

### Inventory

#### Package: swift-async-primitives (Layer 1)

| # | File | Line | Type | Signature |
|---|------|------|------|-----------|
| P1 | Async.Callback.swift | 65 | Stored closure (struct field) | `run: @Sendable (@escaping @Sendable (Value) -> Void) -> Void` |
| P2 | Async.Callback.swift | 71 | Init parameter | `init(run: @escaping @Sendable (_ callback: @escaping @Sendable (Value) -> Void) -> Void)` |
| P3 | Async.Callback.swift | 92 | Method parameter | `map(_ transform: @escaping @Sendable (Value) -> NewValue)` |
| P4 | Async.Callback.swift | 131 | Static method parameter | `async(_ operation: @escaping @Sendable () async -> Value)` |
| P5 | Async.Callback.swift | 155 | Method parameter | `flatMap(_ transform: @escaping @Sendable (Value) -> Async.Callback<NewValue>)` |
| P6 | Async.Continuation.swift | 40 | Enum associated value | `case callback(@Sendable (T) -> Void)` |
| P7 | Async.Continuation.swift | 54 | Init parameter | `init(_ callback: @escaping @Sendable (T) -> Void)` |
| P8 | Async.Continuation.swift | 87 | Stored closure (embedded) | `let callback: @Sendable (T) -> Void` |
| P9 | Async.Continuation.swift | 91 | Init parameter (embedded) | `init(_ callback: @escaping @Sendable (T) -> Void)` |
| P10 | Async.Waiter.Resumption.swift | 51 | Stored closure | `let _resume: @Sendable () -> Void` |
| P11 | Async.Waiter.Resumption.swift | 58 | Init parameter | `init(_ action: @escaping @Sendable () -> Void)` |
| P12 | Async.Promise.swift | 106 | Method parameter | `wait(_ callback: @escaping @Sendable (Value) -> Void)` |
| P13 | Async.Promise.swift | 212 | Method parameter (Void) | `wait(_ callback: @escaping @Sendable () -> Void)` |
| P14 | Async.Barrier.swift | 89 | Method parameter | `arrive(_ callback: @escaping @Sendable () -> Void)` |

#### Package: swift-async (Layer 3) -- Core Types

| # | File | Line | Type | Signature |
|---|------|------|------|-----------|
| S1 | Async.Stream.swift | 54 | Stored closure (struct field) | `_makeIterator: @Sendable () -> Iterator` |
| S2 | Async.Stream.swift | 63 | Init parameter | `init(_ makeIterator: @escaping @Sendable () -> Iterator)` |
| S3 | Async.Stream.Iterator.swift | 20 | Stored closure (struct field) | `_next: @Sendable () async -> Element?` |
| S4 | Async.Stream.Iterator.swift | 26 | Init parameter | `init(_ next: @escaping @Sendable () async -> Element?)` |

#### Package: swift-async (Layer 3) -- Stream Operators (User-Facing Closures)

| # | File | Line | Operator | Signature |
|---|------|------|----------|-----------|
| S5 | Async.Stream.Scan.State.swift | 68 | scan | `_ accumulator: @escaping @Sendable (Result, Element) -> Result` |
| S6 | Async.Stream.Scan.State.swift | 92 | map (sync) | `_ transform: @escaping @Sendable (Element) -> U` |
| S7 | Async.Stream.Scan.State.swift | 113 | map (async) | `_ transform: @escaping @Sendable (Element) async -> U` |
| S8 | Async.Stream.Scan.State.swift | 134 | filter (sync) | `_ predicate: @escaping @Sendable (Element) -> Bool` |
| S9 | Async.Stream.Scan.State.swift | 154 | filter (async) | `_ predicate: @escaping @Sendable (Element) async -> Bool` |
| S10 | Async.Stream.Scan.State.swift | 179 | compactMap (sync) | `_ transform: @escaping @Sendable (Element) -> U?` |
| S11 | Async.Stream.Scan.State.swift | 199 | compactMap (async) | `_ transform: @escaping @Sendable (Element) async -> U?` |
| S12 | Async.Stream.Scan.State.swift | 227 | reduce | `_ accumulator: @escaping @Sendable (Result, Element) -> Result` |
| S13 | Async.Stream.FlatMap.State.swift | 28 | flatMap (sync, stored) | `transform: @Sendable (Element) -> _Async.Stream<U>` |
| S14 | Async.Stream.FlatMap.State.swift | 77 | flatMap (sync, param) | `_ transform: @escaping @Sendable (Element) -> Async.Stream<U>` |
| S15 | Async.Stream.FlatMap.State.Async.swift | 23 | flatMap (async, stored) | `transform: @Sendable (Element) async -> _Async.Stream<U>` |
| S16 | Async.Stream.FlatMap.State.Async.swift | 65 | flatMap (async, param) | `_ transform: @escaping @Sendable (Element) async -> Async.Stream<U>` |
| S17 | Async.Stream.FlatMap.Latest.State.swift | 28 | flatMapLatest (sync, stored) | `transform: @Sendable (Element) -> _Async.Stream<U>` |
| S18 | Async.Stream.FlatMap.Latest.State.swift | 135 | flatMapLatest (sync, param) | `_ transform: @escaping @Sendable (Element) -> Async.Stream<U>` |
| S19 | Async.Stream.FlatMap.Latest.State.Async.swift | 23 | flatMapLatest (async, stored) | `transform: @Sendable (Element) async -> _Async.Stream<U>` |
| S20 | Async.Stream.FlatMap.Latest.State.Async.swift | 118 | flatMapLatest (async, param) | `_ transform: @escaping @Sendable (Element) async -> Async.Stream<U>` |
| S21 | Async.Stream.Distinct.State.swift | 28 | distinct (stored) | `areEqual: @Sendable (Element, Element) -> Bool` |
| S22 | Async.Stream.Distinct.State.swift | 86 | distinctUntilChanged | `_ areEqual: @escaping @Sendable (Element, Element) -> Bool` |
| S23 | Async.Stream.Distinct.State.swift | 106 | distinctUntilChanged by key | `by key: @escaping @Sendable (Element) -> Key` |
| S24 | Async.Stream.Distinct.State.swift | 138 | first where | `where predicate: @escaping @Sendable (Element) -> Bool` |
| S25 | Async.Stream.Last.State.swift | 82 | last where | `where predicate: @escaping @Sendable (Element) -> Bool` |
| S26 | Async.Stream.Prefix.swift | 61 | prefix while | `_ predicate: @escaping @Sendable (Element) -> Bool` |
| S27 | Async.Stream.Prefix.While.swift | 23 | prefix while (stored) | `predicate: @Sendable (Element) -> Bool` |
| S28 | Async.Stream.Drop.swift | 61 | drop while | `_ predicate: @escaping @Sendable (Element) -> Bool` |
| S29 | Async.Stream.Drop.While.swift | 23 | drop while (stored) | `predicate: @Sendable (Element) -> Bool` |
| S30 | Async.Stream.WithLatestFrom.swift | 63 | withLatestFrom transform | `_ transform: @escaping @Sendable (Element, Other) -> Result` |
| S31 | Async.Stream.Zip.swift | 75 | zip transform | `_ transform: @escaping @Sendable (Element, Other) -> Result` |
| S32 | Async.Stream.Unfold.State.swift | 27 | unfold (stored) | `nextFn: @Sendable (S) async -> (Element, S)?` |
| S33 | Async.Stream.Unfold.State.swift | 69 | unfold (param) | `_ next: @escaping @Sendable (State) async -> (Element, State)?` |
| S34 | Async.Stream.Unfold.State.swift | 101 | generate | `_ generator: @escaping @Sendable () async -> Element?` |

#### Package: swift-async (Layer 3) -- Transducer (All Three Closures)

| # | File | Line | Type | Signature |
|---|------|------|------|-----------|
| S35 | Async.Stream.Transducer.swift | 63 | Stored closure | `initial: @Sendable () -> State` |
| S36 | Async.Stream.Transducer.swift | 67 | Stored closure | `step: @Sendable (Element, inout State) -> [Output]` |
| S37 | Async.Stream.Transducer.swift | 71 | Stored closure | `complete: @Sendable (inout State) -> [Output]` |
| S38 | Async.Stream.Transducer.swift | 81-83 | Init parameters | All three transducer closures |

**Total: 14 sites in async-primitives, 38 sites in async-stream.**

### Classification Results

#### MUST STAY @Sendable

These sites genuinely cross isolation boundaries or are stored in types that are sent across isolation domains. Removing `@Sendable` would be unsound.

| Site | Reason |
|------|--------|
| **P6, P7, P8, P9** (Continuation callback) | Stored inside `Async.Continuation`, which is placed into a `[Async.Continuation]` waiter queue inside a `Mutex`. The callback is invoked after lock release by whichever task fulfills/arrives -- a different isolation domain than the one that registered the callback. This is a genuine cross-isolation boundary. |
| **P10, P11** (Waiter.Resumption) | Explicit deferred-resumption thunk. Created under lock, executed after lock release. The execution context is the fulfilling task, not the registering task. Genuine cross-isolation. |
| **P12, P13** (Promise.wait callback) | Callback stored in waiter array, invoked by `fulfill()` caller. Different task/isolation than registerer. |
| **P14** (Barrier.arrive callback) | Callback stored in waiter array, invoked by last-arriving task. Different isolation domain. |
| **S1, S2** (Stream._makeIterator) | Stored in `Sendable` struct. `Stream` itself is `Sendable`, meaning `_makeIterator` may be invoked from any isolation domain. The closure must tolerate cross-domain invocation. |
| **S3, S4** (Iterator._next) | Stored in `Sendable` struct. `Iterator` is `Sendable`, so `_next` may be called from any context. Since iterators are the fundamental consumption mechanism and streams are shared across tasks, this must remain `@Sendable`. |

#### CANDIDATE FOR NONSENDING — Async Closures (Revised Assessment)

**Original claim**: 12 sites viable for nonsending adoption.
**Revised claim**: 0 sites viable in the current `Async.Stream` architecture.

The original analysis incorrectly stated that `map(async)`, `filter(async)`, `compactMap(async)`, and `generate` closures are "stored in actor." In reality, these closures are **captured directly inside `@Sendable () async -> Element?` `_next` closures** (see `Async.Stream.Scan.State.swift` lines 112–122). A `nonisolated(nonsending)` closure **cannot** be captured in a `@Sendable` closure — the isolation context would be lost. These 4 operators (~6 sites) are therefore **not viable**.

The remaining operators (`flatMap(async)`, `flatMapLatest(async)`, `unfold`) do store closures in actors. However, even for actor-stored nonsending closures, the practical benefit is nil: the closure is invoked from within the actor's isolated context, so execution occurs on the **actor's executor**, not the caller's. The isolation propagation that makes `nonisolated(nonsending)` powerful (as demonstrated in Pointfree #355) requires the closure to execute **on the caller's executor** — which cannot happen when the call originates from a different actor.

| Site | Operator | Original Classification | Revised Status |
|------|----------|------------------------|----------------|
| **S7** | map (async) | "Stored in actor" | **NOT VIABLE** — captured directly in `@Sendable` `_next` closure, not actor-stored |
| **S9** | filter (async) | "Same pattern" | **NOT VIABLE** — same as S7 |
| **S11** | compactMap (async) | "Same pattern" | **NOT VIABLE** — same as S7 |
| **S15, S16** | flatMap (async) transform | Actor-stored | **NO PRACTICAL BENEFIT** — invoked on actor's executor, not caller's |
| **S19, S20** | flatMapLatest (async) transform | Actor-stored | **NO PRACTICAL BENEFIT** — same as S15/S16 |
| **S32, S33** | unfold next | Actor-stored | **NO PRACTICAL BENEFIT** — same as S15/S16 |
| **S34** | generate | "Captured directly" | **NOT VIABLE** — captured in `@Sendable` `_next` closure |

**Total: 0 sites viable for nonsending adoption in current architecture.**

This aligns with the stream-isolation-propagation analysis (Option D): `Async.Stream` is architecturally a concurrency boundary. The `@Sendable` `Iterator._next` closure severs caller isolation at the foundation, and actor-based state management introduces independent executor hops. The nonsending opportunity lies not in stream operators but in **dependency injection patterns** (`Async.Callback.Isolated`) and **direct async APIs** (clocks, continuations).

#### MUST STAY @Sendable — Sync Closures (nonsending NOT APPLICABLE)

These closures were originally classified as "candidate for nonsending" but have **non-async function types**. The compiler rejects `nonisolated(nonsending)` on non-async function types ("cannot use 'nonisolated(nonsending)' on non-async function type"). They must remain `@Sendable`.

| Site | Operator | Function Type |
|------|----------|---------------|
| **S5** | scan accumulator | `(Result, Element) -> Result` (sync) |
| **S6** | map (sync) | `(Element) -> U` (sync) |
| **S8** | filter (sync) | `(Element) -> Bool` (sync) |
| **S10** | compactMap (sync) | `(Element) -> U?` (sync) |
| **S12** | reduce | `(Result, Element) -> Result` (sync) |
| **S21, S22, S23** | distinctUntilChanged | `(Element, Element) -> Bool` (sync) |
| **S24** | first(where:) | `(Element) -> Bool` (sync) |
| **S25** | last(where:) | `(Element) -> Bool` (sync) |
| **S26, S27** | prefix(while:) | `(Element) -> Bool` (sync) |
| **S28, S29** | drop(while:) | `(Element) -> Bool` (sync) |
| **S30** | withLatestFrom transform | `(Element, Other) -> Result` (sync) |
| **S31** | zip transform | `(Element, Other) -> Result` (sync) |
| **S35, S36, S37, S38** | Transducer closures | All three closures are sync function types |
| **S13, S14** | flatMap (sync) transform | `(Element) -> Async.Stream<U>` (sync) |
| **S17, S18** | flatMapLatest (sync) transform | `(Element) -> Async.Stream<U>` (sync) |

**Total: ~22 sites — nonsending not applicable due to sync function types.**

#### DUAL-MODE CANDIDATE

These sites serve fundamentally different use cases depending on context, warranting both `@Sendable` and `nonisolated(nonsending)` overloads.

| Site | Type | Rationale |
|------|------|-----------|
| **P1, P2** (Callback.run) | Stored closure + init | `Callback` is used both (a) for cross-isolation handoff (wrapping OS callbacks, network completions) where `@Sendable` is correct, and (b) for same-isolation dependency injection (TCA-style) where nonsending enables synchronous execution. A nonsending variant of `Callback` would enable the Pointfree-style deterministic testing pattern. |
| **P3** (Callback.map) | Method parameter | Transform could run in either context depending on Callback usage. |
| **P4** (Callback.async) | Static method | Inherently async/cross-isolation due to `Task {}`, but a nonsending variant could use `Task { @MainActor in ... }` propagation. |
| **P5** (Callback.flatMap) | Method parameter | Same as map. |

### Impact by Type

#### Bridge

**Verdict: No @Sendable closures to audit.**

`Async.Bridge` does not use `@Sendable` closures in its API. It uses `CheckedContinuation` directly for sync-to-async handoff. The `push()` / `next()` pattern is fundamentally cross-isolation (sync producer, async consumer), but this is handled via the continuation mechanism, not user-provided closures. No action needed.

#### Channel.Bounded

**Verdict: No user-facing @Sendable closures.**

`Channel.Bounded` uses `withTaskCancellationHandler` internally, where the `onCancel` closure is implicitly `@Sendable` (required by the stdlib API). The `send()` / `receive()` methods take only `Element` values, not closures. The internal `withUnsafeContinuation` and `withTaskCancellationHandler` usage is a **language blocker** -- see below.

The `onCancel:` closure in `withTaskCancellationHandler` captures `storage` (a reference type, `@unchecked Sendable`) and accesses it under a lock. This is sound, but the `onCancel` closure is implicitly `@Sendable` by Swift's definition. No user-facing change possible here without stdlib evolution.

#### Channel.Unbounded

**Verdict: Same as Bounded.** No user-facing `@Sendable` closures. Internal `withTaskCancellationHandler` usage is a language blocker. See Channel.Bounded analysis.

#### Broadcast

**Verdict: No user-facing @Sendable closures, but internal blocker.**

`Broadcast.Subscription.AsyncIterator.next()` uses `withTaskCancellationHandler` + `withCheckedContinuation` with an `Async.Publication` for cancellation-safe token exchange. The `onCancel:` closure captures `[publication, broadcast, id]` and is implicitly `@Sendable`. This is a stdlib-level blocker. No user-facing closures to change.

#### Stream (Core)

**Verdict: Must stay @Sendable for _makeIterator and _next.**

`Async.Stream` is `Sendable` and its `_makeIterator` closure is stored as a struct field. Since streams can be passed across isolation domains, the factory must tolerate cross-domain invocation. Similarly, `Iterator` is `Sendable` with a stored `_next` closure.

However, there is a significant design opportunity: **a nonsending Stream variant** (or a `Stream.Local` / `Stream.Isolated` type) that does not require `Sendable` on its closures. This would enable isolation-preserving stream pipelines for same-context usage. This is a major design decision requiring separate analysis.

#### Stream Operators (map, filter, scan, flatMap, etc.)

**Verdict: Primary nonsending adoption opportunity.**

All stream operators store their user-provided closures either:
1. In an actor (`Scan.State`, `Distinct.State`, `FlatMap.State`, `Unfold.State`, `Prefix.While`, `Drop.While`) where they are only invoked within actor isolation.
2. Captured within the `@Sendable () async -> Element?` closure of `Iterator._next`, where they execute sequentially in a single consumer context.

**The structural problem:** Even though these closures only execute within an actor, they are *stored* inside actors whose `init` requires the closure to be `@Sendable` for it to cross into the actor's isolation domain. The actor init boundary is itself an isolation crossing.

**Path forward:** If the stream operator methods accept `nonisolated(nonsending)` closures, those closures would inherit the caller's isolation. But they would need to be stored for repeated invocation. This creates a tension:
- **Nonsending closures are not escapable by default.** They cannot be stored in properties.
- **SE-0430 / `nonisolated(nonsending)` closures with `@escaping`** -- whether this combination is supported depends on the Swift version and evolution status.

This means the operator closures face a two-part blocker:
1. The closure must be `@escaping` (stored for repeated invocation).
2. The closure must not be `@Sendable` (to preserve isolation).

Currently, `@escaping nonisolated(nonsending)` is the combination needed. Swift 6.x may or may not support this fully. This requires investigation.

#### Callback

**Verdict: Primary dual-mode candidate.**

`Async.Callback<Value>` is the type most directly analogous to Pointfree's dependency injection pattern. Its `run` closure wraps a deferred computation. Two usage patterns:

1. **Cross-isolation** (OS callbacks, network): `@Sendable` is correct. The callback may fire on any thread.
2. **Same-isolation** (dependency injection, testing): A nonsending variant would allow the callback to execute synchronously on the caller's actor, eliminating suspension.

**Recommended approach:** Introduce `Async.Callback.Isolated<Value>` or a parallel type with `nonisolated(nonsending)` closures, enabling deterministic testing without thread hops.

#### Transducer

**Verdict: Candidate for nonsending, blocked by storage.**

All three transducer closures (`initial`, `step`, `complete`) are stored in a `Sendable` struct and only invoked inside an actor (`Transducer.State.Run`). Same structural blocker as stream operators -- the closures need to be both `@escaping` (stored in struct) and nonsending (for isolation propagation).

### Swift Language Blockers

#### 1. `withTaskCancellationHandler` onCancel Requires @Sendable

**Status: NOT BLOCKED (validated by experiment).**

The `onCancel:` parameter of `withTaskCancellationHandler` remains `@Sendable` because it executes on the cancellation handler's execution context, which may differ from the caller's. This is semantically correct -- the cancellation handler genuinely runs on a different isolation domain.

However, the `operation` parameter and the function itself already have a `nonisolated(nonsending)` overload in the standard library. The operation body propagates caller isolation. This means channel internals can propagate isolation through their receive/send paths for the operation body. The `onCancel` handler correctly remains `@Sendable`.

**No Swift Evolution needed.** The existing stdlib API already supports the required pattern.

#### 2. `withCheckedContinuation` / `withUnsafeContinuation` Body

**Status: NOT BLOCKED (validated by experiment).**

Both `withCheckedContinuation` and `withUnsafeContinuation` already propagate caller isolation via `isolation: isolated (any Actor)? = #isolation`. Inside the continuation body, `MainActor.assertIsolated()` passes, confirming the body executes on the caller's isolation domain. The original analysis incorrectly characterized this as requiring evolution.

> **Update (2026-03-22)**: The stdlib has since **deprecated** the `isolation:` parameter overloads of these functions in favor of `nonisolated(nonsending)` on the function itself (see `nonsending-compiler-patterns.md`). The new primary API is `public nonisolated(nonsending) func withCheckedContinuation<T>(...) async -> sending T`. The old overloads are marked `@_disfavoredOverload @available(*, deprecated)`.

The continuation itself can still be resumed from any isolation domain (which is correct), but the *body closure* runs in the caller's context. This means code paths using continuation-based suspension do NOT lose caller isolation:
- `Async.Bridge.next()`
- `Async.Promise.value`
- `Async.Barrier.arrive()` (async)
- `Async.Broadcast.Subscription.next()`
- `Async.Channel.Bounded.Receiver.receive()`
- `Async.Channel.Unbounded.Receiver.receive()`
- `Async.Stream.never`

**No Swift Evolution needed.**

#### 3. @escaping + nonisolated(nonsending) Interaction

**Status: RESOLVED for async closures (validated by experiment). NOT APPLICABLE for sync closures.**

Stream operators store closures for repeated invocation. Experiments confirm that `@escaping nonisolated(nonsending)` works for **async** closure types. The semantics are:
- The closure captures the caller's isolation context at creation time.
- On each invocation, it runs in that captured isolation context.
- The closure can be stored in an actor property.

However, `nonisolated(nonsending)` ONLY applies to async function types. The compiler produces "cannot use 'nonisolated(nonsending)' on non-async function type" for sync closures. This means:
- **Async operator closures (map async, filter async, compactMap async, flatMap async, unfold, generate):** Unblocked. Can use `@escaping nonisolated(nonsending)`.
- **Sync operator closures (map sync, filter sync, scan, reduce, distinct, prefix while, drop while, etc.):** Cannot use nonsending. Must remain `@Sendable`.

**No Swift Evolution needed** for the async path. The sync path is a language design limitation, not a missing feature.

#### 4. Actor Init Boundary

**Status: RESOLVED for async closures (validated by experiment).**

Experiments confirm that `nonisolated(nonsending)` async closures can be passed to an actor's `init` and stored as actor-isolated properties. Tested with `NonsendingOperatorState` actor storing a `nonisolated(nonsending) (Int) async -> Int` closure. The closure is stored and invoked repeatedly within the actor's isolated `next()` method.

This resolves the original concern that closure storage in actors requires `@Sendable`. For async closures, `nonisolated(nonsending)` is sufficient.

**No workaround needed.** The pattern works directly.

#### 5. AsyncIteratorProtocol.next() Signature

**Status: Not currently a blocker but relevant.**

`AsyncIteratorProtocol.next(isolation:)` already supports isolation propagation via `#isolation`. Our channel/broadcast iterators use this correctly. This is not a blocker but is worth noting as prior art for the pattern.

#### 6. Sync Closure Limitation (NEW — discovered by experiment)

**Status: Language design constraint.**

`nonisolated(nonsending)` cannot be applied to non-async function types. The compiler rejects it with "cannot use 'nonisolated(nonsending)' on non-async function type". This is not a bug — it reflects the design of SE-0430, where nonsending semantics are tied to async function execution.

This eliminates approximately 22 of the 34 originally identified candidate sites, since those are sync closures (map, filter, scan, reduce, distinctUntilChanged, prefix while, drop while, first where, last where, zip transform, withLatestFrom transform, compactMap sync, flatMap sync transform, flatMapLatest sync transform).

## Experiment Validation

Empirical experiments were conducted in `swift-institute/Experiments/nonsending-closure-type-constraints/` (B1: closure storage and sync restriction) and `swift-institute/Experiments/nonescapable-closure-storage/` (~Escapable edge cases) to validate the blocker analysis above. The results significantly revise the original assessment.

### Critical Discovery: nonsending Only Applies to Async Function Types

**The compiler produces: "cannot use 'nonisolated(nonsending)' on non-async function type".**

This means `nonisolated(nonsending)` is ONLY applicable to `async` closure parameters. The 34 "candidate for nonsending" sites from the original analysis must be reclassified:

- **Sync closures (~22 sites) — NOT APPLICABLE:** map (sync), filter (sync), compactMap (sync), scan, distinctUntilChanged, prefix(while:), drop(while:), reduce, first(where:), last(where:), zip transform, withLatestFrom transform, flatMap (sync) transform, flatMapLatest (sync) transform. These closures have non-async function types. The `nonisolated(nonsending)` attribute cannot be applied to them. They must remain `@Sendable`.
- **Async closures (~12 sites) — VIABLE CANDIDATES:** map (async), filter (async), compactMap (async), flatMap (async, all 4 stored+param variants), flatMapLatest (async, all 4 stored+param variants), unfold, generate. These have async function types and are valid candidates for `nonisolated(nonsending)`.

### Blocker B1: @escaping + nonisolated(nonsending) — RESOLVED

**Original claim:** Unclear whether `@escaping nonisolated(nonsending)` closures can be stored.

**Experiment result:** CONFIRMED WORKING. `@escaping nonisolated(nonsending)` async closures CAN be stored in structs and actors. Tested with `NonsendingOperatorState` actor storing a `nonisolated(nonsending) (Int) async -> Int` closure in its init. The closure is stored as an actor property and invoked repeatedly within the actor's isolated `next()` method.

### Blocker B2: withCheckedContinuation / withUnsafeContinuation — NOT BLOCKED

**Original claim:** The body of `withCheckedContinuation` is `@Sendable`, blocking isolation propagation.

**Experiment result:** NOT BLOCKED. `withCheckedContinuation` and `withUnsafeContinuation` already propagate caller isolation. Inside the continuation body, `MainActor.assertIsolated()` passes, confirming the body executes on the caller's isolation domain. The original analysis incorrectly characterized this as a blocker.

> **Update (2026-03-22)**: The stdlib has since deprecated the `isolation:` parameter overloads, replacing them with `nonisolated(nonsending)` on the function itself (see `nonsending-compiler-patterns.md`).

### Blocker B3: withTaskCancellationHandler — NOT BLOCKED

**Original claim:** No `nonisolated(nonsending)` variant exists, blocking Channel and Broadcast internals.

**Experiment result:** NOT BLOCKED. `withTaskCancellationHandler` already has a fully `nonisolated(nonsending)` overload in the standard library. Both the function itself and its `operation` parameter are `nonisolated(nonsending)`. The `onCancel` closure remains `@Sendable` (semantically correct — cancellation handlers run on a different context), but the operation body propagates isolation.

### Blocker B4: Actor Init Boundary — RESOLVED

**Original claim:** Closures stored in actors must be `@Sendable` to cross the init boundary.

**Experiment result:** RESOLVED for async closures. Nonsending async closures can cross into actor init. Tested with an actor storing a `nonisolated(nonsending) (Int) async -> Int` closure passed through its initializer. The compiler accepts this for async function types.

### Summary Table

| Blocker | Original Status | Experiment Result | Impact |
|---------|----------------|-------------------|--------|
| B1: @escaping + nonsending | Needs investigation | RESOLVED — works for async closures | Unblocks actor-stored patterns (not stream operators — see v1.2.0 correction) |
| B2: withCheckedContinuation | Blocker | NOT BLOCKED — already propagates isolation | No action needed |
| B3: withTaskCancellationHandler | Blocker (evolution needed) | NOT BLOCKED — nonsending overload exists | No action needed |
| B4: Actor init boundary | Design consideration | RESOLVED — async closures cross init boundary | Unblocks actor storage pattern |
| Sync closure limitation | Not previously identified | DISCOVERED — nonsending only applies to async types | Eliminates ~22 of 34 candidate sites |
| **@Sendable _next capture** | **Not previously identified** | **DISCOVERED (v1.2.0)** — closures captured in `@Sendable` `_next` cannot be nonsending | **Eliminates map/filter/compactMap/generate (6 sites)** |
| **Actor executor** | **Not previously identified** | **DISCOVERED (v1.2.0)** — actor-stored nonsending closures still execute on actor's executor, not caller's | **Eliminates practical benefit for flatMap/unfold (6 sites)** |

## Outcome

**Status**: CORRECTED (v1.2.0 — stream operator nonsending overloads not viable)

### Summary of Findings

1. **52 total `@Sendable` sites** inventoried across both packages (14 in primitives, 38 in stream).

2. **Final classification breakdown (post-experiment, post-architecture review):**
   - **Must stay @Sendable — cross-isolation (12 sites):** Continuation callbacks, Waiter.Resumption, Promise/Barrier callbacks, Stream._makeIterator, Iterator._next. These genuinely cross isolation boundaries.
   - **Must stay @Sendable — sync function types (22 sites):** map sync, filter sync, compactMap sync, scan, reduce, distinctUntilChanged, prefix while, drop while, first where, last where, zip transform, withLatestFrom transform, transducer closures, flatMap sync transform, flatMapLatest sync transform. These have non-async function types and `nonisolated(nonsending)` cannot be applied.
   - **Must stay @Sendable — async closures captured in @Sendable (6 sites):** map async, filter async, compactMap async, generate. These have async function types but are captured directly inside `@Sendable () async -> Element?` `_next` closures — a nonsending closure cannot be captured in a `@Sendable` closure.
   - **No practical benefit from nonsending (6 sites):** flatMap async (4 sites), flatMapLatest async, unfold. These are stored in actors and could technically accept nonsending closures, but execution occurs on the actor's executor regardless. The isolation propagation benefit that makes nonsending powerful (Pointfree #355 pattern) requires execution on the **caller's** executor, which cannot happen when the invocation originates from a different actor.
   - **Dual-mode candidate — PRIMARY OPPORTUNITY (6 sites):** Callback.run, Callback.init, Callback.map, Callback.async, Callback.flatMap. These serve both cross-isolation and same-isolation use cases. A nonsending variant (`Async.Callback.Isolated`) directly enables the Pointfree-style deterministic testing pattern.

3. **Language blockers — revised status:**
   - ~~No `nonisolated(nonsending)` variant of `withCheckedContinuation` / `withUnsafeContinuation`~~ — **NOT BLOCKED.** Already propagates isolation via `#isolation`.
   - ~~No `nonisolated(nonsending)` variant of `withTaskCancellationHandler`~~ — **NOT BLOCKED.** Nonsending overload already exists in stdlib.
   - ~~Unclear status of `@escaping nonisolated(nonsending)` closure semantics~~ — **RESOLVED.** Works for async closures.
   - ~~Actor init boundary forces `@Sendable` for stored closures~~ — **RESOLVED.** Nonsending async closures cross actor init boundary.
   - **`nonisolated(nonsending)` only applies to async function types.** This is a language design constraint, eliminating ~22 sync closure sites.
   - **NEW (v1.2.0): `@Sendable` `_next` capture blocks nonsending for simple operators.** `map(async)`, `filter(async)`, `compactMap(async)`, and `generate` capture their transform/predicate/generator directly inside the `@Sendable () async -> Element?` `_next` closure. A nonsending closure cannot be captured in a `@Sendable` closure.
   - **NEW (v1.2.0): Actor-stored nonsending closures provide no practical isolation benefit.** Even where storage is technically possible (flatMap, unfold), the closure executes on the actor's executor, not the caller's.

4. **Largest impact opportunity (final):** `Async.Callback.Isolated` — a nonsending variant of `Callback` that enables synchronous execution from the caller's isolation domain. This is the Pointfree #355 pattern: dependency closures that preserve caller isolation, enabling deterministic testing without thread hops.

5. **Secondary opportunities (non-stream):**
   - `@concurrent` expansion: explicitly mark async functions that genuinely need cross-isolation execution (IO event loops, thread pool dispatch, blocking work)
   - `sending` expansion: more actor boundary handoff annotations
   - `NonisolatedNonsendingByDefault` is already enabled ecosystem-wide — audit for redundant `@Sendable` annotations on async function parameters

### Recommended Next Steps

1. **Prototype `Async.Callback.Isolated`** (or parameterized isolation) as a nonsending variant of `Callback`. Verify that it enables synchronous execution from `@MainActor` callers. This directly enables the Pointfree-style deterministic testing pattern and is the highest-impact opportunity.

2. **Audit for `@concurrent` expansion.** With `NonisolatedNonsendingByDefault` enabled, nonisolated async functions now default to nonsending (inheriting caller isolation). Functions that genuinely need cross-isolation execution should be explicitly marked `@concurrent` for clarity and correctness. Candidates: IO event loop run methods, thread pool dispatch, blocking I/O wrappers.

3. **Audit for `sending` expansion.** Add `sending` annotations on actor method parameters and returns at isolation boundary crossings. The stream actor state methods already use this pattern; extend to other actor boundaries.

4. **Do not change existing `@Sendable` stream operator signatures.** The stream architecture is fundamentally a concurrency boundary (documented in `stream-isolation-propagation.md` Option D). All stream operator closures must remain `@Sendable`.

5. **Accept sync closures as permanently @Sendable.** The 22 sync operator closures cannot use `nonisolated(nonsending)` — language design constraint, not a temporary limitation.

6. **~~Add nonsending overloads for async stream operators~~** — **WITHDRAWN (v1.2.0).** Not viable due to `@Sendable` `_next` capture and actor executor semantics.

## References

- Pointfree #355: Beyond Basics: Isolation, ~Copyable, ~Escapable (Feb 23, 2026)
- SE-0430: `nonisolated(nonsending)` as default for function types
- Swift Concurrency: Sendable and actor isolation model
- `/Users/coen/Developer/swift-primitives/swift-async-primitives/Sources/Async Primitives/` (14 @Sendable sites)
- `/Users/coen/Developer/swift-foundations/swift-async/Sources/Async Stream/` (38 @Sendable sites)
- `swift-institute/Experiments/nonsending-closure-type-constraints/` — closure type applicability (B1a, B1b, B1d)
- `swift-institute/Experiments/stdlib-concurrency-isolation/` — continuation and cancellation handler isolation (B2, B3)
- `swift-institute/Experiments/nonsending-clock-feasibility/` — NonsendingClock protocol (B5)
- `swift-institute/Experiments/nonescapable-closure-storage/` — ~Escapable closure storage (B4a, B4b)
