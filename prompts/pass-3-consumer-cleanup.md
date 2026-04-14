# Pass 3: Consumer Cleanup — Handoff Prompt

Read `Research/audits/implementation-naming-2026-03-20/01-remediation-plan.md` for full context. This prompt executes **Pass 3: Consumer Cleanup**.

## Goal

Replace `.rawValue.rawValue` chains, `Int(bitPattern:)` at non-boundary call sites, and `__unchecked` at non-boundary call sites with the typed infrastructure that already exists. This pass makes NO public API changes — it only changes internal implementation to use typed operations.

## Direction

Tier 0 → Tier 20 (fix closest-to-foundation consumers first, then their consumers).

## Available Infrastructure (from Pass 2 + pre-existing)

### Pre-existing overloads

| Overload | Location |
|----------|----------|
| `Int(bitPattern: Cardinal)` | cardinal-primitives `Int+Cardinal.swift:47` |
| `Int(bitPattern: Ordinal)` | ordinal-primitives `Int+Ordinal.swift:65` |
| `Int(bitPattern: Affine.Discrete.Vector)` | affine-primitives `Int+Affine.Discrete.Vector.swift:21` |
| `Array.subscript<O: Ordinal.Protocol>` | ordinal-primitives `Array+Ordinal.swift:15` |
| `ContiguousArray.subscript<O: Ordinal.Protocol>` | ordinal-primitives `ContiguousArray+Ordinal.swift:23` |
| `InlineArray.subscript<O: Ordinal.Protocol>` | ordinal-primitives `InlineArray+Ordinal.swift:24` |
| `UnsafePointer.subscript<O: Ordinal.Protocol>` | ordinal-primitives |
| `UnsafeMutablePointer.subscript<O: Ordinal.Protocol>` | ordinal-primitives |

### Added in Pass 2

| Overload | Location |
|----------|----------|
| `UInt32.init<C: Cardinal.Protocol>` | cardinal-primitives `UInt32+Cardinal.swift:12` |
| `Array.subscript<O: Ordinal.Protocol>` (generalized) | ordinal-primitives `Array+Ordinal.swift:15` |
| `Memory.Address.bitPattern: UInt` | memory-primitives `Memory.Address.swift:141` |
| `UnsafeRawPointer.init(Tagged<Tag, Memory.Address>)` | memory-primitives `Memory.Address.swift:157` |
| `UnsafeMutableRawPointer.init(Tagged<Tag, Memory.Address>)` | memory-primitives `Memory.Address.swift:171` |

### Important: Principled absences (do NOT add these)

Per [INFRA-200] and the Pass 2 descoping:
- `UnsafePointer + Index<Element>` — principled absence. Add offsets (vectors) to pointers, not scalars (counts). Use the existing typed pointer subscripts instead.
- `UnsafePointer + Index<Element>.Count` — same reason.

## Packages to Fix (tier order)

### Tier 5: swift-affine-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-affine-primitives.md`
**Chains**: 15 `.rawValue.rawValue` — all classified as MEDIUM (boundary code)
**What to fix**: These are inside operator definitions (Tagged+Affine.swift, pointer StdLib Integration files). Use the pre-existing `Int(bitPattern: Affine.Discrete.Vector)` overload where currently doing `offset.rawValue.rawValue`. For pointer files, use `Int(bitPattern:)` on the unwrapped vector instead of double-chain.
**Build**: `cd swift-affine-primitives && swift build && swift test`

### Tier 9: swift-algebra-modular-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-small-packages-batch.md` (section 2)
**Chains**: 3 `.rawValue.rawValue` in multiplication
**What to fix**: `lhs.rawValue.rawValue.multipliedReportingOverflow(by: rhs.rawValue.rawValue)` — use typed arithmetic or at minimum `Int(bitPattern:)` on each operand.
**Build**: `cd swift-algebra-modular-primitives && swift build && swift test`

