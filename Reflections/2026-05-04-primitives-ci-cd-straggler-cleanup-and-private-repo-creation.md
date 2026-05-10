---
date: 2026-05-04
session_objective: Bring 3 unpublished L1 primitive packages (semilattice, glob, observation) to infrastructure alignment with the reference primitives shape and create as PRIVATE GitHub repos.
packages:
  - swift-algebra-semilattice-primitives
  - swift-glob-primitives
  - swift-observation-primitives
  - swift-path-primitives
  - swift-ordinal-primitives
  - ci-cd-workflows
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction DocC-catalog -> docs-job coupling rule covered by existing [DOC-019a] convention; explicit promotion candidate but not high-value. swift-glob-primitives docs-job item is package-implementation tracked in package todo.
---

# Primitives CI/CD straggler cleanup and PRIVATE repo creation for unpublished L1 packages

## What Happened

This session continued a multi-phase CI/CD invariants rollout. Prior session phases (summarized): empirical visibility-gate verification on PUBLIC + PRIVATE canaries → production cutover landing the `if: ${{ !github.event.repository.private }}` gate in three reusable workflow files (swift-institute swift-ci.yml + swift-docs.yml; swift-primitives swift-ci.yml layer wrapper) → Step D mass-enable of 85 disabled CI workflows → Step F pivot from research doc to a new `ci-cd-workflows` skill (single-file, 21 rules, [CI-NNN] prefix) including an exact-match-only carve-out for the L1 embedded job and a Known Non-Conformances sub-section in [CI-040], later resolved with SHAs preserving audit trail.

The current continuation handled the final 3 stragglers — packages with no GitHub remote — bringing them into ecosystem alignment.

**Inventory comparison vs swift-witness-primitives reference**:

| Artifact | semilattice | glob | observation |
|---|---|---|---|
| `.gitignore` | ✓ tracked | ✓ tracked | ✓ tracked |
| `.swift-format` | ✓ tracked | ✗ missing | ✓ tracked |
| `.swiftlint.yml` | ✓ tracked | ✗ missing | ✓ tracked |
| `LICENSE.md`, `Package.swift` | ✓ ✓ | ✓ ✓ | ✓ ✓ |
| `.github/` directory | ✗ missing | ✗ missing | ✗ missing |
| `Audits/` on disk but tracked? | on disk, NOT tracked ✓ | n/a | on disk, NOT tracked ✓ |
| DocC catalog | ✓ | ✗ | ✓ |
| `Tests/` | ✓ | ✗ (Package.swift declares no test target) | ✓ |
| Git remote `origin` | none | none | none |

The first-pass inventory used bare `ls` and missed dotfiles, producing a false-negative gap analysis (claimed semilattice was missing `.swift-format` — actually present). Re-ran with `ls -la` + `git ls-files` for the corrected view.

**User-flagged proactive correction mid-task**: *"see also the gitignore skill — Audits should NOT be committed/tracked."* Verified empirically via `git ls-files`; the canonical `.gitignore`'s `/* + whitelist` pattern correctly excludes `Audits/` in semilattice + observation (it is not on the whitelist). No defect surfaced; the user's flag was a memory-of-past-pain prompt rather than a current finding.

**Authoring + commit + create + push**:

- 3 per-package `metadata.yaml` (descriptions per [GH-REPO-011] L1 template; topics from [GH-REPO-021] default registry plus one inline-extension `observation` per [GH-REPO-021](b) with justification commented in the YAML).
- 3 per-package `ci.yml` (semilattice + observation get the DocC docs job per [DOC-019a]; glob ci-only because it has no `.docc` catalog).
- 6 uniform copies from witness reference (`.swift-format`/`.swiftlint.yml` → glob; `dependabot.yml` + `swift-format.yml` + `swiftlint.yml` workflows → all 3).
- 3 commits; 3 `gh repo create swift-primitives/<name> --private --source . --remote origin --push` invocations — all clean.
- 3 `gh repo edit --add-topic` invocations.
- 3 `gh repo view --json visibility,description,homepageUrl,repositoryTopics` verifications: all PRIVATE; description, homepage, topics match `metadata.yaml`.

**Final state**:

| Repo | Visibility | Topics |
|---|---|---|
| swift-primitives/swift-algebra-semilattice-primitives | PRIVATE | primitives, algebra, math |
| swift-primitives/swift-glob-primitives | PRIVATE | primitives, parsing, file-system |
| swift-primitives/swift-observation-primitives | PRIVATE | primitives, observation, type-safety |

**HANDOFF scan** (per [REFL-009]): 17 files found across `/Users/coen/Developer/` (10) and `swift-institute/` (7); 0 in this session's bounded cleanup authority (the only in-scope handoff was `HANDOFF-ci-cd-invariants-rollout.md`, deleted in the prior session phase); 0 deleted, 0 annotated, 17 out-of-session-scope.

