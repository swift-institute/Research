# Claude Code Swift Rewrite Feasibility

<!--
---
version: 1.0.0
last_updated: 2026-04-01
status: IN_PROGRESS
---
-->

## Context

The accidental leak of Anthropic's Claude Code source (~1,900 TypeScript files, ~800K LOC) and subsequent community analysis (Kuberwastaken/claurst Rust rewrite + spec documents) provides a detailed architectural blueprint for a production-grade AI coding agent. This research investigates whether the Swift Institute ecosystem could support a reimplementation, what already exists, what needs upgrading, and what entirely new packages are required.

**Scope**: Cross-layer analysis (L1 Primitives through L4 Components). Tier 2 research — cross-package, reversible precedent, medium cost of error.

**Companion documents**: `claurst-analysis.md`, `claurst-rust-patterns.md` (both in this Research/ directory).

## Question

Can the Claude Code agent architecture be reimplemented using the Swift Institute five-layer ecosystem? For each subsystem, what infrastructure exists, what gaps remain, and what new packages would be needed?

## Analysis

### Subsystem Mapping Overview

| Claude Code Subsystem | Complexity | Ecosystem Coverage | Verdict |
|----------------------|-----------|-------------------|---------|
| 1. Agent query loop & streaming | High | **~80% covered** | Composition of existing packages |
| 2. Tool system & permissions | Medium | **~30% covered** | New L3 package needed |
| 3. Terminal UI | High | **~25% covered** | New L3+L4 packages needed |
| 4. Context & memory management | Medium | **~60% covered** | New L3 package + YAML gap |
| 5. OAuth authentication | High | **~10% covered** | New L2+L3 packages needed |
| 6. HTTP/WebSocket transport | High | **~20% covered** | New L2+L3 packages needed |
| 7. Plugin/hook system | Medium | **~50% covered** | Composition + thin new package |
| 8. Feature flag system | Low | **~40% covered** | Thin new L3 package |

---

### 1. Agent Query Loop & Streaming

**What Claude Code does**: An async generator loop that streams API responses, dispatches tool calls, manages conversation state, fires hooks, tracks token budgets, and handles four recovery paths (max_tokens retry, reactive compaction, streaming tombstone, model fallback). Channel-based event fan-out decouples the loop from the UI.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| Async streams/sequences | `Async_Stream`, `Async_Sequence` (swift-async) | L3 | Production |
| Channels (bounded, broadcast) | `Async_Primitives` (swift-async-primitives) | L1 T19 | Production |
| Cancellation tokens | `Async_Primitives` — waiters, cancellation | L1 T19 | Production |
| State machines | `Machine_Primitives` (swift-machine-primitives) | L1 T19 | Production |
| Continuations | `Continuation_Primitives` | L1 T2 | Production |
| Effect types | `Effect_Primitives` | L1 T2 | Production |
| Mutexes, timers | `Async_Primitives` | L1 T19 | Production |
| Cost tracking (atomics) | `Kernel_Primitives` — atomics | L1 T17 | Production |

**Gap analysis**: The agent loop itself is application logic, not infrastructure. The Swift mapping is:

```
TypeScript async function*  →  AsyncStream<QueryEvent>
mpsc::UnboundedSender      →  Async.Channel<QueryEvent>
CancellationToken           →  Task.cancel() / withTaskCancellationHandler
StreamAccumulator           →  Custom accumulator struct (trivial)
QueryDeps (DI)              →  Protocol witnesses or Dependencies (swift-dependencies)
```

**Verdict**: **No new packages needed.** The query loop is composition of `Async_Stream` + `Async.Channel` + `Task` cancellation. The four recovery paths map to typed throws with a `switch` on the error type — precisely where our typed throws discipline gives compile-time guarantees that Claude Code's string-matching classification lacks.

**Upgrade needed**: None. Swift's structured concurrency is a better fit than the async generator pattern — we get cancellation propagation for free.

---

### 2. Tool System & Permission Model

