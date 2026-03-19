# swift-io Deep Audit v2

<!--
---
version: 2.0.0
last_updated: 2026-03-19
status: COMPLETE
tier: 2
prior: swift-io-deep-audit.md (v3.0.0, 2026-02-25)
---
-->

## Context

Comprehensive audit of `swift-io` (Layer 3, swift-foundations) against the current skill set — particularly /implementation, /existing-infrastructure, /naming, /errors, /code-organization, and property-primitives adoption. The audit also reconciles all 85 findings from the prior v3.0.0 audit (2026-02-25).

**Package**: `/Users/coen/Developer/swift-foundations/swift-io/`
**Modules**: IO Primitives (7 files), IO Blocking (30 files), IO Blocking Threads (29 files), IO Events (68 files), IO Completions (49 files), IO (34 files) — **217 source files total**
**Dependencies**: 21 packages (15 primitives, 6 foundations)

## Summary

| Category | CRITICAL | HIGH | MEDIUM | LOW | Total |
|----------|----------|------|--------|-----|-------|
| Prior findings still open | 0 | 1 | 5 | 6 | 12 |
| New findings | 0 | 4 | 36 | 30 | 70 |
| **Total active** | **0** | **5** | **41** | **36** | **82** |

**Key improvements since v1**: Zero-copy event pipeline (H-3 resolved), pool-backed slot allocation (H-1 mitigated), heap-based deadline scheduling (H-8 resolved), structured iteration throughout (M-10, M-14, L-17, L-18 resolved). 10 prior findings resolved, 12 confirmed false positive, 14 confirmed KEEP.

---

## Prior Audit Reconciliation

### Resolved (10)

| ID | Original Finding | Resolution |
|----|-----------------|------------|
| C-2 | Slot deallocation race | `defer { slot.deallocateRawOnly(); ... }` at Registry.swift:816-818. Verified. |
| H-1 | Per-operation heap alloc | **Mitigated**: `IO.Executor.Slot.Pool` added (Memory.Pool-backed). Registry.swift:809-814 tries pool first, falls back to heap on exhaustion. Per-operation heap alloc is now the exception. |
| H-3 | Event buffer copy per poll | **Fully resolved**: Zero-copy event pipeline implemented. `IO.Event.Buffer.Pool` (Memory.Pool-backed) + `IO.Event.Batch` (pointer-based). Poll.Loop.swift:86-113 allocates a pool slot and memcpy's events — no `Array(eventBuffer.prefix(count))` heap allocation. |
| H-8 | O(n) deadline scan | Now uses `Heap<Deadline.Entry>.Fixed` for O(1) peek + O(k log n) expiry. Deadline.Manager.swift:47. |
| M-8 | Magic literal 0 wakeup sentinel | Failable `IO.Event.ID(pollData:)` init with `.zero` guard. Poll.Operations.swift:21-32. |
| M-10 | Manual while let dequeue() | `entry.waiters.dequeueEligible(flaggedInto:)` + `.drain {}` at Registry.swift:893-913. |
| M-14 | Manual while loops in Acceptance.Queue | Structured `dequeue()`, `drain()`, and `Expired.cancel()` using slab/queue/heap primitives. |
| M-16 | `__unchecked` + `Cardinal()` waiters | `Index<...>.Count = try! .init(max(capacity, 1))` at Waiters.swift:61-63. |
| L-17 | Acceptance waiter drain | `Queue.drain { entry, coord in ... }` at Threads.swift:270-274. |
| L-18 | Array allocation for expired tickets | Heap-based in-place pop at Queue.swift:366-378. |

### Confirmed False Positive / By Design (13)

