---
date: 2026-05-07
session_objective: Land the pre-publishable polish handoff (skill update + 4 README polishes + 1 research doc) and push to origin/main on per-action authorization.
packages:
  - swift-institute (Skills repo)
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-manifest-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: skill_update
    target: handoff
    description: "[HANDOFF-042] Pre-Existing Code in Scope Existence Verification added"
  - type: skill_update
    target: supervise
    description: "[SUPER-032] Push-Bundle Discipline at Terminal Authorization added"
  - type: research_update
    target: clean-build-first-elevation
    description: "Research/2026-05-07-clean-build-first-elevation.md authored as IN_PROGRESS"
---

# Stream 2 — Pre-Publishable Polish Cohort Execution

## What Happened

Executed `HANDOFF-pre-publishable-polish.md` end-to-end. Four polish items
landed across five repos in seven commits:

| Item | Repo | Commit |
|---|---|---|
| 1 — `[PKG-DEP-001]` path-form-as-safe-default for cross-repo deps | swift-institute/Skills | `bf63961` |
| 2 — swift-linter "Two consumer shapes" section (inert single-file fallback note + migration breadcrumb) | swift-foundations/swift-linter | `c34c489` |
| 3 — Canonical-tier rule activation cascade research doc + Research/_index.json (Tier 2 RECOMMENDATION) | swift-foundations/swift-linter | `10ce148` |
| 4a — swift-linter README evaluator-audience polish | swift-foundations/swift-linter | `f55cafa` |
| 4b — swift-linter-rules README rewrite (catalog + authoring guide) | swift-foundations/swift-linter-rules | `ce934f7` |
| 4c — swift-manifests README authored from scratch | swift-foundations/swift-manifests | `771d7fc` |
| 4d — swift-manifest-primitives README polish | swift-primitives/swift-manifest-primitives | `2be92bc` |

`swift build` ran green on all four touched packages. `swift-linter`
required a `rm -rf .build` clean-rebuild — the incremental build first
failed with `ld: symbol(s) not found for architecture arm64` referencing
Binary primitives symbols, which cleared after the cache wipe.

Push wave shape was split: 4 of 7 commits pushed mid-stream
(principal-initiated on Skills + swift-linter); 3 of 7 pushed at terminal
under explicit "YES PUSH" authorization (swift-linter-rules, swift-manifests,
swift-manifest-primitives). One mechanical glitch during the terminal push:
the third command in a parallel-Bash batch executed without an explicit
`cd`, ran from the previous step's cwd, and reported "Everything up-to-date";
caught immediately and re-ran the push from the right cwd.

`HANDOFF-pre-publishable-polish.md` was stamped with a `[SUPER-011]`
verification block before the reflection invocation: per-item ✓ table,
acceptance-criteria ✓ table, push-timing table, and two
discipline-observation entries.

Discovered en route that `swift-foundations/swift-linter/Research/`
contained 8 docs but no `_index.json` — a pre-existing `[RES-003c]` gap.
Bundled the index creation into the Item 3 commit alongside the new
research doc, since the brief read "Item 3 (research doc + _index.json
update; bundles since they're co-located)."

