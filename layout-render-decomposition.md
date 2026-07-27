# Layout as a Cross-Backend Facet: the `swift-{backend}-layout-render` Decomposition

- **Status:** DECISION (2026-07-08)
- **Layer:** L3 (Foundations)
- **Supersedes framing in:** the in-session "target-not-package" synthesis (shown mis-scoped, §8)
- **Related:** `layout-stack-api-in-pdf-rendering.md` (the L1 `Layout.Stack` canonical-type decision, 2026-03-13); ⚠️ `css-markdown-rendering-decomposition-feasibility.md` §1.3 (2026-03-22, the prior target-extraction ruling) — **THIS DOCUMENT DOES NOT EXIST AND IS NOT RECOVERABLE; see the notice below.**

> ⚠️ **UNSUPPORTED CITATION — recorded 2026-07-24 by the control-plane lane.**
>
> `css-markdown-rendering-decomposition-feasibility.md` is cited above as *"the prior
> target-extraction **ruling**"* — i.e. as a settled decision this document builds on.
> **It has never existed in version control.** Checked three ways: absent from this
> repository's entire history across all revisions and branches; absent from the
> 659-file retirement corpus destroyed on 2026-07-16 (recoverable set indexed at
> `Internal/handoffs/RECOVERY-INDEX-trash-2026-07-16.md`); and untracked in every
> other institute repository.
>
> **This is materially worse than a deleted document.** A deleted one is recoverable
> and the fix is a pointer — that is what the retirement corpus needed. **Evidence
> that never entered version control cannot be recovered by any index**, so the
> ruling cannot be produced, re-read, or checked by anyone.
>
> **Therefore any conclusion in this document that rests on that ruling is
> UNSUPPORTED until re-derived.** The citation is deliberately left in place and not
> repaired: repairing it would make the chain read as settled while the evidence
> remains missing. **Re-derivation or withdrawal belongs to whoever owns the
> layout/render arc.** Not assigned here.
>
> The companion `HANDOFF-package-noun-rename.md`, cited in
> `rendering-primitives-split.md` as the execution plan, is missing the same way —
> and was cited by a bare home-directory path outside every repository.

## Principal rulings (2026-07-08)

1. **Decompose as packages, not targets.** Layout composition is a cross-backend facet; each render backend that carries layout sheds it into a sibling `swift-{backend}-layout-render` package. (Rebuts the "target-not-package" verdict — see §8.)
2. **Q1 — one nil-cost landing.** Nest the containers under `{Backend}.Layout.*` per [API-NAME-001], **and** provide top-level `typealias VStack = HTML.Layout.VStack` (etc.) so existing `VStack { }` call sites keep compiling. This is a principal-authorized exception to the [API-NAME-004a] rename-bridge discouragement, taken deliberately to **avoid source breaks**. The move + nest + aliases land together as one nil-cost change.
3. **Q2 — do not pre-commit the PDF positioning-engine seam.** Wave-2 opens with a coupling-map recon that decides the seam; no pre-commitment.

---

## 0. The one-sentence principle

Layout composition (Stack / Grid / Grid.Lazy / Flow) is **orthogonal to** property-and-element rendering. It is not a per-backend domain; it is a single L1 algebra — `Layout<Scalar, Space>` in `swift-layout-primitives` — **adapted** to each backend's coordinate space. Each base render package sheds its layout facet into a sibling `swift-{backend}-layout-render` that *aliases and conforms* the L1 types rather than re-declaring them, and each base package concurrently collapses to a single concern.

Only **one** type in the entire render family adapts the L1 algebra correctly today: CSS's `LazyVGrid` (routes through `Layout<Length, CSSSpace>.Grid.Lazy.Columns`). PDF's `Stack` adapts it but merged in-package; **everything else hand-rolls** (VStack / HStack / Spacer, PDF.Spacer). The decomposition ends the hand-rolled divergence.

---

## 1. The uniform pattern (stated once)

A `swift-{backend}-layout-render` package is defined by naming, exactly two dependencies, a namespace, and one adapter mechanism.

### Naming
`swift-{backend}-layout-render`, where `{backend}` is the **exact token sequence of that backend's base render package minus the terminal `-render`**. Mechanically: `swift-{backend}-render → swift-{backend}-layout-render` — insert `layout` before `-render`, preserving every backend token in order.

