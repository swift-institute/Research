# TCA26 Isolation Patterns Investigation

<!--
---
version: 1.0.0
last_updated: 2026-04-02
status: RECOMMENDATION
tier: 2
---
-->

## Context

TCA26 (ComposableArchitecture 2.0) is Point-Free's ground-up rewrite of The Composable Architecture, targeting Swift 6.2 with strict concurrency. The rewrite replaces the reducer-based architecture with a macro-driven `@Feature` system, replaces `Effect` with direct `store.addTask`, and fundamentally rethinks how isolation flows through a feature tree.

swift-io is undergoing its own architectural redesign — the Completion Queue ownership collapse removes the Runtime actor and consolidates lifecycle authority onto the poll thread. The question is: what isolation patterns from TCA26 are applicable to swift-io, and what would a ground-up rebuild informed by TCA26 look like?

**Trigger**: Proactive cross-ecosystem investigation. TCA26 represents the state of the art in Swift 6 isolation-first architecture from the team (Point-Free) that has driven much of the ecosystem's concurrency thinking.

**Prior art in our corpus**: `non-sendable-strategy-isolation-design.md` noted "TCA2 uses identical pattern — non-Sendable Client struct with isolation inheritance via `nonisolated(nonsending)` closures." This investigation goes deeper into TCA26's full architecture.

## Question

What isolation, ownership, and concurrency patterns does TCA26 employ, and which are applicable to swift-io's architecture — either as incremental improvements or as principles for a ground-up rebuild?

## Analysis

### TCA26 Architecture Summary

**Package**: Swift 6.2, `.v6` language mode, 52 source files in `ComposableArchitecture2`.

**Core types**:
- `Store<State, Action>`: `@MainActor final class`, `Observable` — the SwiftUI surface
- `StoreActor<State, Action>`: `actor` with pluggable isolation (`any Actor`) — the custom-isolation surface
- `_Core<State, Action>`: Protocol (`AnyObject, SendableMetatype`) — the shared runtime underneath both
- `RootCore`, `ScopedCore`, `SpawnedCore`, `IfLetCore`, `ForEachElementCore`: Concrete core implementations

**Key architectural property**: State and Action have **zero Sendable constraint**. Isolation is provided by the core's `isolation: (any Actor)?` field, inherited by all child cores.

---

### Pattern 1: Non-Sendable Closures for Confined Work

