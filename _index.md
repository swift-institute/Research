# Research Index

This directory contains research documents analyzing design decisions, exploring architectural trade-offs, and documenting reasoning for the Swift Institute ecosystem.

## Research Documents

| Document | Topic | Status |
|----------|-------|--------|
| [discrete-scaling-morphisms.md](discrete-scaling-morphisms.md) | Cross-domain scaling factors and type-safe conversion | RECOMMENDATION |
| [academic-research-methodology.md](academic-research-methodology.md) | Tiered research methodology framework (RES-020-026) | DECISION |
| [skill-based-documentation-architecture.md](skill-based-documentation-architecture.md) | Skill-based documentation architecture | — |
| [skill-loading-reliability.md](skill-loading-reliability.md) | Reliable skill loading via per-repo CLAUDE.md | DECISION |
| [skill-creation-process.md](skill-creation-process.md) | Process for adding new skills to the ecosystem | RECOMMENDATION |
| [swift-package-export-for-llm.md](swift-package-export-for-llm.md) | Optimal format for exporting Swift packages to ChatGPT | RECOMMENDATION |
| [collaborative-llm-discussion.md](collaborative-llm-discussion.md) | Claude-ChatGPT collaborative discussion workflow | RECOMMENDATION |
| ~~range-sequence-collection-semantic-analysis.md~~ | Moved to `swift-primitives/swift-storage-primitives/Research/` | — |
| ~~[tagged-extension-duplication.md](tagged-extension-duplication.md)~~ | Tagged extension duplication analysis | SUPERSEDED |
| [protocol-abstraction-for-phantom-typed-wrappers.md](protocol-abstraction-for-phantom-typed-wrappers.md) | Protocol abstraction for phantom-typed wrappers (Tier 3) — supersedes tagged-extension-duplication.md. Phase 2 complete via SuppressedAssociatedTypes. | IMPLEMENTED |
| [testing-conventions.md](testing-conventions.md) | Testing conventions for Swift Institute ecosystem (Tier 3) | DECISION |
| [minimal-type-declaration-pattern.md](minimal-type-declaration-pattern.md) | Minimal type body with extensions pattern | DECISION |
| [primitives-conversion-anti-patterns.md](primitives-conversion-anti-patterns.md) | Multi-layer .rawValue anti-patterns and Test Support affordances | DECISION |
| [open-source-toolchain-compiler-crashes.md](open-source-toolchain-compiler-crashes.md) | swift.org +assertions toolchain crashes with ~Escapable/~Copyable (Tier 3) — [#87029](https://github.com/swiftlang/swift/issues/87029), [#87030](https://github.com/swiftlang/swift/issues/87030) | DECISION |
| ~~finite-collection-join-point-integration.md~~ | Moved to `swift-primitives/swift-storage-primitives/Research/` | — |
| [implementation-patterns-skill.md](implementation-patterns-skill.md) | New implementation skill: expression patterns, typed arithmetic, boundary overloads (Tier 2) — supersedes anti-patterns | DECISION |
| [protocol-witness-effects-capability-abstraction.md](protocol-witness-effects-capability-abstraction.md) | Protocol vs witness vs effects for capability abstraction (Tier 3) — `associatedtype Output` collision between `Parser.Protocol` and `Rendering.Protocol` | IN_PROGRESS |
| [intent-over-mechanism-expression-first.md](intent-over-mechanism-expression-first.md) | Intent over mechanism as foundational axiom; expression-first code style (Tier 3) | DECISION |
| [session-reflection-meta-process.md](session-reflection-meta-process.md) | Two-phase session reflection and knowledge improvement pipeline (Tier 3) — 103 sources, SLR, formal semantics, v1.1 latest advances addendum | RECOMMENDATION |
| [typed-infrastructure-catalog.md](typed-infrastructure-catalog.md) | Complete typed infrastructure inventory, tiers 0–15 (Tier 3) — systematic catalog for existing-infrastructure skill rebuild | RECOMMENDATION |
| [storage-buffer-abstraction-analysis.md](storage-buffer-abstraction-analysis.md) | Storage and buffer variant abstraction analysis (Tier 3) — SLR (40 sources), container theory, substructural typing, comparative analysis of 5 candidate abstractions | RECOMMENDATION |
| [bit-vector-zeros-infrastructure.md](bit-vector-zeros-infrastructure.md) | Zero-bit scanning infrastructure for Bit.Vector / Bit.Vector.Static (Tier 2) — mirrors .ones with .zeros, enables Storage.Pool.Inline.allocate() to replace raw loop | RECOMMENDATION |
| [nested-protocols-in-generic-types.md](nested-protocols-in-generic-types.md) | Nesting protocols in generic types (Tier 3) — compiler source analysis, SE-0404 gap, no feature flag exists; `Buffer.Arena.Protocol` blocked by `isGenericContext()` | DECISION |
| [nested-protocols-literature-study.md](nested-protocols-literature-study.md) | Cross-language literature study (Tier 3) — 52 sources across Scala/Rust/OCaml/Haskell/C++/type theory; validates "without capture" as ideal design, not just minimum; three-tier recommendation | RECOMMENDATION |
| [tagged-structural-sendable.md](tagged-structural-sendable.md) | Can Tagged<Element, Cardinal> prove structural Sendable when Element: Sendable? (Tier 1) — could remove @unchecked from phantom-typed containers | IN_PROGRESS |
| [affine-operator-unification-completeness.md](affine-operator-unification-completeness.md) | Should remaining Tagged+Affine operators be unified via Domain? (Tier 1) — completeness check after Phase 2 | IN_PROGRESS |
| [domain-first-repository-organization.md](domain-first-repository-organization.md) | Domain-first vs language-first repository organization (Tier 3) — 9 multi-language projects surveyed, 5 organizational models evaluated, formal analysis, `reality-` prefix, converged via Claude–ChatGPT collaborative review. Recommends Model D (Hybrid). | RECOMMENDATION |
| [foundations-dependency-utilization-audit.md](foundations-dependency-utilization-audit.md) | Dependency utilization audit of swift-io and swift-kernel (Tier 1) — cross-referenced against [IMPL-*] and [INFRA-*] skills. Kernel: clean. IO: 2 actionable improvements (Tagged Flag forwarding, reserveCapacity overload). | RECOMMENDATION |
| [swift-io-deep-audit.md](swift-io-deep-audit.md) | Deep quality audit of swift-io and dependencies (Tier 2) — 85 findings across 5 modules. v3.0: all C/H/M triaged. 5 fixes (C-2, H-6, M-8, M-10, M-16), 12 false positive, 10 keep, 6 out of scope, 4 platform, 13 open, 1 design needed, 1 known limitation. LOW deferred. | DECISION |
| [zero-copy-event-pipeline.md](zero-copy-event-pipeline.md) | Zero-copy event pipeline design using Memory.Pool (Tier 2) — eliminates per-poll Array allocation in IO.Event.Poll.Loop via pooled buffer slots. Phased: Phase 1 (pool + memcpy), Phase 2 (direct-to-pool polling). | RECOMMENDATION |
| [parser-combinator-algebraic-foundations.md](parser-combinator-algebraic-foundations.md) | Parser combinator algebraic foundations (Tier 3) — SLR (19 sources, Chomsky–Krishnaswami lineage), formal semantics, two-level algebra analysis (constructor-level vs value-level). Recommends Option D (doc + law tests) over explicit algebra dependency; identifies semiring-parameterized parsing as future work. | RECOMMENDATION |
| [witness-noncopyable-nonescapable-support.md](witness-noncopyable-nonescapable-support.md) | Should swift-witnesses support ~Copyable/~Escapable witness values? (Tier 3, v2.0) — SLR (31 sources: Rust/Haskell/OCaml DI, substructural type theory, capability-passing). ~Copyable values feasible (Ownership.Shared, SuppressedAssociatedTypes, TaskLocal not a blocker) but not yet justified — no concrete use case for ~Copyable witness values. Additive closure-based API (Option E) ready when needed. Monitor ~Escapable scoped access. | RECOMMENDATION |
| [string-path-type-unification.md](string-path-type-unification.md) | String and path type unification across ecosystem (Tier 3, v2.0) — SLR (16 sources), formal semantics, prior art (Rust/C++/Go/Zig/Python/Swift). 5 types across 3 layers. Experiment `phantom-tagged-string-unification` (9 variants, ALL CONFIRMED) **refuted** C2 blocker — Option D is feasible today. Two viable paths: Option E (refine, conservative) or Option D (phantom-tag, progressive). Decision deferred to design judgment. | IN_PROGRESS |
| [comparative-apple-swift-system-metrics.md](comparative-apple-swift-system-metrics.md) | Comparative analysis: apple/swift-system-metrics vs Swift Institute ecosystem (Tier 1) — gap analysis, design pattern comparison, 4 priority recommendations: POSIX rusage/rlimit wrappers, Darwin proc_pidinfo, Linux procfs utilities, Swift 6 feature flag audit | RECOMMENDATION |
| [owned-typed-memory-region-abstraction.md](owned-typed-memory-region-abstraction.md) | Owned typed memory region abstraction (Tier 3, v2.0) — SLR (17 sources: Capability Calculus, Cyclone, Rust/C++, Resource Polymorphism), formal semantics. Gap: no self-owning typed contiguous region. Decision: `Memory.Contiguous<Element: BitwiseCopyable>` fills the gap in its natural namespace. String.Storage wraps `Memory.Contiguous<Char>` + null-termination. BitwiseCopyable is the formal boundary with Storage (per-element lifecycle). | DECISION |

## Moved to swift-memory-primitives/Research/

The following memory/pointer research has been consolidated into `swift-primitives/swift-memory-primitives/Research/`:

- `ordinal-cardinal-foundations.md` — Mathematical foundations for ordinal/cardinal separation
- `affine-scaling-operations.md` — Tier 3 research on scaling operations in affine spaces
- `pointer-architecture-comparison.md` — Swift stdlib pointer vs memory/pointer primitives
- `lifetime-dependent-borrowed-cursors.md` — Lifetime-dependent borrowed cursor patterns

## Workflow

Research workflow is defined in the **research-process** skill (`Skills/research-process/SKILL.md`).

## See Also

- [Experiments/](../Experiments/) — Code verification experiments
- [Documentation.docc/](../Documentation.docc/) — Explanatory documentation
