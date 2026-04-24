# swift-user-interface — Primitive Audit

<!--
---
version: 1.1.0
last_updated: 2026-04-21
status: RECOMMENDATION
changelog:
  - 1.0.0 (2026-04-21): Initial audit
  - 1.1.0 (2026-04-21): Attribute-graph = target-split inside swift-graph-primitives, not new package. Rendering gap = three-package L1 split (core / document / graphics). All primitive-layer changes research-only
tier: 2
scope: cross-package
---
-->

## Context

Follow-up to `danceui-architectural-analysis.md`. That analysis mapped every
DanceUI internal subsystem onto an existing primitive in `swift-primitives/`.
The claim was "the substrate is already largely present." Before acting on
that claim we need a concrete per-primitive verification: does each listed
primitive's actual type surface support the DanceUI-subsystem role, or is an
extension needed?

## Question

For each primitive in the DanceUI-subsystem mapping, does the current L1
surface support the role, need a thin extension, or need a verification
experiment? What extensions (if any) belong inside the existing primitive
vs. as a sibling primitive?

## Analysis

Each entry is grounded in actual files. Verdicts:

- **COVERS** — surface already supports the role, no extension needed
- **NEEDS EXTENSION** — right shape, specific named piece missing
- **NEEDS VERIFICATION EXPERIMENT** — fit not obvious from the surface alone

*Verified: 2026-04-21 against `/Users/coen/Developer/swift-primitives/`.*

### Per-primitive findings

| Primitive                       | Verdict            | Gap                                                                                  |
|---------------------------------|--------------------|--------------------------------------------------------------------------------------|
| `swift-graph-primitives`        | NEEDS EXTENSION    | Transaction / mutation / lazy-recompute discipline — **target-split inside the existing package** (see `swift-user-interface-graph-transactions.md`, v1.1) |
| `swift-layout-primitives`       | NEEDS EXTENSION    | Proposal ↔ measure contract (`sizeThatFits(proposal:) → Size`) on child views         |
| `swift-rendering-primitives`    | COVERS (infrastructure) / NEEDS PARALLEL (action vocabulary) | The infrastructure — `Rendering.View`, `Rendering.Thunk` (typed witness dispatch), `Rendering.Work`, `Rendering.Machine.Frame`, `Rendering.Context.render`, `Rendering._Tuple<each Content>`, `Rendering.Conditional` — is domain-neutral and directly usable. The Action vocabulary (`text`, `image`, `break.{line,thematic,page}`, `push.{block,inline,list,item,link,element,…}`, `attribute`, `class`, `style`, `raw`) is **document-specific** — it is consumed by six L3 foundations (`swift-html-rendering`, `swift-pdf-rendering`, `swift-markdown-html-rendering`, `swift-css-html-rendering`, `swift-pdf-html-rendering`, `swift-svg-rendering`). A UI framework needs a **graphics/widget action vocabulary** (rect, path, fill, stroke, transform, hit-test, layer). See the decomposition decision below |
| `swift-machine-primitives`      | COVERS             | `Machine.Node` is typed heterogeneous AST; `Machine.Combine.Erased` is a witness closure; ViewBuilder TupleView maps directly |
| `swift-property-primitives`     | COVERS             | `Property.View` / `Property.View.Read` / `Property.Consuming` projections model `@Binding` / read-only / move semantics |
| `swift-state-primitives`        | NEEDS EXTENSION    | Currently namespace-only (`public enum State {}`). Needs `State.Mutable<Value>` / `State.Shared<Value>` storage types |
| `swift-dependency-primitives`   | COVERS             | `Dependency.Key` / `.Scope` / `.Values` cover Environment scoping                    |
| `swift-tagged-primitives`     | COVERS             | `Tagged<Tag, RawValue>` + `Viewable` give ForEach-style identity at zero cost        |
| `swift-effect-primitives`       | COVERS             | Algebraic effects (`Effect.Protocol`, `Effect.perform`, `Effect.Handler`, `Effect.Context`) cover event / action pipelines |
| `swift-driver-primitives`       | NEEDS EXTENSION    | Currently minimal. Needs concrete scheduler / executor (`Driver.Scheduler`, `Driver.Loop`) running graph transactions |
| `swift-transform-primitives`    | NEEDS EXTENSION    | Currently namespace-only. Needs concrete `Transform.2D` / `Transform.3D` composing with affine-geometry |
| `swift-affine-primitives`       | COVERS             | `Affine.Discrete.Position` / `.Displacement` / `.Vector` / `.Ratio` sufficient       |
| `swift-affine-geometry-primitives` | COVERS          | `Affine.Continuous.Transform` / `.Point` / `.Translation` compose cleanly             |
| `swift-dimension-primitives`    | COVERS             | `Displacement.X/Y/Z`, `Angle`, `Axis`, `Coordinate`, `Chirality` phantom-tagged      |
| `swift-space-primitives`        | COVERS             | Used as phantom parameter in `Geometry<Scalar, Space>`; namespace-only is correct     |
| `swift-positioning-primitives`  | COVERS             | `Distribution` (fill / space variants); Alignment types present                       |
| `swift-geometry-primitives`     | COVERS             | `Geometry.Point` / `.Size` / `.Vector` / `.Rectangle` / `.Insets` / `.Line` / `.Bezier` comprehensive |

