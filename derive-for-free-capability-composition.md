# Derive-for-Free via Capability Composition

<!--
---
version: 1.1.0
last_updated: 2026-06-02
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
type: investigation/architecture
generalizes: cross-layer-capability-protocol-model.md (v1.3.0)
toolchain_of_record: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), arm64-apple-macosx26.0
changelog:
  - "1.1.0 (2026-06-02): GAP-J RESOLVED to DELETE Collection.Indexed — verified first-hand (Collection.Protocol.swift:58-75 supports ~Copyable via _read + the D4 span bridge; Bidirectional refines Collection.Protocol not Indexed; all 6 Indexed conformers also conform Bidirectional → 0 orphaned; 0 generic-constraint/refiner/external-dep consumers; swift-array-primitives builds green at HEAD confirming the ~Copyable Collection.Protocol path). The Collection.Indexed docstring's reason-to-exist ('Collection.Protocol forces Copyable') is stale (pre-detachment). GAP-J is now a pure-subtraction cleanup, independent of GAP-I. §7.1.1, §8 GAP-J, banner, Outcome §0 updated."
  - "1.0.0 (2026-06-02): Initial RECOMMENDATION. Generalizes the cross-layer capability-protocol model from the single iteration concern to the WHOLE Memory.Contiguous / Storage / Buffer / ADT.`Protocol` stack, and reconciles the container tier (HAS-A composition) with the scalar tier (Tagged-forwarding capability-lift, [API-NAME-001c]) as two faces of ONE derive-for-free law. Inventory + derive-for-free map + warranted-refinement test + gap catalog. Critical stance added (§7.1) — evaluates the design, does NOT assume the current code is correct/complete; Deque (Queue.DoubleEnded, swift-deque-primitives) factual correction. DESIGN/RATIONALE only — no package edits."
---
-->

> **RECOMMENDATION (Tier 3, ecosystem-wide / cross-layer).** A unified model for how a type in the
> data-structure stack **derives as much API/behaviour for free as possible** by *conforming to capability
> protocols* — `Memory.Contiguous.\`Protocol\`` → `Storage.\`Protocol\`` → `Buffer.\`Protocol\`` →
> `<ADT>.\`Protocol\`` — **always by COMPOSITION** (a shared bridge / constrained extension keyed on the
> capability, vending free API to every conformer) and **only rarely by REFINEMENT** (protocol inheritance),
> with refinement reserved for the *warranted* case. The principal's bias is explicit: **compose by default;
> refine only when warranted; derive for free as much as possible.**
>
> **This is a GENERALIZATION, not a re-derivation.** `cross-layer-capability-protocol-model.md` (v1.3.0,
> APPROVED 2026-05-28) already established the normal form, the (R)/(C)/(D) edge taxonomy, the decision rule,
> and the specialization boundary — **for the iteration + set-algebra concerns**. This doc lifts that model to
> the whole stack, reconciles it with the *scalar* tier's already-named derive-for-free pattern
> ([API-NAME-001c]), produces the per-layer derive-for-free map, sharpens the compose-vs-refine rule into a
> four-part *warranted-refinement test*, and catalogs the remaining gaps. **DESIGN/RATIONALE only — no
> production code is landed; no live package or worktree is edited.**
>
> Every load-bearing empirical claim is tagged `[Verified: 2026-06-02]` against the source on disk per
> [RES-023]; file:line citations are to the real types, not inferred.
>
> **This doc evaluates the DESIGN; it does NOT assume the current iteration/sequence/collection code is already
> correct or complete.** The inventory records what the code *does*, not that what it does is finished or right.
> §7.1 catalogs where the present code is provisional, inconsistent, or broken — a dormant *non-compiling*
> `Buffer.Linear: Collection.\`Protocol\`` (GAP-I), a **redundant** `Collection.Indexed` whose stated reason to
> exist is stale (GAP-J — *verified: delete*), demangle-crash-driven iterators, and stale docs (GAP-K). These are
> prerequisites/cleanups toward the target shape, not ratifications of the present state. The model is the
> destination; the stack is partway there.

---

## 1. Prior-Art Reconciliation ([HANDOFF-013] / [RES-013a] / [META-003/004/016] — read + reconcile FIRST)

This topic is **not greenfield**. Each cited artifact was read in full; its disposition for this generalizing
doc is recorded. Nothing below is duplicated — it is cited, extended, consolidated, or coordinated-with.

| Artifact | Status | Disposition | Why |
|----------|--------|-------------|-----|
| `cross-layer-capability-protocol-model.md` v1.3.0 (APPROVED, Tier 3) | `[Verified: 2026-06-02]` | **FOUNDATION** | THE model this doc generalizes. §3.2 normal form (REQUIRES→PROVIDES), the (R)/(C)/(D) edge kinds, the decision rule, and §3.3 specialization boundary are quoted, not re-derived. Its §11 step-3 explicitly *authorizes* this generalization ("apply the same normal form … the model generalizes"). |
| `collection-sequence-protocol-detachment.md` v1.1.0 (DECISION, Feb 2026) | `[Verified: 2026-06-02]` | **FOUNDATION** | The *original* orthogonal-not-refine precedent, predating the framework by 3 months. Supplies the demand-gated bridge test (Option-C rejection: "zero algorithms need both simultaneously"). |
| `set-ordered-capability-composition.md` v1.1.0 (RECOMMENDATION) | `[Verified: 2026-06-02]` | **EXTEND** | Its §1 inherits-vs-writes ledger IS the per-protocol derive-for-free output realized on a real type; this doc generalizes that table shape across cores and folds its §3 "Deferred axes" into the gap catalog (§8). |
| `unified-iteration-design.md` v2.2.0 (APPROVED, the iteration authority) | `[Verified: 2026-06-02]` | **COORDINATE** | The single design authority for the *iteration* concern (LOCKED). This doc generalizes FROM it and reuses its §6.6 D1–D5 acceptance rubric; it does NOT reopen iteration shape. |
| `[API-NAME-001c]` Per-Domain Capability-Marker Protocol (code-surface skill) | `[Verified: 2026-06-02]` | **EXTEND / CONSOLIDATE** | The *scalar* tier's already-named, normative derive-for-free pattern. This doc reconciles it with the container tier as the two faces of one law (§3) and recommends promoting the container tier to a sibling rule (§8 GAP-H). |
| `byte-protocol-capability-marker.md` v1.1.0 (RECOMMENDATION, Tier 3) | `[Verified: 2026-06-02]` | **CITE (foundation of scalar tier)** | Names the *recursion-vs-refinement constraint principle* ([IMPL-102]) — the scalar tier's mechanical reason for compose-not-refine. |
| `mutator-orthogonal-vs-refinement-stance.md` v1.0.0 (REFERENCE) | `[Verified: 2026-06-02]` | **CITE** | Supplies the *conformer-set* form of the compose-vs-refine test (sets-identical→merge / overlap→sibling / disjoint→unrelated) and three concrete failure modes of gratuitous refinement. |
| `buffer-storage-associatedtype-prior-art.md` v1.0.0 (RECOMMENDATION) | `[Verified: 2026-06-02]` | **CITE** | The cross-language T1/T2/T3/T4 taxonomy: contiguity-as-CAPABILITY (T4) is universal; storage-as-associated-TYPE (T1) is anti-precedented. The guardrail against the "expose `associatedtype Storage`" instinct. |
| `bulk-span-iteration-fold-vs-separate.md` v1.0.1 (RECOMMENDATION, Tier 3) | `[Verified: 2026-06-02]` | **CITE** | The `Span<~Copyable>`-but-not-`~Escapable` crux + the rule *a capability belongs on the layer whose identity it expresses, composed onto adjacent concerns, not refined into them.* |
| `iterable-span-primitive-implementation-plan.md` v1.0.0 (RECOMMENDATION) | `[Verified: 2026-06-02]` | **CITE** | The empirical cost model: 34 `: Iterable` conformers → 13 bridge-vended (free) / 18 hand-rolled-scalar / 3 piecewise. Proves derive-for-free is *bounded* to capability-bearing conformers. |
| `iterable-se0516-alignment.md` v1.0.0 (RECOMMENDATION) | `[Verified: 2026-06-02]` | **CITE** | The external precedent (SE-0516) lands on the same compose-orthogonal-siblings shape: Iterable = keep-and-lend (World-B), Sequenceable = give-away (World-A). |
| `property-tagged-semantic-roles.md` v1.1.0 (RECOMMENDATION, Tier 2) | `[Verified: 2026-06-02]` | **CITE** | The Group A / Group B taxonomy + fibration framing (connected vs sealed fibers) — *which* phantom-wrapper families can derive-for-free cross-type. |
| `self-projection-default-pattern.md` v1.0.0 (RECOMMENDATION) | `[Verified: 2026-06-02]` | **COORDINATE** | Adds the second axis (projection-of-Self vs attribute-of-conformer); classifies `Memory.Contiguous` as *element-containment* — exactly the container tier's HAS-A framing. |
| `sequence-storage-integration-analysis.md` v2.0.0 (DECISION, Feb 2026) | `[Verified: 2026-06-02]` | **CONSOLIDATE** | Durable separation-of-concerns rationale ("integration at the ADT layer, by construction"); its `Sequence.Protocol`/`Sequence.Consume` vocabulary is stale (renamed/deleted) — consolidate the rationale, drop the names. |
| `[DS-001]`, `[DS-005]`, `[DS-020]`, `[DS-021]` (ecosystem-data-structures) | `[Verified: 2026-06-02]` | **GOVERNS** | [DS-001] four-layer composition is the backbone; [DS-020] gates every new-primitive gap recommendation; [DS-021] ~Copyable pass-through holds throughout. |
| `[RES-018]` Premature Cross-Cutting Primitive Anti-Pattern | `[Verified: 2026-06-02]` | **GOVERNS** | Every gap in §8 is gated: composition-over-existing must be shown to fail before a new core is proposed. |

