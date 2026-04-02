# Claude Code Architecture Analysis

Analysis of the Kuberwastaken/claurst specification documents, which reverse-engineer the Claude Code TypeScript source (~1,902 files, ~800K LOC) into detailed specification documents for a Rust port.

## Source Material

Eight specification documents from the claurst repository covering: overview and repo structure, index, core entry points and query system, tools system, components/agents/permissions, services/context/state, React hooks, and special systems (buddy, memory, keybindings, skills, voice, plugins).

---

## 1. Agent Loop Architecture

The query loop is the central nervous system of Claude Code. It lives in `query.ts` (69KB) and `QueryEngine.ts` (46KB). The architecture is an async generator that yields events to the UI while driving a multi-turn tool-execution loop.

### Core Loop Structure

The loop is implemented as `async function* query()` returning an `AsyncGenerator`. Each iteration:

1. Yields a `stream_request_start` event (so the UI can show a spinner).
2. Builds the API request: system prompt, message history, available tools, token budget constraints.
3. Applies microcompaction (trimming tool results in-place to reduce context size).
4. Runs autocompaction if the context window is getting full.
5. Calls the Claude API with streaming.
6. Executes any tool calls from the response.
7. Feeds tool results back as user messages for the next iteration.
8. Runs stop hooks at the end of each turn.
9. Checks continuation conditions: no more tool use, budget exceeded, max turns, or stop hook blocked.

The generator pattern is a significant design choice. Rather than a callback-based or event-emitter architecture, the async generator allows the UI layer to pull events at its own pace while the loop maintains its own state. This is a clean separation that makes the loop testable independent of the UI.

### State Management

The loop maintains a `State` object tracking:

- `messages`: the full conversation history (mutable across iterations)
- `autoCompactTracking`: state for the autocompaction system
- `maxOutputTokensRecoveryCount`: retry counter for max_output_tokens errors
- `hasAttemptedReactiveCompact`: one-shot flag for reactive compaction
- `turnCount`: monotonically increasing turn counter
- `transition`: why the previous iteration continued (for diagnostics)
- `stopHookActive`: whether a stop hook is currently blocking

The `QueryEngine` class wraps this generator for the SDK/headless path, owning the full lifecycle of a conversation session. Each `submitMessage()` call starts a new turn while preserving all accumulated state.

### Recovery Paths

The loop has four distinct error recovery strategies:

1. **max_output_tokens**: Retries up to 3 times, incrementing the token budget each time.
2. **Prompt too long**: Triggers reactive compaction (a one-shot compaction mid-turn), or returns a `blocking_limit` terminal if compaction fails.
3. **Streaming fallback**: When streaming fails partway through, orphaned messages are "tombstoned" and a fresh tool executor is created.
4. **Model fallback**: A `FallbackTriggeredError` switches to the configured fallback model and retries.

### Dependency Injection

The `QueryDeps` type enables test injection without module-level mocking:

```
callModel    -> queryModelWithStreaming
microcompact -> microcompactMessages
autocompact  -> autoCompactIfNeeded
uuid         -> randomUUID
```

This is a pragmatic alternative to full DI containers. The four dependencies represent the loop's I/O boundaries: API calls, context management, and randomness.

---

## 2. Context and Memory Management

### Three-Tier Context System

Claude Code manages context at three levels:

1. **System context** (memoized once per session): git status, cache breaker. Captured at session start and never refreshed during the conversation.
2. **User context** (memoized once per session): CLAUDE.md content, current date. Also captured once.
3. **Per-turn context**: tool results, memory file injections, session reminders.

The memoization of system and user context is a deliberate trade-off: it avoids repeated filesystem reads but means the model sees stale git status. The spec notes this explicitly: "This is the git status at the start of the conversation. Note that this status is a snapshot in time, and will not update during the conversation."

### Compaction Architecture

Context compaction is layered:

- **Microcompaction**: In-place trimming of tool results. Runs every iteration. Targets large tool outputs that can be safely truncated.
- **Autocompaction**: Triggered when context usage crosses a threshold. Uses the Claude model itself to generate a compressed summary of the conversation so far.
- **Reactive compaction**: One-shot emergency compaction triggered when the API rejects a request as too long.
- **History snip**: Feature-gated mechanism to trim older conversation turns.
- **Context collapse**: Another feature-gated mechanism for draining staged collapses.

