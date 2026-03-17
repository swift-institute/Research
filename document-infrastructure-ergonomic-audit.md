# Document Infrastructure Ergonomic Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-17
status: IN_PROGRESS
tier: 2
---
-->

## Context

The document creation ecosystem has evolved organically across two generations:

1. **coenttb era**: `swift-documents` (re-export aggregator + print CSS) and `swift-document-templates` (Letter, Invoice, Signature Page, etc.) with AGPL/proprietary licensing.
2. **Swift Institute era**: Rendering pipeline migrated to Apache 2.0 packages (`swift-html`, `swift-pdf-rendering`, `swift-pdf-html-rendering`, `swift-pdf` in swift-foundations/coenttb), but no equivalent of the document-level infrastructure or templates.

The legal domain built on top of the coenttb packages: `rule-legal-document-templates` (Agreement, Deed, Minutes) depends on `swift-document-templates` for Signature.Page and shared utilities. The Aandeelhoudersregister PDF renderer uses the Institute's rendering pipeline directly.

We now need to decide where shared document infrastructure should live in the Institute ecosystem, covering both general documents and legal documents.

## Question

What is the ideal package structure for document infrastructure, covering:
1. Shared document utilities (print CSS baseline, page-break helpers, document head construction)
2. General document templates (Letter, Invoice, Signature Page, etc.)
3. Legal document templates (Agreement, Deed, Minutes, etc.)
4. Multi-format support (PDF, EPUB, HTML web)

## Inventory of Current Assets

### Rendering Pipeline (Already Migrated — Institute Ecosystem)

| Package | Location | Layer | License | Status |
|---------|----------|-------|---------|--------|
| swift-pdf-rendering | swift-foundations | L3 | Apache 2.0 | Active |
| swift-pdf-html-rendering | swift-foundations | L3 | Apache 2.0 | Active |
| swift-html (aggregator) | swift-foundations | L3 | Apache 2.0 | Active |
| swift-markdown-html-rendering | swift-foundations | L3 | Apache 2.0 | Active |
| swift-pdf | coenttb/swift-pdf | L4 | Apache 2.0 | Active |

### Document Infrastructure (Not Yet Migrated — coenttb Ecosystem)

| Package | Location | Purpose | License |
|---------|----------|---------|---------|
| swift-documents | coenttb/ | Re-export aggregator + `Document.Styles` (print CSS) + `Document.styled()` factory | AGPL |
| swift-document-templates | coenttb/ | Letter, Invoice, Invitation, Agenda, Attendance List, Signature Page | Proprietary |

### Legal Document Templates (rule-legal Ecosystem)

| Package | Location | Purpose | License |
|---------|----------|---------|---------|
| rule-legal-document-templates | rule-legal/ | Agreement, Deed, Minutes, Declaration | Commercial |
| Aandeelhoudersregister PDF | rule-legal-nl/ | BV shareholder register PDF renderer | Commercial |
| rule-legal-demo | rule-law/ | NDA demo, Nevada incorporation kit | Commercial |

### Cross-Cutting Dependencies

| Dependency | Used By | Purpose | Current Location |
|------------|---------|---------|-----------------|
| TranslatedString | All templates | Bilingual (NL/EN) labels | swift-translating (coenttb) |
| OrderedDictionary | Invoice, templates | Ordered metadata rendering | swift-collections (Apple) |
| DateExtensions | Letter, Invoice | Locale-aware date formatting | coenttb |
| Signature.Page | Deed, Minutes, Agreement | Multi-party signature blocks | swift-document-templates |

## Analysis

### What Document.Styles Provides

`Document.Styles` in swift-documents provides a print-ready CSS baseline:
- `@page` directive: A4, 2cm margins
- Print-specific rules: `print-color-adjust`, webkit prefixes
- Typography hierarchy: h1–h6 with font stacks
- Table/code/blockquote formatting with orphan/widow control
- Page-break utility classes: `.page-break-before`, `.page-break-after`, `.page-break-avoid`