| ID | Finding | Reason unchanged |
|----|---------|-----------------|
| C-1 | Non-atomic Bool flags | Actor isolation on `IO.Handle.Registry`. |
| C-3 | Handle consume without guarantee | Branches are mutually exclusive under actor serialization. |
| C-5 | Continuation resumption race | CAS with `acquiringAndReleasing` ordering — exactly-once by design. |
| C-6 | Blocking continuation race | `setContinuation()` BEFORE `isCancelled` check; CAS guards all transitions. |
| C-7 | Double-resume in async stream | All state types are actors. |
| H-4 | Shutdown iteration + mutation | Actor isolation on Queue. `cancel(id:)` does not mutate `entries`. |
| H-5 | Unmanaged dangling pointer | `entries` dictionary retains `Storage` for entire kernel operation lifetime. |
| H-7 | Per-job Mutex allocation | `Synchronization.Mutex` is a value type — no heap allocation. |
| H-9 | Continuation lifetime risk | Dropping a `Task` handle does NOT cancel the task. |
| H-10 | Pool.Blocking lock contention | `defer { sync.unlock() }` at function scope (correct). Condition variable semantics. |
| L-12 | Lifecycle check not atomic | `_lifecycle.load(ordering: .acquiring)` IS the atomic check. |
| M-25 | `fatalError` catch-all | These are typed-throws-in-escaping-closure dead code paths, not catch-alls. Correct. |
| M-33 | `.rawValue` in Metrics | Boundary conversion from `Cardinal.Protocol` to `UInt64` for atomic. Acceptable. |

### Still Open (12)

| ID | Severity | Status | Notes |
|----|----------|--------|-------|
| C-4 | KNOWN LIMITATION | Unchanged | `Ownership.Transfer.Cell` silent resource drop. Documented at Registry.swift:368-371. |
| H-2 | OUT OF SCOPE | Unchanged | Double heap alloc per `register()`. Requires `Ownership.Transfer` redesign in swift-memory. |
| M-20 | OPEN | Unchanged | io_uring `@unchecked Sendable` Ring. Requires Linux testing. |
| M-22 | OPEN | Unchanged | `@unchecked Sendable` Shards. Justification in comments at Shards.swift:53-55 is sound. |
| M-24 | OPEN | Unchanged | Unbounded deadline heap. Mitigated by generation-based staleness detection. |
| M-27 | OPEN | Unchanged | Relaxed atomics visibility in shutdown path. Safe in practice (lock fence), fragile semantically. |
| M-30 | OPEN | Unchanged | Shutdown teardown error swallowing. Documented as best-effort. |
| M-31 | OPEN | **Worse** | Now 5 resume sites (was 3). Queue.swift:276,288,295,456,481. All CAS-protected. |
| M-26 | OPEN | Unchanged | io_uring kernel offset bounds checking. Linux-only. |
| L-1 | LOW | Unchanged | Undocumented ordering in Waiter.swift. |
| L-11 | LOW | Unchanged | `@usableFromInline` + `_` prefix in Registry.swift:429-482. Consistent and intentional. |
| L-13 | LOW | Unchanged | Relaxed ordering on telemetry counters. Documented and intentional. |

### Reclassified (2)

| ID | Old | New | Reason |
|----|-----|-----|--------|
| M-32 | MEDIUM | LOW | Resolved by clamping; remaining issue is style (Int not typed Count). |
| M-34 | (H-8 sub) | RESOLVED | Heap replaced O(n) scan entirely. |

### Platform — Unchanged (4)

M-1, M-5, M-6, M-19 — all Windows IOCP. Cannot build or test on macOS.

---

## New Findings by Category

### HIGH

#### v2-H-1: Undefined `.invalidArgument` error case in io_uring [Correctness]

**File**: `IO Completions/IO.Completion.IOUring.swift:122,134`

The io_uring `submitStorage` closure throws `.operation(.invalidArgument)` for nil buffer guards. But `IO.Completion.Error.Operation` defines only: `.cancellation`, `.timeout`, `.invalidSubmission`, `.queue(.full)`. There is no `.invalidArgument` case. This is either a compilation error on Linux or evidence that this code path was never compiled. The IOCP backend correctly uses `.invalidSubmission` for the same guard (IOCP.swift:133,163).

**Rule**: [API-ERR-001]

#### v2-H-2: Weak self drain task risks silent stall [Correctness]

**File**: `IO Completions/IO.Completion.Queue.swift:205-209`

