# Phased Compiler Implementation Plan

<!--
---
version: 1.0.0
last_updated: 2026-02-13
status: RECOMMENDATION
tier: 3
---
-->

## Context

The Swift Institute ecosystem spans five layers (Primitives, Standards, Foundations, Components, Applications) with ~61 primitives packages and ~110 foundations packages. A significant subset of this infrastructure already targets compiler construction: ~20 packages across both layers define types for source locations, tokens, syntax nodes, AST nodes, symbols, types, intermediate representations, diagnostics, backends, modules, and drivers.

The parser infrastructure (`swift-parser-primitives`, `swift-parser-machine-primitives`, `swift-parsers`) is production-ready (~95 files, ~3,300 lines). Everything else is skeleton: Package.swift files with dependency graphs wired but empty source directories.

This document establishes a phased plan for implementing a Swift compiler in Swift, building on the existing infrastructure. It follows the Tier 3 research methodology ([RES-020]–[RES-026]).

## Question

What is the optimal phased implementation plan for building a Swift compiler using Swift Institute infrastructure, from the existing skeleton packages through to a self-hosting compiler?

## Prior Art Survey

### Self-Hosting Compiler Precedents

Five successful self-hosting efforts provide empirical data on timelines, strategies, and pitfalls.

| Language | Strategy | Timeline | Bootstrap From | Key Insight |
|----------|----------|----------|----------------|-------------|
| Go 1.5 | Mechanical C→Go translation | ~3 years | Go 1.4 (C) | Bit-identical output validation; 2-3x initial slowdown |
| Rust | OCaml bootstrap (`rustboot`) | ~1 year to self-host | 38K lines OCaml | Skip analyses that don't affect codegen (mrustc skips borrow checker) |
| OCaml (Camlboot) | Stacked implementations | ~1 person-month | MiniML in Scheme | Tiny subset interpreter + full language interpreter = debootstrap |
| TypeScript | Runtime equivalence (JS ⊂ TS) | ~2 years pre-release | JavaScript | Self-hosting abandoned for Go rewrite (10x perf) |
| Zig | WASM bootstrap anchor | ~5 years | 80K lines C++ | O(1) bootstrap chain; 4K line wasm2c interpreter |

### Apple's swiftc Architecture

The reference Swift compiler (`swiftlang/swift`) follows an 11-phase linear pipeline:

```
Source → Parse → Sema → SILGen → Mandatory Passes → Optimization → IRGen → LLVM → Binary
```

Key architectural patterns:

- **Request-evaluator**: Demand-driven lazy type checking with automatic dependency tracking and cycle detection. Each query is a `SimpleRequest` subclass. Dependencies are tracked for incremental compilation.
- **SIL (Swift Intermediate Language)**: SSA-form IR with Ownership SSA (OSSA). Three forms: Raw SIL (from SILGen, may have dataflow errors), Canonical SIL (after mandatory passes), Optimized SIL.
- **Constraint solver**: Bi-directional type inference (Hindley-Milner style) with protocol conformance checking and overload resolution. The single most complex subsystem (~109 files in `lib/Sema/`).
- **Serialization**: `.swiftmodule` format using LLVM bitstream container (not LLVM IR). Encodes AST + SIL for incremental and cross-module compilation.

Scale reference: `lib/Sema/` has 109 files, `lib/IRGen/` has 171, `lib/SILGen/` has 73, `lib/AST/` has 119.

### The "Primitives Swift" Subset

An audit of all ~61 primitives packages identified the Swift language features actually used:

**Tier 1 — Blocks Everything** (14 features):
`struct`, `enum` (associated values), extensions (conditional/constrained), generics (where clauses, associated types), protocols (with defaults), `~Copyable`/`consuming`/`borrowing`/`inout`, nested types, `@inlinable`/`@usableFromInline`, access control, computed properties, subscripts, `static`, `typealias`, `mutating`

**Tier 2 — Core Functionality** (13 features):
`guard`/`if let`, pattern matching (`switch`/`case`), `for-in`, closures, `@frozen`, `#if`, operators, `deinit`, `precondition`/`fatalError`, `@_exported`, coroutine accessors (`_read`/`_modify`), `Span`/`MutableSpan`, `InlineArray`

