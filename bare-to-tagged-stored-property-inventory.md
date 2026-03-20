# Bare-to-Tagged Stored Property Inventory

**Date**: 2026-03-20
**Scope**: All stored properties using bare `Cardinal` or `Ordinal` types in `Sources/` across `swift-primitives`, `swift-standards`, and `swift-foundations`.

**Exclusions applied**:
- `swift-cardinal-primitives` and `swift-ordinal-primitives` (define the bare types)
- Protocol requirements (handled separately)
- Protocol witnesses (computed properties satisfying `Finite.Enumerable.ordinal`, `Cardinal.Protocol.cardinal`, etc.)
- Computed properties (e.g., `Affine.Discrete.Vector.magnitude`, `Swift.Span.Iterator.remaining`)
- Local variables in functions (e.g., `hunks()`, `diff()`, `counts()`)
- Test, experiment, and research files
- `swift-foundations` had zero hits

**Total stored properties**: 24 (14 Cardinal, 10 Ordinal)

---

## swift-sequence-primitives (16 properties)

### `Sequence.Difference.Hunk`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 1 | `Sequence.Difference.Hunk.swift:26` | `oldStart` | `Ordinal` | `public let` | Line position in original sequence | `Index<Sequence.Difference.Old>` or `Line.Position` |
| 2 | `Sequence.Difference.Hunk.swift:28` | `oldCount` | `Cardinal` | `public let` | Line count in original sequence | `Index<Sequence.Difference.Old>.Count` or `Line.Count` |
| 3 | `Sequence.Difference.Hunk.swift:30` | `newStart` | `Ordinal` | `public let` | Line position in modified sequence | `Index<Sequence.Difference.New>` or `Line.Position` |
| 4 | `Sequence.Difference.Hunk.swift:32` | `newCount` | `Cardinal` | `public let` | Line count in modified sequence | `Index<Sequence.Difference.New>.Count` or `Line.Count` |

**Assessment**: All four properties are semantically scoped to diff line positions/counts. The `old`/`new` prefix already encodes domain intent. These are strong candidates for tagged types using a `Sequence.Difference.Old`/`Sequence.Difference.New` phantom tag, or a domain-specific `Line` tag.

### `Sequence.Difference.Steps.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 5 | `Steps.Iterator.swift:15` | `_index` | `Ordinal` | `@usableFromInline var` | Position into step storage | `Index<Sequence.Difference.Step>` |
| 6 | `Steps.Iterator.swift:18` | `_count` | `Cardinal` | `@usableFromInline let` | Count of steps | `Index<Sequence.Difference.Step>.Count` |

### `Sequence.Difference.Changes.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 7 | `Changes.Iterator.swift:15` | `_index` | `Ordinal` | `@usableFromInline var` | Position into change storage | `Index<Sequence.Difference.Change<Value>>` |
| 8 | `Changes.Iterator.swift:18` | `_count` | `Cardinal` | `@usableFromInline let` | Count of changes | `Index<Sequence.Difference.Change<Value>>.Count` |

### `Sequence.Drop.First`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 9 | `Sequence.Drop.First.swift:32` | `_count` | `Cardinal` | `@usableFromInline let` | Number of elements to drop | `Index<Base.Element>.Count` |

### `Sequence.Drop.First.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 10 | `Sequence.Drop.First.Iterator.swift:41` | `_remaining` | `Cardinal` | `@usableFromInline var` | Remaining elements to skip | `Index<Base.Element>.Count` |

### `Sequence.Prefix.First`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 11 | `Sequence.Prefix.First.swift:33` | `_count` | `Cardinal` | `@usableFromInline let` | Number of elements to take | `Index<Base.Element>.Count` |

### `Sequence.Prefix.First.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 12 | `Sequence.Prefix.First.Iterator.swift:30` | `_remaining` | `Cardinal` | `@usableFromInline var` | Remaining elements to yield | `Index<Base.Element>.Count` |

### `Swift.Span<Element>.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 13 | `Swift.Span.Iterator.swift:32` | `_position` | `Ordinal` | `@usableFromInline var` | Position into span elements | `Index<Element>` |
| 14 | `Swift.Span.Iterator.swift:35` | `_count` | `Cardinal` | `@usableFromInline let` | Total element count in span | `Index<Element>.Count` |

### `Swift.Span<Element>.Iterator.Batch`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 15 | `Swift.Span.Iterator.Batch.swift:33` | `_position` | `Ordinal` | `@usableFromInline var` | Position into span elements | `Index<Element>` |
| 16 | `Swift.Span.Iterator.Batch.swift:36` | `_count` | `Cardinal` | `@usableFromInline let` | Total element count in span | `Index<Element>.Count` |

---

## swift-cyclic-primitives (5 properties)

### `Cyclic.Group.Static<modulus>.Element`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 17 | `Cyclic.Group.Static.swift:80` | `position` | `Ordinal` | `public let` | Position within cyclic group [0, modulus) | `Ordinal.Finite<modulus>` (already has this type nearby) |

