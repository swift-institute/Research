# Buffer Variant Parity Analysis

<!--
---
version: 1.0.1
last_updated: 2026-03-15
status: DEFERRED
tier: 2
type: discovery/consistency-analysis
---
-->

## Context

Buffer primitives provide seven disciplines for managing elements in storage:
**Linear**, **Ring**, **Slab**, **Linked**, **Arena**, **Slots**, and **Pool** (separate package).

Each discipline follows a three-layer architecture (Header / Static Operations / Composed Types) and offers sub-variants: **base** (heap, growable), **Bounded** (heap, fixed), **Inline** (stack, fixed), and **Small** (inline + heap spill).

This discovery audit evaluates **pattern consistency** and **API surface parity** across the seven variants, identifying deviations that are unjustified and should be remediated versus deviations that are structurally warranted.

## Question

Do the buffer variants use consistent patterns throughout, and do they have parity in sub-variant coverage, protocol conformance, file organization, naming, and API surface?

---

## Analysis

### 1. Sub-Variant Coverage

| Sub-variant | Linear | Ring | Slab | Linked | Arena | Slots |
|-------------|:------:|:----:|:----:|:------:|:-----:|:-----:|
| Base (heap, growable) | Y | Y | Y | Y | Y | Y |
| Bounded (heap, fixed) | Y | Y | Y | - | Y | - |
| Inline (stack, fixed) | Y | Y | Y | Y | Y | - |
| Small (inline+spill) | Y | Y | - | Y | Y | - |

**Deviations**:

| Gap | Justification |
|-----|---------------|
| Slab has no Small | **Unjustified** — Slab.Inline exists; a Small variant that spills to heap Slab is structurally feasible and would provide parity with Linear.Small, Ring.Small, Linked.Small, Arena.Small |
| Linked has no Bounded | **Justified** — Linked uses `Storage<Node>.Pool` (reference-semantic). A fixed-capacity heap linked list is effectively what the base already provides when you don't call growth. But arguably should exist for API parity with other variants since a Bounded provides a guarantee (throws on overflow rather than growing) |
| Slots has no Bounded/Inline/Small | **Justified** — Slots is metadata-parametric and consumer-managed. It is the lowest-level primitive, designed for hash-table internals. Sub-variants would add complexity without clear use cases |

### 2. Storage Field Naming

| Variant | Field name | Storage type |
|---------|-----------|--------------|
| Linear | `storage` | `Storage<Element>.Heap` |
| Ring | `storage` | `Storage<Element>.Heap` |
| Slab | `storage` | `Storage<Element>.Heap` |
| Linked | `storage` | `Storage<Node>.Pool` |
| Slots | `storage` | `Storage<Element>.Split<Metadata>` |
| Arena | `_arenaStorage` | `Storage<Element>.Arena` |

**Deviation**: Arena uses `_arenaStorage` while all others use `storage`.

**Assessment**: **Unjustified**. The underscore-prefix convention is for truly private backing storage (like `_inlineBuffer`/`_heapBuffer` in Small variants). Arena's storage plays the same role as `storage` in every other variant. This should be `storage` for consistency. If the name collision concern is that `Storage<Element>.Arena` shares the `Arena` name, that's a namespace issue, not a field naming issue.

### 3. Initialization Patterns

| Variant | Init pattern | Signature |
|---------|-------------|-----------|
| Linear | `init(minimumCapacity:)` | `Index<Element>.Count` |
| Ring | `init(minimumCapacity:)` | `Index<Element>.Count` |
| Slab | `init(minimumCapacity:)` | `Index<Element>.Count` |
| Arena | `init(minimumCapacity:)` | `Index<Element>.Count` |
| Linked | `static func create(capacity:)` | `Index<Node>.Count` |
| Slots | `init(capacity:metadataInitial:)` | `Index<Element>.Count` + `Metadata` |

**Deviations**:

| Deviation | Assessment |
|-----------|------------|
| Linked uses `static func create(capacity:)` instead of `init` | **Unjustified** — All other variants use `init(minimumCapacity:)`. Linked should provide a `public init(minimumCapacity:)` for parity. The `create` pattern may be justified internally but the public API should match |
| Linked uses `capacity` instead of `minimumCapacity` | **Unjustified** — Should be `minimumCapacity` to signal that actual capacity may differ (pool overhead). All growable variants use `minimumCapacity` |
| Linked.Small uses `init()` | **Justified** — Small variants start inline with compile-time capacity. Linear.Small doesn't have a public init either (it's package-level). Needs parity check |
| Slots uses `capacity` + `metadataInitial` | **Justified** — Slots is fixed-capacity by design (like Bounded), and metadata initialization is a structural requirement |

### 4. Mutation API Naming

#### Linear vs Ring naming split

| Operation | Linear | Ring |
|-----------|--------|------|
| Add to back | `append(_:)` | `pushBack(_:)` |
| Remove from front | `consumeFront()` | `popFront()` |
| Remove from back | `removeLast()` | `popBack()` |
| Add to front | N/A | `pushFront(_:)` |

**Assessment**: Ring's push/pop naming is **self-consistent** (symmetric pairs). Linear's naming is **inconsistent** — `append` (stdlib convention) + `consumeFront` (ownership convention) + `removeLast` (stdlib convention). Three different naming philosophies in one type.

**Recommendation**: Linear should use either:
- (A) `append`/`removeFirst`/`removeLast` (stdlib-mirroring), or
- (B) `pushBack`/`popFront`/`popBack` (ring-mirroring for symmetry)

Current `consumeFront` is particularly inconsistent — no other variant uses `consume*` as a method prefix (consuming semantics are expressed via ownership annotations, not naming).

#### Slab naming

| Operation | Slab |
|-----------|------|
| Add | `insert(_:at:)` |
| Remove | `remove(at:)` |
| Replace | `update(at:with:)` |

**Assessment**: **Consistent** — slot-addressed operations with clear semantics.

#### Arena naming

| Operation | Arena |
|-----------|-------|
| Add | `insert(_:)` / `allocate()` |
| Remove | `remove(at:)` / `free(at:)` |

**Assessment**: **Mostly consistent**. `free(at:)` vs `remove(at:)` distinction (deinitialize-only vs deinitialize-and-return) is well-motivated.

#### Linked naming

| Operation | Linked |
|-----------|--------|
| Add front | `insertFront(_:)` |
| Add back | `insertBack(_:)` |
| Remove front | `removeFront()` |
| Remove back | `removeBack()` |

**Assessment**: **Self-consistent**. Symmetric `insert`/`remove` pairs with `Front`/`Back` suffixes. However, could be `pushFront`/`pushBack`/`popFront`/`popBack` to match Ring convention since Linked also has double-ended semantics.

### 5. Protocol Conformance Parity

| Protocol | Linear | Ring | Slab | Linked | Arena | Slots |
|----------|:------:|:----:|:----:|:------:|:-----:|:-----:|
| `Sequence.Drain.Protocol` | base | base | base, Bounded | - | - | - |
| `Sequence.Clearable` | base | base | - | - | - | - |
| `Sequence.Consume.Protocol` | base, Bounded, Inline, Small | base, Bounded, Small | base, Bounded | - | - | - |
| `Sequence.Protocol` | base, Bounded, Inline, Small | base, Bounded, Small | Inline | Inline | - | - |
| `Sequence.Borrowing.Protocol` | base, Bounded, Inline, Small | base, Bounded, Small | - | - | - | - |
| `Swift.Sequence` | base, Bounded | base, Bounded | - | base | - | - |
| `ExpressibleByArrayLiteral` | base | base | - | - | - | - |
| `Equatable` | - | - | - | base | - | - |
| `Hashable` | - | - | - | base | - | - |
| `Span.Protocol` | base, Bounded, Inline, Small | - | - | - | - | - |

**Gaps requiring attention** (where conformance is structurally possible but missing):

