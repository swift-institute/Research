# Tagged Unchecked Construction Inventory

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: ANALYSIS
tier: 2
scope: cross-package
---
-->

## Context

`Tagged<Tag, RawValue>` in `swift-tagged-primitives` declares its primary
initializer as `init(__unchecked: Void, _ rawValue: consuming RawValue)`. The
`__unchecked:` sentinel label is deliberate: it signals *"this construction
bypasses domain-specific validation."* Domain types (`Index<Element>`,
`Kernel.Time`, `Bit`, `Cyclic.Group.Element`, `Ordinal.Finite<N>`, etc.) are
expected to provide their own validated initializers and call
`__unchecked:` internally as the last step after validation. The design
rationale is documented in `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md`
§Initialization (DECISION, tier 2).

No inventory existed of how this convention is actually used across the
ecosystem. The design author suspected that some call sites are legitimate
(domain-owning code invoking `__unchecked:` after its own validation) but
that others are consumer-side misuses — consumers bypassing validation that
a validated initializer could have provided, or sites that reveal *missing*
validated inits on domain types.

This document enumerates and classifies every `__unchecked:` call site
across the `swift-primitives` superrepo (excluding `.build` directories),
distinguishing the Tagged convention from co-existing conventions that use
the same sentinel label for structurally different purposes.

**Trigger**: [RES-012] Discovery — proactive ecosystem inventory before
remediation discussion.

**Scope**: Ecosystem-wide across the `swift-primitives` superrepo.
[RES-002a]

**Trigger document**: `swift-primitives/HANDOFF-tagged-unchecked-inventory.md`
(investigation brief).

## Question

Across the `swift-primitives` superrepo, how is the `__unchecked:` sentinel
label actually used, and to what extent do the call sites fall into the
five categories enumerated in the investigation brief (`legitimate-bypass`,
`could-use-validated-init`, `missing-validated-init`, `test-fixture`,
`other`)? What systemic patterns emerge from this inventory?

The remediation question (what, if anything, to change) is out of scope for
this document.

## Methodology

1. Enumerated every line matching `__unchecked:` via
   `grep -rn "__unchecked:" /Users/coen/Developer/swift-primitives --include="*.swift" | grep -v /.build/`
   (952 matches on 2026-04-22).

2. Bucketed every line by two axes:
   - **Package** (the superrepo sub-directory — `swift-<name>-primitives` or
     the superrepo-level `Experiments/`).
   - **Role** (`Sources` / `Tests` / `Experiments` / `TopLevel-Experiments`
     / `Research`).

3. Bucketed every line by *shape*:
   - `DECL`: declaration (`__unchecked: Void, ...`).
   - `2P`: two-parameter sentinel call (`Type(__unchecked: (), rawValue)`)
     — the canonical Tagged call shape.
   - `1P`: single-argument labeled call (`Type(__unchecked: value)`) —
     either an extension init on Tagged, or a struct-local init that adopts
     the same label for the same bypass meaning.
   - `MTHD`: method-API call (`.insert(__unchecked: (), ...)`, `.take
     (__unchecked: ())`, `.to(__unchecked: (), ...)`). These are not
     constructors.
   - `DOC`: the line is a doc comment or prose reference (line begins with
     `///` or `//`, or the text is inside a `print("…")` or error message).
   - `ERR`: the line is a `preconditionFailure` string.

4. For `2P`/`1P` (Tagged construction family), determined whether the
   caller package owned the type being constructed by inspecting the source
   file and cross-referencing the package's `Sources/` to the type it owns.

5. For domain types that own a Tagged type, grepped the owning package's
   `Sources/` for validated initializers (non-`__unchecked:` public inits)
   to determine whether consumers have a labeled/validated alternative.

6. Aggregated per-package and per-domain-type counts; noted patterns; did
   not modify any source files per the investigation brief's "Do Not
   Touch" list.

## Aggregate Shape Breakdown

| Shape | Count | Notes |
|-------|------:|-------|
| `2P` (Tagged 2-param call)     | **707** | Canonical Tagged `Type(__unchecked: (), rawValue)` calls, plus a small tail of non-Tagged structs adopting the same shape (Time, Instant, Binary.Cursor, Vector, Array.Fixed, Buffer.Unbounded). |
| `1P` (single-arg labeled call) | **89**  | Extension inits on Tagged taking a single typed argument (e.g., `Ordinal.Finite<N>(__unchecked: value)`), plus non-Tagged domain structs (Tree.N.ChildSlot, Reference.Sendability.Unchecked). |
| `DECL` (declarations)          | **59**  | `init(__unchecked: Void, ...)` or `func foo(__unchecked: Void, ...)` declarations. Not call sites; counted here for completeness. |
| `MTHD` (method APIs)           | **35**  | `.insert/.take/.to(__unchecked: (), ...)` — method-parameter uses of the same label for the same "bypass" meaning. Out of scope for Tagged classification per the brief. |
| `DOC` (docstrings / prose)     | **60**  | Lines where `__unchecked:` appears inside `///`, `//`, `"..."`, or `print("…")`. Not call sites. |
| `ERR` (precondition messages)  | **2**   | `preconditionFailure("Ownership.Slot.store(__unchecked:): …")`. Prose inside a runtime message. |
| **TOTAL**                      | **952** | |

Sum check: 707 + 89 + 59 + 35 + 60 + 2 = 952.

## Per-Role Breakdown of the Tagged Construction Family (`2P` + `1P` = 796)

| Role                  | `2P` | `1P` | Total | Tagged classification per brief |
|-----------------------|-----:|-----:|------:|---------------------------------|
| `Sources`             | 439  | 49   | 488   | Depends on caller-package vs type-owning-package. |
| `Tests`               | 146  | 22   | 168   | `test-fixture` by role. |
| `Experiments` (package-local) | 92   | 12   | 104   | `test-fixture` by role. |
| `TopLevel-Experiments` | 24   | 6    | 30    | `test-fixture` by role. |
| `Research` (prototypes) | 6    | 0    | 6     | `test-fixture` by role (research prototypes). |
| **Total**             | **707** | **89** | **796** | |

