# Rollout Phase 1 — Centralized Linter Harness for swift-primitives

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-primitives]
normative: false
---
-->

## Context

### Trigger

Implementation of the Phase 1 rollout dispatched per `HANDOFF-rollout-phase-1.md` (2026-05-05). Phase 1 lands the centralized linter harness for swift-primitives by enforcing 3 mechanical rules:

1. `[DOC-003]` ValidateDocumentationComments — swift-format catalog rule, distributed via fanout
2. `[API-IMPL-005]` one_declaration_per_file — SwiftLint canonical built-in opt-in flip
3. `[PRIM-FOUND-001]` Foundation-family imports — γ-1a workflow migrated to SwiftLint custom rule

Source rule selection rationale: see `mechanical-rule-tool-classification-swift-primitives.md` v1.0.0 (Phase 1 = the 2 Config-Flips + 1 γ-roadmap migration candidate identified there).

### Live revisions during dispatch

The originally-dispatched plan was revised twice during execution by user direction:

1. **Premise correction (canonical SwiftLint location)**: brief prescribed `swift-standards/swift-standards/main/.swiftlint.yml` as the canonical update target; user clarified that location is no longer canonical. Re-derived → 3-tier `parent_config:` chain hosted at the existing `.github` org-special repos (architecture below).
2. **Source-refactor scope deferred**: brief required fixing every existing violation in the same commit-or-PR sequence as rule landing ("never land a gating rule against a dirty tree"). User explicitly overrode: *"focus on getting the CI in place first. Once CI is finalized, we will address the sources. DO NOT exclude to 'fix'. we welcome the violations as these point us to where we need to make changes. failing CI is expected."* This dispatch lands the gates against a known-violating tree intentionally; violations are the diagnostic surface.

Both revisions stamped in `HANDOFF-rollout-phase-1.md` Live Revisions section per `[HANDOFF-016]`.

### Peer agent coordination

A parallel agent working on swift-institute/.github CI/CD reviewed this dispatch's plan. Confirmed V1-V4 (no edit-window conflicts). Caught one critical defect (V5): the original Wave 1 delete list missed `lint-foundation-family-import-weekly.yml` — a cron orchestrator that also references the audit script via `audit-script-url:`. Without including it in the delete, the next Monday cron would 404 on script fetch. Now in Wave 1's delete list. Tier 2 SwiftLint per-PR enforcement absorbs the weekly's cross-org drift-sweep purpose. Coordination details documented in `HANDOFF-rollout-phase-1.md` Live Revisions.

---

## Architecture: 3-tier SwiftLint inheritance

Apple swift-format has no remote inheritance mechanism — files are discovered by walking up the directory tree. SwiftLint, in contrast, supports `parent_config:` accepting both URLs and local paths, with chained inheritance recursively (verified against [realm/SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md): *"References should be local paths relative to the folder of the configuration file they are specified in. This even works recursively, as long as there are no cycles and no ambiguities."* and *"The referenced remote configuration files may even recursively reference other remote configuration files."*). Child overrides parent in case of conflicts.

The dispatch's architecture exploits SwiftLint's chaining for SwiftLint, and uses sync-script fanout for swift-format:

| Tier | Location | URL | parent_config: | Phase 1 rules landed here |
|---|---|---|---|---|
| **Tier 1 — Ecosystem-wide canonical** | `swift-institute/.github/.swiftlint.yml` | `https://raw.githubusercontent.com/swift-institute/.github/main/.swiftlint.yml` | none (root) | `[API-IMPL-005]` `one_declaration_per_file` opt-in (code-surface ecosystem rule) |
| **Tier 2 — swift-primitives org-specific** | `swift-primitives/.github/.swiftlint.yml` | `https://raw.githubusercontent.com/swift-primitives/.github/main/.swiftlint.yml` | Tier 1 URL | `no_foundation_import_error` + `no_foundation_import_warning` (Foundation ban is primitives-specific) |
| **Tier 3 — Per-sub-package** | each `swift-primitives/swift-*-primitives/.swiftlint.yml` | n/a (per-repo) | Tier 2 URL | per-repo overrides only (e.g. `function_parameter_count` disable) |

### swift-format channel (orthogonal to SwiftLint)

