# Agent Harness Engineering: State of the Art

<!--
---
version: 1.0.0
last_updated: 2026-05-10
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

This research surveys the state of the art in **agent harness engineering** —
the design discipline of the scaffolding wrapped around an LLM (prompts, tools,
sandboxes, hooks, memory, sub-agents, feedback loops, observability) that turns
a raw model into a working agent.

**Trigger.** The user invoked `/research-process` on 2026-05-10 with the
explicit goal of comparing "current state of the art" against the workspace's
own harness (CI, skills, memory) in a *second* session. This document is the
first half: an independent survey, with the seed essay (Trivedy / LangChain,
"The Anatomy of an Agent Harness," March 2026) treated as one input among
many. Comparative analysis is the next session's deliverable.

**Tier classification.** Tier 3 per [RES-020]: ecosystem-wide, precedent-setting,
normative for a forthcoming harness redesign. SLR per Kitchenham, formal
grounding, primary-source citations, and parallel-subagent verification per
[RES-020]/[RES-023] are mandatory and were performed.

**Connection to existing internal corpus.** This document extends, but does
not supersede, six prior Research docs:
- `agent-handoff-patterns.md` (shipped as `/handoff`)
- `agent-supervision-patterns.md` (shipped as `/supervise`, 17 requirement IDs)
- `agent-workflow-skill-consistency-audit.md` (2026-04-15, 26 findings, 25 resolved)
- `ai-context-reduction-via-type-system-tooling.md` (Phase 1 shipped)
- `claude-code-swift-rewrite-feasibility.md` (DEFERRED 2026-04-30, awaiting TLS strategy)
- `multi-repo-automation-design-patterns.md` (stub)

Those priors cover handoff/supervise/reflect process skills — a *workflow* harness
for the user's own engineering practice. This document covers the *agent*
harness underneath and around them. Both layers are harness engineering.

## Question

> What is the state of the art in agent harness engineering as of May 2026, and
> what canonical taxonomy of components, patterns, trade-offs, and frontier
> directions has the field converged on?

Sub-questions:
1. What is "harness engineering" as a discipline, and what shape does the field
   give it (definition, history, theoretical grounding)?
2. What canonical taxonomy of harness components has the field converged on?
3. Per component, what are the dominant production patterns, the academic
   grounding, the empirical evidence, and the open failure modes?
4. How do the major shipping harnesses (Claude Code, Cursor, Aider, Codex,
   Cline, Devin, OpenHands, Replit, Continue, Zed, Augment, Warp) compare
   structurally?
5. Where is the academic and industry frontier as of mid-2026?
6. What are the binding constraints and open problems that any future harness
   redesign should plan around?

## Analysis

### 1. Foundations

#### 1.1 Definition: `Agent = Model + Harness`

The field has converged on a single equation as the framing definition:

> **Agent = Model + Harness.** If you're not the model, you're the harness.
> *— Vivek Trivedy, "The Anatomy of an Agent Harness," LangChain, 2026-03-10*

A harness encompasses everything that is not the model: system prompts, project
memory files, tools, MCP servers, sandboxes, sub-agents, hooks, permission
gates, context-management policy, observability, feedback loops, and recovery
paths [Verified: 2026-05-10]. The same equation appears in Anthropic's
*Building Effective Agents* (December 2024) and in *Effective context
engineering for AI agents* (29 September 2025), where context engineering is
positioned as the successor discipline to prompt engineering [Verified:
2026-05-10].

The most visible operational corollary is **"a decent model with a great
harness consistently beats a great model with a bad harness"** (Osmani 2026;
echoed by Trivedy, Lopopolo, Schott, Böckeler, and Karpathy). Production
evidence is non-trivial: Cognition's *SWE-1.5* technical report (2026)
explicitly documents *co-training* — *"we repeatedly dogfooded the model,
noticed issues with the harness, made adjustments to tools and prompts, and
then re-trained the model on the updated harness"* [Verified: 2026-05-10].
Lopopolo's Symphony experiment (Latent Space, 2026-04-07) reports a 3-engineer
team shipping 1M+ LOC and 1,500+ PRs over 5 months at *0% human-written code*
and *0% pre-merge human review*, attributing the result to harness quality
rather than model quality (~$2–3k/day on caching-optimized GPT-5 against an
Elixir orchestrator named Symphony) [Verified: 2026-05-10].

#### 1.2 Why the discipline emerged in 2025–2026

Three convergent forces:

1. **Frontier-model parity.** When Claude / GPT-5 / Gemini 2.5 / DeepSeek-V3
   are all roughly within 5pp on SWE-bench Verified, the differentiator is no
   longer model selection. The harness is what's left to optimize.
2. **Long-horizon failure modes.** Single-prompt evals (HumanEval, MMLU)
   stopped predicting production behavior. Agent-level evaluations
   (SWE-bench, Aider polyglot, Terminal-Bench, AgentBoard) revealed that
   ReAct-style loops fail in *predictable, harness-addressable* ways:
   early-stopping, premise-bias, infinite loops, lost-in-the-middle,
   compaction-mediated forgetting. Cemri et al. 2025 (*Why Do Multi-Agent LLM
   Systems Fail?*, arXiv:2503.13657) catalogues 14 failure modes across 1,600+
   annotated traces from 7 frameworks, with κ=0.88 inter-annotator agreement —
   the empirical foundation of "failures are configuration bugs, not model
   bugs" [Verified: 2026-05-10].
3. **Tooling maturity.** The Model Context Protocol (MCP) standardized tool
   integration in late 2024; Anthropic Skills (Oct 2025) standardized
   procedural-memory packaging; OpenTelemetry GenAI semantic conventions
   (active in CNCF since April 2024) standardized observability. The
   *substrate* for an engineering discipline now exists.

The term "harness engineering" itself is attributed to Trivedy (LangChain) but
the *practice* is older — SWE-agent (Yang et al. 2024, arXiv:2405.15793)
introduced the **Agent-Computer Interface (ACI)** thesis: *language-model
agents are a new class of end-user with their own UX needs, and interface
design substantially affects agent performance* [Verified: 2026-05-10]. ACI is
the academic ancestor; harness engineering is the production-grade
generalization.

#### 1.3 Cybernetic framing (Böckeler, Thoughtworks)

Birgitta Böckeler's *Harness engineering for coding agent users*
(martinfowler.com, 2026-04-02) provides the cleanest theoretical structure
[Verified: 2026-05-10]. Two control mechanisms, both required, neither
sufficient:

- **Guides (feedforward).** Anticipate and steer pre-action: AGENTS.md / CLAUDE.md,
  conventions, code-modification tools, Language Servers, bootstrap scripts,
  type checkers. The agent reads its environment before acting.
- **Sensors (feedback).** Observe and correct post-action: tests, linters,
  type checkers, AI code review, custom linters with LLM-friendly messages,
  CI. The agent gets a closed-loop signal.

Three regulation tiers, in descending maturity: **Maintainability** (most
developed, with mature linter/type-checker stacks), **Architecture Fitness**
(partial; ArchUnit-style tooling exists but is not LLM-friendly), and
**Behaviour** (open frontier — nobody has a robust pre-merge proof that "this
PR does what the issue said it should"). The theoretical grounding is
cybernetics + Ashby's Law of Requisite Variety: the harness's variety must
match the failure-space variety.

#### 1.4 Behavior-first design (Trivedy)

The complementary methodology is **work backwards from behavior**:

> Every piece of the harness must have a distinct job. If you cannot name
> the specific behavior a component exists to deliver, it should be removed.

This is the *constructive* counterpart to Böckeler's *analytical* framing.
Trivedy's enumeration: filesystem (durable state), bash (general-purpose
tooling), sandboxes (safety + iteration speed), memory (continual learning),
search (real-time knowledge), context management (battling rot), long-horizon
execution (loops + planning + splits), hooks (deterministic enforcement)
[Verified: 2026-05-10].

#### 1.5 Generation-verification loop (Karpathy)

Karpathy's *Software 3.0* keynote (Y Combinator AI Startup School, 2025-06-17)
contributes the productivity primitive: **the speed of the
generation-verification loop is the unit of leverage**. Don't build
fully-autonomous agents; build partially-autonomous co-pilots with explicit
**autonomy sliders** [Verified: 2026-05-10]. Software 3.0 (prompts as source
code) sits alongside 1.0 (code) and 2.0 (weights). This frame underwrites
plan-mode/auto-mode/bypass-mode designs in Claude Code and the
"untrusted/on-failure/on-request/never" approval policies in Codex.

#### 1.6 Six-layer ops-stack (Lopopolo, OpenAI Frontier)

Ryan Lopopolo's Symphony retrospective (Latent Space, 2026-04) gives the
field's cleanest *operational* decomposition: **Policy / Configuration /
Coordination / Execution / Integration / Observability** [Verified:
2026-05-10]. This is the cut to use when reasoning about org-scale harness
deployment; Trivedy's cut is for component design; Böckeler's is for control
theory. All three are mutually consistent.

---

### 2. Canonical Component Taxonomy

Synthesized from primary sources (Trivedy, Böckeler, Lopopolo, Anthropic
*Building Effective Agents* + *Managed Agents*, Horthy/HumanLayer 12-factor,
Osmani, Schott/Flue, the OpenAI Agents SDK design memos, and the
`awesome-harness-engineering` index). Each component below appears as a
named primitive in at least three independent sources.