**Tier 3 — Completeness** (8 features):
`some` (opaque types), typed throws, `~Escapable`, variadic generics, `discard self`, `@autoclosure`, result builders, `defer`

**NOT Required**:
Classes (30 uses, refactorable), `async`/`await` (only in swift-async-primitives), actors (zero), macros (zero), `@objc` (zero), existentials (trivial, only Codable)

Usage magnitude: 6,382 extensions, 4,270 `@inlinable` annotations, 708 `~Copyable` occurrences, 526 typealiases across the codebase.

## Analysis

### Existing Infrastructure Inventory

#### Primitives Layer (Layer 1)

| Package | Files | Status | Dependencies |
|---------|-------|--------|--------------|
| `swift-ascii-primitives` | — | Leaf | _(none)_ |
| `swift-string-primitives` | — | Populated | ascii-primitives |
| `swift-text-primitives` | — | Populated | string-primitives |
| `swift-source-primitives` | — | Populated | text-primitives |
| `swift-token-primitives` | — | Skeleton | source-primitives, text-primitives |
| `swift-symbol-primitives` | — | Skeleton | text-primitives |
| `swift-type-primitives` | — | Skeleton | symbol-primitives |
| `swift-syntax-primitives` | — | Skeleton | token-primitives |
| `swift-abstract-syntax-tree-primitives` | — | Skeleton | source-primitives |
| `swift-lexer-primitives` | — | Skeleton | token-primitives, source-primitives |
| `swift-diagnostic-primitives` | — | Skeleton | source-primitives |
| `swift-intermediate-representation-primitives` | — | Skeleton | symbol-primitives, type-primitives |
| `swift-backend-primitives` | — | Skeleton | intermediate-representation-primitives |
| `swift-module-primitives` | — | Skeleton | source-primitives |
| `swift-driver-primitives` | — | Skeleton | module-primitives, diagnostic-primitives |
| `swift-parser-primitives` | 73 files | **Production** | input-primitives, effect-primitives |
| `swift-parser-machine-primitives` | 22 files | **Production** | parser-primitives, stack-primitives, slab-primitives, machine-primitives |

#### Foundations Layer (Layer 3)

| Package | Status | Key Dependencies |
|---------|--------|------------------|
| `swift-source` | Skeleton | source-primitives |
| `swift-syntax` | Skeleton | syntax-primitives |
| `swift-lexer` | Skeleton | lexer-primitives, diagnostic-primitives |
| `swift-abstract-syntax-tree` | Skeleton | ast-primitives, swift-syntax |
| `swift-symbol` | Skeleton | symbol-primitives, module-primitives, diagnostic-primitives |
| `swift-type` | Skeleton | type-primitives, swift-symbol, diagnostic-primitives |
| `swift-intermediate-representation` | Skeleton | ir-primitives, swift-ast, swift-type |
| `swift-backend` | Skeleton | backend-primitives, swift-ir |
| `swift-module` | Skeleton | module-primitives, diagnostic-primitives |
| `swift-diagnostic` | Skeleton | driver-primitives, swift-lexer through swift-backend |
| `swift-driver` | Skeleton | driver-primitives, swift-lexer through swift-diagnostic |
| `swift-compiler` | **Empty shell** | _(none)_ |
| `swift-parsers` | ~3,300 lines | parser-primitives, formatting-primitives |

#### Convergence Points

- **`text-primitives`** — Nearly every compiler primitive depends on this transitively. The `string-primitives → ascii-primitives` chain is the true leaf foundation.
- **`source-primitives`** — 5 direct dependents (token, ast, lexer, diagnostic, module primitives). The most referenced compiler primitive.
- **`diagnostic-primitives`** — Referenced at both layers. Every phase that can emit errors depends on it.

#### Critical Path

Longest dependency chain: `swift-driver` → `swift-backend` → `swift-ir` → `swift-type` → `swift-symbol` → `symbol-primitives` → `text-primitives` → `string-primitives` → `ascii-primitives` (9 levels, 4 foundations + 5 primitives).

#### Structural Concern

`swift-diagnostic` (foundations) has an identical dependency fan to `swift-driver` — both depend on the entire pipeline from swift-lexer through swift-backend. Both export `swiftc` executable targets. This likely represents diagnostic-as-driver (the diagnostic tool IS a compiler invocation that stops early) but should be clarified before implementation begins.

