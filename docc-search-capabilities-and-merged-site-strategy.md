# DocC Search Capabilities and Merged Site Strategy

<!--
---
version: 1.0.0
last_updated: 2026-04-17
status: RECOMMENDATION
---
-->

## Context

`docc merge` is the selected mechanism for combining swift-institute.org's main catalog with two new per-repo archives (`Research.docc`, `Experiments.docc`) on the site deploy. Before committing to Phase 2 implementation, experiment `docc-merge-multi-archive-hosting/` ([EXP-*] placement in `/Users/coen/Developer/swift-institute/Experiments/docc-merge-multi-archive-hosting/`) ran three article-only throwaway catalogs through `docc convert` → `docc merge` → `docc process-archive transform-for-static-hosting` on Swift 6.3.1 / macOS 26.2, then served the result locally.

The experiment's three acceptance criteria from the handoff at `/Users/coen/Developer/swift-institute/swift-institute.org/HANDOFF.md`:

| Acceptance criterion | Result |
|----------------------|--------|
| Unified landing page listing all source archives as top-level sections | **CONFIRMED** — `data/documentation.json` title "Swift Institute Merge Experiment", `topicSectionsStyle: detailedGrid`, one topic section with refs to all three archives; browser rendered three cards. |
| Cross-archive navigation | **CONFIRMED** — `index/index.json` lists all three archives as sibling modules of the merged root; sidebar expanded to show Alpha/Beta/Gamma Documentation each with their nested articles. |
| Search returns hits across all sources | **REFUTED** — the sidebar input is a title-only filter (labeled "Filter"); typing "airplane" (a body-only word in the Alpha Detail article) returned "No results found" even though the word is present on disk. |

The search refutation is what this research resolves. Two concerns:

1. Is the search gap specific to the merged output, or a property of DocC overall?
2. What is the right path for Phase 2 given the gap: ship without, overlay something, fork, or escalate?

The single-catalog swift-institute.org site today serves its content through the same renderer with the same title-only behaviour — so this is not a merge-induced regression. It is a pre-existing DocC constraint that merge surfaces.

## Question

What are DocC's search capabilities on the Xcode-26.4.1-bundled toolchain (Swift 6.3.1, `swift-docc-render-artifact` HEAD `6f911de` 2026-03-03), and which of the realistic search strategies best fits Phase 2 of the merged swift-institute.org deploy?

## Analysis

### Primary-source findings

Verified against local clones of `swiftlang/swift-docc` (`edbc69a1`) and `swiftlang/swift-docc-render-artifact` (`6f911de`). Citations are file:line into those clones unless otherwise noted.

#### Renderer (what the SPA does at runtime)

1. The sidebar "Filter" input and the Cmd/⌃-/ QuickNavigation modal are both powered by the **same** fuzzy matcher. The bundled `dist/js/documentation-topic.aaf718ac.js` contains exactly two `.exec()` sites: one is the input regex compilation (`.exec(n)`), the other is `.exec(t.title)`. No per-page body fetch ever enters the search path. Verified by grep across the bundle.

2. The fuzzy matcher iterates `symbols` — the flattened list derived from `/index/index.json`'s `interfaceLanguages[lang][]` tree — and tests each `symbol.title` against the user's processed regex. There is no field the renderer could use for body search because the index does not carry bodies.

3. The renderer reads the merged archive's `includedArchiveIdentifiers` array (present in our experiment's `index/index.json` with values `["AlphaDocs","BetaDocs","GammaDocs"]`) but does not filter search by it — all merged symbols are equally searchable by title.

4. Three theme feature flags gate search chrome: `enableQuickNavigation` (the `/` popup), `enableNavigator` (the whole sidebar), `enableOnThisPageNav` (the right rail). None of them changes the search algorithm; they only show or hide UI. `quickNavigation` is enabled by default, matching what the experiment saw (`/` shortcut hint visible).

#### Backend (what `docc convert` and `docc merge` produce)

5. `IndexingRecord` (`Sources/SwiftDocC/Indexing/IndexingRecord.swift`) is a full-shape search record with exactly the fields a full-text search would need: `title`, `summary`, `headings: [String]`, `rawIndexableTextContent: String` ("A concatenation of all other raw text content in the document or section"), `platforms`. It is already populated by the converter.

