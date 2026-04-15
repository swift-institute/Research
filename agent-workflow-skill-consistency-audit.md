# Agent Workflow Skill Consistency Audit

<!--
---
date: 2026-04-15
status: COMPLETE
audited_skills:
  - handoff
  - supervise
  - reflect-session
  - skill-lifecycle
---
-->

## Scope

This audit peer-reviews the four agent-workflow skills as a cluster: the recently updated `handoff` (with new [HANDOFF-012] Supervisor Block and edits to [HANDOFF-004]/[HANDOFF-010]), the freshly created `supervise` (17 IDs [SUPER-001]..[SUPER-016] plus [SUPER-001a]), the updated `reflect-session` (new ground-rules verification rows in [REFL-008]/[REFL-009]), and the `skill-lifecycle` template authority that governs the other three. Focus is on cross-reference accuracy, terminology consistency, procedural composition (particularly the handoff↔supervise bridge), lifecycle compliance (frontmatter, index, sequential IDs), and gaps visible only now that all four skills are read together. Out of scope: internal correctness of skills that happen to be cited (e.g., [REFL-PROC-*], [AUDIT-*]); they are checked only as referenceable anchors.

Supporting context was read from `Research/agent-supervision-patterns.md` and `Research/agent-handoff-patterns.md` to verify that the shipped skills match the research they claim to implement.

## Summary

| Category | Findings | Severity |
|---|---|---|
| A. Cross-reference accuracy | 4 | MEDIUM (mostly polish) |
| B. Terminology consistency | 5 | MEDIUM–HIGH |
| C. Procedural gaps | 4 | HIGH |
| D. skill-lifecycle compliance | 4 | MEDIUM |
| E. Composition correctness | 3 | HIGH |
| F. Self-consistency within /supervise | 2 | LOW–MEDIUM |
| G. Hindsight gaps | 4 | MEDIUM–HIGH |

Total: 26 findings (7 HIGH severity, 13 MEDIUM, 6 LOW).

## Disposition (post-audit, 2026-04-15)

Worked through findings in five severity-batched waves. Status snapshot:

| ID | Status | Where applied |
|---|---|---|
| A.1 | RESOLVED 2026-04-15 | reflect-session [REFL-003] Pre-edit checkpoint cross-refs added |
| A.2 | RESOLVED 2026-04-15 | supervise [SUPER-011] cross-refs extended |
| A.3 | RESOLVED 2026-04-15 | supervise [SUPER-001a] Author row refined to cover progressive capture |
| A.4 | RESOLVED 2026-04-15 | CLAUDE.md gained composition routing row |
| B.1 | RESOLVED 2026-04-15 | Heading canonicalized to `### Supervisor Ground Rules` (Title Case) across handoff / reflect-session |
| B.2 | RESOLVED 2026-04-15 | handoff [HANDOFF-012] gained Constraints / Do Not Touch / Task boundaries terminology map |
| B.3 | RESOLVED 2026-04-15 | Research doc Axis 5 footnoted with "task boundaries" → "intervention points" rename |
| B.4 | PARTIAL 2026-04-15 | handoff [HANDOFF-012] gained principal/subordinate glossary; full vocabulary harmonization across /handoff body deferred (low yield) |
| B.5 | RESOLVED 2026-04-15 | supervise [SUPER-014a] Supervisor in Absentia introduced |
| C.1 | RESOLVED 2026-04-15 | supervise [SUPER-012] gained persistence-target table (3 escalation locations) |
| C.2 | RESOLVED 2026-04-15 | supervise [SUPER-011] gained entry-type evidence-form table |
| C.3 | RESOLVED 2026-04-15 | reflect-session [REFL-009] disposition row added for fresh-dispatch case |
| C.4 | RESOLVED 2026-04-15 | supervise [SUPER-016] Step 4 re-handoff bullet now invokes /handoff first |
| D.1 | RESOLVED 2026-04-15 | skill-lifecycle [SKILL-CREATE-003] redirects to swift-institute-core skill index |
| D.2 | RESOLVED 2026-04-15 | skill-lifecycle Phase 5 preface explains numeric clusters |
| D.3 | RESOLVED 2026-04-15 | handoff and supervise gained `requires: swift-institute-core` |
| D.4 | RESOLVED 2026-04-15 | skill-lifecycle [SKILL-LIFE-012] adds creation-as-review-zero rule |
| E.1 | RESOLVED 2026-04-15 | handoff [HANDOFF-010] step 5 requires verification stamp on all three termination paths |
| E.2 | RESOLVED 2026-04-15 | handoff [HANDOFF-012] rationale softened from "supervisor role" to "ground-rules role"; mechanics in supervise [SUPER-014a] |
| E.3 | RESOLVED 2026-04-15 | reflect-session [REFL-009] disposition row added for empty-block detection |
| F.1 | RESOLVED 2026-04-15 | supervise [SUPER-007] gained sub-agent intervention-point collapse note |
| F.2 | RESOLVED 2026-04-15 | supervise [SUPER-014] mid-flight row updated for no-HANDOFF.md case |
| G.1 | RESOLVED 2026-04-15 | supervise [SUPER-014a] encodes class (b) → (c) escalation in absentia (option A with pre-escalation re-read) |
| G.2 | RESOLVED 2026-04-15 | reflect-session [REFL-009] disposition row added for escalation-resolved cleanup |
| G.3 | RESOLVED 2026-04-15 | skill-lifecycle Phase 5 preface adds workflow-skill self-reference rule (queue outside the session, exception when session purpose IS the cluster work) |
| G.4 | RESOLVED 2026-04-15 | supervise [SUPER-015] adds compression-on-overflow sub-requirement with `(merges #N, #M)` supersession notation |

**Coverage**: 25 RESOLVED, 1 PARTIAL. No findings deferred or rejected.

**Provenance for fixes**: `Reflections/2026-04-15-agent-workflow-cluster-audit-and-fixes.md`.

---

## Findings

### A.1 — REFL-003 "Pre-edit checkpoint" cross-reference under SKILL-CREATE inconsistency

