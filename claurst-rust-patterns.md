# Claurst: Rust Rewrite of Claude Code -- Implementation Pattern Analysis

Source: `github.com/Kuberwastaken/claurst`, branch `main`, `src-rust/` directory.

This document analyzes the architecture, decomposition, and implementation patterns
of the Claurst project -- a Rust port of the Claude Code CLI. The analysis is based
on direct reading of the source files as of 2026-04-01.

---

## 1. Workspace and Crate Structure

The workspace uses Cargo resolver v2 with 11 crates:

| Crate | Role | Key dependencies |
|-------|------|------------------|
| `cc-core` | Shared types, errors, config, permissions, history, memdir, system prompt, hooks, keybindings, constants | `thiserror`, `serde`, `dirs`, `tracing` |
| `cc-api` | Anthropic API client, streaming, SSE, message construction | `reqwest`, `tokio`, `serde_json` |
| `cc-tools` | Tool trait + all built-in tool implementations | `cc-core`, `cc-mcp`, `async-trait`, `walkdir` |
| `cc-query` | Agent loop, auto-compact, auto-dream, coordinator, cron | `cc-api`, `cc-core`, `cc-tools`, `tokio-util` |
| `cc-commands` | Slash command framework and all `/command` implementations | `cc-core`, `cc-plugins`, `async-trait` |
| `cc-plugins` | Plugin discovery, manifest parsing, hook registration | `cc-core`, `serde`, `tracing` |
| `cc-mcp` | Model Context Protocol server management | `cc-core` |
| `cc-tui` | Terminal UI (ratatui + crossterm) | `cc-core`, `cc-query` |
| `cc-bridge` | TypeScript/Node.js bridge (FFI layer for gradual migration) | `cc-core` |
| `cc-buddy` | Companion/buddy agent mode | `cc-core`, `cc-query` |
| `cc-cli` | Binary entrypoint, CLI argument parsing | all crates |

**Decomposition pattern**: The crates form a directed acyclic graph with `cc-core`
at the bottom. The dependency flow is `cc-cli -> cc-tui -> cc-query -> cc-tools -> cc-core`,
with `cc-api` as a sibling of `cc-tools` that `cc-query` also depends on. This is
a clean layered architecture where each crate has a single responsibility.

**Notable choice**: All of `cc-core` is defined as inline modules within a single
`lib.rs` file -- the `error`, `types`, `config`, `cost`, `permissions`, `history`,
`hooks`, `keybindings`, `constants`, `output_styles`, and `system_prompt` modules
are all declared inline. The `memdir` module is the one exception, split into its
own file. This "monolith core" approach keeps all shared types colocated and avoids
circular-dependency issues that would arise if they were separate crates, at the
cost of a very large `lib.rs` (the file is over 108KB / ~3000 lines).

**Workspace dependency management**: All third-party versions are pinned once in
`[workspace.dependencies]` and workspace crates reference them via
`cc-core = { path = "crates/core" }`. This is standard Cargo best practice but
worth noting: the workspace has 45+ third-party dependencies, reflecting the
breadth of the tool (HTTP, TUI, crypto, text processing, process management,
JSON Schema generation, etc.).

---

## 2. The Agent Query Loop

The agent loop lives in `cc-query/src/lib.rs` and is the central orchestration
mechanism. Its signature:

```rust
pub async fn run_query_loop(
    client: &cc_api::AnthropicClient,
    messages: &mut Vec<Message>,
    tools: &[Box<dyn Tool>],
    tool_ctx: &ToolContext,
    config: &QueryConfig,
    cost_tracker: Arc<CostTracker>,
    event_tx: Option<mpsc::UnboundedSender<QueryEvent>>,
    cancel_token: tokio_util::sync::CancellationToken,
) -> QueryOutcome
```

### Loop structure

The loop is a `loop {}` that increments a turn counter each iteration:

1. **Turn limit check**: If `turn > config.max_turns`, return `EndTurn`.
2. **Cancellation check**: Via `tokio_util::sync::CancellationToken`.
3. **Build API request**: Convert `Vec<Message>` to `Vec<ApiMessage>`, convert
   `Vec<Box<dyn Tool>>` to `Vec<ApiToolDefinition>`, assemble the system prompt.
