# Skill Corpus Holistic Review

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Swift Institute skill corpus has grown to **37 skills** across **4 layers** (1 meta, 3 architecture, 14 implementation, 19 process). Recent work — particularly the carrier-primitives 0.1.0 launch arc (April 2026) — has both added significant new content and exposed places where the corpus has accumulated drift, weak rules, ghost references, and gaps.

This review was triggered by an explicit principal request after the carrier-launch case-study landed: *"Holistic review of our skills to see which skill might have accrued weak areas, superseded sections, mistakes, or areas that can be improved. Or skills that should be split, or missing skills even."*

The review is Tier 2 per [RES-020]: cross-package analysis with reversible-precedent recommendations. The output is a categorized findings inventory plus a prioritized triage of follow-up work.

**Step 0 prior-research grep** (per [RES-019]) identified ~12 prior research documents on skill-corpus topics:

- `agent-workflow-skill-consistency-audit.md` (2026-04-15) — prior cluster audit of the agent-workflow cluster (handoff / supervise / reflect-session / skill-lifecycle); verified to inform Cluster G review
- `skill-shape-and-growth-evaluation.md` — corpus shape analysis; cited by `[SKILL-CREATE-005a]` multi-file navigation-hub exception
- `skill-loading-reliability.md`, `skill-creation-process.md`, `skill-based-documentation-architecture.md`, `skill-as-input-composition-pattern.md`, `compose-then-trace-skill-design-phase.md` — design rationale for how skills are structured
- `documentation-skill-design.md`, `readme-skill-design.md`, `generalized-audit-skill-design.md`, `audit-finding-triage-taxonomy.md` — per-skill design records
- `implementation-patterns-skill.md` — pattern absorption history

Findings below cite these prior docs by name where relevant. This review **extends** the prior cluster audit (2026-04-15) rather than replaces it; persistent findings from that audit are tracked in Cluster G.

## Question

Across the 37 skills in the corpus, which exhibit:

1. **Weak areas** — vague rules, missing examples, weak rationale
2. **Superseded sections** — rules contradicted or duplicated by newer rules
3. **Mistakes** — factually wrong claims, broken examples, ghost references, ID drift
4. **Improvements** — clarifications without normative-force changes
5. **Split candidates** — single-file skills that have grown to deserve a multi-file navigation hub per `[SKILL-CREATE-005a]`, or single skills covering multiple distinct domains
6. **Missing skills** — categories implied by ecosystem need but not yet codified

What are the prioritized remediation actions, and which clusters warrant `[SKILL-LIFE-031]` cluster-review treatment?

## Methodology

The review used three parallel mechanisms:

1. **Eight cluster-assessment agents** dispatched in parallel via `Explore` subagent. Each was briefed to read its assigned skills in full, identify findings under the six categories, and produce a structured report with line-number citations. Agents covered: A (architecture, 4 skills), B (code-surface + ownership, 4), C (platform + infrastructure, 6), D (testing + benchmark, 4), E (documentation + readme + github, 3), F (audit + research + forums + evolution, 5), G (session + handoff + skill-lifecycle, 5), H (tooling + misc, 8). Total: 39 skill-coverage assignments (some skills covered by multiple agents for cross-validation).

2. **Mechanical cross-skill scan** for duplicate IDs, ghost references, and `last_reviewed` staleness, using the procedures in `[AUDIT-028]` (notation-variant coverage) and `[REFL-PROC-016]` (pre-commit ID-uniqueness scan), extended to cover the full corpus.

3. **Prior-research synthesis** per `[RES-013a]` — each finding inherited from `agent-workflow-skill-consistency-audit.md` (2026-04-15) was verified against the current state and marked as `RE-VERIFIED`, `RESOLVED`, or `STILL OPEN`.

The review produces no skill amendments; each finding is a candidate for follow-up per `[SKILL-LIFE-002]` (provenance-tracked update). Remediation is the principal's call.

## Analysis

### Mechanical scan results

**Duplicate IDs across all skills**: zero detected. The `[REFL-PROC-016]` discipline (added 2026-04-24) and the `[SKILL-CREATE-012]` ID-uniqueness grep have held the corpus collision-free since the April-24 cluster audit's renumbering wave.

**`last_reviewed` staleness** (>30 days from 2026-04-30; cadence per `[SKILL-LIFE-012]` is 90 days for implementation, 180 for process/architecture, on-demand for meta — none are past cadence):

