# Intra-Package Modularization Patterns

<!--
---
version: 1.2.0
last_updated: 2026-04-16
status: SUPERSEDED
tier: 2
type: pattern-extraction
superseded_by: modularization skill [MOD-001..016]
---
-->

## Context

The swift-primitives monorepo contains 128 packages. Many are single-product packages (one library target + test support), but the most architecturally instructive packages decompose into multiple targets within a single package. The modularization decisions in these multi-product packages follow recurring patterns that have not been extracted into a skill.

**Trigger**: The existing skill set covers file-level organization ([API-IMPL-005–008] in **code-organization**) and inter-package layering ([API-LAYER-001–002] in **design**, [PRIM-ARCH-001–002] in **primitives**, [ARCH-LAYER-001] in **swift-institute**). There is no skill governing the **intra-package** level: when to create separate targets within a package, how to structure their dependencies, and how to compose them for consumers.

**Scope**: Primitives-wide. The patterns appear in multiple packages across different tiers. Findings should be promoted to a `modularization` skill per [RES-006a].

**Evidence base**: Eleven exemplar packages analyzed in depth:

| Package | Products | Tier | Decomposition Axis |
|---------|----------|------|---------------------|
| swift-parser-primitives | 35 + test support | 10 | Combinator algebra |
| swift-buffer-primitives | 14 + test support | 15 | Storage strategy |
| swift-storage-primitives | 10+ + test support | 14 | Storage variant + heap/inline |
| swift-memory-primitives | 5 + test support | 13 | Allocation strategy |
| swift-array-primitives | multi + test support | 15 | Constraint isolation (Core vs conformance) |
| swift-stack-primitives | multi + test support | 15 | Constraint isolation (Core vs conformance) |
| swift-queue-primitives | multi + test support | 16 | Constraint isolation (Core vs conformance) |
| swift-slab-primitives | multi + test support | 10 | Constraint isolation (Core vs conformance) |
| swift-set-primitives | multi + test support | 15 | Constraint isolation (Core vs conformance) |
| swift-dictionary-primitives | multi + test support | 16 | Constraint isolation (Core vs conformance) |
| swift-index-primitives | 2 + test support | 6 | Minimal (Core → umbrella) |

## Question

What are the recurring intra-package modularization patterns in swift-primitives, and can they be codified into auditable requirements for a skill?

## Analysis

### Pattern 1: Core Layer

**Observation**: Every multi-product package has a `{Domain} Primitives Core` target that contains namespace enums, foundational protocols, and minimal type definitions.

**Instances**:

| Package | Core Target | Core Contents | Core Dependencies |
|---------|-------------|---------------|-------------------|
| parser | Parser Primitives Core | `Parser` namespace, `Parser.Protocol`, `Parser.Printer`, `Parser.Serializer`, Input type aliases | Input Primitives, Array Primitives (external) |
| buffer | Buffer Primitives Core | `Buffer` namespace, header types, growth policy | Storage, Cyclic Index, Memory, Bit Vector (external) |
| memory | Memory Primitives Core | `Memory` namespace, address types, layout types | Ordinal, Cardinal, Affine, Identity, Property, Bit (external) |
| index | Index Primitives Core | `Index` namespace, bounded index types | Ordinal, Cardinal, Affine, Comparison, Identity, Property (external) |

**Common elements**:
- Core holds the namespace enum and foundational protocol(s)
- Core is the sole target that directly depends on external packages
- Every other target in the package depends on Core (directly or transitively)
- Core re-exports external dependencies via `@_exported public import` in `exports.swift`

**Rationale**: Core acts as the dependency funnel. External package changes affect one target, not N targets.

---

### Pattern 2: Variant Decomposition

**Observation**: Domain-specific implementations are isolated into separate targets along a single decomposition axis.

**Instances**:

| Package | Axis | Variants |
|---------|------|----------|
| buffer | Storage strategy | Ring, Linear, Slab, Linked, Slots, Arena |
| memory | Allocation strategy | Arena, Pool |
| parser (combinators) | Combinator operation | OneOf, Map, FlatMap, Filter, Conditional, Optional, Skip, Many, Take |
| parser (terminals) | Terminal behavior | Always, Fail, Rest, End |
| parser (tracking) | Position concern | Tracked, Spanned, Span, Locate |

**Common elements**:
- Each variant depends on Core + only the siblings it genuinely uses
- Variants are independent of each other (no Ring → Linear dependency)
- Variant complexity ranges from 2 files (simple) to 8 files (with builders and type-erased forms)
- The decomposition axis names a single conceptual dimension (strategy, operation, behavior)

