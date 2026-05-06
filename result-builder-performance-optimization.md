# Result-Builder Performance Optimization

<!--
---
version: 2.0.0
last_updated: 2026-05-06
status: DECISION
tier: 2
scope: cross-package
---
-->

> **Update 2026-05-06 (v2.0.0)**: This document originally recommended Option E (`Repeat<S, Element>` helper type). Validation experiments showed Option E works but introduces a new type. The user's preference was to AVOID a new type in standard-library-extensions. A bare-`Sequence` overload (renamed Option G in `Experiments/result-builder-perf-repeat/`) was prototyped and benchmarks at **0.13× of imperative for N=100** and **0.17× for N=1000** — i.e., the builder is 5–7× FASTER than imperative for direct sequences. **Decision: ship Option G + Option B (consume `buildPartialBlock`), do not ship Option E.** See *Final Decision* section at end.

## Context

The 2026-05-06 result-builder ecosystem rollout (Round-1 + Round-2; 28 builders + variant convenience inits across 10 packages) ships the institute's declarative-construction surface. The accompanying performance experiment (`swift-institute/Experiments/result-builder-perf/`) validated that result-builder construction is on par with or better than imperative `var x = T(); x.append(...)` patterns for the canonical use case (≤ 10 literal statements) but is significantly slower for for-loop builder bodies:

| Case | Imperative | Builder | Ratio | Verdict |
|------|------------|---------|-------|---------|
| Swift.Array N=3 (literals) | 80 ns | 78 ns | 0.98× | BUILDER FASTER |
| Heap N=10 (bulk-build) | 8710 ns | 4767 ns | 0.55× | BUILDER FASTER |
| Array<Int>/Buffer.Linear/Stack/Queue N=3 (literals) | ~320 ns | ~430 ns | 1.27–1.40× | ON PAR |
| Swift.Array N=100 (for-loop) | 341 ns | 4007 ns | **11.74×** | SLOWER |
| Swift.Array N=1000 (for-loop) | 938 ns | 36577 ns | **39.01×** | SLOWER |
| Bitset N=10 (for-loop) | 67 ns | 708 ns | **10.59×** | SLOWER |

The user's acceptance criterion is *"on par with each other, or result-builder should be better"*; the strict reading **fails** for for-loop bodies. The user requested research on whether on-par performance is achievable for for-loops.

## Question

**Can the institute's result-builder pattern provide on-par-or-better performance for builder bodies that include `for` loops, particularly at moderate-to-large N (100–10000)? If yes, what shape; if no, what is the limiting factor and what alternative API surface should the ecosystem ship?**

Sub-questions:

1. What exactly causes the for-loop slowdown? (Build* call structure, allocation pattern, transform shape.)
2. Can the Round-1 builder shape be modified in-place to recover on-par performance?
3. What ecosystem infrastructure (sequence-primitives, buffer-primitives) can be reused?
4. Are there design-level alternatives (different intermediate type, ForEach-helper, lazy chain) that change the cost profile?
5. What is the recommendation, and what residual constraints remain?

## Analysis

### Step 1: Root-Cause Characterization

The standard result-builder transform for `for x in seq { body }` (per [SE-0289](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md)):

```swift
// User writes:
Array {
    for i in 0..<100 {
        i
    }
}

// Compiler synthesizes (roughly):
{
    var partials: [Component] = []
    for i in 0..<100 {
        partials.append(Array.Builder.buildExpression(i))   // per-iteration call
    }
    return Array.Builder.buildArray(partials)               // final flatten
}
```

Where `Component` is the type returned by `buildExpression`. For Array.Builder, `Component = [Element]`. So:

- **Per iteration**: `buildExpression(i) → [i]` — one `[Element]` allocation (heap, ~50–100 ns on macOS arm64). For N=100 that's ~100 small allocations.
- **Per loop**: `partials: [[Element]]` is itself an array of [Element] — one allocation for partials backing storage with growth.
- **Final**: `buildArray(partials).flatMap { $0 }` — one allocation for the flattened result of size N.

