---
date: 2026-05-04
session_objective: Execute Phases C → D → B7 → B8 → F → G of the per-repo-workflow-drift rollout to bring the swift-primitives ecosystem to its architectural target end-state.
packages:
  - swift-institute (.github universal reusables, Skills/ci-cd-workflows)
  - swift-primitives (.github layer wrapper, all 132 consumer packages)
  - swift-array-primitives (R1 recovery + experiment Experiments/shorthand-syntax-with-shadowing/)
  - swift-dictionary-primitives (R1 recovery)
  - swift-cache-primitives, swift-parser-primitives, swift-pool-primitives (R1 recovery)
  - swift-graph-primitives (R1 halted — pre-existing compiler crash)
status: pending
---

# Per-Repo-Workflow-Drift Rollout: C / D / B8 / F-now Execution + B6.5 R-Chain Recovery

## What Happened

The session executed the bulk of the per-repo-workflow-drift rollout for the swift-primitives org: Phase C (cosmetic backfill, 27 commits), Phase D (collapse 132 docs: with: blocks, 132 commits), Phase B8 (universal `enable-private-repos` default flip + 131 consumer mass-removal, 134 commits), and Phase F-now skill update (4 surgical commits to `ci-cd-workflows` SKILL.md). Phase B7 (org-level `PRIVATE_REPO_TOKEN` secret) halted on a principal-side blocker (`gh` lacks `admin:org` scope + token value not provided); Phase F-deferred + Phase G remain outstanding pending B7 close. The session also closed the B6.5 R-chain (recovery from a B6.5b-1 mass-format-pass incident that shipped 6 broken packages to remote).

Key artifacts and SHAs:

- Shared infrastructure: `swift-institute/.github` ended at `5d56067` (4 commits across the rollout). `swift-primitives/.github` ended at `f941be5` (1 commit this session). Total ~700+ commits across the ecosystem when consumer fan-outs are counted.
- Phase F-now skill update: 4 commits (`7ac52f5`, `075e1f5`, `0b840bd`, `f679469`) added 6 new `[CI-NNN]` rules + 2 amendments (`[CI-002]` widened scope, `[CI-031]` updated reference shape).
- Empirical experiment: `swift-array-primitives/Experiments/shorthand-syntax-with-shadowing/` (commit `72f5745`) — 5 variants verifying that Swift's `[T]` / `[K:V]` syntax is hardcoded by the compiler to resolve to stdlib types regardless of module-scope shadowing. Cited swiftlang/swift @ `6f265bdcad8` `KnownStdlibTypes.def:51` + `TypeCheckType.cpp:5584`.
- Final ecosystem state: zero residual umbrella-* in consumer ci.yml, zero residual `enable-private-repos: true`, zero per-repo `swift-format.yml` / `swiftlint.yml` workflow files, 131/132 packages carry `"UseShorthandTypeNames": false` (graph-primitives is the outlier — pre-existing compiler crash from R1 halted recovery there).

The session opened with the B6.5b-1 mass-format-pass incident already in flight: the previous session's `swift-format format --in-place` fan-out across 132 packages had shipped without a per-package build-verify gate. Six packages broke in remote main: `swift-array-primitives` and `swift-dictionary-primitives` (sources of custom shadowing types) plus `swift-cache-primitives`, `swift-graph-primitives`, `swift-parser-primitives`, `swift-pool-primitives` (consumers of those custom types). The principal flagged the `Array<X>` → `[X]` rewrites as semantically wrong; the session then ran `/experiment-process` to verify empirically + dove into the Swift compiler source (after the principal asked "see the global swift-format approach as well on how to apply this") to confirm the hardcoding is structural language behavior, not a swift-format bug.

The recovery (R-chain) landed 5/6 packages cleanly via composite commits (revert + `.swift-format` rule disable + `swift-format format --in-place` under the new rule). Graph-primitives halted on a pre-existing `swift-frontend` SIGABRT in `Graph.Sequential.Transform.Payloads.swift` that the format errors at the broken b2fb23f-equivalent commit had been masking. The R-chain then propagated `"UseShorthandTypeNames": false` to all 132 `.swift-format` files (122 commits in R2 + 4 in R2.5 stage-fail recovery).

## What Worked and What Didn't

**What worked**:

