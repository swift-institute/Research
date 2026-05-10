# Array.Bounded.Index Revisit (2026-05-08)

<!--
---
version: 2.0.0
last_updated: 2026-05-08
status: DECISION
tier: 2
scope: cross-package
packages: [swift-array-primitives, swift-algebra-modular-primitives]
---
-->

## Changelog

- **v2.0.0 (2026-05-08, DECISION)**: Reframed per orchestrator redirect from publish-cost-vs-cohesion ranking to semantic-identity question. The right question is not "what does the publish chain look like under each option?" but "IS `Array.Bounded.Index` an `Algebra.Z<N>`?". Answer: **NOT-A.** The current binding is a category error, not a pragmatic over-spend. The retreat is corrective; the publish-chain reduction is a consequence, not the motivation. Original v1.0.0 evidence (use-site count, dep chain, RECOMMENDATION-not-IMPLEMENTED status of cyclic + numeric refactors) remains load-bearing as supporting evidence; the dispositive evidence is operational — `Array<E>.Index = Index<Element>` (linear), `Array.Protocol` conforms to `Collection.Bidirectional` (linear-bidirectional), sibling Array variants use `successor.saturating()` / `predecessor.exact()` (saturate/throw, NOT wrap), `Queue.Index` is linear (the ecosystem's actual ring buffer rejected exposing modular indices), `cyclic-primitives` does not bind to `Algebra.Z<N>` either.
- **v1.0.0 (2026-05-08, ANALYSIS)**: Initial ranking of three options (status quo / retreat / hybrid target split) on publish-cost vs canonical-cohesion axes. Recommendation deferred to orchestrator. Superseded by v2.0.0 which rejects the ranking framing in favor of semantic identity.

## Context

`swift-algebra-primitives/Research/deferred-work.md` §1 (2026-02-03, DECISION, v2.0.0) establishes `Algebra.Z<n> = Tagged<Residue<n>, Ordinal>` as the canonical Z/nZ residue-class type — a commutative ring with modular `+`, `-`, `*`, additive inverses, and (for prime n) multiplicative inverses, plus `Algebra.Ring`/`Algebra.Field` witnesses and `Finite.Enumerable` conformance.

`Array.Bounded.Index` (in `swift-array-primitives/Sources/Array Bounded Primitives/Array.Bounded.Index.swift:29`) is `typealias Index = Algebra.Z<N>` — a downstream consumer of that decision. The transitive cost is a 7-package algebra chain on the array-primitives publish chain.

The orchestrator rejects the v1.0.0 framing — "rank options on publish-cost-vs-cohesion axes" — as backwards. **Ecosystem preference is re-use over ad-hoc reimplementation, so the actual question is semantic identity, not pragmatism.** Pragmatism is downstream of truth: if `Array.Bounded.Index` IS-A `Algebra.Z<N>`, we pay the 7-package cost on principle; if it is NOT, the retreat is principled regardless of publish chain. Cost cannot decide; semantic fit decides.

## Question

**IS `Array.Bounded.Index` an `Algebra.Z<N>`?**

If yes — i.e., the natural arithmetic on a bounded-array index IS modular wraparound, indexing past the end naturally returns to the start, the type IS-A residue class — then we keep the binding regardless of publish cost. The 7 algebra packages stay in the DS chain.

If no — i.e., it's a bounded LINEAR position (an Ordinal in [0, N) with bounds-checking but no modular arithmetic, like Rust `[T; N]` or stdlib `Array` indexing where overflow is an error rather than a wrap) — then **the current binding is a category error**: `Array.Bounded.Index` is using `Algebra.Z<N>` AS-IF it were a thinner phantom-typed bounded ordinal, ignoring the algebraic ring structure that the type carries. The retreat is structurally correct.

## Verdict

**NOT-A.** `Array.Bounded.Index` is not semantically a Z/nZ. It is a phantom-typed bounded-linear-index — an `Ordinal` in `[0, N)` with bounds-check at construction and linear-bidirectional advance semantics, identical in role to `Array<E>.Index`, `Queue.Index`, and every other DS package's Index type.

The current binding is a category error: `Array.Bounded.Index` uses `Algebra.Z<N>`'s structural substrate (`Tagged<Residue<N>, Ordinal>`) AS-IF it were a thinner phantom-typed bounded ordinal, while the type's algebraic surface (modular `+`, `-`, `*`, ring/field witnesses) actively contradicts the linear-bidirectional contract that `Array.Protocol` / `Collection.Bidirectional` imposes on every Array variant. The retreat is corrective, not pragmatic. The publish-chain reduction is a *consequence* of the correctness fix.

## Operational evidence

### O1 — `Array<E>.Index = Index<Element>` is the canonical Array index family-wide

`swift-array-primitives/Sources/Array Primitives Core/Array.Index.swift:27`:

```swift
extension Array where Element: ~Copyable {
    public typealias Index = Index_Primitives.Index<Element>
}
```

The whole-Array-family Index is `Index_Primitives.Index<Element>` — linear, phantom-typed-by-Element, NOT phantom-typed-by-N. `Array.Bounded.Index = Algebra.Z<N>` is the *only* outlier. Every other Array variant inherits or reuses `Array<E>.Index` (`Array.Small ~Copyable.swift:26: typealias Index = Array<Element>.Index`).

### O2 — `Array.Protocol` conforms to `Collection.Bidirectional`, which is linear

`swift-array-primitives/Sources/Array Primitives Core/Array.Protocol.swift:17`:

```swift
public protocol __ArrayProtocol: Collection.Bidirectional & ~Copyable {
    subscript(_ position: Index) -> Element { get set }
}
```

The contract per the same file lines 56–62: `var startIndex: Index { get }`, `var endIndex: Index { get }`, `func index(after i: Index) -> Index`, `func index(before i: Index) -> Index`, with `Index: Comparison.Protocol`. No modular operations. No wrap. No multiplicative inverse. The contract is linear-bidirectional, not cyclic.

If Array.Bounded conforms to Array.Protocol — and the documentation in `Array.swift:47` (`- ``Array/Bounded``: Compile-time dimensioned with `Algebra.Z<N>` indexing`) and `Array.Bounded.swift:18-39` describe it as an Array variant alongside Static/Small/Fixed/Dynamic — its Index MUST satisfy the linear advance contract. `Algebra.Z<N>`'s `+` operator wraps modulo N at the boundary; `Collection.Bidirectional`'s contract requires saturate/throw at the boundary. These two semantics are operationally incompatible.

### O3 — Sibling Array variants use linear-saturating, NEVER modular

`swift-array-primitives/Sources/Array Small Primitives/Array.Small ~Copyable.swift:35,42`:

```swift
public func index(after i: Index) -> Index { i.successor.saturating() }
public func index(before i: Index) -> Index { try! i.predecessor.exact() }
```

`Array.Static` uses the same convention (`Array.Static Copyable.swift:24-32`: `precondition(index < count, "Index out of bounds")` — error on out-of-bounds, not wrap). The ecosystem-wide pattern is `successor.saturating()` (clamp at endIndex when advancing past end) and `predecessor.exact()` (throw when stepping before startIndex). **NEITHER wraps.** Saturating is the operational *inverse* of modular: saturating clamps at the boundary; modular jumps to the opposite boundary.

If Array.Bounded ever implements `index(after:)` / `index(before:)` (which Collection.Bidirectional requires), it will use saturating/exact — matching its siblings — and `Algebra.Z<N>`'s `+` will be unused. If a future implementer instead uses `Algebra.Z<N>`'s `+`, they break the contract every other Array variant honors. Either way, the binding is wrong: at best the algebra surface is dormant; at worst it is actively contradictory.

### O4 — Queue (the ecosystem's actual ring buffer) uses linear indices

`swift-queue-primitives/Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded Copyable.swift:114-127`:

```swift
public var startIndex: Queue.Index { .zero }
public var endIndex: Queue.Index { count.map(Ordinal.init) }
public func index(after i: Queue.Index) -> Queue.Index { i.successor.saturating() }
public func index(before i: Queue.Index) -> Queue.Index { try! i.predecessor.exact() }
```

`Queue.Index = Index<Element>` — linear. The ring-buffer wrap semantics live INTERNALLY in `Buffer.Ring`, hidden from Queue's user-facing API. Queue's user-facing Index iterates `0..<count` linearly; the underlying ring's wrap is invisible to consumers.

**This is dispositive.** Queue is THE ring buffer in the ecosystem (per `[DS-003]` and `[DS-004]`: `Queue<E>` is "general-purpose FIFO (ring buffer)"; `Buffer.Ring<E>` backs it). If anyone in the ecosystem had a legitimate "this index wraps because the underlying storage is cyclic" use case, it would be Queue. Queue rejected that pattern: its user-facing Index is linear; the cyclic semantics are an internal-storage concern. **Array.Bounded — which is NOT a ring buffer (it is backed by `Buffer.Linear.Bounded`, not `Buffer.Ring`) — has even less reason to expose modular index semantics to its consumers.**

### O5 — Cyclic.Group (the ecosystem's explicit cyclic-arithmetic type) does NOT bind to `Algebra.Z<N>`

`swift-cyclic-primitives/Package.swift` declares zero algebra dependencies (only comparison, hash, ordinal, cardinal, sequence). `grep -rln "Algebra\.Z\|Algebra_Modular" swift-cyclic-primitives/` returns ONLY the `maximal-algebra-refactor.md` research doc (RECOMMENDATION, unimplemented as of 2026-05-08, three months idle), zero source-code matches. cyclic-primitives ships its own hand-rolled `Cyclic.Group.Static.swift`, `Cyclic.Group.Static.Element+Ordinal.swift`, etc. (`ls swift-cyclic-primitives/Sources/Cyclic Primitives/`).

If the ecosystem's *explicit cyclic-arithmetic data type* does not currently bind to `Algebra.Z<N>`, then `Array.Bounded` — whose stated purpose is bounded-linear indexing, not cyclic arithmetic — using `Algebra.Z<N>` is anomalous in the strongest sense. Cyclic-primitives is the IS-A case for `Algebra.Z<N>` (per the maximal-algebra-refactor RECOMMENDATION); even *that* hasn't materialized. Binding to `Algebra.Z<N>` for a non-cyclic role is binding ahead of even the IS-A consumer.

### O6 — No other DS package's Index binds to `Algebra.Z<N>`

`grep -rln "Algebra\.\(Z\|Modular\|Residue\|Residual\)" swift-primitives/*/Sources/ | grep -v swift-algebra` returns three lines, ALL of them in `swift-array-primitives` (the typealias declaration and two doc-comment references). `grep -rln "swift-algebra-modular" swift-primitives/*/Package.swift | grep -v swift-algebra` returns ONE result: `swift-array-primitives/Package.swift`.

Slab.Index, Stack.Index, Heap.Index, Set.Ordered.Index, Dictionary.Index, Tree positions, List.Linked positions — none bind to `Algebra.Z<N>`. They use `Index<E>`, `Buffer.Arena.Position`, or similar linear/sparse shapes. **`Array.Bounded.Index` is the ONLY non-algebra binding to `Algebra.Z<N>` in the entire ecosystem.** This is consistent with NOT-A: if the binding were genuine, we would expect at least one other DS package (Buffer.Ring, Queue, Cyclic) to also bind. None do.

### O7 — Array.Bounded has no tests defining its index semantics

`ls swift-array-primitives/Tests/Array Primitives Tests/` shows: Array Tests, Array+OutputSpan Tests, Array+clone Tests, Array+freeCapacity Tests, Array+reallocate Tests, Array+reserveCapacity Tests, Array+swap Tests, Array.Builder Tests, Array.Deinit Tests, Array.Fixed Tests, Array.Fixed+OutputSpan Tests, Array.Small Tests, Array.Static Tests. **No `Array.Bounded Tests.swift`.**

The Index typealias was wired in before any operation that uses it was specified. There are no tests asserting wraparound; there are no tests asserting saturate/throw; there are no Array.Bounded operations at all yet. Combined with `grep` confirming `Array.Bounded` declares no `Array.Protocol` conformance (only conditional `Copyable` + `@unchecked Sendable` per `Array.Bounded.swift:57,61`), Array.Bounded is currently underspecified — a struct definition with an Index typealias and nothing else.

This means the binding was made on TYPE-AVAILABILITY grounds ("`Algebra.Z<N>` exists and provides a phantom-typed bounded ordinal in [0, N)"), not on SEMANTIC-FIT grounds ("`Array.Bounded.Index` IS-A Z/nZ"). The author wanted "phantom-typed-by-N bounded ordinal" — that's the entirety of Array.Bounded.swift's docstring justification (lines 18-39: "compile-time dimension safety", "indices are always within [0, N)", "subscript access is guaranteed safe", "Type-Level Index Separation"). The modular ring structure was inherited as a side effect, not a design choice.

### O8 — Original-v1 evidence remains load-bearing

The v1.0.0 evidence is now subordinated to the operational case but reinforces it:

- `Array.Bounded` consumes ZERO of `Algebra.Z<N>`'s arithmetic + witness surface (v1 §E1).
- `algebra-modular-primitives`'s only non-algebra consumer is `Array.Bounded.Index` (v1 §E3).
- Cyclic + numeric maximal-refactor docs are RECOMMENDATIONs, not IMPLEMENTED; numeric explicitly routes around `algebra-modular` (v1 §E4).

If `Array.Bounded.Index` were genuinely IS-A Z/nZ, we would expect operational use of the algebra surface to be at least *latent* in the source — a `successor.wrapping()` instead of `successor.exact()`, an `index + offset` that wraps. There is no such use; there is no such latent use; the binding is structural-typealias-only because the Z/nZ structure is not what bounded-array indices are.

## Comparison

| Criterion | IS-A (`Algebra.Z<N>`) | NOT-A (linear bounded-index) |
|-----------|------------------------|------------------------------|
| Addition wraps modulo N | Yes (Z/nZ ring) | **No** — saturate or throw |
| Subtraction wraps modulo N | Yes | **No** — throw on underflow |
| Multiplication has algebraic meaning | Yes (ring) | **No** — `index × index` is meaningless on indices |
| Multiplicative inverse for `gcd(i, N) = 1` | Yes (when N prime) | **No** — `index⁻¹` is meaningless |
| Conforms to `Collection.Bidirectional`'s linear advance contract | **No** (wraps, contradicts saturate/throw) | Yes |
| Matches sibling Array variants' Index semantics | **No** (Static/Small/Fixed all linear) | Yes |
| Matches Queue's ring-buffer Index semantics | **No** (Queue.Index is linear) | Yes |
| Matches the actual cyclic data type (Cyclic.Group) | **No** (Cyclic.Group does not bind to `Algebra.Z<N>`) | Yes (analogous: ad-hoc structural type, no algebra dep) |
| Operational evidence in source | None — Array.Bounded has no Index-consuming code | Strong — every adjacent type treats bounded-array indices linearly |
| Documentation justification | Bounded-safety, type-level separation (Array.Bounded.swift:18-39) | Same — the docstring's stated goals are linear bounded |

Every operational signal points NOT-A. There is no operational signal pointing IS-A. The IS-A case rests entirely on §1's canonical-cohesion argument, which is undermined by O5 (the explicit cyclic type doesn't use `Algebra.Z<N>` either) and O6 (the binding is the ecosystem's only non-algebra one).

## Operational ambiguity to flag

Array.Bounded is currently underspecified (O7): no `Array.Protocol` conformance is declared, no Index-consuming operations exist, no tests define the semantics. The Index typealias is the only piece of Array.Bounded that sits in the Array Bounded Primitives target.

This means a future implementer could *theoretically* declare `extension Array.Bounded: Array.Protocol` with modular wraparound semantics on `index(after:)` / `index(before:)` — i.e., specify Array.Bounded as a cyclic-array data structure rather than a linear bounded-array. **That direction would contradict every adjacent design choice already made**:

- The struct is named `Bounded`, not `Cyclic` ([API-NAME-001] specification-mirroring).
- The namespace is `Array`, whose `Array.Protocol` extends `Collection.Bidirectional` (linear).
- The underlying buffer is `Buffer.Linear.Bounded`, NOT `Buffer.Ring` (per `Array.Bounded.swift:44`).
- The data-structures skill `[DS-003]` catalog lists `Array<E>.Bounded<N>` in the "Sequential — Contiguous" section alongside Static/Small/Fixed (all linear) — *not* in the Sequential — FIFO/Deque section where `Queue<E>` lives.
- Sibling Array variants (Static, Small, Fixed, Dynamic) all use linear semantics.
- Documentation describes Array.Bounded as a linear bounded variant (Array.swift:47 catalog, Array.Bounded.swift:18-39).

So the ambiguity is *operational-not-yet-implemented* but the design intent is unambiguously linear. **No orchestrator clarification is needed before this decision lands**; the verdict NOT-A holds. However, the implementing dispatch should explicitly choose linear-saturating semantics when wiring `Array.Bounded` to `Array.Protocol`, matching sibling variants, to close the operational gap that allowed the category error to slip in.

## Recommendation

**Retreat: `Array.Bounded.Index` becomes a phantom-typed bounded-linear-index, distinct from `Algebra.Z<N>`.** This is not v1.0.0's "Option B" in spirit — it is not a cost-driven retreat. It is a corrective rebind to the type whose semantics actually match the role.

Two structural target shapes for the implementing dispatch to choose between (this research does not bind that choice):

1. **Reuse existing `Index_Primitives.Index<Tag>`**: `Array.Bounded<N>.Index = Index<Bounded<N>>` where `Bounded<N>: Finite.Capacity` is a phantom-tag type. Requires verifying that `Index<E>` accepts a `Finite.Capacity` tag and provides bounds-checking; existing infrastructure preferred per `[INFRA-*]` and `[RES-018]` premature-primitive gate.
2. **Direct Tagged**: `Array.Bounded<N>.Index = Tagged<Bounded<N>, Ordinal>` with bounds-checked init via existing `Tagged where Tag: Finite.Capacity, Underlying == Ordinal` extensions (or new ones if absent). Same shape, fewer indirections, but requires defining the `Bounded<N>: Finite.Capacity` phantom tag (likely in `swift-finite-primitives` since that is where the protocol lives, per `[MOD-DOMAIN]`).

Either choice drops the dep on `algebra-modular` and the entire 7-package algebra chain from the array-primitives target's resolved set. Neither requires a new package per `[DS-020]` / `[RES-018]` (the shape fits inside `finite-primitives` or `array-primitives`). When the implementing dispatch wires `Array.Bounded` to `Array.Protocol`, it should use `successor.saturating()` / `predecessor.exact()` matching siblings.

The hybrid Option C from v1.0.0 (target split inside `algebra-modular`) is now off the table: the question was "is the binding correct?", not "how to keep the binding cheaply"; the binding is incorrect, so target-splitting it is solving the wrong problem.

## Implication for §1

§1's premise — `Algebra.Z<n>` is the canonical Z/nZ in the algebra ecosystem — is unaffected. Z/nZ remains a single canonical type for the algebra purposes the maximal-algebra-refactor docs envision: cyclic group elements, Z/2Z field transport, finite-field arithmetic, modular law verification. The decision here is that **bounded-array indices are not Z/nZ elements**; they are bounded-linear ordinals that happen to share the structural substrate (`Tagged<Tag, Ordinal>` where `Tag: Finite.Capacity`) but have a different algebraic structure (linear-bidirectional, not modular ring).

When the cyclic refactor lands and `Cyclic.Group.Static<N>.Element = Algebra.Z<N>`, that consumer IS-A Z/nZ and rightly uses `Algebra.Z<N>`. `Array.Bounded.Index` NOT-A and rightly uses a different type. Both can coexist because they are different things.

§1 was DECISION'd correctly. The downstream choice to bind `Array.Bounded.Index` to `Algebra.Z<N>` was not §1's call; it was a separate decision made on type-availability grounds rather than semantic-fit grounds. The retreat does not weaken §1; it removes a downstream misuse that was always in tension with the ecosystem's linear-indexing convention.

## Publish-chain impact (consequence, not motivation)

Removing `Array.Bounded.Index = Algebra.Z<N>` and dropping the `algebra-modular` dep from the Array Bounded Primitives target eliminates the 7-package algebra chain from `swift-array-primitives`'s resolved set: `algebra-modular`, `algebra-field`, `algebra-ring`, `algebra-group`, `algebra-semiring`, `algebra-monoid`, `algebra-magma`, `algebra-primitives` (the last minus algebra-primitives if other DS-chain packages transit it via `finite-primitives`'s deps on `algebra-primitives` + `algebra-group`). Net DS publish-chain reduction is approximately 4–5 packages once shared transitive dependencies are accounted for; the `algebra-modular`/`algebra-field`/`algebra-ring`/`algebra-semiring`/`algebra-magma` cascade has zero non-array DS consumers and exits the chain entirely.

