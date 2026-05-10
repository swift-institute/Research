---
date: 2026-05-06
session_objective: Execute Phase 2 of the file-based-canonical migration for swift-linter — replace the canonical-as-Swift-package design with a Lint.swift-at-org-root + // parent: directive chain, ship + verify + retire the prior canonical packages.
packages:
  - swift-foundations/swift-linter
  - swift-foundations/swift-manifest
  - swift-institute/.github
  - swift-primitives/.github
  - swift-primitives/swift-tagged-primitives
status: processed
processed_date: 2026-05-10
triage_outcomes:
  - type: mixed
    description: NoAction supervise verification gate path-distinguishing covered by [SUPER-009a] verification scope sub-rule. swift-manifest cache invalidation is package-implementation work. NoAction handoff dispatch-document-literal commands covered by [HANDOFF-036] recipe-and-path-math empirical verification.
---

# Phase 2 file-based-canonical migration — execution + Phase 2.5 carve-out + push wave + canonical retirement

## What Happened

Executed the Phase 2 file-based-canonical migration for `swift-linter` end-to-end across 5 repos, with an unplanned Phase 2.5 carve-out for an upstream `swift-manifest` shim bug discovered at the verification gate.

**Session arc (in order)**:

- **Commits #1–#4 amended** for principal type-discipline review feedback after the initial round: typed `[Lint.Rule.ID]` for Manifest's enabledRuleIDs/disabledRuleIDs (was `[Swift.String]`), URI-typed parser/fetch helpers (was bare strings), parent-chain resolver with URI cycle detection. Carry-forward commit `0da8879` for a pre-existing dirty `Linter Rule ResultBuilder` working-tree state per principal authorization.
- **Commit #4.4** (course-correction): retyped `Lint.Manifest.excludedPaths` from `[Swift.String]` to `[File.Path]` after surfacing a meta-correction — `Paths.Path` is `Copyable + Sendable + Hashable` and fits stdlib `Array` directly; the prior "[Swift.String] is a typed-system gap because Path is ~Copyable" framing was wrong (conflated `Path_Primitives.Path` with `Paths.Path`). Saved the broader pattern as `feedback_institute_containers_pass_through_noncopyable.md`: institute container catalog (`Array_Primitives`, etc.) handles ~Copyable elements via base-variant unconditional `~Copyable`, so stdlib Array's Copyable constraint is NOT the right framing.
- **Commit #4.5**: dropped underscore prefix on internal-static helpers in `Lint.Driver` (`_parseParentURL` → `parseParentURL` etc.); added file-header NOTE about `[IMPL-024]` static-layer compound-name allowance + re-audit-before-visibility-widening; flagged `tempPathFor` and `sanitizeForPath` with `// TODO: Phase 2.5 ecosystem-promotion` per principal direction.
- **Commit #3.5** (deferred per β): parser-primitive composition for the `// parent:` directive scan. `Parser.Literal<Parser.Input.Bytes>("// parent:")` for the literal match; byte-level scan over `Span<UInt8>` directly inside `File.read.full` closure (no String materialization for the file-reading path); `.ascii.lf/.cr/.space/.tab` byte constants from `swift-ascii-primitives`. Behavioral invariance held — all 24 ParseParentURL test cases continued to pass.
- **Commits #5/#6/#7**: file-based canonical chain authored — Tier 1 `Lint.swift` at `swift-institute/.github` (chain root, empty `enabledRuleIDs`), Tier 2 at `swift-primitives/.github` (R1–R5 cohort, inherits Tier 1 via `// parent:`), consumer at `swift-tagged-primitives` (R1–R5, inherits Tier 2).
- **Commit #8 pre-push gate** discovered that the verification was passing for the **wrong reason**. The 27-hit count came back as expected, but inspecting stderr revealed `swift-manifest`'s auto-generated driver shim was failing to compile — the file was named `main.swift` AND had `@main` on an enum, which Swift 6.x rejects as mutually exclusive. `Manifest.load` was failing → the driver fell back to v1-default (`defaultConfiguration()`, all rules enabled), which produces 27 R5 hits coincidentally because R5 is one of the built-in rules. The v2 evaluation path was unreachable; pre-push and post-push gates would have produced identical output if not for the catch.
- **Phase 2.5 carve-out**: per principal's Option A direction, scope-locked Phase 2 stayed parked. Authored `HANDOFF-swift-manifest-shim-mainswift-fix.md`; principal dispatched a fresh subordinate to fix swift-manifest. Fix landed at commit `ae8e37f` (rename `main.swift` → `Driver.swift`).
- **Resumed Phase 2 from #8**: re-ran the gate — first attempt produced new error (`'main' attribute can't coexist with top-level code` + `invalid redeclaration of __SwiftManifestDriver`) because the `.swift-manifest/` cache directory still had the OLD broken `main.swift` alongside the new `Driver.swift` (same enum). Cleared the cache via `rm -rf .swift-manifest`; re-ran. Got 27 R5 hits + the `[swift-linter] WARN: parent chain resolution failed: ... exitCode: 56 ...` signal. Pre-push fallback path validated.
- **Commit #8.5** (scope expansion bundled): wired the documented-but-unwired `--lint-swift-path` CLI option through `Lint.Driver.resolveConfiguration`. Discovered while preparing the README that the option was declared, documented in `--help`, but silently dropped. Bundled per principal direction because shipping a general-use README documenting an unwired interface would be a worse outcome than the scope expansion.
- **Commit #8.6** (mechanical rename): `Lint.SwiftDriver` → `Lint.Driver` per `[API-NAME-002]` (no compound identifiers) + `[API-NAME-001a]` (single-type-no-namespace; the "Swift" variant label has no sibling variants since the YAML driver was dropped at Phase 1.5). Cross-repo coherence: the Tier 1 `Lint.swift` had a stale doc-comment reference; updated as a sibling commit.
- **Commit #9**: README authored at evaluator-audience grade (98 lines, all 6 dispatch-spec sections).
- **Commit #13**: memory supersession — authored `feedback_lint_canonical_file_based_org_mirror.md`, narrowed `feedback_canonical_packages_org_mirror_authority.md` (now applies only to canonical artifacts that legitimately need SwiftPM-resolvable form), updated `MEMORY.md` index.
- **Push wave (5 repos)** authorized + executed — all 5 pushes landed clean.
- **Post-push commit #8 gate**: 27 R5 hits + ZERO WARN signals — the chain-resolved code path validated end-to-end. Stamped `Research/2026-05-06-r5-postpush-chain-gate.md`. Both runs together (pre-push fallback + post-push chain-resolved) exercise every code path in `Lint.Driver.resolveConfiguration`.
- **Deletion 1** (Tier 2 dependent first): on-disk `rm -rf` + post-deletion `swift build` green across affected repos; GitHub repo retirement blocked at `gh repo delete` (HTTP 403, missing `delete_repo` scope). Per `feedback_no_gh_cli_admin_scope.md` did NOT run `gh auth refresh -s delete_repo`; surfaced for web-UI deletion. User deleted both via web UI.
- **Deletion 2** (Tier 1 root second): on-disk + builds green. GitHub repo retired by user via web UI.

