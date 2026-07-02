---
date: 2026-06-04
session_objective: Independent clean-room verification of swiftlang/swift#89684 from its public body alone, then landing its reproducer as an Issues-repo entry verified on CI
packages:
  - Issues
status: processed
processed_date: 2026-07-02
triage_outcomes:
  - type: skill_update
    target: issue-investigation
    description: "Proposal collected (recommend KEEP): out-of-process reproducer-harness pattern for non-compilable triggers (ICE/crash AND rejects-valid) — .swift.txt resource, subprocess compile/typecheck, signature/exit-0/inconclusive three-way disposition, withKnownIssue flip. Verified absent (skill IDs through [ISSUE-028], no harness rule). Two shipped exemplars (FSO #89617, #89684)."
  - type: skill_update
    target: handoff
    description: "Proposal collected (recommend KEEP, clarifying fold into [HANDOFF-041]): a 'CI green' acceptance criterion MUST name the leg-set and the writer MUST check the target repo's baseline run state at write time; red-by-design baselines make run-level green structurally unattainable."
  - type: blog_idea
    description: "Proposal collected (recommend KEEP, queue when authorized): #89684 conditional-extension name capture as companion to the 2026-04-20 associated-type-trap post; same @_implements escape hatch."
  - type: no_action
    description: "Snapshot-labeling discipline (swift --version per bundle ID): already captured as memory feedback_snapshot_labels_must_match_empirical_version; no further routing."
---

# Assay: sealed-records independent verification of swiftlang/swift#89684

## What Happened