| Gap | Assessment |
|-----|------------|
| Slab.Bounded: no `Sequence.Clearable` | **Unjustified** — has `removeAll()`, conformance is trivial |
| Slab.Inline: no `Sequence.Consume.Protocol` | **Unjustified** — other Inline variants have it |
| Slab: no `Sequence.Borrowing.Protocol` | **Partially justified** — bitmap iteration is different from pointer-based. But could provide span-based iteration over occupied ranges |
| Linked: no `Sequence.Drain.Protocol` | **Unjustified** — has `removeFront()`, drain is `while !isEmpty { body(removeFront()!) }` |
| Linked: no `Sequence.Consume.Protocol` | **Unjustified** — structurally identical to drain |
| Linked: no `Sequence.Clearable` | **Unjustified** — has `removeAll()` |
| Linked: no `ExpressibleByArrayLiteral` | Possible but lower priority |
| Arena: no `Sequence.Drain.Protocol` | **Unjustified** — could drain occupied slots |
| Arena: no `Sequence.Consume.Protocol` | **Unjustified** — could consume occupied slots |
| Ring, Linear: no `Equatable`/`Hashable` | Possible where `Element: Equatable`/`Hashable` |
| Ring.Inline: no `Sequence.Consume.Protocol` | **Unjustified** — Linear.Inline has it |

### 6. Property.View Patterns

| Property.View | Linear | Ring | Slab | Linked | Arena | Slots |
|---------------|:------:|:----:|:----:|:------:|:-----:|:-----:|
| `.drain` | base | base | base, Bounded | - | - | - |
| `.forEach` | - | - | Inline | - | base, Bounded | - |
| `.forEach.occupied` | - | - | - | - | base, Bounded | - |

**Gaps**:

| Gap | Assessment |
|-----|------------|
| No `.drain` on Linked, Arena | **Unjustified** if drain protocol is added |
| No `.forEach` on Linear, Ring | Linear/Ring have `forEach` methods but not as Property.View. Arena and Slab.Inline use Property.View. Pattern should be consistent |
| Bounded variants of Linear/Ring: no `.drain` | The base `.drain` Property.View exists but Bounded sub-variants lack it |

### 7. forEach Patterns (~Copyable Borrowing Iteration)

| Pattern | Linear | Ring | Slab | Linked | Arena | Slots |
|---------|--------|------|------|--------|-------|-------|
| `forEach(_:) throws(E)` | base, Bounded, Inline, Small | base, Bounded, Inline, Small | bitmap-based | base, Inline, Small | forEach.occupied via Property.View | N/A |
| Separate file | `+forEach.swift` | `+forEach.swift` | inline in other files | inline in ~Copyable files | `+forEach Property.View.swift` | - |

**Deviations**:
- Linear and Ring have a dedicated `+forEach.swift` file with the same pattern for all sub-variants
- Slab's forEach is embedded in the static ops and drain, not a dedicated pattern
- Linked's forEach is embedded in the `~Copyable.swift` files
- Arena uses `Property.View` pattern instead of direct `forEach` method

**Recommendation**: Standardize on either dedicated `+forEach.swift` files (Linear/Ring pattern) or accept that forEach shape depends on the data structure's iteration model.

### 8. Subscript Patterns

| Pattern | Linear | Ring | Slab | Linked | Arena | Slots |
|---------|:------:|:----:|:----:|:------:|:-----:|:-----:|
| `subscript(index:)` | base, Bounded, Inline, Small | base, Bounded, Inline, Small | - | - | - | - |
| `subscript(metadata:)` | - | - | - | - | - | Y |
| `subscript(payload:)` | - | - | - | - | - | Y |

**Assessment**: Subscripts only make sense for random-access storage (Linear, Ring, Slots). Slab has slot-addressed access but uses `insert/remove/update` semantics instead. Arena uses `pointer(at:)`. These are **justified** structural differences.

### 9. Span / Iterator Patterns

| Pattern | Linear | Ring | Slab | Linked | Arena | Slots |
|---------|:------:|:----:|:----:|:------:|:-----:|:-----:|
| Span-based Iterator | base, Bounded, Inline, Small | base, Bounded, Small | - | - | - | - |
| `Sequence.Borrowing.Protocol` | Y | Y | - | - | - | - |
| Ring.Inline: Span | - | - (missing!) | - | - | - | - |

**Deviation**: Ring.Inline is missing Span/Sequence.Borrowing.Protocol while Ring.Small has it. **Unjustified** gap.

