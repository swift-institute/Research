# Asymmetric-Quadrant Ergonomics as Rejection Criterion for Capability-Protocol Affordances

Date: 2026-04-26
Scope: ecosystem-wide (all capability-protocol packages with quadrant-shaped design spaces — `~Copyable` Self × `~Copyable` Value, etc.)
Tier: 2 (cross-package, design-decision heuristic, reversible precedent)
Status: RECOMMENDATION — pattern is empirically validated across multiple decisions in 2026-04-26 session; codifying as a rejection criterion for future capability-protocol authoring.
Provenance: Reflection `2026-04-26-carrier-decisions-and-capability-vs-noun-type.md` Pattern 2 (asymmetric-quadrant ergonomics rejected; symmetric quadrant ergonomics accepted).

---

## Context

Capability protocols in the swift-institute ecosystem (Carrier, Mutator, future capability protocols) often present design questions of the form *"should we add ergonomic affordance X to this capability?"* Answers consistently hinge on the same underlying axis: **does X work uniformly across all four quadrants of the ~Copyable × ~Escapable cross-product, or only on a subset?**

Recurrence in 2026-04-26 alone:

1. `@dynamicMemberLookup` on `Carrier`: works for Q1 only (Self: Copyable, Value: Copyable); REFUTED for the three remaining quadrants. **DECISION: don't add.**
2. Sibling default extensions (V2/V3/V4 in `Experiments/relax-trivial-self-default/`): work for ALL four quadrants. **DECISION: do add.**
3. KeyPath subscript on `Mutator`: REFUTED for `~Copyable` Self / `~Copyable` Value. **DECISION: don't add (analogous logic to #1).**

The pattern: **asymmetric-quadrant ergonomic affordance is worse than uniform absence**. A convenience that works only in the "easy" quadrant produces a cliff at the protocol surface — consumers in Q1 reach for it, consumers in Q2/Q3/Q4 hit a hard refusal. The cliff is more confusing than no convenience at all.

---

## Question

Should the swift-institute ecosystem codify asymmetric-quadrant ergonomic affordance as a default rejection criterion for capability-protocol design questions, with documented exceptions for cases where the asymmetric affordance has compelling utility in the supported quadrant?

---

## Analysis

### The quadrant matrix

For protocols whose design space includes ~Copyable Self × ~Copyable Value (the canonical four-quadrant cross-product):

| Quadrant | Self | Value | Common name |
|----------|------|-------|-------------|
| Q1 | Copyable | Copyable | "trivial / easy quadrant" |
| Q2 | Copyable | ~Copyable | "wrapping a non-copyable" |
| Q3 | ~Copyable | Copyable | "non-copyable carrier of a copyable" |
| Q4 | ~Copyable | ~Copyable | "fully linear" |

Many language features work in Q1 and degrade across Q2/Q3/Q4 because Swift's pre-ownership-types ergonomic affordances assumed Copyable as the default. The asymmetric pattern is therefore a recurrent shape, not a one-off concern.

### Why asymmetric is worse than uniform absence

| Outcome | Asymmetric (Q1-only affordance) | Uniform absence |
|---------|--------------------------------|-----------------|
| Q1 consumers | Get the affordance; might rely on it | Don't have the affordance; use the uniform path |
| Q2/Q3/Q4 consumers | Hard refusal at the protocol surface; surprise; documentation friction | Same uniform path as Q1; no surprise |
| Library author | Must document the asymmetry; readers must internalize the cliff | One uniform contract; no asymmetry to document |
| Future migration | Q1 sites coupled to the affordance must rewrite if they cross to Q2/3/4 | No coupling to rewrite |

The asymmetric affordance optimizes for the easy quadrant at the cost of cognitive friction across the remaining three. Uniform absence optimizes for cognitive uniformity at the cost of the easy quadrant losing a convenience.

For capability protocols (Carrier, Mutator, future) where consumers cross quadrant boundaries routinely (e.g., a generic algorithm written against Carrier might accept any quadrant), uniform absence is the more durable choice.