The drain task captures `[weak self]` and calls `await self?.drain(events)`. If the Queue actor is deallocated while operations are in-flight, the drain task silently stops processing events. Pending waiters' continuations would never be resumed. The `deinit` at line 212-215 cancels the drain task but does not resume pending waiters.

#### v2-H-3: Binary_Primitives declared but unused in 2 targets [Dependency]

**File**: `Package.swift` — IO Primitives target (line 52) and IO Events target (line 99)

No source file in either module imports `Binary_Primitives`. Dead dependency weight.

#### v2-H-4: 6 MemberImportVisibility violations [Build]

With `MemberImportVisibility` enabled, these imports reference modules NOT declared as target dependencies and NOT `@_exported` by any declared dependency:

| File | Imports | Missing Dependency |
|------|---------|-------------------|
| `IO Events/IO.Event.Interest+Hash.swift` | `Hash_Primitives` | swift-hash-primitives |
| `IO Events/IO.Event.Selector.Permit.Key+Hash.swift` | `Hash_Primitives` | swift-hash-primitives |
| `IO/IO.Handle.ID+Hash.swift` | `Hash_Primitives` | swift-hash-primitives |
| `IO Blocking/IO.Blocking.Ticket.swift` | `Identity_Primitives` | swift-identity-primitives |
| `IO/IO.Handle.Registry.swift` | `Async_Primitives` | swift-async |
| `IO/IO.Handle.Waiters.swift` | `Async_Primitives` | swift-async |

These work today via transitive visibility but will fail when MIV enforcement tightens.

### MEDIUM

#### Typed Throws Violations [API-ERR-001]

| ID | File:Line | Description |
|----|-----------|-------------|
| v2-M-1 | `IO/IO.Executor.Slot.Pool.swift:36` | Bare `throws` on `init(resourceStride:resourceAlignment:slotCount:)`. Should be `throws(Memory.Pool.Error)`. |
| v2-M-2 | `IO/IO.Executor.Slot.Pool.swift:53` | Bare `throws` on `allocateSlot()`. Should be typed. |
| v2-M-3 | `IO Events/IO.Event.Buffer.Pool.swift:45` | Bare `throws` on `init(maxEvents:slotCount:)`. Should be `throws(Memory.Pool.Error)`. |
| v2-M-4 | `IO Events/IO.Event.Buffer.Pool.swift:69` | Bare `throws` on `allocateSlot()`. Should be typed. |

All 4 are package-access (not public), but still violate the ecosystem convention.

#### One Type Per File Violations [API-IMPL-005]

| ID | File | Types | Notes |
|----|------|-------|-------|
| v2-M-5 | `IO/IO.Lane.swift` | `IO.Lane` + `IO.Lane.Error` | Error should be in `IO.Lane.Error.swift`. |
| v2-M-6 | `IO/IO.Failure.swift` | `IO.Failure` + `.Work` + `.Scope` | 3 types, each should have own file. |
| v2-M-7 | `IO/IO.Handle.Waiters.swift` | `IO.Handle.Waiter` + `.Token` + `IO.Handle.Waiters` | 3 types. |
| v2-M-8 | `IO/IO.Executor.Slot.swift` | `IO.Executor.Slot` + `.Address` | Address should be in own file. |
| v2-M-9 | `IO Events/IO.Event.Channel.swift` | `Channel` + `ReadResult` + `WriteResult` + 4 Error extension inits | Substantial Error conversion logic (75 lines) should be extracted. |
| v2-M-10 | `IO Events/IO.Event.Backoff.Exponential.swift` | `Backoff` namespace + `Backoff.Exponential` | Namespace should be in `IO.Event.Backoff.swift`. |
| v2-M-11 | `IO Events/IO.Event.Deadline.Entry.swift` | `IO.Event.DeadlineScheduling` namespace | **Wrong filename** — should be `IO.Event.DeadlineScheduling.swift`. |
| v2-M-12 | `IO Events/IO.Event.Driver.swift` | `Driver` + `Deadline` typealias | Typealias belongs in own file. |
| v2-M-13 | `IO Events/IO.Event.Registration.Queue.swift` | Module-level `Queue<T>` typealias + extension + nested typealias | Mixed concerns. |
| v2-M-14 | `IO/IO.open.swift:194` | `_ScopeOperationFailure` helper enum | Internal type in wrong file; underscore-prefixed naming. |

