# GitHub Repository Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-05
status: REFERENCE
-->

> Non-normative companion to `Skills/github-repository/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, empirical-grounding narratives, worked examples,
> pilot-status notes, and the dated frontmatter changelog. The skill file remains the CANONICAL source for
> all `[GH-REPO-*]` requirement statements; nothing in this archive is normative. Organized by rule ID; the
> dated changelog is collected in the final section.

---

## §[GH-REPO-021] Topics Open Vocabulary — Why (evicted 2026-07-05)

**Why open vocabulary**: topics describe content, and content is what the repo author knows best. A central registry creates bureaucratic friction for an inherently-extensible vocabulary; a closed enum (briefly adopted in Wave 2b 2026-05-10 then retracted same-day per principal direction) also creates a 5:1 mismatch problem when the registry inevitably lags real-world repo state.

## §[GH-REPO-054] Sidebar Visibility — Provenance (evicted 2026-07-05)

**Provenance**: Reported as a sidebar-noise issue 2026-04-29; encoded as a rule pending API support. Releases-default-on per principal correction 2026-04-29. See `Research/github-metadata-harmonization.md` § 7 Q10.

## §[GH-REPO-055] hasProjectsEnabled=false — Provenance (evicted 2026-07-05)

**Provenance**: Principal direction 2026-07-03 — `swift-foundations/swift-html-render` was found carrying the default-on Projects tab; an ecosystem inventory then found 402 of 495 non-archived repos in the same default-on state (Projects was never part of the launch-flip settings checklist, so only launch-audited repos had it off). Additive per [SKILL-LIFE-003]: governs GitHub-side state going forward; a one-shot `sync-metadata.yml` convergence run brings the existing 402 into conformance.

## §[GH-REPO-056] Merge Method — Provenance (evicted 2026-07-05)

**Provenance**: Principal direction 2026-07-03 — a settings-governance audit (the [GH-REPO-055] Projects arc's follow-on) found merge settings ungoverned and sitting at the GitHub default (all three methods on, auto-delete off) on 493 of 494 non-archived repos. Additive per [SKILL-LIFE-003]: governs GitHub-side state going forward; a one-shot convergence run brings the 493 into conformance.

## §[GH-REPO-057] Secret Scanning — Provenance (evicted 2026-07-05)

**Provenance**: Principal direction 2026-07-03 — the settings-governance audit (the [GH-REPO-055]/[GH-REPO-056] arc) found secret scanning and push protection DISABLED on every repo in the ecosystem despite being free on public repos. Additive per [SKILL-LIFE-003]: a one-shot convergence run enables both on all 364 public non-archived repos.

## §[GH-REPO-063] Schema↔Workflow Key Consistency — Provenance (evicted 2026-07-05)

**Provenance**: 2026-07-03 — the schema documented `defaultBranchRef` while the workflow read `.settings.defaultBranch` (the two never agreed; harmless only because the branch default is `main` regardless). Surfaced during the settings-governance audit that followed the [GH-REPO-055]/[GH-REPO-056] arc. Additive per [SKILL-LIFE-003].

## §[GH-REPO-074] Thin Callers — Why, Sync Mechanism, Reference Application, Provenance (evicted 2026-07-05)

**Why thin callers**: changes to CI shape (a new platform leg, a new lint rule, a new test matrix) propagate by editing one file in `swift-institute/.github` plus, when needed, regenerating per-package callers. Inline-job per-package workflows accumulate drift — the same fix has to land in N package files instead of one centralized file. The centralized model also keeps cross-org GitHub-Actions authentication scoped to `swift-institute/.github` per [GH-REPO-073].

**Sync mechanism**: as of 2026-05-10 there is NO `Scripts/sync-ci-callers.sh` in `swift-institute/Scripts`. The 2026-04-29 centralized-workflow trim was a one-shot migration that subsequently consolidated the shape further (three thin callers → one). A future regenerator is conditional on the reusables becoming versioned (`@v1`) — at that point a sync tool that rewrites `uses: ...@v1` to `@v2` per-caller would be the centralized adoption mechanism per [GH-REPO-077]'s "Avoid per-repo PR storms at versioning time" clause. While reusables remain at `@main`, per-package callers track the centralized reusable automatically — no regeneration step needed.

**Reference application**: `swift-carrier-primitives/.github/workflows/ci.yml` — one thin caller with `ci` + `docs` jobs, under 30 lines. The 2026-05-10 consolidation removed per-package `swift-format.yml` / `swiftlint.yml` files (the intermediate post-2026-04-29-trim shape) in favor of layer-wrapper absorption.

**Provenance**: 2026-04-29 centralized-workflow-trim arc (3-thin-caller intermediate shape) + 2026-05-10 consolidation (1-thin-caller canonical) per the dependabot-cleanup arc that surfaced 7 unmigrated repos and forced clarification of the canonical shape. Reflections: `Reflections/2026-04-29-carrier-launch-arc-and-centralized-workflow-trim.md`; `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md` (Pass 3 supplemental refinement, 2026-04-30).

## §[GH-REPO-075] Thin-Caller Schema Validation — Why, Worked Example, Provenance (evicted 2026-07-05)

**Why a regenerator gate, not a runtime catch**: GitHub Actions rejects the schema-mismatched workflow at runtime with `startup_failure` and no diagnostic — the failed job displays as red with no log, no exit code, and no surfaced reason. The mismatch is catchable at sync time because both YAMLs are local files; the comparison is mechanical; the cost of the gate is sub-second per caller. Without the gate, the failure mode is a red CI run that the consumer cannot diagnose without reading both YAMLs and reverse-engineering the silent rejection.

**Worked example** (canonical 2026-05-01 origin incident): swift-property-primitives 0.1.0 launch. Property's callers passed `secrets: PRIVATE_REPO_TOKEN: ${{ secrets.PRIVATE_REPO_TOKEN }}` to centralized `swiftlint.yml@v1` and `swift-format.yml@v1`, neither of which declared a `secrets:` block in their `workflow_call:`. The carrier reference (validated post-trim) shipped with no secrets passed. Property's EXCLUDE entry in `Scripts/sync-ci-callers.sh:48` skipped property in the regenerate-against-carrier sweep, so property's callers stayed at the pre-trim shape. CI surfaced the mismatch only at runtime via `startup_failure` with no diagnostic. Fix: align property callers + drop property from EXCLUDE.

**Provenance**: 2026-05-01 property 0.1.0 launch arc; cohort-wide sync-ci-callers EXCLUDE staleness when canonical reference moved property → carrier. `Reflections/2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md`.

## §[GH-REPO-076] metadata.yaml Exclusive Source — Why, Empirical Grounding, Worked Example (evicted 2026-07-05)

**Why**: Two parallel stores invite drift even with sync automation, so custom properties are derived projections of metadata.yaml, never a second authoring surface. Whether to project a given field is decided by **capability-fit** — does the field need a GitHub-native capability (org-wide query, ruleset targeting, OIDC claim) that metadata.yaml cannot provide? — not by whether a consumer currently demands it. A field that needs none of those capabilities is already fully expressed by metadata.yaml, so projecting it would add only sync / drift-detection surface.

**Empirical grounding**: 2026-05-10 probe (commits `08653c1..2e24ddf` in `swift-institute/.github`) confirmed custom property values are NOT rendered in the public repo About sidebar — ruling out the visibility use case that initially motivated investigation. The remaining qualifying use cases (org-wide single-call query, ruleset targeting, OIDC claim) are *programmatic* capabilities rather than a UI surface, which is why the rule keys on capability-fit (data shape) — whether the field needs that capability — rather than on a current consumer. GitHub docs ([Managing custom properties for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)) describe only Settings → Custom properties as the viewable UI path; an outstanding community feature request ([Discussion #69914](https://github.com/orgs/community/discussions/69914)) asks for About-sidebar visibility, confirming the absence is intentional rather than a probe-side methodology gap.

**Worked example** (no-projection case, 2026-05-10): The `discussion:` field of `.github/metadata.yaml` (per [GH-REPO-091]) could plausibly be projected to a URL-typed `discussion_url` custom property (URL type added per the 2026-12-09 changelog with built-in format validation). The discussion URL needs none of the three GitHub-native capabilities (org-wide query, ruleset targeting, OIDC claim); the two existing surfaces (metadata.yaml + the README marker block updated by `sync-discussion-threads.yml`) fully express it. **Decision: no projection** — on capability-fit grounds, not consumer count. Add one if/when the field genuinely needs a GitHub-native capability (e.g., a ruleset or OIDC claim keyed on the discussion URL).

## §[GH-REPO-077] Dependabot Scoping — Why, Empirical Grounding, Provenance (evicted 2026-07-05)

**Why**:

1. **Honest configuration**: a repo's `dependabot.yml` documents what Dependabot can act on. Configuring an ecosystem with no bumpable pins is decorative and produces noise.

2. **Surface, don't hide, [GH-REPO-074] violations**: an auto-detect variant that scans workflows for bumpable shapes and configures `github-actions` accordingly would silently re-enable scanning on non-conforming repos, hiding the conformance gap. The class-based rule treats inline refs as a violation requiring migration.

3. **Avoid per-repo PR storms at versioning time**: if the centralized reusables move from `@main` to `@v1`, distributed per-package `github-actions` scanning would generate ~380 PRs per major-version bump. Centralized adoption belongs in `Scripts/sync-ci-callers.sh` as a single regen sweep per [GH-REPO-074]/[GH-REPO-075] — not in Dependabot per-repo scanning. The class-based rule does not pre-commit to that wrong default; the decision is made explicitly at versioning time.

**Empirical grounding**: 2026-05-10 triage of 86 open Dependabot PRs across 7 institute orgs classified them as:
- 68 zombies — PR modifies a workflow file that no longer exists on `main` (the per-repo file was deleted by the 2026-04-29 trim; Dependabot's pre-trim PR targets the deleted shape).
- 15 non-thin — PR modifies an existing inline-action workflow in a [GH-REPO-074]-non-conforming repo missed by the trim. Repos: `swift-html-chart`, `swift-html-css-pointfree`, `swift-html-fontawesome`, `swift-html-prism` (foundations); `swift-rfc-7231` (ietf); `swift-iso-14496-22` (iso); `swift-numeric-formatting-standard`, `swift-standards` (standards).
- 3 swift-pkg — legitimate `Package.swift` bumps; review on merit.

The uniform-canonical produced both noise classes: zombies because `github-actions` scanning was configured in repos whose workflows were reshaped (and the PRs target the pre-trim shapes), and non-thin because the trim missed 8 repos. The class-based rule eliminates the zombie class by construction and surfaces the non-thin class as migration work.

**Provenance**: 2026-05-10 triage and rule extraction; supersedes the "keeping the entry uniform costs nothing" framing in the pre-2026-05-10 `Scripts/dependabot-canonical.yml` header comment.

## §[GH-REPO-090] Centralized Discussion Thread — Pilot Scope, Rationale, Provenance (evicted 2026-07-05)

**Pilot scope (2026-05-10)**: rolled out to swift-primitives only — 11 packages: `swift-carrier-primitives`, `swift-comparison-primitives`, `swift-either-primitives`, `swift-equation-primitives`, `swift-hash-primitives`, `swift-ownership-primitives`, `swift-pair-primitives`, `swift-product-primitives`, `swift-property-primitives`, `swift-standard-library-extensions`, `swift-tagged-primitives`. Cohort expansion to swift-standards (17 packages) and swift-foundations (4 packages) follows after pilot validation. `swift-carrier-primitives` and `swift-tagged-primitives` are designated canaries for the workflow's first live runs.

**Rationale**: Centralized discussion at `swift-institute/.github` keeps ecosystem conversation in one searchable surface — one click from `github.com/orgs/swift-institute/discussions` — without multiplying per-repo discussion sections per [GH-REPO-051]. Per-package threads scale to N packages without exploding category count; a single "Packages" category holds all threads.

**Provenance**: Skill-design discussion 2026-05-10; same-day setup of discussions on `swift-institute/.github`, "Packages" category creation, and swift-institute-bot App permissions extension (Discussions: Read & Write).

## §[GH-REPO-093] Discussion Thread Conventions — Body Evolution (evicted 2026-07-05)

**Body evolution**: the minimal body is the workflow-rendered initial state. The principal MAY edit the thread body in-place after creation (GitHub permits author/maintainer edits to discussion bodies). Subsequent sync runs do NOT overwrite a manually-edited body — the workflow's `createDiscussion` mutation fires only on absent `discussion:` field, not on each run.

## §[GH-REPO-094] Hub Override — Worked Example, Provenance (evicted 2026-07-05)

**Worked example (origin incident, 2026-05-10)**: Discussions enabled + "Packages" category created at ~05:30 UTC. `sync-metadata-nightly.yml` ran at 06:28 UTC, applied default `hasDiscussionsEnabled=false`. Carrier canary live run dispatched at 06:57 UTC failed at the `createDiscussion` step with "Could not resolve to a node with the global id of 'DIC_kwDOSDTLes4C8spE'". Fix: add the override to `swift-institute/.github/.github/metadata.yaml` (commit `b439b16`), dispatch `sync-metadata.yml` manually for immediate sync, verify discussions and categories restored. Categories survived the toggle (same IDs, including `Packages` at `DIC_kwDOSDTLes4C8spE`); only the visibility had been suppressed.

**Provenance**: 2026-05-10 carrier canary failure-and-fix arc; commit `b439b16` on `swift-institute/.github`.

---

## Changelog-Provenance (frontmatter changelog evicted 2026-07-05)

- 2026-07-03 (4): [GH-REPO-057] ADDED — secret scanning + push protection MUST be enabled on PUBLIC repos (free); private exempt (needs GHAS, no billing). Managed by sync-metadata.yml via a visibility-guarded `security_and_analysis` PATCH (gh repo edit/view expose no security surface). [GH-REPO-060] schema + metadata-schema.json extended with secretScanning/secretScanningPushProtection. Origin: settings-governance audit found both disabled ecosystem-wide. Additive per [SKILL-LIFE-003]; principal direction 2026-07-03.
- 2026-07-03 (3): [GH-REPO-023] RELAXED — topic floor 3 → 2 (bare layer tag + ≥1 domain; atomic single-concept packages legitimately carry `[layer, one-domain]`). Audit found 237 non-archived repos (156 public) at 2 topics as their honest tag set; the old floor forced a noise 3rd tag. A relaxation (3+ repos unaffected), not breaking. Schema-bound reconciliation (minItems 0→2, maxItems 20→10) deferred. Principal direction 2026-07-03.
- 2026-07-03 (2): [GH-REPO-056] ADDED — merge method squash-only + auto-delete merged branches (allowSquashMerge=true, allowMergeCommit/allowRebaseMerge=false, deleteBranchOnMerge=true); applied via `gh api PATCH` (gh repo edit lacks the merge-allow flags). [GH-REPO-063] ADDED — schema↔workflow settings-key consistency guard (`validate-schema-workflow-keys.py`), prompted by the defaultBranchRef/defaultBranch mismatch. [GH-REPO-060] schema + metadata-schema.json extended with the 4 merge keys. Origin: settings-governance audit following [GH-REPO-055]; merge settings ungoverned at GitHub default on 493/494 repos. Additive per [SKILL-LIFE-003]; principal direction 2026-07-03.
- 2026-07-03: [GH-REPO-055] ADDED — `hasProjectsEnabled = false` (direct analog of [GH-REPO-052] wiki default-off; a default-on GitHub feature the Institute uses nowhere). Managed by sync-metadata.yml via `gh repo edit --enable-projects`, default-off on YAML silence per [GH-REPO-062]; [GH-REPO-060] schema + metadata-schema.json settings block extended with the key. Origin: swift-foundations/swift-html-render found Projects-on; ecosystem inventory 402/495 non-archived repos default-on (never in the launch-flip checklist). Additive per [SKILL-LIFE-003]; principal direction 2026-07-03.
- 2026-07-02 (2): [GH-REPO-081] RETIRED — swift-institute.org is the sole ecosystem website; per-layer {layer}.org stub repos approved for deletion; ID kept as redirect anchor. [GH-REPO-010] amended — scaffold repos MUST use the truthful reservation description form ("Namespace reserved for «domain» in Swift."); replaces the retired stub-description reference. Cross-refs propagated ([GH-REPO-023] exemption list, [GH-REPO-030] homepage table). Principal direction 2026-07-02; per [SKILL-LIFE-003]/[SKILL-LIFE-007].
- 2026-07-02: [GH-REPO-011] BREAKING — content-phrase richness clause added: vacuous single-noun content phrases ("Async for Swift.") forbidden; distinctive-capability phrasing required within the class template. Existing vacuous descriptions now violate; corpus remediation sweep dispatched same day. Provenance: independent posture audit + principal direction 2026-07-02; per [SKILL-LIFE-003].
- 2026-06-09: [GH-REPO-076] BREAKING — relaxed the consumer-demand gate on custom-property projections. Add-criterion flipped from "a named consumer requires it / speculative forbidden / keys on consumer demand" to capability-fit (data shape): project a metadata.yaml field when it needs a GitHub-native capability (org query / ruleset / OIDC) metadata.yaml can't provide, regardless of a current consumer. Single-source + one-way-sync + drift-revert discipline unchanged. Principal direction (first-principles MO, not consumer-demand); per [SKILL-LIFE-003].
- 2026-05-14: `[GH-REPO-074]` Statement wording amended per [SKILL-LIFE-003] — "single job" → "every job" — to match the Correct example + Reference application (`swift-carrier-primitives/.github/workflows/ci.yml` with `ci` + `docs` two thin-call jobs). The principle is unchanged; this is a wording fix to remove internal inconsistency. Surfaced during pilot 7 of `/promote-rule`; mechanization proceeded under Examples-as-authoritative (Pass A "wording-only defect carve-out" per the calibrated `lint-rule-promotion` Phase 1). Clarifying per [SKILL-LIFE-003].
- 2026-05-14: Pilot 7 of `/promote-rule` mechanized `[GH-REPO-074]` — new validator `validate-thin-callers.py` + reusable workflow `validate-thin-callers.yml` under `swift-institute/.github/.github/`. Checks canonical `ci.yml` for inline `runs-on:` / `steps:` / missing `uses:`, plus forbidden-standalone `swift-format.yml` / `swiftlint.yml`; honors the `on: workflow_call:` tool-reusable carve-out. Validation: 0 findings across 317 per-package repos workspace-wide (canonical seven + every other Package.swift-at-root repo). The 8 repos cited in `[GH-REPO-077]` as non-conforming on 2026-05-10 have all been migrated. Synthetic fixtures (`tests/fixtures/gh-repo-074/`) confirm detection: 3 findings on inline-jobs, 1 on standalone-format. Statement-vs-example mismatch surfaced ("single job" vs reference shape's `ci` + `docs` two-job pattern) — amended in the preceding diary entry per [SKILL-LIFE-003]. Clarifying per [SKILL-LIFE-003].
- 2026-05-10: [GH-REPO-020] reframed "Required topics" → "Recommended topic shape"; [GH-REPO-021] rewritten "hybrid governance" → "open vocabulary" per principal direction retracting the closed-enum schema constraint. metadata-schema.json's topics.items.anyOf enum stripped; schema now validates shape only. Each repo establishes its own tags based on content. The 273-extant-topic-tag question (Wave 2b finalization criterion 2 partial) dissolves under open vocabulary — no reconciliation needed.
- 2026-05-10: Cluster C reflection-processing — added [GH-REPO-075] thin-caller schema validation per Reflections/2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md (sync-ci-callers schema-mismatch failure mode + reference-template-movement EXCLUDE staleness).
- 2026-05-10: [GH-REPO-092]/[GH-REPO-093] amended — category resolved at runtime by slug `packages` (defensive against future category-recreation events that change IDs); sync-discussion-threads-nightly.yml authored at 04:30 UTC for daily validation sweep.
- 2026-05-10: [GH-REPO-091] format string amended (org-aggregate URL form is what `createDiscussion` returns) + [GH-REPO-094] added (hub repo metadata.yaml MUST override `hasDiscussionsEnabled: true` to survive sync-metadata-nightly's default-false revert) — origin incident: swift-carrier-primitives canary live run failure.
- 2026-05-10: Added [GH-REPO-090..093] for centralized discussion threads on swift-institute/.github (pilot scope: swift-primitives, canaries: carrier + tagged).
- 2026-05-10: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — [GH-REPO-021] inline tag enumeration extracted to canonical `swift-institute/.github/topic-registry.json` per decision 6. validate-github-metadata.yml workflow consumes it. Clarifying per [SKILL-LIFE-003].
- 2026-05-10: Wave 2b finalization (HANDOFF-wave-2b-finalization.md) — Decision-6 architectural pivot: topic-registry.json retired in favor of `swift-institute/.github/metadata-schema.json` (JSON Schema). [GH-REPO-021] revised to cite the schema. Clarifying per [SKILL-LIFE-003].