| #  | Component                          | What it solves                                              | Concrete primitives                                              | Canonical reference                                                                                |
|----|------------------------------------|-------------------------------------------------------------|------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| 1  | **Loop / control flow**            | The ReAct cycle that drives action                          | Runner, graph executor, message-passing scheduler                | Yao et al. 2022 (ReAct, arXiv:2210.03629)                                                          |
| 2  | **Tool surface**                   | Callable functions the model invokes                        | Schema-typed tools, MCP, hosted tools                            | Schick et al. 2023 (Toolformer); MCP spec (2024)                                                    |
| 3  | **Filesystem / workspace**         | Durable state, multi-agent collaboration, output offload    | virtual FS, read/write/edit/grep/glob                            | Cao et al. 2026 (arXiv:2603.20432)                                                                  |
| 4  | **Sandbox / execution environment**| Isolated bash + code execution                              | Container, microVM, virtual (just-bash), local                   | E2B Firecracker; Codex Seatbelt; Anthropic sandbox-runtime                                          |
| 5  | **Sub-agents / orchestration**     | Context isolation, task delegation                          | task tool, handoffs, networks, supervisor topology               | Cemri et al. 2025 (MAST taxonomy)                                                                   |
| 6  | **Planner / task tracker**         | Long-horizon decomposition                                  | write_todos, claude-progress.txt, plan files                     | MetaGPT (Hong et al. 2023); deepagents                                                              |
| 7  | **Memory**                         | Cross-session knowledge, working memory                     | Tier'd (core/archival/recall), AGENTS.md, append-only sessions   | Sumers et al. 2023 (CoALA); Packer et al. 2023 (MemGPT)                                             |
| 8  | **Context engineering / compaction**| Token budget management                                     | Summarization, offload, observation masking, prompt caching      | Lindenbauer et al. 2025; Sun et al. 2025 (context-folding)                                          |
| 9  | **Skills (progressive disclosure)**| Capability bundles loaded on demand                         | Frontmatter at startup → SKILL.md on trigger → refs transitively | Anthropic Skills (Oct 2025); Voyager (Wang et al. 2023)                                             |
| 10 | **Hooks / middleware**             | Cross-cutting policy enforcement                            | PreToolUse / PostToolUse / Stop event handlers                   | Claude Code hooks (~30 events)                                                                      |
| 11 | **Permissions / authorization**    | Approval gates, principle of least privilege                | permission_mode, allowed_tools, OAuth scope, deny rules          | Codex approval policies; Anthropic permission modes                                                 |
| 12 | **Guides (feedforward)**           | Steer behavior pre-action                                   | AGENTS.md, type checkers, LSP, conventions, bootstrap scripts    | Böckeler (Thoughtworks) 2026-04-02                                                                  |
| 13 | **Sensors (feedback)**             | Detect & self-correct post-action                           | Linters, tests, pre-commit, AI review                            | Böckeler 2026-04-02; Madaan et al. 2023 (Self-Refine)                                               |
| 14 | **Self-verification loop**         | Closed-loop check that work succeeded                       | Browser automation, test runs, smoke checks, build-loop          | Anthropic *Effective harnesses for long-running agents*                                              |
| 15 | **Observability / tracing**        | Decision transparency, debugging, audit                     | OpenTelemetry GenAI semconv, structured logs, replays            | OTel GenAI SIG (CNCF, 2024–)                                                                         |
| 16 | **Eval harness**                   | Continuous quality measurement                              | LLM-as-judge, error analysis, transition matrices, benchmarks    | Yan 2025; Husain 2026 evals-skills plugin                                                           |
| 17 | **Human-in-the-loop**              | Interrupt, approve, hand back                               | Approval prompts, interruptions, contact-humans-as-tool-call     | LangGraph interrupts; HumanLayer (factor 7)                                                         |
| 18 | **Durability / resume**            | Survive crashes, restart from event log                     | Checkpointers, append-only sessions, durable steps               | Inngest; LangGraph Checkpointer; Anthropic Sessions                                                 |
| 19 | **Optimizer (declarative)**        | Programmatic improvement of prompts/programs                | DSPy GEPA, MIPRO, BootstrapFewShot                               | DSPy 3 + GEPA (Khattab et al. 2023; arXiv:2507.19457)                                              |
| 20 | **Policy**                         | Institutional/global constraints                            | "CI must pass," safety guardrails, content policy                | Lopopolo's top layer; OpenAI Guardrails                                                             |

**Three orthogonal cuts** the field uses across the same component set:

| Cut                            | Authority                  | Selection axis                                                            |
|--------------------------------|----------------------------|---------------------------------------------------------------------------|
| **Behavior-first**             | Trivedy / LangChain         | Each component justified by a behavior the bare model cannot perform      |
| **Control-theoretic**          | Böckeler / Thoughtworks     | Guides (feedforward) vs Sensors (feedback); both required                 |
| **Operational layer**          | Lopopolo / OpenAI           | Policy / Configuration / Coordination / Execution / Integration / Observability |

These cuts are mutually consistent and compose. The behavior-first cut is the
right framing for component design; the control-theoretic cut for failure
analysis; the operational-layer cut for deployment.

---

### 3. Per-Component State of the Art

#### 3.1 Loop / Control Flow

**Definition.** The Thought–Action–Observation cycle that drives every agent.

**Production state.** Universal. Every harness in the survey runs a ReAct
variant. The 2025–2026 refinements are:
- **Native tool calls** baked into models (post-Toolformer; structured JSON or
  XML tool-call format).
- **Reasoning-internalized** loops in o-series, Claude 3.7 thinking, DeepSeek-R1
  — the model performs internal CoT, harness orchestrates external tools.
- **Code-as-action** (CodeAct, Wang et al. 2024, arXiv:2402.01030; +20% over
  JSON tool calls across 17 LLMs) — the action primitive is *Python execution*
  rather than per-tool JSON schemas. OpenHands' CodeActAgent and Anthropic's
  Python tool both adopted this. [Verified: 2026-05-10]

**Academic grounding.** Yao et al. 2022 (ReAct, arXiv:2210.03629); Wang et al.
2022 (Self-Consistency, arXiv:2203.11171); Yao et al. 2023 (Tree-of-Thoughts,
arXiv:2305.10601) — ToT itself is rarely deployed verbatim due to token cost,
but its descendants (best-of-N + verifier, Q*, V-STaR) are standard.

**Failure modes.** *Early stopping* (model declares success too soon; mitigated
by feature-list gates and self-verification — see §3.14); *infinite loops*
(mitigated by step budgets, idle detection, completion contracts); *tool
selection drift* (mitigated by progressive disclosure + tool restriction).

**2026 direction.** The loop itself is solved; the frontier is *what to do at
each loop iteration* — context-folding (Sun et al. 2025, arXiv:2510.11967),
sub-trajectory branching, RL-trained loop policies (FoldGRPO).

#### 3.2 Tool Surface

**Definition.** The set of functions the model can invoke and how they are
described to it.

**Production state.** **MCP is the winner.** Every harness in the survey
except Aider supports the Model Context Protocol (open standard since late
2024, ratified by Anthropic + OpenAI as compatible). Three transports: stdio,
SSE, http. Three primitives: tools, prompts, resources [Verified: 2026-05-10].

The *quality* of the surface is bimodal:

| Approach              | Champion              | Trade-off                                                                       |
|-----------------------|-----------------------|---------------------------------------------------------------------------------|
| Bespoke JSON schemas  | Cursor, Cline, Claude Code | Tight schemas, schema-validated args, harder to compose                  |
| Code-as-tool-call     | OpenHands CodeActAgent, Anthropic Python tool | More general, easier to compose, harder to gate, harder to schema-validate |

Empirically, code-as-tool-call generalizes better but is harder to sandbox.
Anthropic's *Effective context engineering for AI agents* (Sep 2025) advocates
for fewer, more orthogonal tools over many overlapping ones — *"ten highly
focused tools will always outperform fifty overlapping ones"* (Trivedy 2026).

**Tool sprawl** (LangChain Agents, OpenAI plugins) was the early antipattern;
**progressive disclosure** (Anthropic Skills, MCP tool-search) is the response.
Composio packages 1,000+ pre-built integrations behind intent-based "Smart Tool
Resolution," which solves the description-budget problem differently — let the
gateway pick which tool to expose this turn rather than load all 1,000.

#### 3.3 Filesystem / Workspace

**Definition.** Durable state, multi-agent rendezvous, large-output offload.

**Production state.** Universal among the most capable harnesses. Trivedy
calls the filesystem *"arguably the most foundational harness primitive"*
[Verified: 2026-05-10]. Concrete primitives: `read_file`, `write_file`,
`edit_file` (with search-replace blocks, unified diffs, or whole-file rewrite
chosen per-model), `grep`, `glob`. Anthropic Skills, Cline, Claude Code,
Codex, Cursor, Aider, Flue, deepagents all expose this surface.

Cao et al. 2026 (*Coding Agents are Effective Long-Context Processors*,
arXiv:2603.20432) reframes long-context as a *file-system* problem: externalize
processing to a coding agent that uses grep/sed against the FS, +17.3% over
published SOTA on long-context benchmarks (corpora up to 3T tokens) [Verified:
2026-05-10]. This *vindicates* the Claude Code / Codex CLI architectural bet
and predicts even less reliance on million-token context windows for
code-adjacent tasks.

**Git as durable state.** Every coding harness pairs the FS with git. The
patterns:
- *Per-turn auto-commit* (Aider; revertable).
- *Shadow-git checkpoints* (Cline's signature feature; separate repo
  snapshotted after every tool call; three-axis restore — files / conversation
  / both).
- *PR-as-rollback* (Devin, Sweep legacy).
- *Worktree isolation* per session (Claude Code).

The principle: aggressive autonomy is paired everywhere with cheap revert.

#### 3.4 Sandbox / Execution Environment

**Definition.** Isolated environment for tool execution; the trust boundary.

**Production state.** Splitting into two tiers as of 2026:

| Tier              | Mechanism                                  | Examples                                    | When to use                       |
|-------------------|--------------------------------------------|---------------------------------------------|-----------------------------------|
| High-isolation    | Firecracker microVM, gVisor                | E2B (≤125 ms boot, <5 MiB overhead), Vercel Sandbox, Modal, Daytona w/ Kata | Untrusted code; multi-tenant      |
| Practical-default | OS sandbox (Seatbelt, bubblewrap, Landlock)| Claude Code, Codex CLI, OpenHands (Docker)  | Local dev with personal codebase  |

**Claude Code.** macOS Seatbelt, Linux/WSL2 bubblewrap; FS write-bounded to
cwd+subdirs, read access to whole machine except denied paths; network via
hostname-allowlisting proxy (no TLS inspection — domain-fronting risk
acknowledged in the docs); two modes (auto-allow, regular-permissions).
Open-sourced runtime as `@anthropic-ai/sandbox-runtime`. Known incompatibilities:
`watchman`, `docker`, WSL2→Windows binaries [Verified: 2026-05-10].

**Codex CLI.** Three modes (`read-only` / `workspace-write` / `danger-full-access`)
× three approval policies (`untrusted` / `on-request` / `never`); macOS
Seatbelt, Linux bubblewrap, Windows native PowerShell. Known bugs cluster at
the *sandbox × MCP-server* interaction (issue #18243: macOS Seatbelt silently
blocks shell exec under non-`danger-full-access` modes when running as MCP
server) [Verified: 2026-05-10].

**Devin / Replit / Cursor Cloud Agents** run in vendor-managed VMs — strongest
isolation by deployment, since user machines are never touched.

**Failure modes.** *Too tight*: agent can't accomplish task (watchman, docker,
WSL2/Windows boundary). *Too loose*: agent recursively deletes home directory
or exfiltrates SSH keys. *Subtle footguns* documented in the Claude Code
sandboxing docs: granting `docker.sock` Unix-socket access (= host pwn), writes
to `$PATH` directories or `.bashrc` (privilege escalation when other users
invoke), Linux `enableWeakerNestedSandbox` for Docker-in-Docker.

**2026 direction.** Firecracker microVMs are winning at the high-isolation
end; container-only (Docker, gVisor) is the middle; OS sandboxes are the
practical default. Container-only is increasingly viewed as insufficient for
untrusted agent code. The MCP-server interaction is where most current
sandbox bugs live — sandbox × cross-process IPC is the active fault line.

#### 3.5 Sub-agents / Orchestration

**Definition.** Context isolation + task delegation primitive.

**Production state.** **Single-agent + sub-agents-for-isolation has won.**
Cemri et al. 2025 (MAST taxonomy, arXiv:2503.13657) and Cognition's *Don't
Build Multi-Agents* (2025) both establish empirically that heavy multi-agent
debate / role-play orchestration *underperforms* a single capable agent that
spawns sub-agents only for context isolation [Verified: 2026-05-10].

The mainstream pattern across Claude Code, OpenAI Agents SDK (handoffs),
deepagents (`task` tool), and Devin (planner/shell/editor/browser/verifier
specialization, but coordinated by a single planner) is: *one agent owns the
task; sub-agents run in fresh context, return summary only*. ChatDev's
dialogue-heavy approach is now considered token-inefficient and superseded
[Verified: 2026-05-10].

