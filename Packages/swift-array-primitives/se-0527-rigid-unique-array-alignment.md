# SE-0527 RigidArray/UniqueArray Alignment

<!--
---
version: 1.6.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
---
-->

## Changelog

- **1.6.0 (2026-04-24)** — [API-NAME-002] compliance: `Array.swapAt(_:_:)` renamed to `Array.swap(at:with:)` across all 4 variants in `swift-array-primitives@c9c1083`. `swapAt` is a compound identifier (camelCased); the labeled form is single-word method name + standard argument labels, and also exactly matches the `Buffer.Linear.swap(at:with:)` API one layer down.
- **1.5.0 (2026-04-24)** — Adds reallocate. Two new commits:
  - `swift-buffer-primitives@2b9d053` — `Buffer.Linear.reallocate(capacity:)` grows OR shrinks by delegating to the existing `_growTo` primitive, gated on a `capacity >= count` precondition. Both ~Copyable and CoW-aware Copyable paths.
  - `swift-array-primitives@b98f721` — `Array.reallocate(capacity:)` thin delegation.
  Only `Array.Bounded`-specific swapAt and freeCapacity remain deferred (tension between type safety and surface completeness; no consumer pressure; decision parked pending a real use case).
- **1.4.0 (2026-04-24)** — Adds clone to the landed set. Two new commits:
  - `swift-buffer-primitives@2cedfdf` — `Buffer.Linear.clone()` and `Buffer.Linear.clone(capacity:)` (Copyable elements). Fresh, independent storage with SE-0527's "just enough capacity" semantics.
  - `swift-array-primitives@a1dd5a3` — `Array.clone()` and `Array.clone(capacity:)` thin delegations.
  Also absorbed `swift-array-primitives@df6da40` (`.pointee → .value` migration on 4 Property.View accessor sites, mirroring buffer-primitives `db34b05`), removing the one pre-existing ecosystem-inconsistency.
  Still deferred (not landed): `reallocate(capacity:)` (needs Buffer-level shrink primitive), and `Array.Bounded`-specific swapAt + freeCapacity (typed-modular `Algebra.Z<N>` index conversion).
- **1.3.0 (2026-04-24)** — First adoption wave landed. Commits across four packages:
  - `swift-cardinal-primitives@3baf384` — `OutputSpan+Cardinal.swift`: `init(buffer:initializedCount:)`, `removeLast(_:)`, `append(repeating:count:)` on `C: Cardinal.Protocol`
  - `swift-ordinal-primitives@36930fd` — `OutputSpan+Ordinal.swift`: `swapAt(_:_:)` on `I, J: Ordinal.Protocol`
  - `swift-buffer-primitives@c3f082c` — `Buffer.Linear.Bounded.init(capacity:initializingWith:)`
  - `swift-array-primitives@2a43b1a` — `Array.Fixed.init(capacity:initializingWith:)` (traps on partial init to preserve the all-initialized invariant)
  - `swift-buffer-primitives@8d45f6f` — `Buffer.Linear` `init(capacity:)`, `append(addingCapacity:)`, `edit(_:)` with ~Copyable and CoW-aware Copyable paths
  - `swift-array-primitives@9e94f27` — `Array` `init(capacity:)`, `append(addingCapacity:)`, `edit(_:)` (thin delegation)
  - `swift-array-primitives@f0cf7f2` — `Array.swapAt(_:_:)` on dynamic, Fixed, Small, Static (Bounded deferred)
  - `swift-array-primitives@aeda9a6` + `@929836b` — `Array.freeCapacity` on dynamic, Fixed, Small, Static (Bounded deferred)
  - `swift-array-primitives@309e773` — `Array.reserveCapacity(_:)` on dynamic
  Still deferred (not landed): `reallocate(capacity:)` (needs Buffer-level shrink primitive), `clone()`/`clone(capacity:)`, `Array.Bounded` swapAt + freeCapacity (typed-modular `Algebra.Z<N>` index conversion). Status remains RECOMMENDATION until SE-0527's review closes (2026-04-27) and a follow-up covers the deferred items.
