# Agent Supervision Patterns

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: RECOMMENDATION
---
-->

## Context

Claude Code sessions share no state across conversations except the file system, git, and the memory system. A *principal* agent directs work; a *subordinate* agent (a second Claude session, or a sub-agent invocation from the principal) does the work. The principal supervises by reading what the subordinate writes to disk and re-injecting guidance through prompts.

There is already a `/handoff` skill that covers a **discrete transfer moment** — the prior agent packages context into `HANDOFF.md`, the new agent reads it cold and resumes. That is a relay baton. It is not supervision.

Supervision is the thing that happens **between** handoffs. The principal remains engaged while the subordinate works: scope is articulated, questions are fielded, drift is caught, and the principal decides when the subordinate is done. The parent session of the `swift-io` Phase 3 handoff explicitly references this posture in `HANDOFF.md:55`: *"Supervisor constraints #1–#4: all verified end-to-end"* — implying a compressed, enumerated set of ground rules that governed the subordinate's execution and were verified by the principal before the handoff was written.

The `/supervise` skill formalizes that posture. This research document supplies the prior art and the axes the skill should encode.

**Trigger**: `/handoff` exists; `/supervise` does not. The parent agent invents ad-hoc ground-rule blocks. This is the moment to generalize.

**Constraints**:
- The principal and subordinate do not share memory. All supervision flows through files and prompts.
- The principal cannot *force* the subordinate — it can only inject text and re-read outputs.
- The subordinate may be running in parallel (Task tool sub-agents) or serially (new session picking up a handoff).
- Supervision differs from review: review is post-hoc; supervision is in-flight.

## Question

What is the optimal structure, content, and procedure for ongoing supervision of a subordinate agent's in-flight work?

## Analysis

### Prior Art

Six production systems converge on a recognizable pattern: a principal process decomposes the task, briefs the workers with structured context, monitors some form of progress ledger, and decides when to terminate or re-plan. Each system differs on *which* concerns are separated and *how* drift is caught.

1. **Anthropic orchestrator-worker pattern** (`Building Effective Agents`, Dec 2024). A central LLM *"dynamically breaks down tasks, delegates them to worker LLMs, and synthesizes their results."* The orchestrator's three functions are decompose, dispatch, synthesize — and Anthropic stresses that subtasks are *not* pre-defined; they are determined dynamically from the input. Supervision is implicit: the orchestrator owns the decomposition and can pause at checkpoints or when encountering blockers. Guardrails are recommended to be a *separate* concern (a second model screens inputs/outputs).

2. **Anthropic multi-agent research system** (`How we built our multi-agent research system`, Jun 2025). The Lead Researcher *"analyzes [the query], develops a strategy, and spawns subagents to explore different aspects simultaneously."* The critical finding: early attempts with vague instructions like "research the semiconductor shortage" caused subagents to duplicate work. The fix is the **subagent briefing contract** — each subagent MUST receive *"an objective, an output format, guidance on the tools and sources to use, and clear task boundaries."* The lead agent also applies *scaling rules* (simple fact-find = 1 agent, 3–10 tool calls; comparisons = 2–4 subagents, 10–15 calls each) and runs a **synthesis loop**: receive results → decide whether more research is needed → spawn more or exit.

3. **LangGraph supervisor agent**. A central supervisor node routes each turn to one specialist agent, waits for that agent to return, then decides whether to route to another specialist or terminate. LangChain's current guidance is to implement this via tool calls rather than a dedicated library, because tool-calling gives *"more control over context engineering."* Key property: the supervisor owns all flow control; specialists never address the user directly. Termination is a decision the supervisor makes each turn.

4. **CrewAI hierarchical process**. A manager agent (either explicit `manager_agent` or auto-generated from `manager_llm`) *"allocates tasks among crew members based on their roles and capabilities, evaluates tasks, assigns them to appropriate agents, and validates results before proceeding."* The manager is explicitly *not* in the workers list — it operates outside the pool. Delegation is disabled by default on workers (only the manager delegates), which prevents lateral free-for-all. Role/goal strings are the steering signal; the manager reads them to decide routing.

5. **Microsoft AutoGen GroupChatManager**. The manager selects the next speaker (round-robin, random, manual, or auto/LLM-driven) and terminates the chat. A community lesson: auto-selection costs an extra LLM call per turn just to pick who speaks, and a custom `select_speaker` function returning `None` is the clean termination signal. This is instructive: **selection and termination are the same function**; returning `None` means *no one should speak, we are done*.

