# Checkpoint Ordering Design

<!--
---
version: 1.0.0
last_updated: 2026-02-12
status: RECOMMENDATION
---
-->

## Context

During an audit of Buffer Primitives Core, the `Comparable` conformance on `Buffer.Ring.Checkpoint` and `Buffer.Ring.Small.Checkpoint` was flagged as violating the strict total order required by `Swift.Comparable`.

The violation: `<` considers only `count` (inverted — higher count sorts first), while the auto-synthesized `==` considers all stored properties (`head` + `count`, or `head` + `count` + `wasOnHeap`). This breaks trichotomy: two checkpoints with the same count but different heads are incomparable under `<` yet unequal under `==`.

The same pattern propagates to `Parser.Tracked.Checkpoint`, which delegates `<` to `baseCheckpoint <` but auto-synthesizes `==` from `baseCheckpoint` + `trackedOffset`.

Comparable is structurally required by `Input.Protocol`:

```swift
associatedtype Checkpoint: Sendable & Comparable
var checkpointRange: ClosedRange<Checkpoint> { get }
```

`ClosedRange<Bound: Comparable>` requires the conformance, and `checkpointRange.contains(checkpoint)` is the checkpoint validation mechanism across the input/parser/queue stack.

## Question

What is the principally correct approach for checkpoint ordering semantics — given that (a) `Swift.Comparable` requires strict total order, (b) `ClosedRange<Checkpoint>` requires `Comparable`, and (c) the ordering must express a valid backtracking window?

## Analysis

### Checkpoint semantics

A checkpoint is a cursor snapshot enabling save/restore:

| Type | Stored Fields | Restoration Behavior |
|------|---------------|---------------------|
| `Ring.Checkpoint` | `head`, `count` | Sets `header.head`, `header.count`, syncs `storage.initialization` |
| `Ring.Small.Checkpoint` | `head`, `count`, `wasOnHeap` | Routes to inline or heap based on *current* mode (not checkpoint mode) |
| `Parser.Tracked.Checkpoint` | `baseCheckpoint`, `trackedOffset` | Restores base, sets tracked offset |

**Key observation**: Within a linear consumption sequence on a single buffer, `count` uniquely determines the restoration state. The head advances deterministically as elements are consumed from the front. Two valid checkpoints with the same count necessarily have the same head — any checkpoint with a different head for the same count is either invalid or from a different buffer instance.

For `Small.Checkpoint`, `wasOnHeap` records the buffer mode at checkpoint time. Restoration routes based on *current* mode, not checkpoint mode. The field is diagnostic metadata, not restoration-relevant state.

For `Parser.Tracked.Checkpoint`, `trackedOffset` is uniquely determined by `baseCheckpoint` within normal operation — each advance increments both.

**Conclusion**: Within the valid domain, the ordering-relevant field (`count` or `baseCheckpoint`) uniquely determines all other fields. Equality and ordering on that field alone satisfy trichotomy without losing information.

### Why inverted ordering

The current `<` uses `lhs.count > rhs.count` — higher count sorts first. This inversion makes `ClosedRange<Checkpoint>` express the valid backtracking window naturally:

```
Save at count=10, consume 3 elements, now at count=7.

ClosedRange: checkpoint(count=10) ... checkpoint(count=7)
                  lowerBound                 upperBound

Any valid checkpoint has 7 ≤ count ≤ 10, which is:
  checkpoint(count=10) ≤ checkpoint ≤ checkpoint(count=7)

With inverted ordering: (10 > 10)=false, so 10 ≤ 10 ✓
                        (7 > 7)=false,  so 7 ≤ 7  ✓
                        (8 > 10)=false, so 8 ≤ 10 ✓ (8 after 10)
                        (7 > 8)=false,  so 8 ≤ 7  ✓ (8 before 7)
```

The inversion maps "earlier in consumption" to "lower bound" and "current position" to "upper bound." `ClosedRange.contains` correctly identifies all intermediate checkpoints as valid.

Without inversion, `lowerBound` would be the current position (fewest elements) and `upperBound` would be the earliest checkpoint (most elements). This reverses the natural reading direction — "lower" would mean "more consumed" and "upper" would mean "less consumed." The inversion preserves the intuition that `lowerBound` is the earliest (furthest back) point.

