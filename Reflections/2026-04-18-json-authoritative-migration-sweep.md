---
date: 2026-04-18
session_objective: Continue from the mixed-chrome dashboard going live; simplify the dashboard's manifest sourcing, extend the JSON-authoritative migration to internal indexes, update all affected skills, and hand off the remaining per-package migration.
packages:
  - swift-institute.org
  - swift-institute-Research
  - swift-institute-Experiments
  - swift-institute-Audits
  - swift-institute-Blog
  - swift-institute-Skills
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: research-process
    description: Multi-phase migration transition-clause convention added to [RES-003c]
  - type: blog_idea
    description: "The over-built copy step" — architectural simplification narrative around raw.githubusercontent.com pivot
  - type: research_topic
    target: swift-institute.org
    description: Scope-filter dashboard aggregation strategy — stub landed at Research/scope-filter-dashboard-aggregation-strategy.md (Tier 2, IN_PROGRESS)
---

# JSON-Authoritative Migration Sweep + The Over-Built Copy Step

## What Happened

Second reflection for 2026-04-18, picking up from `2026-04-18-two-homepages-mixed-chrome-dashboard.md`. That entry closed at "dashboard is live with committed-snapshot manifests and a CI step that overwrites them from sibling repos." This session restructured that architecture and extended the `_index.md → _index.json` migration across the rest of the swift-institute ecosystem.

**Over-built copy step, identified and removed.** The user asked: "why can't swift-institute.org just use the direct Research (and Experiments) `_index.json`, so when I update those, it 'just works'?" Verified `raw.githubusercontent.com` serves public files with `access-control-allow-origin: *` and a 5-minute cache TTL. Changed `dashboard.js` to fetch directly from `https://raw.githubusercontent.com/swift-institute/{Research,Experiments}/main/_index.json`, deleted the deploy-workflow "Fetch live manifests" step, deleted the local `build-docs.sh` fetch logic, deleted the committed snapshots from the site repo, and added `.gitignore` entries so they can't drift back in. Architecture is now genuinely data-driven: update the sibling repo → dashboard reflects within 5 minutes. No swift-institute.org redeploy.

**Internal migrations — Reflections, Audits, Blog.** User's direction: "just migrate the internal; no dashboard now." `Reflections/_index.md → _index.json` (120 entries) with structured status schema parsing the `processed (date) OUTCOME — description` form into `{status, processedDate, triageOutcome, outcomeDescription, statusRaw}`. `Audits/_index.md → _index.json` (2 sections, 13 entries) with section-based schema. `Blog/_index.md → _index.json` (5 sections, 58 entries, 3 deprecated strike-through markers) preserving per-section column shapes (`Prioritized`/`Ready for Drafting` use one shape, `Needs More Context` uses `blocker` instead of `notes`, `In Progress` uses `writer`/`started`/`draft`, `Published` uses `published`/`post`) and parsing markdown-link cells into `{label, url}` objects.

**Skills sweep.** Updated seven skills to name JSON authoritative and forbid `_index.md`: `research-process` [RES-003c], `experiment-process` [EXP-003e], `reflect-session` [REFL-007], `blog-process` [BLOG-002], `reflections-processing`, `audit` [AUDIT-009], `corpus-meta-analysis`. Committed as `Skills@08c3ef1`, pushed. Final grep confirms only prohibition statements remain as `_index.md` references in Skills.

**Public corpora got delete-and-point treatment.** `Research/_index.md` and `Experiments/_index.md` deleted entirely; the dashboard is the canonical browsable view. `README.md` updated to point at the dashboard. This stronger move (not "MD derived from JSON" but "MD gone") came out of "the markdown is arguably something we should remove entirely, right?" — better answer than my original dual-file plan because it eliminates drift risk at the source.

**Handoff for the ecosystem-wide migration.** 154 `_index.md` files remain across swift-primitives (101), swift-foundations (50), swift-standards (3). Per-package migration spans ~70+ independent git repos (superrepos are submodule aggregators). Wrote `HANDOFF.md` at `/Users/coen/Developer/HANDOFF.md` with inventory, migration policy, tier-A prioritization, structural exceptions (the `data structures/` sub-index, audit sub-index, worktree contents), push-authorization notes, and the transition-clause skill amendment to add on migration completion.

**Session shape.** Pushed five repos (Research, Experiments, Blog, Audits, Skills) plus swift-institute.org for the dashboard fetch-at-runtime change. Wrote one blog draft (`Blog/Draft/two-homepages.md`, BLOG-IDEA-053, unchanged from the earlier reflection). Wrote two `/reflect-session` entries in one calendar day (this one and `2026-04-18-two-homepages-mixed-chrome-dashboard.md`).

## What Worked and What Didn't

**Worked:**

