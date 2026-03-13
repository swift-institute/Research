# Standard Facade Package Organization

<!--
---
version: 2.0.0
last_updated: 2026-03-13
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Context

The Swift Institute's standards layer was originally a single monorepo (`swift-standards/`) containing both specification implementations (RFC, ISO, W3C, etc.) and domain-level facade packages (`swift-*-standard`).

A recent reorganization split the specification implementations into standards-body-specific directories:

| Directory | Content | Count |
|-----------|---------|-------|
| `swift-ietf/` | RFC and BCP implementations | ~70 |
| `swift-w3c/` | W3C specifications | 6 |
| `swift-iso/` | ISO standards | 9 |
| `swift-ieee/` | IEEE standards | 1 |
| `swift-iec/` | IEC standards | 1 |
| `swift-ecma/` | ECMA standards | 1 |
| `swift-whatwg/` | WHATWG living standards | 2 |
| `swift-incits/` | INCITS standards | 1 |

This split is architecturally correct: each org mirrors a real standards body.

However, 17 `swift-*-standard` facade packages remain in `swift-standards/`. With the spec implementations moved out, `swift-standards/` now contains *only* these packages plus `swift-rfc-template`. This raises the question: what role do these packages serve, and where should they live?

Two case studies — [PDF](pdf-standard-case-study.md) and [EmailAddress](emailaddress-standard-case-study.md) — revealed that the original framing ("where do facades go?") missed the real question. The `-standard` packages are not facades to be eliminated. They serve two distinct architectural purposes that justify their existence as a layer.

## Question

What architectural role do `swift-*-standard` packages serve, and how does `swift-standards/` relate to the standards-body orgs and `swift-foundations/`?

## Key Findings

### Two purposes of `-standard` packages

The case studies revealed that `-standard` packages serve two purposes, either individually or in combination:

**1. Convergence** — Unify multiple specs that define the same domain concept from different angles.

Example: `swift-emailaddress-standard` unifies RFC 2822 (Internet Message Format), RFC 5321 (SMTP), RFC 5322 (IMF), and RFC 6531 (internationalized email) into a single `EmailAddress` type. The type stores the most permissive representation (RFC 6531) and provides typed, failable conversions to stricter formats. No single spec defines "email address" — the concept exists at the intersection of four specs.

**2. Stability** — Insulate consumers from specification evolution.

Example: `swift-ipv4-standard` wraps a single RFC (791). If IPv4 were updated via a new RFC (as happens with RFC obsolescence chains), every consumer importing `RFC_791` would need to update their import. With `IPv4_Standard`, only the `-standard` package updates its internal dependency — all consumers keep importing `IPv4_Standard` unchanged.

These purposes are complementary, not alternative. A multi-spec convergence package like `swift-emailaddress-standard` provides BOTH convergence AND stability. A single-spec package like `swift-epub-standard` provides only stability — but that is still valuable.

### The three-layer model

The case studies clarify a three-layer model for how domain concepts are packaged:

```
Layer 3: swift-foundations/      Ecosystem integration (volatile)
         swift-emailaddress      Mailgun integration, validation middleware,
                                 Vapor extensions, database codable support
              ↑
Layer 2: swift-standards/        Convergence + stability (stable)
         swift-emailaddress-     Unifies RFC 2822/5321/5322/6531 into
         standard                EmailAddress type
              ↑
Layer 2: swift-ietf/             Spec implementations (stable)
         swift-rfc-2822          Faithful implementation of RFC 2822
         swift-rfc-5321          Faithful implementation of RFC 5321
         swift-rfc-5322          Faithful implementation of RFC 5322
         swift-rfc-6531          Faithful implementation of RFC 6531
```

The critical insight is the **stable-vs-volatile separation**:

- **Spec implementations** (body orgs) rarely change — specs are versioned documents
- **Standard packages** (`swift-standards/`) rarely change — they unify stable specs into stable domain concepts
- **Foundations packages** (`swift-foundations/`) change frequently — ecosystem integrations evolve with the ecosystem

This separation means a Mailgun API change doesn't touch `swift-emailaddress-standard`. A new RFC version doesn't touch `swift-emailaddress` (the foundations package). Each layer absorbs change independently.

### Domain shape taxonomy

Different domain concepts have different "shapes" that determine their package structure:

| Shape | Primitives | Standards | Example | Pattern |
|-------|-----------|-----------|---------|---------|
| **A: Primitive-first, multi-spec** | Yes | Multiple | Time | `time-primitives` → `iso-8601` + `rfc-3339` + `rfc-5322` → `time-standard` → `swift-time` |
| **B: Standard-first, multi-spec** | No | Multiple | EmailAddress | `rfc-2822` + `rfc-5321` + `rfc-5322` + `rfc-6531` → `emailaddress-standard` → `swift-emailaddress` |
| **C: Standard-first, single-spec** | No | One | EPUB, SVG, PDF | `w3c-epub` → `epub-standard` → `swift-epub` |
| **D: Mixed** | Partial | Multiple, cross-body | Color | `dimension-primitives` → `iec-61966` + `iso-9899` + `ecma-48` → `color-standard` → `swift-color` |

**Shape A** — The domain concept exists before any standard defines it. Time is inherently primitive (durations, instants, calendars). Standards like ISO 8601 and RFC 3339 provide interchange formats. The primitives package defines the concept; the standard package unifies the interchange formats; the foundations package integrates with the ecosystem.

**Shape B** — The domain concept IS defined by standards. There is no "email address" without the RFCs. No primitives package makes sense. The standard package creates the canonical type by converging multiple specs. The foundations package integrates with ecosystem services (validation, sending, storage).

**Shape C** — A single spec fully defines the concept. The standard package provides only stability (insulation from spec version changes), not convergence. The foundations package integrates with ecosystem rendering, parsing, etc.

**Shape D** — The concept has both primitive aspects (color as numbers, dimensions) and multiple cross-body standards (IEC for sRGB, ISO for color math, ECMA for terminal colors). The standard package converges across bodies; the foundations package integrates with rendering pipelines.

## Inventory

### Classification by Shape

**Shape A — Primitive-first, multi-spec**:

| Package | Primitives | Standards | Domain Concept |
|---------|-----------|-----------|----------------|
| swift-time-standard | time-primitives, stdlib-ext | ISO 8601, RFC 5322, 3339 | Time representation |
| swift-locale-standard | stdlib-ext | BCP 47, ISO 639, 3166, 15924 | Locale |

**Shape B — Standard-first, multi-spec**:

| Package | Standards | Domain Concept |
|---------|-----------|----------------|
| swift-domain-standard | RFC 1035, 1123, 5321, 5890 | Domain name |
| swift-emailaddress-standard | domain-standard, RFC 2822, 5321, 5322, 6531 | Email address |
| swift-email-standard | emailaddress-standard, RFC 2045, 2046, 4648, 5322 | Email message |
| swift-uri-standard | RFC 3986, 4648 | URI |
| swift-ipv6-standard | RFC 4291, 5952, 4007 | IPv6 address |
| swift-sockets-standard | RFC 768, 791, 9293 | Socket (UDP + IP + TCP) |
| swift-json-feed-standard | IEEE 754, RFC 5322, uri-standard | JSON Feed |
| swift-rss-standard | binary-primitives, parser-primitives, RFC 5322, uri-standard | RSS feed |
| swift-css-standard | W3C CSS, IEC 61966, color-standard | CSS |

**Shape C — Standard-first, single-spec**:

| Package | Standard | Domain Concept |
|---------|----------|----------------|
| swift-epub-standard | W3C EPUB | EPUB document |
| swift-svg-standard | W3C SVG | SVG image |
| swift-pdf-standard | ISO 32000 | PDF document |
| swift-ipv4-standard | RFC 791 | IPv4 address |
| swift-html-standard | WHATWG HTML, geometry-primitives | HTML |

**Shape D — Mixed**:

| Package | Primitives | Standards (cross-body) | Domain Concept |
|---------|-----------|----------------------|----------------|
| swift-color-standard | dimension-primitives | IEC 61966, ISO 9899, ECMA 48 | Color |

### Dependency Direction Analysis

Per the five-layer architecture, packages may only depend downward:

| Package | Depends on Primitives? | Depends on Standards-Body Specs? | Depends on Other Facades? | Depends on Foundations? |
|---------|----------------------|--------------------------------|--------------------------|----------------------|
| swift-color-standard | Yes (dimension) | Yes (IEC, ISO, ECMA) | No | No |
| swift-css-standard | No | Yes (W3C, IEC) | Yes (color) | No |
| swift-domain-standard | No | Yes (RFCs) | No | No |
| swift-email-standard | No | Yes (RFCs) | Yes (emailaddress) | No |
| swift-emailaddress-standard | No | Yes (RFCs) | Yes (domain) | No |
| swift-epub-standard | No | Yes (W3C) | No | No |
| swift-html-standard | Yes (geometry) | Yes (WHATWG) | No | No |
| swift-ipv4-standard | No | Yes (RFC) | No | No |
| swift-ipv6-standard | No | Yes (RFCs) | No | No |
| swift-json-feed-standard | No | Yes (IEEE, RFC) | Yes (uri) | No |
| swift-locale-standard | Yes (stdlib-ext) | Yes (BCP, ISOs) | No | No |
| swift-pdf-standard | No | Yes (ISO) | No | No |
| swift-rss-standard | Yes (binary, parser) | Yes (RFC) | Yes (uri) | No |
| swift-sockets-standard | No | Yes (RFCs) | No | No |
| swift-svg-standard | No | Yes (W3C) | No | No |
| swift-time-standard | Yes (time, stdlib-ext) | Yes (ISO, RFCs) | No | No |
| swift-uri-standard | No | Yes (RFCs) | No | No |

**Key observation**: No `-standard` package depends on foundations. All depend exclusively on primitives + specification implementations + other `-standard` packages. They are structurally Layer 2.

## Analysis

### Option A: Keep all `-standard` packages in `swift-standards/` (Recommended)

**Description**: All 17 packages stay in `swift-standards/`. The org's role is explicitly redefined: it houses **domain-concept packages** that converge specifications and provide import stability. Each domain concept also gets (or already has) a corresponding foundations package for ecosystem integration.

**Advantages**:
- Zero migration work
- No breaking changes for consumers
- Semantically honest: these packages ARE standards-layer — they depend only on specs and primitives, they add no policy or ecosystem opinion
- Preserves stable-vs-volatile separation: standards change rarely, foundations change often
- Convergence and stability are standards-layer concerns, not foundations-layer concerns
- The packages faithfully implement externally-defined concepts (Domain, URI, EmailAddress) — the concept IS the standard

**Disadvantages**:
- `swift-standards/` now contains zero individual spec implementations — the name could be confusing
- The five-layer architecture document needs updating to acknowledge this sub-category

**Assessment**: The strongest option. The "standards" name is appropriate because these packages define canonical domain types FROM standards. The split between `swift-standards/` (convergence/stability) and body orgs (spec implementations) is a sub-layer distinction within Layer 2, not a violation.

### Option B: Move all to `swift-foundations/`

**Description**: Relocate all 17 packages to `swift-foundations/`.

**Advantages**:
- Architecturally defensible: Foundations = "composed building blocks"
- Clears `swift-standards/` for retirement

**Disadvantages**:
- **Destroys stable-vs-volatile separation**: Standard packages rarely change (specs are stable). Foundations packages change frequently (ecosystem evolves). Mixing them means stable domain types share a home with volatile ecosystem integrations
- Naming friction: "swift-emailaddress-standard" in foundations is awkward
- These are not foundations in spirit — they don't add policy, opinion, or ecosystem integration
- Migration cost (17 packages)

**Assessment**: Technically valid but semantically wrong and operationally harmful. The stable-vs-volatile separation is architecturally valuable and would be lost.

### Option C: Eliminate thin re-exports, move substantive compositions (Original v1.0 recommendation — WITHDRAWN)

**Description**: Eliminate "pure re-export" facades, move substantive compositions to foundations.

**Why withdrawn**: The case studies revealed that even single-spec packages like `swift-ipv4-standard` provide **stability value**. If RFC 791 is obsoleted by a new RFC, only `swift-ipv4-standard` updates internally — all consumers keep importing `IPv4_Standard`. Eliminating these packages forces every consumer to track spec evolution directly. The "pure re-export" classification was based on code substance alone, ignoring the architectural role.

### Option D: Rename `swift-standards/`

**Description**: Rename to reflect the new role (e.g., `swift-domains/`, `swift-convergence/`).

**Assessment**: Unnecessary. The name `swift-standards` is appropriate — these packages create canonical types FROM standards. The name needs no change; the documentation needs updating to explain the sub-layer structure.

### Option E: Absorb into standards-body orgs

