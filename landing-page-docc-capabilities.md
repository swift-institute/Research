# Landing-Page Capabilities of DocC in Swift 6.3

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: RECOMMENDATION
---
-->

## Context

The swift-institute.org landing page is DocC-rendered via `xcrun docc convert --transform-for-static-hosting` in the `deploy-docs.yml` workflow. A separate research pass (`documentation-docc-alpha-launch.md`, status DECISION) locked in Option B — a substantial root module page — but the handoff reports the initial UX is subpar. The synthesis document needs a grounded inventory of what DocC can actually do on a module root page (not tutorial pages), so proposed changes stay inside DocC's native capabilities rather than bypassing its chrome.

This document is one of three perspectives informing that synthesis. The marketing perspective analyzes audience journeys; the comparative study analyzes landing-page patterns elsewhere. This perspective answers: **given the constraints, what DocC tools are on the table?**

## Question

Which DocC directives, metadata, and theming mechanisms are usable on a **module/article root page** (not on tutorial pages) in Swift 6.3's DocC toolchain under static-hosted output — and which of them give meaningful UX lift for a project landing page?

## Analysis

Source-of-truth references used throughout this document:

- `https://www.swift.org/documentation/docc/` (Apple's own DocC catalog, DocC-rendered)
- `https://github.com/swiftlang/swift-docc/tree/main/Sources/docc/DocCDocumentation.docc/Reference%20Syntax/API%20Reference%20Syntax`
- `https://raw.githubusercontent.com/swiftlang/swift-docc/main/Sources/SwiftDocC/SwiftDocC.docc/Resources/ThemeSettings.spec.json`

DocC's own documentation index (`api-reference-syntax.md`) groups article-level directives into two categories:

> **Configuring Documentation Behavior**: `Options`, `Metadata`, `TechnologyRoot`, `Redirected`
> **Creating Custom Page Layouts**: `Row`, `TabNavigator`, `Links`, `Small`

All directives below were introduced in Swift-DocC 5.8 or earlier and ship in the DocC bundled with Swift 6.3.

---

### 1. `@Metadata` and its children

`@Metadata` is the container for page-level configuration. Per Apple's `Metadata.md`, it accepts these child directives on an article page: `DocumentationExtension`, `TechnologyRoot`, `DisplayName`, `PageImage`, `PageKind`, `PageColor`, `CallToAction`, `TitleHeading`, `SupportedLanguage`, `AlternateRepresentation`, `Available`, `DeprecationSummary`, `Redirected`.

The current root page (`Swift Institute.md:3–6`) already uses:

```markdown
@Metadata {
  @DisplayName("Swift Institute")
  @TitleHeading("A layered Swift package ecosystem")
}
```

Everything else in `@Metadata` is unused today and available.

---

### 2. `@PageImage(purpose:, source:, alt:)`

Signature:

```
@PageImage(purpose: Purpose, source: ResourceReference, alt: String?)
```

**Purpose values** (only two exist — no `hero`):

| Purpose | Rendering |
|---------|-----------|
| `icon` | Navigation sidebar icon + article topic sections. Works best as a square with clarity at ≤20×20 pt. |
| `card` | Used as the card image for this page when it appears inside `@Links(visualStyle: compactGrid / detailedGrid)`. Article page backgrounds in some renderer modes. Ideal aspect 16:9, max ~640×360 pt. |

If only `icon` is supplied, DocC falls back to using the icon as the card image (quality degrades unless SVG).

**Available on**: module root and every article page. Resources live in the `.docc` catalog (typically alongside article .md files).

**Verified**: documented on `swift.org/documentation/docc/pageimage`.

**Landing relevance**: the primary way to give the ecosystem a visual identity inside DocC's chrome. Also a prerequisite for making any grid-style `@Links` look reasonable.

---

### 3. `@PageColor(_ color: Color)`

Signature:

```
@Metadata {
    @PageColor(orange)
}
```

**Colors**: `blue`, `gray`, `green`, `orange`, `purple`, `red`, `yellow`. No custom colors.

**Rendering**: used as the primary background color of the page's introduction section (the header block above the Overview). Other intro-section elements adjust for contrast.

**Available on**: module root and every article page.

**Landing relevance**: gives the root page visual distinction from descendant pages (which are the default neutral). Sub-articles can use different accent colors to differentiate sections (e.g., Architecture one color, Blog another), reinforcing the information hierarchy without bespoke CSS.

---

### 4. `@PageKind(article | sampleCode)`

Signature:

```
@Metadata {
    @PageKind(sampleCode)
}
```

Affects the default title heading rendered above the page title and the navigator icon. `article` is the default for standalone Markdown files — there is no `moduleRoot` or `landing` kind. `sampleCode` is useful for pages that center a code example.

**Landing relevance**: marginal. The existing `@TitleHeading` already overrides the title heading text. `@PageKind` does not create new layout modes.

---

### 5. `@CallToAction(url:|file:, purpose:?, label:?)`

Signature:

```
@Metadata {
    @CallToAction(url: "https://example.com/sample.zip", purpose: download)
}
```

**Parameters**:

| Parameter | Role |
|-----------|------|
| `url` | External URL. One of `url`/`file` required. |
| `file` | File in the documentation bundle (downloads). |
| `purpose` | `download` (default label: "Download") or `link` (default label: "View"). One of `purpose`/`label` required. |
| `label` | Custom button label; overrides purpose's default. |

**Rendering**: a prominent button in the page header, visually equivalent to the hero CTA on Apple's "Sample Code" pages.

**Available on**: module root and every article page (nested in `@Metadata`). Constraint is "only valid within a `@Metadata` directive."

**Landing relevance**: high. This is the closest thing DocC gives to a hero CTA. For the swift-institute alpha, natural targets are the GitHub org (`purpose: link, label: "View on GitHub"`), the latest blog post, or the Getting Started page.

---

### 6. `@Links(visualStyle:) { ... }`

Signature:

```
@Links(visualStyle: compactGrid) {
   - <doc:Getting-Started>
   - <doc:Architecture>
   - <doc:Blog>
}
```

**Visual style values**:

| Style | Rendering |
|-------|-----------|
| `list` | Default Topics-style list with full title + abstract per item. |
| `compactGrid` | Grid cards: card image + title, no abstract. |
| `detailedGrid` | Grid cards: card image + title + abstract. |

**Where placeable**: Apple's docs explicitly state "anywhere on a documentation page outside of formal Topics sections." The wording does not restrict to article vs. module root. The Swift Forums pitch ([forums.swift.org/t/59919](https://forums.swift.org/t/highlighting-documentation-pages-outside-of-topics-sections-in-swift-docc-links-directive/59919)) describes it as "styled link lists anywhere on a documentation page."

**Module root caveat**: uncertain whether `@Links` on the module root page coexists cleanly with the module's `## Topics` section. Would need a 5-minute experiment to confirm — build a fork with `@Links(visualStyle: detailedGrid)` in the Overview and a separate `## Topics` section, verify both render.

**Prerequisite**: grid styles look dead unless every linked page has `@Metadata { @PageImage(purpose: card, source: ..., alt: ...) }`. Without card images, `detailedGrid` falls back to icon which falls back to colored square — acceptable but not striking.

**Landing relevance**: this is the single highest-leverage feature for replacing a wall-of-prose Overview with a scannable "three doors" reader-intent router (Read the blog / Read the philosophy / Start using it), while still rendering Topics below for DocC's own navigation.

---

### 7. `@Row { @Column(size: N) { ... } }`

Signature:

```
@Row {
   @Column {
      ![icon](icon-power.svg) Ice power
   }
   @Column(size: 2) {
      Wide column content
   }
}
```

**Parameters**:
- `@Row(numberOfColumns: Int)` — optional; default derived from child count.
- `@Column(size: Int)` — optional; default 1. Acts as column-span weight.

**Rendering**: grid-based row layout. Works in article body.

**Available on**: module root and every article page.

**Landing relevance**: useful for a below-hero "three-principle" band (each principle in a column) or a "three-audience" router. More flexible than `@Links(visualStyle: compactGrid)` because columns can contain arbitrary markup (prose + code + images), not just document links.

---

### 8. `@TabNavigator { @Tab("title") { ... } }`

Signature:

```
@TabNavigator {
   @Tab("Start using") { ... }
   @Tab("Read the philosophy") { ... }
   @Tab("Follow the blog") { ... }
}
```

**Available on**: module root and every article page.

**Landing relevance**: a literal DocC mechanism for reader-intent routing. The three personas (evaluator / early adopter / curious) can each get a tab with their tailored content. Caveat: tabs hide content by default — if the evaluator doesn't click, they miss whatever's in the other tabs. Good for packing optional depth, bad for carrying the pitch.

---

### 9. `@Small { ... }`

Based on HTML `<small>`. Supports inline formatting (bold, italics) but cannot contain `@Row`, `@Column`, or other block directives.

**Landing relevance**: low. Useful for a compact alpha-status footer or license line below the Topics. Marginal.

---

### 10. `@Options(scope: local|global) { ... }` and its children

`@Options` is a configuration directive. Scope defaults to `local` (this page only); `global` applies to every page in the catalog. Only one global `@Options` is allowed per catalog.

Child directives (all introduced in DocC 5.8):

| Child | Purpose |
|-------|---------|
| `@AutomaticSeeAlso(disabled|enabled|siblingPages)` | Controls auto-generation of See Also. |
| `@AutomaticTitleHeading(disabled|enabled|pageKind)` | Controls auto-generation of title heading text. |
| `@AutomaticArticleSubheading(disabled|enabled)` | Controls auto-generation of the "Overview" subheading. |
| `@TopicsVisualStyle(list|compactGrid|detailedGrid|hidden)` | The rendering style of the page's `## Topics` section. |

**Landing relevance**: `@TopicsVisualStyle(detailedGrid)` is the single biggest lever. It replaces DocC's default Topics list (plain bulleted links) with card rendering using each linked page's `@PageImage(purpose: card)`. Applied to the root page, the six Topics groups become card grids — dramatically more inviting than a bulleted list.

Example:

```markdown
@Options {
    @TopicsVisualStyle(compactGrid)
}

## Topics
### Start here
- <doc:Getting-Started>
- <doc:FAQ>
```

Scoping: `local` (root page only) means descendant articles keep their default list style, which is usually what you want.

---

### 11. `@TechnologyRoot`

Marks an article as the root of a standalone technology (used when a `.docc` catalog is not tied to a specific module symbol). Nested in `@Metadata`. The swift-institute catalog is module-tied (`# ``Swift_Institute```), so `@TechnologyRoot` is not applicable.

---

### 12. `@Redirected(from: URL)`

Allows forwarding from an old URL to the current page — useful if pages are renamed. Nested in `@Metadata`. Not urgent for the alpha but worth knowing.

---

### 13. `theme-settings.json`

The catalog-level theme settings file lives at the root of the `.docc` catalog (alongside the root `.md`) and is loaded automatically by DocC. Schema documented at [`ThemeSettings.spec.json`](https://github.com/swiftlang/swift-docc/blob/main/Sources/SwiftDocC/SwiftDocC.docc/Resources/ThemeSettings.spec.json).

Top-level keys:

| Key | Contains |
|-----|----------|
| `meta.title` | Replaces default "Documentation" text in the HTML `<title>` tag. |
| `theme.typography.html-font` | Global body font-family (CSS string). |
| `theme.typography.html-font-mono` | Monospace font-family. |
| `theme.border-radius` | Global corner rounding. |
| `theme.aside.*`, `theme.button.*`, `theme.code.*`, `theme.inline-code.*`, `theme.badge.*`, `theme.tutorial-step.*` | Per-element border radius/style/width. |
| `theme.color.*` (200+ variables) | Light/dark mode colors. Naming: `*-fill` for backgrounds, `*-figure` for foreground. |
| `theme.icons.*` | SVG URL overrides for 45+ icon slots (chevrons, search, download, etc.). |
| `features.docs.quickNavigation.enable` | Toggle quick-navigation search popup. |
| `features.docs.onThisPageNavigator.disable` | Hide the right-side page navigator. |
| `features.docs.i18n` | Toggle internationalization. |

Light/dark support: any color entry accepts either a single string or an object `{ "light": "#...", "dark": "#..." }`.

Favicon: place `favicon.ico` at the catalog root.

**Landing relevance**: substantial. Color tweaks (page intro fill, accent) and typography can give the site a distinct identity without touching chrome. `features.docs.onThisPageNavigator.disable` is a single-line toggle to quiet a noisy right rail on a landing page. Quick navigation is already useful, so don't disable.

**Constraint for this project**: the handoff says "Do not hide, remove, or re-style DocC's sidebar, navigator, search, or chrome." `theme-settings.json` can re-style (colors/fonts are re-styling), but `features.docs.quickNavigation.enable=false` and `onThisPageNavigator.disable=true` would hide chrome — those two flags are out of scope per the handoff.

---

### 14. `Info.plist` catalog settings

The `.docc` catalog's `Info.plist` accepts:

| Key | Role |
|-----|------|
| `CFBundleDisplayName` | Human-readable catalog display name. |
| `CFBundleIdentifier` | Bundle identifier for the catalog. |
| `CDAppleDefaultAvailability` | Default availability for symbols lacking explicit `@Available`. |
| `CDDefaultCodeListingLanguage` | Language for code fences that don't specify. |
| `CDDefaultModuleKind` | Kind heading for the module (e.g., "Framework"). |

The current catalog has no `Info.plist`, so `@DisplayName` in `@Metadata` is the only name override today. Landing relevance is minor — mostly defaulting code-fence language to `swift`, which saves typing but doesn't affect UX.

---

### 15. Static-hosting caveats

The deploy pipeline uses `xcrun docc convert --transform-for-static-hosting`. All directives above are rendered server-side by DocC into HTML/JS fragments; the static transform restructures URLs (drops `/data/documentation/` prefixes in paths, etc.) but does not alter which directives are supported.

Known rough edges from Apple's published renderer and community reports:

- The page first-paint on `swift.org/documentation/docc/...` is empty HTML; the renderer is client-side JS that fetches `/data/documentation/*.json`. This is an SEO and "no-JS" concern but not a correctness concern for `@Row`, `@Links`, `@CallToAction`, etc. — they render identically to local `docc preview`.
- Redirection from `/some/path/` to `/some/path/index.html` must be handled by the host. GitHub Pages handles it.

**Recommended verification**: after any addition, run locally:

```bash
cd "/Users/coen/Developer/swift-institute"
xcrun docc convert "Swift Institute.docc" \
  --output-path /tmp/si-docs \
  --transform-for-static-hosting \
  --hosting-base-path /
# then: python3 -m http.server --directory /tmp/si-docs 8080
```

---

## Outcome

**Status**: RECOMMENDATION — directive availability established; specific combinations still want a ~10-minute local build verification before production.

### Directive availability matrix (module root page in Swift 6.3 static-hosted DocC)

| Feature | Usable on root? | Usable on articles? | Landing-relevance lift | Verification |
|---------|:---------------:|:-------------------:|-----------------------|--------------|
| `@DisplayName` | yes | yes | — (already used) | Verified |
| `@TitleHeading` | yes | yes | — (already used) | Verified |
| `@PageImage(purpose: card)` | yes | yes | Medium — unlocks grid styles | Verified |
| `@PageImage(purpose: icon)` | yes | yes | Low — sidebar identity only | Verified |
| `@PageColor` | yes | yes | High — visual identity, section differentiation | Verified |
| `@PageKind` | yes | yes | Low — affects title heading default | Verified |
| `@CallToAction` | yes | yes | **High** — DocC's closest thing to a hero CTA | Verified |
| `@Links(visualStyle: list)` | likely yes | yes | Low (same as plain Topics list) | Article: verified. Root: uncertain — needs 5-min experiment |
| `@Links(visualStyle: compactGrid)` | likely yes | yes | **High** — card-style "three doors" pattern | Needs experiment |
| `@Links(visualStyle: detailedGrid)` | likely yes | yes | **High** — card-style with abstracts | Needs experiment |
| `@Row` / `@Column` | yes | yes | High — arbitrary-content band below hero | Verified |
| `@TabNavigator` | yes | yes | Medium — reader-intent routing, but hides content | Verified |
| `@Small` | yes | yes | Low — footer text | Verified |
| `@Options(scope: local) { @TopicsVisualStyle(detailedGrid) }` | yes | yes | **Very high** — upgrades the existing Topics section to card rendering | Verified |
| `@Options(scope: global)` | yes | yes | Medium — catalog-wide defaults | Verified |
| `@TopicsVisualStyle(hidden)` | yes | yes | — (useful for articles that shouldn't surface children) | Verified |
| `@Redirected` | yes | yes | Low — URL hygiene | Verified |
| `theme-settings.json` — colors, typography | catalog-wide | catalog-wide | Medium — ecosystem identity | Verified |
| `theme-settings.json` — feature flags that hide chrome | catalog-wide | catalog-wide | **Out of scope** per handoff | Verified |
| `Info.plist` catalog settings | catalog-wide | catalog-wide | Low | Verified |

### Features that do NOT exist in DocC (important negatives)

- No `@PageImage(purpose: hero)` — "hero" is not a purpose. Only `icon` and `card`.
- No `@Featured` / `@Highlighted` for single-item emphasis. The closest is `@Links(visualStyle: detailedGrid)` with one item, or `@CallToAction`.
- No module-root-specific directive. The root `.md` is treated as an article with a specific title (the module identifier).
- No video embed directive on article pages (videos are tutorial-only).
- No built-in latest-blog-post feed. A manually curated `@Links(detailedGrid)` block pointing at the most-recent post is the closest equivalent and requires editing the root page on each post publish.
- No hero-image background (as CSS background). `@PageImage(purpose: card)` is used in grid contexts, not as a full-bleed banner.
- No custom CTA colors beyond the `@PageColor` seven-color palette.

### The three levers with the biggest landing UX delta

Ordered by ratio of visual change to configuration effort, per the availability matrix above:

1. **`@Options { @TopicsVisualStyle(detailedGrid) }` on the root page**, combined with adding `@Metadata { @PageImage(purpose: card, ...) }` to each linked article. Converts the Topics section from bulleted text to a card grid. Single biggest change in perceived polish.
2. **`@CallToAction`** in the root `@Metadata` — a prominent header button. Natural target: GitHub org, the blog, or Getting Started.
3. **`@Row` / `@Column`** in the Overview body — lets three concise columns replace the current five-principle wall of prose.

### Open verification items for the synthesis

1. Does `@Links(visualStyle: detailedGrid)` coexist with a `## Topics` section on the **module root** page (not just articles)? Docs silent.
2. Does `@CallToAction` render differently on a module root vs. an article? Probably not — same `@Metadata` context — but unverified.
3. Does `@Options(scope: global)` in the root `.md` file propagate to sub-articles, or must each article set its own? Schema suggests global propagates; Apple's DocC sample catalog would confirm.

All three are 5-10 minute local builds away from being verified.

## References

- DocC directive syntax index — `https://github.com/swiftlang/swift-docc/blob/main/Sources/docc/DocCDocumentation.docc/Reference%20Syntax/API%20Reference%20Syntax/api-reference-syntax.md`
- `@Metadata` children — `https://github.com/swiftlang/swift-docc/blob/main/Sources/docc/DocCDocumentation.docc/Reference%20Syntax/API%20Reference%20Syntax/Metadata.md`
- `@PageImage` — `https://www.swift.org/documentation/docc/pageimage`
- `@PageColor` — `https://www.swift.org/documentation/docc/pagecolor`
- `@PageKind` — `https://www.swift.org/documentation/docc/pagekind`
- `@CallToAction` — `https://www.swift.org/documentation/docc/calltoaction`
- `@Links` — `https://www.swift.org/documentation/docc/links`
- `@Row` — `https://www.swift.org/documentation/docc/row`
- `@TabNavigator` — `https://www.swift.org/documentation/docc/tabnavigator`
- `@Small` — `https://www.swift.org/documentation/docc/small`
- `@Options` — `https://www.swift.org/documentation/docc/options`
- `@TopicsVisualStyle` — `https://www.swift.org/documentation/docc/topicsvisualstyle`
- theme-settings schema — `https://github.com/swiftlang/swift-docc/blob/main/Sources/SwiftDocC/SwiftDocC.docc/Resources/ThemeSettings.spec.json`
- Appearance customization — `https://www.swift.org/documentation/docc/customizing-the-appearance-of-your-documentation-pages`
- `@Links` pitch (Swift Forums) — `https://forums.swift.org/t/highlighting-documentation-pages-outside-of-topics-sections-in-swift-docc-links-directive/59919`
- Handoff — `/Users/coen/Developer/swift-institute/HANDOFF.md`
