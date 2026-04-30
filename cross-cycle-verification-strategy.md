# Cross-Cycle Latent-Ambiguity Verification Strategy

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

Multi-cycle audit-remediation arcs land ecosystem-wide changes incrementally. When parallel/sibling cycles are active, ambiguities introduced by one cycle can remain *latent* — not exposed by the cycle's own gates — until a sibling cycle's broader scope surfaces them. The 2026-04-24 cycle-3-close investigation surfaced exactly this pattern: Cycle 2's `Kernel.Signal.Information` ambiguity was latent until Cycle 3's broader Linux verification gate exposed it.

This Doc scopes the question of what principled verification strategy prevents cross-cycle latent ambiguities going forward.

## Question

When a multi-cycle audit-remediation arc lands ecosystem-wide changes with parallel/sibling cycles active, what verification gate strategy minimizes latent cross-cycle ambiguities? Specifically: should each cycle's gate scope be widened (paranoid per-cycle), should the arc close with a full-ecosystem sweep (arc-end gate), or should an external mechanism (post-arc `/audit`) catch the residue?

## Analysis

### Three candidate strategies

| Strategy | Where the gate fires | What it catches | Cost |
|----------|---------------------|-----------------|------|
| **A. Per-cycle paranoid** | Each cycle widens its gate to ecosystem-wide Linux/Darwin/Windows verification | Catches cross-cycle ambiguities at the cycle that introduced them | High per-cycle cost; each cycle pays the wider-scope verification overhead |
| **B. Arc-close full-ecosystem** | Single full-ecosystem sweep at the end of the multi-cycle arc | Catches all cross-cycle ambiguities at one structured point | Latency: ambiguities accumulate across cycles before the gate fires; harder to attribute when one fires |
| **C. Post-arc `/audit` pass** | A fresh-eyes audit dispatch after the arc closes | Catches anything the arc's gates missed; produces a durable audit doc | Highest latency; requires a separate dispatch; benefits from independence |

### Observed failure mode (2026-04-24)

Cycle 2 of the layer-perfection three-cycle arc landed `Kernel.Signal.Information` changes. The cycle's own gate (Darwin + macOS Linux build) passed clean. Cycle 3 (a different cycle in the same arc) included Linux platform-specific work that brought in additional Linux modules; building those exposed a `Kernel.Signal.Information` cross-cycle dual-declaration ambiguity introduced by Cycle 2 but invisible to Cycle 2's narrower gate.

Strategy A would have caught it (Cycle 2's wider gate would have exposed the same ambiguity Cycle 3 ultimately did). Strategy B would have caught it at arc-close. Strategy C would have caught it at post-arc audit time.

### Trade-off analysis

| Dimension | A (paranoid per-cycle) | B (arc-close) | C (post-arc audit) |
|-----------|------------------------|---------------|--------------------|
| Latency to surface | Earliest | Mid | Latest |
| Per-cycle cost | High | Low | Low (separate dispatch) |
| Attribution clarity | Clean (cycle that introduced is the cycle that catches) | Muddied (multiple cycles' ambiguities mix) | Clean (audit reports per-finding origin) |
| Authorship cost | Per-cycle gate-widening | One arc-close gate | One audit dispatch |
| Mental load on cycle author | Each cycle's author must hold ecosystem-wide model | Arc-close author holds full model | Audit author starts fresh |

### Open analysis

| Question | Status |
|----------|--------|
| What's the empirical frequency of cross-cycle ambiguities in observed multi-cycle arcs? | TODO — survey 3+ multi-cycle arcs and count cross-cycle defects |
| Does Strategy A's paranoid per-cycle cost scale linearly or super-linearly with cycle count? | TODO — measure on next multi-cycle arc |
| Can a hybrid work? (e.g., narrower per-cycle gates + mandatory arc-close gate) | Likely yes — needs validation |

## Outcome

**Status**: IN_PROGRESS

**Held findings (operational, applicable now)**:

1. Multi-cycle arcs SHOULD plan an arc-close full-ecosystem verification gate (Strategy B as a baseline).
2. Per-cycle gates SHOULD be wider than the cycle's narrowest possible scope when sibling cycles are active in parallel — at minimum, the gate should cover packages that a sibling cycle has already touched.
3. Post-arc `/audit` (Strategy C) is appropriate when the arc lands in a high-stakes pre-release window — the additional latency is tolerable in exchange for the independence.

**Pending empirical work**:

1. Compare the cost of Strategy A's per-cycle paranoia vs Strategy B's arc-close gate against observed cross-cycle ambiguity rate
2. Define a hybrid (per-cycle minimum widening + mandatory arc-close gate) and validate on the next multi-cycle arc
3. Document the strategy explicitly in the audit / handoff skill once an instance proves it out

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The strategy choice affects multi-cycle arcs' verification overhead but is reversible (a chosen strategy can be revised after one or two arcs of evidence).

## References

- Reflection: [Research/Reflections/2026-04-24-cycle-3-close-and-inlinable-spi-cascade-non-fire.md](Reflections/2026-04-24-cycle-3-close-and-inlinable-spi-cascade-non-fire.md) — origin instance (Cycle 2 → Cycle 3 latent ambiguity)
- Companion: [inlinable-spi-transitive-semantics.md](inlinable-spi-transitive-semantics.md) — the same cycle's other research finding
- Skills: [HANDOFF-035] cascade-migration termination criteria (related: ecosystem-wide build gate); [AUDIT-026] substantive canary gate substitution
