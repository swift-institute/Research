# Tower Family-Tier Benchmark Baselines

<!--
---
version: 1.1.0
last_updated: 2026-06-12
status: RECORDED
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

| Run conditions (W2 batch-1) | Recorded 23:11–23:22 after a 60s-clear sustained-quiet gate; EVERY per-run bracket read procs=0 (the only fully-clean session of the arc). Caveat: the window followed a 33-process build storm on the fanless machine — thermal drain is visible as a quality gradient across the session (set-ordered first/hottest: 55/60 cases >10% cross-run spread; dictionary-ordered last/coolest: 11/60). The array drift-canary in this window read median Δ 10.8% vs W1 (p90 19%) — ABOVE W1's stated spreads; the cooler 22:40 opportunistic canary read 3.0%, so the excess is attributed to thermal state, not drift. Within-session family comparisons are unaffected; cross-referencing W2 absolute numbers against W1's carries the ~10% caveat. W3 cool-window re-confirmation (23:27, procs=0, 20 min idle): **median Δ 1.9%, p90 5.6%, 2/74 cases >10%** — thermal attribution CONFIRMED (hot 10.8% → cooler 3.0% → cool 1.9%); no drift. |

| Run conditions (batch-2, W4) | Quiet-gated 06:31–06:40 (06-12); procs=0 at every bracket; canary median Δ 2.0% vs W1. Zero flagged cases in slot-map (33) and arena (18); 2/22 minor in hash-table. The cleanest session of the arc. |

| Run conditions (terminal wave) | Shared leg recorded in the arc's coolest window (procs=0, load 2.4); stack/set/dict session procs=0 at every bracket; canary median Δ 1.8% (the arc's best). |

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

### Set (flat) — terminal wave, bench beside tip `2bb62d2` (commit `ac7a1a9`)