6. `IndexingRecord`s are written to `indexing-records.json` **only when `--emit-digest` is passed** to `docc convert` — `Sources/DocCCommandLine/Action/Actions/Convert/ConvertFileWritingConsumer.swift:177-178`. Without `--emit-digest`, the full-text artifact never leaves the process.

7. `docc merge` (`Sources/DocCCommandLine/Action/Actions/Merge/MergeAction.swift`) operates exclusively on `RenderIndex` (the navigation tree) and bulk-copies a whitelist of directories: `["data/documentation", "data/tutorials", "images", "videos", "downloads"]` (plus the static-hosting variants). `indexing-records.json` is not on the list, and `MergeAction.swift:52` carries an explicit `// TODO: Merge the LMDB navigator index` — that TODO is about the navigator LMDB, not even about indexing-records; the latter is neither present nor planned in the merge path.

8. `docc process-archive index` is a synonym for navigator-index building — `Sources/DocCCommandLine/Action/Actions/IndexAction.swift` constructs `NavigatorIndex.Builder`, not any full-text structure. It is not a back door to search.

9. The `features.docs.quickNavigation.enable` theme-settings flag mentioned in `Research/landing-page-docc-capabilities.md` has no referent in the `swift-docc` source — it is purely a renderer-side toggle. Backend output is identical whether or not theme-settings carries it.

#### In-flight work (what is not yet shipped)

