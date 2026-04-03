# TCA26 Patterns: Kernel & Platform Application

<!--
---
version: 1.0.0
last_updated: 2026-04-02
status: RECOMMENDATION
tier: 2
---
-->

## Context

The prior investigation (`tca26-isolation-patterns-investigation.md`) identified 10 isolation, ownership, and concurrency patterns in TCA26 (ComposableArchitecture 2.0), with 5 recommendations targeting swift-io. This document applies those same findings to the **kernel and platform infrastructure layer** -- specifically swift-kernel, swift-kernel-primitives, and the platform packages (swift-darwin, swift-linux, swift-posix, swift-cpu-primitives, swift-darwin-primitives, swift-linux-primitives, swift-system-primitives).

These packages sit below swift-io in the dependency graph. They provide:
- OS thread lifecycle (spawn, join, detach)
- Synchronization primitives (mutex, condition variable, barrier, gate)
- Executor infrastructure (serial executor backed by OS thread)
- File descriptors and I/O operations
- Syscall normalization
- Platform-specific kernel APIs (kqueue, io_uring/epoll, NUMA)
- CPU-level atomics and barriers
- Continuation bridging (blocking-to-async)

**Trigger**: Systematic application of TCA26 findings to the next infrastructure layer down from swift-io. The kernel/platform layer is the foundation that swift-io builds on; any isolation pattern changes here propagate upward.

**Prior art**: `tca26-isolation-patterns-investigation.md` (Tier 2, RECOMMENDATION), `concurrent-expansion-audit.md` (COMPLETE), `modern-concurrency-conventions.md` (RECOMMENDATION), `tilde-sendable-semantic-inventory.md` (SUPERSEDED), `non-sendable-strategy-isolation-design.md`.

## Question

Which TCA26 isolation patterns (F1, F2, F3 and Patterns 1-10) are applicable to the kernel and platform infrastructure layer, which are already adopted, and which would require breaking changes?

## Analysis

### Package Inventory

**swift-kernel-primitives** (Layer 1, `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/`):
- 27 source target directories (Kernel Descriptor Primitives, Kernel Thread Primitives, Kernel Event Primitives, Kernel Syscall Primitives, Kernel File Primitives, etc.)
- Key types: `Kernel.Descriptor` (~Copyable, Sendable), `Kernel.File.Handle` (~Copyable, Sendable), `Kernel.Environment.Entry` (~Copyable, ~Escapable), `Kernel.Syscall.Rule<T>` (Sendable)
- C shim targets: CDarwinShim, CLinuxShim, CPosixShim, CWindowsShim
- Thread Handle, Mutex, Condition are placeholder files -- actual implementations live in platform-specific packages (swift-iso-9945, swift-windows-primitives)

**swift-kernel** (Layer 3, `/Users/coen/Developer/swift-foundations/swift-kernel/`):
- 6 targets: Kernel, Kernel Core, Kernel Continuation, Kernel File, Kernel System, Kernel Thread
- Key types: `Kernel.Thread.Executor` (@unchecked Sendable), `Kernel.Thread.Executors` (Sendable), `Kernel.Thread.Worker` (~Copyable, Sendable), `Kernel.Thread.Synchronization<N>` (@unchecked Sendable), `Kernel.Thread.Gate` (@unchecked Sendable), `Kernel.Thread.Barrier` (@unchecked Sendable), `Kernel.Continuation.Context` (@unchecked Sendable), `Kernel.Thread.Handle.Reference` (@unchecked Sendable)

**swift-darwin-primitives** (Layer 1, `/Users/coen/Developer/swift-primitives/swift-darwin-primitives/`):
- Targets: Darwin Kernel Primitives, Darwin Loader Primitives, Darwin Memory Primitives, Darwin Primitives
- Key types: `Kernel.Kqueue` (static syscall wrappers), `Kernel.Kqueue.Event`, `Kernel.Kqueue.Filter`

**swift-linux-primitives** (Layer 1, `/Users/coen/Developer/swift-primitives/swift-linux-primitives/`):
- Target: Linux Kernel Primitives (60+ files for io_uring)
- Key types: `Kernel.IO.Uring.*` (Submission.Queue, Completion.Queue, Params, etc.)