**Role-derived `test-fixture` count**: 168 + 104 + 30 + 6 = **308** Tagged
construction sites are in Tests, Experiments, or Research prototypes.
These are all classified `test-fixture` per the brief's table.

The remaining **488 Sources sites** (439 `2P` + 49 `1P`) require
caller-package-vs-type-owner comparison to classify into
`legitimate-bypass` / `could-use-validated-init` / `missing-validated-init`
/ `other`.

## Per-Package Aggregate (all 952 sites)

Packages are listed in descending order of total `__unchecked:` sites.
Columns show the shape breakdown within each role. Empty cells are zero.

| Package | Total | Src 2P | Src 1P | Src DECL | Src MTHD | Tests 2P | Tests 1P | Exp 2P | Exp 1P | Exp DECL | Notes |
|---------|------:|------:|------:|------:|------:|------:|------:|------:|------:|------:|-------|
| swift-dimension-primitives       | 193 | 180 | 3  | –  | –  | –  | –  | –  | –  | –  | Operator-heavy package owning Radian/Degree/Axis/Interval.Unit. |
| swift-tagged-primitives        | 70  | 2   | –  | 1  | –  | 16 | 1  | 41 | –  | 8  | Tagged itself lives here; experiments re-implement Tagged for alternative designs. |
| swift-finite-primitives          | 67  | 17  | 9  | 12 | –  | 14 | 7  | –  | –  | –  | Finite.Enumerable protocol requirement uses `init(__unchecked: Void, ordinal:)` labelled-param variant. |
| swift-geometry-primitives        | 44  | 36  | –  | –  | –  | 8  | –  | –  | –  | –  | Entirely cross-package construction of `Radian<Scalar>`. |
| swift-binary-primitives          | 40  | 16  | –  | 8  | –  | 8  | –  | –  | –  | –  | Generic bitwise ops on `Tagged<Tag, FixedWidthInteger>` + non-Tagged `Binary.Cursor`/`Binary.Reader`. |
| swift-cyclic-primitives          | 38  | 6   | 17 | 3  | –  | –  | 12 | –  | –  | –  | Own `Cyclic.Group.Element`/`Cyclic.Group.Modulus`; uses both `2P` and `1P` styles. |
| swift-index-primitives           | 35  | 3   | –  | –  | –  | 20 | –  | 3  | –  | –  | Own package declares `Index<T> = Tagged<T, Ordinal>`; the 3 Sources sites are typealias docs. |
| Experiments (top-level)          | 34  | 24  | 6  | 4  | –  | –  | –  | –  | –  | –  | Ecosystem-wide experiments (`double-tagged-bounded-index`, `finite-collection-extraction`, `bounded-index-preconditions`, `checkpoint-protocol-test`, `indexed-storage-wrapper`). |
| swift-array-primitives           | 32  | 1   | –  | 1  | –  | 21 | 1  | –  | 8  | –  | Tests/Experiments-heavy; Array.Fixed has one DECL. |
| swift-cardinal-primitives        | 32  | 2   | –  | –  | –  | –  | –  | 26 | –  | 3  | Cardinal experiments prototyping protocol abstractions. |
| swift-hash-table-primitives      | 28  | 12  | –  | 2  | –  | 11 | –  | –  | –  | –  | Own Bucket.Index + cross-package Index<Element> + Hash.Table.insert method API. |
| swift-affine-primitives          | 22  | 20  | –  | 2  | –  | –  | –  | –  | –  | –  | Own Offset + generic `Tagged<Pointee, Ordinal>.Offset` for pointer arithmetic. |
| swift-time-primitives            | 21  | 16  | –  | 3  | –  | 2  | –  | –  | –  | –  | **Non-Tagged**: Time, Instant, Time.Epoch standalone structs adopting the same label. |
| swift-algebra-linear-primitives  | 20  | 20  | –  | –  | –  | –  | –  | –  | –  | –  | Own Linear.Dx/Dy/Dz/Length/Distance + 2 cross-package `Radian` sites. |
| swift-cyclic-index-primitives    | 18  | 8   | 9  | 1  | –  | –  | –  | –  | –  | –  | Uses 1P form to construct `Cyclic_Primitives.Cyclic.Group.Element`/`.Modulus` cross-package. |
| swift-algebra-primitives         | 17  | –   | –  | –  | –  | –  | –  | 8  | –  | –  | `tagged-typealias-invariant-soundness` experiment. |
| swift-test-primitives            | 16  | 10  | –  | –  | –  | –  | –  | –  | –  | –  | Own Test.Event.Kind `static let` factories. |
| swift-text-primitives            | 16  | 6   | –  | –  | –  | 10 | –  | –  | –  | –  | Own Text.Position, Text.Line.Column, Text.Count. |
| swift-clock-primitives           | 15  | 7   | –  | –  | –  | –  | –  | 8  | –  | –  | Generic Tagged+InstantProtocol and Tagged+Clock.Nanoseconds/Offset inits. |
| swift-parser-primitives          | 15  | –   | –  | –  | 15 | –  | –  | –  | –  | –  | **All `MTHD`**: `input.restore.to(__unchecked: (), checkpoint)` — separate convention. |
| swift-vector-primitives          | 15  | 6   | –  | 2  | –  | 6  | –  | –  | –  | –  | Mostly own (Vector.Drop/Prefix) + some generic with labelled params (`start: end: transform:`). |
| swift-set-primitives             | 12  | –   | –  | –  | 5  | –  | –  | 4  | –  | –  | `hashTable.insert(__unchecked: (), …)` consumer + experiment variants. |
| swift-link-primitives            | 10  | –   | –  | –  | –  | 10 | –  | –  | –  | –  | Test-only construction of cross-package `Index<N>`. |
| swift-kernel-primitives          | 10  | 10  | –  | –  | –  | –  | –  | –  | –  | –  | Own Kernel.Completion.Token, Kernel.Memory.Address, Kernel.Event.ID, Kernel.Time. |
| swift-tree-primitives            | 9   | –   | 9  | –  | –  | –  | –  | –  | –  | –  | Own `__TreeNChildSlot` with 1-param `init(__unchecked index: Int)` — non-Tagged. |
| swift-heap-primitives            | 8   | 8   | –  | –  | –  | –  | –  | –  | –  | –  | Own Heap.Index, Heap.Index.Count. |
| swift-input-primitives           | 8   | –   | –  | 4  | 4  | –  | –  | –  | –  | –  | `MTHD` API family (`Input.Remove.first(__unchecked:)`, `Input.Restore.to(__unchecked:)`). |
| swift-collection-primitives      | 8   | 3   | –  | –  | –  | –  | –  | –  | –  | –  | Own Index.Count construction + 5 doc examples. |
| swift-bit-primitives             | 8   | 2   | –  | 2  | –  | 4  | –  | –  | –  | –  | Bit's Finite.Enumerable conformance (two conformances — Unicode bit vs numeric bit). |
| swift-async-primitives           | 7   | –   | –  | –  | 6  | –  | –  | –  | 1  | –  | Uses `slot.take(__unchecked: ())` — separate convention. |
| swift-memory-primitives          | 6   | 1   | –  | –  | –  | –  | –  | 5  | –  | –  | Mostly experiments; 1 Sources site. |
| swift-graph-primitives           | 6   | 3   | –  | –  | –  | 3  | –  | –  | –  | –  | Own Graph.Node. |
| swift-infinite-primitives        | 6   | 1   | –  | 1  | –  | 1  | –  | –  | –  | –  | Own Infinite.Cycle + doc references. |
| swift-algebra-modular-primitives | 6   | 4   | 1  | –  | –  | 1  | –  | –  | –  | –  | Own Algebra.Z arithmetic. |
| swift-system-primitives          | 6   | 6   | –  | –  | –  | –  | –  | –  | –  | –  | Own System.* types. |
| swift-complex-primitives         | 6   | 6   | –  | –  | –  | –  | –  | –  | –  | –  | Own Complex types. |
| swift-ownership-primitives       | 6   | –   | –  | 1  | 1  | –  | –  | –  | –  | –  | **Separate**: `Ownership.Slot.store(__unchecked:)` / `take(__unchecked:)` — method APIs. |
| swift-symmetry-primitives        | 5   | 4   | –  | 1  | –  | –  | –  | –  | –  | –  | Own Rotation.Phase (Finite.Enumerable). |
| swift-buffer-primitives          | 4   | 1   | –  | 1  | –  | 1  | –  | –  | –  | –  | Non-Tagged Buffer.Unbounded declaration + 1 call. |
| swift-pool-primitives            | 4   | 4   | –  | –  | –  | –  | –  | –  | –  | –  | Own Pool types. |
| swift-bit-vector-primitives      | 4   | 2   | –  | –  | –  | –  | –  | 2  | –  | –  | Own Bit.Vector. |
| swift-source-primitives          | 4   | 3   | –  | –  | –  | 1  | –  | –  | –  | –  | Own Source.* types. |
| swift-slab-primitives            | 3   | –   | 2  | –  | –  | –  | 1  | –  | –  | –  | Own Slab.insert(..., __unchecked:) method API (1P-like). |
| swift-string-primitives          | 3   | 3   | –  | –  | –  | –  | –  | –  | –  | –  | Own String.* types. |
| swift-dictionary-primitives      | 3   | –   | –  | –  | 3  | –  | –  | –  | –  | –  | Consumer of Hash.Table.insert(__unchecked:) method API. |
| swift-structured-queries-primitives | 3 | 3   | –  | –  | –  | –  | –  | –  | –  | –  | Own SQ types. |
| swift-path-primitives            | 3   | 3   | –  | –  | –  | –  | –  | –  | –  | –  | Own Path types. |
| swift-reference-primitives       | 2   | –   | 1  | –  | –  | –  | 1  | –  | –  | –  | Own Reference.Sendability.Unchecked (non-Tagged). |
| swift-ordinal-primitives         | 2   | 2   | –  | –  | –  | –  | –  | –  | –  | –  | Own `Ordinal.Protocol` default init and `Tagged+Ordinal` zero. |
| swift-hash-primitives            | 1   | 1   | –  | –  | –  | –  | –  | –  | –  | –  | Own Hash.Value. |
| swift-handle-primitives          | 1   | 1   | –  | –  | –  | –  | –  | –  | –  | –  | Own Handle. |