Total: O(N) heap allocations, O(N) total elements moved. The dominant cost at N=100–1000 is the **per-iteration `[Element]` allocation**, not the buildPartialBlock chain (since for-loops bypass buildPartialBlock and route through buildArray).

[Verified: 2026-05-06] empirically: Swift.Array N=100 for-loop = 4007 ns ÷ 100 iter ≈ 40 ns/iter overhead, consistent with one heap allocation per iteration.

### Step 2: Internal Ecosystem Inventory

#### sequence-primitives

Provides:

- `Sequence.Protocol` — consuming iteration via `consuming func makeIterator()`. Lazy-chain composition (`map`, `filter`, `collect`).
- `Sequence.Borrowing.Protocol` — non-destructive span access.
- `Sequence.Drain` (Property.Inout) — consuming drain that calls a closure per element.
- `Sequence.Consume.View` — consume view used internally by Property.Inout patterns.
- Standard Library Integration — `Sequence.Protocol ↔ Swift.Sequence` bridge.

Key property: `Sequence.Protocol` chains are *lazy* — `source.map { … }.filter { … }` builds a wrapper struct, not a materialized array. Only the terminal `.collect()` allocates. This is the inverse cost profile of the current Builder.

[Verified: 2026-05-06] `swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Protocol.swift` declares the consuming-iteration shape; `Sequence Consuming Primitives` provides Drain and Consume.View.

#### buffer-primitives

Provides:

- `Buffer<Element>.Linear` — heap-allocated growable contiguous storage with O(1) amortized append (CoW-managed). ~Copyable; conditionally Copyable.
- `Buffer<Element>.Linear.Inline<N>` — fixed-capacity inline (zero-heap) storage.
- `remove.first` / `remove.last` / `pop.front` / `pop.back` — element-extraction APIs.

Key property: `Buffer<Element>.Linear` has the *same allocation profile as Swift.Array* (one allocation for backing storage, doubling growth) but with `~Copyable` Element support. It is **not** structurally faster as an intermediate type — it has the same per-allocation cost.

[Verified: 2026-05-06] `swift-buffer-primitives/Sources/Buffer Linear Primitives/Buffer.Linear.swift`.

#### swift-standard-library-extensions

Provides the existing Round-1 `Swift.Array.Builder` (the Copyable canonical builder). Current implementation:

```swift
public static func buildExpression(_ expression: Element) -> [Element] {
    [expression]   // 1 heap alloc per call
}

public static func buildPartialBlock(accumulated: [Element], next: [Element]) -> [Element] {
    accumulated + next   // 1 heap alloc per call (creates new Array)
}

public static func buildArray(_ components: [[Element]]) -> [Element] {
    components.flatMap { $0 }   // 1 heap alloc + N moves
}
```

`buildPartialBlock`'s `+` is O(n) per call due to copy-on-write — for N statement-list bodies, total cost is O(N²). Less of an issue than for-loop because typical statement-list sizes are small (≤ 10).

[Verified: 2026-05-06] `swift-primitives/swift-standard-library-extensions/Sources/Standard Library Extensions/Array.Builder.swift`.

### Step 3: Optimization Options

| Option | Mechanism | Cost reduction | API impact |
|--------|-----------|----------------|------------|
| **A. Document, no change** | Note that for-loop in builder body is O(N) heap allocs; recommend imperative for large N | None | Zero — keep current shape |
| **B. consume + append(contentsOf:)** in buildPartialBlock | Reuses accumulated's storage when uniquely owned | Helps statement-list bodies; **does not** address for-loop (which uses buildArray, not buildPartialBlock) | Backward compatible |
| **C. Swap intermediate type to Buffer<Element>.Linear** | Same allocation profile as `[Element]`; buys nothing | None | Breaking (changes Component type) |
| **D. Drop `buildArray` from Array.Builder** | Removes for-loop support; users must use Repeat helper | Eliminates for-loop slow path entirely | Breaking for any consumer that uses `for` in builder body |
| **E. Add a `Repeat`-style bulk-add helper** | Provides explicit bulk-add expression that avoids per-iteration alloc | For-loop replaced by Repeat(seq) { transform } → O(N) total (one allocation) | Backward compatible (additive) |
| **F. Compiler-level fusion of buildExpression + buildArray for for-loops** | Synthesize partials directly into the Component flatten target, skipping per-iteration buildExpression alloc | Would make for-loop O(1) per iteration | Requires Swift Evolution proposal; out of scope |

