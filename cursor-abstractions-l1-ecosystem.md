# Cursor Abstractions Across the Institute L1 Ecosystem

<!--
---
version: 1.8.0
last_updated: 2026-05-18
status: SUPERSEDED
tier: 3
scope: ecosystem-wide
---
-->

> **SUPERSEDED 2026-05-18 by [`cursor-shape-a-vs-three-worlds.md`](./cursor-shape-a-vs-three-worlds.md) v1.2.0 IMPLEMENTED.**
>
> The Three-Worlds architecture in this doc was chosen against a phantom
> alternative. The stated Shape A rejection — "Swift offers no way to make
> Escapable conditional on a generic parameter" — is empirically refuted by
> `Tagged<Tag, Underlying>` at `swift-tagged-primitives`. The narrower true
> Swift constraint (no Mode-discriminator conditional conformance) doesn't
> block Shape A because Storage-as-borrow-carrier — leveraging the
> institute's existing `Ownership.Borrow.\`Protocol\`` framework
> (`ownership-borrow-protocol-unification.md` v1.0.0) — sidesteps the
> discriminator entirely.
>
> The implementation arc landed 2026-05-18 in two refinements over the same
> day. **Refinement 1 (morning, v1.1.0 DECISION shape)**: `Byte.Borrowed`
> landed in `swift-byte-primitives` (Case B conformer parallel to
> `String.Borrowed`); `swift-cursor-primitives` reshaped as a two-generic
> `Cursor<Storage: ~Copyable & ~Escapable, PositionTag: ~Copyable>` generic
> struct (replacing the prior `Cursor.Span<DomainTag>` enum-namespaced
> shape); `Binary.Bytes.Input.View` / `Lexer.Scanner` retargeted to
> `Cursor<Byte.Borrowed, Byte>` / `Cursor<Byte.Borrowed, Text>`.
> **Refinement 2 (afternoon, v1.2.0 IMPLEMENTED shape)**: principal observed
> the two-generic shape was structurally redundant — when `DomainTag`
> already conforms to `Ownership.Borrow.\`Protocol\`` with a specific
> `Borrowed` type, the explicit Storage parameter restated information
> already encoded by the conformance. The single-generic refinement:
> `Cursor<DomainTag: Ownership.Borrow.\`Protocol\` & ~Copyable>` with storage
> derived as `DomainTag.Borrowed`. Call sites collapse from
> `Cursor<Byte.Borrowed, Byte>(span)` to `Cursor<Byte>(span)` and from
> `Cursor<Byte.Borrowed, Text>(...)` to `Cursor<Text>(...)`. Added `Text:
> Ownership.Borrow.\`Protocol\`` with `typealias Borrowed = Byte.Borrowed`
> (text storage IS bytes; principled domain-identity statement). BENCH-011
> replay GREEN at parity across all probes after BOTH refinements.
>
> This doc's SLR, prior art, theoretical grounding, formal semantics, and
> empirical validation sections survive as historical analysis input. The
> Three-Worlds architectural verdict is superseded; see
> `cursor-shape-a-vs-three-worlds.md` v1.2.0 §Implementation Outcomes for
> the landing details.
>

## Context

The Swift Institute's L1 primitives layer hosts a growing population of *cursor-like* primitives — types that combine contiguous byte storage with an in-storage position and a peek/advance/consume API. These types power every parser, lexer, serializer, and binary-format reader/writer in the ecosystem. Their structural shape is therefore foundational: a wrong choice replicates across every downstream consumer.

Three prior efforts have probed the design space without converging:

| Doc | Date | Status | Verdict |
|---|---|---|---|
| `byte-cursor-primitive-unification.md` v1.0.0 / v1.1.0 | 2026-05-14 | DEFERRED | Parking-lot entry from streaming-deserialize audit; classified as `[RES-018]` case (a) with composition check pending. |
| `byte-cursor-primitive-unification.md` v1.2.0 | 2026-05-17 | DECISION — principled refuse (RETRACTED same day) | Phase 1 comparative shape analysis identified the two `~Escapable` Span-cursors as mechanically similar but rejected unification on three points: `[API-NAME-001c]` precedent, position-type divergence, and the alleged ~Copyable & ~Escapable protocol-novelty cost. Principal review found all three structurally defective. |
| `byte-cursor-primitive-unification.md` v1.3.0 | 2026-05-17 | RECOMMENDATION → IN_PROGRESS (downgraded same day) | Re-executed Phase 1 with corrected lenses; the empirical decomposition probe surfaced Shape F (parameterize over `Tagged<DomainTag, Ordinal>` position). The Outcome was downgraded the same day after the prior-art grep surfaced **two load-bearing artifacts the analysis did not engage**: (a) `Binary.Cursor` in `swift-binary-primitives` as a *third* cursor abstraction, (b) `Lifetime Dependent Borrowed Cursors.md` (RECOMMENDATION, 2026-01-19, ~1200 lines) as prior research arguing protocol-based dispatch is *structurally required* under Swift 6.x. |

The 2026-05-17 downgrade explicitly escalated the question to a Tier 3 `/research-process` arc — the present document. Wave 1 Items 2, 3, 4, and 5 of `HANDOFF.md` are on hold pending this arc's outcome:

- Item 2 (D5 `Binary.Bytes.Input` vs `Byte.Input` typed-input unification)
- Item 3 (R3 `Word16.Protocol` / `Word32.Protocol` / `Word64.Protocol` viability)
- Item 4 (D6 serializer-side parallel extraction)
- Item 5 (F2 non-Byte conformers proliferation)

The user's stated preference (2026-05-17): *"I'd love to have cursor-primitives if that's the principally correct thing to do, and to then re-use that all over in accordance with our decomposition and domain-modularization approach."* The principled answer wins regardless.

This arc applies Tier 3 rigor per `[RES-020]`: systematic literature review per `[RES-023]`, prior art survey per `[RES-021]`, theoretical grounding per `[RES-022]`, formal semantics per `[RES-024]`, and empirical validation per `[RES-025]`.

## Research Questions

Three research questions structure the analysis. Each is answered by the data; the Outcome consolidates the answers.

**RQ1**: What is the complete population of cursor-like primitives in the institute L1 ecosystem (swift-primitives), classified by ownership × mutability × storage × position-type axes?

**RQ2**: Under Swift 6.3+ type-system constraints (`~Copyable`, `~Escapable`, `@_lifetime`, SE-0503 suppressed associated types), what unification is structurally possible? Where the 2026-01-19 doc argued *structurally required* Two Worlds, does that argument survive current language facilities?

**RQ3**: Where does external prior art (Rust, Haskell, SwiftNIO, swift-parsing, academic literature on iteratees / parser combinators / linear and affine types / region types) inform the institute's L1 cursor design space?

## SLR Methodology

Per `[RES-023]` Kitchenham-style review.

### Search strategy

**Internal corpus** (per `[RES-019]` Step-0):

- `grep -rl <keyword> /Users/coen/Developer/swift-institute/Research/`
- `grep -rl <keyword> /Users/coen/Developer/swift-primitives/*/Research/`
- Mechanical scan: `grep -rnE 'public struct [A-Za-z_]+: *~Copyable, *~Escapable|public struct [A-Za-z_]+: *~Escapable, *~Copyable' /Users/coen/Developer/swift-primitives/*/Sources/`
- Mechanical scan: `grep -rnE 'Span<UInt8>|Span<U?Int8>' /Users/coen/Developer/swift-primitives/*/Sources/`
- Mechanical scan: cursor / scanner / pull-stream / reader / writer / cursor-shaped names across L1, L2, L3 source trees

**External corpus**:

- Swift Evolution proposals (SE-0410 ownership, SE-0427 noncopyable generics, SE-0446 ~Escapable, SE-0447 Span, SE-0456 Span properties, SE-0465 nonescapable stdlib primitives, SE-0499 noncopyable protocols, SE-0503 suppressed associated types)
- Swift Forums proposal-review threads
- Academic primary sources: Kiselyov on iteratees, Hutton & Meijer "Monadic Parsing in Haskell", Swierstra & Duponcheel parser combinators, Tofte & Talpin region-based memory management 1997, Bernardy et al. Linear Haskell 2018
- Industry implementations: SwiftNIO `ByteBuffer`, Rust `std::io::Cursor`, Rust `bytes` crate (`Buf` / `BufMut`), Point-Free `swift-parsing`, Haskell `attoparsec` (incremental `Result`), Conduit / Pipes streaming

### Inclusion / exclusion criteria

**Include**:
- Sources discussing cursor abstractions over contiguous bytes (in-memory, owned or borrowed).
- Sources discussing lifetime-bounded borrowed access (Span-shaped, region-typed, lifetime-dependent).
- Sources discussing affine/linear typing of stateful streams.
- Source-grounded inventory at the institute L1 layer.

**Exclude**:
- Sources discussing higher-level stream processing (Iteratee variants beyond the cursor layer; CPS-transformed parsers) — referenced for cross-pollination but not load-bearing for the substrate decision.
- L3 cursor types (CSS Cursor, Async.Stream.Replay.Cursor) — not in scope for the L1 question; mentioned for cross-layer context only.

### Screening

Iterative screening surfaced **six distinct cursor-like primitives at L1**, two beyond the user-briefed three. Per the brief's *"Class-(c) escalation: if the inventory grep surfaces a fourth+ cursor abstraction that materially changes the design space, STOP and ask"* clause, the two additional findings (`Binary.Reader`, `Lexer.Pull.Stream`) were assessed: **neither materially changes the design space**.

- `Binary.Reader<Storage>` is a structural sibling of `Binary.Cursor<Storage>` — same package, same `Memory.Contiguous.Protocol & ~Copyable` Storage genericity, same `Index<Storage>` position discipline, same lifetime class. Fills the (owned, read-only, generic-Storage) cell adjacent to Binary.Cursor's (owned, read-write, generic-Storage). Reinforces the *owned reader-writer family*; does not introduce a new axis.
- `Lexer.Pull.Stream<Tokens>` is a *higher-layer composition* over `Lexer.Scanner` — it stores `var scanner: Lexer.Scanner` and parameterizes over a `Tokens: Lexer.Pull.Tokens` witness. It is a consumer of cursor primitives, not a cursor primitive itself in the substrate sense. Validates the layered-cursor pattern.

The inventory is therefore the union of the user-briefed three plus these two siblings, classified across four axes. No class-(c) escalation fires.

### Data extraction

For each primitive: package, file, line of declaration, generic parameters, Copyability / Escapability attributes, Sendability, position type, storage type, primary method surface, and lifetime annotations.

### Synthesis approach

The cursor space decomposes into four orthogonal axes (ownership, mutability, storage, position-type). The synthesis computes the cross-product, identifies occupied vs empty cells, evaluates each occupied cell for unification opportunity along the position-type axis, and ranks decision shapes by structural correctness against the institute's `[IMPL-INTENT]` / `[IMPL-COMPILE]` axioms.

## Inventory: Cursor-like Primitives in the L1 Ecosystem

Six cursor-like primitives are present at L1 as of HEAD on 2026-05-17:

| # | Primitive | Package | File | Copyability | Escapability | Storage | Position type | Mutability |
|---|-----------|---------|------|-------------|--------------|---------|---------------|------------|
| 1 | `Binary.Bytes.Input` | `swift-binary-parser-primitives` | `Binary.Bytes.Input.swift:45` | Copyable | Escapable | `[UInt8]` | `Index<UInt8>` | Read-only |
| 2 | `Binary.Cursor<Storage>` | `swift-binary-primitives` | `Binary.Cursor.swift:42` | ~Copyable | Escapable | `Storage: Memory.Contiguous.Protocol & ~Copyable where .Element == UInt8` | `Index<Storage>` (dual: reader + writer) | Read-write |
| 3 | `Binary.Reader<Storage>` | `swift-binary-primitives` | `Binary.Reader.swift:42` | ~Copyable | Escapable | `Storage: Memory.Contiguous.Protocol & ~Copyable where .Element == UInt8` | `Index<Storage>` | Read-only |
| 4 | `Binary.Bytes.Input.View` | `swift-binary-parser-primitives` | `Binary.Bytes.Input.View.swift:50` | ~Copyable | ~Escapable | `Span<UInt8>` | `Int` (raw, un-decomposed) | Read-only |
| 5 | `Lexer.Scanner` | `swift-lexer-primitives` | `Lexer.Scanner.swift:39` | ~Copyable | ~Escapable | `Span<UInt8>` | `Text.Position` = `Tagged<Text, Ordinal>` | Read-only |
| 6 | `Lexer.Pull.Stream<Tokens>` | `swift-lexer-primitives` | `Lexer.Pull.Stream.swift:54` | ~Copyable | ~Escapable | wraps `Lexer.Scanner` (composition over Span<UInt8>) | `Text.Position` (via Scanner) | Read-only structural-event |

Auxiliary types that compose with the cursor primitives (not cursors themselves, but relevant to the design space):

| Type | Package | Role |
|------|---------|------|
| `Text.Location.Tracker` | `swift-text-primitives` | Composable line/column overlay maintained external to a cursor; `Sendable, Equatable, Hashable` struct with `(line, lineStart)` state. |
| `Text.Position`, `Text.Count`, `Text.Offset` | `swift-text-primitives` | `Tagged<Text, Ordinal>` / `Tagged<Text, Cardinal>` / `Tagged<Text, Affine.Discrete.Vector>` typed-offset family. Same generic shape as `Index<Element>` family. |
| `Index<Element>` | `swift-index-primitives` | `Tagged<Element, Ordinal>` — the institute's typed-position substrate. `Element: ~Copyable`. |
| `Memory.Contiguous.Protocol` | `swift-memory-primitives` | The Storage protocol owned cursors are generic over. |
| `Parser.Protocol<Input, Output, Failure>` | `swift-parser-primitives` | `associatedtype Input: ~Copyable & ~Escapable` — host protocol for parsers over the cursor substrate. |
| `Sequence.Protocol`, `Sequence.Iterator.Protocol` | `swift-sequence-primitives` | `~Copyable & ~Escapable` protocols with `~Copyable & ~Escapable` associated `Iterator`. Reference points for the institute's mature `~Copyable & ~Escapable` protocol discipline. |
| `Input.Protocol` | `swift-input-primitives` | `~Copyable` (not `~Escapable`) protocol for owned cursors with backtracking; declares `Checkpoint: Comparable`. The borrowed Span-cursors do *not* conform — their position is positional, not checkpoint-restorable. |
| `Property.Inout`, `Property.Borrow` | `swift-property-primitives` | `~Copyable & ~Escapable` accessor patterns; not cursors but used inside cursor implementations. |

### Cross-domain L3 references (out of scope for the substrate decision, in scope for context)

| L3 cursor | Package | Composes with |
|-----------|---------|---------------|
| `JSON.Span.EventStream` | `swift-json` | Thin error-conversion wrapper around `Lexer.Pull.Stream<RFC_8259.Pull.Tokens>` |
| `Async.Stream.Replay.Cursor` | `swift-async` | Async-stream replay buffer cursor (distinct family — async, not byte-cursor) |
| CSS rendering cursors | `swift-css-html-render`, `swift-html-css-pointfree` | Style-traversal cursors (distinct family — DOM/CSS, not byte-cursor) |

These L3 cursors validate the layered approach: when the substrate is right at L1, L3 wraps it with domain-specific overlays. JSON.Span.EventStream is the canonical case — its sole content is `RFC_8259.Error` → `JSON.Error` rethrow wrapping.

## Analysis

### The four axes of cursor variation

The cursor design space resolves into four orthogonal axes:

#### Axis 1: Lifetime (Ownership)

**Owned** (Escapable): the cursor owns its storage and can be stored, returned, or transferred across scopes.

**Borrowed** (`~Escapable`): the cursor borrows its storage and is lifetime-bound to a `Span<UInt8>` source. Cannot escape the source's scope.

The axis is bound to the storage representation: a Span-backed cursor *must* be `~Escapable` because `Span<UInt8>` is itself `~Escapable`. An owned Storage<UInt8>-backed cursor *can* be Escapable (it owns the bytes through the Storage).

This is not a continuum but a discrete choice the type system enforces. Swift offers no "?Escapable" parameterization.

#### Axis 2: Mutability

**Read-only**: position-tracking + peek + advance + consume. Operations advance the cursor without producing data outside its borrowed extent.

**Read-write** (dual-index): position-tracking + read-side + write-side. The owned reader-writer cluster carries two indices (`readerIndex` + `writerIndex`) with the invariant `0 ≤ readerIndex ≤ writerIndex ≤ count`. The writable region is `storage[writerIndex..<count]`; the readable region is `storage[readerIndex..<writerIndex]`.

This is the SwiftNIO `ByteBuffer` model and the Rust `bytes` crate's `BufMut` model. The institute's `Binary.Cursor` implements this pattern directly.

#### Axis 3: Storage

**Span-backed** (`Span<UInt8>`): the universal stdlib-typed borrowed substrate. Lifetime-bound; `~Escapable`. All borrowed cursors share this substrate.

**Storage-protocol-backed** (`Storage: Memory.Contiguous.Protocol & ~Copyable where .Element == UInt8`): generic over institute Buffer / Memory storage abstractions. Allows the owned cursor cluster to ride on `Buffer.Heap`, `Buffer.Linear`, `Buffer.Aligned`, etc.

**Array-backed** (`[UInt8]`): the legacy stdlib-typed owned substrate. Used by `Binary.Bytes.Input`.

These three storage shapes are not interchangeable — each carries different ownership / lifetime / generic-genericity properties.

#### Axis 4: Position-type discipline

**Un-decomposed `Int`**: raw integer position. Used by `Binary.Bytes.Input.View`.

**Typed `Tagged<DomainTag, Ordinal>`**: the institute's typed-position discipline (per `[IMPL-002]`, `[INFRA-102]`). Realized as:
- `Index<Element>` = `Tagged<Element, Ordinal>` for typed indices over Element-tagged collections (`swift-index-primitives`, `Index.swift:38`)
- `Text.Position` = `Tagged<Text, Ordinal>` for text byte-offsets (`swift-text-primitives`, `Text.Position.swift:27`)
- `Index<Storage>` = `Tagged<Storage, Ordinal>` for binary-cursor positions over generic Storage (used by `Binary.Cursor` and `Binary.Reader`)

The two forms are structurally identical at the position-type level — `Tagged<X, Ordinal>` where `X` is the phantom domain tag. The phantom tag at `Text`, `Byte`, `Storage` carries the domain identity while the underlying numeric arithmetic stays in `Ordinal`.