| Skill | Last reviewed | Days | Layer | Verdict |
|---|---|---|---|---|
| collaborative-discussion | 2026-03-20 | 40 | process | Stable; no content drift expected. Bump after carrier validation acknowledged. |
| document-markup | 2026-03-20 | 40 | implementation | Possibly stale: rendering ecosystem (PDF, HTML, Markdown) consolidated April; verify package-import paths. |
| ecosystem-data-structures | 2026-03-26 | 34 | implementation | Possibly stale: missing `Carrier` entry; verify Storage variants. |
| package-export | 2026-03-20 | 40 | process | Stable; format is language-agnostic. Bump only. |
| swift-institute | 2026-03-20 | 40 | architecture | Content gaps — see Cluster A. Needs revalidation, not just bump. |
| swift-pull-request | 2026-03-24 | 36 | process | Stable: workflow unchanged; `[SWIFT-PR-011]` is recent valuable addition. Bump only. |
| testing-institute | 2026-03-27 | 33 | process | Has structural defect (ghost rules); see Cluster D. |
| testing-swiftlang | 2026-03-27 | 33 | implementation | Has content gaps (`.snapshot` trait, `.buildWithoutRunning`); see Cluster D. |

**Verdict**: 4 of 8 stale skills need only a `last_reviewed` bump (acknowledging stability). 4 need content updates: `document-markup`, `ecosystem-data-structures`, `swift-institute`, `testing-swiftlang`. Plus `testing-institute` carries a structural defect.

### Per-cluster findings

Findings are categorized by severity. Severity definitions:

- **CRITICAL**: blocks a skill's correct application; reader following the skill produces wrong output
- **HIGH**: structural defect; broken cross-reference, ghost rule, false obligation
- **MEDIUM**: confusing or incomplete; workable but adds reader friction
- **LOW**: cosmetic, opinion-shaped, or polish

#### Cluster A — Architecture (4 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| A1 | primitives | **CRITICAL** | `requires:` lists `naming`, `errors`, `memory` — three skills that no longer exist (absorbed into `code-surface` and `memory-safety` per `swift-institute-core` lines 80–84). Dangling skill dependencies will silently fail to load. | `swift-primitives/Skills/primitives/SKILL.md:10–14` |
| A2 | swift-institute | HIGH | 91 lines, 40 days stale, weak architecture capture: five-layer diagram present but no codified rules for layer-classification, license-per-layer, or layer-boundary cases. Five referenced sub-skills depend on it. | `swift-institute/Skills/swift-institute/SKILL.md` |
| A3 | swift-institute | MEDIUM | `[SEM-DEP-006]/[008]/[009]` referenced but rule text lives in `implementation/patterns.md`. Reading order problem: a user reading swift-institute first cannot apply rules without `implementation` loaded. | `swift-institute/Skills/swift-institute/SKILL.md:69–79` |
| A4 | swift-package | LOW | `[PKG-NAME-007]`/`[PKG-NAME-008]` describe procedures without explaining underlying causes (Swift lexical-shadowing rules). Cause-explanation would strengthen rule. | `swift-package/SKILL.md:366–407` |

#### Cluster B — Code surface + ownership (4 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| B1 | memory-safety | **WITHDRAWN** | ~~`[MEM-LIFE-001]` in `advanced-ownership.md` describes "~Escapable class stored property limitation"...~~ **WITHDRAWN 2026-04-30**: placement is intentional per `[SKILL-CREATE-005b]` worked example (`skill-lifecycle/SKILL.md:225` explicitly cites `MEM-LIFE-001` as the canonical case for "Compiler-limitation rule (lifetime, but topically in advanced-ownership)" — thematic split chosen over prefix split). Cluster-B agent's finding superseded by pre-existing design decision. | `memory-safety/advanced-ownership.md:91`; `skill-lifecycle/SKILL.md:225` |
| B2 | implementation | MEDIUM | `[IMPL-030]/[IMPL-031]/[IMPL-032]` marked as subsumed by `[IMPL-EXPR-001]`/`[IMPL-033]` per `style.md`. Verify no ghost references exist in other skills before declaring subsumption complete. | `implementation/style.md` |
| B3 | conversions | LOW | 944 lines / 40 rules — at the `[SKILL-CREATE-005a]` 40-rule boundary for multi-file SPLIT. Currently coherent; thematic clusters present (typed arithmetic, raw-value access, conversion APIs, bounds checking). Monitor for further growth. | `conversions/SKILL.md` |
| B4 | code-surface | — | No defects detected. Recent `[API-IMPL-007]` amendment (2026-04-30) clean; no contradictions found. | — |

