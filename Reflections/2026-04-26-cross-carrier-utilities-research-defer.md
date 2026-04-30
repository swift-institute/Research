---
date: 2026-04-26
session_objective: Resolve swift-carrier-primitives/HANDOFF.md (Cross-Carrier Utilities Research) — survey prior art, classify candidate utilities, recommend a ship-list (or codify defer)
packages:
  - swift-carrier-primitives
  - swift-institute/Research
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: no_action
    description: Carrier ad-hoc consolidation exception (one-time, principal-directed) — action items already landed via Skills/35dce3e and Research/2cc36be per Pass-Out 2026-04-30 against carrier-launch-skill-incorporation-backlog.md
---

# Cross-Carrier Utilities Research — defer-all + the [RES-018] precedent stack

## What Happened

Resumed `swift-carrier-primitives/HANDOFF.md` (sequential handoff,
authored same-day post-Carrier-integration). The handoff named the
investigation: *which cross-Carrier utilities (operations that work
generically across any `Carrier` conformer) should ship inside
`Carrier Primitives`*. The structural decision was already locked
(utilities live inside `Carrier Primitives`; methods on the protocol
via constraint extensions; file naming `Carrier where {clause}.swift`).
The content decision was the deliverable.

State verified before starting (per HANDOFF instruction):

- Working tree clean (only gitignored `Experiments/.../Outputs/` untracked).
- `capability-lift-pattern.md` at v1.3.0 RECOMMENDATION.
- Six integration commits present in tagged / cardinal / ordinal /
  affine / clock / property packages, matching the HANDOFF table.

Skills loaded in parallel: `swift-institute-core`, `swift-institute`,
`primitives`, `research-process`.

Per `[RES-019]`, internal corpus grep was the first move (before any
external survey). Hits: ~30 internal docs, ten of which load-bearing
— `capability-lift-pattern.md` v1.3.0, `carrier-vs-rawrepresentable-
comparative-analysis.md` (DECISION), `generic-consumer-across-
quadrants.md` (REFERENCE), `round-trip-semantics-noncopyable-
underlyings.md` (DECISION), `mutability-design-space.md` v1.1.0
(DECISION), `swift-institute/Research/operator-ergonomics-and-carrier-
migration.md`, `carrier-ecosystem-application-inventory.md`,
`decimal-carrier-integration.md`, the same-day
`Reflections/2026-04-26-carrier-integration-retrospective.md`, and
the Tier-3 `phantom-typed-value-wrappers-literature-study.md`
(2026-02-26). All read; cited rather than re-surveyed.

External prior-art survey per `[RES-021]` (parallel WebFetch +
WebSearch): Haskell `Data.Tagged` (`retag`, `untag`, `tagSelf`,
`asTaggedTypeOf`, `witness`, plus full numeric / `Eq` / `Show`
instances via `deriving newtype`); Edward Kmett's `lens`
`Control.Lens.Wrapped` (`_Wrapped`, `_Unwrapped` Iso forms); Rust
`derive_more` and `newtype_derive` (forwards Inner→Newtype, no
cross-newtype morphisms); Scala 3 opaque types (no automatic
forwarding, no documented cross-opaque-type morphism pattern); F#
units of measure (compile-time discrimination, no rebrand operation
by design); McBride 2002 "Faking it" (cited for type-equality
witnesses); Breitner et al. 2014 Coercible/roles (cited for what
Swift lacks). The Tier-3 literature study covered the foundational
academic citations.

Seven candidate utilities enumerated and classified along the four
HANDOFF axes (prior-art ≥2 ecosystems, Carrier-protocol-feasible,
quadrant coverage, Underlying constraint):

1. `describe` — universal prior art, all-quadrant feasible, no second
   consumer.
2. `reroot` — Haskell + lens prior art, blocked Q2/Q3/Q4 absent
   protocol extension (consume-extraction), Q1-only via copy.
3. `equate` — Haskell `Eq`-on-Tagged prior art, Q1-only, semantically
   suspect across phantom domains.
4. `project` — already documented as a Tier 1 REFERENCE sketch in
   `generic-consumer-across-quadrants.md`; the existing sketch is the
   right level of pre-commitment.
5–7. Conditional `Equatable`/`Hashable`/`CustomStringConvertible`
   conformances on Carrier — Q1-only, four compounding concerns
   (asymmetric-quadrant ergonomics, conformance shadowing,
   design-intent reversal per `carrier-vs-rawrepresentable` Dimension 5,
   ecosystem-wide blast radius).

Output document authored: `swift-carrier-primitives/Research/cross-
carrier-utilities.md` — 1142 lines, RECOMMENDATION, Tier 2,
package-specific. Recommendation: ship NONE; codify location decision;
defer all candidates per `[RES-018]`. Acceptance gate spelled out for
future per-candidate ship cycles (named consumer, quadrant story,
conformance-shadowing analysis, verification spike).

