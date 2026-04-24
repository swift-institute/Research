# Rendering Primitives Split: Core / Markup / Image

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

`swift-rendering-primitives` currently mixes two things in one package:

1. **Domain-neutral tree-walk infrastructure** — `Rendering.View` protocol
   (`~Copyable`, `_render`, `@Builder`), `Rendering.Thunk` (typed witness
   dispatch), `Rendering.Work` (render / action / frame), `Rendering.Machine.Frame`
   (deferred-close scope), `Rendering.Context.render(_:)` (iterative drain
   loop), `Rendering._Tuple<each Content>`, `Rendering.Conditional<First,
   Second>`, `Rendering.Pair`, `Rendering.Group`, `Rendering.Empty`,
   `Rendering.Indirect`, `Rendering.Builder` (result builder),
   `Rendering.Speculative` (snapshot + rollback, e.g. for pagination).
2. **Document-markup Action vocabulary** — `Rendering.Action.{text, image,
   break, attribute, class, raw, style, push, pop}`, `Rendering.Push.{block,
   inline, list, item, link, attributes, element, style}`,
   `Rendering.Pop.{…}`, `Rendering.Break.{line, thematic, page}`,
   `Rendering.Semantic.{Block, Inline, List}`, document-specific fields of
   `Rendering.Context` (setAttribute, addClass, writeRaw, registerStyle,
   applyInlineStyle, spliceActions).

The six consumers at L3 —
`swift-html-rendering`, `swift-pdf-rendering`,
`swift-markdown-html-rendering`, `swift-css-html-rendering`,
`swift-pdf-html-rendering`, `swift-svg-rendering` — all depend on (1) AND
(2). A seventh family of consumers is proposed: UI-pixel rendering for
`swift-user-interface-rendering` (L3), which needs (1) with a **different
Action vocabulary** — graphics / paint commands
(`transform`, `clip`, `fill(path|rect)`, `stroke(path)`, `push.layer`,
`pop.layer`, `hit-test`) rather than document-markup commands.

Vocabulary (2) models **structured bracketed emission** of an SGML-family
tree: HTML, SVG-as-XML, Markdown, PDF content streams (tree-structured
text / block model). A UI-pixel renderer needs a vocabulary whose
semantics are **imperative drawing commands mutating 2D state**
(PostScript imaging model / Cairo / HTML5 Canvas / Skia lineage). The
two vocabularies do not share symbols and their dependency requirements
differ (the UI-pixel vocabulary needs `swift-geometry-primitives`,
`swift-affine-primitives`, `swift-affine-geometry-primitives` — which the
current document-only package does not and should not carry).

**Trigger**: the noun-convention research
(`swift-institute/Research/package-namespace-noun-convention.md`, skill
`swift-package` with `[PKG-NAME-001]`–`[PKG-NAME-006]`) motivates renaming
`swift-rendering-primitives` → `swift-render-primitives` as part of an
ecosystem-wide sweep. The split question must be resolved before the
rename lands so the target shape is clear in one atomic migration.

**Prior research**:
`swift-foundations/Research/danceui-architectural-analysis.md` (DanceUI
has a separate `DanceUICompose` module for paint / canvas / render-nodes
sitting above the view-DSL layer — validates the infrastructure /
vocabulary separation).
`swift-foundations/Research/swift-user-interface-package-decomposition.md`
v1.1 (identifies the three-package L1 split as the long-term shape).

## Question

1. How should `swift-rendering-primitives` be decomposed so that (a)
   existing document-renderer consumers retain their current API surface
   after migration, (b) a new UI-pixel consumer can add a graphics Action
   vocabulary without pulling in document-specific symbols, and (c) the
   domain-neutral infrastructure stays shared?
2. Should the decomposition be **target-split inside one package** or
   **package-split across siblings**?
3. What are the final package + target + namespace shapes?

## Analysis

### What splits cleanly

Domain-neutral (belongs in core):

| Symbol                              | Role                                                   |
|-------------------------------------|--------------------------------------------------------|
| `Render.View` (protocol)             | `~Copyable` view protocol with `_render` + `@Builder`   |
| `Render.Thunk`                      | Typed witness dispatch struct                           |
| `Render.Work`                       | Iterative drain work unit (render / action / frame)    |
| `Render.Machine.Frame`              | Deferred close-scope frame                              |
| `Render.Context` (shell)             | Work stack, `render(_:)` iterative drive, `interpret`   |
| `Render._Tuple<each Content>`       | Variadic typed tuple of views                           |
| `Render.Conditional<First, Second>` | Typed if/else branch                                    |
| `Render.Pair`                       | Two-child composition                                   |
| `Render.Empty`, `Render.Group`      | Container primitives                                    |
| `Render.Indirect`                   | Indirection wrapper                                     |
| `Render.Builder`                    | `@resultBuilder`                                        |
| `Render.Speculative`                | Snapshot + rollback (pagination / line-break fit)       |