**The "binary's raw Int is the un-decomposed analog" finding** (carried forward from byte-cursor v1.3.0): `Binary.Bytes.Input.View.position: Int` is structurally `Tagged<UInt8, Ordinal>.rawValue.rawValue` — implementation-historical, not principled. Its principled form is `Index<Byte>` = `Tagged<Byte, Ordinal>`, parallel to `Text.Position` = `Tagged<Text, Ordinal>`. (Verified at `swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift:54` — `public var position: Int`.)

### Cross-product analysis

The four axes generate a 2×2×3×2 = 24-cell cross-product. Occupied cells:

| Ownership | Mutability | Storage | Position type | Primitive |
|-----------|------------|---------|---------------|-----------|
| Owned (Copyable) | Read-only | `[UInt8]` | `Index<UInt8>` | `Binary.Bytes.Input` |
| Owned (~Copyable) | Read-write | `Storage: M.C.P & ~Copyable` | `Index<Storage>` | `Binary.Cursor<Storage>` |
| Owned (~Copyable) | Read-only | `Storage: M.C.P & ~Copyable` | `Index<Storage>` | `Binary.Reader<Storage>` |
| Borrowed (`~Escapable`) | Read-only | `Span<UInt8>` | `Int` (un-decomposed) | `Binary.Bytes.Input.View` |
| Borrowed (`~Escapable`) | Read-only | `Span<UInt8>` | `Text.Position` | `Lexer.Scanner` |
| Borrowed (`~Escapable`) | Read-only structural-event | wraps `Lexer.Scanner` | inherits `Text.Position` | `Lexer.Pull.Stream<Tokens>` |

Unoccupied cells of interest:
- (Borrowed `~Escapable`, Read-write, Span<UInt8>, *) — no use case yet. Writing into a borrowed span requires the source span to be mutable (`MutableSpan<UInt8>`), which changes the substrate.
- (Owned Copyable, Read-write, `[UInt8]`, *) — would be a Copyable reader-writer over Array; could exist but no consumer named.

Three structural clusters emerge:

**Cluster A — Owned ~Copyable reader-writer family** (Binary.Cursor + Binary.Reader). Generic over `Storage: Memory.Contiguous.Protocol & ~Copyable`. Index<Storage> position discipline. Live in `swift-binary-primitives`. `Escapable` because they own the storage; can be moved across scopes.

**Cluster B — Borrowed ~Escapable read-only Span-cursor family** (Binary.Bytes.Input.View, Lexer.Scanner, and indirectly Lexer.Pull.Stream wrapping Scanner). Hard-coded Span<UInt8> substrate. Differ on position-type discipline (raw Int vs Tagged<Text, Ordinal>) and on domain overlays.

**Cluster C — Owned Copyable input family** (Binary.Bytes.Input). Array-backed, Sendable, Copyable. Used by the older Parser.Parser ecosystem. Subject to a separate unification arc (HANDOFF.md Wave 1 Item 2 — Binary.Bytes.Input vs Byte.Input).

### Cross-cutting findings

#### Finding 1 — SE-0503 obsoletes the "structural constraint" claim

The 2026-01-19 `Lifetime Dependent Borrowed Cursors.md` doc's central technical justification was:

> Swift 6.2 does not allow `~Escapable` constraints on protocol associated types.
> Therefore, if you want `Input.View` to be `~Escapable` and to participate in protocol-based dispatch, the dispatch must use a *different* protocol whose `Input` is *not* an associated type.
> Hence the Two Worlds Architecture: a separate `Binary.Bytes.Parser` protocol for the borrowed world and `Parsing.Parser` for the owned world.

This claim was true at the time of writing. It is **no longer true** in the current toolchain.

**SE-0503 (Suppressed Default Conformances on Associated Types)** has been Accepted and is the mechanism that lifts the restriction. From the proposal:

> The proposal extends suppression syntax to associated type declarations. All three syntactic positions now support suppression: in the inheritance clause of the associated type declaration, in a `where` clause attached to the associated type declaration, in a `where` clause attached to the protocol itself.

The institute's `Parser.Protocol`, declared at `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90-95`, exercises this exact capability:

```swift
public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
    /// The input type this parser consumes.
    ///
    /// Supports both escapable inputs (collections, cursors) and non-escapable
    /// inputs like `Span<UInt8>` for zero-copy borrowed parsing.
    associatedtype Input: ~Copyable & ~Escapable
    ...
}
```

The institute's `Sequence.Protocol`, `Sequence.Iterator.Protocol`, and `Sequence.Borrowing.Protocol` (`swift-sequence-primitives`) follow the same pattern with their `Element: ~Copyable` and `Iterator: ~Copyable & ~Escapable` associated types. The ecosystem evidence is dense:

- Carrier.Protocol — `associatedtype Domain: ~Copyable & ~Escapable`, `Underlying: ~Copyable & ~Escapable`
- Ownership.Borrow.Protocol — `associatedtype Borrowed: ~Copyable, ~Escapable`
- Parser.Protocol — `associatedtype Input: ~Copyable & ~Escapable`
- Parser.Printer.Input — same
- Sequence.Protocol — `associatedtype Element: ~Copyable`, `Iterator: ... & ~Copyable & ~Escapable`
- Sequence.Iterator.Protocol — `associatedtype Element: ~Copyable`
- Sequence.Borrowing.Protocol — `associatedtype Element: ~Copyable`

Ten production-conforming protocols and counting. **The Two Worlds Architecture's primary structural justification has been superseded by language evolution.** The 2026-01-19 doc's substantive recommendations — non-closure runner surface, parser-object pattern, protocol with `parse(_:inout Input)` method — remain valid; what is no longer required is *splitting the protocol* across worlds.

#### Finding 2 — The closure-parameter integration gap persists, but the institute's pattern is unaffected

The closure-parameter integration gap identified in the 2026-01-19 doc (§5) is a *separate* concern from the associated-type gap and has *not* been resolved by SE-0503. From SE-0446's own text:

> Escaping closures cannot capture nonescapable values.
> Nonescaping closures can capture nonescapable values subject to the usual exclusivity restrictions.

Passing a `~Escapable` value as a closure parameter is structurally different from a closure capturing one. The 2026-01-19 doc's three attempted workarounds (adding `borrowing`, adding `@_lifetime`, `withoutActuallyEscaping`) all failed because closure-parameter lifetime annotation syntax does not exist. SE-0446 itself confirms this is deferred:

> Specifying a dependency from a function parameter to its nonescapable result currently requires an experimental lifetime dependency feature. ... Adopting new syntax for lifetime dependencies merits a separate, focussed review.

**The institute pattern does not pass `~Escapable` values to closures.** It passes them via:

- `inout` method parameters (protocol-method invocation): Parser.Protocol's `parse(_ input: inout Input)` — the canonical pattern from the 2026-01-19 doc, but unified at one protocol.
- Property-based borrowed access (SE-0456 pattern): `Binary.Cursor.readableBytes: Span<UInt8>` with `@_lifetime(borrow self)` — the canonical pattern from SE-0456.

Where closure-based access *is* required (the `withReadableBytes` / `withRemainingBytes` family on `Binary.Cursor` / `Binary.Reader`), the closure receives an `UnsafeRawBufferPointer`, *not* the `~Escapable` Span<UInt8>. The lifetime contract is manual at that boundary, restricted to `unsafe`-marked entry points per `[MEM-SAFE-001]`.

The closure-integration gap is therefore not a constraint on the cursor substrate design; it constrains only the *consumer API style* and the institute already follows SE-0456's property pattern. No further action required from this arc.

#### Finding 3 — Position-type already decomposes to Tagged<DomainTag, Ordinal> across the institute

The empirical decomposition probe from byte-cursor v1.3.0 survives and is reinforced. At source:

```swift
// swift-text-primitives/Sources/Text Primitives/Text.Position.swift:27
public typealias Position = Tagged<Text, Ordinal>

// swift-index-primitives/Sources/Index Primitives Core/Index.swift:38
public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>

// swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Cursor.swift:53
internal var _readerIndex: Index<Storage>   // ≡ Tagged<Storage, Ordinal>
```

All non-View cursor positions are already typed `Tagged<DomainTag, Ordinal>`:
- `Binary.Cursor<Storage>.readerIndex` = `Index<Storage>` = `Tagged<Storage, Ordinal>`
- `Binary.Reader<Storage>.readerIndex` = `Index<Storage>` = `Tagged<Storage, Ordinal>`
- `Lexer.Scanner.cursor` = `Text.Position` = `Tagged<Text, Ordinal>`
- `Binary.Bytes.Input.position` = `Index<UInt8>` = `Tagged<UInt8, Ordinal>`

The single divergent case is `Binary.Bytes.Input.View.position: Int` — un-decomposed.

This finding is empirically robust and verified at HEAD on 2026-05-17.

#### Finding 4 — Higher-level cursors compose lower-level cursors

`Lexer.Pull.Stream<Tokens>` (`swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Pull.Stream.swift:54-107`) is `~Copyable & ~Escapable` and stores `public var scanner: Lexer.Scanner`. Its `next()`, `skip()`, `peek()`, `consume(via:)` operations delegate to the scanner. The stream adds depth tracking, pristine/consumed state, and a witness-driven token dispatch — none of which require a different *cursor* primitive.

This is the layered cursor pattern. The substrate (Span-cursor) is one layer; the structural-event reader is the next layer; format-specific assemblers (JSON.Assemble, RFC_8259.Pull.Tokens conformer) plug in via witnesses. The institute already practices this stratification.

The same pattern materializes at L3: `JSON.Span.EventStream` (`swift-foundations/swift-json/Sources/JSON/JSON.Span.EventStream.swift:30`) wraps `Lexer.Pull.Stream<RFC_8259.Pull.Tokens>` with a thin error-rethrow.

The cursor-substrate decision (this arc) is therefore *independent* of the layered structural-event question. If the substrate is unified, Lexer.Pull.Stream and JSON.Span.EventStream continue to wrap the unified substrate; if the substrate is left as parallel implementations, they wrap whichever lower-level cursor matches the format.

#### Finding 5 — Tokens witness is the protocol-driven dispatch layer

`Lexer.Pull.Tokens` is a protocol describing a format's token vocabulary, error type, depth semantics, and per-byte dispatch (per `swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Pull.Tokens.swift`, surveyed via the Stream's interface). This is the *witness pattern* applied to format parsing — and it composes cleanly with the institute's Parser.Protocol.

The relevance to the substrate decision: format-specific token machinery already factors *above* the cursor. The cursor's job is byte-level position + peek + advance + consume; format machinery sits on top via witnesses. The substrate need not embed format knowledge.

## Prior Art Survey

### Iteratees (Kiselyov 2009 / 2012)

Iteratees, invented by Oleg Kiselyov, are a composable streaming-IO abstraction for incremental processing. The model decomposes into three roles:

- **Stream** carries data chunks.
- **Iteratee** consumes data chunks and produces a result (or requests more input).
- **Enumerator** produces data chunks and feeds them to iteratees.
- **Enumeratee** is both — it transforms an outer stream into a nested stream.

Iteratees support precise resource control, prompt finalization, and incremental parsing. The model has been applied to incremental JSON parsing, file processing, and network protocol parsing.

**Relevance to the cursor question**: Iteratees are *at a higher abstraction layer* than cursors. They model the *flow* of input through transformations; they don't model the cursor's *position in a single chunk*. The institute's `Lexer.Pull.Stream<Tokens>` is closer to an iteratee in spirit (incremental event stream with depth tracking) than the byte-level cursors are. Iteratees do not argue for or against substrate unification; they argue for a layered architecture, which the institute already practices.

### Parser combinators

**Hutton & Meijer, "Monadic Parsing in Haskell" (1998)** — the canonical text on parser combinators. A `Parser a` is a function from input strings to a list of (a, remaining-input) pairs. Composition via Monad bind allows chaining; alternation via MonadPlus. Input is a string, not a cursor — backtracking is via list backtracking.

**Swierstra & Duponcheel (1996)** — predictive parser combinators. Input is consumed strictly left-to-right; ambiguity is resolved at the combinator level via FIRST/FOLLOW analysis. Input is again a sequence/list, not a positional cursor.

**Attoparsec (Haskell, Bryan O'Sullivan et al.)** — production incremental parser library for Haskell. Result type:

```haskell
data Result a = Failed String
              | Done ByteString a
              | Partial (ByteString -> Result a)
```

Three states: Failed (with message), Done (with consumed input + result), Partial (with continuation expecting more input). The input is a `ByteString` — owned data, consumed positionally. Backtracking is supported via the parser's internal state. The cursor is *implicit*: it's the current head of the ByteString as the parser advances.

**Point-Free `swift-parsing`** — Swift parser combinator library. Per the upstream Parser protocol:

```swift
@rethrows public protocol Parser<Input, Output> {
  associatedtype Input
  associatedtype Output
  associatedtype _Body
  typealias Body = _Body

  func parse(_ input: inout Input) throws -> Output

  @ParserBuilder<Input>
  var body: Body { get }
}
```

`Input` is unconstrained — no `~Copyable`, no `~Escapable`. The library is generic over Input but in practice uses `Substring`, `Substring.UTF8View`, `[UInt8]`, and similar Copyable types. Predates Swift 6.x ownership features.

The institute's `Parser.Protocol` is a generalization of swift-parsing's Parser protocol — it adds `~Copyable` to Self and `~Copyable & ~Escapable` to Input, enabling Span<UInt8>-based zero-copy parsing without abandoning the protocol substrate.

**Relevance to the cursor question**: parser combinators have always worked over a sequence-like Input that is *consumed* by the parser. The cursor abstraction at the substrate level is *position + peek + advance*; the parser combinator layer is *what to do at each position*. The two are at different layers; the prior art validates a layered approach with one substrate cursor abstraction underneath one parser protocol.

### Streaming libraries — Conduit, Pipes

**Conduit (Snoyman)** uses three datatypes (Source, Conduit, Sink) chained by `(.|)`. Adds prompt finalization, upstream-termination notification, and leftover support. Pragmatic, accessible API.

**Pipes (Gonzalez)** unifies into one type `Pipe m i o r` with bidirectional algebra. Higher mathematical elegance; more demanding type signatures (Lens, FreeT).

Both are at the *stream of items* layer, not the *cursor in a contiguous byte buffer* layer. Their existence reinforces that there's natural separation between:
- *Byte-level cursor* (the position-in-buffer abstraction this arc concerns)
- *Stream of items* (the chain of transformations over a stream — Lexer.Pull.Stream territory)

The two layers should not be conflated.

### Lifetime / ownership in research languages

**Rust RFCs 0019 (Lifetime Semantics) and 0066 (Coherence)** — established Rust's borrow checker and lifetime annotation system. Borrow-checked references (`&'a T`) carry a compile-time lifetime parameter; references cannot outlive their referent. The `'static` lifetime is the immortal case.

**Pierce, "Advanced Topics in Types and Programming Languages" (2005, ch.1)** — the standard textbook treatment of advanced type systems. Affine and linear types are covered in detail; region types (Tofte-Talpin) are presented in their own chapter.

**Cyclone (Grossman & Morrisett, 2002)** — a region-typed C dialect. Regions are lexically scoped allocation arenas; pointers are tagged with their region. `~Escapable` types in Swift are conceptually adjacent: a value tagged with its lexical scope, the type system preventing escape.

**Relevance**: Swift's `~Escapable` + `@_lifetime` annotations are the institute-cursor analog of Cyclone region types specialized to a single lexically-scoped region (the source span's lexical scope). The 2026-01-19 doc's "lifetime dependency" framing aligns with the region-types literature.

### Region types

**Tofte & Talpin, "Region-Based Memory Management" (1997)** — formal calculus for region-based memory management with a type-and-effects system. Programs are annotated with region inference; allocations are placed in regions; deallocations are bulk at region exit.

The Swift ~Escapable model is a *single-region* simplification: the type-system tracks one lifetime relationship per value (the borrowed-from source), and deallocation is automatic at the source's scope exit. This is sufficient for the cursor case because cursors borrow from a single Span<UInt8>, not from a complex region graph.

**Relevance**: the cursor's lifetime invariant is exactly the Tofte-Talpin region principle applied to a single-source region. `cursor.position ∈ [0, source.count)` is the cursor's internal invariant; `source.scope ⊇ cursor.scope` is the lifetime constraint enforced by the type system.

### Linear / affine types

**Wadler, "Linear Types Can Change the World" (1990)** — foundational paper on linear types. A value of linear type must be used *exactly once*. Linear arrows distribute multiplicatively.

**Bernardy, Boespflug, Newton, Peyton Jones, Spiwack, "Linear Haskell: practical linearity in a higher-order polymorphic language" (POPL 2018)** — Linear Haskell's design adds linearity on function arrows (`a ⊸ b`) rather than on types. Linear functions consume their argument exactly once. Affine functions consume at most once (`x ⊸_ω b`).

**Walker, "Substructural Type Systems" (chapter in ATTAPL 2005)** — comprehensive theoretical treatment. Linear systems prohibit weakening (drop) and contraction (duplicate); affine systems prohibit only contraction; relevant systems prohibit only weakening.

**Mapping to Swift**:
- Swift `~Copyable` ≈ affine: cannot be duplicated, can be dropped (via going out of scope, with deinit running). Exactly-once consumption requires manual `consume` keyword.
- Swift `~Copyable` + no `deinit` ≈ linear: must be consumed before scope exit (compiler requires it).
- Swift `Copyable` (default) ≈ unrestricted: can be duplicated and dropped freely.

For cursors: the canonical pattern is `~Copyable` (affine) — duplication would create aliasing bugs over position state. Going out of scope is fine; explicit `consume` is required when transferring ownership.

The institute's choice of `~Copyable` for all cursors is structurally correct under the affine reading.

### Swift Evolution proposals