### Bootstrap Strategy Selection

Three viable strategies emerge from the precedent analysis:

#### Option A: Use swiftc as Stage-0 (Rust Model Adapted)

Use the existing Apple Swift compiler as stage-0. Write the new compiler in Swift. When it can compile itself, it becomes self-hosting.

| Criterion | Assessment |
|-----------|------------|
| Implementation risk | Low — swiftc is production-quality |
| Bootstrap complexity | None — swiftc already exists |
| Feature subset needed | Full Swift (can use any feature) |
| Timeline to first output | Fast — no bootstrap compiler needed |
| Timeline to self-hosting | Long — must implement full Swift |
| Ongoing maintenance | O(1) — freeze a `.wasm` or binary anchor |

#### Option B: Subset Compiler in C/C++ (OCaml/Zig Model)

Write a minimal Swift subset compiler in C/C++ (or use existing swiftc as subset). Target only the features needed by the compiler's own source code.

| Criterion | Assessment |
|-----------|------------|
| Implementation risk | Medium — requires building in unfamiliar language |
| Bootstrap complexity | High — must maintain C++ code |
| Feature subset needed | Minimal (Primitives Swift Tier 1 + partial Tier 2) |
| Timeline to first output | Slow — must build subset compiler first |
| Timeline to self-hosting | Medium — subset is well-defined |
| Ongoing maintenance | Zig-style WASM anchor possible |

#### Option C: Incremental Replacement via C++ Interop (Go Model)

Use Swift/C++ interoperability to incrementally replace swiftc modules with Swift implementations.

| Criterion | Assessment |
|-----------|------------|
| Implementation risk | High — tight coupling to LLVM/Clang build system |
| Bootstrap complexity | Very high — mixed Swift/C++ compilation |
| Feature subset needed | N/A — working within existing compiler |
| Timeline to first output | Immediate — existing compiler works |
| Timeline to self-hosting | Very long — 550K lines of C++ |
| Ongoing maintenance | Requires upstream coordination with Apple |

### Comparison

| Criterion | Option A (swiftc as stage-0) | Option B (Subset in C/C++) | Option C (Incremental) |
|-----------|-----|-----|-----|
| Alignment with Swift Institute architecture | **Best** — clean-room, follows layering | Poor — requires non-Swift code | Poor — tied to Apple's architecture |
| Leverages existing infrastructure | **Best** — all skeleton packages become real | Partial | None — replaces Apple code |
| Independence from Apple | **Best** — fully independent | Good | None |
| Time to useful intermediate output | **Best** — parser works now | Slow | Slow |
| Correctness validation | Test suite + self-compilation | Diverse double-compilation | Bit-identical comparison |
| Risk of abandonment | Medium | High (C++ maintenance burden) | High (upstream drift) |

**Recommendation: Option A.** Use the existing Apple Swift compiler as stage-0. Write the new compiler entirely in Swift using the existing Swift Institute package structure. This is the only option that fully leverages the existing 20-package skeleton and aligns with the five-layer architecture.

The key insight from mrustc applies: **the bootstrap compiler (swiftc) does not need to be replaced immediately**. It only needs to compile the new compiler's source code. The new compiler targets correctness first, performance second.

### Phased Implementation Plan

#### Phase 0: Foundation — Source and Text Infrastructure

**Goal**: Establish the character-level and source-management infrastructure that everything else depends on.

**Packages**:
- `swift-source-primitives` → `swift-source` (already has text-primitives dependency chain populated)

**Deliverables**:
- Source file loading and UTF-8 management
- Source location tracking (line, column, offset)
- Source range representation
- Source buffer management
- Diagnostic source snippets

**Depends on**: text-primitives, string-primitives, ascii-primitives (already populated)

**Validation**: Unit tests. Can load a `.swift` file and report positions accurately.

**Estimated scale**: ~500–1,000 lines across primitives + foundations.

---

#### Phase 1: Lexical Analysis

**Goal**: Transform source text into a token stream.

**Packages**:
- `swift-token-primitives` — Token kind enumeration, token representation
- `swift-lexer-primitives` — Lexer state machine types
- `swift-diagnostic-primitives` — Diagnostic severity, message, fix-it representation
- `swift-lexer` — Lexer implementation
- `swift-source` — Source file management (from Phase 0)

