# HANDOFF Lifecycle and Retention

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

`HANDOFF-*.md` files at the working-directory root accumulate despite the
existence of `[REFL-009] Handoff Cleanup`. As of 2026-04-30 11:30 there are
26 such files at `/Users/coen/Developer/` (the brief stamped 25 at 11:30;
one is the brief itself; one further file landed during research). The
prior 2026-04-29 bulk-triage cycle reduced the count from 35 → 20 (43%
reduction) but the rate of new dispatch (≈6 new in 19 hours) projects a
return to the pre-triage baseline within ~4 days at constant cadence.

`[REFL-009]` is well-specified — disposition matrix, MUST-delete-when-complete,
rationale "stale handoff files actively mislead future agents" — yet the file
count grows. The rule is firing in recent sessions (Apr 25 / 26 / 28 / 29 /
30 reflections each carry a `**HANDOFF scan per [REFL-009]**` section). The
failure is not non-invocation; the failure is in the rule's structure as
applied to the cross-session orphan zone.

**Trigger**: 2026-04-30 parent session noticed workspace pollution while
dispatching today's Phase 1c + Tier 2 follow-on handoffs (parent's ongoing
work was Phase 1b stale-experiment triage + skill amendments
`[META-022]` / `[META-022a]` / `[EXP-006c]`). The pollution observation
prompts a structural diagnosis rather than another bulk-triage cycle.

**Constraints**:
- `/Users/coen/Developer/` is NOT a git repository — deletions are
  irreversible filesystem ops, raising the bar on any single deletion.
- The 2026-04-29 triage table (`HANDOFF-handoff-files-triage-and-cleanup-table.md`)
  remains the durable record of dispositions; this research is META and
  must not modify it.
- The 25 in-flight HANDOFF briefs themselves and today's Phase 1c / Tier 2
  pending-dispatch handoffs are out of scope (Do Not Touch).

**Relationship to prior research**: `recurring-handoff-triage-skill-candidate.md`
(2026-04-30, IN_PROGRESS) addresses the *response* side — should the
six-phase bulk-triage framework be codified as a skill? This document
addresses the *prevention* side — why does `[REFL-009]` not prevent the
accumulation that the bulk-triage framework remediates? The two are
complementary: a successful prevention design reduces the cadence at which
the bulk-triage framework needs to fire; a successful bulk-triage codification
makes residual sweeps cheap. They are not substitutes.

## Question

This research investigates four sub-questions:

1. **Q1 — Failure-mode diagnosis**: Why does `[REFL-009]` fail to prevent
   `HANDOFF-*.md` accumulation? Five hypotheses to evaluate (from the brief).
2. **Q2 — Design space**: What structural fixes are available? Enumerate
   ≥5 options with mechanism, scope, and trade-off shape.
3. **Q3 — Recommendation**: Pick one (or composition) and analyze
   consumer impact: skill-rule changes, cross-references, session-end
   behavior shifts, transition cost.
4. **Q4 — Execution plan**: Specify the follow-on `/handoff` brief: effort,
   coordination, sequencing, gates.

## Analysis

### Q1 — Failure-mode diagnosis

Each of the brief's five hypotheses is evaluated against evidence drawn from
recent reflection entries (Apr 25 – Apr 30) and the Apr-29 triage table.

#### Hypothesis 1 — `/reflect_session` invocation opt-in; sessions close without firing it

**Verdict**: PARTIAL. Not the dominant cause.

**Evidence — confirms /reflect-session IS firing**:

| Reflection | HANDOFF scan recorded | Outcome |
|-----------|-----------------------|---------|
| `2026-04-25-platform-audit-dispatch-and-same-day-hygiene-arc.md` | Yes — 4-5 files | "0 deleted, 0 annotated, 5 out-of-session-scope" |
| `2026-04-26-cross-carrier-utilities-research-defer.md` | Yes — 1 file | (deletion authorized via /reflect-session per [REFL-009]) |
| `2026-04-26-l1-exception-removal-skill-cycle.md` | Yes — 1 file | scanned at swift-institute root |
| `2026-04-26-lateral-l3-doc-stamp-and-platform-skill-amendment.md` | Yes — 6 files | (institute root scan) |
| `2026-04-26-observable-macro-twin-design-and-validation-gap.md` | Yes — 1 file | "deleted" |
| `2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md` | Yes — 29 files | "1 deleted, 0 annotated, 28 out-of-session-scope" |
| `2026-04-28-sub-cycle-1-1-inverted-pattern-a.md` | Yes — 28 files | "0 deleted, 0 annotated, 28 LEFT" |
| `2026-04-29-carrier-launch-arc-and-centralized-workflow-trim.md` | Yes — 33 files | "0 deleted, all out-of-session-scope" |
| `2026-04-29-carrier-pre-release-audit-and-launch-deployment.md` | Yes — 7 files (at swift-institute root) | "all out-of-authority, left in place" |
| `2026-04-29-handoff-triage-cycle-and-d-to-a-reclassification.md` | Yes (the bulk triage itself) | 15 deleted via principal-authorized batch |
| `2026-04-30-corpus-meta-analysis-and-phase-11-completion.md` | Yes — 4 files | "fresh dispatch / pending verification — leave" |

