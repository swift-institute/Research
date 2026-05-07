---
date: 2026-05-06
session_objective: Investigate and execute the architectural extension of L1 CI/CD to L2 + L3 + sub-orgs per HANDOFF-ci-cd-cross-ecosystem-reuse.md; produce Tier 2 RECOMMENDATION and execute the migration end-to-end.
packages:
  - swift-institute
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-ietf
  - swift-iso
  - swift-w3c
  - swift-whatwg
  - swift-ecma
  - swift-incits
  - swift-ieee
  - swift-iec
  - swift-arm-ltd
  - swift-intel
  - swift-riscv
  - swift-linux-foundation
  - swift-microsoft
status: pending
---

# Cross-ecosystem CI/CD wrapper rollout: org-hierarchy mirror principal correction, mass uniformity sweep, D4 finalization

## What Happened

Session executed a 6-question Tier-2 investigation + production rollout
for HANDOFF-ci-cd-cross-ecosystem-reuse.md. Three distinct phases:

**Phase 1 — Investigation + principal correction.** Authored
`ci-cd-cross-ecosystem-reuse.md` v1.0.0 RECOMMENDATION using strict
[CI-004] invariant-justification reading (no L2/L3 wrappers — no
documented invariants beyond universal matrix). Principal corrected:
*"CI hierarchy mirrors org hierarchy"* — wrappers exist as structural
anchors at every layer org regardless of current invariants. Authored
v1.1.0 inverting Q1/Q2 verdicts. During revision, discovered the
GitHub Actions `workflow_call` 4-level depth limit cited in
`ci-centralization-strategy.md:100` — empirically verified that the
current L1 chain (per-package → L1 wrapper → universal → advisory
linter) is exactly at the limit. Adding sub-org wrappers would push
to 5 levels, structurally blocking per-authority wrappers today.
Codified as [CI-004b] (sunsets when GitHub raises limit OR universal
is refactored to inline its 6 advisory linter sub-dispatches).

Reviewer pass produced v1.1.1 corrections: migration scope corrected
from "~280" to **262** (verified disk grep: L2 20 + L3 139 + L2
sub-orgs 101 + L3 sub-orgs 2); 4-level cap granularity nuance added
(binds 6 advisory-linter sub-dispatches only, not matrix/build/test);
[RES-018] tension explicit (layer wrappers as day-1 no-op delegations
trade ~30–90s setup overhead for zero future migration cost); L3
sub-orgs distinguished as CONSTRUCTION not MIGRATION.

**Phase 2 — Mass-rollout.** 265 commits across 18 repos in ~50 min
wall:

- 6 infrastructure commits: swift-standards/.github L2 wrapper `079fefb`,
  swift-foundations/.github L3 wrapper `f5150a6`, swift-institute/.github
  Q4 disclaimer `5044547` + lint-org-bot-coverage advisory linter
  `8cbe5c0`, swift-institute/Skills [CI-004a]/[CI-004b] amendments
  `744a4b1`, swift-institute/Research v1.1.1 doc + index `fb36fa2`.
- 1 canary commit: swift-color-standard `aa444f8` (minimal-change wrapper
  validation) → `fd30fae` (uniform-shape re-canary).
- 257 fanout commits across 4 waves: Wave 2 swift-standards proper (18),
  Wave 3 11 L2 spec-authority sub-orgs (101), Wave 4 swift-foundations
  proper (136), Wave 5 2 L3 vendor sub-orgs.

Discovery during fanout: 91/258 packages were pre-centralization inline
workflows hardcoding Swift 6.2 + caching `.build/` + `restore-keys`
partial-prefix fallback (violating [CI-040], [CI-042], [CI-011]). The
"variation" across L2/L3 packages was rule-violation noise, not novel
solutions. Wholesale `ci.yml` replacement to L1-uniform thin-caller
shape; per-package `swift-format.yml` + `swiftlint.yml` deleted per
[CI-054].

Final ecosystem state: 132 L1 + 120 L2 (incl. sub-orgs) + 138 L3
(incl. sub-orgs) = 390 consumers all routing through correct layer
wrappers. 0 stragglers. 0 forbidden workflow files.

