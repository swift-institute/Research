# Documentation-estate audit: swift-standards + Workspace + Internal + Issues + Research

Whole-population survey, 2026-07-30. Read-only; no GitHub mutations, no files under
in the local Institute checkout modified. All counts carry their methodology. Exclusions
throughout: `.build`, `checkouts`, `.git`, `node_modules`, `.worktrees`, plus discovered
generated-state dirs `.workspace-build-*`/`.workspace-test-*` (Workspace build sandboxes that
duplicate package trees — 170 duplicate `ci.yml` copies live there) and `Experiments/` +
nested `Tests/Package.swift` packages.

## 0. Population definition (corrects the task's "28 package roots")

The tasking said 28 standards package roots. On disk the L2 population is larger: 28
top-level `swift-*-standard`-style roots **plus 80 packages nested one level under 12
authority roots** (`swift-ietf` 50, `swift-iso` 12, `swift-w3c` 6, `swift-whatwg` 2,
`swift-iec` 2, `swift-ieee` 2, and 1 each under `swift-arm-ltd`, `swift-ecma`,
`swift-incits`, `swift-intel`, `swift-linux-foundation`, `swift-microsoft`).

- **Package-root denominator: 108** — method:
  `find swift-standards -name Package.swift` with exclusions, minus `Experiments/` and `Tests/Package.swift`.
- Record trees: **Workspace 24 md / Internal 29 md / Issues 87 md / Research 630 md = 770
  files, 290,062 lines** (`find <tree> -name "*.md"` with exclusions + `wc -l`).
- Governance surfaces found in-slice: org checkout `swift-standards/.github`
  (org profile `profile/README.md`, org `metadata.yaml`, CONTRIBUTING/SECURITY), per-repo
  `.github/metadata.yaml` (110 files, method: `find -name metadata.yaml -path "*/.github/*"`),
  per-repo `.github/workflows/ci.yml` (108/108 roots).

**Critical structural fact the shared context underplays:** this is a multi-org estate.
Remotes and install snippets span at least 13 Institute orgs (`swift-standards`,
`swift-ietf`, `swift-iso`, `swift-w3c`, `swift-whatwg`, `swift-iec`, `swift-ieee`,
`swift-ecma`, `swift-incits`, `swift-arm-ltd`, `swift-intel`, `swift-linux-foundation`,
`swift-microsoft`), not one `swift-institute` org. Every org is a renameable coordinate
embedded in hundreds of documents.

## 1. Estate inventory

| Metric | Value | Method |
|---|---|---|
| Package roots | 108 | see §0 |
| Roots with README.md | 107/108 (missing: `swift-spm-standard`) | find README.md + awk join against root list |
| Roots with ≥1 `.docc` | 90/108 | `find -name "*.docc" -type d` + prefix join |
| Root README lines | total 13,549; min 18, p25 35, **median 92**, p75 209, **p90 267**, max 542 (`swift-incits-4-1986`) | null-safe `wc -l` over the 107 |
| READMEs ≤40 lines (minimum-family shape) | 43/107 | awk on line counts |
| Per-repo `metadata.yaml` | 110, **all** with `description:`, 109 with `readme.family` (107 `E`, 2 `G`) | find + grep |
| Repos with any local git tag | **1/108** (`swift-rfc-5890`) | `find -path "*/.git/refs/tags/*"` + packed-refs grep; remotes DO have tags (verified via API) — local checkouts don't fetch them |