The reduction is real but is a *byproduct* of fixing the binding. Had the binding been semantically correct, we would have shipped at 43 packages on principle (per the orchestrator's reframe); the cost saving exists only because the binding was wrong.

## Material findings vs `deferred-work.md` §1

§1 does not address `Array.Bounded.Index`. The maximal-algebra-refactor docs (cyclic 2026-02-04, numeric 2026-02-04) predicted §1's downstream consumers would be `Cyclic.Group.Static<N>.Element` and numeric witnesses; neither has materialized. The error was not in §1; it was in the downstream choice — likely made in the same wave as §1's authoring, on type-availability grounds — to bind a non-Z/nZ semantic role to `Algebra.Z<N>`. §1 survives intact; the retreat removes a misalignment that §1 itself would have flagged had the question been posed at the time.

The 2026-05-08 evidence that materially changes the picture vs §1's downstream landscape:

1. The cyclic refactor is RECOMMENDATION not IMPLEMENTED, and `cyclic-primitives` continues to ship its hand-rolled cyclic group element with zero algebra deps. The ecosystem's actual cyclic data structure has already (implicitly) decided NOT-A on its own type.
2. The numeric refactor explicitly routes its witnesses around `algebra-modular` into `algebra-primitives` directly. Even when numeric lands, it does not produce an `algebra-modular` consumer.
3. `Array.Bounded.Index` is the only non-algebra binding to `Algebra.Z<N>` ecosystem-wide; the binding is also the only non-algebra `algebra-modular` consumer at the package level.

Together: the canonical-cohesion case for `Algebra.Z<N>` rests on consumers that have been recommended but not built; the one consumer that did materialize is the wrong shape. The retreat aligns the ecosystem's bindings with what it actually does.

## References

- `swift-algebra-primitives/Research/deferred-work.md` §1 (2026-02-03, DECISION, v2.0.0) — canonical modular-integer carrier rationale; survives intact under this DECISION
- `swift-cyclic-primitives/Research/maximal-algebra-refactor.md` (2026-02-04, RECOMMENDATION, tier 2) — proposed cyclic ↔ `Algebra.Z<N>` unification; unimplemented as of 2026-05-08
- `swift-numeric-primitives/Research/maximal-algebra-refactor.md` (2026-02-04, RECOMMENDATION, tier 2) — places numeric witnesses in `algebra-primitives`, NOT `algebra-modular`
- `swift-array-primitives/Sources/Array Bounded Primitives/Array.Bounded.Index.swift:29` — the typealias under analysis
- `swift-array-primitives/Sources/Array Primitives Core/Array.Index.swift:27` — `Array<E>.Index = Index<Element>` (canonical linear Array index)
- `swift-array-primitives/Sources/Array Primitives Core/Array.Protocol.swift:17` — `Array.Protocol: Collection.Bidirectional & ~Copyable`, linear contract
- `swift-array-primitives/Sources/Array Primitives Core/Array.Bounded.swift:18-61` — Array.Bounded struct (no Index-consuming surface, no Array.Protocol conformance, conditional Copyable/Sendable only)
- `swift-array-primitives/Sources/Array Small Primitives/Array.Small ~Copyable.swift:35,42` — sibling variant's `successor.saturating()` / `predecessor.exact()`
- `swift-array-primitives/Sources/Array Static Primitives/Array.Static Copyable.swift:24-32` — sibling variant's `precondition(index < count)` (error on out-of-bounds, NOT wrap)
- `swift-queue-primitives/Sources/Queue DoubleEnded Primitives/Queue.DoubleEnded Copyable.swift:114-127` — Queue (the actual ring buffer) uses `Queue.Index = Index<Element>` linear
- `swift-cyclic-primitives/Sources/Cyclic Primitives/` + `Package.swift` — explicit cyclic data type, zero algebra deps, hand-rolled `Cyclic.Group.Static.Element`
- `swift-algebra-modular-primitives/Sources/Algebra Modular Primitives/Algebra.Z.swift:21` — `typealias Z<let n: Int> = Tagged<Residue<n>, Ordinal>`
- `swift-algebra-modular-primitives/Sources/Algebra Modular Primitives/Algebra.Z+Arithmetic.swift` — modular `+`, `-`, `*` arithmetic surface unused by Array.Bounded
- `[API-NAME-003]` Specification-Mirroring Names (`Bounded` not `Cyclic`)
- `[DS-003]` Container Selection — Array<E>.Bounded<N> in Sequential—Contiguous, NOT Sequential—FIFO/Deque
- `[DS-004]` Buffer Selection — `Buffer.Linear` (Array's backing) vs `Buffer.Ring` (Queue's backing)
- `[MOD-006]` Dependency Minimization — substantive violation by the current binding
- `[MOD-DOMAIN]` Factor the Law, Not the Module — Z/nZ law and bounded-linear-index law are distinct laws
- `[RES-018]` Premature Primitive Anti-Pattern — gates against new packages; retreat reuses existing `Tagged` + `Finite.Capacity` infra
- `[RES-022]` Recommendation-Section Framing Heuristic — structural correctness over diff-size; here, structural correctness over publish-cost
- `[RES-023]` Empirical-Claim Verification — all empirical claims in this doc verified against source 2026-05-08

---

## Bit-Field Witness Home — Investigation

<!--
---
section_version: 1.0.0
section_added: 2026-05-08
parent_doc_status: DECISION
section_status: DECISION
---
-->

### Premise (not in question)

`Bit` IS-A `Algebra.Field`. `Bit = {.zero, .one}` with `Bit.adding` (XOR) as additive operation and `Bit.multiplying` (AND) as multiplicative operation forms the two-element field GF(2) ≡ ℤ₂. The Field witness is a genuine algebraic claim, not a category error in the v2.0.0 sense above. The premise IS-A is settled; this section addresses placement.

### Question

Where should `Algebra.Field<Bit>` live? Four options (per dispatch):

- **(A) Stay** — current state: `Bit Field Primitives` subtarget inside `swift-bit-primitives` (`Algebra.Field+Bit.swift`).
- **(B) Move** — to `swift-algebra-field-primitives`; algebra-field gains a dep on bit-primitives; ships `Algebra.Field<Bit>` extension internally. Inverts current direction.
- **(C) Extract** — to a new sibling package (`swift-algebra-bit-primitives` / similar), depending on both bit-primitives and algebra-field-primitives; opt-in by import.
- **(D) Delete** — rely on the generic `Algebra.Field.z2(via:)` factory in algebra-field; consumers construct the Bit ↔ Parity iso themselves.

### Verdict

**(A) Stay.** Current arrangement is consistent with the ecosystem's witness-placement pattern for kind-extension witnesses on non-algebra-internal carriers. Options (B) and (D) have no ecosystem precedent. Option (C) is a viable alternative for a different (carrier-extension) shape but does not match Bit's actual shape and would require both moving the witness AND switching its extension shape — two changes solving an inconsistency that is not present.

### Operational evidence — ecosystem survey of concrete witness placement

Verified by `grep -rln "Algebra\.\(Field\|Group\|Ring\|Module\|Monoid\|Semiring\)\b" swift-primitives/*/Sources/` on 2026-05-08:

| Witness file | Carrier | Owner of carrier | Shape | Placed at | Pattern |
|--------------|---------|------------------|-------|-----------|---------|
| `Algebra.Field+Parity.swift` | Parity | `swift-algebra-primitives` (`Algebra Primitives Core/Parity.swift:17`) — algebra-internal | kind-extension `extension Algebra.Field where Element == Parity` | `swift-algebra-field-primitives` | **Kind home (algebra-internal carrier)** |
| `Algebra.Group+Parity.swift` | Parity | algebra-internal | kind-extension | `swift-algebra-group-primitives` | Kind home (algebra-internal) |
| `Algebra.Field+Z2.swift` | generic via `Algebra.Iso<Element, Parity>` | n/a | generic factory | `swift-algebra-field-primitives` | Generic factory in kind |
| `Algebra.Group+Z2.swift` | generic via `Algebra.Iso<…>` | n/a | generic factory | `swift-algebra-group-primitives` | Generic factory in kind |
| `Algebra.Z+Field.swift`, `+Ring.swift`, `+Semiring.swift` | `Algebra.Z<n>` | `swift-algebra-modular-primitives` (own-package) | kind-extension | `swift-algebra-modular-primitives` | Carrier IS the package's central type — cohabit |
| `Algebra.Field+Bit.swift` | Bit | `swift-bit-primitives` — non-algebra-internal | kind-extension `extension Algebra.Field where Element == Bit` | `swift-bit-primitives/Bit Field Primitives` (subtarget) | **Carrier home, subtarget** |
| `Algebra.Group+Bound.swift`, `+Boundary.swift`, `+Endpoint.swift`, `+Gradient.swift` | Bound/Boundary/Endpoint/Gradient | `swift-finite-primitives` — non-algebra-internal | kind-extension | `swift-finite-primitives/Finite Primitives` (main target) | **Carrier home, main target** |
| `Cardinal+Monoid.swift` | Cardinal | `swift-cardinal-primitives` — non-algebra-internal | carrier-extension `extension Cardinal { static var monoid: Algebra.Monoid<Self>.Commutative }` | `swift-algebra-cardinal-primitives` (separate sibling package) | **Sibling algebra-X package** |
| `Affine.Discrete.Vector+Group.swift` | Affine.Discrete.Vector | `swift-affine-primitives` — non-algebra-internal | carrier-extension | `swift-algebra-affine-primitives` (separate sibling package) | Sibling algebra-X package |
| `Phase+Algebra.swift`, `Rotation+Algebra.swift`, `Shear+Algebra.swift` | Phase/Rotation/Shear | `swift-symmetry-primitives` — non-algebra-internal | carrier-extension | `swift-symmetry-primitives/Symmetry Primitives` (main target) | Carrier home, main target |
| `Sample.Accumulator+Monoid.swift` | Sample.Accumulator | `swift-sample-primitives` — non-algebra-internal | carrier-extension | `swift-sample-primitives/Sample Primitives Core` | Carrier home, main target |

### Principle that emerges

Two ORTHOGONAL axes determine placement:

**Axis 1 — Carrier ownership.** Witnesses for **algebra-internal carriers** (Parity, Algebra.Z<n>, Algebra.Field.Unit) live in the kind's package or co-resident with the carrier's own algebra package. Witnesses for **non-algebra-internal carriers** (Bit, Bound, Cardinal, Affine.Vector, Phase) live with the CARRIER, never in the kind's package.

> No ecosystem evidence places a concrete witness for a non-algebra-internal carrier in the kind's package. Option (B) — move `Algebra.Field<Bit>` to algebra-field-primitives — would be the first such precedent and would invert the kind-package-stays-generic-and-carriers-bring-their-witnesses convention that 11/11 surveyed sites maintain.

**Axis 2 — Granularity (only when carrier home is chosen).** Three sub-patterns, all selected by a single criterion: keep the carrier's main target / Core minimal:

| Sub-pattern | When to use | Examples |
|-------------|-------------|----------|
| Carrier package main target | Main target ALREADY imports the kind (no extra dep) | finite Group witnesses (finite-primitives main already deps algebra-group); Phase+Algebra (symmetry-primitives main already deps algebra-group); Sample.Accumulator+Monoid |
| Carrier package subtarget | Carrier's Core is dep-free or main target should stay free of the algebra dep | **Bit Field Primitives** (bit-primitives Core has zero deps; Bit Field Primitives is the only target that needs algebra-field) |
| Separate algebra-X sibling package | Carrier package's `Package.swift` should stay free of the algebra dep declaration entirely (resolved-graph cleanliness, not just compile cleanliness) | algebra-cardinal-primitives (cardinal-primitives `Package.swift` has zero algebra deps); algebra-affine-primitives |

The choice between subtarget and separate-algebra-X package is essentially: "is keeping the carrier's `Package.swift` algebra-free worth a separate-package overhead?" For Bit today, the subtarget already keeps Bit's Core (and Boolean and SLI) targets compile-clean of algebra-field; the package-level dep declaration is the one remaining cost. The current subtarget pattern is a deliberate midpoint between "main target inline" (which would force Bit's Core to add algebra-field) and "separate package" (which would remove the dep declaration but add ecosystem package count).

