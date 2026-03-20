# Modularization Audit: Ecosystem-Wide Summary

<!--
---
version: 1.0.0
created: 2026-03-20
status: COMPLETE
scope: swift-primitives (132 packages) + swift-foundations (67 packages)
skill: modularization (MOD-001 through MOD-014)
---
-->

## 1. Executive Summary

| Superrepo | Packages | Multi-target | FAIL | REVIEW | COMPLIANT |
|-----------|----------|-------------|------|--------|-----------|
| swift-primitives | 132 | 70 | 68 | 18 | 32 |
| swift-foundations | 67 | 28 | 49 | 16 | 17 |
| **Total** | **199** | **98** | **117** | **34** | **49** |

**Primitives status**: Existing 2026-03-14 audit remains fully current (zero Package.swift changes since). 4 of 5 top findings still open.

**Foundations status**: First audit completed 2026-03-20. 28 multi-target + 39 single-target packages assessed. Key finding: CSS HTML Rendering with 515 files in a single target — the largest in the ecosystem by 6x.

---

## 2. Top 10 Ecosystem-Wide Findings

| Rank | Package | Layer | Finding | Severity |
|------|---------|-------|---------|----------|
| 1 | **swift-css-html-rendering** | L3 | 515 files in single target (MOD-008) | CRITICAL |
| 2 | **swift-io** | L3 | Umbrella `IO` has 42 implementation files (MOD-005) | CRITICAL |
| 3 | **swift-heap-primitives** | L1 | `Swift.Sequence` conformance in Core (MOD-004) | HIGH |
| 4 | **swift-standard-library-extensions** | L1 | 86 files in single target across 15+ domains (MOD-008) | HIGH |
| 5 | **swift-storage-primitives** | L1 | 7 variants independently declare Property Primitives (MOD-002) | HIGH |
| 6 | **swift-html-rendering** | L3 | HTML Attributes/Elements Rendering: 125 files each (MOD-008) | HIGH |
| 7 | **swift-io** | L3 | IO Events: 72 files, depth-4 chains (MOD-007/008) | HIGH |
| 8 | **31 packages** | L1+L3 | Missing Test Support product (MOD-011) | MEDIUM |
| 9 | **Platform packages** (6) | L1+L3 | No Core, no umbrella (MOD-001/005) | MEDIUM |
| 10 | **17 L1 + 6 L3 packages** | L1+L3 | External deps not centralized through Core (MOD-002) | MEDIUM |

---

## 3. Cross-Layer Rule Compliance

| Rule | L1 FAIL | L3 FAIL | L3 REVIEW | Pattern |
|------|---------|---------|-----------|---------|
| MOD-001 Core | 7 | 6 | 2 | Platform packages lack Core at both layers |
| MOD-002 Ext Dep Central | 17 | 3 | 6 | Worse at L1; L3 has fewer multi-product packages |
| MOD-003 Variant Decomp | 1 | 0 | 0 | Clean across both layers |
| MOD-004 Constraint Iso | 1 | 0 | 0 | Only L1 (heap); L3 has no ~Copyable containers |
| MOD-005 Umbrella | 8 | 7 | 0 | L3 has implementation-in-umbrella pattern (IO, translating, plist) |
| MOD-006 Dep Min | 4 | 0 | 5 | L3 has dead package-level deps (loader, posix) |
| MOD-007 Graph Shape | 0 | 1 | 0 | Only swift-io at depth 4 |
| MOD-008 Split Decision | 6 | 5 | 4 | Both layers have oversized targets; L3 has the worst (515 files) |
| MOD-009 Inline Variant | 1 | 0 | 0 | No inline variants at L3 |
| MOD-010 StdLib Integration | 2 | 0 | 0 | L3 single-target: json/xml have stdlib extensions (low priority) |
| MOD-011 Test Support | 22 | 9 | 0 | Most widespread rule violation ecosystem-wide (31 total) |
| MOD-012 Naming | 3 | 5 | 0 | L3: compound names (translating), L1 names at L3 (IO/Plist/FileSystem "Primitives") |
| MOD-013 MARK Comments | 15 | 4 | 0 | Both layers lacking; only swift-tests exemplary at L3 |
| MOD-014 Cross-Pkg Traits | 0 | 0 | 0 | swift-dependencies is the exemplary implementation |

