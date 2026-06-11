# Tower Family-Tier Benchmark Baselines

<!--
---
version: 0.3.0
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

| Run conditions (W2 batch-1) | Recorded 23:11–23:22 after a 60s-clear sustained-quiet gate; EVERY per-run bracket read procs=0 (the only fully-clean session of the arc). Caveat: the window followed a 33-process build storm on the fanless machine — thermal drain is visible as a quality gradient across the session (set-ordered first/hottest: 55/60 cases >10% cross-run spread; dictionary-ordered last/coolest: 11/60). The array drift-canary in this window read median Δ 10.8% vs W1 (p90 19%) — ABOVE W1's stated spreads; the cooler 22:40 opportunistic canary read 3.0%, so the excess is attributed to thermal state, not drift. Within-session family comparisons are unaffected; cross-referencing W2 absolute numbers against W1's carries the ~10% caveat. W3 cool-window re-confirmation (23:27, procs=0, 20 min idle): **median Δ 1.9%, p90 5.6%, 2/74 cases >10%** — thermal attribution CONFIRMED (hot 10.8% → cooler 3.0% → cool 1.9%); no drift. |

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

### Set / Dictionary — HELD (batch-2; arc-2 owns the packages through their W3)

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

### Hash engine — W2

PENDING (per-instance seed cost: init + first-insert latency; grow/re-seed cost spike).

### Slot-map — W2

PENDING (handle-validation overhead per access; insert/remove/iterate vs array baseline).

### Shared — W2

PENDING (detach cost vs in-place mutation; gate overhead on the hot read/write path — R4
methodology, measured through the real box rather than a synthetic one).

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
| B-7 | **Every `Hash.Indexed` remove is Θ(bucketCapacity)**: `decrement(after:)` sweeps the ENTIRE bucket table unconditionally (`Hash.Table+PositionUpdates.swift:45–57`, called from `Hash.Indexed+Engine.swift:110`) — the documented O(n−rank) dense shift is the cheaper half. Quantified (hash-table pin `2eae321`): evict pairs at n=64k cost 141–238 µs vs stdlib's flat 42–68 ns (≈3,000–5,600×); the curve is super-linear through {16, 256, 4k, 64k} in BOTH ordered families. **Anomaly facet**: at n ≥ 4k, back-eviction (zero shift, zero fixups, read-only sweep) costs MORE than front-eviction (dict @64k: 199 µs vs 158 µs, spreads ≤ ~11%) — inverted vs any sweep-only model; unexplained. | hash-table / `Hash.Table+PositionUpdates.swift:45` + `Hash.Indexed+Engine.swift:110` (both ordered families ride it) | The arc's largest find; an arc-5-class fix inside arc-2's package (last-rank fast path · early-exit · rank→bucket back-pointers · epoch-offset). [BENCH-011] dual-mode gates any fix; the inversion facet needs its own minimal probe first. |
| B-8 | **Ordered-family READS through `Shared` pay ~+10–16 ns/lookup** (dict lookup.hit: cow 24.4–34.8 vs direct 11.2–19.0; set mirrors) — array's read rows showed cow≈direct parity, so the tax is NOT the box hop itself but how `Hash.Indexed`'s probe loop re-enters the box per access instead of borrowing the dense span once. | set-ordered/dict-ordered contains/withValue paths over `Shared<…, Hash.Indexed<…>>` | Family-round candidate (span-first probe loop); cheap relative to B-7 but on every keyed read. |
| B-1′ | (evidence update for B-1) The ~7–9 ns `Shared` per-mutation tax is **cross-family invariant**: array set.indexed Δ≈7.5, queue cycle Δ≈6.8–7.4, deque pairs Δ≈+7–11, ordered insert Δ≈+5–11. One shared fix, not N family fixes. | shared / mutation gate chain | Strengthens B-1's "quantify across families first" disposition — done; the fix is singular. |

## Arc-5 gate inputs (W3 — called out explicitly; quantification rows = batch-2)

1. **Generational SoA re-cut.** Current layout: `_generations: [Int]` and `_occupied:
   [Bool]` are stdlib Arrays inside the tower's own storage tier
   (`Storage.Generational.swift:36–48` — the self-hosting debt, weakness-sweep §2 #5).
   The cost question arc-5 must answer empirically: per validated access, the slot-map
   pays TWO independent stdlib-Array paths (refcount-stable but bounds-checked, separately
   allocated, separately cached) vs a fused SoA block's one. Quantification rows (batch-2,
   slot-map + arena grants): handle-validation ns/access · insert/remove (occupancy
   writes) · iterate-occupied · arena `grow(to:)` relocation vs capacity. Until then this
   input is STRUCTURAL, not yet a number.
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
| set / dict (flat) | insert / lookup-hit / lookup-miss / remove / iterate vs stdlib | arc-2 owns through their W3 |
| hash-table (engine) | per-instance seed cost (init + first-insert), grow/re-seed spike | arc-2 (their W1 package; tip moved to `2eae321` mid-W2) |
| slot-map | handle-validation per access; insert/remove/iterate vs array | arc-2 W2 |
| arena | `grow(to:)` relocation vs capacity | arc-2 W2 |
| shared | detach vs in-place; gate overhead isolated (R4 methodology through the real box) | arc-1 (tip moved to `827b2f0`) |
| stack | push/pop vs stdlib | seat re-grant after the Sendable fix (was `7e4200a` → `1359c17` → moving) |

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