**What Claude Code does**: 40+ tools implement a `Tool` protocol (~20 methods). Each tool declares permission requirements, input/output schemas (Zod), and per-call capability flags (`isReadOnly`, `isDestructive`). A four-tier permission system (`allow`/`ask`/`deny`/`passthrough`) with pattern-matching rules. Read-before-write enforcement via mtime tracking. Sandbox integration (bubblewrap/sandbox-exec).

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| Protocol witnesses | `Witness_Primitives` (swift-witness-primitives) | L1 T2 | Production |
| @Witness macro | `Witnesses` (swift-witnesses) | L3 | Production |
| Property access patterns | `Property_Primitives` | L1 T0 | Production |
| JSON encoding/decoding | `JSON` (swift-json) | L3 | Production |
| File system operations | `File_System` (swift-file-system) | L3 | Production |
| Process execution | `Kernel` — process/exec | L3 | Production |
| Path handling | `Paths` (swift-paths) | L3 | Production |
| Typed error hierarchies | `Error_Primitives`, `Outcome_Primitives` | L1 T0-1 | Production |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| JSON Schema generation from Swift types | Medium | New capability in swift-json or new L3 package |
| Permission model (rules, pattern matching, settings layers) | High | New L3 package: `swift-permissions` or inline in agent package |
| Tool registry (registration, dispatch, filtering) | Medium | Application code — protocol + dictionary, no package needed |
| Sandbox abstraction (platform-specific isolation) | Medium | New L3 package or extend swift-kernel/platform packages |
| Read-before-write state cache | Low | Trivial: `[File.Path: File.Modification.Time]` dictionary |

**Verdict**: **One new L3 package** for the permission model + settings layering. Tool dispatch is a protocol with associated types:

```swift
protocol Tool: Sendable {
    associatedtype Input: Decodable & Sendable
    associatedtype Output: Encodable & Sendable
    static var name: String { get }
    static var permissionLevel: Permission.Level { get }
    func execute(_ input: Input, context: Tool.Context) async throws(Tool.Error) -> Output
}
```

This gives us compile-time schema validation (via `Decodable` conformance) instead of runtime Zod validation — a structural advantage.

---

### 3. Terminal UI

**What Claude Code does**: A full React reconciler (Ink) targeting terminal output with Yoga flexbox layout. 389 components, 104 hooks, 96 files just for the terminal framework. Components include: message rendering, prompt input, spinners, permission dialogs, settings screens, agent views, diff rendering.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| Terminal I/O, ANSI control | `Terminal_Primitives` | L1 T18 | Production |
| Console output | `Console` (swift-console) | L3 | Production |
| Rendering abstraction | `Rendering_Primitives` | L1 T20 | Production |
| Color types | `Color` (swift-color), `Color_Standard` | L2-3 | Production |
| ANSI color codes | `Color_Standard` (ECMA 48) | L2 | Production |
| Layout primitives | `Layout_Primitives` | L1 T13 | Production |
| Region/dimension | `Region_Primitives`, `Dimension_Primitives` | L1 T9-10 | Production |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| TUI component framework (widgets, layout engine) | **Critical** | New L3 package: `swift-terminal-ui` |
| Input handling (key events, mouse, focus management) | High | Part of terminal-ui package |
| Flexbox/constraint-based terminal layout | High | Part of terminal-ui package (simpler than Yoga) |
| Diff rendering | Medium | New capability or part of terminal-ui |
| Markdown terminal rendering | Medium | Extend swift-markdown-html-rendering or new target |

**Verdict**: **One new L3 package** (`swift-terminal-ui` or similar) is the largest single gap. However, we should NOT replicate the Ink/React approach — that's 800K LOC of complexity for a CLI tool. The Rust rewrite uses ratatui (a much simpler immediate-mode TUI library). The Swift equivalent would be:

- L1: `Terminal_Primitives` (already exists) — raw terminal I/O, ANSI sequences
- L1: `Rendering_Primitives` (already exists) — rendering witness pattern
- L3: **New** `swift-terminal-ui` — widget tree, layout, input loop, styled text

Rough scope: ~5,000-10,000 LOC for an MVP terminal UI, not 96 files. The rendering witness pattern at L1 already provides the abstraction layer.

---

### 4. Context & Memory Management