#### Cluster C — Platform + infrastructure (6 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| C1 | platform | **HIGH (split candidate)** | 1574 lines, 22 rule families. Three thematically separable domains: `[PLAT-ARCH-*]` (placement architecture, ~860 lines), `[PATTERN-*]` (C-shim + compilation mechanics, ~430 lines), Swift-6/build-infra (~280 lines). Largest single-file skill in corpus. Multi-file split per `[SKILL-CREATE-005a]` warranted. | `platform/SKILL.md` |
| C2 | ecosystem-data-structures | MEDIUM | 35 days stale; missing `Carrier` entry; should reference `Carrier<E>` as variant or sibling concept. Verify Storage variants (e.g., `.Split<Lane>`) post-April-17. | `ecosystem-data-structures/SKILL.md:237` |
| C3 | document-markup | MEDIUM | 41 days stale (oldest in cluster). Rendering-package consolidation in April may have changed import paths cited in lines 24–25. | `document-markup/SKILL.md:24–25` |
| C4 | memory-arithmetic | LOW | Frontmatter requires `primitives-conversions` — that name was absorbed into `conversions` per `swift-institute-core` line 81. Possible typo. | `memory-arithmetic/SKILL.md:1–5` |
| C5 | modularization | — | 898 lines, cohesive single-domain content; no split needed. | — |
| C6 | existing-infrastructure | — | 1173-line catalog skill; tightly organized, no cruft, current. Catalog shape is intentional — not a split candidate. | — |

#### Cluster D — Testing + benchmark (4 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| D1 | testing-institute + benchmark | **CRITICAL** | `[INST-TEST-006]` and `[INST-TEST-007]` cited by `benchmark/SKILL.md:137` as origin rules but **do not exist** in `testing-institute`. Either restore the rules or correct the cross-reference. | `benchmark/SKILL.md:137`, `testing-institute/SKILL.md` (rules end at `[INST-TEST-012]`) |
| D2 | testing-swiftlang | HIGH | Missing `.snapshot` trait pattern (Swift Testing now exposes it); missing `.buildWithoutRunning` trait. 33 days stale. Per `swift-testing-api-migration-map.md` (2026-04-22). | `testing-swiftlang/SKILL.md` |
| D3 | testing-swiftlang | MEDIUM | `[TEST-015]` cited as origin in `[SWIFT-TEST-003]` provenance but not found in `testing/SKILL.md`. Cite is `swiftlang/swift-testing#1508`; bug closed 2026-04-21 with patch landing in Swift 6.1 — provenance needs `status: fixed-in-6.1` annotation. | `testing-swiftlang/SKILL.md:167` |
| D4 | testing | LOW | Test Support sub-canon (`[TEST-010]`, `[TEST-018]`–`[TEST-026]`) is large (~9 rules, ~350 lines) but does not warrant a `testing-support` split — testing skill is architected as routing hub; standalone Test Support skill would orphan testing-swiftlang and testing-institute. | — |
| D5 | benchmark | — | Recent `[BENCH-010]` Tier-0 deferral (2026-04-30) integrates cleanly with `[BENCH-001]` placement decision tree. No defects. | — |
| D6 | **cluster** | — | **Recommendation**: `[SKILL-LIFE-031]` cluster-review candidate. Interdependencies are material (benchmark cites testing-institute); D1 + D2 + D3 are cluster-specific; no prior cluster review on this slice. | — |

#### Cluster E — Documentation + readme + github (3 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| E1 | documentation | LOW | `[DOC-023]` cross-references list `[DOC-028]/[DOC-029]` but not `[DOC-101]`. `[DOC-101]` is the rule that forbids `## Research`/`## Experiments` in per-symbol articles; should be in `[DOC-023]` cross-refs. | `documentation/catalogue.md:242` |
| E2 | documentation | LOW | Sibling-file balance: `visual.md` (86 lines, ~4 rules) is dramatically smaller than `catalogue.md` (501) and `style.md` (404). Candidate for merge with `landing.md` or elevation to short SKILL.md section. Not urgent. | `documentation/visual.md` |
| E3 | readme | — | No defects. Recent `[README-026]` and `[README-014]` extension (2026-04-30) integrated cleanly. 1013-line single-file is at threshold-acceptable; meta-rules + structural rules are inseparable, no split warranted. | — |
| E4 | github-repository | — | Recent `[GH-REPO-074]` thin-caller workflow rule (2026-04-30) sits flat in numeric namespace. Sub-prefix `[GH-REPO-WF-*]` not yet needed; defer until 2+ workflow-specific rules accumulate. | — |