**HANDOFF scan**: 39 files found at `/Users/coen/Developer/`; 1 deleted
(`HANDOFF-pre-publishable-polish.md` — in-scope; all four items landed,
all six supervisor ground-rules verified per the `[SUPER-011]` stamp,
push wave complete to 5 of 5 repos, no pending escalation); 38
out-of-session-scope (per `[REFL-009]` bounded cleanup authority — this
session did not author them, did not work their items, and did not
encounter their completion signals during this session's work). The
out-of-scope set is left for whichever sessions own those items.

## What Worked and What Didn't

**Worked**:

- The per-item commit pattern produced a clean diff hierarchy:
  one commit per discrete deliverable, no entanglement. Every commit
  message stands as a self-contained change record — useful for the
  push wave's bundled review.
- Loading the relevant skills upfront (`swift-package`, `readme/`,
  `research-process`, `skill-lifecycle`, plus `readme/sub-package`)
  gave the right reference frame for each item without round-trip
  rule lookups mid-edit.
- The handoff's per-item draft text for Items 2 + 3 was operational
  enough to follow directly with light skill-conformance edits
  (no `[README-026]` rule-ID citations in prose, no `[README-016]`
  pre-tag interim notes).

**Didn't**:

- The clean-build link error on swift-linter would have surfaced
  faster with a default `rm -rf .build` before verification. The
  symptom (Binary primitives symbol not found) read like a real
  source defect for several seconds before recognizing it as cache
  staleness.
- Push timing was not bundled: 4 commits pushed mid-stream by the
  principal, 3 at terminal under per-action authorization. Per-action
  authorization at TERMINAL is meant to be a single signal; interleaved
  pushes degrade that signal into "is this commit authorized?" round-trips
  the discipline was designed to eliminate.
- The third parallel-`cd` Bash command ran from the previous step's
  cwd. Parallel `cd && cmd` patterns inside a single Agent turn don't
  share cwd state across the parallel calls, but successive serial
  commands DO inherit the previous call's cwd. Mixing the two forms
  risks silent mis-targeting; the fix is either explicit `cd` on every
  command or strict serial sequencing.

## Patterns and Root Causes

**The `_index.json` gap was a side-symptom of the handoff being
ahead of the artifact**. The handoff's "Pre-Existing Code in Scope"
table said `Research/_index.json` was **Updated** — present tense,
implying existence. The file did not exist. This is a small instance
of `[RES-023]` (empirical claims about live state) firing on the
handoff itself: a planning artifact's claim about an external file's
existence aged silently between drafting and execution. The fix at
execution time was bundled-creation; the fix at handoff-write time
would have been a quick `ls` to verify the file's status. Worth
codifying for handoff authoring: any `Pre-Existing Code in Scope`
row claiming an existing artifact MUST be `ls`-verified at handoff
write time.

**Push-timing interleaving is the supervisor-rhythm equivalent of
the test-pyramid inversion** — work that should batch at one signal
gets split across several. Each mid-stream push collapses some of
the bundled-review value: the principal has already integrated a
subset by the time the terminal `YES PUSH` arrives, so the terminal
authorization decides only the residue. The discipline still holds
(every push had explicit authorization, just split), but the
information-shape of the per-action gate degrades when interleaved.
The corrective is mechanical: hold all pushes for the terminal
signal unless the principal explicitly directs mid-stream pushes
for unblocking reasons. This is the rhythm-axis sibling of
`feedback_user_plan_is_roadmap_not_authorization` — same concern,
different surface.

**The clean-build link error is the recurring class
`feedback_clean_build_first` already names**. The cohort wasn't
expected to need it (no source changes, only docs); but the prior
cohort's incremental build state aged through three days of
unrelated Binary-primitives churn. When the verification phase
rebuilt against that aged state, the linker failed to resolve a
symbol whose mangling had drifted between the cached object and
the current source. The pattern: any verification phase running
against a `.build` directory older than the most recent
ecosystem-wide change should clean first. This is a stronger form
of the existing memory rule — currently advisory ("rm -rf .build
before debugging unexpected failures"), should perhaps be
preemptive ("clean .build before verification when ecosystem
churn has occurred since last build").

## Action Items

- [ ] **[skill]** handoff: Add a write-time rule that "Pre-Existing
  Code in Scope" rows claiming existence of an artifact MUST be
  `ls`-verified at handoff authoring. Generalizes `[RES-023]` to
  the handoff-authoring pre-write checklist.
- [ ] **[skill]** supervise: Codify push-bundle discipline — when a
  handoff specifies "per-action authorization at TERMINAL," all
  pushes hold until that single signal unless the principal
  explicitly directs mid-stream pushes for unblocking reasons.
  The terminal signal's information-shape degrades when interleaved.
- [ ] **[research]** Should the `feedback_clean_build_first` memory
  rule be elevated from advisory ("rm -rf .build before debugging")
  to preemptive ("clean .build before verification when ecosystem
  churn has occurred since last build")? The 2026-05-07 swift-linter
  link error is the second instance in the recent record; a third
  would push the recommendation toward preemptive form.