- **1.2.0 (2026-04-24)** — Tier-correct home decision for stdlib typed-bridge extensions. Verified that `swift-cardinal-primitives` and `swift-ordinal-primitives` already host Standard Library Integration targets with `Span+Cardinal.swift` / `MutableSpan+Cardinal.swift` / `Span+Tagged.Ordinal.swift` / `MutableSpan+Tagged.Ordinal.swift`. Verified that `Index<Element> = Tagged<Element, Ordinal>` (index-primitives/Index.swift:38), so Index-based extensions decompose to Ordinal-based ones at a strictly lower tier. **New OutputSpan overloads split across cardinal-primitives and ordinal-primitives per the lowest-tier-possible rule**. The existing `Swift.Span+extracting.swift` in sequence-primitives is a tier violation (uses only Cardinal/Ordinal concepts but lives higher in the stack); migrate its contents down — Cardinal-using methods to cardinal-primitives, Ordinal-using methods to ordinal-primitives. **No new index-primitives integration target is needed.** Sequence-primitives retains only genuinely sequence-protocol-related stdlib integrations (`Swift.Span.Iterator`, `Swift.Span.Iterator.Batch`, `Sequence.Protocol+Swift.Sequence`).
- **1.1.0 (2026-04-18)** — Substrate-gap correction. The v1.0.0 claim that buffer-level uninitialized-tail affordances "already exist internally" was wrong. Direct inspection of `swift-buffer-primitives` confirms no such API is present: `Buffer.Linear.span` / `.mutableSpan` / `.withUnsafeMutableBufferPointer` all cover only `header.count` initialized elements, and `header`/`storage` have `package` access that does not cross SwiftPM-package boundaries. Added §Substrate prerequisites with verified findings and a phased implementation plan. Affected conclusions: items 1 (OutputSpan init/append) and 3 (`edit { }`) in the "Adopt now" ledger are gated on a prerequisite change in `swift-buffer-primitives`. Item 2 (`swapAt`) and items 4–6 are unaffected.

## Context

[SE-0527 "RigidArray and UniqueArray"](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md) is in Active Review (2026-04-13 → 2026-04-27). It proposes two noncopyable array types for the Swift Standard Library, targeting the same problem space that `swift-array-primitives` already addresses: resizable containers for noncopyable elements with predictable performance.

This research documents what the proposal specifies, what the proposal's prerequisites have already landed in Swift 6.3.1 stdlib, what semantic commitments the proposal makes that differ from our package, and which stdlib affordances we can adopt now without waiting for SE-0527's resolution.

**Trigger**: [RES-012] Discovery — proactive alignment audit prompted by SE-0527 entering Active Review.

**Scope**: Package-specific (swift-array-primitives), with cross-package notes on `swift-sequence-primitives` and `swift-buffer-primitives` where the proposal's prerequisites intersect our stack.

## Question

1. How does SE-0527's design (types, semantics, API shape) compare to `swift-array-primitives`'s five-variant design?
2. Which of SE-0527's prerequisites (`Span`, `MutableSpan`, `OutputSpan`, `InlineArray`, `BorrowingSequence`, `SpanIterator`, `borrow`/`mutate` accessors) are already in the stdlib we build against?
3. Which stdlib affordances should we adopt now in `swift-array-primitives`, and which should we defer until SE-0527 resolves?

## Analysis

### Prior art survey

The proposal explicitly names its predecessors and siblings:

| Artefact | Status in 6.3.1 | Notes |
|---|---|---|
| [SE-0447 Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) | **Landed** | `Span<Element: ~Copyable>`, 915 LoC, `stdlib/public/core/Span/Span.swift`; availability `SwiftCompatibilitySpan 5.0` / originally in CompatibilitySpan module, moved to Swift in 6.2 |
| [SE-0467 MutableSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md) | **Landed** | `MutableSpan<Element: ~Copyable>`, 853 LoC |
| [SE-0485 OutputSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md) | **Landed** | `OutputSpan<Element: ~Copyable>`, 497 LoC, plus `OutputRawSpan`, 375 LoC |
| [SE-0453 InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md) | **Landed** | `InlineArray<let count: Int, Element: ~Copyable>`, 618 LoC, with `[N of Element]` sugar |
| [SE-0516 BorrowingSequence](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md) | **Not landed** | `BorrowingSequence` protocol absent from stdlib; `SpanIterator` absent |
| SE-0527 RigidArray / UniqueArray | Active Review | `RigidArray`, `UniqueArray`, `Containers` module all absent |
| `borrow` / `mutate` accessors (SE-0527 uses them in the subscript declaration) | Experimental | Gated on both `-enable-experimental-feature BorrowAndMutateAccessors` and `-enable-experimental-feature CoroutineAccessors`; parser test at `test/Parse/borrow_and_mutate_accessors.swift` |

