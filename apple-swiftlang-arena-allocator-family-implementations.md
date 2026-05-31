# Apple / Swiftlang Arena & Allocator-Family Implementations

<!--
---
version: 1.0.0
last_updated: 2026-05-31
status: ANALYSIS
statusDetail: "Round 1 deep-dive companion to apple-swiftlang-memory-buffer-allocator-survey.md — HOW apple/swiftlang implement arena/pool/bump/slab/stack allocator families. External-only. Round 2 comparative analysis is COMPLETE: see memory-buffer-allocator-institute-vs-apple-comparative.md."
tier: 2
scope: ecosystem-wide
---
-->

## Context

**Trigger.** Continuation of the Round-1 external survey (`apple-swiftlang-memory-buffer-allocator-survey.md`), pushing from the *landscape* into the *implementation mechanics* of **arena types and adjacent allocator families** — "find Arena types and similar family types, and see how they're implemented" (principal request).

**Still Round 1 — external only.** Like the parent survey, this document is a pure external description of apple/swiftlang's own code. No Swift Institute package was read or compared; that contextualization is Round 2.

**Method.** Eight verification-grade deep-read agents over actual source (2026-05-31): six on the obvious veins (swift-syntax, concurrency task allocator, runtime metadata allocator, swift-java arenas, NIO allocator/pool, stdlib temporary allocation), plus a ninth ecosystem **completeness scan** (`gh search code` across `org:apple` + `org:swiftlang` for `Arena`/`BumpPtrAllocator`/`StackAllocator`/`Pool`/`Slab`/`FreeList`/`RegionAllocator`/`Allocator`) that surfaced two more genuinely-distinct arenas — `sourcekit-lsp`'s `UnsafeStackAllocator` and the compiler's `AllocationArena` model — which were then deep-read in a second wave. Every load-bearing claim below was read verbatim with `file:line`; several agents *corrected this author's prompt premises* against source (flagged in the Confidence appendix).

**Verification convention.** Claims are `[Verified: 2026-05-31]` (read verbatim from `main`-branch source). This is a companion to, and shares the References discipline of, the parent survey.

---

## Question

How are **arena and arena-adjacent allocator family types** (bump allocators, slab/stack allocators, object/buffer pools, region/lifetime scopes) actually *implemented* across apple/swiftlang — the backing data structures, allocate algorithms, free/reset discipline, growth, alignment, and ownership/thread-safety models?

---

## Analysis

### The family map

Nine concrete allocator types/families were found and read. They cluster into four implementation *shapes*. All citations are verbatim from `main` (2026-05-31).

| # | Type / family | Repo | Lang | Shape | Free discipline | Public surface |
|---|---|---|---|---|---|---|
| 1 | `BumpPtrAllocator` + `RawSyntaxArena` | swiftlang/swift-syntax | Swift | slab-list bump arena | **free-all on `deinit`** | `@_spi` (SPI) |
| 2 | `UnsafeStackAllocator` + `UnsafeStackArray` | swiftlang/sourcekit-lsp | Swift | inline-buffer page/bump stack | **strict LIFO pop** + heap spill | `package` (internal) |
| 3 | `StackAllocator` + `swift_task_alloc` | swiftlang/swift (Concurrency) | C++ | slab bump, task-local | **strict LIFO pop** | runtime ABI (`swift_task_alloc`) |
| 4 | `MetadataAllocator` + `PoolRange` | swiftlang/swift (runtime) | C++ | global atomic bump pool | **never freed (immortal)** | runtime-internal |
| 5 | `AllocationArena{Permanent, ConstraintSolver}` + `ASTAllocated` | swiftlang/swift (AST/Sema) | C++ | two LLVM bump arenas | Permanent: never; Solver: **whole-arena reset per solve** | compiler-internal |
| 6 | `USRBasedTypeArena` | swiftlang/swift (IDE) | C++ | bump interning arena | free-all on arena destroy | compiler-internal |
| 7 | `SwiftArena` / `AllocatingSwiftArena` family | swiftlang/swift-java | Java | **lifetime-scope** (+ FFM byte alloc) | register→destroy on close/GC | public Java API |
| 8 | `ByteBufferAllocator`/`_Storage`; `…RecvByteBufferAllocator`; `NIOPooledRecvBufferAllocator`; `Pool<Element>` | apple/swift-nio | Swift | malloc-vtable + CoW + recyclers | CoW/ARC + object recycling | public |
| 9 | `withUnsafeTemporaryAllocation` / `withTemporaryAllocation` | swiftlang/swift (stdlib) | Swift | scoped stack-or-heap scratch | scope-bracketed (`defer`) | **public stdlib** |

