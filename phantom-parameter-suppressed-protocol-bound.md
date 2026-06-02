# Phantom-Parameter Suppressed-Protocol Bound

<!--
---
version: 1.0.0
last_updated: 2026-06-01
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
trigger: HANDOFF-phantom-param-escapable-bound.md — spun off from the swift-tagged-collection-primitives Tagged⊗Collection bridge, which had to write `Tag: ~Copyable` because `Index<Tag>` rejects ~Escapable tags. Pure-correctness question; the bridge is NOT blocked.
extends: phantom-typed-value-wrappers-literature-study.md (v1.0.0, Tier 3) — that study settled the Copyable axis of the phantom-tag bound; this doc settles the orthogonal Escapable axis and generalizes to a single maximal-suppression principle.
preceded_by:
  - swift-institute/Research/phantom-typed-value-wrappers-literature-study.md (RECOMMENDATION v1.0.0) — phantom Tag never affects the substructural classification; Tagged keys Copyable/Sendable on RawValue, never Tag.
  - swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md (IMPLEMENTED v1.4.0) — the `Tagged<Tag, T>: X.Protocol where Tag: ~Copyable` operation-lifting pattern.
  - swift-institute/Research/collection-index-escapable-consumer-fallout.md (DECISION v1.3.0) — "Escapable is an operation-level requirement, not intrinsic"; the maximal-permissive-base idiom. THAT doc is about the index VALUE type; THIS doc is about the index's phantom PARAMETER (the a-fortiori case).
  - swift-institute/Research/byte-protocol-capability-marker.md (RECOMMENDATION v1.1.0) — recursive Tagged conformance `where Underlying: Byte.Protocol, Tag: ~Copyable`.
normative: false
---
-->

## Context

`Index<Element>` in `swift-index-primitives` is declared (`Index.swift:38`, **Verified: 2026-06-01**):

```swift
public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>
```

The bound suppresses only `Copyable`; it therefore **requires** `Escapable` of the phantom `Element` — even though `Element` is never instantiated as a value (it is a pure compile-time discriminator; `Tagged` stores only its `Underlying`). The `Tagged⊗Collection` bridge in `swift-tagged-collection-primitives` had to write `Tag: ~Copyable` (`Tagged+Indexed.swift:40`, with the literal comment `// Escapable required: Index<Tag> demands it`) for exactly this reason. The bridge shipped fine and is **NOT blocked**; this is a pure-correctness question spun off for its own investigation per `HANDOFF-phantom-param-escapable-bound.md`.

The companion literature study (`phantom-typed-value-wrappers-literature-study.md`, Tier 3) established the theoretical status of `Tagged` and analysed the **Copyable** axis of the phantom-tag bound — concluding that `Tag: ~Copyable` is "semantically significant" because it enables `Index<Element>` for move-only `Element` (S3). It did not analyse the **Escapable** axis. This document fills that gap and generalises the result to a single principle.

### Scope and exclusions (binding)

Judged **solely on type-system first-principles correctness + evergreen**, per `feedback_correctness_and_evergreen` and `[ARCH-LAYER-008]` (pre-1.0 correctness is the sole driver; `[RES-018]` second-consumer and `[MOD-RENT]` adoption-count criteria **do not apply**). The consumer/demand argument is **explicitly out of scope**: the question is *"is the bound correct?"*, not *"is it needed?"*. The empirical supply-side fact that no consumer currently uses a `~Escapable` tag is recorded nowhere below as evidence for or against the verdict — it is irrelevant to type-system correctness.

## Question

What is the correct suppressed-protocol bound for a **phantom** (never-stored, discriminator-only) generic type parameter — and does the verdict generalise to all `Tagged`-derived phantoms (`Property<Tag>`, `Index`, `Index.Count`, `Index.Offset`, future markers)?