**TCA26 approach**: All internal closures — `postProcessingHooks: [() -> Void]`, `_QueuedTask.operation: () -> Task<Void, Never>?`, `enqueue(_ hook: @escaping () -> Void)` — are plain closures, NOT `@Sendable`. Only boundary closures (Store's `invalidate: @Sendable () -> Void`, task operations with `sending @escaping @isolated(any)`) carry Sendable annotations.

**Rationale**: Hooks and queued tasks run exclusively on the core's owning isolation domain. Making them `@Sendable` would force captured values to be Sendable, cascading viral Sendability through the entire feature tree.

**swift-io applicability**: **HIGH**. The completion queue's poll thread is a single-threaded serialization point. Operations dequeued from the submission queue and executed on the poll thread don't need `@Sendable` closures. Currently, some poll-thread-confined closures may carry unnecessary Sendable annotations. The `_QueuedTask` pattern — plain closure that returns `Task<Void, Never>?` — maps directly to the poll thread's dequeue-execute-collect cycle.

**Recommendation**: Audit poll-thread-confined closures in IO Completions for unnecessary `@Sendable`. Closures that are enqueued to the submission queue and only ever executed on the poll thread should be plain `@escaping`.

---

### Pattern 2: Synchronous Mutation + Async Task Collection

**TCA26 approach**: `RootCore.send(_:)` is synchronous:
1. `isRoutingAction = true` (reentrancy guard)
2. `Root._routeAction(...)` — synchronously mutates state
3. `isRoutingAction = false`
4. `return runHooks().map(\.task).all` — drain hooks, collect tasks, return composite

`runHooks()` loops until both `postProcessingHooks` and `taskQueue` are empty (allowing re-entrant enqueuing), collects all returned tasks, and the caller awaits them via `[Task].all`.

**Rationale**: State mutation is always synchronous and serialized. Async effects are collected and returned as tasks for the caller to manage. This cleanly separates "what changed" from "what to do next."

**swift-io applicability**: **MEDIUM**. The poll thread's dequeue-register-poll-resolve cycle already has this shape. The insight is the explicit two-phase draining with re-entrant support — currently, the poll loop processes submissions and completions in separate passes. A unified `runHooks()`-style drain that loops until stable could simplify the interaction between dequeue, cancellation scanning, and completion matching.

---

### Pattern 3: Single Core Protocol Across Isolation Surfaces

**TCA26 approach**: `_Core<State, Action>` is the only protocol. `Store` (`@MainActor`) and `StoreActor` (custom actor) both wrap the same `_Core` instance. The core doesn't know or care which isolation surface wraps it — it exposes `isolation: (any Actor)?` and the surface provides it.

```swift
// Store (SwiftUI)
@MainActor public final class Store<State, Action>: Observable {
    let core: any _Core<State, Action>
}

// StoreActor (custom isolation)  
public actor StoreActor<State, Action> {
    private let core: any _Core<State, Action>
    private let isolation: any Actor
}
```

**Rationale**: Separation of isolation policy from runtime mechanics. The core manages state, children, hooks, and tasks. The surface provides isolation.

**swift-io applicability**: **HIGH — for a ground-up rebuild**. swift-io has three subsystems with different isolation models:
- Events Selector: actor (`Runtime`) with custom executor
- Completions: poll-thread authority (no actor)
- Blocking Threads: Mutex-protected state

A shared `Runtime` protocol abstracting over state management, lifecycle hooks, and task tracking — with subsystem-specific isolation surfaces — would reduce duplication and enforce consistent lifecycle semantics. The poll thread becomes one isolation surface; the Events actor becomes another; the Mutex-locked thread pool becomes a third. All share the same lifecycle protocol.

---

### Pattern 4: `nonisolated(nonsending)` on Public API Methods

**TCA26 approach**: `StoreTaskID.callAsFunction()`, `TestHost.receive()`, and `TestHost.dismount()` use `nonisolated(nonsending)`. This allows calling from any isolation domain without forcing callers onto a specific actor.

```swift
nonisolated(nonsending) public func callAsFunction() async where Failure == Never {
    switch storage.state {
    case .task(let task):
        defer { storage.state = nil }
        await task.value
    case .unsafeTask, nil:
        return
    }
}
```

In the deprecated CA1 `Effect.Send`, three overloads of `callAsFunction` are `nonisolated(nonsending)`, enabling `await send(.action)` from any isolation context.

**swift-io applicability**: **HIGH**. swift-io's public API methods — `Channel.read()`, `Channel.write()`, `Channel.connect()`, `Channel.accept()` — should be callable from any isolation domain. With `NonisolatedNonsendingByDefault` already enabled, these methods already inherit caller isolation. But explicit `nonisolated(nonsending)` annotation on key API entry points improves readability and signals intent (per existing research finding: 16 bare closure parameters need explicit annotation).

---

### Pattern 5: `sending @escaping @isolated(any)` + `@_inheritActorContext(always)` for Tasks

**TCA26 approach**: `Task.immediateIfAvailable` combines four attributes:

```swift
@_implicitSelfCapture @_inheritActorContext(always)
operation: sending @escaping @isolated(any) () async -> Success
```

- `sending`: allows non-Sendable captures from current context
- `@escaping @isolated(any)`: closure can run on any actor
- `@_inheritActorContext(always)`: inherits current actor even though `@isolated(any)`
- `@_implicitSelfCapture`: captures `self` without explicit `self.`

This is also used in `withStoreTaskCancellation`:

```swift
nonisolated(nonsending)
public func withStoreTaskCancellation(
    id: StoreTaskID<Never>,
    @_implicitSelfCapture @_inheritActorContext(always)
    body: sending @escaping @isolated(any) () async -> Void
) async
```

**swift-io applicability**: **MEDIUM**. The `sending @isolated(any)` pattern could simplify cross-isolation task spawning in the executor layer. Currently, swift-io uses `Ownership.Transfer.Cell` to move ~Copyable contexts to spawned threads. For non-~Copyable but non-Sendable contexts, `sending @isolated(any)` is cleaner. However, swift-io's thread spawning (POSIX threads, not Task) limits applicability.

---

### Pattern 6: `nonisolated(unsafe)` + Weak References for Observation

**TCA26 approach**: `withObservationTracking`'s `onChange` closure is `@Sendable`. To capture core references:

```swift
nonisolated(unsafe) let unsafeFeature = feature
weak nonisolated(unsafe) let unsafeCore = self
weak nonisolated(unsafe) let unsafeStorage = storage

return withObservationTracking {
    apply()
} onChange: {
    unsafeCore?.enqueue { /* remount */ }
}
```

**Rationale**: The weak reference + nil check makes this safe. The enqueued work runs on the core's owning isolation domain. `nonisolated(unsafe)` is the escape hatch for the closure boundary.

**swift-io applicability**: **LOW directly, but pattern is validated**. swift-io already uses `nonisolated(unsafe)` in specific places. The TCA26 usage confirms the pattern is production-grade for cases where closures cross `@Sendable` boundaries but captured references are weak or known-safe.

---

### Pattern 7: `LockIsolated` with `inout sending` Return

**TCA26 approach**:

```swift
package final class LockIsolated<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()
    
    package func withLock<R, F: Error>(
        _ operation: (inout sending Value) throws(F) -> sending R
    ) throws(F) -> sending R
}
```

Both the `inout` parameter and return value are `sending`, enforcing exclusive ownership transfer across the lock boundary.

**swift-io applicability**: **MEDIUM**. swift-io uses `Ownership.Slot` to transfer ~Copyable values across Mutex.withLock boundaries. The `inout sending` pattern is cleaner for non-~Copyable values. However, for ~Copyable values (which swift-io heavily uses), the Slot pattern remains necessary due to region-checker limitations documented in experiment `sending-mutex-noncopyable-region` (V2/V4: inout captures of non-Sendable variables merge regions).

---

### Pattern 8: UnsafeMutablePointer State Storage

**TCA26 approach**: Both `RootCore` and `SpawnedCore` store state via raw pointer allocation:

```swift
private let statePointer: UnsafeMutablePointer<Root.State>

init(initialState: Root.State, feature: Root) {
    self.statePointer = .allocate(capacity: 1)
    self.statePointer.initialize(to: initialState)
}

var state: Root.State {
    unsafeAddress { UnsafePointer(statePointer) }
    unsafeMutableAddress { statePointer }
}

deinit {
    statePointer.deinitialize(count: 1)
    statePointer.deallocate()
}
```

**Rationale**: Enables stable pointer identity for scoped access via `WritableKeyPath<BaseState, ChildState>`. Child cores reach into parent state without copying. `unsafeMutableAddress` provides direct pointer-level access for `inout` semantics.

**swift-io applicability**: **ALREADY USED**. swift-io uses `UnsafeMutablePointer` for completion operation storage, buffer management, and driver handles. The pattern is validated by TCA26 in a high-level framework context, confirming it's not just an I/O concern but a general Swift architecture pattern for performance-critical state management.

---

### Pattern 9: Conservative Advanced Type System Usage

**TCA26 does NOT use**:
- `~Escapable`
- `consuming` / `borrowing` parameter annotations
- `@_lifetime`
- `@_rawLayout`
- `InlineArray`

**TCA26 uses minimally**:
- `~Copyable` — only in `withState<R: ~Copyable>(_ body: (inout State) -> R) -> R` return type
- `sending` — on keypaths, lock operations, and task closures
- `nonisolated(nonsending)` — on 6 methods across 4 files

**swift-io comparison**: swift-io is significantly MORE advanced in ownership features:
- 10+ `~Copyable` types (Submission, Entry, Driver.Handle, Channel, Job.Instance, etc.)
- `~Escapable` (IO.Lane.Scope)
- `@_lifetime(immortal)`
- `consuming func resolve()` for single-commit enforcement
- `Ownership.Transfer.Cell`, `Ownership.Slot` patterns

**Implication**: TCA26 validates that a sophisticated concurrent system CAN be built with minimal advanced type features. But swift-io's domain (I/O resources, file descriptors, memory buffers, poll-thread confinement) genuinely benefits from ~Copyable and ~Escapable. TCA26's conservatism is appropriate for its domain — UI state doesn't need move-only semantics. swift-io should not regress on ownership features.

---

### Pattern 10: Feature Tree = Routing Tree (Structural Composition)

**TCA26 approach**: Features compose by nesting. The `@Feature` macro generates `_routeAction` implementations that route actions down the tree. No explicit reducer composition algebra is needed.

```
store.send(.home(.incrementTapped))
  → RootCore.send(...)
    → Root._routeAction(...)
      → Scope._routeAction(...)  // extracts child action via CaseKeyPath
        → Home._routeAction(...)
          → Update._routeAction(...)
            → storage.feature.update(&state, action)  // terminal mutation
```

**swift-io applicability**: **LOW directly**. I/O systems don't have hierarchical state trees. However, the principle — *structure implies behavior, routing follows composition* — could inform how swift-io organizes subsystem interactions. Currently, Events Selector → Completions → Executor have explicit wiring. A more structural approach where subsystem composition implies event routing could reduce boilerplate.

---

## Comparison Matrix

| Dimension | TCA26 | swift-io | Gap |
|-----------|-------|----------|-----|
| **State Sendable constraint** | None | None (NonisolatedNonsendingByDefault) | Parity |
| **Internal closure Sendability** | Plain `() -> Void` | Mixed (`@Sendable` on some poll-thread closures) | swift-io can simplify |
| **Isolation model** | `isolation: (any Actor)?` threaded through core hierarchy | Hybrid: actor (Events), poll thread (Completions), Mutex (Blocking) | TCA26 more unified |
| **Runtime protocol** | Single `_Core` across all surfaces | No shared runtime protocol | swift-io could benefit |
| **Public API isolation** | `nonisolated(nonsending)` on key methods | NonisolatedNonsendingByDefault enabled | Parity (add explicit annotations) |
| **Task creation** | `sending @isolated(any) @_inheritActorContext` | `Ownership.Transfer.Cell` for thread spawn | Different domains |
| **~Copyable** | Minimal (return type only) | Extensive (10+ types) | swift-io more advanced |
| **~Escapable** | Not used | Used (Lane.Scope) | swift-io more advanced |
| **State storage** | UnsafeMutablePointer with manual lifecycle | UnsafeMutablePointer for buffers/storage | Parity |
| **Lock pattern** | `LockIsolated` with `inout sending` | `Mutex` + `Ownership.Slot` | Both valid; different constraints |
| **@unchecked Sendable** | 7 types, documented | 16 types, safety-invariant documented | swift-io could reduce count |
| **Typed throws** | Used throughout | Used throughout | Parity |
| **Error handling** | Never on features, typed on tasks | Typed `IO.Error<E>`, `IO.Lifecycle.Error<E>` | Parity |

## Outcome

**Status**: RECOMMENDATION

### Findings

TCA26 demonstrates three principles applicable to swift-io:

**F1: Isolation unification via protocol abstraction.** TCA26's single `_Core` protocol serving both `@MainActor Store` and `actor StoreActor` is its strongest architectural contribution. swift-io's three subsystems (Events, Completions, Blocking) each implement their own lifecycle, state management, and task tracking. A shared `Runtime` protocol — abstracting entry tables, lifecycle hooks, and task collection — would reduce duplication while preserving subsystem-specific isolation surfaces.

**F2: Non-Sendable closures for confined work.** TCA26 proves that closures running exclusively on a single isolation domain don't need `@Sendable`. The poll thread is the canonical example. Unnecessary `@Sendable` annotations on poll-thread-confined closures force Sendable cascading onto captured values, adding complexity without safety benefit.

**F3: Synchronous mutation with async task collection.** TCA26's `send() → runHooks() → [Task].all` pattern cleanly separates the synchronous state transition from the asynchronous effects. The poll thread's dequeue-register-poll-resolve cycle shares this shape and could benefit from the explicit two-phase drain with re-entrant support.

### What NOT to adopt from TCA26

**N1: Conservative ownership.** TCA26's avoidance of `~Escapable`, `consuming`, `borrowing` is domain-appropriate for UI but would be a regression for I/O. File descriptors, memory buffers, and poll-thread entries genuinely benefit from compile-time ownership enforcement.

**N2: Feature composition model.** The `@Feature` macro, `FeatureBuilder`, and tree-structured routing are UI patterns. I/O subsystem composition has different constraints (latency, thread affinity, zero-allocation paths).

**N3: `nonisolated(unsafe)` as primary escape hatch.** TCA26 uses 11+ `nonisolated(unsafe)` sites. swift-io's ownership-first approach (Slot, Transfer.Cell, consuming functions) is stronger — it encodes safety in the type system rather than relying on programmer discipline.

### Recommendations for swift-io

**R1 (Incremental)**: Audit completion queue poll-thread closures for unnecessary `@Sendable`. Closures enqueued to the submission queue and executed exclusively on the poll thread should be plain `@escaping`.

**R2 (Incremental)**: Add explicit `nonisolated(nonsending)` annotations to the 16 identified bare closure parameters (from `ownership-transfer-conventions.md` migration surface).

**R3 (Architectural — ground-up rebuild)**: Design a shared `Runtime` protocol abstracting:
- Entry/registration table management
- Lifecycle hooks (mount, dismount, state change)
- Task collection and cancellation
- `isolation` surface binding

Each subsystem (Events, Completions, Blocking) provides a concrete runtime; the isolation surface (actor, poll thread, Mutex) is plugged in separately.

**R4 (Architectural — ground-up rebuild)**: Adopt the two-phase drain pattern for the poll thread: loop `{ drain hooks; drain task queue }` until stable, collecting all spawned tasks. This naturally handles re-entrant enqueuing from completion handlers that trigger new submissions.

**R5 (Preserve)**: Keep and extend ~Copyable and ~Escapable usage. TCA26's conservatism is domain-appropriate for UI; swift-io's advanced ownership is domain-appropriate for I/O. The Entry `~Copyable + ~Escapable` design (from completion-queue-ownership-redesign) is correct.

## References

- TCA26 source: `/Users/coen/Developer/pointfreeco/TCA26`
- Completion Queue redesign: `swift-io/Research/completion-queue-ownership-redesign.md`
- Ownership transfer conventions: `swift-institute/Research/ownership-transfer-conventions.md`
- Modern concurrency conventions: `swift-institute/Research/modern-concurrency-conventions.md`
- Non-sendable strategy design: `swift-institute/Research/non-sendable-strategy-isolation-design.md`
- Sending-mutex experiment: `swift-institute/Experiments/sending-mutex-noncopyable-region/`
- Nonsending dispatch experiment: `swift-institute/Experiments/nonsending-dispatch/`