4. **Stream the response**: Call `client.create_message_stream()` which returns
   a `tokio::sync::mpsc::UnboundedReceiver<StreamEvent>`. A `StreamAccumulator`
   collects events incrementally.
5. **Process stop reason**: Branch on `"end_turn"`, `"max_tokens"`, `"tool_use"`,
   `"stop_sequence"`, or unknown.
6. **Tool dispatch**: For `"tool_use"`, extract all `ContentBlock::ToolUse` blocks,
   execute them sequentially, fire pre/post hooks, collect results, append a
   `Message::user_blocks(result_blocks)` to the conversation, and `continue` the loop.

### Streaming architecture

The streaming design uses a channel-based fan-out pattern:

- `AnthropicClient::create_message_stream()` returns a receiver channel.
- A `ChannelStreamHandler` forwards `StreamEvent`s to an optional `event_tx`
  channel that the TUI consumes for rendering.
- The `StreamAccumulator` is a stateful accumulator that reassembles the full
  assistant message from incremental deltas, exposing `.finish()` which returns
  `(Message, UsageInfo, Option<String>)` -- the completed message, token counts,
  and stop reason.

The inner receive loop uses `tokio::select!` to race the cancellation token
against the next stream event, enabling cooperative cancellation mid-stream.

### Cost tracking

`Arc<CostTracker>` is threaded through the loop. After each API response,
`cost_tracker.add_usage(input, output, cache_creation, cache_read)` is called.
This is a shared atomic counter pattern -- `CostTracker` is likely implemented
with atomics or a mutex internally.

### Hook lifecycle

The loop fires hooks at three points:

- **PreToolUse**: Before each tool execution. If a hook returns `HookOutcome::Blocked(reason)`,
  the tool is skipped and an error result is returned to the model.
- **PostToolUse**: After each tool execution. Informational only (cannot block).
- **Stop**: When the model finishes its turn (`end_turn` or `stop_sequence`).

Hooks receive a `HookContext` struct with the event name, tool name/input/output,
error status, and session ID. The hook execution is `await`ed, meaning hooks are
async shell commands that receive event JSON on stdin.

### Auto-compact integration

After each turn (both `end_turn` and `tool_use`), the loop calls
`compact::auto_compact_if_needed()`. If compaction fires, the entire `messages`
vector is replaced with the compacted version, and a status event is emitted.
This is proactive -- it fires before the next API call would fail.

### Design observations

The loop is deliberately simple: it is a single async function, not a state machine
or actor. State is threaded through mutable references (`&mut Vec<Message>`) and
shared ownership (`Arc<CostTracker>`). The `QueryOutcome` enum captures all possible
terminal states. There is no retry logic in the loop itself -- retries are presumably
handled at the API client level or by the caller.

The `QueryEvent` enum provides a clean observation interface for the TUI without
coupling the loop to any rendering framework.

---

## 3. Memory Directory (Memdir) System

The memdir system in `cc-core/src/memdir.rs` implements persistent, file-based
memory across sessions. It mirrors the TypeScript `src/memdir/` module structure.

### Architecture

Memory files are markdown files with optional YAML frontmatter, stored in a
directory tree. The central index file is `MEMORY.md`.

**Type taxonomy**: Four canonical memory types modeled as an enum:

- `User` -- role, goals, preferences
- `Feedback` -- behavioral guidance
- `Project` -- ongoing work, goals, incidents
- `Reference` -- pointers to external information

**File metadata** (`MemoryFileMeta`): filename, absolute path, frontmatter fields
(`name`, `description`, `type`), and modification time. This struct enables
scanning without loading full file contents.

### Scanning and frontmatter parsing

`scan_memory_dir()` recursively walks the memory directory, collecting `.md` files
(excluding `MEMORY.md`), parsing frontmatter from the first 30 lines, sorting by
modification time (newest first), and capping at 200 files.

The frontmatter parser (`parse_frontmatter_quick`) is deliberately minimal --
it does not use a YAML library. It scans for `---` delimiters and extracts
`name:`, `description:`, and `type:` fields by string prefix matching. This avoids
a dependency on a YAML parser while handling the narrow subset of YAML that
memory files actually use.

### Path resolution

`auto_memory_path()` implements a three-tier resolution strategy:

1. `CLAUDE_COWORK_MEMORY_PATH_OVERRIDE` env var (full override)
2. `CLAUDE_CODE_REMOTE_MEMORY_DIR` + sanitized project root (remote mode)
3. `~/.claude/projects/<sanitized-root>/memory/` (default)