**swift-cpu-primitives** (Layer 1, `/Users/coen/Developer/swift-primitives/swift-cpu-primitives/`):
- Types: `CPU.Atomic` (load/store with memory ordering), `CPU.Barrier` (hardware/compiler), `CPU.Spin` (hint), `CPU.Timestamp`, `CPU.Cache.Prefetch`

**swift-darwin** / **swift-linux** / **swift-posix** (Layer 3, `/Users/coen/Developer/swift-foundations/`):
- Darwin: system info (processor count, memory, NUMA), random
- Linux: thread affinity, random, NUMA discovery
- POSIX: EINTR-safe write wrappers, glob, error messages

**swift-system-primitives** (Layer 1, `/Users/coen/Developer/swift-primitives/swift-system-primitives/`):
- Types: `System.Processor`, `System.Memory`, `System.Page`, `System.Topology.NUMA`

---

### Pattern-by-Pattern Analysis

#### F1: Isolation Unification via Protocol Abstraction

**TCA26**: Single `_Core<State, Action>` protocol serves both `@MainActor Store` and `actor StoreActor`. Isolation surface is plugged in separately.

**Kernel/platform status**: NOT APPLICABLE at the primitives layer. PARTIALLY APPLICABLE at the foundations layer.

The kernel/platform layer operates at a fundamentally different abstraction level than TCA26. There is no "isolation surface" to unify because:

1. **Primitives (L1)** are pure data types and static syscall wrappers. `Kernel.Descriptor`, `Kernel.Kqueue.Event`, `Kernel.IO.Uring.Submission.Queue.Entry` -- these are value types with no isolation model at all. They are building blocks, not runtimes.

2. **Foundations (L3)** do have runtime types (`Kernel.Thread.Executor`, `Kernel.Thread.Synchronization`), but they are *concrete* synchronization primitives, not subsystems with multiple isolation surfaces. The Executor is always a dedicated OS thread. The Synchronization is always a mutex+condvar. There is no variant where they run on MainActor or a custom actor.

**Where F1 could apply**: The `Kernel.Thread.Executor` and `Kernel.Thread.Executors` already implement the right pattern: `Executor` conforms to both `SerialExecutor` and `TaskExecutor`, and the `Mode` enum (`.serial` vs `.task`) determines which identity is reported. This is a lightweight version of TCA26's isolation surface pluggability -- the same executor supports two different runtime identities. This is **already adopted**.

A deeper application of F1 would be a shared protocol across `Gate`, `Barrier`, `SingleSync`, `DualSync`, and `Synchronization<N>`. These all share the pattern: final class, @unchecked Sendable, internal mutex+condvar, public wait/signal/broadcast. However, unifying them under a protocol provides no concrete benefit -- they have different APIs (Gate is one-shot, Barrier counts arrivals, Synchronization has N conditions) and are not interchangeable. The value of F1 is about swapping isolation surfaces, not about abstracting over synchronization primitives.

**Verdict**: Already adopted where applicable (Executor dual-mode). Not applicable at primitives layer. Forced protocol unification of sync primitives would add indirection without benefit.

---

#### F2: Non-Sendable Closures for Confined Work

**TCA26**: All internal closures are plain `() -> Void`, not `@Sendable`. Only boundary closures carry Sendable annotations.

**Kernel/platform status**: PARTIALLY ADOPTED, with justified exceptions.

**Inventory of @Sendable closures in swift-kernel**:

| Location | Signature | Genuinely Boundary-Crossing? |
|----------|-----------|------------------------------|
| `Kernel.Thread.spawn` (line 60) | `@escaping @Sendable () -> Void` | **YES** -- closure executes on a newly spawned OS thread |
| `Kernel.Thread.spawn` (line 80) | `@escaping @Sendable (consuming T) -> Void` | **YES** -- same as above, with value transfer |
| `Kernel.Thread.trap` (line 49) | `@escaping @Sendable () -> Void` | **YES** -- delegates to spawn |
| `Kernel.Thread.trap` (line 63) | `@escaping @Sendable (consuming T) -> Void` | **YES** -- delegates to spawn |
| `Kernel.Thread.Worker.start` (line 93) | `@escaping @Sendable (Token) -> Void` | **YES** -- executes on spawned thread via spawn |
| `Kernel.Continuation.Context` callback (line 58) | `@Sendable (Result<...>) -> Void` | **YES** -- invoked from any thread (complete/cancel/fail race) |
| `Kernel.Continuation.Context.init` (line 89) | `@escaping @Sendable (Result<...>) -> Void` | **YES** -- stored for cross-thread invocation |

