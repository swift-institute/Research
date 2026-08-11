# CSS-Cascade Architectural Gap — `<style>` blocks invisible to PDF renderer

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: RECOMMENDATION
---
-->

## Context

Authored during `HANDOFF-swift-pdf-render-parity.md` Phase E (Round 4.3) post-inventory remediation chat. Inventory at [`visual-differences-inventory-2026-05-13.md`](visual-differences-inventory-2026-05-13.md) (commit `91e935a`) listed nine root-cause clusters across factuur-21 visual deltas. CC3 (line-height cascade, S5–S7) was traced to a structural finding that ALSO underpins CC2 (font-size cascade, S1–S4) and CC7-D2 (`<hr>` UA-color default). This doc anchors the architectural reasoning behind the Phase 1 ⇄ Phase 2 staged remediation adjudicated 2026-05-13.

## Empirical finding

Three structurally entangled gaps cause the document-level CSS cascade to be invisible to the institute PDF renderer:

1. **`HTML.__DocumentProtocol._render` drops `<head>`.** `swift-foundations/swift-html-render/Sources/HTML Rendering Core/HTML.Document.Protocol.swift:37-42`:

   ```swift
   public static func _render(_ html: borrowing Self, context: inout Render.Context) {
       context.render(html.body)   // ← html.head dropped
   }
   ```

   The full document structure (`<html><head>…<style>…</style></head><body>…</body>`) is emitted only by `_renderHTMLDocument` (line 47), which HTML output entry points call directly. PDF renders via the generic `_render` path and therefore never visits the head.

2. **Consumer doesn't wrap in `HTML.Document`.** Consumer call site `timekeeping/Sources/Invoices/main.swift:33` passes `invoice` (a `Letter(...) { table { … } }` tree) directly into `PDF.Document(configuration:) { invoice }`. The `_DocumentHead.DocumentStyles()` content (`normalize.css` + `html { line-height: 1.5 }` + `@media` font-size queries) is **structurally absent from the rendered tree**.

3. **`PDF.HTML.Context.register(style:)` is a no-op stub.** `swift-foundations/swift-pdf-html-render/Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:204-212` returns `nil` for any registered CSS declaration. Even if (1) and (2) were fixed, no parsed-CSS-rule storage or matcher exists. The inline `.css.X()` modifier path bypasses this via `apply(inlineStyle:)`; document-level `<style>` blocks have no analogous handler.

The institute `PDF.HTML.Configuration` fields (`defaultFont`, `defaultFontSize`, `lineHeight`, …) function as the PDF path's de-facto UA stylesheet, but they cannot be cascaded over by template-supplied CSS.

## Seven-component architectural analysis

A full evergreen institute cascade-fix decomposes into seven components. The Phase 1 / Phase 2 split below is grounded in this enumeration.

| # | Component | Required for CC3? | Phase |
|---|-----------|-------------------|-------|
| 1 | `_render` override / extension for `HTML.Document` in PDF context — render head before body | Yes | 1 |
| 2 | Runtime CSS parser for `<style>` block string content (tokenize, rules, declarations) | Yes | 1 |
| 3 | Rule storage keyed by selector + at-rule | Yes | 1 |
| 4 | Selector matching at element-push time — **type-selector only** in Phase 1 | Partial (Yes for type-selector; No for class/ID/attribute/pseudo/combinators) | 1 (partial) / 2 (full engine) |
| 5 | Cascade resolution — source order in Phase 1; specificity + `!important` + origin in Phase 2 | Partial (Yes for source order; No for specificity) | 1 (source order) / 2 (specificity) |
| 6 | Inheritance propagation through `~Copyable` style snapshots | No for CC3 (line-height is unconditionally root-applied; descendants inherit by existing style-stack) | 2 |
| 7 | `@media` query evaluation — print/screen classification in Phase 1; viewport-feature eval in Phase 2 | Partial (Phase 1: print-includes vs screen-only vs other) | 1 (basic classification) / 2 (full @media eval) |

## Implication for visual-differences inventory

Three inventory clusters trace to this gap, with distinct dispositions:

- **CC3 (S5–S7 line-height cascade)** — `html { line-height: 1.5 }` from `HTML.Document.document.swift:69` is **outside any `@media`** and unconditionally applies. Institute default `1.2` (commit `e7da3dc`) wins because the rule never reaches the renderer. Phase 1 closes this **structurally**: consumer-side `lineHeight: 1.5` Configuration override would duplicate template-CSS intent (bandaid); institute should read the template's `<style>` block and honor the rule directly.