**Specialization-cohesion (third axis the dispatch flagged) is real but secondary.** Concrete witnesses do tend to cluster — `Algebra.Field+Parity` and `Algebra.Group+Parity` both in algebra-* because Parity is algebra-internal; `Algebra.Group+Bound/Boundary/Endpoint/Gradient` all in finite-primitives because all four carriers live there. Cohesion follows ownership; ownership doesn't follow cohesion.

### Why the Optic.Iso analogy doesn't generalize cleanly

The dispatch cited the `Optic.Iso → Algebra.Iso` correction (`.z2(via: Algebra.Iso<…>)` factories defined IN algebra-group, not in optic) as evidence supporting Option (B) — "factory methods on a kind's type live in the kind's package." That correction stands BUT it covers the **generic factory** case, not the **concrete witness** case:

- `Algebra.Group.z2(via: Algebra.Iso<Element, Parity>) -> Self` is **generic over Element**. It belongs in algebra-group because it has no specific carrier dependency — algebra-group already has Parity (algebra-internal) and Algebra.Iso (algebra-internal). No external package needed.
- `Algebra.Field<Bit>.z2: Self` is **concrete to Bit**. It requires `Bit` in scope. Placing it in algebra-field requires algebra-field to depend on bit-primitives — inverting the current direction and adding a dep to algebra-field that *every* algebra-field consumer would resolve.

