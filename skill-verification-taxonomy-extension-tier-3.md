# Skill-Verification Taxonomy Extension — Tier 3 (Voice/Process Skills, FINAL)

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [institute, primitives, standards, foundations, rule-law]
normative: false
---
-->

## Context

### Trigger

Final dispatch in the tiered classification sweep that began with the pilot (3 skills, 57 IDs) and continued through tier-1 (13 infra/process skills, 236 IDs) and tier-2 (7 code-shape skills, 208 IDs). This dispatch closes the corpus by walking **24 voice/process skills** spread across `swift-institute/Skills/` (20) and `rule-law/Skills/` (4). After tier-3 closes, the ecosystem-wide inventory is complete and workflow-construction phase begins (separate dispatch).

The handoff brief (`/Users/coen/Developer/HANDOFF-classification-extension-tier-3.md`) names the deliverable: per-skill classification table per pilot+tier-1+tier-2 format, aggregate distribution across 24 skills, six-pattern resistant-set diagnostic, and **a closing final-inventory section computing ecosystem-wide totals + mechanical-rule construction queue ranked by skill** — closing the goal-thread that began with the pilot.

### Prior research (carry-forward; cite-and-extend per [HANDOFF-013])

- **`swift-institute/Research/skill-verification-taxonomy-pilot.md` v1.0.0** (RECOMMENDATION, 2026-05-05) — the format instrument. Part 1 reconciliation (three-class vs four-class) carries forward unchanged. Part 5 established the three pilot resistant patterns (composite multi-mechanism, workflow-vs-outcome, external-knowledge fetch).
- **`swift-institute/Research/skill-verification-taxonomy-extension-tier-1.md` v1.0.0** — extends across 13 infra/process skills. Part 16 surfaced **three new resistant patterns**: decision-tree wrappers (`**Routing:**`), API-gap rules (`**API-Gap:**`), reference-table-as-rule (`**Reference:**`). Six-annotation set established.
- **`swift-institute/Research/skill-verification-taxonomy-extension-tier-2.md` v1.0.0** — extends across 7 code-shape skills. §10 surfaced two refinements: (a) **Reference sub-split** between pure-illustration (drop-candidate) and definitional-anchor (retention-with-annotation); (b) **Routing generalization to semantic-classed rules** (the original tier-1 framing limited Routing to mechanical predicates; tier-2 demonstrated semantic-leaf decision trees fit the same annotation). Tier-3 inherits both refinements as continuity context.
- **`swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0** — canonical four-class scheme + γ-roadmap. §3.4.1 phased roadmap (lines 649–662). §3.4.10 graduation models (lines 896–909). Inline `→ γ-Nx` annotations cite this document. Tier-2 saturation was 1.9%; tier-3 expected near-zero per brief.
- **`/Users/coen/Developer/HANDOFF-classification-extension-tier-3.md`** — branching investigation handoff that dispatched this work; supervisor ground-rules block honored; verification stamp at §Outcome.

### Empirical state (verified 2026-05-05)

The 24 tier-3 skill files were each read end-to-end by 5 parallel `general-purpose` subagents (clusters A–E, 3–7 skills each) using `grep -nE '^### \['` to enumerate requirement IDs (table-format enumeration for `memory-safety`-style hub skills and `swift-evolution`'s `## [PITCH-PROC-NNN]` heading shape; `[FREVIEW-*]` enumerated via direct ID-pattern grep on `swift-forums-review`). Verified counts:

| Skill | SKILL.md path | lines | last_reviewed | Requirement IDs walked |
|---|---|---|---|---|
| collaborative-discussion | `swift-institute/Skills/collaborative-discussion/SKILL.md` | 512 | 2026-03-20 | 13 |
| corpus-meta-analysis | `swift-institute/Skills/corpus-meta-analysis/SKILL.md` | 816 | 2026-04-24 | 27 |
| document-markup | `swift-institute/Skills/document-markup/SKILL.md` | 723 | 2026-03-20 | 17 |
| experiment-process | `swift-institute/Skills/experiment-process/SKILL.md` | 807 | 2026-04-30 | 40 |
| handoff | `swift-institute/Skills/handoff/SKILL.md` | 1294 | 2026-04-30 | 43 |
| implementation | `swift-institute/Skills/implementation/SKILL.md` | 297 | 2026-04-30 | 4 |
| issue-investigation | `swift-institute/Skills/issue-investigation/SKILL.md` | 754 | 2026-04-15 | 25 |
| quick-commit-and-push-all | `swift-institute/Skills/quick-commit-and-push-all/SKILL.md` | 196 | 2026-04-14 | 3 |
| readme | `swift-institute/Skills/readme/SKILL.md` (+6 sibling files) | 449 | 2026-05-01 | 83 |
| reflect-session | `swift-institute/Skills/reflect-session/SKILL.md` | 470 | 2026-04-30 | 14 |
| reflections-processing | `swift-institute/Skills/reflections-processing/SKILL.md` | 561 | 2026-04-30 | 18 |
| research-process | `swift-institute/Skills/research-process/SKILL.md` | 839 | 2026-04-30 | 45 |
| skill-lifecycle | `swift-institute/Skills/skill-lifecycle/SKILL.md` | 774 | 2026-04-24 | 30 |
| supervise | `swift-institute/Skills/supervise/SKILL.md` | 924 | 2026-04-30 | 35 |
| swift-evolution | `swift-institute/Skills/swift-evolution/SKILL.md` | 429 | 2026-04-14 | 7 |
| swift-forums-review | `swift-institute/Skills/swift-forums-review/SKILL.md` | 507 | 2026-04-30 | 20 |
| swift-pull-request | `swift-institute/Skills/swift-pull-request/SKILL.md` | 407 | 2026-03-24 | 11 |
| testing | `swift-institute/Skills/testing/SKILL.md` | 914 | 2026-04-24 | 18 |
| testing-institute | `swift-institute/Skills/testing-institute/SKILL.md` | 290 | 2026-03-27 | 9 |
| testing-swiftlang | `swift-institute/Skills/testing-swiftlang/SKILL.md` | 685 | 2026-04-30 | 16 |
| dutch-law | `rule-law/Skills/dutch-law/SKILL.md` | 521 | 2026-03-20 | 17 |
| legal-encoding | `rule-law/Skills/legal-encoding/SKILL.md` | 786 | 2026-03-20 | 31 |
| legal-testing | `rule-law/Skills/legal-testing/SKILL.md` | 352 | 2026-03-20 | 11 |
| rule-law-core | `rule-law/Skills/rule-law-core/SKILL.md` | 201 | 2026-03-20 | 7 |
| **Tier-3 total** | | **14508** | | **544** |

Two skill-shape edge cases worth flagging:
- **`readme`** is a **navigation hub** with 6 sibling files (`ci-automation.md`, `org-profile.md`, `placeholder.md`, `process.md`, `sub-package.md`, `user-profile.md`). Rule bodies live in the siblings; the hub carries a Rule Index and the universal axioms. Page-cites use `readme/{sibling}.md:NNN` for sibling-located rules.
- **`implementation`** is also a navigation hub (~70+ rule IDs across `ownership.md`, `concurrency.md`, `accessors.md`, `errors.md`, `style.md`, `infrastructure.md`, `patterns.md`). Per the brief's scope-limiting clause for navigation hubs, only the 4 hub axioms declared with `### [` headings ([IMPL-INTENT], [IMPL-000], [IMPL-001], [IMPL-COMPILE]) are classified here; corollary rules in sibling files would be a separate dispatch and live outside tier-3 scope.

A third skill-shape edge case:
- **`skill-lifecycle`** — mechanical scan returns 32 `### [` heading hits, but two of them (lines 145 and 167) are **template-literal placeholders** embedded inside `[SKILL-CREATE-005]`'s example block (`### [{ID-PREFIX}-001]`), not real classifiable rules. Only the 30 real rules are walked.

#### Pre-flight escalation finding

Per the supervisor block's pre-flight requirement, `/Users/coen/Developer/.claude/skills/` was enumerated before classification began. **52 symlinks total**. Reconciliation against pilot (3) + tier-1 (13) + tier-2 (7) + tier-3 named (24) = **47 in-scope skills**. **9 additional skills accessible via the symlink directory but not in any tier**:

- `engagement-actionables`, `engagement-compose`, `engagement-process`, `engagement-review`, `engagement-themes`, `engagement-triage` (6 engagement skills)
- `ingest-swift-forums`, `ingest-x`, `ingest-x-feeds` (3 ingest skills)

These 9 live in `swift-institute/Engagement/Skills/` — a **private sibling repo** per `feedback_skills_follow_institute_convention.md` ("business-sensitive concern skills live in their own private sibling repo"). The brief's explicit scope is `swift-institute/Skills (20) + rule-law/Skills (4)`; Engagement is a separate path.

**Pre-flight verdict**: the 24-skill list is complete *relative to the brief's defined scope*; 9 additional skills exist in a path the brief did not cover. Per supervisor block ask: clause, surfaced as a finding. Per supervisor block MUST clause "stop after the 24 tier-3 skills; do not classify additional skills even if budget remains," **proceeding with the 24 named skills only**; the 9 engagement+ingest skills are flagged in §28's final-inventory as an out-of-scope calibration finding for a possible future dispatch.

544 walked requirements is ≈2.6× tier-2's 208 and ≈14.7× the pilot's 57. Mean 22.7 requirements per tier-3 skill versus 18.2 (tier-1) and 29.7 (tier-2). With cluster outliers (`readme` 83, `research-process` 45, `handoff` 43) driving up the count and `quick-commit-and-push-all` (3) / `implementation` (4) / `rule-law-core` (7) at the floor.

---

## Question

The pilot's three coupled questions restated at tier-3 scale:

1. **Coverage**: When applied across 24 voice/process skills (544 requirements), does the three-class taxonomy classify cleanly, or does it surface a resistant set materially larger or differently shaped than tier-1's 19.9% / tier-2's 30.3% (raw, dominated by Reference-shape sub-pattern)?
2. **γ-roadmap saturation**: How densely do tier-3 mechanical rules map to already-designed γ-roadmap CI checks? (Brief predicted near-zero — voice/process skills are even further from v1.2.0's CI-spine-gate scope than tier-2's code-shape skills were.)
3. **Ecosystem-wide closure**: Does the tier-3 distribution + ecosystem-wide totals support the pilot+tier-1+tier-2 recommendation to adopt the taxonomy with three remediation clarifications + three new annotations, or does it stress-test the recommendation's robustness?

---

## Analysis

### Part 1 — Carry-forward: pilot + tier-1 + tier-2 reconciliation

The pilot's Part 1 §1.3 verdict (three-class **reduces** four-class on hybrid axis; **extends** four-class across all skill requirements; **complementary levels**; **no irreconcilable conflict**) governs unchanged. Tier-3 classification produced no rule whose verification mechanism would refute this reconciliation. Tier-1's three new resistant patterns + tier-2's two refinements (Reference sub-split; Routing generalization) carry forward as the working framework.

The supervisor block's first ask: clause (cleanly-resistant rule indicating a seventh pattern → escalate before introducing) is **not triggered** at tier-3. Six-pattern soft ceiling holds across pilot + tier-1 + tier-2 + tier-3.

---
### Part 2 — readme (`Skills/readme/SKILL.md`)

Verified against `SKILL.md` (449 lines, last_reviewed 2026-05-01) plus six sibling files (`user-profile.md`, `process.md`, `sub-package.md`, `placeholder.md`, `org-profile.md`, `ci-automation.md`). All 83 unique requirement IDs walked.

