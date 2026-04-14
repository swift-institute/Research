# Enum Infrastructure Primitives

<!--
---
version: 1.0.0
last_updated: 2026-03-16
status: RECOMMENDATION
research_tier: 2
applies_to: [foundations, primitives]
normative: false
---
-->

## Context

The converged @Dual / @Defunctionalize / @Witness architecture (see `dual-defunctionalize-architecture.md`) establishes three independent macros at Layer 3 (Foundations). All three share identical codegen routines for enum infrastructure:

| File | Responsibility | Lines (~) |
|------|---------------|-----------|
| `PrismCodegen.swift` | Generates `Optic.Prism` properties for enum cases | ~65 |
| `CaseDiscriminantCodegen.swift` | Generates `Case: Finite.Enumerable` discriminant enum | ~45 |
| `ExtractionCodegen.swift` | Generates extraction computed properties, `var case: Case`, Prisms struct, prism accessors | ~130 |
| `Utilities.swift` | `hasRestrictedAccess`, `canInline`, `escapeIdentifier` | ~40 |

These files are currently duplicated across three macro implementation targets:

| Package | Target | Status |
|---------|--------|--------|
| `swift-witnesses` | `Witnesses Macros Implementation` | Original source; the codegen lives inline in `EnumExpansion.swift` and `WitnessMacro.swift` |
| `swift-dual` | `Dual Macros Implementation` | Copy, refactored into standalone files per the handoff prompt |
| `swift-defunctionalize` | `Defunctionalize Macros Implementation` | Future; will need the same routines for its `T.Calls` enum |

### Trigger

[RES-001] The converged plan states: "Shared codegen lives in a neutral support package, not in swift-dual." The user's direction clarifies: "we don't want a general 'codegen' package, we want to identify the correct primitives/foundations and compose them. We accept these might be micro-package(s)."

### Scope

Ecosystem-wide per [RES-002a]. The chosen pattern governs how macro implementation targets share codegen across Layer 3. This is the first instance of cross-package macro codegen sharing in the ecosystem.

### Key Constraint

These are **macro implementation files** — SwiftSyntax-dependent codegen that runs inside the compiler plugin process. They generate source text that references `Optic_Primitives`, `Finite_Primitives`, `Ordinal_Primitives`, `Cardinal_Primitives`, but they do not import those runtime modules themselves. This means:

1. The shared code depends on SwiftSyntax (specifically `SwiftSyntax`, `SwiftSyntaxBuilder`, `SwiftSyntaxMacros`, `SwiftDiagnostics`).
2. The shared code has zero runtime module dependencies.
3. Any package containing this shared code becomes a SwiftSyntax-dependent artifact — it cannot be imported by runtime targets.
4. Consumer targets are always `.macro(...)` targets inside macro packages.

---

## Question

**Primary**: What is the correct package decomposition for the shared enum codegen (`PrismCodegen`, `CaseDiscriminantCodegen`, `ExtractionCodegen`, `Utilities`) currently duplicated across `swift-dual`, `swift-defunctionalize`, and `swift-witnesses`?

**Secondary**: Does the "identify the correct primitives and compose them" direction survive contact with the SwiftSyntax constraint, or does this particular case call for a different shape?

---

## Prior Art Survey [RES-021]

### Swift ecosystem macro codegen sharing