#### Cluster F — Audit + research + forums + evolution (5 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| F1 | swift-forums-review | **HIGH** | `[FREVIEW-017]` codified as a mandatory rule but marked "pending data; no calibration has run." Creates false obligation — a consumer reading the rule may attempt to follow it without the data it depends on. Either move to "Future Work" section or stub as `[FREVIEW-017-PENDING]`. | `swift-forums-review/SKILL.md:424–440` |
| F2 | swift-forums-review | MEDIUM | `[FREVIEW-017]` placed at end-of-file out of numerical order (after `[FREVIEW-016]`, gap 015→017). Suggests recent edit slip. | `swift-forums-review/SKILL.md` |
| F3 | research-process | MEDIUM | ID numbering has gaps: `[RES-001]/[001a]/[004]/[004a]/[004b]/[005]–[010]/[010a]–[010c]/[020]–[026]`. Workflow separation (investigation vs discovery) explains some gaps; not all. Reader friction. | `research-process/SKILL.md` |
| F4 | research-process | LOW | `[RES-006a]` Documentation Promotion is terse — no decision criteria for promote-vs-keep-as-research. | `research-process/SKILL.md:340–344` |
| F5 | experiment-process | LOW | Stale provenance dates: `[EXP-006]/[EXP-007a]` reference 2026-04-17 Swift 6.3.1 sweep that has now passed. Rules are durable; provenance stamps are dated. | `experiment-process/SKILL.md` |
| F6 | swift-evolution | LOW | Pitch-phase-only stub by design. Post-pitch phases (formal proposal, review, decision, implementation) deferred. Honest scope statement; not a defect. | `swift-evolution/SKILL.md:27–32` |
| F7 | **cluster** | MEDIUM | Mutual cross-references incomplete: audit ↔ research-process ↔ experiment-process ↔ swift-evolution ↔ swift-forums-review form a workflow pipeline. Forward links present (audit cites release-readiness, etc.); back-links missing (research-process does not link audit; experiment-process does not link audit or forums-review). Recommendation: each skill add a "Workflow integration" or "Triggers This Skill" section. | various |

#### Cluster G — Session + handoff + skill-lifecycle (5 skills, prior cluster-audited 2026-04-15)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| G1 | handoff | **CRITICAL** | `[HANDOFF-028]` slot is **orphaned**. Sequence runs `[HANDOFF-021]–[HANDOFF-030]` with `[HANDOFF-028]` missing. Either an ID should exist or numbering needs explanation. | `handoff/SKILL.md` |
| G2 | handoff + supervise + reflect-session | **WITHDRAWN** | ~~PERSISTENT from 2026-04-15 audit B.1: heading spelling drift...~~ **WITHDRAWN 2026-04-30**: the heading-vs-prose distinction is **intentional and documented** at `handoff/SKILL.md:126–131`. The literal markdown heading IS `### Supervisor Ground Rules` (Title Case, no hyphen, matching template style); prose form IS `"supervisor ground-rules block"` (hyphenated compound modifier); `[REFL-009]` MUST match the literal heading exactly when scanning. Cluster G agent's finding superseded by skill-self-documented convention. The 2026-04-15 B.1 finding was resolved by documenting the convention rather than canonicalizing it. | `handoff/SKILL.md:126–131` (convention); `reflect-session/SKILL.md` (REFL-009 matches literal) |
| G3 | skill-lifecycle | MEDIUM | `[SKILL-LIFE-026]` and `[SKILL-LIFE-027]` exist but use 026/027 numbering — does not align with the stated convention "020–029 reserved for deprecation, 030–031 for cluster review." Numbering convention drift. | `skill-lifecycle/SKILL.md:454, 731–766` |
| G4 | reflections-processing | — | Recent (2026-04-30) carrier-exception note properly bounded. `[REFL-PROC-016]` ID-uniqueness scan (2026-04-24) sound. | — |
| G5 | reflect-session | — | 30-day age. Stable since prior cluster audit. | — |
| G6 | **cluster** | — | 2026-04-15 cluster audit findings: many resolved (E.1 success-mode verification stamp, C.4 re-handoff procedure, E.2 supervisor-role wording). G2 (B.1 heading spelling) persists. | per `agent-workflow-skill-consistency-audit.md` |

#### Cluster H — Tooling + miscellaneous process (8 skills)