#### Option E expanded: `Repeat` Helper

Pattern (based on SwiftUI's `ForEach` and the institute's `Sequence.Protocol`):

```swift
public struct Repeat<Source: Swift.Sequence, Element>: Sendable
where Source: Sendable, Element: Sendable {
    @usableFromInline
    let _source: Source
    @usableFromInline
    let _transform: @Sendable (Source.Element) -> Element

    @inlinable
    public init(_ source: Source, _ transform: @escaping @Sendable (Source.Element) -> Element) {
        self._source = source
        self._transform = transform
    }
}

extension Array.Builder {
    @inlinable
    public static func buildExpression<S: Swift.Sequence>(
        _ r: Repeat<S, Element>
    ) -> [Element] where S: Sendable {
        var result: [Element] = []
        result.reserveCapacity(r._source.underestimatedCount)
        for x in r._source {
            result.append(r._transform(x))
        }
        return result
    }
}
```

User-facing call:

```swift
// Old (slow at large N):
let arr = Array<Int> {
    for i in 0..<1000 { i }                // ~36577 ns/iter
}

// New (single-allocation bulk-add):
let arr = Array<Int> {
    Repeat(0..<1000) { $0 }                // expected ~1500 ns/iter (1 alloc + N moves)
}
```

Cost analysis:

- `Repeat(seq)` constructor: zero-cost (struct initialization, two stored fields).
- `buildExpression(_ r:)`: one `[Element]` allocation with `reserveCapacity` (no growth resizes), then N moves.
- buildPartialBlock: still pairs Repeat-result with surrounding statements via `+` (same as current shape; small constant overhead).
- Final cost: **O(N) total time, one heap allocation**.

This recovers parity with imperative `var a = []; a.reserveCapacity(N); for i in seq { a.append(transform(i)) }`.

#### Cross-package generalization

The same pattern applies to every Round-1 / Round-2 builder whose Component type is `[Element]`:

- `Set.Ordered.Builder` — Repeat<S, Element> works the same way; insertion at the convenience init handles uniqueness.
- `Bitset.Builder` — Repeat<S, Int> works.
- `Dictionary.Ordered.Builder` — Repeat<S, (Key, Value)> works.
- `Tree.Binary.Builder` / `Tree.Unbounded.Builder` — Repeat<S, Element> works (the convenience init then walks the [Element] in BFS or appendChild order respectively).

For ~Copyable-Element builders (institute Array, Buffer.Linear, Stack, Queue), the same pattern requires `Repeat<S, Element>` where Element: ~Copyable — possible if the source closure produces Element values; the closure itself stays non-`@Sendable` to permit ~Copyable returns. This adds Round-3 scope.

### Step 4: Comparison Table

| Option | For-loop perf at N=1000 (predicted) | API breaking | Implementation cost | Maintenance burden |
|--------|--------------------------------------|--------------|---------------------|---------------------|
| A. Document only | 39× slower (unchanged) | No | Zero | Zero |
| B. consume buildPartialBlock | ~38× slower (helps statement-list, not for-loop) | No | One commit on swift-standard-library-extensions | Low |
| C. Buffer.Linear intermediate | ~39× slower (same alloc profile) | Yes (Component type change) | Significant | High |
| D. Drop buildArray | N/A (for-loop unsupported) | Yes (existing for-loop bodies break) | Low | Medium (consumer migration) |
| **E. Repeat helper** | **~1.5–2.0× of imperative** | **No (additive)** | **Medium (one Repeat type + buildExpression overload per builder)** | **Low** |
| F. Compiler fusion | ~1.0× (theoretical optimum) | No | Out of scope | Out of scope |

