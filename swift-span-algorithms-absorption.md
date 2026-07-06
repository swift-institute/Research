# swift-span-algorithms Absorption

<!--
---
version: 1.0.0
last_updated: 2026-07-06
status: RECOMMENDATION
---
-->

## Context

**Trigger**: Principal request (2026-07-06) to research `https://github.com/Dave861/swift-span-algorithms` and determine what the ecosystem can absorb of it — in particular into `swift-span-primitives`. The upstream's initial release (0.1.0) is dated the same day as this analysis.

**Tier**: 2 (cross-package routing across L1 primitives; reversible; no hard precedent set). Prior-art survey obligation per [RES-021] is satisfied by the upstream inventory itself plus the SE-proposal cross-references below.

**Method**: Two parallel primary-source inventories ([RES-034]) — (a) a full read of the upstream clone (every `Sources/` file, `docs/DESIGN.md`, tests, benchmarks), (b) an ecosystem sweep over `swift-span-primitives` and the ~200 sibling primitives packages for existing coverage of each upstream algorithm family. Both reports were sample-verified against source before synthesis ([RES-013a]): upstream — `@_lifetime(copy self)` at `Span+Trimming.swift:17`, cursor shape at `Span+Cursors.swift:25-36`, the 0/8/0 `@available` asymmetry, generic-typed-throws signatures at `Span+Search.swift:17-19`; internal — six spot checks (algorithm-free `swift-span-primitives/Sources`, `Iterator.Chunk` presence, zero `forEach{Chunk,Window,Split}` hits ecosystem-wide, zero Span rows in the comparison SLI, the three `Swift.Span.Iterator*` SLI files, 19-consumer count). All claims below tagged `[Verified: 2026-07-06]` were checked against source on that date.

**Step-0 internal grep ([RES-019])**: no prior internal research references this upstream (repo name, `SpanAlgorithms`, or author). Governing internal prior research: `swift-span-primitives/Research/span-capability-stdlib-alignment-and-escapable.md` (Tier 2 RECOMMENDATION — read capability stdlib-aligned and settled; mutable linchpin gated on soundness, since CONFIRMED-concrete by `Experiments/mutablespan-self-vend-soundness` but not landed in `Sources/`).

**Skills loaded ([RES-033])**: swift-institute-core, swift-institute ([ARCH-LAYER-*]), primitives ([PRIM-*]), memory-safety ([MEM-SPAN-*], [MEM-LIFE-*]), code-surface ([API-NAME-*], [API-ERR-*], [API-IMPL-*]), swift-package-heritage ([HERITAGE-*]); research-process governs the document.

**Constraints**: [ARCH-LAYER-011] — absorption means re-implementation inside the institute, never a dependency on the upstream. No tags this phase. This document authorizes no `Sources/` changes; every absorption item below is a separately-dispatched implementation decision.

## Question

Which parts of `Dave861/swift-span-algorithms` 0.1.0 should the Swift Institute ecosystem absorb, in what form, and where — specifically, does any of it belong in `swift-span-primitives`?

## Upstream Inventory

`[Verified: 2026-07-06]` against a clone of `https://github.com/Dave861/swift-span-algorithms.git` at `307af90` (sole commit; author David Retegan / Dave861).

**Shape**: single-target SwiftPM package `SpanAlgorithms`; swift-tools 6.2; Apache-2.0; zero library dependencies; `.strictMemorySafety()` + `.enableExperimentalFeature("Lifetimes")` + `MemberImportVisibility` (`Package.swift:24-28`). v0.1.0 released 2026-07-06 (`CHANGELOG.md:10`); pre-1.0 disclaimer in README.

**Design tiers** (`docs/AlgorithmTemplate.md:24-34`, `README.md:51-70`):

