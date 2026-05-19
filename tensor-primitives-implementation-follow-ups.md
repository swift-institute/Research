# Tensor-Primitives Implementation: Deferred Follow-Ups

<!--
---
version: 1.1.0
last_updated: 2026-05-17
status: PARTIALLY_RESOLVED
tier: 1
scope: ecosystem-wide
---
-->

## Context

Companion to [`tensor-primitives-and-tensors-package-decomposition.md`](tensor-primitives-and-tensors-package-decomposition.md) v1.2.0. The L1 `swift-tensor-primitives` implementation reached `swift build` clean + `swift test` 21/21 passing + `swift-linter` 0 findings. Three classes of follow-up surfaced during the implementation pass + second-opinion review that did NOT block the 0-finding state but are worth recording for principal disposition. None are ship-blockers; all are quality-of-ecosystem improvements.

## Question

What deferred work surfaced during the tensor-primitives implementation, and what would resolve each item?

## Analysis

### Item A — Three skill-amendment candidates (originally surfaced by the second-opinion review)

The second-opinion review proposed three rule amendments to address lint findings. During implementation, all three findings were resolved via code-side fixes (typed-throws-aware iteration via `Vector<Int>`, layout rename to `Order.Row`/`Order.Column`, `Index<Element>(_unchecked: ...)` constructor). The rule-amendment candidates remain valid observations even though tensor-primitives no longer needs them — other ecosystem packages may benefit.

#### A.1 — `[IMPL-033]` typed-throws exemption shape

**Status (2026-05-17): RESOLVED via Item B Property-accessor adapter** — `var forEach: Property<Range.ForEach, Range<Bound>>` on `Swift.Range` coexists with stdlib's inherited `func forEach(_:) rethrows` from `Sequence`; Swift's overload resolution selects the direct-extension Property path for typed-throws closures while non-throwing call sites continue to resolve to the inherited method. No exemption needed; `[IMPL-033]` applies uniformly because typed-throws contexts now have a working institute-canonical iteration verb on the same `forEach` name. Empirical validation in [`/Users/coen/Developer/swift-institute/Experiments/range-property-typed-throws-iteration/`](../Experiments/range-property-typed-throws-iteration/) (CONFIRMED, cross-module debug + release; ForEachVariant target confirms the `forEach`-named accessor wins typed-throws resolution).

**Observation (historical).** `[IMPL-033]` "counter loop iteration" forbids `for i in 0..<n { ... }` in favor of `.forEach { ... }`. The rule's premise is intent-over-mechanism: a counter loop describes how to iterate; `forEach` describes that we iterate.

The exemption shape: when the iteration body needs to propagate a typed throw (`throws(E)`), stdlib `Range<Int>.forEach` erases the typed throw to `any Error` per [API-ERR-005]. The for-loop preserves the typed throw; `forEach` does not. Forcing the institute-canonical `forEach` in typed-throws contexts therefore costs correctness for adherence.

**Current workaround** (in tensor-primitives): import `swift-vector-primitives` and use `Vector<Int>(...).forEach { ... throws(E) in ... }` — `Vector_Primitives` provides typed-throws-aware iteration that the stdlib Range does not.

**Proposed amendment.** Extend `[IMPL-033]` to recognize typed-throws-context exemption: a `for i in 0..<n { try ... }` loop inside a function declared `throws(E)` is structurally correct, not mechanism-leak. The amendment shape parallels the existing exemption in `[API-NAME-002]` for spec-mirroring identifiers — both recognize that the rule's primary intent (mechanism-vs-intent / nested-vs-compound) admits a principled carve-out where alternative idioms break correctness.

**What resolves this.** Either:
- (a) Amend `[IMPL-033]` to add the typed-throws-context exemption explicitly. Cite `[API-ERR-005]` stdlib-typed-throws-compatibility as the structural reason.
- (b) Add a typed-throws-aware adapter at the institute level (see Item B below); rule then applies uniformly because the typed-throws context has a working `forEach`.

