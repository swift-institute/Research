# Agent Handoff Patterns

<!--
---
version: 1.1.0
last_updated: 2026-03-25
status: RECOMMENDATION
---
-->

## Context

Two distinct handoff scenarios arise in Claude Code:

1. **Sequential handoff**: Context fills up, quality degrades, work must continue in a new session. The current practice — asking the degraded agent to "write comprehensive handoff instructions inline in chat" — has systematic failure modes.
2. **Branching handoff**: During work on task X, an orthogonal issue Y surfaces. The user wants the current conversation to continue on X, while a new conversation investigates Y. The new conversation needs a focused brief, not a full task handoff.

This research investigates better patterns for both scenarios and recommends a design for a `/handoff` skill.

**Trigger**: Recurring quality loss during long sessions; ad-hoc handoff instructions that vary in completeness; no mechanism for spinning off focused investigations from a running conversation.

**Constraints**:
- Claude Code conversations share no state except the file system, git, and the memory system
- The user bridges conversations — they start the new session and frame the task
- The new agent can read any file but has no access to the prior conversation
- CLAUDE.md is auto-loaded; arbitrary files are not

## Question

What is the optimal structure, timing, location, and content for agent-to-agent handoff in Claude Code?

## Analysis

### The Handoff Paradox

The fundamental problem: **the agent writing the handoff is the one whose quality has degraded**. If it had perfect recall and reasoning, handoff would be unnecessary. This means the most critical document in the workflow is authored by the worst-performing version of the agent.

This paradox has four mitigations, each supported by prior art:

| Mitigation | Mechanism | Prior Art |
|------------|-----------|-----------|
| Progressive capture | Write while sharp, update incrementally | NASA MER shift reports |
| Tool-assisted population | Use `git diff`, file reads, task state — don't rely on agent memory | Industrial plant walkthrough |
| Fixed-field templates | Structure prevents omission; mandatory fields force completeness | Medical SBAR |
| User review | Human corrects before new session starts | ATC read-back confirmation |

### Option A: Inline Chat (Current Practice)

The user asks: "write a comprehensive handoff instruction for a new agent."

| Criterion | Assessment |
|-----------|------------|
| Persistence | None — lost when conversation ends unless copy-pasted |
| Structure | Varies wildly — no template, no mandatory fields |
| Author quality | Degraded agent, maximum recency bias |
| Context cost | Handoff text competes for remaining context space |
| User effort | Must copy-paste, reformat, verify manually |
| Completeness | Unpredictable — "comprehensive" is subjective |

**Verdict**: Unreliable. Every failure mode compounds.

### Option B: File-Based Handoff Document (Static)

Agent writes a structured handoff file to disk at session end.

| Criterion | Assessment |
|-----------|------------|
| Persistence | Strong — survives conversation end |
| Structure | Template-enforced if skill-driven |
| Author quality | Still degraded, but template + tools compensate |
| Context cost | Zero — written to disk, not to conversation |
| User effort | Low — point new agent to file |
| Completeness | Template ensures mandatory sections |

**Verdict**: Significant improvement over Option A. But still suffers from degraded-author problem.

### Option C: Progressive Capture with Final Handoff

Agent writes/updates a handoff file throughout the session, not just at the end. Each checkpoint is written while quality is still high. The final handoff refines what's already captured.

| Criterion | Assessment |
|-----------|------------|
| Persistence | Strong |
| Structure | Template-enforced, incrementally refined |
| Author quality | Checkpoints written at peak quality; final pass fills gaps |
| Context cost | Minimal — each update is a file write |
| User effort | Low — checkpoints happen as part of workflow |
| Completeness | Best — captures decisions at the moment they're made |

**Verdict**: Strongest option. Solves the handoff paradox.

### Option D: Memory-Based Handoff

Agent saves key context to the Claude Code memory system.

| Criterion | Assessment |
|-----------|------------|
| Persistence | Permanent — auto-loaded in all future conversations |
| Structure | Memory system has its own structure |
| Author quality | Same as other options |
| Context cost | Memory always loaded — adds to every future session |
| User effort | Zero — automatic |
| Completeness | Memory is designed for durable knowledge, not task context |

**Verdict**: Wrong tool. Memory is for persistent cross-conversation knowledge (who the user is, what conventions to follow). Task-specific handoff context is ephemeral — it should be consumed and discarded, not permanently loaded.

### Comparison

| Criterion | A: Inline | B: File | C: Progressive | D: Memory |
|-----------|-----------|---------|----------------|-----------|
| Survives session end | No | Yes | Yes | Yes |
| Written while sharp | No | No | **Yes** | No |
| Structured template | No | Yes | Yes | Partial |
| Auto-populatable | No | Yes | Yes | No |
| Zero context cost | No | Yes | Yes | No (always loaded) |
| Ephemeral (consumed and discarded) | Yes | Yes | Yes | **No** |
| User effort to use | High | Low | Low | Zero |

