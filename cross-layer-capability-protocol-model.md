# Cross-Layer Capability-Protocol Model

<!--
---
version: 1.1.0
last_updated: 2026-05-28
status: RECOMMENDATION
approved: 2026-05-28 (supervisor)
tier: 3
scope: ecosystem-wide
type: investigation/architecture
changelog:
  - "1.1.0 (2026-05-28): Supervisor APPROVED (SIL receipt verified against the real file — hot-path 0-witness confirmed; sequencer-refactor landing + Buffer.Protocol-extended-not-superseded confirmed). §3 normal form + Set.Protocol elevation approved as the ×16 fan-out template foundation. Decisions #1/#3/#4 approved as recommended. Decision #2's substrate condition RESOLVED: the principal authorizes a bounded-lattice package (swift-algebra-lattice = existing semilattice + absorption) + a Boolean-algebra package (on Swift.Bool + the algebra family; name per [PKG-NAME-*]), so the swift-set-algebra-primitives bridge witnesses ∪=join/∩=meet/∁=complement over REAL packaged structures, not prose (§4.2/§8). Research phase concluded. Execution sequenced by the principal — NOT begun."
  - "1.0.0 (2026-05-28): Initial RECOMMENDATION + Set.Ordered pilot + SIL receipt; corrected mid-investigation per the principal (algebra is a THIRD orthogonal concern, decomposed into the set-algebra-primitives bridge)."
---
-->

> **RECOMMENDATION (Tier 3, ecosystem-wide / cross-layer) — APPROVED 2026-05-28 (supervisor).** The
> theoretically-optimal capability-protocol model for the data-structure stack — `Memory.Contiguous.Protocol`
> / `Storage.Protocol` / `Buffer.Protocol` / `Set.Protocol`, and how they relate to the iteration substrate
> (`Iterable` / `Iterator.Borrow` / `Sequenceable`) — so a conformer **inherits as much as theoretically
> possible for free**, bounded by the specialization boundary.
>
> **APPROVAL (2026-05-28).** The supervisor verified the SIL receipt (real file; hot-path 0-witness), the
> `sequencer-refactor` landing, and `Buffer.Protocol`-extended-not-superseded, and **approved** the §3
> normal form + the `Set.Protocol` elevation as **the ×16 fan-out template foundation**. Decisions
> #1/#3/#4 (§8) approved as recommended; **Decision #2's substrate condition is RESOLVED** — the principal
> authorizes the new algebra-structure packages the bridge needs (§4.2/§8). **The research phase concludes
> here.**
>
> **This remained a PLAN throughout. No production code was landed; no live package or worktree was edited.**
> The pilot is a `/tmp` prototype. **WHOLE STACK OPEN** (principal, 2026-05-28): this model is *senior* to
> the recently-landed `Buffer.Protocol` and the in-flight iteration / buffer-dedup arcs. **Execution is
> sequenced by the principal and has NOT begun** — do not land from this doc.
>
> Toolchain of record for all empirical claims: **Apple Swift 6.3.2 (swiftlang-6.3.2.1.108),
> arm64-apple-macosx26.0**.

---

## Context

The data-structure stack is composed in four layers ([DS-001]): **Memory → Storage → Buffer →
Collection**, each adding exactly one concern. Three of those layers, plus the set family at the
collection tier, expose a *capability protocol*:

| Protocol | Package | Concern | Today's shape |
|----------|---------|---------|---------------|
| `Memory.Contiguous.Protocol` (`Memory.ContiguousProtocol`) | swift-memory-primitives | physical contiguous *read* | `span` + unsafe escape hatch |
| `Storage.Protocol` (`__StorageProtocol`) | swift-storage-primitives | physical slot *access* | `capacity` + `pointer(at:)` |
| `Buffer.Protocol` (`__BufferProtocol`) | swift-buffer-primitives | logical *occupancy* | `count` + `isEmpty` default (relaxed `Count`) |
| `Set.Protocol` (`__SetProtocol`) | swift-set-primitives | set *membership/algebra* | `contains` + `forEach` + `count` → algebra defaults |

They are **not yet coherently related**: a conformer does not inherit the maximum it could, the four
were designed at different times against different framings, and `Set.Protocol` in particular "was not
well thought through" (principal) — it reads as a narrow algebra add-on rather than the genuine
**set-layer capability surface**, the true peer of `Buffer.Protocol` / `Storage.Protocol`.

**Trigger** ([RES-001]/[RES-011]): the principal opened the whole stack to redesign (2026-05-28) and
asked for the theoretically-optimal cross-layer model that maximizes free inheritance. This is a Tier 3
investigation ([RES-020]): ecosystem-wide, cross-layer, precedent-setting, establishing a long-lived
semantic contract that future data-structure APIs depend on; formalization and a specialization
receipt are mandatory.

**Seniority.** Per the principal's scope, this model is senior to:
- the **recently-landed `Buffer.Protocol`** (v2 / A′, on `swift-buffer-primitives` main `126e99a`);
- the **in-flight iteration arc** (`unified-iteration-design.md` v1.3.0, set-ordered reference rework AUTHORIZED);
- the **in-flight buffer-dedup spike** (`spike/buffer-storage-dedup`).

Its dispositions toward each are stated explicitly in §7 (per [HANDOFF-013]).

---

## 1. Prior-Art Reconciliation ([HANDOFF-013] — read + reconcile FIRST)

Each cited artifact was read in full and is accounted for. Verification tags per [RES-013a]/[RES-023].

