# PDF Standard Case Study

<!--
---
version: 2.0.0
last_updated: 2026-03-13
status: RECOMMENDATION
tier: 1
scope: cross-package
parent: standard-facade-package-organization.md
---
-->

## Context

This case study examines `swift-pdf-standard` as a concrete instance of the broader question raised in [Standard Facade Package Organization](standard-facade-package-organization.md): where should `swift-*-standard` facade packages live?

The PDF stack is a good test case because it spans the full architecture — from a spec implementation (Layer 2) through rendering (Layer 3) to a top-level aggregate (Layer 3). Examining it end-to-end reveals whether the facade adds value or creates unnecessary indirection.

## The PDF Stack Today

```
swift-iso-32000           Layer 2 (swift-iso/)           224 files, 13 products
       ↓
swift-pdf-standard        Layer 2 (swift-standards/)       5 files, 1 product
       ↓
swift-pdf-rendering       Layer 3 (swift-foundations/)     35 files, 2 products
       ↓
swift-pdf-html-rendering  Layer 3 (swift-foundations/)    136 files, 2 products
       ↓
swift-pdf                 Layer 3 (swift-foundations/)      1 file,  1 product
```

### What swift-iso-32000 provides

A comprehensive, clause-by-clause implementation of ISO 32000 (PDF specification). 224 source files organized into 13 products mirroring the spec structure:

| Product | Scope |
|---------|-------|
| ISO 32000 (umbrella) | Re-exports all clause modules |
| ISO 32000 Shared | Cross-cutting types |
| ISO 32000 3 Terms and definitions | Core object model (COS) |
| ISO 32000 7 Syntax | File structure, objects |
| ISO 32000 8 Graphics | Path, color, images |
| ISO 32000 9 Text | Fonts, text rendering |
| ISO 32000 10 Rendering | Halftones, patterns |
| ISO 32000 11 Transparency | Blending, compositing |
| ISO 32000 12 Interactive features | Annotations, forms, outlines |
| ISO 32000 13 Multimedia features | Rich media |
| ISO 32000 14 Document interchange | Metadata |
| ISO 32000 Annex D | Character sets |
| ISO 32000 Flate | Flate (zlib) compression |

Dependencies: 7 primitives packages, 7 standards packages (ISO 9899, IEEE 754, RFC 1950, RFC 4648, IEC 61966, W3C PNG, ISO 14496-22), 1 foundations package (ASCII).

A consumer can `import ISO_32000` and get the full specification API.

### What swift-pdf-standard adds

5 source files (262 lines of actual code):

| File | Content | Lines |
|------|---------|-------|
| `exports.swift` | `@_exported import ISO_32000`, `ISO_32000_Flate`, `Geometry_Primitives` | 5 |
| `PDF.swift` | `public typealias PDF = ISO_32000` | 10 |
| `PDF.Configuration.swift` | Paper size, margins, fonts, document metadata defaults | 132 |
| `PDF.Rectangle.swift` | Styled rectangle (geometry + fill + stroke) | 81 |
| `PDF.Stroke.swift` | Stroke properties (color + width) | 34 |

The facade adds:
1. **Convenience alias**: `PDF` instead of `ISO_32000`
2. **Re-exports**: Geometry primitives alongside ISO 32000
3. **Three rendering-oriented types**: Configuration, Rectangle, Stroke

### How consumers actually use the stack

**swift-pdf-rendering** (the sole direct consumer) declares `PDF_Standard` as its dependency, but its source code imports BOTH:

```swift
// In exports.swift:
@_exported public import PDF_Standard

// In source files:
import PDF_Standard     // 5+ files
import ISO_32000        // 29 files in ISO_32000+PDF.View/
import ISO_32000_Flate  // 1 file (PDF.Document.swift)
import ISO_32000_Shared // 1 file
```

**swift-pdf-html-rendering** (136 files) imports:
- `PDF_Standard` (standard imports, not re-exported)
- `ISO_32000` (extensively — CSS property converters reference ISO 32000 types directly)

**swift-pdf** (1 file) imports nothing from standards — pure facade over foundations.

### Consumer graph

```
swift-pdf-standard
    ↓ (direct dependency)
swift-pdf-rendering ──→ swift-pdf-html-rendering ──→ swift-pdf
    ↓ (external fork)                                    ↓
coenttb/swift-pdf-rendering                         coenttb/swift-pdf
                                                         ↓
                                                    rule-legal, rule-law (applications)
```

Total reach: 273 Swift files import `PDF_Standard`. But all go through one gateway: `swift-pdf-rendering`.

