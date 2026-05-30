# Collection.Index ~Escapable Consumer Fallout

<!--
---
version: 1.3.0
last_updated: 2026-05-27
changelog: "v1.1.0 (2026-05-27) — principal correction: c1 (revert to concrete typealias) REJECTED — it regresses BOTH the associatedtype (custom index domains) and ~Escapable/~Copyable admission, contradicting the maximal-permissive-foundation pattern. True blast radius is one consumer (Input.Slice, 5 files), so the decision reduces to one token in the base bound: (a)-narrow (keep `& ~Escapable`, migrate Input.Slice) vs strong-bound (`& Escapable`, keep associatedtype). §1–§4 analysis + quantification unchanged; Outcome conclusion revised. v1.0.0 preserved in git history. v1.2.0 (2026-05-27) — added §Both-Ways + Forward Impact (contract-first, per the principal's methodological correction that excludes transitional consumer-cost from the decision); supply-side fact: ZERO ~Escapable-index conformers, custom Escapable domains have real supply; recommendation updated from v1.1.0 (a)-narrow → REQUIRE Escapable on the contract (keep associatedtype, drop the ~Escapable suppression). KEEP-vs-REQUIRE token remains the principal's. v1.3.0 (2026-05-27) — PRINCIPAL DECISION: KEEP ~Escapable; 43d1fb7 STANDS (no revert). Escapable is an operation-level requirement (escape-operations carry it), not intrinsic to Index; Copyable floor via V4 stands; matches ecosystem maximal-support. Supersedes the v1.2.0 REQUIRE recommendation. Status RECOMMENDATION → DECISION. Consumer migration: Input.Slice pins where Base.Index == Index<Base.Element>; execution pending coordination (input's tree is mid-W1 Sequence-migration, owned by the World-B chat)."
status: DECISION
tier: 2
scope: cross-package
trigger: swift-collection-primitives@43d1fb7 (2026-05-26) changed Collection.`Protocol`.Index from a concrete typealias to a `Comparison.`Protocol` & ~Escapable`-admitting associatedtype. The default is preserved but the bound weakened; generic consumers over `Base: Collection.Protocol` lost the concrete `Index<Element>` API and the Escapable/Sendable guarantee. Investigation dispatched via HANDOFF-collection-index-escapable.md to quantify the fallout and decide (a) keep+migrate vs (c) reconsider the bound, from first principles.
preceded_by:
  - swift-institute/Research/parser-collection-protocol-migration.md (DECISION v2.1.0, 2026-02-13) — established Input.Slice<Base: Collection.Protocol> as the canonical generic consumer; this doc measures what 43d1fb7 did to it.
  - swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md (DEFERRED-TOOLCHAIN-PRUNED v1.2.0, 2026-05-09) — the sibling ~Escapable widening on Collection.Protocol *Self* (forEach/count); precedent for pruning hypothetical ~Escapable widenings.
  - swift-index-primitives/Research/Strideable Index Design.md (DECISION v1.0.0, 2026-01-28) — index = position = storable magnitude-from-zero; Strideable-appropriate.
status_note: RECOMMENDATION — not implemented. The `ask:` ground rule (HANDOFF-collection-index-escapable.md) requires principal confirmation of (a) vs (c) + the plan before any consumer edit or `Collection.Index` change. This doc is the decision input; it does not authorize execution.
---
-->

## Context

`swift-collection-primitives@43d1fb7` (2026-05-26, HEAD of `main`, **unpushed — ahead of origin/main by 2**) changed the `Index` member of `Collection.Protocol` from a fixed concrete typealias to a `~Escapable`-admitting associatedtype:

```diff
- typealias Index = Index_Primitives.Index<Element>
+ associatedtype Index: Comparison.`Protocol` & ~Escapable = Index_Primitives.Index<Element>
```

(`Collection.Protocol.swift:52`; commit `43d1fb7`). The same commit added `@_lifetime(copy i)` to `index(after:)` (`:73`), `where Index: Swift.Comparable` to `Collection.Slice.Protocol` (`Collection.Slice.Protocol.swift:32`), and `where Base.Index: Escapable` to the Min/Max/ForEach index-returning algorithms (`Collection.Min+Property.Inout.swift:14` and siblings).

The commit's rationale (in-message + `Experiments/collection-index-escapable-lifetime`, commit `197c807`): let conformers supply **custom index domains** (storage-slot positions, e.g. the future `Buffer.Linked` / `Buffer.Slab.Inline` "oddballs"); the default keeps `Index<Element>`, so existing conformers are unchanged.

**The fallout is real:** the *default* is unchanged (so **conformers** that adopt `Collection.Protocol` with the default `Index<Element>` are source-compatible — `collection-primitives` itself builds green), but the *bound* is now weaker. **Generic consumers** over `Base: Collection.Protocol` see `Base.Index` as only `Comparison.Protocol & ~Escapable`, losing the concrete `Index<Element>` API (`init`, `init(bitPattern:)`, `+`, `Index<Element>.Count(_)` conversion) and the `Escapable` / `Sendable` guarantee.

**This arc is independent of the World-B / Sequence.Protocol→Sequenceable rename (W1) arc** (`HANDOFF-data-structure-iteration-arc.md`). They are two distinct breakages on `main`. This doc quantifies and disentangles them; it does NOT address the Sequence rename. W1 holds the `Collection`-consuming packages pending this decision.