**Phase 3 — Audit + D4 finalization + working-tree cleanup + Option A.**
Authored `ci-uniformity-audit.md` v1.0.0 INVENTORY (six dimensions):
D1 DELIBERATE-DIVERGENCE (L1 vs L2/L3 per [CI-020]; UNIFORM L2↔L3),
D2 UNIFORM (390 ci-routers + 390 docs-routers + zero drift), D3
UNIFORM (390/390 metadata.yaml schema), D4 UNINTENTIONAL-DRIFT (4 file
gaps), D5 VERIFICATION-BLOCKED (admin:org missing — defer to Sunday
cron), D6 UNIFORM (0/13 sub-org wrapper violations).

D4 community-health-sync remediation in waves:
- Cleanly mechanical: ISSUE_TEMPLATE/config.yml (`b4fd401` + `3083f00`)
  + SECURITY.md (`cdb208d` + `7cc8e50`) — sed-driven org/layer name
  substitution from L1 reference.
- Stop-conditioned 1: `.swiftlint.yml` verbatim copy refused (L1's file
  has L1-specific Foundation ban + platform-conditional ban + Cardinal/
  Ordinal/Vector enforcement — wrong for L2/L3). Surfaced; principal
  authorized Option A (Tier 2 thin pass-through with parent_config
  inheritance to swift-institute Tier 1 + zero custom rules). Landed
  at L2 `665e6be` and L3 `bfd5524`.
- Stop-conditioned 2: L3 profile/README.md fresh authorship refused
  (substantive content beyond mirror-shape). Principal: deferred to
  later in-place revision.

Working-tree cleanup (Phase A swift-standards/.github stash+pull+pop+
commit; Phase B swift-foundations/.github flat-dir → fresh-clone with
backup at `_backups/2026-05-06-swift-foundations-flat`). Both repos
on-disk now clean git checkouts.

Option A propagation: bot App grant `organization_secrets:read` for
lint-org-bot-coverage-weekly axis-2 (PRIVATE_REPO_TOKEN coverage
probe per [CI-060]). Web-UI grant + per-org acceptance; spot-check
on swift-primitives confirmed. Manifest extended at
`bot-installations.yaml` (commit `59c6723`): inferred_min sixth
entry, swift-primitives declared block updated, header transitional
note. Research seed `private-repo-secret-management-at-scale.md`
v0.1.0 IN_PROGRESS indexed (commit `7db0bb3`).

## What Worked and What Didn't

**Worked**:

- **Principal-correction loop executed cleanly**: v1.0.0 → v1.1.0
  (principal correction with explicit changelog) → v1.1.1 (reviewer
  pass) within the same session. Each version increment carried a
  surgical changelog entry capturing what flipped and why. The doc's
  audit trail survives external review.
- **4-level cap citation, not invention**: the workflow_call constraint
  was sourced from existing research (`ci-centralization-strategy.md:100`)
  and empirically verified via the canary CI run's actual job tree
  (`ci / matrix / yamllint advisory / yamllint scan` is exactly the
  4-level chain). [CI-004b]'s "sunsets when GitHub relaxes" framing
  has a verified anchor.
- **Mass-rollout via xargs + migrate-caller.sh**: Wave 3 (101 packages)
  pushed in ~3.5 min with line-buffered output via `tee`. Per-package
  `git status` dirty-skip + `git fetch` sync-check + halt-on-N-failures
  worked at scale.
- **Stop-condition discipline saved 2 destructive-or-wrong ops**:
  refused `.swiftlint.yml` verbatim copy (would have imposed L1-only
  Foundation ban + platform-conditional ban on L2/L3 — wrong content);
  refused L3 profile/README.md fresh authorship (substantive content
  beyond mirror-shape). Both surfaced for principal direction; both
  resolutions correct (Tier 2 pass-through; principal-deferred).
