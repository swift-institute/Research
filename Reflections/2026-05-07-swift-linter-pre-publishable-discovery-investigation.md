---
date: 2026-05-07
session_objective: Branching discovery investigation per [RES-012]/[RES-013] — fresh-eye review of swift-linter ecosystem post-cohort, prioritized plan for next-session investments
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-manifest-primitives
  - swift-primitives/swift-linter-primitives
  - swift-primitives/swift-tagged-primitives
status: processed
processed_date: 2026-05-07
triage_outcomes:
  - type: skill_update
    target: release-readiness
    description: "[RELEASE-007] Empirical Example-Compile Gate added"
  - type: skill_update
    target: release-readiness
    description: "[RELEASE-008] Filter-Parameter Runtime-Enforcement Test Gate added"
  - type: research_update
    target: tool-path-env-var-fallback-pattern
    description: "Research/2026-05-07-tool-path-env-var-fallback-pattern.md authored as IN_PROGRESS"
---

# swift-linter Ecosystem Pre-Publishable Discovery Investigation

## What Happened

Branching investigation dispatched into a fresh chat to inventory the
swift-linter ecosystem at HEAD post-cohort (post-Phase-B.4 wave-1
encoding). Read-only authority, [RES-012] discovery / [RES-013] design
audit methodology, no source or research-doc edits. Output: appended
`## Findings` to `HANDOFF-pre-publishable-inventory-and-planning.md`
covering 8 inventory categories, 3 priority bands, recommended
sequence (D1–D9), 4 A/B/C strategic decisions, 10-row risk register,
and ≤350-word report-back to parent supervisor.

Verification: all 6 ecosystem repos clean entry + clean exit (zero
edits by this session); HEADs cited in findings; 7 acceptance criteria
all verified.

