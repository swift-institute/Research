# Storage Primitives Modularization Review

<!--
---
version: 1.0.0
last_updated: 2026-04-16
status: DECISION
tier: 2
changelog:
  - 1.0.0 (2026-04-16): Closed as DECISION. Outcome flipped from initial Option B leaning to Option A (status quo) after recalibration: the Storage taxonomy is intentional curation, not an orthogonal grid; the Chase-Lev "gap" was wrong-layer reasoning. Added ecosystem-vestigial-ManagedBuffer framing.
  - 0.1.0 (2026-04-16): Initial draft.
---
-->

## Context

`swift-storage-primitives` currently ships four storage disciplines:

| Type | Placement | Layout | Init Tracking |
|------|-----------|--------|---------------|
| `Storage.Heap` | Heap (ManagedBuffer) | Single-lane dense | `Storage.Initialization` (range-merging) |
| `Storage.Inline<E, capacity>` | Inline (`@_rawLayout`) | Single-lane dense | `Bit.Vector.Static` (per-slot bitmap) |
| `Storage.Split<Lane>` | Heap (ManagedBuffer) | Dual-lane SoA | None — consumer-managed |
| `Storage.Pool` | Heap (ManagedBuffer) | Single-lane dense | `Bit.Vector` (per-slot allocation bitmap) |

A consultation triggered by `swift-executors`' Chase-Lev work-stealing deque
design (`swift-foundations/swift-executors/Research/work-stealing-scheduler-design.md`)
surfaced that none of these four cleanly fits a fifth discipline shape that
the deque needs: **single-lane dense heap storage with no init tracking,
because the algorithm tracks liveness via atomic indices rather than the
storage layer**.

Today the workarounds are:

1. **`Storage<E>.Split<Lane>` with a dummy `Lane` (e.g., `UInt8`)** — provides
   the consumer-managed-lifecycle contract, but pays for an unused metadata
   lane (`N × stride(Lane)` bytes) and exposes a dual-handle API the consumer
   does not need.
2. **Direct `ManagedBuffer<Header, Element>`** — bypasses the Storage
   abstraction entirely. This is the pattern the stdlib's
   `_ContiguousArrayStorage` uses (`stdlib/public/core/ContiguousArrayBuffer.swift:132–308`,
   via `Builtin.allocWithTailElems` rather than `ManagedBuffer`, but
   structurally equivalent).
3. **Raw `UnsafeMutableBufferPointer<Element>` allocation** — bypasses both
   layers; idiomatic for the spike but not for production primitives.

The Chase-Lev case is one example. The broader question this document opens
is whether the existing four disciplines are the right *decomposition* of
the storage design space — particularly given the user-confirmed mission
that "primitives compose."

## Question

Are the current four `Storage` disciplines the right decomposition, or
should the storage layer be re-factored along more orthogonal axes that
allow consumer-managed-lifecycle, single-lane, heap storage to fall out as
a composition rather than as a missing cell?

Sub-questions:

1. **Is the missing cell a real gap?** Concrete consumer (Chase-Lev). Are
   there others?
2. **What are the right decomposition axes?** Placement × layout ×
   lifecycle-tracking is one factoring. Are there better ones?
3. **Should lifecycle tracking be composable?** Could a wrapper type add
   tracking *onto* an untracked base — `Storage.Tracked<Storage.Untracked.Heap>`
   — rather than being baked into each discipline?
4. **What is the smallest addition that closes the gap?** A dedicated
   `Storage<E>.Untracked.Heap`? A single-lane mode of `Split`? A renamed
   factoring of all four?

## Constraints

| Constraint | Source | Implication |
|------------|--------|-------------|
| `~Copyable` element support | Existing storage disciplines | Any new primitive MUST handle ~Copyable elements |
| `BitwiseCopyable`-only is an acceptable narrower variant | `Storage.Contiguous`, `Storage.Split.Lane` precedent | A "trivial-only" untracked primitive is permissible |
| ManagedBuffer header must be Copyable | `ManagedBuffer.create(minimumCapacity:makingHeaderWith:)` returns Header by value | Atomics or other ~Copyable state cannot live in the header |
| No `Foundation` dependency | `swift-primitives` rule | Any new primitive uses stdlib + sibling primitives only |
| Existing four disciplines have downstream consumers | `swift-foundations` collections | Renaming or restructuring requires migration; *additive* changes preferred |

