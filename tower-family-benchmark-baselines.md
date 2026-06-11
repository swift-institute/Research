# Tower Family-Tier Benchmark Baselines

<!--
---
version: 0.1.0
last_updated: 2026-06-11
status: IN_PROGRESS
tier: 2
scope: ecosystem-wide
---
-->

## Context

Arc 3 of the post-W5 tower iteration (`GOAL-tower-arc-bench.md`; weakness-sweep §2bis #3):
iteration will change internals (the Generational SoA re-cut and the Tree.Position re-cut — arc 5
is explicitly BENCH-GATED on this arc), so the family-tier benchmark surface and RECORDED baselines
must exist BEFORE optimizing. Before this arc, only R4's alias-dispatch cost was measured
(`column-spelling-ergonomics-alias-vocabulary.md`: gate ≈ 4.3 ns/op worst-case, 0 on move-only
columns); everything else was asserted-but-unmeasured (the P lens). **This document records
measurements only — no optimization edits ride this arc; observed anomalies are banked in §Banked
candidates for arc-5's gate.**

Prior art ([RES-019] grep, 2026-06-11): `benchmarking-strategy.md` (the `.timed()` infrastructure
inventory), `benchmark-inline-strategy.md` (parameter-ownership split), `benchmark-result-storage.md`
(DECISION: machine-dependent timing data is never committed — `.benchmarks/` gitignored; this doc
records CURATED baselines with full methodology, the swift-collections announcement-benchmark
class, not result-file dumps), `swift-testing-performance-infrastructure-gaps.md` (cross-suite
serialization + attribution lessons). None is a baselines record; this document is new surface.

## Method

### Instrument

Per-family **nested benchmark packages** (`Benchmarks/Package.swift` beside `Tests/`, the io-bench
shape; [BENCH-001] primitives row) containing **executable targets** run via

```
rm -rf .build                                   # [BENCH-002]; the io-bench 82GB precedent
TOOLCHAINS=org.swift.632202605101a swift build -c release
TOOLCHAINS=org.swift.632202605101a swift run -c release --skip-build "<Family> Benchmarks"
```

— release-only by invocation, never `swift test` (arc GOAL discipline; the io-bench
process-hang precedent, `swift-io/Research/io-bench-process-hang.md`).

**Methodology deviation, flagged for the seat's W1 ruling** ([BENCH-003] mandates the `.timed()`
trait): the institute `.timed()` stack lives in swift-tests/swift-testing (L3 foundations), which
does not build against the reshaped tower on 6.3.2 — the W5 friction log records the L2/standards
tier blocking ALL foundations legs (pre-W1 `Memory.Allocation` spellings; scope ruling F-3 pending),
and the workspace scope is L1-only. The toolchain's own `Testing` module reaches the tower test
targets but has no `.timed()`. The instrument therefore generalizes the **R4 microprobe shape**
(the named methodology precedent): release executable, `ContinuousClock` batch timing, opaque
`@inline(never)` sinks/sources against constant folding and hoisting, fixed checked-in workloads.
`.timed()` adoption is re-openable the moment foundations re-reach the tower.

### Harness shape (proven on the array family, W1)

- **Batching**: each timed sample executes one batch of `opsPerBatch` operations; per-op ns =
  batch duration / opsPerBatch. Batch targets are sized so every sample is ≥ ~0.5 ms (clock
  granularity ≪ 0.1 % of sample): per-element shapes ~2M element-ops, build shapes ~262k slots,
  whole-copy shapes ≥ 16 copies (~4M copied slots).
- **Samples**: 2 untimed warmup batches, then 9 timed samples per case; the FULL per-sample
  vector is emitted (`BENCH {...}` JSON lines), never just a point estimate.
- **Statistics**: median, min, max, CV% across the 9 samples; cross-run agreement is checked over
  3 independent process invocations of the same binary (variance reported alongside every median;
  the seat re-runs samples and checks within stated variance, never exact-number match).
- **Optimizer discipline**: every measured loop's input passes through `@inline(never)` opaque
  sources and its output through an `@inline(never)` accumulating sink printed at exit; state
  lives in real heap-backed structures, and move-only state stays in stack frames captured by
  non-escaping batch closures.
- **Subjects**: `tower.direct` (`Array<HeapColumn<E>>`-class move-only columns), `tower.cow`
  (`Array<Shared<E, HeapColumn<E>>>`-class CoW columns), `stdlib` (the matching Swift standard
  library structure) — identical workloads, identical batch shapes ([BENCH-005]).