**What Claude Code does**: Three-tier context (system/user/per-turn), five-layer compaction (micro → auto → reactive → history snip → context collapse), file-based memory with YAML frontmatter and keyword relevance scoring, auto-dream background consolidation with cost-ordered gating, staleness annotations.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| File system operations | `File_System` (swift-file-system) | L3 | Production |
| JSON encoding/decoding | `JSON` (swift-json) | L3 | Production |
| Path handling | `Paths` (swift-paths) | L3 | Production |
| String utilities | `Strings` (swift-strings) | L3 | Production |
| Markdown processing | `SwiftMarkdown` (swift-markdown-html-rendering) | L3 | Production |
| Cache primitives | `Cache_Primitives` | L1 T20 | Production |
| Time types | `Time` (swift-time), `Time_Standard` | L2-3 | Production |
| Async background tasks | `Async` (swift-async) | L3 | Production |
| Lock files, PID-based mutex | `Kernel` — file locking | L3 | Production |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| YAML frontmatter parsing | Medium | Minimal parser (only `---` delimiters + `key: value`) — can be ~50 LOC inline, or new L3 target |
| Token estimation | Medium | Application logic — heuristic based on character count or tiktoken port |
| Compaction prompt/strategy | Low | Application logic, not infrastructure |
| TF-IDF keyword relevance scorer | Low | ~100 LOC utility, no package needed |
| Memory file type taxonomy | Low | Enum + Codable, trivial |

**Verdict**: **No new packages needed**, but a lightweight YAML frontmatter parser is required. This is NOT full YAML — just the `---`-delimited header with simple `key: value` pairs. The claurst Rust implementation does this in ~80 lines with string prefix matching, no YAML library. We should do the same.

The compaction system, auto-dream consolidation, and relevance scoring are all application-level logic that compose existing file system + async + caching infrastructure.

---

### 5. OAuth Authentication

**What Claude Code does**: OAuth 2.0 PKCE flow via `platform.claude.com`, token storage in files with environment-specific suffixes, automatic refresh with 401 retry, JWT parsing for bridge sessions, keychain prefetch on macOS, secure token storage with allowlisted OAuth URLs.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| URI types | `URI_Standard` (RFC 3986) | L2 | Production |
| HTTP concepts | — | — | **Missing** |
| Base64 encoding | `Base62_Primitives` | L1 T0 | Production (base62 only) |
| JSON | `JSON` (swift-json) | L3 | Production |
| File-based storage | `File_System` | L3 | Production |
| Cryptographic hashing | — | — | **Missing** |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| HTTP client (for token exchange) | **Critical** | Blocked on HTTP transport (see §6) |
| OAuth 2.0 PKCE protocol | **Critical** | New L2 package: `swift-oauth-standard` (RFC 6749 + RFC 7636) |
| JWT parsing/validation | High | New L2 package: `swift-jwt-standard` (RFC 7519) |
| Base64url encoding | Medium | Extend or add target in swift-uri-standard (RFC 4648 already partially covered) |
| Secure credential storage | Medium | Platform-specific: Keychain (macOS), Secret Service (Linux) |
| PKCE code verifier/challenge | Medium | SHA256 + base64url — part of OAuth package |

**Verdict**: **Two new L2 standards packages** needed:
1. `swift-oauth-standard` — RFC 6749 (OAuth 2.0) + RFC 7636 (PKCE). Covers token exchange, refresh, PKCE code_verifier/code_challenge generation.
2. `swift-jwt-standard` — RFC 7519. JWT parsing (header + payload decode, signature verification). Needed for bridge session management.

Plus a SHA256 dependency — either a new `swift-hash-standard` or use platform crypto (`CommonCrypto` on Darwin, `CryptoKit` bridging).

---

### 6. HTTP/WebSocket Transport