| Proposal | Title | Status | Relevance |
|----------|-------|--------|-----------|
| SE-0410 | Low-Level Atomic Operations | (out of scope) | — |
| SE-0377 | borrowing / consuming parameter ownership modifiers | Accepted | Cursor methods use `borrowing` (peek) / `consuming` (transfer) where applicable. |
| SE-0427 | Noncopyable Generics | Accepted | Enables `~Copyable` on generic parameters; load-bearing for `Index<Element: ~Copyable>` and `Memory.Contiguous.Protocol & ~Copyable` Storage. |
| SE-0432 | Borrowing and consuming pattern matching | Accepted | Pattern matching over `~Copyable` types. |
| SE-0438 | (other number, not relevant) | — | (was placeholder in brief; actual proposal is unrelated) |
| SE-0446 | Nonescapable Types | Accepted with modifications (Oct 2024) | The foundation: `~Escapable` types with `@_lifetime` annotations. **Defers closure-parameter lifetime annotations to future work.** |
| SE-0447 | Span: Safe Access to Contiguous Storage | Accepted (Oct 2024) | The Span<T> type — the substrate every borrowed cursor borrows from. |
| SE-0456 | Add Span-providing Properties to Standard Library Types | Accepted | The property-based borrowed-access pattern. `var span: Span<Element> { @_lifetime(borrow self) get }`. The institute pattern for cursor's `readableBytes` accessor. |
| SE-0465 | Nonescapable Standard Library Primitives | Accepted | Optional / Result wrapping ~Escapable. Reinforces the language direction but does not address the cursor substrate decision directly. |
| SE-0474 | Yielding Accessors | Accepted | `_read` / `_modify` coroutines. The institute Property.View pattern's foundation. |
| SE-0499 | Support for Noncopyable Simple Protocols | Accepted | Allowed protocols themselves to be `~Copyable`. Precondition for Parser.Protocol's `~Copyable` Self. |
| SE-0503 | Suppressed Default Conformances on Associated Types | Accepted | **The key proposal that obsoletes the 2026-01-19 doc's structural-constraint claim.** Allows `associatedtype X: ~Copyable & ~Escapable` in protocols. |

### Industry implementations

#### SwiftNIO ByteBuffer

ByteBuffer provides two indices: `readerIndex` (next readable byte) and `writerIndex` (next writable position). Readable region is `bytes[readerIndex..<writerIndex]`; writable region is `bytes[writerIndex..<capacity]`.

This is structurally identical to `Binary.Cursor<Storage>` (institute). The institute Binary.Cursor's design *is* the NIO ByteBuffer model applied to the institute's Memory.Contiguous.Protocol substrate.

#### Netty ByteBuf

Java's Netty has the same reader/writer index model as SwiftNIO. The pattern dates from Netty 3 (mid-2000s) and is the industry-standard owned reader-writer byte cursor.

#### Rust `std::io::Cursor<T>`

```rust
pub struct Cursor<T> {
    inner: T,
    pos: u64,
}
```

A *single-position* cursor — read-only or write-only depending on what trait you implement (`Read` for read, `Write` for write). The cursor type is parameterized over the inner storage `T`, similar to the institute's `Binary.Cursor<Storage>` parameterization. Position is a `u64`, untyped. Rust does not have phantom-tagged positions in stdlib.

#### Rust `bytes` crate — `Buf` / `BufMut` traits

```rust
pub trait Buf {
    fn remaining(&self) -> usize;
    fn chunk(&self) -> &[u8];
    fn advance(&mut self, cnt: usize);
    // + many derived methods
}

pub trait BufMut {
    fn remaining_mut(&self) -> usize;
    fn chunk_mut(&mut self) -> &mut UninitSlice;
    unsafe fn advance_mut(&mut self, cnt: usize);
    // + many derived methods
}
```

Two traits: Buf (read) and BufMut (write). The traits abstract over the storage; a `Buf` value is "a cursor into the buffer." Operations are infallible. Conformers include `Cursor<Vec<u8>>`, `BytesMut`, `&[u8]`, etc.

This is closer to a *protocol-based* unification than the institute's structural-type-based approach. The institute's `Parser.Protocol` plays a similar role — it abstracts the Input shape via the associatedtype.

#### Point-Free swift-parsing

Covered above. Single Parser protocol generic over Input. No explicit cursor primitive — cursor logic is implicit in the input type (Substring, UTF8View, etc.).

### Synthesis of prior art

| Pattern from prior art | Institute equivalent | Status |
|-----------|----------------------|--------|
| Reader/writer dual-index cursor (NIO, Netty, Rust bytes BufMut) | `Binary.Cursor<Storage>` | ✓ Present at L1 |
| Single-position read-only cursor (Rust std::io::Cursor, Rust bytes Buf) | `Binary.Reader<Storage>` | ✓ Present at L1 |
| Span-property pattern (SE-0456) | `Binary.Cursor.readableBytes: Span<UInt8>` with `@_lifetime` | ✓ Present at L1 |
| Parser-object dispatch (Lifetime Dependent doc, swift-parsing) | `Parser.Protocol` with `parse(_: inout Input)` | ✓ Present, unified across owned + borrowed Input |
| Position-typed phantom tagging (institute innovation) | `Index<Element>`, `Text.Position`, `Tagged<DomainTag, Ordinal>` | ✓ Pervasive in the institute |
| Iteratee / Conduit / Pipes streaming layers | `Lexer.Pull.Stream<Tokens>` + format witnesses + `Parser.Protocol` combinators | ✓ Layered above the substrate |
| Closure-passing for borrowed buffer access (legacy NIO `withReadableBytes`) | `Binary.Cursor.withReadableBytes(_: (UnsafeRawBufferPointer) -> R)` | ✓ Present as `unsafe` escape hatch; property pattern is canonical |
| ~Copyable + ~Escapable on protocol associated types | `Parser.Protocol`, `Sequence.Protocol`, ... | ✓ Unlocked by SE-0503; ~10 institute protocols use this |

The institute's L1 cursor ecosystem incorporates every load-bearing pattern from prior art *except* for one specific divergence: the position-type discipline is institute-original (Tagged-based phantom tagging), not present in NIO, Netty, Rust `bytes`, or Rust `std::io::Cursor`. This is not a gap — it is a deliberate refinement that the institute applies *everywhere*. The single exception is `Binary.Bytes.Input.View`, which uses raw Int.

## Theoretical Grounding

Per `[RES-022]`. Light formalism that improves precision.

### Affine type theory applied to cursors

A cursor is a *stateful* object: it carries a position that changes as operations are performed. State + duplication = aliasing bugs (two cursors over the same storage with independently-advanced positions). The type system has two means to prevent this:

1. *Reference semantics* — only one cursor object exists; aliases all point to the same underlying state. Used by Rust's `&mut T` borrows.
2. *Affine value semantics* — the cursor value cannot be implicitly duplicated; the type system rejects code that would alias.

Swift's `~Copyable` is the second. It is the **affine attribution** in Swift's substructural type system: a `~Copyable` value can be moved (consumed once) or dropped (via going out of scope), but cannot be silently duplicated. To duplicate explicitly, the consumer must call `copy`.

**Proposition 1 (Cursor affinity)**: For a cursor type `C` with stateful position, `C: ~Copyable` is the type-theoretically minimal constraint that prevents the position-aliasing class of bugs.

This applies uniformly across all cursor primitives in the institute. Every primitive in the inventory is `~Copyable`. The single Copyable exception — `Binary.Bytes.Input` — is Copyable by design because its position is part of the value (consuming the cursor takes the position too) and its consumers (the older Parser.Parser ecosystem) rely on Copyable semantics for the `remaining: Self` accessor.

### Region types applied to cursors

A *borrowed* cursor has a lifetime relationship to its source. The source carries the bytes; the cursor borrows them. The cursor's lifetime must be ⊆ the source's lifetime.

This is a single-region case of Tofte-Talpin region typing. The Swift implementation uses two mechanisms:

1. `~Escapable` attribution on the cursor type — declares that the cursor cannot escape its source region.
2. `@_lifetime(borrow source)` annotation on the cursor constructor — declares the lifetime relationship.

The compiler enforces the relationship at every use site of the cursor. The cursor cannot be returned from a function whose source-region exits with the function call; it cannot be stored in a heap structure that outlives the source; it cannot cross a suspension point that may outlive the source.

**Proposition 2 (Cursor region invariant)**: For a borrowed Span-cursor `C` with `source: Span<UInt8>` and lifetime annotation `@_lifetime(borrow source)`:
- `scope(C) ⊆ scope(source)` — invariant enforced by `~Escapable`.
- For all reads `C.peek(at: i)` with `i < C.count`, the read is into `source[C.position + i]` — invariant maintained by the position-bounds invariant `0 ≤ C.position ≤ source.count` per the cursor's own logic.

Both invariants together establish soundness: a well-typed cursor cannot read past the end of its source nor read after the source has been deallocated.

### ~Copyable + ~Escapable as Swift's substructural toolkit

Swift's substructural type system, post-SE-0427 and SE-0446, is essentially:

| Suppression | Meaning | Use case |
|-------------|---------|----------|
| `~Copyable` | No implicit duplication (affine) | Stateful resources, unique-ownership values |
| `~Escapable` | No escape from source region | Borrowed views, lifetime-bound values |
| `~Copyable & ~Escapable` | Both | Borrowed cursors over external storage |

For cursors, the combination is determined by the storage substrate:
- Owned storage (Storage<UInt8> or [UInt8]) → `~Copyable, Escapable`
- Borrowed storage (Span<UInt8>) → `~Copyable, ~Escapable`

This is a structural type-system distinction, not a generic-parameter choice. A single cursor type cannot be sometimes Escapable and sometimes not; it is one or the other.

### Formal characterization of the "structural constraint" claim

The 2026-01-19 doc's central claim was a type-theoretic constraint statement. Restated formally:

> Let `P` be a protocol with `associatedtype Input` and an operation `mutating func parse(_: inout Input) -> Output`. If `Input` is required to be `~Escapable` (e.g., `Input: ~Escapable`), then under Swift 6.2 this constraint is unrepresentable. Therefore the protocol must be split into two: one for `Escapable Input` and one for `~Escapable Input`.

**Pre-SE-0503**: this claim holds. Swift 6.2's protocol syntax does not allow `~Escapable` suppressions on associated types.

**Post-SE-0503**: this claim is *falsified*. SE-0503 introduces:

```swift
public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    ...
}
```

The associatedtype `Input` carries the `~Copyable & ~Escapable` suppression, and the protocol is well-typed. Conformers can supply either Escapable or `~Escapable` Input types; the protocol accommodates both.

**Empirical verification**: `Parser.Protocol` (`swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90-95`) compiles, runs, and is the established institute parser substrate.

The original doc's *recommendation* (parser-object dispatch via protocol method, not closure) remains valid — the closure-parameter integration gap (Finding 2) persists. What is no longer required is the *world split* — the protocol-shape split was a workaround for the now-removed constraint.

### Soundness argument

For the proposed Three-Worlds architecture (specified in Outcome §):

**World 1 (Owned reader-writer)**: `Binary.Cursor<Storage>` and `Binary.Reader<Storage>` are `~Copyable, Escapable`. The cursor owns its `storage: Storage`. The invariant `0 ≤ readerIndex ≤ writerIndex ≤ count` is maintained by every mutating method; the `count` derives from `storage.span.count` and is fixed at construction. The reader's invariant `0 ≤ readerIndex ≤ count` is the read-only specialization. Type system enforces unique ownership via `~Copyable`; storage non-escape is irrelevant since the cursor IS the owner.

**World 2 (Borrowed read-only Span)**: A unified `BorrowedSpanCursor<DomainTag>` (proposed) is `~Copyable, ~Escapable` with `position: Tagged<DomainTag, Ordinal>` and `source: Span<UInt8>`. The compile-time invariant `scope(cursor) ⊆ scope(source)` is enforced by `~Escapable` + `@_lifetime(borrow source)`. The run-time invariant `0 ≤ position.rawValue ≤ source.count` is maintained by every peek/advance/consume method. Read at `position` is into `source[position.rawValue]`, well-defined when the invariant holds. The compiler prohibits cursor escape; the cursor's own logic prevents out-of-bounds reads.

**World 3 (Owned Copyable input)**: `Binary.Bytes.Input` is Copyable, Sendable, `[UInt8]`-backed with `position: Index<UInt8>` (or `Index<Byte>` post-Item-2). Position invariant `0 ≤ position.rawValue ≤ storage.count` is maintained by every mutating method. Copying the cursor copies storage + position; the original cursor and the copy advance independently — this is the explicit semantic, not a bug. Sendable holds because `[UInt8]` is Sendable and `Index<UInt8>` is Sendable.

