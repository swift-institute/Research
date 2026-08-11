# Validation receipt: [API-NAME-010b] `phantom suppression` — ADT tower run
Date: 2026-07-07
Rule: phantom suppression (institute tier, Naming pack; previously defined, never bundled)
Task: REVIEW-linter-rules-pass-2026-07-07 §B — run against 3 ADT-tower packages; bundle if clean/low-FP, delete if noisy.

## Firing profile (prebuilt-parse harness, target toolchain 6.3.2)

| Package | Findings | Files |
|---------|----------|-------|
| swift-tree-keyed-primitives | 1 | Sources/Tree Keyed Primitives/TreeStorage.Keyed.swift |
| swift-slab-primitives | 5 | Slab Primitive/Slab ~Copyable.swift (3), Slab Inline Primitive/Slab.Inline+Operations.swift (2) |
| swift-buffer-slab-primitives | 2 | Buffer Slab Primitive/Buffer.Slab+Operations.swift (1), Buffer Slab Bounded Primitive/Buffer.Slab.Bounded+Operations.swift (1) |
| **Total** | **8** | 5 files |

Harness: walked each package's `Sources/`, parsed each `.swift` with SwiftParser, ran `Lint.Rule.\`phantom suppression\`.findings(_, .warning)`, summed. Temporary; deleted post-run.

## Classification: 8/8 TRUE POSITIVES

The rule fired only on `<E: ~Copyable>` (copyable-only) generic parameters used purely as `Index<E>` / `Index<E>.Count` / `Index<E>.Bounded<n>` discriminators and never as a stored/by-value position — its Shape-2 target. It correctly did NOT fire on the sibling `insert`/`update`/`remove` methods that take or return an `E` value (the `usedAsStoredValue` guard held; otherwise it would have fired ~13×/file in `Slab ~Copyable.swift` alone).

Decisive convention evidence: the primitives fleet binds a phantom `Tag`/`Index` discriminator `~Copyable & ~Escapable` at **99 sites**, including direct `Index<Tag>` discriminators done correctly:
- `swift-cyclic-primitives/.../Cyclic.Group.Element.swift:76` — `public init<Tag: ~Copyable & ~Escapable>(__unchecked index: Index<Tag>)`
- `swift-cyclic-primitives/.../Cyclic.Group.Modulus.swift:59` — `public init<Tag: ~Copyable & ~Escapable>(_ count: Index<Tag>.Count)`

The slab/buffer-slab/tree-keyed tower is the deviant minority: `<E: ~Copyable>`-only on phantom Index discriminators (only these 3 files fleet-wide carry the copyable-only phantom shape). Per [API-NAME-010b] a marker requirement on a phantom is vacuous over-constraint (Reynolds parametricity) — the tower under-suppresses; the 99-site majority is the correct target binding.

## Disposition: BUNDLE (clean / low-FP, true positives)

Added `.enable(.\`phantom suppression\`)` to `Bundle.institute` (Naming pack). Severity `.warning` ([PROMOTE-009]) — advisory, non-blocking. The 8 findings are the migration backlog (branch-1 "real violations" per lint-rule-promotion Phase 6): the tower's phantom Index discriminators should be re-bound `~Copyable & ~Escapable` to match the fleet convention. Not fixed in this pass (§B scope is bundle-or-delete, not tower source edits).

### Migration backlog (8 sites)
- swift-tree-keyed-primitives/Sources/Tree Keyed Primitives/TreeStorage.Keyed.swift
- swift-slab-primitives/Sources/Slab Primitive/Slab ~Copyable.swift (×3)
- swift-slab-primitives/Sources/Slab Inline Primitive/Slab.Inline+Operations.swift (×2)
- swift-buffer-slab-primitives/Sources/Buffer Slab Primitive/Buffer.Slab+Operations.swift
- swift-buffer-slab-primitives/Sources/Buffer Slab Bounded Primitive/Buffer.Slab.Bounded+Operations.swift
