# Comparative Study of Technical-Project Landing Pages

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: IN_PROGRESS
---
-->

## Context

The swift-institute.org public alpha is rendered entirely through DocC. The
landing page currently reads as API documentation rather than as a project
front door: reader-intent routing is weak, the blog (the alpha's primary
writing surface) is buried at the bottom of `## Topics`, and the root page
does not visibly distinguish itself from an auto-generated module index.

Before proposing changes, we need to see how comparable technical projects
compose their landing pages, and we need to separate patterns that can be
expressed within DocC's chrome from patterns that require bypassing it.
This study is descriptive; it does NOT recommend what swift-institute.org
should adopt. That recommendation belongs to a synthesis document that
combines this comparative perspective with the marketing and technical
perspectives being produced in parallel.

"Comparable" here means two families of site:

1. **DocC-rendered sites** — Apple's own DocC documentation pages and
   framework landings (swift.org/documentation/docc, developer.apple.com
   Swift/SwiftUI/Foundation/SwiftData). These operate under exactly the
   same constraints swift-institute.org operates under.
2. **Static-site / marketing landings** — Swift.org, Vapor, Hummingbird,
   SwiftNIO (README-as-landing), plus adjacent technical projects
   (Apollo, Rails, Next.js, Hugo, Astro). These are reference points for
   intent routing, hero composition, and latest-content surfacing; they
   are NOT templates to copy because they do not have DocC's chrome.

## Question

Which above-the-fold composition, reader-intent routing, identity-copy,
code-on-landing, and latest-content-surfacing patterns appear on comparable
technical-project landing pages — and which of those patterns translate
into DocC's article-body + Topics chrome versus which require bypassing
DocC?

## Analysis

Unless otherwise noted, all sites were fetched on 2026-04-15. Apple's
DocC-rendered pages (developer.apple.com and swift.org/documentation/docc)
are single-page applications that render from JSON blobs; the analysis
below was conducted against the DocC JSON at the
`/data/documentation/{module}.json` endpoints as well as the rendered
HTML where reachable.

### 1. First-paint anatomy

For each site, the composition immediately visible on desktop before
scrolling:

| Site | Hero composition | Category |
|------|------------------|----------|
| swift.org/documentation/docc (DocC landing for DocC) | Title, one-sentence abstract, Overview prose paragraph with hero image, then a `## Topics` tree organised into 6 groups. No CTA buttons, no code. | text-heavy + Topics-led |
| developer.apple.com/documentation/swift (Swift language) | Title, one-sentence abstract "Build apps using a powerful open language.", Overview, then 10 Topics groups (Essentials, Standard Library, Observation, Distributed Actors, …). No hero image, no code above fold, no CTA. | Topics-led, nav-heavy |
| developer.apple.com/documentation/swiftui | Title, abstract "Declare the user interface and behavior for your app on every platform.", Overview, then a **Featured samples** section rendered as a detailed-grid of 4 sample apps (each with card image), then 9 Topics groups. Hero image `landmarks-app-article-hero` of Landmarks sample on Mac/iPad/iPhone. No code above fold. | featured-led (visual cards) |
| developer.apple.com/documentation/foundation | Title, abstract "Access essential data types, collections, and operating-system services to define the base layer of functionality for your app.", Overview, then 7 Topics groups. No hero image, no featured section, no code. | pure Topics-led |
| developer.apple.com/documentation/swiftdata | Title, abstract "Write your model code declaratively to add managed persistence and efficient model fetching.", hero image `swiftdata-hero` (white Swift logo on blueprint background), Overview, a featured sample card for "Adding and editing persistent data in your app", then 8 Topics groups. | hero-image + featured-card |
| swift.org (Swift language homepage) | Headline "Swift is the powerful, flexible, multiplatform programming language." with three supporting descriptors "Fast. Expressive. Safe.", primary "Install" CTA, and a code sample (vectorised UTF-8 ASCII check) visible above fold. | code-led + pitch-led |
| swift.org/blog | Large hero image with headline "Swift 6.3 Released" as a featured post occupying the top of the page, followed by a vertical list of recent posts grouped by category (Community / Developer Tools / Adopters / Digest). | featured-post-led |
| vapor.codes | Tagline "Swift, but on a server", subheading positioning Vapor as a foundation for HTTP servers / backends / APIs, a minimal `app.get("hello")` code sample, primary "Get Started" CTA plus a GitHub-stars link. | code-led + pitch-led |
| hummingbird.codes | Tagline "The Web framework for Swift", two code examples above the fold (a Hello-Swift router and a MongoDB/Meow query), three CTAs "Get started" / "Example Projects" / "Join the Community". | code-led |
| github.com/apple/swift-nio (README, since swiftnio.io redirects to it) | One-sentence identity "Event-driven network application framework for high performance protocol servers & clients, non-blocking." Conceptual overview prose above any code. Code deferred to "Getting Started"/"Example Usage" sections. | text-heavy (README convention) |
| rubyonrails.org | Tagline "Accelerate your agents with convention over configuration." plus secondary claim about scaling "from PROMPT to IPO" with "token-efficient code". A substantial `Article` Active-Record model code example above the fold. | code-led + pitch-led |
| nextjs.org | Tagline "The React Framework for the Web" with subtitle "Used by some of the world's largest companies, Next.js enables you to create high-quality web applications with the power of React components." Primary "Get Started" and "Learn Next.js" CTAs. A terminal snippet `▲ ~ npx create-next-app@latest` above the fold. Prominent "Next.js 16" release banner. | pitch-led + release-banner |
| astro.build | Tagline "The web framework for content-driven websites." Hero composite of an Astro component code example (imports React, fetches server-side, renders with layout). Primary "Get Started" CTA, secondary `npm create astro@latest`. Release banner "Astro 6.1 Available now!" linking to blog. | code-led + release-banner |
| apollographql.com | Tagline "The API Orchestration Platform for AI Agents, Web, and Mobile Apps" with subheading about connecting agents/apps to GraphQL and REST. No code above the fold — visual-imagery-led with enterprise logo trust bar. CTAs "Start for free" / "See how it works" / "Contact us". | pitch-led (enterprise marketing) |
| gohugo.io | Tagline "The world's fastest framework for building websites." Primary "Getting started" CTA and a GitHub-star count. No code above the fold. | pitch-led, minimal |