#### Naming / API Design

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| v2-M-15 | `IO Events/IO.Event.Registration.Queue.swift:15` | Module-level `public typealias Queue<T>` leaks as top-level name in IO_Events module. | [API-NAME-001] |
| v2-M-16 | `IO Events/IO.Event.Channel.swift:487-549` | 14 occurrences of `.rawValue` in error conversion inits constructing `Kernel.Error.Code` from raw numbers. | Raw value access |
| v2-M-17 | `IO Events/IO.Event.Batch.swift:34` | `count: Int` should be typed Count. Same in `Driver.Capabilities.maxEvents: Int` and `Buffer.Pool.init(maxEvents: Int)`. | Manual arithmetic |

#### @unchecked Sendable / Safety

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| v2-M-18 | `IO Completions/IO.Completion.Operation.swift:79` | `Storage` is `@unchecked Sendable` with mutable fields. Invariant ("mutable fields under actor isolation; immutable fields safe for cross-thread read") not documented. | [MEM-SEND] |
| v2-M-19 | `IO Completions/IO.Completion.Queue.swift:130` | `Entry` is `@unchecked Sendable`. Real invariant is "only accessed under Queue actor isolation." | [MEM-SEND] |
| v2-M-20 | `IO Blocking/IO.Blocking.Lane.Abandoning.Job.swift:13` | Job is `@unchecked Sendable` with manual `Kernel.Thread.Mutex` lock/unlock (no `defer`). Error-prone. | [MEM-SEND] |

#### Completions-Specific

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| v2-M-21 | `IO Completions/IO.Completion.Poll.Context.swift:22` | Documentation drift: says "Reference.Transfer.Cell" but code uses `Ownership.Transfer.Cell`. | Documentation |
| v2-M-22 | `IO Completions/IO.Completion.Driver+Witness.Key.swift:21` | `fatalError("No completion driver available")` on Darwin for `liveValue`. | Robustness |
| v2-M-23 | `IO Completions/IO.Completion.IOUring.swift:70` | Force-unwrap `handle.ringPtr!` without guard. Callers must check first. Fragile. | Robustness |
| v2-M-24 | `IO Completions/IO.Completion.IOUring.Ring.swift:109-145` | Three mmap regions allocated sequentially. If 2nd fails, 1st may leak (depends on Swift partial-init cleanup). | Robustness |
| v2-M-25 | `IO Completions/IO.Completion.Channel.swift:66-98,109-141` | Duplicated outcome-to-result mapping in `read`/`write`. | [IMPL-EXPR] |
| v2-M-26 | `IO Completions/IO.Completion.Poll.swift:59-63` | Submission buffer drain-then-submit: if poll crashes between drain and submit, submissions are lost. | Robustness |

#### Blocking-Specific

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| v2-M-27 | `IO Blocking/IO.Blocking.Lane.Abandoning.Worker.swift:107-108` | Per-job `Kernel.Thread.Mutex()` + `Condition()` allocation for watchdog sync. Allocation pressure under high throughput. | Performance |
| v2-M-28 | `IO Blocking/IO.Blocking.Lane.Abandoning.Worker.swift:135-138` | Silent degradation on watchdog spawn failure — no logging, no metric, no error. | Observability |
| v2-M-29 | `IO Blocking Threads/IO.Blocking.Threads.swift:282-298` | Blocking `condvar.wait()` inside `withCheckedContinuation` blocks a cooperative thread pool thread. | Concurrency |
| v2-M-30 | `IO Blocking Threads/IO.Blocking.Threads.swift:283-285` | Double lock acquisition TOCTOU: check/unlock/lock/wait pattern. First check is an optimization; could race. | Correctness |
| v2-M-31 | `IO Blocking Threads/IO.Blocking.Threads.Worker.swift:51-278` | Single 228-line `run()` method with duplicated batch/acceptance paths. | [API-IMPL] |
| v2-M-32 | `IO Blocking/IO.Blocking.Lane.swift:124-129` | `fatalError` on typed-throws invariant violation. Runtime trap instead of typed error. | Robustness |

