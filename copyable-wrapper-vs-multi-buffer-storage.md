# Copyable Wrapper vs Multi-Buffer Storage

<!--
---
version: 1.0.1
last_updated: 2026-05-13
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
changelog:
  - 1.0.0 (2026-05-13): initial extraction of the cross-cutting structural
    finding from the just-closed swift-json v2 arc
    (`swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0
    SUPERSEDED-BY-EVIDENCE §12). No new measurements; cites the existing
    empirical record from the v2 arc's `parse-performance-bench` harness.
  - 1.0.1 (2026-05-13): three softenings after first-reader review.
    (a) §3.2 "order of magnitude" overstatement scoped explicitly to the
    swift-json reference case rather than asserted as a general factor —
    consistent with the loose-end footnote's existing premise classification.
    (b) §3.3 N ≥ 30-50 break-even relabelled as a back-of-envelope projection
    from §12's structural diagnosis, with an explicit "NOT empirically
    located" tag — the integrated bench never measured at N > 2 (the
    workload mean).
    (c) §4 Option B clarified as a STRUCTURAL PREDICTION ONLY — the v2 L1-1
    prototype tested the conditional-Copyable instantiation of
    `Dictionary.Ordered` (the L1 path), NOT the unconditional ~Copyable
    wrapper that Option B describes (the L2 path). Option B's integrated
    cost is unobserved.
    (d) §5 [BENCH-NNN] rule text amended to scope the "order of magnitude"
    claim to the reference case.
    No structural finding changes; the refcount-per-copy dominance + the
    integration-probe methodological lesson stand.
---
-->

## Context

The just-closed swift-json v2 arc
(`swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0,
status SUPERSEDED-BY-EVIDENCE) attempted to replace the
`RFC_8259.Object`-backing `[(String, Value)]` array with a hash-backed
ecosystem primitive (`Dictionary<String, Value>.Ordered` from
`swift-dictionary-primitives`). The L1-1 prototype was implemented,
177/177 tests passed, and the measurement gate at L1-2 fired with a
catastrophic regression — parse +339% and lookup +226% at the canonical
workload. Per the v2 arc's §12 close-out, the root cause was diagnosed
as **refcount-per-Object-copy on `case .object(let o) = raw` extract,
multiplied by the storage shape's refcount count** (1 for `Array`, 2
for `Swift.Dictionary + [String]`, 3-4 for
`Set<Key>.Ordered + Buffer<Value>.Linear + Hash.Table<Key>`).

The structural finding generalises beyond swift-json. Any institute
consumer that (a) declares a Copyable value-wrapper struct, (b) backs
it with a multi-buffer hash storage primitive, and (c) reads through a
pattern-match extract or `subscript`-through-the-wrapper indirection
pays the same compound cost. The v2 arc closed against this shape;
without an ecosystem-wide framing, the next consumer that reaches for
the same composition will repeat the same prototype-rollback cycle.

This document extracts the principle as a standalone Tier-2 research
note. No new measurements — the v2 arc's
`parse-performance-bench` harness already contains the empirical
record. The value here is the cross-cutting framing.

## Question

When should an institute consumer reach for a multi-buffer hash
storage primitive (`Dictionary.Ordered`, `Dictionary` (slab),
`Set.Ordered`) instead of a single-array linear storage, given that
the wrapper enclosing that storage is Copyable and reads pass through
a pattern-match extract?

Equivalently: under what conditions does the algorithmic O(1) win of
hash storage actually dominate the refcount-per-copy overhead added by
the multi-buffer shape?

## Analysis

### 1. Prior art — what the institute corpus already established

Per [RES-019] / [HANDOFF-013], grepped the
`swift-institute/Research/` corpus for tree-shape, storage-variant,
refcount, and Copyable-wrapper prior art. Cited; not duplicated:

| Source | What it establishes | Relation to this note |
|---|---|---|
| `swift-institute/Research/ecosystem-data-structures-inventory.md` v1.0.0 (DECISION) | Catalog of ecosystem data structures; documents that base / `.Bounded` / `.Fixed` variants become Copyable when `Element: Copyable` (heap-backed CoW), while `.Static<N>` and `.Small<N>` are unconditionally `~Copyable` because `@_rawLayout` prevents conditional Copyable. Names `Dictionary.Ordered` as `Set.Ordered (keys) + Buffer.Linear (values)`; names `Dictionary` (unordered) as `Buffer.Slab + Hash.Table`. | The catalog from which both storage shapes (and their refcount cost) derive. |
| `swift-institute/Research/comparative-dictionary-primitives.md` v1.0.0 (RECOMMENDATION) | Variant catalog for `Dictionary` (slab-backed, O(1) remove), `Dictionary.Ordered` (linear+hash, O(1) lookup, insertion-order preserved), `.Bounded`, `.Static<N>`, `.Small<N>`; conditional-conformance table. | Primary catalog for the Copyable vs ~Copyable storage axis discussed below. |
| `swift-institute/Research/storage-primitives-comparative-analysis.md` v1.1.0 (RECOMMENDATION, Tier 3) | Establishes that `swift-storage-primitives` occupies a novel position combining typed coordinates + automatic tracking + ~Copyable + layered integration; documents the heap/inline separation and ManagedBuffer-based heap storage that underlies every multi-buffer primitive. | Names the substrate; this note adds the integrated-cost finding the substrate analysis did not measure. |
| `swift-institute/Research/property-view-for-cow-copyable-types.md` v2.0.0 (DECISION) | `Property<Tag, Base>` for Copyable types vs `Property<Tag, Base>.View` for ~Copyable types; the CoW Mutation Recipe's `self = _transferDummy` pattern keeps refcount = 1 during `_modify` yields. Reports cost ~4 ARC operations per nesting level (~4 ns on modern hardware). | First institute treatment of the refcount-cost-per-extract axis. The current note generalises from "Copyable wrapper around a single refcount" (Property/CoW) to "Copyable wrapper around N refcounts" (multi-buffer storage). |
| `swift-institute/Research/buffer-arena-conditional-copyable.md` v1.1.0 (RECOMMENDATION) | `Buffer.Arena` is unconditionally `~Copyable`; Option A (Storage.Arena ManagedBuffer subclass) recommended but not implemented as of 2026-05-13. | Names the structural reason multi-buffer primitives lean `~Copyable`: arena-allocated nodes force the cascade. The current note documents the integrated cost of NOT doing the cascade at the consumer. |
| `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0 (SUPERSEDED-BY-EVIDENCE) §12 | The L1-1 prototype's measured outcomes + structural diagnosis. Lists all four diagnostic modes (`crossover`, `synthetic-lookup`, `size-dist`, `lookup`) in the bench harness. | **Primary empirical source.** Not duplicated here; cited section-by-section in §3 below. |
| `swift-foundations/swift-json/Research/parse-performance.md` v1.2.0 (DECISION) | Tiers 0/1/3/4 closed parse-side wedges; swift-json reaches parse parity with Foundation and 14× lookup advantage. | Establishes the baseline against which L1-1's regression was measured. |
| `swift-foundations/swift-json/Research/parse-performance-architecture.md` v1.0.2 (DECISION) | Span-specialized internal lexer / parser inside `swift-rfc-8259`; Phase B (arena tree) NOT triggered under the parse-only framing. | Establishes the parse-side architecture the v2 arc was attempting to build on. |

Per [RES-021] contextualization step: among comparable cross-language
analogues — Rust's `HashMap<K, V>` is move-by-default (the wrapper is
moved on extract, not copied, so the refcount-per-copy cost simply
does not arise); C++'s `std::unordered_map` is copy-by-default but
exposes move semantics, with `std::move` adoption the canonical
remediation; Haskell's `Data.HashMap.Strict` is GHC-RTS-managed with
no per-extract refcount cost. Swift's Copyable-by-default value-type
discipline is the structural reason the finding manifests here and
not, mutatis mutandis, elsewhere. **Universal absence of the pattern
in surveyed analogues is therefore not evidence of universal absence
of the problem — it is evidence that Swift's specific Copyable +
multi-buffer composition is the failure mode under examination.**

### 2. The structural cost model

A Copyable value-wrapper struct enclosing a storage primitive incurs
**one refcount increment per heap-backed component on every copy of
the wrapper**. The cost compounds with the number of distinct
heap-backed components in the storage shape:

| Storage shape | Heap-backed components | Refcounts per wrapper copy |
|---|---|---|
| Single-array `[Element]` (Swift stdlib Array) | 1 (one ManagedBuffer) | 1 |
| `Swift.Dictionary<K, V>` + `[K]` side-order-array | 2 (one ManagedBuffer for the dict, one for the side array) | 2 |
| `Set<K>.Ordered + Buffer<V>.Linear + Hash.Table<K>` (the `Dictionary.Ordered` shape per `ecosystem-data-structures-inventory.md` §Dictionary) | 3-4 (depends on whether `Set.Ordered`'s internal `Buffer.Linear + Hash.Table` is one or two ManagedBuffers in the current implementation) | 3-4 |

A wrapper copy occurs at every:

- Pattern-match extract — `case .object(let o) = raw` binds `o` by
  copy when `Value` is Copyable.
- Subscript-through-wrapper getter — `wrapper[key]` calls the
  wrapper's `subscript` getter, which extracts the storage by copy
  before delegating.
- Stored-property access on a Copyable enclosing struct — every
  read of the property copies.
- Function-argument pass when the parameter is not annotated
  `borrowing` / `consuming`.

The compound cost at a hot path traversing N wrappers with K
heap-backed components each is **N × K refcount operations**, where
each refcount operation costs ~3-10 ns on modern hardware (per the
ARC microbenchmark literature). For traversals where N is large and
K > 1, this term dominates.

### 3. The empirical record from the swift-json v2 arc

The bench harness at
`swift-foundations/swift-json/Experiments/parse-performance-bench/`
captured the integrated cost in two layers. Per [RES-023], the
following are empirical claims with file-line provenance against
the v2 arc's research doc; verified at write time 2026-05-13.

#### 3.1 The L1-1 prototype's measured outcomes (integrated)

Per `value-tree-redesign-v2.md` §12 "Measured outcomes (L1-1
prototype)" (lines 696-710), 86 MB `Swift.symbols.json`, release,
macOS 26 arm64, 3-iter parse + 50-iter lookup:

| Path | Baseline (Array-linear) | L1 prototype (Dict.Ordered) | Δ |
|---|---:|---:|---:|
| swift-json `JSON.parse([UInt8])` (per iter) | 0.304 s | 1.333 s | **+339%** |
| swift-json `JSON.parse(String)` (per iter) | 0.316 s | 1.369 s | **+333%** |
| swift-json lookup pass (per iter) | 3.16 ms | 10.3 ms | **+226%** |
| Foundation parse (per iter) | 0.299 s | 0.301 s | — |
| Foundation lookup pass (per iter) | 46 ms | 46 ms | — |

Per §12 "Two rescue interventions explored" (lines 712-729): a
diagnostic `Swift.Dictionary + [String]` swap (drops some semantics
but isolates the storage-primitive-choice axis) cut the regression
roughly in half — parse 0.553 s (+82% vs baseline) and lookup 8.2 ms
(+159% vs baseline) — but **still regressed materially**. The
wrapper-indirection cost is dominant; storage-primitive choice is a
2× factor on top.

#### 3.2 The L1-0 isolated storage micro-bench (overstated)

Per `value-tree-redesign-v2.md` §11 "Storage micro-bench
(`crossover` mode)" (lines 838-867), raw lookup cost in ns, 10 000
random-hit lookups per object size:

| N | array(curr) | Swift.Dictionary | Dict.Ordered | array ÷ Dict.Ordered |
|--:|------------:|-----------------:|-------------:|---------------------:|
| 1 | 69 ns | 13 ns | 18 ns | 3.78× |
| 2 | 112 ns | 15 ns | 19 ns | 5.87× |
| 4 | 170 ns | 17 ns | 17 ns | 9.67× |
| 8 | 264 ns | 14 ns | 19 ns | 13.62× |
| 32 | 848 ns | 22 ns | 30 ns | 27.56× |
| 256 | 5 265 ns | 20 ns | 27 ns | 192.19× |

The isolated bench showed `Dict.Ordered` beating linear at every N,
including N=1. **The integrated path through `JSON.subscript →
RFC_8259.Value.object → Object[key] → Dict.Ordered.subscript →
Set.Ordered.index → Hash.Table.position → Buffer.Linear[Index<Value>]`
moved the result from +9.67× win at N=4 (isolated) to +226% loss at
N=2.06 mean (integrated).** In this specific consumer-shape ×
storage-shape pair, the integration overstatement is roughly an order
of magnitude. Whether the factor generalises across other consumer
shapes is unverified — see Outcome §"Loose ends" for the explicit
premise classification.

Per §12 "Why the storage micro misled" (lines 751-773), the four
factors the micro did not capture:

1. The refcount cost of `Object` copy along the hot path.
2. The cost of `case .object(let o)` enum extract.
3. The `JSON` wrapper layer's `subscript(_:String)` flow.
4. Cache-cold access during real traversal.

#### 3.3 The canonical workload's N distribution

Per `value-tree-redesign-v2.md` §11 "Object-size distribution on the
canonical workload" (lines 815-836), `size-dist` over
`Swift.symbols.json` (922 531 objects total):

| Keys/object | % | Cumulative % |
|--:|--:|-----:|
| 1 | 21.45% | 21.47% |
| 2 | 63.36% | 84.83% |
| 3 | 10.81% | 95.64% |
| 4 | 2.77% | 98.41% |
| Mean: 2.06, Max: 11 | | |

Symbol-graph JSON is representative of real-world workloads
(configuration files, API responses, log records, RPC envelopes).
The break-even where the algorithmic O(1) win begins to exceed the
refcount-per-copy overhead is **back-of-envelope projected at N ≥
30-50** per §12's structural diagnosis (lines 745-749). The
break-even has **NOT been empirically located**: the integrated
bench was only run against the canonical workload (mean N=2.06,
max N=11), never extended to N = 16, 32, 64, 128, 256, 512, 1024.
The figure is derived from §12's algebraic estimate (~10-15 ns
per-lookup win at N=2 vs ~30-40 ns refcount-per-copy overhead) and
the storage-micro's growth curve. A future consumer with a
known-large-N workload that motivates Option B would close this
gap with a synthetic-lookup extension; this note does not.

### 4. The architectural fork

Three architectural responses are available to consumers that face
the same wedge. The classification names each by the constraint it
relaxes, with the trade-off explicit:

#### Option A — Accept Copyable wrapper, keep single-array storage

- **Cost**: O(n) lookup; large-N workloads pay linearly.
- **Benefit**: 1 refcount per copy; Copyable value semantics
  preserved; no downstream API break.
- **When to choose**: median N ≤ ~30 (covers most real-world JSON,
  config, log, and small-collection traffic); downstream consumers
  rely on Copyable value semantics; no specific large-N consumer
  has surfaced.
- **swift-json's actual outcome**: this option was selected at v2
  arc close — see §12 "Disposition" (lines 775-793). swift-json is
  already 14× faster than Foundation on lookup at canonical
  workloads with this shape.

#### Option B — Break to `~Copyable` wrapper, multi-buffer storage

- **Cost**: Public API break — the value-wrapper becomes
  `~Copyable`; consumers migrate to borrow/consume idioms,
  pattern-match-extract becomes pattern-match-into-`inout`, and
  every `Copyable`-requiring conformance (Hashable, Equatable,
  Sendable in some shapes) must be re-derived or dropped.
- **Benefit (predicted)**: Multi-buffer storage shapes
  (`Dictionary.Ordered`, `Dictionary` slab, `Hash.Table`) become
  viable because the wrapper does not copy on extract — the
  wrapper is borrowed or moved instead. The structural cost model
  in §2 (refcount-per-copy × number of heap-backed components)
  predicts the pattern-match-copy term zeroes out under
  `~Copyable`, leaving only the algorithmic O(1) win. This
  prediction is structurally sound but empirically unobserved
  (see "Empirical status" below).
- **When to choose**: large N expected (median ≥ ~30 per §3.3,
  back-of-envelope, or unbounded); consumer can absorb the
  `~Copyable` API break; downstream ecosystem already accepts
  ~Copyable value types in the relevant position.
- **Reference shape**: `Dictionary.Ordered` itself per
  `swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift:84`
  is declared `public struct Ordered: ~Copyable`, with
  `extension Dictionary.Ordered: Copyable where Value: Copyable`
  at line 115 (the conditional reverts to Copyable when the
  wrapped value type is itself Copyable). Option B is the
  consumer's choice to retain the unconditional `~Copyable` shape
  rather than ride the conditional conformance — i.e., the
  consumer makes its OWN value-wrapper `~Copyable` so the
  conditional never fires.
- **Empirical status — IMPORTANT**: theoretical prediction only.
  The swift-json v2 L1-1 prototype that produced §3's measurements
  used the *conditional*-Copyable instantiation of
  `Dictionary.Ordered` (which becomes Copyable because `Value:
  Copyable` held for `RFC_8259.Value`). That is the v2 doc's L1
  path. Option B as described here corresponds to the v2 doc's L2
  path (full `~Copyable Value` cascade) — which was **NOT
  measured**: rolling the whole value-wrapper to unconditional
  `~Copyable` (e.g. `RFC_8259.Value: ~Copyable`) would eliminate
  the pattern-match-copy term in the §2 cost model, but the
  integrated cost under that composition is unobserved. A
  consumer reaching for Option B is making a structurally-sound
  prediction, not a measurement-backed one. The v2 doc explicitly
  documents L2 as "the only path forward" for large-N workloads
  and explicitly defers it under [BENCH-010] / [RES-018] until a
  consumer surfaces with a concrete need.

#### Option C — `~Copyable` companion in inline storage

- **Cost**: Cannot be Copyable (per [DS-*] / `[MEM-COPY-*]`,
  `@_rawLayout` prevents conditional Copyable on inline storage —
  see `ecosystem-data-structures-inventory.md` "Copyability"
  note); consumer accepts the move-only inline-storage API.
- **Benefit**: Zero heap-backed components on the inline path →
  zero refcount cost on inline reads; small-N win without paying
  the multi-buffer refcount overhead.
- **When to choose**: small N with strict cache-locality preference;
  consumer can accept the inline-storage move-only API; the
  bounded-capacity / spilling-to-heap shape fits the data
  distribution.
- **Reference shape**:
  `swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Small.swift:47`
  declares `public struct Small<let inlineCapacity: Int>: ~Copyable`
  unconditionally — exactly the right tool for the small-N case
  when the consumer can absorb move-only semantics.

#### Decision rubric

| Consumer constraint | Recommended path |
|---|---|
| Need Copyable value semantics + median N ≤ 30 | **A** (single-array, accept O(n)) |
| Need Copyable value semantics + median N > 30 | **A** by default; measure end-to-end through the consumer's actual access path before adopting B or C |
| Can break to `~Copyable` + median N > 30 | **B** (multi-buffer, `~Copyable` wrapper) |
| Can break to `~Copyable` + median N small + cache-local | **C** (`~Copyable` inline companion) |

The "measure end-to-end before adopting B or C" cell encodes the
methodological lesson from §3.2: isolated storage micro-benches
overstate integrated performance when the consumer pays
refcount-per-copy overhead along the hot path. Without an
integration probe, the architecture decision rides on a
measurement that does not capture the cost the architecture would
incur.

### 5. Recommended `[BENCH-NNN]` skill rule

Per [RES-006a], the methodological observation in §3.2 is promotable
to the `benchmark` skill as a normative rule. The skill file itself
MUST NOT be modified in this dispatch (separate skill-lifecycle arc
per the originating handoff's scope statement). Recommended text for
a future `skill-lifecycle` run:

> **`[BENCH-NNN]` Integration probe required for storage benches under Copyable wrappers**
>
> **Statement**: When measuring a storage primitive whose consumer
> access path layers a Copyable wrapper, an enum-case extract, or a
> `subscript`-through-the-wrapper indirection over raw storage
> access, isolated storage micro-benches MUST be paired with an
> end-to-end integration probe through the consumer's actual call
> pattern before the measurement drives an architecture decision.
>
> **Why**: Isolated benches with pre-warmed caches and direct
> storage access can overstate integrated performance materially
> when the consumer pays refcount-per-copy overhead along the hot
> path (~10× in the swift-json v2 reference case at N=4, where
> the storage shape paid 3-4 refcounts per Object copy; the
> generalization of that factor across consumer shapes is
> unverified — the rule fires regardless of magnitude). Multi-
> buffer storage primitives (e.g., `Dictionary.Ordered =
> Set.Ordered + Buffer.Linear + Hash.Table`) compound the refcount
> cost with the number of heap-backed components in the storage
> shape; the isolated bench measures the O(1) algorithmic win but
> not the N × K compound refcount term.
>
> **How to apply**: Before proposing an architecture change that
> swaps storage primitives behind a Copyable wrapper, ship two
> bench modes alongside the proposal — (a) an isolated
> storage-only mode (the existing `crossover`-style micro) and (b)
> an integrated mode that walks the consumer's actual access path
> at the workload's representative N distribution. If the
> integrated mode shows a regression, the architectural change is
> empirically refuted regardless of what the isolated mode shows.
>
> **Provenance**: `swift-institute/Research/copyable-wrapper-vs-multi-buffer-storage.md` v1.0.1 §3; refuted swift-json v2 arc per `swift-foundations/swift-json/Research/value-tree-redesign-v2.md` v1.1.0 §12.

This is a recommendation, not a skill amendment. The
`skill-lifecycle` arc that lands it will own the final wording,
the requirement-ID assignment, and the placement within the
benchmark skill.

## Outcome

**Status**: RECOMMENDATION

The cross-cutting structural finding from the swift-json v2 arc is
extracted and made citable institute-wide. Three downstream
recommendations:

1. **Consumer-side caution**: any institute package considering a
   composition of (Copyable value-wrapper) × (multi-buffer hash
   storage) reads through pattern-match-extract MUST consult §4's
   decision rubric and ship an integration-probe bench before
   driving the swap. Default to Option A (single-array, accept
   O(n)) at small N.

2. **Skill update**: the `benchmark` skill SHOULD adopt
   `[BENCH-NNN]` per §5 in a follow-up `skill-lifecycle` arc. This
   document does NOT amend the skill; it documents the
   recommendation in prose only.

3. **Bench-harness pattern**: the `parse-performance-bench` harness
   at `swift-foundations/swift-json/Experiments/parse-performance-bench/`
   — specifically its dual-mode design (`crossover` micro +
   `synthetic-lookup` integration + `size-dist` workload
   characterization) — is a reference pattern for the
   integration-probe requirement. Future consumers facing the same
   wedge SHOULD reuse the harness's shape rather than rebuild from
   scratch.

### Loose ends (per [RES-027])

| Item | Class | Disposition |
|---|---|---|
| Whether SE-0432 / SE-0466 future-direction work (Copyable-protocol-level optimizations) would change the conclusion at small N | **direction** | Filed as future work; not a load-bearing premise. The finding stands as long as Swift's Copyable defaults remain unchanged. |
| Whether the inline-vs-heap-spill threshold on `Dictionary.Ordered.Small<N>` shifts the Option C decision boundary for specific N distributions | **direction** | Filed as future work; consumers reaching for Option C should measure their own N distribution. |
| Whether the integration-overstatement factor (~10× in the swift-json case) generalises across consumer shapes or is workload-specific | **premise** (would change §5's recommendation strength if disproven) | Per [RES-027], premise items normally require an extant or immediately-created experiment. **Extant experiment 1**: the `parse-performance-bench` harness already captures the overstatement at one consumer shape. **Extant experiment 2** (created in same dispatch, 2026-05-13): `swift-institute/Experiments/copyable-wrapper-refcount-cost/` mechanically validates the §2 cost-model term — V1 (trivial isolated probe) showed the optimizer ELIMINATES the cost entirely (~0 ns across K=1..4), V2 (optimizer-resistant probe) showed K-linear cost (~7.68 ns per additional heap-backed component, matching the cited ~3-10 ns refcount-op range). Composite finding: the §2 cost-model term is real and observable BUT only under access paths that defeat optimizer elision — confirming the integration-probe requirement in §5 is the durable response, and refining its premise: isolated micro-benches do not merely understate the integrated cost; they can ELIMINATE it entirely. Generalisation across consumer shapes is still an open direction (the factor depends on how much optimization headroom the production path leaves), but the structural existence of the cost term is mechanically validated. The rule fires whether the factor is 10× or qualitative (cost present vs absent). |

## References

### Empirical evidence (primary; do not re-run)

- `swift-foundations/swift-json/Research/value-tree-redesign-v2.md`
  v1.1.0 (SUPERSEDED-BY-EVIDENCE), §12 "L1-1 disposition" lines
  688-803. Cited section-by-section in §3 above.
- `swift-foundations/swift-json/Research/parse-performance.md`
  v1.2.0 (DECISION) — Tier 0/1/3/4 baseline establishing the
  pre-L1-1 reference state.
- `swift-foundations/swift-json/Research/parse-performance-architecture.md`
  v1.0.2 (DECISION) — Span-specialized internal lexer/parser
  inside `swift-rfc-8259`; the parse-side architecture L1-1
  attempted to layer over.
- `swift-foundations/swift-json/Experiments/parse-performance-bench/`
  — bench harness with all diagnostic modes (`crossover`,
  `synthetic-lookup`, `size-dist`, `lookup`, `equiv`, `sanity`).
  Reference for the integration-probe pattern recommended in §5.

### Reference architecture (read for prior art)

- `swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.swift:84,115`
  — `public struct Ordered: ~Copyable` + the
  `extension Dictionary.Ordered: Copyable where Value: Copyable`
  conditional conformance. The Option B reference.
- `swift-primitives/swift-dictionary-primitives/Sources/Dictionary Primitives Core/Dictionary.Ordered.Small.swift:47`
  — `public struct Small<let inlineCapacity: Int>: ~Copyable`
  unconditional `~Copyable`. The Option C reference.

### Institute prior art (cited inline in §1)

- `swift-institute/Research/ecosystem-data-structures-inventory.md`
  v1.0.0 (DECISION, Tier 1)
- `swift-institute/Research/comparative-dictionary-primitives.md`
  v1.0.0 (RECOMMENDATION)
- `swift-institute/Research/storage-primitives-comparative-analysis.md`
  v1.1.0 (RECOMMENDATION, Tier 3)
- `swift-institute/Research/property-view-for-cow-copyable-types.md`
  v2.0.0 (DECISION)
- `swift-institute/Research/buffer-arena-conditional-copyable.md`
  v1.1.0 (RECOMMENDATION)

### Skill references

- [RES-003], [RES-003a], [RES-003b], [RES-003c] research-doc shape
  + index registration
- [RES-005], [RES-006a] analysis methodology + documentation
  promotion
- [RES-019] internal grep before external survey
- [RES-020] Tier 2 classification (cross-package, informal
  semantic commitment, medium cost of error, several-releases
  lifetime, reversible)
- [RES-021] prior art survey + contextualization step
- [RES-022] structural-correctness framing (the recommendation
  prioritizes structural correctness — refcount-cost model — over
  diff-size axis)
- [RES-023] empirical-claim verification at write time
- [RES-026] citations
- [RES-027] loose-end follow-up
- [HANDOFF-013] reader-side prior-research check
- [HANDOFF-049] stash-edit-commit-pop pattern (applies when
  committing this doc + the `_index.json` update under
  parent-session uncommitted contamination)
- [BENCH-001]–[BENCH-010] benchmark skill (recommended addition
  in §5)

## Provenance

Extracted from the just-closed swift-json v2 arc per the dispatch
brief `HANDOFF-copyable-wrapper-multi-buffer-storage.md`
(2026-05-13). The parent session executed Tiers 0/1/3/4 of the
parse-performance arc, attempted L1 (storage swap), measured a
catastrophic regression, diagnosed the root cause, and rolled back.
This document extracts the cross-cutting principle so the next
institute consumer reaching for the same composition does not
repeat the prototype-rollback cycle.
