# Cursor Phase 4 W1 Expansion — Principled Refuse

<!--
---
version: 1.0.0
last_updated: 2026-05-18
status: DECISION
tier: 3
scope: ecosystem-wide
---
-->

## Context

This Tier 3 architectural arc closes the Phase 4 W1 question left open by
`cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED (2026-05-18, single-generic
`Cursor<DomainTag: Ownership.Borrow.\`Protocol\` & ~Copyable>`).

The W2 borrowed Span-cursor cohort (`Cursor<Byte>` / `Cursor<Text>`) shipped in
`swift-cursor-primitives` (HEAD `b4dc49e`/`294f0c5`). The W3 portion of the
prior Phase 4 framing was dissolved 2026-05-18 by
`typed-input-unification.md` v1.0.0 DECISION — `Binary.Bytes.Input` now lives
as a typealias chain rooted in `swift-byte-parser-primitives` (canonical byte-domain
owned-input home), substrate in `swift-input-primitives`. Phase 4 reduces to W1
only.

**W1's open question**: what to do with `Binary.Cursor<Storage>` (~Copyable,
Escapable, dual-index reader-writer over `Storage: Memory.Contiguous.\`Protocol\` &
~Copyable where Storage.Element == UInt8`) and `Binary.Reader<Storage>` (same
generics, single-index read-only), both currently shipping at
`swift-primitives/swift-binary-primitives/Sources/Binary Cursor Primitives/`.

The v1.2.0 single-generic shape's protocol bound (`Ownership.Borrow.\`Protocol\``)
is the *borrowed-view* contract; it does not accommodate owned storage. Three
candidate paths surfaced:

- **(a) Sibling owned-cursor type** — introduce `Cursor.Owned<Storage>` and
  `Cursor.Owned.ReaderWriter<Storage>` (or analogous names) in
  `swift-cursor-primitives` alongside the existing `Cursor<DomainTag>`.
- **(b) Broader protocol bound** — introduce `Cursor.Storage.\`Protocol\``
  covering both borrowed-view and owned-storage cases; refactor `Cursor` to
  bound on it; conform `Byte.Borrowed` and the `Memory.Contiguous.\`Protocol\``
  family. Effectively re-introduces the two-generic shape v1.2.0 simplified
  away.
- **(c) Principled refuse** — `Binary.Cursor` + `Binary.Reader` remain in
  `swift-binary-primitives`; `swift-cursor-primitives` stays at Tier 6-8 with
  the borrowed Span-cursor cohort only; Phase 4 closes without W1 expansion.

The principal's 2026-05-17 authorization (recorded in
`cursor-abstractions-l1-ecosystem.md` v1.3.0 §Principal Authorization)
committed to Shape ι expansion under the *then-current* Three-Worlds
architecture. The v1.2.0 IMPLEMENTED single-generic shape (2026-05-18,
SUCCESSOR doc `cursor-shape-a-vs-three-worlds.md`) materially changed the
design ground and the same doc explicitly re-opened W1/W3 with:

> *"W1/W3 unification deferred without commitment."*

The principal's 2026-05-18 brief (HANDOFF-cursor-phase-4-w1-expansion.md)
enumerated principled-refuse (c) as a valid option, confirming the question
is fresh — not pre-committed under the v1.2.0 architecture.

**Trigger**: [RES-001a] First-principles re-evaluation triggered by v1.2.0
architecture change. The W1/W3 deferral framing in v1.2.0 + (c) on the
brief's option-set = the question is open.

**Tier**: 3 — successor to two Tier 3 arcs; precedent-setting for owned-cursor
placement; cost of error very high; expected lifetime evergreen.

**Scope**: Ecosystem-wide (cursor-primitives + binary-primitives + consumers).

## Question

Should `Binary.Cursor<Storage>` and `Binary.Reader<Storage>` migrate into
`swift-cursor-primitives` as part of the Phase 4 expansion contemplated by
the original Shape ι commitment, or stay in their current home in
`swift-binary-primitives`?

## Phase 0 — Prior-research grep (HARD GATE; per [HANDOFF-013a])

Internal corpus `swift-institute/Research/` and `swift-primitives/*/Research/`
greps for cursor, `Cursor.Storage`, `Cursor.Owned`, owned cursor,
`Ownership.Borrow.\`Protocol\``, `Memory.Contiguous.\`Protocol\``,
protocol-bound abstractions covering borrowed + owned:

| Document | Status | Relevance |
|---|---|---|
| `cursor-abstractions-l1-ecosystem.md` v1.7.0 | SUPERSEDED | Parent Tier 3 doc; recorded Principal Authorization committing Shape ι expansion 2026-05-17 under the Three-Worlds architecture; v1.7.0 dissolved W3 portion via Item 2. |
| `cursor-shape-a-vs-three-worlds.md` v1.2.0 | IMPLEMENTED | Canonical reference. Documents single-generic `Cursor<DomainTag>` shape and explicit W1/W3 deferral. Establishes the architectural ground this arc closes on. |
| `ownership-borrow-protocol-unification.md` v1.0.0 | DECISION | Defines `Ownership.Borrow.\`Protocol\`` with Cases A/B/C. The current `Cursor<DomainTag>`'s bound. Borrow-view contract; not owned-storage. |
| `nested-view-vs-borrowed-naming.md` v1.3.0 | DECISION | Pattern 1 (passive borrow-projection) → `.Borrowed`; Pattern 3 (stateful cursor) → `.View`/`.Cursor`/`.Iterator`. Explicitly classifies `Binary.Bytes.Input.View` (a cursor) as Pattern 3 NOT a `Ownership.Borrow.\`Protocol\`` conformer. Axis-based naming table (v1.2.0 framework) reserves `.Owned` as one of the access-mode suffixes for the property-family precedent. |
| `byte-cursor-primitive-unification.md` v1.3.0 | IN_PROGRESS | Predecessor analytical input. Shape F decomposition insight (`Tagged<DomainTag, Ordinal>` as the already-decomposed position substrate) survives as INPUT; downgraded after the per-package grep surfaced `Binary.Cursor` as a third cursor abstraction. |
| `owned-typed-memory-region-abstraction.md` v2.1.0 | DECISION | Defines `Memory.Contiguous<Element: BitwiseCopyable>` and the `Memory.Contiguous.\`Protocol\`` shape (`associatedtype Element: BitwiseCopyable; var count: Int { get }` + span access). Establishes the formal BitwiseCopyable boundary separating bulk-deallocation owned storage from `Storage<Element>` per-element lifecycle storage. |
| `typed-input-unification.md` v1.0.0 | DECISION | Closes Item 2: owned typed-input cursor placed in `swift-byte-parser-primitives`, NOT `swift-cursor-primitives`. Structural precedent for owned-cursor placement. |
| `swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md` v1.0.0 | RECOMMENDATION (2026-01-19) | Two Worlds architecture (Owned + Parsing.Parser vs Borrowed + Binary.Bytes.Parser). Structural-constraint claim obsoleted by SE-0503; reuse-strategy framing engaged by the v1.4.0 Tier 3 arc. |
| `linked-list-cursor-and-arena-backing-improvements.md` v1.0.0 | RECOMMENDATION | Different family of cursors (linked-list positional removal, Pool/Arena semantic boundary). Same English word; structurally orthogonal. NOT load-bearing for this arc. |

All material is cited-and-extended below. No new prior-art has surfaced
beyond what the listed docs already engage.

Phase 0 gate: **CLEAR**.

## Phase 1 — Three options analyzed

### Option (a) — Sibling owned-cursor type

**Concrete sketch** (illustrative; naming choices indicative):