## Prior Art

### Stdlib

The stdlib's `_ContiguousArrayStorage<Element>` (`ContiguousArrayBuffer.swift:132`)
is a tail-allocated typed heap class with no init-tracking machinery.
Initialization is tracked externally in `_ArrayBody.count`; deinitialization
in `deinit` calls `_elementPointer.deinitialize(count: countAndCapacity.count)`.
This is *exactly* the "untracked heap, single-lane, dense" shape — implemented
once for `Array`, never reified as a reusable primitive.

`ManagedBuffer<Header, Element>` itself (`stdlib/public/core/ManagedBuffer.swift`)
is the public-API primitive. It does not enforce or provide init-tracking — it
is the raw "header + tail-allocated typed elements" abstraction. Per [DS-005]
this is structurally what `Storage<E>.Split<Lane>` builds on; an untracked
single-lane storage would also build directly on `ManagedBuffer<Header, E>`.

### Rust

`Vec<T>` (tracked, owns + deinits via Drop) and `Box<[MaybeUninit<T>; N]>`
(untracked, manual lifecycle) are separate primitives, not unified by a
"tracking" axis. Decomposition is along *type-level lifecycle marker*
(`MaybeUninit<T>`) rather than along storage discipline.

### swift-primitives

The existing decomposition is "named useful disciplines" rather than
orthogonal cells. Each discipline is a complete, named composition:

- `Heap` = ManagedBuffer + range-tracking
- `Inline` = `@_rawLayout` + bitmap-tracking
- `Split` = ManagedBuffer + dual-lane + no-tracking
- `Pool` = ManagedBuffer + bitmap-tracking + slot-allocation API

Per [RES-021] contextualization step: orthogonal axes (4 placements × 4
layouts × 5 trackings = 80 cells) is not what mainstream ecosystems do, and
most cells would be useless. The current taxonomy is intentional curation,
not a flat product.

## Analysis

### Decomposition axes

| Axis | Values | Notes |
|------|--------|-------|
| Placement | Heap (ManagedBuffer), Inline (`@_rawLayout`) | Stack-allocated heap classes are not a third option |
| Layout | Single-lane dense, Dual-lane SoA, Sparse (slab/pool) | Single-lane is the common case |
| Init tracking | None (consumer-managed), Range-merging, Bitmap (slot/wordcount), Generation-token | Tracking has cost; not every consumer wants it |

A 2 × 3 × 4 grid yields 24 cells. The four current primitives occupy:

| Discipline | Placement | Layout | Tracking | Notes |
|------------|-----------|--------|----------|-------|
| `Heap` | Heap | Single-lane | Range | Most common |
| `Inline` | Inline | Single-lane | Bitmap | Stack-allocated |
| `Split<Lane>` | Heap | Dual-lane | None | Hash-table backing |
| `Pool` | Heap | Single-lane | Bitmap (alloc) | Pool-allocator |

The cell **(Heap, Single-lane, None)** is *unoccupied*. This is the cell
Chase-Lev's deque needs.

### Options

#### Option A — Accept the current taxonomy; consumers use ManagedBuffer directly

Chase-Lev's `Executor.Job.Deque` uses `ManagedBuffer<Header, UnownedJob>`
directly, matching the stdlib pattern. Storage layer is unchanged.

**Pros**: zero churn; matches stdlib precedent; the "do nothing" option is
defensible since stdlib itself doesn't reify this primitive.

**Cons**: every consumer that needs the cell re-implements the same
ManagedBuffer wrapping. The Storage layer's claim to model the storage
design space is incomplete.

#### Option B — Add `Storage<E>.Untracked.Heap`

A new single-lane untracked heap class, structurally `ManagedBuffer<Header, E>`
with the consumer-managed-lifecycle contract from `Storage.Split` adapted
to single-lane.

```swift
extension Storage where Element: ~Copyable {
    public final class Untracked: ManagedBuffer<Storage.Untracked.Header, Element> {
        // No deinit — consumer manages element lifecycle.
    }
}
```

