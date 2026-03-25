# Variant Naming Audit

<!--
---
version: 2.0.0
last_updated: 2026-03-24
status: DRAFT
research_tier: 3
applies_to: [swift-primitives, swift-foundations]
normative: false
supersedes_sections:
  - ecosystem-data-structures-inventory.md § Variant System (lines 25-39)
  - ecosystem-data-structures-inventory.md § Collection Types (lines 171-290) — naming only
  - storage-buffer-abstraction-analysis.md § 1.3-1.4 — variant inventory
  - comparative-buffer-primitives.md — variant naming aspects
---
-->

## Context

The swift-primitives ecosystem uses a systematic variant pattern for data structure types. Each collection family can offer multiple variants distinguished by allocation strategy: growable heap, bounded heap, compile-time inline, and inline-with-spill. Variant-related information was previously scattered across 14+ research documents with no single authoritative source.

This document unifies all variant naming research into one place: academic foundations, the variant system definition, layer naming conventions, composition architecture, the complete type inventory, copyability/sendability rules, compiler limitations, and the naming corrections needed.

**Trigger**: Ecosystem data structures skill review (2026-03-24) revealed naming inconsistencies. The implementation naming audit Q-024 (2026-03-20) first identified the Queue.Fixed/Bounded doc comment mismatch. The primitives taxonomy audit (2026-02-11) explicitly deferred variant names, leaving a gap.

---

## 1. Academic Foundations

Definitions sourced from `primitives-taxonomy-naming-layering-audit.md` §Prior Art Survey, extended here to cover variant terminology which that audit excluded.

### 1.1 Bounded (Dijkstra 1965)

Dijkstra's "Cooperating Sequential Processes" formalized the **bounded-buffer problem**. A bounded buffer has a fixed capacity but variable count. Operations may fail or block at the bound.

> A bounded buffer is a buffer of finite capacity N, into which items can be deposited and from which items can be extracted.

**Defining characteristic**: capacity-limited, mutable contents. Count varies from 0 to capacity.

### 1.2 Fixed (Knuth, TAOCP)

A **fixed-size array** has all elements initialized at creation. Size is immutable after construction. This is the semantics of C's `int a[10]` — always exactly 10 elements.

**Defining characteristic**: immutable count = capacity, always full. No add/remove operations.

### 1.3 Static (Dijkstra 1960)

**Static allocation** means memory whose size and lifetime are determined at compile time. Contrasts with dynamic allocation (runtime-determined).

**Defining characteristic**: compile-time known capacity, typically stack-allocated.

### 1.4 Small Buffer Optimization

Industry term (not academic) for inline storage with fallback to heap on overflow. C++ calls this "small buffer optimization" (SBO). Rust calls it `SmallVec`.

**Defining characteristic**: inline storage with heap spill on overflow.

### 1.5 Semantic Distinction: Bounded vs Fixed

| Property | Bounded | Fixed |
|----------|---------|-------|
| Count after creation | Variable (0..capacity) | Immutable (= capacity) |
| Can add elements | Yes (up to capacity) | No |
| Can remove elements | Yes | No |
| All slots initialized | No (only 0..count) | Yes (always full) |
| Academic precedent | Dijkstra bounded buffer | Knuth fixed-size array |
| Meaningful for | Any collection | Only collections where "always full" makes sense |

A "fixed Queue" is semantically nonsensical — you cannot dequeue from a collection whose count cannot change. "Fixed" only makes sense for Array (and potentially frozen Set/Dictionary, though none exist in the ecosystem).

---

## 2. The Variant System

### 2.1 Corrected Variant Table

This table supersedes the variant tables in `ecosystem-data-structures-inventory.md` (line 29-35) and the `ecosystem-data-structures` skill [DS-002].