Source: `/Users/coen/Developer/swiftlang/swift` on `release/6.3.1` (HEAD `6f265bdcad8`). Verified 2026-04-18.

**Contextualization ([RES-021])**: SE-0516's `BorrowingSequence` is absent upstream but the concept is **not** absent from our ecosystem. `swift-sequence-primitives` defines `Sequence.Borrowing.Protocol` (`Sources/Sequence Primitives Core/Sequence.Borrowing.Protocol.swift`) with `borrowing func makeIterator() -> Iterator`, and `Sequence.Iterator.Protocol` (same directory) with `nextSpan(maximumCount:) -> Swift.Span<Element>` as the sole requirement. `Swift.Span` itself conforms to our iterator protocol via `Swift.Span.Iterator` and `Swift.Span.Iterator.Batch` (`Sources/Sequence Primitives Standard Library Integration/`). The upstream absence is not a gap we suffer from; it is a convergence question.

### Side-by-side comparison

#### Variant coverage

| Concept | SE-0527 | swift-array-primitives | Gap |
|---|---|---|---|
| Growable heap, unconditional ~Copyable | `UniqueArray<Element>` | — | We use conditional-Copyable instead (see below) |
| Growable heap, CoW when Copyable | — (explicitly rejected) | `Array<Element>` | Proposal opts out by design |
| Fixed capacity, variable count, heap, unconditional ~Copyable | `RigidArray<Element>` | — | Closest: `Array.Static<N>` (inline, compile-time N) |
| Fixed count, all-initialized, heap, conditional Copyable with CoW | — | `Array.Fixed` | Only in primitives |
| Inline storage, variable count 0…N, value-generic N | — (delegated to `InlineArray` but that's all-initialized) | `Array.Static<N>` | Only in primitives |
| Inline with heap spillover (SmallVec) | — | `Array.Small<N>` | Only in primitives |
| Compile-time dimensioned, heap, typed-modular index | — | `Array.Bounded<N>` with `Algebra.Z<N>` | Only in primitives |
| Inline, all-initialized, value-generic N | `InlineArray<N, T>` (stdlib, landed) | `Array.Inline<N>` (typealias to `Swift.InlineArray`) | Same type — we already bridge it |

#### API axes

| Axis | SE-0527 | swift-array-primitives |
|---|---|---|
| Copyability | Unconditionally `~Copyable`; `clone()` for explicit deep copy | `~Copyable` declaration + `Copyable where Element: Copyable` extension |
| Value semantics | Consume-on-assignment only | CoW when copyable; move-only otherwise |
| Capacity representation | Runtime (`capacity: Int` on instance), mutable via `reallocate(capacity:)` on Rigid | Runtime on `Array`/`Fixed`; compile-time on `Static<N>`/`Small<N>`/`Bounded<N>` |
| Storage location | Heap only | Heap (`Array`, `Fixed`, `Bounded`), inline (`Static`), inline+spill (`Small`) |
| Index type | `typealias Index = Int` | `Index<Element>` phantom-typed; `Algebra.Z<N>` for `Bounded` |
| Subscript accessors | `borrow` / `mutate` (experimental) | `_read` / `_modify` coroutines satisfying `{ get set }` |
| Naming | Compound type names (`RigidArray`, `UniqueArray`) | Nested `.Nest.Name` per [API-NAME-001/002] |
| Frozen | `@frozen` (layout locked at ABI) | Not frozen |
| Overflow handling | Trap (Rigid); `pushLast` returns item if full | Typed throws (`__ArrayStaticError.overflow`, `Array.Fixed.Error`) per [API-ERR-001] |
| Unification | No protocol across the two types | `__ArrayProtocol` refining `Collection.Bidirectional & ~Copyable` with `associatedtype Element: ~Copyable` |
| Iteration | `BorrowingSequence` + `SpanIterator` (SE-0516 prerequisite, not landed) | `Sequence.Borrowing.Protocol` + `Sequence.Iterator.Protocol.nextSpan` (already in our sequence-primitives) |
| Bulk mutation idiom | `edit { (inout OutputSpan<Element>) in }`, `append(addingCount:initializingWith:)`, `insert(addingCount:at:initializingWith:)`, `replace(removing:addingCount:...)` | No OutputSpan-shaped APIs yet; single-element `append`/`insert`/`remove` and property views |
| Bulk copy/move | `append(copying: {Span, Sequence, Collection, UnsafeBufferPointer})`, `append(moving: {UnsafeMutableBufferPointer, OutputSpan})` | Not broadly present |
| `swapAt` | Present | Absent (flagged in operations audit) |
| `reallocate(capacity:)` / `reserveCapacity(_:)` | Present | Absent on `Array` surface |
| `freeCapacity` | Present | Absent |
| `clone()` / `clone(capacity:)` | Present (Copyable elements only) | Absent |
| Property views (`.forEach { }`, `.drain { }`, `.remove.last()`) | Not proposed | Present via `property-primitives` |
| `Sendable` | Checked: `Sendable where Element: Sendable & ~Copyable` | `@unchecked Sendable where Element: Sendable` |

### Design philosophy divergence

Two choices are **load-bearing and asymmetric** between the proposals:

**(a) Conditional Copyable vs. unconditional ~Copyable.** SE-0527's Motivation §2 (lines 41–68 of the proposal) argues that runtime copyability checks in mutation paths would undermine performance-critical use cases, and that conditional CoW is "wholly impractical." Our package's `Research/_Package-Insights.md` documents the opposite bet: the module-boundary pattern (core vs. variant modules bridged by `package` access) prevents constraint poisoning, making conditional Copyable practical without per-mutation dispatch. These are not reconcilable — they encode different priorities.

**(b) Int indices vs. phantom-typed indices.** SE-0527 uses `typealias Index = Int` for directness and stdlib affinity. Our `Index<Element>` (from `swift-index-primitives`) prevents cross-collection index confusion at compile time. `Array.Bounded<N>` goes further: `Algebra.Z<N>` encodes the dimension in the index type, so subscript access after construction needs no runtime bounds check. For stdlib's target audience (systems programmers), Int is correct. For our ecosystem (composable primitives at all layers), phantom types are correct.

Neither divergence is resolvable by aligning; both are intentional.

### Ecosystem cross-check

- **`swift-sequence-primitives`** already has:
  - `Sequence.Borrowing.Protocol` — `borrowing func makeIterator() -> Iterator` (our BorrowingSequence analog)
  - `Sequence.Iterator.Protocol` — `nextSpan(maximumCount:) -> Swift.Span<Element>` as sole requirement (our SpanIterator analog, but batch-based rather than element-based)
  - `Swift.Span.Iterator` / `Swift.Span.Iterator.Batch` conformances in `Sequence Primitives Standard Library Integration`
- **`swift-collection-primitives`** has no Span/OutputSpan/BorrowingSequence adoption. The Collection.Protocol hierarchy presently does not mention Span.
- **`swift-buffer-primitives`** provides `Buffer<Element>.Linear`, `Buffer<Element>.Linear.Bounded`, `Buffer<Element>.Linear.Inline<N>`, `Buffer<Element>.Linear.Small<N>` — the storage substrates that underpin each Array variant. OutputSpan adoption at the Array level requires corresponding buffer-level affordances for uninitialized-tail initialization. **These do not yet exist** — see §Substrate prerequisites below. `[Corrected in v1.1.0; v1.0.0 incorrectly claimed these "already exist internally".]`

### Substrate prerequisites

**Added in v1.1.0 after direct substrate verification.**

Arrays delegate storage to `Buffer.Linear` (growable heap), `Buffer.Linear.Bounded` (fixed-capacity heap), `Buffer.Linear.Inline<N>` (inline storage), and `Buffer.Linear.Small<N>` (inline + heap spillover). The question is whether any of these expose an uninitialized-tail affordance sufficient to build an `OutputSpan<Element>` over the `[count..<capacity)` region.

**Inspection findings (2026-04-18)**:

| Affordance on `Buffer.Linear` | Exists? | Coverage | Suitable for OutputSpan? |
|---|---|---|---|
| `span: Span<Element>` | Yes | `0..<count` (initialized only) | No — cannot write past count |
| `mutableSpan: MutableSpan<Element>` | Yes | `0..<count` | No — same reason |
| `withUnsafeMutableBufferPointer(_:)` | Yes, **Copyable only** | `0..<count` | No — wrong range, wrong copyability gate |
| `reserveCapacity(_:)` | Yes (public, CoW-aware) | — | Useful as precondition; does not expose memory |
| Direct access to `storage: Storage<Element>.Heap` | `@usableFromInline package` | — | `package` access does not cross SwiftPM package boundaries; array-primitives cannot reach `_buffer.storage` |
| Any method named `*Uninitialized*`, `*initializingWith*`, `withOutputSpan*` | **No** | — | No such API exists |

`Storage.Heap.pointer(at:)` returns `UnsafeMutablePointer<Element>` (public), which *would* be sufficient — but `storage` itself is not reachable from array-primitives. The buffer's header fields (`header.count`, `header.capacity`) are also `@usableFromInline package` — not public — so even indirect pointer arithmetic from a consumer module is blocked.

**Conclusion**: OutputSpan adoption in `swift-array-primitives` is gated on a **prerequisite addition in `swift-buffer-primitives`**. The substrate needs at least:

```swift
extension Buffer.Linear where Element: ~Copyable {
    /// Construct with `capacity` slots, then run the initializer with an
    /// OutputSpan over the buffer. The resulting count is whatever the
    /// OutputSpan contains when the closure returns (or throws).
    public init<E: Error>(
        capacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E)

    /// Ensure at least `addingCapacity` free slots beyond current count
    /// (growing + CoW as needed), then run the initializer with an OutputSpan
    /// over the uninitialized tail. On return (or throw), any initialized
    /// elements are committed to the buffer's count.
    public mutating func append<E: Error>(
        addingCapacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E)
}

extension Buffer.Linear.Bounded where Element: ~Copyable {
    public init<E: Error>(
        capacity: Index<Element>.Count,
        initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
    ) throws(E)
}
```

Plus corresponding additions on `Buffer.Linear.Small<N>` and `Buffer.Linear.Inline<N>` if we want `Array.Small` and `Array.Static` to have the same shape — lower priority, can land in a later wave.

**Reference implementation**: `Swift.Array.init(capacity:initializingWith:)` at `stdlib/public/core/Array.swift:1633` and `Swift.Array.append(addingCapacity:initializingWith:)` at `:1664` demonstrate the exact throw-safety pattern: `defer { let count = span.finalize(for: buffer); span = OutputSpan(); commit(count) }`. The `finalize` + reset-to-empty-span dance ensures the OutputSpan's deinit does not double-deinitialize elements that have already been committed to the buffer. On throw, `defer` runs with whatever count the span had at throw time, so partial initialization is preserved (matching SE-0527's semantics verbatim).