Document-specific (belongs in markup sibling):

| Symbol                              | Role                                                   |
|-------------------------------------|--------------------------------------------------------|
| `Render.Action` (enum)               | text, image, break, attribute, class, raw, style, push, pop — **document vocabulary** |
| `Render.Push` (struct-with-closures)  | block, inline, list, item, link, attributes, element, style |
| `Render.Pop`                          | matching pop operations                                 |
| `Render.Break`                        | line, thematic, page                                    |
| `Render.Semantic.{Block, Inline, List}` | Structured-content metadata                           |
| Document-specific `Render.Context` fields | `_setAttribute`, `_addClass`, `_writeRaw`, `_registerStyle`, `_applyInlineStyle`, `_spliceActions`, `text`, `image`, `push`, `pop`, `break`, `interpret(_:)` of document Actions |

Graphics-specific (belongs in image sibling, new):

| Symbol                              | Role                                                   |
|-------------------------------------|--------------------------------------------------------|
| `Render.Action` (enum, sibling namespace) | transform, clip, fill, stroke, image, push.layer, pop.layer, hit-test |
| `Render.Transform` accessor          | concatTransform, pushTransform, popTransform            |
| `Render.Clip` accessor               | pushClip(rect \| path), popClip                         |
| `Render.Paint`                       | paint-source primitive (solid, linear gradient, radial, image) |
| `Render.Path`                         | path construction vocabulary                            |
| `Render.Layer`                        | layer open/close with compositing / opacity             |
| `Render.HitTest`                      | hit-test query primitives                               |
| Graphics-specific `Render.Context` fields | drawing destination, current transform stack, current clip |

### Target-split vs package-split: dependency delta

Package-level deps of current `swift-rendering-primitives`
(`Package.swift` lines 39–41): `swift-property-primitives`,
`swift-ownership-primitives`, `swift-async-primitives`.

| New work                              | New deps beyond current            |
|---------------------------------------|------------------------------------|
| Core (domain-neutral infra)            | none (already present)              |
| Markup vocabulary (extract current)    | none (already present)              |
| Image vocabulary (new)                 | `swift-geometry-primitives`, `swift-affine-primitives`, `swift-affine-geometry-primitives` (≥ 3 new deps) |

Per `modularization` (and per the dependency-delta criterion used for
the attribute-graph decision in
`swift-foundations/Research/swift-user-interface-graph-transactions.md`
v1.1): **if a new concern needs deps the existing package doesn't and
shouldn't carry, a sibling package is justified; otherwise a target-split
is lighter**.

Markup extraction has zero dep delta — a target-split inside the
renamed `swift-render-primitives` would work.

Image extraction has a meaningful dep delta — putting geometry and
affine deps at package level would force document-only consumers
(`swift-html-rendering`, `swift-pdf-rendering`, …) to transitively pull
geometry into contexts where they have no use for it. SwiftPM
technically keeps target-deps contained, but package-level deps still
appear in resolution graphs and in `Package.swift` for all consumers
of the package.

### Two shapes worth comparing

**Shape A — one package with three target families (target-split).**

```
swift-render-primitives
├── Render Primitives Core         (domain-neutral infra)
├── Render Primitives              (umbrella)
├── Render Markup Primitives Core  (document vocabulary)
├── Render Markup Primitives       (umbrella)
├── Render Image Primitives Core   (graphics vocabulary)
└── Render Image Primitives        (umbrella)
```

Package-level deps would include geometry + affine (needed by
`Render Image Primitives Core`), pulled by all consumers even though
the markup-only consumers don't use them. Target-level dep isolation
keeps the module deps clean but the `Package.swift` gets polluted.

**Shape B — three sibling packages (package-split).**

```
swift-render-primitives           (core only; deps: property, ownership, async)
    │
    ├── swift-render-markup-primitives   (deps: swift-render-primitives)
    │
    └── swift-render-image-primitives    (deps: swift-render-primitives,
                                                 geometry, affine, affine-geometry)
```