| Artifact | Status read | Disposition | Reason |
|----------|-------------|-------------|--------|
| `Memory.ContiguousProtocol.swift` | `[Verified: 2026-05-28]` | **EXTEND** | The contiguous-read surface (`span`) is the Memory-layer capability. Model positions it as the read terminal of the physical axis; its opt-in `where Self: Iterable` bridge is the canonical relate-don't-refine edge. No change to requirements. |
| `Storage.Protocol.swift` | `[Verified: 2026-05-28]` | **EXTEND** | `capacity` + `pointer(at:)` is the minimal physical-slot primitive. Model keeps it; notes the open `capacity`/`slotCapacity` conformer gap (buffer-dedup blocker) as a Storage-arc concern, not this model's. |
| `Buffer.Protocol.swift` | `[Verified: 2026-05-28]` | **EXTEND, not supersede** | The A′ shape (logical `count`+`isEmpty`; orthogonal-not-refined to `Iterable`; no `Storage` refinement; relaxed `Count: Carrier.Protocol<Cardinal>`) is *correct* and is the buffer-layer instance of this model. Model positions it; does **not** reshape its requirements. → the buffer arc is **not** forced to pause. |
| `Set.Protocol.swift` | `[Verified: 2026-05-28]` | **SUPERSEDE-with-reason** | The capability surface is *retained and elevated* (§4); the **fragmentation** of its algebra across three files / two packages and the **hard-coded `Set.Ordered` return type** are superseded. Its stale-comment reconciliation (already applied: cites the live docs, not the dead `iteration-architecture-set-probe.md`) is confirmed `[Verified: 2026-05-28]`. |
| `storage-generic-buffer-core.md` (v1.1.0) | `[Verified: 2026-05-28]` | **EXTEND** | Its two-lever model (generic-over-`Storage.Protocol` algorithm = cold→default; concrete-Base `Property.Inout` = hot) **is** the Storage/Buffer realization of this model's specialization boundary (§3). Its SIL evidence is a load-bearing input. |
| `unified-iteration-design.md` (v1.3.0, APPROVED) | `[Verified: 2026-05-28]` | **COORDINATE** | Iteration *shape* is supervisor-LOCKED and out of scope to reopen. This model relates the capability protocols *to* that substrate (relate-don't-refine, §5) and relates Set's algebra-enumeration to the planned `Iterable` floor (§4.3, §7). |
| `HANDOFF-buffer-protocol-v2.md` | `[Verified: 2026-05-28]` | **PARTIALLY STALE / COORDINATE** | Its "Do Not Touch `.worktree-sequencer-refactor`" gate is **dead** — see the `sequencer-refactor` row. Its A′ decisions are adopted. Its Open-Question #1 (dual-`Iterator` coexistence against current sequence-primitives) is **resolved** by the landed rename. |
| `sequencer-refactor` worktree (`.worktree-sequencer-refactor`, `d8fa6c1`) | `[Verified: 2026-05-28]` | **LANDED — reconcile** | The worktree **no longer exists**; `git worktree list` in swift-sequence-primitives shows only `main @ 309c1b9`. Commit `d8fa6c1` (the cited worktree HEAD) plus four more are merged into main, including `26c8cf3 A2 (rename): Sequence.Protocol → top-level Sequenceable`. **`Sequence.Protocol` no longer exists; it is now top-level `Sequenceable`.** The arc concluded; the v2 gate has lifted. |
| `storage-protocol-specialization` (Experiment) | `[Verified: 2026-05-28, CONFIRMED]` | **FOUNDATION** | Proves a generic-over-`some Storage.Protocol` algorithm specializes cross-module to 0 `witness_method` on `pointer(at:)`; residual witnesses only in the unused generic-fallback body. The pilot (§6) replicates this harness at the set layer. |
| `property-inout-specialization` (Experiment) | `[Verified: 2026-05-28, CONFIRMED]` | **FOUNDATION** | Proves concrete-Base `Property.Inout` accessors flatten to 0-witness *unconditionally*; protocol-Base do NOT (need `@inlinable` → the documented `~Copyable` borrow-init miscompile). This is the boundary line in §3. |
| `[DS-*]` ecosystem-data-structures | `[Verified: 2026-05-28]` | **GOVERNS** | The four-layer composition arch [DS-001] is the model's backbone; [DS-020] gates any new primitive (none proposed); [DS-021] ~Copyable pass-through holds. |

---

## 2. Question

How should the four capability protocols (`Memory.Contiguous.Protocol`, `Storage.Protocol`,
`Buffer.Protocol`, `Set.Protocol`) and the iteration substrate be related so that **(a)** a data
structure inherits the maximum derivable surface for free, **(b)** `Set.Protocol` becomes the genuine
set-layer capability surface (peer of `Buffer`/`Storage`, not a narrow algebra add-on), and **(c)** the
free inheritance is *bounded by the specialization boundary* — every inherited operation that is hot
must still monomorphize to **0 `witness_method`** in release, cross-module?

---

## 3. The Model

### 3.1 One composition stack of *minimal cores*, plus *orthogonal cross-cutting concerns*

The stack has **one HAS-A composition axis** of *minimal capability cores*, over which **orthogonal
cross-cutting concerns** are composed. Conflating a core with a cross-cutting concern is the root of the
present incoherence — most acutely, the set **algebra** was baked into `Set.Protocol`'s requirements
when it is in fact a third orthogonal concern, no more part of a set's identity than iteration is.

```
COMPOSITION STACK ([DS-001]) — a HAS-A containment chain; each layer's capability protocol is a MINIMAL core
declaring ONLY its layer's irreducible primitives:
   Memory  ◄─has─  Storage  ◄─has─  Buffer  ◄─has─  Collection-tier (Set, …)
   Memory.Contiguous.Protocol   Storage.Protocol     Buffer.Protocol   Set.Protocol
   (span)                       (pointer(at:)+capacity)  (count)        (contains + count)

ORTHOGONAL CROSS-CUTTING CONCERNS — composed OVER the cores via `where Self: Core [& OtherConcern]`,
NEVER baked into a core's requirements:
   • Iteration — Iterable (multipass/borrow) · Sequenceable (single-pass) · Iterator.Borrow (~Copyable pull)   [LOCKED]
   • Algebra   — set algebra in `swift-set-algebra-primitives` (bridges the set core ↔ the
                 `swift-algebra-*-primitives` structure family); composed `where Self: Set.Protocol & Iterable`
   • (future)  — other derived-operation families attach the same way over their cores
```

A buffer **has-a** storage; a set **has-a** buffer; none **is-a** the layer below. **Neither iteration
nor algebra is a layer or a core requirement** — both are orthogonal capabilities composed over the
minimal cores. This *generalizes* the ecosystem's load-bearing stance (stated verbatim in `Iterable.swift`
/ `Sequenceable.swift`: *"iteration capabilities are orthogonal siblings, not a refinement chain"*) from
iteration to **every derived-operation family**: a capability core declares only its irreducible
primitives; *every* derived family — iteration, algebra, … — attaches orthogonally. The pilot proves the
attachment is free at the specialization boundary even when a family composes over *two* protocols (§6.2).