**Skill / location**: `reflect-session/SKILL.md:162`
**Severity**: LOW
**Issue**: [REFL-003]'s "Pre-edit checkpoint" paragraph says *"When a session directly modifies a skill (not via `/reflections_processing`), the skill-lifecycle skill MUST be loaded first."* It refers to the skill by name but never cites an ID in skill-lifecycle. The closest matching anchor is [SKILL-LIFE-001] (Minimal Revision) or [SKILL-LIFE-002] (Update Provenance), both of which govern direct edits. The omission is minor but causes this checkpoint to float without the lifecycle cross-reference that the audit finding pattern would flag elsewhere.
**Why it matters**: A future reader who invokes `/reflect_session` mid-session and then wants the exact skill-lifecycle rule has to go hunting. Other REFL-N sections (e.g., [REFL-002] cross-referencing [REFL-003], [REFL-005]) scrupulously cite IDs; this paragraph breaks that pattern.
**Suggested fix**: Add a trailing "Cross-references: [SKILL-LIFE-001], [SKILL-LIFE-002]" to the Pre-edit checkpoint paragraph, or hoist it into its own numbered requirement if it is load-bearing.

### A.2 — SUPER-011 citing HANDOFF-002 and HANDOFF-009 for re-handoff composition is plausible but HANDOFF-010 is the actual pickup path

**Skill / location**: `supervise/SKILL.md:263`
**Severity**: LOW
**Issue**: [SUPER-011] Re-Handoff Composition ends with *"Cross-references: [HANDOFF-002], [HANDOFF-009]"*. These are the sequential procedure and progressive-capture rules, which author/update the HANDOFF.md. But the *downstream* composition — the new agent's pickup of the supervisor block — is governed by [HANDOFF-010] step 5 and [HANDOFF-012], neither of which is cited here. The cross-reference set is incomplete relative to the end-to-end loop.
**Why it matters**: Readers of /supervise who want to understand what happens after a re-handoff will miss the inheritance protocol. It also means grep-based navigation loses a link that the inverse ([HANDOFF-012] cites [SUPER-011]) explicitly establishes.
**Suggested fix**: Append `[HANDOFF-010], [HANDOFF-012]` to the [SUPER-011] Cross-references line at `supervise/SKILL.md:263`.

### A.3 — SUPER-001a mis-labels the sequential-handoff author as "departing"

**Skill / location**: `supervise/SKILL.md:66`
**Severity**: LOW
**Issue**: The table row reads: *"Author | Authoring agent (departing in sequential mode; parent in branching mode)"*. In sequential mode the author is "the departing agent" per the research doc (`agent-handoff-patterns.md:36`) and per the [HANDOFF-002] Sequential Procedure. But [HANDOFF-009] Progressive Capture explicitly describes an agent that invokes `/handoff` *mid-session* at natural milestones — a living agent, not a departing one. The descriptor "departing" is true for the final handoff only.
**Why it matters**: Minor, but it subtly contradicts /handoff's own progressive-capture doctrine. A reader arriving at /supervise first gets the wrong mental model of when /handoff fires.
**Suggested fix**: Change the row to `Authoring agent (sequential) or parent (branching)` or `Authoring agent (who MAY be departing or still running in progressive mode)`.

### A.4 — CLAUDE.md handoff row mentions only "handing off to a new session or spinning off investigation" — no mention that /handoff is composable with /supervise

**Skill / location**: `/Users/coen/Developer/CLAUDE.md:94-95`
**Severity**: LOW
**Issue**: The Skill Routing table row for **handoff** says *"Handing off to a new session or spinning off investigation"*. The newly added **supervise** row sits immediately below. Neither hints that the two compose. Given the recent addition of [HANDOFF-012], routing by the table alone makes the composition invisible — a reader picks one or the other.
**Why it matters**: This is the top-of-funnel routing table. If a principal agent has non-obvious constraints and is about to hand off, nothing in the routing cues them to invoke /supervise first.
**Suggested fix**: Either merge the two rows into a composition hint, or add a line below: `| Handing off with non-obvious constraints | **handoff** + **supervise** | [HANDOFF-012], [SUPER-002] |`.

---

### B.1 — "Supervisor ground rules" heading spelling vs code reference form

**Skill / location**: `handoff/SKILL.md:117`, `handoff/SKILL.md:262`, `handoff/SKILL.md:298`, `reflect-session/SKILL.md:270`, `reflect-session/SKILL.md:294`
**Severity**: HIGH
**Issue**: The heading defined in [HANDOFF-004] template is literal markdown: *`### Supervisor ground rules`* (three words, no hyphen, `handoff/SKILL.md:117`). Yet:

- [HANDOFF-010] step 5 (`handoff/SKILL.md:262`) says *"If a `### Supervisor ground rules` sub-section is present in Constraints"* — correct form.
- [HANDOFF-012] (`handoff/SKILL.md:298`, `:309`) uses *"`Constraints / ### Supervisor ground rules` sub-section"* — correct form.
- [REFL-008] (`reflect-session/SKILL.md:270`) refers to *"Supervisor ground-rules block"* — hyphenated compound noun.
- [REFL-009] step 4 disposition row (`reflect-session/SKILL.md:309`) refers to *"ground-rules entries"* — hyphenated.
- [REFL-009] Provenance line (`reflect-session/SKILL.md:323`) refers to *"ground-rules blocks"* — hyphenated.
- /supervise itself consistently says *"ground-rules block"* (hyphenated, e.g., `supervise/SKILL.md:81`).

The heading encoded literally in HANDOFF.md is `### Supervisor ground rules` (unhyphenated), but both /supervise and /reflect-session talk about it as *"supervisor ground-rules block"* (hyphenated). The cleanup check in [REFL-009] says to *"Inspect Constraints section for typed entries"* without telling the agent whether to grep for `### Supervisor ground rules` or `### Supervisor ground-rules`.
**Why it matters**: When /reflect-session runs the cleanup procedure, the agent must find the sub-section heading. If it greps for the hyphenated form ("supervisor ground-rules"), it will miss the literal heading. If it matches loosely, false positives are possible. This is the exact kind of encoding drift that breaks automated scans.
**Suggested fix**: Pick one canonical form. Recommendation: rename the heading in [HANDOFF-004] to `### Supervisor Ground-Rules Block` (matching the supervise terminology exactly), or update all references in /reflect-session and /supervise to the unhyphenated *"ground rules"* form when the heading itself is meant. Update all five citations accordingly.