**What Claude Code does**: HTTP client for API calls (streaming SSE), WebSocket for bridge sessions, retry logic with exponential backoff, proxy support, mTLS, pre-connection TCP overlap, prompt cache optimization via header management.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| TCP/UDP sockets | `Sockets_Standard` (RFC 768/791/9293) | L2 | Production |
| Network primitives | `Network_Primitives` | L1 T18 | Production |
| I/O event loop | `IO` (swift-io) — events, completions, executor | L3 | Production |
| DNS resolution | — | — | **Missing** |
| TLS | — | — | **Missing** |
| HTTP/1.1 protocol | — | — | **Missing** |
| SSE (Server-Sent Events) | — | — | **Missing** |
| WebSocket (RFC 6455) | — | — | **Missing** |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| TLS (Transport Layer Security) | **Critical** | New L2 package: `swift-tls-standard` or platform wrapper |
| HTTP/1.1 client | **Critical** | New L3 package: `swift-http` (builds on sockets + TLS) |
| SSE parser/client | High | New target in swift-http or separate package |
| WebSocket protocol | High | New L2 package: `swift-websocket-standard` (RFC 6455) |
| DNS resolution | Medium | Platform APIs (getaddrinfo) or new L3 target |
| HTTP/2 | Low (nice-to-have) | Defer — HTTP/1.1 sufficient for API calls |
| Retry/backoff utilities | Low | Application logic or thin L3 utility |

**Verdict**: **This is the largest infrastructure gap.** Three new packages minimum:

1. **`swift-tls-standard`** (L2) — TLS 1.2/1.3. Options: wrap platform TLS (Security.framework on Darwin, OpenSSL on Linux), or implement from spec. Platform wrapping is pragmatic; pure implementation is a multi-month effort.
2. **`swift-http`** (L3) — HTTP/1.1 client with streaming support, built on `Sockets_Standard` + TLS. Needs: request/response types, chunked transfer encoding, connection pooling, SSE parsing.
3. **`swift-websocket-standard`** (L2) — RFC 6455 WebSocket protocol. Frame parsing, masking, ping/pong, close handshake.

**Alternative**: Wrap `URLSession` on Darwin + `libcurl` on Linux as a pragmatic L3 shim. This sacrifices five-layer purity (Foundation dependency) but ships in weeks instead of months. This is a strategic decision point.

---

### 7. Plugin/Hook System

**What Claude Code does**: Manifest-based plugin discovery from 3 locations, 4 hook types (command, prompt, HTTP, agent), 28 lifecycle events, hot reload with diff computation, conditional execution via permission rule matching.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| Dynamic loading | `Loader` (swift-loader) | L3 | Production |
| JSON manifest parsing | `JSON` (swift-json) | L3 | Production |
| TOML/Plist parsing | `Plist` (swift-plist) | L3 | Production |
| File system watching | — | — | **Missing** (kqueue/inotify at L1 kernel level) |
| Process execution | `Kernel` — process management | L3 | Production |
| Event dispatch | Async.Channel, Swift concurrency | L1/L3 | Production |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| Plugin manifest schema | Low | Application-level JSON/TOML Codable types |
| Hook registry (event → handler mapping) | Low | Dictionary + enum, application logic |
| File system watching (hot reload) | Medium | kqueue on Darwin / inotify on Linux — extend `Kernel` or new target |
| Process execution with stdin JSON | Low | Already possible via `Kernel` process APIs |

**Verdict**: **No new packages needed.** The plugin system is application-level composition of existing `Loader` + `JSON` + `Kernel` + async channels. File system watching may need a small extension to the kernel package, but kqueue/inotify are already exposed at the primitives level.

---

### 8. Feature Flag System

**What Claude Code does**: GrowthBook client with three-tier caching (blocking, cached-may-be-stale, cached-or-blocking), disk cache, obfuscated flag names, build-time tree-shaking via `feature()` function.

**What we have**:

| Capability | Package | Layer | Status |
|-----------|---------|-------|--------|
| Cache primitives | `Cache_Primitives` | L1 T20 | Production |
| JSON parsing | `JSON` (swift-json) | L3 | Production |
| HTTP client | — | — | **Missing** (see §6) |
| Conditional compilation | Swift `#if` | Language | Built-in |

**Gap analysis**:

| Gap | Severity | Resolution |
|-----|----------|------------|
| GrowthBook SDK (or equivalent) | Medium | New thin L3 package or application code |
| Remote config fetching | Medium | Blocked on HTTP client (see §6) |
| Disk-cached flag evaluation | Low | `JSON` + `File_System`, trivial |
| Build-time feature gates | None | Swift `#if` / compiler flags already work |

**Verdict**: **No dedicated package needed** if we use Swift's conditional compilation for build-time gates. Runtime feature flags need an HTTP client (§6 dependency) plus a thin evaluation engine. Could be a target within the agent application rather than a standalone package.