```swift
// In swift-cursor-primitives — new types alongside the existing
// public struct Cursor<DomainTag: Ownership.Borrow.`Protocol` & ~Copyable>: ~Copyable, ~Escapable
extension Cursor {
    /// Owned single-index read-only cursor (parallel of Binary.Reader).
    public struct Owned<Storage: Memory.Contiguous.`Protocol` & ~Copyable>: ~Copyable
    where Storage.Element == UInt8 {
        public let storage: Storage
        @usableFromInline internal let _count: Index<Storage>.Count
        @usableFromInline internal var _readerIndex: Index<Storage>
        // peek / advance / isAtEnd / count / remainingBytes / ...
    }
}

extension Cursor.Owned {
    /// Owned dual-index read-write cursor (parallel of Binary.Cursor).
    public struct ReaderWriter<Storage: Memory.Contiguous.`Protocol` & ~Copyable>: ~Copyable
    where Storage.Element == UInt8 {
        public var storage: Storage
        @usableFromInline internal let _count: Index<Storage>.Count
        @usableFromInline internal var _readerIndex: Index<Storage>
        @usableFromInline internal var _writerIndex: Index<Storage>
        // dual-index operations + readableBytes / writableBytes / ...
    }
}

// In swift-binary-primitives — typealiases
extension Binary {
    public typealias Reader<Storage> = Cursor.Owned<Storage>
    where Storage: Memory.Contiguous.`Protocol` & ~Copyable, Storage.Element == UInt8

    public typealias Cursor<Storage> = Cursor.Owned.ReaderWriter<Storage>
    where Storage: Memory.Contiguous.`Protocol` & ~Copyable, Storage.Element == UInt8
}
```

**Tier impact**: cursor-primitives currently at Tier 6-8 (deps: tagged, ordinal,
cardinal, index, byte, ownership). Adding `swift-memory-primitives` (Tier 12)
as a dep elevates cursor-primitives to **Tier 13**. Per the cursor-abstractions
v1.2.0 inversion argument, this is post-publication-irreversible.

**Mitigation**: split-package (`swift-cursor-primitives` at Tier 6-8 hosting
the borrowed-Span Cursor + new `swift-cursor-owned-primitives` at Tier 13
hosting the owned variants). Sacrifices the discoverability-payoff of
"all cursors in one place" — readers must know which package to look in.

**Composition check per [RES-018]**:
- Cross-domain fit: `Cursor.Owned` and `Cursor.Owned.ReaderWriter` would have
  *one* consumer family today (`Binary.Cursor` + `Binary.Reader`). No
  cross-domain pressure currently exists; `swift-foundations/swift-json`,
  `swift-foundations/swift-lexer`, and every other consumer in the institute
  uses the borrowed Span-cursor (`Cursor<DomainTag>`) — not owned cursors.
- The W1 owned reader-writer pair is *intentional structural specialization*
  per `[API-IMPL-008]` / `[API-IMPL-006]` within the binary domain, not
  cross-domain duplication awaiting consolidation. Relocating the two struct
  declarations does not eliminate code; it relocates it.

**Reversibility**: γ → ι is small per cursor-abstractions v1.2.0; ι → γ is a
costly back-out post-publication (package deletion, typealias unwinding,
consumer-side rebuilds at L3+).