### Step 5: Constraints and Caveats

1. **Sendability**: Sub-experiments will need to verify `Repeat<S, Element>` works under strict-concurrency; the closure must satisfy `@Sendable` for cross-actor builder bodies, but in practice most builder bodies are synchronous and same-actor.
2. **~Copyable Element**: For the institute's ~Copyable types, `Repeat` with closure-producing-Element is possible but the closure capture rules differ. Round-3 work; not blocking the Copyable case.
3. **`underestimatedCount`**: The reserveCapacity hint is opportunistic. Sources without precise count (Lazy chains, `AnySequence`) will still get O(log N) growth allocations. Acceptable.
4. **Combinator composition**: Users can pre-build a Sequence with `.map` / `.filter` / `.lazy` and pass to `Repeat(seq) { $0 }` for full lazy composition. Idiomatic.
5. **Discoverability**: Users not aware of `Repeat` will write `for` loops and get the slow path. **Documentation surface is critical** — DocC for each Builder must call out the `Repeat` helper for moderate-to-large N.

## Outcome

**Status**: RECOMMENDATION

### Recommendation

Adopt **Option E (Repeat helper)** as the canonical solution. Implement in three phases:

| Phase | Scope | Estimated work |
|-------|-------|---------------|
| **Phase 1** | Define `Repeat<S, Element>` in swift-standard-library-extensions (Copyable Element, Sendable closure). Add `buildExpression(_ r: Repeat<S, Element>) → [Element]` overload to `Swift.Array.Builder`. Sub-experiment to validate predicted ~1.5–2.0× ratio at N=1000. | One commit, ~80 LOC + tests. |
| **Phase 2** | Add the same `buildExpression(_ r:)` overload to every Round-1 Builder whose Component type is `[Element]` or `[(Key, Value)]`: Set.Ordered, Bitset, Dictionary.Ordered, Tree.Binary, Tree.Unbounded. Additive; no breaking change. DocC updates per builder calling out the `Repeat` helper for moderate-to-large N. | Per-builder commits, ~30 LOC each + tests. |
| **Phase 3 (deferred)** | ~Copyable-Element variants (institute Array, Buffer.Linear, Stack, Queue, Heap). The closure cannot be `@Sendable` if the closure produces a ~Copyable; the convenience-init path must drain the Repeat into the institute container. Coordinate with ImplOQ6 (Round-2 ~Copyable nested-DSL deferral). | Round-3 dispatch. |

### Decision rationale

- **Option E is the only option that recovers on-par performance without breaking existing API.** A is no-change; B/C/D are insufficient or breaking; F is out of scope.
- **Re-uses ecosystem patterns**: `Repeat` is structurally a `Swift.Sequence`-based bulk-add expression, idiomatic with the institute's `Sequence.Protocol` lazy chain via the SLI bridge. Users who need lazy composition write `Repeat(source.lazy.map { … }) { $0 }`.
- **Discoverability mitigated by DocC**: documenting "for moderate-to-large N, prefer `Repeat(seq) { transform }` over `for x in seq { transform(x) }`" is a single-paragraph addition per builder.
- **Acceptance criterion**: Phase 1's sub-experiment will produce empirical evidence that `Repeat`-based builders meet the user's "≤ 1.5×" criterion. If empirical ratio is between 1.5× and 2.0×, the user adjudicates whether that's acceptable; if > 2.0×, Phase 1 is downgraded to PARTIAL and other options are revisited.

### Residual Constraints

- **`for`-loop in builder body remains slow.** Repeat is an *opt-in* fast path; existing for-loop bodies retain the per-iteration allocation pattern. Users must adopt Repeat at consumer sites for the speedup. No automatic migration possible.
- **Heap.Builder is unaffected.** Heap.Builder already produces Buffer<Element>.Linear (not [Element]) and uses bulk-build heapify in the convenience init — for-loop in Heap body is *also* slow (per-iteration Buffer.Linear allocations) but lower priority since Heap is a niche use case. Phase 2 may add a Heap-specific Repeat overload later.
- **Phase 3 (~Copyable Repeat) is genuinely harder.** The closure must produce a *consuming* Element each call, which conflicts with `@Sendable`. May require a `Repeat.NonCopyable` variant with non-Sendable closure. Tracked as a Round-3 concern.