- **Setup isolation**: persistent subject structures and index streams are built OUTSIDE timed
  regions; build-shape cases include teardown inside the batch on every subject alike (stated
  per shape).
- **Honest bounding** ([BENCH-011], the R4 interpretation discipline): micro numbers bound the
  primitive, they do not predict workloads. Any number that would drive an architecture decision
  through a Copyable wrapper requires the dual-mode (isolated + integrated) probe before promotion.

### Environment (W1 record)

| Item | Value |
|---|---|
| Machine | MacBook Air 15″ (`Mac15,13`), Apple M3, 4P+4E cores, 24 GiB, **fanless** |
| Toolchain | `Apple Swift version 6.3.2 (swift-6.3.2-RELEASE), Target: arm64-apple-macosx26.0`, `TOOLCHAINS=org.swift.632202605101a` |
| OS | macOS 26.2 (25C56) |
| Config | `-c release`, `swiftLanguageModes: [.v6]`, strict memory safety + ecosystem feature flags (family manifests' exact block); build of record clean, zero warnings by full grep |
| Run conditions (W1) | Interactive dev machine with parallel executor arcs active. Stable background during the recorded runs: ONE sibling single-threaded `swift-frontend` at 100% of one core (arc-2's hash-table test build; bracketing `ps` checks + load averages recorded per run). Run-set acceptance is BY CROSS-RUN AGREEMENT: runs 1–3 primary (≤~7% pairwise on nearly all cases), run 4 (~25 min later) corroborates within ±10%; runs 5–6 caught a multi-process load burst (5-min load 7.5), inflated 25–55% uniformly across ALL subjects, and are EXCLUDED by that criterion (preserved in the W1 log sidecar). |

No cross-machine comparisons: every number in this document is from the machine identified above.

## Baselines

> Unit: ns/op (median of 9 samples, CV% in parentheses), run-to-run agreement over 3 invocations.
> `detach`/`clone` rows: one op = one whole-array copy at the row's n.

### Array (proving family, W1) — swift-array-primitives, bench beside tip `257a617`

Primary = median of run-medians over runs 1–3 (`±` = max pairwise run spread; `cv` = worst
within-run CV across the 9 samples; `r4` = run-4 corroboration delta). Element type `Int`
except the `payload.*` rows (`final class` element). Build shapes (`append.*`, `pushPop`,
`payload.append`) include per-rep teardown inside the batch on every subject alike.

| shape | n | tower.direct | tower.cow | stdlib | cow/direct | direct/stdlib |
|---|---|---|---|---|---|---|
| append.zero | 16 | **24.671** ±6.5% (cv 3.5%, r4 +1.6%) | **23.401** ±3.5% (cv 1.6%, r4 -0.4%) | **8.615** ±5.9% (cv 2.7%, r4 +1.5%) | 0.9× | 2.86× |
| append.reserved | 16 | **11.713** ±1.2% (cv 1.2%, r4 -0.2%) | **10.702** ±2.7% (cv 2.7%, r4 +0.5%) | **2.326** ±14.0% (cv 4.4%, r4 +1.7%) | 0.9× | 5.04× |
| append.zero | 1,024 | **2.344** ±13.8% (cv 4.4%, r4 +0.5%) | **9.554** ±1.0% (cv 3.0%, r4 -0.5%) | **0.871** ±6.6% (cv 2.8%, r4 +3.3%) | 4.1× | 2.69× |
| append.reserved | 1,024 | **0.791** ±2.8% (cv 1.0%, r4 +0.4%) | **8.051** ±2.5% (cv 3.2%, r4 -0.6%) | **0.435** ±2.4% (cv 1.6%, r4 -2.3%) | 10.2× | 1.82× |
| append.zero | 65,536 | **1.742** ±2.3% (cv 1.1%, r4 -0.1%) | **8.965** ±1.1% (cv 2.8%, r4 -0.1%) | **1.075** ±9.2% (cv 2.3%, r4 -0.9%) | 5.1× | 1.62× |
| append.reserved | 65,536 | **0.609** ±9.1% (cv 1.0%, r4 +0.8%) | **8.057** ±9.1% (cv 3.4%, r4 -0.6%) | **0.787** ±6.5% (cv 3.4%, r4 -1.9%) | 13.2× | 0.77× |
| get.indexed | 16 | **0.319** ±0.0% (cv 1.8%, r4 -5.0%) | **0.487** ±0.0% (cv 1.8%, r4 +3.5%) | **0.353** ±10.7% (cv 0.8%, r4 -9.6%) | 1.5× | 0.90× |
| get.span | 16 | **0.407** ±1.5% (cv 1.9%, r4 -0.7%) | **0.491** ±3.3% (cv 2.3%, r4 -0.6%) | **0.406** ±0.5% (cv 1.3%, r4 -0.2%) | 1.2× | 1.00× |
| get.indexed | 1,024 | **0.288** ±2.1% (cv 4.2%, r4 +0.3%) | **0.287** ±1.4% (cv 0.5%, r4 -0.3%) | **0.295** ±1.4% (cv 1.7%, r4 -0.7%) | 1.0× | 0.98× |
| get.span | 1,024 | **0.073** ±4.1% (cv 2.8%, r4 +0.0%) | **0.075** ±1.4% (cv 0.5%, r4 -1.3%) | **0.073** ±0.0% (cv 1.4%, r4 +0.0%) | 1.0× | 1.00× |
| get.indexed | 65,536 | **0.313** ±0.3% (cv 0.7%, r4 -0.6%) | **0.313** ±0.3% (cv 0.7%, r4 +0.3%) | **0.304** ±1.0% (cv 1.6%, r4 +0.3%) | 1.0× | 1.03× |
| get.span | 65,536 | **0.074** ±1.4% (cv 2.7%, r4 +2.7%) | **0.075** ±4.1% (cv 1.8%, r4 +1.3%) | **0.075** ±4.1% (cv 1.5%, r4 +1.3%) | 1.0× | 0.99× |
| set.indexed | 16 | **0.322** ±6.4% (cv 3.0%, r4 +4.7%) | **8.388** ±5.5% (cv 2.8%, r4 -1.2%) | **1.201** ±8.8% (cv 3.2%, r4 +1.1%) | 26.0× | 0.27× |
| set.span | 16 | **0.085** ±1.2% (cv 5.1%, r4 +1.2%) | **0.295** ±8.7% (cv 5.0%, r4 -2.4%) | **0.114** ±3.6% (cv 4.4%, r4 +0.9%) | 3.5× | 0.75× |
| set.indexed | 1,024 | **0.301** ±10.8% (cv 2.8%, r4 -2.7%) | **7.848** ±3.3% (cv 2.7%, r4 +1.1%) | **1.145** ±0.8% (cv 3.4%, r4 +2.4%) | 26.1× | 0.26× |
| set.span | 1,024 | **0.077** ±6.9% (cv 7.6%, r4 -9.1%) | **0.081** ±26.9% (cv 13.1%, r4 -8.6%) | **0.085** ±30.8% (cv 9.7%, r4 -5.9%) | 1.1× | 0.91× |
| set.indexed | 65,536 | **0.295** ±6.2% (cv 4.3%, r4 +1.7%) | **7.963** ±2.8% (cv 3.2%, r4 +0.7%) | **1.143** ±7.5% (cv 3.1%, r4 +2.4%) | 27.0× | 0.26× |
| set.span | 65,536 | **0.116** ±0.9% (cv 3.9%, r4 -2.6%) | **0.114** ±7.5% (cv 8.5%, r4 +0.0%) | **0.098** ±24.2% (cv 6.6%, r4 +18.4%) | 1.0× | 1.18× |
| pushPop.cycle | 16 | **2.050** ±7.8% (cv 3.4%, r4 +3.0%) | **11.549** ±9.2% (cv 3.7%, r4 -1.3%) | **1.513** ±3.2% (cv 0.9%, r4 +2.9%) | 5.6× | 1.35× |
| pushPop.cycle | 1,024 | **1.113** ±2.4% (cv 1.3%, r4 +1.7%) | **9.067** ±2.2% (cv 2.1%, r4 +5.6%) | **0.393** ±11.1% (cv 1.1%, r4 +7.9%) | 8.1× | 2.83× |
| pushPop.cycle | 65,536 | **1.090** ±10.2% (cv 4.0%, r4 +1.9%) | **9.686** ±8.3% (cv 2.4%, r4 +0.7%) | **0.595** ±8.5% (cv 6.2%, r4 +4.7%) | 8.9× | 1.83× |
| detach.firstMutation | 1,024 | — | **1,408.020** ±6.9% (cv 2.4%, r4 +1.9%) | **161.021** ±12.5% (cv 7.5%, r4 -5.5%) | — | — |
| clone.explicit | 1,024 | **317.067** ±17.5% (cv 5.2%, r4 +10.5%) | — | — | — | — |
| detach.firstMutation | 65,536 | — | **81,428.375** ±1.8% (cv 2.0%, r4 +7.8%) | **7,391.922** ±14.3% (cv 14.3%, r4 +5.8%) | — | — |
| clone.explicit | 65,536 | **10,565.750** ±0.3% (cv 1.5%, r4 +8.4%) | — | — | — | — |
| payload.append.zero | 1,024 | **25.564** ±5.0% (cv 1.0%, r4 +2.4%) | **31.829** ±5.5% (cv 0.7%, r4 +4.1%) | **27.517** ±2.2% (cv 0.7%, r4 +6.6%) | 1.2× | 0.93× |
| payload.detach | 1,024 | — | **2,864.176** ±0.1% (cv 1.1%, r4 +5.0%) | **4,766.195** ±0.5% (cv 0.6%, r4 +8.4%) | — | — |

**Validated claims** (the asserted-but-unmeasured class, now measured):

1. **Typed indices are cost-free at the access path**: `get.indexed` tower.direct ≡ stdlib
   (0.288 vs 0.295 @1k; 0.313 vs 0.304 @64k) and `get.span` is three-way identical (0.073–0.075).
2. **The move-only column's writes beat stdlib ~3.8×** (`set.indexed` 0.30 vs 1.14): no
   uniqueness machinery on the direct column vs stdlib's per-write `_makeMutableAndUnique`.
3. **Span-first bulk mutation amortizes the CoW gate to ~zero** (`set.span` cow 0.08–0.11 vs
   `set.indexed` cow ~7.9 → ~70–100×; R4's guidance, now with family-grade numbers).
4. **Read paths are gate-free on both columns** as designed (`get.*` cow ≡ direct at n ≥ 1k;
   the box hop is visible only at n=16, +~50% on a 0.3 ns op).
5. **Payload inversion strength datum**: for refcounted elements the `Shared` detach is
   1.66× FASTER than stdlib's (2,864 vs 4,766 ns @1k) — the element-loop retain/release path
   beats stdlib's bridged copy machinery on this shape.

**Read with care**: `set.span` n=1,024 carries ±27–31% run spread on cow/stdlib (sub-0.1 ns/op
shape, 16k span re-entries per pass; DVFS-sensitive) — its qualitative conclusion (≈ gate-free
bulk) is robust, its point estimate is not. `append.*`/`pushPop` rows include array
init+teardown per rep, amortized over n ops (dominant at n=16 — see the n=16 vs n=1k drop).

### Set / Dictionary — W2

PENDING (vs stdlib `Set`/`Dictionary`: insert / lookup-hit / lookup-miss / remove / iterate).

### Set.Ordered / Dictionary.Ordered — W2

PENDING (the O(n) order-preserving remove CURVE, iteration-order overhead vs unordered).

### Hash engine — W2

PENDING (per-instance seed cost: init + first-insert latency; grow/re-seed cost spike).

### Slot-map — W2

PENDING (handle-validation overhead per access; insert/remove/iterate vs array baseline).

### Shared — W2

PENDING (detach cost vs in-place mutation; gate overhead on the hot read/write path — R4
methodology, measured through the real box rather than a synthetic one).

### Queue / Deque — W2

PENDING (ring ops vs stdlib `Array`-as-queue/deque).

### Stack — W2

PENDING (push/pop vs stdlib `Array`).

### Arena — W2

PENDING (`grow(to:)` relocation cost vs capacity; the trees' performance suites are read-only
seeds — trees themselves are NOT in this arc's edit scope).

## Banked candidates (arc-5 gate inputs; MEASURE-ONLY discipline)

| # | Observation | Family / site | Why banked (not chased) |
|---|---|---|---|
| B-1 | **`Shared` per-mutation tax ≈ 7.3–7.6 ns/op, ~1.7× the R4 synthetic bound (4.3 ns) and ~7× stdlib's own per-write check (1.1 ns)** — flat across n (set.indexed cow 7.85–8.39 vs direct 0.30; append.reserved cow 8.05 vs direct 0.79). The real path = gate + box hop + cross-module `_modify` chain, not the bare `isKnownUniquelyReferenced` R4 isolated. | shared / `Shared` mutation path; consumer side `Array ~Copyable.swift:94` `_modify` → `store.prepareForMutation()` | Optimization is out of this arc's scope; candidates: inlining audit of the gate chain, hoisting the box-pointer load. Quantify through set/dict/queue rows in W2 first — if ~7 ns is invariant across families it is one shared fix, not seven. |
| B-2 | **`Shared` detach copies element-wise (~1.24 ns/slot); the direct column's `clone()` is memcpy-class (~0.16 ns/slot); stdlib detach ~0.11 ns/slot** — detach @64k = 81.4 µs vs direct clone 10.6 µs (7.7×) vs stdlib 7.4 µs (11×), identical `Int` payload. The detach path lacks a trivial-element bulk-copy fast path. | shared / detach (`prepareForMutation` slow path) vs buffer-linear `clone()` | The single largest measured asymmetry; an arc-5-class change inside `Shared`. [BENCH-011]: any fix proposal needs the dual-mode probe (isolated + a consumer walking detach-heavy workloads). |
| B-3 | **Direct-column growth ops trail stdlib at small/mid scales**: append.reserved 1.8× @1k (0.79 vs 0.44), append.zero 2.7× @1k, pop ≈ 4× (derived 1.42 vs 0.35 @1k) — but CROSSOVER at 64k where direct append.reserved beats stdlib 0.77× (0.61 vs 0.79). | array / seam append–removeLast path (`Array+Columns.swift:36`, `Array ~Copyable.swift:146`) | Family-round material, not arc-5; per-op accounting through the seam (count/capacity Tagged arithmetic, no `reserveCapacity` exponential-hint divergence chased). The 64k win suggests the gap is fixed-overhead, not algorithmic. |
| B-4 | **Tiny-array build cost**: append.zero @16 ≈ 24.7 ns/op tower vs 8.6 stdlib — first-allocation policy difference dominates (stdlib's empty singleton + first-growth heuristics vs the column's immediate allocate). | array+buffer-linear / zero-capacity init + first growth | Ergonomics/policy datum for the family round; n=16 rows are init+teardown-dominated by design (documented). |
| B-5 | **Harness lesson — sub-0.1 ns/op bulk shapes need ≥16M-op batches AND still carry 25–30% spread at mid-n** (`set.span` @1k); at 64k the larger target stabilized them to ≤7.5%. | bench harness (`spanOpsTarget`) | W2 families should put bulk-span rows at large n or report them qualitative-only at mid n. |
| B-6 | (strength, not defect) **Payload detach inversion**: `Shared` detach 1.66× faster than stdlib for class elements @1k. | shared / detach retain loop | Record only — corroborates that B-2 is about the trivial-element fast path specifically, not copy machinery generally. |

Standing arc-5 inputs called out by the GOAL (to be quantified in W2/W3):
- **SoA re-cut**: what the current `_generations: [Int]` / `_occupied: [Bool]` stdlib-Array
  layout costs (Storage.Generational.swift:36–48) — slot-map / arena benches carry this.
- **Tree.Position re-cut**: the ~16 B/slot position side-table (trees' `Memory layout sizes`
  suite is the seed; read-only this arc).

## References

- `.handoffs/GOAL-tower-arc-bench.md` — the arc GOAL (inventory, discipline, waves).
- `.handoffs/GOAL-tower-weakness-sweep.md` §2bis #3 — the ranked weakness this arc answers.
- `column-spelling-ergonomics-alias-vocabulary.md` — R4: the methodology precedent + the
  ~4.3 ns/op gate bound this arc's Shared rows must reconcile with.
- `benchmarking-strategy.md` · `benchmark-inline-strategy.md` · `benchmark-result-storage.md` ·
  `swift-testing-performance-infrastructure-gaps.md` — prior art ([RES-019]).
- `copyable-wrapper-vs-multi-buffer-storage.md` — the [BENCH-011] dual-mode discipline.
- `swift-io/Research/io-bench-process-hang.md` + `swift-io/Benchmarks/` — the io-bench precedent
  (nested package shape; the never-`swift test` discipline's origin).
- Benchmark skill [BENCH-001..011] — placement, cleanup, comparison, storage, deferral rules.
