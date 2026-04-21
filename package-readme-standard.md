# Swift Package README Standard — Ecosystem Audit and Revisions

<!--
---
version: 1.0.0
last_updated: 2026-04-21
status: RECOMMENDATION
tier: 2
workflow: Discovery [RES-012] (convention evolution) + Investigation [RES-001] (maintainer critique on swift-property-primitives/README.md, 2026-04-21)
trigger: Two signals — (1) maintainer concrete critiques on the first Swift Institute package preparing for 0.1.0 on SPI (swift-property-primitives); (2) ecosystem-wide pre-SPI-publication audit before README conventions propagate across 60+ sibling packages.
scope: The /readme skill canon (22 rules [README-001]–[README-022]). Ecosystem-wide: affects all package READMEs across swift-primitives, swift-standards, swift-foundations, and swift-institute. Excludes .docc catalogue conventions (covered by /documentation) and CLAUDE.md (separate audience).
---
-->

## Context

The `/readme` skill (`Skills/readme/SKILL.md`, v1.0 dated 2026-03-20) codifies 22 requirements [README-001]–[README-022] governing Swift Institute package README files. The skill was authored before any ecosystem package had shipped a release, and its requirements have not yet been stress-tested against top-tier Swift OSS practice.

Two concurrent signals motivate a review before the skill's requirements get baked into the 60+ package ecosystem:

1. **Maintainer critique on the first release-candidate README** (2026-04-21, `swift-primitives/swift-property-primitives/README.md` at commit `bab5c3f`). Three specific defects were identified:

   | Defect | Example |
   |--------|---------|
   | Weak examples | `stack.inspect.count` demonstrates nothing that `stack.count` doesn't already do |
   | Off-scope framing | The "Five-layer Swift Institute ecosystem position" section belongs at ecosystem docs, not in a package README |
   | Lack of evaluator-lens discipline | Paragraphs present that do not earn their place against the reader's evaluation question "do I want to use this?" |

2. **Pre-publication timing**. `swift-property-primitives` is the first Institute package preparing to ship on Swift Package Index. Before that tag lands and downstream consumers pin it, the README conventions should be the version we are willing to see propagated across every sibling package.

The prior research document `readme-skill-design.md` (SUPERSEDED 2026-03-10 by the shipped skill) established the skill's original scope by auditing **internal** READMEs (ecosystem inconsistency across 61+ packages). The present research tests that scope against **external** top-tier Swift OSS.

## Question

Which of the current `/readme` skill's 22 requirements are load-bearing when measured against first-class Swift OSS READMEs, which are ecosystem-idiosyncratic (and justified), and which are over-prescriptive and should be relaxed, tightened, or retired?

And: what new rules or meta-principles are needed to prevent the specific defects the maintainer surfaced on `swift-property-primitives`?

---

## Methodology

### Sample

Fifteen READMEs were surveyed (per [RES-021] prior art), spanning four provenance classes:

| Provenance | Packages | LOC range |
|------------|----------|-----------|
| Apple / Swift.org | swift-collections, swift-numerics, swift-async-algorithms, swift-syntax, swift-log, swift-argument-parser, swift-system, swift-testing, swift-atomics, swift-crypto, swift-nio | 64–401 |
| Point-Free | swift-composable-architecture, swift-dependencies, swift-parsing, swift-snapshot-testing | 315–682 |

Raw READMEs fetched via `gh api repos/{owner}/{repo}/readme -H "Accept: application/vnd.github.raw"` on 2026-04-21.

### Verification discipline ([RES-013a])

Every finding below is tagged:

| Tag | Meaning |
|-----|---------|
| `Verified: 2026-04-21` | Pattern observed directly in the surveyed corpus on the survey date |
| `Ecosystem-specific` | Pattern justified by Swift Institute conventions not present in sampled external practice (e.g., typed throws, `-primitives` suffix) |
| `Carried forward (verified)` | Finding from `readme-skill-design.md` still correct in the current skill |

### Contextualization step ([RES-021])

For each external pattern absent from the current skill — and each current-skill rule absent from external practice — the analysis describes what the concept would cost (or save) in the ecosystem's type system and documentation architecture before classifying the divergence as a gap or as deliberate design.

---

## Analysis

### Section 1 — Section Ordering

**Findings (`Verified: 2026-04-21`)**:

| Package | Opening → Installation distance |
|---------|--------------------------------|
| swift-argument-parser | Installation at line 117 (after full working example at line 13) |
| swift-composable-architecture | Installation at line 564 (after basic usage at line 88) |
| swift-dependencies | Installation at line 242 (after quick start at line 76) |
| swift-snapshot-testing | Installation at line 162 (after usage at line 10) |
| swift-parsing | Getting Started at line 62 (installation only in `Package.swift` snippet inside Getting Started subsection) |
| swift-testing | No installation section at all; links to SPI |
| swift-syntax | Installation at line 17 (embedded under "Releases", after `Documentation` section) |
| swift-atomics | Getting Started at line 53 (with installation snippet inside), preceded by inline code example at line 10 |
| swift-nio | Installation at line 254 (after 100+ lines of repository organization, supported versions, conceptual overview) |
| swift-system | "Adding `SystemPackage` as a Dependency" at line 29 (after usage example at line 14) |
| swift-collections | Installation at line 270 (after module inventory) |
| swift-log | Installation inside Quick Start at line 19 |
| swift-crypto | Installation at line 7 (under "Using Swift Crypto" immediately after one-liner) |
| swift-numerics | Installation at line 38 (after introduction + inline code) |
| swift-async-algorithms | Installation at line 64 (after Motivation + Contents module listing) |