**The headline:** of nine, only **two** are public, general-purpose user surface — NIO's (server-framework-scoped) and the stdlib's scoped temporary-allocation functions. The rest are SPI/`package`/runtime-internal. This reinforces the parent survey's §10 finding: apple/swiftlang implement arenas *pervasively as internal infrastructure*, but expose **no general public allocator/arena abstraction**.

---

### 1. swift-syntax — `BumpPtrAllocator` + `RawSyntaxArena` (the canonical Swift-native arena)

`[Verified: 2026-05-31]` `Sources/SwiftSyntax/BumpPtrAllocator.swift`, `Sources/SwiftSyntax/Raw/RawSyntaxArena.swift`.

- **Data structure** (`BumpPtrAllocator.swift:18-38`): `slabs: [UnsafeMutableRawBufferPointer]` + a bump cursor `current: (pointer, end)?` + a side array `customSizeSlabs` for oversized one-offs + `_totalBytesAllocated`. The classic LLVM `BumpPtrAllocator` shape ported to Swift.
- **Allocate** (`:99-130`): align the cursor up (`alignedUp(toMultipleOf:)`), bounds-check against `end`, advance cursor, return the slice — one align + one compare + one add. Misses: requests `>= initialSlabSize` get a dedicated exact-size custom slab (honoring caller alignment); otherwise `startNewSlab()` and retry.
- **Free discipline** — **free-all-at-once, only in `deinit`** (`:49-57`: `while let slab = slabs.popLast() { slab.deallocate() }`). No per-allocation free, no reset. Doc: *"Clients should never call `deallocate()` on the returned buffer."*
- **Growth** — geometric, *delayed*: `slabSize(at:) = initialSlabSize * 2^(index/128)`, shift capped at `2^30` (`:60-63`). First 128 slabs stay at the initial size, then double every 128. Default arena initial slab = **128 B**, `ParsingRawSyntaxArena` = **4096 B**.
- **Alignment** — bounded: slabs fixed at `SLAB_ALIGNMENT = 8`; `assert(alignment <= 8)` at entry. No arbitrary-alignment support.
- **Ownership** — the arena's defining model: `RawSyntaxData` holds an **unowned** `RawSyntaxArenaRef` (`Unmanaged`, zero refcount traffic); the *root* holds a strong `RetainedRawSyntaxArena`; a node pulled from a *different* arena causes the parent to strong-retain that whole child arena into a `childRefs: Set` (`addChild`, same-arena = no-op), released together in `deinit`. So nodes never individually refcount; they live and die with the arena.
- **Thread-safety** — none/single-threaded: an exhaustive grep found *zero* locks/atomics on the allocation path (the only atomic is a DEBUG-only `_hasParent` arena-cycle guard).
- **Recency** — algorithm stable since early 2024; `SyntaxArena` → `RawSyntaxArena` rename commit `ca5b6d4cc` (2024-12-20), PR #2926 merged 2025-02-05; 2025 touches are cosmetic/resilience only.

### 2. sourcekit-lsp — `UnsafeStackAllocator` + `UnsafeStackArray` (inline-buffer stack arena)

`[Verified: 2026-05-31]` `Sources/CompletionScoring/Utilities/UnsafeStackAllocator.swift` (full 245 lines read).

