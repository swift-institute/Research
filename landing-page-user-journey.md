# Landing-Page User Journey for the swift-institute.org Alpha

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: RECOMMENDATION
---
-->

## Context

The public alpha site at `swift-institute.org` is live and DocC-rendered. A prior pass (`documentation-docc-alpha-launch.md`, status DECISION) established the content scope and alpha-conservative voice, but `HANDOFF.md` records that the resulting root page reads as API documentation rather than a project landing: reader-intent routing is weak, the blog — named as the alpha's primary purpose — is buried at the bottom of Topics, and the five-principles block carries too much weight above the fold.

This synthesis document consolidates three parallel research perspectives, all in `/Users/coen/Developer/swift-institute/Research/`:

| Perspective | File | Focus |
|-------------|------|-------|
| Marketing | `landing-page-marketing-perspective.md` | Audiences, 15-sec hook, 5-min path, copy diagnosis |
| Technical | `landing-page-docc-capabilities.md` | DocC 6.3 directive availability on module/article pages |
| Comparative | `landing-page-comparative-study.md` | 14 comparator sites, Apple DocC-on-DocC precedent |

Each was written without seeing the others. Where they converge is treated as high-confidence; where they diverge is flagged as a decision point.

The voice lock from the prior decision is preserved throughout: no exact package counts, no commercial-license commitments, no domain enumerations, no stewardship framing.

## Question

Within DocC's native capabilities in Swift 6.3, how should the root page at `Swift Institute.docc/Swift Institute.md` be restructured so that it serves the three plausible audiences on their actual time budgets — and, specifically, elevates the blog from its current sixth-of-six position to first-class standing consistent with the handoff's framing of the blog as the alpha's primary purpose?

## Analysis

### Points of convergence across all three perspectives

Where two or three of the three perspectives independently arrive at the same finding:

| Finding | Marketing | Comparative | Technical |
|---------|:---------:|:-----------:|:---------:|
| The current abstract (line 8) reads as generic infrastructure marketing and fails the evaluator's 15-second test. | ✓ | ✓ | n/a |
| Apple's DocC-on-DocC does NOT use inline code in the Overview. The current root embeds four code samples inside Overview prose, pulling toward a marketing-homepage style. | ✓ | ✓ | n/a |
| Blog placement (sixth of six Topics groups) directly contradicts the "blog is primary purpose" framing. | ✓ | ✓ | n/a |
| SwiftUI's "Featured samples" detailedGrid ABOVE Topics is the native DocC precedent for elevating a class of content. This is `@Links(visualStyle: .detailedGrid)` + `@PageImage(purpose: card)` on each linked page. | ✓ | ✓ | ✓ |
| The Topics section itself can be upgraded from bulleted text to card rendering via `@Options { @TopicsVisualStyle(.detailedGrid) }` on the root — requires `@PageImage(purpose: card)` on each linked article. | (implicit) | ✓ | ✓ |
| `@CallToAction` in root `@Metadata` is the DocC-native answer to the hero-CTA pattern used by Vapor, Hummingbird, Next.js, Astro. | (implicit) | ✓ | ✓ |
| Five principles inline on the root over-serves intent 2 (philosophy) and starves intents 1 (latest) and 3 (try it). The "Dead Ends" note in the handoff already flagged this — the issue has not been fixed. | ✓ | ✓ | n/a |
| Topics groups should be reorganized by reader goal, not by architecture category. DocC-on-DocC uses reader-goal grouping uniformly; the current root mixes "Start here" (reader-goal) with "Layers" (architecture-categorical). | ✓ | ✓ | n/a |

### Points of divergence or open questions

