---
date: 2026-04-29
status: PLAN
tier: 2
scope: cross-package
---

# Carrier-Launch Skill-Incorporation Backlog

## Issue

`swift-carrier-primitives` is the pilot launch in the swift-primitives
0.1.0 release cohort (carrier → ownership → tagged → property). The
user-stated intent is that the launch process IS the learning event:
lessons feed back into the skills system before subsequent tags, so
the ownership/tagged/property audits run against an updated rule set.

This document inventories the open skill / convention / research
follow-ups whose **provenance is the carrier work** (cross-carrier
integration, code-surface pass, four-layer doc split, blog
drafting, precursor publish, forums-review pre-mortem,
capability-vs-noun-type discussion). It is the canonical source the
carrier audit's Phase 4 gate references.

Scope filter: items whose root reflection is one of —

- `Reflections/2026-04-22-precursor-publish-and-narrowness-cycle.md`
- `Reflections/2026-04-24-carrier-primitives-blog-drafting-and-convergence.md`
- `Reflections/2026-04-24-carrier-primitives-code-surface-and-four-layer-split.md`
- `Reflections/2026-04-24-carrier-precursor-publish-timing-and-paired-post-url-management.md`
- `Reflections/2026-04-26-carrier-decisions-and-capability-vs-noun-type.md`
- `Reflections/2026-04-26-carrier-integration-retrospective.md`
- `Reflections/2026-04-26-cross-carrier-utilities-research-defer.md`

Items from adjacent sessions (Cycle 2 representability, supervise
codification, etc.) that surfaced *near* carrier work but whose
provenance is independent are NOT included — they belong in their
own backlogs.

## Tiers

- **Tier 1** — Direct skill amendments. Block downstream package
  tags; the ownership/tagged/property audits will reference these
  rule IDs.
- **Tier 2** — Process / craft skills (blog-process,
  collaborative-discussion, handoff). Improve future launches but
  do not block this cohort's tags.
- **Tier 3** — Research investigations. Open new questions; not
  rule changes.
- **Tier 4** — Speculative / lower priority. Consolidation,
  diagnostics, demand-driven studies.

## Tier 1 — Direct skill amendments (blocking next tag)