| Variant | Storage | Capacity | Growth | Semantics |
|---------|---------|----------|--------|-----------|
| *(base)* | Heap | Dynamic | Policy-driven (doubling default) | General purpose; unknown or variable size |
| `.Bounded` | Heap | Fixed at init (runtime) | None; throws on overflow | Capacity-limited, mutable count (Dijkstra bounded buffer) |
| `.Static<N>` | Inline (`@_rawLayout`) | Compile-time (value generic) | None; throws on overflow | Compile-time capacity; zero heap allocation |
| `.Small<N>` | Inline → Heap | Compile-time inline, dynamic after spill | Spills to heap on overflow | Usually small, occasionally large (SmallVec pattern) |
| `.Fixed` | Heap | Fixed at init (runtime or compile-time) | None; immutable after creation | Immutable count = capacity; all elements initialized. **Array only.** |

**Key change from prior documentation**: `.Static<N>` and `.Inline<N>` are NOT interchangeable synonyms. They follow a layer convention (§3). `.Fixed` applies only to Array; all other "Fixed" types should be `.Bounded` (§5).

### 2.2 Corrected Copyability Rules

This supersedes `ecosystem-data-structures-inventory.md` line 37 which incorrectly states "Inline/Bounded/Small variants are always `~Copyable`."

| Variant | Copyability | Reason |
|---------|-------------|--------|
| Base | `~Copyable`; becomes `Copyable` when `Element: Copyable` | Heap-backed, ARC, copy-on-write |
| `.Bounded` | `~Copyable`; becomes `Copyable` when `Element: Copyable` | Heap-backed, ARC, copy-on-write |
| `.Fixed` | `~Copyable`; becomes `Copyable` when `Element: Copyable` | Heap-backed, ARC, copy-on-write |
| `.Static<N>` | **Unconditionally `~Copyable`** | `@_rawLayout` prevents conditional Copyable (compiler limitation, not design choice) |
| `.Small<N>` | **Unconditionally `~Copyable`** | Contains `@_rawLayout` inline storage; deinit required |

### 2.3 Sendability Rules

| Variant | Sendability |
|---------|-------------|
| `~Copyable` instances | `@unchecked Sendable` (exclusive ownership = thread safety) |
| `Copyable` instances | Conditional `Sendable` when `Element: Sendable` |

### 2.4 Known Compiler Limitations (Swift 6.2)