`Research/_index.json` updated per `[RES-003c]` (entry inserted between
`round-trip-semantics-noncopyable-underlyings` and `forums-review-
simulation-2026-04-24`); JSON validated.

**HANDOFF scan per [REFL-009]**: 1 file found
(`swift-carrier-primitives/HANDOFF.md`). Triage: all six Next Steps
verified complete via inline annotation; no `### Supervisor Ground
Rules` sub-heading present (standard sequential handoff); no pending
escalation. Disposition: deleted (gitignored at root by .gitignore;
work captured in `Research/cross-carrier-utilities.md` which IS
tracked). One file scanned, one annotated-then-deleted, zero
out-of-session-scope.

## What Worked and What Didn't

### What worked

The `[RES-019]` Step-0 internal grep was load-bearing. The Tier-3
`phantom-typed-value-wrappers-literature-study.md` (2026-02-26) had
already done a 36-paper SLR + 5-language comparative analysis covering
Reynolds 1983, Wadler 1989, Breitner et al. 2014, Leijen-Meijer 1999,
Hinze 2003, Cheney-Hinze 2003, Tov-Pucella 2011, Kennedy 1997/2010,
plus the Coercibility-Gap finding directly relevant to this document's
question. Skipping the grep would have meant re-deriving 40 years of
phantom-types theory. The grep took ~5 minutes and saved the equivalent
of half a session.

The HANDOFF anticipated the outcome correctly: *"Either a small
ship-list ... OR a 'codify the location, ship none until a real
consumer arrives' recommendation per [RES-018]"*. The author knew
[RES-018] would likely dominate but wanted the rigor of a documented
survey rather than an inference. This is the right framing — the
anticipation made my job easier (I knew the recommendation might land
either way and could let the evidence drive it).

The same-day precedent stack made the recommendation overwhelming.
Three "defer per [RES-018]" decisions in 7 days:

| Date | Decision | Same shape? |
|------|----------|-------------|
| 2026-04-25 | `swift-mutator-primitives` package DEFERRED | Yes — well-shaped, prior-art, no second consumer |
| 2026-04-26 | Decimal Phase 4 (Tagged refactor) CANCELLED | Yes — same shape |
| 2026-04-26 | Cross-Carrier utilities DEFERRED (this doc) | Yes — same shape |

The Mutator deferral is especially load-bearing: an entire package
was investigated, surveyed academically (Tier-2, 31 citations, 26
verified), and DEFERRED. If a whole package can't pass [RES-018], a
single utility method definitely can't.

