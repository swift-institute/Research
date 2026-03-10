# Workspace-Wide Symbol Search for CCLSP

<!--
---
version: 1.0.0
last_updated: 2026-03-10
status: RECOMMENDATION
tier: 2
---
-->

## Context

Claude Code sessions start from `/Users/coen/Developer`, a local-only directory that is not a git repository and does not exist on GitHub. The Swift Institute ecosystem lives in sub-directories (swift-primitives/, swift-standards/, swift-foundations/), each containing monorepos of independent Swift packages.

CCLSP (the Claude Code LSP MCP server, [ktnyt/cclsp](https://github.com/ktnyt/cclsp)) provides type-aware code intelligence via SourceKit-LSP. Currently, workspace-wide symbol search (`find_workspace_symbols`) returns empty results, while file-targeted operations (`find_definition`, `find_references`) work correctly.

This research investigates how to enable workspace-wide symbol search given the local-only nature of the Developer directory.

**Trigger**: Design question blocking effective tooling (Investigation workflow, [RES-001]).

**Cross-reference**: [ai-context-reduction-via-type-system-tooling.md](ai-context-reduction-via-type-system-tooling.md) — parent research.

## Question

How should CCLSP be configured to enable workspace-wide symbol search across the Swift Institute ecosystem when sessions start from a local-only parent directory?

## Analysis

### Empirical Findings

Three critical discoveries drive this analysis, all validated 2026-03-10.

#### Finding 1: `rootMarkers` Is Silently Ignored

The current CCLSP config (`~/.claude/cclsp.json`):

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootMarkers": ["Package.swift", ".xcworkspace", ".xcodeproj"]
    }
  ]
}
```

**`rootMarkers` does not exist in CCLSP's schema.** The `LSPServerConfig` interface accepts only:

```typescript
interface LSPServerConfig {
  extensions: string[];
  command: string[];
  rootDir?: string;              // ← the actual root mechanism
  restartInterval?: number;
  initializationOptions?: unknown;
}
```

JSON.parse silently accepts `rootMarkers` as an unknown property. It has zero effect. There are no references to "rootMarkers" anywhere in the cclsp codebase.

#### Finding 2: CCLSP Sends Exactly One Workspace Folder

CCLSP's workspace root resolution (`server-manager.ts`):

```typescript
rootUri: pathToUri(serverConfig.rootDir || process.cwd())
workspaceFolders: [{
  uri: pathToUri(serverConfig.rootDir || process.cwd()),
  name: 'workspace',
}]
```

It always sends **one** workspace folder: `rootDir` if configured, otherwise `process.cwd()`. Since `rootDir` isn't set and CWD is `/Users/coen/Developer` (no Package.swift), SourceKit-LSP gets a workspace root with no discoverable build system.

#### Finding 3: `.xcworkspace` Is Not Supported by SourceKit-LSP

SourceKit-LSP's `WorkspaceType` enum has exactly three cases:

```swift
enum WorkspaceType { case buildServer, compilationDatabase, swiftPM }
```

Zero references to `.xcworkspace` or `.xcodeproj` in the SourceKit-LSP codebase. The existing `Primitives.xcworkspace` and `Standards.xcworkspace` files are Xcode-only; SourceKit-LSP cannot use them.

### SourceKit-LSP Workspace Capabilities

Despite CCLSP's single-root limitation, SourceKit-LSP itself is quite capable:

| Feature | Status | Detail |
|---------|--------|--------|
| Multiple `workspaceFolders` | ✅ Supported | Each folder gets its own `Workspace` instance |
| Dynamic folder changes | ✅ Supported | `didChangeWorkspaceFolders` notification |
| Implicit workspace discovery | ✅ Supported | Walks up from opened files to find Package.swift |
| Background indexing | ✅ Supported | Configurable via `.sourcekit-lsp/config.json` |
| BSP (Build Server Protocol) | ✅ Supported | Via `.bsp/` directory |

**Implicit workspace discovery** (PR #1081): When a file is opened that no existing workspace handles, SourceKit-LSP walks up parent directories (within explicit workspace roots) looking for `Package.swift`. If found, it creates an **implicit workspace** and indexes that package. This is how file-targeted operations (`find_definition`) currently work — they trigger implicit workspace creation for the relevant package.

**Constraint**: Implicit discovery only searches within the explicit workspace root. If the root is `/Users/coen/Developer`, any sub-directory's Package.swift is discoverable. If the root were `/Users/coen/Developer/swift-primitives/swift-buffer-primitives`, siblings would not be.

### Option A: Set `rootDir` in cclsp.json (Minimal Fix)

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootDir": "/Users/coen/Developer"
    }
  ]
}
```

**What changes**: SourceKit-LSP gets `/Users/coen/Developer` as the explicit workspace root. No Package.swift there, so no SwiftPM workspace is created at the root level. But implicit workspace discovery now covers the entire Developer tree — any file opened in any sub-package triggers an implicit workspace for that package.

