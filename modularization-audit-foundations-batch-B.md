# Modularization Audit: swift-foundations Batch B

<!--
---
version: 1.0.0
created: 2026-03-20
status: COMPLETE
scope: swift-foundations (16 packages, Layer 3)
skill: modularization (MOD-001 through MOD-014)
adaptation: Layer 3 naming uses {Domain} not {Domain} Primitives per MOD-012
---
-->

## 1. Scope

16 STANDARD-complexity packages in `swift-foundations`, each with 2 source targets (plus test targets, macro targets, or C shim targets where applicable). Layer 3 naming convention: Core = `{Domain} Core`, Variant = `{Domain} {Variant}`, Umbrella = `{Domain}`, Test Support = `{Domain} Test Support`.

---

## 2. Package Inventory

| # | Package | Products | Source Targets | Pattern | Files per Target |
|---|---------|----------|----------------|---------|------------------|
| 1 | swift-linux | Linux Kernel, Linux Loader, Linux System | 3 | Peer products | Kernel: 4, Loader: 1, System: 6 |
| 2 | swift-ascii | ASCII | 2 (ASCII + ASCII Test Support) | Main + Test Support | ASCII: 34, Test Support: 1 |
| 3 | swift-css | CSS, CSS Theming | 2 | Peer products (dependent) | CSS: 6, CSS Theming: 9 |
| 4 | swift-css-html-rendering | CSS HTML Rendering, CSS HTML Rendering Test Support | 2 | Main + Test Support | Main: 515, Test Support: 1 |
| 5 | swift-defunctionalize | Defunctionalize | 3 (Main + Macros + Macros Implementation) | Main + Macros | Main: 1, Macros: 1, Implementation: 7 |
| 6 | swift-dual | Dual | 3 (Main + Macros + Macros Implementation) | Main + Macros | Main: 1, Macros: 1, Implementation: 8 |
| 7 | swift-kernel | Kernel, Kernel Test Support | 2 (+1 executable) | Main + Test Support | Kernel: 63, Test Support: 8, _Lock Test Process: exec |
| 8 | swift-loader | Loader | 2 (Loader + CTypeMetadata) | Main + C shim | Loader: 4, CTypeMetadata: C/C++ only |
| 9 | swift-parsers | Parsers, Parsers Test Support | 2 | Main + Test Support | Parsers: 13, Test Support: 1 |
| 10 | swift-pdf | PDF, PDF Test Support | 2 | Main + Test Support | PDF: 1, Test Support: 2 |
| 11 | swift-pdf-html-rendering | PDF HTML Rendering, PDF HTML Rendering Test Support | 2 | Main + Test Support | Main: 58, Test Support: 1 |
| 12 | swift-pdf-rendering | PDF Rendering, PDF Rendering Test Support | 2 | Main + Test Support | Main: 34, Test Support: 1 |
| 13 | swift-posix | POSIX Kernel, POSIX Loader | 2 | Peer products | Kernel: 6, Loader: 1 |
| 14 | swift-svg-rendering | SVG Rendering, SVG Rendering Test Support | 2 | Main + Test Support | Main: 22, Test Support: 1 |
| 15 | swift-windows | Windows Kernel, Windows System | 2 | Peer products | Kernel: 6, System: 4 |
| 16 | swift-witnesses | Witnesses, Witnesses Macros | 3 (Main + Macros + Macros Implementation) | Main + Macros | Main: 21, Macros: 1, Implementation: 5 |

---

## 3. Compliance Tables

### Legend

- **PASS**: Fully compliant
- **FAIL**: Violation found
- **N/A**: Rule does not apply to this package pattern
- **REVIEW**: Borderline, merits discussion

---

### 3.1 swift-linux