Parallel tool dispatch worked well — the four foundational
carrier-primitives docs were read in one parallel batch (after the
Carrier protocol surface), and the external prior-art surveys
(Haskell, Rust, Scala, F#, McBride) ran as 5 parallel WebFetch +
WebSearch calls in a single message. Single round-trip for the
external survey instead of five sequential.

The HANDOFF format itself worked well. The `## Current State` section
explicitly named which decisions were "deliberately ahead" vs.
"awaiting content" — *"The structural decision is deliberately ahead
of the content decision — location is locked, content waits for the
research below."* This made my job much easier: I knew exactly which
decisions to preserve and which to derive. The pattern is worth
naming for future HANDOFFs.

### What didn't

First Hackage WebFetch returned a redirect notice (301 from
`hackage.haskell.org` to `hackage-content.haskell.org`) instead of
content; needed a second call with the redirect URL. Mechanical, but
counts against parallel-dispatch efficiency.

Noticed `Research/_index.json` has 3 pre-existing missing entries:
`dynamic-member-lookup-decision.md`, `forums-review-triage-2026-04-24.md`,
`mutability-design-space.md` — all present in `Research/` but not
indexed. Out of charter for this session; flagged in the close-out.
[RES-003c] violation, but pre-existing. The discovery of this
specifically because I read those docs while sourcing for the new
research suggests that *adding a new entry is the moment when the
index is most likely to be audited* — adding an audit-on-touch
discipline could surface drift earlier.

I told the user mid-session that I'd ask before deleting HANDOFF.md
("I'll wait for confirmation before touching either"). The user then
invoked `/reflect-session`, which authorized [REFL-009]'s MUST-delete
disposition. Briefly considered whether the prior reservation
overrode the skill protocol; resolved by reading the skill carefully
and concluding that invoking the skill IS the authorization for its
protocol. Worth flagging that "I'll wait for confirmation" said
*before* a skill invocation can be implicitly superseded by the
invocation; better to scope the reservation more narrowly.

## Patterns and Root Causes

### The [RES-018]-defer cluster is signal, not coincidence

Three same-shape decisions in 7 days. The ecosystem is *self-correcting
back to demand-driven*. The Carrier migration ran ahead of consumer
demand — `capability-lift-pattern.md` Recommendation #5 explicitly
warned about this risk in v1.0.0 ("driven by demand for Form-D generic
algorithms, not by a desire to factor for its own sake"), but the
migration shipped anyway. The deferral cluster is the consequence —
each adjacent expansion question (mutator, decimal, cross-Carrier
utilities) is now subject to the second-consumer hurdle that the
Carrier migration itself didn't quite clear.

The same-day carrier-integration retrospective (Suggestion #7) called
this out explicitly: *"have any cross-Carrier algorithms been written
post-migration? If demand is unrealized, the Carrier capability is
unused."* That document evaluates the *demand* side. This document
evaluates the *supply* side. The answer "ship none" is correct on the
supply side because the demand side is currently unrealized. When
demand materializes, the candidate list becomes a ranked ship-list —
the prior-art survey did the work for the eventual ship cycle.

This is a healthy pattern. The cluster shows the ecosystem is mature
in its application of [RES-018] — three rapid decisions in the same
direction is harder than it looks, because each decision must resist
the gravitational pull of "we already invested in the abstraction;
let's get value from it." The ecosystem is choosing to defer the
"value extraction" step until consumer evidence justifies it.

### "The sketch is the spec" framing is the right pre-commitment level

The `generic-consumer-across-quadrants.md` document (Tier 1 REFERENCE,
single-author, 90 lines) defines the canonical cross-Carrier utility
shape (`project`) and explicitly says *"When those land, this sketch
becomes the spec they satisfy; until then, it stands as the
operational proof that the abstraction pays rent."* This is exactly
the right pre-commitment level — it's neither too eager (no shipped
API) nor too defensive (no "we shouldn't think about this until a
consumer asks"). The sketch documents the shape so consumers can
recognize the moment when their use case fits it.

This is a transferable pattern. For abstractions that anticipate
demand but don't yet have it: Tier 1 REFERENCE sketch documenting
the shape is the right artifact. It's distinct from Tier 2/3
RECOMMENDATION (which would be a more committed design) and from
no documentation at all (which loses the shape).

### Internal-grep-before-external-survey is consistently load-bearing

Three sessions in the past two months show the same pattern:
- 2026-04-21 (property-primitives handoff): internal Research/
  corpus had stronger signal than external commentary; provenance
  for `[RES-019]`.
- 2026-04-26 (this session): the Tier-3 phantom-types literature
  study had already done the academic survey; cited rather than
  re-surveyed.
- Earlier sessions cited in `[RES-019]` provenance.

The skill rule exists; the habit has to be applied each time. The
cost of *not* doing the internal grep is multi-hour rework; the cost
of doing it is ~5 minutes. The asymmetry favors doing it always.
Worth reinforcing in the research-process skill if it's not already
there as a SHOULD/MUST gate.

### HANDOFF "decision-readiness" framing is reusable

The HANDOFF's Current-State section explicitly distinguished:
- Decisions locked (structural: location, naming, methods-on-protocol)
- Decisions awaiting content (which utilities to ship)

This made the resumption fast: I knew which decisions to preserve as
preconditions and which to derive from the research. Many HANDOFFs
don't explicitly call this out; the author trusts the reader to infer
it. Calling it out explicitly is small effort and large clarity-gain.
Worth proposing as a HANDOFF skill convention or template element.

## Action Items

- [ ] **[package]** swift-carrier-primitives: Sweep `Research/_index.json`
  for missing entries — `dynamic-member-lookup-decision.md`,
  `forums-review-triage-2026-04-24.md`, `mutability-design-space.md`
  are all present in `Research/` but not indexed. `[RES-003c]`
  violation; missing entries hide load-bearing research from consumers
  reading the index. ~5-min mechanical fix.
- [ ] **[research]** swift-carrier-primitives: Should `Carrier` add
  `consuming func unwrap() -> Underlying` (or equivalent
  consume-extraction surface) to enable Q2/Q3/Q4 `reroot`? Currently
  structurally blocked per `round-trip-semantics-noncopyable-
  underlyings.md`. Tier-2 investigation gated on the first concrete
  consumer with a `reroot`-shaped need. The cross-carrier-utilities.md
  document explicitly identifies this as a separate investigation.
- [ ] **[skill]** handoff: Add "Decision-readiness annotation" as a
  SHOULD-element in the HANDOFF template — when the handoff has
  decisions in mixed states (some locked, some awaiting derivation),
  the Current-State section should explicitly label which is which.
  Provenance: this session's HANDOFF used the pattern (in the
  Current-State section's last paragraph) and it materially
  accelerated resumption.