### 3.2 The capability-protocol normal form

Every capability **core** is a pair ⟨**REQUIRES** : the minimal irreducible primitives of its layer's
concern⟩ → ⟨**PROVIDES** : only the derivations expressible from *its own* requirements (edge kind D —
e.g. `isEmpty` from `count`)⟩. **Larger derived families that need another concern (iteration, algebra)
are NOT part of a core's PROVIDES** — they attach orthogonally (edge kind C). "Free inheritance" for a
conformer is then the union of every orthogonal family whose `where`-clause it satisfies. The three
**edge kinds**:

| Edge kind | Meaning | When it applies | Mechanism |
|-----------|---------|-----------------|-----------|
| **(R) Refine** (IS-A) | the sub-protocol genuinely *is* the super | only *within* an axis where identity holds | `protocol P: Q` |
| **(C) Compose-default** (HAS-A / provides-when-also-conforms) | a default fires when a conformer *also* conforms another protocol | *across* the two axes (physical↔logical, capability↔iteration) | `extension P where Self: Q { … }` |
| **(D) Provides-as-default** (intra-protocol derivation) | derive ops from the protocol's own requirements | within one protocol | `extension P { … }` |

**Decision rule for (R) vs (C):** *refine only when the type's identity is the supertype's concern;
compose otherwise.* `Collection.Protocol: Iterable` is a legitimate refinement (a collection **is**
iteration-with-indices). `Buffer.Protocol`, `Storage.Protocol`, `Memory.Contiguous.Protocol` and
`Set.Protocol` do **not** refine `Iterable` (their identity is occupancy / slot-access / contiguous-read
/ membership — not iteration); they relate to it by (C).

### 3.3 The specialization boundary — the HARD constraint

Free inheritance is bounded by **0-`witness_method` specialization**. The boundary, proven by the two
cited experiments, draws the REQUIRES/PROVIDES line:

> **Boundary line.** A derived operation is safe **as a protocol-extension default** iff, when the
> conformer is concrete, the optimizer monomorphizes it to **0 `witness_method`** in release across a
> module boundary. The experiments establish:
> - **Generic-over-`some P` code (edge kinds R/C/D) specializes to 0-witness** when the conformer is
>   statically known. Residual `witness_method` appears *only* in the unused generic-fallback body,
>   which the call site never references. → **derived/cold ops as protocol defaults are SAFE.**
> - **Protocol-Base `Property.Inout` accessors do NOT specialize without `@inlinable`** — and
>   `@inlinable` on the `~Copyable` `Property.Inout` borrow-init path is the documented release
>   miscompile (`Property.Inout.swift`; swiftlang/swift#81624). → **hot mutating ops MUST stay
>   concrete-Base** (`Property.Inout`/`Property.View` on the concrete leaf, or a concrete `mutating
>   func`), NOT dispatched through the protocol.

**Corollary (the require/provide split):** put on the protocol's REQUIRES the irreducible primitive(s)
plus any hot op that must be a concrete-Base witness; put on PROVIDES everything cold/derived. The hot
read primitive (`contains`, `pointer(at:)`, `span`) is a *requirement* (its witness is concrete on the
leaf, so direct calls never touch the protocol; generic calls specialize). The hot *mutating* ops
(`insert`/`remove`/`append`) are NOT protocol-dispatched ops — they live as concrete-Base accessors per
the property-primitives pattern ([PRP-008], [PRP-001]).

### 3.4 Per-protocol specification (acceptance criterion #2)

For each protocol: **R**equires / **P**rovides-as-default / **C**omposition / **inherits-for-free**.

#### Memory.Contiguous.Protocol — physical contiguous read
- **Requires:** `span: Span<Element>` (the one primitive) + `withUnsafeBufferPointer` (C-interop escape). `Element: ~Copyable`.
- **Provides (D):** positional read, `count == span.count`, bounds — all derivable from `span` (today minimal; expandable).
- **Composition (C):** `extension Memory.ContiguousProtocol where Self: Iterable, Element: Copyable { makeIterator() → Iterator.Chunk }` — the canonical relate-don't-refine bridge (already shipped; retroactive refinement is *impossible* cross-package and would force an iterator dep onto memory — [MOD-035]).
- **Inherits-for-free:** a contiguous type declaring `: Iterable` gets the bulk span iterator + the `Iterable` terminal suite, writing only `span`.

#### Storage.Protocol — physical slot access
- **Requires:** `capacity: Index<Element>.Count`, `@unsafe pointer(at: Index<Element>)`. `Element: ~Copyable`. Single-region (`Storage.Split` is multi-region → does not conform).
- **Provides (D):** the generic-over-`some Storage.Protocol` element algorithm (fill/move/sum-shape) — proven 0-witness (`storage-protocol-specialization`). **New (recommended):** a `where Self: …` default supplying `Memory.Contiguous.Protocol.span` from `pointer(at: .zero)` + `capacity` for contiguous single-region storage — a free Memory-read surface (composition within the physical axis).
- **Composition (C):** **does NOT refine `Memory.Contiguous.Protocol`** by default (a slab/arena is slot-addressed but not contiguous) — the span default is gated to contiguous disciplines.
- **Inherits-for-free:** any single-region storage gets the generic element algorithm; contiguous storage additionally gets `span`.

#### Buffer.Protocol — logical occupancy *(EXTEND; keep A′)*
- **Requires:** `count: Count` where `Count: Carrier.Protocol<Cardinal> = Index<Element>.Count`. `Element: ~Copyable`, `Self: ~Copyable & ~Escapable`.
- **Provides (D):** `isEmpty` (`count == .zero`, constrained `where Count == Index<Element>.Count`).
- **Composition (C):** `extension __BufferProtocol where Self: Iterable & ~Copyable { … }` for count+iteration logic; `span` stays on `Memory.Contiguous.Protocol` for contiguous variants. **Does NOT refine `Storage.Protocol`** (has-a) nor `Iterable` (orthogonal; refining would couple header-knowable `count` to iterability).
- **Inherits-for-free:** every discipline writes `count`; gets `isEmpty` free; gains iteration by *separately* conforming `Iterable` (via `Iterator.Borrow` for `~Copyable`).

#### Set.Protocol — the set membership *core* *(SUPERSEDE-with-reason; the elevation — §4)*
- **Requires (the irreducible set core — "what makes a set"):** `contains(_ : borrowing Element) -> Bool` (O(1) membership — the defining set query) + `count: Index<Element>.Count` (O(1) cardinality). `Element: Hash.Protocol & ~Copyable`. **Nothing else** — enumeration and algebra are orthogonal concerns (below), not core requirements.
- **Provides (D):** only `isEmpty` (`count == .zero`) — the one derivation needing nothing but the core's own requirements.
- **Composition (C) — enumeration:** orthogonal sibling of `Iterable`/`Sequenceable`; does NOT refine them (set identity is membership, not iteration). A set *also* conforms `Iterable` (vending `Iterator.Borrow` for `~Copyable`; for pull-style + the `Swift.Sequence` bridge).
- **Composition (C) — algebra (the THIRD orthogonal concern):** the **entire** set algebra is composed over the core + enumeration, in its own module — predicates (`isDisjoint`/`isSubset`/`isSuperset`/`isStrictSubset`/`isStrictSuperset`/`isEqual`) returning `Bool` via `extension Set.Protocol where Self: Iterable`, and constructive ops (`union`/`intersection`/`subtracting`/`symmetricDifference`) returning **`Self`** via `extension BuildableSet where Self: Iterable`. NOT on the core's requirements.
- **Inherits-for-free:** a set variant writes only `contains` + `count` (core) + the `Iterable` enumeration witness (+ `init`/`insert` for `BuildableSet`); inherits the **complete** algebra. Validated in §6 — 0-witness even across the two-protocol composition.

---

## 4. The Set.Protocol redesign (the elevation)

### 4.1 What is "narrow" today, precisely

1. **Fragmented algebra across three locations, two packages.** Predicates (`isDisjoint`/`isSubset`/…)
   live with the protocol in `swift-set-primitives/Set.Protocol+defaults.swift` (correct — all
   conformers inherit). But the **constructive** ops exist **twice downstream**: as protocol defaults
   that hard-return `Set<Element>.Ordered` (`swift-set-ordered-primitives/Set.Protocol+algebra.swift`),
   *and* as a separate concrete `.algebra` accessor namespace
   (`Set.Ordered.Algebra` in `Set.Ordered.Algebra.swift`). Two implementations of `union`/`intersection`.
2. **Hard-coded result type.** The constructive defaults return `Set<Element>.Ordered`, not `Self` —
   forcing them into the set-ordered package (set-primitives cannot name `Set.Ordered`) and making them
   non-general for other set families.
3. **No applied specialization boundary.** Nothing states which ops are hot (concrete-Base) vs derived
   (protocol-default).
4. **Muddled iteration relationship.** The protocol declares `forEach`, while a reconciled comment says
   "membership only; iteration on `Iterable`."
5. **Algebra baked into the core (the root issue).** The protocol's *identity* (membership) is conflated
   with a *derived-operation family* (algebra). Algebra is a third orthogonal concern — no more part of a
   set's identity than iteration is — and should be decomposed out and composed over the core, not listed
   among its requirements/provides.

### 4.2 The redesign — minimal core + algebra decomposed out

`Set.Protocol` becomes the genuine set-layer **core** in the §3.2 normal form, and the algebra is lifted
out as a third orthogonal concern:

- **Minimal core requires:** `contains` + `count` only — membership + cardinality, "what makes a set."
  Enumeration is the orthogonal iteration concern (`Iterable`); algebra is the orthogonal algebra concern.
  Neither is a core requirement.
- **Algebra as ONE orthogonal concern, in a dedicated BRIDGE package.** All set algebra — predicates AND
  constructive — is composed `where Self: Set.Protocol & Iterable` (predicates) / `where Self:
  BuildableSet & Iterable` (constructive), in a dedicated **`swift-set-algebra-primitives`** package
  (principal, 2026-05-28) that **bridges `swift-set-primitives` (the membership core) with the
  `swift-algebra-*-primitives` structure family** — grounding the set operations in *general algebra*
  rather than re-deriving them ad hoc: `union` = join and `intersection` = meet of a **bounded lattice**
  (`swift-algebra-semilattice-primitives`); ∪/∩/complement = a **Boolean algebra**; `⊆` = the lattice
  partial order; the idempotent/commutative/associative/absorption **laws** via
  `swift-algebra-law-primitives`. This collapses today's **three-location fragmentation** — the predicate
  defaults (set-primitives), the `Set.Ordered`-returning constructive defaults (set-ordered-primitives),
  and the duplicate `.algebra` accessor (set-ordered-primitives) — into the one bridge package; the
  duplicate `Set.Protocol+algebra.swift` and `Set.Ordered.Algebra` are **subsumed and deleted**.
- **Substrate RESOLVED (supervisor + principal, 2026-05-28).** The structures the bridge witnesses against
  are authorized as real packages, so `∪`/`∩`/`∁` map onto packaged algebra, not prose: a **bounded-lattice
  package** `swift-algebra-lattice` (the existing `swift-algebra-semilattice-primitives` join+meet + the
  **absorption** law ⇒ a bounded lattice) supplies `union = join` / `intersection = meet`; a
  **Boolean-algebra package** (built on `Swift.Bool` + the algebra family; name per [PKG-NAME-*], the
  family-consistent form being `swift-algebra-boolean-primitives`) supplies `complement` (and `⊆` as the
  lattice partial order). `swift-set-algebra-primitives` then *witnesses* the powerset Boolean algebra over
  the `Set.Protocol` core. (Exact package names finalized by the principal per [PKG-NAME-*] at execution.)
- **Result-type fix.** Constructive ops return **`Self`** (on the `BuildableSet` refinement: `init` +
  `insert`), not the hard-coded `Set<Element>.Ordered` — so they are general, total only on growable sets
  (why they live on `BuildableSet`), and need no downstream home. Bounded variants (`Fixed`/`Static`)
  conform `Set.Protocol` (+ `Iterable`) and inherit the predicates, not `BuildableSet`; a growable result
  for them comes from the canonical growable type at their layer, with overflow explicit rather than
  hidden behind a silent `Set.Ordered` return.
- **Specialization boundary applied:** `contains` (hot read) is a core requirement (concrete witness);
  `insert`/`remove` (hot mutating) are concrete-Base `Property.View` accessors per [PRP-008] — **not**
  protocol ops; the algebra is all orthogonal-composed protocol-extension default (proven 0-witness even
  across the two-protocol composition, §6).

### 4.3 Enumeration comes from the iteration concern (COORDINATE — a narrow dependency)

With algebra decomposed out, `Set.Protocol` declares **no** enumeration of its own; the algebra obtains
its `(borrowing Element)` traversal from the iteration concern it composes over (`extension Set.Protocol
where Self: Iterable`). The dependency on the iteration arc is **narrow**:

| Algebra slice | Enumeration shape needed | Works over *current* `Iterable`? |
|---|---|---|
| Constructive (`union`/`intersection`/…) — always `Element: Copyable` | `(borrowing Element)`; a Copyable iterator gives `Iterator.Element == Element` | **Yes** |
| Predicates on `Copyable` elements | same | **Yes** |
| Predicates on `~Copyable` elements | `(borrowing Element)` floor | **Gated** on the LOCKED §2.1 `Iterable` floor, or composes with `Ownership.Borrow` unwrapping |

So only the **`~Copyable`-element predicate** slice is gated on the iteration arc landing its
`(borrowing Element)` `forEach` **floor** (`unified-iteration-design.md` §2.1, AUTHORIZED) — a
coordination point, not a substrate change (HANDOFF MUST NOT). The model **holds the line** that
enumeration is the iteration concern's job: it does **not** re-bake a `forEach` requirement onto the set
core (that would collide with `Iterable.forEach` for Copyable sets and re-introduce the very conflation
this redesign removes). The pilot models the `(borrowing Element)` floor and proves the full algebra
composition specializes (§6).

---

## 5. The iteration relationship (relate-don't-refine)

`Set.Protocol` (and `Buffer`/`Storage`/`Memory.Contiguous`) relate to the iteration substrate by
**edge kind (C)** — orthogonal sibling, not refinement:

- The set **algebra is generic over `Set.Protocol` alone** — it never names `Iterable`. Iteration is
  genuinely orthogonal to the set capability. (Validated: §6's algebra defaults compile and specialize
  with no `Iterable` in scope.)
- A set **also** conforms `Iterable` (for pull-style + the `Swift.Sequence` bridge) and `Sequenceable`
  (for lazy/consuming pipelines). The dual `Iterable`+`Sequenceable` conformance splits the shared
  `associatedtype Iterator` with `@_implements` — an **iteration-substrate** concern that already
  exists and that this model does **not** touch. `Set.Protocol` introduces **no** new associated-type
  collision (its `Element` does not collide with `Iterable`'s `Iterator`); validated by the
  `DualConformer` compile-proof in §6.
- For `~Copyable` elements, the set's `Iterable` conformance vends an `Iterator.Borrow.Protocol`
  iterator (`next() -> Ownership.Borrow<Element>?`) — the proven `~Copyable` pull-style. The set
  algebra does not depend on this; it uses the clean borrow-`forEach`.

**Why not refine `Iterable`?** Refinement would assert *Set IS-A Iterable*. Per §3.2's decision rule,
refine only when identity is iteration-centric. A set's identity is **membership**; iteration is a
strong secondary capability. `Collection.Protocol` refines `Iterable` (indexed-traversal *is*
iteration); `Set.Protocol` does not — consistent with `Buffer.Protocol`'s A′ refusal and the ecosystem
orthogonality stance. (`Set.Protocol: Iterable` was considered and rejected — see §8 alternative.)

---

## 6. Set.Ordered pilot (acceptance criterion #3)

A `/tmp` prototype (`/tmp/set-capability-pilot`) replicates the proven `storage-protocol-specialization`
harness at the set layer, in the **corrected decomposition**: a `SetCore` module (`SetProtocol` =
`{contains, count}` core; `BuildableSet` refinement; a reduced `Iterating`≈`Iterable` enumeration
concern; the predicate + constructive algebra composed **`where Self: SetProtocol & Iterating`** /
**`where Self: BuildableSet & Iterating`**; the concrete `OrderedSet` leaf; a `~Copyable`-element
coverage proof) and a separate `consumer` module ([EXP-017] cross-module). Faithful reductions
([EXP-004]/[EXP-020]): `Element == Int` for the receipt to isolate protocol-specialization from
element-genericity (as the cited experiments did); `Hashing` stands in for `Hash.Protocol`; `Iterating`
models `Iterable`'s §2.1-LOCKED `(borrowing Element)` floor; `OrderedSet` = contiguous buffer +
open-addressed hash (the `Set.Ordered` shape: `Buffer.Linear` + `Hash.Table`). It proves the **compiler
capability**, not the production refactor (which needs an in-package SIL recheck per [EXP-020]).

### 6.1 Inherits-vs-writes table

**Pilot `OrderedSet` (what the conformer authors vs inherits):**

| Member | Writes / Inherits | Notes |
|--------|-------------------|-------|
| `init()` / `init(reserving:)` | **writes** | `BuildableSet.init` |
| `count` | **writes** (1-line) | **SetProtocol core**; witnessed by `_count` (real: `buffer.count`) |
| `contains` | **writes** | **SetProtocol core**; the O(1) hash probe — the irreducible set primitive (HOT, concrete-Base) |
| `forEach` | **writes** (1-line walk) | **`Iterating` (enumeration concern)** — NOT a set-core requirement; buffer walk `(borrowing Element)` |
| `insert` | **writes** | `BuildableSet`; HOT mutating, concrete-Base |
| `: SetProtocol` / `: Iterating` / `: BuildableSet` | **writes** (3 one-liners) | conformance declarations |
| `isEmpty` | **inherits** | core (D) — `count == 0` |
| `isDisjoint`, `isSubset`, `isSuperset`, `isStrictSubset`, `isEqual` | **inherits** | algebra (C) `where Self: SetProtocol & Iterating` — 0 lines |
| `union`, `intersection`, `subtracting` | **inherits** | algebra (C) `where Self: BuildableSet & Iterating`, returns `Self` — 0 lines |

→ **5 members + 3 conformance lines written; 9 algebra operations inherited for free** (composed over the
membership core + the enumeration concern), all specializing to 0-witness (§6.2).

**Real `Set.Ordered` under the model (delta from today):**

| Today | Under the model |
|-------|-----------------|
| writes `count`, `isEmpty`, `contains`, `forEach`, `insert`, … | writes `count` + `contains` (core), `forEach` (its `Iterable` enumeration witness), `insert`/`remove` (concrete-Base); **`isEmpty` becomes inherited** |
| predicate defaults on `Set.Protocol` (set-primitives, unconditional) | **move** to the algebra module, composed `where Self: Iterable` (they need enumeration); set-primitives' `Set.Protocol` keeps only the `{contains, count}` core + `isEmpty` |
| `Set.Protocol+algebra.swift` (constructive → `Set.Ordered`) | **deleted** — subsumed by the algebra module's `BuildableSet` constructive defaults returning `Self` |
| `Set.Ordered.Algebra` / `.algebra` accessor + `Symmetric` + `form` | **deleted/folded** — subsumed by the inherited ops (a thin `.algebra` alias MAY remain as call-site sugar — a leaf choice) |

### 6.2 SIL receipt (the HARD constraint — release, cross-module)

Method: `swift-institute/Experiments/storage-protocol-specialization` ([EXP-017]). Two modules; `-O`;
cross-module SIL of the consumer importing the built `SetCore`. **Receipt:**
`/tmp/set-capability-pilot/Outputs/{consumer.sil, whole.sil, SIL-RECEIPT.md, run-release.txt}`.

| Build | Total `witness_method` | Location of any residual |
|-------|------------------------|--------------------------|
| Cross-module `consumer.sil` (`-O`) | **2** | **BOTH inside the *unused* generic `probe<S>` fallback** (`$s4main5probe…SetProtocolRzRi_zlF`) — never `function_ref`/`apply`-ed; `main` calls the inlined/specialized path |
| Whole-program `whole.sil` (`-O`) | **0** | none |

**Specialized hot-path symbols — each 0 `witness_method`:**
- `main` (hosts the `isDisjoint` ×10 000 + `contains`-probe ×10 000 hot loops, fully inlined) — **0**
- `OrderedSet.insert` specialized (`…6insertyyxnFSi_Tg5`) — **0**
- `SetProtocol.isSubset` / `isEqual` specialized for `OrderedSet<Int>` (`…Tg5`) — **0**
- `BuildableSet.union` / `intersection` specialized for `OrderedSet<Int>` (`…Tg5`) — **0**

`main` applies only `(Int) -> OrderedSet<Int>`, `(OrderedSet<Int>, OrderedSet<Int>) -> OrderedSet<Int>`,
`(OrderedSet<Int>, OrderedSet<Int>) -> Bool`, and print machinery — **no `witness_method`, no
generic-`probe` apply.** This is structurally identical to the proven storage experiment (6 residual
witnesses, all in the unused generic fallback). **Verdict: PASS — the inherited set algebra + the
membership primitive specialize to 0-witness on the hot path. The model is "perfect" in the
specialization sense: it specializes.**

**Finding (load-bearing for the orthogonal decomposition):** the algebra now composes over **two**
protocols (`Set.Protocol & Iterating`), yet the specialized symbols are still witness-free.
**Orthogonal multi-protocol composition (`where Self: P & Q`) costs nothing at the specialization
boundary** — the same 0-witness bar as the single-protocol storage experiment. Decomposing the algebra
out as a third orthogonal concern is therefore *free*: it improves coherence at zero specialization cost.

**Runtime (release, cross-module) — correct:** `isDisjoint-acc: 20000`, `contains-hits: 10000`,
`union-count: 1536`, `intersection-count: 512`, `a⊆union: true`, `a==a: true`, `mo.isEmpty: true`,
`mo.isDisjoint: true` (the `~Copyable`-element `MoveOnlySet` inherits the orthogonal-composed predicate
algebra — `~Copyable` coverage, no Copyable forcing, no `@_implements`).

### 6.3 ~Copyable coverage + orthogonal coexistence (compile-proofs)
- `MoveOnlySet` (`Element == Token`, a `~Copyable` element; fully `~Copyable` container) conforms
  **both** `SetProtocol` (membership core) **and** `Iterating` (enumeration concern), and thereby
  **inherits the orthogonal-composed predicate algebra** — no Copyable forcing. (Constructive algebra is
  Copyable-gated, matching reality, so it does not apply.) This simultaneously proves the dual
  membership+enumeration conformance needs **no `@_implements`**: `SetProtocol.Element` and
  `Iterating.Element` are the same associated-type name and unify cleanly (unlike the
  `Iterable`+`Sequenceable` dual-`Iterator` case). Confirms §5: the set core introduces no new
  associated-type collision.

---

## 7. In-flight-arc reconciliation (acceptance criterion #4)

| Arc | State (verified 2026-05-28) | Disposition | Action required of the principal |
|-----|------------------------------|-------------|----------------------------------|
| **Recently-landed `Buffer.Protocol`** (v2/A′, buffer-primitives main `126e99a`) | landed; all variants conformed | **EXTEND, not supersede** | None to the protocol. The model adopts A′ wholesale and positions it. **No pause.** |
| **buffer-dedup spike** (`spike/buffer-storage-dedup`) | Lever-2 done + SIL-validated; Lever-1 blocked on a `swift-storage-primitives` `capacity`/`slotCapacity` change | **EXTEND / COORDINATE** | None forced by this model. The model's "Storage.Protocol provides `span` for contiguous storage" (§3.4) is a *complementary* Storage-arc item; sequence it after the Lever-1 unblock. Single-writer on the buffer packages still holds. |
| **iteration arc / set-ordered reference rework** (`unified-iteration-design.md` v1.3.0, AUTHORIZED) | reference rework authorized; fan-out gated | **COORDINATE — sequencing decision needed** | The Set.Protocol redesign (§4) and the reference rework both touch `Set.Ordered`/`Set.Protocol`. The redesign is **capability-surface** work; the rework is **iteration** work. They converge at `forEach` (§4.3). **Recommend:** land the Set.Protocol redesign as a discrete step that the reference rework then builds on (the rework already plans `forEach → Iterable floor`; the redesign supplies the unified algebra + `BuildableSet`). The principal sequences which lands first. **Possible pause** of the reference rework's `Set.Protocol`-touching steps until the redesign is reviewed. |
| **`sequencer-refactor`** (`.worktree-sequencer-refactor`, `d8fa6c1`) | **LANDED** — worktree gone; merged into sequence-primitives main `309c1b9`; `Sequence.Protocol` → top-level `Sequenceable` | **RECONCILE — gate lifted** | None. The v2 handoff's "Do Not Touch" is dead; references to `Sequence.Protocol` must read `Sequenceable`. The dual-`Iterator` coexistence question (v2 OQ#1) is resolved against current sequence-primitives. |

**Supersession flag (per the `ask:` ground rule):** the only supersession is **`Set.Protocol`'s algebra
fragmentation + hard-coded return type** (a within-package reshape of a landed protocol's *defaults*,
not its core requirements). `Buffer.Protocol` is **not** superseded. The one arc that may need a
**pause** is the iteration arc's `Set.Protocol`-touching steps, pending the principal's sequencing.

---

## 8. Decisions — RESOLVED (supervisor + principal, 2026-05-28)

All four were adjudicated at approval. Resolutions are recorded here; **execution is sequenced by the
principal and has not begun.**

1. **Enumeration dependency (§4.3) — APPROVED as recommended.** Land the algebra's un-gated slices
   (constructive + `Copyable`-element predicates) over *current* `Iterable`; gate only the
   **`~Copyable`-element predicate** slice on the iteration arc's `(borrowing Element)` floor (§2.1).
2. **Sequencing vs the set-ordered reference rework (§7) — RESOLVED.** The substrate condition behind it
   is cleared (see #2-substrate below); the principal sequences whether the `Set.Protocol` reduction +
   `swift-set-algebra-primitives` lands before, with, or after the set-ordered rework. (My recommendation
   stands: discrete redesign step first.)
   - **#2 substrate — RESOLVED by principal authorization:** create a **bounded-lattice package**
     `swift-algebra-lattice` (existing `swift-algebra-semilattice-primitives` + the **absorption** law) and
     a **Boolean-algebra package** (on `Swift.Bool` + the algebra family; name per [PKG-NAME-*]). The
     `swift-set-algebra-primitives` bridge witnesses `∪`=join / `∩`=meet / `∁`=complement over these real
     structures (§4.2). These packages do not yet exist; **creating them is execution, sequenced by the
     principal — not begun here.**
3. **`BuildableSet` naming/placement — APPROVED as recommended.** Hoisted `__SetBuildableProtocol` +
   `Set.Buildable.\`Protocol\`` alias in a `Set Buildable Protocol Primitives` target, mirroring
   `Buffer Protocol Primitives` ([API-NAME-001]/[MOD-031]).
4. **`.algebra` accessor fate — APPROVED as recommended.** Delete; the inherited ops are the surface.

**Rejected alternative — `Set.Protocol: Iterable` (refinement).** Viable for `~Copyable` (`Iterable` is
`makeIterator`-only; a `~Copyable` set vends an `Iterator.Borrow` iterator). **Rejected** because (a) it
asserts an identity (Set IS-A Iterable) the ecosystem orthogonality stance denies for non-iteration-centric
primitives; (b) it would fold an iteration requirement (`makeIterator`) into the set *core*, conflating
membership identity with iteration — the exact bake-in this redesign removes for algebra; and (c) it
couples the set core to substrate mechanics the model must not reopen. Compose-don't-refine (§5) achieves the
free inheritance without these costs.

---

## 9. Prior art (cross-language)

- **Rust:** `HashSet`/`BTreeSet` membership is the type's identity; set algebra (`union`, `intersection`,
  `difference`) are methods returning *iterators* (lazy), with `FromIterator` materializing the result
  type — the caller chooses the result type, a generalization of this model's `Self`-returning
  `BuildableSet`. Rust keeps `Iterator` orthogonal to the collection (the `IntoIterator` split) —
  mirrors the relate-don't-refine stance. Constructive ops are not on a "Set trait"; they are inherent
  methods — Rust has no set-capability trait, so the institute's `Set.Protocol` is a *richer* surface.
- **C++ STL:** `std::set`/`unordered_set` expose `find`/`count` (membership) as members; set algebra is
  *free functions* (`std::set_union`, `std::set_intersection`) over iterator ranges, decoupled from the
  container — the extreme of orthogonality (algebra not on the type at all). The institute model keeps
  the algebra *inherited on the protocol* (better discoverability + typed) while preserving the
  orthogonality of iteration.
- **Swift stdlib:** `SetAlgebra` is the precedent — a protocol whose requirements (`contains`,
  `insert`, `union`, `intersection`, …) provide a large derived surface. But `SetAlgebra: Equatable`,
  requires `Copyable` elements, and bakes the result type as `Self` for *all* ops (so `OptionSet` and
  growable sets share one protocol awkwardly). The institute model improves on it: `~Copyable` elements,
  the predicate/constructive split (predicates on the base, constructive on the growable `BuildableSet`
  refinement), and the specialization guarantee. `Sequence`/`Collection` orthogonality in stdlib
  (Collection refines Sequence; Set is a Collection) is the direct analogue of `Collection.Protocol:
  Iterable` and the Set-is-not-a-refinement-of-iteration stance.
- **Haskell `Data.Set`:** purely functional; `member` (membership) + `union`/`intersection` returning a
  new `Set`; `Foldable` (iteration) is a separate orthogonal class — again relate-don't-refine.
- **Order/lattice theory (Birkhoff; Stone representation):** the formal grounding for the
  `swift-set-algebra-primitives` bridge — the powerset of any universe is a **Boolean algebra**, hence a
  **bounded distributive lattice** under (∪ = join, ∩ = meet, ∅/universe = bottom/top, complement), with
  `⊆` the lattice partial order. The set algebra is therefore not bespoke: it is *general* lattice/Boolean
  algebra instantiated over a membership core. No surveyed *language* expresses set ops this way (they
  hand-roll them); the institute's algebra-structure ecosystem (`swift-algebra-semilattice-primitives`
  et al.) makes the grounding explicit — a strictly stronger, more reusable framing.

**Contextualization ([RES-021]):** every surveyed system separates *membership identity* from
*iteration*, and most separate *constructive algebra* from the container (free functions or
`FromIterator`). The institute model's distinctive choice — a typed `Set.Protocol` carrying the algebra
as specializing defaults, split predicate/constructive across a growable refinement — is *more*
structured than any surveyed system while preserving their universal orthogonality of iteration. No
gap; a deliberate, stronger design.

---

## 10. Empirical validation (Cognitive Dimensions, [RES-025])

- **Role-expressiveness:** the §3.2 normal form makes each protocol's role legible (one concern, minimal
  requires, maximal provides); the three edge kinds name the relationships that were previously implicit.
