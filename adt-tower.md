# The ADT Tower

<!--
---
version: 1.0.0
last_updated: 2026-07-02
status: DECISION
tier: 3
scope: ecosystem-wide
---
-->

> **Status: RATIFIED 2026-07-02.** This document is simultaneously the research record, the
> ratified design, and the executable implementation plan for the data-structure tower
> (`Memory ⊏ Storage ⊏ Buffer ⊏ ADT`) across swift-primitives. It supersedes the PROVISIONAL
> Decoupling Charter ([DS-025]–[DS-027] as revised 2026-06-18) and every other tower document
> per the supersession ledger in §10. There are no provisional states in this document: every
> load-bearing claim is backed by an in-session compiling experiment against the toolchain and
> packages of record, or is an inherited negative no design surface depends on (§3 marks each).
>
> **Toolchain of record**: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101),
> `arm64-apple-macosx26.0`, Xcode 26.6. Facts banked on 6.3.2 were re-probed on 6.3.3 where
> load-bearing (§3); Swift 6.4 features are cited as *branched, not shipping* (branch cut
> 2026-05-04, no release date). A Swift 6.4 ecosystem FLOOR is scheduled for the September
> release (principal ruling 2026-07-02; §9.7); no decision in this document depends on it.
>
> **Prime directive discharged**: the prior corpus (≈300 documents; Appendix A of
> `PROMPT-adt-tower-rederivation.md`) was mined as evidence, never authority. Every decision
> below was re-derived from first principles plus the systematic literature review in §6; where
> the re-derivation independently arrives at a prior decision, that is stated; where it
> overturns one, the overturned decision appears in §8 (rejected alternatives) or §10 (ledger).

---

## 1. The north star, and the measured result

> **North star (principal, 2026-07-02)**: declare ADT types and their variants
> (Small/Inline/Heap-class allocation behaviors) with as minimal code duplication as possible.

The tower is a means; the end is that adding a container or a variant is cheap, uniform, and
correct. The prior program's failure was inverting this: layer ontology was perfected while
declaration cost was never measured, and the implementation converged on nothing — three
incompatible ADT shapes coexist in-tree today (§3.2 of the prompt; re-verified at source
2026-07-02: 8 primary shape-S declarations + 2 inherited, 6 element-generic, `Tree`/`List.Linked`
thin-generic, `Bitset` concrete).

### 1.1 The measured declaration cost (the acceptance gate)

`Experiments/adt-tower-worked-example` declares a **complete new ADT** — `Heap`, a binary min
priority queue — with **two allocation variants** (heap-growable canonical + `Small<n>`
inline-budget-spills-to-heap), against the **real** upstream packages
(swift-buffer-linear-primitives, swift-storage-primitives, swift-memory-{heap,small,allocation}-primitives,
swift-comparison-primitives; path deps, [EXP-020] real-shape discipline). It compiles and runs
debug + release, cross-module, with full `~Copyable` element support (a move-only
`Job: Comparison.Protocol` element flows through push/pop/min), and the `-O` client SIL carries
**zero `witness_method` dispatch on tower operations** (the 9 residual sites are
print/stdlib-`Array` machinery and the element's own conformance-thunk definitions; 52
specialized `function_ref`s carry the tower calls).

| Quantity | Measured | Unit |
|---|---|---|
| **New ADT, total** | **105** | code lines (1 file, 1 target, 0 new packages) |
| — carrier (§D2 shape) | 10 | lines |
| — semantic ops (the irreducible algorithm: sift/exchange/pop/min/observability) | 62 | lines |
| — growth (allocation-generic init + push) | 15 | lines |
| — front doors (canonical + 1 variant) | 6 | lines |
| — imports | 12 | lines |
| **New allocation variant, marginal** | **3** | code lines: one constrained typealias; ZERO op code, ZERO conformance code (measured for heap+small; the INLINE front door — `Buffer<Store.Inline<E, n>>.D`, bounded-only ops — lands with the W3 bounded-pin generalization, same mechanism) |
| New capacity variant (`.Bounded`), marginal | ~3 + one thin throws-typed growth pin | lines (§D4.4) |
| New ownership column (`Shared` CoW) front door | ~3 + one thin gate twin per growth op | lines (§D4.5) |

Comparison baselines, for honesty about what the 105 lines replace:

| Baseline | Cost | Source |
|---|---|---|
| In-tree `Heap` (shape E, current) | 2,676 LOC across 8 source targets, 67 public members — and its `.Fixed`/`.MinMax.Fixed` variant families were *deleted* in the Round M coda because their duplication was unaffordable | swift-heap-primitives, survey 2026-07-02 |
| In-tree `Queue` op layer (shape S, current) | every op × every column combination: `enqueue` exists three times (heap-pinned, `Shared`-pinned, `Bounded`-pinned), with `Memory.Heap` hardcoded in each pin — adding `.Small` today means duplicating the whole op layer | `Queue+Columns.swift:39–63` |
| Rust `SmallVec` (the hand-variant baseline) | ~2,625–3,037 lines re-implementing `Vec`'s surface per variant; 5 RUSTSEC advisories, 4 memory-corruption, concentrated in the duplicated grow/insert paths | §6.2 |
| Swift stdlib `UniqueArray` over internal `_RigidArray` | the wrapper re-declares the full surface: 1,618 wrapper lines over 1,958 core lines (~0.8× facade tax) | §6.1 |

The design below makes the *allocation* axis — the axis the mission names — cost **one alias
line** per variant, makes the ownership and capacity axes cost one thin pinned extension each,
and leaves only the semantic algorithm (62 lines for a binary heap) as irreducible. That is the
acceptance gate passed.

### 1.2 Why this is newly possible (the unblocking fact)

The variant-spelling half of this design was **inexpressible on Swift 6.3.2**: namespaced and
value-generic generic typealiases crashed the frontend (SIGSEGV; the recorded blocker for
tree-n/tree-keyed variant spelling, `Audits/` bug-catalog lineage), which is why the prior
program could only choose between hand-written variant *types* (the duplication the mission
forbids) and *dissolving the names entirely* (the Round M coda: "capacity is column-composed,
consumer-pulled" — correct algebra, no spellable names). On 6.3.3 the crash is **fixed**:
`Experiments/adt-tower-walls` probes p1/p1b/p2/p2b/p3 all compile and run — generic aliases in
namespaces, value-generic aliases (`let n: Int`), aliases nested in generic types mixing outer
and inner parameters, extension-through-alias, and **enforced** where-clauses on aliases
(p3c-enforce: `AliC<NotEq>` errors; the constraint is real). `Experiments/adt-variant-front-doors`
then proves the full mechanism end-to-end (0-witness, cross-module, `~Copyable` elements). The
2026-06-23 principal directive — "eliminate per-ADT `.Bounded` variant TYPES via one generic ADT
over its buffer (`Stack.Bounded` → typealias)" — was gated on a charter that never ratified;
this document is that ratification, generalized to every variant axis.

---

## 2. The design

Eight decisions, D1–D8, answering Q1–Q8 of the re-derivation charter. Each is stated as the
decision, the first-principles rationale, the prior-art grounding, the in-session proof, and
what it supersedes. §4 carries the same content as normative rule text.

### D1 (Q1) — The ontology: four owners, allocation a Memory sub-axis

**Decision.** The tower is `Memory ⊏ Storage ⊏ Buffer ⊏ ADT` — four owners, each with exactly
one concern, stated as an invariant:

| Owner | Single concern | Invariant (what it MUST NOT know) |
|---|---|---|
| **Memory** | *Where bytes live* — placement + allocation strategy (heap, inline, small-spill; allocator disciplines Arena/Pool as `Memory.Allocator.*`) | element-free: no element type, no count, no initialization state, no collection layout (`Memory.Region` = `base` + `capacity` only) |
| **Storage** | *Typing + liveness* — lifts raw bytes to typed `Index<Element>` slots; owns the initialization ledger and the **deinit oracle** | no geometry: no order, no front/back, no growth policy |
| **Buffer** | *Geometry* — the discipline (linear, ring, slab, linked, slots) + the logical `Header` (count, cursors) + growth execution. Present exactly where geometry is a SEPARATE concern: identity-geometry storage disciplines (Generational — handle-addressed) yield lawful storage-direct columns with no Buffer owner | no semantics: no LIFO/FIFO/priority/associative laws, no consumer conformances |
| **ADT** | *Semantics* — the abstract-data-type contract and consumer surface; the ownership-column choice (move-only vs `Shared` CoW) | no storage mechanism: reaches its column only through the seams the column conforms |

Allocation is a **sub-axis of Memory**, not a fifth layer: `swift-memory-allocation-primitives`
is a Memory-tier package; a conformer depending on the seam it adopts is the correct direction
(re-verified in the 2026-06-22 layering audit, Q1 PASS). The 5-layer spelling
(`Memory → Allocator → Storage → Buffer → ADT`) from the 2026-06-08 findings report is
superseded (it already was, by the harvest ledger; this ratifies it).

**Why four and not three.** The two merge candidates fail on independent-variation grounds:

- *Storage+Buffer merge*: the two vary independently — the ONE `Storage.Contiguous` /
  `Store.Protocol` seam serves the Linear, Ring, Slab, and Slots disciplines with the
  initialization ledger, the deinit oracle, and the unsafe core written once (verified live:
  `.Contiguous<` references in the discipline packages — linear 73, ring 90, slab 15,
  slots 12); merging Storage into each discipline re-multiplies exactly that shared core.
  The measured pre-seam state is the cost exhibit: the linear algorithm copied across a
  `{Heap,Inline} × {Copyable,~Copyable}` 2×2 — 35 files referencing `Storage.Heap`, 11
  `Storage.Inline`, 0 storage-generic (`swift-buffer-primitives/Research/storage-generic-buffer-core.md:17-23,47`,
  verified 2026-05-24) — evidence for A GENERIC SEAM BELOW GEOMETRY (≥2 owners), with the
  four-vs-three discrimination carried by the live seam-sharing fact above.
- *ADT directly on Storage*: where geometry is a separate concern, skipping the Buffer owner
  makes every ADT re-implement it (ring wraparound, dense-prefix shifts); `Array`/`Stack`/`Heap`
  all ride Linear and `Queue`/`Deque` ride Ring precisely because geometry is shared one layer
  below semantics. Where a storage discipline's geometry is IDENTITY (Generational:
  handle-addressed slot access is the whole geometry), the storage-direct column is the lawful
  shape — `SlotMap` rides `Storage<Memory.Allocator<Memory.Heap>.Pool>.Generational<E>` with no
  Buffer wrapper, and wrapping it would be ceremony (the archived `Buffer.Arena` was exactly
  that ceremony). The Buffer owner exists where geometry exists.

**Why not fewer concerns per owner.** The element-free Memory floor is what makes allocation
variants free (D4): because `Memory.Heap`/`Memory.Inline<n>`/`Memory.Small<n>` differ only in
placement, one `Storage.Contiguous<Memory.Allocator<R>>` lifts all of them, and one buffer
discipline serves all three. Every typed concern stranded on the Memory floor is a defect with
a cost already measured (the memory⇄storage package cycle F1, root-caused to
`Memory.Tracked.Protocol`; dispositioned in §9.6).

**Supersedes**: the 5-layer spelling; `tower-five-layer-findings-report.md`; the pre-June
"Memory owns typed Contiguous/Inline" scope statement (2026-05-22). Confirms: the 4-owner basis
of `REPORT-layering-harvest-ledger.md` + the 2026-06-22 audit + [MOD-PLACE] canon — reached here
independently from the variation-argument, not inherited from the audit.

### D2 (Q2) — The genericity axis: one column parameter, bound-free carrier, hoisted

**Decision.** Every tower container is a thin **carrier**, generic over exactly one parameter —
its **column** (the buffer stack it sits on) — with the parameter bound `~Copyable` **only**:

```swift
/// Hoisted per [API-IMPL-009]/[PKG-NAME-006]; the public spelling is the front-door alias (D4).
@_documentation(visibility: public)   // symbolgraph-extract drops __-prefixed decls otherwise
@frozen
public struct __Array<S: ~Copyable>: ~Copyable {
    @usableFromInline
    package var column: S
    @inlinable public init(column: consuming S) { self.column = column }
    @inlinable public consuming func take() -> S { column }
}
extension __Array: Copyable where S: Copyable {}
extension __Array: Sendable where S: Sendable & ~Copyable {}
```

A **column** is a value of the composed stack — `Buffer<Storage<Memory.Allocator<M>>
.Contiguous<E>>.D` for a Memory leaf `M` and buffer discipline `D`, a storage-direct
`Storage<Memory.Allocator<M>.Pool>.Generational<E>` for identity-geometry disciplines, or
`Shared<E, that>` for the CoW ownership column. The carrier's capabilities attach by **conditional extension keyed on the
seams the column itself conforms** (D3): observability and element access over
`S: Store.Protocol & Buffer.Protocol`; construction and growth over allocation-generic pins
(D4.3). The ADT "rides the column": it calls the column's own operations and the seams' slot
transitions; it never reaches *past* anything, because the column **is** the buffer stack — the
V1-vs-V2 "reach past the buffer to storage" question dissolves once the seams are conformed by
the column value the ADT actually holds.

**Why the column and not the element.** An element-generic concrete ADT (shape E — today's
`Stack`, `Heap`, `Slab`…) hard-codes its storage, so every allocation variant is a new type with
a duplicated surface: this is the measured in-tree cost (`Heap` 2,676 LOC and its variant family
deleted as unaffordable; Rust `SmallVec` ~2.6–3k lines + 4 memory-corruption CVEs in duplicated
grow paths). The column axis makes the variant a *type argument*, so the surface is written once.