3 peer products: Linux Kernel, Linux Loader, Linux System.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | **FAIL** | 3 peer products share `Linux Primitives` but no Core target centralizes it |
| MOD-002 | **FAIL** | `Linux Primitives` declared independently in all 3 targets; `Kernel Primitives` duplicated in Kernel + System |
| MOD-003 | PASS | Targets are independent (no inter-variant deps) |
| MOD-004 | N/A | No ~Copyable concerns in platform layer |
| MOD-005 | **FAIL** | No umbrella target re-exporting all three products |
| MOD-006 | PASS | Each target declares only deps it needs |
| MOD-007 | PASS | Depth 1 (flat, no intra-package chains) |
| MOD-008 | PASS | Largest target is 6 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | **FAIL** | No Test Support product published |
| MOD-012 | PASS | Names follow `Linux {Variant}` L3 convention |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 4 FAIL (MOD-001, MOD-002, MOD-005, MOD-011). Same structural pattern as the primitives-layer platform packages (darwin/linux/windows). The 3-product peer pattern without Core is a known ecosystem-wide pattern for platform-abstraction packages. MOD-002 `Linux Primitives` appears in all 3 target dependency lists; could be centralized via a Core that re-exports it.

---

### 3.2 swift-ascii

1 product + internal test support: ASCII, ASCII Test Support (target only, not product).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Single product, Main + Test Support pattern |
| MOD-002 | N/A | Single main target, no centralization needed |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single product, no umbrella needed |
| MOD-006 | PASS | 7 external deps, all from primitives/standards layer |
| MOD-007 | PASS | Depth 1 (Test Support depends on ASCII) |
| MOD-008 | REVIEW | 34 files in single target — at boundary for split consideration |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | **FAIL** | ASCII Test Support is a target but NOT published as a library product — downstream packages cannot depend on it |
| MOD-012 | PASS | `ASCII`, `ASCII Test Support` — correct L3 naming |
| MOD-013 | N/A | 3 targets (including test), threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). ASCII Test Support exists as a target at `Tests/Support` with 1 file but is not published as a `.library(name: "ASCII Test Support", ...)` product. This prevents downstream consumers from importing test fixtures. 1 REVIEW (MOD-008): 34 files in a single target may warrant decomposition if distinct semantic sub-domains exist (e.g., parsing, serialization, character classification).

---

### 3.3 swift-css

2 products: CSS, CSS Theming. CSS Theming depends on CSS (vertical, not peer).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | CSS Theming depends on CSS — this is a vertical parent/child, not multi-peer |
| MOD-002 | REVIEW | `CSS Standard` declared in both CSS and CSS Theming target deps. CSS could re-export it. |
| MOD-003 | PASS | CSS Theming depends on CSS — documented delegation, not peer violation |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Vertical (not peer) decomposition, no umbrella needed |
| MOD-006 | PASS | CSS: 2 deps, CSS Theming: 2 deps — minimal |
| MOD-007 | PASS | Depth 2 (CSS Theming → CSS → externals) |
| MOD-008 | PASS | CSS: 6 files, CSS Theming: 9 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `CSS`, `CSS Theming` — correct L3 convention |
| MOD-013 | N/A | 3 targets (including test), threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). 1 REVIEW (MOD-002): `CSS Standard` appears as a direct dependency on both CSS and CSS Theming. Since CSS Theming already depends on CSS, it could receive CSS Standard transitively if CSS re-exports it. Minor — only 2 targets.

---

### 3.4 swift-css-html-rendering

2 products: CSS HTML Rendering, CSS HTML Rendering Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 3 external deps for main, 3 for test support |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | **FAIL** | **515 files in a single target** — far exceeds any reasonable single-target threshold |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | PASS | CSS HTML Rendering Test Support published as library product |
| MOD-012 | PASS | `CSS HTML Rendering`, `CSS HTML Rendering Test Support` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-008). **Critical**: 515 Swift files in a single target is by far the largest single-target count in the ecosystem. This likely contains multiple semantic sub-domains (CSS property rendering, layout, selectors, media queries, etc.) and is a strong candidate for decomposition. A `Layout/` subdirectory already exists within the source tree, suggesting at least one natural split axis. This is the single highest-priority finding in this audit.

---

### 3.5 swift-defunctionalize