- **Consistency:** all four protocols share the same shape; `Set.Protocol` stops being the odd one out.
- **Viscosity:** a new set variant writes ~3 requirements + `init`/`insert` and inherits ~10 ops — low
  resistance to adding variants; removing the algebra fragmentation removes a 3-location edit hazard.
- **Error-proneness:** the result-type fix (`Self` on `BuildableSet`) removes the silent
  `Set.Ordered`-overflow surprise on bounded variants; the specialization boundary removes the
  protocol-Base `@inlinable` miscompile foot-gun.
- **Abstraction gradient:** unchanged from [DS-001] — consumers use the leaf; the protocols are for
  generic code and inheritance, validated to specialize away.

---

## 11. Outcome

**Status: RECOMMENDATION.** The theoretically-optimal cross-layer model is: each layer exposes one
**minimal capability core** in the ⟨minimal requires⟩→⟨core-only derivations⟩ normal form (§3.2); **every
derived-operation family — iteration AND algebra — is an orthogonal concern composed over the cores via
`where Self: Core [& OtherConcern]`, never baked into a core** (§3.1); protocols relate by **refine
within an axis only when identity holds, compose across axes** (§3.2 decision rule); the require/provide
line is drawn at the **specialization boundary** (§3.3, derived→defaults, hot-mutating→concrete-Base);
and **`Set.Protocol` is reduced to its `{contains, count}` core** with the algebra decomposed out as a
third orthogonal concern — unified in one module, `Self`-returning via the `BuildableSet` refinement (§4).
The model **extends** the landed `Buffer.Protocol` and the Storage/Buffer two-lever model, **coordinates**
with the locked iteration substrate (relate-don't-refine; a narrow `~Copyable`-predicate enumeration
dependency), and **supersedes** only `Set.Protocol`'s algebra bake-in + fragmentation. The Set.Ordered
pilot proves the inherited algebra + membership specialize to **0 `witness_method`** on the hot path,
release, cross-module — *even across the two-protocol orthogonal composition* (§6).