Option (b) is the stronger long-run move because it eliminates the need for the exemption entirely. Option (a) is the smaller short-term move and is sufficient for the immediate ecosystem.

#### A.2 — `[API-NAME-001]` spec-mirror allowlist for linear-algebra / array-programming vocabulary

**Observation.** v1.1.0 of the tensor-primitives doc proposed `Tensor.Layout.RowMajor` / `Tensor.Layout.ColumnMajor` as zero-size phantom witnesses. The names are compound (Row+Major, Column+Major), violating `[API-NAME-001]` Nest.Name. They are also the dominant terms-of-art across NumPy, PyTorch, Eigen, xtensor, ndarray, BLAS, LAPACK — the established spec-mirror vocabulary for n-d array layout.

**Current resolution** (in tensor-primitives v1.2.0): nest under `Order` sub-namespace as `Tensor.Layout.Order.Row` / `Tensor.Layout.Order.Column`. The path encodes "row order" / "column order"; each component is a single token; `Strided` remains a sibling of `Order` because it is the general-form layout, not a member of the canonical-order family.

This resolution works for tensor-primitives but is *more* nested than the prior art. A consumer typing `Tensor.Value<Float, 2, Tensor.Layout.Order.Row>` is reading four-deep nesting where every other library reads "RowMajor".

**Proposed amendment.** Extend `[API-NAME-003]` (specification-mirroring exception) to recognize linear-algebra / array-programming domain vocabulary as a recognized spec-mirror surface — e.g., `RowMajor`, `ColumnMajor`, `Strided`, `Sparse.COO`, `Sparse.CSR`, `Sparse.CSC`, `Diagonal`, `Triangular.Upper`, `Triangular.Lower`. Each is a compound name in English but a single concept in the field. The allowlist parallels the existing exemptions for acronyms (`URL`, `UUID`, `IO`) and spec-namespace forms (`RFC_4122`, `ISO_9945`).

**What resolves this.** A skill update to `[API-NAME-001]` / `[API-NAME-003]` adding a domain-vocabulary-allowlist clause. The allowlist would need curation (which terms qualify?) and review (does the institute want to commit to mirroring NumPy / mdspan / BLAS / Eigen verbatim?). Alternative: stay with the more-nested form indefinitely and accept the verbosity at call sites.

**Disposition note.** The tensor-primitives v1.2.0 resolution is defensible without this amendment. The amendment is opt-in cleanup; without it, future tensor / linear-algebra primitives will face the same naming question and may reach for the same nested-Order workaround.

#### A.3 — `[API-ERR-004]` `try!`-vs-`try` distinction

**Observation.** `[API-ERR-004]` "closure typed throws annotation" requires closures containing `try` inside a `throws(E)` outer to carry an explicit `throws(E)` annotation. The rule's AST walker uses `TryExprSyntax` to detect `try`, but does not distinguish `try!` (force-unwrap, non-propagating) from `try` (propagating). A closure containing only `try!` is structurally non-throwing and does not need a typed-throws annotation; the rule fires anyway.

**Current resolution** (in tensor-primitives v1.2.0): replaced `try!` with `Index<Element>(_unchecked: ...)` institute-canonical unchecked-init at three sites (matmul, subscript, transpose). The unchecked-init expresses the static-guarantee semantic directly and eliminates the `try!` (and thus the rule's misfire).

This is the right fix in tensor-primitives — `try!` is itself a code smell when the precondition is statically guaranteed — but the rule's overgeneralization remains. Other ecosystem packages may have legitimate `try!` sites where no unchecked-init alternative exists; the rule would still misfire there.

**Proposed amendment.** Refine `[API-ERR-004]`'s `TryExprSyntax` walker to skip nodes whose `questionOrExclamationMark.tokenKind == .exclamationMark`. A `try!` cannot propagate; the rule's premise (the closure needs to declare its typed throws) does not apply.

**What resolves this.** A mechanical refinement to the `Lint.Rule.Throws.ClosureAnnotation` AST walker per [`swift-foundations/swift-linter-rules`]. The refinement preserves the rule's actual safety property (don't erase typed throws via `try`) while eliminating the false positive on non-propagating `try!`.