| Tier | Definition | APIs |
|---|---|---|
| 1 | Results are `Int`/`Bool`/`Element`, or sub-spans visited through a non-escaping closure; no annotations | `firstIndex(where:/of:)`, `lastIndex(where:/of:)`, `contains(_:)`, `min()`, `max()`, `elementsEqual(_:)`, `lexicographicallyPrecedes(_:)`, `forEachChunk(ofCount:_:)`, `forEachWindow(ofCount:_:)`, `forEachSplit(separator:/where:...)` |
| 2 | Returns a narrowed `Span` view of `self`; `@_lifetime(copy self)` (`borrow self` on `MutableSpan`/`InlineArray`) | `trimming(while:)`, `trimmingPrefix(while:)`, `trimmingSuffix(while:)` |
| 3 | Pull-style `~Escapable` cursor structs; factory `@_lifetime(copy self)`, `next()` is `@_lifetime(&self) mutating -> Span<Element>?` | `SpanChunkCursor`, `SpanWindowCursor`, `SpanSplitCursor` via `chunkCursor(ofCount:)` etc. |

Carriers: everything ×4 — `Span` (canonical implementations), `MutableSpan` (hand-written one-line forwarders through SE-0467 `.span`, `MutableSpan+Forwarding.swift`), `InlineArray` (same forwarding, macOS-26-gated), `RawSpan` (byte-typed subset via `unsafe _unsafeView(as: UInt8.self)`, `RawSpan+Bytes.swift:36-38`).

**Notable properties**:

- Generic typed throws throughout: every closure-taking algorithm is `<E: Error> ... throws(E)` — e.g. `func firstIndex<E: Error>(where predicate: (Element) throws(E) -> Bool) throws(E) -> Int?` (`Span+Search.swift:17-19`). Unusually aligned with [API-ERR-001].
- `docs/DESIGN.md` is a compiler-verified lifetime spike (Apple Swift 6.2 `swiftlang-6.2.0.19.9`, re-verified on a 6.4 beta): `@_lifetime` (underscored) is the working spelling; `~Escapable`-returning methods never infer lifetime dependence; **the `Lifetimes` feature is definition-side only** — a two-module library-evolution experiment proved a consumer compiled *without* the feature typechecks clean, and the emitted `.swiftinterface` auto-guards `@_lifetime` vs `@lifetime` across compiler versions (`docs/DESIGN.md:59-72`).
- Test strategy: 88 Swift Testing tests (oracle-based against `Array`/`Sequence` equivalents + seeded `SplitMix64` randomized corpus) plus **8 compile-fail fixtures** driven by `Scripts/compile-fail-tests.sh` — each fixture typechecked *as a consumer sees the package* (`swiftc -typecheck`, no `Lifetimes` flag) with an `// EXPECTED-ERROR:` substring assertion; documented nuance that some escape violations defer past `-typecheck` to SIL passes when the feature is enabled (`docs/DESIGN.md:74-83`).
- Benchmark gate: `package-benchmark` suite asserting `mallocCountTotal == 0` at every percentile p0–p99 for all Span/RawSpan paths; contribution rule requires a zero-malloc (or justified) benchmark per shipped algorithm (`CONTRIBUTING.md:11-13`). Headline: at 10M elements, span-native split ≈ 2.3× the throughput of allocating `Array.split` (`README.md:96-98`).
- Defect noted in passing (not load-bearing here): `@available(macOS 26, ...)` appears on all 8 `InlineArray` extensions but on none of the `MutableSpan`/`RawSpan` files despite the README stating the same floor for `MutableSpan` (`README.md:76-78`) — 0/8/0 count verified.
- No stated lineage to Apple's swift-algorithms/swift-collections; SE-0516 (`BorrowingSequence`) cited as the future generic layer, SE-0467 for `MutableSpan.span`.

## Ecosystem State

`[Verified: 2026-07-06]` per the sweep + sample checks.

