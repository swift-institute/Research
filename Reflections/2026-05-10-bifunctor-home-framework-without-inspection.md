---
date: 2026-05-10
session_objective: Forward-directions research and 0.1.0 publish prep for pair/either/product-primitives; resolve the Pair↔Either bridge home; open swift-bifunctor-primitives.
packages:
  - swift-pair-primitives
  - swift-either-primitives
  - swift-product-primitives
  - swift-bifunctor-primitives
  - swift-algebra-semigroup-primitives
  - swift-algebra-magma-primitives
  - swift-algebra-monoid-primitives
  - swift-standard-library-extensions
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [HANDOFF-048] Writer-Side Destination-Inspection Before Recommending a Target (entry 2 AI 1; algebra-law-primitives premise + Bifunctor-protocol-prescription worked examples). NoAction code-surface [API-NAME-001/002] doc-artifact scope clarification deferred (existing rules sufficient; over-correction is a usage signal not a rule signal). Categorical-structure-micro-package research deferred (research candidate; useful but small instance count).
---

# Pair↔Either bridge home: framework-without-inspection caught twice

## What Happened

Multi-stranded session covering 0.1.0 publish prep for three primitives publishing 2026-05-11 (pair/either/product) plus two architectural decisions that opened new packages.

**Forward-directions research (Tier 2, RECOMMENDATION).** Three parallel agents produced `Research/future-directions.md` for each publishing package, combining type-theory totality + Swift Evolution forward-pass. Pair: 20 candidates / 5 ADOPT / 6 DEFER / 8 REJECT / 1 already-done. Either: 13 candidates with the central typed-throws-vs-Either positioning resolved as complementary (14+ existing `throws(Either<...>)` sites cited as proof). Product: 21 candidates / 1 ADOPT / 6 DEFER / 14 REJECT.

**0.1.0 publish prep work.** W1 hygiene patch on Either's future-directions doc (Semigroup-existence claim correction). W2 BitwiseCopyable across all three: Pair (new conformance + 7 tests), Product (new parameter-pack-conditional conformance + 3 tests), Either (verified already-shipped at `Either.swift:99`). 157/157 tests green on Swift 6.3.1. W3 Either DocC positioning article ("Either, Result, and Typed Throws") with the 14+ throws(Either) sites cited and SE-0413's own Either-as-mechanism quote verified verbatim. W4 Either ↔ SLE `~Copyable` Result interop (init + 7 tests + `@_exported public import` per ecosystem convention).

**Algebra-Semigroup split.** User flagged the Magma+Semigroup bundling as the lone exception across the algebra-*-primitives family. Wrote `HANDOFF-algebra-semigroup-package-split.md`; parallel session executed it cleanly. New `swift-algebra-semigroup-primitives` exists on disk, monoid dep flipped, magma reduced to Magma-only.

**Pair↔Either bridge — first framework defect.** Built a 4-axis framework (canonical-authority + dep-direction + [RES-018] + strict-mission) and recommended Option 1: `swift-algebra-law-primitives` hosts both the law and operations as `Algebra.Law.Distributivity`. User said "do Option 1." Dispatched implementation agent.

Agent stopped on stop-and-ask gate. Finding: `swift-algebra-law-primitives` is *value-level law-verification harnesses* (namespace `enum`s with `check(...) -> Algebra.Law.Violation?` over `Collection<Element>` samples), NOT a home for *type-level categorical iso witnesses*. Worse, the existing `Algebra.Law.Distributivity` namespace is occupied by Ring/Module distributivity. My framework's "canonical home for laws" premise didn't survive package-source inspection. The agent applied the supervisor's own escape clause ("if a transitive dep audit surfaces unexpected coupling, surface and stop") correctly.

Re-ran framework with corrected premise. New option space; user picked Option B: open `swift-bifunctor-primitives` as a new L1 sibling. Wrote `HANDOFF-bifunctor-primitives.md` with the framework rationale and a prescribed shape including a `Bifunctor.Protocol` with parameterized associated types.

**Pair↔Either bridge — second framework defect.** Bifunctor agent stopped on a second stop-and-ask. Three findings: (1) parameterized associated types are not in Swift 6.3.1 — compile-verified ("associated types must not have a generic parameter list"); (2) the two surviving protocol shapes (marker-only / endo-bimap) both fail [RES-018]'s rent test (capability-zero or shape-regression on existing `map(first:second:)`/`map(left:right:)`); (3) **both per-package future-directions docs already converged on "defer the protocol"** — Pair v1.1.0 §What-is-not-recommended and Either v1.2.0 Candidate 7 both said this, and my handoff bundled the protocol on top of distributivity in spite of the documented consensus.