| Open question | Source | Required resolution |
|---------------|--------|---------------------|
| Principles: hybrid (keep one as hero, move rest to article) vs. replace entirely with a blog-featured surface. | Marketing prefers either (c) or (d); comparative observations lean toward (c) because Apple landings don't emphasise principles. | User decision. |
| Hero sentence: replace entirely, or keep the current abstract and reinforce with a separate action sentence? | Marketing recommends replacing line 8; voice lock constrains specific wording. | User decision on wording. |
| `@Links(visualStyle: .detailedGrid)` and `@Options { @TopicsVisualStyle(.detailedGrid) }` usage on a module root page (not just descendant articles) is documented but not unambiguously confirmed for root-page-specific behaviour. | Technical perspective. | A ~10-minute local `xcrun docc convert --transform-for-static-hosting` build will confirm before production deploy. |
| Alpha admonition: keep above the fold (current position, line 10) vs. move below the Overview. | Marketing notes the admonition primes distrust before the pitch lands. | User decision. |

### Proposed landing-page shape, structured end-to-end

The shape below is the composite recommendation. Each numbered block is one **decision** the user approves, modifies, or rejects per the handoff's Next Steps step 3. Nothing is implemented until the user signs off.

Within-DocC delivery is the binding constraint: every block below uses a documented DocC directive or a prose/code pattern that fits inside the article body without touching chrome.

```
┌─────────────────────────────────────────────────────────────────┐
│ DocC top chrome: sidebar + nav + breadcrumbs + search           │ (unchanged)
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  # Swift Institute                                              │ ① @DisplayName (unchanged)
│  A layered Swift package ecosystem                              │    @TitleHeading (unchanged)
│                                                                 │
│  [sharper one-sentence abstract — concrete verb]                │ ② Replace line 8
│                                                                 │
│  [optional: @CallToAction button — View on GitHub / Read Blog]  │ ③ Add CTA
│                                                                 │
│  [optional: @PageImage(purpose: card) hero]                     │ ④ Add hero image (deferred)
│                                                                 │
│  ## Overview                                                    │
│                                                                 │
│  [one hero principle — the Tagged/phantom-type example]         │ ⑤ Keep ONE principle inline
│                                                                 │
│  ## Latest writing                                              │ ⑥ Surface blog above Topics
│                                                                 │
│  @Links(visualStyle: .detailedGrid) {                           │
│      - <doc:Blog/Restarting-the-Blog>                           │
│  }                                                              │
│                                                                 │
│  ## Topics                                                      │ ⑦ Reorganised, goal-based,
│                                                                 │    rendered as card grid via
│  @Options { @TopicsVisualStyle(.detailedGrid) }                 │    @TopicsVisualStyle
│                                                                 │
│  ### Start reading  (Blog + Restarting the Blog post)           │
│  ### Start building (Getting Started + FAQ)                     │
│  ### Understand the design (Architecture + Platform + Research  │
│                              + Experiments)                     │
│  ### Go deeper      (Swift Primitives/Standards/Foundations +   │
│                      Embedded Swift)                            │
│                                                                 │
│  [alpha admonition moved here, small text, near page end]       │ ⑧ Relocate admonition
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Plus: [landing-page-principles article]                            ⑨ New article
      [@Metadata { @PageImage(purpose: card) }] on every article  ⑩ Card images per article
      [theme-settings.json — palette/typography]                  ⑪ Optional, separate decision
```

### Decision-by-decision detail

Each decision is independently reviewable. Labels match the diagram above.

---

**① Page title and subtitle (no change)**

- Current: `@DisplayName("Swift Institute")` + `@TitleHeading("A layered Swift package ecosystem")` at `Swift Institute.md:3–6`.
- Proposal: **keep**. Both work; no perspective challenges them.
- User action: confirm.

---

**② Hero sentence / concrete-verb abstract (REPLACE)**

- Current (`Swift Institute.md:8`):

  > A layered Swift package ecosystem — primitives, standards implementations, and composed foundations — aimed at correctness, composability, and long-term evolution.

- Problem: marketing and comparative agree this is generic. "Correctness, composability, long-term evolution" are table stakes across every maintained Swift library. The verb "aimed at" gives the reader no action to perform. DocC-on-DocC's own abstract is concrete: "Produce rich API reference documentation and interactive tutorials for your Swift framework or package."