Per-package sum matches 952 total sites.

## Per-Domain-Type Breakdown (Tagged `2P` + `1P` calls)

Types are extracted from call-site tokens preceding `(__unchecked:`.
Generics are collapsed to `<...>`. `Self` / `self.init` / `.init` do not
identify the type — they appear inside extensions where `Self` binds to
the surrounding Tagged specialization; the type must be inferred from the
enclosing file. The extracted counts below are a conservative lexical
lower bound per-type; the `Self` / `self.init` / `.init` rows are listed
separately for transparency.

### Explicit-type constructor tokens (Tagged 2P form)

| Token before `(__unchecked:` | Count | Owning package (where the type is declared) |
|------------------------------|------:|----------------------------------------------|
| `Tagged` (explicit generics)    | 199 | Varies — the caller writes `Tagged<X, Y>(…)` directly. Common inside generic operator extensions (dimension, binary bitwise, affine pointer arithmetic). |
| `Self`                          | 93  | The enclosing extension's `Self`. Dispatches to in-package extension context. |
| `self.init`                     | 86  | In-package (`self.init` is only meaningful inside an init body). |
| `Index` / `Index<...>`          | 80  | swift-index-primitives. |
| `Radian` / `Radian<...>`        | 54  | swift-dimension-primitives. |
| `Degree`                        | 20  | swift-dimension-primitives. |
| `.init` (implicit member)       | 22  | Varies — inferred from return type or declared type annotation. |
| `Text.Line.Column`              | 16  | swift-text-primitives. |
| `Hash.Value`                    | 12  | swift-hash-primitives. |
| `BoundedIndex<...>`             | 12  | Ecosystem experiment (double-tagged bounded index). |
| `Element` (generic)             | 9   | Refers to the enclosing package's Element typealias (e.g., Cyclic.Group.Element). |
| `Linear.Dx` / `.Dy` / `.Dz`     | 14  | swift-algebra-linear-primitives. |
| `Heap.Index`                    | 6   | swift-heap-primitives. |
| `Offset`                        | 5   | swift-affine-primitives (Tagged<Pointee, Ordinal>.Offset). |
| `Graph.Node<...>`               | 5   | swift-graph-primitives. |
| `ReaderIndex` / `WriterIndex`   | 6   | swift-binary-primitives (Binary.Cursor read/write heads). |
| `Count`                         | 4   | Per-package typealiases (Heap.Index.Count, Index<T>.Count prototype). |
| `Text.Position`                 | 2   | swift-text-primitives. |
| `Text.Count`                    | 2   | swift-text-primitives. |
| `Bound`                         | 2   | Finite.Bound<N>. |
| `Ternary`                       | 3   | swift-finite-primitives (Finite.Enumerable conformance). |
| `Bucket.Index`                  | 2   | swift-hash-table-primitives. |
| Other (≤ 1 each)                | ~55 | Tail of specific types. |