### B.2 — "Task boundaries" collision is flagged in /supervise but not in /handoff's Constraints/Do Not Touch fields

**Skill / location**: `supervise/SKILL.md:105`, `supervise/SKILL.md:162`, `supervise/SKILL.md:176`, `handoff/SKILL.md:115`, `handoff/SKILL.md:177`
**Severity**: MEDIUM
**Issue**: /supervise explicitly caveats the collision: [SUPER-003] has *"Task boundaries | Explicit 'do not touch' — files, packages, decisions out of scope"* (line 105), then [SUPER-007]'s "Intervention points" note (line 176) clarifies *"distinct from [SUPER-003]'s Task boundaries field, which names scope; this list names temporal checkpoints"*. This is good. But /handoff's two templates have essentially the same concept encoded twice with *different* names:
- [HANDOFF-004] Sequential Template has a `## Constraints` section (`handoff/SKILL.md:114-115`): *"Non-obvious limitations: compiler bugs, API gaps, performance bounds, etc."*
- [HANDOFF-005] Branching Template has `## Do Not Touch` (`handoff/SKILL.md:177-179`): *"Auto-populated: files with uncommitted changes in git."*
- [SUPER-003]'s "Task boundaries" field is described as *"Explicit 'do not touch' — files, packages, decisions out of scope."*

Three terms ("Constraints", "Do Not Touch", "Task boundaries") for overlapping concepts. The supervisor block is placed *inside* the HANDOFF.md Constraints section, but the branching template never mentions where a supervisor block would live if branching mode embedded one (and [HANDOFF-012]'s "MAY include" for branching is silent on placement).
**Why it matters**: A reader writing a /supervise dispatch for a sub-agent gets one name for scope; writing a branching handoff gets another; writing a sequential handoff gets a third. The vocabulary needs to consolidate or the skills need to explicitly map them.
**Suggested fix**: Add a terminology map in either /handoff or /supervise: "Task boundaries (supervise) = Do Not Touch (branching handoff) = files under Constraints (sequential handoff)." Alternatively, rename the Sequential template's `## Constraints` to `## Constraints and Boundaries` and note that [SUPER-003] Task boundaries map into this section.

### B.3 — "Intervention point" vs "task boundary" vs "boundary-triggered"

**Skill / location**: `supervise/SKILL.md:69`, `supervise/SKILL.md:172-184`, `Research/agent-supervision-patterns.md:79`
**Severity**: MEDIUM
**Issue**: The research doc (`agent-supervision-patterns.md:79`) consistently uses *"task boundaries"* for Axis 5 — *"the principal MUST correct at task boundaries"*. [SUPER-007]'s shipped title is **Boundary-Triggered Intervention**, and the body uses *"intervention points"* (a new term, coined to avoid collision with [SUPER-003]'s "Task boundaries" field). [SUPER-001a]'s table row 6 (`supervise/SKILL.md:69`) then reverts: *"Principal verifies at each intervention point"* — correct internal term. But [SUPER-016] step 3 (`supervise/SKILL.md:352`) says *"At each intervention point (per [SUPER-007]: file write, question, phase completion, result report)"* — correct. Research doc uses the old term "task boundaries" in a way that the shipped skill now reserves for scope. A reader consulting the research will be confused; a reader consulting only the skill is fine.
**Why it matters**: The research document is cited as *"prior-art research backing /supervise"* (per the audit prompt and `supervise/SKILL.md:28`). When a reader jumps from [SUPER-007] into the research to understand the grounding, they see "task boundaries" used to mean "intervention points." The skill did the correct divergence; the research doc wasn't updated to match.
**Suggested fix**: Update `agent-supervision-patterns.md:79` and nearby (Axis 5 section and synthesis) to use the shipped term "intervention points" with a note: *"In earlier drafts this was called 'task boundaries', but the shipped skill reserves 'Task boundaries' for the scope field per [SUPER-003]."* Since the skill is canonical, the research doc is the thing that drifts.

### B.4 — "Principal"/"subordinate" not consistently used in /handoff

**Skill / location**: `handoff/SKILL.md:311` (only occurrence), `handoff/SKILL.md` throughout
**Severity**: LOW
**Issue**: /supervise's core vocabulary is *principal* (the supervising agent) and *subordinate* (the supervised agent). /handoff exclusively uses *new agent* and *authoring agent*, *departing agent*, *parent conversation*. The [HANDOFF-012] Supervisor Block introduces *"principal"* for the first time: *"a future principal (or the user) MAY resume active supervision"* (`handoff/SKILL.md:311`). This is the only occurrence in /handoff. The neighbouring cross-reference paragraph (line 323) says *"while a subordinate works"* — also the only occurrence. So /handoff imports /supervise vocabulary in exactly two lines of one requirement, while elsewhere using the old vocabulary.
**Why it matters**: A reader who only ever invokes /handoff (never /supervise) encounters "principal" with no definition in scope. The [SUPER-001a] table is the definition site; it lives in a sibling skill.
**Suggested fix**: Either (a) add a one-line glossary to /handoff near [HANDOFF-012] pointing to [SUPER-001a]'s vocabulary table, or (b) replace "future principal" with "future supervising agent" inline and let /supervise own the compressed term.

### B.5 — "Supervisor in absentia" coined once, never indexed

**Skill / location**: `handoff/SKILL.md:311`, not present in /supervise
**Severity**: MEDIUM
**Issue**: [HANDOFF-012]'s rationale block introduces the concept *"Supervisor in absentia"* (`handoff/SKILL.md:311`): *"After the handing-off agent's session ends, no live supervisor exists. The block plays the supervisor role..."*. This is a load-bearing concept — it explains *why* the block exists — but it is not discussed in /supervise at all. [SUPER-014] Block Location describes the block as something *"both principal and subordinate can re-read between turns"*, which assumes a live principal. The "absentia" degenerate case, where the principal is gone and the block *is* the supervisor, is only handled in /handoff.
**Why it matters**: /supervise's requirements presume a live principal (e.g., [SUPER-005] Question Classification, [SUPER-015] Progressive Refinement both depend on the principal answering and updating). If the supervisor is in absentia, the new agent has no one to ask. /supervise should acknowledge this state explicitly; today it is invented in /handoff with no back-reference.
**Suggested fix**: Add a requirement or sub-section to /supervise (perhaps as [SUPER-014a] or a sub-section of [SUPER-014]) titled "Supervisor in absentia" describing the degenerate case: block on disk, no live principal, new agent reads it as binding and self-verifies; any class-(b) question that would normally be answered by the principal becomes class-(c) (escalate to user) until a new principal adopts the block. Cross-reference [HANDOFF-012].

