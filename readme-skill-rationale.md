# Readme Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/readme/` (hub `SKILL.md` + six topic siblings), per the platform-skill archive pattern.
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> extra example variants, and the dated amendment changelog. The skill files remain the CANONICAL
> source for all `[README-*]` requirement statements; nothing in this archive is normative.
> Organized by rule ID grouped by source file, in skill order; the dated changelog entries are
> collected in the final §Changelog-Provenance section.

---

# Source: SKILL.md (hub)

## §Family-routing — Same org, multiple families (extra example tables)

For `swift-primitives` (leaf org):

| README | Family | Renders at |
|---|---|---|
| `swift-primitives/.github/profile/README.md` | G (leaf tier) | github.com/swift-primitives |
| `swift-primitives/swift-property-primitives/README.md` | E | github.com/swift-primitives/swift-property-primitives |
| `swift-primitives/swift-abi-primitives/README.md` | F | github.com/swift-primitives/swift-abi-primitives |

For `swift-standards` (org-of-orgs):

| README | Family | Renders at |
|---|---|---|
| `swift-standards/.github/profile/README.md` | G (org-of-orgs tier) | github.com/swift-standards |
| `swift-standards/swift-rfc-4122/README.md` | E | github.com/swift-standards/swift-rfc-4122 |

## §[README-023] Evaluator's Lens

**Rationale (full text)**: Section-level rules in each family file admit content that satisfies their local form but dilutes the reader's evaluation. The lens catches errors no section-level rule can. This rule generalizes the v2.0.0 [README-023] across all five families.

## §[README-026] No Internal Rule-ID Citations

**Rationale (full text)**: Rule IDs are author-side scaffolding for skill enforcement. They communicate which convention the author was applying — not what the artifact does or how it behaves. The reader does not have access to the rule body, and the citation reads as opaque jargon. Zero of 15 surveyed first-class Swift OSS READMEs cite internal convention IDs (`Research/package-readme-standard.md`).

**Provenance**: 2026-04-29 carrier README review (caught 2 rule-ID citations: `[MOD-015]`, `[PRIM-FOUND-001]`); `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md` #1.11.