## Question

Should `swift-pdf-standard` continue to exist as a separate package, or should its contents be absorbed elsewhere?

## Analysis

### Option A: Keep swift-pdf-standard as-is (Status Quo)

**Description**: No change. The facade stays in `swift-standards/`.

**Advantages**:
- Zero migration work
- `PDF` typealias provides a clean namespace
- Configuration/Rectangle/Stroke are legitimate abstractions

**Disadvantages**:
- The facade doesn't actually encapsulate: consumers reach through it to import `ISO_32000` directly (29+ files)
- 5 files in a standalone package with its own git repo is heavy infrastructure for light content
- Lives in `swift-standards/` despite being a composition, not a spec implementation
- The `PDF` typealias creates a naming layer that doesn't add safety — just convenience

### Option B: Absorb into swift-iso-32000

**Description**: Move `PDF.Configuration`, `PDF.Rectangle`, `PDF.Stroke`, and the `PDF` typealias into the `swift-iso-32000` package as an additional product (e.g., `ISO 32000 Rendering Support` or added to the umbrella).

**Advantages**:
- Eliminates a package entirely
- The types are intimately tied to ISO 32000 types (they use `PDF.UserSpace.Rectangle`, `PDF.Color`, etc.)
- Consumers already import `ISO_32000` directly alongside `PDF_Standard`

**Disadvantages**:
- Adds rendering-oriented types to a spec-implementation package — blurs spec purity
- `PDF.Configuration` has rendering defaults (A4 paper, Times font) — that's policy, not specification
- The `PDF` typealias (which equals `ISO_32000`) would be circular if placed inside ISO_32000

**Assessment**: Violates the principle that spec packages implement specs, not rendering conveniences. The Configuration struct in particular introduces defaults (paper size, margins, font choices) that are opinion, not specification.

### Option C: Absorb into swift-pdf-rendering

**Description**: Move Configuration, Rectangle, Stroke into `swift-pdf-rendering`. The `PDF` typealias and re-exports move there too. Eliminate `swift-pdf-standard` entirely.

**Advantages**:
- These types exist to serve rendering — Configuration defines rendering defaults, Rectangle adds rendering-style properties, Stroke groups rendering attributes
- `swift-pdf-rendering` already imports everything `swift-pdf-standard` provides
- Reduces the dependency chain by one link
- `swift-pdf-rendering` already re-exports `PDF_Standard` — it can re-export `ISO_32000` directly instead
- Eliminates the leaky abstraction (no more "import the facade but also import what's behind it")

**Disadvantages**:
- `swift-pdf-html-rendering` also imports `PDF_Standard` — would need to update 58+ files to `import ISO_32000` or get it transitively through `PDF_Rendering`
- The `PDF` typealias is used across 273 files — `PDF.Color`, `PDF.Page`, `PDF.UserSpace` etc. If the typealias moves to `swift-pdf-rendering`, all those files still work (they import `PDF_Rendering` which re-exports it)
- External consumer (`coenttb/swift-pdf-rendering`) would need its dependency updated

**Assessment**: Architecturally cleanest. The three types are rendering infrastructure, not standards infrastructure. Migration is mechanical.

### Option D: Move to swift-foundations as swift-pdf-standard

**Description**: Per the parent research recommendation, move `swift-pdf-standard` to `swift-foundations/` since it composes standards into a building block.

**Advantages**:
- Architecturally correct per layer definitions
- Keeps the package as a distinct entity
- The `-standard` suffix signals its bridging role

**Disadvantages**:
- Doesn't address the core problem: the facade doesn't encapsulate (consumers reach through it)
- Moving a 5-file package to foundations doesn't change the fact that it's thin and awkward
- Still requires `swift-pdf-rendering` to depend on it separately from `swift-iso-32000`

**Assessment**: Moves the package to the right layer but doesn't resolve the structural issue.

### Option E: Split — typealias/re-exports to swift-pdf-rendering, types stay as rendering primitives

**Description**: The `PDF` typealias and `@_exported` imports move into `swift-pdf-rendering`. The three types (Configuration, Rectangle, Stroke) become part of a new `PDF Rendering Primitives` target inside `swift-pdf-rendering`, or are added to the main `PDF Rendering` target.

**Advantages**:
- Clean separation: spec types in spec package, rendering types in rendering package
- The typealias lives where it's re-exported from anyway
- No new packages needed

