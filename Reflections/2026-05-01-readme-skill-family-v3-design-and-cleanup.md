---
date: 2026-05-01
session_objective: Design and implement a /readme skill family for ecosystem-wide README conventions, leveraging existing CI/CD orchestration where possible.
packages:
  - readme
  - swift-institute
  - swift-primitives
  - swift-standards
  - swift-foundations
  - coenttb
status: pending
---

# README Skill Family v3.0.0 — Design Convergence and Self-Review-Caught Defects

## What Happened

The session opened with a request to design a family of `/readme` skills for the ecosystem and to leverage the existing centralized CI/CD orchestrator pattern (sync-metadata-nightly, link-check-weekly) where possible. The existing readme skill was a single 1107-line v2.1.0 monolith covering only sub-package READMEs.

**Discovery phase**: Inventoried 818 READMEs across the workspace; identified 8 missing READMEs the existing skill mandated; noted three structural defects (swift-primitives leaf-org profile is a 1-line stub with the wrong title; swift-standards profile has Overview but no inventory; Swift-Evolution README cites internal rule IDs in prose).

**Design phase, in three convergence cycles**:

1. Initial proposal: 7-family taxonomy with three Family-G sub-tiers (top-level / org-of-orgs / leaf). Built around a navigation-hub-plus-siblings shape mirroring the documentation skill's [SKILL-CREATE-005a] split.
2. User correction (mid-session): "we don't have any monorepos. all swift packages are a single github repo." Empirically verified via `ls .git` checks that swift-primitives has no .git at root and each swift-X-primitives package has its own .git with its own GH remote. Dropped Family D (superrepo root); revised SKILL.md, ci-automation.md, related cross-references; updated CLAUDE.md's stale "These are monorepos" line and `feedback_superrepo_terminology.md` memory file (the latter was 46 days old and itself stale).
3. User skepticism (late session): "I'm not quite sure why we need these Local clone-mirror of the * type readmes." Reflected honestly; found Family B's content was redundant with the org's GH profile (Family G) and `CLAUDE.md`'s Package Locations table. Dropped Family B; deleted the 5 clone-mirror READMEs I had just written and the org-of-orgs.md sibling skill file (443 lines deleted); reduced to 5 families.

**Build phase**: 7-file skill family (SKILL.md hub + 6 siblings: user-profile, process, sub-package, placeholder, org-profile, ci-automation; 3,609 lines after the Family B cleanup). Three production org profile READMEs updated or created (swift-primitives rewritten from a 1-line broken stub to a 71-line leaf-tier profile; swift-standards extended with companion-orgs + 19-package inventory + alignment edits; swift-foundations created from scratch as a 137-package leaf-tier catalog). Four "Swift Embedded compatible" stub READMEs in swift-primitives graduated to Family E [README-002] Tier 1. Three CI workflows authored mirroring sync-metadata-nightly + link-check shape (`lint-readme-presence.yml`, `lint-readme-presence-weekly.yml`, `lint-readme-structure.yml`).

**Self-review phase**: User prompted explicit review. Found six real defects in own work: an unsubstantiated "90-day window" for star-count refresh; "100–200 lines typical" with n=1 sample size; missing Family B (which user then authorized dropping); "9-tier swift-primitives" cited in 10 places when canonical doc says 21 tiers; swift-foundations profile catalog had 8 packages missing + 1 invented (`swift-jwt`, conflated with `swift-json-web-token`) + `swift-symbol` duplicated across two domain sections; swift-geometry-primitives README cited 4 of 7 actual `Package.swift` deps. All six fixed.

**Final alignment pass**: Verified all 4 org profiles share the unified `## Part of Swift Institute` → catalog → `## How to use a package` → `## Status` → `## License` shape; voice register is third-person institutional throughout.

**HANDOFF scan**: 3 files found at `~/Developer/`. None in this session's cleanup authority (the session did not write them, did not work their items, and did not encounter their completion signals via session work). Per [REFL-009] bounded cleanup authority + 14-day staleness threshold: `HANDOFF-corpus-phase-7a-toolchain-revalidation.md` left untouched (out of session authority); `HANDOFF-post-path-x-final-architectural-cycles.md` left untouched (out of session authority); `HANDOFF.md` left untouched (out of session authority). No `/audit` was invoked this session, so no audit findings to status-update.