### Tier 13: swift-memory-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-memory-primitives.md`
**Chains**: 2 `.rawValue.rawValue` in Memory.Address
**What to fix**: Use the new `.bitPattern` property (added in Pass 2) instead of `.rawValue.rawValue`.
**Build**: `cd swift-memory-primitives && swift build && swift test`

### Tier 14: swift-binary-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-binary-primitives.md`
**Findings**: BIN-001 (30 `Int(bitPattern:)` in Cursor), BIN-002 (4 `.rawValue.rawValue`), BIN-003 (14 `Int(bitPattern:)` in Reader), BIN-004 (2 `.rawValue.rawValue`), BIN-006/007 compound methods (defer to Pass 5)
**What to fix**:
- Replace `offset.rawValue.rawValue` with `Int(bitPattern: offset)` (the `Int(bitPattern: Affine.Discrete.Vector)` overload works here since Offset is `Tagged<Tag, Affine.Discrete.Vector>` — verify the overload resolves through Tagged)
- Replace `Int(bitPattern: _readerIndex)` patterns — these extract from `Index<Element>` which is `Tagged<Element, Ordinal>`. `Int(bitPattern: Ordinal)` exists, so `Int(bitPattern: index.ordinal)` should work, or check if `Int(bitPattern:)` resolves directly on Index
- Focus on the Cursor and Reader files — they contain ~44 and ~14 sites respectively
**Build**: `cd swift-binary-primitives && swift build && swift test`

### Tier 15: swift-buffer-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-buffer-primitives.md`
**Findings**: BUF-001/002 (`.rawValue.rawValue` in Arena), BUF-003 (`.rawValue` in Unbounded), BUF-004 (`__unchecked` in Unbounded), BUF-006 (`Int(bitPattern:)` in iterators)
**What to fix**:
- Arena: `UInt32(header.highWater.rawValue.rawValue)` → `UInt32(header.highWater)` using the new `UInt32.init<C: Cardinal.Protocol>` from Pass 2
- Unbounded: `minimumCapacity.rawValue` → use typed init on `Buffer.Aligned`; `__unchecked` Count from Cardinal → use typed Count init if one exists
- Iterator pointer arithmetic: Use existing typed pointer subscripts rather than `Int(bitPattern:)` + pointer addition
**Build**: `cd swift-buffer-primitives && swift build && swift test`

### Tier 16: swift-hash-table-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-hash-table-primitives.md`
**Findings**: HT-002 (`Int(bitPattern:)` at InlineArray access), HT-003 (double `__unchecked` chain), HT-008/009 (`UInt(bitPattern:)` + `.rawValue` for bucket computation)
**What to fix**:
- InlineArray access: Use existing `InlineArray.subscript<O: Ordinal.Protocol>` instead of `Int(bitPattern:)` extraction
- Bucket computation: The hash-to-bucket mapping involves `UInt(bitPattern: hash.rawValue)` — this is boundary code (hash domain → bucket domain). Verify whether the `.rawValue` access can be eliminated via a typed accessor
**Build**: `cd swift-hash-table-primitives && swift build && swift test`

### Tier 17: swift-queue-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-queue-primitives.md`
**Findings**: Q-001/002/003 (4 `.rawValue.rawValue` chains), Q-004 (`Int(bitPattern:)` in RandomAccessCollection), Q-005 (`__unchecked` construction)
**What to fix**:
- `Int(bitPattern: end.rawValue.rawValue) - Int(bitPattern: start.rawValue.rawValue)` → use `Int(bitPattern: end) - Int(bitPattern: start)` if `Int(bitPattern:)` resolves on Index, or `Int(bitPattern: end.ordinal) - Int(bitPattern: start.ordinal)`
- `Index(__unchecked: (), Ordinal(UInt(bitPattern: raw)))` → check if a typed Index constructor from Int exists
**Build**: `cd swift-queue-primitives && swift build && swift test`