- Proposal: replace with a concrete-verb sentence. Candidate directions, all within the voice lock (no counts, no commitments, no stewardship):
  - **A.** "Swift packages that compile without Foundation, encode domain meaning in types, and can be adopted one at a time." (Marketing-perspective shape.)
  - **B.** "Build on Swift packages that are typed, portable, and composable — primitives, standards, and foundations that you adopt one at a time."
  - **C.** "Swift packages where types encode meaning, errors declare their shape, and no layer depends on Foundation."
  - **D.** Keep the current sentence but prepend or append one concrete sentence with a reader verb.

- Recommendation: **C** or **A**. Both name three distinctive, falsifiable properties; both have reader-graspable verbs. C is the closest in phrasing to the existing principles section and loses least continuity. A is slightly punchier. D is the most conservative but still leaves the generic line intact.

- User action: pick wording, or propose an alternative.

---

**③ `@CallToAction` in root `@Metadata` (ADD)**

- Current: no CTA on the root. Nested in Topics are 6 groups, the user must scan to find a path.
- DocC mechanism: `@CallToAction(url:, purpose: link, label:)` inside `@Metadata` renders a prominent header button. Verified in `landing-page-docc-capabilities.md` section 5.
- Candidate targets:
  - **a.** GitHub organisation landing (`https://github.com/swift-institute`), label "View on GitHub". Matches Vapor / Hummingbird convention.
  - **b.** The latest blog post itself (`<doc:Blog/Restarting-the-Blog>` — but `@CallToAction` requires `url:` or `file:`, and DocC's `<doc:>` references are not URLs). So this would have to be `url: "https://swift-institute.org/documentation/swift_institute/blog/restarting-the-blog"` — brittle and unidiomatic.
  - **c.** Getting Started (`url: "https://swift-institute.org/documentation/swift_institute/getting-started"`, label "Get Started"). Same URL caveat.
- Recommendation: **a** — GitHub org — because it's the only external URL that is stable and works outside the DocC-rendered HTML. The internal routes (b, c) would need absolute URLs that change if the deploy URL changes. Stick with the external GitHub link.
- User action: confirm CTA destination or defer the CTA decision entirely.

---

**④ Hero image via `@PageImage(purpose: card)` (DEFER)**

- Current: no image on the root.
- DocC mechanism: `@Metadata { @PageImage(purpose: card, source: "si-hero", alt: "...") }`. Precedent: SwiftData's `swiftdata-hero`, SwiftUI's `landmarks-app-article-hero`.
- Problem: the ecosystem has no visual identity asset yet. A placeholder or generic gradient would look unpolished and contradict the alpha-conservative voice. Producing a real asset is out of scope for this pass.
- Recommendation: **DEFER** the hero image. Re-open when an identity asset exists. This is the least-leveraged of the proposed changes; skipping it does not block the rest.
- User action: confirm defer, or name an existing asset to use.

---

**⑤ Hero principle inline — keep one, move the rest (REDUCE)**

- Current (`Swift Institute.md:12–72`): five H3 sections, each a paragraph + code block / table. Types encode meaning → Specs as namespaces → Concrete errors → Foundation independence → Granular composition.
- Problem: all three perspectives converge. Marketing says this over-serves intent 2 (philosophy) and starves intent 1 (latest) and intent 3 (try). Comparative says Apple's DocC landings do not embed multi-principle prose in Overview. Technical says the vertical real-estate could be better spent on `@Links`, `@Row`, or the Topics grid.
- Options from marketing section 5:
  - **(a)** Compress in place — rejected, does not solve the buried-blog problem.
  - **(b)** Move all to a dedicated Principles article.
  - **(c)** Replace entirely with featured blog content.
  - **(d)** Hybrid — keep the strongest one on root, move the other four to a Principles article.
- Recommendation: **(d)**. Rationale: the "Types encode meaning" block at `:12–26` is the strongest concrete material on the page — phantom-type Tagged with visible compile-error. It is the single content DocC-on-DocC would let you keep in Overview. The other four (Specs as namespaces, Concrete errors, Foundation independence, Granular composition) move to a new article at `Swift Institute.docc/Principles.md` (or similar), referenced from Topics.
- Alternative: **(c)** if the user judges that a Principles article is too much content for an alpha and would rather the blog carry the ideological weight by example. Marketing notes (c) is the more aggressive move.
- User action: choose (c) or (d); confirm "Types encode meaning" as the retained hero if (d).

---

**⑥ Surface the latest blog post above Topics (ADD)**

- Current: blog is the sixth and last Topics group at `Swift Institute.md:102–104`. The Blog index at `Swift Institute.docc/Blog/Blog.md` contains a single link, which itself resolves to a single post (`Restarting-the-Blog`). Two clicks from landing to dated content — in a site whose primary purpose is the blog.
- DocC mechanism: `@Links(visualStyle: .detailedGrid) { - <doc:Blog/Restarting-the-Blog> }` in a new `## Latest writing` (or `## Recent` or `## From the blog`) section ABOVE `## Topics`. Precedent: SwiftUI's Featured samples section.
- Requires: the target (`Restarting-the-Blog`) must have `@Metadata { @PageImage(purpose: card, ...) }` for the grid to render with a card image rather than fall back to a colored square. This is a ⑩-class subtask, handled by adding `@PageImage(purpose: card)` to every page the Topics grid references.
- Alternative considered: put "Latest writing" as the first Topics group. Still works, but loses the above-Topics emphasis that SwiftUI's pattern provides.
- Verification needed: `@Links(visualStyle:)` on a module root page alongside a `## Topics` section — docs are silent. ~5-minute local build confirms.
- Recommendation: **ADD** `## Latest writing` as a first-class section above Topics. This is the single highest-leverage change in the entire proposal, per all three perspectives.
- User action: confirm ADD and the section heading.

---

**⑦ Topics reorganisation and card rendering (RESTRUCTURE)**

Two sub-decisions:

**⑦a. New group structure (reader goals, not architecture)**

- Current (`Swift Institute.md:75–104`):
  ```
  ### Start here         - Getting Started, FAQ
  ### Architecture       - Architecture, Platform
  ### Layers             - Swift Primitives, Swift Standards, Swift Foundations
  ### How we work        - Research, Experiments
  ### Deep dives         - Embedded Swift
  ### Blog               - Blog
  ```
- Problem: mixes reader-goal groups ("Start here", "Deep dives") with architecture-categorical groups ("Architecture", "Layers"). "Layers" duplicates "Architecture" conceptually — they point at overlapping content. Blog is last.
- Proposal (goal-based, 4 groups):
  ```
  ### Start reading        - Blog, Restarting-the-Blog
  ### Start building       - Getting Started, FAQ
  ### Understand the design - Architecture, Platform, Research, Experiments
  ### Go deeper            - Swift Primitives, Swift Standards, Swift Foundations, Embedded Swift
  ```
- Rationale: each group names a reader's stated intent. "Understand the design" merges Architecture + How-we-work since both serve the "is this credible" question. "Go deeper" absorbs the Layers group and the Embedded deep dive since both are for readers who have already committed to investigate. "Start reading" elevates the blog.
- Alternative: keep the current 6 groups but reorder so Blog is first. Conservative but loses the goal-reframing benefit.
- User action: choose between the 4-group goal restructure or a reorder-only minimum.

**⑦b. Render Topics as a detailedGrid**

- DocC mechanism: `@Options { @TopicsVisualStyle(.detailedGrid) }` at the top of the root page. Converts the default bulleted list into card rendering with card image + title + abstract per entry.
- Requires: every linked article has `@Metadata { @PageImage(purpose: card, source: ..., alt: ...) }`. Without card images, `detailedGrid` degrades to a colored-square-plus-title grid — visually acceptable but loses the pattern's primary benefit.
- Alternative: `compactGrid` (title + card image only, no abstract). Useful if abstracts are long and crowd the grid. Less informative per card but more compact.
- Alternative: leave Topics as a plain list. Low effort; keeps the page looking like DocC-on-DocC's default (which is fine but forgoes the SwiftUI-style polish).
- Recommendation: **detailedGrid**, conditional on ⑩ (adding card images). Without ⑩ the grid is not worth rendering.
- User action: approve detailedGrid (or choose compactGrid, or keep list).

---

**⑧ Alpha admonition placement (RELOCATE)**

- Current (`Swift Institute.md:10`): `> Important:` admonition is the second visible element on the page, immediately after the abstract.
- Problem: per the marketing perspective, it primes distrust before the pitch has landed. Apple DocC landings do not open with warnings.
- Proposal: move to the footer of the root page, rendered as `@Small { ... }` (per DocC's `@Small` directive — small-print text). Still present, no longer above the fold.
- Alternative: keep in place. Conservative. Counterargument: some readers appreciate the up-front honesty; removing/relocating could feel like hiding the alpha status.
- Recommendation: **relocate** but test visually — a 5-minute local build confirms the `@Small` styling reads as appropriate disclosure rather than as hidden fine-print.
- User action: approve relocation, keep-in-place, or propose alternative phrasing.

---

**⑨ New `Principles.md` article (CREATE, conditional on ⑤-(d))**

- Contents: the four principles being moved from the root — Specifications as namespaces, Concrete errors, Foundation independence, Granular composition — with their current code blocks and tables.
- Placement in Topics: under `### Understand the design`.
- `@Metadata { @PageImage(purpose: card, ...) }` so it renders properly in the Topics grid per ⑩.
- Cross-linked from the root's retained "Types encode meaning" block: "One of [five, four, a handful of] design principles the ecosystem is built on — see <doc:Principles> for the rest."
- User action: approve creation and title (`Principles` vs `Design Principles` vs `Philosophy`).

---

**⑩ Add `@PageImage(purpose: card)` to every Topics-referenced article (ADD)**

- Required for: Getting Started, FAQ, Architecture, Platform, Research, Experiments, Swift Primitives, Swift Standards, Swift Foundations, Embedded Swift, Blog, Restarting-the-Blog, and the new Principles article if ⑨ is approved.
- Source assets: not yet produced. Options:
  - **a.** Skip — rely on the fallback (color-block square + title). `detailedGrid` still works, just unpolished.
  - **b.** Simple generative placeholders — a gradient or pattern per article category. Implementable with a Swift script or any image tool.
  - **c.** Real asset per article — out of scope for this pass.
- Recommendation: **a** for the first pass (ship the structure, accept the fallback rendering), then **b** once the structure proves out. Do not block on **c**.
- User action: approve the staged approach.

---

**⑪ `theme-settings.json` (SEPARATE DECISION)**

- DocC mechanism: a `theme-settings.json` file at `Swift Institute.docc/theme-settings.json` lets the catalog tune colors, typography, border radius, icons, and feature flags. Schema at `ThemeSettings.spec.json` in swift-docc.
- Scope for this pass: at minimum, `meta.title` to override the HTML `<title>` tag (currently renders as "Swift Institute | Documentation"). Beyond that, a minimal color and font customization would give visual identity.
- Out-of-scope per handoff: `features.docs.quickNavigation.enable = false` and `features.docs.onThisPageNavigator.disable = true` — these HIDE chrome, which the handoff forbids.
- Recommendation: **start with `meta.title` only** in this pass; defer color/typography to a later pass once the structural changes above ship.
- User action: approve minimal theme-settings.json, or propose a bolder palette/typography set.

### Directive-to-decision mapping

Direct map between each DocC directive from `landing-page-docc-capabilities.md` and the decision it supports, so that it is clear every change uses a DocC-native mechanism:

| Decision | DocC directive(s) | Verified |
|----------|-------------------|:--------:|
| ① Title/subtitle | `@Metadata { @DisplayName, @TitleHeading }` | already used |
| ② Abstract | First paragraph of article body (Markdown) | n/a (prose) |
| ③ CTA | `@Metadata { @CallToAction(url:, purpose:, label:) }` | ✓ |
| ④ Hero image | `@Metadata { @PageImage(purpose: card, source:, alt:) }` | ✓ |
| ⑤ Hero principle | Markdown H3 + fenced Swift code block | ✓ |
| ⑥ Latest writing | `@Links(visualStyle: .detailedGrid)` above `## Topics` | root-page coexistence: needs ~5-min build verify |
| ⑦a Topics groups | `### Group` under `## Topics` | ✓ |
| ⑦b Topics rendering | `@Options { @TopicsVisualStyle(.detailedGrid) }` | verified; applies via scope:local |
| ⑧ Alpha admonition | `@Small { ... }` | ✓ |
| ⑨ Principles article | new `.md` file + `@Metadata` | ✓ |
| ⑩ Card images | `@Metadata { @PageImage(purpose: card) }` per article | ✓ |
| ⑪ theme-settings.json | catalog-root `theme-settings.json` | ✓ |

No decision requires a feature DocC doesn't have, no decision bypasses DocC's chrome, and every change is reversible by a single commit.

### Verification steps before production deploy

Per the handoff constraint "Verify changes locally with `xcrun docc convert` first":

```bash
cd "/Users/coen/Developer/swift-institute"
xcrun docc convert "Swift Institute.docc" \
  --output-path /tmp/si-docs \
  --transform-for-static-hosting \
  --hosting-base-path /
cd /tmp/si-docs && python3 -m http.server 8080
# Inspect http://localhost:8080/documentation/swift_institute/
```

Run this after each approved decision batch, not all at once. Specifically verify:

1. `@Links(visualStyle: .detailedGrid)` on the root page coexists with `## Topics` — both render, no `docc convert` warning.
2. `@TopicsVisualStyle(.detailedGrid)` applied on the root does not propagate unexpectedly to descendant articles.
3. `@CallToAction` button renders in the header, not clipped by DocC chrome.
4. `@Small` admonition placement reads as disclosure, not hidden fine-print.

All four verifications are minutes of local build + visual inspection.

### Skill opportunity (per handoff Next Steps step 2)

If the decisions above prove out and the resulting patterns stabilise, this research produces reusable DocC-landing conventions worth promoting into a dedicated **`docc-landing`** (or **`public-docc`**) skill per `/skill-lifecycle`. Candidate requirement IDs:

- `[DOCC-LAND-001]` Root page abstract MUST be a concrete-verb sentence naming at least one reader action.
- `[DOCC-LAND-002]` Root page MUST surface the most recent editorial content (blog, announcement) above `## Topics` via `@Links(visualStyle: .detailedGrid)` when editorial content is a primary purpose of the site.
- `[DOCC-LAND-003]` Root page Topics groups MUST be organized by reader goal (Start reading / Start building / Understand the design / Go deeper), not by internal architecture.
- `[DOCC-LAND-004]` Root page Topics SHOULD render as `.detailedGrid` when card images are available on each linked article.
- `[DOCC-LAND-005]` Article pages referenced from root Topics MUST declare `@Metadata { @PageImage(purpose: card, source:, alt:) }`.
- `[DOCC-LAND-006]` Root page MUST NOT hide, re-style, or bypass DocC's sidebar, navigator, search, or breadcrumbs. Catalog-level theming via `theme-settings.json` is permitted for colors, typography, border radius, and icons only.

The skill would sit under `swift-institute/Skills/docc-landing/` and reference the three research documents above. Promotion waits until at least one deploy has shipped with the new structure and proven out in practice — premature extraction is a corpus-meta-analysis anti-pattern per `[META-*]`.

## Outcome

**Status: RECOMMENDATION** — nothing is implemented yet. Eleven decisions (⑥ and ⑦a/b most load-bearing) await user approval per the handoff's Next Steps step 3.

### Summary of what will change, at a glance

| What | From | To |
|------|------|----|
| Abstract (line 8) | "aimed at correctness, composability, and long-term evolution" | concrete-verb sentence (decision ②) |
| CTA | absent | `@CallToAction` pointing at GitHub org (decision ③) |
| Principles | five inline on root | one inline (Tagged) + four in new `Principles` article (decisions ⑤, ⑨) |
| Latest writing | buried as sixth Topics group | `@Links(detailedGrid)` section above Topics (decision ⑥) |
| Topics groups | 6 (mixed reader-goal + architecture) | 4 (all reader-goal), Blog first (decision ⑦a) |
| Topics rendering | bulleted list | `@TopicsVisualStyle(detailedGrid)` — card grid (decision ⑦b) |
| Alpha admonition | above the fold (line 10) | `@Small` near page end (decision ⑧) |
| Card images | none | `@PageImage(purpose: card)` on every article (decision ⑩) |
| Theme | DocC defaults | minimal `theme-settings.json` with `meta.title` override (decision ⑪) |
| Hero image | none | deferred to a later pass (decision ④) |

### Decision summary for user approval

The user approves, modifies, or rejects each of these before any file edit:

1. **② Abstract** — pick from A / B / C / D, or propose alternative.
2. **③ CTA destination** — GitHub org, or deferred.
3. **④ Hero image** — defer, as proposed.
4. **⑤ Principles placement** — (d) hybrid (keep Tagged, move rest to article) or (c) replace entirely with featured blog surface.
5. **⑥ `## Latest writing` section above Topics** — approve as highest-leverage change.
6. **⑦a Topics group restructure** — 4-group goal-based restructure, or minimum reorder (blog first only).
7. **⑦b Topics card rendering** — detailedGrid, compactGrid, or stay as list.
8. **⑧ Alpha admonition** — relocate to `@Small` footer, or keep in place.
9. **⑨ `Principles.md` article** — approve creation, name.
10. **⑩ Card images** — approve staged (fallback first, placeholder second, real assets deferred).
11. **⑪ theme-settings.json** — minimal `meta.title` only, or bolder palette/typography.

### After user approval

Order of implementation, per the handoff:

1. Batch the approved decisions into two or three commits (structural changes together, card-image additions separately, theme-settings separately).
2. Local `xcrun docc convert --transform-for-static-hosting` verification after each batch.
3. Push to main; deploy workflow runs `~2 min`.
4. Verify live.
5. Update `Research/documentation-docc-alpha-launch.md` with a v1.1.0 revision noting the structural adjustments; this research document becomes status DECISION once implementation lands.
6. Evaluate skill extraction per `/skill-lifecycle` once the structure has held for one or two weeks.

## References

- `Research/landing-page-marketing-perspective.md` — audience / journey / copy diagnosis
- `Research/landing-page-docc-capabilities.md` — DocC 6.3 directive availability matrix
- `Research/landing-page-comparative-study.md` — 14 comparator sites, Apple precedent
- `Research/documentation-docc-alpha-launch.md` — locked alpha voice (status: DECISION), prior structural decision
- `HANDOFF.md` — task brief, constraints, next-steps ordering
- `Swift Institute.docc/Swift Institute.md` — current root page under revision
- DocC directive references (swift.org/documentation/docc and swift-docc GitHub) — enumerated inside `landing-page-docc-capabilities.md`
- DocC precedent landings — Apple's DocC-on-DocC (`swift.org/documentation/docc`) and SwiftUI (`developer.apple.com/documentation/swiftui`)