| # | Target | Statement | Provenance | Status |
|---|--------|-----------|------------|--------|
| 1.1 | `primitives` skill | Amend `[PRIM-ARCH-001]` Tier 0 list: remove `swift-tagged-primitives` (moved Tier 0 → Tier 1 by carrier-driven dependency reassignment); add a note about the carrier-primitives-driven reassignment. | `Reflections/2026-04-26-carrier-integration-retrospective.md:149` | LANDED 2026-04-30 (workspace-level edit; swift-primitives/Skills/primitives/SKILL.md is currently unversioned at the swift-primitives superrepo top level — file edited live, also added swift-carrier-primitives to Tier 0 list) |
| 1.2 | `swift-package` skill | Add a "When NOT to apply" section to the `Type.\`Protocol\`` namespace convention distinguishing **capability protocols** from **noun-type protocols**. Pure capability protocols without noun-type backing should remain top-level rather than be forced into a `Namespace.\`Protocol\`` shell. Cite the `Carrier.Mutable` discussion and witness-style classification work. | `Reflections/2026-04-26-carrier-decisions-and-capability-vs-noun-type.md:90` | LANDED (pre-existing as `[PKG-NAME-009]` Capability-Protocol vs Noun-Type Distinction) — verified 2026-04-30 during Pass 1b |
| 1.3 | `documentation` skill | Extend `[DOC-019a]` "Cross-module ambiguity gotcha": the prescription currently covers `docc convert`; the same failure mode bites `docc preview` and the same patch-script fix applies. Add a paragraph (or extend the existing one) explicitly covering local preview of multi-target umbrella catalogs, citing the patch-script's `--exclude-module` flag and the `--additional-symbol-graph-dir` isolation requirement. | `Reflections/2026-04-24-carrier-primitives-code-surface-and-four-layer-split.md:53` | LANDED (pre-existing as `[DOC-102]` Preview-and-Convert Parity in DocC Tooling Guidance) — verified 2026-04-30 during Pass 1b |
| 1.4 | `documentation` skill | Revise `[DOC-028]` and `[DOC-029]` to encode the **consumer/contributor boundary**: per-symbol and topical articles MUST NOT carry `## Research` / `## Experiments` sections, `Status: DECISION` tags, or `<doc:>` cross-references into `Research/` / `Experiments/`. The landing page (or the README's `## Further reading` section) SHOULD carry one consolidated gateway. Decision records with supersession get a `### Resolution` subsection in the Research doc — not a historical note in DocC. Cite swift-property-primitives (precedent) and swift-carrier-primitives (case study) as reference implementations. | `Reflections/2026-04-22-precursor-publish-and-narrowness-cycle.md:116` | LANDED 35dce3e 2026-04-30 — `[DOC-101]` (consumer/contributor boundary, sibling rule) was already in place; this commit revises `[DOC-028]`/`[DOC-029]` to narrow scope to landing pages, removing the contradiction between SHOULD-include (old text) and per-symbol/topical MUST-NOT (`[DOC-101]`). Reference-implementation citation skipped as decorative. |
| 1.5 | `implementation` skill | Document `@_disfavoredOverload` patterns for protocol-conformance disambiguation. Used in this session to resolve the Tagged-cascade ambiguity (`Tagged: Carrier` cascading vs `Tagged: Ordinal.\`Protocol\`` sibling). The pattern is not documented elsewhere in the skill canon. | `Reflections/2026-04-26-carrier-integration-retrospective.md:153` | LANDED 35dce3e 2026-04-30 (`[PATTERN-029]` in implementation/patterns.md) |
| 1.6 | `implementation` or `code-surface` skill | Promote the **Self+Self vs Self+Self.Count** test to a general migration-triage discriminator. `capability-lift-pattern.md` v1.2.0 Recommendation #7 captures it for Carrier specifically; the operator-shape discriminator generalises. Add a sub-rule under `[IMPL-*]` or `[API-LAYER-*]`. | `Reflections/2026-04-26-carrier-integration-retrospective.md:151` | LANDED 35dce3e 2026-04-30 (`[API-LAYER-002]` in implementation/patterns.md) |
| 1.7 | `code-surface` skill | Amend `[API-IMPL-007]` (extension filename `+` suffix pattern) to admit the **where-clause filename shape** as the canonical form for conditional protocol extensions whose discriminator is a constraint, not a conformance. Examples from carrier-primitives: `Carrier where Underlying == Self.swift`, `Carrier where Underlying == Self, Self ~Copyable.swift`, …. Principal direction (2026-04-29): the where-language form is preferred over `+` suffix mnemonics like `+Q1`/`+Q4` because it is self-documenting at the file level. The `+` suffix remains canonical for conformance-adding extensions (e.g., `Array.Dynamic+Sequence.swift`). | `swift-carrier-primitives/Audits/audit.md` Code Surface #1 (2026-04-29 principal direction) | LANDED 35dce3e 2026-04-30 — scope: limited to suppressed-protocol-constraint discriminators (`Self ~Copyable`, `Self ~Escapable`, or both); the unconditional base file in such a family (`Carrier where Underlying == Self.swift`) is admitted as part of the same convention per principal direction 2026-04-30. |
| 1.8 | (cross-package corrective action, not a skill amendment) | Property / ownership / tagged-primitives place their Test Support targets under `Sources/...Test Support/` rather than the `[TEST-019]`-mandated `Tests/Support/`. Cross-package fix required before any of those packages tag. Carrier follows `[TEST-019]` correctly; the audit's earlier OPEN classification was inverted. | `swift-carrier-primitives/Audits/audit.md` Testing #6 (2026-04-29 reversal) | RESOLVED 2026-04-30 — verified during ownership-primitives 0.1.0 final pre-release scan (`swift-ownership-primitives/Audits/audit.md` Phase 6): all three packages (property, ownership, tagged) place Test Support correctly at `Tests/Support/`. Each `Package.swift` declares `path: "Tests/Support"`; each ships `Tests/Support/exports.swift`. The row text was a stale snapshot pre-dating the underlying remediation; no relocation work needed. |
| 1.9 | (workspace tooling, not a skill amendment) | Centralize the local DocC preview helper. Currently bare `swift package preview-documentation` fails on multi-target umbrella packages because the SLI's `@_exported public import` shadows the umbrella's `Carrier` symbol. Per-package `Scripts/preview-docs.sh` would duplicate centralized CI work and accumulate drift. Options: (a) ship one parameterized `swift-institute/Scripts/preview-docs.sh` callable from any umbrella package; (b) upstream the `--exclude-module` flag to `swift package preview-documentation`; (c) skip — leave local preview as "rebuild via CI." Provenance: principal direction 2026-04-29 declined the per-package script in carrier-primitives and asked why centralized CI doesn't already cover this. | swift-carrier-primitives README Contributing decision (2026-04-29) | OPEN |
| 1.10 | `swift-forums-review` skill | Relocate output destination from `<package>/Research/` to `<package>/Audits/forums-review/`. Forums-review artifacts are pre-launch synthetic-critique exercises with bad public optics in `Research/`; `Audits/` is gitignored ecosystem-wide per `[AUDIT-002]` and semantically captures internal verification artifacts. **LANDED 2026-04-29** — skill commit `27ef561`; carrier (5 files), ownership (5 files), async (11 files) artifacts relocated and pushed (`69013ba`, `9383063`, `51f14eb`). Note: prior commits still contain the files in git history; full history-scrub via `git filter-repo` + force-push deferred. | swift-forums-review skill output paths (2026-04-29 principal direction) | LANDED 2026-04-29 |
| 1.11 | `readme` skill | Add explicit rule **forbidding internal rule-ID citations** (`[MOD-015]`, `[PRIM-FOUND-001]`, etc.) in README prose. Rule IDs are author-oriented; consumers don't know what they mean. Reference impl (`swift-property-primitives/README.md`) has zero rule-ID citations but the skill never explicitly forbids them — relies on `[README-023]` evaluator's lens by inference. **Provenance**: 2026-04-29 carrier README review caught 2 rule-ID citations (`[MOD-015]`, `[PRIM-FOUND-001]`) that the prescribed shape would have caught with imitation but not via explicit rule. Proposed: new `[README-026]` "No internal rule-ID citations in README content. Implementation rationale belongs in `Research/`; consumer-facing prose names the behaviour, not the rule." | swift-carrier-primitives README cleanup (2026-04-29) | LANDED 35dce3e 2026-04-30 (`[README-026]` in readme/SKILL.md) |
| 1.12 | `readme` skill | Add explicit rule **constraining Related Packages to public/released repos**. Linking private repos as ecosystem siblings produces 404s for external readers and advertises packages that don't exist yet. Reference impl behaviour is to link only released siblings. **Provenance**: 2026-04-29 carrier README review caught 4 private-repo links in Related Packages (swift-tagged-primitives, swift-cardinal-primitives, swift-ordinal-primitives, swift-hash-primitives) — all unreleased. Proposed: extend `[README-014]` Related Packages with "MUST link only to repos that are public AND have a shipped tag (or explicitly mark unreleased siblings as `(private, unreleased)` rather than as live links)." Plus `[README-016]` addition: prose rationale within Related Packages (e.g., "conformances of a foreign protocol live in the conformer's home package") is contributor-shaped — belongs in `Research/`, not the README's Related Packages section. | swift-carrier-primitives README cleanup (2026-04-29) | LANDED 35dce3e 2026-04-30 (`[README-014]` extended in readme/SKILL.md with public+tagged constraint and prose-rationale exclusion) |

## Tier 2 — Process improvements (blog-process, collaborative-discussion, handoff)

| # | Target | Statement | Provenance | Status |
|---|--------|-----------|------------|--------|
| 2.1 | `blog-process` skill | Add an "audience-magnitude check before timing advice" rule. Before applying heuristics like *"wait for newsletter window"* or *"publish at peak forum traffic,"* confirm audience is non-trivial. At effectively 0 audience, timing advice should invert toward *"ship now for indexing time and low-stakes pipeline rehearsal"*. | `Reflections/2026-04-24-carrier-precursor-publish-timing-and-paired-post-url-management.md` | OPEN |
| 2.2 | `blog-process` skill | Add a "paired-post URL dependency handling" rule with three canonical handling shapes — resolve-and-accept-404 (short lag, near-0 audience), strip-and-restore-on-launch-day (3+ day lag, default), same-day-publish-both (load-bearing cross-reference). Pair with a Tuesday-restore checklist template for option (b). | `Reflections/2026-04-24-carrier-precursor-publish-timing-and-paired-post-url-management.md` | OPEN |
| 2.3 | `blog-process` skill | Document the DocC deploy verification path — `curl` for HTTP status, `gh run list` for build status, rendered-only-in-browser constraint (WebFetch sees empty shells because DocC hydrates client-side). Include the trailing-slash 301 normalization as a known not-a-bug signal. | `Reflections/2026-04-24-carrier-precursor-publish-timing-and-paired-post-url-management.md` | OPEN |
| 2.4 | `blog-process` skill | Add a rhetorical-energy check to paired-post reveal discipline. Extend the paired-post guidance with a named rule: the precursor's closing tease should make the launch feel consequential (reader asks "what is this library?"), not trivial (reader infers "any library of this shape would do"). Provenance: "straightforward to build once the language supports it" drifted toward trivializing the launch in a Round 2 draft; ChatGPT flagged it explicitly. | `Reflections/2026-04-24-carrier-primitives-blog-drafting-and-convergence.md` | OPEN |
| 2.5 | `blog-process` skill | Extend `[BLOG-006]`'s closing-material pass with a mechanical link-reference audit step: after compression or deletion of body paragraphs, grep each `[slug]:` link definition in the References section against the body; drop unused. Orphan references survive author revision passes because readers rarely re-parse the References cluster. | `Reflections/2026-04-24-carrier-primitives-blog-drafting-and-convergence.md` | OPEN |
| 2.6 | `blog-process` skill | Add a parallel-authoring guideline for companion experiments — author the experiment package ALONGSIDE the draft, not after. Frame experiments as correctness harness, not just receipts. Provenance: the V5 `mutating _modify` catch in `namespaced-accessors-walkthrough` would have shipped stale without the parallel build. | `Reflections/2026-04-22-precursor-publish-and-narrowness-cycle.md:117` | OPEN |
| 2.7 | `collaborative-discussion` skill | Document the Round-2-pushback-with-rationale pattern as a recommended Claude-side behavior. When Claude disagrees with a ChatGPT Round 1 proposal, use the Concerns section for explicit pushback with reasoning rather than silent omission or implicit agreement. Empirically accelerates convergence by forcing trade-off engagement at the round where both parties can still reframe. | `Reflections/2026-04-24-carrier-primitives-blog-drafting-and-convergence.md` | OPEN |
| 2.8 | `handoff` skill | Add "Decision-readiness annotation" as a SHOULD-element in the HANDOFF template — when the handoff has decisions in mixed states (some locked, some awaiting derivation), the Current-State section should explicitly label which is which. | `Reflections/2026-04-26-cross-carrier-utilities-research-defer.md:269` | OPEN |
| 2.9 | `implementation` skill (process hook) | Make `/research-process` the default for blocked structural design questions. Add a rule: "If a structural design question blocks implementation for >2 iteration cycles, invoke /research-process before continuing." Could integrate with `[RES-011]` (Research-First Design). Provenance: Phase 2b's late research-process invocation produced Option G after ~3 iteration cycles; early invocation would have produced Option G immediately. | `Reflections/2026-04-26-carrier-integration-retrospective.md:157` | OPEN |
| 2.10 | `audit` skill (or `audit-finding-triage-taxonomy.md`) | Inventory verdict validation step. Extend the audit-finding-triage taxonomy to require: "CAN-yes verdicts on Carrier conformance candidates MUST verify (a) init signatures don't include `throws` (else RawRepresentable territory), (b) generic constraint admits the proposed Underlying constraint, (c) operator shape matches Self+Self (else operator-ergonomics-protocol territory per Recommendation #7)." | `Reflections/2026-04-26-carrier-integration-retrospective.md:159` | OPEN |
| 2.11 | `experiment-process` skill | Pre-implementation verification spike per `[RES-021]` for Carrier conformances. For any Tier 2+ Carrier conformance, do a minimal isolated test BEFORE landing the production conformance. Codifies the spike pattern; would have caught the `Algebra.Modular.Modulus` misclassification upfront. | `Reflections/2026-04-26-carrier-integration-retrospective.md:161` | OPEN |

## Tier 3 — Research investigations

| # | Title | Statement | Provenance | Status |
|---|-------|-----------|------------|--------|
| 3.1 | Four-layer documentation split case study | Document the four-layer split (landing → per-symbol → topical → README) as a case study in `swift-institute/Research/`: which content moved where, before/after line counts, rules cited (`[DOC-010]`, `[DOC-021]`, `[DOC-027]`, `[README-023]`). Carrier Primitives is the clean reference example for packages landing into the four-layer discipline for the first time. | `Reflections/2026-04-24-carrier-primitives-code-surface-and-four-layer-split.md:56` | OPEN |
| 3.2 | Asymmetric-quadrant ergonomics as rejection criterion | Tier-2 cross-package note capturing the recurring pattern (`@dynamicMemberLookup` rejected, KeyPath subscript rejected for ~Copyable, etc.). Cite the in-session experiments and the analogous decisions from carrier and mutator. Currently re-derived from first principles every time it comes up. | `Reflections/2026-04-26-carrier-decisions-and-capability-vs-noun-type.md:91` | OPEN |
| 3.3 | Cross-Carrier algorithm catalog and demand survey | Recommendation #5 says Carrier migration should be driven by Form-D demand. But: have any cross-Carrier algorithms been written post-migration? If demand is unrealized, the Carrier capability is unused. Survey: search ecosystem for `<C: Carrier>` usage post-migration. | `Reflections/2026-04-26-carrier-integration-retrospective.md:165` | OPEN |
| 3.4 | MemberImportVisibility transitive-import pattern | Ecosystem-internal cross-package conformances cause import-cascade friction. Research: is there a pattern (transitive `public import`, `@_exported` re-export, trait-gated visibility) that lets consumers see ecosystem extensions without enumerating imports? Could be a Swift Forums discussion. | `Reflections/2026-04-26-carrier-integration-retrospective.md:167` | OPEN |
| 3.5 | Stale-build-cache reproducer for upcoming features | Multiple "errors disappear after `swift package clean`" moments during the Phase 2b/3 work. Could be a known Swift bug or unintended interaction between `InternalImportsByDefault` / `MemberImportVisibility` and incremental compilation. Worth a minimal reproducer + Swift Forums issue per `issue-investigation` skill. | `Reflections/2026-04-26-carrier-integration-retrospective.md:169` | OPEN |
| 3.6 | Property Q3/Q4 widening study | Property currently doesn't admit `~Escapable` Base. Q3/Q4 Carrier conformance requires widening the generic. Research: do Property's `_modify`, fluent accessors, and downstream consumers (stack/queue/list/heap) survive `~Escapable` Base? Demand-driven per `[RES-018]` — only worth doing if a concrete Q3/Q4 consumer demand surfaces. | `Reflections/2026-04-26-carrier-integration-retrospective.md:171` | OPEN |
| 3.7 | Decimal Tagged refactor design | Phase 4 of the original carrier-ecosystem inventory plan, not attempted. Needs focused research: migration path for `Decimal.Exponent`'s manually-rolled arithmetic to `Tagged<Tag, Int>` extensions; consumer migration scope; breaking-change blast-radius. Should produce a per-package handoff before implementation. | `Reflections/2026-04-26-carrier-integration-retrospective.md:173` | OPEN |
| 3.8 | Carrier coverage map across ecosystem | Diagnostic that walks the ecosystem and reports unconverted Carrier candidates. Tracks migration completeness over time. | `Reflections/2026-04-26-carrier-integration-retrospective.md:175` | OPEN |
| 3.9 | Pre-release scope review as a named release-process step | What does a consumer-perspective review of exported terminology look like? Candidate checklist items: constraint over-specification, noun over-specificity, verb over-specificity, per-article decision-record leakage. Could it run against the rendered DocC (as the consumer sees it) rather than source? The four-pass narrowness cycle on `swift-property-primitives` (container, Tag enum, ~Copyable-Container filename, verb) is the motivating instance. | `Reflections/2026-04-22-precursor-publish-and-narrowness-cycle.md:118` | OPEN |
| 3.10 | Should `Carrier` add `consuming func unwrap() -> Underlying`? | Q2/Q3/Q4 `reroot` is currently structurally blocked per `round-trip-semantics-noncopyable-underlyings.md`. Tier-2 investigation gated on the first concrete consumer with a `reroot`-shaped need. The `cross-carrier-utilities.md` document explicitly identifies this as a separate investigation. | `Reflections/2026-04-26-cross-carrier-utilities-research-defer.md:262` | DEFERRED (demand-gated) |

## Tier 4 — Speculative / consolidation

| # | Title | Statement | Provenance | Status |
|---|-------|-----------|------------|--------|
| 4.1 | Carrier subsumption-boundary consolidation | `capability-lift-pattern.md` has Recommendations #5 (when not to migrate Cardinal/Ordinal "today"), #6 (witness protocols stay distinct), #7 (operator-ergonomics protocols stay distinct), plus 14 `sli-*.md` docs (per-stdlib-type decisions). The "What does Carrier subsume vs what stays distinct?" picture is articulated piecemeal. A consolidated reference would help future migration decisions. | `Reflections/2026-04-26-carrier-integration-retrospective.md:179` | OPEN |
| 4.2 | Tagged: Carrier cascade limits | The `Underlying = RawValue.Underlying` cascade works. But: are there shapes it breaks down? Generic RawValue (per V5a in capability-lift-pattern.md), `~Copyable` RawValue (V5b), existential RawValue (V5c) all have caveats. Worth empirical verification under the production cascade. | `Reflections/2026-04-26-carrier-integration-retrospective.md:181` | OPEN |
| 4.3 | Tier 0 → Tier 1 cascade analysis | `swift-tagged-primitives` moved tiers. Does this affect downstream packages' tier classifications? A diagnostic that walks the dep graph + computes tier reassignments would catch silent shifts. | `Reflections/2026-04-26-carrier-integration-retrospective.md:183` | OPEN |
| 4.4 | Optic.Prism namespace cascade ecosystem audit | Tagged-derived synthesized `.caseName` accessors on `Optic.Prism<Enum, Part>` types collide with enum-case pattern matches at consumer sites whenever the consumer imports a Tagged-bearing primitive transitively. Observed at `iso-9945 Configuration.swift:85` during Cycle 2. Need: inventory of Tagged users in the ecosystem; assessment of whether naming discipline, access-level change, or macro-output adjustment is the correct fix; criterion for when a consumer is at risk. (Adjacent to carrier work — surfaces in Tagged migration which carrier triggered.) | `Reflections/2026-04-22-cycle-2-close-beta-prime-and-c-representability.md:66` | OPEN |

## Package-local follow-ups (in swift-carrier-primitives, not skill changes)

These are tracked here for completeness but live in the package, not
the skill system. They belong to the Carrier audit's Phase 1.

| # | Item | Provenance | Status |
|---|------|------------|--------|
| P.1 | `Research/_index.json` sweep — `dynamic-member-lookup-decision.md`, `forums-review-triage-2026-04-24.md`, `mutability-design-space.md` (and possibly others) are present in `Research/` but not indexed. `[RES-003c]` violation. | `Reflections/2026-04-26-cross-carrier-utilities-research-defer.md:256` | OPEN |
| P.2 | `Research/capability-lift-pattern.md` v1.1.0 §"Existing ecosystem instances" — add `Affine.Discrete.Vector` as a 4th adopter. | `Reflections/2026-04-26-carrier-decisions-and-capability-vs-noun-type.md:92` | LIKELY DONE (commit `01e286e`) — verify in audit Phase 1 |
| P.3 | `Scripts/preview-docs.sh` or README "Contributing > Preview docs locally" section wrapping the patch-symbol-graph + exclude-test-support + isolated-graph-dir incantation. | `Reflections/2026-04-24-carrier-primitives-code-surface-and-four-layer-split.md:55` | OPEN |

## Procedure for landing a Tier 1 item

1. Update the relevant skill file in
   `/Users/coen/Developer/swift-institute/Skills/<skill>/SKILL.md`
   (or sub-file).
2. Bump the skill version per `[SKILL-LIFE-*]`.
3. Run `/Users/coen/Developer/swift-institute/Scripts/sync-skills.sh`
   to regenerate the `~/.claude/skills/` symlinks.
4. Annotate the matching row in this backlog: change `Status` from
   `OPEN` to `LANDED <commit-sha> <date>`.
5. Cross-link from the skill commit message back to this backlog and
   the originating reflection.

## Procedure for deferring a Tier 1 item

If a Tier 1 item is intentionally deferred past the carrier 0.1.0
tag (and therefore past the next package's audit), annotate the row:

```
Status: DEFERRED <date> — <one-line rationale> — re-evaluate at <trigger>
```

The downstream audit MUST cite the deferral when running against
the un-amended skill rule.

## Net assessment

The Tier 1 list contains 12 items. As of 2026-04-30 (Pass-Out):

- **9 items LANDED 2026-04-30**: #1.1, #1.2, #1.3, #1.4, #1.5, #1.6, #1.7,
  #1.11, #1.12. Skill commit `35dce3e` in `swift-institute/Skills`. (#1.2,
  #1.3 were pre-existing as `[PKG-NAME-009]` / `[DOC-102]` and re-verified
  during Pass 1b; #1.1 is a workspace-level edit at
  `swift-primitives/Skills/primitives/SKILL.md`, which sits outside any
  git repo at the swift-primitives superrepo top level — flagged for
  workspace-level git decision.)
- **1 item previously LANDED**: #1.10 (forums-review output destination,
  skill commit `27ef561` 2026-04-29).