The generic-factory rule (kind home) and the concrete-witness rule (carrier home) are DIFFERENT rules covering different shapes. Both are present in the ecosystem and consistent: algebra-group hosts both `Algebra.Group.z2(via:)` (generic factory, Parity-typed iso) and `Algebra.Group<Parity>.additive` (concrete witness, but for an algebra-internal carrier). algebra-group does NOT host `Algebra.Group<Bound>.z2`, `Algebra.Group<Endpoint>.z2`, `Algebra.Group<Cardinal>.monoid`, etc. — those live with the carrier.

### Comparison

| Criterion | (A) Stay | (B) Move to algebra-field | (C) Extract to algebra-bit | (D) Delete |
|-----------|----------|---------------------------|----------------------------|------------|
| Ecosystem precedent for non-algebra-internal carrier | **11/11 carrier-home** | **0/11** | 2/11 (Cardinal, Affine — both carrier-extension shape) | 0/11 (every site ships a pre-defined concrete witness) |
| Matches Bit's extension shape (kind-extension) | Yes — same shape as Bound/Boundary/Endpoint/Gradient placement | Would be only kind-extension at kind-home for non-algebra-internal carrier | Would require switching to carrier-extension shape (`Bit.field`) to match Cardinal pattern | n/a |
| Direction of dep inversion needed | None (current) | algebra-field gains dep on bit-primitives; reverses current | None (new package depends on both) | None (delete) |
| Bit's Core stays dep-free | Yes (subtarget isolates algebra-field) | Yes (Bit's package would no longer declare algebra-field at all — cleaner than (A)) | Yes (algebra-field declaration moves to swift-algebra-bit-primitives) | Yes |
| bit-primitives `Package.swift` declares algebra-field | Yes (current, package-level dep due to subtarget exception per [MOD-002]) | No | No | No |
| Single-witness-package debt | None | None | Adds a one-witness sibling package — `[MOD-RENT]` consumer criterion weak (linear codes, GF(2) algebra are niche today) | None |
| Discoverability of `Algebra.Field<Bit>.z2` | Good (import Bit Field Primitives or umbrella) | Best (import Algebra Field Primitives is enough) | Good (import Algebra Bit Primitives) | Poor (consumer must know `.z2(via:)` factory and construct iso) |
| Consistency with Bound/Boundary/Endpoint/Gradient placement | **Consistent** — both kind-extension, carrier-home | Inconsistent — those stay in finite, this moves to algebra | Inconsistent — those stay in finite, this extracts | Inconsistent — those keep pre-defined witnesses, this deletes |
| Switching cost | None | Move file; restructure deps; update tests; update doc-strings citing call site | New package + wire-up; bit-primitives Package.swift cleanup; consumer migration | Delete file; consumers absorb iso construction inline |