`is_auto_memory_enabled()` checks a priority chain: env vars for disabling,
`--bare` mode, remote mode without a memory dir, settings.json, then defaults to enabled.

### Index truncation

`MEMORY.md` is capped at 200 lines and 25KB. When either limit fires, the content
is truncated at a line boundary and a warning is appended instructing the model to
keep entries short and move detail into topic files. This is a clever self-regulating
mechanism -- the model sees the warning and adapts its memory management behavior.

### Relevance search

`find_relevant_memories_simple()` implements a lightweight TF-IDF-style keyword
scorer without an API call. Query words are matched against the name (weight 2.0),
description (weight 1.0), and filename (weight 0.5) of each memory file. Results
are sorted by score and capped. A more expensive Sonnet-based relevance query
lives in `cc-query`.

### Freshness tracking

Memory files get age annotations: "today", "yesterday", or "N days ago".
Memories older than 1 day receive a staleness caveat wrapped in `<system-reminder>`
tags, explicitly warning the model that "claims about code behavior or file:line
citations may be outdated." This is a robust pattern for preventing the model from
treating stale memory as ground truth.

---

## 4. System Prompt Construction

The system prompt assembly in `cc-core/src/system_prompt.rs` uses a two-zone
architecture split by a `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` marker:

### Zone 1: Cacheable (before boundary)

These sections are static or change rarely, making them eligible for Anthropic's
prompt caching:

1. **Attribution header** -- varies by prefix (CLI, SDK, Vertex, Bedrock, Remote)
2. **Core capabilities** -- tool descriptions, approach guidelines
3. **Tool use guidelines** -- prefer dedicated tools over bash equivalents
4. **Actions section** -- reversibility and blast radius considerations
5. **Safety guidelines** -- file protection, secret handling
6. **Cyber-risk instruction** -- security research boundaries
7. **Output style** -- enum-derived suffix (Concise, Formal, Learning, etc.)
8. **Coordinator mode** -- optional orchestrator instructions
9. **Custom system prompt** -- wrapped in `<custom_instructions>` tags

### Zone 2: Dynamic (after boundary)

These sections change per-turn or per-session:

10. **Working directory** -- wrapped in `<working_directory>` tags
11. **Memory injection** -- wrapped in `<memory>` tags
12. **Appended system prompt** -- raw text appended last

### Prefix detection

`SystemPromptPrefix::detect()` inspects environment variables to determine the
runtime context. The detection order is: Vertex (`ANTHROPIC_VERTEX_PROJECT_ID`) ->
Bedrock (`AWS_BEDROCK_MODEL_ID`) -> Remote (`CLAUDE_CODE_REMOTE`) ->
SDK (non-interactive) -> CLI (default). Each prefix variant has a distinct
attribution string.

### Section caching

A process-global `OnceLock<Mutex<HashMap<String, Option<String>>>>` caches
computed section content. `clear_system_prompt_sections()` flushes the cache
on `/clear` and `/compact`.

### Replace mode

When `replace_system_prompt` is true and a custom prompt is set, the entire
default prompt is skipped -- only the custom text plus the dynamic boundary marker
is emitted. This enables full prompt replacement for specialized use cases.

---

## 5. Context Compaction

The compaction system in `cc-query/src/compact.rs` implements automatic context
window management.

### Trigger logic

`should_auto_compact()` fires when `input_tokens >= 90%` of the model's context
window. Window sizes are hardcoded per model family:

- Claude 4 / Claude 3.5 models: 200,000 tokens
- Everything else: 100,000 tokens

### Compaction strategy

The strategy is simple and effective:

1. Keep the most recent `KEEP_RECENT_MESSAGES` (10) messages verbatim.
2. Summarize everything before those messages into a single compact summary.
3. Replace the conversation head with:
   - A `<compact-summary>` user message containing the summary
   - The preserved tail messages

The summary is generated via a single non-agentic API call (no tool loop) to
avoid recursive compaction. The summarization prompt instructs the model to
preserve "key decisions, code changes, findings, conclusions, constraints,
and ongoing task state."

### Circuit breaker

`AutoCompactState` tracks consecutive failures. After 3 consecutive failures,
the circuit breaker opens and auto-compact is disabled for the session. This
prevents infinite retry loops when the API is returning errors.

