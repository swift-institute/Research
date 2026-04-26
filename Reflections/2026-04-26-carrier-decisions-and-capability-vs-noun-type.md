---
date: 2026-04-26
session_objective: Resolve outstanding carrier-primitives design questions (Span family adoption, dynamicMemberLookup, default-extension relaxation, mutability variant), spin off swift-mutator-primitives via handoff, and dispatch a full-ecosystem application-opportunity inventory.
packages:
  - swift-primitives/swift-carrier-primitives
  - swift-primitives/swift-mutator-primitives
  - swift-institute/Research
status: processed
processed_date: 2026-04-26
triage_outcomes:
  - type: skill_update
    target: swift-package
    description: "[PKG-NAME-009] Capability-Protocol vs Noun-Type Distinction — when to apply Namespace.\\`Protocol\\` convention (only with backing noun-type) vs top-level capability protocol (no namespace shell)"
  - type: research_topic
    target: asymmetric-quadrant-ergonomics-as-rejection-criterion.md
    description: "RECOMMENDATION Tier 2 — codifies decision-test procedure for capability-protocol affordance proposals; default-reject asymmetric ergonomic affordances unless documented exception applies"
  - type: package_insight
    target: swift-carrier-primitives/Research/capability-lift-pattern.md
    description: "Amended Existing ecosystem instances table to include Affine.Discrete.Vector (4th adopter); cites carrier-ecosystem-application-inventory.md provenance"
---

# Carrier v0.1.x decisions and the capability-vs-noun-type pattern

## What Happened

Long arc through the carrier-primitives package, beginning with "should we default `Underlying = Self`?" and ending with two completed branching investigations (swift-mutator-primitives package, ecosystem application inventory). Substantial commits landed in carrier-primitives:

- **Span family conformances** added via `Experiments/span-carrier-conformance/` (V1 REFUTED default, V2/V3/V4 CONFIRMED explicit witnesses) → 4 SLI files with explicit `@_lifetime` witnesses.
- **Test refactor (strict /testing application)**: 28 SLI per-source test files + 5 protocol test files, four-category suite structure per [TEST-005], `Fixture.*` hoisted into Test Support. 168 tests in 165 suites.
- **Trivial-self default extension renamed**: `Carrier+Trivial.swift` → `Carrier where Underlying == Self.swift` (filename mirrors literal Swift constraint clause; cross-platform-friendly modulo Windows-reserved `:`).
- **Default extension relaxation**: `Experiments/relax-trivial-self-default/` (V1/V2/V3 all CONFIRMED) → three sibling defaults added covering ~Escapable / ~Copyable / both quadrants. Span family conformances collapsed from ~12-line explicit witnesses to 4-line typealias-only forms (32 lines saved).
- **DECISION docs**:
  - `Research/dynamic-member-lookup-decision.md` — DECISION not to add `@dynamicMemberLookup` (Q1-only affordance per `Experiments/dynamic-member-lookup-quadrants/`).
  - `Research/mutability-design-space.md` — DECISION read-only stays at v0.1.x; option-(C) orthogonal Mutator package is the principled future shape.

Two **branching handoffs** dispatched and completed in-session:

- `HANDOFF-swift-mutable-primitives.md` → became `swift-mutator-primitives` (naming pivot from research: Mutator is the noun, Mutable the typealias; `Mutatable` was a strawman). Package landed v0.1.0-ready with 4 sibling default extensions, 20 SLI conformances, 34 tests in 19 suites, full DocC catalog. Three Tier-1/2 DECISIONS produced including a corrective finding that `mutating _modify` is NOT a valid protocol property requirement (Swift admits only `get`/`set`).
- `HANDOFF-ecosystem-application-inventory.md` → produced `swift-institute/Research/carrier-ecosystem-application-inventory.md` (RECOMMENDATION). Surveyed 292 packages; 26 hoisted-protocol declarations classified; new `Affine.Discrete.Vector` capability-lift adopter discovered (not yet cited in `capability-lift-pattern.md` v1.1.0).

## What Worked and What Didn't

**Worked**:

- **Experiment-first for design questions**: every major decision had a small empirical backing (Span: 4 variants, dyn-member-lookup: 4 quadrants, default relaxation: 3 quadrants). Each experiment was <30 minutes; each produced a definitive answer. Analysis-without-experiment would have leaned toward more conservative outcomes (e.g., we'd probably have NOT relaxed the default if we'd only argued first-principles, because the lifetime-annotation interaction across quadrants felt fragile).
- **Naming pivots from in-session research** (Carrier+Trivial → Carrier where Underlying == Self; swift-mutable → swift-mutator). Both rebases happened cleanly because the renames were small at the moment they were caught (single-file in carrier; not-yet-published in mutator).
- **Branching handoffs ran end-to-end in the same conversational arc**. Both investigations completed in-session and produced their Findings sections. The branching template's structural separation kept the parent context clean.

**Didn't work as well**:

- **Test split is high-redundancy by design**. 28 SLI test files for 24 stdlib types plus 4 Span family — most are 4 categories × 1-3 trivial round-trip assertions. Strict [TEST-005] / [TEST-009] application produces a lot of file-level boilerplate. The user explicitly asked for this ("don't be lazy") and accepted the tradeoff, but the redundancy is real and any future macro-driven SLI conformance generation should also generate the test files mechanically.
- **Filename convention with literal constraint clauses** (`Carrier where Underlying == Self, Self ~Escapable.swift`) reads cleanly when present but is awkward to type in shell, hits Windows-reserved-colon issues requiring abbreviation, and produces long filenames that strain `ls` output. Not a defect — just a friction the convention pays for cross-platform symmetry.
- **The dynamicMemberLookup decision required a research note + an experiment + a 4-quadrant analysis to settle** — and the answer was "don't add it" all along. The work wasn't wasted (the empirical backing makes the DECISION defensible against future requests), but the question shape ("should we add convenience X?") often resolves negatively for capability protocols and the *prior* (skip) is reasonable to start from.

## Patterns and Root Causes

**The dominant insight of the session was the capability-vs-noun-type distinction.**

The swift-institute `Type.\`Protocol\`` namespace convention works for noun-types (Cardinal, Ordinal, Hash) because they exist as both value type AND namespace via the back-tick trick — there's a real concrete `Cardinal` you instantiate, AND a namespace, AND a refining protocol. The triple identity is meaningful.

For pure capability protocols — Carrier, hypothetical Mutator, hypothetical Serializable — there is no concrete noun-type. Forcing them into the namespace.Protocol mold creates an empty enum shell with nothing in it but punctuation around the dotted form. The user flagged this as "silly" for `Carrier.Mutable`, and the same intuition led to choosing a separate package (swift-mutator-primitives) rather than nesting Mutator under Carrier.

This distinction recurred at least four times in the session:

1. Whether `Carrier.Mutable` should be a nested protocol (DECISION: no, separate package).
2. Whether the deferred `swift-mutable-primitives` package should be named for the noun (Mutator) or the adjective (Mutable) — the noun wins per the same logic.
3. The ecosystem inventory's classification distinguishing capability-shaped (Cardinal, Ordinal, Hash, Affine.Discrete.Vector — 4 adopters) from witness-style (Equation, Comparison, Coder, Serializer, etc. — 13 protocols, *out per recommendation #6 of capability-lift-pattern.md*).
4. The HasSerializer-style discussion — a capability protocol per concept (HasSerializer, HasValidator, HasHasher) not a single meta-protocol abstracting "has-a", because Swift can't kind-polymorphism over protocols and per-capability protocols communicate semantic intent at the type level.

The pattern: **when you reach for a dotted namespace, ask whether the namespace name is a noun-type. If it isn't, you're inventing punctuation, not capturing structure.** This is not currently formalized in any skill — it's been re-derived from first principles each time. Worth elevating.

**Secondary pattern: asymmetric-quadrant ergonomics as a rejection criterion.**

Multiple decisions in this session (and in the broader carrier ecosystem) hinged on the same shape: "if ergonomic X works for Q1 only, that's worse than X working for none." Recurrences:

- `@dynamicMemberLookup` works for Q1 only → DECISION: don't add (asymmetric is worse than uniform absence).
- Sibling default extensions work for ALL four quadrants → DECISION: do add (uniform symmetry wins).
- The same logic surfaced in the mutator-primitives KeyPath-interaction research (REFUTED for ~Copyable Self / ~Copyable Value).

This isn't formalized anywhere either. It's a recurring rejection criterion that future capability-protocol authors will benefit from having pre-figured.

**Tertiary pattern: experiment-first for design questions about language-feature interactions.**

When a design question depends on how a Swift language feature (`@_lifetime`, KeyPath constraints, suppressed associated types, dynamic member lookup) interacts with a protocol shape, a 30-line experiment beats first-principles analysis. Three of the four experiments this session were of this shape; the fourth (Span conformance viability) was slightly different (testing a specific adoption rather than a feature interaction).

The trigger shape is "language feature × protocol shape" or "language feature × quadrant matrix" — both are bounded enough for a small experiment to cover the discrimination space cleanly.

## Action Items

- [ ] **[skill]** swift-package: explicitly distinguish capability protocols from noun-type protocols when applying the `Type.\`Protocol\`` namespace convention. Currently the convention is stated without the distinction, leading to recurring friction (this session's `Carrier.Mutable` discussion; ecosystem inventory's witness-style classification work). Add a "When NOT to apply" section noting that pure capability protocols without noun-type backing should remain top-level rather than forced into a namespace.Protocol shell.
- [ ] **[research]** swift-institute/Research: write a tier-2 cross-package note "asymmetric-quadrant ergonomics as rejection criterion" capturing the recurring pattern (`@dynamicMemberLookup` rejected, KeyPath subscript rejected for ~Copyable, etc.). Cite the in-session experiments and the analogous decisions from carrier and mutator. This is currently re-derived from first principles every time it comes up.
- [ ] **[package]** swift-carrier-primitives: amend `Research/capability-lift-pattern.md` v1.1.0 §"Existing ecosystem instances" to include the newly-discovered `Affine.Discrete.Vector` adopter (from the ecosystem inventory at `swift-institute/Research/carrier-ecosystem-application-inventory.md`). Currently the doc lists 3; the inventory found 4.