**Net:** the model exists; the *names* exist (the scalar tier's [API-NAME-001c]; the container tier's (R)/(C)/(D)
taxonomy); the *worked examples* exist (iteration in unified-iteration; set-algebra in cross-layer §4; the
set-ordered ledger). What did **not** exist is (a) the cross-layer derive-for-free *map* across all cores,
(b) the unification of the container and scalar tiers under one law, (c) a single *warranted-refinement test*,
and (d) a consolidated gap catalog. Those four are this doc's contribution.

---

## 2. Context and Question

### 2.1 Context

The data-structure stack is one **HAS-A composition chain** ([DS-001]): **Memory ◄has─ Storage ◄has─ Buffer
◄has─ Collection-tier**, each layer adding exactly one concern. Three of those layers, plus the ADTs at the
collection tier, expose a *capability protocol* — a minimal contract a type conforms to in order to inherit
behaviour. The just-landed Set.Ordered ×16 fan-out (commit `3cc21cc`, 2026-06-01) *proved* the derive-for-free
model for **one** capability — iteration: a type conforms `Memory.Contiguous.\`Protocol\`` (one requirement:
`span`), declares `: Iterable`, and the shared `memory→Iterable` bridge vends `makeIterator` + the whole
terminal suite (`forEach`/`contains`/`first`/`reduce`) **for free** over the public span — *one bridge per
CAPABILITY, never per-ADT*. The same fan-out landed the one sanctioned refine edge,
`Collection.\`Protocol\`: Iterable`.

This doc generalizes that single proof into the **general law for the whole stack**: it is the durable answer
to *"for any layer's capability protocol, what does a conformer get for free, by what mechanism, and when (if
ever) is refinement the right mechanism instead of composition?"*

There is a second, parallel realization of derive-for-free already in production: the **scalar tier**. Group A
capability markers (`Byte`, `Cardinal`, `Ordinal`, `Index`) lift their entire API onto every conformer —
including every `Tagged<Tag, X>` phantom wrapper — via a per-domain `X.\`Protocol\`` with default impls plus
recursive `Tagged` forwarding ([API-NAME-001c]). The two tiers were designed at different times against
different framings; this doc shows they are **two faces of one law**.

### 2.2 Question

For the capability protocols of the stack — `Memory.Contiguous.\`Protocol\``, `Storage.\`Protocol\``,
`Buffer.\`Protocol\``, the iteration substrate (`Iterable` / `Sequenceable`), and the ADT cores
(`Collection.\`Protocol\``, `Set.\`Protocol\``, …):

1. What does each vend FOR FREE today, and by what mechanism?
2. Where does the stack *hand-write* per-type what a capability bridge could vend — and where is that
   hand-writing *correct* (genuinely irreducible) versus a *gap* (a derivation the stack declines)?
3. What is the decision rule for **compose-by-default vs refine-only-when-warranted**, and what is the precise
   test for "warranted"?
4. Which gaps should be closed, and which would require a new primitive (gated through [DS-020]/[RES-018])?

---

## 3. The two tiers of derive-for-free — one law, two faces

Derive-for-free appears in the ecosystem in **two structural shapes**, and recognizing them as one law is the
key to generalizing the model.

| | **Container tier** (this stack) | **Scalar / value tier** |
|---|---|---|
| Shape | **HAS-A composition chain** | **IS-WRAPPED-BY (Tagged forwarding)** |
| Members | `Memory.Contiguous.\`Protocol\``, `Storage.\`Protocol\``, `Buffer.\`Protocol\``, `Iterable`, `Collection.\`Protocol\``, `Set.\`Protocol\`` | Group A markers: `Byte`, `Cardinal`, `Ordinal`, `Index` (the `X.\`Protocol\`` family) |
| "Derive free" means | a conformer inherits a *capability's operations* (iteration terminals, algebra, span-read) | a conformer (incl. `Tagged<Tag, X>`) inherits a *value type's API* (operators, literals, stdlib witnesses) |
| Mechanism | constrained-extension **bridge** keyed on the capability (`extension Memory.ContiguousProtocol where Self: Iterable { … }`) + intra-protocol defaults | default impls on `extension X.\`Protocol\`` + **recursive** `extension Tagged: X.\`Protocol\``, one per domain |
| Named yet? | **No `[PREFIX-NNN]` rule** — only the framework doc + as-built bridges | **Yes — `[API-NAME-001c]`, normative** |
| Self-projection classification | `Memory.Contiguous` is an *element-containment* protocol (`Element` = what-the-conformer-CONTAINS) `[Verified: 2026-06-02 — self-projection-default-pattern.md V5]` | Group A markers are *domain-identity* wrappers (connected fibers via `retag`) |