**Recommended sequencing** (APPROVED by the supervisor 2026-05-28; §8 decisions resolved; **execution
sequenced by the principal — not begun**):
1. Reduce `Set.Protocol` to the `{contains, count}` core in set-primitives, and stand up the
   **`swift-set-algebra-primitives`** bridge package — predicates `where Self: Set.Protocol & Iterable`,
   constructive `where Self: BuildableSet & Iterable` returning `Self`, grounded in the
   `swift-algebra-*-primitives` structures (semilattice/lattice/Boolean-algebra + laws); delete the
   three-location fragmentation. SIL-re-gate the real `Set.Ordered`.
2. Land the un-gated algebra slices (constructive + `Copyable`-element predicates) now; gate the
   `~Copyable`-element predicate slice on the iteration arc's `(borrowing Element)` floor (§4.3).
3. Apply the same normal form (minimal core + orthogonal concerns) as the audit lens for
   `Dictionary.Protocol` and future collection-tier capability surfaces (out of scope here; the model
   generalizes — algebra is to Set what relational/index families are to other cores).

**APPROVED by the supervisor 2026-05-28 — the §3 normal form + the `Set.Protocol` elevation are confirmed
as the ×16 fan-out template foundation; §8 decisions resolved (incl. the new `swift-algebra-lattice` +
Boolean-algebra packages authorized for the bridge). The research phase concludes here. No production code
is landed; no live package or worktree edited; execution is sequenced by the principal and has not begun.**