| # | Skill | Severity | Finding | Citation |
|---|---|---|---|---|
| H1 | release-readiness | MEDIUM | Newly-created skill (2026-04-30) has 3 obvious gaps: `[RELEASE-007]` changelog/release-notes authoring (deferred during carrier work), `[RELEASE-008]` documentation/docstring drift handling, `[RELEASE-006a]` rollback procedures for CONDITIONAL GO acceptances. | `release-readiness/SKILL.md` |
| H2 | corpus-meta-analysis | MEDIUM | Lacks rule for **corpus-altering events like package launches**. Carrier-launch is exactly the kind of event `[META-*]` should track. Missing `[META-027]` for Discovery Completion Post-Launch. | `corpus-meta-analysis/SKILL.md` |
| H3 | blog-process | LOW | Lacks explicit rule for **precursor-post → launch-post sequencing**. Carrier arc tested `[BLOG-021]` (paired-post URL) and `[BLOG-022]` (DocC verify) — both added after gap discovery. `[BLOG-023]` for closing-bridge discipline would prevent re-derivation. | `blog-process/SKILL.md` |
| H4 | quick-commit-and-push-all | LOW | `[SAVE-002]` script has hardcoded ecosystem-directory list (lines 107–124). Refactor into `[SAVE-002a]` (per-repo logic) + `[SAVE-002b]` (ecosystem-catalog iteration) would enable other ecosystem-wide scripts. **Not absorption candidate** — independent consumers (user invokes directly). | `quick-commit-and-push-all/SKILL.md:85–180` |
| H5 | collaborative-discussion | — | 41 days stale but VERIFIED ACTIVE (carrier blog drafting validated `[COLLAB-013]` round-2-pushback). Bump only. | — |
| H6 | swift-pull-request | — | 36 days stale but stable; `[SWIFT-PR-011]` recent valuable addition. Bump only. | — |
| H7 | package-export | — | 40 days stale but single-purpose and stable. Bump only. | — |
| H8 | issue-investigation | — | Current; `[ISSUE-022]`, `[ISSUE-025]` recent additions reflect April-2026 lessons. | — |

### Cross-cluster patterns

Three patterns recur across multiple clusters:

#### Pattern 1: Ghost references

Five distinct ghost-reference defects across the corpus:

1. **A1** — `primitives` requires `naming`, `errors`, `memory` (absorbed/non-existent skills)
2. **B1** — `[MEM-LIFE-001]` in wrong file (`advanced-ownership.md`, semantically belongs in `safety-isolation.md` as `[MEM-ESCAPE-001]`)
3. **D1** — `[INST-TEST-006]` and `[INST-TEST-007]` cited by `benchmark` but undefined in `testing-institute`
4. **D3** — `[TEST-015]` cited but not found
5. **G1** — `[HANDOFF-028]` numerical slot orphaned

**Prior coverage**: `[AUDIT-028]` (notation-variant ghost-reference detection, 2026-04-24) covers em-dash ranges, level-2 vs level-3 headings, and sub-label citations. The five defects above slip through because they're either (a) frontmatter `requires:` (not in scan scope) or (b) cite IDs that simply don't exist (different from notation variance).

**Recommendation**: extend `[AUDIT-028]` (or add a sibling rule) to cover frontmatter dependency validation and ID-existence scan, not just notation variants. Alternatively, ship a CI script `Scripts/check-skill-references.sh` that runs the ID-existence scan as a hook.

#### Pattern 2: Stale skills with mixed verdicts

Of 8 skills past 30-day review, 4 need only a `last_reviewed` bump (stable content): `collaborative-discussion`, `package-export`, `swift-pull-request`, `quick-commit-and-push-all`. The other 4 carry actual content gaps: `swift-institute` (architecture capture), `document-markup` (rendering-package consolidation), `ecosystem-data-structures` (Carrier catalog), `testing-swiftlang` (snapshot trait).

**Pattern signal**: the `last_reviewed` field conflates two distinct concepts — "content verified current" vs "content updated for new ecosystem state." Per `[SKILL-LIFE-005]` (mechanical drift check, 2026-04-24), automation now flags drift; but the trigger doesn't distinguish stable-from-stable from stale-needs-content.

**Recommendation**: low-priority. The current discipline (manual triage on drift signal) is workable; adding a second metadata field (`content_verified_against:` ecosystem version?) would be over-engineering.

#### Pattern 3: Workflow-pipeline cross-reference asymmetry

Five process skills (audit, research-process, experiment-process, swift-forums-review, swift-evolution) form a workflow pipeline: audit findings → research investigations → experiment validations → swift-evolution pitches; release-readiness Phase 4 invokes swift-forums-review. Forward links are present (audit cites release-readiness; release-readiness cites audit/forums-review). **Back-links are missing** (research-process does not cite audit; experiment-process does not cite audit or forums-review; swift-evolution does not cite forums-review).