Each package carries only the deps it needs. Document-only consumers
import two packages (core + markup); UI-pixel consumers import two
packages (core + image); a future mixed consumer imports three.

### Comparison

| Criterion                                      | Shape A (targets in one package) | Shape B (three siblings)         |
|------------------------------------------------|-----------------------------------|-----------------------------------|
| Package count change                            | 0                                 | +2                                |
| Dependency pollution for doc-only consumers     | geometry / affine pulled unused   | none                              |
| Dependency pollution for image-only consumers   | property / ownership / async clean | clean                             |
| Consumer import cost                            | 2 targets (core + markup or core + image) | 2 packages (same) |
| Symmetry with noun-convention research           | partial (one package for renderer family) | full (3 packages match prior analysis) |
| Matches attribute-graph decision                 | N/A (different problem)            | N/A (different problem)            |
| Single-repo evolution                             | yes                               | no (3 repos to bump for coordinated change) |
| SwiftPM resolution graph                          | simpler                           | slightly more entries              |
| Migration cost (6 L3 consumers)                  | one import add (markup)           | one dep add + one import (markup)  |

### The dep-delta criterion applied

Markup extraction = zero dep delta → target-split suffices. Image
extraction = 3 new deps → sibling package justified. But if image goes
into a sibling package and markup stays as a target of core, the
structure becomes asymmetric:

```
swift-render-primitives
├── Render Primitives Core         (infra)
└── Render Markup Primitives Core  (doc vocab)
    (no Render Image target here — Image is a sibling package)

swift-render-image-primitives       (sibling; deps geometry + affine)
```

The asymmetry is defensible — image IS the outlier with extra deps —
but it means a new vocabulary in the future (audio rendering, 3D
rendering, CRDT rendering of a live doc) would need a case-by-case
decision: target-split if no new deps, sibling-split otherwise.

A consistent symmetric shape (Shape B, three siblings) trades a
modest package-count increase for a **simpler invariant**: every
vocabulary is its own package, core is always a dep, mixed consumers
always compose.

### Prior-art consideration

`swift-rendering-primitives` has six established consumers at L3. A
target-split (Shape A) minimises migration cost for them: they add one
import (`import Render_Markup_Primitives`) and move some type
references behind the new namespace. A package-split (Shape B) costs
the same import + a `.package(path:)` entry in `Package.swift`. Both
are one-time migrations.

The UI-pixel consumer is new; it imposes no sunk-cost constraint.

### Namespace shape

Both shapes use the same namespaces (per `swift-package`
`[PKG-NAME-001]` and `[PKG-NAME-002]`):

```swift
public enum Render {
    public protocol `Protocol`<...>: ~Copyable { ... }  // canonical capability (View)
}
public typealias Rendering = Render.`Protocol`

extension Render {
    public enum Markup { /* document-vocabulary types nested here */ }
    public enum Image  { /* graphics-vocabulary types nested here */ }
}
```

So: `Render.Markup.Action`, `Render.Markup.Push`, `Render.Markup.Break`,
`Render.Markup.Semantic.Block` — all noun-form nested under `Render`.
Image side mirrors: `Render.Image.Action`, `Render.Image.Transform`,
`Render.Image.Path`, `Render.Image.Layer`, `Render.Image.HitTest`.
Consumer code reads as domain-qualified even when it imports both.

## Outcome

**Status**: RECOMMENDATION. Research-only; no primitive package is
touched by this document.

**Decision**: adopt **Shape B — three sibling packages**.

Specifically:

1. Rename `swift-rendering-primitives` → `swift-render-primitives`
   per `[PKG-NAME-001]`. Strip the package to **domain-neutral
   infrastructure only** (the Core symbols enumerated above). Package
   deps remain `swift-property-primitives`, `swift-ownership-primitives`,
   `swift-async-primitives`.
2. Create `swift-render-markup-primitives` as a sibling L1 package.
   Migrate document-vocabulary targets out of the renamed core into
   this sibling. Package deps:
   `swift-render-primitives` + whatever minimal doc-support deps the
   vocabulary carries (expected: zero additional).
3. Create `swift-render-image-primitives` as a sibling L1 package.
   Author the graphics Action vocabulary from scratch (no existing
   code to migrate). Package deps: `swift-render-primitives`,
   `swift-geometry-primitives`, `swift-affine-primitives`,
   `swift-affine-geometry-primitives`.
