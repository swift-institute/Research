---
date: 2026-05-08
session_objective: Research-mode investigations on Array.Bounded.Index = Algebra.Z<N> binding and Algebra.Field<Bit> witness placement
packages:
  - swift-array-primitives
  - swift-algebra-modular-primitives
  - swift-bit-primitives
  - swift-finite-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: SkillUpdate [RES-029] Framing-Challenge for Binding/Membership/Placement Questions (entry 4 AI 1; semantic identity FIRST, cost as tiebreaker; v1.0.0 to v2.0.0 reframe worked example). NoAction [MOD-NNN] witness-placement principle deferred (small-scope amendment, candidate for follow-up). Carrier-extension vs kind-extension standardization research deferred.
---

# Binding-vs-Placement Research Arc — Cost-Axis vs Semantic-Identity Framing

## What Happened

Three sequential dispatches in one session, all using the same methodology pattern (ecosystem-pattern-driven, operational-evidence-first), but on adjacent questions:

**Dispatch 1a (v1.0.0 ANALYSIS)** — Re-examine `Array.Bounded.Index = Algebra.Z<N>` under the data-structure-package public-launch axis. Framing: rank three options (status quo / retreat / hybrid target split) on publish-cost vs canonical-cohesion axes. Output: 248-line ANALYSIS doc with comparison table + recommendation deferred to orchestrator (decision conditional on cyclic + numeric maximal-algebra-refactor adoption schedule).

