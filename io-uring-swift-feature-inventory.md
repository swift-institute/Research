# IO Uring: Swift Feature Inventory for Implementation

<!--
---
version: 1.0.0
last_updated: 2026-04-10
status: RECOMMENDATION
---
-->

## Context

This document identifies existing Swift Institute research and experiments that are directly relevant to implementing io_uring in Swift. It bridges the io_uring API reference (`linux-io-uring-api-reference.md`), the four implementation studies (Zig, TigerBeetle, Rust, liburing), and the Swift ecosystem's accumulated knowledge about ~Copyable, ~Escapable, atomics, typed throws, witnesses, and concurrency.

The purpose is to provide a complete map from "what io_uring needs" to "what Swift features enable it" to "what we already know about those features" — so the implementation design can build on verified findings rather than re-investigating settled questions.

## Question

Which existing research and experiments are relevant inputs for designing a Swift io_uring implementation, and how does each map to a specific io_uring concern?

---

## 1. ~Copyable Types (Ownership)

**io_uring need**: The ring struct owns an fd + mmap regions. Completion structs are intrusive, caller-owned nodes. SQE preparation produces tokens that should be consumed by submission. The Mmap wrapper must munmap before close (drop ordering).

**Why it matters**: All four implementation studies identify ownership as the primary safety mechanism. Rust's `IoUring` owns `OwnedFd` + `ManuallyDrop<MemoryMap>`. Zig uses `errdefer` for cleanup on failure paths. TigerBeetle's caller-owned `Completion` struct eliminates per-I/O allocation.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `noncopyable-ecosystem-state.md` | swift-institute/Research/ | Consolidated ~Copyable state. Subsumes ownership-transfer-patterns. Canonical patterns for consuming through closures (Mutex.withLock). |
| `noncopyable-ownership-transfer-patterns.md` | swift-institute/Research/ | Three canonical patterns for `~Copyable` through `Mutex.withLock`. Pattern 1 (always-consume) maps to SQE submission consuming the entry. |
| `witness-ownership-integration.md` | swift-institute/Research/ | Witness types with ~Copyable values. Directly applies to opcode witnesses that produce ~Copyable SQE entries. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `noncopyable-inline-deinit` | swift-institute/Experiments/ | FIXED 6.2.4 | ~Copyable inline storage deinit works. Ring struct can have inline storage with deinit for munmap+close. |
| `noncopyable-throwing-init` | swift-institute/Experiments/ | CONFIRMED | `throw` before/after init, `self = try factory()`, Optional ~Copyable — all work. Ring init (which can fail with typed errors) is safe. |
| `noncopyable-nested-deinit-chain` | swift-buffer-primitives/Experiments/ | MOVED | Nested deinit ordering. Critical for munmap-before-close (Rust's ManuallyDrop pattern). |
| `noncopyable-operation-closure-pipeline` | swift-institute/Experiments/ | CONFIRMED (13/14) | ~Copyable Sendable Operation through stored closure pipeline. Directly validates the completion callback model. |
| `sending-mutex-noncopyable-region` | swift-institute/Experiments/ | CONFIRMED (5/23) | Slot pattern for extracting ~Copyable from Mutex. Relevant if ring state needs synchronized access. |
| `noncopyable-access-patterns` | swift-institute/Experiments/ | CONSOLIDATED | Consuming, borrowing, iteration patterns for ~Copyable. CQE batch draining uses consuming iteration. |
| `consuming-iteration-pattern` | swift-institute/Experiments/ | SUPERSEDED → noncopyable-access-patterns | Property.View consuming accessor. Maps to CQE iteration that consumes entries. |
| `foreach-consuming-accessor` | swift-institute/Experiments/ | SUPERSEDED → noncopyable-access-patterns | `.forEach.consuming` accessor. Pointer-based consuming (V7) optimal — relevant for CQE batch processing. |

### Design Implication

The ring struct (`IO.Uring`) should be `~Copyable` with a `deinit` that calls `munmap` then `close`. The deinit ordering concern (munmap before close) is addressable via explicit field ordering in deinit, validated by the nested-deinit-chain experiment. TigerBeetle's `Completion` struct maps to a `~Copyable` Swift type with intrusive linked-list links.

---

## 2. ~Escapable Types (Borrowed Access)

**io_uring need**: CQEs are borrowed views into shared ring memory — valid only until `cq_advance()`. Rust's `SubmissionQueue<'a>` is a short-lived borrowed view with cached head/tail. Provided buffer references from CQEs are valid only until the buffer is returned to the ring.

**Why it matters**: The liburing study identifies CQE lifetime as the single largest source of io_uring bugs in C. The Zig study's `copy_cqes` pattern (copy 16-byte CQEs to avoid lifetime bugs) is a safety trade-off. ~Escapable could provide a zero-copy alternative with compile-time enforcement.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `nonescapable-ecosystem-state.md` | swift-institute/Research/ | Consolidated ~Escapable state. Current blockers: `UnsafePointer<T>` requires `T: Escapable` (SE-0465 deferred). |
| `nonescapable-storage-mechanisms.md` | swift-institute/Research/ | Exhaustive storage mechanism test (17 variants). Enum-based variable-occupancy works. `@_rawLayout` declaration works; element access blocked. |
| `span-view-integration-strategy.md` | swift-institute/Research/ | Span/View integration. `@_lifetime` propagation patterns for borrowed access. |
| `owned-typed-memory-region-abstraction.md` | swift-institute/Research/ | `Memory.Contiguous<Element>` as owned typed region with Span access. Direct stored property access works for `@_lifetime` propagation. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `nonescapable-patterns` | swift-institute/Experiments/ | CONSOLIDATED (7 experiments) | ~Escapable accessor, storage, protocol, lazy sequence, pointer patterns. Validates scoped CQE view feasibility. |
| `pointer-nonescapable-storage` | swift-institute/Experiments/ | SUPERSEDED → nonescapable-patterns | 17 storage variants tested. Enum-based (V14/V15) work. Current limitation: heap-backed containers blocked for ~Escapable elements. |
| `memory-contiguous-owned` | swift-institute/Experiments/ | CONFIRMED (11/11) | `Memory.Contiguous<Element>` with Span access, deinit, Sendable. Direct stored property access for `@_lifetime`. Maps to owned mmap regions. |
| `tagged-escapable-accessor` | swift-institute/Experiments/ | 2 CONFIRMED / 3 REFUTED | Public stored property `rawValue` propagates `@_lifetime` correctly; `_read` coroutine blocks it across package boundaries. |
| `escapable-protocol-navigation` | swift-institute/Experiments/ | CONFIRMED (7/7) | ~Copyable + ~Escapable type conforming to protocol with `@_lifetime` Span returns. Validates CQE view as protocol conformer. |
| `mutablespan-async-read` | swift-institute/Experiments/ | — | MutableSpan for async reads. Relevant for buffer management. |
| `resumption-nonescapable-noncopyable` | swift-institute/Experiments/ | CONFIRMED (pattern works; deployment reverted) | `~Copyable + ~Escapable` Resumption type. Validates dual-suppressed types but notes heap storage requires Escapable. |

### Design Implication

Two strategies for CQE access:

**Strategy A (Safe default — Zig's approach)**: Copy CQEs to caller buffer via `copy_cqes`. Avoids ~Escapable complexity entirely. 16 bytes per CQE is trivial.

**Strategy B (Zero-copy advanced path)**: ~Escapable `CompletionQueue.View` type with `@_lifetime` scoping. Validated by `nonescapable-patterns` and `escapable-protocol-navigation`. However, the pointer-to-~Escapable blocker (UnsafePointer requires Escapable) means this would need `withUnsafeBufferPointer`-style scoped access, not stored ~Escapable views.

**Recommendation**: Implement Strategy A (copy) as the primary API. Strategy B can be added later as the ~Escapable story matures.

---

## 3. Atomics and Memory Ordering

**io_uring need**: Acquire/release on ring head/tail. Relaxed loads on SQ flags. A single SeqCst fence for the SQPOLL wakeup race. All four implementation studies agree on exactly these orderings — no more, no less.

**Why it matters**: The Rust study documents the SQPOLL wakeup race in detail: without a SeqCst fence, the kernel thread can sleep permanently. The liburing study shows that C11 atomics fully suffice (no architecture-specific barriers needed).

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `kernel-atomic-memory-ordering.md` | swift-primitives/Research/ | **Directly about this.** Kernel.Atomic was unsound on ARM64 — `@_optimize(none)` compiler barrier replaced with `<stdatomic.h>` C shim. Validated that C11 atomics via C shim provide correct acquire/release semantics. |

### Design Implication

Use the `CCPUShim` atomics infrastructure already in swift-cpu-primitives. The five operations needed:
1. `atomicLoad(.acquiring)` — read other side's head/tail
2. `atomicStore(.releasing)` — publish our head/tail
3. `atomicLoad(.relaxed)` — read SQ flags (advisory)
4. `atomicFence(.sequentiallyConsistent)` — SQPOLL wakeup race (exactly once)
5. Non-atomic read of our own head/tail (we are sole writer)

The `kernel-atomic-memory-ordering.md` research confirms this exact pattern works correctly on ARM64 with the C shim approach.

---

## 4. Typed Throws

**io_uring need**: Per-operation error types. TigerBeetle defines `ReadError`, `AcceptError`, `ConnectError`, etc. with exhaustive errno mapping. Zig defines named error sets per syscall. `[API-ERR-001]` requires typed throws.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `typed-throws-mixed-error-domains.md` | swift-institute/Research/ | How to type mixed error domains. Pattern: aggregate functions wrapping multiple typed-throws sub-operations use a unified error enum. Each io_uring operation gets its own error type; the ring-level submit returns a submit-specific error. |
| `typed-throws-standards-inventory.md` | swift-institute/Research/ | Cross-repo typed throws migration tracker. Patterns for exhaustive errno mapping. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `declarative-parser-typed-throws` | swift-institute/Experiments/ | PARTIAL | `var body` incompatible with typed throws. Validates per-stage error types with `@_disfavoredOverload` for ambiguity resolution. |
| `noncopyable-throwing-init` | swift-institute/Experiments/ | CONFIRMED | ~Copyable throwing init works — validates ring init with typed errors. |

### Design Implication

Three error layers:
- `IO.Uring.Setup.Error` — from `io_uring_setup` (EINVAL, ENOMEM, EPERM, etc.)
- `IO.Uring.Enter.Error` — from `io_uring_enter` (EAGAIN, EBUSY, EBADR, etc.)
- Per-operation: `IO.Uring.Read.Error`, `IO.Uring.Accept.Error`, etc. — from CQE `res` field

This matches TigerBeetle's pattern exactly and satisfies `[API-ERR-001]`.

---

## 5. Witness Pattern (Opcode Builders)

**io_uring need**: Each of 65 operations needs a type-safe builder that fills the correct SQE fields. Rust uses macro-generated opcode structs. Zig uses prep methods on the SQE. The @Witness macro could generate Action enums and forwarding.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `witness-macro-io-drivers-assessment.md` | swift-institute/Research/ | **Directly about IO drivers.** Assessed @Witness for `IO.Event.Driver` and `IO.Completion.Driver`. Both use ~Copyable Handle types with borrowing/consuming conventions. Conclusion: macro adds incremental value over manual forwarding for these types. |
| `witness-ownership-integration.md` | swift-institute/Research/ | Witness + ~Copyable integration. Consolidated findings. |
| `witness-noncopyable-nonescapable-support.md` | swift-institute/Research/ | Witness DI with ~Copyable/~Escapable values. WitnessProjectable pattern for Copyable projections of ~Copyable types. |
| `witness-macro-noncopyable-support-design.md` | swift-institute/Research/ | Revised from DEFERRED to VIABLE. Projection pattern works. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `witness-macro-noncopyable-feasibility` | swift-institute/Experiments/ | CONFIRMED (11/12) | @Witness macro + ~Copyable via Projection pattern. Borrowing/consuming forwarding through closure wrappers. Typed throws requires explicit closure annotations. |
| `witness-noncopyable-value-feasibility` | swift-institute/Experiments/ | CONFIRMED | ~Copyable witness value: `associatedtype Value: ~Copyable`, closure-scoped borrowing, constrained get + universal withValue. |
| `canonical-witness-capability` | swift-institute/Experiments/ | CONFIRMED (10/10) | Protocol canonical + witness alternatives. Validates the pattern for opcode factories. |

### Design Implication

Two viable approaches for opcode types:

**Approach A (Manual prep methods — Zig model)**: Methods on `IO.Uring.Submission.Entry` (the SQE wrapper). Each `prepare.read(...)` fills the correct fields. Simple, no macro dependency, proven pattern.

**Approach B (Witness structs — Rust model)**: Each opcode as a struct (`IO.Uring.Opcode.Read`, `IO.Uring.Opcode.Accept`, etc.) with required fields at init and optional fields as properties. A `build()` method produces the SQE entry. Maps to the existing @Witness infrastructure.

Approach A is more appropriate for L1 primitives (minimal abstraction). Approach B suits L3 foundations.

---

## 6. C Shim Architecture

**io_uring need**: Three syscalls + kernel struct definitions must be callable from Swift. The SQE has 6 anonymous C unions.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `c-shim-placement-architecture.md` | swift-institute/Research/ | **Directly relevant.** Documents that `CLinuxKernelShim` in swift-linux-primitives already wraps io_uring syscalls (listed in inventory: "io_uring_*"). Platform packages own their C shims. |

### Design Implication

`CLinuxKernelShim` already exists and wraps io_uring syscalls. The shim needs to expose:
- `io_uring_setup`, `io_uring_enter`, `io_uring_register` (may already exist)
- Struct definitions for `io_uring_sqe`, `io_uring_cqe`, `io_uring_params`
- All `IORING_*` constants

The Zig approach (redefine structs natively, flatten unions) is preferred over importing C unions directly. The C shim provides only the syscall entry points; Swift defines the struct layout independently.

---

## 7. Zero-Copy Event Pipeline

**io_uring need**: Event loop architecture for CQE draining, callback dispatch, and overflow management. TigerBeetle's three-queue model (ring + unqueued + completed) with batch CQE draining.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `zero-copy-event-pipeline.md` | swift-institute/Research/ | Pool-based buffer management for event batches. Producer→consumer pipeline with bounded buffer pool. Directly applicable to CQE batch management. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `zero-copy-event-pipeline-validation` | swift-institute/Experiments/ | — | Validation of the zero-copy pipeline architecture. |

### Design Implication

The existing zero-copy event pipeline research provides the architectural template for the CQE draining path. The key insight from TigerBeetle — small ring (32) + userspace overflow queue + large CQE batch (256) — fits this pattern. The `Memory.Pool` concept from the research maps to pre-allocated CQE batch buffers.

---

## 8. Concurrency and Event Loop Integration

**io_uring need**: Single-threaded event loop (TigerBeetle model). Integration with Swift Concurrency for async/await. Serial-mode executor for io_uring thread. Lifecycle management (shutdown signaling).

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `callback-isolated-nonsending-design.md` | swift-institute/Research/ | `nonisolated(nonsending)` callbacks for same-isolation DI. Maps to completion callbacks that inherit the event loop's isolation. |
| `non-sendable-strategy-isolation-design.md` | swift-institute/Research/ | Non-Sendable strategy for isolation design. Relevant for ring types that should not be shared across threads. |
| `nonsending-adoption-audit.md` | swift-institute/Research/ | Audit of nonsending adoption opportunities. io_uring event loop callbacks are a primary candidate. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `executor-serial-mode-task-preference` | swift-institute/Experiments/ | CONFIRMED | Serial-mode executor with `withTaskExecutorPreference`. Validated: single `.serial` executor for both actor pinning and task preference. **Directly applicable to io_uring event loop.** |
| `detach-exit-signal` | swift-institute/Experiments/ | CONFIRMED (6/6) | Detached pthread exit signaling. ~Copyable ~Escapable scope with consuming close() async. Validates zero-blocking shutdown for swift-io lifecycle. **Directly applicable to ring shutdown.** |
| `nonsending-dispatch` | swift-institute/Experiments/ | CONSOLIDATED (4 experiments) | `nonisolated(nonsending)` behavior across dispatch contexts. Validates completion callbacks preserving isolation. |
| `noncopyable-operation-closure-pipeline` | swift-institute/Experiments/ | CONFIRMED (13/14) | ~Copyable Sendable Operation through stored closure pipeline. `UnsafeMutableRawPointer` is `@unsafe Sendable` in 6.3. Pipeline mechanics (consuming, forwarding, deinit cleanup, async) all work. |

### Design Implication

The L1 ring wrapper should be `~Sendable` (not thread-safe, like liburing). The L3 event loop integration uses:
- Serial-mode executor (validated by `executor-serial-mode-task-preference`) for the io_uring thread
- `nonisolated(nonsending)` callbacks (validated by `nonsending-dispatch`) for same-thread completion delivery
- Detach-exit-signal pattern (validated by `detach-exit-signal`) for ring lifecycle/shutdown

---

## 9. Memory Regions (mmap Management)

**io_uring need**: Three mmap regions (SQ ring, CQ ring, SQE array) — or two with SINGLE_MMAP. The buffer ring is a separate mmap. All must be munmap'd on teardown.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `owned-typed-memory-region-abstraction.md` | swift-institute/Research/ | **Tier 3 decision.** `Memory.Contiguous<Element>` as owned typed region with bulk deallocation. Capability Calculus region capability model. Direct stored property access for `@_lifetime` propagation. |

### Relevant Experiments

| Experiment | Location | Status | Key Finding for io_uring |
|------------|----------|--------|--------------------------|
| `memory-contiguous-owned` | swift-institute/Experiments/ | CONFIRMED (11/11) | ~Copyable owned region with Span access, deinit deallocation, Sendable inheritance. All variants work debug + release. |

### Design Implication

Each mmap region should be an `IO.Uring.Mmap: ~Copyable` type wrapping `UnsafeMutableRawPointer` + length. `deinit` calls `munmap`. The ring struct owns 2–3 of these. The `Memory.Contiguous` pattern provides the template, substituting `munmap` for `deallocate`.

---

## 10. Existing IO Driver Infrastructure

**io_uring need**: The ecosystem already has `IO.Event.Driver` and `IO.Completion.Driver` witness types at L3 that use ~Copyable Handle types with borrowing/consuming conventions.

### Relevant Research

| Document | Location | Key Finding for io_uring |
|----------|----------|--------------------------|
| `witness-macro-io-drivers-assessment.md` | swift-institute/Research/ | Existing IO drivers already use ~Copyable Handle, borrowing/consuming closures, per-platform factory methods (`.kqueue()`, `.epoll()`). An io_uring backend would be a new factory method. |

### Design Implication

The L3 `IO.Completion.Driver` witness type already has the architecture for an io_uring backend. The L1 swift-linux-primitives work provides the raw binding; the L3 integration adds `IO.Completion.Driver.ioUring()` as a factory alongside `.epoll()` and `.kqueue()`.

---

## Summary Matrix

| io_uring Concern | Swift Feature | Primary Research | Primary Experiment | Confidence |
|-----------------|---------------|------------------|-------------------|------------|
| Ring ownership (fd + mmap) | ~Copyable, deinit | noncopyable-ecosystem-state | noncopyable-inline-deinit, noncopyable-throwing-init | High |
| Deinit ordering (munmap before close) | ~Copyable deinit | — | noncopyable-nested-deinit-chain | High |
| CQE borrowed views | ~Escapable, @_lifetime | nonescapable-ecosystem-state | nonescapable-patterns, escapable-protocol-navigation | Medium (pointer blocker) |
| Ring head/tail barriers | Atomics (acquire/release) | kernel-atomic-memory-ordering | — | High (validated on ARM64) |
| SQPOLL wakeup fence | Atomics (SeqCst fence) | kernel-atomic-memory-ordering | — | High |
| Per-operation errors | Typed throws | typed-throws-mixed-error-domains | noncopyable-throwing-init | High |
| Opcode builders | Witness / prep methods | witness-macro-io-drivers-assessment | witness-macro-noncopyable-feasibility | High |
| C syscall bridge | C shim | c-shim-placement-architecture | — | High (CLinuxKernelShim exists) |
| Event pipeline | Pool + batch drain | zero-copy-event-pipeline | zero-copy-event-pipeline-validation | Medium |
| mmap regions | ~Copyable owned region | owned-typed-memory-region-abstraction | memory-contiguous-owned | High |
| Event loop executor | Serial executor + nonsending | callback-isolated-nonsending-design | executor-serial-mode-task-preference | High |
| Ring lifecycle/shutdown | ~Copyable scope + async | — | detach-exit-signal | High |
| Completion callbacks | ~Copyable operation pipeline | — | noncopyable-operation-closure-pipeline | High |
| Caller-owned completions | ~Copyable intrusive nodes | noncopyable-ecosystem-state | noncopyable-access-patterns | High |

## Outcome

**Status**: RECOMMENDATION

14 io_uring concerns map to existing, validated Swift features. 12 of 14 have HIGH confidence based on confirmed experiments. The two MEDIUM confidence items are:
- ~Escapable CQE views (blocked by pointer-to-~Escapable limitation; copy fallback available)
- Zero-copy event pipeline (validated at research level, pending full integration test)

No io_uring concern requires a Swift feature that is uncharted territory. Every critical mechanism has been validated by at least one experiment on Swift 6.2.3+.

## References

- API reference: `linux-io-uring-api-reference.md` (this directory)
- Implementation studies: `io-uring-impl-study-{zig-std,tigerbeetle,rust-io-uring,liburing}.md` (this directory)
- All referenced research: `swift-institute/Research/`
- All referenced experiments: `swift-institute/Experiments/`
