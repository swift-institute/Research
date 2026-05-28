# Memory.Contiguous Iteration Bridge

<!--
---
version: 1.1.5
last_updated: 2026-05-27
status: RECOMMENDATION
tier: 2
scope: cross-package
changelog:
  - "1.1.5 (2026-05-27): Buffer-ring piecewise template VERIFIED + corrected (commit 58161ac, orchestrator-verified — clean build + 129 tests green). The first ring migration (13c504b) force-fit a UNIFORM bespoke @unsafe raw-pointer Chunk across all 4 variants — including degenerate ≤1-element 'fake-bulk' Chunks on the inline variants. Principal caught two defects: (axis 1) fake-bulk = scalar iteration dressed as Iterator.Chunk.Protocol, violating the storage-shape split (real-bulk→Chunk, fake-bulk→scalar); (axis 2) the heap Chunk re-rolled raw-pointer span extraction, reinventing the canonical Iterator.Chunk<Element>. Corrected via a SPAN-ABILITY split: heap base Buffer.Ring REUSES Iterator.Chunk (composed ≤2 in a thin Buffer.Ring.Segments concatenator; @unsafe surface = segment-span construction only) for Iterable bulk + hand-written scalar for Sequenceable (@_implements split); inline variants (.Inline/.Bounded/.Small, @_rawLayout) go SCALAR-only (borrow-scalar Walk for Iterable + owning Scalar for Sequenceable, @_implements split — a single shared iterator is not expressible since Iterable.makeIterator is borrowing and Sequenceable's is consuming). Rationale: a wrapped ring over inline @_rawLayout would require a 2-segment span concat over self-lifetime-bound inline spans — the same demangle-fragile generic-witness-over-@_rawLayout path (cf. 1.1.2/1.1.4); scalar sidesteps it. Surfaced, not built: a reusable 'concatenate N Iterator.Chunk' primitive (rope / scatter-gather IO / multi-arena) — class-(c) backlog. Corrects §3/§4's earlier 'uniform bespoke 2-segment iterator' framing for the ring family."
  - "1.1.4 (2026-05-27): Demangle /issue-investigation verdict — NOT synthetically reproducible (Experiments/memory-cursor-generic-witness-demangle, 7 targets, 6.3.2 + 6.4-dev, clean builds). Neither a general compiler bug (hand-rolled bare-generic witness doesn't crash) nor Memory.Cursor's shape alone (single/dual/@_implements/value-generic/@_rawLayout/cross-module reconstructions all pass) — it needs the literal Buffer.Linear.Inline 3-module @_rawLayout topology. No standalone reproducer → no [ISSUE-*]. So there may be no clean 'demangle fix' to wait on; the Memory.Cursor bridge stays dormant indefinitely unless the buffer-linear-Inline-specific cause is pinned via a principal-coordinated transient-restore (LOW priority — the hand-written scalar path is the production shape and works). Strengthens the hand-written-scalar decision: the defect is context-specific, not a fundamental Sequenceable/Memory.Cursor problem."
  - "1.1.3 (2026-05-27): Contiguous template FINALIZED (principal decision) — the brief 'Iterable-only' interim is REJECTED. Sequence.Clearable: Sequenceable & ~Copyable (removeAll(), consuming-drain) is conformed by 35 files/13 packages, so dropping : Sequenceable is not free; Clearable STAYS on Sequenceable (re-basing onto Iterable would regress ~Copyable draining). The crash is the Memory.Cursor GENERIC witness specifically, not Sequenceable — buffer-slab d6fcf5b proves a hand-written scalar Sequenceable iterator runs green for a generic conformer. Contiguous reference template = : Memory.Contiguous + : Iterable (memory→Iterable bridge Chunk, kept) + : Sequenceable (HAND-WRITTEN scalar iterator, buffer-slab pattern, NOT Memory.Cursor) + : Sequence.Clearable (intact); @_implements split binds the two Iterators. The memory→Sequenceable Memory.Cursor bridge is DORMANT (no live consumer; swift-memory-sequence-primitives retained); contiguous Sequenceable iterators swap to it once the demangle /issue-investigation resolves — tracked follow-up, not a blocker. No conformer uses Memory.Cursor for Sequenceable until the fix."
  - "1.1.2 (2026-05-27): OQ-2 SPLIT VERDICT — the concrete→generic residual FIRED. Stage A's first generic conformer (Buffer.Linear.Inline<capacity>) crashes at runtime through the Sequenceable bridge (swift_getAssociatedTypeWitness demangle failure, Signal 6, collect()), clean-build-confirmed (stale-resolution/stale-cache confound ruled out: bridge HEADs clean/path-form, Package.resolved up-to-date, .build verified-gone). Decisive control isolates it to the Memory.Cursor/Sequenceable GENERIC witness (not the @_implements dual-split). Direction (principal): contiguous conformers go Iterable-ONLY arc-wide (proven Iterator.Chunk path) until the demangle is fixed — NO contiguous conformer declares : Sequenceable; the fan-out (array + all Memory.Contiguous adopters) follows the Iterable-only template. swift-memory-sequence-primitives RETAINED but DORMANT/GATED (builds on concrete base; no viable generic consumer yet; not deleted). Sequenceable-on-contiguous = tracked deferred OQ behind a /issue-investigation of the demangle (codegen bug vs Memory.Cursor reshape); re-add once resolved."
  - "1.1.1 (2026-05-27): Wave 1 (cascade-independent machinery) LANDED + orchestrator-verified. swift-memory-cursor-primitives f71c9b8 (owned Memory.Cursor + Iterator Protocol dep; 16 tests), swift-memory-sequence-primitives d5c00b3 (NEW local pkg, witness; 2 tests, no remote), swift-memory-iterator-primitives 6c5f013 (Iterable floor BitwiseCopyable->Copyable; 2 tests). OQ-2 in-context PASS (generic Memory.Cursor typechecks + runs against real Memory.Contiguous<Int>); OQ-1 relax landed; no cycle; no dangerous warnings. Doc fix: §1 SHAPE import corrected Iterator_Primitive -> Iterator_Protocol (the product that declares Iterator.`Protocol`). Wave 2 (conformer migration) remains GATED behind HANDOFF-sequence-iterable-rename-cascade.md."
  - "1.1.0 (2026-05-27): Principal adjudication (ratify TWO packages; accept the deletion-gating and Sequence.Span-consumer corrections; flag the corpus error). §1 REVISED — the bridge's owning iterator is the deferred W1 owned-Cursor *sibling* homed in the EXISTING swift-memory-cursor-primitives (working name Memory.Cursor), NOT a new Iterator.Walk; design-fork resolved to a sibling owned type. Spike landed (swift-institute/Experiments/memory-contiguous-sequenceable-bridge-shape): OQ-1 CONFIRMED (Iterator.Chunk's BitwiseCopyable floor is relaxable to Copyable); OQ-2 CONFIRMED (Escapable owned cursor typechecks with @_lifetime omitted). Rebased off the Three-Worlds framing onto the shipping single-generic Cursor; marked cursor-abstractions-l1-ecosystem.md SUPERSEDED; flagged sequencer-...-refactor.md:290 'only real conformer is Sequence.Span' as a factual error."
  - "1.0.0 (2026-05-27): Initial RECOMMENDATION."