- **1 item RESOLVED 2026-04-30 (premise stale)**: #1.8 (cross-package
  Test Support layout) — verified during ownership-primitives 0.1.0
  final pre-release scan that all three packages already place Test
  Support at `Tests/Support/`. The OPEN classification was a row-text
  snapshot from before the underlying state had been corrected; no
  relocation work needed.
- **1 item remains OPEN**: #1.9 (workspace tooling decision for DocC
  preview centralization).

Pass 2 supplemental promotions landed alongside the Tier 1 amendments:
- New skill: `release-readiness` ([RELEASE-001]–[RELEASE-006]) seeded
  from carrier `AUDIT-0.1.0-{release-readiness, final-pre-release-scan}.md`.
- New rule: `[FREVIEW-019]` re-simulation cadence after substantial recent
  changes.
- Cross-link: `audit` skill → release-readiness, swift-forums-review,
  skill-lifecycle.
- Skill index update: `swift-institute-core` adds release-readiness to
  Skill Index + Loading Order (position 19).

Pass 3 supplemental refinements landed alongside:
- New rule: `[BENCH-010]` Tier-0 deferral.
- New rule: `[GH-REPO-074]` per-package thin-caller workflow files.
- Note: `reflections-processing` acknowledges the carrier ad-hoc
  consolidation as a one-time exception.