**Description**: Move each facade into the org of its primary dependency.

**Assessment**: Fails for cross-body compositions (color, time, locale, json-feed, rss), pollutes body orgs with non-spec packages, and breaks the naming convention. Even for single-body packages, it conflates "spec implementation" with "domain convergence."

## Comparison

| Criterion | A (Keep, redefine role) | B (→ Foundations) | C (Eliminate + Move) | D (Rename) | E (Into Body Orgs) |
|-----------|------------------------|-------------------|---------------------|------------|-------------------|
| Preserves stable/volatile separation | Yes | No | No | Yes | Partially |
| Convergence stays at standards layer | Yes | No | No | Yes | Partially |
| Stability insulation | Yes | Yes | Lost for eliminated | Yes | Yes |
| Migration cost | None | High | Medium-High | Low | Medium |
| Conceptual clarity | High (with docs update) | Medium | High initially, wrong long-term | Medium | Low |
| Naming consistency | Good | Friction | Mixed | New name needed | Inconsistent |

## Constraints

1. **SPM path dependencies**: Development uses relative `path:` dependencies. Moving packages changes all dependent Package.swift files.
2. **GitHub repo ownership**: Packages are individual GitHub repos in the `swift-standards` org. Any move requires GitHub transfers.
3. **Existing consumers**: External consumers using `swift-*-standard` packages would need to update dependency URLs after a move.
4. **Inter-facade dependencies**: `swift-css-standard` → `swift-color-standard`, `swift-email-standard` → `swift-emailaddress-standard` → `swift-domain-standard`, `swift-json-feed-standard` → `swift-uri-standard`, `swift-rss-standard` → `swift-uri-standard`.

## Recommendation

**Option A**: Keep all `-standard` packages in `swift-standards/`. Redefine the role of `swift-standards/` in documentation.

### What `swift-standards/` means after the split

Before the split, `swift-standards/` contained both spec implementations and domain compositions. After the split:

- **Standards-body orgs** (`swift-ietf/`, `swift-w3c/`, etc.) — Faithful implementations of individual specifications. One package per spec. Naming follows `swift-{spec-id}` (e.g., `swift-rfc-5322`, `swift-iso-32000`).

- **`swift-standards/`** — Domain-concept packages that converge multiple specs into canonical types and insulate consumers from spec evolution. Naming follows `swift-{concept}-standard` (e.g., `swift-emailaddress-standard`, `swift-pdf-standard`).

Both are Layer 2 (Standards). The distinction is granularity, not layer.

### The full domain-concept model

For each domain concept, the ecosystem provides up to four tiers of packages:

```
swift-foundations/swift-{concept}            Layer 3  Ecosystem integration (volatile)
         ↑
swift-standards/swift-{concept}-standard     Layer 2  Convergence + stability (stable)
         ↑
swift-{body}/swift-{spec-id}                 Layer 2  Spec implementation (stable)
         ↑
swift-primitives/swift-{concept}-primitives  Layer 1  Primitive concept (when applicable)
```

Not every domain concept has all four tiers. The shape taxonomy determines which tiers exist:

| Shape | Primitives | Spec implementations | `-standard` | Foundations |
|-------|-----------|---------------------|-------------|-------------|
| A (primitive-first, multi-spec) | Yes | Multiple | Yes (convergence + stability) | Yes |
| B (standard-first, multi-spec) | No | Multiple | Yes (convergence + stability) | Yes |
| C (standard-first, single-spec) | No | One | Yes (stability only) | Yes |
| D (mixed) | Partial | Multiple, cross-body | Yes (convergence + stability) | Yes |

### Documentation updates needed

1. **Five Layer Architecture.md** — ~~Add a section explaining the sub-layer distinction within Layer 2~~ **Done** (v2.0, 2026-03-13)
2. **Domain shape taxonomy** — Consider promoting the shape taxonomy (A/B/C/D) to the architecture documentation as a guide for how new domain concepts should be packaged

### Per-package action items

No packages need to move. Each `-standard` package should have a corresponding foundations package for ecosystem integration.

#### Foundations counterpart audit