This is **format-agnostic document styling** — useful for both HTML-rendered-in-browser and HTML-to-PDF pipelines. It's currently duplicated: swift-documents has one version, and `PDF.HTML.Configuration` in swift-pdf-html-rendering provides equivalent controls for the PDF pipeline.

**Question**: Should the CSS baseline live alongside the PDF configuration, or should there be a shared document-level CSS module?

### What Document Templates Provide

Templates are concrete `HTML.View` conformances with:
- **Structured data models**: Letter.Sender, Letter.Recipient, Invoice.Row, Signatory.Person
- **Rendering logic**: Header layout, clause numbering, signature blocks, metadata tables
- **Multi-language support**: TranslatedString keys for all labels
- **Composition**: Letter is base; Invoice/Invitation extend it via conversion initializers
- **Preview support**: `static var preview` on each type for development

### Layer Assignment Question

The five-layer architecture gives clear guidance:

| Content | Layer | Rationale |
|---------|-------|-----------|
| Print CSS baseline | L3 (Foundations) | Composed building blocks, no opinion on content |
| `Document.styled()` factory | L3 (Foundations) | Structural helper, no domain knowledge |
| Page-break utilities | L3 (Foundations) | Generic layout tools |
| Letter/Invoice/Signature.Page | L4 (Components) | Opinionated assemblies with defaults |
| Agreement/Deed/Minutes | L5 (Applications) or L4 | Domain-specific, commercial |
| Aandeelhoudersregister PDF | L5 (Applications) | Product-level, jurisdiction-specific |

### Ergonomic Issues in Current State

**E-1: No shared document foundation in Institute ecosystem.**
When writing a new document type today, you start from scratch — there's no print CSS baseline, no document head helper, no page-break utilities. The PDF pipeline has `PDF.HTML.Configuration` but no HTML-side equivalent.

**E-2: Signature Page has no Institute-ecosystem home.**
`Signature.Page` is in the coenttb ecosystem but needed by both general and legal documents. It should be available at L4 (Components) within the Institute ecosystem.

**E-3: TranslatedString dependency unclear.**
Document templates need multi-language labels. `swift-translating` is in the coenttb ecosystem. The Institute ecosystem needs either: (a) its own i18n primitive, (b) a dependency on swift-translating, or (c) a simpler pattern for document labels.

**E-4: Letter as implicit base type is fragile.**
Invoice and Invitation convert their Sender/Recipient to Letter.Sender/Letter.Recipient via conversion initializers. This coupling means Letter changes break downstream types. A shared `Document.Party` or `Document.Correspondent` type would be more stable.

**E-5: No unified Document protocol or configuration.**
Each template independently implements `HTML.View` with ad-hoc structure. There's no shared pattern for: document title, metadata section, body content, signature section, page numbering.

**E-6: Multi-format gap.**
swift-documents re-exports PDF + EPUB + HTML, but EPUB support (`swift-epub`) is not in the Institute ecosystem. Documents should render to all formats from a single source.

### Naming Compliance [API-NAME-001], [API-NAME-002]

The coenttb-era code has several naming violations to correct during migration:

| Current (coenttb) | Corrected (Institute) | Rule |
|--------------------|----------------------|------|
| `DocumentStyles` | `Document.Styles` | [API-NAME-001] compound → Nest.Name |
| `SignaturePage` | `Signature.Page` | [API-NAME-001] compound → Nest.Name |
| `HTML.Document.document(body:)` | `Document.styled(body:)` or styled `HTML.Document` init | [API-NAME-002] redundant compound method |
| `Letter.Sender` / `Letter.Recipient` | `Document.Party` | [API-NAME-001] shared type, not Letter-scoped |
| `_DocumentHead<CustomHead>` | `Document.Head<Custom>` | [API-NAME-001] compound + underscore prefix |

Existing `PDF.HTML.Configuration` properties (`defaultFont`, `defaultFontSize`, `defaultColor`, `paperSize`, `documentTitle`) are compound identifiers per [API-NAME-002]. These are existing shipped API — audit separately if needed. CSS property names (`.fontSize()`, `.backgroundColor()`) are specification-mirroring per [API-NAME-003] (CSS `font-size`, `background-color`).