---

## 4. Systemic Patterns

### 4.1 Platform Package Pattern (6 packages, both layers)

The platform-abstraction packages at both L1 and L3 share an identical structure that deviates from MOD-001/005:

| Layer | Packages | Pattern |
|-------|----------|---------|
| L1 | swift-darwin-primitives, swift-linux-primitives, swift-windows-primitives | Peer products, no Core, no umbrella |
| L3 | swift-darwin, swift-linux, swift-windows | Same peer pattern |

**Decision needed**: Accept as documented exception or retrofit. Given low file counts (1-8 per target), the overhead of Core + umbrella likely exceeds the benefit. Recommend documenting as accepted deviation.

### 4.2 MemberImportVisibility-Driven Duplication (23+ packages)

Swift 6's `MemberImportVisibility` (SE-0444) requires explicit import of transitive modules. This forces many targets to re-declare dependencies that are already available transitively through Core's `@_exported import`. The pattern appears in:
- **L1**: 17 packages (storage, queue, set, parser-machine, etc.)
- **L3**: 6 packages (css, witnesses, linux, posix, windows, tests)

**Resolution**: Core targets should use `@_exported import` in `exports.swift`. Most L1 exemplars (parser-primitives, buffer-primitives) already do this correctly.

### 4.3 Umbrella-as-Implementation Anti-Pattern (L3 specific)

Four L3 packages have umbrella targets containing substantial implementation:

| Package | Target | Impl Files | Assessment |
|---------|--------|-----------|------------|
| swift-io | IO | 42 | CRITICAL — extract to IO Executor |
| swift-translating | Translating | 6 | Extract to variant targets |
| swift-plist | Plist | 3 | Borderline — routing logic |
| swift-testing | Testing | 7 | Justified — macro declarations |

This pattern does not exist at L1 (all L1 umbrellas are re-export-only).

### 4.4 L1 Naming at L3 (3 packages)

Three L3 packages name their Core-equivalent target `{Domain} Primitives` instead of `{Domain} Core`:
- swift-io: `IO Primitives` → should be `IO Core`
- swift-plist: `Plist Primitives` → should be `Plist Core`
- swift-file-system: `File System Primitives` → should be `File System Core`

The `Primitives` suffix is reserved for L1 packages per the five-layer architecture.

### 4.5 Oversized Single Targets

Targets exceeding 40 files across both layers (the top 15):

| Target | Package | Layer | Files |
|--------|---------|-------|------:|
| CSS HTML Rendering | swift-css-html-rendering | L3 | **515** |
| HTML Attributes Rendering | swift-html-rendering | L3 | 125 |
| HTML Elements Rendering | swift-html-rendering | L3 | 125 |
| Kernel File Primitives | swift-kernel-primitives | L1 | 93 |
| Standard Library Extensions | swift-standard-library-extensions | L1 | 86 |
| Linux Kernel Primitives | swift-linux-primitives | L1 | 75 |
| Windows Kernel Primitives | swift-windows-primitives | L1 | 76 |
| IO Events | swift-io | L3 | 72 |
| Markdown HTML Rendering | swift-markdown-html-rendering | L3 | 59 |
| PDF HTML Rendering | swift-pdf-html-rendering | L3 | 58 |
| Sequence Primitives Core | swift-sequence-primitives | L1 | 57 |
| Async Stream | swift-async | L3 | 55 |
| File System Primitives | swift-file-system | L3 | 54 |
| IO Completions | swift-io | L3 | 51 |
| Tests Performance | swift-tests | L3 | 45 |

---

## 5. Foundations-Specific Observations

### 5.1 Re-Export Facades (13 packages)

Thirteen single-target L3 packages are 1-file `@_exported import` re-exports of lower-layer modules: clocks, color, emailaddress, epub, ip-address, json-feed, locale, random, rss, time, uri. These are intentional architectural artifacts, not violations.

### 5.2 Stub/Placeholder Packages (10 packages)

Ten L3 packages have 0 bytes of source or no sources at all: abstract-syntax-tree, backend, compiler, diagnostic, driver, intermediate-representation, lexer, module, symbol, syntax, type. These form a compiler toolchain family. `swift-diagnostic` and `swift-driver` declare 9-10 unused dependencies.