### Token warning states

Three states: `Ok` (plenty of space), `Warning` (within 20,000 tokens of limit),
`Critical` (at the auto-compact threshold). These drive UI indicators.

### Limitations

The compaction is lossy -- tool use blocks, thinking blocks, and structured content
in the summarized head are reduced to a text summary. The recent tail preserves
full fidelity. This is a reasonable trade-off: recent context matters more than
distant history, and the summary preserves the key decisions and findings.

---

## 6. Plugin and Hook Architecture

### Plugin system (`cc-plugins`)

The plugin system has four layers:

1. **Discovery** (`loader.rs`): Scans three locations for plugins:
   - `~/.claude/plugins/` (user-global)
   - `<project>/.claude/plugins/` (project-local)
   - Extra paths from CLI flags or settings

2. **Manifest parsing** (`manifest.rs`): Plugins are defined by `plugin.json`
   or `plugin.toml` manifests. A manifest declares:
   - Name, version, description, author
   - MCP servers to register
   - LSP servers to register
   - Hook entries (event matchers + shell commands)
   - Slash command definitions

3. **Registry** (`registry.rs`): `PluginRegistry` is a collection of
   `LoadedPlugin` instances with enable/disable state, error tracking, and
   diff computation for hot-reload.

4. **Hook registration** (`hooks.rs`): Plugin hooks are collected into a
   `HookRegistry` keyed by event kind, which the query loop consults.

### Hot reload

`reload_plugins()` loads a fresh registry, computes a `ReloadDiff` (added,
removed, updated plugins and error count), and replaces the old registry. The
`/reload-plugins` command formats a human-readable summary.

### Plugin installation

`install_plugin_from_path()` validates the source directory has a manifest,
parses it, and copies the entire directory to `~/.claude/plugins/<name>`.
This is a file-copy install, not a package manager.

### Hook execution in the query loop

Hooks are configured in `Config::hooks` as a `HashMap<HookEvent, Vec<HookEntry>>`.
Each `HookEntry` has a shell command, an optional tool name filter, and a
`blocking` flag. The hook receives a JSON `HookContext` on stdin containing:
event name, tool name/input/output, error status, and session ID.

For `PreToolUse` hooks with `blocking: true`, a non-zero exit code returns
`HookOutcome::Blocked(reason)`, which prevents the tool from executing and
sends an error result back to the model.

---

## 7. Auto-Dream / Background Processing

The auto-dream system in `cc-query/src/auto_dream.rs` implements automatic
memory consolidation as a background daemon.

### Gate architecture

Three gates are checked in cost-ascending order:

1. **Time gate** (cheapest -- one arithmetic check): Hours since
   `last_consolidated_at >= min_hours` (default 24). If never consolidated,
   the gate always passes.

2. **Session gate** (directory scan): Count conversation transcript files with
   `mtime > last_consolidated_at`. If count >= `min_sessions` (default 5),
   the gate passes. The scan is short-circuited as soon as the threshold is met.

3. **Lock gate** (file check): A `.consolidation_lock` file prevents concurrent
   consolidation. Locks older than 1 hour are treated as stale and ignored.
   This provides crash recovery without requiring a proper distributed lock.

### Consolidation state

`ConsolidationState` is a simple JSON file (`.consolidation_state.json`) containing
`last_consolidated_at` (Unix timestamp) and a reserved `lock_etag` field for
future distributed locking. State management is gracefully degrading -- parse
failures return the default state.

### Consolidation prompt

The consolidation prompt is a structured four-phase instruction for a forked
subagent:

1. **Orient**: `ls` the memory directory, read `MEMORY.md`, skim existing files
2. **Gather**: Search transcripts narrowly (grep, not full reads), find drifted memories
3. **Consolidate**: Write/update memory files, merge signal, convert relative
   dates, delete contradicted facts
4. **Prune and index**: Keep `MEMORY.md` under 200 lines / 25KB, resolve
   contradictions, remove stale pointers

The prompt explicitly constrains the subagent to read-only Bash commands,
preventing accidental writes during consolidation.

### Scan throttle

A 10-minute `SESSION_SCAN_INTERVAL_SECS` throttle prevents repeated directory
scans when the time gate passes but the session gate does not. This is a
pragmatic optimization for the common case where a user has an active session
but has not accumulated enough transcripts.

