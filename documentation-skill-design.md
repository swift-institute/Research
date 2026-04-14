# Documentation Skill Design

<!--
---
version: 2.1.0
last_updated: 2026-03-10
status: SUPERSEDED
---
-->

## Context

The Swift Institute has skills for testing (`/testing`), implementation (`/implementation`), naming (`/naming`), errors (`/errors`), and code organization (`/code-organization`). Two documentation gaps exist:

1. **Inline DocC + .docc catalogue conventions** — how to document source code and organize catalogue articles
2. **README conventions** — how to structure package README files

The existing `Documentation Standards.md` covers both, but as a monolithic non-normative document rather than invocable skills. The decision is to create **two separate skills**: `/documentation` (inline DocC + .docc catalogue) and `/readme` (README structure).

This research focuses on `/documentation`. A separate research document will cover `/readme`.

Two exemplar project styles inform the design:

| Style | .docc Approach | Content Distribution |
|-------|---------------|---------------------|
| Navigation-only | Navigation stubs (7-line @Metadata files) | All content in inline `///` comments |
| Substantive content | Substantive content layer | Spec text + examples mirrored in both layers; explanatory material exclusive to .docc |

The substantive-content style demonstrates a significantly richer pattern that the skill must accommodate.

## Question

What should a `/documentation` skill contain, given the two-skill split and the substantive .docc catalogue pattern?

## Analysis

### Two Documentation Maturity Levels

#### Level 1: Navigation Scaffolding

The `.docc` catalogue provides pure navigation:
- Root page with `## Topics` grouping symbols
- Article pages with only `@Metadata` (@DisplayName, @TitleHeading)
- All substantive content lives in inline `///` comments
- .docc articles are 7-line stubs

**When appropriate**: Early development; types not yet fully documented; primitives packages.

#### Level 2: Substantive Content Layer

The `.docc` catalogue carries substantive content alongside navigation:

**Article page structure** (e.g., `Section 3.md`):
```markdown
# ``Module/Symbol``

@Metadata {
    @DisplayName("Human-Readable Title")
    @TitleHeading("Domain Heading")
}

{Brief description}

## Specification

> **Section Title**
>
> [1.](<doc:Symbol/Subsection 1>) Verbatim specification text with
> [cross-references](<doc:Related/Term>) to defined terms...

## Example

` ` `swift
// Working Swift code example
` ` `

## Rationale

{Explanatory prose — design context, relationship to other specifications.
This content is EXCLUSIVE to the .docc article and does NOT appear in inline
comments.}
```

**Key observations**:

1. **Specification text is mirrored** between inline `///` and `.docc` articles. Both contain the same blockquoted text with the same cross-reference links. This is intentional — inline docs are self-sufficient for source readers; .docc articles render the same content in a navigable format.

2. **Explanatory material is exclusive to .docc**. Rationale and explanatory memoranda appear only in .docc articles, not in inline comments. This is the key differentiator — .docc articles ADD context that doesn't belong in source code.

3. **Blockquote convention** delineates spec text from commentary. The `>` prefix clearly marks verbatim specification text versus original prose.

4. **Companion document subdirectories** within `.docc/` host large related documents (e.g., multi-chapter explanatory memoranda).

5. **Conclusion patterns**: Articles may include `## Topics → ### Conclusions` with derived conclusions as navigable symbols.

### Content Distribution Rules

| Content Type | Inline `///` | .docc Article |
|-------------|:---:|:---:|
| Summary line | MUST | — (inherits from symbol) |
| Specification text (blockquoted) | MUST | MAY mirror |
| Subsection enumeration with links | MUST | MAY mirror |
| Code examples | SHOULD | MAY mirror |
| Cross-references to related specs | MUST | MAY mirror |
| Explanatory material (rationale) | MUST NOT | MUST (when available) |
| Companion documents (full chapters) | MUST NOT | MUST (as subdirectories) |
| @Metadata, @DisplayName | — | MUST |
| Topics organization | — | MUST |
| Derived conclusions | — | MAY |

