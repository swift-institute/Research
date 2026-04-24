# ~Escapable Support for Memory, Storage, and Buffer Primitives

<!--
---
version: 2.1.0
last_updated: 2026-02-28
status: DECISION
changelog:
  - "2.1.0 (2026-02-28): Ecosystem-wide completeness scan across all 126 packages. No missed opportunities. Scope expanded from 3 packages to full ecosystem verification."
  - "2.0.0 (2026-02-28): Edge case validation complete. Closure gap boundary refined. Status promoted to DECISION."
  - "1.0.0 (2026-02-28): Initial type taxonomy and fitness analysis."
research_tier: 2
applies_to: [swift-memory-primitives, swift-storage-primitives, swift-buffer-primitives]
normative: false
---
-->

## Abstract

This document investigates whether and how `~Escapable` should be adopted across the memory-primitives, storage-primitives, and buffer-primitives packages. Through type classification, soundness analysis, evaluation against known language limitations, and a completeness scan across all 126 primitives packages, we establish that the existing architecture already captures `~Escapable` at the correct abstraction boundary — the Span/MutableSpan interop layer and the Property.View yielding surface — and that applying `~Escapable` to owning types or integer-address-model views is either unsound, semantically incorrect, or blocked by language limitations. The ecosystem-wide scan confirms no missed opportunities across the full package set.

---

## Part I: Context and Scope

### 1.1 Research Trigger

Per [RES-012], this is a **Discovery** research document. The trigger is a proactive investigation into whether `~Escapable` should be expanded beyond its current surgical use (Span interop, Property.View) to cover more types in the Memory → Storage → Buffer stack.

### 1.2 Scope

Per [RES-002a], this research is **primitives-wide** — it spans three packages in the Memory → Storage → Buffer composition chain:

| Package | Types | Tiers |
|---------|------:|-------|
| swift-memory-primitives | 21 types + 6 protocols | 5–8 |
| swift-storage-primitives | 24 types + extensions | 12–14 |
| swift-buffer-primitives | 60+ types | 15–19 |

### 1.3 Prior Research

This document builds on extensive prior work:

| Document | Key Finding | Relevance |
|----------|-------------|-----------|
| `yielding-vs-returning-lifetime-models.md` | Yielding is primary (599 sites), returning (`~Escapable`) is surgical (28 `_overrideLifetime` sites) | Establishes the dual-model architecture |
| `escapable-deinit-lifetime.md` (storage-primitives) | `~Escapable` values cannot be created in deinit; workaround: `@_unsafeNonescapableResult get` | Blocks `~Escapable` in cleanup paths |
| `lifetime-dependent-borrowed-cursors.md` (memory-primitives) | Closure integration gap: `~Escapable` values cannot be passed to closure parameters in Swift 6.2 | Blocks closure-based APIs |
| `Lifetime-Memory-Safety-Plan.md` (memory-primitives) | `_overrideLifetime` is available externally; `@_lifetime(immortal)` + `_overrideLifetime(_, borrowing: ())` is the working pattern for Span extensions | Established the Span interop pattern |
| `view-vs-span-borrowed-access-types.md` | View (null-terminated) and Span (bounded) are orthogonal borrowed-access types | Clarifies the view/span distinction |
| `noncopyable-view-types-for-peek-reversed.md` (buffer-primitives) | Property.View.Read (`~Copyable, ~Escapable`) is the correct pattern for borrowed element access via accessors | Validates Property.View as the ~Escapable accessor surface |

### 1.4 Methodology

Per [RES-004] and [RES-013]:

| Step | Action | Output |
|------|--------|--------|
| 1 | Classify all types by ownership role | Type taxonomy (Part II) |
| 2 | Evaluate each category for `~Escapable` fitness | Fitness matrix (Part III) |
| 3 | Analyze soundness constraints | Soundness assessment (Part IV) |
| 4 | Identify benefits and costs | Trade-off analysis (Part V) |
| 5 | Make recommendation | Outcome (Part VI) |

---

## Part II: Type Taxonomy

Every type across the three packages falls into one of five categories based on its relationship to memory:

### 2.1 Owners — types that own an allocation

These types allocate on construction and deallocate on destruction. They have `deinit` or delegate deallocation to an ARC-managed class.