| Standard Package | Foundations Counterpart | Exists? |
|---|---|---|
| swift-color-standard | swift-color | No — needs creation |
| swift-css-standard | swift-css | Yes |
| swift-domain-standard | swift-domain-name-system | Yes |
| swift-email-standard | swift-email | Yes |
| swift-emailaddress-standard | swift-emailaddress | No — needs creation |
| swift-epub-standard | swift-epub | No — needs creation |
| swift-html-standard | swift-html | Yes |
| swift-ipv4-standard | swift-ip-address | No — needs creation (shared with ipv6) |
| swift-ipv6-standard | swift-ip-address | No — needs creation (shared with ipv4) |
| swift-json-feed-standard | swift-json-feed | No — needs creation |
| swift-locale-standard | swift-locale | No — needs creation |
| swift-pdf-standard | swift-pdf | Yes |
| swift-rss-standard | swift-rss | No — needs creation |
| swift-sockets-standard | swift-sockets | Yes |
| swift-svg-standard | swift-svg | Yes |
| swift-time-standard | swift-time | Yes |
| swift-uri-standard | swift-uri | No — needs creation |

**8 exist, 8 need creation.** Note: `swift-ipv4-standard` and `swift-ipv6-standard` both feed into a single `swift-ip-address` foundations package (17 standards → 16 foundations).

#### Intra-foundations import rules

Within the foundations layer, packages form their own dependency graph. The rule for importing `-standard` modules:

| Foundations package role | Import standard directly? | Import foundations counterpart? | Rationale |
|---|---|---|---|
| **Rendering/implementation layer** (e.g., `swift-css-html-rendering`, `swift-html-rendering`) | Yes | No — would be circular | The top-level aggregate depends on them |
| **Top-level aggregate** (e.g., `swift-css`, `swift-html`) | Yes (re-exports it) | N/A — it IS the counterpart | Re-exports standard + rendering layers |
| **Peer foundations** (e.g., `swift-pdf-html-rendering` using CSS) | No | Yes — import `CSS`, not `CSS_Standard` | No circularity; gets stability + future ecosystem additions |

The key test is twofold: (1) **can this package depend on the top-level foundations counterpart without creating a cycle?** and (2) **is the transitive dependency closure acceptable?** Top-level aggregates like `swift-html` re-export many sub-packages (CSS, SVG, Markdown rendering, etc.). A rendering-layer package that only needs the standard types should import `*_Standard` directly to avoid pulling in unnecessary transitive dependencies.

#### Additional action items

1. **Review `swift-pdf-standard`** — The [PDF case study](pdf-standard-case-study.md) found that `PDF.Configuration`, `PDF.Rectangle`, and `PDF.Stroke` are rendering infrastructure, not standards-layer types. These should be evaluated for relocation to `swift-pdf-rendering`, while the stability wrapper (`PDF` typealias, re-exports) stays.

2. **Evaluate `swift-pdf-html-rendering` imports** — Currently imports `CSS_Standard` and `HTML_Standard` directly. It already depends on `swift-css` (the foundations counterpart) but also imports `CSS_Standard` separately. The `HTML_Standard` import is intentionally direct — depending on `swift-html` would pull in CSS Theming, SVG, Markdown rendering, and other transitive dependencies it doesn't need.

3. **Switch `swift-html`** — Currently imports `Color_Standard` directly. Should import `Color` (the new foundations counterpart) instead. Also has a redundant `@_exported import CSS_Standard` — this is already re-exported transitively through `@_exported import CSS`.

## Outcome

**Status**: RECOMMENDATION

Keep all 17 `-standard` packages in `swift-standards/`. They serve two distinct architectural purposes — convergence and stability — that are standards-layer concerns. The stable-vs-volatile separation between standards and foundations is architecturally valuable and should be preserved. Update documentation to explain the sub-layer structure within Layer 2.

The original v1.0 recommendation (eliminate thin re-exports, move substantive compositions to foundations) is withdrawn. It was based on a classification by code substance that missed the architectural role these packages serve.

## References

- [Five Layer Architecture](../Documentation.docc/Five%20Layer%20Architecture.md) — layer definitions
- [PDF Standard Case Study](pdf-standard-case-study.md) — thin facade with one consumer, leaky abstraction
- [EmailAddress Standard Case Study](emailaddress-standard-case-study.md) — substantive composition with many consumers, strong encapsulation
- [Domain-First Repository Organization](domain-first-repository-organization.md)
- [SPM Nested Package Publication](spm-nested-package-publication.md)
- [Dual-Mode Package Publication](dual-mode-package-publication.md)
