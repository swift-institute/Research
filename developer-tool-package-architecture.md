# Developer Tool Package Architecture

<!--
---
version: 1.1.0
last_updated: 2026-04-13
status: DECISION
tier: 3
---
-->

## Context

The Swift Institute ecosystem has no precedent for developer tool packages. Tooling exists only as ad hoc shell scripts (`detect-redundant-deps.sh`, `regenerate-compile-commands.sh`, `generate-compile-commands.py`). As the ecosystem grows, algorithmic tooling — dependency analysis, convention verification, API surface diffing — needs a principled home.

This research establishes the architectural pattern for developer tool packages, using redundant dependency detection as the first case study. The decisions here set precedent: every future tool package will follow or explicitly deviate from this pattern.

**Trigger**: Manual cleanup of `swift-pdf-html-rendering` found 4 redundant dependencies (CSS Standard, W3C CSS, ISO 9899, IEC 61966 — all transitively provided via CSS). The existing bash script (`detect-redundant-deps.sh`) works but lacks target-level granularity, is fragile to Package.swift formatting, and cannot be tested or extended as infrastructure.

## Questions

1. **General**: Where do developer tool packages sit in the five-layer architecture, and what structural conventions should they follow?
2. **Specific**: How should a redundant dependency detection tool be designed as a Swift package — parsing strategy, type architecture, algorithm, and CLI interface?

---

## Part I: Prior Art Survey

### §1.1 Systematic Literature Review

Per [RES-023], Tier 3 requires SLR methodology (Kitchenham).

**Research questions**:
- RQ1: What algorithms do existing tools use to detect unused/redundant package dependencies?
- RQ2: At what granularity (symbol, module, package) do they operate?
- RQ3: How do they handle transitive dependencies and re-exports?

**Search strategy**: Surveyed dependency analysis tools across 6 major package ecosystems (Rust/Cargo, Node.js/npm, Go, Swift/SwiftPM, JVM/Maven+Gradle, Python/pip). Sources: tool repositories (GitHub), official documentation, conference talks, Swift Evolution proposals, Swift Forums.

**Inclusion criteria**: Tools that detect unused or redundant *declared* dependencies. **Exclusion**: Tools that only detect unused *code* (e.g., dead code eliminators), tools for version resolution only.

### §1.2 Findings by Ecosystem

#### Rust (Cargo)

Three tools span the accuracy-speed spectrum:

| Tool | Approach | Speed | Transitive |
|------|----------|-------|------------|
| **cargo-udeps** | Build-based: compiles, inspects linked artifacts | Slow (full build) | Cannot distinguish direct vs. transitive usage |
| **cargo-machete** | Regex scanning of source files for `use crate_name` | Fast | No analysis |
| **cargo-shear** | AST parsing via rust-analyzer's parser | Fast | No analysis |

cargo-udeps requires nightly Rust and is reportedly broken with recent cargo/workspace changes. cargo-machete has false positives from substring matches. cargo-shear misses macro-generated imports unless `--expand` (nightly-only) is used.

**Key insight**: No Rust tool detects *redundant* dependencies (transitively provided by another dep). They only detect *unused*.

#### Node.js (npm)

**depcheck**: Pluggable architecture with parsers (ES6, JSX, TypeScript), detectors (`require()`, `import`), and specials (config-file scanners for ESLint, webpack, Babel). Compares `package.json` against detected usage. No transitive analysis. False positives for config-only deps (mitigated by specials plugins). False negatives for dynamic `require()`.

#### Go

**`go mod tidy`**: Built into the toolchain. Scans `.go` files for `import` statements, cross-references against `go.mod`. Adds missing modules, removes unused. Indirect dependencies preserved with `// indirect` annotations. Platform-specific build tags can cause incorrect pruning.

**Key insight**: Go's approach is the most integrated (toolchain-native) and the only one that *modifies* the manifest automatically.

#### JVM (Maven + Gradle)