### 10. Consume Patterns

| Variant | ConsumeState class | Pattern |
|---------|-------------------|---------|
| Linear (base) | `ConsumeState` with header + storage + position | while position < count |
| Linear.Bounded | `ConsumeState` with header + storage + position | while position < count |
| Linear.Inline | `ConsumeState` with storage + position + count | moves to heap first |
| Linear.Small | `ConsumeState` with storage + position + count | heap direct or moves to heap |
| Ring (base) | `ConsumeState` with storage + position + count | linearizes to heap first |
| Ring.Bounded | `ConsumeState` with storage + position + count | linearizes to heap first |
| Ring.Small | `ConsumeState` with storage + position + count | delegates to inline/heap |
| Slab (base) | `ConsumeState` with Storage.Heap + Bit.Vector | bitmap `pop.first()` |
| Slab.Bounded | `ConsumeState` with Storage.Heap + Bit.Vector | bitmap `pop.first()` |

**Assessment**: **Structurally consistent** within each discipline. Differences (linear position scan vs bitmap pop) are justified by the data structure.

**Gap**: Ring.Inline has no Consume. Slab.Inline has no Consume. Linked has no Consume. Arena has no Consume.

### 11. Error Type Patterns

| Error case | Used by |
|------------|---------|
| `.capacityExceeded` | Linear.Bounded, Ring.Bounded, Slab.Bounded, Linear.Inline, Ring.Inline, Slab.Inline |
| `.capacityExhausted` | Linked, Linked.Inline |
| `.full` | Arena.Bounded, Arena.Inline |
| `.invalidPosition` | Arena, Arena.Bounded, Arena.Inline |

**Deviation**: Three different terms for "buffer is full":
1. `.capacityExceeded` (Linear, Ring, Slab)
2. `.capacityExhausted` (Linked)
3. `.full` (Arena)

**Assessment**: **Unjustified inconsistency**. These all mean the same thing: "no room for another element." Should converge on a single term. `.capacityExceeded` is used by the majority. `.capacityExhausted` could be argued for pool-based structures (resources are "exhausted") but this is a distinction without a difference. `.full` is too terse.

**Recommendation**: Standardize on `.capacityExceeded` for all variants where the error means "buffer is full."

### 12. Copy-on-Write Support

| Variant | CoW method | Where |
|---------|-----------|-------|
| Linear | None (heap auto-CoW via Storage.Heap) | - |
| Ring | None (same) | - |
| Linked | `makeUnique()` | base (Copyable), Small (Copyable) |
| Arena | `ensureUnique() -> Bool`, `_makeUnique()` | base (Copyable), Bounded (Copyable), Small (Copyable) |
| Slots | `isStorageUnique() -> Bool` | base (Copyable) |

**Deviation**: Two different naming conventions:
- `makeUnique()` (Linked)
- `ensureUnique() -> Bool` (Arena)
- `isStorageUnique() -> Bool` (Slots)

**Assessment**: **Unjustified inconsistency**. `ensureUnique()` is the better API — it returns whether a copy was needed, and the name implies mutation. Should standardize on `ensureUnique() -> Bool`.

### 13. File Organization

Expected file pattern per sub-variant:

| File | Linear | Ring | Slab | Linked | Arena |
|------|:------:|:----:|:----:|:------:|:-----:|
| `{Variant}.swift` | Y | Y | Y | - | Y |
| `{Variant} Copyable.swift` | Y | Y | - | Y | - |
| `{Variant}+Heap ~Copyable.swift` | Y | Y | Y | - | Y |
| `{Variant}+Heap Copyable.swift` | Y | Y | - | - | - |
| `{Variant}.Bounded.swift` | Y | Y | Y | - | Y |
| `{Variant}.Bounded Copyable.swift` | Y | Y | Y | - | - |
| `{Variant}.Bounded+Subscript.swift` | Y | Y | - | - | - |
| `{Variant}.Bounded+Consume.swift` | Y | Y | Y | - | - |
| `{Variant}.Inline.swift` | Y | Y | Y | - | Y |
| `{Variant}.Inline Copyable.swift` | Y | Y | Y | Y | - |
| `{Variant}+Inline ~Copyable.swift` | Y | Y | Y | - | - |
| `{Variant}.Inline+Subscript.swift` | Y | Y | - | - | - |
| `{Variant}.Inline+Consume.swift` | Y | - | - | - | - |
| `{Variant}.Small.swift` | Y | Y | - | - | Y |
| `{Variant}.Small Copyable.swift` | Y | Y | - | Y | Y |
| `{Variant}.Small+Subscript.swift` | Y | Y | - | - | - |
| `{Variant}.Small+Consume.swift` | Y | Y | - | - | - |
| `{Variant}+Subscript.swift` | Y | Y | - | - | - |
| `{Variant}+Span.swift` | Y | Y | - | - | - |
| `{Variant}+forEach.swift` | Y | Y | - | - | - |
| `{Variant}+Consume.swift` | Y | Y | Y | - | - |
| `{Variant}+ExpressibleByArrayLiteral.swift` | Y | Y | - | - | - |
| `{Variant}+Span.Protocol.swift` | Y | - | - | - | - |
| `{Variant}+Checkpoint.swift` | - | Y | - | - | - |
| `{Variant}+Identity.swift` | - | Y | - | - | - |
| `{Variant}.Header.swift` | Y | Y | Y | - | - |
| `Storage.Initialization.swift` | Y | Y | - | - | - |

**Observations**:
- Linear and Ring have the most complete and consistent file organization
- Slab, Linked, and Arena have significant file organization gaps
- Linked embeds Copyable/~Copyable extensions in fewer, larger files instead of the fine-grained split used by Linear and Ring
- Arena has no `+Heap Copyable.swift` — CoW is embedded in the main `.swift` file

### 14. Test Coverage

| Test file | Variant |
|-----------|---------|
| `Buffer.Linear Tests.swift` | Linear base |
| `Buffer.Linear.Static Tests.swift` | Linear static ops |
| `Buffer.Linear.Header Tests.swift` | Linear header |
| `Buffer.Linear.Inline Tests.swift` | Linear.Inline |
| `Buffer.Linear.Small Tests.swift` | Linear.Small |
| `Buffer.Ring Tests.swift` | Ring base |
| `Buffer.Ring.Static Tests.swift` | Ring static ops |
| `Buffer.Ring.Header Tests.swift` | Ring header |
| `Buffer.Ring.Bounded Tests.swift` | Ring.Bounded |
| `Buffer.Ring.Inline Tests.swift` | Ring.Inline |
| `Buffer.Slab.Static Tests.swift` | Slab static ops |
| `Buffer.Slab.Header Tests.swift` | Slab header |
| `Buffer.Slab.Bounded Tests.swift` | Slab.Bounded |
| `Buffer.Slab.Inline Tests.swift` | Slab.Inline |
| `Buffer.Slots Tests.swift` | Slots |
| `Buffer.Arena Tests.swift` | Arena base |

**Missing test files**:

| Missing | Priority |
|---------|----------|
| `Buffer.Linear.Bounded Tests.swift` | High — Bounded is a fundamental sub-variant |
| `Buffer.Ring.Small Tests.swift` | High — other Small variants have tests |
| `Buffer.Slab Tests.swift` (base) | High — only Bounded/Inline are tested |
| `Buffer.Linked Tests.swift` | **Critical** — no tests at all for any Linked variant |
| `Buffer.Linked.Inline Tests.swift` | Critical |
| `Buffer.Linked.Small Tests.swift` | Critical |
| `Buffer.Arena.Bounded Tests.swift` | High |
| `Buffer.Arena.Inline Tests.swift` | High |
| `Buffer.Arena.Small Tests.swift` | High |

---

## Outcome

**Status**: IN_PROGRESS

### Priority 1: Critical Inconsistencies