**Counter-evidence**: dispatching sessions sometimes do not run /reflect-session
before they end. Today's parent dispatched Phase 1c + Tier 2 handoffs and the
brief noted "noticed workspace pollution" — i.e., the dispatching context is
still open as this research begins. Dispatching-without-reflecting is a
real but small contributor: ~1-2 of today's 6 new files plausibly originate
from dispatch-without-reflection.

**Conclusion**: HYP1 explains a small fraction of accumulation. The dominant
failure is downstream of /reflect-session firing — sessions invoke the rule
and report "scanned but out-of-authority."

#### Hypothesis 2 — `[REFL-009]`'s bounded-cleanup-authority clause leaves cross-session orphans

**Verdict**: CONFIRMED. Dominant cause.

**Evidence**: bounded-cleanup-authority is the explicit gate cited in every
recent `**HANDOFF scan per [REFL-009]**` block. The gate's three-clause test
(*"a handoff file is in this session's cleanup authority if the session either
(a) wrote it, (b) actively worked the items it describes, OR (c) encountered
its header-stated completion signals in the course of other session work"*)
is being applied conservatively, and most files fail all three clauses for
most sessions:

- Clause (a) — wrote it: only fires for the dispatching session, which often
  ends without /reflect-session;
- Clause (b) — actively worked items: only fires for the executing session,
  which typically classifies as "still has Next Steps" and leaves;
- Clause (c) — encountered completion signals during other work: rarely fires
  in practice, requires the session to do unrelated work that incidentally
  verifies a parallel handoff's completion.

**Quantitative pattern**:

| Session | Files in scope | In authority | Out-of-authority |
|---------|----------------|--------------|------------------|
| 2026-04-25 hygiene-arc | 5 | 0 | 5 |
| 2026-04-28 sub-cycle 1.1 | 28 | 1 | 27 |
| 2026-04-28 Phase 1.5 | 29 | 1 | 28 |
| 2026-04-29 carrier-launch | 33 | 0 | 33 |
| 2026-04-29 carrier-pre-release | 7 | 0 | 7 |
| 2026-04-30 corpus-meta-analysis | 4 | 4 | 0 |

The 2026-04-30 corpus-meta-analysis row is the exception: that session
authored its own batch (the corpus phase handoffs) so all 4 are in authority.
But those 4 files were stamped `LEAVE — fresh dispatch, work not yet started`
per `[REFL-009]`'s "block present but no `[SUPER-011]` verification line yet"
disposition — i.e., even when in authority, the rule's preservation defaults
prevent deletion.

**Mechanism**: bounded-cleanup-authority was added (provenance:
`2026-04-16-reflect-session-cleanup-completeness.md`) precisely to prevent
*over-touching* — the failure mode where the agent deletes files it didn't
verify. Its inverse — *under-touching*, the failure mode where every session
declines to triage anything it didn't author — is now dominant. The rule
fixed one failure mode while creating its mirror.

**Verified**: 2026-04-30 against 8 reflections.

#### Hypothesis 3 — F-classified (work-incomplete) handoffs preserved but never resolve

**Verdict**: CONFIRMED for the SGR-unverified subset; partially confirmed
for the Q1=no subset.

**Evidence — from the Apr-29 triage table's F-classified set (6 files)**:

| File | Reason F-classified | Current status (Apr 30) |
|------|---------------------|-------------------------|
| docc-umbrella-patch-pipeline | Q1=no — script never committed | UNCHANGED — gap remains |
| executor-main-platform-runloop | Q1=no — `import Dispatch` still present | UNCHANGED — verified by grep Apr 30 |
| kernel-primitives-phase-3 | SGR unverified — work subsumed by Path X | Path X dissolves package; rule preserves |
| l1-exception-removal-execution | SGR unverified — scaffolding pushed; subsumed | Path X dissolves package; rule preserves |
| l2-cascade-recommendation | SGR unverified — cascade SUPERSEDED by Path X | Successor exists; rule preserves |
| posix-descriptor-l2-vs-l3policy | SGR unverified — RECOMMENDATION landed | Investigation closed; rule preserves |

**Two sub-classes**:

1. **SGR-unverified-but-superseded (4 of 6)**: `[REFL-009]`'s clause
   *"A handoff file containing an unverified supervisor ground-rules entry
   MUST NOT be deleted, even if all Next Steps are complete"* preserves files
   whose underlying work has been dissolved by a superseding investigation
   (Path X subsumes kernel-primitives-phase-3, l1-exception-removal, and the
   cascade; posix-descriptor's RECOMMENDATION is consumed by Path X). The
   SGR was never verified because the work was never executed under the
   block — it was overtaken by a different design path. The rule preserves
   accountability that has no live referent.

2. **Q1=no but stalled (2 of 6)**: docc-umbrella-patch-pipeline and
   executor-main-platform-runloop both have real ecosystem gaps that nobody
   has scheduled. The rule correctly preserves them, but no mechanism exists
   to convert "preserved indefinitely" into either "scheduled for execution"
   or "explicitly de-prioritized."

**Conclusion**: HYP3 is structurally real. The SGR-preservation clause was
designed for in-flight supervision continuity; it was not designed for
post-supersession archive. Both sub-classes accumulate.

#### Hypothesis 4 — G-classified (in-flight) handoffs lack auto-transition to E (archive-tag) on completion

**Verdict**: CONFIRMED in mechanism, latent in current effect.

**Evidence — from the Apr-29 G-classified set (11 files)**:

| File | Reason G | Current status (Apr 30) |
|------|----------|-------------------------|
| l1-kernel-primitives-removal-plan | Path X RECOMMENDATION substrate | IN FLIGHT (Path X cycles 1-23) |
| l1-types-only-no-exceptions | Path X precursor investigation | IN FLIGHT |
| ownership-borrow-release-miscompile | Awaits YES TAG | YES TAG GIVEN per Apr-30 launch reflection |
| ownership-primitives-precursor-blog | Awaits YES PUBLISH | (gated on tag) |
| path-x-bucket-b | Path X Cycles 1-5 | IN FLIGHT |
| path-x-bucket-c | Path X Cycles 6-18 | IN FLIGHT |
| path-x-completion | Path X completion | UPDATED Apr 30 10:43 — IN FLIGHT |
| path-x-phase-1 | Path X Phase 1 | CLOSED Apr 29 (per file) but no deletion rule fired |
| path-x-phase-2 | Path X Phase 2 — `[CLOSED 2026-04-29]` | EXPLICITLY CLOSED yet preserved per `[SUPER-024]` |
| swift-error-primitives-placement | Active topic | IN FLIGHT |
| tagged-primitives-rename | 0.1.0 release in flight | (status TBD) |

**Key observation — path-x-phase-2 case**: this file's body literally argues
self-preservation per `[SUPER-024]` (workspace not git-tracked, deletion
permanent) despite being marked `[CLOSED 2026-04-29]` with all 7 ACs verified
and 6 ground rules verified. The G→E transition that should fire when
"in-flight" → "closed" does not fire because:

- The closing session was the executor (Path X Phase 2), so authority clause
  (a) does not apply (didn't write the original investigation brief);
- Clause (b) authority would apply (actively worked items) but the file's
  own rule citation `[SUPER-024]` explicitly argues against deletion;
- No rule says "G classification is reviewable when the in-flight arc closes."

**Conclusion**: HYP4 is structurally real and will become acute when Path X
completes — at that point, 7-9 currently-G files will simultaneously become
candidates for archive-tag transition with no rule defining who triggers it.

#### Hypothesis 5 — Working-dir root location prevents git-tracked deletion + history

**Verdict**: CONFIRMED as an amplifier; not a primary cause.

**Evidence**:

- `/Users/coen/Developer/` is not a git repository (verified per CLAUDE.md
  "Is a git repository: false" and prior triage table notes).
- The Apr-29 triage table explicitly notes: *"The workspace root is not a
  git repository, so deletions are filesystem `rm` (irreversible)."*
- `[SUPER-024]` is invoked in path-x-phase-2's body as a self-preservation
  argument: *"workspace not git-tracked, deletion would be permanent."*
- This raises the bar on any single deletion: where in a git-tracked
  context an agent can delete with `git revert` as a safety net, in this
  context every deletion is one-way. The conservative bias compounds the
  bounded-authority clause's effect: even when authority applies, the
  irreversibility of the action raises the agent's threshold for action.

**Mechanism**: HYP5 does not by itself create accumulation; bounded-authority
(HYP2) does. But HYP5 amplifies the conservative reading of every disposition
question. An agent uncertain whether to delete in a git-tracked context can
reason "if I'm wrong, I revert"; the same agent in a non-git-tracked context
reasons "if I'm wrong, the file is gone." The asymmetry is structurally
present in every triage decision.

#### Root cause synthesis

The five hypotheses are not independent; HYP2 is the dominant cause and
HYP5 amplifies its effect. HYP3 and HYP4 produce specific accumulating
sub-classes that no rule explicitly resolves. HYP1 is partial and not the
right place to intervene.

The structural picture: `[REFL-009]`'s bounded-cleanup-authority clause
created an *orphan zone* — handoffs whose original session is gone and
whose executing session is gone (or chose to leave for any of HYP3 / HYP4
reasons), with no third party authorized to triage. Each subsequent session
encounters them and correctly applies bounded-authority: not authored here,
not actively worked here, no completion-signal encounter. Result: leave.
The orphan zone grows.

The fix space is therefore not "make /reflect-session fire harder" (HYP1)
but "give some authorized party a path to triage the orphan zone." This is
the same shape as `[META-001]` Staleness Threshold for IN_PROGRESS research
and `[META-022]` Experiment Staleness Detection: when an artifact has aged
past a threshold without modification, *any* future maintenance pass acquires
authority to triage. The handoff lifecycle is missing this analog.

### Q2 — Design space

Each option is described, classified by which hypothesis it primarily
addresses, and evaluated against four criteria:

- **Effectiveness**: how well does it dissolve the orphan zone?
- **Composition**: how cleanly does it fit existing skill rules?
- **Reversibility**: if the fix is wrong, how cheap is reversal?
- **Transition cost**: what migration is required?

#### Option A — Auto-fire `/reflect-session` via session-end hook

Configure a `Stop` hook in `settings.json` that triggers `/reflect-session`
when a session terminates, ensuring [REFL-009] runs at every session end.

**Addresses**: HYP1.

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | Low. /reflect-session IS already firing per recent reflections. Forcing more invocations does not address the bounded-authority gate that fires next. |
| Composition | Poor. Hooks fire on every session including trivial ones; violates `[REFL-001]`'s "SHOULD NOT be invoked for sessions that produced only routine work" guidance. |
| Reversibility | High — remove the hook. |
| Transition cost | Low — single settings.json edit. |
| Side effects | Reflection inflation; routine-session reflections crowd out high-signal reflections in the corpus. |

**Verdict**: misdiagnosis. Rejecting.

#### Option B — `[HANDOFF-staleness]` cadence rule (analog to `[META-022]`)

Add a new staleness-threshold rule for HANDOFF-*.md files at any working-dir
root: a file untouched for ≥14 days MUST be triaged in the next
`/reflect-session`, regardless of bounded-cleanup-authority. Triage outcomes
mirror `[META-002]`: resolve to deleted (work complete), resolve to deferred
(blocker remains), or update with status note. The rule overrides
bounded-authority for stale cases only; fresh handoffs (<14 days) retain
the bounded-authority discipline.

**Addresses**: HYP2 root cause; partially HYP3/HYP4 (stale F/G files become
triageable).

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | High. Dissolves the orphan zone within 14 days of authoring. |
| Composition | Strong. Mirrors `[META-001]` and `[META-022]` exactly; pattern is established and documented. |
| Reversibility | High — revert the skill amendment; existing handoffs unaffected. |
| Transition cost | Medium — skill amendment + one bulk-triage cycle to apply the rule retroactively to the current 26-file backlog. |
| Side effects | Possible over-eager triage of legitimately long-running investigations (e.g., Path X has been in flight ≥14 days). Mitigated by triage outcome including "still active, in-flight" with explicit `last active: YYYY-MM-DD` annotation, mirroring `[META-022]`'s "still active" disposition. |

**Verdict**: strong primary candidate.

#### Option C — Pre-write classification (dispatch-time triage of pre-existing handoffs)

When a session dispatches a new HANDOFF, the dispatcher MUST classify all
pre-existing HANDOFFs at the same root via the same rubric (Q1-Q5 + A-G
disposition) as part of the dispatch. New handoffs cannot be added to a
polluted root without a triage pass.

**Addresses**: HYP2 friction (forces triage as a side effect of dispatch).

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | Medium. Catches accumulation at write-time but only when a new dispatch occurs; quiescent periods still leave the orphan zone untouched. |
| Composition | Medium. Adds friction to dispatch (the cheapest moment to write); contradicts the [HANDOFF-007] token-budget discipline by forcing 25-file-review on every dispatch. |
| Reversibility | High. |
| Transition cost | Low — skill amendment only. |
| Side effects | Dispatch latency; pressure to skip dispatch altogether. |

**Verdict**: high friction relative to value; reject standalone.

#### Option D — Relocate HANDOFF storage to a git-tracked location

Move HANDOFF-*.md files from `/Users/coen/Developer/` (non-git-tracked) to
a new `swift-institute/Handoffs/` directory (git-tracked, mirroring
`swift-institute/Research/`, `swift-institute/Audits/`, `swift-institute/Skills/`
patterns). Adjust `[HANDOFF-008]` File Location and Naming. Add CLAUDE.md
routing to direct agents to the new location.

**Addresses**: HYP5 (permanence/irreversibility).

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | Low for the dominant cause (HYP2 unchanged); high for HYP5 amplifier. |
| Composition | Poor. Breaks `[HANDOFF-008]` working-directory-root convention which exists for discoverability — agents dropped into a CWD `ls` and see HANDOFF*.md. Cross-package handoffs (e.g., Path X spanning 6+ repos) have no natural single git location; `swift-institute/Handoffs/` is one option but it forces the dispatcher to know "is this cross-cutting?" before writing. |
| Reversibility | Medium-low. Once relocated, `[HANDOFF-008]` and CLAUDE.md routing changes propagate; reverting requires a second migration. |
| Transition cost | High. 26 files to relocate; cross-references in skill rules; CLAUDE.md updates; agent workflow changes (multiple sessions running concurrently with stale conventions). |
| Side effects | Discoverability hit. Working-tree contamination resolves (gitignore removes the `/Users/coen/Developer/HANDOFF*.md` clutter), but the migration cost is paid once for a benefit that's marginal vs. Option B. |

**Verdict**: addresses an amplifier, not the root cause; reject standalone.

#### Option E — Composition B + D (sweep + relocate)

**Verdict**: dominant cost is from D (relocation) without proportional
gain over Option B alone. Prefer Option B without relocation.

#### Option F — `[HANDOFF-replacement]` dispatch-side retirement rule

When a new HANDOFF supersedes a prior one (same investigation, different
phase; pre-pivot/post-pivot pair; investigation closed and replaced by
RECOMMENDATION-execution), the dispatching session MUST delete the predecessor
as part of the dispatch. `[HANDOFF-021]`'s scope-enumeration command MUST
include "predecessor handoffs being retired" as an explicit field.

**Addresses**: HYP3 (work-incomplete preserved indefinitely) and HYP4 (G
in-flight lacks transition-to-archive) by making the *creator* of the
successor responsible for predecessor retirement, breaking the orphan-zone
pattern.

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | Medium-high for HYP3/HYP4 specific sub-classes. Does not catch handoffs that go stale without a successor (which is the HYP3 Q1=no sub-class). |
| Composition | Strong. Mirrors the writer-side discipline pattern of `[HANDOFF-013a]` (writer-side prior-research grep) and `[HANDOFF-032]` (extraction-time material check). The dispatcher already has full context to identify predecessors; deferring to the executor (current default) is the cause of orphaning. |
| Reversibility | High. |
| Transition cost | Low — skill amendment only. |
| Side effects | Dispatcher must explicitly identify the predecessor — not always obvious (e.g., Path X dispatch retired no specific predecessor; the kernel-primitives investigation merely became "subsumed" with no formal handoff link). The rule should require dispatchers to enumerate predecessors as part of `[HANDOFF-021]`'s grep, and accept "no predecessor" as a valid answer when the new investigation is genuinely novel. |

**Verdict**: strong, complementary to Option B.

#### Option G — Composition B + F (sweep + dispatch-side retirement)

The recommended primary structure. Composition reasoning:

- **Option B (sweep)** dissolves the orphan zone for handoffs that go stale
  without a successor (HYP2, HYP3 Q1=no, HYP4 in-flight-then-quiet sub-cases).
- **Option F (dispatch retirement)** prevents accumulation at the source
  for handoffs that have a clear successor (HYP3 SGR-unverified-but-superseded,
  HYP4 G-with-named-successor).
- Together they cover the four sub-classes identified in Q1 root-cause
  synthesis.

| Criterion | Assessment |
|-----------|------------|
| Effectiveness | High. B catches the orphan zone; F prevents new accumulation at dispatch time. |
| Composition | Strong. Both options compose with existing skill ecosystem patterns. |
| Reversibility | High. Both are skill amendments; existing handoffs unaffected by reversal. |
| Transition cost | Medium — three skill amendments + one retroactive sweep. |
| Side effects | None significant beyond what each option carries individually. |

#### Comparison table

| Criterion | A: Hook | B: Sweep | C: Pre-write | D: Relocate | E: B+D | F: Dispatch retire | G: B+F (rec) |
|-----------|--------:|---------:|-------------:|------------:|-------:|-------------------:|-------------:|
| HYP1 covered | ✓ | – | – | – | – | – | – |
| HYP2 covered | – | ✓ | partial | – | ✓ | – | ✓ |
| HYP3 covered | – | partial | – | – | partial | ✓ | ✓ |
| HYP4 covered | – | partial | – | – | partial | ✓ | ✓ |
| HYP5 covered | – | – | – | ✓ | ✓ | – | – |
| Effectiveness | Low | High | Med | Low | High | Med-High | High |
| Composition | Poor | Strong | Med | Poor | Med | Strong | Strong |
| Transition cost | Low | Med | Low | High | High | Low | Med |
| Side-effect risk | High (refl. inflation) | Low | Med (dispatch friction) | Med (discoverability) | Med | Low | Low |

### Q3 — Recommendation

**Recommend Option G — composition of B (sweep) + F (dispatch-side retirement)** —
with the explicit refinement that the bounded-cleanup-authority clause in
`[REFL-009]` is amended (not deleted) to add a stale-override exception
referencing the new staleness rule. Three skill amendments compose:

1. **New rule `[HANDOFF-038] HANDOFF Staleness Threshold`** in the handoff
   skill (analog to `[META-022]`). HANDOFF-*.md files at any working-dir
   root older than 14 days (no modification) MUST be triaged in the next
   `/reflect-session`, regardless of `[REFL-009]` bounded-cleanup-authority.
   Triage outcomes mirror `[META-002]`: deleted (work complete), updated
   with `## Triage Status` note (work remains, defer), or annotated
   `// Last active: YYYY-MM-DD` if explicitly still in flight.

2. **New rule `[HANDOFF-039] Predecessor Retirement at Dispatch`** in the
   handoff skill. When dispatching a new HANDOFF that supersedes one or
   more prior handoffs (same investigation phase, pre-pivot/post-pivot,
   investigation→execution transition), the dispatching session MUST:
   - Identify predecessor handoffs (enumeration via `[HANDOFF-021]` grep
     against the root, plus content-search for the same investigation topic).
   - Either delete each predecessor (work fully captured in successor) or
     annotate it with `## Superseded By: HANDOFF-{successor}.md ({date})`
     plus reason. Predecessor handoffs not deleted MUST carry the supersession
     annotation in their first 10 lines so future `[REFL-009]` scans can
     classify them as E (archive-tag) candidates.
   - The `[HANDOFF-021]` scope-enumeration block in the new HANDOFF MUST
     include a `## Predecessors Retired` sub-section listing each retired
     file and its disposition (deleted / annotated-superseded).

3. **Amendment to `[REFL-009]` bounded-cleanup-authority clause** in
   reflect-session. Add a stale-override paragraph after the existing
   bounded-authority text: when a HANDOFF-*.md file at root meets the
   `[HANDOFF-038]` staleness threshold AND its closure signals are
   determinable from current session context (commits landed referencing it,
   successor handoff exists, RECOMMENDATION cited in successor's body),
   the current session MAY triage even if not in original authority.
   The conservative path remains explicit: if uncertain, leave annotated
   per the existing F-disposition rule and note the staleness flag.

**Why composition rather than B alone**: Option B dissolves accumulation
on a 14-day cadence, but in the meantime fresh handoffs continue to be
written. Option F catches the most common case where accumulation happens
deliberately (a successor exists; the dispatching session simply did not
retire the predecessor). Together they shorten the orphan-zone lifetime
from "indefinite" to "≤14 days for orphan, immediate for predecessors."

**Why amendment rather than replacement of `[REFL-009]`**: bounded-cleanup-authority
fixed a real failure (over-deletion) per the 2026-04-16 reflection. Removing
it risks resurfacing that failure mode. The amendment preserves
bounded-authority as the default for fresh handoffs (where the original
session may still complete the work) and only relaxes it when the staleness
threshold is met.

#### Consumer-impact analysis

**Skill rules added**:
- `[HANDOFF-038]` HANDOFF Staleness Threshold — handoff skill, new section
  alongside `[HANDOFF-016]` Staleness Axes.
- `[HANDOFF-039]` Predecessor Retirement at Dispatch — handoff skill, new
  section alongside `[HANDOFF-021]` Scope Enumeration.

**Skill rules amended**:
- `[REFL-009]` Handoff Cleanup — reflect-session skill, add stale-override
  paragraph; cross-reference `[HANDOFF-038]`.

**Cross-references created/updated**:
- `[HANDOFF-038]` → `[META-001]`, `[META-022]` (analog references).
- `[HANDOFF-039]` → `[HANDOFF-013a]`, `[HANDOFF-021]`, `[HANDOFF-032]`
  (writer-side discipline pattern).
- `[REFL-009]` → `[HANDOFF-038]` (stale-override link).

**Session-end behavior shifts**:

| Before | After |
|--------|-------|
| /reflect-session scans root, classifies most files out-of-authority, leaves them | /reflect-session scans root, applies bounded-authority for fresh handoffs (<14 days), applies stale-override for ≥14-day-old files |
| Dispatching session writes new HANDOFF; predecessors orphaned silently | Dispatching session writes new HANDOFF, enumerates predecessors, deletes or annotates each |
| Bulk-triage cycle every ~2 weeks (per `recurring-handoff-triage-skill-candidate.md`) | Bulk-triage cycle still useful for ecosystem-wide audits but routine per-session sweeps catch most accumulation |

**Transition plan** (sketched; full plan in Q4): retroactive bulk-triage
applies the new rules to the current 26-file backlog. The Apr-29 triage
table's classifications remain valid as input; the new rules promote some
F-classified SGR-unverified-but-superseded files to E (archive) and clear
the G-but-explicitly-closed cases (path-x-phase-2).

**Composition with `recurring-handoff-triage-skill-candidate.md`**:
that doc's preliminary recommendation was "defer codification until a
second cycle is observed." This research is the second-cycle's evidence
on the prevention side. The combined position:
- Prevention rules ([HANDOFF-038], [HANDOFF-039], [REFL-009] amendment)
  reduce the cadence at which bulk-triage needs to fire.
- The bulk-triage framework still has value for ecosystem-wide periodic
  sweeps (e.g., semi-annually) but no longer needs to fire every 2 weeks.
- Codification of the bulk-triage framework as a standalone skill
  (Option C in that doc) becomes lower priority once accumulation is
  prevented at source. Recommendation defers to that doc's eventual
  resolution; this research does not block or supersede it.

#### Risks and mitigations

| Risk | Mitigation |
|------|------------|
| 14-day threshold too aggressive — kills legitimately long-running investigations | Triage outcomes include "still active, last active: YYYY-MM-DD" annotation per `[META-022]`; the threshold triggers triage, not deletion |
| Dispatching session over-applies predecessor retirement, deletes still-relevant handoffs | `[HANDOFF-039]` requires explicit identification; "no predecessor" is an acceptable enumeration result; ambiguity escalates to user per existing `[SUPER-005]` discipline |
| Stale-override paragraph in `[REFL-009]` reintroduces over-deletion failure | Stale-override only fires when staleness threshold met AND closure signals are determinable; conservative path explicit; the retroactive bulk-triage in Q4 exercises the rule once with principal review |
| Working-dir non-git-tracked location amplifies any deletion error (HYP5) | The retroactive triage ALWAYS routes deletions through the user's batched YES authorization (mirrors Apr-29 pattern); per-handoff agent autonomy is bounded |

#### Why not Options A or D

**Option A (Stop hook)**: misdiagnosis. /reflect-session firing isn't the
problem; bounded-authority gating is. Adding the hook would force reflection
on routine sessions (violating `[REFL-001]`) without addressing the gate.

**Option D (relocation)**: addresses HYP5 (an amplifier, not the root cause)
at high transition cost. Working-dir-root convention exists for discoverability
and survives most failure modes once Option B + F are applied. If HYP5 amplification
becomes acutely problematic post-rollout (e.g., still-frequent over-cautious
preservation at scale), Option D remains available as a follow-on; the
prerequisite to consider it is empirical evidence that B+F alone are
insufficient, which the current data does not show.

## Outcome

**Status**: RECOMMENDATION (v1.0.0).

**Recommendation**: Adopt Option G (composition of B + F):
- Add `[HANDOFF-038]` HANDOFF Staleness Threshold (handoff skill).
- Add `[HANDOFF-039]` Predecessor Retirement at Dispatch (handoff skill).
- Amend `[REFL-009]` to add stale-override paragraph cross-referencing
  `[HANDOFF-038]`.
- Run a retroactive bulk-triage applying the new rules to the current
  26-file backlog under principal-batched authorization (mirroring the
  Apr-29 cycle's pattern).

**Tier classification**: Tier 2 per `[RES-020]` — cross-package, reversible
precedent. The skill amendments affect every session that invokes
`/handoff` or `/reflect-session`; the rules can be reverted as skill
amendments if the empirical effect is contrary to the prediction.

**Adoption gate**: principal authorization required for skill amendments
per `feedback_user_plan_is_roadmap_not_authorization.md` and
`feedback_skills_follow_institute_convention.md`. The execution handoff
(Q4) is drafted as a branching investigation/execution brief that the
principal can dispatch when convenient.

## Q4 — Execution plan

The follow-on `/handoff` is a sequential execution brief (not branching)
because the work is concrete: edit two skill source files, draft the
retroactive triage table, run the bulk-triage cycle.

**Location**: Working-dir root per `[HANDOFF-008]`, naming
`HANDOFF-handoff-lifecycle-execution.md`.

**Scope** (sketch — full content in the execution handoff itself):

### Phase 1 — Skill amendments (no user authorization required for drafting; commit gates per `feedback_skills_follow_institute_convention.md`)

1. **Edit `swift-institute/Skills/handoff/SKILL.md`**:
   - Add `[HANDOFF-038]` section placed alongside `[HANDOFF-016]` Staleness Axes
     (which it complements: 016 is reader-side staleness recognition; 038 is
     ecosystem-side cadence).
   - Add `[HANDOFF-039]` section placed alongside `[HANDOFF-021]` Scope
     Enumeration at Write-Time (which it complements: 021 is forward-scope
     enumeration; 039 is backward-supersession enumeration).

2. **Edit `swift-institute/Skills/reflect-session/SKILL.md`**:
   - Amend `[REFL-009]` bounded-cleanup-authority paragraph to add the
     stale-override clause cross-referencing `[HANDOFF-038]`.

### Phase 2 — Skill-corpus consistency

- Run `Scripts/sync-skills.sh` to refresh `.claude/skills/` symlinks.
- Grep all skills referencing `[REFL-009]` and verify the new clause is
  consistent with their citations.
- Update cross-references in `corpus-meta-analysis` skill if it references
  `[REFL-009]` (it does, in the cleanup-targets table).

### Phase 3 — Retroactive bulk-triage

- Author `HANDOFF-handoff-files-retroactive-triage-2026-04-30.md` (mirroring
  the Apr-29 triage table's structure) classifying the current 26 files
  under the new rules.
- Apply per-file dispositions:
  - `[HANDOFF-038]` staleness threshold → fires for files with mtime
    ≤ 2026-04-16 (14 days before today).
  - `[HANDOFF-039]` retroactive predecessor identification → at minimum,
    Path X dissolves kernel-primitives-phase-3, l1-exception-removal-execution,
    l2-cascade-recommendation; supersession annotations or deletions per
    those new rules.
  - `[REFL-009]` stale-override → applies to SGR-unverified-but-superseded
    F-files where closure is determinable.
- Stage all proposed deletions for principal-batched YES authorization
  (Apr-29 pattern). Do not delete autonomously.

### Phase 4 — Reflection

- Author reflection at `swift-institute/Research/Reflections/2026-MM-DD-handoff-lifecycle-execution.md`
  capturing: (a) which rules were applied to which files, (b) any rule
  ambiguities surfaced, (c) action items for further refinement.

### Effort estimate

- Phase 1: 30-60 min (skill rule drafting + rationale + provenance).
- Phase 2: 15 min (sync + grep audit).
- Phase 3: 60-90 min (per-file rubric application + table authoring +
  principal authorization round-trip).
- Phase 4: 30 min reflection.
- **Total**: ~2.5-3.5 hours single-session, or splittable across two sessions
  (Phases 1-2 + Phases 3-4).

### Coordination

- **Sequencing**: Phase 1 must precede Phase 3 (rules must exist before
  applying them retroactively). Phases 1+2 can be one commit per skill
  source; Phase 3 is a separate commit (or batch) with principal-authorized
  deletions.
- **Concurrency**: avoid running the execution simultaneously with Path X
  cycles (which currently mutate path-x-completion.md and others). Either
  pause Path X or schedule the execution for a Path-X-quiet window.
- **Coordinaton with `recurring-handoff-triage-skill-candidate.md`**: this
  research is the second-cycle evidence that doc was waiting for. After
  Phase 4, update that doc's Outcome section: the prevention side reduces
  the cadence at which the bulk-triage framework needs to fire; codification
  of the bulk-triage framework as a standalone skill (Option C in that doc)
  remains deferred but the rationale shifts from "single observation" to
  "prevention rules now in place; bulk-triage is the ecosystem-wide audit
  pass, not the routine cleanup."

### Gates

- **Authorization**: skill amendments via Phase 1 do not require principal
  per-action authorization beyond the standard skill-update workflow.
  Retroactive deletions (Phase 3) require explicit YES per
  `feedback_no_public_or_tag_without_explicit_yes.md`'s analog (this
  involves irreversible filesystem ops at non-git-tracked workspace root).
- **Reversibility**: skill amendments are reversible via git; deletions
  are not. Stage the deletion list in a triage table that lives at workspace
  root for reviewer inspection; only delete after explicit batch YES.

## References

- **Skills consulted (canonical)**:
  - `swift-institute/Skills/reflect-session/SKILL.md` — `[REFL-009]` Handoff
    Cleanup, `[REFL-009a]` In-Flight-File Conservativism, `[REFL-008]`
    Cleanup Scope.
  - `swift-institute/Skills/handoff/SKILL.md` — `[HANDOFF-008]` File
    Location, `[HANDOFF-016]` Staleness Axes, `[HANDOFF-021]` Scope
    Enumeration, `[HANDOFF-029]` Pre-Fire Precondition Re-Check,
    `[HANDOFF-032]` Extraction-Time Material Check.
  - `swift-institute/Skills/corpus-meta-analysis/SKILL.md` — `[META-001]`
    Staleness Threshold, `[META-022]` Experiment Staleness Detection,
    `[META-022a]` In-Session Toolchain Revalidation Before Deferral.

- **Research consulted**:
  - `swift-institute/Research/agent-handoff-patterns.md` (SUPERSEDED by
    handoff skill) — design rationale for handoff structure, file
    location, the handoff paradox.
  - `swift-institute/Research/recurring-handoff-triage-skill-candidate.md`
    (IN_PROGRESS) — response-side complement; bulk-triage framework
    codification deferred pending second cycle (this research is that
    second cycle's evidence).

- **Reflections cited (empirical evidence for hypothesis verdicts)**:
  - `2026-04-16-reflect-session-cleanup-completeness.md` — bounded-cleanup-authority
    introduction; the failure mode this research diagnoses is its inverse.
  - `2026-04-25-platform-audit-dispatch-and-same-day-hygiene-arc.md`
  - `2026-04-26-cross-carrier-utilities-research-defer.md`
  - `2026-04-26-l1-exception-removal-skill-cycle.md`
  - `2026-04-26-lateral-l3-doc-stamp-and-platform-skill-amendment.md`
  - `2026-04-26-observable-macro-twin-design-and-validation-gap.md`
  - `2026-04-28-phase-1-5-l2-pivot-attempt-and-namespace-correction.md`
  - `2026-04-28-sub-cycle-1-1-inverted-pattern-a.md`
  - `2026-04-29-carrier-launch-arc-and-centralized-workflow-trim.md`
  - `2026-04-29-carrier-pre-release-audit-and-launch-deployment.md`
  - `2026-04-29-handoff-triage-cycle-and-d-to-a-reclassification.md` —
    origin instance of the bulk-triage framework.
  - `2026-04-30-corpus-meta-analysis-and-phase-11-completion.md`

- **Durable record of the prior triage cycle**:
  - `/Users/coen/Developer/HANDOFF-handoff-files-triage-and-cleanup-table.md`
    (Apr-29) — the input baseline for this research's accumulation
    measurement.

- **Memory feedback informing scope discipline**:
  - `feedback_user_plan_is_roadmap_not_authorization.md` — adoption
    requires per-step principal authorization; multi-step plans are
    roadmaps, not blanket authorizations.
  - `feedback_skills_follow_institute_convention.md` — skill amendments
    go to `swift-institute/Skills/` source; symlinks regenerated by
    `Scripts/sync-skills.sh`.