A principal-dispatched independent `/issue-investigation` ("Assay") of
swiftlang/swift#89684 — bogus `type 'Substrate' does not conform to protocol
'P'` when a conditional extension declares a typealias named after an
enclosing type's generic parameter. The dispatch's core was the
**independence protocol**: inputs restricted to the PUBLIC issue body
(`gh issue view --json body` — no comments, no edit history), clean
toolchains (purge of `~/Library/Caches/org.swift.swiftpm/{repositories,manifests}`,
fresh `/tmp/assay-*` module-cache dirs, bare `swiftc`), with the prior arc's
records (`.handoffs/.trash/`) sealed until the verdict was formed.

The published body decomposed into 11 falsifiable probes: the byte-exact
reproducer, four inconsistency-matrix rows (each with a discriminating
resolution probe; rows 2/4 also got negative probes that must fail), the
associated-type-witness variant, and three workarounds including
`@_implements` witness routing. Run on three `swift --version`-confirmed
toolchains: 6.3.2 Xcode default and 6.4-dev `2026-03-16-a` (both exact
matches for the issue's environment lines) plus 6.5-dev `2026-05-27-a`
(beyond-brief currency). **VERDICT: CONFIRMED — 11/11, zero material
divergences**; the bogus diagnostic is byte-identical down to `7:26` and the
caret block, and the `wa3` negative probe's own diagnostic named the routed
witness: `'Outer<String>.Inner<S>._P2Element' (aka 'Bool')`.

The reproducer landed as
`swift-institute/Issues/swift-issue-conditional-extension-typealias-name-capture/`
@ `15fb566` (the dispatch's single pre-authorized push; set-membership
verified pre-push, `HEAD == origin/main` post-push), adapting the
FunctionSignatureOpts entry's out-of-process subprocess harness from
crash-class (`Crash.swift.txt`, `swiftc -O`) to rejects-valid-class
(`Reject.swift.txt`, `swiftc -typecheck`). CI run 26959330763: the entry's
platform legs 4/4 green (macOS, Ubuntu 6.3 release, Ubuntu nightly — the
flip leg, green = still firing — and Windows); SwiftLint + ci-ok red
classified with receipts as the pre-existing repo-wide baseline (three
pre-push runs red on all 10 siblings; default-config SwiftLint, no repo
`.swiftlint.yml`). Post-verdict diff against the prior arc's adjudication:
full agreement; additions only (6.5-dev currency, negative probes, both
language modes). Supervisor stamped [SUPER-011] SUCCESS.

**Handoff scan ([REFL-009])**: 1 file in this session's authority —
`HANDOFF-issue-89684-independent-verification.md`: consumed (Findings +
ground-rules verification stamp appended), soft-retired to
`.handoffs/.trash/` per [HANDOFF-008a]. Out-of-authority, report-only: 38
`HANDOFF*.md` at `.handoffs/` root (12 past the [HANDOFF-038] 14-day
threshold — seat-managed space; today's Sweep retired 16) and 7 loose
`HANDOFF-*.md` at the workspace root in violation of [HANDOFF-008]'s
location rule (parser-release-sil-crash ×3, set-ordered-tagged-insert-crash,
bit-primitives-domain-decomposition, derive-for-free-capability-composition,
post-cascade-cleanup) — all other arcs', untouched. No `/audit` this session
([REFL-010] N/A). `/tmp/assay-*` probe receipts left to OS cleanup.

## What Worked and What Didn't

**Worked.** (1) The independence protocol held end-to-end and the
conversation-ordered receipts prove it — the verdict existed before any
prior-arc record was opened; the supervisor accepted on that basis. (2)
Empirical snapshot labeling (`swift --version` per bundle ID) caught that
the two NEWEST installed snapshots (2026-05-27-a, 2026-05-12-a) self-report
**6.5-dev** — "use the latest snapshot and call it 6.4-dev" would have
mislabeled the environment row AND missed the exact-match toolchain
(2026-03-16-a) sitting four directories back. (3) Negative discriminating
probes cost three extra files and produced the session's strongest receipt:
a diagnostic that literally names the witness type. (4) Exemplar-first
convention reading (the FSO entry) turned the Issues-entry design into an
adaptation exercise — zero invention needed. (5) Inspecting the CI baseline
BEFORE pushing converted "is the run green?" into a well-posed per-leg
question and pre-classified the SwiftLint red instead of discovering it
post-push as an alarm.

**Didn't.** (1) The dispatch's acceptance criterion "confirm the run is
green on all its platforms" was not satisfiable at run level against a repo
whose baseline is red by design (advisory SwiftLint on all entries +
flip-leg/evidence-leg reds); resolving it via the repo README's own
"per-issue legs are the actionable signals" was correct but cost
investigation time the brief could have pre-spent. (2) One reflexive
foreground `sleep 90` poll while a Monitor was already armed — blocked by
the harness, not self-caught ([REFL-017]'s exact failure signature, caught
by tooling rather than discipline).

## Patterns and Root Causes

**A verified issue body is a test spec.** The published body — itself the
product of the prior arc's Option-1 rewrite — decomposed mechanically into
per-claim probes because every claim was falsifiable as written (exact
diagnostic, enumerated matrix, named workarounds). Verification then cost
minutes, not hours. The inverse lesson: issue bodies that resist this
decomposition are under-specified. The "Assay" shape (sealed records +
clean room + per-claim table + post-verdict diff) is the FSO arc's
"independent fresh-eyes review" graduated into a reproducible protocol; the
sealed-records rule is what makes the confirmation epistemically additive
rather than an echo.

**Labels are claims; only tool output is fact.** A snapshot directory named
`swift-DEVELOPMENT-SNAPSHOT-2026-05-27-a` carrying a 6.5-dev compiler is the
same epistemic class as [PKG-BUILD-013]'s warm-cache "cold" build and
[REFL-011]'s tool-reach extension: an artifact's NAME encodes intent at
creation time; its CONTENT is what runs. `swift --version` per bundle ID is
the pin-assert of toolchain identity.

**Rejects-valid joins the out-of-process harness family.** The Issues
repo's subprocess pattern (trigger as `.txt` resource, staged to `.swift`,
signature-grep three-way disposition: signature→fired / exit-0→fixed /
else→inconclusive, `withKnownIssue` flip) was documented for compiler-abort
bugs but transfers unchanged to rejects-valid — only the flag (`-typecheck`
vs `-O`) and the signature change. The three-way disposition is the
load-bearing piece: a future rephrased diagnostic surfaces as inconclusive
(human re-triage) instead of a false flip in either direction.

**"CI green" is not well-posed against red-baseline repos.** A criterion
naming a run-level state silently assumes a green baseline. Repos that run
advisory legs red by design (or keep permanently-red evidence legs) make
the honest criterion per-leg. This is [HANDOFF-041]'s grep-anchoring
discipline transplanted to CI: anchor the acceptance criterion to the
structural element the prose means — here, the entry's platform test legs —
and verify the baseline before treating any red as signal.

## Action Items

- [ ] **[skill]** issue-investigation: add the out-of-process reproducer-harness pattern for bugs whose trigger cannot be a compiled target (ICE/crash AND rejects-valid): trigger as `.swift.txt` resource, subprocess compile/typecheck, signature/exit-0/inconclusive three-way disposition, `withKnownIssue` flip semantics — provenance FSO #89617 entry + this session's #89684 entry.
- [ ] **[skill]** handoff: extend [HANDOFF-041] to CI acceptance criteria — a "CI green" criterion MUST name the leg-set (per-entry platform legs vs run-level conclusion) and the writer MUST check the target repo's baseline run state at write time; red-by-design baselines make run-level green structurally unattainable.
- [ ] **[blog]** Conditional-extension name capture (#89684) as a companion to the 2026-04-20 associated-type-trap post: distinct mechanism (conditionally-available member capturing an enclosing generic parameter's name vs cross-protocol associated-type merging), same escape hatch — `@_implements` under a non-colliding name, which uniquely admits stored fields.
