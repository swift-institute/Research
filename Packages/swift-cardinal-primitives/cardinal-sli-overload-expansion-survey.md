# Cardinal SLI Overload Expansion Survey

<!--
---
version: 2.0.0
last_updated: 2026-05-21
status: DECISION
tier: 2
scope: cross-package
---
-->

## Context

The `Cardinal Primitives Standard Library Integration` target hosts typed-Cardinal overloads of Swift standard library APIs that take `Int` as a count, size, or capacity parameter — letting consumers pass institute-typed `Cardinal` / `Tagged<Tag, Cardinal>` values directly without an `Int(bitPattern:)` dance at the call site.

The recent reserveCapacity arc (2026-05-21) surfaced two architectural lessons:

1. **Protocol-level placement beats per-concrete-type** when the stdlib hosts the method at a protocol level. The `Array.reserveCapacity` + `ContiguousArray.reserveCapacity` per-type overloads were consolidated into `RangeReplaceableCollection.reserveCapacity(_: some Carrier.\`Protocol\`<Cardinal>)`. One overload covers Array, ContiguousArray, ArraySlice, String, Substring, and any custom RRC conformer in a single declaration. The protocol-level placement also resolves cleanly in `extension Sequence.\`Protocol\` where Self: ~Copyable, Element: Copyable` + `@inlinable consuming func` contexts where per-type extension lookup unexpectedly skipped candidates.

2. **The `Array_Primitives.Array` shadow trap** — `extension Array` may bind to the institute `~Copyable` `Array<Element>` if `Array_Primitives_Core` is transitively reachable. Stdlib-intent extensions on `Array` must be qualified `extension Swift.Array`. Protocol-level extensions avoid the shadow entirely (no institute equivalents for `RangeReplaceableCollection`, etc.).

This survey enumerates stdlib APIs that fit the SLI pattern, classifies by protocol/type hosting, and identifies high-value additions backed by workspace call-site evidence.

## Question

**Which standard-library APIs that accept `Int` as count/size/capacity warrant a typed-Cardinal (`some Carrier.\`Protocol\`<Cardinal>`) overload in Cardinal SLI, and where (protocol-level vs concrete-type) should each overload live?**

Sub-questions:

- Which APIs are hosted at a stdlib protocol level and thus best served by a protocol-level extension?
- Which APIs are concrete-type-only (no protocol home) and need per-type extensions?
- Which Cardinal SLI candidates would overlap with Ordinal SLI / Affine SLI / Memory SLI (and thus belong elsewhere)?
- What's the call-site evidence in the workspace for each candidate (frequency of `Int(bitPattern: <typed-cardinal>)` smell)?

## Analysis

### Prior art — existing Cardinal SLI surface (2026-05-21)

Catalog of currently-shipped overloads in `Sources/Cardinal Primitives Standard Library Integration/`:

| File | Surface | Form |
|---|---|---|
| `RangeReplaceableCollection+Cardinal.swift` | `mutating func reserveCapacity(_:)` | Protocol-level [Verified: 2026-05-21] |
| `ContiguousArray+Cardinal.swift` | `init(repeating:count:)` | Per-type (no RRC equivalent) [Verified: 2026-05-21] |
| `Span+Cardinal.swift` | `init(_unsafeStart:count:)` | Per-type [Verified: 2026-05-21] |
| `MutableSpan+Cardinal.swift` | `init(_unsafeStart:count:)` | Per-type [Verified: 2026-05-21] |
| `OutputSpan+Cardinal.swift` | `init(...)`, `mutating func removeLast(_:)` | Per-type [Verified: 2026-05-21] |
| `UnsafeBufferPointer+Cardinal.swift` | `init(start:count:)` | Per-type [Verified: 2026-05-21] |
| `UnsafeMutableBufferPointer+Cardinal.swift` | `init(start:count:)`, `static func allocate(capacity:)` | Per-type [Verified: 2026-05-21] |
| `UnsafeMutablePointer+Cardinal.swift` | `initialize(...)`, `moveInitialize(...)` (count parameter) | Per-type [Verified: 2026-05-21] |
| `Int+Cardinal.swift` | `init(bitPattern:Cardinal)`, `init(clamping:Cardinal)`, `init(_ Cardinal) throws` | Per-type [Verified: 2026-05-21] |
| `UInt32+Cardinal.swift` | `init(_:Cardinal.Protocol)` | Per-type [Verified: 2026-05-21] |
| `Cardinal+AtomicRepresentable.swift` | Cardinal's own AtomicRepresentable conformance | Type-internal [Verified: 2026-05-21] |
| `Cardinal+ExpressibleByIntegerLiteral.swift` | Cardinal's literal conformance | Type-internal [Verified: 2026-05-21] |
| `Cardinal+UnsignedInteger.swift` | Cardinal's UnsignedInteger init | Type-internal [Verified: 2026-05-21] |