### Implication for finite-primitives' Group witnesses (the symmetric question)

The dispatch flagged `Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift` (in finite-primitives) as "arguably belong in algebra-group" per `tier-inventory-2026-05-08.md` candidate #1. By the principle surfaced above:

- These four witnesses use **kind-extension** shape on **non-algebra-internal carriers** (Bound/Boundary/Endpoint/Gradient are owned by finite-primitives).
- The ecosystem pattern places kind-extension witnesses for non-algebra-internal carriers with the carrier, never with the kind.
- finite-primitives main target already depends on algebra-group (verified at `swift-finite-primitives/Package.swift`), so the inline-in-main-target sub-pattern fits with no extra dep cost.

**The "arguably belong in algebra-group" tier-inventory note is the same misframing as Option (B) for Bit.** Recommendation: leave finite's Group witnesses where they are. The tier-inventory candidate #1 should be REJECTED on the same axis that rejects Option (B) here. Both reduce to: "concrete witnesses for non-algebra-internal carriers do not live in the kind's package; the ecosystem has zero precedent for that placement, and the eleven existing sites are unanimous."

### Note on Option (D)

Option (D) — delete the witness, rely on `.z2(via:)` factory — would be ecosystem-coherent only if applied uniformly. Today the ecosystem ships pre-defined concrete witnesses for every Z2 carrier (`Parity` in algebra-field/group; `Bound`, `Boundary`, `Endpoint`, `Gradient` in finite; `Bit` in bit). Deleting Bit's while keeping the others would be inconsistent. A "delete pre-defined witnesses ecosystem-wide and lean on generic factories" decision is a different (much larger) question that this dispatch does not pose; out of scope here.