#### Cross-Cutting / Dependencies

| ID | File:Line | Description | Rule |
|----|-----------|-------------|------|
| v2-M-33 | `Package.swift` (IO Events) | `Queue DoubleEnded Primitives` declared but unused. No file imports it. | Dependency |
| v2-M-34 | `Package.swift` (IO) | `Memory` (swift-memory) declared but unused. Memory.Pool comes from `Memory Pool Primitives`. | Dependency |
| v2-M-35 | `Sources/IO Completions/` | Missing `exports.swift` file — re-exports inline in `IO.Completion.swift`. Breaks convention. | Convention |
| v2-M-36 | `IO Events/IO.Event.Selector.swift:800,829` | `runEventLoop()` and `runReplyLoop()` are `public` but documented as internal-use only. Should be `package`. | API design |

### LOW

#### Style / Documentation

| ID | File:Line | Description |
|----|-----------|-------------|
| v2-L-1 | `IO/IO.Executor.Counter.swift:2` | File header says "File.swift" instead of the actual filename. |
| v2-L-2 | `IO Blocking Threads/IO.Blocking.Threads.Completion.Result.swift:2` | Same wrong header ("File.swift"). |
| v2-L-3 | `IO/IO.Handle.ID+Hash.swift` | Missing standard file header comment. |
| v2-L-4 | `IO Events/Exports.swift` | Capital "E" — inconsistent with `exports.swift` in all other modules. |
| v2-L-5 | `IO Primitives/exports.swift` | Missing `public` keyword on `@_exported import` (other modules use `@_exported public import`). |
| v2-L-6 | `IO Blocking/exports.swift` | Redundant `@_exported public import Kernel` — already re-exported by IO_Primitives. |
| v2-L-7 | `IO Events/Exports.swift` + `IO.Event.swift` | Kernel re-exported in both files. Redundant. |
| v2-L-8 | `IO Events/IO.Event.Selector.swift:89-95` | Mixed dictionary init styles (`[ID: Registration] = [:]` vs `Dictionary<K,V> = .init()`). |
| v2-L-9 | `IO Completions/IO.Completion.Poll.swift:68,77,94` | Three empty catch blocks labeled "log error" — no actual logging. |
| v2-L-10 | `IO Completions/IO.Completion.Accept.Result.swift:17` | `peerAddress: Void?` placeholder. Always nil. |
| v2-L-11 | `IO Completions/IO.Completion.Channel.swift:201-204` | `close()` is a no-op. Comment says "In a real implementation..." |

#### `try!` Density

| ID | File:Line | Description |
|----|-----------|-------------|
| v2-L-12 | `IO Blocking/Options.Workers.swift:30-31` | `try!` in default parameter values (known-valid constants). |
| v2-L-13 | `IO Blocking/Runtime.State.swift:15` | `try!` in stored property initializer. |
| v2-L-14 | `IO Blocking Threads/Lane.Sharded+Threads.swift:60` | `try!` in Array.Fixed construction. |
| v2-L-15 | `IO Blocking Threads/Snapshot.Storage.swift:28` | `try!` in init. |
| v2-L-16 | `IO Blocking Threads/Acceptance.Queue.swift:81-85` | Four `try!` in Queue init (Slab, Queue.Fixed, Dictionary.Ordered.Bounded, Heap.Fixed). |
| v2-L-17 | `IO Blocking Threads/Worker.swift:53` | `try!` in local batch storage. |
| v2-L-18 | `IO/IO.Executor.Shards.swift:75,99` | `try!` in init (guarded by preceding precondition). |
| v2-L-19 | `IO/IO.Handle.Registry.swift:132,163,192` | `try!` on pool construction. |
| v2-L-20 | `IO Events/IO.Event.Buffer.Pool.swift:85` | `try!` in deallocate. |

All 9 are safe at runtime (known-valid values, clamped inputs, or precondition-guarded), but the density is notable. A `static let` pattern for compile-time-known values would eliminate `try!` in default parameters and property initializers.