**Principle**: Inline docs are the **self-sufficient developer reference** — a developer reading source never needs to consult .docc to understand a type. The .docc catalogue is the **expanded reference** — it mirrors core content for navigation AND adds explanatory depth.

This means specification text appearing in both layers is **intentional mirroring**, not prohibited duplication. The .docc article is the superset.

---

## Proposed Skill Structure

### Planning ([SKILL-CREATE-001])

| Decision | Answer |
|----------|--------|
| Purpose | Codify conventions for inline DocC comments and .docc catalogue documentation |
| Layer | `implementation` |
| ID Prefix | `DOC-` |
| Dependencies | `swift-institute`, `naming`, `code-organization` |
| Applies to | All Swift Institute packages |

### Requirement Inventory

---

#### Section 1: Inline DocC Comments

**[DOC-001] Summary Line**
Every public declaration MUST have a one-line `///` summary describing caller-visible behavior, not implementation details.

**[DOC-002] Type Documentation Structure**
Type declarations MUST follow:
1. One-line summary
2. Blank line
3. Section heading for specification content (e.g., `## RFC Section`, `## ISO Section`)
4. Specification text in blockquote (`>`) when modeling external specs
5. `## Example` with working Swift code (when implemented)

**Correct** (specification-mirroring pattern):
```swift
/// Resource Identifier
///
/// ## RFC 3986 Section 3
///
/// > [3.1.](<doc:RFC_3986/Section/3/1>) A URI scheme is the first
/// > component of a URI reference...
///
/// ## Example
///
/// ```swift
/// let uri = try RFC_3986.URI(...)
/// ```
```

**[DOC-003] Method Documentation**
Methods MUST document: Parameters (`- Parameter name:`), Return value (`- Returns:`), Thrown errors (`- Throws:`), executor/threading guarantees, cancellation behavior.

**[DOC-004] Property Documentation**
Properties MUST NOT be documented when self-evident. MUST be documented when: (a) computed with side effects, (b) has non-obvious invariants, (c) deviates from established pattern.

**[DOC-005] Specification-Mirroring Documentation**
When a type models an external specification, the inline documentation MUST contain:
1. Summary line = specification section title
2. Specification section heading
3. Specification text in blockquote (`>` prefix) — verbatim or summarized
4. Cross-references to related specification sections via DocC links

The `>` blockquote prefix MUST be used for verbatim specification text to visually distinguish it from original commentary.

**[DOC-006] Subsection Enumeration**
When a specification section has numbered subsections, each MUST be listed with a DocC link and one-line summary:
```swift
/// > [1.](<doc:RFC_3986/Section/3/1>) A URI scheme is the first component...
/// >
/// > [2.](<doc:RFC_3986/Section/3/2>) The authority component is preceded...
```

**[DOC-007] Abbreviated Subsection Syntax**
When subsections are too dense to reproduce verbatim, they MAY be abbreviated using bracketed descriptions:
```swift
/// 3.-6. [Provisions for remote participation via electronic communications,
/// videoconferencing, or teleconferencing]
```

**[DOC-008] Cross-Reference Formats**

| Format | Use Case | Example |
|--------|----------|---------|
| DocC link | Explicit authored links, cross-article | `[section 3.2](<doc:RFC_3986/Section/3/2>)` |
| DocC link with term | Links to defined terms | `[authority](<doc:RFC_3986/Glossary/Authority>)` |
| Backtick auto-link | Casual sibling references | `` ``Section_3_2`` `` |

DocC links MUST be used when linking to a different specification section or a defined term. Backtick auto-links MAY be used for sibling references within the same parent scope.

**[DOC-009] Definition Index Pattern**
When a section defines multiple terms, the documentation SHOULD list each definition with an italic title and DocC link:
```swift
/// > _[scheme](<doc:RFC_3986/Glossary/Scheme>)_: The first component of a URI...
/// > _[authority](<doc:RFC_3986/Glossary/Authority>)_: The component identified by...
```

**[DOC-010] Explanatory Material Exclusion**
Explanatory material (design commentary, rationale, explanatory memoranda) MUST NOT appear in inline `///` comments. Inline docs contain specification text and code examples only. Explanatory material belongs exclusively in `.docc` articles.