## What Worked and What Didn't

**Worked**:

- **Mirroring the sync-metadata orchestrator pattern** for the three new CI workflows. The existing infrastructure (workflow_call inputs / scope computation / app-token mint / per-org loop / step-summary report / weekly orchestrator + tracking-issue idempotent update) was a known-good shape; reusing it kept the new workflows immediately legible to anyone who knew the existing ones, and reduced design risk to near-zero.
- **User skepticism cycles as the highest-leverage signal**. Two of the session's three biggest design moves came from user pushback: the topology correction (no monorepos) and the Family B drop. Both forced re-examination of speculative content and produced cleaner outcomes than I would have reached unprompted.
- **Empirical verification against canonical docs**. Reading `Documentation.docc/Primitives Tiers.md` settled the "9-tier" → "21-tier, 126 packages, 304 products" question with authority. The principle generalizes: when a number is cited speculatively, find the source-of-truth and cite from it.
- **Self-review prompts find defects that the writing pass missed**. The `comm` check between disk packages and profile-catalog packages surfaced the 8-missing + 1-invented + 1-duplicated swift-foundations defects. None of those were visible during writing.
- **Cross-reference integrity stayed clean throughout** (83 referenced = 83 defined, verified by structural grep). The discipline of allocating ID ranges per family and tracking ID-to-rule mapping in the SKILL.md Rule Index paid off across multiple refactors.

**Didn't work**:

- **Speculative family design**. Family B (local-disk grouping) was specified, drafted, and elaborated across 4+ turns before user pushback exposed it as redundant. Family D (superrepo root) had a similar arc but was caught earlier. Both wasted ~500+ lines of work and ~30 minutes of design time. The signal — "no instances of this family currently exist" — was visible from turn 1 but didn't trigger speculation-flag thinking.
- **Count-claim discipline**. I cited "129 packages" in the swift-foundations profile in three places (1-liner / opening / footer) without ever running `ls | wc -l`. The actual count was 137. The catalog itself listed 130. Three different numbers shipped because no verification happened during writing. The fix took 8 targeted edits; the cost of a single `ls` check at write time would have been seconds.
- **Inventing names that "feel right"**. `swift-jwt` was invented as a Crypto entry; the actual repo names use the longer `swift-json-web-token` form. Confusion between the JWT-as-shorthand and JWT-as-protocol-family was the root cause; I didn't `ls` to verify.
- **Stub-graduation under-claiming**. swift-geometry-primitives README said "composes affine, region, dimension, and numeric primitives" — 4 of the 7 actual Package.swift deps. Reading the manifest first would have prevented this.
- **Fabricated specifics**. "Star counts MUST be current within the last 90 days" — invented out of nothing. The cited cross-reference [README-021] does not specify any window. I noticed this during self-review only.
- **Overclaim from small sample**. "100–200 lines typical" claimed a population norm from n=1. Same shape: drafting feels like asserting general truth when only one data point exists.
- **Voice register mismatch in extended files**. swift-standards profile had pre-existing first-person plural philosophical prose ("We believe rules deserve to be written..."); my added inventory section was third-person tabular. Mixed register within one file. Caught in alignment pass.

Confidence-during-writing was high; confidence-during-review was lower. The gap is the leading indicator: when an author feels confident in the moment, that's when verification is *most* needed, not least.

## Patterns and Root Causes

**Pattern 1 — Speculation drift in skill design**. When a skill family is being authored, it is tempting to specify rules for every imaginable artifact category in the domain, including categories with zero existing instances. The cost of speculative content is not the writing time; it is the maintenance cost across the design's lifecycle (every refactor, every cross-reference update, every consistency pass touches the speculative content too) plus the integrity cost (rules that have never been validated against real instances accumulate plausible-sounding-but-wrong claims). Both Family B and Family D in this session followed the speculation arc: specified → cross-referenced → reviewed → ultimately dropped. The signal — "zero existing instances of this family in the workspace" — is visible at design time. The intervention: when proposing a new family/category for an artifact type, the design phase MUST identify whether the category has existing instances; categories with zero instances get marked speculative-pending-validation, NOT specified as a peer of validated families.