6. **MetaGPT SOP-driven role hierarchy** (arXiv 2308.00352). Five roles — ProductManager, Architect, ProjectManager, Engineer, QA Engineer — each with *name, profile, goal, constraints*. Roles communicate through **structured documents** (PRDs, sequence diagrams, interface specs), not freeform chat, and publish/subscribe on a shared message pool rather than one-to-one. The supervisory mechanism is the SOP itself: each role's outputs are verified against a standard before the next role consumes them. Structure is the supervision.

7. **Microsoft Semantic Kernel agent group chat**. Selection strategy and termination strategy are **separate concerns**, each a method on `GroupChatManager`. The call order per round is: `ShouldRequestUserInput` → `ShouldTerminate` → `FilterResults` (only if terminating) → `SelectNextAgent` (only if not terminating). This sequence teaches that user-escalation, termination, result-filtering, and next-step routing are four orthogonal decisions a supervisor makes each turn. Collapsing them into one function conflates distinct policies.

8. **Microsoft Magentic-One** (Microsoft Research, Nov 2024). The Orchestrator maintains **two ledgers**: a *Task Ledger* (outer loop: facts, guesses, current plan) and a *Progress Ledger* (inner loop: current task progress and per-agent assignments). After each subtask, the Orchestrator updates the Progress Ledger and asks two questions: is the overall objective complete, and if not, is progress being made? If the stall counter exceeds a threshold, the Orchestrator returns to the outer loop, revises the Task Ledger, and re-plans. Drift detection is explicit, counter-based, and separate from the work itself.

9. **OpenAI Swarm handoffs** (Oct 2024, superseded by Agents SDK). Handoffs are implemented as tool calls that *return the next agent*. Stateless, lightweight. This is instructive as the *minimal* form of agent transition — but it does not supervise; it delegates and walks away. Swarm's guidance document notes this is not production-ready precisely because there is no supervisory wrapper.

### Synthesis: Axes of Supervision

Distilling the prior art, supervision decomposes into **seven orthogonal axes**. Conflating them is the dominant failure mode (AutoGen's auto-selection cost, MetaGPT's pre-SOP ad-hoc prompts, CrewAI's "delegation enabled by default" footgun).

#### Axis 1 — Scope-Setting

How the principal articulates what the subordinate is expected to do and **not** do. Anthropic's multi-agent system names the four mandatory fields: objective, output format, tool/source guidance, and task boundaries. Vague scopes produce duplicated work and scope creep. The principal MUST produce a compressed scope block before the subordinate starts — not paragraphs, enumerated constraints. The parent session of `HANDOFF.md` for swift-sockets Phase 3 implies exactly this: *"Supervisor constraints #1–#4"* — four numbered constraints, each small enough to verify end-to-end. Examples from Magentic-One's Task Ledger: "facts, guesses, current plan." Scope is not the task; scope is what bounds the task.

#### Axis 2 — Strictness Policy

Which elements of scope are non-negotiable, which are defaults the subordinate may overturn with justification, and which are open questions for the subordinate to answer. CrewAI encodes this via the role's `constraints` field; MetaGPT encodes it in the SOP; Magentic-One encodes it in the Task Ledger's distinction between "facts" (fixed) and "guesses" (revisable). Without a declared strictness policy, the subordinate either treats every suggestion as a hard rule (producing paralysis) or treats every rule as a suggestion (producing drift). The principal MUST mark each scope element as MUST / SHOULD / MAY, or equivalent.

#### Axis 3 — Question-Answering Protocol

The principal's posture when the subordinate asks a question. LangGraph and Semantic Kernel both teach that routing is a separate decision from producing a message — the supervisor answers only when the question is inside the declared scope; questions outside scope are either re-scoped (expand the mandate) or escalated to the user. Anthropic's multi-agent paper implies this via the "clear task boundaries" requirement: if a subagent asks something outside its boundary, the lead agent's job is to say *"not in scope — here is the boundary"*, not to answer. The principal MUST NOT answer questions it is not itself authorized to answer; see Axis 7 (Escalation).

#### Axis 4 — Drift Detection

The signals that indicate the subordinate is going off-mark **before** it produces a final output. Magentic-One is the clearest prior art: the Progress Ledger asks after every subtask *"is progress being made?"*, and a stall-count threshold triggers re-planning. Applied to Claude Code supervision: the principal watches for specific signals in the subordinate's turn-by-turn output — repeating itself, re-exploring closed alternatives, expanding scope, asking questions whose answers are in the ground-rules block, proposing changes to files the scope marked out of bounds. The principal MUST enumerate these signals up front (in the ground-rules block itself, "stop and ask if X") and check each subordinate turn against them.

#### Axis 5 — Intervention

When and how the principal corrects mid-task. Three prior-art patterns: (a) LangGraph / Semantic Kernel — the supervisor owns every turn transition, so correction is just the next routing decision; (b) Magentic-One — the Orchestrator re-plans only when the stall threshold trips, letting micro-drift pass; (c) CrewAI — the manager validates results before dispatching the next task, so correction is batched at task boundaries. For Claude Code, intervention should be **boundary-triggered, not continuous**: when the subordinate writes a file, asks a question, or finishes a step, the principal reviews; between those boundaries the principal does not interrupt. The principal MUST correct at *intervention points* and MUST NOT rewrite the subordinate's output (see Rejected Approaches). *(Terminology note: this draft used "task boundaries" for the temporal concept; the shipped skill `[SUPER-007]` reserves "Task boundaries" for the scope field per `[SUPER-003]` and uses "intervention points" for the temporal concept. Updated 2026-04-15 post-audit.)*

#### Axis 6 — Termination

When supervision ends. Semantic Kernel separates termination from selection — `ShouldTerminate` is a distinct function called before `SelectNextAgent`. AutoGen's lesson that `None` is the natural "we are done" signal generalizes: termination is a decision the principal makes *every turn*, not just at the end. Three exit conditions recur: **success** (all scope elements satisfied and verified), **re-handoff** (session quality degrades — feed the subordinate's outputs into `/handoff` and end supervision), **escalation** (a scope question only the user can answer). The principal MUST declare up front what "done" looks like (acceptance criteria) and MUST check each turn against them.