**Both tiers independently chose compose/relate, not refine** — and that convergence is the model's strongest
evidence. The container tier reaches "compose" by a *semantic identity* argument; the scalar tier reaches the
*same* "compose" by a *mechanical Swift-expressibility* argument: a refinement-of-`Carrier` form for a Group A
marker is **inexpressible** because it blocks recursive `Tagged` conformance (the recursion-vs-refinement
constraint, [IMPL-102]) `[Verified: 2026-06-02 — byte-protocol-capability-marker.md §1.2.1; Byte.Protocol.swift:9-26]`.
That the scalar tier's reason is mechanical (refinement literally will not compile recursively), not aesthetic,
is *independent corroboration* that "compose by default" is the right law — in the one place the ecosystem tried
refinement (Byte's early refinement form; the `Carrier` super-protocol pitch), it hit a hard wall and walked
back `[Verified: 2026-06-02 — 2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md]`.

**Reconciliation recommendation (see §8 GAP-H):** promote the container tier to a *sibling rule* of
[API-NAME-001c], stating that the container tier (HAS-A composition chain) is the dual of the scalar tier
(IS-WRAPPED-BY Tagged forwarding) under one derive-for-free law — or at minimum cross-reference the two so the
ecosystem reads them as one principle, not two coincidences.

The rest of this doc is the **container tier**; the scalar tier is its already-formalized dual, cited where it
sharpens the rule.

---

## 4. PART 1 — Inventory: the capability protocols and what each vends free

The framework's **normal form** (cross-layer §3.2): every capability **core** is a pair
⟨**REQUIRES**: its layer's irreducible primitives⟩ → ⟨**PROVIDES**: only the derivations expressible from *its
own* requirements⟩. Larger derived families that need another concern attach **orthogonally** by composition.
Three **edge kinds**:

- **(R) Refine** (IS-A): `protocol P: Q` — only *within* an axis where identity holds.
- **(C) Compose-default** (HAS-A / provides-when-also-conforms): `extension P where Self: Q { … }` — a default
  fires when a conformer *also* conforms `Q`; the cross-axis bridge.
- **(D) Provides-as-default** (intra-protocol): `extension P { … }` — derive ops from `P`'s own requirements.

"Derive for free" for a conformer is the union of every (D) on the protocols it conforms, plus every (C) bridge
whose `where`-clause it satisfies, plus everything inherited across any (R) edge.

### 4.1 The per-protocol inventory

| Protocol (hoisted) | Package · file:line | REQUIRES (minimal) | PROVIDES (D) | Compose bridges (C) | Refines (R) |
|---|---|---|---|---|---|
| **`Memory.Contiguous.\`Protocol\``** (`Memory.ContiguousProtocol`) | swift-memory-primitives · `Memory.ContiguousProtocol.swift:77-93` | `var span: Span<Element>` (the **one** requirement); `Element: ~Copyable`; `Self: ~Copyable`, Escapable | **none** | **`makeIterator() → Iterator.Chunk(span)` where `Self: Iterable`** — the canonical bridge (`Memory.Contiguous+Iterable.swift:31-37`), D4 `~Copyable`-relaxed | **none** |
| **`Memory.Contiguous.Borrowed.\`Protocol\``** (`__Memory_Contiguous_Borrowed_Protocol`) | swift-memory-primitives · `__Memory_Contiguous_Borrowed_Protocol.swift:41-56` | `var span { @_lifetime(copy self) get }`; `Self: ~Copyable, ~Escapable` | **none** | same `makeIterator` bridge, `~Escapable` arm (`Memory.Contiguous+Iterable.swift:52-59`) | **none** — **sibling** of the owned protocol (witness-table contract for `span` differs across lifetime regimes) |
| **`Storage.\`Protocol\``** (`__StorageProtocol`) | swift-storage-primitives · `Storage.Protocol.swift:20-37` | `var capacity: Index<Element>.Count`; `@unsafe func pointer(at: Index<Element>) -> UnsafeMutablePointer<Element>`; `Element: ~Copyable`; single-region (`Storage.Split` does NOT conform) | **none** (no `extension __StorageProtocol` exists) | **none** keyed on `Storage.\`Protocol\`` — the §3.4-recommended `span`-from-`pointer(at:.zero)` bridge **does not exist** (GAP-C) | **none** |
| **`Buffer.\`Protocol\``** (`__BufferProtocol`) | swift-buffer-primitives · `Buffer.Protocol.swift:22-41` | `var count: Count`; `Count: Carrier.\`Protocol\`<Cardinal> = Index<Element>.Count`; `Element: ~Copyable`; `Self: ~Copyable, ~Escapable` | `isEmpty` (`count == .zero`), constrained `where Count == Index<Element>.Count` (`Buffer.Protocol.swift:56-67`) | **none** on `Buffer.\`Protocol\`` itself (the buffer family reaches the memory bridge by *separately* conforming `Memory.Contiguous.\`Protocol\``) | **none** — explicitly NOT `Storage.\`Protocol\`` (HAS-A, `:87-91`), NOT `Iterable` (orthogonal, `:93-107`) |
| **`Iterable`** (multipass / borrow) | swift-iterator-primitives · `Iterable.swift:35-57` | `associatedtype Iterator: __IteratorChunkProtocol`; `borrowing func makeIterator() -> Iterator` | `forEach`, `contains`, `reduce` (no Copyable gate), `first` (gated `Copyable & Escapable` — extraction past borrow); each with a fallible `Either<E, Iterator.Failure>` overload | receives `makeIterator` FREE from the memory bridge | **none** (it is the *supertype* of the one refine edge) |
| **`Sequenceable`** (single-pass / consume) | swift-sequence-primitives · `Sequenceable.swift:90-122` | `consuming func makeIterator()`; binds the scalar `Iterator.Protocol` | lazy pipeline (`map`/`filter`/`drop`/`prefix`), eager terminals, `collect`/`count` | — | **none** — **orthogonal sibling** of `Iterable` |
| **`Collection.\`Protocol\``** (`__CollectionProtocol`) | swift-collection-primitives · `Collection.Protocol.swift:58` | `startIndex`, `endIndex`, `subscript(Index) -> Element`, `index(after:)`; `Index: Comparison.\`Protocol\` & ~Escapable = Index<Element>`; `Element: ~Copyable` | `isEmpty` (`startIndex == endIndex`), `formIndex(after:)`, `count` (O(n) walk, override O(1)) | the Swift.Collection stdlib bridge is a marker only (needs explicit double-conformance) | **`: Iterable`** — **THE one sanctioned refine edge**, landed 2026-06-01 (`3cc21cc`). Carries **no** `makeIterator()` default (intentionally — see §6.4). Chain: `Access.Random ⊳ Bidirectional ⊳ Collection.\`Protocol\` ⊳ Iterable`. |
| **`Set.\`Protocol\``** (`__SetProtocol`) | swift-set-primitives | `contains(_:)`, `count`; `Element: Hash.\`Protocol\` & ~Copyable` | `isEmpty` | the **entire set algebra** `where Self: Set.\`Protocol\` & Iterable` (predicates) / `where Self: BuildableSet & Iterable` (constructive) — in `swift-set-algebra-primitives` | **none** — membership is the identity, not iteration (cross-layer §5) |

(`Iterator.Chunk.\`Protocol\``/`__IteratorChunkProtocol` is the SE-0516-analog bulk iterator that backs the
above; it requires `next(maximumCount:) -> Span<Element>` and provides scalar `next() -> Element?` gated
`Element: Copyable`. It deliberately does **not** refine the scalar `Iterator.Protocol` — a `~Copyable` chunk
iterator must not owe the move-out `next() -> Element?`. `Memory.Contiguous` concrete = the BitwiseCopyable
self-owning heap buffer, [DS-006], the leaf that *synthesizes* `span`.)

### 4.2 The structural reading

Three facts about this table are the whole model:

1. **The cores are maximally minimal.** `Memory.Contiguous.\`Protocol\`` requires exactly `span`; `Storage`
   exactly `{capacity, pointer(at:)}`; `Buffer` exactly `count`. Each PROVIDES (D) only what its *own*
   requirement yields — `isEmpty` from `count`, nothing from `span` *yet* (GAP-B). The richness is composed
   *in*, never baked into a core.

2. **One bridge per capability, keyed on the capability, never per-ADT.** The `memory→Iterable` bridge
   (`Memory.Contiguous+Iterable.swift:31-37`) is *one* constrained extension that vends `makeIterator` over
   `span` to *every* contiguous conformer that opts into `: Iterable` — Array, Set.Ordered, Stack, Buffer.Linear
   all ride it with an **empty conformance body** plus an `@_implements(Iterable, Iterator)` typealias
   `[Verified: 2026-06-02 — Buffer.Linear+Iterable.swift:17-19; Set.Ordered+Iterable.swift:25-28;
   Array.Conformances.swift:55-63]`. That is the derive-for-free engine: write `span` once, declare `: Iterable`,
   inherit the iterator and the entire terminal suite.

3. **The cores do not refine one another or the cross-cutting concerns.** `Buffer` does not refine `Storage`
   (HAS-A); neither refines `Iterable` (orthogonal). The *only* refine edge in the entire stack is
   `Collection.\`Protocol\`: Iterable`. Everything else relates by (C) or (D). This is "compose by default" made
   structural.

---

## 5. PART 2 — The derive-for-free map: free today vs hand-written, and the mechanism

### 5.1 The cross-ADT ledger

For the live ADTs, *how* each acquires each capability — verified against the conformance files on disk.

| ADT (contiguity) | Iteration (`makeIterator`) | Collection face | Equality / Hashing / Description | Membership / count |
|---|---|---|---|---|
| **Array** (contiguous) | **bridge-derived** — `: Memory.Contiguous.\`Protocol\`` (span) then `: Iterable` empty body (`Array.Conformances.swift:55-63`) | **hand-written** index witnesses (`Array ~Copyable.swift:27-65`); conforms `Collection.Indexed`/`Bidirectional` | **absent** — declares none, **though span-derivable** (GAP-A) | — |
| **Set.Ordered** (contiguous) | **bridge-derived** (`Set.Ordered+Iterable.swift:25-28`) | not a Collection (membership face) | **span-derived** — `lhs.span == rhs.span` / `span.hash(into:)` (`Set.Ordered+Hash.Protocol.swift:16-29`) — **the exemplar** | `Set.\`Protocol\`` (contains + count) |
| **Stack** (contiguous) | **bridge-derived** (`Stack+Iterable.swift:26-29`) | not a Collection (LIFO face) | **absent**, **though span-derivable** (GAP-A) | — |
| **Buffer.Linear** (contiguous) | **bridge-derived** (`Buffer.Linear+Iterable.swift:17`) | dormant (`+Collection.Protocol` commented out) | — | `Buffer.\`Protocol\`` (count → `isEmpty` (D)) |
| **Queue.DoubleEnded** (Deque; ring, *not* contiguous) | **hand-written** via `Iterator.Materializing` over `Buffer.Ring.Scalar` (`Queue.DoubleEnded+Iterable.swift`) | **Collection** — `Collection.Indexed`/`Bidirectional`/`Access.Random`, **hand-written** index witnesses (`Queue.DoubleEnded Copyable.swift:104-128`) | **hand-written** (no span) | — |
| **Queue** (FIFO ring, *not* contiguous) | **hand-written** via `Iterator.Materializing` over a scalar ring iterator (`Queue+Iterable.swift:35-48`) | **not a Collection** (deliberately dropped) | **hand-written** via iterator-walk, gated `Copyable` (`Queue+Conveniences.swift:24-79`) | — |
| **Dictionary** (split slab pairs, *not* contiguous) | **hand-written** scalar pair-iterator + `Iterator.Materializing` (`Dictionary.Iterator.swift:48`) | **none** (dropped, `Dictionary.swift:141-143`) | **none** | — |

**Two recipes, separated by contiguity. The *design* is right; not every current hand-written iterator is a
clean realization of it** (some are toolchain-bug workarounds — §7.1):

- **Contiguous ⇒ bridge-derived iteration.** A type with a single `span` conforms `Memory.Contiguous.\`Protocol\``
  and gets the iterator + terminals free. *Zero hand-written iterators.* (Array, Set.Ordered, Stack,
  Buffer.Linear.) This is the recipe working as intended.
- **Non-contiguous ⇒ hand-written via `Iterator.Materializing`.** A ring wraps; a dictionary splits pairs across
  two slab buffers; a linked list follows a node chain — no single `Span<Element>` exists, so the
  `memory→Iterable` bridge is *inapplicable by construction*. The *divergence* is legitimate (no span ⇒ no span
  bridge — a design fact, not a gap). But the *specific* hand-written witnesses are not all clean: `Buffer.Ring.Scalar`
  and the Dictionary pair-iterator are shaped by a **live toolchain demangle crash** (Signal-6
  `swift_getAssociatedTypeWitness` — the generic `Memory.Cursor`/`Sequenceable` witness crashes at runtime, so
  these types bind a bespoke scalar witness to dodge it) `[Verified: 2026-06-02 — Buffer.Ring+Sequence.Protocol.swift:23-26]`.
  Those are *provisional workarounds*, not the settled shape; they should be revisited (and possibly deduped onto
  a generic cursor) once the crash is fixed (`/issue-investigation`). **The model anticipates the divergence; it
  does not bless the current witnesses as final.**

The empirical cost model confirms the boundary: across 34 production `: Iterable` conformers, **13 are
bridge-vended (free), 18 are hand-rolled scalar generators, 3 are piecewise**
`[Verified: 2026-06-02 — iterable-span-primitive-implementation-plan.md]`. **Derive-for-free is bounded to the
capability-bearing (dense-contiguous) conformers** — and that boundary is *exactly* the conformance to
`Memory.Contiguous.\`Protocol\``. A type that can vend `span` rides every span-keyed bridge; a type that cannot
implements (or escalates).

### 5.2 Free today vs could-be-but-hand-written

| Capability | Free today (mechanism) | Hand-written where it *could* be free | Mechanism that would vend it | Verdict |
|---|---|---|---|---|
| **Iteration** over a span | YES — `memory→Iterable` (C) bridge | (none for contiguous types) | — | **Solved.** The fan-out's proof. |
| **`isEmpty`** | YES — `Buffer.\`Protocol\`` (D) `count == .zero`; `Collection.\`Protocol\`` (D) `startIndex == endIndex` | `Buffer.Arena.isEmpty` is redundant (element-domain — could use the (D) default) `[Verified: 2026-06-02 — Buffer.Arena+Buffer.Protocol.swift:26-29]` | drop the witness, inherit (D) | **GAP-E** (cleanup) |
| **`count` / positional read / bounds** over a span | NO | `Memory.Contiguous.count` is *stored* (`Memory.Contiguous.swift:88`) and `Memory.Contiguous.Borrowed.count` re-derives (`:75`) | new (D) defaults on `Memory.Contiguous.\`Protocol\``: `var count { span.count }`, `subscript { span[i] }` | **GAP-B** (count IS a memory concern) |
| **`span`** over storage | NO | `Storage.Heap` + `Storage.Inline` hand-write **structurally-identical** span getters (and `withUnsafeBufferPointer`) `[Verified: 2026-06-02 — Storage.Heap+Memory.Contiguous.Protocol.swift:29-38; Storage.Inline+…:30-39]` | a `Storage.\`Protocol\``-keyed (C) bridge — **but** the span length is the *initialization* count, not `capacity`, so an init-count requirement must be added first | **GAP-C** (two-part) |
| **Equality / hashing** over a span | YES for Set.Ordered (span SLI bridges) | **Array and Stack declare none, though they have the span** `[Verified: 2026-06-02 — grep of Array/Stack modules; Set.Ordered+Hash.Protocol.swift:16-29]` | per-type opt-in to `Equation.\`Protocol\``/`Hash.\`Protocol\`` over `span` — the bridges **already exist** | **GAP-A** (no new primitive — the sharpest actionable gap) |
| **Iteration over a piecewise (ring) buffer** | NO | `Buffer.Ring.Segments` routing, ×3 variants (each maximally reuses `Iterator.Chunk` per segment) `[Verified: 2026-06-02 — Buffer.Ring+Span.swift:81-102]` | a piecewise/N-segment bridge keyed on `segments → sequence-of-Span` | **GAP-D** (generalizes the contiguous bridge) |
| **`Swift.Sequence` interop** | NO (deleted in the SE-0516 migration) | every span-primitive ADT lacks `Swift.Sequence` | one generic `extension X: Swift.Sequence where Element: Copyable`, vended once | **GAP-G** (ecosystem-wide, gated to the fan-out) |
| **Mutating-op bodies** (`insert`/`remove`/`append`) | NO — and correctly so | per-variant, because there is no uniform buffer-mutable core | a *buffer-mutable* capability protocol — **does not exist**; hot mutating ops stay concrete-Base by the specialization boundary regardless | **GAP-F** (deferred-irreducible; gated) |
| **Collection index witnesses** (`startIndex`/`endIndex`/`subscript`/`index(after:)`/`index(before:)`) | the *iteration* half is free (refine edge); the *index* half is hand-written | Array **and** the Deque hand-write the five witnesses | — | **Right design, not a bridge-gap** (§7) — but the index-*root* choice (`Collection.Indexed` vs the spine) is unsettled (§7.1) |

---

## 6. PART 3 — The decision rule and the warranted-refinement test

### 6.1 Compose by default — and it is *free* to do so

The framework's decision rule (cross-layer §3.2, quoted, not re-derived):

> **Refine (R) only when the type's identity IS the supertype's concern; compose (C) otherwise.**

The first thing to establish is that **this is not a performance trade-off.** The specialization boundary
(cross-layer §3.3) proves that a derived operation is safe *as a protocol-extension default* iff it
monomorphizes to **0 `witness_method`** in release, cross-module — and the Set.Ordered pilot proved that
**multi-protocol composition (`where Self: P & Q`) costs nothing at that boundary**, the same 0-witness bar as
single-protocol. So **(R) and (C) specialize identically**; the choice between them carries *no* runtime cost.
Refinement therefore buys nothing performance-wise — which means the decision is **purely semantic/structural**,
and "compose by default" is the correct prior because composition is strictly more flexible (a conformer opts
into each capability independently) at equal cost.

### 6.2 The warranted-refinement test

When *is* refinement warranted? The corpus supplies four independent discriminators — from the framework, the
mutator stance, the scalar tier, and the cross-package mechanics. They are **not four laws; they are four
necessary conditions for the same conclusion.** A refine edge `P: Q` is **warranted iff it passes ALL FOUR**;
failing any one means *compose instead*.

| # | Condition | The test | Fails when | Source |
|---|---|---|---|---|
| **C1 — Identity** | The conformers of `P` *are* `Q`, not merely *have* or *relate to* `Q`. | "Is every `P` an `Q` *as a matter of identity*?" | `P` HAS-A `Q` (Buffer has-a Storage) or `P` relates-to `Q` across orthogonal axes (Buffer ⟂ Iterable). | cross-layer §3.2 |
| **C2 — Conformer-set** | The conformer set of `P` is a genuine *subset* of `Q`'s — every `P`-conformer is a sound `Q`-conformer, and the inclusion is not coincidental. | "Are there types that are `Q` but not `P`, *and* is every `P` soundly a `Q`?" | the sets merely *overlap* (Carrier ∩ Mutable ≠ either) → sibling + dual-conformance, not refine. | mutator-orthogonal-vs-refinement-stance.md |
| **C3 — Expressibility** | The refinement does not block a *needed* recursive or composed conformance. | "Does `P: Q` force an associated-type binding that excludes a conformer the design requires (e.g. `Tagged<Tag, X>`)?" | a Group A marker's `X.\`Protocol\`: Carrier.\`Protocol\` where Underlying == U` blocks `Tagged<Tag, X>` (overlapping-conformance ban, [IMPL-102]). | byte-protocol-capability-marker.md §1.2.1 |
| **C4 — Cross-package mechanics** | The refine edge is *declarable where it is needed*, without forcing an unwanted dependency. | "Can `P: Q` be written at `P`'s declaration site without pulling `Q`'s package into `P`'s identity? (Retroactive refinement is impossible cross-package.)" | declaring `Memory.Contiguous.\`Protocol\`: Iterable` would force an iterator dep onto memory — refused ([MOD-035]); retroactive refine is *impossible* anyway. | `Memory.Contiguous+Iterable.swift:11-19` |

**Why a single test with four conditions, rather than one criterion:** C1 (identity) is the *semantic* gate and
is primary. But identity can *seem* to hold while a mechanical wall forbids the edge — that is what C3 and C4
catch. C2 is C1 restated extensionally (over conformer sets), and is the most operational form to *check*. The
scalar tier is the proof that the conditions are independent: there, C1 might be argued ("a `Byte` IS-A
carrier-of-`UInt8`") yet C3 *fails* (refinement blocks `Tagged<Tag, Byte>`), so the scalar tier composes — its
reason is purely C3, a mechanical wall, with no appeal to identity at all. Conversely the `memory→Iterable`
bridge composes because C4 fails (the edge cannot be declared at memory without violating [MOD-035]), again
independent of identity.

**Three failure modes of gratuitous refinement** (mutator-stance, generalized) — these are *why* failing the
test is costly, not merely stylistically off:

1. **It coerces conformer sets.** `P: Q` asserts every `P` is a `Q`; if some `P`-conformers are not soundly `Q`
   (phantom-identity carriers reject mutation; raw memory rejects iteration), the edge forces an unwanted
   relationship.
2. **It muddles the user.** Refinement signals "every `P` should be `Q` in principle," creating ecosystem
   pressure to author witnesses for conformers the design rationale *excludes* (a `User.ID` pressured to become
   `Mutable`; raw memory pressured to become iterable).
3. **It pays no dividend.** By SE-0335, *conditional conformance to a protocol does not imply conformance to its
   parent* — so a dual-conforming type authors two extensions either way; refinement has the *same* authoring
   cost as siblings while being *less* honest. And (§6.1) it is no faster.

### 6.3 The one sanctioned refine edge, tested

`Collection.\`Protocol\`: Iterable` is the *only* refine edge in the stack
`[Verified: 2026-06-02 — Collection.Protocol.swift:58]`. It passes all four conditions:

- **C1 (identity): PASS.** A collection's identity *is* indexed multi-pass iteration — "a collection IS-A
  multipass iterable; the reverse is false" (`Collection.Protocol.swift:43-53`). Iteration is not an orthogonal
  add-on to a collection the way it is to raw memory or a buffer; it is constitutive.
- **C2 (conformer-set): PASS.** Every `Collection.\`Protocol\`` conformer is a sound `Iterable` (it can produce
  a multipass borrowing iterator); there are `Iterable`s that are not collections (a raw contiguous region, a
  ring). Proper subset.
- **C3 (expressibility): PASS (vacuously).** `Collection.\`Protocol\`` is not a Group A marker; there is no
  recursive-`Tagged` composition pressure on it. The condition is not engaged.
- **C4 (cross-package mechanics): PASS.** Both protocols live in the primitives layer and the edge is declared
  at `Collection.\`Protocol\``'s own declaration site; no foreign dependency is forced (a collection package
  depending on the iterator package is correct layering, not an identity violation).

By contrast, `Memory.Contiguous.\`Protocol\``, `Storage.\`Protocol\``, `Buffer.\`Protocol\``, and
`Set.\`Protocol\`` each **fail C1** against `Iterable` (their identity is contiguous-read / slot-access /
occupancy / membership, not iteration) — and `Memory.Contiguous.\`Protocol\`` *additionally* fails C4 — so all
four compose. This is the decision rule producing exactly the stack on disk.

### 6.4 The deep reason the refine edge omits `makeIterator()`

`Collection.\`Protocol\`: Iterable` carries **no** `makeIterator()` default — each conformer supplies its own
`[Verified: 2026-06-02 — Collection.Protocol.swift:43-53]`. This is the model's most subtle point and worth
stating precisely: an `index`-walk `makeIterator()` (drive the iterator by `subscript(index)` + `index(after:)`)
would force a *scalar move-out* and reintroduce an `Element: Copyable` gate, destroying the `~Copyable`
guarantee. So **iteration is deliberately NOT derived from the index requirements.** Instead, Collection
*refines* `Iterable` to *inherit the terminal suite*, and gets the *iterator itself* from the **`memory→Iterable`
(C) bridge** over `span` — when the collection is contiguous. **Refine-for-identity (the terminals) +
compose-for-capability (the iterator) are two separate edges, joined at the conformer.** This is the template
for every future collection-tier core.

---

## 7. The sharpest gap, resolved: the Array and Deque Collection witnesses

The handoff named the sharpest question: *are Array/Deque's hand-written `Collection` witnesses a sign of a
missing `memory→Collection` bridge, or is routing Collection-ness through `Collection.\`Protocol\`: Iterable`
the deliberate answer?*

**The two Collection conformers in the cohort are `Array` and `Queue.DoubleEnded` (the Deque, in
`swift-deque-primitives`) — and they are the perfect pair, because they differ on the one axis that settles the
question** `[Verified: 2026-06-02]`. Both conform `Collection.Indexed` / `Collection.Bidirectional`
(`Collection.Access.Random` for `Copyable` elements) and **both hand-write their index witnesses**
(`Array ~Copyable.swift:27-65`; `Queue.DoubleEnded Copyable.swift:104-128`). They differ only in *how the
iteration half is supplied*: Array is contiguous (vends `span`), the Deque is a wrapping ring (no single span).
The other cohort types — `Queue` (FIFO), `Stack`, `Set.Ordered`, `Dictionary` — conform `Collection` **not at
all** (iteration and/or membership faces only) `[Verified: 2026-06-02]`.

**The verdict: the hand-written index witnesses are the deliberate, correct answer — not a bridge-gap.**
Collection-ness *decomposes* into two halves on two separate edges, joined at the conformer:

1. **The iteration half is supplied by whichever mechanism fits the storage — and never by an index-walk.** For
   the contiguous **Array**, `makeIterator` is *not* hand-written: Array conforms `Memory.Contiguous.\`Protocol\``
   (vends `span`), declares `: Iterable`, and the `memory→Iterable` (C) bridge supplies the iterator; the
   `Collection.\`Protocol\`: Iterable` refine edge then supplies the terminal suite for free. For the
   non-contiguous **Deque**, the ring wraps, so there is *no* `span`, *no* `Memory.Contiguous.\`Protocol\``, and
   the bridge is inapplicable — the Deque correctly hand-writes a scalar iterator wrapped in `Iterator.Materializing`
   (`Queue.DoubleEnded+Iterable.swift`). In **both** cases iteration is *composed in* (the refine edge for the
   terminals; a storage-fitting iterator for `makeIterator`), **never derived from the index requirements** —
   because an index-walk `makeIterator()` forces a scalar move-out + a Copyable gate (§6.4).

2. **The index half is declared per-collection — and that is correct, identically for both.** The five witnesses
   (`startIndex = .zero`, `endIndex = count.map(Ordinal.init)`, `index(after:) = i.successor.saturating()`,
   `index(before:) = i.predecessor.exact()`, `subscript = _buffer[index]`) are **index-domain** operations: a
   *typed* `Index<Element>` identity, `startIndex`/`endIndex` *as that Index type*, bidirectional navigation, and
   successor/predecessor *totality* (`.saturating()`/`.exact()`). A `Swift.Span` exposes element access by raw
   position but carries **none** of this — no typed-Index identity, no `index(before:)`, no totality story — and
   the Deque has no span at all. The index contract is each collection's own identity, in both cases.

**Why a `memory→Collection` bridge is the wrong shape (possible, but unwarranted).** One *could* write
`extension Collection.\`Protocol\` where Self: Memory.Contiguous.\`Protocol\`, Index == Index<Element>` and fill
the index bodies from `span.count` — the bodies for a contiguous type are derivable. But that bridge would be:

- **non-universal** — it serves *only contiguous* collections; a linked list, a tree, a B-tree have
  Collection-ness with *no* `span`, so their index witnesses can never come from such a bridge. The index
  contract is therefore a *per-collection* concern by construction, not a memory-derived one.
- **low-value** — it vends four one-liners, versus the `memory→Iterable` bridge which encapsulates the entire
  `Iterator.Chunk` machinery. The derive-for-free payoff is marginal where the witnesses are trivial and the
  *identity* (what *is* this collection's index?) is the thing being declared.
- **mis-attributing identity** — the typed `Index` domain is owned by `swift-index-primitives`, not by memory.
  Asking memory to vend a collection's indices inverts ownership.

And the structural anchor: §6.4 — iteration *cannot* be derived from indices (scalar move-out + Copyable gate),
which is precisely why `Collection.\`Protocol\`` refines `Iterable` to get the iterator from the *span* bridge
rather than from its *own* index requirements. The two halves are deliberately kept on separate edges.

**So the deliberate answer is neither "hand-write everything" nor "one big `memory→Collection` bridge." It is:
*refine the iteration in for free (Collection ⊳ Iterable + the memory bridge), and declare the index contract as
the collection's own identity.*** Compose-where-it-pays + declare-the-identity. This is *more* correct than a
`memory→Collection` bridge because it is the *same* pattern for contiguous and non-contiguous collections alike.

**The genuinely actionable gap nearby (GAP-A).** What Array *does* leave on the table is **equality and
hashing**: Array conforms `Memory.Contiguous.\`Protocol\`` (has the `span`) yet declares no `Equatable`/
`Hashable` at all — while Set.Ordered derives both over `span` via the *already-existing* `Span` SLI bridges
(`lhs.span == rhs.span` / `span.hash(into:)`). This is a true "could-be-derived-but-isn't," distinct from the
Collection case which is "cannot-be-derived-and-correctly-isn't." See §8 GAP-A.

### 7.1 Where the current iteration/collection code is NOT settled-correct

The §7 verdict is a *design* judgment — "hand-write the index half, compose the iteration half" is the right
shape, and it stands on its own reasoning (§6.4) independent of whether the present code is bug-free. **This doc
evaluates the design; it does NOT certify the current iteration/sequence/collection code as correct or complete.**
The inventory verifies what the code *does*, not that what it does is finished or right. Five places where the
present state is provisional, inconsistent, or open are flagged here so the §8 recommendations are read as
*toward a target*, not as ratifications of the status quo:

1. **`Collection.Indexed` is redundant dead weight — RESOLVED: delete it (GAP-J).** Every conformer conforms
   *two overlapping index roots*: Array (×4 variants) and the Deque (×2) conform **both** `Collection.Indexed`
   *and* `Collection.Bidirectional` for the same element kind `[Verified: 2026-06-02 — Array ~Copyable.swift:58,62;
   Queue.DoubleEnded Copyable.swift:104,117]`, and the two roots restate `startIndex`/`endIndex`/`index(after:)`
   + `isEmpty`/`formIndex(after:)`. `Collection.Indexed`'s docstring justifies itself as the *only* `~Copyable`-safe
   index root, claiming `Collection.Protocol`'s `subscript -> Element { get }` and `Iterable` refinement "force
   Copyable" — **but that premise is now false**: `Collection.Protocol` declares `associatedtype Element: ~Copyable`
   and `subscript -> Element { get }` *satisfied via `_read`*, and its `Iterable` refinement carries `~Copyable`
   through the D4 span bridge `[Verified: 2026-06-02 — Collection.Protocol.swift:58-75; build of swift-array-primitives
   green at HEAD]`. So `Collection.Protocol` is a strict superset of `Collection.Indexed`, the ~Copyable path
   compiles, and *zero* conformers, generic constraints, or refining protocols need `Indexed`
   `[Verified: 2026-06-02 — grep: no `: Collection.Indexed` consumer, no refiner, no external product dep]`. This
   verifies the §7 decomposition (the index contract is the collection's identity — and it lives on **one** root,
   the spine, not two). The docstring and the 2026-06-01 "delete deferred" note both rest on the pre-detachment
   premise (when `Collection.Protocol: Sequence.Protocol` forced a consuming iterator) — stale since the
   span-primitive realignment. See GAP-J for the (mechanical) deletion; it is *independent* of GAP-I (Buffer.Linear
   does not conform `Indexed`).

2. **`Buffer.Linear: Collection.\`Protocol\`` is dormant and broken, not deferred-clean.** The conformance file
   is *entirely commented out*, recording a `Collection.Protocol+defaults.swift` lifetime-dependence compile
   error, with the Collection product deps commented out in the manifest too
   `[Verified: 2026-06-02 — Buffer.Linear+Collection.Protocol.swift:8-26]`. The one place the buffer layer would
   meet the sanctioned refine edge **currently does not compile**. Any recommendation that leans on a
   buffer-level Collection face must treat this as an unresolved defect on the Collection spine, not a clean
   deferral.

3. **Demangle-crash-driven iterators (§5.1).** `Buffer.Ring.Scalar` and the Dictionary pair-iterator are bespoke
   *because* the generic `Memory.Cursor`/`Sequenceable` witness crashes at runtime (Signal-6). These are
   workarounds that keep the per-variant hand-writing the model otherwise wants to dedup — provisional, pending
   `/issue-investigation`, not the intended end-state.

4. **Stale stdlib-bridge markers misdescribe the live hierarchy.** `Collection.Protocol+Swift.Collection.swift`
   (and the `Bidirectional`/`Access.Random` analogs) still claim "Collection.Protocol no longer inherits from
   Sequence.Protocol … must conform to both" and reference the renamed `Sequence.Protocol` — but Collection now
   *refines* `Iterable` (2026-06-01) and `Sequence.Protocol` is `Sequenceable`. The docs lag the code; "the code
   documents the right design" is, today, **false** here. (A doc-fix, but it means the on-disk rationale cannot
   be trusted as the design of record — this doc is.)

5. **The model itself is a RECOMMENDATION, and its one refine edge is freshly landed.** `Collection.\`Protocol\`:
   Iterable` shipped 2026-06-01 (commit `3cc21cc`) and the ×16 fan-out that generalizes the shape is **gated, not
   complete**. The compose-vs-refine *law* is robust (it is corroborated independently by the scalar tier, §3),
   but the assertion "the stack already derives-for-free everywhere it should" is *not* established — §5.2 and §8
   are precisely the catalog of where it does not yet.

None of these overturn the model's conclusions (compose-iteration + declare-index; the four-part warranted-refinement
test; the gap priorities). They *bound* them: the model is the target; the current code is partway there — a
non-compiling Collection conformance, two overlapping index roots, bug-driven iterators, and stale docs included.
Treating the present code as already-correct would be the error the §8 recommendations exist to avoid.