### Item B — Typed-throws iteration ceremony gap

**Status (2026-05-17): RESOLVED via Property-accessor adapter on the `forEach` verb.** Phase A of Option (a) (institute `func forEach<E>(...)` extension on `Range`) was empirically refuted: Swift 6.3.1 overload resolution prefers stdlib's `rethrows` over the typed-throws variant when both are methods on the same type, erasing `throws(E)` to `any Error`. The Property pattern declares `forEach` as a *computed property* returning `Property<Range.ForEach, Range<Bound>>` (rather than a method), which coexists with stdlib's inherited `func forEach(_:) rethrows` — different member kinds. At a typed-throws call site, Swift selects the direct-extension Property accessor; at a non-throwing call site, stdlib's inherited method resolves as before. No call-site syntax change: `(0..<n).forEach { (i) throws(E) in ... }` and `(0..<n).forEach { (i) in ... }` both work, with typed-throws preservation only in the first form. Adapter at `swift-primitives/swift-vector-primitives/Sources/Vector Primitives Core/Swift.Range+ForEach.swift`. Empirical evidence: [`/Users/coen/Developer/swift-institute/Experiments/range-property-typed-throws-iteration/`](../Experiments/range-property-typed-throws-iteration/) (CONFIRMED — `ForEachVariant` target empirically demonstrates property-vs-method coexistence works). Tensor-primitives' 2 ceremony sites migrated; build + tests + lint green.

**Call site (after resolution)**:

```swift
try (0..<Rank).forEach { (axis: Int) throws(Tensor.Broadcast.Error) in
    // typed throw propagates with shape intact
}
```

**Observation (historical).** Adopting `Vector<Int>(...).forEach { axis throws(E) in ... }` for typed-throws-aware iteration is more ceremony than `for axis in 0..<n { try ... }`:

```swift
// for-loop (rejected per [IMPL-033]; preserves typed throws)
for axis in 0..<Rank {
    try validate(axis)
}

// Vector.forEach (current; satisfies [IMPL-033]; preserves typed throws; verbose)
try Vector<Int>(transform: { Int($0) }, count: Cardinal(Rank))
    .forEach { (axis: Int) throws(Tensor.Index.Error) in
        try validate(axis)
    }
```

The ceremony cost is small per site but compounds across the institute — every primitive package faced with the same constraint will produce the same pattern. The institute's intent-over-mechanism preference argues against the for-loop; the institute's typed-throws preference argues against `forEach`; the synthesis (Vector-mediated iteration) is correct but unergonomic.

**What resolves this.** Either:

- (a) **Typed-throws `Swift.Range` extension at the institute level.** A small adapter at `swift-range-primitives` (or a new `swift-range-typed-iteration` module) providing `Swift.Range<Int>.forEach<E>(_ body: (Int) throws(E) -> Void) throws(E)`. The adapter is a one-line `func` that translates the for-loop into a typed-throws form. Consumers write `(0..<n).forEach { ... }` and get typed throws preserved.
- (b) **`Vector.Int.range(_:)` convenience init.** A typed-init on `Vector` that takes a `Swift.Range<Int>` and produces a typed-throws-iterable `Vector<Int>`. Equivalent to (a) at the call site but anchored in `Vector_Primitives` rather than `Range_Primitives`.
- (c) **`Cardinal.indices.forEach<E>(_:)` typed-throws iterator on Cardinal itself.** Anchors the iteration in the cardinal-arithmetic primitive that already exists; aligned with typed indexing per `[CONV-*]`.

Option (a) is the smallest surface; option (c) is the most domain-aligned. Either would let tensor-primitives' `Tensor.Broadcast.align` and `Tensor.Index.Position.validate` use the natural `(0..<Rank).forEach { ... }` form.