**Maven `dependency:analyze`**: Bytecode analysis of compiled `.class` files. Reports three categories: used+declared, **used+undeclared** (transitive promotion candidates), unused+declared. This is the only tool surveyed that identifies dependencies used only through transitive paths — the closest analogue to our REDUNDANT classification.

**Gradle Dependency Analysis Plugin**: Same bytecode approach. Can automatically promote transitive deps to direct declarations.

**Key insight**: Bytecode analysis catches everything the compiler sees (including inlined constants, removed annotations) but requires a full build.

#### Swift

**No unused dependency detection exists.** SwiftPM diagnoses *missing* dependencies (SE-0443 diagnostic groups) but not unused ones. SwiftLint's `unused_import` rule operates at the file-import level, not package-dependency level. Periphery detects unused *code declarations*, not unused dependencies.

**Gap in the ecosystem**: No tool maps unused imports back to `Package.swift` dependency declarations.

#### Python

**deptry**: Rust-based scanner, compares `import` statements against `pyproject.toml`. Detects unused, missing, and transitive. **py-unused-deps**: Inspects distribution metadata. Both miss dynamic imports (`importlib.import_module`).

### §1.3 Cross-Cutting Synthesis

| Dimension | Build-based | AST/Import scanning | Regex scanning |
|-----------|-------------|---------------------|----------------|
| Accuracy | Highest (sees compiler output) | Medium (misses macros/codegen) | Lowest |
| Speed | Slow (full build) | Fast | Fastest |
| Macro/codegen handling | Handled (expanded at build) | Missed | Missed |
| Transitive insight | Maven: yes. Rust: limited. | Go: yes. Others: no. | No |
| REDUNDANT detection | Maven only | None | None |

**Critical observation**: No tool in any ecosystem performs the REDUNDANT classification that our tool targets — detecting dependencies that are *imported but transitively available through another dependency's re-exports*. Maven's "used but undeclared" is the inverse operation (finding transitive deps that should be promoted). Our tool's REDUNDANT analysis is novel.

**Our position on the spectrum**: Import scanning (AST-level via `dump-package` + source scanning), with transitive analysis via `@_exported` chain traversal. This places us between cargo-shear (AST but no transitive) and Maven (transitive but build-based). The feasibility of this middle ground exists because Swift's re-export mechanism (`@_exported import`) is explicit and statically discoverable — unlike most languages where transitive visibility is implicit.

---

## Part II: Theoretical Grounding

### §2.1 Dependency Graphs

A **package dependency graph** is a directed acyclic graph G = (P, D) where:
- P is the set of packages (each with identity and filesystem path)
- D ⊆ P × P is the dependency relation (p₁ depends on p₂)

A **module graph** within a package is M = (T, I) where:
- T is the set of targets (each producing a module)
- I ⊆ T × T is the import relation (module t₁ imports module t₂)

The import relation is further partitioned:

I = I_regular ∪ I_exported

where I_exported ⊆ I are `@_exported import` edges.

### §2.2 Transitive Visibility

Define the **provides** relation as the reflexive transitive closure of I_exported:

provides(t) = {t} ∪ { t' | t →*_exported t' }

That is: module t provides itself and everything reachable through chains of `@_exported import`.

In the Swift Institute ecosystem, `@_exported` chains are declared in `exports.swift` files and follow a consistent convention: each module re-exports its direct dependencies that should be transitively visible to consumers.

### §2.3 Classification Semantics

Given:
- A target τ with declared product dependencies D(τ) = {d₁, d₂, ..., dₙ}
- Each dᵢ maps to a module mᵢ (via product name → module name conversion: spaces → underscores)
- The set of modules actually imported in τ's source files: imports(τ)

Classification of each dependency dᵢ:

```
classify(dᵢ, τ) =
  | UNUSED     if mᵢ ∉ imports(τ)
  | REDUNDANT  if mᵢ ∈ imports(τ) ∧ ∃ dⱼ ∈ D(τ), j ≠ i :
                    mⱼ ∈ imports(τ) ∧ mᵢ ∈ provides(mⱼ)
  | NEEDED     otherwise
```