**Disadvantages**:
- Same migration cost as Option C (it's essentially the same option with finer granularity)

**Assessment**: Overcomplicates what is essentially Option C.

## Comparison

| Criterion | A (Status Quo) | B (→ iso-32000) | C (→ pdf-rendering) | D (→ foundations) |
|-----------|---------------|-----------------|---------------------|-------------------|
| Eliminates package | No | Yes | Yes | No |
| Architectural alignment | Low | Low (policy in spec) | High | Medium |
| Migration cost | None | Medium | Medium | Medium |
| Resolves leaky abstraction | No | Partially | Yes | No |
| Respects layer boundaries | No (standards ≠ composition) | No (spec ≠ rendering defaults) | Yes | Yes |
| Types in natural home | No | No | Yes | No |

## Constraints

1. **273 files use `PDF` typealias**: The `public typealias PDF = ISO_32000` is pervasive. Any option must preserve this typealias or provide a migration path.
2. **`swift-pdf-rendering` already re-exports `PDF_Standard`**: The typealias and re-exports can move to `swift-pdf-rendering` without changing downstream consumers.
3. **External consumer**: `coenttb/swift-pdf-rendering` depends on `swift-pdf-standard` via GitHub URL. Needs update regardless of option chosen.
4. **`import ISO_32000` already used directly**: 29+ files in `swift-pdf-rendering` already bypass the facade. Removing the facade formalizes what's already happening.

## Observations

### The facade doesn't encapsulate

The strongest signal is that `swift-pdf-rendering` — the sole direct consumer — imports both `PDF_Standard` AND `ISO_32000` directly. The facade was intended to provide a clean `PDF` namespace over `ISO_32000`, but in practice consumers need the underlying module anyway. This makes the facade a pass-through rather than an abstraction boundary.

### The three types are rendering infrastructure

- `PDF.Configuration`: Paper size, margins, default font, line height — these are **rendering** decisions
- `PDF.Rectangle`: Geometry + fill + stroke — a **rendering** primitive
- `PDF.Stroke`: Color + width — a **rendering** attribute

None of these implement or interpret the ISO 32000 specification. They prepare data for rendering. They belong with the renderer.

### The typealias is the only universally-used contribution

`public typealias PDF = ISO_32000` is used across 273 files. It provides a shorter, domain-natural name. This is valuable but doesn't require a separate package — it can live in whichever package re-exports `ISO_32000`.

## Recommendation

**Keep `swift-pdf-standard`** in `swift-standards/`. Evaluate relocating the three rendering types.

The parent research ([Standard Facade Package Organization v2.0](standard-facade-package-organization.md)) concluded that all `-standard` packages should be kept. Even as a single-spec package (Shape C: standard-first, single-spec), `swift-pdf-standard` provides **stability value** — consumers import `PDF_Standard` rather than `ISO_32000`, insulating them from potential spec version changes.

### Action items

1. **Keep the stability wrapper**: The `PDF` typealias, re-exports, and `exports.swift` stay in `swift-pdf-standard`. This is the package's primary architectural purpose.

2. **Evaluate the three rendering types**: `PDF.Configuration`, `PDF.Rectangle`, and `PDF.Stroke` are rendering infrastructure (paper size defaults, styled rectangles, stroke attributes). They may belong in `swift-pdf-rendering` rather than the standards layer. This is a separate, narrower question — it does not affect whether `swift-pdf-standard` continues to exist.

3. **Formalize the leaky abstraction**: The finding that consumers bypass the facade to import `ISO_32000` directly is notable but explained by the nature of PDF — the spec IS the API surface. The `-standard` package provides a stable import name and convenience typealias, not full encapsulation.

## Outcome

**Status**: RECOMMENDATION

Keep `swift-pdf-standard` in `swift-standards/` for stability. Evaluate moving `PDF.Configuration`, `PDF.Rectangle`, and `PDF.Stroke` to `swift-pdf-rendering` as a follow-up.

## Implications for the broader question

This case study revealed two key insights that shaped the parent research:

- **Single-spec packages still have value**: The stability benefit (insulating consumers from spec evolution) applies even when convergence is not needed
- **Policy-bearing types** (`Configuration` with A4/Times defaults) are rendering infrastructure that may not belong at the standards layer — but this is orthogonal to whether the `-standard` package itself should exist
- **Leaky abstractions are acceptable** for single-spec shapes — the `-standard` package provides a stable import name, not necessarily full encapsulation

## References

- [Standard Facade Package Organization](standard-facade-package-organization.md) — parent research
- [Five Layer Architecture](../Documentation.docc/Five%20Layer%20Architecture.md) — layer definitions
