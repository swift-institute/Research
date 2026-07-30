# Documentation-estate audit: swift-foundations (L3, 141 package roots)

Whole-population survey (no sampling) of `swift-institute/swift-foundations`.
All counts exclude `.build`, `checkouts`, `.git`, `node_modules`, `.worktrees`. GitHub access was read-only
(`gh api GET`, `git ls-remote`). Date: 2026-07-30.

**Headline: 136 of 141 READMEs (96.5%) carry at least one mechanically detectable defect.**
Union computed over: branch-pin ∪ from-pin ∪ coenttb-org link ∪ status badge ∪ name-based CI badge ∪ broken
LICENSE link ∪ Swift-version mismatch vs manifest.

---

## 1. Estate inventory

| Fact | Value | Methodology |
|---|---|---|
| Package roots | 141, every one has `Package.swift` and `README.md` (0 missing) | `for d in */; do [ -f "$d/Package.swift" ] && ...` |
| Nested sub-packages (excluded from denominators) | 7 (`*/Tests/Package.swift` ×6, `swift-linter/Runner` ×1) | `find . -maxdepth 3 -name Package.swift` |
| README length | min 13, median 109, p75 180, p90 298, p95 402, max 915 lines; mean 152; total 21,461 | `wc -l` per README, awk percentiles |
| Shortest / longest | swift-metrics, swift-scheduler (13); swift-records (915) | sorted list |
| Manifest toolchain | **uniformly `swift-tools-version: 6.3.3` in all 141** | `head -1 */Package.swift` |
| Manifest platforms | 140/141 declare platforms; 134 declare `.macOS(.v26)`; outliers: v12 ×1, v13 ×1, v14 ×1, v15 ×2 | `grep -hoE '\.macOS\(\.v[0-9_]+\)' */Package.swift` |
| `.docc` catalogues | 64 catalogues in 62/141 packages (44%) | `find . -type d -name "*.docc"` |
| DocC naming split | 53 `<Target>.docc` vs 11 `Documentation.docc` (two conventions) | basename tally |
| `.spi.yml` (Swift Package Index) | 53/141 packages opt in | `ls */.spi.yml` |
| CONTRIBUTING / CODE_OF_CONDUCT / CHANGELOG in packages | 0 / 0 / 0 — centralized in org `.github` repo (good dedup) | `ls */CONTRIBUTING.md` etc. |
| Org profile | `.github/profile/README.md` exists; largely index-by-link design (points at repositories tab + search queries) | read |
| Local tags | **0 of 141 repos have any local git tag** (fetch config omits tags) | `git tag` per repo |
| GitHub org | remotes are `github.com/swift-foundations/<pkg>`; old `coenttb/<pkg>` names **redirect** (verified: `gh api repos/coenttb/swift-mailgun` → `swift-foundations/swift-mailgun`) | `git remote -v`, `gh api` |

### Generated vs authored

READMEs are **structurally templated, content-authored**. H2-header frequency: License 138, Installation 134,
Quick Start 104, Architecture 57, Related Packages 52 (+2 lowercase), Key Features 49, Community 49, Overview 42,
Error Handling 38, Contributing 26, Requirements 18. Badges in 131.

Template signature/generations: MD5 over each `## Community` section yields clusters of 23 / 11 / 9 / 2 / 2
identical copies → **at least 5 template generations** coexist. The `## License` body appears in 8+ distinct
phrasings (51 × "Apache 2.0. See [LICENSE](LICENSE.md).", 12, 9, 7, 5, 4, 4, 3 × others). 7 READMEs have a
Table of Contents; 5 carry a "Status & maintainer" consulting plug. Opening sentences are bespoke and
high-quality per package (spot-checked swift-ascii, swift-async, swift-clocks, swift-color).

DocC is the opposite: **49 of 64 catalogues are a literal unfilled template stub** (see D5).

---

## 2. Defect classes

### D1 — Manifest restatement (README prose restating Package.swift facts)