In prose:
1. **UNUSED**: The module is never imported in the target's source files.
2. **REDUNDANT**: The module is imported, but some *other* dependency (which is itself imported) transitively provides it via `@_exported` chains.
3. **NEEDED**: The module is imported and not available through any other imported dependency.

### §2.4 Soundness Argument

**Claim**: The classification never produces false NEEDED results — if a dependency is classified NEEDED, removing it will cause a compilation failure.

**Proof sketch**:
- If classify(dᵢ, τ) = NEEDED, then mᵢ ∈ imports(τ) (the module is imported) and no other imported dependency provides mᵢ.
- Removing dᵢ from D(τ) removes mᵢ from the set of available modules.
- Since no other dependency provides mᵢ (by the NEEDED condition), the `import mᵢ` statements will fail to resolve.
- Therefore, compilation will fail. ∎

**Caveat — false REDUNDANT risk**: If the provider dⱼ is itself REDUNDANT, removing both dᵢ and dⱼ would leave mᵢ unprovided. However, the tool's output is actionable in sequence: remove UNUSED first, then re-run to re-classify remaining dependencies. Alternatively, the algorithm could resolve to the *ultimate* provider (the NEEDED dependency at the root of the provides chain). See §4.5.

**Caveat — incomplete provides()**: The provides relation is computed by BFS through `exports.swift` files. If a module uses `@_exported import` outside of `exports.swift`, the chain will be incomplete, potentially classifying a REDUNDANT dependency as NEEDED (false NEEDED — conservative, safe). The ecosystem convention of centralizing re-exports in `exports.swift` makes this unlikely in practice.

### §2.5 MemberImportVisibility Interaction

Swift's `MemberImportVisibility` feature (enabled ecosystem-wide) requires that modules providing member declarations be explicitly imported. `@_exported import` satisfies this requirement: if module A does `@_exported import B`, then any file importing A can use B's members without separately importing B.

This was validated empirically: `swift-institute/Experiments/member-import-visibility-reexport/`.

Therefore, the provides() relation correctly models module visibility under MemberImportVisibility.

---

## Part III: Architectural Analysis

### §3.1 Question: Where Do Tools Sit in the Five-Layer Architecture?

Developer tools are *not* library infrastructure — they don't provide types or protocols consumed by other packages. They consume the ecosystem to analyze it. This places them outside the five-layer stack.

#### Option A: Layer 0 — Tooling Layer Below Primitives

A dedicated tooling layer that depends on nothing in the ecosystem. Tools parse manifests and scan source files directly, without importing any Institute packages.

**Advantages**: Complete independence. Tools can analyze any package without circular dependency concerns.
**Disadvantages**: Invents a new architectural concept. No precedent in the five-layer model.

#### Option B: swift-institute/Tools/

Tools live alongside documentation, skills, and research in the Institute repository. Not a Swift package — just scripts or standalone executables.

**Advantages**: Centralized. Already has `generate-compile-commands.py` as precedent.
**Disadvantages**: Not a proper Swift package. Cannot be tested with Swift Testing. Cannot leverage SwiftPM for dependency management (e.g., ArgumentParser).

#### Option C: Standalone Tool Packages in Developer/

Independent Swift packages, one per tool (e.g., `swift-{tool-name}`). Not part of any super-repo. Use SwiftPM for structure, ArgumentParser for CLI, and can be built/tested independently.

**Advantages**: Proper Swift package with full tooling (tests, dependencies, versioning). Independent — no circular dependency risk. Can serve as case study for tool package patterns.
**Disadvantages**: Proliferates top-level directories. No clear grouping for tools vs. library packages.

#### Option D: Tools Super-Repo

A `swift-tools/` super-repo analogous to `swift-primitives/`, `swift-standards/`, `swift-foundations/`, containing all developer tool packages.

**Advantages**: Clean grouping. Follows the super-repo pattern. Discoverable.
**Disadvantages**: Premature if we only have 1-2 tools. The super-repo pattern implies a cohesive layer, but tools are heterogeneous (dependency analysis, convention checking, API diffing share little code).