- **Stale-acceptance-criterion catch**: principal re-issued cleanup
  brief assuming pre-execution state; reality was post-execution from
  prior batch this session. Refused destructive revert of L3
  profile/README.md without explicit YES; surfaced explicitly.
  Principal accepted divergence ("supervisor error on the brief, not
  a subordinate execution defect").
- **Empirical 4-level chain verification**: dispatched canary run
  `25423081172` confirmed all 13 jobs reachable through the new L2
  wrapper. The 5 advisory-linter passes + 6 build/test failures
  pattern was the diagnostic key (advisory linters PASS = chain
  routes correctly; build/test FAIL = pre-existing package state,
  not migration regression).

**Didn't work / friction**:

- **Bash heredoc shell-quoting bugs (recurrence)**: `migrate-caller.sh`
  had two iterations of "unexpected EOF" — first from backslashed-
  backticks `\\\`with:\\\`` inside `$(cat <<EOF)`, then from
  apostrophe in `swift-ci.yml's`. Each cost ~5 min debugging.
  The general failure mode: bash's `"$(cat <<EOF ... EOF)"` matches
  quotes greedily across the heredoc body. Fix is to use `<<'EOF'`
  (quoted heredoc, no expansion) and substitute variables outside,
  OR avoid quote-like characters in the heredoc body.
- **Bash-tool auto-backgrounding interaction**: Wave 3's first
  invocation auto-backgrounded with `tail -10` piping; pipe-buffering
  produced silent-hang appearance. Killed orphan zsh, re-ran inline
  via xargs with `tee` for live output. Indicates the tool's
  backgrounding heuristic interacts poorly with iterative-output
  scripts; lesson is "use xargs + tee for fanout, not bash for-loops
  with pipe-tails."
- **[REFL-003] pre-edit checkpoint skipped**: directly modified
  `Skills/ci-cd-workflows/SKILL.md` (revising [CI-004] + adding
  [CI-004a]/[CI-004b]) without first loading the skill-lifecycle
  skill per [SKILL-LIFE-001]/[SKILL-LIFE-002]. The amendment was
  correct (provenance anchor present, minimal revision discipline
  observed empirically), but the procedural gate was missed. Future
  sessions touching SKILL.md directly should load skill-lifecycle
  first.
- **Migration scope estimate without enumeration**: initial brief
  claimed "~280" callers; reviewer corrected to 262 via disk grep.
  This is the [HANDOFF-021] "scope enumeration at write-time" rule
  — would have been caught at v1.0.0 write time if I'd run the
  enumeration command rather than back-of-envelope-counting from
  per-org repo counts.
- **Canary CI auto-fire anomaly on swift-color-standard**: `aa444f8`
  push didn't auto-fire CI; required workflow_dispatch to validate
  the chain. Subsequent fanout pushes auto-fired correctly. Anomaly
  isolated; root cause unknown (possibly stale GH-side webhook from
  the long-dormant repo's main-branch jump from `881a9bd` to
  `aa444f8`). Worth flagging if it recurs in mass-rollout contexts.

## Patterns and Root Causes

**Pattern 1 — Principal-correction-post-write on framing axis**
(recurrence). v1.0.0 was Tier-2-correct under [CI-004]'s strict
invariant-justification reading. Principal correction introduced a
DIFFERENT framing axis: org hierarchy as architectural primitive,
wrappers as anchors not gates. This is the second occurrence in the
corpus — first being 2026-04-24 cycle-3 framing per [RES-022], where
Doc 4 originally recommended Option B for diff-size reasons and
principal redirected to structural correctness.

Root cause: research authors default to the most recently-cited rule
when drafting, missing that a meta-axis (structural correctness, org-
hierarchy mirror) trumps. The structural axis is invisible because
it's the "default architectural primitive" — not stated as a rule
because it's assumed. v1.1.0's [CI-004a]/[CI-004b] codification makes
the architectural framing first-class (the rule body is now the
consequence of the org-hierarchy primitive, not the starting point).

This suggests a write-time discipline: when authoring Tier-2+ research
that intersects multiple framings, explicitly enumerate the framings
in the Question section, name which axis the analysis prioritizes,
and surface the alternates as "why not this framing?" sub-questions.
Catches the "missed meta-axis" failure mode at write-time rather than
principal-correction time.

**Pattern 2 — Stop-condition discipline as destructive-op safety net.**
Two file classes in D4 had instructions that LITERALLY said "Copy"
but the source content had scope-tied substance that would have been
wrong to verbatim-copy. The principal had pre-marked profile/README.md
as judgment-required; .swiftlint.yml was NOT pre-marked, but
subordinate caught it independently. Pattern: the "shared file"
abstraction can have layer-specific content embedded inside (the L1
.swiftlint.yml's header literally calls itself "Tier 2 — swift-
primitives org-specific" while its content has L1-only rules). The
proactive read-before-copy + content-judgment surface IS valuable.

The pattern generalizes: copy-instructions are not always mechanical.
When the source has scope-tied content (layer-specific, role-specific,
package-specific), the instruction needs content-judgment. Codifying
the proactive surface discipline as a handoff rule (not just a brief-
specific stop condition) makes future sessions catch this without
needing per-brief annotation.

**Pattern 3 — Stale-acceptance-criterion in re-issued briefs**.
Long-session work produces state that subsequent briefs may not
account for. The cleanup brief's "L3 profile/README.md NOT pushed
to origin" was stale relative to reality (prior batch's preserve
commit `32bb1ef` had pushed it). Subordinate caught it; surfaced
explicitly; refused destructive revert without explicit YES.
Principal: "supervisor error on the brief, not a subordinate
execution defect" + Option 2 acceptance.

The general rule: subordinates resuming or re-executing a brief
should compare brief-assumptions vs current state and surface
discrepancies BEFORE acting. Particularly when the brief implies
destructive ops to "achieve" a stated criterion.

**Pattern 4 — Bash heredoc-inside-command-substitution quote
greediness** (low-leverage but recurring). `"$(cat <<EOF ... EOF)"`
with un-quoted EOF expands variables AND matches quotes greedily
across the heredoc body. Backticks, apostrophes, and even some
patterns of curly braces can confuse the parser. Fix: `<<'EOF'`
(single-quoted, no expansion, no quote-matching) + variable
substitution outside via printf or string concatenation. Lower
leverage than the architectural patterns above, but cost ~10 min
debugging this session and has happened before. Worth a memory
entry if it recurs.

**Pattern 5 — Bash-tool auto-backgrounding with iterative-output
scripts**. The Bash tool auto-backgrounded my Wave 3 invocation
when piped through `tail -10`. Pipe-buffering produced silent-hang
appearance. Worked around with xargs + `tee`. Indicates a class
of tool-capability interaction worth understanding more
systematically — but it's an environment-specific pattern, not
a primitive.

## Action Items

- [ ] **[skill]** handoff: codify the stale-acceptance-criterion-in-re-issued-briefs pattern as a new [HANDOFF-N] rule. When a brief's literal text assumes a state different from current reality (because an earlier batch already executed part of the work), the subordinate MUST: (a) execute only the genuinely-new work; (b) surface the discrepancy explicitly in the acknowledgment; (c) refuse destructive ops to "achieve" stale criteria without explicit YES; (d) suggest "principal authoring error, not execution defect" framing as the natural resolution path. Cross-references [HANDOFF-016] (staleness axes — adds a seventh axis: brief-assumption staleness) and [HANDOFF-018] (opt-out clauses are preferences not permissions).

- [ ] **[skill]** handoff: codify proactive read-before-copy content-judgment as a stop-condition class. When a brief instructs "Copy file X to Y" and the subordinate's pre-edit read of X reveals scope-tied content (layer-specific rules, role-specific text, package-specific framing), the subordinate MUST proactively surface this as a stop-condition class even if the brief did not pre-mark it. Cross-references [HANDOFF-013a] (writer-side prior-research grep), [HANDOFF-013b] (build-level visibility pre-flight), and [HANDOFF-018]. New rule [HANDOFF-N+1] under the writer-side discipline family.

- [ ] **[doc]** swift-institute/Research/ci-uniformity-audit.md: update D4 status post-this-session — change D4 verdict from UNINTENTIONAL-DRIFT to RESOLVED 2026-05-06 (modulo L3 profile/README.md principal-deferred per Option 2 acceptance). Document the resolution in v1.1.0 with a brief changelog entry citing this reflection. Cross-reference the L2 .swiftlint.yml at `665e6be` and L3 .swiftlint.yml at `bfd5524`; the L2 SECURITY.md at `cdb208d` and L3 SECURITY.md at `7cc8e50`; the L2 ISSUE_TEMPLATE/config.yml at `b4fd401` and L3 ISSUE_TEMPLATE/config.yml at `3083f00`.