| # | Issue | Action |
|---|-------|--------|
| P1-1 | Error case naming: `.capacityExhausted` (Linked), `.full` (Arena) | Standardize on `.capacityExceeded` |
| P1-2 | Arena storage field: `_arenaStorage` | Rename to `storage` |
| P1-3 | Linked init pattern: `static func create(capacity:)` | Add `init(minimumCapacity:)` |
| P1-4 | Linear mutation naming: `consumeFront` | Rename to `removeFirst` or adopt push/pop pattern |
| P1-5 | CoW naming: `makeUnique()` vs `ensureUnique()` vs `isStorageUnique()` | Standardize on `ensureUnique() -> Bool` |
| P1-6 | Linear.Bounded/Inline/Small have `Sequence.Drain.Protocol` + `.drain` Property.View but the base Linear only has `Sequence.Drain.Protocol` + `.drain` Property.View declared in different files with inconsistent patterns vs Ring.Bounded which does NOT have `.drain` Property.View | Normalize: all sub-variants that have `Sequence.Drain.Protocol` should also have `.drain` Property.View |

### Priority 2: Missing Protocol Conformances

| # | Issue | Action |
|---|-------|--------|
| P2-1 | Linked: no `Sequence.Drain.Protocol` | Add conformance |
| P2-2 | Linked: no `Sequence.Clearable` | Add conformance |
| P2-3 | Linked: no `Sequence.Consume.Protocol` | Add conformance |
| P2-4 | Slab.Bounded: no `Sequence.Clearable` | Add conformance |
| P2-5 | Arena: no `Sequence.Drain.Protocol` | Add conformance |
| P2-6 | Ring.Inline: no `Sequence.Consume.Protocol` | Add (Linear.Inline has it) |
| P2-7 | Slab.Inline: no `Sequence.Consume.Protocol` | Add |

### Priority 3: Missing Sub-Variants

| # | Issue | Action |
|---|-------|--------|
| P3-1 | Slab: no Small variant | Add `Buffer.Slab.Small` |
| P3-2 | Linked: no Bounded variant | Evaluate — may be warranted for API parity |

### Priority 4: Missing Tests

| # | Issue | Action |
|---|-------|--------|
| P4-1 | Linked: zero test coverage | **Critical** — add comprehensive tests |
| P4-2 | Arena.Bounded/Inline/Small: no tests | Add tests |
| P4-3 | Linear.Bounded: no tests | Add tests |
| P4-4 | Ring.Small: no tests | Add tests |
| P4-5 | Slab base: no tests | Add tests |

### Priority 5: File Organization Normalization

| # | Issue | Action |
|---|-------|--------|
| P5-1 | Linked uses few large files instead of fine-grained split | Refactor to match Linear/Ring file patterns |
| P5-2 | Arena embeds CoW in main `.swift` instead of `Copyable.swift` | Extract to dedicated file |
| P5-3 | forEach patterns inconsistent across variants | Standardize file naming and approach |
| P5-4 | Linear `Copyable.swift` is a mega-file (CoW mutations, subscript, forEach Property.View, peek all in one) while Ring separates these into `+Subscript`, `+Span`, etc. | Normalize: either split Linear or merge Ring |
| P5-5 | `Buffer.Linear.Bounded+Span.Protocol.swift` content is duplicated / overlaps with `Buffer.Linear+Span.swift` | Clarify boundary: Span in Span file, Span.Protocol in its own file |

---

---

## Implementation Plan

### Phase 1: Naming & Convention Alignment (Non-Breaking Internal)

These changes are package-internal (`package` visibility) or rename error cases that are not yet shipped.

**1a. Standardize error case naming**
- `Buffer.Linked.Error.capacityExhausted` -> `.capacityExceeded`
- `Buffer.Linked.Inline.Error.capacityExhausted` -> `.capacityExceeded`
- `Buffer.Arena.Bounded.Error.full` -> `.capacityExceeded`
- `Buffer.Arena.Inline.Error.full` -> `.capacityExceeded`
- Files: `Buffer.swift` (Core), `Buffer.Arena.Bounded.swift`, `Buffer.Arena.Inline.swift`

**1b. Rename Arena storage field**
- `_arenaStorage` -> `storage` across all Arena files
- Files: `Buffer.swift` (Core declarations), `Buffer.Arena.swift`, `Buffer.Arena+Heap ~Copyable.swift`, `Buffer.Arena.Bounded.swift`, `Buffer.Arena.Inline.swift`, `Buffer.Arena.Small.swift`, `Buffer.Arena.Small Copyable.swift`