---

## References

- Protocols: `swift-memory-primitives/.../Memory.ContiguousProtocol.swift`;
  `swift-storage-primitives/.../Storage.Protocol.swift`;
  `swift-buffer-primitives/.../Buffer.Protocol.swift`;
  `swift-set-primitives/.../Set.Protocol.swift`, `.../Set.Protocol+defaults.swift`.
- Set.Ordered: `swift-set-ordered-primitives/.../Set.Ordered.swift`, `Set.Ordered ~Copyable.swift`,
  `Set.Ordered+Set.Protocol.swift`, `Set.Protocol+algebra.swift`, `Set.Ordered.Algebra.swift`.
- Iteration substrate (LOCKED; not reopened): `swift-iterator-primitives/.../Iterable.swift`,
  `Iterable+ForEach.swift`, `Iterable+Contains.swift`;
  `swift-iterator-borrow-primitives/.../Iterator.Borrow.Protocol.swift`;
  `swift-sequence-primitives/.../Sequenceable.swift` (post-`sequencer-refactor`, main `309c1b9`).
- Algebra bridge target (the third concern's home): planned `swift-set-algebra-primitives`, bridging
  `swift-set-primitives` with the `swift-algebra-*-primitives` family verified on disk
  (`swift-algebra-semilattice-primitives`, `-monoid-`, `-semigroup-`, `-magma-`, `-group-`, `-ring-`,
  `-semiring-`, `-field-`, `-law-primitives`, root `swift-algebra-primitives`) `[Verified: 2026-05-28]`.
- Research: `swift-buffer-primitives/Research/storage-generic-buffer-core.md` (v1.1.0);
  `swift-institute/Research/unified-iteration-design.md` (v1.3.0).
- Handoffs: `HANDOFF-buffer-protocol-v2.md`; `HANDOFF-capability-protocol-model.md` (this investigation).
- Experiments: `swift-institute/Experiments/storage-protocol-specialization` (CONFIRMED);
  `swift-property-primitives/Experiments/property-inout-specialization` (CONFIRMED);
  pilot `/tmp/set-capability-pilot` (this investigation — PASS, §6).
- Prior art: Rust `std::collections::{HashSet,BTreeSet}`; C++ `std::set`/`<algorithm>` set ops; Swift
  stdlib `SetAlgebra`/`Collection`; Haskell `Data.Set`/`Foldable`.
- Skills: [DS-001], [DS-020], [DS-021]; [RES-018], [RES-020]–[RES-029]; [SUPER-042];
  [PRP-001], [PRP-008]; [MOD-031], [MOD-035]; [API-NAME-001]; [IMPL-078].
