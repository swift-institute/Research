# README Skill Design

<!--
---
version: 1.0.0
last_updated: 2026-02-26
status: RECOMMENDATION
---
-->

## Context

The Swift Institute has a `/documentation` skill covering inline DocC + .docc catalogue conventions. A separate `/readme` skill was explicitly decided in [documentation-skill-design.md](documentation-skill-design.md) because README conventions are structurally independent from DocC patterns.

The existing `Documentation Standards.md` (non-normative .docc article, ~1240 lines) contains comprehensive README specifications (lines 50–535) covering: required sections, badges, one-liner, key features, installation, quick start, architecture, platform support, performance, error handling, related packages, formatting rules, and prohibited content. This content needs to become an invocable skill.

## Question

What should the `/readme` skill contain, and how should it relate to the existing `Documentation Standards.md`?

## Ecosystem Analysis

### Current State: Massive Inconsistency

Surveying all README.md files across the ecosystem reveals three tiers of quality:

| Tier | Count | Pattern | Examples |
|------|-------|---------|----------|
| Empty/stub | ~40 | `# Package Name\n\nSwift Embedded compatible.` (3 lines) | Most primitives packages |
| Partial | ~5 | Some sections, inconsistent format | swift-rfc-9110, swift-iso-8601 |
| Full | ~10 | Most/all required sections present | swift-io, swift-kernel, swift-memory, swift-darwin |

**Specific inconsistencies found**:

| Issue | Packages Affected |
|-------|-------------------|
| No badges at all | swift-rfc-9110, swift-iso-8601, most primitives |
| "Features" with emoji checkmarks instead of "Key Features" with bold keywords | swift-rfc-3986, swift-rfc-4648, swift-memory |
| Badge ordering (CI before status) | swift-rfc-3986 |
| One-liner missing period | swift-rfc-3986 |
| Roadmaps/TODOs (explicitly prohibited) | swift-rfc-9110, swift-iso-8601 |
| Wrong license (MIT instead of Apache 2.0) | swift-iso-8601 |
| Badge after one-liner (wrong position) | swift-memory |
| Missing Platform Support table | Most standards packages |
| Missing Error Handling section | Most packages with typed throws |
| No Table of Contents (>200 lines) | swift-io (338), swift-kernel (277), swift-rfc-4648 (320) |

**Legal/statute packages** (wet-zeggenschap-lichaamsmateriaal, NRS-78) have NO README at all.

**GitHub organization profile READMEs** (`.github/profile/README.md`) are all empty placeholders — `# Swift Institute` (1 line).

### Best-Quality Internal Examples

**swift-io/README.md** (338 lines) — most comprehensive:
- Badge, one-liner, Design Philosophy (with Non-goals), Performance (full benchmark tables), Why swift-io? (comparison table), Installation, Quick Start (3 patterns), Error Handling (ASCII hierarchy + exhaustive matching), Architecture (ASCII diagram + key types table + execution model), Design Details, Configuration, Platform Support, Related Packages, License

**swift-kernel/README.md** (277 lines) — cleanest structure:
- Badge + CI badge, one-liner, Key Features (bold keywords), Installation + Requirements, Quick Start (3 scenarios), Error Handling, Architecture (ASCII + table), Platform Support, Design Philosophy, Related Packages, License

**swift-memory-primitives/README.md** (82 lines) — best minimal example:
- Badge, one-liner, Key Features (bold keywords), Installation (both blocks), Quick Start, Architecture (key types table), Platform Support, License

## External Best Practices

### Apple's Own Packages

Apple's Swift packages (swift-collections, swift-algorithms, swift-argument-parser) are deliberately minimal:
- No badges
- Few sections (Overview, Usage/Quick Start, Documentation link, Installation, License)
- Code-first — usage examples before installation
- No platform support tables
- No architecture diagrams

Notable: swift-argument-parser leads with a full `@main` struct example before any other section.

### Community Packages

Community packages (Alamofire, Kingfisher, Vapor) are badge-heavy:
- Multiple badge types (CI, version, platforms, license, SPM, social)
- Often use HTML `<a><img></a>` instead of Markdown badge syntax
- Features as `- [x]` checkbox lists
- Extensive requirements/migration sections

### Swift Package Index

SPI offers live-updating endpoint badges:
```markdown
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F{owner}%2F{repo}%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/{owner}/{repo})
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F{owner}%2F{repo}%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/{owner}/{repo})
```

These auto-update from SPI's build results — no manual maintenance needed.

### Cognitive Funneling Principle

From "Art of README" (Stephen Whitmore): information flows broadest-to-narrowest. The README's job ends at "can I use this?" — detailed API reference belongs in documentation, not the README.

### README vs DocC vs CLAUDE.md

| Artifact | Audience | Purpose | Format |
|----------|----------|---------|--------|
| README.md | Developers (public) | Package discovery, installation, quick start | GitHub landing page |
| .docc | Developers (users) | API reference, guides, explanatory depth | DocC rendered |
| CLAUDE.md | AI agents | Session context, skill routing, build commands | Machine-readable brief |

These serve entirely separate audiences. No overlap needed.

## Design Decisions

### Decision 1: Codify Documentation Standards.md, Don't Rewrite

The existing Documentation Standards.md README specifications (lines 50–535) are well-developed and already followed by the best READMEs in the ecosystem. The skill should codify this content with requirement IDs, not rewrite it.

**Changes from Documentation Standards.md**:

| Change | Rationale |
|--------|-----------|
| Add requirement IDs (`README-*`) | Enable cross-referencing |
| Add monorepo sub-package README pattern | Missing from current standards |
| Add README maturity tiers | Acknowledge the stub-to-full spectrum |
| Remove overlapping code example rules | Shared with `/documentation` skill; cross-reference instead |
| Add `.github/profile/` README pattern | Currently unaddressed |
| Add SPI badge convention | Modern best practice missing from current standards |

### Decision 2: README Maturity Tiers

The ecosystem has a clear stub-to-full spectrum. Rather than requiring full READMEs for all 61+ packages immediately, define tiers:

| Tier | When | Required Sections |
|------|------|-------------------|
| Minimum | All packages, always | Title, badge, one-liner, Installation, License |
| Standard | Packages with public API documentation | + Key Features, Quick Start, Architecture, Platform Support |
| Complete | Packages at v1.0+ or with external users | + Error Handling, Related Packages, optional sections as applicable |

This acknowledges reality (most primitives are stubs) while providing a clear upgrade path.

### Decision 3: Badge Strategy

Combine development status (required, ecosystem-internal) with SPI live badges (recommended, when published):

| Badge | Required | Source |
|-------|----------|--------|
| Development status | MUST | shields.io static |
| CI status | MAY (only when configured and passing) | GitHub Actions |
| SPI Swift versions | SHOULD (when published to SPI) | SPI endpoint |
| SPI platforms | SHOULD (when published to SPI) | SPI endpoint |

SPI badges are preferred over static platform/version badges because they auto-update.

### Decision 4: Monorepo Sub-Package READMEs

The swift-primitives monorepo has 61+ packages. Each sub-package SHOULD have its own README. The root README navigates to sub-packages.

| Scope | README Location | Content |
|-------|-----------------|---------|
| Monorepo root | `{monorepo}/README.md` | Overview, package inventory table, installation, architecture diagram |
| Sub-package | `{monorepo}/{package}/README.md` | Self-contained per-package README |
| GitHub org profile | `{monorepo}/.github/profile/README.md` | Organization overview (GitHub-rendered) |

Sub-package READMEs are self-contained — they do not assume the reader has seen the root README.

### Decision 5: GitHub Organization Profile README

`.github/profile/README.md` is a distinct artifact from package READMEs. It renders on the GitHub organization page. Currently all are empty. The `/readme` skill SHOULD address this as a separate section with its own conventions.

### Decision 6: Relationship to /documentation Skill

| Aspect | /readme | /documentation |
|--------|---------|----------------|
| Artifact | README.md | `///` comments + .docc articles |
| Audience | External developers discovering the package | Developers using the package |
| Content | What, why, how to install, quick start | API contracts, guides, research/experiment references |
| Workflow position | Can be written early (even pre-implementation) | Written last (synthesis of research, experiments, implementation, tests) |

The `/readme` skill has NO dependency on `/documentation`. A package can have a README without inline docs, and vice versa.

### Decision 7: Formatting Rules

Formatting rules (section separators, heading levels, table alignment, code block language specification) are shared between README and .docc articles. Rather than duplicating, the `/readme` skill codifies README-specific formatting and cross-references the `/documentation` skill for shared patterns.

## Proposed Requirement Inventory

| ID | Topic |
|----|-------|
| README-001 | Required sections and ordering |
| README-002 | README maturity tiers (Minimum / Standard / Complete) |
| README-003 | Development status badge (required, first badge) |
| README-004 | CI badge (optional, only when configured and passing) |
| README-005 | SPI badges (recommended when published) |
| README-006 | One-liner requirements |
| README-007 | Key Features format (bold keyword bullets) |
| README-008 | Installation format (dependency + target blocks) |
| README-009 | Quick Start requirements (runnable, 10-20 lines, imports) |
| README-010 | Architecture section (ASCII diagram for multi-module, key types table for simple) |
| README-011 | Platform Support table format |
| README-012 | Performance documentation methodology |
| README-013 | Error Handling section (ASCII hierarchy + exhaustive matching) |
| README-014 | Related Packages organization (Dependencies / Used By / Third-Party) |
| README-015 | Optional sections catalog |
| README-016 | Prohibited content |
| README-017 | Formatting rules (separators, headings, tables, code blocks) |
| README-018 | Monorepo root README pattern |
| README-019 | Sub-package README (self-contained) |
| README-020 | GitHub organization profile README |
| README-021 | Maintenance obligations (performance numbers, installation snippets, links) |
| README-022 | Code examples in README (imports, realistic naming, error handling) |

## Outcome

**Status**: RECOMMENDATION

Create a `/readme` skill with prefix `README-*`, layer `process`, requiring `swift-institute`. Codify the existing Documentation Standards.md README specifications with requirement IDs, add monorepo and maturity tier patterns, and include SPI badge conventions.

The skill promotes existing non-normative documentation to normative skill requirements, addressing the ecosystem's README inconsistency gap.

## References

- `/Users/coen/Developer/swift-institute/Research/documentation-skill-design.md` — Parent research (separation decision)
- `/Users/coen/Developer/swift-institute/Documentation.docc/Documentation Standards.md` — Existing README specifications
- `/Users/coen/Developer/swift-institute/Skills/documentation/SKILL.md` — Companion skill
- https://github.com/hackergrrl/art-of-readme — Cognitive funneling principle
- https://www.makeareadme.com/ — Section guidance
- https://github.com/RichardLitt/standard-readme — Standard Readme spec
- https://swiftpackageindex.com — SPI badge conventions
