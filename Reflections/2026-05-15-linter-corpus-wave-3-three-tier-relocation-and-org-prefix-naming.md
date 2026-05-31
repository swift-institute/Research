---
date: 2026-05-15
session_objective: Execute Wave 3 of the swift-linter rule corpus arc — relocate 50 T2 + 2 T3 rules out of universal pack into institute and primitives per the three-tier partition doc
packages:
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-institute-linter-rules
  - swift-primitives/swift-primitives-linter-rules
  - swift-primitives/swift-cyclic-primitives
  - swift-primitives/swift-standard-library-extensions
  - swift-institute/Skills (swift-package)
  - swift-institute/Audits
status: processed
processed_date: 2026-05-31
triage_outcomes:
  - type: no_action
    description: "Action items are arc-specific process-discipline tweaks (handoff/supervise/issue-investigation/reflect-session/lint-rule-promotion) already substantially covered by existing rules, point-in-time/stale, or better preserved in this reflection than promoted. Not promoted per the 2026-05-31 institute leanness program (de-bloat triage) to avoid further [PREFIX-*] proliferation in an oversized corpus; research items deferred (spawn via /research-process when scheduled). Learning retained here; re-promote individually if a pattern recurs."
---

# Wave 3 Three-Tier Relocation and the Org-Prefix Naming Convention

## What Happened

Resumed the swift-linter rule corpus calibration arc per `HANDOFF-swift-linter-corpus-arc-2026-05-15.md`. Prior session closed Waves 1-2 (DRY backtick-exemption helper, compound-suite-name relocation); this session executed Wave 3 (broad layer-correctness relocation).

**Phase 1 — Audit (research-only)**: Classified all 60 rules in `Bundle.universal.swift` against `swift-institute/Research/three-tier-linter-rules-partition.md`. Result: T1=7 stay + T2=50 move to institute + T3=2 move to primitives. Reclassified `redundant refinement` from T2 to T1 on the principal's prompt — its `feedback_redundant_protocol_refinement` citation is institute-infra but the kernel ("A & B where A already refines B is redundant") is a universal Swift type-system fact, matching the partition doc's "citation as evidence, not verdict" precedent (lines 86–92, `inlinable internal access` as the exemplar). Net: **8 T1 stay + 50 T2 + 2 T3 = 52 moves**.

**Phase 2 — SwiftPM module-name collision detected pre-dispatch**: Initial design mirrored universal's pack vocabulary 1:1 (institute gets `Linter Rule Memory`, `Linter Rule Closure`, etc.). Each pack-target compiles to a module name derived from its target name — `Linter_Rule_Memory`. Universal already publishes that exact module. The consumer-resolved closure cannot have two products with the same module name. Surfaced the conflict before any file moves; principal ratified the **org-prefix naming convention**:

```
swift-linter-rules            → "Linter Rule <Pack>"            (base, no prefix)
swift-institute-linter-rules  → "Institute Linter Rule <Pack>"  (org prefix)
swift-primitives-linter-rules → "Primitives Linter Rule <Pack>" (org prefix)
```

**Phase 3 — Orchestrator-direct execution**: 52 rule moves + 4 institute pack renames + 1 primitives pack rename + Package.swift rewrites in 2 repos + Bundle file edits in 3 repos + import-rewrite script (75 source/test files touched). Single-author orchestrator pass via a Python script (`/tmp/wave3-relocate.py`), not parallel subagent dispatch — `feedback_serial_swift_builds` forbids parallel `swift build` on the same package, and git-index lock would race on 52+ concurrent commits. Mechanical work + serial verification is the right shape.

**Phase 4 — Empty pack-target preservation**: 6 universal pack-targets (Cardinal, Closure, Platform, Throws, Try, Unchecked) had all their rules moved out, leaving empty dirs. Principal directed "don't delete now-empty universal pack targets after the move." Added `Lint.Rule.<Pack>._Placeholder.swift` + companion test files to keep SwiftPM targets buildable while preserving structure for future use.

**Phase 5 — Verification**: All 3 packages build green; 91 / 764 / 81 tests pass across universal / institute / primitives. **Carrier-primitives canary returns 129 lint findings** — identical to the pre-Wave-3 baseline documented in the handoff (70 inline-rule canary + 59 real findings). Per-rule frequencies confirm rules from BOTH the pre-existing institute packs (Naming, Foundation, Framework, Conformance) and the new Wave 3 packs (Memory, Structure, Unchecked) fire correctly through the renamed module surface.