| Metric | Count / Denominator | Methodology |
|---|---|---|
| READMEs stating a Swift toolchain version | 59/141; **28/59 (47%) contradict the manifest today** (manifests uniformly 6.3.3) | `grep -oE 'Swift [0-9]+\.[0-9]+(\.[0-9]+)?\+'` vs `head -1 Package.swift`, major.minor compare |
| Distinct Swift claims in circulation | 7: "6.3+"×28, "6.0+"×13, "6.2+"×10, "6.3.1+"×6, "6.1+"×4, "5.10+"×3, "5.9+"×1 | same |
| READMEs stating macOS version | 77/141; **18/77 (23%) contradict manifest** (claim 10.15/12/13/14/15 vs `.v26`) | `grep -hoE 'macOS [0-9]+'` vs `\.macOS\(\.v` |
| Xcode claims | 2 (one stale "Xcode 15.0+") | `grep 'Xcode [0-9]'` |
| Module/Product/Target tables | 30 READMEs | `grep -l -E '^\| *`?(Module\|Product\|Target)`? *\|'` |
| `## Products` / `## Dependencies` sections / ASCII arch diagrams | 5 / 9 / 4 | header grep, `┌─` |
| README `.product(name:)` self-references | 132 refs; **2 broken today** (1.5%); all 132 break under product rename | multiline-join manifest parse resolving the `extension String { static let x = "X" }` product-name DSL, then exact-match refs |

Exemplars:
- `swift-html/README.md:45-47` and `:260-264` — Requirements stated **twice** in one file ("Swift 6.3.1+, macOS 26.0+, Xcode 26.0+").
- `swift-authentication/README.md:248` — "Swift 6.0+" vs manifest 6.3.3; also claims macOS 14 vs `.v26`.
- `swift-foundation-extensions/README.md` — claims "Swift 5.10+", macOS 12 (manifest: 6.3.3, v26).
- `swift-linter-rules/README.md:55` — `.product(name: "Linter Rule Cardinal", package: "swift-linter-rules")` — product no longer exists there (moved to swift-institute-linter-rules as "Institute Linter Rule Cardinal").
- `swift-records/README.md:38` — `.product(name: "RecordsTestSupport", ...)` — manifest declares only "Records".

Severity: **drifts today** — the 28 + 18 live contradictions are measured decay, not hypothetical rename risk.
Caveat recorded: a naive `grep name: "X"` check false-positives 34 extra "broken" products because manifests
declare products via a String-constant DSL (`.library(name: .html)`); any future linter must resolve constants
(verified on `swift-html/Package.swift:5-7,37-39`).

### D2 — Version-pin fragility in installation snippets

