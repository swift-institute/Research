# Tensor Primitives and Tensors Package Decomposition

<!--
---
version: 1.2.0
last_updated: 2026-05-17
status: IMPLEMENTED
tier: 3
scope: ecosystem-wide
---
-->

## Changelog

### v1.2.0 (2026-05-17)

L1 swift-tensor-primitives **implemented**; status promoted RECOMMENDATION → IMPLEMENTED. The implementation surfaced three doc-level amendments worth recording:

1. **Layout naming refinement: `Tensor.Layout.RowMajor` / `Tensor.Layout.ColumnMajor` → `Tensor.Layout.Order.Row` / `Tensor.Layout.Order.Column`.** v1.1.0's names violated [API-NAME-001] Nest.Name (compound type names — Row+Major, Column+Major). Resolution: introduce an intermediate `Tensor.Layout.Order` namespace; the canonical orders sit under it as `Order.Row` and `Order.Column`, each a single token. `Tensor.Layout.Strided` remains at the original level as a sibling of `Order` (Strided is the general-form layout admitting arbitrary per-axis strides; Order encodes the restricted-form named orders). Prior art survey: NumPy `'C'`/`'F'`, C++23 mdspan `layout_left`/`layout_right`/`layout_stride`, BLAS `CblasRowMajor`/`CblasColMajor`, Eigen `RowMajor`/`ColMajor`, ndarray `Layout::C`/`Layout::F`. Option F (nested `Order.Row`/`Order.Column`) selected over mdspan-mirror, NumPy-mirror, and formal-math (lex/colex) alternatives on combined institute-rule-conformance + term-of-art-recognizability + call-site-readability axes.

2. **Three structural deviations from v1.1.0 surface (Swift generic-arity constraint).** Swift does not allow `enum Tensor` and `struct Tensor<>` at the same scope. Per [API-NAME-001a] Single-Type-No-Namespace, keep `Tensor` as namespace; rename the value type to `Tensor.Value`. Same constraint forces:
   - `Tensor<Element, Rank, Layout>` → `Tensor.Value<Element, Rank, Layout>`
   - `Tensor.Dynamic<Element>` → `Tensor.Dynamic.Value<Element>` + `Tensor.Dynamic.Shape` (nested rank-erased namespace)
   - `Tensor.Index<Rank>` → `Tensor.Index.Position<Rank>` + `Tensor.Index.Error` (nested per-position namespace)

   These three renames are STAMPED and apply across the doc's type tables, formal-semantics rules, audit-annex examples, and Package.swift skeleton. `Tensor.Shape<Rank>`, `Tensor.Strides<Rank>`, `Tensor.Slice.Specification<Rank>` keep their generic shape (their nested types are only referenced from within extension-on-generic contexts where Rank is in scope).

3. **`swift-vector-primitives` added to L1 deps.** Required for typed-throws-aware iteration in `Tensor.Broadcast.align` and `Tensor.Index.Position.validate`. Stdlib `Range<Int>.forEach` does not preserve typed throws per [API-ERR-005]; `Vector<Int>` from `swift-vector-primitives` provides typed-throws-aware `forEach` that does. Surfaced as an infrastructure-ceremony concern in the v1.2.0 follow-up doc — a thinner adapter (typed-throws `Swift.Range` extension or `Vector.Int.range(_:)` convenience init) is a candidate institute-wide cleanup; not in tensor-primitives scope.

Implementation outcome:
- `swift-tensor-primitives` at `/Users/coen/Developer/swift-primitives/swift-tensor-primitives/` — 51 source files, 5 SwiftPM targets per the v1.1.0 decomposition.
- `swift build` clean. `swift test` 21/21 passing in 15 suites.
- `swift-linter`: **0 findings** after iterative cleanup (initial 207 → cleanup 5 → second-opinion remediation 0).
- Repository remains private and untagged (no `.git` directory; per principal directive).

L3 `swift-tensors` not yet implemented; remains the next dispatch.

Analysis sections preserved verbatim from v1.0.0 / v1.1.0 per [RES-008]. The Audit Annex updated inline to reflect Order.Row / Order.Column naming.

Companion artifact: `tensor-primitives-implementation-follow-ups.md` (v1.0.0, 2026-05-17) — captures three skill-amendment candidates surfaced during implementation, the typed-throws-iteration ceremony gap, and cross-package observation. Status DEFERRED.

### v1.1.0 (2026-05-16)

Three correction passes addressing user feedback on v1.0.0:

1. **Layer-placement correction.** L1 `swift-tensor-primitives` OWNS the `Tensor` type itself and its intrinsic operations. v1.0.0 placed the concrete type at L3, which inverted the ecosystem pattern. Per [ECO-003] L1 holds "irreducible types that higher layers compose"; per [ECO-002] worked example "`Buffer.Ring`: prerequisite for many specs (storage substrate) → L1"; per [ECO-006] L3 is "primitives and standards integrated into reusable infrastructure" (composition of L1+L2, not new types). Every existing L1 package proves this: `Buffer.Aligned` / `Buffer.Linear` / `Buffer.Ring` at `swift-buffer-primitives`, `Linear.Matrix<R, C>` / `Linear.Vector<N>` at `swift-algebra-linear-primitives`, `Complex.Number<Scalar>` at `swift-complex-primitives`, `Tagged<Tag, Underlying>` at `swift-tagged-primitives`. v1.1.0 re-homes the Tensor value type and its intrinsic operations to L1 and repositions L3 `swift-tensors` as the composition layer (matching `swift-json` / `swift-pdf` shape per [ECO-002]). Affected sections: §"Contextualization Step", §"Layer Decomposition", §"SwiftPM Target/Product Decomposition", §"Outcome".

2. **Skill-strict naming + error + file-structure pass per /code-surface.** v1.0.0 introduced [API-NAME-002] violations: `Tensor.MutableView` (compound: Mutable + View) → `Tensor.View.Mutable` per [API-NAME-001] Nest.Name + [API-NAME-008] multi-form Property.View; inconsistent `TensorAxis` / `TensorStorage` / `TensorLayout` text references → nested `Tensor.Axis` / `Tensor.Storage` / `Tensor.Layout` per [API-NAME-001]; typed throws ([API-ERR-001]) made explicit on every fallible operation; protocol typealias on generic types follows hoisted-protocol pattern ([API-IMPL-009]); error types use `Swift.Error` qualification per [PLAT-ARCH-011]; one-type-per-file ([API-IMPL-005]) enumerated for every target. Audit Annex Section A (below) enumerates each corrected site.

3. **Strict modularization + platform pass per /modularization /platform.** SwiftPM target decomposition revised per [MOD-001] Core-internal + [MOD-005] umbrella-only-`@_exported` + [MOD-011] Test Support published + [MOD-024] spine discipline + [MOD-017] Namespace-target evaluation (decided: NOT needed; reasoning in §"L1 SwiftPM Decomposition") + [MOD-026] fine-grained per-type default + [MOD-DOMAIN] factor-the-law. Package.swift Swift settings completed per [PATTERN-005] (Swift 6.3+, Swift 6 language mode, platform floors), [PATTERN-006] (upcoming features), [PATTERN-007] (experimental features for `LifetimeDependence` / `Lifetimes` / `SuppressedAssociatedTypes`). Cross-package conformance via SE-0450 trait-gated dependency ([MOD-014]) specified for `Linear.Matrix<R, C>` ↔ `Tensor` interop. Audit Annex Sections B–D enumerate each rule applied.

Analysis sections preserved verbatim per [RES-008]: §"Step 0 Internal Research Grep", §"Systematic Literature Review", §"Prior Art Survey", §"Theoretical Grounding", §"Formal Semantics", §"Ecosystem Reuse Inventory". The recommendation core stands; only the layer attribution, naming, and SwiftPM shape are amended.

### v1.0.0 (2026-05-16)

Initial Tier-3 research authored from seven parallel subagent surveys (NumPy + ndarray, PyTorch + TensorFlow, JAX + MLX, Eigen + xtensor, ggml + apple/swift-numerics, theoretical grounding, internal ecosystem inventory). Status: RECOMMENDATION; superseded by v1.1.0 on layer placement and skill-conformance dimensions only — analysis sections unchanged.

---

## Context

**Trigger.** A comparative review of `acemoglu/SwiftMetalNumerics` (2026-05-16) surfaced a structural gap in the institute's L1/L3 substrate: the ecosystem has `Linear<Scalar, Space>.Matrix<Rows, Columns>` (compile-time-shaped, stack-inlined) at L1 but no **runtime-shaped n-dimensional array** primitive. Every comparable upstream library — NumPy, PyTorch, TensorFlow, JAX, MLX, Eigen, xtensor, ndarray (Rust), ggml — provides a tensor type distinct from a fixed-rank matrix. SwiftMetalNumerics provides one (`NumericTensor`) but its design fails most institute conventions ([API-NAME-002], [API-ERR-001], [API-IMPL-005], [PRIM-FOUND-001], [MEM-SAFE-024]) and bundles it with platform-specific MPSGraph/Accelerate bindings that belong at L4.

**Constraints.**
- Two new packages: **`swift-tensor-primitives`** at L1 (Foundation-free, atomic, typed-throws, `~Copyable` storage where applicable, OWNS the type per [ECO-003]) and **`swift-tensors`** at L3 (composes L1 + L2 spec layers + other L1s per [ECO-006]).
- Maximal reuse of existing institute infrastructure per `[INFRA-*]` and the "the fix is usually an import" discipline.
- Compatibility with current Swift language reach (Swift 6.3+, value generics SE-0452, variadic type packs SE-0393/SE-0398, no shape arithmetic at the type level, no integer parameter packs).
- Coexistence with `Linear.Matrix<Rows, Columns>` and `Linear.Vector<N>` (fully static) — Tensor is the runtime-shape counterpart, not a replacement.
- Foundation-free at L1 per [PRIM-FOUND-001]; libm-via-L2-shim (`swift-iso-9899`) at L3 per [PLAT-ARCH-008j]; platform-specific compute (Accelerate, MPS, BLAS) deferred to L4 components.

**Timeline.** Recommendation document; no implementation deadline. Implementation is gated on principal authorization.

**Stakeholders.** Principal (architecture commit); future L4 component authors (compute backends, ML libraries, scientific computing); L3 consumers needing runtime-shaped multi-dim arrays.

**[RES-018] classification.** Case **(b) Domain-owned vocabulary at L1**: tensor is a coherent semantic domain (shape, stride, dtype, layout, view, axis, broadcast, contraction, einsum, reduction) with its own vocabulary. Governed by `[MOD-DOMAIN]` alone; no second-consumer hurdle required.

---

## Question

What is the right L1/L2/L3 package decomposition for tensor primitives in the institute ecosystem? Specifically:

1. **Type and concept inventory at each layer** — what types belong at L1 (atomic; the irreducible Tensor value type itself and its intrinsic operations), L2 (specification implementations), L3 (composed foundations integrating L1 + L2)?
2. **Reuse map** — which existing institute primitives feed the tensor design, and how?
3. **Net-new surface** — what genuinely must be authored fresh?
4. **SwiftPM target and product decomposition** — Core internal vs umbrella + variants published, dependency graph, cross-package trait-gated conformances.
5. **Element-type model** — generic over `Scalar` (Swift-idiomatic) vs runtime enum (NumPy/ggml-idiomatic)?
6. **Aliasing model** — `~Copyable` borrow-checked views (Rust-idiomatic) vs ref-counted aliasing (NumPy/PyTorch-idiomatic)?

---

## Step 0: Internal Research Grep [RES-019]

Searched `swift-institute/Research/` and all per-package `Research/` directories on 2026-05-16:

```bash
grep -rli "tensor" /Users/coen/Developer/swift-institute/Research/
# → only zip-primitive-placement.md (incidental)
grep -ril "tensor" /Users/coen/Developer/swift-primitives/*/Research/
# → swift-pair-primitives/Research/pair-prior-art-survey.md (incidental)
# → swift-range-primitives/Research/parallel-iteration-primitives.md (incidental)
# → swift-storage-primitives/Research/split-storage-naming.md (incidental)
```

**No prior tensor research exists.** Adjacent priors referenced:

- [`data-structures-linear-collections-assessment.md`](data-structures-linear-collections-assessment.md) — variant-system audit pattern.
- [`ecosystem-data-structures-inventory.md`](ecosystem-data-structures-inventory.md) v1.0.0 — layer-aware catalog pattern.
- [`buffer-arena-conditional-copyable.md`](buffer-arena-conditional-copyable.md) — conditional-`~Copyable` design pattern.
- [`storage-buffer-abstraction-analysis.md`](storage-buffer-abstraction-analysis.md) — Storage vs Buffer boundary.
- [`copyable-wrapper-vs-multi-buffer-storage.md`](copyable-wrapper-vs-multi-buffer-storage.md) v1.0.1 — refcount-per-copy cost model.