If the orchestrator wants to consider that larger move, it should be a separate research pass covering all 8+ pre-defined Z2 witness sites, not a Bit-specific verdict.

### Inconsistency to flag (does not block this verdict)

The ecosystem has not standardized on extension SHAPE for non-algebra-internal carriers:

- **Carrier-extension** (`extension Carrier { static var monoid: Algebra.Monoid<Self> }`) — used by Cardinal, Affine.Discrete.Vector, Phase, Rotation, Shear, Sample.Accumulator. Call site: `Carrier.witness`.
- **Kind-extension** (`extension Algebra.Kind where Element == Carrier { static var z2: Self }`) — used by Bit, Bound, Boundary, Endpoint, Gradient. Call site: `Algebra.Kind<Carrier>.witness`.

Both shapes coexist. The shape choice cascades into placement viability (carrier-extension shape pairs with separate-algebra-X-package OR carrier-main-target patterns; kind-extension shape pairs with carrier-subtarget OR carrier-main-target patterns; neither shape fits the kind-home pattern for non-algebra-internal carriers).

This is a real ecosystem inconsistency worth orchestrator attention as a SEPARATE question — "which extension shape should new concrete witnesses use?" — but it does not affect the Bit-Field placement verdict. Bit's witness is already kind-extension shape; given that shape, (A) Stay is the placement that matches the ecosystem pattern. If the orchestrator later standardizes on carrier-extension shape and rewrites Bit's witness to `Bit.field`, the placement question would re-open and Option (C) extract-to-algebra-bit would become the natural target (matching Cardinal/Affine). That is a downstream consequence of a separate decision; not relevant today.