The sub-agent dispatch interface itself is converging:
- *Description-driven routing* (Claude Code Task tool, deepagents).
- *Worktree isolation* per sub-agent (Claude Code).
- *Tool whitelist + model override* per sub-agent.
- *Summary-only return* (no conversation-history bleed).

**Devin** is the highest-fidelity production multi-agent system: planner +
shell + editor + browser + verifier, with the verifier triggering re-planning
on test failure [Verified: 2026-05-10]. Note that Devin's "multi-agent" is
*specialization* (each sub-agent has a different tool surface), not *debate*
(multiple agents discussing).

**OpenHands' event-sourced architecture** is the most theoretically clean
design in the survey: stateless `Agent` emits `Action` events; `Workspace`
executes them and returns `Observation` events; `Conversation` is the
append-only `EventLog`. Memory compression, security review, microagent
knowledge injection, sub-agent delegation, stuck-detection are all *services
subscribing to the event stream*, not bolted-on features [Verified:
2026-05-10]. This is straight Kafka/event-sourcing engineering applied to
agents.

**Failure modes** (per MAST taxonomy): (1) System-design failures —
under-specified roles, no termination criteria; (2) inter-agent misalignment —
agents talking past each other; (3) task verification failures — nobody
checks the output. Mitigations: explicit termination contracts (factor 6 of
12-factor agents — *Launch/Pause/Resume*), sensor-based verification (§3.14),
single-agent-with-sub-agents over multi-agent debate.

#### 3.6 Planner / Task Tracker

**Definition.** Long-horizon decomposition + progress tracking.

**Production state.** **Plan/Act bifurcation is universal.** Cline (Plan/Act),
Aider (Architect mode), Devin (interactive planning), Replit (Plan mode),
Cursor (Cloud Agents preview plan), Roo (Architect+Orchestrator), Claude Code
(Plan mode) — every serious harness now has a discrete planning phase
distinct from execution. The single-pass "just do it" loop is dead [Verified:
2026-05-10].

Key concrete primitives:
- **deepagents `write_todos`** — the in-context todo list as an externalized
  plan structure.
- **claude-progress.txt** + git (Anthropic *Effective harnesses for
  long-running agents*, Nov 2025) — durable cross-session progress.
- **Feature-list JSON files** (200+ entries) — Anthropic's antidote to early
  stopping; the agent must check off items before declaring done [Verified:
  2026-05-10].
- **Architect/Editor split** (Aider) — separate models for planning (often a
  reasoning model) and editing (often a faster model).

**Academic grounding.** Hong et al. 2023 (MetaGPT, arXiv:2308.00352): imposed
SOPs reduce cascading hallucinations; phase-gated workflows beat free-form
chat. Madaan et al. 2023 (Self-Refine, arXiv:2303.17651): iterative refinement
with self-feedback; ~20% absolute gains across seven tasks at test time, no
training [Verified: 2026-05-10].

**Failure modes.** *Premise propagation*: agent plans on a faulty premise
that compounds across steps (Lin et al. 2025, *LLM-based Agents Suffer from
Hallucinations*, arXiv:2509.18970). *Plan ossification*: plan written once,
not updated as discoveries change scope. Mitigation: **interactive planning**
(Devin 2.0) — proactive codebase exploration before plan finalization.

#### 3.7 Memory

**Definition.** Cross-session knowledge plus working memory across compaction
boundaries.

**Production state.** This is the most divergent component in the field.
Eight distinct architectures ship in production [Verified: 2026-05-10]:

| Architecture                         | Champion                                      | Storage         | Recall                                    |
|--------------------------------------|-----------------------------------------------|-----------------|-------------------------------------------|
| Static config files                  | CLAUDE.md, AGENTS.md, .cursorrules            | Git-tracked MD  | Every session start                       |
| File-based auto-memory               | Claude Code MEMORY.md + topic files           | `~/.claude/.../memory/` | First 200 lines / 25KB at startup |
| Skills (progressive disclosure)      | Anthropic Skills                              | `.claude/skills/` | Frontmatter at startup; body on trigger |
| Path-scoped rules                    | `.claude/rules/`, Cursor rules                | Git-tracked MD  | Glob-matched on file access               |
| Memory tool (agent-managed)          | Anthropic API memory_20250818                 | Client-controlled | Agent calls `view`/`create`/`str_replace` |
| OS-style paged memory                | Letta / MemGPT                                | Core/recall/archival tiers | Agent self-edits via tool calls    |
| Fact extraction + multi-signal RAG   | Mem0 (semantic+BM25+entity)                   | Vector + graph  | Retrieved per query                       |
| Temporal knowledge graph             | Zep, Cognee                                   | Graph DB        | `thread.get_user_context` retrieval       |
| Server-side opaque memory            | OpenAI ChatGPT memory                         | OpenAI servers  | Server-side relevance retrieval           |
| Memory-bank pattern                  | Cline / Roo (community)                       | `memory-bank/*.md` | Mandatory read-all at task start       |

**Anthropic's own routing rule** (verbatim from `code.claude.com/docs/en/memory`):

> | | CLAUDE.md | Auto memory |
> | Use for | Coding standards, workflows, project architecture | Build commands, debugging insights, preferences Claude discovers |
>
> If an entry is a multi-step procedure or only matters for one part of the
> codebase, move it to a skill or a path-scoped rule instead.

[Verified: 2026-05-10]

**OpenAI Codex's own routing rule** (verbatim):

> Keep required team guidance in AGENTS.md or checked-in documentation.
> Treat memories as a helpful local recall layer, not as the only source for
> rules that must always apply.

[Verified: 2026-05-10]

The convergent industry routing — across Anthropic, OpenAI, Cursor — is a
**layered hybrid**:
1. *Declarative facts and invariants* → CLAUDE.md / AGENTS.md (always loaded,
   kept tight).
2. *Procedural / multi-step / domain knowledge* → Skills (progressive
   disclosure: metadata at startup, body on demand, references transitively).
3. *Path-scoped rules* → `.claude/rules/*.md` or `.cursor/rules/*.mdc` with
   YAML `paths:` frontmatter.
4. *Auto-memory* → narrow: per-user preferences, point-in-time corrections,
   external-system references, learnings not yet stabilized into rules.
5. *Vector / graph memory* → unbounded conversational history or external
   corpora (chat support, customer continuity), *not* codebase conventions.

**Academic grounding.** Sumers et al. 2023 (CoALA, arXiv:2309.02427) imports
Tulving's 1972 cognitive-science taxonomy: working / episodic / semantic /
procedural memory. Most production architectures map cleanly:

| CoALA type | Production home |
|-----------|-----------------|
| Working   | The active context window itself; LangGraph short-term checkpoint; MemGPT main context |
| Episodic  | LangGraph episodic exemplars; MemGPT recall; Zep episodes; ChatGPT chat-history retrieval |
| Semantic  | LangGraph collections; Mem0/Zep/Cognee KGs; CLAUDE.md when stating facts |
| Procedural| **Anthropic Skills**; Cursor Rules; Cline Memory Bank `systemPatterns.md`; Voyager skill library |

Voyager (Wang et al. 2023, arXiv:2305.16291) is the canonical reference for
procedural memory: an ever-growing skill library of executable code with
automatic curriculum — directly maps to Anthropic's slash-skill pattern
[Verified: 2026-05-10]. Reflexion (Shinn et al. 2023, arXiv:2303.11366) is the
ancestor of `CLAUDE.md`-style operating notes: episodic textual self-criticism
in a buffer between trials, replacing gradient-based RL.

**Failure modes** (documented):

1. *Index overflow*. Claude Code's MEMORY.md hard-caps at 25KB / 200 lines;
   exceeding it truncates. Anthropic's GitHub issue #23544 ("disable
   auto-memory") and #34556 ("59 compactions, built our own") report power
   users hitting this exact failure: 3,100-token reload over 10 compactions =
   31,000 tokens spent reloading [Verified: 2026-05-10].
2. *Staleness*. Auto-extracted notes age silently — "yesterday's deploy bug"
   becomes meaningless a week later (Milvus blog, 2026).
3. *Cross-surface fragmentation*. Anthropic Skills don't sync between Claude.ai,
   API, and Claude Code: each surface owns its installation [Verified:
   2026-05-10].
4. *Memory regression*. ChatGPT Memory: OpenAI Developer Community bug
   #1310926 documents "context loss across chats and inside threads"
   [Verified: 2026-05-10].
5. *ADD-only accumulation*. Mem0's documented design: nothing overwritten;
   contradictions survive unless entity-linked retrieval suppresses them.
6. *Manual-discipline failure*. Cline Memory Bank requires "update memory
   bank" prompts; sessions drift; `activeContext.md` updates while
   `systemPatterns.md` ossifies. The MCP-server variant
   (`dazeb/cline-mcp-memory-bank`) automates writes specifically because manual
   discipline failed.

**2026 direction.** *Skills with progressive disclosure* threads the needle
between context-bloat and recall-failure best, by storing unboundedly while
loading only metadata. Anthropic launched Skills as an open standard in late
2025; cross-vendor adoption is real (OpenHands' microagents are Skill-format
compatible). The frontier question is no longer "what to remember?" but
**"how do we audit, prune, version, and govern agent memory across multi-agent
systems?"** — see *Memory in the Age of AI Agents* survey (claimed
arXiv:2512.13564, not directly fetched).

#### 3.8 Context Engineering / Compaction

**Definition.** Token-budget management as a first-class harness primitive.

**Production state.** Universal. Anthropic explicitly elevated **context
engineering** to a discipline successor to prompt engineering in *Effective
context engineering for AI agents* (Sep 2025) [Verified: 2026-05-10]. Three
primary techniques converge across vendors:

1. **Compaction.** Auto-compact (triggered by approaching limit; clears tool
   outputs, summarizes conversation, re-attaches CLAUDE.md and skill
   metadata); manual `/compact <focus>`; PreCompact / PostCompact hooks
   (Claude Code).
2. **Tool-output offload.** Store massive outputs in the filesystem; keep
   only headers + footers in context. Anthropic's claude-progress.txt pattern
   externalizes long-running progress to disk.
3. **Progressive disclosure.** Anthropic Skills, MCP tool-search (deferred
   tool loading): metadata at startup, body on trigger, references
   transitively.

**Empirical foundations:**

- **Hong et al. 2025 (Chroma, *Context Rot*).** Across 18 frontier LLMs:
  performance is *non-uniform* as a function of input length even on simple
  tasks; degradation is sensitive to question/answer semantic similarity,
  distractor presence, haystack structure [Verified: 2026-05-10]. Empirical
  foundation for "context is a finite, depleting resource."
- **Hsieh et al. 2024 (RULER, arXiv:2404.06654).** 17 long-context models
  tested; despite near-perfect NIAH, almost all degrade well below claimed
  context size on multi-hop and aggregation tasks [Verified: 2026-05-10].
  Effective context << advertised context.
- **Liu et al. 2023 (Lost in the Middle, arXiv:2307.03172).** Multi-document
  QA performance is U-shaped over relevant-info position [Verified:
  2026-05-10]. Direct motivation for tool-result placement strategies.