**Recommendation**: each skill in the pipeline adds a "Workflow integration" or "Triggers This Skill" sub-section listing which prior-workflow outcomes call it. Not a normative rule change — a discoverability improvement. Defer to Tier 3.

### Split candidates

**Strong (recommend split)**:

- **platform** (1574 lines, 22 rule families) — split into `platform-architecture` (PLAT-ARCH placement rules, ~920 lines) and `platform-compilation` (PATTERN compilation mechanics + Swift-6 + build infra, ~470 lines). Each new skill stands alone; cross-references exist for a `platform` umbrella to retain.

**Borderline (monitor; do not split yet)**:

- **conversions** (944 lines, 40 rules) — at `[SKILL-CREATE-005a]` boundary. Currently coherent; `[CONV-016]` master preference hierarchy ties rules together. Monitor; if >1000 lines, extract `[IDX-*]` rules to sibling.
- **testing** (914 lines) — large, but Test Support sub-canon (~9 rules) doesn't justify standalone `testing-support` skill that would orphan testing-swiftlang/testing-institute/benchmark. Status quo defensible.
- **swift-institute** (91 lines) — has the OPPOSITE problem: too small + content gaps. Expand, don't split.

### Missing skills

Four candidates:

1. **`changelog` / `release-notes`** — deferred during carrier work. Should govern GitHub Releases content (distinct from CHANGELOG.md). `[README-016]` forbids changelogs in READMEs and directs them to "CHANGELOG.md or GitHub Releases" but no skill governs those artifacts.

2. **`github-org`** — explicitly named as future work in `github-repository` skill (line ~80 `[GH-REPO-080]`). Would govern org-level community-health files (FUNDING.yml, CODE_OF_CONDUCT.md, profile/README.md) currently handled by `Scripts/sync-community-health.sh` without skill backing.

3. **`platform-compilation`** (split from `platform`) — see Split Candidates above.

4. **`platform-architecture`** (split from `platform`) — see Split Candidates above.

A fifth candidate was discussed and rejected:

- **`testing-support`** — Test Support sub-canon could spin out, but doing so would orphan testing-swiftlang/testing-institute/benchmark from the umbrella router. Status quo is architecturally sound.

### Persistent findings from 2026-04-15 audit

Per `[RES-013a]` Synthesis Verification, every prior finding was checked:

| Finding | Status | Notes |
|---|---|---|
| B.1 — Heading spelling: `Supervisor Ground Rules` vs `supervisor ground-rules block` | **RESOLVED-BY-DESIGN** (verified 2026-04-30) | Convention now explicitly documented at `handoff/SKILL.md:126–131` — heading-vs-prose distinction is intentional. `[REFL-009]` matches literal heading; consistent with documented convention. |
| B.5 — Supervisor in absentia concept coined in handoff | **PARTIALLY ADDRESSED** | `[SUPER-014a]` added; `[HANDOFF-012]` role-wording also fixed |
| C.1 — Escalation lacks persistence requirement | **MIXED** | `[SUPER-012]` Persistence Requirement table added; `[SUPER-016]` Step 4 still doesn't list escalation in termination bullet |
| C.4 — `[SUPER-016]` Step 4 skips `/handoff` invocation | **FIXED** | Step 4 now correctly invokes `/handoff` per `[SUPER-010]` |
| D.1 — `[SKILL-CREATE-003]` Prefix list stale | **MITIGATED** | Now redirects to swift-institute-core Skill Index |
| E.1 — Success-termination subordinate verification line | **FIXED** | `[HANDOFF-010]` step 5 explicit on all three termination paths |
| E.2 — `[HANDOFF-012]` "plays the supervisor role" claim | **FIXED** | Now reads "plays the ground-rules role" |

**Verdict (revised 2026-04-30)**: 4 fixed, 1 resolved-by-design, 1 mitigated, 1 partial. **The cluster is in better shape than the 2026-04-30 cluster-G agent's report indicated.** Two of the agent's findings (T1.4 [MEM-LIFE-001] and G2 / B.1 heading spelling) were superseded by intentional designs documented in the skills themselves; the agent's grep didn't reach the convention documentation. Methodological lesson: holistic-review agents should explicitly grep for "convention", "Heading-vs-prose", "intentional placement" near suspected defects before classifying.

## Outcome

**Status**: RECOMMENDATION

