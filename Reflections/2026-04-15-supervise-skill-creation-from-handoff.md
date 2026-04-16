---
date: 2026-04-15
session_objective: Create a new /supervise skill from the parent session's branching handoff brief, covering ground-rules setup, drift detection, termination, and composition with /handoff
packages:
  - swift-institute
status: processed
processed_date: 2026-04-16
triage_outcomes:
  - type: skill_update
    target: skill-lifecycle
    description: "Added [SKILL-CREATE-006a] Internal Consistency Pass (cross-ref correctness, terminology collisions, research-vs-shipped ID divergence, ghost references)"
  - type: research_topic
    target: handoff-vs-convention-resolution-protocol.md
    description: "Codify: when handoff specifies structural choice conflicting with skill convention, skills win"
  - type: no_action
    description: "[x] handoff reciprocal cross-reference — already resolved in-session per entry's own triage_outcomes"
---

# /supervise Skill Creation — Handoff vs Convention, Self-Review Yield

## What Happened

Branching investigation invoked from the swift-io Phase 3 parent session (`HANDOFF-supervise-skill-creation.md` at `/Users/coen/Developer/swift-foundations/swift-io/`). Mandate: research agent supervision patterns, then author a `/supervise` skill that codifies the principal-supervises-subordinate posture, distinct from the discrete-transfer `/handoff` skill.

Phase 1: dispatched a research sub-agent to survey nine production multi-agent systems (Anthropic orchestrator-worker, Anthropic multi-agent research, LangGraph supervisor, CrewAI hierarchical, AutoGen GroupChatManager, MetaGPT SOP, Semantic Kernel group chat, Magentic-One ledgers, OpenAI Swarm). Output: 229-line Tier 2 research doc at `swift-institute/Research/agent-supervision-patterns.md` distilling seven supervision axes and reverse-engineering the parent session's `HANDOFF.md:55` (*"Supervisor constraints #1–#4: all verified end-to-end"*) as the lived example.

Phase 2: authored the skill at `swift-institute/Skills/supervise/SKILL.md` — 17 requirement IDs (`[SUPER-001]`, `[SUPER-001a]`, `[SUPER-002]–[SUPER-016]`), 375 lines after fixes, organized as Mode Selection → Ground Rules → Runtime Posture → Termination → Cross-Cutting → Procedure. Updated the Skill Index in `swift-institute-core`, the workspace `CLAUDE.md` Skill Routing table, and `swift-institute/Research/_index.md`. Ran `Scripts/sync-skills.sh` — symlink created at `Developer/.claude/skills/supervise`.

Pre-flight path correction by the user: I was about to write to `~/.claude/skills/supervise/` per the handoff's literal text. The user interrupted with *"should it not be put here?"* pointing at `/Users/coen/Developer/swift-institute/Skills/`. After clarifying the trade-off (handoff specifies vs. convention requires) the user chose convention. Saved a feedback memory (`feedback_skills_follow_institute_convention.md`) so the same pattern does not need re-litigation.

User-requested self-review after authoring caught nine issues: (1) `[SUPER-001]` cross-reference range was wrong (`[SUPER-013]` should have been `[SUPER-015]` or `[SUPER-016]`); (2) "Departing agent" in the `[SUPER-001a]` table was wrong for branching handoffs; (3) Step 2 of `[SUPER-016]` only handled pre-dispatch, not mid-flight; (4) IDs diverged between research draft and shipped skill; (5) `[SUPER-001a]` Composition sentence duplicated the normative claim of `[SUPER-011]`; (6) `SUPERVISE.md` was a ghost reference with no template; (7) `Why:` sub-field prefix collided with `fact:`/`ask:` entry-type prefixes; (8) sub-agent atomicity was not acknowledged anywhere; (9) "Task boundaries" named two different concepts in `[SUPER-003]` (scope) and `[SUPER-007]` (temporal). All nine fixed.

Findings appended to the parent handoff doc as instructed.

**In-session update to `/reflect-session`** (prompted by user during reflection): the new `/supervise` skill places supervisor ground-rules blocks in HANDOFF.md Constraints sections (per `[SUPER-014]`), but `[REFL-009]`'s handoff-cleanup procedure only enumerated Next Steps and Scope items — it would have silently deleted a handoff with completed Next Steps but unverified ground-rules. Applied an additive fix: added a "Ground-rules verified?" check row to `[REFL-009]` step 2; added a row to `[REFL-008]`'s cleanup-scope table for supervisor blocks; updated step-4 disposition rules to require both items-complete *and* ground-rules-verified before deletion. Per `[SKILL-LIFE-003]` this is Additive — handoffs without supervisor blocks behave exactly as before.

**Handoff triage** (per `[REFL-009]` step 5): scanned for handoffs at the working directory root. The only handoff this session knows about is `/Users/coen/Developer/swift-foundations/swift-io/HANDOFF-supervise-skill-creation.md` — the branching-investigation brief that initiated this work. All Phase 1 (research) and Phase 2 (skill authoring) items complete; Findings section appended per the brief's instructions. **Decision: leave the file in place** for the parent session to triage. Reasoning: the file is its own Findings Destination; the parent session has not yet read the appended Findings; deleting before the reader consumes the result would defeat the branching-handoff contract per `[HANDOFF-005]`. The other 13 `HANDOFF-*.md` files at the swift-io root belong to unrelated parent-session work and are out of this session's scope to triage.

