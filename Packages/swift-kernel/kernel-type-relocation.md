# Kernel Type Relocation

<!--
---
version: 1.0.0
last_updated: 2026-04-08
status: SUPERSEDED (2026-04-14 — thread-coordination REDEFINE reversed by strict-mission refactor)
---
-->

> **Supersession note (2026-04-14)**: This document's REDEFINE recommendation
> for the thread-coordination stack (Synchronization / DualSync / SingleSync /
> Barrier / Gate / Semaphore / Worker staying in swift-kernel) was overridden
> by the strict-mission refactor executed on 2026-04-14. Those types now live
> in swift-threads, split into fine-grained per-type variant targets
> (`Thread Synchronization`, `Thread Barrier`, `Thread Gate`,
> `Thread Semaphore`, `Thread Worker`) with a `Threads` umbrella.
>
> The REDEFINE rationale (cited "no external consumers" and "coherent
> dependency chain") was pragmatic. The user subsequently chose the
> principled alternative: swift-kernel's mission is now STRICTLY
> "thin syscall-adjacent wrappers over L1 kernel-primitives" — no L3
> compositions — and a new swift-threads L3 package owns thread-layer
> compositions.
>
> File.Write.Atomic / Streaming relocations (MOVE → swift-file-system) and
> the Continuation.Context / Handoff.Cell REMOVE recommendations DID land
> as proposed and remain authoritative. Only the thread-coordination stack
> verdict reversed.
>
> For the current state of each type see `swift-threads/Research/thread-dispatch-taxonomy.md`
> and the swift-threads package structure.

## Context

swift-kernel's README describes it as "policy-free syscall wrappers" providing "raw descriptors, typed throws, and unified error types." However, the package has grown to include significant composed abstractions that go well beyond thin syscall wrapping. A prior session extracted `Kernel.Thread.Executor` and `Kernel.Thread.Executor.Sharded` to `swift-executors`, establishing a precedent for relocating composed types out of swift-kernel.

This investigation was triggered by three parallel handoffs completing simultaneously: Async.Semaphore (L1), Kernel.Thread.Semaphore (L3), and the swift-executors extraction. The executor consolidation proved that cross-module extension of namespace enums works cleanly for defining types in external modules.

### Package inventory

swift-kernel contains 6 targets and 85 source files:

| Target | Files | Content |
|--------|-------|---------|
| Kernel Core | 16 | Kernel.Failure, Kernel.Readiness.* (14 files), Lock.Acquire, Process.ID, atomic |
| Kernel System | 4 | Processor.Count, Physical.Count, Memory.Total |
| Kernel Thread | 29 | Handle, spawn/trap, Affinity, Count, Synchronization, DualSync/SingleSync, Barrier, Gate, Semaphore (11 files), Worker (2 files) |
| Kernel File | 32 | Open, Clone, Copy, Write.Atomic (10 files), Write.Streaming (13 files), Write shared (5 files), String extension |
| Kernel Continuation | 3 | Continuation.Context (1 file), namespace enum, exports |
| Kernel (Umbrella) | 1 | Re-exports |

## Question

For each type currently in swift-kernel, should it: (a) **STAY** under the current mission, (b) **MOVE** to another package, or (c) remain but with a **REDEFINE**d mission statement that explicitly encompasses it?

Five specific sub-questions:

1. Is `Kernel.Thread.Synchronization<N>` a thin syscall wrapper or a composed primitive?
2. Where should the thread coordination family (Barrier/Gate/Semaphore/Worker) live?
3. Where should `Continuation.Context` live?
4. Where should `File.Write.Atomic` and `File.Write.Streaming` (~27 files) live?
5. Should swift-kernel's mission statement be updated?

## Analysis

### Evaluation criteria

| Criterion | Question |
|-----------|----------|
| **Syscall proximity** | Does it wrap a single syscall or compose multiple? |
| **Consumer breadth** | Is it used across many packages, or narrowly? |
| **Dependency impact** | What breaks if it moves? Cost of the cascade? |
| **Architectural fit** | Does it match swift-kernel's stated mission? |
| **Import ergonomics** | Does moving it fragment `import Kernel`? |
| **Precedent** | Does the Executor extraction set a pattern to follow? |

---

### Category 1: Clearly kernel-intrinsic types

These types wrap individual syscalls or provide direct kernel vocabulary. No analysis needed — they stay.

| Type | Files | Wraps | Verdict |
|------|-------|-------|---------|
| `Kernel.Failure` | 1 | Error aggregation boundary | **STAY** |
| `Kernel.Readiness.*` | 14 | kqueue/epoll event driver | **STAY** |
| `Kernel.File.Open` | 2 | `open(2)` | **STAY** |
| `Kernel.File.Clone` | 1 | `clonefile(2)` | **STAY** |
| `Kernel.File.Copy` | 1 | `copyfile(2)` | **STAY** |
| `Kernel.System.Processor.Count` | 1 | `sysconf`/`sysctl` | **STAY** |
| `Kernel.System.Processor.Physical.Count` | 1 | `sysconf`/`sysctl` | **STAY** |
| `Kernel.System.Memory.Total` | 1 | `sysconf`/`sysctl` | **STAY** |
| `Kernel.Thread.Handle` | 2 | `pthread_t` | **STAY** |
| `Kernel.Thread.spawn/trap` | 2 | `pthread_create` | **STAY** |
| `Kernel.Thread.Affinity` | 1 | `pthread_setaffinity` | **STAY** |
| `Kernel.Thread.Count` | 1 | Vocabulary type | **STAY** |
| `Kernel.Lock.Acquire` | 1 | `fcntl` locking | **STAY** |

---

### Category 2: Kernel.Thread.Synchronization\<N\>

**Implementation**: Composes `Kernel.Thread.Mutex` (wraps `pthread_mutex_*`) and N `Kernel.Thread.Condition` objects (wraps `pthread_cond_*`) using `InlineArray<N, Condition>`. Adds waiter tracking, broadcast-all, and conditional signaling. ~256 LOC.

**Nature**: One hop above raw syscalls. The generic N parameter provides compile-time safety for condition count (zero-allocation `InlineArray`), but the actual operations delegate directly to Mutex.lock/unlock and Condition.wait/signal/broadcast. No policy decisions, no state machines, no retry logic.

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Close** — one level above raw pthread. All operations delegate directly to Mutex/Condition. |
| Consumer breadth | **Wide** — swift-io (event loop, blocking lanes, completions), swift-executors. Dependency root for Barrier, Gate, Semaphore, Worker, Executor. |
| Dependency impact | **Critical** — moving cascades to every type that uses it. Barrier, Gate, Semaphore, Worker, and Executor all depend on it. |
| Architectural fit | **Ambiguous** — not a single syscall, but the thinnest possible composition of two syscall wrappers. |
| Import ergonomics | Moving would require every user of `Kernel.Thread.Synchronization` to import an additional module. |
| Precedent | Executor moved, but Executor was 2 hops from syscalls (Executor → Synchronization → Mutex/Condition). Synchronization is 1 hop. |

**Assessment**: Synchronization\<N\> is the boundary case. It composes two syscall wrappers with no added policy. The generic N parameter is a type-level optimization, not a semantic decision. Compare: Rust's `parking_lot::Condvar` is a separate crate from `mio`, but it's also a standalone crate — not part of the runtime. In our architecture, moving Synchronization would cascade to 5+ types and 2 packages. The migration cost exceeds the architectural clarity gained.

**Verdict**: **REDEFINE** — Keep in swift-kernel. Update mission to encompass "direct compositions of OS threading primitives."

---

### Category 3: DualSync / SingleSync

**Implementation**: Pure typealiases.

```swift
public typealias DualSync = Synchronization<2>
public typealias SingleSync = Synchronization<1>
```

~43 LOC combined (including `DualSync.Broadcast` convenience extension of 8 LOC).

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | Same as Synchronization — zero-cost alias. |
| Consumer breadth | `DualSync`: used by swift-io (blocking threads, lanes). `SingleSync`: no external consumers. |
| Dependency impact | Moving creates no new dependencies — they follow Synchronization. |

**Verdict**: **REDEFINE** — Follow Synchronization. These are zero-cost typealiases.

---

### Category 4: Kernel.Thread.Barrier

**Implementation**: Composes `SingleSync` (= `Synchronization<1>`). Manages `_arrived` counter, `target` count, and `_released` boolean. Waits until all N threads arrive, then broadcasts. ~80 LOC.

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Two hops** — Barrier → SingleSync → Mutex/Condition. |
| Consumer breadth | **Narrow** — swift-io tests only. No production use outside swift-kernel. |
| Dependency impact | **Low** — only test code references it. |
| Architectural fit | **Borderline** — classical thread coordination primitive. Simple enough to be infrastructure. |

**Assessment**: At 80 LOC with no external production consumers, this is the simplest type in the coordination family. It's a textbook barrier — the kind of type that Go puts in `sync` (its stdlib) and Rust puts in `std::sync`. Moving it gains nothing: no consumer would import the destination package just for Barrier, and it has no production dependents.

**Verdict**: **REDEFINE** — Keep in swift-kernel. Too simple and too narrowly consumed to justify relocation.

---

### Category 5: Kernel.Thread.Gate

**Implementation**: Composes `SingleSync` (= `Synchronization<1>`). Manages `_isOpen` boolean. One-shot blocking primitive. ~104 LOC.

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Two hops** — Gate → SingleSync → Mutex/Condition. |
| Consumer breadth | **Narrow** — swift-io tests only. No production use outside swift-kernel. |
| Dependency impact | **Low** — only test code references it. |
| Architectural fit | **Borderline** — simpler than Barrier. |

**Assessment**: Same reasoning as Barrier. Even simpler. Go's `sync.Once` and Java's `CountDownLatch(1)` are stdlib/juc types.

**Verdict**: **REDEFINE** — Keep in swift-kernel. Same reasoning as Barrier.

---

### Category 6: Kernel.Thread.Semaphore

**Implementation**: Composes `DualSync` (= `Synchronization<2>`, dual conditions: available + shutdown). 11 files, ~725 LOC. Substantial state machine:

- Three-state lifecycle: `open` → `closing` → `closed`
- `State` struct tracking available, outstanding, waiters, lifecycle, metrics
- `Effect` enum for signal/broadcast decisions
- `Metrics` for operational telemetry (acquisitions, releases, rejections, timeouts, peak)
- Three `Run` accessor patterns: basic, timeout, cancellable
- `Cancellation.Storage` with atomic flag
- Graceful shutdown with outstanding permit draining

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Three hops** — Semaphore → DualSync → Synchronization → Mutex/Condition. |
| Consumer breadth | **None external** — no production consumers outside swift-kernel yet. |
| Dependency impact | **None** — no package depends on it. |
| Architectural fit | **Poor under current mission** — 725 LOC with state machines, metrics, and cancellation is not "policy-free." |
| Architectural fit (redefined) | **Acceptable** — thread-level blocking semaphore, distinct from `Async.Semaphore` (L1). The kernel semaphore specifically manages OS thread blocking, which is kernel-adjacent. |

**Assessment**: This is the strongest candidate for relocation. At 725 LOC with metrics, cancellation, and a three-state lifecycle, it goes well beyond syscall wrapping. However, three factors argue for keeping it:

1. **No external consumers yet** — moving it costs effort with zero migration benefit.
2. **Distinct from Async.Semaphore** — the kernel semaphore blocks OS threads via pthread_cond_wait; the async semaphore suspends Swift tasks. They serve different layers.
3. **Natural dependency chain** — it builds on DualSync which builds on Synchronization, forming a coherent thread-coordination stack within swift-kernel.

The counter-argument: if consumers emerge, they'll depend on swift-kernel for a type that arguably belongs elsewhere. But that future dependency can be broken by extraction when the need arises — an extraction with zero migration cost (no current consumers to update).

**Verdict**: **REDEFINE** — Keep in swift-kernel for now. The thread-coordination stack (Synchronization → DualSync/SingleSync → Barrier/Gate/Semaphore) forms a coherent unit. Revisit if external consumers emerge, at which point the consumer pattern will inform the right destination.

---

### Category 7: Kernel.Thread.Worker

**Implementation**: Composes `Kernel.Thread.Handle` (wraps `pthread_t`) + `Kernel.Thread.Worker.Token` (shared stop-request signaling). `~Copyable` for single-owner semantics. ~139 LOC.

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **One hop** — Worker → Handle (= pthread_t) + spawn (= pthread_create). |
| Consumer breadth | **None external** — no production consumers outside swift-kernel. |
| Dependency impact | **None**. |
| Architectural fit | **Good** — managed thread lifecycle is kernel-level infrastructure. |

**Assessment**: Worker is a thin lifecycle wrapper around Handle + spawn. It's analogous to `std::thread` in Rust or `java.lang.Thread` in Java — a managed thread type that belongs with thread primitives. The `~Copyable` ownership is a compile-time safety layer, not a policy decision.

**Verdict**: **REDEFINE** — Keep in swift-kernel. Thread lifecycle management is core kernel infrastructure.

---

### Category 8: Kernel.Continuation.Context

**Implementation**: Atomic state machine for exactly-once callback/continuation resumption. Uses `Synchronization.Atomic<State>` (Apple's Synchronization module). State enum: `pending` → `completed|cancelled|failed`. 167 LOC. 1 source file + namespace enum + exports = 3 files in its own target.

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **None** — no syscall involvement. Uses Swift's `Atomic` from the Synchronization module. |
| Consumer breadth | **Zero** — no source code consumers anywhere in the workspace. Referenced only in swift-io research documents (synchronous-run-overload.md, audit.md, benchmark-fairness-audit.md) but never adopted. |
| Dependency impact | **None** — nothing depends on it. |
| Architectural fit | **Poor** — has zero kernel/OS relationship. It's a concurrency utility for bridging async/sync boundaries. |

**Assessment**: This type was designed for swift-io's blocking lane infrastructure but was never adopted. swift-io chose a superior architecture: the poll thread acts as exclusive arbiter, and `~Copyable` + `consuming` provides compile-time exactly-once guarantees — no atomic CAS needed.

swift-io's actual patterns:
- **`IO.Completion.Entry`**: `~Copyable` struct owns `CheckedContinuation<Void, Never>?` directly. `consuming func resolve()` enforces exactly-once at compile time. Poll thread is sole arbiter — no racing paths, no atomics.
- **`IO.Completion.Queue`** / **`IO.Handle.Registry`**: Use `withCheckedContinuation` directly.
- **`IO.Completion.Cancellation.Flag`**: Simple `Atomic<Bool>` for signaling — not a state machine.

The pattern `Continuation.Context` captures (multi-path racing resumption via atomic CAS) is real but ~20 lines of CAS logic — trivially inlinable if any future consumer genuinely has racing resumption paths without a single-arbiter architecture. No consumer in the ecosystem needs it today, and the ecosystem's architecture (poll-thread arbiter + `~Copyable`) has made it unnecessary.

**Verdict**: **REMOVE** — Delete the Kernel Continuation target entirely. Zero consumers, superseded by a better pattern, not kernel-related, and simple enough to recreate if ever needed.

---

### Category 9: Kernel.File.Write.Atomic

**Implementation**: Major composed strategy implementing crash-safe atomic writes. 10 files, ~900 LOC. Composes 6+ syscalls in a multi-phase pipeline:

1. Create temp file (open + random token generation)
2. Write all data (write loop)
3. Sync file to disk (fsync / F_FULLFSYNC / fdatasync — configurable durability)
4. Preserve metadata (fchmod, fchown, futimens — optional)
5. Atomic rename (rename / renameat2 RENAME_NOREPLACE)
6. Sync directory (fsync on parent dir)

Includes:
- 13 error cases with semantic accessors
- `Commit.Phase` enum tracking 7-phase progress for postmortem diagnostics
- `TempFile` struct with `~Copyable` descriptor ownership
- `Options` with strategy (replaceExisting/noClobber), durability, preservation, ownership
- Platform-specific path handling (Windows backslash normalization)

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Far** — composes 6+ syscalls with substantial policy (durability levels, metadata preservation, no-clobber strategy). |
| Consumer breadth | **Narrow** — only swift-file-system (via typealias re-exports). |
| Dependency impact | **Low** — only swift-file-system uses it, and already depends on swift-kernel. |
| Architectural fit | **Poor** — the README says "no policy, no retry logic." This type has retry logic (temp file creation), durability policy, metadata preservation policy, and clobber strategy. |
| Precedent | Compare to Readiness.* (event driver): that's also a multi-syscall composition, but it abstracts kqueue/epoll which are inherently kernel concerns. File writing strategy is file-system domain logic. |

**Assessment**: This is the largest composed abstraction in swift-kernel and the clearest violation of its stated mission. At 900 LOC with policy decisions (durability levels, preservation options, clobber strategies), it embodies exactly what "policy-free syscall wrappers" is not.

The natural destination is swift-file-system, which is already the sole consumer and already re-exports these types via typealiases. The move would internalize rather than add dependencies. The types would continue extending `Kernel.File.Write` via namespace extension from swift-file-system, maintaining the same API surface for consumers of `import File_System`.

**Verdict**: **MOVE** to swift-file-system. Already the sole consumer. Internalizes rather than creates dependencies. The namespace extension pattern (proven by the executor extraction) preserves the API surface.

---

### Category 10: Kernel.File.Write.Streaming

**Implementation**: Modular composed strategy for streaming file writes. 13 files, ~600+ LOC. Policy-based design with two commit modes:

- **Atomic** mode: temp file + rename (crash-safe, same pattern as Write.Atomic)
- **Direct** mode: write directly to destination (fast, no crash-safety)

Includes:
- `Context` struct (`~Copyable`) holding state across open → write → commit phases
- `Commit.Policy` selector between atomic and direct
- `Options` per mode (durability, preallocation hints)
- Error type with 10+ cases and semantic accessors
- Platform-specific `fcntl(F_PREALLOCATE)` for macOS

| Criterion | Assessment |
|-----------|------------|
| Syscall proximity | **Far** — same multi-syscall composition as Atomic, plus streaming/chunking and preallocation policy. |
| Consumer breadth | **Narrow** — only swift-file-system (extensive typealias re-exports and direct use). |
| Dependency impact | **Low** — same as Atomic. |
| Architectural fit | **Poor** — same reasoning as Atomic. |

**Assessment**: Same reasoning as Write.Atomic. The streaming architecture adds another layer of policy (chunk-based writing, preallocation, direct vs. atomic mode selection). Same sole consumer, same re-export pattern.

**Verdict**: **MOVE** to swift-file-system. Co-locates with Write.Atomic. Same reasoning.

---

### Category 11: Shared Write Infrastructure

Five files support both Atomic and Streaming:

| File | LOC | Content |
|------|-----|---------|
| `Kernel.File.Write.swift` | ~20 | Namespace enum |
| `Kernel.File.Write+Shared.swift` | ~399 | Path resolution, writeAll, syncFile, randomToken, atomicRename |
| `Kernel.File.Write.Error.swift` | ~30 | Shared error enum |
| `Kernel.File.Write.Durability.swift` | ~36 | Durability enum (full/data/none) |
| `Swift.String+Kernel.swift` | ~15 | String extension for path handling |

**Assessment**: These files are shared infrastructure for Atomic and Streaming. They should move with their consumers.

**Verdict**: **MOVE** to swift-file-system together with Atomic and Streaming. Total: ~27 files relocating from `Kernel File` target.

---

### Category 12: Kernel.Handoff.Cell

**Assessment**: Listed in the README Key Types table but does not exist in source. Zero source files, zero references.

**Verdict**: **REMOVE** from README. Stale reference.

---

### Summary comparison

| Type | Files | LOC | Syscall Hops | External Consumers | Verdict |
|------|-------|-----|-------------|-------------------|---------|
| Kernel-intrinsic (13 types) | 26 | — | 0-1 | Various | **STAY** |
| Synchronization\<N\> | 2 | ~350 | 1 | swift-io, swift-executors | **REDEFINE** |
| DualSync / SingleSync | 3 | ~43 | 1 (alias) | swift-io | **REDEFINE** |
| Barrier | 1 | ~80 | 2 | swift-io tests | **REDEFINE** |
| Gate | 1 | ~104 | 2 | swift-io tests | **REDEFINE** |
| Semaphore | 11 | ~725 | 3 | None | **REDEFINE** |
| Worker | 2 | ~139 | 1 | None | **REDEFINE** |
| Continuation.Context | 3 | ~167 | None | None (zero consumers) | **REMOVE** — unused, superseded |
| File.Write.Atomic | 10 | ~900 | Far | swift-file-system | **MOVE** → swift-file-system |
| File.Write.Streaming | 13 | ~600+ | Far | swift-file-system | **MOVE** → swift-file-system |
| Write shared infra | 5 | ~500 | Mixed | (supports Atomic/Streaming) | **MOVE** → swift-file-system |
| Handoff.Cell | 0 | 0 | N/A | None | **REMOVE** from README |

---

## Prior Art Survey

Per [RES-021], this section surveys how comparable ecosystems separate syscall wrappers from composed synchronization primitives and file strategies.

### Rust

| Layer | Crate | Contains | Analogue |
|-------|-------|----------|----------|
| Syscall wrappers | `mio` | epoll/kqueue/IOCP, non-blocking I/O registration | swift-kernel Readiness.* |
| OS thread sync | `std::sync` | Mutex, Condvar, Barrier, Once, RwLock | swift-kernel Synchronization, Barrier, Gate |
| Userspace sync | `parking_lot` | Fast Mutex, Condvar, RwLock, Once | (not applicable) |
| Async runtime sync | `tokio::sync` | Semaphore, Mutex, Barrier, Notify, mpsc | swift-executors domain |
| File I/O strategies | `std::fs` / `tempfile` + `atomicwrites` | Atomic write via tempfile+rename | swift-kernel File.Write.Atomic |

**Key insight**: Rust places OS-level synchronization primitives (Mutex, Condvar, Barrier) in `std::sync` — the standard library — because they're considered fundamental infrastructure, not application-level concerns. `mio` (the syscall wrapper) never provides composed synchronization. Atomic file writes are handled by third-party crates, separate from both syscall wrappers and sync primitives.

### Go

| Layer | Package | Contains | Analogue |
|-------|---------|----------|----------|
| Syscall wrappers | `syscall` / `golang.org/x/sys` | Raw syscall interfaces | swift-kernel-primitives (L1) |
| OS thread sync | `sync` | Mutex, RWMutex, WaitGroup, Once, Cond, Pool | swift-kernel Synchronization, Barrier |
| Async/goroutine sync | `sync`, channels | Channel-based coordination | L1 Async.* |
| File I/O strategies | `os`, `io/ioutil` | `os.Rename`, `ioutil.TempFile` (manual composition) | swift-kernel File.Write.Atomic |
| Internal I/O infra | `internal/poll` | epoll/kqueue wrappers | swift-kernel Readiness.* |

**Key insight**: Go keeps all synchronization primitives in `sync`, firmly in the standard library. The `syscall` package provides raw wrappers; `sync` provides composed coordination. These are separate packages. Go has no stdlib atomic-write primitive — users compose it manually from `os.TempDir`/`os.Rename`.

### Java

| Layer | Package | Contains | Analogue |
|-------|---------|----------|----------|
| Low-level I/O | `java.nio` | Channels, selectors, buffers | swift-kernel Readiness.* |
| Thread sync | `java.util.concurrent` | Semaphore, CountDownLatch, CyclicBarrier, Phaser | swift-kernel Semaphore, Gate, Barrier |
| Locks | `java.util.concurrent.locks` | ReentrantLock, Condition, ReadWriteLock | swift-kernel Synchronization |
| Atomics | `java.util.concurrent.atomic` | AtomicInteger, AtomicReference | Apple's Synchronization module |
| File operations | `java.nio.file` | Files.move(ATOMIC_MOVE), StandardOpenOption | swift-kernel File.Write.Atomic |

**Key insight**: Java separates I/O primitives (`java.nio`) from synchronization (`java.util.concurrent`) from file operations (`java.nio.file`). The separation is by domain: I/O primitives, thread coordination, and file strategies are three distinct packages. Atomic file moves are in `java.nio.file`, not in the channel/selector package.

### Contextualization per [RES-021]

The prior art consensus is:

1. **All surveyed ecosystems separate syscall wrappers from composed synchronization.** However, the composed synchronization lives at the *language standard library* level in all three cases (Rust `std::sync`, Go `sync`, Java `j.u.c`). Our ecosystem lacks a stdlib-level sync package, so the closest equivalent is swift-kernel itself, which is the L3 unification layer — the first place all thread primitives converge.

2. **All surveyed ecosystems separate file writing strategies from I/O infrastructure.** Rust uses third-party crates, Go requires manual composition, Java uses `java.nio.file`. None place atomic write strategies in their syscall wrapper or I/O selector package.

3. **Basic synchronization primitives (Mutex+Condvar, Barrier, Gate/Latch) universally live close to the threading layer**, not in application-level packages. Moving them to a separate package would be unusual across all three ecosystems — they are considered fundamental.

**Ecosystem-specific conclusion**: The absence of a separate `swift-synchronization` package is *not* a gap. It reflects the fact that in our architecture, swift-kernel serves as the L3 unification layer where OS-level thread coordination naturally resides — analogous to `std::sync` being part of Rust's standard library. The gap is in file writing strategies: those belong with file-system operations, not with kernel-level thread coordination.

---

## Outcome

**Status**: RECOMMENDATION

### Mission redefinition

swift-kernel's mission should be updated from:

> Policy-free syscall wrappers

To:

> OS-level primitives and their direct thread-coordination compositions. Provides raw descriptors, typed throws, unified error types, and the foundational thread-synchronization building blocks that higher-level concurrency and I/O packages compose upon.

This explicitly encompasses Synchronization\<N\>, Barrier, Gate, Semaphore, Worker, and DualSync/SingleSync as legitimate residents.

**Justification**: The thread-coordination stack (Synchronization → DualSync/SingleSync → Barrier/Gate/Semaphore) forms a coherent dependency chain rooted in OS thread primitives (Mutex, Condition). These types are *infrastructure* for higher layers (swift-executors, swift-io), not application-level constructs. All surveyed ecosystems keep this infrastructure close to the threading layer.

### Removals

#### 1. Kernel.Continuation.Context — DELETE

- **3 files** (Kernel Continuation target: `Kernel.Continuation.Context.swift`, `Kernel.Continuation.swift`, `exports.swift`)
- **Reason**: Zero source code consumers anywhere in the workspace. Designed for swift-io's blocking lane infrastructure but never adopted — swift-io chose a superior pattern (`~Copyable` + `consuming` for compile-time exactly-once, poll thread as exclusive arbiter). The atomic CAS pattern it captures is ~20 lines and trivially recreatable if a future consumer genuinely has racing resumption paths without a single-arbiter architecture.
- **Migration cost**: Zero — nothing depends on it.
- **Also remove**: `Kernel.Continuation.Context` entry from README Key Types table.

### Relocations

#### 1. Kernel.File.Write.{Atomic, Streaming, shared} → swift-file-system

- **~27 files** (subset of Kernel File target)
- **Reason**: Major composed strategies with policy decisions (durability levels, metadata preservation, clobber strategies, preallocation hints). Violates "no policy, no retry logic."
- **Migration cost**: Low. Sole consumer (swift-file-system) already re-exports these types via typealiases. After the move, swift-file-system owns them directly and the typealiases become unnecessary.
- **API preservation**: Define in swift-file-system via `extension Kernel.File.Write { }`. The `Kernel` namespace is available through swift-file-system's existing dependency on swift-kernel. Consumers see the same API surface through `import File_System` or `import Kernel`.
- **Remaining in Kernel File target**: 6 files — `Kernel.File.Open` (2 files), `Kernel.File.Clone`, `Kernel.File.Copy`, `Swift.String+Kernel.swift`, `exports.swift`. These are genuine syscall wrappers.

### README update

Remove from the Key Types table:
- `Kernel.Handoff.Cell` — does not exist in source.
- `Kernel.Continuation.Context` — being deleted.

### Post-relocation package shape

| Target | Files | Content |
|--------|-------|---------|
| Kernel Core | 16 | Unchanged |
| Kernel System | 4 | Unchanged |
| Kernel Thread | 29 | Unchanged (Synchronization family stays) |
| Kernel File | 6 | Open, Clone, Copy (syscall wrappers only) |
| ~~Kernel Continuation~~ | ~~3~~ | Deleted (zero consumers, superseded pattern) |
| Kernel (Umbrella) | 1 | Unchanged (re-exports adjusted) |
| **Total** | **53** | Down from 85 |

### Revisit triggers

- **Semaphore**: If external consumers emerge, evaluate whether it should follow Executor to swift-executors or to a new `swift-synchronization` package.
- **Barrier/Gate**: If production (non-test) consumers emerge, re-evaluate placement.
- **Mission scope**: If new composed types are proposed for swift-kernel, evaluate them against the redefined mission. The test: "Is this a direct composition of OS thread primitives with no policy decisions?"

## References

- Parnas, D. L. (1972). "On the Criteria To Be Used in Decomposing Systems into Modules." Communications of the ACM.
- Rust `std::sync` — https://doc.rust-lang.org/std/sync/
- Go `sync` package — https://pkg.go.dev/sync
- Java `java.util.concurrent` — https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/package-summary.html
- HANDOFF-swift-executors-consolidation.md — Executor extraction precedent
