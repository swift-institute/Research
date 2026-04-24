# swift-user-interface — Package Decomposition

<!--
---
version: 1.1.0
last_updated: 2026-04-21
status: RECOMMENDATION
changelog:
  - 1.0.0 (2026-04-21): Initial — rendering sibling L3, SwiftUI-interop deferred, graphics-rendering primitive deferred
  - 1.1.0 (2026-04-21): Adopt 3-package rendering primitive split (core / document / graphics) as the recommended future shape. Research-only; no primitive package edits proposed now
tier: 2
scope: cross-package
---
-->

## Context

Follow-up to `danceui-architectural-analysis.md`. DanceUI ships the
declarative view DSL (`DanceUI`), the attribute-graph runtime
(`DanceUIGraph`), the C++ core (`DanceUIRuntime`), the rendering /
paint / canvas module (`DanceUICompose`), and the Observation backport
(`DanceUIObservation`) as five separate repositories. The parent research
recommends that our analog *also* separate concerns — but punted on (a) where
paint / rendering lives, and (b) whether a SwiftUI-interop adapter is wanted.

Also informed by the new finding from the primitive audit: our
`swift-rendering-primitives` is a **document-rendering** substrate
(HTML / PDF / SVG / Markdown), not a UI-pixel renderer. A UI framework needs
a graphics / widget vocabulary, not document structure.

## Question

1. Where does UI-pixel rendering (paint, canvas, vector, hit-testing) live
   relative to `swift-user-interface`?
2. Is a SwiftUI source-interop adapter wanted? If yes, where does it live?

## Analysis

### 1. Rendering placement

DanceUI's `DanceUICompose` contains: Canvas, ColorFilter, Gradient, Image,
Paint, Paragraph, PathOps, RenderNodeLayer, VectorImage, plus the
`ComposeRenderingUIViewImpl` bridge to `UIView`. It sits structurally
*above* the view-DSL layer — it consumes resolved views and produces UIKit
render nodes.

Three options for us:

#### Option A — rendering lives inside `swift-user-interface`

The view DSL package contains paint, canvas, hit-test, and the platform
adapter.

- **Pros**: one-import ergonomics; tight coupling where it naturally
  belongs.
- **Cons**: conflates two concerns — *declarative view algebra* (compose,
  modify, measure, diff) and *pixel rendering* (paint stream, transform,
  layer backing). Makes the package a monolith. Cannot plug in alternative
  backends (software, Metal, CoreGraphics, Skia bindings, web canvas)
  without cross-cutting changes.

#### Option B — sibling L3 `swift-user-interface-rendering`

Paint / canvas / render-node / hit-test live in a sibling foundations
package that depends on `swift-user-interface` (or on the substrate below
it) and exposes a backend-agnostic rendering surface. Platform backends
(CoreGraphics, Metal, web canvas) are *their own* L3 packages consuming
this one.

- **Pros**: clean separation of "describe a UI" from "paint a UI";
  mirrors DanceUI's own split (`DanceUI` vs `DanceUICompose`); backend
  swapping is a package choice, not a compile-flag choice.
- **Cons**: two packages to import in a real app; clear interface between
  them has to be designed carefully.

#### Option C — three-package L1 split: core / document / graphics

`swift-rendering-primitives` is refactored into a domain-neutral core,
and the document and graphics vocabularies become sibling L1 packages
that depend on it:

```
swift-rendering-primitives             (L1, refactored to core only)
    View, Thunk, Work, Machine.Frame, Context (shell), _Tuple, Conditional,
    Builder, Speculative, Pair, Group, Indirect, Empty

swift-document-rendering-primitives    (L1, new; depends on swift-rendering-primitives)
    Action.{text,image,break,attribute,class,raw,style}, Push.{block,inline,
    list,item,link,attributes,element,style}, Pop.{...}, Break.{line,thematic,
    page}, Semantic.{Block,Inline,List}

swift-graphics-rendering-primitives    (L1, new; depends on swift-rendering-primitives
                                         + swift-geometry-primitives
                                         + swift-affine-primitives
                                         + swift-affine-geometry-primitives)
    Action.{rect,path,fill,stroke,transform,hit-test,layer,…}, Push / Pop / Break
    (graphics-specialized), Context fields for pixel output
```

- **Dependency delta justifies the split**: document vocabulary needs no
  new deps; graphics vocabulary needs geometry + affine primitives that
  `swift-rendering-primitives` does not and should not carry (it would
  force document-only consumers like `swift-html-rendering` to transitively
  pull geometry).