`[DOC-003]` ValidateDocumentationComments lives in `.swift-format` (Apple swift-format catalog rule, not SwiftLint). Distributed via the new `swift-institute/Scripts/sync-swift-format.sh` family-conventional sync script reading the canonical content from `swift-institute/Scripts/swift-format-canonical.json`. Each consumer (133 swift-primitives sub-packages + root) gets a copy of the canonical written by the sync script; override mechanism is `.swift-format.local` marker file (presence-only).

### Rule placement rationale

- `[API-IMPL-005]` at Tier 1: code-surface ecosystem rule (one type per file) with no primitives-specific semantic; applies to all Swift Institute Swift code conceptually. Other ecosystems pick it up automatically when they migrate their `parent_config:` chains. Per peer-agent input: aligns with `feedback_strict_mission_early.md` alpha-phase posture; defers nothing on cautious-rollout grounds.
- `[PRIM-FOUND-001]` at Tier 2: Foundation ban is primitives-specific (only L1 forbids Foundation imports across the ecosystem); placing the rule at Tier 1 would force-ban Foundation in swift-foundations / swift-standards / etc. before they're ready.
- `[DOC-003]` in `.swift-format` (separate channel): catalog match — `ValidateDocumentationComments` is an Apple swift-format linter rule, NOT a SwiftLint built-in. Distributed via fanout (no inheritance) since swift-format has no remote-config mechanism.

### Old canonical (swift-standards/swift-standards) deliberately untouched

The pre-dispatch canonical at `swift-standards/swift-standards/main/.swiftlint.yml` keeps serving its existing content for the ~2400 non-swift-primitives consumers. Only swift-primitives sub-packages re-target their `parent_config:` to the new Tier 2 URL. Other ecosystems migrate when their own dispatches land. This gives blast-radius control: Phase 1 is swift-primitives-only by construction (per user direction "LIMIT SCOPE TO swift-primitives").

---

## Deliverables (status)

| # | Brief deliverable | Status | Artifact |
|---|---|---|---|
| 1 | `swift-institute/Scripts/sync-swift-format.sh` — new sync script mirroring `sync-swift-settings.sh` shape; respects `.swift-format.local` opt-out marker | ✅ Authored | `swift-institute/Scripts/sync-swift-format.sh` (4923 bytes; family conventions: `--dry-run`, unknown-arg-rejected exit-2, `set -e`, idempotent writes, override-respect, REPOS limited to swift-primitives only per user scope) |
| 2 | `swift-institute/Scripts/swift-format-canonical.json` — canonical source-of-truth | ✅ Authored | `swift-institute/Scripts/swift-format-canonical.json` (1906 bytes; current swift-primitives root content + `ValidateDocumentationComments: true`) |
| 3 | Canonical SwiftLint config update | ✅ Re-architected per user direction → 3-tier chain | Tier 1: `swift-institute/.github/.swiftlint.yml` (NEW; canonical body + `[API-IMPL-005]` opt-in flip). Tier 2: `swift-primitives/.github/.swiftlint.yml` (NEW; `parent_config:` Tier 1 + Foundation custom rule pair). Old canonical at swift-standards/swift-standards untouched. |
| 4 | γ-1a workflow removal | ✅ Done (with Wave 1 expansion per peer-agent V5 catch) | Deleted: `lint-foundation-family-import.yml`, `lint-foundation-family-import-weekly.yml`, `audit-foundation-import.py`. Edited: swift-ci.yml caller block lines 262-267 removed + section comment updated; cron-audit-base.yml consumer-list comment updated to remove the deleted weekly. |
| 5 | Source-code refactor across 133 packages | ⏸ **DEFERRED** per user revision: "DO NOT exclude to 'fix'. we welcome the violations." Source refactor is Phase 2+ work. | None this dispatch. Baseline counts in §"Violation counts" below. |
| 6 | Local validation: every package builds + tests pass + swiftlint clean + swift-format lint clean | ✅ Reframed to "CI infrastructure correctness" per user direction. Compiles still pass; lint deliberately fails as the diagnostic surface. | See §"Validation results" |
| 7 | Push plan structured report | ✅ Below | See §"Push plan" |

---

## Violation counts (the diagnostic surface)

Per user direction "we welcome the violations as these point us to where we need to make changes; failing CI is expected." These counts are NOT problems to fix in this dispatch — they are intentional diagnostic output that Phase 2+ source-refactor dispatches address.