All three worlds are independently sound. The architecture as a whole composes safely because each world's cursors are usable in any context where their attributes (Escapable / ~Escapable / Copyable / ~Copyable / Sendable) are compatible — and consumers (Parser.Protocol) accept any `~Copyable & ~Escapable` Input, which is the union of World 1's `Escapable & ~Copyable`, World 2's `~Copyable & ~Escapable`, and World 3's `Copyable & Escapable & Sendable`. (Note: `Copyable & Escapable` types satisfy `~Copyable & ~Escapable` constraints trivially per SE-0427's suppression semantics.)

## Decision Space Enumeration

Following the brief's required enumeration, augmented with refinements surfaced during analysis.

### Shape A — Single fully generic cursor

```swift
public struct Cursor<
    Storage,           // either Span<UInt8> or M.C.P-conforming
    DomainTag,
    Mode               // read or read-write
>: ?Copyable, ?Escapable { ... }
```

**Verdict**: structurally impossible. Swift offers no way to make `Escapable` conditional on a generic parameter. A type is either Escapable or `~Escapable` — the bit is fixed at declaration. **Rejected** on structural grounds.

### Shape B — Single protocol with two-or-more conformers

```swift
public protocol Cursor.`Protocol`: ~Copyable {
    associatedtype Position: Comparable
    var position: Position { get }
    mutating func peek() -> UInt8?
    mutating func advance(by: UInt) throws(Error)
    ...
}

public struct OwnedCursor<Storage>: Cursor.`Protocol`, ~Copyable { ... }
public struct BorrowedCursor<DomainTag>: Cursor.`Protocol`, ~Copyable, ~Escapable { ... }
```

**Verdict**: structurally viable. Unifies the *interface* without unifying the *implementation*. Useful when generic algorithms operate over any cursor. Cost: an additional protocol layer in the surface area; per-conformer implementation still separate.

The institute already has this pattern for the *consumer* side via `Parser.Protocol` — it accepts any `Input: ~Copyable & ~Escapable`. Adding a `Cursor.Protocol` would not displace Parser.Protocol; it would constrain Input to *cursor-shaped* values. Demand: there is no enumerated consumer that needs to dispatch generically over both owned and borrowed cursors today. Without such a consumer, the protocol adds vocabulary without payoff.

**Hold** as a future option if a consumer materializes; do not add today per `[RES-018]` case (a) gating. The protocol can be added later without disruption if the structural types are stable.

### Shape C — Generic-Element cursor

```swift
public struct Cursor<Element>: ~Copyable, ~Escapable { source: Span<Element>; ... }
```

**Verdict**: premature generalization. Element = UInt8 is fixed in every existing consumer; there is no enumerated `Element ≠ UInt8` consumer (no `Cursor<Float>`, no `Cursor<String>`, etc.). Adding the Element parameter is parameterizing along an axis with no cross-domain pressure. **Rejected** per the spirit of `[RES-018]` (no second-element demand).

### Shape C′ — Position-parameterized cursor (Shape F predecessor)

```swift
public struct Cursor<Position: Comparable>: ~Copyable, ~Escapable
    where Position == Tagged<...> { ... }
```

**Verdict**: viable as a structural primitive for the borrowed Span-cursor cluster, but the constraint `Position: Comparable` with the institute's `Tagged<DomainTag, Ordinal>` discipline is awkward — the `Tagged<X, Ordinal>` is already Comparable via the Ordinal substrate, and the cursor doesn't really need to be polymorphic over Position; it needs to be polymorphic over DomainTag (where Position is computed from DomainTag).

**Refined into Shape F**.

### Shape D — Pull Span-cursor to swift-byte-primitives

Add `Byte.Cursor` to `swift-byte-primitives`, tier-shifting byte-primitives downward in the DAG to absorb cursor mechanics.

**Verdict**: mission-boundary tension with byte-primitives' established "pure value layer" stance from the byte-extraction arc (`byte-primitive-extraction-and-domain-naming.md` v1.0.1 DECISION 2026-05-15). Byte.swift is intentionally minimal — storage + Carrier init + Sendable declaration only. Adding a Span-cursor primitive to the same package contradicts the established scope.

Furthermore, the Span-cursor is not byte-domain-owned in the sense [API-NAME-001b] requires: a Span-cursor over Text bytes is text-domain code; a Span-cursor over Binary bytes is binary-domain code; the substrate's domain is *the substrate*, not the byte value type. Pulling the cursor under Byte conflates the byte value layer with the byte-stream-cursor layer.

**Rejected**.

### Shape F — Unified borrowed-Span cursor with Tagged<DomainTag, Ordinal> position

```swift
public struct <SomeName><DomainTag: ~Copyable>: ~Copyable, ~Escapable
where ... {
    internal let source: Span<UInt8>
    internal var position: Tagged<DomainTag, Ordinal>
    // peek, peek(at:), advance, advance(by:), consume, isAtEnd, etc.
}
```

Both `Binary.Bytes.Input.View` and `Lexer.Scanner` migrate to this single primitive:
- `Binary.Bytes.Input.View` → typealias or thin wrapper around `<SomeName><Byte>` (or `<Binary>` — see naming discussion in Open Questions) with binary-domain overlays (`starts(with:)`, `copyToOwned()`).
- `Lexer.Scanner` → typealias or thin wrapper around `<SomeName><Text>` composed with `Text.Location.Tracker` overlay + lexer-specific helpers (`Scanner+Lexing.swift`).

**Verdict**: structurally correct for the borrowed read-only Span-cursor cluster (World 2). Both consumers already share ~50 LOC of mechanically-identical scaffolding (verified in byte-cursor v1.2.0 §Phase 1, retained in v1.3.0). Position-type unification aligns both with the institute's typed-position discipline (closing the "raw Int" outlier in Binary.Bytes.Input.View).

Shape F is *necessary but not sufficient* — it unifies World 2 only. It leaves Worlds 1 (Binary.Cursor + Binary.Reader) and 3 (Binary.Bytes.Input) untouched.

**Accepted as a component of the recommended architecture.**

### Shape γ — Three-Worlds Architecture (refinement, recommended)

The principled answer is **three structural clusters at L1, with World 2 internally unified per Shape F**.

#### World 1 — Owned reader-writer cluster (status quo)

- `Binary.Cursor<Storage>` — `~Copyable, Escapable`, dual-index reader-writer over generic Storage. SwiftNIO/Netty-style.
- `Binary.Reader<Storage>` — `~Copyable, Escapable`, single-index reader-only over generic Storage.
- Live in `swift-binary-primitives`.
- Use `Index<Storage>` position discipline (already aligned with institute conventions).
- Compose with `Memory.Contiguous.Protocol & ~Copyable` Storage abstractions (Buffer.Heap, Buffer.Linear, Buffer.Aligned, …).

**No structural change recommended.** This cluster already practices the discipline. The pair (Cursor + Reader) follows `[API-IMPL-008]` minimal-type-body and the "single type per file" discipline correctly — Cursor and Reader have different operation sets and reasonable storage shapes (Cursor carries an extra writerIndex), warranting separate types over a single "read-write or read-only" parameterized type.

#### World 2 — Borrowed read-only Span-cursor cluster (UNIFY per Shape F)

- Today: `Binary.Bytes.Input.View` (raw Int position) and `Lexer.Scanner` (Text.Position position) — two near-identical implementations differing only in position-type discipline.
- Proposed: one primitive (call it `<SomeName><DomainTag>` — see Open Questions for naming).
- Both consumers ride the unified primitive with domain-specific overlay layers above.

Properties:
- `~Copyable, ~Escapable`
- `source: Span<UInt8>`
- `position: Tagged<DomainTag, Ordinal>` (where `DomainTag: ~Copyable`)
- Surface: `peek()`, `peek(at: Tagged<DomainTag, Cardinal>)`, `advance()`, `advance(by: Tagged<DomainTag, Cardinal>)`, `consume()`, `isAtEnd`, `count`, `position`.
- `@_lifetime(borrow source)` on the init; `@_lifetime(self: copy self)` on mutating methods.

Domain overlays compose above:
- Binary domain: `Cursor<Byte>` (or `Cursor<Binary>` — naming discussion) plus extension methods `starts(with:)`, `copyToOwned()`.
- Text domain: `Cursor<Text>` plus extension methods `newline(at:)`, `location`, `location(at:)`, plus the composable `Text.Location.Tracker`.

Backward compatibility: `Binary.Bytes.Input.View` becomes a typealias or thin wrapper on `Cursor<Byte>`; `Lexer.Scanner` becomes a typealias or thin wrapper on `Cursor<Text>` + tracker.

#### World 3 — Owned Copyable input cluster (status quo, separate arc)

- `Binary.Bytes.Input` — Copyable, Sendable, `[UInt8]`-backed, `Index<UInt8>` position.
- Live in `swift-binary-parser-primitives`.
- Currently used by `Parser.Protocol`'s older consumer ecosystem.

**No structural change recommended in this arc.** HANDOFF.md Wave 1 Item 2 (`Binary.Bytes.Input` vs `Byte.Input` unification) is a separate arc focused on the *typed-input* unification at the owned-Copyable layer. That arc inherits this recommendation's Shape γ framing — World 3 is its own cluster — but its disposition (rename / unify / consolidate) is left to Item 2 to settle.

#### Summary of Shape γ

```
World 1 (Owned reader-writer, ~Copyable, Escapable, generic-Storage):
    Binary.Cursor<Storage>     — read-write, dual index
    Binary.Reader<Storage>     — read-only, single index
    Position: Index<Storage>

World 2 (Borrowed read-only, ~Copyable, ~Escapable, Span<UInt8>):
    <UnifiedCursor><DomainTag>  — single primitive (NEW)
        instantiated for DomainTag = Byte for binary parsing
        instantiated for DomainTag = Text for lexing
    Position: Tagged<DomainTag, Ordinal>

World 3 (Owned Copyable input, Copyable, Sendable, [UInt8]):
    Binary.Bytes.Input          — single index
    Position: Index<UInt8>      (or Index<Byte> post-Item-2)
```

**Verdict**: principled three-worlds decomposition. Each world has a coherent semantic domain. World 2 internally unifies; Worlds 1 and 3 stay structurally separate.

### Shape ε — Status quo with position-type retrofit only

A weaker variant: leave the three borrowed-cursor types as separate implementations, but align `Binary.Bytes.Input.View`'s position from raw Int to `Index<Byte>` = `Tagged<Byte, Ordinal>` for consistency with the institute's typed-position discipline.

**Verdict**: a valid partial fix. Closes the position-type outlier without introducing a new unified primitive. However, it leaves the ~50 LOC of mechanically-identical scaffolding duplicated across Binary.Bytes.Input.View and Lexer.Scanner. Cheaper to land; structurally less complete than Shape γ.

**Considered as a fallback** if Shape γ implementation encounters unanticipated obstacles. Not the principled recommendation.

### Shape ζ — Pull the substrate higher (replace Scanner with Pull.Stream-shaped substrate everywhere)

Replace the Span-cursor substrate with `Lexer.Pull.Stream`-shaped structural-event cursor as the primary surface.

**Verdict**: not viable. Lexer.Pull.Stream is at a *higher* abstraction layer — it operates on tokens, not bytes. Many consumers (binary parsing, raw byte processing) don't need structural-event semantics. Replacing the byte-level substrate with a structural-event substrate would force every byte-level consumer to define a trivial Tokens witness, paying generic-dispatch cost for nothing. Reverses the layering correctly identified in Finding 4.

**Rejected**.

### Shape η — Iteratee or Conduit-style streaming substrate

Adopt iteratee or conduit semantics at the substrate level — consumers are iteratees consuming a stream of bytes.

**Verdict**: not viable for the same reason as Shape ζ. The iteratee/conduit pattern is at the stream-processing layer, not the substrate layer. The institute's `Sequence.Protocol` and `Lexer.Pull.Stream` already inhabit the stream layer; replacing the byte-cursor substrate with iteratees would conflate layers.

**Rejected**.

### Shape ι — Full centralization in a dedicated `swift-cursor-primitives` package

The user-requested angle (added 2026-05-17 in v1.1.0): rather than distributing cursor types across the three domain packages (Shape γ's package placement), centralize **all** cursor types in a single new L1 package `swift-cursor-primitives`. Domain packages (`swift-binary-primitives`, `swift-binary-parser-primitives`, `swift-lexer-primitives`) reduce to typealiases or thin wrappers over the centralized types.

#### Important clarification — Shape ι ≠ Shape A

Shape ι is **not** "one cursor type for everything." The three structural Worlds persist because Escapable / `~Escapable` and Copyable / `~Copyable` are type-system distinctions that *cannot* be parameterized by a generic — Shape A's structural impossibility is unchanged. The Three-Worlds *type structure* is the same in Shape ι as in Shape γ; what differs is *package placement*. Shape ι = same three structural clusters + centralized package home + typealiases/wrappers in domain packages.

This separates two orthogonal axes that were collapsed in the original framing:

| Axis | Shape γ | Shape ι |
|------|---------|---------|
| **Type structure** (how many distinct cursor types) | Three Worlds (W1 owned-rw, W2 borrowed-ro-Span, W3 owned-Copyable-input) with W2 internally unified | **Same** — Three Worlds with W2 internally unified |
| **Package placement** (where the cursor types live) | Distributed: W1 in `swift-binary-primitives`, W2 in a new or existing package (open), W3 in `swift-binary-parser-primitives` | Centralized: all three Worlds in `swift-cursor-primitives` |

#### Concrete sketch of Shape ι

The cursor-primitives package hosts 3 (or 4) concrete cursor primitive types, all generic over their relevant axes:

```swift
// In swift-cursor-primitives
public enum Cursor {}

extension Cursor {
    /// World 2 — borrowed read-only Span cursor.
    public struct Span<DomainTag: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline internal let source: Swift.Span<UInt8>
        @usableFromInline internal var _position: Tagged<DomainTag, Ordinal>
        @inlinable @_lifetime(borrow source)
        public init(_ source: borrowing Swift.Span<UInt8>) { ... }
        // peek, peek(at:), advance, advance(by:), consume, isAtEnd, count, position
    }
}

extension Cursor {
    /// World 1 (read-only variant) — owned read-only cursor over generic Storage.
    public struct OwnedReader<Storage: Memory.Contiguous.`Protocol` & ~Copyable>: ~Copyable
    where Storage.Element == UInt8 {
        public let storage: Storage
        @usableFromInline internal let _count: Index<Storage>.Count
        @usableFromInline internal var _readerIndex: Index<Storage>
        // peek, advance, consume, remainingBytes (Span accessor), ...
    }

    /// World 1 (read-write variant) — owned read-write cursor over generic Storage.
    public struct OwnedReaderWriter<Storage: Memory.Contiguous.`Protocol` & ~Copyable>: ~Copyable
    where Storage.Element == UInt8 {
        public var storage: Storage
        @usableFromInline internal let _count: Index<Storage>.Count
        @usableFromInline internal var _readerIndex: Index<Storage>
        @usableFromInline internal var _writerIndex: Index<Storage>
        // dual-index operations, readableBytes / writableBytes (Span accessors), ...
    }
}

extension Cursor {
    /// World 3 — owned Copyable input cursor over [Element].
    public struct Input<Element>: Sendable where Element: Sendable {
        @usableFromInline internal var storage: [Element]
        @usableFromInline internal var _position: Index<Element>
        // peek, advance, consume, count, ...
    }
}
```

Domain packages reduce to typealiases or thin wrappers:

```swift
// In swift-binary-primitives
extension Binary {
    public typealias Cursor<Storage> = Cursor.OwnedReaderWriter<Storage>
    where Storage: Memory.Contiguous.`Protocol` & ~Copyable, Storage.Element == UInt8

    public typealias Reader<Storage> = Cursor.OwnedReader<Storage>
    where Storage: Memory.Contiguous.`Protocol` & ~Copyable, Storage.Element == UInt8
}

// In swift-binary-parser-primitives
extension Binary.Bytes {
    public typealias Input = Cursor.Input<UInt8>   // or Cursor.Input<Byte> post-Item-2

    extension Input {
        public typealias View = Cursor.Span<Byte>   // World 2 typealias
    }
}

// In swift-lexer-primitives — Scanner CAN'T be a typealias because it stores tracker state
extension Lexer {
    @safe
    public struct Scanner: ~Copyable, ~Escapable {
        @usableFromInline internal var inner: Cursor.Span<Text>
        @usableFromInline internal var tracker: Text.Location.Tracker
        @usableFromInline internal var hasEmittedEndOfFile: Bool
        // Forward peek / advance / consume to inner, plus tracker-aware newline(at:) etc.
    }
}
```

Lexer.Pull.Stream<Tokens> continues to wrap a `Lexer.Scanner` (which now wraps `Cursor.Span<Text>`); no change at the structural-event layer.

#### Is Shape ι possible?

Yes. Each component is well-defined:

- The three (or four) cursor primitive types are structurally valid — they are exactly the same types as in Shape γ, just declared in `swift-cursor-primitives` instead of in their current domain packages.
- Typealiases for generic types in Swift can carry where-clauses; `Binary.Cursor<Storage>` as a typealias works syntactically.
- Wrapper structs (for cases like `Lexer.Scanner` that add state beyond the substrate cursor) compose cleanly; `@inlinable` forwarding eliminates runtime indirection.
- The cursor-primitives package satisfies `[RES-018]` case (a) gates: cross-domain fit ✓ (binary + byte + text are distinct domains), composition check ✓ (cursor mechanics are not composed from existing primitives — peek/advance/consume + position-bounds invariant + lifetime attribution is itself a distinct primitive concept).
- The package satisfies `[MOD-RENT]` three-criteria test: capability ✓, consumers ✓ (binary + binary-parser + lexer immediate), theoretical content ✓ (cursor as stateful position-in-storage with affine ownership and region-bounded lifetime).
- The institute has direct precedent for cross-cutting primitives in their own packages: `swift-sequence-primitives`, `swift-index-primitives`, `swift-tagged-primitives`. Cursor-primitives would follow that pattern.

#### Drawbacks of Shape ι

These are the specific costs of full centralization relative to Shape γ's distributed placement:

**1. Tier elevation in the primitives DAG.** `swift-cursor-primitives` references these types in its source:

| Type referenced | From | Tier |
|-----------------|------|------|
| `Swift.Span<UInt8>` | stdlib | — |
| `Tagged<Tag, Underlying>` (the typed-position substrate) | swift-tagged-primitives | 0 |
| `Ordinal`, `Cardinal`, `Affine.Discrete.Vector` (raw position/count/offset arithmetic) | swift-ordinal / swift-cardinal / swift-affine | ≈ 4–5 |
| `Index<Element>` (typealias for `Tagged<Element, Ordinal>`) | swift-index-primitives | ≈ 8 |
| `Memory.Contiguous.Protocol` (the Storage bound on Worlds 1 owned cursors) | swift-memory-primitives | **12** |

The only *high-tier* dep is `Memory.Contiguous.Protocol` — required as the Storage generic bound on `Cursor.OwnedReader<Storage>` and `Cursor.OwnedReaderWriter<Storage>`. The other deps are at low-to-mid tiers and would not by themselves elevate cursor-primitives meaningfully. Memory-primitives currently sits at Tier 12 (the top of the existing 13-tier DAG); placing cursor-primitives above it puts cursor-primitives at Tier 13 — extending the tier structure by one.

Note (correction from the v1.1.0 draft): cursor-primitives does **not** need `swift-byte-primitives` as a dep. `Byte` (the value type) only appears as a *phantom `DomainTag`* at consumer instantiation sites (`Cursor.Span<Byte>` in `swift-binary-parser-primitives`). The cursor-primitives source itself writes `<DomainTag: ~Copyable>` as a generic parameter and never names `Byte`.

Any L1 primitive package at a tier lower than 13 that *might* want a cursor cannot use cursor-primitives. Today there is no such consumer; the risk is hypothetical. The tier rises if a new cursor-needing primitive surfaces at a lower tier, forcing either (a) a bespoke cursor in that package or (b) a tier reshuffle.

In contrast, Shape γ keeps `Binary.Cursor` / `Binary.Reader` in `swift-binary-primitives` (Tier ~10) and the World 2 unified primitive in its own home (lower tier — it doesn't need `Memory.Contiguous.Protocol` because World 2 is hard-coded to `Swift.Span<UInt8>`). No single package needs to sit at Tier 13 to absorb all cursor logic.

**Split-package mitigation under Shape ι**: if the tier elevation is the primary concern, the cursor types could split:

- `swift-cursor-span-primitives` (tier ≈ 8) — hosts only World 2's `Cursor.Span<DomainTag>`. No `Memory.Contiguous.Protocol` dep.
- `swift-cursor-primitives` (Tier 13) — hosts Worlds 1 and 3 — the cursors that need Storage genericity.

This split sacrifices some of Shape ι's centralization payoff but bounds the tier cost. It is a trade-off, not a free option; the implementation arc may choose this hybrid if `[BENCH-011]` or consumer evidence justifies it.

**2. Mission breadth and `[MOD-DOMAIN]` tension.** The cursor-primitives package's mission would be "byte-cursor mechanics across owned reader-writer, owned read-only, borrowed read-only Span, and owned Copyable input clusters." This is coherent as a *cursor mechanics* mission, but broader than the institute's typical per-domain package mission per `[MOD-DOMAIN]`. The four cursor type families share the cursor concept but differ on their type-system attributes (Escapable / `~Escapable` / Copyable / `~Copyable`).

Shape γ defends the per-domain placement: Binary.Cursor is *binary-domain*, Lexer.Scanner is *text-domain*, Binary.Bytes.Input is *binary-parser-domain*. Each cursor's mission is bound to its domain. Centralizing them in cursor-primitives sacrifices this per-domain coherence for cursor-mechanics consistency. Both framings are defensible; cursor-primitives is a defensible mission scope but not an obvious one.

Counter-argument: `Sequence.Protocol` lives in `swift-sequence-primitives` even though sequences are used across many domains. The institute's own pattern is cross-cutting primitive concepts in their own packages. Cursor-primitives would follow this pattern.

**3. Generic-specialization risk across module boundaries (`[BENCH-011]`).** Every cursor type in cursor-primitives carries one or two generic parameters (DomainTag, Storage). Methods on these types are generic. SwiftNIO's `ByteBuffer` is *non-generic* over storage specifically to guarantee inlining and specialization at the type definition site, avoiding cross-module specialization pitfalls.

Under Shape ι, every cursor method call from a domain package (`Binary.Cursor.advance(by:)`) crosses the cursor-primitives ↔ binary-primitives module boundary. Swift's monomorphization at known-DomainTag-and-known-Storage call sites *should* eliminate the indirection in optimized builds, but module-boundary specialization is the gray area. The `[BENCH-011]` integration probe is mandatory before landing.

Shape γ has the same risk for World 2 (one new package with a generic primitive). Shape ι amplifies it across all three Worlds.

**4. Migration cost.** Under Shape γ, only World 2's two existing implementations consolidate; Worlds 1 and 3 are untouched. Under Shape ι, all three Worlds migrate:

- `swift-binary-primitives` migrates `Binary.Cursor<Storage>` and `Binary.Reader<Storage>` to typealiases. Extensions like `extension Binary.Cursor where Storage: SomeProtocol { ... }` migrate to `extension Cursor.OwnedReaderWriter where Storage: SomeProtocol { ... }` — verbose, and the role-expressive `Binary.Cursor` identity becomes implicit via the typealias.
- `swift-binary-parser-primitives` migrates `Binary.Bytes.Input` (World 3) and `Binary.Bytes.Input.View` (World 2) to typealiases.
- `swift-lexer-primitives` migrates `Lexer.Scanner` to a thin wrapper (can't be a typealias because of tracker state).
- All cross-package consumers of these types continue to work via the typealiased identity, but extensions and protocol conformances on the original types need to be re-anchored.

This is bounded and pre-1.0-permissible per `[ARCH-LAYER-008]` correctness-driver, but it is a larger migration scope than Shape γ's World-2-only.

**5. Extension surface verbosity.** Extensions on `Binary.Cursor` under Shape γ are written as `extension Binary.Cursor where Storage: ... { ... }` — short and role-expressive at the call site. Under Shape ι, the same extensions become `extension Cursor.OwnedReaderWriter where DomainTag == Binary, Storage: ... { ... }` (or — if there is no DomainTag for Binary because owned cursors don't need a phantom domain tag separate from Storage — extensions on `Cursor.OwnedReaderWriter where Storage: ... { ... }` with the binary domain implicit).

The verbosity is real but small. Source-level readability degrades modestly at extension declarations; consumer call sites are unaffected.

**6. Wrapper overhead for state-augmented cursors.** `Lexer.Scanner` cannot be a typealias because it stores `Text.Location.Tracker` and `hasEmittedEndOfFile` beyond what `Cursor.Span<Text>` provides. It becomes a thin wrapper struct:

```swift
extension Lexer {
    @safe
    public struct Scanner: ~Copyable, ~Escapable {
        @usableFromInline internal var inner: Cursor.Span<Text>
        @usableFromInline internal var tracker: Text.Location.Tracker
        @usableFromInline internal var hasEmittedEndOfFile: Bool

        @inlinable
        public mutating func peek() -> UInt8? { inner.peek() }
        // ... forward every cursor method to inner ...
    }
}
```

Each forwarded method adds one layer of indirection at source. `@inlinable` should eliminate the runtime cost at well-known call sites, but the source-level boilerplate grows by ~5-8 forwarding methods on Scanner.

Under Shape γ, Lexer.Scanner stays as it is today — a direct concrete struct over Span<UInt8> with all its mechanics inline. No wrapper layer.

**7. The Three Worlds remain visible.** "Full unification" as a phrase invites the misreading "one cursor type for everything." That is not possible (Shape A's impossibility). Shape ι centralizes the *placement* of three cursor type families; the type system continues to enforce three structural clusters because Escapable / `~Escapable` and Copyable / `~Copyable` cannot be parameterized. Consumers see `Cursor.Span<DomainTag>` (~Escapable read-only), `Cursor.OwnedReader<Storage>` / `Cursor.OwnedReaderWriter<Storage>` (Escapable, `~Copyable`), and `Cursor.Input<Element>` (Copyable, Sendable) — three or four distinct types in the cursor namespace.

The unification is at the *naming + placement* level, not at the *type structure* level. This is a real but narrower achievement than the phrase "full cursor unification" might suggest.

**8. Coupling concentration.** All cursor-mechanics changes go through one package. Coordinated change across the cursor primitives is more disciplined under centralization (one package to test, one package to release), but it also makes the cursor-primitives package a single point of contention for unrelated cursor evolutions. Under Shape γ, World 1 changes ship via `swift-binary-primitives` independently of World 2 changes shipping via the World 2 home.

**9. Identity dilution.** `Binary.Cursor`'s public identity becomes "a typealias for `Cursor.OwnedReaderWriter<Storage>` where Storage is binary-tagged." For users reading API docs or stack traces, the indirection through the typealias is visible. Some readers find typealiased identities less role-expressive than direct concrete types. (E.g., a debugger showing `Cursor.OwnedReaderWriter<Buffer.Heap>` rather than `Binary.Cursor<Buffer.Heap>`.)

Mitigation: domain packages can wrap the cursor in a thin domain-named struct rather than typealias, preserving the role-expressive identity at the cost of one wrapper struct per cursor — but this defeats some of Shape ι's centralization benefit (now there are still three places where cursor identity is defined).

#### Comparison: Shape γ vs Shape ι on the institute's design axes

| Axis | Shape γ — distributed placement | Shape ι — centralized in cursor-primitives |
|------|----------------------------------|---------------------------------------------|
| Type structure | Three Worlds (W1 + W2 unified + W3) | **Same** |
| Position-type discipline | Unified to `Tagged<DomainTag, Ordinal>` across all cursors (in W2 unification; W1 and W3 already align) | **Same** |
| Package count for cursors | 2-3 packages (binary-primitives, binary-parser-primitives, + a new W2 home) | 1 cursor-primitives package + thin typealiases/wrappers in 3 domain packages |
| Decomposition + composition | Partial — W2 substrate decomposed and reused across two consumers; W1 and W3 substrates are domain-bound | **Full** — all cursor substrates in one place, domain packages compose typealiases/wrappers |
| Tier elevation | Bounded (W2 home is the only new tier rise) | Higher (cursor-primitives ≥ Tier 13, depends on memory + index + tagged + byte) |
| Mission boundaries per `[MOD-DOMAIN]` | Each cursor's domain is its package; explicit per-domain placement | Single cursor-mechanics mission; broader than per-domain default but coherent under the cursor concept |
| Generic-specialization risk (BENCH-011) | One generic primitive (W2) crossing module boundary | Three or four generic primitives crossing module boundaries |
| Migration cost | Small (only W2's two existing implementations consolidate) | Larger (all 3 Worlds' types move; extensions re-anchor; one wrapper struct for Scanner) |
| Discoverability | Cursors found per-domain; ad-hoc | Single package, single namespace; predictable |
| Extension verbosity | Domain-name-tight (`extension Binary.Cursor where ...`) | Verbose (`extension Cursor.OwnedReaderWriter where DomainTag == Binary, Storage: ...`) |
| Institute precedent | Per-domain ownership matches `[MOD-DOMAIN]` default | Sequence.Protocol / Index<T> / Tagged precedent for cross-cutting primitives in dedicated packages |
| User preference (2026-05-17 stated) | Partial match — only W2 unifies | **Full match** — all cursors built on shared cursor primitives |

#### Verdict on Shape ι

**Shape ι is structurally valid, passes `[RES-018]` case (a) and `[MOD-RENT]` three-criteria gates, and aligns with the user's stated preference (decomposition + composition; cursor-primitives package with domain-package typealiases). The drawbacks are real but bounded: tier elevation is a hypothetical concern (no current sub-Tier-13 cursor consumer); migration is one-time and pre-1.0-permissible; generic-specialization risk is testable via `[BENCH-011]` before landing.**

The choice between Shape γ-distributed and Shape ι-centralized is a structural trade-off, not a correctness verdict — both produce the same Three-Worlds type structure. The difference is *package placement* and the consequent trade-offs (mission breadth vs decomposition; tier elevation vs domain coherence; migration cost vs centralization payoff).

**Aligned with the institute's cross-cutting primitives precedent and the user's stated preference, Shape ι is the principally preferred placement.** Shape γ remains the conservative fallback if migration cost or generic-specialization risk surfaces during implementation.

### Decision matrix

| Shape | Composition | World coverage | Position-type unified | Structural correctness | Implementation cost |
|-------|-------------|---------------|----------------------|----------------------|---------------------|
| A | impossible | — | — | rejected | — |
| B (Cursor.Protocol) | unification at protocol only | all 3 | no | viable but premature | low |
| C | premature generalization | rejected | — | rejected | — |
| C′ | position-axis param | World 2 | yes | viable | medium |
| D | pull to byte-primitives | partial | yes | rejected (mission boundary) | low-medium |
| F | borrowed-Span cluster only | World 2 | yes | correct for World 2 | medium |
| **γ** | **F + 3-worlds framing, W2-only consolidation; W1/W3 stay in current packages** | **W2 (targets the genuine cross-domain duplication)** | **yes (W2 unifies; W1/W3 already aligned via Index<Storage> / Index<Element>)** | **AUTHORIZED 2026-05-17 as immediate Phases 0-3 (choice C, combined with ι)** | **medium (= F's cost)** |
| ε | position-only retrofit | World 2 partial | yes (in BBIV only) | partial — sole technical fallback if BENCH-011 surfaces unmitigable specialization regression | low |
| ζ | substrate-as-event-stream | wrong layer | n/a | rejected | high |
| η | iteratee at substrate | wrong layer | n/a | rejected | high |
| **ι** | **F + 3-worlds framing, centralized placement in swift-cursor-primitives** | **all 3, in one package** | **yes** | **AUTHORIZED 2026-05-17 as committed Phase 4 follow-on (choice C, combined with γ); not evaluated for whether — only for how (split-package vs single, post-Item-2 W3 placement)** | **medium-high (= γ's cost + cross-Worlds migration + Tier 13 commitment)** |

## Empirical Validation per Cognitive Dimensions Framework

Per `[RES-025]`. Six dimensions scored against the current shapes:

| Dimension | Status quo (per-domain concrete) | Shape γ (Three-Worlds + Shape F W2 unified) |
|-----------|----------------------------------|---------------------------------------------|
| **Visibility** | Per-domain concrete types are highly visible at their site (`Binary.Bytes.Input.View`, `Lexer.Scanner`). Easy to discover when working inside a single package. | World 2 primitive's name is visible to every consumer; binary and text consumers see the same cursor type with different DomainTag parameter. Cross-domain visibility is improved. |
| **Consistency** | Position-type discipline is *inconsistent* — View uses raw Int; Scanner uses Text.Position; Binary.Cursor uses Index<Storage>. Three different forms. | Position-type discipline is consistent — every cursor's position is `Tagged<DomainTag, Ordinal>` for some DomainTag. Even World 1 already aligns (Index<Storage>). |
| **Viscosity** | High viscosity in the borrowed cluster: any change to the cursor mechanics requires editing both Binary.Bytes.Input.View *and* Lexer.Scanner identically. The 2026-05-14 streaming-deserialize audit surfaced the duplication. | Lower viscosity: cursor-mechanics changes happen in one place. Domain overlays (binary's starts/copyToOwned, text's tracker + lexer helpers) remain in their domain packages. |
| **Role-expressiveness** | Domain-specific naming (`Scanner`, `Input.View`) telegraphs role at call sites. Easy to read intent. | Generic-named cursor with DomainTag parameter is less role-expressive at the cursor type itself. However, downstream typealiases (`typealias Scanner = Cursor<Text>`) or wrapper types can preserve role-expressive naming where domain consumers want it. Net role-expressiveness can be preserved via the typealias-or-wrapper layer. |
| **Error-proneness** | Two near-identical implementations are a known error class: bug-fix-in-one, miss-in-other. The 2026-05-14 audit's surfacing of the parallelism IS an instance of this risk. | Single implementation eliminates the bug-divergence class. Phantom-tagged positions (`Tagged<Byte, Ordinal>` ≠ `Tagged<Text, Ordinal>`) prevent cross-domain position confusion. |
| **Abstraction** | Concrete types each at one abstraction level. No abstraction overhead. | Single generic primitive introduces one abstraction level (the DomainTag generic). Generic specialization (via Swift's monomorphization) means runtime cost is unchanged at well-known DomainTag instantiations; cost is at compile time. |

**Scoring**: Shape γ improves four of six dimensions (Visibility, Consistency, Viscosity, Error-proneness), neutral or modest cost on two (Role-expressiveness, Abstraction). The Abstraction dimension's cost is bounded by the generic-specialization probe (BENCH-011, implementation-time concern) and the typealias-wrapper layer can restore Role-expressiveness where consumers want it.

Net: Shape γ scores favorably on the Cognitive Dimensions Framework against status quo, especially on the dimensions that matter for *cross-package* developer experience (Visibility, Consistency, Viscosity).

## Outcome

**Status**: DECISION (authorized 2026-05-17).

### Principal Authorization

**Date**: 2026-05-17.

**Authorized**: Choice C — Shape γ as the immediate move, with Shape ι expansion explicitly scheduled as a committed follow-on arc.

**Binding decisions**:

1. **Shape γ is the immediate move.** The implementation arc opens with the four-phase sequence (BENCH-011 probe → cursor-primitives package creation → Binary.Bytes.Input.View typealias + Lexer.Scanner wrapper migration → HANDOFF.md Item 2 resume) as specified in §Implementation Gating.

2. **Shape ι expansion is committed, not evaluated.** Phase 4 (the follow-on arc) executes Shape ι expansion — moving Worlds 1 and 3 into cursor-primitives — as the bound end-state. Phase 4 is not a decision point on *whether* to expand; it is execution work on *how* to expand.

3. **Technical gates inform expansion shape, not whether to expand.** BENCH-011 evidence from the W2 work, and HANDOFF.md Item 2's settled outcome, are inputs to Phase 4's shape — for example: whether to use split-package mitigation (Tier 6-8 + Tier 13 sibling packages) if BENCH-011 surfaces specialization regressions at the W1 owned-cursor module boundary; whether the typed-input cursor consolidated from Binary.Bytes.Input + Byte.Input lands in cursor-primitives as `Cursor.Input<UInt8>` vs `Cursor.Input<Byte>` vs in a consolidated byte-input home. These are shape questions, not gate questions.

4. **Sole technical fallback that voids the ι commitment**: BENCH-011 surfaces a fundamental generic-specialization regression at the W2 work that mitigation (`@inlinable` aggressive use; concrete typealiases at known instantiations; monomorphization tuning) cannot close. In that singular case, the W2 unification itself may need to fall back to Shape ε (position-only retrofit on `Binary.Bytes.Input.View`) and Shape ι expansion correspondingly aborts. No other path voids the ι commitment — Item 2's outcome does not, migration-cost surprises do not, identity-dilution concerns do not.

**What this authorization does**:

- Closes this Tier 3 arc as DECISION.
- Opens the implementation arc as a separate dispatch (not in scope here).
- Binds the eventual ecosystem end-state to Shape ι (full centralization of three cursor primitive type families in `swift-cursor-primitives`).
- Preserves the technical gates Shape γ established (BENCH-011 evidence; Item 2's typed-input outcome) as inputs to Phase 4's *shape*, not its *commitment*.

**What this authorization does NOT do**:

- Does not modify any source code (research arc is closed; implementation arc is separate).
- Does not pre-decide Phase 4's specific shape (package split vs single, position-type for consolidated W3, naming of follow-on package or typealias additions). Phase 4's dispatch authors that with BENCH-011 + Item 2 evidence in hand.
- Does not bind Items 3, 4, 5 of HANDOFF.md Wave 1 — those proceed independently per the original brief.

### Type structure — Three Worlds (load-bearing; same in either placement)

The institute L1 cursor ecosystem decomposes structurally into three clusters. This type structure is fixed by Swift's type system (Escapable / `~Escapable` and Copyable / `~Copyable` are not generic-parameterizable) and is independent of package placement:

| World | Cluster | Disposition under Shape γ (immediate move) |
|-------|---------|---------------------------------------------|
| 1 | Owned reader-writer (~Copyable, Escapable, Storage<UInt8>) | `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` — canonical primitives. **Remain in `swift-binary-primitives`** at this stage. Rw/ro is intentional structural specialization per `[API-IMPL-008]` / `[API-IMPL-006]`; not the kind of duplication centralization eliminates. |
| 2 | Borrowed read-only Span (~Copyable, ~Escapable, Span<UInt8>) | **UNIFY** the two near-identical cross-domain implementations into one primitive parameterized over `DomainTag`. `Binary.Bytes.Input.View` migrates to typealias; `Lexer.Scanner` migrates to thin wrapper. Position type aligns to `Tagged<DomainTag, Ordinal>` across both consumers. **Lives in a new cursor-primitives package** (Tier 6-8). |
| 3 | Owned Copyable input (Copyable, Sendable, [UInt8]) | `Binary.Bytes.Input` — canonical primitive. **Remains in `swift-binary-parser-primitives`** pending HANDOFF.md Wave 1 Item 2 (Binary.Bytes.Input vs Byte.Input typed-input unification), which operates within W3 and informs W3's eventual placement. |

### Package placement — Shape γ (W2 unification only) is the principled-first move; Shape ι expansion is a deferred follow-on arc

> **v1.2.0 revision (2026-05-17)**: v1.1.0 recommended Shape ι (full centralization in `swift-cursor-primitives`) as preferred. Reviewer feedback identified three structural defects in that framing: (a) the "eliminate duplication across all three Worlds" argument is uneven — W2 has cross-domain duplication; W1 has intentional rw/ro structural specialization (not eliminated by centralization); W3 stands alone with no duplication. (b) Tier 13 elevation is real, post-publication irreversible, and inadequately weighed — Shape γ with W2-only avoids the question entirely. (c) W3's placement is premature given HANDOFF.md Item 2 (Binary.Bytes.Input vs Byte.Input) is in flight within W3. v1.2.0 inverts the recommendation: **Shape γ is the immediate move; Shape ι expansion is a deferred follow-on arc** gated on Item 2 settling + BENCH-011 evidence.

The Three-Worlds type structure admits two placement patterns:

| Placement | Where cursor types live | Scope of change | Reversibility |
|-----------|--------------------------|-----------------|---------------|
| **Shape γ (immediate move)** | World 2's unified primitive in a new home (`swift-cursor-primitives` or `swift-cursor-span-primitives`); Worlds 1 and 3 remain in current packages | W2 only — targets the genuine cross-domain duplication | γ → ι is a small follow-on if evidence supports |
| Shape ι (deferred follow-on arc) | All three Worlds' types centralized in cursor-primitives; domain packages reduce to typealiases / thin wrappers | All three Worlds migrate | ι → γ is a costly back-out post-publication |

**The principled-first move is Shape γ**, on three grounds:

1. **The duplication-elimination case is W2-specific.** The genuine cross-domain duplication is the two near-identical `~Copyable & ~Escapable` Span-cursors (`Binary.Bytes.Input.View` and `Lexer.Scanner`). W1's (`Binary.Cursor` rw + `Binary.Reader` ro) is *intentional structural specialization* per `[API-IMPL-008]` / `[API-IMPL-006]` — two related sibling types in the same package with deliberately different operation sets. Centralization relocates the two struct declarations without eliminating them; the duplication is intentional and managed. W3 (`Binary.Bytes.Input`) stands alone with no duplication. Lumping the three Worlds together as "duplication everywhere" overstates the centralization payoff. The strongest unification case is W2 alone.

2. **Tier elevation is post-publication irreversible.** A W2-only cursor primitive does not need `Memory.Contiguous.Protocol` (it's hard-coded to `Swift.Span<UInt8>`); it sits at Tier 6-8 in the primitives DAG (depends on Tagged, Ordinal, Cardinal, Affine, Index). This is broadly reusable — Buffer-primitives at Tier 10, Binary-primitives at Tier 10, Lexer-primitives at Tier 10 can all consume it. A cursor-primitives package hosting Worlds 1 (which need `Memory.Contiguous.Protocol` at Tier 12 as the Storage bound) sits at Tier 13, cutting off every sub-Tier-13 consumer. The Tier 13 commitment is post-publication-irreversible; Shape γ avoids it entirely by leaving W1 in its current Tier 10 home.

3. **W3's placement is sequencing-premature given HANDOFF.md Item 2.** Item 2 (D5 Binary.Bytes.Input vs Byte.Input typed-input unification) is a separate in-flight arc that operates within W3. Its outcome may reveal that the typed-input cursor's natural home is `swift-cursor-primitives`, `swift-byte-parser-primitives`, or somewhere consolidated with Byte.Input. Pre-committing W3 to cursor-primitives via Shape ι forecloses placement options that Item 2 has not yet surfaced. Shape γ leaves Binary.Bytes.Input in its current package; Item 2 then settles within the existing W3 placement and the *combined* outcome of (Item 1 W2 unification + Item 2 typed-input unification) informs whether Shape ι expansion is warranted.

**Reversibility heuristic** (load-bearing): γ → ι is a small follow-on arc — once W2's unified primitive ships and matures, expanding cursor-primitives to host W1 and (post-Item-2) W3 is mechanically scoped. The reverse — backing out from Shape ι if BENCH-011 surfaces specialization regressions, or if Item 2 reveals W3 belongs elsewhere, or if the Tier 13 commitment proves costly — is a costly back-out involving package deletion, typealias unwinding, and consumer-side rebuilds. When the placement decision sits at the edge of certainty, the reversible move is principled-first.

**Why the original v1.1.0 arguments for Shape ι weaken under scrutiny**:

- *Institute cross-cutting precedent*: Sequence.Protocol / Index<T> / Tagged ARE in dedicated packages — but they centralize the cross-cutting *concept* (the protocol or the typealias); concrete instances live in their domain packages (Array, Stack, Queue all live separately). The institute pattern centralizes the horizontal abstraction, not all instances. Shape γ's W2-only centralization fits the precedent precisely (the borrowed Span-cursor is the horizontal concept); Shape ι's W1+W3 centralization extends beyond the precedent.
- *Decomposition + composition*: Shape γ fully satisfies this for W2. W2's mechanics decompose from W2's domain semantics; the unified W2 primitive is reused across binary and text consumers via DomainTag parameterization. Shape ι doesn't add decomposition beyond what γ provides; it adds *placement consolidation* — a separate concern.
- *Eliminates duplication across all three Worlds*: defective per Concern 1 above. Only W2 has true duplication.
- *User stated preference*: the user's "cursor-primitives + every cursor built on it" framing is satisfiable by either shape. Shape γ creates the cursor-primitives package (hosting W2); Shape ι expansion later expands it to W1 and W3 if evidence supports. The preference does not require immediate Shape ι.

**Shape ι expansion remains on the table as a follow-on arc**, gated on:
- HANDOFF.md Item 2 settling (informs whether W3 belongs in cursor-primitives).
- `[BENCH-011]` evidence from the W2 unification work (informs whether cross-module-boundary specialization is viable for the generic cursor primitive shape).
- A surfaced consumer at sub-Tier-13 needing cursor mechanics (would make the Tier 13 trade-off explicit rather than hypothetical).

If those gates clear and the evidence supports expansion, Shape ι is the natural next step. If they don't clear or the evidence cuts the other way, Shape γ stands as the final shape.

### Why this is principled

1. **Each World is a coherent semantic domain.** World 1 is owned-storage-with-write-capability; World 2 is borrowed-span-readonly; World 3 is owned-array-with-input-protocol-semantics. Each carries different type-system attributes, different storage requirements, and different intended consumer patterns. `[MOD-DOMAIN]` favors per-domain primitive grouping.

2. **World 2 unification is empirically justified.** The two existing implementations share ~50 LOC of mechanically-identical scaffolding and differ only in position-type discipline (raw Int vs Tagged<Text, Ordinal>) and domain-specific overlays. The position-type divergence is not load-bearing — it is implementation-historical (per byte-cursor v1.3.0's empirical decomposition probe, surviving v1.3.0's downgrade because the probe itself was source-level grounded). The domain overlays compose above the unified substrate.

3. **The structural-constraint claim from Lifetime Dependent Borrowed Cursors.md is obsolete.** SE-0503 lifts the protocol-associatedtype constraint. The institute already runs Parser.Protocol with `associatedtype Input: ~Copyable & ~Escapable`. The doc's non-closure-runner-surface recommendation survives — and is in fact already implemented in `Parser.Protocol`, unified across owned + borrowed worlds via the associated-type mechanism.

4. **Worlds 1 and 3 should stay structurally separate.** Their type-system attributes diverge enough (`~Copyable` vs Copyable; generic-Storage vs `[UInt8]`-fixed; reader-writer dual-index vs reader-only single-index) that a single parameterized cursor type would be either (a) too constrained to fit both, or (b) so generic that role-expressiveness collapses. Three structural primitives, each tuned for its world, is the institute's modularity discipline.

5. **The institute already has all the substrate pieces in place.** SE-0503 is accepted. `Sequence.Protocol` family demonstrates `~Copyable & ~Escapable` protocols and associated types at scale. Property accessor pattern + SE-0456 + `@_lifetime` are mature. Tagged-position discipline is pervasive. The recommendation is *one new primitive* (World 2 unified), not a wholesale rewrite.

6. **Lexer.Pull.Stream pattern validates the layered approach.** The institute already practices a two-layer cursor hierarchy — substrate (Lexer.Scanner) + structural-event (Lexer.Pull.Stream). The recommendation preserves this; Pull.Stream simply wraps the World 2 unified primitive instead of wrapping Scanner directly.

### Why the alternative shapes lose

- Shape A (single generic): structurally impossible.
- Shape B (Cursor.Protocol): unification at the *interface*, not the implementation; no consumer yet needs generic-over-cursors dispatch. Premature.
- Shape C (Element-generic): premature generalization on an axis with no cross-domain pressure.
- Shape D (Pull to byte-primitives): mission-boundary tension with byte-primitives' established pure-value-layer scope.
- Shape ε (position-only retrofit): closes the position-type outlier but leaves the implementation duplication; structurally less complete.
- Shape ζ (substrate-as-event-stream): conflates abstraction layers.
- Shape η (iteratee at substrate): same layer-conflation error.

### Acceptance criteria

The implementation arc that follows this DECISION executes **Shape γ as the immediate move** and **Shape ι expansion as a committed follow-on arc**. Per the Principal Authorization §, Shape ι is not "evaluated later"; it is bound, with technical gates informing its *shape* rather than its *commitment*.

**Phases 0-3: Shape γ (immediate)** — the implementation arc must satisfy:

1. **`[BENCH-011]` integration probe** as Phase 0. Generic specialization of `~Copyable & ~Escapable` types parameterized over `Tagged<DomainTag, Ordinal>` is the load-bearing perf assumption. Probe the binary-parsing and text-lexing hot paths against current per-domain implementations BEFORE any source change. If a regression surfaces that mitigation (`@inlinable`, monomorphization tuning) cannot close, the arc reverts to Shape ε (position-only retrofit on `Binary.Bytes.Input.View`) AND Shape ι expansion correspondingly aborts. This is the sole technical fallback that voids the ι commitment.
2. **One new L1 package** hosts World 2's unified primitive. Naming: `swift-cursor-primitives` is the principal-authorized choice — the package is the eventual end-state home for all three Worlds under Phase 4 expansion, so the name does not artificially restrict to Span-substrate. Tier at Phase 1: 6-8 (Tagged + Ordinal + Cardinal + Affine + Index deps; no Memory.Contiguous.Protocol). Phase 4 expansion lifts the tier to ≥ 13 (per the authorization's accepted Tier 13 commitment) or maintains the split-package mitigation depending on BENCH-011 evidence. **API surface (as implemented)**: `init(_:Span<UInt8>)`, `position`, `count`, `isAtEnd`, `peek()`, `peek(at:)`, `advance()`, `advance(by:)`, `consume()`, `seek(to:)`. `seek(to:)` was added beyond the originally-enumerated surface (peek / peek(at:) / advance / advance(by:) / consume / isAtEnd / count / position) to support parser-machine backtracking — `Binary.Bytes.withBorrowed`'s alternative-frame branches restore the cursor to a previously-captured position when a branch fails; the legacy `public var position: Int` settable allowed this directly, and the cursor analog is `seek(to:)`. Position-only seeks are well-defined on a borrowed Span-cursor because no data is consumed destructively. Class-(c) judgment within the spec's "(exact signatures: your judgment within the spec)" latitude.
3. **`Binary.Bytes.Input.View` migrates to typealias** on the unified W2 primitive. Position type migrates from raw `Int` to `Tagged<Byte, Ordinal>` (or the chosen DomainTag). Source-transparent at construction sites; extensions on the typealiased identity may need re-anchoring to the cursor-primitives type.
4. **`Lexer.Scanner` migrates to a thin wrapper struct** composing the W2 substrate with `Text.Location.Tracker` overlay state. `@inlinable` forwarding methods eliminate runtime indirection at known call sites. Existing `Lexer.Scanner` consumer API remains source-compatible.
5. **Worlds 1 and 3 unchanged in Phases 0-3.** `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` remain in `swift-binary-primitives`; `Binary.Bytes.Input` remains in `swift-binary-parser-primitives`. They migrate in Phase 4.
6. **HANDOFF.md Wave 1 Item 2 resumes** after the W2 unification lands. Item 2 (D5 Binary.Bytes.Input vs Byte.Input typed-input unification) operates within the existing W3 placement; its outcome informs Phase 4's shape (specifically: the consolidated typed-input cursor's identity and placement within the eventual cursor-primitives), not whether Phase 4 executes.
7. **HANDOFF.md Wave 1 Items 3, 4, 5** are independent of this substrate question; they may proceed in parallel.

**Phase 4: Shape ι expansion (committed follow-on)** — the follow-on dispatch must satisfy:

- **Worlds 1 and 3 migrate** to cursor-primitives as typealiases (Binary.Cursor / Binary.Reader / Binary.Bytes.Input) or thin wrappers where state augmentation requires (none anticipated at W1/W3, but the option is open).
- **Tier 13 commitment** is made explicit. If BENCH-011 evidence from the W2 work surfaced a specialization concern at the W1 owned-cursor module boundary, **split-package mitigation** is the principal-pre-authorized response: `swift-cursor-span-primitives` (Tier 6-8, W2 alone — already created in Phase 1, possibly renamed) + `swift-cursor-primitives` (Tier 13, Worlds 1+3). If BENCH-011 is uniformly clean, the single-package outcome is preferred.
- **Item 2's settled outcome** informs the W3 consolidated typed-input cursor's identity and placement (e.g., whether `Cursor.Input<UInt8>` or `Cursor.Input<Byte>` is the canonical form, given Item 2's resolution of Binary.Bytes.Input vs Byte.Input consolidation).
- **Migration is one-time and pre-1.0-permissible** per `[ARCH-LAYER-008]` correctness-driver. Extensions on Binary.Cursor / Binary.Reader / Binary.Bytes.Input re-anchor to the cursor-primitives types.
- **Phase 4 dispatch is gated on**: Phase 3 (Item 2 resume) reaching a settled outcome on the typed-input question, AND BENCH-011 evidence from Phases 1-3 being available. Phase 4 does not gate on a *new* evaluation of whether to proceed; only on the inputs to its shape.

### What this DECISION does NOT specify

- **Phase 4's specific shape**: single-package vs split-package, the W3 consolidated typed-input cursor's exact identity, position-type retrofit fine-grained sequencing. Phase 4's dispatch authors these with BENCH-011 + Item 2 evidence in hand.
- **Final cursor primitive type naming** beyond the principal-authorized package name (`swift-cursor-primitives`). Open Question Q1 candidates remain open for the cursor TYPES inside the package.
- **Detailed package structure** of `swift-cursor-primitives` (Core, variants, umbrella per `[MOD-001]`/`[MOD-005]`; Test Support per `[MOD-024]`). Standard institute package structure; implementation-time concern.
- **Whether to add a Cursor.Protocol** (Shape B) as a future enhancement. Stays open until a generic-over-cursors consumer materializes.
- **Whether to retrofit `Binary.Bytes.Input`'s position from `Index<UInt8>` to `Index<Byte>`**. That is HANDOFF.md Wave 1 Item 2's province; Phase 4 inherits Item 2's outcome.
- **Implementation sequencing**, source modifications, or dispatch authoring. Per the original brief's ground rules, this DECISION is research only; the implementation arc is a separate dispatch.

## Implementation Outcomes

The implementation arc executing Phases 0-3 of Shape γ landed across three packages between 2026-05-17 and 2026-05-17, under principal supervision. Phase 4 Shape ι expansion remains pending per the authorization — gated on HANDOFF.md Wave 1 Item 2 settling.

### Phase 0 — BENCH-011 integration probe (HARD GATE)

Probe at `swift-institute/Experiments/cursor-span-bench-011/` (release build, macOS 26 / arm64e, 200 iterations × 65 KiB buffer, warmup 10):

| Probe | Legacy | Cursor | Ratio |
|---|---|---|---|
| Text peekAdvance | 165.75 µs | 165.50 µs | 0.998 |
| Text consume | 165.54 µs | 165.50 µs | 1.000 |
| Binary consumeLoop | 17.27 ms | 162.9 µs | 0.009 |
| Binary peekAdvance | 17.70 ms | 839 µs | 0.047 |

Text path parity (Lexer.Scanner already used `Tagged<Text, Ordinal>` position — see §Implementation Notes for the structural difference). Binary path 20-100× faster. No regression on any path. **Phase 0 gate: GREEN.**

### Phase 1 — swift-cursor-primitives created

- Repository: `swift-primitives/swift-cursor-primitives` (PRIVATE; public release requires separate principal YES per `feedback_never_create_public_repos.md`).
- Tier: 6-8 in the primitives DAG. Deps: `swift-tagged-primitives`, `swift-ordinal-primitives`, `swift-cardinal-primitives`, `swift-index-primitives` (Test Support spine only). NO `Memory.Contiguous.Protocol` dep.
- Structure: 4 library products per `[MOD-001]` / `[MOD-005]` / `[MOD-024]` — Core (namespace + re-exports), Cursor Span Primitives (variant hosting `Cursor.Span<DomainTag>`), umbrella, Test Support (anchored on `Index_Primitives_Test_Support`).
- Lint configuration: `Lint.swift` declares `Lint.Rule.Bundle.primitives`. swift-linter run: 0 findings on cursor-primitives source.
- Tests: 12 pass in 6 suites (Unit / Edge Case / Integration / Performance per `[TEST-005]`; Performance suite empty — substantive benchmarks live in the BENCH-011 experiment).
- Commits: `0f57273` (initial) + `2bd7800` (add `seek(to:)` for parser-machine backtracking).

### Phase 2a — Binary.Bytes.Input.View migration

- Repository: `swift-primitives/swift-binary-parser-primitives` commit `13e4dbf2`.
- Type shape: `Binary.Bytes.Input.View` is now `typealias View = Cursor.Span<Byte>` (`Byte` from `swift-byte-primitives` as DomainTag).
- Position retrofit: `var position: Int` → `var position: Tagged<Byte, Ordinal>` (read-only computed on cursor; writeback via `Cursor.Span.seek(to:)`).
- Count retrofit: `var count: Int` → `var count: Tagged<Byte, Cardinal>` (see §Implementation Notes for source-transparency verification).
- Legacy binary-domain API preserved via `@inlinable` extensions on `Cursor.Span where DomainTag == Byte`: `isEmpty`, `first`, `removeFirst`, `removeFirst(_:)`, `consumedCount`, `subscript[offset:]`, `starts(with:)`, `copyToOwned()`, plus the `Index<UInt8>` subscript from `+typed.swift`.
- `Binary.Bytes.withBorrowed` parser-machine backtracking migrated from `view.position = N` to `view.seek(to: savedCheckpoint.retag(Byte.self))`.
- Tests: 69 pass in 22 suites.
- New deps: `swift-byte-primitives`, `swift-cursor-primitives` (path-form per `[PKG-DEP-001]`).

### Phase 2b — Lexer.Scanner migration

- Repository: `swift-primitives/swift-lexer-primitives` commit `575e4cb`.
- Type shape: `Lexer.Scanner: ~Copyable, ~Escapable` is now a thin wrapper struct with stored fields `inner: Cursor.Span<Text>` + `source: Span<UInt8>` (preserved for sub-span extraction in internal lexing helpers) + `tracker: Text.Location.Tracker` + `hasEmittedEndOfFile: Bool`.
- Public API preserved exactly: `init(_:)`, `position`, `location`, `location(at:)`, `isAtEnd`, `peek()`, `peek(at:)`, `advance()`, `advance(by:)`, `consume()`, `newline(at:)`, `next(diagnostics:)`. All forwarded via `@inlinable`.
- Internal `cursor` accessor (forwards reads to `inner.position`, writes to `inner.seek(to:)`) preserves Scanner+Lexing.swift's `cursor += .one` hot-loop pattern without mechanical refactor. `@inlinable` collapses the indirection in release builds.
- Tests: 48 pass in 3 suites.
- New deps: `swift-cursor-primitives` (path-form).

### Phase 3 — Termination gate per [HANDOFF-035] / [HANDOFF-040]

Workspace-wide grep (literal + generic-instantiated forms) for `Binary.Bytes.Input.View`, `Lexer.Scanner`, and `Cursor.Span` across `swift-primitives` + `swift-standards` + `swift-foundations`: zero residuals on old shapes. All references are expected — internal package sources, the typealias declaration sites, the wrapper declaration site, and docstring/comment mentions in research notes.

Ecosystem-wide `swift build --build-tests` from a fresh `.build` across every transitive consumer:

| Package | Build | Tests |
|---|---|---|
| swift-primitives/swift-cursor-primitives | green | 12 pass |
| swift-primitives/swift-binary-parser-primitives | green | 69 pass |
| swift-primitives/swift-lexer-primitives | green | 48 pass |
| swift-primitives/swift-binary-coder-primitives | green | (not run) |
| swift-foundations/swift-lexer | green | 6 pass |
| swift-foundations/swift-json | green | **216 pass** |
| swift-foundations/swift-ascii | green | (not run) |

swift-json's 216 tests passing is the load-bearing signal — it's the major Lexer.Scanner external consumer (stores `var scanner: Lexer.Scanner`, forwards extensively to its cursor operations).

## Implementation Notes

These notes record substantive findings surfaced during the implementation arc that were not pre-determined by the DECISION.

### Count retrofit (Int → `Tagged<Byte, Cardinal>`) was not in the original brief

The DECISION's §Implementation Gating Phase 1 prescribed the **position** retrofit (`Int → Tagged<Byte, Ordinal>`) as the explicit pre-1.0 breakage permitted per `[ARCH-LAYER-008]`. The migration also retrofitted **count** (`var count: Int → var count: Tagged<Byte, Cardinal>`) because `Cursor.Span<DomainTag>` exposes a typed `count: Tagged<DomainTag, Cardinal>` accessor and a coexisting `count: Int` accessor would have introduced a duplicate-name compile collision.

Source-transparency at the build level: verified by the Phase 3 ecosystem build gate (216 swift-json tests + 69 binary-parser-primitives tests pass, including test code that does `let n = view.count` and `#expect(n == 5)`).

Source-transparency at the semantic level: verified by workspace-wide grep for `view.count` usages on Binary.Bytes.Input.View. The only matches are (a) the package's own tests (already verified passing) and (b) a comment in `Binary.Bytes.withBorrowed.swift` line 329 (`// Compute remaining from locals (avoid view.count)` — not actual code). No downstream code performs typed-arithmetic (`view.count + intExpr`) or annotated-type assignments (`let n: Int = view.count`) on the retrofit-affected `view.count`. The retrofit holds in spirit, not just in build-passing.

The same retrofit-extension justification applies to `consumedCount` and `position`: the typed forms enable the cursor's typed-position discipline; preserving the Int form would have required either a name collision or a renamed accessor.

### Binary 20-100× speedup root cause

The Phase 0 BENCH-011 probe showed Cursor.Span<Byte> outperforming legacy Binary.Bytes.Input.View by 20-100× on hot-loop paths. This is not benchmark anomaly or compiler magic. The structural difference:

```swift
// Pre-migration Binary.Bytes.Input.View
public struct View: ~Copyable, ~Escapable {
    @usableFromInline let span: Span<UInt8>
    public var position: Int       // ← PUBLIC stored property, no @inlinable
    ...
}

// Post-migration Cursor.Span<DomainTag>
public struct Span<DomainTag: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    @usableFromInline internal let source: Swift.Span<UInt8>
    @usableFromInline internal var _position: Tagged<DomainTag, Ordinal>
    ...
}
```

`public var position: Int` is a public stored property without `@inlinable`. Public stored properties default to *resilient* access — the compiler emits opaque getter/setter call sequences rather than direct field loads/stores, because the storage layout is not part of the module's stable ABI by default. Inside `@inlinable` mutating methods like `removeFirst()`, every position read and every position write goes through the resilient access pattern, which optimizer passes cannot fully simplify.

`@usableFromInline internal var _position` is the cursor's pattern. Internal visibility with `@usableFromInline` means the storage is non-resilient (it's part of the module's compile-time-known layout) AND is accessible from `@inlinable` methods, so the optimizer can inline position reads/writes as direct memory operations.

`Lexer.Scanner`'s pre-migration cursor field was already `@usableFromInline internal var cursor: Text.Position` — the same pattern as the post-migration cursor. The Text path therefore showed parity, not speedup. The Binary path's speedup is *specifically* the optimization that the legacy `public var position: Int` was preventing.

This is the (a) category from the principal review: legacy Binary.Bytes.Input.View had a real perf defect that the cursor migration accidentally fixed. The defect is not unique to this type — any `public var` stored property on an `@inlinable`-method-bearing struct pays the same hidden cost. An ecosystem-wide audit for the `public var` storage pattern is worth scheduling before pre-1.0, separate from this arc.

Full investigation record: `swift-institute/Experiments/cursor-span-bench-011/README.md`.

## Open Questions Routed to Implementation

These questions are out of scope for this RECOMMENDATION but must be settled at implementation time.

### Q1: Naming of the World 2 unified primitive

Candidates (alphabetical, all valid):

| Candidate | Reading | Trade-offs |
|-----------|---------|-----------|
| `Bytes.Cursor<DomainTag>` | "A byte-stream cursor in the DomainTag domain" | Reads well; collides with existing `Binary.Cursor` naming if Binary is the DomainTag (`Binary.Cursor` is already taken at L1). |
| `Byte.Cursor<DomainTag>` | "A byte cursor over a DomainTag-tagged stream" | Subject-first per `[API-NAME-001b]` if "Byte" is the subject and "Cursor" is the role. But Byte.Cursor inside swift-byte-primitives violates [API-NAME-001b] in the other direction — DomainTag is the larger domain. |
| `Cursor.Span<DomainTag>` | "A Span-cursor tagged with DomainTag" | Establishes new Cursor namespace. Awkward to reach with Binary.Cursor and Lexer.Scanner already present. |
| `Input.Span.Cursor<DomainTag>` | "An input-span cursor tagged with DomainTag" | Naturally nests under input-primitives. Long. |
| `Span.Cursor<DomainTag>` | "A Span cursor tagged with DomainTag" | Reads cleanly. Establishes Span namespace at L1 (distinct from Swift.Span). |
| `<DomainTag>.Cursor` | "The cursor in the DomainTag domain" (e.g., `Byte.Cursor`, `Text.Cursor`) | Distributes the primitive across domain packages. Goes against the unification intent — same generic logic re-instantiated per domain. **Rejected** on those grounds. |

Per the institute's `[API-NAME-001b]` Subject-vs-Role rule: the cursor here is the role; the subject is the bytes / span / input substrate. The candidate that best matches is one with the substrate-name as the subject: `Span.Cursor<DomainTag>`, `Bytes.Cursor<DomainTag>`, or `Input.Span.Cursor<DomainTag>`.

The implementation arc decides.

### Q2: Package home for the cursor primitives

Two questions nest here: (a) under Shape ι, what is the cursor-primitives package's name and scope; (b) under Shape γ fallback, where does the World 2 unified primitive live.

**Under Shape ι (preferred)** — the new package `swift-cursor-primitives` hosts all three Worlds' cursor primitive types in one place:

| Type | In cursor-primitives | Domain package's role |
|------|----------------------|------------------------|
| `Cursor.Span<DomainTag>` (W2 borrowed read-only) | concrete primitive | `Binary.Bytes.Input.View` typealias to `Cursor.Span<Byte>` in `swift-binary-parser-primitives`; `Lexer.Scanner` thin wrapper around `Cursor.Span<Text>` in `swift-lexer-primitives` |
| `Cursor.OwnedReader<Storage>` (W1 read-only owned) | concrete primitive | `Binary.Reader<Storage>` typealias in `swift-binary-primitives` |
| `Cursor.OwnedReaderWriter<Storage>` (W1 read-write owned) | concrete primitive | `Binary.Cursor<Storage>` typealias in `swift-binary-primitives` |
| `Cursor.Input<Element>` (W3 Copyable input) | concrete primitive | `Binary.Bytes.Input` typealias in `swift-binary-parser-primitives` |

Package naming candidates for the centralized home:

| Candidate | Reading | Trade-offs |
|-----------|---------|------------|
| `swift-cursor-primitives` | "Cursor primitives" — package follows the unified concept's name | Clean. Matches the user's framing ("cursor-primitives"). Does not bind to a specific substrate (Span, Storage, Array). |
| `swift-byte-cursor-primitives` | "Byte-cursor primitives" — restricted to byte-cursors | Reflects current scope (all cursors are over UInt8 today). Less future-proof if non-byte cursors materialize. |
| `swift-span-cursor-primitives` | "Span-cursor primitives" — restricted to Span-cursors | Captures only World 2; doesn't fit centralizing all three Worlds. Better fit under Shape γ fallback for the W2 home alone. |

The preferred name under Shape ι is `swift-cursor-primitives` — it's the user-stated name, it doesn't artificially restrict to a substrate, and it matches institute precedent (`swift-sequence-primitives` is not "swift-collection-sequence-primitives").

**Under Shape γ (conservative fallback)** — Worlds 1 and 3 stay in their current packages; only World 2's unified primitive needs a home:

| Package | Rationale | Trade-offs |
|---------|-----------|-----------|
| New `swift-span-cursor-primitives` (or `swift-byte-cursor-primitives`) | Focused single-purpose L1 package for W2 only | Adds one package. Per `[RES-018]` case (a), cross-domain-fit ✓ (binary + text), composition check ✓. Per `[MOD-RENT]` three-criteria ✓. |
| `swift-input-primitives` (extension) | Composes with existing Input.Protocol family | Span-cursor doesn't conform to Input.Protocol (~Escapable vs ~Copyable-only). Sibling abstractions, not a refinement chain. Stretches the package's mission. |
| `swift-lexer-primitives` (extension) | Lexer.Scanner already lives here | Binds the borrowed substrate to text-domain naming. Mission-boundary issue. |
| `swift-byte-primitives` (extension) | Byte is the conceptual unit | Mission-boundary issue per Shape D rejection — byte-primitives is a pure-value layer. |
| `swift-binary-parser-primitives` (extension) | Binary.Bytes.Input.View already lives here | Inverts layering (text consumers would depend on binary-parser-primitives for the substrate). |

Under Shape γ, a new focused package is the most architecturally clean option per `[RES-018]` case (a) + `[MOD-RENT]`. The implementation arc decides between Shape ι's cursor-primitives package and Shape γ's narrower W2 home, with `[BENCH-011]` evidence as the empirical input.

### Q3: Position-type retrofit for Binary.Bytes.Input.View

`Binary.Bytes.Input.View.position: Int` (current) → `Tagged<Byte, Ordinal>` (proposed under Shape γ).

This change is part of the World 2 unification but warrants explicit confirmation: the View's public API exposes `position` as a public stored property. Migrating to a typed position changes the public API. The migration may be staged:

- v0.x: introduce the unified primitive; deprecate `position: Int` as a legacy accessor; expose `position: Tagged<Byte, Ordinal>` as canonical.
- v1.0: remove the deprecated Int accessor.

OR migrate immediately as a breaking change at the pre-1.0 stage per `[ARCH-LAYER-008]` correctness-driver discipline (the institute is pre-1.0 in this domain; correctness-driven shaping is permitted).

The implementation arc decides the staging.

### Q4: Domain overlay placement

`Binary.Bytes.Input.View`'s binary-specific methods (`starts(with:)`, `copyToOwned()`) and `Lexer.Scanner`'s text-specific methods (`newline(at:)`, `location`, `location(at:)`) live in their respective packages today. After unification:

- Option A: keep all overlay methods as extensions on the unified primitive specialized via DomainTag (`extension Cursor where DomainTag == Byte { func starts(with:) }`; `extension Cursor where DomainTag == Text { func newline(at:) }`). One file per domain extension, in the unified-primitive package OR in the domain's own package.
- Option B: keep overlays in their existing domain packages (`swift-binary-parser-primitives` extension on `Cursor<Byte>`; `swift-lexer-primitives` extension on `Cursor<Text>`).

Option B aligns with the institute's `[MOD-DOMAIN]` discipline (domain-specific code stays in domain packages). The unified primitive's package owns the substrate; consumers own their overlays.

The implementation arc decides; Option B is the principled default.

### Q5: Whether to add `Cursor.Protocol` (Shape B) as a future enhancement

`Cursor.Protocol` would abstract over all three Worlds. Today, no consumer needs generic-over-cursors dispatch — `Parser.Protocol` already abstracts at the right layer (its associatedtype Input accepts any `~Copyable & ~Escapable` shape, which includes all three Worlds' cursor types directly).

If a future consumer materializes that needs "any cursor, regardless of world" generic dispatch, Cursor.Protocol can be added without disrupting the three Worlds. Defer the decision until that consumer is named.

## Revisit Conditions

This DECISION is closed under the 2026-05-17 Principal Authorization. Revisit conditions for the *implementation plan* (Shape γ Phases 0-3 + Shape ι Phase 4), not the DECISION itself:

1. **Sole technical fallback voiding Shape ι expansion**: if `[BENCH-011]` surfaces a fundamental generic-specialization regression at the W2 work that mitigation (`@inlinable` aggressive use; concrete typealiases at known instantiations; monomorphization tuning) cannot close, the W2 unification falls back to Shape ε (position-only retrofit on `Binary.Bytes.Input.View`) and Shape ι expansion correspondingly aborts. This is the only path that voids the ι commitment.
2. **Inputs to Phase 4 shape (not gates)**: `[BENCH-011]` evidence from Phases 1-3 informs whether Phase 4 uses single-package (`swift-cursor-primitives` Tier 13) or split-package mitigation (`swift-cursor-span-primitives` Tier 6-8 + `swift-cursor-primitives` Tier 13). HANDOFF.md Item 2's settled outcome informs the W3 consolidated typed-input cursor's identity in Phase 4.
3. **Compiler-side revisit**: if Swift 6.x introduces a new constraint affecting `~Copyable & ~Escapable` generic types in ways not visible from the ecosystem's existing usage, the implementation may stage differently or amend this DECISION via v1.4.0.
4. **Inventory-side revisit**: if a seventh+ structural cursor abstraction surfaces at L1 that materially changes the cross-product of axes (e.g., a `MutableSpan<UInt8>`-backed borrowed reader-writer for some new use case), revisit the Worlds inventory.
5. **Protocol-discipline revisit**: if `Parser.Protocol`'s associated-type discipline changes (e.g., relaxes ~Copyable & ~Escapable constraint), revisit whether the cursor primitives need to align.

## Out of Scope

- **Implementation** of any cursor primitives. Per the brief's ground rules, this is research only.
- **Naming, package home, retrofit staging** — routed to the implementation arc (Open Questions §).
- **Item 2 (D5 Binary.Bytes.Input vs Byte.Input typed-input unification)** — separate arc at HANDOFF.md Wave 1 Item 2. This RECOMMENDATION's Shape γ framing positions it: Item 2 operates within World 3, deciding how the owned Copyable input cursor should be named and whether `Binary.Bytes.Input` and `Byte.Input` should consolidate. The substrate question is settled here; the naming/consolidation is Item 2's province.
- **Items 3, 4, 5** of HANDOFF.md Wave 1 — independent of the substrate question; may proceed in parallel.
- **Higher-layer cursor abstractions (Lexer.Pull.Stream, format-specific Event Streams)** — already at the right layer; substrate decisions here propagate naturally.
- **Async cursors and L3 cursor patterns** — out of scope for the L1 question.

## References

### Internal corpus (institute)

- `swift-institute/Research/byte-cursor-primitive-unification.md` v1.0.0–v1.3.0 — predecessor arc; Shape F decomposition insight survives as INPUT to this arc.
- `swift-primitives/swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md` v1.0.0 (RECOMMENDATION, 2026-01-19) — the 2026-01-19 doc whose structural-constraint claim is reassessed here. The doc's non-closure runner surface recommendation survives; the protocol-split recommendation is superseded by SE-0503.
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1 (DECISION, 2026-05-15) — parent byte-arc decisions including [API-NAME-001b] precedent.
- `swift-institute/Research/byte-protocol-capability-marker.md` v1.1.0 — [API-NAME-001c] precedent; clarifies that this arc's question is structurally different from the capability-marker one.
- `swift-institute/Research/ascii-parsing-domain-ownership.md` v4.2.0 (RECOMMENDATION, 2026-03-04) — earlier subject-first naming precedent on a different domain pair.
- `swift-institute/Research/typed-infrastructure-catalog.md` — Tier 3 systematic audit backing the existing-infrastructure skill; documents the Tagged<DomainTag, Ordinal> position discipline.
- `swift-primitives/swift-lexer-primitives/Research/lexer-primitives-scope.md` (DEFERRED, 2026-03-15) — D2 prior decision: lexer cursor stays separate from Input.Protocol layer.
- `swift-primitives/swift-binary-parser-primitives/Research/full-internal-typing-interpreter.md` (DECISION, 2026-01-29) — typed-index discipline applied to Binary.Bytes.withBorrowed interpreter.

### Source-code anchors (verified at HEAD 2026-05-17)

- `swift-primitives/swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Cursor.swift:42` — `public struct Cursor<Storage: Memory.Contiguous.Protocol & ~Copyable>: ~Copyable where Storage.Element == UInt8`
- `swift-primitives/swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Reader.swift:42` — `public struct Reader<Storage: Memory.Contiguous.Protocol & ~Copyable>: ~Copyable where Storage.Element == UInt8`
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input View Primitives/Binary.Bytes.Input.View.swift:50` — `public struct View: ~Copyable, ~Escapable`
- `swift-primitives/swift-binary-parser-primitives/Sources/Binary Input Primitives/Binary.Bytes.Input.swift:45` — `public struct Input: Sendable`
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Scanner.swift:39` — `public struct Scanner: ~Copyable, ~Escapable`
- `swift-primitives/swift-lexer-primitives/Sources/Lexer Primitives/Lexer.Pull.Stream.swift:54` — `public struct Stream<Tokens: Lexer.Pull.Tokens>: ~Copyable, ~Escapable`
- `swift-primitives/swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90` — `public protocol \`Protocol\`<Input, Output, Failure>: ~Copyable` with `associatedtype Input: ~Copyable & ~Escapable`
- `swift-primitives/swift-sequence-primitives/Sources/Sequence Primitives Core/Sequence.Protocol.swift:92` — `public protocol \`Protocol\`<Element>: ~Copyable, ~Escapable` with `associatedtype Iterator: ... & ~Copyable & ~Escapable`
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text.Position.swift:27` — `public typealias Position = Tagged<Text, Ordinal>`
- `swift-primitives/swift-index-primitives/Sources/Index Primitives Core/Index.swift:38` — `public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>`
- `swift-primitives/swift-input-primitives/Sources/Input Primitives/Input.Protocol.swift:66` — `public protocol \`Protocol\`<Element>: Streaming, ~Copyable` with `associatedtype Checkpoint: Comparable`
- `swift-foundations/swift-json/Sources/JSON/JSON.Span.EventStream.swift:30` — `public struct EventStream: ~Copyable, ~Escapable` wrapping `Lexer.Pull.Stream<RFC_8259.Pull.Tokens>`

### Swift Evolution

- [SE-0377: borrowing and consuming parameter ownership modifiers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0377-parameter-ownership-modifiers.md)
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md)
- [SE-0432: Borrowing and consuming pattern matching](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)
- [SE-0446: Nonescapable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md) — foundation for ~Escapable types; defers closure-parameter lifetime annotations.
- [SE-0447: Span: Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md) — the Span<T> type.
- [SE-0456: Add Span-providing Properties to Standard Library Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0456-stdlib-span-properties.md) — property-based borrowed access pattern.
- [SE-0465: Nonescapable Standard Library Primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md)
- [SE-0474: Yielding Accessors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0474-yielding-accessors.md) — `_read` / `_modify` coroutines.
- [SE-0499: Support for Noncopyable Simple Protocols](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-support-non-copyable-simple-protocols.md)
- [SE-0503: Suppressed Default Conformances on Associated Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md) — **THE proposal that obsoletes the 2026-01-19 doc's structural-constraint claim.**

### Industry implementations

- [SwiftNIO ByteBuffer documentation](https://swiftpackageindex.com/apple/swift-nio/2.80.0/documentation/niocore/bytebuffer) — readerIndex / writerIndex pattern; the institute's `Binary.Cursor` is the same model.
- [Rust `std::io::Cursor`](https://doc.rust-lang.org/std/io/struct.Cursor.html) — single-position cursor wrapping inner storage T.
- [Rust `bytes::Buf` trait](https://docs.rs/bytes/latest/bytes/buf/trait.Buf.html) — read-cursor trait abstraction.
- [Rust `bytes::BufMut` trait](https://docs.rs/bytes/latest/bytes/buf/trait.BufMut.html) — write-cursor trait abstraction.
- [Point-Free swift-parsing repository](https://github.com/pointfreeco/swift-parsing) — Parser combinator library; Parser protocol generic over Input.

### Academic literature

- Wadler, P. (1990). "Linear types can change the world!" In *Programming Concepts and Methods*.
- Hutton, G. & Meijer, E. (1998). "Monadic Parsing in Haskell." *Journal of Functional Programming*.
- Swierstra, S.D. & Duponcheel, L. (1996). "Deterministic, error-correcting combinator parsers." In *Advanced Functional Programming*.
- [Tofte, M. & Talpin, J.-P. (1997). "Region-Based Memory Management." *Information and Computation* 132, 109–176](http://ropas.snu.ac.kr/lib/dock/ToTa1997.pdf).
- Pierce, B.C., ed. (2005). *Advanced Topics in Types and Programming Languages*. MIT Press.
- Grossman, D., Morrisett, G., et al. (2002). "Cyclone: A safe dialect of C." *USENIX Annual Technical Conference*.
- [Bernardy, J.-P., Boespflug, M., Newton, R.R., Peyton Jones, S., Spiwack, A. (2018). "Linear Haskell: practical linearity in a higher-order polymorphic language." POPL 2018](https://dl.acm.org/doi/10.1145/3158093).
- [Kiselyov, O. "Iteratees" — okmij.org](https://okmij.org/ftp/Haskell/Iteratee/).
- Walker, D. (2005). "Substructural Type Systems." In *Advanced Topics in Types and Programming Languages*, ch. 1.

### Haskell streaming libraries

- [Haskell Wiki: Iteratee I/O](https://wiki.haskell.org/Iteratee_I/O)
- [Conduit package documentation](https://hackage.haskell.org/package/conduit)
- [Pipes package documentation](https://hackage.haskell.org/package/pipes)
- [attoparsec incremental Result type](https://hackage.haskell.org/package/attoparsec)

## Provenance

Surfaced as the Tier 3 escalation of `byte-cursor-primitive-unification.md` v1.3.0 (downgraded to IN_PROGRESS, 2026-05-17). Triggered by the per-package prior-art grep that surfaced `Binary.Cursor` and `Lifetime Dependent Borrowed Cursors.md` as load-bearing prior artifacts the v1.3.0 analysis had not engaged. The Tier 3 arc was authored 2026-05-17.

This arc inherits v1.3.0's empirical decomposition probe (Tagged<DomainTag, Ordinal> as already-decomposed substrate; Index<Byte> as Binary's parallel of Text.Position) as **input**, not as a decided answer. The arc settles the question independently with full Tier 3 rigor: SLR per `[RES-023]`, prior art per `[RES-021]`, theoretical grounding per `[RES-022]`, formal semantics per `[RES-024]`, empirical validation per `[RES-025]`.

The single substantive evolution relative to v1.3.0: the Tier 3 analysis surfaced that the 2026-01-19 doc's "structural constraint" claim (~Escapable on protocol associated types being impossible) was correct at the time and is **now obsoleted by SE-0503**. The institute's `Parser.Protocol` is the empirical witness. This finding *strengthens* Shape F's structural justification — the worlds split that motivated the protocol-shape proliferation is no longer required, but the structural cursor *type* clusters remain distinct because their type-system attributes (Escapable vs ~Escapable, Copyable vs ~Copyable, storage genericity) are genuinely different.

The recommendation aligns with the user's stated preference (2026-05-17): cursor-primitives unification where principally correct. The principled answer is World 2 unification with Worlds 1 and 3 staying structurally separate — the Three-Worlds architecture.

## Phase 4 W1 Resolution (2026-05-18, v1.8.0)

The Phase 4 W1 expansion question (`Binary.Cursor<Storage>` +
`Binary.Reader<Storage>` migration to `swift-cursor-primitives`) is settled
2026-05-18 by `cursor-w1-expansion.md` v1.0.0 DECISION — **Option (c)
principled refuse**.

Binary.Cursor + Binary.Reader stay in `swift-binary-primitives`. cursor-primitives
stays at Tier 6-8 with only the borrowed Span-cursor cohort. Phase 4 closes
without source changes.

The 2026-05-17 Principal Authorization committed Shape ι expansion under
the *Three-Worlds* architecture (this doc's v1.0.0-v1.3.0 framing). The
2026-05-18 v1.2.0 IMPLEMENTED single-generic shape (`cursor-shape-a-vs-three-worlds.md`)
replaced that with `Cursor<DomainTag: Ownership.Borrow.\`Protocol\` & ~Copyable>`
— a *borrow-view* contract that does not generalize to owned storage. The
v1.2.0 doc explicitly re-opened the question (*"W1/W3 unification deferred
without commitment"*); the brief `HANDOFF-cursor-phase-4-w1-expansion.md`
enumerated principled-refuse as a valid option. The architectural ground
changed, the prior commitment's scope no longer applies, and the W1 question
warranted fresh DECISION-grade evaluation.

Verdict grounded in seven structural arguments (see `cursor-w1-expansion.md`
v1.0.0 §Phase 2 §Rationale): the v1.2.0 architecture change; W1 has no
cross-domain duplication; the Item 2 / typed-input precedent (W3 placed in
its byte-domain home, not cursor-primitives); `Ownership.Borrow.\`Protocol\``
is the borrow-view contract not the owned-storage contract;
`nested-view-vs-borrowed-naming.md` v1.3.0 Pattern 3 classifies cursors as
stateful traversal (not borrow-projections); Tier 13 elevation is
post-publication-irreversible; `[ARCH-LAYER-006]` domain completeness
determines L1 existence.

The Shape ι "committed expansion" framing in this doc's v1.3.0 §Principal
Authorization is closed under the new architectural ground. Phase 4 W1 is
settled; W3 was settled 2026-05-18 by `typed-input-unification.md` v1.0.0
DECISION (Binary.Bytes.Input → Byte.Input typealias chain, owned-input
identity placed in swift-byte-parser-primitives).

`HANDOFF.md` Wave 1 Item 1's Phase 4 expansion is CLOSED.

## Phase 4 W3 Simplification (2026-05-18, v1.7.0)

HANDOFF.md Wave 1 Item 2 (D5 `Binary.Bytes.Input` vs `Byte.Input` unification) landed 2026-05-18 as `typed-input-unification.md` v1.0.0 DECISION. The Phase 4 follow-on framing in this doc anticipated migrating W3 (`Binary.Bytes.Input`) into `swift-cursor-primitives` as part of full Shape ι centralization; that W3 portion is **dissolved** by the typed-input-unification landing.

The dissolution:

- `Binary.Bytes.Input` is now a typealias chain `Binary.Bytes.Input → Byte.Input → Input_Primitives.Input.Slice<Array<UInt8>.Indexed<UInt8>>`.
- The byte-domain owned-input identity lives in `swift-byte-parser-primitives` (canonical home per [API-NAME-001b]).
- The underlying `Input.Slice<...>` substrate lives in `swift-input-primitives`.
- Neither package is `swift-cursor-primitives`. Migrating Binary.Bytes.Input to cursor-primitives is no longer a meaningful Phase 4 action — the W3 identity already lives in its principled home (byte-parser-primitives) and the substrate lives in its principled home (input-primitives).

**Phase 4 reduces to W1 only**: `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` in `swift-binary-primitives` are the remaining owned-storage cursor types that could plausibly relocate to a centralized cursor-primitives home under Shape ι. The W3 portion of the Phase 4 brief is removed from scope. Phase 4 dispatch authorship MAY proceed on W1 with BENCH-011 evidence in hand; W3 is closed.

The successor `cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED shape (single-generic `Cursor<DomainTag: Ownership.Borrow.\`Protocol\` & ~Copyable>`) is unaffected — that doc addresses the borrowed Span-cursor layer (W2), which has no overlap with this W3 dissolution. The two arcs are orthogonal and now both individually settled.

## Changelog

- **v1.8.0** (2026-05-18): Status remains SUPERSEDED — adds §"Phase 4 W1 Resolution" recording that the Phase 4 W1 expansion question is settled by `cursor-w1-expansion.md` v1.0.0 DECISION via Option (c) principled-refuse. `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` stay in `swift-binary-primitives`; cursor-primitives stays at Tier 6-8 with only the borrowed Span-cursor cohort. The Shape ι "committed expansion" framing in v1.3.0 §Principal Authorization is closed under the v1.2.0 single-generic architecture's changed ground (Ownership.Borrow.\`Protocol\` is the borrow-view contract, not the owned-storage contract). W3 was settled 2026-05-18 by `typed-input-unification.md` v1.0.0; W1 is now settled. HANDOFF.md Wave 1 Item 1's Phase 4 expansion is CLOSED. No change to the Three-Worlds analytical content, the SE-0503 finding, the SLR / prior art / theoretical grounding sections, or the v1.5.0/v1.6.0 successor pointers — the supersession verdict is unchanged.
- **v1.7.0** (2026-05-18): Status remains SUPERSEDED — adds §"Phase 4 W3 Simplification" recording that HANDOFF.md Wave 1 Item 2 landed as `typed-input-unification.md` v1.0.0 DECISION (`Binary.Bytes.Input = Byte.Input` typealias chain). The Phase 4 W3 centralization to `swift-cursor-primitives` contemplated in v1.3.0/v1.4.0's Implementation Gating is dissolved — `Binary.Bytes.Input`'s identity now lives in `swift-byte-parser-primitives` (the canonical byte-domain owned-input home) and the substrate lives in `swift-input-primitives`. Phase 4 dispatch reduces to W1 only. No change to the Three-Worlds analytical content, the SE-0503 finding, the SLR / prior art / theoretical grounding sections, or the v1.5.0/v1.6.0 successor pointers — the supersession verdict is unchanged.
- **v1.6.0** (2026-05-18): Status remains SUPERSEDED — single-generic refinement of the successor `cursor-shape-a-vs-three-worlds.md` (v1.1.0 DECISION → v1.2.0 IMPLEMENTED) lands. Cursor's shape further collapses from two-generic `Cursor<Storage, PositionTag>` (v1.5.0 supersession framing) to single-generic `Cursor<DomainTag: Ownership.Borrow.`Protocol` & ~Copyable>` — storage is now derived as `DomainTag.Borrowed` via the protocol's associated type rather than a separate generic parameter. Call sites collapse `Cursor<Byte.Borrowed, Byte>(span)` → `Cursor<Byte>(span)` and `Cursor<Byte.Borrowed, Text>(...)` → `Cursor<Text>(...)`. Added `Text: Ownership.Borrow.`Protocol`` conformance with `Borrowed = Byte.Borrowed` (principled domain-identity — text storage IS bytes). Implementation: swift-text-primitives 190fb64, swift-cursor-primitives b4dc49e, swift-binary-parser-primitives a6fbf075, swift-lexer-primitives 511d06e. BENCH-011 replay GREEN at parity across all four probes (ratios 0.998–0.999); ecosystem build gate clean across 8 packages (~990 tests pass). The SUPERSEDED banner is updated to point at the v1.2.0 successor and document both refinements 1 (two-generic) and 2 (single-generic) within the 2026-05-18 same-day landing. No change to the doc's analytical content; the supersession verdict is unchanged. W1/W3 (owned-storage Worlds) remain explicitly deferred — the single-generic protocol bound forecloses "one cursor type for all three Worlds" option A; Phase 4 dispatch decides between a sibling owned-cursor type and a more general protocol bound.
- **v1.5.0** (2026-05-18): SUPERSEDED by `cursor-shape-a-vs-three-worlds.md` v1.1.0 DECISION. Three-Worlds architecture replaced by Shape A — a single generic `Cursor<Storage, PositionTag>` type whose Copyable/Escapable attributes inherit from Storage via Tagged-style conditional conformance. The v1.4.0 doc's Shape A rejection reasoning ("Swift offers no way to make Escapable conditional on a generic parameter") is empirically refuted; the actual narrower Swift constraint (no Mode-discriminator conditional conformance) doesn't block Shape A because Storage-as-borrow-carrier — using the institute's existing `Ownership.Borrow.\`Protocol\`` framework (`ownership-borrow-protocol-unification.md` v1.0.0) and a new `Byte.Borrowed` Case B conformer in swift-byte-primitives — sidesteps the discriminator entirely. The Three-Worlds inventory + SLR + theoretical grounding sections survive as historical analysis input; the architectural verdict is superseded. Implementation arc landed 2026-05-18: Byte.Borrowed in `swift-byte-primitives` (commit `c0e50aa` + public-span amend `9e0bd46`), `swift-cursor-primitives` reshape (commit `64717b2`), `swift-binary-parser-primitives` retarget (commit `65bcdfd0`), `swift-lexer-primitives` retarget (commit `25dddd1`). BENCH-011 replay GREEN — all four probes at parity (ratios 0.95-1.00); 216 swift-json tests pass, 6 swift-lexer tests pass, 69 binary-parser tests pass, 48 lexer tests pass. Phase 4 Shape ι expansion under the new shape collapses to typealiases + conditional extensions on the unified Cursor; reframed as future-work follow-on. The successor doc `cursor-shape-a-vs-three-worlds.md` is the canonical reference; this v1.4.0 → v1.5.0 transition is a status update preserving the analytical content of the earlier arc.
- **v1.4.0** (2026-05-17): **IMPLEMENTED (Shape γ)** — Phases 0-3 of Shape γ landed under principal supervision across `swift-primitives/swift-cursor-primitives` (new repo, commits `0f57273` + `2bd7800`), `swift-primitives/swift-binary-parser-primitives` (commit `13e4dbf2`), `swift-primitives/swift-lexer-primitives` (commit `575e4cb`), and `swift-institute/Experiments` (BENCH-011 probe at `cursor-span-bench-011`, commit `3180870`). Phase 4 Shape ι expansion remains pending per the original authorization — gated on HANDOFF.md Wave 1 Item 2 settling. Adds §Implementation Outcomes (Phase 0 BENCH-011 GREEN results table + Phases 1/2a/2b/3 commit SHAs and build-gate evidence across 7 packages including swift-json's 216 tests). Adds §Implementation Notes (count retrofit Int → Tagged<Byte, Cardinal> was not in the original brief, source-transparency verified by build + grep; Binary 20-100× speedup root cause attributed to legacy `public var position: Int` storage preventing `@inlinable` method optimization — the cursor's `@usableFromInline internal var _position` pattern accidentally fixed a real perf defect, not benchmark anomaly or compiler magic). Updates §Implementation Gating Phase 1 API surface to include `seek(to:)` (added during Phase 1 for parser-machine backtracking — `Binary.Bytes.withBorrowed`'s alternative-frame branches restore the cursor to a previously-captured position when a branch fails; the legacy `public var position: Int` settable allowed this directly, the cursor analog is `seek(to:)`; class-(c) judgment within the spec's signature-latitude). No change to the Three-Worlds type structure verdict, the SE-0503 finding, the obsolescence of Lifetime Dependent Borrowed Cursors.md's structural-constraint claim, the inventory of six L1 cursor primitives, or the §Principal Authorization. Phase 4 dispatch opens as a separate follow-on.
- **v1.3.0** (2026-05-17): **DECISION** — Principal authorized choice C on 2026-05-17: Shape γ as the immediate move (Phases 0-3) **with Shape ι expansion explicitly scheduled as a committed Phase 4 follow-on arc**. Adds §Principal Authorization section recording the authorization, binding decisions, sole technical fallback (BENCH-011 unmitigable specialization regression voids ι expansion via Shape ε fallback on W2), and what the authorization does/does-not do. Updates §Implementation Gating: Phase 4 reframed from "evaluate Shape ι expansion" (v1.2.0) to "execute Shape ι expansion" (v1.3.0). Technical gates (BENCH-011 evidence; Item 2's settled outcome) reframed as inputs to Phase 4's *shape* (single-package vs split-package; W3's consolidated typed-input cursor identity) rather than gates on its *commitment*. Decision Matrix updated to mark Shape γ as authorized for Phases 0-3 and Shape ι as authorized as committed Phase 4 follow-on. Package naming `swift-cursor-primitives` is principal-authorized (the package is the eventual end-state home; no `swift-cursor-span-primitives` artificial restriction). No change to the Three-Worlds type structure verdict, the SE-0503 finding, the obsolescence of Lifetime Dependent Borrowed Cursors.md's structural-constraint claim, the inventory of six L1 cursor primitives, the SLR / prior art / theoretical grounding / formal semantics / empirical validation sections, or the Open Questions on detailed cursor-type naming. This Tier 3 arc closes as DECISION; the implementation arc opens as a separate dispatch.
- **v1.2.0** (2026-05-17): RECOMMENDATION (superseded by v1.3.0 DECISION) — Three-Worlds type structure unchanged; **placement recommendation inverted**: Shape γ (W2 unification only) becomes the principled-first immediate move; Shape ι (full centralization of W1+W3 to cursor-primitives) becomes a deferred follow-on arc gated on HANDOFF.md Item 2 settling + BENCH-011 evidence. Inversion responds to reviewer feedback identifying three structural defects in v1.1.0's "Shape ι preferred" framing: (a) the duplication-elimination argument is W2-specific — W1 has intentional rw/ro structural specialization (not the kind centralization eliminates), W3 stands alone with no duplication; (b) Tier 13 elevation is post-publication irreversible and Shape γ avoids it entirely (W2-only sits at Tier 6-8 without Memory.Contiguous.Protocol dep); (c) W3 placement is premature because Item 2 (Binary.Bytes.Input vs Byte.Input) is in flight within W3. Reversibility heuristic load-bearing: γ → ι is a small follow-on; ι → γ is a costly back-out. No change to the Three-Worlds type structure verdict, the SE-0503 finding, the obsolescence of Lifetime Dependent Borrowed Cursors.md's structural-constraint claim, or the inventory of six L1 cursor primitives.
- **v1.1.0** (2026-05-17): RECOMMENDATION (SUPERSEDED by v1.2.0) — Shape ι preferred / Shape γ fallback framing. Added Shape ι to the Decision Space Enumeration. Reviewer feedback identified three structural defects (see v1.2.0 changelog).
- **v1.0.0** (2026-05-17): RECOMMENDATION — Three-Worlds Architecture (Shape γ). Refines `byte-cursor-primitive-unification.md` v1.3.0's Shape F to the full L1 inventory: World 1 (Binary.Cursor + Binary.Reader status quo), World 2 (unified borrowed-Span cursor with Tagged<DomainTag, Ordinal> position), World 3 (Binary.Bytes.Input status quo, subject to separate Item 2 arc). The 2026-01-19 doc's "structural constraint" claim is identified as obsoleted by SE-0503. Wave 1 Items 2, 3, 4, 5 of HANDOFF.md may resume.