10. Git log across `swift-docc`, `swift-docc-render-artifact`, `swift-docc-plugin`, `swift-docc-symbolkit` over the past 12 months shows no full-text search work. Recent navigator commits improve display names (#1463), API-collections-as-articles (#1440), group-marker flattening (#1423), external-entity indexing (#1328), beta status (#1249), external links (#1247). LMDB work is persistence for navigator metadata, not a search index. Per-page HTML content addition (#1396 / #1402 / #1409) targets static hosting of page bodies into `index.html` files — a prerequisite for Pagefind-style HTML crawling but not a search feature itself.

### Constraint: what this means for merge

The constraint is stronger than "search doesn't work on merged archives." `indexing-records.json` is untouched by `merge` (fact 7). Even if `swift-institute.org`, `Research`, and `Experiments` each shipped an `indexing-records.json` from a `--emit-digest` build, `docc merge` would drop all three on the floor. A search strategy that relies on DocC's own index shape requires either a fork of `swift-docc` (to merge the records) AND a fork of `swift-docc-render` (to consume them), or an overlay that does not depend on DocC-emitted search data at all.

### Prior art

**`swift.org/swift-evolution`** — a custom HTML/Vue dashboard, not DocC. Uses a hand-maintained proposals.json data file, custom search UI, custom status-filter pills. The precedent confirms that when Apple needs richer search than DocC offers, they go fully off-DocC for that surface. But that choice was about a proposals dashboard with unique status/author/Swift-version facets; for article/catalog browsing, `swift.org/documentation/` itself uses DocC with the same search limitations we are seeing.

**Pagefind** (`pagefind.app`) — static search for static sites. Post-build tool: crawls rendered HTML, emits a bucketed index keyed by Bloom-filter prefixes + small chunks fetched on demand. Client JS (~70 KB core) loads only buckets matching the query. Designed for JAMstack sites; no runtime service. Integrates via a single drop-in script tag and an HTML selector telling it which parts of each page are searchable content. Notable Swift-world adopter: [Point-Free's `pointfree.co`](https://www.pointfree.co/) uses Pagefind on their Swift-focused course site.

**Lunr.js / MiniSearch / Orama** — JS libraries for client-side indexing. Lunr builds the index at build time from a JS manifest; MiniSearch / Orama are smaller and faster. All three require a build step that emits a JSON corpus (title + body per page) and a UI binding. Viable but more code to maintain than Pagefind, which consumes the already-rendered HTML.

**Algolia DocSearch** — hosted, but free for open-source docs. Crawls the live site on a schedule and serves search via their API + Autocomplete UI. External dependency (Algolia infra), live-crawl latency (staleness after deploys), and application gating (approval queue). Used by `docs.swift.org/swift-book/` via a custom integration.

### Options

The decision splits at whether the Research and Experiments corpora should be rendered through DocC at all. Two tracks:

- **Track 1 (Option 1) — Stay in DocC.** The current handoff direction. `docc merge` combines the three archives into one hosted site. Search options are variants 1a–1d.
- **Track 2 (Options 2+) — Mix chromes.** DocC kept at `/documentation/` (where it earns its chrome — the symbol-oriented main catalogue). Research and Experiments surfaced at `/research/` and `/experiments/` via a purpose-built dashboard treating each corpus as a database of documents rather than articles in a catalogue. Variants 2–4 differ in which dashboard technology.

Eliminated up front:

- **Fork swift-docc-render to extend `fuzzyMatch` + extend `RenderIndex` schema.** Requires maintaining a private `swift-docc` + `swift-docc-render` fork across toolchain bumps, rebuilding the render artifact (Vue + npm toolchain), and shipping the merged archive alongside a forked bundle. High ongoing cost; eliminated unless nothing else works.

### Track 1 — Stay in DocC

#### Option 1a — Ship with DocC's native title-only filter + QuickNavigation

Do nothing beyond the merge. The sidebar filter matches archive + article + (when symbol graphs exist) symbol titles, not body text. QuickNavigation (`/`) uses the same matcher. Cross-archive search works for titles only.

| | |
|---|---|
| Build cost | Zero. |
| Deploy change | Zero beyond merge itself. |
| UX delivered | Title-only search across all three archives. Nav + sidebar work. |
| UX missing | Body-text queries ("show me pages that mention `witness`") produce no hits. Research / Experiments corpora are especially affected — the signal in these documents is often in body prose, not titles. No facet filters by status / tier / toolchain. |
| Maintenance | None (tracks upstream DocC). |
| Reversibility | Trivial — overlay can be added any time without re-architecting. |

#### Option 1b — DocC merge + Pagefind post-build overlay

After `docc merge` + `docc process-archive transform-for-static-hosting`, run `pagefind --site <merged-output>`. Pagefind crawls the rendered HTML, produces `pagefind/` directory with Bloom-index buckets and chunk files. Add a small `<script>` + search input shim to the DocC shell via a build-time HTML injection step.

The DocC SPA is client-rendered — its HTML shell is almost empty at build time. Pagefind needs rendered HTML to crawl. Two paths:

1. Use DocC's `--experimental-transform-for-static-hosting-with-content` flag (verified in `Sources/DocCCommandLine/ArgumentParsing/Subcommands/Convert.swift`) to embed page content in each `documentation/<path>/index.html`. Pagefind crawls those directly.
2. If the experimental flag has gaps, run a one-shot headless-browser render (Playwright) of each `/data/documentation/<path>.json` URL into static HTML for Pagefind to crawl. More moving parts but fully controlled.

| | |
|---|---|
| Build cost | One-time overlay wiring: Pagefind CLI in CI, one invocation, one script tag injection, ~100 LOC JS for the search input UI (or use Pagefind's default modal). |
| Deploy change | Additional ~1–3 MB of index artifacts in `pagefind/`; single new build step. |
| UX delivered | Full-text search across all three archives; result snippets; typo tolerance. Still no structured filters — Pagefind surfaces text matches, not facets. |
| UX caveat | Pagefind's UI is not DocC-themed out of the box; accept mismatch, hide behind `Cmd+K` (DocC owns `/`), or theme it. |
| Maintenance | Pagefind is Rust (build-time only); stable API. The HTML-crawl approach does not depend on DocC's internal index shape — if DocC changes `RenderIndex`, the overlay does not care. |
| Reversibility | Trivial — remove the build step and the script tag. |

#### Option 1c — Custom JS overlay reading `--emit-digest` artifacts (rejected)

Emit `--emit-digest` per archive, post-merge script concatenates each archive's `indexing-records.json`, custom Lunr/MiniSearch UI consumes it.

Rejected on mechanism: `docc merge` does not copy `indexing-records.json` (fact 7). Reimplementing DocC's merge link resolution against an internal JSON format with no SemVer guarantee is the highest-maintenance of the four Track-1 options with no UX advantage over 1b.

#### Option 1d — Algolia DocSearch (discouraged)

Apply for OSS programme; Algolia's crawler scrapes the live site, serves search via their API.

Discouraged: external service, cross-origin, staleness until crawl runs, approval gate, misaligned with the "static site on GitHub Pages, no external service" posture. Low effort but gives up control of a core UX. Keep on the shelf if analytics on search queries becomes a requirement.

### Track 2 — Mix chromes (non-DocC for corpora, DocC for main catalogue)

The interlocutor's stated precedent is `swift.org/swift-evolution` — a Vue SPA over a JSON manifest, with status-pill filters and substring title search. It is "pathetically barebones, but at bare minimum still better than a static page." Three Track-2 variants differ in how much off-the-shelf framing we bring in.

#### Option 2 — swift-evolution-style dashboard (recommended Track-2 variant)

Shape:
- Build-time script scans `Research/` (frontmatter) and `Experiments/` (main.swift headers + `_index.md` rows + EXPERIMENT.md if present), emits `research.json` and `experiments.json` manifests at the site root. One entry per document / experiment directory: title, abstract, status, tier (for research), toolchain (for experiments), date, GitHub URL.
- A small SPA (Vue or vanilla JS, ~200–400 LOC) renders each corpus as a table with status/tier pills, sortable columns, and a search input.
- Client-side search via [MiniSearch](https://lucaong.github.io/minisearch/) or [Fuse.js](https://fusejs.io/) over title + abstract. Typo tolerance; substring matching; no external service.
- Each row links out to its GitHub source (markdown file for research, directory URL for experiments). No detail pages.
- Hosted at `/research/` and `/experiments/` on swift-institute.org alongside the DocC-rendered `/documentation/`. Shared CSS header (~50 LOC) for brand consistency.
- `_index.md` files continue to be the GitHub-browsable contracts.

| | |
|---|---|
| Build cost | Manifest generator (Swift script, ~150 LOC — deliberately in Swift to dog-food the ecosystem). SPA (~300 LOC JS/HTML/CSS). Shared header (~50 LOC). ~1–2 days end-to-end. |
| Deploy change | Two new CI jobs: generate manifests, build SPA. Deploy alongside DocC site. |
| UX delivered | Title + abstract search with typo tolerance. Status / tier / toolchain pill filters. Sortable columns. Matches swift-evolution precedent explicitly. |
| UX caveat | Visual divergence from DocC chrome — mitigated via shared header. No detail pages (rows link to GitHub) — a feature, not a bug, given the corpora's natural home is in the repo. |
| Maintenance | Low. Manifest generator is a directory scanner. SPA is static. No external service. |
| Reversibility | High — the DocC main catalogue is untouched; the dashboard is additive. |

#### Option 3 — Pre-built static site generator (MkDocs Material, Hugo, or Zola)

Drop the corpora into a batteries-included SSG with first-class search, sidebar navigation, tags, dark mode.

- **MkDocs Material** (Python) — best search UX of the three; good theming; excellent tag/facet support; active community.
- **Hugo** (Go) — fastest build; thinner default theming; large ecosystem.
- **Zola** (Rust) — simple, fast; smaller ecosystem; clean defaults.

| | |
|---|---|
| Build cost | ~half day to configure + theme. |
| Deploy change | New CI dep (Python + pip, or Go, or Rust). New build step per corpus. |
| UX delivered | Full-text search, sidebar nav, tags, dark mode out of the box. MkDocs Material's search is particularly strong. |
| UX caveat | Distinct theme from DocC — two-chrome site. Less control over row-level presentation than Option 2 (SSGs render pages, not tables). |
| Maintenance | Medium — theme divergence needs periodic reconciliation; CI depends on external tool version pins. |
| Reversibility | High — additive. |

#### Option 4 — Replace DocC across all three surfaces (discouraged)

Adopt a single SSG (MkDocs, Hugo, Zola, or custom) for `/documentation/`, `/research/`, `/experiments/`. Gains chrome consistency; loses DocC's symbol-oriented features (on-this-page navigator, type-aware cross-references, symbol-graph integration).

Discouraged: rewrites a working surface (the main catalogue) to fix a problem (search on two article corpora) that Option 2 or 3 solves more cheaply. Revisit only if DocC pain accumulates beyond the search gap.

### Track 3 — Fork DocC (or build our own renderer for DocC archives)

Three sub-variants. All three keep the DocC **archive format** (JSON-based `RenderNode`, `RenderIndex`, `IndexingRecord`) as the wire contract between compiler and renderer — a fork only touches the renderer and/or the CLI's merge path, not the archive format itself, so the existing `docc convert` output stays reusable.

#### Option 5a — Fork `swift-docc-render` to add full-text search

Smallest fork. Target two modifications to the Vue SPA at `swiftlang/swift-docc-render`:

1. Extend `fuzzyMatch` to also test `t.summary` and a new `t.content` field (populated from `IndexingRecord.rawIndexableTextContent` if emitted alongside the archive).
2. Extend `fetchIndexData` to optionally load an auxiliary `/search-index.json` (built from `indexing-records.json`) so the search input indexes bodies without having to walk per-page JSONs at runtime.

Still requires `swift-docc` backend work: patch `MergeAction.swift` to copy and combine `indexing-records.json` across source archives (the TODO at `MergeAction.swift:52` is adjacent). Alternatively, do the combine in our CI step and keep DocC untouched.

| | |
|---|---|
| Build cost | ~3–5 days for a working fork: Vue component patch, build new render artifact, CI wiring to combine indexing-records.json. |
| Deploy change | Private render-artifact repo pinned to a specific commit; CI uses our artifact, not Xcode-bundled. |
| UX delivered | Full-text search inside DocC chrome, with QuickNavigation + sidebar Filter both body-aware. Chrome consistency kept. |
| UX caveat | Our fork diverges from upstream. Every DocC upstream feature (new directive, new RenderNode field) requires a rebase or re-apply. |
| Maintenance | **High and ongoing.** Swift toolchain bumps every ~6 months carry new DocC + new render artifact. Our fork must track: Xcode bundles its own DocC, so falling behind means the artifact we ship is a reskin of an older renderer than users expect when they read swift.org documentation. |
| Reversibility | Expensive — once PRs onto the fork accumulate, reverting to upstream means re-writing the search feature on a new base. |
| Upstreaming | Possible. A well-scoped "enable full-text search" change (behind a feature flag, or via the existing `--emit-digest` artifact) would plausibly be accepted by the DocC team. If accepted, maintenance cost drops to zero. Effort: likely 2–4 weeks including upstream review cycle. |

#### Option 5b — Write a Swift-native renderer consuming DocC archives

Write an alternative SPA (or server-rendered static site) that reads standard DocC archives (`data/documentation/*.json`, `index/index.json`, `indexing-records.json` via `--emit-digest`) and produces its own HTML chrome — using the ecosystem's own packages (`swift-html`, `swift-markdown`, `swift-css-standard`, etc.) instead of Vue.

On-brand dogfooding. Swift Institute's stack is mature enough to render HTML documentation natively. `swift-html` produces statically-typed HTML; `swift-pdf-html-rendering` already composes with it. The renderer would be a Swift executable that walks the archive JSON and emits HTML files per page, plus a search index.

| | |
|---|---|
| Build cost | **Weeks-to-months.** DocC's `RenderNode` schema has ~80 node kinds (paragraph, heading, code block, step, aside, table, tutorial intro, call-to-action, row+column, tabs, links group, and many more). Each needs rendering logic. Symbol pages have availability blocks, platform tables, overloaded symbol groups. Navigation sidebar, on-this-page navigator, resolved link rewriting, theme. It is a large renderer. |
| Deploy change | New Swift executable in CI; builds the whole site from DocC archives. |
| UX delivered | Complete control: any UX we want (swift-evolution-style dashboards, facet filters, detail pages, full-text search, alternative navigation), inside a chrome we own. |
| UX caveat | Everything DocC's upstream renderer does must be re-implemented. Missing node kinds manifest as gaps until we hit them. |
| Maintenance | **Highest of all options.** Every upstream `RenderNode` addition is a silent gap in our rendering. Staying compatible with DocC's evolving schema is an indefinite commitment. |
| Reversibility | Medium — DocC archive format is stable; we can always go back to the upstream renderer for any archive. |
| Ecosystem fit | **Strongest of all options.** Uses swift-html, swift-markdown, swift-css-standard, swift-pdf, etc. — every component is a Swift Institute package eating its own dog food. Becomes both site infrastructure and a flagship demonstration of what the ecosystem is for. |

#### Option 5c — Upstream-first: contribute full-text search to swift-docc-render

The "do it right" variant. Contribute the search feature to `swiftlang/swift-docc-render` and `swiftlang/swift-docc` upstream as a PR, gated behind a feature flag so Apple's existing documentation is unaffected.

Design sketch: new CLI flag `--emit-full-text-index`, new `/search-index.json` with compact per-page indexed content, renderer checks for the file at load time and upgrades `fuzzyMatch` to body-aware when present.

| | |
|---|---|
| Build cost | ~1–2 weeks implementation + ~weeks–months upstream review + iteration. |
| Deploy change | None once accepted — we use stock DocC with the flag. |
| UX delivered | Same as Option 5a once merged. |
| UX caveat | Timeline is out of our control. Review may ask for significant redesign. May be declined outright — DocC's maintainers may prefer the current scope. |
| Maintenance | **Lowest of all options once upstreamed** — zero, tracks upstream. |
| Reversibility | N/A — upstream, not a fork. |
| Risk | Can fail in review, leaving us back at Options 1–4. Good path to start on, but do not wait for it as the only plan. |

### Comparison

| Criterion | 1a | 1b | 1d | 2 | 3 | 4 | 5a | 5b | 5c |
|-----------|:--:|:--:|:--:|:-:|:-:|:-:|:--:|:--:|:--:|
| | DocC as-is | +Pagefind | +Algolia | SPA dashboard | MkDocs | SSG all | Fork render | Swift renderer | Upstream PR |
| Full-text search | No | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes (if merged) |
| Facet filters | No | No | No | **Yes** | Yes (tags) | Yes (tags) | Possible | **Yes** | Possible |
| Swift-evolution shape | No | No | No | **Yes** | No | No | No | **Yes** | No |
| Matches stakeholder precedent | No | Partial | Partial | **Yes** | Partial | Partial | Partial | **Yes** | Partial |
| DocC kept at `/documentation/` | Yes | Yes | Yes | Yes | Yes | **No** | Yes | Yes | Yes |
| Architectural consistency | 1 | 1 | 1 + ext | 2 | 2 | 1 | 1 | 1 | 1 |
| Self-hosted | Yes | Yes | **No** | Yes | Yes | Yes | Yes | Yes | Yes |
| External dep | — | Pagefind | Algolia | — | Py/Go/Rust | Py/Go/Rust | Private fork | — | — |
| Coupling to DocC internals | None | None | None | None | None | None | **High** | **High** (archive schema) | None (via upstream flag) |
| Ecosystem dogfooding | — | — | — | Partial (Swift script) | — | — | — | **Strongest** | — |
| Estimated initial effort | 0h | 2–4h | 1–2h | **1–2d** | ~4h | 3–5d | 3–5d | weeks–months | 1–2w + review |
| Maintenance burden | None | Low | Low | Low | Medium | Medium | **High** | **Highest** | None (if merged) |
| Reversible | Yes | Yes | Yes | Yes | Yes | Expensive | Expensive | Medium | N/A |

### Contextualisation of the "gap"

Per [RES-021]'s contextualisation step, before classifying DocC's title-only search as a gap we should check whether the absence is deliberate. DocC's design frames the filter as navigation aid inside a symbol-oriented catalogue: when pages are Swift symbol docs, the title is usually the symbol name and the user's mental model is "jump to `Array.append(_:)`" not "find a page that discusses appending." Full-text indexing would inflate shipped artifacts and provide marginal value in the symbol-reference use case.

For swift-institute.org's merged site, however, two of the three sources — Research and Experiments — are article-only corpora where the signal is in prose, not symbol names. That shifts the use case closer to a docs site than a symbol reference and makes title-only search structurally insufficient. The "gap" is real for our use case, even if DocC's design choice is correct for its intended audience.

## Outcome

**Status**: RECOMMENDATION — pending user decision between two live tracks.

### Three live paths

The research leaves three reasonable directions. The choice is a judgement call between chrome consistency, search-UX fit, and long-term investment in our own rendering stack.

**If chrome consistency inside DocC matters and upstream change is not worth waiting for** → **Option 1b** (DocC merge + Pagefind overlay). Delivers full-text search across all three surfaces within a single chrome. ~2–4 hours of CI wiring after the merge lands. Maintains the handoff's "do it in DocC" direction. No fork, no wait.

**If stakeholder feedback is load-bearing and we want the most UX control soon** → **Option 2** (swift-evolution-style SPA at `/research/` and `/experiments/`, DocC retained at `/documentation/`). Delivers richer UX (facet filters + full-text search + sortable rows), matches the stated precedent, leaves the handoff's main-catalogue merge work unblocked. ~1–2 days for a polished dashboard.

**If full DocC-renderer parity with our own ecosystem matters** → **Option 5b** (Swift-native renderer consuming DocC archives). Long-term investment; weeks-to-months of work; maximum dogfooding (`swift-html`, `swift-markdown`, `swift-css-standard`). Yields complete control over chrome and UX across all three surfaces without losing the DocC archive format as input. Commit only if the ecosystem case outweighs the ongoing schema-tracking maintenance.

The three are not mutually exclusive. In particular: **Option 1b can ship now**, **Option 5c (upstream PR) can be pitched in parallel**, and **Option 5b can be the long game** — with 1b as the bridge until 5b (or an upstream merge) lands. Option 2 is the best stand-alone "one thing" if we want to pick a single direction.

### Do not pursue

- **Option 1c** (`--emit-digest` overlay). Couples to internal DocC JSON shapes and merge link resolution; no UX advantage over 1b or 2.
- **Option 1d** (Algolia). External service; misaligned with the "static site on GitHub Pages, no external service" posture. Only revisit if search-query analytics becomes a requirement.
- **Option 3** (pre-built SSG for corpora only). Theme divergence costs more than effort advantage saves over Option 2. Reconsider only if building a custom SPA feels disproportionate.
- **Option 4** (replace DocC everywhere with an SSG). Rewrites a working surface to fix a scoped problem. Revisit only if DocC pain accumulates beyond the search gap.
- **Option 5a** (private fork of swift-docc-render). High ongoing maintenance; less control than 5b; less leverage than 5c. Pick 5c if upstreaming is viable, 5b if it is not.

### Implications for the handoff

- The handoff's Phase 2 step "Add `Experiments.docc/` to Experiments root; add `Research.docc/` to Research root; extend deploy-docs.yml to clone + merge" is work only under Track 1. Under Track 2 these `.docc` catalogues are not built at all; instead the manifest generator + SPA replaces them.
- The Phase 2 merge wiring for the **main** swift-institute.org catalog is unaffected by the track choice. If the future brings a separate reason to merge additional DocC catalogs into the main site, the infrastructure from the experiment still applies.
- The experiment `docc-merge-multi-archive-hosting/` stays as-is regardless of track. Under Track 1 it is a dress rehearsal for the production merge; under Track 2 it is the evidence for why that merge is not the right chrome for these corpora specifically.

### Open questions that the chosen track would answer

| Question | Track 1 resolution | Track 2 resolution |
|----------|--------------------|--------------------|
| Article generation strategy for `.docc` catalogs | Hand-author landing + one article per corpus entry | N/A — no `.docc` catalogs |
| Hosting path layout | `/documentation/research/`, `/documentation/experiments/` | `/research/`, `/experiments/` (siblings of `/documentation/`) |
| Search implementation | Pagefind over rendered HTML | MiniSearch / Fuse.js over JSON manifest |
| Facet filters (status, tier, toolchain) | Not supported by DocC chrome | First-class dashboard feature |
| `_index.md` contract | Unchanged | Unchanged |

### Follow-up (regardless of track)

- `landing-page-docc-capabilities.md` row on `features.docs.quickNavigation.enable` is correct but implicit about what it toggles. Consider a one-line cross-reference to this document when it is next updated.
- Experiment header already records CONFIRMED for (a)+(b), REFUTED for (c) per [EXP-006].

### Notes if Track 1 is chosen

- Run `docc convert` on each source catalogue with `--experimental-transform-for-static-hosting-with-content` to embed page bodies in each `documentation/<path>/index.html`. Required for 1b's Pagefind to crawl rendered HTML directly.
- Match the macOS runner version (`macos-26`) and Swift 6.3 toolchain to the experiment to avoid the merge subcommand missing on older Xcode.
- After merge, archive-level `metadata.json` inherits the first archive's `bundleDisplayName` / `bundleID` (observed in the experiment: `"AlphaDocs"`). Pass the main swift-institute.org catalog as the first positional argument so the browser tab defaults to "Swift Institute".

### Notes if Track 2 is chosen

- Manifest generator: a small Swift executable scanning `Research/` (markdown frontmatter + first paragraph) and `Experiments/` (`main.swift` header comment parsing + `_index.md` row extraction). Deliberately in Swift so the ecosystem dog-foods itself. Output: `research.json` and `experiments.json` with stable schema.
- SPA: Vue + MiniSearch is the minimum viable shape. Vanilla JS + Fuse.js is the minimum viable *smaller* shape. Either is ~200–400 LOC.
- Status pills — harvest from existing status vocabulary: CONFIRMED / REFUTED / DEFERRED / SUPERSEDED / PARTIAL for experiments; DECISION / RECOMMENDATION / IN_PROGRESS / DEFERRED / SUPERSEDED for research. Tier pills for research: Tier 1 / 2 / 3.
- Each row's click target is a GitHub URL, not a local detail page. Avoids rendering bodies — the body lives in the repo.
- Hosting: `swift-institute.org/research/` and `/experiments/`. Deploy wired into the same `deploy-docs.yml`.
- Stakeholder-fit: the `Experiments/_index.md` and `Research/_index.md` tables become live, queryable views of the same data — which is what the interlocutor pointed to as the starting point.

## References

### Primary sources (local clones, verified 2026-04-17)

- `swift-docc` `edbc69a1`:
  - `Sources/SwiftDocC/Indexing/IndexingRecord.swift` — full-text record shape
  - `Sources/DocCCommandLine/Action/Actions/Convert/ConvertAction.swift:29, 85, 110, 351, 401–426` — `emitDigest` plumbing
  - `Sources/DocCCommandLine/Action/Actions/Convert/ConvertFileWritingConsumer.swift:177–178` — `indexing-records.json` write
  - `Sources/DocCCommandLine/Action/Actions/Merge/MergeAction.swift:52` — `// TODO: Merge the LMDB navigator index`
  - `Sources/DocCCommandLine/Action/Actions/Merge/MergeAction.swift:54–92` — directory whitelist, RenderIndex concat path
  - `Sources/DocCCommandLine/Action/Actions/IndexAction.swift` — nav index builder
  - `Sources/DocCCommandLine/ArgumentParsing/Subcommands/Convert.swift` — `--emit-digest`, `--emit-lmdb-index`, `--experimental-transform-for-static-hosting-with-content`
- `swift-docc-render-artifact` `6f911de`:
  - `dist/js/documentation-topic.aaf718ac.js` — only `.exec()` sites are `.exec(n)` and `.exec(t.title)`; `enableQuickNavigation` gate; `fetchIndexData` reads `/index/index.json`

### Prior research in the corpus

- `Research/landing-page-docc-capabilities.md` (RECOMMENDATION, 2026-04-15) — DocC article-level directive inventory, mentions `features.docs.quickNavigation.enable` toggle.
- `Research/documentation-docc-alpha-launch.md` (DECISION, 2026-04-15) — alpha launch content strategy.
- `Research/Reflections/2026-04-16-docc-landing-restructure-and-layers-show.md` — CI-equivalent build lesson applies to the Phase 2 pipeline.

### Experiment

- `Experiments/docc-merge-multi-archive-hosting/` — three article-only catalogs, `docc convert` → `docc merge` → `docc process-archive transform-for-static-hosting`. Acceptance: (a) + (b) CONFIRMED, (c) REFUTED (see Outcome notes).

### External

- Pagefind — `https://pagefind.app/`
- Swift Forums, combined documentation preview — `https://forums.swift.org/t/a-preview-of-doccs-support-for-combined-documentation/74373`
- Swift Forums, docbuild and merge multiple docc catalogs — `https://forums.swift.org/t/docbuild-and-merge-multiple-docc-catalogs/77013`
- swift.org/swift-evolution — custom, non-DocC dashboard.

### Handoff

- `/Users/coen/Developer/swift-institute/swift-institute.org/HANDOFF.md`