**Assessment**: Semantically scoped to the cyclic group's residue class. The compile-time `modulus` parameter provides natural domain scoping. Could use `Ordinal.Finite<modulus>` which already exists in the codebase.

### `Cyclic.Group.Static<modulus>.Iterator`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 18 | `Cyclic.Group.Static.Iterator.swift:28` | `current` | `Ordinal` | `@usableFromInline var` | Current position in iteration | `Ordinal.Finite<modulus>` or `Index<Element>` |
| 19 | `Cyclic.Group.Static.Iterator.swift:31` | `bound` | `Cardinal` | `@usableFromInline let` | Upper bound (= modulus) | `Cardinal.Finite<modulus>` or `Index<Element>.Count` |

### `Cyclic.Group.Modulus`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 20 | `Cyclic.Group.Modulus.swift:26` | `value` | `Cardinal` | `public let` | Modulus value for dynamic cyclic group | Genuinely domain-free (modulus is a bare size) |

**Assessment**: `Modulus.value` wraps a validated positive cardinal. The type itself *is* the domain wrapper -- tagging further may be over-engineering. However, if a `Cyclic.Group.Size` phantom tag existed, it could be `Index<Cyclic.Group>.Count`.

### `Cyclic.Group.Element`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 21 | `Cyclic.Group.Element.swift:43` | `residue` | `Ordinal` | `public let` | Residue class position [0, modulus) | `Index<Cyclic.Group>` |

**Assessment**: Semantically scoped to the cyclic group. The element *is* the domain -- `residue` represents position within the group.

---

## swift-algebra-modular-primitives (1 property)

### `Algebra.Modular.Modulus`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 22 | `Algebra.Modular.Modulus.swift:18` | `cardinal` | `Cardinal` | `public let` | Modulus value for modular arithmetic | Genuinely domain-free (modulus is a bare size) |

**Assessment**: Same pattern as `Cyclic.Group.Modulus.value`. The containing type provides the semantic wrapper. Tagging the inner value adds little safety since the type itself is never confused with other cardinals.

---

## swift-parser-machine-primitives (1 property)

### `Parser.Machine.Memoization.Key`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 23 | `Parser.Machine.Memoization.Key.swift:18` | `node` | `Ordinal` | `package let` | Index into parser program nodes | `Index<Parser.Machine.Node>` |

**Assessment**: Strongly domain-scoped. This is a node index in a parser program -- a textbook case for `Index<Parser.Machine.Node>`.

---

## swift-color-standard (1 property)

### `Theme`

| # | Line | Property | Type | Visibility | Domain | Tagged Replacement |
|---|------|----------|------|------------|--------|--------------------|
| 24 | `Theme.swift:30` | `ordinal` | `Ordinal` | `public let` | Case index of a finite enumeration | `Ordinal.Finite<2>` or `Index<Theme>` |

**Assessment**: Stored property satisfying `Finite.Enumerable.ordinal`. The domain is the `Theme` type itself. Could use `Ordinal.Finite<2>` (the type has exactly 2 cases) or `Index<Theme>`, but this is a pattern shared across all `Finite.Enumerable` conformers -- any change here implies a protocol-wide decision.

---

## swift-foundations

No bare `Cardinal` or `Ordinal` stored properties found in any `Sources/` directory.

---

## Summary by Category

### Strongly domain-scoped (clear tagged replacement)

| # | Type | Property | Suggested Tag |
|---|------|----------|---------------|
| 1-4 | `Sequence.Difference.Hunk` | `oldStart`, `oldCount`, `newStart`, `newCount` | `Sequence.Difference.{Old,New}` |
| 5-8 | `Sequence.Difference.{Steps,Changes}.Iterator` | `_index`, `_count` | `Index<Step>`, `Index<Change<Value>>` |
| 9-12 | `Sequence.{Drop,Prefix}.First{,.Iterator}` | `_count`, `_remaining` | `Index<Base.Element>.Count` |
| 13-16 | `Swift.Span.Iterator{,.Batch}` | `_position`, `_count` | `Index<Element>`, `Index<Element>.Count` |
| 23 | `Parser.Machine.Memoization.Key` | `node` | `Index<Parser.Machine.Node>` |

### Cyclic group scoped (domain is the group itself)

| # | Type | Property | Notes |
|---|------|----------|-------|
| 17 | `Cyclic.Group.Static<N>.Element` | `position` | Could be `Ordinal.Finite<N>` |
| 18-19 | `Cyclic.Group.Static<N>.Iterator` | `current`, `bound` | Iterator internals |
| 21 | `Cyclic.Group.Element` | `residue` | Dynamic group element |

### Modulus wrappers (containing type is the domain wrapper)

| # | Type | Property | Notes |
|---|------|----------|-------|
| 20 | `Cyclic.Group.Modulus` | `value` | Type itself provides semantic safety |
| 22 | `Algebra.Modular.Modulus` | `cardinal` | Type itself provides semantic safety |

### Finite enumeration pattern (protocol-wide decision)

| # | Type | Property | Notes |
|---|------|----------|-------|
| 24 | `Theme` | `ordinal` | Stored conformance to `Finite.Enumerable`; any change affects all conformers |