---

## 8. Tool Registry Pattern

### Trait-based dispatch

Every tool implements the `Tool` trait:

```rust
#[async_trait]
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn permission_level(&self) -> PermissionLevel;
    fn input_schema(&self) -> Value;
    async fn execute(&self, input: Value, ctx: &ToolContext) -> ToolResult;
    fn to_definition(&self) -> ToolDefinition { ... }
}
```

Tools are zero-sized structs (unit structs like `BashTool`, `FileReadTool`) that
implement this trait. The `all_tools()` function returns a `Vec<Box<dyn Tool>>`
constructed manually -- there is no registration macro or inventory system.

### Permission levels

Five levels form a hierarchy: `None`, `ReadOnly`, `Write`, `Execute`, `Dangerous`.
The `ToolContext::check_permission()` method delegates to a `PermissionHandler`
trait object, which can be `AutoPermissionHandler` (always allow based on mode)
or `InteractivePermissionHandler` (prompt the user).

### Shell state persistence

A notable pattern for the `BashTool`: shell state (cwd, environment variables)
persists across invocations via a process-global `DashMap<String, Arc<Mutex<ShellState>>>`
keyed by session ID. This solves the problem that each tool invocation is a
separate function call with no shared mutable state -- the `ToolContext` is
constructed fresh each time, but the shell state lives outside it in a static registry.

### Tool context

`ToolContext` carries the working directory, permission mode, permission handler,
cost tracker, session ID, non-interactive flag, MCP manager, and full config.
The `resolve_path()` method handles relative-to-absolute path resolution.

### Tool inventory

The built-in tool set comprises 33 tools across categories:

- **File operations**: Read, Edit, Write, Glob, Grep, NotebookEdit
- **Execution**: Bash, PowerShell, Sleep
- **Web**: WebFetch, WebSearch
- **Agent**: Tasks (Create/Get/Update/List/Stop/Output), SendMessage
- **Planning**: EnterPlanMode, ExitPlanMode, TodoWrite
- **MCP**: ListMcpResources, ReadMcpResource
- **Session**: EnterWorktree, ExitWorktree
- **Scheduling**: CronCreate, CronDelete, CronList
- **Meta**: ToolSearch, Brief, Config, Skill, AskUserQuestion

The `AgentTool` (sub-agent spawning) lives in `cc-query` rather than `cc-tools`
because it needs to call `run_query_loop` recursively, which would create a
circular dependency.

---

## 9. Command System

The slash command system in `cc-commands` mirrors the tool system but for user-facing
commands rather than model-facing tools.

### Trait

```rust
#[async_trait]
pub trait SlashCommand: Send + Sync {
    fn name(&self) -> &str;
    fn aliases(&self) -> Vec<&str>;
    fn description(&self) -> &str;
    fn help(&self) -> &str;
    fn hidden(&self) -> bool;
    async fn execute(&self, args: &str, ctx: &mut CommandContext) -> CommandResult;
}
```

### Result types

`CommandResult` is a rich enum: `Message` (display only), `UserMessage` (inject
into conversation), `ConfigChange`, `ClearConversation`, `SetMessages` (for
rewind), `ResumeSession`, `RenameSession`, `StartOAuthFlow`, `Exit`, `Silent`,
`Error`. This gives commands full control over side effects without coupling
to the REPL implementation.

### Command categories

Commands are grouped into 10 categories for help display: Conversation, Settings,
Usage & Cost, System, Auth & Permissions, Project, Integrations, Sessions & Remote,
AI & Thinking, Tools & Extras. There are approximately 60 slash commands in total.

### Plugin command adapters

Plugin-defined commands are wrapped in a `PluginSlashCommandAdapter` that delegates
to the plugin's command definition. The adapter pattern keeps the command registry
uniform regardless of whether a command is built-in or plugin-provided.

---

## 10. Patterns Valuable for Swift Agent Tooling

### Observation channel pattern

The `QueryEvent` + `mpsc::UnboundedSender` pattern cleanly decouples the agent
loop from rendering. The loop emits structured events (`ToolStart`, `ToolEnd`,
`TurnComplete`, `Status`, `Error`, `Stream`), and the TUI subscribes to these
events without the loop knowing anything about the display layer. In Swift, this
maps directly to `AsyncStream<QueryEvent, Never>` or a typed
`AsyncChannel<QueryEvent>` from the concurrency primitives.