**Phase 6 — Commits + pushes**: Three commits, one per repo (`2de31b4` universal, `dfa8d53` institute, `94258cc` primitives). Plus skill commit `0a7aa18` adding `[PKG-NAME-014]` to swift-package skill mechanizing the org-prefix convention. All pushed; PUBLIC consumer commits (ordinal + affine test renames) pushed under the prior session's authorization.

**Phase 7 — Consumer-breakage cleanup (caught post-commit via re-grep)**: After pushes, a workspace-wide grep for stale `Linter_Rule_<X>` references found two real consumer breakages:
- `swift-primitives/swift-cyclic-primitives/Lint.swift` — imported `Linter_Rule_RawValue`, `Linter_Rule_Structure`, `Linter_Rule_Unchecked` (all renamed) with the wrong package-paths (`swift-linter-rules` instead of `swift-institute-linter-rules` for the moved Structure/Unchecked rules)
- `swift-primitives/swift-standard-library-extensions/Lint/Package.swift` + `Lint/Sources/Lint/main.swift` — imported `Linter_Rule_Naming` + product reference, both renamed

Fixed both, verified cyclic via canary (31 findings, matches pre-Wave-3 baseline), committed + pushed (`426dff7` cyclic, `421b549` standard-library-extensions).

**Handoff scan**: 60+ `HANDOFF-*.md` files at workspace root (`/Users/coen/Developer/`). None were touched, written, or had completion-signals encountered by this session. All out-of-session-scope per [REFL-009]'s bounded cleanup authority. Left in place. The arc-specific handoff (`swift-institute/Audits/HANDOFF-swift-linter-corpus-arc-2026-05-15.md`) was updated with Wave 3 closeout sections and committed (`35ab2cf`).

## What Worked and What Didn't

**Worked**:

- **Audit-first discipline saved a wasted dispatch.** Per `feedback_class_c_ecosystem_stop_not_dispatch`, the relocation is a class-(c) ecosystem question; the audit produced the candidate table for principal authorization before any file moves. The principal's two pre-dispatch interjections (reclassifying `redundant refinement` to T1, ratifying the org-prefix convention) materially changed the dispatch — both interjections happened pre-execution where they were cheap. If I had auto-dispatched, both would have surfaced as in-flight redirections costing rework.

- **Detecting the module-name collision before dispatching.** I noticed `option (a) mirror universal pack names` would produce `Linter_Rule_Memory` in both universal AND institute, triggered the surface-the-issue path, and the principal's one-sentence convention authorization closed it cleanly. Without that detection, 52 subagent dispatches would have produced 9 build-time collisions all discovered post-hoc.

- **Orchestrator-direct beat subagent dispatch.** The work was mechanical (file moves + Package.swift rewrites + bundle edits). Parallel subagents would have raced on `swift build` locks (per `feedback_serial_swift_builds`) and git-index locks (52 commits). One Python script did the whole relocation in under a minute; a 75-file import-rewrite script handled the renamed imports in seconds.

- **Carrier-primitives canary as end-to-end verification.** The Wave 3 relocation didn't change rule semantics, just their package homes. The carrier canary returning 129 findings = pre-Wave-3 baseline is a strong invariant — proves the consumer's typed-ID accessors still resolve to the relocated rules, proves Bundle.primitives aggregates the right pack universe, proves the org-prefix module names round-trip cleanly. Single command. High signal.

- **Surgical pre-commit isolation kept user WIP intact.** The principal had pre-existing untracked WIP in 4 working trees (22 Research promote-validation docs, the revalidation-anchor source+tests+enable line, .gitignore canonical sync edits, 8 untracked rule packs / NestedTag rule). My commits used explicit `git add Sources/ Tests/` (and explicit `Package.swift` adds) instead of `git add -A` or `-u`, preserving each WIP item in working tree.

**Didn't work / would do differently**:

- **Consumer-breakage scan was post-commit, not pre-commit.** The pack renames (institute Naming → Institute Linter Rule Naming + module name rewrite) broke swift-cyclic-primitives and swift-standard-library-extensions. I caught these via a workspace-wide grep, but only after Wave 3 commits had landed locally. The fixes worked but the timing was inverted — broken state existed in a small window between Wave 3 pushes and the cleanup commits. A pre-commit grep against the broader workspace would have caught both consumers within the Wave 3 dispatch, allowing the fixes to be batched into the institute/primitives commits as "post-rename consumer adjustments."