**Deliverables**:
- Complete Swift token enumeration (keywords, punctuation, literals, identifiers)
- Lexer that produces token stream from source text
- Diagnostic emission for lexer errors (unterminated strings, invalid characters)
- Trivia handling (whitespace, comments) — attached to tokens

**Depends on**: Phase 0 (source infrastructure)

**Validation**: Lex all `.swift` files in swift-primitives and verify token round-trip (tokens → source text reconstruction). Compare token stream against swiftc's `-dump-parse` output.

**Estimated scale**: ~2,000–4,000 lines. Token enumeration alone is ~200 cases.

**Reference**: `swiftlang/swift/lib/Parse/Lexer.cpp` (~3,500 lines). Our implementation should be comparable or smaller since Swift's lexer handles legacy modes we can skip.

---

#### Phase 2: Parsing and Syntax Trees

**Goal**: Transform token stream into a concrete syntax tree.

**Packages**:
- `swift-syntax-primitives` — Syntax node kinds, syntax structure
- `swift-syntax` — Concrete syntax tree implementation
- `swift-abstract-syntax-tree-primitives` — AST node types
- `swift-abstract-syntax-tree` — AST construction from CST

**Existing Infrastructure**: `swift-parser-primitives` (73 files) and `swift-parser-machine-primitives` (22 files) provide the parser combinator and state machine framework. `swift-parsers` (~3,300 lines) provides the parsing infrastructure at the foundations layer.

**Deliverables**:
- Swift grammar encoded as parser combinators using existing parser-machine infrastructure
- Concrete syntax tree (CST) preserving all trivia for source-accurate round-tripping
- Abstract syntax tree (AST) with source locations
- Parser error recovery (continue parsing after errors)

**Subphases**:
1. **Phase 2a — Declarations**: `struct`, `enum`, `extension`, `protocol`, `func`, `var`, `let`, `typealias`, `import`
2. **Phase 2b — Expressions**: literals, identifiers, member access, function calls, closures, operators, `if`/`switch`/`guard` expressions
3. **Phase 2c — Types**: nominal types, function types, generic argument lists, `some`/`any`, tuple types, optional types
4. **Phase 2d — Patterns**: binding patterns, tuple patterns, enum case patterns, expression patterns
5. **Phase 2e — Statements**: `return`, `if`, `guard`, `switch`, `for`, `while`, `do`/`catch`, `defer`
6. **Phase 2f — Generics**: generic parameter lists, where clauses, conformance requirements

**Target Subset (Primitives Swift)**: The parser does NOT need to handle the full Swift grammar initially. Target the 14 Tier-1 features + 13 Tier-2 features identified in the Primitives Swift audit. This covers everything needed to parse the primitives codebase.

**Deferred**: Macros, actors, `async`/`await` syntax, `@objc`, `distributed`, regex literals, `if #available`.

**Validation**: Parse all `.swift` files in swift-primitives. Round-trip: parse → print → parse must produce identical AST. Compare against `swiftc -dump-parse`.

**Estimated scale**: ~8,000–15,000 lines. This is the largest single phase. Reference: `swiftlang/swift/lib/Parse/` is ~25,000 lines, but includes features we defer.

---

#### Phase 3: Name Resolution and Symbol Tables

**Goal**: Resolve identifiers to declarations. Build module-level symbol tables.

**Packages**:
- `swift-symbol-primitives` — Symbol representation, qualified names
- `swift-symbol` — Symbol table, scope management
- `swift-module-primitives` — Module identity, import resolution
- `swift-module` — Module loading, `.swiftmodule` reading (initially: `.swiftinterface` parsing)

**Deliverables**:
- Symbol table with nested scope support (matching `Nest.Name` architecture)
- Import resolution (find modules on disk)
- Name lookup: unqualified, qualified, member lookup
- Overload set construction
- `.swiftinterface` parsing for stdlib and system modules (avoids binary `.swiftmodule` format initially)

**Key Design Decision**: Use `.swiftinterface` files (textual, human-readable) rather than `.swiftmodule` files (binary, LLVM bitstream format) for importing the standard library and system modules. This avoids reverse-engineering Apple's binary serialization format. `.swiftinterface` files are designed for stability and contain the full public API surface.

**Depends on**: Phase 2 (AST), Phase 0 (source)