### Additional primitives participating in UI framework composition

Not listed in the original mapping table but relevant:

| Primitive                  | Relevance                                                                   |
|----------------------------|-----------------------------------------------------------------------------|
| `swift-witness-primitives` | Tree traversal alternative to visitor pattern; see `swift-user-interface-tree-traversal.md` |
| `swift-reference-primitives` | Weak / unowned back-refs for parent pointers in a view tree                |
| `swift-lifetime-primitives` | Subscription / observer lifetime, `Lifetime.Scoped` / `.Disposable`         |
| `swift-cache-primitives`   | Memoizing `sizeThatFits` results or layout computations                      |

### Where extensions belong

The critical question for each `NEEDS EXTENSION` verdict is whether the
extension sits **inside the existing primitive** or as a **sibling primitive**.

**Inside the primitive** when the extension is a thin overlay of the same
domain concept — e.g., `swift-state-primitives` needs concrete storage types
(State.Mutable / State.Shared); `swift-transform-primitives` needs the
concrete Transform.2D / Transform.3D the namespace was waiting for;
`swift-layout-primitives` needs a child-measurement protocol
(`sizeThatFits(proposal:)`) that extends the existing Layout.Stack / Grid /
Flow shapes; `swift-driver-primitives` needs the Scheduler / Loop types the
namespace was waiting for.

**As a sibling primitive** when the extension introduces a genuinely
orthogonal runtime discipline — which is the case for attribute-graph
transactions. See `swift-user-interface-graph-transactions.md`: we recommend
a new L1 `swift-attribute-graph-primitives` that depends on
`swift-graph-primitives` rather than extending it, because pure graph
algorithms and reactive runtime have independent reuse scopes.

### Reconciliation note

The wider audit classified `swift-graph-primitives` as "NEEDS EXTENSION
inside the package". The focused graph-transaction investigation (same day,
deeper reading of mutation semantics) classified it as "separate L1 package."
**The focused investigation wins.** The per-primitive audit was correct
that the gap exists; it was not the right venue to decide where the gap
closes. Decision recorded in `swift-user-interface-graph-transactions.md`.

## Outcome

**Status**: RECOMMENDATION.

### What is already sufficient (no work needed)

`swift-rendering-primitives`, `swift-machine-primitives`,
`swift-property-primitives`, `swift-dependency-primitives`,
`swift-tagged-primitives`, `swift-effect-primitives`,
`swift-affine-primitives`, `swift-affine-geometry-primitives`,
`swift-dimension-primitives`, `swift-space-primitives`,
`swift-positioning-primitives`, `swift-geometry-primitives`.