**Grouping by hero strategy**:

- **Code-led** (code is part of the hero, acts as identity-by-syntax):
  vapor.codes, hummingbird.codes, swift.org, astro.build, rubyonrails.org
- **Pitch-led** (prose tagline is the hero, code deferred):
  nextjs.org, apollographql.com, gohugo.io
- **Topics-led** (DocC default): swift.org/documentation/docc,
  developer.apple.com/documentation/swift, Foundation
- **Featured-content-led** (visual cards dominate the hero area):
  developer.apple.com/documentation/swiftui, swift.org/blog, SwiftData
- **Text-heavy** (README convention): swift-nio

The current swift-institute.org root sits between "Topics-led" and a partial
"code-led" (it has four inline code samples inside Overview prose). It
does not use featured-grid, hero image, or CallToAction directives.

### 2. Reader-intent routing

Patterns observed for routing distinct visitor intents on a single landing:

- **Multi-CTA button row** — Hummingbird routes three intents explicitly
  with three buttons above the fold: "Get started" (try-it), "Example
  Projects" (learn-by-example), "Join the Community" (community). Vapor
  uses "Get Started" + GitHub stars. Next.js uses "Get Started" (docs) +
  "Learn Next.js" (interactive tutorial). Astro uses "Get Started" + an
  install-command snippet that doubles as a CTA.

- **Top-nav as intent index** — Swift.org exposes Docs / Community /
  Packages / Blog / Install as persistent top-nav anchors so each intent
  has a one-click destination regardless of scroll position.

- **Featured samples grid** — developer.apple.com/documentation/swiftui
  routes the "I want to see what this looks like built" intent by leading
  with four sample-app cards (each with card image) BEFORE the Topics
  tree. This is a DocC-native detailed-grid section (`role: sampleCode`
  pages referenced from the landing).

- **"What's new" section surfaced near the top** — SwiftUI's Topics
  starts with "Essentials" containing an "Adopting Liquid Glass" migration
  guide and a "SwiftUI updates" release-notes page. This routes "what's
  changed recently?" before "what is this in total?"

- **Featured-post hero** — swift.org/blog puts "Swift 6.3 Released" as a
  full-width hero above the post list; the hero IS the latest post.
  Next.js uses a similar pattern with a "Next.js 16" banner linking to
  `/blog/next-16`, and Astro with "Astro 6.1 Available now!".