---

### C.1 — Escalation (SUPER-010/SUPER-012) leaves the HANDOFF.md-plus-ground-rules-block in an undefined state

**Skill / location**: `supervise/SKILL.md:231-242`, `supervise/SKILL.md:267-281`, `reflect-session/SKILL.md:309`
**Severity**: HIGH
**Issue**: [SUPER-010] says *"Escalation | A scope question only the user can answer arises | Escalate per [SUPER-012]; supervision is paused until the user resolves"*. There is no requirement governing what happens if the user never resumes the session, or if the principal's session ends with an escalation outstanding. [SUPER-012] is purely about the *format* of the escalation message. [SUPER-016] Step 4 says *"If escalation: surface the question to the user per [SUPER-012]"* — and then the procedure terminates without telling the principal to write anything to disk.

Now trace through /reflect-session: [REFL-009]'s disposition table row says *"Some items remain, OR any ground-rules entry unverified"* → *"Leave the updated file"*. But an escalation is not literally an *"unverified entry"* nor an *"unfinished Next Step"* — it is a third thing: a question to the user that the principal couldn't answer. If /reflect-session fires after an escalated supervision phase, it does not know how to flag that state. Worst case: the handoff file is missing the escalated question entirely (since /supervise did not require writing it anywhere) and future sessions have no idea there is a pending escalation.
**Why it matters**: This is one of the three termination modes [SUPER-010] names, but it is the only one with no artifact. Success terminates with verification of criteria. Re-handoff terminates with a HANDOFF.md cited per [SUPER-011]. Escalation terminates with... nothing on disk. If the principal's session crashes or context overflows, the escalation is lost.
**Suggested fix**: Add a requirement [SUPER-012a] or amend [SUPER-012]: *"When escalating, the principal MUST also record the escalated question in a persistent artifact (Open Question in HANDOFF.md if one exists, or a fresh HANDOFF-escalation-{slug}.md) before ending the principal's turn. The ground-rules block remains on disk with the pre-escalation state."* Then amend [REFL-009]'s disposition table to add an "Escalation pending" row.

### C.2 — Resume protocol step 5 in HANDOFF-010 tells the new agent to "verify each entry as work proceeds" but does not define what verification looks like for each entry type

**Skill / location**: `handoff/SKILL.md:262`
**Severity**: HIGH
**Issue**: The edit to [HANDOFF-010] step 5 adds: *"treat its entries as binding constraints; verify each entry as work proceeds; report verification status if a re-handoff is produced per [SUPER-011]"*. But the four entry types from [SUPER-002] (MUST, MUST NOT, `fact:`, `ask:`) have radically different verification semantics:

- **MUST**: verify the required behavior was performed.
- **MUST NOT**: verify the forbidden approach was *not* taken — a negative fact, harder to prove.
- **`fact:`**: is a scope assertion, not an action; "verification" means checking the fact still holds (e.g., Linux-only guard still `#if os(Linux)`).
- **`ask:`**: is a stop-and-ask rule; verification is that no case arose where the agent *should* have asked but didn't.

None of this is spelled out. [SUPER-011] gives the *notation* (`#1–#4 verified` vs `#1 verified; #3 blocked`) but not the verification method per entry type. [REFL-009] line 294 says *"count unverified entries per the [SUPER-011] notation pattern"* — also purely notational.
**Why it matters**: Different entry types need different evidence. A MUST NOT that was never tempted is technically verified by "nothing happened"; a MUST NOT that was tempted and avoided is verified by evidence of refusal. The skill doesn't distinguish. The new agent will likely default to "all unchecked = unverified" or "all untouched = verified", and either is wrong.
**Suggested fix**: Either (a) add a sub-table to [HANDOFF-010] or [SUPER-011] mapping entry type → verification evidence form; or (b) explicitly note this is an open-ended methodological question and instruct the new agent to annotate verification with a brief evidence phrase alongside the count.

### C.3 — REFL-009's "Ground-rules verified?" check assumes every HANDOFF.md with a supervisor block has a SUPER-011 status line inline