| Project | Approach | Notes |
|---------|----------|-------|
| **swift-syntax itself** | Single monorepo; shared utilities are internal targets (`SwiftSyntaxBuilder`, `SwiftOperators`). No cross-package sharing — everything lives in one package. | N/A for cross-package. |
| **swift-composable-architecture** (TCA) | Single macro package (`ComposableArchitectureMacros`). All codegen is internal. No sharing with other packages. | No precedent for sharing. |
| **swift-macro-toolkit** (stackotter) | A standalone SwiftSyntax utility library that macro authors import. Provides generic helpers (`FunctionDeclSyntax` extensions, type resolution, etc.). | Closest precedent: a shared SwiftSyntax-dependent library consumed by macro implementations. However, it is generic tooling (syntax tree manipulation), not domain codegen. |
| **MacroToolkit / swift-syntax-extras** (community) | Similar to above — generic SwiftSyntax utilities. Not domain-specific codegen. | Generic, not domain. |
| **swift-spyable** / **swift-macro-testing** | Self-contained single-macro packages. No codegen sharing. | No precedent. |
| **CasePaths** (Point-Free) | Provides enum case paths (analogous to prisms). Implemented as a macro + runtime library, all in one package. No shared codegen with other packages. | Interesting parallel: CasePaths generates similar extraction/prism infrastructure but does not factor it out for sharing. |

**Finding**: No Swift macro ecosystem has established a pattern for sharing domain-specific codegen across multiple macro packages. The generic-utility pattern (swift-macro-toolkit) exists but is a different shape — it provides syntax tree helpers, not domain-specific code generators.

### Related languages

| Language/Tool | Approach |
|---------------|----------|
| **Rust proc-macro crates** | Shared codegen is a regular crate (`some-derive-internals`) imported by multiple proc-macro crates. The proc-macro crate boundary is analogous to Swift's `.macro` target. Rust's crate system makes this natural. |
| **Haskell Template Haskell** | TH codegen shares through regular library modules. No special packaging needed. |
| **OCaml ppx** | Shared ppx utilities live in `ppxlib`. Domain-specific rewriters are separate packages that depend on `ppxlib`. |

**Finding**: In Rust, factoring out shared proc-macro internals into a regular (non-proc-macro) crate is the established pattern (`serde_derive_internals`, `syn`, `quote`). The Swift equivalent is: factor shared codegen into a regular library target that `.macro` targets can import.

---

## Options

### Option A: Keep duplication (current state)

Maintain three identical copies of the codegen files.

**Structure**: No new packages. Each macro package contains its own copy of `PrismCodegen.swift`, `CaseDiscriminantCodegen.swift`, `ExtractionCodegen.swift`, `Utilities.swift`.

**Advantages**:
- Zero dependency graph changes.
- Zero coordination overhead for builds.
- ChatGPT Round 4 endorsement: "A little duplication is less damaging than a false semantic edge."

**Disadvantages**:
- Three copies to maintain. When codegen changes (e.g., new Finite.Enumerable requirements, new prism features), all three must be updated identically.
- The duplication is not principled — these are not "similar but evolving independently." They are identical routines generating identical infrastructure for identical type families (Optic.Prism, Finite.Enumerable). There is no reason for them to diverge.
- Contradicts the converged plan's explicit statement: "Shared codegen lives in a neutral support package."

**Verdict**: Acceptable short-term. Unacceptable as permanent architecture for "timeless infrastructure."

---

### Option B: Single micro-package `swift-enum-codegen-primitives`

Extract all four files into a new package at Layer 1 (Primitives) containing a single library target that macro implementations import.

**Structure**:
```
swift-primitives/swift-enum-codegen-primitives/
├── Package.swift
└── Sources/
    └── Enum Codegen Primitives/
        ├── PrismCodegen.swift
        ├── CaseDiscriminantCodegen.swift
        ├── ExtractionCodegen.swift
        └── Utilities.swift
```

**Package.swift dependencies**: `swift-syntax` only. No runtime primitives dependencies (the codegen generates string references to `Optic_Primitives`, etc. — it does not import them).

**Consumer usage**:
```swift
// In swift-dual/Package.swift
.macro(
    name: "Dual Macros Implementation",
    dependencies: [
        .product(name: "Enum Codegen Primitives", package: "swift-enum-codegen-primitives"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
    ]
),
```