## What Worked and What Didn't

**Worked**:
- The user's mid-flight correction caught the path error before any artifacts were written. Cheap to fix, expensive if discovered after the skill had been committed and referenced.
- Research delegation produced quality output (Tier 2 prior art, primary-source citations, distilled axes). The brief was self-contained per the agent-output-discipline memory; the agent returned a one-line confirmation.
- Self-review at user request was high-yield: 9 real issues from a single pass on a skill that had already been "finished." None of these were caught by template adherence (skill-lifecycle's `[SKILL-CREATE-005]` and `[SKILL-CREATE-006]`).
- The shipped skill survived the self-review with its structure intact — fixes were targeted edits, not rewrites.

**Didn't work**:
- I trusted the handoff's literal path over the established convention. CLAUDE.md is explicit: *"Skills are the canonical source for all requirement IDs and implementation rules. Skills override any memorized patterns."* By analogy skills should override handoff specifications too, but I followed the handoff. Took a user interrupt to surface the conflict.
- Research-doc Skill Translation table predicted 15 IDs; shipped skill has 17. Drift was not flagged at authoring time — only at self-review. The research doc became out-of-date the moment the skill diverged from its draft mapping; the lag was unnecessary.
- Terminology collision between `[SUPER-003]` "Task boundaries" (scope, the field name) and `[SUPER-007]` "Task boundaries" (temporal, the intervention checkpoints) survived initial authoring. Same noun, two referents, in adjacent requirements. Linguistic blindness — both readings felt natural in their local context.

## Patterns and Root Causes

**Pattern: handoff documents are not authoritative on infrastructure conventions.** A handoff brief is one agent's compressed snapshot of *task* state. Conventions (where skills live, how research is organized, how cross-references are structured) are *ecosystem* state. The two have different lifetimes and different update cadences. When they conflict, the handoff is wrong by definition: it cannot have updated the convention. The fix is structural — when reading a handoff, scan it for path/structural claims and check those against convention before acting on the rest. The salience of the handoff (right in front of the agent, freshly written) makes it tempting to defer to.

**Pattern: template-adherent skills can still have semantic ambiguities.** The skill-lifecycle template (`[SKILL-CREATE-005]` structure, `[SKILL-CREATE-006]` content) ensures every skill has frontmatter, statements, rationales, cross-references. It does not check for: cross-reference range correctness, terminology collisions across requirements, ID divergence between draft research and shipped skill, ghost references to undefined concepts. These are semantic, not syntactic — they only surface when reading the skill as a coherent whole. The implication: there is a real gap between "the template is satisfied" and "the skill is internally consistent." A dedicated review pass between authoring and integration would close it.

**Pattern: research → skill drift is normal but trackable.** The research doc's "Skill Translation" table was a draft mapping written *before* the skill existed. The skill's actual structure emerged during authoring as the relationships between the seven axes clarified (e.g., termination clearly belongs *with* re-handoff composition because re-handoff *is* a termination mode — they cluster). Drift between the draft mapping and the shipped IDs is not a failure; it is the design crystallizing. What matters is that the artifacts agree at end of session. Updating the research's table to match shipped IDs (Fix 4) was the closing step that prevents future readers from being misled.

**Pattern: composition is the interesting design surface.** Both `/handoff` and `/supervise` are now codified, but the actual high-leverage decisions are about how they compose: a supervisor produces a handoff on degradation; a handoff sets up the conditions a fresh principal then enforces; the swift-io `HANDOFF.md:55` line *"Supervisor constraints #1–#4: all verified end-to-end"* is the point where they touch. The reciprocal pointer from `/handoff` back to `/supervise` is missing — currently `/handoff` only references `/reflect-session`, not its in-flight oversight counterpart. This is an action item below.

## Action Items

- [x] **[skill]** handoff: Add reciprocal cross-reference to `/supervise`. **Resolved in-session** (2026-04-15): instead of the originally-proposed point edits to `[HANDOFF-002]`/`[HANDOFF-009]`, applied a more comprehensive integration — new `[HANDOFF-012]` Supervisor Block (Optional) with when-to-use table; updated `[HANDOFF-004]` Sequential Template to add a `### Supervisor ground rules` sub-section under Constraints; updated `[HANDOFF-010]` Resume Protocol step 5 to require the new agent to verify supervisor-block entries; added `supervise` to bottom Cross-References block. Provenance: this reflection.

- [ ] **[skill]** skill-lifecycle: Add `[SKILL-CREATE-006a]` Internal Consistency Pass between authoring (`[SKILL-CREATE-006]`) and integration (`[SKILL-CREATE-007]`). The pass should check for (a) cross-reference range correctness, (b) terminology collisions across requirements, (c) ID divergence between any predecessor research doc and the shipped skill, (d) ghost references to undefined files/concepts. This session's self-review caught nine such issues that template adherence alone missed.

- [ ] **[research]** Document the resolution protocol when a handoff specifies a structural choice (file path, naming, location) that conflicts with established skill convention. This session needed user clarification on path; the resolution rule is "skills override handoff specifications" but it is not written down anywhere. A short research note codifying the rule, with the supervise-skill creation as the worked example, would prevent future re-litigation of the same pattern.