#### Axis 7 — Escalation to User

When the principal must surface a question to the user rather than answer it itself. MetaGPT's SOP makes this implicit (role constraints declare what a role may decide); CrewAI and LangGraph leave it to the supervisor's judgment. For Claude Code specifically: the principal is itself a delegate of the user. If a subordinate question would require the principal to change the user's stated goal, relax a user-declared constraint, or commit resources outside the agreed task, the principal MUST escalate to the user rather than answer from first principles. Escalation is not failure; it is a type-safe disclaimer that the principal did not exceed its authority.

### The Handoff/Supervise Boundary

These two skills solve different problems and compose cleanly. The existing `/handoff` skill (see `/Users/coen/Developer/swift-institute/Skills/handoff/SKILL.md` and `/Users/coen/Developer/swift-institute/Research/agent-handoff-patterns.md`) is built on the *handoff paradox*: the agent writing the handoff is the one whose quality has degraded. Its mitigations — progressive capture, tool-assisted population, fixed-field templates, user review — all address that discrete transfer moment.

| | Handoff | Supervise |
|---|---|---|
| Temporal shape | Discrete transfer (one moment) | Continuous oversight (a phase) |
| Author | The departing agent | The principal (still running) |
| Reader | The new agent (cold start) | The principal itself, reviewing subordinate output |
| Artifact | `HANDOFF.md` — self-contained cold-start brief | Ground-rules block — re-injected into subordinate prompts |
| Paradox addressed | Departing agent's degraded recall | Subordinate's lack of shared context |
| Verification | New agent verifies before starting | Principal verifies at each task boundary |

**They compose.** A handoff can set up the conditions a supervisor then enforces, and a supervisor can produce a handoff when degradation hits. The parent session of the swift-sockets Phase 3 handoff did exactly this: while supervising the subordinate, the principal declared four constraints (scope-setting + strictness policy from Axes 1–2), verified them end-to-end (drift detection + intervention from Axes 4–5), and then on completion produced the handoff that cites *"Supervisor constraints #1–#4: all verified end-to-end"* (line 55). The `/supervise` skill governs the phase where those constraints are active; `/handoff` governs the handoff artifact that cites the result.

The clean boundary: `/handoff` writes a file; `/supervise` governs a posture. Different artifacts, different lifetimes, different failure modes.

### Lived Example

The parent session of `/Users/coen/Developer/swift-foundations/swift-io/HANDOFF.md` was in supervisory mode for the whole of Phase 2 of the swift-sockets consumption of swift-io. The handoff's line 55 — *"Supervisor constraints #1–#4: all verified end-to-end"* — is the supervisor's post-hoc attestation.