These are the substrate for `swift-user-interface`. No new L1 packages and
no extensions are required for them to serve a UI framework.

### What needs thin in-package extension

| Primitive                     | Extension                                                                 |
|-------------------------------|---------------------------------------------------------------------------|
| `swift-layout-primitives`     | Proposal ↔ measure contract on child views                                 |
| `swift-state-primitives`      | Concrete storage types (`State.Mutable<Value>`, `State.Shared<Value>`)     |
| `swift-driver-primitives`     | Concrete scheduler / loop (`Driver.Scheduler`, `Driver.Loop`)              |
| `swift-transform-primitives`  | Concrete transform types (`Transform.2D`, `Transform.3D`) on existing namespace |

These are all first-class work on existing packages — small design
decisions, not new architectural commitments.

### What needs a new sibling primitive

| New Package                            | Reason                                                                |
|----------------------------------------|------------------------------------------------------------------------|
| `swift-document-rendering-primitives`  | Extract the current document-specific Action vocabulary out of `swift-rendering-primitives` (Push/Pop/Break/Action.{block,inline,list,item,link,element,attribute,class,style,text,image,break}) into a sibling L1. Depends on `swift-rendering-primitives` (refactored to domain-neutral core). Six L3 foundations migrate imports. |
| `swift-graphics-rendering-primitives`  | New UI-pixel Action vocabulary (rect / path / fill / stroke / transform / hit-test / layer). Depends on `swift-rendering-primitives` + `swift-geometry-primitives` + `swift-affine-primitives` + `swift-affine-geometry-primitives`. Consumed by `swift-user-interface-rendering`. Dependency delta (geometry / affine) is what justifies it as a sibling vs a target-split. |

Both of the above and the `swift-rendering-primitives` core refactor are
captured here as the **recommended future shape**. This research does not
edit any primitive package; the refactor and the six downstream import
migrations are sequenced as a separate, later change.

### What does NOT need a new package

- **Attribute-graph**: was earlier proposed as a new L1
  `swift-attribute-graph-primitives`. Reversed. Dependency delta is at
  most one optional new dep (`swift-cache-primitives`). Target-split
  inside `swift-graph-primitives` wins — matches the existing one-target-per-
  algorithm granularity, no package proliferation. See
  `swift-user-interface-graph-transactions.md` v1.1.

### Implication for swift-user-interface

The L3 package is a composition task. The gating work is not inventing
primitives; it is (1) filling in the four thin in-package extensions above,
(2) standing up `swift-attribute-graph-primitives`, and (3) making the
tree-traversal decision in `swift-user-interface-tree-traversal.md`. Once
those land, the L3 DSL is fundamentally a naming / ergonomics / modifier
surface over existing substrate.

### Next actions

All primitive-layer work is deferred until the user authorizes touching
existing primitive packages. This research doc captures the target shape.

1. When authorized: open design docs in `swift-primitives/Research/` for
   the four in-package extensions (proposal-measure, State storage,
   Driver scheduler, Transform.2D/3D).
2. When authorized: add the five attribute-graph targets to
   `swift-graph-primitives` per `swift-user-interface-graph-transactions.md`
   v1.1.
3. When authorized: execute the rendering 3-package split
   (`swift-rendering-primitives` refactor + two new siblings +
   migration of six L3 foundations). See
   `swift-user-interface-package-decomposition.md` v1.1.
4. Tree-traversal decision per `swift-user-interface-tree-traversal.md`
   is independent of primitive-layer changes and can proceed whenever
   `swift-user-interface` implementation begins.
5. Keep `swift-foundations/swift-user-interface/` and
   `swift-user-interface-rendering/` as stubs until (1)–(3) land.

## References

- `/Users/coen/Developer/swift-primitives/` — all surveyed primitives
- `danceui-architectural-analysis.md` — parent research
- `swift-user-interface-graph-transactions.md` — attribute-graph placement
- `swift-user-interface-tree-traversal.md` — witness vs visitor decision