- **CC2 (S1–S4 font-size cascade)** — `@media only screen and (max-width: 831px) { html { font-size: 14px } }` from `HTML.Document.document.swift:103-107` is **screen-only**. Per CSS Media Queries §2.3, PDF is the `print` media type; `screen` media-type-restricted rules do not apply. Phase 1's print-media-aware @media classification correctly SKIPS this rule. CC2 closure via consumer-side `defaultFontSize: 14` (commit `e724a08`) is **legitimate UA-customization**, not a bandaid — `PDF.HTML.Configuration` IS the institute UA stylesheet for non-CSS-cascade-resolvable defaults. The 2026-05-13 `0039040` revert (institute default reverts to 12pt) is consistent with this framing.

- **CC7-D2 (`<hr>` color)** — institute renders gray per HTML5 §15.3.8 UA default; REF (Quartz) renders black via a UA quirk. WIP is W3C-correct; Phase 1 closure means preserving this correctness (the structural fix does not introduce a regression here).

## Phase 1 — Minimum-viable structural lift (this dispatch)

Closes CC3 structurally. CC2 stays correctly via consumer default per Option-C @media-aware classification. CC7-D2 preserved.

| # | Location | Change | Component |
|---|----------|--------|-----------|
| 1 | `swift-html-render/Sources/HTML Rendering Core/HTML.Document.Protocol.swift:37-42` | `_render` calls `context.render(html.head)` before `context.render(html.body)` | Component 1 |
| 2 | `swift-pdf-html-render/Sources/PDF HTML Rendering/` | (a) `<style>` element scope interception (`text()` buffer); (b) CSS parser; (c) parsed-rule storage; (d) type-selector matching + property → modifier dispatch at `_pushElement`; (e) print-media-aware @media classification | Components 2, 3, 4 (partial), 5 (partial), 7 (partial) |
| 3 | `timekeeping/Sources/Invoices/main.swift` (3 sites) | `PDF.Document(...) { invoice }` → `PDF.Document(...) { HTML.Document.document { invoice } }` | Application |

### Phase 1 selector engine (Component 4 partial)

Supported (parsed and applied):
- Type selector: `html`, `body`, `hr`, `code`, `h1`, etc.
- Type-selector list: `code, pre, tt, kbd, samp { ... }` (comma-separated)
- Universal selector: `*`

Silently parsed and skipped (per CSS Selectors §3.1 "unsupported selector matches nothing"):
- Class selector: `.foo`
- ID selector: `#bar`
- Attribute selector: `[type=button]`
- Pseudo-class: `:hover`
- Pseudo-element: `::before`, `::after`
- Combinators: descendant (space), child (`>`), sibling (`+`, `~`)
- Nesting selector: `&`

### Phase 1 cascade resolution (Component 5 partial)

- **Source order only**: later rules in the parsed stylesheet override earlier rules at the same type-selector. Per CSS Cascade §6.4.4 (cascade-order step 4: order of appearance).
- No specificity calculation. Not needed for type-selector-only matching at root scope.
- No `!important`. Phase 1 silently ignores; Phase 2 introduces.

### Phase 1 @media classification (Component 7 partial)

The orchestrator-adjudicated **Option C** (print-media-aware) shape:

- Extract media-query string after `@media`; classify as one of:
  - `print-includes`: `@media print`, `@media (print)`, or any query that includes `print` in its media-type list — **rules APPLY**.
  - `screen-only`: `@media screen`, `@media only screen and (...)`, or any query restricted to `screen` (and not `print`) — **rules SKIP** (per CSS Media Queries §2.3, PDF is the `print` media type).
  - `all` / unconditional: `@media all`, no `@media` wrapper, or `@media (...)` with no media-type prefix — **rules APPLY**.
  - `other`: media types like `tv`, `speech` — **rules SKIP** (PDF is not these media).
- **Bare media-feature rules** (e.g. `@media (min-width: 832px) { ... }` — no media-type prefix, just a feature): per W3C, default to media-type `all`. **Phase 1 disposition: SKIP** (no viewport ⇒ no match for any feature). Documented; Phase 2 introduces print-equivalent viewport (`max-width: <PDF-page-width-px>`) for feature evaluation.

### Phase 1 deliberate scope limitations (degenerate behaviors, not bandaids)