Reverse-engineering from the Key Decisions (lines 58–79) and Constraints (lines 150–166) sections, the four supervisor constraints were almost certainly:

1. **No shadow types to bridge ownership.** Per memory `feedback_language_features_over_custom_types`. Encoded in both Key Decision #1 (*"Don't add Kernel.Socket.Descriptor.kernelDescriptor borrowing view as a cross-type bridge"*) and Constraints (*"borrowing/consuming/~Copyable, never shadow types or accessor views to bridge ownership"*). This is a **MUST NOT** rule — the principal marks an architectural boundary the subordinate may not cross. Even when a research document (`io-architecture.md` v1.2 §4.A.0) suggested the shadow type, the supervisor's constraint superseded the research. That is strictness policy (Axis 2) in action.

2. **Toolchain pinned to Swift 6.3 stable for the Linux gate, not nightly.** Encoded in Key Decision #2 and Constraints. The subordinate is forbidden from switching toolchains. This is a **MUST** rule with a stated reason (nightly fails on `Optional.take()` region-isolation), which is strictness policy done properly: the reason lets the subordinate know when the rule could stop applying.

3. **`IO.completions` is Linux-only by design.** Explicit platform guard: Phase 3A's parameterized test *"must `#if os(Linux)` the completions cell"*. Scope-setting (Axis 1): an architectural fact that bounds what the subordinate can implement.

4. **Non-owning view contract: stable address for duration of `try await` (NOT "heap-backed")**. Encoded in Constraints. A memory-safety invariant that the subordinate must preserve. Drift detection signal: any change that violates the `Memory.Buffer` contract is an immediate halt.

Plus a likely fifth standing instruction embedded in the Next Steps structure: **stop for review at each sub-phase gate** (*"Stop for review before 3B"*, line 132). This is intervention policy (Axis 5): task-boundary-triggered, not continuous.

The pattern is recognizable. The block is:

- **Small** — 4 numbered constraints plus one process rule; fits in a single compressed block.
- **Enumerable** — the supervisor can say "#1–#4 verified" and the subordinate can check each.
- **Typed** — each constraint is either a MUST, MUST NOT, or scope fact.
- **Cited** — each constraint traces to a concrete rationale (memory entry, platform fact, performance invariant).
- **Re-injectable** — the subordinate reads it at start, and the principal re-injects it if drift is detected.

This is what the `/supervise` skill should generalize. The principal, before work starts, emits a "supervisor ground rules" block with four to six entries. Each entry is one of:

- A **MUST** with rationale (required behavior).
- A **MUST NOT** with rationale (forbidden approach, especially when a plausible-looking document or pattern suggests otherwise).
- A **scope fact** (architectural boundary, platform guard, API contract).
- A **stop-and-ask rule** (specific conditions under which the subordinate must escalate instead of deciding).

The block is stored at the top of the subordinate's working file (HANDOFF.md, investigation file, or injected as a prompt prefix) and re-referenced at each task boundary.

### Rejected Approaches

- **"Always escalate to user"** — defeats supervision. The user delegated to the principal precisely so routine decisions do not require user intervention. Escalation is for questions outside the principal's authority (Axis 7), not for every question.

- **"Never intervene mid-task"** — supervision becomes inert. The principal's job is to catch drift before it compounds. The Magentic-One lesson is that intervention must be *boundary-triggered* (at task completion, on file writes, on questions), not continuous, but not zero either.

- **"Supervisor rewrites subordinate output"** — that is takeover, not supervision. It destroys the subordinate's ability to learn from correction and creates two half-authored artifacts instead of one. The principal may **reject** output and require the subordinate to redo it with corrected guidance, but must not silently edit.

- **"Supervisor runs in parallel and polls"** — Claude Code does not have true concurrent state across sessions. A "supervisor" that runs in parallel to a subordinate and polls would require an out-of-band channel (file watcher, process monitor) the skill cannot assume. Supervision in Claude Code is turn-boundary synchronous: the subordinate writes something, the principal reads and responds.

- **"One SKILL per axis"** — tempting, given Semantic Kernel's clean separation. Rejected because for Claude Code the principal **is** the strategy — there is no framework to which axes are plugged in. Axes are the skill's internal structure, not separate skills.

- **"Auto-generate the ground-rules block from the task description"** — plausible but it produces the same failure mode Anthropic reported with early multi-agent ("research the semiconductor shortage"). The ground rules must be explicitly authored; the skill's job is to enforce structure, not to synthesize content.

