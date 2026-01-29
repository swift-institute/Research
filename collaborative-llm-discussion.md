# Collaborative LLM Discussion Workflow

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
tier: 2
---
-->

## Context

A common workflow involves collaborative design discussions between Claude Code and ChatGPT:

1. Export a Swift package using `package-export` skill
2. Manually paste to ChatGPT
3. Ask ChatGPT to "enter a collaborative discussion with Claude"
4. Manually copy ChatGPT's response back to Claude Code
5. Iterate until convergence on a plan

**Goal**: Design a skill that structures this workflow and explore automation to reduce/eliminate manual passing.

**Trigger**: Investigation into tooling workflow automation.

## Question

What is the optimal structure for a collaborative discussion skill, and how can the manual clipboard passing be reduced or eliminated?

---

## Analysis

### Current Workflow Pain Points

| Step | Manual Action | Time Cost |
|------|---------------|-----------|
| Export package | Invoke skill | Low (automated) |
| Copy export to clipboard | Manual | Low |
| Open ChatGPT, paste | Manual | Medium |
| Write collaboration prompt | Manual | Medium |
| Copy ChatGPT response | Manual | Medium |
| Paste back to Claude | Manual | Medium |
| Repeat N times | Manual × N | High |

**Total overhead**: ~2-5 minutes per round-trip, multiplied by 3-10 iterations typical for convergence.

---

## Option A: Manual Workflow with Structured Prompts

**Description**: A skill that provides structured prompts and templates but requires manual copy-paste.

**Components**:
1. Standard "opening prompt" for ChatGPT establishing collaboration protocol
2. Standard "response format" for structured handoffs
3. Convergence checklist
4. Guidance on when discussion is complete

**ChatGPT Opening Prompt Template**:
```
You are entering a collaborative discussion with Claude (Anthropic).
The goal is to converge on a plan for: {topic}

Protocol:
- Be cooperative where possible, critical where necessary
- Address ALL issues before declaring convergence
- Structure responses with: AGREEMENTS, CONCERNS, PROPOSALS, QUESTIONS
- When fully aligned, state: "CONVERGED: {summary}"

Context:
{exported package or document}

Claude's opening position:
{Claude's analysis}
```

**Handoff Format**:
```
## Round {N} - {Claude|ChatGPT}

### Agreements
- {points of consensus}

### Concerns
- {issues with other party's proposals}

### Proposals
- {suggested changes or approaches}

### Questions
- {clarifications needed}

### Status: {ONGOING | CONVERGED}
```

**Advantages**:
- No external dependencies
- Works with ChatGPT web interface (free tier)
- No API costs
- Human oversight at every step

**Disadvantages**:
- High manual effort
- Error-prone (copy mistakes, context truncation)
- Slow iteration

---

## Option B: Clipboard-Assisted Semi-Automation

**Description**: Use macOS clipboard tools (`pbcopy`/`pbpaste`) with Claude Code hooks to streamline handoffs.

**Architecture**:
```
Claude Code
    ↓ (PostToolUse hook on Write)
  /tmp/{session}-chatgpt-input.txt → pbcopy
    ↓ (manual paste to ChatGPT)
  ChatGPT Web
    ↓ (manual copy response)
  pbpaste → /tmp/{session}-chatgpt-response.txt
    ↓ (hook notifies Claude)
  Claude Code reads response
```

**Implementation**:
1. **Export hook**: After exporting, automatically copy to clipboard
2. **File watcher**: Monitor a "drop folder" for ChatGPT responses
3. **Notification**: Alert user when clipboard is ready / response detected

