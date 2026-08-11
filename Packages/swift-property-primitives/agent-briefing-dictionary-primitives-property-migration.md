# Agent Briefing: Dictionary Primitives and Property Migration
<!--
---
version: 1.0.0
last_updated: 2026-01-21
status: DECISION
---
-->

**Date**: 2026-01-21
**From**: Property Primitives Investigation
**To**: Agent working on swift-dictionary-primitives

---

## Executive Summary

After extensive investigation, **Dictionary Primitives should NOT migrate to `Property<Tag, Base>`**. Keep the existing concrete proxy structs (`Values`, `Merge`, `Keep`). This is a deliberate architectural decision, not a limitation to work around.

---

## Why Property Pattern Works for Deque/Heap but Not Dictionary

| Aspect | Deque/Heap | Dictionary |
|--------|-----------|------------|
| Generic parameters | 1 (`Element`) | 2 (`Key`, `Value`) |
| Nesting depth | Single level | Double (`merge.keep`) |
| Protocol conformance | None required | `Sequence` on `Values` |
| Property.Typed fit | Perfect | Inadequate |

---

## The Three Blockers

### 1. Multi-Parameter Generics

`Property.Typed<Element>` smuggles ONE type parameter into extension scope. Dictionary needs TWO (`Key`, `Value`).

**Investigated solutions:**
- Parameter packs (`Typed<each T>`) - Can't project elements in where clauses
- Nested Typed (`Typed<A>.Typed<B>`) - Works but requires multiple struct definitions
- Protocol Witness (types in Tag) - Works but requires marker protocols on all tags
- Tuple parameters (`Typed<(A,B)>`) - Can't destructure in where clauses

**Conclusion**: All solutions add complexity without sufficient benefit. Concrete structs are cleaner.

### 2. Protocol Conformance (Sequence)

`Dictionary.Ordered.Values` must conform to `Sequence` for idiomatic iteration:
```swift
for value in dict.values { ... }
```

Swift's conformance system cannot scope conformances to specific phantom type instantiations for generic type families. You cannot write:
```swift
// INVALID - cannot introduce K, V in conformance
extension<K, V> Property.Typed: Sequence
where Tag == Dictionary<K, V>.Ordered.Values { ... }
```

Only concrete type conformances work (`Dictionary<String, Int>`), which is useless for a primitives library.

### 3. Doubly-Nested Generic Accessor Chain

The merge API requires:
```swift
dict.merge.keep.first(pairs)
```

For this to work generically, `.keep` must be a property (not method) that introduces `Key` and `Value`. Swift properties cannot introduce generic parameters - only methods can.

---

## Recommended Architecture for Dictionary Primitives

```
Dictionary.Ordered
├── Values (concrete struct) - conforms to Sequence
├── Merge (concrete struct)
│   └── Keep (concrete struct)
└── [other accessors using Property if single-param]
```

Keep `Values`, `Merge`, and `Keep` as concrete proxy structs. They correctly handle:
- Two-parameter generic constraints
- Protocol conformances
- Nested accessor chains

---

## Relevant Files

### Case Study Documentation
```
swift-property-primitives/Research/
├── case-study-dictionary-primitives-migration-failure.md
└── agent-briefing-dictionary-primitives-property-migration.md (this file)
```

### Experiments (with full code and findings)
```
/Users/coen/Developer/swift-primitives/swift-property-primitives/Experiments/
├── _index.json (experiment index)
├── property-typed-parameter-pack-test/    ← Multi-param solutions investigation
├── property-phantom-conformance-test/     ← Protocol conformance limitations
├── property-doubly-nested-accessor-test/  ← Nested accessor patterns
└── property-protocol-test/                ← Protocol extension limitations
```

### Property Primitives Source
```
/Users/coen/Developer/swift-primitives/swift-property-primitives/Sources/Property Primitives/
├── Property.swift
├── Property.Typed.swift
└── Property.View.swift
```

---

## Key Experiment Results

### property-typed-parameter-pack-test
- Parameter pack instantiation works but element projection in where clauses does not
- `Typed<A>.Typed<B>` nesting works but requires multiple struct definitions
- Protocol Witness pattern works but requires marker protocols
- **Decision**: None elegant enough; keep concrete structs

### property-phantom-conformance-test
- Constrained conformances work for CONCRETE types only
- Cannot add `Sequence` for all `Dictionary<K, V>` - only specific instantiations
- Multiple conformances with different constraints are forbidden
- **Decision**: `Values` must remain concrete struct for `Sequence`

### property-doubly-nested-accessor-test
- Doubly nested accessors work for concrete types
- Generic doubly nested requires methods (not properties) to introduce type params
- **Decision**: `Merge`/`Keep` must remain concrete structs

---

## What This Means for Your Work

1. **Do NOT attempt to migrate** `Values`, `Merge`, or `Keep` to Property pattern
2. **Document the design decision** in code comments (see case study for suggested text)
3. **Property pattern IS suitable** for any future single-parameter accessors
4. **The experiments are preserved** for future reference if Swift adds pack element projection

---

## Contact

If you need clarification on any findings, the experiments contain full executable code demonstrating each limitation. Run them with `swift run` in the respective directories.