---

#### Section 2: .docc Catalogue

**[DOC-020] Catalogue Location**
Every module MUST have a `.docc` catalogue directory:
```
Sources/{Module Name}/{Module Name}.docc/
```

**[DOC-021] Root Page**
The catalogue MUST contain a root page matching the module name:
```markdown
# ``{Module_Identifier}``

@Metadata {
    @DisplayName("{Human-Readable Name}")
    @TitleHeading("{Domain Heading}")
}

> Important: {Legal disclaimers or version notes if applicable.}

> {Preamble text if applicable (e.g., legislative enacting clause).}

## Topics

### {Domain Section Name}

- ``{Symbol}``
```

`@TitleHeading` provides domain context: "RFC 4122", "ISO 32000", "Swift Institute".

**[DOC-022] Article Pages — Navigation Level**
Article pages at minimum MUST contain @Metadata:
```markdown
# ``{Module_Identifier}/{Symbol Path}``

@Metadata {
    @DisplayName("{Human-Readable Title}")
    @TitleHeading("{Domain Heading}")
}
```

This is sufficient for early development or shell types.

**[DOC-023] Article Pages — Substantive Level**
Article pages MAY expand with substantive content sections. Recognized sections, in order:

| Section | Purpose | Required |
|---------|---------|----------|
| `## Specification` | Blockquoted spec text with cross-links | MAY (mirrors inline docs) |
| `## Example` | Working Swift code example | MAY (mirrors inline docs) |
| `## Rationale` | Explanatory material exclusive to .docc | MAY |
| `## Topics → ### Conclusions` | Derived conclusions as navigable symbols | MAY |

When specification text appears in a .docc article, it MUST match the inline `///` version exactly. The .docc article is the superset — it mirrors inline content and adds explanatory depth.

**[DOC-024] Subsection Pages**
When a type has documented subsections, each SHOULD have its own article page:
```markdown
# ``{Module_Identifier}/{Parent}/{Subsection}``

@Metadata {
    @DisplayName("{Parent}.{Subsection} {Title}")
    @TitleHeading("{Domain Heading}")
}
```

**[DOC-025] Topics Organization**
The root page's `## Topics` section MUST group symbols by logical domain sections, not alphabetically. Section headings MUST match the domain's own organizational structure.

**[DOC-026] Companion Document Subdirectories**
Large companion documents (explanatory memoranda, detailed rationale, legislative history) SHOULD be organized in subdirectories within `.docc/`:
```
Sources/{Module Name}/{Module Name}.docc/
├── {Module Name}.md                    ← Root page
├── {Article}.md                        ← Per-symbol articles
└── {Companion Document Name}/          ← Companion docs
    ├── {Companion Document Name}.md    ← Index with chapter links
    └── {Chapter}.md                    ← Individual chapters
```

The root page MUST link to companion documents in its `## Topics` section.

**[DOC-027] Content Layering Principle**
Inline `///` documentation is the **self-sufficient developer reference** — reading source alone must suffice to understand a type. The `.docc` catalogue is the **expanded reference** — it mirrors core content for navigation and adds explanatory depth exclusive to .docc.

| Layer | Audience | Content |
|-------|----------|---------|
| Inline `///` | Developer reading source | Spec text, examples, cross-refs |
| `.docc` article | Reader navigating docs | Same + explanatory material |
| `.docc` companion | Deep reader | Full companion documents |

Specification text appearing in both layers is intentional mirroring, not prohibited duplication.

---

#### Section 3: External Specification References

**[DOC-030] External Links**
The root page's `## Overview` or preamble MUST include a link to the authoritative external specification:
```markdown
- [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986)
```

**[DOC-031] Cross-Module References**
When inline documentation references specifications outside the current module, the reference MUST use the full specification identifier:
```swift
/// as required by RFC 3986 Section 3.1
```
DocC links SHOULD be used when the referenced specification has a corresponding Swift module.