**What works**:
- `find_definition`, `find_references`, `get_hover`, call hierarchy — all work via file-targeted queries
- `find_workspace_symbols` — works **progressively**: scope grows as files are opened and implicit workspaces are created
- Cross-package references — work once both packages have implicit workspaces

**What doesn't**:
- `find_workspace_symbols` at session start — returns empty until files are opened
- Proactive cross-package search without prior file access

**Effort**: One line change. Immediate.

**Locality**: Purely local (`~/.claude/cclsp.json`). No files added to any repository.

### Option B: `rootDir` + Lightweight Root Package.swift

Add both:
1. `rootDir: "/Users/coen/Developer"` in cclsp.json
2. A `Package.swift` at `/Users/coen/Developer` declaring dependencies on key packages

```swift
// /Users/coen/Developer/Package.swift
// Local-only workspace manifest for SourceKit-LSP indexing.
// Not a git-tracked file. Not published anywhere.
import PackageDescription
let package = Package(
    name: "workspace",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Per-monorepo: list the sub-packages needed for indexing
        .package(path: "swift-primitives/swift-buffer-primitives"),
        .package(path: "swift-primitives/swift-memory-primitives"),
        .package(path: "swift-primitives/swift-storage-primitives"),
        // ... more as needed
        .package(path: "swift-standards/swift-iso-8601"),
        .package(path: "swift-foundations/swift-io"),
        // ...
    ],
    targets: []  // No targets needed — just the dependency graph
)
```

**What changes**: SourceKit-LSP discovers the Package.swift at the workspace root, creates a SwiftPM workspace, and resolves the full dependency graph. All symbols in declared packages become immediately available.

**What works**:
- `find_workspace_symbols` — immediate full search across declared packages
- All file-targeted operations — immediate
- Cross-package navigation — immediate

**What doesn't**:
- Packages not listed in the manifest — not indexed (but implicit discovery still catches them on file open)

**Effort**: Low. One cclsp.json change + one Package.swift file.

**Scale concern**: 361 sub-packages as dependencies may cause slow SwiftPM resolution. Mitigation: list only frequently-used packages (~20-30), rely on implicit discovery for the rest.

**Locality**: `cclsp.json` is local. `Package.swift` is in a non-git directory — purely local. No upstream pollution.

### Option C: Multiple CCLSP Server Entries (Per-Monorepo)

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootDir": "/Users/coen/Developer/swift-primitives"
    },
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootDir": "/Users/coen/Developer/swift-standards"
    },
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootDir": "/Users/coen/Developer/swift-foundations"
    }
  ]
}
```

**How CCLSP routes**: `getServerForFile()` picks the server whose `rootDir` is the longest prefix of the file path. Files in swift-primitives route to server 1, files in swift-standards to server 2, etc.

**What works**:
- File-targeted operations within each monorepo — implicit discovery confined to that monorepo
- Three smaller search spaces instead of one huge one

**What doesn't**:
- `find_workspace_symbols` — unclear which server receives the query (no file context to route by). May only search one server.
- Cross-layer references (primitives → standards) — different servers, no cross-server resolution
- Three SourceKit-LSP processes running simultaneously — memory overhead

**Effort**: Low (config only). But limited benefit over Option A.

### Option D: Per-Monorepo Aggregate Package.swift

Add a Package.swift at each monorepo root that declares all sub-packages as dependencies:

```
swift-primitives/Package.swift      → all 132 sub-packages
swift-standards/Package.swift       → all 111 sub-packages
swift-foundations/Package.swift     → all 118 sub-packages
```

Combine with Option A (`rootDir: "/Users/coen/Developer"`) for workspace root.

**What changes**: Each monorepo becomes a single SwiftPM workspace. SourceKit-LSP indexes all modules within each monorepo.

**What works**:
- Full symbol search within each monorepo
- All file-targeted operations

**Concern**: These files WOULD be in git repositories. They are NOT local-only.

**Mitigations**:
- `.gitignore` them — but this hides a potentially useful development artifact
- Commit them — useful for CI, DocC generation, other developers. But represents a structural claim about the monorepo.

**Effort**: Medium. Three Package.swift files with ~100+ dependencies each. Maintenance burden when sub-packages are added.

### Option E: Custom BSP Server

Place a BSP connection file at `/Users/coen/Developer/.bsp/swift-institute.json`:

```json
{
  "name": "Swift Institute",
  "version": "1.0.0",
  "bspVersion": "2.2.0",
  "languages": ["swift"],
  "argv": ["/path/to/swift-institute-bsp"]
}
```

The BSP server would aggregate all packages, responding to `buildTarget/sources` and `textDocument/sourceKitOptions` by delegating to the appropriate sub-package's SwiftPM build system.

**What works**: Everything — the most powerful option. Full workspace-wide search, cross-package references, correct build settings per file.

**Effort**: High. Requires implementing a BSP server. SourceKit-LSP's BSP support is mature but the server itself must handle the aggregation logic.

**Locality**: `.bsp/` directory at non-git root — purely local.

### Option F: Contribute `workspaceFolders` to CCLSP

Fork or PR [ktnyt/cclsp](https://github.com/ktnyt/cclsp) to support an array of workspace folders:

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "workspaceFolders": [
        "/Users/coen/Developer/swift-primitives",
        "/Users/coen/Developer/swift-standards",
        "/Users/coen/Developer/swift-foundations"
      ]
    }
  ]
}
```