- **Empirical validation of language behavior**. Running `/experiment-process` produced a 5-variant artifact that captured the hardcoding empirically. Then diving into `swiftlang/swift` source and citing line numbers verbatim (`KnownStdlibTypes.def:51`, `TypeCheckType.cpp:5584`) gave the principal evidence stronger than either the experiment or the source-dive alone. Combined evidence was decisive.
- **Composite commits for R1 recovery**. Bundling revert + `.swift-format` edit + reformat into one commit per affected package (per principal authorization to treat them as one logical change) was clean: 6 broken packages, 5 single-commit recoveries, one commit per package contained the full inseparable fix.
- **`jq` for `.swift-format` JSON edits + Python script for YAML edits in consumer ci.yml**. Both produced deterministic, reviewable diffs. The Python script for Phase D + B8d handled the empty-`with:`-block cleanup case correctly without YAML libraries (string-based with leading-whitespace checks).
- **Carrier canary at every phase boundary**. `swift-carrier-primitives` is public (visibility gate doesn't fire), has no private deps (`enable-private-repos: true` default-flip is harmless), and follows convention exactly (DocC derivation produces the expected umbrella values). It's nearly the perfect canary — every B-phase canary dispatch caught issues early or confirmed clean state.
- **Surfacing-for-clarification on principal mental-model drift**. Twice in the session the principal's stated intent didn't match GitHub Actions semantics: (1) "remove `secrets:` block entirely; org-level inheritance handles authentication" is wrong because secrets don't auto-cross the `workflow_call` boundary even with org-level secrets; (2) the architectural target shape was stated as "12 lines" but the realistic minimum is ~14 lines for public consumers and ~18 for private (with `secrets: inherit`). Surfacing both before mass-edit got the corrected target shape ("`secrets: inherit`, not full removal") locked in before damage.

**What didn't work**:

- **B6.5b-1 had no per-package build-verify gate**. The format-in-place fan-out shipped 6 broken packages because no `swift build` ran between `format-in-place` and `git push`. With a build-verify gate, the first failed package would have halted the fan-out and surfaced the `Array<X>` → `[X]` issue at package #19 (swift-array-primitives) instead of after 132 pushes had completed. The discipline gap is now codified as `[CI-056]`.
- **Recover-consumer function had a halting-logic bug**. The bash function used `if swift build ... | grep error: | head -1; then halt; fi` — but `head` always exits 0, so the halt branch always fires regardless of whether the grep matched. swift-cache-primitives was falsely halted; manual completion needed. Pattern: `if pipeline ending in head | something_with_zero-exit; then …; fi` is structurally broken — the head's exit status overrides the pipeline's signal value. Switched to `swift build … >/dev/null; rc=$?; if [ $rc -ne 0 ]; then …` for graph-onward.
- **Initial diff threshold for `jq` edit verification was wrong**. Set `[ "$diff_lines" -gt 7 ]` based on `wc -l` of `git diff` output, but `git diff` adds ~5 boilerplate lines (`diff --git`, `index abc..def`, `---`, `+++`, `@@ ... @@`) on top of the +/- changed lines + 3 context lines on each side. Triggered "unexpected diff" rejection on 115/126 packages on the first R2 round-2 attempt. Re-ran with `diff` (unix) `-cE '^[<>]' | wc -l` testing for exactly 2 (one `<`, one `>`) — clean. Pattern: when verifying mechanical edits, prefer the simpler diff format (unix `diff`) over `git diff` when only line-count gates are needed.
- **A4 framing of "dead `cache-key-prefix` input" was imprecise**. Phase 0 audit reported "2 consumers passing dead input to swift-docs.yml" but on closer inspection the consumers were passing it to the layer wrapper (where the input is alive in the embedded job) or to the universal reusable (where it's not declared at all). The cleanup was still correct but for different reasons per consumer. Premise-staleness instance: my own audit's framing was wrong; the principal's authorization rested on the wrong premise; surfacing the nuance before A4 execution caught it.

## Patterns and Root Causes

The dominant pattern across the session was **mass-rollout discipline gap** specifically for source-modifying transforms. `[CI-051]` (surgical commits, dirty-skip discipline) covers mass workflow-file edits universally. But it doesn't include a build-verify gate — and `format-in-place` is a source-modifying transform that can produce semantically-equivalent changes ON AVERAGE while breaking SPECIFIC packages with structural shape collisions. Without local build-verify between transform and push, the per-package commit fan-out ships broken commits to remote main where they trigger red CI and require recovery work that's strictly more expensive than the verify would have been. The lesson is now codified as `[CI-056]`; the codification cost was one rule-write versus the recovery cost of an entire R-chain.

The `[UseShorthandTypeNames]` failure mode is worth naming as a class: **language-level hardcoding produces transforms that look semantically equivalent but aren't**. swift-format's `Array<X>` → `[X]` rewrite is correct in 95%+ of consumer code (because most code uses `Swift.Array`), but the 5%-or-less that defines or imports a shadowing custom `Array<T>` breaks. The compiler's hardcoded `getArrayDecl()` lookup in `lib/Sema/TypeCheckType.cpp` (with the comment "the rest of the compiler is going to assume it can canonicalize [T] to Array<T>") makes this a structural fact, not a swift-format defect. Tools that perform mechanical transforms across language-feature boundaries (sugar like `[T]`, `[K:V]`, `T?`) inherit the language's hardcoded semantics — they cannot be more flexible than the language allows. The takeaway: when a tool's transform crosses a language-syntax boundary, the language's semantics are the ceiling.

The principal's mental-model drift on GitHub Actions secret semantics ("org-level inheritance handles authentication automatically") is interesting because the drift was small but the consequences would have been ecosystem-wide. The drift came from conflating two things that both involve "org-level secrets": (1) the caller-side `${{ secrets.X }}` namespace DOES include org-level secrets; (2) but secrets DON'T auto-cross the `workflow_call` boundary into reusable workflows — they must be passed via `secrets:` block (per-secret listing or `secrets: inherit`). Both halves are correct individually; mixing them produces the wrong-shaped conclusion. The same shape recurs across other distributed-systems mental-model drifts (e.g., "Kubernetes secrets are mounted into pods" — true for one secret-passing mode, not for envFrom). Surfacing-for-clarification before mass-edit is the right discipline; the cost of surfacing is one round-trip, the cost of mass-applying a wrong-shaped fix would have been a 132-package recovery.

The session also exhibited the **post-commit memory scan** pattern (per `[REFL-006]`) usefulness: `feedback_clean_build_first.md` and `feedback_rm_build_benchmarks.md` would have been worth consulting before debugging the graph-primitives compiler crash investigation. The user's "try remove .build first" intervention was correct — and codified in feedback memory. Mechanical scan over feedback memory at debugging boundaries (especially for build/CI failures) closes the consultation gap without needing the reviewer.

The graph-primitives pre-existing compiler crash, masked by format errors at the broken b2fb23f-equivalent state, is a small example of **error-masking**: when a build fails on one error, subsequent errors don't surface; fixing the masking error reveals what was hidden. The format errors aborted the build before reaching `Graph.Sequential.Transform.Payloads.swift`; the R1 recovery (which fixed the format errors) then exposed the SIGABRT at that file. The crash was always there — visible only after the masking went away. This is the "fixing one bug reveals another" pattern; the fix isn't to avoid fixing the first bug, it's to recognize that the second bug is a separate concern and triage it accordingly.

## Action Items

- [ ] **[skill]** ci-cd-workflows: schedule F-deferred rules (`secrets: inherit` consumer pattern + org-level `PRIVATE_REPO_TOKEN` inheritance discipline) to land once Phase B7 closes. The HANDOFF residual section currently tracks them; they need to become rules in the skill once B7's commits are available to cite. Likely IDs `[CI-059]` + `[CI-060]`.
- [ ] **[research]** swift-graph-primitives compiler SIGABRT in `Graph.Sequential.Transform.Payloads.swift` (target `Graph_Payload_Map_Primitives`). Reduce-to-minimal-reproducer + upstream Swift bug report. Reproduces at HEAD~1 of graph (pre-rollout) — independent of the format pass. The crash is likely at SIL-emission or runtime-init; investigation entry-point is the file at line 1.
- [ ] **[skill]** experiment-process: consider extending `[EXP-006b]` (Confirmation Evidence) with a sub-rule for compiler-behavior experiments — when an experiment's hypothesis is about Swift language behavior, the strongest evidence form combines (a) empirical variants AND (b) verbatim line-citations from `swiftlang/swift` source pinned to a specific commit SHA. The shorthand-syntax-with-shadowing experiment was uncommonly persuasive precisely because it cited both. Worth codifying as a template for future compiler-behavior experiments.

---

## Session Artifact Cleanup Report

**HANDOFF triage**:

- `HANDOFF-eliminate-per-repo-workflow-drift.md` (this rollout): RETAINED per principal direction. Updated in-place to reflect Phases C / D / B8 / F-now landed; outstanding work section captures B7 (BLOCKED on user-side org-admin action) + F-deferred + G. NOT deleted because it tracks active outstanding work.
- 14 other `HANDOFF-*.md` files at workspace root: out-of-session-scope per `[REFL-009]` bounded cleanup authority — this session did not write or actively work them. Left untouched.
- 4 `AUDIT-*.md` files at workspace root: out-of-session-scope. Left untouched.

**Audit findings**: this session did not invoke `/audit` or modify any `Audits/audit.md` file. No status updates needed.

**HANDOFF scan**: 15 HANDOFF files found at `/Users/coen/Developer/`; 1 retained-and-annotated (`HANDOFF-eliminate-per-repo-workflow-drift.md`); 14 out-of-session-scope.