**`swift-span-primitives` is capability-only.** Five products (`Span Primitive`, `Span Protocol Primitives`, `Span Raw Primitives`, umbrella, test support). Its entire surface: the unbound alias `public typealias Span = Swift.Span` (`Sources/Span Primitive/Span.swift:19`) + `Span.Mutable = Swift.MutableSpan`; the unified read capability `Span.Protocol` (`~Copyable, ~Escapable`, sole requirement `var span: Swift.Span<Element> { @_lifetime(borrow self) get }`, `__Span.Protocol.swift:122`); its mutable refinement `Span.Mutable.Protocol` (`__Span.Mutable.Protocol.swift:68-93`); the read linchpin `Swift.Span: Span.Protocol` (`Swift.Span+Span.Protocol.swift:28-38`); and the byte-domain views `Span.Raw` / `Span.Raw.Mutable` (Copyable, `Hashable`, `@unchecked Sendable`, buffer-pointer bridging, `withRebound`). **Zero algorithm code** — no search, min/max, comparison, trimming, split, chunk, or cursor logic anywhere in its `Sources/` (grep-verified). The `Swift.MutableSpan: Span.Mutable.Protocol` linchpin is deliberately absent: soundness CONFIRMED (concrete, `extracting(...)` self-vend body, debug+release, cross-module) by `Experiments/mutablespan-self-vend-soundness`, but the governing research doc explicitly does not authorize the `Sources/` change.

**The algorithm families exist elsewhere, over other carriers**:

| Family | Existing institute surface | Carrier | Span coverage |
|---|---|---|---|
| Chunked/pull iteration | `Iterator.Chunk` (`swift-iterator-primitives/Sources/Iterator Chunk Primitives/Iterator.Chunk.swift:26`), protocol `__IteratorChunkProtocol` with bulk `next(maximumCount:) -> Span<Element>` + `skip(by:)`; `Swift.Span.Iterator` / `Swift.Span.Iterator.Batch` (`swift-sequence-primitives` SLI); `Span.Protocol+Iterable` bridge (`swift-memory-iterator-primitives`) | Span-native | **COVERED** |
| forEach / reduce / contains / first terminals | `Iterable+ForEach/Reduce/Contains/First` (`swift-iterator-primitives/Sources/Iterable/`) — predicate forms, driven by the bulk span loop | Any `Iterable` | Partial (no index-returning search) |
| Element search (`firstIndex(of:)`) | `Collection+Byte.firstIndex(of:)/contains` (`swift-byte-collection-primitives`, `Collection+Byte.swift:112-144`) | `Swift.Collection` | **NONE on Span** |
| Min/max | `Collection.Min` / `Collection.Max` Property-accessor families (`swift-collection-primitives`), `Sequence.min/max(count:)` (`swift-standard-library-extensions`) | `Collection.Protocol` / `Sequence` | **NONE on Span** |
| Lexicographic compare / equality | `Comparison.Protocol` SLI rows for `Array`, `ArraySlice`, `ContiguousArray`, `UnsafeBufferPointer`, … (`swift-comparison-primitives`, all `#if swift(<6.4)`-gated) | many carriers | **NONE on Span/MutableSpan** (0 SLI files, verified) |
| Trimming | `Collection.trimming(_:)/trimming(where:)` incl. two-ended `BidirectionalCollection` form (`swift-standard-library-extensions/Collection.swift:138-228`); byte-domain lift (`Collection+Byte.swift:42-91`) | `Collection` | **NONE on Span**; ecosystem verb is `trimming(where:)`, never `trimming(while:)` |
| Split / window | `[UInt8].split(separator:)` (allocating, `swift-binary-primitives`), `Collection.chunked(into:)` (allocating) | Array/Collection | **NONE lazy/span-native**; zero `forEachSplit`/`forEachWindow`-shaped hits ecosystem-wide |
| Span narrowing | `Swift.Span+extracting.swift` typed `extracting(first:/droppingFirst:)` + `Ordinal`/`Cardinal` subscripts (`swift-sequence-primitives` SLI) | Span | Present (narrowing only) |

