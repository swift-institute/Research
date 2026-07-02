# Modularization Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/modularization/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> lint-enforcement scope detail, and the dated amendment changelog. The skill file remains the CANONICAL
> source for all `[MOD-*]` requirement statements; nothing in this archive is normative. Organized by rule
> ID in skill order; the dated frontmatter changelog entries are collected in the final section.

---

## §[MOD-PLACE] Lowest-Correct-Layer Placement (axiom)

**Rationale (full text)**: [MOD-DOMAIN] applied across layers — factor each law to the layer that owns it. The tower is the unique orthogonal basis of a stored data structure's design-decision space (Reynolds; Parnas; Mitchell–Plotkin); placing a concern correctly *is* expressing it in that basis. The recurring failure was re-deriving placement ad hoc; this axiom plus the closed inventory make placement a **lookup**, not a debate.

---

## §[MOD-002] External Dependency Centralization

**Rationale for the amendment (full text)**: Under [MOD-001], external deps centralize in Core so an upgrade affects one `dependencies:` declaration. Under [MOD-031], the equivalent property is preserved at the sub-namespace level — each sub-namespace target declares only the externals it uses, and an external-package upgrade affects only the sub-namespace targets that actually use it. The locality is finer-grained but the principle is the same.

**Rationale (full text)**: Centralizing external dependencies means upgrading an external package affects one `dependencies:` declaration, not N. This is the Parnas information-hiding criterion applied to dependency management.

---

## §[MOD-003] Variant Decomposition

**Rationale (full text)**: Variant independence enables selective import — a consumer needing only `Buffer_Ring_Primitives` pays no compile-time cost for Linear's algorithms. Parnas: each variant hides one design decision (its strategy). Baldwin-Clark: independent variants maximize option value.

---

## §[MOD-004] Constraint Isolation

**Rationale (full text)**: This is the strongest theoretical result from the literature study. Walker (2005) proves substructural constraints compose conjunctively — if `S` conforms to `Collection` with `Element: Copyable`, the constraint propagates to all uses. Module separation leverages the scope-limiting property of existential types (Mitchell-Plotkin 1988): the constraint is existentially quantified within its module and only propagates when imported. **Constraint isolation is type-theoretically necessary, not merely pragmatic** (SE-0427 context). This pattern is the dominant modularization driver for the entire data structure stack (storage → buffer → array/stack/queue/slab/set/dictionary).

---

## §[MOD-005] Umbrella Re-export

**Acyclicity — verified exemplar**: Verified at `swift-buffer-linear-primitives` `fdce249`: `Buffer Linear Primitives` re-exports `Buffer_Linear_Primitive` + `Buffer_Linear_{Bounded,Inline,Small}_Primitives` + `Sequence_Primitives`, and each variant ops depends on a TYPE module, not on `Buffer Linear Primitives`.

**Exemplar (non-aggregating, full text)** — `swift-hash-table-primitives` (2026-05-28): `Hash.Table` (dynamic/heap) and `Hash.Table.Static` (inline) are mutually exclusive per consumer — a dynamic ordered set/dictionary embeds `Hash.Table`, a static one embeds `Hash.Table.Static`, never both in one module. So `Hash Table Primitives` (base ops + umbrella) re-exports only `Hash_Table_Primitive`, NOT `Hash_Table_Static_Primitives`; the static variant is reached by importing `Hash_Table_Static_Primitives` (or its type module) directly. Consumer split verified: `Set.Ordered`/`Dictionary.Ordered` (dynamic) import `Hash_Table_Primitives`; `Set.Ordered.Static`/`Dictionary.Ordered.Static` import the static product.

---

## §[MOD-016] @_spi Per-File Opt-In

**Rationale (full text)**: Each `.swift` file is an independent compilation unit for SPI purposes. The per-file ceremony ensures every file that reaches into SPI members explicitly declares that intent, making the SPI boundary auditable (`grep @_spi(Syscall)` identifies all boundary code). The 81-file burden in iso-9945 is proportional to the risk and documents the exact blast radius.

**Provenance**: `swift-kernel-primitives/Research/spi-and-path-cleanup.md`, 2026-04-10.

**Lint enforcement (DEFERRED — full narrative, mechanization attempted 2026-05-13)**: a pilot promotion attempt under `/promote-rule` constructed `Lint.Rule.Structure.SpiPerFile` with file-scoped detection (file has `_<lowerCamelCase>` member access AND zero `@_spi(` imports → flag). The full-AST validation ladder revealed the heuristic produces dense false positives on the institute's `_storage` / `_base` private-storage convention: `swift-carrier-primitives` 8 findings, `swift-property-primitives` 33 findings — all intra-module private-field references, none cross-module SPI. The rule's underlying principle is correct (per-file `@_spi` is a Swift compiler invariant) but the mechanization requires module-of-origin semantic info that SwiftSyntax does not surface; AST-only detection cannot distinguish intra-module `_X` private convention from cross-module SPI access. Rule artifacts reverted; outcome record at `swift-institute/Audits/PROMOTE-MOD-016-2026-05-13.md`. Mechanization deferred pending either (a) a semantic-aware linter pass with module-resolution info, or (b) a workflow validator that uses `swift build` diagnostics or `swift package describe` to track SPI imports per target.

---

## §[MOD-017] `{Domain} Primitive` — Namespace + Foundational-Types Root Target

**Rationale (full text)**: Extenders whose sole need is to add a sub-namespace (`extension Kernel { public enum Futex {} }` in `swift-linux-standard`; `typealias Darwin.Kernel = Kernel` in `swift-darwin-standard`) import `{Domain} Primitive` and acquire zero transitive external weight — but only as long as the zero-dep invariant holds. Merging the namespace and Core declaration-roles into one singular target removes the former two-target ceremony (`{Domain} Namespace` + `{Domain} Primitives Core`) while preserving the cheap-import property: `{Domain} Primitive` stays dependency-free, and external-dep-bearing foundational declarations live in sub-namespace targets per `[MOD-031]`. This is the smallest Parnas information-hiding partition of the package: the dependency-free root is separable from the external-dep-bearing type catalog.

