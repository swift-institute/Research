# Work-Stealing Scheduler Design

<!--
---
version: 0.1.0
last_updated: 2026-04-16
status: DECISION
tier: 2
---
-->

## Context

`swift-executors` v1 will ship `Kernel.Thread.Executor.Stealing` per the locked
taxonomy in `executor-package-design.md`. Today the package contains:

- `Kernel.Thread.Executor` — single thread, condvar wait, FIFO queue
- `Kernel.Thread.Executor.Sharded` — N threads, per-thread queues, round-robin assignment

`Stealing` is greenfield. The Swift runtime itself does not yet ship a
work-stealing scheduler; `TaskPrivate.h:469` and `Actor.cpp:2772` carry
`TODO (rokhinip)` markers acknowledging that "task stealers" are unimplemented.
The design space is therefore open both downstream of `swift-executors` and
upstream in the runtime.

The mission per `executor-package-design.md` is "complete, no-brainer,
theoretical-perfect." Work-stealing has 25+ years of academic and production
precedent — the no-brainer position is to lift the proven ABI rather than
invent. The remaining design questions are which proven ABI, how to
parameterize policy, and how the chosen design composes with Swift's actor
isolation model.

This document opens the design and is `IN_PROGRESS`. It will reach `DECISION`
when (1) the deque ABI is locked, (2) the steal-victim selection policy is
locked, and (3) the actor-isolation interaction is established as a documented
non-issue or as a documented constraint.

## Question

Lock the design for `Kernel.Thread.Executor.Stealing` along four axes:

1. **Deque ABI.** What synchronization protocol does each per-thread deque use
   for the owner's `push`/`take` operations and the stealers' `steal` operation?
2. **Steal-victim selection.** How does an idle worker pick which peer to steal
   from?
3. **Idle policy.** What does a worker that finds no work (locally or via
   stealing) do — spin, yield, or park?
4. **Pool sizing.** How is the worker count determined and parameterized?

These are coupled to one Swift-specific constraint:

5. **Actor-isolation interaction.** `Stealing` conforms to `TaskExecutor`, not
   `SerialExecutor`. Tasks that require actor isolation are dispatched by the
   runtime to a `SerialExecutor`; tasks that prefer a `TaskExecutor` (per
   SE-0417) but do not require serialization are eligible for stealing. The
   design must make this boundary explicit and ensure stolen jobs are never
   actor-bound.

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `Executor.Job.Deque` lives at L1 in `swift-executor-primitives` | `executor-package-design.md` | The deque ABI is a primitives-layer commitment, not local to `Stealing` |
| Existing ecosystem deque (`Queue<E>.DoubleEnded`) is sequential | `ecosystem-data-structures` skill, [DS-003] | Cannot compose: head/tail are plain `Int`, no atomic manipulation surface. Chase-Lev requires its own storage. |
| No existing Storage discipline is concurrency-aware | `ecosystem-data-structures` skill, [DS-005] | Heap/Inline/Arena/Slab/Pool/Split all assume single-threaded mutation. Chase-Lev introduces the first concurrent storage in the ecosystem. |
| Stealing is `TaskExecutor`, not `SerialExecutor` | SE-0417 + actor model | Stolen jobs MUST NOT be actor-bound; isolation enforced by runtime job classification |
| Provable space bound expected | Blumofe-Leiserson 1999 | Depth-first execution discipline; pop from owner's end MUST be LIFO |
| No `Foundation` dependency | Layer-3 toolkit | All atomics via `Synchronization` (or `Atomics` if pre-6.0); no `OSAtomic`, no `os_unfair_lock` |
| Embedded Swift compatibility goal | TBD per `embedded-swift-scoping.md` | Influences allocator strategy and atomic primitive choice |

## Prior Art Survey

### Cilk / Cilk Plus / OpenCilk (Blumofe-Leiserson 1999)

