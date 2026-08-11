# swift-package-graph — Design

<!--
---
version: 1.1.0
last_updated: 2026-05-14
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-package-graph]
normative: true
---
-->

## Changelog

- **v1.1.0 (2026-05-14)**: Realigned to the L1/L2/L3 split per `swift-institute/Research/swift-package-domain-l1-l2-split.md`. swift-package-graph now imports the SwiftPM-typed manifest model from the new L2 `swift-spm-standard` rather than assuming an L1 surface that would mix universal vocabulary with SwiftPM-specific types. Drops the assumption that swift-package-graph owns `Package.Manifest` definition (it doesn't — that's L2's job); swift-package-graph owns the *graph*, *queries*, and *loading-against-the-typed-manifest*.
- **v1.0.0 (2026-05-14)**: Initial RECOMMENDATION. Superseded by v1.1.0 on the same day.

## Context

### Trigger

The Institute is a 141-package SwiftPM ecosystem across 9 tiers. Multiple emerging tools need queryable access to the package-level dependency graph: build-impact orchestration (`swift-impact`), release-readiness pre-tag verification, audit blast-radius computation, version-bump propagation, and the swift-institute.org ecosystem visualization. Today, each of these would either re-derive the graph from scratch or compose primitives ad-hoc.

The existing `swift-foundations/swift-dependency-analysis` package was structurally similar to what's needed here but is **stale** (per principal 2026-05-14). Reviving it carries unrelated revival cost; superseding it with a fresh, narrowly-scoped foundation is the cleaner move.

### Scope

This document specifies `swift-foundations/swift-package-graph` v0.1.0 — an L3 Foundation owning the "package-level dependency graph from a local SwiftPM workspace" domain. Out of scope: the manifest *types themselves* (those are L2, owned by swift-spm-standard); build orchestration (lives in `swift-impact`); source-level API diff (lives in the existing `lint-api-breakage` workflow).

### Prior research

- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 (2026-05-14) — established that no off-the-shelf CI/CD or SwiftPM-native tool implements downstream-impact analysis.
- **`swift-institute/Research/swift-package-domain-l1-l2-split.md` v1.0.0 (2026-05-14)** — the parent architecture doc. Establishes the L1 generic + L2 SwiftPM-specific split. swift-package-graph consumes the L2 model (swift-spm-standard) rather than redefining or extending L1.
- `swift-institute/Skills/swift-institute/SKILL.md` — five-layer architecture.
- `swift-institute/Skills/existing-infrastructure/SKILL.md` — consulted during 2026-05-14 dep audit.

---

## Question

How should the Institute provide a reusable, queryable package-level dependency graph derived from a local SwiftPM workspace, such that build orchestration / release-readiness / audit / version-bump tools can consume it without each re-deriving the graph?

Decomposes into:

1. **Domain mandate**: what does swift-package-graph own; what does it not own?
2. **Manifest substrate**: where does the typed manifest model live; how does swift-package-graph load values into it?
3. **Graph type**: how does it compose `swift-graph-primitives` with the L2 manifest payload?
4. **Public API surface**: workspace discovery, forward queries, reverse queries, cycle detection, topological order, visualization.
5. **CLI surface**: what subcommands does the `package-graph` executable expose?
6. **Layer placement**: L3 (composed building block).

---

## Analysis

### Q1 — Domain mandate

**Owns**:

- Discovery of SwiftPM packages on a local filesystem (walking directory tree, locating `Package.swift` files).
- Loading: invoking `swift package dump-package` per package via `swift-process`; JSON-decoding the output into the L2 `Package.Manifest` type (from swift-spm-standard) via that type's Codable conformance.
- Construction of a typed `Package.Graph` value composing `swift-graph-primitives`.
- Query APIs: forward dependencies, reverse dependencies, transitive closures, topological order, cycle detection, SCC, DOT visualization.
- A CLI binary `package-graph` exposing those queries as subcommands.

**Does not own**:

- The manifest **types themselves** (→ `swift-spm-standard` at L2).
- The generic `Package.Name` / `Product.Name` / `Target.Name` identifiers (→ `swift-package-primitives` at L1).
- Build orchestration / running `swift build` (→ `swift-impact`).
- Source-level API delta / `swift package diagnose-api-breaking-changes` (→ existing `lint-api-breakage.yml`).
- SwiftPM-DSL evaluation for Institute config files (→ `swift-manifests`; distinct domain).
- Remote dependency resolution (would compose with a future `swift-package-resolver` if needed).
- Manifest *mutation* (writing back). v0.1 is read-only; if mutation surfaces as a need with a second direct consumer, an L3 `swift-package-manager` foundation gets authored.

### Q2 — Manifest substrate

Per the L1/L2 split doc, the typed manifest model **lives at L2 in swift-spm-standard**. swift-package-graph imports those types; it does not redefine or extend them.

What swift-package-graph does add is the **loading pipeline**:

```
For each Package.swift under <workspace-root>:
  1. swift-process spawns: `swift package dump-package --package-path <pkg-dir>`
  2. Captures stdout (JSON), stderr (diagnostics)
  3. swift-json decodes stdout into Package.Manifest (from swift-spm-standard)
  4. On non-zero exit: surface Process.Status + stderr in Package.Graph.Error
```

Bounded concurrency per `Workspace.Configuration.maxConcurrentLoads` (default = `activeProcessorCount`). The loader is internal to swift-package-graph for v0.1; if a second direct-consumer for the loader emerges, extract to an L3 `swift-package-manager` foundation (per `[RES-018]`).

### Q3 — Graph type composition

`swift-graph-primitives` provides (verified 2026-05-14):

- `Graph.Sequential<Tag, Payload>` — concrete graph value (~Copyable Builder for construction)
- `Graph.Node<Tag>` — typed node identifier
- `.reversed()` — transpose the graph
- `.reachable(from: roots)` / `.reachable(to: target)` — closure queries (BFS/DFS)
- `.breadth(...)` / `.depth(...)` — explicit traversals
- `.topological()` — sort
- `.scc()` — strongly connected components
- `.hasCycles()`, `.shortest(from:to:)`, `.transitiveClosure()`

**swift-package-graph parameterization**:

- `Tag = Package.Name` (from swift-package-primitives at L1 — the generic typed identifier)
- `Payload = Package.Manifest` (from swift-spm-standard at L2 — the SwiftPM-typed manifest stored as the per-node payload)

Reverse-dep query: `graph.reversed().reachable(from: upstreamNode)` — one composition. The graph's payload (`Package.Manifest`) is fully typed; queries that need richer per-package information (kind, platforms, settings) read from the payload without separate lookups.

### Q4 — Public API surface

Per `[API-NAME-001]` nested-namespace conventions:

**Types defined in swift-package-graph** (the thin slice):

```swift
extension Package {
  /// A discovered workspace: the on-disk root + loaded manifests for the
  /// packages found within.
  public struct Workspace: ~Copyable, Sendable {
    public static func discover(
      at: File.Path.Directory,
      configuration: Package.Workspace.Configuration = .init()
    ) async throws(Workspace.Error) -> Self

    public var root: File.Path.Directory { get }
    public var manifests: some Collection<Package.Manifest> { get }   // type from swift-spm-standard
  }

  /// The queryable dependency graph.
  public struct Graph: ~Copyable, Sendable {
    public init(_ workspace: borrowing Package.Workspace) throws(Graph.Error)

    // Forward queries
    public func directDependencies(of: Package.Name) -> some Collection<Package.Name>
    public func transitiveDependencies(of: Package.Name) -> Set<Package.Name>

    // Reverse queries — the swift-impact substrate
    public func directDependents(of: Package.Name) -> some Collection<Package.Name>
    public func transitiveDependents(of: Package.Name, depth: Int) -> [Package.Graph.Wave]

    // Diagnostics
    public func cycles() -> [Package.Graph.Cycle]
    public func topologicalOrder() throws(Graph.Error) -> [Package.Name]
    public func stronglyConnectedComponents() -> [[Package.Name]]

    // Payload access (the manifest is stored as the graph payload)
    public func manifest(for: Package.Name) -> Package.Manifest?

    // Visualization
    public func dot() -> String
  }
}

extension Package.Workspace {
  public struct Configuration: Sendable {
    public var maxDepth: Int                   // discovery depth; default 2
    public var maxConcurrentLoads: Int         // default = activeProcessorCount
    public var swiftExecutable: String?        // explicit path override; nil = $PATH
  }

  public struct Error: Swift.Error, Sendable, Hashable {
    case rootDoesNotExist(File.Path.Directory)
    case noPackagesFound(File.Path.Directory)
    case manifestLoadFailed(package: String, reason: String)
  }
}

extension Package.Graph {
  public struct Wave: Sendable, Hashable {
    public var depth: Int
    public var packages: Set<Package.Name>
  }

  public struct Cycle: Sendable, Hashable {
    public var nodes: [Package.Name]
  }

  public struct Error: Swift.Error, Sendable, Hashable {
    case workspaceLoadFailed(reason: String)
    case manifestLoadFailed(package: String, reason: String)
    case dumpPackageNonZeroExit(package: String, status: Process.Status)
    case invalidManifestJSON(package: String, reason: String)
    case noTopologicalOrder   // graph has cycles
  }
}
```

**Types imported from other layers**:

| Type | From | Layer |
|---|---|---|
| `Package.Name`, `Product.Name`, `Target.Name` | swift-package-primitives | L1 |
| `Package.Manifest`, `Package.Dependency`, `Package.Requirement`, `Manifest.Product`, `Manifest.Target`, `TargetDependency` | **swift-spm-standard** | **L2** |
| `Graph.Sequential`, `Graph.Node`, `Graph.Adjacency.*` | swift-graph-primitives | L1 |
| `File.Path.Directory`, `File.Directory` | swift-path-primitives + swift-file-system | L1 + L3 |
| `Process.Spawn`, `Process.Status`, `Process.Stream` | swift-process | L3 |
| `JSON` parsing primitives | swift-json | L3 |

**Types newly defined here**: `Package.Workspace`, `Package.Workspace.Configuration`, `Package.Workspace.Error`, `Package.Graph`, `Package.Graph.Wave`, `Package.Graph.Cycle`, `Package.Graph.Error`. Seven types total — genuinely thin.

### Q5 — Dependencies

| Dep | Layer | Role | Status |
|---|---|---|---|
| **swift-spm-standard** | **L2** | **The typed manifest model: `Package.Manifest`, `Package.Dependency`, `Package.Requirement`, `Package.Manifest.Product/Target`, `TargetDependency`, `SupportedPlatform`. Plus the JSON Codable conformances for `swift package dump-package` wire format.** | **NEW; to author per L1/L2 split doc** |
| swift-package-primitives | L1 | Generic `Package.Name`, `Product.Name`, `Target.Name` typed identifiers | Exists; needs refactor to remove SwiftPM-flavored types per L1/L2 split |
| swift-version-primitives | L1 | `Version.Semantic`, `Version.Tools`, `Version.Range` for Requirement/SupportedPlatform versions | Exists; rich |
| swift-graph-primitives | L1 | `Graph.Sequential` + reverse/reachable/topological/SCC algorithms | Exists; rich |
| swift-path-primitives | L1 | Path vocabulary | Exists |
| swift-property-primitives | L1 | Typed properties for internal state | Exists |
| swift-process | L3 | Spawn `swift package dump-package` subprocess | Exists; reliable per 2026-05-14 audit |
| swift-file-system | L3 | Walk workspace, locate `Package.swift` files | Exists; reliable |
| swift-json | L3 | Parse `dump-package` JSON output | Exists; reliable |
| swift-async | L3 | Bounded-concurrency manifest loading | Exists; reliable |
| swift-console | L3 | CLI output formatting for `package-graph` executable | Exists; active dev |

**No external dependencies.** The CLI uses minimal hand-rolled argument parsing in v0.1 (~80 lines for the 7 subcommands), migratable to a future `swift-command-line-interface` L3 foundation when it lands.

### Q6 — CLI surface

The `package-graph` executable exposes subcommand-driven graph queries (read-only against the local workspace):

| Subcommand | Behavior |
|---|---|
| `package-graph dependents-of <package> [--depth N]` | Reverse-dep query; N=1 default (direct), N=∞ (transitive) |
| `package-graph dependencies-of <package> [--depth N]` | Forward-dep query |
| `package-graph topo` | Topological order over the whole workspace |
| `package-graph cycles` | List all cycles (empty output if acyclic) |
| `package-graph scc` | Strongly connected components |
| `package-graph dot [-o file.dot]` | Emit GraphViz DOT for visualization |
| `package-graph list` | List all discovered packages |

Default workspace root is `$PWD`; `--root <path>` overrides. Output format defaults to human-readable; `--json` switches to structured output for tooling consumption.

### Q7 — `[RES-018]` Premature Primitive check (re-evaluated)

Per the L1/L2 split doc, the heavier lift (the manifest *model*) is now hosted at L2 in swift-spm-standard, with that L2 package's own `[RES-018]` justification independently established. For swift-package-graph (this L3 foundation):

1. **"Why not compose existing primitives?"** — swift-spm-standard provides the typed manifest; swift-graph-primitives provides graph algorithms; swift-process + swift-json + swift-file-system provide the loading plumbing. Each consumer wanting reverse-dep queries (swift-impact, future audit, future release-readiness, future version-bump, dashboard) would otherwise re-implement: workspace discovery + concurrent subprocess dispatch + JSON decode + graph construction + reverse-traversal driving. That's ~300 LOC duplicated per consumer.

2. **"Is there a second consumer?"** — Five named consumers:

   | Consumer | Use of swift-package-graph |
   |---|---|
   | swift-impact (immediate) | `directDependents(of:)` for matrix construction; `transitiveDependents` for `--wave N` |
   | Future release-readiness pre-tag gate | `transitiveDependents` to enumerate "what will break if this package bumps version" |
   | Future audit tooling | `transitiveDependencies` + `transitiveDependents` for blast-radius assessment |
   | Future swift-version-bump | `topologicalOrder` for tag propagation order |
   | swift-institute.org dashboard | `dot()` for ecosystem visualization |

Hurdle cleared.

### Q8 — Layer placement: L3

L3 ("composed building blocks") fits because:

- The library composes L1 + L2 + sibling L3 deps downward.
- It does I/O (filesystem walk + subprocess invocation) — clearly above L1/L2's pure-data mandate.
- Its mandate (the "package dep graph as a queryable structure" domain) is a foundation other foundations build on, not an opinionated assembly (which would be L4 components).

The CLI binary `package-graph` is a convenience product of the library, packaged together per Institute convention.

---

## Outcome

**Status: RECOMMENDATION**

Proceed to scaffold `swift-foundations/swift-package-graph` (after the L1/L2 split's Phase 0a/0b/0c complete) with:

- **Products**: `Package Graph` (library), `package-graph` (executable)
- **Targets**: `Package Graph`, `Package Graph Tests`, `package-graph` (executable target)
- **Dependencies**: as enumerated in Q5 (10 Institute deps; zero external; **load-bearing new dep: swift-spm-standard L2**)
- **Public surface**: as sketched in Q4 (7 newly-defined types; everything else imported from L1/L2)
- **CLI**: as sketched in Q6 (7 subcommands; hand-rolled arg parsing in v0.1)
- **Visibility**: public from day 1 (`[CI-032]`)
- **CI**: thin caller `ci.yml` calling `swift-foundations/.github/.../swift-ci.yml@main`

## Migration: swift-dependency-analysis

Once swift-package-graph v0.1.0 ships:

1. Add a deprecation notice to swift-dependency-analysis's `README.md` pointing to swift-package-graph.
2. Update `.github/metadata.yaml` to mark it archived.
3. Preserve git history.
4. Migrate any discovered existing dependents case-by-case.

## Open questions

1. **`Package.Workspace.discover` recursion depth**: depth-2 default (Institute's `~/Developer/swift-primitives/*/` shape); `--max-depth` flag for deeper workspaces.

2. **Mirror-resolved deps vs URL-declared deps**: the SwiftPM mirror at `~/Library/org.swift.swiftpm/configuration/mirrors.json` substitutes URLs to local paths transparently at SwiftPM-resolve time. `swift package dump-package` reports the URL form (the declared form), not the mirrored form. swift-package-graph treats the URL's package-name component as the node identifier (matches Institute convention). Cross-org collision is theoretically possible but not present today; document the constraint.

3. **Concurrent manifest loading bound**: default = `activeProcessorCount`. Caller overrides via `Configuration.maxConcurrentLoads`. Each `swift package dump-package` invocation is ~3–10s; the 141-package cold load is ~30–60s with 8-way concurrency.

4. **Caching the resolved graph across CLI invocations**: re-resolving 141 packages on every `package-graph` invocation is slow. v0.1: no caching, measure. v0.2: optional cache at `.swift-package-graph/cache.json` keyed on each Package.swift's mtime + content hash. Defer.

5. **`swift package dump-package` JSON schema versioning**: SwiftPM's output schema is pinned to Swift 6.3+ for swift-spm-standard's Codable conformances. swift-package-graph inherits that pin. Revisit at Swift 7.

6. **Granularity: target vs package**: v0.1 operates at **package granularity** (the user's stated use case). Target-level granularity is a v0.2+ extension (would surface `Module.Name` from swift-module-primitives + the manifest's `targets[*].dependencies` as a second-tier graph).

7. **Cycle handling in concurrent loading**: `Package.Workspace.discover` does not yet detect cycles — that's the graph's job. If a malformed workspace causes `swift package dump-package` to loop, the bounded concurrency + per-subprocess timeout (default 60s per `Process.Spawn.Configuration.timeout`) caps the damage.

## References

### Verified primary sources (2026-05-14)

See `swift-institute/Research/swift-package-domain-l1-l2-split.md` § References for the L1 + L2 + L3 dep API surveys this document inherits.

Additional probes specific to swift-package-graph:

- `/Users/coen/Developer/swift-primitives/swift-graph-primitives/Sources/Graph Primitives Core/` — `Graph.Sequential<Tag, Payload>` + `.reversed()` + `.reachable(...)` + `.topological()` + `.scc()` confirmed.
- `/Users/coen/Developer/swift-foundations/swift-process/Sources/` — `Process.Spawn.Configuration` accepts executable + arguments; returns `Process.Status` with `.exited(code:)` discriminant.
- `/Users/coen/Developer/swift-foundations/swift-json/Sources/` — `JSON.parse(_:)` for strings + bytes; typed errors via `Parser.Error.Located<JSON.Error>`.

### Internal cross-references

- `swift-institute/Research/swift-package-domain-l1-l2-split.md` v1.0.0 — **parent architecture doc**; defines the L1 generic / L2 SwiftPM-specific split this design assumes.
- `swift-institute/Research/downstream-impact-ci-for-swiftpm-ecosystems.md` v1.0.0 — grandparent arc establishing the need for downstream-impact tooling.
- `swift-institute/Skills/swift-institute/SKILL.md` — five-layer architecture.
- `swift-institute/Skills/swift-package/SKILL.md` — `[PKG-NAME-*]`, `[PKG-DEP-*]`.
- `swift-institute/Skills/research-process/SKILL.md` — `[RES-018]` (cleared in Q7), `[RES-020]` (parallel verification applied), `[RES-026]` (citations applied).
- `swift-institute/Skills/code-surface/SKILL.md` — `[API-NAME-001]`, `[API-NAME-002]`, `[API-ERR-001]`, `[API-IMPL-005]`.

### Sibling-package cross-references

- `swift-foundations/swift-impact/Research/design.md` (companion, pending) — the immediate consumer.
- `swift-standards/swift-spm-standard/` (pending) — the L2 dependency that provides `Package.Manifest`.
- `swift-foundations/swift-dependency-analysis` — superseded by this package; archived post-v0.1.0.