### §3.2 Comparison

| Criterion | Option A | Option B | Option C | Option D |
|-----------|----------|----------|----------|----------|
| Proper Swift package | Yes | No | Yes | Yes |
| Testable | Yes | Limited | Yes | Yes |
| Independent of ecosystem | Yes | N/A | Yes | Yes |
| Precedent in ecosystem | No | Partial | No | Pattern exists |
| Scalable to many tools | With layer | No | Cluttered | Yes |
| Premature abstraction risk | Medium | None | None | High (1-2 tools) |

### §3.3 Recommendation

**Option C now, Option D later.** Start with a standalone `swift-dependency-analysis/` package in `Developer/`. If more tools emerge and share infrastructure (e.g., a common manifest parsing library), promote to a `swift-tools/` super-repo. This follows the Institute principle of not abstracting prematurely.

**Layer placement**: The tool depends on primitives (L1: graph-primitives, set-primitives, dictionary-primitives) and foundations (L3: json, file-system, paths, console). This places it at **Layer 3 (Foundations)** or above. Since it composes L1 and L3 packages into an opinionated assembly, **Layer 4 (Components)** is the natural fit — but the tool is not a library consumed by others, so layer placement is descriptive rather than constraining.

**Dog-fooding**: The tool imports ecosystem packages as compiled dependencies and reads ecosystem packages' manifests/sources as runtime data. These are orthogonal relationships — no circularity. This follows the same pattern as swift-testing (which tests packages that depend on it) and the nested `Tests/Package.swift` pattern ([INST-TEST-001]).

---

## Part IV: Case Study — Redundant Dependency Detection

### §4.1 Manifest Parsing Strategy

Three approaches for extracting structured package manifest data:

#### Strategy 1: Regex Parsing of Package.swift

The existing bash script's approach. Parse `.package(path:)` and `.product(name:, package:)` with line-by-line regex.

**Failure modes**:
- Multi-line declarations (product declaration split across lines)
- Whitespace variations (`.package(path:"...")` vs `.package(path: "...")`)
- Comments containing matching patterns
- Cannot distinguish which products belong to which target

#### Strategy 2: `swift package dump-package` + Codable

Shell out to `swift package dump-package`, which outputs the fully resolved manifest as JSON. Parse with Codable into typed Swift models.

**Output structure** (empirically verified):
```
Package
  ├── name: String
  ├── dependencies: [PackageDependency]     — .fileSystem with identity + path
  └── targets: [Target]
        ├── name: String
        ├── type: "regular" | "test" | ...
        ├── path: String?                   — nil = convention (Sources/{name} or Tests/{name})
        └── dependencies: [TargetDependency]
              ├── .product(name, package, ...)
              └── .byName(name, ...)
```

**Advantages**: Structured, reliable, handles all formatting. SwiftPM's own serialization — guaranteed to match what SwiftPM sees. Per-target dependency information directly available.
**Disadvantages**: Requires shelling out to `swift package`. ~1-2 seconds per invocation. Requires Swift toolchain installed (guaranteed in our context).

#### Strategy 3: SwiftPM Command Plugin

Use PackagePlugin API for structured access to the package graph.

**Disadvantages** (decisive): Must be declared as a dependency of the analyzed package. Cannot run independently. Single-package scope.

#### Decision: Strategy 2

`swift package dump-package` provides exactly the structured data needed with no fragility. The ~1-2 second overhead per package is acceptable (and parallelizable across packages with Swift concurrency).

### §4.2 Type Architecture

Following [API-NAME-001] (namespace structure), [API-IMPL-005] (one type per file), [API-ERR-001] (typed throws), [IMPL-INTENT] (code reads as intent).