The canonical work-stealing scheduler. Defines the **THE protocol**: owner's
`push`/`pop` use `T` (tail) and `H` (head) indices with memory-fence-mediated
race resolution; stealers compete on `H`. Establishes the foundational result:
the expected execution time on P processors is `T₁/P + O(T∞)`, and the space
bound is `S₁(P) ≤ P · S₁` where `S₁` is the serial space.

| Property | Cilk THE |
|----------|----------|
| Owner end | LIFO push/pop |
| Stealer end | FIFO take |
| Atomicity | Memory fence on collision |
| Lock-freedom | Owner is wait-free; stealers compete via lock or CAS |

**Contextualization in Swift:** the THE protocol is implementable directly with
`UnsafeAtomic<Int>` for the `H`/`T` indices and `Synchronization.Mutex` for
stealer-stealer arbitration. No type-system friction.

### Chase-Lev Dynamic Circular Deque (2005)

The modern canonical implementation. Refines THE for dynamic resizing and uses
a CAS-based `steal` that retries on conflict. Wait-free for the owner's `push`,
lock-free for `take` and `steal`. Adopted by:

- **Java ForkJoinPool** (Doug Lea, JSR-166)
- **Rust Tokio** (multi-thread runtime)
- **Go runtime** (per-P run queues; conceptually similar with FIFO global queue)
- **Intel TBB**
- **.NET TPL ThreadPool**

A subtle weak-memory-model bug in the original 2005 paper was identified and
fixed by Lê, Pop, Cohen & Zappa Nardelli (2013), which is the version production
runtimes use.

| Property | Chase-Lev (2013 corrected) |
|----------|---------------------------|
| Owner end | LIFO push/pop, wait-free |
| Stealer end | FIFO take, lock-free CAS |
| Resizing | Dynamic, owner-driven |
| Memory model | C11/C++11 acq/rel + seq_cst on critical paths |

**Contextualization in Swift:** requires `UnsafeAtomic<Int>` for indices and an
`UnsafeMutableBufferPointer<UnownedJob>` for the storage ring. Resizing requires
an indirection (atomic pointer to current buffer). Implementable in current
Swift with `Synchronization` module atomics; no type-system friction. The
weak-memory-model corrections are mechanical and well-documented.

### Idempotent Work Stealing (Michael, Vechev, Saraswat 2009)

Trades **idempotence** (a stolen job may execute multiple times across workers)
for **simpler synchronization** (no CAS required for steal — only loads and
stores). Useful when work units are pure / commutative.

**Contextualization in Swift:** Swift's task model assumes single execution per
job. Adopting idempotent stealing would require an external dedup layer (e.g.,
"first-completer wins" via per-job atomic flag), which adds back the CAS this
protocol was meant to avoid. Rejected on the contextualization step alone — not
a fit for a general-purpose `TaskExecutor`.

### Acar-Charguéraud-Rainey Private Deques (2013)

Owner accesses are entirely lock-free; stealers communicate **steal requests**
via a separate channel that the owner serves at safe points. Trades steal
latency for owner-side simplicity and cache-friendliness.

**Contextualization in Swift:** plausible. The owner-served-steal-request model
maps cleanly onto a `Async.Channel.Bounded` per worker. Steal latency may be
unacceptable for high-priority injected jobs (the owner only checks at safe
points). Worth re-evaluating if cache profiling on Sharded reveals false-sharing
problems with Chase-Lev.

### Tokio multi-thread runtime (Rust)

- Per-worker LIFO bounded queue (256 entries) backed by Chase-Lev variant
- Spillover to global FIFO injection queue when local queue full
- Steal half of victim's queue at once (batched stealing)
- Random victim selection with `XorShift` seeded per worker
- Park via `Parker` (futex on Linux, condvar elsewhere) when no work

### Go runtime

- Per-P (logical processor) run queue, bounded LIFO with FIFO overflow
- Global run queue for spillover and injection from non-P contexts
- Random victim selection with deterministic seed
- `runtime.findRunnable` walks: local → global → steal → poll network → park

### Java ForkJoinPool (Doug Lea)