- Responding to the user's "why not use raw directly?" question as a genuine architecture-review prompt rather than as a defense of the existing design. Verified the CORS header (`access-control-allow-origin: *`) and the cache TTL before changing direction; the data made the simplification obvious. Ripped out ~25 lines of CI code and ~5 lines of local-build code; added 3 lines of URL substitution. Net-negative code delta for a strictly better architecture.
- Per-shape migration scripts rather than a single over-abstracted tool. Each `_index.md` shape (Research/Experiments with status-enum, Reflections with `processed (date) OUTCOME — description`, Audits with sections, Blog with per-section column shapes) got its own ~80-line Python script. Each script was disposable, each output was auditable, and each shape's edge cases surfaced immediately rather than being masked by a general-purpose parser.
- The "delete entirely, point to dashboards" pivot. My initial plan kept `_index.md` as a derived view with a regenerator tool as future work. User pushed stronger: "the markdown is arguably something we should remove entirely, right?" The stronger move matched the single-source-of-truth principle and retired an outstanding action item (the regenerator is now obsolete). When "derived view" and "delete entirely" both work, delete entirely — drift is inherent to dual sources.
- Iterative scope expansion through user prompting. First scope was Research + Experiments, then "are other sections overbuilt?" widened it to architecture, then "also there are more `_index.md` files" widened it to the ecosystem. Each prompt surfaced scope the session hadn't been considering. The flow worked because the user was doing scope-widening and I was doing execution + synthesis; neither side was trying to anticipate what the other would notice.
- Handoff decision for the 154-file ecosystem migration. Recognized that 70+ separate git repos + per-batch push authorization + per-repo cross-ref sweep is work that benefits from a fresh session with focused attention, rather than end-of-session hacking. Wrote the handoff with concrete next steps, structural-exception flags, and the skill-amendment-on-completion note.

**Didn't work or needed a second pass:**

- Initial committed-snapshot architecture for dashboard manifests. I built a deploy-workflow step that shallow-clones both sibling repos and copies their `_index.json` into the site output at deploy time. Correct in isolation, but the data was never a build-time artifact — it was live content from authoritative repos. One user question exposed this; the corrective edit was small; the lesson is that "consistent with a build-artifact model" is a weak justification when the thing being modeled isn't a build artifact. Default to runtime fetch before falling back to build-time copy.
- Skill text overshot the ecosystem state. `[RES-003c]` and `[EXP-003e]` now say "`_index.md` is forbidden" without a transition clause. 154 legacy files exist across superrepos that the skill doesn't acknowledge. Captured as a note in the handoff: add the transition clause after the ecosystem migration completes. Still, writing the skill as if migration were already done was aspirational in a way that would have been caught by the sentence "does this describe current reality?"
- Initial migration-reflections script missed several status variants (`MOSTLY IMPLEMENTED`, `FIX_IMPLEMENTED`, `CONVERGED`, `DRAFT`, `INVENTORY`, `REFERENCE`, `TRANSCRIPT`). Parser fell back to treating them as `{status: "MOSTLY", detail: "IMPLEMENTED"}` and similar nonsense. Visible only on inspecting output. A 2-line "unrecognized status" emission before writing would have caught it in the first run.
- Composite-push denial on Skills (from the earlier half of the day). Attempted to push Research + Experiments + Skills in one call; sandbox correctly denied because only Research + Experiments were pre-authorized. The split-and-retry was cheap, but bundling pushes was the wrong instinct — each repo's authorization should be explicit.

**Confidence calibration:**

- High confidence on the CORS + cache TTL findings before changing the architecture. Correctly high; the curl of `raw.githubusercontent.com` took five seconds and gave definitive headers.
- Medium confidence on the Blog index migration before running. The multi-section + per-section column shapes + strike-through deprecation + markdown-link cells were all shape variations from the Research/Experiments case. Wrote the script carefully, then verified output counts matched expectations. Correctly medium.
- High confidence on the handoff decision. The scale (70+ repos), authorization pattern (per-batch), and risk profile (error-multiplying across many pushes) all pointed the same direction. Correctly high.

## Patterns and Root Causes

**Pattern 1 — The "build-artifact consistency" trap.** When a file is produced by CI and copied into a deploy output, every deploy-workflow step applies to it. When a file is authoritative live data, only its source applies. The trap is treating live data as a build artifact because the deploy pipeline has a convenient place to put it. The result is a copy step that ages poorly — source updates don't propagate until redeploy, and drift risk accumulates. The corrective question is simple: "does this file change between deploys?" If yes, it's live data; serve it live. The committed-snapshot approach failed this test — `_index.json` changes on every push to the sibling repo, not on swift-institute.org deploys. Fetching at runtime is the physical expression of "source of truth lives in the source repo."

