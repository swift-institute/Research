# swift-pdf Audit: Implementation + Naming

Date: 2026-03-13

## Summary
- Total files audited: 8
- Total violations found: 13
- Critical (naming/compound types): 5
- Implementation style: 8

## Notes

The `swift-pdf` package is a thin umbrella module. It has a single source file (`Sources/PDF/exports.swift`) that re-exports five dependencies. All substantive code lives in test and experiment files. The audit covers the source file, all test files, and experiment files.

## Violations

### [API-NAME-001] Compound type names in test helpers

- **File**: `Tests/PDF Tests/PDF Tests.swift:328`
- **Issue**: `TableDemoHeader` is a compound type name. Should be nested under a namespace.
- **Current**: `private struct TableDemoHeader: HTML.View`
- **Expected**: Nested namespace, e.g., `Table.Demo.Header` or similar `Nest.Name` pattern. However, since these are private test-only structs not exposed as API, this is LOW severity.

Also affects: `TableSection6_1` (line 628), `TableSection6_2` (line 671), `TableSection6_3` (line 709), `TableSection6_4` (line 758), `TableSection6_5` (line 806), `TableSection6_6` (line 840), `TableSection6_7` (line 886), `TableDemoView` (line 324), `TableDemoView2` (line 333), `NDADemoView` (line 343), `NDADemoPreamble` (line 1000), `NDADemoArticles` (line 1055), `NDADemoClosing` (line 1121), `TextStylingDemo` (line 354), `LinksDemo` (line 428), `BlockElementsDemo` (line 443), `ListsDemo` (line 457), `ListsDemoBasic` (line 464), `ListsDemoAdvanced` (line 543), `HeadingsDemo` (line 607), `DescriptionListDemo` (line 944), `SemanticDemo` (line 957), `FigureDemo` (line 973), `NestedListDemo` (line 982), `InlineStyleDemo` (line 1189), `TechnicalSpecificationView` (line 131), `TechSpecFrontMatter` (line 140), `TechSpecSections4Through6` (line 157), `TechSpecSections7Through9` (line 203), `TechSpecAnnexes` (line 267), `ComplexView` (line 304), `MarkdownToPDF` (line 1250).

**Severity**: LOW -- all are `private` test helper types, not public API. The naming convention technically applies but the practical impact is minimal for test scaffolding.

---

### [API-NAME-001] Compound type names in performance test helpers

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:205`
- **Issue**: `Doc1`, `Doc10`, `Doc50`, `Doc100`, `Doc200`, `Doc500`, `Para10`, `Para100` are compound-ish names (number-suffixed rather than namespaced).
- **Current**: `struct Doc1: HTML.View`, `struct Doc10: HTML.View`, etc.
- **Expected**: Nested namespace pattern, e.g., `Doc.Paragraphs1`, `Doc.Paragraphs10`, or a parameterized approach.

**Severity**: LOW -- these are test-internal helpers for benchmarking.

---

### [API-NAME-002] Compound method name `generateBatch`

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:8`
- **Issue**: `generateBatch` is a compound method name.
- **Current**: `private func generateBatch(count: Int)`
- **Expected**: `generate.batch(count:)` or similar nested accessor pattern.

**Severity**: LOW -- private test helper function, not public API.

---

### [API-NAME-002] Compound method name `generateDocument`

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:154`
- **Issue**: `generateDocument` is a compound method name.
- **Current**: `private func generateDocument(paragraphs count: Int)`
- **Expected**: `generate.document(paragraphs:)` or similar nested accessor pattern.

**Severity**: LOW -- private test helper function.

---

### [API-NAME-002] Compound method name `measureThroughput`

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:158`
- **Issue**: `measureThroughput` is a compound method name.
- **Current**: `private func measureThroughput(paragraphs: Int, duration: Duration)`
- **Expected**: `measure.throughput(paragraphs:duration:)` or similar nested accessor pattern.

**Severity**: LOW -- private test helper function.

---

### [API-NAME-002] Compound method names `makePDF`, `makePDFDirect`, `makePDFDirectWithSize`

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:179`
- **Issue**: `makePDF`, `makePDFDirect`, `makePDFDirectWithSize` are compound method names.
- **Current**: `func makePDF(paragraphs: Int)`, `private func makePDFDirect(paragraphs: Int)`, `private func makePDFDirectWithSize(paragraphs: Int) -> Int`
- **Expected**: Nested accessor pattern, e.g., `make.pdf(paragraphs:)`.

**Severity**: LOW -- test helper functions.

---

### [API-NAME-002] Compound method name `compareAtScale`

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Pipeline Analysis.swift:46`
- **Issue**: `compareAtScale` is a compound method name.
- **Current**: `private func compareAtScale(paragraphs: Int, iterations: Int)`
- **Expected**: `compare.atScale(paragraphs:iterations:)` or similar nested accessor pattern.

**Severity**: LOW -- private test helper function.

---

### [API-NAME-002] Compound method name `printOutline`

- **File**: `Tests/PDF Tests/PDF Tests.swift:116`
- **Issue**: `printOutline` is a compound method name.
- **Current**: `private func printOutline(_ items: [ISO_32000.Outline.Item], indent: Int)`
- **Expected**: Nested accessor pattern.

