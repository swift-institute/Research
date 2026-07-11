---
date: 2026-07-11
session_objective: Execute the overnight dispatch (CI verification after the tools-6.3.3 checkpoint push + lint-arc waves), then morning adjudications and close-out
packages:
  - swift-institute/.github
  - swift-markdown-html-render
  - swift-pdf-html-render
  - swift-css
  - swift-html
  - swift-webpage
  - swift-ieee-754
  - swift-standards
  - swift-graph-primitives
  - swift-rfc-4648
  - swift-ascii
  - swift-sockets-standard
  - swift-buffer-ring-primitives
  - swift-rfc-791
status: pending
---

# Overnight CI heal + t002 lane-B close (fleet red root-caused; ledger-vs-detector divergence)

## What Happened

Overnight session dispatched via `HANDOFF-overnight-2026-07-10.md`. The
tools-6.3.3 checkpoint push had turned 377/416 public repos red. Root-caused
to TWO defects in the universal reusable: (1) the new Identity-conflict
fast-check step exits 127 on all `swift:*` container legs — minimal images
lack python3 (the prior fix `f112502` installed curl only); (2) macOS/
simulator legs pinned Xcode 26.4 (Swift 6.3.1), which cannot load 6.3.3
manifests. One commit fixed both (`.github` `c540822`); a canary run
validated both legs green; 374 `workflow_dispatch` runs healed the fleet
(the `ci-<ref>` cancel-in-progress concurrency group REPLACED the doomed
queued runs — queue-time reclaimed, not waited out). By morning ~60–65% of
completed re-runs were green vs 2% pre-fix; residual reds matched known
pre-existing classes, plus one newly named defect (swift-async: 10
isolation-preservation tests fail on Linux only).

Lint arc: wave-0 (106 L2 `Bundle.standards` flips) re-derived from git as
ALREADY COMPLETE. The real workload became t002 lane B: a fresh local
detector over the 119-repo worklist found 38 repos/111 hits where the
ledger implied far less; lanes verified every hit — 30 suites restructured/
merged across 16 repos (all build+test gated, counts preserved, pushed),
11 repos verified already-compliant/(c)-residue, 5 orchestrator-pre-screened.
Four structural transform gaps surfaced (protocol-hosted suites,
reserved-keyword `.Protocol` hosts, cross-target Test-suite invisibility,
(b)-form collision fallback) — all codified into [SWIFT-TEST-003]
(`Skills` `1c4b35c`) after principal ratification. New [CI-113]
(toolchain-floor pre-flight) codified (`3c9ccc4`).

Morning adjudications (principal-ratified, all executed): swift-css checkout
back to main; swift-html WIP split (tools bump committed `973fba4`, redundant
re-export deleted, Translating trait left as lane-owned WIP) via
temporary-edit → commit → re-apply; swift-webpage LinkColor.swift landed
(`2b8727e`); Research divergence resolved (commit-first on `.cadence.log`,
duplicate reflection commit dropped via `rebase --onto` after proving its
content byte-identical on origin). Relay report:
`Workspace/handoffs/REPORT-relay-2026-07-11.md`.

HANDOFF scan ([REFL-009]): guards run — memory guard OK (0 topic files,
inbox within cadence); handoff store reads 72>40, red by the documented cap
ruling (drain per-arc at close; no bulk re-triage). 2 files in this
session's authority: `HANDOFF-overnight-2026-07-10.md` — consumed, retired
to `.trash/` (commit `cc63f9cd`); `HANDOFF-workspace-pivot-2026-07-10.md` —
LIVE daytime arc, annotated in place (Open Questions 7–10 marked resolved,
1–6 remain). All other store files out of session authority — untouched.
No loose root handoffs. No `/audit` run this session — no finding statuses
to update.

## What Worked and What Didn't

