# The Storage/Memory Split — Un-fusing `Storage<E>.Heap` into Storage-discipline-over-Memory-leaf

<!--
---
version: 1.1.0
last_updated: 2026-06-04
status: DECISION
tier: 3
scope: ecosystem-wide
normative: true (seat-ratified 2026-06-04 — all six asks; Phase E GO)
applies_to:
  - swift-store-primitives
  - swift-memory-heap-primitives (NEW — per-action YES pending)
  - swift-storage-primitives
  - swift-storage-pool-primitives / swift-storage-arena-primitives (conformance-ripple verification only)
  - the Buffer-tier + collection-tier consumers (source-stability verification only)
depends_on:
  - swift-institute/Research/cross-layer-capability-protocol-model.md (CLCPM, APPROVED + §12 v1.4.0 RE-APPROVED)
  - swift-institute/Research/memory-byte-bit-domain-orthogonality.md (RECOMMENDATION, Tier 3)
  - .handoffs/msb-tower-converged.md (ratified converged plan + the element-level-seam amendment)
  - .handoffs/HANDOFF-msb-tower-followups.md (§A #3 / #2 / #5a(i))
  - .handoffs/msb-tower-PROGRESS.md (the bd04f32 wall record; ASK-1 (b′); ①-rev-(i))
---
-->

> **Phase-D design packet for the supervisor seat** (dispatch: `HANDOFF-storage-memory-split.md`,
> principal-authorized 2026-06-04). Design-FIRST: **zero production edits made** — this doc, its
> `_index.json` entry, and the two `/tmp` probe packages are the only artifacts. Phase E fires only
> on seat ratification.
>
> **Coordination (seat relay, 2026-06-04): the span DESIGN BASELINE is POST-collapse.** A parallel
> arc ("Unify", follow-up #1, `HANDOFF-span-protocol-collapse.md`) is landing the
> `Span.Borrowed.Protocol` → single **`Span.Protocol: ~Copyable, ~Escapable` + `borrow self`**
> collapse (proven `/tmp/msb-span-unify`, 0-witness identical). Every `Span.Protocol` reference in
> this packet means the unified single-protocol form. **swift-span-primitives is Unify's zone —
> this arc does not touch it**; the leaf's conformance and Contiguous's conditional forwarding are
> spelled against whatever migrated conformance shape Unify lands (the protocol NAME is unchanged,
> so this packet's spellings are already baseline-correct; an Escapable `Memory.Heap` conforming
> the ~Escapable-relaxed unified protocol is admission-widening, not a change). **Phase E
> sequencing**: W-B/W-C worktrees branch off mains AFTER Unify's storage-closure migration lands —
> the leaf's `Memory.Heap+Span.Protocol` file ports the POST-Unify Heap conformance shape verbatim.

## Context

W3 left `Storage<E>.Heap` as ONE type fusing two domains: the **Memory leaf** (a single
`ManagedBuffer` allocation, its cleanup, its CoW backing identity) and the **Storage discipline**
(typed slot access, the uninit↔init ledger surface, the `Storage.Protocol` conformance the Buffer
tier composes). Follow-up **#3** dispatches the un-fusing into the model's true shape —
`Storage.Contiguous<M>`-class composition over a class-backed Memory leaf — with **#2**
(`Storage.Flat` → `Storage.Contiguous`) riding along, and #5a(i) fixing the end-state spelling:
`Buffer<Storage<E>.Contiguous<Memory.Heap<E>>>.Ring` *(today's `Storage<E>.Heap` is the correct
intermediate spelling, kept source-stable through this arc)*.

**The binding constraint (the `bd04f32` wall, verified in msb-tower-PROGRESS.md:66–67):**
`deinitializer cannot be declared in generic struct that conforms to Copyable`. A conditionally-
Copyable generic struct can NEVER carry `deinit` — so the cleanup oracle MUST live in the LEAF's
class (Heap's own Backing pattern; cf. Split delegating to CoW Heap planes), NEVER in the generic
composer (Storage.Slab's failure mode, which forced the Box relocation and ①-rev-(i)).

## Questions

1. **The shape**: what exactly is the Memory leaf, what remains in the discipline, and where does
   the initialization ledger live — given the wall, the domain model, and [MOD-032] package acyclicity?
2. **Open (a)**: the CoW/Copyable story — Array's backing rides Heap's CoW façades today; how does
   conditional Copyability + `isUnique`/`ensureUnique` survive the composition?
3. **Open (b)**: Inline's borrow-threaded lens — no class, stack-stored: what is *its* leaf?
4. **Open (c)**: the typealias-first migration — `Storage<E>.Heap` spellings (≈230 production files
   across ≈25 packages, incl. 209 `S == Storage<E>.Heap` same-type pins) MUST stay source-stable.

## Internal Research Survey [RES-019]

| Document | Status | Bearing |
|---|---|---|
| CLCPM v1.4.0 (§3.3, §3.4, §12) | APPROVED; §12 RE-APPROVED 2026-06-03 | GOVERNS. §3.3 = the 0-`witness_method` HARD gate this packet's receipts replicate. §3.4's `Storage.Protocol` spec (`capacity` + `@unsafe pointer(at:)`) is **stale** — predates the W3 element-level seam (Store.Protocol) and the ASK-1 (b′) `initialization` lift; **fold-back item** (same path §12 took). §12 = span is a cross-cutting capability — this packet's leaf conforms `Span.Protocol` accordingly. |
| msb-tower-converged.md (+ ratified amendment) | CONVERGED | The tower (`Buffer<S>` → `Storage<M>` → owned leaves); the element-level mutate seam (MutableSpan never a generic seam); "validate seam shapes cross-module (2-module probe)". |
| memory-byte-bit-domain-orthogonality.md v1.0.0 | RECOMMENDATION (Tier 3) | Memory = the location/layout axis; capabilities namespace-neutral. The leaf joins the Memory strategy family (Arena/Pool/Aligned/Unbounded + **Heap**). |
| memory-storage-composition-feasibility.md v1.0.0 | RECOMMENDATION | The raw/typed split; Memory as the owned-region layer — the composition direction this packet realizes. |
| nonescapable-support-memory-storage-buffer.md v2.1.0 | DECISION | The owned/borrowed span lifetime regimes the leaf's `span` honors. |
| msb-tower-PROGRESS.md | live record | bd04f32 (the wall) · ASK-1 (b′) (`initialization` on `Storage.Protocol`; inert vends sanctioned for non-range oracles) · A2-addendum: *"Flat's non-inert witness = SUBSTRATE-FORWARDING under follow-up #3, parked"* — **this packet un-parks it** · ①-rev-(i): Storage.{Arena,Pool} oracles KEPT (out of scope here beyond ripple verification) · follow-up #18 (the Flat stored-`_initialization` compiler diagnostic) — **sidestepped by this design** (no stored ledger in the discipline). |
| storage-buffer-abstraction-analysis.md v1.2.0 | — | Historical Storage/Buffer rationale; superseded in detail by the converged tower, cited for lineage. |

## Empirical State Verification [RES-023] (all verified on disk 2026-06-04, post-W3 pushed mains)

- **The fused type**: `Storage<E>.Heap` = `~Copyable` struct over `final class Buffer: ManagedBuffer<Header, Element>` whose **deinit walks `header.initialization`** (`Storage.Heap.swift:62–113`); ledger lives in the **class header** (`Storage.Heap.Header.swift:21–34`); `Copyable where Element: Copyable` (`Storage.Heap.swift:135`); `initialization { get; nonmutating set }` (`Storage.Heap ~Copyable.swift:56–59`); `isUnique`/`ensureUnique()` Copyable-path only (`Storage.Heap Copyable.swift:27`, comment at `~Copyable.swift:79–84`).
- **The seam**: `Store.Protocol` (`__StoreProtocol`) = capacity + `subscript {get set}` (`_read`/`_modify`) + `initialize(at:to:)` + `move(at:)` (`Store.Protocol.swift:20–69`, FROZEN per CLCPM §12); `Storage.Protocol` = that + `var initialization: Storage<Element>.Initialization { get set }` (`Storage.Protocol.swift:34–45`), inert `.empty` vends explicitly sanctioned for non-range oracles (`:39–44`).
- **The existing discipline**: `Storage.Flat<Substrate: Store.Protocol> where Substrate.Element == Element` (`Storage.Flat.swift:46–61`); 4-op forwarding (`Storage.Flat+Storage.Protocol.swift:20–68`); **inert** `initialization` witness with the supervisor-sanctioned comment (`:72–84`); conditional `Span.Protocol where Substrate: Span.Protocol` (`Storage.Flat+Span.Protocol.swift:19`); **unconditionally `~Copyable` today** (no Copyable extension); **zero consumers outside swift-storage-primitives** (workspace grep, incl. foundations + standards: empty).
- **Discipline usage of the fused surface** (the source-stability contract): `storage.initialization = header.initialization` ×14 (buffer-linear) + ×7 (buffer-ring) and `= .empty` ×3/×5; `storage.ensureUnique()` ×2/×2; `storage.mutableSpan(count: header.count)`; `storage.move(at:)` / `initialize(at:to:)`; `heap._storage.pointer(at:)`; `storage.outputSpan`; `storage.move(range:to:at:)` (verb-namespace bulk op); **209 `S == Storage<E>.Heap` same-type pins** across buffer/array/stack/heap/set-ordered/dictionary/hash-table/arena.
- **Spelling blast radius**: ≈230 production files across ≈25 packages spell `Storage.Heap`/`Storage<X>.Heap`. `Heap.Header`: **zero** references outside swift-storage-primitives. `extension Storage.Heap`: **zero** outside swift-storage-primitives (13 in-package files = the migration's own rewrite set).
- **Inline**: `Storage<E>.Inline<let count: Int>` = `@_rawLayout` + `_slots: Bit.Vector.Static<4>`; seam ops auto-update bits; **no deinit** — consumer-drains contract (`Storage.Inline.swift:35–61`); real (derived, linear-discipline) `initialization` witness (`Storage.Inline ~Copyable.swift:100–114`); unconditionally `~Copyable`.
- **Sendable**: Heap has **no** Sendable conformance (grep empty) — no Sendable surface to preserve.
- **`Storage Initialization Primitives`**: its own target, deps = Index Primitives only (`Package.swift:66–73`) — the relocation candidate is already isolation-shaped.

## Prior Art [RES-021]

- **Swift stdlib**: `Array` = value façade over `_ContiguousArrayStorage` (cited as the model in `Storage.Heap.swift:31–40`); `ManagedBuffer` direct use is the sanctioned interim per [DS-022]. The leaf keeps this exact pattern — relocated, not re-invented.
- **Rust**: `Vec<T>` = {`RawVec<T>` (allocation leaf: ptr+cap, owns alloc/dealloc/grow) + `len` (discipline)}. The discipline/leaf split is the industry-standard shape. **Divergence (deliberate)**: Rust drops elements in `Vec::drop` (discipline-side) and memory in `RawVec::drop`; here BOTH live in the leaf, because (i) the bd04f32 wall forbids discipline-side deinit under conditional Copyability, and (ii) CoW sharing makes element ownership a property of the *backing*, not of any one façade copy. [Verified against rust-lang `raw_vec.rs` design as of knowledge cutoff; the wall + CoW arguments are toolchain-empirical and stand on the receipts regardless.]
- **C++**: `std::vector<T, Allocator>` — allocation strategy as a composed parameter; the leaf-as-parameter (`Contiguous<M>`) is the same axis, typed.
- **Contextualization**: universal adoption of discipline/leaf splits does not by itself mandate ours ([RES-021]); the institute-specific forcing facts are bd04f32 + the tower's substitution model + the Memory strategy family the orthogonality doc establishes. Those are receipted independently.

## The Design (A3′)

### 1. The protocol stack — insert `Store.Tracked.Protocol`; everything else keeps its surface

```
Store.Protocol            (swift-store-primitives — FROZEN 4-op seam; UNTOUCHED)
  ⊂ Store.Tracked.Protocol  (swift-store-primitives — NEW: + var initialization { get set })
      ⊂ Storage.Protocol      (swift-storage-primitives — becomes a PURE MARKER refinement;
                               requirement set seen by consumers is IDENTICAL — the
                               `initialization` requirement now arrives by inheritance)
```

- `__StoreTrackedProtocol: __StoreProtocol, ~Copyable { var initialization: Store.Initialization<Element> { get set } }` — the
  doc language transplants **verbatim** from today's `Storage.Protocol.swift:36–44` (range-tracked
  view the store's OWN teardown honors; non-range oracles vend `.empty` — the sanction travels with
  the requirement).
- `__StorageProtocol: __StoreTrackedProtocol, ~Copyable {}` — keeps its single-region slot-topology
  marker semantics; **zero consumer-visible change** (every `S: Storage.Protocol` constraint sees
  the same five requirements).
- **Conformance ripple = zero**: Inline / Pool / Arena / Split witnesses already exist and satisfy
  the inherited requirement unchanged (their `Storage<E>.Initialization`-spelled types resolve
  through the §3 alias). Verified shape in probe P1; W-D re-verifies on the real packages.

### 2. The ledger relocates to swift-store-primitives ([MOD-032]-forced)

`Storage<E>.Initialization` (enum: `.empty/.one/.two`) moves to swift-store-primitives as
**`Store.Initialization<Element: ~Copyable>`** (new target `Store Initialization Primitives`,
deps = index only — today's target is already exactly this shape). swift-storage-primitives'
`Storage Initialization Primitives` target becomes a **shim**: `@_exported public import` + 
`extension Storage { public typealias Initialization = Store.Initialization<Element> }`.

*Why forced*: the leaf must vend the ledger (its header field + its oracle + its Tracked
conformance), so the ledger type must be visible from the leaf's package; the leaf's package must
sit strictly below swift-storage-primitives (storage-pkg re-exports the leaf for import-stability,
so the reverse edge would complete a [MOD-032] package cycle). Placement at store-primitives over a
new package per [MOD-020] (dep-delta zero against the nearest family member). Domain note: the
seam's `initialize(at:to:)`/`move(at:)` ARE the uninit↔init transitions (converged amendment) —
the ledger is that same concern's *state vocabulary*; `Store`'s "no lifecycle policy" charter
refers to *policy* (the Tracked refinement is opt-in capability, not imposed policy).

### 3. The leaf — `Memory.Heap<Element: ~Copyable>` (NEW package `swift-memory-heap-primitives`)

Today's `Storage<E>.Heap` mechanics relocate wholesale (same `~Copyable` struct-over-
`ManagedBuffer` shape, same Header-carries-ledger, same Backing-deinit oracle, same
`Copyable where Element: Copyable`, same `isUnique`/`ensureUnique` Copyable-path, same
`create`/`span`(tracked-prefix)/`mutableSpan(count:)`/`outputSpan`/`pointer(at:)`/bulk-move):

- **Conformances**: `Store.Protocol` + `Store.Tracked.Protocol` + `Span.Protocol` (the
  post-collapse unified form per the baseline note; the conformance body ports the post-Unify
  Heap shape). **NOT `Storage.Protocol`** — the storage-tier identity is precisely what the leaf
  must not carry;
  carrying it would make the composition decorative and (via the shim's re-export direction)
  complete the [MOD-032] cycle.
- **Package**: `swift-memory-heap-primitives`, joining the Memory strategy family
  (memory-{arena,pool,aligned,unbounded}; [MOD-035] memory-primitives scope statement keeps
  strategies OUT of the substrate package). Deps: swift-memory-primitives (`Memory Primitive`
  zero-dep root + Address/Alignment as needed), swift-store-primitives, swift-span-primitives,
  swift-index-primitives, swift-standard-library-extensions. **No storage dep** (the invariant).
  Tier = max(deps)+1 per [PRIM-ARCH-002], computed at Phase E. Package creation = per-action YES.
- **Domain-model note (ask-4)**: the converged doc's "Memory … no init frontier" line refines to:
  Memory *leaves* MAY carry a **cleanup ledger** as part of their owned-region teardown contract
  (allocation strategies own correct teardown — Arena/Pool already carry token/bitmap oracles at
  their own tiers); the init-transition *semantics* (the protocol surface, the discipline) remain
  Storage's. Same refinement class as the §12 span amendment; seat ratifies the wording.

### 4. The discipline — `Storage.Contiguous<M>` (the #2 rename of `Storage.Flat`)

- **#2 rename executes here**: type + target + files (`Storage Flat Primitives` → `Storage
  Contiguous Primitives`); zero external consumers (receipt above), no deprecation shim needed;
  names the real axis and rhymes with `Memory.Contiguous` as the follow-ups specify.
- Gains **conditional Copyable**: `extension Storage.Contiguous: Copyable where Element: ~Copyable, Substrate: Copyable {}`
  (NEW — Flat is unconditionally ~Copyable today; required for the Heap CoW chain). No deinit
  anywhere — the wall is respected by construction.
- Gains the **layered conditional conformances** (probe P1, C2):
  `: Store.Protocol` unconditional · `: Store.Tracked.Protocol where Substrate: Store.Tracked.Protocol`
  (the **substrate-forwarding `initialization` witness** — the parked A2-addendum item, realized:
  `get { _substrate.initialization } set { _substrate.initialization = newValue }`) ·
  `: Storage.Protocol where Substrate: Store.Tracked.Protocol`.
- The **inert witness is deleted from the discipline**. Consequence (deliberate, [IMPL-COMPILE]):
  a Contiguous over an *untracked* store is `Store.Protocol`-only — it cannot enter
  `S: Storage.Protocol` dense disciplines, whose ledger-sync teardown contract an untracked
  substrate cannot honor. The silent-leak path the inert witness left open is now unrepresentable.
  (Inert vends remain sanctioned where they belong: the kept Pool/Arena oracles at the storage tier.)
  Zero consumers lose anything (Flat-over-untracked consumers: none).
- Conditional `Span.Protocol where Substrate: Span.Protocol` stays as-is (production-proven).
- Stored-field note: the discipline holds ONLY `_substrate` — no stored ledger — so the follow-up
  #18 compiler diagnostic (stored `_initialization` in a conditionally-Span-conforming generic)
  is structurally sidestepped, not worked around.

### 5. The typealias + the pinned surface (open (c))

```swift
extension Storage where Element: ~Copyable {
    public typealias Heap = Storage<Element>.Contiguous<Memory.Heap<Element>>
}
```

- `Storage Heap Primitives` target becomes the **shim**: the typealias + `@_exported public import
  Memory_Heap_Primitives` (imports stay stable: `import Storage_Heap_Primitives` keeps working) +
  the **pinned ergonomics surface** in `extension Storage.Contiguous where Element: ~Copyable,
  Substrate == Memory.Heap<Element>` form: `create(minimumCapacity:)` · `isUnique`/`ensureUnique()`
  (Copyable) · `mutableSpan(count:)` · `outputSpan` · `pointer(at:)` ×2 · `isEmpty` · the verb
  namespaces `initialize`/`move`/`deinitialize`/`copy` (Property.Inout tags stay in `Storage
  Accessor Primitives`; bodies forward to leaf public ops — incl. the Copyable variants' CoW
  routing, preserved 1:1). Generalization of the verbs to any Tracked substrate is follow-up-#5
  territory, deliberately not taken now.
- **C6 wall (probe finding)**: `extension Storage.Heap` (unbound) through the generic typealias is
  REJECTED by 6.3.2 ("reference to generic type 'Storage' requires arguments") — the pinned
  spelling above is the migration form. Blast radius: in-package only (zero consumer extensions).
- `Storage<E>.Heap.Header` dies as a spelling (zero external refs); the leaf owns `Memory.Heap.Header`.
- storage-pkg gains the dep on swift-memory-heap-primitives; direction verified acyclic (probe P1
  mirrors it at module level: LeafKit never imports StorageKit).

### 6. Open (a) — the CoW/Copyable story: RESOLVED

The chain `Array: Copyable where E: Copyable` → `Buffer.Linear: where S: Copyable` →
`Contiguous: where Substrate: Copyable` → `Memory.Heap: where Element: Copyable` type-checks
through three conditional layers, diverges correctly under mutation, double-frees nothing, and
keeps move-only instantiations noncopyable (SIL-level negative receipt). `isUnique`/`ensureUnique`
reach the leaf's `isKnownUniquelyReferenced(&_buffer)` through the pinned forwarders; the
occupancy-aware deep copy honors the ledger leaf-side (self-contained — the ledger lives where the
copy happens). Receipts: P1 C2/C7/C7b + negative-copy.log.

### 7. Open (b) — Inline's leaf: RESOLVED (design), DEFER (execution)

**The answer**: Inline's leaf is a **tracked value store** — no class; the "oracle" is not a
deinit but the consumer-drains contract, and the tracking (bitmap, auto-updated by the seam ops)
IS the leaf's ledger, vended through the same `Store.Tracked.Protocol`. The borrow-threaded lens
is the existing conditional `Span` forwarding (production-proven on Flat, W3 `e436e67`) over
Inline's own shipped `Span.Protocol` conformance. Probe P2 proves the full composition
mechanically — **including the value-generic typealias** `Storage<E>.Inline<let n: Int> =
Contiguous<Memory.Inline<Element, n>>` — in debug AND release (the historical rawLayout
release-crash class did not fire).

**Recommendation: do NOT dissolve Inline in this arc.** (i) Its tracking discipline differs in
kind (active bitmap auto-track vs Heap's passive synced ledger) — unifying those semantics is
exactly the tracked-substrate design the supervisor deferred to follow-up #5's second creatable
substrate (Q2 ruling); Small's inline arm will force it with a real consumer. (ii) Zero consumer
pressure now; (iii) feasibility is banked (P2), so deferral loses nothing and avoids perturbing
`Memory.Inline` (today raw/untracked, [DS-006]) ahead of need. Heap-only dissolution this arc.

### 8. Formal sketch [RES-024]

- **Copyability law**: `Copyable(Contiguous<M>) ⇔ Copyable(M)`; `Copyable(Memory.Heap<E>) ⇔
  Copyable(E)`; composed: `Copyable(Storage<E>.Heap) ⇔ Copyable(E)` — extensionally identical to
  the fused type's law. (Receipt: P1 C2 + negative.)
- **Oracle invariant**: for every Backing b, at deinit(b): exactly the slots in
  b.header.initialization are deinitialized, then the region frees. Disciplines preserve
  "ledger ⊆ initialized-slots" across ops (sync sites); CoW copies preserve the invariant by
  copying ledger+elements atomically leaf-side. (Receipt: P1 C3/C3b/C4/C7.)
- **Specialization (§3.3 HARD)**: concrete driver through Ring→Contiguous→Heap-leaf = 0
  `witness_method` at -O cross-module; residuals confined to retained public-@inlinable generic
  fallback bodies (the §3.3-blessed class). (Receipt: P1 consumer.sil, function-level attribution.)

### 9. Alternatives rejected

| Alt | Shape | Rejection |
|---|---|---|
| A1 | Keep inert witness; pinned shadow for Heap | Generic `S: Storage.Protocol` sync sites dispatch the WITNESS → inert → silent teardown leak on the composed Heap. Dead. |
| A2′ | Put `initialization` on `Store.Protocol` itself | Reopens the FROZEN 4-op seam (CLCPM §12 ratified text); contradicts Store's neutrality charter (`Store.swift:17`); forces ledger noise onto every minimal store. Mechanics subsumed by P1 anyway. |
| A5/A6 | Leaf conforms `Storage.Protocol` directly | Domain inversion (the leaf carrying the storage-tier identity makes the composition decorative) + completes the [MOD-032] package cycle through the import-stability re-export. |
| Thin leaf (ledger in discipline, cleanup closure / synced count in leaf) | — | bd04f32 (no discipline deinit) + the Slab lesson ("the 'redundant' sync was oracle maintenance") + Ring's two-segment ledger doesn't reduce to a count. |
| No split (status quo) | — | Contradicts the principal's named first post-push priority and the model's true shape (#5a(i)). |

### 10. Phase E plan (fires on ratification; worktrees under `/Users/coen/Developer/.split-wt/`; per-step commits; no push/tag)

- **W-A — swift-store-primitives**: add `Store Initialization Primitives` (ledger, relocated) +
  `Store Tracked Primitives` (`__StoreTrackedProtocol` + namespace alias). Tests. Suite green.
- **W-B — swift-memory-heap-primitives (NEW; per-action YES)**: `Memory.Heap` per §3 (mechanics
  ported from the 13 Heap files); port Heap's test coverage. Suite green.
- **W-C — swift-storage-primitives**: ledger target → shim · `Storage.Protocol` → marker
  refinement (doc transplanted) · Flat→Contiguous rename (#2) + conditional Copyable + layered
  conformances + forwarding witness (inert deleted) · `Storage Heap Primitives` → shim + pinned
  surface · `Storage.swift` table refresh. Storage suite green (Inline/tests adjusted in-package).
  **W-C checklist riders (seat-confirmed at W-A close, 2026-06-04):** (i) the [API-NAME-010b]
  maximal-suppression widening of `Store.Initialization`'s Element (`~Copyable` →
  `~Copyable & ~Escapable`) folds in HERE, where the storage-side alias binds it — advisory-tier,
  non-breaking, deliberately not churned into W-A; (ii) the CLCPM §3.4 fold-back amendment block
  (the §12 form) drafts inside W-C's doc pass per ratified ask-6, seat reviews at the W-C close.
- **W-D — closure verify**: serial clean `swift build && swift test` at ratified bars across the
  tower closure (storage, buffer-{linear,ring,slab,slots,linked,arena}, array, stack*, heap*,
  set-ordered, dictionary, hash-table, + the 13-package wave set incl. L3 swift-async*) — *the
  starred entries at their standing exception bars; **zone exclusions honored**: no edits in
  deque/async-primitives/L3-swift-async (#19), property-primitives (#20), tensor (#21),
  collection/iterator + `.drift-wt/` (P-1), **swift-span-primitives (#1 Unify; seat relay
  2026-06-04)** — those packages are VERIFY-ONLY here, and any red traced to this arc is a STOP. Expected source edits outside the three owned packages: **zero**
  (typealias-first; receipts above). Pool/Arena: build+test only (ripple bar: zero edits).
- **W-E — receipts + gates**: fresh 0-`witness_method` receipt on the REAL modules (the
  `/tmp/msb-real-tower-receipt` harness re-pointed at `Contiguous<Memory.Heap<Int>>`); the
  [HANDOFF-035] termination greps incl. Package.swift declarations; honest-record receipt form.
- **Acceptance criteria** (all disk/build-verifiable): (1) every W-D package at its ratified bar
  with zero source edits outside {store, memory-heap, storage} except none; (2) `Storage<E>.Heap`
  / `Storage<E>.Initialization` spellings compile unchanged ecosystem-wide (grep + builds); (3)
  0-witness receipt on real modules; (4) the three deleted/renamed internals (`Storage.Heap`
  struct, `Storage.Flat` name, in-storage ledger enum) have zero residual references
  ([HANDOFF-040] generic-instantiated forms included); (5) oracle + CoW behavior pinned by ported
  tests incl. a new composed-CoW divergence suite.

### 11. `ask:` items for the seat (ratification points)

1. **A3′ stack**: insert `Store.Tracked.Protocol` + relocate the ledger into swift-store-primitives
   (two NEW targets; `Store.Protocol` itself untouched — the frozen 4-op text stands).
2. **Conditional `Storage.Protocol` on Contiguous** (supersedes Flat's sanctioned inert witness —
   the (b′) sanction's *wording* lives on in Tracked's transplanted doc; the discipline-side inert
   vend is removed). This is the un-parking of the A2-addendum item explicitly reserved for #3.
3. **`swift-memory-heap-primitives` creation** (name #5a(i)-anchored; per-action YES at W-B).
4. **The converged-doc Memory-domain wording refinement** (§3 above — cleanup ledger at leaves;
   init-frontier semantics stay Storage's).
5. **Open (b) disposition**: Inline stays fused this arc; composed-Inline feasibility banked (P2)
   toward follow-up #5.
6. **CLCPM §3.4 fold-back** (the stale `Storage.Protocol` spec → the W3 seam + this packet's
   marker shape) — drafted as part of W-C's doc pass or its own follow-up, seat's choice.

## Probe receipts (CLCPM §3.3 protocol; [EXP-017] release + cross-module)

| Probe | Where | Verdict |
|---|---|---|
| P1 — composed shape, layered conditional conformances, oracle placement, generic ledger sync, CoW chain, typealias + 209-pin class, 0-witness | `/tmp/split-probe` (4 modules mirroring the package boundaries + exe) · `Outputs/SIL-RECEIPT.md`, `run-{debug,release}.txt`, `consumer.sil` (1905 lines; hot driver = 0 `witness_method`), `negative-copy.log` (SIL-level move-only rejection) | **ALL PASS** (21 runtime checks, debug + release) + C6 wall documented (unbound `extension Storage.Heap` rejected → pinned spelling; zero consumer impact) |
| P2 — open (b): tracked value leaf, @_rawLayout, value-generic typealias, release | `/tmp/split-probe-inline` · `Outputs/RECEIPT.md`, `run-{debug,release}.txt` | **ALL PASS** (6 checks, debug + release) |

## Outcome

**Status: RECOMMENDATION** — the seat ratifies the six `ask:` items; Phase E then executes W-A…W-E
under the dispatch's standing ground rules (worktree-local, per-step commits, suites + 0-witness
receipts per wave, zone exclusions, no push/tag; publication is its own later principal gate).

## References

- CLCPM: `swift-institute/Research/cross-layer-capability-protocol-model.md` §3.3/§3.4/§12
- Orthogonality: `swift-institute/Research/memory-byte-bit-domain-orthogonality.md` v1.0.0
- Converged plan: `.handoffs/msb-tower-converged.md` (+ the element-level-seam amendment)
- Follow-ups index: `.handoffs/HANDOFF-msb-tower-followups.md` §A #3/#2/#5a(i), #18, #5-Q2
- Span collapse (the design baseline): `.handoffs/HANDOFF-span-protocol-collapse.md` (#1 Unify; proven `/tmp/msb-span-unify`)
- W3 record: `.handoffs/msb-tower-PROGRESS.md` (bd04f32: :66–67; ASK-1 (b′): :90; A2-addendum: :119; Slab Box: :91)
- Production sources: file:line citations inline in §Empirical State Verification
- Probes: `/tmp/split-probe`, `/tmp/split-probe-inline` (receipts inside)
- Cross-language: Rust `RawVec`/`Vec`, C++ `std::vector<T, A>`, Swift `_ContiguousArrayStorage` ([DS-022])

## Changelog

- **v1.1.0** (2026-06-04): **RATIFIED — status → DECISION.** Seat ruling (relay 2026-06-04): all
  six asks ratified (A3′ stack · conditional `Storage.Protocol` + inert-witness deletion, the
  (b′) discipline-side sanction formally superseded · `swift-memory-heap-primitives` per-action
  YES carried · converged-doc Memory-wording refinement · Inline stays fused, P2 banked toward
  follow-up #5 · CLCPM §3.4 fold-back drafts inside W-C). Probes banked to
  `~/Developer/.probe-bank/`. **Phase E GO**: W-A executed + seat-verified PASS
  (`.split-wt/swift-store-primitives` @ `storage-memory-split`: `c34fd64` ledger relocation,
  `a03f547` Store.Tracked.Protocol; suite 20/6; 0-witness receipt banked to
  `.probe-bank/wa-receipt`). W-B/W-C HOLD for the seat's Unify-merge signal (span baseline =
  post-collapse single `Span.Protocol`). W-C checklist riders added (the [API-NAME-010b]
  widening; the §3.4 fold-back).
- **v1.0.0** (2026-06-04): Initial Phase-D design packet. A3′ (Tracked insertion + ledger
  relocation + Memory.Heap leaf + conditional Storage.Protocol on the renamed Contiguous +
  typealias-first source stability); opens (a)/(b)/(c) resolved with 2-module-or-deeper /tmp
  probes and 0-witness receipts; Phase E wave plan; six seat ratification points. Zero production
  edits.