- **The `feedback_reverify_baseline_failure_before_path_choice` discipline applied successfully.** When the carrier canary's first run failed at the swift-linter compile step ("Parser Literal Primitives product not found"), I re-verified the failing symbol's current state in parser-primitives before composing an A/B/C escalation. The principal had already fixed swift-linter to drop that dep in commit `33e9663` — surfacing the diagnostic at file:line beat fabricating an escalation. Worked exactly as intended.

- **Stash-vs-surgical-edit choice was cleaner than I expected.** No stash was needed in Wave 3 because the user's only Bundle.universal WIP (the revalidation-anchor enable line) was *part of* the relocation (the rule moved to institute and the enable line carried with it per principal Q2). The surgical-edit pattern would have been right for any other Bundle.universal WIP situation; this one absorbed.

- **The empty-pack placeholder pattern was a surprise** that resolved cleanly. SwiftPM rejects empty targets at build time. Principal direction ("don't delete now-empty universal pack targets") would have produced 6 broken targets; placeholders with a one-paragraph comment kept the structure semantically clear while satisfying SwiftPM's "at least one source file" constraint.

## Patterns and Root Causes

### Pattern A — SwiftPM Module-Name Collision Is a Design-Time Risk in Layered Vocabularies

**Observation**: SwiftPM has no consumer-side module-aliasing escape hatch. When two packages in the same dep graph both publish a target with the same name, the resolved-closure rejects the duplicate module name at build time. The collision is invisible until you actually try to build; the *risk* is only visible to a designer who notices that two packages mirror each other's pack vocabulary.

**Root cause**: SwiftPM resolves products by their module name across the dep graph, not by their package origin. Two products both named "Linter Rule Memory" both compile to `Linter_Rule_Memory`; the consumer's `import Linter_Rule_Memory` has no way to disambiguate. Module aliasing exists at the dep-declaring site but not at the import site, and only works for path-form deps with explicit `moduleAliases:` (deep-cut feature, rarely used).

**Generalization**: Any pair of layered packages whose authors are tempted to use parallel pack-target names triggers this risk. The pattern fires more often than seems likely: anywhere an ecosystem has tier-structured rule packs, capability packs, feature packs, etc. — the second-tier package author naturally reaches for "the same name with a more specific scope" without realizing the collision implication.

**Mitigation in skill form**: `[PKG-NAME-014]` (added this session) codifies the org-prefix convention. The convention's predictability matters more than its aesthetics — every author can derive the prefix from the layered position, every consumer can read it as tier documentation.

**Why this pattern wasn't caught earlier**: The three-tier partition doc (`swift-institute/Research/three-tier-linter-rules-partition.md`, 2026-05-11) specifies *what* moves where but doesn't address *what* the relocated targets are named. Wave 2's compound-suite-name relocation used the institute's existing `Linter Rule Naming` pack-target as the landing — and because universal had no `Linter Rule Naming`, the collision didn't surface. Wave 3's broader vocabulary-mirroring is where the latent risk became active.

### Pattern B — Orchestrator-Direct vs Subagent Dispatch Is Decided by Lock Contention, Not Parallelism Opportunity

**Observation**: The handoff's Wave 3 section explicitly recommended subagent-per-rule dispatch ("each rule's move is independent"). I considered this carefully and chose orchestrator-direct instead. The chosen path was strictly faster and produced cleaner history (3 commits vs 52+).

**Root cause**: The decision pivots on three lock points, not on parallelism:
1. SwiftPM `.build/lock` — per `feedback_serial_swift_builds`, parallel `swift build` on the same package serializes anyway, just less efficiently
2. Git `.git/index.lock` — 52 commits in 3 repos would race on each repo's index
3. Bundle file authorship — single-author serialization through orchestrator was non-negotiable per principal Q4

When all three lock points serialize the work, the "parallelism" of subagent dispatch is illusory. The remaining benefit (subagents read independent file sets) doesn't beat the orchestrator-direct cost (Python script reads all files once, writes all changes in a single pass).

**Generalization**: Subagent dispatch shines when work has (a) genuinely independent file/build/git surfaces, (b) per-task analysis cost that benefits from parallel reasoning, (c) modest task count where coordination overhead doesn't dominate. Wave 3 had none of these: mechanical file moves, shared bundle/Package.swift surfaces, 52+ tasks where coordination would have exceeded the work.