- Chase-Lev deque per worker
- `asyncMode` flag: LIFO for fork/join (default), FIFO for asynchronous tasks
- Random victim selection with rotating offset to reduce contention
- "Help" semantics: a thread waiting on a future executes other tasks while
  waiting

### Erlang BEAM

- Per-scheduler run queue (priority-bucketed FIFO)
- Migration logic balances queues periodically rather than steal-on-empty
- Different model: cooperative reduction count rather than preemptive scheduling

### Pattern observations

| Pattern | Adopted by |
|---------|------------|
| Chase-Lev deque (2013 corrected) | Tokio, Go, Java FJ, .NET TPL, TBB |
| Random victim selection | Cilk, Tokio, Go, Java FJ |
| Local-LIFO + global-FIFO injection | Tokio, Go |
| Park-via-futex | Tokio, Go, modern Java |
| Batched stealing (half the victim's queue) | Tokio, Java FJ |

**Universal pattern**: Chase-Lev with random victim selection and futex-style
parking. The variations (asyncMode, batched-vs-single steal, half-vs-quarter
batch) are policy parameters atop the same ABI.

**Per [RES-021] contextualization step:** The universal pattern translates
cleanly into Swift's type system using `Synchronization` module atomics. There
is no Swift-specific friction (no type-erasure cost, no typed-throws conflict)
that would justify diverging. The remaining decisions are policy parameters,
not ABI choice.

## Analysis

### Q1: Deque ABI

| Option | Description | Owner cost | Steal cost | Swift fit |
|--------|-------------|:---:|:---:|:---:|
| A. Cilk THE (1999) | Tail/head with memory fence | Wait-free | Lock-or-CAS | ✓ implementable |
| B. **Chase-Lev (2013 corrected)** | Dynamic circular deque, CAS steal | Wait-free | Lock-free CAS | ✓ canonical, broadest precedent |
| C. Idempotent (Michael 2009) | Allow duplicate execution | Load/store only | Load/store only | ✗ requires external dedup; Swift jobs not idempotent |
| D. Private deques (Acar 2013) | Steal requests via channel | Lock-free | Owner-served, latent | ⚠ steal latency; reconsider on cache-profile evidence |

**Initial recommendation: Chase-Lev (B).** Universal adoption across modern
runtimes is direct evidence the corrected ABI is correct, performant, and
implementable. Cilk THE (A) is a strict subset; modern runtimes use it only as
a teaching reference. Idempotent (C) fails the contextualization step.
Private deques (D) is an optimization to revisit only if profiling demands it.

**Validated by spike (2026-04-16):** `Experiments/chase-lev-deque-spike/`
implements Chase-Lev (B) using only `Synchronization.Atomic<Int>` with
`.acquiring`/`.releasing`/`.sequentiallyConsistent` orderings. Both the
single-threaded LIFO/FIFO discipline (V1) and the contended count
reconciliation under 1 owner + 4 stealer Tasks across 100k items (V2)
PASSED. Apple Swift 6.3 on macOS 26 arm64. Full `atomic_thread_fence` is
not required because seq_cst on the linked `bottom`-store / `top`-load pair
in `take` provides the equivalent ordering. Result: CONFIRMED for the
target platform. Linux validation outstanding.

**Storage composition (revised after V3 + V4 spikes, 2026-04-16):** existing
ecosystem storage disciplines are sequential (per [DS-005]) and
`Queue<E>.DoubleEnded` exposes no atomic manipulation surface, so
`Executor.Job.Deque` cannot compose into the Storage layer at the level of
existing collection primitives. It stands alone at L1 as the ecosystem's
first concurrency-aware storage. The remaining question is *what raw
storage* it holds for each variant:

| Variant | Recommended primitive | Status |
|---------|-----------------------|--------|
| `.Static<N>` (inline, zero heap) | `Memory.Inline<UnownedJob, N>` from `Memory_Primitives_Core` | ✓ Validated by V3 — `pointer(at:)` gives the mutable typed access Chase-Lev needs |
| Base / `.Bounded` (heap) | `ManagedBuffer<Header, UnownedJob>` (stdlib) — the same pattern stdlib's `_ContiguousArrayStorage` uses (`ContiguousArrayBuffer.swift:132-308`). Atomics live in the wrapping class because `ManagedBuffer.create(minimumCapacity:makingHeaderWith:)` requires a Copyable header. | ✓ Validated by V4 |

**Earlier "Memory.Contiguous.Mutable gap" framing was wrong** on two counts:

1. The right layer is **Storage**, not Memory. The "typed heap with
   consumer-managed lifecycle" abstraction lives at the Storage layer
   per [DS-005], above raw allocation.
2. The pattern *already exists* in stdlib (`_ContiguousArrayStorage` via
   `Builtin.allocWithTailElems`) and in `swift-storage-primitives`
   (`Storage<E>.Split<Lane>` with the explicit "consumer-managed
   lifecycle … same contract as `UnsafeMutableBufferPointer` or raw
   `ManagedBuffer`" guarantee). Chase-Lev's heap variant uses the
   `ManagedBuffer` pattern directly.

**No new Storage primitive needed.** The Storage layer is intentional
curation of *sequential* lifecycle disciplines shared across collection
families; Chase-Lev is a concurrent collection primitive whose lifecycle
is algorithm-specific. `Executor.Job.Deque` is itself the new L1 primitive
(in `swift-executor-primitives`), backed directly by `ManagedBuffer<H, E>`
— matching stdlib's own `_ContiguousArrayStorage` precedent
(`ContiguousArrayBuffer.swift:132-308`). See
[`swift-storage-primitives/Research/storage-primitives-modularization-review.md`](../../../swift-primitives/swift-storage-primitives/Research/storage-primitives-modularization-review.md)
(DECISION, Tier 2) for the full analysis closing this question.

**ManagedBuffer is vestigial in the ecosystem.** Long-term the aim is to
replace its uses with native ecosystem primitives. For Chase-Lev v1, the
direct ManagedBuffer use is a known interim choice tracked by the larger
ecosystem-wide ManagedBuffer-replacement effort, not something local to
this design.

### Q2: Steal-victim selection

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. **Random** | Pick random peer | Provably bounded contention; no topology assumption | No locality awareness |
| B. Round-robin | Iterate peers in order | Predictable | Concentrated contention on near peers; cache-unfriendly |
| C. Nearest-neighbour | Prefer threads with shared cache | Cache-friendly | Requires topology query; macOS/Linux divergence |
| D. Hierarchical (NUMA) | Tier by NUMA node, then random within tier | NUMA-aware | Topology queries; dispatch on multi-socket Linux only |

**Initial recommendation: Random (A) for v1.** Matches Tokio, Go, Java FJ, Cilk.
Topology-aware variants (C, D) are deferred to `numa-aware-sharding.md` and can
be added behind a policy parameter without breaking the ABI.

### Q3: Idle policy (worker found no local work, no successful steal)

| Option | Description | Latency on new work | CPU at idle |
|--------|-------------|:---:|:---:|
| A. Spin forever | Loop checking own queue and stealing | ~ns | 100% per idle worker |
| B. Spin → yield (`sched_yield`) | Brief spin, then yield to OS | ~µs | high but cooperative |
| C. Spin → park (futex/condvar) | Brief spin, then block | ~µs–ms (wakeup cost) | ~0% |
| D. **Spin → yield → park (hysteresis)** | Three-tier with timeouts | tunable | ~0% at steady state |

**Initial recommendation: D, with tunable spin/yield/park thresholds.**
Standard practice across Tokio, Go, Java FJ. Hysteresis prevents thundering
herd on bursty workloads.

The wakeup primitive should compose with `Executor.Wait.Condvar` from
`swift-executor-primitives` for portability; futex is a Linux-specific
optimization layer. Embedded Swift may force option A or B if no parking
primitive is available — to be resolved in `embedded-swift-scoping.md`.

### Q4: Pool sizing

| Option | Description | When |
|--------|-------------|------|
| A. **`processorCount`** | One worker per logical CPU (default) | General-purpose |
| B. `processorCount - 1` | Reserve one CPU for OS / main thread | UI / latency-sensitive |
| C. User-specified | Constructor parameter | Always available |
| D. Adaptive | Spawn/retire based on load | Out of scope for v1 |

**Initial recommendation: C with default of A.** `init(workers: Int = ProcessInfo.processorCount)` (or kernel-primitives equivalent — must not pull in `Foundation`). Adaptive (D) is deferred indefinitely; it adds substantial machinery for marginal benefit on the workloads `Stealing` is intended for.

### Q5: Actor-isolation interaction

`Stealing` conforms to `TaskExecutor`, not `SerialExecutor`. The runtime
guarantees that an actor's jobs are dispatched to the actor's `SerialExecutor`,
not to the task executor preference. Therefore stolen jobs are by construction
not actor-bound — the `Stealing` executor never sees actor-isolated work
unless a user explicitly conforms an actor's `unownedExecutor` to it (which
would be a misuse, since `Stealing` cannot serialize).

**Documentation requirement:** `Kernel.Thread.Executor.Stealing` MUST be
documented as `TaskExecutor`-only. Conformance to `SerialExecutor` MUST be
absent (compile-time enforcement). Per [DOC-049] the documentation should
actively counter-market against actor-pinning attempts.

## Theoretical Grounding

### Blumofe-Leiserson space bound

For a multithreaded computation with serial space `S₁` and `P` workers, work-
stealing with depth-first execution discipline (LIFO local pop) achieves
expected space `S₁(P) ≤ P · S₁`. The proof relies on the **busy-leaves**
property: stealers always steal the *oldest* (deepest in the call stack) work
unit, which is the inverse of the owner's LIFO discipline.

**Implication for Q1:** the deque MUST be LIFO at the owner's end and FIFO at
the stealer's end. This rules out symmetric (LIFO/LIFO or FIFO/FIFO) deques.
Chase-Lev satisfies this constraint by construction.

**Implication for Q3:** the idle policy must not delay steals so long that the
busy-leaves invariant is broken. Park-only-after-spin (option D above) is
compatible; immediate-park-on-empty would let work accumulate at one worker
while others sleep, breaking the bound.

### Time bound

Expected execution time on `P` workers: `T₁/P + O(T∞)`, where `T₁` is serial
work and `T∞` is critical-path length. Constant hidden in `O(T∞)` depends on
steal frequency and overhead.

**Implication:** steal overhead is a first-order performance concern.
Chase-Lev's lock-free steal path is essential to keep the hidden constant
small.

## Outcome

**Status:** `DECISION`.

### Locked recommendations

| Question | Initial recommendation |
|----------|------------------------|
| Q1: Deque ABI | Chase-Lev (Lê et al. 2013 corrected variant) |
| Q2: Victim selection | Random, with `XorShift` per-worker seed |
| Q3: Idle policy | Spin → yield → park (hysteresis); composes with `Executor.Wait.Condvar` |
| Q4: Pool sizing | User-specified; default `processorCount` |
| Q5: Actor isolation | Documented `TaskExecutor`-only; no `SerialExecutor` conformance |

### Completed pre-DECISION steps

1. ~~**Verify `Synchronization` module suffices** for the Chase-Lev atomics on
   target platforms (macOS, Linux; Embedded TBD).~~ **DONE (macOS arm64)** —
   `Experiments/chase-lev-deque-spike/` CONFIRMED on Swift 6.3 / macOS 26 arm64.
   Linux x86_64 / arm64 validation remains open; rerun the same spike on Linux
   under the same toolchain to close.
2. ~~**Variant taxonomy alignment per [DS-002].** Decide which variants of
   `Executor.Job.Deque` ship in v1: base growable, `.Bounded` (fixed capacity,
   heap), `.Static<N>` (inline, zero heap).~~ **DONE** — `.Static<N>` uses
   `Memory.Inline<UnownedJob, N>`; base uses `ManagedBuffer<Header, UnownedJob>`
   directly per stdlib precedent. Both implemented in `swift-executor-primitives`.
   ManagedBuffer use is a known vestigial-ecosystem choice; future
   replacement is tracked at the ecosystem level, not in this design.
3. ~~**Lock victim-selection PRNG.**~~ **DONE.** `XorShift32` — a 4-line
   struct, inline, zero dependency. The standard choice across production
   runtimes (Tokio uses `FastRand` which is XorShift128; Go uses a
   deterministic seed; Java FJ uses a rotating offset with XorShift).
   `swift-random-primitives` dependency rejected: one PRNG does not
   justify a package dependency. Record: victim selection uses per-worker
   `XorShift32` seeded from worker index.
4. ~~**Resolve Embedded interaction** in coordination with `embedded-swift-scoping.md`
   — may force a non-parking variant (`StealingSpinning`?) or rule out Embedded
   for v1.~~ **DONE** — `embedded-swift-scoping.md`: Stealing is CONDITIONAL on
   RTOS `Kernel.Thread` backend.
5. ~~**Coordinate with `priority-escalation-policy.md`** — work-stealing's
   interaction with priority escalation is non-trivial (a high-priority stolen
   job may now run on a low-priority worker thread).~~ **DONE** — mutual defer
   on priority-keyed deque; Chase-Lev wait-free invariant justifies M1/M2
   rejection.
6. ~~**Coordinate with `numa-aware-sharding.md`** — Q2's deferred topology-aware
   variants are that document's territory.~~ **DONE** — deferred to
   `numa-aware-sharding.md`; class-per-worker is accidentally safe at 192 bytes.
7. ~~**Element-lifecycle design for non-trivial elements.** The spike stores
   `Int` (trivially copyable). Production `Executor.Job.Deque` holds
   `UnownedJob`. Chase-Lev's slot lifecycle (owner-init on push;
   owner-or-stealer-deinit on take/steal success) does not fit any existing
   Storage discipline per [DS-005]. Lock the deinit ownership protocol before
   committing to non-trivial element types.~~ **DONE** — `UnownedJob` is
   `BitwiseCopyable`; Chase-Lev atomicity suffices; documented in design
   discussion.