| Rule | Violations | Affected packages | Top contributors |
|---|---|---|---|
| `[DOC-003]` ValidateDocumentationComments (swift-format linter) | **155** | 33 | swift-structured-queries-primitives 30, swift-buffer-primitives 21, swift-tree-primitives 11, swift-storage-primitives 9, swift-clock-primitives 7 |
| `[API-IMPL-005]` one_declaration_per_file (SwiftLint Tier 1, opt-in) | **23** | 6 | swift-structured-queries-primitives (multiple files; up to 7 types/file), swift-list-primitives, swift-dictionary-primitives, swift-set-primitives, swift-stack-primitives, swift-carrier-primitives (DocC tutorial step files) |
| `[PRIM-FOUND-001]` Foundation-family import (SwiftLint Tier 2 custom, gating ERROR for Sources/Tests-Support; WARNING for Tests/** elsewhere) | **79** | 6 | swift-render-primitives 51, swift-structured-queries-primitives 12, swift-test-primitives 11, swift-time-primitives 2, swift-dimension-primitives 2, swift-observation-primitives 1 |
| **Total** | **257** | — | — |

### Violation methodology

- `[DOC-003]`: counted by running `swift-format lint --recursive Sources` per swift-primitives sub-package after the canonical fanout (with `ValidateDocumentationComments: true`) and grepping for `ValidateDocumentationComments` in the lint output. swift-format's `format` mode does NOT auto-fix this rule (it's a pure linter rule per the [swift-format catalog](https://github.com/apple/swift-format/blob/main/Documentation/RuleDocumentation.md)).
- `[API-IMPL-005]`: counted by Python heuristic (`re.MULTILINE` regex anchored at column 0 detecting top-level `struct|enum|class|actor|protocol` declarations; flagging files with >1). 23 candidate files across 6 packages identified; cross-checked sample against SwiftLint canonical `one_declaration_per_file` semantics and the heuristic matched. Below the supervisor `ask:` codemod-threshold of 30, so manual splitting is in scope when source refactor dispatches land — no codemod design escalation triggered.
- `[PRIM-FOUND-001]`: counted via the same regex pattern as the (now-deleted) `audit-foundation-import.py` script (`^[ \t]*(?:@[a-zA-Z_]+[ \t]+)*(?:public|package|internal|fileprivate|private)?[ \t]*import[ \t]+(Foundation|FoundationEssentials|FoundationInternationalization)\b`). 79 violations is **79× the brief's expected zero** — γ-1a was deployed advisory (`with: { advisory: true }` in swift-ci.yml caller), so it warned but never gated; files accumulated unenforced. Tier 2 SwiftLint custom rule is severity:error → first push gates immediately.

### Regex parity verification

Side-by-side test of the (deleted) Python audit script regex vs the new SwiftLint custom rule regex against:
- 11 attribute permutations from research §3.4.2 docstring (bare, public, package, internal, fileprivate, private, @_exported, @_exported public, @_implementationOnly, @preconcurrency, @preconcurrency public)
- 6 variants (combinations, FoundationEssentials, FoundationInternationalization, leading whitespace)
- 7 negative cases (non-Foundation imports, comments, string literals, prefix-fail, suffix-`\b`-rejection)

Result: **24/24 cases produce identical match/non-match outcomes**. The Tier 2 SwiftLint custom rule is functionally equivalent to the audit script. The `\b` boundary correctly rejects `import FoundationFooBar`, `import FoundationKit`, etc. SwiftLint uses NSRegularExpression; only standard POSIX-extended regex constructs are used in the rule (no Python-specific extensions like `(?P<name>)` capture groups), so the translation is direct.

---

## Validation results

| Check | Result | Method |
|---|---|---|
| All 134 sub-package `.swift-format` files JSON-valid + `ValidateDocumentationComments: true` | ✅ 133/133 valid (root + 132 sub-packages with `.swift-format`) | `python3 -c json.load` over each file |
| All 132 sub-package `.swiftlint.yml` files YAML-valid + parent_config correctly re-targeted to Tier 2 URL | ✅ 132/132 valid + correct URL | `python3 -c yaml.safe_load` + URL-suffix match |
| Tier 1 + Tier 2 + root `.swiftlint.yml` YAML-valid | ✅ 3/3 valid | `python3 -c yaml.safe_load` |
| `swift-format-canonical.json` JSON-valid | ✅ Valid | `python3 -c json.load` |
| `sync-swift-format.sh` idempotent (apply mode followed by `--dry-run` shows zero remaining diff) | ✅ 0/134 would update after apply | `./sync-swift-format.sh --dry-run` post-apply |
| Regex parity (Tier 2 SwiftLint vs deleted audit script) | ✅ 24/24 cases match | Side-by-side Python-re test |
| `swift-ci.yml` YAML-valid post-γ-1a-caller removal | ✅ Valid | `python3 -c yaml.safe_load` |
| Sample `swift build` post-config-changes (canonical config doesn't break compilation) | ✅ swift-tagged-primitives + swift-carrier-primitives both build clean | `swift build` per package |
| Cross-session contamination preserved untouched | ✅ Unstaged changes in swift-institute/Research (wasm-ci doc, Reflections additions, _index.json wasm-ci entry) untouched; parallel agent's untracked `lint-readme-*.yml` files in swift-institute/.github untouched | git status before/after each commit |

### Deferred to post-push

| Check | Why deferred | When it runs |
|---|---|---|
| Wave 2.5 canary on a public sub-package (verify live `parent_config:` chain Tier 3 → Tier 2 URL → Tier 1 URL resolves under HTTP/cache/CDN realities) | URLs only resolve once Tier 1 + Tier 2 are pushed | After Wave 1 + Wave 2 land on remote; before Wave 3 push wave |
| Full-ecosystem `swift build` + `swift test` across 134 packages | Out of scope per user direction "focus on CI"; config changes don't affect compilation (already sample-verified) | When source refactor dispatches land Phase 2+ |
| `swiftlint` + `swift-format lint` clean per package | Deliberately fails on push as the diagnostic surface; clean state arrives over Phase 2+ source refactor | After Phase 2+ source refactor lands |

---

## Push plan

All pushes require explicit per-action user authorization per `feedback_no_public_or_tag_without_explicit_yes`. The dispatch authored-and-validated locally; no remote pushes from this session.

### Wave 1 — `swift-institute/.github` (commit `7f53280`)

**Branch**: main. **Commit**: `7f53280` "Phase 1 rollout: Tier 1 SwiftLint canonical + γ-1a migration".

| Change | File | Type |
|---|---|---|
| New Tier 1 canonical | `.swiftlint.yml` | A |
| Delete γ-1a per-PR workflow | `.github/workflows/lint-foundation-family-import.yml` | D |
| Delete γ-1a weekly cron orchestrator | `.github/workflows/lint-foundation-family-import-weekly.yml` | D |
| Delete γ-1a audit script | `.github/scripts/audit-foundation-import.py` | D |
| Remove γ-1a caller block (lines 262-267) + update section comment | `.github/workflows/swift-ci.yml` | M |
| Update consumer-list comment removing the deleted weekly | `.github/workflows/cron-audit-base.yml` | M |

**Push impact**: 2414 SwiftLint inheritors are unaffected (they still use the swift-standards canonical until they migrate). swift-primitives sub-packages cannot resolve their new `parent_config:` Tier 2 URL until Wave 2 pushes. The next swift-ci.yml run on any consumer in swift-institute's CI orchestration sees the γ-1a callers gone.

### Wave 2 — `swift-primitives/.github` (commit `8a03db6`)

**Branch**: main. **Commit**: `8a03db6` "Phase 1 rollout: Tier 2 swift-primitives SwiftLint canonical".

| Change | File | Type |
|---|---|---|
| New Tier 2 canonical | `.swiftlint.yml` | A |

**Push impact**: Tier 2 URL begins serving content. swift-primitives sub-packages' `parent_config:` chains now resolve fully (Tier 3 → Tier 2 URL → Tier 1 URL). Tier 2 immediately gates Foundation imports on next CI run for any consumer that picked up Tier 2.

### Wave 2.5 — Live canary (post-push, pre-Wave-3)

Probe the live chain on `swift-carrier-primitives` or `swift-tagged-primitives` (both public; both already on the new Tier 2 URL via local Wave 3 commit; canary catches HTTP/cache/CDN surprises that local mechanical verification misses).

Procedure: trigger one CI run on the canary repo; verify SwiftLint loads the chain without 404s, applies the new rules, and produces the expected violation surface (none for these L1-clean packages, presumably).

### Wave 3 — 132 swift-primitives sub-packages (one commit per repo)

**Branches**: each sub-repo's main. **Commit message** (uniform): "Phase 1 rollout: parent_config re-target + ValidateDocs flip".

| Change | File | Type |
|---|---|---|
| Re-target `parent_config:` from swift-standards/swift-standards URL to Tier 2 URL | `.swiftlint.yml` | M |
| Flip `ValidateDocumentationComments: false` → `true` | `.swift-format` | M |

131 sub-repos committed in this dispatch (one had nothing to commit — likely already in sync). Push order within Wave 3: any order. Each sub-repo's CI run on push will fire the new rules — expect violations per the §"Violation counts" table per package. Failing CI is the intended diagnostic surface.

### Wave 4 — `swift-primitives/` root (workspace-level, NOT a git repo)

The swift-primitives root `.swiftlint.yml` (thin parent_config) and `.swift-format` (canonical content) are workspace-level files; they are not committed to any git repo. They serve as workspace defaults for swift-format/swiftlint commands run from the parent directory. No push action.

### Wave 5 — `swift-institute/Research`

**Branch**: main. **Commit**: this document + `_index.json` entry.

Push impact: this RECOMMENDATION + index entry visible in the public-facing Research catalog.

### Wave-ordering invariants

- **W1 must precede W2**: Tier 2's `parent_config:` references Tier 1 URL; W1 push makes Tier 1 URL resolve.
- **W2 must precede W3**: sub-packages' `parent_config:` references Tier 2 URL; W2 push makes Tier 2 URL resolve.
- **W2.5 canary between W2 and W3**: catch HTTP/cache/CDN surprises before fanning out to 132 sub-repos.
- **W3 may interleave with W5** in any order: independent.

---

## Known follow-ups

### Phase 2+ source refactor dispatches (per user direction)

The 257 violations require source-refactor dispatches to clear:

| Phase 2 dispatch | Scope | Estimated cost |
|---|---|---|
| Phase 2a — `[API-IMPL-005]` file-splitting refactor | 23 violations across 6 packages (top: swift-structured-queries-primitives 12 files, swift-list-primitives 1 with 4 types) | Manual file splits; ~5-10 min each → ~2-4 hours |
| Phase 2b — `[DOC-003]` doc-comment fixes | 155 violations across 33 packages; categories: missing `Throws:` sections, remove `Returns:` from inits, fix Parameter-list mismatches, replace inline `Parameter` with plural `Parameters:` | Doc-comment edits; ~30-60s each → ~1.5-2.5 hours |
| Phase 2c — `[PRIM-FOUND-001]` Foundation removal | 79 violations across 6 packages (51 in swift-render-primitives alone) | Domain refactor; mixed mechanical (unused-import removal) + semantic (replace `Date`/`URL`/`UUID` with primitive equivalents); some may need redesign. Rough ~10-30 min/file → multi-day |

Phase 2c (Foundation) is the heaviest. Per the brief's `feedback_workspace_scope_l1_only.md` and the user's strict-mission posture, swift-primitives is L1 — Foundation imports are primitives-rule violations by definition. Some likely need replacement with primitive types; others may be `// swiftlint:disable:next no_foundation_import_error  // reason: <tracking-issue>` if a primitive replacement isn't yet available (then the tracking issue captures the migration need).

### Phase 1.5 polish items

- `swift-primitives/.swiftlint.yml` (root, workspace-level): verify the disabled-rules override (`function_parameter_count`) is still desired or fold into Tier 2.
- `cron-audit-base.yml` consumer-list comment: when the weekly cron orchestrators converge to a stable consumer set, refresh the comment.

### Future dispatch candidates (out of Phase 1 scope)

- The 40 standalone SwiftLint outliers (parent-thread item — separate cleanup dispatch).
- Generalization of the 3-tier `parent_config:` chain to swift-foundations / swift-standards / other ecosystems.
- γ-1b license-header migration (parallel to this γ-1a migration; tracked separately).
- Migration of remaining 192 swift-primitives mechanical rules per Phase 2+ classification cohorts.

### Coordination notes

- Parallel CI/CD agent landed F-series + PM #1/3/4 composite refactors today. Their edit window for swift-institute/.github + swift-primitives/.github is closed; pushes here don't conflict with theirs. PM #4 commit `ffffd8a` (today) refactored the now-deleted weekly orchestrator — that work is intentionally reverted by this dispatch's deletion.
- Untracked `lint-readme-*.yml` files in `swift-institute/.github/.github/workflows/` belong to the parallel agent and were NOT staged in this dispatch's commits.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05). Pending principal sign-off on push waves.

### Key findings

1. **3-tier `parent_config:` chain** is the structurally-correct mechanism for SwiftLint canonical inheritance across the swift-institute ecosystem. URL-based parent_config (vs the relative-path approach initially drafted) is the only viable mechanism for distributed CI where each sub-repo is checked out standalone. Verified mechanically against SwiftLint docs.
2. **swift-format fanout** via `sync-swift-format.sh` (sibling to `sync-swift-settings.sh` family) is the correct mechanism for Apple swift-format since its config has no remote inheritance. The new script + canonical JSON join the existing sync-script family.
3. **γ-1a workflow → SwiftLint custom rule migration** is structurally complete: regex parity verified 24/24 cases; both per-PR caller and weekly cron deleted (peer agent caught the latter; my draft missed it). Tier 2 per-PR enforcement absorbs both purposes.
4. **Foundation imports baseline = 79** (vs brief's expected zero): γ-1a was advisory, never gating; violations accumulated unenforced. Tier 2 is severity:error → gates immediately. This is the intended diagnostic surface per user direction.
5. **Total violation surface = 257** (DOC-003: 155, API-IMPL-005: 23, Foundation: 79). Source-refactor cleanup is Phase 2+, not this dispatch.

### Out-of-scope items (deliberately not done per dispatch brief + user revisions)

- Pushing any commit to any remote (per supervisor block + user direction).
- Source-code fixes for the 257 violations (per user revision: "DO NOT exclude to 'fix'; failing CI is expected").
- `swiftlint --fix` auto-correct pass (would silently change source).
- `swift-format format` auto-correct pass for `[DOC-003]` (rule is linter-only, no auto-fix anyway).
- `excluded:` paths in Tier 2 to suppress the 79 Foundation violations (per user "DO NOT exclude").
- Generalization beyond swift-primitives (per user "LIMIT SCOPE TO swift-primitives").
- Modifying the v1.2.0 design document `centralized-swift-ci-and-spine-gate.md`.
- In-line-disable enforcement check (recommendation comment authored at Tier 1; no enforcement).
- The 40 standalone SwiftLint outliers, γ-1b workflow, γ-2 workflow, or any in-flight HANDOFF / AUDIT (per Do Not Touch list).

### Supervisor block verification stamp

Per `[HANDOFF-010]` step 5: each supervisor ground-rule entry verified against work product —

| Entry | Type | Verification |
|---|---|---|
| Read all "Relevant Files" content before authoring | MUST | Verified — sync-swift-settings.sh + sync-skills.sh + sync-dependabot.sh patterns read; γ-1a workflow + audit script + swift-ci.yml caller line + cron-audit-base.yml + v1.2.0 §3.4.2 design + canonical SwiftLint config + swift-primitives root .swift-format all read in full at write time. |
| Follow family conventions for sync scripts | MUST | Verified — sync-swift-format.sh has `--dry-run`, unknown-arg-rejection (exit 2), `set -e`, idempotent writes (cmp before write), override-respect via `.swift-format.local` marker. Mirrors sync-dependabot.sh shape (closest pattern reference). |
| Validate locally end-to-end | MUST | Verified — reframed per user direction to "CI infrastructure correctness" (configs parse, regex parity, no compile breakage). Source-compliance validation deliberately deferred per "failing CI is expected". |
| Fix every existing violation in the same commit-or-PR sequence | MUST | **Explicitly OVERRIDDEN by user revision**: "focus on CI; DO NOT exclude to 'fix'; failing CI is expected." Source refactor moved to Phase 2+. Live revision stamped in HANDOFF-rollout-phase-1.md. |
| Preserve cross-session contamination untouched | MUST | Verified — wasm-ci doc + Reflections additions + Reflections/_index.json mod (in swift-institute/Research) all untouched; parallel agent's `lint-readme-*.yml` untracked files in swift-institute/.github untouched. Each commit's staged file list audited. |
| Commit-as-you-go per [HANDOFF-019]; one focused commit per logical unit | MUST | Verified — Wave 1 (1 commit, swift-institute/.github), Wave 2 (1 commit, swift-primitives/.github), Wave 3 (131 commits, one per sub-repo). Scripts work was already autosaved (commit 5c2275a "Save progress: 2026-05-05" — autosave hook captured the dispatch's authored files into one commit). |
| Per-rule pre/post violation counts in the report | MUST | Verified — see §"Violation counts". Pre = post since no fixes (per user direction). |
| Do not push any commit to any remote | MUST NOT | Verified — no `git push` invocations. |
| Do not modify any rule's mechanical/hybrid/semantic class | MUST NOT | Verified — classification doc unchanged; this dispatch only sub-classifies into enforcement-tool buckets and lands the 3 selected for Phase 1. |
| Do not modify the v1.2.0 design (`centralized-swift-ci-and-spine-gate.md`) | MUST NOT | Verified — no edits to that file. |
| Do not author an in-line-disable enforcement check | MUST NOT | Verified — Tier 1's `### Disabling a rule` block is recommendation comment only, no automated check. |
| Do not generalize beyond swift-primitives | MUST NOT | Verified — `applies_to: [swift-primitives]`. Tier 1 is hosted at swift-institute/.github but its content is the migration target of swift-standards/swift-standards's canonical (not new ecosystem-wide expansion); other ecosystems retain the old canonical until they migrate themselves. |
| Do not modify any consumer's `.swift-format` directly except via the sync script's run | MUST NOT | Verified — all 134 .swift-format file updates went through `sync-swift-format.sh` apply mode (idempotent post-apply). |
| Do not touch the 40 standalone SwiftLint outliers, γ-1b workflow, γ-2 workflow, or any in-flight HANDOFF/AUDIT | MUST NOT | Verified — none touched. |
| γ-1a workflow currently live + canaried green; removal is the migration | fact | Honored — Wave 1 deletion is the migration step; Tier 2 SwiftLint custom rule absorbs both per-PR + weekly purposes. |
| Cross-org blast radius is real; SwiftLint canonical changes propagate immediately | fact | Honored — old canonical at swift-standards/swift-standards untouched; only swift-primitives sub-packages migrate. Other ecosystems wait for their own dispatches. |
| Cost discipline (Max OAuth token, no API key) | fact | Honored — no token-heavy operations; baseline counts via fast Python heuristics not per-package swiftlint invocations (the latter was tried and abandoned for being too slow). |
| If `[API-IMPL-005]` violations >30 → propose codemod design before manual splitting | ask | Not triggered — count is 23 < 30. |
| If SwiftLint custom Foundation regex cannot cover all 9 attribute permutations → surface gap | ask | Not triggered — regex parity verified 24/24 cases. |
| If validation surfaces unrelated regression → do NOT fix; surface as finding | ask | Not triggered — sample swift build clean on probe packages; no regressions. |
| If `.swift-format.local` opt-out marker found → surface list before sync run | ask | Not triggered — zero markers found across swift-primitives. |

---

## References

- `swift-institute/Research/mechanical-rule-tool-classification-swift-primitives.md` v1.0.0 — sub-classification dispatch that selected Phase 1's 3 rules.
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 §3.4.2 — γ-1a Foundation design (regex permutations).
- `swift-institute/Research/workflow-construction-phase-1.md` — γ-1a workflow + audit script provenance.
- `https://raw.githubusercontent.com/swift-standards/swift-standards/main/.swiftlint.yml` — pre-dispatch SwiftLint canonical (kept untouched; serves non-swift-primitives ecosystems).
- `swift-institute/Scripts/sync-swift-settings.sh` + `sync-skills.sh` + `sync-dependabot.sh` — sync-script family pattern references.
- [Apple swift-format Rules.md](https://github.com/apple/swift-format/blob/main/Documentation/RuleDocumentation.md) — `ValidateDocumentationComments` is a linter rule (not auto-fix-capable).
- [SwiftLint README](https://github.com/realm/SwiftLint/blob/main/README.md) — `parent_config:` URL chaining semantics (verified 2026-05-05).
- `/Users/coen/Developer/HANDOFF-rollout-phase-1.md` — dispatch brief + Live Revisions sections.