The token budget tracker uses a 90% completion threshold and a diminishing returns detector: if output tokens delta is below 500 for two consecutive checks after 3+ continuations, the loop stops. This prevents infinite low-productivity loops.

### Memory System

The memory system (`memdir/`) is file-based: markdown files with YAML frontmatter stored in `~/.claude/projects/<sanitized-git-root>/memory/`. Key architectural decisions:

- **Relevance selection is model-driven**: A side query to a Sonnet model picks up to 5 relevant memory files from a manifest of headers. This means memory selection costs an extra API call per turn.
- **Freshness warnings are injected**: Memories older than 1 day get a `<system-reminder>` caveat warning the model that citations may be outdated.
- **Four memory types**: user, feedback, project, reference. Each has different scoping rules for team vs. private visibility.
- **Auto-dream consolidation**: A background process (`autoDream`) periodically scans session transcripts and uses a forked agent to consolidate learnings into memory files. Gated behind a minimum of 24 hours and 5 sessions before first consolidation. Uses a file-based mutex lock with PID-based ownership and 1-hour stale timeout.

The memory path resolution has extensive security: rejects relative paths, root paths, UNC paths, null bytes, and normalizes to NFC. Team memory paths get additional symlink-following validation via `realpathDeepestExisting()`.

---

## 3. Permission Model and Security

### Four-Tier Permission System

Permission decisions are modeled as a discriminated union:

- `allow`: proceed with potentially modified input
- `ask`: prompt the user with a message
- `deny`: block with a message
- `passthrough`: always ask the user (no auto-resolution)

Each tool declares its own `checkPermissions()` function that returns one of these decisions. The permission context carries:

- `mode`: one of `default`, `plan`, `auto`, `bypassPermissions`, `acceptEdits`, `dontAsk`
- Rule lists: `alwaysAllow`, `alwaysDeny`, `alwaysAsk` with pattern matching
- Additional working directories
- Per-tool permission overrides

### Settings Layering

Settings are resolved in priority order:
1. Managed (enterprise, read-only)
2. Local project (`.claude/settings.local.json`, gitignored)
3. Project (`.claude/settings.json`, shared)
4. Global (`~/.claude/settings.json`)

This layering means enterprise policies always win, project-specific rules override personal preferences, and local overrides are never committed to version control.

### Sandbox System

The sandbox configuration is remarkably detailed:

- **Linux**: bubblewrap (`bwrap`) isolation
- **macOS**: `sandbox-exec` based isolation
- **Windows**: no sandbox available

The sandbox settings schema includes network allowlists (domains, unix sockets, local binding), filesystem allowlists/denylists for read and write, violation ignoring per rule, and enterprise "fail if unavailable" enforcement.

A notable security feature: `autoAllowBashIfSandboxed` lets enterprises auto-approve bash commands when the sandbox is active, trading per-command approval for sandboxed execution.

### Read-Before-Write Enforcement

FileWriteTool and FileEditTool enforce that the target file has been previously read via FileReadTool within the same session. The read registers the file in a `readFileState` cache with its mtime. Before writing, the tool checks:

1. The file exists in `readFileState` (was read this session).
2. The mtime has not changed since the read (no concurrent modifications).

This prevents the model from blindly overwriting files it has never seen, and catches race conditions with external editors.

### Trust Dialog

Claude Code shows a trust dialog on first run that must be dismissed before any `apiKeyHelper` scripts execute. The spec explicitly notes this prevents RCE: a malicious project could place an `apiKeyHelper` script that executes before the user has a chance to review the project.

---

## 4. Hook System Design

### Hook Types

Four hook types, each represented as a discriminated union on the `type` field:

1. **Command hook** (`type: 'command'`): Executes a shell command. Supports async (non-blocking), `asyncRewake` (background execution that wakes the model on exit code 2), and `once` (run once then remove).
2. **Prompt hook** (`type: 'prompt'`): Sends a prompt to an LLM. The hook input JSON is available via `$ARGUMENTS` substitution.
3. **HTTP hook** (`type: 'http'`): POSTs to a URL with optional headers. Supports environment variable interpolation with explicit allowlists.
4. **Agent hook** (`type: 'agent'`): Runs a verification prompt via a sub-agent. Default model is Haiku, default timeout 60 seconds.

### Hook Lifecycle Events

28 hook events are defined:

```
PreToolUse, PostToolUse, PostToolUseFailure, Notification,
UserPromptSubmit, SessionStart, SessionEnd, Stop, StopFailure,
SubagentStart, SubagentStop, PreCompact, PostCompact,
PermissionRequest, PermissionDenied, Setup, TeammateIdle,
TaskCreated, TaskCompleted, Elicitation, ElicitationResult,
ConfigChange, WorktreeCreate, WorktreeRemove, InstructionsLoaded,
CwdChanged, FileChanged
```

### Conditional Execution

The `if` field uses permission rule syntax (e.g., `Bash(git *)`, `Read(*.ts)`) to filter hook execution before spawning. This is evaluated against `tool_name` and `tool_input`, meaning hooks can be scoped to specific tool invocations.

### Hook Matchers

The `HookMatcher` type pairs an optional `matcher` string with an array of hook commands. This allows multiple hooks to fire on the same event, with different matchers filtering to different subsets of tool calls.

### Stop Hook Orchestration

The stop hook system (`query/stopHooks.ts`) orchestrates end-of-turn behavior. Execution order:

1. Cache context for prompt suggestions.
2. Template job classification (60s timeout).
3. Background side-effects: prompt suggestion, memory extraction, auto-dream.
4. Execute Stop/SubagentStop hooks in parallel.
5. Summary message and notification if hooks ran.
6. Teammate hooks if applicable.

A blocking hook error creates a `UserMessage` with `isMeta: true` that is injected back into the conversation. A `preventContinuation` flag stops the loop entirely.

---

## 5. Feature Flags and Hidden Features

### Feature Flag Taxonomy

Feature flags come from two sources:

1. **Build-time flags** (`feature()` function): Tree-shaking boundaries that compile out code paths. Examples: `BUDDY`, `KAIROS`, `COORDINATOR_MODE`, `BRIDGE_MODE`, `BG_SESSIONS`, `TEMPLATES`, `CHICAGO_MCP`, `DAEMON`, `VOICE_MODE`.
2. **Runtime flags** (GrowthBook): Dynamic config fetched from a remote server with disk caching. Examples use obfuscated names like `tengu_onyx_plover` (auto-dream), `tengu_frond_boric` (analytics kill switch), `tengu_amber_quartz_disabled` (voice kill switch), `tengu_herring_clock` (team memory), `tengu_coral_fern` (memory search section).

The GrowthBook integration has a three-tier caching strategy:

- `_DEPRECATED` functions: block on initialization Promise (used for startup-critical gates)
- `_CACHED_MAY_BE_STALE`: synchronous from in-memory cache
- `_CACHED_OR_BLOCKING`: awaits init then returns cached (security gates only)

### Buddy / Tamagotchi System

A companion pet system gated behind the `BUDDY` flag, planned for April 1-7 2026 as a "teaser window." Key details:

- 18 ASCII art species with 3 animation frames each (500ms tick).
- Deterministic appearance derived from `hash(userId + SALT)` via Mulberry32 PRNG. Never stored; always recomputed. This prevents users from editing config to claim legendary rarity.
- Gacha mechanics: 60% common, 25% uncommon, 10% rare, 4% epic, 1% legendary. 1% shiny chance independent of rarity.
- Species name strings are encoded as `String.fromCharCode()` literals to bypass a build-time string scan that checks for internal model codenames.

### Anti-Distillation Measures

The spec reveals a `tengu_anti_distill_fake_tool_injection` GrowthBook gate that injects fake tools into API calls "as a training data quality signal." This is a countermeasure against competitors training on Claude Code's API traffic.

### Ablation Baseline

The `ABLATION_BASELINE` flag sets multiple `CLAUDE_CODE_*` environment variables for "harness-science L0 ablation" -- a controlled experiment mode that strips features to measure their individual contribution.

### Coordinator Mode

A multi-worker orchestration mode where Claude Code becomes a coordinator spawning parallel subagents. The coordinator gets a detailed system prompt describing a 4-phase workflow: Research, Synthesis, Implementation, Verification. Workers communicate via mailbox files at `~/.claude/mailboxes/<name>.json`.

### KAIROS Mode

A persistent assistant mode with daily log files (`~/.claude/projects/.../memory/logs/YYYY/MM/YYYY-MM-DD.md`), brief mode toggle, and a dream/consolidation system. Associated with cron scheduling and remote triggers.