**Dispatch 1b (v2.0.0 DECISION)** — Orchestrator reframed: "Pragmatism is downstream of truth — if it IS-A, we pay the cost; if it's NOT, the retreat is principled regardless of publish chain." Reframe rejected the cost-vs-cohesion ranking as backwards; the actual question is semantic identity. Output: 220-line DECISION doc, verdict NOT-A. Eight operational evidence sources (`Array<E>.Index = Index<Element>` linear, `Array.Protocol: Collection.Bidirectional` linear contract, sibling Array variants `successor.saturating()` / `predecessor.exact()`, `Queue.Index = Index<Element>` (the actual ring buffer rejected modular indices, hiding cyclic semantics inside Buffer.Ring), `cyclic-primitives` doesn't bind to `Algebra.Z<N>` either, plus the v1.0.0 use-count evidence subordinated). The current binding is a category error: kind-extension witness on a non-algebra-internal carrier where the kind's algebra surface (modular wraparound) actively contradicts `Collection.Bidirectional`'s linear-bidirectional contract. Retreat is corrective; publish-chain reduction is consequence not motivation.

**Dispatch 2 (Bit-Field Witness Home)** — Same methodology applied to "where should `Algebra.Field<Bit>` live?". Surveyed 11 witness sites across the ecosystem (`grep -rln Algebra.{Field|Group|Ring|Module|Monoid|Semiring}`). Identified two orthogonal axes: (1) carrier ownership (algebra-internal vs non-algebra-internal) and (2) granularity within carrier home (main target / subtarget / separate algebra-X package, by Core minimality). Verdict: (A) Stay. Current `Bit Field Primitives` subtarget in bit-primitives matches ecosystem pattern (kind-extension shape on non-algebra-internal carrier; 11/11 carrier-home sites; bit-primitives Core's zero-dep posture per [MOD-001] is what makes subtarget the right granularity). Section appended inline (133 lines) to the same doc as v2.0.0 — preserved the arc.

**Implementing dispatch landed during this session** — `swift-array-primitives/Package.swift` was modified mid-session (visible via system-reminder near the end): `swift-algebra-modular-primitives` swapped for `swift-finite-primitives`; `Array Bounded Primitives` target now imports `Finite Primitives Core` instead of `Algebra Modular Primitives`. This validates the v2.0.0 verdict was actionable; the retreat to thinner bounded-linear-index is in flight.

**HANDOFF scan**: 47 `HANDOFF-*.md` files found at workspace root + 8 in `swift-institute/`; all out-of-session-scope (none written, worked, or with closure signals encountered in session context). No triage performed. No audit findings to update (no `/audit` invocation this session).

## What Worked and What Didn't

**Worked**:

- The v2.0.0 reframe produced a clean DECISION where v1.0.0's cost-axis ranking produced ANALYSIS-pending. The reframe wasn't a different perspective on the same question; it was a structurally better question. Operational evidence (Queue.Index linear, cyclic-primitives doesn't bind, sibling variants saturate) was uniformly dispositive once the question shifted to "is the binding right?".
- Skill loading (research-process, swift-institute-core, modularization, ecosystem-data-structures) was load-bearing — citation discipline used [RES-018], [RES-022], [RES-023], [RES-027], [MOD-001], [MOD-002], [MOD-006], [MOD-DOMAIN], [MOD-RENT], [DS-003], [DS-020] throughout, none invented. The early decision to load research-process + modularization was the right move; ecosystem-data-structures was lighter-weight than expected (a few rule cites).
- Three-iteration doc arc preserved coherence by editing in place rather than authoring parallel docs. v1.0.0 (248 lines) → v2.0.0 (220 lines, superseded inline) → +Bit-Field section (133 lines, total 356). All within constraint caps. The Changelog convention captured the arc's history without bloating the active text.
- Index-entry maintenance ([RES-003c]) tracked the doc's evolution — initial entry, status DECISION update, appended-section note in statusDetail. JSON parsed clean each round.
- Ecosystem-survey methodology (Dispatch 2) successfully extracted an implicit pattern that was unwritten across 11 sites. The two-axis structure (carrier ownership × granularity) wasn't given to me; it emerged from systematic enumeration. Future witness-placement questions can reference this surfacing.

**Didn't work as well**:

- Dispatch 1a defaulted to the dispatcher's framing (rank cost-vs-cohesion). The framing was the wrong shape for the underlying question, and I produced a dutiful ANALYSIS that satisfied the framing but didn't reach a decision. The orchestrator's reframe was needed to produce the answer. I should have flagged the framing issue upfront — "if the underlying question is whether the binding is correct, ranking on cost vs cohesion presupposes that both are valid; let me drive on semantic identity first" — instead of accepting the framing.
- v1.0.0's evidence selection was correct but ranked wrong. Use-site count, dependency chain, RECOMMENDATION-not-IMPLEMENTED status of cyclic + numeric refactors — all true, all secondary. The v2.0.0 evidence (operational behavior of adjacent types) was always available; v1.0.0 just didn't ask "what does Queue do?" because the cost-axis framing didn't surface that question.
- Mid-session attention to system-reminder noise was acceptable but not optimal — a few "task tools haven't been used recently" reminders fired without my needing tasks. I correctly ignored them per the standing instruction not to mention the reminder, but they did add cognitive load.

## Patterns and Root Causes

**Pattern 1: Cost-axis framing is a research anti-pattern when the underlying question is binding or placement.** When a dispatcher frames "rank options on axis X vs Y," the dispatcher has already decided that ranking is the right operation. But if the underlying question is "is this binding correct?" or "where does this concept belong?", ranking presupposes that all options are semantically valid — it skips the prior question. The 1a→1b cycle was one full dispatch round-trip on this gap. Future dispatches: when the framing is "rank options," explicitly check whether the underlying question is binding/membership/placement; if yes, drive on semantic identity first and treat ranking-on-cost as a tiebreaker only AFTER the semantic question resolves to multiple-still-valid options.

**Pattern 2: Operational behavior of adjacent types is more dispositive than use-site counts for IS-A questions.** v1.0.0 cited use-site counts (Array.Bounded uses zero of Algebra.Z<N>'s arithmetic surface; algebra-modular's only non-algebra consumer is Array.Bounded.Index). True and useful but secondary — the use-count evidence is consistent with both IS-A (canonical cohesion not yet realized) and NOT-A (binding is wrong). v2.0.0 cited operational evidence (Queue.Index linear, cyclic-primitives doesn't bind to Algebra.Z<N>, sibling Array variants saturate) which was uniformly NOT-A. The lesson: for "is X an instance of Y?" questions, what do *adjacent* types do? If Y has multiple adjacent instances and they all use Z (not Y), that's stronger than counting use-sites of Y in the candidate.

**Pattern 3: Ecosystem-survey methodology for placement questions.** Dispatch 2 surfaced an implicit two-axis pattern that was consistent across 11 sites. The methodology: enumerate every existing site of the same kind, classify each on candidate axes, see which axes produce uniform groupings. Two axes emerged (carrier ownership; granularity-by-Core-cleanliness) that explained 11/11 placements. The pattern wasn't documented anywhere — it lived in the cumulative authoring decisions. Generalization: when the ecosystem has multiple existing sites of the same kind of decision, the implicit pattern is recoverable by enumeration. The cost is one `grep` and a small classification table.

**Root cause: The research-process skill currently codifies "investigate options" but not "challenge framing."** [RES-001], [RES-004], [RES-005] cover option enumeration and trade-off analysis. [RES-022] codifies "structural correctness over diff-size" but as a tiebreaker among already-chosen options, not as a framing-level rule. There is no existing rule that says "if the dispatch frames a binding/placement question as a ranking, challenge the framing first." The 1a→1b round-trip is the cost of that gap. Adding a framing-challenge rule to research-process would convert this experience into a durable skill update.

**Cross-pattern observation**: Both Dispatch 1 (binding) and Dispatch 2 (placement) used the same evidence shape — "what do adjacent types/sites do?" — and reached clean verdicts when that question was central. The difference: Dispatch 1 needed orchestrator reframing to ask the question; Dispatch 2 used the question by default because the dispatch was framed as "where should X live?" already. The framing of the dispatch determines whether the right evidence shape is reached on the first pass.

## Action Items

- [ ] **[skill]** research-process: Codify framing-challenge rule for binding/membership/placement questions. New requirement (proposed slot near [RES-022]): "When a research dispatch frames a question as 'rank options on axis X vs axis Y' AND the underlying entity is an instance/binding/placement question (IS-A, NOT-A, where-does-it-live), the research MUST drive on semantic identity first; cost/pragmatism is a tiebreaker only AFTER multiple options remain semantically valid. Additionally, for IS-A evidence: operational behavior of adjacent ecosystem types ranks higher than use-site counts in the candidate site itself, because use-site counts can be artificially zero from type-availability bindings while operational consensus is dispositive." Provenance: this session's 1a→1b round-trip.

- [ ] **[skill]** modularization: Codify the witness-placement principle from the Bit-Field section as a new [MOD-*] requirement. Two axes: (1) carrier ownership — algebra-internal carriers → kind home; non-algebra-internal carriers → carrier home, never kind home; (2) granularity within carrier home — main target if main already imports the kind, subtarget if Core is dep-free, separate algebra-X sibling package if carrier's Package.swift wants resolved-graph cleanliness. 11 ecosystem sites of evidence verified 2026-05-08. Implicit pattern → explicit rule. Provenance: `array-bounded-index-revisit-2026-05-08.md` "Bit-Field Witness Home" section.

- [ ] **[research]** swift-institute/Research/: Should the ecosystem standardize one extension shape (carrier-extension `Cardinal.monoid` vs kind-extension `Algebra.Field<Bit>.z2`) for concrete witnesses on non-algebra-internal carriers? Currently 5 carrier-extension sites (Cardinal, Affine.Discrete.Vector, Phase, Rotation, Shear, Sample.Accumulator) + 6 kind-extension sites (Bit, Bound, Boundary, Endpoint, Gradient — and arguably some others) coexist. The shape cascades into placement viability (carrier-extension pairs naturally with separate algebra-X package or carrier-main-target; kind-extension pairs with carrier-subtarget or carrier-main-target). Whether the split is structural (different shapes for different concept categories) or accidental (authoring-time variance) determines whether a standardization pass is warranted. Flagged in the Bit-Field section as out of scope for that decision but worth a dedicated research pass.