| Package | Type | Backing | ~Copyable | ~Escapable? |
|---------|------|---------|:---------:|:-----------:|
| memory | `Memory.Contiguous<E>` | `UnsafePointer<E>` + count | Yes | — |
| memory | `Memory.Arena` | `UnsafeMutableRawPointer` | Yes | — |
| memory | `Memory.Pool` | `UnsafeMutableRawPointer` | Yes | — |
| memory | `Memory.Inline<E, capacity>` | `@_rawLayout` stack | Yes | — |
| storage | `Storage.Heap` (class) | `ManagedBuffer` | No (class) | — |
| storage | `Storage.Pool` (class) | `Memory.Pool` wrapper | No (class) | — |
| storage | `Storage.Arena` (class) | `Memory.Arena` wrapper | No (class) | — |
| storage | `Storage.Slab` (class) | `Storage.Heap` + Bitmap | No (class) | — |
| storage | `Storage.Split<Lane>` (class) | `ManagedBuffer<_, UInt8>` | No (class) | — |
| storage | `Storage.Inline<capacity>` | `@_rawLayout` stack | Yes | — |
| storage | `Storage.Pool.Inline<capacity>` | `@_rawLayout` stack | Yes | — |
| storage | `Storage.Arena.Inline<capacity>` | `@_rawLayout` stack | Yes | — |
| buffer | `Buffer.Ring` | `Storage.Heap` | Yes | — |
| buffer | `Buffer.Linear` | `Storage.Heap` | Yes | — |
| buffer | `Buffer.Slab` | `Storage.Slab` | Yes | — |
| buffer | `Buffer.Linked<N>` | `Storage.Pool` | Yes | — |
| buffer | `Buffer.Arena` | `Storage.Arena` | Yes | — |
| buffer | `Buffer.Slots<M>` | `Storage.Split` | Yes | — |
| buffer | `Buffer.Aligned` | `UnsafeMutablePointer<UInt8>` | Yes | — |
| buffer | `Buffer.Unbounded` | `Buffer.Aligned` | Yes | — |
| buffer | All `.Bounded` variants | Respective heap storage | Yes | — |
| buffer | All `.Inline<capacity>` variants | Respective inline storage | Yes | — |
| buffer | All `.Small<capacity>` variants | Inline + heap enum | Yes | — |

**Assessment**: Owners MUST NOT be `~Escapable`. An owner needs to be stored, returned, and transferred — all of which `~Escapable` prevents. An owner's raison d'être is to outlive any individual scope and carry its allocation across boundaries.

For class-backed owners, Swift additionally does not permit classes to be declared `~Escapable`.

### 2.2 Integer-Address Views — non-owning views using the integer-address model

| Package | Type | Stored Fields | Copyable |
|---------|------|---------------|:--------:|
| memory | `Memory.Buffer` | `Memory.Address` + `Memory.Address.Count` | Yes |
| memory | `Memory.Buffer.Mutable` | `Memory.Address` + `Memory.Address.Count` | Yes |

`Memory.Address = Tagged<Memory, Ordinal>` — an integer representation of a pointer's bit pattern, deliberately stripped of provenance. The address is a `UInt` wrapped in typed wrappers.

**Assessment**: Making these `~Escapable` would be semantically misleading. `~Escapable` enforces that a value cannot outlive its source's *lexical scope*. But `Memory.Address` is a number — it has no relationship to any specific allocation's scope. You can create a `Memory.Address` from a literal `UInt`, and no lifetime dependency would be meaningful.

The safety concern with `Memory.Buffer` is not about escaping a scope (a lexical property) but about outliving an allocation (a dynamic property). These are fundamentally different:

```
Lexical scope:    { let buffer = alloc(); /* buffer valid here */ }  // ~Escapable prevents escape
Allocation scope: let buffer = alloc(); free(buffer); /* buffer dangling */  // ~Escapable can't help
```

`~Escapable` is the wrong tool for integer-address-model views.

### 2.3 Pure Values — types with no memory relationship

| Package | Type | Description |
|---------|------|-------------|
| memory | `Memory.Address` | Integer address (no provenance) |
| memory | `Memory.Alignment` | Power-of-2 alignment value |
| memory | `Memory.Shift` | Bit shift count |
| memory | `Memory.Allocation` | Namespace enum |
| storage | `Storage.Initialization` | Slot tracking state |
| storage | `Storage.Heap.Header` | ManagedBuffer header |
| storage | `Storage.Arena.Meta` | Per-slot metadata |
| storage | `Storage.Field<V>` | Byte offset + stride |
| buffer | All `Header` types | Pure cursor state |
| buffer | `Buffer.Arena.Position` | Index + token |
| buffer | `Buffer.Growth.Policy` | Growth strategy |
| buffer | All error types | Error cases |