**Advantages**:
- Single source of truth. One place to update when codegen evolves.
- Clear domain identity: this IS enum infrastructure codegen — prisms, discriminants, extraction. The name says what it is.
- Follows the Rust `serde_derive_internals` precedent.
- SwiftSyntax dependency is correctly isolated: only `.macro` targets consume it.

**Disadvantages**:
- **Layer placement is wrong.** Layer 1 (Primitives) answers "What must exist?" — and what must exist are the runtime types (`Optic.Prism`, `Finite.Enumerable`), not the codegen that happens to generate references to them. Codegen is implementation machinery for Layer 3 macros, not an atomic building block.
- **"Primitives" naming is misleading.** The ecosystem's Primitives are runtime types with zero or minimal dependencies. A SwiftSyntax-dependent code generator is categorically different from an `Ordinal` or an `Optic.Prism`.
- **False semantic edge risk.** `swift-optic-primitives` defines the Prism type. `swift-enum-codegen-primitives` generates code that references it. These are different concerns (runtime algebra vs compile-time text generation). Naming them as peers in the same layer conflates the distinction.

**Verdict**: Right idea (single source of truth), wrong layer and naming.

---

### Option C: Multiple micro-packages by concern

Factor into `swift-prism-codegen`, `swift-case-codegen`, `swift-extraction-codegen`.

**Advantages**:
- Maximum granularity.

**Disadvantages**:
- These are not independently meaningful. `ExtractionCodegen` generates prism infrastructure (Prisms struct, accessors). `CaseDiscriminantCodegen` generates Case enum used by extraction. They are one coherent concern (enum infrastructure) split into steps. All three consumers need all three. Nobody imports `swift-prism-codegen` alone.
- Three packages for ~280 lines of code. The overhead (3 Package.swift files, 3 dependency declarations per consumer) exceeds the benefit.
- Violates [MOD-DOMAIN]: a target must represent a coherent semantic domain, not a processing step.

**Verdict**: Over-decomposed. These are not separable concerns.

---

### Option D: Put shared codegen in the runtime primitives packages

Place `PrismCodegen.swift` in `swift-optic-primitives`, `CaseDiscriminantCodegen.swift` in `swift-finite-primitives`.

**Advantages**:
- Co-locates codegen with the types it generates.

**Disadvantages**:
- **SwiftSyntax contaminates runtime packages.** `swift-optic-primitives` and `swift-finite-primitives` are Layer 1 Primitives — zero-dependency atomic building blocks. Adding `swift-syntax` as a dependency is a fundamental layer violation. Every consumer of `Optic.Prism` (currently dozens of packages) would transitively depend on SwiftSyntax.
- Even if placed in a separate target within the package, SPM resolves the dependency at the package level. `swift package resolve` for `swift-optic-primitives` would fetch SwiftSyntax.

**Verdict**: Eliminated. SwiftSyntax in Layer 1 is a non-starter.

---

### Option E: Put shared codegen in swift-witnesses

Make `swift-witnesses` the canonical home. `swift-dual` and `swift-defunctionalize` depend on `swift-witnesses` for codegen.

**Advantages**:
- No new package. Reuses the original source.

**Disadvantages**:
- **False semantic edge.** `swift-dual` (category theory duality) depending on `swift-witnesses` (DI composition) creates a dependency that has no semantic justification. Duality does not depend on witness composition. The dependency exists only because the codegen happens to be there.
- **Circularity risk.** The converged architecture says `@Witness` may eventually compose on `@Defunctionalize`. If `swift-defunctionalize` already depends on `swift-witnesses` (for codegen), and `swift-witnesses` later wants to depend on `swift-defunctionalize` (for its Calls enum), the graph is circular.
- **ChatGPT Round 4's concern applies exactly here**: this IS a false semantic edge.

**Verdict**: Eliminated. Creates exactly the false semantic edge that was warned against.

---

### Option F: Library target inside a Layer 3 Foundations support package

Create a library target (not a macro target, not a product) within a new Foundations-layer package that exists specifically to hold shared macro support code. The library depends on SwiftSyntax and is consumed by `.macro` targets in other packages.