---

## New Package Summary

### Required New Packages (by layer)

#### L2 Standards (specification implementations)

| Package | Specification | Estimated Scope | Priority |
|---------|--------------|-----------------|----------|
| `swift-http-standard` | RFC 7230–7235 (HTTP/1.1) | Medium (~5K LOC) | **P0** — blocks everything |
| `swift-tls-standard` | RFC 8446 (TLS 1.3) | Large (~10K+ LOC) or platform wrap | **P0** — blocks HTTP |
| `swift-websocket-standard` | RFC 6455 | Small (~2K LOC) | P1 — blocks bridge mode |
| `swift-oauth-standard` | RFC 6749 + RFC 7636 (PKCE) | Small (~1.5K LOC) | P1 — blocks auth |
| `swift-jwt-standard` | RFC 7519 | Small (~1K LOC) | P2 — bridge sessions only |
| `swift-sse-standard` | W3C Server-Sent Events | Small (~500 LOC) | P1 — blocks API streaming |

#### L3 Foundations (composed building blocks)

| Package | Purpose | Estimated Scope | Priority |
|---------|---------|-----------------|----------|
| `swift-http` | HTTP client (connection pooling, streaming, retry) | Medium (~4K LOC) | **P0** |
| `swift-terminal-ui` | TUI widget framework (layout, input, styled text) | Medium (~8K LOC) | P1 |

#### L4 Components (opinionated assemblies)

| Package | Purpose | Estimated Scope | Priority |
|---------|---------|-----------------|----------|
| `swift-agent` | Agent loop, tool dispatch, permissions, context management | Large (~15K LOC) | P1 |

### Existing Packages Needing Upgrades

| Package | Upgrade | Scope |
|---------|---------|-------|
| `swift-json` | JSON Schema generation from Swift types (for tool input schemas) | Medium |
| `swift-kernel` / platform packages | File system watching (kqueue/inotify wrapper) | Small |
| `swift-uri-standard` | Base64url encoding (RFC 4648 §5) — may already be partial | Small |

### Nothing Needed (Application Logic)

These Claude Code subsystems map to application code, not infrastructure packages:

- Agent query loop (composes `Async_Stream` + `Async.Channel` + `Task`)
- Compaction system (application logic over message arrays)
- Memory/memdir system (file I/O + lightweight frontmatter parsing)
- Plugin/hook system (composition of `Loader` + `JSON` + `Kernel`)
- Feature flag evaluation (conditional compilation + thin runtime logic)
- Tool implementations (each tool is application code using foundation packages)
- Cost tracking (atomic counters — already have via `Kernel_Primitives`)
- Read-before-write enforcement (dictionary + mtime check)

---

## Architecture Mapping

### Claude Code layers → Five-layer architecture

```
Claude Code                    Swift Institute
─────────────────────────────────────────────────
Terminal UI (Ink/React)    →   L4 Component: swift-agent-ui
                               L3 Foundation: swift-terminal-ui
                               L1 Primitive: Terminal_Primitives, Rendering_Primitives

Agent Core                 →   L4 Component: swift-agent
  Query loop                   L3: swift-async (AsyncStream + Channel)
  Tool dispatch                L3: swift-agent (Tool protocol + registry)
  Permissions                  L3: swift-agent (Permission model)
  Context/memory               L3: swift-file-system + swift-json

API Transport              →   L3 Foundation: swift-http
                               L2 Standard: swift-http-standard, swift-sse-standard
                               L2 Standard: swift-tls-standard
                               L1 Primitive: Network_Primitives, Sockets_Standard

Authentication             →   L3 Foundation: swift-http (token exchange)
                               L2 Standard: swift-oauth-standard, swift-jwt-standard

Bridge / Remote            →   L3 Foundation: swift-http (SSE transport)
                               L2 Standard: swift-websocket-standard

Platform                   →   L1 Primitive: Darwin/Linux/Windows_Primitives
                               L3 Foundation: Kernel, IO
```

### Typed Throws Advantage

Claude Code classifies errors via string matching:
```typescript
isRateLimitError(error)          // string check
isPromptTooLongMessage(msg)      // string check  
startsWithApiErrorPrefix(text)   // string check
```

