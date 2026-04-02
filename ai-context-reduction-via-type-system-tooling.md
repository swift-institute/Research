# AI Context Reduction via Type System Tooling

<!--
---
version: 1.0.1
last_updated: 2026-04-01
status: RECOMMENDATION
tier: 2
---
-->

## Context

The Swift Institute architecture encodes functionality as typed primitives with strict composition rules. This has an emergent AI benefit: the AI can *compose* existing infrastructure rather than *regenerating* code, dramatically reducing context window consumption. However, the bottleneck shifts from generation to **discovery** — the AI must know what exists before it can compose.

Three tools are underutilized for this discovery problem:

1. **CCLSP** (Claude Code LSP) — interactive, type-aware symbol queries
2. **Swift Symbol Graph** — batch API surface extraction via the compiler
3. **SwiftPM manifest introspection** — structural dependency and target metadata

This research investigates how to combine these into a pipeline that lets the AI work from type signatures alone, reducing the need to read implementation files.

### Premise: Implementation Follows from Types

In the Swift Institute codebase, function signatures carry almost all the information needed to use them correctly:

```swift
// The signature tells you everything:
static func zeroed(byteCount: Cardinal, alignment: Memory.Alignment)
    throws(Buffer<Element>.Aligned.Error) -> Buffer<Element>.Aligned
```

- **What it does**: creates a zeroed buffer (name)
- **What it needs**: size and alignment (parameters)
- **What can go wrong**: a specific error type (typed throws)
- **What it returns**: a specific buffer type (return type)
- **Ownership semantics**: no `consuming`/`borrowing` → standard value

The implementation is not needed to *use* this correctly. This means an AI that has access to the **signature catalog** can compose solutions without loading implementation files into context.

## Question

How should we structure tooling so the AI can discover and compose the Swift Institute API surface with minimal context consumption?

## Analysis

### Tool Inventory: What We Have

#### CCLSP (Claude Code LSP via MCP)

Available tools, tested 2026-03-10 against swift-buffer-primitives:

| Tool | What It Returns | Status |
|------|----------------|--------|
| `find_workspace_symbols(query)` | Symbols matching a name across workspace | ❌ Empty — no Package.swift at CWD |
| `find_definition(file, symbol)` | Definition locations + full type hierarchy | ✅ Works with specific file paths |
| `find_references(file, symbol)` | All references across workspace | ✅ Works with specific file paths |
| `find_implementation(file, line, char)` | Protocol implementation locations | Untested (needs index) |
| `get_hover(file, line, char)` | Type info, documentation at position | ❌ Timeout — needs build index |
| `get_incoming_calls(file, line, char)` | Call sites of a function | Untested (needs index) |
| `get_outgoing_calls(file, line, char)` | Functions called by a function | Untested (needs index) |
| `get_diagnostics(file)` | Errors, warnings for a file | ✅ Available |
| `prepare_call_hierarchy(file, line, char)` | Prerequisite for call analysis | Untested |

**Key finding**: CCLSP's workspace-level features (`find_workspace_symbols`) require SourceKit-LSP to have a Package.swift at or above the working directory. The CWD `/Users/coen/Developer` has no Package.swift, so workspace queries return empty. File-targeted queries (`find_definition`) work because they trigger single-file indexing.

**Implication**: A root-level Package.swift would unlock workspace-wide symbol search.

#### Swift Symbol Graph (`swift symbolgraph-extract`)

Tested 2026-03-10. Extracts the compiler's own view of the public API surface as structured JSON.

**Extraction command** (requires prior `swift build`):
```bash
SDK=$(xcrun --show-sdk-path) && swift symbolgraph-extract \
  -module-name Module_Name \
  -I .build/debug/Modules \
  -F .build/debug/PackageFrameworks \
  -sdk "$SDK" \
  -target arm64-apple-macosx26.0 \
  -output-dir /tmp/symbolgraph \
  -pretty-print \
  -minimum-access-level public
```

**Output structure** for `Buffer_Primitives_Core` (single module):

| Metric | Value |
|--------|-------|
| File size | 1.1 MB |
| Line count | 43,383 |
| Symbols | 192 |
| Relationships | 339 |

**Symbol data includes**:
- `kind`: Structure, Enumeration, Instance Method, Operator, Instance Property, etc.
- `names.title`: Human-readable name
- `pathComponents`: Full namespace path (e.g., `["Buffer", "Aligned", "copy(from:at:)"]`)
- `declarationFragments`: Full declaration with types, generics, constraints, throws
- `accessLevel`: public/internal

**Relationship data includes**:
- `memberOf`: 191 relationships (type hierarchy)
- `conformsTo`: 148 relationships (protocol conformances)

**Key finding**: This is the richest structured data source. It's the compiler's own API view — guaranteed accurate, includes all generic constraints and typed throws. One module produces a complete, machine-parseable API surface.

**Implication**: A pipeline that extracts symbol graphs for all modules produces a complete API catalog without reading any source files.

#### SwiftPM Manifest Introspection

