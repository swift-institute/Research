# Agent Handoff Prior Art Notes

**Date**: 2026-03-25
**Purpose**: Actionable patterns for agent-to-agent context handoff

---

## Domain Handoff Protocols

### Medical: SBAR

The dominant structured handoff in healthcare. Four fields:

| Field | Content | Agent Analogue |
|-------|---------|----------------|
| **S**ituation | Patient name, chief complaint, bed | Task identifier, current goal |
| **B**ackground | Diagnosis, history, hospital days | Decisions made, constraints discovered |
| **A**ssessment | Vitals, diagnostics, clinical state | Current state of implementation, test results |
| **R**ecommendation | Proposed action, urgency | Prioritized next steps |

Key finding: SBAR reduced sentinel events and was adopted by the Joint Commission after studies showed communication failures caused 30% of malpractice claims and 1700+ deaths over 5 years. Variants include ISBAR (adds Introduction) and SBAR+2 (adds Q&A at end).

Actionable pattern: **Fixed-field structured handoff with a mandatory recommendation field forces the outgoing party to commit to next steps, not just dump state.**

### Air Traffic Control: Handover-Takeover

ATC uses a three-phase protocol: (1) outgoing controller briefs traffic picture, (2) incoming controller reads back and confirms, (3) formal verbal acceptance of responsibility. The incoming controller must achieve "situation awareness" before accepting. No ambiguous ownership period exists.

Actionable pattern: **Explicit acceptance. Responsibility transfers at a discrete moment, not gradually. The receiving agent must confirm it has sufficient context before the handoff completes.**

### NASA Mars Exploration Rover

MER surface operations ran 24/7 across three shifts on Mars time. Teams used structured "situation reports" with rover state, command sequences in progress, anomalies, and constraints for the next planning cycle. The handoff was a document, not a conversation.

Actionable pattern: **Document-oriented handoff (not conversational replay). The outgoing shift writes a structured artifact; the incoming shift reads it cold.**

### Industrial/Process Operations (Honeywell, BP)

Shift handover in chemical plants and pipelines emphasizes: (1) abnormal conditions first, (2) changes made during shift, (3) pending actions with deadlines, (4) equipment status. BP's procedure (USPL-COW-490-002) mandates a physical walkthrough of the plant alongside the written handoff.

Actionable pattern: **Anomalies and deviations are always listed first, before routine state. What changed matters more than what stayed the same.**

---

## Multi-Agent LLM Patterns

### OpenAI Swarm (2024) / Agents SDK (2025)

Two primitives: Agents and Handoffs. A function returns another Agent to transfer control. Context transfer uses a `Result` object with three fields: `value`, `agent`, `context_variables`. Critical design choice: **conversation history persists across handoffs, but system prompt changes to the new agent's instructions.** Only the last handoff in a turn takes effect.

Actionable pattern: **Separate mutable state (context_variables dict) from conversation history. The new agent gets fresh instructions but shared conversational memory.**

### LangGraph (LangChain)

Models agents as a directed graph. Nodes are agents, edges define flow. All agents read from and write to a **central state object**. LangGraph manages state persistence and uses reducer logic to merge concurrent updates. This is fundamentally shared-memory, not message-passing.

Actionable pattern: **Shared state with typed reducers. Each agent contributes to a common state object rather than producing a handoff document. Enables parallel agent execution with deterministic merge.**

### CrewAI

Role-based model. Each agent has a role, goal, and tools. CrewAI manages handoffs between agents automatically based on task dependencies. The "crew" defines the execution plan, and agents are composed into sequential or parallel pipelines.

Actionable pattern: **Role + goal + tools as the agent identity triple. Handoff is implicit via task graph, not explicit function calls.**

### Google A2A Protocol (2025)

Agent-to-agent communication over HTTP + JSON-RPC. Agents discover capabilities, negotiate tasks, and collaborate. Built on web standards rather than framework-specific APIs.

Actionable pattern: **Capability advertisement. Before handoff, the receiving agent declares what it can handle. The sender matches task requirements to receiver capabilities.**

### Anthropic Agent SDK (2026)

Focused on safety-critical applications. Locked to Claude models. Lighter orchestration than LangGraph but deeper safety integration.

### Continuous Claude v3 (Community, 2025-2026)

The most developed community solution for Claude Code session continuity:

- **Continuity Ledgers**: Markdown files tracking session metadata, file claims, dirty flags, symbol index snapshots. Stored in `thoughts/ledgers/`.
- **Handoff YAML**: Token-efficient documents (~1/20th of raw context) containing: `decisions_made`, `blockers_identified`, `next_steps`, `context_lost`, `file_locations`.
- **Hook-driven lifecycle**: `PreCompact` hook fires before context compression to auto-generate handoff. `PostToolUse` indexes changes. `SessionEnd` triggers archival via daemon with BGE embeddings.
- **Agent isolation**: 32 specialized agents (scout, debug, kraken, plan, oracle) with isolated tool access. PostgreSQL-backed file claims enforce mutual exclusion.
- **TLDR 5-layer code compression**: AST -> CallGraph -> CFG -> DFG -> PDG. Compresses ~23K tokens to ~1.2K per file.

Actionable pattern: **Compound, don't compact. Extract learnings into structured artifacts before context is lost. Handoff documents are dramatically smaller than the context they replace.**

---

## Context Degradation Research

