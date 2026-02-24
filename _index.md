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
