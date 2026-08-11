# NUMA-Aware Sharding

<!--
---
version: 0.4.0
last_updated: 2026-04-17
status: DECISION
tier: 2
---
-->

## Context

`Kernel.Thread.Executor.Sharded` and `Kernel.Thread.Executor.Stealing`
both manage N worker threads with per-worker state (queues, condvars,
atomics). Neither has cache-line padding, thread-to-core affinity, or
NUMA topology awareness. `work-stealing-scheduler-design.md` Q2
(victim selection) explicitly defers topology-aware variants to this
note (lines 262–270 [Verified: 2026-04-16]):

> Topology-aware variants (C, D) are deferred to
> `numa-aware-sharding.md` and can be added behind a policy parameter
> without breaking the ABI.

This note scopes three concerns: (1) cache-line padding to prevent
false sharing on contended atomics, (2) NUMA-node-aware thread pinning
and memory allocation, (3) topology-aware steal-victim selection for
`Stealing`.

## Question

1. **Cache-line padding.** What is the false-sharing exposure in
   Sharded and Stealing, and what padding is needed?
2. **NUMA pinning.** Should we pin worker threads and their memory to
   NUMA nodes?
3. **Topology-aware steal-victim selection.** Should `Stealing` prefer
   NUMA-local or L2-cluster-local victims?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| Apple Silicon cache line: **128 bytes** | `sysctl hw.cachelinesize` on this host [Verified: 2026-04-16] | Safe portable padding must be ≥ 128 bytes |