**The handoff's recommendation was a default, not a verdict**. Choosing orchestrator-direct over the handoff template wasn't a deviation — it was the right call once the lock points were named. The handoff was written before [PKG-NAME-014] existed; with the convention baked in, the work shape changed from "per-rule decision-required moves" to "per-package mechanical rewrites."

### Pattern C — Re-Grep After Pack Renames Catches Consumer Breakage Post-Hoc, Should Be Pre-Commit

**Observation**: I caught swift-cyclic-primitives and swift-standard-library-extensions breakage by running a workspace-wide grep for `Linter_Rule_<X>` after Wave 3 commits had landed. The fixes worked, but the broken-state window between Wave 3 push and the fix-up commits was a regression hazard.

**Root cause**: My Wave 3 verification was scoped to the 3 modified repos (universal/institute/primitives). Consumers external to those repos weren't in my mental scope. The fact that 2 of ~14 cohort-or-adjacent packages had Lint.swift consumers of specifically these renamed modules wasn't discoverable from inside the 3-repo Wave 3 perimeter.

**Generalization**: Any rename that crosses a published surface (a product name, an exported module name, a public symbol) has consumers OUTSIDE the rename's immediate package. The grep that catches them is mechanical; the discipline is doing it BEFORE the rename's commits land, not after.

**Skill-promotion candidate**: A `[LINT-PROMOTE-NNN]` or `[PKG-NAME-NNN]` rule mandating "before committing a pack-target rename, grep the workspace for the old module name and produce a consumer-impact list" would close the gap. The grep is sub-second; the cost of missing it is post-push fixup commits.

### Pattern D — The Placeholder-File Pattern Resolves the "Empty SwiftPM Target" Constraint Without Architectural Change

**Observation**: SwiftPM requires at least one source file per target. After Wave 3 emptied 6 universal pack-targets, those targets would have been unbuildable. Principal direction said don't delete them. The resolution was `Lint.Rule.<Pack>._Placeholder.swift` with a one-paragraph "this pack's rules were relocated; cleanup is its own dispatch" comment.

**Root cause**: SwiftPM's target validity is structural, not semantic. A target with one no-op source file is valid; a target with zero source files is invalid. The placeholder pattern bridges the gap with minimal noise.

**Generalization**: Anywhere a multi-phase refactor leaves intermediate-state empty targets (post-decomposition cleanup, pre-removal preservation, etc.), the placeholder pattern is the cleanest holding form. The `_Placeholder` naming is self-documenting; the comment provides context for the next reader.

**Alternative considered**: Comment out the empty target in Package.swift. Rejected because it would have required additional commits when the cleanup dispatch runs (to re-add the targets if they're needed). Placeholder files require zero Package.swift changes when the target is repopulated — just drop new sources in the dir.

## Action Items

- [ ] **[skill]** lint-rule-promotion: codify a pre-commit consumer-grep checklist for pack-target / module-name renames. Specifically: before committing any pack-target rename, grep the broader workspace for `<OldModuleName>` and produce a consumer-impact list. Pattern C in this reflection caught 2 real consumer breakages post-commit; a pre-commit grep would have caught them in-dispatch, allowing the fixes to ride the rename's commits rather than producing fixup commits.

- [ ] **[research]** Audit other ecosystem org-mirror tri-tier or N-tier pairs for latent module-name collision risk per [PKG-NAME-014]'s pattern. Candidates to survey: `swift-foundations/swift-coder-rules` (if/when it exists) vs `swift-primitives/swift-coder-primitives-rules`; the `rule-institute/Skills` vs `swift-institute/Skills` lineage if their consumers share resolution graphs; any other places where two packages decompose along similar pack vocabularies. The audit's output: a list of packages where applying the org-prefix convention proactively would close latent collision risk, before the next vocabulary-mirroring relocation surfaces it.

- [ ] **[package]** swift-foundations/swift-linter-rules: empty universal pack-targets (Cardinal, Closure, Platform, Throws, Try, Unchecked) cleanup is deferred per principal direction. Track the deferred dispatch — eventually the placeholder-pack scaffolding should resolve: either the packs are retired entirely from Package.swift (if no future rules will land there) or new T1 rules populate them. The current state (6 packs with only placeholder files + Bundle.universal.swift importing only 5 of 11 declared packs) is a coherent intermediate but not a stable end state.