- **Sequential sections assuming progressive engagement** — swift.org's
  Getting Started page uses task-oriented groupings (Command-line Tool /
  Library / Web Service / iOS/macOS Application) without hero imagery
  or decision trees, relying on reader self-selection.

- **Enterprise-logo trust bar** — Apollo, Next.js, Astro, Vapor, Rails
  all include "used by X / trusted by Y" bars below the hero. This routes
  the "should I take this seriously?" intent.

The weakest pattern on the current swift-institute root is that there is
**no visible intent split at all above the fold** — a reader cannot tell
whether to go to Getting-Started, FAQ, Architecture, or the Blog without
scrolling through the Overview prose and then reading `## Topics` group
headings.

### 3. Project identity in 1 sentence

Taglines, verbatim, grouped by style:

**Prose pitch** (what it is, in plain language):
- "The powerful, flexible, multiplatform programming language." (Swift)
- "Declare the user interface and behavior for your app on every
  platform." (SwiftUI)
- "Access essential data types, collections, and operating-system services
  to define the base layer of functionality for your app." (Foundation)
- "Write your model code declaratively to add managed persistence and
  efficient model fetching." (SwiftData)
- "Produce rich API reference documentation and interactive tutorials for
  your Swift framework or package." (DocC)
- "Build apps using a powerful open language." (Swift framework page)
- "The React Framework for the Web." (Next.js)
- "The web framework for content-driven websites." (Astro)
- "The world's fastest framework for building websites." (Hugo)
- "The Web framework for Swift." (Hummingbird)
- "Event-driven network application framework for high performance
  protocol servers & clients, non-blocking." (SwiftNIO)

**Metaphor / positioning pitch** (an analogy, not a definition):
- "Swift, but on a server." (Vapor)
- "The API Orchestration Platform for AI Agents, Web, and Mobile Apps."
  (Apollo)
- "Accelerate your agents with convention over configuration." (Rails)

**What makes the strong ones strong.** The taglines that land are
specific about both the subject and the verb: SwiftUI says "declare the
user interface" (not "build UIs"), SwiftData says "managed persistence
and efficient model fetching" (not "data modelling"), Hugo claims
superlative "fastest" (contestable but memorable), Vapor uses a
metaphor that names the entire product. Apollo's newer tagline tries
to cover too many audiences ("AI Agents, Web, and Mobile Apps") and
reads as diluted. Foundation's abstract is 20 words where 8 would do.

**None of the strong taglines is code**. Code appears ALONGSIDE the
tagline on code-led sites, but the identity sentence itself is always
prose. The one-sentence identity is a separate surface from the
syntactic identity.

swift-institute's current root abstract is:

> "A layered Swift package ecosystem — primitives, standards
> implementations, and composed foundations — aimed at correctness,
> composability, and long-term evolution."

By the pattern above, this is prose-pitch category, 22 words, and its
verbs ("aimed at correctness, composability") are abstract. SwiftUI's
"declare the user interface and behavior for your app" is a concrete
user action; swift-institute's "aimed at correctness" is a goal, not
something the reader does. This is a description of the subject, not a
framing of the reader's next action.

### 4. Code-on-landing patterns

Sites where code appears above the fold and the role that code plays:

| Site | Code role |
|------|-----------|
| swift.org | Proof-of-performance (vectorised UTF-8 ASCII). Code demonstrates the "Fast." claim in the tagline — it is evidence, not tutorial. |
| vapor.codes | Minimum-viable demo. A 5-line `app.get("hello")` route is the smallest complete program. Role: "this is how easy it is." |
| hummingbird.codes | Two examples with different purposes — the router shows the core primitive, the MongoDB/Meow example shows ecosystem composition. Role: identity + breadth. |
| astro.build | Feature demonstration. Shows an Astro component importing React, fetching server-side, rendering a product page. Role: "here's what makes Astro Astro." |
| rubyonrails.org | Syntactic density. An `Article` model with associations, attachments, enums, callbacks in a small number of lines. Role: "this is what Rails feels like." |

Sites where code is deferred (README body or docs):