1 product: Defunctionalize. 3 targets: Defunctionalize, Defunctionalize Macros, Defunctionalize Macros Implementation (macro target).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Macros pattern |
| MOD-002 | PASS | Optic/Finite Primitives only on Macros (which needs them), swift-syntax only on Implementation |
| MOD-003 | N/A | Macros Implementation is a build-tool target, not a semantic variant |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single product |
| MOD-006 | PASS | Minimal deps per target |
| MOD-007 | PASS | Depth 2 (Defunctionalize → Macros → Implementation) |
| MOD-008 | PASS | Main: 1, Macros: 1, Implementation: 7 |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Defunctionalize`, `Defunctionalize Macros` — correct L3 naming |
| MOD-013 | N/A | 4 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). No test support product. Given that this is a macro package, a test support product is less critical than for data-type packages but still required by the rule.

---

### 3.6 swift-dual

1 product: Dual. 3 targets: Dual, Dual Macros, Dual Macros Implementation (macro target).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Macros pattern |
| MOD-002 | PASS | Same structure as Defunctionalize — clean separation |
| MOD-003 | N/A | Not a variant package |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single product |
| MOD-006 | PASS | Minimal deps per target |
| MOD-007 | PASS | Depth 2 (Dual → Macros → Implementation) |
| MOD-008 | PASS | Main: 1, Macros: 1, Implementation: 8 |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Dual`, `Dual Macros` — correct L3 naming |
| MOD-013 | N/A | 4 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). Same pattern as Defunctionalize.

---

### 3.7 swift-kernel

2 products: Kernel, Kernel Test Support. Also has `_Lock Test Process` executable target.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns at this layer |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 10 deps on main target — large but all platform-conditional, justified by cross-platform unification role |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | REVIEW | 63 files in Kernel target — substantial but may be inherent to cross-platform unification |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | PASS | Kernel Test Support published as library product |
| MOD-012 | PASS | `Kernel`, `Kernel Test Support` — correct L3 naming |
| MOD-013 | N/A | 4 source targets, threshold is 5 (note: Package.swift has good internal comments even below threshold) |
| MOD-014 | N/A | Platform deps use `condition: .when(platforms:)` not traits — correct for always-needed platform abstraction |

**Findings**: 0 FAIL. 1 REVIEW (MOD-008): 63 files in Kernel is large but this is the cross-platform unification layer (Darwin + Linux + Windows + POSIX). Each platform variant is already in a separate package. Splitting Kernel further would require identifying sub-domains within the unified API (e.g., file descriptors, threads, signals). Worth investigating but not a clear violation.

---

### 3.8 swift-loader