### v1 Optimization Items (deferred, tracked here)

| Item | Origin | Status |
|------|--------|--------|
| Worker.swift lock-wrapping removal | Worker.swift currently wraps all deque operations in `wait.withLock { deque.push/take/steal }` — correct for the sequential-placeholder Executor but over-synchronized for Chase-Lev (deque is lock-free per Lê et al. 2013). Removing the locks to exploit the lock-free property is a separate Stealing executor design task. | DEFERRED — flagged 2026-04-16, awaits Stealing-executor implementation cycle |

### Benchmark amendment (2026-04-17)

`Experiments/victim-selection-benchmark/` validates Q2's DECISION
(random victim selection) against a sequential-scan baseline using a
minimal mutex-protected deque (not Chase-Lev; sufficient to isolate
the victim-selection variable). Averages across 3 runs, Apple Swift
6.3 / macOS 26 arm64:

**V1 — Skewed initial load (100k jobs placed on worker 0):**

| workers | sequential | random | speedup |
|---------|-----------:|-------:|--------:|
| 4 | ~13 ms | ~9 ms | **~1.5×** |
| 8 | ~24 ms | ~11 ms | **~2.2×** |

Random's per-attempt success rate is lower (30 % vs 50 % at 4w;
14 % vs 27 % at 8w) — more attempts hit empty peers — but total
drain time is shorter because steal attempts spread across peers
rather than colliding on worker 0's lock.