**Skill / location**: `reflect-session/SKILL.md:294`
**Severity**: MEDIUM
**Issue**: The check says *"count unverified entries per the [SUPER-011] notation pattern (`Supervisor constraints #1–#N: all verified` vs `#1, #2 verified; #3 blocked`)"*. But [SUPER-011] is *only* invoked on re-handoff termination (per [SUPER-010]'s table row). A handoff written per [HANDOFF-012] as initial ground-rules (i.e., the principal is writing HANDOFF.md to launch a subordinate for the *first* time) has a `### Supervisor ground rules` sub-section but no verification status yet — the subordinate hasn't worked yet. [REFL-009]'s check will see N entries and zero verification notation, and the disposition table will classify this as *"any ground-rules entry unverified"* → *"Leave the updated file"*. That is correct behavior for an unstarted supervision, but the reasoning encoded in the procedure is wrong: it treats "no verification line written" as "work done but unverified" rather than "work not yet started."
**Why it matters**: For sessions that just set up a new supervision and then triggered a reflection (rare but possible — e.g., the principal authored the block, handed off, and now reflects), the reflect-session agent will annotate the handoff as "unverified" with no indication that no work has begun. A future session reading these annotations will misread the state.
**Suggested fix**: [REFL-009] should distinguish "block present with verification line" vs "block present without verification line (fresh dispatch)" vs "block present with partial verification." Amend the Check-table row: *"Ground-rules verified? | Inspect Constraints for `### Supervisor ground rules`. If entries present but no `#N verified` status line per [SUPER-011], this is a fresh dispatch — treat as 'pending verification', not 'unverified failure'."*

### C.4 — SUPER-010's "Re-handoff" termination mode writes HANDOFF.md, but [SUPER-016] Step 4 does not instruct calling /handoff, only "cite ground-rules status in HANDOFF.md per [SUPER-011]"

**Skill / location**: `supervise/SKILL.md:238`, `supervise/SKILL.md:363`
**Severity**: MEDIUM
**Issue**: [SUPER-010] row 2 says *"Re-handoff | Subordinate quality degrades, or work needs to continue in a fresh session | Invoke `/handoff` per [SUPER-011]; supervision ends when the handoff is written"*. Good — explicit skill chaining.

[SUPER-016] Step 4 says *"If re-handoff: cite ground-rules status in HANDOFF.md per [SUPER-011]"*. This assumes HANDOFF.md exists and the principal just appends to it. But [SUPER-010] says the trigger is a *fresh* session, which implies /handoff in sequential mode — which may be writing HANDOFF.md for the first time or updating per [HANDOFF-009]. The ordering matters: /handoff fills the template from scratch or updates, then [SUPER-011] cites status.
**Why it matters**: [SUPER-016] skips the *"invoke /handoff"* part and jumps to citation. A principal following [SUPER-016] literally will annotate an HANDOFF.md that doesn't yet exist. The fix in [SUPER-010] is correct; [SUPER-016] drops it.
**Suggested fix**: Amend [SUPER-016] Step 4's re-handoff bullet to: *"If re-handoff: invoke /handoff per [SUPER-010] (which will follow [HANDOFF-002] or [HANDOFF-009] as appropriate), then cite ground-rules status in the resulting HANDOFF.md per [SUPER-011]."*

---

### D.1 — SKILL-CREATE-003 "Existing prefixes" list is out of date

**Skill / location**: `skill-lifecycle/SKILL.md:61-69`
**Severity**: MEDIUM
**Issue**: [SKILL-CREATE-003] lists *"Existing prefixes (DO NOT reuse)"* and enumerates: `API-NAME`, `API-ERR`, `API-IMPL`, `API-LAYER`, `API-DESIGN`; `PATTERN-001–050`; `MEM-*`; `PRIM-*`; `COPY-FIX`, `COPY-REM`; `ARCH-LAYER`; `RES-*`, `EXP-*`, `BLOG-*`; `SKILL-CREATE`, `SKILL-LIFE`. This list is missing: `HANDOFF-*`, `SUPER-*`, `REFL-*`, `REFL-PROC-*`, `AUDIT-*`, `META-*`, `IDX-*`, `CONV-*`, `MEM-ARITH`, `MEM-SEND`, `MEM-REF`, `MEM-LIFE`, `PLAT-ARCH`, `MOD-*`, `INFRA-*`, `DS-*`, `INST-TEST-*`, `SWIFT-TEST-*`, `BENCH-*`, `DOC-*`, `DOC-MARKUP-*`, `README-*`, `PKG-EXPORT-*`, `COLLAB-*`, `SAVE-*`, `ISSUE-*`, `SWIFT-PR-*`, `SEM-DEP-*`, `TEST-*`, `PITCH-PROC-*`, `LEG-ENC-*`, `JUD-ENC-*`, `COMP-ENC-*`, `PROD-ENC-*`, `NL-WET-*`, `LEG-TEST-*`, `RL-CORE-*`. That is roughly 20+ active prefixes the list doesn't mention. The swift-institute-core Skill Index (the canonical list per this audit) has them all.
**Why it matters**: [SKILL-CREATE-003] is the gate against ID collisions. If it is stale, a new skill author checks this list, sees their chosen prefix is "new," and picks it — potentially colliding with an existing one. /supervise itself could have been authored against this stale list; it got away with `SUPER-*` which is genuinely new, but a future skill might collide with `SWIFT-*` or `META-*`.
**Suggested fix**: Replace the hand-maintained list with *"Existing prefixes: see swift-institute-core Skill Index — that is the canonical list."* Update immediately if keeping an inline mirror. Lifecycle was last reviewed 2026-03-20 (`skill-lifecycle/SKILL.md:16`) and the list is visibly stale.

### D.2 — SKILL-LIFE requirement IDs have unexplained gaps

**Skill / location**: `skill-lifecycle/SKILL.md:324-429`
**Severity**: LOW
**Issue**: [SKILL-LIFE-*] IDs: `001`, `002`, `003`, `010`, `011`, `012`, `020`, `021`, `022`. The gaps `004-009` and `013-019` are not explained. The other three audited skills do not have this pattern:

- handoff: 001–012 sequential with progressive numbering (012 appended after 011).
- supervise: 001, 001a, 002–016 sequential.
- reflect-session: 001–010 sequential.
- skill-lifecycle: 001–003, 010–012, 020–022. Three clusters with visible gaps.

The gaps appear intentional (one cluster per phase: updates/review/deprecation) but `SKILL-CREATE-*` uses *sequential* numbering 001–011 for *three* phases. The conventions aren't uniform within the skill itself.
**Why it matters**: `swift-institute-core/SKILL.md:74` says *"Requirement IDs follow `[PREFIX-NNN]` with a zero-padded integer"* and names foundational-axiom word-IDs as the only exception. Numeric gaps aren't forbidden, but they aren't explained either. A reader wondering "is there a SKILL-LIFE-013?" has to check the file.
**Suggested fix**: Either renumber to close the gaps, or add a comment near the top of the SKILL-LIFE block: *"Numeric clusters: 001–009 (updates), 010–019 (review), 020–029 (deprecation). Gaps reserved for future requirements within each cluster."* Low priority; ergonomic not functional.

### D.3 — supervise skill requires: [] but relies on swift-institute-core vocabulary conventions

**Skill / location**: `supervise/SKILL.md:9`, `handoff/SKILL.md:9`
**Severity**: MEDIUM
**Issue**: Both /handoff and /supervise declare `requires: []` (empty). But [SKILL-CREATE-004] says *"The `requires:` field MUST list all skills that must be loaded before this skill. At minimum, require `swift-institute-core` or `swift-institute`."* Neither of these two process skills requires either. /skill-lifecycle correctly requires `- swift-institute-core`. /reflect-session correctly requires `- swift-institute`.
**Why it matters**: Direct violation of [SKILL-CREATE-004]. The process skill author may reason that /handoff and /supervise are domain-agnostic (they work in any repo) and so don't need Swift Institute conventions — but the skills *do* cite swift-institute research documents and live in the ecosystem's skill tree. The requirement in [SKILL-CREATE-004] is unconditional.
**Suggested fix**: Add `- swift-institute-core` to both `requires:` fields. Or explicitly discuss the exception and update [SKILL-CREATE-004] to permit process skills that are ecosystem-agnostic.

### D.4 — /supervise's last_reviewed date (2026-04-15) is today — should it be authored-date or reviewed-date?

**Skill / location**: `supervise/SKILL.md:18`
**Severity**: LOW
**Issue**: The skill was created today (2026-04-15) and `last_reviewed: 2026-04-15`. [SKILL-LIFE-012] Review Cadence defines review cadence in *days from last review*. For a brand-new process skill, 2026-04-15 is strictly the creation date — no review has happened. Should it be `created: 2026-04-15` plus `last_reviewed: <not yet>`? Or is creation a review by definition? Lifecycle is silent.
**Why it matters**: When /corpus-meta-analysis fires on cadence, it will compute age = 0 days for /supervise. That is correct if creation ≡ review; deceptive if not. The other process skills set `last_reviewed` to a date later than their creation, which implies a distinction; /supervise collapses them.
**Suggested fix**: Clarify in [SKILL-LIFE-012] that `last_reviewed` is the date of the most recent full review OR the creation date if never reviewed, and creation counts as review-zero. Alternatively, add a `created` field to the frontmatter template and interpret `last_reviewed` strictly. Current practice works; the convention needs to be written down.

---

### E.1 — Composition trace: supervise → re-handoff → new agent → reflect-session runs, but where does the escalation trace go?

**Skill / location**: End-to-end cross-skill composition
**Severity**: HIGH
**Issue**: Tracing the supervisor-terminates-by-re-handoff → new-agent-picks-up → reflect-session workflow:

1. Principal runs /supervise, decides to re-handoff per [SUPER-010]. OK.
2. Principal invokes /handoff per [HANDOFF-009] (progressive update). OK.
3. Principal writes supervisor status in HANDOFF.md Constraints/### Supervisor ground rules per [HANDOFF-012] and [SUPER-011]. OK.
4. New session begins; agent reads HANDOFF.md per [HANDOFF-010] step 1-4. OK.
5. New agent hits [HANDOFF-010] step 5, inherits ground rules, treats them as binding, verifies as work proceeds. OK.
6. New agent completes work. At end of session, runs /reflect-session.
7. [REFL-009]'s Handoff Cleanup scans the HANDOFF.md and checks *"Ground-rules verified?"* per [SUPER-011] notation.
8. If the new agent did NOT write a fresh `#1–#N verified` line, the cleanup treats the block as unverified and leaves the file. **But the new agent was told in [HANDOFF-010] step 5 to "report verification status if a re-handoff is produced"**. What if no re-handoff is produced — the new agent simply finished?

The mechanism breaks here. The new agent's options on completion are:
- Re-handoff (rare if they finished): [SUPER-011] tells them what to do.
- Success: No requirement tells them to update the verification line in-place. [REFL-009] will see stale "pre-session" status.
- Escalation: No requirement covers this (per C.1).

**Why it matters**: The most common case (new agent successfully finishes inherited supervised work) has no requirement telling them to stamp verification on the way out. The handoff gets deleted by [REFL-009] only if all Next Steps complete AND all ground-rules entries verified. If the new agent never writes the verification, the file never gets deleted, and accumulates.
**Suggested fix**: Add a requirement (either [HANDOFF-010] step 6 or [SUPER-011] generalization) instructing the *new* agent, not just the principal on re-handoff, to update the verification status line before triggering /reflect-session or closing the session.

### E.2 — "Supervisor in absentia" concept is load-bearing but the mechanics don't quite work

**Skill / location**: `handoff/SKILL.md:311`
**Severity**: HIGH
**Issue**: [HANDOFF-012]'s rationale claims *"After the handing-off agent's session ends, no live supervisor exists. The block plays the supervisor role: the new agent self-verifies against it, and a future principal (or the user) MAY resume active supervision by reading the block as the current ground rules."* 

But /supervise's core mechanics presume live interaction:
- [SUPER-005] Question Classification has three classes, two of which ((a) answer from block, (c) escalate to user) work in absentia. Class (b) — *"Factual / technical question within the principal's authority"* — requires a live principal. In absentia, who answers class (b)?
- [SUPER-015] Progressive Refinement says *"the principal MUST append the decision to the ground-rules block as a new entry"*. In absentia, no one is appending. The block degrades from living into stale.
- [SUPER-013] Re-Injection on Drift requires quoting the rule "back to the subordinate, citing the entry number" — requires a live principal to notice drift.

The "plays the supervisor role" claim is aspirational. The block can function as a *passive constraint document* — a cold brief — but not as a supervisor, because supervision is defined by live interaction in the rest of /supervise.
**Why it matters**: This is a semantics mismatch at the heart of the composition. [HANDOFF-012] sells the block as a supervisor stand-in; /supervise's own [SUPER-001a] Composition row says *"Composition: A handoff MAY set up the conditions a supervisor then enforces"* — "enforces" implies a live enforcer. The handoff block is correctly described in /supervise's vocabulary as *"conditions the supervisor then enforces"*, not as *"the supervisor"*.
**Suggested fix**: Soften the rationale in [HANDOFF-012] line 311: *"The block plays the **ground-rules role** in the supervisor's absence: ... the new agent treats them as binding, but class (b) questions that would normally be answered by a live principal become class (c) (escalate to user) until a new principal adopts the block and resumes supervision."* Also add the degenerate-case treatment to /supervise as per finding B.5.

### E.3 — HANDOFF-012's "SHOULD NOT include the block — empty supervisor blocks are noise" vs REFL-009's "any ground-rules entry unverified" disposition

**Skill / location**: `handoff/SKILL.md:307`, `reflect-session/SKILL.md:309-312`
**Severity**: MEDIUM
**Issue**: [HANDOFF-012] says *"Routine sequential handoff with no constraints beyond the obvious | SHOULD NOT include the block — empty supervisor blocks are noise"*. [REFL-009]'s disposition:
- *"All items completed AND all ground-rules entries verified (or no ground-rules block present) | Delete the file"*
- *"Some items remain, OR any ground-rules entry unverified | Leave the updated file"*

The disposition correctly handles "no ground-rules block present" (deletes if other conditions met). But the middle case — a block with all entries verified — joins the "delete" branch. What if someone inserts an *empty* block (contrary to [HANDOFF-012]'s SHOULD NOT) just to placate the ritual? [REFL-009] will see zero unverified entries (because zero entries total) and delete the file. That's probably correct but the outcome of the two skills cooperating on an invalid input is undefined.
**Why it matters**: Minor. It's a "SHOULD NOT" not a "MUST NOT", so empty blocks can appear. Cleanup is reasonable (delete), but nothing surfaces the SHOULD-NOT violation.
**Suggested fix**: Amend [REFL-009] to note: *"If a `### Supervisor ground rules` sub-section is present but empty, report it as a [HANDOFF-012] SHOULD-NOT violation in the reflection entry before deleting."*

---

### F.1 — SUPER-007's "Intervention points" don't fully cover sub-agent case

**Skill / location**: `supervise/SKILL.md:177-184`, `supervise/SKILL.md:47-52`
**Severity**: LOW
**Issue**: [SUPER-001]'s Sub-agent caveat says *"Task-tool sub-agents return atomically — the principal cannot intervene mid-execution, only pre-dispatch (ground rules in the prompt) and post-return (review and re-dispatch). The boundary-triggered intervention model in [SUPER-007] assumes a serial new-session subordinate where each turn is a boundary; for sub-agents, boundaries collapse to 'before dispatch' and 'after return.'"*

[SUPER-007]'s "Intervention points" list (file write, question, phase completion, result report) does not adapt for sub-agents. The [SUPER-001] caveat acknowledges this but [SUPER-007] itself doesn't. Step 3 of [SUPER-016] (*"At each intervention point (per [SUPER-007]: file write, question, phase completion, result report)"*) fires regardless of subordinate type — but for sub-agents, "file write" and "question" are not intervention opportunities (sub-agent runs to completion).
**Why it matters**: A principal following [SUPER-016] step 3 for a sub-agent will imagine intervention points that don't exist. The caveat in [SUPER-001] isn't propagated. Small issue but the kind that compounds.
**Suggested fix**: Add a note to [SUPER-007] or [SUPER-016] step 3: *"For sub-agents per [SUPER-001]'s caveat, the intervention-point list collapses to 'before dispatch' (review prompt + ground rules) and 'after return' (review produced artifact). The other three points (file write, question mid-run, phase completion mid-run) are inaccessible."*

### F.2 — SUPER-014's "Mid-flight" row assumes HANDOFF.md already exists

**Skill / location**: `supervise/SKILL.md:317`
**Severity**: MEDIUM
**Issue**: [SUPER-014] Block Location table row 3: *"Mid-flight (principal enters supervisory mode for an already-running subordinate) | Append to the existing HANDOFF.md Constraints section, or write a topic-specific file (e.g., `HANDOFF-{topic}.md`) per [HANDOFF-005]"*.

The mid-flight case from [SUPER-001] is: *"Principal has already dispatched a subordinate and recognizes it now needs explicit oversight"*. This could be a sub-agent (no HANDOFF.md in play — the sub-agent ran from the Task tool prompt) OR a new-session subordinate (HANDOFF.md might exist from the original dispatch). [SUPER-014] row 3 *assumes* HANDOFF.md exists. But for a sub-agent mid-flight — which per [SUPER-001] caveat is impossible anyway, since sub-agents return atomically — there is a semantic weirdness.

Resolving this: for sub-agents, mid-flight is impossible. For new-session subordinates, mid-flight means the principal must inject the block on the next prompt turn and persist it to HANDOFF.md. [SUPER-014] row 3's "Append to the existing HANDOFF.md" works *only* if HANDOFF.md exists. If the new-session was started without one (e.g., via direct conversation), the principal must create it — not just "append."
**Why it matters**: The row oversimplifies. A new-session subordinate running without HANDOFF.md is a real case (the principal may have spoken directly to the subordinate).
**Suggested fix**: Amend [SUPER-014] row 3: *"Append to the existing HANDOFF.md Constraints section if one exists; otherwise, create HANDOFF.md or a topic-specific HANDOFF-{topic}.md per [HANDOFF-005] and embed the block."*

---

### G.1 — Missing: principal's session ends while subordinate keeps working

**Skill / location**: Not addressed in any of the four skills
**Severity**: HIGH
**Issue**: Consider the case: Principal dispatches a new-session subordinate with a supervisor block per [HANDOFF-012]. Principal's session then ends (context overflow, user closes tab). Subordinate keeps working in their new session (they have HANDOFF.md, they have the ground-rules block). At some point the subordinate hits a class (b) question per [SUPER-005] — *"factual / technical question within the principal's authority"*. The principal is gone. What does the subordinate do?

/supervise has no requirement for this. [SUPER-005] class (b) says *"Answer cooperatively, then append the decision to the ground-rules block as a new entry"*. But the subordinate isn't the principal — they can't "append decisions to the ground-rules block as new constraints on themselves." If the subordinate does this, they are self-authoring constraints and inheriting them, which is exactly the ad-hoc drift /supervise exists to prevent.

The parallel case is [HANDOFF-012]'s "supervisor in absentia" (finding B.5 and E.2), but that only explicitly covers constraint inheritance, not the class-(b) question problem. And /reflect-session only runs at session end, not mid-subordinate-run.
**Why it matters**: This is a realistic failure mode of the composition. The supervisor block cannot protect against it because /supervise's question-answering protocol assumes a live principal. A subordinate hitting class (b) with no principal has no defined behavior.
**Suggested fix**: Add a requirement to /supervise or /handoff defining subordinate behavior when no principal is available:
- Option A: class (b) → class (c) (escalate to user) per the absentia rule proposed in B.5.
- Option B: subordinate may answer class (b) themselves but MUST flag the question and their answer in HANDOFF.md Open Questions for later principal review.
- Option C: subordinate halts and waits.

Pick one and encode it explicitly.

### G.2 — Missing: cleanup of escalation artifact after the user resolves

**Skill / location**: `reflect-session/SKILL.md`, not addressed
**Severity**: MEDIUM
**Issue**: Per finding C.1, assume the gap is fixed and escalations produce a persistent artifact (HANDOFF.md Open Question or HANDOFF-escalation-*.md). The user resolves the escalation. What cleans up the artifact? [REFL-009]'s disposition table doesn't have an "Escalation resolved" row. The obvious answer — the next /reflect-session invocation cleans it up — is not written down anywhere.
**Why it matters**: Once C.1 is fixed, the artifact exists. Without an explicit cleanup rule, the file accumulates.
**Suggested fix**: If C.1 is accepted, amend [REFL-009] disposition table with a row: *"Escalation resolved (user answered) | Annotate the resolution in-place; if resolution also completes all Next Steps, delete per the standard rule."*

### G.3 — Missing: what if a reflection's action item updates supervise or handoff itself?

**Skill / location**: Self-reference loop
**Severity**: LOW
**Issue**: /reflect-session [REFL-003] allows `[skill] handoff` or `[skill] supervise` action items. /reflections-processing routes these per [REFL-PROC-005]. [SKILL-LIFE-002] requires provenance. No special treatment is defined for reflecting on the meta-skills that define the workflow. The recursive case (reflection on /reflect-session itself, or on /skill-lifecycle) is not ruled out.
**Why it matters**: Unbounded. Probably fine in practice, but a reflection that proposes changing /reflect-session while using /reflect-session creates an awkward composition. No rule against it; also no rule for it.
**Suggested fix**: Add a note in [REFL-003] or [SKILL-LIFE-002]: *"Action items updating the workflow skills themselves (/reflect-session, /skill-lifecycle, /handoff, /supervise) SHOULD be queued and applied outside the session that surfaced them, to avoid modifying the skill during the process that invokes it."* Low priority.

### G.4 — Missing: versioning or supersession notation for successive ground-rules blocks

**Skill / location**: [SUPER-015] Progressive Refinement, [HANDOFF-009] Progressive Capture
**Severity**: MEDIUM
**Issue**: [SUPER-015] says class (b) answers append to the block. [HANDOFF-009] says /handoff updates HANDOFF.md in place, appending new decisions. Over a long supervision phase, the ground-rules block grows entry by entry. [SUPER-002] caps it at 4–6 entries. What happens when appending would push it past 6? [SUPER-002] says *"Longer than 6 entries: compress, or split the work into sub-phases each with its own block."* But [SUPER-015] only says "append" — not "compress." The combined rule is: append, then when above 6, invoke [SUPER-002]'s compress-or-split. This isn't stated.

Relatedly, when a block is compressed, old entries are lost. There is no supersession notation (e.g., "#3 superseded by #7"). [SUPER-011]'s re-handoff format only reports verified vs blocked, not supersession. The history is lost.
**Why it matters**: Without supersession notation, a principal returning to a mid-phase HANDOFF.md cannot see what the constraints looked like earlier. Compression is destructive.
**Suggested fix**: Add a sub-requirement to [SUPER-015]: *"When appending would exceed the [SUPER-002] cap of 6 entries, the principal MUST either (a) compress — adding `(merges #N, #M)` notation to the new entry — or (b) split the phase per [SUPER-002]. Compression MUST NOT silently drop prior entries."*

---

## Patterns

Three recurring patterns emerged across these findings:

**Pattern 1 — Live-principal assumption bleeds through /supervise's requirements.** [SUPER-005], [SUPER-013], [SUPER-014], [SUPER-015], and [SUPER-016] all presume a live principal. The "supervisor in absentia" concept introduced in [HANDOFF-012] is real but /supervise doesn't accommodate it. Findings B.5, E.2, G.1 all instances. The fix across them is to add a single explicit requirement for the no-principal case — probably a new [SUPER-014a] — and propagate its implications to class (b) questions and drift re-injection.

**Pattern 2 — Terminology drift at composition boundaries.** "Supervisor ground rules" (heading) vs "supervisor ground-rules block" (prose) vs "ground-rules block" (prose) vs "Task boundaries" (field name) vs "task boundaries" (temporal concept in research). Findings B.1, B.2, B.3 all instances. The four skills were authored in sequence — /handoff first (2026-03-26), then updated today; /supervise created today; /reflect-session updated today. The canonicalization step — "pick one term and use it everywhere" — didn't fully run. This is the #1 refactor target.

**Pattern 3 — Procedural gaps show up at the edges: escalation, completion-without-re-handoff, and absentia.** [SUPER-010]'s three termination modes have different artifact commitments: Success is underspecified (does the subordinate write verification?), Re-handoff is specified via [SUPER-011], Escalation is unspecified on disk. Findings C.1, E.1, G.1, G.2 all instances. The happy path (re-handoff with status) is well-oiled; the other paths aren't.

## What's working well

- **Four-entry-type typing ([SUPER-002])** composes cleanly with [HANDOFF-004]'s template slot and [REFL-009]'s inspection check. The typed vocabulary (MUST / MUST NOT / `fact:` / `ask:`) propagates correctly across all three skills that need it.
- **Three-way termination ([SUPER-010])** is genuinely well-factored. The Success/Re-handoff/Escalation split mirrors what Semantic Kernel's ShouldTerminate+FilterResults does, cited correctly in the research doc, and reflected correctly in [SUPER-016]'s end-to-end procedure.
- **[SUPER-001a] Distinguishing Supervise from Handoff** is a strong piece of boundary definition — it prevents the skills from collapsing into each other while preserving the composition. The "Temporal shape" row (one moment vs a phase) is memorable.
- **Cross-skill cross-references with real IDs**: every `[SUPER-N]` cited in /handoff resolves (verified); every `[HANDOFF-N]` cited in /supervise resolves; every `[SUPER-N]` and `[HANDOFF-N]` cited in /reflect-session resolves. The cluster does not have broken ID citations in its current form.
- **Research-to-skill fidelity**: the 7-axis research maps to the shipped 17 IDs with only minor drift (finding B.3). The skill translation table in `agent-supervision-patterns.md:186-204` is a useful provenance artifact and appears accurate.
- **[REFL-009]'s conditional disposition table** correctly handles the additive case (handoffs without supervisor blocks behave as before, handoffs with blocks gain a verification gate). The `Provenance:` line citing the 2026-04-15 reflection is exemplary.
- **swift-institute-core index** correctly lists **supervise** with `[SUPER-*]` at line 69 and the CLAUDE.md Skill Routing table has the supervise row at line 95. Integration per [SKILL-CREATE-007] is properly executed.