Swift implementation with typed throws:
```swift
enum API.Error: Swift.Error {
    case rateLimited(retryAfter: Duration)
    case promptTooLong(actual: Int, limit: Int)
    case authentication(Authentication.Error)
    case overloaded
    case connection(Connection.Error)
}

// Compile-time exhaustive handling:
func handle(_ error: API.Error) {
    switch error {
    case .rateLimited(let retryAfter): ...
    case .promptTooLong(let actual, let limit): ...
    // compiler enforces all cases handled
    }
}
```

This eliminates an entire class of bugs (missed error classifications, typos in string matching).

---

## Critical Path

The dependency chain for a minimum viable agent:

```
Phase 1: Transport (blocks everything)
  TLS → HTTP standard → HTTP client → SSE
  
Phase 2: Auth + API (blocks agent loop)  
  OAuth standard → API client wrapper
  
Phase 3: Agent Core (blocks UI)
  Tool protocol + registry
  Permission model
  Query loop (AsyncStream composition)
  Context management
  
Phase 4: Terminal UI
  Terminal UI framework
  Agent-specific components
  
Phase 5: Extended Features
  WebSocket (bridge mode)
  JWT (remote sessions)
  Plugin system
  Feature flags
```

**Phase 1 is the bottleneck.** Without HTTP+TLS, nothing else can proceed. The strategic decision: pure Swift implementation (months) vs. platform TLS wrapping (weeks). Platform wrapping violates [PRIM-FOUND-001] at L2 but not at L3 — a pragmatic `swift-http` at L3 could wrap platform TLS while an L2 `swift-tls-standard` is developed in parallel.

---

## Comparison: Lines of Code

| Component | Claude Code (TS) | Claurst (Rust) | Estimated Swift |
|-----------|-----------------|----------------|-----------------|
| Agent loop | ~115K (query.ts + QueryEngine.ts + services) | ~25K | ~8K |
| Tool system | ~230K (40+ tools + framework) | ~100K (33 tools) | ~30K |
| Terminal UI | ~580K (Ink + components + hooks) | ~100K (ratatui) | ~15K |
| Transport | ~75K (bridge + API + SSE) | ~80K | ~20K |
| Memory/context | ~30K | ~15K | ~5K |
| Auth | ~20K | ~15K | ~5K |
| **Total** | **~800K** | **~350K** | **~80-100K** |

The 8-10x reduction from TypeScript is due to: no React reconciler, no flexbox engine, typed errors instead of string classification, Swift's expressive type system (protocols with associated types replace runtime schema validation), and structured concurrency replacing manual async orchestration.

---

## Outcome

**Status**: IN_PROGRESS

**Preliminary finding**: A Swift reimplementation is feasible and would be architecturally superior in several dimensions (typed errors, actor isolation for global state, protocol-based tool dispatch with compile-time schema validation). The ecosystem covers ~40-50% of the required infrastructure today.

**Critical gap**: HTTP/TLS transport. This is the single largest blocker and represents the most significant engineering investment. Everything else either exists or is tractable composition of existing packages.

**New packages needed**: 6 at L2 (standards), 2 at L3 (foundations), 1 at L4 (component). Estimated total new infrastructure: ~25-30K LOC across the new packages.

**Recommended next steps**:
1. **Strategic decision**: Platform TLS wrapping vs. pure implementation — determines timeline (weeks vs. months for Phase 1)
2. **Prototype**: Build the agent query loop using existing `Async_Stream` + `Async.Channel` to validate the concurrency model
3. **HTTP spike**: Evaluate whether `swift-io`'s event loop + `Sockets_Standard` can support HTTP/1.1 with streaming SSE
4. **Tool protocol design**: Formalize the `Tool` protocol with associated types and typed throws — this is the most architecturally significant design decision

## References

- Kuberwastaken/claurst repository: `https://github.com/Kuberwastaken/claurst`
- Spec documents: `claurst/spec/00_overview.md` through `claurst/spec/13_rust_codebase.md`
- Companion analyses: `claurst-analysis.md`, `claurst-rust-patterns.md` (this directory)
- Five-layer architecture: `Documentation.docc/Five Layer Architecture.md`
- Ecosystem data structures: `ecosystem-data-structures-inventory.md` (this directory)