**Rationale**: Variant independence enables selective import. A consumer needing only `Parser_Map_Primitives` pays no compile-time cost for OneOf's result builders.

---

### Pattern 3: Inline Variant Satellite

**Observation**: In buffer-primitives, heap-allocated variants have corresponding inline (fixed-capacity) satellite targets.

**Instances**:

| Heap Variant | Inline Satellite | Additional Satellite |
|-------------|-----------------|---------------------|
| Buffer Ring Primitives | Buffer Ring Inline Primitives | — |
| Buffer Linear Primitives | Buffer Linear Inline Primitives | Buffer Linear Small Primitives |
| Buffer Slab Primitives | Buffer Slab Inline Primitives | — |
| Buffer Linked Primitives | Buffer Linked Inline Primitives | — |
| Buffer Arena Primitives | Buffer Arena Inline Primitives | — |

**Dependency direction**: Inline always depends on Heap (never reverse). Small depends on both Linear and Linear Inline.

**Common elements**:
- Heap variant is self-contained (Core + external deps)
- Inline variant adds Core + Heap variant as dependencies
- Small/composite variants layer on top of both
- This creates a 2-3 tier mini-hierarchy within a single decomposition axis

**Rationale**: The inline variant reuses the heap variant's type definitions and algorithms, adding only the fixed-capacity storage specialization. Separating them means consumers who don't need inline storage never compile it.

---

### Pattern 4: Constraint Isolation (Core for ~Copyable Hygiene)

**Observation**: Storage, buffer, and data structure packages uniformly split into a `* Core` target that defines types with `~Copyable` element support, and variant targets that add protocol conformances carrying `Copyable` constraints. This is the dominant modularization driver for the entire data structure stack.

**The problem**: Swift's `Sequence` and `Collection` protocols (both stdlib and custom) carry an implicit `Element: Copyable` constraint through their associated types. If a generic type `Array<Element: ~Copyable>` directly conforms to `Collection` in the same module where it is defined, the conformance **poisons** the type — all downstream uses inherit the `Element: Copyable` requirement, even code paths that never iterate.

**The solution**: Separate the type definition (Core) from the protocol conformance (variant module). Code that needs `Array<FileHandle>` where `FileHandle: ~Copyable` imports only Core and uses span-based or direct subscript access. Code that needs `for element in array` imports the variant module and accepts the `Element: Copyable` constraint.

**Instances across the data structure stack**:

| Package | Core Target | Core Provides | Variant Targets | Variants Add |
|---------|-------------|---------------|-----------------|-------------|
| storage | Storage Primitives Core | `Storage.Heap<E: ~Copyable>`, `Storage.Inline<E: ~Copyable>`, move/copy primitives | Heap, Inline, Pool, Arena, Split, Slab + Inline variants | Property views, bulk operations |
| buffer | Buffer Primitives Core | `Buffer.Linear<E: ~Copyable>`, `Buffer.Ring<E: ~Copyable>`, headers, growth policy | Ring, Linear, Slab, Linked, Slots, Arena + Inline variants | Sequence/Collection conformances |
| array | Array Primitives Core | `Array<E: ~Copyable>`, `Array.Fixed`, `Array.Static`, `Array.Small`, `Array.Bounded`, subscript | Dynamic, Fixed, Static, Small, Bounded | `Swift.Sequence`, `Swift.Collection` conformance (forces `E: Copyable`) |
| stack | Stack Primitives Core | `Stack<E: ~Copyable>`, push/pop, peek | Dynamic, Static, Small | `Swift.Sequence`, `Swift.Collection` conformance |
| queue | Queue Primitives Core | `Queue<E: ~Copyable>`, enqueue/dequeue | Dynamic, Fixed, Static, Small, Linked, DoubleEnded | `Swift.Sequence`, `Swift.Collection` conformance |
| slab | Slab Primitives Core | `Slab<E: ~Copyable>`, insert/remove by handle | Dynamic, Static | `Sequence.Drain.Protocol` conformance |
| set | Set Primitives Core | `Set.Ordered<E: ~Copyable>`, hash table bookkeeping | Ordered | `Swift.Sequence`, `Swift.Collection` conformance |
| dictionary | Dictionary Primitives Core | `Dictionary.Ordered<K, V: ~Copyable>`, key-value storage | Ordered, Bounded, Slab | `Swift.Sequence`, `Swift.Collection` conformance |

**Dependency structure** (consistent across all instances):