**Why the column and not the storage.** The storage axis (V1's premise) skips the geometry
owner: the ADT would re-implement discipline logic per family. The in-tree shape-S ADTs already
bind columns in practice — their `S` *is* a buffer stack satisfying both seams — the V1 defect
was never the axis' identity but (a) the capability bound welded onto the type and (b) the
`Memory.Heap`-hardcoded op pins (D4.3).

**Why the bound lives on extensions, not the type.**
1. A bound-free carrier admits columns that satisfy only part of the seam set (a keyed tree
   column is not slot-shaped; GATE-1 verified one `Container<S: ~Copyable>` carrying slot,
   ordinal-child, and keyed-child capability families, 0 `witness_method`, 2026-06-18).
2. [MEM-COPY-018] (F-4 wall, re-affirmed 6.3.2): conditional conformances cannot derive through
   same-type method pins — but they derive fine through `where S: Copyable` on a bound-free
   parameter. The `Copyable`/`Sendable`/`Equatable` chains "flow from the column" only if the
   type doesn't over-constrain `S` first.
3. Composition, not refinement: the bound-on-type welds every present and future capability into
   the ADT's identity; bound-on-extension keeps capability protocols deletable conveniences
   ([API-IMPL-023]).

**Consumer surface.** The column axis never reaches consumers: the canonical spelling and every
variant are front-door aliases (D4.2). The empirical leak today is minimal but real — exactly one
L2/L3 site writes a full column spelling (`swift-json`'s local
`SmallByteArray = Array<Buffer<Storage<Memory.Allocator<Memory.Small<24>>>.Contiguous<Byte>>.Linear>`)
— and it exists *because* the library provided no name. D4 makes the library provide the names.

**In-session proof**: `Experiments/adt-variant-front-doors` (synthetic, mechanism);
`Experiments/adt-tower-worked-example` (real upstream, end-to-end). **Supersedes**: [DS-025]-V2's
"rides `Buffer.Protocol` element ops" prose — the real `Buffer.Protocol` deliberately carries no
element ops (its doc: "capability, NOT an op-dispatch surface"), so V2-as-specified was written
against a protocol that does not exist; this is the resolved form of that discrepancy (§8.2).
**Confirms** (independently): the thin-carrier shape of `Tree<S>` (b09726a) and [DS-025]'s
bound-free clause.

### D3 (Q3) — The capability model: minimal orthogonal seams, additive consumer protocols

**Decision.** The protocol surface below the ADT tier is exactly:

| Seam | Requirements | Role |
|---|---|---|
| `Store.Protocol` (`__StoreProtocol`) | `capacity`, `subscript(slot:) { get set }` (witnessed `_read`/`_modify`), `initialize(at:to:)`, `move(at:)`, `unshare()` (defaulted no-op) | the generic cross-module **mutate seam**: slot-typed element access + the two init-state transitions + the CoW gate |
| `Buffer.Protocol` (`__BufferProtocol`) | `count: Index<Element>.Count` **(CONCRETE — M7 deletes the `associatedtype Count`; `Element: ~Copyable` is the only associated type left)**, `isEmpty` (defaulted, now UNCONSTRAINED — concrete `Index<Element>.Count` surfaces `==`/`.zero`, resolving W18) | the logical **observability seam** |
| `Store.Ledgered.Protocol` | one settable-ledger member over `Store.Protocol` | the **one permitted refinement** (non-prefix occupancy sync for ring/sparse columns); its dissolution review remains a Round-C item, inherited unchanged |
| `Span.Protocol` / `Iterable` | (unchanged, orthogonal) | bulk read surface / borrowing iteration — composed, never refined into the seams |

plus, per ADT family, an **additive consumer protocol** `X.Protocol` (hoisted `__XProtocol` +
namespace alias per [API-IMPL-009]): the carrier conforms conditionally
(`extension __Array: Array.Protocol where S: …`), the column never conforms it. `X.Protocol`
earns its weight as the generic-consumer surface ("any array-shaped thing, any column") and as
the conformance anchor for cross-family algorithms; GATE-1 verified the shape at 0 witness cost.

**No per-discipline op protocols** (no `Ring.Protocol` carrying pushBack/popFront, etc.). This
re-derives Ruling 12 (2026-06-13) from present evidence rather than inheriting it:
1. Hot ops through protocol-Base accessor machinery need `@inlinable` to specialize, and the
   `@inlinable` + `~Copyable` `Property.Inout` borrow-init path is the documented release
   miscompile (swift#81624). Plain generic op METHODS over the seams specialize fully **where
   their bodies are visible** — same module or `@inlinable` (every 0-witness receipt —
   `storage-protocol-specialization`, GATE-1, the walls A-probe, the worked example — carries
   `@inlinable`); a NON-inlinable generic module hop re-introduces witness dispatch
   (panel-measured: 29 `witness_method`, 139–714× on element ops). Hence [DS-025]/[DS-029]
   REQUIRE `@inlinable` on public tower ops; the #81624 caveat binds the accessor machinery,
   not plain `@inlinable` op methods (all receipts clean).
2. F-4: `Shared` would need a hand conformance per discipline protocol — bounded but recurring
   cost with no consumer pull today.
3. Typed-throws capacity divergence (growable `push` never throws; bounded `push`
   `throws(Overflow)`) is *expressible* through an associated `Overflow` error with
   `Overflow == Never` call sites needing no `try` (probed 2026-06-23) — so the protocol route
   stays AVAILABLE if consumer pull ever demands it, and is banked in §8.6, not adopted.
Every seam remains a deletable convenience per [API-IMPL-023]: canonical spellings stay concrete;
existentials are forbidden.

**Suppression posture**: every capability protocol suppresses `~Copyable` *and* `~Escapable`
(`Comparison.Protocol` and `Buffer.Protocol` already do); associated `Element: ~Copyable` rides
`SuppressedAssociatedTypes` on 6.3.3 and becomes SE-0503 (default-on, Swift 6.4) at the
SCHEDULED 6.4 floor (§9.7). Protocol-vended borrowing access to `~Copyable` elements through `{ get set }`
requirements witnessed by `_read`/`_modify` is re-proven on 6.3.3 cross-package (walls probe A:
borrow + in-place `_modify` mutate pass; whole-value `+1` extraction is rejected at SIL —
"noncopyable 's.subscript' cannot be consumed…" — which is exactly the seam contract,
compiler-enforced).

**Supersedes**: the withdrawn occupancy-protocol shapes (`Store.Sparse`, the
`Store × Occupancy` conjunction — both already withdrawn 2026-06-08, now ledgered); the
2026-05-25 "hot mutating ops stay concrete-Base `Property.Inout`" ruling *as a universal* — it
remains correct for the accessor-machinery surface, and is narrowed here: seam-generic op
*methods* are proven zero-cost and are the primary op form (the worked example's `pop()`).

### D4 (Q4) — The variant algebra: variants are column points; names are aliases

**Decision.** A variant is a **point in column space**, never a hand-written type. The algebra
has four orthogonal axes, each owned by the layer whose concern it is (D1):

| Axis | Values | Owner | Declared as |
|---|---|---|---|
| **allocation placement** | `Memory.Heap` / `Memory.Small<n>` (via `Storage<Memory.Allocator<·>>.Contiguous`) · inline: the fused, allocation-independent `Store.Inline<E, n>` leaf (seat ruling 2026-06-09) | Memory (heap/small); Store tier (inline) | the leaf inside the column spelling; inline columns compose `Buffer<Store.Inline<E, n>>.D` |
| **capacity contract** | growable / `Bounded` (typed `Overflow` on growth ops) | Buffer | the column's discipline variant (`….Linear` vs `….Linear.Bounded`), never a sibling ADT type |
| *(discipline — a FROZEN per-family coordinate, NOT a variant axis)* | Linear / Ring / Slab / Linked / Slots (Buffer tier) · Generational (Storage tier, storage-direct) | Buffer, or Storage for identity-geometry disciplines | fixed by the family's semantics (`Array`→Linear, `Queue`→Ring, `SlotMap`→Generational); a DIFFERENT discipline under the same semantic surface is a SIBLING family (`Queue.Linked`), never a variant |
| **ownership** | move-only direct (default) / `Shared` CoW | ADT-column boundary | wrapping the column in `Shared<Element, _>` |

**D4.1 The variant/sibling discriminator (panel-hardened to an ordered, mechanical test).**

> A family member is a **VARIANT** iff it is a re-parameterization of the SAME carrier along
> the three FREE axes only — **allocation, capacity, ownership** — with the SAME op layer
> modulo the two DECREED op forms of [DS-029] (`throws(Overflow)` growth pins for bounded;
> `Shared` gate twins for ownership). Everything else is a **SIBLING**: a different discipline
> (`Queue.Linked`), a different key/order model (`Set.Ordered`, `Dictionary.Ordered`,
> `Tree.N`/`Tree.Keyed` columns), a different end-surface (`Queue.DoubleEnded`).

Two clarifications the earlier prose left ambiguous: (a) the bounded push's typed `Overflow`
is a decreed op FORM under this test, not a law difference — so `Stack.Bounded` is a VARIANT
(capacity axis) even though its push throws; (b) "alias" has two marked senses — a **variant
alias** re-parameterizes the same carrier ([DS-028]); a **nest alias** merely names a SIBLING's
canonical member under the family namespace (`Queue<E>.Linked` naming the `__QueueLinked`
carrier's canonical front door). Siblings keep their own packages and carriers (D7); only
their nest aliases live on the parent family's carrier.

**D4.2 How a variant is declared — the front doors.** The canonical type is a top-level
**generic-instantiation typealias** pinning the default column (the sanctioned [API-NAME-004]
exception: it localizes a specialization decision); each variant is a **constrained nested
typealias** on the carrier that re-parameterizes the column, inheriting `Element` from the
family member it is named on:

```swift
/// CANONICAL — the growable heap-allocated array.
public typealias Array<E: ~Copyable> =
    __Array<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>

extension __Array where S: ~Copyable, S: Store.`Protocol` {
    /// VARIANT — inline budget `n` bytes, spilling to heap.
    public typealias Small<let n: Int> =
        __Array<Buffer<Storage<Memory.Allocator<Memory.Small<n>>>.Contiguous<S.Element>>.Linear>
}

// Consumer spellings — [API-NAME-001]-clean, zero forwarding, zero runtime cost:
var a = Array<Int>()                 // canonical
var s = Array<Int>.Small<24>()       // allocation variant, THROUGH the canonical alias
```

`Array<Int>.Small<24>` resolves via the canonical alias to the carrier instantiation
`__Array<…Memory.Small<24>…>`; the alias chain fully specializes (0 `witness_method` in the -O
cross-module client SIL, `adt-variant-front-doors`); conformances, inits (including
value-generic pins), and `~Copyable` elements all flow through it (proven end-to-end). Under
[API-IMPL-005]/[API-IMPL-006] a production variant is one file (`Array.Small.swift`) holding one
alias — the 3-line marginal cost of §1.1. Which variants exist per family stays
**consumer-pulled** (the dissolution doctrine's substance is retained); what changes is the
price of pulling one.

**The alias-declaration discipline (panel-hardened).** A naive alias body that REBUILDS the
column from `S.Element` silently RESETS the other axes when chained (probed:
`Vector<Int>.Shared.Small<8>` == `Vector<Int>.Small<8>` — the Shared axis dropped without a
diagnostic). Front doors therefore follow three laws:

1. **Axis-CHANGING aliases** (allocation: `Small<n>`, `Inline<n>`) are declared in extensions
   constrained to DIRECT canonical columns via the `Direct` marker (a **load-bearing** seam type,
   NOT a deletable convenience — M4, 2026-07-03: it is the axis-drop fence itself, §4.7
   [API-IMPL-023]; SPLIT HOME per the hoist idiom: the PROTOCOL `__ColumnDirect` homes in Store
   Protocol Primitives, with a seam-tier public typealias `Store.Direct` (= `__ColumnDirect`)
   alongside it — in-tower conformance/where-clauses bind `Store.Direct`, so NO dunder token ever
   appears in a public conformance clause (M4, superseding the SEAT's 2026-07-02 "in-tower
   plumbing binds `__ColumnDirect` directly" ruling; recorded in §10); the buffer disciplines are
   low enough to conform; the consumer-facing `Column.Direct` SPELLING homes in the column
   vocabulary as `extension Column { public typealias Direct = __ColumnDirect }`; conformed by the
   buffer stacks and storage-direct columns, NOT by `Shared` or bounded instantiations) — a
   cross-axis chain that would silently reset an axis becomes a compile error.
2. **Axis-ADDING aliases** are column-PRESERVING transformers: `Shared` wraps `S`
   (`typealias Shared = __X<Shared<S.Element, S>>`); `Bounded` maps through a **capacity-twin
   associated type** (`Buffer<S>.Linear`'s nested `.Bounded` witnesses the `Bounded` requirement in
   its own generic context — expressible today — and `Shared` forwards it conditionally), so
   every §5.1 product point, including the live `Shared×Bounded` ring column
   (`Queue+Columns.swift:76`), has a correct, order-insensitive spelling.
3. **The units rule**: `Small<n>` is a BYTE budget (`Memory.Small`'s n); `Inline<n>` is an
   ELEMENT count (`Store.Inline`'s n) — stated in every alias doc comment. Element-count
   small semantics are INEXPRESSIBLE under the ratified algebra (no type-level arithmetic,
   W10-adjacent); the parked `Store.Small<E, k>` item is the designated road if a consumer
   pulls it.

**D4.3 Ops are never per-variant: the allocation-generic pin.** Operations that need the
column's own surface (construction, growth) are written once per (family × discipline ×
ownership), generic over the allocation:

```swift
extension __Heap where S: ~Copyable {
    @inlinable
    public mutating func push<E: ~Copyable & Comparison.`Protocol`, Resource: Memory.Growable & ~Copyable>(
        _ element: consuming E
    ) where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        column.append(element)                       // the column's own R-generic append
        // Restore the heap invariant from the newly-appended tail. Op bodies derive
        // the seed through the TYPED count (Count → Index via `.map { Ordinal() }`),
        // descending to Int only via `Int(clamping:)` where heap arithmetic genuinely
        // needs it — NEVER the reach-through `Int(count.underlying.rawValue)` (a tier-5
        // double-unwrap, [CONV-016]) or `Int(bitPattern:)` (§4.7 [conversions] rider).
        siftUp(fromLastOf: count)                     // typed count in; helper clamps internally
    }
}
```

> **Op-body index hygiene (M6, ratified 2026-07-03).** The seam count is typed
> (`Index<Element>.Count`); the two DECREED descents to raw `Int` in an op body are (i)
> `count.map { Ordinal() }` / typed arithmetic for a bound, and (ii) `Int(clamping:)` for the
> residual arithmetic seed a raw loop genuinely needs. The reach-through
> `Int(count.underlying.rawValue)` (which the W2 heap pilot still carries at
> `Heap.swift:176,207`) and `Int(bitPattern:)` are FORBIDDEN in op bodies. This is the
> [conversions] rider below; the pilot is corrected on its branch and re-gates in full.

This is the shipped `Buffer.Linear` pattern (`append<Element, Resource: Memory.Growable>` —
"pinned to the column over ANY `Resource: Memory.Growable`"; `swift-json` consumes it over
`Memory.Small<24>` in production) promoted to law. `Memory.Inline` correctly does not conform
`Memory.Growable`, so growth ops do not exist for inline columns — by construction, not by
duplication. Ops expressible over the seams alone (removal, in-place mutation, observation,
iteration hooks) are written once, fully generic, CoW-correct via `unshare()`
(the worked example's `pop`).

**D4.4 The capacity axis.** `Bounded` lives at the buffer (`Column.Bounded` with `Header`
capacity + typed `Overflow`), matching live code and the bounded-discipline algebra; the
[MOD-PLACE-DECOMPOSE] "capacity at Memory" spelling is superseded for the *contract* half —
Memory owns the placement bytes, the Buffer owns the overflow contract (the observable law).
ADT-level bounded front doors are aliases to bounded columns plus one thin `throws(Overflow)`
growth pin — a DECREED op form under the D4.1 test (typed overflow does not make bounded a
sibling); the surviving hand-written `Stack.Bounded` and `List.Linked.Bounded` types migrate
to exactly that (the 2026-06-23 principal directive, executed by §9).

**D4.5 The ownership axis.** `Shared<Element, B>` is the one CoW column (F-4 keeps its declared
seam bounds load-bearing). Seam-expressible ops are CoW-correct for free through
`unshare()`; column-surface ops (growth) take one thin gate twin per op
(`store.withUnique { … }`). The `Shared` front door is an alias like any other variant.

**Prior-art grounding** (§6): this is the `heapless` shape (storage-parameterized core +
typealias front-doors + capacity-in-the-storage-type — the shipping Rust counterexample that
neutralizes the Store-RFC layout objection, since `Memory.Inline<n>`/`Memory.Small<n>` carry
their budget in the type, costing zero stored words), reached where C++/stdlib/Zig could not go
because Swift's enforced constrained aliases + value generics + suppressed-conformance generics
did not exist in those systems' decision windows. The stdlib's separate-named-types answer
(`InlineArray`/`RigidArray`/`UniqueArray`) is honored at the *naming* layer — variants have real
names — while its facade-duplication bill (~0.8× per wrapper) is eliminated because our names
are aliases, not wrappers.

**Supersedes**: [DS-002]/[DS-003]'s variant tables (they describe deleted or never-built
types); the W4/W5 "`Array.Small` never exists" ruling (its *substance* — no hand-written variant
types — is kept; the *name* returns as an alias, which the 6.3.2 crash made impossible when the
ruling was made); the shelved bare-`Array<Int>`-façade analysis (it evaluated a wrapper with
~4.3 ns/op dispatch and an arity collision; the alias has neither — §8.4).

### D5 (Q5) — Occupancy lives in the leaf: re-derived, AFFIRMED

**Decision.** Liveness + teardown live in the **single-allocation leaf** (the Storage tier's
concrete discipline over its Memory leaf), never in the buffer. Re-derivation from the walls,
independent of the 2026-06-07 ratification:

1. Wall 1 (SE-0427, by design, mirrored by Rust E0184/E0367): a `deinit` forces unconditional
   `~Copyable` — so wherever teardown lives is permanently move-only. Placing it in the GENERIC
   buffer forces every buffer instantiation move-only AND (per occupancy-encoding-4, Lemmas
   II.2/II.3 plus the located `Buffer.Slab` header-ledger bug, W14) cannot be made correct for
   buffer-held occupancy anyway; placing it in the single-allocation LEAF matches the copyability
   function of §5.3 (leaves move-only or class-backed; `Copyable` enters only at `Shared`). The
   16-cell satisfiability matrix is computed UNDER the leaf placement and holds in every cell
   but one: cell 14 {inline × sparse × value-semantics × no-niche} is the unique exclusion, by
   the SE-0427 law itself (Theorem II.5), collapsible only by a conditional-deinit language
   feature — the buffer placement was retired BEFORE the matrix (AX-4), on the lemmas and the
   W14 bug, and its cost exhibit is the deleted concrete carve-out types of the pre-June state.
2. The information floor: dense-prefix liveness is Θ(log N) (achieved exactly by
   `Store.Initialization`'s range ledger); arbitrary liveness is N bits (the bitmap); the niche
   law makes `Optional`-as-slot cost 0 marginal bits when ξ(E) ≥ 1. These are leaf-shaped
   facts — a buffer-held oracle re-encodes them one level up with a `deinit` it cannot have.
3. Empirical: the `InlineArray`-in-class-field DSE miscompile killed the buffer-owned inline
   occupancy shape outright (writes elided under -O; dossiered in swift-institute/Issues).

No occupancy *protocol* exists (the 2026-06-08 revision stands): occupancy is concrete leaf
state (range ledger / bitmap / free list / generation), synchronized outward only via
`Store.Ledgered` where a non-prefix discipline needs it.

**Supersedes**: cleave-6's "occupancy IS the buffer layer" (already reversed); the sparse-inline
hard-floor carve-outs (already dissolved). **Confirms**: [DS-023] verbatim.

### D6 (Q6) — Copyability, sendability, escapability

**Decision.**
- **Move-only substrate, copyability flows from the column**: carriers and columns are
  `~Copyable`; `extension X: Copyable where S: Copyable`; the only `Copyable` columns are
  `Shared` CoW columns (`Copyable` exactly when `Element: Copyable` — the S5 chain). CoW enters
  ONLY at the `Shared` column; the drain-box rule [MEM-SAFE-028] governs its box (the 6.3.2 -O
  devirtualized-destroy/deinit-omission family — `cow-box-deinit-omission-miscompile`, R-6 —
  makes drain-in-class-deinit the only safe shape; RE-PROBED 2026-07-02 on 6.3.3: STILL
  PRESENT — 5 shapes skip the user deinit at -O, the drain shape alone is safe).
- **Sendability flows from the column**: `extension X: Sendable where S: Sendable & ~Copyable`;
  leaves justify `@unchecked Sendable` by exclusive ownership; `sending ≠ uniqueness` stands —
  region disconnection is not refcount uniqueness, so the CoW gate remains a runtime check.
- **Escapability**: capability protocols suppress `~Escapable` today (free, shipped). Carriers
  remain `Escapable` on 6.3.3: the suppressed-carrier shape (`__X<S: ~Copyable & ~Escapable>:
  ~Copyable, ~Escapable` + conditional re-conformances) compiles and runs ONLY behind
  `-enable-experimental-feature Lifetimes` + `@_lifetime(copy column)` (walls probe p13: bare
  6.3.3 rejects it — "the '_read' accessor cannot return a ~Escapable result"). The carrier
  widening is a **recorded non-breaking trigger**: adopt when (a) the first nonescapable column
  materializes, or (b) `@_lifetime` ships un-flagged — whichever first. Owners otherwise stay
  `Escapable` (the 2026-02-28 boundary decision, re-affirmed: `~Escapable` is the view tier's
  concern — `Span`/`Property.View`).
- Wall 2 (swift#86652) **persists on 6.3.3, asymmetrically**: the naked cross-package
  `@_rawLayout` store leaks in DEBUG (0/2 deinits) and destroys correctly in release (walls
  probe C) — the value-witness misclassification is bypassed by release specialization only.
  The `[MEM-SAFE-027]` `_deinitWorkaround` therefore remains REQUIRED on every `@_rawLayout`
  leaf (probe B: 2/2 both modes). `InlineArray` with a same-module element destroys correctly
  in both modes (p12).

### D7 (Q7) — Packaging: canonical-in-main; variants are aliases in-main; siblings get packages

**Decision.** [DS-027] re-derived with one substantive change:

1. **Canonical-in-main** (kept): `swift-X-primitives` holds the canonical family — the hoisted
   carrier, the seam-generic ops, the canonical front-door alias, and the **allocation/capacity/
   ownership variant aliases** (each its own file per [API-IMPL-005]). A package per 3-line
   alias fails every modularization test; variant aliases are not packages. Heavy-leaf variant
   aliases (whose column leaf is outside the canonical target's closure) get their own TARGET +
   product in the same package, umbrella-re-exported — the [DS-027].1 rider — keeping lean
   consumers lean.
2. **One-SIBLING-per-package** (replaces one-variant-per-package): semantic siblings
   (`Set.Ordered`, `Queue.DoubleEnded`, `Queue.Linked`, `Dictionary.Ordered`, tree columns)
   keep their own packages — they are distinct contracts with real op layers. The prior rule's
   examples were all siblings; its *word* ("variant") is what this corrects.
3. **One storage-seam package** (kept): `swift-storage-primitives` holds the seam target
   (minimal, index-only deps) + `Storage.Contiguous`; `swift-storage-generational-primitives`
   holds the sparse generational discipline (the executed P1 rename); no `.Tracked` tier
   (dissolved; its Memory-tier residue is a §9.6 deletion).
4. Buffer discipline packages unchanged (`swift-buffer-{linear,ring,slab,linked,slots}-primitives`
   under the `swift-buffer-primitives` seam/namespace package).

End-state count: 36 live tower packages today → **34** after §9.6 (no new packages required by
this design; two deletions, zero splits). Every variant the catalog re-grows arrives as files
in existing packages.

### D8 (Q8) — Mechanical enforcement

**Decision.** Status is checked, never eyeballed:

1. **The conformance predicate** (replaces [DS-026]'s): a family is AT-TARGET iff
   (a) its carrier's column parameter is bound `~Copyable` only — no capability-protocol bound
   on the type, direct or inherited; (b) capability extensions constrain only seams/pins on `S`
   itself (no associated-type reach-through in ADT op extensions); (c) a canonical front-door
   alias exists, and every variant alias resolves to the same carrier; (d) no two op extensions
   differ only in the Memory leaf of their pins (the allocation-generic check); (e) every
   public tower op is `@inlinable` and every hoisted decl carries
   `@_documentation(visibility: public)`. Encoded by
   re-pointing `Scripts/adt-decoupling-classify.py` (predicate + registry + fresh ledger at wave
   W0, §9.1); promoted to a swift-linter AST rule per lint-rule-promotion at W4 — the recorded
   "AST linter unrunnable (binary-parser closure lag)" blocker is CONTRADICTED at the
   rules-bundle level (swift-primitives-linter-rules builds clean, 90.2s, zero binary-* deps;
   verified 2026-07-02). The RUNNER's recorded failure was its ~4000-module full-closure run
   (a consumer-catch-up class, ledgered to Round C) plus a 5-commit pin lag — so the W4
   promotion scopes the runner to the tower packages and refreshes the pin; full-closure
   health stays a Round-C item, not a promotion blocker.
2. **The seam-ledger laws** [DS-024] (kept verbatim): every new column runs
   `Seam.Ledger.violations(makeEmpty:element:)` from its own suite — the count contract the type
   system cannot express (Wall 8).
3. **Existing tower lint rules** (kept): `FrozenTowerType` ([API-IMPL-022]) and `CloneLessBox`
   ([MEM-COPY-019]) — both enforce rules this design retains; the FrozenTowerType fixture
   already tracks the surviving tree shape.
4. **Benchmark guardrails**: the family baselines (§9.5) gate every reshape wave.

### D9 (Q9) — The iteration contract: iteration flows from the column (borrowing `forEach`), 0-witness

**Decision.** The ADT tier defines NO iteration of its own. A tower container is iterable exactly
when its column vends borrowing iteration; iteration **flows from the column** — composed over the
buffer-tier surface, never refined into the seams (D3), never re-implemented per family. The
guaranteed common surface is a **borrowing `forEach`** lending `(borrowing S.Element)` — the one
surface every occupancy discipline provides.

**The borrow/consume boundary.** A `~Copyable` column is **borrow-iterable only**. The consuming
`Sequenceable` path is `Element: Copyable`-gated on both Linear and Ring
(`Buffer.Linear+Sequenceable.swift:14`, `Buffer.Ring+Sequence.Protocol.swift:18`): a move-only
element can be borrow-iterated but never consume-iterated (consuming iteration would move each
element out — structurally unavailable, the multipass/single-pass orthogonality of
`Iterable.swift:24-34`). So "iteration over a `~Copyable` column" means **borrow**-iteration —
mirroring the `min`-vs-`pop` boundary in [DS-025] (a `~Copyable` borrow of `Element?` is
structurally unavailable, so borrowing accessors keep precondition gates while consuming ops vend
`Optional`).

**The Linear/Ring asymmetry (load-bearing — why the contract is stated over `forEach`, not
`Iterable`).** The two disciplines are NOT symmetric on the *protocol-vended* surface:
- **Linear** ALSO vends the multipass `Iterable` protocol, element gate relaxed to `~Copyable`
  (`Buffer.Linear+Iterable.swift:22`).
- **Ring** vends ONLY the single-pass bespoke borrowing `forEach` (`Buffer.Ring+forEach.swift`).
  Its multipass `Iterable` side was **active-pruned** (seat-ruled 2026-06-10,
  `Buffer.Ring+Sequence.Protocol.swift:11-17`); a live multipass ring story re-materializes only
  when a borrowing *segment iterator* is designed against the move-only substrate.

Therefore D9 states the tower iteration contract as **"a borrowing `forEach` over the column"**
(the surface BOTH columns satisfy at 0-witness), NOT the multipass `Iterable` protocol — stating
it over `Iterable` would overstate Ring. A family MUST NOT claim multipass `Iterable` unless its
column vends it (Linear yes; Ring no, until the segment iterator lands).

**0-witness evidence (spike-verified, real packages).** Cross-module, over a move-only
`Job: ~Copyable`, both Linear and Ring borrow-`forEach` specialize to **zero `witness_method`** on
every executing path. The `-O` consumer SIL carries 4 `witness_method` sites — ALL inside the
retained `@inlinable` generic `Iterable.forEach` template (`public_external`, unreachable from a
concrete client); the three specialized functions the client actually calls (Linear `Iterable`
count, Linear bespoke sum, Ring bespoke sum) hold 0 each. Iteration bottoms out in the concrete
column's `Span.Protocol` span (Linear) / ledger-walked `storage[slot]` subscript (Ring) with no
protocol dispatch — it flows from the column exactly as D3 requires. Evidence: scratch spike
`m11-iteration-0witness` (path-deps the REAL buffer/storage/allocator packages on local mains, as
the ratified worked example does); GREEN + runtime-correct on 6.3.3; promotion to `Experiments/`
is a follow-up.

**W2 implication.** Each family's iteration IS the column's borrowing `forEach`; the ADT adds no
iteration machinery. Families over Linear additionally expose multipass `Iterable`; families over
Ring (and any single-pass column) expose only the single-pass borrowing `forEach` until a
borrowing segment iterator exists. The W2 fan-out inherits this — a family's iteration surface is
READ FROM its column, never declared at the ADT tier.

**Provenance**: §2 D3 (compose-don't-refine); spike `m11-iteration-0witness`;
`Buffer.Linear+Iterable.swift`, `Buffer.Ring+forEach.swift`,
`Buffer.Ring+Sequence.Protocol.swift:11-17` (the 2026-06-10 ring multipass prune);
`Iterable.swift:24-34` (multipass/single-pass orthogonality).

---

## 3. Constraints-compliance table

Every hard empirical constraint × the design's compliance. **Status** is the 2026-07-02 state on
the toolchain of record; probes live in `Experiments/adt-tower-walls` (`W-*` = walls package,
`p*` = single-file probes, receipts in `Outputs/`) unless another experiment is named.

| # | Constraint | 6.3.3 status (probe) | Design compliance |
|---|---|---|---|
| W1 | SE-0427 law: `deinit` ⟹ unconditionally `~Copyable`; no conditional deinit; no experimental flag unlocks it | UNCHANGED, by design (S1–S8 matrix stands; language law, not re-probed) | Teardown lives in leaves (D5); buffers/carriers carry no `deinit`; conditional `Copyable` flows through bound-free parameters (D2, D6) |
| W2 | swift#86652: cross-package `@_rawLayout` deinit skip | **STILL PRESENT, asymmetric** — naked store: 0/2 deinits DEBUG, 2/2 release (W-C); with `_deinitWorkaround`: 2/2 both (W-B); stdlib `InlineArray`, same-module element: 2/2 both (p12) | [MEM-SAFE-027] workaround stays REQUIRED on every `@_rawLayout` leaf; inline columns remain usable cross-package with it; issue open upstream (no fix PR) |
| W3 | Dual-storage IRGen crash (`@_rawLayout` + class-ref field, release) | **FIXED in reduction** — concrete (p8), field-after-rawLayout (p8b), generic-element + class payload (p8c) all pass at -O | Design does not depend on the mixed shape (two-arm enum layouts remain the `Small`-leaf idiom); production-scale re-validation banked at wave W4 ([EXP-020] extrapolation caveat) |
| W4 | Namespaced/value-generic generic-typealias SIGSEGV | **FIXED** — p1/p1b/p2/p2b/p3 all compile+run; extension-through-alias works (p3b); alias where-clauses ENFORCED (p3c-enforce, `Equatable` form; the earlier NOT-ENFORCED read was a Sendable-leniency artifact) | The unblocking fact: the whole front-door mechanism (D4.2) rests on it; re-verified end-to-end in two experiment packages |
| W5 | -O devirtualized-destroy / CoW-box deinit-omission (R-6 family) | **STILL PRESENT** — re-probed in-session on 6.3.3: 5 shapes skip the user deinit at -O; only the DRAIN-box-deinit shape is safe (`cow-box-deinit-omission-miscompile`, revalidated 2026-07-02) | Drain-box rule [MEM-SAFE-028] retained verbatim and re-confirmed; `Shared` is the only CoW column |
| W5a | Borrow-pointer miscompile (`withUnsafePointer(to:)` over `borrowing`/field-of-self, `@inlinable`, release) | **STILL CRASHES** — release run SIGTRAP rc=133 (`borrow-pointer-storage-release-miscompile`, revalidated 2026-07-02); V8 `inout` idiom remains stable | [MEM-SAFE-029] per-access derivation through `inout`/mutating shapes retained; no design surface vends interior pointers from borrows |
| W6 | `_read`/`_modify` required to vend `~Copyable` elements; `borrow`/`mutate` unavailable | CONFIRMED — bare: flag-named error; with flag: "cannot be enabled in production compiler" (p5). SE-0507 is Implemented (Swift 6.4), default-on there. `CoroutineAccessors` flag IS accepted on 6.3.3: struct `read`/`modify` parse; protocol requirements accept `{ read }`/`{ read set }` but not `modify` (p6/p6b) | [API-IMPL-021] retained: requirements `{ get set }`, witnesses `_read`/`_modify`; the SE-0507/SE-0474 rename is a mechanical 6.4-gate item; SE-0507's limits (single return; no pointer projection) mean heap-backed vending keeps coroutines even post-6.4 |
| W7 | Outer-scope suppression refuted: `B.Storage.Element: ~Copyable` clause | STILL REFUTED — identical diagnostic (p4) | Moot under D2/D3: element suppression lives on the seams' associated types; no ADT extension re-suppresses |
| W8 | Seam-ledger contract untypeable | UNCHANGED (type-system fact) | [DS-024] law tests retained per column (D8.2) |
| W9 | Extension-implies-Copyable | CONFIRMED (p7) | Every capability extension spells `where S: ~Copyable`; enforcement stays with the existing sweep discipline + the D8 classifier |
| W10 | No default generic arguments | CONFIRMED (p10); upstream: never reviewed (PR #591 closed 2017, no SE, no active pitch) | The Rust `A = Global` mechanism is permanently unavailable; front-door aliases are the Swift-shaped equivalent (D4.2) |
| W11 | Protocol seam vends `~Copyable` borrows; whole-value get rejected | CONFIRMED cross-package (W-A: borrow read + `_modify` mutate pass; p11 Sema-accepts, p11b SIL-rejects the `+1` extraction — sound) | The seam contract (D3) is compiler-enforced end-to-end; extraction goes through `move(at:)` only |
| W12 | F-4: conditional conformance cannot derive through same-type pins | Inherited (6.3.2, `ASK-F WITHDRAWN` record); not re-probed — no design surface depends on the negative | `Shared` keeps its declared seam bounds; carrier conformance chains key on `S:` bounds, never pins (D2 rationale 2) |
| W13 | #81624: `@inlinable` protocol-Base `Property.Inout` borrow-init miscompile | Inherited (documented); avoided by construction | No protocol-Base accessor machinery in the op layer (D3); seam-generic op *methods* + concrete-Base accessors only |
| W14 | `InlineArray`-in-class-field DSE miscompile (writes elided at -O) | Inherited (dossiered, swift-institute/Issues 2e45aa1) | Buffer-owned inline occupancy is dead (D5); leaves own occupancy; no class box holds a mutable `InlineArray` ledger |
| W15 | §A13 (#89617): vocabulary nested in generic namespaces goes phantom-generic; typed throw across witness asserts at -O | Inherited | Tower vocabulary stays on non-generic nouns via the [API-IMPL-009] hoist ([API-IMPL-023] triple); carriers are hoisted `__X` types, not vocabulary hosts |
| W16 | §A9: generic-extension members over `Storage<…Pool>.Generational` crash in DEBUG | Inherited; 4 suite guards remain (`.disabled(compiler<6.4)`) | Generational-specific; unguard-probe stays a Round-M-W1-inherited item, re-homed to wave W4 (§9.4) |
| W17 | `Memory.Small` value-generic + `@_rawLayout(size:)` needs integer literal | Inherited (probe 5b): `likeArrayOf:count:` accepts value generics; `size:` does not | `Memory.Inline<n>`/`Memory.Small<n>` already use the `likeArrayOf` form; no design surface needs `size:` |
| W18 | Abstract `Count` surfaces `.zero` but not `==` | Inherited (charter-dispatch record) | Observability extensions gate on `S.Count == Index<S.Element>.Count` (the worked example's constraint); sparse-domain columns supply their own `isEmpty` |

---

## 4. Replacement normative rule text

The following text is ready to install in the **ecosystem-data-structures** skill via the
skill-lifecycle workflow, replacing the Decoupling Charter section ([DS-025]–[DS-027]) and
correcting [DS-002]/[DS-003]. Classification: **BREAKING** for [DS-025]/[DS-026]/[DS-027]
(the PROVISIONAL V2 revision is superseded; the packaging law's clause 2 changes);
**Additive** for [DS-028]/[DS-029]. This document is the rationale companion for all five.

### 4.1 `[DS-025]` The Canonical ADT Shape *(replaces the 2026-06-18 text; RATIFIED)*

**Statement**: Every tower container is a thin **carrier** `struct __X<S: ~Copyable>: ~Copyable`
— hoisted per [API-IMPL-009]/[PKG-NAME-006] — generic over exactly one parameter, its storage
**column** (the composed buffer stack, a storage-direct identity-geometry discipline, or
`Shared<Element, _>` over one), with the parameter
bound `~Copyable` **only**: no capability-protocol bound on the type, direct or inherited.

- Capabilities attach by **conditional extension** keyed on what the column conforms:
  observability and slot ops over `where S: Store.\`Protocol\` & Buffer.\`Protocol\``;
  construction and growth by allocation-generic pins per [DS-029]; every extension restates
  `where S: ~Copyable`. **(M7, 2026-07-03: the former `S.Count == Index<S.Element>.Count` pin is
  DELETED — `Buffer.Protocol.count` is now the concrete `Index<Element>.Count`, so the
  element-domain count needs no pin; spike-verified GREEN, see M7 note below.)**
- The public spelling of the family is its **front doors** per [DS-028]; the carrier's hoisted
  name never appears in consumer signatures or `throws` clauses ([API-ERR-007]).
- Every hoisted carrier AND hoisted seam protocol carries `@_documentation(visibility: public)`:
  symbolgraph-extract's underscore filter otherwise drops the entire family API from DocC
  (panel-measured: the worked example's symbol graph = 1 orphan alias, 0 relationships; the
  attribute restores the full graph on the exact carrier shape). DocC curation makes the
  front-door alias page the family landing page. The same hole is LIVE on today's hoisted
  seam protocols (`__StoreProtocol` extracts 0 symbols) — a §9.6 sweep item.
- Conformance chains flow from the column: `extension __X: Copyable where S: Copyable`;
  `extension __X: Sendable where S: Sendable & ~Copyable`; semantic conformances
  (`Equatable`, …) key on `S:` bounds, never on same-type pins ([MEM-COPY-018]).
- `__X<S>` additively conforms its own consumer protocol
  (`extension __X: X.\`Protocol\` where S: …`); the column never conforms `X.\`Protocol\``.
- **Every public seam-generic and column-pinned operation is `@inlinable`** (over the
  `@usableFromInline package` column). This is load-bearing, not style: the tower's topology
  puts generic ops in the library and concreteness in the consumer, so cross-module
  specialization exists only through serialized bodies — the panel measured the §4.1 exemplar
  WITHOUT `@inlinable` at 90.33 vs 0.126 ns/op per element read (714×) from a concrete
  front-door client, with 29 `witness_method` sites in the middle-module SIL.
- Element accessors are `_read`/`_modify` coroutines per [API-IMPL-021]; carriers are `@frozen`
  per [API-IMPL-022]; carriers carry **no `deinit`** (teardown lives in the leaf, [DS-023]).
- The carrier vends exactly the column in/out pair inline — `@inlinable init(column: consuming S)`
  and `@inlinable consuming func take() -> S` — and nothing else structural; every capability is a
  conditional extension (M12).
- Escapability: capability protocols suppress `~Escapable`; carriers stay `Escapable` until the
  recorded trigger (first nonescapable column, or un-flagged `@_lifetime`) — the widening is
  non-breaking.
- **Carrier vs combinator (M9)**: this rule governs CARRIERS — functors `__X⟨−⟩` from storage
  columns (§5.1). A **combinator** whose single parameter is the wrapped ADT rather than a column
  (`__HashIndexed`, `Cache`) has NO column axis; [DS-025] and the [DS-026] predicate do not apply,
  and its classification state is **n-a** (see [DS-026] combinator carve-out).

**Correct**:
```swift
@frozen public struct __Array<S: ~Copyable>: ~Copyable {
    @usableFromInline package var column: S
    @inlinable public init(column: consuming S) { self.column = column }
    @inlinable public consuming func take() -> S { column }
}
extension __Array: Copyable where S: Copyable {}
extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    @inlinable
    public subscript(_ i: Index<S.Element>) -> S.Element {
        _read { yield column[i] }
        _modify { column.unshare(); yield &column[i] }
    }
}
extension __Array: Array.`Protocol` where S: Store.`Protocol` & Buffer.`Protocol` {}
```

**Incorrect**:
```swift
public struct Array<S: Store.`Protocol` & Buffer.`Protocol` & ~Copyable>  // ❌ bound ON the type
public struct Stack<Element: ~Copyable>                                   // ❌ no column axis (variant = new type)
extension Array where B: Buffer.`Protocol` { subscript … }                // ❌ element ops on the observability seam (V2-as-specified — the seam has none)
```

**Status**: RATIFIED 2026-07-02 (this document; the tree-core real-upstream validation the
2026-06-18 revision parked on is discharged by `Experiments/adt-tower-worked-example` — real
columns, cross-module, 0-witness). The storage-generic (V1) and ride-`Buffer.Protocol` (V2)
premises survive in git history and §8 of the rationale companion only.

**Provenance**: `Research/adt-tower.md` (this document) §2 D2–D3; `Experiments/adt-variant-front-doors`;
`Experiments/adt-tower-worked-example`; GATE-1 (2026-06-18, 0-witness capability families).

### 4.2 `[DS-026]` The Conformance Predicate *(replaces the 2026-06-18 text; RATIFIED)*

**Statement**: Whether a family meets [DS-025] MUST be decided mechanically. The predicate:

| Part | Test |
|---|---|
| (a) | the carrier's column parameter is bound `~Copyable` only — no capability-protocol bound, direct or inherited from a parent namespace |
| (b) | capability extensions constrain seams/pins on `S` itself; no extension re-suppresses or reaches through nested associated types |
| (c) | a canonical front-door alias exists, and every variant alias in the family resolves to the same carrier ([DS-028]) |
| (d) | no two op extensions differ only in the Memory leaf of their column pins (the allocation-generic check, [DS-029]) |

Every family is in exactly one state: **at-target** (a–d hold) · **carrier-only** (a–b hold;
front doors or op generalization pending) · **legacy** (a fails: bound-on-type, or no column
axis at all). The predicate is encoded in `Scripts/adt-decoupling-classify.py` (re-pointed at
wave W0 with a fresh ledger; the embedded 2026-06-18 V1-axis LEDGER is void) and is a
swift-linter AST-rule promotion candidate per lint-rule-promotion.

**Combinator carve-out (M9, 2026-07-03)**: a family whose single generic parameter is the
WRAPPED ADT rather than a storage column is a **combinator**, not a carrier — `__HashIndexed`
(the Set/Dictionary index combinator: its index table is derived state, and per §5.1 it is not a
functor `__X⟨−⟩` from `Columns(E)`), in the same class as `Cache`. [DS-025]'s bound-free-COLUMN
law and this predicate's parts (a)–(d) DO NOT APPLY to a combinator; its state is **n-a**. Its
W1 gate is instead: census n-a consistent + composes with the reshaped carriers it wraps
(the reshaped `Set`/`Dictionary`). SEAT ruling 2026-07-02, grounded here in §5.1.

**Pin/predicate reconciliation (M7 / GAP-3, 2026-07-03)**: part (b) forbids an extension that
reaches through a nested associated type; yet the pre-M7 [DS-025] op extensions carried exactly
such a reach-through — `S.Count == Index<S.Element>.Count` — to obtain the element-domain count,
an internal contradiction between two ratified rules. **M7 dissolves it**: concretizing
`Buffer.Protocol.count` to `Index<Element>.Count` deletes `S.Count`, so no op extension reaches
through a nested associated type and part (b) holds cleanly tower-wide.

**[DS-025]/[DS-026] seam amendment (M7 — concretize `Count`; RATIFIED 2026-07-03, SPIKE-GATED →
GREEN).** `Buffer.Protocol` deletes `associatedtype Count` and vends the concrete
`count: Index<Element>.Count` (`Element: ~Copyable` remains its only associated type). Effects:
(i) removes the `S.Count == Index<S.Element>.Count` reach-through pin from every op extension
(§4.1, §2 D3); (ii) resolves §3 **W18** — the unconstrained `isEmpty` default `count == .zero`
now compiles because concrete `Index<Element>.Count` (= `Tagged<Element, Cardinal>`) surfaces
both `==` and `.zero` (this is M7's payoff, not a wall hit). **Conformer cost**: the four slab
witnesses re-tag their `Bit`-domain occupancy into the element domain via the sanctioned in-tree
`.retag(S.Element.self)` (one occupied bitmap slot IS one live element — a phantom-label change,
numerically sound; `Buffer.Slab+Operations.swift:20` already uses `.retag`); the generational
witness is already element-domain (verbatim). **Secondary win**: deleting the
`Count: Carrier.\`Protocol\`<Cardinal>` bound removes `swift-buffer-protocol-primitives`'s direct
imports of `Carrier_Protocol` and `Cardinal_Primitive` (`.zero`/`==` still resolve via
`Index_Primitives`' re-export) — a two-module dep-surface reduction. **Evidence**: scratch spike
`m7-concretize-count`, `swift build` GREEN on 6.3.3 — concretized seam + real atomic-type
packages (index/cardinal/carrier/tagged/ordinal), six conformers + a negative control (a
non-retag slab witness is correctly REJECTED, proving the constraint is load-bearing); promotion
to `Experiments/` is a follow-up. **WAVE GATE (SEAT)**: this proves the DESIGN; the production
seam change additionally requires the same green reproduced against the REAL
slab/slot-map/generational packages before it lands.

**Status**: RATIFIED 2026-07-02. The three-shape taxonomy (at-target / foundational / concrete)
is superseded by the three states above; the 2026-06-18 census (2/9/10) remains historically
correct against the old predicate.

### 4.3 `[DS-027]` The Packaging Law *(clause 2 amended; RATIFIED)*

**Statement**:
1. **Canonical-in-main** *(unchanged)*, with a target-placement rider: `swift-X-primitives`
   holds the canonical family — the hoisted carrier, seam-generic ops, the canonical front
   door, and ALL allocation/capacity/ownership **variant aliases** (one file each per
   [API-IMPL-005]/[API-IMPL-006]). A variant alias whose column LEAF is NOT already in the
   canonical target's product closure (`Small` → Memory Small Primitives; `Inline` → Store
   Inline Primitives) lands in **its own variant target + product** within the package
   ([MOD-031]; the array manifest already scaffolds the "Small type/ops/variant" MARKs), as its
   OWN PRODUCT explicitly imported by variant consumers — NOT folded into the umbrella product
   (SEAT ruling 2026-07-02: umbrella re-export would drag the heavy leaf into every umbrella
   consumer, defeating this rider's entire purpose; the earlier [MOD-005] phrasing was a
   drafting slip) — so heap-only consumers keep a lean dependency graph
   (panel-measured: the in-target shape would push +2 packages onto 7 consumers that never
   spell `Small`).
2. **One-sibling-per-package** *(amends "one-variant-per-package")*: a semantic SIBLING — a
   family member with distinct observable laws (`Set.Ordered`, `Queue.DoubleEnded`,
   `Queue.Linked`, `Dictionary.Ordered`, tree columns) — lives in its own
   `swift-X-Y-primitives`. A **variant** — a column point differing only in the three free
   axes (allocation, capacity, ownership) — is an alias in the canonical package and MUST NOT
   get a package. Discriminator: the ordered D4.1 test (same carrier re-parameterized along
   the free axes, same op layer modulo the [DS-029] decreed forms ⇒ variant; anything else —
   discipline, key/order model, end-surface — ⇒ sibling).
3. **One storage-seam package** *(unchanged)*: `swift-storage-primitives` (seam target minimal,
   index-only deps; `Storage.Contiguous` concrete) + `swift-storage-generational-primitives`
   (the sparse generational discipline). No refinement tiers between seam and concrete
   (`Store.Ledgered` is the capped single exception, Round-C review inherited).

**Status**: RATIFIED 2026-07-02 (clause 2's re-wording is the only change to the
principal-ratified 2026-06-18 law; its examples were all siblings already).

### 4.4 `[DS-028]` The Variant Algebra and Front-Door Aliases *(NEW; RATIFIED)*

**Statement**: A variant is a **point in column space** along the three FREE axes — allocation
placement (Memory leaf / `Store.Inline` leaf), capacity contract (buffer `Bounded`, typed
`Overflow` as the decreed op form), and ownership (`Shared`) — the DISCIPLINE being a frozen
per-family coordinate (a different discipline is a sibling family, [DS-027].2). A variant is
declared as a **typealias**, never a hand-written type:

- The **canonical** family member is a top-level generic-instantiation alias pinning the default
  column: `public typealias X<E: ~Copyable> = __X<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.D>`.
- Every **variant** is a constrained nested alias on the carrier, `Element` inherited from the
  member it is named on — spelled `X<E>.Small<n>`, `X<E>.Inline<n>`, `X<E>.Bounded`,
  `X<E>.Shared` per [API-NAME-001] (variant labels nest) — under a GOVERNING RESTATEMENT LAW
  plus the three alias laws. **Restatement law (M1, ratified 2026-07-03)**: every alias-hosting
  extension MUST restate the carrier's suppression on `S` — `where S: ~Copyable` (and, when it
  also constrains the fence, `where S: ~Copyable, S: Store.Direct`), per [MEM-COPY-004]. A bare
  `extension __X where S: Store.Direct { … }` implicitly re-imposes `S: Copyable` (W9,
  extension-implies-Copyable), making the alias UNREACHABLE from the move-only canonical column —
  the CONFIRMED `Array.Small.swift:27` defect (missing `, S: ~Copyable`; fixed on-branch, one-line
  compile-verified). The W1.6 wave-gate adds a per-family alias-reachability compile-probe from a
  move-only column (compile, not grep). Then the three alias laws: axis-CHANGING aliases
  (allocation) constrain to the `Direct` marker (cross-axis chains error instead of silently
  resetting an axis); axis-ADDING aliases are column-preserving transformers (`Shared` wraps `S`;
  `Bounded` maps the capacity-twin associated type); every alias doc comment states the units rule
  (`Small<n>` = bytes, `Inline<n>` = element count).
- Which variants exist per family is **consumer-pulled**; pulling one costs one alias file.
  Conformances, inits (including value-generic pins), and `~Copyable` elements flow through the
  alias chain with zero forwarding code and zero runtime cost (0 `witness_method`, verified).
- Semantic siblings are NOT variants and NOT aliases ([DS-027].2).
- `.Indexed<Tag>` remains NOT a variant (the tagged-collection rule stands).

**Rationale**: the alias IS the sanctioned [API-NAME-004] generic-instantiation exception; the
mechanism was inexpressible before 6.3.3 (the namespaced/value-generic alias SIGSEGV) — hence
the interim dissolution doctrine, whose algebra this rule keeps and whose missing names it
restores.

**Provenance**: `Research/adt-tower.md` §2 D4; `Experiments/adt-variant-front-doors` (mechanism,
0-witness); `Experiments/adt-tower-worked-example` (real upstream); walls probes p1–p3c
(the alias feature matrix, 6.3.3).

### 4.5 `[DS-029]` Allocation-Generic Operation Pins *(NEW; RATIFIED)*

**Statement**: Tower operations MUST NOT hardcode a Memory leaf. Three op forms exist, in order
of preference:

1. **Seam-generic** (`where S: Store.\`Protocol\` & Buffer.\`Protocol\``): any op expressible
   over slot transitions + count — removal, in-place mutation, observation. CoW-correct via
   `unshare()` before the first write. Covers every column including `Shared`.
   **Gate discipline (M3, ratified 2026-07-03 — formalizes pilot-review F4)**: a public mutating
   op calls `unshare()` EXACTLY ONCE, at entry, before its first write; seam-generic HELPERS
   (`exchange`, `siftUp`, `siftDown`, …) NEVER gate and MUST carry the gating precondition in
   their doc comment ("caller must have gated `unshare()`"). Double-gating and an un-gated helper
   write are both defects. (`unshare()` is the [DS-025] seam requirement renamed from
   `prepareForMutation()` — M3 ships the rule text, the skill rider, and the 42-site code change
   as ONE lockstep arc; a validator or skill still spelling `prepareForMutation` after the wave is
   a defect.)
2. **Allocation-generic pin** (`where S == Buffer<Storage<Memory.Allocator<R>>.Contiguous<E>>.D,
   R: Memory.Growable & ~Copyable`): ops needing the column's own surface (construction,
   growth). One extension covers heap AND small; `Memory.Inline` correctly falls outside
   (`Memory.Growable` is the fence). Bounded columns take the same shape with the bounded
   discipline + `throws(Overflow)` — where `Overflow` denotes the family's OWN nested `Error`
   (a `.full` case; the LANDED per-family shape), NOT a shared tower-wide `Overflow` type (which
   never landed). See §4.7 M10 rider; keep per-family nested `Error`.
3. **Ownership twin** (`where S == Shared<E, …>`): one thin gate-twin per column-surface op
   (`store.withUnique { … }`) — only for ops form 1 cannot express.

All three forms are `@inlinable` ([DS-025]'s visibility requirement — the specialization
property is body-visibility-conditional, not automatic).

A `Memory.Heap`-hardcoded pin where `R: Memory.Growable` suffices is a defect (the [DS-026](d)
check). Buffer-tier public ops follow the same law (`Buffer.Linear.append` is the shipped
exemplar; ring/slab/linked heap-pinned ops are wave-W3 migration items, §9.1).

**Provenance**: `Buffer.Linear+Lifecycle.swift` (the shipped pattern; `swift-json` consumes it
over `Memory.Small<24>` in production); `Experiments/adt-tower-worked-example` §3 (the pattern
at the ADT tier, real columns, both variants).

### 4.6 Corrections to `[DS-002]` / `[DS-003]`

The variant-selection and container-catalog tables are **stale against the tree** (they list
`Queue.Fixed/.Static/.Small`, `Array.Bounded/.Fixed`, `Dictionary.Ordered.Small`,
`Queue.Linked.Inline`, `Heap.Fixed`, tree variant nests — deleted or never built). Replace:

- [DS-002]'s variant table → the [DS-028] axis table + "which variants exist is
  consumer-pulled; consult the family's front-door files". Copyability/Sendability rules →
  "flow from the column" (D6). The known-compiler-issues block → §3's W1/W2/W3 rows (W2 with
  the 6.3.3 debug/release asymmetry; W3 fixed-in-reduction).
- [DS-003]'s per-family variant rows → canonical spellings only, plus each family's front-door
  inventory as built; the selection flowcharts stay (they select families, which are stable).
- [DS-001]'s "Collection" layer word → **ADT** (aligning with the 4-owner vocabulary); tier
  numbers unchanged.

### 4.7 Amendment riders (cross-referenced skills)

| Rule | Rider |
|---|---|
| **modularization** [MOD-PLACE-DECOMPOSE] (`.Bounded` bundle row) | Capacity splits: *placement bytes* at Memory; the *overflow contract* (typed `Overflow`, `Header` capacity) at Buffer — the live-code shape. Delete the "capacity value + growth at Memory" spelling. |
| **modularization** [MOD-PLACE] seam-taxonomy note | Fix per audit F5 (2026-06-22, still OPEN): `Memory.Allocatable.\`Protocol\`` refines `Memory.Region` (not `Memory.Tracked` — that protocol is deleted by §9.6); the create/grow seam is `Memory.Growable`, now ALSO the fence for allocation-generic op pins ([DS-029]). |
| **memory-safety** [MEM-SAFE-027] | Re-affirmed on 6.3.3 with sharper shape: the naked cross-package skip is DEBUG-only (release specializes past it) — the workaround stays REQUIRED because debug leaks are real leaks. Add the probe pointer (`Experiments/adt-tower-walls`, W-B/W-C). |
| **memory-safety** [MEM-SAFE-028] | Unchanged; add: re-probe on each toolchain bump is a standing wave gate (§9.5); the reproducer package is the witness. |
| **memory-safety** [MEM-COPY-016] / [MEM-COPY-018] | Unchanged; now load-bearing citations of [DS-025] (D2 rationale). Refresh their [DS-*] cross-references to the ratified numbers. |
| **code-surface** [API-IMPL-021] | Unchanged; add the 6.3.3 data point: `CoroutineAccessors` flag is accepted (struct `read`/`modify` parse; protocol requirements accept `{ read }`/`{ read set }`, not `modify`); adoption stays deferred to the SE-0474/SE-0507 gate bump. |
| **code-surface** [API-IMPL-022] | Unchanged; carriers are stored tower value types ⇒ `@frozen` from birth (the worked example complies). |
| **code-surface** [API-IMPL-023] | **AMENDED (M4, 2026-07-03)**: [DS-028] front doors are generic-instantiation aliases, expressly OUTSIDE the forbidden rename-bridge class. Discipline seams remain deletable conveniences WITH ONE CARVE-OUT — the `Direct` marker (`__ColumnDirect`, and the NEW seam-tier `Store.Direct` typealias below) is **load-bearing**, NOT a deletable convenience: it is the axis-drop FENCE the [DS-028] alias laws depend on ([DS-028] law 1 — deleting it lets a cross-axis chain silently reset an axis). Reclassified from "deletable convenience" to a required seam type; §10 records the supersession of the prior "in-tower plumbing binds `__ColumnDirect` directly" ruling. |
| **code-surface** [API-NAME-004] / `Store.Direct` (M4, NEW) | Add a seam-tier public typealias `Store.Direct` (= `__ColumnDirect`) in Store Protocol Primitives alongside the hoisted marker, so in-tower conformance/where-clauses bind `Store.Direct` — NOT the dunder `__ColumnDirect` and NOT the column-vocabulary `Column.Direct` (which stays the consumer-facing spelling). No dunder token ever appears in a public conformance clause. |
| **conversions** [CONV-016] / op-body index hygiene (M6, NEW) | Op bodies over the typed seam count MUST derive bounds through the typed API (`count.map { Ordinal() }`, typed `Index`/`Offset`/`Count` arithmetic) and descend to raw `Int` ONLY via `Int(clamping:)` for the residual arithmetic seed a raw loop genuinely needs. The reach-through `Int(x.underlying.rawValue)` (tier-5 double-unwrap) and `Int(bitPattern:)`-in-arithmetic are FORBIDDEN in tower op bodies; both are AST-lint-promotion candidates (extends `no_int_bitpattern_arithmetic`). The W2 heap pilot's `Heap.swift:176,207` carry the reach-through and are corrected on-branch. |
| **code-surface** [API-NAME-008] remove-op naming (M5, NEW) | A single-word removal op that can fail on empty returns `Optional` (`pop() -> Element?`), tower-wide (extends the SEAT's §9.3 remove-from-empty ruling into a naming decree): `Array.removeLast()` → `pop()`; every family's single-word remove follows. Carve-out: this supersedes any [API-NAME-008] compound-name pressure for the `~Copyable`-carrier remove ops — the Optional-consuming return is available for `~Copyable` elements (a borrow is not, so borrowing accessors keep crashing preconditions, `min`). |
| **ecosystem-data-structures** bounded error (M10, NEW) | The bounded op form spelled `throws(Overflow)` throughout this document denotes each family's OWN nested error type (`throws(Queue.Error)` with a `.full` case — the LANDED shape, `Queue+Columns.swift:62,75`, `Queue.Bounded.swift:29`), NOT a shared tower-wide `Overflow` type (which never landed). Keep per-family nested `Error`; `Overflow` in [DS-028]/[DS-029]/D4.1/D4.4 is a stand-in token for that per-family error, read accordingly. |
| **ecosystem-data-structures** iteration (D9 / M11, NEW) | The ADT tier defines NO iteration; it flows from the column as a **borrowing `forEach`** lending `(borrowing Element)` — 0-witness cross-module, spike-verified for both Linear and Ring over a move-only element. `~Copyable` columns are **borrow-iterable only** (consuming `Sequenceable` is `Element: Copyable`-gated). Multipass `Iterable` is a **Linear-only** surface (Ring's was pruned 2026-06-10); a family claims `Iterable` ONLY if its column vends it. See §2 D9. |
| **code-surface** [API-IMPL-009] struct-carrier hoist (M12, NEW) | The [API-IMPL-009]/[PKG-NAME-006] hoist idiom explicitly covers STRUCT carriers (`__X` struct + front-door alias), not only protocols and agent-nouns — the tower carrier is the canonical struct-hoist instance. State it in the skill so a family author reads the struct-carrier hoist as sanctioned, not an exception. |
| **modularization** [MOD-036] correction (M12, NEW) | [MOD-036]'s wholesale claim that `@usableFromInline package` storage + `@inlinable` accessors collide cross-package is REFUTED — the landed carriers compile and specialize (0-witness, cross-module). The real constraint is narrower: it manifests ONLY at a RESILIENT (library-evolution) module boundary. Tower packages build NON-RESILIENT, so the [DS-025] carrier shape is sound. Record the **non-resilient-builds invariant** (tower carriers assume non-resilient builds) and correct [MOD-036] to the resilient-boundary-only scope via skill-lifecycle. |

**M12 tracked follow-ups (design-audit arc, 2026-07-03).** Basket items that carry into the wave
plan rather than the rule text — each lands with its finding's specific data at wave dispatch,
noted here so none is lost:

- **Lint re-arm is a HARD pre-W2 gate** — the [DS-026] predicate classifier + the M1/M6 checks
  must be ARMED (not promotion-candidates) before the nine-family fan-out (§7 Error-proneness,
  D8(1)). Until armed, the §9.4 grep-zero + per-family compile-probes carry enforcement.
- **§9.4 consumer counts** are plan-time indicative and re-grepped at each package dispatch
  ([RES-023] predicates re-run at execution); any specific count correction lands with its
  package's break-list, not in this document.
- **GAP-6/7 + the gate-twin spike** fold into the W2 per-family gates (§9.3), carried with their
  finding detail at wave dispatch.
- **[DS-027] skill-slip**, **`Inline` double-spend**, and **Column-vocab axis-consistency** are
  tracked skill-lifecycle riders — recorded here so they survive; each resolves with its finding.

---

## 5. Formal appendix ([RES-024])

### 5.1 The column algebra

Let `𝕄 = { Heap, Inline⟨n⟩, Small⟨n⟩, Foreign, … }` (Memory leaves; element-free),
`𝕊 = { Contiguous, Generational, Split }` (Storage disciplines; introduce `Element`),
`𝔻 = { Linear, Ring, Slab, Linked, Slots }` (Buffer disciplines). A **column** over element `E`:

```
K ::= D(S_d(Alloc(M), E))            buffered column        (D ∈ 𝔻, S_d ∈ 𝕊, M ∈ 𝕄)
    | S_id(Alloc(M), E)              storage-direct column  (S_id ∈ 𝕊 with identity geometry: Generational)
    | Shared(E, K_direct)            ownership column
```

concretely spelled `Buffer<Storage<Memory.Allocator<M>>.S_d<E>>.D` and `Shared<E, _>`. A
**family** is a carrier functor `__X⟨−⟩` from columns to types; a **variant** is a fiber of the
projection

```
π : Columns(E) → 𝕄̂ × Capacity × Ownership      (the three FREE axes; 𝕄̂ = 𝕄 modulo the leaf's
                                                 internal representation. The discipline D_X is a
                                                 FROZEN per-family coordinate, not a component of π —
                                                 changing it changes the family, not the variant.)
```

and a **front door** is a named section of π: the canonical alias picks
`(Heap, growable, D_X, direct)`; `X<E>.Small⟨n⟩` picks `(Small⟨n⟩, growable, D_X, direct)`; etc.
The axes commute where both are defined: allocation × capacity are independent
(`Bounded` composes over any `Memory.Growable` leaf), allocation × ownership are independent
(`Shared` wraps any direct column), discipline is a per-family constant (`D_X` fixed by X's
semantics; identity-geometry disciplines take the storage-direct production — the Buffer owner
appears exactly where geometry is a separate concern). The front-door set per family is a
product — REACHED through the D4.2 alias laws: axis-adding transformers compose in any order
(column-preserving), axis-changing aliases apply only at direct columns (the `Direct` fence),
so every product point has exactly one well-typed spelling and mis-ordered chains fail to
compile rather than silently projecting. `Memory.Growable` is the fence functor: growth ops exist over exactly the columns whose
leaf lies in `Growable ⊂ 𝕄` — `Inline⟨n⟩ ∉ Growable`, so bounded-only surfaces are selected by
construction, not by duplication.

### 5.2 Capability judgments

```
K ⊨ Store      (capacity, slot subscript, initialize, move, unshare)
K ⊨ Buffer     (count : Count, isEmpty)
```

Direct columns satisfy both by construction of the buffer stack (the discipline conforms
`Store.Protocol` where its storage is `Ledgered`; `Buffer.Protocol` unconditionally).
**Shared preservation**: `K ⊨ Store ∧ K ⊨ Buffer ⟹ Shared(E, K) ⊨ Store ∧ Buffer`, with
`unshare()` overridden to the uniqueness-restoring gate. The preservation
conformances are *declared* on `Shared` with full seam bounds — they cannot be derived
conditionally through pins (W12/F-4) — which is sound because `Shared` is a column, not a
carrier: [DS-025]'s bound-free law binds carriers only.

The carrier's capability extensions are conditional morphism families:

```
⟦obs⟧  : ∀K ⊨ Store ∧ Buffer.  __X⟨K⟩ → Observables          (count, isEmpty, min, …)
⟦mut⟧  : ∀K ⊨ Store ∧ Buffer.  __X⟨K⟩ ⇒ __X⟨K⟩               (seam-generic; gate-first)
⟦grow⟧ : ∀M ∈ Growable.        __X⟨D(S(Alloc(M),E))⟩ ⇒ …      (allocation-generic pin)
```

Zero-cost claim: for every concrete K, `⟦·⟧` specializes to direct calls (no `witness_method`)
— witnessed at three scales (seam reduction 2026-05-24; GATE-1 2026-06-18; the worked example
2026-07-02, real columns).

### 5.3 Copyability soundness against Wall 1

Define `Copy(T)` = "T conforms Copyable". The design's copyability function:

```
Copy(__X⟨K⟩)        ⇔ Copy(K)                        (conditional conformance on the carrier)
Copy(Shared(E, K))  ⇔ Copy(E)                        (the S5 chain)
Copy(K_direct)      = false                          (leaves are move-only or class-façaded)
```

Wall 1 requires: any node with a user `deinit` is unconditionally `¬Copy`. The design places
user `deinit`s only at (a) unconditionally-`~Copyable` inline leaves (`Store.Inline`-class,
`@_rawLayout` + oracle) and (b) class boundaries (`Shared`'s box; heap-leaf backings) — the
[MEM-COPY-016] triangle. Every node that can be `Copy` under some instantiation (the carrier;
the `Shared` struct shell) is deinit-free; direct buffers are likewise deinit-free `~Copyable`
pass-throughs (their teardown obligation is leaf-owned per D5, not buffer-owned); teardown
reaches elements through the leaf oracle or the box drain ([MEM-SAFE-028]). Hence no instantiation of the algebra can put a `deinit` on a conditionally
copyable type: the SE-0427 law is satisfied structurally, not by per-case audit. Double-destroy
soundness follows the same argument as SE-0427's own: `Copy(T)` nodes never carry custom
teardown; teardown-carrying nodes are unique by `¬Copy` or refcount-gated by the box.

### 5.4 The ledger contract ([DS-024], W8)

For a column K with abstract state `⟨slots, count⟩`:

```
{ ¬live(i) }  initialize(at: i, to: e)  { live(i) ∧ count' = count + 1 }
{ live(i)  }  move(at: i)               { ¬live(i) ∧ count' = count − 1 }
{ live(i)  }  subscript _read/_modify   { count' = count }
              (all three)               { capacity' = capacity }
```

The carrier's seam-generic mutations (remove-shift, drain, pop) terminate and preserve
family invariants **iff** K satisfies this contract; the type system cannot express it
(the judgments quantify over mutation history), so it is law-tested per column
(`Seam.Ledger.violations`). This is the one obligation the design leaves to tests by
construction, and it is stated as such rather than hidden.

---

## 6. Prior-art survey (SLR, [RES-023])

Method: Kitchenham-style parallel survey (7 topics, independent agents, primary-source
verification with verbatim excerpts; the synthesis below plus the §11 citations are the
record of the survey). The swift-collections deep-dive agent was rate-limit-interrupted AFTER writing its full
verified report (recovered; integrated as §6.5 and §11); the academic-foundations topic was
re-run to completion before ratification (§6.6, §11). The load-bearing synthesis:

### 6.1 The convergent negative result

**No surveyed system collapses allocation variants into one owner via type-system polymorphism
alone.** The industry answers: delete the variants (Zig 0.15/0.16 removed managed containers
AND `BoundedArray`; bounded became a mode with UB-documented misuse), duplicate the owners
(Ada's ten `Bounded_*` packages, 65.3% line-identical GNAT bodies; Hylo's separate
`BoundedArray` beside `Array` despite first-class projections; stdlib's
`InlineArray`/`RigidArray`/`UniqueArray` as separate named types), erase at the view layer
(.NET `Span<T>`; Swift `Span` — unifies reads, never growth), or park the unifier
(Rust's allocator_api unstable for 10 years; the Store/storages RFC 3446 open since 2023).
The Swift stdlib retired unification **twice**: de-gybbing Arrays (2018 — codegen was available
and was abandoned for hand-maintained facades) and demoting `RigidArray` to the internal core of
`UniqueArray` (2026 — the wrapper re-declares the full surface, 1,618/1,958 lines).

### 6.2 Why the do-nothing baseline is also condemned

The hand-variant path is measured: `SmallVec` re-implements ~40% of a `Vec` per variant
(2.6–3k lines) with conversion-only reuse, and its duplicated grow/insert paths produced four
memory-corruption RUSTSEC advisories in a heavily-audited crate. Centralizing grow/overflow/free
logic once is a memory-safety argument, not a line-count argument. The institute's own tree
concurs: the deleted `Heap.Fixed`/`Queue.Linked.Fixed`/`Tree.N.Bounded` families, and the
`Queue+Columns.swift` op layer where one `enqueue` exists three times with `Memory.Heap`
hardcoded.

### 6.3 The two counterexamples the design is built on

- **`heapless` (Rust, shipping)**: `VecInner<T, S: VecStorage>` + typealias front doors
  (`Vec = VecInner<OwnedVecStorage<T,N>>`) + **capacity in the storage type** — which
  neutralizes the libs-api layout objection to storage-generic containers (a storage-generic
  `Vec` "can't match SmallVec's 24-byte packing" — it can when the inline budget is a type-level
  constant, exactly `Memory.Inline<n>`/`Memory.Small<n>`'s shape).
- **Rust's `RawVec`/`Vec` split**: growth/overflow/free centralized in an ELEMENT-BLIND
  memory-management layer below the semantic layer ("does not in any way inspect the memory
  that it manages") — prior art for the element-free floor and for ≥2 owners, NOT for the
  exact D1 cut: Rust places growth execution below the liveness ledger and merges
  ledger+count+semantics inside `Vec`, so its boundary crosses the Storage/Buffer line. The
  four-owner discrimination rests on the in-tree seam-sharing facts (D1), not on Rust.

Swift-specific enablers absent from every surveyed system's decision window: **enforced
constrained generic typealiases** (probed, 6.3.3), **value generic parameters** in aliases and
pins (SE-0452), **suppressed-conformance generics** (SE-0427) with conditional re-conformance —
together these make the `heapless` shape spellable with real `Nest.Name` names and zero wrapper
tax. C++'s cautionary record (N1850: the allocator type parameter as the most-criticized
container decision; PMR as the runtime-erasure repair with virtual-dispatch cost; P0843's
separate-type rationale for `inplace_vector` — the *contract*, not just the storage, changes) is
answered by (a) front doors keeping the parameter out of consumer signatures, (b) static
dispatch preserved (0-witness receipts), and (c) the capacity *contract* axis being a real axis
in the algebra (typed `Overflow`), not a hidden behavioral change.

### 6.4 The stdlib direction, tracked not diverged-from

`InlineArray` (fully-initialized only; separate type by stated design), `Span`/`MutableSpan`/
`OutputSpan` (the view-layer unification — every tower column vends spans through
`Span.Protocol`), SE-0516 `Iterable` (borrowing iteration; decision pending — the tower's
`Iterable` integration point), SE-0499/0503/0507/0519 (the 6.4 wave: `~Copyable` stdlib
refinements, suppressed associated types default-on, borrow/mutate accessors, `Ref`/
`MutableRef`). The design's 6.4 gate-bump items are mechanical renames/widenings (§9.7), not
reshapes — the shape is chosen to be forward-compatible with all four.

### 6.6 Academic grounding (the formal-lineage synthesis)

The design's load-bearing structures each have a named formal ancestor; the §5 appendix is the
institute-shaped instance of this lineage, not a novelty:

- **Move-only substrate**: Wadler's linear-types result — linear values "safely admit
  destructive array update" without GC — is the founding warrant; Swift's `~Copyable` is the
  affine (droppable) weakening that Alms argues is the practical polarity, and Alms/Mezzo/Cogent
  jointly license the **facade discipline** (a move-only surface over copyable internals is
  sound via sealing; Cogent shipped verified filesystems exactly this way, and its warning —
  iteration is the hardest move — is why `Iterable`/span iteration is composed, not refined).
- **The kernel/facade obligation**: RustBelt's theorem shape — every safe facade over an unsafe
  kernel owes a "library-specific verification condition" at its interface — is what the
  [DS-024] seam-ledger laws and the per-column law tests ARE (with Stacked Borrows as the
  reminder that the kernel's aliasing discipline must be stated, per [MEM-SAFE-029]).
- **The Header/Storage factoring**: Abbott/Altenkirch/Ghani's containers theorem (every strictly
  positive datatype = shapes × positions) is the categorical basis for one shared kernel under
  many families — the §5.1 column algebra is a container decomposition.
- **Region columns**: Tofte–Talpin regions + Cyclone's region kinds (heap/stack/dynamic ↔
  growable/inline/arena) ground the Memory-leaf axis; region polymorphism IS the
  allocation-generic pin ([DS-029]). Berger et al.'s allocator study prices the axis budget:
  general-purpose heap default + regions/arena earn their keep; ad-hoc per-container allocator
  columns don't — the catalog's restraint is evidence-backed.
- **The two ownership rows over one kernel**: Perceus (uniqueness-guarded reuse) and FP²
  (static ownership guarantees in-place execution) formalize exactly the design's split — the
  move-only column is the static row, the `Shared` CoW column the dynamic row, both over ONE
  mutation kernel gated by `unshare()`.
- **Ownership/representation exposure**: Clarke/Potter/Noble's defect class (aggregate state
  mutated "via an alias to one of its components") names the invariant the seams enforce —
  storage never escapes; only non-escaping borrows are vended (W11's SIL-enforced contract).
- **Destination-passing**: Minamide's holes + DPS ground the `OutputSpan`-style
  `init(capacity:populate:)` producers the columns already ship — allocation polymorphism at
  function boundaries with linear fill obligations.

---

## 7. Consumer-surface evaluation (cognitive dimensions, [RES-025])

| Dimension | Assessment |
|---|---|
| **Role-expressiveness** | `Array<Int>`, `Array<Int>.Small<24>`, `Heap<Job>` read as what they are; the column spelling appears only when a consumer opts into custom composition. The alias-chained variant (`X<E>.V<n>`) states family-then-variant in [API-NAME-001] order. |
| **Abstraction level** | Two entry tiers: names (front doors) for the 99% case; the column algebra for composers. No third tier — no builder DSL, no macro layer (by charter). |
| **Visibility / hidden dependencies** | Diagnostics print the carrier instantiation (`__Array<Buffer<…>.Linear>`), not the alias — the known alias trade-off ([API-NAME-004] rationale). Mitigations: the hoisted name is one hop from the alias file; error surfaces keep public paths ([API-ERR-007]); `@_documentation(visibility: public)` keeps the hoisted API in DocC (the panel-found symbol-graph hole, D2). Accepted cost, stated. |
| **Viscosity** | Changing a variant choice at a use site = editing one type spelling; adding a variant to a family = one alias file; adding an ADT = one package-internal file set (measured §1.1). Cross-family renames stay mechanical (aliases localize spellings). |
| **Error-proneness** | The seam contract is compiler-enforced (W11: borrow yes, mutate yes, move-out no); capacity misuse is typed (per-family `throws(Error)` with `.full`, M10). The two residual footguns — forgetting `where S: ~Copyable` (W9) and heap-pinning an op (D8(d)) — have mechanical checks **DESIGNED but NOT YET ARMED (M12 honesty)**: the [DS-026] predicate classifier + the M6 reach-through lint are swift-linter promotion candidates (armed at W4, D8(1)); the M1 alias-reachability check is a per-family COMPILE-probe added at the W1.6 gate. **Lint re-arm is a HARD pre-W2 gate** (M12) — the fan-out MUST NOT proceed on aspirational checks; until armed, the per-family compile-probes + the §9.4 grep-zero gates carry the enforcement. |
| **Consistency** | One shape for every family; a reader who learns `__Array<S>` + front doors has learned `__Heap<S>`, `__Queue<S>`, `Tree<S>`. The existing `Tree` family already reads this way. |
| **Premature commitment** | Consumers choose a variant last (swap the alias), not first; family authors choose variants never (consumer-pulled). |

---

## 8. Rejected alternatives

### 8.0 The adversarial panel record

Per the Tier-3 rigor requirement, twelve independent refuters attacked D1/D2/D4/D7 through
distinct lenses (minimality, evidence-fidelity, forward-compatibility; type-system soundness,
ergonomics/diagnostics, performance; expressivity, compiler-scale, migration-cost;
discriminator-robustness, modularization-fit, build-graph), each required to produce a
compiling counterexample, a source citation, or a measured number for a REFUTED verdict.
Outcome: **0 REFUTED · 8 DENTED · 4 SURVIVES** (all twelve lenses completed). Every dent was
a text/plan repair that left the decision standing, and every repair is INTEGRATED in this
document:

| Lens | Verdict | Repair (integrated at) |
|---|---|---|
| D1 minimality | DENTED | storage-direct columns for identity-geometry disciplines (D1/D2/D4/§4.1/§4.4/§5.1); Store.Inline noted as the allocation-independent inline leaf |
| D1 evidence-fidelity | DENTED | three citations re-scoped: the 2×2 (primary source cited; supports a-generic-seam, not four-vs-three), RawVec/Vec (element-blind-layer prior art, boundary crosses ours), the 16-cell matrix (computed UNDER the leaf placement; buffer placement retired on Lemmas II.2/II.3 + W14) — D1/D5/§5.3/§6.3 |
| D1 forward-compatibility | SURVIVES | 6.4's Rigid/Unique facade convergence poses no migration trap; bonus: independently re-verified the §1.1 facade-tax figure and §9.7's flag facts |
| D2 type-system soundness | SURVIVES | the full unbuilt composition (bound-free carrier × Shared × conformance diamond × alias chain × value generics) passes -O/-Onone; `Shared`'s self-gating seam witnesses make the carrier gate defense-in-depth |
| D2 ergonomics/diagnostics | DENTED | `@_documentation(visibility: public)` on every hoisted decl (measured DocC hole; live on today's `__StoreProtocol`) — D2/[DS-025]/D8(e)/§9.6-12 |
| D2 performance | DENTED | `@inlinable` REQUIRED on public tower ops (714×/139× measured without; 29 witness_method) — [DS-025]/[DS-029]/D3 re-scoped |
| D4 expressivity | DENTED | the three alias laws: `Direct`-fenced axis-changing aliases; column-preserving transformers (Shared wraps S; Bounded via the capacity-twin associated type); the units rule (`Small<n>`=bytes, `Inline<n>`=elements) — D4.2/[DS-028]/§9.6-13 |
| D4 compiler-scale | SURVIVES | interface round-trip + 400-alias scale + 3-hop chains pass; caught the worked example's missing `@frozen` (fixed in-session, evolution emit passes) |
| D4 migration-cost | DENTED | Graph/Cache consumer sweeps; corrected counts; Tests/ in scope; the silent-retype hazard ⇒ the legacy-spelling grep-zero gate — §9.1/§9.3/§9.4 |
| D7 discriminator | DENTED | the ordered mechanical test: three free axes; discipline frozen; decreed op forms; variant-vs-nest alias senses — D4.1/D4.4/[DS-027].2/[DS-028]/§5.1 |
| D7 modularization-fit | SURVIVES | the sibling nest-alias-through-hoisted-typealias shape compiles and runs cross-module (3-module probe, MemberImportVisibility); [MOD-032] scan: 0 cycles across 203 manifests; sibling deps one-way |
| D7 build-graph | DENTED | the [DS-027].1 target-placement rider: heavy-leaf variant aliases (Small/Inline) get their own variant target + product, umbrella-re-exported — the in-target shape would have pushed the dropped memory-small dep (+2 packages) onto 7 heap-only consumers — D7/[DS-027].1/§9.2 |

The full verdicts (attacks, evidence, probes) are in the panel workflow journal; the probes the
refuters wrote are reproducible from the evidence lines quoted in each repair's section.

Each with the specific reason it loses. Prior corpus positions appear here when the
re-derivation overturns them; §10 dispositions their documents.

### 8.1 V1-as-specified — capability bound on the type (`X<S: Store.Protocol & Buffer.Protocol & ~Copyable>`)
The shipped shape of 8 families. Loses on: (a) conformance chains and capability families are
welded to the bound — a keyed/non-slot column can never be a valid argument (GATE-1's families
are inexpressible); (b) [MEM-COPY-018] retrofits — pins interact with the bound as two levers
that must be edited together; (c) the bound adds nothing at runtime (0-witness holds either
way — "concrete == pin vs protocol bound is ontology, not performance", the receipts). The
*axis* (a column) was right; the weld was the defect.

### 8.2 V2-as-specified — "ride `Buffer.Protocol`, never reach storage" (`X<B>` with element ops on the buffer seam)
The 2026-06-18 PROVISIONAL charter text. Loses on a factual premise: the real `Buffer.Protocol`
is deliberately observability-only ("capability, NOT an op-dispatch surface" — its own doc,
backed by the #81624/accessor specialization evidence); the element ops V2 rides do not exist on
it, and widening it re-litigates a correct 2026-05 decision. Implemented 0×; the tree-core
validation gate never closed *because the shape was unimplementable as written*. Its two sound
clauses — bound-free carrier, additive consumer protocol — survive in [DS-025]; the
seam-conformance resolution (the column itself conforms `Store.Protocol`) supersedes the
"reach" framing entirely. The `adt-over-buffer-seam` experiment stands as evidence about
*reductions* (and its V3/V4 clauses remain the suppression walls' witnesses).

### 8.3 Concrete-over-Element families (shape E) as the end-state
Today's `Stack`/`Heap`/`Slab`/`Hash.Table`/`Queue.Linked`/`List.Linked`. Loses on the mission
metric: every allocation variant is a new type with a duplicated surface (the deleted-variant
history; the SmallVec CVE record). Survives only where a family's engine is genuinely
column-free (none identified; `Hash.Table` becomes an internal engine — §9.3).

### 8.4 The wrapper façade (`struct Array<Element>` wrapping a defaulted column)
The shelved bare-`Array<Int>` analysis, re-examined: a wrapper pays the stdlib's measured facade
tax (~0.8× surface re-declaration, `UniqueArray`), an arity collision with the carrier, and
~4.3 ns/op worst-case dispatch. The alias front door delivers the same spelling with none of the
three. (The shelving decision was correct for the wrapper; it does not transfer to the alias.)

### 8.5 Hand-written variant types (the pre-dissolution taxonomy)
[DS-002]/[DS-003]'s `.Static<N>`/`.Small<N>`/`.Fixed` catalog. Loses on everything the Round M
coda established (duplication unaffordable; the deletions) — retained as the *name inventory*
the front doors re-grow on consumer pull.

### 8.6 Per-discipline op protocols (`Ring.Protocol` with pushBack/popFront, typed `Overflow`)
The strongest rejected candidate. Would unify direct/bounded/`Shared` columns under one op
extension per family (typed-throws `Overflow == Never` call sites need no `try` — probed).
Loses today on: F-4 (a hand conformance per discipline on `Shared`), #81624 adjacency for
accessor surfaces, Ruling-12's protocol-minimalism re-derived (D3), and zero consumer pull for
generic-over-discipline ADT code. **Banked**: the shape is expressible and becomes attractive
iff a consumer needs "any ring-shaped column" genericity; revisit at the Round-C
`Store.Ledgered` review.

### 8.7 PMR-style runtime allocator (type-erased `any Allocator` field)
One type, no spelling leak — at virtual dispatch per allocation, sticky-semantics questions
(C++ PMR's record), and an existential in the hot path where [API-IMPL-023] forbids one. The
static column algebra + front doors reach the same consumer surface without the runtime cost.

### 8.8 Merging Storage into Buffer (3-owner tower)
Loses on independent variation (D1): re-creates the measured 2×2 duplication; contradicted by
the RawVec/Vec precedent and by every discipline sharing `Storage.Contiguous`.

### 8.9 The five-layer ontology (allocation as a layer)
Superseded by the 4-owner basis (D1); a conformer depending on the seam it adopts is not a
layer inversion. (Already the audit's Q1 verdict; re-derived here from the invariant table.)

### 8.10 Macro-generated declarations
Excluded from the candidate space by principal ruling (2026-07-02, charter §5): not surveyed,
not spiked, not costed, per the no-macros law for the ADT declaration path. (The corpus's own
macro probe — a working `@SparseLeaf` that still could not dissolve the carve-out — stands as
independent corroboration that macros do not reach the actual walls, but plays no part in this
decision.)

### 8.11 Names-in-consumers (the status quo ante)
Leaving spelling to consumers (json's local `SmallByteArray`) externalizes the naming cost to
every consumer and produces divergent local vocabularies for identical columns. Rejected by the
mission statement itself; the empirical consumer survey (27 consuming packages, exactly one
deep spelling) shows the leak is small today only because variants were unusable.

### 6.5 apple/swift-collections, corrected and mined (pinned 6c12132, 2026-07-01)

The survey premise "swift-collections offers no allocation variants" is stale: releases
1.3.0–1.6.0 (2025-09 → 2026-06) shipped a two-axis `~Copyable` family — `RigidArray`/`RigidDeque`/
`RigidSet`/`RigidDictionary` (fixed-capacity, heap) and `Unique*` (growable) — plus a
trait-gated container-protocol preview. Three load-bearing extractions:

1. **The layered core, upstream**: `UniqueArray` is "a relatively simple wrapper around rigid
   array instance, forwarding operations to it" (BasicContainers.docc) — the growable-over-fixed
   layering of D1, paid for with the facade tax our aliases avoid (separate types, full surface
   re-declared).
2. **The maintainer wants exactly the missing variants and is language-blocked** (issue #484,
   lorentey): "We do need (and really really want) a `Heap` variant with inline storage, and
   also one that starts out with a fixed-capacity inline buffer and switches to heap allocation
   … (`SmallHeap`)"; `InlineArray` is unsuitable ("constant `count`, not just a constant
   `capacity`"); what's needed is "a proper inline array type, with a variable count, and
   partially initialized storage", which "requires fundamental changes in how the compiler
   expects Swift types to manage memory"; and the LSG has deprioritized the direction. The
   institute is not blocked: `@_rawLayout` leaves + the [MEM-SAFE-027] workaround ARE
   partially-initialized inline storage today (W2-caveated), which is precisely why the tower's
   inline/small columns exist below the stdlib's reach.
3. **The duplication argument, from the maintainer**: the `InlineArray<Optional<T>>` workaround
   is rejected partly because "we'd need to add a separate heap implementation … 2x the code →
   2x the bugs", and foremost because an optionals buffer is not `Span`-compatible — both
   arguments this design's leaf-law (D5: niche-law slots at the LEAF, spans over initialized
   prefixes) already internalizes.

---

## 9. The implementation plan

Executable by a fresh session via `/goal` + workflows, with zero design decisions arising
mid-flight: every disposition below is decided here. Write scope of the implementation session:
production packages + skills; this document's own §10 authorizes the pruning.

### 9.1 Wave structure

| Wave | Scope | Gates |
|---|---|---|
| **W0 — ratify + arm** | Install §4 rule text into ecosystem-data-structures (+ §4.7 riders) via skill-lifecycle; re-point `adt-decoupling-classify.py` to the [DS-026] predicate + regenerate its ledger (void the 2026-06-18 LEDGER); re-pin benchmark baselines (`swift --version` stamp per run, [BENCH] discipline) | skill CI green; classifier runs with the new predicate |
| **W1 — S-shape realignment** (8 carriers + 2 inherited; lands in FAMILY CLUSTERS) | For each of Array, Fixed, Queue, Set (+`__SetOrdered`), Dictionary, SlotMap, `__HashIndexed`, and the inherited Queue.DoubleEnded / Dictionary.Ordered: hoist the carrier (`X` → `__X` where the public name moves to the alias), DROP the type-level seam bound → capability extensions, add the canonical front door + the already-pulled variant aliases (`Array<Byte>.Small<24>` exists day one — json pulls it), keep [MEM-COPY-018] pins as-is, wire [DS-024] law tests for every column named in a front door | per package: build ×2 (debug+release) with ZERO NEW diagnostics attributable to the reshape — evidence: a sorted diagnostic-fingerprint diff vs main under the same command (SEAT ruling 2026-07-02: pre-existing warnings in files the reshape TOUCHES are cleared while there; pre-existing debt in UNTOUCHED files is LEDGERED as a cleanup item, not gated; a package whose main is pre-existing-RED gates on "zero new diagnostics" and carries the disclosure in its commit message); tests green; classifier state = at-target (EXCEPTION — `__HashIndexed` is a COMBINATOR: one generic parameter = the wrapped ADT, index table is derived state, not a column, so its census state is n-a like Cache; its W1 gate is instead "census n-a consistent + composes with the reshaped Set/Dictionary carriers" — SEAT ruling 2026-07-02); SIL spot-check 0 `witness_method` on one hot generic op; consumer break-list migrated + the §9.4 legacy-spelling grep-zero gate (compile-green alone is insufficient — the silent-retype hazard) |
| **W2 — E-shape families gain the column axis** | Per-family dispositions in §9.3 (all decided) — Stack, Heap, Slab, Queue.Linked, List.Linked, Hash.Table, Bitset, Cache, tree columns | same gates as W1 + family benchmark rows within guardrails (§9.5) |
| **W3 — buffer-tier op generalization** | Ring/Slab/Linked/Slots public ops: heap-pin → allocation-generic pin ([DS-029] form 2; Linear is the shipped exemplar); verify Small/Inline column coverage per discipline; §A9 unguard-probe (W16) on the current toolchain; re-probe W3 dual-storage at production scale; cut the first INLINE front doors (`X<E>.Inline<n>` over `Buffer<Store.Inline<E, n>>.D`, bounded ops) once the bounded pins generalize | per package: build ×2, tests, benchmarks; ring/deque front doors gain `.Small` on the generalized ops |
| **W4 — deletions + docs + enforcement** | §9.6 deletions; [DS-002]/[DS-003] table refresh lands in the skill; catalogs/inventory rebuilt against the reshaped tree; lint-rule promotion attempt for the [DS-026] predicate; `_index.json` refreshes | `[MOD-032]` cycle scan = 0; classifier --verify PASS against the regenerated ledger; docs build |
| **W5 — Round P re-stage** | Re-bless per-package readiness for every reshaped package (the 2026-06-15 blessings are void for reshaped packages, valid for untouched ones); PUBLIC-FLIP-LAST unchanged; flip remains per-repo principal YES | release-readiness brief per package; the flip itself stays outside this plan's authority |

Waves are serial; packages within W1/W2 parallelize per the no-duplicate-dispatch and
serial-build disciplines (one executor per package tree; parent builds once after edits).

### 9.2 W1 mechanics (per package, uniform)

**The W1.5 fence-retrofit unit (SEAT ruling 2026-07-02).** The §4.4/[DS-028] alias-law
INFRASTRUCTURE lands as one coherent unit immediately AFTER the W1 lands and BEFORE W2 opens
(and before json's L2 dispatch consumes `Array<Byte>.Small<24>`): (i) the marker protocol
`__ColumnDirect: __StoreProtocol` (the refinement yields `S.Element` in alias bodies), homed
in Store Protocol Primitives — low enough for the buffer disciplines to conform — CARRYING
the capacity twin `associatedtype Bounded: ~Copyable`; its public `Column.Direct`
spelling is a typealias in the column vocabulary (`swift-column-primitives`, which already
deps the storage package), making W1.5 a 5-package unit; IN-TOWER plumbing (conformances AND
where-clauses, incl. the array Small alias) binds `__ColumnDirect` DIRECTLY — the Small
variant target takes NO Column_Primitives dep (closure stays lean; `Column.Direct` is the
consumer-facing/doc spelling); (ii) W1.5 conformances: `Buffer.Linear` and
`Buffer.Ring` (+ twins = their `.Bounded`) only — ring/slab/linked op generalization stays W3,
`Generational` conforms at its family's wave, `Shared` NEVER conforms (that IS the fence);
(iii) the shipped axis-changing alias (`Array<E>.Small<n>`) gains `where S: Column.Direct`,
and the shipped rebuild-style `.Bounded` aliases re-express column-preserving as
`__X<S.Bounded>`; (iv) the Small variant TARGET+product land in this unit with their
constraint. W1 itself lands as-is — the mis-chain hazard is unreachable through any shipped
alias chain and consumers are grep-zero-gated; W1.5 closes the carrier-spelling residual.

**W1.75 — tower quality sweep (PRINCIPAL directive 2026-07-02; gates the W2 open).** After
W1.5 lands and before any W2 source work: run `swift-linter` directly over every W1/W1.5-touched
package (~16: the 11 W1 carriers + storage/buffer-linear/buffer-ring/column/array W1.5 legs)
plus a code-surface review of the NEW public surface (carriers, front doors, the marker) against
[API-NAME-001/002], [API-IMPL-005/021/022/023], [API-ERR-*]. Findings triage three-way per the
standing lint discipline: fix-source (commit per package), fix-rule (escalate with drafted rule
amendment), ambiguous (escalate). Results land in a NEW ledger file (`Audits/adt-tower-quality-
sweep.tsv`) — the M-phase burndown's `Audits/lint-burndown.tsv` belongs to the paused parallel
arc and is NEVER written by this sweep (nor is `lint-sweep.sh` reused — it appends there).
GATE DISPOSITION (SEAT ruling 2026-07-02, per the partial-verification discipline): the W1.75
gate was met by the CODE-SURFACE half (judgment review: clean, one defect ruled, two items
folded to W2 queue-linked); the AUTOMATED lint half was structurally vacuous — swift-linter's
own dep closure contains swift-async-primitives, an unmigrated W1 consumer whose build now
hard-errors on the old spellings (field-proof of the §9.4 hazard), so 0 rules load. The lint
re-run is therefore a NAMED W2 GATE ITEM: it executes immediately after async-primitives
migrates (first W2 consumer migration) and must be non-vacuous for the W2 wave gate to close.
Not a skip — a tracked obligation.

**Family-cluster landing (SEAT ruling on pilot ESC-2, 2026-07-02).** A family hoist BREAKS any
sibling that declares its type inside `extension <Family> where …` — post-hoist the family name
is a column-pinned generic alias, so the extension's `S` no longer binds and the nested type is
never created (empirically: the deque probe fails with "'DoubleEnded' is not a member type").
Therefore: (a) siblings reshape in LOCKSTEP — hoist to their own carrier (`__QueueDoubleEnded`,
`__DictionaryOrdered`, `__QueueLinked`, `__SetOrdered` already hoisted) + a NEST alias on the
family carrier (D4.1 sense (b)); (b) W1 lands as clusters in dep order within one window —
**{queue, deque, queue-linked(unbreak-only)} · {set, set-ordered} · {dictionary,
dictionary-ordered} · {array} · {fixed} · {slotmap} · {hash-indexed}** — a sibling whose FULL
disposition is a later wave (queue-linked, W2) gets only the minimal unbreak (carrier hoist +
nest alias) in the family's wave, the rest stays in its planned wave; (c) the classifier
LEDGER FLIP rides the cluster's landing window — never precedes it (a pre-merge flip makes
`--verify` fail for every parallel session against the live tree).

1. Rename the primary decl to the hoisted form; keep the file name = carrier file
   (`Array.swift` holds `__Array` + the namespace doc); add `X<E>` canonical alias file.
2. Move the type-level bound to the existing capability extensions (most already spell the
   seams; the diff is the generic-parameter clause + `where` lines).
3. Same-type `where S == …` pins: KEEP (construction/growth pins are [DS-029] form 2/3).
   The `Memory.Heap`→`R: Memory.Growable` re-point applies at W1 ONLY to LINEAR-riding
   families (`Buffer.Linear`'s surface is already R-generic); ring/slab/linked-riding
   families (Queue, Deque, …) keep their heap pins at W1 and re-point at W3 with their
   discipline's op generalization — a W1 R-generic pin there would call buffer ops that do
   not exist for generic `R` (SEAT ruling on pilot ESC-1, 2026-07-02). Queue's enqueue pin
   set is FOUR (direct, `Shared`, bounded, `Shared`-bounded — the last live-tested), all
   preserved; the earlier "trio" was a plan miscount.
4. Front doors: canonical + variants with live consumers (grep the consumer list per family
   before choosing which variant aliases land in W1; everything else waits for pull). Apply
   the [DS-027].1 target rider: `Array<Byte>.Small<24>` lands in a `Array Small Primitive`
   variant target/product (the scaffolded MARKs), NOT in the canonical target — json (the
   day-one puller) already declares the memory-small dep; the 7 heap-only consumers gain
   nothing.
5. Consumer migration: mechanical respell `X<Column>` → `__X<Column>` or (preferred where the
   column is a default/`Small` point) the front door. Break lists per family live in the wave
   dispatch; the 27-package consumer survey (13 L2/L3 + 14 intra-L1; io=10 files, async=9 the
   largest) is the enumeration source of record.

### 9.3 W2 per-family dispositions (all decided now)

| Family (pkg) | Disposition | Notes |
|---|---|---|
| `Stack` (swift-stack-primitives) | carrier `__Stack<S>` over Linear columns; ops seam-generic (push/pop are append/removeLast shapes) + R-generic growth; front doors `Stack<E>`, `.Bounded` (alias to the bounded linear column + `throws(Overflow)` pin) — **deletes the hand-written `Stack.Bounded` type** (the 2026-06-23 directive, executed) | the entangled Pool `Stack<Slot.Index>.Bounded` consumer migrates to the alias in the same wave |
| `Heap` (swift-heap-primitives) | carrier `__Heap<S>`; the worked example IS the blueprint (ops verbatim-portable); `Comparison.Protocol` element bound; MinMax stays parked as a sibling for the heap-template round (unchanged plan) | replaces 2,676-LOC shape-E core; benchmark rows: heap family baselines |
| *(W2 convention rider — SEAT review of the heap pilot, 2026-07-03)* **Remove-from-empty ops return `Optional` across the tower** (`pop() -> S.Element?`, matching the landed `Queue.dequeue()` model; and a single-word removal op that can fail on empty IS spelled `pop()` per the M5 naming decree (§4.7 [API-NAME-008]) — `Array.removeLast()` renames to `pop()`; supersedes both the shape-E `throws(Heap.Error)` and the worked example's crashing precondition — the experiment stays frozen as-is). Crashing preconditions remain ONLY for borrowing accessors where an `Optional` is structurally unavailable (`min` yields a `~Copyable` borrow; documented). **Pilot-set test floor**: each reshaped family ships a randomized differential test against a plain-array oracle (≥500 mixed ops incl. duplicates + interleaved push/pop) — 5-7 example tests alone do not license the fan-out. **Mutating seam-generic helpers carry the gating contract in their doc comment** ("caller must have gated `unshare()`"). **Tracked optimization (ledgered, not gating)**: exchange-based sifting costs ~2× the seam traffic of the classical hole-shift form; the pilot's insert tax (1.3–1.9× stdlib) is attributable to BOTH the typed-slot append path AND this — re-attribute honestly in benchmark notes; hole-shift lands as a measured follow-up. | applies template-wide to the W2 fan-out (Stack.pop etc.) |
| `Slab` (swift-slab-primitives) | carrier `__Slab<S>` over the generational/slab column family; stable-index laws in [DS-024]-style tests | discipline = Generational storage / Slab buffer per the leaf-law |
| `Queue.Linked` (swift-queue-linked-primitives) | SIBLING (O(1) middle-removal is a contract difference, D4.1); carrier `__QueueLinked<S>` over Linked columns; front door `Queue<E>.Linked` (a NEST alias on `__Queue`, declared in the sibling package — D4.1 sense (b)) + a `.Bounded` alias (its `Fixed` hand variant was already deleted in the Round M coda; nothing residual remains) | pre-existing list-linked RED clears with W2 List work below |
| `List.Linked` (swift-list-linked-primitives) | carrier `__ListLinked<S, let N: Int>` (already thin-generic!) — W2 adds front doors + deletes the hand `List.Linked.Bounded` type for the alias | the `List` namespace root stays (nest for `Linked`) |
| `Hash.Table` (swift-hash-table-primitives) | reclassified: **internal engine**, not a consumer ADT (dense elements + POD index engine per the 2026-06-10 hashed-family decisions); `__HashIndexed` remains the set/dict combinator; the engine's tombstone scheme migrates to backward-shift + per-instance seed (both upstream lineages reject tombstones) | census state: n/a (engine) |
| `Bitset` (swift-bitset-primitives) | KEEP concrete (deliberate, recorded exception: a bit-packed word engine has no element axis; the column algebra's Element would be `Bit` with nothing to vary) — trigger to revisit: a consumer pulls an inline/bounded bitset | its existing `.Static`/`.Small`/`.Fixed` hand variants get the same dissolution treatment at that trigger, not before |
| `Cache` (swift-cache-primitives) | family: out of tower scope (reference cache; census n/a) — but a W1 CONSUMER sweep: 4 `Array<Column.Heap<…>>` sites (Cache.swift:269,373,403,436) | |
| *(census note — SEAT ruling 2026-07-02: COLUMN packages (tree-n, tree-keyed) classify n-a in the [DS-026] census — the carrier predicate applies to carriers; columns are its inputs, not its subjects)* | | |
| `Tree` family | already at-target (carrier `Tree<S>` b09726a); W2 adds the front doors the 6.3.2 SIGSEGV blocked: `Tree<E>.N<n>` etc. via aliases over the tree-n/tree-keyed columns; `TreeDynamic` compound alias RETIRES in favor of the canonical `Tree<E>` front door | tree-n/tree-keyed stay column/sibling packages |
| `Graph` | family: namespace, no reshape — but a W1 CONSUMER sweep: 13 files / 28 `Array<Column.Shared<Payload>>` sites migrate to the Shared front door | the §9.4 silent-retype gate applies |

### 9.4 Consumer-migration notes

- **The silent-retype hazard (panel-found, compiling probe)**: after W1, an unmigrated
  legacy spelling `Array<Column.Heap<Int>>` TYPECHECKS against the canonical alias as an
  array-of-COLUMNS (Element := the column) instead of erroring. Compile-green is therefore
  NOT a sufficient migration gate; every W1/W2 consumer dispatch carries a mandatory
  **legacy-spelling grep-zero gate** (`<Column\.` and `<Buffer<` in element position, plus
  `__`-carrier spellings where the front door is intended) over Sources/ AND Tests/.
- Verified consumer set (panel-corrected 2026-07-02; Sources + Tests): L2/L3 — 11 packages:
  io(10 files), async(9), tests(4), file-system(4), pdf-html-render(3), html-render(3),
  kernel(2), json(2), svg-render(1), memory(1), css-html-render(1); intra-L1 non-tower —
  pool(9), parser(6), builder(5), async-primitives(7), byte-parser(3+1 test), version(3),
  binary-parser(3), tensor/glob/executor/column/ascii-parser(2 each),
  property/binary-coder(1 each) — PLUS the two §9.3 consumer sweeps (graph 13 files/28 sites,
  cache 4 sites) and ≥4 consumer-package test files (pool, graph, byte-parser, ascii-parser).
- Exactly one deep composed spelling exists in L2/L3 (json's `SmallByteArray`); it becomes
  `Array<Byte>.Small<24>` (or keeps its local alias over the front door — either is valid; the
  dispatch picks the front-door respell).
- Each W1/W2 package dispatch carries its own fresh break-list grep ([RES-023] plan-time
  predicates re-run at execution).
- §A9 guard interplay: graph-family suites keep their 4 guards until the W3 unguard-probe.

### 9.5 Benchmark guardrails

Baselines of record: `tower-family-benchmark-baselines.md` (M3, 6.3.2, release; the doc's
duplicated-table blocks are an editing artifact — read each family's own section only), plus the
Round-M plane re-cut numbers. Standing invariants each wave must preserve (±5% per family row
unless the wave's dispatch names an accepted trade):

- typed indices cost-free vs stdlib (`get.indexed` ~0.29 ns vs 0.295; `get.span` identical);
- move-only writes ≥ ~3× stdlib (`set.indexed` 0.30 vs 1.14);
- `Shared` mutation tax ≤ ~7–9 ns/op cross-family (gate ~1 ns inlinable);
- ring queue ~flat ~2.6 ns/op; deque frontFront ~4.1 ns flat;
- Hash.Indexed remove stays O(n−rank)-class (the B-7 V3 fix: back 87 ns / random 43.6 µs /
  front 93 µs @64k) — the tombstone→backward-shift migration must not regress it;
- W0 re-pins all of these on 6.3.3 before W1 lands anything (labels must match
  `swift --version`). SEAT ruling 2026-07-02: the re-pin scope at W0 is the INVARIANT
  SUBSET above (the family tables re-pin at each family's own wave gate); `Benchmarks/`
  packages for heap and slab are AUTHORED as part of their W2 dispatches (gate item); the
  6.3.3 label of record is "Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), XcodeDefault (Xcode 26.6
  17F113)"; the harness stays the baselines doc's recorded microprobe methodology (a
  methodology change would invalidate cross-version deltas). SEAT ruling 2 (2026-07-02): "harness
  unchanged" freezes the METHODOLOGY, not stale spellings — pre-existing compile drift in the
  harness (e.g. `Allocator<…>.System` absorbed into the agent noun at 1153e09; init-label
  renames) is fixed by SAME-COLUMN re-spelling only, one line each + a note row in the
  baselines doc; a family whose drift proves SEMANTIC (not spelling) falls back to its 6.3.2
  rows as guardrails-of-record with a version caveat + a post-land re-pin obligation, the
  others proceed. Benchmarks/ packages are CONSUMERS: they join the §9.4 break-lists for the
  front-door spelling migration after their family lands.

### 9.6 Deletions and corrections (Q12)

| # | Item | Action |
|---|---|---|
| 1 | `Memory.Tracked.Protocol` (memory-tier `Store.Protocol`-refining shell; sole cause of the org's only package cycle) | DELETE target + umbrella re-export; relax `Buffer.Slab`'s constraint to `Store.\`Protocol\``; drop `swift-storage-primitives` dep from `swift-memory-primitives`; re-run `[MOD-032]` scan → 0 cycles (audit §4a recipe) |
| 2 | `Memory.Unique.Protocol` (orphaned: 0 conformers/consumers) | DELETE target + re-export; fix the one stale comment (`Buffer.Linear+Subscript.swift:12`) |
| 3 | `Storage.Generational: Buffer.\`Protocol\`` upward conformance (forbidden per [MOD-PLACE]; firstpass conf-95) | REMOVE; the generational count surface lives on the family's own observability extensions |
| 4 | Hand-written variant types: `Stack.Bounded`, `List.Linked.Bounded` (the two coda survivors) | DELETE for front-door aliases (W2 rows above) |
| 5 | `TreeDynamic` compound ergonomic alias | RETIRE for the `Tree<E>` front door ([API-NAME-001] hygiene) |
| 6 | Classifier's embedded 2026-06-18 LEDGER | VOID + regenerate at W0 |
| 7 | Stale doc lines: `Storage.swift` naming `swift-storage-arena-primitives` (renamed 2026-06); `Store.swift:38` ("Memory.Contiguous conforms Store.Protocol" — type dissolved 2026-06-23); `Memory.Small.swift:22` signature comment; fossil `*+Memory.Contiguous.Protocol.swift` filenames (audit F7) | FIX in the owning packages' W1/W2 dispatches |
| 8 | `Experiments/g2-allocator-store-seam` manifest referencing deleted `swift-store-primitives` | FIX path dep → `swift-storage-primitives` (experiment maintenance; findings unaffected) |
| 9 | Hash.Table sentinel tombstones (`empty=0, deleted=Int.min, rehash()` compaction) | MIGRATE to backward-shift + per-instance seed with the W2 engine work |
| 10 | [DS-003] rows naming `swift-tree-unbounded-primitives` types and other absent variants | Corrected by §4.6 |
| 11 | The P1 `storage-split→store-split` rename (staged, unexecuted) | RETIRE — `Storage.Split` is a Storage discipline; the name is correct as-is (the arena→generational half already executed) |
| 12 | Live DocC hole: hoisted tower decls (`__StoreProtocol`, `__BufferProtocol`, `__SetOrdered`, …) extract 0 symbols (underscore filter) | SWEEP `@_documentation(visibility: public)` onto every hoisted tower decl at W1 (panel-verified fix) |
| 13 | `Memory.Small.swift:17` doc says "elements" for a BYTE budget (substantive units error, not just a stale comment) | FIX with the [DS-028] units rule at W1 |
| 14 | The worked example's carrier omitted `@frozen` (caught by the library-evolution panel probe; fixed in-session, evolution emit now passes with `-package-name`) | DONE 2026-07-02 (experiment commit) |

### 9.7 The Swift 6.4 floor (SCHEDULED — the September release alignment)

**Principal ruling (2026-07-02): a Swift 6.4 minimum ecosystem version is acceptable, and the
release (= tagging) happens in September when 6.4 launches officially.** The floor is therefore
a SCHEDULED pre-release wave, not a hypothetical. Two boundaries hold: (a) **no decision in
this document depends on the floor** — every load-bearing mechanism is proven on shipping
6.3.3 (ratification parked on an unreleased toolchain is the prior program's failure mode #2
and is not repeated here); (b) the floor does NOT unlock the two walls people might assume it
does — `@_rawLayout` and `@_lifetime` remain experimental-flagged on release/6.4.x, so the
Wall-2 workaround and the D6 `~Escapable`-carrier trigger are unchanged by it.

The floor wave runs AFTER W5 and BEFORE the September tag, calendar-gated on the official
6.4 release. At the floor wave: `SuppressedAssociatedTypes` flag → SE-0503 default-on
(delete the flag); evaluate `_read`/`_modify` → SE-0507 `borrow`/`mutate` for *inline-backed*
vends (SE-0507 rejects pointer projection — heap-backed vends keep coroutines; SE-0474's
`yielding` spelling remains flag-gated even on 6.4, so no wholesale rename); `Comparison.\`Protocol\``
↔ SE-0499 `Comparable`-on-`~Copyable` reconciliation (single-point bound swap, recorded in the
skill); re-probe banked walls (W2 #86652, W5a borrow-pointer, W16 §A9, the η capacity-span
door); carrier `~Escapable` widening iff the D6 trigger has fired.

### 9.8 Round P interaction

Round P (publication; PUBLIC FLIP LAST, per-repo YES, NO tags) stays open and unchanged in
policy. The 2026-06-15 ADT-tier readiness blessings are **void for every package W1/W2
reshapes** (all ADT-tier packages) and **valid for untouched packages**; W5 re-blesses per
package on its post-reshape state. The "trees held out of the flip" ruling dissolves into the
normal W2/W5 flow (trees are reshaped like every family). FAM-012 is **not tower work** (a
codec-arc name collision — §10 ledger) and proceeds independently.

---

## 10. The supersession / prune ledger (Q11)

**Policy.** This document is the single surviving rationale for the tower. Every artifact below
receives one disposition:

| Disposition | Meaning |
|---|---|
| DELETE | purely historical/operational; nothing to extract; remove in the implementation session with normal git discipline (git history is the archive) |
| EXTRACT-THEN-DELETE | its load-bearing facts are carried into this document (section pointers in the tables); then remove |
| AMEND | normative or still-live artifact: update per §4/§9, never delete |
| KEEP-EVIDENCE | experiment / evidence artifact retained per the [EXP] lifecycle (FIXED-verdict guards, reproducers, receipts) |
| OUT-OF-SCOPE | not tower work (mis-listed in the prompt's universe); untouched by this ledger |

Reflections (`Research/Reflections/…`) are lifecycle-managed by reflections-processing, not this
ledger: rows below marked ALIVE/reflection stay in that corpus untouched.

Deletion authorization: this ledger IS the authorization; execution happens in implementation
wave W4 (§9.1) with explicit per-file adds and one commit per repo.

### 10.1 Normative (A.1) — all AMEND

`Skills/ecosystem-data-structures/SKILL.md` (install §4.1–4.6); riders per §4.7 in
`Skills/memory-safety/` ([MEM-COPY-016], [MEM-COPY-018], [MEM-SAFE-027], [MEM-SAFE-028]),
`Skills/modularization/SKILL.md` ([MOD-PLACE] note + [MOD-PLACE-DECOMPOSE] row),
`Skills/code-surface/SKILL.md` ([API-IMPL-021] data point; [API-IMPL-022]/[API-IMPL-023]
cross-reference refresh).

**Ruling supersessions (design-audit arc, 2026-07-03).** Two prior SEAT rulings are superseded
by this session's amendments:

- **M4** — the SEAT's 2026-07-02 "in-tower plumbing binds `__ColumnDirect` directly" ruling is
  superseded by the seam-tier `Store.Direct` typealias (§4.4 alias-law 1; §4.7 [API-IMPL-023] /
  [API-NAME-004] riders): in-tower conformance and where-clauses bind `Store.Direct`, so no dunder
  token ever appears in a public conformance clause, and the `Direct` marker is reclassified from a
  deletable [API-IMPL-023] convenience to a **load-bearing** required seam type — it IS the
  axis-drop fence the [DS-028] alias laws depend on. The SEAT ratified this supersession
  ("`Store.Direct` at the seam tier is strictly better… reclassifying the marker as load-bearing
  matches the fence's ratified role. Write the supersession note.").
- **M3** — the [DS-025] seam requirement `prepareForMutation()` is renamed `unshare()` (§4.1;
  §2 D3 seam table; §4.5 gate decree). The rename ships as ONE lockstep arc — rule text + skill
  rider (via skill-lifecycle) + the 42-site code change; any validator, skill, or source still
  spelling `prepareForMutation` after the wave is a defect.

### 10.2 Per-file dispositions (mined groups)

Detail provenance: per-file JSON ledgers produced by the 2026-07-02 corpus-mining workflow;
compacted here. "Extract carried" names what this document absorbed.


#### A.2 charter core (11 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `Research/adt-buffer-storage-decoupling-shape.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the F-A..F-I verified source-fact table (file:line, 2026-06-18); (2) the [MEM-COPY-018] same-type-pin caveat + the Step-2 union confirmation spec (builds x2 / 0-warn / … |
| `Research/universal-adt-shape.md` | EXTRACT-THEN-DELETE | Carry forward: the GATE-1 verdict table verbatim (positive x2 builds, negative controls with exact missing-conformance errors, keyed-storage admission, 0-witness SIL) with its /tmp/uadt +… |
| `Research/cross-layer-capability-protocol-model.md` | ALIVE | The backbone cross-layer model: minimal orthogonal cores, R/C/D edge kinds, specialization boundary, Set.Protocol elevation; amended with span lift and post-split store stack. |
| `Research/occupancy-lives-in-the-leaf.md` | EXTRACT-THEN-DELETE | Carry forward: the Law text verbatim + the placement matrix table; the located-bug file:line (Buffer.Slab.Header.swift:27 / Buffer.Slab.swift:53-57); the S2+S5 assembly argument and why S… |
| `Research/occupancy-encoding-1-adt-cell-layout.md` | KEEP-EVIDENCE | Cell-layout angle: Slot<E>=Optional<E> is the maximal ADT-layer point — A/C/D/E unconditional, B iff xi(E)>=1; measured niche taxonomy; manual bit-stealing escape. |
| `Research/occupancy-encoding-2-category-theory-composition.md` | KEEP-EVIDENCE | Category-theory angle: sparse store = product Store⊗Occupancy of orthogonal non-refining capabilities; refinement dissolved; teardown is a theorem; proven on 6.3.2. |
| `Research/occupancy-encoding-3-swift-typesystem-mechanisms.md` | KEEP-EVIDENCE | Mechanism frontier on 6.3.2: second @_rawLayout wall; InlineArray is the conditional-Copyable inline leaf (value-semantics seam only); macros cannot dissolve the carve-out. |
| `Research/occupancy-encoding-4-placement-proof.md` | KEEP-EVIDENCE | Proves the tower as a theorem: information floors, three-placement lattice, 16-cell matrix with unique excluded cell 14, collapsed only by a conditional deinit. |
| `Research/occupancy-encoding-5-prior-art-and-vacuity.md` | KEEP-EVIDENCE | Cross-language survey + consumer census: the excluded corner is the universal one among copyability-coupled languages, and zero real institute consumers inhabit it. |
| `Research/conditional-deinit-conditionally-copyable-generics.md` *(unlisted)* | KEEP-EVIDENCE | The Wall-1 proof and S1-S8 probe matrix the whole occupancy panel consumes as axioms; SLR across compiler source, Evolution, Forums, Rust, C++; PITCH-0003 held. |
| `Research/buffer-namespace-membership-occupancy-vs-region.md` *(unlisted)* | ALIVE | Occupancy membership test (count != capacity) over the Buffer.* namespace; Aligned/Unbounded -> Memory recommended (HELD); Buffer.Slots verdict reversed 2026-06-03. |

#### A.2 storage/memory research (22 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `storage-memory-split.md` | AMEND | Ratified #3 packet: un-fuses Storage<E>.Heap into Storage.Contiguous<Memory.Heap<E>> discipline-over-leaf; inserts Store.Tracked.Protocol; ledger relocates to store-primitives; Phase E ex… |
| `storage-small-substrate.md` | AMEND | Cleave-3 end-state packet: one generic hybrid Storage<E>.Small<let n> (inline ≤ n ⊕ heap spill) absorbing 12+ hand-rolled variants; verbose spellings; Heap alias retirement. |
| `storage-arena-architecture.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the deinit-ordering guarantee (class deinit body before stored-property destruction) as the soundness basis for class-composing-~Copyable-allocator leaves; (2) the 2-vs… |
| `storage-buffer-abstraction-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) Rust Storage API 2+year non-stabilization as adversarial evidence; (2) the multiplicity-polymorphism / structural-incompatibility theorem and its framing of the Copyabl… |
| `storage-primitives-comparative-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the seven-dimension evaluation framework and final scorecard as a dated baseline; (2) the three novelty claims (typed coordinates, automatic per-slot tracking, tracked … |
| `memory-contiguous-dissolution.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the element-free Memory tier as current law (Memory.Contiguous dissolved; jobs split to Memory.Heap / Storage.Contiguous / bare Swift.Span); (2) the provenance law + th… |
| `memory-storage-composition-feasibility.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the zero-runtime-cost bridging fact (retag/assumingMemoryBound compile away) as the enabling condition for typed-over-raw composition; (2) the F4 virgin-cursor O(n)→O(1… |
| `store-capability-elimination.md` | EXTRACT-THEN-DELETE | Carry forward INTO the re-derivation (this is core Q-input): the three findings with receipts (type-selected allocation at 0 witness; contiguous-constrained static bulk-path selection; le… |
| `store-inline-span-vs-in-place-pointer.md` | AMEND | ACCEPTED 2026-06-09: add Span/MutableSpan accessors to Store.Inline (safe whole-region surface); NOT pointer-free on 6.3.2; no type-level inline/heap unification. |
| `owned-typed-memory-region-abstraction.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the region-capability vs element-capability formal boundary (BitwiseCopyable = bulk-dealloc soundness line) — load-bearing for where Memory ends and Storage begins; (2)… |
| `memory-foreign-and-memory-protocol.md` | ALIVE | Memory.Foreign (provider-released foreign memory, finalizer-only ~Copyable envelope) + verdict: Memory.Region IS the memory-tier protocol; buffer-tier heap pins fence out all non-heap reg… |
| `sequence-storage-integration-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the underestimatedCount dual-conformance disambiguation requirement; (2) the Property.View-fails-on-temporaries / non-mutating-Sequence-works finding and the Ones.Stati… |
| `copyable-wrapper-vs-multi-buffer-storage.md` | KEEP-EVIDENCE | Cross-cutting finding from swift-json v2: Copyable wrapper × multi-buffer hash storage compounds refcount-per-copy; isolated micro-benches can invert; integration probe required. |
| `pool-bounded-storage-refactor.md` | DELETE | Feb-2026 recommendation: Pool.Bounded's parallel arrays use Array<Slot>.Fixed + Array<Entry>.Fixed.Indexed<Slot> (Option A) to eliminate 30+ .rawValue sites. |
| `memory-buffer-allocator-institute-vs-apple-comparative.md` | KEEP-EVIDENCE | Round-2 comparison vs apple/swiftlang: convergent substrate by deliberate reuse; divergent public typed allocator/arena vocabulary; Memory.Allocator.Protocol dormant; ~10 stale institute … |
| `apple-swiftlang-memory-buffer-allocator-survey.md` | KEEP-EVIDENCE | Round-1 external survey: Span family is the centerpiece; verified absence of any stdlib allocator abstraction; recurring CoW storage idiom; lifetime annotations experimental. |
| `memory-pool-arena-buffer-usage-analysis.md` | DELETE | Note for the pruner: [META-005] currently mandates retain-in-place for superseded docs (banner present, index-filtered). Physical deletion requires either a [META-005] amendment or accept… |
| `apple-swiftlang-arena-allocator-family-implementations.md` *(unlisted)* | KEEP-EVIDENCE | Deep-dive of nine apple/swiftlang arena/allocator implementations: slab-list bump dominant; three free disciplines; single-threaded by construction; no public abstraction. |
| `memory-byte-bit-domain-orthogonality.md` *(unlisted)* | AMEND | Normative axis model: Memory = location/layout axis orthogonal to Bit→Byte→Binary; span vending lifted to namespace-neutral Span.Protocol; memory↔bit essential, memory↔byte not a tie. |
| `memory-cursor-generic-witness-demangle-reshape.md` *(unlisted)* | KEEP-EVIDENCE | Compiler wall: corrupt associated-type-witness mangled name for deep generic Memory.Cursor<Buffer<A>.Linear.Inline<8>>; element-only-generic snapshot witness is the only validated dodge. |
| `memory-domain-cross-package-inventory.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry forward: (1) the wrap-not-redefine law for kernel-over-memory (Tagged phantom wrapping, conversions at the seam); (2) the three-namespace disambiguation (Memory / Kernel.Memory / Ke… |
| `nonescapable-support-memory-storage-buffer.md` *(unlisted)* | AMEND | DECISION: ~Escapable boundary already correct at Span/Property.View layer; no owning type becomes ~Escapable; 126-package scan found no missed opportunities. |

#### A.2 buffer/container research (19 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `buffer-namespace-membership-occupancy-vs-region.md` | EXTRACT-THEN-DELETE | Carry: (1) the occupancy test (count!=capacity) WITH the Slots caveat that it mis-fires for metadata-parametric disciplines whose occupancy delegation is by-design; (2) count==capacity ve… |
| `buffer-storage-associatedtype-prior-art.md` | KEEP-EVIDENCE | Cross-language survey: exposing storage as an associated type on a buffer protocol (T1) is anti-precedented; capability/concept (T4) is the universal shape. |
| `buffer-arena-conditional-copyable.md` | EXTRACT-THEN-DELETE | Carry: SE-0390 deinit law; Storage.Initialization 1-2-contiguous-ranges limit as the mechanism that forces sparse disciplines to own a deinit; the taxonomy 'copyability flows from where t… |
| `comparative-buffer-primitives.md` | EXTRACT-THEN-DELETE | One line survives: typed buffer disciplines do not subsume untyped variable-length slot pools; raw-memory consumers (IO) correctly bypass the buffer tier for Memory.Pool - a layering datu… |
| `binary-buffer-primitives-architectural-review.md` | DELETE | Deleted swift-binary-buffer-primitives; moved Buffer.Aligned/Unbounded into buffer-primitives constrained where Element == UInt8; pure-Swift allocation. |
| `canonical-buffer-discipline-cross-language-survey.md` | KEEP-EVIDENCE | 8/8 languages make contiguous/linear the default growable buffer; recommends doc-only canonical designation (D3) of Buffer.Linear, owner stays pure substrate. |
| `iterator-span-buffer-elimination.md` | EXTRACT-THEN-DELETE | Carry: Optional-payload-at-offset-0 ABI pattern (with the withUnsafeMutablePointer-only constraint and V2 refutation); the 2-3x single-element-beats-batch benchmark with the array-managem… |
| `container-protocol-lattice-borrowing-iteration.md` | ALIVE | Audit-#5 root cause: move-only columns lost Collection/Iterable via a conformance-bundling bound, not a structural wall; probe clears { get } as borrow on 6.3.2. |
| `slot-map-prior-art-and-the-generational-seam.md` | ALIVE | Prior art settles it: the Handle API IS the generational seam - never conform Store.Protocol; SlotMap composes as a pinned-column family; slot-scan iteration. |
| `hashed-container-substrate-archaeology.md` | ALIVE | Stdlib+swift-collections hashed-storage archaeology: single-allocation sparse leaf confirmed at industrial scale; two lawful hashed compositions for the tower. |
| `stdlib-array-family-source-archaeology.md` | ALIVE | Array-family archaeology across 6.3.2/6.4.x/main: Array is Copyable-only everywhere; facade has zero precedent; drain-box and span-canonical confirmed stdlib-convergent. |
| `layer-container-orphan-triage.md` | DELETE | NOT a data-structure doc: superrepo-dismantle orphan triage (layer-CONTAINER directories); relocations executed and rules codified into skills. |
| `tree-primitives-buffer-arena-migration.md` | EXTRACT-THEN-DELETE | Carry: the linear-deinit correctness argument (value-type index links => container owns all nodes => arena-order drain is always sound; a general tower principle for node-linked structure… |
| `nonescapable-support-memory-storage-buffer.md` | EXTRACT-THEN-DELETE | Carry: the lexical-vs-dynamic law (integer-address provenance-free => ~Escapable is the wrong tool); the containment-cascade argument against ~Escapable containers; the closure-gap bounda… |
| `nonescapable-storage-mechanisms.md` | DELETE | Already-superseded: why heap-backed containers cannot store ~Escapable elements (implicit Escapable on pointer Pointee); enum-based small-capacity workaround. |
| `derive-for-free-capability-composition.md` | ALIVE | The pre-tower capability-composition law: minimal cores, one bridge per capability, four-part warranted-refinement test, GAP ledger A-O with landed commits. |
| `copyable-wrapper-vs-multi-buffer-storage.md` *(unlisted)* | KEEP-EVIDENCE | Cross-cutting extraction of the swift-json v2 failure: Copyable wrapper x multi-buffer hash storage pays refcount-per-copy per heap component; default single-array. |
| `linked-list-cursor-and-arena-backing-improvements.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the positional-cursor gap (remove(at:)/insert(after:)) as a live ADT-families surface requirement IF still unlanded (verify against current Buffer.Linked); note that the ABA gap re… |
| `handle-vs-arena-position-unification.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry one line into the tower's handle-carrier design question: three (index, generation) handle shapes now coexist (Handle<T> 8B, Buffer.Arena.Position 8B, Store.Generational.Handle 16B)… |

#### A.2 program docs + reflections (28 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `Research/tower-family-benchmark-baselines.md` | KEEP-EVIDENCE | Regression guardrails = the ENTIRE file (embedded verbatim in verbatimContent). If the successor doc absorbs it, carry §Method (comparability conditions), all §Baselines tables incl. the … |
| `Research/tower-research-arc-riders-2026-06-10.md` | EXTRACT-THEN-DELETE | Carry forward: (a) the R-6 dossier pointer (Experiments/cow-box-deinit-omission-miscompile, 2e2f7f1+113c711) + full mitigation matrix + draft-issue skeleton; (b) the §3 gate-bump table ve… |
| `Research/bounded-discipline-analysis.md` | EXTRACT-THEN-DELETE | Carry: the three-senses disambiguation; the Bucket-B seven-row inventory with file:line; the 7x overflow-spelling table; the Stack.Bounded minimum-vs-exact finding; the validated 6.3.2 co… |
| `Research/bounded-discipline-algebra.md` | EXTRACT-THEN-DELETE | Carry the whole §1-§6 algebra (short, self-contained): truncated-sum definition; representation-vs-morphism split; Never=0 seam soundness + 6.3.2 probe; the L x G lattice + quotient; the … |
| `Research/variant-naming-audit.md` | EXTRACT-THEN-DELETE | Carry: the §1 academic definitions table (Dijkstra/Knuth/SBO — reusable grounding); the §2.2 copyability rule; the §2.4 compiler-wall records with #86652; the Inline-vs-Static layer conve… |
| `Research/decomposition-layer-placement-package-map.md` | EXTRACT-THEN-DELETE | Carry: the two-wall record (SE-0427 law; #86652 IRGen bug + sole-workaround warning + double-workaround SIGSEGV) with its authority pointers; the ee9aa41 Index.Bounded misdiagnosis lesson… |
| `Research/data-structures-variant-catalog-data-structures.md` | EXTRACT-THEN-DELETE | The full claimed variant list (embedded verbatim in verbatimContent) is the extract — preserve as the dated April-2026 declaration-surface snapshot; its delta vs the live tree quantifies … |
| `Research/data-structures-variant-catalog-infrastructure.md` | EXTRACT-THEN-DELETE | Full claimed type list embedded verbatim in verbatimContent (dated snapshot; staleness is the finding). The per-package type-count summary table is the compact carry-forward. |
| `Research/data-structures-variant-catalog-parsers.md` | EXTRACT-THEN-DELETE | Full claimed type list embedded verbatim in verbatimContent (dated snapshot). Least tower-load-bearing of the four catalogs; re-derive parser-domain inventories from the tree if ever needed. |
| `Research/data-structures-variant-catalog-systems.md` | EXTRACT-THEN-DELETE | Full claimed type list embedded verbatim in verbatimContent (dated snapshot); the queue-family delta vs the tree is the sharpest single staleness exhibit in the group. |
| `Research/ecosystem-data-structures-inventory.md` | AMEND | Tier-1 DECISION catalog (v1.0.0, 2026-03-24) of 50+ data-structure types with variant system, decision guide, and the Memory->Storage->Buffer->Collection composition model. |
| `Research/decomposition-layer-placement-calculus.md` *(unlisted)* | KEEP-EVIDENCE | The placement calculus (v1.0.0, 2026-06-05): first-principles ontology of the four tower layers, six-step placement procedure, formal typing rules, case-study validation, [MOD-PLACE] basis. |
| `Research/data-structures-umbrella-mapping.md` *(unlisted)* | DELETE | Definitive umbrella-product/Core-target/variant-product mapping for 29 multi-product swift-primitives packages (April-era; product names use spaces, modules underscores). |
| `Research/data-structures-umbrella-violations.md` *(unlisted)* | DELETE | Point-in-time umbrella-import violation scan (2026-04-03): 471 violations (272 Package.swift deps + 199 source imports) across 93 packages. |
| `Research/data-structures-associative-hashing-assessment.md` *(unlisted)* | DELETE | Post-refactor v2 audit (DECISION, 2026-02-12) of the four associative/hashing packages after the Feb Buffer/Storage/Memory stack migration. |
| `Research/data-structures-bit-collections-assessment.md` *(unlisted)* | DELETE | Post-refactor audit (RECOMMENDATION, 2026-02-12) of five bit packages; found Bit.Vector.Static.isFull semantic bug and bitset's zero ecosystem integration. |
| `Research/data-structures-linear-collections-assessment.md` *(unlisted)* | DELETE | Post-refactor v2 audit (DECISION, 2026-02-12) of array/list/stack/queue/deque packages against the freshly refactored buffer/storage/memory stack. |
| `Research/data-structures-priority-hierarchical-assessment.md` *(unlisted)* | DELETE | Post-refactor v2 audit (DECISION, 2026-02-12) of Heap/Tree/Graph: v1 had Heap 98% migrated, Tree unmigrated (raw ManagedBuffer); v2 records all three fully updated. |
| `Research/data-structures-resource-management-assessment.md` *(unlisted)* | DELETE | Post-refactor v2 audit (RECOMMENDATION, 2026-02-12) of Pool/Slab/Cache packages against the refactored stack. |
| `Research/data-structures-remediation-batch-1.md` *(unlisted)* | DELETE | Remediation worklist batch 1 (generated 2026-04-03) for the umbrella-import violation scan. HIGH: missing variant products (Sequence/Affine/Queue Core) blocking umbrella narrowing in buff… |
| `Research/data-structures-remediation-batch-2.md` *(unlisted)* | DELETE | Remediation worklist batch 2 (generated 2026-04-03) for the umbrella-import violation scan. HIGH: slab + peers — per-file umbrella-dep replacements. |
| `Research/data-structures-remediation-batch-3.md` *(unlisted)* | DELETE | Remediation worklist batch 3 (generated 2026-04-03) for the umbrella-import violation scan. HIGH: finite + peers — canonical-umbrella filtering then replacements. |
| `Research/data-structures-remediation-batch-4.md` *(unlisted)* | DELETE | Remediation worklist batch 4 (generated 2026-04-03) for the umbrella-import violation scan. MEDIUM+LOW: all packages with <=10 violations; lists packages clean after canonical filtering. |
| `Research/Reflections/2026-06-04-msb-capability-tower-w3-endgame.md` *(unlisted)* | KEEP-EVIDENCE | PROCESSED reflection (2026-06-04): MSB W3 re-layering endgame findings banked; already triaged into skill updates incl. [MEM-COPY-016], [PKG-BUILD-013..015], [MEM-SPAN-004]. |
| `Research/Reflections/2026-06-04-supervisor-seat-msb-endgame-multi-arc-board.md` *(unlisted)* | ALIVE | PENDING seat reflection (2026-06-04): held supervisor seat for the MSB endgame merge->publish->push and the post-program multi-arc board through seat succession. |
| `Research/Reflections/2026-06-07-seat-cleave-8-closure-handoff-push-window-enumeration.md` *(unlisted)* | ALIVE | PENDING seat reflection (2026-06-07): Cleave-8 closure — ratified Item A (Memory.Unbounded dissolved; Memory.Aligned becomes the growable aligned leaf); handoff push-window under-sizing l… |
| `Research/Reflections/2026-06-12-tower-phase-3-seat-closeout.md` *(unlisted)* | ALIVE | PENDING seat reflection (2026-06-12): phase-3 weakness-sweep closeout — engine-fix legs independently reproduced, policies codified, phase-4 plan ratified, baselines published. |
| `Research/Reflections/2026-06-13-tower-phase-4-seat-round-m-supervision.md` *(unlisted)* | ALIVE | PENDING seat reflection (2026-06-13): Round M rulings R-1..R-19 — parity-token plane, variant-doctrine census (4 convicted), rename CANCELLED, Tree<Children> briefed, Round P baton. |

#### A.3 audits (8 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `Audits/AUDIT-adt-decoupling-status.md` | EXTRACT-THEN-DELETE | Carry: the corrected shape census (at-target 2 / foundational 9 / concrete 10 / N-A 2; pins<=>foundational); the Swift 6.3.2 swift-frontend SIGSEGV wall on namespaced generic typealiases … |
| `Audits/tower-layering-status-quo-2026-06-22.md` | EXTRACT-THEN-DELETE | Contents already known to the orchestrator per depth guidance (F1 memory<->storage sole org cycle; F2 Memory.Tracked misplacement as root cause; F3 Memory.Unique orphan; F4 Memory.Contigu… |
| `Audits/AUDIT-layering-violations-firstpass.md` | EXTRACT-THEN-DELETE | Carry: the 8 violation patterns; top-confidence rows with file:line (Memory.Contiguous 95; Storage.Generational:Buffer 95 + Shared:Buffer 70; Buffer.Slab occupancy-in-buffer 92/90; typed-… |
| `Audits/AUDIT-round-m-warts.md` | ALIVE | W-1's resolution (handle(at:) = permanent decode seam, tree family sole consumer, [ARCH-LAYER-006] domain-completeness rationale) belongs in the re-derived tower doc's Storage.Generationa… |
| `Audits/borrow-pointer-storage-release-miscompile.md` | KEEP-EVIDENCE | 2026-04-24 compiler-miscompile investigation: withUnsafePointer(to: borrowing ~Copyable) returns a dead spill-slot in release; workarounds shipped; V11 watchflag; unfiled upstream. |
| `Audits/unsafe-pointer-inventory.md` *(unlisted)* | ALIVE | 2026-06-30 Phase-1 ecosystem inventory of Unsafe*/unsafe usage across 395 packages; ~98% SURVIVE at the expected raw floor; Phase-2 reduction gated on principal sign-off. |
| `Audits/HANDOFF-buffer-linear-consumer-migration.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the confirmed [MOD-027] internal-import+@inlinable diagnostic wall; the principal-ratified 2026-05-24 umbrella decision (base ops = umbrella, variants don't re-export base, [MOD-03… |
| `Audits/HANDOFF-memory-cohort-extraction.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the Memory scope statement (Address/Alignment/Allocation/Shift core; strategies/sync/IPC/OS are consumers) TOGETHER WITH the note that its typed Contiguous/Inline clause was supers… |

#### A.4 experiments (16 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `Experiments/adt-over-buffer-seam` | KEEP-EVIDENCE | Validates the ADT-over-concrete-buffer sketch: conditional extension reaching storage through B.Storage nested associated type compiles, specializes-class-wise, and avoids known crash zon… |
| `Experiments/g2-allocator-store-seam` | KEEP-EVIDENCE | G2 seam probes: fixed-slot Pool conforms typed Store.`Protocol` (occupancy out-of-band); bump Arena cannot and stays raw Memory.Allocator.`Protocol`; dense-over-sparse wrap is a type-chec… |
| `Experiments/sparse-inline-slot-storage` | KEEP-EVIDENCE | Cleave-9 gate G1 bed: InlineArray<N, Slot<E>> self-cleaning slot storage clears all four must-resolve risks for deleting @_rawLayout .Inline/.Small leaves, at the cost of an InlineArray d… |
| `Experiments/storage-variant-patterns` | EXTRACT-THEN-DELETE | Carry forward: (1) the four-strategy taxonomy names and their storage backings (Static=InlineArray/@_rawLayout inline; Bounded=fixed heap; growable=base type name; Small=inline+heap spill… |
| `Experiments/storage-protocol-specialization` | KEEP-EVIDENCE | GATE-1 receipt: a generic core over `some StorageProtocol` (~Copyable, suppressed associated Element) fully specializes in release across a module boundary — 0 witness_method on the hot p… |
| `Experiments/borrow-pointer-storage-release-miscompile` | KEEP-EVIDENCE | Confirmed 6.3.1/6.4-dev release-mode miscompile: withUnsafePointer(to:) over a borrowing ~Copyable value (and over a stored field of self) yields dangling pointers when stored; Memory.Inl… |
| `Experiments/noncopyable-storage-poisoning` | DELETE | Superseded isolated repro: conditional `extension Storage: Sequence where Element: Copyable` poisons a ~Copyable-generic Storage's stored-property access; absorbed into noncopyable-constr… |
| `Experiments/nonescapable-closure-storage` | DELETE | Superseded probe: ~Escapable types CAN store @escaping closures under @_lifetime(immortal); borrow-lifetime capture and @_lifetime-on-Escapable-closure rejected; absorbed into nonescapabl… |
| `Experiments/pointer-nonescapable-storage` | EXTRACT-THEN-DELETE | Carry forward from REVALIDATION-6.3.md: (1) full still-blocked matrix on 6.3.0 — V1 UnsafeMutablePointer<~Escapable>, V2b initializeMemory, V2c assumingMemoryBound, V6/V7/V8/V11 Optional … |
| `Experiments/conditional-escapable-container` | KEEP-EVIDENCE | PARTIAL: conditional-Escapable works for single-element Box/Pair/nested compositions; heap-backed and Optional-slot multi-element containers blocked by three walls, all still present on S… |
| `Experiments/nonescapable-patterns` *(unlisted)* | KEEP-EVIDENCE | EXP-018 consolidation package (2026-04-02): 7 ~Escapable experiments merged (accessor, closure storage, gap revalidation, cross-module protocol, lazy sequence, pointer storage, contiguous… |
| `Experiments/noncopyable-constraint-behavior` *(unlisted)* | KEEP-EVIDENCE | EXP-018 consolidation (2026-04-02, absorbed 8): canonical home for Sequence-conformance constraint poisoning and cross-module propagation evidence; supersession target for noncopyable-sto… |
| `Experiments/cow-box-deinit-omission-miscompile` *(unlisted)* | KEEP-EVIDENCE | Confirmed 6.3.2 release miscompile in the tower's Storage<Allocation>.Contiguous<Element> shape: after isKnownUniquelyReferenced, -O destroy omits the nested ~Copyable struct's user deini… |
| `Experiments/copyable-wrapper-refcount-cost` *(unlisted)* | KEEP-EVIDENCE | Benchmarks the Copyable-wrapper K-refcount cost model: invisible under trivial isolation (V1 elided to fs-scale) but K-linear ~7.68 ns/heap-component under an optimizer-resistant probe (V… |
| `Experiments/escapable-slot-inlinable-sqe` *(unlisted)* | KEEP-EVIDENCE | Slot-type prior art: ~Copyable ~Escapable slots over pointer-backed (mmap'd) memory work only through coroutine yield (_read/_modify) — the coroutine scope is the lifetime boundary; retur… |
| `Experiments/noncopyable-multifile-poisoning` *(unlisted)* | DELETE | Superseded companion to noncopyable-storage-poisoning: moving the conditional Sequence conformance to a separate file still poisons the ~Copyable container's stored properties at module l… |


**Resolution of rows the miners marked ALIVE** (they bind here as follows):
`cross-layer-capability-protocol-model.md` → AMEND (stays the cross-family capability-model
backbone; its tower-specific sections are superseded by §2 D3 — add the supersession banner);
`derive-for-free-capability-composition.md` → AMEND (compose-first law survives; its
`Buffer.Protocol`-era examples are stale per §4.6); `container-protocol-lattice-borrowing-iteration.md`
→ AMEND (the SE-0516-tracking lattice doc; live upstream dependency);
`stdlib-array-family-source-archaeology.md`, `hashed-container-substrate-archaeology.md`,
`slot-map-prior-art-and-the-generational-seam.md` → KEEP-EVIDENCE (source-archaeology references
cited by §6/§9.3); `memory-foreign-and-memory-protocol.md` → AMEND (Memory.Foreign is a live
non-tower arc; only its tower-integration section cites this doc); `buffer-namespace-membership-…`
→ EXTRACT-THEN-DELETE (its 18-conformer inventory predates the dissolution; the surviving fact —
Aligned/Unbounded are raw regions, GAP-O — is carried in §9.3/§10.4);
`AUDIT-round-m-warts.md`, `unsafe-pointer-inventory.md` → KEEP-EVIDENCE (active audits with open
phases); the four seat reflections → reflections corpus (out of this ledger).

### 10.3 Operational archive (A.5, ~150 files in `~/Developer/.handoffs/`)

**Concurrent-execution note (2026-07-02)**: while this document was being written, a parallel
session retired **94** of these files to `.handoffs/.trash/` (suffix `-retired-20260702`) —
including the whole Round M report chain, the cleave GOALs, the msb end-state, and the
memory-tier handoffs. Their dispositions below are therefore confirmed post-hoc rather than
pending; the extracts this document carries were mined from the live files earlier the same
day (the W5-coda report was read live at 09:10). The `.trash/` purge itself remains a W4 item.

Grouped dispositions; the named rows are the exceptions. Everything in A.5 not named below:
**DELETE** (operational choreography whose surviving facts are §2–§9 of this document and the
per-file tables above).

| Group / file | Disposition | Extract carried |
|---|---|---|
| `PROMPT-adt-tower-rederivation.md` | EXTRACT-THEN-DELETE | discharged by this document (its Appendix A = this §10's universe) |
| `HANDOFF-tower-SEAT.md` (+ archives), `SEAT-precensus-round-m.md`, `msb-tower-PROGRESS.md`, `OVERVIEW-tower.md` | EXTRACT-THEN-DELETE | program state → §9.8; the SEAT chain's standing rulings (never-file-upstream; PUBLIC-FLIP-LAST; never-push-until-flip) remain in force via memory/skills, not via these files |
| `PROPOSAL-tower-perfected-design.md` | EXTRACT-THEN-DELETE | R-1..R-7 (move-only substrate; Shared at the ADT tier; S5 chain; drain-box R-5) → §2 D6; R-6 reproducer → KEEP-EVIDENCE (experiment) |
| `REPORT-layering-harvest-ledger.md` | EXTRACT-THEN-DELETE | the 4-owner basis + C1–C7 forks → §2 D1, §9.6 |
| `GOAL-msb-tower-end-state.md`, `HANDOFF-tower-{endstate,design-perfection}.md`, `HANDOFF-msb-tower-followups.md` | DELETE | superseded end-states; their D1–D6 rulings are re-derived or overturned in §2 |
| five-layer arc (`tower-five-layer-findings-report.md`, `tower-migration-plan-skeleton.md`, `tower-type-signature-inventory.md`, `HANDOFF-five-layer-tower-nesting-review.md`) | DELETE | superseded by D1 (§8.9) |
| cleave arcs (`*cleave*`: GOALs, PROGRESS, HANDOFFs) | EXTRACT-THEN-DELETE | walls provenance (bd04f32 tri-toolchain re-probe; #86652 WA matrix — substrate-WA/double-WA/H1 shapes; the CoW overload-specificity defect; family-2 range-ledger root cause; the §B 50-package DAG verification) → §3, §5.4; receipts stay in `.probe-bank`/Experiments (KEEP-EVIDENCE) |
| occupancy/allocation/memory-tier handoffs (`*occupancy*`, `*allocation*`, `*memory-tier*`, `HANDOFF-buffer-arena-pool-repair.md`, `HANDOFF-slab-occupancy-seat.md`, `RULING-allocation-arc-recharter.md`) | DELETE (pending-resume rows may add named extracts) | the leaf law + allocation triple live in [DS-023]/[MOD-PLACE]/[API-IMPL-023] already |
| storage/buffer/charter handoffs (`HANDOFF-buffer-storage-protocols.md`, `HANDOFF-buffer-protocol-v2.md`, `HANDOFF-storage-protocol-*`, `HANDOFF-storage-consolidation.md`, `HANDOFF-storage-inline-finalization.md`, `SCOPING-store-ledgered-dissolution.md`, `HANDOFF-pool-resplit.md`, `HANDOFF-adt-shape-research.md`, `GOAL-tower-adt-families.md`, `REPORT-ADT-families-*`, `REPORT-hash-indexed-surfacing.md`) | EXTRACT-THEN-DELETE | seam evolution + F-3/F-4 walls + the families-tranche record + hash-engine decisions → §2 D3, §3, §9.3; `Store.Ledgered` cap + Round-C review → §2 D3 |
| Round M (`*round-m*`, `GOAL-tower-arc-*`, `REPORT-arc-*`, `HANDOFF-tower-flag-day-migration.md`, `HANDOFF-tower-{cross-module,rich-fidelity,reference-slice}*`) | DELETE — already retired to `.trash/` by the parallel session (see the note above); extracts carried via the seat/cleave/program tables + the live W5-coda read | wave outcomes already carried: variant-dissolution coda → §1.2/§8.5; R-19 η door + banked re-probe → §9.7 |
| Round P (`GOAL-tower-round-p.md`, `GOAL-round-p-adt-tier.md`, `REPORT-round-p-*`) | EXTRACT-THEN-DELETE | staged state + PUBLIC-FLIP-LAST → §9.8 |
| tree recomposition (`GOAL-tree-recomposition*`, `HANDOFF-tree-{charter-adoption,universal-shape,core-v2-rebuild}.md`, `REPORT-tree-recomposition-*`) | EXTRACT-THEN-DELETE | the never-closed V2 gate is discharged (§8.2; the worked example is the replacement validation); Tree's at-target state → §9.3 |
| FAM-012 files (`*fam012*`) | OUT-OF-SCOPE | name collision: the family-codable codec arc, not tower work; proceeds independently (§9.8) |
| `HANDOFF-decomposition-layer-placement.md`, `HANDOFF-strata-package-map.md`, `HANDOFF-bounded-proliferation.md`, `LEDGER-modernization-deferred.md`, probe/log dirs, `.trash/` | DELETE (probe-bank receipts cited by experiments: KEEP-EVIDENCE) | placement calculus already canon in [MOD-PLACE]; bounded algebra → §2 D4.4 |

Per-file detail (recovered ledgers; where a file was since retired to `.trash/` the
disposition below is confirmed post-hoc):

#### A.5 detail — SEAT chain / overview / design (21 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `.handoffs/PROPOSAL-tower-perfected-design.md` | EXTRACT-THEN-DELETE | Carry: (1) the §1.4 miscompile fact + drain-box rule [MEM-SAFE-028] + repro pointers (Experiments/cow-box-deinit-omission-miscompile, swiftlang#89832); (2) both §1.3 SE-0427 spe… |
| `.handoffs/REPORT-layering-harvest-ledger.md` | EXTRACT-THEN-DELETE | Carry verbatim: §1 converged core (the 4-owner one-axis law), §3 full fence list (Walls 1/2, @_rawLayout⇒~Copyable, excluded cell, ~Escapable limits, MEM-COPY-018, 0-witness/spe… |
| `.handoffs/GOAL-msb-tower-end-state.md` | EXTRACT-THEN-DELETE | Carry: the D1 correction pair (a conditionally-Copyable inline struct cannot self-deinit so even the non-ARC inline leaf must expose a live-extent ledger; the .empty/.one/.two r… |
| `.handoffs/HANDOFF-tower-SEAT.md` | EXTRACT-THEN-DELETE | Carry: ruling 12 verbatim (protocol-minimal + Store.Ledgered high-water/dissolution-candidate); the 2026-06-18 universal-shape pivot record + GATE-1 empirics (0 witness_method p… |
| `.handoffs/HANDOFF-tower-SEAT-archive-2026-06-12.md` | EXTRACT-THEN-DELETE | Carry: #89832 filing record + never-file policy; the Shared strategy-less-init CoW trap + [MEM-COPY-017] pair-split rule; B-7/B-8/B-1′ engine numbers (Θ(cap) sweep, ~3.9ns box i… |
| `.handoffs/HANDOFF-tower-SEAT-archive-2026-06-13.md` | EXTRACT-THEN-DELETE | Carry: §A9 refutation (guards = true-vector survivors, SIGSEGV on clean 6.3.2); grow-door DELTA metric lesson; §A13/#89617 phantom-generic hoist mechanics + R-3 no-compounds poo… |
| `.handoffs/SEAT-precensus-round-m.md` | EXTRACT-THEN-DELETE | Carry two evergreen facts: (1) protocol-cannot-nest-in-generic-type restriction forcing non-generic noun homes for tower vocabulary; (2) §A13 phantom-generic -O assert affected … |
| `.handoffs/OVERVIEW-tower.md` | DELETE | Seat-maintained plain map, snapshot 2026-06-13 (Round M closed, Round P open); explicitly a map not a source of truth; duplicates rulings held elsewhere. |
| `.handoffs/HANDOFF-tower-endstate.md` | DELETE | Cleave-3 dispatch brief (2026-06-05): Storage<E>.Small hybrid substrate + verbose truth-spelling flip + alias retirement; self-ratification addendum and parallelization rules. |
| `.handoffs/HANDOFF-tower-design-perfection.md` | DELETE | Brief that commissioned the perfected-design session (2026-06-09): diagnosis that value semantics silently fell out of the tower; PRIORITY-1 copyability fork Option1 vs Option2. |
| `.handoffs/HANDOFF-msb-tower-followups.md` | EXTRACT-THEN-DELETE | Carry: ring slot-subscript addressing law + trap provenance; the 13-not-7 consumer-enumeration lesson (grep + manifest walk, digit-inclusive); F1 mirror-first + F2 stale-shared-… |
| `.handoffs/msb-tower-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry: Findings 1/11 (restate-every-suppressed-param), 2 (Swift.Span shadow), 3/8 (MemberImportVisibility/public import), 6 (UInt8→typed cascade idiom); the bd04f32 wall verbati… |
| `.handoffs/tower-five-layer-findings-report.md` | EXTRACT-THEN-DELETE | Carry: the three-level grounding + Layer Admission Rule (as prior-art framing for Q1); R2's convenience-not-foundational statement + Caveat A (extension IS a constraint; load-be… |
| `.handoffs/tower-migration-plan-skeleton.md` | DELETE | Pre-spike migration skeleton (P1–P5 phases); every Buildability/Risk/Tests line PENDING SPIKE; fully superseded by the executed W1–W5 program. |
| `.handoffs/tower-type-signature-inventory.md` | EXTRACT-THEN-DELETE | Carry: the `:`-vs-`==` constraint rule with shipping-precedent counts (9 heap pins, 53 arena pins); the Element-welded-twice arity finding; the never-built Storage.Protocol fact… |
| `.handoffs/HANDOFF-five-layer-tower-nesting-review.md` | EXTRACT-THEN-DELETE | Carry into Q3 (capability model): Caveat A verbatim (extension IS a constraint; load-bearing vs deletable axis); the no-third-option duplication-vs-bound trade; Caveat B's per-b… |
| `.handoffs/REPORT-W1-tower-flag-day-to-seat.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: probe-5b verbatim wall (value-generic @_rawLayout size rejected → Memory.Inline marker); the bare-extension-re-defaults-Copyable module-split mechanic; the phantom-generi… |
| `.handoffs/REPORT-W4-seat-open-questions.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: Q1's defaulted-requirement analysis (bare extension = Copyable-only; requirement can't be conditional; option-C CoW-witness impossibility); Q5 accessor availability table… |
| `.handoffs/REPORT-msb-tower-capability-elimination-decisions.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the structural ledger-handoff analysis (range-set shape .empty/.one/.two; discipline-derives-sets-once; class-deinit oracle; bd04f32 forcing) — the cleanest single statem… |
| `.handoffs/AUDIT-tower-layering-status-quo-2026-06-22.md` *(unlisted)* | DELETE | Read-only audit BRIEF (2026-06-22) for the fresh layering review; no Findings section here — the executed audit lives at swift-institute/Audits/tower-layering-status-quo-2026-06… |
| `.handoffs/PROMPT-adt-tower-rederivation.md` *(unlisted)* | ALIVE | The active re-derivation charter (2026-07-02): mission, prime directives, verified inventory, 10 hard constraints, Q1–Q12 decision surface, SEAT supervision, prune universe. |

#### A.5 detail — cleave arcs (18 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `.handoffs/.trash/cleave-3-PROGRESS.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: (a) bd04f32 tri-toolchain re-probe verdict + exact diagnostic; (b) InlineArray.init(unsafeUninitializedCapacity:) absent on 6.3.2/6.5-dev, Optional-slot route typechecks;… |
| `.handoffs/.trash/HANDOFF-cleave-3-close-spec.md` *(unlisted)* | DELETE | Staged seat spec for Cleave-3 close: defer A-repay pending Prism verdict; handover contents for Cleave-4. |
| `.handoffs/HANDOFF-039-cleave-4.md` | EXTRACT-THEN-DELETE | Carry the full §0 shape matrix + canonical binding-wall finding verbatim (value-generic n binds only via .Valued<n> when n is the enclosing type's own generic; SHAPE_E free-type… |
| `.handoffs/HANDOFF-cleave-4.md` | EXTRACT-THEN-DELETE | Carry: (a) the decompose/compose doctrine (no capability protocols/refinements; constrained extensions; ops at canonical layer, delegate down); (b) the Memory.Small leaf/discipl… |
| `.handoffs/HANDOFF-cleave-4.5.md` | EXTRACT-THEN-DELETE | Carry: the dissolve-set/exclude-set classification rule (variant-suffix-on-contiguous vs discipline), and the __MemoryAddressableProtocol acceptance rationale (value-generic-n w… |
| `.handoffs/HANDOFF-cleave-5-exploration.md` | DELETE | Prism dispatch: read-only scoping of the protocol-corpus decompose/compose refactor (future Cleave-5); honest refactor/keep/reshape map required. |
| `.handoffs/cleave-4.5-PROGRESS.md` | DELETE | Cleave-4.5 log: 4 packages green via swift package update; buffer-linked respell 749106a; Storage.Heap typealias retired; STOP on systemic cascade + CoW defect. |
| `.handoffs/cleave-4.6-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry the CoW overload-resolution hazard verbatim: non-generic protocol-constrained overload outranks generic same-type-constrained overload → silent CoW bypass; the grow-reallo… |
| `.handoffs/cleave-5-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry: (a) the D1-D6 ruling set (one line each) as the capability-elimination record; (b) the two compiler facts — Copyable-beats-~Copyable specificity, and the 'cannot suppress… |
| `.handoffs/GOAL-cleave-6-sparse-occupancy.md` | EXTRACT-THEN-DELETE | Carry: the two ratification records (Shape α; Option A) with dates, the rejected alternatives (i)/β/B with reasons, the carve-out statement + its 'forced by swift#86652, revisit… |
| `.handoffs/cleave-6-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry: (a) the bd04f32 precise statement + the buffer-copyability-not-occupancy-shape insight; (b) the same-package-works/cross-package-skipped/WA-SIGSEGV empirical triple with … |
| `.handoffs/GOAL-cleave-7-end-state.md` | EXTRACT-THEN-DELETE | Carry: (a) the SE-0427 deinit⟹~Copyable law + 8-spike/no-escape empirical result with the Rust E0184/E0367 mirror (canonical home: Research/conditional-deinit-conditionally-copy… |
| `.handoffs/cleave-7-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry the full 4-config empirical matrix + the precise wall statement + the unsatisfiability conclusion + the non-reproducibility facts (5-pkg /tmp model passes debug; release L… |
| `.handoffs/GOAL-cleave-8-memory-tier.md` | DELETE | Cleave-8 goal (BANKED 2026-06-07): A memory-unbounded dissolved into growable Memory.Aligned; B Span.Raw relocation; C spun to Cleave-9. |
| `.handoffs/cleave-8-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry: (a) the Index.Bounded duplicate collision + misdiagnosis correction (canonical = finite-primitives typealias); (b) the span/memory dependency-direction rule (Span.Raw mus… |
| `.handoffs/GOAL-cleave-9-allocation-arc.md` | DELETE | Cleave-9 goal, superseded in-file 2026-06-07: Item C respelled — composed Pool/Arena spelling ill-formed; G1/G2 gates; DELETE doomed code. |
| `.handoffs/cleave-9-PROGRESS.md` | EXTRACT-THEN-DELETE | Carry: (a) the 4-point ill-formed grounding with file:line; (b) the typed-vs-raw Memory-leaf inconsistency statement; (c) the G1 verdict + numbers (16→16 B free for node familie… |
| `.handoffs/HANDOFF-occupancy-leaf-cleave.md` | ALIVE | Cleave-11.5 dispatch: 'occupancy lives in the leaf' law; no occupancy protocol; leaf homing ruled Storage.* then HELD 2026-06-08. |

#### A.5 detail — storage/buffer/charter arcs (23 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `.handoffs/HANDOFF-buffer-storage-protocols.md` | EXTRACT-THEN-DELETE | Carry: two-axis physical/logical ownership principle; Buffer-never-refines-Storage; Array-model conditional-Copyable facade rationale (+~Copyable ensureUnique footgun); Slab pla… |
| `.handoffs/HANDOFF-buffer-protocol-v2.md` | EXTRACT-THEN-DELETE | Carry: A' orthogonality decision + the Count-relaxation shape and its two costs (explicit typealiases on parameterized conformers; isEmpty-not-count==.zero over the protocol); s… |
| `.handoffs/HANDOFF-storage-protocol-modernization-review.md` | EXTRACT-THEN-DELETE | Carry: the [C2] aliasing unsoundness proof + [C1] OutputSpan-circularity argument (why the seam subscript is mutating, why whole-region stays off-protocol); the G4-NS 0-witness … |
| `.handoffs/HANDOFF-storage-protocol-modernization-implementation.md` | EXTRACT-THEN-DELETE | Carry: the validation verdict + probe matrix (already summarized in the review extract); the 398-sites/117-files metric-correction lesson (grep -rln counts files, not sites). |
| `.handoffs/HANDOFF-storage-protocol-p6-depointer.md` | EXTRACT-THEN-DELETE | Carry: final 4-op typed seam + WHY subscript is mutating; the two principled escape-hatch walls (~Copyable-enum-payload language limitation; ~Escapable-span-in-Escapable-iterato… |
| `.handoffs/HANDOFF-storage-consolidation.md` | EXTRACT-THEN-DELETE | Carry one line: since G3 (2026-06-18) the storage seam is ONE package — swift-storage-primitives hosts Store.Protocol (minimal, index-only-deps target) + concrete storage; swift… |
| `.handoffs/HANDOFF-storage-inline-finalization.md` | EXTRACT-THEN-DELETE | Carry: the InlineArray-class-field -O write-elision miscompile (dossier 2e45aa1) as a standing wall against buffer-owned inline sparse occupancy; the probe-position false-green … |
| `.handoffs/SCOPING-store-ledgered-dissolution.md` | EXTRACT-THEN-DELETE | Carry whole §1-§5 skeleton: the one-member refinement, the prefix-arithmetic-vs-wrapped-ledger soundness rationale, the three dissolution options with costs, ruling 12's cap, an… |
| `.handoffs/HANDOFF-pool-resplit.md` | DELETE | Executor brief applying the principal's 2026-06-17 maximize-split ruling to swift-pool-primitives: un-fuse Scope·ID and Error·Capacity into 4 single-namespace foundational targe… |
| `.handoffs/HANDOFF-adt-shape-research.md` | EXTRACT-THEN-DELETE | Carry verbatim: the 6-point converged model + the 'additive correction not teardown' framing + the verified source-shape citations (Array outlier / Buffer target / core member l… |
| `.handoffs/GOAL-tower-adt-families.md` | EXTRACT-THEN-DELETE | Carry: the five standing rules born this arc ([DS-024], [API-IMPL-021/022], [MEM-COPY-017], [MEM-SAFE-028]) with their skill homes; the sending/CoW verdict; the deliberate Gener… |
| `.handoffs/REPORT-ADT-families-composition.md` | EXTRACT-THEN-DELETE | Carry: the §0 landscape table (what existed/was RED/never existed before the tranche — needed to read the shipped tier honestly) + the SlotMap-compound-name flag. Ask details su… |
| `.handoffs/REPORT-ADT-families-spike-findings.md` | KEEP-EVIDENCE | Evidence artifact: the walls (F-3, F-4) and law-pass results are toolchain-versioned empirical facts with a preserved re-runnable spike (probes-2026-06-10/queue-family-spike). K… |
| `.handoffs/REPORT-ADT-families-execution.md` | EXTRACT-THEN-DELETE | Carry: the §A9 debug-crash wall statement with its bisection list + repro path + release-path exception + queued-investigation status (this is a first-class compiler-wall input … |
| `.handoffs/REPORT-ADT-families-leg8-execution.md` | EXTRACT-THEN-DELETE | Carry: D2's structural argument (a public 4-op seam over a hashed column is lawful only with a re-index guard — the template for any content-addressed Store.Protocol conformer);… |
| `.handoffs/REPORT-hash-indexed-surfacing.md` | EXTRACT-THEN-DELETE | Carry: the one-generic-parameter derived-state argument (index table is not a column); the constraint-carry rule (declaration bounds, not witness bounds); closures-not-Equatable… |
| `.handoffs/HANDOFF-buffer-arena-pool-repair.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the correctness-driven surface-derivation principle (upstream discipline defines the surface; consumers adapt); the ~Copyable-generic-typealias SIGSEGV avoidance rule; th… |
| `.handoffs/REPORT-buffer-isempty-generalization-decision.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the Count-equality wall (abstract Carrier Count has .zero but no ==; == addition triple-defines) as the standing argument for isEmpty-as-requirement / gated defaults on m… |
| `.handoffs/HANDOFF-binary-cursor-reader-storage-redesign.md` *(unlisted)* | ALIVE | Redesign brief: Binary.Reader/Cursor are design-broken (Escapable struct storing a Span.Protocol storage whose only conformer, Swift.Span, is ~Escapable); move UInt8->Byte; prin… |
| `.handoffs/REPORT-round-p-W3-pilot-storage.md` *(unlisted)* | DELETE | Round-P publication pilot on swift-storage-primitives: all runnable flip checks pass; the institute-linter 'lint clean' gate blocked by transitive-closure consumer lag; recommen… |
| `.handoffs/HANDOFF-fam-012-ratification.md` *(unlisted)* | ALIVE | [FAM-012] family-codable ratification record (D1 YES; D2 = full retire of the canonical codec tier) — CODEC arc, not ADT-tower families; pure name collision with this group's th… |
| `.handoffs/HANDOFF-fam012-drain-phaseE.md` *(unlisted)* | ALIVE | [FAM-012] codec-arc executor brief: drain cohort (29 conformers off deprecated Binary.ASCII.Serializable) + Phase-E IPv4/IPv6/Host/Authority — CODEC arc, out of tower scope (nam… |
| `.handoffs/HANDOFF-fam012-seat.md` *(unlisted)* | ALIVE | [FAM-012] codec-arc SEAT continuation (re-cut cohort complete, 10 held commits / 9 packages; seal-last -> integration sweep -> W4 -> publish remaining) — CODEC arc, out of tower… |

#### A.5 detail — occupancy/allocation/memory-tier arcs (22 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `.handoffs/RULING-allocation-arc-recharter.md` | EXTRACT-THEN-DELETE | Carry: R1/R3/R4/R5 + DP1 rulings; the Memory.Arena-not-dead correction; the 'Arena is pool-backed, name misleads' finding + unexecuted rename recommendation; DP3 canonical-seam … |
| `.handoffs/REPORT-allocation-arc-scout.md` | EXTRACT-THEN-DELETE | Carry: §7a seam-taxonomy table verbatim (canonical marker + defunct label + distinct Allocatable + protocol-can't-nest-in-generic fact); W5-1 pool-backed reality; zero-consumer … |
| `.handoffs/REPORT-allocation-arc.md` | EXTRACT-THEN-DELETE | Carry: Part A commits + test counts; the ~Copyable forcing chain (unconditional leaf -> move-only buffer, conditional Copyable illegal over ~Copyable field); the B3 cascade map … |
| `.handoffs/HANDOFF-allocation-arc.md` | DELETE | Original executor brief for the out-of-line allocation arc (arena path first, pool path deferred); premises invalidated by the scout and re-chartered 2026-06-19. |
| `.handoffs/HANDOFF-buffer-arena-pool-repair.md` | EXTRACT-THEN-DELETE | Carry: the discipline-derived-surface design basis (consumer usage never defines the surface); Skills@01440f8 seam fix; the [MEM-COPY-018] risk name; the verbose-spelling wall; … |
| `.handoffs/GOAL-cleave-9-allocation-arc.md` | EXTRACT-THEN-DELETE | Carry: the ill-formed-spelling ruling; the keep-shells -> DELETE-doomed-code reversal; the Index.Bounded misdiagnosis; the purge-cache unlock. |
| `.handoffs/GOAL-cleave-8-memory-tier.md` | EXTRACT-THEN-DELETE | Carry: the Memory.Aligned seam ruling (Span.Protocol + Growth.Growable only, not an allocator); Memory.Buffer -> Span.Raw relocation; the two latent L1 bug fixes; the don't-conf… |
| `.handoffs/HANDOFF-memory-allocation-alignment-naming.md` | EXTRACT-THEN-DELETE | Carry: the machine-vs-value classification rule; the Alignable half-step + Aligned.`Protocol` end-form; the no-Aligner finding; the dated allocation-surface snapshot (for seam-h… |
| `.handoffs/HANDOFF-memory-tier-cleanup.md` | EXTRACT-THEN-DELETE | Carry: the only-cycle fact + closure commits + [MOD-032] 1->0; the live-source-vs-.build-mirror false-conformer trap; the clean-resolve canary rule. |
| `.handoffs/HANDOFF-memory-tier-completion.md` | EXTRACT-THEN-DELETE | Carry: string/path -> Memory.Heap + take() ruling with the raw-egress rationale; the W1 canonical transform; the CoW-withdrawal-to-move-only pattern; Storage.Inline<Element,n> f… |
| `.handoffs/GOAL-cleave-6-sparse-occupancy.md` | EXTRACT-THEN-DELETE | Carry: the swift#86652 cross-package deinit-skip evidence + the nested-substrate AnyObject? SIGSEGV; the range-set-vs-sparse leak mechanism; the Shape-alpha and Option-A rulings… |
| `.handoffs/cleave-6-PROGRESS.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the same-package-green / cross-package-leak discriminator for swift#86652; the workaround-SIGSEGV structural shape; deinit-in-body-not-extension LLVM crash note; the 7491… |
| `.handoffs/cleave-8-PROGRESS.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the Index.Bounded collision mechanics; the Span.Raw no-Memory.Address cycle rule; the purge-cache unlock; the A/B commit ledger. |
| `.handoffs/cleave-9-PROGRESS.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the 4 ill-formed receipts; G1 results (the durable experiment package Experiments/sparse-inline-slot-storage is the KEEP-EVIDENCE artifact); G2 two-role decomposition + r… |
| `.handoffs/HANDOFF-occupancy-leaf-cleave.md` | EXTRACT-THEN-DELETE | Carry: the no-occupancy-protocol decision + concrete-pin pattern; the phantom-S recursive-constraint compiler rejection; the HELD/never-finalized Storage.{Slab,Pool} homing (tim… |
| `.handoffs/occupancy-leaf-worklist.md` | EXTRACT-THEN-DELETE | Carry: Buffer.Arena-already-lawful evidence (leaf-owned teardown precedent with file:line); the zero-call-site fact for Inline/Small deletion; the .Bounded-is-capacity-not-occup… |
| `.handoffs/HANDOFF-sparse-occupancy-placement.md` | ALIVE | Probe-first decision brief (2026-06-24): buffer-owned inline occupancy is release-broken by an InlineArray class-field DSE miscompile; leaf-vs-buffer ruling + corpus reconciliat… |
| `.handoffs/HANDOFF-slab-occupancy-seat.md` | ALIVE | Seat-transfer handoff (2026-06-24): standing principal directive to build Memory.Allocator.Slab; kill Buffer.Slab's Box; three open gates. Directive UNEXECUTED as of 2026-07-02. |
| `.handoffs/REPORT-round-p-adt-C1-memory-tier.md` | EXTRACT-THEN-DELETE | Carry: the towerRoots set + Memory-exclusion rationale (defines what counts as 'the tower' for lint purposes); the @frozen-harm precedent; the dated Memory-tier public-type census. |
| `.handoffs/HANDOFF-pool-resplit.md` *(unlisted)* | DELETE | Executor dispatch (2026-06-17): un-fuse swift-pool-primitives targets into Scope/ID/Error/Capacity. Async resource-pool domain — not the memory-allocation pool; weak theme match. |
| `.handoffs/HANDOFF-async-timer-arena-migration.md` *(unlisted)* | EXTRACT-THEN-DELETE | Carry: the bump-vs-generational capability distinction (arena cannot do per-slot reuse/ABA); the retained Position->Handle mapping; the Handle-mint-internal + fatalError-on-exha… |
| `.handoffs/HANDOFF-capacity-decomposition.md` *(unlisted)* | DELETE | Read-only research dispatch (Prism continuation, 2026-06-05): find canonical homes for .Bounded/.Fixed/.Static capacity/growth variants under maximum decomposition. |

Per-file detail for the Round P / tree / FAM-012 group (the grouped rows above bind where
the table lacks a row):

#### A.5 detail — Round P / tree recomposition / FAM-012 (mined live 2026-07-02) (47 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `.handoffs/GOAL-tower-round-p.md` | EXTRACT-THEN-DELETE | The PUBLIC-FLIP-LAST posture (flip NO TAGS + per-repo YES + squash-before-flip + trees flip when tower-shaped) and the fact that the publication program has since executed (repos pub… |
| `.handoffs/GOAL-round-p-adt-tier.md` | EXTRACT-THEN-DELETE | The gate-ladder velocity doctrine and the @frozen-not-reflexive rule (empty/low layouts must stay unfrozen to allow non-breaking growth). |
| `.handoffs/REPORT-round-p-STANDDOWN.md` | EXTRACT-THEN-DELETE | TSan positive-control durable location (Experiments/tsan-positive-control, fires 4 races/6 warnings) and the heap 4->2 recount rationale. |
| `.handoffs/REPORT-round-p-P1-disposition-proposals.md` | EXTRACT-THEN-DELETE | The still-live dispositions: storage-split rename pending (mismatch now public); memory-small parked on Q2 Store.Small; buffer-slab/slab parked on the W1 Slab-allocator decision. |
| `.handoffs/REPORT-round-p-W1-frozen-inherited.md` | DELETE | Gate-verify of 3 inherited @frozen commits (buffer-linear e41b3ca, buffer-linked ef98671, stack 664bc76): PASS, kept; 2026-06-13. |
| `.handoffs/REPORT-round-p-W2-frozen-graph-heap.md` | EXTRACT-THEN-DELETE | The @frozen-empty-layout doctrine (freezing a placeholder blocks later non-breaking realization) and the 21-finding recount. |
| `.handoffs/REPORT-round-p-W3-pilot-storage.md` | EXTRACT-THEN-DELETE | The linter-closure wall (binary-parser Shared_Primitive diagnostic; gate needs whole closure compiling) and the resolve-vs-build lesson. |
| `.handoffs/REPORT-round-p-W4-substrate-tier.md` | EXTRACT-THEN-DELETE | The destructive prefer_self --fix incident (protocol constraint -> Self, 13 errors) and the config-dependent swiftlint count collapse. |
| `.handoffs/REPORT-round-p-W5-columns-tier.md` | DELETE | Columns tier (column/fixed/shared/slot-map/store) readied + committed 2026-06-14; all name-matched; hard gate passed; wave closed. |
| `.handoffs/REPORT-round-p-adt-cohort-plan.md` | EXTRACT-THEN-DELETE | The verified 20-package intra-tier dependency layering (empirical composition evidence for the tower) and the async Timer.Wheel orphaned-source state. |
| `.handoffs/REPORT-round-p-adt-C1-memory-tier.md` | EXTRACT-THEN-DELETE | Memory excluded from towerRoots by design, and the memory-heap identity fact (element-free raw-byte Heap over Memory.Contiguous<Byte>, post storage/memory split). |
| `.handoffs/REPORT-round-p-adt-C2-core-containers.md` | EXTRACT-THEN-DELETE | The dissolved-variant-family fact (Array.Small/Fixed/Static/Bounded/Inline never shipped; column vocabulary replaced them) and the element-generic vs column-generic split across ADTs. |
| `.handoffs/REPORT-round-p-adt-C3-composites.md` | EXTRACT-THEN-DELETE | The verbose canonical column spelling (Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Ring) as declaration-cost evidence, and the set-algebra relocation. |
| `.handoffs/REPORT-round-p-adt-C4-ordered-graph-executor.md` | DELETE | Cohort 4 (set-ordered/dict-ordered/graph/executor) readied 2026-06-15; graph 15/15 @frozen; set-ordered/dict-ordered READMEs joined the column batch. |
| `.handoffs/REPORT-round-p-adt-C5-and-set-docc.md` | EXTRACT-THEN-DELETE | The pool effects-based consumer surface fact and the removed unverified-Embedded-claims precedent. |
| `.handoffs/HANDOFF-round-p-adt-column-readme-batch.md` | DELETE | Fresh-session handoff (2026-06-15) for the 7-package column-ADT README batch; captures the seat convention and per-package verified columns. |
| `.handoffs/REPORT-round-p-adt-column-readme-batch.md` | EXTRACT-THEN-DELETE | The verified consumer-facing declaration/usage cost of the column-generic family (spellings + import counts) — direct evidence for the north-star declaration-cost metric — and the /t… |
| `.handoffs/GOAL-array-readme-rewrite.md` *(unlisted)* | EXTRACT-THEN-DELETE | The verified old-variant -> column mapping table, incl. the two inexpressible cases (Array.Small awaits Store.Small; Array.Bounded belongs to typed indices) — variant-taxonomy evidence. |
| `.handoffs/GOAL-tree-recomposition-R1.md` | EXTRACT-THEN-DELETE | The carried-forward Round-M inventory (decode/token/typed-count/CoW column) and the §A13-dormancy rationale (stored state means self never eliminable under -O FunctionSignatureOpts). |
| `.handoffs/REPORT-tree-recomposition-R0.md` | EXTRACT-THEN-DELETE | The conditional-Copyable-on-C.Element diagnostic (6.3.2) + the no-defaulted-type-generic-args constraint + the Array-hides-copyability-in-the-seam cross-check. |
| `.handoffs/REPORT-tree-recomposition-R0-revalidation.md` | EXTRACT-THEN-DELETE | The three child-axis walls with diagnostics, the ecosystem conformer-set enumeration, and the shared-layer-unifies/child-layer-does-not empirical split. |
| `.handoffs/REPORT-tree-recomposition-R0-optionC.md` | EXTRACT-THEN-DELETE | The witness-values-cost law: protocol-free variant-as-value costs ~7 words/instance + likely non-devirtualized dispatch; element-free-ness is the condition that clears the ~Copyable … |
| `.handoffs/REPORT-tree-recomposition-R0-optionE.md` | EXTRACT-THEN-DELETE | The cross-package access-level law (package-level defaults cannot read conformer storage cross-repo without public) and the abstraction-vs-compose-over protocol-kind distinction. |
| `.handoffs/REPORT-tree-recomposition-R0-optionE-corrected.md` | EXTRACT-THEN-DELETE | The operation-seam pattern (requirements = operations, never storage) with its measured forwarder tax, proven private-storage separation, and the ~Copyable requirement-shape trio. |
| `.handoffs/REPORT-tree-recomposition-R1-W0-plan.md` | EXTRACT-THEN-DELETE | The @usableFromInline-vs-private law for @inlinable primitives, the top-level-vs-nested twin-mangling rule, and the additive-then-dissolve migration pattern. |
| `.handoffs/REPORT-tree-recomposition-R1-W1.md` | DELETE | R1 W1 (compound-named engine, tree-core 1221df8, additive; all downstream green). Superseded by the W1-prime forward-fix after the naming violation. |
| `.handoffs/REPORT-tree-recomposition-R1-renamed-plan.md` | EXTRACT-THEN-DELETE | The naming-violation incident and the falsified claim that a bare struct Tree<Element> could not coexist with Nest.Name variants (it can, when the struct IS the nest). |
| `.handoffs/REPORT-tree-recomposition-R1-revalidation-structTree.md` | EXTRACT-THEN-DELETE | The extension-twin mangling collision diagnostic and the member-level-twin rule for types nested in inverse-generic extensions (6.3.2). |
| `.handoffs/REPORT-tree-recomposition-R1-W1prime-W2aprime.md` | EXTRACT-THEN-DELETE | The typed-Address family discipline (per-conformer associated Address with typed index domains) and the proven safety of enum->struct namespace refactor. |
| `.handoffs/REPORT-tree-recomposition-R1-W2-flags-and-treeN-handoff.md` | EXTRACT-THEN-DELETE | The hoist-only-protocols rule (structs can host nested generics; drop __ hoists where nesting works) and the checked-Sendable-chain fact through Shared/Column.Generational. |
| `.handoffs/REPORT-tree-recomposition-R1-W2.md` | EXTRACT-THEN-DELETE | The .Protocol-in-conformance-clause collision, the +298/-814 dedup measurement, and the leading-dot-through-same-type-constraint resolution finding. |
| `.handoffs/REPORT-tree-recomposition-R1-W2a.md` | DELETE | W2a checkpoint: compound-named NaryTree conformer landed additively (38168c7) — the detour later removed by W2a-prime after the naming retraction. |
| `.handoffs/REPORT-tree-recomposition-R1-W3.md` | EXTRACT-THEN-DELETE | The shadowing-cannot-delegate-to-default wall and its error-split consequence; the ChildLinks-bundling trick for per-variant node payload; the grep-trailing-closure test-estimate les… |
| `.handoffs/REPORT-tree-recomposition-R1-W4.md` | EXTRACT-THEN-DELETE | The borrowing-view lifetime wall + Property.Borrow adoption, the view-typed-return limitation (Int? fold), the W-1 sole-consumer verification, and the [PRP-009] stale-name errata. |
| `.handoffs/HANDOFF-tree-universal-shape.md` | EXTRACT-THEN-DELETE | Gate-1 empirical receipts (keyed-valid layered Container<S>, 0 witness_method in -O cross-module SIL, negative controls) and the corrected ADT-vs-storage conformance mapping. |
| `.handoffs/HANDOFF-tree-core-v2-rebuild.md` | EXTRACT-THEN-DELETE | Full extraction above: the V2 target shape + non-negotiable invariants, the untested arena-as-Buffer question, the discard rationale for b09726a, and the verified never-executed stat… |
| `.handoffs/HANDOFF-adt-shape-research.md` *(unlisted)* | DELETE | Step-1 dispatch (2026-06-18) to formalize the converged ADT-shape model against prior art; produced the decoupling charter line ([DS-025-027]). |
| `.handoffs/STATUS-fam012-phase-d.md` | DELETE | Point-in-time FAM-012 Phase D status for the seat (2026-06-30): mechanical re-cut complete; composite/drain cohorts pending decisions. Superseded by the seat handoff. |
| `.handoffs/REPORT-fam012-conformer-ledger.md` | DELETE | FAM-012 Phase D conformer-level ledger (2026-06-30): 84 conformers / 22 packages — 30 re-cut, 14 canonical pending, 29 drain, 11 binary-only. Consumed by the completed drain. |
| `.handoffs/REPORT-fam012-phase-d-recut-verification.md` | DELETE | FAM-012 mechanical re-cut verification (2026-06-30): recipe, A/B/C outcome classes, seat ruling executed; superseded by later waves. |
| `.handoffs/HANDOFF-fam-012-ratification.md` | EXTRACT-THEN-DELETE | The ratification record (D1 YES / D2 full-retire, 2026-06-30) with its codified home (family-codable-convention.md v1.2.0+) — non-tower; must not be pruned by the tower supersession … |
| `.handoffs/HANDOFF-fam012-drain-phaseE.md` | DELETE | Executor brief for the FAM-012 drain cohort + Phase E forcing functions (IPv4/IPv6/Host/Authority); drain shipped — retire-on-completion condition met. |
| `.handoffs/HANDOFF-fam012-seat.md` | ALIVE | SEAT continuation for FAM-012 (updated through 2026-07-01 21:20): drain shipped + 11-repo push wave landed; W4 namespace deletion committed but UNPUSHED — arc ACTIVE at its final step. |
| `.handoffs/PROMPT-adt-tower-rederivation.md` *(unlisted)* | ALIVE | The live mission doc (2026-07-02) driving this re-derivation: one ratified document Research/adt-tower.md; prior corpus = evidence; ratified-or-nothing; no macros in the declaration … |
| `.handoffs/.trash/GOAL-tree-recomposition.md-retired-20260702` *(unlisted)* | DELETE | The original R0 goal (seat-drafted 2026-06-13): tower-canonical Tree<Children> over a Children seam; namespace dissolves with the variants. Already retired to .trash 2026-07-02. |
| `.handoffs/.trash/HANDOFF-tree-charter-adoption.md-retired-20260702` *(unlisted)* | DELETE | Dispatch for the Charter [DS-025] Gate-2 adoption: Tree concrete -> at-target Tree<S: ~Copyable>; produced b09726a. Already retired to .trash 2026-07-02. |
| `.handoffs/.trash/HANDOFF-tree-recomposition-R1-W3.md-retired-20260702` *(unlisted)* | DELETE | The W3 (Tree.Keyed in-place swap) executor dispatch; fully superseded by REPORT-tree-recomposition-R1-W3.md. Already retired to .trash 2026-07-02. |

### 10.4 Per-package Research/ (A.6)

All four corpora mined per-file (2026-07-02); the compiler-bug docs are KEEP-EVIDENCE
(Wall-2 provenance).

#### A.6 swift-buffer-primitives/Research (26 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `_index.json` | AMEND | Regenerate after pruning; carry the storage-generic statusDetail wording (0 witness_method validation summary) into the new tower doc's evidence section. |
| `_Package-Insights.md` | EXTRACT-THEN-DELETE | Carry: (1) #86652 fix validated against 2,284 compiler tests; (2) 22 _deinitWorkaround sites / 10 packages + canary experiment name; (3) DeinitDevirtualizer ICE on 6.4-dev (Buffer.Un… |
| `arena-buffer-design.md` | EXTRACT-THEN-DELETE | Carry: Slab-vs-Arena taxonomy (consumer-chosen+bitmap vs allocator-chosen+generation tokens), the 4-point Storage.Pool rejection rationale, count-as-virgin-cursor invariant, and the … |
| `bounded-index-parameter-syntax.md` | EXTRACT-THEN-DELETE | Carry: the retag-preserves-bound fact (+ experiment name) and the boundary principle 'accept bounded at API boundary; retag carries the bound; widen only at bitmap/header sinks'. |
| `buffer-core-pattern-unification.md` | DELETE | Post-audit correctness/API-surface pass on Buffer Primitives Core: six concrete changes (Hashable removals, isSpilled demotion, Arena.Small observables, comment dedup). |
| `buffer-ring-consumer-api-boundary.md` | EXTRACT-THEN-DELETE | Carry the layering principle: buffer owns all buffer invariants; ADT layer is thin vocabulary; 'package' access is not a cross-package tool — must be public API or same-package. |
| `buffer-variant-parity-analysis.md` | EXTRACT-THEN-DELETE | Carry as evidence of duplication cost: the 7-discipline x 4-variant x Copyable-split combinatorial surface and its measured drift (naming, conformance, tests) — the explosion the tow… |
| `checkpoint-ordering-design.md` | EXTRACT-THEN-DELETE | Carry: checkpoint = quotient order over count with explicit == matching <; ClosedRange-as-backtracking-window is the reason Comparable is structural. Relevant to any tower Checkpoint… |
| `compiler-fix-86652.md` | EXTRACT-THEN-DELETE | Carry: full root-cause mechanism (public->element-wise->invariant.load vs internal->VWT), the unblock list with the 22-site/8-byte figure, and the correction that GenStruct.cpp creat… |
| `compiler-fix-86652-consequences.md` | EXTRACT-THEN-DELETE | Carry: blast-radius table (which shapes reach createNonFixed), three-tier destruction fallback with the containing-struct trigger subtlety, and the Option A rationale (matches intern… |
| `inline-small-linked-buffer-design.md` | EXTRACT-THEN-DELETE | Carry: InlineArray init(repeating:) Copyable+O(capacity) limitation and the in-band free-list stride argument — both recur in any inline-variant re-derivation. |
| `linked-buffer-n-parameterization.md` | EXTRACT-THEN-DELETE | Carry: N-parameterized links representation + the 8-bytes-per-node cost argument; O(n) removeBack for N=1 as the accepted trade. |
| `linked-cow-safe-overloads.md` | EXTRACT-THEN-DELETE | Carry: static-method core pattern (and the copyable-overload-resolution experiment reference) + buffer-owns-CoW principle — both are inputs the tower must ratify or replace. |
| `metadata-parametric-slots.md` | ALIVE | The open Class-(c) boundary-definition item IS the tower re-derivation's subject; the realized Slots/Split layering and the GAP-O fold-and-reversal are the strongest recent empirical… |
| `noncopyable-optional-access-patterns.md` | EXTRACT-THEN-DELETE | Carry: the Swift 6.2 consume-vs-borrow wall with the experiment reference, marked 'toolchain-versioned — re-probe on current toolchain before relying' (tower re-probe task covers this). |
| `noncopyable-view-types-for-peek-reversed.md` | EXTRACT-THEN-DELETE | Carry: the two walls (coroutine-vs-closure scoping of withUnsafePointer; method-level-generic constraint poisoning -> Typed/Valued type parameters) and the mutating-_read-is-free-for… |
| `rawlayout-release-crash-investigation.md` | KEEP-EVIDENCE | Wall-2 canonical provenance. If the tower doc restates Wall-2, cite this file; do not duplicate the IR-level detail. |
| `release-build-options-v2.md` | EXTRACT-THEN-DELETE | Carry: the consumer-module vs extension-file trigger paths are DIFFERENT IR lowering paths (why the AnyObject? workaround scoped wrong), the discard-self refutation for @_rawLayout, … |
| `release-mode-llvm-verifier-crash-diagnosis.md` | KEEP-EVIDENCE | Referenced as 'authoritative diagnosis' by the RESOLVED consolidated record; retain for the Step 1-8 matrices ([MOD-004] verification matrix, workaround-refutation table). Amend the … |
| `slab-first-principles.md` | EXTRACT-THEN-DELETE | Carry: the discipline taxonomy table and the Slab/Arena WHERE-distinction; Bonwick + Rust-slab citation list for the tower SLR. |
| `slots-buffer-variant-parity.md` | EXTRACT-THEN-DELETE | Carry: the two-tier (predicate vs bulk) copy discipline keyed on Copyable vs BitwiseCopyable — a reusable boundary pattern for the tower's CoW story. |
| `small-buffer-enum-compiler-workarounds.md` | EXTRACT-THEN-DELETE | Carry: the mixed @_rawLayout+class-ref destructor wall (with snapshot-2026-02-08-a stamp), the enum-payload _modify wall (MoveOnlyPartialReinitialization dependency), and the 2-moves… |
| `small-buffer-storage-representation.md` | EXTRACT-THEN-DELETE | Carry: Optional's unchecked_take_enum_data_addr special-casing (why Optional-field SBO beats enum SBO ergonomically in Swift), the all-elements-spill invariant, and the Rust-vs-Swift… |
| `storage-generic-buffer-core.md` | ALIVE | Immediate predecessor of the tower arc: its verified duplication counts, the two SIL specialization experiments, the two-axis physical/logical ownership ruling, the teardown-truth su… |
| `storage-pointer-access-level.md` | EXTRACT-THEN-DELETE | Carry: buffers-own-lifecycle / storage-exposes-raw-pointer boundary ruling (with commit 038e626 anchor), and the redeclaration-conflict fact that kills same-package public wrapper sh… |
| `theoretical-buffer-primitives-design.md` | EXTRACT-THEN-DELETE | This is the artifact the tower re-derivation directly replaces. Carry: ordering-vs-addressability axis, header/static-ops/composed-types layer vocabulary, Bit.Vector-vs-Storage.Initi… |

#### A.6 swift-storage-primitives/Research (25 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `Collection Primitives Architecture.md` | EXTRACT-THEN-DELETE | Carry the three-bug ~Copyable taxonomy (S5.1) and the S8/S9 principle list (structural parity, conditional capability, explicit constraints, typed errors, storage sharing); explicitl… |
| `_Package-Insights.md` | EXTRACT-THEN-DELETE | Carry the monus/Count-domain totality formulation, the genuine-vs-artificial-partiality test, and the typed-errors-for-init-preconditions principle; annotate stale type names. |
| `bounded-unbounded-storage-inline-api.md` | EXTRACT-THEN-DELETE | Carry the narrowing-inside-invariant-owner principle, the 187-tests/~40-errors evidence, and the open tension with the Storage.Protocol unbounded witness (Wave 1). |
| `escapable-deinit-lifetime.md` | EXTRACT-THEN-DELETE | Carry the _read-assertion compiler wall (LifetimeDependenceDiagnostics @owned assumption) with its Feb-2026 toolchain era, and the shipped get/_modify accessor shape. |
| `initialization-visibility.md` | EXTRACT-THEN-DELETE | Carry one line: buffer layer needed 30 direct init-state writes (non-linear patterns), evidencing that init-state authority placement is a real tower boundary question; the specific … |
| `inline-bitvector-wordcount.md` | EXTRACT-THEN-DELETE | Carry the capacity<=256 operating envelope + the three INV-INLINE IDs + the no-value-generic-arithmetic wall that forced fixed sizing. |
| `inline-deinit-ownership.md` | EXTRACT-THEN-DELETE | Carry the Swift 6.2.3 LLVM-verifier wall verbatim, the layering rule 'storage owns memory; buffer owns element lifecycle', and the Rust/C++26/ManagedBuffer precedent triple. |
| `inline-deinitialize-state-reset.md` | EXTRACT-THEN-DELETE | Carry the discard-self trivial-destructibility wall and the deinit-cannot-mutate-struct constraint; note the footgun was dissolved by per-slot BitVector tracking. |
| `inline-pool-arena.md` | AMEND | DECISION (v1.0.0, 2026-02-11, tier 3, normative): add Storage.Pool.Inline and Storage.Arena.Inline with bounded-index allocate/access; bitmap-scanned pool; bump arena. |
| `inline-slot-type-organization.md` | EXTRACT-THEN-DELETE | Carry the @_rawLayout capability facts (automatic size/alignment, any ~Copyable element), the stdlib precedent list, the forces-~Copyable consequence, and the Option-C fallback shape. |
| `inline-storage-layering.md` | EXTRACT-THEN-DELETE | Carry the memory-vs-storage concern split (the tower's Memory->Storage boundary rationale: raw layout below, lifecycle tracking above) plus the 80-iterator / 32B-overhead evidence. |
| `inline-storage-read-pointer-escape.md` | EXTRACT-THEN-DELETE | Carry the escaped-pointer UB evidence (garbage-read repro) and the yield-cannot-nest-in-closure restriction shaping _read implementations. |
| `per-slot-initialization-tracking.md` | EXTRACT-THEN-DELETE | Carry the size measurements (33B/41B vs 8/16/32B), the value-generic-arithmetic wall, and the two footgun failure modes the bitmap dissolves. |
| `ring-buffer-index-arithmetic.md` | ALIVE | Typed cyclic index arithmetic (tier 3, applies to index/queue/deque primitives): two-tier design — Z/NZ ops on Bounded<N> compile-time; Index % Count runtime. Header DEFERRED, body D… |
| `split-storage-design.md` | EXTRACT-THEN-DELETE | Carry the metadata-driven no-tracking principle, field-handle single-layout-authority (header stores only capacity), the fixed-capacity invariant, and the Element-stays-distinguished… |
| `split-storage-naming.md` | EXTRACT-THEN-DELETE | Carry one line: Split retained over Planar/Columnar/Paired/Dual/SoA; DSPSplitComplex analog; 'fields' terminology; arity-agnostic. |
| `storage-contiguous-api-design.md` | EXTRACT-THEN-DELETE | Carry the 4-layer API layering summary, the property-linear/closure-arbitrary principle, and the Storage.Span -> Range<Index<Storage>> supersession. |
| `storage-contiguous-protocol-conformance.md` | EXTRACT-THEN-DELETE | Carry the classes-cannot-mutating-get constraint and the read-only-protocol principle; note the Heap-is-now-a-struct aging. |
| `storage-inline-invariants.md` | AMEND | DECISION (v1.0.0, 2026-02-05, tier 2): invariant catalog INV-INLINE-001..008 for post-@_rawLayout Storage.Inline — layout, init state, access preconditions, ownership, pointer lifeti… |
| `storage-ownership-reference-synthesis.md` | AMEND | Master synthesis (v3.0.0, 2026-02-05, DECISION, tier 3, normative): storage = placement x ownership x lifetime; names encode placement only; Proposal C layered split with staged roll… |
| `storage-pool-architecture.md` | DELETE | SUPERSEDED (marked 2026-03-15): concluded Option B — Storage.Pool independent of Memory.Pool; explicitly reversed by memory-storage-composition-feasibility; current code composes. |
| `storage-primitives-modularization-review.md` | EXTRACT-THEN-DELETE | Carry the curation-not-orthogonal-grid framing table, the Chase-Lev wrong-layer ruling, and the ManagedBuffer-is-ecosystem-vestigial ruling with its deferred-replacement scope. |
| `storage-protocol-capacity-pilot.md` | KEEP-EVIDENCE | CONFIRMED findings (2026-05-25, Swift 6.3.2, macOS 26 arm64, branch spike/storage-protocol): typed capacity; Inline/Pool/Heap specialize to zero witness dispatch; Heap becomes value … |
| `storage-protocol-pointer-modernization.md` | ALIVE | RECOMMENDATION (v1.1.0, 2026-06-02, tier 2, cross-package): Option C — replace the UnsafeMutablePointer primitive with a single borrowing mutableSpan(at:); transitions sink to the me… |
| `_index.json` | AMEND | Machine index (schema v1, generatedAt 2026-04-18) of 22 docs + narrative sections; omits 2 corpus files; several statuses stale vs file headers; generatedAt stale vs newest entries. |

#### A.6 swift-memory-primitives/Research (26 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `swift-memory-primitives/Research/memory-address-mutability.md` | EXTRACT-THEN-DELETE | Carry: (1) address-as-position ruling with prior art (Rust provenance, CHERI, uintptr_t); (2) empirical fact that same-named nested types on Tagged extensions collide (see ambiguity … |
| `swift-memory-primitives/Research/pointer-type-hierarchy.md` | EXTRACT-THEN-DELETE | Carry one line: nesting a raw (non-generic) type under a generic namespace pollutes it with the phantom parameter — namespace raw variants outside the generic, or avoid raw variants. |
| `swift-memory-primitives/Research/pointer-mutable-pointee-semantics.md` | EXTRACT-THEN-DELETE | Carry: (1) `&` is non-overloadable compiler magic producing UnsafeMutablePointer<Self>; (2) nonmutating _modify is the correct mutation surface for pointer-like value wrappers (addre… |
| `swift-memory-primitives/Research/stdlib-pointer-migration.md` | EXTRACT-THEN-DELETE | Carry: 826/68/17 inventory result + the ruling that stdlib pointers are the internal-machinery currency and typed safety belongs at API boundaries — direct evidence for the tower's M… |
| `swift-memory-primitives/Research/_Package-Insights.md` | AMEND | Living non-normative insights: provenance-correct sentinel, Arena Count-vs-Offset fix, stride as Ratio not Count. |
| `swift-memory-primitives/Research/buffer-base-nullability.md` | EXTRACT-THEN-DELETE | Carry: empty-buffer interop needs BOTH conventions (nil-for-empty stdlib vs sentinel non-null for C); make the choice explicit and grep-able via nested accessor, never a silent default. |
| `swift-memory-primitives/Research/pool-free-list-representation.md` | EXTRACT-THEN-DELETE | Carry: in-band free-list links can be fully typed; the principled nil-sentinel for an index space is its one-past-end ordinal (endIndex analogue), never a magic max value. |
| `swift-memory-primitives/Research/ordinal-cardinal-foundations.md` | EXTRACT-THEN-DELETE | Carry: ordinal=position vs cardinal=magnitude split with monus as the canonical cardinal subtraction; note the recommendation was realized as packages; unresolved 12.4 questions (esp… |
| `swift-memory-primitives/Research/affine-scaling-operations.md` | EXTRACT-THEN-DELETE | Carry the four scaling rules verbatim (position/vector/morphism/cardinal) — they are the algebraic law set for the tower's index/offset/count arithmetic. |
| `swift-memory-primitives/Research/buffer-algebraic-structure.md` | EXTRACT-THEN-DELETE | Carry: composite types gain nothing from Tagged algebra (scalar-only benefit); universal (ptr,count) prior art; resource-vs-geometric 'affine' disambiguation. Load-bearing negative r… |
| `swift-memory-primitives/Research/contiguous-memory-access-standardization.md` | EXTRACT-THEN-DELETE | Carry: experiment result that inline storage safely exposes span PROPERTIES (stdlib InlineArray precedent) + the three irreducible withUnsafeBufferPointer use cases. Standard surface… |
| `swift-memory-primitives/Research/span-access-abstraction.md` | EXTRACT-THEN-DELETE | Carry: span-protocol abstraction was implemented and then deleted (refuted shape, with the Rust AsRef usage evidence) — do not re-derive a Span protocol for the tower without new gen… |
| `swift-memory-primitives/Research/typed-index-arithmetic-unification.md` | EXTRACT-THEN-DELETE | Carry: confirmed pattern statement + experiment pointer; rule already promoted to skill IDs [IDX-006a]/[IDX-006b], so the doc is redundant once the experiment record is preserved. |
| `swift-memory-primitives/Research/Input Index Bit Analysis.md` | DELETE | Paper-style advocacy for systematic Index/Input/Bit adoption across 14 data-structure packages; reuse-over-dependency-minimization principle. |
| `swift-memory-primitives/Research/mutable-cross-module-ambiguity.md` | KEEP-EVIDENCE | Experiment record: same-named nested types on different constrained Tagged extensions are cross-module ambiguous in Swift 6.2.3; Variant H fix confirmed. |
| `swift-memory-primitives/Research/unique-package-placement.md` | EXTRACT-THEN-DELETE | Carry only the dated deprecation fact: swift-pointer-primitives deprecated pre-2026-03-15; storage-primitives moved to stdlib pointers directly. That fact retires every pointer-* DEC… |
| `swift-memory-primitives/Research/memory-inline-package-placement.md` | EXTRACT-THEN-DELETE | Carry: SPM package-level (not target-level) cycle rejection; memory-below-vector tier ordering ruling; Option F _overrideLifetime zero-allocation span pattern as the reason inline bu… |
| `swift-memory-primitives/Research/memory-primitives-rawvalue-underlying-rename.md` | DELETE | Operational cascade plan for Tier-12 rawValue->underlying and Carrier->Carrier.Protocol renames; no own-field renames applied in this package. |
| `swift-memory-primitives/Research/Pointer-Stdlib-Interop-Design.md` | DELETE | Design paper recommending extension initializers on stdlib types for pointer-wrapper interop; entire substrate (pointer-primitives) since deleted. |
| `swift-memory-primitives/Research/Lifetime-Memory-Safety-Plan.md` | KEEP-EVIDENCE | Experiment record: initial ~Escapable interop hypothesis refuted — _overrideLifetime IS externally available; @_lifetime(immortal) alone fails. |
| `swift-memory-primitives/Research/lifetime-dependent-borrowed-cursors.md` | KEEP-EVIDENCE | Paper: Swift 6.2 ~Escapable closure-integration gap is real and deliberate; non-closure runner (protocol with parse(inout Input.View)) is structurally required. |
| `swift-memory-primitives/Research/allocation-substrate-first-principles.md` | ALIVE | Converged allocator contract: single region Memory.Allocator.Protocol (allocate+deallocate over Request->Block); Arena/Pool are concrete non-conforming siblings. |
| `swift-memory-primitives/Research/allocation-alignment-operation-domain-naming.md` | ALIVE | Applies operation-domain naming: allocation is a machine (four forms, bundled into substrate pass); alignment is a relation (Aligned->Memory.Alignable, no Aligner). |
| `swift-memory-primitives/Research/pointer-architecture-comparison.md` | EXTRACT-THEN-DELETE | Carry: (1) pointers-are-not-magic (Builtin.RawPointer structs); (2) binding/aliasing at SIL — delegate, never re-implement; (3) responsibility split table; (4) provenance argument fo… |
| `swift-memory-primitives/Research/pointer-primitives-design.md` | DELETE | Original pointer-wrapper architecture (Option 5 hybrid incl. Raw.Pointer.Mutable); index marks SUPERSEDED; package deleted from disk. |
| `swift-memory-primitives/Research/_index.json` | AMEND | Machine-readable index (generated 2026-04-18, patched to 2026-06-03); materially stale versus directory contents and file headers. |

#### A.6 carrier / array / slab / tree / split / collection singles (31 files)

| Path | Disposition | Extract carried (→ this doc) |
|---|---|---|
| `swift-primitives/swift-carrier-primitives/Research/Carrier Primitives Vision.md` | ALIVE | Consolidated v0.1.0 design rationale for Carrier<Underlying> phantom-wrapper super-protocol; supersedes 10 prior research docs (VISION, 2026-04-29). |
| `swift-primitives/swift-carrier-primitives/Research/sli-array.md` | ALIVE | DECISION (2026-04-24): Array<Element> skipped from carrier 0.1.0 SLI; trivial self-carriage zero payoff, parametric form locks Domain choice. |
| `swift-primitives/swift-carrier-primitives/Research/sli-clock-instants.md` | ALIVE | DECISION (2026-04-24): ContinuousClock/SuspendingClock Instants skipped; positional timeline points, not value wrappers; Duration is the one time conformance. |
| `swift-primitives/swift-carrier-primitives/Research/sli-contiguousarray.md` | ALIVE | DECISION (2026-04-24): ContiguousArray skipped, identical reasoning to sli-array; contiguous-storage guarantee orthogonal to Carrier. |
| `swift-primitives/swift-carrier-primitives/Research/sli-dictionary.md` | ALIVE | DECISION (2026-04-24): Dictionary skipped; two-parameter generic cannot map into single-Underlying Carrier without committing to one axis. |
| `swift-primitives/swift-carrier-primitives/Research/sli-foundation.md` | ALIVE | DECISION (2026-04-24): hard skip of ALL Foundation types (Date, URL, Data, UUID, ...) from every carrier-primitives target per [PRIM-FOUND-001]. |
| `swift-primitives/swift-carrier-primitives/Research/sli-inlinearray.md` | ALIVE | DECISION (2026-04-24): InlineArray (SE-0452, Swift 6.1+) skipped; Array reasoning plus awkward extra value-generic count axis. |
| `swift-primitives/swift-carrier-primitives/Research/sli-optional.md` | ALIVE | DECISION (2026-04-24): Optional skipped despite clean parametric form; Domain propagation choice is a one-way door without validated demand. |
| `swift-primitives/swift-carrier-primitives/Research/sli-range-family.md` | ALIVE | DECISION (2026-04-24): five Range types skipped; intervals are bound-pairs, no canonical single wrapped Underlying exists. |
| `swift-primitives/swift-carrier-primitives/Research/sli-result.md` | ALIVE | DECISION (2026-04-24): Result skipped; two-parameter sum type has no canonical Underlying; both-axes form needs a nonexistent stdlib Either. |
| `swift-primitives/swift-carrier-primitives/Research/sli-set.md` | ALIVE | DECISION (2026-04-24): Set skipped; element-unwrap parametric form breaks round-trip via hash inconsistency (cardinality can collapse). |
| `swift-primitives/swift-carrier-primitives/Research/sli-slice.md` | ALIVE | DECISION (2026-04-24): Slice skipped; it is a view borrowing base storage, not a wrapped value - semantic-identity mismatch plus Array-family issues. |
| `swift-primitives/swift-carrier-primitives/Research/sli-span-family.md` | ALIVE | DECISION revised twice in 2 days (v1.2.0, 2026-04-25): Span/MutableSpan/RawSpan/MutableRawSpan ADOPTED as one-line trivial-self Carrier conformances. |
| `swift-primitives/swift-carrier-primitives/Research/sli-taskpriority.md` | ALIVE | DECISION (2026-04-24): TaskPriority skipped; trivially viable but no evident cross-type dispatch value; rawValue is not stable API. |
| `swift-primitives/swift-carrier-primitives/Research/sli-unsafe-pointers.md` | ALIVE | DECISION (2026-04-24): all seven unsafe pointer types skipped; pointers reference memory rather than wrap values - category error for Carrier. |
| `swift-primitives/swift-carrier-primitives/Research/sli-void.md` | ALIVE | DECISION (2026-04-24): Void skipped; language wall - non-nominal tuple () cannot be extended (SE-0283 did not open nominal conformance). |
| `swift-primitives/swift-array-primitives/Research/_Package-Insights.md` *(unlisted)* | ALIVE | Non-normative insight log (v1.0.0, entries 2026-01-22 to 2026-04-26): constraint poisoning, pointer-acquisition wall, value-generic name shadowing. |
| `swift-primitives/swift-array-primitives/Research/array-discipline-boundary-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the boundary rule - ADT layer owns protocol conformances, semantic contracts (bounds checks, invariants) and thin delegation; Buffer owns storage, growth, CoW, ele… |
| `swift-primitives/swift-array-primitives/Research/array-foreach-redesign.md` | EXTRACT-THEN-DELETE | Carry forward the naming rule: forEach yields elements (stdlib-aligned); index iteration is the nested accessor .forEach.index; compound forEachIndex forbidden per [API-NAME-002]. No… |
| `swift-primitives/swift-array-primitives/Research/array-operations-audit.md` | EXTRACT-THEN-DELETE | Carry forward: (1) DiagnoseStaticExclusivity compiler crash blocking Array.Small ~Copyable _modify (re-probe on current toolchain); (2) Array.Bounded stub status + completion backlog… |
| `swift-primitives/swift-array-primitives/Research/array-protocol-unification.md` | EXTRACT-THEN-DELETE | Carry forward: (1) the 6.2-era wall + exact diagnostics AND its resolution via SuppressedAssociatedTypes (dated 2026-02-12); (2) protocol shape (Index: Comparable, count/startIndex/e… |
| `swift-primitives/swift-array-primitives/Research/repeating-reference-type-aliasing.md` | EXTRACT-THEN-DELETE | Carry forward the diagnostic rule: if Element is a class, repeating: produces N references to ONE object - use init(count:initializingWith:); plus the Pool.Bounded incident as proven… |
| `swift-primitives/swift-array-primitives/Research/se-0527-rigid-unique-array-alignment.md` | ALIVE | RECOMMENDATION (v1.6.0, 2026-04-24): SE-0527 RigidArray/UniqueArray comparison; OutputSpan-shaped APIs adopted via 15+ commits; mirror types refused. |
| `swift-primitives/swift-slab-primitives/Research/slab-discipline-boundary-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) zero-leak audit verdict + the slab-vs-buffer semantic boundary list (typed errors, composed ops, occupancy-aware access, typed indices ARE the data-structure layer… |
| `swift-primitives/swift-slab-primitives/Research/slab-primitives-design-variants-module-architecture.md` | ALIVE | DEFERRED (v1.0.1, 2026-03-15; IN_PROGRESS since 2026-02-11): full slab redesign - variants Slab/Static/Indexed, 4-module split, insert/remove naming. |
| `swift-primitives/swift-tree-primitives/Research/_Package-Insights.md` | ALIVE | Non-normative insight log (2026-01-20/22): Tree.Binary -> Tree.N<Element,2> consolidation, post-order bug fix, variant + Sendable patterns. |
| `swift-primitives/swift-tree-primitives/Research/tree-discipline-boundary-analysis.md` | EXTRACT-THEN-DELETE | Carry forward: (1) zero-leak verdict; (2) tree-over-arena as the third instance of the ADT-over-Buffer boundary pattern (with array-over-Linear, slab-over-Slab); (3) the error-case m… |
| `swift-primitives/swift-storage-split-primitives/Research/storage-split-to-columns-redesign.md` | ALIVE | DEFERRED (v1.0.0, 2026-05-25, principal ruling): converged redesign Storage.Split -> Storage.Columns as ~Escapable borrowed view; CoW class to buffer. |
| `swift-primitives/swift-collection-primitives/Research/_Package-Insights.md` | AMEND | Non-normative insight log (2026-01-22/02-13): omit-Element protocol design for ~Copyable compatibility; broken collection-foreach-test experiment. |
| `swift-primitives/swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md` | KEEP-EVIDENCE | DEFERRED-TOOLCHAIN-PRUNED (v1.2.0, 2026-05-09): Collection.Protocol ~Escapable admission refuted by exclusivity law; upstream Property inits pruned. |
| `swift-primitives/swift-pool-primitives/Research/` | DELETE | No .md files present - directory contains only _index.json (265 bytes). |


### 10.5 Tooling (A.7)

| Item | Disposition |
|---|---|
| `Scripts/adt-decoupling-classify.py` | AMEND (re-point to the [DS-026] predicate; regenerate ledger; keep as the mechanical gate until the AST-linter promotion lands) |
| `Primitives Linter Rule Tower/` (FrozenTowerType, CloneLessBox) | AMEND (keep; both rules survive; fixtures already track the current tree) |
| `Store.Ledgered` law support (`Buffer Primitives Test Support`) | KEEP (load-bearing per [DS-024]) |

### 10.6 Experiments (A.4 + this session's)

Per the A.4 table above (KEEP-EVIDENCE throughout; `g2` manifest fix per §9.6.8), plus this
session's three new packages — `adt-tower-walls`, `adt-variant-front-doors`,
`adt-tower-worked-example` — KEEP-EVIDENCE (they are this document's §3/§1.1 witnesses), indexed
in `Experiments/_index.json`.

---

## 11. References ([RES-026])

### Swift Evolution / upstream (primary)
- SE-0427 Noncopyable Generics — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md
- SE-0437 Noncopyable Standard Library Primitives — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md
- SE-0446 Nonescapable Types — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
- SE-0447 Span — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
- SE-0452 Integer Generic Parameters — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md
- SE-0453 InlineArray — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md ("There must never be an uninitialized element within a InlineArray")
- SE-0465 Nonescapable Standard Library Primitives — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0465-nonescapable-stdlib-primitives.md (pointer-pointee deferral)
- SE-0474 Yielding Accessors — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0474-yielding-accessors.md
- SE-0485 OutputSpan — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0485-outputspan.md
- SE-0499 Basic protocols with ~Copyable/~Escapable — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0499-inheritance-buildup.md
- SE-0503 Suppressed Default Conformances on Associated Types — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md
- SE-0507 Borrow and Mutate Accessors — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md
- SE-0516 Iterable — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md
- SE-0519 Ref and MutableRef — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-ref-mutableref-types.md
- SE-0527 RigidArray/UniqueArray — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md (LSG: accepted-in-principle; RigidArray demoted to internal core)
- swiftlang/swift#86652 (open; cross-module `@_rawLayout` deinit skip) — https://github.com/swiftlang/swift/issues/86652
- Default generic arguments: swift-evolution PR #591 (closed 2017, never reviewed) — https://github.com/apple/swift-evolution/pull/591
- Swift 6.4 Release Process — https://forums.swift.org/t/swift-6-4-release-process/85421
- stdlib sources (release/6.4.x): `Array.swift`, `ArrayBufferProtocol.swift`, `StringObject.swift`, `SmallString.swift`, `InlineArray.swift`, `BorrowingSequence.swift`, `ManagedBuffer.swift`, `HashTable.swift` — https://github.com/swiftlang/swift/tree/release/6.4.x/stdlib/public/core
- De-gyb Arrays commit — https://github.com/swiftlang/swift/commit/fd808f3ea7c

### apple/swift-collections (primary; pinned to 6c12132, 2026-07-01)
- `RigidArray.swift` / `UniqueArray.swift` / BasicContainers.docc — https://github.com/apple/swift-collections/tree/main/Sources/BasicContainers
- Issue #309 "Support fixed-size Deque" (closed COMPLETED 2026-04-24; the Rigid/Unique pivot) — https://github.com/apple/swift-collections/issues/309
- Issue #484 "InlineOrHeap sequence" (open; the maintainer position on inline/`SmallHeap`: "really really want… What we actually need … a proper inline array type, with a variable count, and partially initialized storage"; "2x the code → 2x the bugs") — https://github.com/apple/swift-collections/issues/484
- Release 1.3.0 (BasicContainers) — https://github.com/apple/swift-collections/releases/tag/1.3.0

### Rust / C++ / Zig / others (primary)
- RawVec — https://github.com/rust-lang/rust/blob/master/library/alloc/src/raw_vec/mod.rs ; Vec — https://github.com/rust-lang/rust/blob/master/library/alloc/src/vec/mod.rs
- allocator_api tracking #32838 (open since 2016) — https://github.com/rust-lang/rust/issues/32838
- RFC 3446 "Store" — https://github.com/rust-lang/rfcs/pull/3446 ; storage-poc — https://github.com/matthieu-m/storage-poc ; storages-api — https://github.com/CAD97/storages-api
- servo/rust-smallvec — https://github.com/servo/rust-smallvec ; RUSTSEC advisories — https://rustsec.org/packages/smallvec.html
- heapless storage-parameterized Vec — https://github.com/rust-embedded/heapless/blob/main/src/vec/mod.rs
- E0184 — https://doc.rust-lang.org/error_codes/E0184.html
- N1850 Towards a Better Allocator Model (Halpern) — https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2005/n1850.pdf
- P0843R14 inplace_vector — https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2024/p0843r14.html
- pmr::polymorphic_allocator — https://en.cppreference.com/w/cpp/memory/polymorphic_allocator
- boost small_vector — https://github.com/boostorg/container/blob/develop/include/boost/container/small_vector.hpp
- LLVM SmallVector (+ Programmer's Manual) — https://llvm.org/docs/ProgrammersManual.html#llvm-adt-smallvector-h
- Zig 0.15.1 / 0.16.0 release notes (unmanaged flip; BoundedArray removal) — https://ziglang.org/download/0.15.1/release-notes.html · https://ziglang.org/download/0.16.0/release-notes.html
- Hylo subscripts (projections) — https://docs.hylo-lang.org/language-tour/subscripts ; BoundedArray.hylo — https://github.com/hylo-lang/hylo/blob/main/StandardLibrary/Sources/BoundedArray.hylo
- Ada 2022 RM A.18.19 Bounded_Vectors — http://www.ada-auth.org/standards/22rm/html/RM-A-18-19.html
- .NET ValueListBuilder — https://github.com/dotnet/runtime/blob/main/src/libraries/Common/src/System/Collections/Generic/ValueListBuilder.cs

### Academic
- Wadler — Linear types can change the world! (1990) — https://homepages.inf.ed.ac.uk/wadler/topics/linear-logic.html
- Clarke/Potter/Noble — Ownership Types for Flexible Alias Protection (OOPSLA 1998) — https://www.cs.cornell.edu/courses/cs711/2005fa/papers/cpn-oopsla98.pdf
- Jung/Jourdan/Krebbers/Dreyer — RustBelt (POPL 2018) — https://plv.mpi-sws.org/rustbelt/popl18/paper.pdf
- Jung/Dang/Kang/Dreyer — Stacked Borrows (POPL 2020) — https://plv.mpi-sws.org/rustbelt/stacked-borrows/
- Tofte & Talpin — Region-Based Memory Management (Information & Computation 1997) — https://www.irisa.fr/prive/talpin/papers/ic97.pdf
- Grossman et al. — Region-Based Memory Management in Cyclone (PLDI 2002) — https://homes.cs.washington.edu/~djg/papers/cyclone_regions.pdf
- Berger/Zorn/McKinley — Reconsidering Custom Memory Allocation (OOPSLA 2002) — https://people.cs.umass.edu/~emery/pubs/berger-oopsla2002.pdf
- Halpern — Polymorphic Memory Resources, WG21 N3916 (2014) — https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n3916.pdf
- Reinking/Xie/de Moura/Leijen — Perceus: Garbage-Free Reference Counting with Reuse (PLDI 2021) — https://www.microsoft.com/en-us/research/uploads/prod/2020/11/perceus-tr-v1.pdf
- Lorenzen/Leijen/Swierstra — FP²: Fully in-Place Functional Programming (ICFP 2023) — https://www.microsoft.com/en-us/research/uploads/prod/2023/05/fbip.pdf
- Abbott/Altenkirch/Ghani — Categories of Containers (FoSSaCS 2003) — https://people.cs.nott.ac.uk/psztxa/publ/fossacs03.pdf
- Pottier/Protzenko — Programming with Permissions in Mezzo (ICFP 2013) — http://cambium.inria.fr/~fpottier/publis/pottier-protzenko-mezzo.pdf
- Tov/Pucella — Practical Affine Types / Alms (POPL 2011) — https://users.cs.northwestern.edu/~jesse/pubs/alms/tovpucella-alms.pdf
- O'Connor et al. — Cogent: Refinement through Restraint (ICFP 2016) — https://trustworthy.systems/publications/nicta_full_text/9425.pdf
- Minamide — A Functional Representation of Data Structures with a Hole (POPL 1998) — https://sv.c.titech.ac.jp/minamide/papers/hole.popl98.pdf
- Shaikhha/Fitzgibbon/Peyton Jones/Vytiniotis — Destination-Passing Style (FHPC 2017) — https://simon.peytonjones.org/assets/pdfs/destination-passing-style.pdf

### Internal evidence (paths of record)
- `Experiments/adt-tower-walls` (+ `Probes/`, `Outputs/`) — the §3 re-probe matrix, 6.3.3
- `Experiments/adt-variant-front-doors` — the D4.2 mechanism proof (0-witness)
- `Experiments/adt-tower-worked-example` — the §1.1 measured worked example (real upstream)
- `Experiments/adt-over-buffer-seam`, `storage-protocol-specialization`, `sparse-inline-slot-storage`, `g2-allocator-store-seam`, `cow-box-deinit-omission-miscompile`, `borrow-pointer-storage-release-miscompile` (+ the consolidated `nonescapable-patterns`, `noncopyable-constraint-behavior`) — inherited witnesses per §10.6
- `Audits/tower-layering-status-quo-2026-06-22.md`, `AUDIT-adt-decoupling-status.md`, `AUDIT-layering-violations-firstpass.md` — the audited ground state
- `Research/tower-family-benchmark-baselines.md` — §9.5 baselines (superseded as a document by §10.2; its numbers are carried there and re-pinned at W0)
- Every §6 claim traces to the primary links above (the SLR working reports were intermediate; their verbatim excerpts are reproduced or superseded by the primary citations). §10.2 per-file dispositions are self-contained in this document.