**1c. Standardize CoW method naming**
- `Buffer.Linked.makeUnique()` -> `ensureUnique() -> Bool`
- `Buffer.Slots.isStorageUnique()` -> `ensureUnique() -> Bool`
- Files: `Buffer.Linked Copyable.swift`, `Buffer.Linked.Small Copyable.swift`, `Buffer.Slots Copyable.swift`

**1d. Standardize Linear mutation naming**
- `Buffer.Linear.consumeFront()` -> `removeFirst()`
- `Buffer.Linear.consumeBack()` (static) -> internal name alignment
- Update all callers: base, Bounded, Inline, Small (both ~Copyable and Copyable files)
- Update test files

**1e. Add `init(minimumCapacity:)` to Linked**
- Add `public init(minimumCapacity: Index<Node>.Count)` that calls `Self.create(capacity:)`
- Keep `create(capacity:)` as package-level implementation detail
- File: `Buffer.Linked ~Copyable.swift`

### Phase 2: Missing Protocol Conformances

Each conformance is small (1-5 lines) and follows established patterns from Linear/Ring.

**2a. Linked: Sequence.Drain.Protocol**
```swift
extension Buffer.Linked: Sequence.Drain.`Protocol` where Element: Copyable {
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let element = removeFront() { body(element) }
    }
}
```
- Add `.drain` Property.View
- File: new `Buffer.Linked+Drain.swift` or add to `Buffer.Linked Copyable.swift`

**2b. Linked: Sequence.Clearable**
```swift
extension Buffer.Linked: Sequence.Clearable where Element: Copyable {}
```
- `removeAll()` already exists
- File: add to `Buffer.Linked Copyable.swift`

**2c. Linked: Sequence.Consume.Protocol**
- Add `ConsumeState` class + `consuming func consume()` following Linear's pattern
- File: new `Buffer.Linked+Consume.swift`

**2d. Slab.Bounded: Sequence.Clearable**
```swift
extension Buffer.Slab.Bounded: Sequence.Clearable {}
```
- `removeAll()` already exists; Slab is never Copyable so constraint is unconditional
- File: add to `Buffer.Slab.Bounded.swift`

**2e. Arena: Sequence.Drain.Protocol**
- Add drain that iterates occupied slots
- File: new `Buffer.Arena+Drain.swift` or add to existing Arena files

**2f. Ring.Inline: Sequence.Consume.Protocol**
- Add `ConsumeState` class + `consume()` following Linear.Inline's pattern (move to heap first)
- File: new `Buffer.Ring.Inline+Consume.swift`

**2g. Slab.Inline: Sequence.Consume.Protocol**
- Add `ConsumeState` class + `consume()` following Slab's pattern (bitmap-based)
- File: new `Buffer.Slab.Inline+Consume.swift`

### Phase 3: Missing Property.View Parity

**3a. Add `.drain` Property.View to all variants with Sequence.Drain.Protocol**
- Ring.Bounded: add `var drain: Property<Sequence.Drain, Self>.View`
- Linked (after 2a): add `.drain` Property.View
- Arena (after 2e): add `.drain` Property.View

**3b. Normalize forEach Property.View**
- Evaluate: should Linear/Ring base types expose `forEach` as Property.View (like Slab.Inline, Arena) or keep it as a direct method? The Property.View pattern is used when the iteration is a "capability" exposed via a named property, while direct `forEach` is for the primary iteration.
- Decision: Keep direct `forEach` for primary iteration (Linear, Ring, Linked), use Property.View for secondary/specialized iteration (Arena `forEach.occupied`, Slab.Inline `forEach`). Document this distinction.

### Phase 4: Critical Test Coverage

**4a. Linked tests (CRITICAL — zero coverage)**
- Create `Buffer.Linked Tests.swift` — base (heap) variant
  - `insertFront`/`insertBack`/`removeFront`/`removeBack`
  - Growth/ensureCapacity
  - forEach/forEachReversed
  - CoW (makeUnique -> ensureUnique after Phase 1)
  - N=1 (singly) vs N=2 (doubly) behavior