### Option A: Explicit `==` matching `<` (count-only)

Provide an explicit `==` that considers only `count`, matching `<`:

```swift
public struct Checkpoint: Copyable, Sendable, Comparable {
    @usableFromInline
    package let head: Index<Element>

    @usableFromInline
    package let count: Index<Element>.Count

    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.count == rhs.count
    }

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.count > rhs.count
    }
}
```

**Trichotomy**: For any `a`, `b` — exactly one of `a.count > b.count` (a < b), `a.count == b.count` (a == b), `a.count < b.count` (b < a) holds. Satisfied.

**`ClosedRange.contains`**: Works correctly. No change to `Input.Protocol`, `checkpointRange`, or any consumer.

**Semantic**: `==` means "same position in the consumption sequence" (ordering equivalence), not "identical cursor snapshot" (structural identity). Within the valid domain these coincide, so no information is lost.

**Trade-off**: `head` is no longer visible to `==`. Code that pattern-matches on checkpoint equality to detect identical cursor states would need to compare heads explicitly. In practice, no current code does this — checkpoints are compared only for range containment.

**Hashable implication**: If `Hashable` is added later, the hash MUST use only `count` (since `a == b` implies same hash). This is consistent and correct.

### Option B: Lexicographic ordering on all fields

Make both `<` and `==` consider all fields:

```swift
public static func < (lhs: Self, rhs: Self) -> Bool {
    Comparison(comparing: lhs.count, to: rhs.count)
        .then(Comparison(comparing: lhs.head, to: rhs.head))
        .isGreater  // inverted: higher count = "less than"
}
```

**Trichotomy**: Satisfied — lexicographic ordering is a strict total order.

**Problem**: `checkpointRange` would need to account for all valid (head, count) combinations. Two checkpoints with the same count but different heads are no longer equivalent — the range might not contain valid intermediate states with different heads. The `ClosedRange` model breaks because the valid set is not a contiguous interval in (count, head) space — it's a diagonal line (each count has exactly one valid head).

**Verdict**: Rejected. Lexicographic ordering is mathematically clean but incompatible with the `ClosedRange<Checkpoint>` validation model.

### Option C: Remove Comparable, use Comparison.Protocol

Replace `Swift.Comparable` with `Comparison.Protocol` + `Equation.Protocol`, and replace `ClosedRange<Checkpoint>` with a custom validation mechanism.

**Impact**:
- `Input.Protocol` changes: `associatedtype Checkpoint: Sendable & Comparable` → requires new constraint
- `ClosedRange<Checkpoint>` eliminated — need alternative for `checkpointRange`
- All `Input.Protocol` conformers updated (Queue, Input.Buffer, Input.Slice, Parser.Tracked, Binary.Bytes.Input)
- Parser Machine memoization tables updated (`where Checkpoint: Comparable`)

**Verdict**: Rejected. Massive cross-cutting change for no semantic benefit. The fundamental issue (count-only ordering with `ClosedRange` validation) is correct; it just needs the `==` to match the `<`.

### Option D: Remove Comparable entirely, named methods only

Remove `Comparable`. Provide `func isDeeper(than:) -> Bool`. Replace `ClosedRange<Checkpoint>` with explicit validation.

**Impact**: Same as Option C — requires rewriting `Input.Protocol` and all conformers.

**Verdict**: Rejected for the same reason. The `ClosedRange` model is the right abstraction.

### Option E: Newtype the ordering key

Extract the ordering-relevant field into a separate type:

```swift
public struct Checkpoint: Copyable, Sendable {
    public let position: Position  // Comparable wrapper around count
    package let head: Index<Element>

    public struct Position: Copyable, Sendable, Comparable {
        let count: Index<Element>.Count
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.count > rhs.count
        }
    }
}
```

Then `Input.Protocol` uses `Checkpoint.Position` as the range key.

**Problem**: Changes `associatedtype Checkpoint` semantics, requires `checkpoint.position` at every comparison site, splits the type into two for no user benefit.