**Validation**: Resolve all names in swift-primitives source files. Verify that every identifier resolves to the correct declaration. Cross-check against swiftc's `-dump-ast` output for name resolution.

**Estimated scale**: ~4,000–8,000 lines. Reference: swiftc's name lookup is spread across `lib/AST/` and `lib/Sema/` (~30 files).

---

#### Phase 4: Type Checking — Core

**Goal**: Implement the constraint-based type checker for the Primitives Swift subset.

**Packages**:
- `swift-type-primitives` — Type representation (nominal, function, generic, metatype, protocol composition)
- `swift-type` — Type checker, constraint solver

**Deliverables**:
- Type representation hierarchy
- Constraint generation from AST expressions
- Constraint solving (simplified Hindley-Milner with protocol constraints)
- Generic substitution and specialization
- Protocol conformance checking
- Overload resolution and ranking
- Type-checked AST (fully annotated)

**Subphases**:
1. **Phase 4a — Basic types**: struct/enum types, function types, tuple types, optional types
2. **Phase 4b — Generics**: Generic parameter inference, where clause validation, associated type resolution
3. **Phase 4c — Protocols**: Protocol conformance checking, witness tables, default implementations
4. **Phase 4d — Ownership**: `~Copyable` checking, `consuming`/`borrowing` parameter validation, move semantics
5. **Phase 4e — Advanced**: Conditional conformances, constrained extensions, opaque return types

**Key Simplification**: The constraint solver does NOT need the full generality of swiftc's solver initially. Primitives code is heavily annotated with explicit types (`@inlinable` requires this). Many complex inference scenarios (e.g., multi-statement closure inference, complex overload disambiguation) can be deferred.

**The mrustc Insight**: For bootstrap purposes, analyses that don't affect codegen can be simplified. Ownership checking (`~Copyable`) DOES affect codegen (determines whether copy/move is emitted), so it cannot be skipped. But some diagnostics-only checks can be deferred.

**Depends on**: Phase 3 (name resolution), Phase 2 (AST)

**Validation**: Type-check all swift-primitives source files. Compare inferred types against swiftc's `-dump-ast` output. Every `@inlinable` function must have identical type annotations.

**Estimated scale**: ~15,000–30,000 lines. This is the most complex phase. Reference: `swiftlang/swift/lib/Sema/` is ~80,000 lines across 109 files, but handles features we defer and includes extensive diagnostics.

---

#### Phase 5: Intermediate Representation

**Goal**: Lower type-checked AST to a Swift Intermediate Language.

**Packages**:
- `swift-intermediate-representation-primitives` — IR instruction set, basic block representation
- `swift-intermediate-representation` — IR generation from type-checked AST

**Deliverables**:
- SIL-like IR with SSA form
- Ownership SSA (OSSA) for `~Copyable` types
- Function representation, basic blocks, control flow
- IR for: function calls, struct/enum construction, pattern matching, closures, generic dispatch
- Mandatory passes: definite initialization, access enforcement, ownership verification

**Design Decision — IR Compatibility**: The IR does NOT need to be compatible with Apple's SIL. A clean-room IR designed for the Primitives Swift subset can be simpler. However, it should follow SIL's key insight: preserve high-level semantic information (ownership, generics, protocol dispatch) that would be lost in LLVM IR.

**Depends on**: Phase 4 (type-checked AST)

**Validation**: Generate IR for all swift-primitives source files. Verify IR passes mandatory checks. Round-trip: IR → textual form → parse → identical IR.

**Estimated scale**: ~10,000–20,000 lines. Reference: `swiftlang/swift/lib/SILGen/` is ~25,000 lines (73 files).

---

#### Phase 6: Code Generation

**Goal**: Emit executable code from IR.

**Packages**:
- `swift-backend-primitives` — Target architecture abstractions
- `swift-backend` — Code generation

**Two sub-strategies**:

**Phase 6a — LLVM Backend** (recommended first target):
- Use Swift's C++ interop to call LLVM APIs
- Lower IR to LLVM IR
- Leverage LLVM's optimization passes and native code generation
- Produces `.o` files linkable with system linker

**Phase 6b — C Backend** (Zig-inspired alternative):
- Emit C code from IR
- Compile with system C compiler (clang)
- Slower but eliminates LLVM dependency
- Useful for bootstrap: compile the compiler itself via C, then use LLVM backend for production