**Cross-package access path**: `OutputSpan.init(buffer: UnsafeMutableBufferPointer<Element>, initializedCount: Int)` is `public @unsafe @_alwaysEmitIntoClient` (OutputSpan.swift:136). Our `Package.swift` has `.strictMemorySafety()` enabled, so call sites will need explicit `unsafe` expressions, consistent with existing uses in `Buffer.Linear+Span.Protocol.swift`.

### Adoption gating

| Affordance | Landed? | Availability floor | Adopt now? |
|---|---|---|---|
| `Span<Element>` | Yes | `SwiftCompatibilitySpan 5.0` | Already in use on all variants |
| `MutableSpan<Element>` | Yes | Same | Already in use |
| `OutputSpan<Element>` | Yes | Same | **Yes, but gated** — stdlib affordance is usable; array-level adoption requires prerequisite buffer-primitives additions (§Substrate prerequisites) |
| `Array.init(capacity:initializingWith: (inout OutputSpan<Element>) throws(E) -> Void)` on `Swift.Array` | Yes | Same | Reference implementation for our own `init` |
| `Array.append(addingCapacity:initializingWith:)` on `Swift.Array` | Yes | Same | Reference implementation for our own `append` |
| `InlineArray<N, T>` | Yes | `SwiftStdlib 6.2` | Already wrapped as `Array.Inline<N>` |
| `BorrowingSequence` protocol | No | n/a | Defer — we have `Sequence.Borrowing.Protocol` ecosystem-side |
| `SpanIterator` | No | n/a | Defer — we have `Sequence.Iterator.Protocol` ecosystem-side |
| `borrow` / `mutate` accessor syntax | Experimental only | n/a | Defer — keep `_read`/`_modify` |
| `Containers` module | No | n/a | Defer |
| `RigidArray` / `UniqueArray` | No | n/a | Defer — do not add mirror types |
| `swapAt(_:_:)` | n/a (proposed for stdlib arrays, trivial for us) | n/a | **Yes** — add to our operations |
| `clone()` / `clone(capacity:)` | n/a | n/a | Consider — see Outcome below |
| `freeCapacity`, `reserveCapacity(_:)`, `reallocate(capacity:)` | n/a | n/a | Consider — see Outcome below |