| Site | Why code is deferred |
|------|----------------------|
| swift-nio (GitHub README) | Leads with architectural prose explaining EventLoop / Channel / ChannelHandler concepts before any code. The project is a framework whose identity is conceptual; a code sample would not communicate it. |
| developer.apple.com/documentation/* | DocC framework landings never lead with code — they lead with the abstract + Overview prose + Topics. Code appears on specific symbol pages and sample-code pages. |
| Apollo | Pure marketing site — code lives in docs, not on the landing. |
| Next.js | Code on landing is a terminal snippet (`npx create-next-app@latest`), not source code. The landing is pitch-led; source code is on docs / templates pages. |
| Hugo | No code on landing at all. |

**Observation**. The current swift-institute.org root is **unusual** for
a DocC landing — it embeds four inline code samples (`Tagged<Timer,
UInt64>`, `RFC_3986.URI`, `throws(Parse.Error)`, SwiftPM `dependencies`)
inside its Overview prose. Apple's DocC landings do not do this. The
Vapor/Hummingbird-style landing pattern (code as part of hero) also does
not match because those are static-site marketing landings, not DocC
pages. Swift.org's landing is static and uses code as pitch-proof, and
swift-institute has imitated that convention inside DocC Overview prose.

This is not automatically wrong — code-as-identity is a valid choice —
but it means swift-institute's root is closer to swift.org-marketing-
page conventions than to Apple-framework-DocC conventions.

### 5. Latest-content surfacing

The alpha's primary purpose is the blog. Patterns for surfacing latest
content on comparable landings:

- **Full-width featured-post hero** — swift.org/blog elevates the most
  recent release post ("Swift 6.3 Released") to occupy the top of the
  page with a large hero image. The rest of the page is a category-
  tagged list below. This is the pattern for a blog index, not a
  project root.

- **Release-banner strip** — Astro ("Astro 6.1 Available now!") and
  Next.js ("Next.js 16") surface the latest release as a dismissible
  banner linking to the announcement post. The banner lives above the
  regular hero. Project identity is still the primary hero; the latest
  release is an inset.

- **"What's new" first-item in Topics** — Apple's Swift and SwiftUI
  documentation landings both place "Swift updates" / "SwiftUI updates"
  as the first entry in the "Essentials" Topics group. This is not a
  visual surface — it is a prioritised link inside the Topics tree.
  This pattern translates natively into DocC's chrome.

- **Sample-project cards grid** — developer.apple.com/documentation/swiftui
  surfaces 4 named samples (Landmarks, Wishlist, Destination Video,
  document-based app) as a detailed-grid above Topics. This is not
  "latest" strictly — it's "featured/current exemplars" — but
  functionally it operates as "here's the most relevant thing to look
  at right now." The featured block is a first-class DocC section with
  `role: sampleCode` child pages.

- **Three-card news grid** (generic marketing pattern) — Apollo, Rails,
  and Astro all have sections further down the landing titled "News" /
  "Latest" / "From the blog" with 3 cards. Not above the fold, and
  typically auto-updating from a CMS.

- **No latest-content surface** — swift.org/documentation/docc,
  Foundation, swift-nio README, gohugo.io. These sites are either
  reference documentation where "latest" is release-notes-level (not
  editorial blog-level) or are product landings where the blog lives
  behind a top-nav link.

**Observation**. The current swift-institute root surfaces the blog via
`## Topics ### Blog` at the bottom of the Topics tree — the same visual
weight as every other group. None of the comparator sites surfaces a
blog that way if the blog is the alpha's primary writing surface. The
closest native-DocC precedents for lifting the blog into a more
prominent position are:

1. Apple's "Essentials / SwiftUI updates" — a prioritised link at the
   top of Topics.
2. SwiftUI's "Featured samples" — a detailed-grid section rendered
   above Topics. Applied to blog posts instead of samples, this would
   be a "Featured posts" grid on the root page.

### 6. Constraints alignment with DocC

DocC owns the navigator sidebar, top chrome, search, breadcrumbs, and
page-layout shell. Landing-page patterns can be classified by whether
they fit inside a DocC article body or require displacing DocC's chrome.

**Translates natively** (achievable inside a DocC article body + Topics,
with documented or verifiable directives):

| Pattern | DocC mechanism |
|---------|----------------|
| One-sentence project identity | Article abstract (first paragraph) |
| Prose Overview | Article body below abstract |
| Code samples above the fold | Fenced code blocks inside the article body |
| Hero image | `@PageImage(purpose: icon)` / `@PageImage(purpose: card)` — used by swiftdata (`swiftdata-hero`) and SwiftUI (`landmarks-app-article-hero`). |
| "What's new" prioritised link | First item of "Essentials" Topics group (Apple's convention) |
| Featured-samples detailed grid | `@Links(visualStyle: .detailedGrid)` section referencing sample/article pages — verified present on developer.apple.com/documentation/swiftui |
| Reader-intent Topics groups | `### Group Name` headings inside `## Topics` (current swift-institute root already uses this) |
| Latest-post card grid | Same `@Links(visualStyle:)` mechanism pointing at blog-post articles |
| Per-page CTA | `@CallToAction(url: purpose: label:)` directive — referenced in handoff; verification is the technical perspective's job |

**Does NOT translate** (requires bypassing DocC's chrome or is a
marketing-site-only pattern):

| Pattern | Why it doesn't fit DocC |
|---------|-------------------------|
| Two-column hero with code on the right and prose on the left | DocC article bodies flow single-column. `@Row`/`@Column` exist but render as stacked blocks in most contexts; verify before relying on them. |
| Dismissible release-banner strip above the hero | No DocC directive for this; would require theme-settings.json injection or a custom header. |
| Multi-CTA button row (3+ primary buttons) | `@CallToAction` exists but is typically one per page. A row of three buttons is not a documented DocC pattern. |
| Auto-updating "latest blog post" card | DocC is static. Any "latest post" surface is manually curated on each rebuild. |
| Full-width hero image with text overlay | DocC images are inline-flow; a hero-overlay layout is not a supported directive. `@PageImage(purpose: card)` is an aside image, not a full-width banner. |
| Enterprise-logo trust bar | Would require an article body that inlines a grid of logos — possible with `@Row`/`@Column` and repeated images, but visually weak inside DocC's content column. |
| Persistent top-nav with distinct sections (Docs / Community / Blog / Install) | DocC's nav is the sidebar tree, not a top bar. Top-of-page horizontal routing is not a DocC concept. |
| Category-filtered blog index | DocC has no taxonomy / tag system. Category filtering requires a separate blog engine. |
| Search-as-hero (like Swift Package Index's search box) | DocC search is in the top chrome and cannot be promoted to a landing-page component. |

### 7. Anti-patterns

Concrete misses observed on the studied sites, useful as "things to
explicitly avoid":

- **Abstract too long.** Apollo's "The API Orchestration Platform for
  AI Agents, Web, and Mobile Apps" tries to cover too many audiences in
  one sentence and reads as diluted. Foundation's 20-word sentence is
  technically correct but none of the words do work. A 10-12 word
  concrete-verb sentence (SwiftData, SwiftUI) is stronger.

- **Dense Topics lists with no grouping.** Swift's framework landing
  has 10 Topics groups, some with only one or two entries (Observation,
  Distributed Actors, Low-Level Atomic Operations are each a single
  link). This produces a long vertical list that is hard to scan. The
  Topics tree becomes the page.

- **Walls of prose before any navigation.** The swift-nio README leads
  with an extensive conceptual overview of EventLoops and Channels
  before showing code or linking to getting-started. This works for a
  README read by someone who is already oriented; it is a poor landing
  for a drop-in visitor.

- **Featured content that doesn't update.** If a "Featured samples" or
  "Latest post" section is curated manually (as it would be in DocC),
  the failure mode is the section ages into an anti-pattern — most-
  recent-post from two years ago. Any surface that implies freshness
  ("Latest", "What's new") must be cheap to update or it becomes worse
  than no surface at all.

- **"Click here for a tour" with no tour.** Several marketing sites
  (not in the Swift ecosystem) promise guided-tour CTAs that lead to a
  single generic docs page. If a "Get Started" CTA appears on the
  landing it must land on a page that actually starts something.

- **Separate blog index that visually resembles a changelog.** If the
  blog is the alpha's primary writing surface but its index renders as
  a dated list of link titles with no cards or excerpts, it reads as
  release notes, not editorial content. swift.org/blog's
  featured-post-plus-category-list hybrid is a strong pattern here;
  a flat chronological list is a weak pattern.

- **Principles expressed as a list of abstract nouns.** The existing
  swift-institute root had a 5-principles block that was judged subpar
  as initial UX (per HANDOFF.md). The anti-pattern is principles as
  nouns without a reader-facing verb — "correctness, composability,
  long-term evolution" does not tell a reader what they can DO.

### 8. Apple's own DocC site

Apple uses DocC to document DocC at
`https://www.swift.org/documentation/docc/`. This is the canonical
reference for a DocC-native project landing.

**First-paint anatomy** (from the DocC JSON at
`/data/documentation/docc.json`):

- `metadata.title`: "DocC"
- `metadata.roleHeading`: "Tool"
- `metadata.role`: "collection"
- `metadata.symbolKind`: "module"
- `abstract`: **"Produce rich API reference documentation and interactive
  tutorials for your Swift framework or package."**
- A hero image in the Overview section.
- `primaryContentSections[0]`: "Overview" — explanatory paragraphs
  describing DocC as a documentation compiler that converts Markdown
  into rich documentation.
- No CTA buttons, no banners, no code above the fold.
- `topicSections`: 6 groups in this exact order:
  1. **Essentials** — "Documenting a Swift Framework or Package"
  2. **Documentation Content** — 5 entries (Writing Symbol Documentation,
     Adding Supplemental Content, Linking to Symbols, Adding Code
     Snippets, Documenting API with Different Language Representations)
  3. **Structure and Formatting** — 6 entries (Formatting, Adding Tables,
     Other Formatting Options, Adding Images, Adding Structure,
     Customizing the Appearance)
  4. **Distribution** — 1 entry (Distributing Documentation)
  5. **Documentation Types** — 2 entries (API Documentation, Interactive
     Tutorials)
  6. **Shared Syntax** — 1 entry (Comment)

**What DocC-on-DocC does that swift-institute.org currently does not**:

1. **Leads with a single concrete-verb abstract.** "Produce rich API
   reference documentation and interactive tutorials for your Swift
   framework or package." The verb is "produce" and the object is
   specific. swift-institute's abstract "A layered Swift package
   ecosystem … aimed at correctness, composability, and long-term
   evolution" names no verb the reader can perform.

2. **Uses a hero image in the Overview section.** `@PageImage` is a
   documented DocC directive, used by swiftdata (`swiftdata-hero`) and
   DocC itself. swift-institute has no hero image.

3. **The first Topics group is "Essentials" with ONE link, not a menu.**
   DocC-on-DocC reduces the first reader-facing step to a single
   concrete action: "Documenting a Swift Framework or Package."
   swift-institute's first Topics group is "Start here" with two links
   (Getting-Started and FAQ) — close to the pattern but already
   broadening the choice.

4. **No code in the Overview prose.** DocC-on-DocC's Overview is pure
   prose; code lives on child pages. swift-institute's Overview embeds
   four code snippets inline, pulling the page toward a marketing-
   homepage style rather than a DocC-native style.

5. **Topics groups read as reader-goal categories, not architecture
   categories.** DocC-on-DocC groups by what the reader is trying to
   produce (Content / Structure / Distribution / Types / Syntax).
   swift-institute groups by internal architecture (Start here /
   Architecture / Layers / How we work / Deep dives / Blog) — some of
   which (Layers) only makes sense after the reader already knows what
   a layer is.

A closer Apple-framework analogue is the SwiftUI landing at
`developer.apple.com/documentation/swiftui`: it extends the DocC
convention with a hero image (`landmarks-app-article-hero`) and a
`Featured samples` detailed-grid section of 4 sample-app cards rendered
ABOVE the Topics tree. This is a DocC-native answer to "how do I make
the landing visually scannable without leaving DocC" and it appears
to be `@Links(visualStyle: .detailedGrid)` over child pages with
`@PageImage(purpose: card)` metadata — the technical perspective should
verify this.

## Outcome

**Status: RECOMMENDATION** (descriptive — the synthesis document
decides what swift-institute.org adopts).

### Patterns that translate to DocC

From the comparator set, these translate into DocC's chrome with
documented or verifiable directives:

- One-sentence concrete-verb abstract as the identity surface
- Hero image via `@PageImage(purpose: card)` — precedent in swiftdata,
  SwiftUI
- Prose Overview below the abstract
- Featured grid section above the Topics tree via `@Links(visualStyle:
  .detailedGrid)` — precedent in SwiftUI
- "What's new" prioritised as the first entry in the first Topics group
  — precedent in Swift + SwiftUI (updates link first in Essentials)
- Reader-goal-categorised Topics groups (what the reader is trying to do
  / produce / find) — precedent in DocC-on-DocC
- Per-page `@CallToAction` for specific article pages (verify availability
  in Swift 6.3 DocC; outside this perspective's scope)

### Patterns that do NOT translate

From the comparator set, these require bypassing DocC or are marketing-
site-only conventions:

- Two-column hero with code right, prose left
- Dismissible release-banner strip above the hero
- Multi-CTA button row as the hero's primary affordance
- Full-width hero image with text overlay
- Persistent top-nav with Docs / Community / Blog / Install sections
- Enterprise-logo trust bar at visual parity with a marketing homepage
- Category-filtered / tag-faceted blog index
- Search-as-hero

### Things Apple's DocC site does that swift-institute.org currently does not

The most directly-applicable precedent (DocC-on-DocC and SwiftUI) does
the following; swift-institute.org does none of these today:

1. **Concrete-verb abstract.** Current abstract is goal-oriented
   ("aimed at correctness, composability") rather than action-oriented
   ("Produce X for your Y"). (`Swift Institute.docc/Swift Institute.md`
   line 8.)
2. **Hero image via `@PageImage`.** No image on the current root.
3. **Overview without inline code.** Current root interleaves four code
   samples inside Overview prose. (Lines 16-26, 32-38, 44, 66-71.)
4. **A featured-grid section above Topics.** Current root has no
   equivalent of SwiftUI's Featured-samples detailedGrid.
5. **"What's new" as the first link.** Current "Start here" group
   leads with Getting-Started then FAQ. Neither is a "what's new / what's
   just published" surface. (Lines 77-80.)
6. **Reader-goal Topics categorisation.** Current groups (Start here /
   Architecture / Layers / How we work / Deep dives / Blog) mix a
   reader-goal group ("Start here") with architecture-categorical
   groups ("Layers"). DocC-on-DocC's groups are uniformly reader-goal.
7. **Blog surfaced as a first-class landing component, not the last
   Topics group.** Swift.org/blog and SwiftUI both elevate latest /
   featured content above the Topics tree; current swift-institute
   places Blog as the sixth and final Topics group at the bottom of
   the root. (Lines 102-104.)

These seven items are the delta between current swift-institute root
and the DocC-on-DocC + SwiftUI precedent. They are input to the
synthesis document, not a prescription.

## References

All URLs fetched on 2026-04-15 unless noted.

DocC-rendered sites (analysed via `/data/documentation/*.json` where
rendered HTML was empty due to client-side rendering):
- https://www.swift.org/documentation/docc/ — Apple's DocC-on-DocC
- https://www.swift.org/documentation/docc/data/documentation/docc.json — JSON for DocC-on-DocC
- https://developer.apple.com/tutorials/data/documentation/swift.json — Swift framework landing
- https://developer.apple.com/tutorials/data/documentation/swiftui.json — SwiftUI framework landing
- https://developer.apple.com/tutorials/data/documentation/foundation.json — Foundation framework landing
- https://developer.apple.com/tutorials/data/documentation/swiftdata.json — SwiftData framework landing
- https://developer.apple.com/tutorials/data/documentation/swift/swift_standard_library.json — Swift Standard Library collection
- https://developer.apple.com/tutorials/data/documentation/swiftui/app-organization.json — SwiftUI app-organization collection
- https://developer.apple.com/tutorials/data/documentation/swiftui/app-extensions.json — SwiftUI app-extensions collection
- https://developer.apple.com/tutorials/data/documentation/swiftui/landmarks-building-an-app-with-liquid-glass.json — Sample-code page structure reference

Static-site Swift landings:
- https://www.swift.org/ — Swift language homepage
- https://www.swift.org/documentation/ — swift.org documentation index
- https://www.swift.org/blog/ — swift.org blog index
- https://www.swift.org/documentation/server/ — Swift on Server page
- https://www.swift.org/getting-started/ — swift.org getting started
- https://vapor.codes/ — Vapor framework
- https://hummingbird.codes/ — Hummingbird framework
- https://github.com/apple/swift-nio — SwiftNIO (swiftnio.io redirects here)

Adjacent technical project landings:
- https://www.apollographql.com/ — Apollo GraphQL
- https://rubyonrails.org/ — Ruby on Rails
- https://nextjs.org/ — Next.js
- https://gohugo.io/ — Hugo
- https://astro.build/ — Astro

Not reached (access blocked by bot protection during this session; noted
rather than analysed):
- https://swiftpackageindex.com/ — Swift Package Index homepage
- https://www.pointfree.co/ — Pointfree

Source documents consulted:
- /Users/coen/Developer/swift-institute/HANDOFF.md
- /Users/coen/Developer/swift-institute/Swift Institute.docc/Swift Institute.md
- /Users/coen/Developer/swift-institute/Research/documentation-docc-alpha-launch.md