```
Dependency                          — namespace enum (top-level domain)
  Dependency.Analysis               — orchestrator: phases 1–5 composed as intent
  Dependency.Analysis.Configuration — analysis options (target filter, verbosity)
  Dependency.Analysis.Result        — per-package result with per-target breakdown
  Dependency.Analysis.Error         — typed error: .packageNotFound, .manifestParseFailed, .targetSourceNotFound

Dependency.Classification           — enum: .unused, .redundant(via:), .needed

Dependency.Target                   — parsed target with name, type, deps, source path
  Dependency.Target.Kind            — enum: .regular, .test, .plugin, ...

Dependency.Module                   — module identity (name, source directory)
  Dependency.Module.Graph           — wraps graph-primitives' directed graph for the @_exported relation
  Dependency.Module.Import          — a parsed import statement (module name, file path)

Dependency.Manifest                 — Codable model matching `swift package dump-package` JSON
  Dependency.Manifest.Target        — JSON target: name, type, dependencies, path
  Dependency.Manifest.Reference     — JSON package dependency: identity, path

Dependency.Report                   — formatted output (text, json, markdown)
  Dependency.Report.Entry           — single dependency classification with context
```

**Naming rationale per [API-NAME-001]**:
- `Dependency` is the domain namespace — "a declared package dependency" is the unit of analysis
- `Dependency.Manifest` (not `Dependency.Package`) avoids collision with SwiftPM's `Package` type and names the actual artifact: the JSON manifest output from `dump-package`
- `Dependency.Module.Graph` nests under `Module` because the graph models the module-level `@_exported` relation, not package-level dependency

**Infrastructure consumed** (not reinvented):
- `Graph BFS Primitives` or `Graph Reachable Primitives` → the provides() computation in Phase 3 is a reachability query on the `@_exported` directed graph. Graph-primitives provides this algorithm; `Dependency.Module.Graph` wraps the graph representation and delegates traversal.
- `swift-json` → `Dependency.Manifest` and subtypes decode directly from the dump-package JSON
- `swift-file-system` → directory scanning in Phases 2 and 4

**File layout** (one type per file, per [API-IMPL-005]):
```
Sources/
  Dependency Analysis/
    Dependency.swift                          — namespace enum
    Dependency.Analysis.swift
    Dependency.Analysis.Configuration.swift
    Dependency.Analysis.Result.swift
    Dependency.Analysis.Error.swift
    Dependency.Classification.swift
    Dependency.Target.swift
    Dependency.Target.Kind.swift
    Dependency.Module.swift
    Dependency.Module.Graph.swift
    Dependency.Module.Import.swift
    Dependency.Manifest.swift
    Dependency.Manifest.Target.swift
    Dependency.Manifest.Reference.swift
    Dependency.Report.swift
    Dependency.Report.Entry.swift
    exports.swift
  Dependency Analysis CLI/
    main.swift                                — ArgumentParser @main entry point
```

### §4.3 Algorithm (Per-Target Granularity)

The algorithm has 5 phases, matching the formal semantics in §2.3 but operating per-target:

**Phase 1: Parse Manifest**
```
Input:  Package directory path
Action: Run `swift package dump-package`, decode JSON via Codable
Output: Dependency.Package (targets, package-level dependencies, resolved paths)
```

**Phase 2: Build Module Index**
```
Input:  Resolved dependency package paths
Action: For each dependency package, scan Sources/*/ directories
        Map: module name (spaces → underscores) → source directory path
Output: [String: URL] module → source directory
```

**Phase 3: Compute provides() — reachability over @_exported graph**
```
Input:  Module index from Phase 2
Action: 1. Build directed graph G where edge (a, b) means module a has
           `@_exported import b` in its exports.swift
        2. For each module m, compute provides(m) = reachable(m, G) ∪ {m}
           using graph-primitives' BFS reachability (Graph BFS Primitives
           or Graph Reachable Primitives — not hand-rolled)
Output: Dependency.Module.Graph — wraps the reachability result
```

**[IMPL-INTENT] compliance**: The call site reads as "compute what each module provides" —
the BFS mechanism lives inside graph-primitives. The tool expresses intent (reachability query),
not mechanism (queue management, visited tracking).