### Lost in the Middle (Liu et al., 2023/2024, TACL)

The foundational finding: LLM performance follows a U-shaped curve across context position. On multi-document QA with 20 documents:
- Document 1 (beginning): ~75% accuracy
- Document 10 (middle): ~55% accuracy
- Document 20 (end): ~72% accuracy

Root cause: Rotary Position Embedding (RoPE) introduces long-term decay that prioritizes beginning and end tokens. Attention weights sum to 1, so every added token dilutes attention available for relevant content.

### Context Length Alone Hurts (October 2025)

Even with 100% perfect retrieval of relevant information placed optimally, performance still degrades 13.9% to 85% as input length increases. **Length itself is the problem, not just position.**

### NoLiMa Benchmark (Adobe Research, February 2025)

When questions and target content share minimal lexical overlap (realistic queries), 11 of 12 models dropped below 50% of baseline performance at just 32K tokens.

### Claimed vs. Effective Context (RULER, NVIDIA, April 2024)

Claimed context lengths far exceed effective context lengths. GPT-4's claimed 128K context has only ~64K effective capacity.

### Chroma 2025 Study

Tested 18 frontier models (GPT-4.1, Claude Opus 4, Gemini 2.5). All showed performance degradation as input length increased. No model is immune.

### Actionable Thresholds

| Model Class | Degradation Onset | Severe Degradation |
|-------------|-------------------|--------------------|
| GPT-4-turbo | ~16K tokens | Claimed 128K, effective ~64K |
| Claude-3-sonnet | ~16K tokens | Middle positions worst |
| Llama-3.1-405B | ~32K tokens | Falls off sharply beyond |

### Proven Mitigations

1. **Position-aware placement**: Critical information at beginning or end, never middle.
2. **Context curation > context volume**: Irrelevant information can push accuracy below zero-context baselines. Less is more.
3. **Contextual retrieval** (Anthropic, Sept 2024): Adding 50-100 tokens of chunk-specific explanatory context reduces retrieval failures by 49%.
4. **Hybrid retrieval + reranking**: Semantic embeddings + BM25 lexical matching + reranking achieved 67% failure reduction.
5. **Prompt compression**: LLMLingua maintained quality while reducing latency 1.7-5.7x.

---

## Community Practices

### Claude Code Official Best Practices

From Anthropic's documentation (code.claude.com/docs/en/best-practices):

- **"Context window is the most important resource to manage."** Performance degrades as context fills.
- **Compact at 60% utilization, not 90%.** Early compaction preserves more signal.
- **Limit sessions to work expected to consume under 120K input tokens.**
- **`/clear` between unrelated tasks.** Accumulated irrelevant context actively hurts.
- **After two failed corrections, `/clear` and rewrite the prompt.** Polluted context from failed attempts degrades performance faster than starting fresh.
- **Use subagents for investigation.** They explore in isolated context, returning summaries without cluttering the main window.
- **CLAUDE.md should be short.** If too long, Claude ignores rules (lost-in-the-middle effect on instructions).

### Session Handoff Pattern (Community Consensus)

The community converged on a file-based handoff pattern:

1. Before session end, write a handoff file with: completed tasks, pending tasks, key decisions, blockers, relevant file paths with line numbers.
2. On session start, read the handoff file. Archive previous handoffs.
3. Keep handoff files small (conventions and active state, not full context dumps).

GitHub issue #11455 (anthropics/claude-code) documents this as a feature request with 12+ interactions. The requester implemented it manually with `.claude/next-session.md` and `.claude/session-history/` and reports "zero missed tasks or context loss."

### PreCompact Hook Pattern

Community members proposed (and implemented) a `PreCompact` hook that fires automatically when context compression triggers, creating an emergency snapshot before information is lost. This is complementary to Auto Memory (long-term) -- PreCompact captures the session-specific ephemeral state.

### Writer/Reviewer Pattern

Use separate Claude sessions for implementation and review. The reviewer session has clean context, free from implementation bias. This is the multi-agent equivalent of code review.

### Key Anti-Patterns

1. **Kitchen sink session**: Multiple unrelated tasks in one session. Fix: `/clear` between tasks.
2. **Correction spiral**: Repeated corrections pollute context with failed approaches. Fix: Fresh session after 2 failures.
3. **Bloated CLAUDE.md**: Instructions get lost in the middle. Fix: Ruthlessly prune.
4. **Infinite exploration**: Unscoped investigation fills context with file contents. Fix: Subagents or narrow scope.

---

## Synthesis: Patterns That Transfer

| Domain Pattern | Agent Handoff Application |
|----------------|--------------------------|
| SBAR fixed fields | Handoff document with mandatory sections: Situation, Decisions, State, Next Steps |
| ATC explicit acceptance | Receiving agent confirms context sufficiency before proceeding |
| NASA document-not-conversation | Write structured artifact, not conversational replay |
| Industrial anomalies-first | Lead with what changed, what broke, what deviates from plan |
| Swarm context_variables | Separate mutable state from conversation history |
| LangGraph shared state | Typed state object with reducers, not free-form markdown |
| Continuous Claude TLDR | Compress code context into layered summaries (AST -> dependencies -> flow) |
| Lost-in-the-middle | Place critical handoff information at document edges, not middle |
| 60% compaction threshold | Trigger handoff extraction well before context is exhausted |