- **Lindenbauer et al. 2025 (arXiv:2508.21433).** Naive *observation
  masking* (drop old tool outputs) matches LLM-summarization at lower cost;
  hybrid yields 7-11% additional gains [Verified: 2026-05-10]. Practical
  guidance: harnesses should default to *cheap* context management (drop,
  don't summarize) until evidence demands more.
- **Sun et al. 2025 (Context-Folding, arXiv:2510.11967).** Branch into
  sub-trajectories; fold subtask traces into outcome summaries on completion;
  combined with FoldGRPO RL training — 10× smaller active context at parity
  with ReAct [Verified: 2026-05-10]. Operationalizes Reflexion-style
  summarization as a structural primitive.

**Trade-off.** Inject too much → context bloat, reduced adherence. Inject too
little, retrieve more → recall failure, latency, opaque "why didn't the agent
know X?". **Skills' progressive disclosure** is the architectural answer most
aligned with this trade-off: store unboundedly, load metadata only.

#### 3.9 Skills (Progressive Disclosure)

**Definition.** Capability bundles loaded by progressive disclosure: tiny
metadata at startup, body on trigger, references transitively.

**Production state.** Anthropic Skills (launched as open standard in
October 2025) is the canonical implementation. **Three loading levels**:

| Level                        | When loaded             | Token cost           | Content                  |
|------------------------------|-------------------------|----------------------|--------------------------|
| 1: Metadata (YAML name+desc) | Always at startup       | ~100 tok / skill     | Discovery only           |
| 2: SKILL.md body             | When triggered          | <5K tok              | Procedural instructions  |
| 3: Bundled files / scripts   | On-demand via bash      | "Effectively unlimited" | Reference / executable code |

[Verified: 2026-05-10]

**Triggering = description-driven.** Anthropic explicitly: *"The description
is critical for skill selection: Claude uses it to choose the right Skill
from potentially 100+ available Skills."* Always third-person ("Processes
Excel files…", not "I can help…"). Body recommended **<500 lines**.
References must be **one level deep** because Claude may `head -100`-preview
deeper files instead of reading them fully.

**Cross-vendor adoption.** OpenHands' *microagents* are Skill-format
compatible (markdown with frontmatter triggers, two formats: AgentSkills
standard with directory-based `SKILL.md` and gradual disclosure, plus legacy
single-file). Public registry at github.com/OpenHands/extensions [Verified:
2026-05-10]. Letta Code bundles skills + sub-agents in its CLI. Codex
Harness (Symphony / Lopopolo) treats skills as *"reusable primitives bundling
business logic + observability"* [Verified: 2026-05-10].

**Academic grounding.** Voyager (Wang et al. 2023, arXiv:2305.16291): the
ever-growing skill library of executable code with automatic curriculum, 3.3×
more unique items, 15.3× faster tech-tree progression in Minecraft —
foundational reference for procedural-memory architectures [Verified:
2026-05-10].

**Failure modes.** *Cross-surface fragmentation* (Anthropic's own docs:
Skills don't sync between Claude.ai / API / Claude Code). *Description-budget
truncation* when many skills load. *Stale skills* — body says one thing, code
behaves differently. The user's existing `skill-lifecycle` skill addresses
the staleness failure with explicit review cadences [Verified: 2026-05-10
against `/Users/coen/Developer/swift-institute/Skills/skill-lifecycle/`].

#### 3.10 Hooks / Middleware

**Definition.** Cross-cutting policy enforcement at lifecycle events.

**Production state.** Claude Code is the most expressive (~30 lifecycle
events: SessionStart, Setup, UserPromptSubmit, UserPromptExpansion, PreToolUse,
PermissionRequest, PermissionDenied, PostToolUse, PostToolUseFailure,
PostToolBatch, Notification, SubagentStart, SubagentStop, TaskCreated,
TaskCompleted, Stop, StopFailure, TeammateIdle, InstructionsLoaded,
ConfigChange, CwdChanged, FileChanged, WorktreeCreate, WorktreeRemove,
PreCompact, PostCompact, Elicitation, ElicitationResult, SessionEnd) [Verified:
2026-05-10]. Five hook types: command (shell), http (POST), mcp_tool,
prompt (single-turn LLM), agent (subagent with tool access).

**Exit-code protocol** (Claude Code, the de-facto standard the rest of the
field is converging on):
- Exit 0 → success; parse stdout JSON.
- Exit 2 → blocking error; stderr fed back to Claude as error message.
- Other → non-blocking; proceed.

[Verified: 2026-05-10]

**PreToolUse decision precedence**: `deny > defer > ask > allow`. Hooks can
also rewrite tool input via `updatedInput` and inject system reminders via
`additionalContext` (capped at 10KB).

**Other harnesses, partial coverage:**

- **OpenAI Agents SDK** ships **Guardrails** as `@input_guardrail` /
  `@output_guardrail` decorators returning `GuardrailFunctionOutput` with
  `tripwire_triggered: bool`; tripwire raises `InputGuardrailTripwireTriggered`,
  halting execution. Input guardrails parallel-or-blocking. No PreToolUse-equivalent
  rewriting; agent-boundary granularity, not tool-call [Verified: 2026-05-10].
- **LangGraph** ships `interrupt(payload)` plus checkpointer; suspends graph,
  persists state keyed by `thread_id`, waits indefinitely for `Command(resume=value)`.
  Sharp edge: node re-executes from start on resume, forbidding non-idempotent
  pre-interrupt work. More durable than any in-process hook ("can be resumed
  many months later, on a different machine") but cannot autonomously rewrite
  tool input [Verified: 2026-05-10].
- **Pydantic AI** ships `ModelRetry` raised by output validators; feeds
  validation error back to the model, re-invokes. Per-agent and
  per-output-type budgets. Closer to typed-throws-style retry than broader
  hook semantics [Verified: 2026-05-10].
- **Aider** is the simplest case: enforcement = git itself, with default
  `git commit --no-verify`; `--git-commit-verify` opts back in [Verified:
  2026-05-10].
- **Cursor** has *no programmatic enforcement layer*. Enforcement is entirely
  declarative via four-tier rules. The most exposed position if model
  reliability proves insufficient.
- **OpenHands** enforces sandbox-side rather than harness-side: actions either
  succeed or fail in the container.

**What hooks accomplish (five orthogonal axes):**

1. **Determinism gates.** Forced lint/typecheck/test.
2. **Safety gates.** Block destructive commands, redact secrets.
3. **Compaction / context shaping.** Auto-summarize, inject relevant context.
4. **Routing.** Decide which sub-agent / model handles next turn.
5. **Telemetry.** Log every step for replay, eval, offline learning.

The cross-vendor pattern: every harness has at least one of these, but only
Claude Code surfaces all five as first-class user-configurable extension
points.

#### 3.11 Permissions / Authorization

**Definition.** Approval gates and principle of least privilege.

**Production state.** Claude Code: five permission modes (`default`,
`acceptEdits`, `plan`, `auto`, `bypassPermissions`, `dontAsk`); allow/deny/ask
rule lists with deny-first precedence; gitignore-style path matching; MCP
permission patterns (`mcp__server__tool`); Agent permissions (`Agent(Explore)`).
Codex: orthogonal sandbox modes × approval policies [Verified: 2026-05-10].

The user's current settings.json (verified against
`/Users/coen/.claude/settings.json` on 2026-05-10) configures:
- 100+ deny/ask entries primarily targeting destructive bash and secrets-edit
  patterns
- `defaultMode: "auto"`
- Bash(*) allow-listed
- `skipAutoPermissionPrompt: true`

This is one of the more liberal permission postures in the field — auto mode
+ Bash(*) + skip-auto-prompt — backed by an aggressive ask-list for
destructive ops. Codex's default-`workspace-write + on-request` is structurally
similar but routed through an OS sandbox; Claude Code's auto mode uses a
background safety classifier instead.

#### 3.12 Guides (Feedforward) and 3.13 Sensors (Feedback)

Per Böckeler's framing (§1.3), every harness has both, even if not named as
such. The mature/open frontier breakdown:

| Tier                 | Guides (mature)                              | Sensors (mature)                   | Gap                                  |
|----------------------|----------------------------------------------|-------------------------------------|--------------------------------------|
| Maintainability      | AGENTS.md / CLAUDE.md, conventions, LSPs     | Linters, type checkers, formatters | Solved                               |
| Architecture Fitness | Type system, ArchUnit-style rules            | Custom linters with LLM-friendly messages | Partial — tooling exists, not LLM-tuned |
| Behaviour            | Specs, ADRs, design docs                     | Tests, AI code review              | **Open** — no robust pre-merge proof |

The Behaviour gap is the field's biggest open frontier (§7).

#### 3.14 Self-Verification Loop

**Definition.** Closed-loop check that work succeeded, before declaring done.

**Production state.** Anthropic's *Effective harnesses for long-running
agents* (Nov 2025) documents the canonical pattern: **mandatory browser
automation testing** via Puppeteer MCP for UI changes; **build-loop with
1-minute upper bound** (Lopopolo); **feature-list JSON files** (200+ entries
preventing premature victory); **claude-progress.txt + git** as cross-session
state [Verified: 2026-05-10]. Cline's `attempt_completion` tool is gated by
test runs.

**Academic foundation.** Madaan et al. 2023 (Self-Refine, arXiv:2303.17651)
established the pattern: same model as generator/critic/refiner; ~20% absolute
gains. Modern reasoning models internalize this as RL-trained behavior;
weaker-model harnesses scaffold it explicitly [Verified: 2026-05-10].

#### 3.15 Observability / Tracing

**Definition.** Decision transparency + replay capability + offline-learning
substrate.

**Production state.** OpenTelemetry GenAI semantic conventions are the
emerging schema standard (CNCF SIG active since April 2024). Span types:
`create_agent`, `invoke_agent`, `invoke_workflow`. Required attributes:
`gen_ai.operation.name`, `gen_ai.provider.name`. Opt-in PII-sensitive:
`gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`,
`gen_ai.tool.definitions` [Verified: 2026-05-10]. Datadog landed native
support in OTel v1.37; Grafana started LLM-trace ingestion in May 2026.

**Vendor platforms:**

| Platform             | Style                                       | Distinctive                                    |
|----------------------|---------------------------------------------|------------------------------------------------|
| LangSmith            | Tightest LangChain/LangGraph coupling        | Polly (Dec 2025) — first vendor with model-suggested fixes from traces |
| Braintrust           | Eval-driven, "quality management system"     | Single connected workflow (eval + observability) |
| Langfuse             | Open-source, self-host                       | Operationally heavy (PG + ClickHouse + Redis + S3 + K8s) |
| Phoenix (Arize)      | Full open-source, OTel-aggressive            | Practical for vendor-neutral stacks            |
| Helicone             | Proxy-based, simplest setup                  | Weakest evals; OpenAI cost-tracking focus      |
| Anthropic Console    | In-product traces for Managed Agents         | Webhooks for session/vault lifecycle           |
| OpenAI tracing       | Built into Agents SDK                        | First-party                                    |

[Verified: 2026-05-10]

**Claude Code** emits OpenTelemetry; tool input/output content **not logged
in spans by default** — `OTEL_LOG_TOOL_CONTENT=1` opts in, with 60 KB-per-span
truncation [Verified: 2026-05-10].

**The harness-as-living-artifact thesis** (Trivedy: every failure becomes a
permanent rule) is *partially* operationalized:

- ✅ **Replay-based debugging** — `agent-replay` (open-source SQLite tool),
  Maxim AI, Phoenix, LangSmith all ship some form. *Recording the model id is
  essential because vendors update weights frequently — replay validates that
  responses came from the expected version* [Verified: 2026-05-10].
- ⚠️ **Auto-prompt-revision from failure traces** — LangSmith Polly,
  Maxim AI debugging assistants. Quality reportedly mixed: useful for obvious
  cases, brittle for subtle reasoning errors.
- ✅ **Process Reward Models on harness traces** — AgentPRM (WWW 2026,
  arXiv:2511.08325); DeepSeek-R1 used GRPO on reasoning trajectories; Fin-PRM
  and ReasonFlux-PRM extend to domain-specialized variants [Verified:
  2026-05-10]. The honest open problem: *"Process rewards are hard to define …
  reasoning steps do not naturally occur in sequences, and annotating labels
  for each token is too costly."*
- ✅ **Co-training models with harnesses in the loop** — Cognition's SWE-1.5
  technical report (2026): *"we repeatedly dogfooded the model, noticed
  issues with the harness, made adjustments to tools and prompts, and then
  re-trained the model on the updated harness"* [Verified: 2026-05-10]. They
  define a *reward hardening* process (multiple rounds of human-expert
  attempts to circumvent graders).
- ❌ **Automated trace → rule extraction → harness commit pipeline** — *no
  vendor publicly documents this as a shipping artifact*. The Cognition Devin
  2025 retrospective discusses improvement metrics (PR merge rate 34% → 67%)
  but does not describe rule-extraction-from-failure as a discrete pipeline.
  The strong form of the Trivedy thesis remains aspirational outside
  Cognition's internal practice.

[RES-021 contextualization step]: the field has the *substrate* for harness
self-improvement (replay + PRM + co-training) but has not yet packaged it as
a shipping product. Universal academic enthusiasm for harness-as-compiler
(§7) does not yet imply universal production necessity.

#### 3.16 Eval Harness

**Definition.** Continuous quality measurement, separate from the agent
harness itself.

**Production state.** Husain (March 2026) shipped an **evals-skills** plugin
packaging six skills: error-analysis, generate-synthetic-data, write-judge-prompt,
validate-evaluator, evaluate-rag, build-review-interface [Verified: 2026-05-10].
Yan's framing: *"Evals aren't static artifacts; they're practices applying the
scientific method, eval-driven development, and AI output monitoring."*

Husain explicitly cautions **against** writing evaluators before features ("LLMs
have infinite failure surface; you can't anticipate"). Start with **error
analysis** on real traces. Concept: **transition matrices** showing
failure-causing transitions [Verified: 2026-05-10].

**Benchmarks dominating 2025–2026** (whole-harness, not just model):

- **SWE-bench Verified / Multimodal / Live** — coding agent canonical;
  every frontier-model launch reports SWE-bench numbers.
- **Aider polyglot** — 225 hardest Exercism problems across 6 languages;
  two-attempt protocol (test feedback as the second-attempt context) is now
  standard.
- **Terminal-Bench** (Merrill et al. 2026, arXiv:2601.11868) — 89 hard
  real-world terminal tasks; frontier agents (Claude Code, Codex CLI,
  Gemini CLI, OpenHands) all <65% [Verified: 2026-05-10]. The first benchmark
  that directly evaluates *whole harnesses* — i.e., the actual operating
  mode of Claude Code et al.
- **AgentBoard** (Ma et al. 2024, arXiv:2401.13178) — fine-grained
  *progress-rate* metric (vs binary success); underwrites reward-shaping in
  agentic RL.
- **SWE-bench Pro** — Augment claims 51.8% (vs Cursor 50.21%, Claude Code
  49.75%), citing Context Engine [Verified: 2026-05-10].

#### 3.17 Human-in-the-Loop

**Definition.** Interrupt, approve, hand back when the model is uncertain or
the action is risky.

**Production state.** LangGraph interrupts (most durable); HumanLayer's
`request_approval` (12-factor agents factor 7: *Contact humans with tool
calls*); Claude Code permission modes; Cursor approval prompts. The shape
across vendors converges: model emits a tool call asking the human, harness
materializes that as a UI prompt, human responds, response feeds back to
the model.

#### 3.18 Durability / Resume

**Definition.** Survive crashes and restart from event log.

**Production state.** Inngest (durable steps via Inngest's substrate);
LangGraph Checkpointer (PostgreSQL or SQLite-backed); Anthropic Sessions
(server-side append-only log); Vercel Workflows (suspend/resume across
function timeouts); OpenHands EventLog; Anthropic Managed Agents'
*brain/hands/session* split (April 8, 2026) — the LLM "brain" stateless and
replaceable, sandboxes "hands" provisioned per `execute(name, input)` call,
durable append-only event log "session" holds state. **p50 TTFT dropped ~60%,
p95 >90%** [Verified: 2026-05-10].

The "stateless reducer" pattern (12-factor factor 12) plus durable session is
the converging shape.

#### 3.19 Optimizer (Declarative)

**Definition.** Programmatic improvement of prompts and program structure.

**Production state.** **DSPy** is the canonical implementation [Verified:
2026-05-10]. Three-piece design: `Signature` (typed I/O), `Module` (Predict /
ChainOfThought / ReAct / ProgramOfThought), `Optimizer` (compile against
eval). DSPy 3 + **GEPA** (Genetic-Pareto, July 2025 paper, arXiv:2507.19457)
evolves entire DSPy programs (signatures, modules, control flow) via
LM-driven reflection on trajectories. Reported gains: 67% → 93% on MATH for
ChainOfThought; +10pp on AIME 2025 for GPT-4.1 Mini. Adopted by MLflow, Comet
ML Opik, Pydantic, and Google's Agent Development Kit. ~34k stars [Verified:
2026-05-10].

This is the **harness-as-compiler** thesis operationalized: the harness is a
search target, optimized either by an outer agent or by gradient-free / RL
methods, with the harness's edits treated as falsifiable artifacts.

#### 3.20 Policy

**Definition.** Institutional / global / organizational constraints.

**Production state.** Lopopolo's top layer; Anthropic managed-policy
CLAUDE.md (system-directory file org admins can preload, not user-overridable
[Verified: 2026-05-10]); Codex `AGENTS.override.md`; OpenAI Agents SDK
guardrails; Composio policies. The "CI must pass" / "no PR without review"
class of rule is policy.

---

### 4. Comparative Survey of Major Harnesses

A structured comparison across eight axes, drawing on the parallel-subagent
surveys [Verified: 2026-05-10 unless noted]. Where primary documentation was
inaccessible (some Cursor / Replit URLs aggressive-redirect), claims are
flagged conservatively.

| Harness        | Memory                                                | Tool Surface                          | Context Mgmt                                     | Orchestration                          | Hooks                       | Sandbox                                          | Loop Control                | Distinctive                                              |
|----------------|-------------------------------------------------------|---------------------------------------|--------------------------------------------------|----------------------------------------|-----------------------------|--------------------------------------------------|-----------------------------|----------------------------------------------------------|
| Claude Code    | CLAUDE.md (layered) + auto-MEMORY.md + Skills + .claude/rules/ + memory tool (API only) | Native + MCP + Skills            | Auto-compact + skill progressive disclosure + hook-driven | Subagent w/ Task tool, worktree iso    | ~30 events, 5 hook types    | macOS Seatbelt / Linux bubblewrap, network proxy | Permission modes: default/auto/plan/bypass | Most expressive hook surface; Skills as open standard |
| Cursor         | 4-tier rules (.cursor/rules .mdc / User / Team / AGENTS.md) | Native + MCP                          | Encrypted vector embeddings, 5min refresh        | Single + Explore subagent + Cloud VMs  | Cloud-agent hooks only      | Cloud Agent VM only; local has none              | Unlimited tool calls / queue | 4-mode rule activation; encrypted client-side embeddings |
| Aider          | CONVENTIONS.md + /read flags + prompt caching         | Native; **no MCP**                    | **Repo-map** (graph-rank over tree-sitter, 1K tokens default) | **Architect/Editor split** (planner+executor, two models) | Auto-lint + auto-test post-edit | None (git revertability)                         | Mode-driven (/code /architect /ask)| Repo-map; explicit architect/editor; first prompt caching |
| Cline          | .clinerules + CLAUDE.md + memory-bank/                | Native + MCP + browser_action         | AST scan + regex on demand; new_task handoff     | Plan/Act mode; single-agent           | Auto-approve grid + checkpoints | Per-tool approval; no process sandbox            | attempt_completion; auto-approve cap | **Shadow-git checkpoints** (3-axis restore)              |
| Roo Code       | Cline rules + mode-scoped (.roo/rules-{mode}/)         | Cline-derived + mode restrictions     | Cline-derived                                    | **Built-in modes** + **Orchestrator**  | Cline-derived               | Cline-derived; per-mode soft sandbox             | Per-mode termination        | Mode-scoped permissions and rules                        |
| OpenAI Codex CLI | AGENTS.md hierarchical (32KiB cap) + AGENTS.override.md + opt-in async memories | Native + MCP                          | Standard model context; no vector index          | Single + optional reviewer agent       | Approval-policy gates       | **Real OS sandbox** (Seatbelt / bubblewrap / Windows native), 3 modes × 3 policies | Approval × sandbox modes    | OS-level sandboxing as default                           |
| Devin          | Knowledge panel + per-team facts                      | Shell + IDE + browser + integrations  | **Devin Search** (codebase-grounded retrieval)   | **5-agent split** (planner/shell/editor/browser/verifier) | PR-mediated review        | Cloud VM (always)                                | Long-horizon; verifier triggers re-plan | Browser-as-first-class-tool                             |
| OpenHands      | Microagents (markdown w/ frontmatter triggers) + AGENTS.md/CLAUDE.md/GEMINI.md fallback | **CodeActAgent** (bash + Python + browser DSL) | Append-only EventLog; memory compression service | Stateless agent + EventLog services    | Security review + stuck-detection services | Docker / E2B / Daytona / Modal | Action/Observation loop                | **Event-sourced architecture** (most novel)              |
| Continue.dev   | config.yaml + Hub + rules: field                       | Per-role models + MCP + custom slash  | Pluggable context providers (@-mention)          | Single-agent; Hub assistants           | None first-class            | None (IDE process)                               | Mode-based                  | Model-role separation; context-provider plugins          |
| Replit Agent   | Repl-as-context + integrations                        | Full-stack + auto-deploy + DB + secrets | Repl filesystem direct                          | Lite/Economy/Power modes; Plan mode    | Plan-mode review gate       | NixOS-based per-Repl sandbox (always cloud)      | Plan-approved-then-execute  | Cloud sandbox + auto-deploy + zero-install               |
| Warp           | Workflow rules + command history                      | **Terminal IS the tool surface** + MCP | Terminal session + MCP-fed                       | **Oz** orchestrator (multi-agent cloud)| Observability layer        | Terminal scope (interactive); cloud VM (autonomous) | Schedule/event/integration triggered | Terminal as agent's IDE                                  |
| Zed            | .rules + Threads sidebar                              | Standard + can host external agents (Claude Code, Gemini CLI) | @-mention                                         | Multiple threads; single-agent per thread | Tool profiles (Write/Ask/Minimal) + permission default | Editor process              | Per-tool confirm; change-review accordion | **Tool profiles orthogonal to permissions**              |
| Augment        | Project-wide via Context Engine                       | Native + Claude Opus 4.6              | **Context Engine** (4,456 → 682 sources via semantic filter) | Single agent backed by engine          | Standard IDE confirms       | IDE process                                      | Tool-loop until resolution  | **Retrieval-as-product**                                 |

**Convergent patterns** across all 12+:

1. *Memory file at repo root.* CLAUDE.md / AGENTS.md / GEMINI.md /
   CONVENTIONS.md — every harness either originated or adopted one. AGENTS.md
   is winning the standardization race (Cursor adopted as alternative; Codex
   canonical; OpenHands fallback).
2. *MCP is table stakes.* All 12 except Aider.
3. *Plan/Act bifurcation.* All 12 have a discrete planning phase.
4. *Diff-based file edits over whole-file rewrites.* Search-replace blocks,
   unified diffs.
5. *Shadow-state checkpointing or PR-as-rollback.* Cline shadow-git, Cursor
   checkpoints, Aider auto-commit, Devin PR pattern, Replit Repl history.
6. *Per-mode/per-profile tool restriction.* Roo modes, Zed profiles, Cline
   auto-approve grid, Codex sandbox modes.

**Divergent patterns**:

1. *Retrieval substrate.* Vector embeddings (Cursor, Augment), graph-rank
   over tree-sitter (Aider repo-map), code-graph search (Cody/Sourcegraph),
   AST + regex on demand (Cline), event-stream + microagent injection
   (OpenHands), or none (Codex CLI, Aider default).
2. *Sandboxing.* OS-level isolation (Codex Seatbelt/bubblewrap, OpenHands
   Docker, Devin/Replit cloud VM) vs GUI-confirm only (Cline, Zed, Cursor
   local). Codex is alone among local-first CLIs in taking process isolation
   seriously by default.
3. *Multi-agent topology.* Specialization-split (Devin 5-agent, Aider
   architect/editor, Roo Orchestrator) vs single-agent-with-subdispatcher
   (Cursor Explore subagent) vs stateless-on-event-stream (OpenHands).
4. *Tool surface philosophy.* Bespoke per-tool JSON (Cursor, Cline, Claude
   Code) vs code-as-tool-call (OpenHands CodeActAgent). The latter is winning
   empirically but is harder to gate.
5. *Where the agent runs.* User machine vs cloud VM vs hybrid (Warp).
6. *Hooks/determinism.* Claude Code's lifecycle hooks have no equivalent
   anywhere else; Codex routes determinism through approval gates;
   OpenHands through pluggable services on the event stream.

**Most architecturally novel: OpenHands.** The event-sourced architecture
(stateless `Agent` + `Action`/`Observation` events + append-only `EventLog` +
services subscribing to the stream) is categorically different from the
imperative tool-loop architectures everywhere else. CodeActAgent's
"code-as-tool-call" is a second distinguishing bet. Plus full open-source +
ICLR paper + LiteLLM-wrapped provider portability. Cursor wins on UX; Claude
Code wins on hook expressiveness; Aider invented patterns everyone copies;
Codex wins on real sandboxing; Devin wins on browser-driven QA — but
OpenHands is the only design where you could re-implement the entire agent
loop in a different language and the *architecture* would carry over
unchanged because it isn't a loop, it's a stream.

---

### 5. Empirical Foundations

The Tier 3 SLR per [RES-023] surfaced these empirically anchored claims as
load-bearing for harness design. All citations have abstracts/intros fetched
2026-05-10 unless noted `[claimed]`.

**Coding-agent benchmarks dictate harness shape:**

| Benchmark        | What it measures                                            | Calibration impact                                              |
|------------------|-------------------------------------------------------------|-----------------------------------------------------------------|
| SWE-bench (Verified / Multimodal / Live) | 2,294+ real GitHub issue/PR pairs                  | Single most influential eval; every harness improvement calibrated against it |
| Aider polyglot   | 225 hardest Exercism problems × 6 languages, two-attempt    | First widely-adopted *editing-agent* benchmark (vs generation)  |
| Terminal-Bench   | 89 hard real-world terminal tasks; frontier all <65%        | First *whole-harness* benchmark on terminal-native tasks        |
| AgentBoard       | Fine-grained progress-rate metric                            | Underwrites reward-shaping in agentic RL                        |
| AgentBench       | 8 environments; commercial > open-source                    | Earliest broad agent eval; mostly superseded                    |

Yang et al. 2024 (SWE-agent, arXiv:2405.15793) is the canonical empirical
demonstration that **interface design substantially affects agent performance**
— the Agent-Computer Interface thesis. Custom file editor + repo-navigation
commands + lint-on-write took SWE-bench from 12.5% to SOTA at the time
[Verified: 2026-05-10]. *This is the empirical foundation for harness
engineering as a research object.*

**Long-context fundamentals:**

- *Liu et al. 2023* (Lost in the Middle, arXiv:2307.03172): U-shaped recall
  over position [Verified: 2026-05-10].
- *Hsieh et al. 2024* (RULER, arXiv:2404.06654): effective context << advertised
  [Verified: 2026-05-10].
- *Hong et al. 2025* (Chroma, *Context Rot*): 18-LLM survey, performance
  non-uniform with input length [Verified: 2026-05-10].
- *Lindenbauer et al. 2025* (arXiv:2508.21433): naive observation masking
  matches LLM-summarization at lower cost [Verified: 2026-05-10].

**Multi-agent failure empirics:**

- *Cemri et al. 2025* (Why MAS Fail, arXiv:2503.13657): MAST taxonomy, 14
  failure modes, 1,600+ traces, κ=0.88 [Verified: 2026-05-10]. Empirical
  foundation for the field's retreat from heavy multi-agent orchestration.

**Co-training documented in production:**

- *Cognition SWE-1.5 technical report* (2026): explicit co-training of model
  with harness across iterations. [Verified: 2026-05-10]
- *Lopopolo / Symphony retrospective* (Latent Space, 2026-04-07): 1M+ LOC,
  1,500+ PRs, 0% human-written, 0% pre-merge review, 5 months, 3 engineers,
  ~$2-3k/day. [Verified: 2026-05-10]

**Reasoning training internalized in models:**

- *Lightman et al. 2023* (Let's Verify Step by Step, arXiv:2305.20050) →
  PRM800K → o1-style RL post-training. [Verified: 2026-05-10] Implication for
  harnesses: the reasoning models that today's harnesses run on top of are
  PRM-trained; harnesses no longer need to scaffold step-level verification
  the way they did for GPT-3.5.

---

### 6. Theoretical Grounding (Tier 3 [RES-024] Formal Component)

#### 6.1 CoALA (Cognitive Architectures for Language Agents)

Sumers et al. 2023 (arXiv:2309.02427) imports Tulving's 1972 cognitive-science
taxonomy:

```
Memory M = ⟨ Working, Episodic, Semantic, Procedural ⟩
Action  A = ⟨ Reasoning, Retrieval, Grounding, Learning ⟩
Decision D : (Memory × Observation) → Action
```

[Verified: 2026-05-10] Production memory architectures (§3.7) map onto these
four types. CoALA's contribution is *formal* rather than architectural: it
provides the canonical vocabulary for memory-related design discussions.

#### 6.2 ACI (Agent-Computer Interface) thesis

Yang et al. 2024 (arXiv:2405.15793) formalizes the design space of
agent-facing interfaces:

```
Performance(Agent, Task) = f(Model, ACI, Environment)
```

Where ACI = ⟨tool-set, prompts, error-message-format, navigation primitives⟩.
The empirical claim: *holding Model and Environment fixed, ACI improvements
yield large performance deltas.* [Verified: 2026-05-10]

This is the theoretical foundation underwriting the entire discipline: if
agent performance varied only with Model, harness engineering would be
search-engine-optimization, not engineering. The ACI thesis says it *is*
engineering.

#### 6.3 Harness-as-compiler

The DSPy → GEPA → Meta-Harness → Agentic Harness Engineering line (Khattab
2023 → Lee 2026 → Lin 2026):

```
Spec    : Declarative agent program (Signatures + Modules + control flow)
Compiler: Optimizer (BootstrapFewShot, MIPRO, GEPA)
Trace   : Execution log with per-step rewards
δ       : Spec → Spec mutation, scored against eval
```

Lee et al. 2026 (Meta-Harness, arXiv:2603.28052) reports +7.7pt
classification, 75% token reduction, +4.7pt math vs hand-engineered
baselines. Lin et al. 2026 (arXiv:2604.25850) ships a three-pillar
observability contract (component / experience / decision) enabling
falsifiable harness mutations; Terminal-Bench 2: 69.7% → 77.0% over 10
iterations [Verified: 2026-05-10].

This formalizes Trivedy's "every failure becomes a permanent rule" thesis
into a search problem with measurable progress.

#### 6.4 Cybernetic framing (Ashby's Law of Requisite Variety)

Böckeler's framing (martinfowler.com, 2026-04-02): the harness is a
controller in a feedback loop with the agent-environment pair. By Ashby's
Law, the controller's variety must match the disturbance variety. Concretely:
the harness's failure-mode coverage must match the agent's failure-mode
generation. *Open frontier*: no published method for measuring "harness
failure-mode coverage" against "agent failure-mode generation"
[Verified: 2026-05-10].

---

### 7. The 2026 Frontier

#### 7.1 Harness-as-compiler / declarative agent specs

DSPy 3 + GEPA, Meta-Harness (Lee 2026), Agentic Harness Engineering (Lin 2026).
Common thread: the harness is a search target, optimized either by an outer
agent or by RL. Where the field is moving:

- Falsifiability contracts on harness mutations (each rule must predict an
  outcome; outcome violation triggers rollback).
- Three-pillar observability (component / experience / decision) as the
  precondition for any auto-evolution.
- Cross-vendor adoption: GEPA in MLflow, Comet ML Opik, Pydantic, Google ADK.

#### 7.2 Coding agent as universal long-context processor

Cao et al. 2026 (arXiv:2603.20432) reframes long-context as a *file-system*
problem: externalize processing to a coding agent that uses grep/sed against
the FS. +17.3% over published SOTA on long-context benchmarks (corpora up to
3T tokens). This *vindicates* the Claude Code / Codex CLI architectural bet
and predicts decreasing reliance on million-token context windows for
code-adjacent tasks [Verified: 2026-05-10].

#### 7.3 Domain-specialized harnesses

llvm-autofix (arXiv:2603.20075 [claimed]) shows compilers, kernels, and
similarly closed domains require *bespoke* ACIs. Generic harnesses
underperform on domain-heavy tasks. Expect proliferation: harnesses for proof
assistants, hardware HLS, scientific computing.

#### 7.4 Harness-in-the-loop RL post-training

Zhang et al. 2025 (Agentic RL Survey, arXiv:2509.02547) repositions LLM RL
from single-step MDP to temporally-extended POMDP — agentic RL as a distinct
paradigm. The harness is the *environment specification*. **The model-vs-
harness boundary dissolves** when the whole stack (model + tools + memory +
termination policy) is co-optimized [Verified: 2026-05-10].

#### 7.5 Memory governance as a first-class concern

The frontier question is no longer "what to remember?" but "how do we audit,
prune, version, and govern agent memory across multi-agent systems?" *Memory
in the Age of AI Agents* (claimed arXiv:2512.13564) and the *Anatomy of
Agentic Memory* benchmark (claimed arXiv:2602.19320) consolidate the
four-tier taxonomy and identify governance as the open frontier.

#### 7.6 Whole-harness benchmarks

Terminal-Bench (Merrill 2026) measures *Claude Code, Codex CLI, Gemini CLI,
OpenHands* together on hard real-world tasks — not models in isolation. Eval
has caught up with the practitioner reality that the harness is the binding
constraint [Verified: 2026-05-10].

#### 7.7 The behaviour-fitness gap (Böckeler)

The biggest unsolved problem: no robust pre-merge proof that "this PR does
what the issue said it should." The Maintainability tier is solved (linters,
type checkers); Architecture Fitness is partial (ArchUnit-style tooling
exists but isn't LLM-friendly); Behaviour is **open**. AI code review is
the partial answer in production; mathematically grounded approaches (formal
specs, refinement types, contract-driven testing) remain niche.

---

### 8. Failure-Mode Taxonomy

Synthesized from MAST (Cemri 2025), Lin et al. 2025 (Agent Hallucinations,
arXiv:2509.18970), the 12-factor agents diagnostic, Anthropic's
long-running-agents post, and the user's internal `agent-supervision-patterns.md`
+ `agent-handoff-patterns.md`:

| Category                    | Failure Mode                             | Mitigation                                                       |
|-----------------------------|------------------------------------------|------------------------------------------------------------------|
| **System design**           | Under-specified roles                    | Explicit role/scope contracts (12-factor 10; user's [SUPER-001a]) |
|                             | No termination criteria                  | Step budgets + idle detection + completion contracts              |
|                             | Unbounded scope creep                    | Ground-rules block (user's [SUPER-002] typed entries)             |
| **Inter-agent misalignment**| Talking past each other                  | Single-agent-with-subagents over multi-agent debate (Cemri 2025)  |
|                             | Premise propagation                      | Premise verification before action; sensors                        |
| **Task verification**       | Premature victory ("done" too soon)      | Feature-list JSON gates; mandatory browser-automation testing      |
|                             | Hallucinated success                     | Self-verification loop with closed-loop sensor                     |
| **Context**                 | Context bloat / index overflow           | Progressive disclosure; observation masking; Skills > MEMORY.md    |
|                             | Lost in the middle                       | Important info at top/bottom; ranked retrieval                     |
|                             | Context rot (long-context decay)         | Compaction; sub-trajectory folding; tool-output offload            |
|                             | Stale memory                             | Explicit verification tags; pruning cadence (user's [META-005])    |
| **Tool**                    | Tool sprawl                              | Progressive disclosure; tool-search; fewer-orthogonal-tools rule   |
|                             | Wrong-tool selection                     | Description-driven routing; mode-scoped tool restrictions          |
|                             | Tool input drift                         | PreToolUse hook input rewriting; schema validation                 |
| **Loop**                    | Infinite loops                           | Step budgets; stuck-detection (OpenHands)                          |
|                             | Early stopping                           | Forced-continuation patterns ("Ralph Loop"); feature-list gates    |
| **Sandbox**                 | Too tight (incompatible tools)           | Documented escape hatches; `excludedCommands`                      |
|                             | Too loose (rm -rf ~)                     | OS-level isolation by default; deny-first precedence               |
|                             | MCP-server-sandbox interaction           | Active fault line; documented per-vendor                            |
| **Memory**                  | Cross-surface fragmentation              | Open-standard (Skills, MCP); standardized format                   |
|                             | Manual-discipline failure                | Automated triggers (memory-bank MCP variant)                       |
|                             | ADD-only accumulation (Mem0)             | Entity-linking; temporal invalidation (Zep)                        |
| **Hooks**                   | Cursor's no-hooks gambit                 | Architectural risk if model reliability is insufficient            |

The *most consequential cross-vendor finding*: **deterministic enforcement
gates** (Claude Code hooks, Codex approvals, OpenAI Guardrails) are the
binding constraint between "model says it did X" and "system verifies X
happened." Cursor's all-declarative posture is the field's most exposed bet.

---

### 9. Convergence and Divergence — What Every Harness Believes

**Strong convergence (2026 consensus):**

1. **Filesystem is foundational.** Every capable harness uses FS as state
   machine. *Trivedy: "arguably the most foundational harness primitive."*
2. **MCP is the tool-protocol winner.** Every framework except Aider ships
   MCP support.
3. **Progressive disclosure has displaced eager tool registration.** Loading
   47 tool schemas at startup is the antipattern.
4. **Sub-agents = context isolation, not orchestration.** Heavy multi-agent
   debate is empirically refuted (Cemri 2025).
5. **Stateless model + durable session.** Anthropic's brain/hands/session,
   12-factor's "stateless reducer," LangGraph Checkpointer, Inngest steps —
   same shape.
6. **Self-verification beats heuristics.** Browser automation, build loops,
   test runs — every serious long-running harness has a closed-loop check.
7. **The harness encodes opinions.** Every thought leader argues this:
   Trivedy ("agents should be more opinionated"), Schott (Flue), Osmani
   ("every line in AGENTS.md traceable to a specific failure"), Horthy ("own
   your prompts/control flow/context window").

**Strong divergence (vendor bets):**

| Bet                                        | Champion                      | If wrong, the harness fails because…                                                |
|--------------------------------------------|-------------------------------|--------------------------------------------------------------------------------------|
| Vector embeddings as primary retrieval     | Cursor, Augment               | Embedding drift / semantic-noise dominates; small-codebase re-rank loses to grep    |
| Repo-map graph rank over tree-sitter       | Aider                         | Cross-repo / multi-language scenarios where tree-sitter is incomplete                |
| OS-level sandboxing default                | Codex CLI                     | User experience cost (incompatible tools) outweighs safety benefit                   |
| Cloud VM only                              | Devin, Replit                 | Latency / data-residency / "agent never sees production code" friction               |
| Code-as-tool-call                          | OpenHands, Anthropic Python   | Schema-validation guarantees lost; gating becomes harder                              |
| Event-sourced architecture                 | OpenHands                     | Operational complexity (event replay, eventual consistency) outweighs architectural cleanliness |
| Declarative-rules-only enforcement         | Cursor                        | Model reliability proves insufficient; failures repeat without deterministic gates    |
| Static-config + auto-memory + skills hybrid| Anthropic Claude Code         | Index-overflow / cross-surface fragmentation (already documented in production)       |
| Markdown-first agent definition            | Flue                          | Type-safe agent specs (DSPy, Pydantic AI) become dominant                             |
| Harness-as-compiler                        | DSPy, GEPA, Meta-Harness      | Compilation cost dominates; manual harness engineering cheaper at the margin          |

---

## Outcome

**Status: RECOMMENDATION**

This document maps the 2026-05 state of the art across 20 canonical harness
components, 12+ shipping harnesses, ~35 academic papers, and the discourse
threads of 10+ thought leaders. It serves as the survey input to a *next-session
comparative analysis* against the workspace's own harness — that comparison
is intentionally not made here.

**Key findings, for the next session's comparative analysis:**

1. **The 20-component canonical taxonomy** in §2 is the comparison frame.
   The next session should map each of the workspace's harness elements
   (settings.json permissions, the 45 skills under `swift-institute/Skills/`,
   the 4-skill workflow pipeline `/handoff` → `/supervise` → `/reflect-session`
   → `/reflections-processing`, the auto-memory MEMORY.md system, the CI
   stack, the type-system-as-context-reduction tooling) against components 1–20.
2. **The user's existing routing guardrail** in `/Users/coen/Developer/CLAUDE.md`
   (skills-canonical, memory-narrow, propose-skill-update-before-saving-memory)
   independently re-derives Anthropic's official routing rule. The MEMORY.md
   24.4KB-cap overflow is therefore a *discipline failure*, not an
   architectural failure. The fix is enforcement of the existing guardrail,
   not architecture change.
3. **The workspace's most exposed component is `hooks`.** The current
   `~/.claude/settings.json` configures *zero hooks* — only deny/ask
   permission rules. Among the 5 axes hooks accomplish (determinism, safety,
   compaction, routing, telemetry), only *safety* is partially covered (via
   ask-rules). The other 4 axes — determinism (forced lint/test),
   compaction-shaping, routing, telemetry — have no harness-side enforcement.
   The next session should examine whether this is a deliberate bet (like
   Cursor's all-declarative posture) or an unintentional gap.
4. **The workspace's strongest component is `procedural memory via skills`.**
   45 skills with `[PREFIX-*]` requirement IDs, structured by [SKILL-CREATE-*]
   and [SKILL-LIFE-*], indexed routing in CLAUDE.md, regenerated symlinks via
   `Scripts/sync-skills.sh`. This is a more rigorous skill discipline than
   any production harness in the survey ships out-of-the-box.
5. **The workspace's harness has unique components not in the field's
   canonical taxonomy.** The five-layer architectural skill (`swift-institute`,
   [ARCH-LAYER-*]), the typed-throws-via-skills enforcement (`code-surface`),
   the meta-skills (`reflect-session`, `reflections-processing`,
   `corpus-meta-analysis`) that codify learning loops at the skill layer
   itself. These are *user-side* harness components — workflow harness
   for the user's engineering practice, layered on top of the agent harness.
   The two-layer framing is a contribution back to the discipline; the next
   session should make this explicit.
6. **The frontier (§7) suggests three forward bets** the comparative
   session should weigh:
   (a) Promote MEMORY.md remnants to skills + path-scoped rules (matches
       Anthropic + OpenAI explicit guidance and the user's own guardrail).
   (b) Add a hooks layer for determinism/compaction/telemetry — at minimum a
       Stop hook + a PreToolUse hook for forced linting on Swift edits.
   (c) Adopt OpenTelemetry GenAI semconv for whole-harness observability
       (Datadog v1.37 + Grafana support is shipping; the schema is stable
       enough to commit to).

**Open questions for the comparative session (pre-empted, not answered here):**

- Is the workspace's auto-memory truly a *discipline failure* or are there
  classes of entries that legitimately don't fit either skills or
  path-scoped rules? Triage MEMORY.md entry-by-entry to find out.
- Does the workspace want to invest in a hooks layer, or take the Cursor
  bet (all-declarative)? The user's `feedback_no_regex_evasion_*` and
  `feedback_no_toggle_bool_rule` memories suggest hook-shaped enforcement
  has been considered and case-by-case rejected.
- How does the workspace's two-layer harness (workflow harness on top of
  agent harness) compare to the field's most-mature multi-layer designs
  (Lopopolo's six-layer ops-stack, OpenHands' service-on-event-stream)?
- Is the deferred Claude Code Swift rewrite (`claude-code-swift-rewrite-feasibility.md`,
  DEFERRED 2026-04-30) a viable forward path given the field's harness-as-
  compiler frontier, or does it make more sense to invest in the harness-side
  configurations against the existing Claude Code runtime?

**Followups (per [RES-027]):**

The above open questions are *direction* items, not premise items. The
*premise* items in this document — empirical claims about specific
production systems — are tagged `[Verified: 2026-05-10]` against primary
sources. The comparative session is the extant follow-up; no new experiment
package is required at this stage.

## References

Organized by section. Where multiple sources support a claim, only the
canonical citation is given. All `[Verified: 2026-05-10]` claims trace to a
URL or arXiv ID below; primary sources fetched 2026-05-10 unless noted.

### Foundations and discourse

- Trivedy, V. (2026-03-10). *The Anatomy of an Agent Harness.* LangChain Blog. https://www.langchain.com/blog/the-anatomy-of-an-agent-harness
- Anthropic. (2024-12). *Building Effective Agents.* https://www.anthropic.com/research/building-effective-agents
- Anthropic. (2025-09-29). *Effective context engineering for AI agents.* https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic. (2025-11-26). *Effective harnesses for long-running agents.* https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic. (2026-04-08). *Scaling Managed Agents: Decoupling the brain from the hands.* https://www.anthropic.com/engineering/managed-agents
- Böckeler, B. (2026-04-02). *Harness engineering for coding agent users.* martinfowler.com. https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html
- Horthy, D. *12-Factor Agents.* https://github.com/humanlayer/12-factor-agents
- HumanLayer. *Skill Issue: Harness Engineering for Coding Agents.* https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents
- Schott, F. (2026-05-01). *Flue announcement.* https://x.com/FredKSchott/status/2050274923852210397
- Karpathy, A. (2025-06-17). *Software Is Changing (Again) — Software 3.0.* YC AI Startup School.
- Lopopolo, R. (2026-04-07). *Extreme Harness Engineering for Token Billionaires.* Latent Space. https://www.latent.space/p/harness-eng
- OpenAI. *Harness engineering: leveraging Codex in an agent-first world.* https://openai.com/index/harness-engineering/
- Yan, E. *Patterns for Building LLM-based Systems & Products.* https://eugeneyan.com/writing/llm-patterns/
- Husain, H. (2026-03). *Evals Skills for Coding Agents.* https://hamel.dev/blog/posts/evals-skills/
- Willison, S. *Agentic Engineering Patterns.* https://simonwillison.net/guides/agentic-engineering-patterns/
- Osmani, A. *Agent Harness Engineering.* https://addyosmani.com/blog/agent-harness-engineering/
- *awesome-harness-engineering.* https://github.com/ai-boost/awesome-harness-engineering

### Academic foundations

- Yao, S., et al. (2022). *ReAct: Synergizing Reasoning and Acting in Language Models.* arXiv:2210.03629.
- Wei, J., et al. (2022). *Chain-of-Thought Prompting.* arXiv:2201.11903.
- Wang, X., et al. (2022). *Self-Consistency.* arXiv:2203.11171.
- Yao, S., et al. (2023). *Tree of Thoughts.* arXiv:2305.10601.
- Shinn, N., et al. (2023). *Reflexion: Language Agents with Verbal Reinforcement Learning.* arXiv:2303.11366.
- Schick, T., et al. (2023). *Toolformer.* arXiv:2302.04761.
- Wang, G., et al. (2023). *Voyager.* arXiv:2305.16291.
- Park, J., et al. (2023). *Generative Agents.* arXiv:2304.03442.
- Sumers, T., et al. (2023). *Cognitive Architectures for Language Agents (CoALA).* arXiv:2309.02427.
- Packer, C., et al. (2023). *MemGPT.* arXiv:2310.08560.
- Wu, Q., et al. (2023). *AutoGen.* arXiv:2308.08155.
- Hong, S., et al. (2023). *MetaGPT.* arXiv:2308.00352.
- Li, G., et al. (2023). *CAMEL.* arXiv:2303.17760.
- Qian, C., et al. (2023). *ChatDev.* arXiv:2307.07924.
- Du, Y., et al. (2023). *Multiagent Debate.* arXiv:2305.14325.
- Liu, N., et al. (2023). *Lost in the Middle.* arXiv:2307.03172.
- Hsieh, C., et al. (2024). *RULER.* arXiv:2404.06654.
- Shaham, U., et al. (2023). *ZeroSCROLLS.* arXiv:2305.14196.
- Hong, K., et al. (2025). *Context Rot* (Chroma).
- Li, Z., et al. (2024). *Long Context vs RAG for LLMs.* arXiv:2501.01880.
- Lindenbauer, P., et al. (2025). *The Complexity Trap: Simple Observation Masking.* arXiv:2508.21433.
- Sun, W., et al. (2025). *Scaling Long-Horizon LLM Agent via Context-Folding.* arXiv:2510.11967.
- Cao, Y., et al. (2026). *Coding Agents are Effective Long-Context Processors.* arXiv:2603.20432.
- Jimenez, C., et al. (2023). *SWE-bench.* arXiv:2310.06770.
- Yang, J., et al. (2024). *SWE-agent: Agent-Computer Interfaces.* arXiv:2405.15793.
- Wang, X., et al. (2024). *Executable Code Actions Elicit Better LLM Agents (CodeAct).* arXiv:2402.01030.
- Liu, X., et al. (2023). *AgentBench.* arXiv:2308.03688.
- Ma, C., et al. (2024). *AgentBoard.* arXiv:2401.13178.
- Merrill, A., et al. (2026). *Terminal-Bench.* arXiv:2601.11868.
- Madaan, A., et al. (2023). *Self-Refine.* arXiv:2303.17651.
- Lightman, H., et al. (2023). *Let's Verify Step by Step (PRM).* arXiv:2305.20050.
- Yuan, W., et al. (2024). *Self-Rewarding Language Models.* arXiv:2401.10020.
- Hosseini, A., et al. (2024). *V-STaR.* arXiv:2402.06457.
- Zelikman, E., et al. (2022). *STaR.* arXiv:2203.14465.
- Khattab, O., et al. (2023). *DSPy.* arXiv:2310.03714.
- DSPy GEPA. (2025-07). arXiv:2507.19457.
- Lee, S., et al. (2026). *Meta-Harness.* arXiv:2603.28052.
- Lin, Y., et al. (2026). *Agentic Harness Engineering: Observability-Driven Automatic Evolution.* arXiv:2604.25850.
- Zhang, R., et al. (2025). *The Landscape of Agentic Reinforcement Learning for LLMs.* arXiv:2509.02547.
- Cemri, M., et al. (2025). *Why Do Multi-Agent LLM Systems Fail?* arXiv:2503.13657.
- Lin, J., et al. (2025). *LLM-based Agents Suffer from Hallucinations.* arXiv:2509.18970.
- AgentPRM (WWW 2026). arXiv:2511.08325.

### Production harness primary docs

- Claude Code documentation. https://code.claude.com/docs/en/
  - Skills: https://code.claude.com/docs/en/skills
  - Hooks: https://code.claude.com/docs/en/hooks
  - MCP: https://code.claude.com/docs/en/mcp
  - Sub-agents: https://code.claude.com/docs/en/sub-agents
  - Memory: https://code.claude.com/docs/en/memory
  - Permissions: https://code.claude.com/docs/en/permissions
  - Sandboxing: https://code.claude.com/docs/en/sandboxing
  - Agent SDK: https://code.claude.com/docs/en/agent-sdk/overview
  - Monitoring: https://code.claude.com/docs/en/monitoring-usage
- Anthropic. *Equipping agents for the real world with Agent Skills.* https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- Anthropic. *Memory tool docs.* https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool
- Anthropic. *Skill best practices.* https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Anthropic. *Model Spec Midtraining (Apr 2026).* https://alignment.anthropic.com/2026/msm/
- Cursor. *Documentation.* https://cursor.com/docs ; https://cursor.com/docs/rules
- Aider. https://aider.chat/docs/
- Cline. https://docs.cline.bot/
- Roo Code. https://docs.roocode.com/
- Codex. https://developers.openai.com/codex/ ; AGENTS.md, sandboxing, approvals.
- Cognition. *Devin 2.2.* https://cognition.ai/blog/introducing-devin-2-2
- Cognition. *SWE-1.5.* https://cognition.ai/blog/swe-1-5
- Cognition. *Don't Build Multi-Agents.* https://cognition.ai/blog/dont-build-multi-agents
- Cognition. *SWE-bench Technical Report.* https://cognition.ai/blog/swe-bench-technical-report
- OpenHands. https://docs.openhands.dev/ ; ICLR paper https://openreview.net/forum?id=OJd3ayDDoF
- Continue. https://docs.continue.dev/
- Sourcegraph Cody. https://sourcegraph.com/docs/cody
- Replit Agent. https://docs.replit.com/replitai/agent
- Warp. https://docs.warp.dev/agents/agent-mode
- Zed. https://zed.dev/docs/ai/agent-panel
- Augment. https://www.augmentcode.com/agent

### Frameworks / SDKs

- LangGraph. https://github.com/langchain-ai/langgraph
- deepagents. https://github.com/langchain-ai/deepagents
- CrewAI. https://github.com/crewAIInc/crewAI
- OpenAI Agents SDK. https://github.com/openai/openai-agents-python ; https://openai.github.io/openai-agents-python/
- Claude Agent SDK. https://github.com/anthropics/claude-agent-sdk-python
- Microsoft AutoGen. https://github.com/microsoft/autogen
- Microsoft Agent Framework (MAF). https://github.com/microsoft/agent-framework
- Pydantic AI. https://github.com/pydantic/pydantic-ai
- Mastra. https://mastra.ai
- Inngest AgentKit. https://agentkit.inngest.com
- Vercel AI SDK. https://ai-sdk.dev/
- Flue. https://github.com/withastro/flue
- DSPy. https://github.com/stanfordnlp/dspy ; GEPA: https://dspy.ai/api/optimizers/GEPA/overview/
- Letta. https://github.com/letta-ai/letta ; *Agent Memory* https://www.letta.com/blog/agent-memory
- Composio. https://composio.dev

### Memory architectures

- Mem0 paper. arXiv:2504.19413. https://arxiv.org/abs/2504.19413
- Zep. https://help.getzep.com/concepts
- LangMem. https://langchain-ai.github.io/langmem/concepts/conceptual_guide/
- Cognee. https://www.cognee.ai/
- Cline Memory Bank. https://docs.cline.bot/features/memory-bank
- Codex Memories. https://developers.openai.com/codex/memories
- GitHub claude-code issue #23544 (disable auto-memory).
- GitHub claude-code issue #34556 (59 compactions, built our own).
- Milvus blog. *Claude Code Memory System Explained.* https://milvus.io/blog/claude-code-memory-memsearch.md

### Sandboxing / Observability

- E2B Firecracker microVMs. https://e2b.dev/blog/firecracker-vs-qemu
- Daytona vs Modal comparison. https://northflank.com/blog/daytona-vs-modal
- AI Agent Sandboxes (microVM survey). https://emirb.github.io/blog/microvm-2026/
- OpenTelemetry GenAI Agent Spans. https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/
- LangSmith vs Arize vs Braintrust comparison. https://anudeepsri.medium.com/langsmith-vs-arize-vs-braintrust-e397e4728a76
- agent-replay. https://github.com/clay-good/agent-replay
- *Deterministic Replay for AI Agents.* https://tianpan.co/blog/2026-04-12-deterministic-replay-debugging-non-deterministic-ai-agents

### Internal corpus (Swift Institute)

- `agent-handoff-patterns.md` — handoff progressive-capture model, SBAR template
- `agent-supervision-patterns.md` — seven-axis supervision framework, ground-rules block
- `agent-workflow-skill-consistency-audit.md` (2026-04-15) — 26-finding audit, 25 resolved
- `ai-context-reduction-via-type-system-tooling.md` — symbol-graph API discovery, Phase 1 shipped
- `claude-code-swift-rewrite-feasibility.md` (DEFERRED 2026-04-30) — 8-subsystem mapping
- `multi-repo-automation-design-patterns.md` — state-axis enumeration, stub