Adjacent SLI surfaces (out of Cardinal SLI scope but worth knowing):

- `Ordinal Primitives Standard Library Integration` — `Atomic<Tagged<Tag,Ordinal>>.advance(within:)`, `Range` operations, position-typed pointer subscripts. ALSO hosts an `Array.init(count:Cardinal, _ closure)` overload — included there because it composes Cardinal (count) AND Ordinal (each closure invocation receives a typed Ordinal position).
- `Affine Primitives Standard Library Integration` — pointer arithmetic with typed `Offset` (signed vector).
- `Memory Primitives Standard Library Integration` — raw memory ops with typed counts (Index<T>.Count for element-typed ops, Memory.Address.Count for byte-typed ops).
- `Vector Primitives Standard Library Integration` — UnsafeRawPointer arithmetic with typed Index.

### Placement decision framework

Apply the following test in order:

1. **Is the stdlib method hosted on a stdlib protocol (and the concrete-type overrides are derived defaults)?** If yes → protocol-level extension on the broadest hosting protocol. Single overload covers all conformers.
2. **Is the method semantically signed (accepts negative values)?** If yes → NOT Cardinal SLI territory. Use Affine SLI (`some Carrier.\`Protocol\`<Vector>` or signed Offset).
3. **Is the parameter a position (absolute index)?** If yes → NOT Cardinal SLI. Use Ordinal SLI (`some Carrier.\`Protocol\`<Ordinal>`).
4. **Is the method concrete-type-only?** Per-type extension; one file per concrete type per institute convention.
5. **Does the stdlib type have an institute shadow (e.g., `Array_Primitives.Array`)?** Qualify the extension explicitly (`extension Swift.Array`). Protocol-level extensions sidestep the shadow.

### Candidate enumeration — by stdlib-protocol-host vs concrete-type

#### Protocol-level candidates (highest-value placement)

##### `RangeReplaceableCollection` — already partly covered

| Method | Stdlib signature | Current Cardinal SLI | Recommended Cardinal SLI |
|---|---|---|---|
| `reserveCapacity(_:Int)` | protocol method | ✓ shipped | (current) |
| `removeFirst(_:Int)` | extension default on RRC | — | **ADD**: `mutating func removeFirst(_:some Carrier.\`Protocol\`<Cardinal>)` |
| `removeLast(_:Int)` | extension default on BidirectionalCollection (where Self: RRC) | — | **ADD**: `mutating func removeLast(_:some Carrier.\`Protocol\`<Cardinal>)` (on RRC or BidirectionalCollection — see "constraint analysis" below) |

**Constraint analysis for `removeLast(_:)`**: stdlib hosts `removeLast(_:Int)` as `extension BidirectionalCollection where Self: RangeReplaceableCollection`. The institute overload should match — `extension BidirectionalCollection where Self: RangeReplaceableCollection { mutating func removeLast(_:some Carrier.\`Protocol\`<Cardinal>) }`. Or, more simply, host on RRC and accept that String / Array / ContiguousArray (which conform to both) all get it; ArraySlice (which conforms to both) too.

##### `Sequence` — broad reach

| Method | Stdlib signature | Recommended Cardinal SLI |
|---|---|---|
| `prefix(_:Int) -> SubSequence` | extension on Sequence | **ADD**: `func prefix(_:some Carrier.\`Protocol\`<Cardinal>) -> SubSequence` |
| `suffix(_:Int) -> SubSequence` | extension on Collection (technically) | **ADD**: on Collection or BidirectionalCollection per stdlib host |
| `dropFirst(_:Int) -> SubSequence` | extension on Sequence | **ADD**: `func dropFirst(_:some Carrier.\`Protocol\`<Cardinal>) -> SubSequence` |
| `dropLast(_:Int) -> SubSequence` | extension on Collection (default impl on Sequence) | **ADD**: on Sequence per stdlib host |