**Pattern 2 — Skill text as current-state vs. future-state.** `[RES-003c]` says "`_index.md` is forbidden" in present tense. That's true going forward for new work, but 154 legacy files exist that the statement doesn't describe. The ambiguity between "is forbidden for new creation" and "does not exist in the ecosystem" matters during multi-phase migrations: a reader of the current skill text would (correctly) assume the ecosystem already matches, which is aspirational. The underlying root cause is that skill writing tends to describe the end-state; multi-phase migrations need transition language that distinguishes "new work obeys this rule" from "legacy work has not yet been migrated." Both can be true simultaneously. Making that explicit in the skill avoids the aspirational-text trap and gives future readers a correct picture of where the ecosystem actually is.

**Pattern 3 — Per-shape throwaway scripts beat a generalized tool in one-pass migrations.** The temptation during this session was to write one parameterized Python that could handle Research, Experiments, Reflections, Audits, and Blog through some form of shape-discriminator arg. I wrote five small scripts instead. Each was ~80 lines, each output was auditable in isolation, each shape's edge cases surfaced as bugs in that shape's script rather than as latent bugs in a general-purpose parser. The handoff for the 70+-repo ecosystem migration does recommend generalizing the tool — because at that scale the abstraction pays for itself — but for five one-shot migrations the abstract tool would have cost more than it saved. The general rule: abstract when the abstraction will be reused; do five direct things when the fifth doesn't exist yet.

**Pattern 4 — User-driven scope widening beats author-predicted scope.** The session's scope widened three times in response to user prompts: "are other sections overbuilt?" surfaced the committed-snapshot architecture; "there are more `_index.md` files, for example `/audit`" surfaced the Reflections / Audits / Blog migrations; "the markdown is arguably something we should remove entirely" surfaced the delete-and-point decision. I did not predict any of these widenings from the original task description. Attempting to predict them upfront would have either over-scoped the initial task (weeks of up-front analysis) or under-scoped it (same as happened, but without the benefit of the widening prompts). The working pattern is: execute the currently-declared scope cleanly; stay responsive to widening prompts; make the incremental scope steps observable in the reflection so the next session inherits the widened understanding.

## Action Items

- [ ] **[skill]** research-process + experiment-process: Add a "transition clause" convention for skills describing ecosystem rules during multi-phase migrations. The specific addition: a drop-in sentence pattern like "{rule} applies to new work. Legacy {artifacts} migrate on {condition}; once migrated, {rule} becomes strict for that repo." Motivating incident: `[RES-003c]` and `[EXP-003e]` currently describe `_index.md is forbidden` as present-tense truth, but 154 legacy files exist across superrepos. The convention lets skills stay accurate during multi-phase rollouts without either softening the going-forward rule or pretending the ecosystem already complies.
- [ ] **[blog]** "The over-built copy step" — architectural simplification narrative anchored on the `raw.githubusercontent.com` pivot. The piece writes the first-principles arc: built a deploy-time manifest sync to keep the dashboard "fresh," user asked why it couldn't fetch direct, verified CORS + cache, ripped out ~30 lines for a net-better architecture. Generalizable lesson: when data isn't a build artifact, don't treat it like one. Receipts: the diff of the deploy-workflow change + the dashboard.js fetch URL + the CORS headers from curl.
- [ ] **[research]** Scope-filter dashboard aggregation strategy. Once the 70+-repo ecosystem migration completes per the handoff, the eventual "all swift-primitives research + all swift-foundations research + …" aggregation needs design work upstream of implementation: how does the dashboard discover the list of `_index.json` URLs (manifest file vs. GitHub API vs. enumeration)? How do schemas harmonize across per-package indexes that may have slight shape variations? What does the scope-pill UX look like when some corpora are large (swift-memory-primitives/Research, 45 rows) and others are sparse? This is Tier 2 research, cross-package, worth resolving before the migration lands so the JSONs are authored future-compatible.

## Cleanup

**Handoff triage** per `[REFL-009]`:

- `/Users/coen/Developer/HANDOFF.md` — scanned. Written this session per `/handoff` for the 154-file ecosystem migration. Next Steps enumerate six concrete items; none executed. No supervisor ground-rules block (routine sequential handoff, not cross-session supervised work). No pending escalation. Work is explicitly handed off to a future session and is NOT complete this session. **Disposition: leave in place** per `[REFL-009]` (some items remain, no ground-rules violation).

- `swift-institute.org/HANDOFF.md` — already deleted in the prior `/reflect-session` this same calendar day. No longer exists.

No other `HANDOFF-*.md` files at the workspace root or within any of the active sibling repos.

**Audit findings** per `[REFL-010]`: `/audit` was not invoked this session. No audit status updates.

**Other artefacts left in place:**

- `/tmp/migrate_{indexes,reflections,audits,blog}.py` — ephemeral migration scripts, referenced in the handoff as fork candidates. Will evaporate on reboot. Handoff notes the reference-migration commits on each sibling repo as a fallback source.
- Research working tree: `_Package-Insights.md` (gitignored) and `path-type-ecosystem-model.md` (untracked, not mine) left as-is.
- Research `whitepaper` branch: one pending-merge decision on `Reflections/_index.md`, pre-existing, user's call.