**Dependency-graph fact**: the 19 consumers of `swift-span-primitives` are all infrastructure builders (buffer/storage/memory/parser/cursor tier); none of the algorithm-owning packages (`swift-comparison-primitives`, `swift-collection-primitives`, `swift-iterator-primitives`, `swift-standard-library-extensions`) depends on it. The algorithm layer and the span capability are currently **disjoint** in the graph. Because `Span` is an unbound alias for `Swift.Span`, algorithm packages can extend the bare stdlib type with no new dependency; only `Span.Protocol`-generic surfaces (reaching `Span.Raw`, buffers, storages) require the dep.

**Placement precedent**: iteration is deliberately kept OUT of `Span.Protocol`'s own package and attached from downstream packages (`Span.Protocol+Iterable.swift:11-19` comment, `[MOD-035]`; same shape in `swift-memory-sequence-primitives`). [DS-030] codifies the discipline: behavior is written once over seam protocols, never re-implemented per family. [INFRA-107] ranks bulk operations and iteration infrastructure above hand-rolled loops.

## Analysis

### The structural mismatch — what "absorption" can and cannot mean

The upstream ships a **per-type × per-algorithm matrix**: 4 carrier types × ~15 algorithms, with the `MutableSpan` and `InlineArray` columns hand-written as per-method forwarders through `.span` (`MutableSpan+Forwarding.swift` alone is 10+ forwarders). The institute architecture factors this matrix: algorithms are written **once** against `Span.Protocol` (or attach as `Iterable` terminals over the bulk iterator), and each carrier pays **one conformance**, not one forwarder per algorithm. `Swift.Span` already conforms; `Span.Raw` already conforms (`Span.Raw.swift:117`); every storage/buffer type conforms.

Absorbing the upstream's *shape* (extensions × 4 types) would therefore be architecture-regressive. What is absorbable is:

1. its **algorithm capability list** — as gap evidence, re-derived into institute form;
2. the **linchpin conformances** its forwarder columns imply (`MutableSpan`, `InlineArray`);
3. its **process/verification assets** (compile-fail methodology, zero-malloc gate, the `@_lifetime` non-poisoning proof).

### Heritage adjudication ([HERITAGE-001])

| Condition | Holds? |
|---|---|
| Material lineage (production code closely parallels upstream) | **No** — every absorbed item is re-derived: protocol-generic instead of per-type, typed indices instead of `Int`, iterator manner-variants instead of `forEach*` closures + `SpanXCursor` structs, `trimming(where:)` instead of `trimming(while:)` |
| Community/consumer overlap | Partial (span users generally) |
| License compatibility | Yes (Apache 2.0) |
| Upstream non-owned | Yes |

Material lineage fails → **[HERITAGE-006] independent re-implementation** is the correct shape. No fork, no LICENSE attribution obligation (no derivative-works claim). Attribution record = this research document; where a family is absorbed, its implementing package MAY carry a "related work" research/README note citing the upstream. No implementation body should be ported verbatim.

### Contextualization ([RES-021])

The upstream's premise — "give the borrowed-view types the algorithm surface the stdlib gives collections" — is universal-adoption reasoning. Concretized in the institute's type system, parts of the premise dissolve:

- **`MutableSpan`/`InlineArray` forwarders are not a gap** — they are what the absence of a protocol looks like. `Span.Mutable.Protocol` refines `Span.Protocol`; a read-side conformance makes every `Span.Protocol` algorithm reach the carrier with zero per-algorithm cost. Deliberate architecture, not missing surface.
- **`RawSpan` byte algorithms are not a gap** — `Span.Raw` (institute's raw view) vends `span: Swift.Span<Byte>` through `Span.Protocol`, so byte-typed algorithms reach it via the protocol; the byte discipline ([API-BYTE-*], element `Byte` not `UInt8`) routes this without the upstream's `unsafe _unsafeView(as:)` reinterpretation at each call site.
- **Chunked visitation/cursors are not a gap** — `Iterator.Chunk` + `Swift.Span.Iterator.Batch` + `Iterable.forEach` already cover them. The upstream's Tier-3 cursor design (`~Escapable` struct, `@_lifetime(&self) next() -> Span<Element>?`, factory `@_lifetime(copy self)`) is structurally the same design the institute reached independently — convergent external validation of the `Iterator.Chunk`/SE-0516 shape, worth recording, not absorbing.
- **`Int`-returning search** conflicts with the typed-index discipline ([IDX-*]; `Swift.Span+extracting.swift` already exposes typed `Ordinal`/`Cardinal` bridges). The absorbed form must adjudicate `Index<Element>`/`Ordinal` vs stdlib-mirroring `Int` at SLI tier — precedent exists for stdlib-mirroring names/shapes in SLI extensions of stdlib types (`Collection+Byte.firstIndex(of:)`), while institute-native surfaces take the `Iterable`-terminal shape. Naming re-verification per [API-NAME-007] required either way.

What survives contextualization as **genuine gaps**: index-returning search over spans, min/max over spans, `Comparison.Protocol`/equality rows for `Span`/`MutableSpan`, span-returning trimming, and lazy split/window iteration.

### Per-family adjudication

| # | Upstream family | Verdict | Institute form | Home |
|---|---|---|---|---|
| 1 | `firstIndex`/`lastIndex`/`contains` (search) | **ABSORB (gap)** | Index-returning search terminal(s); adjudicate typed `Index<Element>` vs SLI `Int`-mirroring at implementation; predicate forms exist (`Iterable+First/Contains`) — the delta is index-returning + `Equatable`-needle forms | `swift-iterator-primitives` (`Iterable` terminals) and/or span SLI in `swift-sequence-primitives` |
| 2 | `min()`/`max()` | **ABSORB (gap)** | Terminals over the bulk iterator (span carriers cannot take the `Collection.Protocol` route); align comparator vocabulary with `Collection.Min/Max` (`Order.Comparator`) | `swift-iterator-primitives`, vocabulary-aligned with `swift-collection-primitives` |
| 3 | `elementsEqual` / `lexicographicallyPrecedes` | **ABSORB (gap), gated** | `Comparison.Protocol` SLI rows for `Span`/`MutableSpan`, `#if swift(<6.4)`-gated like the existing 17 rows. **Gate**: whether `Comparison.Protocol` admits `~Escapable` conformers is unverified — verification spike required before implementation ([RES-035]; cf. the pre-SE-0499 Escapable requirement on stdlib `Hashable`/`Comparable`) | `swift-comparison-primitives` SLI |
| 4 | `trimming(while:)` family (span-returning) | **ABSORB (gap)** | `trimming(where:)` / prefix/suffix variants (ecosystem verb), `@_lifetime(copy self)`, returning `Span<Element>`; upstream's DESIGN.md non-poisoning proof + the in-tree `extracting` bridges establish the pattern is shippable | Beside `Swift.Span+extracting.swift` (`swift-sequence-primitives` SLI) — or `swift-standard-library-extensions`; adjudicate at implementation |
| 5 | `forEachChunk` + `SpanChunkCursor` | **NO ABSORB (covered)** | `Iterator.Chunk`, `Swift.Span.Iterator.Batch`, `Iterable.forEach` already provide both push and pull forms | — |
| 6 | `forEachWindow` + `SpanWindowCursor` | **ABSORB (gap)** | `Iterator.Window` — manner-variant noun per [API-NAME-001b] (sibling of `Iterator.Chunk`); `Iterable` terminals give the closure form for free | `swift-iterator-primitives` |
| 7 | `forEachSplit` + `SpanSplitCursor` | **ABSORB (gap)** | `Iterator.Split` — manner-variant sibling; separator (`Equatable`) + predicate forms; `maxSplits`/`omittingEmptySubsequences` semantics match `Sequence.split` (upstream matches these exactly — keep that oracle); options shape per [API-IMPL-014] | `swift-iterator-primitives` |
| 8 | `RawSpan` byte ops | **NO ABSORB (structurally covered)** | Byte algorithms reach `Span.Raw` via `Span.Protocol` (`span: Span<Byte>`); needle search lands with #1 | — |
| 9 | `MutableSpan` forwarders | **NO ABSORB (superseded)** | Land the read-side linchpin instead — one conformance dissolves the entire forwarding file | `swift-span-primitives` (see below) |
| 10 | `InlineArray` forwarders | **NO ABSORB (superseded)** | One `InlineArray: Span.Protocol` conformance (macOS-26-gated; witness = stdlib `.span`, whose existence upstream's forwarders demonstrate) | `swift-span-primitives` (see below) |
| 11 | Process assets | **ABSORB (technique)** | (a) consumer-view compile-fail suite for `~Escapable` misuse (`swiftc -typecheck` without `Lifetimes`; the deferred-to-SIL nuance is the load-bearing detail) — candidate for testing-skill/Experiments adoption; (b) `mallocCountTotal == 0` benchmark gate via `package-benchmark` — candidate for the benchmark skill; (c) the `.swiftinterface` `@_lifetime`/`@lifetime` auto-guard finding — relevant mitigation evidence for [MEM-LIFE-004] version skew | Routed as inbox observations → skill-lifecycle, not code |

### What `swift-span-primitives` itself absorbs

**Nothing algorithmic.** Its strict mission ([ARCH-LAYER-010]) is the span capability; the ecosystem precedent ([MOD-035]-comment, [DS-030]) attaches behavior downstream. The answer to "what can swift-span-primitives absorb" is the two **linchpin conformances** the upstream's forwarder columns motivate:

1. **`Swift.MutableSpan` read-side conformance to `Span.Protocol`** — witness = SE-0467 `.span` (upstream verified it typechecks with no experimental feature, `docs/DESIGN.md:51-57`). This is a strict subset of the already-soundness-confirmed mutable linchpin and independently useful: it gives every `Span.Protocol` algorithm to `MutableSpan` with zero forwarders. Whether to land read-only first or the full `Span.Mutable.Protocol` linchpin (soundness CONFIRMED via the `extracting(...)` body) remains governed by `span-capability-stdlib-alignment-and-escapable.md` — this document adds the absorption motivation, not a new authorization. Conformance spike per [RES-035] before landing (the stdlib getter must witness the `@_lifetime(borrow self)` requirement shape — unverified).
2. **`InlineArray: Span.Protocol`** — macOS-26-gated; same one-conformance-replaces-N-forwarders payoff. Home: the `Span Protocol Primitives` target (conformance in the protocol's own package — no `@retroactive` per [API-IMPL-018]). Conformance spike per [RES-035] before landing (unverified).

### Placement options considered ([RES-005], [RES-036])

| Option | Shape | Verdict |
|---|---|---|
| A — absorb algorithms into `swift-span-primitives` | Capability package grows an algorithm surface | **Reject**: violates strict mission; contradicts the in-tree precedent of attaching behavior downstream; would invert the [DS-030] write-once discipline |
| B — route each family to its domain owner (chosen) | Search/min-max/window/split → iterator tier; comparison → comparison SLI; trimming → sequence SLI / stdlib-extensions; linchpins → span package | **Recommend**: structurally correct factoring; bridges the currently-disjoint algorithm↔span layers along existing seams; zero new packages |
| C — new package mirroring the upstream (`swift-span-algorithm-primitives`) | One package owning all span algorithms | **Reject** per [DS-020]: composition over existing packages does not fail — every family has a natural existing home; a span-algorithms package would also re-couple families ([MOD-DOMAIN]) that belong to different domains (iteration vs comparison vs trimming) |

Option B is recommended on structural grounds; diff-size was not a selection criterion ([RES-036]).

## Outcome

**Status**: RECOMMENDATION (no `Sources/` changes authorized; each item is a separate implementation dispatch).

**Recommended absorptions**, in structural priority order:

1. `swift-span-primitives`: land the linchpin conformances — `Swift.MutableSpan` (read side; sequencing with the mutable linchpin per the existing governing research) and `InlineArray: Span.Protocol` — each behind a [RES-035] conformance spike. This is the highest-leverage item: it is what makes every other absorbed algorithm reach all carriers for free.
2. `swift-iterator-primitives`: `Iterator.Split` and `Iterator.Window` as manner-variant siblings of `Iterator.Chunk`, with `Iterable`-terminal closure forms. Split is the family with zero ecosystem coverage and demonstrated ~2.3× win over allocating `Array.split` (upstream benchmark, M4, 10M elements — supporting evidence, machine-specific).
3. `swift-iterator-primitives`: index-returning search + min/max terminals (typed-index adjudication at implementation).
4. `swift-comparison-primitives` SLI: `Span`/`MutableSpan` lexicographic rows — after the `~Escapable`-conformer spike.
5. `swift-sequence-primitives` SLI (or stdlib-extensions): span-returning `trimming(where:)` family.
6. Process assets (compile-fail methodology; zero-malloc benchmark gate) — routed via workspace inbox to the testing/benchmark skill pipeline.

**Explicitly not absorbed**: the per-type forwarding matrix; `forEachChunk`/chunk cursors (covered); `RawSpan`-specific algorithm extensions (covered via `Span.Raw`/`Byte` discipline); the upstream's `SpanXCursor` compound-named types ([API-NAME-001]); `trimming(while:)` verb; `Int`-index surface as institute-native (SLI-tier mirroring remains an open per-item choice); any dependency on the upstream package ([ARCH-LAYER-011]).

**Heritage**: [HERITAGE-006] independent re-implementation; this document is the attribution record.

## Residual

Directions (not carried premises — nothing below is asserted true; each is a gate on its item, unverified until its spike runs):

- Does `Comparison.Protocol` admit `~Escapable` conformers on 6.3.2? (Gates item 4; spike ≤1h against the comparison package.)
- Does the stdlib `MutableSpan.span` / `InlineArray.span` getter satisfy `Span.Protocol`'s `@_lifetime(borrow self)` requirement shape as a witness? (Gates item 1; conformance spike per [RES-035].)
- Typed `Index<Element>`-vs-`Int` for span search returns; exact home for span trimming (sequence SLI vs stdlib-extensions); target decomposition for `Iterator.Split`/`Iterator.Window` ([MOD-*]). (Implementation-time adjudications.)

## References

- Upstream: [Dave861/swift-span-algorithms](https://github.com/Dave861/swift-span-algorithms) @ `307af90` (0.1.0, 2026-07-06) — `Package.swift`, `README.md`, `CHANGELOG.md`, `docs/DESIGN.md`, `docs/AlgorithmTemplate.md`, `Sources/SpanAlgorithms/*`, `Tests/CompileFail/*`, `Benchmarks/results/latest.md`. [Verified: 2026-07-06]
- Internal: `swift-span-primitives/Research/span-capability-stdlib-alignment-and-escapable.md` (Tier 2 RECOMMENDATION); `swift-span-primitives/Experiments/mutablespan-self-vend-soundness/EXPERIMENT.md` (CONFIRMED-concrete); `swift-span-primitives/Experiments/span-typealias-hosting/EXPERIMENT.md` (CONFIRMED). [Verified: 2026-07-06]
- Internal surfaces cited with file:line throughout: `swift-iterator-primitives` (Iterator Chunk Primitives, Iterable terminals), `swift-sequence-primitives` (Span SLI), `swift-comparison-primitives` (SLI rows), `swift-collection-primitives` (Min/Max), `swift-standard-library-extensions` (Collection trimming), `swift-byte-collection-primitives` (Collection+Byte), `swift-binary-primitives` (Array+Bytes). [Verified: 2026-07-06]
- Swift Evolution: [SE-0447 Span](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) (deferred `ContiguousStorage` = `Span.Protocol` precedent), [SE-0467 MutableSpan](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0467-MutableSpan.md), [SE-0516 BorrowingSequence] (upstream's cited future generic layer; institute analog `__IteratorChunkProtocol`), SE-0507 (borrow/mutate accessors — forward direction per the span capability research).