These four are exceptionally broad — every Sequence conformer benefits.

##### `String` (via RangeReplaceableCollection)

`String.reserveCapacity(_:Int)` already covered transitively via the RRC overload. Verify in a downstream consumer.

#### Concrete-type candidates (no protocol home)

##### `Set` — not RangeReplaceableCollection

| Method | Stdlib signature | Recommended Cardinal SLI |
|---|---|---|
| `Set.reserveCapacity(_:Int)` | concrete | **ADD**: `mutating func reserveCapacity(_:some Carrier.\`Protocol\`<Cardinal>)` |
| `Set.init(minimumCapacity:Int)` | concrete | **ADD**: `init(minimumCapacity:some Carrier.\`Protocol\`<Cardinal>)` |

##### `Dictionary` — not RangeReplaceableCollection

| Method | Stdlib signature | Recommended Cardinal SLI |
|---|---|---|
| `Dictionary.reserveCapacity(_:Int)` | concrete | **ADD**: `mutating func reserveCapacity(_:some Carrier.\`Protocol\`<Cardinal>)` |
| `Dictionary.init(minimumCapacity:Int)` | concrete | **ADD**: `init(minimumCapacity:some Carrier.\`Protocol\`<Cardinal>)` |

##### `String` — concrete `init(repeating:count:)`

| Method | Stdlib signature | Recommended Cardinal SLI |
|---|---|---|
| `String.init(repeating: String, count: Int)` | concrete | **ADD**: `init(repeating: String, count: some Carrier.\`Protocol\`<Cardinal>)` |
| `String.init(repeating: Character, count: Int)` | concrete (deprecated in newer stdlib but still callable) | Skip — niche |

##### `Array` — uncovered concrete inits

| Method | Stdlib signature | Recommended Cardinal SLI |
|---|---|---|
| `Array.init(repeating:count:Int)` | concrete | **ADD**: `init(repeating:count:some Carrier.\`Protocol\`<Cardinal>)` — `extension Swift.Array` per shadow rule. Sibling to existing `ContiguousArray.init(repeating:count:)` |
| `Array.init(_unsafeUninitializedCapacity:Int, initializingWith:)` | concrete | **ADD**: similar overload accepting typed Cardinal capacity |
| `ContiguousArray.init(_unsafeUninitializedCapacity:Int, initializingWith:)` | concrete | **ADD**: sibling |
| `ArraySlice.init(repeating:count:Int)` | concrete | Skip — niche; ArraySlice usually constructed via slicing not repeating |

##### `Range` / `ClosedRange` — Int-typed range bounds

`Range<Int>(uncheckedBounds:(lower:Int, upper:Int))` — Int-as-position, NOT Cardinal. Cardinal SLI doesn't cover (use Ordinal SLI or position-typed alternatives).

#### Out-of-scope candidates (belong in other SLIs)

| Method | Why not Cardinal SLI |
|---|---|
| `Collection.index(_:offsetBy:Int)` | Offset is signed (BidirectionalCollection allows negative) → Affine SLI |
| `Collection.formIndex(_:offsetBy:Int)` | Same |
| `Collection.distance(from:to:) -> Int` | Returns Int — typed-Cardinal return is a different shape (pure conversion) |
| `Range(start:Index, count:Int)` | Index is positional — Ordinal SLI |
| `UnsafePointer.advanced(by:Int)` | Already in Affine SLI |

### Workspace call-site evidence

Empirical sample of `Int(bitPattern: <typed-cardinal-source>)` sites across the workspace (excluding tests, experiments, SLI internals, and `.build/.swift-lint` caches):