**Assessment**: Pure values MUST NOT be `~Escapable`. They carry no borrowed reference to any other value and need to be freely storable and returnable.

### 2.4 Tag Types — enums for the Property accessor pattern

| Package | Examples |
|---------|----------|
| storage | `Storage.Initialize`, `Storage.Deinitialize`, `Storage.Copy`, `Storage.Move` |
| buffer | `Buffer.Ring.Push`, `Buffer.Ring.Pop`, `Buffer.Ring.Peek`, `Buffer.Linear.Peek`, etc. |

**Assessment**: Tag types are zero-size markers. `~Escapable` has no semantic relevance.

### 2.5 Already-~Escapable Types — borrowed views and yielded accessors

These types are ALREADY `~Escapable` in the current architecture:

| Source | Type | Pattern |
|--------|------|---------|
| stdlib | `Span<Element>` | Returned via `@_lifetime(borrow self)` from `.span` properties |
| stdlib | `MutableSpan<Element>` | Returned via `@_lifetime(&self)` from `.mutableSpan` properties |
| stdlib | `RawSpan` | Raw untyped equivalent of Span |
| property-primitives | `Property.View<Tag, Base>` | Yielded via `_read`/`_modify` coroutines |
| property-primitives | `Property.View.Read<Tag, Base>` | Yielded via `_read`; `~Copyable, ~Escapable` |

Current usage across the three packages:

| Metric | memory-primitives | storage-primitives | buffer-primitives |
|--------|------------------:|-------------------:|------------------:|
| `@_lifetime` annotations | 3 | 20+ | 100+ |
| `_overrideLifetime` calls | 1 | 3 | varies |
| `Span` properties | 1 (`Memory.Contiguous.span`) | 2 (Heap, Inline) | all linear/ring types |
| `MutableSpan` properties | 0 | 1 (Inline) | all linear/ring types |
| Yielding `_read` accessors | few | many | many |
| Yielding `_modify` accessors | few | many | many |

**Assessment**: The `~Escapable` boundary is already at the correct abstraction layer — the borrowed-view layer. Span and Property.View provide lifetime-safe access to the internals of owning types. This is precisely where `~Escapable` belongs.

---

## Part III: Fitness Analysis

### 3.1 Question: Should any currently-Escapable type become ~Escapable?

For each category:

| Category | Type Count | Should become ~Escapable? | Reason |
|----------|----------:|:------------------------:|--------|
| Owners (struct) | ~30 | **No** | Must be storable, returnable, transferable |
| Owners (class) | 5 | **No** | Classes cannot be ~Escapable (Swift limitation) |
| Integer-address views | 2 | **No** | No provenance — ~Escapable can't enforce the relevant safety property |
| Pure values | ~20 | **No** | No borrowed reference — ~Escapable has no semantic content |
| Tag types | ~15 | **No** | Zero-size markers |
| Already ~Escapable | — | Already done | Span, MutableSpan, Property.View |

**Finding**: No currently-Escapable type in these three packages should become `~Escapable`.

### 3.2 Question: Should new ~Escapable types be introduced?

Potential candidates for new types:

#### Candidate A: Provenance-carrying raw buffer view

A type like `Memory.Buffer.Borrowed` that wraps a raw pointer (not an integer address) with `~Escapable` semantics:

```swift
public struct Borrowed: ~Escapable {
    internal let _pointer: UnsafeRawPointer
    internal let _count: Int

    @_lifetime(borrow source)
    init(borrowing source: Memory.Contiguous<some BitwiseCopyable>) { ... }
}
```

**Analysis**: This would be `RawSpan` with a different name. `RawSpan` already provides exactly this: a `~Escapable`, provenance-carrying, raw contiguous memory view. Introducing a duplicate would violate the principle of not reinventing stdlib primitives.

**Verdict**: Not needed — `RawSpan` already fills this role.

#### Candidate B: Typed mutable borrowed view for Storage.Inline

A `~Escapable` mutable view into inline storage that provides direct element mutation without going through `Property.View`:

```swift
public struct MutableView: ~Copyable, ~Escapable {
    internal let _base: UnsafeMutablePointer<Storage<Element>.Inline<capacity>>

    @_lifetime(&storage)
    init(_ storage: inout Storage<Element>.Inline<capacity>) { ... }

    subscript(slot: Index<Element>) -> Element { ... }
}
```

**Analysis**: `MutableSpan<Element>` already provides this for contiguous element access. Storage.Inline already exposes `.mutableSpan` via `@_lifetime(&self)`. For non-contiguous access (e.g., individual slot operations), the Property.View pattern with `_modify` accessors already handles this.

**Verdict**: Not needed — `MutableSpan` + Property.View already cover these patterns.

#### Candidate C: ~Escapable elements in containers

Could containers hold `~Escapable` elements (e.g., `Buffer.Ring<Span<Int>>`)?

**Analysis**: Fundamentally blocked. Storing a `~Escapable` value requires the container itself to be `~Escapable` (containment rule). But containers are owners — they must be storable and returnable. Making a `Buffer.Ring` `~Escapable` defeats its purpose.

Even if possible, the semantics would be incoherent: a ring buffer of Spans implies the Spans survive across push/pop operations, but `~Escapable` values are scope-bound. The source of each Span would need to outlive the buffer, and all Spans would need the same source — this is a fixed-size view, not a dynamic container.

**Verdict**: Not viable — contradicts the ownership model of containers.

---

## Part IV: Soundness Analysis

### 4.1 Known Language Limitations Affecting ~Escapable

| Limitation | Impact on These Packages | Status |
|------------|--------------------------|--------|
| **Closure integration gap (narrowed)** | `~Copyable & ~Escapable` types that store `~Escapable` fields cannot be passed to closure parameters. However, `Span` alone, and `Copyable & ~Escapable` types (even with `~Escapable` fields) CAN be passed. See experiment for exact boundary. | Partially fixed in Swift 6.2.4; narrow gap remains |
| **No ~Escapable in deinit** | Cannot create `~Escapable` views in `deinit` for cleanup delegation | Workaround: `@_unsafeNonescapableResult get` (documented in `escapable-deinit-lifetime.md`) |
| **Classes cannot be ~Escapable** | 5 storage types (Heap, Pool, Arena, Slab, Split) are classes and cannot participate | Swift language constraint |
| **`@_lifetime` is experimental** | All lifetime annotations use `@_lifetime` (underscore prefix), which may change syntax | Feature flag: `Lifetimes` |
| **`_overrideLifetime` required** | Each Span/MutableSpan property needs this unsafe bridge | 28 sites currently; each is returning-model technical debt |
| **No BorrowingSequence** | Cannot iterate ~Escapable elements with for-in | Pitch stage only |

#### Closure Gap Boundary (Experimentally Determined, Swift 6.2.4)

| Type Configuration | Closure Passing | Verified |
|--------------------|:---------------:|:--------:|
| `Copyable` + `~Escapable` + no `~Escapable` fields | **Works** | Yes |
| `Copyable` + `~Escapable` + stores `Span` | **Works** | Yes |
| `~Copyable` + `~Escapable` + no `~Escapable` fields | **Works** | Yes |
| `~Copyable` + `~Escapable` + stores `Span` (or any `~Escapable` field) | **Fails** | Yes |
| `Span<T>` directly | **Works** | Yes |
| `@_lifetime(immortal)` values | **Works** | Yes |

The gap specifically targets the combination: `~Copyable` + `~Escapable` + stored `~Escapable` field. This is a narrower limitation than previously documented.

#### Compiler Source Analysis (swiftlang/swift, 2026-02-28)

Cross-referencing the experiment results against the compiler source reveals that all LifetimeDependence closure improvements are on `main` only — **none have shipped in `release/6.2`** (Swift 6.2.4). The simple Copyable cases passing in 6.2.4 reflect the original implementation's behavior, not recent improvements.

Key commits on `main` (not yet in any release):

| Date | Commit | Description |
|------|--------|-------------|
| 2025-11-10 | `7b9db389848` | `LifetimeDependence: Support function types` — foundational |
| 2026-02-06 | `d0003468249` | `Inference for closure expressions` — enables closure coercion to lifetime-dependent function types |
| 2026-02-10 | PR #87085 | **"Basic support for closures with lifetime dependencies"** — the key PR |
| 2026-02-19 | `6a9875c73e9` | `Support for mutable captures` of `~Escapable` values |
| 2026-02-23 | `cc7e4ab33a6` | `Fix lifetime type checking for nonescaping closures` — allows `func f(body: () -> NE) -> NE` without annotation |