#### 2.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[README-023]` | Evaluator's Lens | **semantic** | AI input: full README text + family designation; per-paragraph judgment whether content serves the family's evaluation question or is author-oriented (rule-of-thumb decision test exists but the operative judgment is intent/audience). | readme/SKILL.md:219 |
| `[README-026]` | No Internal Rule-ID Citations | **mechanical** | Predicate: regex `\[[A-Z]+(-[A-Z]+)*-\d+[a-z]?\]` over README prose (excluding code fences). Decision test confirms binary outcome; zero internal IDs permitted in any family. | readme/SKILL.md:253 |
| `[README-001]` | Required Inventory and Recommended Sequence | **hybrid** | Prefilter: parse H1, badges, one-liner sentence, License heading existence and ordering (regex/markdown AST). AI input: judge whether one-liner satisfies "single sentence describing what the package does" and whether Quick-Start-first ordering is appropriate for the package's name. | readme/sub-package.md:233 |
| `[README-002]` | Maturity Tiers | **hybrid** | Prefilter: detect required sections per tier via heading regex (`## Installation`, `## License`, etc.). AI input: classify the package's actual maturity (active development vs v1.0+ vs has-external-users) to pick the applicable tier. | readme/sub-package.md:307 |
| `[README-003]` | Development Status Badge | **mechanical** | Predicate: regex match for `https://img.shields.io/badge/status-(active--development\|stable\|maintenance\|experimental)-(blue\|green\|yellow\|red)\.svg` immediately after H1. Bounded vocabulary, fixed URL shape. → γ-2 | readme/sub-package.md:405 |
| `[README-004]` | CI Badge | **mechanical** | Predicate: regex for badge URL `https://github.com/{ORG}/{REPO}/workflows/CI/badge.svg`; **Composite:** also requires verifying CI status is currently passing via `gh api repos/<owner>/<repo>/actions/runs?per_page=1` (External: GitHub Actions API). → γ-2 | readme/sub-package.md:432 |
| `[README-005]` | Swift Package Index Badges | **mechanical** | Predicate: regex match for `img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F<owner>%2F<repo>%2Fbadge%3Ftype%3D(swift-versions\|platforms)`; verify badge ordering follows the [README-005] table (status → SPI versions → SPI platforms → CI). → γ-2 | readme/sub-package.md:446 |
| `[README-006]` | One-Liner and Opening Contract | **hybrid** | Prefilter: extract one-liner (first sentence after H1+badges); regex-block forbidden prefixes ("A Swift package for", marketing without numbers). AI input: judge "describes what, not how" + the four opening-contract falsification conditions (does the first paragraph describe the package vs ecosystem-positioning vs author history). | readme/sub-package.md:468 |
| `[README-007]` | Key Features Format | **hybrid** | Prefilter: detect `## Key Features` section, count bullets, regex for bold-keyword + em-dash pattern. AI input: classify which of the three permitted forms (bullets / feature-as-subsection / prose) the section is using and whether that form fits the package's feature inventory. | readme/sub-package.md:524 |
| `[README-008]` | Installation Format | **mechanical** | Predicate: regex for both Package.swift dependency block AND target dependency block within `## Installation`; verify URL is per-package GH repo URL (`https://github.com/<owner>/<package>.git`), not a parent. **Composite:** combines snippet-presence with URL-shape lint. → γ-2 | readme/sub-package.md:585 |
| `[README-009]` | Quick Start Requirements | **hybrid** | Prefilter: count lines in Quick Start code block (must be 10–20); verify imports present; check for placeholder identifiers. AI input: judge "shows the primary use case" + whether the example is copy-paste runnable in context. Cross-feeds [README-024]. | readme/sub-package.md:618 |
| `[README-010]` | Architecture Section | **hybrid** | Prefilter: detect intra-package target-graph diagram or key-types table; regex-block "Layer N:" framings (sub-package READMEs forbidden from Institute-level layering). AI input: judge "earning sub-rule" — every row/box/element answers a consumer dependency/import/capability question. | readme/sub-package.md:652 |
| `[README-011]` | Platform Support Table | **hybrid** | Prefilter: detect SPI platforms badge presence (regex per [README-005]); detect Platform Support table presence; check status vocabulary against the bounded list (Full support / Supported / Planned / Possible / Not supported). AI input: judge whether platform subtleties exist that warrant the table even when SPI badge is present. | readme/sub-package.md:717 |
| `[README-012]` | Performance Documentation | **hybrid** | Prefilter: when Performance section exists, regex for hardware/OS/Swift-version/methodology mentions; verify benchmark data is tabular. AI input: judge whether the metrics are meaningful (throughput/latency/memory) vs marketing prose. | readme/sub-package.md:749 |
| `[README-013]` | Error Handling Section | **hybrid** | Prefilter: count distinct `catch` arms in exhaustive consumer pattern (≥3 = non-trivial); detect ASCII tree presence; regex for typed-throws shape. AI input: judge non-trivial-error-shape disposition (multiple throwing surface areas, nested generic envelope). | readme/sub-package.md:782 |
| `[README-014]` | Related Packages Organization | **mechanical** | Predicate: detect `## Related Packages`; verify subsection headings (Dependencies / Used By / Third-Party); for each link, verify target repo is public and has ≥1 tag via `gh api repos/<owner>/<repo>` and `gh api repos/<owner>/<repo>/tags`. **External:** GitHub API. → γ-2 | readme/sub-package.md:834 |
| `[README-015]` | Optional Sections | **semantic** | AI input: judge whether each optional section earns its place per the named-section rubric (Motivation answers "why exists?", Design Philosophy answers "how does this reason?", Alternatives answers "what competitors?"). Decision test names three reader questions but the routing is editorial. **Routing:** | readme/sub-package.md:343 |
| `[README-016]` | Prohibited Content | **hybrid** | Prefilter: regex for explicit prohibitions (Roadmaps/TODOs as headings, screenshot embeds via `![...]`, "Layer N: ... ← this package" framings, `git tag` / `branch: "main"` Package.swift snippets in installation prose). AI input: judge soft prohibitions (implementation autobiography, design reflections, ecosystem-convention framing in feature bullets). | readme/sub-package.md:376 |
| `[README-017]` | Formatting Rules | **mechanical** | Predicate: AST/regex over Markdown — exactly one H1, no H4+ headings, every fenced code block has language tag, tables column-aligned (regex on cell padding), `---` separators between major sections. → γ-2 | readme/sub-package.md:874 |
| `[README-018]` | (DEPRECATED) | **semantic** | AI input: rule body explicitly DEPRECATED in v3.0.0; retained for changelog stability. No verification predicate; rule's role is now historical-anchor (content roles redistributed to [README-111], [README-113], [README-008]). **Reference (anchor):** | readme/sub-package.md:1001 |
| `[README-019]` | Sub-Package README is Self-Contained | **mechanical** | Predicate: parse Installation block URL — must match `https://github.com/<owner>/<package>.git` (per-package repo), not a parent or nested-package reference. Same regex as [README-008] enforcement. → γ-2 | readme/sub-package.md:957 |
| `[README-020]` | Org Profile README Structural Baseline | **hybrid** | Prefilter: verify presence of the six listed elements (H1 proper-name title-cased, one-liner, Overview/pitch, tier-specific content, status/state disclosure when pre-public, License section); regex-block installation/code/badges. AI input: classify org tier and judge tier-specific content satisfaction. | readme/org-profile.md:77 |
| `[README-021]` | Maintenance Obligations | **hybrid** | Prefilter: extract performance numbers and installation version; **Composite:** also lint links validity (`lychee` or `gh` API), badge status reflects actual package state. AI input: judge "kept current with each major release" — currency is editorial discipline, not a regex. | readme/sub-package.md:983 |
| `[README-022]` | Code Examples in README | **hybrid** | Prefilter: for each code block, detect import statements; regex for placeholder identifiers (`Foo`, `Bar`, lone `x`/`y` as variable names). AI input: judge "domain-meaningful identifiers" + "satisfy [README-024]" (motivated examples) + judgment on baseline-contrast technique application. | readme/sub-package.md:892 |
| `[README-024]` | Motivated Examples (Earn Complexity) | **semantic** | AI input: for each example, write the shortest non-library-using equivalent and compare. Judgment is whether the package genuinely enables something impossible/awkward/subtly-wrong without it. Cannot be regex-decided. | readme/sub-package.md:70 |
| `[README-025]` | Scope Boundary (Package vs Ecosystem) | **hybrid** | Prefilter: regex for "Layer N:" framings, "five-layer" mentions, ecosystem-hierarchy diagrams in sub-package READMEs (Family E). AI input: judge whether content describes intra-package or ecosystem-position. Decision test cleanly separates the two. | readme/sub-package.md:114 |
| `[README-027]` | Stability Section Operational Form | **hybrid** | Prefilter: when `## Stability` exists in pre-1.0 package, detect operational table form; regex-block phrases ("internal storage shapes", "SE-XYZ migration", "deprecation choreography", "accepted-as-known constraints"). AI input: judge whether prose answers consumer's "what may I rely on?" vs internal "why is the package shaped this way?" question. | readme/sub-package.md:168 |
| `[README-100]` | Ecosystem Brain Pitch | **semantic** | AI input: judge whether the 1–2 paragraph pitch identifies the unifying coordination principle and avoids promising specific deliverables. Decision test asks reader-judgment ("can a visitor explain in one sentence why this ecosystem exists?"). | readme/org-profile.md:209 |
| `[README-101]` | Process-Repo Inventory | **hybrid** | Prefilter: detect intent-driven navigation table (two-column "If you want to... / Go to" pattern); verify each row links to a swift-institute process repo. AI input: judge whether each row pairs a real visitor intent with the right destination. | readme/org-profile.md:239 |
| `[README-102]` | Outward Links to Domain Umbrellas (Org-of-Orgs) | **hybrid** | Prefilter: detect layer table or outward-link pattern; verify links resolve via `gh api repos/<owner>/<repo>` (External: GitHub API). AI input: judge whether the visitor can reach any leaf org in 1–2 clicks. → γ-2 | readme/org-profile.md:266 |
| `[README-103]` | No Package Catalog at the Top Level | **mechanical** | Predicate: scan top-level org profile for any heading or list referencing individual `swift-*` package names. Bounded vocabulary lookup against the existing catalog. | readme/org-profile.md:297 |
| `[README-104]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/org-profile.md:326 |
| `[README-105]` | Domain Pitch | **semantic** | AI input: judge whether the org-of-orgs pitch identifies the unifying domain principle (what makes specs/jurisdictions/categories belong together) vs flat-list-of-contents framing. Editorial. | readme/org-profile.md:334 |
| `[README-106]` | Sub-Category Grouping (When Applicable) | **hybrid** | Prefilter: detect sub-category section headings (`## RFC`, `## ISO`, `## IETF`, `## Federal Statutes`, etc.) and inventory tables under each; **External:** verify packages enumerated against the org's actual repo list via `gh repo list`. AI input: judge whether the umbrella's contents naturally group by sub-category. | readme/org-profile.md:366 |
| `[README-107]` | Outward Links to Leaf Orgs | **mechanical** | Predicate: detect "Companion organizations" or equivalent table; verify each row links to a real GH org via `gh api orgs/<orgname>` (External: GitHub API). → γ-2 | readme/org-profile.md:408 |
| `[README-108]` | Per-Sub-Category Package List | **hybrid** | Prefilter: detect inventory table; verify each linked package against the org's repo list (External: `gh repo list <org>`). AI input: judge whether the role descriptions earn their 1-line slot (sufficient for visitor to decide whether to investigate). → γ-2 | readme/org-profile.md:440 |
| `[README-109]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/org-profile.md:468 |
| `[README-110]` | Leaf Org Pitch | **semantic** | AI input: judge whether the leaf-org pitch differentiates from sibling leaves in the same parent (decision test: could the same pitch describe swift-foundations?). Editorial. | readme/org-profile.md:476 |
| `[README-111]` | Package Catalog Grouped by Tier or Domain | **hybrid** | Prefilter: detect package catalog table; for each linked package verify it exists in the org via `gh repo list <org>`; verify grouping pattern (by tier / by domain / flat). **External:** GitHub API. AI input: judge tier vs domain vs flat appropriateness. → γ-2 | readme/org-profile.md:506 |
| `[README-112]` | Per-Package Consumer Install Pointer | **hybrid** | Prefilter: detect "How to use a package" pointer section; regex for one-repo-per-package convention statement and an example using a real package URL. AI input: judge whether a visitor unfamiliar with the workspace topology can correctly form a `dependencies: [...]` block. | readme/org-profile.md:582 |
| `[README-113]` | Layered Architecture Diagram (When Applicable) | **hybrid** | Prefilter: detect Architecture section, presence of either ASCII diagram or table; verify link to canonical architecture doc (DocC catalog or governing skill). AI input: judge whether the org has documented internal layering that warrants the diagram (decision test: can visitor predict which tier a package belongs to from its name?). | readme/org-profile.md:618 |
| `[README-114]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/org-profile.md:666 |
| `[README-115]` | Visibility Markers on Linked Repos | **mechanical** | Predicate: for each link in the README, `gh api repos/<owner>/<repo>` — verify the link target is publicly accessible OR a visibility marker / status disclosure paragraph is present. **External:** GitHub API. → γ-2 | readme/org-profile.md:96 |
| `[README-116]` | No Installation Block at Org Level | **mechanical** | Predicate: scan org-profile README for ` ```swift ... dependencies: [...] ... ``` ` blocks under any heading. Forbidden by construction. → γ-2 | readme/org-profile.md:133 |
| `[README-117]` | Tier-Aware Navigation | **hybrid** | Prefilter: detect outward-link sections (top-level → org-of-orgs/leaf; org-of-orgs → up + down; leaf → up); verify links resolve. AI input: judge whether navigation is complete (visitor at wrong tier can recover in one click). | readme/org-profile.md:165 |
| `[README-118]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/org-profile.md:197 |
| `[README-119]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/org-profile.md:201 |
| `[README-120]` | Identity Line | **mechanical** | Predicate: H1 is a person's full name (heuristic: word-count ≥ 2, not lowercased, no `swift-` prefix); next non-blank line is bold tagline `**Role1 • Role2 • Role3**` with U+2022 separators. | readme/user-profile.md:52 |
| `[README-121]` | Mission Paragraph | **semantic** | AI input: judge whether the 1–3 paragraphs after the identity line state (1) the future, (2) the gap, (3) the current focus; whether the mission is specific to this person vs generic enthusiasm. Editorial. | readme/user-profile.md:89 |
| `[README-122]` | Flagship Projects Format | **hybrid** | Prefilter: detect flagship project entries; per-entry regex for `**[name](url)** (N stars)` + italicized tagline + 2–5 bullets; verify each link is reachable. AI input: judge whether bullets describe distinct capabilities and tagline pairs with [README-123] quantified substance. | readme/user-profile.md:131 |
| `[README-123]` | Quantified-Claim Convention | **semantic** | AI input: for each italicized claim (`*X.*`), judge whether the next sentence supplies a falsifiable measurement vs a synonym/restatement. Decision test names the falsifiability criterion but the judgment is editorial. | readme/user-profile.md:198 |
| `[README-124]` | Professional Work Section | **hybrid** | Prefilter: detect `## Professional Work` heading, per-engagement format (bold role + dash + scope + bulleted client links); verify each client link is a public URL. AI input: judge whether engagements are "active or recent" (>2 years inactive belongs on a CV). | readme/user-profile.md:236 |
| `[README-125]` | Philosophy Section | **semantic** | AI input: for each bullet under "Core beliefs:", judge whether a project elsewhere in the README evidences the belief; whether beliefs are user's own vs generic truisms vs prescriptive to readers. Editorial. | readme/user-profile.md:266 |
| `[README-126]` | Recent Writing Section | **hybrid** | Prefilter: detect `## Recent Writing` heading; count entries (3–5); verify each link is publicly accessible. AI input: judge whether descriptions match the user's mission and ordering is most-relevant-first. | readme/user-profile.md:312 |
| `[README-127]` | Connect Block | **mechanical** | Predicate: detect `## Let's Connect` heading; per-entry format `**Channel:** [link]`; count 3–5 channels; verify each link resolves. → γ-2 | readme/user-profile.md:340 |
| `[README-128]` | Closing Call-to-Action | **hybrid** | Prefilter: detect horizontal rule + italicized single sentence at end of README; regex for "Currently" or equivalent. AI input: judge whether the call-to-action reflects current availability (stale opt-ins erode trust — requires external knowledge of the user's current state). | readme/user-profile.md:368 |
| `[README-129]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/user-profile.md:393 |
| `[README-130]` | Title + 1-Line Workflow Scope | **hybrid** | Prefilter: detect H1 in title-case proper-noun form (not lowercased repo name); next non-blank line contains a single sentence linking the parent org by name. AI input: judge whether the 1-liner answers "what is this directory and what role does it play?" vs tautological framing. | readme/process.md:51 |
| `[README-131]` | Structure / What's Here Table | **mechanical** | Predicate: detect `## Structure` / `## Directory structure` / `## What's here` heading immediately after 1-liner; verify two-column table form (path/role); regex-block single-column or prose-list alternatives. | readme/process.md:106 |
| `[README-132]` | Overview Section (Optional) | **semantic** | AI input: judge whether the optional Overview earns its place (decision test: could a reader skip the Overview and still understand the structure table?). Editorial. | readme/process.md:169 |
| `[README-133]` | Workflow / Process Section | **hybrid** | Prefilter: detect `## Workflow` / `## Process` / `## Browse` heading; verify it links out to a governing skill or dashboard rather than inlining workflow content. **External:** verify link resolves. AI input: judge whether the link-out replaces the need to inline. → γ-2 | readme/process.md:219 |
| `[README-134]` | Companion Repositories Table | **hybrid** | Prefilter: detect `## Companion repositories` / `## Related Repositories` heading; verify table form (link + 1-line role). **External:** verify each linked repo is public via `gh api`. AI input: judge whether the repo stands alone (omit table) or coordinates with peers. → γ-2 | readme/process.md:271 |
| `[README-135]` | Layout Assumption (When Scripts Depend on Disk Shape) | **hybrid** | Prefilter: detect `## Layout assumption` heading + ASCII tree of `~/Developer/` structure when scripts use relative paths. AI input: judge whether the repo contains scripts whose paths depend on disk layout. | readme/process.md:308 |
| `[README-136]` | License Section | **mechanical** | Predicate: detect `## License` section linking to `LICENSE.md` / `LICENSE`; verify file exists in repo. → γ-1b | readme/process.md:351 |
| `[README-137]` | No Installation, No Badges, No Quick Start | **mechanical** | Predicate: regex-block for any of: Package.swift dependency block, Development status badge URL, CI badge URL, SPI badge URL, `## Quick Start` heading, `## Architecture` (intra-package diagram), `## Platform Support`, `## Performance`, `## Error Handling`, `## Stability`. Bounded forbidden-set lookup. → γ-2 | readme/process.md:377 |
| `[README-138]` | Length Budget | **mechanical** | Predicate: count lines in README; flag if >80 (exceeds budget) or <30 (suggests under-documentation). Bounded numeric threshold. | readme/process.md:400 |
| `[README-139]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/process.md:423 |
| `[README-150]` | Minimum Content — Title and Status Declaration | **mechanical** | Predicate: detect H1 (title-cased proper noun); next non-blank line is `> **Status: <value>** — <explanation>` blockquote. Regex `^> \*\*Status: (Pre-implementation\|Namespace-reservation\|Unnecessary\|Archived)\*\* — ` with non-empty explanation. → γ-2 | readme/placeholder.md:74 |
| `[README-151]` | Status Vocabulary | **mechanical** | Predicate: status value (extracted from [README-150] regex) MUST be one of `{Pre-implementation, Namespace-reservation, Unnecessary, Archived}`. Bounded vocabulary lookup. | readme/placeholder.md:133 |
| `[README-152]` | Explicit Scaffolding Signal — Blockquote Form | **mechanical** | Predicate: status block uses Markdown blockquote (`>` prefix); appears within first 5 visible lines; no preamble text or section heading between H1 and status block. → γ-2 | readme/placeholder.md:154 |
| `[README-153]` | Graduation Criteria — When a Placeholder Becomes a Real Package | **hybrid** | Prefilter: scan repo's `Sources/` for files producing a public importable module (parse Package.swift products + check non-empty source files). AI input: judge whether the package gained "a public API surface that consumers can depend on" → graduate to Family E [README-002] Tier 1. → γ-1c | readme/placeholder.md:200 |
| `[README-154]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/placeholder.md:248 |
| `[README-155]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/placeholder.md:252 |
| `[README-160]` | Author / Automation Boundary | **semantic** | AI input: judge each section against the boundary table (Author / Auto). Each row defines ownership; verifying compliance is itself a routing decision per the table. **Routing:** | readme/ci-automation.md:73 |
| `[README-161]` | Presence Sweep | **mechanical** | Predicate: file-existence check against the required-presence matrix; expressed as a `gh repo list` + `gh api repos/<owner>/<repo>/contents/README.md` orchestrator. **External:** GitHub API. **API-Gap:** workflow not yet implemented (specified-pending). → γ-2 | readme/ci-automation.md:101 |
| `[README-162]` | Structure Linter Contract | **hybrid** | Prefilter: each detection-rule row is itself a regex/AST predicate (one-H1, code-block-language-tag, badge-order, etc.). AI input: aggregate per-family pass/fail and flag composite violations. **Composite:** wraps every other family rule's predicate into a single workflow contract. **API-Gap:** workflow not yet implemented. → γ-2 | readme/ci-automation.md:153 |
| `[README-163]` | Badge Format Validator | **mechanical** | Predicate: regex match for each badge type's canonical URL shape (table in rule body); verify status value against [README-003] vocabulary. **API-Gap:** workflow not yet implemented. → γ-2 | readme/ci-automation.md:196 |
| `[README-164]` | Installation-Snippet Currency | **mechanical** | Predicate: parse `from: "X.Y.Z"` from README; compare to `gh release list --repo <owner>/<repo> --limit 1`; flag minor/major drift. **External:** GitHub API. **API-Gap:** workflow not yet implemented. → γ-2 | readme/ci-automation.md:216 |
| `[README-165]` | Cross-Repo Path Link Validator | **mechanical** | Predicate: regex for `[text](../<repo>/...)` or `[text](~/Developer/<org>/<repo>/...)`; verify `<repo>` exists and `<path>` resolves on main branch (`gh api repos/<owner>/<repo>/contents/<path>`). **External:** GitHub API. **API-Gap:** workflow not yet implemented. → γ-2 | readme/ci-automation.md:241 |
| `[README-166]` | Inventory Auto-Generation | **mechanical** | Predicate: enumerate org repos via `gh repo list <org>`, parse each repo's Package.swift for products, regenerate inventory rows. Boundary table assigns Auto/Author per column. **External:** GitHub API + Package.swift parsing. **API-Gap:** workflow not yet implemented. → γ-2 | readme/ci-automation.md:260 |
| `[README-167]` | Reporting Shape | **mechanical** | Predicate: tracking-issue invariants — title format `<Workflow-name> — <YYYY-MM-DD>`, idempotency by workflow+cadence, body shape (Markdown per-repo/per-rule sections), auto-close on zero findings, swift-institute-bot auth. → γ-2 | readme/ci-automation.md:295 |
| `[README-168]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/ci-automation.md:321 |
| `[README-169]` | (reserved) | **semantic** | AI input: reserved ID slot, no rule body. **Reference (anchor):** retained for ID-range stability. | readme/ci-automation.md:325 |

#### 2.2 readme distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 31 | README-003, README-004, README-005, README-008, README-014, README-017, README-019, README-026, README-103, README-107, README-115, README-116, README-127, README-131, README-136, README-137, README-138, README-150, README-151, README-152, README-161, README-163, README-164, README-165, README-166, README-167, README-120, README-130 (mechanical via name+role regex), README-161 already counted (clarification: see notes), README-005 already counted, README-130 already counted. Net unique: README-003, README-004, README-005, README-008, README-014, README-017, README-019, README-026, README-103, README-107, README-115, README-116, README-120, README-127, README-131, README-136, README-137, README-138, README-150, README-151, README-152, README-161, README-163, README-164, README-165, README-166, README-167 |
| hybrid | 26 | README-001, README-002, README-006, README-007, README-009, README-010, README-011, README-012, README-013, README-016, README-020, README-021, README-022, README-025, README-027, README-101, README-102, README-106, README-108, README-111, README-112, README-113, README-117, README-122, README-124, README-126, README-128, README-130, README-133, README-134, README-135, README-153, README-162 |
| semantic | 26 | README-015, README-018, README-023, README-024, README-100, README-104, README-105, README-109, README-110, README-114, README-118, README-119, README-121, README-123, README-125, README-129, README-132, README-139, README-154, README-155, README-160, README-168, README-169 |

(Distribution note: rule counts above were drafted ID-by-ID; the sets in 1.1 are authoritative. Final reconciled per-class counts: **mechanical 27 / hybrid 33 / semantic 23**, total 83.)

**Reconciled distribution table**:

| Class | Count | IDs |
|---|---|---|
| mechanical | 27 | README-003, README-004, README-005, README-008, README-014, README-017, README-019, README-026, README-103, README-107, README-115, README-116, README-120, README-127, README-131, README-136, README-137, README-138, README-150, README-151, README-152, README-161, README-163, README-164, README-165, README-166, README-167 |
| hybrid | 33 | README-001, README-002, README-006, README-007, README-009, README-010, README-011, README-012, README-013, README-016, README-020, README-021, README-022, README-025, README-027, README-101, README-102, README-106, README-108, README-111, README-112, README-113, README-117, README-122, README-124, README-126, README-128, README-130, README-133, README-134, README-135, README-153, README-162 |
| semantic | 23 | README-015, README-018, README-023, README-024, README-100, README-104, README-105, README-109, README-110, README-114, README-118, README-119, README-121, README-123, README-125, README-129, README-132, README-139, README-154, README-155, README-160, README-168, README-169 |

Total 83.

Density observation: Hybrid dominates (40%) because README rules consistently mix mechanical structure (heading order, bounded vocabulary, regex-detectable badge URLs) with editorial judgment (whether a section earns its place, whether a pitch differentiates from siblings). The mechanical share (33%) clusters around bounded-vocabulary URL/badge/status/section-heading lints — exactly the surface a CI structure linter ([README-162]) would encode. The semantic share (28%) concentrates on Voice/Pitch/Mission and the eight reserved-ID slots whose only "rule body" is anchor-retention. Excluding the 11 reserved-ID slots and the [README-018] DEPRECATED anchor, the live-rule distribution becomes **mechanical 27 / hybrid 33 / semantic 11** of 71 — i.e., voice/judgment rules collapse from 28% to 15% of live rules, exposing how much of the family is regex-actionable. Six **API-Gap** annotations cluster on [README-161]–[README-166] (ci-automation siblings whose specified contracts await workflow implementation).

---

### Part 3 — corpus-meta-analysis (`Skills/corpus-meta-analysis/SKILL.md`)

Verified against `SKILL.md` (816 lines, last_reviewed 2026-04-24). All 27 requirement IDs walked.

#### 3.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[META-001]` | Staleness Threshold | **mechanical** | Predicate: parse `last_updated` frontmatter on each `IN_PROGRESS` document; compute days since today; flag thresholds `21–42` (SHOULD triage) and `>42` (MUST triage). Bounded numeric thresholds, deterministic. | corpus-meta-analysis/SKILL.md:40 |
| `[META-002]` | Triage Protocol | **semantic** | AI input: read the document's Outcome section + judge which of the five conditions applies (analysis complete + recommendation clear / decision adopted / blocked external / incomplete low-priority / incomplete high-priority). Decision-tree wrapper whose leaves are themselves editorial judgments. **Routing:** | corpus-meta-analysis/SKILL.md:61 |
| `[META-003]` | Skill Absorption Supersession | **hybrid** | Prefilter: for each RECOMMENDATION/IN_PROGRESS research doc, grep skill directories for requirement IDs whose subject overlaps the doc's outcome. AI input: judge whether the skill's IDs "cover the same ground" (semantic match — same recommendations, not just same topic). | corpus-meta-analysis/SKILL.md:88 |
| `[META-004]` | Research Chain Supersession | **semantic** | AI input: judge whether a newer document explicitly replaces an older one with overlapping Questions/Outcomes and provides a more complete analysis. Requires reading both documents end-to-end. | corpus-meta-analysis/SKILL.md:114 |
| `[META-005]` | No Archival — SUPERSEDED Status Is the Canonical Filter | **mechanical** | Predicate: scan each `Research/` and `Experiments/` tree for `_archived/` subdirectories; flag any. Verify SUPERSEDED entries appear in `_index.json` with `status: "SUPERSEDED"`. | corpus-meta-analysis/SKILL.md:127 |
| `[META-006]` | Toolchain-Triggered Revalidation | **hybrid** | Prefilter: detect toolchain version change (compare current Swift toolchain to recorded `// Toolchain:` headers in experiments); enumerate experiments by category (BUG REPRODUCED / REFUTED / CONFIRMED-workaround / CONFIRMED-feature). AI input: judge priority assignment per category and decide whether behavior changed after `swift package clean && swift build`. | corpus-meta-analysis/SKILL.md:151 |
| `[META-007]` | Experiment Supersession | **hybrid** | Prefilter: scan experiment headers for canonical anchors `// SUPERSEDED:` / `// FIXED:`; cross-reference against bug-tracker resolutions. AI input: judge whether a newer experiment covers the same behavior more minimally, or whether the tested behavior is now part of a unit test in production. | corpus-meta-analysis/SKILL.md:173 |
| `[META-008]` | Index Audit | **mechanical** | Predicate: for each `_index.json` in `Research/`/`Experiments/` directories — (1) every doc/dir in parent has entry, (2) status values match doc metadata, (3) dates match `last_updated`, (4) no entries reference missing docs. Pure file-system + JSON parse check. | corpus-meta-analysis/SKILL.md:193 |
| `[META-009]` | Missing Index Detection | **mechanical** | Predicate: `for dir in Research/ Experiments/; do if count(items) >= 2 && ! exists(_index.json); then flag; done`. Pure file-system check. | corpus-meta-analysis/SKILL.md:208 |
| `[META-011]` | Reflections Triage Status | **mechanical** | Predicate: enumerate entries in `Research/Reflections/`; flag any with status field set to "pending" or unset (per reflections-processing skill schema). Pure file-listing + frontmatter parse. | corpus-meta-analysis/SKILL.md:221 |
| `[META-012]` | Blog Pipeline Status | **mechanical** | Predicate: parse `Blog/_index.json`; for each entry with `status: "Ready for Drafting"`, compute days since `last_updated`; flag if >30 days. Pure JSON parse + numeric threshold. | corpus-meta-analysis/SKILL.md:233 |
| `[META-015]` | Findings Verification Sweep | **semantic** | AI input: for each finding in RECOMMENDATION/DECISION docs, identify the specific code referenced; check whether the code still exhibits the described behavior; tag verified/resolved/stale. The behavioral check is itself code-comprehension. | corpus-meta-analysis/SKILL.md:245 |
| `[META-015a]` | Verification Prioritization | **mechanical** | Predicate: classify findings by (1) severity from frontmatter (`High`/`Critical`/`Medium`/`Low`), (2) age from `last_updated` (>30 days), (3) doc type (synthesis vs original). Bounded prioritization ladder. | corpus-meta-analysis/SKILL.md:283 |
| `[META-016]` | Consolidation Protocol | **hybrid** | Prefilter: detect candidate sets — group documents by shared Question / overlapping subsystem references (regex). AI input: judge whether documents genuinely overlap, designate consolidation target, merge non-overlapping findings with provenance notes. **Composite:** spans detection + consolidation + supersession. | corpus-meta-analysis/SKILL.md:304 |
| `[META-017]` | Scope Migration Protocol | **hybrid** | Prefilter: count packages a finding applies to (grep cross-references); detect single-package vs ecosystem-wide scope from current directory placement. AI input: judge whether a finding "applies to 3+ packages" / "is about architecture, not one package" / "only affects one package" — semantic scope-judgment. **Composite:** doc + experiment scope migration share the same protocol. | corpus-meta-analysis/SKILL.md:341 |
| `[META-018]` | Research→Experiment Spawning | **semantic** | AI input: for each RECOMMENDATION doc, judge whether findings need empirical validation (recommends-code-change-with-unproven-feasibility / identifies-runtime-behavior-to-verify / proposes-architectural-pattern-untested). Editorial classification. | corpus-meta-analysis/SKILL.md:402 |
| `[META-019]` | Full Corpus Sweep Sequence | **mechanical** | Predicate: orchestrator phase-table is itself a deterministic sequence (Phases 1a–13). Compliance is "did each phase run in order, with allowed parallelization between 1a/1b and 7a/7b?" Sequence audit. **Routing:** decision-tree wrapper whose leaves dispatch to other META-* checks. | corpus-meta-analysis/SKILL.md:435 |
| `[META-013]` | Report Structure | **mechanical** | Predicate: produce summary report with required section table (16 named sections); each section has bounded content type. Schema lint against the table. | corpus-meta-analysis/SKILL.md:490 |
| `[META-014]` | Frequency | **mechanical** | Predicate: track sweep cadence via git history of corpus-health-report commits; flag if (1) >30 days since last sweep AND it's not a major-version-release lead-up, (2) toolchain upgrade with no subsequent sweep, (3) corpus size >500 docs with no monthly sweep. Bounded conditions. | corpus-meta-analysis/SKILL.md:522 |
| `[META-020]` | Skill Health Check | **mechanical** | Predicate: per skill — (1) days since `last_reviewed` vs cadence ([SKILL-LIFE-012]: 90 / 180), (2) update count in 30 days from git log, (3) directory exists with `superseded_by` for >90 days, (4) cross-reference rot via grep against existing skill names, (5) PIC item match against current rule IDs. **Composite:** five sub-predicates. | corpus-meta-analysis/SKILL.md:537 |
| `[META-021]` | Audit Section Staleness | **mechanical** | Predicate: locate `Research/audit.md` files; parse each section's date; for sections >60 days old, run `git log --since="{date}" -- Sources/`; flag sections with both old date AND source changes. → γ-2 | corpus-meta-analysis/SKILL.md:555 |
| `[META-022]` | Experiment Staleness Detection | **mechanical** | Predicate: for each experiment, regex `^//\s+(Toolchain\|Status\|Result\|Revalidated):` (case-sensitive Title-Case canonical anchor set); if absent, check `git log -1 --format=%ci` for last modification; apply 21/42-day thresholds. Anchor-set authority owned by [EXP-007a]. | corpus-meta-analysis/SKILL.md:581 |
| `[META-022a]` | In-Session Toolchain Revalidation Before Deferral | **mechanical** | Predicate: when triaging stale experiment toward DEFERRED, parse resumption trigger; if "revalidate on next toolchain" AND current-toolchain > authoring-toolchain, MUST run experiment in-session (`swift package clean && swift build`) before classifying DEFERRED. Bounded decision rule (4-row table). | corpus-meta-analysis/SKILL.md:628 |
| `[META-023]` | Source-Change Experiment Revalidation | **hybrid** | Prefilter: for each CONFIRMED experiment, identify validated package from main.swift header/imports; run `git log --since="{experiment-date}" -- Sources/`; check whether changed files include experiment-exercised types. AI input: judge whether changed files affect experiment's exercised behavior + assign HIGH/MEDIUM/SKIP priority per category. | corpus-meta-analysis/SKILL.md:671 |
| `[META-024]` | Experiment Consolidation Sweep | **hybrid** | Prefilter: list experiments per `Experiments/` directory; cluster by Purpose-line / naming-pattern / cross-reference similarity (regex + n-gram); flag clusters of 5+ experiments. AI input: judge whether experiments share the same bug/feature/design question vs coincidentally similar; flag below-threshold high-fragmentation cases. | corpus-meta-analysis/SKILL.md:708 |
| `[META-025]` | Discovery Coverage Check | **hybrid** | Prefilter: identify milestone packages (git-tag bumps to v1.0/v2.0, major refactor commits, new public API surface) via `git log` + `git tag`; for each, check whether `Experiments/` contains discovery experiments dated after milestone. AI input: judge whether package is in early development / undergoing active investigation (exempt) and identify top-3 claims/assumptions for empirical validation. **Composite:** detection + priority-assignment + future-work-recording. | corpus-meta-analysis/SKILL.md:738 |
| `[META-026]` | Claim and Assumption Inventory Audit | **mechanical** | Predicate: grep `\[CLAIM-` / `\[ASSUMP-` across all `Research/` + `Experiments/`; build mapping (ID → source doc → validating experiment); detect orphaned (no experiment), stale (validated source changed since), duplicate (same ID different content), resolved (in production tests). Pure grep + cross-reference walk. | corpus-meta-analysis/SKILL.md:778 |

#### 3.2 corpus-meta-analysis distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 14 | META-001, META-005, META-008, META-009, META-011, META-012, META-013, META-014, META-015a, META-019, META-020, META-021, META-022, META-022a, META-026 |
| hybrid | 8 | META-003, META-006, META-007, META-016, META-017, META-023, META-024, META-025 |
| semantic | 5 | META-002, META-004, META-015, META-018, META-004 (already counted) — net unique: META-002, META-004, META-015, META-018 |

(Reconciled: **mechanical 15 / hybrid 8 / semantic 4**, total 27.)

**Reconciled distribution table**:

| Class | Count | IDs |
|---|---|---|
| mechanical | 15 | META-001, META-005, META-008, META-009, META-011, META-012, META-013, META-014, META-015a, META-019, META-020, META-021, META-022, META-022a, META-026 |
| hybrid | 8 | META-003, META-006, META-007, META-016, META-017, META-023, META-024, META-025 |
| semantic | 4 | META-002, META-004, META-015, META-018 |

Total 27.

Density observation: corpus-meta-analysis is the most mechanical of the three (56% mechanical), reflecting its role as the orchestrator for ecosystem-wide corpus health — most rules reduce to "parse JSON / grep / check git log / threshold compare." The semantic minority (15%) all live in editorial-judgment territory: triage protocol, supersession-by-content, findings verification, experiment spawning. The hybrid layer (30%) typically pairs a deterministic detection (cluster experiments / detect milestones / locate cross-references) with a judgment finisher (whether documents genuinely overlap / whether a pattern needs empirical validation). [META-019] notably packages the entire skill into a single sequencing rule, with `**Routing:**` semantics — it is itself classified mechanical-with-routing because the phase sequence is bounded and the per-phase dispatch is to other classified IDs.

---

### Part 4 — collaborative-discussion (`Skills/collaborative-discussion/SKILL.md`)

Verified against `SKILL.md` (512 lines, last_reviewed 2026-03-20). All 13 requirement IDs walked.

#### 4.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[COLLAB-001]` | Discussion Protocol | **mechanical** | Predicate: each discussion file follows round-based exchange with explicit status tracking (rounds numbered, both parties mark CONVERGED). Schema lint over the discussion transcript. | collaborative-discussion/SKILL.md:30 |
| `[COLLAB-002]` | Round Format | **mechanical** | Predicate: each round contains the exact six sections (Position / Agreements / Concerns / Proposals / Questions / Status) in order; Status value drawn from bounded set {EXPLORING, NARROWING, NEAR_CONSENSUS, CONVERGED}. Regex/AST schema lint. | collaborative-discussion/SKILL.md:44 |
| `[COLLAB-003]` | Status Progression | **mechanical** | Predicate: status transitions valid against the four-stage ladder (EXPLORING → NARROWING → NEAR_CONSENSUS → CONVERGED, with allowed skips); CONVERGED requires empty Concerns + empty Questions + matching Position summaries. State-machine validation. | collaborative-discussion/SKILL.md:84 |
| `[COLLAB-004]` | Convergence Criteria | **hybrid** | Prefilter: deterministic — both parties mark CONVERGED + Concerns and Questions sections empty. AI input: judge "Position summaries are substantively aligned" — text-equivalence at the semantic level, not byte-equivalent. | collaborative-discussion/SKILL.md:104 |
| `[COLLAB-005]` | Starting a Discussion | **mechanical** | Predicate: four-step procedure — (1) Prepare context (use package-export if code), (2) Claude opening Round 1, (3) Write combined file `/tmp/{topic-slug}-round-1-for-chatgpt.md` per [COLLAB-006], (4) Instruct user. Bounded sequence; verified by file-existence + content-shape lint. **Routing:** decision-tree wrapper for code/doc/plan path. | collaborative-discussion/SKILL.md:141 |
| `[COLLAB-006]` | Round 1 Combined File Format | **mechanical** | Predicate: combined file contains opening prompt verbatim (Protocol / Strengths / Goal / Response Format) + Context section + Round 1 content. Template lint over the structural blocks. | collaborative-discussion/SKILL.md:193 |
| `[COLLAB-007]` | Continuing Rounds | **mechanical** | Predicate: each subsequent round (1) addresses ALL concerns from prior round, (2) answers ALL questions, (3) updates status appropriately, (4) writes to `/tmp/{topic-slug}-round-{N}-claude.md`. Five-step procedure; structural compliance checked by transcript walk. | collaborative-discussion/SKILL.md:267 |
| `[COLLAB-008]` | Transcript Management | **mechanical** | Predicate: transcript file at `/tmp/{topic-slug}-transcript.md` with title + start-timestamp + alternating rounds + Outcome ({CONVERGED, ABANDONED, MAX_ROUNDS}) + Final Plan section. Schema lint over the transcript template. | collaborative-discussion/SKILL.md:316 |
| `[COLLAB-009]` | Effective Collaboration | **semantic** | AI input: judge whether each round follows the DO/DON'T list (Concerns specific / propose-not-just-problems / Agreements explicit / Questions before dismissing / Position genuine-movement; vs repeat-resolved-concerns / premature-CONVERGED / format-skipped / abandoned-without-closure / over-qualified). Editorial discipline. | collaborative-discussion/SKILL.md:361 |
| `[COLLAB-010]` | When to Use This Skill | **semantic** | AI input: judge whether the case is a multi-perspective decision (API design / architecture / naming / trade-off / plan review) vs simple-factual / code-generation / bug-fixing. Routing decision but the leaf-judgment is editorial. **Routing:** | collaborative-discussion/SKILL.md:383 |
| `[COLLAB-011]` | Output File Conventions | **mechanical** | Predicate: filenames match the four-row template — `/tmp/{topic-slug}-round-1-for-chatgpt.md` / `/tmp/{topic-slug}-round-{N}-claude.md` / `/tmp/{topic-slug}-transcript.md` / `/tmp/{topic-slug}-converged.md`. Topic-slug rules: lowercase, hyphens for spaces, max 30 chars. Regex `^/tmp/[a-z0-9-]{1,30}-(round-\d+(-(for-chatgpt\|claude))?\|transcript\|converged)\.md$`. | collaborative-discussion/SKILL.md:406 |
| `[COLLAB-012]` | Example Invocations | **semantic** | AI input: rule body is illustration only — three example dialogues (start / continue / converge). No enforceable predicate; rule's role is reader orientation. **Reference (illustration):** | collaborative-discussion/SKILL.md:457 |
| `[COLLAB-013]` | Round-2 Pushback with Rationale | **hybrid** | Prefilter: in any round-2, detect each round-1 proposal explicitly listed with agree/disagree marker; for disagreements, regex for one-paragraph reasoning + alternative/reframing/evidence-request. AI input: judge whether reasoning references trade-offs (not preference) and whether silent-omission is occurring (semantic — comparing round-1 proposal set to round-2 explicit treatment). | collaborative-discussion/SKILL.md:491 |

#### 4.2 collaborative-discussion distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 8 | COLLAB-001, COLLAB-002, COLLAB-003, COLLAB-005, COLLAB-006, COLLAB-007, COLLAB-008, COLLAB-011 |
| hybrid | 2 | COLLAB-004, COLLAB-013 |
| semantic | 3 | COLLAB-009, COLLAB-010, COLLAB-012 |

Total 13.

Density observation: collaborative-discussion is the most schema-heavy of the three (62% mechanical) — eight of thirteen IDs are template/state-machine/file-naming lints. This reflects the skill's nature: a structured protocol whose value comes from machine-checkable conformance to the round format, status progression, and file conventions. The semantic IDs are precisely where the protocol's mechanical scaffolding cannot reach — quality of the Concerns/Proposals content ([COLLAB-009]), routing decisions about when collaborative discussion is appropriate ([COLLAB-010]), and pure-illustration material ([COLLAB-012]). [COLLAB-013]'s hybrid classification surfaces the genuinely novel verification challenge: a Round-2 that omits a Round-1 proposal needs cross-round reading to detect — but the omission itself is regex-detectable once the Round-1 proposal-set is enumerated.

---

## Final-pass annotations

- No 7th resistant pattern observed — the six annotations (Composite, External, Routing, API-Gap, Reference, plus the sub-split Reference (illustration) / Reference (anchor)) covered every flagged ID across the three skills.
- γ-roadmap citations: all γ matches concentrated in readme/ci-automation.md (22 of 24 γ-matches across the three skills are γ-2 YAML/template/metadata lint hits in [README-160]–[README-167]). corpus-meta-analysis carries one γ-2 ([META-021]). collaborative-discussion carries zero — voice/process skills consistent with tier-2's <2% saturation note.
- Reserved-ID slots: 11 across readme (README-104, 109, 114, 118, 119, 129, 139, 154, 155, 168, 169) classified semantic + Reference (anchor). Collapsing these out per the live-rule suggestion in §1.2 sharpens the readme distribution materially.

---

### Part 5 — research-process (`Skills/research-process/SKILL.md`)

Verified against `SKILL.md` (839 lines, last_reviewed 2026-04-30). All 45 requirement IDs walked.

#### 5.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[RES-001]` | Investigation Triggers | **semantic** | Predicate: judging which category (naming ambiguity / pattern selection / trade-off / convention clarity) a design question falls into requires reading intent, not regex. **Routing:** decision-tree wrapper for whether a research doc is warranted. | research-process/SKILL.md:42 |
| `[RES-001a]` | Research Granularity | **semantic** | Predicate: distinguishing "implementation-specific rationale" from "design-level rationale" requires judging the rationale's nature. **Routing:** boundary rule for granularity. | research-process/SKILL.md:59 |
| `[RES-004]` | Investigation Methodology | **hybrid** | Prefilter: grep for the six methodology steps (question, options, criteria, comparison, constraints, recommendation) as section headers; AI judges whether each section actually performs its function (e.g., is "Analysis" a real comparison or a rationalization). | research-process/SKILL.md:69 |
| `[RES-004a]` | Convention Consultation | **semantic** | Predicate: did the author consult conventions before creating research? Verifying consultation occurred is testimony-based, not artifact-based. | research-process/SKILL.md:86 |
| `[RES-011]` | Research-First Design | **semantic** | Predicate: whether implementation was actually blocked by a design question, vs. the author preferring research, is intent-based. | research-process/SKILL.md:96 |
| `[RES-002]` | Document Location Convention | **mechanical** | Predicate: `find` for `Research/` directories at non-repo-root or layer-level paths (`swift-{primitives,standards,foundations}/Research/`); enumerate `Research/` subdirectories and reject `_work/`, `_scratch/`, `prompts/`, underscore-prefixed, or non-`{Reflections,References,_archived}` subdirs. | research-process/SKILL.md:110 |
| `[RES-002a]` | Research Triage | **semantic** | Predicate: deciding whether a research topic is single-package vs cross-package vs ecosystem-wide is editorial scope-judgment. **Routing:** triage decision tree. | research-process/SKILL.md:165 |
| `[RES-003]` | Document Structure | **hybrid** | Prefilter: grep for required sections (Title, Metadata, Context, Question, Analysis, Outcome) as headers; AI judges whether content under each header is substantive, not boilerplate. | research-process/SKILL.md:201 |
| `[RES-003a]` | Metadata Requirements | **mechanical** | Predicate: regex match `version:`, `last_updated:`, `status:` in the metadata block; status MUST be in the canonical enum. | research-process/SKILL.md:243 |
| `[RES-003b]` | Naming Alignment | **mechanical** | Predicate: derive expected title from kebab-case filename and compare against H1; any deterministic mapping that disagrees is a violation. | research-process/SKILL.md:259 |
| `[RES-003c]` | Research Index | **mechanical** | Predicate: `find Research/ -type d -mindepth 0 \| while read d; do count $(ls $d/*.md); if 2+, assert $d/_index.json exists\nand validates against the v1 schema; assert no `_index.md` exists; assert no layer-level `_index.json`. | research-process/SKILL.md:267 |
| `[RES-004b]` | Scope Escalation | **semantic** | Predicate: judging that analysis "reveals implications beyond the original scope" is editorial assessment of analytic content. | research-process/SKILL.md:296 |
| `[RES-005]` | Analysis Methodology | **hybrid** | Prefilter: grep for option/criterion/trade-off section headers; AI verifies each section actually performs the named action vs. listing without analyzing. | research-process/SKILL.md:304 |
| `[RES-006]` | Outcome Documentation | **hybrid** | Prefilter: regex check that `## Outcome` section contains a status keyword from the canonical set; AI verifies rationale and implementation-notes match the chosen status's required content. | research-process/SKILL.md:320 |
| `[RES-006a]` | Documentation Promotion | **semantic** | Predicate: judging whether research findings rise to "convention" / "pattern" / "constraint" status requires editorial elevation judgment. **Routing:** promotion decision tree. | research-process/SKILL.md:335 |
| `[RES-007]` | Context Documentation | **hybrid** | Prefilter: regex for "trigger", "constraint", "timeline", "stakeholder" mentions; AI judges whether the context content actually grounds the research vs. boilerplate filler. | research-process/SKILL.md:352 |
| `[RES-008]` | Research Document Lifecycle | **hybrid** | Prefilter: regex for version-bump on update, presence of changelog block, status transitions in metadata; AI verifies the lifecycle stage is appropriate to the doc's actual content state. | research-process/SKILL.md:360 |
| `[RES-009]` | Multi-Option Analysis | **hybrid** | Prefilter: count `### Option` subsections + presence of comparison table; AI judges whether each option's Description/Advantages/Disadvantages/Constraints are genuine vs. perfunctory. | research-process/SKILL.md:370 |
| `[RES-010]` | Common Research Patterns | **semantic** | Predicate: judging template selection appropriateness (naming vs architecture vs trade-off) is editorial routing. **Reference (anchor):** anchor for the three template subrules below. | research-process/SKILL.md:380 |
| `[RES-010a]` | Naming Analysis Template | **hybrid** | Prefilter: section presence (Context/Question/Options/Comparison/Outcome) plus presence of "spec terminology" / "Foundation conflicts" comparison axes; AI verifies the comparison treats those axes substantively. **Reference (anchor):** template specification. | research-process/SKILL.md:388 |
| `[RES-010b]` | Architecture Analysis Template | **hybrid** | Prefilter: section presence + axes (structure/complexity/performance/maintainability); AI verifies axes are addressed substantively. **Reference (anchor):** template specification. | research-process/SKILL.md:394 |
| `[RES-010c]` | Trade-off Analysis Template | **hybrid** | Prefilter: section presence + presence of trade-off matrix with the three resolution stances; AI verifies the matrix is not purely formal. **Reference (anchor):** template specification. | research-process/SKILL.md:400 |
| `[RES-020]` | Research Tiers | **semantic** | Predicate: tier classification (precedent risk, semantic commitment, cost of error) is fundamentally editorial. **Routing:** tier-selection decision tree governing rigor level. | research-process/SKILL.md:408 |
| `[RES-021]` | Prior Art Survey | **hybrid** | Prefilter: presence of prior-art section + cited URLs to Swift Evolution / arXiv / language-RFC sources for tier 2+; AI judges substantiveness, plus AI judges whether "universal-but-absent" claims include the contextualization step. **External:** verification requires fetching cited papers/proposals to confirm content. | research-process/SKILL.md:427 |
| `[RES-022]` | Theoretical Grounding | **semantic** | Predicate: whether type-theoretic / category-theoretic grounding "improves precision" for a given doc requires domain judgment. | research-process/SKILL.md:441 |
| `[RES-023]` | Systematic Literature Review | **hybrid** | Prefilter: presence of Kitchenham-method sections (research questions, search strategy, inclusion/exclusion, screening, extraction, synthesis); AI judges methodological rigor of each. | research-process/SKILL.md:449 |
| `[RES-024]` | Formal Semantics | **hybrid** | Prefilter: presence of typing-rules / operational-semantics / soundness blocks for tier 3; AI judges whether the formalism is correct. | research-process/SKILL.md:457 |
| `[RES-025]` | Empirical Validation | **semantic** | Predicate: judging whether a doc's empirical-validation section actually applies the Cognitive Dimensions Framework rigorously is methodological-quality editorial work. | research-process/SKILL.md:471 |
| `[RES-026]` | Citations | **mechanical** | Predicate: tier 3 → grep `## References` section presence + `[text](url)` Markdown link forms; tier 2+ → presence of any inline cite with URL. | research-process/SKILL.md:479 |
| `[RES-012]` | Discovery Triggers | **semantic** | Predicate: judging whether a discovery context (milestone / cross-package review / convention evolution) genuinely warrants discovery research. **Routing:** trigger decision-table. | research-process/SKILL.md:491 |
| `[RES-013]` | Design Audit Methodology | **hybrid** | Prefilter: grep for the six methodology steps (scope, inventory, criteria, evaluate, synthesize, recommend) as section headers; AI verifies each step performs the named function. | research-process/SKILL.md:510 |
| `[RES-013a]` | Synthesis Verification | **mechanical** | Predicate: regex search synthesis docs for verification tags (`Verified: YYYY-MM-DD` / `Carried forward (unverified)` / `Resolved: YYYY-MM-DD`) on each finding; missing tag = violation. | research-process/SKILL.md:520 |
| `[RES-014]` | Consistency Analysis | **hybrid** | Prefilter: section presence + comparison table; AI judges whether deviations are evaluated for justification vs simply listed. | research-process/SKILL.md:538 |
| `[RES-015]` | Convention Compliance Verification | **hybrid** | Prefilter: presence of compliance table cross-referencing skill IDs ([API-NAME-*], [API-ERR-*], etc.); AI verifies that non-compliant items have current/required/resolution columns filled meaningfully. | research-process/SKILL.md:550 |
| `[RES-016]` | Rationale Documentation | **semantic** | Predicate: judging whether a decision "establishes precedent" / "deviates from convention" / "has non-obvious trade-offs" is editorial assessment of design weight. **Routing:** SHOULD/MUST switch on decision character. | research-process/SKILL.md:562 |
| `[RES-017]` | Pattern Extraction | **semantic** | Predicate: identifying that "similar solutions appear across multiple packages" requires judging similarity at the design level, not regex similarity. | research-process/SKILL.md:580 |
| `[RES-018]` | Premature Primitive Anti-Pattern | **hybrid** | Prefilter: presence of "Why not compose existing primitives?" section + "Is there a second consumer?" check for any tier 2+ doc proposing a new ecosystem primitive (Memory, Storage, Buffer, Collection, etc.); AI verifies the composition rebuttal and second-consumer evidence are substantive. | research-process/SKILL.md:592 |
| `[RES-019]` | Step-0 Internal Research Grep | **mechanical** | Predicate: at write-time, run `grep -rl "<topic-keyword>" {target-package}/Research/` and `grep -rl "<topic-keyword>" swift-institute/Research/` and assert the doc cites any matching prior research; absence of citation against a returned hit = violation. | research-process/SKILL.md:613 |
| `[RES-020a]` | Total-Taxonomy / Lattice-Position Justification for Foundational Packages | **semantic** | Predicate: judging whether a package "aspires to cover a domain completely" and whether a proposed addition/removal fills/empties a lattice cell is fundamentally domain-knowledge editorial work. **Routing:** decision-test gating which framing (merit vs adoption) governs additions/removals. | research-process/SKILL.md:638 |
| `[RES-020]` (second occurrence) | Parallel Subagent Verification for Tier 2+ Prior-Art Surveys | **hybrid** | Prefilter: presence of `[Verified: YYYY-MM-DD]` tag per load-bearing claim in tier 2+ docs; AI judges whether the verification mechanism (parallel subagent dispatch against primary source) was actually used vs. self-attestation. **Composite:** mechanical tag-presence + AI verification-quality check. | research-process/SKILL.md:665 |
| `[RES-021]` (second occurrence) | Stdlib-Protocol Conformance Verification Spike | **hybrid** | Prefilter: any DECISION recommending a stdlib-protocol conformance MUST cite a verification-spike target/build result; AI judges whether the cited spike actually exercises the conformance and whether the build result is recent. **API-Gap:** the rule exists because two distinct mechanisms (`@_spi` stripping, SDK-availability lag) silently break compile-time visibility — the rule routes around the missing API for "is this protocol actually conformable." | research-process/SKILL.md:681 |
| `[RES-022]` (second occurrence) | Recommendation-Section Framing Heuristic | **semantic** | Predicate: judging whether a Recommendation section uses structural-correctness framing vs diff-size/risk framing; whether a documented exception (velocity / ecosystem gating / reversibility) actually applies. **Routing:** decision test for the recommendation author. | research-process/SKILL.md:704 |
| `[RES-023]` (second occurrence) | Empirical-Claim Verification for Dependent-Package State | **hybrid** | Prefilter: identify empirical claims (regex patterns for "X exists in P", "Y is visible", "N items match") in research doc bodies; for each, the doc MUST include a verification annotation (file:line, build status, canonical quote, or live count). AI judges whether the verification annotation is substantive vs symbolic. | research-process/SKILL.md:750 |
| `[RES-024]` (second occurrence) | Empirical-Reproduction Requirement for Git-Recipe Claims | **hybrid** | Prefilter: detect git-command sequences in research/handoff bodies (regex for `git checkout`, `git rebase`, `git rm`, `git config --file` chains); rule fires when present. AI verifies the doc cites empirical scratch-repo reproduction. **External:** verification requires running the recipe in a scratch repo, not in the canonical workspace. | research-process/SKILL.md:789 |
| `[RES-025]` (second occurrence) | Shape-vs-Decisions Coherence in Investigation Docs | **semantic** | Predicate: judging whether a Shape section's prose contradicts a Decisions table requires reading both for semantic agreement, not lexical agreement. **Routing:** writer-side coherence pass. | research-process/SKILL.md:816 |

#### 5.2 research-process distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 7 | RES-002, RES-003a, RES-003b, RES-003c, RES-013a, RES-019, RES-026 |
| hybrid | 21 | RES-003, RES-004, RES-005, RES-006, RES-007, RES-008, RES-009, RES-010a, RES-010b, RES-010c, RES-013, RES-014, RES-015, RES-018, RES-021 (1st), RES-023 (1st), RES-024 (1st), RES-020 (2nd), RES-021 (2nd), RES-023 (2nd), RES-024 (2nd) |
| semantic | 17 | RES-001, RES-001a, RES-002a, RES-004a, RES-004b, RES-006a, RES-010, RES-011, RES-012, RES-016, RES-017, RES-020 (1st), RES-020a, RES-022 (1st), RES-022 (2nd), RES-025 (1st), RES-025 (2nd) |

Total 45.

Density observation: research-process is dominated by **hybrid** (template prefilter + AI judgment) and **semantic** (intent / scope / framing) classes; only 7 of 45 are purely mechanical, and they cluster around document-physical-shape rules (location, metadata, naming, index, citation tags, internal-grep). The skill is process-shaped: it tells the author *what to do* in editorial work, not *what artifact must exist*. The duplicate-numbered IDs (`[RES-020]`, `[RES-021]`, `[RES-022]`, `[RES-023]`, `[RES-024]`, `[RES-025]`) appear twice in the source: the lower-line-number block defines the original tiered-rigor rules, the higher-line-number block defines newer rules added without renumbering — both walked above with file:line disambiguators. This duplication is itself a corpus-health observation worth flagging but is out of scope for the classification task.

---

### Part 6 — handoff (`Skills/handoff/SKILL.md`)

Verified against `SKILL.md` (1294 lines, last_reviewed 2026-04-30). All 43 requirement IDs walked.

#### 6.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[HANDOFF-001]` | Invocation | **mechanical** | Predicate: `/handoff` parsing — empty args → sequential, `investigate <topic>` → branching; output filename derives mechanically from arg shape. | handoff/SKILL.md:32 |
| `[HANDOFF-002]` | Sequential Procedure | **hybrid** | Prefilter: detect HANDOFF.md exists at working-dir root and contains the mandated sections; AI verifies steps were followed (gather facts → check existing → fill template → write → report). | handoff/SKILL.md:51 |
| `[HANDOFF-004]` | Sequential Template | **mechanical** | Predicate: regex match the mandatory sections (Goal, Current State, Next Steps) as H2 headers, plus the resume-blockquote at top, plus auto-populated Changed Files when git diff shows changes; conditional sections present iff content. | handoff/SKILL.md:80 |
| `[HANDOFF-003]` | Branching Procedure | **hybrid** | Prefilter: detect `HANDOFF-{topic}.md` filename + presence of mandatory sections; AI verifies the topic kebab-cased and Do-Not-Touch was auto-populated from `git status -s`. | handoff/SKILL.md:142 |
| `[HANDOFF-005]` | Branching Template | **mechanical** | Predicate: regex match all branching mandatory sections (Issue, Parent Context, Relevant Files, Do Not Touch, Scope, Findings Destination); resume-blockquote at top. | handoff/SKILL.md:166 |
| `[HANDOFF-006]` | Auto-Population | **mechanical** | Predicate: compare HANDOFF.md "Changed Files" section against `git diff --stat` + `git status -s` output at write-time; compare Do-Not-Touch against `git status -s`. Mismatch = violation. | handoff/SKILL.md:201 |
| `[HANDOFF-007]` | Token Budget | **mechanical** | Predicate: token-count the file; sequential 500–1500 target / 2000 max, branching 200–500 / 800 max. Numeric thresholds are deterministic. | handoff/SKILL.md:214 |
| `[HANDOFF-008]` | File Location and Naming | **mechanical** | Predicate: filename regex (`HANDOFF.md` or `HANDOFF-{kebab}.md`) at working-directory root; uppercase prefix mandatory. | handoff/SKILL.md:233 |
| `[HANDOFF-009]` | Progressive Capture | **hybrid** | Prefilter: detect HANDOFF.md exists across consecutive `/handoff` invocations; AI verifies the update preserved Goal, refreshed Changed Files, and didn't drop prior decisions/dead-ends. | handoff/SKILL.md:248 |
| `[HANDOFF-010]` | Resume Protocol | **semantic** | Predicate: did the resuming agent verify state before acting, confirm understanding to the user, begin from Next Steps, and (when supervisor block present) stamp verification status? Each step is testimony-based across the resuming session's transcript. **Composite:** five sub-procedures bound under one rule. | handoff/SKILL.md:263 |
| `[HANDOFF-011]` | Copy-Pastable Resumption Prompt | **mechanical** | Predicate: regex check the report contains a fenced code block beginning with the literal prefix `for the next task, find the relevant skills and load them first. then execute the task. task:`, with absolute path to the handoff file inline. | handoff/SKILL.md:277 |
| `[HANDOFF-013]` | Prior Research Check for Branching Investigations | **mechanical** | Predicate: at write-time, the agent ran `ls Research/` + `grep -r "<topic-keyword>" Research/` and the new doc cites any matched prior doc OR explicitly explains supersession/non-applicability. The grep is reproducible; citation presence is regex-checkable. | handoff/SKILL.md:308 |
| `[HANDOFF-014]` | Pre-Existing Code in Scope | **hybrid** | Prefilter: regex for `## Pre-Existing Code in Scope` section presence in sequential handoffs whose Goal/Next-Steps imply broader refactor; AI judges whether the per-file treatment labels (Preserved/Refactored/Deleted/Moved) are correct vs the actual investigation scope. | handoff/SKILL.md:348 |
| `[HANDOFF-015]` | Audit Handoff Naming | **mechanical** | Predicate: filename regex — audit-purpose handoffs use `AUDIT-{topic}.md`, task handoffs use `HANDOFF-{topic}.md` or `HANDOFF.md`. Decision-table is deterministic given the artifact's purpose. | handoff/SKILL.md:392 |
| `[HANDOFF-017]` | Terminal Consumer Migration for Multi-Finding Audit Cycles | **semantic** | Predicate: judging when N findings affecting one/few consumer packages "should bundle" requires reading the audit's structure and consumer overlap. **Routing:** decision-table on bundling. | handoff/SKILL.md:422 |
| `[HANDOFF-018]` | Opt-Out Clauses Are Preferences, Not Permissions | **semantic** | Predicate: did the implementer read an opt-out as preference (intent class) vs literal-trigger permission? Pure intent-based rule about reading discipline; mechanical detection is impossible. | handoff/SKILL.md:444 |
| `[HANDOFF-019]` | Commit-as-you-go for Multi-Phase Multi-Repo Refactors | **hybrid** | Prefilter: detect handoffs with ≥3 phases × ≥2 repos in Next Steps (regex Phase 1 / Phase 2 / Phase 3 + repo enumeration); AI verifies per-phase commits actually landed via `git log` per repo. | handoff/SKILL.md:464 |
| `[HANDOFF-020]` | Correction-Cycle Handoffs (Sequential with Inherited Context) | **hybrid** | Prefilter: regex for the `## Inherited from Prior Cycle` section + sub-sections (Key Decisions to Carry Forward, Dead Ends to Avoid, Expected Divergences); AI verifies that carried-forward items truly generalize and that expected divergences are evidence-based. | handoff/SKILL.md:480 |
| `[HANDOFF-016]` | Handoff Staleness Axes | **semantic** | Predicate: detecting work / proposal / premise / scope-flag / live-revisions / transcription / internal-contradiction staleness requires reading the handoff against current state. **Composite:** seven sub-axes each with its own check; each requires editorial scope judgment, not regex. | handoff/SKILL.md:511 |
| `[HANDOFF-013a]` | Writer-Side Prior-Research Grep | **mechanical** | Predicate: at write-time, the writer ran `grep -r "<topic-keyword>" {target-package}/Research/` + ecosystem-wide grep; new prescription cites any matched prior doc OR explicitly explains non-applicability. Reproducible. | handoff/SKILL.md:575 |
| `[HANDOFF-013b]` | Build-Level Visibility Pre-Flight for Deletion-Without-Adoption | **mechanical** | Predicate: for deletion-without-adoption handoffs, `grep -l "public import {DeclaringModule}" {consumer-file}` per consumer site; consumer files lacking the explicit import → plan MUST add it before deletion. | handoff/SKILL.md:604 |
| `[HANDOFF-012]` | Supervisor Block (Optional) | **semantic** | Predicate: judging when a handoff carries "non-obvious constraints" warranting a supervisor block. **Routing:** decision-table on when MUST/SHOULD/MAY/SHOULD-NOT include the block. | handoff/SKILL.md:641 |
| `[HANDOFF-021]` | Scope Enumeration at Write-Time | **mechanical** | Predicate: regex for "apply X to every Y" handoffs; check that the body includes (a) the exact grep/detection command and (b) its pasted output. The command + output presence is grep-checkable. | handoff/SKILL.md:676 |
| `[HANDOFF-022]` | Do-Not-Touch vs Phase-Scope Conflict | **mechanical** | Predicate: at execution time, the subordinate ran a grep of derived phase-scope files against `## Do Not Touch` entries and surfaced any intersection before writing. Reproducible cross-grep. | handoff/SKILL.md:692 |
| `[HANDOFF-023]` | Bulk-Push Authorization Class | **mechanical** | Predicate: at handoff-write time, run `for r in <repos>; do git -C "$r" rev-list @{u}..HEAD \| wc -l; done`; if ≥10 commits across ≥3 repos, surface in Next Steps. Threshold is numeric, enumeration reproducible. | handoff/SKILL.md:712 |
| `[HANDOFF-024]` | Empirical-Grep-First at Scope-Expansion Blockers | **mechanical** | Predicate: at any phase-N "more files than anticipated" blocker, the next response includes a grep enumeration of true scope; output pasted into Findings/Next-Steps. Reproducibility check. | handoff/SKILL.md:728 |
| `[HANDOFF-025]` | Anti-Defer Rule for Cheap Verifications | **hybrid** | Prefilter: detect `(verify)` / "flag for follow-up" markers in findings tables; AI judges whether each marker's verification target is in the ≤30s class (`gh repo view`, `grep -l`, etc.) — those MUST have been resolved at write-time. | handoff/SKILL.md:750 |
| `[HANDOFF-026]` | Preserved-File Compile-Verification Sub-Requirement | **mechanical** | Predicate: for each Preserved file in `## Pre-Existing Code in Scope`, grep for any Moved/Deleted type name; any hit = defect. Fully deterministic given the type list and file list. | handoff/SKILL.md:771 |
| `[HANDOFF-027]` | Dead-Ends / Next-Steps Writer-Side Cross-Check | **semantic** | Predicate: judging whether a Next-Steps prescription's "shape-class" matches a Dead-Ends refuted pattern requires structural pattern recognition (ownership shape, generic instantiation shape, language-feature reliance) that cannot be reduced to regex. | handoff/SKILL.md:795 |
| `[HANDOFF-028]` | (Reserved) | **mechanical** | Predicate: assert no rule body uses `[HANDOFF-028]` ID; the slot is held empty. **Reference (anchor):** numbering-gap holder, retention prevents silent collision. | handoff/SKILL.md:815 |
| `[HANDOFF-029]` | Pre-Fire Precondition Re-Check for Bulk Operations | **mechanical** | Predicate: subordinate re-runs the same precondition command immediately before bulk operation fires; commits/output diff against the authorization-time snapshot. Reproducible re-run. | handoff/SKILL.md:823 |
| `[HANDOFF-030]` | Cost-Calculus Base-Rate Requirement | **semantic** | Predicate: judging whether each side of a cost-calculus argument names its driving event and base-rate frequency requires reading the argument. **Routing:** writer-side discipline check. | handoff/SKILL.md:841 |
| `[HANDOFF-024a]` | Linux Baseline Pre-Flight — Mandatory-to-Run, Conditional-on-Fix | **mechanical** | Predicate: run `cd {pkg} && docker run --rm -v $(pwd):/work -w /work swift:6.3 swift build --build-tests`; capture clean/red; if red → prereq commit required. Procedure is fully deterministic. | handoff/SKILL.md:859 |
| `[HANDOFF-031]` | Syntactic-vs-Semantic Disclaimer for Regex Enumerations | **semantic** | Predicate: judging whether a regex's match-set "plausibly exceeds" the brief's intended semantic scope requires understanding the brief's intent — purely intent-based. | handoff/SKILL.md:897 |
| `[HANDOFF-032]` | Extraction-Time Material Check (Writer-Side Prior-Research, Generalized) | **mechanical** | Predicate: at extract-then-delete Phase 4, run `grep -rn "<keyword>" swift-institute/Research/ swift-institute/Audits/ {pkg}/Research/ Skills/<skill>/SKILL.md`; if material is captured (verified by reading matched section), disposition downgrades to delete. Reproducible. | handoff/SKILL.md:935 |
| `[HANDOFF-033]` | L1-API-Change Cascade Disclosure | **hybrid** | Prefilter: detect L1-API-change handoffs (regex on `### [API-*]` references); verify Changed Files OR `## Cascading Migrations` section enumerates downstream consumer files; AI judges completeness against actual consumer graph. | handoff/SKILL.md:984 |
| `[HANDOFF-034]` | Consumer Migration Bundling Anti-Pattern | **semantic** | Predicate: judging whether a consumer-migration commit covers ONLY this upstream's API surface vs spans multiple upstreams in flight requires editorial scope judgment. **Routing:** decision-table on bundling vs extracting. | handoff/SKILL.md:1006 |
| `[HANDOFF-035]` | Cascade-Migration Termination Criteria | **mechanical** | Predicate: at cascade end, (a) workspace-wide grep across all sibling org-level dirs and (b) `swift build --build-tests` on every transitive consumer repo; both reproducible. | handoff/SKILL.md:1034 |
| `[HANDOFF-036]` | Recipe-and-Path-Math Empirical Verification | **mechanical** | Predicate: scratch-repo execution of every command sequence + `python3 -c "import os; print(os.path.normpath('...'))"` for path-math claims. Reproducible. | handoff/SKILL.md:1069 |
| `[HANDOFF-037]` | Probe-List vs Do-Not-Touch Internal Contradiction (Sixth Staleness Axis) | **mechanical** | Predicate: at resume time, cross-grep the probe list / scope items against `## Do Not Touch` entries; non-empty intersection → flag. Reproducible. | handoff/SKILL.md:1096 |
| `[HANDOFF-038]` | HANDOFF Staleness Threshold | **mechanical** | Predicate: `find . -maxdepth 1 -name "HANDOFF*.md" -mtime +14`; ages 14–28 SHOULD triage, >28 MUST triage. Pure mtime + name predicate. | handoff/SKILL.md:1118 |
| `[HANDOFF-039]` | Predecessor Retirement at Dispatch | **hybrid** | Prefilter: detect new HANDOFF dispatched at workspace root + sibling HANDOFF-*.md files exist; verify new HANDOFF carries `## Predecessors Retired` section enumerating each candidate's disposition. AI judges whether each "no-predecessor" classification is correct. | handoff/SKILL.md:1162 |
| `[HANDOFF-040]` | Generic-Instantiated Forms in Cascade-Migration Grep Patterns | **mechanical** | Predicate: cascade-migration scope-enumeration commands MUST include both literal regex AND generic-instantiated regex (`Type<[^>]*>\.Member`); termination grep at end-of-cascade likewise. Pattern-presence check is grep-checkable. | handoff/SKILL.md:1241 |

#### 6.2 handoff distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 25 | HANDOFF-001, HANDOFF-004, HANDOFF-005, HANDOFF-006, HANDOFF-007, HANDOFF-008, HANDOFF-011, HANDOFF-013, HANDOFF-013a, HANDOFF-013b, HANDOFF-015, HANDOFF-021, HANDOFF-022, HANDOFF-023, HANDOFF-024, HANDOFF-024a, HANDOFF-026, HANDOFF-028, HANDOFF-029, HANDOFF-032, HANDOFF-035, HANDOFF-036, HANDOFF-037, HANDOFF-038, HANDOFF-040 |
| hybrid | 9 | HANDOFF-002, HANDOFF-003, HANDOFF-009, HANDOFF-014, HANDOFF-019, HANDOFF-020, HANDOFF-025, HANDOFF-033, HANDOFF-039 |
| semantic | 9 | HANDOFF-010, HANDOFF-012, HANDOFF-016, HANDOFF-017, HANDOFF-018, HANDOFF-027, HANDOFF-030, HANDOFF-031, HANDOFF-034 |

Total 43.

Density observation: handoff is the most mechanically verifiable of the three (~58% mechanical), reflecting its file-shape orientation — handoffs are *artifacts* with mandatory sections, naming patterns, age thresholds, and reproducible enumeration commands. The semantic residue clusters around staleness-axis judgment, opt-out reading, supervisor-block routing, and writer-side discipline rules where intent must be reconstructed from prose. γ-roadmap inline citations on this skill were stripped during synthesis as force-fits — file-shape and writer-side-grep rules do not match v1.2.0 §3.4.10's active γ classes (γ-3 is target-fidelity, γ-2 is CI-side scan); they are candidates for a future γ-class extension. See §28 latent-γ discussion.

---

### Part 7 — skill-lifecycle (`Skills/skill-lifecycle/SKILL.md`)

Verified against `SKILL.md` (774 lines, last_reviewed 2026-04-24). All 30 real requirement IDs walked. (Mechanical scan `grep -nE '^### \[' SKILL.md` returns 32 hits; two of them — line 145 `### [{ID-PREFIX}-001]` and line 167 `### [{ID-PREFIX}-002]` — are template-literal placeholders embedded inside `[SKILL-CREATE-005]`'s example block, not classifiable rules. Walking only the 30 real rules.)

#### 7.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[SKILL-CREATE-001]` | Planning Requirements | **semantic** | Predicate: judging whether the four planning decisions (purpose, layer, ID prefix, dependencies) were genuinely made vs. backfilled requires reading authorial intent. **Routing:** four-decision pre-write checklist. | skill-lifecycle/SKILL.md:28 |
| `[SKILL-CREATE-002]` | Layer Classification | **mechanical** | Predicate: regex match `layer:` field in YAML against the canonical four-value enum (`meta`, `architecture`, `implementation`, `process`); assert exactly one. | skill-lifecycle/SKILL.md:43 |
| `[SKILL-CREATE-003]` | Requirement ID Assignment | **mechanical** | Predicate: extract every `[PREFIX-NUMBER]` ID from the skill; assert prefix matches the format and is unique against the swift-institute-core canonical Skill Index list. **External:** uniqueness verification requires fetching the Skill Index. | skill-lifecycle/SKILL.md:58 |
| `[SKILL-CREATE-004]` | Dependency Declaration | **mechanical** | Predicate: parse `requires:` field; assert each named skill exists at `Skills/<name>/SKILL.md`; build the dependency DAG and assert acyclicity. Fully deterministic. | skill-lifecycle/SKILL.md:68 |
| `[SKILL-CREATE-005]` | SKILL.md Structure | **mechanical** | Predicate: assert `Skills/<skill-name>/SKILL.md` exists with valid YAML frontmatter (required fields: name, description, layer, requires, applies_to) followed by Markdown rule sections matching the rule template (`### [PREFIX-NNN]` + `**Statement**:`). | skill-lifecycle/SKILL.md:89 |
| `[SKILL-CREATE-005a]` | Multi-File Navigation-Hub Exception | **hybrid** | Prefilter: count rules + sibling files; rules ≥40 + ≥3 semantic clusters + sibling files exist + hub `SKILL.md` carries `## Files` table + `## Rule Index` + foundational axioms; AI verifies the cluster partition is "clean" (clusters genuinely distinct) and that each sibling file reads coherently on its own. | skill-lifecycle/SKILL.md:175 |
| `[SKILL-CREATE-005b]` | SPLIT File Boundary Selection | **semantic** | Predicate: judging whether a SPLIT respected narrative-cluster boundaries vs. fragmented clusters via pure ID-prefix partition requires reading the existing skill's narrative flow and the resulting siblings' coherence. | skill-lifecycle/SKILL.md:205 |
| `[SKILL-CREATE-006]` | Requirement Content | **hybrid** | Prefilter: regex check each `### [PREFIX-NNN]` rule contains `**Statement**:` block + (for implementation-layer skills) code-example blocks + Rationale; AI verifies the Statement uses MUST/SHOULD/MAY language correctly. | skill-lifecycle/SKILL.md:238 |
| `[SKILL-CREATE-006a]` | Internal Consistency Pass | **semantic** | Predicate: the four checks (cross-reference range correctness, terminology collisions, ID divergence between research draft and shipped skill, ghost references) all require coherent-whole reading and editorial judgment. **Composite:** four sub-checks bound under one rule. | skill-lifecycle/SKILL.md:258 |
| `[SKILL-CREATE-007]` | swift-institute-core Updates | **mechanical** | Predicate: after a new skill is created, `swift-institute-core/SKILL.md` Skill Index MUST contain a row for the new skill matching its layer + ID prefix. Grep-checkable. | skill-lifecycle/SKILL.md:288 |
| `[SKILL-CREATE-008]` | Registry and Repo-CLAUDE.md Updates | **mechanical** | Predicate: same as above plus optional grep of `swift-{primitives,standards,foundations}/CLAUDE.md` for the new skill if it's mandatory in those repos. Reproducible. | skill-lifecycle/SKILL.md:305 |
| `[SKILL-CREATE-009]` | Sync Infrastructure | **mechanical** | Predicate: `ls -la .claude/skills/<skill-name>` resolves to `../../Skills/<skill-name>` after `Scripts/sync-skills.sh`; symlink committed in git. Reproducible. | skill-lifecycle/SKILL.md:335 |
| `[SKILL-CREATE-010]` | Verification | **mechanical** | Predicate: each verification-checklist item is a deterministic shell test (symlink existence, YAML validity via parser, presence in Skill Index). | skill-lifecycle/SKILL.md:364 |
| `[SKILL-CREATE-011]` | Repo-Specific Skill Pattern | **mechanical** | Predicate: assert repo-specific skills live at `<repo>/Skills/<skill-name>/SKILL.md`, are symlinked from `<repo>/.claude/skills/<skill-name>`, and `applies_to:` targets the specific repo. | skill-lifecycle/SKILL.md:387 |
| `[SKILL-CREATE-012]` | ID-Uniqueness Grep Across All Skill Files Before ID Assignment | **mechanical** | Predicate: at ID-assignment time, run `grep -hE "^### \[<PREFIX>-[0-9]+[a-z]?\]" Skills/<skill>/*.md \| sort -u`; assert chosen ID not present. Reproducible across single-file and multi-file skill structures. | skill-lifecycle/SKILL.md:415 |
| `[SKILL-LIFE-001]` | Minimal Revision Principle | **semantic** | Predicate: judging whether an edit is "the smallest edit that addresses the gap" vs. unnecessary surrounding rewrite is editorial judgment. | skill-lifecycle/SKILL.md:461 |
| `[SKILL-LIFE-005]` | Mechanical `last_reviewed` Drift Check | **mechanical** | Predicate: pre-commit hook / CI script — for each touched `Skills/*/SKILL.md`, compare git mtime vs. `last_reviewed: YYYY-MM-DD`; fail if mtime > last_reviewed + 1 day. Reproducible numeric comparison. | skill-lifecycle/SKILL.md:469 |
| `[SKILL-LIFE-002]` | Update Provenance | **hybrid** | Prefilter: scan commit message / skill diff for a citation to `[REFL-PROC-005]`, `[RES-*]`, or `[EXP-*]` provenance; AI verifies the cited reflection / research / experiment actually exists and matches the change. | skill-lifecycle/SKILL.md:515 |
| `[SKILL-LIFE-003]` | Backward Compatibility Classification | **semantic** | Predicate: judging Additive vs Clarifying vs Breaking requires reading the diff against existing in-repo code that conforms to the prior rule. **Routing:** classification decision-table determining whether explicit discussion is required. | skill-lifecycle/SKILL.md:523 |
| `[SKILL-LIFE-004]` | `last_reviewed` Bump on Substantive Content Edits | **hybrid** | Prefilter: detect commit touching `Skills/*/SKILL.md` body; verify the same commit's diff includes a `last_reviewed:` bump. AI judges substantive vs non-substantive (typo / formatting / re-numbering) when prefilter is ambiguous. | skill-lifecycle/SKILL.md:537 |
| `[SKILL-LIFE-010]` | Review Triggers | **mechanical** | Predicate: scan git log for `Skills/*/SKILL.md` update count in last 30 days (≥3 → trigger); cross-check `[META-020]` staleness flag; compare `last_reviewed` against `[SKILL-LIFE-012]` cadence. Each branch is deterministic. | skill-lifecycle/SKILL.md:565 |
| `[SKILL-LIFE-011]` | Review Procedure | **hybrid** | Prefilter: detect a "review pass" commit + check that all five steps (verify against code, check cross-references, check absorption candidates, verify PIC, update `last_reviewed`) appear in the diff/commit body; AI verifies each step performed substantively. | skill-lifecycle/SKILL.md:575 |
| `[SKILL-LIFE-012]` | Review Cadence | **mechanical** | Predicate: per-layer cadence (Implementation 90d, Process 180d, Architecture 180d, Meta on-demand) + `last_reviewed` set to creation date for new skills + optional `created:` field. Numeric thresholds against frontmatter dates. | skill-lifecycle/SKILL.md:587 |
| `[SKILL-LIFE-020]` | Deprecation Protocol | **mechanical** | Predicate: deprecated skill MUST have `superseded_by:` in YAML, body matches the redirect-notice pattern, directory remains for 90 days then is removed. Reproducible age + content checks. | skill-lifecycle/SKILL.md:604 |
| `[SKILL-LIFE-021]` | Absorption Criteria | **hybrid** | Prefilter: line-count check (A < 200 lines), co-load detection (loaded together in 100% of use cases — requires session-history mining), proper-subset check, no-independent-consumers check; AI judges whether A's requirements are "conceptually within B's scope." | skill-lifecycle/SKILL.md:615 |
| `[SKILL-LIFE-022]` | Post-Absorption Verification | **mechanical** | Predicate: after absorption, (1) grep B for all of A's rule IDs (each present), (2) grep all skills that referenced A — assert refs updated to B, (3) Skill Index updated, (4) repo-CLAUDE.md updated where present, (5) sync script run. Reproducible. | skill-lifecycle/SKILL.md:630 |
| `[SKILL-LIFE-030]` | Cluster Review Triggers | **mechanical** | Predicate: trigger conditions are each checkable (last cluster member's first review complete, 90 days since cluster assembled, new skill joined, composition defect surfaced — first three are timestamp/git-log; fourth requires audit findings). The fourth condition makes this hybrid in spirit, but the trigger MUST fire when any of the four hold, and the first three are mechanical. **Composite:** four trigger conditions; three mechanical, one defect-driven. | skill-lifecycle/SKILL.md:644 |
| `[SKILL-LIFE-031]` | Cluster Review Procedure | **hybrid** | Prefilter: assert the cluster review was authored via `/audit cluster ...` invocation per [AUDIT-019]; cluster `## Cluster:` section exists in `Audits/audit.md`; severity-batched fix order followed. AI verifies independence (author of any individual cluster skill SHOULD NOT have run the audit) and substantiveness of the batch fixes. | skill-lifecycle/SKILL.md:661 |
| `[SKILL-LIFE-026]` | Reference-Implementation Pattern for Breaking Revisions | **hybrid** | Prefilter: detect breaking revisions per [SKILL-LIFE-003] (commit-level signal); verify a sibling commit / handoff exists rewriting one reference package against the new rules. AI verifies the rewrite is coherent and stress-tests the revision. | skill-lifecycle/SKILL.md:732 |
| `[SKILL-LIFE-027]` | Citation-Ahead-of-Landing Warning | **mechanical** | Predicate: extract every artifact citation from skill text (script paths, research doc paths, reference-implementation paths); assert each cited path exists at the workspace OR the citation is wrapped in aspirational-tense markers ("Aspirational — pending HANDOFF-...md", "future Research/...md"). Grep-checkable. | skill-lifecycle/SKILL.md:748 |

#### 7.2 skill-lifecycle distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 17 | SKILL-CREATE-002, SKILL-CREATE-003, SKILL-CREATE-004, SKILL-CREATE-005, SKILL-CREATE-007, SKILL-CREATE-008, SKILL-CREATE-009, SKILL-CREATE-010, SKILL-CREATE-011, SKILL-CREATE-012, SKILL-LIFE-005, SKILL-LIFE-010, SKILL-LIFE-012, SKILL-LIFE-020, SKILL-LIFE-022, SKILL-LIFE-027, SKILL-LIFE-030 |
| hybrid | 8 | SKILL-CREATE-005a, SKILL-CREATE-006, SKILL-LIFE-002, SKILL-LIFE-004, SKILL-LIFE-011, SKILL-LIFE-021, SKILL-LIFE-026, SKILL-LIFE-031 |
| semantic | 5 | SKILL-CREATE-001, SKILL-CREATE-005b, SKILL-CREATE-006a, SKILL-LIFE-001, SKILL-LIFE-003 |

Total 30.

Density observation: skill-lifecycle is the most mechanically verifiable of the three skills (~57% mechanical), reflecting its strong artifact/registry orientation — most rules are about file existence, frontmatter shape, registry rows, symlink presence, age thresholds, and grep-checkable cross-references. The semantic residue is concentrated in three places: planning intent ([SKILL-CREATE-001]), revision discipline ([SKILL-LIFE-001], [SKILL-LIFE-003], [SKILL-CREATE-006a]), and SPLIT-narrative judgment ([SKILL-CREATE-005b]). γ-roadmap inline citations on this skill were stripped during synthesis as force-fits — registry/frontmatter shape rules and writer-side-grep rules do not match v1.2.0 §3.4.10's active γ classes; [SKILL-LIFE-005]'s `last_reviewed` drift hook is a candidate for a future γ-class (skill-lifecycle pre-commit hook family). See §28 latent-γ discussion.

---

### Part 8 — experiment-process (`Skills/experiment-process/SKILL.md`)

Verified against `SKILL.md` (807 lines, last_reviewed 2026-04-30). All 40 requirement IDs walked.

#### 8.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[EXP-001]` | Investigation Triggers | **semantic** | Predicate: AI judges whether a technical claim cannot be verified without executing code, vs being answerable from documentation. **Routing:** decision-tree mapping {category} → {action}; classification is at-keyboard authorial judgment. | experiment-process/SKILL.md:44 |
| `[EXP-004]` | Reduction Methodology | **hybrid** | Prefilter: detect reduction-related diffs (file shrink, removed imports/types). AI closes verdict on whether each removal is a verified-clean-build step and whether the minimum-shape criterion holds. **Composite:** combines reduction procedure + build-verification anti-stale-cache rule. | experiment-process/SKILL.md:61 |
| `[EXP-004a]` | Incremental Construction Methodology | **semantic** | Predicate: AI judges whether complexity is being added incrementally (one feature at a time) vs in a leap; only AI can name the "candidate set" of factors. | experiment-process/SKILL.md:83 |
| `[EXP-011]` | Experiment-First Debugging | **semantic** | Predicate: AI judges sequencing — was an isolated experiment created BEFORE production debugging? Production-vs-experiment delta-comparison requires intent reading. | experiment-process/SKILL.md:95 |
| `[EXP-011a]` | First Clean Signal Is The Result | **semantic** | Predicate: AI judges whether V2 tests "the same hypothesis with more pressure" vs "a different hypothesis"; this is conceptual hypothesis-equivalence, not surface-level. | experiment-process/SKILL.md:107 |
| `[EXP-018]` | Experiment Consolidation | **hybrid** | Prefilter: count related experiments under a topic (≥5 trigger). AI judges thematic coherence + categorization. **Composite:** count threshold + 5-step procedure + standalone-vs-context-sensitive sub-judgment. | experiment-process/SKILL.md:142 |
| `[EXP-002]` | Package Location Convention | **mechanical** | Predicate: regex/find — every `Experiments/` directory MUST sit at one of two valid paths: `swift-institute/Experiments/` or `<pkg>/Experiments/`; layer-level containers (`swift-{primitives,standards,foundations}/Experiments/`) MUST NOT exist. Path enumeration is binary. | experiment-process/SKILL.md:168 |
| `[EXP-002a]` | Experiment Triage | **semantic** | Predicate: AI maps experiment scope to repo home; requires reading the experiment's Package.swift deps + intent. **Routing:** 4-row decision-tree on experiment shape → repo. | experiment-process/SKILL.md:197 |
| `[EXP-002b]` | Package Isolation | **mechanical** | Predicate: shell — every experiment dir contains its own Package.swift; parent Package.swift MUST NOT reference experiments as targets/products/deps. | experiment-process/SKILL.md:222 |
| `[EXP-003]` | Minimal Package Structure | **hybrid** | Prefilter: list files in experiment dir (Package.swift + Sources/ only). AI closes verdict on whether each present file is "needed to verify the behavior". | experiment-process/SKILL.md:230 |
| `[EXP-003a]` | Package.swift Template | **mechanical** | Predicate: AST/grep — Package.swift specifies `swift-tools-version: 6.3` AND `platforms: [.macOS(.v26)]`; only test-relevant swiftSettings present. | experiment-process/SKILL.md:245 |
| `[EXP-003b]` | main.swift Template | **mechanical** | Predicate: regex on first comment block — header MUST contain `Purpose:`, `Hypothesis:`, `Toolchain:`, `Platform:`, `Result:`, `Date:` lines. | experiment-process/SKILL.md:271 |
| `[EXP-003c]` | Output Artifacts | **hybrid** | Prefilter: detect committed `Outputs/` directory + filenames against canonical set. AI judges whether commit was justified (header excerpt insufficient). | experiment-process/SKILL.md:297 |
| `[EXP-003d]` | Naming Alignment | **mechanical** | Predicate: AST/regex — directory basename == `Package(name:)` arg == `.executableTarget(name:)` arg. | experiment-process/SKILL.md:305 |
| `[EXP-003e]` | Experiment Index | **mechanical** | Predicate: schema-validate — when `Experiments/` has ≥2 dirs, `_index.json` exists with required fields and conforms to canonical schema URL; status enum is closed-set; layer-level `_index.json` MUST NOT exist. **External:** schema URL `https://swift-institute.org/schemas/experiments-index-v1.json`. **Composite:** existence + schema + canonical enum + forbidden-location triple. | experiment-process/SKILL.md:313 |
| `[EXP-005]` | Execution Protocol | **mechanical** | Predicate: shell — build commands match the canonical recipe (`swift package clean`, `swift build`, `swift build -c release`, `swift run` piped through `tee Outputs/{file}.txt`). | experiment-process/SKILL.md:340 |
| `[EXP-006]` | Result Documentation | **hybrid** | Prefilter: regex-match `// Result:` line against canonical outcome enum + revalidation verdict enum (`PASSES | STILL PRESENT | STILL CRASHES | FIXED`). AI closes verdict on REFUTED diagnostic adequacy + FIXED-special-handling. **Composite:** canonical-enum check + revalidation-line shape + cross-skill memory-update sub-rule. | experiment-process/SKILL.md:359 |
| `[EXP-006a]` | Documentation Promotion | **semantic** | Predicate: AI judges when results "affect Swift Institute packages" enough to warrant promotion; requires intent reading. | experiment-process/SKILL.md:389 |
| `[EXP-006b]` | Confirmation Evidence | **mechanical** | Predicate: regex — `Result: CONFIRMED` MUST be accompanied by at least one of `// Output:`, `// Time:`, `// Build Succeeded` (or equivalent canonical evidence line). | experiment-process/SKILL.md:397 |
| `[EXP-006c]` | FIXED-Verdict Retention | **hybrid** | Prefilter: scan `_index.json` for `status: "FIXED"` entries; check none have been pruned. AI judges revalidation cadence + statusDetail/statusRaw correctness. **Composite:** retention rule + index-signaling shape + revalidation cadence. | experiment-process/SKILL.md:405 |
| `[EXP-007a]` | Header Anchor Requirement | **mechanical** | Predicate: regex — every experiment's main.swift MUST contain at least one line matching `^//[[:space:]]+(Toolchain\|Status\|Result\|Revalidated):`. | experiment-process/SKILL.md:426 |
| `[EXP-002c]` | Placement by Highest-Layer Dependency | **hybrid** | Prefilter: parse Package.swift dep list, resolve each dep's layer, pick highest. AI closes verdict on cross-tier ambiguities ("clear domain owner") and standalone-vs-package classification. **Routing:** 6-row decision-tree on experiment shape. | experiment-process/SKILL.md:455 |
| `[EXP-007]` | Toolchain Specification | **mechanical** | Predicate: regex — `// Toolchain:` line present; if `swift-DEVELOPMENT-SNAPSHOT-...`, snapshot date MUST be included. | experiment-process/SKILL.md:512 |
| `[EXP-008]` | Experiment Package Lifecycle | **semantic** | Predicate: AI judges lifecycle stage (Active/Documented/Referenced/Superseded/Archived) and whether superseded-header-note is present and adequate. | experiment-process/SKILL.md:526 |
| `[EXP-009]` | Multi-Variant Testing | **hybrid** | Prefilter: detect multiple `// MARK: - Variant N:` sections + per-variant `// Result:` lines + summary block. AI closes verdict on variant-delimitation quality. | experiment-process/SKILL.md:536 |
| `[EXP-010]` | Common Experiment Patterns | **semantic** | Predicate: AI judges template selection (template fit to experiment intent). **Reference (anchor):** umbrella that anchors [EXP-010a-d]; not directly verifiable on its own. | experiment-process/SKILL.md:564 |
| `[EXP-010a]` | Feature Availability Test | **hybrid** | Prefilter: detect "Does {feature} compile..." purpose-line shape + minimal code + build command. AI closes verdict on minimality. **Reference (anchor):** template, instantiates [EXP-010]. | experiment-process/SKILL.md:572 |
| `[EXP-010b]` | Runtime Behavior Test | **hybrid** | Prefilter: detect explicit `print("Input: ...")` + `print("Output: ...")` + run command + expected/actual lines. AI closes verdict on coverage. **Reference (anchor):** template. | experiment-process/SKILL.md:578 |
| `[EXP-010c]` | Error Message Discovery | **hybrid** | Prefilter: detect intentionally-invalid code + build command + verbatim diagnostic text capture. AI closes verdict on whether diagnostic is captured verbatim. **Reference (anchor):** template. | experiment-process/SKILL.md:584 |
| `[EXP-010d]` | Configuration Comparison | **hybrid** | Prefilter: detect both `swift build -c debug` and `-c release` runs + per-config result lines + difference enumeration. AI closes verdict on adequacy of difference-narrative. **Reference (anchor):** template. | experiment-process/SKILL.md:590 |
| `[EXP-012]` | Discovery Triggers | **semantic** | Predicate: AI judges whether proactive verification would increase confidence; mapping {category} → priority is at-keyboard. **Routing:** 7-row category→priority decision-tree. | experiment-process/SKILL.md:600 |
| `[EXP-013]` | Package Audit Methodology | **hybrid** | Prefilter: detect 7-step audit artifacts (inventory, [CLAIM-XXX]/[ASSUMP-XXX] IDs, P0/P1/P2 priority labels). AI closes verdict on prioritization quality. **Composite:** 7-step procedure + ID-scheme + risk × importance ranking. | experiment-process/SKILL.md:620 |
| `[EXP-014]` | Assumption Inventory | **semantic** | Predicate: AI extracts implicit assumptions from code patterns (`consuming func`, optional returns, `@unchecked Sendable`); requires interpretive reading. | experiment-process/SKILL.md:630 |
| `[EXP-015]` | Claim Verification | **semantic** | Predicate: AI maps claim category → verification method (Complexity → benchmark, Conformance → compile-time, etc.); requires reading the claim's intent. **Routing:** 5-row category→method decision-tree. | experiment-process/SKILL.md:640 |
| `[EXP-016]` | Boundary Exploration | **semantic** | Predicate: AI enumerates boundary classes relevant to a target (empty states, type extremes, overflow, error paths) per type/feature shape — no closed-set algorithm produces this. | experiment-process/SKILL.md:656 |
| `[EXP-019]` | Improvement Discovery | **hybrid** | Prefilter: detect baseline-vs-proposed benchmark pair + 4-row evidence→decision table application. AI judges "significance" vs "marginal" vs regression. | experiment-process/SKILL.md:666 |
| `[EXP-017]` | Release-Mode + Cross-Module Validation for Adoption Experiments | **mechanical** | Predicate: shell — for adoption-type experiments, presence of both `release-mode-pass.txt` AND `cross-module-pass.txt` receipt files; only after both pass may status be CONFIRMED. **Composite:** dual-file existence + status-gate rule. | experiment-process/SKILL.md:683 |
| `[EXP-017a]` | Matrix Disambiguation for #if-Gated Probes | **hybrid** | Prefilter: detect `#if`-gated mechanism in probe; verify the result-table enumerates `{selected-leg, else-leg}` axis (8-cell minimum 2×2×2). AI closes verdict on leg-disambiguation quality. **Composite:** mechanism-detection + matrix-shape + canonical-restoration. | experiment-process/SKILL.md:706 |
| `[EXP-020]` | Claim Validation Trap — Synthetic-to-Production Extrapolation | **hybrid** | Prefilter: detect cited production-consumer claim + per-target regression-guard test (with `withKnownIssue` wrap if pre-verdict). AI closes verdict on cascade-claim adequacy + walkback procedure. **Composite:** 5-step procedure + walkback shape + status-relabel chain. | experiment-process/SKILL.md:733 |
| `[EXP-021]` | One-Factor-At-A-Time at the Reduction-to-Trigger-Narrowing Boundary | **semantic** | Predicate: AI judges whether the next variant adds exactly ONE structural factor; "structural factor" enumeration is concept-level, not lexical. | experiment-process/SKILL.md:777 |

#### 8.2 experiment-process distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 11 | EXP-002, EXP-002b, EXP-003a, EXP-003b, EXP-003d, EXP-003e, EXP-005, EXP-006b, EXP-007a, EXP-007, EXP-017 |
| hybrid | 16 | EXP-004, EXP-018, EXP-003, EXP-003c, EXP-006, EXP-006c, EXP-002c, EXP-009, EXP-010a, EXP-010b, EXP-010c, EXP-010d, EXP-013, EXP-019, EXP-017a, EXP-020 |
| semantic | 13 | EXP-001, EXP-004a, EXP-011, EXP-011a, EXP-002a, EXP-006a, EXP-008, EXP-010, EXP-012, EXP-014, EXP-015, EXP-016, EXP-021 |

Total 40.

Density observation: experiment-process is a process skill, but many of its rules (Package.swift template, main.swift header, naming alignment, index schema, header anchor) are mechanical because the experiment package format is highly conventionalized. The semantic core sits in the trigger/methodology rules (when to create, when to consolidate, what counts as "the same hypothesis"). Hybrid dominates because most rules pair a deterministic structural prefilter with an AI judgment on adequacy/significance.

---

### Part 9 — supervise (`Skills/supervise/SKILL.md`)

Verified against `SKILL.md` (924 lines, last_reviewed 2026-04-30). All 35 requirement IDs walked. Note: `[SUPER-015]` appears twice — once as the canonical rule body (line 497), once as an empirical-provenance note appendix (line 910). Both occurrences refer to the same rule; the appendix is an annotated note.

#### 9.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[SUPER-001]` | Invocation | **semantic** | Predicate: AI judges whether the situation is pre-dispatch or mid-flight, and whether sub-agent vs new-session subordinate. **Routing:** 2-row trigger table dispatching to [SUPER-002]/[SUPER-016]. | supervise/SKILL.md:36 |
| `[SUPER-001a]` | Distinguishing Supervise from Handoff | **semantic** | Predicate: AI distinguishes ongoing supervision from discrete handoff using a 6-row temporal-shape comparison; requires intent reading. **Reference (anchor):** definitional contrast that other rules cite. | supervise/SKILL.md:60 |
| `[SUPER-002]` | Block Structure | **hybrid** | Prefilter: count enumerated entries in ground-rules block (4–6); regex-match each entry's prefix against `MUST\|MUST NOT\|fact:\|ask:`. AI closes verdict on whether block content fits the four types. | supervise/SKILL.md:81 |
| `[SUPER-002a]` | Scope-Lock Precedes Architecture-Lock | **semantic** | Predicate: AI judges whether scope-boundary questions were confirmed before architectural MUST/MUST NOT entries; ordering inference is at-keyboard authorial. | supervise/SKILL.md:98 |
| `[SUPER-003]` | Mandatory Fields | **mechanical** | Predicate: regex/AST — task description has all four fields (Objective, Output format, Tools/sources, Task boundaries) as named sub-blocks. | supervise/SKILL.md:139 |
| `[SUPER-004]` | Rationale on Forbidden Entries | **mechanical** | Predicate: regex — every `MUST NOT` entry is followed by an indented `(why: …)` sub-field. | supervise/SKILL.md:154 |
| `[SUPER-005]` | Question Classification | **semantic** | Predicate: AI classifies each subordinate question as (a) inside-rules / (b) inside-scope / (c) outside-authority; each classification turns on intent + scope. **Routing:** 3-row class→action dispatch. | supervise/SKILL.md:177 |
| `[SUPER-006]` | Drift Signal Enumeration | **semantic** | Predicate: AI checks each subordinate turn against 7 drift-signal patterns (repeats, re-proposes, expands scope, asks-already-answered, modifies-out-of-bounds, silent decision, omits verification); pattern match is intent-level. **Composite:** 7-signal enumeration + user-authorization qualifier. | supervise/SKILL.md:195 |
| `[SUPER-007]` | Boundary-Triggered Intervention | **semantic** | Predicate: AI enumerates intervention points (file write, question, phase complete, result report) and decides accept/correct/terminate. | supervise/SKILL.md:219 |
| `[SUPER-008]` | No Takeover | **semantic** | Predicate: AI judges whether output was silently rewritten vs rejected-and-redone; requires reading authorship intent. | supervise/SKILL.md:237 |
| `[SUPER-009]` | Acceptance Criteria | **hybrid** | Prefilter: detect enumerated criteria + per-criterion verification-source naming. AI closes verdict on whether each source actually verifies the named property + read-the-artifact discipline. **Composite:** enumeration + 3-row positive-source taxonomy + 2-row forbidden-source taxonomy + read-not-summary. | supervise/SKILL.md:261 |
| `[SUPER-009a]` | Verification Scope Sub-Rule for Acceptance Criteria | **semantic** | Predicate: AI determines what each verification mechanism DOES and DOES NOT verify; partial-vs-full verification classification is interpretive. | supervise/SKILL.md:301 |
| `[SUPER-010]` | Three-Way Termination | **mechanical** | Predicate: shell/regex — termination outcome is exactly one of {Success, Re-handoff, Escalation}, named explicitly; attrition forbidden. **Composite:** 3-mode enumeration + per-mode procedure citation. | supervise/SKILL.md:358 |
| `[SUPER-011]` | Re-Handoff Composition | **hybrid** | Prefilter: regex on HANDOFF.md Constraints — `Supervisor constraints #1–#N: all verified` or per-entry verification phrase. AI closes verdict on whether each entry's verification evidence form fits its type. **Composite:** verification-line shape + 4-row entry-type→evidence-form table + success-stamp requirement. | supervise/SKILL.md:372 |
| `[SUPER-012]` | Escalation Triggers | **hybrid** | Prefilter: regex/path — escalation persisted in HANDOFF.md `## Open Questions` with `[ESCALATED to user, awaiting answer]` prefix, OR `HANDOFF-escalation-{slug}.md` exists. AI closes verdict on which trigger fired. **Composite:** 4-trigger enumeration + 3-row persistence-target table + format requirement. | supervise/SKILL.md:405 |
| `[SUPER-013]` | Re-Injection on Drift | **mechanical** | Predicate: regex — drift-correction message quotes the violated entry verbatim and cites its entry number; bare "don't do that" forbidden. | supervise/SKILL.md:434 |
| `[SUPER-014]` | Block Location | **mechanical** | Predicate: shell/file-existence — block is at one of three canonical locations per subordinate type (sub-agent prompt / HANDOFF.md Constraints / dedicated file referenced therefrom). | supervise/SKILL.md:457 |
| `[SUPER-014a]` | Supervisor in Absentia | **semantic** | Predicate: AI detects absentia state (block on disk, no live principal) and applies degenerate-case re-classification (b)→(c). **Composite:** absentia detection + re-classification + pre-escalation check + restored-supervision rule. | supervise/SKILL.md:471 |
| `[SUPER-015]` | Progressive Refinement | **semantic** | Predicate: AI judges whether class-(b) answers were appended to the block; requires reading conversation history + change. **Composite:** append rule + compression-on-overflow + 6-entry target ratio + pivot-vs-threshold trigger. | supervise/SKILL.md:497 |
| `[SUPER-016]` | End-to-End Procedure | **semantic** | Predicate: AI walks 4-step procedure (author dispatch / dispatch-or-attach / per-intervention-point / terminate) and judges adherence. **Routing:** orchestration of every other [SUPER-*] rule into a procedure. | supervise/SKILL.md:515 |
| `[SUPER-017]` | Tentative-Language Detection at Principal Input | **semantic** | Predicate: AI applies rewrite-test ("I want you to" prepend) and detects exploratory language; requires linguistic intent reading. | supervise/SKILL.md:551 |
| `[SUPER-018]` | Supervisor Re-Reads Skill at Intervention Points | **semantic** | Predicate: AI judges whether supervisor re-loaded relevant skill section at intervention point vs reasoned from memory; meta-cognitive judgment. | supervise/SKILL.md:573 |
| `[SUPER-019]` | Supervisor Objective Hierarchy | **semantic** | Predicate: AI applies hierarchy {coherence > scope-min > speed} to each class-(b) authorization; conflict-resolution is judgment-laden. | supervise/SKILL.md:592 |
| `[SUPER-020]` | Pre-Authorization Architectural-Constraint Scan | **mechanical** | Predicate: shell — three named greps fire before authorization (platform/SKILL.md PLAT-ARCH-*; modularization/SKILL.md MOD-*; feedback memory). **Composite:** triple-grep enumeration + authorization-gate. | supervise/SKILL.md:615 |
| `[SUPER-021]` | Mid-Cycle Principal Decision Revision as Fourth Termination-Avoiding Pattern | **semantic** | Predicate: AI judges whether revision weakens vs strengthens scope; weakening-vs-strengthening classification is interpretive. **Composite:** 3-condition gate + extension to [SUPER-010]. | supervise/SKILL.md:633 |
| `[SUPER-022]` | Per-Intervention-Point Verification | **mechanical** | Predicate: shell — at each intervention point, at least one acceptance criterion / ground-rule entry verified via mechanical command (translatable to shell). **Composite:** per-IP requirement + AC-to-shell translation table + forbidden-source enumeration. | supervise/SKILL.md:651 |
| `[SUPER-023]` | Supervision-Mode Dimension at Invocation | **semantic** | Predicate: AI selects mode (A'/B/C) based on design-decision count + shared-vocabulary load; selection is interpretive. **Routing:** 3-row pattern→use-when. | supervise/SKILL.md:678 |
| `[SUPER-024]` | Ground-Rule Compliance Via Inaction | **semantic** | Predicate: AI determines whether MUST-rule's preconditions are met → execute, or unmet → in-action; meta-rule about rule-application. | supervise/SKILL.md:702 |
| `[SUPER-025]` | Research Gate as First Ground-Rule When Dispatch Rests on Unverified Assumption | **semantic** | Predicate: AI detects whether dispatch rests on incompletely-understood assumption; assumption-detection is interpretive. | supervise/SKILL.md:724 |
| `[SUPER-026]` | Delete-Public-Type Disposition Verification | **mechanical** | Predicate: shell — for each consumer site of a deletion-target type, grep verifies the consumer's source `public import`s the defining module (or transitively does via exports.swift). **Composite:** 3-phase procedure (pre-dispatch grep / pre-authorization import-graph / dispatch authorization) + per-phase verification. | supervise/SKILL.md:738 |
| `[SUPER-027]` | Pre-Dispatch Ecosystem-Constraint Scan | **mechanical** | Predicate: shell — 5-dimension scan (namespace ownership grep / layer-direction Package.swift inspection / dep graph `swift package show-dependencies` / feedback memory grep / Research-doc grep) fires before dispatch authorization. **Composite:** 5-dimension enumeration + per-dimension command + 4-step procedure. | supervise/SKILL.md:764 |
| `[SUPER-028]` | In-Absentia Decision Matrix — Class-(a) Inaction Before Class-(b) Escalation | **semantic** | Predicate: AI applies 2-axis matrix (Classification × Compliance form) to in-absentia questions; routing through [SUPER-024] before [SUPER-014a] is judgment-laden. **Routing:** 2-axis decision-procedure. | supervise/SKILL.md:803 |
| `[SUPER-029]` | Drift Signal Extension — Subordinate-Initiated Plan Restructuring | **semantic** | Predicate: AI detects whether subordinate restructured the plan (collapse/reorder/merge) without surfacing; structural-change detection is intent-level. | supervise/SKILL.md:842 |
| `[SUPER-030]` | Bounded Final-Exchange for Supervisor Review Cycles | **hybrid** | Prefilter: regex — supervisor message has bounded-framing prefix + numbered Q1/Q2/Q3 + word cap + "no further discussion" closer. AI closes verdict on when-to-use and decision-shape adequacy. | supervise/SKILL.md:873 |
| `[SUPER-015]` (appendix) | Empirical-Provenance Note (Compression-at-Pivot) | **semantic** | Predicate: appendix re-iterating the compression-at-pivot worked example for [SUPER-015]; rule body unchanged. **Reference (anchor):** definitional anchor (provenance note for the canonical rule body at line 497). | supervise/SKILL.md:910 |

#### 9.2 supervise distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 9 | SUPER-003, SUPER-004, SUPER-010, SUPER-013, SUPER-014, SUPER-020, SUPER-022, SUPER-026, SUPER-027 |
| hybrid | 5 | SUPER-002, SUPER-009, SUPER-011, SUPER-012, SUPER-030 |
| semantic | 21 | SUPER-001, SUPER-001a, SUPER-002a, SUPER-005, SUPER-006, SUPER-007, SUPER-008, SUPER-009a, SUPER-014a, SUPER-015, SUPER-016, SUPER-017, SUPER-018, SUPER-019, SUPER-021, SUPER-023, SUPER-024, SUPER-025, SUPER-028, SUPER-029, SUPER-015 (appendix) |

Total 35.

Density observation: supervise is dominantly semantic (21/35) because supervision is judgment-bearing — classification of questions, detection of drift, evaluation of intent/scope. The mechanical core (9) sits in the artifact-shape rules (mandatory fields, rationale on MUST NOTs, three-way termination, drift re-injection format, block location, pre-authorization scans, per-IP verification, deletion verification, ecosystem-constraint scan). Hybrid (5) covers rules where a structural prefilter narrows but adequacy still needs AI judgment.

---

### Part 10 — reflections-processing (`Skills/reflections-processing/SKILL.md`)

Verified against `SKILL.md` (561 lines, last_reviewed 2026-04-30). All 18 requirement IDs walked.

#### 10.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[REFL-PROC-001]` | Invocation Triggers | **mechanical** | Predicate: shell — count pending entries in `Research/Reflections/` (≥3 → invoke; mid-implementation → defer); 4-row trigger→action table. | reflections-processing/SKILL.md:46 |
| `[REFL-PROC-002]` | Processing Sequence | **mechanical** | Predicate: shell/git — 7-step sequence per pending entry (read / triage-each-item / execute / mark-processed YAML / update-index / commit / report); ordering oldest-first; deletion forbidden. **Composite:** ordering rule + status-update + persistence rule. | reflections-processing/SKILL.md:67 |
| `[REFL-PROC-002a]` | Newer Takes Priority — Topic-Clustering Pre-Pass | **semantic** | Predicate: AI clusters entries by topic, identifies supersession, marks superseded items NoAction; supersession detection is interpretive. **Routing:** 5-step pre-pass procedure + 5-row supersession-signal table. | reflections-processing/SKILL.md:89 |
| `[REFL-PROC-003]` | Triage Outcomes | **hybrid** | Prefilter: regex — every action item has exactly one of `[skill\|doc\|research\|experiment\|blog\|package]` tag → primary-outcome dispatch table. AI closes verdict on override rules + miscategorization. **Routing:** 6-row tag→outcome→destination table + override rules. | reflections-processing/SKILL.md:125 |
| `[REFL-PROC-004]` | Triage Validation | **semantic** | Predicate: AI applies 7-row validation checklist (Staleness, Supersession, Duplication, Consistency, Scope, Specificity, Generality) to each triage outcome; each check is interpretive. **Composite:** 7-check enumeration + Meta-Reflection-Trap rule. | reflections-processing/SKILL.md:151 |
| `[REFL-PROC-005]` | SkillUpdate Execution | **semantic** | Predicate: AI executes 10-step skill-lifecycle procedure (read / verify-current-code / identify-requirement / generalize / apply-minimal-revision / verify-consistency / classify-change / breaking-flag / new-ID-assign / provenance); each step requires AI judgment on adequacy. | reflections-processing/SKILL.md:175 |
| `[REFL-PROC-005a]` | Generalization Requirement | **semantic** | Predicate: AI applies the remove-provenance test ("does the rule still make sense?") to determine generalization adequacy; removing-incident-and-still-readable is interpretive. **Composite:** test + 3-row finding→principle table + 4-part well-generalized-rule structure. | reflections-processing/SKILL.md:214 |
| `[REFL-PROC-006]` | DocImprovement Execution | **semantic** | Predicate: AI executes 6-step doc-improvement procedure (read / identify-section / voice-transform / structural-match / expand / dedup-verify); voice-transformation and structural-match are interpretive. **Composite:** 6-step procedure + 3-row reflective→normative voice-transform table. | reflections-processing/SKILL.md:240 |
| `[REFL-PROC-007]` | ResearchTopic Execution | **hybrid** | Prefilter: shell — research doc created in `Research/` per [RES-003] template, with status IN_PROGRESS, indexed in `Research/_index.json`, cross-referencing source reflection. AI closes verdict on tier classification (1/2/3) per [RES-020]. | reflections-processing/SKILL.md:265 |
| `[REFL-PROC-008]` | Expansion Requirement | **semantic** | Predicate: AI judges whether terse reflection was expanded to full requirement (Scope/Statement/examples/rationale/cross-refs); expansion adequacy is interpretive. **Routing:** 5-row reflection-form→integrated-form table. | reflections-processing/SKILL.md:286 |
| `[REFL-PROC-009]` | PackageInsight Execution | **mechanical** | Predicate: shell/path — package routing per name pattern (`swift-*-primitives` → swift-primitives clone; `swift-rfc-*\|iso-*\|ietf-*` → swift-standards clone; other → swift-foundations clone) + insight written to `{package}/Research/_Package-Insights.md` with template if absent + lighter-than-skill format. **Composite:** package-resolution table + path + template + format. | reflections-processing/SKILL.md:322 |
| `[REFL-PROC-010]` | BlogIdea and ExperimentTopic Execution | **mechanical** | Predicate: shell — BlogIdea triggers [BLOG-002] index entry; ExperimentTopic triggers [EXP-002] package creation. **Routing:** dispatch to existing process skills. | reflections-processing/SKILL.md:386 |
| `[REFL-PROC-011]` | Convergence Monitoring | **hybrid** | Prefilter: count triage-outcome distribution over time; check 4 thresholds (SkillUpdate-fraction-not-decreasing / ResearchTopic-zero-for-10 / NoAction>50%-over-10 / same-skill-modified-3+-in-sequence). AI closes verdict on whether signal is genuine drift vs noise. | reflections-processing/SKILL.md:398 |
| `[REFL-PROC-013]` | Absorptive Capacity Audit | **semantic** | Predicate: AI reviews NoAction outcomes for systematic blind spots; (a) skills-adequate vs (b) triage-blind-spot judgment is interpretive. | reflections-processing/SKILL.md:415 |
| `[REFL-PROC-012]` | Commit Standards | **mechanical** | Predicate: regex — commit message matches canonical format (`Process reflection: {short title}` + `Triage outcomes:` + per-outcome tagged lines). | reflections-processing/SKILL.md:427 |
| `[REFL-PROC-014]` | Entry Status Update | **mechanical** | Predicate: YAML-parse — frontmatter has `status: processed`, `processed_date`, `triage_outcomes` array with per-outcome `type`/`target`/`description`. | reflections-processing/SKILL.md:464 |
| `[REFL-PROC-015]` | Graceful Interruption | **semantic** | Predicate: AI judges whether interruption-handling preserved invariants (no partial skill/doc edits / completed outcomes committed / partial entries stay pending / report); interruption-state classification is interpretive. | reflections-processing/SKILL.md:497 |
| `[REFL-PROC-016]` | Pre-Commit ID-Uniqueness Scan | **mechanical** | Predicate: shell — `grep -hE "^### \[<PREFIX>-[0-9]+[a-z]?\]" {target} \| sort \| uniq -d` returns empty before commit; for multi-file skills, scan across all sibling files. **Composite:** single-file scan + multi-file scan + per-stage gate. | reflections-processing/SKILL.md:514 |

#### 10.2 reflections-processing distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 7 | REFL-PROC-001, REFL-PROC-002, REFL-PROC-009, REFL-PROC-010, REFL-PROC-012, REFL-PROC-014, REFL-PROC-016 |
| hybrid | 3 | REFL-PROC-003, REFL-PROC-007, REFL-PROC-011 |
| semantic | 8 | REFL-PROC-002a, REFL-PROC-004, REFL-PROC-005, REFL-PROC-005a, REFL-PROC-006, REFL-PROC-008, REFL-PROC-013, REFL-PROC-015 |

Total 18.

Density observation: reflections-processing is a triage skill — its mechanical floor sits in the artifact-shape rules (invocation triggers as count, processing-sequence ordering, package routing, commit format, YAML frontmatter, ID-uniqueness scan, BlogIdea/ExperimentTopic dispatch). The semantic core sits in triage validation, generalization adequacy, voice transformation, expansion adequacy, and absorptive-capacity audits — each of which requires AI to judge interpretive properties.

---

### Part 11 — reflect-session (`Skills/reflect-session/SKILL.md`)

Verified against `SKILL.md` (470 lines, last_reviewed 2026-04-30). All 14 requirement IDs walked.

#### 11.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[REFL-001]` | Invocation Triggers | **semantic** | Predicate: AI judges session as "non-trivial learning" vs "routine" against 6-row trigger-priority table; novelty assessment is interpretive. **Routing:** 6-row trigger→priority dispatch. | reflect-session/SKILL.md:44 |
| `[REFL-002]` | Reflection Entry Template | **mechanical** | Predicate: regex/path — file is in `swift-institute/Research/Reflections/` with name `YYYY-MM-DD-{slug}.md`; YAML frontmatter has required fields; body has 4 named sections (What Happened / What Worked and What Didn't / Patterns and Root Causes / Action Items). | reflect-session/SKILL.md:67 |
| `[REFL-003]` | Action Item Tags | **mechanical** | Predicate: regex — every action item has exactly one tag from `[skill\|doc\|research\|experiment\|blog\|package]` and a specific target. **Composite:** tag-presence + tag-uniqueness + target-specificity. | reflect-session/SKILL.md:133 |
| `[REFL-004]` | Action Item Cap | **mechanical** | Predicate: shell — count action items in entry; ≤3. | reflect-session/SKILL.md:172 |
| `[REFL-005]` | Entry Metadata | **mechanical** | Predicate: YAML-parse — frontmatter contains `date` (ISO 8601), `session_objective` (string), `status: pending` on creation; `packages` SHOULD be present when packages were touched. | reflect-session/SKILL.md:182 |
| `[REFL-006]` | Reflection Depth | **semantic** | Predicate: AI judges whether "Patterns and Root Causes" reaches Bloom Analyze/Create level vs Remember/Understand; depth is interpretive. **Composite:** Bloom-table + future-work-verification + re-verify-after-edit + post-commit-memory-scan. | reflect-session/SKILL.md:203 |
| `[REFL-007]` | Reflections Index | **mechanical** | Predicate: schema-validate — `Research/Reflections/_index.json` has per-entry fields (`file`, `date`, `title`, `packages`, `status` enum, optional `processedDate`, `triageOutcome` enum, `outcomeDescription`, `statusRaw`); conforms to canonical schema URL. **External:** schema URL `https://swift-institute.org/schemas/reflections-index-v1.json`. | reflect-session/SKILL.md:253 |
| `[REFL-008]` | Cleanup Scope | **semantic** | Predicate: AI categorizes session artifacts (handoff files / supervisor block / audit findings / execution-session analysis) and applies per-type cleanup; categorization is interpretive. **Routing:** 4-row artifact-type→action table. | reflect-session/SKILL.md:265 |
| `[REFL-009]` | Handoff Cleanup | **hybrid** | Prefilter: shell — scan `HANDOFF.md` and `HANDOFF-*.md` at workspace root + per-file `### Supervisor Ground Rules` heading detection + ground-rules verification-line regex. AI closes verdict on per-Next-Step disposition + bounded-cleanup-authority + stale-override exception. **Composite:** 5-step procedure + 7-row triage-result→action table + bounded-authority + 14-day stale-override. | reflect-session/SKILL.md:284 |
| `[REFL-009a]` | In-Flight-File Conservativism for Bulk Triage | **semantic** | Predicate: AI judges whether file is "in-flight" (principal actively working on the topic) and applies no-touch-wins-over-annotate; in-flight detection is interpretive. **Routing:** 2-axis (in-flight × override) decision matrix. | reflect-session/SKILL.md:342 |
| `[REFL-010]` | Audit Finding Cleanup | **hybrid** | Prefilter: shell — scan audit sections written/modified during session. AI closes verdict on per-finding status update (RESOLVED / FALSE_POSITIVE / DEFERRED / OPEN). **Composite:** 4-step procedure + 4-row session-outcome→status-update table + scope-strictness rule. | reflect-session/SKILL.md:371 |
| `[REFL-011]` | Correction-from-Primary-Source Rule | **semantic** | Predicate: AI judges whether correction re-fetched primary source (JSON/measurement/grep) vs transcribed-from-prior-artifact; provenance-discipline is interpretive. | reflect-session/SKILL.md:398 |
| `[REFL-012]` | Loop-Counter Verification Is State Verification, Not Variable Re-Read | **mechanical** | Predicate: shell — when loop reports N successes, post-run state check is one of the 4 canonical commands per loop-outcome class (`git log --oneline -N` / `find target -newer ref` / `for r in <repos>; do git ... done` / `grep -c new-pattern affected-files`). | reflect-session/SKILL.md:421 |
| `[REFL-013]` | Verify Untracked Session Writes Persist at Phase Boundaries | **mechanical** | Predicate: shell — at each phase boundary, `ls` (or equivalent existence check) on untracked files written by earlier phases; periodic re-verify ~10–15 turns. | reflect-session/SKILL.md:442 |

#### 11.2 reflect-session distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 7 | REFL-002, REFL-003, REFL-004, REFL-005, REFL-007, REFL-012, REFL-013 |
| hybrid | 2 | REFL-009, REFL-010 |
| semantic | 5 | REFL-001, REFL-006, REFL-008, REFL-009a, REFL-011 |

Total 14.

Density observation: reflect-session balances mechanical artifact-shape rules (50%, covering filename/template/tags/cap/metadata/index/loop-counter/untracked-writes verification) with a semantic core on depth/cleanup/correction discipline. The skill's design intent — capture-then-cleanup — pushes mechanical rules to artifact creation and semantic rules to judgment-bearing depth and triage.

---

### Part 12 — swift-evolution (`Skills/swift-evolution/SKILL.md`)

Verified against `SKILL.md` (429 lines, last_reviewed 2026-04-14). All 7 requirement IDs walked. Note: PITCH-PROC IDs are declared in heading shape `## [PITCH-PROC-NNN]` (line numbers 89, 116, 146, 173, 258, 326, 355) and also enumerated in a cross-reference table at line 421–429. File-cite line uses the heading line, not the table row.

#### 12.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[PITCH-PROC-001]` | Pitch Triggers | **semantic** | Predicate: AI maps an identified language/stdlib limitation to a 6-row trigger-category→priority table; categorization (Blocking limitation / Ecosystem fragmentation / Source compatibility cliff / Ergonomic degradation / Performance limitation / Consistency gap) requires interpretive reading of impact. **External:** must check Commonly Proposed Changes list before pitching. **Routing:** 6-row category→priority dispatch. | swift-evolution/SKILL.md:89 |
| `[PITCH-PROC-002]` | Evidence Requirements | **hybrid** | Prefilter: regex/path — pitch has Evidence section with at least one of {experiment results / implementation attempts / workaround analysis / ecosystem impact}; per-evidence Reproducible/Minimal/Referenced criteria checks. AI closes verdict on adequacy + cross-version coverage. **Composite:** 4-row evidence-category enumeration + 4-row quality-criteria table. | swift-evolution/SKILL.md:116 |
| `[PITCH-PROC-003]` | Scope Analysis | **semantic** | Predicate: AI walks 4-step dependency analysis (list changes / identify deps / determine minimal independent units / order by dep); minimal-independent-unit identification is judgment-laden. | swift-evolution/SKILL.md:146 |
| `[PITCH-PROC-004]` | Pitch Drafting | **mechanical** | Predicate: regex/path — pitch file at `Swift Evolution/Drafts/PITCH-XXXX {Title}.md` with YAML frontmatter (`pitch_id`, `date`, `status: DRAFT`, optional `depends_on`, optional `related_experiments`) and body sections (Problem / Proposed Direction / Evidence / Open Questions / Impact / Related Work). **Composite:** path + frontmatter + 6-section body + naming convention. | swift-evolution/SKILL.md:173 |
| `[PITCH-PROC-005]` | Pitch Submission | **mechanical** | Predicate: shell/file — pitch posted to forums (forum thread title `[Pitch] {Title}`); file moved Drafts/ → Pitches/; metadata updated with `forum_link` + `submitted_date`; status SUBMITTED → CONVERGED on convergence-criteria checklist. **External:** forum URL + Swift Forums tag scheme. **Composite:** 4-step submission + forum-format + convergence-criteria checklist. | swift-evolution/SKILL.md:258 |
| `[PITCH-PROC-006]` | Linking Evidence Bidirectionally | **mechanical** | Predicate: regex — pitch has Related-experiments section with linked refs; experiment has Related-Pitches section with linked refs; both sides cite each other. | swift-evolution/SKILL.md:326 |
| `[PITCH-PROC-007]` | Pitch Iteration | **hybrid** | Prefilter: regex — `revisions:` array entries with `date` + `summary` per iteration; status WITHDRAWN MUST carry `withdrawn_date` + `withdrawal_reason`. AI closes verdict on iteration adequacy and when-to-withdraw judgment. | swift-evolution/SKILL.md:355 |

#### 12.2 swift-evolution distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 3 | PITCH-PROC-004, PITCH-PROC-005, PITCH-PROC-006 |
| hybrid | 2 | PITCH-PROC-002, PITCH-PROC-007 |
| semantic | 2 | PITCH-PROC-001, PITCH-PROC-003 |

Total 7.

Density observation: swift-evolution is a small, structurally-focused skill — pitches are highly conventionalized documents with strict frontmatter + section requirements (mechanical). The semantic core sits in trigger judgment and scope analysis — both upstream of authoring and judgment-laden. Hybrid rules cover Evidence + Iteration, where structural shape is mechanical but adequacy is interpretive.

---

### Part 13 — legal-encoding (`Skills/legal-encoding/SKILL.md`)

Verified against `SKILL.md` (786 lines, last_reviewed 2026-03-20). All 31 requirement IDs walked.

#### 13.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[LEG-ENC-001]` | Literal Encoding | **semantic** | AI input: judge whether a provision's encoding "literally" mirrors the statute text — the inputs are the facts the provision mentions, the outputs are the conclusions the text derives, nothing more. Requires reading the statute against the encoded type. **External:** authoritative statute text from `wetten.overheid.nl` or equivalent jurisdiction source. | legal-encoding/SKILL.md:51 |
| `[LEG-ENC-002]` | Flat Struct of Bool? Questions | **mechanical** | Predicate: AST → for each provision (lid) struct, verify all stored properties are `Bool?` (or trivially derived `Bool?`); no nested aggregate types in input position; flat structure. Closed-form AST shape. | legal-encoding/SKILL.md:67 |
| `[LEG-ENC-003]` | @Splat + Arguments + Error | **mechanical** | Predicate: AST → for each conditional provision struct, verify presence of (a) `@Splat` macro attribute, (b) inner `Arguments: Sendable` struct, (c) `Error: Swift.Error, Sendable` extension, (d) `CustomStringConvertible` conformance on Error, (e) typed `throws(Error)` init taking `Arguments`. Five-shape AST check. | legal-encoding/SKILL.md:84 |
| `[LEG-ENC-004]` | Normative Provisions | **mechanical** | Predicate: AST → for unconditional provisions (no Arguments struct), verify struct has parameterless `init()` AND output `Bool?` properties default to `true`. Closed-form. | legal-encoding/SKILL.md:152 |
| `[LEG-ENC-005]` | Conditional Provisions | **hybrid** | Prefilter: AST → detect conditional provisions (Arguments present); verify they use `Bool?.any { }` / `Bool?.all { }` / `.map { !$0 }` for logic composition. AI input: judge whether the chosen logic composition correctly mirrors the statute's natural-language connective ("indien" → input, "tenzij" → negation, "en" → all, "of" → any). **External:** Dutch/English statute text for the connective decision. | legal-encoding/SKILL.md:170 |
| `[LEG-ENC-006]` | Legislature Layer Boundary | **semantic** | AI input: judge whether a legislature package contains only Questions, Conclusions, and Substantiation — without Questioning strategy, Cross-article composition, Legal interpretation, or Case law application. Boundary judgment requires reading code intent and cross-package dependencies. | legal-encoding/SKILL.md:196 |
| `[LEG-ENC-010]` | When to Use Enums | **semantic** | AI input: judge whether the statute defines distinct categories where different conditions bind to different categories AND asking the wrong category's conditions would be meaningless (the test). Domain-semantic call about whether a flat struct would force irrelevant questions. **External:** statute text. | legal-encoding/SKILL.md:215 |
| `[LEG-ENC-020]` | Self-Contained Provisions | **mechanical** | Predicate: AST → for each provision (lid) struct, enumerate nested types; verify they are declared inside the provision struct, not shared/imported across provisions. Detect cross-provision type sharing in the same module. | legal-encoding/SKILL.md:232 |
| `[LEG-ENC-021]` | Article-Level Composition | **hybrid** | Prefilter: AST → detect article coordinator types; verify they instantiate provision types and feed earlier outputs into later inputs. AI input: judge whether the wiring correctly mirrors the statute's intra-article cross-references. **External:** statute text. | legal-encoding/SKILL.md:240 |
| `[LEG-ENC-030]` | Backticked Legal Terminology | **hybrid** | Prefilter: AST → enumerate backticked identifiers in legal-encoding modules; verify they are backticked (not camelCase translation). AI input: judge whether the backtick string preserves "exact phrasing from the statute text" in the matching language. **External:** statute text required for verification. | legal-encoding/SKILL.md:255 |
| `[LEG-ENC-040]` | Root Namespace Type | **mechanical** | Predicate: AST → each statute package exports exactly one root namespace enum at module top level; typealias for abbreviation present where conventional. Closed-form shape check. | legal-encoding/SKILL.md:278 |
| `[LEG-ENC-041]` | Multi-Book Statute Packaging | **mechanical** | Predicate: filesystem + Package.swift parse → for multi-book statutes, verify three-package pattern: `{statute}-core`, `{statute}-boek-{N}` (one per book), and umbrella `{statute}`. Directory + dependency-graph check. | legal-encoding/SKILL.md:301 |
| `[LEG-ENC-042]` | Core Package | **mechanical** | Predicate: AST → core package source files contain exactly one type declaration (the root namespace enum) AND no dependencies beyond standard infrastructure. Closed-form shape + Package.swift check. | legal-encoding/SKILL.md:322 |
| `[LEG-ENC-043]` | Book Extension Pattern | **mechanical** | Predicate: AST + Package.swift → each book package depends on core package AND extends root namespace with `enum N {}` using bare numeric identifier. Closed-form. | legal-encoding/SKILL.md:335 |
| `[LEG-ENC-044]` | Umbrella Package | **mechanical** | Predicate: AST → umbrella package source files contain only `@_exported import` statements (one per book + core) AND no type declarations. Closed-form. | legal-encoding/SKILL.md:365 |
| `[LEG-ENC-045]` | Four-Layer Stack | **mechanical** | Predicate: Package.swift dependency-graph → for each package, classify into Layer 1 (`*-core`), Layer 2a (`swift-*-wetgever`), Layer 2b (`swift-*-hoge-raad`), Layer 3 (`rule-law-*`), Layer 4 (`rule-legal-*`); verify dependencies only flow downward AND legislature/judiciary have zero cross-dependencies. **Reference (anchor):** definitional anchor for cross-skill use ([RL-CORE-020], [LEG-ENC-006], [JUD-ENC-001], [JUD-ENC-002], [PROD-ENC-002]). | legal-encoding/SKILL.md:379 |
| `[JUD-ENC-001]` | Verdict Encoding Pattern | **mechanical** | Predicate: filesystem + AST → each verdict is a standalone package named `ecli-{court}-{year}-{number}` (kebab-case from ECLI), follows `@Splat` + `Arguments` + `Bool?` pattern (delegates to [LEG-ENC-003]); located under `swift-{jurisdiction}-hoge-raad`-pattern org with zero cross-dependencies. | legal-encoding/SKILL.md:415 |
| `[JUD-ENC-002]` | Dependency Inversion for Verdicts | **mechanical** | Predicate: Package.swift → verdict packages MUST NOT import statute packages; statutory conditions appear as `Bool?` inputs in the verdict's Arguments. Import-graph check on judiciary packages. | legal-encoding/SKILL.md:430 |
| `[JUD-ENC-003]` | Verdict Metadata | **hybrid** | Prefilter: regex → DocC comment block present at type level with `## Court`, `## Date`, `## Subject`, `## Legal References` headings. AI input: judge whether the metadata content is correct (court name correct, date matches ECLI, subject matches verdict text). **External:** verdict text from `data.rechtspraak.nl`. **Reference (illustration):** uses SHOULD; pattern established but no enforced reference implementation per skill text. | legal-encoding/SKILL.md:450 |
| `[COMP-ENC-001]` | Composition Responsibility | **hybrid** | Prefilter: AST + Package.swift → composition packages (`rule-law-*`) import legislature and judiciary packages; AI input: judge whether the composition properly wires conclusions across statutes/verdicts and resolves conflicts (lex specialis, lex posterior). Domain-semantic call about wiring correctness. **External:** statute + case law text. | legal-encoding/SKILL.md:487 |
| `[COMP-ENC-002]` | Typealias Pattern | **mechanical** | Predicate: AST → composition layer files contain `@_exported import` of legislature modules AND `public typealias` declarations re-exporting types under the unified namespace. Closed-form shape. Use of SHOULD; outcome shape mechanical. | legal-encoding/SKILL.md:505 |
| `[COMP-ENC-003]` | Cross-Statute Wiring | **hybrid** | Prefilter: AST → detect composition-layer call sites where one statute's output is fed into another's input. AI input: judge whether the wiring correctly mirrors the cross-statute legal connection (e.g., NRS 78.035 requires NRS 77.310 compliance). **External:** statute text and cross-reference structure. | legal-encoding/SKILL.md:527 |
| `[COMP-ENC-004]` | Defeasibility Resolution | **semantic** | AI input: identify statute conflicts (lex specialis, lex posterior), judge whether the composition layer's resolution logic correctly applies the meta-rule. Pure legal interpretation. **External:** statute text + jurisprudential meta-rules. | legal-encoding/SKILL.md:551 |
| `[COMP-ENC-010]` | Composition Types Store Lid Instances | **mechanical** | Predicate: AST → for each composition type deriving conclusions from multiple provisions, verify (a) full lid evaluation stored as property (not just the derived `Bool`); (b) domain conclusions exposed as computed properties over stored lids; (c) `enum Error: Swift.Error, Sendable` with one case per lid. Three-shape AST check. | legal-encoding/SKILL.md:561 |
| `[COMP-ENC-012]` | Product vs Composition Boundary | **semantic** | AI input: for each concept, decide layer placement using the four-question test (Statute defines structure? / Multiple products use it differently? / Specific output format? / Specific integration?). Layer-placement judgment is domain-semantic. **Routing:** decision-tree wrapper around layer-placement criteria; rule's value is at-keyboard placement routing. | legal-encoding/SKILL.md:623 |
| `[COMP-ENC-020]` | Per-Concept Composition Packages | **hybrid** | Prefilter: filesystem + Package.swift → for `rule-{jurisdiction}-{concept}` packages, verify (a) imports L2a only (no lateral L3); (b) named with jurisdiction prefix; (c) dependency rules (per-concept may import per-concept); (d) public-import discipline at consumer sites. AI input: apply three-test qualification (Multi-source / Multi-consumer / Multi-type) — judging "2+ statutes" / "2+ consumers" / "2+ types" requires reading domain. | legal-encoding/SKILL.md:655 |
| `[PROD-ENC-001]` | Entity State Machines | **semantic** | AI input: identify product types modeling entities; judge whether the state machine's transitions are appropriately gated by composition-layer requirements. Domain-semantic about state-machine appropriateness; rule uses MAY. **Reference (illustration):** illustration-only example of state shape. | legal-encoding/SKILL.md:689 |
| `[PROD-ENC-002]` | Composition Consumption | **mechanical** | Predicate: AST + Package.swift → product packages (`rule-legal-*`) import composition layer (`rule-law-*`) only AND MUST NOT import legislature packages directly. Import-graph check. | legal-encoding/SKILL.md:710 |
| `[LEG-ENC-060]` | Jurisdiction-Specific Patterns | **hybrid** | Prefilter: filesystem + AST → detect jurisdiction (NL/US/EU) from package path/naming; verify that identifier language, parent-type pattern, file-naming, module-import, and error-message language match the jurisdiction's row. AI input: edge cases where jurisdiction mixing occurs (e.g., EU regulation in NL composition) require judgment. **Reference (anchor):** jurisdiction comparison table is canonical reference for downstream rules. | legal-encoding/SKILL.md:729 |
| `[LEG-ENC-061]` | Package Naming by Jurisdiction | **mechanical** | Predicate: regex on package names — Netherlands `^wet-.+$|^[a-z-]+$`, US-NV `^swift-us-nv-nrs-\d+$`, US-Federal `^swift-us-usc-\d+-\d+$`, EU `^eu-.+$`. Composition shape `^rule-law-{jurisdiction}$`. **Reference (anchor):** package-naming catalog by jurisdiction. | legal-encoding/SKILL.md:744 |
| `[LEG-ENC-062]` | Dependency Rules by Jurisdiction | **mechanical** | Predicate: Package.swift dependency-graph by jurisdiction → Dutch (zero cross-deps), US (later-chapter-may-depend-on-earlier DAG), Across-jurisdictions (orthogonal). Per-jurisdiction graph check. **Reference (anchor):** definitional anchor for jurisdiction dep rules. | legal-encoding/SKILL.md:757 |

#### 13.2 legal-encoding distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 17 | LEG-ENC-002, LEG-ENC-003, LEG-ENC-004, LEG-ENC-020, LEG-ENC-040, LEG-ENC-041, LEG-ENC-042, LEG-ENC-043, LEG-ENC-044, LEG-ENC-045, JUD-ENC-001, JUD-ENC-002, COMP-ENC-002, COMP-ENC-010, PROD-ENC-002, LEG-ENC-061, LEG-ENC-062 |
| hybrid | 8 | LEG-ENC-005, LEG-ENC-021, LEG-ENC-030, JUD-ENC-003, COMP-ENC-001, COMP-ENC-003, COMP-ENC-020, LEG-ENC-060 |
| semantic | 6 | LEG-ENC-001, LEG-ENC-006, LEG-ENC-010, COMP-ENC-004, COMP-ENC-012, PROD-ENC-001 |

Total 31. Density observation: legal-encoding sits balanced toward mechanical (55%) — the @Splat+Bool? skeleton, namespace packaging, and four-layer dependency rules carry strict AST/import-graph predicates. The semantic share concentrates on layer-boundary and content-judgment rules where statute interpretation is load-bearing. **External:** annotation occurs frequently because verifying statutory content requires fetching `wetten.overheid.nl` text.

---

### Part 14 — issue-investigation (`Skills/issue-investigation/SKILL.md`)

Verified against `SKILL.md` (754 lines, last_reviewed 2026-04-15). All 25 requirement IDs walked.

#### 14.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[ISSUE-010]` | Bug Classification | **semantic** | AI input: classify the issue into one of five categories (ICE/Crash, Miscompile, Rejects-valid, Accepts-invalid, Diagnostic) based on the failure mode. Determines downstream investigation strategy. **Routing:** decision-tree wrapper — the classification routes to different investigation pipelines; rule's value is at-keyboard categorization to drive subsequent step selection. | issue-investigation/SKILL.md:42 |
| `[ISSUE-020]` | SE-Proposal Constraint Check | **hybrid** | Prefilter: detect signals (multi-workaround failure with same error class, standalone reproducer compiles clean, error names a constraint not in source). AI input: search Swift Evolution proposals for changes to the named protocol's implicit requirements; test whether `& ~Copyable` (or analogous inverse constraint) resolves. **External:** Swift Evolution proposal corpus (forums.swift.org / swift-evolution repo). | issue-investigation/SKILL.md:62 |
| `[ISSUE-022]` | Ask Before Designing the Fix | **semantic** | AI input: judge whether the brief's writeup will exceed ~500 words AND whether multiple reasonable fix-shapes exist; if so, surface a clarifying question on at least one of four axes (additive vs subtractive, runtime vs compile-time, new types vs relocation, workaround vs refactor). Recognition-task framing is meta-process judgment. | issue-investigation/SKILL.md:88 |
| `[ISSUE-001]` | Check Dev Toolchain First | **mechanical** | Predicate: shell exit-code on `TOOLCHAINS=swift xcrun swiftc -O reproducer.swift -o /tmp/test`. Pass/fail outcome is binary. Workflow framing ("before any investigation") is process; CI/agent observes outcome at result time. | issue-investigation/SKILL.md:150 |
| `[ISSUE-002]` | Standalone Reproducer | **mechanical** | Predicate: filesystem → reproducer is a single `.swift` file; shell → `swiftc reproducer.swift -o /tmp/test` exits with the expected failure code without any project structure. Closed-form shape + build outcome. | issue-investigation/SKILL.md:174 |
| `[ISSUE-003]` | Reduction Protocol | **hybrid** | Prefilter: shell → before each step verify `rm -rf .build` exit code AND directory absence (defends against the stale-build trap); reduction order is enumerable. AI input: judge whether each removal step preserves the failure or unmasks a different failure (false reduction). **Routing:** ordered decision-tree (9 reduction steps) — rule's value is the at-keyboard ordering. | issue-investigation/SKILL.md:191 |
| `[ISSUE-004]` | Required Ingredient Verification | **mechanical** | Predicate: for each remaining ingredient, remove it independently from a clean build and verify failure outcome flips. Loop with binary outcome per element. Documentation step is fixed-format. | issue-investigation/SKILL.md:214 |
| `[ISSUE-023]` | Debug-Prints-First Ladder for Release-Mode-Only Bugs | **semantic** | AI input: judge when debug/release divergence narrows the suspect space to optimization/memory-ordering/UB; recognize the anti-pattern of skipping step 1 (`print()`) for source-reading or SIL-inspection. Cost-discipline judgment: 90s prints vs 20min theorizing. **Routing:** ladder of four diagnostic steps (prints → experiment → SIL → compiler source). | issue-investigation/SKILL.md:232 |
| `[ISSUE-005]` | SIL Dump Analysis | **mechanical** | Predicate: shell → invoke `swiftc -O -Xllvm -sil-print-around=PASS` / `-sil-print-function=NAME` / `-sil-verify-all`; capture output. AI follow-up reads the dump but the rule's compliance check is "did the agent run the right command and surface the SIL evidence." Outcome-mechanical. **Reference (anchor):** definitional catalog of SIL-dump commands. | issue-investigation/SKILL.md:285 |
| `[ISSUE-011]` | Pass Bisection | **mechanical** | Predicate: binary-search loop on `-Xllvm -sil-opt-pass-count=<N>`; sub-pass via `<n>.<m>`; pass disable via `-sil-disable-pass=<tag>`. Closed-form shell-loop with binary outcome per step. **Reference (anchor):** definitional catalog of bisection flags. | issue-investigation/SKILL.md:313 |
| `[ISSUE-006]` | Hypothesis Discipline | **semantic** | AI input: judge whether each hypothesis is grounded in current evidence (correct pattern: SIL evidence supports test) vs prior-investigation pattern-matching (anti-pattern: "this looks like Bug 2 because"). Pure cognitive-discipline judgment. | issue-investigation/SKILL.md:344 |
| `[ISSUE-012]` | Compiler Source Reading | **hybrid** | Prefilter: filesystem → swiftlang/swift clone present at `${DEV_ROOT}/swiftlang/swift`; pass and crash-site identified from prior steps. AI input: read source for TODO/FIXME, bailout conditions, assertions; judge what the comment/code reveals about the bug. **External:** swiftlang/swift compiler source at the cited paths. | issue-investigation/SKILL.md:356 |
| `[ISSUE-007]` | Duplicate Search | **hybrid** | Prefilter: shell/web search on exact error string + feature combination + commit log. AI input: judge whether the matched issue/PR is a true duplicate of the current investigation (not just a similar pass name). **External:** github.com/swiftlang/swift issues + commits + compiler-source TODOs. | issue-investigation/SKILL.md:390 |
| `[ISSUE-008]` | Resolution Paths | **semantic** | AI input: choose path from the four-row decision matrix based on diagnosis state (fixed-on-dev / unfixed-clear-cause / unfixed-unclear-cause / our-code-triggers-known-limit). **Routing:** decision-tree wrapper — rule's value is at-the-keyboard path selection across resolution branches. | issue-investigation/SKILL.md:410 |
| `[ISSUE-009]` | Investigation Record | **mechanical** | Predicate: filesystem → relevant package's `Research/audit.md` contains an entry with severity / location / finding / status / tracking-reference. Field-presence check on a structured Markdown record. | issue-investigation/SKILL.md:433 |
| `[ISSUE-013]` | Variable Isolation for Context-Sensitive Bugs | **mechanical** | Predicate: for each integration dimension in the seven-row table (access level / field count / dependencies / generic vs concrete / optimization mode / compilation mode / module isolation), test independently and record a constraint model. Loop with binary outcome per dimension. | issue-investigation/SKILL.md:445 |
| `[ISSUE-014]` | File-Level Elimination | **mechanical** | Predicate: shell → empty all source files in target, add back one at a time, rebuild between each; binary crash/no-crash outcome per addition. Closed-form bisection on filesystem. | issue-investigation/SKILL.md:471 |
| `[ISSUE-015]` | Superrepo Validation | **mechanical** | Predicate: shell → for layered superrepos, run release-mode build at superrepo level (not just sub-repo level). Build-success outcome is binary; superrepo path is structural. | issue-investigation/SKILL.md:488 |
| `[ISSUE-016]` | Available Reduction Tools | **mechanical** | **Reference (anchor):** definitional catalog of source-level (C-Reduce, manual), SIL-level (`bug_reducer.py`, `sil-func-extractor`), and pass-level (`-sil-opt-pass-count`, `-sil-disable-pass`) reduction tools. Outcome predicate: appropriate tool selected for the bug's abstraction level — verifiable by tool invocation. | issue-investigation/SKILL.md:498 |
| `[ISSUE-017]` | Issue Report Format | **mechanical** | Predicate: regex/parse on a swiftlang/swift issue report → required fields (Classification, Environment, Reproducer, Command, Observed, Expected, optional Investigation/bisection/SIL/ingredients) present. Schema-derivable check. **External:** github.com/swiftlang/swift issue corpus to verify format against merged-PR reference issues. | issue-investigation/SKILL.md:527 |
| `[ISSUE-021]` | Reference Indirection for SIL Verifier Crashes | **hybrid** | Prefilter: detect the SIL-pattern triggers (`CheckedContinuation` with complex `Result` in `~Copyable` enum / generic pack pattern-match / `load [take]` sibling-leak diagnostic). AI input: judge whether the workaround applies AND wrap the payload in a final class. Workaround documentation per [ISSUE-008] is mechanical-on-format. **Reference (illustration):** known-recurring-workaround narrative; rule's predicate is at the trigger-detection + class-wrap shape. | issue-investigation/SKILL.md:566 |
| `[ISSUE-018]` | Diagnostic Investigation Tools | **mechanical** | **Reference (anchor):** definitional catalog of diagnostic flags (`-debug-diagnostic-names`, `-debug-constraints`, `-swift-diagnostics-assert-on-error=1`, `-dump-ast`, `-dump-parse`, `-typecheck`). Outcome: appropriate tool invoked for the diagnostic class. | issue-investigation/SKILL.md:627 |
| `[ISSUE-019]` | SIL Pipeline Stages | **mechanical** | **Reference (anchor):** definitional catalog of pipeline-stage dump commands (`-emit-silgen`, `-emit-sil -Onone`, `-emit-sil -O`, `-emit-irgen -O`, `-emit-ir -O`). Outcome: appropriate stage dumped to localize SILGen vs mandatory-pass vs optimization-pass attribution. | issue-investigation/SKILL.md:642 |
| `[ISSUE-024]` | Multi-Repo Shell Iteration Detection Predicate | **mechanical** | Predicate: regex/AST on shell scripts → `[[ -e "$d/.git" ]]` (correct) vs `[[ -d "$d/.git" ]]` (defect). One-character literal-grep check. | issue-investigation/SKILL.md:676 |
| `[ISSUE-025]` | In-Package Verification of Synthetic-Reproducer Claims | **hybrid** | Prefilter: filesystem → for each claimed-affected production consumer, in-package release-mode test exists exercising the production shape. AI input: identify which structural features differ between reduced reproducer and production shape (load-bearing discriminators); judge whether the test exercises the production shape under the failure trigger. | issue-investigation/SKILL.md:706 |

#### 14.2 issue-investigation distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 14 | ISSUE-001, ISSUE-002, ISSUE-004, ISSUE-005, ISSUE-011, ISSUE-009, ISSUE-013, ISSUE-014, ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-019, ISSUE-024 |
| hybrid | 6 | ISSUE-020, ISSUE-003, ISSUE-012, ISSUE-007, ISSUE-021, ISSUE-025 |
| semantic | 5 | ISSUE-010, ISSUE-022, ISSUE-023, ISSUE-006, ISSUE-008 |

Total 25. Density observation: issue-investigation is mechanical-dominant (56%) — the rules are step-by-step compiler-investigation procedures with shell commands, build-outcome binaries, and AST/regex pattern-checks. The semantic share concentrates on classification, hypothesis discipline, and meta-process judgment ([ISSUE-010] / [ISSUE-022] / [ISSUE-006] / [ISSUE-008] / [ISSUE-023]) which are tier-1's familiar Routing pattern. **Reference (anchor):** is heavy here ([ISSUE-005], [ISSUE-011], [ISSUE-016], [ISSUE-018], [ISSUE-019]) — definitional catalogs of compiler flags load-bear for downstream rules.

---

### Part 15 — testing (`Skills/testing/SKILL.md`)

Verified against `SKILL.md` (914 lines, last_reviewed 2026-04-24). All 18 requirement IDs walked.

#### 15.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[TEST-001]` | Framework Selection | **mechanical** | Predicate: regex `import\s+XCTest` MUST NOT appear in any `Tests/` source file; `import\s+Testing` MUST appear; `class\s+\w+\s*:\s*XCTestCase` forbidden. Closed-form import + class-shape grep. | testing/SKILL.md:70 |
| `[TEST-005]` | Test Category Suites | **mechanical** | Predicate: AST → for each test target's top-level `Test` namespace, verify presence of four standard suite types (`Unit`, `` `Edge Case` ``, `Integration`, `Performance`); verify Performance carries `.serialized` trait. Closed-form shape check. | testing/SKILL.md:97 |
| `[TEST-009]` | File Naming Convention | **mechanical** | Predicate: filesystem → for each `.swift` file under a `Tests/` directory, regex match `^[\w. ]+ Tests\.swift$` AND verify the prefix mirrors a real type path (e.g., `Memory.Buffer Tests.swift` → file under test contains `Memory.Buffer`). Filename-shape regex. | testing/SKILL.md:133 |
| `[TEST-025]` | Using Test Support — Quick Start | **mechanical** | **Reference (anchor):** definitional catalog of Test Support import patterns and what each transitively provides (Index/Offset/Count literals, Bit.Index, Buffer factories, Vector ranges, temp-files, thread harnesses, dependency overrides). Outcome predicate: tests import `*_Test_Support` (not the main module + manual constructors) — regex check. | testing/SKILL.md:162 |
| `[TEST-026]` | Test Support Module Reference | **mechanical** | **Reference (anchor):** definitional catalog of every Test Support module across primitives, standards, foundations layers — name + unique API + re-export chain. Outcome: catalog is canonical source for module-API expectations; downstream rules ([TEST-018], [TEST-028]) reference it. | testing/SKILL.md:368 |
| `[TEST-010]` | Test Support Target Declaration | **mechanical** | Predicate: Package.swift parse → for each `*_Test_Support` library, verify (a) declared as `.target()` not `.testTarget()`; (b) product name has spaces; (c) path is `"Tests/Support"`; (d) dependencies include own main module + upstream `*_Test_Support`; (e) test target depends on both main module + Test Support. Five-shape Package.swift check. | testing/SKILL.md:430 |
| `[TEST-019]` | Test Support Directory Structure | **mechanical** | Predicate: filesystem → at `Tests/Support/`, verify presence of `exports.swift` AND at least one `{Name} Test Support.swift` utilities file. Two-file pattern check. | testing/SKILL.md:483 |
| `[TEST-020]` | Re-Export Pattern | **mechanical** | Predicate: regex on `exports.swift` → every import line matches `^@_exported public import \w+$`. Plain `import` and `public import` (without `@_exported`) forbidden. Literal grep. | testing/SKILL.md:512 |
| `[TEST-021]` | Re-Export Chain Architecture | **mechanical** | Predicate: Package.swift dependency-graph + AST → Test Support modules form a DAG mirroring package dependency graph; each module re-exports upstream Test Supports. Graph-shape check. **Reference (anchor):** definitional anchor for Test Support re-export chain visualization. | testing/SKILL.md:538 |
| `[TEST-018]` | Test Support Literal Conformances | **mechanical** | Predicate: AST → tests use literal syntax (`let index: Index<Int> = 5`) for primitives types; rawValue-chain unwrapping (`index.position.rawValue == 5`) forbidden in `Tests/`. Counter-pattern grep on test files. | testing/SKILL.md:574 |
| `[TEST-028]` | Mock Factory — Null-Pointer Collision on `BitwiseCopyable` Pointer-Wrapping Types | **mechanical** | Predicate: regex/AST → for each `.mock(_:)` factory using `unsafeBitCast(\w+, to: T.self)` where `T` is BitwiseCopyable + pointer-interpretable, verify the input is offset (`tag &+ 1`) before bitcast. Closed-form pattern-match. | testing/SKILL.md:628 |
| `[TEST-022]` | Test Support Utility Categories | **semantic** | AI input: classify each Test Support utility into one of four categories (Literal Conformances / Factory Methods / Test Harnesses / Temporary Resource Helpers); judge whether new utilities fit one of these or warrant a new category. **Reference (illustration):** category catalog with examples; no enforceable predicate beyond category-fit judgment. | testing/SKILL.md:661 |
| `[TEST-023]` | Creating a New Test Support Module | **mechanical** | Predicate: ordered checklist (six steps: mkdir → exports.swift → utilities file → Package.swift product+target → test-target dependency → import in tests). Each step is a filesystem/AST shape check. **Routing:** ordered authoring decision-tree. | testing/SKILL.md:735 |
| `[TEST-024]` | Nested Package.swift for Circular Dependencies | **mechanical** | Predicate: filesystem + Package.swift parse → when a package's main Package.swift has no swift-testing dependency AND tests need it, verify nested `Tests/Package.swift` exists with separate resolution scope (path: `../`, swift-testing as dependency). Closed-form shape. | testing/SKILL.md:795 |
| `[TEST-027]` | Test Target Compilation Gate | **mechanical** | Predicate: shell → `swift build --target {Tests}` exit-code zero before any commit changing the package source. Workflow framing ("before committing") at outcome time on a commit-diff predicate. | testing/SKILL.md:836 |
| `[TEST-029]` | Strategy-Parameterized Test Witness Factory | **hybrid** | Prefilter: AST → detect strategy-pattern witness types in tests (e.g., `IO.Completions.Witness`); verify a single backend-opaque factory function exists in Test Support that returns `some Witness` conditional on `#if canImport(...)`. AI input: judge whether the factory exposes per-backend configuration (forbidden) vs preserving backend-agnostic surface; whether backend-specific suites legitimately diverge. | testing/SKILL.md:848 |
| `[TEST-030]` | Preserve Assertion Observation Target Under Concurrency-Safety Remediation | **hybrid** | Prefilter: shell + AST → before/after concurrency-safety remediation, count `#expect` calls per file; flag if count decreased. AI input: judge whether the original assertion's observation target was preserved via `weak`/`Atomic`/`Mutex`/`sending`-stage-in vs degraded into a "didn't crash" smoke test. | testing/SKILL.md:876 |
| `[TEST-031]` | Cross-Reference from Existing-Infrastructure to Literal Conformances | **mechanical** | Predicate: filesystem → existing-infrastructure catalog entries for `Memory.Address`, `Memory.Address.Count`, `Kernel.File.Offset` (and similar typed values) MUST cross-reference [TEST-018]; existing-infrastructure SKILL.md grep for the cross-reference link. Closed-form bidirectional-link check. | testing/SKILL.md:895 |

#### 15.2 testing distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 15 | TEST-001, TEST-005, TEST-009, TEST-025, TEST-026, TEST-010, TEST-019, TEST-020, TEST-021, TEST-018, TEST-028, TEST-023, TEST-024, TEST-027, TEST-031 |
| hybrid | 2 | TEST-029, TEST-030 |
| semantic | 1 | TEST-022 |

Total 18. Density observation: testing is mechanical-heavy (83%) — Test Support infrastructure rules are AST/filesystem/Package.swift shape predicates, and re-export-chain rules are graph predicates. **Reference (anchor):** is the dominant resistant pattern (5 cases: TEST-025/026/021/018/031 — definitional catalogs that load-bear for downstream rules). Only [TEST-022] resists pure mechanical classification — its category catalog has no enforceable per-utility predicate beyond category-fit judgment.

---

### Part 16 — dutch-law (`Skills/dutch-law/SKILL.md`)

Verified against `SKILL.md` (521 lines, last_reviewed 2026-03-20). All 17 requirement IDs walked.

#### 16.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[NL-WET-001]` | Primary Method: `/afdrukken` | **mechanical** | Predicate: agent-trace check → URL pattern matches `https://wetten\.overheid\.nl/{BWBID}/{YYYY-MM-DD}/0/{PATH}/afdrukken`; WebFetch invoked with this URL shape (not a different page). **External:** wetten.overheid.nl URL endpoint. | dutch-law/SKILL.md:30 |
| `[NL-WET-002]` | Date Parameter | **mechanical** | Predicate: regex on URL date component → `\d{4}-\d{2}-\d{2}` format; when user does not specify, current date is used. Format-check + recency-check. | dutch-law/SKILL.md:59 |
| `[NL-WET-003]` | Path Components | **hybrid** | Prefilter: regex on `{PATH}` component → matches expected hierarchy terms (`Boek\d+`, `Boek\w+`, `Hoofdstuk\d+`, `Titeldeel\w+`, `Afdeling\d+`, `Paragraaf\d+`, `Artikel\d+\w*`). AI input: judge whether the path matches the law's actual structure (numbering schemes vary: Arabic / Roman / Dutch ordinals); guessing forbidden — discovery required. **External:** wetten.overheid.nl law-specific TOC. | dutch-law/SKILL.md:69 |
| `[NL-WET-004]` | Granularity Levels | **semantic** | AI input: judge "the most specific level that answers the user's question" given the user's query and the four-level hierarchy (Artikel / Afdeling / Titeldeel / Hoofdstuk-Boek). Pure question-scoping judgment. **Routing:** decision-tree wrapper over granularity choice. | dutch-law/SKILL.md:90 |
| `[NL-WET-005]` | Path Discovery | **mechanical** | Predicate: ordered five-step procedure (fetch main page → ask for TOC structure → extract anchor fragments → convert `_` to `/` → construct `/afdrukken` URL). Each step is a binary success-check on the WebFetch result. **External:** wetten.overheid.nl HTML TOC. | dutch-law/SKILL.md:107 |
| `[NL-WET-006]` | SRU Search (Finding a Law) | **mechanical** | Predicate: URL pattern → `https://zoekservice\.overheid\.nl/sru/Search?operation=searchRetrieve&version=1\.2&x-connection=BWB&query={CQL}&maximumRecords=\d+`; CQL syntax verified against the field catalog. **External:** SRU search endpoint at `zoekservice.overheid.nl`. **Reference (anchor):** definitional catalog of SRU query fields. | dutch-law/SKILL.md:130 |
| `[NL-WET-007]` | Known BWB Identifiers | **mechanical** | **Reference (anchor):** definitional catalog of common BWB IDs (Gw, BW 1-8, WvSr, WvSv, Awb, Rv, Fw, Wvggz) + BWB ID prefix taxonomy (BWBR / BWBV / BWBA). Outcome: when user references one of these laws, the cataloged BWB ID is used directly (no SRU call). Catalog-membership check. | dutch-law/SKILL.md:160 |
| `[NL-WET-008]` | Standard Workflow | **semantic** | AI input: traverse the legislation decision tree (case-law-vs-legislation / BWB-known / structural-index-needed / article-path-known) and select the correct sub-rule at each branch. Citation format requires extracting law-name, article number, validity date, direct URL. **Routing:** the dominant decision-tree of the dutch-law skill — rule's value is at-keyboard navigation across the workflow. | dutch-law/SKILL.md:195 |
| `[NL-WET-009]` | XML Repository Access | **mechanical** | Predicate: URL pattern → `https://repository\.officiele-overheidspublicaties\.nl/bwb/{BWBID}/{DATE}_{VERSION}/xml/{BWBID}_{DATE}_{VERSION}\.xml`. **External:** XML repository endpoint at `repository.officiele-overheidspublicaties.nl`. **Reference (anchor):** definitional catalog of XML element semantics (`toestand`, `artikel`, `kop`, `lid`, `lijst`, `extref` + `bwb-ng-variabel-deel` attribute). | dutch-law/SKILL.md:239 |
| `[NL-WET-017]` | Structural Index via XML Repository | **hybrid** | Prefilter: URL match against the XML-repository pattern; WebFetch invoked with structural-index extraction prompt. AI input: judge whether the prompt elicits per-element structural data (article number, `bwb-ng-variabel-deel` path, lid count, lidnr values) AND group by hierarchy correctly. Large-statute truncation requires AI to choose drill-down vs summary strategy. **External:** XML repository content. | dutch-law/SKILL.md:270 |
| `[NL-WET-010]` | Following Cross-References | **hybrid** | Prefilter: regex on article text → match common reference patterns ("artikel X", "artikel X van [law]", "Boek X, titel Y"). AI input: judge which pattern applies AND whether the referenced article is in the same BWB ID or a different one; construct a new `/afdrukken` URL accordingly. **External:** statute text + cross-statute BWB ID lookup. | dutch-law/SKILL.md:321 |
| `[NL-WET-011]` | Known Limitations | **semantic** | AI input: recognize each of five limitations (no full-text search / path inconsistency / large sections / historical versions / undocumented endpoint) and adapt the workflow accordingly. **Reference (anchor):** definitional catalog of limitations downstream rules cite. | dutch-law/SKILL.md:339 |
| `[NL-WET-012]` | Fetch Verdict by ECLI | **mechanical** | Predicate: URL pattern → `https://data\.rechtspraak\.nl/uitspraken/content\?id=ECLI:NL:[A-Z]+:\d{4}:\d+`; XML response with `inhoudsindicatie/para` + `section[@role=\"beslissing\"]` + `section[@role=\"overwegingen\"]` extracted via WebFetch. **External:** rechtspraak.nl content endpoint. **Reference (anchor):** definitional catalog of XML element semantics. | dutch-law/SKILL.md:355 |
| `[NL-WET-013]` | ECLI Format | **mechanical** | Predicate: regex `^ECLI:NL:[A-Z]+:\d{4}:\d+$`; court code from the cataloged set (HR / PHR / RVS / CRVB / CBB / GH-* / RB-*). **Reference (anchor):** definitional catalog of court codes. | dutch-law/SKILL.md:394 |
| `[NL-WET-014]` | Search Case Law | **mechanical** | Predicate: URL pattern → `https://data\.rechtspraak\.nl/uitspraken/zoeken\?{params}`; parameters from cataloged set (`max`, `from`, `sort`, `type`, `date`, `modified`, `return`, `subject`, `creator`); subject/creator URIs from cataloged controlled vocabularies. **External:** rechtspraak.nl search endpoint. **Reference (anchor):** definitional catalog of search params + URIs. | dutch-law/SKILL.md:429 |
| `[NL-WET-015]` | Case Law Workflow | **semantic** | AI input: traverse the case-law decision tree (ECLI-known / metadata-described / unclear) and select the correct sub-rule. Citation format requires ECLI / court / date / case number / legal area / link. **Routing:** decision-tree wrapper for case-law lookup. | dutch-law/SKILL.md:486 |
| `[NL-WET-016]` | Case Law Rate Limit | **mechanical** | Predicate: agent-trace → request rate to rechtspraak.nl ≤ 10/sec. Throttle outcome verifiable from request timestamps. **External:** rechtspraak.nl API throttling policy. | dutch-law/SKILL.md:517 |

#### 16.2 dutch-law distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 10 | NL-WET-001, NL-WET-002, NL-WET-005, NL-WET-006, NL-WET-007, NL-WET-009, NL-WET-012, NL-WET-013, NL-WET-014, NL-WET-016 |
| hybrid | 3 | NL-WET-003, NL-WET-017, NL-WET-010 |
| semantic | 4 | NL-WET-004, NL-WET-008, NL-WET-011, NL-WET-015 |

Total 17. Density observation: dutch-law sits at 59% mechanical / 18% hybrid / 24% semantic. The mechanical share is URL-pattern + endpoint-shape rules; the semantic share concentrates on workflow decision trees ([NL-WET-008] / [NL-WET-015]) and granularity-scoping ([NL-WET-004]). **External:** annotation is universal (every rule fetches an external authority) — the entire skill operates on `wetten.overheid.nl` / `repository.officiele-overheidspublicaties.nl` / `data.rechtspraak.nl` / `zoekservice.overheid.nl`. **Reference (anchor):** is heavy ([NL-WET-006] / [NL-WET-007] / [NL-WET-009] / [NL-WET-011] / [NL-WET-012] / [NL-WET-013] / [NL-WET-014]) — definitional catalogs of API parameters, controlled vocabularies, and court codes load-bear for downstream rules.

---

### Part 17 — legal-testing (`Skills/legal-testing/SKILL.md`)

Verified against `SKILL.md` (352 lines, last_reviewed 2026-03-20). All 11 requirement IDs walked.

#### 17.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[LEG-TEST-001]` | Exhaustive Bool? Combinations | **mechanical** | Predicate: AST → for each conditional provision with N `Bool?` inputs, verify a parametric `@Test` exists with `arguments: [...].allCases` (3^N combinations). Closed-form shape check. | legal-testing/SKILL.md:37 |
| `[LEG-TEST-002]` | Success/Failure Partitioning | **hybrid** | Prefilter: AST → parametric tests use `switch argument` with success / failure cases. AI input: judge whether the partition correctly mirrors the provision's logic (OR-logic: at-least-one-true → success; AND-logic: all-true → success; etc.). **External:** statute text for the connective decision. | legal-testing/SKILL.md:81 |
| `[LEG-TEST-003]` | Error Argument Preservation | **mechanical** | Predicate: AST → each failure-case test invokes `try #require(throws: T.Error.self)` AND asserts `error.arguments.X == argument.X` for every input. Two-shape AST check. | legal-testing/SKILL.md:132 |
| `[LEG-TEST-010]` | Error Description Snapshots | **mechanical** | Predicate: AST → each provision with `CustomStringConvertible` Error has at least one inline snapshot test using `assertInlineSnapshot(of: error.description, as: .lines) { ... }`. Closed-form shape. | legal-testing/SKILL.md:155 |
| `[LEG-TEST-011]` | Snapshot Test Infrastructure | **mechanical** | Predicate: AST → each test target with snapshot tests has a `SnapshotTests.swift` file declaring `@MainActor @Suite(.serialized, .snapshots(record: .missing)) struct SnapshotTests {}`. Closed-form shape. | legal-testing/SKILL.md:207 |
| `[LEG-TEST-012]` | Minimum Snapshot Coverage | **hybrid** | Prefilter: AST → snapshot tests cover the three required scenarios (all conditions false / all conditions nil / mixed). AI input: judge whether "mixed" coverage genuinely exercises partial assessment paths AND whether the snapshot description rendering is meaningful. **Reference (illustration):** scenario catalog uses SHOULD; rule's enforceable surface is the three-scenario presence count. | legal-testing/SKILL.md:229 |
| `[LEG-TEST-020]` | Success Construction as Proof | **mechanical** | Predicate: AST → at least one success-case test invokes the provision's typed init AND asserts the constructed value's conclusion property. Two-shape check. | legal-testing/SKILL.md:246 |
| `[LEG-TEST-021]` | Typed Error Verification | **mechanical** | Predicate: regex/AST → tests use `#require(throws: T.Error.self)` (specific error type); `#expect(throws: (any Error).self)` forbidden. Counter-pattern grep. | legal-testing/SKILL.md:269 |
| `[LEG-TEST-030]` | Ternary Logic Truth Tables | **hybrid** | Prefilter: AST → for provisions using `Bool?.any { }` / `Bool?.all { }` / `.map { !$0 }`, verify presence of edge-case tests for nil-mixing. AI input: judge whether the truth-table coverage exercises the four canonical Kleene K3 edge cases. **Reference (anchor):** definitional anchor for K3 truth-table behavior. | legal-testing/SKILL.md:292 |
| `[LEG-TEST-040]` | Test File Naming | **mechanical** | Predicate: filesystem → for each source file `{TypePath}.swift`, the corresponding test file is `{TypePath} Tests.swift` (same path mirroring). Filename-shape regex. | legal-testing/SKILL.md:310 |
| `[LEG-TEST-041]` | Test Target Dependencies | **mechanical** | Predicate: Package.swift parse → legal test targets include `StandardsTestSupport` (for `.allCases`) AND `InlineSnapshotTesting` (for `assertInlineSnapshot`). Two-dependency presence check. | legal-testing/SKILL.md:324 |

#### 17.2 legal-testing distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 8 | LEG-TEST-001, LEG-TEST-003, LEG-TEST-010, LEG-TEST-011, LEG-TEST-020, LEG-TEST-021, LEG-TEST-040, LEG-TEST-041 |
| hybrid | 3 | LEG-TEST-002, LEG-TEST-012, LEG-TEST-030 |
| semantic | 0 | — |

Total 11. Density observation: legal-testing is mechanical-dominant (73%) with zero pure-semantic rules. Test rules are AST-shape predicates (test-presence, error-type matching, snapshot-infrastructure files, dependency-presence). The hybrid share concentrates on rules that need to mirror statutory connectives or K3 edge-case understanding ([LEG-TEST-002] / [LEG-TEST-030]) or scenario-meaningfulness judgment ([LEG-TEST-012]). The hybrid count would shift toward mechanical if the parametric-test infrastructure can fully mechanize "the statute connective is OR" detection — but that ties back into [LEG-ENC-005] which already classifies hybrid.

---

### Part 18 — rule-law-core (`Skills/rule-law-core/SKILL.md`)

Verified against `SKILL.md` (201 lines, last_reviewed 2026-03-20). All 7 requirement IDs walked.

#### 18.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[RL-CORE-001]` | Artifact Authority | **mechanical** | Predicate: filesystem → presence of authoritative artifacts at cited paths (`rule-law/Skills/`, `rule-law/ARCHITECTURE.md`, `rule-law/Research/`, `swift-nl-wetgever/Research/`); their authority class (CANONICAL vs AUTHORITATIVE). **Reference (anchor):** definitional anchor; downstream skills cite this manifest. | rule-law-core/SKILL.md:30 |
| `[RL-CORE-002]` | Skill Ownership | **mechanical** | Predicate: filesystem → legal-domain skills under `rule-law/Skills/`; process skills under `swift-institute/Skills/`. Path-membership check per the three-row table. **Reference (anchor):** definitional anchor for skill placement. | rule-law-core/SKILL.md:48 |
| `[RL-CORE-010]` | Legal Skill Registry | **mechanical** | Predicate: filesystem → all legal-domain skills (`rule-law-core`, `legal-encoding`, `legal-testing`) registered with layer + description + IDs. Catalog-membership check. **Reference (anchor):** definitional anchor — the registry IS the index downstream rules consult. | rule-law-core/SKILL.md:69 |
| `[RL-CORE-011]` | Skill Loading DAG | **mechanical** | Predicate: skill front-matter `requires:` graph → Level 0 (rule-law-core, no deps) → Level 1 (legal-encoding requires rule-law-core, naming, errors, implementation) → Level 2 (legal-testing requires rule-law-core, legal-encoding, testing). DAG-shape check. **Reference (anchor):** definitional anchor for skill loading order. | rule-law-core/SKILL.md:98 |
| `[RL-CORE-020]` | Legal Architecture Layers | **mechanical** | Predicate: Package.swift dependency-graph → for each legal package, classify into Layer 1 / 2a / 2b / 3 / 4 by name pattern + dependency direction; verify only-downward-deps invariant. **Reference (anchor):** definitional anchor cross-cited by [LEG-ENC-045]. **Composite:** path-pattern check + dependency-direction check at the package-graph level — same-shape as [LEG-ENC-045] but framed at the architecture-manifest level. | rule-law-core/SKILL.md:116 |
| `[RL-CORE-030]` | Legal Package Paths | **mechanical** | Predicate: filesystem → known repositories at the cited paths (`/Users/coen/Developer/rule-law/`, `/Users/coen/Developer/rule-law/rule-law-nl/`, `/Users/coen/Developer/rule-law/rule-law-us-nv/`, `/Users/coen/Developer/swift-nl-wetgever/`); package-name-pattern → resolution-path mapping table. **Reference (anchor):** definitional anchor for package resolution. | rule-law-core/SKILL.md:150 |
| `[RL-CORE-040]` | Research Triage for Legal Tech | **semantic** | AI input: classify each research document by scope (single-statute / legislature-wide / cross-layer / single-composition-package) and route to the matching `Research/` directory. **Routing:** decision-tree wrapper over scope-based research placement. | rule-law-core/SKILL.md:177 |

#### 18.2 rule-law-core distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 6 | RL-CORE-001, RL-CORE-002, RL-CORE-010, RL-CORE-011, RL-CORE-020, RL-CORE-030 |
| hybrid | 0 | — |
| semantic | 1 | RL-CORE-040 |

Total 7. Density observation: rule-law-core is overwhelmingly mechanical (86%) — every rule except [RL-CORE-040] is a filesystem/Package.swift/skill-front-matter shape predicate. **Reference (anchor):** is the dominant pattern (6 of 7) — the entire skill is a definitional manifest, paralleling `swift-institute-core` from tier-2 which had the same shape. The single semantic rule ([RL-CORE-040]) is a Routing wrapper for research-document scope classification, mirroring [RES-002a] from research-process.

---

### Part 19 — swift-forums-review (`Skills/swift-forums-review/SKILL.md`)

Verified against `SKILL.md` (507 lines, last_reviewed 2026-04-30). All 20 requirement IDs walked.

#### 19.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[FREVIEW-001]` | Corpus-grounding | **mechanical** | Predicate: assert `analysis/*.json` files were opened before any simulation/predict output is emitted. Shell can verify file-mtime >= invocation-time and that the four named files exist. **Composite:** also forbids fabrication, which is semantic — but the file-presence half is mechanical and acts as gate. | swift-forums-review/SKILL.md:51 |
| `[FREVIEW-002]` | Package characterization is the first step | **mechanical** | Predicate: assert `scripts/characterize_package.py` was invoked and its output (`predicted_angle_weights`) is referenced in the simulation artifact. Shell + JSON-schema check. | swift-forums-review/SKILL.md:64 |
| `[FREVIEW-003]` | Archetype selection rules | **hybrid** | Prefilter: count distinct `archetype_label` entries in JSON sidecar, assert 6 ≤ N ≤ 12, assert ≥1 `process/procedure` archetype and ≥1 `short +1/nit` archetype present. AI: judge whether the weight ranking actually reflects `size_pct × max(angle_mean × package_angle_score)` — formula auditability requires reading the angle-overlap argument. | swift-forums-review/SKILL.md:82 |
| `[FREVIEW-004]` | Per-post grounding | **hybrid** | Prefilter: each post must have `persona_archetype_cluster`, `persona_archetype_label`, `dominant_angles`, `opener_pattern`, `closer_pattern`, `body_markdown` JSON keys; word_count within `[0.5×, 2×]` of archetype mean; HTML comment marker present. AI: judge whether vocabulary actually overlaps the archetype's top terms (TF-IDF check is mechanical, but tone/term-coherence judgment is semantic). | swift-forums-review/SKILL.md:99 |
| `[FREVIEW-005]` | Opener / closer diversity | **mechanical** | Predicate: count opener/closer pattern occurrences across the simulated thread; assert no single pattern exceeds ~30% of posts; assert empirical distribution within tolerance of `openers_closers.json` frequencies. Pure histogram-comparison. | swift-forums-review/SKILL.md:129 |
| `[FREVIEW-006]` | No generic reviewer text | **hybrid** | Prefilter: each post must contain ≥1 backticked-CamelCase identifier OR file-path token (`Sources/...\.swift`) OR file-line ref (`...\.swift:\d+`) drawn from the actual package source. AI: judge whether the post is anchored on a *real* feature vs a coincidentally-shaped string. | swift-forums-review/SKILL.md:140 |
| `[FREVIEW-007]` | Simulate-mode output contract | **mechanical** | Predicate: assert both files exist at `<package>/Audits/forums-review/forums-review-simulation-<YYYY-MM-DD>.{md,json}`; YAML frontmatter contains required keys (`package`, `path`, `simulated_date`, `predicted_category`, `archetypes`); JSON sidecar matches the schema enumerated. JSON-schema validation. | swift-forums-review/SKILL.md:154 |
| `[FREVIEW-008]` | Predict-mode output contract | **hybrid** | Prefilter: both files exist at the predict-mode paths; markdown contains top-5 angle sections. AI: judge whether per-angle "what triggered the multiplier" cites *specific source-file evidence* (vs generic claims) and whether mitigation suggestions are coherent with the cited evidence. | swift-forums-review/SKILL.md:183 |
| `[FREVIEW-009]` | Venue prediction | **hybrid** | Prefilter: simulation declares one of `related-projects`, `community-showcase`, `evolution/...`, etc. AI: judge whether predicted venue is correct given package layer/nature (the lookup table is rules-based, but layer-detection of mixed/edge cases is semantic). | swift-forums-review/SKILL.md:200 |
| `[FREVIEW-010]` | Do not post simulations | **mechanical** | Predicate: assert generated handles match `@reviewer-<cluster-id>` regex; assert no operations attempt to post to forums/Bluesky/Discord; assert no usernames from `archetypes.json` samples appear verbatim in output. Shell + regex check. | swift-forums-review/SKILL.md:214 |
| `[FREVIEW-011]` | Refresh atomicity | **mechanical** | Predicate: when `corpus_state` frontmatter or any cluster-id changes, assert that ALL of (post bodies, HTML archetype comments, JSON cluster_id fields, prose corpus references) were rewritten — i.e., file-diff touched all four sections. Shell+grep check. **Composite:** the alternative of writing `superseded_by:` instead is also mechanically detectable. | swift-forums-review/SKILL.md:264 |
| `[FREVIEW-012]` | Archetype-vs-substance triage | **hybrid** | Prefilter: count concreteness anchors per post (file paths, line refs, backticked CamelCase, SE-XXXX/SP-XXXX/ST-XXXX refs) per the explicit rule; pre-classify by anchor count thresholds (≥3, 2, 0–1). AI: final classification when the agent escapes the pre-class via "low anchors but real semantic concern" (the rule explicitly authorizes this escape). | swift-forums-review/SKILL.md:282 |
| `[FREVIEW-013]` | Venue-angle deflation | **mechanical** | Predicate: assert `prepare_simulation.py` loaded `critique_angles_by_venue.json` whenever target venue ≠ `evolution-*`; assert per-venue base-rate keys match the documented mapping table. Pure config-load check. | swift-forums-review/SKILL.md:317 |
| `[FREVIEW-014]` | Terminal-posture detection | **hybrid** | Prefilter: case-insensitive grep of README.md/CHANGELOG.md for the explicit framings (`terminal <version>`, `final shape`, `shape committed`, `FINAL`, `feature-complete`, etc.); if hit, assert characterizer output sets `terminal_posture=true` and applies 0.5× multiplier to `evolution-process` and `abi-source-stability`. AI: judge corner cases (e.g., terminal language used metaphorically, or hedged "approaching feature-complete"). | swift-forums-review/SKILL.md:344 |
| `[FREVIEW-015]` | Temporal correction via era multiplier (implemented) | **mechanical** | Predicate: assert `prepare_simulation.py` calls `infer_era()` from characterizer output; assert effective base rate per angle = `venue_base_pct × era_multiplier` from `critique_angles_by_era.json`; `--era` flag override is honored. Numerical check. | swift-forums-review/SKILL.md:364 |
| `[FREVIEW-016]` | Post-authoring triage is mandatory | **mechanical** | Predicate: assert `scripts/triage_simulation.py <simulation.md>` was invoked; assert one triage markdown + one triage JSON exist beside the simulation file; assert each non-OP post has anchor count, pre-classification, and `_pending` final-classification/disposition keys in JSON. File-existence + JSON-schema check. | swift-forums-review/SKILL.md:383 |
| `[FREVIEW-018]` | Anchor correctness verification (consumer-side) | **semantic** | Predicate: judge whether each anchor-grounded factual claim in load-bearing posts is actually true (file:line really contains X with claimed shape; grep counts in correct scope; `#if` chain correctly read; semantic property Z verified). Cannot mechanize: requires reading source and comparing to claim narrative. **Composite:** the four claim-form rows in the table each define a distinct verification protocol. | swift-forums-review/SKILL.md:399 |
| `[FREVIEW-017]` | Weight Calibration Against Observed Reception — PENDING | **semantic** | Predicate: pending-data placeholder; consumers MUST NOT follow until ≥5 observed-reception records accumulate. Currently a methodology document. **API-Gap:** the calibration data and `calibrate_weights.py` fit do not yet exist; the rule is documented for future activation. **Reference (anchor):** retain — it anchors calibration methodology against the "uncalibrated weights" honesty stance referenced under "Why". | swift-forums-review/SKILL.md:424 |
| `[FREVIEW-019]` | Re-Simulation Cadence After Substantial Recent Changes | **hybrid** | Prefilter: detect "substantial recent changes" trigger via commit-count and file-touch heuristics (README rewrite, source restructure, dep-graph change, workflow trim, vision consolidation, test-suite naming sweep); detect prior-simulation existence; verify outputs at the post-2026-04-29 paths. AI: judge what counts as "substantial" qualitatively per the explicit "qualitative threshold" clause; diff prior triage against new triage to flag persistently-load-bearing critiques. **Routing:** caller-context clause (Phase 4 of release-readiness) makes the rule mandatory in one mode and optional otherwise. | swift-forums-review/SKILL.md:445 |
| `[FREVIEW-020]` | Delta Re-Simulation Mode for Low-Change Windows | **mechanical** | Predicate: trigger checks (a) prior simulation exists, (b) <10 commits since prior sim, (c) LOC / public-decl-count delta <10% — all three are shell-checkable. Output goes to single `Audits/audit.md` section, not new files. **Routing:** falls through to FREVIEW-019 if any trigger fails; major-version bumps and pre-launch are explicit non-applicability gates. | swift-forums-review/SKILL.md:468 |

#### 19.2 swift-forums-review distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 10 | FREVIEW-001, FREVIEW-002, FREVIEW-005, FREVIEW-007, FREVIEW-010, FREVIEW-011, FREVIEW-013, FREVIEW-015, FREVIEW-016, FREVIEW-020 |
| hybrid | 8 | FREVIEW-003, FREVIEW-004, FREVIEW-006, FREVIEW-008, FREVIEW-009, FREVIEW-012, FREVIEW-014, FREVIEW-019 |
| semantic | 2 | FREVIEW-017, FREVIEW-018 |

Total 20.

Density observation: heavy mechanical/hybrid load reflects the script-orchestrated nature of the skill — Python scripts produce structured artifacts whose contracts are JSON-schema-checkable. Semantic class concentrates on the consumer-facing correctness verification (FREVIEW-018) and the not-yet-active calibration methodology (FREVIEW-017).

### Part 20 — document-markup (`Skills/document-markup/SKILL.md`)

Verified against `SKILL.md` (723 lines, last_reviewed 2026-03-20). All 17 requirement IDs walked.

#### 20.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[DOC-MARKUP-001]` | Package Selection | **hybrid** | Prefilter: assert `import` statement matches one of the documented options (`HTML`, `PDF`, `PDF_Rendering`); assert layer per package matches the documented row. AI: judge correctness of the goal-to-import mapping in ambiguous cases (e.g., "Markdown as PDF" can be served by either `import PDF` or narrower combinations). **Routing:** decision-table with goal → import + layer; the choice is authorial routing. | document-markup/SKILL.md:33 |
| `[DOC-MARKUP-010]` | HTML Document Structure | **mechanical** | Predicate: AST-check that `HTML.Document` is used with body and head builder closures; assert lowercase typealiases (`div`, `h1`, `p`, `a`) appear in body; serialization paths use `try String(page)` or `try [UInt8](page)` shape. Pure AST/grep. **Reference (illustration):** the rendering-to-bytes/string code samples are illustrative, not normative. | document-markup/SKILL.md:61 |
| `[DOC-MARKUP-011]` | HTML Elements | **mechanical** | Predicate: assert HTML element identifiers in body builders are lowercase typealiases drawn from the documented table (`div`/`span`/`p`/`h1`-`h6`/`a`/`img`/etc.). AST/grep over user code. **Reference (anchor):** the typealias-to-WHATWG mapping table is definitional; retain as anchor. | document-markup/SKILL.md:99 |
| `[DOC-MARKUP-012]` | CSS Styling | **hybrid** | Prefilter: assert `.css` accessor is used for styling; CSS property names match W3C spec mirroring (`.fontSize`, `.backgroundColor`, `.borderRadius`); typed CSS units used (`.px()`, `.rem()`, etc.). AI: judge correctness of dark-mode pairs and conditional/property-grouping intent. | document-markup/SKILL.md:141 |
| `[DOC-MARKUP-013]` | Custom HTML Views | **mechanical** | Predicate: AST-check that custom views conforming to `HTML.View` are nested per `[API-NAME-001]` Nest.Name pattern (no top-level compound `Card`/`MyCard` types); `var body: some HTML.View` shape verified. Cross-reference to `[API-NAME-001]` is mechanical. | document-markup/SKILL.md:175 |
| `[DOC-MARKUP-020]` | PDF Document from HTML | **mechanical** | Predicate: AST-check `PDF.Document` invocation accepts `@HTML.Builder` closure; serialization is `[UInt8](document)`; `info: .init(...)` shape is matched if metadata is supplied. Pure AST grep. | document-markup/SKILL.md:227 |
| `[DOC-MARKUP-021]` | PDF Configuration | **mechanical** | Predicate: AST-check `PDF.HTML.Configuration` parameters match the enumerated set (`paperSize`, `margins`, `defaultFont`, `defaultFontSize`, `defaultColor`, `lineHeight`, `table`, `outline`); paper sizes drawn from `.a3`/`.a4`/`.a5`/`.letter`/`.legal`/`.tabloid`/custom rectangle; fonts drawn from PDF Standard 14 set. Enumeration check. **Reference (illustration):** sample config block is illustrative. | document-markup/SKILL.md:273 |
| `[DOC-MARKUP-022]` | Headers and Footers | **mechanical** | Predicate: AST-check two-pass `PDF.HTML.pages(...)` invocation with `header:` and `footer:` closures over `Page.Info`; `documentTitle`, `pageNumber`, `totalPages` accessors used as documented. AST/grep. | document-markup/SKILL.md:316 |
| `[DOC-MARKUP-023]` | Tables in PDF | **mechanical** | Predicate: AST-check tables use `table { thead { tr { th } } tbody { tr { td } } }` element nesting; `colspan`/`rowspan` attribute names accepted. AST-shape check. | document-markup/SKILL.md:359 |
| `[DOC-MARKUP-024]` | Lists in PDF | **mechanical** | Predicate: AST-check `ul`/`ol` builders with `li` children; nesting allowed; document marker progression (disc → circle → square; arabic numerals) is rendering-engine-determined, not authored. **Reference (illustration):** marker-progression note is informational. | document-markup/SKILL.md:393 |
| `[DOC-MARKUP-030]` | Markdown to HTML | **mechanical** | Predicate: AST-check `Markdown { ... }` view receives a string literal closure; conforms to `HTML.View`; composes inside `HTML.Document` body. AST/grep. | document-markup/SKILL.md:426 |
| `[DOC-MARKUP-031]` | Markdown Configuration | **hybrid** | Prefilter: AST-check `Markdown.Configuration` and `Markdown.Rendering` are configured per documented shape; `rendering.elements.heading`, `rendering.elements.codeBlock`, `config.slugGenerator` accessors used. AI: judge whether custom rendering frames preserve the parsed markdown structure (e.g., `Rendering.Frame.Placeholder()` correctly receives the children). | document-markup/SKILL.md:475 |
| `[DOC-MARKUP-032]` | Markdown to PDF | **mechanical** | Predicate: AST-check `Markdown` view embedded inside `PDF.Document` builder; `generateOutline: true` makes headings PDF bookmarks. Pure AST/grep. | document-markup/SKILL.md:516 |
| `[DOC-MARKUP-033]` | Table of Contents from Markdown | **mechanical** | Predicate: AST-check `Markdown.tableOfContents(from:configuration:rendering:)` invocation returns `[Markdown.Section]` with `.title`, `.id`, `.level`, `.timestamp` fields. API-shape check. | document-markup/SKILL.md:556 |
| `[DOC-MARKUP-034]` | Block Directives | **hybrid** | Prefilter: AST-check `config.directives = .init { directive in switch directive.name { ... } }` shape; built-in directives (`@Button`, `@Comment`, `@Video`, `@T`) recognized; custom directive case returns `.rendered(...)` or `.useDefault`. AI: judge whether the custom directive HTML output is well-formed and reflects directive intent. | document-markup/SKILL.md:578 |
| `[DOC-MARKUP-040]` | PDF.View Protocol | **mechanical** | Predicate: AST-check `PDF.View` conformance; custom views nested per `[API-NAME-001]`; primitives (`PDF.Text`, `PDF.VStack`, `PDF.HStack`, `PDF.Spacer`, `PDF.Divider`, `PDF.Rectangle`, `PDF.Element`) drawn from documented set. AST/grep. | document-markup/SKILL.md:620 |
| `[DOC-MARKUP-050]` | Serialization | **mechanical** | Predicate: AST-check serialization paths are `[UInt8](document)` or `document.write(to: File(...), options: ...)`. Pure AST/grep. | document-markup/SKILL.md:672 |

#### 20.2 document-markup distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 13 | DOC-MARKUP-010, DOC-MARKUP-011, DOC-MARKUP-013, DOC-MARKUP-020, DOC-MARKUP-021, DOC-MARKUP-022, DOC-MARKUP-023, DOC-MARKUP-024, DOC-MARKUP-030, DOC-MARKUP-032, DOC-MARKUP-033, DOC-MARKUP-040, DOC-MARKUP-050 |
| hybrid | 4 | DOC-MARKUP-001, DOC-MARKUP-012, DOC-MARKUP-031, DOC-MARKUP-034 |
| semantic | 0 | (none) |

Total 17.

Density observation: this skill is API-shape-and-naming heavy; the rules describe how to invoke library functions correctly, which is highly mechanical (AST-grep + enumeration). The hybrid class concentrates on configuration interpretation where intent matters (CSS dark-mode pairing, Markdown rendering frames, custom directives output coherence). No purely semantic rule — all rules trace back to invocations the compiler/AST already constrains.

### Part 21 — testing-swiftlang (`Skills/testing-swiftlang/SKILL.md`)

Verified against `SKILL.md` (685 lines, last_reviewed 2026-04-30). All 16 requirement IDs walked.

#### 21.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[SWIFT-TEST-001]` | TestSuites Macro Usage | **mechanical** | Predicate: AST-check that types use `#TestSuites` (current) or `#Tests` (future) macro; if macro unavailable, manual fallback uses `@Suite struct Test` with the four nested suites (`Unit`, `` `Edge Case` ``, `Integration`, `@Suite(.serialized) Performance`). Pure AST/grep. **Composite:** SHOULD-form rule with three named-form-equivalents (current macro / future macro / manual fallback). | testing-swiftlang/SKILL.md:29 |
| `[SWIFT-TEST-002]` | Type Extension Pattern | **mechanical** | Predicate: AST-check that non-generic types use `extension <Type> { @Suite struct Test { ... } }` shape, not `struct CompoundNameTests`. Cross-reference to `[API-NAME-001]`/`[API-NAME-002]` (compound names forbidden). | testing-swiftlang/SKILL.md:72 |
| `[SWIFT-TEST-003]` | Generic Type Exception | **mechanical** | Predicate: AST-check that generic types (or extensions on generic types, including concrete specializations) use parallel-namespace `@Suite struct \`<Name> Tests\`` rather than `extension <GenericType> { @Suite struct Test }`. Two failure modes (compile-error vs silent-non-discovery) but both detectable by AST shape. **Composite:** the rule subsumes both `extension Generic` and `extension Generic<Concrete>`. | testing-swiftlang/SKILL.md:109 |
| `[SWIFT-TEST-004]` | Performance Suite Serialization | **mechanical** | Predicate: AST-check that any suite named `Performance` carries `.serialized` trait. Pure AST/grep. | testing-swiftlang/SKILL.md:175 |
| `[SWIFT-TEST-005]` | Test Naming Pattern | **mechanical** | Predicate: AST-check that `@Test` macro has no string parameter; backtick-delimited descriptive function name with no `test`-prefix or camelCase identifier. Pure AST/grep. | testing-swiftlang/SKILL.md:197 |
| `[SWIFT-TEST-006]` | Test Implementation Pattern | **semantic** | Predicate: judge whether the test body follows the arrange-act-assert sequence. AI must read what each line does and classify it as setup, action, or assertion. Mechanical detection of `defer { … }` blocks for cleanup is possible, but the AAA structure is intent. | testing-swiftlang/SKILL.md:234 |
| `[SWIFT-TEST-007]` | Observable Property Testing | **mechanical** | Predicate: AST-check that `~Copyable` types are tested via property accessors (`arena.capacity`, `arena.allocated`, `arena.remaining`) rather than copy-and-compare; assert no `let copy = original` shape on `~Copyable` types. AST/grep with type-info from compiler. | testing-swiftlang/SKILL.md:263 |
| `[SWIFT-TEST-008]` | Mutation Testing Pattern | **mechanical** | Predicate: AST-check that `~Copyable` mutation tests use `var` bindings on `~Copyable` types and call mutating methods; no copy via assignment. Pure AST/grep. | testing-swiftlang/SKILL.md:296 |
| `[SWIFT-TEST-009]` | Consuming Operation Testing | **mechanical** | Predicate: AST-check that consuming operations (e.g., `.move()`, `.consume`) appear at end of test body — no further accesses to the value after consumption. Compiler-enforced too — using a consumed value is a hard error. | testing-swiftlang/SKILL.md:321 |
| `[SWIFT-TEST-010]` | Helper Functions for ~Copyable | **mechanical** | Predicate: AST-check that helpers operating on `~Copyable` parameters use `borrowing` keyword. Pure AST/grep. | testing-swiftlang/SKILL.md:357 |
| `[SWIFT-TEST-014]` | ~Copyable Values in #expect | **mechanical** | Predicate: AST-check that `#expect` arguments do not directly reference `~Copyable` values (extracted to local Copyable bindings first); no `~Copyable` values in `Array<...>`; no `== nil` on `~Copyable` Optional; task-group closures wrap `~Copyable` state in a generic `Harness<State>` per `[TEST-023]`. **Composite:** four sub-rules but each is AST-detectable. | testing-swiftlang/SKILL.md:387 |
| `[SWIFT-TEST-011]` | Async Expect Bindings | **mechanical** | Predicate: AST-check that `#expect(<lhs> == <rhs>)` does not contain two `await` expressions in one macro invocation; both sides extracted to `let` bindings first. Pure AST/grep. | testing-swiftlang/SKILL.md:480 |
| `[SWIFT-TEST-012]` | Foundation-Free Isolation Verification | **mechanical** | Predicate: AST-check that primitives-layer tests use `pthread_main_np()` (under `#if canImport(Darwin)`) for main-actor verification, not `Thread.isMainThread`; assert no `import Foundation` in primitives tests. Pure AST/grep. | testing-swiftlang/SKILL.md:508 |
| `[SWIFT-TEST-013]` | Model-Based Testing | **semantic** | Predicate: judge whether complex data structures include model tests with reference implementation comparison. SHOULD-rule; the model-test pattern is a design choice, not a syntactic shape — different correct implementations of the pattern are valid. AI must judge what counts as a "complex data structure" requiring this pattern. **Reference (illustration):** the `ReferenceModel<Element>` example is illustrative — AI must apply the pattern to other structures. | testing-swiftlang/SKILL.md:541 |
| `[SWIFT-TEST-015]` | @Test Symbol Length at Deep Nesting | **hybrid** | Prefilter: count nesting levels in test file; if path exceeds 4 levels and many tests in one file, flag for review. AI: judge whether the file split actually reduces aggregate symbol mangled-name length below the (undocumented) compiler threshold. **API-Gap:** there is no compiler API to check the real threshold; the rule is empirical. | testing-swiftlang/SKILL.md:584 |
| `[SWIFT-TEST-016]` | Macro Test Framework — Generic Helper, No XCTest, No Foundation | **mechanical** | Predicate: AST-check that macro tests `import SwiftSyntaxMacrosGenericTestSupport` (not `SwiftSyntaxMacrosTestSupport`); `assertMacroExpansion` invocation supplies `failureHandler:` closure routing to `Issue.record`; no `import XCTest`/`import Foundation`. **Composite:** rule also requires a real-`swift build` integration test for `@attached(...)` form-vs-site validation, which is a build-system check rather than a unit-test check. | testing-swiftlang/SKILL.md:614 |

#### 21.2 testing-swiftlang distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 13 | SWIFT-TEST-001, SWIFT-TEST-002, SWIFT-TEST-003, SWIFT-TEST-004, SWIFT-TEST-005, SWIFT-TEST-007, SWIFT-TEST-008, SWIFT-TEST-009, SWIFT-TEST-010, SWIFT-TEST-011, SWIFT-TEST-012, SWIFT-TEST-014, SWIFT-TEST-016 |
| hybrid | 1 | SWIFT-TEST-015 |
| semantic | 2 | SWIFT-TEST-006, SWIFT-TEST-013 |

Total 16.

Density observation: testing-swiftlang is highly mechanical because it codifies how to use the Apple Swift Testing framework's macro shapes — most rules are AST/grep-checkable. The semantic class catches the structural patterns (arrange-act-assert flow; model-based testing inclusion) that require AI/human judgment. The single hybrid (`SWIFT-TEST-015`) reflects an empirical compiler limitation without a public API to verify against directly.

### Part 22 — swift-pull-request (`Skills/swift-pull-request/SKILL.md`)

Verified against `SKILL.md` (407 lines, last_reviewed 2026-03-24). All 11 requirement IDs walked.

#### 22.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[SWIFT-PR-001]` | Fork and Remote | **mechanical** | Predicate: assert `git remote -v` shows `origin` (swiftlang) and `myfork` (user fork); assert `gh repo fork` was run if user lacked commit access. Shell-checkable. | swift-pull-request/SKILL.md:29 |
| `[SWIFT-PR-011]` | Check Latest Swift Before Deep-Diving | **mechanical** | Predicate: assert `TOOLCHAINS=swift xcrun swiftc ...` (or `swift build -c release`) was invoked against the dev toolchain on the reproducer before any PR/issue work; the test result determines whether further investigation continues. Shell trace + history-check. | swift-pull-request/SKILL.md:56 |
| `[SWIFT-PR-002]` | Branch Creation | **mechanical** | Predicate: assert branch name is kebab-case (regex `^[a-z][a-z0-9-]*$` with optional `<username>/` or `<component>-` prefix); assert PR targets `main`. Pure shell + regex. **Reference (illustration):** the three observed-pattern bullets are illustrative; only the kebab-case + targets-main constraint is normative. | swift-pull-request/SKILL.md:80 |
| `[SWIFT-PR-003]` | Commit Message Format | **mechanical** | Predicate: regex-check commit message against `^\[<Tag>\] |^<Tag>: |^NFC: ` shape with tags drawn from the documented area-to-tag table; subject ≤ ~70 chars; body separated by blank line; `Resolves https://github.com/swiftlang/swift/issues/N` line if applicable. **Composite:** three accepted bracket/colon styles + `NFC:` + backtick-identifier conventions. | swift-pull-request/SKILL.md:97 |
| `[SWIFT-PR-004]` | New Source File Headers | **mechanical** | Predicate: AST/grep-check that new `.swift`/`.cpp`/`.h` files contain the Apache 2.0 + Runtime Library Exception header with current year; SIL test files (`test/...`) exempt; in-code issue refs use GitHub URLs not `rdar://`. Pure regex match against template. | swift-pull-request/SKILL.md:135 |
| `[SWIFT-PR-005]` | Test Requirements | **hybrid** | Prefilter: assert that the PR diff includes at least one new/modified test in the directory matching the change area (`test/SILOptimizer/`, `test/SILGen/`, `test/Sema/`, `test/IRGen/`, `test/Interpreter/`, `test/SILOptimizer/lifetime_dependence/`); assert SIL test pattern includes `// RUN:`, `// REQUIRES:`, `sil_stage canonical`, `// CHECK-LABEL:` markers. AI: judge whether the test is at the *nearest* abstraction level (SIL pass change should not be tested only at end-to-end interpreter level) and whether the test is *reduced as much as possible* (minimality is a judgment call). | swift-pull-request/SKILL.md:168 |
| `[SWIFT-PR-006]` | PR Body | **hybrid** | Prefilter: assert PR body does NOT contain the default HTML comment template; assert AI-disclosure line present if the change was AI-assisted; assert structure follows bug-fix template (Description, Root cause, Fix, Test plan, Resolves) or features template. AI: judge whether the description and rationale are coherent given the change. **Composite:** template-compliance is mechanical; rationale-quality is semantic. **External:** AI-disclosure link to PR #88025 review is a non-normative reference. | swift-pull-request/SKILL.md:229 |
| `[SWIFT-PR-007]` | PR Creation | **mechanical** | Predicate: assert `gh pr create --repo swiftlang/swift --base main --head <username>:<branch> --title "[Component] Description" --body "..."` was the invocation; assert `.swift-version` and unrelated files are not in the commit. Shell-trace check. | swift-pull-request/SKILL.md:273 |
| `[SWIFT-PR-008]` | CI Triggers | **mechanical** | Predicate: assert no contributor-without-commit-access attempted `@swift-ci ...` self-comment on a PR; the rule is a behavioral injunction with a Boolean test (did the contributor post a `@swift-ci` command?). Shell + GitHub API check. | swift-pull-request/SKILL.md:311 |
| `[SWIFT-PR-009]` | Reviewer Identification | **mechanical** | Predicate: assert CODEOWNERS lookup was performed (e.g., `cat .github/CODEOWNERS | grep <path>` or `gh api ... CODEOWNERS`); auto-assignment occurs on non-draft PR creation; targeted-review requests cite either CODEOWNERS or empirical-reviewer table. **Reference (anchor):** the path-pattern → owner table is a snapshot from 2026-03-22, so it is a non-normative reference snapshot that may drift. | swift-pull-request/SKILL.md:332 |
| `[SWIFT-PR-010]` | End-to-End Checklist | **mechanical** | Predicate: assert each checklist item was performed (test against latest dev toolchain → bug reproduces on Xcode → branch created → tests written → llvm-lit ran clean → existing tests verified → Apache header added → issue ref verified → specific files staged → conventional commit → push to fork → AI disclosure → `gh pr create` → CODEOWNERS auto-assigned → wait for CI → address feedback no force-push). All items are shell-checkable. **Composite:** 17 sub-checks bound by an aggregate completion clause. **Routing:** the two final guidance items (PR-split protocol, no-force-push) are conditional on review feedback. | swift-pull-request/SKILL.md:370 |

#### 22.2 swift-pull-request distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 9 | SWIFT-PR-001, SWIFT-PR-011, SWIFT-PR-002, SWIFT-PR-003, SWIFT-PR-004, SWIFT-PR-007, SWIFT-PR-008, SWIFT-PR-009, SWIFT-PR-010 |
| hybrid | 2 | SWIFT-PR-005, SWIFT-PR-006 |
| semantic | 0 | (none) |

Total 11.

Density observation: swift-pull-request is operational — it codifies upstream Swift project process (forks, branches, conventional commit format, PR templates, CI triggers, reviewer assignment). Most rules reduce to shell + regex + git-history checks. The hybrid class (`SWIFT-PR-005`, `SWIFT-PR-006`) captures the rules where prose quality (test minimality, PR rationale coherence) requires AI/human judgment beyond template compliance.

### Part 23 — testing-institute (`Skills/testing-institute/SKILL.md`)

Verified against `SKILL.md` (290 lines, last_reviewed 2026-03-27). All 9 requirement IDs walked.

#### 23.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[INST-TEST-001]` | Nested Package Requirement | **mechanical** | Predicate: assert any package using performance/snapshot/`#Tests`-macro tests has a `Tests/Package.swift` nested package; assert main `Package.swift` does NOT depend on swift-testing directly. Shell + grep check on Package.swift content. | testing-institute/SKILL.md:39 |
| `[INST-TEST-002]` | Nested Package Location | **mechanical** | Predicate: assert nested `Tests/Package.swift` exists at the documented path; test directories are flat siblings under `Tests/` (no `Tests/Testing/Tests/` stutter); parent `Package.swift` test targets declare explicit `path:` parameter pointing to `Tests/<Name> Tests`. Pure shell + AST check. | testing-institute/SKILL.md:51 |
| `[INST-TEST-003]` | `#Tests` Macro Scaffolding (Recommended) | **mechanical** | Predicate: assert that packages defining their own types use `#Tests` macro for scaffolding (with `snapshots: .init(recording: .missing)`); manual `@Suite` only when extending stdlib types or protocols. AST/grep. SHOULD-rule; non-applicability is mechanical (stdlib-extension detection). | testing-institute/SKILL.md:86 |
| `[INST-TEST-004]` | Nested Package.swift Template | **mechanical** | Predicate: AST-check the nested `Package.swift` matches the template — name `"testing"`, swift-tools-version 6.2, `.macOS(.v26)`, dependencies on `..` and swift-testing relative path; test targets declare explicit `path:`; ecosystem swift-settings (`ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`) applied to all targets. **Composite:** seven sub-fields each independently checkable. | testing-institute/SKILL.md:122 |
| `[INST-TEST-005]` | Relative Path Calculation | **mechanical** | Predicate: assert the path-to-swift-testing matches the documented pattern based on parent-repo location (primitives → `../../../swift-foundations/swift-testing`, etc.); parent path always `..`. Pure shell check. **Reference (anchor):** the parent-repo-to-path lookup table is definitional. | testing-institute/SKILL.md:178 |
| `[INST-TEST-008]` | Snapshot Test Structure | **mechanical** | Predicate: AST-check `#snapshot(value, as: .lines [, named: "..."]) [ { """expected""" } ]` invocation shape; reference files committed under `__Snapshots__/` adjacent to test source; recording mode drawn from documented set (`.missing`/`.all`/`.failed`/`.never`). Pure AST/grep. | testing-institute/SKILL.md:196 |
| `[INST-TEST-009]` | Snapshot Configuration with `#Tests` | **mechanical** | Predicate: AST-check that snapshot-recording mode is set in the `#Tests(snapshots: .init(recording: ...))` macro call at type-extension scope, not at individual test. Pure AST/grep. SHOULD-rule. | testing-institute/SKILL.md:240 |
| `[INST-TEST-011]` | .gitignore | **mechanical** | Predicate: shell-check parent or nested `.gitignore` excludes `.build/`, `.swiftpm/`, `.benchmarks/` under the nested Tests/ directory. SHOULD-rule. | testing-institute/SKILL.md:256 |
| `[INST-TEST-012]` | Migration Procedure | **mechanical** | Predicate: assert each migration step from the legacy `Tests/Testing/` pattern was applied — directory rename, Package.swift relocation, dep path adjustment, explicit `path:` on nested targets, explicit `path:` on parent targets, removal of legacy directory, verify `swift test` from each scope. Shell + git-log audit. **Composite:** seven enumerated steps. | testing-institute/SKILL.md:264 |

#### 23.2 testing-institute distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 9 | INST-TEST-001, INST-TEST-002, INST-TEST-003, INST-TEST-004, INST-TEST-005, INST-TEST-008, INST-TEST-009, INST-TEST-011, INST-TEST-012 |
| hybrid | 0 | (none) |
| semantic | 0 | (none) |

Total 9.

Density observation: testing-institute is fully mechanical — every rule reduces to filesystem/AST shape verification (Package.swift contents, directory layout, macro invocations, gitignore entries, migration steps). This is the densest mechanical-class concentration in the tier-3 batch and reflects the skill's role as a structural template that admits no semantic ambiguity.

### Part 24 — implementation (`Skills/implementation/SKILL.md`)

Verified against `SKILL.md` (297 lines, last_reviewed 2026-04-30). All 4 requirement IDs declared via `### [` headings walked.

Note: this SKILL.md is a navigation hub; per the task-prompt scope, only IDs declared with `### [` headings count here ([IMPL-INTENT], [IMPL-000], [IMPL-001], [IMPL-COMPILE]). The hub indexes ~70+ rule IDs across sibling files (`ownership.md`, `concurrency.md`, `accessors.md`, `errors.md`, `style.md`, `infrastructure.md`, `patterns.md`); those are NOT classified here per the prompt's "only count IDs declared with `### [` headings in this file" constraint.

#### 24.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[IMPL-INTENT]` | Code Reads as Intent, Not Mechanism | **semantic** | Predicate: judge whether each line of implementation code reads as *what* (intent) vs *how* (mechanism). Reading every line of a function and tagging it intent-vs-mechanism is fundamentally a judgment call — different reviewers will draw the line differently. The corollary rules in the linked sibling files cover specific mechanisms (offset arithmetic, raw-value access, pointer scaffolding) that are mechanically detectable, but the governing axiom itself is irreducibly semantic. | implementation/SKILL.md:48 |
| `[IMPL-000]` | Call-Site-First Design | **semantic** | Predicate: judge whether the ideal expression was written *first*, and whether infrastructure improvement (or principled-absence ratification) was the response when the expression failed to compile. The decision tree at the heart of the rule (`if it compiles → done`; `if not, principled? yes → rethink, no → improve infrastructure`) is mechanical, but the determination of "ideal expression" is semantic. **Routing:** at-keyboard authorial decision tree. | implementation/SKILL.md:64 |
| `[IMPL-001]` | Principled Absences | **semantic** | Predicate: judge whether a missing operation's absence is principled (would violate mathematical/type-theoretic properties) before adding infrastructure. The two tables enumerate examples (subtraction on naturals, scaling indices, addition on bounded ordinals) but the test ("does the operation preserve mathematical properties?") is a judgment call. **Reference (anchor):** the dual tables are definitional anchors — retain. **Routing:** the rule is itself a routing checklist between rethink/improve/add paths. | implementation/SKILL.md:86 |
| `[IMPL-COMPILE]` | Compiler as Primary Correctness Mechanism | **semantic** | Predicate: judge whether each invariant expressible in the type system has been pushed to compile-time enforcement. The corollary table (resource lifecycle → ~Copyable; view lifetime → ~Escapable; isolation crossing → sending; etc.) is enumerated, but the governing question — *"is there a compile-time constraint I could add that would make a class of runtime bugs impossible?"* — is irreducibly semantic. | implementation/SKILL.md:114 |

#### 24.2 implementation distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 0 | (none) |
| hybrid | 0 | (none) |
| semantic | 4 | IMPL-INTENT, IMPL-000, IMPL-001, IMPL-COMPILE |

Total 4.

Density observation: this skill is the foundational-axioms hub; all four declared IDs are governing principles whose verification is irreducibly semantic. Their corollary rules in sibling files (`ownership.md`, `concurrency.md`, etc.) are individually more mechanical, but the prompt's scope limits this part to the four hub axioms. As governing axioms, they read as routing rules whose value is at-keyboard authorial judgment, so all four also carry **Routing:** semantics — but the dominant classification remains semantic on intent-vs-mechanism / ideal-expression / principled-absence / compile-time-invariant determination.

### Part 25 — quick-commit-and-push-all (`Skills/quick-commit-and-push-all/SKILL.md`)

Verified against `SKILL.md` (196 lines, last_reviewed 2026-04-14). All 3 requirement IDs walked.

#### 25.1 Classification table

| ID | Title | Three-class | Predicate / AI-input | File:line |
|---|---|---|---|---|
| `[SAVE-001]` | Directory and Repository Structure | **mechanical** | Predicate: assert iteration covered all 17 enumerated directories (swift-primitives, swift-ietf, swift-iso, swift-w3c, swift-whatwg, swift-ieee, swift-iec, swift-ecma, swift-incits, swift-standards, swift-linux-foundation, swift-microsoft, swift-arm-ltd, swift-intel, swift-riscv, swift-foundations, swift-institute); within each directory assert sub-repos processed before parent (when parent is a git repo); assert sub-directories without `.git` were silently skipped. Pure shell + filesystem-walk check. **Composite:** 17-row directory table + ordering invariant + skip rule. | quick-commit-and-push-all/SKILL.md:42 |
| `[SAVE-002]` | Commit and Push Procedure | **mechanical** | Predicate: assert per-repo procedure invoked `git add -A`, `git commit -m "Save progress: <YYYY-MM-DD>"` (today's date), `git push`; clean repos silently skipped; no `--force` or `--no-verify` flags; single-script approach (not per-repo tool calls); push-unpushed rule applied (any repo with `git rev-list @{u}..HEAD` ≥1 commit MUST push regardless of working-tree state). Shell-trace audit. **Composite:** three primary procedure steps + four behavioral injunctions (skip clean / no force / no verify / single script / push unpushed). | quick-commit-and-push-all/SKILL.md:85 |
| `[SAVE-003]` | Output Summary | **mechanical** | Predicate: assert post-script report enumerates which repos were committed and which were clean; assert report is brief (no exhaustive listing of every clean repo). Shell-output check on stdout format. | quick-commit-and-push-all/SKILL.md:190 |

#### 25.2 quick-commit-and-push-all distribution

| Class | Count | IDs |
|---|---|---|
| mechanical | 3 | SAVE-001, SAVE-002, SAVE-003 |
| hybrid | 0 | (none) |
| semantic | 0 | (none) |

Total 3.

Density observation: quick-commit-and-push-all is fully mechanical — a filesystem-walk + shell-procedure skill whose every requirement reduces to git/shell trace verification. The push-unpushed rule and the script-batching invariant are both mechanically detectable. No interpretive surface in any of the three rules.


---

### Part 26 — Aggregate distribution and density calibration

#### 26.1 Per-skill distribution

| Skill | Mechanical | Hybrid | Semantic | Total | Mechanical % |
|---|---|---|---|---|---|
| readme | 27 | 33 | 23 | 83 | 32.5% |
| corpus-meta-analysis | 15 | 8 | 4 | 27 | 55.6% |
| collaborative-discussion | 8 | 2 | 3 | 13 | 61.5% |
| research-process | 7 | 21 | 17 | 45 | 15.6% |
| handoff | 25 | 9 | 9 | 43 | 58.1% |
| skill-lifecycle | 17 | 8 | 5 | 30 | 56.7% |
| experiment-process | 11 | 16 | 13 | 40 | 27.5% |
| supervise | 9 | 5 | 21 | 35 | 25.7% |
| reflections-processing | 7 | 3 | 8 | 18 | 38.9% |
| reflect-session | 7 | 2 | 5 | 14 | 50.0% |
| swift-evolution | 3 | 2 | 2 | 7 | 42.9% |
| legal-encoding | 17 | 8 | 6 | 31 | 54.8% |
| issue-investigation | 14 | 6 | 5 | 25 | 56.0% |
| testing | 15 | 2 | 1 | 18 | 83.3% |
| dutch-law | 10 | 3 | 4 | 17 | 58.8% |
| legal-testing | 8 | 3 | 0 | 11 | 72.7% |
| rule-law-core | 6 | 0 | 1 | 7 | 85.7% |
| swift-forums-review | 10 | 8 | 2 | 20 | 50.0% |
| document-markup | 13 | 4 | 0 | 17 | 76.5% |
| testing-swiftlang | 13 | 1 | 2 | 16 | 81.3% |
| swift-pull-request | 9 | 2 | 0 | 11 | 81.8% |
| testing-institute | 9 | 0 | 0 | 9 | 100% |
| implementation | 0 | 0 | 4 | 4 | 0.0% |
| quick-commit-and-push-all | 3 | 0 | 0 | 3 | 100% |
| **Tier-3 total** | **263** | **146** | **135** | **544** | **48.3%** |
| Tier-2 baseline (7 skills) | 107 | 58 | 43 | 208 | 51.4% |
| Tier-1 baseline (13 skills) | 135 | 50 | 51 | 236 | 57.2% |
| Pilot baseline (3 skills) | 26 | 15 | 16 | 57 | 45.6% |

#### 26.2 Aggregate three-class distribution (tier-3 vs prior tiers)

| Class | Pilot % | Tier-1 % | Tier-2 % | Tier-3 % | Δ tier-2→tier-3 |
|---|---|---|---|---|---|
| mechanical | 45.6% | 57.2% | 51.4% | 48.3% | −3.1 pp |
| hybrid | 26.3% | 21.2% | 27.9% | 26.8% | −1.1 pp |
| semantic | 28.1% | 21.6% | 20.7% | 24.8% | **+4.1 pp** |

**Tier-3 mechanical share (48%) is between tier-2 (51%) and pilot (46%)**, comparable to tier-2. **Semantic share rebounds at tier-3 (+4.1 pp vs tier-2)** — voice/process skills carry more intent/judgment content than code-shape skills, but the rebound is modest because many tier-3 skills (testing-*, quick-commit-and-push-all, document-markup, swift-pull-request) are operational and structurally mechanical. Hybrid share is comparable to tier-2 — the AST-prefilter + judgment-closure shape continues to dominate where structural rules carry editorial qualifiers.

#### 26.3 Density outliers and calibration data (per supervisor block ask: clause)

| Skill | Observed | Type | Calibration signal |
|---|---|---|---|
| `testing-institute` | 9/0/0 (100%) | tier-3 | **Most-mechanical skill in tier-3.** Every rule is a Package.swift / filesystem / AST shape predicate; no semantic surface. Mirrors tier-1's `package-export` shape (82%). |
| `quick-commit-and-push-all` | 3/0/0 (100%) | tier-3 | Smallest fully-mechanical skill — git-shell trace verification only. |
| `testing-swiftlang` | 13/1/2 (81%) | tier-3 | Apple Swift Testing macro shapes — AST-grep dominant. |
| `swift-pull-request` | 9/2/0 (82%) | tier-3 | Operational skill codifying upstream Swift project process — shell + regex + git-history. |
| `testing` | 15/2/1 (83%) | tier-3 | Test Support infrastructure — SwiftPM dependency-graph predicates + AST-shape; 5 Reference (anchor) rules. |
| `document-markup` | 13/4/0 (76%) | tier-3 | API-shape skill — every rule traces to library invocation patterns. Zero semantic. |
| `rule-law-core` | 6/0/1 (86%) | tier-3 | **Manifest-only skill** — like tier-1's `swift-institute-core`. 6 of 7 rules are Reference (anchor). |
| `implementation` | 0/0/4 (0%) | tier-3 | **Foundational-axiom hub** (4 hub axioms: IMPL-INTENT / IMPL-000 / IMPL-001 / IMPL-COMPILE). All semantic by design. Sibling-file corollary rules out of tier-3 scope per brief. |
| `supervise` | 9/5/21 (26%) | tier-3 | **Most semantic-heavy skill in tier-3.** Supervision is judgment-bearing — drift detection, intent reading, scope classification. Mirrors tier-2's `swift-package-heritage` (29%) but at much larger ID count. |
| `research-process` | 7/21/17 (16%) | tier-3 | **Most hybrid-heavy skill in tier-3.** Process skills with template-prefilter + AI-judgment-closure structure. Lowest mechanical share. |
| `readme` | 27/33/23 (33%) | tier-3 | **Largest single-skill ID count** (83 IDs). Hybrid dominates (40%) because README rules consistently mix mechanical structure with editorial earning judgment. 11 reserved-ID slots inflate semantic by 11; live-rule distribution (excluding reserved + DEPRECATED) is roughly 27m/33h/11s. |
| `dutch-law` | 10/3/4 | tier-3 | **Universal `**External:**` density** — every rule fetches `wetten.overheid.nl` / `data.rechtspraak.nl` / `repository.officiele-overheidspublicaties.nl` / `zoekservice.overheid.nl`. Highest single-skill External annotation density across pilot+tier-1+tier-2+tier-3. |
| `legal-encoding` | 17/8/6 | tier-3 | Heavy `**External:**` cluster — statutory text fetching dominates verification cost. |

The supervisor block's first ask: clause is **triggered**: tier-3 surfaces multiple density outliers worth flagging for workflow-construction prioritization. The most material findings are (i) `testing-institute` and `quick-commit-and-push-all` as 100%-mechanical skills (immediate-substrate candidates); (ii) `dutch-law`'s universal `**External:**` annotation requiring an authority-fetch infrastructure layer; (iii) `implementation`'s 0% mechanical share reflecting its hub-axiom role.

#### 26.4 γ-roadmap saturation

Distribution of γ-marks across the 263 tier-3 mechanical rules (after force-fit normalization):

| γ class | Count | Skills carrying matches |
|---|---|---|
| γ-2 (CI workflow / metadata / structure lint) | 26 | readme (25 — ci-automation siblings + sub-package badge/format/install rules); corpus-meta-analysis (1 — META-021 audit-section staleness) |
| γ-1b (License header) | 1 | readme (README-136) |
| γ-1c-adjacent (API-breakage advisory pilot) | 1 | readme (README-153 placeholder graduation) |
| γ-1a / γ-3 / γ-3b / γ-2b / γ-4 | 0 | — |

**28 of 263 tier-3 mechanical rules (10.6%) carry a γ-roadmap match** — between tier-2 (1.9%) and tier-1 (37.8%). The match cluster is exclusively in `readme` (especially `readme/ci-automation.md`, where rules explicitly describe `gh repo list` + `gh api` orchestrators that fit the γ-2 deterministic-scan family) plus one corpus-meta-analysis rule. **All other tier-3 mechanical rules carry no γ match** because they audit artifact-shape (handoff template, skill frontmatter, experiment Package.swift, etc.) or platform-fetch (legal sources) — both outside v1.2.0's current γ-1/γ-2/γ-3/γ-4 scope.

**Latent γ-class candidate clusters** (NOT marked inline per "do not force matches" directive; surfaced for future v1.2.0 extension):
- **Skill-shape audit family** (~50+ rules): `skill-lifecycle` SKILL-CREATE-002/003/004/005/007/008/009/010/011, SKILL-LIFE-005/010/012/020/022/027/030; `handoff` HANDOFF-004/005/008/015/038; `research-process` RES-002/003a/003b/003c/013a/026; `experiment-process` EXP-002/002b/003a/003b/003d/003e/005/006b/007a/007/017; `corpus-meta-analysis` META-001/005/008/009/011/012/013/014/015a/019/020/022/022a/026; `reflect-session` REFL-002/003/004/005/007/012/013; `reflections-processing` REFL-PROC-001/002/009/010/012/014/016. Each is a deterministic file-shape / frontmatter / registry / git-log scan against a closed schema — same operational shape as v1.2.0 §3.4.5's YAML/symlink lint family but applied to authorial artifacts (research docs, skill files, handoffs, reflections) rather than CI infrastructure.
- **Test-shape audit family** (~30+ rules): `testing` TEST-001/005/009/010/018/019/020/021/023/024/027/028/031, `testing-institute` INST-TEST-001-012, `testing-swiftlang` SWIFT-TEST-001-016. Closed-schema audits of test-target structure / SwiftPM macros / Suite shape.
- **Legal-source-fetch family** (~40+ rules): `dutch-law` NL-WET-001-016, `legal-encoding` LEG-ENC-002-062, `legal-testing` LEG-TEST-001-041. URL pattern + authority-source fetch + AST shape — externally-grounded but mechanically verifiable.
- **Process-discipline workflow family** (~20+ rules): `swift-pull-request` SWIFT-PR-001-010, `quick-commit-and-push-all` SAVE-001-003, `swift-evolution` PITCH-PROC-004/005/006. git-history + shell-trace audits.
- **Markup-API family** (~13 rules): `document-markup` DOC-MARKUP-010/011/013/020-024/030/032/033/040/050. AST/grep on library invocation patterns.

Each of the five clusters is a candidate for a new γ-class extension: `skill-shape`, `test-shape`, `legal-source-fetch`, `process-discipline`, `markup-api`. None is currently designed in v1.2.0 §3.4. Tier-3 surfaces **~150 additional mechanical rules whose CI-enforcement design is pending γ-roadmap extension** — the largest mechanical-rule reservoir in any tier.

---

### Part 27 — Resistant-set diagnostic (extending tier-2's six-pattern shape)

Tier-3 confirms the six-pattern annotation set holds. **No seventh pattern surfaces.** All resistant rules across the 24 skills classify under one (or more) of the six existing annotations: `**Composite:**`, `**External:**`, `**Routing:**`, `**API-Gap:**`, `**Reference:**` (with optional sub-shape disambiguator), plus the original `**Composite:**` and `**External:**` from the pilot.

#### 27.1 Pattern density at tier-3

| Pattern | Tier-3 count (approx) | Concentration |
|---|---|---|
| Composite | ~50+ | experiment-process (8), supervise (10+), reflections-processing (5+), readme (4+), legal-encoding (1), testing-* (4+), dutch-law (1+), quick-commit-and-push-all (2), swift-pull-request (3+) |
| External | ~30+ | dutch-law (universal — 17/17 rules), legal-encoding (10+), corpus-meta-analysis (3), supervise (some), swift-pull-request (1), readme (10+ — gh API), issue-investigation (1) |
| Routing | ~50+ | research-process (10+), supervise (10+), readme (5+), reflect-session (3), reflections-processing (3), corpus-meta-analysis (3), implementation (4 — all 4 axioms), legal-encoding (1), issue-investigation (4), dutch-law (3), document-markup (1), swift-forums-review (2), swift-pull-request (1), swift-evolution (1), collaborative-discussion (2), rule-law-core (1) |
| API-Gap | 4 | swift-forums-review (FREVIEW-017 calibration data), readme (5 ci-automation siblings — workflow-not-yet-implemented; counted under same skill but distinct rules), testing-swiftlang (SWIFT-TEST-015 compiler-mangling-threshold), research-process (RES-021 second occurrence — `@_spi`/SDK-availability gap) |
| Reference (illustration) | ~10+ | collaborative-discussion (COLLAB-012), document-markup (multiple — sample blocks), swift-pull-request (SWIFT-PR-002), testing-swiftlang (SWIFT-TEST-013 ReferenceModel example), legal-testing (LEG-TEST-012), legal-encoding (JUD-ENC-003, PROD-ENC-001), issue-investigation (ISSUE-021) |
| Reference (anchor) | ~50+ | readme (11 reserved-ID slots), supervise (SUPER-001a, SUPER-015 appendix), research-process (RES-010/010a/010b/010c, HANDOFF-028), experiment-process (EXP-010/010a/010b/010c/010d), issue-investigation (ISSUE-005, ISSUE-011, ISSUE-016, ISSUE-018, ISSUE-019), dutch-law (NL-WET-006, NL-WET-007, NL-WET-009, NL-WET-011, NL-WET-012, NL-WET-013, NL-WET-014), testing (TEST-025, TEST-026, TEST-021, TEST-018, TEST-031), document-markup (DOC-MARKUP-011), swift-pull-request (SWIFT-PR-009), legal-encoding (LEG-ENC-045, LEG-ENC-060, LEG-ENC-061, LEG-ENC-062), rule-law-core (6 of 7 rules), legal-testing (LEG-TEST-030), implementation (IMPL-001), swift-forums-review (FREVIEW-017), testing-institute (INST-TEST-005) |

**Routing dominates tier-3 numerically** (≈50 cases), confirming tier-2's generalization to semantic-classed rules holds. **Reference (anchor) is the second-largest cluster** (≈50), consistent with tier-2's expansion of the original Reference shape — definitional anchors load-bear for downstream rules across voice/process skills (procedure-catalogs, decision-tables, controlled vocabularies).

#### 27.2 Updated resistant-set summary (pilot + tier-1 + tier-2 + tier-3)

| Class of resistance | Pilot | Tier-1 | Tier-2 | Tier-3 | Total | Materiality |
|---|---|---|---|---|---|---|
| Composite (multi-mechanism) | 5 | 12 | 8 (+2 implicit) | ~50 | ~77 | HIGH — split atomic OR `**Composite:**` |
| Workflow (process vs outcome) | 5 | 14 | 0 | 0 | 19 | MEDIUM — clarify field encodes outcome (tier-2 + tier-3 confirm structurally code/voice-shape skills are commit-time checkable) |
| External-knowledge (fetch cost) | 3 | 12 | 12 | ~30 | ~57 | LOW — `**External:**` annotation; `dutch-law`'s 17/17 universal density is the largest cluster |
| Decision-tree wrappers | 0 | 6 | 12 | ~50 | ~68 | MEDIUM — `**Routing:**` annotation; tier-3 confirms tier-2's generalization to semantic-classed rules holds at scale |
| API-gap rules | 0 | 1 | 1 | 4 | 6 | LOW (structurally important) — `**API-Gap:**`; tier-3 surfaces a new sub-pattern: workflow-not-yet-implemented (readme ci-automation siblings) |
| Reference-table-as-rule | 0 | 2 | 28 | ~60 | ~90 | HIGH — sub-split (illustration vs anchor) confirmed; anchor sub-shape dominant in voice/process skills |
| **Total resistant** | **13/57 (22.8%)** | **47/236 (19.9%)** | **63/208 (30.3%)** | **~190/544 (35%)** | **~313/1045 (~30%)** | |

The tier-3 resistant fraction (~35%) is the highest of any tier, driven by the Reference (anchor) cluster (~50 cases) and the Routing cluster (~50 cases). **Excluding Reference (anchor) cases that classify cleanly as mechanical/hybrid/semantic with the annotation purely informational**, the genuinely-resistant fraction drops to ~25% — comparable to pilot/tier-1 and lower than tier-2's adjusted 22.1% reading. The taxonomy continues to classify the supermajority cleanly across all 1045 walked requirements.

#### 27.3 No new (seventh) pattern surfaced

Per the supervisor block's MUST clause "MUST NOT introduce a seventh resistant pattern without escalating first": **tier-3 surfaces no rule that genuinely resists the six-pattern annotation set.** The closest diagnostic refinement is the `**API-Gap:**` sub-pattern of "workflow-not-yet-implemented" (readme ci-automation siblings READ-161/162/163/164/165/166), which fits inside the existing `**API-Gap:**` annotation rather than introducing a new one. **Six-pattern soft ceiling holds across pilot + tier-1 + tier-2 + tier-3.**

---

### Part 28 — Final inventory: ecosystem-wide totals + mechanical-rule construction queue

This section closes the goal-thread that began with the pilot. The verification taxonomy classification sweep is complete: **47 skills, 1045 walked requirements**.

#### 28.1 Ecosystem-wide totals

| Tier | Skills | Requirements | Mechanical | Hybrid | Semantic | Mech % |
|---|---|---|---|---|---|---|
| Pilot | 3 | 57 | 26 | 15 | 16 | 45.6% |
| Tier-1 (infra/process) | 13 | 236 | 135 | 50 | 51 | 57.2% |
| Tier-2 (code-shape) | 7 | 208 | 107 | 58 | 43 | 51.4% |
| Tier-3 (voice/process) | 24 | 544 | 263 | 146 | 135 | 48.3% |
| **Ecosystem total** | **47** | **1045** | **531** | **269** | **245** | **50.8%** |

| Class | Ecosystem count | Ecosystem % |
|---|---|---|
| mechanical | 531 | 50.8% |
| hybrid | 269 | 25.7% |
| semantic | 245 | 23.4% |

**The ecosystem-wide distribution is roughly half mechanical, quarter hybrid, quarter semantic.** Mechanical density across all 47 skills is dominated by tier-1 (+6.4 pp above ecosystem mean) and tier-3 (very close to ecosystem mean despite voice/process orientation, driven by mechanical-heavy operational skills like testing-*, document-markup, dutch-law, legal-encoding). Pilot's 45.6% was the lowest mechanical density (driven by blog-process at 30%); tier-2's 51.4% the highest hybrid density (27.9%, code-shape AST-prefilter shape).

The supervisor block's first ask: clause asked whether tier-3's distribution "shifts the ecosystem-wide totals materially against expectation." **Answer: no material shift.** Tier-3's 263 mechanical / 146 hybrid / 135 semantic align with prior-tier expectations — voice/process skills do not collapse into pure-semantic territory; operational sub-clusters (testing, legal, swift-pull-request) maintain the mechanical floor.

#### 28.2 Mechanical-rule construction queue (ranked by mechanical count, descending)

For workflow-construction prioritization. Each row carries the skill's mechanical-rule count, tier, and γ-roadmap match status. **Rules with γ-roadmap matches (γ-1a/b/c, γ-2, γ-3, γ-3b) feed the immediate workflow-construction substrate** (designed-pending checks). Rules without γ matches form the **latent reservoir** awaiting future γ-class extension.

| Rank | Skill | Mech | Tier | γ-roadmap matches | γ-class candidate cluster |
|---|---|---|---|---|---|
| 1 | documentation | 32 | tier-1 | many γ-2 | (in active γ scope) |
| 2 | readme | 27 | tier-3 | 27 (all γ-2 + 1 γ-1b + 1 γ-1c) | (in active γ scope after API-Gap close) |
| 2 | memory-safety | 27 | tier-2 | 0 | code-shape (test-shape adjacent) |
| 4 | github-repository | 25 | tier-1 | many γ-2 (20) | (in active γ scope) |
| 4 | handoff | 25 | tier-3 | 0 | skill-shape audit |
| 6 | ci-cd-workflows | 22 | tier-1 | many γ-2 (18) | (in active γ scope) |
| 6 | platform | 22 | tier-2 | γ-2 (2) | (partial γ scope) |
| 8 | conversions | 18 | tier-2 | 0 | code-shape (typed-API) |
| 9 | index | 17 | tier-2 | 0 | code-shape (typed-API) |
| 9 | skill-lifecycle | 17 | tier-3 | 0 | skill-shape audit |
| 9 | legal-encoding | 17 | tier-3 | 0 | legal-source-fetch |
| 12 | code-surface | 15 | pilot | 0 | code-shape (Swift-AST) |
| 12 | corpus-meta-analysis | 15 | tier-3 | γ-2 (1) | skill-shape audit |
| 12 | testing | 15 | tier-3 | 0 | test-shape audit |
| 15 | audit | 14 | tier-1 | γ-3-adjacent (some) | (partial γ scope) |
| 15 | issue-investigation | 14 | tier-3 | 0 | process-discipline (compiler) |
| 17 | existing-infrastructure | 13 | tier-1 | 0 | code-shape (typed-API) |
| 17 | modularization | 13 | tier-2 | 0 | code-shape (SwiftPM schema) |
| 17 | document-markup | 13 | tier-3 | 0 | markup-API |
| 17 | testing-swiftlang | 13 | tier-3 | 0 | test-shape audit |
| 21 | experiment-process | 11 | tier-3 | 0 | skill-shape audit |
| 22 | dutch-law | 10 | tier-3 | 0 | legal-source-fetch |
| 22 | swift-forums-review | 10 | tier-3 | 0 | process-discipline (forums) |
| 24 | package-export | 9 | tier-1 | γ-3-adjacent | (partial γ scope) |
| 24 | supervise | 9 | tier-3 | 0 | skill-shape audit |
| 24 | swift-pull-request | 9 | tier-3 | 0 | process-discipline |
| 24 | testing-institute | 9 | tier-3 | 0 | test-shape audit |
| 28 | collaborative-discussion | 8 | tier-3 | 0 | skill-shape audit (state-machine) |
| 28 | legal-testing | 8 | tier-3 | 0 | test-shape audit (legal) |
| 28 | memory-arithmetic | 8 | tier-2 | 0 | code-shape (typed-API) |
| 31 | research-process | 7 | tier-3 | 0 | skill-shape audit |
| 31 | reflect-session | 7 | tier-3 | 0 | skill-shape audit |
| 31 | reflections-processing | 7 | tier-3 | 0 | skill-shape audit |
| 31 | blog-process | 7 | pilot | 0 | skill-shape audit (publishing) |
| 35 | benchmark | 6 | tier-1 | γ-3-adjacent | (partial γ scope) |
| 35 | swift-package-build | 6 | tier-1 | γ-3 (5) | (in active γ scope) |
| 35 | rule-law-core | 6 | tier-3 | 0 | manifest-only |
| 38 | swift-package | 5 | tier-1 | γ-1c-adjacent (1) | (partial γ scope) |
| 39 | primitives | 4 | pilot | γ-1a (1 — canonical Foundation case) | (in active γ scope) |
| 40 | swift-evolution | 3 | tier-3 | 0 | process-discipline |
| 40 | quick-commit-and-push-all | 3 | tier-3 | 0 | process-discipline (git) |
| 42 | release-readiness | 2 | tier-1 | γ-1c (1) | (partial γ scope) |
| 42 | swift-package-heritage | 2 | tier-2 | 0 | (heritage / manifest) |
| 44 | swift-institute | 1 | tier-1 | 0 | (manifest) |
| 45 | swift-institute-core | 0 | tier-1 | — | (manifest, zero rules) |
| 45 | ecosystem-data-structures | 0 | tier-1 | — | (semantic catalog only) |
| 45 | implementation | 0 | tier-3 | — | (foundational axioms only) |
| **Total** | **531** | | | **80** active γ matches | |

**Construction priorities** (workflow-construction phase, separate dispatch):

1. **Tier-1 active-γ cluster (immediate substrate)** — documentation, github-repository, ci-cd-workflows, swift-package-build, primitives, release-readiness: ≈51 mechanical rules with designed γ-1/γ-2/γ-3 checks. Workflow YAML can be drafted directly against v1.2.0 §3.4 designs.

2. **Tier-3 readme cluster (immediate substrate, API-Gap-blocked)** — readme: 27 mechanical rules with γ-2 marks but `**API-Gap:**` annotation indicating workflows are specified-pending. Workflow YAML drafting requires implementing the ci-automation contracts ([README-161] through [README-167]) first.

3. **Latent reservoir for γ-class extension (future)** — ~400 mechanical rules across tier-2 (code-shape) + tier-3 (skill-shape, test-shape, legal-source-fetch, process-discipline, markup-API). Requires v1.2.0 §3.4 extension to define new γ classes; workflow construction follows after extension.

4. **Foundational-axiom skills (workflow-out-of-scope)** — `implementation` (4 axioms), `ecosystem-data-structures` (10 selection rules), `swift-institute-core` (manifest), `rule-law-core` (manifest). All 0% mechanical or anchor-only; AI/human review pipeline is the operational outcome, not CI workflows.

#### 28.3 Out-of-scope finding: 9 engagement+ingest skills (private sibling repo)

Per §Empirical-state pre-flight escalation: 9 additional skills accessible via `/Users/coen/Developer/.claude/skills/` symlinks but not in the brief's tier-3 list:
- `engagement-actionables`, `engagement-compose`, `engagement-process`, `engagement-review`, `engagement-themes`, `engagement-triage`
- `ingest-swift-forums`, `ingest-x`, `ingest-x-feeds`

These 9 live in `swift-institute/Engagement/Skills/` (private sibling repo per `feedback_skills_follow_institute_convention.md`). The brief's explicit scope was `swift-institute/Skills (20) + rule-law/Skills (4)`; Engagement is a separate path. **These 9 skills are NOT classified in this dispatch** per supervisor block MUST clause.

If a future "Engagement annex" dispatch is authorized, the expected shape (based on the engagement skill pattern from `feedback_engagement_test_only_phase.md` + `feedback_engagement_no_reusable_text.md`):
- Mechanical density: high — engagement workflows have schema-shaped contracts (queue records, JSON shapes, draft files)
- Semantic content: moderate — composition-quality rules ("never reuse openers/closers") would be hybrid/semantic
- γ-roadmap match: zero — engagement is in test-only phase per `feedback_engagement_test_only_phase.md`; no CI workflows exist

The 9 skills add an estimated 50–100 rules to the corpus if classified. Ecosystem-wide mechanical density would shift by < ±2 pp. **Surfacing as scope-expansion candidate for supervisor consideration; not required for the current sweep's closure.**

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05) — closes the tiered classification sweep across pilot + tier-1 + tier-2 + tier-3 (47 skills, 1045 requirements). Ecosystem-wide inventory complete.

### Tier-3 verdict

The three-class taxonomy classifies tier-3 cleanly with **48.3% mechanical / 26.8% hybrid / 24.8% semantic** across 544 walked requirements. **Tier-3 mechanical density is comparable to tier-2** (51%) and **between tier-2 and pilot**, contradicting the brief's expectation of "dominantly semantic." The voice/process classification holds at the skill-cluster level (supervise 26%, research-process 16%, implementation 0%) but is offset by operational sub-clusters (testing-* 80–100%, dutch-law/legal-encoding 55–86%, document-markup 76%, swift-pull-request 82%) that maintain a robust mechanical floor. **Semantic share rebounds modestly** (+4.1 pp vs tier-2) but does not dominate.

The resistant fraction is the highest of any tier (~35% raw; ~25% after Reference (anchor) cases that classify cleanly are excluded), driven by Routing and Reference (anchor) cluster expansion at scale. **No seventh resistant pattern surfaced** — six-pattern soft ceiling holds across all four dispatches.

### Ecosystem-wide closure

**1045 requirements walked across 47 skills:**
- 531 mechanical (50.8%)
- 269 hybrid (25.7%)
- 245 semantic (23.4%)

The ecosystem distribution is **roughly half mechanical, quarter hybrid, quarter semantic** — a clean and balanced decomposition. Mechanical-rule construction queue (§28.2) ranks all 47 skills by mechanical count; the top 10 skills (mech ≥ 17) account for **220 mechanical rules (41% of all mechanical rules across 47 skills)**, concentrated in:
- `documentation` (32, tier-1, active γ)
- `readme` (27, tier-3, γ-2 with API-Gap)
- `memory-safety` (27, tier-2)
- `github-repository` (25, tier-1, active γ)
- `handoff` (25, tier-3, latent skill-shape)
- `ci-cd-workflows` (22, tier-1, active γ)
- `platform` (22, tier-2)
- `conversions` (18, tier-2)
- `index` / `skill-lifecycle` / `legal-encoding` (17 each)

### γ-roadmap saturation across the corpus

**80 of 531 ecosystem-wide mechanical rules (15.1%) carry a v1.2.0 γ-roadmap match** — concentrated in tier-1 (51 matches, 78% of total) + tier-3's readme cluster (27 matches) + tier-2's platform PATTERN-005/006 (2 matches). **The remaining 451 mechanical rules form a latent reservoir** awaiting v1.2.0 §3.4 extension to define new γ classes (skill-shape, test-shape, legal-source-fetch, process-discipline, markup-API, code-shape). Tier-3's mechanical contribution to the workflow-construction substrate is concentrated in `readme` (immediate, API-Gap-blocked) and the latent reservoir; tier-3 is not a primary source of immediate workflow rules.

### Recommendation

**Adopt pilot+tier-1+tier-2's six annotations unchanged** (composite / external / routing / API-gap / reference + pilot's two folded). **Optionally adopt the Reference sub-shape disambiguator** (illustration vs anchor) per tier-2 §10. **No seventh taxonomy class needed.** The ecosystem-wide evidence (1045 requirements across 47 skills) reinforces the pilot+tier-1+tier-2 verdict: **the three-class taxonomy is structurally sound; the resistant set is bounded; rollout readiness depends on the format-change clarifications and a single reference skill rewrite per `[SKILL-LIFE-026]`.**

**Workflow construction phase begins (separate dispatch)** with the following ordered substrate:

1. **Active γ cluster** (51 tier-1 + 2 tier-2 + 27 tier-3 = ≈80 rules with designed checks) — workflow YAML can be drafted directly against v1.2.0 §3.4 designs. tier-3's readme cluster requires implementing ci-automation contracts first.
2. **Latent reservoir** (≈451 rules across 5 candidate γ-class extensions) — requires v1.2.0 §3.4 extension before workflow drafting.
3. **AI/human review pipeline** (269 hybrid + 245 semantic = 514 rules) — operational outcome for the non-mechanical bucket; not part of the workflow-construction substrate.

**Tier-3 closes the classification sweep.** No further classification dispatches are scheduled within this sweep. The 9 engagement+ingest skills in `swift-institute/Engagement/Skills/` are surfaced as a scope-expansion candidate for supervisor consideration but are **not** required for sweep closure.

### Out of scope for this dispatch (deliberately not done, per supervisor block)

- No `SKILL.md` files were edited (read-only per supervisor block).
- No `Verification:` fields were added.
- No GitHub Actions workflow YAML was drafted.
- No Phase-1 triage queue updates were applied inline.
- Tier-3 scope held at exactly 24 skills; the 9 additional engagement+ingest skills accessible via the symlink directory were explicitly NOT classified per "MUST stop after the 24 tier-3 skills" clause.
- No `/audit` or token-heavy ecosystem sweep was initiated beyond the 24-skill brief.
- No remote pushes; commit gated on principal authorization per `feedback_no_public_or_tag_without_explicit_yes`.
- Cross-session contamination (wasm-ci doc, untracked Reflections, Reflections/_index.json mods, _index.json wasm-ci entry) deliberately not staged or modified per `feedback_triage_dirty_worktree`.

### Supervisor block verification stamp

Per [HANDOFF-010] step 5: each supervisor ground-rule entry verified against work product —

| Entry | Type | Verification |
|---|---|---|
| Discard the tier-2 supervisor block; this block is the binding contract for tier-3 | MUST | Honored — tier-2 ground-rules dropped at dispatch start; tier-3 block governed throughout. |
| Run pre-flight escalation check (enumerate skills directory; confirm 24-skill list complete) before classifying; stop and escalate if missing | MUST | Verified — pre-flight ran before dispatch; finding documented in §Empirical-state. 9 additional engagement+ingest skills surfaced; per "stop after 24" MUST clause and "escalate" ask: clause, surfaced as a finding without classification. |
| Apply six resistant-pattern annotations consistently with tier-2 §10's refinements (routing on semantic; reference sub-split where helpful) | MUST | Verified — annotations applied per-cluster; Routing on semantic-classed rules used (research-process RES-001, supervise SUPER-005, etc.); Reference sub-split (illustration vs anchor) applied where structurally helpful. |
| Include final-inventory section (ecosystem-wide totals + mechanical-rule construction queue ranked by skill) | MUST | Verified — §28 includes ecosystem-wide totals (§28.1) + ranked construction queue (§28.2) + out-of-scope engagement finding (§28.3). |
| Use parallel subagents for throughput | MUST | Verified — 5 clusters dispatched as parallel `general-purpose` subagents (A: 3 skills/123 IDs; B: 3 skills/118 IDs; C: 5 skills/114 IDs; D: 6 skills/109 IDs; E: 7 skills/80 IDs). Total subagent wall-clock ~6.5 min, all in flight concurrently; staged outputs in `/tmp/tier3-{A,B,C,D,E}.md`. |
| Stop after 24 tier-3 skills; do not classify additional skills even if budget remains | MUST | Verified — exactly 24 skills classified; the 9 engagement+ingest skills explicitly NOT classified despite being accessible via the symlink directory. |
| Commit-as-you-go; stage only files this dispatch authored or modified | MUST | Honored — single logical commit at end of dispatch covers ONLY the new tier-3 doc + its `_index.json` entry; cross-session contamination (wasm-ci, untracked reflections, Reflections/_index.json mods) deliberately not staged. Stash + targeted apply pattern from tier-2 reused. |
| Do not edit any SKILL.md file | MUST NOT | Verified — every subagent prompt declared read-only on SKILL.md; main thread used only Read tool against SKILL.md paths; no Edit/Write/NotebookEdit invocations against `Skills/**`. |
| Do not add Verification: fields, draft workflow YAML, or initiate token-heavy sweep beyond 24 tier-3 skills | MUST NOT | Verified — no `Verification:` field authored; no `.yml` content written; no broader sweep initiated. |
| Do not apply Phase-1 triage queue updates inline | MUST NOT | Verified — Phase-1 triage queue not opened during classification. |
| Do not push commits to any remote without explicit supervisor authorization | MUST NOT | Verified — no `git push` invoked. |
| Do not stage cross-session contamination (wasm-ci doc, untracked reflections, Reflections/_index.json mods) | MUST NOT | Verified — pre-existing working-tree mods stashed before commit; restored after via `git stash pop`. |
| Do not introduce a seventh resistant pattern without escalating | MUST NOT | Verified — no rule resists all six. The closest diagnostic refinement (workflow-not-yet-implemented sub-pattern of API-Gap) fits inside existing annotation. |
| Tier-3 skill list (24): collaborative-discussion, corpus-meta-analysis, document-markup, experiment-process, handoff, implementation, issue-investigation, quick-commit-and-push-all, readme, reflect-session, reflections-processing, research-process, skill-lifecycle, supervise, swift-evolution, swift-forums-review, swift-pull-request, testing, testing-institute, testing-swiftlang, dutch-law, legal-encoding, legal-testing, rule-law-core | fact | Honored — all 24 present in §26.1 per-skill distribution; no skill substituted or dropped. |
| Working tree contains cross-session contamination from prior dispatches; leave untouched | fact | Honored — none of those files modified by this dispatch. |
| Cost discipline binds — Max OAuth, never API key | fact | Honored — no API-key invocation; subagent dispatch within Max-account budget. |
| Tier-3 is the final dispatch; after closure, ecosystem-wide inventory is complete and workflow construction phase begins | fact | Honored — §28 closes the inventory; recommendation at §Outcome stages workflow-construction as the separate dispatch. |
| If tier-3's distribution shifts ecosystem-wide totals materially against expectation, surface in final-inventory as calibration | ask | **Triggered** — §26.3 surfaces 13 density outliers (testing-institute/quick-commit-and-push-all 100% mech; dutch-law universal External; supervise 26% mech as judgment-bearing; implementation 0%; readme 83-ID outlier; etc.). The most material UNanticipated finding: tier-3's mechanical share (48%) is comparable to tier-2 (51%), NOT "dominantly semantic" as the brief expected. Voice/process skills carry mechanical floors via their operational sub-clusters. |
| If pre-flight reveals additional unclassified skills beyond the 24 named, STOP and escalate before classifying any of them | ask | **Triggered** — 9 engagement+ingest skills surfaced; NOT classified per MUST clause; surfaced in §Empirical-state and §28.3 for supervisor consideration. |
| If a tier-3 skill turns out to be non-normative, classify as 0/0/0 and note without forcing | ask | **Triggered** — `implementation` classified as 0/0/4 (4 hub axioms only, all semantic, sibling-file corollary rules out of scope per brief). `rule-law-core` classified as 6/0/1 (manifest-only with one routing rule). Both noted in §26.3 calibration. |

All MUST and MUST NOT entries verified. Three ask: triggers (calibration data, pre-flight escalation, non-normative skill handling) handled inline in §26.3, §Empirical-state + §28.3, and §26.3 respectively. Termination mode: **Success** per [SUPER-010]; supervision in absentia (no live principal during dispatch) honored per [SUPER-014a].

---

## References

### Internal cross-references (verified 2026-05-05 by reading the cited line ranges)

- `swift-institute/Research/skill-verification-taxonomy-pilot.md` v1.0.0 (RECOMMENDATION, 2026-05-05) — the format instrument; Part 1 reconciliation carries forward; Part 5 established three pilot resistant patterns.
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-1.md` v1.0.0 (RECOMMENDATION, 2026-05-05) — extends across 13 infra/process skills; Part 16 surfaced three new resistant patterns (decision-tree wrappers / API-gap rules / reference-table-as-rule).
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-2.md` v1.0.0 (RECOMMENDATION, 2026-05-05) — extends across 7 code-shape skills; §10 surfaced two refinements (Reference sub-split; Routing generalization to semantic-classed rules).
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 (RECOMMENDATION, 2026-05-04) — canonical four-class scheme + γ-roadmap.
- The 24 tier-3 SKILL.md files at the paths enumerated in §Empirical-state — file:line cited per row in Parts 2–25.
- `swift-institute/Skills/handoff/SKILL.md` — [HANDOFF-010] Resume Protocol step 5; [HANDOFF-013] Prior Research Check; [HANDOFF-019] Commit-as-you-go.
- `swift-institute/Skills/supervise/SKILL.md` — [SUPER-002] Block Structure; [SUPER-010] Three-Way Termination; [SUPER-014a] Supervisor in Absentia.
- `swift-institute/Skills/research-process/SKILL.md` — [RES-002a] Research Triage; [RES-003] Document Structure; [RES-013a] Synthesis Verification; [RES-019] Step-0 Internal Research Grep; [RES-020] Research Tiers (this doc is Tier 2); [RES-022] Recommendation-Section Framing Heuristic; [RES-023] Empirical-Claim Verification.
- `swift-institute/Skills/skill-lifecycle/SKILL.md` — [SKILL-LIFE-026] Reference-Implementation Pattern for Breaking Revisions.

### Source artifact (the handoff brief)

`/Users/coen/Developer/HANDOFF-classification-extension-tier-3.md` — branching investigation handoff that dispatched this work; supervisor ground-rules block honored; verification stamp in §Outcome.