**Cross-package observation.** Other ecosystem packages with the same constraint (see Item C) would benefit identically. This is not a tensor-primitives-specific gap.

### Item C — Cross-package observation: for-counter loops in typed-throws contexts elsewhere

**Observation.** During implementation, the subagent observed similar `for axis in 0..<N { try ... }` patterns in:

- `swift-affine-geometry-primitives` — geometric transformations over N-dimensional spaces.
- `swift-algebra-linear-primitives` — matrix/vector arithmetic where each axis iteration needs typed-throws propagation.

These packages presumably either (a) pre-date the strict `[IMPL-033]` enforcement, (b) accept-as-known the lint findings, or (c) have their own workarounds. The institute may want to apply the same `Vector_Primitives` (or future Item B adapter) remediation uniformly.

**What resolves this.** A dispatch (separate from tensor-primitives) auditing the two packages for typed-throws-context counter loops, then applying whichever Item B resolution lands. This is appropriately staged after Item B's adapter (if adopted) — otherwise every package replicates the same `Vector<Int>(transform:count:).forEach` boilerplate.

**Disposition note.** This is purely an observation. The institute may have already addressed it; if so, the observation is moot. If not, the cohort-wide cleanup pass would be the natural place to apply Item B's adapter.

## Outcome

**Status**: DEFERRED.

Each item awaits principal disposition:

| Item | What it asks | What resolves it |
|------|--------------|------------------|
| A.1 | Extend `[IMPL-033]` with typed-throws-context exemption OR adopt Item B's adapter | `/skill-lifecycle` update to `[IMPL-033]` OR Item B adoption |
| A.2 | Extend `[API-NAME-003]` spec-mirror allowlist to linear-algebra vocabulary | `/skill-lifecycle` update with curated domain-vocabulary allowlist |
| A.3 | Refine `[API-ERR-004]` AST walker to distinguish `try!` from `try` | Lint-rule patch at `swift-foundations/swift-linter-rules` |
| B | Add typed-throws `Swift.Range.forEach` extension OR `Vector.Int.range(_:)` OR `Cardinal.indices.forEach` | Small adapter at the appropriate ecosystem package |
| C | Audit `swift-affine-geometry-primitives` + `swift-algebra-linear-primitives` for same-shape findings | Separate dispatch, ideally after Item B |

None of these items block any current ecosystem work. They are surfaced for future principal disposition; the tensor-primitives v1.2.0 implementation stands without them.

## Blog Potential

The Property-accessor pattern for stdlib types (the resolution shape adopted for Item A.1 + Item B) has been captured as a blog idea:
- [BLOG-IDEA-104: Overloading by member kind: coexisting with the standard library](../Blog/_index.json) — currently in `In Progress` (draft at `Blog/Draft/overloading-by-member-kind.md`)

## References

### Internal

- [`tensor-primitives-and-tensors-package-decomposition.md`](tensor-primitives-and-tensors-package-decomposition.md) v1.2.0 — parent doc.
- `/Users/coen/Developer/swift-primitives/swift-tensor-primitives/` — the implemented package.

### Skill rules cited

- `[IMPL-033]` counter-loop iteration (in `/Users/coen/Developer/swift-institute/Skills/implementation/`)
- `[API-NAME-001]` Nest.Name pattern; `[API-NAME-002]` no compound identifiers; `[API-NAME-003]` specification-mirroring names (in `/Users/coen/Developer/swift-institute/Skills/code-surface/`)
- `[API-ERR-001]` typed throws; `[API-ERR-004]` closure typed-throws annotation; `[API-ERR-005]` stdlib typed-throws compatibility (in `/Users/coen/Developer/swift-institute/Skills/code-surface/`)
- `[CONV-*]` typed-index conventions (in `/Users/coen/Developer/swift-institute/Skills/conversions/`)