**Template identification.** READMEs are template-skeleton, authored-body. Signature (line
frequency across the 107): `![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)`
in **105**; `## Installation` in 103; `dependencies: [` in 206 instances; placeholder
`name: "YourTarget"` in 77; `Apache 2.0. See [LICENSE.md](LICENSE.md).` in 46. Only 5
distinct >10-char lines appear in ≥50 READMEs — bodies are package-specific.
The template's authority is not ad hoc: **`Skills/documentation/readmes.md` is a ratified
README constitution** — family taxonomy resolved from `readme.family` in metadata, read by a
"centralized Swift repository-policy validator"; fixed badge vocabulary; fixed Platform
Support cell vocabulary; an explicit pin policy ("branch pin before the package has any tag,
a `from:` tag pin only once that tag exists"); an org-profile anti-enumeration rule; and an
admission that the shipped validator diverges from the prose in both directions.

## 2. Defect classes

### D1 — Manifest restatement (README prose restating Package.swift facts)

Denominator: 107 root READMEs. All manifests declare `swift-tools-version: 6.3.3` (108/108,
method: `head -1` over all manifests) and platforms `.macOS(.v26)`/`.iOS(.v26)` (108/107
occurrences via grep).

| Sub-class | Files | Live drift today? |
|---|---|---|
| Product names restated in install snippets (`.product(name:` self-references) | **101/107** files, 107 instances | **6 references in 5 READMEs name products that do not exist in the manifest** (awk getline containment join) |
| Swift-version claims | **58/107**; 41 claim "Swift 6.0", 9 claim "Swift 6.2" | **all ~50 contradict or understate the uniform 6.3.3 floor — wrong today** |
| Platform claims | **42/107** | claims cluster at macOS 13/14/15, iOS 16/18; only 7 say macOS 26 → **~35 wrong today** vs `.v26` manifests |
| `## Products`/`## Targets` sections | 4/107 | latent |

Exemplars:
- `swift-rss-standard/README.md:39` — `.product(name: "RSS", package: "swift-rss-standard")`; manifest declares `RSS Standard` (also `RSS iTunes` vs `RSS Standard iTunes`, `RSS Dublin Core` vs `RSS Standard Dublin Core`). Copy-paste fails resolution.
- `swift-stripe-types/README.md` — references product `Stripe Types`; not in manifest.
- `swift-css-standard/README.md:120-121` — "Swift 6.0+ / macOS 15.0+, iOS 18.0+…" vs 6.3.3/.v26.
- `swift-domain-standard/README.md:255-256` — "Swift 6.0+ / macOS 13.0+ / iOS 16.0+".
- `swift-ietf/swift-rfc-4648/README.md` — references product `RFC4648`; manifest spells it differently.

Severity: the version/platform sub-classes drift **on every toolchain/platform bump and are
already wrong fleet-wide**; product-name restatement is required by the ratified Installation
block (target clause), so it cannot simply be deleted — it needs a freshness check instead.

### D2 — Version-pin fragility in install snippets

Method: grep `from: "` / `exact:` / `branch:` over the 107; remote comparison via one
batched GraphQL query (51 aliased `repository{refs(refPrefix:"refs/tags/")}` lookups).

- `from: "x.y.z"` pins: **75 instances in 73 READMEs**; 27 distinct versions from 0.0.1 to 0.7.4.
- `branch: "main"` pins: **30 READMEs**. `exact:`: 0. Overlap from∩branch: 0 → 103/107 have exactly one pin style; 4 have none.
- Remote staleness (51 unique repo↔pin pairs where URL and pin co-located): **44 fresh
  (pin == latest remote tag), 1 stale, 4 pin a version on repos with NO tags, 2 pin
  a non-existent tag** → **7/51 (13.7%) broken or stale as published**.

Exemplars:
- `swift-w3c/swift-w3c-css/README.md:18` — `from: "0.3.0"`; remote's latest tag is 0.1.2. Resolution fails.
- `swift-w3c/swift-w3c-svg/README.md` — `from: "0.3.0"`; latest remote tag 0.1.0.
- `swift-ietf/swift-rfc-8259/README.md`, `swift-rfc-8446`, `swift-iso-21320`, `swift-w3c-epub` — pin `0.0.1`; repos have no tags at all (violates the ratified pre-tag branch-pin rule).
- `swift-ietf/swift-rfc-2387/README.md:30` — `.package(url: "https://github.com/swift-standards/swift-rfc-2387.git", from: "0.1.0")` — **stale org AND stale pin** (repo now under `swift-ietf`; latest 0.2.5).

Severity: drifts on every tag; 44 "fresh" pins decay silently with the next release. The
ratified branch→from transition has no mechanical trigger. Note the manifests themselves
compose via `branch: "main"` — the README `from:` style documents a mode the ecosystem
doesn't use internally.

### D3 — Reference fragility (renameable coordinates)

- Cross-repo `github.com/<org>/<repo>` references in the 107 READMEs: **348 instances across
  18 orgs** (top: swift-ietf 146, swift-standards 90, swift-iso 21, swift-foundations 19,
  **coenttb 16**, swift-w3c 14). Method: `grep -o 'github\.com/[^/]+/[^/)]+'` + org aggregation.
  Every one embeds two renameable display coordinates; the swift-rfc-2387 case proves org
  moves already happened without reference sweeps.
- **coenttb-org links: 16 instances in 11 READMEs** ("Related Packages" sections, e.g.
  `swift-domain-standard/README.md:250-251`) — references into the non-Institute personal org.
- Branch-relative deep links (`/blob/main|/tree/main`): **1**. Line-number anchors `#L<n>`: **0**. Good.
- Relative md links: **65** (fine on GitHub, break in DocC/SPI renderings; `swift-ieee-1003/README.md:173` `](./LICENSE.md`).
- CI badges: 40 READMEs; **0 point at missing workflows** (all 108 roots have
  `.github/workflows/ci.yml`), **but 37/40 use the deprecated name-addressed form**
  `…/workflows/CI/badge.svg` (breaks when the workflow's `name:` field changes); only 2 use
  the path-addressed `…/actions/workflows/ci.yml/badge.svg`. 67 roots have CI but no badge — uniformity gap.
- Record trees: **1,198 bare `#N` issue references vs 227 repo-qualified** (`org/repo#N`)
  across the 770 files (84% ambiguous outside their home repo). By tree: Research 1,049,
  Issues 107, Internal 30, Workspace 20. Method: grep `(^|[^&/a-zA-Z0-9])#[0-9]{1,4}\b` vs `[org]/[repo]#[0-9]+`.
- Display-name board references "*Institute Work*": **5 files** (Internal/README.md:9,
  UNIFORMITY-SWEEP-2026-07-28.md:463, SWEEP-FINDINGS-2026-07-28.md:202,
  SWEEP-COVERAGE-GAPS-2026-07-28.md:188, RULINGS-RETIREMENT-2026-07-28.md:130). Durable
  ProjectV2 coordinates (number/node id): **0 occurrences anywhere**. The #94 defect motif is
  systemic in the local records too.

Severity: latent until any rename/move — but moves have already occurred (rfc-2387), and the
multi-org constellation makes the blast radius programme-wide.

### D4 — Volatile inventories in prose

- Static status badge `status-active--development` asserted in **105/107 READMEs (106 incl.
  a non-root)** — a fleet-wide uniform status claim that is validator-mandated (readmes.md)
  yet carries no evidence and will require a fleet sweep the day any package leaves
  active development.
- Status/roadmap prose (`planned|under active development|not yet|currently …`): **7 READMEs, 11 lines**. Already stale:
  `swift-ietf/swift-rfc-9110/README.md:129-130` lists "RFC 9111 (planned: swift-rfc-9111)" and
  "RFC 9112 (planned: swift-rfc-9112)" — **both packages exist** in the tree today.
  `swift-rfc-6570/README.md:200` "under active development as part of the swift-standards project".
  `swift-ieee-1003/README.md:161` "swift-arguments (L3 foundations, planned)".
- Org profile (`swift-standards/.github/profile/README.md`): 28 table rows enumerating the
  org's packages with one-line roles + "swift-riscv (pending)" — a hand-maintained inventory
  that duplicates the Repositories tab and contradicts readmes.md's own anti-enumeration rule.
- Record trees: **356/770 files (46%)** use now-language (`currently|as of|for now|at present`);
  **631 count-in-prose instances** (`N packages/targets/repos…`). Workspace docs are clean of
  repo-count restatement (no "444" outside `Workspace.json`), but `TOOLCHAINS.md` hardcodes
  `6.3.3` in 8+ worked examples (drifts every toolchain bump).

### D5 — Boilerplate / emptiness

- Missing README: **1/108** (`swift-spm-standard`).
- **`.docc` estate is ~93% unauthored placeholder**: 90 catalogues; landing-file line
  distribution min 11 / median 11 / p90 11 / max 54. **84/90 contain the literal scaffold
  text** "umbrella catalog placeholder. Replace this line with a one-sentence description"
  followed by an **empty `## Topics`** (method: grep for the placeholder string). For AI
  readers this is worse than absence: it is a documentation-shaped surface with zero
  information that still costs a fetch and misleads coverage metrics ("90/108 have DocC").
- 6 authored catalogues: swift-rfc-6265, swift-iec-80000-13, swift-iso-80000-1,
  swift-iso-9945, swift-w3c-svg, swift-postgresql-standard (whose `StructuredQueries.md`
  appears vendored from upstream pointfree material — foreign doc in an Institute catalogue).
- Template-not-adapted READMEs: `name: "YourTarget"` scaffold text in **77** READMEs is
  by-design template filler in the target clause; not counted as defect but it is the
  copy-paste surface the product-name drift (D1) rides on.

### D6 — DocC curation fragility

- Disambiguation-hash symbol links (`-<hash>` suffixes): **0** estate-wide. Not a live problem.
- Signature-coupled symbol links (argument-label forms like ``Table(_:)`` /
  ``Column(_:as:primaryKey:)`` or nested paths like ``RFC_6265/Cookie/Pair``): **23 instances
  in 5 files** (the authored minority). Breaks on any signature change; small today because
  almost nothing is authored.
- All 90 landing files carry `## Topics`; in the 84 placeholders it is empty (no curation to
  restate). The `@DisplayName`/`@TitleHeading("Swift Standards")` metadata in every catalogue
  is another display-name surface.

### D7 — Duplication across surfaces

The "what is this package" sentence exists in ≥4 places with no mechanical link: README
prose, `.github/metadata.yaml` `description:` (bot-converged to the GitHub repo description),
the org-profile table role, and (nominally) the DocC landing abstract (placeholder today).
Measured README-first-prose vs metadata description (token-Jaccard): **exact 13, similar 29,
divergent 65 of 107 (61%)**. Method: python over metadata `description:` and first non-badge
prose line. Exemplars: swift-color-standard (metadata: "Unified Color type converting
between sRGB, CIE LAB, CIE LCH, Oklab, Oklch…" vs README: "Unified color representation for
Swift, composing CSS and display-profile specifications"); swift-domain-standard
(metadata names RFCs 1035/1123/5321; README says "multi-RFC" generically). Because the org
profile paraphrases a third time, an agent reading three surfaces gets three answers.

### Discovered classes

- **D8 — Stale-org/moved-repo coordinates:** `swift-rfc-2387` README installs from
  `swift-standards/` org while the repo lives under `swift-ietf/` (redirect-dependent). 16
  coenttb-org references are the same class pending any migration.
- **D9 — Machine-path leakage in records:** 6 files, 10 instances of `/Users/coen…` — all in
  `Internal/` (private repo per `gh repo view`: visibility private) → contained, but
  readmes.md explicitly bans home-directory paths in public docs; keep the check.
- **D10 — Space-bearing target/product names → space-bearing paths:** universal in
  standards (`Sources/JSON Feed Standard/JSON Feed Standard.docc/…`). Not wrong per policy,
  but it broke this audit's own first tooling pass and will break any naive agent script;
  fleet automation must be null-delimited/quoted, and the linter should own that discipline.

## 3. What already exists (governance to build on, not duplicate)

1. `Skills/documentation/readmes.md` — the authoring constitution: machine-resolved family
   (`readme.family`), badge and platform-cell vocabularies, pin policy, org-profile
   anti-enumeration, minimum/standard/complete structure ladder — **with a self-admitted
   validator/prose divergence** ("the shipped README validator is not a faithful
   implementation of the prose above").
2. `.github/metadata.yaml` per repo (110/110 with description) — the existing
   machine-readable identity layer the bot converges to GitHub; the natural SSOT for the
   identity sentence.
3. The **Issues tree is the positive exemplar of agent-first records**: per-issue
   `dossier-manifest.json` with `schemaVersion` and durable `canonicalObject:
   "swift-institute/Issues#5"`; READMEs that state "This directory is evidence for the
   canonical GitHub Issue, not a second status ledger"; dated re-verification sections with
   toolchain-stamped result tables.
4. `Research/_index.json` — generated, schema-versioned (`research-index-v1.json`) index over
   630 memos; prose inventories are already displaced by a generated artifact there.

## 4. Corrections to the first-pass draft (stress-test outcome)

- **Direction confirmed** (SSOT-per-fact, durable coordinates, generate-don't-restate; new
  Goal rather than #79 scope injection — nothing found here contradicts that disposition).
- **"Sampled" anecdotes → fleet facts:** manifest restatement is not occasional; it is the
  template itself (101/107 product restatement; ~50 wrong Swift floors; ~35 wrong platform
  claims; 7/51 broken pins).
- **The draft misses the existing constitution.** readmes.md + metadata families + the
  policy validator already own README form; the new Goal must *evolve that instrument* (and
  close its admitted prose/validator gap), not stand up a parallel standard. Removing status
  badges, as the draft proposes, would violate the current ratified minimum — that change is
  a supersession decision, not a cleanup.
- **DocC emphasis misplaced:** zero disambiguation hashes exist; the real DocC decision is
  **complete-or-delete 84 placeholder catalogues**. Placeholder text telling authors to
  replace it is anti-content for an AI-only readership.
- **Multi-org reality:** "the org swift-institute" understates the surface — 13+ Institute
  orgs appear in install coordinates; reference-durability policy must treat org names as
  the most consequential renameable display name in the estate.
- **Records side has the same disease as #94:** 1,198 bare `#N` vs 227 qualified refs; 5
  "Institute Work" display-name refs; 0 durable ProjectV2 coordinates.

## 5. Top 5 highest-leverage mechanical fixes for this slice

1. **Manifest-facts freshness check (kills D1 live drift).** A Workspace/linter predicate
   that parses each root README's Installation block + Requirements bullets and compares
   product names, Swift floor, and platform floors against the evaluated manifest
   (fail-closed, fixture-backed per #90). Fixes today: 6 wrong product refs, ~50 wrong Swift
   claims, ~35 wrong platform claims — and prevents the next toolchain bump from silently
   re-breaking 107 files. (Cheapest variant: stop stating Swift/platform floors in prose
   entirely; the manifest states them.)
2. **Pin-reality check (kills D2).** Same predicate family: a `from:` pin must equal an
   existing tag (and flag when a newer tag exists); a `branch:` pin is allowed only while
   the repo has no tags — this rule is already ratified in readmes.md, so this is pure
   enforcement. Fixes 7 broken/stale pins now; converts 30 branch-pins at the moment each
   repo first tags.
3. **Reference-coordinate sweep + lint (kills D3/D8 cheaply).** One mechanical pass
   rewriting `github.com/<org>/<repo>` references against the Workspace.json repo inventory
   (catches moved repos like rfc-2387 and coenttb strays), converting the 37 name-addressed
   badge URLs to path-addressed form, and — in record trees — requiring `org/repo#N` for any
   issue reference that leaves the current repo (1,198 candidates, auto-qualifiable from
   context in most cases).
4. **Complete-or-delete the 84 placeholder .docc catalogues (kills most of D5/D6).**
   Either generate a real one-sentence abstract from `metadata.yaml`'s description at
   catalogue-build time, or remove the catalogue until authored content exists. An empty
   `## Topics` plus "Replace this line…" must not ship on any surface an agent fetches.
5. **Single identity sentence (kills D7).** Declare `metadata.yaml.description` the SSOT for
   the package one-liner; generate the README first line and DocC abstract from it (or lint
   equality), and replace the org-profile 28-row hand table with the readmes.md-sanctioned
   filter-links + small curated "Start here" set. Fixes 65 divergent identities and removes
   the org profile's volatile inventory.

Every fix above is enforcement or generation attached to instruments that already exist
(Workspace evaluation, the repository-policy validator, metadata.yaml, the bot) — none
requires new prose doctrine beyond ratifying the checks, which supports the draft's
"new Goal, doctrine-and-instruments-first" disposition.