**Naming alignment per [API-NAME-001] / [API-NAME-001b]**:
- `Cursor.Owned<Storage>` works — `.Owned` is one of the access-mode suffixes
  formally established by `nested-view-vs-borrowed-naming.md` v1.2.0
  (table row "Access/ownership/reference-capability-discriminated property/
  accessor wrapper family" → `.Inout`, `.Borrow`, `.Owned`, `.Shared`, etc.).
- `Cursor.Owned.ReaderWriter<Storage>` is acceptable but verbose. Alternative
  flat shape `Cursor.OwnedReaderWriter<Storage>` violates `[API-NAME-002]`
  (no compound identifiers).

**Phase 4 closure**: yes — Phase 4 closes cleanly with `Binary.Cursor` /
`Binary.Reader` as typealiases over the new cursor-primitives types.

### Option (b) — Broader `Cursor.Storage.\`Protocol\`` bound

**Concrete sketch** (illustrative):

```swift
// New protocol in swift-cursor-primitives
extension Cursor {
    public enum Storage {}
}

extension Cursor.Storage {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        var span: Swift.Span<UInt8> { @_lifetime(borrow self) borrowing get }
        var count: Int { get }
    }
}

// Conformers
extension Byte.Borrowed: Cursor.Storage.`Protocol` {}  // ~Copyable, ~Escapable

extension Buffer.Heap: Cursor.Storage.`Protocol` where Element == UInt8 {}
// ... and all other Memory.Contiguous.Protocol conformers with Element == UInt8

// Cursor refactored to bound on the new protocol
public struct Cursor<
    Storage: Cursor.Storage.`Protocol` & ~Copyable & ~Escapable,
    PositionTag: ~Copyable
>: ~Copyable {
    @usableFromInline internal var storage: Storage
    @usableFromInline internal var _position: Tagged<PositionTag, Ordinal>
}

extension Cursor: Escapable where Storage: Escapable & ~Copyable, PositionTag: ~Copyable {}
```

**Effect**: re-introduces the two-generic shape (`Storage`, `PositionTag`) with
conditional `Escapable` — which the v1.2.0 IMPLEMENTED single-generic shape
explicitly removed:

> *"The conditional Copyable/Escapable extensions are dropped — storage is
> always `~Copyable, ~Escapable` (per the protocol's associated-type
> declaration), so the cursor is always `~Copyable, ~Escapable`."*

Call sites collapse back from `Cursor<Byte>(span)` to either
`Cursor<Byte.Borrowed, Byte>(...)` or — if Ownership.Borrow.Protocol's
associatedtype is preserved as a convenience — a mix of shapes per
instantiation. **This is an architectural regression** relative to v1.2.0.

**Tier impact**: same as Option (a) — Memory.Contiguous.Protocol becomes a
dep of cursor-primitives. **Tier 13**.

**Composition check per [RES-018]**:
- The protocol unifies the interface but does NOT unify the implementation.
  The borrowed-view path and the owned-storage path have different lifetime
  semantics; the storage protocol just gives uniform `var span` access.
- No consumer needs `Cursor<some Cursor.Storage.\`Protocol\`>`-style generic
  dispatch in the workspace at HEAD 2026-05-18 (greps for
  `<.*: Cursor\.Storage`-shaped constraints across primitives + standards +
  foundations return zero matches). The abstraction would have no consumer.
- Per cursor-abstractions v1.4.0 Q5: *"Cursor.Protocol can be added without
  disrupting the three Worlds. Defer the decision until that consumer is
  named."* The same logic applies to `Cursor.Storage.\`Protocol\``.

**Reversibility**: even more costly than Option (a) — adding a protocol
locks in the abstraction structure across all conformers; removing it later
is breaking-change-shaped.

**Naming alignment**: `Cursor.Storage.\`Protocol\`` follows the institute's
`Namespace.\`Protocol\`` form per `[PKG-NAME-002]` and is internally
consistent. No naming defect.

**Phase 4 closure**: yes — Phase 4 closes with Binary.Cursor / Binary.Reader
as instantiations of the unified `Cursor<Storage, PositionTag>`.

### Option (c) — Principled refuse

**Concrete state**:
- `swift-cursor-primitives` stays at Tier 6-8 hosting only `Cursor<DomainTag>`
  (the W2 borrowed Span-cursor cohort) at its current HEAD `294f0c5`.
- `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` stay in
  `swift-binary-primitives/Sources/Binary Cursor Primitives/` unchanged.
- No new package, no new types in cursor-primitives, no source changes
  outside this research arc's doc back-port.

**Tier impact**: cursor-primitives stays at Tier 6-8. `Memory.Contiguous.\`Protocol\``
remains an unused-by-cursor-primitives type — used by binary-primitives,
buffer-primitives, etc. at higher tiers as before.

**Composition check per [RES-018]**:
- N/A — no extraction. The binary-domain owned-cursor pair stays in its
  domain home. The institute's existing per-domain placement discipline
  per `[MOD-DOMAIN]` is preserved.
- W2's cross-domain duplication (`Binary.Bytes.Input.View` vs
  `Lexer.Scanner`) WAS the only cursor-side cross-domain pressure in the
  workspace. The v1.2.0 single-generic Cursor resolved it. W1 has no
  parallel cross-domain pressure.

**Reversibility**: maximum. If a future cross-domain owned-cursor consumer
materializes (e.g., a non-binary L1 package needing dual-index owned
reader-writer over Memory.Contiguous storage), the extraction can be done
*then* — informed by the second consumer's actual shape. Pre-extraction
on hypothetical pressure is exactly the speculative-architecture-laundering
pattern that `nested-view-vs-borrowed-naming.md` v1.2.0 names forbidden.

**Naming alignment**: N/A — no new types.

**Phase 4 closure**: yes — Phase 4 closes with principled-refuse rationale.
The Shape ι end-state framing from `cursor-abstractions-l1-ecosystem.md`
v1.3.0 is superseded by the v1.2.0 single-generic architecture; the
"committed expansion" framing was scoped to the Three-Worlds shape (now
itself SUPERSEDED). The W1/W3 deferral framing in
`cursor-shape-a-vs-three-worlds.md` v1.2.0 re-opened the question; this
arc closes it.