---
-->

> **Status**: RECOMMENDATION (decision-pending on OQ-3/OQ-4). Planning + an authorized spike;
> no live-package source edited, no bridge built, no target deleted. Operationalizes the **D-2
> RETIRE** decision (`sequencer-primitives-reconciliation-refactor.md` §4b) and **Step-C**
> (`collection-sequence-protocol-detachment.md`) with the one piece neither worked out: the
> concrete `Memory.Contiguous → Sequenceable` pipeline bridge. v1.1.0 incorporates the principal's
> adjudication and the spike at
> `swift-institute/Experiments/memory-contiguous-sequenceable-bridge-shape` (OQ-1 + OQ-2 both
> CONFIRMED, debug+release).

## Context

`Sequence.Borrowing.Protocol` (swift-sequence-primitives, `Sequence Borrowing Primitives`
target, `Sequence.Borrowing.Protocol.swift:43`) is the **vestigial bulk-span borrowing
tier** — "a container that produces span chunks." It is design-superseded: the institute
has already decided (D-2, `sequencer-primitives-reconciliation-refactor.md` §4b v0.5.0)
to **RETIRE** it, on the principle that *"producing span chunks is a property of
contiguous storage, not a kind of sequence"* (`bulk-span-iteration-fold-vs-separate.md`
§6). It cannot be deleted yet — it has live conformers.

The retirement is a **first-principles decomposition**, optimizing for
decomposition/composition and **semantics, not current consumers**:

> `Sequence.Borrowing.Protocol` ≡ `Memory.Contiguous.Protocol` (the span substrate)
> + two `where Self: <attachable>` bridges that derive iteration and the lazy pipeline
> "for free."

Five prior docs converge on this thesis but **none works out the
`Memory.Contiguous → Sequenceable` bridge** — that is this note's new contribution.

## Question

How is `Sequence.Borrowing.Protocol` concretely retired? Specifically:

1. What is the `Memory.Contiguous → Sequenceable` bridge — its iterator shape, ownership,
   lifetime, and constraints?
2. Does the new bridge live in **one** package or **two** (`memory-iterator` exists; does
   `memory-sequence` join it, or do both bridges co-locate)?
3. How does each live conformer migrate?
4. What does **not** use the bridge (the boundary table)?
5. When and how are the `Sequence Borrowing` + `Sequence Span` targets deleted?
6. How is the stale `Sequenceable.swift` two-tier doc fixed?

## Prior Art — Reconciliation, Not Duplication

Per [HANDOFF-013] / [RES-019], the internal corpus was grepped first. The decomposition
is **already decided**; this note supplies the missing mechanism and extends — it does not
re-litigate.

| Doc | Status | What it established | This note's relationship |
|-----|--------|---------------------|--------------------------|
| `collection-sequence-protocol-detachment.md` | DECISION | **Step-C**: "No new protocols needed. `Memory.Contiguous.Protocol` already provides span access; `Sequence.Borrowing.Protocol` is reframed as a chunked-span optimization, not a borrowing-iteration mechanism." C1/C2 = the doc-fix tasks. | **Extends**: from *reframe-as-optimization* → *full retirement via Memory.Contiguous + two bridges*. C1/C2 become deliverable #6. |
| `sequencer-primitives-reconciliation-refactor.md` | DRAFT (§4b **D-2 RESOLVED — RETIRE**, v0.5.0) | Retire the bulk-span borrowing protocol; **bulk-span = contiguous-memory property → `Memory.Contiguous.Protocol`**; scalar borrowing-iteration → `Iterable`. | **Operationalizes** D-2: supplies the concrete bridges, migration table, deletion gating. |
| `bulk-span-iteration-fold-vs-separate.md` | RECOMMENDATION | The thesis anchor — the institute moved the bulk/contiguous capability *out of the iteration hierarchy entirely* onto a *memory* abstraction. | **Cites** as the semantic justification for routing the substrate to `Memory.Contiguous`. |
| `two-world-traversal-decomposition.md` | RECOMMENDATION | The two-world model: **multipass (World B) → the existing `Iterable`**; single-pass → `Sequenceable`. Validated end-to-end against the real `Iterator.\`Protocol\`` / `Iterable`. | **Inherits** the two-world classification; the bridges are its memory-substrate realization. |
| `world-b-span-decomposition.md` | RECOMMENDATION | The **parent cascade's** research home (`HANDOFF-sequence-iterable-rename-cascade.md`): `Sequence.\`Protocol\`` → `Iterable`/`Sequenceable`, per-conformer classification + dependency-ordered wave plan. | **Sequences around** it — the cascade lands first; the `Sequence.Borrowing` drop folds into the same conformance lines. |
| `cursor-shape-a-vs-three-worlds.md` | IMPLEMENTED | The shipping cursor architecture: a **single-generic** `Cursor<DomainTag: Ownership.Borrow.\`Protocol\`>` **borrowed-view** cursor (storage is `DomainTag.Borrowed`, unconditionally `~Copyable & ~Escapable`). Its **Phase-4 scope note explicitly defers owned `Memory.Contiguous.Protocol` storage (W1)** to "a sibling owned-cursor type or a more general protocol bound." | **Realizes the deferral**: the Sequenceable bridge's owning iterator IS the deferred **W1 owned-Cursor sibling** — homed in the existing `swift-memory-cursor-primitives`, conforming `Iterator.\`Protocol\``. See §1. (Note: I rebase on this *shipping single-generic* `Cursor` + the deferred sibling — **not** on the W1/W2/W3 "Three-Worlds" framing, which is descriptive history.) |
| `cursor-abstractions-l1-ecosystem.md` | **SUPERSEDED** (2026-05-18, by `cursor-shape-a-vs-three-worlds.md` v1.2.0) | The predecessor that originated the Three-Worlds framing. | **Cited only to mark superseded** — its Three-Worlds verdict is not the architecture; the §1 revision is grounded in the shipping single-generic `Cursor`. |