#### Robustness / Performance

| ID | File:Line | Description |
|----|-----------|-------------|
| v2-L-21 | `IO/IO.Handle.Registry.swift:939` | Timeout mapped to cancellation — callers cannot distinguish the two. |
| v2-L-22 | `IO Events/IO.Event.Poll.Operations.swift:248` | Timeout overflow clamp maps to `-1` (block forever) instead of `Int32.max`. |
| v2-L-23 | `IO Events/IO.Event.Channel.swift:264-310,325-358` | Duplicated arm logic in `arm(for:)` and `await(readiness:)`. |
| v2-L-24 | `IO Events/IO.Event.Channel.Lifecycle.swift:24` | Full actor for 2 boolean flags — `Atomic<UInt8>` would avoid actor-hop overhead. |
| v2-L-25 | `IO Events/IO.Event.Queue.Operations.swift:68` | Inconsistent ID construction between kqueue and epoll. |
| v2-L-26 | `IO Blocking Threads/Selector.swift:58` | Verbose index chain `Int → UInt → Ordinal → Index`. |
| v2-L-27 | `IO Blocking Threads/Worker.swift:99` | Opaque `capacity.subtract.saturating(.one)` for "was full, now has one slot" semantic. |
| v2-L-28 | `IO Blocking/Execution.Semantics.swift:63-69` | Private computed `rawValue: Int` switch for Comparable. |
| v2-L-29 | `IO Blocking Threads/Ticket+Hash.swift` | Empty file (only a comment explaining conformances come from elsewhere). |
| v2-L-30 | `IO Blocking/Deadline.swift:35-38` | `Int64(attoseconds / 1_000_000_000)` truncates sub-nanosecond precision. Acceptable for deadlines. |

---

## Dependency Utilization Matrix

| # | Dependency | Classification | Used By | Notes |
|---|-----------|---------------|---------|-------|
| 1 | swift-kernel (Kernel) | **HEAVY** | All 6 modules | Atomics, Tagged, Thread, Continuation, System. Re-exported everywhere. |
| 2 | swift-systems (Systems) | MODERATE | IO Blocking, Blocking Threads | NUMA topology, `System.topology()`. |
| 3 | swift-async (Async) | **HEAVY** | IO Events, IO Completions | `Async.Bridge` for event handoff. |
| 4 | swift-memory (Memory) | **UNUSED in IO target** | IO Completions only (Linux) | IO target declares dep but no file imports it. Memory.Pool comes from swift-memory-primitives. |
| 5 | swift-pools (Pool) | LIGHT | IO (exports only) | Only `IO.Pool` typealias to `Pool.Bounded`. |
| 6 | swift-witnesses (Witnesses) | MODERATE | IO Blocking, Events, Completions | `@Witness` macro on Lane, Drivers. |
| 7 | swift-clock-primitives | MODERATE | IO Blocking | `Clock.Suspending.Instant` for deadlines. |
| 8 | swift-buffer-primitives | **HEAVY** | IO Primitives, Blocking Threads, Events, Completions | `Deque`, `Buffer` types. Re-exported by IO Primitives. |
| 9 | swift-binary-primitives | **UNUSED** | Declared in IO Primitives, IO Events — **no file imports it** | Dead dependency. Should be removed. |
| 10 | swift-queue-primitives | HEAVY | IO Blocking Threads | `Queue.DoubleEnded.Fixed`, `Queue.Fixed`. **Also declared for IO Events but unused there.** |
| 11 | swift-dimension-primitives | MODERATE | IO Blocking, Blocking Threads, Completions | Typed dimensions in options. |
| 12 | swift-system-primitives | LIGHT | IO Blocking Threads | Stack size types. Single file. |
| 13 | swift-test-primitives | MODERATE | IO Test Support | Test-only. |
| 14 | swift-ownership-primitives | **HEAVY** | IO Blocking, Blocking Threads, Events, Completions, IO | `Ownership.Transfer`, `Ownership.Mutable.Unchecked`. |
| 15 | swift-heap-primitives | MODERATE | IO Events, Blocking Threads | Deadline heaps. |
| 16 | swift-array-primitives | MODERATE | IO Blocking Threads, IO | `Array.Fixed` for sharded storage. |
| 17 | swift-dictionary-primitives | MODERATE | IO Blocking Threads, Events, Completions, IO | `Dictionary.Ordered.Bounded`, standard Dictionary extensions. |
| 18 | swift-slab-primitives | MODERATE | IO Blocking Threads | Acceptance queue storage plane. |
| 19 | swift-memory-primitives | MODERATE | IO Events, IO | `Memory.Pool` for buffer/slot pools. |
| 20 | swift-dependency-primitives | LIGHT | IO Blocking Threads, IO | `Dependency.Key` conformances. 2 files. |
| 21 | swift-witness-primitives | LIGHT | IO Events, IO Completions | `Witness.Key` protocol. |