---

## Systematic Literature Review (Kitchenham)

Per [RES-023] (Tier 3 MUST include SLR).

### Research questions

| RQ | Question |
|----|----------|
| RQ1 | What is the universal core data model adopted by production tensor libraries? |
| RQ2 | Where is the design space open (i.e. where do production libraries disagree)? |
| RQ3 | What design patterns in upstream libraries are language-specific and do NOT transfer to Swift? |
| RQ4 | What Swift language features are required to express each shape-typing position? |
| RQ5 | What theoretical constraints does a sound tensor type satisfy? |
| RQ6 | Which existing institute primitives can be reused vs. authored fresh? |

### Search strategy

| Lane | Subject | Primary sources |
|------|---------|-----------------|
| 1 | NumPy + ndarray (Rust) | numpy.org, NEPs, ndarray docs.rs + GitHub source |
| 2 | PyTorch + TensorFlow | pytorch.org docs + ATen/c10 source, tensorflow.org + framework/tensor.h |
| 3 | JAX + MLX | jax.readthedocs.io + JEPs + jax/_src/core.py, ml-explore.github.io + mlx/array.h |
| 4 | Eigen + xtensor | libeigen.gitlab.io + xtensor.readthedocs.io |
| 5 | ggml + apple/swift-numerics | github.com/ggerganov/ggml, github.com/apple/swift-numerics + issue #6 |
| 6 | Theoretical grounding | Dex, Futhark, Hasktorch, Liquid Haskell, Idris, SE-0452/0393/0398, einsum semantics, Selinger 2009 |
| 7 | Internal ecosystem | All `swift-primitives/swift-*/Sources/` + `swift-foundations/swift-*/Sources/` |

### Inclusion criteria

Tensor / n-dimensional array libraries with production deployment OR research languages with formal type-system treatment of arrays. Primary-source verifiable per [RES-020] / [RES-023].

### Exclusion criteria

Domain-specific extensions where the core array model is inherited from a parent library. Blog posts and tutorials without primary-source backing.

### Screening + data extraction

Seven parallel subagent surveys per [RES-020] (parallel subagent verification). Each survey extracted twelve dimensions with primary-source citations tagged `[Verified: 2026-05-16 — <URL>]`. Internal ecosystem inventory authored by an `Explore` agent with file:line citations across forty-plus primitive packages.

### Synthesis

The six findings sections answer RQ1–RQ6 in order. Section "Prior Art Survey" answers RQ1, RQ2; "Contextualization" answers RQ3; "Theoretical Grounding" + "Formal Semantics" answer RQ4, RQ5; "Ecosystem Reuse Inventory" answers RQ6.

---

## Prior Art Survey

Cross-system synthesis answering RQ1 (universal core) and RQ2 (open design space).

### Universal patterns (every surveyed library)

All ten libraries (NumPy, ndarray, PyTorch, TensorFlow, JAX, MLX, Eigen, xtensor, ggml — apple/swift-numerics is the deliberate non-adopter) implement these:

1. **Strided indexing scheme.** Shape + strides + base pointer + element size. Linear-index formula `offset = Σ strides[k] · index[k]`. Pioneered by NumPy [Verified: 2026-05-16 — https://numpy.org/doc/stable/reference/arrays.ndarray.html], adopted verbatim by ndarray, PyTorch's `TensorImpl::sizes_and_strides_`, ggml's `ne[GGML_MAX_DIMS]` + `nb[GGML_MAX_DIMS]`, TensorFlow's `TensorShape`, MLX's `ArrayDesc`.

2. **Zero-copy views via stride manipulation.** Transpose, slice, axis-swap, reshape (when compatible), broadcast (stride-zero) — all metadata operations.

3. **Broadcasting via stride-0.** A length-1 axis on one operand is treated as if extended to the other's length by zero-stride read repetition. Universal trailing-dim alignment rule.

4. **Owned vs view distinction.** Either at runtime (NumPy's `base` + `OWNDATA` flag) or compile time (ndarray's `OwnedRepr` / `ViewRepr` / `OwnedArcRepr` / `CowRepr` storage parameter).

5. **Row-major default; F-order or channels-last as opt-in.** Universal.

6. **Reductions parameterized by axis.** `sum_axis(k)`, `mean_axis(k)`, etc.; `keepdims` flag.

7. **Contiguity as derived property.** NumPy caches `C_CONTIGUOUS` / `F_CONTIGUOUS` flags; ndarray recomputes via `.is_standard_layout()`.

8. **Reshape contract: view-if-possible-else-copy.** NumPy and PyTorch document this view-or-copy non-determinism. PyTorch explicitly flags it as a wart user "shouldn't rely on".

9. **Einsum-shaped abstraction over contractions.** Matmul is `ij,jk->ik`; outer product is `i,j->ij`; trace is `ii->`; transpose is `ij->ji`.

10. **Dtype catalog with promotion rules.** NumPy's hierarchy `complex > floating > integral > boolean` [Verified: 2026-05-16 — https://numpy.org/neps/nep-0050-scalar-promotion.html], PyTorch's same hierarchy + cast restrictions, TensorFlow's category-based promotion.

### Open design space

Where libraries make different commitments:

1. **Rank in the type or not.** NumPy: never (runtime `nd: int`, max 64). ndarray: yes for ≤6 (separate Ix1..Ix6 types), no for >6 (IxDyn heap-backed). PyTorch: never. xtensor: rank-fixed-dims-dynamic via `xtensor<T, N>`. Eigen: fully static. ggml: hard-coded rank 4. JAX: jaxpr-typed Vars carry shape; static-shape requirement under `jit`. MLX: never in type; dynamic graphs.

2. **Dtype erased vs generic.** NumPy: runtime type-erased `PyArray_Descr`, restructured to class hierarchy by NEP 42. ndarray: generic over `A`, monomorphized. PyTorch / TensorFlow: runtime enum. ggml: runtime `ggml_type` enum, with **quantization formats first-class** (Q4_0, Q4_K, ... each is a `ggml_type` with per-type traits).

3. **Aliasing semantics.** NumPy / PyTorch: permitted; runtime overlap-detection or version counters. ndarray: **forbidden** statically by Rust borrow checker. TensorFlow / JAX: arrays immutable.

4. **Storage class in the type.** ndarray's `ArrayBase<S, D>` lifts ownership into the type system. NumPy / PyTorch / TF / MLX / ggml: single tensor type, ownership at runtime.

5. **Stride unit.** NumPy / ggml: bytes. ndarray / PyTorch: element counts.

6. **Lazy vs eager evaluation.** Eager-default: NumPy, PyTorch, ndarray, Eigen, xtensor. Lazy-default: MLX, ggml (op-DAG). Lazy-under-transform: JAX (`@jit`).

7. **Compile-time vs runtime shape polymorphism.** None: NumPy, PyTorch, ndarray, MLX. Trace-cache per shape: JAX `@jit`, MLX `mx.compile`. Symbolic polymorphism: JAX `export.symbolic_shape` with constraint algebra. Compile-time arithmetic: Eigen, Hasktorch typed.

8. **Max rank.** NumPy: 64. ndarray: 6 compile-time. ggml: 4 hardcoded. xtensor: arbitrary.

9. **Indexing power.** NumPy: integer + slice + ellipsis + None + integer-array + boolean-mask. ndarray: integer + slice ONLY — deliberate omission. PyTorch: full NumPy-style.

10. **Autograd integration.** PyTorch: per-tensor `grad_fn`, `requires_grad`, version counters — first-class state on `TensorImpl`. TensorFlow: separate `GradientTape` + `Variable`. JAX: external `jax.grad` transform over functions. ndarray / NumPy / ggml-forward / Eigen / xtensor: no autograd.

11. **Device in the type.** PyTorch: dispatch key (runtime). JAX: device via Sharding/Mesh, decoupled from value. MLX: no device per-array (unified memory). NumPy / ndarray / ggml-host / xtensor / Eigen: implicit CPU.

12. **Buffer-protocol / FFI export.** NumPy: `__array_interface__` + `__array_struct__` + buffer protocol + DLPack. MLX: NumPy buffer-protocol bridge. ndarray: raw pointer + slice + PyO3/numpy crate.

### Documented regrets

| Library | Regret | Source |
|---------|--------|--------|
| NumPy | Value-based promotion (NEP 50 fixes) | https://numpy.org/neps/nep-0050-scalar-promotion.html |
| NumPy | Monolithic dtype (NEP 42 restructures) | https://numpy.org/neps/nep-0042-new-dtypes.html |
| NumPy | `np.matrix` deprecated | https://numpy.org/doc/stable/reference/generated/numpy.matrix.html |
| NumPy | Masked arrays as ndarray subclass (NEP 17 rejected) | https://numpy.org/neps/nep-0017-split-out-maskedarray.html |
| PyTorch | `Variable` class (merged into `Tensor` in 0.4.0) | https://pytorch.org/blog/pytorch-0_4_0-migration-guide/ |
| PyTorch | Flat dispatch keys (replaced by matrix) | http://blog.ezyang.com/2020/09/lets-talk-about-the-pytorch-dispatcher/ |
| PyTorch | `reshape()` view-or-copy non-determinism | https://docs.pytorch.org/docs/2.12/tensor_view.html |
| TensorFlow | Graph-first execution (TF2 inverts) | https://www.tensorflow.org/guide/intro_to_graphs |
| ndarray | `into_shape()` deprecated (ambiguous order) | https://github.com/rust-ndarray/ndarray/blob/master/RELEASES.md (0.16) |
| Eigen | `auto` with expression types | https://libeigen.gitlab.io/eigen/docs-nightly/TopicPitfalls.html |

The institute design avoids each by initial choice. Anti-recommendations enumerated in §"Outcome".

---

## Contextualization Step [RES-021]

Per [RES-021]: a Tier 2+ survey identifying universal patterns MUST concretize each in the ecosystem's type system before classifying absences as gaps.

### Pattern: strided indexing scheme (universal)

**Concretization (L1).** `Tensor.Shape<Rank>` is `InlineArray<Rank, Cardinal>`; `Tensor.Strides<Rank>` is `InlineArray<Rank, Affine.Discrete.Vector>` (signed). Base pointer is `Buffer.Aligned<UInt8>` or `Buffer.Linear<Element>`. Linear offset is computed via `Affine.Discrete.Vector` accumulation. All types compose with existing primitives.

**Cost.** None — this is the right design.

### Pattern: zero-copy views via stride manipulation (universal)

**Concretization (L1).** A view is `Tensor.View<Element, Rank>` (read-only) and `Tensor.View.Mutable<Element, Rank>` (exclusive-borrowed). Both are `~Copyable` and lifetime-bound (`@_lifetime(borrow source)` or equivalent) to an owning `Tensor<Element, Rank>`. Stride manipulation (transpose, slice, axis-swap) produces a new view sharing storage.

**Cost.** Swift's borrow rules + `~Copyable` give Eigen's `auto` trap and runtime-aliasing failures structurally absent: the compiler enforces what Eigen detects via runtime assertion. Friction is real but is *the correctness property* — keep it.

### Pattern: rank-fixed-dims-runtime (xtensor's signature design)

**Concretization (L1).** `Tensor<Element, let Rank: Int, Layout>` where `Rank: Int` is a SE-0452 value generic (shipping Swift 6.2 / supported in 6.3). Shape is a runtime `Tensor.Shape<Rank>` instance property. Indexing arity is type-checked: `tensor[i, j, k]` on `Tensor<Float, 3, _>` typechecks; on `Tensor<Float, 2, _>` it doesn't.

**Cost.** SE-0452 admits only `==` constraints, no arithmetic. Operations changing rank (squeeze, unsqueeze, reduce-removing-axis) cannot be type-level generic in `Rank`. Workaround: provide concrete-rank overloads for the small-rank cases (rank 1–4), erase to `Tensor.Dynamic<Element>` for rank-change operations beyond that. When SE-0452's arithmetic future-direction lands, the design can be tightened without breaking the API.

**Verdict: ADOPT.**

### Pattern: fully compile-time shape (Eigen, xtensor_fixed)

**Verdict: DO NOT ADOPT** at L1 swift-tensor-primitives. `Linear.Matrix<Rows, Columns>` already occupies the compile-time-shape slot for rank-2 in `swift-algebra-linear-primitives`; future rank-3 / rank-4 fully-static needs are served by extending `Linear` (e.g. `Linear.Tensor3<D0, D1, D2>`), not by a parallel hierarchy. The runtime-shape Tensor and the compile-time-shape Linear.Matrix are complements, not competitors.

### Pattern: Dex-style named axes

**Concretization (L1).** `Tensor.Named<Element, repeat each Axis>` where each axis is a type conforming to `Tensor.Axis.Protocol` with an associated `static var size: Int`. So `Tensor.Named<Float, Image.Height, Image.Width, RGB.Channel>` is a different type from `Tensor.Named<Float, RGB.Channel, Image.Height, Image.Width>`. Operations on shapes act on the variadic type pack of axes.

**Cost.** SE-0398 supports the pattern; SE-0393 provides runtime pack expansion. Users must author axis types as first-class entities. This is verbose but type-safe.

**Verdict: ADOPT as opt-in variant.** Default surface is positional `Tensor<Element, Rank, Layout>` (runtime shape). Users wanting Dex-style axis identity opt into `Tensor.Named<Element, repeat each Axis>` via a separate variant target.

### Pattern: storage class in the type (ndarray)

**Concretization (L1).** Three SEPARATE TYPES sharing a protocol surface, not a storage generic parameter:

- `Tensor<Element, Rank, Layout>` — owned (`~Copyable` if Element is or storage demands; conditionally Copyable otherwise).
- `Tensor.View<Element, Rank, Layout>` — borrowed read-only (`~Copyable, ~Escapable`).
- `Tensor.View.Mutable<Element, Rank, Layout>` — exclusive-borrowed mutable (`~Copyable, ~Escapable`).

**Cost.** Three types per shape-rank combination instead of one parameterized type, but the institute idiom is *Swift exclusivity + `~Copyable` + lifetime annotations* — which is structurally stronger than ndarray's compile-time discrimination and structurally simpler than NumPy's runtime ref-count + `base` pointer.

**Verdict: ADOPT** via distinct types under `Tensor.View.*` hierarchy per [API-NAME-001].

### Pattern: ggml's tensor-IS-graph-node + quantization-as-element-type

**Verdict: DO NOT ADOPT at L1.** The op-DAG-inline-in-the-tensor pattern conflicts with eager-by-default + `~Copyable` borrow checking. Defer compute-DAG semantics to L4 (`swift-compute-graph` or similar) where lazy fusion can be expressed. Quantization (Q4_K etc. as element types) stays at L4 (`swift-quantization-component`) — L1 tensor stays scalar-generic.

### Pattern: NumPy's `__array_interface__` / DLPack export

**Verdict: ADOPT AS DEFERRED.** A separate L2 `swift-dlpack-standard` package implements the DLPack v0.x spec (https://dmlc.github.io/dlpack/) with case-(d) spec-mirroring per [RES-018]. Bridge code at L3 `swift-tensors`. Defer until a concrete L4 consumer needs DLPack interop.

---

## Theoretical Grounding

Per [RES-022] (Tier 2+ SHOULD) + [RES-024] (Tier 3 MUST include formal semantics inline).

### Tensor as multilinear map

A tensor of type `(p, q)` over a vector space `V` is a multilinear map `V* × ... × V* × V × ... × V → k` with `p` copies of `V*` and `q` of `V`. Covariant (lower) indices ↔ `V` arguments; contravariant (upper) ↔ `V*`. Library-grade tensors drop the variance distinction and require only size match. (Standard textbook material; Lee, *Introduction to Smooth Manifolds*, ch. 12.)

### Monoidal-category structure

`Vect_k` is a symmetric monoidal category under `⊗`: objects are types, morphisms are linear maps, unit `k`, associator `(A ⊗ B) ⊗ C ≅ A ⊗ (B ⊗ C)`, symmetry `A ⊗ B ≅ B ⊗ A`. Compact closed: every object `V` has dual `V*` with `η : k → V ⊗ V*` and `ε : V* ⊗ V → k`. Contraction *is* `ε`. (Selinger 2009, *A survey of graphical languages for monoidal categories* — [Verified: 2026-05-16 — https://arxiv.org/abs/0908.3347].)

### Einsum as the primitive contraction

Wenig et al. (2025, [Verified: 2026-05-16 — https://arxiv.org/abs/2509.20020]) formalize einsum: for each output assignment, sum-of-products over remaining indices, evaluated in a chosen semiring. Three algebraic equivalences proven: commutativity, associativity, distributivity. Einsum is *the* binary primitive: matmul is `ij,jk->ik`; outer product is `i,j->ij`; trace is `ii->`; transpose is `ij->ji`; dot is `i,i->`.

### Functoriality + broadcasting

`Tensor s : Type → Type` (fixing shape) is a functor: `map : (a → b) → Tensor s a → Tensor s b` with `map id = id`, `map (g ∘ f) = map g ∘ map f`. Stronger: bifunctor in `(Shape, Element)`. Naturality square `map f ∘ reshape σ = reshape σ ∘ map f` is the algebraic version of "fusion is sound". Broadcasting is a natural transformation between shape functors; naturality (map-f commutes with broadcasting) is the type-theoretic justification for treating broadcasting as a structural part of the language.

### Swift's reach (verified May 2026)

Three composing language mechanisms:

1. **SE-0393 (Value and Type Parameter Packs)** [Verified: 2026-05-16 — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md]: `func f<each T>(_: repeat each T)`. Type packs. Explicitly bars arithmetic on pack shapes.

2. **SE-0398 (Variadic Generic Types)** [Verified: 2026-05-16 — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md]: lifts packs into type declarations. At most one type parameter pack per type. Type-only.

3. **SE-0452 (Integer Generic Parameters)** [Verified: 2026-05-16 — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md] — shipping Swift 6.2: `struct Vector<let count: Int, Element>`. Only `Swift.Int`, only `==` constraints, only literal/parameter-reference arguments. **Arithmetic (`n+m`, `n*m`) is explicit Future Direction.** Integer parameter packs Future Direction.

The Swift n-d tensor frontier as of May 2026:
- **Reachable today**: fixed-rank tensor with `let Rank: Int`; Dex-style named axes via type packs; runtime-shape with compile-time rank.
- **Out of reach without further evolution**: `Tensor<N+M>` (shape arithmetic), `Tensor<each let N: Int>` (Int packs), refinement-typed shape, full dependent types.

### What cannot be encoded

The hard limit: **data-dependent shapes**. `where(mask, x)` produces a tensor whose length is `sum(mask)`. No static type system can express this without existentials (Futhark) or runtime-checked refinement (Liquid Haskell) or dynamic-rank type. Operations whose output shape is data-dependent (`filter`, `where`, `unique`, `nonzero`) return `Tensor.Dynamic` (rank known, dims runtime-checked).

---

## Formal Semantics

Per [RES-024]. Typing rules using `Γ ⊢ e : T` notation.

### Notation

- `Tensor[s] a` = tensor with shape `s` (list of `Int` cardinalities) and element type `a`. Swift surface: `Tensor<a, let Rank: Int, Layout>` with rank value-generic.
- `Fin n` = type of integers `i` with `0 ≤ i < n`. Swift: `Ordinal.Finite<n>`.
- `Rank` = compile-time rank parameter.
- `Strides[s]` = stride array compatible with shape `s`.

### T-INDEX (single-axis indexing)

```
Γ ⊢ T : Tensor[d₁, …, dₙ] a       Γ ⊢ i : Fin d₁
─────────────────────────────────────────────────  (T-INDEX)
Γ ⊢ T[i] : Tensor[d₂, …, dₙ] a
```

Swift surface: `subscript(_ i: Ordinal.Finite<d₁>) -> Tensor<a, n-1>` — rank reduction `n-1` not expressible today (SE-0452 lacks arithmetic); workaround is per-concrete-rank overloads.

### T-MULTI-INDEX (full coordinate indexing)

```
Γ ⊢ T : Tensor[d₁, …, dₙ] a       Γ ⊢ i₁ : Fin d₁  …  Γ ⊢ iₙ : Fin dₙ
─────────────────────────────────────────────────────────────────────  (T-MULTI-INDEX)
Γ ⊢ T[i₁, …, iₙ] : a
```

Swift surface: single subscript taking variadic generic indices pack or `InlineArray<Rank, Ordinal>`. Bounds-checks runtime; types guarantee arity.

### T-SLICE (slicing along one axis)

```
Γ ⊢ T : Tensor[d₁, …, dₙ] a       Γ ⊢ r : Range d₁
─────────────────────────────────────────────────  (T-SLICE)
Γ ⊢ T[r] : Tensor[len r, d₂, …, dₙ] a
```

For runtime range, `len r` is existentially quantified — output type carries `Rank` but leading dim is runtime-only.

### T-RESHAPE

```
Γ ⊢ T : Tensor[d₁, …, dₙ] a       d₁ · ⋯ · dₙ = e₁ · ⋯ · eₘ
───────────────────────────────────────────────────────────  (T-RESHAPE)
Γ ⊢ reshape[e₁, …, eₘ] T : Tensor[e₁, …, eₘ] a
```

Product-equality premise: runtime check throwing `Tensor.Reshape.Error` per [API-ERR-001].

### T-BROADCAST (binary)

Shape unification operator `⊔`:

```
[] ⊔ s         = s
s ⊔ []         = s
(d :: s) ⊔ (1 :: s')   = d :: (s ⊔ s')
(1 :: s) ⊔ (d :: s')   = d :: (s ⊔ s')
(d :: s) ⊔ (d :: s')   = d :: (s ⊔ s')
(d :: s) ⊔ (d' :: s')  = ⊥                  when d ≠ d', neither is 1
```

```
Γ ⊢ T : Tensor[s] a       Γ ⊢ U : Tensor[s'] a       s ⊔ s' = s''
─────────────────────────────────────────────────────────────────  (T-BCAST)
Γ ⊢ T ⊙ U : Tensor[s''] a
```

Operationally: broadcast operand's stride at stretched axis = **zero**.

### T-EINSUM (contraction)

For einsum spec `i₁i₂…iₖ, j₁j₂…jₗ → o₁o₂…oₘ`:
- Free indices `F = {o₁, …, oₘ}` appear in output.
- Contracted indices `C = ({iₛ} ∪ {jₛ}) \ F` are summed over.

```
Γ ⊢ T : Tensor[d_{i₁}, …, d_{iₖ}] a       Γ ⊢ U : Tensor[d_{j₁}, …, d_{jₗ}] a
∀ x ∈ ({iₛ} ∩ {jₛ}). d_x ∈ T  =  d_x ∈ U                  (size compatibility)
F = {o₁, …, oₘ},  C = ({iₛ} ∪ {jₛ}) \ F
────────────────────────────────────────────────────────────────────────────  (T-EINSUM)
Γ ⊢ einsum(T, U) "…→…" : Tensor[d_{o₁}, …, d_{oₘ}] a
```

Operational: `result[o₁, …, oₘ] = Σ_{c₁, …, c_|C|} T[…] · U[…]` over a chosen semiring.

### Soundness invariant

Every Tensor value's runtime shape equals its static shape (or, for existentially-quantified shapes, runtime witness inhabits the existential). Progress + preservation by structural induction over typing rules. Reshape and slicing are the interesting cases; both are checked at construction time via `Tensor.Shape.Error` / `Tensor.Slice.Error` typed throws per [API-ERR-001].

### Operational model in Swift

Soundness enforced by:

1. **Construction-time checks**: `Tensor.init(shape:elements:)` validates `shape.product == elements.count` or throws `Tensor.Shape.Error`.
2. **Slicing returns a typed view**: `Tensor.slice(_:axis:)` constructs `Tensor.View` with computed shape.
3. **Broadcasting alignment**: `Tensor.Broadcast.align(_:_:)` throws `Tensor.Broadcast.Error` on incompatible shapes.
4. **Stride invariants**: stride values validated against shape at view construction.
5. **Borrow-check enforcement**: `Tensor.View.Mutable` cannot coexist with any other view of overlapping memory (Swift exclusivity + `~Copyable, ~Escapable`).

Type-safe at compile time for parts the type system expresses (rank arity, scalar type, layout witness); runtime-checked-via-typed-throws for the rest.

---

## Ecosystem Reuse Inventory

Authored by parallel `Explore` subagent on 2026-05-16 with file:line citations.

### Indexing / position / size

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Index<Element>` (= `Tagged<Element, Ordinal>`) | `swift-index-primitives/.../Index.swift:38` | `Index<Tensor.Axis>` for type-safe axis subscripts |
| `Ordinal` | `swift-ordinal-primitives/.../Ordinal.swift:39` | Flat indices, strides, offsets |
| `Cardinal` | `swift-cardinal-primitives/.../Cardinal.swift:37` | Dimension cardinalities |
| `Axis<N>` | `swift-dimension-primitives/.../Axis.swift:23` | 0-based axis index in `[0, N)`, compile-time bounded |
| `Finite.Bound<N>` | `swift-finite-primitives/.../Finite.swift:59` | Phantom tag for `[0, N)` bounded values |
| `Ordinal.Finite<N>` | `swift-finite-primitives/.../Ordinal.Finite.swift` | Position in bounded set |

### Storage / buffer / memory

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Buffer.Aligned: ~Copyable` | `swift-buffer-primitives/.../Buffer.Aligned.swift:67` | Page-aligned storage; GPU-bridge composes with `System.pageSize.alignment` |
| `Buffer.Linear<Element>` | `swift-buffer-primitives/.../Buffer.Linear/` | Default heap-backed element storage |
| `Buffer.Linear.Inline<capacity>` | `swift-buffer-primitives/.../Buffer.Linear.swift:54` | Stack storage for small fixed-shape tensors |
| `Storage.Heap<Element>` | `swift-storage-primitives/.../Storage.swift` | Tracked heap with `Storage.Initialization` |
| `Memory.Address` | `swift-memory-primitives/.../Memory.Address.swift:54` | Byte-level offset arithmetic |
| `Memory.Alignment` | `swift-memory-primitives/.../Memory.Alignment.swift:31` | Power-of-2 alignment |
| `Memory.Alignment.alignUp(_:)` | `swift-memory-primitives/.../Memory.Alignment.Align.swift` | Length-rounding for GPU-bridge zero-copy |
| `Memory.Contiguous.Protocol` | `swift-memory-primitives/.../Memory.ContiguousProtocol.swift` | Contract for contiguous element views |

### System / page

| Type | Location | Tensor Role |
|------|----------|-------------|
| `System.Page.Size` (= `Tagged<System.Page, Cardinal>`) | `swift-system-primitives/.../System.Page.swift:45` | Runtime page size (typed) |
| `Memory.Alignment.init(_:System.Page.Size)` | `.../System.Page+Alignment.swift:21` | Page size → alignment |
| `System.pageSize` (L3) | `swift-kernel/.../` | Cross-platform runtime accessor |

### Affine / offset arithmetic

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Affine.Discrete.Vector` | `swift-affine-primitives/.../Affine.Discrete.Vector.swift:35` | Signed stride/displacement |
| `Memory.Address + Affine.Discrete.Vector` | `swift-affine-primitives/.../Tagged+Affine.swift` | Pointer arithmetic without provenance loss |

### Numeric / algebra / linear

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Numeric` protocol | `swift-numeric-primitives/.../Numeric.swift` | Element constraint base |
| `Complex.Number<Scalar>` | `swift-complex-primitives/.../Complex.swift:45` | Complex tensor elements |
| `Algebra.Ring<Element>` | `swift-algebra-ring-primitives/.../Algebra.Ring.swift:27` | Element-ring constraint for matmul |
| `Algebra.Field<Element>` | `swift-algebra-field-primitives/.../Algebra.Field.swift:31` | Element-field constraint for invertibles |
| `Algebra.Module<Scalar, Element>` | `swift-algebra-module-primitives/.../Algebra.Module.swift` | Generalized vector space |
| `Linear<Scalar, Space>.Matrix<R, C>` | `swift-algebra-linear-primitives/.../Linear.Matrix.swift:19` | **Compile-time-shape reference design** |
| `Linear<Scalar, Space>.Vector<N>` | `swift-algebra-linear-primitives/.../Linear.Vector.swift:18` | **Reference design** |

### Tagged / phantom / witness

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Tagged<Tag, Underlying>` | `swift-tagged-primitives/.../Tagged.swift:55` | Phantom typing |

### Format / error / sequence

| Type | Location | Tensor Role |
|------|----------|-------------|
| `Format.Style` | `swift-format-primitives/.../Format.swift:12` | `Format.Tensor` style at L3 |
| `Error.Context` etc. | `swift-error-primitives/.../Error.swift` | Wrap tensor errors |
| `Sequence.Protocol` | `swift-sequence-primitives/.../` | Tensor flattened iteration view |

---

## Layer Decomposition

### Layer 1: `swift-tensor-primitives` (new) — OWNS the type

**Mission**: provide the irreducible `Tensor<Element, Rank, Layout>` value type and its intrinsic operations as L1 primitives, Foundation-free, typed-throws, `~Copyable`-aware. L1 owns the type per [ECO-003]; consistent with `Buffer.Ring`, `Linear.Matrix<R, C>`, `Complex.Number<Scalar>`, `Tagged<Tag, Underlying>` placement.

**Domain vocabulary** ([MOD-DOMAIN], [RES-018] case (b)):

| Type | Purpose | Reuse |
|------|---------|-------|
| `Tensor` (enum namespace) | Domain umbrella | — |
| `Tensor<Element, let Rank: Int, Layout>` | **Primary owned value type** | `Buffer.Linear` storage; `Tensor.Shape`/`Tensor.Strides` metadata |
| `Tensor.View<Element, Rank, Layout>` | Read-only borrowed view (`~Copyable, ~Escapable`) | Lifetime-bound to owner |
| `Tensor.View.Mutable<Element, Rank, Layout>` | Exclusive-borrowed mutable view (`~Copyable, ~Escapable`) | Per [API-NAME-001] Nest.Name + [API-NAME-008] (mutable is a variant of view) |
| `Tensor.Dynamic<Element>` | Rank-erased (data-dependent shapes from `filter`/`where`/`unique`) | Carries `Tensor.Shape.Dynamic` |
| `Tensor.Named<Element, repeat each Axis>` | Dex-style named-axis overlay (SE-0398) | Axes conform to `Tensor.Axis.Protocol` |
| `Tensor.Shape<let Rank: Int>` | Compile-time-rank, runtime-dim shape | `InlineArray<Rank, Cardinal>` |
| `Tensor.Shape.Dynamic` | Rank-erased shape for `Tensor.Dynamic` | `Buffer.Linear<Cardinal>` |
| `Tensor.Strides<let Rank: Int>` | Per-axis signed strides | `InlineArray<Rank, Affine.Discrete.Vector>` |
| `Tensor.Offset` | Element offset from buffer base | `Ordinal` |
| `Tensor.Axis` (namespace) | Axis identity + protocol | — |
| `Tensor.Axis.Protocol` (hoisted per [API-IMPL-009]) | Witness with static `size: Int` for named-axis overlay | — |
| `Tensor.Index<let Rank: Int>` | Multi-axis position | `InlineArray<Rank, Ordinal>` |
| `Tensor.Slice<let Rank: Int>` | Multi-axis range type | — |
| `Tensor.Slice.Axis` | Per-axis range (full / range / single / newaxis) | enum |
| `Tensor.Layout` (namespace) | Layout witnesses | — |
| `Tensor.Layout.Protocol` (hoisted per [API-IMPL-009]) | Witness protocol | — |
| `Tensor.Layout.Order` | Sub-namespace for canonical row/column orders | — |
| `Tensor.Layout.Order.Row` | C-contiguous witness (formerly RowMajor; v1.2.0) | zero-size struct |
| `Tensor.Layout.Order.Column` | F-contiguous witness (formerly ColumnMajor; v1.2.0) | zero-size struct |
| `Tensor.Layout.Strided` | Arbitrary-stride witness (sibling of `Order`, NOT nested under it) | zero-size struct |
| `Tensor.Broadcast` (namespace) | Broadcast operations | — |
| `Tensor.Broadcast.align(_:_:)` | Shape unification (NumPy trailing-dim rule) | — |
| `Tensor.Storage` (namespace) | Storage policy witnesses | — |
| `Tensor.Storage.Owned` | Owned-storage witness | wraps `Buffer.Linear<Element>` |
| `Tensor.Storage.Aligned` | Page-aligned witness (for GPU-bridge prep) | wraps `Buffer.Aligned<UInt8>` |
| `Tensor.Shape.Error` | Typed error per [API-ERR-001/002] | `Swift.Error`-conforming enum |
| `Tensor.Broadcast.Error` | Typed | same |
| `Tensor.Slice.Error` | Typed | same |
| `Tensor.Reshape.Error` | Typed | same |
| `Tensor.Index.Error` | Typed | same |

**Intrinsic operations at L1** (only those reachable with stdlib constraints + L1 primitives; no libm, no Foundation, no platform-C per [PRIM-FOUND-001] / [PLAT-ARCH-008j]):

| Operation | Constraint | Mechanism |
|-----------|------------|-----------|
| Subscript single-axis: `tensor[i]` for `i: Ordinal.Finite<d>` | none | Compile-time bounds |
| Subscript multi-axis: `tensor[i₁, …, iₙ]` | none | Variadic indices |
| Slice along axis: `tensor.slice(_:axis:)` returns `Tensor.View` | none | Stride manipulation |
| Transpose: `tensor.transposed()` | none | Stride swap (zero-copy view) |
| Permute axes: `tensor.permuted(axes:)` | none | Stride permutation |
| Reshape (view-or-copy): `tensor.reshape(_:)` throws `Tensor.Reshape.Error` | none | Returns `Tensor`; copies if not stride-compatible |
| Reshape (view-only): `tensor.reshaping(_:)` throws `Tensor.Reshape.Error` | none | Returns `Tensor.View`; throws on non-contiguous |
| Broadcast view: `tensor.broadcast(to:)` throws `Tensor.Broadcast.Error` | none | Stride-zero on stretched axes |
| Element-wise binary `+` `-`: `tensor + tensor` | `Element: AdditiveArithmetic` | Broadcast.align + flat iter |
| Element-wise multiply `*`: `tensor * tensor` | `Element: Numeric` | Broadcast.align + flat iter |
| Element-wise negate `-tensor` | `Element: SignedNumeric` | Flat iter |
| Scalar-multiply: `tensor * scalar` | `Element: Numeric` | Flat iter |
| Sum reduction along axis | `Element: AdditiveArithmetic` | Stride-aware reduction |
| Product reduction along axis | `Element: Numeric` | Stride-aware reduction |
| Min/max along axis | `Element: Comparable` | Stride-aware reduction |
| Pure-Swift matmul: `tensor.multiplied(by:)` for rank-2 | `Element: Algebra.Ring.Carrier` (or `Numeric`) | Naive O(n³) via nested `+` and `*` |
| Map: `tensor.map(_:)` | none, typed throws on closure error | Functor |
| Contiguity-gated raw access: `tensor.withContiguousElements(_:)` throws | layout precondition | Closure receives `UnsafeBufferPointer<Element>` only if contiguous |

**Notably absent from L1** (deferred to L3):

- Transcendental element-wise (`exp`, `log`, `sin`, `cos`, …) — requires libm, lives at L3 per [PLAT-ARCH-008j].
- FFT — requires sin/cos from libm.
- Einsum compiler — composes parser primitives + Tensor; sits at L3 as a composition.
- Matmul-with-BLAS-dispatch — composes L2 `swift-blas-standard` (when authored).
- Pretty-print formatter — composes `swift-format-primitives` + Tensor; sits at L3.

### Layer 2: deferred

Two viable candidates surfaced in the survey:

- **`swift-dlpack-standard`** — DLPack v0.x spec, [API-NAME-003] spec-mirroring (`DLPack.ManagedTensor`, `DLPack.Device`, `DLPack.DataType`).
- **`swift-array-api-standard`** — Python Array API standard; Python-centric, lower priority.

**Recommendation: defer both.** L1 + L3 ship without L2 spec packages. When a concrete L4 consumer needs DLPack interop, author `swift-dlpack-standard` then. Case-(c)/(d) pull-down per [RES-018].

### Layer 3: `swift-tensors` (new) — composes L1 + L2

**Mission**: compose L1 `swift-tensor-primitives` with L2 specs (libm via `swift-iso-9899`) and other L1 primitives to deliver reusable infrastructure. Matches the `swift-json` / `swift-pdf` shape per [ECO-002]/[ECO-006]: L3 owns composition, NOT new types.

**L3 surface** (compositions only — no new Tensor type):

| Composition | What it composes | Why L3 |
|-------------|------------------|--------|
| Transcendental element-wise tensor ops (`tensor.exp()`, `tensor.log()`, `tensor.sin()`, `tensor.cos()`, `tensor.sqrt()`, etc.) | L1 `Tensor` + L2 `swift-iso-9899` (libm) per [PLAT-ARCH-008j] | L1 cannot bind libm |
| Element-wise complex ops (extends `Tensor<Complex.Number<Scalar>, Rank, Layout>`) | L1 `Tensor` + L1 `Complex.Number` + L2 `swift-iso-9899` | Needs libm transcendentals on complex scalars |
| FFT (1D Cooley-Tukey, 1D Bluestein for non-power-of-2, 2D row-then-column) | L1 `Tensor` + L1 `Complex.Number` + L2 `swift-iso-9899` (sin/cos for twiddle factors) | Algorithm needs libm |
| Einsum compiler (parse string spec → execute) | L1 `Tensor` + L1 parser primitives | Composes parser + Tensor |
| `Linear.Matrix<R, C>` ↔ `Tensor<Element, 2>` interop | L1 `swift-tensor-primitives` + L1 `swift-algebra-linear-primitives` via SE-0450 trait per [MOD-014] | Cross-package conformance trait-gated |
| `Linear.Vector<N>` ↔ `Tensor<Element, 1>` interop | same | same |
| Format styles (`Format.Tensor` for pretty-printing) | L1 `Tensor` + L1 `swift-format-primitives` | Composes format witness over Tensor |
| Higher-level convenience constructors (`tensor.zeros(shape:)`, `.ones(shape:)`, `.eye(n:)`, etc. that need transcendentals or special-value semantics) | L1 + (when needed) L2 spec layer | Convenience composition |
| Future: DLPack export/import | L1 + L2 `swift-dlpack-standard` (deferred) | Spec-binding L3 composition |
| Future: BLAS-dispatch matmul | L1 + L2 `swift-blas-standard` (deferred) | Backend dispatch via L2 |

### Layer 4: deferred (out of scope)

Platform-specific compute backends — Accelerate / MPS / MPSGraph / CUDA / BLAS-platform-dispatched / autograd — all live at L4 as separate component packages depending on `swift-tensors` (L3). L4 attaches without changing L1/L3.

---

## SwiftPM Target / Product Decomposition

### L1 `swift-tensor-primitives` — target structure

Per [MOD-001] Core internal + [MOD-005] umbrella-only-`@_exported` + [MOD-026] fine-grained-per-type-default + [MOD-011] + [MOD-024] spine discipline.

**[MOD-017] Namespace target evaluation**: The `Tensor` namespace's only declared content is `public enum Tensor {}`. No anticipated cross-package extender at L2 / L3 that would benefit from a standalone Namespace target's transitive-weight reduction (the Tensor namespace is fully internal to swift-tensor-primitives' own variant family; L3 swift-tensors imports Tensor types, not just the namespace). **Decision**: NO separate Namespace target. The namespace declaration lives in `Tensor Primitives Core`. Revisit if a second-package extender materializes per [MOD-017]'s deferred-extraction guidance.

**Target list**:

| Target | Type | Contains |
|--------|------|----------|
| `Tensor Primitives Core` | internal target (no library product per [MOD-001]) | `Tensor` namespace; `Tensor.Shape`, `Tensor.Strides`, `Tensor.Index.Position`, `Tensor.Index.Error`, `Tensor.Slice`, `Tensor.Axis`, `Tensor.Axis.Protocol`; `Tensor.Layout` namespace + `Tensor.Layout.Order` sub-namespace + `Order.Row`/`Order.Column` + `Tensor.Layout.Strided` (sibling) + `Tensor.Layout.Protocol`; `Tensor.Broadcast` namespace + `align(_:_:)`; `Tensor.Storage` namespace + Owned/Aligned witnesses; `Tensor.Value<Element, Rank, Layout>` + `Tensor.View` + `Tensor.View.Mutable` value types; intrinsic operations; typed errors (Shape/Broadcast/Slice/Reshape/Index Error). |
| `Tensor Dynamic Primitives` | published variant | `Tensor.Dynamic<Element>` rank-erased type + its intrinsic operations |
| `Tensor Named Primitives` | published variant | `Tensor.Named<Element, repeat each Axis>` Dex-style overlay + axis-type machinery |
| `Tensor Primitives` | published umbrella per [MOD-005] | `exports.swift` only: `@_exported public import` of all three above |
| `Tensor Primitives Test Support` | published per [MOD-011] | Test fixtures + spine deps per [MOD-024] |

**Decomposition rationale** (per [MOD-015] supplementary vs primary test):

The Core target contains the main `Tensor<Element, Rank, Layout>` API surface and is consumer-functional on its own. The Dynamic and Named variants are minor opt-in additions for specific use cases. Therefore this is **supplementary decomposition** per [MOD-015]: the umbrella `Tensor Primitives` is the canonical consumer import. Consumers needing only positional Tensors write `import Tensor_Primitives` and pay no cost for Dynamic/Named code (they're in separate targets compiled only when included via the umbrella).

**File organization per [API-IMPL-005] (one type per file) + [API-IMPL-006] (dotted file naming)**:

Sample `Sources/Tensor Primitives Core/`:

```
Tensor.swift                              — public enum Tensor {} namespace
Tensor.Shape.swift                        — Tensor.Shape<Rank>
Tensor.Shape.Error.swift                  — Tensor.Shape.Error
Tensor.Strides.swift                      — Tensor.Strides<Rank>
Tensor.Index.swift                        — Tensor.Index<Rank>
Tensor.Index.Error.swift
Tensor.Slice.swift                        — Tensor.Slice<Rank>
Tensor.Slice.Axis.swift                   — Tensor.Slice.Axis
Tensor.Slice.Error.swift
Tensor.Axis.swift                         — Tensor.Axis namespace
Tensor.Axis.Protocol.swift                — hoisted _TensorAxisProtocol per [API-IMPL-009]
Tensor.Layout.swift                       — Tensor.Layout namespace
Tensor.Layout.Protocol.swift              — hoisted _TensorLayoutProtocol per [API-IMPL-009]
Tensor.Layout.Order.swift                 — Tensor.Layout.Order sub-namespace
Tensor.Layout.Order.Row.swift             — Row witness (C-contiguous)
Tensor.Layout.Order.Column.swift          — Column witness (F-contiguous)
Tensor.Layout.Strided.swift               — Strided witness (sibling of Order)
Tensor.Broadcast.swift                    — Tensor.Broadcast namespace
Tensor.Broadcast+Align.swift              — align(_:_:) extension
Tensor.Broadcast.Error.swift
Tensor.Storage.swift                      — Tensor.Storage namespace
Tensor.Storage.Owned.swift                — Owned witness
Tensor.Storage.Aligned.swift              — Aligned witness
Tensor.swift                              — Tensor<Element, Rank, Layout> value type (canonical init + stored properties only, per [API-IMPL-008])
Tensor+Subscript.swift                    — subscript extensions
Tensor+Slicing.swift                      — slice methods extension
Tensor+Transpose.swift                    — transposed/permuted extension
Tensor+Reshape.swift                      — reshape/reshaping extension
Tensor+Arithmetic.swift                   — +/-/*/scalar-multiply extension
Tensor+Reductions.swift                   — sum/product/min/max extension
Tensor+Matmul.swift                       — multiplied(by:) extension
Tensor+Map.swift                          — map functor extension
Tensor+Broadcast.swift                    — broadcast(to:) extension
Tensor+Sequence.swift                     — Sequence.Protocol conformance
Tensor.View.swift                         — Tensor.View<Element, Rank, Layout> type
Tensor.View+Subscript.swift               — view subscript
Tensor.View+Slicing.swift                 — view slicing
Tensor.View.Mutable.swift                 — Tensor.View.Mutable type
Tensor.View.Mutable+Subscript.swift       — mutable subscript
Tensor.Reshape.Error.swift
exports.swift                             — internal target; re-exports for in-target visibility
```

Note: where the same name appears twice in the list above (namespace file + value-type file both named `Tensor.swift`), the value-type file lives at a sub-directory per [API-IMPL-005]'s expectation that each declaration occupies its own `.swift` file. The actual filename for the value type would be `Tensor (Value).swift` or it could be folded under a different name; the table illustrates the principle.

**[MOD-001] Core internal contract**: `Tensor Primitives Core` re-exports its external dependencies via `@_exported public import` in `Sources/Tensor Primitives Core/exports.swift`:

```swift
@_exported public import Index_Primitives
@_exported public import Cardinal_Primitives
@_exported public import Ordinal_Primitives
@_exported public import Finite_Primitives
@_exported public import Affine_Primitives
@_exported public import Dimension_Primitives
@_exported public import Tagged_Primitives
@_exported public import Buffer_Primitives_Core
@_exported public import Storage_Primitives_Core
@_exported public import Memory_Primitives_Core
@_exported public import Numeric_Primitives_Core
@_exported public import Error_Primitives
@_exported public import Algebra_Ring_Primitives
@_exported public import Format_Primitives_Core
@_exported public import Sequence_Primitives_Core
```

**[MOD-002] external dep centralization**: only Core depends on externals; variant targets (Dynamic, Named) depend on Core.

### L1 Package.swift skeleton

```swift
// swift-tools-version: 6.3.1
// swift-tensor-primitives — runtime-shape n-dimensional array primitives.

import PackageDescription

let package = Package(
    name: "swift-tensor-primitives",
    platforms: [
        .macOS(.v26), .iOS(.v26), .tvOS(.v26),
        .watchOS(.v26), .visionOS(.v26),
    ],
    products: [
        .library(name: "Tensor Dynamic Primitives", targets: ["Tensor Dynamic Primitives"]),
        .library(name: "Tensor Named Primitives",   targets: ["Tensor Named Primitives"]),
        .library(name: "Tensor Primitives",         targets: ["Tensor Primitives"]),
        .library(name: "Tensor Primitives Test Support", targets: ["Tensor Primitives Test Support"]),
    ],
    dependencies: [
        .package(path: "../swift-tagged-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-cardinal-primitives"),
        .package(path: "../swift-ordinal-primitives"),
        .package(path: "../swift-finite-primitives"),
        .package(path: "../swift-affine-primitives"),
        .package(path: "../swift-dimension-primitives"),
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-storage-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-numeric-primitives"),
        .package(path: "../swift-algebra-ring-primitives"),
        .package(path: "../swift-error-primitives"),
        .package(path: "../swift-format-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-vector-primitives"),
    ],
    targets: [
        // MARK: - Core (internal)
        .target(name: "Tensor Primitives Core", dependencies: [
            .product(name: "Tagged Primitives",        package: "swift-tagged-primitives"),
            .product(name: "Index Primitives",         package: "swift-index-primitives"),
            .product(name: "Cardinal Primitives",      package: "swift-cardinal-primitives"),
            .product(name: "Ordinal Primitives",       package: "swift-ordinal-primitives"),
            .product(name: "Finite Primitives",        package: "swift-finite-primitives"),
            .product(name: "Affine Primitives",        package: "swift-affine-primitives"),
            .product(name: "Dimension Primitives",     package: "swift-dimension-primitives"),
            .product(name: "Buffer Primitives",        package: "swift-buffer-primitives"),
            .product(name: "Storage Primitives",       package: "swift-storage-primitives"),
            .product(name: "Memory Primitives",        package: "swift-memory-primitives"),
            .product(name: "Numeric Primitives",       package: "swift-numeric-primitives"),
            .product(name: "Algebra Ring Primitives",  package: "swift-algebra-ring-primitives"),
            .product(name: "Error Primitives",         package: "swift-error-primitives"),
            .product(name: "Format Primitives",        package: "swift-format-primitives"),
            .product(name: "Sequence Primitives",      package: "swift-sequence-primitives"),
            .product(name: "Vector Primitives",        package: "swift-vector-primitives"),
        ]),

        // MARK: - Variants
        .target(name: "Tensor Dynamic Primitives", dependencies: ["Tensor Primitives Core"]),
        .target(name: "Tensor Named Primitives",   dependencies: ["Tensor Primitives Core"]),

        // MARK: - Umbrella
        .target(name: "Tensor Primitives", dependencies: [
            "Tensor Primitives Core",
            "Tensor Dynamic Primitives",
            "Tensor Named Primitives",
        ]),

        // MARK: - Test Support (per [MOD-011] + [MOD-024] spine)
        .target(name: "Tensor Primitives Test Support",
            dependencies: [
                "Tensor Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"),

        // MARK: - Tests
        .testTarget(name: "Tensor Primitives Tests",
            dependencies: ["Tensor Primitives Test Support"]),
    ],
    swiftLanguageModes: [.v6]
)

// MARK: - Ecosystem Swift settings (per [PATTERN-005] / [PATTERN-006] / [PATTERN-007])
for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
```

### L3 `swift-tensors` — target structure

Per [MOD-026] fine-grained-per-type-default + [MOD-001] / [MOD-005] / [MOD-011] / [MOD-024]. L3 is **composition** of L1 + L2 + other L1 packages — no new types.

**Target list**:

| Target | Type | Composes |
|--------|------|----------|
| `Tensors Core` | internal | Re-exports `swift-tensor-primitives` + binds `swift-iso-9899` libm shim for transcendental dispatch backbone |
| `Tensors Operations` | published | Transcendental element-wise (exp/log/sin/cos/etc.), reductions for Real types, BLAS-fallback matmul (pure-Swift naive when BLAS unavailable) |
| `Tensors FFT` | published | Cooley-Tukey + Bluestein 1D/2D |
| `Tensors Einsum` | published | Einsum string parser + executor |
| `Tensors Linear` | published, trait-gated per [MOD-014] | `Linear.Matrix<R, C>` ↔ `Tensor<Element, 2>` + `Linear.Vector<N>` ↔ `Tensor<Element, 1>` interop via SE-0450 trait `Linear` |
| `Tensors Format` | published | `Format.Tensor` style |
| `Tensors DLPack` | published, trait-gated, **deferred** until L2 `swift-dlpack-standard` exists | DLPack export/import |
| `Tensors` | published umbrella per [MOD-005] | `exports.swift` only |
| `Tensors Test Support` | published per [MOD-011] | Spine deps per [MOD-024] |

**[MOD-014] cross-package integration via traits**: the `Tensors Linear` target requires `swift-algebra-linear-primitives`, but not every consumer of `swift-tensors` needs the Linear interop. Gated behind an SE-0450 trait:

```swift
traits: [
    .trait(name: "Linear"),
    .trait(name: "DLPack"),  // future
],
```

Consumers opting in:

```swift
.package(path: "../swift-tensors", traits: ["Linear"]),
```

### L3 Package.swift skeleton

```swift
// swift-tools-version: 6.3.1
// swift-tensors — composed tensor operations atop swift-tensor-primitives.

import PackageDescription

let package = Package(
    name: "swift-tensors",
    platforms: [
        .macOS(.v26), .iOS(.v26), .tvOS(.v26),
        .watchOS(.v26), .visionOS(.v26),
    ],
    products: [
        .library(name: "Tensors Operations", targets: ["Tensors Operations"]),
        .library(name: "Tensors FFT",        targets: ["Tensors FFT"]),
        .library(name: "Tensors Einsum",     targets: ["Tensors Einsum"]),
        .library(name: "Tensors Linear",     targets: ["Tensors Linear"]),
        .library(name: "Tensors Format",     targets: ["Tensors Format"]),
        .library(name: "Tensors",            targets: ["Tensors"]),
        .library(name: "Tensors Test Support", targets: ["Tensors Test Support"]),
    ],
    traits: [
        .trait(name: "Linear", description: "Linear.Matrix / Linear.Vector interop"),
        // .trait(name: "DLPack", description: "DLPack export/import"),  // deferred
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-tensor-primitives"),
        .package(path: "../../swift-primitives/swift-complex-primitives"),
        .package(path: "../../swift-primitives/swift-numeric-primitives"),
        .package(path: "../../swift-primitives/swift-format-primitives"),
        .package(path: "../../swift-primitives/swift-error-primitives"),
        .package(path: "../../swift-primitives/swift-parser-primitives"),
        .package(path: "../../swift-iso/swift-iso-9899"),
        // Trait-gated:
        .package(path: "../../swift-primitives/swift-algebra-linear-primitives"),
    ],
    targets: [
        // MARK: - Core (internal)
        .target(name: "Tensors Core", dependencies: [
            .product(name: "Tensor Primitives",   package: "swift-tensor-primitives"),
            .product(name: "Complex Primitives",  package: "swift-complex-primitives"),
            .product(name: "Numeric Primitives",  package: "swift-numeric-primitives"),
            .product(name: "ISO 9899 Core",       package: "swift-iso-9899"),  // libm via L2
        ]),

        // MARK: - Operations
        .target(name: "Tensors Operations", dependencies: ["Tensors Core"]),

        // MARK: - FFT
        .target(name: "Tensors FFT", dependencies: ["Tensors Core"]),

        // MARK: - Einsum
        .target(name: "Tensors Einsum", dependencies: [
            "Tensors Core",
            .product(name: "Parser Primitives", package: "swift-parser-primitives"),
        ]),

        // MARK: - Linear (trait-gated)
        .target(name: "Tensors Linear", dependencies: [
            "Tensors Core",
            .product(name: "Algebra Linear Primitives", package: "swift-algebra-linear-primitives",
                     condition: .when(traits: ["Linear"])),
        ]),

        // MARK: - Format
        .target(name: "Tensors Format", dependencies: [
            "Tensors Core",
            .product(name: "Format Primitives", package: "swift-format-primitives"),
        ]),

        // MARK: - Umbrella
        .target(name: "Tensors", dependencies: [
            "Tensors Core",
            "Tensors Operations",
            "Tensors FFT",
            "Tensors Einsum",
            "Tensors Linear",
            "Tensors Format",
        ]),

        // MARK: - Test Support
        .target(name: "Tensors Test Support",
            dependencies: [
                "Tensors",
                .product(name: "Tensor Primitives Test Support", package: "swift-tensor-primitives"),
            ],
            path: "Tests/Support"),

        // MARK: - Tests
        .testTarget(name: "Tensors Tests",
            dependencies: ["Tensors Test Support"]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
```

### Dependency graph

```
                    swift-tensors (L3)
                          ↓
       ┌──────────────────┼──────────────────┐
       ↓                  ↓                  ↓
  swift-tensor-      swift-complex-     swift-iso-9899 (L2, libm)
  primitives (L1)    primitives (L1)
       ↓ (transitively, via Core re-exports)
  [L1 primitives: index, cardinal, ordinal, finite, affine, dimension,
   buffer, storage, memory, numeric, algebra-ring, error, format, sequence,
   tagged]

  Optionally (Linear trait):
  swift-tensors → swift-algebra-linear-primitives (L1)

  swift-tensor-primitives itself has no further upward dependencies.
```

No circular dependencies. L1 stays Foundation-free per [PRIM-FOUND-001]; L2 `swift-iso-9899` is the libm authority per [PLAT-ARCH-008j]; L3 swift-tensors composes L1 + L2.

---

## Open Questions

Per [RES-027] (residual loose-ends, classified as **direction** vs **premise**).

### Premises (load-bearing; verify before adopting)

**P1 — `InlineArray<Rank, T>` with `~Copyable` element compatibility.** [premise]
`Tensor.Shape<Rank>` and `Tensor.Strides<Rank>` use `InlineArray<Rank, Cardinal>` and `InlineArray<Rank, Affine.Discrete.Vector>` as stored properties of structs. **Verification spike** (≤ 30 min minimal package): `struct Foo<let N: Int>: ~Copyable { var arr: InlineArray<N, SomeCopyable> }` plus mutation. If fails, fall back to `Tagged<Tensor.Shape.Storage<Rank>, ...>` with custom backing.

**P2 — `Memory.Alignment.alignUp(_:)` signature.** [premise]
Inventory cites `Memory.Alignment.alignUp(_:)` at `swift-memory-primitives/Sources/Memory Primitives Core/Memory.Alignment.Align.swift`. **Verify**: grep + signature check; if signature differs from assumption (accepts byte count, returns rounded-up value), adjust composition code.

**P3 — `Affine.Discrete.Vector` arithmetic on tensor stride types.** [premise]
Negative strides require `Tagged<...> - Tagged<...> → Affine.Discrete.Vector` (signed displacement), then `Memory.Address + Affine.Discrete.Vector → Memory.Address` for offset advance. **Verify** these operators exist for the relevant Tagged tag types.

**P4 — `Tensor.Layout` witnesses as zero-size types.** [premise]
`Tensor.Layout.Order.Row` / `Tensor.Layout.Order.Column` / `Tensor.Layout.Strided` as phantom-type witnesses (v1.2.0 naming). **Verify** they compile when used as generic parameters on `Tensor.Value<Element, Rank, Layout>` with `Layout: Tensor.Layout.Protocol`. (Resolved: implementation confirmed working.)

**P5 — `~Copyable, ~Escapable` lifetime annotation for `Tensor.View` borrowing from `Tensor`.** [premise]
The view types must be lifetime-bound to the owner. **Verify** via Swift 6.3's `@_lifetime(borrow source)` or successor syntax that the borrow check rejects use-after-free at compile time.

**P6 — SE-0398 variadic type-pack usability for `Tensor.Named<Element, repeat each Axis>`.** [premise]
The named-axis overlay relies on variadic generics + per-axis static `size` extraction. **Verify** via spike: axis-type pack expansion produces compilable Tensor.Named operations (init, subscript, transpose).

### Directions (not load-bearing; future decisions)

**D1 — Element-type enum vs generic.** [direction] Generic chosen. Quantized types come as a separate `Tensor.Quantized<Block>` type at L4 (not in scope here).

**D2 — Reshape semantics.** [direction] Split APIs decided: `tensor.reshape(_:)` returns `Tensor` (view-if-possible-else-copy); `tensor.reshaping(_:)` returns `Tensor.View` and throws `Tensor.Reshape.Error` on non-contiguous.

**D3 — Lazy / eager toggle.** [direction] Eager-by-default. Lazy fusion deferred to L4 `swift-compute-graph` (hypothetical).

**D4 — Autograd integration.** [direction] No autograd in L1/L3. If added later, explicit-tape model (JAX-style) at L4.

**D5 — Einsum surface (string DSL vs builder).** [direction] Both can be provided; string DSL delegates to typed builder. Defer to UX research.

**D6 — Sparse, ragged variants.** [direction] Future direction. Sibling types at L1 (`Tensor.Sparse.COO<Element>`, `Tensor.Ragged<Element>`) sharing the `Tensor` namespace.

**D7 — `Tensor.Storage` as type vs witness.** [direction] Currently designed as witness (zero-size types). Could become a generic parameter on Tensor if storage variants need protocol-level dispatch (e.g., pooled storage for fast allocation). Defer to spike when motivation appears.

---

## Outcome

**Status**: RECOMMENDATION (v1.1.0, 2026-05-16).

### Recommendation

Author two new packages, **`swift-tensor-primitives`** at L1 and **`swift-tensors`** at L3, with the type/concept/target/product decomposition specified above. **L1 owns the Tensor type itself and all intrinsic operations** (subscript, slice, transpose, reshape, broadcast, basic arithmetic, reductions, pure-Swift matmul). **L3 composes L1 with L2 specs and other L1 primitives** to deliver transcendentals, FFT, einsum, format styles, and cross-package interop (Linear.Matrix). Defer L2 (`swift-dlpack-standard`) and L4 (platform compute backends) until concrete consumers materialize.

### Specific architectural commitments

1. **L1 owns the type.** `Tensor<Element, let Rank: Int, Layout>` and its `~Copyable, ~Escapable` view types (`Tensor.View`, `Tensor.View.Mutable`) and rank-erased and named variants (`Tensor.Dynamic`, `Tensor.Named<each Axis>`) all live in `swift-tensor-primitives` along with intrinsic operations.

2. **Rank in the type via SE-0452 `let Rank: Int`.** No shape arithmetic; rank-changing operations use concrete-rank overloads or erase to `Tensor.Dynamic<Element>`.

3. **Shape and strides runtime, typed.** `Tensor.Shape<Rank>` is `InlineArray<Rank, Cardinal>`; `Tensor.Strides<Rank>` is `InlineArray<Rank, Affine.Discrete.Vector>`.

4. **Layout as zero-size witness.** `Tensor.Value<Element, Rank, Layout: Tensor.Layout.Protocol>` with `Tensor.Layout.Order.Row`, `Tensor.Layout.Order.Column`, `Tensor.Layout.Strided` as phantom types (v1.2.0). `Tensor.Layout.Protocol` is the public alias to a hoisted protocol per [API-IMPL-009]. Strided is a sibling of `Order`, not a member.

5. **Storage as separate types, not parameter.** `Tensor` (owned), `Tensor.View` (borrowed), `Tensor.View.Mutable` (exclusive-borrowed) are separate types sharing protocol witnesses. Borrow-check via Swift exclusivity + `~Copyable, ~Escapable`.

6. **Element generic, not enum.** `Tensor<Element, Rank, Layout>` with `Element: Numeric` constraint baseline. Quantization deferred to a separate L4 type.

7. **Eager-by-default.** No expression templates. Op-DAG model is L4.

8. **Typed throws everywhere** per [API-ERR-001]. `Tensor.Shape.Error`, `Tensor.Broadcast.Error`, `Tensor.Slice.Error`, `Tensor.Reshape.Error`, `Tensor.Index.Error` — all `Swift.Error`-conforming enums with descriptive cases per [API-ERR-002] / [API-ERR-003].

9. **One type per file** per [API-IMPL-005] + dotted file names per [API-IMPL-006].

10. **Foundation-free at L1** per [PRIM-FOUND-001]; libm-via-L2-shim (`swift-iso-9899`) at L3 per [PLAT-ARCH-008j]; platform-specific dispatch (Accelerate, MPS, BLAS) deferred to L4 components.

11. **Coexistence with `Linear.Matrix<Rows, Columns>` and `Linear.Vector<N>`.** Compile-time-shape Linear primitives stay; Tensor is the runtime-shape complement. Interop via SE-0450 trait-gated L3 target `Tensors Linear` per [MOD-014].

12. **SwiftPM**: per [MOD-001] Core internal; per [MOD-005] umbrella is `@_exported public import` only; per [MOD-011] / [MOD-024] Test Support published with spine; per [MOD-026] fine-grained-per-type-default. Full Swift settings profile per [PATTERN-005] / [PATTERN-006] / [PATTERN-007].

### Implementation path (gated on principal authorization)

**Phase 0 — verification spikes** (pre-implementation, ≤ 30 min each):
- P1: `InlineArray<Rank, T>` + `~Copyable` interop.
- P2: `Memory.Alignment.alignUp(_:)` signature.
- P3: `Affine.Discrete.Vector` arithmetic on stride types.
- P4: `Tensor.Layout` witness compilation.
- P5: `~Copyable, ~Escapable` view lifetime-bound.
- P6: SE-0398 variadic type pack for `Tensor.Named`.

**Phase 1** — `swift-tensor-primitives` Core:
- `Tensor Primitives Core` with namespace + addressing types + Layout/Broadcast witnesses + typed errors.
- `Tensor<Element, Rank, Layout>` value type with canonical init + stored properties only (per [API-IMPL-008]).
- `Tensor.View` + `Tensor.View.Mutable` value types.
- Intrinsic operations as separate extension files per [API-IMPL-006].
- Tests + Test Support spine per [MOD-024].

**Phase 2** — `swift-tensor-primitives` variants:
- `Tensor Dynamic Primitives`.
- `Tensor Named Primitives`.
- `Tensor Primitives` umbrella.

**Phase 3** — `swift-tensors` Core + Operations:
- `Tensors Core` composing L1 + `swift-iso-9899` libm.
- `Tensors Operations`: transcendental element-wise, reductions, matmul.

**Phase 4** — `swift-tensors` extensions:
- `Tensors FFT` (Cooley-Tukey + Bluestein).
- `Tensors Einsum`.
- `Tensors Linear` (trait-gated `Linear.Matrix` / `Linear.Vector` interop).
- `Tensors Format`.
- `Tensors` umbrella.

**Phase 5** — release readiness:
- Documentation per `[DOC-*]`, README per `[README-*]`.
- Audit per `[AUDIT-*]`, release-readiness per `[RELEASE-*]`.
- Benchmark per `[BENCH-*]`.

L4 component packages (Accelerate backend, MPS backend, etc.) attach after L3 stable; not in scope.

### Anti-recommendations

- Do NOT replicate SwiftMetalNumerics' `NumericTensor` as-is.
- Do NOT use untyped throws.
- Do NOT use `@unchecked Sendable` for storage with mutating accessors.
- Do NOT use a singleton compute backend.
- Do NOT use a global mutable dispatch heuristic guarded by NSLock.
- Do NOT replicate the `Layers.swift` 1036-line multi-type file anti-pattern.
- Do NOT use expression templates / lazy expression trees as the default.
- Do NOT use bytes-strides (use element-strides + typed `Affine.Discrete.Vector`).
- Do NOT use runtime dtype enum dispatch (use generics).
- Do NOT bind libm at L1 (use the `swift-iso-9899` L2 shim at L3 per [PLAT-ARCH-008j]).
- Do NOT use `Tensor.MutableView` (compound name); use `Tensor.View.Mutable` per [API-NAME-001].
- Do NOT introduce a `Tensor` Namespace target unless a cross-package extender materializes per [MOD-017].

---

## Skill-Conformance Audit Annex

Per the v1.1.0 user request: explicit, mechanical audit of this design against the four named skills.

### Annex A — /code-surface conformance ([API-NAME-*], [API-ERR-*], [API-IMPL-*])

| Rule | Applied? | Evidence in this doc |
|------|----------|----------------------|
| [API-NAME-001] Nest.Name pattern | ✓ | All types follow `Tensor.X.Y` — `Tensor.Shape`, `Tensor.Strides`, `Tensor.View.Mutable`, `Tensor.Layout.Order.Row`, etc. No compound type names. v1.2.0 corrected v1.1.0's `Layout.RowMajor` / `Layout.ColumnMajor` to `Layout.Order.Row` / `Layout.Order.Column`. |
| [API-NAME-001a] Single-Type-No-Namespace | ✓ | `Tensor.Dynamic` is a leaf type (not nested under a Dynamic namespace). `Tensor.Named` is a leaf type. `Tensor.Storage` namespace contains multiple witnesses (Owned, Aligned) so namespace is justified. |
| [API-NAME-001b] LargerDomain.Subdomain | ✓ | `Tensor.Layout` (Tensor = subject, Layout = aspect); Layout is a kind of Tensor metadata. `Tensor.Broadcast` same. |
| [API-NAME-002] No compound identifiers | ✓ corrected | v1.0.0 had `Tensor.MutableView` (compound Mutable + View) → v1.1.0 `Tensor.View.Mutable` (Mutable is a kind of View). All methods (`transposed`, `reshape`, `reshaping`, `multiplied(by:)`, `slice(_:axis:)`, `broadcast(to:)`, `withContiguousElements(_:)`) avoid compound shape. |
| [API-NAME-003] Specification-mirroring | ✓ | `DLPack.ManagedTensor`, `DLPack.Device`, `DLPack.DataType` deferred L2; would mirror spec exactly. |
| [API-NAME-007] Convention-known heuristic | ✓ | `withContiguousElements` not `withUnsafeBufferPointer` (institute-flavored not stdlib-aliased). |
| [API-NAME-008] Property.View vs labeled method | ✓ | `slice(_:axis:)` is single-form labeled method (not Property.View). `View.Mutable` is multi-form (Tensor.View has multiple kinds: read-only + Mutable) — justifies the `Mutable` variant under `View`. |
| [API-NAME-010] No *Tag suffix | n/a | No phantom tags use Tag suffix. Layout witnesses are zero-size types named directly (Order.Row, Order.Column, Strided). |
| [API-NAME-011] Options not Flags | ✓ | No OptionSet types proposed in v1; if added later, `.Options` suffix per rule. |
| [API-ERR-001] Typed throws required | ✓ | Every fallible operation explicitly typed: `throws(Tensor.Shape.Error)`, `throws(Tensor.Broadcast.Error)`, `throws(Tensor.Slice.Error)`, `throws(Tensor.Reshape.Error)`, `throws(Tensor.Index.Error)`. |
| [API-ERR-002] Nested error types + `Swift.Error` qualification per [PLAT-ARCH-011] | ✓ | All errors nested as `Tensor.X.Error` enums conforming to `Swift.Error` (qualified). |
| [API-ERR-003] Describe failure not recovery | ✓ | Error cases describe the failure condition (`.shapeMismatch(lhs:rhs:)`, `.productNotPreserved(from:to:)`, etc.) not recovery. |
| [API-ERR-006] No existential throws | ✓ | All `throws(...)` clauses typed; no `throws(any Error)`. |
| [API-IMPL-005] One type per file | ✓ | File organization enumerated in §"L1 SwiftPM Decomposition" with per-type file naming. |
| [API-IMPL-006] File naming with dots | ✓ | `Tensor.Shape.swift`, `Tensor.View.Mutable.swift`, `Tensor.Layout.Order.Row.swift`, etc. |
| [API-IMPL-007] Extension files (`+` suffix) | ✓ | `Tensor+Arithmetic.swift`, `Tensor+Subscript.swift`, `Tensor+Reshape.swift`, etc. |
| [API-IMPL-008] Minimal type body | ✓ | `Tensor` value type body = stored properties + canonical init; all methods in `+*` extension files. |
| [API-IMPL-009] Hoisted protocol pattern | ✓ | `Tensor.Layout.Protocol` is a typealias to a hoisted `_TensorLayoutProtocol` (similar for `Tensor.Axis.Protocol`); declaring-module conformance uses hoisted name; consumers use typealias path. |
| [API-IMPL-012] Closures trail signature | ✓ | `withContiguousElements(_ body:)`, `Tensor.map(_:)` — closures last. |
| [API-IMPL-014] Configuration first or last | n/a | No Configuration parameters in v1 surface. |
| [API-IMPL-018] `@retroactive` package-scoped | ✓ | Cross-package conformances (L3 `Tensors Linear` adding `Linear.Matrix` extension to `Tensor`) lives in a separate package (`swift-tensors`); requires `@retroactive` per the rule. |
| [API-IMPL-019] Qualified names inside conforming extensions | ✓ | `swift-tensors`' Linear interop extension uses fully-qualified module paths for cross-namespace references. |

**Verdict**: ✓ All [API-NAME-*] / [API-ERR-*] / [API-IMPL-*] rules applied or n/a for the v1 surface. v1.0.0's `Tensor.MutableView` compound violation corrected in v1.1.0.

### Annex B — /implementation conformance ([IMPL-*], [PATTERN-009–053])

| Rule | Applied? | Evidence |
|------|----------|----------|
| [IMPL-INTENT] Code reads as intent | ✓ | Method names are intent-named: `transposed`, `reshape`, `multiplied(by:)`, `broadcast(to:)`, `align(_:_:)`. No mechanism names. |
| [IMPL-000] Call-site-first design | ✓ | Operations are designed for natural call sites: `tensor.transposed()`, `tensor.reshape(newShape)`, `tensor * scalar`, `tensor.sum(along: axis)`. Infrastructure (Shape, Strides, Layout) supports these expressions. |
| [IMPL-001] Principled absences | ✓ | Cardinal subtraction is partial → not provided on `Tensor.Shape.subtract`; instead use `Cardinal.subtract.saturating`/`.exact`. Strides arithmetic via `Affine.Discrete.Vector` (signed). |
| [IMPL-COMPILE] Compiler as primary correctness mechanism | ✓ | Rank arity compile-time-checked via SE-0452; view ownership compile-time-enforced via `~Copyable, ~Escapable`; layout dispatch zero-cost via phantom witnesses; typed throws compile-time-checked. |
| [IMPL-002] Write the math, not the mechanism | ✓ | Linear-index formula `offset = Σ strides[k] · index[k]` expressed via `Affine.Discrete.Vector` accumulation; no `.rawValue` chains at call sites. |
| [IMPL-010] Push Int to the edge | ✓ | `Memory.Address` + `Affine.Discrete.Vector` for offset arithmetic; `Int(bitPattern:)` only inside boundary overloads in `Buffer.Linear`/`Memory.Address` (per [INFRA-*]). |
| [IMPL-033] Iteration intent | ✓ | Reductions and element-wise ops use stride-aware bulk iteration, not raw `for i in 0..<n`. |
| [IMPL-050] Bounded indices for static-capacity | ✓ | `Tensor.Shape<Rank>` uses `InlineArray<Rank, Cardinal>` — indexing via `Ordinal.Finite<Rank>` not raw Int. |
| [IMPL-060] Ecosystem dependencies | ✓ | All addressing/storage/algebra/error types are existing institute primitives (see §"Ecosystem Reuse Inventory"); minimal net-new surface. |
| [IMPL-064] Types default to `~Copyable` | ✓ | `Tensor.View` and `Tensor.View.Mutable` are `~Copyable, ~Escapable`. `Tensor<Element, Rank, Layout>` is conditionally `~Copyable` based on Element/storage. |
| [IMPL-065] `~Escapable` for scoped views | ✓ | View types are `~Escapable` with lifetime-bound to owner. |
| [IMPL-067] Explicit ownership annotations | ✓ | Mutating operations use `consuming`/`borrowing`/`inout` per institute idiom; explicit on every method. |
| [IMPL-074] Cross-layer type reference test | ✓ | Tensor at L1 references existing L1 primitives only. L3 references L1 + L2; no upward references. |
| [IMPL-088] Lock-ordering | n/a | No locks in L1/L3 design (eager-by-default; no shared state). |
| [IMPL-106] Language features over custom ownership | ✓ | Uses `~Copyable`/`~Escapable`/`borrowing`/`consuming`; no `Raw`/`Borrow` shadow types. |
| [IMPL-108] No `try?` | ✓ | All call sites in the design use `do throws(E) { } catch { }` typed-catch pattern; no `try?`. |

**Verdict**: ✓ /implementation rules applied. Intent-over-mechanism, ownership-first, compiler-enforced rank arity + layout + lifetime, ecosystem reuse maximized.

### Annex C — /modularization conformance ([MOD-*])

| Rule | Applied? | Evidence |
|------|----------|----------|
| [MOD-DOMAIN] Factor the law | ✓ | The "law" is the strided-indexing scheme + shape/stride/layout/broadcast vocabulary; this is what L1 owns. Variants (Dynamic, Named) factor along orthogonal axes (rank-erasure, axis-identity). |
| [MOD-001] Core layer (internal, no library product) | ✓ | `Tensor Primitives Core` is internal-only; only umbrella + Dynamic + Named variants + Test Support are published. |
| [MOD-002] External dep centralization | ✓ | Only Core depends on externals (Buffer, Storage, Memory, Numeric, Algebra Ring, Tagged, Index, Cardinal, Ordinal, Finite, Affine, Dimension, Error, Format, Sequence). Variants depend on Core. |
| [MOD-003] Variant decomposition | ✓ | Variants (Dynamic, Named) along single axis (shape-identity / axis-identity), independent of each other. |
| [MOD-004] Constraint isolation | ✓ | Core stays `Element: ~Copyable`-permissive where possible. Sequence/Collection conformances live in variant targets, not Core. (Tensor's `Sequence.Protocol` conformance via flattened-view extension is in a separate file in Core that's conditionally compiled when Element is Copyable.) |
| [MOD-005] Umbrella re-export only | ✓ | `Tensor Primitives` umbrella has `exports.swift` only: `@_exported public import` of Core + Dynamic + Named. |
| [MOD-006] Dependency minimization | ✓ | Variants depend only on Core; no inter-variant dependencies (Dynamic doesn't depend on Named or vice versa). |
| [MOD-007] DAG shape (depth ≤ 3) | ✓ | Max depth: Core → Variant (e.g. Dynamic) → Umbrella = depth 2. Test Support → Umbrella → variants = depth 3. |
| [MOD-008] Split decision criteria | ✓ | Dynamic split for rank-erasure use case (different dependency set: no Rank generic). Named split for SE-0398 type-pack use case (different language-feature surface). |
| [MOD-011] Test Support published | ✓ | `Tensor Primitives Test Support` published. |
| [MOD-014] Cross-package integration via SE-0450 traits | ✓ | L3 `Tensors Linear` trait-gated `swift-algebra-linear-primitives` dep. |
| [MOD-015] Consumer import precision | ✓ | Tensor Primitives is supplementary decomposition (Core has the main API; Dynamic and Named are minor opt-in additions) → umbrella `import Tensor_Primitives` is canonical consumer import. Tensors (L3) is also supplementary → `import Tensors` is canonical. Narrow imports (`Tensors_FFT`, `Tensor_Named_Primitives`) available for selective consumers. |
| [MOD-017] Namespace-only target | n/a (justified) | Evaluated: no cross-package extender of `Tensor` namespace anticipated (L3 swift-tensors consumes Tensor types, not just the namespace). Decision: NO separate Namespace target. Revisit if a second-package namespace-only extender materializes. |
| [MOD-024] Test Support spine | ✓ | `Tensor Primitives Test Support` anchors on `Buffer Primitives Test Support` (lowest in-scope dep). |
| [MOD-026] Fine-grained per-type default | ✓ | L3 `swift-tensors` decomposed into Operations / FFT / Einsum / Linear / Format separate targets, not bundled. |
| [MOD-RENT] Three-criteria rent test | ✓ | Capability: Tensor is not expressible via existing primitives alone (composition of Buffer + Shape + Strides + Layout is the new structure). Consumer: future L3 swift-tensors itself; pre-existing potential consumers in ML/scientific computing. Theoretical content: tensor as multilinear map per §"Theoretical Grounding" — coherent semantic domain. |
| [MOD-029] Split decisions: upstream dep tree | n/a (not splitting an existing package) | Both packages are new; no upstream-dep-tree split decision applies. |

**Verdict**: ✓ /modularization rules applied. Core-internal-+-umbrella-+-variants discipline + fine-grained per-type default + Test Support spine + SE-0450 trait for cross-package interop.

### Annex D — /platform conformance ([PLAT-ARCH-*], [PATTERN-001–008])

| Rule | Applied? | Evidence |
|------|----------|----------|
| [PLAT-ARCH-008c] L1 unconditionally platform-agnostic | ✓ | `swift-tensor-primitives` has NO `#if os(...)` / `#if canImport(...)` conditionals in any target. No platform-specific storage. No platform-C imports. |
| [PLAT-ARCH-008j] L2 platform-C import authority | ✓ | L3 `swift-tensors` does NOT import libm directly. Transcendental ops compose via L2 `swift-iso-9899` (the libm-import authority for the institute). |
| [PLAT-ARCH-011] `Swift.Error` qualification | ✓ | All error types declared as `enum X: Swift.Error` (Swift-qualified per [PLAT-ARCH-022] for cross-context portability). |
| [PLAT-ARCH-022] `Swift.<Protocol>` for shadowed protocols | ✓ | `Swift.Sequence`, `Swift.Error` qualifiers used wherever consumed (especially the Tensor flattening view's `Swift.Sequence.Protocol` conformance — qualified to avoid `Sequence` namespace shadow from `swift-sequence-primitives`). |
| [PATTERN-001] C shim layer structure | n/a | No C shims in v1 design. Libm comes via L2 `swift-iso-9899`'s existing shim. |
| [PATTERN-004] SwiftPM platform conditions | n/a (cross-platform) | No platform-specific deps in L1 or L3. |
| [PATTERN-004a] `#if os()` for platform identity | n/a | No platform identity checks needed. |
| [PATTERN-004b] Module name normalization | ✓ | Target names use spaces (`"Tensor Primitives Core"`); import identifiers underscored (`Tensor_Primitives_Core`). |
| [PATTERN-005] Swift 6 language mode | ✓ | `// swift-tools-version: 6.3.1` and `swiftLanguageModes: [.v6]` in both packages. Platforms floor `.macOS(.v26)` / `.iOS(.v26)` / etc. per current ecosystem standard. |
| [PATTERN-005a] Strict memory safety warnings as design feedback | ✓ | `.strictMemorySafety()` in SwiftSetting profile. Per [PATTERN-005b] + [MEM-SAFE-002], `unsafe` markers will be expression-granular when added during implementation. |
| [PATTERN-006] Upcoming features | ✓ | SwiftSetting includes `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `LifetimeDependence`. |
| [PATTERN-007] Experimental features | ✓ | `LifetimeDependence`, `Lifetimes`, `SuppressedAssociatedTypes` enabled — required for `~Escapable` view types and `~Copyable`-conditional protocols. |
| [PATTERN-008] Parameter packs for n-ary types | ✓ | `Tensor.Named<Element, repeat each Axis>` uses SE-0393 / SE-0398 parameter packs. Multi-axis subscripting uses variadic generic indices. |

**Verdict**: ✓ /platform rules applied. L1 platform-agnostic; L3 libm via L2 `swift-iso-9899`; full Swift 6.3+ SwiftSetting profile; SE-0452 + SE-0398 + SE-0393 leveraged.

### Annex Summary

| Skill | Conformance | Notes |
|-------|-------------|-------|
| /code-surface | ✓ all applied | v1.0.0's `Tensor.MutableView` compound name corrected to `Tensor.View.Mutable` |
| /implementation | ✓ all applied | Intent-over-mechanism; compiler-enforced strictness via SE-0452 + `~Copyable, ~Escapable` |
| /modularization | ✓ all applied | Core internal + umbrella + variants; fine-grained per-type default; SE-0450 trait for Linear interop |
| /platform | ✓ all applied | L1 platform-agnostic; L3 libm via L2 `swift-iso-9899`; full SwiftSetting profile |

---

## References

### Internal (institute) prior research

- [ecosystem-data-structures-inventory.md](ecosystem-data-structures-inventory.md) — layer-aware data-structure catalog.
- [data-structures-linear-collections-assessment.md](data-structures-linear-collections-assessment.md) — variant-system audit pattern.
- [buffer-arena-conditional-copyable.md](buffer-arena-conditional-copyable.md) — conditional-~Copyable design pattern.
- [storage-buffer-abstraction-analysis.md](storage-buffer-abstraction-analysis.md) — Storage vs Buffer boundary.
- [copyable-wrapper-vs-multi-buffer-storage.md](copyable-wrapper-vs-multi-buffer-storage.md) — refcount-per-copy cost model.

### Specifications

- DLPack v0.x: https://dmlc.github.io/dlpack/
- Python Array API standard: https://data-apis.org/array-api/latest/
- Swift Evolution proposals:
  - SE-0246 Generic Math(s) Functions: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0246-mathable.md
  - SE-0393 Value and Type Parameter Packs: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md
  - SE-0398 Variadic Generic Types: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md
  - SE-0450 Package Traits: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-package-traits.md
  - SE-0452 Integer Generic Parameters: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0452-integer-generic-parameters.md

### Production libraries (primary sources)

- NumPy: https://numpy.org/doc/stable/reference/arrays.ndarray.html ; NEPs at https://numpy.org/neps/
- ndarray (Rust): https://docs.rs/ndarray/ ; https://github.com/rust-ndarray/ndarray
- PyTorch: https://pytorch.org/docs/ ; https://github.com/pytorch/pytorch/blob/main/aten/src/ATen/templates/TensorBody.h ; Edward Yang dispatcher: http://blog.ezyang.com/2020/09/lets-talk-about-the-pytorch-dispatcher/
- TensorFlow: https://www.tensorflow.org/ ; https://github.com/tensorflow/tensorflow/tree/master/tensorflow/core/framework/
- JAX: https://docs.jax.dev/ ; https://github.com/google/jax/
- MLX: https://ml-explore.github.io/mlx/build/html/index.html ; https://github.com/ml-explore/mlx
- Eigen: https://libeigen.gitlab.io/eigen/docs-nightly/
- xtensor: https://xtensor.readthedocs.io/en/latest/
- ggml: https://github.com/ggerganov/ggml
- Apple's swift-numerics: https://github.com/apple/swift-numerics ; issue #6: https://github.com/apple/swift-numerics/issues/6

### Academic / theoretical

- Maclaurin et al., "Dex: array programming with typed indices" (ICLR 2019): https://openreview.net/forum?id=rJxd7vsWPS
- Paszke et al., "Getting to the Point" (ICFP 2021): https://arxiv.org/abs/2104.05372
- Henriksen & Elsman, "Towards Size-Dependent Types for Array Programming" (ARRAY 2021): https://futhark-lang.org/publications/array21.pdf
- Wenig et al., "The Syntax and Semantics of einsum" (2025): https://arxiv.org/abs/2509.20020
- Selinger, "A survey of graphical languages for monoidal categories" (2009): https://arxiv.org/abs/0908.3347
- Brady, "Idris 2: Quantitative Type Theory in Practice" (ECOOP 2021): https://drops.dagstuhl.de/storage/00lipics/lipics-vol194-ecoop2021/LIPIcs.ECOOP.2021.9/LIPIcs.ECOOP.2021.9.pdf
- Vazou et al., Liquid Haskell tutorial: https://ucsd-progsys.github.io/liquidhaskell-tutorial/book.pdf
- Idris documentation: https://docs.idris-lang.org/en/latest/tutorial/typesfuns.html
- Veldhuizen, "Expression Templates" (1995): https://www.cs.rpi.edu/~musser/design/blitz/exprtmpl.html
- Hasktorch typed tensors: https://hasktorch.github.io/tutorial/07-typed-tensors.html
- jaxtyping: https://docs.kidger.site/jaxtyping/

### Comparator (Swift-specific)

- `acemoglu/SwiftMetalNumerics` — local clone at `/Users/coen/Developer/acemoglu/SwiftMetalNumerics/`.