The ownership audit's Phase 2 may now proceed against the updated rule
set. Tier 2/3/4 items expand the backlog but do NOT gate the cohort.

Outstanding Tier 1 items (do NOT block carrier's tag; #1.8 RESOLVED on
2026-04-30 with no work needed):

- ~~**#1.8** (Test Support layout corrective action) — three packages need
  to relocate Test Support from `Sources/...Test Support/` to
  `Tests/Support/` per `[TEST-019]`. Surfaced by inverting the carrier
  audit finding. Cross-package code change, NOT a skill change.~~
  **RESOLVED 2026-04-30** — verified during ownership-primitives 0.1.0
  final pre-release scan. All three packages were already at `Tests/Support/`
  at the time the row was written; the OPEN classification was a stale
  snapshot. See `swift-ownership-primitives/Audits/audit.md` Phase 6.
- **#1.9** (DocC preview centralization) — workspace tooling decision;
  options A (parameterized `swift-institute/Scripts/preview-docs.sh`),
  B (upstream `--exclude-module` to `swift package preview-documentation`),
  or C (skip).

## References

- `swift-primitives/swift-carrier-primitives/AUDIT-0.1.0-release-readiness.md`
  — the audit document that gates on this backlog at Phase 4.
- `swift-institute/Research/carrier-ecosystem-application-inventory.md`
  v1.1.0 — Phase 1 inventory + triage + implementation log.
- `swift-institute/Research/operator-ergonomics-and-carrier-migration.md`
  v1.0.0 — Tier 2 research producing Recommendation #7.
- `swift-carrier-primitives/Research/capability-lift-pattern.md`
  v1.3.0 — recommendations the Tier 1 items operationalise.
- All seven reflections enumerated under "Issue / Scope filter."