Concretely for the triggering site: is `Element: ~Copyable` (Escapable required) the correct bound on `Index`, or should a phantom parameter be `Element: ~Copyable & ~Escapable` (maximal suppression, matching `Tagged`'s own `Tag` bound)?

## Empirical Ground Truth

### The three-regime inconsistency (Verified: 2026-06-01)

The three canonical phantom-typed wrappers in the ecosystem bind their phantom parameter **three different ways**, with no semantic difference between the phantoms:

| Wrapper | Phantom-parameter bound | Site | Regime |
|---------|-------------------------|------|--------|
| `Tagged<Tag, Underlying>` | `Tag: ~Copyable & ~Escapable` | `Tagged.swift:55` | **maximal suppression** |
| `Index<Element>` = `Tagged<Element, Ordinal>` | `Element: ~Copyable` | `Index.swift:38` | Copyable suppressed, **Escapable required** |
| `Index<T>.Count` = `Tagged<Tag, Cardinal>` | `Tag: ~Copyable` (enclosing ext) | `Ordinal.Protocol.swift:104,110` | Escapable required |
| `Index<T>.Offset` = `Tagged<Tag, …Vector>` | `Tag: ~Copyable` (enclosing ext) | `Tagged+Affine.swift:61` (+ enclosing) | Escapable required |
| `Array.Fixed.Indexed<Tag>` (per-container) | `Tag: ~Copyable` | `Array.Fixed.Indexed.swift:23` | Escapable required |
| `Property<Tag, Base>` | `Tag` *(no suppression)* | `Property.swift:46` | **Copyable AND Escapable both required** |

`Tagged` itself adopted the maximal bound (`Tag: ~Copyable & ~Escapable`). `Index` (a typealias *for* `Tagged`) lags one suppression behind; `Property` lags two. The literature study (2026-02) shows `Tagged` was `Tag: ~Copyable` then; it has since been widened to `~Copyable & ~Escapable`, and the aliases were not updated in lockstep. Three regimes for the same structural role (a never-stored discriminator) is the signature of incidental drift, not deliberate design.

### `Tagged`'s capabilities key on `Underlying`, never on `Tag` (Verified: 2026-06-01)

Every conditional conformance and operation on `Tagged` suppresses **both** protocols on `Tag` and derives the capability from `Underlying`:

| Capability | Constraint (abridged) | Site |
|-----------|------------------------|------|
| `Copyable` | `where Tag: ~Copyable & ~Escapable, Underlying: Copyable & ~Escapable` | `Tagged.swift:115` |
| `Escapable` | `where Tag: ~Copyable & ~Escapable, Underlying: Escapable & ~Copyable` | `Tagged.swift:116` |
| `Sendable` | `where Tag: ~Copyable & ~Escapable, Underlying: … Sendable & Escapable` | `Tagged.swift:126` |
| `Equatable` / `Hashable` / `Comparable` (`==`, `<`) | `where Tag: ~Copyable & ~Escapable, Underlying: … & Escapable` | `Tagged.swift:139–188` |
| `map` / `retag` | `where Tag: ~Copyable & ~Escapable, Underlying: ~Copyable` | `Tagged.swift:225,262` |
| `Carrier.Protocol` | `where Tag: ~Copyable & ~Escapable, Underlying: ~Copyable & ~Escapable` | `Tagged+Carrier.Protocol.swift:42` |
| `CustomStringConvertible`, `Collection`, `Sequence`, `Identifiable`, `LosslessStringConvertible` | `where Tag: ~Copyable & ~Escapable, …` | respective SLI files |

This extends the literature study's soundness point #5 — *"`Tagged` is `Copyable` iff `RawValue: Copyable` … `Sendable` iff `RawValue: Sendable`; the phantom `Tag` never contributes to or detracts from these properties"* — to the **Escapable** axis: `Tagged<Tag, U>` is `Escapable` iff `U` is `Escapable`, irrespective of `Tag` (`Tagged.swift:116`). *(Synthesis-verification per `[RES-013a]`: the study cited Copyable at line 69 and Sendable at line 77 as of 2026-02; the principle holds verbatim, with line numbers now :115 / :126 and the Escapable conformance made explicit at :116. **Verified: 2026-06-01.**)*

**This resolves the brief's UNVERIFIED item.** The concern was that relaxing `Index.swift:38` alone might be hollow if the `Tagged` operations consumers use (`Count`, `<`, `retag`) secretly required an `Escapable` tag. They do not: **the entire core operation surface of `Tagged` already carries `Tag: ~Copyable & ~Escapable`**, so it admits `~Escapable` tags today. Relaxing `Index`'s bound to match makes `Index<~EscapableTag>` immediately functional for `==`, `<`, `retag`, `map`, `Sendable`, `Hashable` — it is **sufficient, not hollow**, for the core surface. The residual `Tag: ~Copyable`-only sites (the nine literal conformances `Tagged+Literals.swift:45…`, `Tagged+AtomicRepresentable.swift:26`, the `Tagged+Indexed.swift:40` bridge, the `Ordinal.Protocol` conformance `:104`) are *independent* incidental-drift instances — each gates only its own operation, and `Tagged+Literals`/`AtomicRepresentable` sitting at `~Copyable` while the sibling core conformances sit at `~Copyable & ~Escapable` *within the same package* is itself further evidence of drift.

### Type-system probe (Apple Swift 6.3.2, `swiftlang-6.3.2.1.108`, arm64)

A faithful single-file model mirroring `Tagged`'s exact bounds (`/tmp/phantom-bound-probe/`; `swiftc -typecheck -enable-experimental-feature Lifetimes`):

| Probe | Construct | Result |
|-------|-----------|--------|
| **A (positive)** — `IndexNew<Element: ~Copyable & ~Escapable>` with a `~Escapable` phantom tag | `==`, `<`, `retag(EscTag.self)` all called; value stored in a class stored property and an `Array` | **exit 0** — ops available; the value is itself `Escapable` & `Copyable` (storable in a class field — `[MEM-LIFE-001]` — and an `Array`), because escapability derives from `Ordinal`, not the phantom |
| **B (negative)** — current `IndexOld<Element: ~Copyable>` with a `~Escapable` phantom tag | `func n1(_ x: borrowing IndexOld<NonEscTag>)` | **exit 1** — `error: type 'NonEscTag' does not conform to protocol 'Escapable'` |

Probe B reproduces the limitation; Probe A confirms the relaxation admits the `~Escapable` tag, keeps every operation, and leaves the wrapper's own escapability untouched. *(A `/tmp` model is the right instrument here: the question is purely type-system, and the committed `Index.swift`/`Tagged.swift` must not be edited — `[feedback_convention_vs_typesystem_constraint]`, `[feedback_inpkg_iter_over_tmp_probes]`.)*

## First-Principles Analysis

**1. What `Escapable` constrains.** `Escapable` (SE-0446) is a marker protocol governing whether **values** of a type may outlive the lexical scope that produced them. `T: Escapable` is a demand on the lifetime behaviour of `T`-*values*. It is default-on; `~Escapable` suppresses it.

**2. A phantom parameter is never a value.** In `Tagged<Tag, Underlying>` only `Underlying` is stored (`var underlying: Underlying`, `Tagged.swift:71`); `Tag` appears solely in the type signature. By Reynolds parametricity (literature study S1, Wadler's free theorem), no operation can construct, store, return, or inspect a `Tag`-value. There is no `Tag`-value whose lifetime could escape — so `Tag`'s escapability is never exercised.

**3. A constraint must encode a real requirement of the implementation.** A bound `Tag: P` asserts the implementation *witnesses* capability `P` on a value of `Tag`. `Tagged` witnesses **no** capability of `Tag` (parametricity guarantees this). It never copies a `Tag`-value (so `Copyable` is unneeded) and never stores/returns one (so `Escapable` is unneeded). Both default-on requirements are therefore **vacuous over-constraints**: they shrink the admissible domain of `Tag` while enabling nothing. The maximally-correct bound suppresses every default-on marker: `Tag: ~Copyable & ~Escapable` — exactly what `Tagged` declares (`:55`).

**4. The aliased type already proves the point.** `Index<Element> = Tagged<Element, Ordinal>`. A typealias should not impose a constraint *narrower* than the type it aliases without a requirement justifying the narrowing. `Index`'s `Element: ~Copyable` is strictly narrower than `Tagged`'s `Tag: ~Copyable & ~Escapable`, yet `Index`'s entire surface is inherited from that very `Tagged`, every operation of which already admits `~Escapable` tags. So `Index<T>` can express a strictly **smaller** set of tag domains than the `Tagged<T, Ordinal>` it is *defined to equal* — a definitional inconsistency with no type-system warrant.

**5. The "guards against a meaningless `Index<~EscapableType>`" counter fails on type-system grounds.**
- It is a domain/semantic argument, not a type-system one; the brief restricts judgment to type-system first principles.
- Even semantically it is weak: a `~Escapable` type is a perfectly good *discriminator*; `Index<Element>` never indexes *into* `Element`-values — `Element` is a label, and a `~Escapable` label partitions the index space exactly as any other type does.
- It is **incoherent with the settled Copyable axis.** The same argument forbids `Index<~CopyableType>`, yet the ecosystem deliberately *admits* `~Copyable` tags — `Index.swift:38` suppresses `Copyable` precisely to enable type-safe indices into move-only collections (literature study S3). For a phantom, the Copyable and Escapable axes are symmetric (neither is ever witnessed); admitting one suppression while forbidding the other has no principled basis.
- Constraints are not documentation. If "value-domain intent" merits recording, that is a doc-comment's job; a bound that "documents intent" while encoding no implementation requirement conflates the constraint language (which expresses requirements) with prose.

**6. No reachable future operation can need `Tag: Escapable`.** Such an operation would have to store or return a `Tag`-value — which would make `Tag` non-phantom and contradict `Tagged`'s defining invariant (only `Underlying` is stored). The phantom-ness of `Tag` is a **structural invariant** that permanently guarantees `Tag`'s escapability is irrelevant; the "keep it required in case we need it later" hedge has no reachable justification. This is the exact converse of the `collection-index-escapable-consumer-fallout.md` situation: there the index is a **value**, so escape-operations *can* need `Escapable` (hence the per-operation `where Index: Escapable`); here the phantom is **never** a value, so **no** operation can ever need it.

**7. Ecosystem precedent is unanimous in the maximal direction.**
- `Tagged<Tag: ~Copyable & ~Escapable, …>` — the aliased type itself.
- `Iterator.Protocol`'s `Element: ~Copyable & ~Escapable` — the maximal-permissive-base idiom cited by the collection-index DECISION.
- `collection-index-escapable-consumer-fallout.md` (DECISION, 2026-05-27): even for a **value-bearing** index coordinate — where escapability genuinely matters — the principal chose to *admit* `~Escapable` at the base and require `Escapable` only on escape-operations. **A fortiori**, a phantom that is never a value must admit it.
- `[API-IMPL-007]`'s four-quadrant where-clause file convention treats `~Copyable & ~Escapable` as the canonical maximal base shape.

## Formal Semantics

Extending the literature study's typing rules (which gave phantom-parameter safety and the `retag` rule).

**Escapability derivation (the phantom is phantom in the escapable sense too):**
```
  ────────────────────────────────────────────
  Escapable( Tagged<Tag, U> )  ⟺  Escapable(U)
```
`Tag` does not appear on the right — symmetric to the Copyable rule of the literature study's soundness #5, and witnessed at `Tagged.swift:116`.

**Vacuous-constraint principle.** A bound `Tag: P` is *operative* iff some operation in the type's surface witnesses `P` on a value of type `Tag`. For a phantom `Tag`, no value of type `Tag` is ever formed (parametricity), so no `P` is witnessed; hence every `Tag: P` is *vacuous*. The correct bound suppresses every default-on marker protocol:
```
  Tag phantom in C⟨Tag, …⟩
  ─────────────────────────────────────
  bound(Tag) = ~Copyable & ~Escapable      (maximal suppression)
```

**Soundness of the relaxation `~Copyable → ~Copyable & ~Escapable` on a phantom.**
1. *Monotone domain enlargement.* It only widens the admissible tag set; every existing `Index<EscTag>` use is still well-typed (Probe A, P1). No call site can break.
2. *Conformances unchanged.* `Tagged`'s `Copyable`/`Escapable`/`Sendable`/… all key on `Underlying`; widening `Tag`'s bound changes none of them (Probe A: the relaxed `Index<NonEscTag>` is still `Copyable` & `Escapable`).
3. *Operations preserved.* Every core operation already carries `Tag: ~Copyable & ~Escapable`; widening the alias bound to match cannot remove any (source + Probe A).

Therefore the relaxation is sound and information-preserving: it strictly enlarges expressiveness with no behavioural change to any existing instantiation.

## Options

| Option | Phantom bound | Assessment (type-system only) |
|--------|---------------|-------------------------------|
| **R — Relax to maximal** *(recommended)* | `~Copyable & ~Escapable` | Matches `Tagged`'s own `Tag` bound; encodes the true (zero) requirement; closes the definitional inconsistency; sound (above); a-fortiori-supported by the value-index DECISION. |
| K — Keep `~Copyable` | `~Copyable` (status quo for `Index`) | Retains a vacuous `Escapable` requirement; leaves `Index` narrower than the `Tagged` it equals; incoherent with the admitted `~Copyable` suppression on the same parameter. |
| S — Status quo `Property` | *(no suppression)* | Retains *two* vacuous requirements; strictly worse than K; the most drifted regime. |
| P — Per-operation (mirror collection-index) | suppress at base, re-require on ops | Category error: the collection-index pattern fits a **value** coordinate whose *operations* can need escape. A phantom has no operations that touch a `Tag`-value, so there is nothing to re-require — the pattern degenerates to R. |

## Outcome

**Status: RECOMMENDATION.** The type-system verdict below is **determinate, not tentative** — it is a conclusion from first principles plus empirical confirmation. The RECOMMENDATION status reflects only that (a) the convention should land via `skill-lifecycle`, and (b) the cross-package diff is a coordinated change awaiting authorization (it is not applied here — see *Implementation*).

### Verdict (the principle)

> A **phantom** (never-stored, discriminator-only) generic type parameter MUST be bound `~Copyable & ~Escapable` — maximal suppression. Because the implementation witnesses no capability of a phantom (Reynolds parametricity), every non-suppressed protocol requirement on it is a **vacuous over-constraint**: it shrinks the admissible domain while enabling nothing. The correct bound is therefore the one that demands nothing.

For the triggering site: **relax `Index.swift:38` to `Index<Element: ~Copyable & ~Escapable>`.** The verdict generalises to every `Tagged`-derived phantom: `Index.Count`, `Index.Offset`, `Property<Tag, Base>` (whose `Tag` should gain *both* suppressions), the per-container `*.Indexed<Tag>` wrappers, and any future marker.

**Boundary (do not over-apply).** This rule governs *phantom* parameters only. A `~Copyable` bound on a **stored** value parameter (`Queue<Element>`, `Array<Element>`, `Stack<Element>`, `Pool.Acquire<Resource>`, …) is a *different* question — whether the container should also hold `~Escapable` *values* — governed by the container's value-semantics needs and the `collection-index`-style value analysis, NOT by this rule. The discriminator is: *does any value of the parameter type get stored or flow through an operation?* If no → phantom → this rule. If yes → stored → out of scope here.

### Proposed convention (skill update via `skill-lifecycle`)

Per the CLAUDE.md memory-write guardrail (a project convention belongs in a skill, not a memory), author a new requirement. Recommended home: **`code-surface`**, as a sibling to the phantom-type *naming* rules `[API-NAME-010]` / `[API-NAME-010a]` (which already govern phantom tags), with **`conversions` `[IDX-001]`** updated to cite it (that rule currently reproduces the `~Copyable`-only bound verbatim).

> **[API-NAME-010b] (proposed) — Maximal Suppression on Phantom Parameters.** A generic type parameter that is *phantom* (never stored as a value, never flowing through any operation — a pure compile-time discriminator, e.g. the `Tag` of `Tagged`/`Property` or the `Element` of `Index`) MUST be bound `~Copyable & ~Escapable`. A non-suppressed marker-protocol requirement (`Copyable` and/or `Escapable`) on a phantom parameter is forbidden as vacuous over-constraint. This rule does NOT apply to *stored* value parameters, whose suppression follows the container's value-semantics needs.

The naming `[API-NAME-010b]` is a placeholder; `skill-lifecycle` selects the final ID/home. Mechanisation candidate: an AST rule flagging a `typealias`/`struct`/`enum` generic parameter that is provably phantom (appears only in a `Tagged<P, …>`/`Property<P, …>` position, never in a stored property's type) yet lacks `& ~Escapable`.

### Implementation (concrete diff — RECOMMENDED, NOT applied)

> **Complete execution plan:** a full, mechanically-enumerated cascade plan — all ~117 sites across 23 packages, the dependency-ordered build sequence, per-package build gates, risk analysis, cross-arc coordination, and the skill-codification routing — lives in the sibling doc [`phantom-parameter-bound-cascade-implementation-plan.md`](phantom-parameter-bound-cascade-implementation-plan.md). The per-site sketch below is the original summary; the sibling plan supersedes it for execution.

The diff is **not applied** in this investigation: the deliverable is this research doc; the change is a coordinated cross-package phantom-bound cascade (≥5 packages + DocC), which the brief itself frames as "a coordinated phantom-bound decision." Per `[feedback_no_redundant_long_builds]` (cascade scope > 3 files across packages → hand off, don't grind) and the co-architect discipline (`ask before assuming`), this awaits explicit authorization and per-package build verification (`[RES-023]`: the compile-cleanliness of each edit below is *expected from the type-system analysis but unverified against a real build*; the `/tmp` probe verified the principle, not these packages).

Primary (the triggering site):
```diff
# swift-index-primitives/Sources/Index Primitives/Index.swift:38
-public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>
+public typealias Index<Element: ~Copyable & ~Escapable> = Tagged<Element, Ordinal>
```
DocC mirror in the same package: `Index Primitives.docc/Phantom-Type-Tags.md:14`, `Index.md:34`.

Parallel phantom-declaration sites (apply with the same rationale, each build-verified):
- `swift-ordinal-primitives/.../Ordinal.Protocol.swift:104` — `extension Tagged: Ordinal.Protocol where … Tag: ~Copyable` → `Tag: ~Copyable & ~Escapable` (carries `Index.Count`).
- `swift-affine-primitives/.../Tagged+Affine.swift` — the `Tag: ~Copyable` extension carrying `typealias Offset` (`:61`) → maximal.
- `swift-property-primitives/.../Property.swift:46` — `struct Property<Tag, Base: ~Copyable>` → `struct Property<Tag: ~Copyable & ~Escapable, Base: ~Copyable>`.
- `swift-array-primitives/.../Array.Fixed.Indexed.swift:23` and sibling per-container `*.Indexed<Tag>` wrappers → maximal (consult `project_indexed_wrapper_consolidation` — these wrappers are slated for consolidation into the `Tagged⊗Collection` bridge, so coordinate or fold in).

Parallel operation sites constrained `Tag: ~Copyable` (Escapable-implied) that should also widen for full ecosystem consistency (none block the declaration fix):
- `swift-tagged-primitives/.../Tagged+Literals.swift` — all 9 conformances (`:45,:57,:67,:77,:87,:100,:110,:153,:174`).
- `swift-tagged-primitives/.../Tagged+AtomicRepresentable.swift:26`.
- `swift-tagged-collection-primitives/.../Tagged+Indexed.swift:40` — drop the `// Escapable required: Index<Tag> demands it` comment once `Index` is relaxed.
- Any `Int(bitPattern:)`-family overloads declared `<Tag: ~Copyable>` over `Tagged<Tag, Ordinal>` (per `[CONV-001]`).

Enumeration command for the coordinated cascade (per `[HANDOFF-021]`, re-run at execution time; covers literal and conformance-position forms per `[HANDOFF-040]`):
```bash
grep -rnE ': ~Copyable([,>) ]|: ~Copyable$)' swift-primitives --include="*.swift" \
  | grep -v '/.build/' | grep -v '& ~Escapable' \
  | grep -E 'Tagged<|typealias .*= *Tagged|struct (Index|Property|Indexed)|Tag: ~Copyable'
```
then **classify each hit phantom-vs-stored** before editing (the grep cannot distinguish them; only phantom parameters are in scope).

### What this does NOT recommend

- **No change to stored-value `~Copyable` parameters** (containers, buffers, pools). Their suppression is a separate value-semantics question.
- **No reversal of the collection-index DECISION.** That doc concerns a *value* coordinate; its KEEP-`~Escapable` outcome and this doc's relax-the-phantom outcome are consistent applications of the same maximal-permissive-base principle to two different positions (value vs phantom).
- **No reliance on consumer demand.** The verdict stands independent of whether any `~Escapable`-tagged index ever ships (`[ARCH-LAYER-008]`, `feedback_correctness_and_evergreen`).
- **No claim that the cross-package diff compiles as written.** Each site needs a real build before landing (`[RES-023]`).

### Note on `associatedtype` vs generic-parameter suppression

The protocol-abstraction work records that `associatedtype Domain: ~Copyable & ~Escapable` was *refuted* in 2026-02 ("cannot suppress requirement of an associated type") and only later unblocked for `~Copyable` by the SuppressedAssociatedTypes feature. That limitation is specific to **associated types**. This doc concerns **generic type parameters** of a `typealias`/`struct`, for which `~Escapable` is fully supported today (SE-0446; Probe A, Swift 6.3.2). The two are not to be conflated.

## References

### Internal (institute)
- `swift-institute/Research/phantom-typed-value-wrappers-literature-study.md` (RECOMMENDATION v1.0.0, Tier 3) — **the doc this extends**; phantom-tag theory, S3 Copyable axis, soundness #5 (capabilities key on RawValue not Tag).
- `swift-institute/Research/collection-index-escapable-consumer-fallout.md` (DECISION v1.3.0) — "Escapable is operation-level, not intrinsic"; maximal-permissive-base idiom; the **value**-index axis (this doc's a-fortiori predecessor).
- `swift-institute/Research/protocol-abstraction-for-phantom-typed-wrappers.md` (IMPLEMENTED v1.4.0) — `Tagged<Tag, T>: X.Protocol where Tag: ~Copyable` lifting; the associatedtype-Domain limitation (distinct from generic-parameter suppression).
- `swift-institute/Research/byte-protocol-capability-marker.md` (RECOMMENDATION v1.1.0) — recursive Tagged conformance `where … Tag: ~Copyable`; `[API-NAME-001c]`.
- `swift-institute/Research/tagged-extension-duplication.md` (SUPERSEDED) — historical precursor to protocol-abstraction.

### Source (Verified: 2026-06-01, Apple Swift 6.3.2)
- `swift-index-primitives/Sources/Index Primitives/Index.swift:38` — the bound under investigation.
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift:55,71,115,116,126,139–188,225,262` — Tagged decl + capability conformances keying on Underlying.
- `swift-tagged-primitives/Sources/…/Tagged+Literals.swift`, `Tagged+AtomicRepresentable.swift:26` — within-package `~Copyable`-only drift.
- `swift-tagged-collection-primitives/Sources/…/Tagged+Indexed.swift:40` — the surfacing site (`// Escapable required: Index<Tag> demands it`).
- `swift-property-primitives/Sources/Property Primitives Core/Property.swift:46` — `Property<Tag, Base>` (no suppression).
- `swift-ordinal-primitives/.../Ordinal.Protocol.swift:104,110`; `swift-affine-primitives/.../Tagged+Affine.swift:61`; `swift-array-primitives/.../Array.Fixed.Indexed.swift:23`.

### Empirical artifact
- `/tmp/phantom-bound-probe/{model,positive,negative}.swift` — Apple Swift 6.3.2; Probe A `exit 0`, Probe B `error: type 'NonEscTag' does not conform to protocol 'Escapable'`.

### Swift Evolution
- SE-0446: Nonescapable types (`~Escapable`). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0446-non-escapable.md
- SE-0390: Noncopyable structs and enums (`~Copyable`). https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
- SE-0427: Noncopyable generics. https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md

### Governing rules
- `[ARCH-LAYER-008]` (pre-1.0 correctness sole driver; `[RES-018]`/`[MOD-RENT]` excluded); `feedback_correctness_and_evergreen` (judge ~Copyable/~Escapable adoption on correctness + evergreen, not demand).
- `[IDX-001]` (conversions — reproduces the bound), `[API-NAME-010]`/`[API-NAME-010a]` (phantom-type naming, sibling rules), `[API-IMPL-007]` (four-quadrant where-clause file convention), `[MEM-LIFE-001]` (~Escapable values not storable in class fields — Probe A isolation test).