**Pros**: occupies the missing cell; reusable for Chase-Lev and any future
consumer; one additional primitive, additive only.

**Cons**: introduces a `.Untracked.` namespace level; needs a clear naming
convention (`Untracked.Heap` / `Untracked.Inline`?) and a story for whether
existing tracked disciplines should be renamed for symmetry (`Tracked.Heap` /
`Tracked.Inline`).

#### Option C — Make `Storage.Split.Lane` optional (single-lane mode)

Allow `Storage.Split<Void>` or introduce a marker indicating "no metadata
lane." The same ManagedBuffer backing serves both modes.

**Pros**: no new top-level primitive; reuses existing field-handle API.

**Cons**: `Storage.Split` is named for its dual-lane purpose; using it for
the single-lane case is semantically misleading. Field handles for a
non-existent lane are dead surface area.

#### Option D — Factor tracking into a composable wrapper

Introduce `Storage.Untracked.Heap` (option B) as the base, and refactor
`Storage.Heap` to be `Storage.Tracked<Storage.Untracked.Heap>` — tracking
becomes a wrapper rather than a property of each discipline.

**Pros**: maximally composable; matches the user-confirmed mission of
"primitives that compose"; would also let consumers compose alternative
tracking strategies (e.g., generation-token tracking around an Untracked
base).

**Cons**: substantial refactor; existing `Storage.Heap` consumers see API
churn; the wrapper indirection has runtime cost (extra method calls,
potentially extra heap allocation if not carefully designed); the analogous
factoring of `Inline` and `Split` may not be uniform.

### Comparison

| Criterion | A: Status quo | B: Add Untracked.Heap | C: Single-lane Split | D: Tracking wrapper |
|-----------|:---:|:---:|:---:|:---:|
| Closes the Chase-Lev cell | ❌ (consumer reimplements) | ✓ | ✓ (with overhead) | ✓ |
| Additive only | ✓ | ✓ | ⚠ (Lane semantics widen) | ❌ (refactor) |
| Reduces consumer boilerplate | ❌ | ✓ | ✓ | ✓ |
| Maximally composable | ❌ | ⚠ (one new cell) | ❌ | ✓ |
| Semantic clarity of names | ✓ | ⚠ (needs symmetric naming) | ❌ (Split for non-split) | ⚠ (wrapper introduces indirection) |
| Migration cost | none | none | low | high |

## Outcome

**Status:** `DECISION`.

**Decision: Option A — accept the current taxonomy. No new Storage
primitive is added.**

### Rationale

The "missing cell" framing was wrong. The Storage layer is *intentional
curation* — six named lifecycle disciplines, each shared across multiple
sequential collection families. It is not an orthogonal grid awaiting
completion. Adding `Storage<E>.Untracked.Heap` (the original Option B
leaning) would have been *premature primitive* — naming `ManagedBuffer`
with extra ceremony for the benefit of one consumer.

The corrected architectural framing is:

| Layer | Role | Examples |
|-------|------|----------|
| Memory | Raw allocation, typed inline, byte buffers | `Memory.Inline`, `Memory.Buffer.Mutable`, `Memory.Aligned`, allocators |
| **Storage** | **Sequential lifecycle disciplines shared across collection families** | `Heap`/`Inline`/`Split`/`Pool`/`Arena`/`Slab` |
| Buffer | Mutation logic shared across collection families | `Buffer.Linear`/`Ring`/`Slab`/`Linked`/`Slots`/`Arena` |
| Collection | User-facing API | `Array`, `Queue`, `Dictionary`, … |
| **stdlib** | `ManagedBuffer<H, E>` — universal tail-allocated typed memory | Backs `_ContiguousArrayStorage` *and* `Storage<E>.Heap`/`.Pool`/`.Split` themselves |

Chase-Lev's `Executor.Job.Deque` is a **concurrent collection primitive**,
not a sequential lifecycle discipline. It belongs at the same layer as
`Array` (its own L1 collection in `swift-executor-primitives`), backed
directly by `ManagedBuffer` — exactly the pattern stdlib's
`_ContiguousArrayStorage` uses. There is no Storage discipline gap because
no sequential collection family shares Chase-Lev's lifecycle pattern;
its pattern is algorithm-specific, not generalizable.