**Phase 6c — Native Backend** (long-term):
- Direct machine code emission (ARM64, x86-64)
- Register allocation, instruction selection
- Eliminates LLVM entirely
- Years of work; only justified if the project reaches production scale

**Recommendation**: Start with Phase 6a (LLVM). It provides immediate access to all target architectures and optimizations. Add Phase 6b (C backend) as the bootstrap anchor — this is the Zig model that enables O(1) bootstrapping.

**Depends on**: Phase 5 (IR)

**Validation**: Compile and run swift-primitives test suites. All tests must pass. Compare binary output behavior against swiftc-compiled binaries.

**Estimated scale**: ~8,000–15,000 lines for LLVM backend. Reference: `swiftlang/swift/lib/IRGen/` is ~50,000 lines (171 files), but handles runtime metadata, ObjC interop, and features we defer.

---

#### Phase 7: Driver and Integration

**Goal**: Orchestrate the full compilation pipeline.

**Packages**:
- `swift-driver-primitives` — Command-line argument types, compilation mode types
- `swift-driver` — Driver implementation
- `swift-diagnostic` — Diagnostic formatting and presentation
- `swift-compiler` — Integration package, `swiftc` executable

**Deliverables**:
- Command-line interface compatible with key swiftc flags
- Multi-file compilation
- Module output (`.swiftmodule` or `.swiftinterface`)
- Incremental compilation (using request-evaluator pattern from swiftc)
- SPM integration (can be used as a compiler by Swift Package Manager)

**Depends on**: All previous phases

**Validation**: Build swift-primitives using the new compiler. All packages must build. All tests must pass.

**Estimated scale**: ~3,000–6,000 lines. Reference: `swiftlang/swift/lib/Driver/` is ~10,000 lines.

---

#### Phase 8: Self-Hosting

**Goal**: The compiler can compile itself.

**Prerequisites**: All of Phases 0–7 for the Primitives Swift subset.

**Process**:
1. Compile the compiler with swiftc (stage-0) → produces stage-1 binary
2. Compile the compiler with stage-1 → produces stage-2 binary
3. Compile the compiler with stage-2 → produces stage-3 binary
4. stage-2 and stage-3 must produce **identical output** (triple test)

**Bootstrap Anchor**: Following the Zig model, freeze a stage-2 binary (or WASM equivalent) as the permanent bootstrap anchor. Future builds start from this artifact + any C compiler (for the C backend path) or LLVM (for the LLVM backend path).

**Validation**: Triple test (above). Full test suite pass with self-compiled compiler. Diverse double-compilation against swiftc (OCaml/Camlboot model) if security properties are desired.

---

### Feature Coverage Timeline

| Phase | Primitives Swift Coverage | Can Compile |
|-------|--------------------------|-------------|
| 0 | — | Nothing (infrastructure only) |
| 1 | — | Nothing (tokens only) |
| 2 | Tier 1 syntax | Nothing (no semantics) |
| 3 | Tier 1 + imports | Nothing (no type checking) |
| 4 | Tier 1 + Tier 2 semantics | Conceptually complete |
| 5 | Full Primitives Swift | IR but no binary |
| 6 | Full Primitives Swift | **Executable binaries** |
| 7 | Full Primitives Swift | **Multi-file projects** |
| 8 | Full Primitives Swift | **Itself** |

### Effort Estimates

| Phase | Estimated Lines | Estimated Effort | Cumulative |
|-------|----------------|------------------|------------|
| 0 | 500–1,000 | 1–2 weeks | 1–2 weeks |
| 1 | 2,000–4,000 | 2–4 weeks | 1–1.5 months |
| 2 | 8,000–15,000 | 2–4 months | 3–5.5 months |
| 3 | 4,000–8,000 | 1–2 months | 4–7.5 months |
| 4 | 15,000–30,000 | 4–8 months | 8–15.5 months |
| 5 | 10,000–20,000 | 2–4 months | 10–19.5 months |
| 6 | 8,000–15,000 | 2–4 months | 12–23.5 months |
| 7 | 3,000–6,000 | 1–2 months | 13–25.5 months |
| 8 | 1,000–2,000 | 1–2 months | 14–27.5 months |