| Command | Output | Use |
|---------|--------|-----|
| `swift package dump-package` | Full JSON manifest | Targets, dependencies, products |
| `swift package describe` | Human-readable manifest | Quick inspection |

**Key finding**: Provides structural metadata (what depends on what, which files belong to which module) but not API surface. Complementary to symbol graphs.

### Option A: Root Package.swift for CCLSP Workspace Indexing

Add a `Package.swift` at `/Users/coen/Developer` that declares all ecosystem packages as local dependencies.

**What it unlocks**:
- `find_workspace_symbols` across all 361 sub-packages
- `get_hover` with full type information
- Call hierarchy analysis (incoming/outgoing calls)
- Cross-package reference finding

**Challenges**:
- 361 sub-packages is extreme for SwiftPM resolution
- SourceKit-LSP indexing time could be prohibitive
- Memory pressure from full dependency graph
- Risk of constant re-indexing during development

**Mitigation**: Layered Package.swift files:
```
/Users/coen/Developer/Package.swift          → all layers (for occasional full-index)
  or per-layer:
swift-primitives/Package.swift (existing per-sub-package)
swift-standards/Package.swift  (existing per-sub-package)
swift-foundations/Package.swift (existing per-sub-package)
```

Alternatively, use existing `.xcworkspace` files (`Primitives.xcworkspace`, `Standards.xcworkspace`) — SourceKit-LSP can use `buildServer.json` to delegate to Xcode's build system, which already understands workspaces.

**Verdict**: High value, uncertain feasibility at full scale. Start with per-layer workspace manifests.

### Option B: Symbol Graph Pipeline (Batch API Inventory)

Build a script that:
1. Iterates all sub-packages
2. Builds each (or uses cached `.build/`)
3. Extracts symbol graphs for all public modules
4. Produces a compressed API inventory

**Output format** — a condensed signature catalog per module:

```
# Buffer_Primitives_Core (192 symbols)

## Types
Buffer (enum)
Buffer.Aligned (struct) : ~Copyable
Buffer.Arena (struct) : ~Copyable
Buffer.Growth (enum)
Buffer.Linear (struct) : ~Copyable
Buffer.Linked (struct) : ~Copyable
Buffer.Ring (struct) : ~Copyable
Buffer.Slab (struct) : ~Copyable
Buffer.Slots (struct) : ~Copyable
Buffer.Unbounded (struct)

## Buffer.Aligned
  static zeroed(byteCount:alignment:) throws(Buffer.Aligned.Error) -> Buffer.Aligned
  copy(from:at:) mutating (Span<UInt8>, Int) -> Void
  zero() mutating -> Void
  withUnsafeBytes<R,E>(_:) (UnsafeRawBufferPointer) throws(E) -> R
  withRawSpan<R,E>(_:) (RawSpan) throws(E) -> R
  isAligned(to:) (Memory.Alignment) -> Bool
  subscript(_:) Int -> UInt8 { get set }
```

**Context cost**: ~20-50 lines per module vs. thousands of lines of source. For 361 packages, a full catalog might be 10K-20K lines — large but feasible as a reference file, or partitioned by layer/domain.

**Key advantage**: Produced by the compiler, so guaranteed to match reality. No hallucination risk. Can be regenerated on every build.

**Key advantage for meta-analysis**: The structured JSON enables automated pattern checking (see Option D).

**Verdict**: High value, straightforward implementation. Most impactful single improvement.

### Option C: CCLSP for Interactive Composition (Hybrid)

Use the symbol graph catalog for discovery ("what exists?") and CCLSP for interactive queries during implementation ("how does this connect?").

**Workflow**:
1. AI reads condensed catalog → knows `Buffer.Ring` exists, sees its signature shape
2. AI needs to compose `Buffer.Ring` with `IO.Handle` → uses `find_references` to see how others compose them
3. AI writes code → uses `get_diagnostics` to verify correctness without full build
4. AI investigates a call chain → uses `get_incoming_calls`/`get_outgoing_calls`

**What this replaces**: Currently the AI reads source files to understand both API surface AND composition patterns. With the hybrid approach:
- API surface → catalog (zero source reading)
- Composition patterns → CCLSP references (targeted, not bulk)
- Correctness → diagnostics (compiler feedback without full build)

**Verdict**: Ideal end state. Requires Option B (catalog exists) and partial Option A (CCLSP works for at least the active package).

### Option D: Signature Shape Meta-Analysis

Because implementation follows from types, analyzing the *shape* of signatures across the ecosystem reveals patterns, gaps, and inconsistencies without reading any implementation code.

**Analyses enabled by symbol graph data**:

| Analysis | What It Detects | Mechanism |
|----------|----------------|-----------|
| Typed throws compliance | Functions using untyped `throws` | Check `declarationFragments` for `throws` without `(ErrorType)` |
| ~Copyable consistency | Types missing expected constraints | Check `conformsTo` relationships, `swiftGenerics` constraints |
| Method shape consistency | `Buffer.Ring` has `append` but `Buffer.Linear` doesn't | Compare method sets across sibling types |
| Naming compliance | Compound names, missing namespaces | Check `pathComponents` against [API-NAME-001] patterns |
| Convention completeness | Every `~Copyable` container should have `consume`/`move` | Check method presence against expected patterns |
| Unused conformances | Protocol conformance without using protocol methods | Cross-reference `conformsTo` with actual method calls |
| Signature symmetry | `init` without corresponding `deinit`, `encode` without `decode` | Pair analysis on method names |