When these land in a release (likely Swift 6.3), the `withBorrowed` closure pattern documented as blocked in `lifetime-dependent-borrowed-cursors.md` should become possible for `~Copyable & ~Escapable` types with stored `~Escapable` fields.

### 4.2 Soundness of Current ~Escapable Usage

The current usage IS sound:

1. **Span properties**: Each `span` property uses `@_lifetime(borrow self)` + `_overrideLifetime(_, borrowing: self)`. The `_overrideLifetime` call is `@unsafe` and manually audited. The Span cannot outlive the borrow of `self`. Sound.

2. **MutableSpan properties**: Each `mutableSpan` property uses `@_lifetime(&self)` + `_overrideLifetime(_, mutating: &self)`. Exclusive access prevents aliasing. Sound.

3. **Property.View (yielding)**: The `_read`/`_modify` coroutine structurally bounds the view's lifetime to the accessor's scope. No `_overrideLifetime` needed. Sound by construction.

4. **Pointer-returning methods**: `@_lifetime(borrow self)` on `pointer(at:)` methods in Inline types ensures pointers don't outlive the storage. Sound (modulo the inherent unsafety of returning raw pointers).

### 4.3 Soundness of Proposed Expansions

If we were to make `Memory.Buffer` `~Escapable`:

1. **Would need `@_lifetime` on all creation points**: `init(_ buffer: UnsafeRawBufferPointer)`, `init(start:count:)`, etc. But these take `UnsafeRawPointer` arguments, which are `Escapable` — the compiler cannot verify the pointer's validity. The lifetime annotation would annotate a relationship that the compiler can't enforce.

2. **Would need to make all types containing Memory.Buffer also ~Escapable**: This cascades. Any struct storing a `Memory.Buffer` would need to be `~Escapable`, which would cascade further.

3. **Would break 31+ downstream uses**: `Memory.Buffer` is used as a stored property and return value in multiple packages.

**Conclusion**: Expanding `~Escapable` beyond the current Span/Property.View boundary would be unsound (for integer-address types), impractical (containment cascade), or redundant (stdlib already provides the right types).

---

## Part V: Benefits Assessment

### 5.1 Benefits of the Current Architecture

The existing dual-model approach already delivers the key benefits of `~Escapable`:

| Benefit | How It's Achieved | Example |
|---------|-------------------|---------|
| Compile-time lifetime safety for read access | `span: Span<E>` with `@_lifetime(borrow self)` | `buffer.span[i]` — Span cannot outlive buffer |
| Compile-time lifetime safety for write access | `mutableSpan: MutableSpan<E>` with `@_lifetime(&self)` | `buffer.mutableSpan[i] = v` — exclusive access enforced |
| Safe element borrowing | Property.View.Read via `_read` coroutine | `buffer.peek.first { $0 }` — view scoped to coroutine |
| Safe element mutation | Property.View via `_modify` coroutine | `buffer.push.back(element)` — view scoped to coroutine |
| Zero-copy access | Span provides direct pointer access with bounds checking | No allocation or copy needed |
| Bounds-checked subscripts | Span in all build modes; `Index<T>.Bounded` for inline types | Eliminates overflow/underflow |

### 5.2 What Additional ~Escapable Would NOT Add

| Hypothetical Benefit | Reality |
|---------------------|---------|
| "Prevent use-after-free on Memory.Buffer" | Memory.Buffer uses integer addresses (no provenance); ~Escapable can't enforce allocation lifetime |
| "Prevent storing a dangling buffer reference" | The address model is deliberately provenance-free; safety here requires discipline, not types |
| "Safe views into storage without closures" | Already provided by Span (returning model) and Property.View (yielding model) |
| "~Escapable elements in collections" | Blocked by containment rule + ownership semantics |

### 5.3 Where Expansion Could Provide Value (Narrow)

Two areas where expanded `~Escapable` usage could improve the current architecture, without changing existing types:

**Area 1: SE-0507 Borrow Accessors** (Watch-listed in yielding-vs-returning)

When SE-0507 `borrow` accessors ship, Span properties could use `borrow` instead of `get` + `@_lifetime` + `_overrideLifetime`. This would eliminate the `_overrideLifetime` unsafe bridge:

```swift
// Current (returning model with unsafe bridge):
public var span: Span<Element> {
    @_lifetime(borrow self)
    borrowing get {
        let s = unsafe Span(_unsafeStart: ptr, count: count)
        return unsafe _overrideLifetime(s, borrowing: self)
    }
}

// Future (borrow accessor, no unsafe bridge):
public var span: Span<Element> {
    borrow {
        // compiler knows result borrows from self
        unsafe Span(_unsafeStart: ptr, count: count)
    }
}
```

This does not introduce new `~Escapable` types but improves the soundness of existing Span properties by removing `_overrideLifetime`.

**Area 2: Closure Lifetime Annotations** (Watch-listed in yielding-vs-returning)

When Swift gains closure parameter lifetime annotations, the closure integration gap closes. This would enable:

```swift
// Future (not possible in Swift 6.2):
func withBorrowedSpan<T>(_ body: @_lifetime(borrow self) (Span<Element>) -> T) -> T
```

This expands the usability of existing `~Escapable` types (Span, MutableSpan) but does not require making any new types `~Escapable`.

---

## Part V-B: Ecosystem-Wide Completeness Scan

### Methodology

To verify that the findings in Parts II–V are not limited to the three targeted packages, a completeness scan was performed across all 126 packages in swift-primitives. The scan cross-referenced every package against `~Escapable`, `@_lifetime`, `_overrideLifetime`, `Span<`, `MutableSpan<`, and `RawSpan` usage (282 file matches across 37 packages), then analyzed each non-matching package for missed ~Escapable opportunities.

### 5B.1 Packages Already Using Lifetime Features (37)

These packages already use `~Escapable`, `Span`, `@_lifetime`, or `_overrideLifetime`:

| Category | Packages |
|----------|----------|
| **Core infrastructure** | memory, storage, buffer, property, sequence, collection |
| **Data structures** | array, stack, queue, heap, set, dictionary, list, hash-table, bit-vector |
| **Parsing** | parser, binary-parser, binary, input |
| **Identity/Text** | identity, string, path, token |
| **Index/Ordinal** | ordinal, cardinal, vector, index (experiments) |
| **Trees/Graphs** | tree, graph |
| **Platform** | darwin, linux, windows, kernel, machine, loader |
| **Other** | cyclic, finite, standard-library-extensions |

### 5B.2 Packages Without Lifetime Features — Correctly So (~89)

The remaining packages were analyzed and grouped by why `~Escapable` is inapplicable:

| Category | Count | Representative Packages | Why Not Applicable |
|----------|------:|-------------------------|--------------------|
| **Algebra** (magma→field→module→affine→linear) | 16 | algebra-magma, algebra-group, algebra-ring, algebra-field | Pure mathematical abstractions — protocols and value types with no memory relationship |
| **Platform/CPU** | 5 | arm, riscv, x86, cpu, abi | Register definitions and ABI types — all value types |
| **Coordinates/Geometry** | 9 | geometry, affine-geometry, positioning, space, dimension, region, layout, transform, matrix | Pure geometric/spatial value types — no contiguous memory access |
| **Type system/Protocols** | 11 | comparison, ordering, logic, predicate, type, witness, ownership, lifetime, error, outcome, effect | Protocol definitions and small value types — no borrowed reference semantics |
| **Scalar/Numeric** | 8 | scalar, numeric, decimal, complex, endian, random, sample, equation | Pure numeric value types — no memory views |
| **Text/Source** | 8 | text, source, ascii, lexer, syntax, symbol, formatting, locale | Metadata/coordinate types (phantom-tagged integers, enum cases) — no memory access |
| **Infrastructure** | ~32 | handle, reference, cache, pool, async, continuation, state, dependency, clock, time, range, slice, infinite, etc. | Owned values, capability tokens, protocol namespaces, or stub packages |

### 5B.3 Investigated Candidates

Fifteen packages were investigated in detail as potential candidates:

| Package | Investigated Because | Finding |
|---------|---------------------|---------|
| **pool** | `Pool.Bounded.Checkout` is ~Copyable, described as "borrowed capability token" | **Not a candidate.** Checkout is `@usableFromInline` (internal), never referenced in code (dead type), fields are all value types (slot index, entry, ID), and the public API is already closure-scoped (`acquire { resource in ... }`) |
| **slab** | Holds `Buffer.Slab.Bounded` — could expose borrowed views | **Not now.** No view access patterns exposed; candidate only if view-based read accessors are added |
| **bitset** | Holds contiguous `UInt` storage — could have bit-range views | **Not now.** No read-only view accessors; mutating operations dominate |
| **source** | Could have spans into source text | **No.** All metadata/identity types (File, Position, Location) |
| **text** | Could have text spans | **No.** Phantom-tagged coordinate types (Position, Offset, Count) |
| **lexer** | Could use Span for token ranges | **No.** Token descriptors with trivia metadata — no borrowed views |
| **region** | Memory regions — could involve borrowed access | **No.** Spatial enum types (Quadrant, Octant, Edge, Corner) |
| **reference** | Non-owning references — different borrowed model | **No.** ARC weak/unowned references — different model from ~Escapable |
| **matrix** | Could have row/column spans | **No.** Pure algebraic matrix types |
| **handle** | Capability tokens — could be borrowed | **No.** Opaque `Tagged<Phantom, SlotAddress>` — no access semantics |
| **layout** | Type layout views | **No.** Compositional functor over geometry |
| **cache** | Views into cached data | **No.** Owned values with `Ownership.Mutable` reference semantics |
| **syntax** | Syntax tree views | **No.** Namespace stub — minimal content |
| **parser-machine** | Parser state machines — could use Span | **No.** Defunctionalized machine (accumulator-based) — no contiguous access |
| **slice** | Slicing — could produce borrowed views | **No.** Package exists but has no `Sources/` content (stub) |

### 5B.4 Scan Verdict

**No missed `~Escapable` opportunities across the full 126-package ecosystem.** The 37 packages already using lifetime features cover all types that handle borrowed access, contiguous memory, or pointer-based views. The remaining ~89 packages operate on pure values, protocols, or owned references where `~Escapable` has no semantic content.

---

## Part VI: Outcome

### Status: DECISION

Analysis complete. All edge cases experimentally validated against Swift 6.2.4 (Apple Swift 6.2.4, swiftlang-6.2.4.1.4). See `Experiments/nonescapable-edge-cases/` for full verification.

### Principal Findings

1. **No existing type should become `~Escapable`.** Every type in memory-primitives, storage-primitives, and buffer-primitives is correctly classified: owning types are `~Copyable` + `Escapable`, borrowed views are already `~Escapable` (Span, Property.View), and integer-address views cannot benefit from `~Escapable` due to the provenance-free address model. An ecosystem-wide scan across all 126 packages (Part V-B) confirms this finding extends to the full primitives layer — no package contains types that would benefit from additional `~Escapable` adoption.

2. **No new `~Escapable` types need to be introduced.** The stdlib (`Span`, `MutableSpan`, `RawSpan`, `OutputSpan`) and property-primitives (`Property.View`, `Property.View.Read`) already provide complete coverage of the borrowed-view space. Any new `~Escapable` type would duplicate existing abstractions. Of 15 packages investigated as potential candidates, none warranted `~Escapable` adoption.

3. **The existing dual-model architecture is correct.** Yielding (599 sites) is primary for element access. Returning (`~Escapable` via Span) is surgical for stdlib interop (28 `_overrideLifetime` sites). This matches the recommendation in `yielding-vs-returning-lifetime-models.md`.

4. **The integer-address model is the key differentiator.** `Memory.Address = Tagged<Memory, Ordinal>` is deliberately provenance-free. This design decision makes `~Escapable` inapplicable to `Memory.Buffer` — the safety concern (outliving an allocation) is a dynamic property that `~Escapable` (a lexical/scope property) cannot enforce.

5. **Future language evolution will improve the existing pattern, not change it.** SE-0507 `borrow` accessors could eliminate `_overrideLifetime` on Span properties. Closure lifetime annotations could close the remaining closure gap. Neither requires changing which types are `~Escapable`.

6. **The closure integration gap is narrower than previously documented.** Experimental validation (8 edge cases, Swift 6.2.4) reveals that `Span<T>` alone, and `Copyable & ~Escapable` types (even with stored `~Escapable` fields), CAN be passed to non-escaping closures. The gap only manifests for `~Copyable & ~Escapable` types with stored `~Escapable` fields. This is a significant improvement over the state documented in earlier research.

### Recommendation

