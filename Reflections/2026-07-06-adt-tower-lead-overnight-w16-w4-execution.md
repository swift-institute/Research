---
date: 2026-07-06
session_objective: ADT Tower lead seat — Phase 3 adversarial validation of adt-tower.md, then supervised execution of waves W1.6→W4-code via in-chat subagents, closed by seat succession
packages:
  - swift-buffer-ring-primitives
  - swift-buffer-slab-primitives
  - swift-buffer-linked-primitives
  - swift-queue-primitives
  - swift-deque-primitives
  - swift-slab-primitives
  - swift-tree-keyed-primitives
  - swift-list-linked-primitives
  - swift-ownership-shared-primitives
  - swift-kernel
  - swift-async
  - swift-io
  - swift-json
status: pending
---

# ADT Tower Lead — Overnight W1.6→W4 Execution, Six STOPs, Five Parks, One Succession

## What Happened

One seat session ran the ADT tower program from Phase 3 (adversarial end-to-end read of
`Research/adt-tower.md`, none of it self-authored) through closing waves W1.6, W1.7, W1.8
(30-package ownership re-home + the F3(c) `swift-ownership-shared-primitives` rename), W1.9,
W2 (eight-family fan-out + the first non-vacuous lint gate of the arc), W3 (buffer-tier op
generalization, the `.Small` doors, `Slab<E>.Inline<n>`), and W4's code leg (§9.6 deletions +
the MOD-032 zero-cycle receipt). Execution moved mid-session from planned fresh-session
subordinates to in-chat subagents (principal-directed), with the seat sample-verifying every
evidence bundle and performing all FF merges (the harness denies subagents `git merge` — the
denial preserved author≠verifier as a structural property). Census ended 15 at-target /
0 carrier-only / 2 deliberate-legacy / 5 n-a; the carrier-only bucket emptied for the first
time. Nothing was pushed; no repo flipped; two foreign uncommitted diffs were banked verbatim
as patches before reconciliation. Six executor STOPs were adjudicated; five became parked
principal items (P1 linked bounded twin, P2 slots two-lane form, P3 pool-path allocation,
P4 keyed-error name, P5 inline-door op surface). The W2 lint gate turned out to be a
four-deep consumer domino (async→kernel→witnesses→io+json), all discharged. One real runtime
finding surfaced: io's driver-contract test SIGSEGVs in DEBUG inside `__Dictionary.insert`
(frames extracted, reducer parked, docketed). The session ended with a seat-succession
handoff (`Workspace/handoffs/HANDOFF-adt-tower-seat-succession.md`, committed) delegating the
docket adjudication + W4 residuals + W5 to a fresh session.

## What Worked and What Didn't

**Worked.** (1) Verbatim-doc-quoting dispatches plus an absolute STOP discipline: every
subordinate that hit a fork the document didn't decide STOPPED with file:line evidence
instead of improvising — the two dispatch-imprecision incidents early in the arc (omitted
worktree mechanics; a "no hoist needed" claim contradicting §9.3) were both caught by
executor discipline, and later dispatches restated mechanics and quoted the doc. (2) The
seat-performs-merges pattern: sample re-runs (tests, grep spots) before each FF land caught
zero landing defects across ~35 lands — and kept verification honest. (3) Recovering the
zombie consumer-leg's work from disk: the commits were the deliverable; the agent's report
was only ever a pointer to them. (4) The park-not-improvise disposition for P1–P5: the parks
clustered coherently (P1+P3+DS-024 are one generational-tier design story), which is itself
evidence the STOPs were genuine design gaps, not executor timidity.