**Recommendation**: Option C (progressive capture with final handoff), falling back to Option B when progressive capture wasn't used.

### Handoff Document Structure

Drawing from SBAR (medical), industrial shift handoff (anomalies-first), and the "lost in the middle" research (critical info at edges), the recommended structure is:

```markdown
# Handoff: {Brief Task Description}

> Resume prompt: Read this file, verify the current state, then continue
> with the next steps. Ask if anything is unclear before proceeding.

## Goal
{What we're trying to achieve — the user's original intent}

## Current State
{What has been accomplished}
{Build/test status: compiles? tests pass? partial implementation?}

## Key Decisions
{Decisions made with rationale — most important first}
{Rejected alternatives and why — prevents the new agent from retreading}

## Dead Ends
{Approaches tried that failed — with failure reason}

## Changed Files
{Auto-populated from git diff — file path + one-line description}

## Open Questions
{Unresolved issues requiring user input}

## Next Steps
{Prioritized list of what to do next}

## Constraints
{Non-obvious limitations discovered during work}
```

**Design rationale for section ordering**:
1. **Goal** first — establishes context immediately (SBAR "Situation")
2. **Current State** second — the new agent needs to know where things stand (SBAR "Assessment")
3. **Key Decisions** and **Dead Ends** — the most frequently lost information; prevents rework (SBAR "Background")
4. **Changed Files** — auto-populated, provides concrete anchors
5. **Next Steps** last — the action items, at the end where attention is highest per "lost in the middle" research (SBAR "Recommendation")

### File Location

| Option | Pros | Cons |
|--------|------|------|
| `HANDOFF.md` at project root | Discoverable, simple | Clutters root, needs .gitignore |
| `.claude/handoff.md` | Hidden, .claude/ often gitignored | Less discoverable |
| Temp file | Zero cleanup | Lost on reboot, harder to reference |

**Recommendation**: `HANDOFF.md` at working directory root. Reasons:
- Maximum discoverability for the new agent
- The user can glance at it in their editor
- Can be `.gitignore`d if desired (the skill can offer to add the entry)
- Convention: uppercase signals "read me first"

### Token Budget

From the prior art on context degradation:
- Performance degrades measurably at 16K-32K tokens
- Irrelevant context actively hurts (can push accuracy below zero-context baseline)
- "Context curation > context volume" — less is more

**Target**: 500-1500 tokens (~400-1200 words). Maximum: 2000 tokens.

The handoff document replaces tens of thousands of tokens of conversation context. It must be a 10-50x compression, not a dump. This aligns with Continuous Claude's finding that handoff YAML is ~1/20th of raw context.

If detail is needed for specific areas, the handoff should reference files to read on demand rather than inlining content.

### Timing and Triggers

**Proactive triggers** (before degradation):
- After completing a major milestone (natural checkpoint)
- When starting a new phase of work
- At user request (`/handoff`)

**Reactive triggers** (degradation detected):
- Agent starts repeating itself or forgetting earlier decisions
- Agent makes errors on already-discussed topics
- User notices quality drop

**Key insight from prior art**: The community recommends compacting at 60% context utilization, not 90%. The same principle applies to handoff — capture state while quality is still high, not as an emergency measure.

### Handoff Lifecycle

```
1. /handoff          — Create or update HANDOFF.md (checkpoint)
2. [continue work]   — Normal development
3. /handoff          — Update with new progress (another checkpoint)
4. [quality drops]   — User decides to hand off
5. /handoff          — Final update (may be lower quality, but prior checkpoints captured the important context)
6. [new session]     — User starts fresh, points agent to HANDOFF.md
7. [agent reads]     — New agent reads, verifies state, continues
8. [cleanup]         — Delete or archive HANDOFF.md
```

### Acceptance by the New Agent

Following the ATC pattern of explicit acceptance, the new agent should:

1. Read `HANDOFF.md`
2. Verify claims: Do the listed files exist? Does the code compile? Do mentioned decisions show in git history?
3. Confirm to the user: "I've read the handoff. Here's my understanding of the current state and next steps. Shall I proceed?"
4. Only then begin work

This prevents the new agent from proceeding with stale or incorrect context.

### Branching Handoff (Fork Pattern)

The second use case is fundamentally different from sequential handoff. The current conversation continues — the handoff is a **fork**, not a relay.

**Scenario**: Working on task X. Agent mentions "by the way, the Sendable conformances here look wrong." User wants to investigate that in a separate session without derailing the current work.

**Key differences from sequential handoff**:

| Aspect | Sequential | Branching |
|--------|------------|-----------|
| Original conversation | Ends | Continues |
| Scope | Full task | Single issue |
| Handoff author quality | Degraded | Still sharp (issue just surfaced) |
| Conflict risk | None (only one session) | High (two sessions touch same codebase) |
| Document lifetime | Until task completes | Until investigation concludes |
| Token budget | 500–1500 | 200–500 (focused brief) |