**Hook example** (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": { "tool_name": "Write", "path": "/tmp/*-chatgpt-input.txt" },
        "command": "cat $TOOL_OUTPUT_PATH | pbcopy && osascript -e 'display notification \"Ready for ChatGPT\" with title \"Claude\"'"
      }
    ]
  }
}
```

**Advantages**:
- Reduces friction significantly
- Maintains human oversight
- No API costs
- Works with free ChatGPT

**Disadvantages**:
- macOS-specific (pbcopy/pbpaste)
- Still requires manual ChatGPT interaction
- File watcher adds complexity

---

## Option C: API-Based Full Automation

**Description**: Use both Claude API and OpenAI API programmatically to automate the entire conversation.

**Architecture**:
```
Orchestrator Script (Python)
    ├── Anthropic Client (Claude)
    └── OpenAI Client (ChatGPT/GPT-4)

Loop:
    1. Claude generates position/analysis
    2. Script sends to GPT-4 with collaboration prompt
    3. GPT-4 responds
    4. Script sends response back to Claude
    5. Check for CONVERGED status
    6. Repeat until converged or max rounds
```

**Implementation** (Python sketch):
```python
import anthropic
import openai

def collaborative_discussion(topic: str, context: str, max_rounds: int = 10):
    claude = anthropic.Anthropic()
    gpt = openai.OpenAI()

    history = []

    # Claude's opening
    claude_response = claude.messages.create(
        model="claude-sonnet-4-20250514",
        messages=[{
            "role": "user",
            "content": f"Analyze this for collaborative discussion:\n{context}"
        }]
    )
    history.append(("Claude", claude_response.content[0].text))

    for round in range(max_rounds):
        # GPT-4's turn
        gpt_response = gpt.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": COLLABORATION_SYSTEM_PROMPT},
                *format_history(history)
            ]
        )
        gpt_text = gpt_response.choices[0].message.content
        history.append(("GPT-4", gpt_text))

        if "CONVERGED:" in gpt_text:
            return extract_convergence(history)

        # Claude's turn
        claude_response = claude.messages.create(
            model="claude-sonnet-4-20250514",
            messages=format_history_for_claude(history)
        )
        claude_text = claude_response.content[0].text
        history.append(("Claude", claude_text))

        if "CONVERGED:" in claude_text:
            return extract_convergence(history)

    return {"status": "max_rounds", "history": history}
```

**Cost Estimate** (per discussion):
| Model | Tokens/Round | Rounds | Cost |
|-------|-------------|--------|------|
| Claude Sonnet | ~4K in + 2K out | 5 | ~$0.09 |
| GPT-4o | ~4K in + 2K out | 5 | ~$0.05 |
| **Total** | | | **~$0.14** |

**Advantages**:
- Fully automated
- Fast iteration (seconds per round vs minutes)
- Consistent formatting
- Transcript automatically captured

**Disadvantages**:
- Requires API keys for both services
- Costs money (~$0.14 per discussion)
- Loses human oversight during discussion
- Complex setup

---

## Option D: AutoGen Multi-Agent Framework

**Description**: Use Microsoft's AutoGen framework which natively supports multi-model conversations.

**Architecture**:
```python
from autogen import AssistantAgent, UserProxyAgent

claude_agent = AssistantAgent(
    name="Claude",
    llm_config={"config_list": [{"model": "claude-sonnet-4", "api_type": "anthropic"}]}
)

gpt_agent = AssistantAgent(
    name="GPT4",
    llm_config={"config_list": [{"model": "gpt-4o", "api_type": "openai"}]}
)

# AutoGen handles the conversation orchestration
groupchat = GroupChat(agents=[claude_agent, gpt_agent], messages=[])
manager = GroupChatManager(groupchat=groupchat)
```

**Advantages**:
- Production-grade orchestration
- Built-in conversation management
- Supports human-in-the-loop
- Handles retries, errors gracefully
- Can mix local and cloud models

**Disadvantages**:
- Heavy dependency (AutoGen framework)
- Steeper learning curve
- May be overkill for simple discussions
- Still requires API keys

---

## Option E: Hybrid - Skill + Optional Automation

**Description**: A skill that supports both manual and automated modes, allowing the user to choose based on context.

**Skill Structure**:
```yaml
---
name: collaborative-discussion
description: |
  Facilitate collaborative discussions between Claude and ChatGPT.
  Apply when converging on plans, reviewing designs, or debating approaches.
---
```

**Modes**:
1. **Manual mode** (default): Structured prompts, human copy-paste
2. **Clipboard mode**: Hooks assist with copy, user pastes
3. **Auto mode**: Full API automation (requires setup)

**Invocation**:
```
"start collaborative discussion about {topic}"          → manual mode
"start collaborative discussion about {topic} --auto"   → automated mode
```

**Advantages**:
- Flexibility for different contexts
- Low barrier to entry (manual works immediately)
- Progressive enhancement path
- User controls automation level

**Disadvantages**:
- More complex skill to maintain
- Documentation overhead for multiple modes

---

## Comparison

| Criterion | A: Manual | B: Clipboard | C: API Auto | D: AutoGen | E: Hybrid |
|-----------|-----------|--------------|-------------|------------|-----------|
| Setup complexity | None | Low | Medium | High | Medium |
| Per-use effort | High | Medium | None | None | Variable |
| API costs | None | None | ~$0.14 | ~$0.14 | Optional |
| Human oversight | Full | Full | None | Optional | Configurable |
| Speed | Slow | Medium | Fast | Fast | Variable |
| Dependencies | None | macOS | APIs | Framework | APIs (optional) |
| Works with free ChatGPT | Yes | Yes | No | No | Partial |

---

## Prior Art Survey

### Multi-Agent Debate Research

The [Multi-Agent Debate (MAD) framework](https://github.com/Skytliang/Multi-Agents-Debate) explores leveraging collaboration among multiple LLM agents, guided by the principle that "truth emerges from the clash of adverse ideas."

Key findings from [ICLR 2025 research](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/):
- Current MAD methods fail to consistently outperform simpler single-agent strategies
- Effectiveness improves with more rounds of debate
- Sparse communication topologies can be more effective than dense ones

### AutoGen Framework

[Microsoft AutoGen](https://github.com/microsoft/autogen) provides a production-grade multi-agent conversation framework supporting multiple LLM backends including Claude and GPT-4.

### Model Context Protocol (MCP)

[MCP](https://modelcontextprotocol.io/) provides a standardized bridge between AI applications. OpenAI adopted MCP in March 2025. However, MCP is designed for tool/data integration, not LLM-to-LLM conversation orchestration.

---

## Constraints

1. **ChatGPT web interface is primary target** — Many users don't have API access or want to avoid costs
2. **Must work within Claude Code** — This is a skill, not a standalone tool
3. **Human oversight is valuable** — Users should be able to intervene/redirect
4. **Convergence detection** — Need clear criteria for when discussion is complete

---

## Outcome

**Status**: RECOMMENDATION

### Recommended Approach: Option E (Hybrid) with Option A as baseline

**Phase 1: Manual Mode Skill** (implement now)
- Structured collaboration protocol
- Handoff format templates
- Convergence checklist
- Works immediately with no setup

**Phase 2: Clipboard Assistance** (implement if manual mode is used frequently)
- PostToolUse hook for auto-copy
- Notification when ready
- macOS-specific but significant friction reduction

**Phase 3: API Automation** (implement if demand exists)
- Standalone Python script callable from skill
- Optional, requires user to provide API keys
- Falls back to manual mode if keys unavailable

### Collaboration Protocol Design

The skill should establish a structured protocol optimized for convergence:

**Round Structure**:
```
## Round {N} - {Participant}

### Position
{Current stance on the topic}

### Agreements
{Points where we align with the other party}

### Concerns
{Issues with the other party's proposals}

### Proposals
{Concrete suggestions for resolution}

### Questions
{Clarifications needed before proceeding}

### Status: {EXPLORING | NARROWING | NEAR_CONSENSUS | CONVERGED}
```

**Status Progression**:
- `EXPLORING`: Initial positions, many open questions
- `NARROWING`: Key issues identified, working toward resolution
- `NEAR_CONSENSUS`: Minor details remain
- `CONVERGED`: Full agreement reached

**Convergence Criteria**:
1. Both parties mark status as `CONVERGED`
2. No items in Concerns section
3. No items in Questions section
4. Agreement summary matches

### Opening Prompt for ChatGPT

```
You are entering a collaborative design discussion with Claude (Anthropic).

## Protocol
- Be COOPERATIVE where possible — seek common ground
- Be CRITICAL where necessary — challenge weak reasoning
- Address ALL issues before declaring convergence
- Use the structured format below for responses

## Your Role
You bring the perspective of {GPT's strengths: broad knowledge, different training data}.
Claude brings the perspective of {Claude's strengths: code analysis, Swift expertise}.

## Goal
Converge on a plan/decision for: {topic}

## Response Format
Use this exact structure:

### Position
{Your current stance}

### Agreements
{Where you align with Claude}

### Concerns
{Issues with Claude's proposals}

### Proposals
{Your suggestions}

### Questions
{Clarifications needed}

### Status: {EXPLORING | NARROWING | NEAR_CONSENSUS | CONVERGED}

---

## Context
{exported package or document}

## Claude's Opening Position
{Claude's analysis}
```

---

## Implementation Notes

### Skill ID Prefix

Use `[COLLAB-*]` for requirement IDs:
- `[COLLAB-001]` Protocol establishment
- `[COLLAB-002]` Handoff format
- `[COLLAB-003]` Convergence detection
- `[COLLAB-004]` Status progression
- `[COLLAB-005]` Automation modes (if implemented)

### File Outputs

| File | Purpose |
|------|---------|
| `/tmp/{topic}-round-{N}-claude.md` | Claude's response for copying to ChatGPT |
| `/tmp/{topic}-round-{N}-gpt.md` | Placeholder for pasting GPT's response |
| `/tmp/{topic}-transcript.md` | Full conversation history |
| `/tmp/{topic}-convergence.md` | Final agreed plan |

### Claude Code Hook (Phase 2)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": {
          "tool_name": "Write",
          "path_pattern": "/tmp/*-round-*-claude.md"
        },
        "command": "cat \"$CLAUDE_TOOL_OUTPUT_PATH\" | pbcopy && osascript -e 'display notification \"Round ready - paste to ChatGPT\" with title \"Collaborative Discussion\"'"
      }
    ]
  }
}
```

---

## References

- [AutoGen Multi-Agent Framework](https://github.com/microsoft/autogen)
- [Multi-Agent Debate (MAD)](https://github.com/Skytliang/Multi-Agents-Debate)
- [ICLR 2025: Multi-LLM-Agents Debate](https://d2jud02ci9yv69.cloudfront.net/2025-04-28-mad-159/blog/mad/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
- [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat)
- [LLM-Enhanced Clipboard on macOS](https://medium.com/@mpuig/llm-enhanced-clipboard-on-macos-streamlining-your-writing-process-52efb2eb56dc)