**Severity**: LOW -- private test helper function.

---

### [PATTERN-009] Unused Foundation import in test file

- **File**: `Tests/PDF Tests/PDF Tests.swift:4`
- **Issue**: `import Foundation` in test file. No Foundation types appear to be directly referenced. The `String(repeating:count:)` on line 117 is stdlib, not Foundation.
- **Current**: `import Foundation`
- **Expected**: Remove unused import.

**Severity**: MEDIUM -- unused import adds unnecessary dependency.

---

### [PATTERN-009] Foundation import in performance test files

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:3`
- **Issue**: `import Foundation` is used for `String(format:)` and `.padding(toLength:)`. These are Foundation extensions on String.
- **Current**: `import Foundation`
- **Expected**: Foundation is needed for `String(format:)`. Consider replacing with stdlib alternatives to eliminate the dependency, or accept it as test-only.

**Severity**: LOW -- test file, and Foundation is legitimately used.

---

### [PATTERN-009] Foundation import in Pipeline Analysis

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Pipeline Analysis.swift:3`
- **Issue**: `import Foundation` -- same situation as above, used for `String(format:)`.
- **Current**: `import Foundation`
- **Expected**: Same as above.

**Severity**: LOW -- test file.

---

### [PATTERN-009] Unused Foundation import in experiment

- **File**: `Experiments/result-builder-stack-overflow/Sources/main.swift:16`
- **Issue**: `import Foundation` appears unused in this file. No Foundation types are referenced.
- **Current**: `import Foundation`
- **Expected**: Remove unused import.

**Severity**: LOW -- experiment file, not production code.

---

### [IMPL-EXPR-001] Unnecessary intermediate variables in performance tests

- **File**: `Tests/Testing/Tests/PDF Performance Tests/Performance Tests.swift:84-101`
- **Issue**: The `scalingAnalysis` function accumulates results into an intermediate array, then iterates it for printing. The computation and printing could be fused into a single loop, eliminating the `results` intermediate.
- **Current**:
```swift
var results: [(size: Int, time: Double)] = []
for size in sizes {
    // ... compute ...
    results.append((size, avgTime))
}
// ... iterate results for printing ...
```
- **Expected**: Fuse measurement and reporting into a single pass, or accept the two-pass approach as intentional for clarity (the second pass computes the scaling exponent from first and last results).

**Severity**: LOW -- test helper code, two-pass approach is arguably intentional since the scaling exponent needs first/last values.

---

## Clean Areas

The following rules were checked and produced NO violations:

- **[API-NAME-003]**: The package correctly uses `PDF.Document`, `PDF.Text`, `ISO_32000.Outline.Item` -- specification-mirroring names are properly used.
- **[API-NAME-004]**: No typealiases for type unification found.
- **[IMPL-INTENT]**: The source code (exports.swift) is purely declarative. Test code reads as intent (create document, write, expect).
- **[IMPL-000]**: Call-site-first design is evident in the `PDF.Document { ... }` builder pattern.
- **[IMPL-002]**: No raw value extraction at call sites.
- **[IMPL-004]**: No raw value comparisons found.
- **[IMPL-006]**: Not applicable (no stored properties in this package).
- **[IMPL-010]**: No Int boundary concerns found.
- **[IMPL-020]**: Not applicable (no verb-as-property patterns needed).
- **[IMPL-021]**: Not applicable (no Property/Property.View usage).
- **[IMPL-030]**: Inline construction is used throughout (e.g., `PDF.Document { ... }`).
- **[IMPL-031]**: No manual switch statements that should be enum iteration (the `makePDF` switch is over runtime values, not enum cases).
- **[IMPL-034]**: `unsafe` keyword is used correctly in experiment file (line 22-23).
- **[IMPL-040]**: No throwing functions in the package source to evaluate.
- **[IMPL-041]**: Not applicable (no error types defined).
- **[IMPL-050-053]**: Not applicable (no static-capacity types).
- **[PATTERN-010]**: Nested type names are correctly used (`PDF.Test.Unit`, `PDF.Test.Scaling`).
- **[PATTERN-017]**: No rawValue usage at call sites.
- **[PATTERN-018]**: No Int escape for arithmetic.
- **[PATTERN-022]**: Not applicable (no ~Copyable nested types).
- **[IMPL-003]**: Not applicable (no domain crossing).
- **[IMPL-032]**: Not applicable (no per-element loops that should be bulk operations).
- **[IMPL-033]**: Iteration patterns are acceptable; index variables carry semantic meaning.

## Overall Assessment

The `swift-pdf` package is a minimal umbrella re-export module with a single 7-line source file. The source code itself is clean with zero violations.

All 13 findings are in test and experiment files:
- 8 are compound method/type names in private test helpers (LOW severity)
- 4 are Foundation imports (1 MEDIUM for unused import, 3 LOW)
- 1 is an unnecessary intermediate variable (LOW)

**Recommendation**: The MEDIUM-severity unused `import Foundation` in `PDF Tests.swift` should be investigated -- if no Foundation API is actually used, remove it. The compound naming violations in test helpers are technically correct findings but low priority since they are private, non-API code.