**V2 — Even initial load (25k per worker):**

| workers | sequential | random | ratio |
|---------|-----------:|-------:|------:|
| 4 | ~3.6 ms | ~3.2 ms | ~0.9× |
| 8 | ~10.3 ms | ~11.4 ms | ~1.1× |

Under balanced load both strategies converge — little stealing is
needed, and the small cost of random's broader probing rounds out
roughly equal.

**Verdict.** Q2's DECISION is correct. Random victim selection wins
decisively on the scenario it was chosen for (skewed load, which
production task placement frequently exhibits) and does not regress
on balanced load within measurement noise. XorShift32 per-worker
seeding costs ~3 ns per call — below the mutex-acquisition cost that
dominates steal-attempt overhead.

**Implementation note (2026-04-17).** `Kernel.Thread.Executor.Stealing.Worker`
now carries the per-worker XorShift32 state (seed = `id &+ 0x9E3779B9`,
OR-guaranteed non-zero), replacing the prior sequential-scan loop
over `pool.workers`. Single-writer; no lock.

### Escalation note

Per [RES-004b]: this analysis touches `swift-executor-primitives` (L1),
swift-executors (L3), and the runtime's evolving stealer model. Scope is
cross-package within `swift-foundations` + `swift-primitives`. No escalation to
`swift-institute` is required at this stage. Re-evaluate if the Embedded or
priority-escalation cross-cuts grow.