The change would modify `server-manager.ts` to send all folders in the LSP `initialize` request:

```typescript
workspaceFolders: (serverConfig.workspaceFolders || [serverConfig.rootDir || process.cwd()])
  .map(dir => ({ uri: pathToUri(dir), name: path.basename(dir) }))
```

SourceKit-LSP would create a `Workspace` instance per folder, with implicit discovery within each.

**What works**: Full multi-root workspace. Cross-package references within each monorepo. No fake Package.swift.

**Effort**: Low code change (~10 lines in cclsp). Requires upstream PR acceptance or fork maintenance.

**Locality**: Fully local (config only). No changes to any repository.

## Comparison

| Criterion | A: rootDir | B: rootDir + Pkg | C: Multi-server | D: Monorepo Pkg | E: BSP | F: CCLSP PR |
|-----------|-----------|------------------|-----------------|-----------------|--------|------------|
| Immediate workspace search | ❌ Progressive | ✅ Declared packages | ❌ Progressive | ✅ All packages | ✅ All | ✅ Progressive |
| Cross-layer search | ✅ (after open) | ✅ (if declared) | ❌ | ❌ (separate) | ✅ | ✅ (after open) |
| Implementation effort | Trivial | Low | Low | Medium | High | Low (PR) |
| Upstream acceptance needed | No | No | No | Possibly | No | Yes |
| Locality (no repo changes) | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Maintenance burden | None | Low | None | High | High | Fork/PR |
| Memory / process overhead | Low | Medium | High (3x) | Medium | Low | Low |
| Scale concern (361 pkgs) | None | Moderate | None | Severe | None | None |

## Outcome

**Status**: RECOMMENDATION

### Recommended: Option A (immediate) + Option F (medium-term)

**Phase 1 — Today**: Apply Option A.

Change `~/.claude/cclsp.json` to:

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "rootDir": "/Users/coen/Developer"
    }
  ]
}
```

This is a one-line change that:
- Fixes the silently-ignored `rootMarkers` problem
- Enables implicit workspace discovery across the entire ecosystem
- Makes all file-targeted CCLSP operations work from any package
- Makes `find_workspace_symbols` progressively useful as files are accessed

The progressive nature is actually well-suited to AI sessions: the AI starts by reading specific files (triggering indexing), then uses workspace search later. By the time workspace search is needed, the relevant packages are already indexed.

**Phase 2 — Medium-term**: Contribute `workspaceFolders` support to CCLSP (Option F).

A small PR to ktnyt/cclsp that:
1. Adds `workspaceFolders?: string[]` to `LSPServerConfig`
2. Sends all folders in the LSP `initialize` request
3. Falls back to `rootDir` or `process.cwd()` if not set

With this, the config becomes:

```json
{
  "servers": [
    {
      "extensions": ["swift"],
      "command": ["sourcekit-lsp"],
      "workspaceFolders": [
        "/Users/coen/Developer/swift-primitives",
        "/Users/coen/Developer/swift-standards",
        "/Users/coen/Developer/swift-foundations"
      ]
    }
  ]
}
```

Each monorepo becomes a proper workspace folder, enabling SourceKit-LSP to discover all sub-packages within each via implicit workspace discovery. No Package.swift needed anywhere.

**Phase 3 — If needed**: Add a lightweight root Package.swift (Option B) listing 20-30 frequently-used packages, to make `find_workspace_symbols` immediately useful at session start. Only pursue if the progressive discovery in Phase 1 proves insufficient.

### Rejected Options

- **Option C (multi-server)**: Three SourceKit-LSP processes with unclear cross-server behavior. Higher resource cost with lower benefit than A.
- **Option D (monorepo Package.swift)**: Violates the locality constraint — adds files to git repos. ~100+ dependency lists with ongoing maintenance. Only justified if these manifests serve other purposes (CI, DocC).
- **Option E (BSP server)**: Disproportionate effort for the problem. Correct engineering, but the simpler options solve the immediate need.

### Also: Remove Dead `rootMarkers` Config

Regardless of chosen option, the `rootMarkers` field should be removed from cclsp.json since it does nothing and creates a false sense of configuration.

## References

- ktnyt/cclsp: https://github.com/ktnyt/cclsp (v0.7.0)
- SourceKit-LSP workspace folders: swiftlang/sourcekit-lsp PR #473
- SourceKit-LSP implicit workspace discovery: swiftlang/sourcekit-lsp PR #1081
- SourceKit-LSP config schema: `Sources/SKOptions/SourceKitLSPOptions.swift`
- Parent research: [ai-context-reduction-via-type-system-tooling.md](ai-context-reduction-via-type-system-tooling.md)