**Pattern 2 — Count-claim discipline gap**. Specific numbers cited in production artifacts ("129 packages", "9-tier", "60+ packages organized across 9 tiers") have a particular failure mode: they are treated as harmless connective tissue at write time but as load-bearing claims at read time. The author forgets they cited a specific number; the reader takes it at face value. Three different "129" / "130" / "137" claims about swift-foundations coexisted in one file because no single source-of-truth check was run at any of the three citation points. The cost-asymmetry is sharp: verification takes seconds, correction takes ~8 targeted edits across one file (and would scale linearly with how widely the wrong number was cited). The intervention: any claim of a specific count in a profile or skill file must be derivable from a single source-of-truth check (`ls`, `wc -l`, `grep -c`, reading a canonical doc) at write time, with the source-of-truth cited.

**Pattern 3 — User skepticism > author rationale**. The user's "I'm not quite sure why we need these..." question on Family B was worth more than my ~1500 lines of skill content defending it. This connects to the broader pattern observed in user-design work: authors accumulate justification for their choices in writing, but justification-density does not equal correctness. A user's skepticism is often the cheaper-to-execute version of the question "does this earn its place?" — a question authors should ask themselves at write time but rarely do because the writing-flow rewards forward motion over self-skepticism. The intervention: when the user asks why something exists, lean into the skepticism rather than defending. The user is often catching the design overhead I missed; defending costs both of us context, while honestly answering may surface a deletion that improves the system.

**Pattern 4 — Self-review with adversarial eyes finds the defects**. The session had two distinct review modes: the "summarize what I built" report (where I listed all the work and called it complete) and the "self-review with adversarial eyes" pass (where I ran `comm`, grep, structural integrity checks and found six real defects). The first mode found nothing. The second found everything. The difference is whether the review mode is structured to find defects or to confirm completion. The intervention: after writing a body of substantive content, run a **structural integrity pass** before reporting complete. This is a per-rule-of-completeness check (`grep -hoE` on rule IDs to verify cross-reference integrity; `comm` between disk reality and catalog claims; `wc -l` on count claims; sed/awk to spot duplicates) — not an "I think this is done" assessment.

**Pattern 5 — Voice register mismatch in extended artifacts**. When adding to an existing file, the writer often defaults to their own voice rather than auditing the existing register and matching or recommending a refactor. swift-standards profile is the canonical example: existing prose was first-person plural philosophical; my additions were third-person tabular. Both are conformant to the family rules in isolation, but together they read as two voices speaking past each other. The intervention: when extending an artifact whose existing voice differs from the author's default, audit the register first; either match the existing voice or surface a "voice register mismatch — recommend refactor" finding to the user before writing.

## Action Items

- [ ] **[skill]** readme/ci-automation: extend [README-162] structure linter contract to enforce count-claim consistency — when an org profile cites "N packages" in 1-liner / opening / footer / catalog, all four must agree on N AND N must equal the actual catalog row count. The 2026-05-01 swift-foundations defect (129 / 130 / 137 disagreement) is the canonical case the rule must catch on first run.
- [ ] **[skill]** readme/SKILL.md: add a meta-rule (in the Family Routing section or as a new universal meta-rule) that families with zero existing instances at design time MUST be flagged "speculative — pending validation" in the changelog AND in the family file's frontmatter, AND the design MUST identify the validation criterion (the first instance the rules are tested against). Family B and Family D would have been flagged on day 1 under this rule, surfacing the speculation cost early.
- [ ] **[skill]** readme/sub-package: tighten [README-006] one-liner discipline to require dep-list-completeness for composition one-liners — when a Tier 1+ one-liner says "composes A, B, C", the listed names MUST equal the full dep list in `Package.swift` (or be explicitly marked subset with "(among others)"). Catches the swift-geometry-primitives 4-of-7 defect class.