Platform floor in `Package.swift`: `.macOS(.v26)`, `.iOS(.v26)`, `.tvOS(.v26)`, `.watchOS(.v26)`, `.visionOS(.v26)`. All landed affordances (6.2+) are strictly below the floor.

## Outcome

**Status**: RECOMMENDATION

### Adopt now (no waiting)

1. **Add `OutputSpan`-shaped initializers and bulk appenders to each Array variant.** The `Swift.Array.init(capacity:initializingWith:)` and `Swift.Array.append(addingCapacity:initializingWith:)` signatures are the canonical shape. Mirror them on `Array`, `Array.Fixed`, `Array.Static<N>`, `Array.Small<N>`, `Array.Bounded<N>`:

   ```swift
   public init<E: Error>(
       capacity: Index.Count,
       initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
   ) throws(E)

   public mutating func append<E: Error>(
       addingCapacity: Index.Count,
       initializingWith initializer: (inout OutputSpan<Element>) throws(E) -> Void
   ) throws(E)
   ```

   Rationale: unlocks building `~Copyable` arrays without temporary copies, matches the idiom developers will learn from stdlib and SE-0527, reuses `OutputSpan`'s ownership tracking so partial-init + throw leaves the array in a consistent state.

   **Gated on a prerequisite addition in `swift-buffer-primitives`** — see §Substrate prerequisites. The array-primitives layer is a thin delegation; the real work is the buffer-primitives API for exposing the uninitialized tail.

