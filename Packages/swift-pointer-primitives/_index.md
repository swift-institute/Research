# Research Index

Pointer primitives research has been consolidated into `swift-memory-primitives/Research/`.

## Moved Documents

The following documents have been moved to `swift-primitives/swift-memory-primitives/Research/`:

| Document | Topic |
|----------|-------|
| pointer-type-hierarchy.md | Typed-only pointer hierarchy design |
| pointer-mutable-pointee-semantics.md | `Pointer.Mutable.pointee` mutation semantics |
| pointer-primitives-design.md | Best-in-class pointer wrapper architecture |
| Pointer-Stdlib-Interop-Design.md | Stdlib interoperability design |
| Lifetime-Memory-Safety-Plan.md | ~Escapable types and lifetime system |
| mutable-cross-module-ambiguity.md | Cross-module typealias ambiguity |
| unique-package-placement.md | Package organization decisions |

## Rationale

Memory and pointer primitives are closely coupled. Consolidating research into a single location:
- Provides a unified reference for memory model decisions
- Reduces context-switching when researching related topics
- Ensures consistency across memory/pointer/buffer/storage design
