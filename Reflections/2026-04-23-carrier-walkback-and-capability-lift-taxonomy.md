---
date: 2026-04-23
session_objective: Investigate self-projection default pattern, then Cardinal/Ordinal capability-lift pattern; converge on Group A/B taxonomy; plan tagged-primitives rename.
packages:
  - swift-primitives
  - swift-property-primitives
  - swift-identity-primitives
  - swift-cardinal-primitives
  - swift-ordinal-primitives
status: pending
---

# Carrier walk-back and capability-lift taxonomy convergence

## What Happened

Multi-part research session across two related meta-patterns on the
`*.\`Protocol\`` family in swift-primitives.

**Part 1 — self-projection default pattern**: per a branching handoff,
authored an experiment (six variants) and Research doc characterizing
the "protocol associatedtype defaults to `N<Self>`" pattern generalized
from the Borrow DECISION. Classified V0 Borrow baseline (FITS), V1
Mutate mirror (FITS), V2 Property two-param (DOES NOT FIT), V3
constraint-mismatch (REFUTED), V4 Hash no-sibling (DEGENERATE), V5
Memory.Contiguous element-axis (DOES NOT FIT). Stamped handoff
verification.

**Part 2 — user challenge**: user pushed back: *"so this is quite
useless then?"* Forced re-articulation of what the investigation
actually bought. Acknowledged that V4/V5 are confirmations of the
known negative cases, and the genuinely novel finding is the
structural vs semantic precondition distinction (V5).

**Part 3 — pivot to capability-lift**: user clarified their actual
interest was `Cardinal.\`Protocol\`` / `Ordinal.\`Protocol\`` + Tagged
forwarding for API broadening — a different pattern from self-
projection. Authored a new experiment (`capability-lift-pattern`, six
variants including V2 refinement, V3 SE-0346 parameterized Carrier,
V4 API broadening, V5 limits) and two research docs: one
characterization, one academic-foundations survey with verified
citations (Reynolds 1983, Wadler 1989, Hinze 2003, Cheney-Hinze 2003,
Yallop-White 2014, Atkey 2009, Cardelli-Wegner 1985, Wadler-Blott
1989, Leijen-Meijer 1999, Carette-Kiselyov-Shan).

**Part 4 — Tagged-is-canonical-Carrier framing**: user asked *"is
`Carrier<Underlying>` equivalent to a theoretical `Tagged<A, B>.\`Protocol\`\`\`"*.
Produced the deeper framing: Tagged is the free / canonical generic
implementation of Carrier — same relationship as Array → Sequence.
Strict answer: no (bare value types wedge); spiritual answer: yes.

**Part 5 — consolidation probe**: user asked whether Property and
Tagged should share `swift-phantom-primitives`. Rejected on naming
convention ([PRIM-NAME-003] mechanism-not-technique).

**Part 6 — existing research**: user pointed at
`property-tagged-semantic-roles.md` — the canonical Group A / Group B
taxonomy already exists from a prior session. Read it; connected to
my capability-lift work (Group A admits super-protocol in principle;
Group B does not, because its Tags are container-local).

**Part 7 — Carrier package question + walk-back**: user asked whether
to create `swift-carrier-primitives` and rename
`swift-identity-primitives` → `swift-tagged-primitives`. Walked back
the Carrier proposal on three grounds: (1) single-protocol package
violates per-canonical-type convention; (2) recursive Tagged
composition doesn't compose with refinement protocols like
`Ordinal.\`Protocol\`` (Swift overlap rules); (3) no demonstrated use
case. Confirmed the rename is correct.

**Part 8 — plan + execute**: authored a four-phase plan; user
authorized with "do as you advise"; in-chat executed Phase 1 doc
hygiene (5 files: `property-tagged-semantic-roles.md` v1.1.0,
`capability-lift-pattern.md` v1.2.0, `capability-lift-pattern-academic-foundations.md` v1.1.0,
Tagged-side DocC `Phantom-Tag-Semantics.md`, both READMEs). Authored
Phase 2 rename handoff `HANDOFF-tagged-primitives-rename.md` with
supervisor ground-rules block + sequencing constraint (gated on
Borrow cascade Phase 9).

**Part 9 — context disturbance**: mid-session, untracked files I
created earlier (self-projection-default-pattern.md, both experiment
packages) were wiped from disk. `.git` directory also removed from
swift-primitives. Detected only when attempting Phase 1b edit failed
with "file does not exist." Recovered capability-lift docs from
current context (full text available); accepted loss of self-
projection-default work per user direction.

**Handoff triage (per [REFL-009])**:

- `HANDOFF-self-projection-default-pattern.md` — all constraints and
  acceptance criteria verification-stamped mid-session; Findings
  section complete. Per standard rule, delete. However, the
  verification line was authored when artifacts existed on disk; the
  underlying artifacts were subsequently wiped (out of this
  subordinate's control). Work was *authored complete*; I'll annotate
  with a note about the artifact loss rather than silently delete —
  the verification statements are no longer true-at-present for
  criteria #2, #3, and #6.
- `HANDOFF-tagged-primitives-rename.md` — written this session; work
  not yet dispatched (gated on Borrow cascade Phase 9). Leave in
  place per triage table.
- All other `HANDOFF-*.md` at `/Users/coen/Developer/` root — out of
  this session's authority; no scan.

## What Worked and What Didn't

**Worked**:
- Academic-foundations doc with verified WebSearch citations — 11
  primary sources confirmed against DOI/URL/author/year before
  committing to the text. Applied `feedback_verify_cited_sources`
  discipline mechanically.
- Walk-back once Problem 2 (recursive Tagged conformance
  non-composition) surfaced — didn't defend the original Carrier
  pitch after identifying the structural blocker. The response
  explicitly apologized for the earlier over-pushing.
- Cross-referencing the three research docs (this session's + the
  pre-existing property-tagged-semantic-roles) into a coherent family
  with bidirectional pointers.
- Leveraging existing research — `property-tagged-semantic-roles.md`
  was already comprehensive; connecting to it rather than
  re-deriving saved substantial work and produced a complementary
  finding (Group A's "Swift-expressiveness-blocked" + Group B's
  "categorically-blocked" give a unified taxonomy).

**Didn't work**:
- **Initial Carrier pitch oversold.** I framed the super-protocol as
  a clean win for multiple turns before the user's question ("should
  we actually do this?") forced me to confront the recursive-Tagged
  composition problem. The problem was implicit in my experiment's
  V5 limits from the start, but I didn't connect it to "this breaks
  the universal Carrier conformance." This is the
  `feedback_no_sendable_constraint_workaround` failure mode applied
  to a super-protocol proposal: I reached for an abstraction before
  verifying it composes.
- **Mid-session file disappearance went undetected until edit
  failure.** No periodic "files still on disk?" check between phases.
  The user had also modified some state (date change + Borrow status
  update) which suggested external session activity in the gap —
  could have flagged earlier.
- **Action-item quality on Carrier walk-back was slow.** When the
  user pushed back with "so this is quite useless then?", my first
  response was defensive hedging before I arrived at the real
  admission. The useful answer ("yes, I oversold — here's what's
  genuinely new vs confirmatory") came only after the user's
  follow-up about their actual use case.

## Patterns and Root Causes

**Pattern 1 — Academic framing is necessary but not sufficient for
language-specific design**. The Carrier proposal was categorically
clean (free-Carrier adjunction, fibration structure, parametricity
justification — all correctly grounded in cited literature). It
failed on a distinctly Swift concern: overlapping conditional
conformances are forbidden, and the universal "Tagged is a Carrier"
extension would need recursive-via-Carrier extensions that conflict
with per-Underlying extensions. The academic framing didn't surface
this because academic literature on phantom types / type classes /
free constructions doesn't centrally discuss instance-overlap
semantics (Haskell's `OverlappingInstances` is a language extension
warned about in the literature, not a central concern).

The rule that should stick: **when proposing a super-protocol or
cross-type abstraction in Swift, the gating question is "does this
require overlapping conditional conformances to express fully?"** If
yes, the abstraction is incomplete in Swift regardless of its
theoretical beauty. This gates before academic justification is
written up, not after user pushback.

**Pattern 2 — Session writes are not durable until committed; no
check fires on this.** Untracked files disappearing mid-session is a
real failure mode that this session encountered explicitly. The
[REFL-006] re-grep-after-edit discipline is for edits; the analogous
discipline for writes is "verify the file is still on disk before
referencing it in a later phase." The absence of this check let the
index entries and file state diverge silently.

Root cause common to both patterns: **verification at boundaries is
the load-bearing mechanism**. Pattern 1's fix is verifying
Swift-expressiveness before recommending an abstraction. Pattern 2's
fix is verifying file persistence before continuing to the next
phase. Both are "check before building further on top" disciplines
that were not systematic in this session.

**Secondary observation — the user-as-principal model worked well in
the walk-back phase**. The user's direct question "should we do this?"
was a legitimate class-(c) escalation per `/supervise`'s rules
(revisit an architectural commitment). Treating it as a real question
rather than a prompt to re-defend produced the walk-back. The
re-handoff (Phase 2 rename) then carried this correctly in its
ground-rules block: "MUST NOT introduce Carrier — deferred per
capability-lift-pattern.md v1.2.0 R2."

## Action Items

- [ ] **[skill]** implementation: Add a requirement (new ID in
  `[IMPL-*]` space, around API-LAYER or PATTERN) — *when proposing a
  super-protocol, abstract interface, or cross-type conformance
  scheme, verify it does not require overlapping conditional
  conformances to express fully. If yes, document the limitation
  before recommending.* Applies during [API-DESIGN] / [API-LAYER]
  review. Prevents academically-clean-but-Swift-incomplete proposals
  from reaching recommendation status.

- [ ] **[skill]** reflect-session: Add a "verify untracked session
  writes persist" check to [REFL-009] or adjacent procedure — at
  phase boundaries (or before referencing earlier-written untracked
  files in later phases), `ls` or otherwise confirm the file still
  exists. Catches mid-session disturbances (git clean, external
  wipe, restart) that would otherwise produce silent state
  divergence. Addresses this session's file-disappearance failure.

- [ ] **[blog]** *"Two kinds of phantom types: domain-identity vs
  verb-namespace"* — already flagged as Low-priority blog candidate
  in `property-tagged-semantic-roles.md` R6 (v1.1.0 promoted to
  Medium). This session's capability-lift work adds complementary
  evidence: Group A's "structural composition limit in Swift" pairs
  with Group B's "categorically-blocked" to give a unified explanation
  of why both patterns stay separate. Worth the Swift Institute blog.