The corpus is in **good health** overall: 37 skills, zero duplicate IDs, no skills past `[SKILL-LIFE-012]` cadence, recent active maintenance. Specific defects below are tractable; collectively they amount to ~25 actionable items across three priority tiers.

### Tier 1 — Critical (do now; broken cross-references / dangling deps)

| # | Action | Status | Effort | Skill |
|---|---|---|---|---|
| T1.1 | Fix `primitives/SKILL.md` `requires:` — replace `naming, errors, memory` with `code-surface, memory-safety` | **LANDED 2026-04-30** | 5 min | primitives |
| T1.2 | Resolve `[INST-TEST-006]/[007]` ghost rules — `benchmark/SKILL.md:137` Origin line removed (the cited TEST-015, INST-TEST-006, INST-TEST-007 were all ghost references; rule [BENCH-003] is complete without them) | **LANDED 2026-04-30** | 5 min | benchmark |
| T1.3 | Fix `[HANDOFF-028]` orphan — added an explicit "Reserved" rule at the slot, citing the holistic review as provenance and instructing future rules to use `[HANDOFF-031]+` | **LANDED 2026-04-30** | 10 min | handoff |
| T1.4 | ~~Resolve `[MEM-LIFE-001]` ID/file mismatch~~ | **WITHDRAWN** — placement intentional per `[SKILL-CREATE-005b]` worked example | 0 | memory-safety |
| T1.5 | Fix `[FREVIEW-017]` false obligation — added a top-of-rule "STATUS — PENDING DATA" banner; renamed heading to make pending status unambiguous; rule body retained for forward-looking discoverability | **LANDED 2026-04-30** | 5 min | swift-forums-review |

**T1 total**: 4 actionable defects landed (~25 min wall time). T1.4 was withdrawn after verification against `[SKILL-CREATE-005b]` confirmed the placement is intentional design, not a defect.

**Methodological lesson**: the agent finding for T1.4 illustrates [RES-013a] (Synthesis Verification): cluster agents working on a single cluster cannot always see when their finding is superseded by a rule in a *different* cluster's skill (in this case, `skill-lifecycle/SKILL.md:225`). The parent's grep before remediation caught this. Future holistic reviews SHOULD include a cross-cluster verification pass before classifying agent findings as defects.

### Tier 2 — Substantive (this cycle; structural defects + obvious gaps)

| # | Action | Effort | Skill |
|---|---|---|---|
| T2.1 | **Split `platform` skill** into `platform-architecture` (PLAT-ARCH-*) + `platform-compilation` (PATTERN + Swift-6 + build infra) per `[SKILL-CREATE-005a]` | 4–6 hours | platform → 2 new skills |
| ~~T2.2~~ | ~~Persistent G2 defect (heading spelling)~~ — **WITHDRAWN 2026-04-30**: convention is intentional and documented at `handoff/SKILL.md:126–131`. See cluster-G findings table for details. | 0 | — |
| T2.3 | `swift-institute` skill (architecture, 91 lines): expand with codified layer-classification rules, license-per-layer rules, layer-boundary cases | 2 hours | swift-institute |
| T2.4 | `testing-swiftlang`: add missing `.snapshot` trait pattern, `.buildWithoutRunning` trait; update `#1508` provenance | 1 hour | testing-swiftlang |
| T2.5 | `release-readiness` gaps: add `[RELEASE-007]` changelog/release-notes, `[RELEASE-008]` doc-drift handling, `[RELEASE-006a]` rollback procedures | 2 hours | release-readiness |
| T2.6 | `corpus-meta-analysis`: add `[META-027]` Discovery Completion Post-Launch | 30 min | corpus-meta-analysis |
| T2.7 | Run `[SKILL-LIFE-031]` cluster audit on testing/testing-swiftlang/testing-institute/benchmark | 2–3 hours | testing cluster |
| T2.8 | `document-markup`: refresh against April rendering-package consolidation; verify import paths | 1 hour | document-markup |
| T2.9 | `ecosystem-data-structures`: add Carrier entry; verify Storage variants; bump | 30 min | ecosystem-data-structures |
| T2.10 | Add new `changelog` / `release-notes` skill — TBD scope (governs GitHub Releases content) | 3–4 hours | new skill |

**T2 total** (revised 2026-04-30 after G2 withdrawal): 9 actionable items, ~16–21 hours of focused work. Items can be parallelized; T2.1 (platform split) is the largest singleton.

### Tier 3 — Polish (when convenient)