**Didn't.** (1) Stale caches produced at least five distinct false verdicts across the night
— mixed-generation resolutions during consumer gates, lint evals reading pre-rename mirrors,
the W4 agent's false slab-RED (its rig resolved a pre-reshape slab checkout), and the
converse risk that my own W3.3 slab land re-ran tests in the executor's worktree `.build`
(a cached seam could have masked a real break; the fresh morning rebuild happened to confirm
green). Both green and red verdicts were manufactured by cache reach at different points.
(2) The W1.6-era dossier enumerations went stale by W3 (the linked leg's premise was
overturned by a deeper source read) — scope enumerations in dispatch prompts need write-time
verification AND resume-time re-verification, exactly [HANDOFF-016/021], which the dossier
had honored at write time but the world moved. (3) The io crash investigation stalled on
probe module-topology at 2am and was correctly parked — but two probe-fix round-trips were
spent before the time-box fired; the box should fire earlier when context is deep.

## Patterns and Root Causes

**The night's dominant failure class was tool-reach, not logic.** Every wrong verdict —
false RED (W4's slab), potentially-masked GREEN (worktree `.build` reuse at land), vacuous
lint PASSes (rules never loaded), "doesn't resolve" noise (stale mirrors mid-rename) — was
one epistemic defect: a verification tool whose reach (its resolved pin set, its cache
generation, its rule-load state) was narrower than or skewed from the claim being made.
This is [REFL-011]'s tool-reach extension and [PKG-BUILD-013]'s pin-assert, observed live
five times in one session. The structural amplifier: a many-package locally-mirrored
ecosystem **mid-rename** (F3(c)) maximizes cache-generation skew — every `.build`,
`Package.resolved`, `workspace-state.json`, mirrors.json copy, and ModuleCache is a
potential stale-generation witness. The remedy that worked every time was the same:
fresh resolve + pin-assert against canonical tips + completed-build re-grep. The gap:
the SEAT'S OWN land recipe did not mandate this — executor gates did, but the seat's
verify-before-FF sample re-runs reused executor worktree state. The verifier needs the
same pin discipline as the executor.

**STOP discipline is a design-surface detector, not overhead.** The doc's §9 claimed
mechanical executability; the six STOPs empirically located exactly where that claim's
boundary ran: [DS-029]'s three-form table is spelled only for the Contiguous storage path.
Pool/Generational (P3), Split (P2), and the bounded/inline axes (P1, P5) are outside it —
and every executor that reached those edges stopped rather than invented. The program's
"parks" are therefore a precise, evidence-backed map of the spec's unspecified region —
more valuable than if the executors had plausibly improvised through them. The keyed-error
collision (P4) generalizes: nested aliases named `Error` collide with inherited
carrier-level `Error` aliases on any `__Carrier where S:` family — a naming-scheme
constraint the code-surface skill does not yet state.

**Compile-green is not meaning-preserving under hoists (§9.4 fired live).** json's
`SmallByteArray` alias silently re-meant array-of-columns for five days — every build green,
type wrong, caught only by the planned consumer migration. Grep-zero gates on old spellings
are the ONLY detector for this class; they are load-bearing, not ceremony.

## Action Items

- [ ] **[skill]** swift-package-build: extend [PKG-BUILD-013] (or add a sibling) — a
  supervisor/verifier re-running an executor's gates before landing MUST fresh-resolve and
  pin-assert (never reuse the executor's `.build`/`Package.resolved`); five stale-cache
  false-verdict incidents in the 2026-07-05/06 tower session, including one false RED and
  one potentially-masked GREEN at the land boundary.
- [ ] **[skill]** ecosystem-data-structures: fold into the pending W4 skill-rider pass — a
  [DS-029] scope note stating the three op forms are specified for the Contiguous storage
  path only; Pool/Generational, Split, and Inline-bounded paths are explicitly unspecified
  (the P1/P2/P3/P5 parks are the evidence), so executors must STOP there, not extrapolate
  form-2.
- [ ] **[blog]** The silent-retype hazard: how a typealias survived a generic hoist
  compile-green and changed meaning (`Array<Column>` → array-of-columns), why the type
  system cannot catch it, and grep-zero gates as the detector class — grounded in the json
  `SmallByteArray` incident.
