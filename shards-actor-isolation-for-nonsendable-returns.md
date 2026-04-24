# Shards Actor Isolation for Non-Sendable Returns

<!--
---
version: 1.0.0
last_updated: 2026-04-03
status: DECISION
tier: 1
---
-->

## Context

The `sending`-over-`Sendable` migration removed `T: Sendable` from all blocking `run` return types and from `Registry.transaction`/`Registry.handle` (actor-isolated methods where region analysis proves T is disconnected). Two sites remain:

```swift
// IO.Executor.Shards.swift:167,181
internal func transaction<T: Sendable, E: Swift.Error & Sendable>(...) -> T
internal func handle<T: Sendable, E: Swift.Error & Sendable>(...) -> T
```

The TODO comments say "revisit when Shards can be actor-isolated." This research evaluates whether actor isolation on Shards would actually solve the problem.

**Trigger**: TODO comment from sending-over-Sendable migration.

## Question

Can the remaining `T: Sendable` constraints on `Shards.transaction` and `Shards.handle` be removed by making Shards actor-isolated?

## Analysis

### The Actual Constraint

Shards is a `final class: Sendable` (nonisolated). It calls:

```swift
return try await registry(for: id.shard).transaction(id, body)
```

`Registry` is an actor. T crosses from Registry's isolation domain to Shards' nonisolated context. The compiler error:

> non-Sendable 'T'-typed result can not be returned from actor-isolated instance method to nonisolated context

### Option A: Make Shards an Actor

If Shards were an actor, `transaction` would be actor-isolated. But the call to `registry.transaction()` still crosses between **two different actors** (Shards → Registry). T would still need to cross an actor boundary on the return path. The compiler would still require T: Sendable.

**Verdict**: Does not solve the problem. The constraint exists because Registry is a *separate* actor, not because Shards is nonisolated.

### Option B: Share Isolation Between Shards and Registry

If Shards methods ran on the *same* executor as the target Registry, the call wouldn't cross an actor boundary. This could work via:

- `Registry.assumeIsolated { ... }` from within Shards — unsound unless Shards is actually on Registry's executor
- Custom executor routing: Shards dispatches each call to the target shard's executor before calling Registry

This is complex and defeats the purpose of Shards (a thin routing layer). The routing would need to hop to the correct executor per-call, which is what `await registry.transaction()` already does.

**Verdict**: Adds complexity for no benefit — the actor hop already provides the executor dispatch.

### Option C: Eliminate Registry as Actor

If Registry were not an actor (e.g., Mutex-protected state), there would be no actor boundary. T would never cross isolation domains. But Registry is an actor for good reason — it provides handle isolation with waiter queues, continuation management, and lifecycle state that benefit from actor serialization.

**Verdict**: Architecturally regressive. Registry's actor isolation is earned.

### Option D: Accept the Constraint

`T: Sendable` on Shards' two methods is the correct encoding. T crosses between two independent actors. The constraint is not an artifact of the architecture — it reflects a genuine isolation boundary. Callers of `Shards.transaction` produce T inside a `@Sendable` body closure running on the Registry actor, and T must safely return to the caller's context.

In practice, T is typically `Void` (side-effecting transactions) or a small Sendable value (read results). Non-Sendable T would only matter for returning non-Sendable resources from the actor — which would be unsound anyway, since the resource is actor-isolated.

## Outcome

**Status**: DECISION

`T: Sendable` on `Shards.transaction` and `Shards.handle` is **correct and should remain**. Making Shards an actor does not help — the constraint exists because T crosses between two independent actors (Shards' caller → Registry), regardless of whether Shards itself is an actor or a class.

Update the TODO comments to reflect this is a permanent constraint, not a deferred fix.