### Documented exceptions

| Exception | When it applies | What to document |
|-----------|-----------------|------------------|
| Q1 is overwhelmingly the dominant use case (>90% of consumers) | The asymmetric affordance's value in Q1 outweighs the cliff cost in Q2/3/4 | Quantitative justification (consumer survey or empirical measurement) |
| The affordance has a documented uniform replacement at the cliff | Consumers hitting Q2/3/4 have a clear alternative | The replacement's name + documentation pointer |
| Q1 has an established external convention requiring the affordance (e.g., stdlib-compat) | External-compat constraint forces the asymmetric shape | Cite the external convention + the Q2/3/4 alternative |

Absent one of these, asymmetric affordance is rejected by default.

### Decision-test procedure

When evaluating "should we add ergonomic affordance X to capability protocol P?":

1. Construct the four-quadrant test matrix (or whichever cross-product is canonical for P).
2. Enumerate which quadrants X works in.
3. If X works in all quadrants (symmetric): **proceed**, evaluate other criteria normally.
4. If X works in a strict subset (asymmetric): **default-reject**. To overturn the default-reject, the proposal MUST document one of the exceptions above.

The decision-test is fast: a 30-line experiment per quadrant resolves the symmetry question (cf. 2026-04-26 `Experiments/dynamic-member-lookup-quadrants/` 4 variants in <30 minutes).

---

## Outcome

**Recommendation**: Adopt asymmetric-quadrant ergonomics as a default rejection criterion for capability-protocol affordance design questions in the swift-institute ecosystem.

**Application sites**:

- Future Carrier convenience APIs (subscript shapes, dynamic-lookup, key-path operations).
- swift-mutator-primitives capability extensions (mirror Carrier's discipline).
- Any future capability protocol authored in `swift-primitives/`.
- Hypothetical HasSerializer / HasValidator / HasHasher and similar per-capability protocols (per `2026-04-26` reflection's discussion of per-capability protocol design).

**Codification path**: This Doc serves as the canonical reference for the heuristic. The decision-test procedure can be cited in future capability-protocol Research Docs (per [RES-013a]). If the heuristic survives 6-12 months without principled-disagreement counterexamples, promote to a skill rule (candidate target: `swift-package` or `code-surface` skill).

**Empirical backing**:

- Carrier `@dynamicMemberLookup`: 4-variant experiment (`Experiments/dynamic-member-lookup-quadrants/`); REFUTED in Q2/Q3/Q4; DECISION not to add (`Research/dynamic-member-lookup-decision.md`).
- Carrier sibling default extensions: 3-variant experiment (`Experiments/relax-trivial-self-default/`); CONFIRMED across all quadrants; DECISION to add (default extension relaxation landed v0.1.x).
- Mutator KeyPath subscript: REFUTED for `~Copyable` Self / `~Copyable` Value (per `swift-mutator-primitives` research, 2026-04-26 spin-off package).

Three independent decisions converged on the same axis without explicit codification — the heuristic was being re-derived each time. This Doc closes that gap.

---

## Cross-references

- Reflection: `2026-04-26-carrier-decisions-and-capability-vs-noun-type.md` (origin; Pattern 2 in §"Patterns and Root Causes")
- Skill rule (related): [PKG-NAME-009] Capability-Protocol vs Noun-Type Distinction (codified from same reflection's Pattern 1 / dominant insight)
- Experiments cited: `swift-primitives/swift-carrier-primitives/Experiments/dynamic-member-lookup-quadrants/`, `Experiments/relax-trivial-self-default/`
- Decision Docs cited: `swift-primitives/swift-carrier-primitives/Research/dynamic-member-lookup-decision.md`, `Research/mutability-design-space.md`
- Companion ecosystem inventory: `swift-institute/Research/carrier-ecosystem-application-inventory.md` (RECOMMENDATION 2026-04-26; classifies capability-shaped vs witness-style protocols)