After further analysis, this is just Option B at a different layer. The naming and layer questions from Option B apply. We can address them.

**Revised proposal**: Place the shared codegen at Layer 3 (Foundations), named to reflect what it IS.

What is it? It is codegen for enum infrastructure. What enum infrastructure? Prisms, discriminants, extraction — the same infrastructure that `Optic_Primitives`, `Finite_Primitives`, `Ordinal_Primitives`, `Cardinal_Primitives` provide as runtime types. The codegen does not provide new primitives; it provides the compile-time machinery to generate code that references existing primitives.

**Name candidates**:

| Candidate | Assessment |
|-----------|------------|
| `swift-enum-codegen` | Describes the mechanism (codegen), not the domain. What kind of codegen? |
| `swift-enum-infrastructure-codegen` | Better — "enum infrastructure" is the domain. But "codegen" in a package name is unprecedented in the ecosystem. |
| `swift-enum-macro-support` | "Support" is vague. [MOD-DOMAIN] says targets must be concepts, not helpers. |
| `swift-enum-syntax` | Ambiguous — could mean SwiftSyntax extensions for enum declarations. |
| `swift-enum-generation` | Close but doesn't identify what is generated. |

All candidates struggle because the concept being named is genuinely a *process* (code generation), not a *thing* (a type). The ecosystem names packages after the domain they represent (`swift-optic-primitives` → Optic types, `swift-finite-primitives` → Finite types). There is no natural domain name for "SwiftSyntax routines that generate enum boilerplate referencing Optic/Finite/Ordinal/Cardinal primitives."

This observation is important. The difficulty naming the package is a signal.

---

## Analysis

### The naming difficulty is diagnostic

[API-NAME-001] says types use `Nest.Name`. [MOD-DOMAIN] says targets represent coherent semantic domains. The naming difficulty with Options B/C/F arises because "enum infrastructure codegen" is not a domain — it is an implementation detail of macro packages. Specifically:

- The *domain* is "enum infrastructure" — prisms, discriminants, extraction, case analysis.
- The *runtime types* for this domain live in `swift-optic-primitives` and `swift-finite-primitives`.
- The *codegen* is how macro packages generate references to those types.

The codegen is tightly coupled to the types it generates. When `Optic.Prism`'s API changes, `PrismCodegen.swift` must change. When `Finite.Enumerable`'s protocol requirements change, `CaseDiscriminantCodegen.swift` must change. This coupling is inherent and correct — it is not a false edge.

### Evaluating the "micro-package is acceptable" direction

The user said: "we accept these might be micro-package(s)." But [MOD-DOMAIN] constrains what a micro-package can be: it must be a coherent semantic domain. "Enum codegen" fails this test — it is not a concept, it is an implementation technique.

However, there is a deeper framing that does pass the test.

### Reframe: what concept IS this?

Consider what these four files actually provide:

1. **PrismCodegen**: Given case metadata → produce `Optic.Prism` source text
2. **CaseDiscriminantCodegen**: Given case names → produce `Finite.Enumerable` Case enum source text
3. **ExtractionCodegen**: Given case metadata → produce extraction properties, Prisms struct, accessors
4. **Utilities**: Identifier escaping, access-level analysis

Items 1–3 are *renderers*: they take a semantic description of enum cases and render it into source text that implements the enum infrastructure protocols. They are the "syntax layer" for enum infrastructure — analogous to how a serializer is the "wire layer" for a data model.

The concept is: **enum infrastructure syntax generation**. Or more concisely: the ability to render enum infrastructure as source text. This is the compile-time complement to the runtime types.

This reframing suggests: the shared code belongs *with* the macro infrastructure that uses it, not with the runtime types it references. Layer 3 is correct. The question is: which Layer 3 package?

### Comparison table