**Inventory of non-@Sendable closures in swift-kernel**:

| Location | Signature | Why Non-Sendable? |
|----------|-----------|-------------------|
| `Synchronization.withLock` (line 68) | `() throws(E) -> T` | Runs under lock on calling thread -- never crosses threads |

**Inventory in swift-kernel-primitives**:

| Location | Signature | Genuinely Boundary-Crossing? |
|----------|-----------|------------------------------|
| `Kernel.Syscall.Rule` (line 38) | `@Sendable (T) -> Bool` | **DEBATABLE** -- Rule is `Sendable`, stored as a property, but the closure is a pure predicate that never captures mutable state |

**Analysis**: Every `@Sendable` annotation in swift-kernel is **genuinely justified**. Thread spawn closures cross OS thread boundaries by definition. Continuation callbacks race between completion/cancellation/failure paths from different threads. The `withLock` closure is correctly non-Sendable -- it runs on the calling thread while holding the lock.

The one debatable case is `Kernel.Syscall.Rule<T>`. The stored `@Sendable (T) -> Bool` closure is used as a pure predicate (e.g., `.nonNegative` = `{ $0 >= 0 }`). It never captures mutable state. The `@Sendable` annotation is not strictly necessary for thread safety -- it is present because `Rule<T>` itself is `Sendable`, and stored closures in Sendable types must be `@Sendable`. Removing it would require making `Rule` non-Sendable, which would break its use in concurrent syscall contexts.

**F2 verdict for kernel/platform**: **Already correctly adopted.** The kernel layer has the right annotations -- `@Sendable` exactly where closures cross thread boundaries (spawn, continuation callback), plain closures where they don't (withLock). There are no unnecessary `@Sendable` annotations to remove. This is tighter than TCA26's swift-io recommendations because the kernel layer has fewer closure patterns and each one has a clear thread-crossing justification.

---

#### F3: Synchronous Mutation with Async Task Collection

**TCA26**: `send()` synchronously mutates state, then `runHooks()` drains the task queue in a two-phase loop.

**Kernel/platform status**: ALREADY ADOPTED in `Kernel.Thread.Executor`.

The executor's run loop (`Kernel.Thread.Executor.runLoop()`, line 183 of `Kernel.Thread.Executor.swift`) implements exactly this pattern:

```swift
fileprivate func runLoop() {
    while true {
        let job: UnownedJob? = sync.withLock {
            while jobs.isEmpty && isRunning {
                sync.wait()          // Phase 1: wait for work
            }
            guard isRunning || !jobs.isEmpty else { return nil }
            return jobs.dequeue()    // Phase 2: dequeue synchronously under lock
        }
        guard let job else { return }
        // Phase 3: execute outside lock
        switch mode {
        case .serial:
            unsafe job.runSynchronously(on: asUnownedSerialExecutor())
        case .task:
            unsafe job.runSynchronously(on: asUnownedTaskExecutor())
        }
    }
}
```

This is a clean separation: synchronous dequeue under lock (mutation), then execution outside the lock (effect). The pattern differs from TCA26 in that it processes one job per iteration rather than draining all hooks in a batch, but this is correct for a serial executor -- jobs must run serially, and batch draining wouldn't change behavior.

The `enqueue()` method (line 143) also follows the two-phase pattern: synchronous state check under lock, then either inline execution or signal.