| Metric | Count / Denominator | Methodology |
|---|---|---|
| READMEs with `from: "x.y.z"` pin | **44/141** (53 real instances; 1 grep false positive: swift-markdown-html-render's `tableOfContents(from:)` API) | `grep -l 'from: "'` + manual FP check |
| Pin verdicts vs remote tags | **MATCH 17, STALE 18, PIN_TAG_NONEXISTENT 5, NO_REMOTE_TAGS 4 → 27/44 (61%) wrong today** | per-repo `git ls-remote --tags origin`, semver sort, membership + newest compare |
| `exact:` pins | 1 README (swift-records, ×2 instances, `exact: "0.0.1"`, also wrong org) | `grep 'exact:'` |
| `branch: "main"` pins | **90/141 READMEs** (100 instances) | `grep -l 'branch: "main"'` |
| Both styles in one README | 3 | comm of lists |
| No install snippet at all | 16/141 | `grep -L '.package(url:'` |
| Local tag verifiability | 0/141 repos have local tags → pins are locally unverifiable without network | `git tag` |

Exemplars (pin → newest remote tag):
- `swift-testing-performance/README.md:32` — `from: "1.0.0"` but newest tag is **0.3.1**; 1.0.0 never existed (also wrong org: coenttb).
- `swift-foundation-extensions/README.md:41` — `from: "1.0.0"` vs newest **0.1.0** (nonexistent).
- `swift-form-coding/README.md:21` — `from: "0.1.0"` vs newest 0.5.0, no 0.1.0 tag ever (nonexistent).
- `swift-translating/README.md:11` — `from: "0.1.1"` vs newest 0.3.0 (stale).
- `swift-authentication`, `swift-json-web-token`, `swift-linter`, `swift-money` — pinned versions on repos with **no remote tags at all** (unresolvable snippet).
- Org profile `.github/profile/README.md:31` — showcases `swift-html … from: "0.1.0"` while swift-html's real newest tag is 0.17.2 and its own README says 0.17.2.

Severity: 61% wrong **today**; the 17 matches drift on next tag. The 90 branch-pins never go stale but are a
reproducibility hazard and contradict the release-gate model.

### D3 — Reference fragility (renameable coordinates, link classes)

| Metric | Count / Denominator | Methodology |
|---|---|---|
| `github.com/coenttb/*` references (pre-migration org) | **249 instances across 37/141 READMEs**; **24 packages' own install snippet points at the old org** | `grep -o 'github\.com/coenttb/[a-z-]*'`; own-URL cross-check per package |
| Redirect status | old names currently redirect (verified read-only); breaks if old name is reclaimed; **SwiftPM identity hazard today**: mixing `coenttb/<pkg>` and `swift-foundations/<pkg>` URLs in one dependency graph = duplicate-package conflict | `gh api repos/coenttb/swift-mailgun` |
| Name-based CI badges `workflows/CI/badge.svg` (break when workflow display-name changes) | **35/141** vs 8 file-based `actions/workflows/ci.yml/badge.svg` | grep both patterns |
| Broken `[LICENSE](LICENSE)` links (file is LICENSE.md) | **25 packages** (license files on disk: 134 LICENSE.md, 6 LICENSE) | link-target existence check |
| Other dead relative links | swift-records → `docs/TESTING_ARCHITECTURE.md`, `docs/DEVELOPMENT_HISTORY.md` (both absent) | same checker |
| Renderer-dependent links | `swift-threads/README.md:32` → `](../swift-synchronizers)` (resolves on disk, **404s on GitHub**); `swift-pdf/README.md` → `](../../tree/html-to-pdf)` (works only on GitHub web, broken on disk/DocC, and names a **branch**) | existence + pattern review |
| Links into DocC source with heading anchors | swift-records README ×7 → `Sources/Records/Documentation.docc/FullTextSearch.md#…` (breaks under catalogue restructure; anchors unchecked) | grep |
| Line-anchor links `#L<n>` / `blob\|tree` deep links | **0 / 0** (clean) | grep |
| Org display-name baked into DocC | 53 × `@TitleHeading("Swift Foundations")` | grep |
| Org-root links styled as package links | 2 × `github.com/swift-standards` | grep |

Severity: 25 + 2 broken **today**; 249 old-org references work-by-redirect (latent break + live SwiftPM identity
hazard for third parties); badges break only under workflow rename (but 35 use the fragile form).

### D4 — Volatile inventories (prose that changes)

| Metric | Count / Denominator | Methodology |
|---|---|---|
| Status badges | **129/141**: `status-active--development` blue ×114, orange ×10, `pre--cutover` ×2, `work--in--progress` ×1, blank ×2 | `grep -ho 'img.shields.io/badge/status-[a-z-]*'` |
| Prose maturity claims (pre-1.0 / alpha / beta) | 13 READMEs | case-insensitive grep |
| "currently …" claims | 10 READMEs / 12 instances | grep -i |
| Numeric inventory claims | 4 (swift-stripe "48 modules", swift-stripe-live "48+ modules", swift-linter "~43 rules") | `grep -E '[0-9]+\+? (targets\|products\|modules\|rules\|...)'` |
| "Related Packages" sections (family lists that stale as ecosystem evolves) | 52 (+2 lowercase) | header grep |
| "coming soon"/roadmap | 1 | grep |

Severity: drifts today. The D1 47% Swift-version error rate and D2 61% pin error rate ARE this class's measured
decay curve; the 129 "active development" badges are unfalsifiable-until-false and all say the same thing.

### D5 — Boilerplate / emptiness

| Metric | Count / Denominator | Methodology |
|---|---|---|
| Missing READMEs | 0/141 | file check |
| READMEs with no install snippet | 16/141 | `grep -L '.package(url:'` |
| DocC catalogues that are the literal unfilled stub | **49/64** — contain "umbrella catalog placeholder. Replace this line with a one-sentence description" | `grep -rl "umbrella catalog placeholder"` |
| Catalogues with ≤1 markdown file | 56/64 | find + count |
| DocC md files with an empty `## Topics` (heading, zero content after) | **137/247** files having the heading | awk per file (space-safe loop — Institute paths contain spaces) |
| Packages publishing to Swift Package Index **with placeholder-only docc** | **16** (placeholder text potentially rendered publicly on SPI) | `.spi.yml` ∩ placeholder |
| Rich catalogues (the exceptions) | swift-structured-queries-postgres (32 articles / 5,802 lines), swift-records (9 / 5,908), swift-translating (5 / 1,036), swift-kernel (4 / 769), swift-testing-performance (3 / 444) | per-catalogue tally |

Stub text (identical across 49, e.g. `swift-ascii/Sources/ASCII/ASCII.docc/ASCII.md`):
`# ``ASCII`` … @TitleHeading("Swift Foundations") … "ASCII — umbrella catalog placeholder. Replace this line…" … ## Topics` (empty).

Severity: static (doesn't drift) but is published surface; the "Replace this line" instruction is agent-visible
noise and 16 of them may be live on swiftpackageindex.com.

### D6 — DocC fragility

| Metric | Count / Denominator | Methodology |
|---|---|---|
| Disambiguation-hash symbol links (``…-5ljww``) | **7 instances / 2 files** | `grep -rn -E '``[^`]+-[0-9a-z]{4,8}``' --include="*.md"` |
| Signature-carrying symbol links (``foo(a:b:)``) | **233 instances / 29 files** | `grep -rl -E '``[A-Za-z][^`]*\([^`)]*:\)[^`]*``'` |
| `<doc:…>` links | 128 | grep |
| Empty Topics sections | 137 (see D5) | awk |

Exemplars: `swift-testing-performance/…/TestingPerformance.docc/TestingPerformance.md:29-39` (6 hash links,
e.g. ``TestingPerformance/measure(warmup:iterations:operation:)-4kv1g``);
`swift-records/…/Documentation.docc/NotificationsGuide.md:397` (``Database/Writer/notify(channel:payload:)-5ljww``).
Severity: hash links break when the overload set changes (silent under docc unless `--warnings-as-errors`);
signature links break on any parameter change — rename-and-signature-change fragility, latent today.

### D7 — Duplication across surfaces

| Metric | Count | Methodology |
|---|---|---|
| README first-paragraph ↔ DocC abstract overlap | 2/64 (swift-url-routing, swift-file-system) — low **only because** 49 catalogues are stubs with nothing to duplicate | 40-char abstract-prefix containment probe |
| README ↔ README boilerplate | Community section: 47 copies in 5 md5-variants; License: 138 sections, 8+ phrasings; Contributing: 26 sections despite org-central CONTRIBUTING.md | md5 clustering |
| Org profile ↔ package README | profile "Start here" table + install example duplicates package content and is already stale (0.1.0 vs 0.17.2) | read |
| swift-records dual-surface tutorial mass | 915-line README + 5,908-line docc with overlapping FTS/testing content, README deep-linking into docc source ×7 | inspection |

### Discovered classes

- **D8 — Post-rename residue.** The estate renamed products to spaced names ("Stripe Customers") and moved rules
  between packages, without sweeping docs: `swift-stripe/README.md:236` `import StripeCustomers` (+ StripePaymentIntents,
  StripeSubscriptions) — modules are now `Stripe_Customers` etc.; `swift-linter-rules/README.md:28,55,69-70` still
  teaches the Cardinal rule it no longer owns; `swift-records` RecordsTestSupport. Confirmed-broken import/product
  refs concentrated in 4 packages.
- **D9 — Renderer-dependence.** Three link idioms each valid in exactly one renderer: `[LICENSE](LICENSE)` (GitHub-only
  if file were present), `](../swift-synchronizers)` (disk-only), `](../../tree/html-to-pdf)` (GitHub-web-only). No
  link class is valid across GitHub + local checkout + DocC.
- **D10 — Tagless local checkouts.** 0/141 repos fetch tags; every version claim in docs is locally unverifiable;
  agents must go to network to check any pin. (Also makes `--fresh` builds of `from:`-declared local graphs
  network-dependent.)

---

## 3. Top 5 highest-leverage mechanical fixes for this slice

1. **Delete the two volatile blocks estate-wide: status-badge line + Requirements (Swift/macOS/Xcode) prose.**
   The manifest is the SSOT and is uniform (6.3.3 / v26). One templated sweep kills 129 permanent "active
   development" claims and all 46 live version/platform contradictions; add a swift-linter README rule forbidding
   `img.shields.io/badge/status`, `Swift [0-9.]+\+`, `macOS [0-9]+` in README prose. Nothing of value is lost —
   the facts remain machine-readable where SwiftPM already reads them.
2. **Generate install snippets from the manifest.** Emit the `.package(url:…)` + `.product(name:…)` block from
   `Package.swift` + `git remote` (org-correct URL, real product names, pin either omitted or auto-bumped by the
   release workflow). Kills in one stroke: 24 wrong-org self-URLs, 27 wrong pins (61% of pins), 90 branch-pins,
   2 broken product names, 3 stale import lines. The product-name resolver must handle the String-constant DSL
   (10 lines of parsing, validated in this audit).
3. **One org-wide substitution `github.com/coenttb/<pkg>` → `github.com/swift-foundations/<pkg>`** (249 instances,
   37 files; pure sed, zero judgment) + linter ban on the old org. Removes redirect dependence and the live SwiftPM
   duplicate-identity hazard for downstream graphs.
4. **Relative-link existence check in CI + LICENSE normalization.** A ~10-line checker (resolve `](path)` against
   the repo tree) catches today's 25 broken LICENSE links, records' 2 dead `docs/` links, and the disk-vs-GitHub
   idioms; standardize LICENSE.md + one License phrasing (mechanical: 8 phrasings → 1).
5. **DocC placeholder triage + fragile-link bans.** For the 49 stub catalogues: mechanically copy each README's
   (bespoke, verified-good) opening sentence over the "Replace this line" placeholder, or delete the catalogue
   until authored; block `.spi.yml` docs publishing while the placeholder marker is present (16 live today).
   Simultaneously: swap 35 name-based CI badges → file-based form (sed), and lint-ban disambiguation-hash symbol
   links (7 today) plus new `#L` links (0 today — keep it that way).

## 4. Implication for the research question (this slice's evidence)

The defect mass here is overwhelmingly **mechanical and lintable**: 96.5% of READMEs are reachable by ~6 grep-class
rules, and every high-count defect (badges 129, branch-pins 90, old-org 249, version prose 59, stub docc 49) is
either a template artifact or a restatement of a machine-readable fact. That matches Workspace context discipline
(deterministic facts → Workspace/swift-linter/CI, prose only for judgment). The drift-detection half of this
(README restating manifest = derived content going stale) sits squarely inside Goal #79's frame; the estate-wide
presence policy (badge policy, install-snippet generation, DocC stub lifecycle, org-profile freshness, old-org ban)
is *new exact-owner work* under #79's accepted assessment ("later policy proposals are new exact-owner work") and
therefore belongs in a **new Goal** that cites this survey as its evidence base, rather than scope-injecting #79.

## Appendix: verification traps hit during this audit (methodology warnings for repeat runs)

- Manifest product names use a String-extension constant DSL; naive `grep 'name: "X"'` produced 34 false "broken"
  refs. Resolve constants first (true broken count: 2/132).
- Institute paths contain spaces ("Copy on Write.docc"); unquoted `for f in $(grep -l …)` loops shred them. Use
  `while IFS= read -r` / `-print0`.
- `[UInt8](view)`-style Swift code is markdown-link-shaped; link checkers must exclude code spans (3 FPs).
- `git ls-remote | tail` is lexical; semver-sort before "newest tag" claims (0.9.1 vs 0.17.2).
- `from: "` greps catch `tableOfContents(from: """…` (1 FP).
- macOS `tr '\x01'` translates the *characters* x, 0, 1 — corrupted an intermediate result until replaced.
