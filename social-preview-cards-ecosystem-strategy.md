# Social Preview Cards Ecosystem Strategy

<!--
---
version: 2.0.0
last_updated: 2026-05-07
status: DECISION
tier: 2
scope: ecosystem-wide
changelog:
  - 2026-05-07 (v2.0.0): Promoted RECOMMENDATION → DECISION. Implementation
    pivoted from Option B (CI-generated + maintainer manual upload, with
    PNG committed to each repo) to a hybrid: Option A's mechanism
    (Playwright + session cookie) but run LOCALLY on a maintainer's
    machine, never in CI. PNG is NOT committed (treated as derived state).
    Added Implementation Outcome section. Operationalised in
    Skills/social-preview/SKILL.md.
  - 2026-05-07 (v1.0.0): Initial RECOMMENDATION (Option B).
---
-->

## Context

GitHub repositories expose a "Social preview" image (Settings → General → Social
preview) that overrides the auto-generated thumbnail when the repo URL is
shared on Twitter/X, LinkedIn, Slack, Discord, iMessage, Facebook, etc. The
ecosystem currently spans 130+ public-facing repositories across the Primitives
(L1), Standards (L2), Foundations (L3), Components (L4), and Institute org-of-orgs
tiers; today, every repo ships GitHub's default auto-generated card
(owner-avatar + name + description + stats on a white card with an orange rule).

Two prior research artifacts inform scope:

1. `github-metadata-harmonization.md` (2026-04-29) reserved "social preview
   images" as a future surface in §13's enumeration of out-of-scope-but-tracked
   GitHub repo affordances. This document operationalizes that future surface.
2. The existing centralized `swift-institute/.github/.github/workflows/sync-metadata.yml`
   reusable workflow handles description/homepage/topics propagation via
   `gh repo edit`. The natural question is whether social preview images can
   ride the same chassis.

The brand language is established: four tier avatars at
`swift-institute.org/avatars/` (primitives bronze, standards silver,
foundations gold, institute capstone) implementing a four-bar pyramid composition
where the gradient bar's vertical position encodes tier (bottom = base layer,
top = capstone). The primitives card's gradient is the bottommost bar; the
institute card inverts it as a capstone. This is a strong, already-shipping
visual chassis to extend into per-repo social preview cards.

## Question

Can the swift-institute ecosystem deploy custom social preview cards across
all 130+ repositories via a centralized CI/CD pipeline (mirroring the
metadata-harmonization model), and if so, what design and what mechanism
should the pipeline produce and deploy?

Sub-questions:

1. **Capability**: Does GitHub expose a token-authenticated API path for
   uploading social preview images that a reusable workflow can call?
2. **Spec**: What are the hard constraints (dimensions, format, file size,
   safe area) the generated card must satisfy?
3. **Design**: What card composition fits the ecosystem brand and is
   resilient to downstream re-cropping (Twitter/X, LinkedIn, Slack, iMessage)?
4. **Prior art**: What design patterns have mature OSS ecosystems converged on?
5. **Strategy**: Given the capability finding, what is the recommended
   deployment shape (full automation, generation-only with manual upload,
   or no-customization)?

## Analysis

### Hard constraints (verified primary sources) [Verified: 2026-05-07]

| Property | Value | Source |
|---|---|---|
| Recommended dimensions | 1280 × 640 px (2:1) | GitHub Docs |
| Minimum dimensions | 640 × 320 px | GitHub Docs |
| Accepted formats | PNG, JPG, GIF | GitHub Docs |
| Max file size | < 1 MB | GitHub Docs |
| GitHub-recommended safe-area inset | 40 pt border around critical content | GitHub's downloadable Repo Card Template |
| Fallback when missing | Auto-generated card with owner avatar + name + description + stats | GitHub Docs |
| README `og:image` honored as fallback for `github.com` URLs? | **No** | GitHub Docs |
| GitHub injects own `og:image` / `og:title` / `og:description` / `twitter:card="summary_large_image"` for `github.com/<owner>/<repo>` URLs? | **Yes**, the uploaded preview is the value of `og:image`; cannot be overridden externally for github.com URLs | OpenGraph Protocol; GitHub Docs |