```
External deps (Index, Memory, Property, etc.)
        ↓
  {Domain} Primitives Core          ← defines types with Element: ~Copyable
        ↓                              NO Collection/Sequence dependency
  {Domain} {Variant} Primitives     ← adds conformances
        ↓                              IMPORTS Collection/Sequence Primitives
        ↓                              CONSTRAINT: Element: Copyable in scope
  {Domain} Primitives (umbrella)    ← re-exports everything
```

**What Core deliberately excludes**:
- `Swift.Sequence` / `Swift.Collection` conformances
- `Sequence.Protocol` / `Collection.Protocol` conformances (custom protocols)
- `Sequence.Drain.Protocol` conformances
- Property views that iterate (`.forEach`, `.withElement`)
- Any API whose signature or implementation requires `Element: Copyable`

**What Core retains**:
- Type definitions with `Element: ~Copyable`
- Direct subscript access (index-based, no iteration)
- Span-based access (borrowed, no copy)
- Mutating operations (append, push, enqueue, insert, remove)
- Count, capacity, isEmpty
- Deinit

**Evidence from research**: The `Resource Management Assessment` (data structures/) confirms this is deliberate:

> `Sequence.Drain.Protocol` conformance is declared on types (`Slab.Static`, `Slab.Indexed`) outside their defining module (`Slab Primitives Core`). This is a deliberate split to avoid ~Copyable constraint poisoning from `Sequence.Drain.Protocol`'s `associatedtype Element` (which implies `Copyable`). Correctly architected.

**Why this is unique to Swift**: Most languages don't distinguish between copyable and move-only types at the type system level. In Rust, `Clone` is explicit and opt-in. In C++, move semantics are implicit. Swift's `~Copyable` makes the distinction structural, which means protocol conformances can silently inject constraints that propagate through the entire dependency graph. Module separation is the only defense.

**Rationale**: Without this split, a package claiming `Element: ~Copyable` support would be lying — the conformance would force `Copyable` at every use site. The Core target keeps the type signature honest.

---

### Pattern 5: Umbrella Re-export

**Observation**: Every multi-product package has an umbrella target whose `exports.swift` contains only `@_exported public import` statements — zero implementation code.

**Instances**:

| Package | Umbrella | Re-exports |
|---------|----------|------------|
| parser | Parser Primitives | 35 targets |
| buffer | Buffer Primitives | 13 targets |
| memory | Memory Primitives | Core + StdLib Integration + Arena + Pool |
| index | Index Primitives | Core only |

**The exports.swift pattern**:
```swift
// Parser Primitives/exports.swift — complete file
@_exported public import Parser_Primitives_Core
@_exported public import Parser_Error_Primitives
@_exported public import Parser_Match_Primitives
// ... (32 more)
```

**Common elements**:
- Umbrella product name matches the package domain: `{Domain} Primitives`
- Umbrella target depends on ALL sub-targets (in Package.swift dependencies)
- Umbrella contains exactly one file: `exports.swift`
- Consumer choice: `import Parser_Primitives` (everything) or `import Parser_Map_Primitives` (selective)

**Rationale**: The umbrella enables convenience without sacrificing granularity. It is purely a consumer ergonomics layer.

---

### Pattern 5: Standard Library Integration Module

**Observation**: When a package extends stdlib types, those extensions live in a dedicated `{Domain} Primitives Standard Library Integration` target.

**Instances**:

| Package | Integration Target | Content |
|---------|-------------------|---------|
| memory | Memory Primitives Standard Library Integration | Extensions on `UnsafePointer`, `UnsafeBufferPointer`, etc. |

**Common elements**:
- Depends on Core only
- Contains extensions on Swift standard library types (not on package types)
- Re-exported by the umbrella, but available for selective import
- Only present when stdlib extensions exist (parser-primitives has none)

**Rationale**: Stdlib extensions can cause implicit member resolution conflicts if imported broadly. Isolating them lets consumers who don't need stdlib interop avoid the extensions.

---

### Pattern 6: Test Support Product

**Observation**: Every package publishes a `{Domain} Primitives Test Support` library product.

**Instances**:

| Package | Test Support Dependencies |
|---------|--------------------------|
| parser | Umbrella + Input Primitives Test Support + Array Primitives |
| buffer | Umbrella + Storage/Cyclic Index/Bit Vector/Memory Test Support |
| memory | Umbrella + Identity/Index/Ordinal/Cardinal/Affine Test Support |
| index | Umbrella + Identity/Ordinal/Cardinal/Affine Test Support |