**[SUPER-011] verification stamp** finalized in `HANDOFF-file-based-canonical-migration-phase-2.md` with all six supervisor constraints + eight acceptance criteria verified.

**HANDOFF scan**: 38 `HANDOFF-*.md` files at workspace root. In-authority for triage: `HANDOFF-file-based-canonical-migration-phase-2.md` (worked end-to-end), `HANDOFF-swift-manifest-shim-mainswift-fix.md` (Phase 2.5 brief, completion verified by Phase 2 resumption), `HANDOFF-file-based-canonical-migration.md` (Phase 1 predecessor, annotated superseded per dispatch metadata). Other 35 are out-of-session-scope. No audit findings to triage (no `/audit` invocation this session).

## What Worked and What Didn't

**Worked**:

- **Two-run verification strategy** (pre-push fallback vs post-push chain-resolved) caught the swift-manifest shim bug. A count-only check would have passed on both runs, masking the latent failure. The principal's specific framing — "the WARN-signal in stderr is dispositive proof which path fired" — turned a coincidental count match into a path-identification check.
- **Scope-lock discipline** on Phase 2.5 carve-out. Refused Option C (1-line fix in this dispatch) per `[SUPER-002a]`. The fix was eventually 1 line, but the full sub-dispatch (rename + tests + grep consumers) proved that the "small" framing was misleading.
- **Memory consultation under pressure** at the `gh repo delete` blocker. The reflex would have been to run `gh auth refresh -s delete_repo` — `feedback_no_gh_cli_admin_scope.md` was load-bearing and held without the rule needing to be re-derived. Web UI was the right channel.
- **Cross-repo coherence detection**. After the `Lint.SwiftDriver` → `Lint.Driver` rename in the linter repo, an ecosystem-wide grep surfaced a stale doc-comment reference in the Tier 1 `Lint.swift` at `swift-institute/.github`. Caught unprompted; sibling commit kept the namespace coherent.
- **Forward-compat note discipline** in commit messages (NOT in code comments). The Phase 3a extraction note for the chain-resolution machinery → `Manifest.Resolver<M, C>` lives in commit `a771c12`'s body — survives the eventual extraction without becoming a code-comment anchor that has to be removed.

**Didn't work the first time**:

- **Initial pre-push gate run** with `Sources/` path-arg from the dispatch document literally — produced 0 hits because Sources/ has no `__unchecked:` sites and no `Lint.swift` (so v2 path doesn't fire). Required surfacing the dispatch-document-vs-canonical-command discrepancy and getting principal sign-off on the package-root command being canonical.
- **Stale `.swift-manifest/` cache** after Phase 2.5's swift-manifest fix. The renamed `main.swift` → `Driver.swift` left the OLD `main.swift` in the cache directory; the new shim wrote `Driver.swift` alongside, producing a redeclaration error. Required `rm -rf .swift-manifest` before the post-fix verification could succeed.
- **`--lint-swift-path` was documented-but-unwired**. Surfacing this required actually trying to use the option (functional test), not just reading the CLI struct. Bundled as commit #8.5 because the README drafted around it would have shipped a broken-as-documented interface.

## Patterns and Root Causes

**Pattern 1 — Verification gates can pass for the wrong reason.** The 27-hit count was the load-bearing baseline, but the count alone was insufficient — a count match between v1-fallback and v2-fallback paths is structurally possible because R5 happens to be a built-in rule that defaultConfiguration enables. The real verification needed BOTH the count AND the WARN-signal trace identifying which path produced it. The principal's two-run strategy made this a designed-in property: pre-push run validates the v2 fallback path (WARN present), post-push run validates the chain-resolved path (WARN absent). Together they cover every code path in `resolveConfiguration`.

This is a class of failure: "the gate passes, but for a reason we didn't intend." Recognizing it requires asking not just "did the count match?" but "did the count match because the code path I wanted to verify actually fired?" The cheap way to make this rigorous is to identify a path-distinguishing observable (here: the WARN signal) and check both the count AND the path identity.

**Pattern 2 — Scope-lock under pressure is the discipline that pays.** The Phase 2.5 carve-out was the right call even though the swift-manifest fix turned out to be 1 line. The framing "this is small, just fix it" is precisely what `[SUPER-002a]` was designed to refuse. The full sub-dispatch (Driver.swift rename + regression test + consumer grep) was the proper shape; doing it in-scope would have polluted the Phase 2 commit message with cross-package work that didn't belong. Scope-lock isn't about the size of the fix; it's about preserving the dispatch's commit narrative.

The same pattern applied to commit #8.5 (the `--lint-swift-path` wiring): I bundled it WITH explicit scope-expansion attribution in the commit message, because shipping a broken-as-documented interface alongside the README in #9 would have been a worse outcome than the scope expansion. Different decision, same discipline: name the scope expansion explicitly when it's justified, refuse it silently when it isn't.

**Pattern 3 — Auto-generated cache + upstream fix = stale-state divergence.** The `.swift-manifest/` cache directory persisted across the swift-manifest rename. The cache holds files keyed on what swift-manifest *used to* write, not what swift-manifest *now* writes. The new generator wrote `Driver.swift` alongside the orphaned `main.swift` from the prior generation, producing a redeclaration error that wasn't a bug in either swift-manifest version — it was a generation-mismatch between the cached output and the running generator.

This is the same pattern as `feedback_clean_build_first.md`'s `rm -rf .build` discipline, but for shim caches rather than build caches. Generalization: when an upstream tool's output format changes, the cached output of the OLD format is hostile state; explicit invalidation is required, not optional.

## Action Items

- [ ] **[skill]** supervise: codify "verification gates can pass for the wrong reason — identify a path-distinguishing observable (WARN-signal trace, build-output diff, etc.) and check both the count AND the path identity, not the count alone" as a sub-rule under `[SUPER-009]`'s "verification source" enumeration. Worked example: 2026-05-06 Phase 2 commit #8 gate, where the v2 vs v1-fallback distinction was load-bearing but invisible to a count-only check.
- [ ] **[package]** swift-manifest: document the `.swift-manifest/` cache invalidation requirement in the package's Documentation.docc — when consumers update their Lint.swift OR when swift-manifest itself changes its shim filename/structure, `rm -rf <consumer>/.swift-manifest` is required. Reference `feedback_clean_build_first.md`'s `.build` analog. Could also add a stale-cache-detection check to the shim writer (e.g., delete sibling files matching the prior generation's filename before writing the new generation).
- [ ] **[skill]** handoff: add a HANDOFF-quality rule for dispatch-document-literal commands — the literal command should be verified end-to-end (path arg, expected output, fallback paths) BEFORE the dispatch is frozen. The 2026-05-06 Phase 2 dispatch's literal command (`tagged-primitives/Sources`) couldn't satisfy the gate it was attached to (`27 R5 hits`); only careful execution surfaced the discrepancy. Could add an "execute the dispatch's verification command pre-flight, confirm the assertion holds against the current state" gate to the dispatch-authoring procedure.