**Concrete safe-area for ecosystem cards** [synthesis]: Keep all logos,
wordmarks, and text inside a **1200 × 540 px rectangle centered on the canvas
(70 px top/bottom, 40 px left/right inset)**. This survives both GitHub's
40 pt template border *and* a 1.91:1 LinkedIn / Facebook center-crop (which
clips ~32 px top/bottom of a 1280 × 640 source).

**Minimum effective font size** [synthesis]: 48 px on the 1280 × 640 canvas.
Twitter/X timeline thumbnails render the card at ~504 px wide → 48 px source
becomes ~19 px on screen. Anything smaller is illegible at thumbnail.

### Capability finding (the load-bearing claim) [Verified: 2026-05-07]

**GitHub does NOT expose a public, token-authenticated API for SETTING a
repository's social preview image.** The "leverage centralized CI/CD"
framing has a hard ceiling at the upload step.

Evidence by vector:

| Vector | Result |
|---|---|
| `PATCH /repos/{owner}/{repo}` (REST) | No `social_preview` / `open_graph` / `image` field accepted. ([REST repos reference](https://docs.github.com/en/rest/repos/repos)) |
| GraphQL `Repository.openGraphImageUrl` | **Query-only**. No mutation exists to set it. ([GraphQL Mutations reference](https://docs.github.com/en/graphql/reference/mutations)) |
| `gh repo edit` flags | description, homepage, topics, merge/branch settings, visibility — no social-preview flag. |
| GitHub staff confirmation | KaloudasDev (2025-09-04), [Community Discussion #172072](https://github.com/orgs/community/discussions/172072): *"Currently, there is no public GitHub API endpoint available to update a repository's social preview image."* |
| README `og:image` fallback | Not honored for github.com URLs. |
| Undocumented `/upload/repository-images/...` endpoint | Exists but is **session-cookie-authenticated** (`user_session` cookie), not PAT/App-token. Two known tools exploit it: [`AnswerDotAI/gh-social-preview`](https://github.com/AnswerDotAI/gh-social-preview) (Playwright + saved session) and [`drogers0/gh-image`](https://github.com/drogers0/gh-image) (reads `user_session` from browser cookie store). The `user_session` cookie is **password-equivalent — full account access, not PAT-scoped.** |

**Implication**: `GITHUB_TOKEN`, fine-grained PATs, and the existing
`swift-institute-bot` GitHub App installation token **cannot** push social
preview images. Every centralized-pipeline path requires either (a) headless
browser automation with a stored `user_session` cookie (account-scoped,
password-equivalent, brittle to UI changes — incompatible with
`feedback_no_gh_cli_admin_scope.md` posture), or (b) per-repo manual web UI
upload.

### Prior art survey [RES-021]

19 repos surveyed across Apple Swift, swiftlang, Vapor, Point-Free,
ChartsOrg, Realm, Quick, rust-lang, tokio-rs, Vercel, Supabase, Stripe.
Provenance signal: `og:image` host — `repository-images.githubusercontent.com/...`
indicates a custom upload; `opengraph.githubassets.com/<sha>/...` indicates the
GitHub auto-generated default.

| Repo | Card type |
|---|---|
| swiftlang/swift | auto |
| apple/swift-collections | auto |
| swiftlang/swift-syntax | auto |
| apple/swift-numerics | auto |
| swiftlang/swift-foundation | auto |
| apple/swift-nio | auto |
| apple/swift-system | auto |
| **vapor/vapor** | **custom** |
| **vapor/fluent** | **custom** |
| pointfreeco/swift-composable-architecture | auto |
| pointfreeco/swift-dependencies | auto |
| ChartsOrg/Charts | auto |
| realm/SwiftLint | auto |
| Quick/Quick | auto |
| rust-lang/rust | auto |
| tokio-rs/tokio | auto |
| **vercel/next.js** | **custom** |
| **supabase/supabase** | **custom** |
| stripe/stripe-node | auto |

**Adoption rate of custom previews: 4/19 (21%).** Zero of 15 surveyed Swift
repos use a custom preview. The entire Apple/Swiftlang ecosystem,
Point-Free, ChartsOrg, Realm, Quick, rust-lang, tokio, and Stripe ship
GitHub defaults. Apple's choice across the Swift surface is the dominant
signal: custom preview cards are **not table-stakes** for serious
infrastructure OSS.

**Card composition of the four customs**:

- **vapor/vapor + vapor/fluent** — identical chassis: deep-navy → deep-purple
  gradient background; centered isometric "cube" mark (white top face, layered
  cyan stripes left, layered magenta stripes right); single-word wordmark
  ("Vapor", "Fluent") in heavy white sans below. Only the cube's top-face glyph
  and the wordmark vary across the two repos. **Org-wide ecosystem template
  with a glyph + wordmark slot.**
- **vercel/next.js** — minimalist near-white background with faint
  construction guides; black circular monogram badge with the "N" mark
  top-center; two-line headline tagline below. No repo name. Pure product
  positioning.
- **supabase/supabase** — pure black canvas, left half logo + wordmark +
  two-line tagline ("Build in a weekend. / Scale to millions."), right half
  product screenshot framed with green border.

### Patterns observed

1. **Default-is-fine majority (15/19, including all 15 surveyed Swift repos).**
   Apple's surface across swiftlang and apple orgs ships defaults. The org
   avatar carries the brand work; the repo card is informational.
2. **Ecosystem template with per-repo glyph slot (Vapor pattern).** A single
   visual chassis (gradient + mark + heavy wordmark) is reused across every
   package; only the glyph and wordmark change. Maximum brand cohesion at
   minimum per-repo authoring cost. Closest analog to a swift-institute
   family card.
3. **Product-tagline pattern (Vercel, Supabase).** Commercial OSS leans into
   positioning copy, not repo identifier. Less applicable for an
   infrastructure-grade research institute.
4. **Background convention: dark-OR-near-white, never mid-tone.** All four
   surveyed customs follow this. Brand-color flood-fill backgrounds are
   *not* observed.

### Why universal adoption is absent ([RES-021] contextualization)

[RES-021]'s contextualization step requires evaluating *what universal adoption
of a missing pattern would cost in our type system / posture.* For social
preview cards the absence is mostly explained by GitHub's API gap making
the deployment cost high enough that it's only worth bearing for marketing
surfaces with a strong product narrative (Vercel, Supabase, Vapor's brand
identity) — not for infrastructure libraries where the org avatar already
carries the brand. Apple shipping defaults across 100+ Swift repos is
strong direct precedent that custom cards are not a quality signal for
research-grade infrastructure.

### Options for the swift-institute ecosystem

#### Option A — Full automation via session-cookie headless browser

Generate cards in a centralized workflow; deploy via Playwright + stored
`user_session` cookie of a bot account or a maintainer.

| Criterion | Assessment |
|---|---|
| Achievability | Possible; both [`AnswerDotAI/gh-social-preview`](https://github.com/AnswerDotAI/gh-social-preview) and [`drogers0/gh-image`](https://github.com/drogers0/gh-image) demonstrate the path. |
| Auth posture | **Hard fail.** `user_session` cookie is password-equivalent (full account access; not PAT-scoped). Storing it in CI secrets violates `feedback_no_gh_cli_admin_scope.md` ("admin-class GitHub ops via web UI ONLY") in spirit — the cookie carries broader privilege than `admin:org`. |
| Brittleness | UI-cookie schemes change without notice; tooling regularly breaks on GitHub redesigns. |
| Reversibility | High — uploaded cards can be removed manually. |
| Verdict | **REJECT**. Auth posture incompatible with the ecosystem's no-admin-CLI doctrine. |

#### Option B — Generation in CI, manual one-time upload per repo

A reusable workflow renders a per-repo card from the institute chassis,
commits the PNG to `.github/social-preview.png` in each repo, and the
generation runs nightly + on metadata change. Per-repo first-time deployment
is a manual web UI upload by a maintainer (one-time, ~130 repos), documented
in the repo onboarding runbook.

| Criterion | Assessment |
|---|---|
| Achievability | High. Image generation is straightforward (SVG template + per-repo metadata.yaml → PNG via `rsvg-convert` / `librsvg` / `resvg`). |
| Auth posture | Compatible with no-admin-CLI doctrine. The committed PNG path uses the existing GitHub App token. The upload itself is web UI. |
| Drift handling | Generation pipeline detects template/metadata changes and updates the committed PNG; maintainers receive a notification when a card is updated, prompting re-upload. Cadence is low (template changes are rare). |
| Per-repo first-time cost | One drag-and-drop per repo (~30 sec each, ~1 hr total for 130 repos). |
| Reversibility | High. |
| Verdict | **VIABLE**. Closest to the user's vision within the API constraint. |

#### Option C — Generation only, no deployment (asset-shop posture)

A centralized workflow generates and commits cards to each repo at
`.github/social-preview.png`; no upload step is part of the
"infrastructure". Maintainers upload at their discretion.

| Criterion | Assessment |
|---|---|
| Achievability | Identical to Option B's generation step. |
| Effective brand cohesion | Lower than B (cards exist as files but don't appear in GitHub previews until uploaded). |
| Maintenance | Lowest — no manual step formalized. |
| Verdict | **VIABLE as Option B's degenerate form**. Effectively Option B with the per-repo upload step deferred. |

#### Option D — No customization (Apple posture)

Ship GitHub defaults across the ecosystem. Rely on the org avatar (already
established per `swift-institute.org/avatars/`) for brand cohesion at the
org-page level; let GitHub's auto-generated card carry repo-level identity.

| Criterion | Assessment |
|---|---|
| Achievability | Trivial (no work). |
| Effective brand cohesion | Medium — the org avatars already render in GitHub's auto-card next to the repo name. The auto-card includes the avatar, name, description, language, and stats. |
| Precedent | Strong (15/19 surveyed, 15/15 Swift). |
| Verdict | **DEFENSIBLE**. The dominant pattern for infrastructure OSS. |

### Comparison

| Criterion | A: Cookie-auto | B: Gen + manual upload | C: Gen only | D: No custom |
|---|---|---|---|---|
| Eco-wide brand cohesion | High | High | Low | Medium |
| Time-to-deploy per repo | Auto | ~30 s | 0 (no upload) | 0 |
| Auth-posture compatibility | **Fails** | OK | OK | N/A |
| Brittleness | High (UI changes) | Low | Low | None |
| Drift handling | Auto | Auto-generated, manual re-upload on change | Auto-generated, no re-upload | N/A |
| Aligns with prior-art majority | No | Vapor-aligned (4/19) | n/a | Apple-aligned (15/19) |
| Recommended? | **No** | **Yes (primary)** | Yes (fallback) | Yes (status quo) |

## Outcome

**Status: DECISION** (v2.0.0, 2026-05-07)

**Implemented**: hybrid path — Option A's mechanism (Playwright session-cookie
upload to the undocumented `/upload/repository-images/...` endpoint) **run
locally on a maintainer's machine, never in CI**. Sidesteps Option A's auth
rejection by keeping the password-equivalent cookie on the maintainer's laptop
(same security envelope as opening Settings → Social preview manually); the
generation+upload pipeline is `swift-institute/Scripts/social-preview.sh` +
vendored uploader at `Scripts/social-preview-uploader/upload.js` (forked from
`AnswerDotAI/gh-social-preview` to accept `--image`). PNG is **not** committed
to target repos — derived state, regenerable from chassis + org metadata + repo
name.

**Why not the v1.0.0-recommended Option B**: Option B's value-add over D was
"committed PNG as canonical asset"; in practice the committed PNG is dead
weight (every repo grew an extra binary file the maintainer never references)
and creates a two-source-of-truth drift surface (committed PNG vs. uploaded
og:image). Local-only render+upload preserves the brand cohesion goal at lower
maintenance cost.

**Deployed (2026-05-07)** across 9 orgs:

| Org | Brand | Public swift-* repos uploaded |
|---|---|---|
| swift-primitives | bronze / PRIMITIVES | (initial canary; ~60 repos) |
| swift-foundations | gold / FOUNDATIONS | 4 |
| swift-standards (umbrella) | silver / STANDARDS | 18 |
| swift-ietf | silver / STANDARDS | 44 (RFC + BCP) |
| swift-iso | silver / STANDARDS | 7 |
| swift-ieee | silver / STANDARDS | 1 |
| swift-iec | silver / STANDARDS | 1 |
| swift-w3c | silver / STANDARDS | 4 |
| swift-whatwg | silver / STANDARDS | 2 |
| swift-incits | silver / STANDARDS | 1 |

**Deferred from v1.0.0 recommendation** (no longer relevant):

- ❌ Reusable workflow `generate-social-preview.yml` in
  `swift-institute/.github/.github/workflows/` — never written; no CI step.
- ❌ Committed `.github/social-preview.png` per repo — explicitly forbidden
  by [SOC-006] in the operational skill.
- ❌ `lint-social-preview-staleness.yml` linter comparing committed vs. served
  hash — only matters with committed PNG, which we don't.

**Standing, from v1.0.0**:

- ✓ Single parametric chassis at `swift-institute/.github/social-preview/`.
- ✓ Tier-coloured gradient + 4-bar pyramid glyph, varying via accent colors
  declared in each org's `.github/metadata.yaml` `socialPreview` block.
- ✓ Display name resolves from per-repo override → mechanical kebab→display
  derivation (now with authority-code uppercasing, acronym expansion, and
  IPv4/IPv6 special cases per [SOC-004]).

**Cards rendered & uploaded** at this point: 80+. Operational state is
captured in `Skills/social-preview/SKILL.md` (canonical day-to-day reference);
this research document remains the strategic context.

---

### Pre-implementation analysis (preserved as authored 2026-05-07 v1.0.0)

**Original recommendation — Option B (Generation in CI, manual one-time upload per repo):**

Build a centralized reusable workflow `generate-social-preview.yml` in
`swift-institute/.github/.github/workflows/` (alongside `sync-metadata.yml`)
that:

1. Reads each repo's `.github/metadata.yaml` to determine **tier** (L1/L2/L3/L4)
   and **display name** (typically the package's primary namespace, e.g.
   `Buffer`, `Path`, `RFC_4122.UUID`).
2. Selects the matching tier chassis from a per-tier SVG template authored
   from the existing `swift-institute.org/avatars/avatar-{primitives,standards,foundations,institute}.svg`
   visual language (4-bar pyramid + tier-coloured gradient bar in the
   tier-appropriate position; bronze L1 / silver L2 / gold L3 / capstone for
   institute-org-of-orgs surfaces).
3. Substitutes the display name into the chassis's wordmark slot.
4. Renders to PNG at 1280 × 640 via `resvg` or `rsvg-convert` (single-binary,
   container-friendly), verifies file size < 1 MB, and commits to
   `.github/social-preview.png` in the target repo via the existing
   `swift-institute-bot` GitHub App.
5. Runs on nightly cron + manual `workflow_dispatch` + on-push to the chassis
   templates in `swift-institute/.github`.

**Card composition** (canvas 1280 × 640; safe area 1200 × 540 centered):

| Region | Content |
|---|---|
| Background | Tier-tinted off-white (`#fbf8f6` matching the existing avatars), or solid dark variant if needed for thumbnail contrast (decided in design follow-up). |
| Left third | Tier glyph: scaled 4-bar pyramid from the tier avatar (gradient bar in tier-correct position). |
| Right two-thirds | Repo display name in heavy sans (≥ 72 px), optional one-line description below in lighter weight (≥ 48 px). |
| Bottom rule | 4 px tier-gradient bar spanning the safe-area width (visual continuity with the avatars). |

**Per-repo first-time deployment**: documented in the repo onboarding runbook
(forthcoming `Skills/github-repository/social-preview-deployment.md` or as
a section appended to the existing skill). Drag-and-drop the committed PNG
into Settings → Social preview. ~30 sec per repo; one-time. The 130-repo
backfill is one focused session, not infrastructure.

**Drift handling**: Nightly workflow detects template / display-name changes
and re-commits the PNG. A separate `lint-social-preview-staleness.yml`
linter (matching the `lint-readme-presence` style) compares the committed
PNG hash against the GitHub-served `og:image` hash via WebFetch and posts
a status check when they diverge. Maintainers re-upload when notified
(low cadence — chassis changes are rare).

**Secondary fallback — Option C (Generation only)**: If the per-repo manual
upload backfill is deferred indefinitely, Option B degenerates gracefully
into Option C. The committed PNG is still useful as a canonical asset
referenced from documentation, blog posts, the swift-institute.org site,
and so on.

**Default-keep — Option D (no customization)**: Acceptable status quo if
the institute decides the brand work is already carried sufficiently by the
org avatars. Apple's posture across the entire Swift ecosystem is direct
precedent. **This is not a quality regression.** The upgrade from D to B is
a brand-cohesion improvement, not a correctness fix.

**Rejection — Option A (cookie automation)**: Incompatible with the
ecosystem's no-admin-CLI auth posture per `feedback_no_gh_cli_admin_scope.md`.
Storing a `user_session` cookie in CI secrets is broader-privilege than
`admin:org` and is explicitly out-of-bounds. Do not adopt.

### Rationale anchors

- The user's framing assumed centralized CI/CD upload was possible; the
  empirical [RES-023] finding is that it is not (under acceptable auth
  posture). The recommendation preserves the spirit of the framing
  (centralize generation, single-source-of-truth chassis) within the
  capability ceiling.
- The Vapor pattern is the strongest prior-art precedent: an ecosystem-wide
  template with a per-repo glyph + wordmark slot, applied across every
  package. The institute's existing tier avatars already encode the
  glyph axis (bronze/silver/gold pyramid); the per-repo wordmark is the
  one variable.
- Apple's choice to ship GitHub defaults across the entire Swift surface
  is the strongest data point that custom cards are *not* a quality bar
  for research-grade infrastructure OSS. Option B is a brand-cohesion
  enhancement, not a correctness requirement; Option D remains
  defensible.

### Implementation gates

Per `feedback_no_public_or_tag_without_explicit_yes.md` and the user's
per-action authorization rule:

- Authoring the reusable workflow + chassis SVG templates in
  `swift-institute/.github` is in scope for a follow-up dispatch (not this
  research session).
- The per-repo backfill (manual upload across 130+ repos) requires explicit
  per-action authorization.
- A `Skills/github-repository/social-preview-deployment.md` page formalizing
  the onboarding-runbook step is a downstream skill update.

### Open questions for the implementing dispatch

1. **Background variant** — off-white (matches existing avatars) or solid
   dark (better thumbnail contrast in Slack/Discord dark mode)? Two-variant
   render is cheap; choose default at template authoring time.
2. **Display-name source** — `metadata.yaml.displayName` (already exists),
   or derive from the package's primary namespace via SwiftPM dump?
   `metadata.yaml.displayName` is the cheaper path; the latter is more
   robust to namespace renames but needs build-step parity.
3. **Multi-target packages** — for packages with multiple products (e.g.,
   swift-linter has engine + rule packs + primitives), is the card
   identified by the package name or by a curated headline product?
4. **Cohort tier display** — packages in transitional/cohort tiers
   (Components L4 not yet uniformly defined) — what tier gradient applies?
   Default to the dependency-deepest tier, matching the existing
   `compute-tiers` script.
5. **Institute-internal repos** (Skills, Audits, Blog, Swift-Evolution,
   Scripts — private) — do they get cards? Per
   `feedback_private_repos_no_ci_runs.md` they have zero CI signal
   currently, but `og:image` for private repo URLs is rendered when
   shared to maintainers; the chassis is cheap to apply. Recommend
   institute-tier capstone chassis for these.

## References

- [Customizing your repository's social media preview — GitHub Docs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)
- [GitHub REST API: repos](https://docs.github.com/en/rest/repos/repos)
- [GitHub GraphQL API: Mutations](https://docs.github.com/en/graphql/reference/mutations)
- [GitHub Community Discussion #172072 — staff "no public API"](https://github.com/orgs/community/discussions/172072)
- [GitHub Community Discussion #52294](https://github.com/orgs/community/discussions/52294)
- [GitHub Community Discussion #49928](https://github.com/orgs/community/discussions/49928)
- [AnswerDotAI/gh-social-preview (Playwright + saved session)](https://github.com/AnswerDotAI/gh-social-preview)
- [drogers0/gh-image (browser cookie store)](https://github.com/drogers0/gh-image)
- [The Open Graph Protocol](https://ogp.me/)
- Internal: `swift-institute/Research/github-metadata-harmonization.md` (2026-04-29) §13 — reserved-future-surface enumeration
- Internal: `swift-institute/.github/.github/workflows/sync-metadata.yml` — chassis precedent for per-repo metadata propagation
- Internal: `swift-institute.org/avatars/avatar-{primitives,standards,foundations,institute}.svg` — ecosystem brand language