**[DOC-032] Range Reference Pattern**
When a specification references a range of sections, the documentation MUST link both endpoints and preserve the specification's range language:
```swift
/// [RFC 3986 Section 3.1](<doc:RFC_3986/Section/3/1>) to [RFC 3986 Section 3.3](<doc:RFC_3986/Section/3/3>), inclusive
```

**[DOC-033] Blockquote Convention for Specification Text**
Verbatim specification text MUST use the `>` blockquote prefix in both inline docs and .docc articles. This visually delineates normative specification text from original commentary:

```swift
/// > **Scheme**
/// >
/// > [3.1.](<doc:RFC_3986/Section/3/1>) A URI scheme is the first...
```

---

#### Section 4: Documentation Quality

**[DOC-040] Documentation Tiers**

| Tier | .docc Article | Inline Docs | When |
|------|--------------|-------------|------|
| 1 — Full | Spec text + examples + explanatory material + companion docs | Spec text + examples + cross-refs | Implemented type with available companion material |
| 2 — Standard | Spec text + examples | Spec text + examples + cross-refs | Implemented type |
| 3 — Enumerated | @Metadata + Topics | Subsection enumeration with links | Multi-subsection type |
| 4 — Minimal | @Metadata only | Summary line + abbreviated spec text | Partially documented |
| 5 — Shell | @Metadata only | None or summary only | Namespace container / placeholder |

Types SHOULD progress through tiers as they gain implementation.

**[DOC-041] Section Heading Conventions**
Specification section headings SHOULD mirror the specification's own terminology:

| Domain | Heading | Example |
|--------|---------|---------|
| RFCs | `## RFC {N} Section {M}` | RFC 4122 |
| ISO standards | `## ISO {N} Section {M}` | ISO 32000 |
| General | `## Specification` | Fallback |

Explanatory material headings:

| Domain | Heading |
|--------|---------|
| General | `## Rationale` or `## Design Notes` |

**[DOC-042] Documentation Currency**
When specification text changes, both inline docs and .docc articles MUST be updated. The .docc @DisplayName MUST reflect the current specification title.

---

## Separate `/readme` Skill

README conventions from `Documentation Standards.md` will become a separate `/readme` skill covering:
- Required sections and ordering
- Badge conventions
- One-liner requirements
- Installation format
- Quick Start requirements
- Architecture diagrams
- Platform support tables
- Performance methodology
- Error handling documentation
- Related packages organization

This separation is clean because README conventions are structurally independent from inline DocC + .docc patterns. The `/readme` skill will use prefix `README-`.

---

## Cross-References with Existing Infrastructure

| Existing Source | Relationship |
|-----------------|-------------|
| `Documentation Standards.md` | Split: inline/catalogue rules → `/documentation`; README rules → `/readme`. Workaround/deviation/anticipatory templates and code example rules remain shared and are cross-referenced from both skills. |
| `naming` skill [API-NAME-003] | Spec-mirroring names; [DOC-005] extends to documentation content. |
| `code-organization` skill [API-IMPL-005] | One type per file; [DOC-022] one article per type. |
| `errors` skill [API-ERR-001] | Typed throws; [DOC-003] requires documenting thrown errors. |


---

## Open Questions

1. **Mandate .docc catalogues for all packages?** Recommendation: MUST, with tier 5 as minimum bar.

2. **Spec-mirroring documentation MUST vs SHOULD?** Recommendation: MUST for standards-layer packages (they exist to model specs), SHOULD for all others.

3. **Should mirrored spec text be literally identical between inline and .docc?** Observed practice shows near-identical text. Recommendation: MUST be semantically identical; minor formatting differences (e.g., line wrapping) are acceptable.

4. **Should the blockquote convention (`>`) apply to all specification types (RFCs, ISOs)?** Recommendation: yes — the pattern generalizes well to any verbatim specification text.

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: **documentation** skill [DOC-*]
This research was absorbed into the documentation skill. It remains as historical rationale.

## References

- `Documentation.docc/Documentation Standards.md`
- `Skills/skill-creation/SKILL.md`
- `Skills/testing/SKILL.md`
- `Skills/implementation/SKILL.md`