**Phase 4: Scan Target Imports**
```
Input:  Each target's source directory
Action: For each target τ:
          Scan all .swift files in Sources/{τ.name}/ (or τ.path if specified)
          Extract import statements, normalize to module names
          Filter: strip `import struct/class/enum/protocol/func/typealias/var/let`
          Filter: strip submodule paths (import Foo.Bar → Foo)
Output: imports(τ) per target
```

**Phase 5: Classify Per-Target**
```
Input:  D(τ), imports(τ), provides()
Action: For each declared product dependency dᵢ of target τ:
          Apply classification function from §2.3
Output: Dependency.Analysis.Result per target
```

### §4.4 Error Handling

Per [API-ERR-001] (typed throws) and [IMPL-041] (error type nesting):

```swift
// Error nested under the type that throws it — per [IMPL-041]
extension Dependency.Analysis {
    public enum Error: Swift.Error, Hashable, Sendable {
        case packageNotFound(path: String)
        case manifestParseFailed(underlying: String)
        case targetSourceNotFound(target: String, expectedPath: String)
    }
}

// Typed throws — per [API-ERR-001]
extension Dependency.Analysis {
    public static func analyze(
        package path: String,
        configuration: Configuration
    ) throws(Error) -> Result { ... }
}
```

Error cases describe the failure domain, not the mechanism. `.packageNotFound` tells the caller *what* went wrong; the caller decides *how* to respond.

### §4.5 Open Design Questions

#### Q1: Transitive REDUNDANT Resolution

When C is redundant via B, and B is redundant via A, the current algorithm reports "C via B". Should it resolve to the ultimate NEEDED provider?