**Example**: Typed throws audit via symbol graph:

```python
# Find all functions that throw but don't use typed throws
for symbol in symbols:
    frags = symbol['declarationFragments']
    decl = ''.join(f['spelling'] for f in frags)
    if ' throws ' in decl and 'throws(' not in decl:
        print(f"UNTYPED: {'.'.join(symbol['pathComponents'])}: {decl}")
```

This replaces reading hundreds of source files. The `typed-throws-standards-inventory.md` research document was produced manually — this would automate it.

**Integration with existing-infrastructure skill**: The symbol graph can *generate* the infrastructure catalog automatically, keeping it perpetually accurate instead of manually maintained.

**Verdict**: Force multiplier. Enables convention compliance verification at ecosystem scale.

## Comparison

| Criterion | A: Root Package.swift | B: Symbol Graph Pipeline | C: Hybrid CCLSP | D: Meta-Analysis |
|-----------|----------------------|------------------------|-----------------|-----------------|
| Implementation effort | Low (1 file) | Medium (script) | Low (workflow change) | Medium (script) |
| Feasibility risk | High (361 packages) | Low (proven today) | Low (given A+B) | Low (proven today) |
| Context reduction | High (interactive) | Very high (catalog) | Very high (combined) | N/A (analytical) |
| Ongoing maintenance | Auto (SwiftPM) | Script per build | None | Script per build |
| Prerequisite | None | `swift build` per package | A + B | B |
| Value for AI | Interactive queries | Static discovery | Full workflow | Quality assurance |

## Outcome

**Status**: RECOMMENDATION

### Recommended Implementation Order

**Phase 1: Symbol Graph Pipeline** (Option B)
- Build a script that extracts symbol graphs from all built modules
- Produce a condensed signature catalog per layer
- Store at `swift-institute/Infrastructure/api-catalog/` or similar
- Integrate into `existing-infrastructure` skill as the authoritative source
- **Immediate payoff**: AI can discover and compose from signatures without reading source

**Phase 2: Root Package.swift** (Option A — scoped)
- Start with per-monorepo workspace-level Package.swift files (primitives, standards, foundations)
- These already have `.xcworkspace` files — explore `buildServer.json` for SourceKit-LSP delegation
- Test whether SourceKit-LSP can index at this scale
- If viable, add a root-level `/Users/coen/Developer/Package.swift` that unifies all layers
- **Payoff**: CCLSP workspace queries, hover, call hierarchy

**Phase 3: Meta-Analysis Scripts** (Option D)
- Build scripts that run against the symbol graph JSON:
  - Typed throws compliance checker
  - Naming convention verifier ([API-NAME-001], [API-NAME-002])
  - Method shape consistency across sibling types
  - Conformance completeness checker
- Produce reports as research documents or CI artifacts
- **Payoff**: Automated convention enforcement at ecosystem scale

**Phase 4: Hybrid Workflow** (Option C)
- Document the AI workflow: catalog → CCLSP → diagnostics
- Update skills to reference the API catalog instead of manual lists
- **Payoff**: Minimal context consumption for routine development

### Phase 1 Execution: 2026-03-15

Phase 1 has been executed. See [primitives-public-api-graph-analysis.md](primitives-public-api-graph-analysis.md) for full results.

Key outcomes:
- Symbol graph extraction works across 115/132 packages (17 empty/failed)
- Distilled into 9.8 MB JSON: 435 modules, 13,262 symbols, 19,022 relationships
- Cross-module relationships ARE captured via the `@Module.symbols.json` extension files
- JSON proved to be the right catalog format — analyzable by scripts, fits in AI context as summary
- Scripts stored at `swift-primitives/Scripts/{extract,distill,analyze}-symbol-graphs.*`

### Open Questions

1. **Scale limit**: Can SourceKit-LSP index 361 packages simultaneously? Need empirical test.
2. **Incremental extraction**: Can symbol graphs be extracted incrementally (only changed modules)?
3. ~~**Catalog format**~~: JSON confirmed as the right format. Resolved by Phase 1.
4. **Catalog freshness**: How to keep the catalog in sync with code changes? Pre-commit hook? Build phase?
5. ~~**Cross-module relationships**~~: The `@Module.symbols.json` files capture these. Resolved by Phase 1.

## References

- Swift Symbol Graph format: produced by `swift symbolgraph-extract`, consumed by DocC
- SourceKit-LSP: https://github.com/swiftlang/sourcekit-lsp
- Existing research: `typed-infrastructure-catalog.md` (manually maintained; Option D could automate)
- Existing research: `typed-throws-standards-inventory.md` (manually produced; Option D example)
- Existing skill: `existing-infrastructure` (Option B output would feed this)