Recorded 2026-06-12 (terminal session; procs=0 at every bracket; in-window canary vs W1:
median Δ 1.8%, p90 6.2% — the arc's best conditions). The flat family composes the SAME `Hash.Indexed`
combinator as Set.Ordered — B-7 applies here too:

| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **100.09** ±3.1% (cv 0.9%) | **101.95** ±3.9% (cv 0.9%) | **29.12** ±2.7% (cv 0.5%) |
| lookup.hit | 16 | **10.74** ±19.8% (cv 2.2%) | **18.66** ±9.7% (cv 0.8%) | **5.45** ±3.8% (cv 0.7%) |
| lookup.miss | 16 | **10.09** ±9.0% (cv 1.7%) | **20.42** ±1.5% (cv 1.3%) | **5.55** ±4.3% (cv 0.8%) |
| iterate.sum | 16 | **0.40** ±1.5% (cv 0.8%) | **0.49** ±0.4% (cv 1.6%) | **0.44** ±3.2% (cv 1.4%) |
| insert.zero | 1,024 | **42.52** ±5.4% (cv 0.8%) | **57.39** ±4.5% (cv 0.5%) | **19.67** ±2.5% (cv 0.6%) |
| lookup.hit | 1,024 | **13.46** ±5.3% (cv 1.7%) | **23.56** ±1.5% (cv 0.8%) | **5.78** ±4.8% (cv 0.6%) |
| lookup.miss | 1,024 | **14.04** ±4.1% (cv 0.7%) | **32.49** ±1.1% (cv 1.1%) | **5.95** ±6.6% (cv 0.4%) |
| iterate.sum | 1,024 | **0.07** ±0.0% (cv 2.8%) | **0.07** ±0.0% (cv 2.5%) | **0.71** ±1.4% (cv 1.1%) |
| insert.zero | 65,536 | **48.92** ±2.0% (cv 1.9%) | **62.21** ±3.0% (cv 0.7%) | **28.19** ±1.2% (cv 0.5%) |
| lookup.hit | 65,536 | **18.95** ±2.5% (cv 0.8%) | **28.94** ±2.2% (cv 1.5%) | **10.53** ±1.8% (cv 1.0%) |
| lookup.miss | 65,536 | **31.93** ±2.2% (cv 0.7%) | **41.54** ±1.4% (cv 0.6%) | **14.78** ±1.3% (cv 2.9%) |
| iterate.sum | 65,536 | **0.07** ±4.2% (cv 2.9%) | **0.07** ±4.2% (cv 0.4%) | **0.73** ±0.4% (cv 0.7%) |
| churn.steady | 16 | **174.68** ±0.1% (cv 0.6%) | **186.34** ±1.2% (cv 0.8%) | **55.50** ±1.5% (cv 1.3%) |
| churn.steady | 256 | **482.88** ±0.2% (cv 1.0%) | **493.98** ±1.1% (cv 0.6%) | **62.71** ±0.6% (cv 1.0%) |
| churn.steady | 4,096 | **4,947.23** ±1.3% (cv 0.7%) | **5,007.16** ±2.3% (cv 0.9%) | **63.64** ±2.5% (cv 1.0%) |
| churn.steady | 65,536 | **143,427.08** ±5.1% (cv 17.1%) | **143,393.23** ±7.5% (cv 22.0%) | **65.50** ±2.1% (cv 0.7%) |
| buildWipe.keep | 1,024 | **21.55** ±30.0% (cv 10.8%) | **32.60** ±3.8% (cv 2.0%) | **10.46** ±5.4% (cv 2.4%) |
| buildWipe.keep | 65,536 | **28.88** ±23.3% (cv 4.3%) | **35.60** ±1.6% (cv 0.3%) | **11.76** ±0.8% (cv 0.4%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **119.04** ±4.0% (cv 0.5%) | **114.76** ±4.2% (cv 0.4%) | **34.06** ±3.7% (cv 0.6%) |
| lookup.hit | 16 | **11.16** ±11.8% (cv 0.5%) | **26.95** ±3.1% (cv 3.4%) | **6.06** ±6.2% (cv 0.8%) |
| lookup.miss | 16 | **11.13** ±6.8% (cv 1.0%) | **18.45** ±11.4% (cv 2.5%) | **6.13** ±8.4% (cv 1.2%) |
| iterate.sum | 16 | **0.49** ±0.4% (cv 0.4%) | **0.58** ±0.0% (cv 0.4%) | **0.44** ±0.0% (cv 1.2%) |
| insert.zero | 1,024 | **60.84** ±4.1% (cv 1.0%) | **66.17** ±2.5% (cv 0.9%) | **19.30** ±2.3% (cv 2.0%) |
| lookup.hit | 1,024 | **13.34** ±3.6% (cv 2.2%) | **22.97** ±4.0% (cv 0.8%) | **7.16** ±3.2% (cv 0.7%) |
| lookup.miss | 1,024 | **12.51** ±3.0% (cv 1.2%) | **31.00** ±3.2% (cv 1.3%) | **6.71** ±2.3% (cv 1.1%) |
| iterate.sum | 1,024 | **0.17** ±0.6% (cv 4.3%) | **0.17** ±0.0% (cv 1.9%) | **0.72** ±1.7% (cv 0.1%) |
| insert.zero | 65,536 | **62.79** ±6.8% (cv 1.0%) | **68.30** ±3.8% (cv 0.9%) | **28.88** ±1.3% (cv 0.3%) |
| lookup.hit | 65,536 | **19.52** ±0.2% (cv 1.4%) | **35.31** ±0.9% (cv 1.6%) | **11.83** ±1.2% (cv 1.5%) |
| lookup.miss | 65,536 | **32.74** ±0.8% (cv 1.0%) | **39.93** ±1.1% (cv 0.4%) | **15.06** ±0.6% (cv 4.3%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.6%) | **0.17** ±0.0% (cv 0.1%) | **0.73** ±0.3% (cv 1.1%) |
| churn.steady | 16 | **184.98** ±0.5% (cv 0.2%) | **196.65** ±1.7% (cv 0.3%) | **56.88** ±1.4% (cv 3.0%) |
| churn.steady | 256 | **502.85** ±1.3% (cv 0.4%) | **513.78** ±0.6% (cv 0.2%) | **63.87** ±0.6% (cv 1.1%) |
| churn.steady | 4,096 | **5,177.69** ±0.5% (cv 0.4%) | **5,172.85** ±0.7% (cv 0.4%) | **64.27** ±0.4% (cv 0.6%) |
| churn.steady | 65,536 | **118,640.62** ±3.8% (cv 14.9%) | **119,244.80** ±5.2% (cv 14.1%) | **67.58** ±1.8% (cv 0.5%) |
| buildWipe.keep | 1,024 | **35.89** ±4.8% (cv 1.4%) | **42.63** ±3.8% (cv 0.7%) | **10.63** ±2.4% (cv 0.7%) |
| buildWipe.keep | 65,536 | **40.11** ±8.0% (cv 2.0%) | **46.43** ±1.0% (cv 1.0%) | **12.28** ±0.4% (cv 0.4%) |
| shape | n | flat | ordered |
|---|---|---|---|
| insert.zero | 1,024 | 42.515 | 44.236 |
| lookup.hit | 1,024 | 13.463 | 14.037 |
| iterate.sum | 1,024 | 0.071 | 0.074 |
| iterate.sum | 65,536 | 0.072 | 0.072 |

### Dictionary (flat) — terminal wave, bench beside tip `c51d879` (commit `76cc9b9`)

(Same session. The `buildWipe.keep` rows measure the FIXED `removeAll` Shared door —
the c51d879 grant note; CoW wipes are uniform-cost, ±≤4.8%.)

| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **119.04** ±4.0% (cv 0.5%) | **114.76** ±4.2% (cv 0.4%) | **34.06** ±3.7% (cv 0.6%) |
| lookup.hit | 16 | **11.16** ±11.8% (cv 0.5%) | **26.95** ±3.1% (cv 3.4%) | **6.06** ±6.2% (cv 0.8%) |
| lookup.miss | 16 | **11.13** ±6.8% (cv 1.0%) | **18.45** ±11.4% (cv 2.5%) | **6.13** ±8.4% (cv 1.2%) |
| iterate.sum | 16 | **0.49** ±0.4% (cv 0.4%) | **0.58** ±0.0% (cv 0.4%) | **0.44** ±0.0% (cv 1.2%) |
| insert.zero | 1,024 | **60.84** ±4.1% (cv 1.0%) | **66.17** ±2.5% (cv 0.9%) | **19.30** ±2.3% (cv 2.0%) |
| lookup.hit | 1,024 | **13.34** ±3.6% (cv 2.2%) | **22.97** ±4.0% (cv 0.8%) | **7.16** ±3.2% (cv 0.7%) |
| lookup.miss | 1,024 | **12.51** ±3.0% (cv 1.2%) | **31.00** ±3.2% (cv 1.3%) | **6.71** ±2.3% (cv 1.1%) |
| iterate.sum | 1,024 | **0.17** ±0.6% (cv 4.3%) | **0.17** ±0.0% (cv 1.9%) | **0.72** ±1.7% (cv 0.1%) |
| insert.zero | 65,536 | **62.79** ±6.8% (cv 1.0%) | **68.30** ±3.8% (cv 0.9%) | **28.88** ±1.3% (cv 0.3%) |
| lookup.hit | 65,536 | **19.52** ±0.2% (cv 1.4%) | **35.31** ±0.9% (cv 1.6%) | **11.83** ±1.2% (cv 1.5%) |
| lookup.miss | 65,536 | **32.74** ±0.8% (cv 1.0%) | **39.93** ±1.1% (cv 0.4%) | **15.06** ±0.6% (cv 4.3%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.6%) | **0.17** ±0.0% (cv 0.1%) | **0.73** ±0.3% (cv 1.1%) |
| churn.steady | 16 | **184.98** ±0.5% (cv 0.2%) | **196.65** ±1.7% (cv 0.3%) | **56.88** ±1.4% (cv 3.0%) |
| churn.steady | 256 | **502.85** ±1.3% (cv 0.4%) | **513.78** ±0.6% (cv 0.2%) | **63.87** ±0.6% (cv 1.1%) |
| churn.steady | 4,096 | **5,177.69** ±0.5% (cv 0.4%) | **5,172.85** ±0.7% (cv 0.4%) | **64.27** ±0.4% (cv 0.6%) |
| churn.steady | 65,536 | **118,640.62** ±3.8% (cv 14.9%) | **119,244.80** ±5.2% (cv 14.1%) | **67.58** ±1.8% (cv 0.5%) |
| buildWipe.keep | 1,024 | **35.89** ±4.8% (cv 1.4%) | **42.63** ±3.8% (cv 0.7%) | **10.63** ±2.4% (cv 0.7%) |
| buildWipe.keep | 65,536 | **40.11** ±8.0% (cv 2.0%) | **46.43** ±1.0% (cv 1.0%) | **12.28** ±0.4% (cv 0.4%) |
| shape | n | flat | ordered |
|---|---|---|---|
| insert.zero | 1,024 | 42.515 | 44.236 |
| lookup.hit | 1,024 | 13.463 | 14.037 |
| iterate.sum | 1,024 | 0.071 | 0.074 |
| iterate.sum | 65,536 | 0.072 | 0.072 |

**B-7's blast radius extended as predicted**: flat-family `churn.steady` @64k runs
143 µs (set) / 119 µs (dict) per pair vs stdlib's flat 66–68 ns (**≈2,100×**) — the
Θ(capacity) sweep fires identically without any rank surface. **Flat vs Ordered (the
inventory's "iteration-order overhead vs unordered", answered in-tower at identical
combinator):**

| shape | n | flat | ordered |
|---|---|---|---|
| insert.zero | 1,024 | 42.515 | 44.236 |
| lookup.hit | 1,024 | 13.463 | 14.037 |
| iterate.sum | 1,024 | 0.071 | 0.074 |
| iterate.sum | 65,536 | 0.072 | 0.072 |

The rank surface costs ≈4% on insert/lookup and **zero on iteration** — order is nearly
free where it is not being removed; B-7 is the entire ordered-family penalty story.
Wipe-row caveat: `buildWipe.keep` builds pre-sized while `insert.zero` builds from zero —
the wipe delta is not directly subtractable (recorded as the consumer-grade build+wipe
cycle; the set-direct rows carry ±23–30% from wipe-phase variance, the FIXED CoW door is
stable).

### Set.Ordered — W2 batch-1, bench beside tip `3e44537` (commit `3f76acf`)

Recorded 2026-06-11 ~23:11–23:22 in a bracketed clean window (procs=0 at EVERY
bracket; post-storm thermal drain noted — set-ordered ran first/hottest and carries the
widest spreads, dictionary-ordered last/coolest and the tightest; magnitudes agree across
both). Primary = median of 3 run-medians; ± = max pairwise run spread; cv = worst within-run
CV. Pins at the build of record are in REPORT-arc-bench-W2 (hash-table at `2eae321` for the
ordered families).

| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **102.31** ±61.9% (cv 11.6%) | **107.32** ±42.9% (cv 22.5%) | **28.48** ±25.3% (cv 7.2%) |
| lookup.hit | 16 | **11.47** ±69.6% (cv 17.4%) | **21.04** ±92.5% (cv 15.9%) | **5.51** ±72.8% (cv 28.6%) |
| lookup.miss | 16 | **12.50** ±30.3% (cv 8.9%) | **20.91** ±36.7% (cv 23.0%) | **5.69** ±29.0% (cv 2.8%) |
| iterate.sum | 16 | **0.40** ±24.9% (cv 1.0%) | **0.49** ±25.1% (cv 5.6%) | **0.45** ±15.1% (cv 15.7%) |
| insert.zero | 1,024 | **44.24** ±48.1% (cv 17.8%) | **62.12** ±20.1% (cv 8.5%) | **19.82** ±26.7% (cv 2.9%) |
| lookup.hit | 1,024 | **14.04** ±17.9% (cv 21.8%) | **24.70** ±15.6% (cv 1.2%) | **6.03** ±20.2% (cv 9.3%) |
| lookup.miss | 1,024 | **13.93** ±36.2% (cv 25.8%) | **33.76** ±36.1% (cv 14.6%) | **6.24** ±10.9% (cv 55.2%) |
| iterate.sum | 1,024 | **0.07** ±13.9% (cv 31.4%) | **0.08** ±15.1% (cv 20.3%) | **0.75** ±9.1% (cv 4.6%) |
| insert.zero | 65,536 | **51.15** ±12.0% (cv 3.3%) | **63.74** ±11.0% (cv 20.2%) | **28.38** ±12.1% (cv 2.7%) |
| lookup.hit | 65,536 | **19.64** ±17.9% (cv 1.9%) | **35.88** ±171.6% (cv 80.7%) | **13.71** ±63.8% (cv 29.6%) |
| lookup.miss | 65,536 | **36.77** ±36.1% (cv 16.1%) | **42.91** ±10.3% (cv 3.9%) | **15.86** ±16.2% (cv 1.1%) |
| iterate.sum | 65,536 | **0.07** ±15.3% (cv 2.7%) | **0.07** ±13.7% (cv 3.5%) | **0.74** ±5.9% (cv 0.7%) |
| frontEvict.steady | 16 | **175.14** ±12.6% (cv 4.9%) | **193.97** ±18.3% (cv 4.9%) | **56.38** ±25.6% (cv 2.4%) |
| backEvict.steady | 16 | **96.73** ±28.8% (cv 16.3%) | **107.19** ±30.8% (cv 2.1%) | **37.48** ±37.0% (cv 4.2%) |
| frontEvict.steady | 256 | **498.38** ±12.8% (cv 0.9%) | **507.12** ±12.7% (cv 1.3%) | **63.54** ±20.5% (cv 9.9%) |
| backEvict.steady | 256 | **377.90** ±31.4% (cv 5.3%) | **403.16** ±29.0% (cv 2.8%) | **40.90** ±18.1% (cv 3.0%) |
| frontEvict.steady | 4,096 | **5,204.67** ±21.4% (cv 7.1%) | **5,048.34** ±14.1% (cv 0.7%) | **63.46** ±42.3% (cv 5.1%) |
| backEvict.steady | 4,096 | **6,178.35** ±36.6% (cv 4.5%) | **5,870.57** ±62.4% (cv 24.7%) | **42.11** ±46.3% (cv 20.9%) |
| frontEvict.steady | 65,536 | **141,044.92** ±10.6% (cv 13.2%) | **154,896.48** ±50.7% (cv 34.8%) | **65.51** ±0.2% (cv 1.7%) |
| backEvict.steady | 65,536 | **238,039.75** ±3.9% (cv 14.4%) | **236,280.13** ±12.9% (cv 15.1%) | **41.99** ±3.0% (cv 1.9%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **120.48** ±3.8% (cv 3.1%) | **116.69** ±3.8% (cv 7.1%) | **32.11** ±4.8% (cv 1.2%) |
| lookup.hit | 16 | **11.17** ±13.0% (cv 2.9%) | **27.50** ±6.2% (cv 3.6%) | **6.32** ±7.4% (cv 1.0%) |
| lookup.miss | 16 | **11.27** ±4.2% (cv 1.2%) | **15.20** ±20.0% (cv 1.6%) | **6.50** ±15.0% (cv 0.8%) |
| iterate.sum | 16 | **0.49** ±0.8% (cv 0.8%) | **0.58** ±2.1% (cv 1.4%) | **0.44** ±1.8% (cv 3.1%) |
| insert.zero | 1,024 | **60.24** ±11.0% (cv 2.8%) | **71.30** ±4.6% (cv 5.8%) | **20.38** ±5.7% (cv 38.6%) |
| lookup.hit | 1,024 | **14.20** ±13.1% (cv 1.8%) | **24.38** ±10.5% (cv 2.6%) | **7.26** ±1.0% (cv 1.2%) |
| lookup.miss | 1,024 | **12.96** ±6.4% (cv 4.6%) | **30.98** ±7.6% (cv 1.6%) | **6.85** ±5.0% (cv 3.5%) |
| iterate.sum | 1,024 | **0.17** ±1.2% (cv 3.9%) | **0.17** ±4.0% (cv 2.7%) | **0.71** ±3.0% (cv 2.0%) |
| insert.zero | 65,536 | **62.75** ±1.2% (cv 1.4%) | **68.90** ±1.2% (cv 0.8%) | **29.41** ±4.8% (cv 4.9%) |
| lookup.hit | 65,536 | **19.01** ±7.9% (cv 4.4%) | **34.79** ±5.0% (cv 3.6%) | **12.00** ±2.1% (cv 3.6%) |
| lookup.miss | 65,536 | **32.79** ±1.9% (cv 1.2%) | **39.62** ±1.0% (cv 1.6%) | **17.05** ±3.5% (cv 1.9%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.4%) | **0.17** ±0.0% (cv 1.4%) | **0.73** ±1.0% (cv 0.7%) |
| frontEvict.steady | 16 | **186.58** ±0.2% (cv 0.3%) | **197.90** ±1.6% (cv 0.5%) | **57.23** ±0.4% (cv 0.6%) |
| backEvict.steady | 16 | **105.22** ±1.8% (cv 1.0%) | **120.37** ±2.1% (cv 0.7%) | **40.45** ±5.5% (cv 1.0%) |
| frontEvict.steady | 256 | **523.65** ±2.3% (cv 0.8%) | **526.72** ±2.4% (cv 1.6%) | **64.43** ±1.1% (cv 2.3%) |
| backEvict.steady | 256 | **382.71** ±7.9% (cv 4.2%) | **406.83** ±10.7% (cv 3.0%) | **42.09** ±7.2% (cv 2.0%) |
| frontEvict.steady | 4,096 | **5,352.86** ±1.2% (cv 2.0%) | **5,346.15** ±1.6% (cv 1.5%) | **64.79** ±1.1% (cv 7.1%) |
| backEvict.steady | 4,096 | **5,585.55** ±9.6% (cv 3.5%) | **5,916.08** ±9.2% (cv 7.1%) | **42.25** ±2.7% (cv 1.0%) |
| frontEvict.steady | 65,536 | **157,851.56** ±21.3% (cv 9.5%) | **157,326.17** ±22.8% (cv 19.3%) | **67.76** ±2.3% (cv 1.1%) |
| backEvict.steady | 65,536 | **198,922.23** ±10.9% (cv 6.9%) | **187,134.26** ±21.9% (cv 8.4%) | **43.06** ±1.0% (cv 0.7%) |

### Dictionary.Ordered — W2 batch-1, bench beside tip `10153d2` (commit `eee4ae5`)

| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **120.48** ±3.8% (cv 3.1%) | **116.69** ±3.8% (cv 7.1%) | **32.11** ±4.8% (cv 1.2%) |
| lookup.hit | 16 | **11.17** ±13.0% (cv 2.9%) | **27.50** ±6.2% (cv 3.6%) | **6.32** ±7.4% (cv 1.0%) |
| lookup.miss | 16 | **11.27** ±4.2% (cv 1.2%) | **15.20** ±20.0% (cv 1.6%) | **6.50** ±15.0% (cv 0.8%) |
| iterate.sum | 16 | **0.49** ±0.8% (cv 0.8%) | **0.58** ±2.1% (cv 1.4%) | **0.44** ±1.8% (cv 3.1%) |
| insert.zero | 1,024 | **60.24** ±11.0% (cv 2.8%) | **71.30** ±4.6% (cv 5.8%) | **20.38** ±5.7% (cv 38.6%) |
| lookup.hit | 1,024 | **14.20** ±13.1% (cv 1.8%) | **24.38** ±10.5% (cv 2.6%) | **7.26** ±1.0% (cv 1.2%) |
| lookup.miss | 1,024 | **12.96** ±6.4% (cv 4.6%) | **30.98** ±7.6% (cv 1.6%) | **6.85** ±5.0% (cv 3.5%) |
| iterate.sum | 1,024 | **0.17** ±1.2% (cv 3.9%) | **0.17** ±4.0% (cv 2.7%) | **0.71** ±3.0% (cv 2.0%) |
| insert.zero | 65,536 | **62.75** ±1.2% (cv 1.4%) | **68.90** ±1.2% (cv 0.8%) | **29.41** ±4.8% (cv 4.9%) |
| lookup.hit | 65,536 | **19.01** ±7.9% (cv 4.4%) | **34.79** ±5.0% (cv 3.6%) | **12.00** ±2.1% (cv 3.6%) |
| lookup.miss | 65,536 | **32.79** ±1.9% (cv 1.2%) | **39.62** ±1.0% (cv 1.6%) | **17.05** ±3.5% (cv 1.9%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.4%) | **0.17** ±0.0% (cv 1.4%) | **0.73** ±1.0% (cv 0.7%) |
| frontEvict.steady | 16 | **186.58** ±0.2% (cv 0.3%) | **197.90** ±1.6% (cv 0.5%) | **57.23** ±0.4% (cv 0.6%) |
| backEvict.steady | 16 | **105.22** ±1.8% (cv 1.0%) | **120.37** ±2.1% (cv 0.7%) | **40.45** ±5.5% (cv 1.0%) |
| frontEvict.steady | 256 | **523.65** ±2.3% (cv 0.8%) | **526.72** ±2.4% (cv 1.6%) | **64.43** ±1.1% (cv 2.3%) |
| backEvict.steady | 256 | **382.71** ±7.9% (cv 4.2%) | **406.83** ±10.7% (cv 3.0%) | **42.09** ±7.2% (cv 2.0%) |
| frontEvict.steady | 4,096 | **5,352.86** ±1.2% (cv 2.0%) | **5,346.15** ±1.6% (cv 1.5%) | **64.79** ±1.1% (cv 7.1%) |
| backEvict.steady | 4,096 | **5,585.55** ±9.6% (cv 3.5%) | **5,916.08** ±9.2% (cv 7.1%) | **42.25** ±2.7% (cv 1.0%) |
| frontEvict.steady | 65,536 | **157,851.56** ±21.3% (cv 9.5%) | **157,326.17** ±22.8% (cv 19.3%) | **67.76** ±2.3% (cv 1.1%) |
| backEvict.steady | 65,536 | **198,922.23** ±10.9% (cv 6.9%) | **187,134.26** ±21.9% (cv 8.4%) | **43.06** ±1.0% (cv 0.7%) |

**The order-preserving remove curve (the inventory's target), both families**: one op = one
remove+insert pair at steady occupancy n. Against stdlib's flat ~40–68 ns, the tower pair
cost grows super-linearly to ~141–238 µs at n=64k (≈3,000–5,600×). Two distinct facets:
(1) the documented dense shift is NOT the dominant term — see banked B-7 (the Θ(capacity)
bucket sweep on every remove, `Hash.Table+PositionUpdates.swift:45–57`); (2) an INVERSION at
n ≥ 4k: removing the NEWEST element (zero shift, zero fixups) costs MORE than removing the
oldest (dict @64k: 199 µs back vs 158 µs front, spreads ≤ ~11%) — unexplained by the sweep
alone; banked as B-7's anomaly facet. `iterate.sum` is the counterweight strength: the dense
buffer scans 4–11× FASTER than stdlib's buckets (set 0.07 vs 0.74; dict 0.17 vs 0.73 ns/elem).
Reads through the `Shared` column pay ~+10–16 ns/lookup that array's reads did NOT show —
banked B-8.

### Hash engine — batch-2, bench beside tip `7b3052a` (commit `0b807c9`)

Recorded 2026-06-12 06:31–06:40, quiet-gated (60 s sustained-clear), procs=0 at EVERY
bracket; in-window array canary vs W1: median Δ 2.0% (p90 6.7%) — recording-grade
conditions throughout.

| shape | n | tower.table | tower.indexed | stdlib |
|---|---|---|---|---|
| init.zero | 0 | **273.22** ±1.9% (cv 3.7%) | — | **0.00** ±0.0% (cv 89.5%) |
| init.sized | 16 | **261.14** ±2.2% (cv 0.4%) | — | **58.24** ±1.3% (cv 2.4%) |
| init.sized | 1,024 | **1,053.66** ±1.2% (cv 1.3%) | — | **62.13** ±2.5% (cv 1.1%) |
| init.sized | 65,536 | **54,665.36** ±9.4% (cv 9.1%) | — | **853.52** ±15.5% (cv 1.7%) |
| init.firstInsert | 1 | — | **503.73** ±3.5% (cv 2.2%) | **42.55** ±2.9% (cv 1.0%) |
| build.zero | 1,024 | — | **42.77** ±9.6% (cv 0.6%) | **19.70** ±2.9% (cv 0.6%) |
| build.reserved | 1,024 | — | **20.09** ±15.4% (cv 3.0%) | **9.22** ±3.2% (cv 0.4%) |
| build.zero | 4,096 | — | **47.24** ±5.1% (cv 0.6%) | **21.07** ±0.6% (cv 0.6%) |
| build.reserved | 4,096 | — | **22.32** ±6.0% (cv 2.2%) | **9.65** ±1.7% (cv 0.4%) |
| build.zero | 65,536 | — | **49.76** ±3.3% (cv 1.7%) | **28.11** ±0.6% (cv 0.4%) |
| build.reserved | 65,536 | — | **24.48** ±3.3% (cv 2.1%) | **10.69** ±1.0% (cv 0.4%) |
| n | build.control ns/op | growRelocate ns/op | delta ns | delta ns/slot |
|---|---|---|---|---|
| 256 | 1,843 | 5,033 | 3,190 | 12.46 |
| 4,096 | 26,725 | 75,472 | 48,747 | 11.90 |
| 65,536 | 412,164 | 1,162,214 | 750,050 | 11.44 |

**Per-instance seeding quantified**: `init.zero` 273 ns vs `Swift.Set`'s ~0 (free empty
singleton; the institute Table pays `makeSeed()`'s `SystemRandomNumberGenerator` read +
allocation per instance — `Hash.Table.swift:124`). `init.sized` grows O(capacity) with the
bucket-metadata fill (~0.83 ns/bucket at 64k: 54.7 µs) where stdlib's sized init stays
58–854 ns. `init.firstInsert` 504 vs 43 ns (11.8×). Steady inserts: reserved 20–24 vs
stdlib 9.2–10.7 ns (≈2.2×); the growth tax (zero − reserved) ≈ +23–25 ns/insert vs stdlib's
+10–17. Two rows flagged ~15% (init.sized stdlib @64k; build.reserved @1k) — noted, minor.

### Slot-map — batch-2, bench beside tip `a420d48` (commit `23e6cd5`)

Recorded 2026-06-12 06:31–06:40, quiet-gated (60 s sustained-clear), procs=0 at EVERY
bracket; in-window array canary vs W1: median Δ 2.0% (p90 6.7%) — recording-grade
conditions throughout. Pins: the batch-2 tips themselves (arena `52537ef` · slot-map
`a420d48` · hash-table `7b3052a`, seat-granted post-W3-0).

| shape | n | tower.direct | tower.cow | stdlib.array | stdlib.dictionary |
|---|---|---|---|---|---|
| access.valid | 16 | **1.23** ±0.1% (cv 0.8%) | **4.03** ±0.4% (cv 0.3%) | **0.34** ±2.1% (cv 2.9%) | **6.05** ±8.9% (cv 0.4%) |
| access.stale | 16 | **0.82** ±0.6% (cv 0.5%) | — | — | — |
| removeInsert.cycle | 16 | **5.10** ±0.9% (cv 0.7%) | **10.81** ±0.3% (cv 0.6%) | — | **19.60** ±7.1% (cv 0.5%) |
| iterate.full | 16 | **0.81** ±0.9% (cv 0.7%) | — | — | — |
| iterate.holes | 16 | **1.36** ±1.6% (cv 0.6%) | — | — | — |
| build.reserved | 16 | **18.74** ±4.0% (cv 0.9%) | — | — | — |
| access.valid | 1,024 | **1.21** ±2.5% (cv 21.0%) | **3.75** ±3.4% (cv 0.6%) | **0.29** ±3.8% (cv 0.9%) | **7.43** ±2.4% (cv 0.7%) |
| access.stale | 1,024 | **0.82** ±0.6% (cv 0.9%) | — | — | — |
| removeInsert.cycle | 1,024 | **5.15** ±1.4% (cv 0.6%) | **10.81** ±0.7% (cv 0.6%) | — | **20.29** ±5.1% (cv 0.6%) |
| iterate.full | 1,024 | **0.81** ±0.7% (cv 0.9%) | — | — | — |
| iterate.holes | 1,024 | **1.33** ±0.1% (cv 0.3%) | — | — | — |
| build.reserved | 1,024 | **6.51** ±0.6% (cv 0.6%) | — | — | — |
| access.valid | 65,536 | **1.21** ±1.5% (cv 0.8%) | **3.75** ±0.6% (cv 0.5%) | **0.30** ±1.7% (cv 1.4%) | **11.85** ±2.8% (cv 0.5%) |
| access.stale | 65,536 | **0.81** ±1.2% (cv 0.6%) | — | — | — |
| removeInsert.cycle | 65,536 | **5.16** ±1.0% (cv 0.4%) | **10.83** ±0.2% (cv 0.4%) | — | **20.96** ±2.0% (cv 0.7%) |
| iterate.full | 65,536 | **0.80** ±0.9% (cv 0.6%) | — | — | — |
| iterate.holes | 65,536 | **1.33** ±0.5% (cv 0.9%) | — | — | — |
| build.reserved | 65,536 | **6.23** ±0.6% (cv 0.4%) | — | — | — |
| shape | n | tower.direct |
|---|---|---|
| build.control | 256 | **1,843.36** ±0.4% (cv 2.3%) |
| growRelocate.curve | 256 | **5,033.06** ±1.9% (cv 1.1%) |
| build.control | 4,096 | **26,725.26** ±2.1% (cv 0.7%) |
| growRelocate.curve | 4,096 | **75,472.49** ±0.2% (cv 0.9%) |
| build.control | 65,536 | **412,164.06** ±0.8% (cv 0.4%) |
| growRelocate.curve | 65,536 | **1,162,213.56** ±0.2% (cv 0.5%) |
| contains.valid | 16 | **0.82** ±0.2% (cv 0.6%) |
| removeInsert.cycle | 16 | **5.20** ±0.7% (cv 0.3%) |
| iterate.full | 16 | **0.82** ±0.9% (cv 0.6%) |
| iterate.holes | 16 | **1.37** ±0.5% (cv 0.7%) |
| contains.valid | 1,024 | **0.81** ±0.8% (cv 0.7%) |
| removeInsert.cycle | 1,024 | **5.22** ±1.0% (cv 0.8%) |
| iterate.full | 1,024 | **0.81** ±1.1% (cv 1.0%) |
| iterate.holes | 1,024 | **1.35** ±0.7% (cv 0.7%) |
| contains.valid | 65,536 | **0.80** ±1.0% (cv 1.0%) |
| removeInsert.cycle | 65,536 | **5.25** ±0.6% (cv 0.2%) |
| iterate.full | 65,536 | **0.80** ±0.1% (cv 0.6%) |
| iterate.holes | 65,536 | **1.33** ±0.1% (cv 0.3%) |
| shape | n | tower.table | tower.indexed | stdlib |
|---|---|---|---|---|
| init.zero | 0 | **273.22** ±1.9% (cv 3.7%) | — | **0.00** ±0.0% (cv 89.5%) |
| init.sized | 16 | **261.14** ±2.2% (cv 0.4%) | — | **58.24** ±1.3% (cv 2.4%) |
| init.sized | 1,024 | **1,053.66** ±1.2% (cv 1.3%) | — | **62.13** ±2.5% (cv 1.1%) |
| init.sized | 65,536 | **54,665.36** ±9.4% (cv 9.1%) | — | **853.52** ±15.5% (cv 1.7%) |
| init.firstInsert | 1 | — | **503.73** ±3.5% (cv 2.2%) | **42.55** ±2.9% (cv 1.0%) |
| build.zero | 1,024 | — | **42.77** ±9.6% (cv 0.6%) | **19.70** ±2.9% (cv 0.6%) |
| build.reserved | 1,024 | — | **20.09** ±15.4% (cv 3.0%) | **9.22** ±3.2% (cv 0.4%) |
| build.zero | 4,096 | — | **47.24** ±5.1% (cv 0.6%) | **21.07** ±0.6% (cv 0.6%) |
| build.reserved | 4,096 | — | **22.32** ±6.0% (cv 2.2%) | **9.65** ±1.7% (cv 0.4%) |
| build.zero | 65,536 | — | **49.76** ±3.3% (cv 1.7%) | **28.11** ±0.6% (cv 0.4%) |
| build.reserved | 65,536 | — | **24.48** ±3.3% (cv 2.1%) | **10.69** ±1.0% (cv 0.4%) |
| n | build.control ns/op | growRelocate ns/op | delta ns | delta ns/slot |
|---|---|---|---|---|
| 256 | 1,843 | 5,033 | 3,190 | 12.46 |
| 4,096 | 26,725 | 75,472 | 48,747 | 11.90 |
| 65,536 | 412,164 | 1,162,214 | 750,050 | 11.44 |

**Zero cases flagged** (all spreads ≤ ~9%). Handle-validated access is **1.21 ns flat
across three decades** of slot count — vs 0.30 ns raw `[Int]` (the ledger+wrapper tax
≈ 0.9 ns/access) and vs 6.0–11.9 ns `Swift.Dictionary` (the stable-key alternative loses
5–10× AND degrades with n while the slot-map stays flat). Stale-handle rejection costs the
same as a hit (0.81 ns — the generation compare is the whole check). The CoW box adds
+2.5 ns/read here (single hop) — sharpening B-8: the ordered families' +10–16 ns is
per-PROBE re-entry, not the hop itself.

### Shared — terminal wave, bench beside tip `b652394` (commit `1e6dfde`)

Recorded 2026-06-12 (terminal session; procs=0 at every bracket; in-window canary vs W1:
median Δ 1.8%, p90 6.2% — the arc's best conditions). The gate decomposition (every gated door vs its
`AssumingUnique` twin vs the bare Linear column at identical substrate; boxes unique
throughout the gated rows — R4's worst case):

| shape | n | shared.unique | column.direct | shared.sibling |
|---|---|---|---|---|
| gate.prepareForMutation | 1,024 | **1.06** ±5.0% (cv 2.6%) | — | — |
| gate.ensureUnique | 1,024 | **1.06** ±3.8% (cv 3.1%) | — | — |
| appendPop.gated | 1,024 | **6.21** ±0.1% (cv 0.3%) | — | — |
| appendPop.assumingUnique | 1,024 | **5.15** ±0.1% (cv 0.5%) | — | — |
| appendPop.bareColumn | 1,024 | — | **1.19** ±2.7% (cv 7.1%) | — |
| write.subscript | 1,024 | **3.73** ±0.1% (cv 0.6%) | — | — |
| write.span | 1,024 | **0.07** ±22.9% (cv 5.1%) | — | — |
| write.spanAssumingUnique | 1,024 | **0.07** ±24.6% (cv 2.1%) | — | — |
| read.subscript | 1,024 | **0.17** ±0.6% (cv 0.7%) | **0.16** ±0.6% (cv 0.5%) | — |
| read.span | 1,024 | **0.07** ±2.8% (cv 2.2%) | — | — |
| detach.firstMutation | 1,024 | — | — | **1,321.63** ±4.5% (cv 3.3%) |
| detach.firstMutation | 65,536 | — | — | **76,402.34** ±7.9% (cv 2.4%) |
| shape | n | tower.stack | stdlib |
|---|---|---|---|
| pushPop.cycle | 16 | **7.72** ±4.9% (cv 1.0%) | **1.94** ±53.2% (cv 19.8%) |
| build.zero | 16 | **23.22** ±2.5% (cv 0.8%) | **8.49** ±1.6% (cv 1.1%) |
| pushPop.cycle | 1,024 | **7.71** ±0.2% (cv 0.4%) | **1.95** ±52.0% (cv 15.0%) |
| build.zero | 1,024 | **9.38** ±0.3% (cv 0.8%) | **0.89** ±5.4% (cv 1.3%) |
| pushPop.cycle | 65,536 | **7.72** ±0.2% (cv 0.4%) | **1.95** ±0.5% (cv 0.5%) |
| build.zero | 65,536 | **8.87** ±0.8% (cv 0.6%) | **1.08** ±2.0% (cv 1.9%) |
| detach.firstMutation | 1,024 | **2,368.40** ±0.1% (cv 0.5%) | **155.03** ±6.9% (cv 10.4%) |
| detach.firstMutation | 65,536 | **142,660.80** ±0.4% (cv 0.5%) | **6,236.33** ±10.9% (cv 4.5%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **100.09** ±3.1% (cv 0.9%) | **101.95** ±3.9% (cv 0.9%) | **29.12** ±2.7% (cv 0.5%) |
| lookup.hit | 16 | **10.74** ±19.8% (cv 2.2%) | **18.66** ±9.7% (cv 0.8%) | **5.45** ±3.8% (cv 0.7%) |
| lookup.miss | 16 | **10.09** ±9.0% (cv 1.7%) | **20.42** ±1.5% (cv 1.3%) | **5.55** ±4.3% (cv 0.8%) |
| iterate.sum | 16 | **0.40** ±1.5% (cv 0.8%) | **0.49** ±0.4% (cv 1.6%) | **0.44** ±3.2% (cv 1.4%) |
| insert.zero | 1,024 | **42.52** ±5.4% (cv 0.8%) | **57.39** ±4.5% (cv 0.5%) | **19.67** ±2.5% (cv 0.6%) |
| lookup.hit | 1,024 | **13.46** ±5.3% (cv 1.7%) | **23.56** ±1.5% (cv 0.8%) | **5.78** ±4.8% (cv 0.6%) |
| lookup.miss | 1,024 | **14.04** ±4.1% (cv 0.7%) | **32.49** ±1.1% (cv 1.1%) | **5.95** ±6.6% (cv 0.4%) |
| iterate.sum | 1,024 | **0.07** ±0.0% (cv 2.8%) | **0.07** ±0.0% (cv 2.5%) | **0.71** ±1.4% (cv 1.1%) |
| insert.zero | 65,536 | **48.92** ±2.0% (cv 1.9%) | **62.21** ±3.0% (cv 0.7%) | **28.19** ±1.2% (cv 0.5%) |
| lookup.hit | 65,536 | **18.95** ±2.5% (cv 0.8%) | **28.94** ±2.2% (cv 1.5%) | **10.53** ±1.8% (cv 1.0%) |
| lookup.miss | 65,536 | **31.93** ±2.2% (cv 0.7%) | **41.54** ±1.4% (cv 0.6%) | **14.78** ±1.3% (cv 2.9%) |
| iterate.sum | 65,536 | **0.07** ±4.2% (cv 2.9%) | **0.07** ±4.2% (cv 0.4%) | **0.73** ±0.4% (cv 0.7%) |
| churn.steady | 16 | **174.68** ±0.1% (cv 0.6%) | **186.34** ±1.2% (cv 0.8%) | **55.50** ±1.5% (cv 1.3%) |
| churn.steady | 256 | **482.88** ±0.2% (cv 1.0%) | **493.98** ±1.1% (cv 0.6%) | **62.71** ±0.6% (cv 1.0%) |
| churn.steady | 4,096 | **4,947.23** ±1.3% (cv 0.7%) | **5,007.16** ±2.3% (cv 0.9%) | **63.64** ±2.5% (cv 1.0%) |
| churn.steady | 65,536 | **143,427.08** ±5.1% (cv 17.1%) | **143,393.23** ±7.5% (cv 22.0%) | **65.50** ±2.1% (cv 0.7%) |
| buildWipe.keep | 1,024 | **21.55** ±30.0% (cv 10.8%) | **32.60** ±3.8% (cv 2.0%) | **10.46** ±5.4% (cv 2.4%) |
| buildWipe.keep | 65,536 | **28.88** ±23.3% (cv 4.3%) | **35.60** ±1.6% (cv 0.3%) | **11.76** ±0.8% (cv 0.4%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **119.04** ±4.0% (cv 0.5%) | **114.76** ±4.2% (cv 0.4%) | **34.06** ±3.7% (cv 0.6%) |
| lookup.hit | 16 | **11.16** ±11.8% (cv 0.5%) | **26.95** ±3.1% (cv 3.4%) | **6.06** ±6.2% (cv 0.8%) |
| lookup.miss | 16 | **11.13** ±6.8% (cv 1.0%) | **18.45** ±11.4% (cv 2.5%) | **6.13** ±8.4% (cv 1.2%) |
| iterate.sum | 16 | **0.49** ±0.4% (cv 0.4%) | **0.58** ±0.0% (cv 0.4%) | **0.44** ±0.0% (cv 1.2%) |
| insert.zero | 1,024 | **60.84** ±4.1% (cv 1.0%) | **66.17** ±2.5% (cv 0.9%) | **19.30** ±2.3% (cv 2.0%) |
| lookup.hit | 1,024 | **13.34** ±3.6% (cv 2.2%) | **22.97** ±4.0% (cv 0.8%) | **7.16** ±3.2% (cv 0.7%) |
| lookup.miss | 1,024 | **12.51** ±3.0% (cv 1.2%) | **31.00** ±3.2% (cv 1.3%) | **6.71** ±2.3% (cv 1.1%) |
| iterate.sum | 1,024 | **0.17** ±0.6% (cv 4.3%) | **0.17** ±0.0% (cv 1.9%) | **0.72** ±1.7% (cv 0.1%) |
| insert.zero | 65,536 | **62.79** ±6.8% (cv 1.0%) | **68.30** ±3.8% (cv 0.9%) | **28.88** ±1.3% (cv 0.3%) |
| lookup.hit | 65,536 | **19.52** ±0.2% (cv 1.4%) | **35.31** ±0.9% (cv 1.6%) | **11.83** ±1.2% (cv 1.5%) |
| lookup.miss | 65,536 | **32.74** ±0.8% (cv 1.0%) | **39.93** ±1.1% (cv 0.4%) | **15.06** ±0.6% (cv 4.3%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.6%) | **0.17** ±0.0% (cv 0.1%) | **0.73** ±0.3% (cv 1.1%) |
| churn.steady | 16 | **184.98** ±0.5% (cv 0.2%) | **196.65** ±1.7% (cv 0.3%) | **56.88** ±1.4% (cv 3.0%) |
| churn.steady | 256 | **502.85** ±1.3% (cv 0.4%) | **513.78** ±0.6% (cv 0.2%) | **63.87** ±0.6% (cv 1.1%) |
| churn.steady | 4,096 | **5,177.69** ±0.5% (cv 0.4%) | **5,172.85** ±0.7% (cv 0.4%) | **64.27** ±0.4% (cv 0.6%) |
| churn.steady | 65,536 | **118,640.62** ±3.8% (cv 14.9%) | **119,244.80** ±5.2% (cv 14.1%) | **67.58** ±1.8% (cv 0.5%) |
| buildWipe.keep | 1,024 | **35.89** ±4.8% (cv 1.4%) | **42.63** ±3.8% (cv 0.7%) | **10.63** ±2.4% (cv 0.7%) |
| buildWipe.keep | 65,536 | **40.11** ±8.0% (cv 2.0%) | **46.43** ±1.0% (cv 1.0%) | **12.28** ±0.4% (cv 0.4%) |
| shape | n | flat | ordered |
|---|---|---|---|
| insert.zero | 1,024 | 42.515 | 44.236 |
| lookup.hit | 1,024 | 13.463 | 14.037 |
| iterate.sum | 1,024 | 0.071 | 0.074 |
| iterate.sum | 65,536 | 0.072 | 0.072 |

**The B-1′ re-attribution (the engine-fix arc's target map):** the uniqueness gate ALONE
costs **1.06 ns** — three-way agreement (isolated prepareForMutation; ensureUnique; the
gated−assumingUnique pair difference 6.21−5.15). The dominant term is the **box ≈3.9 ns**
(assumingUnique 5.15 vs bare column 1.19); family seams add ≈2–3 ns more to the ~7 ns
family-level tax. Reads through the box are free on the subscript path (0.17 vs 0.16);
bulk spans amortize everything (0.07). Detach: 1,322 ns @1k / 76.4 µs @64k (**1.17–1.29
ns/slot** — B-2's element-wise copy confirmed at box level). R4's ~4.3 ns synthetic bound
was the gate + an @inline(never) work boundary; the shipped inlinable gate on a
predicted-true branch runs ~1 ns.

### Queue — W2 batch-1, bench beside tip `131a0be` (commit `86fd9e4`)

Recorded 2026-06-11 ~23:11–23:22 in a bracketed clean window (procs=0 at EVERY
bracket; post-storm thermal drain noted — set-ordered ran first/hottest and carries the
widest spreads, dictionary-ordered last/coolest and the tightest; magnitudes agree across
both). Primary = median of 3 run-medians; ± = max pairwise run spread; cv = worst within-run
CV.

| shape | n | tower.direct | tower.cow | tower.bounded | stdlib.shift |
|---|---|---|---|---|---|
| cycle.steady | 16 | **2.62** ±0.8% (cv 1.8%) | **10.02** ±5.3% (cv 0.9%) | **2.91** ±0.6% (cv 0.6%) | **2.12** ±14.0% (cv 1.5%) |
| enqueue.zero | 16 | **25.87** ±3.0% (cv 1.6%) | **25.91** ±4.9% (cv 2.0%) | — | **8.78** ±2.3% (cv 4.0%) |
| cycle.steady | 1,024 | **2.60** ±0.5% (cv 0.4%) | **9.70** ±6.2% (cv 2.0%) | **2.95** ±0.7% (cv 0.7%) | **45.32** ±0.0% (cv 1.4%) |
| enqueue.zero | 1,024 | **2.70** ±1.5% (cv 1.2%) | **11.75** ±0.2% (cv 0.9%) | — | **0.85** ±2.5% (cv 2.6%) |
| cycle.steady | 65,536 | **2.61** ±1.3% (cv 1.1%) | **9.41** ±3.9% (cv 1.5%) | **2.95** ±1.0% (cv 0.9%) | **4,345.05** ±1.1% (cv 1.2%) |
| enqueue.zero | 65,536 | **2.10** ±0.7% (cv 0.8%) | **11.16** ±1.4% (cv 1.0%) | — | **1.06** ±1.7% (cv 2.5%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| backBack.steady | 16 | **1.57** ±14.6% (cv 3.8%) | **12.40** ±14.2% (cv 3.3%) | **1.43** ±54.0% (cv 23.1%) |
| frontFront.steady | 16 | **4.08** ±9.3% (cv 3.0%) | **8.80** ±13.5% (cv 2.4%) | **4.15** ±56.8% (cv 31.8%) |
| rotate.steady | 16 | **2.60** ±6.3% (cv 2.6%) | **9.77** ±10.6% (cv 1.6%) | **2.33** ±29.5% (cv 6.6%) |
| backBack.steady | 1,024 | **1.55** ±9.2% (cv 3.8%) | **12.46** ±12.3% (cv 4.2%) | **1.95** ±55.1% (cv 9.9%) |
| frontFront.steady | 1,024 | **4.08** ±1.9% (cv 0.4%) | **8.80** ±8.6% (cv 1.8%) | **100.09** ±7.2% (cv 1.7%) |
| rotate.steady | 1,024 | **2.60** ±1.9% (cv 0.4%) | **9.30** ±8.5% (cv 1.8%) | **50.06** ±6.3% (cv 4.5%) |
| backBack.steady | 65,536 | **1.47** ±15.3% (cv 1.4%) | **12.67** ±7.7% (cv 2.1%) | **1.32** ±31.6% (cv 18.2%) |
| frontFront.steady | 65,536 | **4.16** ±18.9% (cv 10.2%) | **9.37** ±29.2% (cv 19.0%) | **9,056.64** ±251.5% (cv 30.4%) |
| rotate.steady | 65,536 | **2.78** ±57.8% (cv 34.8%) | **9.90** ±11.8% (cv 2.9%) | **4,815.11** ±4.5% (cv 0.2%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **102.31** ±61.9% (cv 11.6%) | **107.32** ±42.9% (cv 22.5%) | **28.48** ±25.3% (cv 7.2%) |
| lookup.hit | 16 | **11.47** ±69.6% (cv 17.4%) | **21.04** ±92.5% (cv 15.9%) | **5.51** ±72.8% (cv 28.6%) |
| lookup.miss | 16 | **12.50** ±30.3% (cv 8.9%) | **20.91** ±36.7% (cv 23.0%) | **5.69** ±29.0% (cv 2.8%) |
| iterate.sum | 16 | **0.40** ±24.9% (cv 1.0%) | **0.49** ±25.1% (cv 5.6%) | **0.45** ±15.1% (cv 15.7%) |
| insert.zero | 1,024 | **44.24** ±48.1% (cv 17.8%) | **62.12** ±20.1% (cv 8.5%) | **19.82** ±26.7% (cv 2.9%) |
| lookup.hit | 1,024 | **14.04** ±17.9% (cv 21.8%) | **24.70** ±15.6% (cv 1.2%) | **6.03** ±20.2% (cv 9.3%) |
| lookup.miss | 1,024 | **13.93** ±36.2% (cv 25.8%) | **33.76** ±36.1% (cv 14.6%) | **6.24** ±10.9% (cv 55.2%) |
| iterate.sum | 1,024 | **0.07** ±13.9% (cv 31.4%) | **0.08** ±15.1% (cv 20.3%) | **0.75** ±9.1% (cv 4.6%) |
| insert.zero | 65,536 | **51.15** ±12.0% (cv 3.3%) | **63.74** ±11.0% (cv 20.2%) | **28.38** ±12.1% (cv 2.7%) |
| lookup.hit | 65,536 | **19.64** ±17.9% (cv 1.9%) | **35.88** ±171.6% (cv 80.7%) | **13.71** ±63.8% (cv 29.6%) |
| lookup.miss | 65,536 | **36.77** ±36.1% (cv 16.1%) | **42.91** ±10.3% (cv 3.9%) | **15.86** ±16.2% (cv 1.1%) |
| iterate.sum | 65,536 | **0.07** ±15.3% (cv 2.7%) | **0.07** ±13.7% (cv 3.5%) | **0.74** ±5.9% (cv 0.7%) |
| frontEvict.steady | 16 | **175.14** ±12.6% (cv 4.9%) | **193.97** ±18.3% (cv 4.9%) | **56.38** ±25.6% (cv 2.4%) |
| backEvict.steady | 16 | **96.73** ±28.8% (cv 16.3%) | **107.19** ±30.8% (cv 2.1%) | **37.48** ±37.0% (cv 4.2%) |
| frontEvict.steady | 256 | **498.38** ±12.8% (cv 0.9%) | **507.12** ±12.7% (cv 1.3%) | **63.54** ±20.5% (cv 9.9%) |
| backEvict.steady | 256 | **377.90** ±31.4% (cv 5.3%) | **403.16** ±29.0% (cv 2.8%) | **40.90** ±18.1% (cv 3.0%) |
| frontEvict.steady | 4,096 | **5,204.67** ±21.4% (cv 7.1%) | **5,048.34** ±14.1% (cv 0.7%) | **63.46** ±42.3% (cv 5.1%) |
| backEvict.steady | 4,096 | **6,178.35** ±36.6% (cv 4.5%) | **5,870.57** ±62.4% (cv 24.7%) | **42.11** ±46.3% (cv 20.9%) |
| frontEvict.steady | 65,536 | **141,044.92** ±10.6% (cv 13.2%) | **154,896.48** ±50.7% (cv 34.8%) | **65.51** ±0.2% (cv 1.7%) |
| backEvict.steady | 65,536 | **238,039.75** ±3.9% (cv 14.4%) | **236,280.13** ±12.9% (cv 15.1%) | **41.99** ±3.0% (cv 1.9%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **120.48** ±3.8% (cv 3.1%) | **116.69** ±3.8% (cv 7.1%) | **32.11** ±4.8% (cv 1.2%) |
| lookup.hit | 16 | **11.17** ±13.0% (cv 2.9%) | **27.50** ±6.2% (cv 3.6%) | **6.32** ±7.4% (cv 1.0%) |
| lookup.miss | 16 | **11.27** ±4.2% (cv 1.2%) | **15.20** ±20.0% (cv 1.6%) | **6.50** ±15.0% (cv 0.8%) |
| iterate.sum | 16 | **0.49** ±0.8% (cv 0.8%) | **0.58** ±2.1% (cv 1.4%) | **0.44** ±1.8% (cv 3.1%) |
| insert.zero | 1,024 | **60.24** ±11.0% (cv 2.8%) | **71.30** ±4.6% (cv 5.8%) | **20.38** ±5.7% (cv 38.6%) |
| lookup.hit | 1,024 | **14.20** ±13.1% (cv 1.8%) | **24.38** ±10.5% (cv 2.6%) | **7.26** ±1.0% (cv 1.2%) |
| lookup.miss | 1,024 | **12.96** ±6.4% (cv 4.6%) | **30.98** ±7.6% (cv 1.6%) | **6.85** ±5.0% (cv 3.5%) |
| iterate.sum | 1,024 | **0.17** ±1.2% (cv 3.9%) | **0.17** ±4.0% (cv 2.7%) | **0.71** ±3.0% (cv 2.0%) |
| insert.zero | 65,536 | **62.75** ±1.2% (cv 1.4%) | **68.90** ±1.2% (cv 0.8%) | **29.41** ±4.8% (cv 4.9%) |
| lookup.hit | 65,536 | **19.01** ±7.9% (cv 4.4%) | **34.79** ±5.0% (cv 3.6%) | **12.00** ±2.1% (cv 3.6%) |
| lookup.miss | 65,536 | **32.79** ±1.9% (cv 1.2%) | **39.62** ±1.0% (cv 1.6%) | **17.05** ±3.5% (cv 1.9%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.4%) | **0.17** ±0.0% (cv 1.4%) | **0.73** ±1.0% (cv 0.7%) |
| frontEvict.steady | 16 | **186.58** ±0.2% (cv 0.3%) | **197.90** ±1.6% (cv 0.5%) | **57.23** ±0.4% (cv 0.6%) |
| backEvict.steady | 16 | **105.22** ±1.8% (cv 1.0%) | **120.37** ±2.1% (cv 0.7%) | **40.45** ±5.5% (cv 1.0%) |
| frontEvict.steady | 256 | **523.65** ±2.3% (cv 0.8%) | **526.72** ±2.4% (cv 1.6%) | **64.43** ±1.1% (cv 2.3%) |
| backEvict.steady | 256 | **382.71** ±7.9% (cv 4.2%) | **406.83** ±10.7% (cv 3.0%) | **42.09** ±7.2% (cv 2.0%) |
| frontEvict.steady | 4,096 | **5,352.86** ±1.2% (cv 2.0%) | **5,346.15** ±1.6% (cv 1.5%) | **64.79** ±1.1% (cv 7.1%) |
| backEvict.steady | 4,096 | **5,585.55** ±9.6% (cv 3.5%) | **5,916.08** ±9.2% (cv 7.1%) | **42.25** ±2.7% (cv 1.0%) |
| frontEvict.steady | 65,536 | **157,851.56** ±21.3% (cv 9.5%) | **157,326.17** ±22.8% (cv 19.3%) | **67.76** ±2.3% (cv 1.1%) |
| backEvict.steady | 65,536 | **198,922.23** ±10.9% (cv 6.9%) | **187,134.26** ±21.9% (cv 8.4%) | **43.06** ±1.0% (cv 0.7%) |

The ring holds FLAT ~2.6 ns/op (bounded 2.9) across three decades of occupancy while
stdlib-as-queue's O(n) `removeFirst` curve runs 2.1 → 45.3 → 4,345 ns (ring wins ≥17× from
n=1k). The `Shared` column's ~7 ns mutation tax reappears unchanged (cycle cow ≈ 9.4–10.0 vs
direct 2.6) — the third family confirming B-1's cross-family invariance.

### Deque — W2 batch-1, bench beside tip `2ed1691` (commit `f7d4c46`)

| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| backBack.steady | 16 | **1.57** ±14.6% (cv 3.8%) | **12.40** ±14.2% (cv 3.3%) | **1.43** ±54.0% (cv 23.1%) |
| frontFront.steady | 16 | **4.08** ±9.3% (cv 3.0%) | **8.80** ±13.5% (cv 2.4%) | **4.15** ±56.8% (cv 31.8%) |
| rotate.steady | 16 | **2.60** ±6.3% (cv 2.6%) | **9.77** ±10.6% (cv 1.6%) | **2.33** ±29.5% (cv 6.6%) |
| backBack.steady | 1,024 | **1.55** ±9.2% (cv 3.8%) | **12.46** ±12.3% (cv 4.2%) | **1.95** ±55.1% (cv 9.9%) |
| frontFront.steady | 1,024 | **4.08** ±1.9% (cv 0.4%) | **8.80** ±8.6% (cv 1.8%) | **100.09** ±7.2% (cv 1.7%) |
| rotate.steady | 1,024 | **2.60** ±1.9% (cv 0.4%) | **9.30** ±8.5% (cv 1.8%) | **50.06** ±6.3% (cv 4.5%) |
| backBack.steady | 65,536 | **1.47** ±15.3% (cv 1.4%) | **12.67** ±7.7% (cv 2.1%) | **1.32** ±31.6% (cv 18.2%) |
| frontFront.steady | 65,536 | **4.16** ±18.9% (cv 10.2%) | **9.37** ±29.2% (cv 19.0%) | **9,056.64** ±251.5% (cv 30.4%) |
| rotate.steady | 65,536 | **2.78** ±57.8% (cv 34.8%) | **9.90** ±11.8% (cv 2.9%) | **4,815.11** ±4.5% (cv 0.2%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **102.31** ±61.9% (cv 11.6%) | **107.32** ±42.9% (cv 22.5%) | **28.48** ±25.3% (cv 7.2%) |
| lookup.hit | 16 | **11.47** ±69.6% (cv 17.4%) | **21.04** ±92.5% (cv 15.9%) | **5.51** ±72.8% (cv 28.6%) |
| lookup.miss | 16 | **12.50** ±30.3% (cv 8.9%) | **20.91** ±36.7% (cv 23.0%) | **5.69** ±29.0% (cv 2.8%) |
| iterate.sum | 16 | **0.40** ±24.9% (cv 1.0%) | **0.49** ±25.1% (cv 5.6%) | **0.45** ±15.1% (cv 15.7%) |
| insert.zero | 1,024 | **44.24** ±48.1% (cv 17.8%) | **62.12** ±20.1% (cv 8.5%) | **19.82** ±26.7% (cv 2.9%) |
| lookup.hit | 1,024 | **14.04** ±17.9% (cv 21.8%) | **24.70** ±15.6% (cv 1.2%) | **6.03** ±20.2% (cv 9.3%) |
| lookup.miss | 1,024 | **13.93** ±36.2% (cv 25.8%) | **33.76** ±36.1% (cv 14.6%) | **6.24** ±10.9% (cv 55.2%) |
| iterate.sum | 1,024 | **0.07** ±13.9% (cv 31.4%) | **0.08** ±15.1% (cv 20.3%) | **0.75** ±9.1% (cv 4.6%) |
| insert.zero | 65,536 | **51.15** ±12.0% (cv 3.3%) | **63.74** ±11.0% (cv 20.2%) | **28.38** ±12.1% (cv 2.7%) |
| lookup.hit | 65,536 | **19.64** ±17.9% (cv 1.9%) | **35.88** ±171.6% (cv 80.7%) | **13.71** ±63.8% (cv 29.6%) |
| lookup.miss | 65,536 | **36.77** ±36.1% (cv 16.1%) | **42.91** ±10.3% (cv 3.9%) | **15.86** ±16.2% (cv 1.1%) |
| iterate.sum | 65,536 | **0.07** ±15.3% (cv 2.7%) | **0.07** ±13.7% (cv 3.5%) | **0.74** ±5.9% (cv 0.7%) |
| frontEvict.steady | 16 | **175.14** ±12.6% (cv 4.9%) | **193.97** ±18.3% (cv 4.9%) | **56.38** ±25.6% (cv 2.4%) |
| backEvict.steady | 16 | **96.73** ±28.8% (cv 16.3%) | **107.19** ±30.8% (cv 2.1%) | **37.48** ±37.0% (cv 4.2%) |
| frontEvict.steady | 256 | **498.38** ±12.8% (cv 0.9%) | **507.12** ±12.7% (cv 1.3%) | **63.54** ±20.5% (cv 9.9%) |
| backEvict.steady | 256 | **377.90** ±31.4% (cv 5.3%) | **403.16** ±29.0% (cv 2.8%) | **40.90** ±18.1% (cv 3.0%) |
| frontEvict.steady | 4,096 | **5,204.67** ±21.4% (cv 7.1%) | **5,048.34** ±14.1% (cv 0.7%) | **63.46** ±42.3% (cv 5.1%) |
| backEvict.steady | 4,096 | **6,178.35** ±36.6% (cv 4.5%) | **5,870.57** ±62.4% (cv 24.7%) | **42.11** ±46.3% (cv 20.9%) |
| frontEvict.steady | 65,536 | **141,044.92** ±10.6% (cv 13.2%) | **154,896.48** ±50.7% (cv 34.8%) | **65.51** ±0.2% (cv 1.7%) |
| backEvict.steady | 65,536 | **238,039.75** ±3.9% (cv 14.4%) | **236,280.13** ±12.9% (cv 15.1%) | **41.99** ±3.0% (cv 1.9%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **120.48** ±3.8% (cv 3.1%) | **116.69** ±3.8% (cv 7.1%) | **32.11** ±4.8% (cv 1.2%) |
| lookup.hit | 16 | **11.17** ±13.0% (cv 2.9%) | **27.50** ±6.2% (cv 3.6%) | **6.32** ±7.4% (cv 1.0%) |
| lookup.miss | 16 | **11.27** ±4.2% (cv 1.2%) | **15.20** ±20.0% (cv 1.6%) | **6.50** ±15.0% (cv 0.8%) |
| iterate.sum | 16 | **0.49** ±0.8% (cv 0.8%) | **0.58** ±2.1% (cv 1.4%) | **0.44** ±1.8% (cv 3.1%) |
| insert.zero | 1,024 | **60.24** ±11.0% (cv 2.8%) | **71.30** ±4.6% (cv 5.8%) | **20.38** ±5.7% (cv 38.6%) |
| lookup.hit | 1,024 | **14.20** ±13.1% (cv 1.8%) | **24.38** ±10.5% (cv 2.6%) | **7.26** ±1.0% (cv 1.2%) |
| lookup.miss | 1,024 | **12.96** ±6.4% (cv 4.6%) | **30.98** ±7.6% (cv 1.6%) | **6.85** ±5.0% (cv 3.5%) |
| iterate.sum | 1,024 | **0.17** ±1.2% (cv 3.9%) | **0.17** ±4.0% (cv 2.7%) | **0.71** ±3.0% (cv 2.0%) |
| insert.zero | 65,536 | **62.75** ±1.2% (cv 1.4%) | **68.90** ±1.2% (cv 0.8%) | **29.41** ±4.8% (cv 4.9%) |
| lookup.hit | 65,536 | **19.01** ±7.9% (cv 4.4%) | **34.79** ±5.0% (cv 3.6%) | **12.00** ±2.1% (cv 3.6%) |
| lookup.miss | 65,536 | **32.79** ±1.9% (cv 1.2%) | **39.62** ±1.0% (cv 1.6%) | **17.05** ±3.5% (cv 1.9%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.4%) | **0.17** ±0.0% (cv 1.4%) | **0.73** ±1.0% (cv 0.7%) |
| frontEvict.steady | 16 | **186.58** ±0.2% (cv 0.3%) | **197.90** ±1.6% (cv 0.5%) | **57.23** ±0.4% (cv 0.6%) |
| backEvict.steady | 16 | **105.22** ±1.8% (cv 1.0%) | **120.37** ±2.1% (cv 0.7%) | **40.45** ±5.5% (cv 1.0%) |
| frontEvict.steady | 256 | **523.65** ±2.3% (cv 0.8%) | **526.72** ±2.4% (cv 1.6%) | **64.43** ±1.1% (cv 2.3%) |
| backEvict.steady | 256 | **382.71** ±7.9% (cv 4.2%) | **406.83** ±10.7% (cv 3.0%) | **42.09** ±7.2% (cv 2.0%) |
| frontEvict.steady | 4,096 | **5,352.86** ±1.2% (cv 2.0%) | **5,346.15** ±1.6% (cv 1.5%) | **64.79** ±1.1% (cv 7.1%) |
| backEvict.steady | 4,096 | **5,585.55** ±9.6% (cv 3.5%) | **5,916.08** ±9.2% (cv 7.1%) | **42.25** ±2.7% (cv 1.0%) |
| frontEvict.steady | 65,536 | **157,851.56** ±21.3% (cv 9.5%) | **157,326.17** ±22.8% (cv 19.3%) | **67.76** ±2.3% (cv 1.1%) |
| backEvict.steady | 65,536 | **198,922.23** ±10.9% (cv 6.9%) | **187,134.26** ±21.9% (cv 8.4%) | **43.06** ±1.0% (cv 0.7%) |

Both-ends parity with stdlib where stdlib is O(1) (`backBack` 1.5 vs 1.4–1.9 ns, sub-2 ns
rows carry B-5-class spreads), and the designed blowout where it is not: `frontFront` direct
4.1 ns flat vs stdlib 100 ns @1k / ~9.1 µs @64k; `rotate` 2.6–2.8 ns flat vs 50 ns / 4.8 µs.
The cow tax shows as ~+7–11 ns; deque's gate fires per push AND per pop.

### Stack — terminal wave, bench beside tip `f648181` (commit `f024ded`)

Recorded 2026-06-12 (terminal session; procs=0 at every bracket; in-window canary vs W1:
median Δ 1.8%, p90 6.2% — the arc's best conditions). The pre-reshape element-generic ADT (hand-rolled
CoW), measured as shipped — the before-picture for its eventual column respell:

| shape | n | tower.stack | stdlib |
|---|---|---|---|
| pushPop.cycle | 16 | **7.72** ±4.9% (cv 1.0%) | **1.94** ±53.2% (cv 19.8%) |
| build.zero | 16 | **23.22** ±2.5% (cv 0.8%) | **8.49** ±1.6% (cv 1.1%) |
| pushPop.cycle | 1,024 | **7.71** ±0.2% (cv 0.4%) | **1.95** ±52.0% (cv 15.0%) |
| build.zero | 1,024 | **9.38** ±0.3% (cv 0.8%) | **0.89** ±5.4% (cv 1.3%) |
| pushPop.cycle | 65,536 | **7.72** ±0.2% (cv 0.4%) | **1.95** ±0.5% (cv 0.5%) |
| build.zero | 65,536 | **8.87** ±0.8% (cv 0.6%) | **1.08** ±2.0% (cv 1.9%) |
| detach.firstMutation | 1,024 | **2,368.40** ±0.1% (cv 0.5%) | **155.03** ±6.9% (cv 10.4%) |
| detach.firstMutation | 65,536 | **142,660.80** ±0.4% (cv 0.5%) | **6,236.33** ±10.9% (cv 4.5%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **100.09** ±3.1% (cv 0.9%) | **101.95** ±3.9% (cv 0.9%) | **29.12** ±2.7% (cv 0.5%) |
| lookup.hit | 16 | **10.74** ±19.8% (cv 2.2%) | **18.66** ±9.7% (cv 0.8%) | **5.45** ±3.8% (cv 0.7%) |
| lookup.miss | 16 | **10.09** ±9.0% (cv 1.7%) | **20.42** ±1.5% (cv 1.3%) | **5.55** ±4.3% (cv 0.8%) |
| iterate.sum | 16 | **0.40** ±1.5% (cv 0.8%) | **0.49** ±0.4% (cv 1.6%) | **0.44** ±3.2% (cv 1.4%) |
| insert.zero | 1,024 | **42.52** ±5.4% (cv 0.8%) | **57.39** ±4.5% (cv 0.5%) | **19.67** ±2.5% (cv 0.6%) |
| lookup.hit | 1,024 | **13.46** ±5.3% (cv 1.7%) | **23.56** ±1.5% (cv 0.8%) | **5.78** ±4.8% (cv 0.6%) |
| lookup.miss | 1,024 | **14.04** ±4.1% (cv 0.7%) | **32.49** ±1.1% (cv 1.1%) | **5.95** ±6.6% (cv 0.4%) |
| iterate.sum | 1,024 | **0.07** ±0.0% (cv 2.8%) | **0.07** ±0.0% (cv 2.5%) | **0.71** ±1.4% (cv 1.1%) |
| insert.zero | 65,536 | **48.92** ±2.0% (cv 1.9%) | **62.21** ±3.0% (cv 0.7%) | **28.19** ±1.2% (cv 0.5%) |
| lookup.hit | 65,536 | **18.95** ±2.5% (cv 0.8%) | **28.94** ±2.2% (cv 1.5%) | **10.53** ±1.8% (cv 1.0%) |
| lookup.miss | 65,536 | **31.93** ±2.2% (cv 0.7%) | **41.54** ±1.4% (cv 0.6%) | **14.78** ±1.3% (cv 2.9%) |
| iterate.sum | 65,536 | **0.07** ±4.2% (cv 2.9%) | **0.07** ±4.2% (cv 0.4%) | **0.73** ±0.4% (cv 0.7%) |
| churn.steady | 16 | **174.68** ±0.1% (cv 0.6%) | **186.34** ±1.2% (cv 0.8%) | **55.50** ±1.5% (cv 1.3%) |
| churn.steady | 256 | **482.88** ±0.2% (cv 1.0%) | **493.98** ±1.1% (cv 0.6%) | **62.71** ±0.6% (cv 1.0%) |
| churn.steady | 4,096 | **4,947.23** ±1.3% (cv 0.7%) | **5,007.16** ±2.3% (cv 0.9%) | **63.64** ±2.5% (cv 1.0%) |
| churn.steady | 65,536 | **143,427.08** ±5.1% (cv 17.1%) | **143,393.23** ±7.5% (cv 22.0%) | **65.50** ±2.1% (cv 0.7%) |
| buildWipe.keep | 1,024 | **21.55** ±30.0% (cv 10.8%) | **32.60** ±3.8% (cv 2.0%) | **10.46** ±5.4% (cv 2.4%) |
| buildWipe.keep | 65,536 | **28.88** ±23.3% (cv 4.3%) | **35.60** ±1.6% (cv 0.3%) | **11.76** ±0.8% (cv 0.4%) |
| shape | n | tower.direct | tower.cow | stdlib |
|---|---|---|---|---|
| insert.zero | 16 | **119.04** ±4.0% (cv 0.5%) | **114.76** ±4.2% (cv 0.4%) | **34.06** ±3.7% (cv 0.6%) |
| lookup.hit | 16 | **11.16** ±11.8% (cv 0.5%) | **26.95** ±3.1% (cv 3.4%) | **6.06** ±6.2% (cv 0.8%) |
| lookup.miss | 16 | **11.13** ±6.8% (cv 1.0%) | **18.45** ±11.4% (cv 2.5%) | **6.13** ±8.4% (cv 1.2%) |
| iterate.sum | 16 | **0.49** ±0.4% (cv 0.4%) | **0.58** ±0.0% (cv 0.4%) | **0.44** ±0.0% (cv 1.2%) |
| insert.zero | 1,024 | **60.84** ±4.1% (cv 1.0%) | **66.17** ±2.5% (cv 0.9%) | **19.30** ±2.3% (cv 2.0%) |
| lookup.hit | 1,024 | **13.34** ±3.6% (cv 2.2%) | **22.97** ±4.0% (cv 0.8%) | **7.16** ±3.2% (cv 0.7%) |
| lookup.miss | 1,024 | **12.51** ±3.0% (cv 1.2%) | **31.00** ±3.2% (cv 1.3%) | **6.71** ±2.3% (cv 1.1%) |
| iterate.sum | 1,024 | **0.17** ±0.6% (cv 4.3%) | **0.17** ±0.0% (cv 1.9%) | **0.72** ±1.7% (cv 0.1%) |
| insert.zero | 65,536 | **62.79** ±6.8% (cv 1.0%) | **68.30** ±3.8% (cv 0.9%) | **28.88** ±1.3% (cv 0.3%) |
| lookup.hit | 65,536 | **19.52** ±0.2% (cv 1.4%) | **35.31** ±0.9% (cv 1.6%) | **11.83** ±1.2% (cv 1.5%) |
| lookup.miss | 65,536 | **32.74** ±0.8% (cv 1.0%) | **39.93** ±1.1% (cv 0.4%) | **15.06** ±0.6% (cv 4.3%) |
| iterate.sum | 65,536 | **0.17** ±0.0% (cv 1.6%) | **0.17** ±0.0% (cv 0.1%) | **0.73** ±0.3% (cv 1.1%) |
| churn.steady | 16 | **184.98** ±0.5% (cv 0.2%) | **196.65** ±1.7% (cv 0.3%) | **56.88** ±1.4% (cv 3.0%) |
| churn.steady | 256 | **502.85** ±1.3% (cv 0.4%) | **513.78** ±0.6% (cv 0.2%) | **63.87** ±0.6% (cv 1.1%) |
| churn.steady | 4,096 | **5,177.69** ±0.5% (cv 0.4%) | **5,172.85** ±0.7% (cv 0.4%) | **64.27** ±0.4% (cv 0.6%) |
| churn.steady | 65,536 | **118,640.62** ±3.8% (cv 14.9%) | **119,244.80** ±5.2% (cv 14.1%) | **67.58** ±1.8% (cv 0.5%) |
| buildWipe.keep | 1,024 | **35.89** ±4.8% (cv 1.4%) | **42.63** ±3.8% (cv 0.7%) | **10.63** ±2.4% (cv 0.7%) |
| buildWipe.keep | 65,536 | **40.11** ±8.0% (cv 2.0%) | **46.43** ±1.0% (cv 1.0%) | **12.28** ±0.4% (cv 0.4%) |
| shape | n | flat | ordered |
|---|---|---|---|
| insert.zero | 1,024 | 42.515 | 44.236 |
| lookup.hit | 1,024 | 13.463 | 14.037 |
| iterate.sum | 1,024 | 0.071 | 0.074 |
| iterate.sum | 65,536 | 0.072 | 0.072 |

pushPop holds **7.7 ns flat** across three decades vs stdlib's 1.95 (the ~6 ns
hand-rolled-CoW gate+box per op — the same structure B-1′ decomposes). Its detach runs
**2.18–2.31 ns/slot** — 1.8× the `Shared` combinator's 1.17–1.29 on identical payloads:
the hand-rolled copy is measurably worse than the column combinator it predates (a
respell datum). stdlib's sub-2 ns rows at n ≤ 1k carry the B-5 spread class.

### Arena (Storage.Generational, the substrate) — batch-2, bench beside tip `52537ef` (commit `b0ac26d`)

Recorded 2026-06-12 06:31–06:40, quiet-gated (60 s sustained-clear), procs=0 at EVERY
bracket; in-window array canary vs W1: median Δ 2.0% (p90 6.7%) — recording-grade
conditions throughout.

| shape | n | tower.direct |
|---|---|---|
| build.control | 256 | **1,843.36** ±0.4% (cv 2.3%) |
| growRelocate.curve | 256 | **5,033.06** ±1.9% (cv 1.1%) |
| build.control | 4,096 | **26,725.26** ±2.1% (cv 0.7%) |
| growRelocate.curve | 4,096 | **75,472.49** ±0.2% (cv 0.9%) |
| build.control | 65,536 | **412,164.06** ±0.8% (cv 0.4%) |
| growRelocate.curve | 65,536 | **1,162,213.56** ±0.2% (cv 0.5%) |
| contains.valid | 16 | **0.82** ±0.2% (cv 0.6%) |
| removeInsert.cycle | 16 | **5.20** ±0.7% (cv 0.3%) |
| iterate.full | 16 | **0.82** ±0.9% (cv 0.6%) |
| iterate.holes | 16 | **1.37** ±0.5% (cv 0.7%) |
| contains.valid | 1,024 | **0.81** ±0.8% (cv 0.7%) |
| removeInsert.cycle | 1,024 | **5.22** ±1.0% (cv 0.8%) |
| iterate.full | 1,024 | **0.81** ±1.1% (cv 1.0%) |
| iterate.holes | 1,024 | **1.35** ±0.7% (cv 0.7%) |
| contains.valid | 65,536 | **0.80** ±1.0% (cv 1.0%) |
| removeInsert.cycle | 65,536 | **5.25** ±0.6% (cv 0.2%) |
| iterate.full | 65,536 | **0.80** ±0.1% (cv 0.6%) |
| iterate.holes | 65,536 | **1.33** ±0.1% (cv 0.3%) |
| shape | n | tower.table | tower.indexed | stdlib |
|---|---|---|---|---|
| init.zero | 0 | **273.22** ±1.9% (cv 3.7%) | — | **0.00** ±0.0% (cv 89.5%) |
| init.sized | 16 | **261.14** ±2.2% (cv 0.4%) | — | **58.24** ±1.3% (cv 2.4%) |
| init.sized | 1,024 | **1,053.66** ±1.2% (cv 1.3%) | — | **62.13** ±2.5% (cv 1.1%) |
| init.sized | 65,536 | **54,665.36** ±9.4% (cv 9.1%) | — | **853.52** ±15.5% (cv 1.7%) |
| init.firstInsert | 1 | — | **503.73** ±3.5% (cv 2.2%) | **42.55** ±2.9% (cv 1.0%) |
| build.zero | 1,024 | — | **42.77** ±9.6% (cv 0.6%) | **19.70** ±2.9% (cv 0.6%) |
| build.reserved | 1,024 | — | **20.09** ±15.4% (cv 3.0%) | **9.22** ±3.2% (cv 0.4%) |
| build.zero | 4,096 | — | **47.24** ±5.1% (cv 0.6%) | **21.07** ±0.6% (cv 0.6%) |
| build.reserved | 4,096 | — | **22.32** ±6.0% (cv 2.2%) | **9.65** ±1.7% (cv 0.4%) |
| build.zero | 65,536 | — | **49.76** ±3.3% (cv 1.7%) | **28.11** ±0.6% (cv 0.4%) |
| build.reserved | 65,536 | — | **24.48** ±3.3% (cv 2.1%) | **10.69** ±1.0% (cv 0.4%) |
| n | build.control ns/op | growRelocate ns/op | delta ns | delta ns/slot |
|---|---|---|---|---|
| 256 | 1,843 | 5,033 | 3,190 | 12.46 |
| 4,096 | 26,725 | 75,472 | 48,747 | 11.90 |
| 65,536 | 412,164 | 1,162,214 | 750,050 | 11.44 |

**The grow door priced** (growRelocate − build.control per op):

| n | build.control ns/op | growRelocate ns/op | delta ns | delta ns/slot |
|---|---|---|---|---|
| 256 | 1,843 | 5,033 | 3,190 | 12.46 |
| 4,096 | 26,725 | 75,472 | 48,747 | 11.90 |
| 65,536 | 412,164 | 1,162,214 | 750,050 | 11.44 |

**11.4–12.5 ns per relocated slot, linear and stable** across 256 → 64k — the W5
`grow(to:)` door's cost curve, previously unmeasured. Substrate validation (`contains`)
is 0.81 ns flat; the slot-map wrapper adds 0.4 ns. `iterate.holes` (50% occupancy) costs
1.33 vs 0.80 ns full — **the `_occupied` hole-skip ≈ +0.53 ns per visited slot** (≈2× per
LIVE element at half-holes): the SoA re-cut's iterate-side number.

### Round M re-record — the fused-plane ledger (2026-06-12), arena tip `5f50bd0`

The [BENCH-011] dual-mode re-record after the B1 plane re-cut (the stdlib `[Int]`/`[Bool]`
ledger dissolved into ONE `Memory.Heap`-backed parity-token plane; span reads + four documented
pointer transitions — storage-arena `5f50bd0`, seat ruling R-12/R-13 on REPORT-round-m-W1/W2).

**Substrate (recording-grade: load bracketed 2.68→2.71, cross-run spread ≤3.2%, cv ≤2.1%,
4 invocations, clean `.build`):**

| shape | n | tower.direct (was → now) |
|---|---|---|
| growRelocate.curve | 65,536 | 1,162,214 → **823,293** (−29%) |
| build.control | 65,536 | 412,164 → **179,789** (−56%) |
| contains.valid | 1,024 | 0.81 → **0.80** |
| removeInsert.cycle | 1,024 | 5.22 → **3.86** (−26%) |
| iterate.full | 1,024 | 0.81 → **0.67** (−17%) |
| iterate.holes | 1,024 | 1.35 → **0.94** (−30%) |

**The grow door re-priced** (growRelocate − build.control, per slot — the criterion metric):

| n | was | now |
|---|---|---|
| 256 | 12.46 | **10.45** |
| 4,096 | 11.90 | **10.08** |
| 65,536 | 11.44 | **9.82** |

**−14% on the door @64k — the R-13 criterion (≤12.5 ns/slot) passes outright.** The
hole-skip is HALVED: holes − full = +0.53 → **+0.27 ns per visited slot**. Validation holds
0.80–0.81 flat (span reads pay bounds checks; the fused single-load read pays them back).

**Attribution (same-session worktree bisect, quiet window):** pre-R-5 `b0ac26d` re-measures
raw grow @64k at 17.97 ns/slot vs its recorded 17.73 — 1.4% cross-session replication (the
calibration anchor); R-5's two-pass release restructure costs +2.3% raw (17.97 → 18.38); the
plane re-cut takes it to 12.56 raw (−32% vs R-5). Method note of record: the door price is
the DELTA metric above — raw `growRelocate/n` is NOT comparable to it (a Round-M W2 confusion,
caught and corrected at this re-record).

**Family tier (slot-map wrapper, corroboration-grade: 12 invocations across a mixed-load
evening window; stdlib anchors replicate — `stdlib.array` access.valid 0.29–0.31 vs recorded
0.29–0.34, `stdlib.dictionary` cycle 18.98–21.56 vs recorded 19.60–20.96):**

| shape @1,024 | recorded | now (median-of-12) |
|---|---|---|
| access.valid (direct) | 1.21 | **0.82** (−32%; the +0.4 wrapper tax over substrate-contains collapsed) |
| access.valid (cow) | 3.75 | **1.37** (−64%) |
| access.stale | 0.82 | **0.82** (parity — one-load fail-fast both shapes) |
| removeInsert.cycle (direct) | 5.15 | **3.91** (−24%) |
| removeInsert.cycle (cow) | 10.81 | **5.68** (−47%) |
| iterate.full | 0.81 | **0.68** (−15%) |
| iterate.holes | 1.33 | **0.95** (−29%) |
| build.reserved | 6.51 | **2.78** (−57%) |

The arena rows above this addendum (tip `52537ef`) remain the PRE-plane record; this section
is the post-plane baseline of record for the substrate. Full run data: REPORT-round-m-W2/W3
(.handoffs).

## Banked candidates (arc-5 gate inputs; MEASURE-ONLY discipline)

| # | Observation | Family / site | Why banked (not chased) |
|---|---|---|---|
| B-1 | **`Shared` per-mutation tax ≈ 7.3–7.6 ns/op, ~1.7× the R4 synthetic bound (4.3 ns) and ~7× stdlib's own per-write check (1.1 ns)** — flat across n (set.indexed cow 7.85–8.39 vs direct 0.30; append.reserved cow 8.05 vs direct 0.79). The real path = gate + box hop + cross-module `_modify` chain, not the bare `isKnownUniquelyReferenced` R4 isolated. | shared / `Shared` mutation path; consumer side `Array ~Copyable.swift:94` `_modify` → `store.prepareForMutation()` | Optimization is out of this arc's scope; candidates: inlining audit of the gate chain, hoisting the box-pointer load. Quantify through set/dict/queue rows in W2 first — if ~7 ns is invariant across families it is one shared fix, not seven. |
| B-2 | **`Shared` detach copies element-wise (~1.24 ns/slot); the direct column's `clone()` is memcpy-class (~0.16 ns/slot); stdlib detach ~0.11 ns/slot** — detach @64k = 81.4 µs vs direct clone 10.6 µs (7.7×) vs stdlib 7.4 µs (11×), identical `Int` payload. The detach path lacks a trivial-element bulk-copy fast path. | shared / detach (`prepareForMutation` slow path) vs buffer-linear `clone()` | The single largest measured asymmetry; an arc-5-class change inside `Shared`. [BENCH-011]: any fix proposal needs the dual-mode probe (isolated + a consumer walking detach-heavy workloads). |
| B-3 | **Direct-column growth ops trail stdlib at small/mid scales**: append.reserved 1.8× @1k (0.79 vs 0.44), append.zero 2.7× @1k, pop ≈ 4× (derived 1.42 vs 0.35 @1k) — but CROSSOVER at 64k where direct append.reserved beats stdlib 0.77× (0.61 vs 0.79). | array / seam append–removeLast path (`Array+Columns.swift:36`, `Array ~Copyable.swift:146`) | Family-round material, not arc-5; per-op accounting through the seam (count/capacity Tagged arithmetic, no `reserveCapacity` exponential-hint divergence chased). The 64k win suggests the gap is fixed-overhead, not algorithmic. |
| B-4 | **Tiny-array build cost**: append.zero @16 ≈ 24.7 ns/op tower vs 8.6 stdlib — first-allocation policy difference dominates (stdlib's empty singleton + first-growth heuristics vs the column's immediate allocate). | array+buffer-linear / zero-capacity init + first growth | Ergonomics/policy datum for the family round; n=16 rows are init+teardown-dominated by design (documented). |
| B-5 | **Harness lesson — sub-0.1 ns/op bulk shapes need ≥16M-op batches AND still carry 25–30% spread at mid-n** (`set.span` @1k); at 64k the larger target stabilized them to ≤7.5%. | bench harness (`spanOpsTarget`) | W2 families should put bulk-span rows at large n or report them qualitative-only at mid n. |
| B-6 | (strength, not defect) **Payload detach inversion**: `Shared` detach 1.66× faster than stdlib for class elements @1k. | shared / detach retain loop | Record only — corroborates that B-2 is about the trivial-element fast path specifically, not copy machinery generally. |
| B-7 | **Every `Hash.Indexed` remove is Θ(bucketCapacity)**: `decrement(after:)` sweeps the ENTIRE bucket table unconditionally (`Hash.Table+PositionUpdates.swift:45–57`, called from `Hash.Indexed+Engine.swift:110`) — the documented O(n−rank) dense shift is the cheaper half. Quantified (hash-table pin `2eae321`): evict pairs at n=64k cost 141–238 µs vs stdlib's flat 42–68 ns (≈3,000–5,600×); the curve is super-linear through {16, 256, 4k, 64k} in BOTH ordered families. **Anomaly facet**: at n ≥ 4k, back-eviction (zero shift, zero fixups, read-only sweep) costs MORE than front-eviction (dict @64k: 199 µs vs 158 µs, spreads ≤ ~11%) — inverted vs any sweep-only model; unexplained. | hash-table / `Hash.Table+PositionUpdates.swift:45` + `Hash.Indexed+Engine.swift:110` (both ordered families ride it) | The arc's largest find; an arc-5-class fix inside arc-2's package (last-rank fast path · early-exit · rank→bucket back-pointers · epoch-offset). [BENCH-011] dual-mode gates any fix; the inversion facet needs its own minimal probe first. **PROBE VERDICT (06-12, seat-authorized /tmp probe, read-only)**: the inversion reproduces at the ENGINE level (Hash.Indexed direct, no family wrapper) and is KEY-PATTERN-INDEPENDENT — a bijective key shuffle preserves back/front at 1.15× (64k) and 1.24× (4k) exactly; key-clustering and wrapper effects are ELIMINATED. Remaining suspects are inside the remove path's sweep/insert interaction; the B-7 fix shapes (skip-sweep fast path) would moot the back case regardless. Probe log: `arc-bench-W2-logs/b7-inversion-probe.log`. **RESOLVED (2026-06-12, engine-fix W2, seat-ruled V3 — hash-table `d20c635`+`ff1e012`+`6b0fc58`)**: a rank→bucket back-pointer plane restores the documented O(n−rank) — re-recorded evict pairs (engine bench, same harness): back @64k 236 µs → **87 ns** (flat at every size), random 431 → 43.6 µs, front 147 → 93 µs (the inherent dense shift); maintenance side: build.reserved @64k +0.4% (noise), build.zero +5.9%, init.sized ≈2× (the plane's own O(capacity) zero-fill, bulk-door respelled after a 7× per-element-append regression was caught at the gate). **The inversion is EXPLAINED-AND-MOOTED** (spike `REPORT-engine-fix-W1` §3): work-accounting puts back and front within ≤2 probe steps outside the sweep while front does 65,535 MORE writes — the asymmetry is load-coupled scan micro-structure INSIDE the Θ(cap) sweep (never-taken compare chain vs taken-branch+warm-line stores; the low-load control at α≈0.125 FLIPS the sign), amplified by the real engine's per-bucket machinery. Every fix shape erases the back case; V3 erases the sweep itself. **Banked for arc-5 (SoA round)**: the plane is +8 B/BUCKET (≈11.4 B/live entry at 70% load) as a separate Linear buffer beside the Split slots — a third-plane fuse candidate when the SoA re-cut runs. B-8 rides the same tip: span-first probe loops (hash-plane base hoisted once per walk; the Shared read-tax mechanism isolated at Δ27–28 ns in the spike model); the family-level cow-vs-direct re-record stays with arc-3's set/dict bench legs. |
| B-8 | **Ordered-family READS through `Shared` pay ~+10–16 ns/lookup** (dict lookup.hit: cow 24.4–34.8 vs direct 11.2–19.0; set mirrors) — array's read rows showed cow≈direct parity, so the tax is NOT the box hop itself but how `Hash.Indexed`'s probe loop re-enters the box per access instead of borrowing the dense span once. | set-ordered/dict-ordered contains/withValue paths over `Shared<…, Hash.Indexed<…>>` | Family-round candidate (span-first probe loop); cheap relative to B-7 but on every keyed read. |
| B-9 | **Per-instance hash seeding + O(capacity) init fill**: Hash.Table init costs 273 ns (seed syscall) where stdlib's empty Set is free, and sized init pays ~0.83 ns/bucket (54.7 µs at 64k) where stdlib defers. Steady inserts ≈2.2× stdlib. | hash-table / `Hash.Table.swift:124` (`makeSeed`), init's `buffer.fill` | Engine-round candidates: lazy seeding (seed at first insert), lazy/incremental bucket fill. The per-instance seed is a deliberate hardening choice — the COST of the choice is now on record (it buys per-instance probe-sequence diversity). |
| B-10 | **Counted-loop per-rep arena create traps "pool exhausted" under -O** while the IDENTICAL straight-line sequence succeeds (bisect: exact-fill 4 ✓, 256 ✓, fill-200 ✓, then the first in-loop rep traps). Sidestepped in the benches by making the per-rep capacity loop-variant (`n &+ (r & 1)`). | bench-side observation against arena `52537ef`; suspicion class: R-6-adjacent (-O move-only lifecycle mishandling, cf. swiftlang#89832) | NO wall-claim — mechanism unproven; minimal repro is a candidate /issue-investigation (institute Issues only, per standing policy). The bisect evidence + workaround are preserved in the W4 report. |
| B-1′ | (evidence update for B-1) The ~7–9 ns `Shared` per-mutation tax is **cross-family invariant**: array set.indexed Δ≈7.5, queue cycle Δ≈6.8–7.4, deque pairs Δ≈+7–11, ordered insert Δ≈+5–11. One shared fix, not N family fixes. | shared / mutation gate chain | Strengthens B-1's "quantify across families first" disposition — done; the fix is singular. |

## Arc-5 gate inputs (W3 — called out explicitly; quantification rows = batch-2)

1. **Generational SoA re-cut.** Current layout: `_generations: [Int]` and `_occupied:
   [Bool]` are stdlib Arrays inside the tower's own storage tier
   (`Storage.Generational.swift:36–48` — the self-hosting debt, weakness-sweep §2 #5).
   The cost question arc-5 must answer empirically: per validated access, the slot-map
   pays TWO independent stdlib-Array paths (refcount-stable but bounds-checked, separately
   allocated, separately cached) vs a fused SoA block's one. Quantification rows (batch-2,
   slot-map + arena grants): handle-validation ns/access · insert/remove (occupancy
   writes) · iterate-occupied · arena `grow(to:)` relocation vs capacity. **QUANTIFIED at
   batch-2 (06-12)**: validation 0.81 ns flat (substrate) / 1.21 ns (wrapper) vs 0.30 ns raw
   array — the two-stdlib-Array ledger costs ≈ 0.9 ns/access all-in; hole-skip iterate
   +0.53 ns/visited slot at 50% occupancy; grow(to: 2n) relocation 11.4–12.5 ns/slot,
   linear 256→64k. The arc-5 SoA re-cut's win is bounded by these sub-ns/access and
   ~12 ns/slot-relocate terms.
2. **Tree.Position re-cut.** The ~16 B/slot position side-table is already explicit in the
   read-only seed: trees' `Performance Tests.swift:413–422` accounts bytes/slot = node
   stride + 9 B column ledger (8 generation + 1 occupancy) + 16 B
   `Store.Generational.Handle?` side table. The BYTE cost is settled by the seed; the
   ACCESS cost rides the same batch-2 slot-map/arena rows. Trees stay out of this arc's
   edit scope.
3. **Sequencing input from W2**: B-7 (the Θ(capacity) `Hash.Indexed` remove + its
   back>front inversion) dominates any SoA-layout effect by 3–4 orders of magnitude in the
   ordered families. If arc-5 budgets one structural change first, B-7 is it; the SoA
   re-cut's win is bounded by ns-scale per-access effects.

## Residual at W3 (grant-blocked rows; the only outstanding inventory items)

| Family | Inventory measures pending | Blocking grant |
|---|---|---|
**NONE — the inventory is COMPLETE.** All ten family surfaces measured: array (W1) ·
queue, deque, set-ordered, dictionary-ordered (W2 batch-1) · slot-map, arena
(Storage.Generational), hash-table engine (batch-2) · shared (gate decomposition), stack,
set, dictionary (terminal wave). Hash-table ownership has passed to the engine-fix
executor; this document's engine rows stand as the before-picture.

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