- Create `Buffer.Linked.Inline Tests.swift`
  - Same operations, capacity overflow, free-list reuse
- Create `Buffer.Linked.Small Tests.swift`
  - Inline-to-heap spill, dual-dispatch correctness

**4b. Arena sub-variant tests**
- Create `Buffer.Arena.Bounded Tests.swift` — fixed-capacity, `.capacityExceeded` error
- Create `Buffer.Arena.Inline Tests.swift` — inline storage, deinit cleanup
- Create `Buffer.Arena.Small Tests.swift` — inline-to-heap spill, position validity across spill

**4c. Fill remaining gaps**
- Create `Buffer.Linear.Bounded Tests.swift`
- Create `Buffer.Ring.Small Tests.swift`
- Create `Buffer.Slab Tests.swift` (base growable)

### Phase 5: File Organization Normalization

**5a. Split Linear Copyable mega-file**
- Extract CoW subscript to `Buffer.Linear+Subscript Copyable.swift` (parallel to `+Subscript.swift`)
- Extract `forEach` Property.View to `Buffer.Linear+forEach Copyable.swift`
- Keep peek + CoW mutations + ensureUnique in `Buffer.Linear Copyable.swift`

**5b. Refactor Linked to fine-grained files**
- Current: 2 files (`~Copyable.swift`, `Copyable.swift`) contain everything
- Target: Match Linear/Ring pattern with dedicated files for Subscript, forEach, Consume, etc.

**5c. Extract Arena CoW to dedicated file**
- Move `ensureUnique()` / `_makeUnique()` from `Buffer.Arena.swift` to `Buffer.Arena Copyable.swift`

### Phase 6: Future Sub-Variants (Lower Priority)

**6a. Buffer.Slab.Small** — inline bitmap + heap spill
- Follows pattern from Linear.Small, Ring.Small, Arena.Small
- Uses `Buffer.Slab.Inline<wordCount>` + `Buffer.Slab?` spill

**6b. Buffer.Linked.Bounded** — fixed-capacity heap linked list
- Evaluate: is this distinct from base Linked with no growth calls?
- If warranted: add Bounded with `.capacityExceeded` throws on insert

### Execution Order

```
Phase 1 (naming)  ──> Phase 4a (Linked tests)  ──> Phase 2 (conformances)
                  ──> Phase 4b-c (other tests)  ──> Phase 3 (Property.View)
                                                ──> Phase 5 (file reorg)
                                                ──> Phase 6 (new variants)
```

Phase 1 is prerequisite for everything (renames affect all subsequent work).
Phase 4a (Linked tests) should precede Phase 2 Linked conformances so the conformances ship with test coverage.
Phase 5 is independent and can proceed in parallel.
Phase 6 is lowest priority and can be deferred.

## References

- `Buffer.swift` (Core): Lines 1-1156 — all type declarations and conditional conformances
- `Buffer.Linear.swift`: Lines 1-162 — Linear base API
- `Buffer.Ring.swift`: Lines 1-171 — Ring base API
- `Buffer.Slab.swift`: Lines 1-99 — Slab base API
- `Buffer.Arena.swift`: Lines 1-234 — Arena base API + CoW
- `Buffer.Slots.swift`: Lines 1-27 — Slots base API
- Research process skill: [RES-012] Discovery Triggers, [RES-014] Consistency Analysis

---

## Deferral

**Date**: 2026-03-15
**Previous status**: IN_PROGRESS (since 2026-02-11)
**New status**: DEFERRED

**Blocker/Reason**: Comprehensive 6-phase implementation plan is fully specified (naming alignment, missing protocol conformances, Property.View parity, critical test coverage, file organization, future sub-variants). No open analysis questions remain. Deferred because implementation has not started. Phase 1 (naming/convention alignment) is prerequisite for all subsequent phases. Phase 4a (Linked tests -- zero coverage) is critical but blocked on Phase 1 renames.

**Resumption trigger**: When buffer-primitives enters a consistency/polish cycle, or when Linked buffer tests become blocking for a downstream consumer.