---

## 6. Tool System Architecture

### Tool as a Protocol

The `Tool` type is essentially a protocol with ~20 methods/properties. Key design decisions:

- **Lazy schema initialization**: `inputSchema` and `outputSchema` are getter properties, allowing deferred Zod schema construction.
- **Per-call capability flags**: `isConcurrencySafe(input)`, `isReadOnly(input)`, `isDestructive(input)` accept the specific input, enabling per-invocation decisions.
- **Dual rendering paths**: Each tool provides both data output (`call()`) and React component rendering (`renderToolUseMessage()`, `renderToolResultMessage()`).
- **Permission integration**: `checkPermissions()` returns a `PermissionDecision` that can modify the input (`updatedInput` field in the `allow` variant).

### Tool Registration and Filtering

Tools are registered in a specific order (must stay in sync with Statsig caching config for prompt cache stability). The `assembleToolPool()` function merges built-in and MCP tools, sorts by name for cache stability, and deduplicates (built-in wins).

A `CLAUDE_CODE_SIMPLE` environment variable strips everything down to `[BashTool, FileReadTool, FileEditTool]` -- a minimal mode for constrained environments.

### Agent Tool

The Agent tool (also aliased as `Task`) spawns sub-agents as isolated Claude instances. It supports:

- Background execution (auto-backgrounds after 120 seconds).
- Named agents for inter-agent messaging.
- Team association for collaborative multi-agent work.
- Isolation strategies: `worktree` (git worktree for isolated file changes) or `remote` (remote session).
- Model override per-agent (`sonnet`, `opus`, `haiku`).

### Streaming vs Sequential Execution

Tool execution has two modes, gated on a Statsig flag:

- **Streaming**: Uses a `StreamingToolExecutor` class that begins executing tools as their input streams in from the API.
- **Sequential**: Uses `runTools()` from the tool orchestration service, executing tools after the full response is received.

---

## 7. Patterns Worth Adopting

### Async Generator for Agent Loops

The `async function*` pattern for the query loop is elegant. It naturally handles the pull-based nature of UI rendering while keeping the loop's state encapsulated. Error recovery is handled with standard try/catch around `yield` points.

### Dependency Injection via Parameter Objects

Rather than a DI container, the `QueryDeps` type bundles the four I/O boundaries into a single object passed at construction time. Production code uses `productionDeps()`, tests substitute fakes. This is the lightest-weight DI pattern possible.

### Layered Configuration with Clear Priority

The four-layer settings system (managed, local project, project, global) with deterministic priority resolution is a pattern that scales well for enterprise deployment.

### Read-Before-Write as a Protocol Invariant

The `readFileState` cache enforcing that files must be read before they can be written is a system-level invariant that prevents an entire class of bugs (blind overwrites, stale data). The mtime check catches race conditions.

### Token Budget with Diminishing Returns Detection

The token budget tracker does not just check "are we over budget?" -- it detects when the model is making less than 500 tokens of progress per iteration and stops. This is a practical heuristic that prevents expensive infinite loops.

### Memoized Context with Explicit Staleness Contracts

Both `getSystemContext()` and `getUserContext()` are memoized with explicit documentation that they are point-in-time snapshots. The memory freshness system extends this pattern by injecting `<system-reminder>` tags that tell the model to verify stale information.

---

## 8. Architectural Observations

### Scale of the Codebase

800K+ lines of TypeScript for what is fundamentally a CLI tool is staggering. The 104 React hooks, 389 component files, and 564 utility files suggest significant internal complexity. The Rust rewrite targeting 47 files across 9 crates will need to be radically more selective about what to port.

### React in a Terminal

Claude Code uses a custom React reconciler (Ink) targeting terminal output with Yoga flexbox layout. This means the entire UI is a React application with hooks, context providers, and component trees -- running in a terminal. The 96 files in the Ink framework alone represent a substantial rendering engine.

### Analytics Density