## References

### Foundational work-stealing

- Blumofe, R. D., & Leiserson, C. E. (1999). [Scheduling Multithreaded
  Computations by Work Stealing](https://dl.acm.org/doi/10.1145/324133.324234).
  *Journal of the ACM*, 46(5), 720–748.
- Frigo, M., Leiserson, C. E., & Randall, K. H. (1998). [The implementation of
  the Cilk-5 multithreaded language](https://dl.acm.org/doi/10.1145/277650.277725).
  *PLDI '98*. Introduces the THE protocol.

### Deque protocols

- Chase, D., & Lev, Y. (2005). [Dynamic Circular Work-Stealing
  Deque](https://dl.acm.org/doi/10.1145/1073970.1073974). *SPAA '05*.
- Lê, N. M., Pop, A., Cohen, A., & Zappa Nardelli, F. (2013). [Correct and
  Efficient Work-Stealing for Weak Memory
  Models](https://dl.acm.org/doi/10.1145/2517327.2442524). *PPoPP '13*. The
  weak-memory-model fix that production runtimes use.
- Michael, M. M., Vechev, M. T., & Saraswat, V. A. (2009). [Idempotent Work
  Stealing](https://dl.acm.org/doi/10.1145/1504176.1504186). *PPoPP '09*.
- Acar, U. A., Charguéraud, A., & Rainey, M. (2013). [Scheduling parallel
  programs by work stealing with private
  deques](https://dl.acm.org/doi/10.1145/2442516.2442538). *PPoPP '13*.

### Locality and topology

- Acar, U. A., Blelloch, G. E., & Blumofe, R. D. (2002). [The Data Locality of
  Work Stealing](https://dl.acm.org/doi/10.1145/277651.277678). *Theory Comput.
  Syst.*, 35(3), 321–347.

### Production implementations

- [Tokio multi-thread runtime](https://tokio.rs/blog/2019-10-scheduler) — Rust
- [Go runtime scheduler](https://go.googlesource.com/go/+/refs/heads/master/src/runtime/proc.go)
  — Go (`runtime/proc.go`)
- [Java ForkJoinPool](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ForkJoinPool.html)
  — Doug Lea's design notes in source
- [.NET TPL ThreadPool](https://github.com/dotnet/runtime/tree/main/src/libraries/System.Private.CoreLib/src/System/Threading)

### Swift runtime context

- `swiftlang/swift` — `stdlib/public/Concurrency/TaskPrivate.h:469` (task
  stealer TODO)
- `swiftlang/swift` — `stdlib/public/Concurrency/Actor.cpp:2772` (stealer-job
  TODO for priority escalation)
- [SE-0417: Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor.md)

### Internal references

- `executor-package-design.md` (locked taxonomy; `Executor.Job.Deque` as L1)
- `composable-executor-abstractions.md` (Design 1 origin)
- `sync-handoff-to-actors.md` (precedent for Q5 documentation strategy)