- **Data structure** (`:27-46`): an **8192-byte inline value** `storage: Bytes8192` (built by a recursive doubling chain `Bytes8`→…→`Bytes8192` of `UInt64`-backed tuples — a fixed-size byte buffer without a language fixed-array feature), a `pageSize = 64`, `pagesCapacity = 128`, and a single bump cursor `pagesAllocated` (a *page count*). The arena lives on the **C stack** (it's a `struct` value), no heap for the arena itself.
- **Allocate** (`:53-74`): `pagesNeeded = ceil(bytesNeeded/64)`; if it fits, start = `baseAddress + pagesAllocated*64`, `bindMemory(to: Element)`, bump cursor. **Heap-overflow fallback**: when `pagesNeeded >= pagesAvailable`, return `UnsafeMutablePointer.allocate(...)` (plain malloc).
- **Free discipline** — **strict LIFO pop**, range-detected (`:87-101`): `deallocate` tests whether the pointer is inside the 8 KB arena; if so it must be the top-most block (`assert(projectedArrayStart == arrayStart)`) and pops the cursor; if outside (heap-fallback block) it calls `.deallocate()`. The order/balance checks are `assert` → **debug-only**; in release it's a pure trust-the-caller bump/pop. (Two verified source quirks: the assert *message* says "FIFO" but enforces LIFO; the in-arena threshold is strict `<` so an exactly-full request spills to heap — harmless, conservative.)
- **Growth** — *none*: the 8 KB buffer is fixed; overflow goes to the heap, no chaining/realloc.
- **Alignment** — punted: asserts `Element.alignment <= 8` and `<= 64`; comment *"Avoid dealing with alignment for now."* Page granularity satisfies it incidentally.
- **Ownership/thread-safety** — single-threaded by **non-sharing**: `private init()`, obtainable only inside `withUnsafeStackAllocator { … }`; each scoring worker opens its own. `UnsafeStackArray<Element>` is a fixed-capacity, `RandomAccessCollection`/`MutableCollection`-conforming non-owning handle carved from one arena block, with append/push/pop and trivial-type "leave garbage" fast paths (`initializeWithContainedGarbage`).
- **Rationale/recency** — completion-scoring hot path (avoid malloc/ARC per candidate); landed 2025-01-03 (commit `5709e1a8`, the SourceKit completion plugin), functionally unchanged since.

### 3. swift runtime — Concurrency per-task `StackAllocator`

`[Verified: 2026-05-31]` `stdlib/public/Concurrency/TaskAlloc.cpp`, `stdlib/public/runtime/StackAllocator.h`, `stdlib/public/Concurrency/{Task.cpp,TaskPrivate.h}`. Self-described: *"A bump-pointer allocator that obeys a stack discipline."*

- **Data structure** (`StackAllocator.h:94-141`): `lastAllocation: Allocation*` (intrusive LIFO stack head) + `firstSlab: Slab*` + bitfields. A `Slab` is a header `{metadata, next, capacity, currentOffset}` with a tail-allocated buffer; an `Allocation` is `{previous, slab}` + tail payload. Live state ≈ 2 words + 4 bytes.
- **Allocate** (`:362-384`): round size to 16, find current slab via `lastAllocation->slab`, placement-new an `Allocation` at `currentOffset`, bump the offset. The allocator is resolved per call from `task->Private.get().Allocator` — **embedded in the task object** (`TaskAlloc.cpp:39-50`).
- **Free discipline** — **strict LIFO, fatal on violation** (`:386-398`): `dealloc` fatal-errors unless the freed pointer is exactly `lastAllocation`, then rewinds `currentOffset` and pops `lastAllocation = previous`. `deallocThrough` bulk-pops down through a pointer.
- **Growth** — fixed-size slabs sized to a **1 KB malloc bucket**: `SlabCapacity = 1024 - 8 - slabHeaderSize()` (`TaskPrivate.h:842-849`); no doubling. Oversized request → one-off slab sized exactly to it; freed successor slabs are *retained and reused* (or coalesced). **The first ~512-byte slab is carved out of the same allocation as the `AsyncTask`** (`Task.cpp:1108-1112`, `firstSlabIsPreallocated = true`) — early async-frame allocation needs *no malloc*.
- **Alignment** — `MaximumAlignment = 16`; every request `alignTo(16)`.
- **Thread-safety** — **none, by design** (`TaskAlloc.cpp:15-17`): *"allocation is task-local, and there's at most one thread running a task at once, no synchronization is required."* No atomics/locks in alloc/dealloc.
- **Recency** — core design old/stable; an **env-var to disable the slab allocator** (degrade to malloc) was added 2025-11-01 (`a62f08e05`); slabs routed through `swift_slowAlloc` 2026-05-06.

### 4. swift runtime — `MetadataAllocator` / `PoolRange` (immortal lock-free bump pool)

`[Verified: 2026-05-31]` `stdlib/public/runtime/{Metadata.cpp,MetadataCache.h,Heap.cpp}`, `include/swift/Runtime/Atomic.h`.

- **Data structure** (`Metadata.cpp:8158-8193`): a **single global** `swift::atomic<PoolRange>` where `PoolRange{ char *Begin; size_t Remaining; }` (16 bytes, `alignas(2*word)`), seeded from a **static zero-init 64 KB BSS buffer** (`InitialPoolSize = 64*1024` — *"doesn't cost us anything in binary size"*). The allocator object itself is stateless apart from a 16-bit `Tag`.
- **Allocate** (`:8284-8400`): a lock-free optimistic CAS loop — load `{Begin, Remaining}`; if it fits, `allocation = Begin`, `newState = {Begin+size, Remaining-size}`; else malloc a fresh 16 KB page (`PageSize`); publish via `compare_exchange_weak`, retry on contention (freeing the speculatively-malloc'd slab if the race is lost). Requests `> 8 KB` (`MaxPoolAllocationSize = PageSize/2`) bypass to `swift_slowAlloc`.
- **Free discipline** — **never freed / immortal** (`:8402-8430`): `Deallocate` is a no-op *unless* the block is exactly the most recent allocation (flush against `Begin`), in which case it best-effort rolls the bump pointer back one step; any non-tail free or lost CAS is intentionally dropped (verbatim comment: *"we'll just leak the allocation"*). Only `>8 KB` allocations truly return to the heap.
- **Alignment** — pre-satisfied by the caller (`assert(alignment <= alignof(void*)); assert(size % alignof(void*) == 0)`); the bump pointer stays pointer-aligned for free, no rounding in the hot path.
- **Thread-safety** — **lock-free double-word CAS** (the one synchronized allocator here): `cmpxchg16b`/`casp` via `std::atomic<PoolRange>`; only `_WIN64` hand-rolls the intrinsic (MSVC's 16-byte atomic spin-locks). Release/consume ordering + manual TSan annotations handle slab-publication visibility.
- **Rationale** — type metadata (29 tags: metadata, witness tables, generic instantiations, packs, `LayoutString`, `FixedArrayCache`, `BorrowCache`…) lives for the whole process, so a never-free bump arena is optimal; tags are diagnostics-only and share the one pool. Lock-free because metadata instantiation happens on arbitrary threads.
- **Supporting heap** — `swift_slowAlloc`/`swift_slowDealloc` (`Heap.cpp:32-186`) use an alignment-*mask* ABI: plain `malloc`/`free` when the mask fits the platform's known malloc alignment (`MALLOC_ALIGN_MASK = 15` on 64-bit), else `AlignedAlloc`/`AlignedFree`; mask `~0` = "default" forced through the aligned path.
- **Recency** — algorithm long-stable; `BorrowCache` tag added 2026-01-16; configurable scribble byte 2026-05-14.

### 5. swift compiler — `AllocationArena{Permanent, ConstraintSolver}` (two-arena lifetime policy)

`[Verified: 2026-05-31]` `include/swift/AST/{ASTAllocated.h,ASTContext.h}`, `lib/AST/ASTContext.cpp`, `include/swift/Sema/ConstraintSystem.h`.

- **The model** (`ASTAllocated.h:21-37`): exactly two arenas, each an `llvm::BumpPtrAllocator`, **each carrying its own copy of the type-uniquing caches** (`FoldingSet`/`DenseMap` tables) so speculative solver types never pollute permanent interning.
  - **`Permanent`** — *immortal*, tied to the `ASTContext`'s whole lifetime, never reset, never individually freed. The `ASTAllocated<T>` CRTP base **deletes `operator delete`** (`ASTAllocated.h:53`) — AST nodes can *only* be arena-allocated and are never freed one-by-one. Default `arena = Permanent`, so ordinary `new (ctx) Node` is immortal.
  - **`ConstraintSolver`** — *transient scratch*, blown away after each type-check solve. Selected for "any type involving a type variable" (`getArena(RecursiveTypeProperties)`, `ASTContext.cpp:2236-2240`). The arena holds only a *reference* to a `BumpPtrAllocator`; the allocator and the installing RAII guard (`ConstraintCheckerArenaRAII`) are both **members of `ConstraintSystem`** (`ConstraintSystem.h:841-846`). On scope exit, `~ConstraintCheckerArenaRAII()` detaches/restores the arena pointer (supporting nested solves), then the `BumpPtrAllocator` member is destroyed — freeing **all** solver scratch in one shot.
- **One chokepoint** (`ASTContext::Allocate`, `ASTContext.h:491-503`) → `getAllocator(arena).Allocate(bytes, alignment)`; caller alignment forwarded verbatim (`static_assert(alignof(TypeBase) >= 8)` protects pointer-bit packing); a `LangOpts.UseMalloc` debug escape hatch swaps in `AlignedAlloc`.
- **Thread-safety** — single-threaded (one `ASTContext` mutator; `assert(CurrentConstraintSolverArena)`).
- **`USRBasedTypeArena`** (`CodeCompletionResultType.h:158-178`) is a *separate* IDE subsystem arena: its own `BumpPtrAllocator` + a USR→type `StringMap`, interning USR-canonical types that must outlive a completion's transient `ASTContext`. Freed wholesale on arena destroy.
- **Rationale** — immortal AST nodes (freed en masse at teardown, no refcount/cleanup) vs. disposable per-expression solver scratch (huge volumes of throwaway type-variable types discarded the instant the solve ends).

### 6. swift-java — `SwiftArena` / `AllocatingSwiftArena` (lifetime scopes over JDK FFM)

`[Verified: 2026-05-31]` `SwiftKitCore/.../core/*`, `SwiftKitFFM/.../ffm/*`, `Sources/JExtractSwiftLib/FFM/*`. (Java + Swift codegen.)

- **An arena is a *lifetime scope for Swift objects*, not a byte allocator** (in core). `SwiftArena`'s sole method is `register(SwiftInstance)`; closing/collecting destroys the registered Swift objects "in a way appropriate to their type." Byte allocation (`allocate(byteSize, byteAlignment) → MemorySegment`) is a *separate* capability added only by the FFM sub-interface `AllocatingSwiftArena extends SegmentAllocator` (JNI mode has no `MemorySegment`).
- **Two disciplines:** `ConfinedSwiftMemorySession` — an `AtomicInteger` CAS state machine (`ACTIVE→CLOSED`, idempotent close) draining a `ConcurrentLinkedQueue<SwiftInstanceCleanup>`; the FFM subclass wraps `java.lang.foreign.Arena.ofConfined()` and closes **Swift destroys before** the JDK arena frees segments. `AutoSwiftMemorySession` — GC/`Cleaner`/`PhantomReference`-driven, documented as *"LESS reliable… prefer confined."*
- **FFM allocate+destroy ride the Swift runtime value-witness table** (`SwiftValueWitnessTable.java`): `$LAYOUT` per imported struct is computed at class-load from the VWT (`size`/`stride` read off the table, alignment decoded from `flags & 0xFF + 1`, VWT pointer found one word *before* the metadata address). Generated wrappers emit `arena.allocate(MyStruct.$LAYOUT)` to carve a segment; destruction invokes the VWT `destroy` slot via a `Linker.nativeLinker().downcallHandle`. The codegen threads an `AllocatingSwiftArena swiftArena` parameter through any binding that returns a Swift value and emits `new Type(result$, swiftArena)` → the constructor calls `arena.register(this)`.
- **2026-05-20 rework (PR #761)** — *not* a state-machine change: it removed a per-instance `AtomicBoolean $state$destroyed` heap allocation, folding the destroyed flag into a `volatile int` inside the cached cleanup object (mutated via a static `AtomicIntegerFieldUpdater`). The confined `AtomicInteger` CAS persists. The cleanup is now created once in the constructor and doubles as a GC-survivable destroyed-state holder.
- **JDK substrate** (labeled: JDK `java.lang.foreign`, *not* apple/swiftlang): `Arena.ofConfined()` (thread-confined, deterministic close), `ofShared()`, `ofAuto()` (GC), `ofGlobal()` (never closed).

### 7. swift-nio — `ByteBufferAllocator` + recv-allocator + pool family

`[Verified: 2026-05-31]` `Sources/NIOCore/{ByteBuffer-core.swift,RecvByteBufferAllocator.swift,NIOPooledRecvBufferAllocator.swift}`, `Sources/NIOPosix/Pool.swift`.

- **`ByteBufferAllocator`** — a stateless `struct` holding **four `@convention(c)` function pointers** (a vtable over `malloc`/`realloc`/`free`/`copy`), not a pool; `buffer(capacity:0)` returns a shared no-alloc singleton. As of PR #3526 (2026-03) it accepts custom C allocation closures (`@_spi(CustomByteBufferAllocator)`), letting a `ByteBuffer` be backed by external memory.
- **`ByteBuffer._Storage`** — a `final class` (enables CoW) with a `UInt8`-bound raw pointer; capacity rounded **up to the next power of two** (`nextPowerOf2ClampedToMax`, bit-smear, 32-bit-clamped) — so `buffer(capacity: 100)` mallocs 128. Freeing is pure ARC `deinit → free`; **no free-list**. Mutations gate on `isKnownUniquelyReferenced`.
- **`AdaptiveRecvByteBufferAllocator`** — sizes the *next* read by **arithmetic ×2 / ÷2 between power-of-two bounds** (64/2048/65536 default) — **not** a Netty-style static size table (verified absent). Grow is eager (one full read doubles); shrink is hysteretic (two consecutive small reads via a `decreaseNow` latch).
- **`NIOPooledRecvBufferAllocator`** — a recycler of *whole `ByteBuffer`s* (single-buffer-or-array dual representation, round-robin `_lastUsedIndex`, `capacity = maxMessagesPerRead`). Reuses a pooled buffer **iff its storage is uniquely referenced** (`modifyIfUniquelyOwned` + `clear(minimumCapacity:)`, normally zero-alloc); else allocates fresh; buffers beyond capacity are transient. Promoted NIOPosix→NIOCore and made public in PR #3110 (2025-05). Purpose: dodge per-read malloc/CoW when a `ChannelHandler` retains the previous read's buffer.
- **`Pool<Element>`** — a generic object-recycling **free-list** (`get()`/`put()`, `maxSize`, `evictedFromPool()`), used to recycle event/write-state objects; distinct from the byte allocators.
- **Thread-safety** — structural, not locked: `_Storage` and the pool are explicitly *not* thread-safe; correctness comes from being per-channel state mutated *"on EventLoop thread only."* Heavy Span/RawSpan adoption + typed-throws migration across late-2025–2026.

### 8. stdlib — `withUnsafeTemporaryAllocation` / `withTemporaryAllocation`

`[Verified: 2026-05-31]` `stdlib/public/core/TemporaryAllocation.swift`, `stdlib/public/stubs/Stubs.cpp`.

- **The decision is a flat constant in Swift** (`:61-96`): `_isStackAllocationSafe` returns `true` only when `alignment <= 16` (`_swift_MinAllocationAlignment`) **and** `byteCount <= 1024`; everything else → heap. `@_transparent`, so it constant-folds at the call site.
- **The runtime "smart heuristic" is dead code** (`Stubs.cpp:169-215`): `swift_stdlib_isStackAllocationSafe` unconditionally `return false;` — the live-stack-bounds / safety-margin logic exists only inside `#if 0`. So the effective behavior is purely the 1024-byte cutoff.
- **Stack path** = `Builtin.stackAlloc` (LLVM `alloca`) + `Builtin.stackDealloc` in a `defer` (strict LIFO scope); **heap fallback** = `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` + `deallocate()`, also `defer`-scoped. An `unprotected` twin uses `Builtin.unprotectedStackAlloc` to skip stack-protector instrumentation.
- **SE-0524 span layer** (`:263-321`) is a pure wrapper: `withTemporaryAllocation(...) -> inout OutputSpan/OutputRawSpan` delegates to `withUnsafeTemporaryAllocation`, wrapping the buffer in an init-tracking span that auto-`finalize`s and `deinitialize`s the initialized prefix on exit (even on throw). Back-deployable; **Accepted, Swift 6.4**.

---

### Cross-cutting implementation patterns

The synthesized payload — how apple/swiftlang implement arenas *as a body of practice*:

1. **Slab-list bump is the dominant arena shape.** swift-syntax `BumpPtrAllocator`, the task `StackAllocator`, the metadata `PoolRange`, sourcekit-lsp `UnsafeStackAllocator`, and the compiler AST arenas are all "carve from a big block, bump a cursor, refill with a new slab when full." Differences are concentrated in *growth* and *free discipline*, not in the core bump.

2. **Free discipline splits cleanly into three idioms, by lifetime shape:**
   - **Free-all-on-destroy / immortal** (the true "arena") — swift-syntax (`deinit`), compiler `Permanent` (never), metadata allocator (never; `Deallocate` is a no-op-unless-last). Used when the contents outlive any individual operation.
   - **Strict LIFO pop** (the "stack allocator") — task `StackAllocator` (fatal on violation), sourcekit-lsp `UnsafeStackAllocator` (asserted), compiler `ConstraintSolver` (whole-arena reset at RAII scope end). Used when allocation lifetimes nest.
   - **CoW + ARC + object recycling** (the "buffer/pool") — NIO `ByteBuffer`/`_Storage`/pools. Used when buffers are shared and resized.

3. **Growth strategies are deliberately varied and tuned to the workload:** geometric *delayed* doubling (swift-syntax, ×2 every 128 slabs, cap 2³⁰); fixed slabs sized to a **1 KB malloc bucket** (task); fixed **16 KB pages** with a **64 KB static seed** (metadata); **fixed 8 KB, no growth** + heap spill (sourcekit-lsp); **next-power-of-two** (NIO buffers). Nobody uses a one-size-fits-all growth policy.

4. **Thread-safety is almost always "single-threaded by construction," not locking.** swift-syntax (per-arena), task (task-local, ≤1 thread), sourcekit-lsp (per-worker, non-sharing), compiler (one `ASTContext` mutator), NIO (per-event-loop). The **sole** allocator that synchronizes is the **metadata allocator** — a lock-free double-word CAS — precisely because metadata instantiation races across arbitrary threads. (swift-java's confined `AtomicInteger` CAS guards *close idempotency*, not allocation.)

5. **Alignment is consistently bounded/punted, never generalized.** ≤ 8 (swift-syntax), ≤ 8/≤ 64 asserted with the comment *"avoid dealing with alignment for now"* (sourcekit-lsp), caller-pre-satisfied (metadata), fixed 16 = `MaximumAlignment`/`_swift_MinAllocationAlignment` (task, stdlib), whatever-malloc-gives (NIO). No surveyed arena implements arbitrary-alignment bump arithmetic.

6. **Heap fallback for the "too big / overflow" case is universal.** swift-syntax `customSizeSlabs`, task oversized one-off slab, metadata `>8 KB → swift_slowAlloc`, sourcekit-lsp heap spill on page exhaustion, stdlib `>1024 B → UnsafeMutableRawPointer.allocate`. The arena fast-paths the common case and degrades gracefully.

7. **"Arena" denotes two distinct concepts, and swift-java separates them explicitly.** (a) a *memory arena* — a bump region freed wholesale (syntax/runtime/compiler/sourcekit-lsp); (b) a *lifetime-ownership scope* — register objects, run their destructors on close (swift-java `SwiftArena`). swift-java layers byte allocation onto the scope only in `AllocatingSwiftArena` (FFM), keeping the two notions cleanly factored.

8. **These are infrastructure, not API.** Eight of nine are SPI / `package` / runtime-internal / Java-binding; only NIO's (framework-scoped) and the stdlib's scoped temporary-allocation functions are general public surface. There is no public, composable `Allocator`/`Arena` *protocol* — each subsystem hand-rolls the arena it needs and hides it. This is the implementation-level corroboration of the parent survey's §10 "no user-facing custom-allocator facility."

---

## Outcome

**Status: ANALYSIS — Round 1 implementation deep-dive complete.** Companion to `apple-swiftlang-memory-buffer-allocator-survey.md`. No Institute comparison performed (Round 2).

Synthesized answer to "how are arena & similar family types implemented":

- Apple/swiftlang lean heavily on **slab-list bump allocators** as internal infrastructure, differentiated by **free discipline** (immortal free-all / strict-LIFO-stack / CoW-pool) chosen to match the contents' lifetime shape.
- Concurrency safety is overwhelmingly achieved by **owning the allocator single-threaded** (per-task, per-arena, per-event-loop), with exactly one lock-free CAS exception (metadata) where cross-thread racing is unavoidable.
- **Growth and alignment are tuned per-subsystem, never generalized**; every arena has a **heap fallback** for oversized/overflow allocations.
- **"Arena" is overloaded**: a memory bump region vs. an object-lifetime scope; swift-java is the one place both coexist, explicitly factored (`SwiftArena` scope + `AllocatingSwiftArena` bytes over JDK FFM).
- Critically, **none of this is a public allocator abstraction** — the arenas are hidden implementation details (SPI/`package`/runtime/Java). The only public allocation-control surface remains the stdlib's scoped `withUnsafeTemporaryAllocation`/`withTemporaryAllocation` and NIO's framework allocator — corroborating the parent survey's headline at the implementation level.

**Round 2 hooks.** When comparing to the Institute: the relevant axes are (a) bump-vs-pool-vs-lifetime-scope shape, (b) free discipline (immortal / LIFO / CoW), (c) single-threaded-by-construction vs synchronized, (d) public-abstraction vs hidden-infrastructure, (e) alignment generality, (f) the value-type-façade + CoW-storage idiom. The parent survey's reserved internal docs (`storage-arena-architecture.md`, `memory-pool-arena-buffer-usage-analysis.md`, `buffer-arena-conditional-copyable.md`, `handle-vs-arena-position-unification.md`, `linked-list-cursor-and-arena-backing-improvements.md`, `tree-primitives-buffer-arena-migration.md`) are the comparison targets.

---

## References

**swiftlang/swift-syntax:** [`BumpPtrAllocator.swift`](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/BumpPtrAllocator.swift) · [`Raw/RawSyntaxArena.swift`](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntax/Raw/RawSyntaxArena.swift)

**swiftlang/sourcekit-lsp:** [`Sources/CompletionScoring/Utilities/UnsafeStackAllocator.swift`](https://github.com/swiftlang/sourcekit-lsp/blob/main/Sources/CompletionScoring/Utilities/UnsafeStackAllocator.swift)

**swiftlang/swift (runtime/compiler):** [`StackAllocator.h`](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/StackAllocator.h) · [`Concurrency/TaskAlloc.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskAlloc.cpp) · [`Concurrency/TaskPrivate.h`](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskPrivate.h) · [`runtime/Metadata.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/Metadata.cpp) · [`runtime/MetadataCache.h`](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/MetadataCache.h) · [`runtime/Heap.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/runtime/Heap.cpp) · [`AST/ASTAllocated.h`](https://github.com/swiftlang/swift/blob/main/include/swift/AST/ASTAllocated.h) · [`AST/ASTContext.cpp`](https://github.com/swiftlang/swift/blob/main/lib/AST/ASTContext.cpp) · [`Sema/ConstraintSystem.h`](https://github.com/swiftlang/swift/blob/main/include/swift/Sema/ConstraintSystem.h) · [`IDE/CodeCompletionResultType.h`](https://github.com/swiftlang/swift/blob/main/include/swift/IDE/CodeCompletionResultType.h) · [`core/TemporaryAllocation.swift`](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/TemporaryAllocation.swift) · [`stubs/Stubs.cpp`](https://github.com/swiftlang/swift/blob/main/stdlib/public/stubs/Stubs.cpp)

**swiftlang/swift-java:** `SwiftKitCore/src/main/java/org/swift/swiftkit/core/{SwiftArena,ConfinedSwiftMemorySession,AutoSwiftMemorySession}.java` · `SwiftKitFFM/src/main/java/org/swift/swiftkit/ffm/{AllocatingSwiftArena,FFMConfinedSwiftMemorySession,SwiftValueWitnessTable}.java` · `Sources/JExtractSwiftLib/FFM/FFMSwift2JavaGenerator*.swift` · PR #761 (2026-05-20)

**apple/swift-nio:** [`NIOCore/ByteBuffer-core.swift`](https://github.com/apple/swift-nio/blob/main/Sources/NIOCore/ByteBuffer-core.swift) · [`NIOCore/RecvByteBufferAllocator.swift`](https://github.com/apple/swift-nio/blob/main/Sources/NIOCore/RecvByteBufferAllocator.swift) · [`NIOCore/NIOPooledRecvBufferAllocator.swift`](https://github.com/apple/swift-nio/blob/main/Sources/NIOCore/NIOPooledRecvBufferAllocator.swift) · `NIOPosix/Pool.swift` · PR #3110 (2025-05), #3526 (2026-03)

---

## Appendix — Confidence & residual gaps

**Verification quality.** Every type above was read verbatim from `main`-branch source with `file:line`. Notably, the deep-read agents *corrected several of this author's prompt premises* against source — raising rather than lowering confidence:
- swift-java's 2026-05-20 rework removed a per-instance **`AtomicBoolean`** heap allocation (folded into a `volatile int` + `AtomicIntegerFieldUpdater`), **not** the confined-session `AtomicInteger` CAS (which is intact).
- NIO's adaptive recv-allocator uses **arithmetic ×2/÷2**, **not** a Netty-style static size table (verified absent by grep).
- `TemporaryAllocation.swift` contains **no `_fixLifetime`** (lifetime is enforced by the `stackAlloc`/`stackDealloc` builtin pair + `defer`), and the runtime stack-safety hook is **dead code** (`return false` / `#if 0`).
- The metadata allocator's `Deallocate` is a **no-op unless the block is the last allocation** (immortal-by-design), with the verbatim comment *"we'll just leak the allocation."*

**Residual gaps (carried forward honestly):**
- The compiler `ConstraintSolver` arena's free is established by C++ **member-destruction-order reasoning** (allocator member destroyed after the RAII guard detaches it), quoted from headers; `lib/Sema/ConstraintSystem.cpp`'s constructor init-list and the `Solution`-promotion-into-`Permanent` code were not separately opened.
- swift-java's JNI-side cleanup symmetry (`JNISwiftInstanceCleanup`, `SwiftObjects.destroy`) and Swift *class* (reference-type) retain/release binding were seen only via the PR #761 diff, not read in full; the JDK `Arena` factory guarantees in §6 are standard-knowledge, not re-verified against the live JDK Javadoc *(UNVERIFIED)*.
- NIO/`_Storage` alignment is "whatever `malloc` returns" (no explicit alignment request) — platform-dependent, *(UNVERIFIED)* beyond typical 16-byte malloc alignment.
- Two source-level quirks in sourcekit-lsp's `UnsafeStackAllocator` are *verified, not inferred*: the dealloc assert message says "FIFO" but enforces LIFO; the in-arena threshold is strict `<` (exactly-full request spills to heap).
- `gh search code` is whitespace-tokenized and was intermittently rate-limited; a single-token allocator name in a low-traffic repo could theoretically have been missed by the completeness scan (compensated with per-repo queries; confirmed *negative* for swift-collections, swift-foundation, swift-system, swift-distributed-actors).
- Line numbers are `main` as of 2026-05-31; frequently-edited files (`ASTContext.cpp`, `ByteBuffer-core.swift`) may drift by a few lines on tagged releases. Structures/algorithms are stable.