### 5.3 Nested Test Packages (9 packages)

Nine L3 packages use the `Tests/Package.swift` nested package pattern for performance and snapshot tests: css, css-html-rendering, html, html-rendering, markdown-html-rendering, pdf, pdf-html-rendering, pdf-rendering, svg-rendering. This is the [INST-TEST-*] pattern from the testing-institute skill.

### 5.4 Exemplary L3 Packages

| Package | Why Exemplary |
|---------|---------------|
| **swift-dependencies** | Canonical MOD-014 implementation (SE-0450 trait-gated Clocks integration) |
| **swift-tests** | Proper Core + umbrella + MARK comments + Test Support. Only L3 package with exemplary MARK usage. |
| **swift-html-rendering** | Clean umbrella (re-export-only), trait-gated test support, consistent decomposition along HTML spec |
| **swift-parsers** | Zero violations, clean Main + Test Support pattern |
| **swift-pdf** | Zero violations, thin composition layer |
| **swift-pdf-rendering** | Zero violations, consistent naming and deps |
| **swift-svg-rendering** | Zero violations, consistent naming and deps |

---

## 6. Priority Remediation Roadmap

### Tier 1: Critical (structural violations with broad impact)

| # | Package | Layer | Fix |
|---|---------|-------|-----|
| 1 | swift-css-html-rendering | L3 | Decompose 515-file monolith by CSS domain (layout, properties, selectors) |
| 2 | swift-io | L3 | Extract IO umbrella's 42 impl files into `IO Executor` target |
| 3 | swift-heap-primitives | L1 | Move `Swift.Sequence` from Core to Heap Binary Primitives |

### Tier 2: High (material modularization improvement)

| # | Package | Layer | Fix |
|---|---------|-------|-----|
| 4 | swift-io | L3 | Rename `IO Primitives` → `IO Core`, make internal-only |
| 5 | swift-plist | L3 | Rename `Plist Primitives` → `Plist Core` |
| 6 | swift-file-system | L3 | Rename `File System Primitives` → `File System Core` |
| 7 | swift-storage-primitives | L1 | Centralize Property Primitives through Core |
| 8 | swift-standard-library-extensions | L1 | Decompose 86-file target by stdlib domain |
| 9 | swift-translating | L3 | Move 6 impl files from umbrella to variants; fix compound names |

### Tier 3: Medium (convention compliance, batch-fixable)

| # | Scope | Fix |
|---|-------|-----|
| 10 | 31 packages (22 L1, 9 L3) | Add Test Support products |
| 11 | 19 packages (15 L1, 4 L3) | Add `// MARK: -` comments |
| 12 | 6 platform packages | Document as accepted deviation or add Core + umbrella |
| 13 | 3 L3 packages | Remove dead package-level dependencies (loader, posix) |
| 14 | 5 L3 naming violations | Fix compound names in swift-translating |

### Tier 4: Low (polish, judgment calls)

| # | Scope | Fix |
|---|-------|-----|
| 15 | Large targets (45-125 files) | Evaluate decomposition case-by-case |
| 16 | json/xml | Consider StdLib Integration modules |
| 17 | 10 stub packages | Clean up unused deps or mark as placeholder |

---

## 7. Cross-References

| Document | Path |
|----------|------|
| Primitives audit (complete, 2026-03-14) | `swift-primitives/Research/modularization-audit/SUMMARY.md` |
| Primitives audit batch files (A-J) | `swift-primitives/Research/modularization-audit/batch-*.md` |
| Primitives delta report (2026-03-20) | `swift-institute/Research/modularization-audit-primitives-delta.md` |
| Foundations batch A (12 high/medium) | `swift-institute/Research/modularization-audit-foundations-batch-A.md` |
| Foundations batch B (16 standard) | `swift-institute/Research/modularization-audit-foundations-batch-B.md` |
| Foundations single-target (39 packages) | `swift-institute/Research/modularization-audit-foundations-single-target.md` |
| Modularization skill (canonical) | `swift-institute/Skills/modularization/SKILL.md` |
| Pattern extraction research | `swift-primitives/Research/intra-package-modularization-patterns.md` |
| Theoretical foundations | `swift-primitives/Research/modularization-theoretical-foundations.md` |