**Provenance**: Kernel Namespace case study, 2026-04-21 (original separate `{Domain} Namespace` split). Merge into the singular `{Domain} Primitive` verified 2026-05-24 against `swift-buffer-primitives` (`Buffer Primitive`, `dependencies: []`) and `swift-sequence-primitives` (`Sequence Primitive`, `dependencies: []`; its `exports.swift` cites this rule's zero-dep invariant). Principal direction 2026-05-24.

---

## §[MOD-006] Dependency Minimization

**Benchmark**: parser-primitives achieves mean 1.2 sibling dependencies per target across 34 non-umbrella targets.

**Rationale (full text)**: Minimal dependencies keep incremental compile times proportional to the change. Stevens-Myers-Constantine coupling density at ~7% is exceptionally low and near-optimal for balancing connectivity with independence. Adding a feature to Parser Error Primitives recompiles only the ~12 targets that depend on it, not all 34.

---

## §[MOD-007] Dependency Graph Shape

**Measured exemplars** (evicted; the depth metric + rationale remain in-skill):

| Package | Max Depth | Shape |
|---------|-----------|-------|
| parser | 2 (Core → Take → Many) | Wide fan, one 2-deep chain |
| buffer | 3 (Core → Linear → Linear Inline → Linear Small) | Wide fan, per-variant 2-3 depth |
| memory | 2 (Core → StdLib Integration → Arena/Pool) | Flat star |

---

## §[MOD-015] Consumer Import Precision

**Supplementary-decomposition example pair** (evicted; the primary-decomposition pair remains in-skill):

**Correct** (supplementary decomposition — umbrella is canonical):
```swift
// Sequence protocols are the main product — umbrella is canonical
import Sequence_Primitives

// Cardinal arithmetic is the main product — umbrella is canonical
import Cardinal_Primitives
```

**Incorrect** (supplementary decomposition — Core is not consumer-facing):
```swift
// ❌ Core is an implementation detail, not a consumer-facing product
import Sequence_Primitives_Core
```

**Rationale (full text)**: Primary decomposition packages can have 10–35 variant modules. Importing the umbrella defeats the modularization investment — consumers pay compile-time cost for every variant and lose the signal of which specific capabilities they depend on. Supplementary decomposition packages have 1–2 minor additions atop a complete Core; the umbrella adds negligible overhead and is the natural consumer interface.

**Provenance**: Import precision audit, 2026-04-03 (`swift-primitives/Research/audit.md`).

---

## §[MOD-015a] Narrow-Imports Exception for Shadow Disambiguation

**Alternative (rejected)**: making Core a product. Making Core publishable would fix the qualification path but defeats the Core-is-internal invariant per [MOD-001]. The umbrella pathway preserves Core's internal role while giving consumers a declared-module anchor.

**Rationale (full text)**: The narrow-imports preference is correct in the common case and reduces compile-time coupling. The shadow-disambiguation case is an exception, not a violation — the same reasoning that makes narrow imports preferable does not account for the structural difference between visibility and declaration in Swift's module system. Codifying this exception prevents consumers from fighting the compiler when stdlib-conforming types bring stdlib namespaces into scope.

**Provenance**: Reflection `2026-04-15-completion-loop-proactor-reactor-boundary.md`.

---

## §[MOD-008] Split Decision Criteria

**Evidence**:

| Target | Files | Split Justification |
|--------|-------|---------------------|
| Parser Optional | 3 | Different dep set (Core only, no Error) |
| Parser Peek | 2 | Unique concern (non-consuming lookahead) |
| Parser Take | 8 | Complex, many dependents |
| Parser Many | 5 | Delegates to Take, separate concern |

---

## §[MOD-014] Cross-Package Optional Integration

**Form 2 — Trait-gate manifest examples** (evicted; the extraction example remains in-skill):

**Correct** (provider package):
```swift
let package = Package(
    name: "swift-dependencies",
    products: [
        .library(name: "Dependencies", targets: ["Dependencies"]),
        .library(name: "Clocks Dependency", targets: ["Clocks Dependency"]),
    ],
    traits: [
        .trait(name: "Clocks"),
    ],
    dependencies: [
        .package(path: "../swift-witnesses"),
        .package(path: "../../swift-primitives/swift-clock-primitives"),
    ],
    targets: [
        .target(name: "Dependencies", dependencies: [
            .product(name: "Witnesses", package: "swift-witnesses"),
        ]),
        // MARK: - Integration
        .target(name: "Clocks Dependency", dependencies: [
            "Dependencies",
            .product(name: "Clock Primitives", package: "swift-clock-primitives",
                     condition: .when(traits: ["Clocks"])),
        ]),
    ]
)
```

**Correct** (consumer package):
```swift
.package(path: "../swift-dependencies", traits: ["Clocks"]),
// ...
.product(name: "Clocks Dependency", package: "swift-dependencies"),
```

**Rationale (full text)**: SE-0450 traits remove the *resolution and compile cost* of an optional integration but NOT the *manifest coupling* — A still declares B in its `Package.swift`, so the package-graph edge A → B survives with the trait off. Extraction removes the coupling outright at the cost of one more package; under maximum decomposition that package is worth it, and "unnecessary proliferation" was the wrong default for the single-integration-target case. Traits remain correct only as the structural fallback when extraction cannot achieve clean layering. Validated forms: swift-dependencies clock integration (trait fallback; research: `cross-package-integration-strategies.md`); Bit ⊗ Algebra-Field bridge (extraction default, 2026-05-28).

**Provenance (weakening, 2026-05-28)**: principal direction. A trait leaves the `.package(...)` edge in the depending package's manifest; when manifest-level decoupling is the goal a single-integration-target package is correct, and the prior "❌ separate repository for a single integration target — unnecessary proliferation" prohibition is retracted. Breaking per [SKILL-LIFE-003] (inverts the rule's default); discussion satisfied by principal direction. Motivating case: swift-bit-primitives' sole use of swift-algebra-field-primitives — the `Algebra.Field<Bit>.z2` witness in `Bit Field Primitives`.