- **Mirrors the attribute-graph analysis**: the deciding criterion is
  "does the new vocabulary need new deps?" For graphics, yes. For
  document, no — but the user's direction was explicit here, and keeping
  the two vocabularies symmetric (both extract to siblings, core goes
  neutral) is the clean move.
- **Migration cost**: six L3 foundations (`swift-html-rendering`,
  `swift-pdf-rendering`, `swift-markdown-html-rendering`,
  `swift-css-html-rendering`, `swift-pdf-html-rendering`,
  `swift-svg-rendering`) update their imports from
  `Rendering_Primitives_Core` to include
  `Document_Rendering_Primitives`. One-time change.
- **Pros**: backend-agnostic core; vocabulary-specific siblings; no
  cross-contamination of deps; symmetric story.
- **Cons**: three packages where there was one; migration across six
  foundations. Primitive-layer change, sequenced separately from the UI
  framework.

### Comparison

| Criterion                           | A (inside L3)    | B (sibling L3)     | C (three-package L1 split + sibling L3) |
|-------------------------------------|------------------|--------------------|------------------------------------------|
| Package count change                 | 0                | +1 L3              | +1 L3, +2 L1, -0 (refactor L1)          |
| Backend swappability                 | Painful          | Easy                | Easy                                     |
| Reuse outside UI                     | No               | Limited             | Yes (graphics primitive standalone)      |
| Mirrors document-rendering stack     | No               | Partial             | Yes (fully symmetric)                    |
| Dependency isolation at L1           | N/A              | N/A                 | Yes (doc consumers don't pull geometry)  |
| Cross-package migration cost         | None             | None                | 6 L3 foundations update imports          |
| Primitive-layer churn                | None             | None                | High                                     |
| Authorized to touch primitives?       | N/A              | N/A                 | No (research only, pending user OK)     |

### Recommendation for (1)

**Option C is the destination; Option B is the scaffolding step.** Create
`swift-foundations/swift-user-interface-rendering` as a sibling L3 now
(already done). The L1 refactor
(`swift-rendering-primitives` → core + document + graphics) is the right
shape long-term, but is a primitive-layer change with downstream
migration cost across six foundations and is **not authorized** by this
research — it is captured here so that when implementation time comes,
the direction is known. Until then, `swift-user-interface-rendering`
uses a private action vocabulary inside its own target.

### 2. SwiftUI source-interop adapter

DanceUI's **entire** design is SwiftUI source-compat. Our
`swift-user-interface` is explicitly not that. The question is whether a
*separate* adapter package is wanted that lets existing SwiftUI code be
recompiled against our framework with minimal changes.

Three options:

#### Option A — no adapter; deliberate incompatibility

Ship the framework with our own naming (Nest.Name), our own view
protocol, our own modifier style. Users migrate by rewriting.

- **Pros**: maximum design freedom; no flat-name pollution in our
  namespace; no surface-area compromise.
- **Cons**: adoption friction; new users with existing SwiftUI code can't
  try us cheaply.

#### Option B — interop adapter as separate L3 `swift-user-interface-swiftui-interop`

Dedicated package that defines SwiftUI-flat names (`View`, `Text`,
`VStack`, `Binding`, `@State`, etc.) as thin wrappers over our
Nest.Name types. Compound names and flat-namespace style are allowed
*only* in this package; the rest of the ecosystem retains discipline.

- **Pros**: adoption path for SwiftUI users; compound-name / flat-style
  exception is sandboxed; ecosystem conventions stay intact everywhere
  else. Parallel to how Foundation interop is handled — quarantined.
- **Cons**: adapter work is non-trivial; risk of adapter lagging behind
  the main framework; some SwiftUI behavior is impossible to replicate
  (e.g., `_makeView` leakage).

#### Option C — first-class dual naming inside `swift-user-interface`

The framework itself exposes both Nest.Name and SwiftUI-flat APIs.

- **Pros**: single import.
- **Cons**: pollutes our namespace with compound / flat names; violates
  our discipline as a matter of policy; creates uncertainty about which
  name is canonical.

### Comparison

| Criterion                               | A (none)       | B (sibling) | C (dual) |
|-----------------------------------------|----------------|-------------|----------|
| Preserves Nest.Name discipline           | Yes            | Yes         | No       |
| Adoption friction                         | High           | Low         | Low      |
| Maintenance cost                          | Zero           | Non-trivial | Highest  |
| Policy clarity                            | Clear          | Clear       | Muddied  |
| Sandboxing exception                      | N/A            | Localized   | Global   |

### Recommendation for (2)

**Option B, but deferred.** Design the framework in its Nest.Name shape.
When it is mature enough that a source-compat adapter can be written
*without* distorting the base design, create
`swift-foundations/swift-user-interface-swiftui-interop` as the single
location where SwiftUI-flat naming is permitted. Do not start the
adapter before the base framework stabilizes — otherwise adapter
pressures will distort the base.

## Outcome

**Status**: RECOMMENDATION.

### Package shape to aim for (long-term target)

```
swift-foundations/
├── swift-user-interface/                       (view DSL, modifiers, composition)
├── swift-user-interface-rendering/             (paint / canvas / hit-test / render-node; sibling L3)
├── swift-html-rendering, swift-pdf-rendering, swift-markdown-html-rendering,
│   swift-css-html-rendering, swift-pdf-html-rendering, swift-svg-rendering
│                                               (existing; migrate imports to Document core when L1 split lands)
└── swift-user-interface-swiftui-interop/       (deferred; SwiftUI-flat naming only here)

swift-primitives/
├── swift-graph-primitives/                     (adds 5 new targets for reactive runtime — not a new package)
├── swift-rendering-primitives/                 (refactored to domain-neutral core)
├── swift-document-rendering-primitives/        (new; depends on rendering-primitives)
└── swift-graphics-rendering-primitives/        (new; depends on rendering-primitives + geometry/affine)
```

### Dependency direction (long-term target)

```
swift-user-interface-swiftui-interop
    → swift-user-interface
    → swift-user-interface-rendering
          → swift-rendering-primitives (core) + swift-graphics-rendering-primitives
            + geometry / affine / transform primitives + swift-color
          → swift-user-interface
    → swift-graph-primitives (structural + reactive targets — same package)
    → swift-layout-primitives / swift-machine-primitives / swift-rendering-primitives (core)
    → swift-property / state / dependency / identity / effect / driver primitives
    → geometry / dimension / space / positioning / transform / affine primitives

swift-{html,pdf,markdown-html,css-html,pdf-html,svg}-rendering
    → swift-rendering-primitives (core) + swift-document-rendering-primitives
```

### Policy consequences

1. **Rendering sibling L3**: already created. Uses a private action
   vocabulary inside its own target until the graphics-rendering L1
   primitive lands.
2. **L1 rendering split is authorized later, not now**: decomposing
   `swift-rendering-primitives` into core / document / graphics siblings
   is the right long-term shape, but requires updating six L3 foundations'
   imports. This research does **not** edit any primitive package.
3. **Attribute-graph is a target-split, not a new package**: five new
   targets in `swift-graph-primitives` when implementation is authorized.
   No package proliferation.
4. **SwiftUI interop**: last package to land, not early scaffolding.
5. **Nest.Name exception**: the one sanctioned violation of Nest.Name
   discipline for compound / flat naming is
   `swift-user-interface-swiftui-interop`. Same policy as Foundation-interop
   adapters elsewhere in the ecosystem.

### Next actions (sequence, none of which edits existing primitive packages yet)

1. **No action required on existing primitive packages.** Current rendering
   and graph primitive packages are untouched.
2. When primitive-layer edits are authorized:
   - Add 5 new targets to `swift-graph-primitives` per
     `swift-user-interface-graph-transactions.md`.
   - Refactor `swift-rendering-primitives` into core + siblings per the
     three-package split above; migrate the six L3 foundation imports.
3. When those two land, fill in `swift-user-interface` and
   `swift-user-interface-rendering`.
4. Consider SwiftUI-interop adapter after (3) stabilizes.

## References

- `danceui-architectural-analysis.md` — parent research
- `swift-user-interface-graph-transactions.md` — attribute-graph L1 decision
- `swift-user-interface-tree-traversal.md` — witness-based tree walk
- `swift-user-interface-primitive-audit.md` — per-primitive coverage table
- `/Users/coen/Developer/bytedance/DanceUI/Modules/DanceUICompose/` — DanceUI's rendering module
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/` — existing document-rendering infrastructure (reusable pattern, document-specific vocabulary)
- `/Users/coen/Developer/swift-foundations/swift-{html,pdf,css-html,markdown-html,pdf-html,svg}-rendering/` — existing consumers of the document-rendering substrate