**Action items**:
- **Remove** swift-binary-primitives from IO Primitives and IO Events (v2-H-3)
- **Remove** Queue DoubleEnded Primitives from IO Events (v2-M-33)
- **Remove** Memory (swift-memory) from IO target (v2-M-34)
- **Add** swift-hash-primitives to IO Events and IO targets (v2-H-4)
- **Add** swift-async to IO target (v2-H-4)
- **Add** swift-identity-primitives to IO Blocking target or verify via Kernel re-export (v2-H-4)

---

## Module Boundary Assessment

### Layering

```
IO Primitives → IO Blocking → IO Blocking Threads ─┐
                                                     ↓
IO Primitives → IO Events ──────────────────────────→ IO
                                                     ↑
IO Primitives → IO Events → IO Completions ─────────┘
```

**Layering is clean**: No circular or upward references. All imports respect the declared module hierarchy. Types that straddle boundaries (e.g., `IO.Blocking.Lane.Sharded` defined in IO Blocking, extended in IO Blocking Threads) are correctly placed — the split follows the dependency direction.

### Re-Export Hygiene

| Module | Re-exports | Issues |
|--------|-----------|--------|
| IO Primitives | Kernel, Buffer_Primitives, Synchronization | Missing `public` on `@_exported import` (v2-L-5). |
| IO Blocking | IO_Primitives, Kernel | Kernel re-export is redundant (v2-L-6). |
| IO Blocking Threads | IO_Blocking | Clean. Single re-export. |
| IO Events | IO_Primitives, Kernel, Async | Kernel re-exported in 2 files (v2-L-7). Split re-exports across Exports.swift and IO.Event.swift (v2-L-4). |
| IO Completions | IO_Primitives | No `exports.swift` file (v2-M-35). Re-exports inline in `IO.Completion.swift`. |
| IO | IO_Blocking, IO_Blocking_Threads, Pool_Primitives | Does NOT re-export IO_Events or IO_Completions. Intentional — consumers must explicitly opt-in. |

### Types in Wrong Module

No types found in the wrong module. The `IO.Backpressure.Policy` type is correctly in IO Blocking (not IO Primitives) because it references typed dimensions and has runtime semantics. `IO.Backpressure.Strategy` is correctly in IO Primitives (pure value type).

---

## Property-Primitives Adoption Assessment

swift-property-primitives is NOT currently a dependency. Evaluation of adoption candidates:

| Pattern | Occurrence | Property.View Candidate? | Assessment |
|---------|-----------|------------------------|------------|
| Two ~Copyable optional tokens (`registering`/`armed`) | IO.Event.Channel.swift:68-69 | No | Move-only typestate. Prior audit M-15 confirmed KEEP. |
| Mutex-protected mutable state | Buffer.Pool, Slot.Pool, Shards, Runtime.State | No | These are Lock+State patterns, not Property patterns. |
| Actor-isolated stored properties | Handle.Registry, Selector, Queue | No | Actor isolation provides the access control. |
| Atomic-backed state machines | Waiter.State, Job.State, IO.Lifecycle | No | Atomic primitives are the correct abstraction. |

**Conclusion**: No compelling property-primitives adoption targets. The IO module's patterns are either lock-based, actor-based, or atomic-based — none map naturally to Property.View's read/modify accessor model.

