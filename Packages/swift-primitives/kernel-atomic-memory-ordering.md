# Kernel Atomic Memory Ordering

<!--
---
version: 2.0.0
last_updated: 2026-03-25
status: DECISION
tier: 3
---
-->

## Context

`Kernel.Atomic` in `swift-kernel-primitives` provides memory-ordered load and store operations for shared-memory synchronization — specifically io_uring ring buffers and lock-free SPSC queues. The current implementation uses a compiler-only barrier (`@_optimize(none)` on an empty function) to prevent reordering:

```swift
@usableFromInline
@_optimize(none)
static func _compilerBarrier<T>(_ value: T) { }
```

This is **unsound on ARM64**. The `@_optimize(none)` attribute prevents the *compiler* from reordering across the call, but the *CPU* can still reorder loads and stores. ARM64 has a weak memory model where:
- Loads can be reordered with subsequent loads/stores
- Stores can be reordered with subsequent stores

On x86-64 this works *by accident* — the Total Store Order (TSO) memory model already provides acquire/release semantics for every load/store. But relying on architecture-specific behavior without an explicit contract is unsound infrastructure.

Additionally, `@_optimize(none)` is an underscored attribute with no stability guarantee. It could change semantics or be removed in any Swift release.

**Trigger**: Design question arose during implementation audit — the barrier is provably insufficient on ARM64.

