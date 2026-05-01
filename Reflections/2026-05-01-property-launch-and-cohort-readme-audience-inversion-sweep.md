---
date: 2026-05-01
session_objective: Execute the swift-property-primitives 0.1.0 public flip per HANDOFF.md and handle whatever cohort-wide cleanup surfaces during the post-launch process.
packages:
  - swift-property-primitives
  - swift-carrier-primitives
  - swift-tagged-primitives
  - swift-ownership-primitives
  - swift-institute
status: pending
---

# Property-primitives 0.1.0 launch + cohort README audience-inversion sweep

## What Happened

Session opened on a property-primitives 0.1.0 public-flip handoff (squash → force-push → public flip → CI watch → Actions cleanup). Sequenced through the original Next Steps:

1. Pushed `f63dd57` (readiness commit) → `0d6b11b`-precursor `6f0ce3e` (URL conversion to `branch: "main"`).
2. Composed the canonical `Initial publication` commit message; squashed; force-pushed with explicit `YES DO NOW`; flipped repo to PUBLIC with the same authorization in the same message.
3. CI on the parentless commit `e9d8b56` returned `SwiftLint: startup_failure` and `Swift Format: startup_failure` immediately. Investigation surfaced a schema mismatch: property's caller workflows passed `secrets: PRIVATE_REPO_TOKEN: ${{ secrets.PRIVATE_REPO_TOKEN }}` to centralized `swiftlint.yml@v1` / `swift-format.yml@v1` which declare no `secrets:` block. Carrier (the validated reference per [GH-REPO-074]) shipped clean by passing no secrets. The hidden cause: property had been the *original* canonical reference template — the 2026-04-29 centralized-workflow trim made carrier the new reference and regenerated 436 callers across 296 packages, but `Scripts/sync-ci-callers.sh:48` had property in EXCLUDE specifically to skip it as the original reference, so property's callers were never refreshed against the trimmed centralized side.
4. Aligned property's caller files to the canonical templates (`8130d40` after intermediates); bookkeeping commit removed property from sync-ci-callers EXCLUDE (`86c2a8e`).
5. Re-running with the fixed callers surfaced 8 SwiftLint `--strict` violations in the source tree (3× `leading_whitespace` + 4× `empty_count` + 1× `orphaned_doc_comment`). Added `isEmpty` accessors to the test-support `Container` and `Stack.peek` extension; converted `count == 0` to `isEmpty`; moved the orphaned `///` to attach directly to `public final class State`. swift test 48/48 pass; SwiftLint clean. Re-squashed everything to v2 parentless `0d6b11b`; force-pushed; deleted all 134 prior Actions runs for clean slate; re-watched CI on the new SHA, all green.
6. Mid-launch the user removed an `## Design choices` paragraph from the ownership README (`9186f52`) — author's design rationale for rejected alternative shapes — and observed: *"the readme is written more for the maintainer than consumers of the package."* That triggered a /collaborative-discussion (3 rounds, CONVERGED) with ChatGPT diagnosing the cohort-wide pattern as **audience inversion** — single failure class, six surface patterns (pre-tag interim notes; sibling-package taxonomy; Stability with internal rationale; exhaustive negative documentation; ecosystem-convention framing; unreleased-package Quick Starts).
7. Executed the converged plan: Phase 0 audit at `swift-institute/Research/cohort-readme-evaluator-pass.md`; Phase 1 readme skill v2.1.0 amendment (4-row [README-016] extension + new conditional [README-027] Stability operational form + [README-010] Architecture earning sub-rule); Phase 2 per-repo cleanups (Property → Tagged → Ownership → Carrier audit-only); Phase 3 backlog Pass 4 entry on the carrier-launch-skill-incorporation-backlog.
8. Property's README then iterated 5 times based on direct user observations: (a) Quick Start using an unreleased downstream package → Stack-based with mutating push and the CoW dance → Property.Typed read-only `peek` (no dance); (b) drop the `Property_Primitives.Property.*` qualifier in favor of unqualified `Property.*`; (c) split the foundational typealias into its own extension (separate from any per-namespace tag/accessor); (d) `from: "0.1.0"` Installation snippet → `branch: "main"` (no tag exists yet) — applied across all four cohort repos.
9. Tutorial + DocC consistency sweep (10 files: tutorial step-02..05, the `Tests/Tutorial` mirror, CoW-Safe-Mutation-Recipe.md, Property.swift doc-comment, Property.Typed.swift doc-comment + Property.Typed.md, Phantom-Tag-Semantics.md). Then a full ecosystem-uniformity sweep (17 more files: every Property variant's source doc-comment + per-symbol DocC article + cross-cutting `~Copyable-Base-Patterns.md` + `GettingStarted.tutorial`). 48/48 tests pass after each.
10. Final squash + force-push to `2d3dda8` parentless commit.

HANDOFF scan: `swift-property-primitives/HANDOFF.md` deleted earlier in the session (gitignored; fully discharged); 4 HANDOFF-*.md files at `swift-institute/` root (`platform-audit-cycle-followup`, `string-correction-cycle`, `typed-time-clock-cleanup`, `windows-kernel-string-parity`) and 1 root `HANDOFF.md` were out-of-session-scope per [REFL-009] bounded cleanup authority — none touched.

## What Worked and What Didn't

**Worked:**

- **/collaborative-discussion converged in 3 rounds.** ChatGPT's adjustments (Architecture rule broader than "When to import"; [README-027] conditional rather than mandatory; Carrier as control discipline-not-template) materially improved Claude's initial position. The audit + skill amendment + per-repo cleanup-order plan was actionable verbatim. The structured round format with per-paragraph KEEP/COMPRESS/RELOCATE/DELETE verdicts surfaced the right work units.

- **Audience inversion as a diagnostic frame.** Sharper than "evaluator's lens failure" — captures the failure as a *direction* (author-side context flowing into consumer-facing prose) that scales to per-paragraph review. The six surface patterns (pre-tag notes, sibling taxonomy, Stability mixing, exhaustive absences, ecosystem-convention bullets, unreleased-package Quick Starts) all traced back to the same direction.

- **Property.Typed as the simpler Quick Start shape.** Switching from a mutating `push.back(_:)` example (with the 5-step CoW recipe) to a read-only `peek` example (with `Property.Typed` and a one-line accessor) reduced cognitive load from four Swift features to two. The Tutorial introduces push BEFORE peek, but for the README's first-encounter shape the inverted order is correct.

- **Iterative README refinement based on direct user observation.** Five rounds of README revision uncovered debt that the formal pre-launch audit + final pre-release scan had not caught. The collaborative-discussion converged plan resolved the scope question; subsequent iterations refined the example shape based on user feedback ("dance is structural", "drop the qualifier", "split the typealias").

- **Bash sandbox correctly rejected destructive `git checkout HEAD -- _index.json`** when the file carried in-progress edits from a prior session. Pivoted to surgical commit-only-my-file with a documented `_index.json` deferral.

**Didn't work as well:**

- **Workflow-caller schema mismatch produced `startup_failure` with no diagnostic.** GitHub Actions rejected the caller-passes-undeclared-secret combination silently. Diagnosis required cross-referencing carrier (works) vs property (fails) and reading both centralized YAMLs. The asymmetry is structural: property was the EXCLUDE'd reference, so it never got the post-trim caller refresh — that single line in `Scripts/sync-ci-callers.sh:48` was the load-bearing detail.

- **Pre-launch audit + final pre-release scan didn't catch the cohort-wide audience-inversion pattern.** Both passed on property; the user caught it post-launch. The audit checklist focused on per-package compliance against existing skill rules, not on cross-cohort recurring patterns where the rules themselves needed extension.

- **Pre-tag `from: "0.1.0"` snippets across all 4 cohort READMEs.** Each repo's Installation snippet pinned to `from: "0.1.0"` despite no tag existing. This was a stale state — the audit didn't flag it because the rule wasn't yet codified. The new [README-016] row (pre-tag interim notes prohibited) addresses this going forward.

- **Iteration count on property README is high.** Five revisions in one session. The first-pass audit specified the verdicts but not the exact example shape; the example shape was discovered iteratively. A "dry-run example" step in the audit (composing a minimal worked example) would have surfaced the typealias-shape and qualifier choices earlier.

## Patterns and Root Causes

**Pre-launch rule-compliance vs cross-launch pattern discovery are different validation modes.** The audit checklist verifies per-package compliance against existing skill rules. It cannot surface failure modes the rules themselves don't yet name. Cohort-wide patterns — where the same defect appears across N packages because all N authors made the same authorial mistake — only reveal themselves *after* enough packages exist to compare. The user's observation came from comparing READMEs side-by-side; no individual pre-launch audit had that vantage. The remediation is to fold a discovery-lens pass over each cohort package into the release-readiness audit, even when no specific rule fires — a "do these paragraphs serve the consumer's adoption decision?" gut-check is cheap and catches the class.

**Audience inversion is a single failure class with multiple surface patterns.** Six distinct surface patterns (pre-tag notes, sibling taxonomy, Stability mixing, exhaustive absences, ecosystem-convention bullets, unreleased-package Quick Starts) all share the same direction: author-side context flowing into consumer-facing prose. Once named, the class is easy to recognize across the cohort. Before naming, each pattern looked like an isolated style choice. The skill amendment (4-row [README-016] extension + new [README-027] + [README-010] sub-rule) operationalises the class by enumerating its surface patterns and a positive form for the most common positive case (Stability).

**Reference-template state can ossify when the canonical reference moves.** Property was the original reference template that `Scripts/sync-ci-callers.sh` regenerated 295 other packages from. The 2026-04-29 centralized-workflow trim made carrier the validated reference per [GH-REPO-074]. The script's EXCLUDE list still named property, designed to skip it as the canonical reference — but the canonical reference had moved. Property's callers were stale relative to the centralized workflows that had been updated against carrier. The same class of bug applies whenever an artifact carries the responsibility of being "the reference" and that responsibility gets handed off without updating the artifact's exclude/skip rules. The fix here was small (drop property from EXCLUDE); the diagnostic class is broader: any "this one is exempt because it's the reference" rule needs to update when the reference moves.

**The CoW-safe `_modify` recipe is structural to Swift's accessor system.** `yield` must appear directly in the accessor body — no helper function can encapsulate the transfer-clear-defer-yield sequence because `yield` is an accessor coroutine primitive, not a regular statement. A `@PropertyAccessor` macro could automate it but doesn't exist. So the dance is intrinsic to Swift, not an authoring shortcoming. But `Property.Typed` for read-only namespaces has a value-based one-line accessor and no recipe — a much simpler entry point. The Tutorial introduces push (with dance) before peek (with Property.Typed), putting the harder shape first; for the README's first-encounter shape, inverting that ordering is approachability.

**Ecosystem-wide uniformity sweeps must touch many surfaces.** README-only changes leave the Tutorial step files, Tests/Tutorial mirror, source doc-comments, per-symbol DocC articles, and cross-cutting articles all carrying the older shape. The teaching surface is wide; only the README gets the user's first attention. The 27 files touched in this session (10 in the Tutorial sweep + 17 in the full uniformity sweep) all carried the older shape. The lesson: when a canonical example shape changes, the propagation cost is wide and obvious-once-named — the skill rules should signal "any change to the canonical example here propagates to N other surfaces" so the change-author scopes correctly upfront.

## Action Items

- [ ] **[skill]** github-repository: Add a thin-caller schema-validation rule. When `Scripts/sync-ci-callers.sh` regenerates callers, validate that each caller's `secrets:` and `with:` blocks are accepted by the centralized workflow's `workflow_call:` declaration. A schema mismatch (caller passes a secret the centralized doesn't declare) currently produces `startup_failure` with no diagnostic. The 2026-05-01 property launch lost ~30 minutes to this — direct cost of the silent rejection. The fix is mechanical: parse both YAMLs at sync time, fail with a clear message when they diverge.

- [ ] **[skill]** readme: Extend [README-016] with an explicit Installation-snippet rule. `from: "X.Y.Z"` in Package.swift Installation snippets is forbidden when no X.Y.Z tag exists. Pre-tag state requires `branch: "main"` (or equivalent) to ensure consumers copying the snippet get a usable pin. The cohort-wide 4-repo `from: "0.1.0"` → `branch: "main"` fix in this session confirms this is a recurring pattern across the swift-primitives 0.1.0 cohort, not a one-off. The rule extends the existing pre-tag-interim-notes prohibition to the snippet itself.

- [ ] **[skill]** release-readiness: Extend Phase 2 audit with an explicit [README-023] discovery-lens pass. The property pre-launch audit + final pre-release scan both passed, but the cohort-wide audience-inversion pattern only surfaced post-launch via direct user observation. Adding a per-paragraph "cover with your hand — does the reader skip and still decide?" check during Phase 2 (or a per-section "is this evaluator-shaped or author-shaped?" gut-check) would catch the class on future cohorts before launch. Cost: minutes per package; benefit: avoids the post-launch sweep cost (this session's 27-file ecosystem-uniformity sweep).