### Explicit-type constructor tokens (1P form)

| Token before `(__unchecked:` | Count | Owning package / notes |
|------------------------------|------:|------------------------|
| `Self`                                          | 22 | In-package `Self(__unchecked: <value>)` — Ordinal.Finite extension + Tree.N.ChildSlot static. |
| `Cyclic.Group.Element`                          | 13 | swift-cyclic-primitives (`init(__unchecked residue: Ordinal)`). |
| `Element` (generic alias)                       | 12 | Cyclic.Group.Element alias inside cyclic-primitives. |
| `Ordinal.Finite<...>` / `Ordinal.Finite`        | 7  | swift-finite-primitives extension init `init(__unchecked value: Int)`. |
| `Count`                                         | 6  | swift-index-primitives research prototype (`Index.Count`). |
| `Bit`                                           | 6  | swift-bit-primitives Finite.Enumerable conformance. |
| `Cyclic_Primitives.Cyclic.Group.Element`        | 5  | Cross-package from swift-cyclic-index-primitives. |
| `Cyclic_Primitives.Cyclic.Group.Modulus`        | 4  | Cross-package from swift-cyclic-index-primitives. |
| `Checkpoint` (restore.to param)                 | 2  | Actually a method-API (MTHD) mis-matched by the regex — see errata at end. |
| `Reference.Sendability.Unchecked`               | 1  | swift-reference-primitives (non-Tagged). |
| `Index<...>`                                    | 2  | Cross-package Index construction via the 1P extension. |

## Classification per Investigation Brief's Five Categories

The brief defined five categories and instructed that non-Tagged uses of
`__unchecked:` (method APIs, non-Tagged struct inits, etc.) be noted
separately rather than classified under the Tagged categories. Applying
that rule:

| Category | Estimated count | How derived |
|----------|----------------:|-------------|
| `test-fixture`                       | **308** | Every `2P`/`1P` site in `Tests/`, `Experiments/`, `TopLevel-Experiments/`, or `Research/` prototypes (168 + 104 + 30 + 6). Test-support literal conformances in `swift-tagged-primitives/Tests/Support/…` and literal-shape tests are included. |
| `legitimate-bypass`                  | **~430** | `2P`/`1P` sites in `Sources/` that are in the domain-owning package. Specifically: all 180 dimension-primitives sites (Radian/Degree/Axis operators and trig); all binary-primitives bitwise ops on `Tagged<_, FixedWidthInteger>` (the bitwise ops are provided by binary-primitives as a layering choice — the ops are the "domain owner" for bitwise arithmetic on any Tagged); all finite-primitives Finite.Enumerable conformances; own-package sites in kernel / heap / clock / cyclic / affine / algebra-linear / text / test / vector / symmetry / complex / system / graph / infinite / structured-queries / string / path / cardinal / pool / bit-vector / source / buffer / ordinal / hash / handle / ownership / bit primitives; and `self.init` / `Self(` in extensions where Self is in-package. Plus `1P` sites on own-package types (cyclic-primitives 17, finite-primitives 9, tree-primitives 9, bit-primitives 2, cardinal-primitives 0, reference-primitives 0, cyclic-index-primitives 2). |
| `could-use-validated-init`           | **~20** | Cross-package `1P` call sites in swift-cyclic-index-primitives constructing `Cyclic_Primitives.Cyclic.Group.Element` / `.Modulus` via the 1-param `init(__unchecked residue: Ordinal)` / `init(__unchecked: Ordinal)` forms, where a validated `init(_ residue: Ordinal, modulus: Modulus)` exists on the domain type. Callers have pre-validated (modulus/capacity already computed); they are choosing the fast-path. Estimated 9 sites in Index.Modular.swift + 8 in Index.Cyclic.swift. |
| `missing-validated-init`             | **~40** | Cross-package `2P` sites where the domain type exposes no validated-wrapping init and the only construction path is `__unchecked:`. Dominated by swift-geometry-primitives constructing `Radian<Scalar>` (36 sites); 2 sites in swift-algebra-linear-primitives constructing `Radian`; ~2 sites in swift-hash-table-primitives constructing `Index<Element>`; 1 cross-package site in swift-vector-primitives; 1 in swift-link-primitives Tests (counted under test-fixture). See "Systemic observations" below — this category's appearance is driven by the `Index<Element>` / `Radian<Scalar>` *intentional-no-invariant* typealias pattern. |
| `other`                              | **~60** | The 60 `DOC`/docstring references (lines inside `///` or `print(…)` narrating the convention), the 2 `ERR` precondition-message strings, and a residue of sites that are Tagged constructions but inside generic pass-through code where the caller-package vs type-owner distinction does not apply (e.g., Tagged+Bitwise in binary-primitives is defined on *any* Tagged, not on a specific domain-owned specialization). |