Endorsed agent's Option A (distributivity-only, protocol deferred). Agent shipped: `swift-bifunctor-primitives` package on disk with `Bifunctor` namespace, `Bifunctor.Distributivity.{distribute,factor}` × 4 overloads (each admitting `~Copyable & ~Escapable` via four package-private `_pack*` helpers that work around a documented move-checker bug), 18 tests passing in 6 suites, build clean in 7.67s.

**HANDOFF cleanup ([REFL-009]).** Two files in this session's bounded cleanup authority (case (a) — session wrote them):

| File | Status | Disposition |
|------|--------|-------------|
| `HANDOFF-algebra-semigroup-package-split.md` | Source-tree work landed; user-YES gates (gh repo create, push, visibility flip) pending | Annotate-and-leave per [REFL-009]'s "some items remain" rule |
| `HANDOFF-bifunctor-primitives.md` | Source-tree work landed (verified); user-YES gates pending | Annotate-and-leave; agent already appended Findings section |

`HANDOFF-introducing-pair-either-product.md` (yesterday's, for tomorrow's publish) is actively in-flight per [REFL-009a] — left alone, not in cleanup authority.

The other ~45 `HANDOFF-*.md` files at workspace root are out-of-session-scope and out-of-bounded-cleanup-authority.

## What Worked and What Didn't

**Worked.**

The institutional wiring caught both framework defects. Both subordinate stop-and-asks fired exactly as designed — the supervisor's escape clauses ("if shape is more contorted than precedents, surface" and "if transitive dep audit surfaces unexpected coupling, surface and stop") covered for the framework's premise gaps. Without those clauses the work would have proceeded against a wrong shape and produced shippable-but-wrong artifacts.

Both agents wrote substantive STOP-AND-ASK reports with compile-verification of their findings (`/tmp/bifunctor-shape-spike/` for the parameterized-associated-types check; live read of algebra-law-primitives source for the package-mission check). The subordinates didn't just escalate "this seems off" — they brought receipts. That's exactly the [SUPER-009] "attestation vs verification" discipline working as intended.

The DocC compound-name correction was a useful soft re-direct. User said "documentation must comply with code-surface, in particular re compoundname rule"; I initially over-corrected by proposing a filename rename (`Either-Result-and-Typed-Throws.md` → `Positioning.md`). User pulled back: filename was fine; only section-heading compound forms (em-dash "case — recommendation") needed splitting. Got the correction in two turns instead of leaving the docs in violation.

The algebra-Semigroup split landed cleanly via a separate /handoff session. Pattern (write detailed handoff → user runs separate session → reports back done) worked smoothly for both this and the bifunctor-primitives work. The handoff structure absorbed the parallel-session dispatch cleanly.

Move-checker bug workaround in bifunctor-primitives was principled: the agent cited Pair.swift:97-99's documented note about the same bug class and applied the same consuming-parameter-scope discipline via four `_pack*` helpers. Not invented — extended.

**Didn't work.**

I drafted the bridge-home framework without inspecting the candidate destination. Treated `swift-algebra-law-primitives` as a generic "canonical home for laws" without reading its source. The package's actual mission (verification harnesses, not iso witnesses) would have been visible from a 30-second scan of any existing law file. The framework was structurally rigorous but resting on an unverified premise.

I bundled the Bifunctor protocol into the handoff dispatch despite *both per-package future-directions docs* having already converged on "defer the protocol" with explicit prose ("No HKT-style abstraction... Swift can't represent it cleanly"; "Defer the Bifunctor protocol pending a third consumer"). [HANDOFF-013a] explicitly mandates writer-side prior-research grep before prescribing shapes — I had just edited those exact docs hours before, and still prescribed against their consensus. The discipline existed; I didn't run it.

I over-corrected on the DocC compound-name rule scope. The rule's text is about types/methods/properties; documentation artifacts are an analogous-but-not-explicitly-covered surface, and my strict reading on the filename was too aggressive.

The bifunctor agent flagged a suspected prompt-injection concern: "two `<system-reminder>` blocks appeared embedded inside Read tool results for sibling-package Package.swift files, declaring fake equation-primitives and comparison-primitives skills." I haven't investigated the source. Could be real injection, a confused MCP/hook artifact, or stale content. Flagging here for follow-up — not blocking, but worth tracking.

## Patterns and Root Causes