- **"Supervision ends when subordinate says 'done'"** — subordinate attestation is not acceptance. The principal MUST verify against declared acceptance criteria before terminating supervision. This is the ATC read-back pattern from the handoff research applied to the supervisory relationship.

## Outcome

**Status**: RECOMMENDATION

The `/supervise` skill should encode seven orthogonal axes, producing a compressed ground-rules block up front and a verify-at-boundaries runtime posture throughout.

### Recommended Supervision Pattern

**Axis 1 — Scope-Setting**. The principal MUST produce a ground-rules block before the subordinate begins work. The block MUST contain four mandatory fields per subordinate task: objective, output format, tools/sources, and task boundaries. The block SHOULD be 4–6 enumerated entries total; longer blocks SHOULD be compressed or split.

**Axis 2 — Strictness Policy**. Each entry in the ground-rules block MUST be typed as MUST, MUST NOT, SHOULD, or scope fact. MUST NOT entries MUST include the rationale (compiler bug, architectural principle, memory reference), because a MUST NOT with no rationale will be broken the moment a plausible-looking document suggests otherwise.

**Axis 3 — Question-Answering Protocol**. When the subordinate asks a question, the principal MUST classify it as (a) answerable from the ground-rules block (quote the rule and cite), (b) answerable from the principal's own scope (answer, then append the decision to the ground-rules block), or (c) outside the principal's authority (escalate per Axis 7). The principal MUST NOT answer questions of type (c) from first principles.

**Axis 4 — Drift Detection**. The principal MUST enumerate drift signals up front. Default signals include: subordinate repeats itself across turns, subordinate re-proposes a rejected alternative, subordinate expands scope, subordinate asks a question whose answer is in the ground-rules block, subordinate modifies files outside the declared scope. The principal SHOULD check each subordinate turn against the signal list before accepting it.

**Axis 5 — Intervention**. The principal MUST intervene only at task boundaries (file writes, question-asks, phase completion). The principal MUST NOT continuously interrupt; this defeats the subordinate's autonomy. The principal MUST NOT rewrite subordinate output; it may reject and require a redo with corrected guidance.

**Axis 6 — Termination**. The principal MUST declare acceptance criteria up front. Supervision ends when (a) all criteria verified end-to-end (success), (b) subordinate quality degrades (re-handoff via `/handoff`), or (c) a scope question only the user can answer arises (escalation per Axis 7). The principal MUST verify criteria before terminating; subordinate attestation alone is not sufficient.

**Axis 7 — Escalation to User**. The principal MUST escalate to the user, rather than answer, when a question would require changing the user's stated goal, relaxing a user-declared constraint, or committing resources outside the agreed task. Escalation is correct behavior, not failure.

**Cross-cutting — Re-injection**. The ground-rules block MUST be re-injected when drift is detected. The principal SHOULD cite the specific rule being violated by quoting it back to the subordinate.

**Cross-cutting — Composition with `/handoff`**. When supervision terminates via re-handoff, the principal MUST produce a `HANDOFF.md` whose Constraints section cites the ground-rules block's verified and unverified entries, per the swift-io lived example (line 55: *"Supervisor constraints #1–#4: all verified end-to-end"*).

### Skill Translation

The skill as shipped at `/Users/coen/Developer/swift-institute/Skills/supervise/SKILL.md` is the canonical numbering. The table below reflects the shipped IDs (this section was updated post-authoring to match):