---

## 8. PART 4 — Gaps and recommendations (gated through [DS-020] / [RES-018])

Every recommendation below is gated: per [DS-020] the data-structure catalog was consulted and
composition-over-existing-primitives was attempted *first*; per [RES-018] no new cross-cutting primitive is
proposed without demonstrating composition cannot cover the case. The cleanest gaps need **no new primitive at
all**.

### Prerequisite — resolve the §7.1 open questions / defects (these GATE the wins; they are not wins themselves)

- **GAP-I — fix the dormant, non-compiling `Buffer.Linear: Collection.\`Protocol\`` conformance** (§7.1.2). It is
  commented out over a `Collection.Protocol+defaults.swift` lifetime-dependence error, with the Collection deps
  commented out in the manifest. Until it compiles, the buffer layer has **no** Collection face, and any
  buffer-level Collection consumer (and the §2.2 Indexed-dedup plan) is blocked. **Recommendation:** treat as a
  Collection-spine defect to resolve (likely a `@_lifetime` / `_read`-accessor fix on the `count`/`subscript`
  defaults) before relying on a buffer Collection face; route via `/issue-investigation` if it is a toolchain
  interaction. Prerequisite, not a derive-for-free gain.

- **GAP-J — delete `Collection.Indexed` (VERIFIED 2026-06-02; completes the detachment doc's Step B).** The
  question "delete or keep?" is **resolved: delete.** The protocol is redundant dead weight (§7.1.1): it is a
  strict subset of `Collection.Protocol`, every one of its 6 conformers also conforms `Collection.Bidirectional`
  (→ `Collection.Protocol`), the ~Copyable `Collection.Protocol` path compiles green (build of
  swift-array-primitives at HEAD), and there are zero generic constraints, refining protocols, or external
  product deps on it. Its docstring's reason-to-exist ("`Collection.Protocol` forces Copyable") is stale —
  contradicted by `Collection.Protocol.swift:58-75`. **Recommendation (mechanical, ~6 edits + a 3-package build):**
  (a) remove the 6 redundant `: Collection.Indexed {}` conformance extensions (Array/Static/Small/Fixed in
  swift-array-primitives; Queue.DoubleEnded/.Fixed in swift-deque-primitives); (b) delete the `Collection Indexed
  Primitives` target + product in swift-collection-primitives and drop the `@_exported public import
  Collection_Indexed_Primitives` from the umbrella `exports.swift` and the umbrella's dep; (c) build
  swift-collection-primitives + swift-array-primitives + swift-deque-primitives green to confirm
  (`[RES-024]`-style: the executor reproduces before landing). No new primitive; pure subtraction. **Independent
  of GAP-I** — `Buffer.Linear` does not conform `Indexed`, so this can land first. (The `Collection.Indexed`
  docstring's stale hierarchy diagram disappears with the protocol; the `count`/`isEmpty`/`formIndex` it provided
  already exist on `Collection.Protocol`.)

- **GAP-K (doc-fix) — correct the stale stdlib-bridge markers** (§7.1.4) so the on-disk rationale matches the
  live `Collection.\`Protocol\`: Iterable` hierarchy and the `Sequenceable` rename. Cheap; restores "the code
  documents the right design."

(The demangle-crash iterators of §7.1.3 are already an open `/issue-investigation` toolchain item, not a new
recommendation here — but the per-variant hand-writing they cause will not dedup until that crash is fixed.)

### Recommended — no new primitive

- **GAP-A — Array/Stack span-derived `Equatable`/`Hashable` (the sharpest actionable gap).** Array and Stack
  conform `Memory.Contiguous.\`Protocol\``; the `Equation.\`Protocol\`+Swift.Span` and `Hash.\`Protocol\`+Swift.Span`
  bridges already exist and Set.Ordered already uses them. **Recommendation:** add the per-type opt-in
  conformances (`Element: Equation.\`Protocol\``/`Hash.\`Protocol\``) so `==`/`hash` derive over `span`, exactly
  as Set.Ordered does. Pure composition over existing bridges — [DS-020]/[RES-018] clear (no new surface). *Caveat
  for the implementer (out of scope here):* element-wise span equality is the correct semantics for an ordered
  sequence; confirm per-type that ordered-equality is intended before opting in (Set membership equality is a
  different contract and is correctly Set.Ordered's own).

- **GAP-B — `Memory.Contiguous.\`Protocol\`` (D) defaults for `count`/`subscript`/bounds.** Add intra-protocol
  defaults `var count: Int { span.count }`, `subscript(_:) -> Element { span[i] }` (borrowing addressor →
  `~Copyable`-safe), `isEmpty`, bounds checks — all derivable from the single `span` requirement, and `count` is
  genuinely a memory concern (not iteration). This dedups the *stored* counts on `Memory.Contiguous` /
  `Memory.Contiguous.Borrowed` and touches neither the iterator package nor memory's identity. (D) enrichment;
  no new primitive.

- **GAP-E — drop the redundant `Buffer.Arena.isEmpty`.** Arena's `Count` is the element domain, so it is inside
  the constrained (D) `isEmpty` extension; its own witness is redundant (live-slot count == 0 iff empty), exactly
  as Linear/Linked correctly omit theirs. Cleanup; subtraction.

### Recommended — reshape an existing core (no new package)

- **GAP-C — the `Storage.\`Protocol\``-keyed `span` bridge (§3.4, two-part).** `Storage.Heap` and `Storage.Inline`
  hand-write structurally-identical `span` and `withUnsafeBufferPointer` getters (4 copies today; ~5× once
  Pool/Arena/Slab land in their sibling packages). The §3.4 default is *sound only* if `Storage.\`Protocol\``
  first gains an **initialization-count requirement** — the span length is the *initialized* count, not
  `capacity`; a `capacity`-length span would expose uninitialized slots. **Recommendation (two-part):** (a) add
  `var initialized: Index<Element>.Count` (or equivalent) to `Storage.\`Protocol\``; (b) add the (C) bridge
  `extension Memory.Contiguous.\`Protocol\` where Self: Storage.\`Protocol\`` supplying `span` (and
  `withUnsafeBufferPointer`) from `pointer(at:.zero)` + the init-count, gated to contiguous single-region
  disciplines. This reshapes an existing domain-owned protocol — [RES-018] case (b)/(c), not a new cross-cutting
  primitive; the duplication on disk is the justification.

### Recommended — generalize the contiguous bridge

- **GAP-D — a piecewise / N-segment iteration bridge.** A ring is ≤ 2 contiguous segments; `Buffer.Ring.Segments`
  hand-writes the 2-way routing (×3 variants) while already reusing `Iterator.Chunk` per segment. A bridge keyed
  on a `segments → some Sequence<Span<Element>>` capability would vend the routing free and is the natural
  generalization of the contiguous (single-span) bridge. **Recommendation:** scope a small design note; honor
  [DS-020] by demonstrating composition over `Iterator.Chunk` first (the routing is the only irreducible part).
  Not a regression today (the hand-written form is correct and maximally reuses the leaf); the obvious next bridge.

### Recommended — ecosystem-wide, coordinate with the fan-out

- **GAP-G — one generic `Swift.Sequence` interop bridge.** Span-primitive ADTs have no `Swift.Sequence`
  conformance (deleted in the SE-0516 migration). The derive-for-free shape is a *single* generic
  `extension X: Swift.Sequence where Element: Copyable`, vended once and settled ecosystem-wide at/before the ×16
  fan-out (already on the iteration arc's deferred list). **Recommendation:** track it there; do not re-derive.

### Deferred-irreducible — candidate WRITE-axis core, gated

- **GAP-F — a buffer-mutable capability protocol.** `insert`/`remove`/`append`/`clear` are written per-variant
  because there is no uniform buffer-mutable core (`Hash.Table.\`Protocol\`` is read-only). A
  `Buffer.Mutable.\`Protocol\`` (uniform `append`/`remove`/`count`) is a *plausible* WRITE-axis core — but it is
  gated by [DS-020]/[RES-018] (demonstrate composition first), and **even if it existed the hot mutating
  witnesses stay concrete-Base** by the specialization boundary (cross-layer §3.3) — only *cold* composition
  would dedup. **Recommendation:** frame as a candidate for the write axis, explicitly bounded by the
  specialization boundary; do **not** propose it lightly. This is the corpus's one honestly-irreducible
  derive-for-free wall.

### The meta-gap

- **GAP-H — the container tier has no `[PREFIX-NNN]` rule.** The scalar tier's derive-for-free is *named and
  normative* ([API-NAME-001c]); the container tier's lives only in the framework doc and the as-built bridges.
  Per the workspace memory-write guardrail (a rule that reads as a `[PREFIX-*]` requirement belongs in a skill),
  several rules in this doc already read as requirements: the (R)-vs-(C) identity rule, the four-part
  warranted-refinement test, the one-bridge-per-capability shape, the with*-elimination corollary, the
  demand-gated bridge test. **Recommendation:** promote the container-tier model to a sibling rule of
  [API-NAME-001c] — e.g. **`[DS-0NN]` / `[API-NAME-001d]` *Per-Capability Composition Bridge*** — stating the
  one-bridge-per-capability shape, the warranted-refinement test, and the HAS-A/IS-WRAPPED-BY duality with the
  scalar tier. Route it through `skill-lifecycle`. (This doc supplies the rationale; the promotion is a separate,
  authorized step.)

### Anti-recommendations (dead-ends — do not re-derive)

- **`associatedtype Storage` on `Buffer.\`Protocol\`` (T1).** Anti-precedented across every stabilized ecosystem
  (buffer-storage prior-art); rejected in cross-layer §6.5. Contiguity is a **capability** (`span`, the T4 form),
  composed by (C), not a possessed storage *type*.
- **Re-baking `forEach` (or any iteration/algebra) onto a core's requirements.** Re-introduces the
  identity/concern conflation the model removes (cross-layer §4.3).
- **An `Iterator.Borrow` element-wrapping iterator.** Rejected by SE-0516; the relevant type was *deleted*
  2026-05-31, not parked.
- **A universal meta-protocol unifying the scalar recipe across domains.** Blocked by [IMPL-102] (overlapping
  conditional conformances). The container tier's bridges are likewise per-capability by necessity, not by choice.

---

## 9. The specialization boundary (the constraint that makes "compose" free)

Restated because it is load-bearing for §6.1 and for every gap recommendation. A derived operation is safe **as a
protocol-extension default** iff, when the conformer is concrete, the optimizer monomorphizes it to **0
`witness_method`** in release across a module boundary (cross-layer §3.3, proven by the
`storage-protocol-specialization` and `property-inout-specialization` experiments and the Set.Ordered pilot —
including the finding that `where Self: P & Q` multi-protocol composition costs nothing extra). The corollary
draws the REQUIRES/PROVIDES line:

- **Hot *read* primitives** (`span`, `pointer(at:)`, `contains`, `count`) are **requirements** — concrete on the
  leaf, so direct calls never touch the protocol and generic calls specialize.
- **Hot *mutating* ops** (`insert`/`remove`/`append`) are **concrete-Base accessors**, *not* protocol-dispatched
  (the protocol-`Base` `Property.Inout` `@inlinable` borrow-init path is a documented miscompile,
  swiftlang/swift#81624) — this is the hard floor under GAP-F.
- **Cold / derived ops** are **(D) defaults or (C) bridges** — they specialize away.

Because (R) and (C) both land at 0-witness, the compose-vs-refine choice is *semantic*, never performance — the
reason §6.1's "compose by default" carries no cost.

The iteration arc's **D1–D5 acceptance rubric** (unified-iteration §6.6) is the reusable lens for any new bridge
or core proposed under this model: D2 — `~Copyable`/`~Escapable` carried, never degraded; D3 — 0-witness on hot
ops *and* the protocol-topology boundary respected (the capability vehicle is `Memory.Contiguous`/`Iterable`, not
a higher core); D5 — walls escalate, not retreat (no caving to a Copyable gate).

---

## 10. Cross-language prior art (Tier 3, [RES-021])

The model's two structural choices — *capability-not-storage-type* and *compose-orthogonal-not-refine* — are the
cross-ecosystem consensus, not bespoke.

- **Storage as a capability, not a type (the T4 verdict).** No stabilized ecosystem exposes the storage object as
  an associated/member TYPE (T1). C++20 `contiguous_range` requires `ranges::data(t)` *yield* a pointer (a
  capability); Swift `Span`/SE-0237 `withContiguousStorageIfAvailable` are scoped capabilities (the would-be
  `ContiguousStorage` protocol was *deferred* by SE-0447 over the exact `~Copyable`/`_read`-accessor wall the
  institute hit); Rust exposes `Deref<Target=[T]>`/`as_slice` (a slice *view*) and keeps `Vec`'s fields private;
  the one T1 attempt (Rust's Storage API) is unstable after 2+ years and exposes an opaque `Handle`, not a
  pointer-vending storage object. The institute's `Memory.Contiguous.\`Protocol\`` (`span` capability) is the T4
  form `[Verified: 2026-06-02 — buffer-storage-associatedtype-prior-art.md]`.

- **Iteration orthogonal to the collection, composed not refined.** Rust splits `IntoIterator` from the
  collection; C++ STL set algebra is *free functions* over iterator ranges; Haskell `Foldable` is a separate
  class from `Data.Set`; SE-0516 keeps `BorrowingIteratorProtocol` orthogonal to `IteratorProtocol` (World-B
  keep-and-lend vs World-A give-away) — the *exact* `Iterable` / `Sequenceable` split. And the one place the
  stdlib conflates them (`Collection: Sequence`) is "an artifact of a Copyable-only world" that the institute
  *detached* (collection-sequence-protocol-detachment.md). The single refine the institute *keeps* —
  `Collection.\`Protocol\`: Iterable` — mirrors stdlib `Collection: Sequence` but on the *multipass-borrowing*
  axis where the identity actually holds.

- **The crux that forces the shape.** `Span<Element>` admits `Element: ~Copyable` but **not** `~Escapable`
  (`Span.swift:25-29`): folding a `Span` hook onto a single iterator would force the whole protocol's `Element` to
  `Escapable`, destroying `~Escapable` scalar iteration — so bulk iteration *must* live as a property of
  contiguous storage (`Memory.Contiguous.span`) and compose onto the iterator, *not* refine into it
  (bulk-span-iteration-fold-vs-separate.md). The "nobody chunks" empirical finding (every call site passes
  `Cardinal(UInt.max)`) confirms the bulk path is in practice "give me the whole span" — i.e. the memory
  capability.

**Contextualization ([RES-021]):** every surveyed system separates iteration from the container identity and
expresses contiguity as a yielded capability. The institute's distinctive choice — a *typed* capability protocol
per layer carrying its derivations as specializing defaults, with a single sanctioned identity-refine — is *more*
structured than any surveyed system while preserving their universal orthogonality. No gap; a deliberate,
stronger design.

---

## 11. Outcome

**Status: RECOMMENDATION.**

The unified derive-for-free model for the data-structure stack is:

1. **Each layer exposes one minimal capability core** in the ⟨REQUIRES: irreducible primitives⟩ → ⟨PROVIDES:
   core-only derivations⟩ normal form. `Memory.Contiguous.\`Protocol\`` = `span`; `Storage.\`Protocol\`` =
   `{capacity, pointer(at:)}`; `Buffer.\`Protocol\`` = `count`; the ADT cores add their own identity contract
   (membership for Set; index for Collection).

2. **Every derived family is composed in via one bridge per CAPABILITY, keyed on the capability, never
   per-ADT** — `extension <Capability> where Self: <Concern> { … }`. The canonical instance is the
   `memory→Iterable` bridge that vends the iterator + terminal suite over `span` to every contiguous conformer
   with an empty conformance body. Derive-for-free is *bounded* to the capability-bearing conformers; types
   without the capability (non-contiguous storage) hand-write the irreducible part — by *design* (no span ⇒ no
   span bridge), though some current witnesses are provisional toolchain-bug workarounds (§7.1).

3. **Compose by default; refine only when the four-part warranted-refinement test passes** (identity ∧
   conformer-set ∧ expressibility ∧ cross-package mechanics). The choice is *free* at the specialization boundary,
   so it is decided on semantics alone. The *only* warranted refine in the stack is
   `Collection.\`Protocol\`: Iterable` — and even it keeps the iterator on the compose edge (the index half is
   the collection's declared identity; the iteration half is refined-in + bridge-vended).

4. **The container tier (HAS-A) and the scalar tier (IS-WRAPPED-BY, [API-NAME-001c]) are two faces of one law.**
   Both chose compose-not-refine — the scalar tier for a *mechanical* reason (refinement blocks recursive
   `Tagged`), independently corroborating the container tier's *semantic* choice.

The model **extends** the approved cross-layer framework from one concern to the whole stack, **consolidates** the
two tiers, and **catalogs** the gaps (§8). But it is a *destination*, not a description of a finished stack
(§7.1): the cleanest derive-for-free wins (Array/Stack equality-over-span, GAP-A; `Memory.Contiguous`
count/subscript defaults, GAP-B; Arena cleanup, GAP-E) need **no new primitive**; the `Storage→span` bridge
(GAP-C) reshapes an existing core; the buffer-mutable core (GAP-F) is honestly deferred-irreducible and gated;
the model itself should be **promoted to a named rule** (GAP-H); and a set of **prerequisites/defects** (the
non-compiling `Buffer.Linear` Collection conformance, GAP-I; the unsettled index-root, GAP-J; stale docs, GAP-K)
must be resolved before the stack actually *is* what the model describes.

**Recommended sequencing** (DESIGN/RATIONALE only — execution sequenced by the principal; nothing landed):

0. **Cleanups/prerequisites first.** Land **GAP-J** now — *verified: delete `Collection.Indexed`* (pure
   subtraction, independent of everything else); apply the **GAP-K** doc-fix alongside. Then resolve **GAP-I**
   (make `Buffer.Linear: Collection.\`Protocol\`` compile) — the one genuine blocker for a buffer-level Collection
   face. Until GAP-I lands, the Collection layer is not fully in the state the model assumes.
1. Land **GAP-A** (Array/Stack `Equatable`/`Hashable` over the existing `Span` bridges) and **GAP-B**
   (`Memory.Contiguous.\`Protocol\`` `count`/`subscript`/bounds (D) defaults) — both pure composition, the
   highest-leverage subtraction, and independent of the Collection-layer prerequisites.
2. **GAP-C** as a two-part Storage-arc item (add the init-count requirement, then the `span` bridge), sequenced
   after the buffer-dedup Lever-1 unblock noted in cross-layer §7; **GAP-E** as a one-line cleanup alongside.
3. **GAP-H** — promote the container-tier model to a `[DS-*]`/`[API-NAME-001d]` rule via `skill-lifecycle`, as the
   sibling of [API-NAME-001c]; apply the normal form as the audit lens for `Dictionary.\`Protocol\`` and future
   collection-tier cores (cross-layer §11 step 3).
4. **GAP-D** (piecewise bridge) and **GAP-F** (buffer-mutable core) as gated design notes when their conformer
   pressure materializes; **GAP-G** tracked on the iteration fan-out.

---

## References

### Internal research (governs per [RES-019]; cite/extend, do not duplicate)
- `swift-institute/Research/cross-layer-capability-protocol-model.md` v1.3.0 — the model generalized here (§3.2
  normal form + (R)/(C)/(D); §3.3 specialization boundary; §11 step-3 authorization).
- `swift-institute/Research/collection-sequence-protocol-detachment.md` v1.1.0 — the original orthogonality
  precedent + the demand-gated bridge test.
- `swift-institute/Research/set-ordered-capability-composition.md` v1.1.0 — the realized inherits-vs-writes ledger
  + the deferred-axes catalog (extended into §8).
- `swift-institute/Research/unified-iteration-design.md` v2.2.0 — the iteration authority + the D1–D5 acceptance
  rubric (coordinated-with, not reopened).
- `swift-institute/Research/buffer-storage-associatedtype-prior-art.md` v1.0.0 — the T1/T2/T3/T4 taxonomy
  (anti-T1 guardrail).
- `swift-institute/Research/bulk-span-iteration-fold-vs-separate.md` v1.0.1 — the `Span<~Copyable>`-not-`~Escapable`
  crux + capability-belongs-on-its-layer.
- `swift-institute/Research/iterable-span-primitive-implementation-plan.md` v1.0.0 — the 13-free/18-scalar/3-piecewise
  cost model (derive-for-free is bounded).
- `swift-institute/Research/iterable-se0516-alignment.md` v1.0.0 — SE-0516 ↔ institute mapping (World-A/World-B).
- `swift-institute/Research/byte-protocol-capability-marker.md` v1.1.0 — the recursion-vs-refinement constraint
  principle / [IMPL-102] (scalar-tier foundation).
- `swift-institute/Research/mutator-orthogonal-vs-refinement-stance.md` v1.0.0 — the conformer-set test + the
  three failure modes of gratuitous refinement.
- `.../property-tagged-semantic-roles.md` v1.1.0 — the Group A/B taxonomy + fibration framing.
- `swift-institute/Research/self-projection-default-pattern.md` v1.0.0 — the projection-of-Self vs
  attribute-of-conformer axis (classifies `Memory.Contiguous` as element-containment).
- `swift-institute/Research/sequence-storage-integration-analysis.md` v2.0.0 — durable separation-of-concerns
  rationale (consolidated; stale vocabulary dropped).
- Reflections: `2026-06-01-finish-the-fan-out-collection-iterable-refine-edge.md` (the just-landed precedent),
  `2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` ([IMPL-102] provenance).

### Source (verified on disk 2026-06-02 — read the real types per [RES-023])
- `swift-memory-primitives/.../Memory.ContiguousProtocol.swift:77-93`,
  `.../__Memory_Contiguous_Borrowed_Protocol.swift:41-56`, `.../Memory.Contiguous.swift:71-124`.
- `swift-memory-iterator-primitives/.../Memory.Contiguous+Iterable.swift:31-62` (the canonical (C) bridge).
- `swift-storage-primitives/.../Storage.Protocol.swift:20-37`;
  `.../Storage.Heap+Memory.Contiguous.Protocol.swift:29-64`, `.../Storage.Inline+….swift:30-84` (GAP-C duplication).
- `swift-buffer-primitives/.../Buffer.Protocol.swift:22-107`;
  `swift-buffer-linear-primitives/.../Buffer.Linear+Iterable.swift:17-19`, `.../Buffer.Linear+Memory.Contiguous.Protocol.swift:13`.
- `swift-iterator-primitives/.../Iterable.swift:35-57` + `Iterable+{ForEach,Contains,First,Reduce}.swift`;
  `.../__IteratorChunkProtocol.swift:42-78`; `.../Iterator.Chunk.swift`, `.../Iterator.Materializing.swift`.
- `swift-sequence-primitives/.../Sequenceable.swift:90-122`, `.../Sequence.Borrowing.Protocol.swift:45-78`.
- `swift-collection-primitives/.../Collection.Protocol.swift:58` (the (R) edge, `3cc21cc`),
  `.../Collection.Protocol+defaults.swift`, `.../Collection.Bidirectional.swift:37`, `.../Collection.Indexed.swift:72`.
- `swift-array-primitives/.../Array.Conformances.swift:55-63`, `.../Array ~Copyable.swift:27-65` (§7 verdict);
  `swift-set-ordered-primitives/.../Set.Ordered+Hash.Protocol.swift:16-29` (GAP-A exemplar);
  `swift-queue-primitives/.../Queue+Conveniences.swift` (the non-Collection contrast).
- `swift-byte-primitives/.../Byte.Protocol.swift:87-225`, `.../Tagged+Byte.Protocol.swift:30-59` (scalar tier).

### Skills
- `[API-NAME-001c]` Per-Domain Capability-Marker Protocol (code-surface) — the scalar-tier dual.
- `[DS-001]`, `[DS-005]`, `[DS-006]`, `[DS-020]`, `[DS-021]` (ecosystem-data-structures).
- `[RES-018]`, `[RES-020]`–`[RES-023]` (research-process); `[IMPL-102]` (implementation);
  `[MOD-035]` (modularization — scope/identity); `[MEM-COPY-004]` (memory-safety).

### Language / external
- SE-0447 (Span), SE-0237 (`withContiguousStorageIfAvailable`), SE-0256 (ContiguousCollection — *Rejected*),
  SE-0427 (Noncopyable Generics), SE-0335 (Constrained existentials), SE-0516 (BorrowingIteratorProtocol analog).
- C++20 `std::ranges::contiguous_range`; Rust `Vec`/`Deref<Target=[T]>` + the unstable Storage API; Haskell
  `Data.Set`/`Foldable`.