Adjacent (cited, not load-bearing): `iterator-span-buffer-elimination.md` (DECISION — Optional-inline iterator storage supersedes heap buffer; relevant to the owned cursor's storage discipline), `sequence-operator-unification.md` (RECOMMENDATION — the lazy-pipeline operators anchored on `Sequenceable`).

**Corpus corrections this note records** ([RES-013a] / [META-003] — contradicting prior research must be cited, not silently diverged from):

1. `sequencer-primitives-reconciliation-refactor.md:290` (DRAFT v0.10.x) asserts *"The only real conformer to today's `Sequence.Borrowing.Protocol` is `Sequence.Span`."* This is a **factual error** `[Verified: 2026-05-27]`: `Sequence.Span` is a *consumer* (a `Property.Inout` `Base` constraint), not a conformer; the actual conformers are the **six buffer variants** (buffer-linear ×3 + buffer-ring ×3) enumerated below. The *adjacent* claim on the same line — *"every call site passes `Cardinal(UInt.max)`; nobody chunks"* — is corroborated and supports the retirement (the bulk-span chunk surface is functionally unused). The :290 conformer clause should be corrected when that DRAFT next advances.
2. `cursor-abstractions-l1-ecosystem.md` is SUPERSEDED (above); any reference to its Three-Worlds verdict as current architecture is stale.

## Verified Ground Truth

All claims `[Verified: 2026-05-27]` against live source ([RES-023] / [RES-020]).

**The substrate** — `Memory.ContiguousProtocol` (`Memory Contiguous Primitives`,
`Memory.ContiguousProtocol.swift:90`): `associatedtype Element: ~Copyable`,
`var span: Span<Element> { get }`, `withUnsafeBufferPointer`. `Span<Element>` forces
`Element: Escapable` (Swift 6.3.1; per `Sequence.Borrowing.Protocol.swift:48-49` and
`Sequenceable.swift:103`).

**The protocol to retire** — `Sequence.Borrowing.\`Protocol\`<Element>: ~Copyable, ~Escapable`
(`Sequence.Borrowing.Protocol.swift:43`): `associatedtype Element: ~Copyable`;
`associatedtype Iterator: Sequence.Iterator.\`Protocol\` & ~Copyable & ~Escapable`;
`@_lifetime(borrow self) borrowing func makeIterator() -> Iterator`. It is the
**borrowing / multipass** tier — structurally the same role as `Iterable`.

**The existing memory→Iterable bridge** (the model) —
`swift-memory-iterator-primitives`, single target `Memory Iterator Primitives`, single
source `Memory.Contiguous+Iterable.swift`. It is **witness-only**: a constrained
extension supplying `borrowing func makeIterator() -> Iterator.Chunk<Element>`, reusing
the canonical bulk iterator (defines no iterator of its own). Two constraints worth
noting:
- `extension Memory.ContiguousProtocol where Self: Iterable, Self: ~Copyable, Element: BitwiseCopyable`
  (`Memory.Contiguous+Iterable.swift:28`). The element floor is **`BitwiseCopyable`**, not
  merely `Escapable`.
- A second witness on `__Memory_Contiguous_Borrowed_Protocol` (the `~Escapable` borrowed
  views) covers `Memory.Contiguous.Borrowed` / `Byte.Borrowed` / `Binary.Borrowed`.
- Package deps: `Memory Contiguous Primitives` + `Iterator Primitive` + `Iterable` +
  `Iterator Chunk Primitives`. **No Test Support target.**

**The pipeline anchor** — `Sequenceable<Element>: ~Copyable, ~Escapable`
(`Sequenceable.swift:90`): `associatedtype Element: ~Copyable & ~Escapable`;
`@_lifetime(copy self) consuming func makeIterator() -> Iterator`. `Sequence.Map<Base: Sequenceable & ~Copyable & ~Escapable>`
(`Sequence.Map.swift:42`) confirms the lazy pipeline is anchored on `Sequenceable`. The
doc's own extraction-vs-borrow split (`Sequenceable.swift:98-103`): in-loop borrowing
terminals (`forEach(borrowing:)`) admit `~Escapable`; **extraction terminals (`collect`,
`first`) constrain `Element: Escapable`**; the bulk path stays `Escapable`-narrowed.

**`Cursor<DomainTag>`** (`swift-cursor-primitives`, `Cursor.swift:72`): generic over
`DomainTag: Ownership.Borrow.\`Protocol\``, stores `storage: DomainTag.Borrowed` (a
`~Copyable, ~Escapable` **borrowed view**) + `_position`; a parser-style
peek/advance/consume cursor that **does not conform `Iterator.\`Protocol\`** and **does
not own its source**. Its Phase-4 note (`Cursor.swift:53-59`) defers owned-
`Memory.Contiguous` storage. (`swift-byte-cursor-primitives` is the byte specialization;
`swift-memory-cursor-primitives` is the byte-cursor↔memory bridge — neither is a
Sequenceable bridge.)

**Live conformers of `Sequence.Borrowing.\`Protocol\`** (workspace-wide grep across
swift-primitives + swift-standards + swift-foundations; zero outside primitives):

| Conformer | Contiguous? | Conforms `Memory.Contiguous.Protocol`? | Conformance file |
|-----------|-------------|----------------------------------------|------------------|
| `Buffer.Linear` | yes | yes (`Element: Copyable`) | `Buffer.Linear+Sequence.Protocol.swift:56` |
| `Buffer.Linear.Bounded` | yes | yes | `Buffer.Linear.Bounded+Sequence.Protocol.swift:52` |
| `Buffer.Linear.Small` | yes | yes | `Buffer.Linear.Small+Sequence.Protocol.swift:59` |
| `Buffer.Ring` | **no** (2-segment) | **no** | `Buffer.Ring+Span.swift:124` |
| `Buffer.Ring.Bounded` | **no** | **no** | `Buffer.Ring.Bounded+Span.swift:116` |
| `Buffer.Ring.Small` | **no** | **no** | `Buffer.Ring.Small+Span.swift:120` |

Plus one in-package **consumer** (not a conformer): `Sequence.Span+Property.Inout.swift:10-13`
— `extension Property.Inout where Base: Sequence.Borrowing.\`Protocol\` & ~Copyable, Tag == Sequence.Span`
(the `.span.forEach` / `.elements` / `.reduce` machinery in `Sequence Span Primitives`).

> **Two corrections to the brief** ([RES-023]). (a) The brief's *"Sequence.Span is its
> only real conformer"* is imprecise on two counts: `Sequence.Span` is a **consumer**
> (Property.Inout `Base` constraint), not a conformer; and the real conformers are the
> **six buffer variants** above. (b) All three buffer-linear conformers conform
> `Memory.Contiguous.Protocol` at **`Element: Copyable`** — and `Buffer.Linear.Inline`
> conforms `Memory.Contiguous.Protocol` but **not** `Sequence.Borrowing` (so its migration
> is purely additive). The "buffer-linear ×3 already conforms Memory.Contiguous" claim is
> right for the *Sequence.Borrowing* conformers; the full Memory.Contiguous set is ×4.

## Analysis

### §1 — The `Memory.Contiguous → Sequenceable` bridge (REVISED v1.1.0)

`Sequenceable.makeIterator()` is **consuming** — the iterator must **own** the consumed
sequence (the lazy pipeline stores each consumed stage inside its wrapper). The substrate
gives only a *borrowed* `var span` (`~Escapable`), which cannot be stored across `next()`
calls. The bridge's iterator therefore **owns the consumed contiguous base and re-derives the
span inside each `next()`**.

**This owning iterator is the deferred W1 owned-Cursor sibling, not a new `Iterator.Walk`.**
`cursor-shape-a-vs-three-worlds.md` (IMPLEMENTED) deferred owned-`Memory.Contiguous` storage
to *"a sibling owned-cursor type."* That deferred sibling **is** the bridge's owning iterator.
Per principal direction (2026-05-27): home it in the **existing
`swift-memory-cursor-primitives`** (subject-homed, working name **`Memory.Cursor`**), reusing
the cursor ecosystem's conventions (`Tagged` position, `@frozen`), and conform it to the
foundation `Iterator.\`Protocol\`` so the pipeline witnesses through it. The earlier v1.0.0
`Iterator.Walk` (a new manner-named type in the iterator family) is **withdrawn**: it
reinvented what the cursor ecosystem already homes, and the owning cursor is a *cursor* (it
holds a position over storage), subject-homed under `Memory`, with `Iterator.\`Protocol\`` as a
*secondary* conformance.

```swift
// swift-memory-cursor-primitives / Memory Cursor Primitives / Memory.Cursor.swift  (SHAPE)
//   The deferred W1 owned-Cursor sibling — owned (vs the borrowed Cursor<DomainTag>).
public import Memory_Contiguous_Primitives
public import Iterator_Protocol             // Iterator.`Protocol` — product "Iterator Protocol" (NEW dep for memory-cursor; Wave-1-verified)
public import Tagged_Primitives
public import Ordinal_Primitives            // Tagged<Base, Ordinal> position (ecosystem convention)

extension Memory {
    @frozen
    public struct Cursor<Base: Memory.ContiguousProtocol & ~Copyable>
    where Base.Element: Copyable & Escapable {           // Escapable iff Base is Escapable
        public var base: Base                            // OWNS the consumed contiguous Self
        public var position: Tagged<Base, Ordinal>       // Tagged position — mirrors Cursor<DomainTag>
        @inlinable public init(_ base: consuming Base) { … }
    }
}

extension Memory.Cursor: Iterator.`Protocol` {
    public typealias Element = Base.Element
    public typealias Failure = Never
    // NO @_lifetime: an Escapable result REJECTS @_lifetime (spike OQ-2 V1). The Escapable
    // witness satisfies Iterator.`Protocol`'s @_lifetime(&self) next() requirement anyway
    // (spike OQ-2 V2a — CONFIRMED debug+release).
    @inlinable public mutating func next() -> Base.Element? {
        let span = base.span                  // re-derive INSIDE next(); never store the ~Escapable span
        guard position < span.count else { return nil }
        defer { position = position.successor.saturating() }
        return span[position]                 // copy-out (Element: Copyable & Escapable)
    }
}
```

```swift
// swift-memory-sequence-primitives / Memory Sequence Primitives /
//   Memory.Contiguous+Sequenceable.swift  (SHAPE) — the thin witness only; the type lives above.
public import Memory_Contiguous_Primitives
public import Memory_Cursor_Primitives      // Memory.Cursor
public import Sequence_Protocol_Primitives  // Sequenceable

extension Memory.ContiguousProtocol
where Self: Sequenceable, Self: ~Copyable, Element: Copyable & Escapable {
    // No @_lifetime (Escapable result; see above). Conformer writes the one-line `: Sequenceable`.
    public consuming func makeIterator() -> Memory.Cursor<Self> { Memory.Cursor(self) }
}
```

| Property | Decision | Rationale / evidence |
|----------|----------|----------------------|
| **Type + home** | `Memory.Cursor` (owned), in `swift-memory-cursor-primitives`, sibling to the borrowed `Cursor<DomainTag>` | Principal direction; realizes the `cursor-shape-a` W1 deferral; reuses cursor-ecosystem conventions (`Tagged` position, `@frozen`). |
| **Ownership** | stores `base: Base` by value (consumed) | `consuming makeIterator` requires the iterator to outlive `self`; owning the base keeps memory alive for the lazy chain. |
| **Span lifetime** | `base.span` re-derived inside every `next()`, never stored | `span` is `~Escapable`; re-deriving borrows the owned `base` per call — O(1). |
| **Escapability** | **Escapable** (tracks `Base`; the bridge's contiguous bases are Escapable owned containers) | Spike OQ-2: an Escapable owned cursor typechecks against `Sequenceable` + `Iterator.\`Protocol\``. **`@_lifetime` is OMITTED** — invalid on an Escapable result (OQ-2 V1 REFUTED), and the Escapable witness satisfies the `@_lifetime`-annotated requirements without it (OQ-2 V2a CONFIRMED). |
| **Element constraint** | `Copyable & Escapable` | `next()` copies the element out of a borrowed span (`Copyable`) and returns it past the iterator (`Escapable`). Matches `Sequenceable`'s extraction-terminal constraint (`Sequenceable.swift:98-103`). |
| **Witness shape** | `where Self: Sequenceable, Self: ~Copyable` | `Self: ~Copyable` suppresses the protocol-extension default `Self: Copyable` ([MEM-COPY-004]); cannot retroactively refine `Memory.Contiguous.Protocol`, so the conformer opts in with `: Sequenceable`. |

**Design fork resolved → (a) sibling owned type** (the Cursor doc named the fork: owned storage
doesn't fit `Ownership.Borrow.\`Protocol\``'s borrowed-view contract — "a sibling owned-cursor
type **or** a more general protocol bound"). **Pick (a).** Argument: the borrowed
`Cursor<DomainTag>` stores `DomainTag.Borrowed`, which `Ownership.Borrow.\`Protocol\`` constrains
to `~Copyable & ~Escapable`, so the borrowed cursor is **unconditionally `~Escapable`**
(`Cursor.swift:37-42`, "inherited unconditionally"). The owned `Memory.Cursor` over an Escapable
contiguous base is **Escapable**. Escapability is fixed at type declaration — one concrete type
cannot be `~Escapable` for borrowed storage *and* Escapable for owned storage. A "more general
protocol bound" (b) would have to make the cursor's Escapable bit conditional on the storage's —
opposite profiles that Swift cannot unify in one type (the same "Escapable can't be made
conditional on a generic" tension `cursor-shape-a` navigated, here with *contradictory* profiles
rather than a uniform one). Hence two cursor types: borrowed `Cursor<DomainTag>` (`~Escapable`,
`swift-cursor-primitives`) and owned `Memory.Cursor` (Escapable, `swift-memory-cursor-primitives`).

**Spike scope + residual — the residual FIRED (v1.1.2 update).** The Wave-1 spike validated OQ-2
only for a **concrete `[Int]`** base (`total = 60`); it did **not** exercise the
*generic-over-`Memory.ContiguousProtocol`* factor. At **Stage A** the first generic conformer
(`Buffer.Linear.Inline<capacity>`) driven through the Sequenceable bridge **crashed at runtime**
on a verified-clean build (confound ruled out: bridge HEADs clean/path-form, `Package.resolved`
up-to-date, `.build` verified-gone): `swift_getAssociatedTypeWitness` **fails to demangle the
`Iterator` associated-type witness** for the generic `Sequenceable` conformance → Signal 6 in
`Sequenceable.collect()`. A decisive control (single `Sequenceable`, no `Iterable`, no
`@_implements`) crashes identically → the defect is the **`Memory.Cursor`/Sequenceable witness for
generic conformers**, not the dual-conformance split. So **OQ-2 is a split verdict: CONFIRMED
(non-generic) / REFUTED (generic)** — see Outcome.

**Consequence — the CONTIGUOUS REFERENCE TEMPLATE (principal decision 2026-05-27, REVISED v1.1.3).**
A brief "Iterable-only" interim was rejected once the blast radius surfaced: **`Sequence.Clearable: Sequenceable & ~Copyable`** (sole req `removeAll()`, refines `Sequenceable` for `~Copyable`
consuming-drain) is conformed by **35 files / 13 packages**, so dropping `: Sequenceable` is NOT
free anywhere a container conforms `Clearable`. `Clearable` **stays on `Sequenceable`** (decided —
re-basing it onto `Iterable` would regress `~Copyable` draining). The crash is the **`Memory.Cursor`
generic witness specifically, not `Sequenceable`** — buffer-slab `d6fcf5b` proves a hand-written
scalar `Sequenceable` iterator runs green for a generic conformer. So the contiguous template is:

| Conformance | Witness |
|-------------|---------|
| `: Memory.Contiguous.\`Protocol\`` | substrate (`var span`) |
| `: Iterable` | the memory→Iterable bridge vends `Iterator.Chunk` (bulk; proven generic-clean — keep) |
| `: Sequenceable` | a **hand-written scalar iterator** (buffer-slab `d6fcf5b` pattern — index + buffer, `consuming`; **NOT `Memory.Cursor`**) |
| `: Sequence.Clearable` + `removeAll()` | rides `Sequenceable`'s consuming drain (intact) |

Iterable.Iterator (`Iterator.Chunk`) ≠ Sequenceable.Iterator (the scalar) → `@_implements` split
(builds green; the earlier dual state proved the split, only the `Memory.Cursor` witness ran-crashed).
**The memory→Sequenceable bridge (`Memory.Cursor`) is DORMANT** — no live consumer; `swift-memory-sequence-primitives` is RETAINED (builds on a concrete base; not deleted). Applies arc-wide: NO
conformer uses `Memory.Cursor` for `Sequenceable` until the cause is pinned.

**Demangle `/issue-investigation` verdict (`Experiments/memory-cursor-generic-witness-demangle`,
7 targets, Swift 6.3.2 + 6.4-dev, clean builds) — NOT SYNTHETICALLY REPRODUCIBLE.** The crash is
**neither a general compiler bug** (a hand-rolled bare-generic associated-type-witness does NOT
crash) **nor `Memory.Cursor`'s shape alone** (every high-fidelity reconstruction passes — single &
dual `@_implements`, value-generic `<let N: Int>`, `@_rawLayout` owning real inline storage,
cross-module bridge-default witness). It needs a factor specific to the literal `Buffer.Linear.Inline`
**3-module `@_rawLayout` topology** (type module / conformances module / cross-package bridge-default
witness) that the flat experiment couldn't replicate. **No standalone reproducer → no `[ISSUE-*]`.**
Consequence: there may be **no clean "demangle fix"** to wait on — the `Memory.Cursor` bridge stays
dormant indefinitely unless the buffer-linear-`Inline`-specific cause is pinned via a principal-coordinated
transient restore of the dual conformance on a throwaway branch (**low priority** — the hand-written
scalar path works and is the production shape). The hand-written-scalar decision is *strengthened*:
the defect is context-specific, not a fundamental `Sequenceable`/`Memory.Cursor` problem.

### §2 — One bridge package or two? → **TWO** (`swift-memory-sequence-primitives`)

The analysis is unambiguous; **ratified by the principal 2026-05-27**. **Recommendation: a new
sibling package `swift-memory-sequence-primitives` (`Memory Sequence Primitives`), deps `Memory
Contiguous Primitives` + `Sequence Protocol Primitives` + `Memory Cursor Primitives`** — joining
the existing `swift-memory-iterator-primitives`, not merging with it. The owned `Memory.Cursor`
type lives in `swift-memory-cursor-primitives` (§1), so the bridge package itself stays
**thin** (the `where Self: Sequenceable` witness only) — which *strengthens* the two-package
answer.

| Driver | Two packages (recommended) | One package (`memory-traversal`) |
|--------|----------------------------|----------------------------------|
| **Precedent** | `swift-memory-iterator-primitives` is already a standalone one-bridge package (deps memory+iterator) `[Verified]`. Symmetry: the sequence bridge is its own package. | Would require **relocating** the existing memory-iterator bridge — churn + breaks an established package for zero gain. |
| **[MOD-006] dep minimization** | A consumer wanting only borrowing iteration pays only iterator-primitives; only the lazy pipeline pays only sequence-primitives. | Forces the **union dep** (iterator + sequence) on every consumer of *either* bridge. |
| **[MOD-029] upstream dep-tree** | Extracting the sequence bridge prunes the iterator consumer's graph and vice versa. The two bridges share **zero code** (borrowing vs consuming `makeIterator`; reuse `Iterator.Chunk` vs vend the owned `Memory.Cursor`). | Bundles two zero-shared-code bridges; no pruning. |
| **[MOD-020] dependency-delta** | The sequence bridge needs `sequence-primitives` — a dep `memory-iterator-primitives` does **not** have. Non-zero delta ⇒ new package, not a target-split into memory-iterator. | n/a |
| **[MOD-032/033/034] cycle safety** | Depends **down** on memory + sequence + iterator; none depends back ⇒ no cycle. [MOD-034]: the bridge role is *incidental* (capability layer), not foundational to memory or sequence identity ⇒ extraction-safe. | same cycle-safety, but the relocation churn re-opens [MOD-033] fan-in on the existing package. |
| **[MOD-RENT]** | (1) capability — supplies the consuming/pipeline witness for contiguous types; (2) consumer — the migrating buffer-linear conformers + `Memory.Contiguous` itself; (3) theoretical content — the memory↔single-pass-iteration boundary, the dual of memory-iterator. Passes. | n/a |

> **Asymmetry to record**: the two bridges are *not* structurally identical, but **both stay
> witness-only**. memory→Iterable reuses the bulk `Iterator.Chunk` (`swift-iterator-primitives`).
> memory→Sequenceable vends the owned `Memory.Cursor` (`swift-memory-cursor-primitives`, §1) —
> the *type* is homed in the cursor ecosystem, not invented in the bridge. So neither bridge
> package carries an iterator type; the difference is which upstream they pull (iterator vs
> sequence + memory-cursor). This reinforces two packages (different deps) and keeps both thin.

Package shape mirrors `swift-memory-iterator-primitives` (single target, `~Copyable`/
`Lifetimes`/strict-memory-safety settings, no Test Support unless tests are added —
`memory-iterator` has none). Naming per [PKG-NAME-001] noun-form + [PRIM-NAME-001]
`-primitives`; it declares no new namespace (the witness extends `Memory.Contiguous`; the cursor
type lands in `swift-memory-cursor-primitives`). Created with `gh repo create --private` per
`feedback_never_create_public_repos`; declared path-form per [PKG-DEP-001]. The companion change
— `Memory.Cursor` + its `iterator-primitives` dep in `swift-memory-cursor-primitives` (§1) — is a
second execution target. **Out of scope here** (planning only) — flagged for the execution dispatch.

### §3 — Per-conformer migration

The parent cascade (`HANDOFF-sequence-iterable-rename-cascade.md` /
`world-b-span-decomposition.md`) lands first; the `Sequence.Borrowing` drop folds into the
same conformance line each conformer already edits for `Sequence.\`Protocol\`` →
`Iterable`/`Sequenceable`.

| Conformer | Migration |
|-----------|-----------|
| `Buffer.Linear`, `.Bounded`, `.Small` (contiguous) | Drop `, Sequence.Borrowing.\`Protocol\`` from the conformance clause. Opt into `Iterable` (multipass) and/or `Sequenceable` (pipeline) — each derives `makeIterator()` **for free** from the two bridges over the already-present `Memory.Contiguous.Protocol` conformance. To preserve their current `Element: Copyable` multipass generality, the Iterable bridge's `Element` floor relaxes `BitwiseCopyable → Copyable` (OQ-1 **CONFIRMED feasible** — `Iterator.Chunk`/`Swift.Span` accept Copyable non-BitwiseCopyable; in-context relax + cross-module per [EXP-017] at execution). |
| `Buffer.Linear.Inline` (contiguous, no `Sequence.Borrowing` today) | **Purely additive** — nothing to drop; opt into `Iterable`/`Sequenceable` only if iteration is wanted. |
| `Buffer.Ring` (heap, **piecewise** — 1–2 real segments) | **NOT the memory bridge** (no single `span`). `Iterable` = bulk via `Buffer.Ring.Segments`, a thin iterator owning ≤2 canonical `Iterator.Chunk<Element>` (one per segment), draining A→B — **reuses** `Iterator.Chunk.next(maximumCount:)`; its only `@unsafe` work is constructing the segment `Span`(s) in `makeIterator`. `Sequenceable` = hand-written scalar. `@_implements` split. **VERIFIED** 58161ac (129 tests green). The brief's shorthand *"ring→Iterator.Chunk"* was directionally right (reuse) but the mechanism is ≤2-chunk *composition*, not one chunk. |
| `Buffer.Ring.Inline`, `.Bounded`, `.Small` (inline `@_rawLayout`) | **Scalar — NOT bulk.** A wrapped ring over inline storage would need a 2-segment span concat over `self`-lifetime-bound inline spans = the demangle-fragile generic-witness-over-`@_rawLayout` path; scalar sidesteps it. Each conforms a borrow-scalar `Walk` (`Iterable`) + owning-consuming `Scalar` (`Sequenceable`), `@_implements` split (a single shared iterator is not expressible — `Iterable.makeIterator` is `borrowing`, `Sequenceable`'s `consuming`). No `Chunk`. **VERIFIED** 58161ac. |
| `Sequence.Span` Property.Inout consumer (`Sequence Span Primitives`) | Re-base `extension Property.Inout where Base: Sequence.Borrowing.\`Protocol\`` onto `Base: Memory.Contiguous.Protocol` — its `.span.forEach`/`.elements`/`.reduce` are bulk-span operations the substrate provides directly. Home for the re-based ops: the memory→Iterable bridge package (it already owns the contiguous↔bulk surface). Sub-decision flagged (OQ-4). |

### §4 — Boundary table (what does NOT use the bridge)

| Case | Why excluded | Route instead |
|------|--------------|---------------|
| `~Escapable` elements | `Span<Element>` requires `Element: Escapable` (Swift 6.3.1); `Sequence.Borrowing` itself blocks it (`Sequence.Borrowing.Protocol.swift:48-49`). | None yet — blocked upstream until `Swift.Span` accepts `~Escapable`. |
| `~Copyable` elements | The bridge `makeIterator` copies elements out (extraction); needs `Copyable`. | Bespoke conformance; in-loop borrowing `forEach(borrowing:)` via `Iterable` admits `~Copyable`, but the *memory bridge* does not vend it. |
| Non-contiguous containers (ring, linked, tree) | No single `span` ⇒ cannot conform `Memory.Contiguous.Protocol`. | Bespoke `Iterable`/`Sequenceable` conformance. |
| Piecewise (heap ring's 1–2 segments) | Two spans, not one ⇒ no single-span `Memory.Contiguous`. | `Buffer.Ring.Segments` — a thin iterator *composing* ≤2 canonical `Iterator.Chunk` (reuse, not re-roll). **VERIFIED** 58161ac. |
| Piecewise over inline `@_rawLayout` (`.Inline`/`.Bounded`/`.Small` ring) | A 2-segment span concat over `self`-bound inline spans is the demangle-fragile path. | Scalar `Iterator.\`Protocol\`` (`Walk` + `Scalar`), not bulk. **VERIFIED** 58161ac. |
| `Copyable & ~BitwiseCopyable` elements, **bulk path** | The memory→Iterable bridge *currently* floors at `Element: BitwiseCopyable` (`Memory.Contiguous+Iterable.swift:28`). | **Not a permanent exclusion** — OQ-1 CONFIRMED that floor is an over-constraint relaxable to `Copyable`. After the relax, the bulk Iterable bridge covers them; the scalar Sequenceable bridge already did. (Until the relax lands, the scalar bridge is the route.) |

### §5 — Deletion of `Sequence Borrowing` + `Sequence Span` targets ([ARCH-LAYER-009])

**The brief's "deletion gated on zero-conformer grep + principal authorization" is too
permissive for the pre-1.0 phase, and is corrected here.** The exact [ARCH-LAYER-009] clause
relied on (verbatim from the `swift-institute` skill):

> **Statement**: During pre-1.0 / private-development phase, NO packages and NO source modules
> (`Sources/<X>/`) MAY be removed from disk for any reason. … **Removal candidates are evaluated
> only at public-release time, and even then with explicit per-action authorization.**
>
> **Forbidden during pre-1.0**: `rm -rf` of a package directory · Deleting a `Sources/<X>/`
> directory · Removing a `.target(name:)` declaration without preserving the source.

**Reconciliation with the sibling cascade (one rule).** `HANDOFF-sequence-iterable-rename-cascade.md`
frames the same three-target retirement as "delete on zero-conformer grep + authorization." That
is **not** a contradiction once timing is made explicit: the cascade's gate *is*
[ARCH-LAYER-009]'s release-time "explicit per-action authorization" — the cascade simply omitted
the pre-1.0 *interim*. Collapsed to one rule both arcs honor: **retain-and-supersede through
pre-1.0; the zero-conformer-grep + per-action-authorization deletion fires at public-release.**
(If the principal reads [ARCH-LAYER-009] as permitting dev-time deletion of a zero-conformer
target, that is a skill-amendment decision — surfaced, not assumed; until then, retain-and-supersede.)

Recommended two-phase retirement:

| Phase | Action | Gate |
|-------|--------|------|
| **Pre-1.0 (now)** | Land the two bridges; migrate all conformers (§3); the `Sequence Borrowing` + `Sequence Span` source **stays on disk**, with `Sequence.Borrowing.Protocol` annotated superseded (doc note pointing to `Memory.Contiguous` + `Iterable`/`Sequenceable`), zero conformers. | None beyond normal review. **No `rm`, no `.target` removal.** |
| **Release-time** | Delete the `Sequence Borrowing Primitives` + `Sequence Span Primitives` targets. | (a) **zero-conformer workspace-wide grep** — `grep -rn 'Sequence\.Borrowing\.\`Protocol\`'` across all org-mirror dirs (per [HANDOFF-050] / [PKG-NAME-013], not just swift-primitives), expect zero; AND (b) **explicit per-action principal authorization**; AND (c) release-readiness pass per [ARCH-LAYER-009]. |

The interim "retained-but-superseded" state is exactly [ARCH-LAYER-009]'s "unused source
stays on disk; consider archiving/aliasing if cleanup is needed."

### §6 — Stale `Sequenceable.swift` doc fix (Step-C C1/C2)

`Sequenceable.swift` is internally inconsistent `[Verified: 2026-05-27]`: its top
(`:17-26`) already names `Iterable` the multipass sibling, but its **two-tier table**
(`:59-67`) and the line at `:75` still name `Sequence.Borrowing.Protocol` as the borrowing
tier. Fix: replace those `Sequence.Borrowing.Protocol` references with `Iterable`
(the borrowing/multipass attachable), discharging Step-C's C1 ("docs: chunked-span access
optimization over `Memory.Contiguous.Protocol`, not borrowing iteration") and C2
("Conformers typically also conform to `Memory.Contiguous.Protocol`"). Companion stale docs:
`Sequence Primitives.docc/Sequence-Protocol.md:7,15,36,113` and `Sequence.Span.swift:5,9,13`
(docc examples). All doc-only — fold into the same dispatch.

## Outcome

**Status: RECOMMENDATION (decision-pending on OQ-3/OQ-4).** The decomposition is sound and
operational; the two load-bearing risks (OQ-1, OQ-2) are now **spike-resolved** (debug+release);
the residual items are for principal sign-off before an execution dispatch is authored.

**Recommended / ratified decisions:**
1. **§2 one-vs-two packages → TWO** (ratified 2026-05-27). New `swift-memory-sequence-primitives`
   joins the existing `swift-memory-iterator-primitives`; do not merge or relocate.
   ([MOD-006]/[MOD-020]/[MOD-029]/[MOD-RENT].)
2. **§1 bridge shape** = the owning iterator is the **deferred W1 owned-`Cursor` sibling**
   (`Memory.Cursor`, homed in the existing `swift-memory-cursor-primitives`, `@frozen`, `Tagged`
   position), conforming `Iterator.\`Protocol\``, **Escapable, `@_lifetime` omitted**; the bridge
   package carries only the thin `where Self: Sequenceable` witness. (Withdraws the v1.0.0
   `Iterator.Walk`.) Design-fork → **(a) sibling owned type** (argued in §1).
3. **§5 deletion** = retain-and-supersede pre-1.0; the zero-conformer-grep + per-action
   authorization deletion fires at public-release — reconciling the sibling cascade to one rule.

**Resolved by the spike** (`Experiments/memory-contiguous-sequenceable-bridge-shape`, 6.3.2,
debug+release):

- **OQ-1 (constraint narrowing) → RESOLVED feasible.** `Iterator.Chunk` / `Swift.Span` accept
  `Copyable` non-`BitwiseCopyable` elements (generic + concrete probes compile). The memory→Iterable
  bridge's `Element: BitwiseCopyable` floor is an over-constraint; relaxing it to `Copyable`
  preserves buffer-linear's current multipass generality — **no forced regression.** *Residual
  (execution):* relax the real bridge witness in-context + cross-module per [EXP-017].
- **OQ-2 (Escapable owned cursor) → SPLIT VERDICT: ✅ non-generic / ❌ generic** (clean-build-confirmed
  at Stage A). The *shape* is right: an Escapable owned cursor conforming `Iterator.\`Protocol\``,
  vended from `consuming makeIterator()`, typechecks **when `@_lifetime` is omitted** (V1 with it
  REFUTED; V2a without it builds + runs for a concrete `[Int]` base). **But the GENERIC case is
  REFUTED at runtime:** the first generic conformer (`Buffer.Linear.Inline<capacity>`) crashes —
  `swift_getAssociatedTypeWitness` cannot demangle the `Iterator` witness for the generic
  `Sequenceable` conformance (Signal 6, `collect()`), on a verified-clean build (confound ruled
  out). Decisive control isolates it to the `Memory.Cursor`/Sequenceable generic witness, not the
  `@_implements` dual-split — it is the `Memory.Cursor` witness emission for a generic conformer.
  → **The `Memory.Cursor` bridge for Sequenceable is DORMANT** behind a `/issue-investigation` of the
  demangle (codegen/runtime bug vs `Memory.Cursor` reshape). Contiguous conformers still get
  `Sequenceable` — but via a **hand-written scalar iterator** (buffer-slab `d6fcf5b` pattern, proven
  green for a generic conformer), keeping `Iterable` via the bridge `Iterator.Chunk` (see §1 template);
  they swap to the `Memory.Cursor` bridge once the demangle is fixed (tracked follow-up). The Wave-1
  "OQ-2 CONFIRMED" was correct *for non-generic only* — this is exactly the concrete→generic residual
  flagged in §1.

**Open questions for principal sign-off:**

- **OQ-3 (naming) → near-resolved.** Anchored as `Memory.Cursor`, the owned-`Cursor` sibling in
  `swift-memory-cursor-primitives` (subject-homed, not the `Iterator` family). Confirm the final
  name.
- **OQ-4 (Sequence.Span re-home).** Exact home for the re-based `.span.*` Property.Inout ops
  (memory→Iterable bridge package vs a span-iteration sibling).
- **Sequencing.** All of the above sequence **after** the parent
  `HANDOFF-sequence-iterable-rename-cascade.md` lands ([HANDOFF-022]: the cascade touches
  the same buffer conformance lines; this is planning-only so no conflict, but the execution
  dispatch must assume the cascade first).

## References

- `swift-institute/Research/collection-sequence-protocol-detachment.md` (DECISION, Step-C)
- `swift-institute/Research/sequencer-primitives-reconciliation-refactor.md` (DRAFT, §4b D-2 RESOLVED — RETIRE)
- `swift-institute/Research/bulk-span-iteration-fold-vs-separate.md` (RECOMMENDATION)
- `swift-institute/Research/two-world-traversal-decomposition.md` (RECOMMENDATION)
- `swift-institute/Research/world-b-span-decomposition.md` (RECOMMENDATION; parent cascade)
- `swift-institute/Research/cursor-shape-a-vs-three-worlds.md` (IMPLEMENTED; shipping single-generic `Cursor` + W1 owned-sibling deferral realized here)
- `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` (**SUPERSEDED** 2026-05-18; Three-Worlds framing not the architecture)
- `swift-institute/Research/iterator-span-buffer-elimination.md`, `sequence-operator-unification.md` (adjacent)
- **Spike**: `swift-institute/Experiments/memory-contiguous-sequenceable-bridge-shape` (OQ-1 + OQ-2 CONFIRMED, Swift 6.3.2, debug+release)
- Source: `swift-memory-primitives` `Memory.ContiguousProtocol.swift:90`;
  `swift-memory-iterator-primitives` `Memory.Contiguous+Iterable.swift`;
  `swift-iterator-primitives` `Iterable.swift:33`, `Iterator.Chunk.swift`, `Iterator.Protocol.swift`, `Iterator.Once.swift`;
  `swift-sequence-primitives` `Sequenceable.swift:90`, `Sequence.Borrowing.Protocol.swift:43`,
  `Sequence.Map.swift:42`, `Sequence.Span+Property.Inout.swift:10`;
  `swift-cursor-primitives` `Cursor.swift:72`; `swift-memory-cursor-primitives`
  `Cursor+MemoryContiguousBorrowed.swift` (borrowed bridge; the owned `Memory.Cursor` sibling is new here).
- Skills: [ARCH-LAYER-009], [MOD-006], [MOD-020], [MOD-029], [MOD-032], [MOD-034], [MOD-RENT],
  [MOD-035], [API-NAME-001b], [MEM-COPY-004], [DS-006], [PKG-NAME-001], [PKG-DEP-001],
  [HANDOFF-022], [HANDOFF-050]; [EXP-002a], [EXP-011a], [EXP-017], [EXP-021], [RES-013a], [RES-027].
