# Documentation.docc Structure for Public Alpha Launch

<!--
---
version: 1.0.0
last_updated: 2026-04-15
status: DECISION
---
-->

## Context

The Swift Institute ecosystem comprises 219 packages across three active layers: primitives (128 packages), standards (20 packages), and foundations (71 packages). The ecosystem covers type-safe geometry, specification implementations (RFC, ISO, W3C), data formats (JSON, XML, TOML, YAML, Protobuf, MessagePack), full HTTP stack (15 packages), auth/security (15 packages), markup/rendering (HTML, SVG, PDF, EPUB, Markdown), databases (SQL with three backends), platform abstraction (POSIX, Linux, Darwin, Windows), async/concurrency, and more.

The `Swift Institute.docc` catalog is the public-facing documentation site, built with DocC and served via `xcrun docc preview`. It lives at the swift-institute repo root and serves as the ecosystem's front door.

**Trigger**: The initial documentation rewrite drew only from existing .docc articles, producing copy that accurately described the architecture but undersold the ecosystem's scope. The Five Layer Architecture was centered as the organizing principle, but layers 4 (Components) and 5 (Applications) do not exist yet. The documentation needs to communicate what the ecosystem IS and why it matters, not how it is organized internally.

**Audience for the alpha launch**:

| Audience | Question | Time budget |
|----------|----------|-------------|
| Evaluator | "What is this? Is it worth my attention?" | 30 seconds on root page |
| Early adopter | "How do I start using this?" | 5 minutes |
| Curious developer | "What's the philosophy here?" | 20+ minutes |

**Constraint**: Public alpha means packages are actively being released. Not all URLs will resolve yet. Documentation must acknowledge this without undermining confidence.

## Question

What should the swift-institute Documentation.docc contain and how should it be structured for a public alpha launch — given that we want to communicate principles and identity, not catalog packages, and should de-emphasize the five-layer architecture?

## Analysis

### Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| First-impression clarity | High | Evaluator understands what this is in 30 seconds |
| Principle communication | High | Distinctive qualities are obvious, not buried |
| Practical entry | High | Early adopter can start using a package in 5 minutes |
| Appropriate scope | High | Doesn't over-promise or under-sell for alpha |
| Progressive disclosure | Medium | Depth available without requiring it |
| Maintenance cost | Medium | Fewer pages to keep current during rapid alpha changes |

### Option A: Short root page + separate Principles article

```
Root page: 3-4 sentences + 1 code example + Topics
├── Principles (new: 5 principles with examples)
├── Getting Started
├── FAQ
├── Architecture (de-emphasized)
├── Deep dives (Math, Embedded, Identity)
├── Glossary
└── Blog
```

**Advantage**: Clean separation. Root page stays concise. Principles article is shareable/linkable on its own.

**Disadvantage**: Evaluators won't click through to a "Principles" page — the root page must carry the weight. Two-click depth to reach the pitch is one click too many for a 30-second evaluator.

### Option B: Substantial root page, no separate Principles article

```
Root page: Identity + principles with selective examples + Topics
├── Getting Started
├── FAQ
├── Architecture (de-emphasized, three-layer framing)
├── Deep dives (Math, Embedded, Identity)
├── Glossary
└── Blog
```

**Advantage**: The root page IS the pitch. Every evaluator reads it. Principles are communicated before any click-through. Fewer articles to maintain. DocC renders pre-Topics content as the page body — there is no length constraint.

**Disadvantage**: Root page gets longer. Risk of overwhelming evaluators with too much text before Topics.

**Mitigation**: Structure the root page so each principle is a short paragraph + code block. Evaluators can stop reading after the first example and still understand the value. The structure is scannable, not wall-of-text.

### Option C: Use-case organized (domain-led)

```
Root page: "What can you build?"
├── Data Formats (JSON, XML, ...)
├── Web (HTTP, WebSocket, ...)
├── Rendering (PDF, HTML, SVG, ...)
├── Getting Started
├── FAQ
└── ...
```

**Rejected**: This is a catalog approach. The user explicitly stated we are NOT listing all packages or providing extensive showcases. Domain organization also creates maintenance pressure — adding or restructuring packages requires documentation updates.

### Comparison

| Criterion | Option A (short root) | Option B (substantial root) |
|-----------|----------------------|---------------------------|
| First-impression clarity | Medium — pitch split across pages | High — pitch is the page |
| Principle communication | Medium — requires click-through | High — immediate |
| Practical entry | Same | Same |
| Appropriate scope | Good | Good |
| Progressive disclosure | Good separation | Good — Topics section routes deeper |
| Maintenance cost | More pages | Fewer pages |

### What Principles to Communicate

The root page should communicate what makes this ecosystem distinctive from the Swift package landscape. Five principles, each illustrable with a single code example:

| Principle | One-line pitch | Example source |
|-----------|---------------|----------------|
| Types encode meaning | The compiler catches what tests miss | Phantom-typed coordinates — geometry-primitives |
| Specifications as namespaces | Types mirror the specs they implement | `RFC_4122.UUID`, `ISO_32000.Page` — standards packages |
| Concrete errors | Typed throws, not `any Error` | `throws(IO.Error)` — IO package |
| Foundation independence | Darwin and Linux today; Embedded and Windows coming soon | `~Copyable`, no Foundation import — primitives |
| Granular composition | Depend on exactly what you need | Package.swift with individual deps |

These five principles cover what evaluators care about (1-3), what distinguishes this from the rest of the Swift ecosystem (1-4), and what early adopters need to understand (5).

### Architecture Reframing

The current Five Layer Architecture article is strong but centers a model where 2 of 5 layers don't exist. Options:

**A. Keep title, reframe opening**: "Three layers today, designed for five." Present primitives/standards/foundations as the current reality. Mention components and applications exist in the design but not yet in code. Keep all body content.

**B. Rename to "Architecture"**: Drop the "Five Layer" from the title. Present the three active layers. Acknowledge the full design exists but don't lead with it.

**C. Keep as-is, demote in Topics**: Leave the article intact but move it to a "Going deeper" Topics group.

Recommendation: **A**. The title "Five Layer Architecture" is already part of the ecosystem's vocabulary (referenced in FAQ, Identity, Skills, CLAUDE.md). Renaming would create inconsistency. But the opening should acknowledge reality: three layers are released, two are planned.

### Article Inventory for Alpha

| Article | Status | Role | Change needed |
|---------|--------|------|---------------|
| Root page | Rewrite | Pitch + principles | Replace current with substantial version |
| Getting Started | Exists (new) | Practical entry | Minor revision — align examples with root page |
| FAQ | Exists | Practical questions | Minor — de-emphasize five-layer references |
| Five Layer Architecture | Exists | Background | Rewrite opening to acknowledge three active layers |
| Mathematical Foundations | Exists | Deep dive | No change |
| Embedded Swift | Exists | Deep dive | No change |
| Identity | Exists | Deep dive | No change |
| Glossary | Exists | Reference | No change |
| Blog | Exists | Blog index | No change |

### Topics Grouping

```
## Topics

### Start here

- <doc:Getting-Started>
- <doc:FAQ>

### Going deeper

- <doc:Five-Layer-Architecture>
- <doc:Mathematical-Foundations>
- <doc:Embedded-Swift>
- <doc:Identity>

### Reference

- <doc:Glossary>

### Blog

- <doc:Blog>
```

Architecture moves from its own group to "Going deeper" — it's context, not a primary destination. Glossary gets its own "Reference" group.

### Alpha Status Communication

The root page needs an alpha disclaimer. Options:

- DocC `> Important:` admonition — visually prominent, standard DocC pattern
- Inline paragraph — less visually prominent

Recommendation: `> Important:` admonition after the identity statement, before principles. Brief: this is an early public release, packages are being published incrementally, URLs may not resolve until release tags land.

### Platform Status

The documentation should state current platform support clearly:

| Platform | Status |
|----------|--------|
| Darwin (macOS, iOS, tvOS, watchOS, visionOS) | Supported |
| Linux | Supported |
| Embedded Swift | Coming soon |
| Windows | Coming soon |

This belongs in the root page's Foundation independence principle and in Getting Started. The Embedded Swift deep dive article already exists for the curious — the root page just needs the status line.

## Outcome

**Status**: DECISION — implemented in commits 8f77efb, 9627194, 954be4c, 75eba04.

**Recommendation**: Option B (substantial root page) with the following structure:

### Root Page Structure

1. Identity statement (one paragraph — what Swift Institute IS)
2. Alpha status admonition
3. Principles with selective examples (3-5, each ~1 paragraph + 1 code block):
   - Types encode meaning
   - Specifications as namespaces
   - Concrete errors (typed throws)
   - Foundation independence
   - Granular composition
4. Brief architectural context (three active layers, link to full article)
5. `## Topics` with progressive disclosure grouping

### Other Changes

- Five Layer Architecture: rewrite opening to acknowledge three active layers
- FAQ: minor adjustments to de-emphasize five-layer framing
- Getting Started: align example choices with root page
- Deep dives: no changes, available for curious readers
- No new articles beyond what already exists

### What NOT to Include

- Package catalogs or inventories
- Domain-organized navigation (data formats, web, security, etc.)
- Extensive tutorials or walkthroughs
- Components or Applications layer content (doesn't exist yet)
- Internal conventions (that's Skills/, not Documentation.docc/)

## References

- Handoff: `/Users/coen/Developer/swift-institute/HANDOFF.md`
- Prior research: `documentation-skill-design.md` (SUPERSEDED)
- Prior research: `skill-based-documentation-architecture.md` (SUPERSEDED)
- Documentation skill: `/Users/coen/Developer/.claude/skills/documentation/SKILL.md`
- Blog process skill: `/Users/coen/Developer/.claude/skills/blog-process/SKILL.md`
