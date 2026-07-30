# Documentation-estate audit: swift-primitives (L1, whole population)

Audited: 2026-07-30. Root: `swift-institute/swift-primitives`.
Population: 202 package roots (every top-level directory carries `Package.swift` at depth 1; `find $P -maxdepth 2 -name Package.swift | wc -l` = 202). All counts are whole-population, no sampling. Exclusions applied everywhere: `.build`, `checkouts`, `.git`, `node_modules`, `.worktrees`. GitHub touched read-only (`gh api` GET only).

**Population caveat discovered:** `swift-buffer-primitives-issue-3` is a second clone of `swift-buffer-primitives` (identical `origin`, byte-identical README via `cmp`). The slice therefore contains **201 unique repositories in 202 roots**. Scratch checkouts inside the family root pollute every whole-population denominator.

---

## 1. Estate inventory

| Fact | Value | Methodology |
|---|---|---|
| Roots with root README.md | **202/202 (100%)** | `ls $P/*/README.md \| wc -l` |
| README length | **median 102, mean 105, p90 141, max 263, min 3; total 21,365 lines** | `wc -l $P/*/README.md` sorted, percentile awk |
| Packages with ≥1 `.docc` | **154/202 (76%)** | `find $P -type d -name "*.docc"` → dedupe by package |
| `.docc` catalogues / md files | **165 catalogues, 300 md files** | same find + `find -name "*.md"` per catalogue |
| Single-file catalogues | **115/165 (70%)** | md-count per catalogue distribution: 115×1, 37×2, 6×3, tail to 32 (`swift-structured-queries-primitives`) |
| Machine metadata | **202/202 have `.github/metadata.yaml`; all declare `readme: family: E`** | `ls $P/*/.github/metadata.yaml`; `grep "family:"` |
| CI workflow | **202/202 have `.github/workflows/ci.yml`** | `find $P/*/.github/workflows -name "*.yml"` |
| LICENSE.md | **201/202** — missing in `swift-property-primitives`, whose README links `LICENSE.md` (broken link) | per-dir existence loop |
| Git remotes | **202/202 → org `swift-primitives`** (consistent) | `git -C $d remote get-url origin` |
| Local tags | 8 packages have local tags; **local checkouts do not carry remote tags** (evidence trap: `swift-tagged-primitives` = 0 local, 10 remote tags, newest 0.10.0) | `git tag` loop + `gh api repos/.../tags` |

### Generated vs authored: the template signature

The estate is one generated family with hand-adapted bodies. Signature of README family E:

- shields.io status badge: **201/202** (`badge/status-active--development-blue` ×200, `experimental-red` ×1)
- Section skeleton (files containing header): Quick Start **191**, Installation **198**, Architecture **182**, Platform Support **175**, Community **166**, License **201**, Key Features **55**, Stability **16**, Related Packages **69**, Error Handling **6**
- Injection markers `<!-- BEGIN: discussion -->…<!-- END: discussion -->`: **165** — an injection pipeline already exists
- Identical sentence "Apache 2.0. See [LICENSE…": **191**
- Two toolchain-sentence generations: "…matching Linux / Windows toolchain" **120** vs "…corresponding Linux / Windows toolchain" **44**
- Org-level `.github/metadata.yaml` documents the pipeline: `sync-metadata.yml` (description/topics/homepage), `generate-social-preview.yml`, org-profile fields

Verdict: **100% template-derived, ~100% hand-edited afterwards** — the worst of both: template uniformity without template regenerability.

### Commit messages (adjacent surface)

Last 3 subjects × 202 repos = 606 sampled: `Sync .gitignore from canon` ×197, `Inherit organization issue forms` ×182, `chore: materialize canonical issue forms` ×168 — fleet-sync noise dominates recent history. Only **4/606** subjects carry an issue/PR number. Mixed imperative and conventional-commit styles. For an agent reconstructing "why", commit history in this slice is nearly information-free; the durable context lives in issues the commits don't reference.

---

## 2. Defect classes

### D1 — Manifest restatement (README restating Package.swift)

| Metric | Count | Denominator |
|---|---|---|
| Product tables (`\| Product \|`) | **172** | 202 READMEs |
| Target tables (`\| Target \|`) | **111** | 202 |
| Platform tables (`\| Platform`) | **173** | 202 |
| Toolchain-version claims (`Swift 6.x`) | **178** | 202 |
| Install snippets naming products (`.product(name:`) | **198** | 202 |

Estimated instances: ≥830 restatement blocks/lines across ~198 files.

**Measured drift TODAY** (python pass comparing `| Product |` table rows against `.library(name:)` in `Package.swift`):