### References (added in this section)

- `swift-algebra-primitives/Sources/Algebra Primitives Core/Parity.swift:17` — Parity is owned by algebra-primitives (algebra-internal carrier)
- `swift-algebra-field-primitives/Sources/Algebra Field Primitives/Algebra.Field+Parity.swift` — kind-home witness, algebra-internal carrier
- `swift-algebra-field-primitives/Sources/Algebra Field Primitives/Algebra.Field+Z2.swift` — generic factory `z2(via: Algebra.Iso<Element, Parity>)`, kind-home (correctly)
- `swift-algebra-group-primitives/Sources/Algebra Group Primitives/Algebra.Group+Parity.swift`, `Algebra.Group+Z2.swift` — same pattern as Field
- `swift-bit-primitives/Sources/Bit Field Primitives/Algebra.Field+Bit.swift` — the witness under analysis (carrier-home, subtarget)
- `swift-bit-primitives/Package.swift` — Bit Primitives Core has zero deps; Bit Field Primitives subtarget depends on algebra-field per [MOD-002] variant exception
- `swift-finite-primitives/Sources/Finite Primitives/Algebra.Group+{Bound,Boundary,Endpoint,Gradient}.swift` — symmetric case, carrier-home, main target
- `swift-algebra-cardinal-primitives/Sources/Algebra Cardinal Primitives/Cardinal+Monoid.swift` — sibling-package pattern, carrier-extension shape
- `swift-algebra-affine-primitives/Sources/Algebra Affine Primitives/Affine.Discrete.Vector+Group.swift` — sibling-package pattern, carrier-extension shape
- `swift-symmetry-primitives/Sources/Symmetry Primitives/Phase+Algebra.swift` — main-target pattern, carrier-extension shape
- `[MOD-001]` Core Layer — Bit Primitives Core's zero-dep posture is what makes the subtarget the right granularity here
- `[MOD-002]` External Dependency Centralization — variant-exception clause covers Bit Field Primitives' direct algebra-field dep
- `[MOD-RENT]` Three-Criteria Primitive-Package Rent Test — option (C) extract would create a single-witness package whose consumer criterion is weak today (linear codes / GF(2) algebra are niche)
- `[RES-018]` Premature Primitive Anti-Pattern — same gate against (C)
- `[DS-020]` Gate Before Proposing a New Ecosystem Primitive — same gate against (C)