---

## Options

### Option A: Minimal — Document Utilities Target in swift-html

Add a `Document Utilities` target to swift-foundations/swift-html containing:
- `Document.Styles` (print CSS baseline)
- `Document.styled()` factory
- Page-break CSS utility helpers

Templates stay in their respective ecosystems (coenttb for general, rule-legal for legal). No new packages.

**Advantages**:
- Minimal change, fast to implement
- No new package to maintain
- Print CSS logically belongs near HTML rendering

**Disadvantages**:
- Doesn't solve E-2 (Signature Page), E-4 (Letter coupling), E-5 (no shared document pattern)
- Templates remain in AGPL/proprietary coenttb ecosystem
- No path for general templates in Institute ecosystem

### Option B: New swift-documents Package in swift-foundations

Create `swift-foundations/swift-documents/` as an L3 package containing:
- **Document Utilities** target: Print CSS, document factory, page-break helpers
- **Document Standard** target: Shared types — `Document.Party`, `Document.Metadata`, `Document.Section`

Then separately, a new `swift-document-templates` at L4 (in coenttb or as a standalone repo) containing:
- Letter, Invoice, Signature Page, Attendance List, Agenda

Legal templates stay in rule-legal ecosystem, depending on `Document Standard` from L3.

**Advantages**:
- Clean layering: L3 utilities, L4 general templates, L4/L5 legal templates
- Shared `Document.Party` type eliminates Letter coupling (E-4)
- `Document Standard` gives legal templates stable foundations (E-5)
- Fits existing monorepo pattern (swift-foundations already has 20+ packages)

**Disadvantages**:
- Two new packages to create and maintain
- Must decide what constitutes "standard" vs "template"
- TranslatedString dependency still needs resolution (E-3)

### Option C: New swift-documents Package in swift-foundations + Legal Templates in rule-law Ecosystem

Like Option B but with explicit legal template strategy:

**swift-foundations/swift-documents/** (L3):
- `Document Utilities`: Print CSS baseline, Document.styled() factory
- `Document Standard`: Party, Metadata, Section, Clause types

**coenttb/swift-document-templates** or new location (L4):
- Letter, Invoice, Signature Page, Attendance List, Agenda
- Depends on `Document Standard` from L3

**rule-legal-document-templates** (L4, stays in rule-legal):
- Agreement, Deed, Minutes, Declaration
- Depends on `Document Standard` from L3 + Signature Page from L4

**Aandeelhoudersregister PDF** and other jurisdiction-specific renderers (L5, stay in rule-legal):
- Product-level document renderers
- Depend on legal templates + rendering pipeline

**Advantages**:
- Cleanest separation of concerns
- Each ecosystem owns its templates
- Shared foundation prevents duplication
- Legal ecosystem can evolve independently
- Matches the four-layer legal architecture (legislature → composition → products)

**Disadvantages**:
- Most work to implement
- Need to define the `Document Standard` API carefully

### Option D: Absorb Document Utilities into Existing Packages

No new packages. Instead:
- Print CSS → new target in swift-css (already in swift-foundations)
- Document head factory → extension in swift-html
- Shared party/metadata types → new target in swift-html or swift-pdf-html-rendering

Templates stay external.

**Advantages**:
- Zero new packages
- Leverages existing package structure

**Disadvantages**:
- Scatters document concerns across multiple packages
- No clear "document" import path
- Makes discovery harder for new users

## Comparison

| Criterion | A: Minimal | B: New L3 pkg | C: L3 + Legal strategy | D: Absorb |
|-----------|-----------|---------------|----------------------|-----------|
| Solves print CSS gap (E-1) | Yes | Yes | Yes | Yes |
| Solves Signature Page gap (E-2) | No | Yes (L4) | Yes (L4) | No |
| Solves TranslatedString (E-3) | No | Partially | Partially | No |
| Solves Letter coupling (E-4) | No | Yes | Yes | No |
| Solves no-shared-pattern (E-5) | No | Yes | Yes | No |
| Multi-format path (E-6) | No | Possible | Possible | No |
| Implementation effort | Low | Medium | Medium-High | Low |
| Layering clarity | Good | Good | Best | Muddled |
| Legal ecosystem alignment | N/A | Good | Best | N/A |

## Recommendation

**Option C** is the strongest design, but can be implemented incrementally:

### Phase 1: Document Utilities (immediate)
Create `swift-foundations/swift-documents/` with a single target `Document Utilities`:
- Port `Document.Styles` (print CSS baseline) from coenttb/swift-documents
- Port `Document.styled()` factory
- Add page-break utility helpers
- License: Apache 2.0

This solves E-1 immediately and establishes the package.

### Phase 2: Shared document types (next)
Add targets to `swift-foundations/swift-documents/`:
- `Document.Party` (name, address, identifiers — replaces Letter.Sender/Recipient coupling)
- `Document.Metadata` (ordered key-value pairs for document headers)
- `Document.Section` (titled, numbered content section)
- `Document.Clause` (numbered clause with optional header, recursive nesting)

This solves E-4 and E-5.

### Phase 3: Template migration (when needed)
- General templates (Letter, Invoice, Agenda, Attendance List) → L4 package (TBD location)
- Legal templates (Signature Page, Agreement, Deed, Minutes, Declaration) → `rule-legal/swift-legal-documents`
- Both depend on shared types from Phase 2

This solves E-2.

### Phase 4: Multi-format (deferred)
EPUB support and unified multi-format rendering. Depends on swift-epub maturity.

### TranslatedString (E-3) — Design Decision Needed

Three sub-options:
1. **Accept swift-translating dependency** — pragmatic, already works
2. **Create a minimal `Localized<String>` type in primitives** — just a protocol + String wrapper, no full i18n
3. **Use plain String with locale parameter** — simplest, but loses compile-time label safety

**Recommendation**: Start with plain `String` for Phase 1–2. Add localization in Phase 3 when templates are migrated and the right pattern is clear.

## Decisions (2026-03-17)

1. **No separate L2 Document Standard package.** All document infrastructure lives in `swift-foundations/swift-documents/` (L3). Shared types (Party, Metadata, Section, Clause) are targets within this package, not a separate standards package.

2. **Legal document types → `rule-legal/swift-legal-documents`.** Signature Page, Agreement, Deed, Minutes, Declaration — all legal-domain document types live in the rule-legal ecosystem. This replaces both the current `rule-legal-document-templates` and the Signature Page from `swift-document-templates`.

3. **Clauses support recursive nesting.** `Document.Clause` will allow sub-clauses. Not top priority — implement when templates are migrated.

4. **CSS baseline vs PDF.HTML.Configuration — still open.** Needs investigation into overlap and whether they should share a common source of truth.

## Outcome

**Status**: IN_PROGRESS

### Resolved Questions

| # | Question | Decision |
|---|----------|----------|
| 1 | Where do Document Standard types live? | Same package: `swift-foundations/swift-documents/` (L3) |
| 3 | Should Clause support recursive nesting? | Yes, but not top priority |
| 5 | Where does Signature Page live? | `rule-legal/swift-legal-documents` |

### Open Questions

1. What is the right granularity for `Document.Party`? (Natural person vs legal entity, address fields, identifier types)
2. How should the print CSS baseline relate to `PDF.HTML.Configuration`? (Overlap in margins, fonts, page size)

## References

- Five-Layer Architecture: `/Users/coen/Developer/swift-institute/Documentation.docc/Five Layer Architecture.md`
- rule-law ARCHITECTURE.md: `/Users/coen/Developer/rule-law/ARCHITECTURE.md`
- coenttb/swift-documents: `/Users/coen/Developer/coenttb/swift-documents/`
- coenttb/swift-document-templates: `/Users/coen/Developer/coenttb/swift-document-templates/`
- rule-legal-document-templates: `/Users/coen/Developer/rule-legal/rule-legal-document-templates/`
- PDF.HTML.Configuration: `/Users/coen/Developer/swift-foundations/swift-pdf-html-rendering/Sources/PDF HTML Rendering/PDF.HTML.Configuration.swift`