Worked: the resume protocol's verify-don't-trust stance paid for itself
three times — the handoff's cited `ci-red-classification-early.tsv` did not
exist (found the real artifacts), wave-0 was already complete (avoided
redundant dispatch), and the pdf-html-render "case rename" first appeared
WRONG until [PKG-BUILD-012] surfaced a stale resolved pin. The canary +
fleet-dispatch sequencing worked exactly as designed, and concurrency-group
replacement of doomed queued runs was the single highest-leverage move of
the night. Subagent lanes with the frozen brief + explicit amendments were
uniformly reliable (16/16 gates green, several principled escalations
instead of improvisation).

Didn't: three monitor scripts had to be re-armed for scripting defects (zsh
reserves `status`; `gh` returns `""` not null for queued-job conclusions;
a backtick in a double-quoted echo executed as command substitution and
mangled an inbox line). The rollup lens (statusCheckRollup) was silently
wrong for the heal phase — it does not reflect `workflow_dispatch` runs, so
the first "settle" monitor concluded a wave that had not started; the
latest-run lens was the correct instrument. Low confidence initially about
whether reruns re-resolve the reusable `@main` ref (they do not — they pin
the original SHA); establishing that early would have saved one canary
cancel-and-replace cycle.

## Patterns and Root Causes

**A mass change's blast surface includes every execution environment, not
just the target repos.** The fleet normalization verified the manifests but
not the machines that load them — CI runners, container images, SDK bundles.
The same shape as [PKG-BUILD-001]'s toolchain-selection lesson, one level
up: config declared ≠ config loadable everywhere it must load. Now
mechanized as [CI-113] (pre-flight all six surfaces, workflow-first, canary).

**Ledgers are claims; trees are truth — in BOTH directions.** The drain
ledger simultaneously UNDER-claimed (wave-0 "in progress" was complete) and
OVER-claimed ("nothing-to-fix" repos carried genuine misses; a drained
repo's TSV predated suites added later). The honest re-derivation was a
fresh detector sweep + per-repo lane verification, exactly [HANDOFF-016]
extended to wave resumption: a resumed wave re-detects, never re-reads its
own ledger. The 07-09 harvest bug (Sources-only regex) is the same disease
— the measurement instrument, not the work, was the defect.

**Tool-reach mismatches were the night's dominant epistemic failure class**
([REFL-011] tool-reach extension, four instances): rollup-vs-dispatch runs,
loop-counter-vs-state, `""`-vs-null conclusions, and the brief's pinned
6.3.2 toolchain unable to open 6.3.3 manifests. In each case the tool's
output was narrower than the claim being read off it. The fix was always
the same: name the claim's scope, then check the instrument actually
reaches it.

**Queue-time is a schedulable resource.** Cancel-in-progress concurrency
groups convert "wait for doomed work to drain" into "replace doomed work
in place" — the fleet dispatch was effectively a queue rewrite. Worth
remembering for any future fleet-wide CI event.

## Action Items

- [ ] **[skill]** ci-cd-workflows: workflow-authoring.md — add the CI
  verdict-lens rule: `statusCheckRollup` does NOT reflect
  `workflow_dispatch` runs and re-runs PIN the original reusable SHA;
  fleet-heal verification must use the latest-run lens
  (`gh api repos/<nwo>/actions/workflows/ci.yml/runs`), and heal-after-
  reusable-fix must be fresh dispatches, never re-runs.
- [ ] **[package]** swift-async: Linux-only failure of the 10
  isolation-preservation tests (macOS green; run 29125672706 job
  86473782042) — actor-isolation semantics diverge on corelibs; needs a
  dedicated triage lane.
- [ ] **[skill]** handoff: scope-discipline.md — clarify [HANDOFF-016] for
  wave resumption: drain-ledger entries ("drained", "nothing-to-fix",
  "already-compliant") are claims that MUST be re-derived by fresh
  detection when a wave resumes; both under- and over-claiming occurred
  2026-07-11 (evidence: wave-0 complete-but-unrecorded; swift-ascii
  nothing-to-fix carrying 3 genuine misses).
