# Sub-Product Split-Decision Rubric

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
provenance: Research/Reflections/2026-05-07-dep-pass-audit-and-cleanup-execution.md
---
-->

## Context

A recurring decision in the swift-primitives ecosystem is whether a sibling variant inside a multi-product package should be promoted to its own package, kept as a sibling target, or absorbed into a neighbor. Three signals compete on every such call:

- **(A) Upstream-pruning** — would extracting this candidate cause the package's resolved dep tree to prune meaningfully? The LEB128 precedent ([algebra-primitives-package-split.md](algebra-primitives-package-split.md)) demonstrated that extracting a sub-product to lower its tier can prune ~10 transitive deps for downstream consumers — that's an upstream effect, measured at the candidate's package-deps boundary.

- **(B) Structural axis ([MOD-003] Variant Decomposition)** — does the candidate sit cleanly along a single decomposition axis (strategy / operation / behavior / representation) such that it is independent of its siblings (no inter-variant dependencies, by [MOD-003])?

- **(C) Capability rent ([MOD-RENT])** — does the candidate satisfy the three-criteria rent test (capability + consumer + theoretical content)?

The 2026-05-07 dep-cleanup-pass session opened with a (rejected) split proposal frame that prioritized **downstream consumer count** as the dominant signal — i.e., it leaned on the consumer criterion of [MOD-RENT] in isolation. The user corrected the framing in two parts:

1. **Upstream effect, not downstream count**, is the load-bearing signal during pre-1.0 development. (Memory: `feedback_split_upstream_not_downstream`.)
2. **No package or module deletion during development.** Consumer-count gating from [MOD-RENT] applies at PUBLIC-RELEASE/TAG time only, not during development. (Memory: `feedback_no_removal_during_development`, `feedback_correctness_sole_driver_during_development`.)

Without a written priority order across A, B, C the same misframing recurs whenever a candidate passes one signal but the *prioritized* signal would have ruled differently. This document codifies the priority.

## Question

When does a sibling variant become a split candidate, and what is the priority order across the three competing signals (upstream-pruning / structural axis / capability rent)?

## Recommendation

### Priority Order

| Priority | Signal | Operates as | Where defined |
|---|---|---|---|
| **0** | [MOD-DOMAIN] coherence | Hard precondition — factor the law, not the module | [modularization SKILL.md] |
| **1** | Upstream-pruning | Dominant during pre-1.0 development | This rubric (A) |
| **2** | Structural axis | Necessary structural condition | [MOD-003] |
| **3** | Capability rent (consumer criterion) | Gate at PUBLIC-RELEASE/TAG time only | [MOD-RENT] |

**Decision rule**: Apply in order 0 → 1 → 2 → 3. Each priority level is a gate; failing a higher-priority gate ends the inquiry regardless of lower-priority signals. The candidate is a split candidate only if **all applicable** gates pass for the current lifecycle phase.

**Lifecycle gating**: Priority 3 (consumer criterion of [MOD-RENT]) does NOT fire during pre-1.0 development per `feedback_correctness_sole_driver_during_development`. The capability and theoretical-content sub-criteria of [MOD-RENT] are absorbed into Priority 0 ([MOD-DOMAIN]) — only the consumer-count sub-criterion is deferred. During development, the rubric is effectively three gates (0, 1, 2). At PUBLIC-RELEASE/TAG time, all four gates apply.

### Gate Definitions

#### Gate 0 — [MOD-DOMAIN] Coherence (Hard Precondition)

The candidate MUST represent a coherent semantic domain (a definition, a law, a spec, a structural invariant) — not just code. Convenience wrappers, naming sugar, and shared-helper extractions fail this gate regardless of upstream effects or structural shape.