1 product: Loader. 2 targets: Loader + CTypeMetadata (C shim).

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + C shim pattern |
| MOD-002 | N/A | Single Swift target |
| MOD-003 | N/A | CTypeMetadata is a C build dependency, not a variant |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single product |
| MOD-006 | REVIEW | Package declares `swift-darwin-primitives` as a package dep but no target uses it. Similarly `swift-windows` is listed but commented out. Unused package-level deps. |
| MOD-007 | PASS | Depth 1 (Loader → CTypeMetadata) |
| MOD-008 | PASS | Loader: 4 files, CTypeMetadata: C only |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Loader`, `CTypeMetadata` — CTypeMetadata is a C shim, naming is conventional |
| MOD-013 | N/A | 2 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). 1 REVIEW (MOD-006): Package-level `dependencies:` lists `swift-darwin-primitives` but no target references any product from it. Similarly `swift-windows` is declared but the only reference is commented out. These are dead package-level dependencies.

---

### 3.9 swift-parsers

2 products: Parsers, Parsers Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 7 deps — includes parser primitives, machine primitives, formatting, time, source, async, clocks — all justified for a parser infrastructure module |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | 13 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | PASS | Parsers Test Support published as library product |
| MOD-012 | PASS | `Parsers`, `Parsers Test Support` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. Clean compliance.

---

### 3.10 swift-pdf

2 products: PDF, PDF Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 3 deps (HTML, PDF HTML Rendering, File System) — minimal |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | 1 file in main target — this is a thin composition layer |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | PASS | PDF Test Support published as library product |
| MOD-012 | PASS | `PDF`, `PDF Test Support` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. Clean compliance. PDF is a thin orchestration layer above PDF HTML Rendering.

---

### 3.11 swift-pdf-html-rendering

2 products: PDF HTML Rendering, PDF HTML Rendering Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 10 deps — large count but each serves a distinct rendering concern (HTML, PDF, CSS, base64, layout, dictionary, stack, property) |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | REVIEW | 58 files in single target — moderate size, approaching split consideration |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | PASS | PDF HTML Rendering Test Support published as library product |
| MOD-012 | PASS | Correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. 1 REVIEW (MOD-008): 58 files is substantial but not at the critical threshold that CSS HTML Rendering's 515 files represents.

---

### 3.12 swift-pdf-rendering

2 products: PDF Rendering, PDF Rendering Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 5 deps — all justified (PDF Standard, Rendering Primitives, CoW, Layout, Property) |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | 34 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | PASS | PDF Rendering Test Support published as library product |
| MOD-012 | PASS | Correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. Clean compliance.

---

### 3.13 swift-posix

2 products: POSIX Kernel, POSIX Loader.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | REVIEW | 2 peer products share `ISO 9945` dep but no Core. With only 2 targets and 1 shared dep, Core may be over-engineering. |
| MOD-002 | REVIEW | `ISO 9945` (base product) declared independently in both targets. Minor — only 2 targets. |
| MOD-003 | PASS | Targets are independent |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | **FAIL** | No umbrella target |
| MOD-006 | PASS | Minimal deps (2 each from same package) |
| MOD-007 | PASS | Depth 1 (flat) |
| MOD-008 | PASS | Kernel: 6 files, Loader: 1 file |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `POSIX Kernel`, `POSIX Loader` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 2 FAIL (MOD-005, MOD-011). 2 REVIEW (MOD-001, MOD-002). Note: `swift-kernel-primitives` is declared as a package-level dependency but no target references any product from it. This is a dead package dependency (same class of issue as swift-loader).

---

### 3.14 swift-svg-rendering

2 products: SVG Rendering, SVG Rendering Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 6 deps — all justified for SVG rendering |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | 22 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | PASS | SVG Rendering Test Support published as library product |
| MOD-012 | PASS | Correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. Clean compliance.

---

### 3.15 swift-windows

2 products: Windows Kernel, Windows System.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | REVIEW | 2 peer products share `Windows Primitives` but no Core. Same pattern as POSIX — minimal shared surface. |
| MOD-002 | REVIEW | `Windows Primitives` declared in both targets independently |
| MOD-003 | PASS | Targets are independent |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | **FAIL** | No umbrella target |
| MOD-006 | PASS | Kernel: 5 deps, System: 2 deps — minimal |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | Kernel: 6 files, System: 4 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Windows Kernel`, `Windows System` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 2 FAIL (MOD-005, MOD-011). 2 REVIEW (MOD-001, MOD-002). Structurally identical to primitives-layer swift-windows-primitives finding.

---

### 3.16 swift-witnesses

2 products: Witnesses, Witnesses Macros. 3 source targets: Witnesses, Witnesses Macros, Witnesses Macros Implementation.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Macros pattern |
| MOD-002 | REVIEW | `Witness Primitives` declared in both Witnesses and Witnesses Macros target deps. Witnesses depends on Macros, so it could receive Witness Primitives transitively if Macros re-exports it. |
| MOD-003 | N/A | Not a variant package |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Two products but vertical (Witnesses depends on Macros) |
| MOD-006 | PASS | Each target declares deps it needs |
| MOD-007 | PASS | Depth 2 (Witnesses → Macros → Implementation) |
| MOD-008 | PASS | Main: 21 files, Macros: 1 file, Implementation: 5 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions |
| MOD-011 | **FAIL** | No Test Support product |
| MOD-012 | PASS | `Witnesses`, `Witnesses Macros` — correct L3 naming |
| MOD-013 | N/A | 4 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 1 FAIL (MOD-011). 1 REVIEW (MOD-002): `Witness Primitives` appears in both Witnesses and Witnesses Macros deps. Since Witnesses already depends on Witnesses Macros, this is a duplicate if Macros re-exports it. Verify whether `MemberImportVisibility` requires the explicit dependency declaration (see primitives delta audit section 5 — this is a systemic ecosystem pattern where MemberImportVisibility forces explicit dep declarations even when transitive access exists).