**Branch handoff template**:

```markdown
# Investigation: {Issue Description}

> Resume prompt: Read this file for context on what to investigate.
> The parent conversation is continuing separate work — avoid modifying
> files listed under "Do Not Touch" unless critical.

## Issue
{What was observed, where, why it matters}

## Context
{What the parent conversation is working on}
{How this issue was discovered}

## Relevant Files
{Files related to the issue — with line numbers if possible}

## Do Not Touch
{Files the parent conversation is actively modifying — avoid conflicts}

## Scope
{What to investigate, and explicit boundaries on what NOT to change}

## Findings Destination
{Where to write results — e.g., a specific file, or inline in the handoff}
```

**Design rationale**:
- **Issue first** — the new agent needs to understand what to investigate immediately
- **Do Not Touch** — critical for avoiding conflicts; the parent conversation is still active
- **Scope** — prevents the investigation from expanding into the parent task's territory
- **Findings Destination** — tells the investigation agent where to put results so the parent conversation (or a subsequent session) can pick them up

**File naming**: `HANDOFF-{topic}.md` (e.g., `HANDOFF-sendable-conformance.md`). Multiple branch handoffs can coexist, while `HANDOFF.md` (no suffix) is reserved for sequential handoff.

**Lifecycle**:

```
1. [in conversation A] /handoff investigate {topic}  — Creates HANDOFF-{topic}.md
2. [conversation A continues normally]
3. [new conversation B] User points agent to HANDOFF-{topic}.md
4. [conversation B investigates, writes findings]
5. [conversation A or C] Reads findings, integrates into main work
6. [cleanup] Delete HANDOFF-{topic}.md
```

### What the Skill Should NOT Do

- **Not use memory** for task-specific context — memory is for durable knowledge
- **Not produce multi-thousand-token documents** — defeats the purpose
- **Not try to capture the full conversation** — compress, don't replay
- **Not require the user to restructure their workflow** — `/handoff` should be a single command

## Outcome

**Status**: RECOMMENDATION

### Primary Recommendation

Create a `/handoff` skill with two modes:

**Mode 1 — Sequential handoff** (`/handoff`):

1. **Writes `HANDOFF.md`** to the working directory root using the SBAR-derived template
2. **Auto-populates** the Changed Files section from `git diff` and `git status`
3. **Asks the agent to fill** Goal, Current State, Key Decisions, Dead Ends, Open Questions, Next Steps, and Constraints
4. **Enforces the token budget** (500–1500 tokens) — the skill instructions should emphasize conciseness
5. **Is idempotent** — invoking `/handoff` multiple times updates the same file (progressive capture)
6. **Includes a resume prompt** at the top of the document for the new agent

**Mode 2 — Branching handoff** (`/handoff investigate {topic}`):

1. **Writes `HANDOFF-{topic}.md`** using the branch template (Issue, Context, Relevant Files, Do Not Touch, Scope, Findings Destination)
2. **Auto-populates** Do Not Touch from files with uncommitted changes in git
3. **Enforces a tighter token budget** (200–500 tokens) — this is a focused brief, not a full handoff
4. **Multiple branch handoffs can coexist** — each gets its own file
5. **Does not disturb `HANDOFF.md`** — the two modes are independent

### Secondary Recommendations

- The skill should remind the user to invoke `/handoff` after major milestones, not just at session end
- The new agent's first action should be to verify the handoff document's claims before proceeding
- Consider a `.gitignore` entry for `HANDOFF*.md` (offer, don't force)
- Archive previous handoffs to `.claude/handoff-archive/` before overwriting (optional)
- Branch handoff findings should be written to a predictable location so the parent conversation or a subsequent session can find them

### Out of Scope

- Automatic handoff triggering (would require hook infrastructure beyond the skill)
- Multi-agent orchestration (this is sequential handoff and focused branching, not parallel coordination)
- Cross-repo handoff coordination (each repo gets its own HANDOFF.md)
- Merging branch investigation results back into the parent conversation (manual for now)

## References

- Liu et al., "Lost in the Middle: How Language Models Use Long Contexts" (TACL 2023/2024)
- SBAR structured communication protocol (Joint Commission, healthcare)
- ATC handover-takeover procedure (ICAO Doc 4444)
- NASA MER surface operations shift handover protocol
- OpenAI Swarm/Agents SDK handoff primitives (2024-2025)
- Anthropic Claude Code best practices — context management (2025-2026)
- GitHub issue anthropics/claude-code#11455 — session continuity feature request
- Continuous Claude v3 — community session continuity implementation
- "Context Length Alone Hurts" (October 2025)
- RULER benchmark, NVIDIA (April 2024)