| Pass | Fail |
|---|---|
| `Buffer Linear Primitives` (storage-strategy axis: contiguous-memory invariant, distinct from Ring's wrap-around invariant) | "BufferUtilities Primitives" (collected helpers — not a domain) |
| `Sequence Drain Primitives` (consuming-iteration law, distinct from non-consuming forEach) | "Sequence Helpers Primitives" (mixed bag) |

A failure at Gate 0 ends the inquiry. The candidate is NOT a split candidate. The disposition is "keep where it is" (sibling target or in-line within an existing target), not "promote to package."

#### Gate 1 — Upstream-Pruning Effect

If the candidate passes Gate 0, ask: does extracting the candidate cause meaningful upstream tree pruning at the candidate's package-deps boundary? "Meaningful" is measured against the primary container the candidate lives in today.

**Test**:

1. Identify the candidate's actual upstream deps (the imports its source files use, transitively through `@_exported` re-export chains — the same uniquely-providing analysis from [MOD-025]).
2. Identify the container's other contents' actual upstream deps.
3. Compute `delta = container_deps − (candidate_deps ∪ {other_contents}_deps)`. The delta is the set of deps the container carries today *only* because the candidate is bundled in.
4. If the delta is empty or trivially small (≤ 1 packages, no tier-spread compression), the upstream effect is absent — Gate 1 fails.
5. If the delta is meaningful (≥ 2 packages, OR a single high-tier dep that compresses the container's effective tier), Gate 1 passes.

**Sense-check**: The LEB128 / algebra-primitives precedent is the canonical pass case. Extracting the abstract algebraic hierarchy from `swift-algebra-primitives` lowered the abstract-hierarchy product's tier from 8 to 3, freeing `numeric-primitives` (tier 1) to depend on it — a tier-compression effect on the *consumer's* dep tree, but the gating evidence was measured at the candidate's package-deps boundary (not the consumer count).

**Failure mode this gate catches**: A structurally clean variant ([MOD-003]-passing) that nonetheless shares 100% of its upstream deps with its siblings produces no upstream pruning when extracted. Promoting it to a package adds a `Package.swift`, a maintenance surface, a review cost on every adjacent change — without earning any tier-compression or dep-graph benefit. The candidate stays a sibling target.

**Worked failure example**: `Buffer Linear Primitives` (in `swift-buffer-primitives`). It passes Gate 0 (contiguous-memory invariant — real domain). It passes [MOD-003] (storage-strategy axis, sibling-independent). But its upstream deps are a near-superset of `Buffer Ring Primitives` and `Buffer Slab Primitives` — extracting it to `swift-buffer-linear-primitives` would not prune `swift-buffer-primitives`'s tree meaningfully. Gate 1 fails. Disposition: keep as sibling target inside `swift-buffer-primitives`.

#### Gate 2 — Structural Axis ([MOD-003])

If the candidate passes Gate 1, confirm it sits along a single decomposition axis cleanly:

- Sibling-independent (no inter-variant dependencies, except documented delegation per [MOD-003]).
- Axis is single-named (strategy / operation / behavior / representation — not "miscellaneous").
- Co-extraction-safe (extracting one sibling along the axis does not orphan the others).

**Failure mode this gate catches**: A candidate that prunes upstream cleanly but whose siblings carry implicit cross-references (a shared helper used by Ring AND Linear, for example) is structurally entangled. Extracting it forces extracting the helper too, or duplicating it. Disposition: refactor the entanglement first (move the helper to Core or out-line), THEN re-evaluate the split.

#### Gate 3 — Capability Rent (Consumer Criterion, PUBLIC-RELEASE only)

At PUBLIC-RELEASE/TAG time only, apply the consumer sub-criterion of [MOD-RENT]: does the candidate have at least one real ecosystem consumer (excluding the candidate's own tests and self-examples)?

**During development**: This gate does NOT fire. A candidate with zero consumers may still be a legitimate split if Gates 0–2 pass — the consumer is presumed-future and consumer-count gating is deferred per `feedback_correctness_sole_driver_during_development`.

**At PUBLIC-RELEASE**: The gate fires. A candidate with zero consumers at release time is a candidate for absorption / deprecation / deletion per [MOD-RENT].

### Worked Examples

The 2026-05-07 dep-cleanup-pass surfaced three illustrative cases; each passes at least one signal but fails the *prioritized* signal that the rubric promotes.

#### Buffer Linear

| Gate | Result |
|---|---|
| 0. [MOD-DOMAIN] | Pass — contiguous-memory invariant is a real domain |
| 1. Upstream-pruning | **Fail** — shares ~all upstream deps with Buffer Ring / Buffer Slab; extraction prunes nothing |
| 2. Structural axis | (Pass — storage-strategy axis is clean) |
| 3. Consumer | (Deferred — pre-1.0) |

**Disposition**: Keep as sibling target inside `swift-buffer-primitives`. The earlier framing that proposed Buffer Linear as a split candidate (citing [MOD-003] axis fitness in isolation) leaned on Gate 2 over Gate 1. The rubric makes the priority explicit: Gate 1 fails, inquiry ends, no split.

#### Memory Pool

| Gate | Result |
|---|---|
| 0. [MOD-DOMAIN] | Pass — pool-allocator invariant (bounded, reusable, free-list-managed) is a real domain |
| 1. Upstream-pruning | **Fail** — shares Memory.Address arithmetic deps and Cardinal/Ordinal infrastructure with the rest of `swift-memory-primitives`; extraction prunes ~0 deps |
| 2. Structural axis | (Pass — allocator-strategy axis) |
| 3. Consumer | (Deferred — pre-1.0) |

**Disposition**: Keep as sibling target inside `swift-memory-primitives`. The mistake the rubric corrects: defending the candidate on conceptual-purity grounds ("pool ≠ arena") without showing upstream effect.

#### Async Channel

| Gate | Result |
|---|---|
| 0. [MOD-DOMAIN] | Pass — channel semantics (rendezvous / buffered / closed-state law) is a real domain |
| 1. Upstream-pruning | **Fail** — channel implementation reuses Mutex, Continuation, and Sequence infrastructure already needed by sibling Async primitives; no upstream-tree compression |
| 2. Structural axis | (Pass — coordination-shape axis) |
| 3. Consumer | (Deferred — pre-1.0) |

**Disposition**: Keep as sibling target inside the relevant async primitives package.

### Counter-Example: When a Split IS Justified (LEB128 precedent)

For contrast, the LEB128 / algebra-primitives precedent is the rubric's canonical pass case:

| Gate | Result |
|---|---|
| 0. [MOD-DOMAIN] | Pass — abstract algebraic hierarchy (Magma → Field) is a coherent law-bearing domain |
| 1. Upstream-pruning | **Pass** — extracting the abstract hierarchy lowers its product tier from 8 to 3, allowing `numeric-primitives` (tier 1) to depend on it. The tier compression frees a downstream tier inversion. |
| 2. Structural axis | Pass — abstract-vs-concrete axis is single and clean |
| 3. Consumer | (Deferred — pre-1.0; would pass at release with `numeric-primitives` as consumer) |

**Disposition**: Split candidate. The split is documented in [algebra-primitives-package-split.md](algebra-primitives-package-split.md).

## Anti-Patterns

These framings recur and the rubric explicitly rejects them:

- **"Many downstream consumers want this alone"** as a primary justification. Downstream consumer count is a Gate 3 signal (PUBLIC-RELEASE only) and never the dominant signal during development. Memory: `feedback_split_upstream_not_downstream`.
- **"Conceptually distinct from its siblings"** without showing upstream effect or [MOD-003] axis fitness. Conceptual distinctness is a tiebreaker among Gate 0–2 passers, not an independent justification. (Same anti-pattern called out in [MOD-RENT]'s "conceptual-purity defense" section.)
- **"Removes some files from the umbrella package"** — file-count optimization is not an upstream-pruning effect. Gate 1 measures dep-tree pruning, not source-file relocation.

## Decision Procedure (Operational Form)

When evaluating a sibling variant for split candidacy:

```
1. Apply Gate 0 ([MOD-DOMAIN]).
   ├─ Fail → NOT a split candidate. Disposition: keep as sibling target or absorb. STOP.
   └─ Pass → continue.

2. Apply Gate 1 (upstream-pruning).
   ├─ Fail → NOT a split candidate during development. Disposition: keep as sibling target. STOP.
   └─ Pass → continue.

3. Apply Gate 2 ([MOD-003] structural axis).
   ├─ Fail → Refactor entanglement first; re-evaluate after. STOP.
   └─ Pass → continue.

4. Lifecycle check.
   ├─ Pre-1.0 development → split candidate confirmed. Proceed to scaffolding.
   └─ At PUBLIC-RELEASE/TAG time → apply Gate 3 ([MOD-RENT] consumer).
       ├─ Fail → reconsider absorption / deprecation per [MOD-RENT].
       └─ Pass → split candidate confirmed at release-readiness.
```

## Cross-References

- [modularization SKILL.md] §[MOD-DOMAIN] — Factor the law, not the module (Gate 0)
- [modularization SKILL.md] §[MOD-003] — Variant decomposition (Gate 2)
- [modularization SKILL.md] §[MOD-008] — Split decision criteria (subsumed; this rubric is the authority on priority order)
- [modularization SKILL.md] §[MOD-RENT] — Three-criteria rent test (Gate 3 source)
- [modularization SKILL.md] §[MOD-025] — Dep-cleanup-pass audit procedure (the operational source of upstream-pruning measurement)
- [algebra-primitives-package-split.md](algebra-primitives-package-split.md) — LEB128 precedent (Gate 1 canonical pass)
- Memory: `feedback_split_upstream_not_downstream`, `feedback_no_removal_during_development`, `feedback_correctness_sole_driver_during_development`

## Provenance

Written 2026-05-07 in response to action item from `Research/Reflections/2026-05-07-dep-pass-audit-and-cleanup-execution.md`. The rubric codifies the prioritization that the user's mid-session corrections established as canonical: upstream effect dominates downstream count during development; consumer gating is deferred to PUBLIC-RELEASE.

[modularization SKILL.md]: ../Skills/modularization/SKILL.md