| Criterion | A: Keep duplication | B: L1 micro-package | C: Three micro-packages | D: In runtime packages | E: In swift-witnesses | F: L3 micro-package |
|-----------|:--:|:--:|:--:|:--:|:--:|:--:|
| Single source of truth | No | Yes | Yes | Yes | Yes | Yes |
| No false semantic edge | Yes | Mild (L1 naming) | Yes | **No** (SwiftSyntax in L1) | **No** (Dual→Witnesses) | Depends on naming |
| Layer correctness | N/A | **No** (codegen is not L1) | **No** (codegen is not L1) | **No** (SwiftSyntax in L1) | Yes (L3) | Yes (L3) |
| Maintenance burden | High (3 copies) | Low | Medium (3 packages) | Low | Low | Low |
| SwiftSyntax isolation | Yes (per-package) | Yes (dedicated package) | Yes | **No** | Yes | Yes |
| [MOD-DOMAIN] compliance | N/A | Questionable | **No** (process steps) | N/A | N/A | Questionable |
| No circularity risk | Yes | Yes | Yes | Yes | **No** | Yes |
| Consumer simplicity | Simplest (no dep) | 1 dep per consumer | 3 deps per consumer | 2 deps per consumer | 1 dep per consumer | 1 dep per consumer |

### The remaining candidates: A vs F

Options D and E are eliminated (SwiftSyntax contamination and false semantic edge, respectively). Option C is eliminated (over-decomposition, [MOD-DOMAIN] violation). Option B is eliminated (wrong layer).

The real decision is between A (duplication) and F (Layer 3 micro-package).

**Arguments for A (duplication)**:
1. ChatGPT Round 4: "A little duplication is less damaging than a false semantic edge."
2. ~280 lines total. The maintenance burden is real but bounded.
3. No dependency graph changes. No new packages to version, tag, publish.
4. The three macros may eventually diverge in their codegen needs (e.g., `@Witness` might need additional Case enum members for observe/unimplemented).

**Arguments for F (shared package)**:
1. The converged plan explicitly says "shared codegen lives in a neutral support package."
2. The Rust ecosystem proves this pattern works (`serde_derive_internals`).
3. When the codegen does change (e.g., Finite.Enumerable adds a new requirement), updating one place is strictly better than updating three.
4. Counter-argument to divergence: if `@Witness` needs extra Case enum members, it generates them in its own EnumExpansion.swift on top of the shared discriminant. The shared codegen produces the base; each macro adds its own extensions.

**The ChatGPT concern does not apply here.** "A little duplication is less damaging than a false semantic edge" is about not creating a dependency that misrepresents the semantic relationship. Option F does not create a false semantic edge if the shared package is correctly scoped: it represents "enum infrastructure syntax generation" — a coherent concern that all three macros genuinely depend on. The dependency `swift-dual → swift-enum-infrastructure-codegen` accurately says: "the Dual macro uses shared enum infrastructure codegen." That is true. It is not a false edge.

The ChatGPT concern **does** apply to Option E (swift-dual depending on swift-witnesses), where the dependency falsely implies that duality depends on witness composition.

---

## Outcome

**Status**: RECOMMENDATION

### Recommendation: Option F — shared library target at Layer 3

Extract the four shared files into a dedicated Layer 3 package.

**Package name**: `swift-enum-infrastructure-codegen`

This name is admittedly mechanical rather than domain-elegant. It violates the ecosystem's preference for domain-noun names (not process-verb names). But it is accurate, unambiguous, and there is no better alternative:
- "Enum infrastructure" identifies the domain (prisms, discriminants, extraction).
- "Codegen" identifies the layer (compile-time source generation, not runtime types).
- The name distinguishes it from the runtime packages (`swift-optic-primitives`, `swift-finite-primitives`) that define the types being generated.

**Package location**: `https://github.com/swift-foundations/swift-enum-infrastructure-codegen`