---

## 4. Aggregate Results

### 4.1 By Rule

| Rule | PASS | FAIL | REVIEW | N/A | Notes |
|------|------|------|--------|-----|-------|
| MOD-001 | 0 | 1 | 2 | 13 | FAIL: linux. REVIEW: posix, windows |
| MOD-002 | 2 | 1 | 4 | 9 | FAIL: linux. REVIEW: css, posix, windows, witnesses |
| MOD-003 | 3 | 0 | 0 | 13 | All peer-product packages pass |
| MOD-004 | 0 | 0 | 0 | 16 | No ~Copyable concerns at L3 |
| MOD-005 | 0 | 3 | 0 | 13 | FAIL: linux, posix, windows |
| MOD-006 | 13 | 0 | 2 | 1 | REVIEW: loader (dead deps), posix (dead dep) |
| MOD-007 | 16 | 0 | 0 | 0 | All pass, max depth 2 |
| MOD-008 | 13 | 1 | 2 | 0 | FAIL: css-html-rendering (515). REVIEW: kernel (63), pdf-html-rendering (58) |
| MOD-009 | 0 | 0 | 0 | 16 | No inline variants at L3 |
| MOD-010 | 0 | 0 | 0 | 16 | No stdlib extensions observed at L3 |
| MOD-011 | 7 | 9 | 0 | 0 | PASS: css-html-rendering, kernel, parsers, pdf, pdf-html-rendering, pdf-rendering, svg-rendering. FAIL: all others |
| MOD-012 | 16 | 0 | 0 | 0 | All pass — L3 naming convention followed consistently |
| MOD-013 | 0 | 0 | 0 | 16 | No package reaches 5-target threshold |
| MOD-014 | 0 | 0 | 0 | 16 | No trait-gated integration observed |

### 4.2 By Package

| # | Package | FAIL | REVIEW | Clean? |
|---|---------|------|--------|--------|
| 1 | swift-linux | 4 | 0 | No |
| 2 | swift-ascii | 1 | 1 | No |
| 3 | swift-css | 1 | 1 | No |
| 4 | swift-css-html-rendering | 1 | 0 | No |
| 5 | swift-defunctionalize | 1 | 0 | No |
| 6 | swift-dual | 1 | 0 | No |
| 7 | swift-kernel | 0 | 1 | REVIEW |
| 8 | swift-loader | 1 | 1 | No |
| 9 | swift-parsers | 0 | 0 | **Yes** |
| 10 | swift-pdf | 0 | 0 | **Yes** |
| 11 | swift-pdf-html-rendering | 0 | 1 | REVIEW |
| 12 | swift-pdf-rendering | 0 | 0 | **Yes** |
| 13 | swift-posix | 2 | 2 | No |
| 14 | swift-svg-rendering | 0 | 0 | **Yes** |
| 15 | swift-windows | 2 | 2 | No |
| 16 | swift-witnesses | 1 | 1 | No |

**Clean packages** (4): swift-parsers, swift-pdf, swift-pdf-rendering, swift-svg-rendering

---

## 5. Priority Findings

### 5.1 CRITICAL: CSS HTML Rendering — 515 files in single target (MOD-008)

**Package**: swift-css-html-rendering
**Target**: `CSS HTML Rendering`
**File count**: 515 Swift files
**Evidence**: `Sources/CSS HTML Rendering/` contains 515 .swift files with at least one subdirectory (`Layout/`)

This is the largest single-target file count in the entire ecosystem. For comparison, the prior primitives audit flagged `swift-standard-library-extensions` at 86 files as a monolith. At 515 files, this target is 6x larger than that prior worst case.

**Recommendation**: Investigate decomposition axes. The `Layout/` subdirectory suggests at least a `CSS HTML Rendering Layout` split. CSS properties, selectors, and rendering logic may form additional natural sub-domains.

### 5.2 HIGH: MOD-011 — 9 packages missing Test Support product

Nine of sixteen packages have no Test Support product. This blocks downstream packages from importing test fixtures.