| # | Action | Effort | Skill |
|---|---|---|---|
| T3.1 | `swift-package` `[PKG-NAME-007]/[008]`: add cause-explanations alongside procedures | 30 min | swift-package |
| T3.2 | `documentation`: add `[DOC-101]` to `[DOC-023]` cross-references | 5 min | documentation |
| T3.3 | `documentation`: visual.md (86L runt) — merge with landing.md OR elevate to SKILL.md section | 1 hour | documentation |
| T3.4 | `research-process`: ID-numbering gap explanation OR renumber for continuity | 30 min | research-process |
| T3.5 | `research-process` `[RES-006a]`: define promote-vs-keep-as-research decision criteria | 20 min | research-process |
| T3.6 | `experiment-process`: refresh `[EXP-006]/[007a]` provenance dates | 15 min | experiment-process |
| T3.7 | `quick-commit-and-push-all`: refactor `[SAVE-002]` into `[SAVE-002a]` (per-repo) + `[SAVE-002b]` (ecosystem iteration) | 1 hour | quick-commit-and-push-all |
| T3.8 | `blog-process` `[BLOG-023]`: precursor-post → launch-post closing-bridge rule | 30 min | blog-process |
| T3.9 | Workflow-pipeline back-links: each of audit/research-process/experiment-process/swift-forums-review/swift-evolution add "Workflow integration" or "Triggers This Skill" section | 2 hours | 5 skills |
| T3.10 | Consolidate stale-but-stable `last_reviewed` bumps: collaborative-discussion, package-export, swift-pull-request, quick-commit-and-push-all | 10 min | 4 skills |
| T3.11 | `skill-lifecycle` numbering-convention drift: `[SKILL-LIFE-026]/[027]` don't align with stated 030–031 cluster-review range. Document the convention OR renumber. | 30 min | skill-lifecycle |
| T3.12 | New `github-org` skill (deferred from `github-repository`) | 3–4 hours | new skill |
| T3.13 | `memory-arithmetic`: verify `requires: primitives-conversions` typo (should be `conversions`) | 5 min | memory-arithmetic |
| T3.14 | Extend `[AUDIT-028]` (or sibling rule) to cover frontmatter `requires:` validation and ID-existence checks across the corpus | 1 hour | audit |

**T3 total**: ~12 hours.

### Aggregate

- **Tier 1**: ~1.5 hours, 5 defects fixed
- **Tier 2**: ~17–22 hours, structural gaps closed
- **Tier 3**: ~12 hours, polish + missing skills

**Grand total**: ~30–36 hours of skill maintenance work indicated. Tier 1 is closure-shaped (defects). Tier 2 is improvement-shaped (gaps). Tier 3 is polish.

The principal can:

(a) Execute Tier 1 immediately (low effort, high payoff; all defects).
(b) Schedule Tier 2 across multiple sessions; coordinate `platform` split with downstream consumers.
(c) Defer Tier 3 to opportunistic moments or schedule via `/loop` agents.

Or selectively pick items by package context — e.g., when next touching a specific skill, sweep its outstanding T2/T3 items.

### Methodological note on this review

This review used **8 parallel Explore subagents** to scan 37 skills in one shot. Effort: ~5 minutes parent dispatch + 4–6 minutes per agent in parallel = ~10 minutes wall clock for the read-and-categorize phase. Synthesis (this document) added ~30 minutes. Total: ~40 minutes for a corpus-wide review.

For comparison, sequential single-agent review of 37 skills × 700 lines avg would have consumed substantial parent-context tokens and likely required ~2–3 hours wall clock. The parallel subagent pattern is the right shape for corpus-wide reviews; codifying it as a research-process or audit-skill methodology rule is a Tier 3 candidate (`[RES-024]` parallel-subagent verification already covers the verification side; the open-ended-survey side could use a sibling rule).

## References

- `swift-institute/Research/agent-workflow-skill-consistency-audit.md` (2026-04-15) — prior cluster audit; persistent findings tracked
- `swift-institute/Research/skill-shape-and-growth-evaluation.md` — rationale for `[SKILL-CREATE-005a]` multi-file exception
- `swift-institute/Research/skill-loading-reliability.md` — symlink + sync rationale
- `swift-institute/Research/skill-creation-process.md`, `skill-based-documentation-architecture.md`, `skill-as-input-composition-pattern.md`, `compose-then-trace-skill-design-phase.md` — skill design rationale
- `swift-institute/Research/documentation-skill-design.md`, `readme-skill-design.md`, `generalized-audit-skill-design.md`, `audit-finding-triage-taxonomy.md`, `implementation-patterns-skill.md` — per-skill design records
- `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md` — case study driving recent skill amendments
- Skill files cited inline by absolute path with line numbers