- Property → modifier coverage = the existing `PDF.HTML.Style.Modifier` registry envelope. A property like `box-sizing` (no current modifier) is silently dropped. Each supported modifier gains a `(propertyName: String, value: String) → modifier` parser; the value grammars are W3C-spec-defined per property (e.g., line-height accepts `<number>`, `<length>`, `<percentage>`, `normal`).
- Cascade against existing institute tag-style defaults (`HTML.Element.Tag+TagStyle.swift`): Phase 1 applies `<style>` rules AFTER tag-style defaults. Where rules overlap (e.g. `h1 { font-size: 2em }` matches institute's existing h1 sizing — no-op; `b, strong { font-weight: bolder }` vs institute's `bold` font selection — should be no-op), need corpus-wide visual diff check (factuur-21 + DemenTree + 100+ invoices) to verify no regression.

## Phase 2 — Deferred (separate dispatch)

Triggered when one of these conditions becomes **load-bearing** (i.e., the inventory or template surfaces a visual regression that ONLY Phase 2 components can resolve):

1. **CSS specificity required**: a template uses a class- or ID-scoped rule whose intent differs from a co-existing type-selector rule (e.g., `h1 { color: black }` AND `.heading-emphasized { color: red }` on the same element), AND the visual deviation traces to incorrect-cascade-order under Phase 1's source-order-only resolution.
2. **`@media` viewport-feature evaluation required**: a template's correct rendering depends on print-viewport-width evaluation (`@media print and (max-width: ...)` or similar). The current invoice corpus does not require this.
3. **CSS inheritance chain required**: a template uses `font-size: inherit`, `color: inherit`, or similar relative declarations that need a computed-style resolution chain through the element tree, not just root-scope application.
4. **`!important` required**: a template uses `!important` to override an inline or higher-specificity declaration, and Phase 1's silent-ignore produces a wrong-rule-wins regression.
5. **Pseudo-element / combinator required**: a template uses `::before`, `::after`, descendant/child combinators with intent the consumer relies on for visual correctness.

Phase 2 scope (estimated):
- Full selector engine: class, ID, attribute, pseudo-class, pseudo-element, descendant/child/sibling combinators
- Specificity calculation per CSS Selectors §16
- Cascade resolution per CSS Cascade §6.4 (source order + specificity + origin + `!important`)
- Inheritance propagation through `~Copyable` style snapshots in `PDF.HTML.Context.Style`
- Full `@media` query evaluator: print-viewport mode (PDF page width → viewport-equivalent px), `@media print` features, `@supports`

## Cross-references

- Parent dispatch: [`tenthijeboonkkamp/timekeeping/HANDOFF-swift-pdf-render-parity.md`](../../../tenthijeboonkkamp/timekeeping/HANDOFF-swift-pdf-render-parity.md) (Rev 7.11 + Round 4.3)
- Inventory: [`visual-differences-inventory-2026-05-13.md`](visual-differences-inventory-2026-05-13.md) (commit `91e935a`)
- Rendering reference: [`coenttb-rendering-reference.md`](coenttb-rendering-reference.md) (Phase D, 5-axis spec)
- Modifier dispatch: [`modifier-dispatch-ordering.md`](modifier-dispatch-ordering.md) (A1/A2 axes — Phase 1 cascade interacts with A1 dispatch ordering)
- Round 4.2.2 `e724a08` precedent (consumer-side font-size override) — reframed as legitimate UA-customization per Phase 1 / Option-C disposition
- CSS specs:
  - [CSS Cascade §6.4 cascade order](https://www.w3.org/TR/css-cascade-5/#cascade-order)
  - [CSS Selectors §3.1 type selectors](https://www.w3.org/TR/selectors-4/#type-selectors)
  - [CSS Selectors §16 specificity](https://www.w3.org/TR/selectors-4/#specificity)
  - [CSS Media Queries §2.3 media types](https://www.w3.org/TR/mediaqueries-5/#media-types)
  - [CSS Syntax §5 parsing](https://www.w3.org/TR/css-syntax-3/#parsing)
  - [HTML5 §15.3.8 UA stylesheet](https://html.spec.whatwg.org/multipage/rendering.html)

## Outcome

**Status**: RECOMMENDATION.

Phase 1 staged structural lift is the orchestrator-adjudicated path (2026-05-13). Rejected alternatives: (a) consumer-side `lineHeight: 1.5` bandaid (duplicates template-CSS intent; rejected as the textbook anti-pattern the user explicitly reverted at `0039040`); (b) full CSS3 cascade compliance in one dispatch (rejected as scope-creep on the inventory time-box; defers CC4 and dispatch termination becomes muddied). Phase 2 awaits a load-bearing trigger from the five enumerated conditions above.