- Module: `"{Backend Tokens} Layout Rendering"` → import token `{Backend_Tokens}_Layout_Rendering`.
- Rationale (composes two [PKG-NAME-016] moves, both reducing to [PKG-NAME-001]'s owner-first mirror): (1) the backend prefix is **inherited** from the base package, not re-derived — the layout package is the layout *facet* of the same backend and must occupy the identical name-path; reordering (`html-css`) desyncs the facet from the base package whose namespace it shares. (2) `layout` is a *decomposition* of the render domain, written larger-then-smaller: render backend first, `layout` before the terminal `-render`. [PKG-NAME-004] keeps the family at L3 with `-render` names (not L1 `-primitives`), so the sibling carries `-render`.
- **This corrects the initially-proposed `swift-html-css-layout-render` to `swift-css-html-layout-render`.**

### Dependencies (exactly two)
1. **`swift-layout-primitives`** (L1, module `Layout_Primitives`) — strictly downward L3→L1, unconditionally legal per [ARCH-LAYER-001]. Today this dep sits in the base package's manifest *only* to serve layout; extraction relocates it here.
2. **The base render package** (L3, e.g. `swift-css-html-render` shorn of layout) — a **lateral L3↔L3** edge, sanctioned by orchestrator disposition per [ARCH-LAYER-012] and matching [MOD-014]'s default bridge form (the live pattern: `swift-html → swift-css → swift-css-html-render` are already L3↔L3 edges).

The base render package **MUST NOT** depend back on the layout package — that re-couples and defeats the shed. The graph stays acyclic because the re-export is wired **above** the base (§4).

### Namespace
`{Backend}.Layout.*` per [API-NAME-001] (Nest.Name): root = the backend module consumers `import`; sub-namespace `Layout` = the cross-backend facet; leaf = the view type. E.g. `HTML.Layout.VStack`, `PDF.Layout.Stack`. Per ruling Q1, a top-level `typealias VStack = HTML.Layout.VStack` (etc.) preserves source-compat.

### The adapter mechanism (from the PDF reference)
Reference: `swift-pdf-render/.../PDF.Stack+PDF.View.swift`. The adapter does **not** declare a struct — it aliases the L1 type and conforms it:

1. `public typealias LayoutRaw = Layout` — sidesteps the name shadow.
2. `extension {Backend} { public typealias Layout = LayoutRaw<Scalar, Space> }` — specializes the L1 generic (PDF: `Double`, `ISO_32000_Shared.UserSpace`).
3. `public typealias Stack<C> = {Backend}.Layout.Stack<C>` — exposes the L1 container verbatim.
4. `extension LayoutRaw<Scalar, Space>.Stack: {Backend}.View where Content: {Backend}.View` — the conformance. Inside the render entry (PDF `_render`; CSS `body`): read the L1 struct's public stored fields (`axis`, `spacing`, `alignment`, `content`), switch on axis, project the non-directional spacing to Width/Height per axis, translate the L1 alignment enum to the backend's representation, recurse into `content`.
5. Backend-ergonomic named factories: `{Backend}.Stack(.vertical/.horizontal, spacing:){builder}` forwarding to the L1 memberwise init.

This **replaces** per-backend hand-rolled layout structs; the adapter reads L1's public fields directly — no re-declaration of `axis`/`spacing`/`alignment`/`content`.

---

## 2. Package topology: which backends get a sibling

Seven L3 render packages exist. **Two** get a live sibling now; one is a **latent name** (no current contents); four have **no layout**.

| Base render package | Sibling? | Sibling name | What moves out |
|---|---|---|---|
| **swift-css-html-render** | **YES (pilot)** | `swift-css-html-layout-render` | `Layout/` types: VStack, HStack, Spacer, LazyVGrid + the `CSSSpace` phantom (currently ad-hoc at `LazyVGrid.swift:17`). |
| **swift-pdf-render** | **YES** | `swift-pdf-layout-render` | The in-package Stack adapter (`PDF.Layout` typealias, the `Layout.Stack: PDF.View` conformance + hand-written `_render` + convenience init) and `ISO_32000.Table`/`Row` (which wrap in `PDF.Stack`). |
| **swift-svg-render** | **LATENT** | `swift-svg-layout-render` | Nothing today (SVG positioning is intrinsic to element coordinate attributes; no Stack/Flow/Grid). Reserve the name; populate only when SVG stack/flow layout is wanted. Do **not** create an empty package ([MOD-RENT]). |
| swift-html-render | NO | — | Already the layout-free HTML base render. Its `Group/_Tuple/_Array/_Conditional` are generic control-flow re-exported from L1 `swift-render-primitives`, not layout. (It *receives* `HTMLForEach` — §5.) |
| swift-markdown-html-render | NO | — | Markdown→HTML renderer; owns no layout. `Markdown.Rendering.Frame` is a caching structure, not a container. |
| swift-pdf-html-render | NO | — | Cross-backend **bridge** (HTML tree → PDF). Consumes `Layout_Primitives` (text-align/line-box/table) but declares no container. `Table.Grid` is a span-occupancy tracker. |
| swift-user-interface-render | NO / N/A | — | Empty stub (only `exports.swift`). Out of the arc. |

### 2a. Pilot — `swift-css-html-layout-render`
- **Deps:** `swift-layout-primitives` (L1) + `swift-css-html-render` (L3 base).
- **Scalar / Space:** `W3C_CSS_Values.Length` (= `CSS_Standard.Length`) / `CSSSpace` (phantom, **owned here** — moved out of `LazyVGrid.swift:17`).
- **Namespace:** `HTML.Layout.{VStack, HStack, Spacer, Grid.Lazy}` (LazyVGrid re-nests to `HTML.Layout.Grid.Lazy` mirroring the L1 `Layout.Grid.Lazy` shape) + top-level `typealias`es for source-compat (Q1).
- **Base after shed:** `swift-css-html-render` becomes a **pure CSS-property renderer** (~1000 one-property-per-file types), single-concern. Its `Grid.swift` is a CSS *property* setter (`HTML.CSS.grid(_:)`), **not** a container — it stays. The `swift-layout-primitives` dep + its transitive primitive fan-in (Column, Buffer.Linear, Hash, Ordered-Dictionary, Ownership.Shared) leaves the base manifest.

### 2b. `swift-pdf-layout-render`
- **Deps:** `swift-layout-primitives` (L1) + `swift-pdf-render` (L3 base). **Scalar / Space:** `Double` / `ISO_32000_Shared.UserSpace`. **Namespace:** `PDF.Layout.Stack`.
- **Stays in base:** leaf primitives `PDF.Spacer`/`Divider`/`Rectangle`, the `PDF.View`/`@PDF.Builder` DSL, `PDF.Context`, `PDF.Document`/`Page`.
- **The real cost (Q2):** `PDF.Stack._render` is tightly coupled to the base's positioning engine (`PDF.Context.Layout`/`Row`/`Inline`/`Spacing`/`Advance`) and to `ISO_32000.Table`/`Row`. The substance is the **untangle**, not the file move — the seam is decided by Wave-2 recon, not pre-committed. PDF currently conforms only Stack; Grid/Grid.Lazy/Flow are unconformed.

---

## 3. The L1 algebra as the shared spine

`Layout<Scalar: ~Copyable, Space>` (`swift-layout-primitives`) is the single canonical algebra — Foundation-free, Embedded-compatible, depends only on `Geometry_Primitives`, with **public** stored fields so adapters read them directly:

- `Layout.Stack<Content>` — axis (`Axis<2>` .primary/.secondary), non-directional `spacing: Spacing`, `alignment: Cross.Alignment`, content. Factories `.vertical`/`.horizontal`; functor `.map.content`.
- `Layout.Grid<Content>` / `Layout.Grid.Lazy` (`columns: .count/.fractions/.autoFill/.autoFit`, each documented with its CSS `grid-template-columns` equivalent) / `Layout.Flow<Content>` (wrapping flexbox).
- Alignment vocabulary: `Alignment`, `Cross.Alignment` (leading/center/trailing/fill), `Horizontal/Vertical.Alignment`, `Direction`, `Axis<2>`.

### Per-backend specialization

| Backend | Scalar | Space |
|---|---|---|
| PDF | `Double` | `ISO_32000_Shared.UserSpace` |
| HTML/CSS | `W3C_CSS_Values.Length` | `CSSSpace` (phantom, owned by the layout package) |
| SVG (latent) | TBD | TBD |

### The VStack/HStack fix (ending the hand-rolled divergence)

Today `VStack`/`HStack`/`Spacer` carry backend-native fields (`VStack: alignment: AlignItems, spacing: CSS_Standard.Length?`; `HStack: alignment: VerticalAlign`) and build `ContentDivision{…}.css.display(.flex).flexDirection(…).rowGap/columnGap` directly, **bypassing `Layout.Stack`** — the defect. The fix conforms the L1 type:

```swift
extension Layout<W3C_CSS_Values.Length, CSSSpace>.Stack: HTML.View where Content: HTML.View {
  var body: some HTML.View {
    switch axis {
    case .secondary: // vertical
      ContentDivision { content }.css.display(.flex).flexDirection(.column)
        .rowGap(spacing.height)      // non-directional spacing → Height
    case .primary:   // horizontal
      ContentDivision { content }.css.display(.flex).flexDirection(.row)
        .columnGap(spacing.width)    // non-directional spacing → Width
    }
    // translate L1 Cross.Alignment (leading/center/trailing/fill) → CSS AlignItems
  }
}
```

`VStack`/`HStack` collapse to named factories over the conformed type (mirroring PDF.Stack); `LazyVGrid` re-nests to the conformed `HTML.Layout.Grid.Lazy` (its `cssGridTemplateColumns` extension moves with it); `Spacer` (`flexGrow(1)`) has no L1 analogue and stays a backend primitive in the layout package. Same mechanism ports to SVG when needed.

---

## 4. Re-export wiring (source-transparency for all consumers)

The layout types surface today because module `CSS` re-exports `CSS_HTML_Rendering`. Insert the new module at the **same node**.

**Live chain (verified):**
```
import HTML → swift-html/Sources/HTML/exports.swift:8  @_exported import CSS
            → swift-css/Sources/CSS/exports.swift:8     @_exported import CSS_HTML_Rendering   ← VStack reachable here today
```

**Exact edits — two files, one package (`swift-css`):**
1. `swift-css/Sources/CSS/exports.swift` — add `@_exported import CSS_HTML_Layout_Rendering` alongside line 8 ([PKG-DEP-003]).
2. `swift-css/Package.swift` — add the dep (`branch: "main"` per [PKG-DEP-001]) and the `.product(name: "CSS HTML Layout Rendering", …)` on the `CSS` target.

**Why `swift-css`, not `swift-css-html-render`:** re-exporting from the base would force it to depend on the layout package — re-coupling it and defeating the shed. The re-export must live **above** the base.

**Resulting acyclic graph:**
```
swift-html → swift-css → { swift-css-html-render, swift-css-html-layout-render }
swift-css-html-layout-render → { swift-css-html-render, swift-layout-primitives }
```

**Migration surface:** `import HTML` consumers (incl. swift-webpage post-transfer) are **nil-cost** — the re-export + top-level typealiases (Q1) keep `VStack { }` compiling with zero edits. Direct `CSS_HTML_Rendering` importers were checked — every site is inside `swift-css`'s own property files; **none** use VStack/HStack/Spacer/LazyVGrid, so there is no external re-point burden.

---

## 5. `HTMLForEach` disposition

`HTMLForEach` is **pure control-flow** (`body = HTML.Builder.buildArray(data.map(content))`) — zero CSS, no `Layout_Primitives` dep, not a layout container. **Do not** fold it into the layout package. Its natural home is `swift-html-render` core, alongside the other generic control-flow primitives re-exported from L1 `swift-render-primitives`. It re-exports transparently either way (nil-cost). Schedule as a small base-package-audit cleanup, independent of the pilot.

## 6. `swift-standards/swift-standards` dead-`Layout` disposition

`swift-standards/swift-standards/Sources/Layout/` holds a full L2 duplicate of the algebra with its own tests. **Re-verified: ZERO external consumers** (only self-test imports); L1 is canonical and settled — not a "which copy is canonical" question. **Disposition:** dead code; leave in place, delete when the deprecated `swift-standards/swift-standards` repo retires. Do **not** extend, consume, or point any sibling at it — all siblings adapt L1 `swift-layout-primitives` exclusively.

---

## 7. Sequencing (wave plan)

Load-bearing invariant every wave: **the re-export + top-level aliases keep consumers green** — no consumer edits.

### Wave 1 — `swift-css-html-layout-render` (pilot; swift-webpage needs it)
1. Create the package (L3), deps `swift-layout-primitives` + `swift-css-html-render`.
2. Move VStack/HStack/Spacer/LazyVGrid + the `CSSSpace` phantom in.
3. Rewrite VStack/HStack/Spacer as the conformed `Layout<Length, CSSSpace>.Stack` + factories (§3); re-seat LazyVGrid as `HTML.Layout.Grid.Lazy`. Nest under `HTML.Layout.*` and add top-level `typealias`es (Q1).
4. Wire the re-export at `swift-css` (§4, two-file edit).
5. Drop `swift-layout-primitives` (+ orphaned primitive fan-in) from `swift-css-html-render`'s manifest; confirm the base builds as a pure CSS-property renderer.
6. Build + test green (6.3.2). **Invariant:** `import HTML` still surfaces `VStack { }`; swift-webpage untouched.

### Wave 2 — `swift-pdf-layout-render` (fix the in-package Stack)
1. **Coupling-map recon first** (Q2) — map `PDF.Context.Layout/Row/Inline/Spacing/Advance` ↔ `Stack._render` before any move; the recon decides the seam.
2. Move the Stack adapter + `ISO_32000.Table`/`Row`; leave leaf primitives in the base; wire the PDF re-export node (above the base, identified during recon).
3. Build + test green. Optional follow-on: conform PDF's Grid/Grid.Lazy/Flow.

### Wave 3 — latent / no-op
- `swift-svg-layout-render`: reserve the name; create only with contents.
- `HTMLForEach → swift-html-render` core (§5): small base-package-audit cleanup.
- Dead L2 `Layout` (§6): no action until the repo retires.

---

## 8. Reconciliation with the prior "target-not-package" verdict

The prior verdict is not wrong about its **rule** — it is **mis-scoped**. It applied [MOD-029] (split decisions weight the *upstream* dep-tree prune) and asked "would the extracted *layout* package's own upstream tree prune?" — answer: no, the adapter intrinsically needs both `swift-layout-primitives` and the base render package. That reasoning is valid for a **domain-split** question. But layout-on-a-backend is **not a domain split**; it is an orthogonal cross-backend **integration facet**, under which the prune is measured on the **SOURCE** side — where it is real and large:

- **[SEM-DEP-009]** (orthogonal integrations → separate packages): bundling layout into `swift-css-html-render` makes `swift-layout-primitives` + its whole primitive fan-in a **non-essential dep** of every consumer who only wants property/element rendering — the violation whose remedy is a separate package.
- **[MOD-014]** (cross-package optional integration): textbook Problem 2; its discriminator is decisive — **only extraction removes the dep from the base manifest** (trait-gating leaves the `.package` edge). [MOD-014] explicitly overrides [MOD-020]'s prefer-target default and grants the [MOD-RENT] integration-package carve-out ("no consumer today / doesn't prune its own tree" does not disqualify an integration bridge — the exact objection the prior verdict raised).
- Reinforced by **[ARCH-LAYER-010]** (optimize strict-mission boundaries early — shed the mission-violator before consumers bind the loose shape) and **[MOD-026]** (a distinct type-family carrying an orthogonal upstream dep graduates to a package).

**The verdict flips to PACKAGE with no contradiction of [MOD-029]:** its split signal (upstream orthogonality) is satisfied; its downstream-count clause is simply inapplicable.

---

## 9. Risks

- **R1 — PDF untangle underestimated.** `Stack._render` is fused to the base positioning engine + `ISO_32000.Table`/`Row`. Mitigation: Wave 2 opens with coupling-map recon (Q2); the file move is last, not first.
- **R2 — PDF re-export node not yet identified.** The swift-css node is verified; the PDF umbrella node that surfaces `PDF.Stack` is located during Wave-2 recon (rule fixed: above the base, never in it).
- **R3 — swift-webpage is mid-transfer.** The re-export guarantees nil-cost *if* it reaches layout via `import HTML` (the live path). Confirm at/after transfer.
- **R4 — Empty latent packages are debt** ([MOD-RENT]). Reserve `swift-svg-layout-render`'s name only; do not create it without contents.

---

## Appendix — Rules cited

[PKG-NAME-016] token order · [PKG-NAME-001] owner-first mirror · [PKG-NAME-004] foundations-cascade (-render not -primitives) · [API-NAME-001] Nest.Name · [API-NAME-004a] discouraged rename bridge (principal-excepted, Q1) · [ARCH-LAYER-001] depend-only-downward · [ARCH-LAYER-012] sibling-L3 lateral disposition · [ARCH-LAYER-010] early strict-mission boundaries · [MOD-014] cross-package optional integration (extract by default) · [SEM-DEP-009] orthogonal → separate package · [MOD-029] upstream-prune domain-split (shown mis-scoped) · [MOD-026] per-type family in multi-type L3 · [MOD-020] prefer-target default (overridden by MOD-014) · [MOD-RENT] integration-package rent carve-out · [PKG-DEP-003] deliberate `@_exported` · [PKG-DEP-001] pre-tag `branch:"main"` dep form.