**Option 1: Immediate provider** — report "C via B". Simple, matches the direct re-export chain.
**Option 2: Ultimate provider** — report "C via A". More accurate for the removal action (you'd remove both B and C, keeping only A).
**Option 3: Both** — report "C via B (ultimately via A)".

**Recommendation**: Option 2 (ultimate provider). The actionable information is "which NEEDED dependency makes this one removable." Computing this requires a second pass after initial classification, resolving the provider chain until reaching a NEEDED dependency.

#### Q2: Cross-Target Dependency Analysis

A package dependency is declared at the package level (`.package(path:)`), but products are consumed per-target. If product P is needed by target A but not target B, the *package* dependency is still needed. The tool should report per-target classifications but roll up to a package-level recommendation.

**Roll-up rule**: A package-level dependency is removable only if ALL of its products are UNUSED or REDUNDANT across ALL targets.

#### Q3: Internal Target Dependencies

Targets can depend on other targets in the same package via `.byName()` or `.target()`. These are not external dependencies and should be excluded from analysis. The dump-package JSON distinguishes these via the dependency kind (`byName` vs `product`).

#### Q4: Tests/Package.swift

Per [INST-TEST-001], performance/snapshot test dependencies live in `Tests/Package.swift`. The tool should be able to analyze this nested package independently. When analyzing the parent package, test targets in the parent should only reference the parent's own modules — any external test framework dependency in the parent is a smell worth flagging.

#### Q5: `@_exported` Outside exports.swift

The algorithm only follows `@_exported` chains through `exports.swift` files. A module could re-export via `@_exported import` in any file. This is a conservative design choice — it may miss some transitive visibility, leading to false NEEDED (safe) but never false REDUNDANT (dangerous).

**Trade-off**: Scanning all `.swift` files for `@_exported` would be more complete but significantly slower and noisier (some files might conditionally re-export). The ecosystem convention strongly centralizes re-exports in `exports.swift`. Accept the conservative approach.

---

## Part V: Implementation Considerations

### §5.1 Dependencies

The tool dog-foods the ecosystem — using Institute packages for graph traversal, JSON parsing, file system access, and console output. This is not circular: the tool *imports* these packages as compiled dependencies, and *reads* other packages' manifests and source files as data at runtime. These are orthogonal relationships, analogous to how swift-testing tests packages that depend on swift-testing (see [INST-TEST-001]).

#### Tier 1: Core Algorithm

| Dependency | Purpose | Layer |
|------------|---------|-------|
| **swift-graph-primitives** | BFS reachability for provides() computation via `@_exported` chains | L1 Primitives |
| **swift-json** | Parse `swift package dump-package` JSON output via Codable | L3 Foundations |
| **swift-file-system** | Scan Sources/ directories, read exports.swift, discover .swift files | L3 Foundations |

#### Tier 2: Supporting Infrastructure

| Dependency | Purpose | Layer |
|------------|---------|-------|
| **swift-dictionary-primitives** | Module name → source directory index | L1 Primitives |
| **swift-set-primitives** | Visited tracking, import deduplication | L1 Primitives |
| **swift-paths** | Path resolution for relative `.package(path:)` declarations | L3 Foundations |
| **swift-console** | Colored terminal output (✓/✗, UNUSED/REDUNDANT/NEEDED) | L3 Foundations |

#### Tier 3: CLI

| Dependency | Purpose | Layer |
|------------|---------|-------|
| **swift-argument-parser** | CLI interface (@main, @Argument, @Flag) | External (Apple) |

#### Not Needed

| Rejected | Why |
|----------|-----|
| Foundation | swift-json replaces JSONDecoder, swift-file-system replaces FileManager |
| swift-parsers | Import statement parsing is simple enough for direct string matching |
| swift-tree-primitives | The provides() graph is flat (adjacency), not hierarchical |
| swift-dependency-primitives | Models DI-style dependencies, not package manifest dependencies |

### §5.1a Infrastructure Applicability

The [INFRA-*] catalog from the existing-infrastructure skill is designed for primitives-internal code (typed arithmetic, Property.View, ~Copyable patterns, pointer operations). Most of it does NOT apply to this tool — the tool works with strings, paths, JSON, and graphs, not with raw memory or phantom-typed indices.

**Applicable**:
- [IMPL-INTENT] — all code reads as intent, mechanism lives in dependencies
- [IMPL-EXPR-001] — prefer single expressions (e.g., Phase 3 as a reachability call, not manual BFS)
- [IMPL-000] — call-site-first: write the ideal expression, improve infrastructure if it doesn't compile
- [API-ERR-001] + [IMPL-041] — typed throws with nested error enums
- [API-NAME-001] + [API-NAME-002] — namespace structure, no compound identifiers
- [API-IMPL-005] — one type per file

**Not applicable** (primitives-internal infrastructure):
- [INFRA-101–105] — Cardinal/Ordinal/Affine/Finite typed arithmetic (tool uses stdlib `Int`, `String`, `URL`)
- [INFRA-106] — Property<Tag, Base> / Property.View (tool types are Copyable, no accessor namespace needed)
- [INFRA-107–109] — Sequence iteration, bit vectors, storage primitives (internal data structure machinery)
- [INFRA-110] — Static method architecture for ~Copyable overloads (not applicable)

**Principle**: The tool is a *consumer* of the ecosystem, not an *extension* of it. It should use the ecosystem's infrastructure where it solves a real problem (graph-primitives for BFS, swift-json for parsing) but not adopt internal patterns (typed arithmetic, Property.View) that don't serve its domain.

### §5.2 Concurrency Strategy

For `--all` mode (scanning multiple packages), packages can be analyzed concurrently:

```swift
try await withThrowingTaskGroup(of: Dependency.Analysis.Result.self) { group in
    for package in packages {
        group.addTask { try await analyze(package: package) }
    }
    // collect results
}
```

Each `swift package dump-package` invocation is I/O-bound (~1-2s), so concurrent execution across packages provides significant speedup.

### §5.3 Testing Strategy

Per [TEST-*] and [INST-TEST-*]:

**Unit tests** (Apple Testing, parent Package.swift):
- Classification algorithm with synthetic inputs (no filesystem)
- Module graph BFS with in-memory graphs
- Import statement parsing with sample strings
- Codable decoding of dump-package JSON (fixture files)

**Integration tests** (parent Package.swift):
- Analyze a known test fixture package with expected classifications
- Verify against the current ecosystem (swift-buffer-primitives, etc.)

**Performance tests** (Tests/Package.swift, swift-testing):
- Full analysis of swift-foundations (largest package) within time budget
- Module graph BFS scaling with deep @_exported chains

### §5.4 CLI Interface

```
USAGE: dependency-analysis <package-directory>
       dependency-analysis --all [base-directory]

OPTIONS:
  --target <name>     Analyze specific target only
  --format <format>   Output format: text (default), json, markdown
  --verbose           Show per-target breakdown even for needed deps
  --help              Show help information
```

---

## Part VI: Empirical Validation

### §6.1 Cognitive Dimensions Assessment

Per [RES-025], evaluating the API design against the Cognitive Dimensions Framework:

| Dimension | Assessment |
|-----------|------------|
| **Visibility** | High — classification names (UNUSED, REDUNDANT, NEEDED) are self-descriptive. The `via` attribution explains causality. |
| **Consistency** | High — follows ecosystem naming conventions ([API-NAME-001]). One type per file. Typed throws throughout. |
| **Viscosity** | Low — adding a new classification or analysis phase requires minimal changes (add enum case, add phase function). |
| **Role-expressiveness** | High — `Dependency.Classification.redundant(via:)` carries its meaning. `Dependency.Module.Graph` names what it is. |
| **Error-proneness** | Low — typed throws prevent error erasure. Per-target analysis prevents the original script's pooling bug. |
| **Abstraction** | Appropriate — no premature abstractions. Each type maps to a concrete domain concept. |

### §6.2 Known Validation Target

The tool's first validation should reproduce the manually-discovered result from `swift-pdf-html-rendering`:
- CSS Standard → REDUNDANT (via CSS)
- W3C CSS → REDUNDANT (via CSS)
- ISO 9899 → REDUNDANT (via CSS)
- IEC 61966 → REDUNDANT (via CSS)

If the tool does not reproduce this known result, the algorithm has a bug.

---

## Outcome

**Status**: IN_PROGRESS

**Decisions made**:
1. Developer tools live as standalone packages in `Developer/`, outside the five-layer architecture (Option C, §3.3)
2. Manifest parsing via `swift package dump-package` + Codable (Strategy 2, §4.1)
3. Per-target granularity with package-level roll-up (§4.3, Q2)
4. Ultimate provider resolution for REDUNDANT chain (§4.5, Q1 — tentative)
5. Conservative @_exported scanning (exports.swift only) (§4.5, Q5)

**Next steps**:
1. Resolve open design questions (§4.5 Q1-Q5) — discuss with co-architect
2. Create `swift-dependency-analysis/` package with type structure from §4.2
3. Implement Phase 1 (Codable models for dump-package JSON)
4. Implement Phases 2-5 with unit tests against fixtures
5. Validate against swift-pdf-html-rendering (§6.2)
6. Run `--all` across ecosystem, review results

## References

### Tools Surveyed
- cargo-udeps: https://github.com/est31/cargo-udeps
- cargo-machete: https://github.com/bnjbvr/cargo-machete
- cargo-shear: https://github.com/Boshen/cargo-shear
- depcheck (npm): https://github.com/depcheck/depcheck
- deptry (Python): https://github.com/fpgmaas/deptry
- Periphery (Swift): https://github.com/peripheryapp/periphery
- Maven dependency:analyze: https://maven.apache.org/plugins/maven-dependency-plugin/analyze-mojo.html

### Swift Evolution / Forums
- SE-0443: Precise Control Flags over Compiler Warnings
- Swift Forums: "Should SwiftPM diagnose missing dependencies?" (2024)
- SwiftLint unused_import rule: https://realm.github.io/SwiftLint/unused_import.html

### Ecosystem
- MemberImportVisibility + @_exported validation: `swift-institute/Experiments/member-import-visibility-reexport/`
- Manual redundancy discovery: `swift-pdf-html-rendering` cleanup (2026-03-13)
- Existing bash prototype: a local `detect-redundant-deps.sh` script
