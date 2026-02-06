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
| [protocol-abstraction-for-phantom-typed-wrappers.md](protocol-abstraction-for-phantom-typed-wrappers.md) | Protocol abstraction for phantom-typed wrappers (Tier 3) — supersedes tagged-extension-duplication.md | DECISION |
| [testing-conventions.md](testing-conventions.md) | Testing conventions for Swift Institute ecosystem (Tier 3) | DECISION |
| [minimal-type-declaration-pattern.md](minimal-type-declaration-pattern.md) | Minimal type body with extensions pattern | DECISION |
| [primitives-conversion-anti-patterns.md](primitives-conversion-anti-patterns.md) | Multi-layer .rawValue anti-patterns and Test Support affordances | DECISION |
| [open-source-toolchain-compiler-crashes.md](open-source-toolchain-compiler-crashes.md) | swift.org +assertions toolchain crashes with ~Escapable/~Copyable (Tier 3) — [#87029](https://github.com/swiftlang/swift/issues/87029), [#87030](https://github.com/swiftlang/swift/issues/87030) | DECISION |
| ~~finite-collection-join-point-integration.md~~ | Moved to `swift-primitives/swift-storage-primitives/Research/` | — |

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