---

## §[MOD-024] Test Support Spine Discipline

**Rationale — verification history**: The Tagged ExpressibleBy*Literal conformances live in `Tagged_Primitives_Standard_Library_Integration`. The single-hop chain pattern (Phase 1 exemplar: `swift-iso-9945` `Tests/Support/exports.swift`) is verified across the swift-primitives ecosystem (Phase 2a, 2026-05-04: 114/132 packages with TS, 0 violations, 0 missing).

**Spine-completion gap — provenance**: 2026-05-07 dep-cleanup-pass execution surfaced 6 such gaps (lexer, memory, parser TS shells); all closed by `@_exported` additions, none by dep removal.

**Self-application worked example (the origin incident, 2026-05-08)**: the swift-linter X1 wave installed the [MOD-024] Test Support spine in 3 of 5 cohort packages — `swift-manifest-primitives`, `swift-manifests`, `swift-linter-rules` (with `swift-linter-primitives` pre-existing) — but NOT in swift-linter itself, the pilot. The rule's self-application to the pilot was missed at the wave's authoring time. swift-linter's release-readiness Phase 1 gap #6 surfaced this as a structural gap; the disposition is CONDITIONAL GO (accept-as-known) at 0.1.0 with the spine added before the cohort's third package tags. Codifying the self-applies-to-pilot step prevents recurrence: future cohort waves that install [MOD-024] verify the pilot first, then propagate.

**Provenance (self-application step, 2026-05-08)**: swift-linter D5 release-readiness brief Phase 1 #6 (Test Support spine missing on swift-linter pilot); reflection `2026-05-04-test-support-spine-strict-rollout-and-mod-024.md`; `swift-institute/Research/swift-linter-launch-skill-incorporation-backlog.md` row 1.18.

---

## §[MOD-031] Per-Sub-Namespace Decomposition Default

**Status verification**: Verified 2026-05-24 against `swift-buffer-primitives` (`Buffer Primitive`) and `swift-sequence-primitives` (`Sequence Primitive`), both with `dependencies: []` on the root.

**Worked example — `swift-sequence-primitives`** (the [MOD-031] pilot; shape verified 2026-05-24):

| Tier | Targets | External deps |
|---|---|---|
| 0 | Sequence Primitive (singular — namespace + foundational types; `dependencies: []`) | (none) |
| 1 | Sequence Iterator Primitives | Index Primitives |
| 2 | Sequence Protocol Primitives, Sequence Borrowing Primitives | Index Primitives (Protocol only) |
| 3 | Sequence {Map, Filter, FlatMap, CompactMap, Drop, Prefix, ForEach, Satisfies, Contains, First, Reduce, Hint, Drain, Consume, Clearable, Difference, Span} Primitives + Sequence Primitives Standard Library Integration | Per-target: Index Primitives (where Cardinal used), Property Primitives (where Property.Inout used) |
| umbrella | Sequence Primitives | All sub-targets |
| test support | Sequence Primitives Test Support | Sequence Primitives + Index Primitives Test Support |

The singular `Sequence Primitive` root + sub-namespace targets + umbrella + test support. Max depth from the `Sequence Primitive` root to any leaf = 3, within `[MOD-007]`'s guideline.

**Provenance**: 2026-05-21 swift-sequence-primitives pilot (commit `fa52679`). The principal noted "other packages have done [Option B coarser decomposition] in the past, but always it turns out [Option A maximum-granular] is preferable. And we're doing this process for each package we're publishing, and each time A is the best." [MOD-031] codifies the practice that had already been emerging as the converged shape per publication arc.

**Naming correction provenance (2026-05-21)**: Initial pilot at `fa52679` used `{Domain} {SubName}` (no `Primitives` suffix) for sub-namespace targets. Principal correction during ownership-primitives Wave 3 audit (2026-05-21): primitive packages MUST keep the `Primitives` suffix at all times to ensure unique primitives module names across the ecosystem. Pilot package (sequence-primitives) renamed in commit `a7982a7` to match the corrected convention; rule + worked-example table updated in this commit. (The suffix-retention requirement itself remains stated in the skill: [MOD-031] Statement + [MOD-012] naming tables.)

**Root-merge provenance (2026-05-24)**: principal direction to fold the former `{Domain} Namespace` and `{Domain} Primitives Core` roles into a single singular `{Domain} Primitive` published target. Verified against `swift-buffer-primitives` (`Buffer Primitive`) and `swift-sequence-primitives` (`Sequence Primitive`), both `dependencies: []`; the latter's `Sequence Primitive/exports.swift` cites `[MOD-017]`'s zero-dep invariant by name.

---

## §[MOD-012] Target Naming Convention

**Type/ops-split verified exemplar**: Verified at `swift-buffer-linear-primitives` `fdce249`.

**Provenance**: Reflection `2026-03-24-swift-io-audit-consolidation.md`.

---

## §[MOD-EXCEPT-001] Platform Packages

**Established**: 2026-03-20 (ecosystem-wide modularization audit)

---

## §[MOD-EXCEPT-002] Placeholder/Stub Packages

**Established**: 2026-03-20 (ecosystem-wide modularization audit)

---

## §[MOD-020] Dependency-Delta Check Before New-Primitive-Package Proposal

**Rationale (full text)**: Target-splits are cheap and preserve single-package consumer imports; new packages multiply the ecosystem's surface, the Package.swift maintenance load, and the cross-package version alignment burden. The delta check makes package creation an exception rather than a default.

**Provenance**: 2026-04-21-danceui-noun-convention-rename-cascade.md (swift-attribute-graph-primitives reversal)

---

## §[MOD-021] Documentation-Fidelity Consequences of Multi-Target + Umbrella Shape

**Rationale (full text)**: `@_exported` re-exports are a Swift-compiler feature; the doc-comment-strip is a consequence of the symbol-graph emitter treating re-exports as references, not declarations. The merge workflow restores the docs to the umbrella archive by piecing symbol graphs together. The rule surfaces a consequence of `@_exported` that authors routinely miss, leading to empty umbrella-archive symbol pages.