| Package | Has Test Support Target? | Published as Product? |
|---------|------------------------|-----------------------|
| swift-linux | No | No |
| swift-ascii | **Yes** (1 file) | **No** — target exists but not a product |
| swift-css | No | No |
| swift-defunctionalize | No | No |
| swift-dual | No | No |
| swift-loader | No | No |
| swift-posix | No | No |
| swift-windows | No | No |
| swift-witnesses | No | No |

**Note**: swift-ascii is the most actionable — it already has the target; it just needs `.library(name: "ASCII Test Support", targets: ["ASCII Test Support"])` added to the products array.

### 5.3 MODERATE: Platform packages without Core/Umbrella (MOD-001, MOD-005)

Three packages follow the peer-products-without-Core pattern: swift-linux (3 products), swift-posix (2 products), swift-windows (2 products). This mirrors the same finding from the primitives-layer audit. The pattern is consistent — platform abstraction packages across both Layer 1 and Layer 3 use flat peer layouts.

**Decision needed**: Is the platform-abstraction pattern an accepted exception to MOD-001/MOD-005, or should all platform packages be retrofitted with Core + umbrella? Given the low file counts (1-6 files per target), the overhead of Core + umbrella may outweigh the benefit.

### 5.4 LOW: Dead package-level dependencies (MOD-006)

| Package | Dead Dependency | Notes |
|---------|----------------|-------|
| swift-loader | `swift-darwin-primitives` | Declared at package level, no target uses it |
| swift-loader | `swift-windows` | Declared at package level, target reference is commented out |
| swift-posix | `swift-kernel-primitives` | Declared at package level, no target uses it |

These cause unnecessary resolution overhead and should be removed.

### 5.5 LOW: Duplicate transitive deps (MOD-002, MemberImportVisibility pattern)

Several packages declare the same external dependency in both a parent and child target:

| Package | Duplicate Dep | Targets |
|---------|--------------|---------|
| swift-css | `CSS Standard` | CSS, CSS Theming (Theming depends on CSS) |
| swift-witnesses | `Witness Primitives` | Witnesses, Witnesses Macros (Witnesses depends on Macros) |
| swift-linux | `Linux Primitives` | All 3 targets |
| swift-linux | `Kernel Primitives` | Linux Kernel, Linux System |
| swift-posix | `ISO 9945` | POSIX Kernel, POSIX Loader |
| swift-windows | `Windows Primitives` | Windows Kernel, Windows System |

For vertical relationships (child depends on parent): these are likely required by `MemberImportVisibility` (SE-0444), which requires explicit import of transitive modules used directly. This is a systemic ecosystem pattern, not a true violation. See primitives delta audit section 5.

For peer relationships (linux, posix, windows): these are genuine duplications that a Core target would centralize.

---

## 6. Comparison with Primitives Audit

| Finding | Primitives (L1) | Foundations (L3, Batch B) |
|---------|-----------------|---------------------------|
| Platform packages without Core | FAIL (darwin, linux, windows) | FAIL (linux, posix, windows) — same pattern |
| MOD-011 Test Support missing | 22 packages | 9 packages |
| MOD-008 oversized targets | standard-library-extensions (86 files) | **css-html-rendering (515 files)** — 6x worse |
| MOD-002 dep duplication | 17 packages | 1 FAIL + 4 REVIEW — much less prevalent |
| MOD-012 naming | 3 violations | 0 violations — clean L3 naming |
| MOD-004 constraint isolation | 1 violation (heap) | 0 — no ~Copyable at L3 |
| Dead package deps | Not tracked | 3 instances (loader x2, posix x1) |

The foundations layer is structurally simpler than primitives (fewer multi-product packages, no ~Copyable concerns, consistent naming). The single critical finding is the 515-file CSS HTML Rendering monolith.

---

## 7. Totals

- **14 FAIL** across 12 packages
- **11 REVIEW** across 8 packages
- **4 clean packages** (parsers, pdf, pdf-rendering, svg-rendering)
- **1 critical finding** (CSS HTML Rendering 515-file monolith)
- **3 dead package-level dependencies** (loader, posix)