**Pattern**: 13 of 15 surveyed READMEs place Installation **after** the first code example / usage demonstration. Only `swift-crypto` places Installation immediately after the one-liner without a preceding example. No surveyed README places Installation in position 4 (the current skill's [README-001] requirement).

**Current skill rule** ([README-001]):

> 1. Title and badges
> 2. One-liner
> 3. Key Features — 4–8 bullets
> 4. Installation — Package.swift dependency and target configuration
> 5. Quick Start — Minimal working example

**Contextualization**: The "Installation-before-Quick-Start" ordering presumes the reader has already decided to use the package — Installation is the conversion step. Every other surveyed README presumes the opposite: the reader is evaluating, and Installation is the call-to-action after the hook. The "Art of README" cognitive funneling principle cited in the superseded `readme-skill-design.md` explicitly favors example-first ordering. The current skill's ordering is empirically absent from first-class Swift OSS.

**Diagnosis**: **Over-prescriptive**. The rule should allow either ordering.

---

### Section 2 — Opening Move

**Findings (`Verified: 2026-04-21`)**:

| Opening archetype | Example packages | Form |
|-------------------|------------------|------|
| `Swift X is an {one-liner}.` | swift-collections, swift-async-algorithms, swift-crypto, swift-numerics (implicit via "Swift Numerics provides"), swift-system, swift-log ("This repository contains …"), swift-testing, swift-atomics | Prose paragraph, sometimes naming the package as bold text |
| Inline code before any prose | swift-argument-parser (H1 → "## Usage" → 26-line working `@main` example at line 13) | Code-first opening |
| Tagline + inline example in paragraph | swift-atomics (H1 → 2 paragraphs → 12-line example at line 10) | Hybrid; atomic counter shown before any section header |
| Badges + feature bullets | swift-parsing (H1 → badges → 4-bullet feature list with bold keywords → TOC) | Ecosystem-advantage framing |
| Marketing-first | TCA ("a library for building applications in a consistent and understandable way") | Point-Free house style |

No surveyed README begins with "A Swift package for …" — the phrase our current [README-006] explicitly prohibits. `Verified: 2026-04-21`. This rule is aligned with external practice.

**Pattern**: The strongest openings answer "what is this and why would I want it?" within the first 10 lines. `swift-argument-parser`'s opening is the sharpest in the sample: the full `@main` example *is* the explanation — property wrappers show themselves declaring the CLI. `swift-atomics` is similar: the 12-line concurrent-counter example demonstrates both the atomicity and the required-ordering design discipline. No padding.

**Diagnosis**: **Load-bearing but under-specified**. The current rule [README-006] correctly prohibits "A Swift package for …" and marketing language. What it does not yet articulate: the opening should land the reader's evaluation by the end of the first screen. Add an "opening contract" guidance.

---

### Section 3 — Example Quality (the Maintainer's Critique)

**Maintainer's seed** (2026-04-21):
> `stack.inspect.count` is weak because `stack.count` already does that. An example in a README must EARN its complexity by demonstrating something the primitive enables that you cannot easily do otherwise.

**Cross-reference against top-tier corpus** (`Verified: 2026-04-21`):

| Package | First code example | What it demonstrates | Load-bearing? |
|---------|-------------------|----------------------|---------------|
| swift-atomics | `ManagedAtomic<Int>` counter; 10 concurrent queues × 1M increments = 10_000_000 | Correctness under concurrency — impossible to get right without atomics | Yes |
| swift-numerics | `let z = Complex<Double>.i` | Types not in stdlib — literally cannot be expressed without the package | Yes |
| swift-system | `FileDescriptor.open(…) { try fd.writeAll(message.utf8) }` via `closeAfter` | Typed file descriptor + automatic close semantics — shows the package's entire resource-management value prop | Yes |
| swift-argument-parser | `@main struct Repeat: ParsableCommand { @Option var count: Int? ... }` | Property wrappers declaring the CLI — the library's magic made visible | Yes |
| swift-testing | `#expect(greeting == "Hello")` → failure output `(greeting → "Hello, world!")` | Value-capturing macro, demonstrable on failure — reason-to-use is visible | Yes |
| swift-parsing | Naive `split(separator:)` approach FIRST, then library version | Baseline-contrast technique: shows the problem before the solution | Yes |
| swift-snapshot-testing | `assertSnapshot(of: vc, as: .image)` | One-line asymmetric API that replaces manual image-comparison harness | Yes |
| swift-log | `Logger(label:).info("Application started")` | Generic — could be any logger | Weaker; redeemed by the metadata-key example immediately below |
| swift-collections | No opening code example — module inventory with documentation links | Package is too broad for one representative example | Acceptable; navigational README |

**Pattern**: In the eight strongest cases, the first code example demonstrates something that would be **either impossible, awkward, or subtly wrong** to express without the library. The example earns its complexity.

**The anti-pattern** (matching the maintainer's critique): showing a call whose non-library equivalent is *trivially identical* — `stack.inspect.count` vs `stack.count`. Even if the verbose form is part of the API surface, showcasing it in the README demonstrates nothing the reader could not already see in DocC.

**Diagnosis**: **Missing rule**. The current skill's [README-009] and [README-022] require imports, realistic names, and runnability. They do not require that the example be *motivated* — that it demonstrate something fundamental to the package. Add this as a new rule.

**Baseline-contrast technique** (observed in swift-parsing): Show the problem's naive solution first (`.split(separator:)` + `compactMap` + `guard let`), then the library's version. This is the single sharpest teaching pattern in the surveyed corpus. Document it as a permitted optional technique.

---

### Section 4 — Scope Boundary (Package vs Ecosystem)

**Maintainer's seed** (2026-04-21):
> The "Five-layer Swift Institute ecosystem position" section is not relevant to this package's README. A package README is about THE PACKAGE, not where it sits in the broader ecosystem.

**Cross-reference** (`Verified: 2026-04-21`):

| Package | Sibling / ecosystem content | Form | Scope-respectful? |
|---------|----------------------------|------|-------------------|
| swift-nio | "Repository organization" table listing 6 sibling repos with `from: "X"` SPM version hints | Side-by-side table, not hierarchical | Yes — treats siblings as peers |
| swift-collections | Module inventory (BasicContainers, DequeModule, …) pointing to DocC | Per-module summaries | Yes — internal product breakdown, not ecosystem-narrative |
| swift-composable-architecture | "Companion libraries" section naming 3 community extensions + "Other libraries" naming competitors | Bullet list of peer libraries | Yes — peer and competitor framing |
| swift-dependencies | "Extensions" (building on top) + "Alternatives" (competitors) as separate H2 sections | Bullet lists | Yes — same peer/competitor framing |
| swift-crypto | "Evolution" section explaining *this package's relationship to Apple CryptoKit* (its parent) | Prose | Yes — the parent is load-bearing for the reader's evaluation (why would I use this over CryptoKit?) |
| swift-parsing | "Other libraries" (competitors) + "Motivation" (why the library exists) | Bullet list + prose | Yes |
| swift-property-primitives (current) | "Five-layer Swift Institute ecosystem position: Layer 1: Primitives ← swift-property-primitives" | Hierarchical diagram | **No** — author-oriented positioning |

**Pattern**: Top-tier READMEs reference other repositories when doing so **helps the reader's evaluation**: peers (sibling packages they might also need), parents (the thing this package is the Linux port of, as in swift-crypto), or competitors (alternatives they could consider). They do **not** include parent-ecosystem hierarchical diagrams that answer "where does this sit in our architecture?" — that question is the author's question, not the reader's.

**Contextualization step**: The Swift Institute's five-layer architecture is load-bearing at the swift-institute.org website, in `Layers.md`, and in the monorepo root README [README-018]. It is **not** load-bearing in a sub-package README because the evaluator's decision ("do I want to use this?") does not depend on which layer this package lives in — the evaluator will install it, reference it, and observe its dependencies regardless of the hierarchical label.

Institute-specific ecosystem content *does* belong in:

| Artifact | Content |
|----------|---------|
| `swift-institute.org` DocC | Layer diagrams, cross-layer architecture, ecosystem manifesto |
| Monorepo root READMEs (swift-primitives, swift-standards, swift-foundations) | Layer diagram showing where the monorepo sits, package inventory |
| `.github/profile/README.md` (org-level) | Org-to-ecosystem navigation |
| Sub-package README | **NOT** ecosystem-hierarchy content; sibling-package peer references are fine |

**Diagnosis**: **Missing rule**. Add a scope-boundary rule prohibiting author-oriented ecosystem-navigation content in sub-package READMEs and explicitly permitting peer-package references.

---

### Section 5 — Evaluator's Lens (Meta-Rule)

**Maintainer's seed**:
> A package README's audience is someone evaluating "do I want to use this?" — every paragraph must earn its place against that question.

This is not a rule about any specific section — it is a meta-principle that subsumes the critiques in Sections 3 and 4. Surveyed top-tier READMEs consistently exhibit this discipline: every paragraph answers one of:

1. **What does this do?** (one-liner, opening code example, feature inventory)
2. **Why would I use it vs alternatives?** (motivation, alternatives, design philosophy)
3. **What is the shape of using it?** (quick start, API teaser, installation, platform support)

Content that does **not** answer one of those three questions — author-oriented history, internal organization narrative, architectural-position diagrams (in sub-package READMEs), author's design reflections — degrades the evaluator's experience and belongs elsewhere (DocC articles, blog posts, research documents, `CONTRIBUTING.md`).

**Diagnosis**: **New meta-rule**. Add as the first rule after the maturity-tier scaffolding.

---

### Section 6 — Key Features Format

**Current skill rule** ([README-007]): Key Features MUST contain 4–8 bullets; each bullet MUST start with a **bold keyword**; single line per bullet; em-dash separator.

**Survey findings** (`Verified: 2026-04-21`):

| Package | Top-of-README "features" signal | Form |
|---------|--------------------------------|------|
| swift-parsing | 4 bullets at line 10–16 with **bold keywords** and em-dashes — matches the rule exactly | Bold-keyword bullets |
| swift-log | 5 bullets at line 7–13, each with 📚 🚀 🪪 🔒 🔀 emoji + **bold keyword** | Emoji + bold keyword (not quite our format) |
| swift-async-algorithms | 3 goal bullets at line 7–9, plain text (no bold keyword) | Prose bullets |
| swift-argument-parser | No bullet list; opens with inline code + prose | No Key Features section |
| swift-numerics | Prose description with two categorization bullets | Prose |
| swift-system | Prose opening, no Key Features bullets | Prose |
| swift-atomics | No Key Features bullets near the top; "Features" section appears at line 123 as a technical inventory | Deep-document feature inventory |
| swift-testing | H3 subsections (`### Clear, expressive API`, `### Custom test behaviors`) with a code example in each | Feature-as-subsection-with-example |
| swift-crypto | No Key Features section | N/A |
| swift-collections | Module-by-module bullet breakdown | Product inventory |
| swift-nio | No Key Features section | N/A |
| swift-composable-architecture | 5 bullets with **bold keywords** and `<br>` line breaks + explanatory paragraphs | Bold keyword + paragraph |
| swift-dependencies | Inline prose Overview, no bullet list | Prose |
| swift-snapshot-testing | "Features" section at line 208 deep in the document, not at the top | Deep-document feature inventory |

**Pattern**: The "4–8 bold-keyword bullets near the top" format is present in ~3 of 15 READMEs (swift-parsing, swift-log with emoji prefix, TCA with paragraph expansions). The other 12 either use prose, subsection-with-example, or have no Key Features section at all.

**Contextualization step**: The bold-keyword bullet format is **scannable** and enables quick comparison when multiple packages are evaluated side-by-side — a genuine benefit for an ecosystem of 60+ packages. But **requiring** this format for all packages (especially small primitives where 4 bullets would be padding) over-constrains. For example, `swift-buffer-ring-inline-primitives` might have only 2 features of note — "Fixed-capacity FIFO" and "~Copyable" — and padding to 4 bullets would dilute.

**Diagnosis**: **Over-prescriptive**. Relax from MUST to SHOULD; permit H3 "feature-as-subsection-with-example" as an alternative; permit prose for small packages. The bold-keyword bullet format remains the recommended form for Key Features *when included*.

---

### Section 7 — Architecture Diagrams

**Current skill rule** ([README-010]): Multi-module or layered packages MUST include an ASCII layer diagram; simpler packages MAY use a key types table.

**Survey findings** (`Verified: 2026-04-21`):

| Package | Diagram present? | Form |
|---------|-----------------|------|
| All 15 surveyed READMEs | **No ASCII layer diagrams anywhere** | — |
| swift-nio | Text-based "Conceptual Overview" discussing `EventLoop`, `Channel`, `ChannelPipeline` — no diagram | Prose |
| swift-collections | Module bullets linking to DocC | Links to DocC for visual |
| swift-composable-architecture | Embedded image (`<img ... demos.png>`) — navigation thumbnail for example apps | Navigational image, not architecture |
| swift-parsing | Benchmark tables, code contrast examples | No diagram |
| swift-crypto | Textual "Implementation" section describing BoringSSL vs CryptoKit duality | Prose |

**Contextualization step**: ASCII layer diagrams are virtually absent from first-class Swift OSS. swift-property-primitives' intra-package target-graph diagram (`┌── Property Primitives (umbrella) ──┐ ...`) is a genuinely useful visual — it shows the variant decomposition that the umbrella/variant-product structure encodes. However, requiring an ASCII diagram for "multi-module or layered packages" is not aligned with practice, and the term "layered" itself invites the scope-boundary violation flagged in Section 4 (ecosystem-layer framing leaking into package READMEs).

**Diagnosis**: **Over-prescriptive**. Relax from MUST to SHOULD for multi-module packages. Reclassify "layered" to mean "intra-package layered" (target graph), not "ecosystem-layered" (Institute's five-layer position). Explicitly prohibit ecosystem-layer diagrams in sub-package READMEs (cross-references Section 4).

---

### Section 8 — Error Handling Section

**Current skill rule** ([README-013]): Packages using typed throws MUST include an Error Handling section with ASCII tree notation AND an exhaustive pattern-matching example.

**Survey findings** (`Verified: 2026-04-21`): **No surveyed README has an "Error Handling" section.** swift-system shows `try fd.writeAll(...)` but does not document the error tree. swift-nio describes error behavior inline in documentation but not in a dedicated section. swift-testing documents error trait usage but not an error-type hierarchy.

**Contextualization step**: This absence is **not a gap** — it is the tell of a design difference. The surveyed packages predominantly use `throws` (untyped) or `throws(any Error)`. Swift Institute's typed-throws-everywhere policy ([API-ERR-001]) creates a structurally different situation: a consumer handling `IO.Lifecycle.Error<IO.Error<File.Open.Error>>` cannot write correct exhaustive `catch` without knowing the full error tree. Documenting that tree in the README is ecosystem-specific value, not decoration.

**However**: requiring this section as MUST for *any* package with typed throws is too broad. A primitives package with one throwing initializer that throws `File.Error` (a one-case enum) gets no value from a three-line ASCII tree. The rule should scope to packages where the error shape is **non-trivial** — nested error types, generic error envelopes, or more than one throwing surface area.

**Diagnosis**: **Ecosystem-specific but over-broad**. Keep the rule, but narrow applicability: MUST only when the package exposes a non-trivial error shape (nested typed throws, generic error wrappers, or multiple throwing surface areas). SHOULD otherwise for any typed-throws API. Cross-reference [API-ERR-001].

---

### Section 9 — Platform Support Table

**Current skill rule** ([README-011]): Platform support MUST be expressed as a table with Platform, CI, and Status columns.

**Survey findings** (`Verified: 2026-04-21`):

| Package | Platform section? | Form |
|---------|-------------------|------|
| swift-nio | "Supported Platforms" + "Supported Versions" + "Swift Versions" table | Three separate tables (SemVer matrix, not ours) |
| swift-system | "Source Stability" table by platform type (Darwin/POSIX-like/Windows) | Platform-type tabular |
| swift-atomics | "Swift Releases" table (version-to-version matrix) | SemVer matrix |
| swift-collections | "Minimum Required Swift Toolchain Version" prose | Prose |
| swift-testing | Badges (two CI badges for main and 6.3 toolchain) | Badges only |
| SPI-badged packages (most) | Platforms communicated via `type=platforms` SPI endpoint badge | Badge auto-generated from SPI build results |
| Apple ecosystem packages in general | Platform support communicated through Swift versions and SPM minimums, not separate table | Prose or SPM block |

**Pattern**: No surveyed README uses a "Platform / CI / Status" three-column table matching our [README-011]. The closest match is swift-nio's "Swift Versions" SemVer matrix, which is more about *version compatibility* than *platform matrix*. Most rely on SPI badges to communicate platforms automatically.

**Contextualization step**: The SPI platforms badge auto-updates from SPI's actual build results — if the package builds on Linux, SPI shows Linux. A manually-maintained "Platform Support" table is, by contrast, prone to drift: the swift-property-primitives README says "macOS 26 / Linux / Windows" but this claim drifts when CI configuration changes. The table is also duplicative of the SPI badge in v1.0+ published packages.

However: pre-SPI packages (most Institute packages today, before the first tag) have no SPI badge yet. The table provides a human-readable compatibility statement when SPI data is not yet available.

**Diagnosis**: **Partially over-prescriptive**. Keep the rule but reduce to SHOULD. When the SPI platforms badge is present, the Platform Support table MAY be omitted (the badge is authoritative). When the package is pre-SPI or has platform subtleties the badge cannot convey (e.g., "Supported on iOS with caveats on watchOS"), keep the table.

---

### Section 10 — Alternatives Section

**Survey findings** (`Verified: 2026-04-21`):

| Package | Alternatives section | Content |
|---------|---------------------|---------|
| swift-dependencies | Yes (explicit H2 "Alternatives") | Lists Factory, Needle, Swinject, Weaver — competitor DI libraries |
| swift-parsing | Yes ("Other libraries") | Lists competitor parsing libraries |
| swift-composable-architecture | Yes ("Other libraries" at line 639) | Comparison with similar libraries |
| swift-crypto | Implicit via "Evolution" section — describes relationship to CryptoKit (parent) | Comparison with authoritative origin |
| swift-log | Community ecosystem section, not alternatives | — |
| All Apple core packages | No explicit Alternatives | — |

**Pattern**: Point-Free consistently includes Alternatives sections naming competitors without disparaging them. Apple core packages omit. This matches the evaluator's lens: for a library in a crowded problem space (DI, parsing, snapshot testing), the reader explicitly asks "why this one over the alternatives?" For a library with no credible alternative (stdlib extensions, atomics, numerics), the question doesn't arise.

**Current skill**: [README-015] lists "Why This Package?" as an optional section permitting comparison. This is under-documented. The Alternatives pattern deserves its own optional-section entry with clear inclusion criteria.

**Diagnosis**: **Missing documentation**. Add "Alternatives" as a named optional section. Inclusion criterion: when the package occupies a crowded problem space where the reader has a plausible competing choice.

---

### Section 11 — Motivation / Why Section

**Survey findings** (`Verified: 2026-04-21`):

| Package | Motivation section | Form |
|---------|-------------------|------|
| swift-async-algorithms | "## Motivation" (line 11) — 5 paragraphs on why the package exists | Narrative |
| swift-parsing | "## Motivation" (line 36) — baseline-contrast teaching pattern | Narrative + code |
| swift-dependencies | "## Overview" (line 32) — enumerates problems the package solves | Enumerated concerns |
| swift-crypto | "## Evolution" + "## Implementation" — why exists, how relates to CryptoKit | Narrative |
| Most Apple narrow-scope packages | No motivation section | — |

**Pattern**: Motivation sections appear when the package solves a problem whose existence is not self-evident from the package name. `swift-deque-primitives` doesn't need a motivation section — the name declares the motivation. `swift-dependencies` does, because "dependency injection in Swift" has 20 years of context and the reader needs to know why this one.

**Current skill**: [README-015] mentions "Design Philosophy" as optional. Motivation is a related but distinct concept. Add as named optional section.

**Diagnosis**: **Missing documentation**. Add "Motivation" as a named optional section. Cross-reference the baseline-contrast technique documented in Section 3.

---

### Section 12 — Badge Discipline

**Survey findings** (`Verified: 2026-04-21`):

| Package | Badge set | Count |
|---------|-----------|-------|
| swift-collections | SPI Swift versions + SPI platforms | 2 |
| swift-numerics | None | 0 |
| swift-async-algorithms | None | 0 |
| swift-syntax | None | 0 |
| swift-log | None (emoji-prefix bullets serve as visual marker) | 0 |
| swift-argument-parser | None | 0 |
| swift-system | None | 0 |
| swift-testing | Two CI badges (main + 6.3 toolchain) | 2 |
| swift-atomics | None (prose-first) | 0 |
| swift-crypto | None | 0 |
| swift-nio | SSWG graduated badge above title | 1 |
| swift-composable-architecture | CI + Slack + SPI versions + SPI platforms | 4 |
| swift-dependencies | CI + Slack + SPI versions + SPI platforms | 4 |
| swift-parsing | CI + Slack + SPI versions + SPI platforms | 4 |
| swift-snapshot-testing | CI + Slack + SPI versions + SPI platforms | 4 |

**Pattern**: Apple's practice is near-zero badges. Point-Free's practice is a consistent four-badge header (CI, Slack, SPI versions, SPI platforms). SSWG adds a maturity-level badge.

**Current skill**: [README-003] requires a Development Status badge (shields.io static). No top-tier Apple package uses this specific badge — it is a Swift Institute convention. Contextualization: the badge signals `active--development / stable / maintenance / experimental`, which usefully telegraphs ecosystem-internal maturity across 60+ packages. Apple's convention is to use `Source Stability` prose instead, which works for 10 packages but scales poorly to 60+. Keep the rule.

**Diagnosis**: **Ecosystem-specific but justified**. No change needed to badge rules [README-003]–[README-005].

---

### Section 13 — Package-Identity Emoji

**Survey findings** (`Verified: 2026-04-21`):

| Package | Title emoji | Justification |
|---------|------------|---------------|
| swift-atomics | `⚛︎︎` (atom symbol in H1) | Directly corresponds to package concept |
| swift-snapshot-testing | `📸` (camera, H1 prefix) | Directly corresponds to package concept |
| swift-log | Emoji-prefixed bullets (📚 🚀 🪪 🔒 🔀) — not in title | Typographic markers |
| All others | No emoji | — |

**Current skill**: No rule either permits or prohibits title emoji. Prior [README-007] prohibits emoji checkboxes in Key Features ("✅ Supports typed throws" anti-pattern).

**Pattern**: Apple practice is near-zero emoji. When emoji appears, it relates directly to the package's semantic identity (atoms, camera). Emoji decoration without semantic grounding is absent.

**Diagnosis**: **No rule needed**. Current skill correctly prohibits emoji-as-checkmark in Key Features. Title-level semantic-identity emoji is rare and harmless; adding a permissive rule is unnecessary cruft. Skip.

---

## Comparison Matrix

Distilling the findings into a single-view audit of the current skill:

| [ID] | Rule (summary) | Top-tier alignment | Ecosystem-specific? | Diagnosis |
|------|----------------|--------------------|---------------------|-----------|
| 001 | Required sections and ordering | Ordering not aligned (most put Installation after Quick Start) | Partial | **Relax**: allow early or late Installation |
| 002 | Maturity tiers | No external analog (scale-management) | Yes | Keep |
| 003 | Development status badge required | Not used externally | Yes | Keep |
| 004 | CI badge optional (only if passing) | Aligned | — | Keep |
| 005 | SPI badges recommended | Aligned (Point-Free, Apple) | — | Keep |
| 006 | One-liner requirements | Aligned | — | **Tighten**: add "opening contract" — first screen must land the evaluation |
| 007 | Key Features: 4–8 bold-keyword bullets | Partially aligned (~3/15 use this form) | Partial | **Relax**: SHOULD, permit prose or H3-with-example alternatives |
| 008 | Installation format (dep + target) | Aligned when included | — | Keep |
| 009 | Quick Start: 10–20 lines runnable | Aligned | — | **Tighten**: add "motivated example" requirement (Section 3) |
| 010 | Architecture: ASCII diagram for multi-module | Not aligned (no ASCII diagrams in surveyed corpus) | Partial | **Relax**: SHOULD; scope "layered" to intra-package |
| 011 | Platform support table | Not aligned (SPI badge substitutes) | Partial | **Relax**: SHOULD; omit when SPI badge present |
| 012 | Performance methodology | Aligned (swift-parsing benchmarks section) | — | Keep |
| 013 | Error Handling: ASCII tree + exhaustive match | Not aligned (absent externally) | Yes — typed throws | **Narrow**: MUST only for non-trivial error shapes |
| 014 | Related Packages organization | Partially aligned (NIO, TCA, PF packages use similar sections) | — | Keep |
| 015 | Optional sections catalog | Partially aligned | — | **Extend**: add Alternatives, Motivation as named sections |
| 016 | Prohibited content | Aligned | — | **Extend**: prohibit ecosystem-hierarchy content in sub-package READMEs |
| 017 | Formatting rules | Aligned | — | Keep |
| 018 | Monorepo root README | Aligned (swift-nio, swift-collections similar patterns) | Partial | Keep |
| 019 | Sub-package README (self-contained) | Aligned | Yes | Keep |
| 020 | GitHub org profile README | Not externally relevant at this level | Yes | Keep |
| 021 | Maintenance obligations | No direct analog; valid | Partial | Keep |
| 022 | Code examples in README | Aligned | — | **Tighten**: fold motivated-example requirement here |

**Additionally**, three meta-rules are missing entirely:

| Missing meta-rule | Source | Scope |
|-------------------|--------|-------|
| Evaluator's Lens | Maintainer seed; corroborated across all 15 surveyed READMEs | Whole-README discipline |
| Motivated Examples (Earn complexity) | Maintainer seed; corroborated by swift-atomics, swift-numerics, swift-system, swift-argument-parser, swift-testing | Code-example rule |
| Scope Boundary (package vs ecosystem) | Maintainer seed; corroborated by absence of ecosystem-hierarchy content in all 15 surveyed READMEs | Prohibited-content rule |

---

## Cognitive Dimensions Assessment ([RES-025])

Applying the Cognitive Dimensions Framework lightly, treating the README as the API surface of the package's documentation:

| Dimension | Current skill | Top-tier practice | Diagnosis |
|-----------|--------------|-------------------|-----------|
| **Visibility** | Section ordering fixed ⇒ readers know where to look | Variable ordering, but always within an evaluator-serving frame | Ordering constraint serves *authors* ("I always write X first"); evaluator's lens serves *readers* — relax ordering, add evaluator lens |
| **Consistency** | High (strict rule set) | Variable across packages | Ecosystem internal-consistency is a real benefit; preserve within 60+ packages even when diverging from external practice |
| **Viscosity** | Change-resistant: fixed ordering and mandatory sections make authoring painful when content doesn't fit | Authoring-flexible | Relaxing MUST → SHOULD reduces viscosity without losing consistency |
| **Role-expressiveness** | Each section has a clear role | Each paragraph has a clear role | Role-expressiveness should apply paragraph-by-paragraph via the Evaluator's Lens, not section-by-section |
| **Error-proneness** | Low: section missing is visible | Medium: authors can write prose that doesn't earn its place | The Evaluator's Lens rule catches errors the section-level rules miss |
| **Abstraction** | Right level: section = abstraction unit | Variable | Preserve |

**Conclusion**: The current skill optimizes for *section-level* visibility and consistency; top-tier practice optimizes for *paragraph-level* role-expressiveness. The two are complementary, not opposed. Add the Evaluator's Lens rule to capture the paragraph-level discipline without weakening the section-level scaffolding.

---

## Decisions

### Decision 1 — Add three meta-rules

| New rule (proposed ID) | Statement |
|-----------------------|-----------|
| **Evaluator's Lens** [README-023] | Every paragraph in a package README MUST serve the reader's evaluation question: *"Do I want to use this?"* Paragraphs that serve the author rather than the evaluator MUST be removed or moved to DocC, research documents, or blog posts. |
| **Motivated Examples** [README-024] | Every code example in a README MUST demonstrate something the package enables that is **impossible, awkward, or subtly wrong** to express without the package. Trivial call-sites whose non-library equivalent is identical are forbidden (e.g., `stack.inspect.count` when `stack.count` already exists). |
| **Scope Boundary** [README-025] | Sub-package READMEs MUST NOT include Institute-level ecosystem-hierarchy content (five-layer architecture diagrams, "where does this sit" positioning). Peer-package references (sibling packages, alternatives, parents with load-bearing relationships like swift-crypto ↔ CryptoKit) are permitted and encouraged where they serve the evaluator's lens. |

### Decision 2 — Relax four over-prescriptive rules

| Rule | Change |
|------|--------|
| [README-001] Required sections ordering | Split into (a) required *inventory* (Title, badge, one-liner, License — MUST) and (b) recommended *sequence* for remaining sections. Quick Start MAY precede Installation. |
| [README-007] Key Features format | Relax to SHOULD. Permit H3 "feature-as-subsection-with-code" alternative (swift-testing pattern). Permit prose for small primitives. |
| [README-010] Architecture ASCII diagram | Relax MUST to SHOULD for multi-module packages. Clarify "layered" means intra-package target graph, not ecosystem layer. |
| [README-011] Platform Support table | Relax to SHOULD. Explicitly: when a functional SPI platforms badge is present, the table MAY be omitted. |
| [README-013] Error Handling section | Narrow MUST to packages with non-trivial error shape (nested typed throws, generic error wrappers, multiple throwing surface areas). SHOULD for other typed-throws packages. |

### Decision 3 — Tighten two existing rules

| Rule | Change |
|------|--------|
| [README-006] One-liner | Add "opening contract": the first screen (H1 + one-liner + first badge block or first code example) MUST be sufficient for the reader to decide to keep reading. The opening contract is falsified when the first code example is unmotivated, when no one-liner is present, or when the first prose paragraph describes author-oriented content. |
| [README-022] Code examples | Cross-reference new [README-024] Motivated Examples. Add recommended "baseline-contrast" technique (show the problem without the library, then the library's solution — the swift-parsing pattern). |

### Decision 4 — Extend optional sections catalog ([README-015])

Add to named optional sections:

| Section | When to include |
|---------|----------------|
| **Motivation** | When the package solves a problem whose existence is not self-evident from the package name |
| **Alternatives** | When the package occupies a crowded problem space with plausible competing choices |

Update existing entries:

| Entry | Change |
|-------|--------|
| "Why This Package?" | Rename to "Alternatives" or merge; the current label invites marketing prose rather than comparative listing |
| "Design Philosophy" | Clarify this is distinct from Motivation: Design Philosophy answers "how does this package think?" while Motivation answers "why does this package exist?" |

### Decision 5 — Extend prohibited content ([README-016])

Add to the prohibited table:

| Prohibited | Reason | Alternative |
|-----------|--------|-------------|
| Institute-level ecosystem-hierarchy diagrams | Author-oriented; does not serve evaluator | Move to swift-institute.org DocC or monorepo root README |
| Implementation autobiography | "How this package evolved from an earlier internal tool …" — rarely earns its place | Blog, research document, CHANGELOG |
| Author's design reflections | Prose about choices made and why — belongs in research | `Research/` directory; DocC philosophy article |

### Decision 6 — Decision tests for judgment-call rules

Following the convention in `/code-surface` [API-NAME-001a], add **Decision test** blocks to rules where applicability requires judgment:

- [README-023] Evaluator's Lens — Decision test: "Could a reader considering this package skip this paragraph and still decide whether to adopt? If yes, it probably doesn't earn its place."
- [README-024] Motivated Examples — Decision test: "Write the shortest non-library-using equivalent of this call-site. If the non-library version is identical or trivially shorter, the example is unmotivated."
- [README-025] Scope Boundary — Decision test: "Does this sentence answer 'where this package fits in the architecture' or 'what this package does'? The former belongs elsewhere; the latter belongs here."
- [README-013] Error Handling narrowing — Decision test: "Count the distinct `catch` arms a correct exhaustive consumer must write. If ≤ 2, the error shape is trivial and the ASCII tree is unnecessary. If ≥ 3, document the tree."

### Decision 7 — Skill version bump

Per [SKILL-LIFE-003], this is a **Breaking** change:

- Three new MUST rules ([README-023]–[README-025]) where none existed before — previously-conforming READMEs containing ecosystem-hierarchy content or unmotivated examples will now be non-conforming.
- Five rules relaxed from MUST to SHOULD — additive in the relaxation direction (previously-conforming still conforms) but the skill is no longer enforcing the same strictness.

Recommended skill version: **v2.0.0** (major bump reflecting breaking addition of evaluator-lens rules). `last_reviewed` advances to 2026-04-21.

---

## Prescriptive Skill-Rule Changes (input to Part B)

This is the definitive punch-list for the skill update.

### New rules

| ID | Title | Kind | Classification |
|----|-------|------|----------------|
| [README-023] | Evaluator's Lens | MUST (whole-README meta) | Breaking addition |
| [README-024] | Motivated Examples (Earn Complexity) | MUST | Breaking addition |
| [README-025] | Scope Boundary (Package vs Ecosystem) | MUST for sub-package READMEs | Breaking addition |

### Rules to tighten

| ID | Change |
|----|--------|
| [README-006] | Add "opening contract" sub-clause: first screen must land the evaluation. |
| [README-022] | Cross-reference [README-024]; document baseline-contrast technique as permitted optional. |

### Rules to relax

| ID | Change |
|----|--------|
| [README-001] | Split required sections into inventory (Title, badge, one-liner, License — MUST) vs recommended sequence (all others SHOULD). Installation MAY follow Quick Start. |
| [README-007] | MUST → SHOULD. Permit H3 "feature-as-subsection" and prose alternatives. |
| [README-010] | MUST → SHOULD for multi-module. Clarify "layered" = intra-package. |
| [README-011] | MUST → SHOULD. Table MAY be omitted when SPI platforms badge is present. |
| [README-013] | Narrow MUST to non-trivial error shape (≥ 3 exhaustive catch arms). SHOULD otherwise. |

### Rules to extend

| ID | Change |
|----|--------|
| [README-015] | Add Motivation, Alternatives as named optional sections. Clarify Design Philosophy. Rename "Why This Package?" to "Alternatives" or merge. |
| [README-016] | Add three prohibited content types: Institute-level ecosystem-hierarchy diagrams in sub-package READMEs; implementation autobiography; author's design reflections. |

### Rules unchanged

[README-002], [README-003], [README-004], [README-005], [README-008], [README-009], [README-012], [README-014], [README-017], [README-018], [README-019], [README-020], [README-021] — all verified aligned with surveyed practice or justified as ecosystem-specific.

### Decision tests to add

- [README-013] — Count exhaustive catch arms
- [README-023] — Would a reader skip this?
- [README-024] — Non-library equivalent shorter?
- [README-025] — Architecture-position or capability description?

### Skill metadata

- Version: v1.0 → **v2.0.0** (breaking, per [SKILL-LIFE-003])
- `last_reviewed`: 2026-03-20 → **2026-04-21**
- Changelog entry: link to this research document as provenance ([SKILL-LIFE-002])

### Sync obligations

- Re-run `swift-institute/Scripts/sync-skills.sh`
- Verify symlink `.claude/skills/readme/SKILL.md` resolves
- Commit skill update as a separate commit from this research document

---

## Outcome

**Status**: RECOMMENDATION

The `/readme` skill's current 22 requirements are ~70% aligned with first-class Swift OSS practice. The remaining ~30% divides into:

- **Ecosystem-specific but justified** (typed-throws Error Handling, dev-status badge, `.github/profile/` pattern, maturity tiers): keep.
- **Over-prescriptive vs external practice** (fixed ordering, ASCII diagrams, bold-keyword Key Features, Platform Support table as MUST): relax to SHOULD.
- **Missing meta-rules that prevent the specific defects on `swift-property-primitives`**: Evaluator's Lens, Motivated Examples, Scope Boundary — add as MUST.

The resulting skill v2.0.0 retains ecosystem-internal consistency while gaining three paragraph-level discipline rules that address the maintainer's critique. The new rules have clear decision tests so they do not degenerate into taste-based enforcement.

This document is the input for Part B of `HANDOFF-readme-standard-research.md`. The subsequent package-README rewrite (`swift-primitives/swift-property-primitives/HANDOFF-readme-rewrite.md`) is explicitly out of scope for this research.

---

## References

### Surveyed READMEs (fetched 2026-04-21)

| Package | URL |
|---------|-----|
| swift-collections | https://github.com/apple/swift-collections/blob/main/README.md |
| swift-numerics | https://github.com/apple/swift-numerics/blob/main/README.md |
| swift-async-algorithms | https://github.com/apple/swift-async-algorithms/blob/main/README.md |
| swift-syntax | https://github.com/swiftlang/swift-syntax/blob/main/README.md |
| swift-log | https://github.com/apple/swift-log/blob/main/README.md |
| swift-argument-parser | https://github.com/apple/swift-argument-parser/blob/main/README.md |
| swift-system | https://github.com/apple/swift-system/blob/main/README.md |
| swift-testing | https://github.com/swiftlang/swift-testing/blob/main/README.md |
| swift-atomics | https://github.com/apple/swift-atomics/blob/main/README.md |
| swift-crypto | https://github.com/apple/swift-crypto/blob/main/README.md |
| swift-nio | https://github.com/apple/swift-nio/blob/main/README.md |
| swift-composable-architecture | https://github.com/pointfreeco/swift-composable-architecture/blob/main/README.md |
| swift-dependencies | https://github.com/pointfreeco/swift-dependencies/blob/main/README.md |
| swift-parsing | https://github.com/pointfreeco/swift-parsing/blob/main/README.md |
| swift-snapshot-testing | https://github.com/pointfreeco/swift-snapshot-testing/blob/main/README.md |

### Prior internal research

- `swift-institute/Research/readme-skill-design.md` (SUPERSEDED 2026-03-10) — original skill design, audited *internal* ecosystem READMEs. The present research audits *external* first-class OSS and specifically addresses the gaps surfaced by `swift-property-primitives` 0.1.0 pre-release feedback.
- `swift-institute/Research/documentation-skill-design.md` — separation decision between /readme and /documentation.

### Handoffs

- `swift-institute/HANDOFF-readme-standard-research.md` — the handoff that triggered this investigation.
- `swift-primitives/swift-property-primitives/HANDOFF-readme-rewrite.md` — the downstream package-README rewrite (Handoff B), explicitly out of scope for this research.

### Sibling research in the /code-surface family (decision-test pattern precedent)

- `Skills/code-surface/SKILL.md` [API-NAME-001a] — demonstrates the Decision test block form adopted by [README-023], [README-024], [README-025].

### External sources

- Stephen Whitmore, "Art of README" — https://github.com/hackergrrl/art-of-readme (cognitive funneling principle)
- Richard Littauer, "Standard Readme" — https://github.com/RichardLitt/standard-readme
- Swift Package Index — https://swiftpackageindex.com (SPI badge conventions; auto-generated platform reporting)
- Apple Swift API Design Guidelines — https://www.swift.org/documentation/api-design-guidelines/ (evaluator's lens has a parallel in the Guidelines' "clarity at the point of use" principle)