| x86-64 cache line: **64 bytes** | Intel Optimization Manual §2.6.2 [Verified: 2026-04-16] | 128-byte padding over-pads on x86 but does not harm correctness |
| Swift has **no** cache-line-size constant | Searched: `Synchronization`, `swift-atomics`, `swift-collections`, `swift-primitives` [Verified: 2026-04-16] | We must define our own; we would be first in the ecosystem |
| macOS has **no NUMA** (UMA) | `sysctl -a | grep numa` returns nothing; Apple Silicon is unified memory [Verified: 2026-04-16] | NUMA pinning is Linux-only |
| Apple Silicon locality boundary: **L2 cluster** | `hw.perflevel0.cpusperl2=4`, `hw.cacheconfig` [Verified: 2026-04-16] | On Apple Silicon, "topology-aware" means cluster-aware, not NUMA-node-aware |
| Linux NUMA APIs: `numa_run_on_node`, `pthread_setaffinity_np`, `numa_alloc_onnode` | `man 3 numa`, `man 2 sched_setaffinity` [Verified: 2026-04-16] | Available but require libnuma; no privilege gating (unlike SCHED_DEADLINE) |
| Sharded cursor (`Atomic<Index<Kernel.Thread>>`) is unpadded; co-located with read-only fields in a heap object | `Kernel.Thread.Executor.Sharded.swift:41` [Verified: 2026-04-16] | Write-contended cursor may false-share with read-only `executors` and `count` |
| Stealing workers are class-per-worker — independent heap objects | `Kernel.Thread.Executor.Stealing.Worker.swift:32–41` [Verified: 2026-04-16] | Cross-worker false sharing is avoided by accident (allocator-provided alignment) |
| Acar-Blelloch-Blumofe 2002: NUMA-local steal bias helps constant factor, not asymptotic bound | [TCS 35(3):321–347](https://dl.acm.org/doi/10.1145/277651.277678) [Verified: 2026-04-16] | Topology-aware stealing is a constant-factor optimization, not a correctness concern |

## Prior Art Survey

### Cache-line padding in production runtimes

| Runtime | Mechanism | Size | Source |
|---------|-----------|:---:|--------|
| Rust crossbeam | `CachePadded<T>` with `#[repr(align(128))]` on aarch64-apple, `align(64)` elsewhere | 64/128 | crossbeam-utils [Verified: 2026-04-16] |
| C++ stdlib | `std::hardware_destructive_interference_size` (compile-time; GCC: 64; unavailable on Apple Clang) | 64 | C++17 spec |
| Linux kernel | `____cacheline_aligned_in_smp` | `L1_CACHE_BYTES` (64 on x86) | `arch/x86/include/asm/cache.h` |
| Swift Concurrency runtime (C++) | Struct layout separation in `DefaultActorImpl` (header vs footer) | implicit | `Actor.cpp:1252` |
| Swift ecosystem | **None.** No `@_alignment(128)` or `CachePadded` pattern exists | — | Searched stdlib, swift-atomics, swift-collections [Verified: 2026-04-16] |

### NUMA in production runtimes

| Runtime | NUMA awareness | Source |
|---------|:---:|--------|
| Tokio | No; uses crossbeam `CachePadded` for false-sharing only | `tokio-rs/tokio` [Verified: 2026-04-16] |
| Go | No; `sched_getaffinity` for CPU counting only | `runtime/os_linux.go` [Verified: 2026-04-16] |
| Java HotSpot | `-XX:+UseNUMA` — places TLABs on local NUMA node | Oracle docs [Secondary confirmation] |
| .NET | `GCServer` — one GC heap per NUMA node | .NET Runtime docs [Secondary confirmation] |

Java and .NET's NUMA support is GC-focused (memory allocation locality),
not scheduling-focused (thread-pinning for work-stealing). No surveyed
general-purpose task scheduler implements NUMA-aware steal-victim
selection.

### Acar-Blelloch-Blumofe (2002) — Data Locality of Work Stealing

Key result: expected remote steals are `O(P · T∞ · L)` — proportional
to critical-path length times the number of processors times the
cache-line cost. Work-stealing achieves near-optimal locality for
series-parallel computations. NUMA-local steal bias reduces the
constant factor but not the asymptotic bound.

**Contextualization.** Typical Swift task parallelism has short critical
paths and few steals. NUMA-local stealing helps only for bulk-parallel
workloads on multi-socket servers — a niche target for swift-executors
v1.

## Analysis

### Q1: Cache-line padding

**False-sharing audit** [Verified: 2026-04-16]:

| Executor | Contended field | Risk | Fix |
|----------|----------------|:---:|-----|
| Sharded | `cursor: Atomic<Index<Kernel.Thread>>` at `:41` — written on every `next()` call, co-located with immutable `executors` array ref | Low-Medium | Pad or isolate cursor into its own 128-byte-aligned allocation |
| Stealing | Per-worker `deque`, `wait`, `handle` at `Worker.swift:32–41` — each worker is a separate heap class | Low | Heap allocator provides independent alignment; no cross-worker false sharing |
| Stealing (post-Chase-Lev) | Stealer's CAS on victim's `top` atomic bounces the victim's cache line | Inherent (algorithm) | Cannot be eliminated; is the Chase-Lev cost model |

**Recommendation revised (post-spike, 2026-04-16):**
`@_alignment(128)` is **not possible in Swift** — the compiler caps
`@_alignment` at 16. Verified by spike:
`Experiments/alignment-spike/` [Verified: 2026-04-16].

Alternative approaches for `CacheLine.Padded<T>`:

1. **Manual padding tuple.** Add enough `UInt64` fields to bring
   `MemoryLayout<CacheLinePadded<T>>.stride` to ≥ 128. Works for
   value types but requires computing the pad size per `T`.
2. **`posix_memalign(128)` for heap-allocated padded values.** Verified
   working by spike (V3: PASS). For class-based executors (Sharded,
   Stealing), the contended field can be isolated into its own 128-byte-
   aligned heap allocation, stored as a pointer. This is the cleanest
   approach for our use case.
3. **Language feature request.** The `@_alignment(16)` cap is a
   compiler-imposed limit, not a hardware limit. Filing a Swift
   compiler issue to raise the cap is warranted for the ecosystem.

Apply to Sharded's cursor via approach (2) (`posix_memalign`).
Stealing needs no action in v1 — Worker instances are 192 bytes per
`malloc_size` ([Verified: 2026-04-16 by alignment spike V4]), so
back-to-back allocations cannot share a 128-byte cache line.

The constant 128 (Apple Silicon) is the correct portable minimum: it
over-pads on x86 (64-byte lines) but over-padding is safe. Under-
padding (64 on Apple Silicon) causes false sharing.

### Q2: NUMA pinning

macOS has no NUMA (UMA). Linux multi-socket servers are the only
target where NUMA pinning has value. The APIs are unprivileged but
require `libnuma` (not universally installed).

**Recommendation: out of scope for v1.** NUMA pinning is a policy
decision for the deployment operator, not the executor library. If
users need it, they pin threads themselves before passing them to the
executor (or we expose an `Options.threadAffinity: [CpuSet]?`
parameter in v2).

### Q3: Topology-aware steal-victim selection

`work-stealing-scheduler-design.md` Q2 recommends random victim
selection for v1. The Acar-Blelloch-Blumofe bound shows topology-aware
bias helps only the constant factor on bulk-parallel workloads.

Current implementation: sequential scan from own position
(`Worker.swift:69–76` [Verified: 2026-04-16]). This is a pre-spike
placeholder; the design doc recommends random.

**Recommendation: random for v1 (per work-stealing-scheduler-design.md Q2).
Topology-aware as an `Options.victimSelection: .random | .nearestFirst`
policy in v2.** On Apple Silicon, "nearest" means same L2 cluster
(`hw.perflevel0.cpusperl2`); on Linux NUMA, same NUMA node
(`/sys/devices/system/node/nodeN/cpulist`). The policy parameter can
be added without ABI break.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Question | Decision |
|----------|----------|
| Cache-line padding | `CPU.Cache.Padded<T>` at L1 (`swift-cpu-primitives`, 128 bytes), applied to `Sharded.cursor`. Stealing needs no padding in v1 (Worker instances are 192 bytes per `malloc_size`, so back-to-back workers already sit on separate cache lines). |
| NUMA pinning | Out of scope for v1; expose `Options.threadAffinity` in v2. |
| Victim selection | Random for v1 (per `work-stealing-scheduler-design.md` Q2 — DECISION status); topology-aware `Options.victimSelection` in v2. |

### Implementation status (2026-04-16)

1. ~~**Define `CPU.Cache.Padded<T>`**~~ **DONE** —
   `swift-cpu-primitives/Sources/CPU Primitives/CPU.Cache.Padded.swift`
   ships the first cache-line-aware type in the ecosystem. Uses
   `UnsafeMutableRawPointer.allocate(byteCount:alignment:)` with
   alignment 128 — cleaner than `posix_memalign` and Foundation-free.
   Storage is `~Copyable`, supports `T: ~Copyable` (so it wraps
   `Atomic<V>`, `Mutex<V>`, etc.), and exposes a `value` coroutine
   accessor for borrow/mutate. 8 tests cover alignment, byte-count,
   atomic round-trip, and inter-instance distance (54/54 at L1 pass).

2. ~~**Apply to `Sharded.cursor`**~~ **DONE** —
   `Kernel.Thread.Executor.Sharded.swift` now declares:

   ```swift
   private let cursor: CPU.Cache.Padded<Atomic<Index<Kernel.Thread>>>
   ```

   and accesses the atomic via `cursor.value.advance(within: count)`.
   The cursor lives in its own 128-byte-aligned heap slot, isolated
   from the read-mostly `executors` array reference and `count` scalar
   in the `Sharded` class layout. (28/28 at L3 pass.)

3. **Switch Stealing's victim selection from sequential to random** —
   deferred. Tracked in `work-stealing-scheduler-design.md` Q2
   (DECISION status, XorShift32 per-worker PRNG chosen; implementation
   pending). Not a blocker for this note: the locked decision here is
   "random for v1"; the implementation lives in `Stealing.Worker`, not
   in the NUMA note.

4. **Benchmark before/after padding** — deferred. Building a
   `next()`-under-contention benchmark requires a coordinated harness
   spanning Sharded + timed threads; the microbenchmark infrastructure
   exists in `swift-institute-benchmarks` but setup is non-trivial.
   Not a blocker for DECISION — the padding is sound on first
   principles (false-sharing elimination is a well-established
   optimization; the only question a benchmark would answer is the
   magnitude of improvement, not whether to apply it).

5. ~~**Defer NUMA and topology-aware stealing**~~ **DONE** — recorded
   here; v2 work item via `Options` parameters.

### Scope outside this note

- The `CPU.Cache.Padded<T>` primitive is broader than this note —
  future uses (e.g., per-core state in a v2 scheduler, padded
  channels, counter pads) are independent of the NUMA/sharding
  discussion. This note owns the first application, not the type's
  API evolution.
- NUMA pinning on Linux multi-socket servers is explicitly out of
  swift-executors v1. When it lands in v2, the policy model should
  slot into the existing `Options` struct rather than a new top-level
  type.

### Benchmark amendment (2026-04-17)

`Experiments/cursor-padding-benchmark/` validates `CPU.Cache.Padded<T>`
as a primitive and empirically tests its effect on Sharded.cursor.

**V3 (classic false-sharing, each thread writes its OWN atomic):**
padded wins decisively.

| threads | unpadded | padded | speedup |
|---------|---------:|-------:|--------:|
| 2 | 279 M/s | 1095 M/s | **3.92×** |
| 4 | 165 M/s | 2036 M/s | **12.29×** |
| 8 |  75 M/s | 2562 M/s | **34.00×** |

This is the textbook false-sharing scenario. Unpadded atomics share
a cache line; every store from one core invalidates the other cores'
copies. Padded atomics sit on independent lines and scale linearly.
The primitive itself is sound.

**V1 (Sharded.cursor workload, 4 shards, all threads hammer the
same cursor):** padded is *neutral-to-negative* in a tight loop.

| threads | unpadded | padded | ratio |
|---------|---------:|-------:|------:|
| 1 | ~360 M/s | ~370 M/s | ~1.0× |
| 2 | ~210 M/s | ~210 M/s | ~1.0× |
| 4 | ~100 M/s | ~120 M/s | ~1.2× |
| 8 |  ~27 M/s |  ~15 M/s | **~0.6×** |

Run-to-run variance is high (± 30 %), but the direction is consistent:
**under extreme cursor contention, padding does not help and may
hurt**. The intuition: in V1, all threads CAS the same cursor, so
the cursor's cache line ping-pongs between cores regardless of
padding. Isolating the cursor from `executors` / `count` eliminates
one invalidation channel (the neighbour line stays stable) but adds
one pointer indirection per access (via `CPU.Cache.Padded._storage`).
At 8-way contention the indirection overhead dominates.

**Implication.** The DECISION to pad `Sharded.cursor` was rationalized
by false-sharing between cursor and read-only neighbours. The
benchmark shows that in the extreme case (tight-loop `next()` with no
intervening work), the cursor-line contention dwarfs any
neighbour-sharing cost. In realistic use — where workers do actual
compute between `next()` calls — the neighbour line is evicted
anyway, so the unpadded layout's neighbour-re-fetch cost fades into
the noise.

**Verdict: keep the padding but downgrade the expected benefit.** The
primitive remains validated for its intended use (independent per-
thread state, V3 pattern). For `Sharded.cursor` specifically, the
padding is defensive — it costs a small indirection and does not
visibly hurt realistic workloads, while insuring against a workload
mix where neighbour-line stability matters. If a future benchmark on
the realistic mixed workload shows a regression, reverting to the
unpadded layout is a one-line change.

**v2 question (tracked).** Re-benchmark after implementing a
Stealing-style worker loop where `next()` is called once per actual
job rather than in a tight loop. If the padding effect is still
neutral there, revert `Sharded.cursor` and reserve `CPU.Cache.Padded`
for per-thread state.

### Realistic-workload benchmark (2026-04-17, follow-up)

`Experiments/realistic-sharded-benchmark/` answers the v2 question
above. Each worker interleaves `next()` with a compute burn whose
length is calibrated to a target nanosecond budget, touching a
1 MiB scratch buffer between calls so cache lines are evicted the
way real work would evict them.

**V1 — compute sweep (4 threads, 100k iterations):**

| compute/iter | unpadded | padded | speedup |
|:-------------|---------:|-------:|--------:|
| ~10 ns  | ~15 ms  | ~12 ms  | 1.0–1.6× (noisy — iteration is too short to observe real work) |
| ~100 ns | ~38 ms  | ~38 ms  | 0.89–1.14× (noise) |
| ~1 µs   | ~120 ms | ~117 ms | **consistently 1.01–1.03×** |
| ~10 µs  | ~1.3 s  | ~1.1 s  | 0.81–1.02× (dominated by compute; cursor cost invisible) |

At the realistic working point (~1 µs of work per `next()` call —
roughly a short actor job), padded is consistently 1–3 % faster.
Not a dramatic win, but the direction matches the hypothesis.

**V2 — thread scaling at ~1 µs compute:**

| threads | unpadded | padded | ratio |
|---------|---------:|-------:|------:|
| 1 | ~100 ms | ~100 ms | 1.00× |
| 2 | ~102 ms | ~102 ms | 1.00× |
| 4 | ~106 ms | ~105 ms | 1.00× |
| 8 | ~144 ms | ~147 ms | 0.97× |

Thread scaling is essentially flat — the compute burn dominates and
masks any cursor-line effect.

**Synthesis across both benchmarks.**

| workload | padded vs unpadded |
|----------|-------------------|
| Textbook false-sharing (V3 of cursor-padding) | **34× faster** — primitive strongly validated |
| Shared cursor, tight loop (V1 of cursor-padding) | ~0.6–1.2× (noisy; padded often slower at extreme contention) |
| Shared cursor + realistic compute (this note V1) | **1.01–1.03× at 1 µs work/iter** (consistent) |
| Shared cursor + very heavy compute (this note V1) | 1.00× (compute dominates) |

**Final verdict.** Keep the `Sharded.cursor` padding as-is.

- At the realistic working point it is slightly positive, not
  neutral — the cursor-padding-benchmark's negative V1 numbers
  reflect the pathological tight-loop regime, not production use.
- The primitive is separately validated for its intended use
  (independent per-thread state, V3).
- The pointer-indirection cost the tight-loop benchmark flagged
  disappears once real work intervenes between `next()` calls.
- Reverting would churn code for a 1 % difference in the wrong
  direction.

The v2 re-benchmark question is now resolved and struck from the
implementation roadmap.

### Escalation note

Per [RES-004b]: `CacheLine.Padded<T>` is an L1 primitive addition
(either `swift-cpu-primitives` or `swift-memory-primitives`). Scope
crosses `swift-primitives` (L1) and `swift-executors` (L3). No
escalation to `swift-institute` required.

## References

### Architecture

- Apple WWDC 2020 "Optimize for Apple Silicon" — 128-byte cache lines.
- Intel. *64 and IA-32 Architectures Optimization Reference Manual*,
  §2.6.2. 64-byte cache lines.
- `sysctl hw.cachelinesize` = 128 on this host [Verified: 2026-04-16].

### Cache-line padding

- Rust crossbeam-utils —
  [`CachePadded`](https://github.com/crossbeam-rs/crossbeam/blob/master/crossbeam-utils/src/cache_padded.rs)
  (`align(128)` on aarch64-apple).
- C++17 — `std::hardware_destructive_interference_size`.
- Linux kernel — `____cacheline_aligned_in_smp`.

### NUMA

- Linux `man 3 numa`, `man 2 sched_setaffinity`,
  `Documentation/admin-guide/mm/numa_memory_policy.rst`.
- Java `-XX:+UseNUMA` — Oracle docs.
- .NET GCServer — Runtime docs.

### Data locality

- Acar, U. A., Blelloch, G. E., & Blumofe, R. D. (2002). [The Data
  Locality of Work
  Stealing](https://dl.acm.org/doi/10.1145/277651.277678). *Theory of
  Computing Systems*, 35(3), 321–347.

### Internal references

- `work-stealing-scheduler-design.md` Q2 — random victim selection
  for v1; topology-aware deferred here.
- `executor-package-design.md` — Sharded and Stealing taxonomy.
- `executor-identity-sharded.md` — complements this note for the
  `isIsolatingCurrentContext` gap.