4. Migrate the six L3 document-renderer foundations to import
   `Render_Markup_Primitives` alongside the renamed core. One-time sweep,
   single atomic commit per
   `swift-institute/Skills/swift-package/SKILL.md` and
   `HANDOFF-package-noun-rename.md`.

**Rationale for Shape B over Shape A**:

- Clean invariant: "every vocabulary is a sibling package on top of
  the core." Future vocabularies (audio, 3D, CRDT-live) follow the same
  rule mechanically; no per-vocabulary re-litigation of target-vs-package.
- Zero dep pollution for document-only consumers. The six existing
  foundations stay as clean as they are today after the rename.
- Symmetric namespace shape (`Render.Markup.*` + `Render.Image.*`)
  with independent evolution cadences per package.
- Migration cost is already being paid (the rename is happening
  regardless); the added cost of splitting vs bulk-renaming is
  minimal — one new `.package(path:)` entry per consumer.

**Why not Shape A**:

- Package-level dep on geometry + affine would be carried by every
  consumer of `swift-render-primitives`, including document-only
  renderers, for no benefit. SwiftPM's resolution graph gets noisier.
- The asymmetric variant (target-split for markup but sibling-split
  for image) is honest but sets no mechanical rule for future
  vocabularies. Each new vocabulary would require the dep-delta
  decision again — work avoided by choosing Shape B once.

### Execution sequencing

The split is authorized in aggregate; it executes as part of Phase 1
of `HANDOFF-package-noun-rename.md` (the atomic rename + split of
`swift-rendering-primitives`). This research doc is the design
reference for the Phase 1 commit.

Order of operations within Phase 1 (to keep the repo compilable):

1. Rename `swift-rendering-primitives/` → `swift-render-primitives/`,
   Swift namespace `Rendering` → `Render`, targets + products renamed,
   gerund typealias added.
2. In the same change, create `swift-render-markup-primitives/` with
   document-vocabulary sources moved out of the renamed core into
   `Render.Markup.*` namespace.
3. In the same change, create `swift-render-image-primitives/` as a
   minimal skeleton (namespace enum `Render.Image`, empty umbrella
   target, deps declared). Actual graphics vocabulary is future work.
4. In the same change, update all six L3 renderer foundations to
   depend on `swift-render-primitives` + `swift-render-markup-primitives`
   and update `import` statements from
   `Rendering_Primitives_Core` to `Render_Primitives_Core` and add
   `import Render_Markup_Primitives` where document vocabulary is used.
5. Regenerate `swift-primitives/Package.swift` via
   `Scripts/generate-package-swift.py`.
6. Build + test everything.
7. Commit.

### What is NOT decided by this doc

- The shape of `Render.Image.Action` / `Render.Image.Push.layer` /
  `Render.Image.Paint` / etc. — that's vocabulary design, deferred
  until a concrete consumer (`swift-user-interface-rendering`) drives
  the requirements.
- Whether a future `Render.Markup` sub-specialisation (XML, Markdown,
  HTML5 subsets) deserves its own sibling package. Defer until a
  second markup-flavour vocabulary emerges with conflicting
  vocabulary needs.
- Placement of `swift-render-primitives` in tier ordering — currently
  at its established tier; no relocation proposed.

## References

- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Sources/Rendering Primitives Core/` — existing infrastructure + document vocabulary (to be split)
- `/Users/coen/Developer/swift-primitives/swift-rendering-primitives/Package.swift` — current deps
- `swift-foundations/Research/danceui-architectural-analysis.md` — DanceUI's own DanceUI/DanceUICompose split (validates infra-vs-vocabulary separation)
- `swift-foundations/Research/swift-user-interface-package-decomposition.md` v1.1 — upstream decomposition research
- `swift-foundations/Research/swift-user-interface-graph-transactions.md` v1.1 — dependency-delta criterion in action
- `swift-institute/Research/package-namespace-noun-convention.md` — convention research
- `swift-institute/Skills/swift-package/SKILL.md` — `[PKG-NAME-001]`–`[PKG-NAME-006]`
- `/Users/coen/Developer/HANDOFF-package-noun-rename.md` — execution plan (Phase 1 is this split)
- [PostScript Language Reference Manual, Adobe 1985, Ch. 4 "Imaging Model"] — prior art for the Image vocabulary
- [Porter & Duff 1984, "Compositing Digital Images"] — compositing algebra
- [ISO 8879:1986 SGML] — tree-bracketed markup vocabulary ancestry