### Ecosystem-vestigial ManagedBuffer

`ManagedBuffer` is **vestigial in the ecosystem** — long-term, the aim is
to replace its uses with native ecosystem primitives. Today it remains
the de facto backing for tail-allocated typed memory because no native
ecosystem primitive yet covers that role at the same layer
(`swift-storage-primitives`' four heap-disciplines all *use* ManagedBuffer
internally; they don't *replace* it for the bare-tail-allocated case).

Replacing ManagedBuffer ecosystem-wide is a much larger project than this
note's scope:

- It would require a native primitive (likely in `swift-memory-primitives`
  or a new layer) that provides the tail-allocated-typed-memory contract.
- All four existing Storage disciplines would migrate from
  `ManagedBuffer<H, E>` backing to the native primitive.
- All ad-hoc consumers (`_ContiguousArrayStorage`-style classes, including
  `Executor.Job.Deque`) would migrate too.

That work is **out of scope here** and warrants its own research note in
`swift-memory-primitives/Research/`. This note's narrow conclusion stands
independently: no new Storage discipline is needed; ManagedBuffer is the
backing today; replacing ManagedBuffer is its own ecosystem-wide effort.

### Implications for Chase-Lev (and similar consumers)

- `Executor.Job.Deque` uses `ManagedBuffer<Header, UnownedJob>` directly
  for v1, matching the stdlib precedent of `_ContiguousArrayStorage`.
- This is a known vestigial-ManagedBuffer use to address when the
  ecosystem-wide replacement project happens. It is not a research
  question in `swift-storage-primitives`.
- If future concurrent collection primitives arrive (a second consumer of
  the same shape as Chase-Lev), reopen this question — at that point
  shared lifecycle logic might justify a `Storage<E>.Concurrent.*` family
  or similar abstraction. One consumer is not enough evidence.

### Trigger

Cross-posted from `swift-foundations/swift-executors/Research/work-stealing-scheduler-design.md`
which originally framed the absence as a mutable-typed-contiguous-memory gap
(later succeeded by `Storage.Contiguous`) at the Memory layer. Both framings
(Memory-layer gap, Storage-layer modularization) were wrong-layer /
wrong-question; the analysis above records why.

## References

### Stdlib

- `stdlib/public/core/ContiguousArrayBuffer.swift:132–308` — `_ContiguousArrayStorage`
  pattern: tail-allocated typed elements, no Storage-style tracking, manual
  deinit using externally-tracked count.
- `stdlib/public/core/ManagedBuffer.swift` — `ManagedBuffer.create(minimumCapacity:makingHeaderWith:)`
  factory. Header must be value-returnable (Copyable).

### swift-storage-primitives internal

- `Storage Primitives Core/Storage.Heap.swift:35` — Heap discipline
- `Storage Primitives Core/Storage.Inline.swift` — Inline discipline
- `Storage Split Primitives/Storage.Split.swift:77` — Split discipline
  (note explicit "consumer-managed lifecycle … same contract as
  `UnsafeMutableBufferPointer` or raw `ManagedBuffer`")
- `Research/split-storage-design.md` — Split design rationale
- `Research/split-storage-naming.md` — Split naming literature study
- `Research/inline-storage-layering.md` — Memory vs Storage layering
- `Research/storage-ownership-reference-synthesis.md` — Master synthesis

### Cross-package trigger

- `swift-foundations/swift-executors/Research/work-stealing-scheduler-design.md`
  — Chase-Lev deque design where the gap surfaced.
- `swift-foundations/swift-executors/Experiments/chase-lev-deque-spike/`
  — Empirical validation that all three workarounds (UMBP, Memory.Inline,
  ManagedBuffer) work for the algorithm; the question this note opens is
  whether the *primitives layer* should reify the missing cell.

### Catalog

- `ecosystem-data-structures` skill, [DS-005] (Storage layer), [DS-006]
  (Memory layer), [DS-001] (four-layer composition architecture).