2. **Add `swapAt(_:_:)` to the `Array.Protocol` surface.** Flagged as absent in `array-operations-audit.md`. Trivial, O(1), applicable to all variants. **Not gated** — implementable today without buffer-primitives changes (the underlying `Buffer.Linear.swap(at:with:)` already exists).

3. **Add `edit { (inout OutputSpan<Element>) in ... }` on `Array` (and variants where meaningful).** This is SE-0527's general-purpose mutation escape hatch. Verified: no name collision anywhere in `swift-primitives` today (grep 2026-04-18). **Gated on the same substrate prerequisite as item 1** — `edit` needs an OutputSpan over the full `[0..<capacity)` region, which requires the same buffer-level affordance.

### Adopt conservatively (alignment-driven, no breaking change)

4. **Add `freeCapacity: Index.Count`.** Natural companion to existing `capacity` and `isFull`. Minimal surface cost, high call-site expressiveness.

5. **Add `reserveCapacity(_ n: Index.Count)` and `reallocate(capacity: Index.Count)` on `Array` and `Array.Fixed`.** Explicit capacity management without implicit growth. `Array.Fixed.reallocate(capacity:)` is the coherent path to "grow this fixed array" that doesn't currently exist.

6. **Add `clone()` / `clone(capacity:)` on variants, constrained to `Element: Copyable`.** Explicit deep copy is useful for our users too, and gives us an entry point that could later generalize to a `Cloneable` protocol if one emerges from SE-0527's follow-up work.

### Defer

7. **Do not add `Array.Rigid` / `Array.Unique` as mirror types.** SE-0527 is in Active Review and may change. If it ships in Swift 6.4 / 6.5, we'll address integration as a separate research question — probably as conversion initializers, not sibling types, since the semantic split (conditional-Copyable-with-CoW vs. unconditional-~Copyable) is exactly what distinguishes our `Array<T>` from stdlib's proposed `UniqueArray<T>`.

8. **Do not adopt `borrow` / `mutate` accessor syntax.** Gated on two experimental features simultaneously; not production-ready. Keep `_read`/`_modify` coroutines which satisfy protocol `{ get set }` requirements.

9. **Do not introduce a `BorrowingSequence` equivalent.** We already have `Sequence.Borrowing.Protocol` upstream in `swift-sequence-primitives`. When/if SE-0516 ships, the bridging question is how `Sequence.Borrowing.Protocol` relates to stdlib `BorrowingSequence` — addressed separately in a sequence-primitives research note.

10. **Do not alter the conditional Copyable / CoW design of `Array<T>`, `Array.Fixed`, `Array.Bounded`.** SE-0527 explicitly rejects this model for stdlib; we explicitly embrace it (see `_Package-Insights.md`). Divergence is intentional.

### Implementation path

**Revised in v1.1.0** to reflect the substrate gap.