| ID | Title | Anchor |
|---|---|---|
| [SUPER-001] | Invocation | Pre-dispatch and mid-flight triggers; sub-agent atomicity caveat |
| [SUPER-001a] | Distinguishing Supervise from Handoff | Side-by-side table; composition pointer to [SUPER-011] |
| [SUPER-002] | Block Structure | 4–6 enumerated entries, four entry types (MUST, MUST NOT, fact:, ask:) |
| [SUPER-003] | Mandatory Fields | Four fields per dispatched task (objective, output format, tools/sources, Task boundaries) |
| [SUPER-004] | Rationale on Forbidden Entries | Every MUST NOT MUST carry a (why: …) sub-field |
| [SUPER-005] | Question Classification | Three-way classification (in ground rules / in principal's scope / escalate) |
| [SUPER-006] | Drift Signal Enumeration | Default seven-signal list; principal MAY add task-specific signals |
| [SUPER-007] | Boundary-Triggered Intervention | Intervene only at *intervention points* (file write, question, phase completion, result report) — distinct from [SUPER-003]'s Task boundaries field |
| [SUPER-008] | No Takeover | Principal MAY reject and require redo; MUST NOT silently rewrite |
| [SUPER-009] | Acceptance Criteria | Declared up front; testable from disk/git/build, not from subordinate attestation |
| [SUPER-010] | Three-Way Termination | Success / re-handoff / escalation; no termination by attrition |
| [SUPER-011] | Re-Handoff Composition | On re-handoff, `HANDOFF.md` Constraints MUST cite ground-rules verification status |
| [SUPER-012] | Escalation Triggers | Goal change, constraint relaxation, resource commitment, unanticipated user constraint |
| [SUPER-013] | Re-Injection on Drift | Quote the violated entry back to the subordinate, citing entry number |
| [SUPER-014] | Block Location | Sub-agent (in prompt) / new-session (HANDOFF.md) / mid-flight (HANDOFF.md or HANDOFF-{topic}.md) |
| [SUPER-015] | Progressive Refinement | Class-(b) answers MUST be appended to the block as new typed entries |
| [SUPER-016] | End-to-End Procedure | Author dispatch → dispatch or attach → review at intervention points → terminate |

Section ordering within the skill mirrors the axis sequence: Scope → Strictness → Q/A → Drift → Intervention → Termination → Escalation. This matches the temporal order in which the supervisor makes decisions each turn (Semantic Kernel's lesson). The shipped skill adds [SUPER-001a] (handoff/supervise distinction) as a pre-flight reference, and [SUPER-016] (end-to-end procedure) as the bottom-line aggregator.

## References

- [Building Effective Agents — Anthropic Engineering](https://www.anthropic.com/engineering/building-effective-agents)
- [How we built our multi-agent research system — Anthropic Engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- [langgraph-supervisor — LangChain Python reference](https://reference.langchain.com/python/langgraph/supervisor/)
- [Build a personal assistant with subagents — LangChain docs](https://docs.langchain.com/oss/python/langchain/multi-agent/subagents-personal-assistant)
- [Hierarchical Process — CrewAI docs](https://docs.crewai.com/en/learn/hierarchical-process)
- [Implementing the Hierarchical Process in CrewAI — CrewAI docs](https://docs.crewai.com/how-to/Hierarchical/)
- [Group Chat — AutoGen docs (stable)](https://microsoft.github.io/autogen/stable//user-guide/core-user-guide/design-patterns/group-chat.html)
- [Conversation Patterns — AutoGen 0.2](https://microsoft.github.io/autogen/0.2/docs/tutorial/conversation-patterns/)
- [Customize Speaker Selection — AutoGen 0.2](https://microsoft.github.io/autogen/0.2/docs/topics/groupchat/customized_speaker_selection/)
- [MetaGPT: Meta Programming for A Multi-Agent Collaborative Framework — arXiv 2308.00352](https://arxiv.org/abs/2308.00352)
- [MetaGPT (HTML v7) — arXiv](https://arxiv.org/html/2308.00352v7)
- [Group Chat Agent Orchestration — Microsoft Learn (Semantic Kernel)](https://learn.microsoft.com/en-us/semantic-kernel/frameworks/agent/agent-orchestration/group-chat)
- [Exploring Agent Collaboration in Agent Chat (archive) — Microsoft Learn](https://learn.microsoft.com/en-us/semantic-kernel/support/archive/agent-chat)
- [Magentic-One: A Generalist Multi-Agent System for Solving Complex Tasks — Microsoft Research (Nov 2024, PDF)](https://www.microsoft.com/en-us/research/wp-content/uploads/2024/11/Magentic-One.pdf)
- [Magentic-One: A Generalist Multi-Agent System for Solving Complex Tasks — Microsoft Research article](https://www.microsoft.com/en-us/research/articles/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/)
- [Magentic Agent Orchestration — Microsoft Learn (Semantic Kernel)](https://learn.microsoft.com/en-us/semantic-kernel/frameworks/agent/agent-orchestration/magentic)
- [OpenAI Swarm — GitHub](https://github.com/openai/swarm)
- [Orchestrating Agents: Routines and Handoffs — OpenAI Cookbook](https://developers.openai.com/cookbook/examples/orchestrating_agents)
- Internal: `/Users/coen/Developer/swift-institute/Skills/handoff/SKILL.md`
- Internal: `/Users/coen/Developer/swift-institute/Research/agent-handoff-patterns.md`
- Internal: `/Users/coen/Developer/swift-foundations/swift-io/HANDOFF.md` (parent session lived example)
