---
date: 2026-04-16
session_objective: Promote parameter-ordering conventions (configuration placement + closure positioning) into code-surface as normative rules, via /research-process and /code-surface.
packages:
  - swift-institute
status: pending
---

# Parameter Ordering Conventions — and a Skill-Lifecycle Routing Gap

## What Happened

The session's content objective was to codify parameter-ordering conventions into `code-surface`. Flow:

1. Loaded `implementation` and `code-surface` skills.
2. Ecosystem survey via Explore agent across `swift-primitives`, `swift-standards`, `swift-foundations` — zero violations of any candidate rule set.
3. User asked for `/research-process`. Loaded it, classified as **Tier 2** (cross-ecosystem, precedent-setting, reversible), performed prior-art survey: Apple API Design Guidelines, SE-0279 / SE-0286 / SE-0245, TSPL, stdlib precedents, community writing (Sundell, hpique, Point-Free, objc.io, Swift Forums). Wrote `swift-institute/Research/parameter-ordering-conventions.md` as RECOMMENDATION.
4. User said "insert the rules". I inserted `[API-IMPL-012]` – `[API-IMPL-015]` into `code-surface/SKILL.md` as a new "## Parameter Ordering" section and extended the Post-Implementation Checklist.
5. User asked "did you follow /skills?". I loaded `skill-lifecycle` — *after* the edit — and audited the update. One defect: no explicit `[SKILL-LIFE-003]` classification recorded. Classified retroactively as **Additive** (zero-violation ecosystem survey confirms no previously-conforming code is now non-conforming), documented in the research doc's changelog. Research doc bumped from RECOMMENDATION → DECISION (v1.1.0); `_index.md` updated.

**Handoff triage per [REFL-009]**: scanned `/Users/coen/Developer/` and `swift-institute/` for `HANDOFF*.md`. Six pre-existing handoff files found (executor-main-platform-runloop, io-completion-migration, migration-audit, path-decomposition, primitive-protocol-audit, swift-institute/HANDOFF.md) — none touched by this session. Left unchanged.

**Audit cleanup per [REFL-010]**: no `/audit` invoked this session. N/A.

## What Worked and What Didn't

**Worked**:
- Tier-2 methodology ([RES-020], [RES-021] contextualization) caught a real tension — API Design Guidelines' "defaults at end" vs. stdlib closure-bearing APIs — that a shallower survey would have missed. The contextualization step prevented "universal adoption → must adopt" bias: the survey asked what adopting each pattern would cost in a `~Copyable` / typed-throws / Property.View / nested-namespace ecosystem, and confirmed zero structural conflict.
- Two surveys (internal ecosystem + external prior art) as independent evidence streams converged on the same ruleset. Zero-violation ecosystem survey made the Additive classification trivially defensible.
- Inserting the rules followed `[SKILL-CREATE-005/006]` structure (Statement → Correct → Incorrect → Rationale → Cross-references → Provenance). All cross-references resolved on a read-through ([IMPL-092], [PATTERN-016], [API-NAME-002], intra-[API-IMPL-*]). The [SKILL-CREATE-006a] consistency pass was implicit but passed.

**Didn't work**:
- I loaded `skill-lifecycle` **after** the skill edit, not before. `[REFL-003]` contains an explicit "pre-edit checkpoint": *"When a session directly modifies a skill (not via /reflections_processing), the skill-lifecycle skill MUST be loaded first per [SKILL-LIFE-001] and [SKILL-LIFE-002]."* This is a MUST. I missed it.
- The user's "did you follow /skills?" was a clean corrective signal; the only recoverable defect was the missing explicit classification, which I added to the research changelog. But the procedural slip was real.

## Patterns and Root Causes

The pre-edit checkpoint in `[REFL-003]` is a rule about **what to do before a skill edit**. Its home is in `reflect-session`, which loads at *session end*. That placement guarantees the rule cannot fire before the edit it governs — it is, structurally, a post-edit rule filed as a pre-edit rule.

The proximate failure: when a session's flow is a chain of content-skill loads (`implementation` → `code-surface` → `research-process`) culminating in a skill edit, the edit feels like the **trailing action of the content task**, not the **leading action of a lifecycle task**. The mental model that would surface "I should load skill-lifecycle first" isn't primed, because:

1. The content skills are already loaded and carry most of the task's working memory.
2. `skill-lifecycle`'s content is orthogonal to the content-skill rules — it governs *how* to update, not *what* to update with. Loading it feels like overhead.
3. The one place where the pre-edit rule is actually stated (`[REFL-003]`) is not consulted at edit time.

The deeper pattern: **process rules that gate an action should live in the skill that the action consults, not in the skill that wraps up the session**. `/code-surface` edits → `skill-lifecycle` must be loaded. But the rule saying so lives in `/reflect-session`. It's structurally misfiled. Duplicating or moving the checkpoint into `skill-lifecycle` itself would make it discoverable by anyone who considers loading `skill-lifecycle` — which is the actual window where the rule needs to fire.

The `CLAUDE.md` skill-routing table in `/Users/coen/Developer/CLAUDE.md` already contains entries like "Skill lifecycle (create/update/review/deprecate) → skill-lifecycle". That routing exists; what's missing is an assertion that **modifying a skill file IS a skill-lifecycle task** and therefore triggers the routing.

Secondary pattern (minor): the three-step "user asks why, I audit, I fix" cadence is a cheap-and-clean corrective loop. Worth preserving: when a user questions a process step, treat it as a checklist trigger, not a defense opportunity. The audit table I produced (checklist items with ✓/✗) was the right format.

## Action Items

- [ ] **[skill]** skill-lifecycle: Mirror `[REFL-003]`'s pre-edit checkpoint into skill-lifecycle's Phase 5 (Skill Updates) intro, so that the "load skill-lifecycle before editing a skill file" requirement is surfaced by the skill whose domain it belongs to — not only by `reflect-session`, which loads after the edit.
- [ ] **[doc]** `/Users/coen/Developer/CLAUDE.md`: Add a one-line assertion under "Skill Routing" that editing any `SKILL.md` file MUST route to `skill-lifecycle` first, not only the `/skill-lifecycle` command. The current routing table entry names the command but does not make the "edits-to-SKILL.md → skill-lifecycle" equivalence explicit.