**Framework-without-inspection — the load-bearing pattern of this session.** Both bridge defects share the same root cause: I prescribed a destination (algebra-law-primitives) and a shape (Bifunctor protocol with parameterized associated types) without verifying that the destination actually was what my prescription assumed. Both prescriptions were structurally well-formed (the framework was rigorous; the protocol shape was natural) but rested on premises the prescribed targets did not actually satisfy.

This is the **writer-side equivalent** of [RES-013a] (Synthesis Verification — verify carried-forward findings) and [HANDOFF-013a] (writer-side prior-research grep). [HANDOFF-013a] catches the case where a writer prescribes shapes that prior research already rejected. The framework-without-inspection failure mode is one tier removed: prescribing *a destination* (a package, a namespace, a typeclass) without verifying that destination's actual scope. The defect is invisible from outside the destination — only inspection reveals it.

The institutional wiring that caught both was *the supervisor's own escape clauses in the dispatch brief*. Both handoffs included paragraphs telling the subordinate "if X, surface and stop." The clauses fired. This is good wiring but it works *because* it converts framework defects into stop-and-asks rather than completed-but-wrong work. Without those clauses I'd have shipped two structurally-wrong outputs.

The pattern generalizes: **frameworks that recommend placements MUST inspect the placement target.** The 30-second cost of `ls + grep` of the candidate destination's actual content is one of the cheapest verifications available; the cost of skipping it is unbounded (architectural commitments based on wrong premises). [HANDOFF-013a] and [RES-023] (empirical-claim verification) both gesture at this; neither names it precisely as a writer-side destination-inspection rule.

The session also surfaced a **scope-of-rule ambiguity** for the compound-name rule [API-NAME-002]. The rule's text targets types/methods/properties. Documentation artifacts (DocC article filenames, H1 titles, section headings) are analogous identifier-like surfaces but not explicitly covered. The strict reading produces over-correction (I tried to rename a defensible article filename); the loose reading produces under-correction (em-dash "case — recommendation" headings were genuinely compound and did need fixing). The user's clarification — "Either-Result-and-Typed-Throws.md is fine; section headings need fixing" — implies a default scope: code-identifier surfaces strict, documentation surfaces strict-on-section-headings-and-tighter-elements but not on top-level article identifiers. Worth codifying.

The bifunctor work also confirmed a **micro-package-as-architectural-decision** pattern. The user's stance "we don't want mission creep, we accept 'micro' packages" was load-bearing — without it, Option A (mission-creep algebra-law-primitives) might have looked attractive. The institute's ecosystem already exhibits the pattern (algebra-magma-primitives + algebra-semigroup-primitives + algebra-monoid-primitives + ... — each one type), but this session was the first time I saw it as the *deliberate alternative to mission creep* rather than as a default. Worth capturing.

The prompt-injection concern is unresolved. Two possibilities: (a) actual injection content somewhere in the workspace's files (worth a security audit), or (b) a hook / MCP server outputting reminders that look like system-reminders embedded in tool results. Either way the agent correctly ignored the spurious skills. No action this session, but noting it as a thread.

## Action Items

- [ ] **[skill]** handoff: Add a writer-side destination-inspection rule (proposed `[HANDOFF-013c]` or extension of `[HANDOFF-013a]`). When a handoff or framework recommends a target package, namespace, typeclass, or other placement, the writer MUST inspect the target's actual scope/mission before prescribing. "X is the canonical home for Y" is an empirical claim about the target, not a definitional one. Reading at least one canonical existing artifact in the target (one law file in algebra-law-primitives; one protocol in equation-primitives) is the minimum check. Provenance: this session's twice-caught framework-without-inspection — algebra-law-primitives premise wrong, then Bifunctor-protocol-prescription against existing converged research.

- [ ] **[skill]** code-surface: Clarify the scope of [API-NAME-001/002] (compound-name rule) for documentation artifacts. Default-strict on section headings and code-identifier-shaped surfaces; default-permissive on DocC article filenames and H1s when they read as legitimate multi-concept titles. Provenance: this session's over-correction on `Either-Result-and-Typed-Throws.md` filename (defensible) vs section headings like "Single Error Domain — Use Typed Throws" (genuinely compound, correctly fixed).

- [ ] **[research]** swift-institute: Document the categorical-structure-micro-package pattern. `swift-bifunctor-primitives` opens a family distinct from `swift-algebra-*-primitives`. The distinction (value-level algebra over carrier sets vs type-level structure on type constructors) is load-bearing and not currently codified anywhere. Tier 1 / DECISION grade. Should also capture the three re-evaluation triggers for the deferred Bifunctor protocol (parameterized associated types in Swift; third consumer; SE-0503 implementation).