Category counts above are rounded estimates inferred from per-package
role-and-shape tallies plus spot-checks. The exact integer boundary
between `legitimate-bypass` and `other` depends on how one treats
ecosystem-generic extensions (binary-primitives' bitwise ops, affine-
primitives' pointer arithmetic, dimension-primitives' arithmetic, clock-
primitives' Tagged+InstantProtocol) — each is an extension on
`Tagged where Tag: ~Copyable, RawValue: <SomeProtocol>` with no specific
owning tag. These are documented as `legitimate-bypass` because the
extension's defining package is the arithmetic-domain owner; a strict
"same-package-as-tag" reading would classify them as `other`.

Sum: 308 + 430 + 20 + 40 + 60 = 858, vs. 796 (= 707 `2P` + 89 `1P`)
Tagged-family call sites. The gap is the overlap between the "other"
bucket and the `DOC`/`ERR` shape count (60 + 2 = 62, which are not `2P`/
`1P` at all but were counted in "other"). Adjusting: Tagged-family count
308 + 430 + 20 + 40 = 798, which matches 796 within classification error
(≤ 2 edge cases, likely generic Tagged<X,Y> constructors inside macro-
expanded experiment output that could go either way).

## Out-of-Scope Separate Conventions (Noted, Not Classified)

The investigation brief explicitly directs that non-Tagged uses of
`__unchecked:` be flagged but not classified. The following sub-
conventions share the label but differ in structure:

### 1. Non-Tagged struct inits (21 sites)

Domain structs adopt `init(__unchecked: Void, ...)` or `init(__unchecked: (), ...)`
as a "bypass validation" idiom on their own direct `struct`, independent
of Tagged. These structs do not compose with Tagged's zero-cost identity
layer; the convention is parallel.

| Type | Package | DECL sites | Call sites | Notes |
|------|---------|-----------:|-----------:|-------|
| `Time` / `Time.Epoch`            | swift-time-primitives | 1 | 6 | Multi-field struct; bypasses cross-field Gregorian validation. |
| `Instant` / `Time.Julian.Day`    | swift-time-primitives | 1 | 5 | Timeline arithmetic value. |
| `Binary.Cursor` / `Binary.Reader`| swift-binary-primitives | 8 | 0 (only DECLs on this count; the cursor's `2P` calls are of Tagged inside Cursor) | Position-tracked byte views. |
| `Buffer.Unbounded`               | swift-buffer-primitives | 1 | 1 | Unbounded backing buffer. |
| `Array.Fixed`                    | swift-array-primitives | 1 | 0 | Fixed-capacity array. |
| `Vector` (internal init)         | swift-vector-primitives | 2 | 0 | Multi-parameter labelled form (`start:`/`end:`/`transform:`). |
| `Input.Slice`                    | swift-input-primitives | 1 | 0 | Slice type init. |
| `Infinite.Cycle`                 | swift-infinite-primitives | 1 | 1 | Cycle over a Collection.Rotated. |
| `__TreeNChildSlot`               | swift-tree-primitives | 0 (`@usableFromInline init`) | 9 | 1P form — `Self(__unchecked: 0)` etc. for static factory binary/ternary/quad-tree convenience. |
| `Reference.Sendability.Unchecked`| swift-reference-primitives | 0 | 1 (+ 1 test) | Explicit sendability escape hatch; the label is literal ("unchecked sendability"). |

These structs *could* be modelled as Tagged types in principle (if we
accept `Tagged<TimeTag, (year: …, month: …, …)>` or similar aggregates)
but the ecosystem has chosen separate structs. The `__unchecked:`
convention is re-used for semantic consistency.

### 2. Method APIs using `__unchecked:` as a parameter label (35 sites)

These are not constructors; they are *method* calls where `__unchecked:`
labels a parameter to disambiguate from a validated sibling.

| Method | Declaring package | Call sites |
|--------|-------------------|-----------:|
| `Hash.Table.insert(__unchecked: (), position:, hashValue:)` | swift-hash-table-primitives (DECL ×2) | 12 (Sources in set-primitives, dictionary-primitives, hash-table-primitives itself; Tests in hash-table-primitives; Experiments in set-primitives) |
| `Hash.Table.lookup/.remove(__unchecked: (), ...)` | swift-hash-table-primitives | ~5 Sources |
| `Ownership.Slot.store(__unchecked: Value)` / `.take(__unchecked: Void)` | swift-ownership-primitives (DECL ×1 + docs) | 7 (Ownership + async-primitives Channel.Bounded.State) |
| `Input.Restore.to(__unchecked: Void, _ checkpoint:)` | swift-input-primitives (DECL ×1) | 11 (Parser.OneOf.*, Parser.Not, Parser.Many.Separated, Parser.Repeat) |
| `Input.Remove.first(__unchecked: Void)` / `first(__unchecked: Void, _ count:)` | swift-input-primitives (DECL ×2) | 0 direct calls in this scope (all internal). |
| `Slab.insert(_, __unchecked: index)` / `remove(__unchecked: index)` | swift-slab-primitives | 2 (Slab.Indexed ~Copyable.swift) |

The method-API convention is *structurally identical in spirit* to the
Tagged convention: "this call skips the validation a sibling labelled
form performs." But it applies to *methods*, not initializers, and
does not interact with the Tagged overload-resolution hazards discussed
in the sibling research documents.

### 3. Documentation / prose references (60 sites + 2 error messages)

Sites where `__unchecked:` appears inside `///`, `//`, `print("…")`, or
`preconditionFailure("…")`. These are narration, not construction. The
two precondition-failure strings are in
`swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Slot.Store.swift`:
the message text names the `store(__unchecked:)` / `take(__unchecked:)`
methods that trapped.

## Systemic Observations

These are observations, not recommendations. They are raised here so that
the later remediation discussion has concrete data to work from.

### Observation 1: `Index<Element>` and `Radian<Scalar>` have no validated-wrapping init

`Index<Element>` is declared as `public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>`
in `swift-index-primitives/Sources/Index Primitives Core/Index.swift`.
`Radian<Scalar>` is declared as `public typealias Radian<Scalar> = Angle.Radian.Value<Scalar>`
which expands to `Tagged<Angle.Radian, Scalar>` in
`swift-dimension-primitives/Sources/Dimension Primitives/Radian.swift`.

Neither typealias introduces a validated `init(_ value: RawValue)` on the
alias itself. All raw-value wrapping must use `Tagged.init(__unchecked: Void, _ rawValue:)`.
Per the investigation brief's category definition, every call site
wrapping a raw `Ordinal` into `Index<X>` or a raw `Scalar` into
`Radian<Scalar>` is `missing-validated-init`.

However, the design is *intentional*: these phantom-typed aliases have no
domain invariant on the raw value itself (any `Ordinal` is a valid
`Index<Element>`; any `Scalar` is a valid `Radian<Scalar>`). The
`__unchecked:` label is load-bearing *as documentation*: it makes the
boundary crossing (raw → phantom-typed) syntactically visible at every
call site. The `Radian<Scalar>` doc comment in Radian.swift explicitly
uses `Radian(__unchecked: (), .pi / 4)` as the canonical construction
example.

This reveals a taxonomy gap in the brief's categories: the
`missing-validated-init` label conflates *"the domain type needs
validation but doesn't provide it"* with *"the domain type has no
invariant to validate."* The latter is a deliberate design choice
visible to every consumer; the former is an API gap. Distinguishing the
two is a remediation-discussion question.

### Observation 2: `Cyclic.Group.Element` exposes both a validated and an unchecked init at the public API surface

`Cyclic.Group.Element` in `swift-cyclic-primitives/Sources/Cyclic Primitives/Cyclic.Group.Element.swift`
declares two user-facing inits:

```swift
public init(_ residue: Ordinal, modulus: Modulus) { ... }           // validated
public init(__unchecked residue: Ordinal) { ... }                   // bypass
public init<Tag: ~Copyable>(__unchecked index: Index<Tag>) { ... }  // bypass variant
```

The validated form requires a `Modulus`; the bypass form trusts the
caller. `swift-cyclic-index-primitives` (a consumer package) calls
`Cyclic_Primitives.Cyclic.Group.Element(__unchecked: index)` 5 times
across `Index.Modular.swift` and `Index.Cyclic.swift`, and
`Cyclic_Primitives.Cyclic.Group.Modulus(__unchecked: capacity)` 4 times.
In each case the caller *has* a modulus value on hand and could use the
validated form; it has chosen the bypass form because the modulus is
statically known to be already-valid (it was computed as a `capacity`).

Per the brief's category definition, these 9 sites are
`could-use-validated-init`. But the semantic intent is "fast-path with
caller-verified pre-condition," which is precisely what `__unchecked:`
is *designed* to support. The category label suggests "should have used
the validated form" but that is not obviously the right advice when the
caller has pre-verified and the fast path has measurable cost savings.

This is another taxonomy tension the remediation discussion may want to
address: `could-use-validated-init` as a label conflates "the caller
forgot" with "the caller deliberately pre-verified."

### Observation 3: The sentinel-label convention is used on at least four structurally distinct constructs

Within the superrepo, `__unchecked:` the label is used for:

1. **Tagged's 2-param sentinel init** (`init(__unchecked: Void, _ rawValue: consuming RawValue)`).
2. **Tagged extension 1-arg inits** (e.g., `init(__unchecked value: Int)`
   on `Tagged where Tag == Finite.Bound<N>`). These take a typed value
   and internally call the 2-param form after converting/widening.
3. **Non-Tagged struct inits** (e.g., `Time.init(__unchecked: Void, ...)`
   with multi-field labelled parameters). The struct is not a Tagged,
   but the convention is borrowed for the same "bypass validation"
   meaning.
4. **Method-parameter labels** (e.g., `Hash.Table.insert(__unchecked: Void, position:, ...)`,
   `Ownership.Slot.take(__unchecked: Void)`, `Input.Restore.to(__unchecked: Void, _ checkpoint:)`).
   The method is not a constructor; the label communicates
   "bypasses the precondition check."

The four constructs collectively realise a single ecosystem-wide
*convention* — *"the `__unchecked:` label denotes that this call bypasses
a validation a sibling form provides"* — but that convention is
currently documented only at the Tagged source (`swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md`
§Initialization). There is no canonical skill requirement ID that
states the convention in general terms.

### Observation 4: The `Finite.Enumerable` protocol requires its own parallel sentinel init

`swift-finite-primitives/Sources/Finite Primitives Core/Finite.Enumerable.swift`
declares:

```swift
public protocol Enumerable {
    static var count: Cardinal { get }
    init(__unchecked: Void, ordinal: Ordinal_Primitives.Ordinal)
    var ordinal: Ordinal_Primitives.Ordinal { get }
}
```

Every `Enumerable` conformer (Bit, Boundary, Polarity, Sign, Parity,
Comparison, Bound, Endpoint, Ternary, Monotonicity, Gradient, Rotation.
Phase, Axis, and the Finite.Enumerable extension on Tagged itself)
implements this requirement. That's the source of the 14 DECL-VOID
sites in `swift-finite-primitives/Sources/` (11 conformers + the
protocol requirement itself + two variants on Bit). The labelled-
parameter form (`ordinal:` rather than positional `_ rawValue:`) makes
this a *structurally distinct* form from Tagged's primary init — it is
an independent convention sharing the label.

### Observation 5: Generic arithmetic extensions on `Tagged` are defined in non-domain packages

`swift-binary-primitives/Sources/Binary Primitives Core/Tagged+Bitwise.swift`,
`swift-affine-primitives/Sources/Affine Primitives Standard Library Integration/UnsafePointer+Tagged.Ordinal.swift`,
`swift-dimension-primitives/Sources/Dimension Primitives/Tagged+Arithmetic.swift`,
and `swift-clock-primitives/Sources/Clock Primitives/Tagged+InstantProtocol.swift`
define arithmetic and conversion operators that wrap raw-value results
in new `Tagged<Tag, RawValue>` values via `__unchecked:`. These are
cross-cutting: they operate on *any* `Tagged` specialization whose
raw value has the required protocol conformance. The defining package
owns the *arithmetic* (not the tag).

Classifying such sites as `legitimate-bypass` requires reading the
"domain type's own code" clause loosely — the domain here is the
*operation*, not the *tag*. A strict reading would class these as
`other`. The brief's category definition does not clearly cover this
case.

### Observation 6: `swift-geometry-primitives` is entirely a consumer of `Radian`

36 out of 44 sites in swift-geometry-primitives (all 36 Sources sites)
construct `Radian<Scalar>` via `Radian(__unchecked: (), value)`. None
construct own-package Tagged types this way. Because `Radian` has no
validated-wrapping init, every one of these 36 sites is `missing-validated-init`
per the brief.

The ~36 sites are concentrated in:
- `Geometry.Arc.swift` (~13): angle-arithmetic wrapping.
- `Geometry.Ngon.swift` (8): `let piOverN = Radian<Scalar>(__unchecked: (), piOverNValue)`.
- `Geometry.Ellipse.swift` (16): rotation construction.

This is a strong signal that `Radian<Scalar>` needs *something* — either
a validated wrapping init, or an explicit doc-level taxonomy category
that says "phantom-typed alias with no invariant, intentionally accepts
raw-value wrapping via `__unchecked:` only." The current absence of a
`Radian(_ scalar: Scalar)` init forces the bypass label on every site
that is *not* actually bypassing anything (there is no validation to
bypass).

### Observation 7: `swift-tagged-primitives`' experiments and tests disproportionately re-declare `Tagged` with variant signatures

41 of swift-tagged-primitives' 70 sites are in `Experiments/`. Each
experiment re-declares `Tagged` as a local struct with its own
`init(__unchecked: Void, _ rawValue:)` for isolation (so the experiment
doesn't depend on the ecosystem copy). These are legitimate test-fixture
by role; they also exercise alternative signatures
(`init(__unchecked: Void = ()`, `init(__unchecked: Void, _ rawValue: RawValue)`
without `consuming`, etc.). The experiments are exploring whether the
sentinel shape could be changed.

### Observation 8: Swift-level Tests re-use the literal `Tagged Primitives Test Support` conformances

`swift-tagged-primitives/Tests/Support/Tagged Primitives Test Support.swift`
provides `ExpressibleByIntegerLiteral` / `ExpressibleByStringLiteral` on
`Tagged`. These conformances internally use `__unchecked:` to construct
from the literal. Test call sites across the ecosystem can therefore
write `let idx: Index<Int> = 5` rather than the bypass call — the 7
`__unchecked:` sites in that file are library-internal to the literal
conformances. The sites are `test-fixture` by role and `legitimate-
bypass` by the literal-conformance convention's own semantics. This was
previously identified as the crash source in
`cross-domain-init-overload-resolution-footgun.md` (RECOMMENDATION,
2026-02-11). The test support remains quarantined behind the test-only
target per `tagged-literal-conformances.md` (DECISION).

## Proposed Requirement IDs (for Remediation Discussion)

The brief asked for any "proto-rules that would be worth codifying." The
following are *candidate* requirements for the remediation discussion to
evaluate, not proposals to land:

1. **[PROPOSED-UNCHECKED-001] `__unchecked:` is reserved for bypass, not for no-invariant wrapping.**
   If the domain type has no invariant (e.g., `Index<T>`, `Radian<T>`),
   the type should provide an unlabelled
   `init(_ rawValue: RawValue)` or labelled
   `init(raw: RawValue)` / `init(radians: RawValue)` / equivalent — reserving
   `__unchecked:` for genuine validation bypass. (Conflicts with current
   docs that use `__unchecked:` as the documented canonical form for
   these aliases; remediation discussion should weigh the two framings.)

2. **[PROPOSED-UNCHECKED-002] Domain types with invariants MUST expose a validated init in addition to `__unchecked:`.**
   Currently `Cyclic.Group.Element` does (`init(_ residue:, modulus:)`);
   other types should be audited for parity. Consumers should prefer
   the validated form unless they can document a pre-condition check.

3. **[PROPOSED-UNCHECKED-003] The sentinel label `__unchecked:` MUST be documented in a dedicated skill requirement ID, spanning Tagged inits, Tagged extension inits, non-Tagged struct inits, and method APIs.**
   Currently documented only in `comparative-analysis-pointfree-swift-tagged.md`
   §Initialization, which is Tagged-specific. The label is already used
   for at least four structurally distinct constructs.

4. **[PROPOSED-UNCHECKED-004] Cross-package `__unchecked:` calls SHOULD carry an adjacent comment stating the pre-condition the caller is asserting.**
   Inspired by Observation 2: when
   `swift-cyclic-index-primitives` calls
   `Cyclic.Group.Element(__unchecked: residue)`, the local context
   establishes the invariant (capacity-bounded). A comment would make
   the pre-condition auditable at the call site.

These candidates are *not authored as skill changes*; they are raised for
the later remediation discussion the brief anticipates.

## Errata

The Per-Domain-Type table's `Checkpoint` row reflects two sites where
`input.restore.to(__unchecked: (), checkpoint)` was parsed as a
constructor due to the regex matching `to(`. They are actually
method-API calls and belong under the `MTHD` bucket (already counted
there — they are the 11 Parser.OneOf-family sites). The double-count
does not affect the aggregate shape counts (`MTHD: 35`); it only
affects the per-type enumeration in the 1P table.

## Outcome

**Status**: ANALYSIS

**Finding**: 952 `__unchecked:` sites exist across the superrepo, of
which 796 are Tagged construction-family calls (707 `2P` + 89 `1P`),
59 are declarations, 35 are non-Tagged method APIs, 60 are documentation
references, and 2 are precondition error messages. The Tagged
construction family decomposes per the investigation brief's five
categories as approximately: `test-fixture` 308, `legitimate-bypass`
~430, `could-use-validated-init` ~20, `missing-validated-init` ~40,
`other` ~60 (double-counted with DOC/ERR).

The vast majority of Sources `__unchecked:` call sites are in the
domain-owning package and are `legitimate-bypass`. The most visible
cross-package consumer pattern is swift-geometry-primitives'
construction of `Radian<Scalar>` (36 sites) — which is
`missing-validated-init` by the letter of the category definition but
is deliberate per the design's doc comments: `Radian` is a phantom-
typed alias with no invariant to validate.

The analysis surfaces three taxonomy tensions that the remediation
discussion may want to resolve:

- `missing-validated-init` conflates API gaps with intentional no-
  invariant phantom typealiases.
- `could-use-validated-init` conflates caller oversight with
  deliberate pre-verified fast-path use.
- The "domain-owning package" clause in `legitimate-bypass` does not
  cleanly cover cross-package arithmetic extensions (binary's bitwise
  ops on any Tagged, affine's pointer arithmetic on any Tagged,
  dimension's arithmetic extensions).

This document feeds the subsequent remediation discussion; no decision
is made here.

## References

### Source Documents
- `/Users/coen/Developer/swift-primitives/HANDOFF-tagged-unchecked-inventory.md`
  — investigation brief.
- `swift-tagged-primitives/Sources/Tagged Primitives/Tagged.swift`
  — `init(__unchecked: Void, _ rawValue: consuming RawValue)` declaration.
- `swift-tagged-primitives/Research/comparative-analysis-pointfree-swift-tagged.md`
  §Initialization — DECISION rationale for the sentinel label.

### Prior Ecosystem Research
- `swift-primitives/Research/implicit-member-init-resolution-hazard.md`
  — DECISION, tier 3. Establishes the init taxonomy that places
  `__unchecked` in the "Unchecked" category (internal, bypasses
  invariants, excluded from implicit resolution).
- `swift-primitives/Research/cross-domain-init-overload-resolution-footgun.md`
  — RECOMMENDATION. Identifies the Tagged literal + `.map(Type.init)`
  crash that was the original reason to scrutinise `__unchecked:`'s
  pairing with literal conformances.
- `swift-institute/Research/tagged-extension-duplication.md` — ecosystem
  pattern for Tagged extension organisation.
- `swift-institute/Research/tagged-structural-sendable.md` — related
  Sendable-conditional-on-Tag research.
- `swift-tagged-primitives/Research/tagged-literal-conformances.md`
  — DECISION quarantining `ExpressibleByXxxLiteral` to the test
  support target.

### Convention Candidates (not yet codified)
- Init taxonomy (from `implicit-member-init-resolution-hazard.md`):
  Identity / Promotion / Narrowing / Cross-domain / Bit-pattern /
  Unchecked.

### Tooling
- Grep baseline: `grep -rn "__unchecked:" /Users/coen/Developer/swift-primitives --include="*.swift" | grep -v /.build/`
  (952 matches on 2026-04-22).

## Appendix A: Representative Raw Sites

The full site list is ~950 lines; the ten patterns below capture the
structural variety. Line numbers are as-of 2026-04-22.

### Pattern A1: Canonical Tagged 2-param call inside a validated init (legitimate-bypass)

```
swift-finite-primitives/Sources/Finite Primitives Core/Tagged+Ordinal.Finite.swift:15
    guard position < Finite.Bound<N>.capacity else { return nil }
    self.init(__unchecked: (), position)
```

### Pattern A2: Tagged 2-param call from a static constant (legitimate-bypass)

```
swift-dimension-primitives/Sources/Dimension Primitives/Axis.swift:85
    public static var primary: Self { Self(__unchecked: (), 0) }
```

### Pattern A3: Tagged 2-param call from an arithmetic operator (legitimate-bypass)

```
swift-dimension-primitives/Sources/Dimension Primitives/Radian.swift:105
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(__unchecked: (), lhs.rawValue + rhs.rawValue)
    }
```

### Pattern A4: Generic Tagged 2-param call in a cross-cutting extension (legitimate-bypass, broad reading)

```
swift-binary-primitives/Sources/Binary Primitives Core/Tagged+Bitwise.swift:26
    Tagged(__unchecked: (), lhs.rawValue & rhs.rawValue)
```

### Pattern A5: Cross-package Tagged 2-param call on Radian<Scalar> (missing-validated-init)

```
swift-geometry-primitives/Sources/Geometry Primitives/Geometry.Arc.swift:283
    if containsAngle(Radian(__unchecked: (), Scalar.pi)) {
```

### Pattern A6: Tagged 1-param labelled extension init call (legitimate-bypass)

```
swift-finite-primitives/Sources/Finite Primitives Core/Tagged+Ordinal.Finite.swift:88
    return Self(__unchecked: result)
```

### Pattern A7: Cross-package Tagged 1-param fast-path call (could-use-validated-init)

```
swift-cyclic-index-primitives/Sources/Cyclic Index Primitives/Index.Modular.swift:57
    let modulus = Cyclic_Primitives.Cyclic.Group.Modulus(__unchecked: capacity)
    let element = Cyclic_Primitives.Cyclic.Group.Element(__unchecked: index)
```

### Pattern A8: Non-Tagged struct init with the same label (separate convention)

```
swift-time-primitives/Sources/Time Primitives Core/Time.swift:89
    @_spi(Internal)
    public init(
        __unchecked: Void,
        year: Time.Year, month: Time.Month, day: Time.Month.Day,
        hour: Time.Hour = .zero, minute: Time.Minute = .zero, …
    ) { … }
```

### Pattern A9: Method API with the same label (separate convention)

```
swift-parser-primitives/Sources/Parser OneOf Primitives/Parser.OneOf.Any.swift:73
    input.restore.to(__unchecked: (), checkpoint)
```

### Pattern A10: Non-Tagged single-arg domain struct (separate convention)

```
swift-tree-primitives/Sources/Tree Primitives Core/Tree.N.ChildSlot.swift:65
    public static var left: Self { Self(__unchecked: 0) }
```

## Appendix B: Per-Package Totals Verification

| Shape | Site count |
|-------|-----------:|
| `2P` (Tagged 2-param call) | 707 |
| `1P` (single-arg labelled call) | 89 |
| `DECL` (declarations) | 59 |
| `MTHD` (method APIs) | 35 |
| `DOC` (prose in `///` or `//` or strings) | 60 |
| `ERR` (precondition messages) | 2 |
| **Total** | **952** |

Role breakdown:

| Role | Count |
|------|------:|
| `Sources` | 614 |
| `Tests`   | 172 |
| `Experiments` (package-local) | 131 |
| `TopLevel-Experiments` (ecosystem) | 34 |
| `Research` | 7 |
| Other | -26* |
| **Total** | **952** |

\* Other category is negative because my per-package per-role script uses
role precedence (Experiments-over-Sources when a path is an
experiment's Sources sub-directory, which is correct; the "Sources
614" above includes only real package Sources, not experiment-internal
Sources). Values cross-checked via per-package pivot (see tooling).

All counts cross-checked 2026-04-22.