**Audit findings cleanup**: no audit findings addressed this session. N/A.

## What Worked and What Didn't

**Worked**:
- Parallel file authoring (`Write × 6` in one batch) was efficient and self-evidently correct.
- `gh repo create --source . --remote origin --push` is the clean one-shot path for fresh-repo creation; avoids the manual `git remote add` + `git push -u origin main` chain.
- The visibility gate landed in earlier session phases means all CI jobs will appropriately skip on these PRIVATE repos. Zero billing burn until eventual public flip.
- User's proactive Audits/ flag caught no defect (canonical `.gitignore` already handles it), but verifying empirically (rather than dismissing on the assumption the rule was enforced) was the right discipline.

**Didn't**:
- Initial inventory pass with bare `ls` produced false-negative gap analysis. The discrepancy surfaced when a follow-up `git ls-files` showed `.swift-format` was already tracked in semilattice. The right inventory tool for repo infrastructure (which is largely dotfiles) is `ls -la` or `git ls-files`, not `ls`.
- Bash command-chaining bug in a multi-package status check: `cd dirA && git ls-files | head; echo "==="; git ls-files | head; echo "===other==="` ran the second `git ls-files` in `dirA` again because the second `cd` was missing. Caught from output (identical content under the "other" header). Habit fix: prefer `for pkg in ...; do cd "$pkg" && ...; done` over interleaved manual `cd` + bare commands.

## Patterns and Root Causes

**Dotfile-inventory false negative**. Bare `ls` hides dotfiles. The canonical inventory of repo infrastructure files (`.gitignore`, `.swift-format`, `.swiftlint.yml`, `.github/`) is mostly dotfiles, so bare `ls` is the *wrong tool by default* for this comparison. The right tools are `ls -la` (filesystem state) or `git ls-files` (tracked state). Picking the wrong tool produces a false-negative gap that survives until a follow-up tracked-file check reveals the lie. The pattern recurs in every infrastructure-comparison task; the cost of using `ls -la` from the start is zero. This is a low-frequency one-off in this session — not yet skill-worthy on its own — but worth flagging mentally as "infrastructure inventory ⇒ `ls -la` or `git ls-files`, never bare `ls`".

**DocC-catalog → docs-job coupling is invisible to ci-cd-workflows**. Each package's `ci.yml` has-or-doesn't-have a docs job depending on whether the package has a `.docc` catalog. The pattern is followed mechanically (semilattice + observation include the docs job; glob doesn't), but the coupling is not codified — a future package author who adds a DocC catalog must remember to also add the docs job to `ci.yml`. Since the pattern is uniform across all packages with DocC catalogs, it deserves a normative rule in the ci-cd-workflows skill rather than living as implicit precedent. This is also a useful test of whether the skill's reusable-consumption pattern ([CI-030]) is fully self-describing — currently it is not.

**[GH-REPO-021](b) inline-extension loop worked cleanly**. The `observation` topic isn't in the default registry; per the (b) clause, an inline extension with a one-line justification in the `metadata.yaml` comment is permitted, and the next 90-day skill review folds the new tag into the default registry per [SKILL-LIFE-012]. This is the design-as-intended path; the friction-cost of authoring the inline-extension comment was low (one comment line) and the registry will accumulate organically. No action item needed; flagging only as a confirmation that the rule's hybrid-governance form is empirically usable.

**User-flagged proactive concern → empirical verification**. The user wrote *"see also the gitignore skill — Audits should NOT be committed/tracked"* mid-task. The reflexive response would be either (a) "yes, confirmed" without checking, or (b) re-running the gitignore enforcement. The correct response was (c) verify empirically via `git ls-files` against current state, which confirmed the canonical rule was already enforcing. This pattern — *user surfaces concern from memory; agent verifies against current state rather than transcribing from memory* — is exactly [REFL-011] (correction-from-primary-source rule) generalized to user-driven concerns: re-fetch the primary source (in this case, `git ls-files`), don't transcribe from prior context.

## Action Items

- [ ] **[skill]** ci-cd-workflows: Codify the DocC-catalog → docs-job coupling as an explicit rule. Propose [CI-031] (or extension to [CI-030]) stating: "A package's `ci.yml` MUST include the docs job (per [DOC-019a]) iff the package contains a `.docc` catalog. Adding a `.docc` catalog later requires adding the docs job in the same commit." Currently the coupling is implicit precedent only.
- [ ] **[package]** swift-glob-primitives: When a `.docc` catalog is later added to this package, the docs job MUST be added to `.github/workflows/ci.yml` per [DOC-019a]. The current `ci.yml` is ci-only because no catalog exists yet.