Layer 3 is correct because:
- The codegen is implementation machinery for Layer 3 macros.
- Layer 1 Primitives are runtime types; this is a compile-time tool.
- The package depends on SwiftSyntax, which is inappropriate for Layer 1.

**Structure**:
```
swift-enum-infrastructure-codegen/
├── Package.swift
└── Sources/
    └── Enum Infrastructure Codegen/
        ├── PrismCodegen.swift
        ├── CaseDiscriminantCodegen.swift
        ├── ExtractionCodegen.swift
        └── Utilities.swift
```

**Package.swift**:
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-enum-infrastructure-codegen",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "Enum Infrastructure Codegen", targets: ["Enum Infrastructure Codegen"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        .target(
            name: "Enum Infrastructure Codegen",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Note: This is a regular `.target`, not a `.macro` target. Macro targets are compiler plugin executables. This is a library that macro targets link against. The same pattern as `swift-macro-toolkit` or Rust's `serde_derive_internals`.

**Consumer integration** (e.g., in swift-dual):
```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    .package(path: "../swift-enum-infrastructure-codegen"),
    // ...runtime deps...
],
targets: [
    .macro(
        name: "Dual Macros Implementation",
        dependencies: [
            .product(name: "Enum Infrastructure Codegen", package: "swift-enum-infrastructure-codegen"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        ]
    ),
]
```

### Implementation sequence

1. **Create the package** with the four files extracted from `swift-witnesses/Sources/Witnesses Macros Implementation/EnumExpansion.swift` (lines 20-360) and `WitnessMacro.swift` (lines 664-681 for `hasRestrictedAccess`/`canInline`). Make all types and functions `public`.
2. **Migrate swift-dual** to import `Enum_Infrastructure_Codegen` instead of its local copies.
3. **Migrate swift-witnesses** to import `Enum_Infrastructure_Codegen` and remove the duplicated code from `EnumExpansion.swift` and `WitnessMacro.swift`. `EnumExpansion.swift` retains `extractEnumCases`, `generateEnumPrismMembers`, `generateEnumComputedProperty`, and `generateEnumPrismProperty` (which call into the shared codegen) — these are witness-specific orchestration.
4. **swift-defunctionalize** imports `Enum_Infrastructure_Codegen` from day one.
5. **Test**: `swift test` in all three packages after migration.

### Precedent established

This recommendation establishes: **shared macro codegen across Layer 3 packages lives in a dedicated Layer 3 library package, not in the runtime primitives packages it references.** The library depends on SwiftSyntax and is consumed only by `.macro` targets.

### Acceptable alternative: defer extraction until swift-defunctionalize exists

If the preference is to avoid creating a package before the third consumer exists, Option A (duplication in swift-dual and swift-witnesses, with the converged plan's intent to extract later) is the pragmatic interim. The extraction should happen when `swift-defunctionalize` is implemented — at that point, three consumers make the case for shared infrastructure clear.

---

## References

- Converged architecture: `Research/prompts/swift-dual-implementation.md`
- Architecture memory: `dual-defunctionalize-architecture.md` (MEMORY.md)
- swift-witnesses EnumExpansion.swift: `https://github.com/swift-foundations/swift-witnesses/blob/main/Sources/Witnesses Macros Implementation/EnumExpansion.swift`
- swift-witnesses WitnessMacro.swift: `https://github.com/swift-foundations/swift-witnesses/blob/main/Sources/Witnesses Macros Implementation/WitnessMacro.swift`
- [MOD-DOMAIN], [MOD-001]–[MOD-005]: `Skills/modularization/SKILL.md`
- [RES-003], [RES-021]: `Skills/research-process/SKILL.md`
- Rust precedent: `serde_derive_internals` crate (serde-rs/serde, proc-macro shared internals)
- Swift precedent: `swift-macro-toolkit` (stackotter, shared SwiftSyntax utility library)
- CasePaths (Point-Free): single-package enum case path macro, no shared codegen extraction