**Lint-annotation provenance**: Annotation added 2026-05-13 (the script's check was authored earlier as part of Wave 2b finalization; the skill body just lacked the cross-reference).

## §[README-028] Speculative Family / Rule Validation Discipline

**Worked examples (canonical 2026-05-01 origin incident)**:

- README skill v3.0.0 design initially specified a 7-family taxonomy including Family B (local-disk clone-mirror grouping) and Family D (superrepo root). Both had zero existing instances. Family B accumulated ~1500 lines of skill content + 5 placeholder READMEs across 4+ design-discussion turns before user pushback exposed redundancy with Family G + `CLAUDE.md`. Family D was caught earlier but had similar speculative drift. Both were dropped to reach the v3.0.0 5-family taxonomy.
- Under this rule, both would have been flagged `speculative — pending validation` on day 1; the day-1 flag would have surfaced "no existing artifact justifies this work" before any sibling-skill content was authored.

**Rationale (full text)**: Speculative skill content carries three costs: (a) authoring time to write the rule body and worked examples, (b) maintenance cost across every refactor / cross-reference update / consistency pass, and (c) integrity cost — rules never validated against real instances accumulate plausible-sounding-but-wrong claims. The "no existing instances" signal is visible at design time; the rule converts that signal into a deferral that prevents downstream-detected drops.

**Provenance**: 2026-05-01 readme skill v3.0.0 design; Family B (clone-mirror) and Family D (superrepo) both proposed, drafted, then dropped after user skepticism caught the speculation. `Reflections/2026-05-01-readme-skill-family-v3-design-and-cleanup.md` — Pattern 1 "Speculation drift in skill design".

---

# Source: user-profile.md (Family A)

## §[README-120] Identity Line

**Rationale (full text)**: Recruiters and ecosystem visitors scan the top of the page first. The full-name H1 + bullet-separated roles tagline is the densest form of identity disclosure. The pattern is observed in `coenttb/coenttb/README.md` (the canonical instance) and matches conventions across high-engagement GitHub user profiles.

**Extra incorrect variant**:

```markdown
# Coen ten Thije Boonkkamp

I am a lawyer, Swift developer, and founder.  <!-- ❌ Prose where a tagline is sharper -->
```

## §[README-121] Mission Paragraph

**Rationale (full text)**: A mission paragraph is the load-bearing differentiator between a portfolio README and a personal README. Recruiters, collaborators, and prospects choose to engage based on alignment with the user's stated mission; vague missions don't enable that choice. The mission also frames the project section that follows — projects become "things in service of this mission" rather than "things I've built."

**Extra incorrect variant**:

```markdown
My mission is to build great software for everyone everywhere.  <!-- ❌ Mission so broad it could belong to anyone -->
```

## §[README-122] Flagship Projects Format

**Rationale (full text)**: The flagship-entry shape is the densest form of project signaling. Star count is a quick adoption proxy; the italicized tagline frames the project; the quantified claim provides substance; the bullets list capabilities. The pattern compounds: scanning the section, the reader builds a mental model of what the user has shipped at production quality.

**Extra incorrect variants**:

```markdown
- swift-html - Type-safe HTML.  <!-- ❌ No bold, no link, no highlights -->
```

```markdown
**[swift-bar](url)** (5 stars) - HTML library
- Fast
- Easy
- Powerful  <!-- ❌ Adjectives without claims -->
```

## §[README-123] Quantified-Claim Convention

**Rationale (full text)**: The italicized form is a marketing convention, and marketing without substance is forbidden by the universal evaluator's lens ([README-023]). The quantified-substance pairing rule preserves the convention's signaling value while preventing it from degenerating into hype. The pattern is observed throughout `coenttb/coenttb/README.md` and matches the discipline of `[README-006]` in `sub-package.md` (one-liner technical-substance requirement) generalized to portfolio entries.

**Extra correct variant**:

```markdown
*Production Swift website.* 100% Swift, type-safe from database to DOM.
```

**Extra incorrect variants**:

```markdown
*The best library ever.*  <!-- ❌ No substance -->
```

```markdown
*High-performance HTML rendering.* Carefully crafted for production use.  <!-- ❌ "Carefully crafted" is not a verifiable claim -->
```

## §[README-124] Professional Work Section

**Rationale (full text)**: Professional engagements are a signal of the user's domain credibility outside the open-source body of work. They also connect the mission to outcomes ("Bridging law and code for groundbreaking life sciences" frames the engagements as instances of the broader mission). The bulleted-link form makes verification trivial.

## §[README-125] Philosophy Section

**Rationale (full text)**: A philosophy section without grounding is hot air. With grounding, it tells the reader how the user reasons — which is sometimes the load-bearing fit signal for prospective collaborators. The pattern requires the user's body of work to back the beliefs, which prevents the section from drifting into platitudes.

**Extra incorrect variant**:

```markdown
**Core beliefs:**
- You should learn Swift  <!-- ❌ Prescriptive to the reader -->
- Apple is the best platform  <!-- ❌ Tribal claim with no technical substance -->
```

## §[README-126] Recent Writing Section

**Rationale (full text)**: Writing is a signal of how the user thinks beyond what the projects show. Three to five pieces is enough to demonstrate range without consuming the page. The ordering (most-relevant-first) lets the reader stop at the first piece that catches their interest.

## §[README-127] Connect Block

**Rationale (full text)**: The connect block is the call-to-action affordance — readers who decided "yes, I want to engage" need a clear path. The channel diversity (website + social + professional) lets readers choose the one that fits their context.

## §[README-128] Closing Call-to-Action

**Rationale (full text)**: The closing call-to-action converts profile readers who reached the bottom into action-takers. The italicization and `Currently` framing signal that this is current availability — readers know to look here for opt-in status. The discipline of removing the section when not open to engagements prevents the README from carrying false signals.

---

# Source: process.md (Family C)

## §[README-130] Title + 1-Line Workflow Scope

**Rationale (full text)**: A process repo's identity is its role within an ecosystem. The title-cased role + parent-org-anchored 1-liner is the minimal contract. The pattern is consistent across the eight observed swift-institute process repos. Title-casing the proper noun (`Skills`, not `skills` or `swift-institute-skills`) signals that this is a named role, not just a package.

**Extra correct variant**:

```markdown
# Audits

Repository- and ecosystem-level audit reports for the [Swift Institute](https://swift-institute.org) ecosystem.
```

**Extra incorrect variant**:

```markdown
# Skills

The Swift Institute Skills repository.  <!-- ❌ Tautological; doesn't say what the workflow does -->
```

## §[README-131] Structure / What's Here Table

**Rationale (full text)**: Process repos are inventory — readers come looking for a specific artifact. A two-column path/role table answers that question scannably. Prose lists fail to scan. Single-column tables are equivalent to `ls`. The two-column shape is consistent across all eight observed swift-institute process READMEs.

**Extra correct variants**:

```markdown
## Directory structure

| Directory | Purpose |
|-----------|---------|
| `Draft/` | Posts being written or awaiting publication |
| `Review/` | Posts under review |
| `Published/` | Posts that have been published externally |
| `Series/` | Series plans grouping related posts |
```

```markdown
## What's here

| Path | Contents |
|------|----------|
| [`Swift Institute.docc/`](Swift%20Institute.docc) | The DocC catalog that becomes the public site — articles, blog, theme |
| [`Sources/`](Sources) | Stub Swift target used to generate the DocC symbol graph |
| [`Package.swift`](Package.swift) | Package manifest declaring the `Swift Institute` target |
| [`build-docs.sh`](build-docs.sh) | Local build script — produces a static site under `/tmp/si-docs` |
```

**Extra incorrect variant**:

```markdown
## Structure

| Directory |
|-----------|
| `Draft/` |
| `Published/` |    <!-- ❌ Single-column table; role missing — equivalent to `ls` output -->
```

## §[README-132] Overview Section (Optional)

**Rationale (full text)**: Three of eight observed process READMEs include an Overview (Audits, Research, Experiments); five do not (Skills, Scripts, swift-institute.org, Blog, Swift-Evolution). The pattern is "include when the role-context warrants a paragraph; omit otherwise." Making it optional matches observed practice.

**Extra correct variant (Overview earns its place — Research)**:

```markdown
## Overview

When a design decision has non-obvious alternatives, the reasoning is recorded here rather than lost in commit history. Each document captures the question, the options considered, and the outcome — so future readers can understand not just what was decided, but why.

Research documents are persistent and version-controlled. They are not internal drafts; they are part of the public record.
```

## §[README-133] Workflow / Process Section

**Rationale (full text)**: Process repos are operational artifacts; the workflow rules belong in the governing skill. Inlining the workflow creates a duplicate that drifts. The link-out pattern is consistent across observed process READMEs (Audits → audit skill, Blog → blog-process skill, Swift-Evolution → swift-evolution skill, Research/Experiments → swift-institute.org dashboard). The Swift-Evolution rule-ID citation is a real instance of [README-026] being violated; the corrected form is archived below.

**Extra example variant — when a dashboard is the canonical browse view (Research, Experiments)**:

```markdown
## Browse

The canonical browsable view of this corpus is the [Research dashboard](https://swift-institute.org/dashboard/#research) on swift-institute.org — filterable by status, tier, and scope, with full-text search across titles and topics.
```

**Extra example variant — when the workflow is external (Swift-Evolution defers to the official Swift Evolution process)**:

```markdown
## Process

The pitch phase is documented in the [`swift-evolution`](https://github.com/swift-institute/Skills/blob/main/swift-evolution/SKILL.md) skill. Formal proposal, review, and implementation phases follow the official [Swift Evolution process](https://github.com/swiftlang/swift-evolution/blob/main/process.md) without additional institute-level convention.
```

**Corrected form of the observed rule-ID-citation defect** (names the workflow phases by their role rather than by rule ID):

```markdown
## Process

The pitch phase is documented in the [`swift-evolution`](...) skill — triggers, evidence requirements, scope analysis, drafting, submission, iteration, and bidirectional evidence links. Formal proposal, review, and implementation phases follow the official [Swift Evolution process](...) without additional institute-level convention.
```

## §[README-134] Companion Repositories Table

**Rationale (full text)**: Process repos in the swift-institute org form a network — Skills governs Audits, Research backs Experiments, Blog draws from Research. Cross-linking the network in each repo's README orients arriving maintainers without requiring them to navigate the org page. Five of eight observed process READMEs include this section.

**Extra correct variant**:

```markdown
## Related Repositories

| Repository | Contents |
|------------|----------|
| [Research](https://github.com/swift-institute/Research) | Design rationale, trade-off analyses, and post-session reflections |
| [Experiments](https://github.com/swift-institute/Experiments) | Standalone Swift packages backing technical claims in the website's articles and blog |
```

## §[README-135] Layout Assumption

**Rationale (full text)**: The current Scripts/README.md documents this layout explicitly because its `sync-*.sh` scripts use `~/Developer/<org>/` paths. Without the layout block, a fresh maintainer cannot run the scripts. No other observed process repo includes this section because no other observed process repo runs scripts that depend on disk layout.

## §[README-138] Length Budget

**Rationale (full text)**: Process READMEs are orientation, not documentation. A reader scans them on arrival. The ~50-line ceiling preserves scannability and forces longer content into its proper home (governing skill, DocC, Research). All eight observed process READMEs sit comfortably within the budget.

**Observed lengths in swift-institute process repos**:

| Repo | Lines | Within budget? |
|---|---|---|
| Audits/README.md | 22 | ✓ |
| Skills/README.md | 26 | ✓ |
| Research/README.md | 28 | ✓ |
| Swift-Evolution/README.md | 31 | ✓ |
| Blog/README.md | 35 | ✓ |
| Experiments/README.md | 36 | ✓ |
| Scripts/README.md | 50 | ✓ (at the upper edge — justified by the layout-assumption block) |
| swift-institute.org/README.md | 50 | ✓ |

---

# Source: sub-package.md (Family E)

## §[README-024] Motivated Examples (Earn Complexity)

**Correct example (evicted variant — earns its complexity; the resource-management shape of `closeAfter` is exactly what a reader uses swift-system for)**:

```swift
import SystemPackage

let path: FilePath = "/tmp/log"
let fd = try FileDescriptor.open(path, .writeOnly, options: [.append, .create], permissions: .ownerReadWrite)
try fd.closeAfter {
    _ = try fd.writeAll("Hello, world!\n".utf8)
}
```

**Rationale (full text)**: The anti-pattern — showing an API surface whose non-library equivalent is trivially identical — was the first concrete critique that triggered the v2.0.0 skill revision (maintainer critique on `swift-primitives/swift-property-primitives/README.md` @ `bab5c3f`, 2026-04-21). Motivated examples are the near-universal practice across surveyed first-class Swift OSS: 8 of 15 packages show a first example that would be impossible, awkward, or subtly wrong without the library. See `Research/package-readme-standard.md` §3.

## §[README-025] Scope Boundary (Package vs Ecosystem)

**Correct example (evicted variant — peer references serve the evaluator)**:

```markdown
## Related Packages

- [swift-kernel-primitives](url) — Typed kernel syscall wrappers, used by this package for descriptor lifecycle.
- [swift-io](url) — High-level I/O executor built on swift-property-primitives' `~Copyable` patterns.
```

**Rationale (full text)**: None of the 15 surveyed top-tier Swift OSS READMEs include parent-ecosystem hierarchical positioning. Peer-package references (sibling packages, parents via load-bearing comparison, competitors) are common and aligned with the evaluator's lens. The Institute's five-layer architecture is load-bearing at the Institute level but does not serve the sub-package evaluator's decision, since the decision does not depend on which layer the package occupies — the evaluator will observe that from the dependency graph regardless. See `Research/package-readme-standard.md` §4.

## §[README-027] Stability Section Operational Form

**Incorrect example (evicted — mixes evaluator SemVer with internal-implementation rationale + speculative migration choreography)**:

```markdown
## Stability

**Source-stability commitment for 0.x**:

- The public initializer surface is intended to be source-stable through 1.0.
- Internal storage shapes (`_pointer` / `_owner` / `_storage` fields, hoisted state-constant modules, fileprivate helper classes) are implementation details and free to change. <!-- ❌ Internal-implementation listing in consumer prose -->
- The `Foo.Bar.\`Protocol\`` capability typealias and its hoisted `__Foo_Bar_Protocol` backing exist to work around SE-0404 (no nested protocols inside generic types). <!-- ❌ Workaround rationale -->

**Migration to stdlib SE-XYZ**:

When SE-XYZ stabilises in stdlib, this package will:
1. Deprecate `Foo.Bar` in favour of stdlib `Bar<T>`.
2. Provide a migration guide and a deprecation window of at least one minor version.  <!-- ❌ Future-migration choreography asserted as plan -->
...

**Known accepted-as-known constraints in 0.1.0**:

- `Foo.Bar.init(borrowing:)` for `Copyable Value` heap-allocates a class-owned copy. The cost is documented inline; the workaround is required by the pre-SE-XYZ toolchain.  <!-- ❌ Workaround rationale; the consumer needs the cost, not the WHY -->
```

**Rationale (full text)**: Pre-1.0 infrastructure packages have a real evaluator question — "will my code break in 0.x?" — that the development-status badge alone doesn't fully answer. But the question's scope is operational: which surfaces can I rely on, which aren't yet committed. Internal-implementation rationale, deprecation plans for proposals still in evolution, and accepted-as-known workaround narratives all answer different questions (contributor's "why is the package shaped this way" question, not the consumer's "what may I rely on" question), and they belong in `Research/` or DocC philosophy articles, not in the consumer-facing README.

**Provenance**: `swift-institute/Research/cohort-readme-evaluator-pass.md` — Ownership Stability/Migration/Constraints section was the canonical instance triggering this rule (50+ lines mixing evaluator SemVer with workaround rationale and SE-0519 migration choreography). 3-round Claude/ChatGPT collaborative discussion 2026-05-01.

## §[README-001] Required Inventory and Recommended Sequence

**Correct example (evicted variant — utility package, Installation precedes Quick Start)**:

```markdown
# swift-kernel-primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Typed kernel syscall wrappers.

## Installation
...

## Quick Start
...

## License
Apache 2.0. See [LICENSE](LICENSE).
```

**Rationale (full text)**: The fixed ordering in v1.0 was not aligned with top-tier Swift OSS: 13 of 15 surveyed READMEs place Installation after the first code example. The required inventory preserves consistent scannability (the first three visible pieces are always Title/badges → one-liner → License-at-end) while permitting the Quick-Start-first pattern that dominates external practice. See `Research/package-readme-standard.md` §1.

## §[README-002] Maturity Tiers

**Rationale (full text)**: The ecosystem has many packages. Requiring full READMEs for all packages immediately is impractical. Tiers provide a clear upgrade path while ensuring every package has at minimum: identity (title + badge), purpose (one-liner), usability (installation), and legal clarity (license).

## §[README-015] Optional Sections

**Rationale (full text)**: Top-tier Swift OSS uses Motivation and Alternatives as distinct named sections (swift-async-algorithms, swift-parsing, swift-dependencies, TCA) where the prior v1.0 catalog merged them under the catch-all "Why This Package?" label. The rename clarifies author intent and aligns with external practice. See `Research/package-readme-standard.md` §10, §11.

## §[README-016] Prohibited Content

**Worked example for the compatibility-claim row (the origin incident, 2026-05-08)**: `swift-standard-library-extensions` 0.1.0 README claimed "Embedded-compatible" before any Embedded build had run. Phase 2 audit's `P-02` finding cited the README's claim as RESOLVED based on grep for `import Foundation`. Post-flip CI surfaced 4 Embedded source-guard violations (concurrency surface) — the claim was structurally unfalsifiable on the evidence supplied. The README's claim, the audit's RESOLVED, and the actual build state were three independent statements never reconciled until CI did so for them.

**Rationale (full text)**: The v2.1.0 prohibitions codify the maintainer's critique of the first release-candidate README cohort: a sub-package README is about the package, not its position in the broader Institute architecture, its internal evolution, or the author's reasoning process. The compatibility-claim row (added 2026-05-08) extends this discipline: a positive consumer-facing claim must be backed by exercised evidence, not absence-of-disqualifier reasoning. See `Research/package-readme-standard.md` §4, §5.

## §[README-006] One-Liner and Opening Contract

**Extra correct variant**:

```
Convert HTML to PDF on Apple platforms using WKWebView. Processes 1,939 PDFs/sec continuous mode with 35 MB steady-state memory.
```

**Extra incorrect variants**:

```
The best I/O library you'll ever use!  <!-- ❌ Marketing without substance -->
```

```
This package is Layer 1 of the Swift Institute five-layer architecture.  <!-- ❌ Ecosystem-hierarchy framing, not a description of the package -->
```

**Worked example (canonical 2026-05-01 origin incident)**: `swift-geometry-primitives/README.md` one-liner read "composes affine, region, dimension, and numeric primitives" — 4 of 7 actual `Package.swift` deps. The unlisted 3 (point, dimension-conversion, vector) were not marked as subset, so the prose read as the full dep set. Cost of the lookup at write time: seconds (`grep -c '\.package(' Package.swift`); cost of correction across already-shipped READMEs: linear in citation sites.

**Rationale (full text)**: Technical precision in descriptions enables accurate package selection and comparison. The opening contract addresses a defect observed in ecosystem READMEs where the first paragraph describes ecosystem positioning rather than the package itself. The composition-claim sub-rule extends the precision discipline: a partial list rendered without subset-marking is a count-claim defect indistinguishable from miscount. See `Research/package-readme-standard.md` §2, §5.

## §[README-007] Key Features Format

**Alternative-form example — feature-as-subsection-with-example (each H3 has a 3–10-line demonstration)**:

````markdown
## Feature overview

### Clear, expressive API

The `#expect` macro captures evaluated values on failure.

```swift
@Test func helloWorld() {
  let greeting = "Hello, world!"
  #expect(greeting == "Hello")  // Expectation failed: (greeting → "Hello, world!") == "Hello"
}
```

### Custom test behaviors

Traits describe runtime conditions...
````

**Alternative-form example — prose (for small primitives whose feature inventory would otherwise pad)**:

```markdown
`Buffer.Ring.Inline<E, N>` is a fixed-capacity FIFO ring buffer with value semantics and `~Copyable` support. The `N` parameter is a compile-time `Int` (value generic).
```

**Rationale (full text)**: The bold-keyword bullet pattern enables quick scanning across many packages, but was over-prescriptive for small primitives (where padding to 4 bullets dilutes) and for packages whose features are best shown inline with code (swift-testing's pattern). See `Research/package-readme-standard.md` §6.

## §[README-008] Installation Format

**Rationale (full text)**: Copy-paste-ready installation blocks reduce integration friction. Both blocks are needed because SPM requires separate dependency and target configuration. Tag-vs-branch pin form is consumer-facing state, not author-facing aspiration: a snippet that resolves to a non-existent tag shifts the failure mode from a clean build error to an obscure SPM error message that the consumer cannot diagnose without knowing the package's release history.

**Provenance**: 2026-05-01 swift-property-primitives 0.1.0 launch; cohort-wide pre-tag `from: "0.1.0"` snippets across 4 cohort READMEs (property, carrier, tagged, ownership) were corrected to `branch: "main"` mid-launch when no tags existed yet. The pattern is recurring across the swift-primitives 0.1.0 cohort, not a one-off. `Reflections/2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md`.

## §[README-010] Architecture Section

**Incorrect example (evicted verbatim — ecosystem-layer framing, [README-025] violation)**:

```
Layer 5: Applications
Layer 4: Components
Layer 3: Foundations
Layer 2: Standards
Layer 1: Primitives      ← swift-property-primitives
```

This is an Institute-level ecosystem diagram that belongs at swift-institute.org or in the org profile README [README-020], NOT in a sub-package README.

**Rationale (full text)**: ASCII layer diagrams were virtually absent in surveyed first-class Swift OSS (0 of 15). The diagram is genuinely useful when it documents *this package's* target graph (e.g., a multi-variant primitives package with an umbrella + variant decomposition). It is a defect when it documents the Institute's ecosystem layering, which is author-oriented content that the evaluator does not need. See `Research/package-readme-standard.md` §7. The v2.1.0 earning sub-rule extends the discipline: even the intra-package decomposition is contributor content if the rows don't map to consumer choices. Provenance: `swift-institute/Research/cohort-readme-evaluator-pass.md` 2026-05-01.

## §[README-011] Platform Support Table

**Rationale (full text)**: The three-column "Platform / CI / Status" form is not present in surveyed top-tier Swift OSS; most rely on the SPI platforms badge. A manually-maintained table drifts when CI configuration changes, creating a false-confidence trap. The relaxation preserves the useful content for pre-SPI packages while removing duplicative maintenance for published packages. See `Research/package-readme-standard.md` §9.

## §[README-013] Error Handling Section

**Rationale (full text)**: Visual error hierarchies are ecosystem-specific value: the typed-throws-everywhere policy ([API-ERR-001]) means consumers cannot write correct exhaustive `catch` without knowing the full tree. However, requiring this section for *any* typed-throws package is over-broad: a primitives package with one throwing initializer and a one-case error enum gains nothing from an ASCII tree. The narrowing to non-trivial shapes preserves the value while eliminating the padding. No surveyed top-tier Swift OSS package has this section at all — this is genuinely ecosystem-specific content. See `Research/package-readme-standard.md` §8.

## §[README-014] Related Packages Organization

**Rationale (full text)**: Structured dependency documentation enables package graph traversal. The public + tagged constraint prevents the README from advertising URLs that 404 for external readers and packages that don't ship yet — both common defects in pre-release ecosystems where Related Packages tends to grow ahead of the actual sibling-shipping pace.

**Provenance**: 2026-04-29 carrier README cleanup (caught 4 unreleased private-repo links: swift-tagged-primitives, swift-cardinal-primitives, swift-ordinal-primitives, swift-hash-primitives); `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md` #1.12.

## §[README-022] Code Examples in README

**Extra correct variant**:

```swift
import IO

let connection = try Network.Connection(host: "api.example.com", port: 443)
```

**Extra incorrect variant**:

```swift
// ❌ Unmotivated example — `stack.count` already does this
let size = stack.inspect.count
```

**Rationale (full text)**: Complete, realistic examples demonstrate actual usage patterns and enable immediate verification. The motivated-examples cross-reference ([README-024]) closes the gap that allowed examples whose baseline equivalent is trivially identical. The baseline-contrast technique is the single sharpest teaching pattern observed in the surveyed corpus. See `Research/package-readme-standard.md` §3.

## §[README-019] Sub-Package README is Self-Contained

**Rationale (full text)**: Developers often land on a sub-package README via search or link. A self-contained README serves them without requiring navigation to the org profile, the local-disk grouping, or a sibling repo. Every Swift package is a single GitHub repo; the installation URL points directly to the package, not via any parent. Updated in v3.0.0 to reflect the workspace's actual one-repo-per-package topology (the v2.1.0 example used a `swift-primitives/swift-primitives` URL that does not exist).

## §[README-040] Community Section

**Provenance**: Skill-design discussion 2026-05-10; same-day setup of `swift-institute/.github` discussions surface and "Packages" category.

---

# Source: placeholder.md (Family F)

## §Family-F-context — Why This Family Exists (full text)

Without explicit Family F rules, two anti-patterns emerge in production:

1. **Silent under-documentation**: A package has working code but a 3-line README with no status, no installation, no usage. The evaluator cannot tell whether the package is implemented but undocumented, partially implemented, or a stub. Observed instances in the swift-primitives org include `swift-parser-primitives/README.md`, `swift-decimal-primitives/README.md`, `swift-geometry-primitives/README.md`, and `swift-algebra-linear-primitives/README.md` — each currently reads only:

   ```markdown
   # {Title}

   Swift Embedded compatible.
   ```

   These are not legitimate Family F READMEs. They are Family E packages below the [README-002] Minimum tier. They MUST graduate to a proper Family E README (title + status badge + one-liner + Installation + License) per [README-153], or — if the package is genuinely a placeholder — adopt the Family F status form per [README-150]. *(Restated in-skill: the MUST-graduate obligation is normatively carried by [README-153] / [README-150] and summarized in the trimmed "Why This Family Exists" section.)*

2. **Scaffold without disclosure**: A package was created as a namespace reservation but the README does not say so. Consumers may attempt to depend on it, then discover at compile time that there is no public API. The Family F status block ([README-150]) prevents this by making the package's state load-bearing in the README's first 5 lines.

Family F rules ensure that a placeholder declares itself as such, leaving no ambiguity for the evaluator.

## §[README-150] Minimum Content

**Extra correct variants**:

```markdown
# Hash Primitives

> **Status: Pre-implementation** — Reserved for the hash function family (xxHash, FNV-1a, SipHash). No public API yet; design is being driven by `swift-institute/Research/hash-function-tradeoffs.md`. Do not add this as a dependency.
```

```markdown
# Foo Primitives

> **Status: Archived** — This package was superseded by [Bar Primitives](https://github.com/swift-primitives/swift-bar-primitives) on 2026-04-15. Existing consumers should migrate; new consumers should depend on Bar Primitives directly.
```

**Extra incorrect variant (under-documented, no Status block — observed instance)**:

```markdown
# Parsing Primitives

Swift Embedded compatible.
```

This README is not a legitimate Family F document. The package either has working code (graduate to Family E [README-002] Tier 1 with a proper one-liner, badge, Installation, and License) or is a placeholder (add a `> **Status: …**` block per [README-150]).

**Rationale (full text)**: The `> **Status: …** — explanation` form was first observed in `swift-primitives/swift-abi-primitives/README.md` (2026-04 vintage) and is the only legitimate placeholder shape that satisfies the evaluator's question without inviting accidental adoption. The blockquote form visually distinguishes the README from a normal package README — readers see the formatting and recognize "this is metadata, not documentation."

## §[README-151] Status Vocabulary

**Provenance**: `Unnecessary` is observed in production (`swift-primitives/swift-abi-primitives/README.md`). The other three values are specified here based on the observed lifecycle states packages can occupy; they have not yet been observed in production READMEs and SHOULD be adopted as packages enter those states.

## §[README-152] Explicit Scaffolding Signal

**Extra incorrect variants**:

```markdown
# ABI Primitives

ABI Primitives is a namespace for ABI-related types.

> **Status: Unnecessary** — ...    <!-- ❌ Preamble suggests the package is documented; status is buried -->
```

```markdown
# ABI Primitives

## Status

Unnecessary. This package is a namespace reservation...    <!-- ❌ Section heading suggests there are other sections -->
```

**Rationale (full text)**: The blockquote `>` rendering pulls the eye and visually labels the entire content as metadata. The single-paragraph form keeps the README minimal — a reader scanning the rendered page sees nothing else and correctly concludes there is nothing else to see. Section headers (`## Status`) imply other sections exist; the blockquote form rules them out.

## §[README-153] Graduation Criteria

**Anti-pattern observed**: The four `swift-*-primitives` packages whose READMEs read only `# {Title}\n\nSwift Embedded compatible.` (parser, decimal, geometry, algebra-linear) are NOT placeholders by this rule — they have working modules. They are Family E packages below Tier 1 that need to graduate.

---

# Source: org-profile.md (Family G)

## §Family-G-context — Observed state, tier rationale, and provenance

**Scope state (observed 2026-05-01, evicted from the trimmed Scope paragraph)**: Today three org profiles exist: `swift-institute/.github/profile/README.md` (top-level tier, well-developed), `swift-standards/.github/profile/README.md` (org-of-orgs tier, has prose but missing inventory), `swift-primitives/.github/profile/README.md` (leaf tier, at observation time a 1-line stub with the wrong title — `# Swift Institute` instead of `# Swift Primitives`). Several missing: `swift-foundations`, `swift-nl-wetgever`, `swift-us-nv-legislature`, `swift-law`, `rule-law` per-org profiles do not yet exist. (Superseded same-day: see §[README-161] known-state table below — swift-primitives/swift-standards updated and swift-foundations created on 2026-05-01.)

**Why three tiers exist (full closing text)**: The three tiers serve different evaluator questions. A visitor to `github.com/swift-institute` wants to understand the ecosystem; a visitor to `github.com/swift-standards` wants the spec coverage; a visitor to `github.com/swift-primitives` wants to find a primitives package. Same family, different content because the visitor's purpose differs.

**Provenance (per-tier reference instances, observed 2026-05-01)**:
- Top-level tier: `swift-institute/.github/profile/README.md` (59 lines) is the canonical reference.
- Org-of-orgs tier: `swift-standards/.github/profile/README.md` (30 lines) is the partial reference; the missing sub-category grouping and package inventory ([README-106], [README-108]) are documented gaps.
- Leaf tier: `swift-primitives/.github/profile/README.md` (1 line) was a stub with the wrong title; the leaf-tier rules describe the recommended shape rather than mirror an existing example.

## §[README-020] Org Profile README Structural Baseline

**Rationale (full text)**: The org profile is navigation, not documentation. Its job is to orient the visitor and route them to the right repo or sub-org. Borrowing per-package conventions creates the false impression that the org-page itself is something to install or import.

## §[README-115] Visibility Markers on Linked Repos

**Rationale (full text)**: Org profile READMEs are the front door for the ecosystem. Broken links read as carelessness. The blockquote-disclosure pattern handles the common case of staged releases (the swift-institute profile's "Release in progress" pattern) without requiring per-link maintenance during a rollout. (The blockquote form is observed in `swift-institute/.github/profile/README.md`.)

## §[README-117] Tier-Aware Navigation

**Rationale (full text)**: The three tiers form a graph that visitors traverse. Each org profile being a navigation node — pointing at adjacent tiers — lets visitors recover from arriving at the wrong page. The pattern is observed in swift-institute's profile and SHOULD be replicated in the leaf-org and org-of-orgs profiles. *(The SHOULD-replicate recommendation is carried normatively by the rule Statement's SHOULD.)*

**Correct example (evicted variant — leaf pointing up, for a hypothetical swift-primitives leaf-org profile)**:

```markdown
## Part of Swift Institute

swift-primitives is the Layer 1 organization within the [Swift Institute](https://github.com/swift-institute) ecosystem — atomic building blocks the rest of the stack composes against. See the [ecosystem overview](https://swift-institute.org) for the full layered architecture.
```

## §[README-100] Ecosystem Brain Pitch

**Rationale (full text)**: Top-level orgs justify their existence by the value of coordination — without that justification, the ecosystem reduces to a directory of unrelated packages. The pitch makes the coordination visible.

## §[README-101] Process-Repo Inventory

**Rationale (full text)**: A flat process-repo list creates a "what's here" inventory. An intent-driven table creates a routing affordance — visitors arriving with a question (mission alignment, technical receipts, security) get directed to the right artifact. The intent-driven shape is observed in swift-institute's "Where to go next" table.

## §[README-102] Outward Links to Domain Umbrellas

**Rationale (full text)**: Top-level orgs are the entry point for visitors who don't know which leaf org holds what they need. Outward links make the entry point useful. The dual presentation (layer table + org-of-orgs disclosure paragraph) matches the swift-institute profile's observed shape and is the recommended form.

## §[README-103] No Package Catalog at the Top Level

**Correct example (evicted)**:

```markdown
| Layer | Organization | Role |
|-------|--------------|------|
| 1 | [swift-primitives](https://github.com/swift-primitives) | Atomic building blocks |  <!-- ✓ Points to the leaf org; the leaf org has the package catalog -->
```

**Rationale (full text)**: Top-level orgs do not host code; they coordinate. A package list at the top level invites the visitor to expect installable artifacts, which the top-level org doesn't provide. Routing to the leaf orgs lets each tier's profile do its job.

## §[README-105] Domain Pitch

**Rationale (full text)**: Org-of-orgs justify their existence by the unifying domain principle. Without it, the umbrella reduces to a flat list of unrelated specs. The pitch makes the principle the load-bearing claim — the same way a top-level org's pitch makes coordination load-bearing.

## §[README-106] Sub-Category Grouping

**Anti-pattern observed**: `swift-standards/.github/profile/README.md` (2026-05-01) has substantial Overview and Technical Approach sections but NO sub-category grouping or package inventory. A visitor cannot tell from the README what specs the umbrella covers. This is a real gap to close.

**Rationale (full text)**: Org-of-orgs are useful precisely because they organize a domain. Hiding the organization (no sub-category sections, no inventory) defeats the umbrella's purpose. The visitor came looking for spec X; the README must answer whether spec X is covered.

## §[README-107] Outward Links to Leaf Orgs

**Rationale (full text)**: Org-of-orgs are conceptual — visitors arrive expecting to find code, but the actual code lives in the per-authority leaves. The link-out resolves this redirection in one click rather than requiring the visitor to guess which leaf org hosts what.

## §[README-110] Leaf Org Pitch

**Anti-pattern observed**: `swift-primitives/.github/profile/README.md` (2026-05-01) at observation time read only `# Swift Institute` — a 1-line stub with the **wrong title** (says "Swift Institute" instead of "Swift Primitives"). The stub is non-conforming on three counts: wrong title, missing 1-liner, missing pitch. This was a concrete cleanup target (updated same day; see §[README-161]).

**Rationale (full text)**: Leaf-org profiles compete for the visitor's attention with sibling leaves. The pitch makes the org's distinctive contribution visible. The "Part of <ecosystem>" framing prevents the visitor from concluding the leaf is a standalone project disconnected from its parent.

## §[README-111] Package Catalog Grouped by Tier or Domain

**Correct example (evicted variant — grouped by domain, recommended shape for swift-foundations)**:

```markdown
## Packages

Composed building blocks across multiple domains.

### Platform

| Package | Role |
|---|---|
| [swift-darwin](url) | Darwin platform integration |
| [swift-linux](url) | Linux platform integration |

### Web

| Package | Role |
|---|---|
| [swift-html](url) | Type-safe HTML DSL |
| [swift-css](url) | Type-safe CSS DSL |

### IO and networking

| Package | Role |
|---|---|
| [swift-io](url) | Async I/O executor |
| [swift-file](url) | File system operations |
```

**Rationale (full text)**: The catalog is the leaf org's primary navigation affordance. Visitors arrive looking for a specific capability ("which package handles HTML?"); the grouped table answers that question scannably. The grouping pattern matches the org's actual structure, preserving the visitor's mental model.

## §[README-112] Per-Package Consumer Install Pointer

**Rationale (full text)**: The one-repo-per-package convention is non-obvious. Visitors familiar with monorepo SPM packages may look for a parent install URL ("just depend on swift-primitives and import what you need"). The pointer disambiguates. The "see the package's README" link-out keeps maintenance bounded — the org profile isn't responsible for tracking each package's current version.

## §[README-113] Layered Architecture Diagram

**Correct example (evicted variant — ASCII diagram, when the layering is small and visualizable)**:

````markdown
## Architecture

```
┌─────────────────────────────────────┐
│   Layer 9 (composed across stack)   │
├─────────────────────────────────────┤
│   ...                               │
├─────────────────────────────────────┤
│   Layer 1 (atomic, no inter-deps)   │
└─────────────────────────────────────┘
```
````

**Rationale (full text)**: The layering is load-bearing for visitors choosing which packages to depend on (Tier 1 packages have minimal dependency footprints; higher tiers compose more). Surfacing the layering at the org profile prevents the visitor from learning it package-by-package. The single-source-of-truth (DocC catalog) link prevents the org profile and DocC from drifting.

---

# Source: ci-automation.md (CI/CD contract)

## §[README-160] Author / Automation Boundary

**Rationale (full text)**: Drift is the long-term cost of unmaintained sections. Without a fixed boundary, manual edits and CI regenerations interfere; sections fall out of date because nobody is responsible for them. The explicit-boundary discipline lets each side trust the other's contributions and reduces the cost of regenerating an inventory or running a lint.

## §[README-161] Presence Sweep

**Known state of Family G org profiles as of 2026-05-01** (the inaugural sweep target):

| Org | Path | State |
|---|---|---|
| swift-institute | `swift-institute/.github/profile/README.md` | Well-formed (canonical reference for the top-level tier per [README-100]–[README-103]) |
| swift-primitives | `swift-primitives/.github/profile/README.md` | Updated 2026-05-01 — was a 1-line stub with the wrong title; now a leaf-tier profile per [README-110]–[README-114] |
| swift-standards | `swift-standards/.github/profile/README.md` | Updated 2026-05-01 — added the sub-category grouping and inventory the org-of-orgs tier requires per [README-106], [README-108] |
| swift-foundations | `swift-foundations/.github/profile/README.md` | Created 2026-05-01 — leaf-tier profile per [README-110]–[README-114] |

## §[README-162] Structure Linter Contract

**Worked example (canonical 2026-05-01 origin incident)**: `swift-foundations/.github/profile/README.md` cited "129 packages" in 1-liner / opening / footer; the catalog itself listed 130; the actual disk count via `ls swift-foundations/swift-* | wc -l` was 137. Three different numbers shipped because no single source-of-truth check ran at any of the three citation points. Verification cost: seconds; correction cost: 8 targeted edits across one file (linear with citation breadth).

## §[README-163] Badge Format Validator

**Rationale (full text)**: Badges drift silently — a copy-pasted badge with the wrong owner/repo or a fabricated status value renders fine on the rendered page but signals incorrect package state. The validator catches these at PR time; SPI endpoint URLs in particular are easy to copy wrong (the `%3A` / `%2F` encoding is non-obvious).

## §[README-164] Installation-Snippet Currency

**Rationale (full text)**: The maintenance obligation in [README-021] requires installation snippets to match the latest release. Manual enforcement is unreliable across many packages. The currency check surfaces drift cohort-wide on a regular cadence (weekly, mirroring `link-check-weekly.yml`).

## §[README-165] Cross-Repo Path Link Validator

**Rationale (full text)**: Cross-repo references using filesystem-relative paths (`../`) are a workspace-internal convention that doesn't resolve when the README is rendered on GitHub. They should either be rewritten as fully-qualified `https://github.com/...` URLs (preferred) or flagged as workspace-only references (and not appear in public READMEs at all). The validator surfaces both cases.

## §[README-166] Inventory Auto-Generation

**Rationale (full text)**: Hand-maintaining a 60-row inventory across the swift-primitives org (or 13-row for swift-standards, or comparable for others) is brittle. A repo gets added, the inventory drifts. Auto-generation for the structural columns + author-owned roles preserves the editorial value of curated descriptions while removing the maintenance burden. The PR-based workflow (rather than direct push) keeps a human in the loop for reviewing role/grouping inferences when new packages are added.

## §[README-167] Reporting Shape

**Rationale (full text)**: Maintainers already triage tracking issues from sync-metadata-nightly and link-check-weekly; adding README-related findings to the same channel keeps the cognitive load low. The idempotent update pattern prevents notification noise (one issue per workflow per cadence, updated in place).

## §[README-168] Discussion-link auto-generation and validation

**Provenance**: Skill-design discussion 2026-05-10.

## §[README-170] Composed-Example Empirical Validation

**Why parse-only is structurally insufficient for composed examples (full text)**:

`swiftc -parse` validates that the example is grammatically Swift; it does NOT validate that the example uses real APIs in their real shapes. For a single-type example (`UUID()` initializer with no arguments), parse failure reliably catches authoring defects. For a composed example invoking 4+ typed APIs across different packages, every signature is a potential drift point — `Source.Location(file:line:column:)` is grammatically valid Swift even when the real API is `Source.Location(fileID:filePath:line:column:)`. Parse passes; the example wouldn't compile against the real types. Per [README-009] / [README-022], README examples are authoritative for evaluators; an example that parses but doesn't compile is worse than no example.

**Worked example (the origin incident)**:

A 2026-05-07 D1' branching dispatch authored a `swift-linter-primitives` README Quick Start composing `Source.Location` + `Diagnostic.Record` + `Lint.Rule.Protocol` + SwiftSyntax types. Initial draft used `Source.Location(file:line:column:)` based on inferred shape. `swiftc -parse` passed. Reading the underlying `Source.Location.swift` directly revealed the real init is `Source.Location(fileID:filePath:line:column:)` — the README would have shipped with a non-compiling Quick Start. The `swift-linter-rules/Sources/Linter Rule Try Optional/Lint.Rule.TryOptional.swift` real call site provided the exact `Source.Location(fileID:filePath:line:column:)` shape verbatim; citing the real call-site would have caught the defect at authoring time.

**Rationale (full text)**: The 4-of-5 swift-linter cohort README non-compile rate (per the 2026-05-07 pre-publishable discovery investigation) is the systemic gap [README-170] addresses at the per-example layer; [RELEASE-007] addresses the same gap at the release-readiness checklist layer. The two rules compose: per-example discipline catches the defect at authoring time; release-readiness discipline catches it at the publication-gate. The 30-second cost of a real-call-site grep per composed type is strictly cheaper than the post-publication rework cost when the README ships broken.

**Provenance**: Reflection `2026-05-07-d1-readme-and-driver-repair.md` (Source.Location signature catch in Quick Start authoring; recommended pattern: grep call-site shape against an existing real call-site).

---

# Changelog-Provenance

Dated changelog entries evicted from the skill files' bodies and frontmatter comments. Two clauses from the 2026-05-10 Wave 2b frontmatter entry were hoisted verbatim into rule bodies (noted inline): the [README-013] threshold-encoding clause (→ `sub-package.md` §[README-013] Lint enforcement) and the Decision-7 `readme.family` clause (→ `SKILL.md` §Family Routing Lint enforcement).

## SKILL.md frontmatter comments (evicted)

- 2026-05-10: Phase 3b TRIM-PROSE — compressed Rationale prose on [README-162] now that `validate-readme.yml` mechanically enforces. Statements unchanged per [SKILL-LIFE-001].
- 2026-05-10: Cluster C reflection-processing — added [README-028] speculative family/rule validation discipline; extended [README-006] composition-claim completeness; extended [README-008] pre-tag installation pin; extended [README-162] count-claim consistency lint per Reflections/2026-05-01-readme-skill-family-v3-design-and-cleanup.md and 2026-05-01-property-launch-and-cohort-readme-audience-inversion-sweep.md.
- 2026-05-10: Wave 2b finalization (HANDOFF-wave-2b-finalization.md) — added Lint enforcement notes for the family-routing rules now mechanically enforced by the new `validate-readme.yml` reusable workflow + companion `.github/scripts/validate-readme.py`. Workflow reads `readme.family` from each repo's `metadata.yaml` per Decision 7. [README-013] error-handling threshold encoded per Decision 5 (any public throws(NonNever) → ## Error Handling required). Clarifying per [SKILL-LIFE-003]. *(Both operative clauses hoisted into rule bodies as noted above.)*
- 2026-05-10: v3.1.0 — added [README-040] Community Section and [README-168] Discussion-link auto-generation per github-repository [GH-REPO-090..093].
- 2026-05-05: Track B Phase B-2 — `**Composite:**` annotations on 4 composite rules in siblings (sub-package.md, ci-automation.md) per HANDOFF-skills-quality-refactor-track-b.md

## sub-package.md frontmatter comments (evicted)

- 2026-05-10: Added [README-040] Community Section (auto-generated discussion-link marker block) per github-repository [GH-REPO-090..093].
- 2026-05-08: [README-016] extended with unverified-compatibility-claim row per session retrospective; cross-references [AUDIT-033] + [RELEASE-001b].
- 2026-05-05: Track B Phase B-2 — `**Composite:**` annotations on 3 composite rules per HANDOFF-skills-quality-refactor-track-b.md

## ci-automation.md frontmatter comments (evicted)

- 2026-05-10: [README-168] promoted from reserved to active rule (discussion-link auto-generation and validation) per github-repository [GH-REPO-092].
- 2026-05-05: Track B Phase B-2 — `**Composite:**` annotation on 1 composite rule per HANDOFF-skills-quality-refactor-track-b.md

## SKILL.md body `## Changelog` section (evicted verbatim)

### v3.1.0 — 2026-05-10 (Additive per [SKILL-LIFE-003])

**Provenance**: Skill-design discussion 2026-05-10 — centralizing public-package discussion threads at `swift-institute/.github`. Same-day setup of the discussions surface, "Packages" category, and swift-institute-bot App permissions (Discussions: Read & Write). Pilot scope: 11 swift-primitives packages, with `swift-carrier-primitives` and `swift-tagged-primitives` as canaries.

**Additions** (new MUST rules):

- [README-040] Community Section — public Family E packages MUST include a `## Community` section (between Maintenance and License) carrying an auto-generated discussion-link marker block. Cross-references the new [GH-REPO-090..093] rules in the **github-repository** skill.
- [README-168] Discussion-link auto-generation and validation — CI contract for keeping the README marker block synchronized with `metadata.yaml`'s `discussion:` field; reuses [README-167]'s tracking-issue reporting shape.

### v3.0.0 — 2026-05-01 (Breaking per [SKILL-LIFE-003])

**Provenance**: Ecosystem-growth observation by the principal on 2026-05-01: "our ecosystem is growing. also in terms of readme and metadata. we have coenttb personal readme, swift-institute/primitives/standards (and sub-orgs)/foundations readmes." A skill-design conversation converged on a five-family taxonomy with per-family voice registers, three org-tier sub-rules within Family G, and a navigation-hub structure.

**Shape change**: Monolithic skill (1107 lines, single file) → navigation hub + 6 topic siblings per [SKILL-CREATE-005a]. The hub holds workflow position, family routing, and the universal meta-rules ([README-023], [README-026]); siblings hold family-specific structural rules and voice sections.

**Family taxonomy** (new — every README belongs to exactly one):

| # | Family | Sibling | Existing IDs migrated | New ID range |
|---|---|---|---|---|
| A | User profile | `user-profile.md` | — | [README-120..129] |
| C | Process / workflow | `process.md` | — | [README-130..139] |
| E | Sub-package library | `sub-package.md` | [README-001..017], [README-019], [README-021], [README-022], [README-024], [README-025], [README-027] | [README-040..049] (reserved) |
| F | Placeholder / scaffold | `placeholder.md` | — | [README-150..159] |
| G | Org profile (3 tiers) | `org-profile.md` | [README-020] | [README-100..119] |

(No Family B — an earlier draft allocated one for "local-disk grouping" READMEs at `~/Developer/<org>/README.md`. Dropped on 2026-05-01 as redundant: the information lives better in the org's GH profile (Family G) and in `CLAUDE.md`'s Package Locations table. The workspace also has no monorepos and no superrepos; every Swift package is its own GitHub repo. Earlier drafts also explored a "Family D superrepo root" — also dropped for the same topology reason.)

**Org-tier sub-rules within Family G**: top-level org (swift-institute), org-of-orgs umbrella (swift-standards, swift-law, rule-law), leaf org (swift-primitives, swift-foundations, swift-nl-wetgever, swift-us-nv-legislature). Each tier has different content rules; see `org-profile.md`.

**Preserved**: All 27 [README-001..027] IDs from v2.1.0 retained in their semantic homes — no renumbering. The v2.0.0 + v2.1.0 changelog entries below stand unchanged; this entry sits on top.

**Terminology cleanup**: "monorepo" and "superrepo" are dropped from the skill. The workspace has neither — every Swift package is a single GitHub repo, and the local-disk directory at `~/Developer/<org>/` is a clone-mirror, not a "repo" in any GitHub sense. [README-018] (originally "monorepo root README structure") is DEPRECATED with content absorbed by [README-111] (org profile leaf-tier package catalog), [README-113] (leaf-tier architecture diagram), and [README-008] (per-package installation). [README-019] is updated: the installation example now uses the per-package GH repo URL rather than a nested-package reference.

**applies_to expanded**: now covers swift-{primitives,standards,foundations}, swift-institute, rule-law, swift-law, swift-nl-wetgever, swift-us-nv-legislature, coenttb. The skill governs ecosystem-wide README conventions; one sibling (user-profile.md) covers the coenttb voice register specifically.

**Universal vs family-scoped meta-rules**:

- **Universal** (kept inline in this hub): [README-023] Evaluator's Lens, [README-026] No Internal Rule-ID Citations.
- **Family-scoped** (moved to siblings): [README-024] Motivated Examples → `sub-package.md` (sub-package code examples). [README-025] Scope Boundary → `sub-package.md` (sub-package vs ecosystem-hierarchy). [README-027] Stability Section Operational Form → `sub-package.md` (sub-package Stability sections).

**No content changes** to existing rules during the migration. Voice sections are NEW content per family file.

### v2.1.0 — 2026-05-01 (Additive per [SKILL-LIFE-003])

**Provenance**: `swift-institute/Research/cohort-readme-evaluator-pass.md` — per-paragraph audit of the swift-primitives 0.1.0 release cohort (carrier / tagged / ownership / property), 2026-05-01. Triggered by the principal's recurring-pattern observation after a per-paragraph fix on `swift-ownership-primitives/README.md`. Convergence reached via 3-round Claude/ChatGPT collaborative discussion (`/tmp/cohort-readme-pattern-converged.md`). Diagnoses the pattern as **audience inversion** — author-side context leaking into consumer-evaluator prose — expressed through six surface forms.

**Additions** (new MUST rule + extensions):

- [README-027] Stability Section Operational Form — *if* a Stability section is present in a pre-1.0 package README, it MUST be operational (consumer SemVer expectations, not internal rationale or future-proposal speculation); SHOULD for infrastructure packages where omission creates source-compatibility uncertainty.
- [README-016] Prohibited Content extended with 4 new rows: pre-tag/release-process notes, future-migration choreography, internal workaround rationale, ecosystem-convention framing in feature bullets.
- [README-010] Architecture extended with the consumer-question earning sub-rule: every row, box, or diagram element must answer a consumer dependency / import / capability / adoption question; "When to import" is the recommended column for product/target tables specifically.

### v2.0.0 — 2026-04-21 (Breaking per [SKILL-LIFE-003])

**Provenance**: `swift-institute/Research/package-readme-standard.md` — ecosystem audit of 15 first-class Swift OSS READMEs (Apple core + Point-Free + SSWG), Tier 2 research, 2026-04-21. Addresses concrete maintainer critiques on `swift-primitives/swift-property-primitives/README.md` (2026-04-21).

**Additions** (new MUST rules — previously-conforming READMEs may now violate):

- [README-023] Evaluator's Lens — every paragraph MUST serve the reader's evaluation ("do I want to use this?").
- [README-024] Motivated Examples — code examples MUST demonstrate something impossible, awkward, or subtly wrong without the package.
- [README-025] Scope Boundary — sub-package READMEs MUST NOT carry Institute-level ecosystem-hierarchy content.

**Relaxations** (MUST → SHOULD or narrowed):

- [README-001] — Required inventory (Title / badge / one-liner / License) vs recommended sequence (all others). Installation MAY follow Quick Start.
- [README-007] — Key Features format permits prose or feature-as-subsection alternatives.
- [README-010] — Architecture ASCII diagram; "layered" clarified as intra-package.
- [README-011] — Platform Support table MAY be omitted when a functional SPI platforms badge is present.
- [README-013] — Error Handling narrowed to non-trivial error shape (≥ 3 exhaustive catch arms).

**Tightenings**:

- [README-006] — Added opening-contract sub-clause.
- [README-022] — Added baseline-contrast technique; cross-references [README-024].

**Extensions**:

- [README-015] — Added Motivation, Alternatives as named optional sections; clarified Design Philosophy.
- [README-016] — Added three prohibited content types (ecosystem-hierarchy diagrams in sub-package READMEs, implementation autobiography, author's design reflections).

### v1.0.0 — 2026-03-20

Initial skill. See `Research/readme-skill-design.md` (SUPERSEDED).