**Common elements**:
- Published as a library product (visible to downstream packages)
- Depends on the umbrella (full API access for test helpers)
- Depends on upstream packages' test support products (re-exports test fixtures)
- Located at `Tests/Support/` (non-standard path declared in Package.swift)
- Contains test fixture types, convenience initializers, and re-exports

**Rationale**: Downstream packages need test fixtures for types from upstream. Publishing test support as a product creates a parallel dependency graph for testing infrastructure.

---

### Pattern 7: Dependency Minimization

**Observation**: Each target declares exactly the dependencies it needs — no convenience imports, no "pull in everything" shortcuts.

**Evidence from parser-primitives** (34 non-umbrella targets):

| Dependency Count | Targets | Examples |
|-----------------|---------|----------|
| Core only (1 dep) | 11 targets | Optional, Peek, Always, Fail, Rest, Lazy, Trace, Parse, Spanned, Constraint, EndOfInput |
| Core + 1 sibling | 9 targets | Map, FlatMap, Skip, Conditional, OneOf (+ Error), Not (+ Match), End (+ Match), Consume (+ Constraint) |
| Core + 2 siblings | 7 targets | Filter, Prefix, First, Tracked, Locate, Byte, Conformance |
| Core + 3 siblings | 3 targets | Span, Literal, Discard |
| Core + 5 siblings | 1 target | Take |
| Core + Take | 1 target | Many |

**Mean sibling dependencies per target**: 1.2

**Rationale**: Minimal dependencies keep incremental compile times proportional to the change. Adding a feature to Parser Error Primitives recompiles only the ~12 targets that depend on it, not all 34.

---

### Pattern 8: External Dependency Centralization

**Observation**: Only Core depends on external packages. All other targets reach external types through Core's re-exports.

**Evidence**:

| Package | External Dependencies | Where Declared |
|---------|----------------------|----------------|
| parser | Input Primitives, Array Primitives | Core only |
| buffer | Storage, Cyclic Index, Memory, Bit Vector, Finite, Sequence, Collection | Core + variant targets that need Sequence/Collection directly |
| memory | Ordinal, Cardinal, Affine, Identity, Property, Bit, Index, Bit Vector | Core + Pool (needs Bit Vector, Index directly) |

**Exception**: Buffer-primitives variant targets directly depend on Sequence Primitives and Collection Primitives. This is justified because these are protocol conformance dependencies (the variant types conform to Sequence/Collection protocols), which cannot be provided transitively through Core.

**Rationale**: Centralizing external dependencies in Core means upgrading or swapping an external package affects one `dependencies:` declaration, not N.

---

### Pattern 9: Semantic Group Markers

**Observation**: Package.swift files use `// MARK: -` comments to organize targets into semantic groups.

**Evidence from parser-primitives**:
```
// MARK: - Core
// MARK: - Error & Match
// MARK: - Input Errors
// MARK: - Combinators
// MARK: - Consumption
// MARK: - Prefix
// MARK: - Element Access
// MARK: - Position Tracking
// MARK: - Lookahead
// MARK: - Terminals
// MARK: - Utilities
// MARK: - Concrete Parsers
// MARK: - Umbrella
// MARK: - Tests
```

**Evidence from buffer-primitives**: Inline comments on each target declaration serve the same purpose:
```swift
// Core: Namespace enums, header types, growth policy
// Ring: Circular buffer heap and bounded variants
// Ring Inline: Inline and small circular buffer variants
```

**Rationale**: Semantic grouping in Package.swift makes the decomposition axis legible to maintainers. The groups correspond to the variant decomposition axis.

---

### Pattern 10: Dependency Graph Shape

**Observation**: The intra-package dependency graph is consistently a wide, shallow DAG rooted at Core.

**Measured depth** (longest path from Core to a leaf):

| Package | Max Depth | Shape |
|---------|-----------|-------|
| parser | 3 (Core → Take → Many) | Wide fan from Core, one 3-deep chain |
| buffer | 3 (Core → Linear → Linear Inline → Linear Small) | Wide fan with per-variant 2-3 depth |
| memory | 2 (Core → StdLib Integration → Arena/Pool) | Flat star |
| index | 1 (Core → umbrella) | Trivial |

**The shape invariant**: Most targets are at depth 1 (direct Core dependency). Depth > 2 is rare and always follows the inline-satellite or delegation pattern.

**Rationale**: A wide DAG maximizes parallelism in the build system and minimizes the blast radius of changes. A deep chain (A → B → C → D → E) means touching A recompiles everything.

