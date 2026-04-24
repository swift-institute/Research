# DanceUI Architectural Analysis

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

ByteDance released [DanceUI](https://github.com/bytedance/DanceUI) — a
declarative UI framework whose stated goals are (1) reuse of the SwiftUI
developer ecosystem via API-level compatibility and (2) broad platform support
with an iOS 13 minimum deployment target. The project ships as a trio of
repositories: `DanceUI` (the public-surface framework), `DanceUIGraph` (a
separately distributed attribute-graph engine), and `DanceUIRuntime` (a C++
runtime built on Boost).

Before we design `swift-user-interface` (Layer 3), we want to understand what
the ByteDance team chose to build, what is forced by their "be SwiftUI-shaped"
constraint, what is genuinely re-usable insight, and what we deliberately do
not want to copy. The primitive substrate a UI framework needs is already
broadly present in `swift-primitives` — `swift-graph-primitives`,
`swift-layout-primitives`, `swift-rendering-primitives`,
`swift-machine-primitives`, `swift-property-primitives`,
`swift-dependency-primitives`, `swift-tagged-primitives`,
`swift-state-primitives`, `swift-effect-primitives`, `swift-driver-primitives`,
and the geometry/transform/space family. The question this research answers is
how DanceUI's internal decomposition maps onto what we already have, and what
thin gaps (if any) remain.

**Trigger**: external release of a substantive SwiftUI-shaped framework whose
internal decomposition is visible for the first time.

**Constraints on our future package**:
- Must sit at Layer 3 (Foundations) of the Swift Institute architecture
- May depend on Layer 1 primitives and Layer 2 standards only
- No Foundation (at primitives); typed throws; Nest.Name naming; one type per file
- Swift 6.3/6.4 baseline, ~Copyable and strict memory safety available
- No C++ runtime shim; no CocoaPods; no reflection as a core dependency

**Stakeholders**: the eventual swift-user-interface package and any primitives
it needs. Broader than a single target — hence filed at the superrepo root.

## Question

What is DanceUI's architecture, what does it tell us about the real
decomposition of a SwiftUI-shaped framework, and what should we carry forward
(or deliberately avoid) when we design `swift-user-interface` and its
supporting primitives?

## Analysis

### 1. Repository layout

Three separately-released repositories:

| Repo                | Role                                                  |
|---------------------|-------------------------------------------------------|
| `DanceUI`           | Public view DSL, modifiers, services, FWK integration |
| `DanceUIGraph`      | Attribute graph engine (AttributeGraph analog)        |
| `DanceUIRuntime`    | C++ runtime (depends on Boost 1.x)                    |

Inside `DanceUI` itself:

```
Sources/DanceUI/
    AppStructure/      State, Binding, Environment, PreferenceKey, ...
    UIElements/        View, Text, Button, Shape, Color, Image, Picker, ...
    ViewContainers/    ScrollView, NavigationView, ForEach, Section, ...
    Interactivity/     Gestures, input
    UserInput/         TextField, submit labels
    FrameworkIntegration/ UIViewRepresentable, UIHostingController
    Services/          AsyncImage, HostApp, Tracker, FeatureToggle, Settings
    Internal/          DataFlow, Graph, Layout, Paint, Update, ViewList,
                       Transition, Visitor, Display, Threading, ...
Sources/DanceUIShims/  .modulemap + C/ObjC shims
Modules/
    DanceUICompose/    Rendering (Canvas, Paragraph, Vector, Paint)
    DanceUIObservation/ Observation backport + macro (iOS 13+ target)
    DanceUIComposeModule/
    RxAnnotation/      Annotation shim
    RxCoreComponents/  Precompiled C++ components (include/ + lib/)
    RxFoundation/      Precompiled C++ Foundation analog (include/ + lib/)
    RxInjector/        DI shim
```

**Observation**: the public view-DSL layer is a relatively thin facade over
substantial internal subsystems (`Internal/` dwarfs the public tree). This
mirrors SwiftUI's own shape, where the declarative surface hides an attribute
graph, a layout engine, and a render tree.

### 2. Source-compatibility as a design axis

Public `View` types declare exactly SwiftUI's hidden hooks:

```swift
public protocol View {
    associatedtype Body : View
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
    static func _viewListCount(inputs: _ViewListCountInputs) -> Int?
    @ViewBuilder @MainActor @preconcurrency
    var body: Self.Body { get }
}
```

The underscored static hooks, `_GraphValue<T>`, `_ViewInputs`, `_ViewOutputs`,
`_ViewListInputs`, `_ViewListOutputs`, and `_ViewListCountInputs` are all taken
directly from SwiftUI's private ABI. The goal is explicit: any existing
SwiftUI-targeting code (including code that calls the underscored escape
hatches) should be recompilable against DanceUI with no source changes.

**Consequence**: every design decision in DanceUI that looks odd by our
conventions — compound names (`ViewBodyAccessor`, `LayoutEngineProtocol`,
`DynamicPropertyCache`), class-based property boxes, heavy use of
`AnyKeyPath`, visitor dispatch — is load-bearing for SwiftUI source-compat.
They are not choices about how a UI framework *should* look; they are
constraints imposed by trying to be a drop-in SwiftUI replacement.

This is the single most important frame for the whole analysis: **source-compat
with SwiftUI is the goal, and it warps the internal design to match SwiftUI's
internal design, including SwiftUI's own compromises**.

We have no such constraint.

### 3. Internal subsystem decomposition

`Sources/DanceUI/Internal/` carves the problem into clearly-named subsystems.
This is the decomposition worth studying independently of the source-compat
overlay:

| Subsystem             | Responsibility                                                 |
|-----------------------|----------------------------------------------------------------|
| `DataFlow`            | Property locations, projections, preference combiners           |
| `Graph`               | Attribute graph inputs/outputs, graph host, transactions        |
| `Layout`              | Layout engine, layout computer, proxies, proposed sizes         |
| `Paint`               | Resolved paint, paint types, anchored paints                    |
| `ViewList`            | Variadic view children, implicit roots, identity                |
| `Update`              | Invalidation / update scheduling                                 |
| `Transition`          | Animation and transition plumbing                                |
| `Event`               | Input event pipeline                                             |
| `Accessibility`       | A11y attributes and traversal                                    |
| `Display`             | Display-side rendering hooks                                     |
| `DynamicContainer`    | Dynamic list / content containers                                |
| `Style` / `Spacing`   | Style resolution, spacing tokens                                 |
| `Subscription`        | Publisher-like subscription plumbing                             |
| `Threading`           | Main-thread / background coordination                            |
| `Visitor`             | Type-erased tree traversal                                       |
| `ADT`                 | Object cache, inline array, bloom filter, stack                  |
| `Math`                | Vector / affine / misc. math                                     |
| `ViewGenerator`, `BodyAccessing`, `ViewAlias`, `ViewDebug` | ViewBuilder / DSL support |

The clean-room observation is that a SwiftUI-shaped framework needs all of
these, and several of them are naturally independent: the **attribute graph**,
the **layout engine**, the **paint model**, the **identity/viewlist algebra**,
and the **reactive dataflow** are each substantive on their own terms. They
compose, but each has a well-defined interface.

### 4. The attribute graph is a separate package

The choice to ship `DanceUIGraph` as a *separate* repository is significant.
It is imported internally (`internal import DanceUIGraph`) from the view layer,
and its surface (`_Graph`, `_GraphValue<T>`, `_GraphInputs`) is the
dependency boundary between the view DSL and the reactive core.

**This validates that a declarative UI framework factors cleanly into two
tiers**: an attribute-graph / reactive-dataflow substrate, and a view-DSL
layer built on top of it. We already have pieces of the substrate
(`swift-property-primitives`, observation/signal infrastructure, indices).
A `swift-reactive-primitives` (or `swift-attribute-graph-primitives`) package
at L1, plus possibly a reactive-witness spec at L2, is the right foundation
for anything UI-shaped at L3.

### 5. The C++ runtime (DanceUIRuntime / RxFoundation / RxCoreComponents)

DanceUIRuntime is a C++17 library built against Boost (`OTHER_CPLUSPLUSFLAGS`
references `fno-aligned-allocation`, and the podspec points into
`DanceUIDependencies/boost`). `RxFoundation` and `RxCoreComponents` ship as
precompiled C++ libraries with C headers.

**Why it exists**: AttributeGraph equivalents in Swift are hard to write at
SwiftUI's performance target without reflection tricks and cache-friendly
layout. Going to C++ is a shortcut around Swift's historical weaknesses here.

**What we do differently**: we have ~Copyable, `@_rawLayout`, typed indices,
inline storage primitives (Buffer.Inline, Slab), strict memory safety, and a
Swift-native observation model. We can build the same attribute-graph
semantics without a C++ runtime. That is a major delta — DanceUI's C++ core is
a workaround for capabilities we already have in the primitives layer.

### 6. Observation backport

`DanceUIObservation` is a standalone SwiftPM package that re-implements
`@Observable`, `ObservationRegistrar`, and `ObservationTracking` so they work
on iOS 13+. It ships a companion macro plugin (`DanceUIObservationMacro` /
`DanceUIObservationMacroImpl`). The registrar uses `AnyKeyPath`-keyed
observer sets with `@Sendable` closures over `@unchecked Sendable` state.

**Relevance to us**: our baseline is Swift 6.3+. We do not need an Observation
backport. We do need our own observation/signal layer at the primitives tier
(distinct from Apple's `Observation` module, distinct from Foundation). That
already exists in the ecosystem as `swift-property-primitives` plus the
signal/observation work. DanceUIObservation is a datapoint that an
observation model with macro-driven registration is feasible entirely outside
of Apple's stdlib.

### 7. DanceUICompose

`DanceUICompose` sits on top of the view layer and provides the *rendering*
half: Canvas, Paragraph layout, Vector, Gradient, Paint, RenderNode layers,
UIView integration. It is the thing that turns a resolved view tree into
pixels via `UIView`. It also depends on Paragraph for text layout.

**Relevance to us**: rendering is its own Layer 3/4 concern, built on graphics
primitives (`swift-geometry`, `swift-color`). It should not be inside
`swift-user-interface`; it is its own foundation, or an application-layer
integration.

### 8. Naming and type-design choices

DanceUI uses pervasive compound names: `ViewBodyAccessor`, `LayoutEngineProtocol`,
`DynamicPropertyCache`, `AnimatableFrameAttribute`, `PreferenceCombiner`,
`MultiPreferenceCombinerVisitor`, `CachedEnvironment`, `ProjectionTransform`,
`LayoutPriorityTraitKey`, `GraphHost`, `RootTransform`, `SizeThatFitsObserver`,
`ImplicitRootVisitor`, and hundreds more. Many are required for SwiftUI
source-compat (`PreferenceKey`, `LayoutValueKey`, `ViewBuilder`); many are
purely internal and would nest naturally under our Nest.Name convention
(`View.Body.Accessor`, `Layout.Engine`, `DynamicProperty.Cache`,
`Preference.Combiner`, `Graph.Host`).

**Takeaway**: DanceUI's type names are not an argument against our conventions;
they are an illustration of what SwiftUI's surface forces. For our
clean-room framework, the Nest.Name discipline applies with no compromise.
The one exception space we already acknowledge is SwiftUI-interop adapters,
which by definition must type-match SwiftUI.

### 9. Visitor pattern as the traversal mechanism

DanceUI uses visitors extensively (`MultiPreferenceCombinerVisitor`,
`PairwisePreferenceCombinerVisitor`, `ResolvedPaintVisitor`,
`_VariadicView_ImplicitRootVisitor`, `MakeViewRoot`). This is the conventional
pattern for traversing a heterogeneous tree of `some View` nodes where the
concrete types are not known uniformly — the visitor opens the existential.

**For us**: visitors are a workable pattern, but we have an alternative worth
analyzing before committing: **witnesses** (via `@Witness`-style dual
defunctionalization) can represent the same traversal without existential
erasure and with typed throws. A separate investigation should compare
visitor vs witness for a view-tree traversal, specifically around
`@ViewBuilder`'s variadic tuple case.

### 10. iOS 13 baseline is the primary constraint

Many of DanceUI's compromises — the Observation backport, the back-deployed
macros, the `@preconcurrency @MainActor` annotations everywhere, the
Foundation imports inside `_Graph.swift` for Darwin availability — exist
because of iOS 13. We target modern Swift and modern platforms. Most of
DanceUI's iOS 13 scaffolding simply disappears for us.

### Cross-cutting observations

Each DanceUI subsystem has a close counterpart already in `swift-primitives`.
The table is the single most load-bearing output of this research:

| DanceUI subsystem                                                  | Closest existing primitive in our ecosystem                                          |
|--------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `DanceUIGraph` (attribute-graph engine, separate repo)              | `swift-graph-primitives` (adjacency, BFS/DFS, SCC, topological, reachability, shortest-path, transitive closure) |
| `Internal/Graph` (graph host, transactions, inputs/outputs)         | `swift-graph-primitives` + `swift-driver-primitives` (execution), `swift-effect-primitives` (transactions) |
| `Internal/Layout` (engine, computer, proxies, proposals)            | `swift-layout-primitives` (Layout.Flow, Layout.Grid, Layout.Grid.Lazy, Layout.Line, Layout.Stack, Alignment, Axis) |
| `Internal/Paint` + `DanceUICompose` rendering                       | `swift-rendering-primitives` (Rendering.Machine, Action.Push/Pop/Break, Builder, Context) + `swift-geometry-primitives` + `swift-color` |
| `Internal/DataFlow` (Location, Projection, StoredLocation)          | `swift-property-primitives` (Property.Typed, Property.View, Property.View.Read, Property.Consuming) |
| `Internal/DataFlow/PreferenceCombiner`                              | `swift-graph-primitives` fold + `swift-rendering-primitives` action stream           |
| `AppStructure/Environment`                                          | `swift-dependency-primitives` (Dependency.Key, Dependency.Scope, Dependency.Values)  |
| `AppStructure/State`, `AppStructure/Binding`                        | `swift-state-primitives` + `swift-property-primitives`                               |
| `Internal/ViewList` identity                                        | `swift-tagged-primitives` (Tagged + Viewable)                                       |
| `_VariadicView` tuple machinery                                     | `swift-machine-primitives` (Machine.Node, Machine.Next, Machine.Combine) + `swift-rendering-primitives` |
| `Internal/Update` (invalidation, scheduling)                        | `swift-machine-primitives` + `swift-driver-primitives` + `swift-effect-primitives`   |
| `Internal/Transform`, `ProjectionTransform`                         | `swift-transform-primitives` + `swift-affine-primitives` + `swift-affine-geometry-primitives` |
| `Internal/Layout` sizing (ProposedViewSize, ViewDimensions)         | `swift-dimension-primitives` + `swift-space-primitives` + `swift-positioning-primitives` |
| `Internal/Event` (gesture/input pipeline)                           | `swift-effect-primitives` + `swift-driver-primitives`                                 |
| `DanceUIRuntime` C++ Boost runtime                                  | Not applicable; ~Copyable + `@_rawLayout` + typed indices + existing graph/machine primitives remove the motivation |
| Visitor pattern for tree traversal                                  | `swift-rendering-primitives` (tree-walk produces an action stream) + witnesses        |
| `_makeView` / `_GraphValue` / `_ViewInputs` leakage                 | Not a target; substrate stays internal                                                |
| CocoaPods, iOS 13 scaffolding, `@preconcurrency`                    | Not applicable                                                                        |

## Outcome

**Status**: RECOMMENDATION.

### What to take from DanceUI

1. **The separation of the attribute-graph runtime from the view DSL is correct.**
   DanceUI ships it as a separate repo; we should ship it as a separate
   primitive. `swift-user-interface` should not contain its reactive substrate.

2. **The internal subsystem decomposition is informative.** Layout, Paint,
   Preference, Identity/ViewList, Update, Transition, Event, Accessibility,
   and Style are genuinely separable. We should expect an analogous split in
   any SwiftUI-shaped framework we build, and we should pre-emptively put the
   pieces that have reuse beyond UI (layout, paint, reactive dataflow) into
   primitives rather than into the foundation target.

3. **Macro-driven observation from outside the stdlib is feasible.** We do not
   need to backport, but the pattern (registrar + tracking + macro plugin)
   generalizes, and our property/observation primitives already follow it in
   spirit.

4. **Source-compat with SwiftUI is a distinct project from "a declarative UI
   framework."** DanceUI is the former. Our `swift-user-interface` should be
   the latter — a clean-room declarative UI DSL that obeys our conventions
   and uses our primitives, with SwiftUI interop available as a separate L3
   or L4 adapter package (mirroring how we treat Foundation interop).

### What to avoid

1. **C++ runtime.** Not needed. Every capability DanceUIRuntime delivers
   (packed attribute records, cache locality, keyed observer sets) is
   expressible in Swift given our primitives.

2. **Exposing SwiftUI's underscored ABI.** `_makeView`, `_GraphValue`,
   `_ViewInputs`, `_ViewOutputs` are SwiftUI's leaked internals. Our view
   protocol should stay sealed behind public surface; the reactive-graph
   substrate lives in a separate module and its types are not re-exported
   through the View protocol.

3. **Compound identifiers.** Everything DanceUI names `XYZCombiner`,
   `XYZCache`, `XYZVisitor`, `XYZTraitKey`, `XYZHost` nests under Nest.Name
   for us. Draft all types through that discipline from day one.

4. **Visitor-first traversal.** Evaluate witnesses before committing. Spawn a
   follow-up investigation comparing visitor vs witness for view-tree
   traversal, particularly for the `TupleView` / `_VariadicView` case.

5. **iOS 13 back-compat scaffolding.** We target Swift 6.3+; the
   `@available(iOS 13.0, *)` / `@preconcurrency` decoration is not our
   problem.

### Implications for package shape

The substrate is **largely already present** in `swift-primitives`. Every
major subsystem DanceUI carves out internally maps to an existing L1 package
(see the mapping table above). The L3 `swift-user-interface` package is a
composition of already-extant primitives, not a project that requires new
primitives to be built from scratch.

| Layer | Package                                     | Status   | Role in a UI framework                                    |
|-------|---------------------------------------------|----------|-----------------------------------------------------------|
| L1    | `swift-graph-primitives`                    | exists   | Attribute-graph / dependency tracking / topological update |
| L1    | `swift-layout-primitives`                   | exists   | Flow / Stack / Grid / Line layout algebra                 |
| L1    | `swift-rendering-primitives`                | exists   | Tree-walk → action-stream rendering machine               |
| L1    | `swift-machine-primitives`                  | exists   | Machine.Node / Next / Combine — view-tree evaluation      |
| L1    | `swift-property-primitives`                 | exists   | `@State`, `@Binding`, typed property views                |
| L1    | `swift-state-primitives`                    | exists   | State storage base                                        |
| L1    | `swift-dependency-primitives`               | exists   | Environment (Dependency.Key / Scope / Values)             |
| L1    | `swift-tagged-primitives`                 | exists   | ViewList identity via Tagged                              |
| L1    | `swift-effect-primitives`                   | exists   | Event/action pipeline, handlers, continuations            |
| L1    | `swift-driver-primitives`                   | exists   | Update scheduling / execution driver                      |
| L1    | `swift-transform-primitives` + affine/space | exists   | ViewTransform, ProjectionTransform, sizing                |
| L1    | `swift-geometry-primitives` + dim/position  | exists   | Proposal / ViewGeometry / ViewDimensions                  |
| L3    | `swift-color` (foundations)                 | exists   | Paint color substrate                                     |
| L3    | `swift-user-interface`                      | **stub** | Declarative view DSL, modifiers, composition              |
| L3?   | swift-user-interface-* split                | **open** | Paint / rendering / SwiftUI-interop possibly separate L3  |

**What might still be missing at L1** (to be verified, not assumed):

1. **Attribute-graph phase protocol** — DanceUI has `GraphInput`, `GraphMutation`,
   `AsyncTransaction`, `VersionSeed`. `swift-graph-primitives` has the
   structural graph; we may still need a phase/transaction discipline on top
   of it for incremental recomputation. Likely belongs in
   `swift-graph-primitives` itself, not a new package.
2. **Layout proposal ↔ measure protocol** — `swift-layout-primitives` has
   Layout.Flow / Grid / Stack shapes. It is worth verifying it already models
   SwiftUI-style `sizeThatFits(proposal:subviews:)` semantics; if not, that is
   an *extension* to `swift-layout-primitives`, not a new package.
3. **Preference combine** — likely expressible as a graph fold in
   `swift-graph-primitives` plus the rendering action stream; verify rather
   than add.
4. **Variadic view tuple algebra** — ViewBuilder's `TupleView` is a specific
   shape of `swift-machine-primitives`. Verify the fit before adding.

### Next actions

These replace the earlier plan — existing primitives turn most "research
whether this belongs at L1" questions into "verify the L1 already covers
it."

1. **Audit each existing primitive against the DanceUI-subsystem-mapping
   table.** For every row, check that the listed primitive actually supports
   the shape a view-DSL composition would need. Emit a per-primitive delta:
   "covers it", "needs extension X", "needs verification experiment".
2. **Witness vs visitor for view-tree traversal.** Still worth doing. The
   candidate substrate is `swift-machine-primitives` + `swift-rendering-primitives`;
   the question is whether `@ViewBuilder`'s `TupleView` shape composes
   cleanly on top of Machine.Node / Rendering.Builder without reaching for
   visitors.
3. **Attribute-graph transaction/phase discipline.** Verify whether
   `swift-graph-primitives` already offers mutation + topological
   recomputation at the right granularity, or whether a thin phase overlay
   is needed (and if so, inside `swift-graph-primitives`, not a new package).
4. **Paint / rendering target placement.** DanceUI keeps `DanceUICompose`
   (paint / canvas / paragraph) as a separate module on top of the view
   layer. Decide whether our analog lives inside `swift-user-interface` or as
   a sibling L3 foundation (`swift-user-interface-rendering` or similar). Do
   not pre-commit.
5. **SwiftUI interop target.** If a SwiftUI adapter is wanted, it is its own
   L3 foundation package (`swift-user-interface-swiftui-interop` or similar)
   and is deliberately the only place where our Nest.Name discipline yields
   to SwiftUI's flat naming — the same way Foundation interop is quarantined
   elsewhere in the ecosystem.
6. Expand this stub's `exports.swift` only once (1)–(4) land.

The stub stays a stub, but the gating work is verification of existing
primitives, not construction of new ones.

## References

- [DanceUI](https://github.com/bytedance/DanceUI) — public repository
- [DanceUIGraph](https://github.com/bytedance/DanceUIGraph) — attribute graph
- [DanceUIRuntime](https://github.com/bytedance/DanceUIRuntime) — C++ runtime
- Local clone: `/Users/coen/Developer/bytedance/DanceUI`
- `Sources/DanceUI/UIElements/View/View.swift` — View protocol definition
- `Sources/DanceUI/Internal/Graph/_Graph.swift` — graph host entry
- `Sources/DanceUI/Internal/Layout/Layout.swift` — Layout protocol
- `Modules/DanceUIObservation/Sources/DanceUIObservation/` — observation backport
- `Modules/DanceUICompose/Sources/DanceUICompose/` — render / Canvas / Paragraph
- Internal Swift Institute conventions: `[API-NAME-001]`, `[API-NAME-002]`,
  `[API-ERR-001]`, `[PRIM-FOUND-001]`, `[ARCH-LAYER-*]`