**Constraints**:
- L1 (Primitives) — no Foundation, no external dependencies beyond existing swift-primitives packages
- Must emit actual hardware barriers on ARM64 (`ldar`/`stlr` or `dmb`)
- Must be zero-cost on x86-64 (no unnecessary fences)
- Must work on Darwin (ARM64, x86-64) and Linux (ARM64, x86-64)
- Operates on **externally-owned memory** (mmap'd ring buffers) — cannot use types that manage their own storage

## Question

What is the correct, portable, zero-overhead way to implement acquire-load and release-store on externally-mapped memory from Swift — and where does this primitive belong in the architecture?

## Prior Art

### liburing (Gold Standard)

liburing is the reference userspace library for Linux io_uring. Its `barrier.h` implements shared-memory synchronization for ring buffer access between userspace and kernel.

**C path** (the one that matters for us):
```c
#define io_uring_smp_load_acquire(p)                        \
    atomic_load_explicit((_Atomic __typeof__(*(p)) *)(p),   \
                         memory_order_acquire)

#define io_uring_smp_store_release(p, v)                    \
    atomic_store_explicit((_Atomic __typeof__(*(p)) *)(p),  \
                          (v), memory_order_release)
```

This uses C11 `<stdatomic.h>` with pointer casting to `_Atomic`-qualified type. The compiler lowers these to:

| Architecture | `memory_order_acquire` load | `memory_order_release` store |
|---|---|---|
| ARM64 | `ldar w0, [x1]` (Load-Acquire Register) | `stlr w0, [x1]` (Store-Release Register) |
| x86-64 | `mov eax, [rdi]` (plain load — TSO provides acquire) | `mov [rdi], esi` (plain store — TSO provides release) |

Key insight: on ARM64, `ldar`/`stlr` are **single instructions** with precise ordering — they only constrain the specific load/store, not all memory. This is fundamentally lighter than a standalone fence (`dmb`).

### Swift Stdlib Synchronization Module (Swift 6.0+)

The stdlib provides `Atomic<T>` backed by LLVM builtins:

```
Swift API → AtomicRepresentable → Builtin.atomicload_*_acquire / Builtin.atomicstore_*_release → LLVM IR → ldar/stlr
```

However, `Atomic<T>` is a `~Copyable` struct using `@_rawLayout(like: Value.AtomicRepresentation)` — it **owns its storage**. There is no way to point an `Atomic<T>` at externally-mapped memory. The builtins (`Builtin.atomicload_*`) are internal to the stdlib and not accessible from user code.

### apple/swift-atomics

Uses the same LLVM builtins via `.gyb`-generated code. Provides `UnsafeAtomic<T>` and `ManagedAtomic<T>`, both of which allocate and own their storage. Same limitation: cannot operate on external memory at arbitrary addresses.

### CCPUShim (Existing in swift-cpu-primitives)

Already provides standalone memory fences:

| Function | ARM64 | x86-64 |
|---|---|---|
| `swift_cpu_barrier_full_v1` | `dmb ish` | `mfence` |
| `swift_cpu_barrier_load_v1` | `dmb ishld` | `lfence` |
| `swift_cpu_barrier_store_v1` | `dmb ishst` | `sfence` |
| `swift_cpu_barrier_compiler_v1` | compiler barrier | compiler barrier |

These are **standalone fences**, not ordered load/store instructions. Critical differences from atomic load/store:

1. **Precision**: `dmb ishld` affects *all* prior loads. `ldar` only orders *this specific load* relative to subsequent accesses.
2. **Performance**: `dmb` is heavier than `ldar`/`stlr` on modern ARM cores (fence stalls the pipeline; `ldar` is just a slightly annotated load).
3. **x86-64 correctness**: `lfence` blocks speculative execution and `sfence` flushes write-combining buffers — **neither is needed for acquire/release**. Plain `mov` already has acquire/release semantics under TSO. Using `lfence`/`sfence` would add unnecessary overhead.

## Analysis

### Option A: C Shim Using `<stdatomic.h>` (Recommended)

Create `static inline` C functions wrapping `atomic_load_explicit` / `atomic_store_explicit`, exactly mirroring liburing's approach.

**Implementation sketch** — C shim header:
```c
#ifndef SWIFT_CPU_ATOMIC_SHIM_H
#define SWIFT_CPU_ATOMIC_SHIM_H

#include <stdatomic.h>
#include <stdint.h>

// --- 32-bit ---

static inline uint32_t
swift_cpu_atomic_load_acquire_u32_v1(const uint32_t *_Nonnull p) {
    return atomic_load_explicit(
        (_Atomic const uint32_t *)p, memory_order_acquire);
}

static inline void
swift_cpu_atomic_store_release_u32_v1(uint32_t *_Nonnull p, uint32_t v) {
    atomic_store_explicit(
        (_Atomic uint32_t *)p, v, memory_order_release);
}

static inline uint32_t
swift_cpu_atomic_load_relaxed_u32_v1(const uint32_t *_Nonnull p) {
    return atomic_load_explicit(
        (_Atomic const uint32_t *)p, memory_order_relaxed);
}

static inline void
swift_cpu_atomic_store_relaxed_u32_v1(uint32_t *_Nonnull p, uint32_t v) {
    atomic_store_explicit(
        (_Atomic uint32_t *)p, v, memory_order_relaxed);
}

// --- 64-bit ---

static inline uint64_t
swift_cpu_atomic_load_acquire_u64_v1(const uint64_t *_Nonnull p) {
    return atomic_load_explicit(
        (_Atomic const uint64_t *)p, memory_order_acquire);
}

static inline void
swift_cpu_atomic_store_release_u64_v1(uint64_t *_Nonnull p, uint64_t v) {
    atomic_store_explicit(
        (_Atomic uint64_t *)p, v, memory_order_release);
}

static inline uint64_t
swift_cpu_atomic_load_relaxed_u64_v1(const uint64_t *_Nonnull p) {
    return atomic_load_explicit(
        (_Atomic const uint64_t *)p, memory_order_relaxed);
}

static inline void
swift_cpu_atomic_store_relaxed_u64_v1(uint64_t *_Nonnull p, uint64_t v) {
    atomic_store_explicit(
        (_Atomic uint64_t *)p, v, memory_order_relaxed);
}

#endif
```

**Swift API** (in `CPU Primitives`, swift-cpu-primitives):
```swift
extension CPU {
    /// Memory-ordered load and store on externally-owned memory.
    ///
    /// For scenarios where the memory is not owned by a Swift `Atomic<T>` —
    /// mmap'd ring buffers, shared-memory IPC, lock-free data structures
    /// operating on raw pointers.
    ///
    /// Standalone fences (`CPU.Barrier.hardware`) order ALL memory operations.
    /// Atomic load/store orders only the SPECIFIC access — lighter on ARM64.
    public enum Atomic {}
}
```

**Advantages**:
- Exactly what liburing does — proven correct for the exact same use case (io_uring ring buffers)
- Emits `ldar`/`stlr` on ARM64 — single-instruction acquire/release, minimal overhead
- Emits plain `mov` on x86-64 — truly zero-cost
- C11 standard — portable across GCC, Clang, MSVC (v17.5+)
- Small shim (< 50 lines of C)

**Disadvantages**:
- Requires C shim functions
- Pointer cast to `_Atomic` is implementation-defined in the C standard (but universally supported by all three compilers and used by liburing, the Linux kernel's uapi headers, and every major C atomics library)

**Correctness argument**: `atomic_load_explicit` with `memory_order_acquire` is defined by C11 §7.17.7.2 to perform an atomic load with acquire semantics. The compiler must emit instructions that:
1. Read the value atomically at the natural width
2. Ensure no subsequent memory operations (load or store) can be reordered before this load

On ARM64, the only instruction that satisfies this is `ldar` (or `ldaxr` for exclusive access). On x86-64, every aligned load already satisfies this — the compiler emits a plain `mov`.

### Option B: Swift Stdlib `Atomic<T>`

Use `import Synchronization` and `Atomic<T>`.

**Advantages**:
- Pure Swift, no C shim
- Correct by construction (LLVM builtins)

**Disadvantages**:
- `Atomic<T>` owns its storage via `@_rawLayout` — **cannot point it at mmap'd memory**
- Would require redesigning the entire API: instead of `load(pointer, ordering:)`, callers would need to construct an `Atomic<UInt32>` that lives at the mmap address — which is not supported by the type
- Requires Swift 6.0+ (acceptable — we target 6.2)

**Verdict**: **Not viable.** The fundamental design of `Atomic<T>` manages its own storage. There is no safe way to overlay it onto externally-mapped memory. This is the gap that `CPU.Atomic` exists to fill.

### Option C: CCPUShim Standalone Fences

Replace `_compilerBarrier` with `swift_cpu_barrier_load_v1()` / `swift_cpu_barrier_store_v1()`:

```swift
// Acquire load via fence
let value = unsafe pointer.pointee
swift_cpu_barrier_load_v1()     // dmb ishld on ARM64, lfence on x86-64
return value
```

**Advantages**:
- Already exists — no new C functions needed
- Hardware barrier — correct on ARM64

**Disadvantages**:
- **Wrong barrier model**: Fences affect *all* memory operations, not just the target load/store. This is semantically heavier than needed.
- **Suboptimal on ARM64**: `dmb ishld` stalls the pipeline waiting for all prior loads to complete. `ldar` is a non-stalling annotation on a single load — modern ARM cores handle it without pipeline disruption.
- **Unnecessarily expensive on x86-64**: `lfence` serializes speculative execution (intended for Spectre mitigation and RDTSC ordering). `sfence` flushes write-combining buffers (intended for non-temporal stores). **Neither is needed for acquire/release** — TSO already guarantees it. A plain `mov` is correct; adding `lfence`/`sfence` wastes cycles.
- **Fence placement is error-prone**: The fence must be placed *after* the load (for acquire) or *before* the store (for release). This is a maintenance hazard — future modifications could accidentally move the fence.

**Verdict**: **Correct on ARM64 but unnecessarily heavy. Incorrect cost model on x86-64.** A standalone fence is the wrong abstraction for an ordered load/store.

### Option D: GCC `__atomic_load_n` / `__atomic_store_n` Builtins

Use GCC atomic builtins instead of `<stdatomic.h>`:

```c
static inline uint32_t
swift_cpu_atomic_load_acquire_u32_v1(const uint32_t *p) {
    return __atomic_load_n(p, __ATOMIC_ACQUIRE);
}
```

**Advantages**:
- No `_Atomic` pointer cast needed — works directly on regular pointers
- Same codegen as `<stdatomic.h>`
- Supported by GCC, Clang, and recent MSVC

**Disadvantages**:
- GCC extension, not C standard (though universally available)
- Less widely recognized than `<stdatomic.h>` — reviewers may not immediately understand the semantics

**Verdict**: **Viable but less portable than Option A.** The `_Atomic` cast in Option A is implementation-defined but practically universal; using a non-standard builtin doesn't actually improve the situation. Prefer the C11 standard path.

### Option E: Inline Assembly

Hand-write `ldar`/`stlr` on ARM64, plain load/store on x86-64:

```c
static inline uint32_t
swift_cpu_atomic_load_acquire_u32_v1(const uint32_t *p) {
#if defined(__aarch64__)
    uint32_t val;
    __asm__ __volatile__("ldar %w0, [%1]" : "=r"(val) : "r"(p) : "memory");
    return val;
#elif defined(__x86_64__)
    uint32_t val = *p;
    __asm__ __volatile__("" ::: "memory"); // compiler barrier only
    return val;
#endif
}
```

**Advantages**:
- Maximum control over exact instructions emitted
- No `_Atomic` cast, no compiler interpretation

**Disadvantages**:
- Fragile — must be correct per-architecture, per-width
- Must handle 32-bit and 64-bit widths separately
- Must handle ARM32, x86-32, Windows/MSVC intrinsics separately
- Duplicates what `<stdatomic.h>` already does correctly
- Maintenance burden: every new architecture requires new assembly
- Error-prone: easy to get wrong (e.g., forgetting the `memory` clobber)

**Verdict**: **Correct but unnecessarily risky.** This is what the Linux kernel does, but the kernel has a team of architecture experts maintaining it. For our purposes, `<stdatomic.h>` provides identical codegen with compiler-verified correctness.

### Comparison Table

| Criterion | A: `<stdatomic.h>` | B: `Atomic<T>` | C: CCPUShim Fences | D: GCC Builtins | E: Inline ASM |
|---|---|---|---|---|---|
| **Correct on ARM64** | Yes (`ldar`/`stlr`) | N/A | Yes (`dmb`) | Yes (`ldar`/`stlr`) | Yes (manual) |
| **Zero-cost on x86-64** | Yes (plain `mov`) | N/A | No (`lfence`/`sfence`) | Yes (plain `mov`) | Yes (manual) |
| **Works on external memory** | Yes | **No** | Yes | Yes | Yes |
| **Precision** | Per-instruction | N/A | All-memory fence | Per-instruction | Per-instruction |
| **C standard** | C11 | N/A | N/A | GCC extension | N/A |
| **Maintenance** | Low | N/A | Low | Low | High |
| **Proven in io_uring** | Identical to liburing | No | No | No | Linux kernel variant |

## API Shape

### Concrete-Width Overloads

The current generic `UnsafeMutablePointer<T>` interface must be **replaced with concrete-width overloads**:

```swift
// Current (unsound, generic)
public static func load<T>(_ pointer: UnsafeMutablePointer<T>, ordering:) -> T

// Correct (sound, concrete widths)
public static func load(_ pointer: UnsafeMutablePointer<UInt32>, ordering:) -> UInt32
public static func load(_ pointer: UnsafeMutablePointer<UInt64>, ordering:) -> UInt64
```

**Rationale**: Atomic operations are only well-defined for naturally-aligned, naturally-sized types. Generic `T` would compile for `T = String` or `T = SomeLargeStruct`, which cannot be atomically loaded or stored. The C shim provides concrete widths (`uint32_t`, `uint64_t`), and the Swift API should match.

io_uring ring buffer indices are `UInt32`. SPSC queue metadata can be `UInt32` or `UInt64`. These two widths cover all practical use cases.

### Pointer Type

`UnsafeMutablePointer<UInt32>` is correct over `UnsafeRawPointer` + offset because:
1. It is type-safe — the width is in the type
2. It is what consumers already have after `mmap` + `bindMemory` or pointer arithmetic
3. It maps directly to the C shim parameter types
4. It makes the code self-documenting at call sites

## Architectural Placement

### The Layering Problem

Memory-ordered load/store is a **CPU memory model operation**. It is not a kernel operation. The current placement of `Kernel.Atomic` in `swift-kernel-primitives` (`Kernel Thread Primitives` target) is a layering violation.

Evidence:
- `CPU.Barrier` in `swift-cpu-primitives` already owns standalone memory fences — the same domain (CPU memory ordering)
- Any lock-free data structure in `swift-foundations` would need memory-ordered load/store; forcing it to import `Kernel_Thread_Primitives` for a CPU operation is wrong
- `Kernel Primitives Core` already does `@_exported public import CPU_Primitives` — the dependency direction confirms CPU is the lower layer

### Existing Shim Architecture

| Tier | Package | Shim | Scope | Calling Convention |
|---|---|---|---|---|
| Architecture-specific | swift-arm-primitives | `CARMShim` | ARM-only: MRS, WFE, WFI, SEV, SEVL | Non-inline, `_v1` ABI |
| Architecture-specific | swift-x86-primitives | `CX86Shim` | x86-only: CPUID, RDRAND, RDSEED, RDTSCP | Non-inline, `_v1` ABI |
| Cross-platform | swift-cpu-primitives | `CCPUShim` | Portable: barriers, spin hints, prefetch, CRC-32C | Non-inline, `_v1` ABI |

- **CARMShim**: Wrong. Atomic ordering is not ARM-specific — `<stdatomic.h>` is cross-platform.
- **CX86Shim**: Wrong. Same reason.
- **CCPUShim**: **Right domain** — memory ordering is a CPU concern, and `CCPUShim` already owns standalone fences (`swift_cpu_barrier_*_v1`). Ordered load/store and standalone fences are two facets of the same concern: CPU memory ordering.

### The Inline Convention Problem

All `CCPUShim` functions are **non-inline** — declared in `shim.h`, defined in `shim.c`, with `_v1` ABI-versioned symbols. Every call goes through the C function calling convention.

This convention is **wrong for single-instruction operations**:

| Function | Instruction | Cost | Call overhead |
|---|---|---|---|
| `swift_cpu_barrier_full_v1` | `dmb ish` (1 cycle) | 1 cycle | ~4-10 cycles |
| `swift_cpu_barrier_load_v1` | `dmb ishld` (1 cycle) | 1 cycle | ~4-10 cycles |
| `swift_cpu_barrier_store_v1` | `dmb ishst` (1 cycle) | 1 cycle | ~4-10 cycles |
| `swift_cpu_barrier_compiler_v1` | zero instructions | 0 cycles | ~4-10 cycles |
| `swift_cpu_spin_hint_v1` | `yield`/`pause` (1 cycle) | 1 cycle | ~4-10 cycles |

The function call overhead **dominates** the actual work. The Swift wrappers are `@inline(always)`, but that only inlines the Swift→C call dispatch — the C function itself is still a non-inlined call.

For atomic load/store this is even worse: `ldar` returns a value that the caller needs in a register. A non-inlined call forces the value through the stack/return register convention, preventing the compiler from keeping it in a register across surrounding code.

The non-inline `_v1` convention exists for ABI stability across binary-compatible releases. But:
1. There are no external C consumers — only Swift targets within the superrepo import `CCPUShim`
2. A memory barrier instruction has no implementation that could change — it IS the instruction
3. The `_v1` suffix provides versioning for what can never have a v2

### Recommendation: `CPU.Atomic` in swift-cpu-primitives

The uniquely correct solution has two parts:

**Part 1: Add `static inline` atomic functions to `CCPUShim`**

Add a new header `atomic.h` within `CCPUShim` (the existing target — no new C target needed):

```
CCPUShim/
  include/
    shim.h          ← existing: non-inline complex operations
    atomic.h        ← new: static inline atomic load/store
  shim.c            ← existing: implementations for non-inline functions
```

The `atomic.h` header uses `static inline` because:
- These are single-instruction operations that must be inlined
- `<stdatomic.h>` functions are defined by the C standard as potentially inline
- The kernel shims (`CDarwinShim`, `CLinuxShim`, etc.) already use `static inline` headers — this is a proven pattern within the primitives superrepo

**Part 2: Add `CPU.Atomic` Swift API in `CPU Primitives`**

```swift
// CPU.Atomic.swift
extension CPU {
    /// Memory-ordered load and store on externally-owned pointers.
    ///
    /// For memory not owned by a Swift `Atomic<T>` — mmap'd ring buffers,
    /// shared-memory IPC, lock-free data structures on raw pointers.
    ///
    /// ## Atomic Load/Store vs Standalone Fences
    ///
    /// `CPU.Barrier.hardware` emits standalone fences that order ALL memory
    /// operations. `CPU.Atomic` orders only the SPECIFIC load or store —
    /// lighter on ARM64 (`ldar`/`stlr` vs `dmb`), zero-cost on both
    /// architectures for relaxed.
    public enum Atomic {}
}

// CPU.Atomic.Load.swift
extension CPU.Atomic {
    public enum Load {}
}

// CPU.Atomic.Load.Ordering.swift
extension CPU.Atomic.Load {
    public enum Ordering: Sendable {
        case relaxed
        case acquiring
    }
}

// CPU.Atomic.Store.swift
extension CPU.Atomic {
    public enum Store {}
}

// CPU.Atomic.Store.Ordering.swift
extension CPU.Atomic.Store {
    public enum Ordering: Sendable {
        case relaxed
        case releasing
    }
}
```

With load/store implementations:
```swift
extension CPU.Atomic {
    @inline(always)
    public static func load(
        _ pointer: UnsafeMutablePointer<UInt32>,
        ordering: Load.Ordering
    ) -> UInt32 {
        switch ordering {
        case .relaxed:
            return swift_cpu_atomic_load_relaxed_u32_v1(pointer)
        case .acquiring:
            return swift_cpu_atomic_load_acquire_u32_v1(pointer)
        }
    }

    @inline(always)
    public static func store(
        _ pointer: UnsafeMutablePointer<UInt32>,
        _ value: UInt32,
        ordering: Store.Ordering
    ) {
        switch ordering {
        case .relaxed:
            swift_cpu_atomic_store_relaxed_u32_v1(pointer, value)
        case .releasing:
            swift_cpu_atomic_store_release_u32_v1(pointer, value)
        }
    }

    // + UInt64 overloads
}
```

**Part 3: Remove `Kernel.Atomic`**

Since `Kernel Primitives Core` already does `@_exported public import CPU_Primitives`, adding `CPU.Atomic` makes it automatically available to all kernel-level consumers. `Kernel.Atomic` becomes redundant and should be removed:

- Delete: `Kernel.Atomic.swift`, `Kernel.Atomic.Load.swift`, `Kernel.Atomic.Load.Ordering.swift`, `Kernel.Atomic.Store.swift`, `Kernel.Atomic.Store.Ordering.swift`, `Kernel.Atomic.Flag.swift`
- All call sites change: `Kernel.Atomic.load(ptr, ordering: .acquiring)` → `CPU.Atomic.load(ptr, ordering: .acquiring)`

**Part 4 (deferred): Migrate existing barriers to `static inline`**

The same single-instruction-behind-function-call problem affects `swift_cpu_barrier_*_v1`, `swift_cpu_spin_hint_v1`, and `swift_cpu_cache_prefetch_*_v1`. These should eventually move to `static inline` headers. This is a separate change but the same underlying issue. CRC-32C (`swift_cpu_integrity_cyclic_castagnoli_v1`) and timestamp (`swift_cpu_timestamp_read_v1`) are multi-instruction and correctly non-inline.

## Expected Instructions (Verification)

After implementation, verify with `objdump -d` or `lldb disassemble`:

### ARM64

```asm
; swift_cpu_atomic_load_acquire_u32_v1:
ldar    w0, [x0]           ; Load-Acquire Register (32-bit)
ret

; swift_cpu_atomic_store_release_u32_v1:
stlr    w1, [x0]           ; Store-Release Register (32-bit)
ret

; swift_cpu_atomic_load_relaxed_u32_v1:
ldr     w0, [x0]           ; Plain load (no ordering)
ret

; swift_cpu_atomic_store_relaxed_u32_v1:
str     w1, [x0]           ; Plain store (no ordering)
ret
```

### x86-64

```asm
; swift_cpu_atomic_load_acquire_u32_v1:
mov     eax, [rdi]         ; Plain load (TSO provides acquire)
ret

; swift_cpu_atomic_store_release_u32_v1:
mov     [rdi], esi          ; Plain store (TSO provides release)
ret

; swift_cpu_atomic_load_relaxed_u32_v1:
mov     eax, [rdi]         ; Plain load (same — TSO is always at least this strong)
ret

; swift_cpu_atomic_store_relaxed_u32_v1:
mov     [rdi], esi          ; Plain store
ret
```

No `mfence`, `lfence`, `sfence`, or `lock` prefix should appear for acquire/release operations on x86-64.

## Outcome

**Status**: DECISION

**Decision**: **Option A — `<stdatomic.h>` C shim in `CCPUShim`, Swift API as `CPU.Atomic` in `CPU Primitives`**.

This is the uniquely correct solution because it respects two independent invariants simultaneously:

1. **Mechanism correctness**: `<stdatomic.h>` emits per-instruction ordering (`ldar`/`stlr`) rather than standalone fences (`dmb`). This is the same technique liburing uses and is proven correct for the exact use case (io_uring ring buffers). Zero-cost on x86-64 (plain `mov`).

2. **Architectural correctness**: Memory ordering is a CPU memory model operation. `CPU.Barrier` already owns standalone fences. `CPU.Atomic` is the ordered load/store counterpart — same domain, same package. Placing it anywhere else (kernel, arm, x86) creates either a layering violation or a domain mismatch.

**Implementation path**:
1. Add `include/atomic.h` to `CCPUShim` with `static inline` functions (UInt32 + UInt64, relaxed + acquire/release)
2. Add Swift files to `CPU Primitives`: `CPU.Atomic.swift`, `CPU.Atomic.Load.swift`, `CPU.Atomic.Load.Ordering.swift`, `CPU.Atomic.Store.swift`, `CPU.Atomic.Store.Ordering.swift`
3. Remove `Kernel.Atomic` files from `Kernel Thread Primitives`
4. Update any call sites from `Kernel.Atomic` → `CPU.Atomic`
5. Verify with `objdump` that ARM64 emits `ldar`/`stlr` and x86-64 emits plain `mov`

**Deferred work**:
- Migrate existing single-instruction CCPUShim functions to `static inline` (same bug, lower priority)

**Breaking change**: `Kernel.Atomic` is removed. Call sites migrate to `CPU.Atomic`. The generic `T` parameter becomes concrete `UInt32`/`UInt64` — call sites using other types will fail to compile, which is correct because those call sites were silently unsound.

## References

- liburing `barrier.h`: https://github.com/axboe/liburing/blob/master/src/include/liburing/barrier.h
- C11 §7.17.7.2 (`atomic_load_explicit`), §7.17.7.1 (`atomic_store_explicit`)
- ARMv8-A Architecture Reference Manual: LDAR (Load-Acquire Register), STLR (Store-Release Register)
- Intel® 64 and IA-32 Architectures SDM Vol 3A §8.2.2: Memory Ordering in P6 and More Recent Families
- Swift Synchronization module: `stdlib/public/Synchronization/Atomics/` in swiftlang/swift
- apple/swift-atomics: https://github.com/apple/swift-atomics
- Linux kernel `Documentation/memory-barriers.txt`: Acquire/release semantics