**Provenance**: 2026-04-21-property-primitives-handoff-execution-and-docc-aggregation-research.md

---

## §[MOD-022] Mechanical Coupling Inventory Before Scope Estimation

**Rationale (full text)**: Scope estimates derived from a partial build's error count are biased in both directions: the build may have stopped before surfacing most errors (underestimate), or may have surfaced errors from templated sites all deriving from one logical error (overestimate). A 30-minute mechanical scan produces a bounded, reviewable number; extrapolation produces a range the reviewer cannot verify.

**Provenance**: 2026-04-22-strict-modularization-and-case-relocation.md

---

## §[MOD-RENT] Two-Criteria Primitive-Package Rent Test

**Worked example (the origin incident, full text)**:

The 2026-04-26 ecosystem audit applied the test to `swift-lifetime-primitives`:

| Criterion | Lifetime.Lease | Lifetime.Disposable | Lifetime.Scoped |
|-----------|----------------|---------------------|-----------------|
| Capability | **Failed** — structurally identical to `Ownership.Unique` (both `~Copyable`, `UnsafeMutablePointer<Value>` storage, same access pattern); Lease has weaker semantics (runtime `_released` trap vs Unique's compile-time linear enforcement) | **Failed** — adds nothing the language doesn't provide; `consuming` methods + `~Copyable` `deinit` cover the pattern | **Failed** — `defer` in struct form |
| Theoretical content | **Failed** — no structural invariant beyond Ownership.Unique | **Failed** — symbolic protocol with no laws | **Failed** — no invariant beyond `defer` |

Both criteria failed for all three types in the package. The package was deleted from the workspace; commented-out lifetime-primitives deps were stripped from five other primitive packages (`swift-continuation-primitives`, `swift-handle-primitives`, `swift-cache-primitives`, `swift-state-primitives`, `swift-loader-primitives`) that had never actually used the package — visible signal that the failure was apparent to authors but no one had applied the test to act on it.

**Rationale (full text)**: Primitive packages bear ecosystem weight — each adds a Package.swift target, a maintenance surface, a review cost on every adjacent change, and a decision fork ("absorb or add?") for future designers. The hurdle rate for adding or retaining a primitive package is therefore higher than for adding a type internal to one package. The two-criteria test is a default-explicit gate against the conceptual-purity defense pattern: a package that fails capability or theoretical content is failing rent regardless of how cleanly its conceptual scope reads.

**Provenance**: Reflection `2026-04-26-ecosystem-audit-and-typed-tls-promotion.md`. 2026-05-14: pull-down interaction note added alongside the `[RES-018]` BREAKING revision. 2026-06-09 BREAKING: removed the **consumer** criterion (criterion 2) and the [RES-018]-case-(c) interaction note — package existence is judged on capability + theoretical content only; consumer / adoption count is no longer a decision driver (principal direction, first-principles MO; per [ARCH-LAYER-008]).

---

## §[MOD-023] `#externalMacro` Module Name Normalization

**Why this fires**: Swift normalizes Package.swift target names by replacing spaces with underscores per [PATTERN-004b]. The normalized form is what the compiler sees as the module identifier in `import` statements and macro module references. A handoff brief or copy-paste from documentation may carry the un-normalized or collapsed-space form; the compile error ("no such module") is clear but the fix is mechanical.

**Rationale (full text)**: Module name normalization is an implicit compiler step at the SwiftPM-target boundary. Macro declarations cite module names by string literal; the literal MUST match the normalized form that the compiler emits. Codifying the normalization rule for `#externalMacro` specifically prevents the friction that otherwise discovers the rule via compile-time failure on every new macro target.

**Provenance**: Reflection `2026-04-26-observable-macro-twin-design-and-validation-gap.md` (initial brief specified `module: "ObservationsMacros"`; SwiftPM target `"Observations Macros"` produces module identifier `"Observations_Macros"`, requiring the underscore form).

---

## §[MOD-025] Dep-Cleanup-Pass Audit Procedure

**Rationale (full text)**: Dep cleanup is high-leverage (smaller resolved graphs, faster CI, clearer ownership) but failure-modes are silent: dropping a uniquely-providing dep breaks downstream consumers only when they next build, often weeks later. The procedure's safety properties — uniquely-providing classification, transitive @_exported following, spine exclusion, per-edit clean-build verification — collectively eliminate the class of failure where a dep looks unused at the source level but is load-bearing for re-export chains. The 2026-05-07 ecosystem sweep across 135 packages produced zero post-cleanup build regressions when the procedure was followed; the same audit's earlier iterations (before bugs (a)–(d) were fixed) generated phantom UNUSED findings that would have broken three packages if executed.

**Provenance**: 2026-05-07 dep-cleanup-pass audit and execution across 135 swift-primitives packages. Reflection: `swift-institute/Research/Reflections/2026-05-07-dep-pass-audit-and-cleanup-execution.md`. Bugs (a) skip-commented, (b) url-resolve, (c) @_exported-chain, (d) Tests/Support scan were each surfaced by individual case-verification rounds against the v1 script.

---

## §[MOD-026] Fine-Grained Per-Type Modularization Default in Multi-Type L3 Packages

**Why default to fine (full text)**: consumers who need `Kernel.Thread.Barrier` alone should not be forced to compile `Gate`, `Pool`, `Semaphore`, `Worker`. The compile-cost asymmetry is real (a barrier-only consumer of a coarse "Thread Synchronization" target compiles ~5× more code than they need), and the import-precision rules ([MOD-015]) only enforce narrow imports if narrow products *exist*. The package author's default decomposition determines whether [MOD-015] has narrow targets to point at.

**Provenance**: 2026-04-15 user feedback during Kernel.Thread package design — initial plan bundled all thread-coordination types into one "Thread Synchronization" target; user corrected to per-type targets (`Thread Barrier`, `Thread Gate`, etc.).

---

## §[MOD-027] `internal import` Is Incompatible With `@inlinable` Bodies Referencing the Module's Public API

**Prior art**: `@_disfavoredOverload` on 10 iso-9945 Read/Write declarations at swift-iso-9945 `9aa06e6` (canonical pattern).

**Provenance**: memory `feedback_inlinable_blocks_internal_import.md` (2026-04-20 Read/Write L2/L3 ambiguity investigation; import-demotion produced double-digit "internal and cannot be referenced from @inlinable" errors before emitting any module).

---

## §[MOD-028] Cross-Module Nested Extension Member Resolution Workaround

**Provenance**: memory `feedback_cross_module_extension_visibility.md` (Swift 6.2 BW Boek 2 article-typealias workaround).

---

## §[MOD-029] Split Decisions Weight UPSTREAM Dep Tree, Not DOWNSTREAM Consumer Count

**Why (full text)**: Domain-split exists to keep dependency graphs minimal and reasoning local. The right test is "if I extracted this module, would the graph prune?" — that question's answer is determined by upstream coupling, not downstream popularity. Counting consumers measures adoption, which is orthogonal to architecture. A widely-used module isn't necessarily multi-domain; a single-consumer module isn't necessarily single-domain.

**Provenance**: memory `feedback_split_upstream_not_downstream.md` (recurring correction during package-split evaluations).

---

## §[MOD-030] Combinator/Leaf-Type Micro Modules Are Deliberate

**Why (full text)**: Micro modules carry three independent properties that bulk modules cannot replicate at once:

1. **Optional adoption** — consumers import only the family they need (e.g., `Parser Many Primitives` without `Parser OneOf Primitives`). [MOD-015] consumer-import-precision only has narrow products to point at when the package author's decomposition is fine-grained.
2. **Parallel compilation** — independent modules compile in parallel, and per-module compile cost stays proportional to the consumer's actual surface, not to the union of all combinator families.
3. **Conformance modularity** — each module hosts its own conditional conformances (e.g., the ~18 `Parser.Printer` conditional conformances spread across combinator modules in swift-parser-primitives). Revising one conformance does not perturb compilation of unrelated combinators.

**Worked example (the origin incident, full text)**:

A 2026-05-13 transformation-domain audit examined whether swift-parser-primitives' 37 modules (33+ combinator modules) could be unified via variadic generics into a single `Parser.OneOf<each P>` shape — collapsing per-arity `OneOf.Two`/`OneOf.Three` into one. The spike (`swift-institute/Experiments/variadic-oneof-same-element-blocker/`) refuted the unification path on three independent compiler blockers (same-element requirements, primary-associated-type placeholder rejection, pack-member associated-type access). The audit then proposed a separate consolidation pass ("33 → 5 categories") as an axis of unification independent of variadic generics. The user reversed both proposals: variadic was already blocked upstream; the consolidation was not desired regardless. The institute's intended granularity IS one module per combinator family, not a workaround for the absent variadic shape.

**Provenance**: 2026-05-13 transformation-domain audit + collaboration discussion (this session). The variadic-oneof experiment is the empirical anchor; the user's reversal of the consolidation proposal codifies the rule.

---

## §[MOD-032] No Package-Level Cycles, Even SwiftPM-Tolerated

**Why (full fragility list)**: SwiftPM's cycle detection operates at the target-graph level. A configuration where two packages have bidirectional `.package(path:)` declarations but the underlying target dependencies form an acyclic graph compiles and tests cleanly today. It is fragile to:

- Future SwiftPM versions that tighten cycle detection
- Alternate build systems (Bazel, Buck) that operate at the package-graph level
- URL-form switchover (the cycle becomes a manifest-resolution failure when packages resolve from remotes rather than paths)
- Other PackageDescription consumers (IDEs, audit tools, dependency analyzers)

Pre-1.0 "timeless infrastructure" quality demands true acyclicity, not "works today by accident."

**Worked example (the origin incident, full text)**:

The 2026-05-22 binary-primitives readiness program's Chain C extracted `Cardinal Carrier Primitives` to `swift-cardinal-carrier-primitives`. The new sibling depended on `swift-cardinal-primitives` for `Cardinal_Primitive`; the owner depended on the new sibling for `.zero`/`.one` accessors used by `Cardinal Subtract Primitives` (an owner-stayer). Both packages built and tested cleanly because the target graph was acyclic — but the package graph carried a bidirectional `.package(path:)` cycle. Discovered post-push; reverted as the only structurally-correct disposition. Same shape repeated in Ordinal-Cardinal, Affine-Carrier, Affine-Tagged, Affine-Ordinal, Comparison-Property — six reverts total. Codified as binding rule by principal direction 2026-05-22.

**Provenance**: 2026-05-22 Cohort I revert pattern (Chain C Cardinal Carrier + Ordinal Cardinal pushed cycles; Chain A Affine Carrier + Tagged + Ordinal extracted then reverted; Chain D Comparison Property extracted then reverted). Principal direction: "we CANNOT have a cycle."

---

## §[MOD-033] Pre-Extraction Owner-Internal Fan-In Check

**Worked examples (full text)**:

- **Memory Cursor extraction (pilot, clean)**: `swift-cursor-primitives/Sources/Cursor Primitives/exports.swift` did NOT re-export `Memory_Cursor_Primitives` (it was a capability layer, not exported from the umbrella). [MOD-033] passed; extraction proceeded without controversy.
- **Affine Ordinal extraction (rejected)**: `swift-affine-primitives/Sources/Affine Primitives/exports.swift` re-exported `Affine_Ordinal_Primitives` via `@_exported public import`. The umbrella-drop path was structurally available, but [MOD-034] also fired (Ordinal participation is foundational to Affine), so the extraction was rejected on both axes.
- **Cardinal Subtract reaching .zero/.one in Cardinal Carrier (rejected)**: `swift-cardinal-primitives/Sources/Cardinal Subtract Primitives/*.swift` imported `Cardinal_Carrier_Primitives`. The source-file fan-in was the cycle vector; refactoring stayers to use `.underlying` (Carrier base accessor) was structurally available but [MOD-034] foundational-conformance check also fired, so extraction was rejected on both axes.

**Provenance**: 2026-05-22 Chain B Binary Format pre-flight (caught `Sources/Binary Primitives Standard Library Integration/RawRepresentable+Format.swift` importing the moving target before push; resolved via Option I file-move-into-sibling) + Cohort I revert pattern at large.

---

## §[MOD-034] Pre-Extraction Identity-Defining-Surface Check

**Why the asymmetry (full text)**: Foundational conformances are how `{Domain}` defines its own behavior. Owner-stayer code USES the conformance internally to express algebraic structure, equality, ordering, hashability, etc. Extracting the conformance to a sibling package inverts the dependency: the owner now depends on the sibling for its own identity surface, which is structurally backwards. The cycle test [MOD-033] catches the mechanical symptom; [MOD-034] catches the architectural root cause and applies even when the cycle test would technically pass (e.g., via umbrella-drop workaround).

**Worked examples (full text)**:

- **Cardinal Carrier** (rejected): `carrier` ∈ FOUNDATIONAL_ROLES. Cardinal IS a Carrier of Int; `.zero`/`.one` are part of Cardinal's identity. Extraction inverts dep.
- **Affine Tagged** (rejected): `tagged` ∈ FOUNDATIONAL_ROLES. `Affine.Discrete.Vector` IS a Tagged<Tag, Int>; the Tagged conformance is identity-defining. Independently confirmed by Tagged-vs-Carrier research (`swift-institute/Research/affine-vector-representation-tagged-vs-carrier.md`).
- **Comparison Property** (rejected): `property` ∈ FOUNDATIONAL_ROLES. Property defines identity surface that Comparison uses internally.
- **Memory Cursor** (accepted): `cursor` ∈ INCIDENTAL_ROLES. Cursor is a capability layer over Memory's substrate; Memory's identity doesn't depend on cursor.
- **Binary Format** (accepted): `format` ∈ INCIDENTAL_ROLES. Output formatting is a capability over Binary; Binary's identity (parsing/structure) doesn't depend on format.

**Provenance**: 2026-05-22 Chain A revert (Affine Carrier + Tagged + Ordinal) + Chain C revert (Cardinal Carrier + Ordinal Cardinal) + Comparison Property revert + Tagged-vs-Carrier research (`affine-vector-representation-tagged-vs-carrier.md` v1.0.0 RECOMMENDATION). Principal direction: foundational conformances "provide value to {owner} directly; extraction does not make sense."

---

## §[MOD-035] Scope Statement Required for L1 Primitives Packages

**Why (full text)**: Without a written scope, every contribution is judged against the contributor's intuition of "what fits." Memory-primitives' scope can be argued either way: "memory is addressing + alignment + nothing else" (lean) or "memory is everything memory-related" (open-ended). The package converges on the looser reading because there's no codified boundary; sub-targets like Pool, Buffer, Arena, Lock, Shared, Map accrete over time, each justifiable in isolation, none individually triggering a reject. Together they expand memory's surface beyond its identity. A written scope statement fixes the boundary at the package-design level, before the per-sub-target judgment is needed.

**Worked example (the origin incident, full text)**: 2026-05-22 memory-primitives Cohort II semantic analysis. The discriminator-v3.5 ran cleanly on memory-primitives but identified zero role-based extractions (Step 5 caught Carrier/Tagged extractions ecosystem-wide; none in memory). Pool, Buffer, Arena, Lock, Shared, Map all passed Step 5 (none are foundational roles by name) and Step 4 (cycle pre-flight passed via umbrella drop). What the discriminator could NOT decide was whether they were *in scope* for memory-primitives' identity. The principal's semantic analysis articulated the scope statement in the skill's worked example; the six sub-targets extracted as outside-scope. Without the scope statement, the discriminator's "clean" verdict would have been read as "extract or keep, both are fine" — and the question of whether memory's identity should expand to include allocation strategies would have remained ambient.

**Provenance**: 2026-05-22 memory-primitives Cohort II semantic-scope analysis + principal direction "we like our packages to be 'completely implemented' for their scope, which means the scope has to be determined."

---

## §[MOD-036] Cross-Package Inlinable Surface Must Be Genuinely Inlinable

**Lint enforcement (TEXT-ONLY — full narrative, synthetic build-probe attempted + retracted 2026-05-24)**: `/promote-rule [MOD-036]` confirmed this is REAL on the 6.3 gating toolchain — the actual `swift-set-primitives` consumer fails cross-package `@inlinable` against the pre-refactor buffer-linear (`Set.Ordered.Small`: `init()`/`isSpilled` "internal … `@inlinable`") — but a *synthetic* build-probe is an unreliable detector: concrete, generic, and byte-identical-declaration-plus-imports probes all build clean. The trigger is **whole-module** (it surfaces only in a real consumer's full Core module, alongside its base-`Buffer.Linear` and `Buffer.Linear.Inline` uses), not in any isolated snippet. AST detection is likewise out (cross-module access-level resolution, `[MOD-016]`). Enforcement is therefore **incidental consumer CI** — a consumer building against a violating buffer dependency goes red in real whole-module context (optionally made deterministic by a producer-side "canary consumer build"). Re-promotable to a dedicated validator only with a representative real-consumer fixture once the buffer/set cohort migration settles. Outcome record: `Audits/PROMOTE-MOD-036-2026-05-24.md`.

**Provenance**: 2026-05-24 buffer type/ops refined-C arc (`swift-buffer-linear-primitives`); original blocker `REPORT-buffer-split-consumer-migration-blocker.md`; design rationale `swift-buffer-primitives/Research/storage-generic-buffer-core.md`; specialization evidence `swift-institute/Experiments/{storage-protocol-specialization,property-inout-specialization}`.

---

## §[MOD-037] Cross-Variant `package` Symbols Must Not Flip to `internal`

**Provenance**: 2026-05-24 buffer refined-C arc, §5 finding — a base `_remove*` flipped to `internal` broke the `Small` satellite; the per-target build masked it.

---

## §[MOD-038] Every Source Import Is a Declared Target Dependency

**The failure shape (W3-F2, full text)**: `Async.Barrier.swift:21` declares `internal import Async_Waiter_Primitives`; the `Async Barrier Primitives` target declared deps `["Async Primitives Core", "Async Mutex Primitives"]` only. With no Barrier→Waiter edge, Barrier compiled iff some other target's job built Waiter first: debug, tsan-debug, and plain-release plans won that race; the first tsan-release plan lost it — `error: no such module 'Async_Waiter_Primitives'` surfacing in a DOWNSTREAM consumer's gate (pool), with an incremental rerun replaying the memoized failure. Fix: the one-line dependency declaration (swift-async-primitives `1f2bf7a`, "Declare Barrier's Async Waiter dependency").

**Provenance**: `.handoffs/REPORT-arc-shared-soundness-W3.md` §2 (FINDING W3-F2, build-plan race evidence, ASK-W3-B); fix exemplar swift-async-primitives `1f2bf7a`; disposition `.handoffs/REPORT-round-m-W4-terminal.md` §1 (D3: mint a [MOD-*] rule via skill-lifecycle, then promote). Round M skills batch (seat dispatch, 2026-06-13).

---

## Changelog-Provenance

The dated amendment changelog evicted from the skill frontmatter, verbatim and newest-first. Normative clauses introduced by these entries live in the owning rules' bodies in the skill; these records are provenance only.

- **2026-06-22**: Seam-taxonomy note RECONCILED — DP3 (2026-06-18) superseded. The allocation-strategy marker is now Memory.Allocator.Protocol (gerund Memory.Allocating) on the AGENT NOUN via the [API-IMPL-009] hoist; Memory.Allocation.Protocol retired (the Memory.Allocation namespace stays for .Error/.Granularity). DP3's premise (a protocol can't nest in generic Memory.Allocator<Resource> on 6.3.2) was disproven by the hoist (verified swiftc 6.3.2 + 6.5-dev); live code moved (memory-allocation 1153e09), converging with the calculus's original Memory.Allocator.Protocol spelling. Memory-row + [MOD-PLACE-EXPRESS] marker spellings updated; Memory.Allocatable.Protocol distinct-seam clarification retained. Clarifying per [SKILL-LIFE-003]. Provenance: [API-IMPL-023] (BREAKING 2026-06-22) + operation-domain-naming-and-organization.md v1.1.2 §6.1.
- **2026-06-18**: [MOD-PLACE]/[MOD-PLACE-DECOMPOSE]/[MOD-PLACE-FLOOR]/[MOD-PLACE-AUDIT]/[MOD-PLACE-EXPRESS] ADDED — the Layer-Placement Calculus promoted from Research (decomposition-layer-placement-calculus.md §7.1 + the package-map) into canon. The four-owner basis (Memory/Storage/Buffer/ADT), the CLOSED canonical-placement inventory (allocation → Memory.Allocator.*; Storage.Arena/Pool DISSOLVE → Storage.Contiguous<Memory.Allocator.X>; Buffer.Arena kept-as-occupancy; upward Storage.*:Buffer.Protocol conformance FORBIDDEN), the lowest-correct-layer axiom + 5-step procedure, bundle-decomposition, the honest floor, the two-failure-mode audit lens, express-by-compose-not-protocol. Single source of truth for placement — ends ad-hoc per-session re-derivation (the foundations-perfect / no-relitigate mandate). Lint: Scripts/layer-placement-classify.py. Additive per [SKILL-LIFE-003]; principal-directed 2026-06-18. [MOD-009]/[MOD-012]/[MOD-035] cross-referenced (§7.2). Provenance: decomposition-layer-placement-calculus.md §7 + decomposition-layer-placement-package-map.md + ecosystem-data-structures [DS-001/004/025].
- **2026-06-13**: [MOD-038] ADDED — every source import is a declared target dependency (no riding transitive build accidents): import set ⊆ dependencies: (toolchain/SDK modules excepted); undeclared edges make compilation a build-plan scheduling race that surfaces in DOWNSTREAM consumers' gates (W3-F2: Async.Barrier's undeclared Async_Waiter_Primitives import — tsan-release plan lost the race; fix async 1f2bf7a). Lower bound complementing [MOD-006]'s upper bound. Enforcement queued per the Round M D3 disposition (mint-first, /promote-rule later; AST-vs-workflow-validator is the triage question). Additive per [SKILL-LIFE-003]. Provenance: .handoffs/REPORT-arc-shared-soundness-W3.md §2 + REPORT-round-m-W4-terminal.md §1 (Round M skills batch, seat dispatch).
- **2026-06-09**: [MOD-RENT] BREAKING — removed the **consumer** criterion (criterion 2: "has at least one real consumer today"); the rent test is now two-criteria (capability + theoretical content). Removed the consumer-signal trigger row, the procedure consumer-check step, the worked-example Consumer row, and the [RES-018]-case-(c) interaction note. Package existence is judged on capability + theoretical merit, never consumer/adoption count (per [ARCH-LAYER-008]). Principal direction (first-principles MO, not YAGNI); per [SKILL-LIFE-003] (discussion completed this session).
- **2026-05-28** ([MOD-005] aggregation-discriminator — Breaking per [SKILL-LIFE-003]): added the non-aggregating base-plural carve-out to the type/ops dual-role umbrella — when a package's variants are mutually exclusive per consumer (no downstream module imports >1 variant) the base plural MUST NOT re-export sibling variant ops; each variant is an independent entry point (the per-variant `{Variant} Primitives → {Variant} Primitive` re-export is unchanged). Default stays dual-role aggregation for cross-variant-consumer disciplines (set-ordered, buffer-linear). Added a discriminator test + hash-table exemplar; distinguished from the [MOD-015] consumer-import axis; relaxed the "umbrella MUST depend on ALL sub-targets" line for the non-aggregating case. Breaking per [SKILL-LIFE-003] (weakens an absolute MUST) though no currently-aggregating package is invalidated; explicit-discussion requirement satisfied by principal direction. Provenance: principal direction 2026-05-28; motivating case = swift-hash-table-primitives modernization (538c2ac) + consumer migrations set-ordered (a76b14e) / dictionary-ordered (81cda1e).
- **2026-05-28** ([MOD-014] weakening — Breaking per [SKILL-LIFE-003]): retracted the "separate repository for a single integration target — unnecessary proliferation" prohibition. Cross-package optional integration now DEFAULTS to extraction (a sibling package E depending on both A and B); trait-gating demoted to structural fallback. Discriminator: a trait leaves the `.package(...)` edge to B in A's manifest (package-graph edge A→B survives with the trait off); only extraction removes it. Added [MOD-RENT]/[MOD-020] carve-outs for integration packages. Principal direction; motivating case = swift-bit-primitives' sole swift-algebra-field-primitives use (the `Algebra.Field<Bit>.z2` witness).
- **2026-05-24** ([MOD-007] depth-metric clarification): clarified that [MOD-007] depth = longest-path EDGES from the root ≤ 3 (= ≤ 4 nodes), NOT node-count; corrected the parser exemplar label 3→2 (Core→Take→Many is 2 edges); memory ("2") and buffer ("3") exemplars already correct under edge-reading and left as-is. Updated the lint-enforcement line to the validator's edge-depth>3 (node-count>4) check. Clarifying per [SKILL-LIFE-003]; principal-confirmed edge-reading 2026-05-24. Companion: swift-institute/.github validate-package-structure.py off-by-one fix (commit 904867c).
- **2026-05-24** (type/ops-split umbrella codification): [MOD-012] + [MOD-005] + [MOD-036] amended — codified the type/ops-split discipline-package shape: SINGULAR `{Domain} {Variant} Primitive` = lean ~Copyable type module; PLURAL `{Domain} {Variant} Primitives` = type re-export + isolated conformances; base plural `{Domain} Primitives` doubles as the [MOD-005] umbrella (re-exports base type + all variant ops + base-conformance externals) — no separate pure umbrella, no Base token. Acyclicity (non-negotiable): variant ops depend on the base/variant TYPE singular, never on base ops. Dual-role exception to [MOD-005]'s zero-implementation umbrella rule + the validate-package-structure "umbrella sole source is exports.swift" check. Distinguished from [MOD-017]'s zero-dep substrate root (the split's singular is a type module that MAY carry external deps). Additive per [SKILL-LIFE-003]; verified vs swift-buffer-linear-primitives `fdce249`. [MOD-036] additions layered on top of d141a7b's TEXT-ONLY enforcement annotation (not clobbered).
- **2026-05-24**: [MOD-001] REMOVED (was DEPRECATED 2026-05-21), [MOD-017] REVISED, [MOD-012] + [MOD-031] amended — the root namespace + foundational-types target is merged into the SINGULAR `{Domain} Primitive` (folds the former `{Domain} Primitives Core` + `{Domain} Namespace` into one published library). Zero-external-dependency invariant preserved on `{Domain} Primitive`; sub-namespace (`{Domain} {X} Primitives`), umbrella (`{Domain} Primitives`), and test-support naming unchanged. BREAKING per [SKILL-LIFE-003], principal-authorized; migration note retained (legacy Core/Namespace packages migrate when next touched). Verified vs swift-buffer-primitives (`Buffer Primitive`) + swift-sequence-primitives (`Sequence Primitive`), both `dependencies: []`. [MOD-036]/[MOD-037] left untouched (already singular per the buffer type/ops split). KNOWN-STALE follow-ups: validate-package-structure.yml Core/Namespace-presence checks + name regex; residual legacy `Core` examples in [MOD-002]/[MOD-003]/[MOD-004]/[MOD-005]/[MOD-006]/[MOD-007]/[MOD-009]/[MOD-010]/[MOD-013]/[MOD-015a] surfaced to principal, not edited (out of stated scope; several interact with the untouchable [MOD-036]/[MOD-004] framing). [MOD-012]'s legacy Core-based table + layer-adaptation table intentionally RETAINED as migration reference.
- **2026-05-22**: [MOD-032]-[MOD-035] added — codifies the Cohort I + Cohort II semantic-scope lessons. [MOD-032] forbids package-level cycles even when SwiftPM tolerates them (target-acyclic / package-cyclic configurations). [MOD-033] mandates owner-internal fan-in pre-flight before any extraction. [MOD-034] forbids extraction of foundational-role sub-targets (Carrier, Tagged, Property, Equation, Hash, Comparison) — they define owner identity. [MOD-035] requires a written scope statement per L1 primitives package. Mechanical enforcement: Scripts/integration-extraction-inventory.py v3.5 (Step 4 + Step 5). Additive per [SKILL-LIFE-003]; codifies 6 reverts + 1 pre-flight catch from 2026-05-22.
- **2026-05-14**: [MOD-RENT] Rationale block — added "Interaction with [RES-018] case (c) pull-down" clarifying that the consumer criterion is satisfied by the originating L2/L3 package after an [RES-018] case (c) layer-agnostic pull-down. Clarifying per [SKILL-LIFE-003]; companion to [RES-018] BREAKING revision same day. (Note: this interaction note was subsequently REMOVED by the 2026-06-09 BREAKING revision above.)
- **2026-05-13**: [MOD-030] added — combinator/leaf-type micro modules are deliberate at any layer; module count is not a quality signal. Generalizes [MOD-026]'s L3 fine-grained-per-type-modularization default to L1 combinator-style packages. Provenance: 2026-05-13 transformation-domain audit (`swift-institute/Experiments/variadic-oneof-same-element-blocker/`). Additive per [SKILL-LIFE-003].
- **2026-05-10**: Phase 3b TRIM-PROSE — compressed Rationale prose on [MOD-001], [MOD-005], [MOD-007], [MOD-011], [MOD-012] now that `validate-package-structure.yml` mechanically enforces. Statements unchanged per [SKILL-LIFE-001]. Clarifying per [SKILL-LIFE-003].
- **2026-05-10**: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — added Lint enforcement lines for [MOD-001], [MOD-005], [MOD-007], [MOD-011], [MOD-012], [MOD-017] mapping each rule to the new `validate-package-structure.yml` reusable workflow + companion `.github/scripts/validate-package-structure.py` validator. Clarifying per [SKILL-LIFE-003].