- **Element leak on drop** (swiftlang/swift#86652): `deinit` is commented out for `.Static<N>` and `.Small<N>` variants due to a release-mode LLVM verifier crash with `@_rawLayout`. **Elements are NOT automatically deinitialized when the container is dropped.** Consumer must drain all elements before the container goes out of scope.
- **@_rawLayout blocks conditional Copyable**: Even when `Element: Copyable`, inline variants cannot gain Copyable conformance. This is a compiler limitation, not a design choice.
- **LLVM verifier crash in Small variants**: Struct containing both `@_rawLayout` (Storage.Inline) and reference-type field (Storage.Heap) triggers IRGen crash in release builds. Workaround uses enum `_Representation`.

---

## 3. Layer Naming Convention: Static vs Inline

### 3.1 The Convention

| Layer | Variant Name | Describes | Examples |
|-------|-------------|-----------|----------|
| Memory (Tier 13) | **Inline** | Where storage lives (in the struct) | `Memory.Inline<E, N>` |
| Storage (Tier 14) | **Inline** | Where storage lives | `Storage.Inline<N>`, `Storage.Pool.Inline<N>`, `Storage.Arena.Inline<N>` |
| Buffer (Tier 15) | **Inline** | Where storage lives | `Buffer.Linear.Inline<N>`, `Buffer.Ring.Inline<N>` |
| Collection (Tier 16+) | **Static** | When capacity is known (compile time) | `Array.Static<N>`, `Stack.Static<N>`, `Queue.Static<N>` |

### 3.2 Rationale

Infrastructure layers (Memory, Storage, Buffer) care about **placement** — "inline" means "not heap-indirected." Collection layers care about the **user-facing property** — "static" means "compile-time known," following the CS definition (Dijkstra 1960).

### 3.3 The Array.Inline Collision

`Array.Inline<N>` is a typealias to `Swift.InlineArray` (all N elements always initialized, count = N). This is semantically different from `Array.Static<N>` (variable count 0..N, inline storage). Renaming `Static` to `Inline` at the collection level would collide with this stdlib type.

### 3.4 Current Violations

Two collection types use "Inline" instead of "Static":

| Type | Current | Correct |
|------|---------|---------|
| `List.Linked.Inline<N>` | Inline | `List.Linked.Static<N>` |
| `Tree.N.Inline<N>` | Inline | `Tree.N.Static<N>` |

---

## 4. Composition Architecture

How collection variants compose buffer variants compose storage types. Sourced from `storage-buffer-abstraction-analysis.md` §1.3-1.4 and `comparative-buffer-primitives.md`.

### 4.1 Buffer Variant Inventory

Six buffer disciplines, each with up to four storage-strategy variants (Base, Bounded, Inline, Small). There is **no "Fixed" variant at the buffer level** — "Fixed" is a collection-level semantic constraint.

| Discipline | Base | Bounded | Inline | Small | Backs |
|------------|:----:|:-------:|:------:|:-----:|-------|
| Linear | ✓ | ✓ | ✓ | ✓ | Array, Stack, Heap, Dictionary.Ordered, Set.Ordered |
| Ring | ✓ | ✓ | ✓ | ✓ | Queue, Queue.DoubleEnded |
| Slab | ✓ | ✓ | ✓ | ✓ | Slab, Dictionary |
| Linked\<N\> | ✓ | — | ✓ | ✓ | List.Linked, Queue.Linked |
| Slots\<M\> | ✓ | — | — | — | Hash.Table |
| Arena | ✓ | ✓ | ✓ | ✓ | Tree types |

### 4.2 Buffer Three-Layer Architecture

Every discipline follows the same internal structure (from `storage-buffer-abstraction-analysis.md` §1.4):

```
Layer 1: Header       — Pure cursor/bookkeeping state (Copyable, Sendable)
Layer 2: Static Ops   — Expert-level functions on raw storage
Layer 3: Composed Type — header: Header + storage: Storage<Element>.X
```

### 4.3 Buffer-to-Storage Composition

| Buffer Variant | Composes | Capacity |
|----------------|----------|----------|
| Base | `Storage<E>.Heap` | Dynamic, policy-driven |
| Bounded | `Storage<E>.Heap` | Fixed at init, throws on overflow |
| Inline\<N\> | `Storage<E>.Inline<N>` | Compile-time, throws on overflow |
| Small\<N\> | Inline\<N\> + Base (enum) | Inline then spill to heap |

### 4.4 Collection "Fixed" Composes Buffer "Bounded"

`Array.Fixed` (the only legitimate Fixed type) composes `Buffer.Linear.Bounded` — the same buffer variant as `Stack.Bounded`. The "Fixed" semantic (immutable count, all elements initialized) is enforced by the collection API: Array.Fixed has no `append`, `remove`, or `insert` methods. The buffer layer does not distinguish between "bounded mutable" and "bounded immutable."

### 4.5 Growth Policy

`Buffer.Growth.Policy` is a **struct with closure** (not an enum). Static factories:
- `.doubling` — `max(current + current, 1)`
- `.factor(scale)` — multiply by rational scale, rounded up
- `.exact` — no growth beyond what is needed
- `.pageAligned(alignment)` — round to `Memory.Alignment` boundary

This supersedes `ecosystem-data-structures-inventory.md` line 167 which incorrectly says "enum: `.doubling`, `.linear`, `.custom`."

---

## 5. Complete Collection Variant Inventory

Every collection type with current name, correct name, backing buffer, and mutability status. Verified against struct declarations (not doc comments).

### 5.1 Array (`swift-array-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Array` | Yes | Buffer.Linear | `Array` | ✓ |
| `Array.Fixed` | **No** (immutable, all initialized) | Buffer.Linear.Bounded | `Array.Fixed` | ✓ |
| `Array.Bounded<N>` | **No** (dimensioned, Z\<N\> index) | Buffer.Linear.Bounded | see §5.12 | ⚠ |
| `Array.Static<N>` | Yes (0..capacity) | Buffer.Linear.Inline | `Array.Static<N>` | ✓ |
| `Array.Small<N>` | Yes (spills) | Buffer.Linear.Small | `Array.Small<N>` | ✓ |

### 5.2 Stack (`swift-stack-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Stack` | Yes | Buffer.Linear | `Stack` | ✓ |
| `Stack.Bounded` | Yes (up to capacity) | Buffer.Linear.Bounded | `Stack.Bounded` | ✓ |
| `Stack.Static<N>` | Yes (0..capacity) | Buffer.Linear.Inline | `Stack.Static<N>` | ✓ |
| `Stack.Small<N>` | Yes (spills) | Buffer.Linear.Small | `Stack.Small<N>` | ✓ |

### 5.3 Queue (`swift-queue-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Queue` | Yes | Buffer.Ring | `Queue` | ✓ |
| **`Queue.Fixed`** | Yes (enqueue/dequeue) | Buffer.Ring.Bounded | **`Queue.Bounded`** | ✗ |
| `Queue.Static<N>` | Yes (0..capacity) | Buffer.Ring.Inline | `Queue.Static<N>` | ✓ |
| `Queue.Small<N>` | Yes (spills) | Buffer.Ring.Small | `Queue.Small<N>` | ✓ |
| `Queue.Linked` | Yes | Buffer.Linked | `Queue.Linked` | ✓ |
| **`Queue.Linked.Fixed`** | Yes (up to capacity) | Buffer.Linked | **`Queue.Linked.Bounded`** | ✗ |
| `Queue.Linked.Inline<N>` | Yes (0..capacity) | Buffer.Linked.Inline | `Queue.Linked.Inline<N>` | ✓ |
| `Queue.Linked.Small<N>` | Yes (spills) | Buffer.Linked.Small | `Queue.Linked.Small<N>` | ✓ |
| `Queue.DoubleEnded` | Yes | Buffer.Ring | `Queue.DoubleEnded` | ✓ |
| **`Queue.DoubleEnded.Fixed`** | Yes (up to capacity) | Buffer.Ring.Bounded | **`Queue.DoubleEnded.Bounded`** | ✗ |
| `Queue.DoubleEnded.Static<N>` | Yes (0..capacity) | Buffer.Ring.Inline | `Queue.DoubleEnded.Static<N>` | ✓ |
| `Queue.DoubleEnded.Small<N>` | Yes (spills) | Buffer.Ring.Small | `Queue.DoubleEnded.Small<N>` | ✓ |

**Note**: Q-024 from the implementation naming audit found doc comments referencing `Queue.Bounded` while the type is `Queue.Fixed`, suggesting a rename from Bounded to Fixed occurred without semantic justification.

### 5.4 Heap (`swift-heap-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Heap` | Yes | Buffer.Linear | `Heap` | ✓ |
| **`Heap.Fixed`** | Yes (insert/extract) | Buffer.Linear.Bounded | **`Heap.Bounded`** | ✗ |
| `Heap.Static<N>` | Yes (0..capacity) | Buffer.Linear.Inline | `Heap.Static<N>` | ✓ |
| `Heap.Small<N>` | Yes (spills) | Buffer.Linear.Small | `Heap.Small<N>` | ✓ |
| `Heap.MinMax` | Yes | Buffer.Linear | `Heap.MinMax` | ✓ |
| **`Heap.MinMax.Fixed`** | Yes (insert/extract) | Buffer.Linear.Bounded | **`Heap.MinMax.Bounded`** | ✗ |
| `Heap.MinMax.Static<N>` | Yes (0..capacity) | Buffer.Linear.Inline | `Heap.MinMax.Static<N>` | ✓ |
| `Heap.MinMax.Small<N>` | Yes (spills) | Buffer.Linear.Small | `Heap.MinMax.Small<N>` | ✓ |

**Note**: `comparative-heap-primitives.md` line 154 already describes `Heap.Fixed` as "(bounded capacity)" in prose.

### 5.5 Set (`swift-set-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Set.Ordered` | Yes | Buffer.Linear + Hash.Table | `Set.Ordered` | ✓ |
| **`Set.Ordered.Fixed`** | Yes (insert/remove) | Buffer.Linear.Bounded + Hash.Table | **`Set.Ordered.Bounded`** | ✗ |
| `Set.Ordered.Static<N>` | Yes (0..capacity) | Buffer.Linear.Inline + Hash.Table.Static | `Set.Ordered.Static<N>` | ✓ |
| `Set.Ordered.Small<N>` | Yes (spills) | Inline → Heap | `Set.Ordered.Small<N>` | ✓ |

**Note**: Set.Ordered is backed by Buffer.Linear + Hash.Table, NOT Buffer.Slab. This corrects errors in the `ecosystem-data-structures` skill (pre-2026-03-24) and `ecosystem-data-structures-inventory.md` line 130.

### 5.6 Dictionary (`swift-dictionary-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Dictionary` | Yes | Buffer.Slab + Hash.Table | `Dictionary` | ✓ |
| `Dictionary.Ordered` | Yes | Set.Ordered (keys) + Buffer.Linear (values) | `Dictionary.Ordered` | ✓ |
| `Dictionary.Ordered.Bounded` | Yes (up to capacity) | Buffer.Linear.Bounded | `Dictionary.Ordered.Bounded` | ✓ |
| `Dictionary.Ordered.Static<N>` | Yes (0..capacity) | Inline | `Dictionary.Ordered.Static<N>` | ✓ |
| `Dictionary.Ordered.Small<N>` | Yes (spills) | Inline → Heap | `Dictionary.Ordered.Small<N>` | ✓ |

### 5.7 List (`swift-list-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `List.Linked` | Yes | Buffer.Linked | `List.Linked` | ✓ |
| `List.Linked.Bounded` | Yes (up to capacity) | Buffer.Linked | `List.Linked.Bounded` | ✓ |
| **`List.Linked.Inline<N>`** | Yes (0..capacity) | Buffer.Linked.Inline | **`List.Linked.Static<N>`** | ✗ naming |
| `List.Linked.Small<N>` | Yes (spills) | Buffer.Linked.Small | `List.Linked.Small<N>` | ✓ |

### 5.8 Tree (`swift-tree-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Tree.N` | Yes | Buffer.Arena | `Tree.N` | ✓ |
| `Tree.N.Bounded` | Yes (up to capacity) | Buffer.Arena.Bounded | `Tree.N.Bounded` | ✓ |
| **`Tree.N.Inline<N>`** | Yes (0..capacity) | Buffer.Arena.Inline | **`Tree.N.Static<N>`** | ✗ naming |
| `Tree.N.Small<N>` | Yes (spills) | Buffer.Arena.Small | `Tree.N.Small<N>` | ✓ |
| `Tree.Unbounded` | Yes | Buffer.Arena | `Tree.Unbounded` | ✓ |
| `Tree.Keyed` | Yes | Buffer.Arena | `Tree.Keyed` | ✓ |

### 5.9 Slab (`swift-slab-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Slab` | Yes | Buffer.Slab | `Slab` | ✓ |
| `Slab.Static<wordCount>` | Yes (sparse) | Buffer.Slab.Inline | `Slab.Static<wordCount>` | ✓ |
| `Slab.Indexed<Tag>` | Yes | Buffer.Slab | `Slab.Indexed<Tag>` | ✓ |

### 5.10 Bitset (`swift-bitset-primitives`)

| Current Name | Mutable Count | Backing | Correct Name | Status |
|-------------|:-------------:|---------|-------------|:------:|
| `Bitset` | Yes | ContiguousArray\<UInt\> | `Bitset` | ✓ |
| **`Bitset.Fixed`** | Yes (insert/remove bits) | ContiguousArray\<UInt\> | **`Bitset.Bounded`** | ✗ |
| `Bitset.Static<wordCount>` | Yes (0..wordCount×64) | InlineArray\<UInt\> | `Bitset.Static<wordCount>` | ✓ |
| `Bitset.Small<N>` | Yes (spills) | Inline → Heap | `Bitset.Small<N>` | ✓ |

### 5.11 Non-Container Types

| Type | Category | Notes |
|------|----------|-------|
| `Graph` | Algorithm namespace | Not a container; operates on external representations |
| `String` | Text primitive | `~Copyable`, `@unchecked Sendable`; no variants |
| `Hash.Table` | Infrastructure | Backing for Dictionary/Set; not standalone |

### 5.12 Note on Array.Bounded\<N\>

`Array.Bounded<N>` is immutable-count (all N elements always present), with compile-time dimension `N` and type-safe `Algebra.Z<N>` indexing. It is named after its **index** property (bounded/dimension-safe indices), not the Dijkstra "bounded buffer" sense. This creates an ambiguity:

1. `Stack.Bounded`, `List.Linked.Bounded`, etc. — capacity-limited, mutable count (Dijkstra)
2. `Array.Bounded<N>` — dimensioned, immutable count, typed Z\<N\> index

This ambiguity is noted but out of scope for this audit. See `pool-bounded-storage-refactor.md` for further discussion.

---

## 6. Bounded Indices on Static-Capacity Types

From `Reflections/2026-02-12-stack-buffer-remediation-bounded-canonical.md`:

> On static-capacity types, bounded indices are not an "also" — they are the only API.

When a type's capacity is known at compile time (`.Static<N>` variants), its subscript MUST accept `Index<Element>.Bounded<capacity>`, not unbounded `Index<Element>`. The unbounded variant is technical debt, not a fallback. This is enforced by [IMPL-052].

This principle interacts with the variant naming system: `.Static<N>` types carry compile-time capacity knowledge that should propagate to their index types. The implementation naming audits (ARR-014, ARR-015) found Array.Static and Array.Small still using unbounded indices.

---

## 7. Cross-Document Contradictions

Five contradictions were identified across existing research. Each is cataloged with source and resolution.

### C1: "Fixed" described as "bounded capacity" in prose

**Source**: `comparative-heap-primitives.md` line 154:
> Uses `Heap.Fixed` **(bounded capacity)** with `.ascending` order

**Resolution**: Rename `Heap.Fixed` → `Heap.Bounded`. The prose already knows the correct term.

### C2: Inventory variant table vs code reality for "Fixed"

**Source**: `ecosystem-data-structures-inventory.md` line 35 defines `.Fixed` as "Fixed count (immutable)."

**Contradiction**: 7 of 8 types named "Fixed" have mutable count. Only `Array.Fixed` matches.

**Resolution**: After renames, `.Fixed` applies only to Array.Fixed. Update the inventory.

### C3: Copyability rules wrong

**Source**: `ecosystem-data-structures-inventory.md` line 37: "Inline/Bounded/Small variants are always `~Copyable`."

**Contradiction**: Heap-backed Bounded variants ARE conditionally Copyable. Only Inline/Small (containing `@_rawLayout`) are unconditionally `~Copyable`.

**Resolution**: Corrected rules in §2.2 above.

### C4: Static and Inline treated as synonyms

**Source**: `ecosystem-data-structures-inventory.md` line 33 lists `.Static<N>` / `.Inline<N>` as interchangeable.

**Contradiction**: They follow a principled layer convention (§3). Two collection types violate it.

**Resolution**: Document the convention; rename List.Linked.Inline and Tree.N.Inline to Static.

### C5: Buffer level has no "Fixed" variant

**Source**: `storage-buffer-abstraction-analysis.md` §1.4 defines four buffer variants: Base, Bounded, Inline, Small.

**Contradiction**: Collection level adds "Fixed" (five variants), but Fixed composes Buffer.Bounded — same storage as Bounded.

**Resolution**: "Fixed" is a collection-level semantic constraint (no mutation API) on top of Buffer.Bounded storage. Document this explicitly (§4.4).

### C6: Inventory has wrong Set.Ordered backing

**Source**: `ecosystem-data-structures-inventory.md` line 130 and line 259 list `Buffer.Slab` as backing for Set.Ordered.

**Contradiction**: Set.Ordered uses `Buffer.Linear` + `Hash.Table`. Verified at `swift-set-primitives/Sources/Set Primitives Core/Set.swift` line 51.

**Resolution**: Corrected in §5.5. The skill was already corrected 2026-03-24.

### C7: Inventory has wrong Growth.Policy API

**Source**: `ecosystem-data-structures-inventory.md` line 167: "enum: `.doubling`, `.linear`, `.custom`."

**Contradiction**: `Buffer.Growth.Policy` is a struct with closure. Factories: `.doubling`, `.factor(scale)`, `.exact`, `.pageAligned(alignment)`. No `.linear` or `.custom` exist.

**Resolution**: Corrected in §4.5. The skill was already corrected 2026-03-24.

### C8: Inventory lists Queue.Bounded but code has Queue.Fixed

**Source**: `ecosystem-data-structures-inventory.md` line 247: `Queue<E>.Bounded<capacity>`.

**Contradiction**: The actual type in code is `Queue.Fixed` (no compile-time parameter). The inventory predates a rename from Bounded to Fixed that occurred without updating all references (Q-024).

**Resolution**: The code should be renamed back to `Queue.Bounded` per §5.3. The inventory's name was correct; the code diverged.

---

## 8. Proposed Renames

### 8.1 Fixed → Bounded (7 types)

| Package | Current | Proposed |
|---------|---------|----------|
| swift-queue-primitives | `Queue.Fixed` | `Queue.Bounded` |
| swift-queue-primitives | `Queue.DoubleEnded.Fixed` | `Queue.DoubleEnded.Bounded` |
| swift-queue-primitives | `Queue.Linked.Fixed` | `Queue.Linked.Bounded` |
| swift-heap-primitives | `Heap.Fixed` | `Heap.Bounded` |
| swift-heap-primitives | `Heap.MinMax.Fixed` | `Heap.MinMax.Bounded` |
| swift-set-primitives | `Set.Ordered.Fixed` | `Set.Ordered.Bounded` |
| swift-bitset-primitives | `Bitset.Fixed` | `Bitset.Bounded` |

### 8.2 Inline → Static (2 types)

| Package | Current | Proposed |
|---------|---------|----------|
| swift-list-primitives | `List.Linked.Inline<N>` | `List.Linked.Static<N>` |
| swift-tree-primitives | `Tree.N.Inline<N>` | `Tree.N.Static<N>` |

### 8.3 Not Renamed

| Type | Reason |
|------|--------|
| `Array.Fixed` | Genuinely fixed: immutable count, all initialized |
| `Array.Bounded<N>` | Named after index property (Z\<N\>), not buffer semantics; separate discussion |
| All `.Static<N>` variants | Already correct |
| All `.Small<N>` variants | Already correct |
| All base types | Already correct |
| All Buffer.*.Inline variants | Correct for infrastructure layer |

### 8.4 Scope of Each Rename

Each rename requires:
1. Struct declaration
2. All extension references
3. File names (e.g., `Queue.Fixed.swift` → `Queue.Bounded.swift`)
4. Module/target names in Package.swift (e.g., `"Queue Fixed Primitives"` → `"Queue Bounded Primitives"`)
5. Import statements in downstream packages
6. Doc comments and research documents
7. Downstream consumers in swift-foundations

### 8.5 Cross-Package Impact

**swift-standards**: No references to any affected types.

**swift-foundations**: Active references in source code:
- `IO.Blocking.Threads.Worker.swift` — `Queue.DoubleEnded.Fixed`
- `IO.Blocking.Threads.Runtime.State.swift` — `Queue.DoubleEnded.Fixed`
- `swift-io/Research/data-structure-ecosystem-triage.md` — `Queue.Fixed`, `Heap.Fixed`, `Queue.DoubleEnded.Fixed`

### 8.6 Post-Rename Document Updates

| Document | Update needed |
|----------|---------------|
| `ecosystem-data-structures-inventory.md` | Fix copyability rule (C3); drop Inline synonym (C4); note Fixed is Array-only (C2); fix Set.Ordered backing (C6); fix Growth.Policy (C7) |
| `ecosystem-data-structures` skill | Update Queue/Heap/Set/Bitset variant names after code rename |
| `comparative-queue-primitives.md` | Queue.Fixed → Queue.Bounded throughout |
| `comparative-heap-primitives.md` | Heap.Fixed → Heap.Bounded throughout |
| `comparative-set-primitives.md` | Set.Ordered.Fixed → Set.Ordered.Bounded throughout |
| `swift-io/Research/data-structure-ecosystem-triage.md` | Queue.Fixed, Heap.Fixed references |
| `IO.Blocking.Threads.Worker.swift` | Queue.DoubleEnded.Fixed → Bounded |
| `IO.Blocking.Threads.Runtime.State.swift` | Queue.DoubleEnded.Fixed → Bounded |

---

## 9. Outcome

**Status**: DRAFT — pending execution

### Findings

1. **Seven types misuse "Fixed"** for bounded-buffer semantics. The academic term for "capacity-limited, variable count" is "bounded" (Dijkstra 1965). "Fixed" should be reserved for immutable-count types (only Array.Fixed qualifies).

2. **Two types use "Inline" at the collection level** where the established convention is "Static." Infrastructure layers (Memory, Storage, Buffer) correctly use "Inline"; collections should use "Static."

3. **The variant naming system was never formally audited.** The taxonomy audit (`primitives-taxonomy-naming-layering-audit.md`) covers type names and layer names but explicitly excludes variant names. This document fills that gap.

4. **Eight cross-document contradictions exist** (C1–C8). The most significant: the inventory's copyability rule is wrong (C3), Static/Inline are treated as synonyms (C4), Set.Ordered backing is wrong (C6), and Growth.Policy API is wrong (C7). Three of four skill-level errors were already corrected 2026-03-24.

5. **Cross-package impact is contained.** swift-standards has zero references. swift-foundations has references in IO Blocking Threads (2 source files) and research documents.

---

## References

### Academic

1. Dijkstra, E.W. (1965). "Cooperating Sequential Processes." In *Programming Languages*, F. Genuys, ed., Academic Press, 1968.
2. Knuth, D.E. (1968). *The Art of Computer Programming, Volume 1: Fundamental Algorithms*. Addison-Wesley.
3. Dijkstra, E.W. (1960). "Recursive Programming." *Numerische Mathematik*, 2(1), 312-318.
4. Williams, J.W.J. (1964). "Algorithm 232: Heapsort." *CACM*, 7(6), 347-348.

### Ecosystem Documents

5. `swift-primitives/Research/primitives-taxonomy-naming-layering-audit.md` — CS definitions for type/layer names; defers variant names to this document.
6. `swift-institute/Research/ecosystem-data-structures-inventory.md` — variant table and type inventory (C2, C3, C4, C6, C7, C8).
7. `swift-institute/Research/storage-buffer-abstraction-analysis.md` — buffer variant inventory and composition theory (C5).
8. `swift-institute/Research/comparative-heap-primitives.md` — Heap variant catalog (C1).
9. `swift-institute/Research/comparative-queue-primitives.md` — Queue variant catalog.
10. `swift-institute/Research/comparative-set-primitives.md` — Set variant catalog.
11. `swift-institute/Research/comparative-buffer-primitives.md` — buffer variant catalog across 6 disciplines.
12. `swift-institute/Research/audits/implementation-naming-2026-03-20/swift-queue-primitives.md` — Q-024: Queue.Bounded→Fixed rename evidence.
13. `swift-institute/Research/Reflections/2026-02-12-stack-buffer-remediation-bounded-canonical.md` — bounded indices as sole API on static-capacity types.
14. `swift-primitives/Research/pool-bounded-storage-refactor.md` — Array.Bounded\<N\> dual-meaning discussion.