The analytics infrastructure is extensive: Datadog metrics, first-party event logging, GrowthBook feature flags, OpenTelemetry spans, and per-event sampling configuration. Event names use the `tengu_` prefix (Claude Code's internal codename). The marker type `AnalyticsMetadata_I_VERIFIED_THIS_IS_NOT_CODE_OR_FILEPATHS` is a fascinating code-review mechanism -- the type name itself is the assertion that the developer verified the data is safe to log.

### GrowthBook Gate Naming

Feature gates use obfuscated names: `tengu_frond_boric`, `tengu_onyx_plover`, `tengu_amber_quartz_disabled`, `tengu_herring_clock`, `tengu_coral_fern`. This is likely to prevent external monitoring of feature rollouts via GrowthBook's public API.

### The Bridge Protocol

Claude Code supports remote sessions via WebSocket/SSE transports with JWT authentication. The bridge protocol enables IDE integration (VS Code, JetBrains), cloud-synced sessions, and the REPL bridge. The `DirectConnectSessionManager` handles NDJSON message routing, permission request/response proxying, and interrupt signal forwarding.

### Prompt Cache Optimization

Prompt caching is aggressively optimized. Tools are sorted by name for cache stability. A 1-hour TTL cache tier is available for eligible users (session-stable, latched to prevent mid-session overage flips). A dedicated `promptCacheBreakDetection` service monitors for unexpected cache evictions, writing diff files to disk for debugging.

---

## 9. Surprising Discoveries

1. **Species name obfuscation**: The buddy system encodes species names as `String.fromCharCode()` literals because one species name collides with an internal model codename that would trigger a build-time canary scan.

2. **Anti-distillation fake tool injection**: A feature gate can inject fake tools into API calls as a countermeasure against competitor training on Claude Code traffic.

3. **The `unsafe` keyword `dangerouslyDisableSandbox`**: BashTool has a per-call escape hatch from sandboxing, but it requires explicit enterprise policy opt-in (`allowUnsandboxedCommands`) and triggers separate permission flows.

4. **Process-level heap monitoring**: A React hook (`useMemoryUsage`) polls `process.memoryUsage().heapUsed` every 10 seconds, triggering warnings at 1.5GB and critical alerts at 2.5GB. The `--max-old-space-size=8192` flag is set at bootstrap for remote environments.

5. **The Mulberry32 PRNG**: The buddy system uses a 32-bit PRNG seeded from `hash(userId + SALT)` to deterministically generate companion attributes. The roll is memoized because it is called from three hot paths: sprite animation tick (500ms), per-keystroke PromptInput rendering, and the per-turn observer.

6. **Scroll drain idle detection**: A 150ms debounce mechanism (`markScrollActivity()` / `getIsScrollDraining()` / `waitForScrollIdle()`) prevents background operations from competing with scroll rendering.

7. **Double-press exit pattern**: Ctrl+C and Ctrl+D require a double-press within 800ms to exit, with a visual "Press again to exit" hint between presses. This prevents accidental termination during long-running agent tasks.

8. **Pre-connection TCP overlap**: `preconnectAnthropicApi()` is called during initialization to overlap TCP+TLS handshake with other startup work, saving latency on the first API call.

9. **The `_PROTO_*` metadata convention**: Analytics events use `_PROTO_` prefixed keys to route data to PII-tagged BigQuery columns. These keys are stripped before Datadog but preserved for first-party logging. The naming convention acts as a code-review signal about data sensitivity.

10. **File state cache for MCP**: The MCP server entrypoint maintains an LRU cache of 100 files / 25MB for the `readFileState`, enabling the read-before-write enforcement even when Claude Code is running as an MCP server for external tools.

---

## 10. Implications for Our Architecture

The claurst analysis reveals several patterns that are either directly adoptable or serve as cautionary examples:

**Adoptable**: The async generator agent loop, read-before-write enforcement, layered settings with deterministic priority, dependency injection via parameter objects, and token budget diminishing returns detection are all patterns that translate well to any language or architecture.

**Cautionary**: The sheer scale (800K LOC for a CLI) suggests that the React-in-terminal approach, while powerful, brings significant complexity. The 564 utility files and 104 hooks indicate a codebase that has outgrown its original architecture. The Rust port (47 files, 9 crates) appears to be a ground-up rethinking rather than a line-by-line translation.

**Notable absence**: There is no mention of typed errors in the query loop. Errors are classified by string matching (`isRateLimitError`, `isPromptTooLongMessage`, `startsWithApiErrorPrefix`). This is precisely the kind of infrastructure where typed throws would provide compile-time guarantees.

---

*Analysis based on claurst spec documents dated 2026-03-31. Source: https://github.com/Kuberwastaken/claurst*