| Priority | Action | Rationale |
|----------|--------|-----------|
| **Do not do** | Do not make owning types `~Escapable` | Owners must be storable and returnable |
| **Do not do** | Do not make `Memory.Buffer` `~Escapable` | Integer-address model lacks provenance; `~Escapable` would enforce a constraint the compiler can't verify |
| **Do not do** | Do not introduce new `~Escapable` wrapper types | Span, MutableSpan, RawSpan, Property.View already cover the borrowed-view space |
| **Continue** | Continue using `@_lifetime` on Span/MutableSpan properties | Existing pattern is sound and well-understood |
| **Continue** | Continue using yielding (`_read`/`_modify`) as primary borrowed-access model | 599 sites; no unsafe bridges needed |
| **Watch** | SE-0507 `borrow` accessors | Could eliminate `_overrideLifetime` on Span properties |
| **Watch** | PR #87085 closure lifetime support | On `main` now; when released, `withBorrowed` closure pattern becomes viable for `~Copyable & ~Escapable` cursor types |
| **Watch** | `Borrow<T>` / `Inout<T>` pitch | New stdlib ~Escapable reference types; may affect pointer-returning APIs |
| **Watch** | BorrowingSequence pitch | Would enable for-in over ~Escapable elements |

### Summary

The `~Escapable` support story for the primitives ecosystem is: **it's already done.** A completeness scan across all 126 packages (37 using lifetime features, ~89 correctly not) confirms that the `~Escapable` boundary sits at the Span/Property.View layer, which is precisely where it should be. The owning types below that boundary must remain `Escapable` to function as owners. The pure-value types have no lifetime relationship to enforce. The integer-address model makes `~Escapable` inapplicable to `Memory.Buffer`. No package in the ecosystem contains types that would benefit from additional `~Escapable` adoption.

The correct investments are:
1. Monitoring language evolution (SE-0507, closure lifetime annotations) for improvements to the existing pattern
2. Maintaining the `_overrideLifetime` count as a health metric (28 currently; growth indicates returning-model expansion beyond Span interop)
3. Expanding Span/MutableSpan property coverage to any owning type that provides contiguous access but doesn't yet expose `.span`

---

## References

### Experiment

0. `swift-primitives/Experiments/nonescapable-edge-cases/` — 8 edge cases validated against Swift 6.2.4. Includes closure gap boundary determination, containment cascade, integer-address soundness, deinit limitation, and ~Copyable+~Escapable combination.

### Swift Primitives Internal Research

1. "Yielding vs Returning: Lifetime Models for Borrowed Access." `swift-primitives/Research/yielding-vs-returning-lifetime-models.md`
2. "~Escapable Values in deinit." `swift-storage-primitives/Research/escapable-deinit-lifetime.md`
3. "Lifetime-Dependent Borrowed Cursors." `swift-memory-primitives/Research/lifetime-dependent-borrowed-cursors.md`
4. "Lifetime and Memory Safety: Experiment Results." `swift-memory-primitives/Research/Lifetime-Memory-Safety-Plan.md`
5. "View vs Span: Borrowed Access Types." `swift-primitives/Research/view-vs-span-borrowed-access-types.md`
6. "Non-Copyable View Types for Peek and Reversed." `swift-buffer-primitives/Research/noncopyable-view-types-for-peek-reversed.md`

### Swift Evolution Proposals

7. SE-0446: Nonescapable Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
8. SE-0447: Span: Safe Access to Contiguous Storage. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
9. SE-0456: Add Span-providing Properties to Standard Library Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md
10. SE-0465: Standard Library Primitives for Nonescapable Types. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md
11. SE-0467: MutableSpan. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-mutablespan.md
12. SE-0485: OutputSpan. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md
13. SE-0499: Support ~Copyable, ~Escapable in Simple Standard Library Protocols. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md
14. SE-0507: Borrow and Mutate Accessors. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md

### Swift Forums

15. "~Escapable, Span, Ownership Annotations, etc." https://forums.swift.org/t/escapable-span-ownership-annotations-etc/84566
16. Pitch #3: Compile-time lifetime dependency annotations. https://forums.swift.org/t/pitch-3-compile-time-lifetime-dependency-annotations/84968
17. Borrow and Inout types for safe, first-class references. https://forums.swift.org/t/borrow-and-inout-types-for-safe-first-class-references/84490
18. Experimental support for lifetime dependencies. https://forums.swift.org/t/experimental-support-for-lifetime-dependencies-in-swift-6-2-and-beyond/78638