### Circuit breaker for compaction

The `AutoCompactState` with consecutive failure tracking and a disabled flag
is a clean operational resilience pattern. Three failures in a row disable the
subsystem for the session rather than retrying indefinitely. This is particularly
relevant for any Swift agent tooling that calls external APIs -- the circuit
breaker prevents cascading failures.

### Gate-ordered cheapness

The auto-dream system's gate ordering (time check -> directory scan -> lock check)
is an excellent pattern for any background consolidation task. Checking the
cheapest gate first (one arithmetic comparison) avoids unnecessary I/O in the
common case where consolidation is not needed. This "fail fast, fail cheap"
ordering should be standard practice.

### Two-zone prompt caching

The `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` marker that splits the system prompt into
cacheable (static) and dynamic (per-turn) zones is directly applicable to any
system that uses Anthropic's prompt caching. The pattern is: assemble all
static sections first, emit the boundary marker, then assemble volatile sections.
The API client splits on the marker to determine cache eligibility.

### Trait-object tool registry with permission levels

The `Tool` trait + `PermissionLevel` enum + `ToolContext` pattern is a clean
architecture for tool dispatch in any agent system. The key insight is that
permission checking is a cross-cutting concern handled by the context, not by
individual tools. Tools declare what they need; the context decides whether to grant it.

In Swift, this maps to a protocol with associated types for input/output schemas
rather than `serde_json::Value`, which would give compile-time schema validation:

```swift
protocol Tool: Sendable {
    associatedtype Input: Decodable
    associatedtype Output: Encodable
    var name: String { get }
    var permissionLevel: Permission.Level { get }
    func execute(_ input: Input, context: Tool.Context) async throws(Tool.Error) -> Output
}
```

### Static shell state registry

The `SHELL_STATE_REGISTRY` pattern (a process-global `DashMap` keyed by session ID)
solves a real problem: tool invocations are stateless function calls, but shell
state (cwd, environment) must persist across invocations. In Swift, this maps to
an actor-isolated dictionary or a `Mutex<[Session.ID: Shell.State]>`.

### Memory freshness annotations

Wrapping stale memories in `<system-reminder>` tags with explicit staleness warnings
is a pattern that should be standard in any memory system. The model cannot do
date arithmetic reliably, so converting timestamps to "47 days ago" and adding
"verify against current code before asserting as fact" is a high-leverage prompt
engineering pattern.

### Self-regulating memory index

The `MEMORY.md` truncation mechanism with an in-band warning to the model
("Only part of it was loaded. Keep index entries to one line under ~200 chars")
creates a feedback loop where the model learns to maintain a compact index. This
is a pattern where operational constraints are communicated to the model as
instructions, enabling self-correction.

### Monolith core with peripheral crates

The "fat core" pattern (108KB `lib.rs` with all shared types inline) avoids the
Rust-specific problem of circular dependencies between small crates. In Swift's
module system, this maps to a single `Core` target that defines all shared types,
with separate targets for tools, query loop, commands, etc. The trade-off is
the same: co-location simplifies dependency management at the cost of a large
compilation unit.

### Consolidation as read-only subagent

The auto-dream system's constraint that the consolidation subagent is limited to
read-only operations is a safety pattern worth adopting. The consolidation prompt
explicitly restricts tool access, preventing the background agent from
accidentally modifying code or state. In a Swift implementation, this would be
enforced at the tool-context level by providing a restricted set of tools rather
than relying on prompt instructions alone.

---

## Summary

The Claurst codebase demonstrates a pragmatic Rust architecture for an LLM agent
system. The key structural decisions are:

1. **Layered crate DAG** with a fat shared-types core
2. **Single-function agent loop** with channel-based event fan-out
3. **Trait-object tool dispatch** with declarative permission levels
4. **Two-zone system prompt** for cache optimization
5. **Proactive context compaction** with circuit breaker resilience
6. **File-based persistent memory** with freshness-aware injection
7. **Background consolidation** with cost-ordered gating
8. **Plugin system** with manifest-based discovery and hot reload

The implementation is thorough and production-oriented, with comprehensive test
suites throughout. The patterns are directly applicable to building equivalent
infrastructure in Swift, with natural mappings to Swift concurrency, protocols
with associated types, and actor isolation.