| Site pattern | Approx. count | Migration target |
|---|---|---|
| `reserveCapacity(Int(bitPattern: count))` where count is typed Cardinal | ~5 [grep verified 2026-05-21] | Already covered by RRC overload |
| `init(repeating:count: Int(bitPattern: ...))` on Array | ~3 [grep verified 2026-05-21] | Array.init(repeating:count:) overload |
| `removeLast(Int(bitPattern: ...))` / `removeFirst(Int(bitPattern: ...))` on String, Array | grep needed (search uses `.removeLast(`/`.removeFirst(`) | RRC.removeFirst/removeLast |
| `prefix(Int(bitPattern: ...))` / `dropFirst(Int(bitPattern: ...))` on collections | grep needed | Sequence.prefix/dropFirst |
| `Set.reserveCapacity(Int(bitPattern: ...))` | grep needed | Set.reserveCapacity overload |
| `Dictionary.reserveCapacity(Int(bitPattern: ...))` | grep needed | Dictionary.reserveCapacity overload |

The grep `Int(bitPattern: .*\.count\|Int(bitPattern: .*\.cardinal\|Int(bitPattern: .*\.underlying)` across `/Users/coen/Developer/swift-primitives` (excluding `.build/`, `.swift-lint/`, tests, experiments, Cardinal SLI itself) returned ~30+ files with at least one such site. Many are at stdlib-collection-init / mutation boundaries (Stack, Set, Storage variants).

The implementation handoff should enumerate per-site mappings precisely.

### Placement summary

Recommended new files in `Sources/Cardinal Primitives Standard Library Integration/`:

| File | Surface |
|---|---|
| `RangeReplaceableCollection+Cardinal.swift` (existing — extend) | Add `removeFirst(_:Cardinal.Protocol)`, `removeLast(_:Cardinal.Protocol)` |
| `Sequence+Cardinal.swift` (NEW) | `prefix(_:Cardinal.Protocol)`, `dropFirst(_:Cardinal.Protocol)` |
| `Collection+Cardinal.swift` (NEW) | `suffix(_:Cardinal.Protocol)`, `dropLast(_:Cardinal.Protocol)` (or under BidirectionalCollection if stdlib hosts it there) |
| `Array+Cardinal.swift` (NEW — was deleted in the reserveCapacity arc; resurrect for the init overloads) | `init(repeating:count:Cardinal.Protocol)` (extension Swift.Array) — sibling to existing ContiguousArray init |
| `Array+Cardinal+UnsafeUninitialized.swift` (NEW, optional) | `init(_unsafeUninitializedCapacity:Cardinal.Protocol, initializingWith:)` |
| `ContiguousArray+Cardinal.swift` (existing — extend) | Add `init(_unsafeUninitializedCapacity:Cardinal.Protocol, initializingWith:)` |
| `Set+Cardinal.swift` (NEW) | `reserveCapacity(_:Cardinal.Protocol)`, `init(minimumCapacity:Cardinal.Protocol)` |
| `Dictionary+Cardinal.swift` (NEW) | `reserveCapacity(_:Cardinal.Protocol)`, `init(minimumCapacity:Cardinal.Protocol)` |
| `String+Cardinal.swift` (NEW) | `init(repeating:String, count:Cardinal.Protocol)` |

## Outcome

**Status**: DECISION (2026-05-21)

Cardinal SLI expansion implemented across three tiers per the recommendation. ~13 new typed-Cardinal overloads land in `Sources/Cardinal Primitives Standard Library Integration/`. Implementation commits:

| Tier | Commit | Surface |
|------|--------|---------|
| Tier 1 | [`1fb2691`](https://github.com/swift-primitives/swift-cardinal-primitives/commit/1fb2691) | `RangeReplaceableCollection.removeFirst`, `BidirectionalCollection.removeLast where Self: RRC`, `Collection.{prefix, suffix, dropFirst, dropLast}` |
| Tier 2 | [`5098356`](https://github.com/swift-primitives/swift-cardinal-primitives/commit/5098356) | `Set.{reserveCapacity, init(minimumCapacity:)}`, `Dictionary.{reserveCapacity, init(minimumCapacity:)}` |
| Tier 3 | [`fbad738`](https://github.com/swift-primitives/swift-cardinal-primitives/commit/fbad738) + [`15d2e1b`](https://github.com/swift-primitives/swift-cardinal-primitives/commit/15d2e1b) | `Swift.Array.{init(repeating:count:), init(unsafeUninitializedCapacity:initializingWith:)}`, `ContiguousArray.init(unsafeUninitializedCapacity:initializingWith:)`, `String.init(repeating:count:)` |

Consumer migration (driving the protocol-level Collection overloads in production):

- `swift-sequence-primitives` [`32f6dca`](https://github.com/swift-primitives/swift-sequence-primitives/commit/32f6dca) — `contextBuffer.dropFirst(skip)` via the new `Collection.dropFirst` typed-Cardinal overload.

### Placement deviations from this survey's original recommendation

1. **`prefix`, `dropFirst`, `dropLast`, `suffix` → `Collection`, NOT `Sequence`**. The survey's enumeration above listed `prefix`/`dropFirst`/`dropLast` as "extension on Sequence" with return type `SubSequence`. Empirically incorrect — Sequence has no `SubSequence` associatedtype; all four `(_:Int) -> SubSequence` forms live on `Collection` in stdlib (verified via `_Concurrency.swiftinterface` grep on the macOS 26.x SDK). All four landed on `Collection` in `Collection+Cardinal.swift`. Optimized overrides on `BidirectionalCollection` (for `suffix` and `dropLast`) remain reachable via inner delegation.

2. **`unsafeUninitializedCapacity` uses single generic `C` for both capacity and inout count**. The closure's `initializedCount` parameter is `inout C` of the same `Carrier.\`Protocol\`<Cardinal>` conformer as the capacity — so a caller passing `Index<Element>.Count` receives `inout Index<Element>.Count` in the closure. Internal wrapper bridges to stdlib's `inout Int`. This preserves the count domain across the API rather than collapsing to bare `Cardinal` mid-call.

### Dead Ends (REVISED 2026-05-21)

The original v1.0.0 of this survey claimed:

> Per-type `extension Swift.Array.reserveCapacity(_:Cardinal)` did NOT resolve in `extension Sequence.Protocol where Self: ~Copyable, Element: Copyable` + `@inlinable consuming func`. Root cause unclear; protocol-level placement on RangeReplaceableCollection sidesteps it. Treat per-type Array overloads as resolution-fragile by default; prefer protocol-level when stdlib hosts the method there.

This is now **REFUTED**. The "resolution failure" was misdiagnosed — it was not a Swift compiler overload-resolution limitation. The root cause was a stale `Package.resolved` pin in `swift-sequence-primitives` pointing to `swift-cardinal-primitives @ 4b7a83a` (Initial publication 2026-05-12), which pre-dated the entire reserveCapacity arc. The pinned upstream genuinely had no typed-Cardinal `reserveCapacity` overload — so the compiler correctly failed to find it. `swift package update` re-resolves the local mirror to current `main` HEAD; the typed overload resolves cleanly in `~Copyable Self` extension + `@inlinable consuming func` contexts at every variant tested.

Experiment artifact: [`copyable-self-cardinal-resolution`](../Experiments/copyable-self-cardinal-resolution/) (REFUTED, 2026-05-21). The diagnostic that broke the misdiagnosis: a module-scope `@inlinable` probe outside the `~Copyable Self` extension failed identically, proving the bug was NOT extension-context-specific.

**Implication for past decisions**: the consolidation in commit `3ffa3cd` (per-type Array + ContiguousArray → protocol-level RRC) is still correct on its own merits — single overload covers Array, ContiguousArray, ArraySlice, String, Substring, and any custom RRC conformer with one declaration. But the rationale recorded in that commit message ("the per-type overload was not being considered as an overload candidate in `~Copyable Self` contexts") needs to be read as a misdiagnosis. The consolidation is good for reach; not for "resolution-stress workaround."

### Original recommendation (preserved as historical record)

Proposed expansion of Cardinal SLI to cover ~10 additional stdlib APIs, organized by host (protocol-level vs concrete-type) per the placement decision framework. Prioritization for the follow-up implementation handoff:

**Tier 1 — protocol-level, broad reach** (do first):

1. `RangeReplaceableCollection.removeFirst(_: some Carrier.\`Protocol\`<Cardinal>)`
2. `BidirectionalCollection.removeLast(_: some Carrier.\`Protocol\`<Cardinal>) where Self: RangeReplaceableCollection`
3. `Sequence.prefix(_: some Carrier.\`Protocol\`<Cardinal>) -> SubSequence`
4. `Sequence.dropFirst(_: some Carrier.\`Protocol\`<Cardinal>) -> SubSequence`
5. `Collection.suffix(_: some Carrier.\`Protocol\`<Cardinal>) -> SubSequence`
6. `Sequence.dropLast(_: some Carrier.\`Protocol\`<Cardinal>) -> SubSequence`

**Tier 2 — concrete-type, no protocol alternative** (do second):

7. `Set.reserveCapacity(_: some Carrier.\`Protocol\`<Cardinal>)`
8. `Set.init(minimumCapacity: some Carrier.\`Protocol\`<Cardinal>)`
9. `Dictionary.reserveCapacity(_: some Carrier.\`Protocol\`<Cardinal>)`
10. `Dictionary.init(minimumCapacity: some Carrier.\`Protocol\`<Cardinal>)`

**Tier 3 — concrete-type Array/String inits** (do third):

11. `Swift.Array.init(repeating:count: some Carrier.\`Protocol\`<Cardinal>)` (Swift. qualifier per shadow rule)
12. `Swift.Array.init(_unsafeUninitializedCapacity: some Carrier.\`Protocol\`<Cardinal>, initializingWith:)` (Swift. qualifier)
13. `ContiguousArray.init(_unsafeUninitializedCapacity: some Carrier.\`Protocol\`<Cardinal>, initializingWith:)` (sibling)
14. `String.init(repeating: String, count: some Carrier.\`Protocol\`<Cardinal>)`

**Decision deferred**:

- **Should the `Array` shadow concern argue for protocol-level placement of init overloads?** `init(repeating:count:)` doesn't exist on `RangeReplaceableCollection` as a protocol method — only as concrete on Array, ContiguousArray, ArraySlice. Per-type sibling overloads remain the only path. Defer to implementation: if a protocol-level init overload can be added via `extension RangeReplaceableCollection where Self: ...`, that's preferable. Otherwise per-type with `Swift.Array` qualifier.
- **Should we add `extension Set.SymmetricDifference` or other less-common Set/Dictionary init overloads?** Skip until call-site evidence appears.

### Verification protocol for the implementation handoff

Per the recent reserveCapacity arc lesson:

1. **Protocol-level placement first**. Only fall back to per-type when the stdlib method has no protocol home.
2. **Empirical reproduction**: each new overload tested in at least one consumer context that previously used `Int(bitPattern:)`. Verify the overload is found via overload resolution (no silent fall-through to the stdlib `Int` form).
3. **The `~Copyable Self` extension context** is the resolution-stress case — verify the new protocol-level overloads work where the per-type overloads silently failed during the reserveCapacity arc.
4. **Swift.Array qualifier** on any `extension Array:` for stdlib-intent (defensive against the `Array_Primitives.Array` shadow).
5. **Per-overload @inlinable** so consumers can inline the typed bridge across module boundaries (no perf regression).

## References

- `swift-cardinal-primitives` @ `3ffa3cd` — RangeReplaceableCollection consolidation (the precedent for protocol-level placement)
- `swift-binary-parser-primitives` @ `4178d1c6` — Array shadow fix (`extension Swift.Array: Binary.Parseable`) (the precedent for Swift.Array qualification)
- `swift-cardinal-primitives` @ `196e5f4` (initial ContiguousArray sibling), `afa9e3c` (initial Swift.Array qualifier) — superseded by the RRC consolidation; retained for history
- `swift-sequence-primitives` @ `1f8965a` — first consumer to use RRC overload in the resolution-stress `~Copyable Self` extension context
- `/Users/coen/Developer/HANDOFF-remove-binary-input-view-primitives.md` — Pass 4 outcome record, particularly the (4) row documenting the protocol-level lesson
- `existing-infrastructure` skill [INFRA-001–005] — institute SLI architecture catalog
- `byte-discipline` skill [API-BYTE-007] — clarifies that SLI is for extensions ON stdlib types ACCEPTING institute types (not the reverse)
- Stdlib `RangeReplaceableCollection` documentation — Apple Developer / `swiftlang/swift` `stdlib/public/core/RangeReplaceableCollection.swift`
- Swift Evolution: SE-0470 (BidirectionalCollection.removeLast(_:)) and surrounding stdlib evolution for the host-level analysis