### Tier 17: swift-kernel-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-kernel-primitives.md`
**Findings**: KER-021 (triple `.rawValue.rawValue.rawValue` on Memory.Address), KER-022 (triple chain on buffer alignment)
**What to fix**:
- Use the new `Memory.Address.bitPattern` property (Pass 2) instead of `.rawValue.rawValue.rawValue`
- Use the new `UnsafeRawPointer.init(Tagged<Tag, Memory.Address>)` where pointer construction is needed
**Build**: `cd swift-kernel-primitives && swift build && swift test`

### Tier 17: swift-set-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-set-primitives.md`
**Findings**: SET-012/013/014/015 (`hashTable.insert(__unchecked:)` in non-boundary code)
**What to fix**: These pass `__unchecked` to the hash table's insert method. Check if a non-unchecked insert variant exists. If the `__unchecked` is on the INDEX being passed (not the insert call itself), replace with a typed index construction.
**Build**: `cd swift-set-primitives && swift build && swift test`

### Tier 18: swift-dictionary-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-dictionary-primitives.md`
**Findings**: DICT-001 through DICT-021 (systematic `Int(bitPattern:)` + `Ordinal(UInt(index))` in every variant)
**What to fix**:
- `subscript(index index: Int)` methods contain `Int(bitPattern: count)` and `Ordinal(UInt(index))` — use typed subscripts/constructors
- `underestimatedCount` returning `Int(bitPattern: count)` — this IS a boundary (Swift.Sequence requires Int). Mark as acceptable, no change.
- `endIndex` returning `Int(bitPattern: count)` — same, Swift.Collection requires Int.
**Build**: `cd swift-dictionary-primitives && swift build && swift test`

### Tier 19: swift-tree-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-tree-primitives.md`
**Findings**: TREE-016 through TREE-023 (`Int(bitPattern:)` in _validate and remove methods)
**What to fix**: Use the generalized `Array.subscript<O: Ordinal.Protocol>` (from Pass 2) instead of `Int(bitPattern: position.index)`.
**Build**: `cd swift-tree-primitives && swift build && swift test`

### Tier 20: swift-binary-parser-primitives

**Audit file**: `Research/audits/implementation-naming-2026-03-20/swift-binary-parser-primitives.md`
**Findings**: BPAR-001 (`.rawValue.rawValue` double extraction), BPAR-002 (`Int(bitPattern:)` at call site), BPAR-006 (repeated `Cardinal(UInt(n))` chains)
**What to fix**:
- `.rawValue.rawValue` → use `Int(bitPattern:)` on the typed value
- `Cardinal(UInt(n))` chains → check if a typed Cardinal.init exists for the source type
**Build**: `cd swift-binary-parser-primitives && swift build && swift test`

## Procedure

For each package (in tier order):

1. Read the specific audit file for that package
2. Open the flagged files and find each violation site
3. Replace with the typed infrastructure (see "Available Infrastructure" above)
4. If unsure whether an overload resolves, check: does the type conform to `Ordinal.Protocol` or `Cardinal.Protocol`? If yes, the generic overloads from Pass 2 apply.
5. `swift build` — if it fails, the overload doesn't resolve as expected. Check the conformance chain.
6. `swift test` — verify no behavioral changes
7. Commit: `[audit] Pass 3: consumer cleanup — swift-X-primitives`

## What NOT to change in this pass

- **Compound method/property names** — that's Pass 5
- **Type renames** — that's Pass 4
- **File organization** — that's Pass 6
- **`Int(bitPattern:)` in `underestimatedCount` / `endIndex`** — these ARE boundaries (Swift.Sequence/Collection require Int)
- **`.rawValue` inside operator definitions** — these ARE boundaries per [PATTERN-017]
- **`__unchecked` after modular reduction** — boundary-correct per cyclic audit

## Estimated effort

~8 hours across 12 packages.