## Prior Art Survey

[Verified: 2026-05-06] consulted internally and externally:

- **SE-0289 Result Builders** ([source](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md)): Establishes the `buildExpression`, `buildPartialBlock`, `buildArray` shape. `buildArray` is explicitly the for-loop transform target; per-iteration buildExpression call is mandated. The proposal does not address allocation overhead; it predates strict-concurrency Sendable requirements.
- **SwiftUI ViewBuilder**: Does not support `for` in builder body. Users use `ForEach(source)`, which is structurally identical to the `Repeat` pattern recommended here. Strong precedent for the recommendation. ([Apple SwiftUI documentation](https://developer.apple.com/documentation/swiftui/foreach))
- **Swift Charts ChartContentBuilder**: Same pattern — `ForEach` for iteration, bare `for` is rejected. ([Apple Swift Charts documentation](https://developer.apple.com/documentation/charts))
- **Rust `quote!` / `format!` macros**: Compile-time-only; no runtime cost analog. Not applicable.
- **Internal: institute's Sequence.Protocol** (in swift-sequence-primitives): Lazy-chain composition via consuming iteration. Compatible with Repeat: Repeat takes any Swift.Sequence, including those bridged from Sequence.Protocol via `Standard Library Integration`.
- **No internal research found** on result-builder performance specifically. This document is the first.

## Implementation Path (Phase 1, after supervisor adjudication)

1. Author `Repeat<S, Element>` in `swift-primitives/swift-standard-library-extensions/Sources/Standard Library Extensions/Repeat.swift` (or similar).
2. Author the `buildExpression(_ r:)` overload on `Swift.Array.Builder` in the same package.
3. Author sub-experiment `swift-institute/Experiments/result-builder-perf-repeat-helper/` mirroring the existing `result-builder-perf` package structure; benchmark `for`-loop case vs `Repeat` case at N=100, N=1000.
4. Update DocC on Array.Builder calling out the helper for moderate-to-large N.
5. Per-builder Phase 2 dispatch follows.

## Final Decision (2026-05-06)

After validation in `swift-institute/Experiments/result-builder-perf-repeat/`, the recommendation supersedes the original Option E proposal. The user's constraint *"we'd prefer NOT adding a type in standard-library-extensions"* combined with the "we control all packages, can change all code" mandate produced the following decision.

### Shipped changes

**1. Option G — bare `Sequence` overload added to standard-library-extensions builders.**

```swift
extension Array.Builder {
    @inlinable
    public static func buildExpression<S: Sequence>(_ expression: S) -> [Element]
    where S.Element == Element {
        Array(expression)
    }
}
```

Same overload added to: `Array.Builder`, `ContiguousArray.Builder`, `ArraySlice.Builder`, `Set.Builder`. **It is an overload, not a type**, so the no-new-type constraint is satisfied. Single optimized `Array.init(_ sequence:)` call replaces per-iteration allocation.

**2. Option B — `consume` + `append(contentsOf:)` in `buildPartialBlock`.**

```swift
public static func buildPartialBlock(
    accumulated: consuming [Element],
    next: [Element]
) -> [Element] {
    accumulated.append(contentsOf: next)
    return accumulated
}
```

Replaces `accumulated + next` (O(N) copy per partial block step) with mutating-append. Same change applied to `Set.Builder` (`formUnion` instead of `union`).

### Empirical validation

Re-run of `Experiments/result-builder-perf/` after upstream changes:

| Case | Imperative | Builder | Ratio | Verdict |
|------|------------|---------|-------|---------|
| Swift.Array N=3 (literals) | 82.7 ns | 77.6 ns | **0.94×** | BUILDER FASTER |
| Swift.Array N=100 (Sequence: `0..<100`) | 371.2 ns | 46.6 ns | **0.13×** | BUILDER 8× FASTER |
| Swift.Array N=1000 (Sequence: `0..<1000`) | 1004.5 ns | 172.2 ns | **0.17×** | BUILDER 6× FASTER |
| Heap N=10 (bulk-build) | 10370.6 ns | 5257.3 ns | **0.51×** | BUILDER 2× FASTER |
| Swift.Array N=100 (for-loop) | 371.2 ns | 4773.6 ns | 12.86× | SLOWER (do not use) |

The for-loop pattern (`for i in 0..<N { i }`) remains slow — that is a structural cost of SE-0289's per-iteration `buildExpression` transform and is not fixable without a different result-builder shape. **Recommended pattern: write the sequence directly (`0..<N`).**

### Why Option E was rejected

| Criterion | Option E (Repeat) | Option G (Sequence) |
|-----------|-------------------|---------------------|
| New type in stdlib-ext | Yes (`Repeat<S, Element>`) | **No** (overload only) |
| Direct sequence ergonomics | `Repeat(0..<100)` | `0..<100` |
| Direct sequence perf (N=1000) | 1.0× of imperative | **0.17×** of imperative (5.9× faster) |
| Transform support | Yes (`Repeat(seq) { f }`) | No (use eager `seq.map`) |
| Discoverability | Requires DocC ("use Repeat") | None (`Sequence` is canonical Swift vocabulary) |

Option E's only advantage is the in-builder-body transform path. The transform-via-`.map` case was independently slow even via the existing `[Element]` overload (~21× of imperative — appears to be a result-builder ↔ overload-resolution interaction, filed as a separate investigation). Users with transformations should pre-materialize: `let m = seq.map { ... }; Array { m }`.

### Adoption guidance

| Pattern | Example | Verdict |
|---------|---------|---------|
| Direct sequence | `Array<Int> { 0..<100 }` | **Recommended** — 0.13× of imperative |
| Pre-materialized array | `Array<Int> { Array(seq) }` | Acceptable — 0.58× of imperative |
| Pre-materialized transform | `let m = seq.map { … }; Array { m }` | Acceptable for transforms |
| Mixed literals + sequence | `Array<Int> { 1; 2; 0..<100; 99 }` | OK — 2.4× (declarative-syntax tax; allocation per single-element statement) |
| For-loop in body | `Array<Int> { for i in 0..<N { i } }` | **Avoid** — 12-44× slower |
| Lazy chain | `Array<Int> { (0..<100).lazy.map { … } }` | **Avoid** — ~20× slower; pre-materialize instead |

### Residual: in-body `.map` slowdown

`Array<Int> { (0..<100).map { $0 * 2 } }` measures at ~4500 ns vs imperative 211 ns even though `.map` returns `[Int]` and should hit the existing `[Element]` overload identity path. Root cause is unclear and is filed for separate investigation. Workaround: pre-materialize.

### Phase 2 status

Propagation of Option G to the 13 institute Round-1 + Round-2 Builders (institute Array, Buffer.Linear/Ring, List.Linked, Stack, Queue/Linked, Heap, Set.Ordered, Bitset, Dictionary.Ordered, Tree.Binary/Unbounded) is deferred. The standard-library-extensions changes deliver the canonical Repeat-replacement story; institute-builder propagation is mechanical and additive.

## References

- [SE-0289 Result Builders](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md)
- [Apple SwiftUI ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple Swift Charts](https://developer.apple.com/documentation/charts)
- `swift-institute/Experiments/result-builder-perf/` (empirical baseline data)
- `swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Protocol.swift` (consuming-iteration shape)
- `swift-primitives/swift-buffer-primitives/Sources/Buffer Linear Primitives/Buffer.Linear.swift` (Buffer.Linear allocation profile)
- `swift-primitives/swift-standard-library-extensions/Sources/Standard Library Extensions/Array.Builder.swift` (current Round-1 builder shape)
- `HANDOFF-result-builder-ecosystem-extensions.md` (Round-1 + Round-2 dispatch history)