**Verdict**: Over-engineered. The simple explicit `==` (Option A) achieves the same correctness with zero API disruption.

### Prior art

**Swift `String.Index`**: Comparable based on encoded offset only. The index also carries transcoding state, but ordering/equality use position alone. Same pattern — ordering-relevant field determines the total order; auxiliary data is carried for operations.

**Rust `std::io::SeekFrom` / cursor patterns**: Position-based ordering. Auxiliary state (whence, buffer state) is not part of `Ord`.

**C++ `std::string::iterator`**: `operator<` compares position in the underlying buffer. Iterator validity (dangling, invalidated) is not encoded in ordering.

**Haskell `Data.Sequence` finger tree offsets**: Ordering by position in the sequence. Annotations (measures) are monoidally combined but not part of `Ord`.

### Theoretical grounding

The checkpoint ordering is a **quotient order**: the total order on `Index<Element>.Count` is lifted to `Checkpoint` via the projection `π: Checkpoint → Count`. The equivalence relation `a ~ b ⟺ π(a) = π(b)` partitions checkpoints by count. Within the valid domain, each equivalence class has exactly one member (count uniquely determines head), so the quotient is injective and the ordering is well-defined.

The inversion (`>` instead of `<` on counts) is an **order-reversing isomorphism** (order dual). This is mathematically clean — the dual of a total order is a total order.

The `ClosedRange<Checkpoint>` model requires the valid checkpoint set to be an **interval** in the ordering. Under the inverted count ordering, the valid set {count | current ≤ count ≤ saved} maps to the interval [checkpoint(saved) ... checkpoint(current)] — a contiguous range. This holds because consumption is monotonically decreasing in count.

## Outcome

**Status**: RECOMMENDATION

**Recommendation**: Option A — Provide explicit `==` matching `<` semantics (count-only).

### Changes required

**Buffer Primitives Core** (`Buffer.swift`):

1. `Buffer.Ring.Checkpoint` (line 164): Add explicit `==` comparing `count` only.
2. `Buffer.Ring.Small.Checkpoint` (line 134): Add explicit `==` comparing `count` only.
3. Document the ordering semantic on both types: "Ordered by consumption position. Higher count (earlier in consumption) sorts first, enabling `ClosedRange<Checkpoint>` to express valid backtracking windows."

**Parser Primitives** (`Parser.Tracked.swift`):

4. `Parser.Tracked.Checkpoint` (line 86): Add explicit `==` comparing `baseCheckpoint` only.

### Rationale

- Restores trichotomy with zero API disruption
- No changes to `Input.Protocol`, `ClosedRange<Checkpoint>`, or any consumer
- Within the valid domain, count-only equality is semantically correct (count uniquely determines restoration state)
- The inverted ordering is principled — it makes `ClosedRange` express the valid backtracking window naturally
- Matches prior art (Swift String.Index, Rust cursor patterns)
- Theoretically grounded as a quotient order with injective projection

### Not recommended

- Removing `Comparable` (Options C, D): Too disruptive for the same semantic result
- Lexicographic ordering (Option B): Incompatible with `ClosedRange` validation model
- Newtyping (Option E): Over-engineered for a single-field projection

## References

- `Buffer.swift:134-181` — Current Checkpoint declarations
- `Parser.Tracked.swift:86-103` — Parser Tracked Checkpoint
- `Input.Protocol.swift:66-121` — `associatedtype Checkpoint: Sendable & Comparable`, `checkpointRange`, `isValid`
- `Buffer.Ring+Checkpoint.swift` — Checkpoint save/restore operations
- `Queue+Input.Protocol.swift:54-68` — Queue checkpoint range (degenerate)
- `Input.Buffer+Input.Protocol.swift:55-57` — Input.Buffer checkpoint range (position-based)
- Comparison Primitives Design (`swift-comparison-primitives/Research/Comparison Primitives Design.md`) — Trichotomy, monoid structure
- Ordering Primitives Design (`swift-ordering-primitives/Research/Ordering Primitives Design.md`) — Projection pattern
- `buffer-ring-consumer-api-boundary.md` — A5 Checkpoint API design (IN_PROGRESS)