---

### Pattern 11: Split Decision Criteria

**Observation**: Analyzing when a concern gets its own target vs. staying in a parent reveals consistent criteria.

**Targets that got split out (with evidence)**:

| Target | Files | Justification |
|--------|-------|---------------|
| Parser Optional | 3 | Different dependency set (Core only, no Error) |
| Parser Peek | 2 | Unique concern (non-consuming lookahead) |
| Parser Always | 2 | Terminal parser, depended on by Take |
| Parser Take | 8 | Complex (variants + builder), many dependents |
| Parser Many | 5 | Delegates to Take, separate concern (repetition) |
| Buffer Slots | small | Orthogonal metadata parametrization |

**The criteria (extracted)**:

A concern SHOULD be a separate target when any of:
1. **Different dependency set** — It needs fewer (or different) dependencies than its siblings
2. **Independent consumer value** — A downstream package would import this target alone
3. **Depended-on by siblings** — Other targets in the package need it (creating a shared core within the variant layer)
4. **Semantic independence** — It answers one specific question about the domain

A concern SHOULD NOT be a separate target when:
1. It always co-occurs with another target (no independent consumer)
2. It would create a depth > 3 chain without justification
3. The file count is 1 and no other target depends on it specifically

---

### Pattern 12: Naming Convention for Multi-Product Packages

**Extracted naming scheme**:

| Role | Name Pattern | Example |
|------|-------------|---------|
| Core | `{Domain} Primitives Core` | Parser Primitives Core |
| Variant | `{Domain} {Variant} Primitives` | Parser Map Primitives |
| Inline satellite | `{Domain} {Variant} Inline Primitives` | Buffer Ring Inline Primitives |
| Composite satellite | `{Domain} {Variant} Small Primitives` | Buffer Linear Small Primitives |
| StdLib integration | `{Domain} Primitives Standard Library Integration` | Memory Primitives Standard Library Integration |
| Umbrella | `{Domain} Primitives` | Parser Primitives |
| Test Support | `{Domain} Primitives Test Support` | Parser Primitives Test Support |

**Import form** (underscores): `Parser_Map_Primitives`, `Buffer_Ring_Inline_Primitives`

---

## Comparison: Existing Skill Coverage vs. Gap

| Level | Skill | Rules | Covered? |
|-------|-------|-------|----------|
| File | code-organization | [API-IMPL-005–008] | Yes |
| Type | naming | [API-NAME-001–003] | Yes |
| Module/Target (intra-package) | — | — | **No** |
| Package (inter-package) | design, primitives | [API-LAYER-*], [PRIM-ARCH-*] | Yes |
| Ecosystem | swift-institute | [ARCH-LAYER-001] | Yes |

The module/target level is the uncovered middle layer.

## Outcome

**Status**: RECOMMENDATION

### Recommendation

Create a `modularization` skill at the **implementation** layer with requirement prefix `[MOD-*]`. The skill should codify the 13 patterns identified above as auditable requirements.

### Proposed Skill Structure

```
Skills/modularization/SKILL.md

layer: implementation
requires:
  - swift-institute
  - code-organization
  - naming
  - design

ID prefix: [MOD-*]
```

### Proposed Requirement Map

| ID | Pattern | Type |
|----|---------|------|
| MOD-001 | Core Layer — every multi-product package MUST have a Core target | Structural |
| MOD-002 | External Dependency Centralization — only Core SHOULD depend on external packages | Structural |
| MOD-003 | Variant Decomposition — variants MUST be independent along a single axis | Structural |
| MOD-004 | Constraint Isolation — Core MUST NOT carry protocol conformances that poison `~Copyable` | Constraint Hygiene |
| MOD-005 | Umbrella Re-export — multi-product packages MUST have a pure re-export umbrella | Structural |
| MOD-006 | Dependency Minimization — targets MUST declare only direct dependencies | Dependency |
| MOD-007 | Dependency Graph Shape — max depth SHOULD NOT exceed 3 | Dependency |
| MOD-008 | Split Decision Criteria — when to create a separate target | Decision |
| MOD-009 | Inline Variant Satellite — inline MUST depend on heap, never reverse | Structural |
| MOD-010 | Standard Library Integration Module — stdlib extensions SHOULD be isolated | Structural |
| MOD-011 | Test Support Product — published library for downstream test fixtures | Structural |
| MOD-012 | Naming Convention — multi-product target naming scheme | Naming |
| MOD-013 | Semantic Group Markers — MARK comments in Package.swift | Readability |