**Phase 0 — `swift-buffer-primitives`** (prerequisite for items 1 and 3):

1. `Buffer.Linear.init(capacity:initializingWith:)` (~Copyable path, fresh construction over new heap allocation)
2. `Buffer.Linear.append(addingCapacity:initializingWith:)` (growable path; invokes `ensureUnique` + `_growTo` as needed, then builds OutputSpan over `[count..<capacity)`)
3. `Buffer.Linear.Bounded.init(capacity:initializingWith:)` (fixed-capacity heap)
4. Tests exercising: `~Copyable` elements, Copyable-with-CoW elements, throwing closure preserving partial-init, empty-closure noop
5. (Deferred to a later wave) Same signatures on `Buffer.Linear.Small<N>` and `Buffer.Linear.Inline<N>` to unblock `Array.Small` / `Array.Static`

**Phase 1 — `swift-array-primitives`** (thin delegation over Phase 0):

6. `Array.init(capacity:initializingWith:)` and `Array.append(addingCapacity:initializingWith:)` → delegate to `Buffer.Linear`
7. `Array.Fixed.init(capacity:initializingWith:)` → delegate to `Buffer.Linear.Bounded`
8. `Array.edit { }` → delegate via a buffer-level helper that yields an OutputSpan over the whole `[0..<capacity)` region
9. `Array.Protocol.swapAt(_:_:)` — independent of Phase 0; can land standalone at any time
10. Tests mirroring Phase 0 test matrix at the Array level

**Phase 2 — follow-on items (independent)**:

Work items 4–6 from the Outcome ledger (`freeCapacity`, `reserveCapacity`, `reallocate`, `clone`, `clone(capacity:)`) can land incrementally as each becomes needed; they do not share the OutputSpan substrate dependency.

**Recommended first increment** (after substrate verification): Narrow to `Array.Fixed` + `Buffer.Linear.Bounded` — simpler semantics (fixed capacity, no growth, no CoW interplay on the init path) validates the vertical end-to-end before attempting the dynamic-growth `Array` path. See §Tracking SE-0527 for sequencing relative to the proposal's review outcome.

Items 7–10 are posture statements — no work required, but worth linking from the operations audit.

### Tracking SE-0527

- Review window closes 2026-04-27. Outcome (accepted / returned / rejected) should be propagated into this document as a changelog entry with status updated to DECISION (if accepted and adoption plan finalized) or remain RECOMMENDATION (if returned for revision).
- If accepted: spawn a follow-up research document covering stdlib conversion paths (`Array<T> ↔ UniqueArray<T>`, `Array.Fixed ↔ RigidArray<T>`) and any naming alignment for shared operations (`swapAt`, `clone`).
- If returned for revision: wait for the next revision to converge before adopting any SE-0527-specific idioms beyond the OutputSpan-based ones (which are independently motivated).

## References

### Swift Evolution proposals

- [SE-0527 RigidArray and UniqueArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md) — Active Review 2026-04-13 → 2026-04-27
- [SE-0447 Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) — Accepted
- [SE-0467 MutableSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md) — Accepted
- [SE-0485 OutputSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md) — Accepted
- [SE-0453 InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md) — Accepted
- [SE-0516 BorrowingSequence](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md)

### swiftlang/swift (release/6.3.1, HEAD 6f265bdcad8)

- `stdlib/public/core/Span/OutputSpan.swift` (497 LoC)
- `stdlib/public/core/Span/Span.swift` (915 LoC)
- `stdlib/public/core/Span/MutableSpan.swift` (853 LoC)
- `stdlib/public/core/InlineArray.swift` (618 LoC)
- `stdlib/public/core/Array.swift:1612–1695` — OutputSpan-based `init` and `append`
- `test/Parse/borrow_and_mutate_accessors.swift` — experimental accessor grammar

### swift-primitives ecosystem

- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/_Package-Insights.md` — module-boundary pattern for conditional Copyable
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-operations-audit.md` — missing operations ledger
- `/Users/coen/Developer/swift-primitives/swift-array-primitives/Research/array-protocol-unification.md` — `__ArrayProtocol` design
- `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Borrowing.Protocol.swift` — ecosystem BorrowingSequence analog
- `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Iterator.Protocol.swift` — `nextSpan(maximumCount:)` span-based iterator
- `/Users/coen/Developer/swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Standard Library Integration/Swift.Span.Iterator.swift` — Swift.Span conformance to our iterator protocol