- **41/172 product tables (24%) mismatch the manifest now** — 149 manifest products absent from tables, 20 ghost rows naming products that do not exist.
- Whole-README product coverage (issue #80's predicate): **219 of 841 library products (26%) are named nowhere in their package's README**, across 58 packages. Excluding `… Test Support` products: **180 real products uncovered, in 32 packages**.

Exemplars (path → offending content):
- `swift-affine-primitives/README.md` — table lists 5 products incl. ghost `Affine Primitives Core`; manifest has 14 (`Affine Quotient/Tagged/Composition/… Primitives` all absent)
- `swift-cardinal-primitives/README.md` — ghost `Cardinal Primitives Core`; 9 manifest products absent
- `swift-byte-primitives/README.md` — 5 of 8 products absent from table
- `swift-bit-primitives/README.md:88` — table omits `Bit Pattern Primitives`
- `swift-bit-primitives/README.md:78` — "Requires Swift 6.3.1 and macOS 26 / iOS 26 …" restating manifest `platforms:`/tools-version

Severity: **drifts today** — 24–26% of restated facts are already wrong, without any rename event. Toolchain/platform claims will drift in one sweep the day the fleet moves to Swift 6.4.

### D2 — Version-pin fragility (installation snippets)

Methodology: `grep -l 'branch: "main"' | 'from: "' | 'exact:'` over root READMEs; remote verification `gh api repos/swift-primitives/<r>/tags?per_page=1` (read-only).

- `branch: "main"` pins: **196/202**
- `from: "0.1.0"` pins: **16** — **all 16 remote-verified to have ZERO tags → the documented snippet fails dependency resolution today** (swift-affine-, byte-, byte-collection-, byte-serializer-, cardinal-, collection-, cursor-, cyclic-, dimension-, input-, ordinal-, percent-, radix-, range-, vector-primitives, swift-standard-library-extensions)
- `exact:` pins: 0. `.upToNextMajor`: 1.
- Reverse direction, remote-verified: **≥7 repos have resolvable semver tags while their README still advises `branch: "main"`**: swift-tagged-primitives (0.10.0), swift-buffer-primitives (0.1.1, ×2 incl. clone), swift-builder-primitives (0.1.0), swift-logic-primitives (0.1.2), swift-cache-primitives (0.0.1), swift-render-primitives (**3.2.2**, fork heritage). `swift-memory-allocation-primitives` (0.2.0 remote) has **no Installation section at all**. Full 196-repo remote census aborted (API loop throttling in sandbox); the 7 are a verified lower bound. Local tags are NOT usable as a proxy (see evidence trap above).
- **≥23/202 packages (11%) have an installation snippet contradicting remote reality today.**

Exemplars: `swift-percent-primitives/README.md` (`from: "0.1.0"`, no tags); `swift-tagged-primitives/README.md` (`branch: "main"` vs 0.10.0); org profile `.github/profile/README.md` example pins `from: "0.1.0"` for tagged-primitives (resolves, but 9 releases stale).

Severity: **broken today in both directions**; every future tag event mints more instances.

### D3 — Reference fragility

Methodology: `grep -oE "github.com/[^ )]+"` classification; local-dir existence as target check; `gh api repos/...` for the misses (GET only).

- Cross-repo links to `github.com/swift-primitives/*`: **607 instances, 202 distinct targets** across READMEs.
- **2 targets are renamed repos surviving only on GitHub redirects**: `swift-shared-primitives` → now `swift-ownership-shared-primitives` (3 refs), `swift-storage-arena-primitives` → now `swift-storage-generational-primitives` (1 ref). Affected: `swift-array-primitives`, `swift-async-primitives`, `swift-column-primitives`, `swift-ownership-shared-primitives` (links to its own old name), `swift-slot-map-primitives`, `swift-tree-primitives` READMEs. This is the #94 "display name" defect class realized in the estate: rename happened, docs didn't.
- Branch-relative deep links (`/blob/main/`): **5** (4 → swiftlang/swift-evolution proposals, quasi-stable; 1 → `swift-institute/swift-institute/blob/main/Research/…` in `swift-binary-base-primitives/README.md`, path-fragile). Org profile adds 1 more (`swift-primitives/swift-primitives/blob/main/Documentation.docc/Primitives Tiers.md` — target exists remotely, verified).
- Line-number anchors: **0**. Issue-number references in READMEs: **0**. (Clean.)
- Relative links: **194** READMEs (mostly `LICENSE.md`) — render on GitHub, break when README prose is reused as DocC/SPI landing; **1 broken today** (`swift-property-primitives` links a LICENSE.md that does not exist).
- Badges: 47 CI badges, **0 broken** (all `ci.yml` exist); 155 packages have CI but no badge — inconsistency, not fragility.
- Links to `github.com/coenttb/*`: **7 instances in 5 READMEs** (swift-percent ×3, swift-money, swift-bunq, swift-document-templates, swift-structured-queries-postgres) — cross-boundary references from Institute docs into personal estate; policy-relevant given the Institute dependency rule.

Severity: mixed — 2 rename-victims **latent-broken now** (one new repo claiming an old name silently hijacks 4 links), rest breaks only under rename/move.

### D4 — Volatile inventories in prose

Methodology: pattern battery over READMEs + numeric-claim verification against manifests (python).

- Numeric product-count claims ("Two library products…", "20 library products"): **83 READMEs; 19 (23%) are WRONG today** (e.g. swift-affine-primitives claims 5, has 14; swift-cardinal-primitives claims 4, has 12; swift-order-primitives claims 2, has 9; swift-byte-primitives claims 3, has 8).
- "Pre-1.0" claims: **69 files** (75 instances) — falsified per-package at first 1.0 tag; already awkward for render-primitives (3.2.2).
- Status badges `active--development`: **200** — one shared volatile claim × 200 copies.
- "currently": 6, "not yet": 4/5, "planned": 1/2, roadmap/coming-soon/TODO: **0** (clean).
- Org profile (`.github/profile/README.md`): "Each package ships with a DocC catalog" (**actual: 76%**), "Status: Public alpha", "Multi-target per package — **Core + variants + umbrella**" — the Core convention was **dissolved by doctrine** ([MOD-001] deprecated per in-repo scope docs); the family's front page still teaches it.

Severity: **drifts today** (23% of countable claims already false); every claim is a per-package copy of what is usually one family-level fact.

### D5 — Boilerplate / emptiness

- Missing READMEs: **0**. Honest stub: 1 (`swift-matrix-primitives`, 3 lines, explicit "namespace reservation" notice — arguably the most agent-honest README in the slice).
- READMEs without an Installation section: **4** (binary-leb128-parser, matrix, memory-allocation, set-algebra).
- **Community/discussion sections are 100% dead weight**: 165 marker blocks → 35 empty, 21 visible placeholder ("*Discussion thread will be created at first public release.*"), 109 HTML-comment placeholder. **0 real discussion links.** 166 `## Community` headers serve no reader.
- DocC placeholders: **80/300 docc md files (27%) contain the literal template text "Replace this line with a one-sentence description…", across 71 packages = 46% of docc-bearing packages** (methodology: NUL-safe `find … -print0 | xargs -0 grep -l "Replace this line"`; note paths contain spaces — naive `$(cat list)` greps silently return 0).
- Single-file catalogues: 115/165 (70%) — a landing page and nothing else.

Severity: static rot; costs every agent a read that returns nothing.

### D6 — DocC fragility

Methodology: NUL-safe grep battery over the 300 catalogue md files; module-existence check of symbol-link first components against `Sources/*` module names (spaces→underscores), whole-family index for cross-module classification.

- Symbol links (double-backtick): **1,298 instances**; **331 carry signatures** (`(_:)`, parameter lists) — break on any signature change.
- Disambiguation-suffix links (`-swift.property`, `-swift.protocol`, hash suffixes): **10 files** (swift-ordinal-primitives ×2, swift-property-primitives ×7, swift-structured-queries-primitives ×1) — the most signature-fragile form.
- **Broken today: 31 symbol links across 4 packages reference modules that no longer exist anywhere** — `Affine_Primitives_Core`, `Cardinal_Primitives_Core`, `Index_Primitives_Core`, `Ordinal_Primitives_Core` — residue of the documented "L1 core-dissolution sweep (2026-06-23)". Exemplar: `swift-ordinal-primitives/Sources/Ordinal Primitives/Ordinal Primitives.docc/Tagged-Ordinals.md` → ``Ordinal_Primitives_Core/Ordinal/Protocol-swift.protocol``.
- Cross-module links that cannot resolve in the catalogue's own build: **9** (swift-coproduct-, order-, product-primitives referencing sibling packages' modules).
- `## Topics` curation: **213/300 files** — exposure surface for future auto-curation restatement.
- Matching README-side residue: **9 READMEs still name a dissolved `<X> Primitives Core` product** (affine, argument, cardinal, comparison, equation, hash, ordinal, property, vector).
- Notable positive: **37 docc files cite doctrine by durable ruling ID** ([MOD-017] ×51, [MOD-031] ×47, [MOD-001] ×14, 136 instances) — exactly the durable-coordinate style #94 wants; but 22 files also embed dated sweep events that will read as stale history.