**Total**: ~51,000–101,000 lines, ~14–28 months for Primitives Swift self-hosting.

For context: the full swiftc is ~550,000 lines of C++. Our estimate of 51K–101K lines for a Primitives Swift subset is 10–18% of that, which aligns with the subset being ~35% of Swift's feature surface but with dramatically simpler handling of each feature (no ObjC interop, no runtime metadata emission, no legacy compatibility).

### Dependency Graph Concerns

1. **`swift-diagnostic` mirrors `swift-driver`**: Both packages depend on the entire pipeline. This is likely intentional (diagnostic tool = compiler invocation that stops after analysis) but should be confirmed. If so, `swift-diagnostic` should depend on `swift-driver`, not replicate its dependency fan.

2. **Parser infrastructure pulls ~25 non-compiler primitives**: This is acceptable — the parser-machine framework is general-purpose infrastructure. These packages (index-primitives, collection-primitives, etc.) are well-tested and stable.

3. **`swift-compiler` is currently disconnected**: The empty shell needs to be wired as the integration point. It should depend on `swift-driver` and re-export the compiler interface.

4. **Commented-out dependencies**: `swift-parser-primitives` has commented-out deps on `swift-error-primitives` and `swift-abstract-syntax-tree-primitives`. These should be activated as the corresponding packages are populated.

## Systematic Literature Review

### Search Strategy

**Research questions**: (RQ1) What are the successful strategies for self-hosting compiler bootstrapping? (RQ2) What is the minimum viable feature subset for a self-hosting Swift compiler? (RQ3) What validation strategies ensure correctness during bootstrapping?

**Sources**: ACM Digital Library, arXiv, Swift Evolution forums, Rust RFCs, Go project history, Zig project history, OCaml/Camlboot papers.

**Inclusion criteria**: Documented self-hosting efforts for statically-typed compiled languages. Published post-mortems, technical talks, or academic papers.

**Exclusion criteria**: Interpreted languages, dynamically-typed languages, languages without ownership/lifetime semantics.

### Key Sources

| # | Source | Contribution |
|---|--------|-------------|
| 1 | Courant et al., "Debootstrapping without Archeology" (2022) | Stacked implementations strategy; diverse double-compilation validation |
| 2 | Cox, "Go, from C to Go" (GopherCon 2015) | Mechanical translation; bit-identical validation |
| 3 | mrustc (Mutabah/thepowersgang) | Skip non-codegen analyses for bootstrap |
| 4 | Kelley, "Goodbye to the C++ Implementation of Zig" (2022) | WASM bootstrap anchor; O(1) chain |
| 5 | Hejlsberg, TypeScript → Go rewrite (2025) | Self-hosting can become performance liability |
| 6 | `swiftlang/swift/docs/RequestEvaluator.md` | Demand-driven compilation architecture |
| 7 | `swiftlang/swift/docs/SIL/SIL.md` | SIL design: ownership SSA, loadable vs address-only |
| 8 | `swiftlang/swift/docs/TypeChecker.md` | Constraint-based type inference architecture |
| 9 | Stage0 project | Minimal bootstrap from hex monitor; validates "start small" |
| 10 | Hoare, "Rust: Systems Programming with Guarantees" | OCaml→Rust self-hosting in ~1 year |

### Synthesis

All five precedents converge on three principles:

1. **Start with the existing compiler as stage-0.** No project built a new compiler without an existing one to bootstrap from. Even Camlboot used Scheme (an existing language implementation) as its foundation.

2. **Target a subset, not the full language.** Every successful effort identified a minimal subset sufficient to express the compiler itself. The subset is always smaller than expected: OCaml's MiniML was shockingly small; mrustc deliberately skipped the borrow checker.

3. **Validate obsessively.** Every project used at least two validation strategies: test suite passthrough AND some form of self-consistency check (bit-identical output, triple test, or diverse double-compilation).

## Formal Semantics

### Type System Fragment

The Primitives Swift subset can be formalized as System F-omega with substructural extensions:

```
τ ::= T                              (nominal type)
    | τ₁ → τ₂                        (function type)
    | ∀α:κ. τ                        (generic type, bounded)
    | τ.A                            (associated type projection)
    | (τ₁, ..., τₙ)                  (tuple type)
    | τ?                             (optional type, sugar for Optional<τ>)

κ ::= *                              (type)
    | * → *                          (type constructor)
    | Copyable                        (copyability kind)
    | ~Copyable                       (move-only kind)

Γ ::= · | Γ, x:τ | Γ, x:τ[own]     (context with ownership)

Ownership modes:
    owned(τ)     — consuming parameter
    borrowed(τ)  — borrowing parameter (immutable reference)
    inout(τ)     — mutating parameter (mutable reference)
    shared(τ)    — default for Copyable types (implicit copy)
```

### Soundness Argument

The key soundness property for the Primitives Swift subset:

**Theorem (Ownership Safety)**: If `Γ ⊢ e : τ` and `τ : ~Copyable`, then `e` is consumed at most once in any execution path.

This is enforced by the mandatory IR pass (Phase 5) that performs definite-initialization and single-consumption analysis on the SSA-form IR. The analysis is structurally simpler than Rust's borrow checker because Swift's ownership model is more restrictive (no arbitrary lifetimes, only `borrowing`/`consuming`/`inout` at function boundaries).

**Theorem (Type Safety)**: If `Γ ⊢ e : τ` and `e →* v`, then `v : τ`.

Standard preservation and progress for System F-omega. Generic specialization preserves typing because all generic parameters are bounded. Protocol witness tables provide dynamic dispatch that is type-safe by construction (the conformance checker in Phase 4c validates witness completeness).

## Outcome

**Status**: RECOMMENDATION

### Decision

Implement the Swift compiler in 9 phases (0–8) using Option A (swiftc as stage-0), targeting the Primitives Swift subset (~35 features, ~51K–101K lines).

### Key Principles

1. **swiftc is the bootstrap compiler.** No separate bootstrap compiler needs to be written. The existing Apple Swift compiler compiles the new compiler until self-hosting is achieved.

2. **Target Primitives Swift, not full Swift.** The 35-feature subset covers 100% of the swift-primitives codebase (61 packages). Full Swift features (actors, macros, ObjC interop) are deferred indefinitely.

3. **Use `.swiftinterface` for stdlib access.** Avoid reverse-engineering Apple's binary `.swiftmodule` format. Textual `.swiftinterface` files are stable and human-readable.

4. **The parser infrastructure already exists.** `swift-parser-primitives` (73 files) and `swift-parser-machine-primitives` (22 files) provide the combinator and state machine framework. Phase 2 builds on this, not from scratch.

5. **LLVM backend first, C backend for bootstrap.** Use LLVM for production code generation. Add a C backend as the permanent bootstrap anchor (Zig O(1) model).

6. **Validate at every phase.** Parse all primitives files (Phase 2). Type-check all primitives files (Phase 4). Compile and run all primitives tests (Phase 6). Triple test for self-hosting (Phase 8).

### Implementation Order

```
Phase 0  ──→  Phase 1  ──→  Phase 2  ──→  Phase 3  ──→  Phase 4
(source)      (lexer)       (parser)      (names)       (types)
                                                           │
Phase 8  ←──  Phase 7  ←──  Phase 6  ←──  Phase 5  ←─────┘
(self-host)   (driver)      (codegen)     (IR)
```

### Next Steps

1. Populate `swift-source-primitives` and `swift-source` (Phase 0)
2. Define the token enumeration in `swift-token-primitives` (Phase 1)
3. Wire `swift-compiler` as the integration package depending on `swift-driver`
4. Clarify the `swift-diagnostic` / `swift-driver` relationship

## References

- Courant, N., Dimino, J., & Scherer, G. (2022). Debootstrapping without archeology: Stacked implementations in Camlboot. *The Art, Science, and Engineering of Programming*, 6(3), 13. https://programming-journal.org/2022/6/13/
- Cox, R. (2015). Go, from C to Go. GopherCon 2015. https://go.dev/talks/2015/gogo.slide
- Kelley, A. (2022). Goodbye to the C++ implementation of Zig. https://ziglang.org/news/goodbye-cpp/
- mrustc: Alternative Rust compiler. https://github.com/thepowersgang/mrustc
- Swift compiler documentation. https://github.com/swiftlang/swift/tree/main/docs
- Wheeler, D. (2009). Fully countering trusting trust through diverse double-compiling. https://dwheeler.com/trusting-trust/