Method: parallelized two general-purpose agents — (1) read 8 cohort
reflections + 2 research docs (consumer-syntax v1.0.1, canonical-tier),
(2) audit 12 rule modules — while I directly read engine + linter-
primitives + manifest + manifest-primitives + consumer PoC source. Two
agents returned ~1500-word reports; I synthesized + read remaining
files (engine reporters, README's, Package.swifts) directly.

HANDOFF-scan disposition (per [REFL-009]): one in-scope file —
`HANDOFF-pre-publishable-inventory-and-planning.md`. Investigation
COMPLETE; findings written; [SUPER-011] verification stamped. Per
disposition table, all-items-completed normally → delete. Counter-
indication: workspace root is NOT a git repo (`Is a git repository:
false`); deletion would lose the deliverable since the parent supervisor
has not yet read the findings. Disposition: leave the file in place
with the embedded `## Findings` and `[SUPER-011]` stamp as the
durable record (the principal reads it next; deletion is the principal's
call after consumption).

Other handoff files at workspace root (38–39 per Reflections 2/3/5/7)
are out-of-authority for this session — bounded cleanup applies only
to files this session wrote/worked. Stale-override per [HANDOFF-038]
not applied (those files are tracked by their own authoring sessions
or the parallel cohort streams).

## What Worked and What Didn't

**Worked**:

- **Parallel agent dispatch** for the two highest-token-cost reads
  (8 reflections + 2 research docs in one agent; 12 rule audits in
  another) freed my main context for the engine + primitives + manifest
  + consumer PoC source reads. Net effect: one parallel cycle covered
  what would otherwise have been ~25 sequential reads.
- **Skill-loading-first per dispatch instruction**: loading
  research-process / handoff / supervise / release-readiness up front
  produced the [RES-012/013], [HANDOFF-013a], [SUPER-009/011],
  [RELEASE-001/002/003] vocabulary the findings + recommendations
  needed.
- **Cohort-reflection reads before code reads**: the 10 documents
  surfaced the carry-forwards (Phase B.2/B.3, Wave-2, P5–P7), open
  research questions (Q1–Q6), and the v1/v2/v3 phasing — which let
  the per-finding prioritization be roadmap-aware instead of treating
  every gap as equally urgent.

**Didn't**:

- **Hardcoded workspace-fallback in Driver.Driver was not anticipated**.
  No prior reflection flagged it; the cohort reflections covered
  modularization, decouple, code-surface cleanup, and Stream 2/3
  polish but not "what runtime paths leak into post-decouple
  configuration?" The Driver only surfaces the leak on first
  external-adopter run; the cohort dispatch never had that scenario
  cross its boundary.
- **README-non-compile pattern was 4-of-5**: every customer-facing
  README had at least one non-compiling example (compound module
  imports `import Linter Rule X` is the recurring class — Swift
  module names cannot contain spaces; the institute's spaces-in-product-
  names convention silently masks the underscore-form import
  requirement until empirical run). This is a systemic gap — not a
  one-off — and current release-readiness skill ([RELEASE-001/002])
  does not mandate empirical example-validation.
- **Path.Filter unenforced** (Lint.Run never reads `entry.paths`)
  is the kind of API-surface-vs-runtime-enforcement gap that's
  invisible to per-rule unit testing. A pure-rule-test world thinks
  the API works; only an end-to-end fixture run would catch it.
- **Tier 1/Tier 2 canonical Lint.swift declare empty rule lists** —
  the chain inheritance README narrative is structurally non-functional
  at publish time. Two cohort reflections (2 + 4) note Tier 1/Tier 2
  scaffolding shipped but neither flags that "scaffolding shipped"
  isn't "rule list populated."

## Patterns and Root Causes

The 4-of-5 README non-compile rate is the symptomatic pattern.
Underneath: every README copies a code block from in-session prose
(skills, commit messages, handoff notes) where Swift's spaces-in-product-
name convention reads cleanly to humans (`Linter Rule Unchecked` is
the SwiftPM product name, the directory name, and the symbol the brain
groups as a noun phrase). That same human-readable form does NOT
import — the import statement requires the underscore-replaced module
name (`Linter_Rule_Unchecked`). The cohort sessions wrote READMEs at
the end, after the human-readable noun-phrase form had been internalized
through ~30 commits of usage; the underscore-replaced compile-required
form gets invisibly dropped at the README composition step.

The institutional countermeasure is mechanical: every README example
MUST compile when extracted as-is. The release-readiness skill does
not currently enforce this. Carrier-primitives' release-readiness
brief / final pre-release scan reference templates ([RELEASE-001/002])
have phase-3 checklist items for "README install snippet matches
version" but not "README examples compile." This investigation surfaced
the gap; the next cohort needs the rule before its first publish.

The Driver workspace-path-fallback pattern is a different class —
"runtime resolution that works in the development environment will
silently work-but-misbehave in adopter environments." `SWIFT_LINTER_PATH`
unset → fallback to `/Users/coen/Developer/...` → adopter doesn't have
that path → path resolution silently fails → empty configuration → zero
findings → adopter thinks linter is broken. The cohort's "runs locally
during architecture cohort" invariant masked the leak; the discovery
investigation surfaces it as the first non-developer run.

The Path.Filter unenforced pattern surfaces the same class as
"feature shape exists in API but doesn't fire" — declared in
linter-primitives, factory methods accept `paths:`, the parameter is
threaded through `Lint.Rule.Configuration`, and then `Lint.Run.run`
ignores it. Per-rule unit tests don't catch this because each rule
operates in isolation. Only an integration test that activates a rule
WITH a `paths:` filter, runs against a directory containing both
in-scope and out-of-scope files, and verifies findings come from the
in-scope subset only would expose the gap. This is the same class
as the README-non-compile gap: a feature-mention-vs-feature-fire
crosswalk that no current skill mandates.

## Action Items

- [ ] **[skill]** release-readiness: Add explicit Phase-3 check item per [RELEASE-001]: "Every README/DocC/skill example MUST be empirically validated — compile or run as-extracted-from-the-doc." Provenance: 4-of-5 swift-linter cohort packages had non-compiling READMEs at post-cohort discovery investigation; the institute-internal noun-phrase convention silently masked the underscore-required import form.
- [ ] **[skill]** release-readiness: Add Phase-3 check: "Every public-API surface element with a filter parameter (paths, included, excluded, etc.) MUST have a runtime-enforcement test demonstrating the filter narrows behavior end-to-end." Provenance: Lint.Rule.Configuration's Path.Filter declared at L1, factory-accepted, threaded through Configuration, but `Lint.Run.run` ignores `entry.paths` — pure unit-test discipline missed it.
- [ ] **[research]** Hardcoded workspace-fallback pattern in environment-variable-driven path resolution. What's the institute pattern for `<TOOL>_PATH` env-var-or-fail vs env-var-or-fallback in tools deployed beyond the developer's workspace? Provenance: swift-linter Driver fallback to `/Users/coen/Developer/swift-foundations/swift-linter` literal path; the leak only surfaces on first non-developer run.