**Where F3 could additionally apply**: The `Kernel.Continuation.Context` uses atomic compare-exchange rather than a two-phase drain, which is appropriate for its exactly-once semantics. Gate and Barrier use mutex+condvar correctly. There is no place in the kernel layer where a batch-drain-until-stable pattern (TCA26's `runHooks()`) would improve things.

**F3 verdict**: Already adopted. The executor's run loop is the two-phase pattern. Other sync primitives use appropriate alternatives (atomics, condvar wait loops).

---

#### Pattern 1: Non-Sendable Closures for Confined Work

Same as F2. See above. **Already correctly adopted.**

---

#### Pattern 3: Single Core Protocol Across Isolation Surfaces

Same as F1. See above. **Already adopted where applicable (Executor dual-mode). Not applicable for forced sync primitive unification.**

---

#### Pattern 4: `nonisolated(nonsending)` on Public API Methods

**TCA26**: Key public API methods annotated with `nonisolated(nonsending)`.

**Kernel/platform status**: NOT USED -- but **not needed** due to design characteristics.

The kernel/platform layer has **zero `nonisolated(nonsending)` annotations** across all examined packages. The reason is structural:

1. **Primitives (L1)** are Sendable value types and static functions. `Kernel.Descriptor`, `Kernel.Syscall.Rule`, `Kernel.Kqueue.Event` -- these have no isolation to begin with. Static syscall wrappers (`Kernel.Kqueue.create()`, `Kernel.Syscall.require()`) are global functions with no isolation context to inherit.

2. **Foundations (L3)** have `@unchecked Sendable` classes with explicit thread synchronization. Their methods (`Executor.enqueue()`, `Gate.open()`, `Barrier.arrive()`) are callable from any thread because the types handle synchronization internally. They are not actor-isolated, so `nonisolated(nonsending)` would be meaningless.

3. **Thread spawn closures** are `@escaping @Sendable` by necessity (they execute on a different OS thread). `nonisolated(nonsending)` would not help here -- the closure genuinely leaves the calling isolation domain.

The `NonisolatedNonsendingByDefault` feature flag is enabled ecosystem-wide, so new async methods automatically inherit caller isolation. But the kernel layer is predominantly synchronous -- its API surface is blocking syscalls and thread lifecycle management, not async methods.

**Verdict**: Not applicable. The kernel layer's API surface is either isolated-by-construction (Sendable types with internal sync) or inherently cross-thread (spawn closures). There are no methods that would benefit from `nonisolated(nonsending)`.

---

#### Pattern 5: `sending @escaping @isolated(any)` + `@_inheritActorContext(always)`

**TCA26**: Used for task creation that inherits caller's actor context.

**Kernel/platform status**: NOT APPLICABLE.

The kernel layer creates OS threads, not Swift Tasks. Thread spawn uses `@escaping @Sendable` closures because OS threads have no actor context to inherit. The `Ownership.Transfer.Cell` pattern (`Kernel.Thread.spawn` line 83-88) handles ~Copyable value transfer across the thread boundary:

```swift
let cell = Ownership.Transfer.Cell(value)
let token = cell.token()
return try self {
    let v = token.take()
    body(v)
}
```

This is more appropriate than `sending @isolated(any)` because:
- OS threads don't participate in Swift's actor isolation model
- The cell handles ~Copyable types that `sending` cannot (region checker limitations)
- The exactly-once consumption guarantee is enforced by the cell's type system

**Where it could apply in the future**: If `Kernel.Thread.Executor` gains task-spawning convenience methods that create Swift Tasks on the dedicated thread, `sending @isolated(any)` would be appropriate there. Currently, task creation happens at the swift-io layer, not the kernel layer.

**Verdict**: Not applicable. OS thread creation requires `@Sendable`, not `sending @isolated(any)`.

---

#### Pattern 7: `LockIsolated` with `inout sending` Return

**TCA26**: `LockIsolated<Value>` uses `(inout sending Value) throws(F) -> sending R` for exclusive ownership transfer across lock boundaries.

**Kernel/platform status**: DIFFERENT PATTERN -- `Synchronization.withLock` uses plain closures.

`Kernel.Thread.Synchronization.withLock` (line 68):
```swift
public func withLock<T, E: Swift.Error>(_ body: () throws(E) -> T) throws(E) -> T {
    try mutex.withLock(body)
}
```

The closure is `() throws(E) -> T` -- no `inout sending`, no `@Sendable`. This is simpler than TCA26's `LockIsolated` because:

1. The Synchronization class protects **external** state (the Executor's `jobs` queue, `isRunning` flag), not internal `Value` storage. The locked code accesses the class's stored properties directly.
2. There is no need for ownership transfer across the lock boundary -- the protected values are `var` properties of the class, accessed in-place.
3. The closure never escapes -- it runs synchronously under the lock.

TCA26's `LockIsolated` pattern would be beneficial if the kernel layer had lock-protected values that need to be transferred out as owned values. Currently, all withLock usage returns computed results (Bool, Optional<Job>), not owned values.

**Verdict**: Different domain, different pattern. Both are correct. The kernel layer's `withLock(() -> T)` is appropriate for its use case (accessing class properties under lock). TCA26's `inout sending` pattern would be applicable if the kernel layer had lock-protected value transfer needs.

---

#### Pattern 8: UnsafeMutablePointer State Storage

**TCA26**: `RootCore` and `SpawnedCore` store state via raw pointer allocation for stable pointer identity and direct `inout` access.

**Kernel/platform status**: EXTENSIVELY USED -- the kernel layer goes much further.

**In swift-kernel-primitives**:
- `Kernel.Descriptor` stores `_raw: Raw` (Int32 or UInt, line 66) -- direct storage, not pointer-based, because descriptors are small enough for inline storage
- `Kernel.Environment.Entry` stores `_name: UnsafePointer<String.Char>` and `_value: UnsafePointer<String.Char>` (line 26-30) -- borrowed pointers into the process environment block, with `~Escapable` enforcing lifetime

**In swift-cpu-primitives**:
- `CPU.Atomic.load()` and `CPU.Atomic.store()` operate on `UnsafeMutablePointer<UInt8/UInt32/UInt64>` -- raw pointer-based atomics for shared-memory ring buffers (io_uring submission/completion queues)
- These are the kernel layer's equivalent of TCA26's `unsafeMutableAddress` -- direct pointer access for performance-critical paths, but for hardware memory ordering rather than Swift property access

**In swift-darwin-primitives**:
- `Darwin.Loader.Image.withPathBytes()` and `Darwin.Loader.Section.withDataBytes()` use scoped pointer access with `~Copyable` return types
- `Kernel.Kqueue.kevent()` passes `UnsafePointer<kevent>` and `UnsafeMutablePointer<kevent>` to the kernel syscall

**In swift-kernel (L3)**:
- `Kernel.Thread.Executor` uses `Ownership.Transfer.Retained` (line 112) to transfer `self` to the spawned thread -- a pointer-based pattern for reference type ownership transfer
- The Executor's run loop accesses `jobs: Job.Queue` and `isRunning: Bool` as stored properties, not through pointers, because they are protected by the Synchronization lock

**Comparison with TCA26**: TCA26 uses `UnsafeMutablePointer` for a specific purpose -- stable pointer identity for key-path-based scoped access. The kernel layer uses pointers for a different set of purposes: C interop (syscall buffers), shared-memory access (ring buffers), and cross-thread ownership transfer (Transfer.Cell, Transfer.Retained). Both validate the pattern, but for different reasons.

**Verdict**: Already adopted, more extensively than TCA26. The kernel layer's pointer usage is syscall-driven (C interop, shared memory) rather than Swift-ergonomics-driven (key-path access).

---

#### Pattern 9: Conservative vs Advanced Ownership

**TCA26**: Only `~Copyable` on return types. No `~Escapable`, no `consuming`/`borrowing`.

**Kernel/platform status**: SIGNIFICANTLY MORE ADVANCED -- correctly so.

**~Copyable types in the kernel layer**:

| Type | Location | Rationale |
|------|----------|-----------|
| `Kernel.Descriptor` | kernel-primitives, line 56 | File descriptor is an OS resource -- double-close is UB |
| `Kernel.File.Handle` | kernel-primitives, line 43 | Owns descriptor + Direct I/O state |
| `Kernel.Thread.Worker` | swift-kernel, line 50 | Single-owner thread lifecycle -- join exactly once |
| `Kernel.Thread.Handle` | iso-9945/windows (referenced) | OS thread handle -- join exactly once |
| `Kernel.File.Write.Streaming.Context` | swift-kernel, line 37 | Write session state -- single-owner |
| `Kernel.File.Write.Atomic.TempFile` | swift-kernel, line 208 | Private, owns descriptor |

**~Escapable types**:

| Type | Location | Rationale |
|------|----------|-----------|
| `Kernel.Environment.Entry` | kernel-primitives, line 23 | Borrows from process environment block -- must not outlive iterator |

**`consuming` usage**: `Kernel.Thread.Worker.join()` (line 131) is a consuming operation -- the worker cannot be used after join. `Kernel.Thread.Handle.joinChecked()` (line 29) is also consuming.

**`borrowing` usage**: All `Kernel.Kqueue` syscall wrappers take `_ kq: borrowing Kernel.Descriptor` -- the kqueue descriptor is borrowed, not consumed, during operations. `POSIX.Kernel.IO.Write.write(_ descriptor: borrowing Kernel.Descriptor, ...)` follows the same pattern.

This is the correct domain application. TCA26's conservatism reflects its UI domain -- State and Action are values that can be freely copied. The kernel domain has genuine move-only resources:
- File descriptors must be closed exactly once (double-close is UB per POSIX)
- Thread handles must be joined exactly once (double-join is UB on some platforms)
- Environment entries borrow kernel memory that may be reallocated

**Verdict**: The kernel layer is correctly more advanced than TCA26. Reducing ownership sophistication would be a regression.

---

#### Pattern 10: Structural Composition (Feature Tree = Routing Tree)

**TCA26**: Features compose hierarchically, routing follows composition structure.

**Kernel/platform status**: NOT APPLICABLE.

The kernel layer does not have hierarchical state trees. Its composition model is layered (L1 -> L2 -> L3), not tree-structured:

```
CPU Primitives (L1) ──> Kernel Primitives (L1) ──> Darwin/Linux Primitives (L1)
                                                          │
                                                          v
                                    ISO 9945 (L2) ──> POSIX/Darwin/Linux (L3)
                                                          │
                                                          v
                                                    Kernel (L3, umbrella)
```

Each layer adds policy (EINTR retry in swift-posix) or composition (Executor composes Thread + Synchronization + Job.Queue), but there is no routing or action dispatch.

**Verdict**: Not applicable. Layer composition is the correct model for infrastructure.

---

### @unchecked Sendable Audit

The TCA26 investigation recommended reducing @unchecked Sendable where isolation confinement could be used instead. Here is the kernel layer inventory:

| Type | Location | Safety Invariant | Could Eliminate? |
|------|----------|------------------|-----------------|
| `Kernel.Thread.Executor` | swift-kernel line 74 | Jobs enqueued under lock, executed serially on dedicated thread | **NO** -- class must be Sendable for `SerialExecutor` conformance; internal synchronization is the correct pattern |
| `Kernel.Thread.Synchronization<N>` | swift-kernel line 38 | All access via `withLock` or while holding mutex | **NO** -- this IS the synchronization primitive; isolation confinement would be circular |
| `Kernel.Thread.Gate` | swift-kernel line 43 | State protected by internal `SingleSync` | **NO** -- same as Synchronization; the type provides synchronization |
| `Kernel.Thread.Barrier` | swift-kernel line 30 | State protected by internal `SingleSync` | **NO** -- same rationale |
| `Kernel.Thread.Handle.Reference` | swift-kernel line 40 | Handle accessed exactly-once for join, in controlled lifecycle code | **MAYBE** -- could use `Mutex<Handle?>` instead of class + Optional. But the current pattern is simpler and the exactly-once join is enforced by deinit+precondition |
| `Kernel.Continuation.Context` | swift-kernel line 51 | Atomic state machine for exactly-once resumption; callback invoked from winner of atomic CAS | **NO** -- genuinely thread-safe-by-construction via `Atomic<State>` |

**Analysis**: All 6 @unchecked Sendable types in swift-kernel are **genuinely thread-safe-by-construction**. Five of six are synchronization primitives or types that *provide* thread safety -- they cannot use isolation confinement because they *are* the isolation mechanism. `Handle.Reference` is the only candidate for simplification, but the current pattern is already simpler than alternatives.

**Verdict**: No @unchecked Sendable types should be changed. The ~Sendable semantic inventory (which identified IOUring.Ring, IOCP.State, IteratorHandle as Tier 1 candidates) correctly focused on swift-io, not the kernel layer.

---

### C/Swift Boundary Closures

A specific concern from the task description: how do closures cross the C/Swift boundary?

**Answer**: They don't. The kernel/platform layer's C interop is **statically dispatched** -- there are no callback closures crossing the C boundary.

- `Kernel.Kqueue.kevent()` calls `_kevent()` (a `@_silgen_name` import of the C `kevent` function) with pointer parameters, not callbacks
- `CPU.Atomic.load/store` calls C shim functions (`swift_cpu_atomic_load_relaxed_u8_v1`) with pointer parameters
- `POSIX.Kernel.IO.Write.write()` calls `ISO_9945.Kernel.IO.Write.write()` which calls the C `write` syscall
- `Linux.Thread.Affinity.apply()` calls `pthread_setaffinity_np()` with a `cpu_set_t` value, not a callback

The only "callback" pattern is `Kernel.Thread.spawn`, which creates a closure that runs on the new thread. But this is a Swift-to-Swift transfer via `pthread_create`'s `void *(*)(void *)` function pointer -- the C boundary is in the platform-specific implementation (swift-iso-9945), not in these packages.

**Verdict**: No C/Swift closure boundary concerns in the audited packages.

---

## Comparison Matrix

| TCA26 Pattern | Kernel Primitives (L1) | Kernel Foundations (L3) | Platform (L1/L3) | Status |
|---|---|---|---|---|
| **F1: Isolation unification** | N/A (pure data types) | Adopted (Executor dual-mode) | N/A | ALREADY ADOPTED where applicable |
| **F2: Non-Sendable closures** | 1 debatable (`Syscall.Rule`) | All justified | None | ALREADY ADOPTED |
| **F3: Sync mutation + async collection** | N/A | Adopted (Executor runLoop) | N/A | ALREADY ADOPTED |
| **P4: nonisolated(nonsending)** | N/A (no isolation) | N/A (explicit sync) | N/A (static/sync) | NOT APPLICABLE |
| **P5: sending @isolated(any)** | N/A | N/A (OS threads) | N/A | NOT APPLICABLE |
| **P7: LockIsolated inout sending** | N/A | Different pattern (withLock) | N/A | ALTERNATIVE ADOPTED |
| **P8: Pointer state storage** | Extensive (syscall buffers) | Moderate (Transfer.Retained) | Extensive (ring buffers) | ALREADY ADOPTED (more advanced) |
| **P9: Conservative ownership** | ~Copyable, ~Escapable, borrowing | ~Copyable, consuming | ~Copyable | MORE ADVANCED (correctly) |
| **P10: Structural composition** | N/A | N/A | N/A | NOT APPLICABLE |
| **@unchecked Sendable** | 0 types | 6 types (all justified) | 0 types | NO CHANGES NEEDED |
| **@Sendable closures** | 1 (Syscall.Rule predicate) | 7 (all boundary-crossing) | 0 | NO UNNECESSARY ANNOTATIONS |
| **nonisolated(nonsending)** | 0 sites | 0 sites | 0 sites | N/A (sync layer) |
| **sending** | 0 sites | 0 sites | 0 sites | N/A (OS threads, not Tasks) |

## Outcome

**Status**: RECOMMENDATION

### Findings

**K1: The kernel/platform layer already follows TCA26 best practices for isolation and Sendability.** Every `@Sendable` annotation is justified (thread spawn, continuation callback). Every non-Sendable closure is correctly non-Sendable (withLock). All @unchecked Sendable types are genuinely thread-safe-by-construction. There is no cleanup work to do.

**K2: The kernel layer's ownership model is correctly more advanced than TCA26.** `Kernel.Descriptor` (~Copyable with deinit), `Kernel.Environment.Entry` (~Copyable + ~Escapable), `Kernel.Thread.Worker` (~Copyable with consuming join), and the `borrowing` parameter convention on syscall wrappers are all domain-appropriate. TCA26's conservatism validates that these features are not needed for UI; the kernel layer validates that they ARE needed for OS resources.

**K3: F1 (isolation unification via protocol) does not apply to the kernel layer.** The kernel layer is below the isolation boundary -- it provides the synchronization primitives that higher layers use to implement isolation. Unifying Gate, Barrier, and Synchronization under a protocol would add indirection without enabling any new capability.

**K4: F2 (non-Sendable closures) is already perfectly applied.** The key insight from TCA26 -- that closures confined to a single domain don't need `@Sendable` -- is already embodied in `Synchronization.withLock(() throws(E) -> T)`. The only @Sendable closures are those genuinely crossing OS thread boundaries.

**K5: The C/Swift boundary in the kernel layer uses pointer parameters, not callbacks.** All syscall interop is through static function calls with `UnsafePointer`/`UnsafeMutablePointer` parameters. There are no callback closures crossing the C boundary, so the TCA26 concern about closure Sendability at boundaries does not arise.

### Recommendations

**R1 (NO-OP)**: No changes to @Sendable annotations. All 8 @Sendable closure sites in the kernel layer are genuinely boundary-crossing.

**R2 (NO-OP)**: No changes to @unchecked Sendable conformances. All 6 types are synchronization primitives or atomic-state-machine types that are thread-safe by construction.

**R3 (MINOR -- Kernel.Syscall.Rule)**: The `@Sendable` on `Rule<T>.check` (line 38 of `Kernel.Syscall.swift`) is present because `Rule<T>: Sendable` requires stored closures to be `@Sendable`. This is technically correct but limits Rule to Sendable predicates. Since all existing rules are stateless closures (`.nonNegative = { $0 >= 0 }`, `.equals(x) = { $0 == x }`), this is not a practical issue. **No change recommended** -- the annotation is load-bearing for the type's Sendable conformance.

**R4 (PRESERVE)**: Continue the current ownership model. The kernel layer correctly uses ~Copyable for OS resources (Descriptor, Handle, Worker), ~Escapable for borrowed environment data (Environment.Entry), consuming for exactly-once lifecycle operations (join), and borrowing for syscall parameters. These are TCA26-validated as non-excessive for their domain.

**R5 (INFORMATIONAL)**: This analysis confirms the isolation hierarchy from `modern-concurrency-conventions.md` is correctly applied at the kernel layer: `~Copyable` (Descriptor, Worker) > `Atomic` (Continuation.Context, Worker.Token, Executors counter) > `Mutex+CondVar` (Synchronization, Gate, Barrier) > `@unchecked Sendable` (Executor, Reference). No level is being used where a higher-priority mechanism would suffice.

### What This Means for swift-io

The TCA26 recommendations (R1-R5 from the prior investigation) remain valid for swift-io. The kernel layer analysis demonstrates that the infrastructure *below* swift-io is already clean. Any @Sendable cleanup in swift-io's poll-thread closures (prior R1) can proceed without concern about the kernel layer -- the kernel APIs that swift-io calls (spawn, withLock, Continuation.Context) have correct annotations.

## References

- TCA26 investigation: `swift-institute/Research/tca26-isolation-patterns-investigation.md`
- Kernel.Thread.Executor: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.Executor.swift`
- Kernel.Thread.Synchronization: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.Synchronization.swift`
- Kernel.Thread.spawn: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.spawn.swift`
- Kernel.Thread.Worker: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.Worker.swift`
- Kernel.Continuation.Context: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Continuation/Kernel.Continuation.Context.swift`
- Kernel.Descriptor: `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Descriptor Primitives/Kernel.Descriptor.swift`
- Kernel.Syscall.Rule: `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Syscall Primitives/Kernel.Syscall.swift`
- Kernel.Environment.Entry: `/Users/coen/Developer/swift-primitives/swift-kernel-primitives/Sources/Kernel Environment Primitives/Kernel.Environment.Entry.swift`
- Darwin.Kernel.Kqueue: `/Users/coen/Developer/swift-primitives/swift-darwin-primitives/Sources/Darwin Kernel Primitives/Darwin.Kernel.Kqueue.swift`
- CPU.Atomic: `/Users/coen/Developer/swift-primitives/swift-cpu-primitives/Sources/CPU Primitives/CPU.Atomic.Load.Operations.swift`
- POSIX.Kernel.IO.Write: `/Users/coen/Developer/swift-foundations/swift-posix/Sources/POSIX Kernel/POSIX.Kernel.IO.Write.swift`
- Kernel.Thread.Worker.Token: `/Users/coen/Developer/swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.Worker.Token.swift`
- Modern concurrency conventions: `swift-institute/Research/modern-concurrency-conventions.md`
- ~Sendable semantic inventory: `swift-institute/Research/tilde-sendable-semantic-inventory.md`
- Concurrent expansion audit: `swift-institute/Research/concurrent-expansion-audit.md`