### 4th option enumeration (per brief's class-(c) escalation discipline)

No 4th option materialized during analysis. Two near-options surfaced and
were rejected:

- **Hybrid (d)**: move only `Binary.Reader` (the read-only single-index
  variant — structurally most analogous to W2's single-index cursor) to
  cursor-primitives; leave `Binary.Cursor` (dual-index reader-writer) in
  binary-primitives. **Rejected**: the W1 reader-writer + reader pair is
  intentional structural specialization (per cursor-abstractions v1.2.0
  §Type structure); splitting them sacrifices the sibling-pair framing
  without eliminating duplication.
- **Bare relocation (e)**: move both W1 types to cursor-primitives without
  any abstraction (Option a without the `.Owned` namespace nesting).
  **Rejected**: this is structurally identical to Option (a), modulo naming
  detail.

No class-(c) ecosystem escalation is triggered. No Tier-13 problematic
sub-Tier-13 consumer surfaced.

## Phase 2 — DECISION

**Status**: DECISION.

**Verdict**: **Option (c) — Principled refuse.** `Binary.Cursor<Storage>` and
`Binary.Reader<Storage>` remain in `swift-binary-primitives`. Phase 4 closes
without W1 expansion. `swift-cursor-primitives` stays at Tier 6-8 with the
borrowed-Span Cursor cohort only.

### Rationale

The principled answer is grounded in seven structural arguments:

1. **The v1.2.0 single-generic architecture changed the design ground.** The
   2026-05-17 Principal Authorization committing Shape ι expansion was made
   under the Three-Worlds architecture (v1.0.0-v1.3.0 framing — Cursor.Span,
   Cursor.OwnedReader, Cursor.OwnedReaderWriter, Cursor.Input as parallel
   shapes). The 2026-05-18 v1.2.0 IMPLEMENTED single-generic shape replaced
   that with `Cursor<DomainTag: Ownership.Borrow.\`Protocol\`>` — a *borrow-view*
   contract that does not generalize to owned storage. The same v1.2.0
   doc explicitly re-opened the question: *"W1/W3 unification deferred
   without commitment."* Honoring the prior commitment under the new
   architecture requires either a sibling type (Option a, which doesn't
   unify) or a regression to two-generic (Option b). Both produce worse
   structural shapes than the v1.2.0 simplification achieved.

2. **W1 has no cross-domain duplication.** The duplication-elimination
   case that justified W2 unification was empirical: two near-identical
   `~Copyable & ~Escapable` Span-cursor implementations (`Binary.Bytes.Input.View`
   and `Lexer.Scanner`) maintained across two packages with mechanically
   parallel scaffolding. W1's `Binary.Cursor` + `Binary.Reader` are
   *intentional structural specialization* per `[API-IMPL-008]` /
   `[API-IMPL-006]` — two related sibling types within the same package
   with deliberately different operation sets (rw dual-index vs ro
   single-index). Centralization relocates the two struct declarations
   without eliminating any code. The "duplication-elimination" payoff is
   absent.

3. **The Item 2 / typed-input-unification precedent (2026-05-18) supports
   principled refuse on owned-cursor placement.** Item 2 placed the
   byte-domain owned-input cursor in `swift-byte-parser-primitives`
   (canonical byte-domain owned-input home per `[API-NAME-001b]`), NOT in
   `swift-cursor-primitives`. The structural symmetry argues the same:
   the binary-domain owned-cursor pair belongs in `swift-binary-primitives`
   (canonical binary-domain owned-cursor home), NOT in cursor-primitives.
   `typed-input-unification.md` v1.0.0 already dissolved the W3 portion of
   the original Shape ι expansion on exactly this reasoning; the W1
   portion lands the same way.

4. **`Ownership.Borrow.\`Protocol\`` is the *borrow-view* contract, not the
   *owned-storage* contract.** The institute has no parallel
   "owned-storage capability" protocol for the borrow-pattern domain types
   (Byte, Text) the W2 Cursor parameterizes over. `Memory.Contiguous.\`Protocol\``
   exists, but it abstracts owned-storage *implementations* (Buffer.Heap,
   Buffer.Linear, Buffer.Aligned, Memory.Contiguous itself), NOT the
   *value-domain phantom tags* (Byte, Text) that the W2 Cursor's DomainTag
   generic encodes. Forcing W1 into the same Cursor type requires either
   a sibling type with completely different generic shape (Option a) or
   a broader protocol abstraction (Option b) that adds complexity without
   eliminating duplication.

5. **`nested-view-vs-borrowed-naming.md` v1.3.0 Pattern 3 classifies
   cursors as stateful traversal, NOT borrow-projections.** The current
   single-generic `Cursor<DomainTag>` uses `Ownership.Borrow.\`Protocol\``
   AS A STORAGE CARRIER mechanism (the DomainTag's `Borrowed` associated
   type is the cursor's storage shape), not because the cursor itself is
   a borrow-projection. Owned cursors don't have a parallel "owned-storage
   capability via phantom-tag conformance" relationship in the ecosystem.
   The v1.3.0 framework's axis-based naming table reserves `.Owned` as a
   property-family suffix; it does not prescribe that owned cursors should
   centralize into a cursor-namespace alongside borrow-domain cursors.

6. **Tier 13 elevation is post-publication-irreversible.** Adding
   `swift-memory-primitives` (Tier 12) as a dep of cursor-primitives
   elevates cursor-primitives to Tier 13, foreclosing future sub-Tier-13
   cross-cutting consumers. Currently no such consumer exists, but the
   restriction is permanent once Tier 13 is committed. The split-package
   mitigation (Tier 6-8 + Tier 13 siblings) sacrifices the discoverability
   payoff that motivated centralization. Per `cursor-abstractions-l1-ecosystem.md`
   v1.2.0's reversibility heuristic: Shape γ → Shape ι is a small follow-on
   if evidence supports; Shape ι → Shape γ is a costly back-out post-
   publication. Option (c) preserves maximum reversibility.

7. **[ARCH-LAYER-006] Domain Completeness, Not Consumer Count, Determines
   L1 Existence.** Binary.Cursor + Binary.Reader belong where their domain
   mission places them, regardless of current consumer count (which is
   zero outside their defining package at HEAD 2026-05-18). The binary
   domain's mission is binary-format reader-writer semantics; owned
   cursors over contiguous storage are part of that mission. Moving them
   into a cursor-mechanics-mission package dilutes both packages'
   missions per `[ARCH-LAYER-010]` strict-mission discipline.

### Acceptance criteria check (per brief)

- **Composition check explicit**: ✓ — Option (c) has no composition action;
  the institute's per-domain placement discipline `[MOD-DOMAIN]` is
  preserved. Options (a) and (b) fail the substantive composition test
  (no cross-domain pressure to compose against; W2's case was unique).
- **Tier impact explicit**: ✓ — Option (c) keeps cursor-primitives at Tier
  6-8; no Memory.Contiguous.Protocol dep added. Options (a) and (b)
  elevate to Tier 13 (post-publication-irreversible per the inversion
  reasoning).
- **Reversibility heuristic explicit**: ✓ — Option (c) preserves maximum
  reversibility. If a future second cross-domain consumer of owned-cursor
  mechanics materializes (currently zero), centralization can be done then.
- **Phase 4 closure status explicit**: ✓ — Phase 4 closes with principled
  refuse. The Shape ι "committed expansion" framing was scoped to the
  Three-Worlds shape (itself SUPERSEDED); the v1.2.0 single-generic
  architecture's W1/W3 deferral framing re-opened the question; this arc
  closes it.

### What this DECISION does

- Closes the Phase 4 W1 expansion question with a principled-refuse verdict.
- Preserves `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` in their
  current `swift-binary-primitives` home with no source changes.
- Preserves `swift-cursor-primitives` at Tier 6-8 with only the borrowed
  Span-cursor cohort.
- Closes `HANDOFF.md` Wave 1 Phase 4 expansion (in concert with the W3
  dissolution from Item 2).

### What this DECISION does NOT do

- Does not foreclose a future centralization arc. If a cross-domain owned-
  cursor consumer materializes (a second non-binary L1 domain needing
  dual-index owned reader-writer over Memory.Contiguous storage), the
  W1 extraction can be opened then — informed by the second consumer's
  actual shape, not by hypothetical pressure.
- Does not modify `Binary.Cursor` or `Binary.Reader`'s public API surface.
- Does not bind `HANDOFF.md` Wave 1 Items 3, 4, 5 — those proceed
  independently per the original brief.
- Does not add `Cursor.Protocol` (Shape B) or `Cursor.Storage.\`Protocol\``
  (Option b in this arc). Q5 of `cursor-abstractions-l1-ecosystem.md`
  v1.4.0 remains the disposition for that question: defer until a
  generic-over-cursors consumer materializes.

## Phase 3 — Implementation

**None.** Option (c) requires no source changes to `swift-cursor-primitives`,
`swift-binary-primitives`, or any consumer. The ecosystem build gate per
`[HANDOFF-035]` is not triggered.

## Phase 4 — Doc back-port

Doc updates landing in this arc:

1. `swift-institute/Research/cursor-w1-expansion.md` v1.0.0 DECISION (this doc).
2. `swift-institute/Research/cursor-abstractions-l1-ecosystem.md` v1.7.0 →
   v1.8.0: status remains SUPERSEDED; adds §Phase 4 W1 Resolution recording
   this arc's principled-refuse outcome and noting that Phase 4 closes.
3. `swift-institute/Research/cursor-shape-a-vs-three-worlds.md` v1.2.0 →
   v1.3.0: status remains IMPLEMENTED; adds §Phase 4 W1 Resolution recording
   that the v1.2.0 W1/W3 deferral is now closed via principled-refuse.
4. `HANDOFF.md` Wave 1 Item 1: mark Phase 4 W1 expansion CLOSED via
   principled refuse; cross-reference this doc.
5. `swift-institute/Research/_index.json`: add entry for this new doc;
   amend entries for cursor-abstractions and cursor-shape-a-vs-three-worlds
   with version bumps and W1-resolution statusDetail.

## Revisit conditions

This DECISION is closed under principled-refuse. Revisit conditions:

1. **Cross-domain owned-cursor consumer surfaces.** A second L1 package
   (non-binary domain) requiring dual-index or single-index owned
   reader/writer over `Memory.Contiguous.\`Protocol\`` storage — currently
   zero such consumers in the workspace. If one materializes, re-evaluate
   W1 extraction informed by the second consumer's actual shape.
2. **Tier-13 cap becomes binding.** A sub-Tier-13 cursor consumer
   materializes that would benefit from owned-cursor primitives — currently
   none. If one surfaces, the Tier 13 cost becomes problematic and an
   extraction (with split-package mitigation) becomes warranted.
3. **`Memory.Contiguous.\`Protocol\``'s shape changes substantively.** If
   the storage protocol is reshaped (e.g., absorbed into a broader
   abstraction or replaced by a different L2 boundary), revisit whether
   the W1 cursor types should follow that change cohort.

## Out of scope

- Renaming or reshaping `Binary.Cursor` / `Binary.Reader` — they survive
  in their current shape at HEAD `97660a3` on `swift-binary-primitives`.
- `HANDOFF.md` Wave 1 Items 3 (Word16/32/64.Protocol), 4 (D6 serializer-side
  extraction), 5 (capability-marker proliferation) — separate arcs.
- Public-var-storage perf audit (surfaced as a follow-on from BENCH-011
  finding in cursor-abstractions v1.4.0 §Binary 20-100× speedup root cause)
  — separate arc.
- Adding `Cursor.Protocol` (Shape B) as a future enhancement — defer until
  a generic-over-cursors consumer materializes (per cursor-abstractions
  v1.4.0 Q5).

## References

### Internal corpus (engaged)

- `cursor-abstractions-l1-ecosystem.md` v1.7.0 SUPERSEDED — parent Tier 3 arc.
- `cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED — canonical
  reference for the single-generic shape; this arc closes its W1/W3 deferral
  on W1.
- `ownership-borrow-protocol-unification.md` v1.0.0 DECISION — the
  borrow-view contract framework.
- `nested-view-vs-borrowed-naming.md` v1.3.0 DECISION — Pattern 1/3
  classification + axis-based naming framework.
- `byte-cursor-primitive-unification.md` v1.3.0 IN_PROGRESS — predecessor.
- `owned-typed-memory-region-abstraction.md` v2.1.0 DECISION —
  Memory.Contiguous.Protocol framework.
- `typed-input-unification.md` v1.0.0 DECISION — Item 2 / W3 dissolution
  precedent.
- `swift-binary-primitives/Research/Lifetime Dependent Borrowed Cursors.md`
  v1.0.0 RECOMMENDATION (2026-01-19) — Two Worlds prior framing.

### Source-code anchors (verified at HEAD 2026-05-18)

- `swift-primitives/swift-cursor-primitives/Sources/Cursor Primitives Core/Cursor.swift:64-85`
  — `public struct Cursor<DomainTag: Ownership.Borrow.\`Protocol\` & ~Copyable>: ~Copyable, ~Escapable`
  (HEAD `b4dc49e`).
- `swift-primitives/swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Cursor.swift:42`
  — `public struct Cursor<Storage: Memory.Contiguous.\`Protocol\` & ~Copyable>: ~Copyable where Storage.Element == UInt8`.
- `swift-primitives/swift-binary-primitives/Sources/Binary Cursor Primitives/Binary.Reader.swift:42`
  — `public struct Reader<Storage: Memory.Contiguous.\`Protocol\` & ~Copyable>: ~Copyable where Storage.Element == UInt8`.
- `swift-primitives/swift-byte-primitives/Sources/Byte Primitives/Byte.Borrowed.swift:69`
  — `extension Byte: Ownership.Borrow.\`Protocol\` {}`.
- `swift-primitives/swift-text-primitives/Sources/Text Primitives/Text+Ownership.Borrow.Protocol.swift:43-44`
  — `extension Text: Ownership.Borrow.\`Protocol\`` with `typealias Borrowed = Byte.Borrowed`.

### Skills referenced

- `[ARCH-LAYER-001]` — Dependency Direction (layer cascade discipline).
- `[ARCH-LAYER-006]` — Domain Completeness, Not Consumer Count.
- `[ARCH-LAYER-008]` — Correctness Driver during pre-1.0.
- `[ARCH-LAYER-010]` — Strict-Mission Boundaries, Optimized Early.
- `[API-NAME-001]` / `[API-NAME-001b]` / `[API-NAME-002]` — naming discipline.
- `[API-IMPL-006]` / `[API-IMPL-008]` — intentional structural specialization.
- `[MOD-DOMAIN]` — per-domain primitive grouping.
- `[RES-018]` — case-(a) cross-cutting primitive composition check.
- `[PKG-NAME-002]` — `Namespace.\`Protocol\`` form.

## Provenance

Surfaced 2026-05-18 by the `HANDOFF-cursor-phase-4-w1-expansion.md` dispatch.
Triggered by the explicit W1/W3 deferral framing in
`cursor-shape-a-vs-three-worlds.md` v1.2.0 IMPLEMENTED (2026-05-18) re-opening
the question that the prior 2026-05-17 Principal Authorization had committed
under the now-SUPERSEDED Three-Worlds architecture.

The arc's Phase 0 prior-research grep CLEARED — all load-bearing prior
artifacts (cursor-abstractions, cursor-shape-a-vs-three-worlds,
ownership-borrow-protocol-unification, nested-view-vs-borrowed-naming,
byte-cursor-primitive-unification, owned-typed-memory-region-abstraction,
typed-input-unification, Lifetime Dependent Borrowed Cursors) cited-and-
extended; no new prior-art surfaced beyond what these engage. No
class-(c) ecosystem escalation triggered.

The DECISION-grade verdict is principled refuse on Option (c), grounded in
seven structural arguments and consistent with the precedent set by
typed-input-unification.md v1.0.0 (W3 portion of Phase 4 dissolved via the
same per-domain placement reasoning).

## Changelog

- **v1.0.0** (2026-05-18): DECISION — Option (c) principled refuse.
  `Binary.Cursor<Storage>` + `Binary.Reader<Storage>` stay in
  `swift-binary-primitives`. `swift-cursor-primitives` stays at Tier 6-8
  hosting only the borrowed Span-cursor cohort. Phase 4 closes with
  principled-refuse rationale; the Shape ι "committed expansion" framing
  scoped to the now-SUPERSEDED Three-Worlds architecture is closed. Seven
  structural arguments documented in §Phase 2 §Rationale.