Severity: 40 link instances **broken today**; 331 more break on the next signature-shaping refactor.

### D7 — Duplication across surfaces

- README intro vs DocC landing intro (difflib over first prose block, pairs where both ≥40 chars): only **13 comparable pairs** (docc landings are mostly placeholders) → 1 near-duplicate (>0.8: swift-buffer-linked-primitives 0.92), 3 partial. **Low today** — because the DocC surface is unfilled, not because duplication is controlled.
- Org profile hand-duplicates 6 package one-liners ("Start here" table) — small, drift-prone.
- The dominant duplication is **template-instantiated family facts**: 191 identical license lines, 164 toolchain sentences, 173 platform tables, 200 status badges — each a per-package copy of one family-level fact, so one family-level change = ~200-file sweep.

### Discovered classes

- **D8 wrong-repo install URL**: whole-population scan found **0 genuine instances** (only the issue-3 clone, correct for its true identity). Negative result worth recording.
- **D9 estate-hygiene/evidence traps**: (a) scratch clone `swift-buffer-primitives-issue-3` inflates every denominator and would double-publish docs; (b) local checkouts lack remote tags — any local-only "is it tagged?" audit silently lies; (c) `.docc` paths contain spaces — unquoted shell pipelines return silent zeros (two of this audit's own first passes returned false zeros).
- **D10 doctrine-stale front door**: the org profile teaches the dissolved Core convention and a dead install pin — the highest-traffic page in the family contradicts both current doctrine and current tags.

---

## 3. Cross-cutting quantitative pattern

Every class of restated fact converges on the same drift rate within months of the template sweep:

| Restated fact | Drifted today |
|---|---|
| Product tables | 41/172 = **24%** |
| Product coverage (#80) | 219/841 = **26%** |
| Numeric count claims | 19/83 = **23%** |
| `from:` pins | 16/16 = **100%** dead |
| Core references (README+DocC) | 9 READMEs + 31 links, 100% stale since 2026-06-23 |

A quarter of everything hand-restated has already drifted, with zero renames involved — rename fragility (D3) is the smaller, latent half; **derivation without regeneration is the active defect engine**.

## 4. Top 5 highest-leverage mechanical fixes (this slice)

1. **Make the Installation snippet tag-derived or tag-free.** One generator (extend the existing metadata/injection pipeline: markers already in 165 files) that writes the snippet from the repo's newest remote tag, or a fleet-wide unpinned form. Repairs all 23 broken-today snippets and retires the 196-file `branch:"main"` liability the first coordinated tagging milestone would otherwise create. Denominator: 198 Installation sections.
2. **Project product/target/platform tables from `Package.swift`** via the same marker mechanism (`<!-- BEGIN: products -->`), or delete the tables. Repairs 41 drifted tables + 149 uncovered products, mechanically satisfies the #80 coverage predicate forever, and removes ~460 restatement blocks from hand maintenance.
3. **One-shot Core-residue sweep + module-existence linter.** Fix 9 READMEs, 31 dead DocC links, and the org-profile "Core + variants" sentence; add a swift-linter/CI check that every ``Module/…`` DocC link's module exists in the package (would also catch the 9 cross-module non-resolvers). Turns the 2026-06-23 sweep's leftover debt into a machine-enforced invariant.
4. **Ban numeric inventories and fleet-level facts from per-package prose.** Template edit: "Two library products —" → "Products —"; move toolchain/platform sentence to a generated line; retire per-file status claims into the badge (or drop). Kills the 83-claim/19-wrong class and collapses 364 copies of one family fact into the generator.
5. **Delete dead weight and the estate traps**: remove 166 empty Community sections (or actually inject content — pipeline exists), fill-or-delete 80 "Replace this line" DocC placeholders (46% of catalogue-bearing packages), fix the 4 renamed-repo link instances + add link-target existence to the linter, add the missing `swift-property-primitives/LICENSE.md` or fix its link, and evict `swift-buffer-primitives-issue-3` from the family root.

## 5. Implications for the #79-vs-new-Goal question (evidence, not policy)

- The estate is already generation-managed (family-E marker, metadata.yaml sync, injection markers) — extending generation to products/platforms/install is incremental engineering, not a new paradigm.
- The measured defects split cleanly: **(a) stale derived content** (Core residue, dead pins, wrong counts — exactly Goal #79's subject) and **(b) absent generation/linter policy** (README-as-projection, DocC link checking — which #79's accepted assessment explicitly fences off: "later policy proposals are new exact-owner work"). The data supports repairing (a) under #79 and chartering (b) as new exact-owner work; the 23–26% drift rates are the quantified justification for (b).
- For AI-only readers, the highest-value README content observed is exactly what is NOT derivable from the manifest (Quick Start semantics, "when to import which product" guidance, Related Packages rationale, the ruling-ID citations in DocC scope docs); everything derivable showed ~25% rot. This slice's evidence: **prose for judgment, projection for facts** is not an aesthetic preference — it is the measured failure boundary.