### Proposed Audit Metrics

In addition to the MOD-* compliance checks, the skill should reference quantitative diagnostics already available:

| Metric | Source | What It Reveals |
|--------|--------|-----------------|
| Product tier spread | `compute-tiers.sh` | Products spanning 3+ tiers suggest bundled concerns at different abstraction levels — extraction candidates |
| Mean sibling dependencies | Package.swift analysis | Lower is better. Parser-primitives achieves 1.2 mean sibling deps per target |
| Max dependency depth | Package.swift analysis | Should not exceed 3. Deeper chains reduce build parallelism |
| Semantic domain count | Manual analysis per Primitives Layering | A package with multiple semantic domains should split (per "Factor the Law, Not the Module") |

### Audit Usage

The skill should function as an audit benchmark:

```
"Audit swift-parser-primitives against /modularization"
```

This would check each MOD-* requirement against the package's Package.swift and source layout, producing a compliance table per [RES-015].

### Relationship to Existing Infrastructure

The modularization skill builds on existing primitives infrastructure:

| Infrastructure | Relevance to Modularization |
|----------------|----------------------------|
| `compute-tiers.sh` | Product-level tier spread identifies when intra-package decomposition is needed |
| Primitives Layering: Semantic Domain Analysis | Formal cohesion test (same question + same algebra + same deps) determines package scope |
| Primitives Layering: Factor the Law, Not the Module | Module creation justified only for semantic domains, not shared code |
| Primitives Layering: Relocation Principle | Types migrate to semantic home; modularization enables this |
| Primitives Requirements: Design Philosophy | "Primitives design is language design" — modularization decisions have vocabulary-level consequences |
| Primitives Tiers: Package vs Product tier distinction | SPM resolves at package level; product-level effective tiers reveal actual linking depth |

### Complementarity with /implementation

The **implementation** skill governs how code reads within a module (intent-over-mechanism, expression-first, typed arithmetic). The **modularization** skill governs how modules relate to each other within a package (dependency structure, decomposition strategy, re-export patterns). They share no rule overlap:

| Concern | Skill |
|---------|-------|
| Should this line use `.map()` or manual reconstruction? | implementation |
| Should this type be in its own target? | modularization |
| Does this expression read as intent? | implementation |
| Does this target declare minimal dependencies? | modularization |
| Is this name mechanism or origin? | naming / implementation |
| Is this concern a semantic domain or just shared code? | modularization |

### Complementarity with /design

The **design** skill covers inter-package layering ([API-LAYER-001–002]) and responsibility separation. The **modularization** skill covers intra-package target structure. They meet at the boundary: design tells you *what goes in which package*; modularization tells you *how to organize targets within that package*.

| Concern | Skill |
|---------|-------|
| Should this be a separate package? | design (semantic domain analysis) |
| Should this be a separate target within the package? | modularization (split decision criteria) |
| Does this package depend on the right layer? | design ([API-LAYER-001]) |
| Does this target declare minimal dependencies? | modularization ([MOD-006]) |

## References

### Primary Sources (Normative)

- `Documentation.docc/Primitives Tiers.md` — Tier constraint, package vs product tier distinction, architectural issues
- `Documentation.docc/Primitives Layering.md` — Semantic domain analysis, split workflow, "Factor the Law, Not the Module"
- `Documentation.docc/Primitives Requirements.md` — Foundation independence, design philosophy, naming conventions
- `Documentation.docc/Computed Primitives Tiers.md` — Generated tier assignments with product-level spread analysis
- `Scripts/compute-tiers.sh` — Tier computation algorithm (package-level and product-level)

### Skill Cross-References

- [RES-017] Pattern Extraction methodology
- [RES-006a] Documentation Promotion
- [RES-015] Convention Compliance Verification
- [API-IMPL-005–008] Code Organization rules (file level)
- [API-LAYER-001–002] Package Layering rules (inter-package level)
- [PRIM-ARCH-001–002] Primitives Tier rules
- [MEM-COPY-001–006] ~Copyable type rules (constraint poisoning context)

### Research Documents

- Parser Primitives Research: `swift-parser-primitives/Research/_Package-Insights.md` (layering as future-proofing)
- Resource Management Assessment: `Research/data structures/Resource Management Assessment.md` (Slab constraint poisoning finding)
- Storage Primitives Comparative Analysis: `Research/storage-primitives-comparative-analysis.md`
- Primitives Taxonomy Naming Layering Audit: `Research/primitives-taxonomy-naming-layering-audit.md`