---

## Recommended Migration Order

### Phase 1: Build Correctness (HIGH priority)

1. **Fix v2-H-1**: Change `.invalidArgument` to `.invalidSubmission` in IOUring.swift:122,134
2. **Fix v2-H-3**: Remove Binary_Primitives from IO Primitives and IO Events in Package.swift
3. **Fix v2-H-4**: Add missing target dependencies (Hash_Primitives, Async_Primitives, Identity_Primitives) or verify re-export chains
4. **Fix v2-M-33/M-34**: Remove unused Queue_DoubleEnded_Primitives from IO Events, Memory from IO

### Phase 2: Typed Throws (MEDIUM priority)

5. **Fix v2-M-1 through M-4**: Type the 4 bare `throws` in Slot.Pool and Buffer.Pool

### Phase 3: Code Organization (MEDIUM priority, batch)

6. **Fix v2-M-5 through M-14**: Extract types to their own files. Priority order:
   - IO.Failure.swift (3 types → 3 files)
   - IO.Handle.Waiters.swift (3 types → 3 files)
   - IO.Lane.swift (2 types → 2 files)
   - IO.Executor.Slot.swift (2 types → 2 files)
   - IO.Event.Channel.swift (extract Error conversion logic)
   - IO.Event.Deadline.Entry.swift (rename to DeadlineScheduling.swift)
   - IO.open.swift (extract _ScopeOperationFailure)

### Phase 4: Safety Documentation

7. **Fix v2-M-18/M-19/M-20**: Document `@unchecked Sendable` safety invariants on Operation.Storage, Entry, Job

### Phase 5: Module Hygiene

8. **Fix v2-M-35**: Add exports.swift to IO Completions
9. **Fix v2-M-36**: Change `runEventLoop()`/`runReplyLoop()` from `public` to `package`
10. Normalize exports.swift casing and redundant re-exports (v2-L-4 through L-7)

### Deferred

- v2-H-2: Weak self drain task — requires architectural analysis of Queue lifecycle guarantees
- v2-M-29/M-30: Blocking condvar in async context, TOCTOU in shutdown — requires redesign of shutdown path
- `try!` density (v2-L-12 through L-20) — low priority, no runtime risk
- Platform findings (M-1, M-5, M-6, M-19) — requires Windows/Linux builds

---

## Changelog

### v2.0.0 (2026-03-19)

- **Full re-audit**: 217 source files, 10 audit axes
- **Prior reconciliation**: 10 resolved (including H-3 zero-copy pipeline), 13 confirmed false positive/KEEP, 12 still open, 2 reclassified
- **New findings**: 70 (4 HIGH, 36 MEDIUM, 30 LOW)
- **Key new axes**: MemberImportVisibility compliance, dependency utilization, property-primitives adoption evaluation
- **Notable improvements since v1**: Zero-copy event pipeline (H-3), pool-backed slot allocation (H-1), heap-based deadlines (H-8), structured iteration (M-10, M-14, L-17, L-18)

### Prior versions

- v3.0.0 (2026-02-25): MEDIUM triage. 3 fixed, 8 KEEP, 5 OUT OF SCOPE, 4 PLATFORM, 13 OPEN.
- v2.0.0 (2026-02-24): CRITICAL+HIGH triage. 12 FALSE POSITIVE, 2 FIXED, 1 KNOWN LIMITATION, 2 KEEP, 1 DESIGN NEEDED, 1 OUT OF SCOPE.
- v1.0.0 (2026-02-24): Initial audit. 85 findings (9 CRITICAL, 18 HIGH, 36 MEDIUM, 22 LOW).

---

## Cross-References

- Prior audit: [swift-io-deep-audit.md](swift-io-deep-audit.md) (v3.0.0)
- Dependency utilization (Tier 1): [foundations-dependency-utilization-audit.md](foundations-dependency-utilization-audit.md)
- Design doc: [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md) — H-3 now fully implemented
- Skills: **implementation**, **existing-infrastructure**, **naming**, **errors**, **code-organization**, **memory-safety**