## Question

Is a `~Escapable`-admitting **base** `Collection.Protocol.Index` the semantically correct default — given that every realized consumer wants a concrete, `Escapable`, `Sendable`, Ordinal-arithmetic-bearing index, and no realized consumer wants a `~Escapable` one — or does the `~Escapable` (and custom-index) case belong as an **opt-in** that does not tax every generic consumer?

Concretely: **(a) keep** the `~Escapable` `Index` and migrate generic consumers, or **(c) reconsider the bound** (a stronger bound that retains the consumer-needed API, or a separate opt-in variant), with the fallout quantified first and the change's experiment-backed rationale engaged — not a casual revert.

## Methodology

- **Toolchain:** Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), macOS 26.2 (build 25C56), arm64. (Matches the backing experiment's stated toolchain.)
- **Baseline build:** `swift build --package-path <pkg>` against `collection-primitives` at HEAD `43d1fb7`, for the ~10 candidate consumers named in the handoff, run serially per `[feedback_serial_swift_builds]`.
- **Resolution provenance (verified, per `[feedback_check_package_resolved_before_compiler_bug_claim]`):** most consumers depend on collection-primitives via `.package(path: "../swift-collection-primitives")` → they compile against the local HEAD `43d1fb7` directly. `input-primitives` uses `.package(url: …, branch: "main")`; its `Package.resolved` pins collection-primitives to revision `43d1fb7` (branch `main`), and `~/Library/.../mirrors.json` maps the URL to the local path — so input also reflects `43d1fb7`. No stale-resolution confound.
- **Working-tree caveat (per `[feedback_never_revert_or_checkout]` — not disturbed):** `input` carries 3 uncommitted W1 files (`Package.swift`, `Input.Slice+Collection.Slice.Protocol.swift`, `exports.swift`); `infinite` carries 7. Builds compile the working tree (source untouched); the Collection.Index error classes reported below appear in pristine files (`Input.Slice.swift`, `Input.Slice.Error.swift`) outside the WIP set, so the attribution is robust. `buffer-linear` is on branch `spike/buffer-storage-dedup` with its collection dep commented out → decoupled, excluded.
- **Attribution method:** errors classified by **distinct message text**, not line counts (Swift's multi-line diagnostics inflate naive grep counts). Collection.Index-class ≡ mentions of `Base.Index` losing `Ordinal.Protocol` / `init` / `+` / `Tagged<_,Cardinal>` conversion / `Escapable` / `Sendable`. Sequence-rename-class ≡ `Sequenceable` / `'Protocol' is not a member of struct 'Sequence'` / `ambiguous type name 'Iterator'`.

## Quantified Fallout

`collection-primitives@43d1fb7` itself: **`swift build` exit 0, 0 errors** (confirms the commit's "builds green" claim — the change is source-compatible for conformers).

| Consumer | Build | Collection.Index errs | Sequence-rename errs | Attribution |
|----------|-------|----------------------:|---------------------:|-------------|
| **input**-primitives | ❌ | **66** (all in `Input.Slice*`) | 0 | **ROOT Collection.Index consumer** (handoff's "75"¹) |
| dictionary-primitives | ❌ | 74 (all in `Input.Slice*`) | 0 | transitive — `.package(path:"../swift-input-primitives")` |
| infinite-primitives | ❌ | 66 (all in `Input.Slice*`) | 0 | transitive via input² |
| queue-primitives | ❌ | 74 (all in `Input.Slice*`) | 0 | transitive via input |
| array-primitives | ❌ | **0** | 20 | Sequence rename (W1) via buffer-linear dep |
| cache-primitives | ❌ | **0** | 32 | Sequence rename (W1) via buffer-linear dep |
| heap-primitives | ❌ | **0** | 32 | Sequence rename (W1) via buffer-linear dep |
| slab-primitives | ❌ | **0** | 10 | Sequence rename (W1) — own `Buffer.Slab.Inline` files |
| stack-primitives | ❌ | **0** | 14 | Sequence rename (W1) via buffer-linear dep |
| buffer-linear-primitives | — | — | — | decoupled (spike branch; collection dep commented out) |

¹ The handoff's "75 errors" is the raw `error:`-line count (includes cascade + `error: cancelled` orchestration lines); 66 is the distinct Collection.Index-class count. Same five files either way.
² `infinite` additionally has **one own potential site** — `Infinite.Cycle.Iterator` stores `var index: Base.Index` (`Infinite.Cycle.swift:79`) under a `where Base.Index: Sendable` conditional Sendable conformance (`:108`). Its build failed at the input dependency before reaching its own code, so this site is **unverified** (per `[RES-023]`); it is at most one additional file, and only if `Infinite.Cycle`'s `Base` is a `Collection.Protocol`.

**Net blast radius of the Collection.Index ~Escapable change: input-primitives' `Input.Slice` — one type family, five files.** Every Collection.Index-class error across all packages is in the same set: `Input.Slice.swift`, `Input.Slice.Error.swift`, `Input.Slice+Collection.Slice.Protocol.swift`, `Input.Slice+Input.Access.Random.swift`, `Input.Slice+Input.Protocol.swift`. dictionary / infinite / queue break **only because they build input transitively**; fixing input clears their Collection.Index errors. array / cache / heap / slab / stack have **zero** Collection.Index errors — they break on the **Sequence rename (W1)**, which is a separate arc.

### The casualty's shape (why it breaks)

`Input.Slice` already stores raw `Int` offsets and **reconstructs `Base.Index` on demand assuming it is the concrete Ordinal-backed `Index<Element>`** (`Input.Slice.swift:99–106`):

```swift
var _lower: Base.Index { Base.Index(_unchecked: Ordinal(UInt(bitPattern: _start))) }
var _upper: Base.Index { Base.Index(_unchecked: Ordinal(UInt(bitPattern: _end))) }
```

`Base.Index(_unchecked: Ordinal(…))` is `Index<Element>`'s initializer — it exists only because, pre-`43d1fb7`, `Base.Index` *was* `Index<Element>` concretely. The new bound (`Comparison.Protocol & ~Escapable`) provides none of it.

### Error classes (all in `Input.Slice`) — mapped to what 43d1fb7 bundled

| Class | Representative diagnostic | Caused by |
|-------|---------------------------|-----------|
| **A. Lost Ordinal index construction/arithmetic** | `init(bitPattern:) requires that 'Base.Index' conform to 'Ordinal.Protocol'`; `type 'Base.Index' has no member 'init'`; `operator '+' requires 'Base.Index' conform to 'Ordinal.Protocol'`; `cannot convert 'Base.Index' to 'Tagged<…, Cardinal>'` | **associatedtype-ification + minimal `Comparison.Protocol` bound** (Index no longer the concrete `Tagged<_,Ordinal>`) |
| **B. Lost Sendable** | `associated value of 'Sendable'-conforming enum 'Error' contains non-Sendable type 'Base.Index'` | **bound omits Sendable** |
| **C. Lost Escapable** | `'Escapable'-conforming enum 'Error' has non-Escapable type '(…Base.Index…)'`; `stored property '_upper' of 'Escapable'-conforming struct 'Iterator' has non-Escapable type 'Base.Index'` | **`& ~Escapable` admission** |
| **D. Downstream cascade** | `Input.Slice<Base> does not conform to 'Collection' / 'Equatable'` | classes A–C prevent the conformances |

The three causes are **separable**: A is the associatedtype + weak-bound axis; B is the dropped-Sendable axis; C is the `~Escapable` axis. This separation is the crux of the decision.

## Engaging the Experiment (the `fact:` ground rule)

The change is deliberate and experiment-backed (`Experiments/collection-index-escapable-lifetime`); reconsidering it is a real architectural call. What the experiment actually establishes:

- **It proves VIABILITY, not necessity or benefit.** The hypothesis was: does `@_lifetime(copy i)` on `index(after:)` let the storable-index contract (`formIndex(after: inout Index)`) typecheck for a `~Escapable`-admitting associatedtype? **CONFIRMED** — `ProtocolV2` compiles and the conformer runs (`traversed sum = 60`). The prior `/tmp` spike's "not viable" was an artifact of testing only `@_lifetime(borrow self)`. This is a genuine, correct finding: the bound *can* be declared and the formIndex default *does* typecheck.
- **But the conformer it exercises uses an `Escapable` index.** `IntBag.Index = SlotIndex`, and `SlotIndex` is a plain `struct: Comparison.Protocol` — **Escapable** ("the common case … a slot position", `main.swift:37–45`). The experiment never traverses a genuinely `~Escapable` index. It demonstrates the **associatedtype/custom-domain** capability with an **Escapable** custom index — which does **not** require the `~Escapable` relaxation at all.
- **`~Copyable` index is REFUTED** (`V4`: "subscripts cannot have noncopyable parameters yet"). So the change admits only `~Escapable` (still-Copyable) indices.
- **The change's own companions exclude `~Escapable` everywhere beyond the four bare requirements.** `Collection.Slice.Protocol` requires `where Index: Swift.Comparable` — its own comment: *"`~Escapable` / custom-domain indices are excluded from slicing by design."* Min/Max/ForEach index-returning algorithms each require `where Base.Index: Escapable` — their own comment: *"they return a *stored* index, which a `~Escapable` index cannot be."*

So within collection-primitives itself, a `~Escapable` index can participate **only** in the bare 4-member protocol (`startIndex`, `endIndex`, `subscript`, `index(after:)`) and **nothing else** — no slicing, no min/max/foreach-by-index, no storage in a consumer. That is a degenerate index.

## First-Principles Analysis

### 1. Semantic: an index is, essentially, a storable escapable coordinate

An index denotes a *position* that can be **detached from the collection and stored** — held across a loop, written back via `formIndex(after: inout Index)`, stored as slice bounds (`Input.Slice.sliceStart/sliceEnd`), returned from an algorithm (`min.index(by:) -> Base.Index?`), carried in an iterator (`Infinite.Cycle.Iterator.index`), or placed in an error payload (`Input.Slice.Error.invalidBounds(startIndex:endIndex:)`). A `~Escapable` value, by definition, **cannot** be stored in arbitrary, lifetime-unbounded locations. `~Escapable` therefore contradicts the essential nature of an index. The empirical corroboration is total: `~Copyable` index refuted; every storing/returning operation in the package already carries `where …: Escapable`; `Input.Slice`'s Error and Iterator both fail precisely because they store `Base.Index`. (`Strideable Index Design.md` independently models an index as a position/magnitude-from-zero — a value, not a borrow.)

### 2. Decompose/compose: the base must carry the common case; specializations opt in

`43d1fb7` bundles three separable changes (the A/B/C axes above). The `~Escapable` axis weakened the **shared base bound** to a degenerate `Comparison.Protocol & ~Escapable`, then forced every algorithm (`where Base.Index: Escapable`) and every generic consumer to re-strengthen it. That inverts decompose/compose: the base should carry what all conformers and consumers share; a specialization layers on top. Weakening the base to admit a case that no consumer uses and that every algorithm must immediately re-exclude taxes the common path for a hypothetical rare one.

### 3. The bound-tension is fundamental — the two goals belong in different protocols

There is **no single bound** that serves both the change's goal and the existing consumers:

- A bound weak enough for the experiment's `SlotIndex` (just `Comparison.Protocol`, only `==`/`<`) **breaks `Input.Slice`**, which needs Ordinal arithmetic (`+`, `init(bitPattern:)`, `Index.Count(_)` conversion).
- A bound strong enough for `Input.Slice` (Ordinal arithmetic + `init` + `Escapable` + `Sendable`) **excludes `SlotIndex`** (which has no Ordinal arithmetic) — defeating the custom-domain purpose.

They want opposite things. Decompose/compose's answer is therefore not "find the right single bound" but "**keep the strong base for the common consumers; make the minimal/custom-index case a separate opt-in**." (Note: `index-primitives` ships only `typealias Index<Element> = Tagged<Element, Ordinal>` — there is **no standalone "Index protocol"** today. A "stronger bound" within (c) is not a one-liner; it is a from-scratch protocol-design task.)

### 4. Cost realized; benefit unrealized; and the institute precedent

The cost (breaking the established `Input.Slice` / parser-input stack — `parser-collection-protocol-migration.md` made `Input.Slice` *the* canonical parser input) is **realized and quantified**. The benefit (custom index domains) has **zero realized consumers** — the commit message itself notes the motivating types are "blocked by the in-flight buffer-linear spike … array/queue unverified." This is the same shape as the sibling ~Escapable widening on `Collection.Protocol` *Self* (`escapable-protocol-foreach-count-view.md`), which was **DEFERRED-TOOLCHAIN-PRUNED** because the consumer path was hypothetical — except this Index change is *worse* on the cost axis: the forEach/count widening was source-compatible, whereas this one actively breaks consumers. Per `[RES-018]` / `feedback_correctness_and_evergreen`, ~Escapable adoption is judged on **structural correctness + evergreen, not consumer count** — and the structural case here fails (axis 1), independent of the (also-absent) consumer demand.

### 5. Why not (a) keep + migrate

Migrating `Input.Slice` to tolerate an abstract `Base.Index` is not possible without re-imposing the very guarantees the base dropped: it must constrain `where Base.Index: Escapable & Sendable & <Ordinal-arithmetic>` (or `where Base.Index == Index<Base.Element>`). Slicing *is* range arithmetic on indices; the parser-migration doc already records that `Collection.Protocol` "lacks slicing … and index arithmetic," which is exactly why `Collection.Slice.Protocol` exists with `where Index: Swift.Comparable`. So (a) reduces to "every generic consumer re-adds the constraint the base removed" — pure ceremony that yields consumers nothing and supports a `~Escapable` capability none of them use. That confirms the **base bound**, not the consumers, is the thing in the wrong shape.

## Both-Ways + Forward Impact (v1.2.0 — contract-first)

> **Methodological frame (principal's correction, honored).** `Collection.Protocol` was refactored but its consumers have **not** been migrated to the associatedtype world. Current-consumer breakage and counts (§Quantified Fallout; §5 above) are therefore a **transitional artifact** — they reflect code written for the *old concrete-Escapable* `Index`, not evidence about the correct contract. They are **excluded** from this decision. Consumers are things to be migrated **to** the chosen contract, not votes **for** it. (This supersedes the v1.1.0 lean, which rested on the now-excluded "blast radius = one consumer, migration is cheap" argument.)

> **The axis (precise).** `Index: Comparison.`Protocol` & ~Escapable` is a **suppression**: it *admits* both Escapable and `~Escapable` index conformers; it does not force non-escapable. So the choice is **KEEP `& ~Escapable`** (permissive base — admits `~Escapable` conformers) vs **REQUIRE Escapable** (restrictive base). The associatedtype is kept either way; the realized goal — *custom Escapable index domains* — is preserved by both.

### The core contract question

Is **exportability** — a position you can name, store, compare-while-both-live, return, and range over (i.e., escape its obtaining scope) — intrinsic to what a `Collection` index *is*? The detachment decision (`collection-sequence-protocol-detachment.md`, DECISION v1.1.0) made `Collection.Protocol` and `Sequence.Protocol` **orthogonal**: Collection = *indexed, multi-pass, subscriptable, borrowing* access; Sequence = *iterator, consuming/owned, single-pass*. **Honest reading:** that doc separates on **access mode** (indexed-borrowing vs iterator-consuming), was written with a **concrete Escapable** `Index` (its Option-B code shows `typealias Index = Index<Element>`), and never contemplated a `~Escapable` index — so it **neither requires nor forbids** exportable indices; the question is genuinely **downstream** of it, not settled by it. What it *does* establish: transient/consuming access already has a home (the Sequence/Iterator tier).

### Supply-side fact (the only current data that legitimately counts)

Grep of every `Collection.Protocol` conformer's `Index` across the ecosystem (46 conformances):

- **`~Escapable` index conformers: ZERO.** No type provides a `~Escapable` index. KEEP's `& ~Escapable` is, today, **pure speculative admission** — it widens the base to a conformer shape nothing supplies.
- **Custom *Escapable* index domains: real supply** — `Int` (Dictionary.Ordered, Deque, Set.Ordered, Path.Components), `Tagged<_, Ordinal>` (Pool.Bounded.Slot, Memory.Map, Darwin.Loader.Image), `Array<Element>.Index`. This justifies the **associatedtype** (custom domains) — but every realized domain is **Escapable**, so it does **not** justify the **`~Escapable` suppression** specifically.

The two halves of `43d1fb7` thus have opposite support: the associatedtype generalization is **demanded** (real custom-Escapable-index supply); the `~Escapable` suppression is **unsupplied**.

### Steelman — KEEP `& ~Escapable`

1. **Permissive-foundation idiom.** The ecosystem's standing pattern: base protocols admit `~Copyable`/`~Escapable` maximally; consumers constrain. Matches `Iterator.Protocol`'s `Element: ~Copyable & ~Escapable`.
2. **Layering coherence.** The *base* `Collection.Protocol` (startIndex/endIndex/subscript/index(after:)) needs only *bare indexed traversal*, which a `~Escapable` index satisfies within a scope (the experiment proved `formIndex(after: inout)` typechecks under `@_lifetime(copy i)`). Export-requiring operations live in **refinements** — `Collection.Slice.Protocol` already gates `where Index: Swift.Comparable` (⟹ Escapable). "Base permits, refinement constrains" is structurally clean.
3. **Loosening is foundational.** Admitting `~Escapable` now is non-breaking; requiring Escapable now and admitting `~Escapable` later is a breaking protocol change. The asymmetry favors keeping the door open.
4. **Future shapes.** A borrowed/handle/scoped-cursor index (e.g., a bounds-checked cursor into mapped memory, valid only within the borrow) could offer full *within-scope* indexed random access — more than a Sequence — while being `~Escapable`.

### Steelman — REQUIRE Escapable

1. **Exportability is the index's defining capability over a cursor.** The operations that make an index *useful and distinct from a consumable cursor* — `Range<Index>` (two positions live as a stored value), slicing, returning a found position (`firstIndex` / `min.index`), stashing a checkpoint — **all require escape**. An index that cannot escape has no capability a borrowing iterator lacks; its "index-ness" is **vestigial**. (Comparison `<` is in the bound, but borrowing `<` needs no escape — so even the bound's own ordering doesn't rescue a non-exportable index into usefulness.)
2. **The language already treats `Index` as contract-bearing, not payload.** V4 (~Copyable Index) is **REFUTED** — "subscripts cannot have noncopyable parameters." `Element` freely admits `~Copyable & ~Escapable`; `Index` admits *neither* cleanly (`~Copyable` refused outright; `~Escapable` only degenerately). So `Index` is **not** a free-suppression site, and the `Element` analogy powering KEEP-#1 does not transfer.
3. **`Element` ≠ `Index`.** `Element` is *produce-and-discard* — the protocol places no storage obligation on it, so `~Escapable` is free. `Index` is the *coordinate the protocol's surface is parameterized on* (`subscript(Index)`, `index(after:) -> Index`, `Range<Index>`): producing and consuming index **values** is the protocol's job, so exportability is implicit in "value-typed coordinate." The maximal-permissive idiom is right for the payload, mis-applied to the coordinate.
4. **The decomposition already homes the foreclosed shape.** A `~Escapable`/scoped "index" is transient-position access — which the detachment decision routes to the *Sequence / borrowing-iterator* tier, not Collection. Admitting it at `Collection` muddies the very orthogonality the detachment established. Nothing is lost: that shape has a home.
5. **Reconciliation with maximal-support (not a rejection of it).** The ecosystem holds maximal-permissive-base because suppression *usually enables real conformers* (~Copyable elements/Self exist — real supply). For `Index` that premise **fails**: `~Escapable`-index supply is zero and the shape is vestigial/redundant. Maximal-support is a heuristic grounded in payoff; `Index` is the case where it doesn't pay off (V4 + zero supply are the tells).
6. **Asymmetry subordinate to semantics.** Requiring-now/admitting-later is breaking — but if the honest contract is "an index is an exportable coordinate," then admitting non-exportable indices later *is* a semantic redefinition of `Collection`, and a breaking change is the **correct signal** for that. Hedging via permissive admission buys avoidance of a hypothetical future break at the price of permanent semantic muddiness now.

### Forward implications (design under each — no un-migrated-consumer counts)

**Under KEEP `& ~Escapable`:**
- **Standing obligation, forever:** the base no longer guarantees an exportable index, so *every* future storable-index consumer/algorithm (ranges, slices, `firstIndex`, `min.index`, stored checkpoints, any struct field holding a `Base.Index`) must itself declare `where Base.Index: Escapable` (or pin concrete). The storable majority pays a permanent constraint-tax to support a zero-supply minority. The base's `Index` ceases to mean "exportable position."
- **Decomposition pressure:** the Collection / Sequence / Iterator split (per detachment) blurs — "indexed access whose positions can't be exported" sits ambiguously across the Collection/borrowing-iterator line; future tier work must repeatedly re-adjudicate where operations belong.

**Under REQUIRE Escapable:**
- **Foreclosed:** scoped/borrowed/handle indices that cannot escape. Assessment: these are **Sequence-shaped, not Collection-shaped** — transient position access *is* a borrowing iterator; if within-scope random access is genuinely needed, the honest model is a *scoped view* that vends an Escapable index into a snapshot/borrow. Genuinely Collection-shaped (exportable-index) access — **100% of current supply** — is fully preserved, including all custom *Escapable* domains.
- **Standing posture:** the base `Index` means "exportable, comparable position"; storing algorithms/refinements need **no** `where Index: Escapable` ceremony; the Collection/Sequence line stays sharp. Re-admitting `~Escapable` later requires a deliberate breaking change — appropriately, since it would redefine `Collection`.

### Recommendation (contract-first): REQUIRE Escapable — keep the associatedtype, drop the `~Escapable` suppression

On the contract alone (consumer-cost excluded per the principal's frame), the index's distinguishing capability is exportability; a non-exportable index is a cursor wearing index syntax, whose home is the Sequence/iterator tier the decomposition already provides. V4 (the language refusing `~Copyable` Index) and the zero `~Escapable` supply are concrete evidence that `Index` is contract-bearing — not a payload like `Element` — so the maximal-support idiom that justifies KEEP does not transfer to it. REQUIRE keeps everything with real supply (the associatedtype + all custom *Escapable* index domains) and drops only a zero-supply, vestigial admission whose foreclosure costs nothing real.

This **updates my v1.1.0 "(a)-narrow is reasonable" lean** — which I now see rested on the consumer-cost argument the principal correctly excluded. The strongest case *against* REQUIRE is KEEP-#2/#3 (base = bare-traversal, refinements constrain; the loosening asymmetry) — genuinely coherent, and the reason this remains a real philosophy call the **principal owns**: *if* a `~Escapable` index is read as a legitimate (if rare) Collection shape rather than a cursor, KEEP follows. My read is that it is a cursor, so REQUIRE is the honest contract.

## Outcome

**Status: DECISION (principal, 2026-05-27): KEEP `~Escapable`; `43d1fb7` STANDS.** Consumer-migration execution pending coordination (see §Decision below). This supersedes the v1.2.0 REQUIRE recommendation and the v1.1.0 (a)-narrow lean recorded further down (both preserved as the reasoning trail).

### Decision (final — principal, 2026-05-27): KEEP `~Escapable`. No revert.

**Token decided: KEEP `Index: Comparison.`Protocol` & ~Escapable`.** `43d1fb7` stands in full — the associatedtype, the `& ~Escapable` admission, and the `@_lifetime(copy i)` on `index(after:)` all remain.

**Rationale (principal).** Escapable is an **operation-level** requirement, **not intrinsic** to `Index`. The core index operations — `subscript(Index)`, `index(after:)`, comparison (`<`/`==`), scoped iteration via `formIndex(after: inout)` — all work with a `~Escapable` index (the experiment proved the storable-index contract typechecks under `@_lifetime(copy i)`). Only the **escape operations** — `Range<Index>`, slicing, `firstIndex`/`min.index` returns, stored bounds/checkpoints — require Escapable. So the requirement belongs **on those operations**, not on the base bound. The `~Copyable` floor stands (V4: subscripts cannot take noncopyable parameters). Admitting `~Escapable` is the ecosystem-wide maximal-support pattern applied consistently; nothing is foreclosed.

This **resolves the philosophy call this doc flagged as the principal's**, and directly answers the v1.2.0 REQUIRE argument: REQUIRE held that exportability is the index's *defining* capability; the decision is that exportability is a property of *escape-operations*, required **where used**, not at the base — the same decompose/compose shape used throughout (`Collection.Slice.Protocol` already carries `where Index: Swift.Comparable`). REQUIRE is **superseded**.

**General migration pattern (record for the ecosystem):**

| Use of an index | Constraint |
|-----------------|-----------|
| **Escape-operation** — stores an index beyond a scope, forms a `Range<Index>`, slices, returns a found index, or holds index-typed struct fields (`Input.Slice`, `Collection.Slice.Protocol`, `firstIndex`, `min.index`, index-storing iterators) | carry `where Index: Escapable` — or pin `where Base.Index == Index_Primitives.Index<Element>` when the concrete Ordinal API (`.distance`/`init`/`+`/`Index.Count`) is needed |
| **Within-scope index use** — bare traversal (`startIndex`/`endIndex`/`subscript`/`index(after:)`/scoped `formIndex`) | **no** Escapable constraint — works with any admitted index |

**Consumer-migration status.** The one realized escape-operation consumer, `Input.Slice` (input-primitives), pins `where Base.Index == Index_Primitives.Index<Base.Element>` on its `Collection.Protocol`-using extensions. Execution + ownership/sequencing are **pending coordination**: input-primitives' working tree is currently mid-W1 Sequence-rename (owned by the World-B chat — `import Iterable`, `Iterator_Primitive.Iterator`), so it does not build and one target file (`Input.Slice+Collection.Slice.Protocol.swift`) is held by that chat. The Index-axis pin must be applied in coordination with the World-B chat's held Sequence edits (it does **not** conflate with the W1 arc; the two axes co-locate in one file). Recipe in the handoff `## Findings`.

---

_The analysis that fed this decision is retained below for the reasoning trail (v1.0.0 → v1.2.0)._

**Prior status: RECOMMENDATION (pending principal confirmation per the `ask:` ground rule).**

### Correction (v1.1.0): c1 rejected; the decision is one token

v1.0.0 recommended **c1 — revert `Index` to the concrete `typealias Index = Index<Element>`**. **Rejected.** c1 conflated "the base should not *require* `~Escapable`" with "drop the associatedtype" — separable, and c1 regresses **both** axes the change was right to open: it removes the associatedtype (→ no custom index domains: the `SlotIndex` / `Buffer.Linked` / `Buffer.Slab.Inline` goal) **and** pins the base to a concrete `Escapable`+`Copyable` type (→ loses `~Escapable`/`~Copyable` admission, contradicting the ecosystem's maximal-permissive-foundation pattern, cf. `Iterator.Protocol`'s `Element: ~Copyable & ~Escapable`). §1–§4 and the quantification stand; the conclusion is revised. With the blast radius now known to be **one consumer (`Input.Slice`, 5 files)**, §5's "(a) = pure tax on *every* consumer" objection collapses — at true scale, (a) is cheap.

**Both live options keep the associatedtype and migrate only `Input.Slice` — identically** — by constraining its `Base.Index` back to the concrete default: `extension Input.Slice where Base.Index == Index_Primitives.Index<Element> { … }`. That restores exactly what `Input.Slice` needs (`.distance`, `Index(_unchecked: Ordinal(…))`, `+`, `Index.Count(_)`, `Escapable`/`Sendable` storage) — necessarily the *concrete* type, because there is **no Index *protocol*** carrying that surface (`Index<Element>` is a concrete struct; `Comparison.Protocol` supplies only `<`/`==`). So the migration is **common to both options, not a differentiator.** The options differ in exactly one token of the base bound:

| Option | Base `Index` bound | Gives | Costs |
|--------|--------------------|-------|-------|
| **(a)-narrow** (principal's lean) | `Comparison.`Protocol` & ~Escapable` (unchanged) | Maximal-permissive foundation; keeps the (rare, pointer/handle-index) `~Escapable` case; matches `Iterator.Element`. **Loosening is foundational** — now is the only non-breaking time to admit `~Escapable`. | Index-**storing** algorithms/consumers permanently carry `where Base.Index: Escapable`; admits a case degenerate past bare traversal. |
| **strong-bound** | `Comparison.`Protocol` & Escapable` (keep associatedtype, require Escapable) | Semantically honest — an index is a *storable coordinate*, the very property separating `Collection.Protocol` from `Sequence.Protocol`; storing consumers need no `where: Escapable`. Custom **Escapable** index domains (the realized goal — `SlotIndex` is Escapable) fully preserved. | Forecloses `~Escapable` Index at the base; re-admitting later is breaking. |

**Deciding question (the principal's call):** *is a `~Escapable` index ever coherent for a multi-pass `Collection`, or is a non-storable cursor definitionally a `Sequence`?* `~Copyable` Index is already dead (V4 REFUTED). `~Escapable` Index is **degenerate but not categorically incoherent** (a pointer/handle index could be `~Escapable`) — so the call weights **"don't foreclose at the foundation" (→ (a)-narrow)** vs **"don't admit a state no realized consumer can use; keep the Collection/Sequence line sharp" (→ strong-bound)**.

**My revised lean.** A genuinely close call — I am **updating from v1.0.0's anti-`~Escapable` stance**, whose two premises both weakened (it is one consumer, not every; `~Escapable` Index is degenerate, not impossible). Given the loosening-is-foundational asymmetry and the standing maximal-support principle, **(a)-narrow is reasonable and I do not object.** My one genuine flag, for deliberate (not reflexive) weighing: **`Index` is special among associatedtypes** — unlike `Element` (a produce-and-discard payload), it carries a *storability contract*, which is exactly the Collection-vs-Sequence distinction; that is the standing case for strong-bound. Either way: **keep the associatedtype; migrate `Input.Slice`'s 5 files; c1 is off the table.**

> **v1.2.0 conclusion (contract-first — supersedes the v1.1.0 lean above).** The principal's methodological correction excludes consumer-cost (a transitional artifact) from the decision; the v1.1.0 "(a)-narrow is reasonable" lean rested on exactly that. Reasoning from the **contract alone** — see **§Both-Ways + Forward Impact** above — I land on **REQUIRE Escapable**: an index's distinguishing capability over a cursor is *exportability*, a non-exportable "index" is a cursor whose home is the Sequence/iterator tier, and `Index` is contract-bearing not payload (V4 refuses `~Copyable` Index; `~Escapable`-index **supply is zero**). REQUIRE keeps the associatedtype + all custom *Escapable* domains and drops only a zero-supply, vestigial admission. The **KEEP-vs-REQUIRE token remains the principal's** call (KEEP follows iff a `~Escapable` index is read as a legitimate Collection shape rather than a cursor); execution unchanged — keep the associatedtype, migrate `Input.Slice`'s 5 files either way.

### Plan (staged; execution gated on principal confirmation — NOT performed here)

| Phase | Scope | Notes |
|-------|-------|-------|
| **0. Decision gate** | Principal confirms the base-bound token: **(a)-narrow** (keep `& ~Escapable`) vs **strong-bound** (`& Escapable`). c1 rejected. | The `ask:` ground rule. This doc is the input. |
| **1. Set token + migrate the one consumer** | (a)-narrow → leave `Collection.Protocol.swift:52` unchanged. strong-bound → tighten `& ~Escapable` → `& Escapable` (keep the associatedtype) + drop the now-redundant `where Base.Index: Escapable` on Min/Max/ForEach. **Both** → add `where Base.Index == Index<Element>` to `Input.Slice`'s 5 files; rebuild collection-primitives (16 tests) + input. Retain the experiment as a viability record. | collection-primitives ≤1 token; input 5 files. |
| **2. Verify consumers (CI axis)** | Rebuild input (expect green), then dictionary / infinite / queue (Collection.Index errors clear transitively). | These packages may *still* carry independent Sequence-rename (W1) breakage — that is W1's scope, not this arc's. |
| **3. Future, separate arc** | When the buffer-linear spike lands a real custom-index conformer, design the opt-in custom-index capability with full information. | Decompose-clean; evergreen. |

**Out of scope (do not conflate):** the Sequence rename breakage in array / cache / heap / slab / stack (via buffer-linear / buffer-slab) is the **W1 arc**. This decision neither fixes nor depends on it. W1 may resume its `Collection`-consuming subset once this arc lands (input compiles), but the Sequence-rename fixes remain W1's.

## Open Questions (for the principal)

1. **The base-bound token (the one first-principles call):** **(a)-narrow** (keep `& ~Escapable`) or **strong-bound** (`& Escapable`)? Both keep the associatedtype and migrate `Input.Slice` identically; they differ only in whether the base admits a `~Escapable` index. (c1 — revert-to-concrete — is rejected: it would drop the associatedtype too.)
2. **`infinite`'s `Infinite.Cycle.Iterator` own site** (footnote 2) — confirm it is downstream-of-input-only, or a genuine second consumer, once `input` is fixed and infinite's build proceeds past the dependency.
3. **Custom index domains ahead of the buffer-linear spike?** The associatedtype is preserved by both options, so a concrete custom-index conformer (`Buffer.Linked` / `Buffer.Slab.Inline`) can adopt it whenever its index shape is known; no need to design speculatively now.

## References

- **The change:** `swift-collection-primitives` commit `43d1fb7` — `Sources/Collection Protocol Primitives/Collection.Protocol.swift:52,73`; companions `Collection.Slice Primitives/Collection.Slice.Protocol.swift:32`, `Collection.Min Primitives/Collection.Min+Property.Inout.swift:14` (and Max/ForEach siblings).
- **Backing experiment:** `swift-collection-primitives/Experiments/collection-index-escapable-lifetime/` — `Sources/ProtocolV2/CollectionLike.swift` (the bound + formIndex default), `Sources/collection-index-escapable-lifetime/main.swift:37–62` (the **Escapable** `SlotIndex` conformer), `Sources/V4CopyableIndex/V4.swift` (~Copyable REFUTED), `Outputs/run.txt` (`traversed sum = 60`). Commit `197c807`.
- **Casualty:** `swift-input-primitives/Sources/Input Slice Primitives/Input.Slice.swift:54–118` (raw-Int storage + `Base.Index(_unchecked: Ordinal(…))` reconstruction), `Input.Slice.Error.swift`, `Input.Slice+Collection.Slice.Protocol.swift`.
- **The bound:** `swift-comparison-primitives/Sources/Comparison Protocol Primitives/Comparison.Protocol.swift:62` (`: Equation.Protocol, ~Copyable, ~Escapable`; only `<`/`==`/derived comparison). `swift-index-primitives/Sources/Index Primitives/Index.swift:38` (`typealias Index<Element> = Tagged<Element, Ordinal>` — no standalone index protocol).
- **Prior art (institute):** `swift-institute/Research/parser-collection-protocol-migration.md` (DECISION v2.1.0 — Input.Slice as canonical Collection.Protocol consumer); `swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md` (DEFERRED-TOOLCHAIN-PRUNED v1.2.0 — precedent for pruning hypothetical ~Escapable widenings); `swift-index-primitives/Research/Strideable Index Design.md` (DECISION v1.0.0 — index = storable position); `swift-institute/Research/nonescapable-ecosystem-state.md` (the ~Escapable program context).
- **Empirical baseline:** `swift build` matrix, Apple Swift 6.3.2 / macOS 26.2 / arm64, collection-primitives@`43d1fb7`, 2026-05-27 (this investigation).
- **Governing rules:** `[RES-018]` + `feedback_correctness_and_evergreen` (judge ~Escapable on structural correctness + evergreen, not consumer count); `[ARCH-LAYER-008]` (correctness drives pre-1.0 reshape).
