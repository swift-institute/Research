# Test Support Snapshot Strategy Sharing

<!--
---
version: 1.1.0
last_updated: 2026-04-13
status: DEFERRED
---
-->

## Context

The Swift Institute ecosystem separates test infrastructure into two layers:

1. **Parent Test Support** (`Tests/Support/`, declared as `.target()` in parent `Package.swift`) — provides literal conformances, factory methods, harnesses. No swift-testing dependency. Consumable cross-package via product export. Governed by [TEST-010].

2. **Nested Test Support** (`Tests/Snapshot Support/` or similar, declared in `Tests/Package.swift`) — provides snapshot strategies, performance traits, and other swift-testing-dependent utilities. Lives inside the nested package to avoid leaking test framework dependencies into production manifests.

This separation works when test support is consumed only within the same package. It breaks when multiple packages need the same swift-testing-dependent test support — specifically, when multiple packages need the same `Test.Snapshot.Strategy` extension.

### The Concrete Problem

The `.html` snapshot strategy (converting `HTML.View` to `String` for snapshot comparison) is currently duplicated across **4 packages**:

| Package | Location | Access |
|---------|----------|--------|
| swift-html-rendering | `Tests/Snapshot Support/` | `public` (nested target) |
| swift-css | `Tests/Support/` | `public` |
| swift-css-html-rendering | `Tests/Snapshot Support/` | `public` |
| swift-html | `Tests/HTML Snapshot Tests/` | `internal` |

All 4 are semantically identical (~40 lines). A 5th package (swift-markdown-html-rendering) needs the same strategy but cannot access any of the existing definitions.

The strategy requires two dependencies:
- `HTML_Renderable` (Layer 3 production code — provides `HTML.View`, `String.init(_:)`)
- `Test_Snapshot_Primitives` (Layer 1 test infrastructure — provides `Test.Snapshot.Strategy`, `.pullback`)

### Trigger

Audit of rendering package test infrastructure revealed the duplication. Adding swift-markdown-html-rendering's nested test package exposed that no sharing mechanism exists.

### SPM Constraint

Nested `Tests/Package.swift` files cannot be referenced as path dependencies from other nested packages because:
1. SPM derives package identity from the directory name for path-based deps
2. All nested packages sit in directories named `Tests/`
3. Even with unique `name:` fields in Package.swift, SPM uses directory-based identity
4. A nested package inside a parent that's already in the dependency graph cannot be independently referenced

This was verified empirically: `.package(path: "../../swift-html-rendering/Tests")` resolves but products declared there are not found.

## Question

How should the ecosystem share `Test.Snapshot.Strategy` extensions (and other swift-testing-dependent test utilities) across packages without duplicating code or leaking test dependencies into production package manifests?

## Constraints

| Constraint | Source | Non-negotiable? |
|-----------|--------|-----------------|
| No test framework dependencies in production `Package.swift` | User principle | Yes |
| No code duplication of shared test infrastructure | User principle | Yes |
| No new package for trivial amounts of code | Pragmatic | Soft |
| Nested packages cannot cross-reference each other | SPM limitation | Yes (current SPM) |
| Parent Test Support cannot depend on `Test_Snapshot_Primitives` | Follows from constraint 1 | Yes |
| Layer architecture: no lateral deps between L3 packages | [ARCH-LAYER] | Yes for production; unclear for test infra |

## Analysis

### Option A: Standalone Test Support Package

Create `swift-foundations/swift-html-test-support/` as a proper SPM package.

```
swift-html-test-support/
  Package.swift          # depends on html-rendering + test-primitives
  Sources/
    HTML Test Support/
      Test.Snapshot.Strategy+HTML.swift
      exports.swift
```

**Advantages:**
- Strategy defined once
- Proper SPM identity, consumable by any nested package
- Clean separation: test infrastructure in test package

**Disadvantages:**
- New package for ~40 lines of code
- Package proliferation: would need similar packages for PDF, SVG strategies
- Lateral Layer 3 dependency (html-test-support → html-rendering)

**Verdict:** Architecturally clean but over-engineered. Scales to 3+ packages (HTML, PDF, SVG) which makes it worse.

---

### Option B: Add Test Primitives to Parent Test Support

Add `swift-test-primitives` as a dependency of `swift-html-rendering`'s parent Package.swift, used only by the `HTML Renderable Test Support` target.

```swift
// In swift-html-rendering/Package.swift
.target(
    name: "HTML Renderable Test Support",
    dependencies: [
        .htmlRenderable,
        .product(name: "Test Snapshot Primitives", package: "swift-test-primitives"),
    ],
    path: "Tests/Support"
),
```

**Advantages:**
- Strategy defined once in existing Test Support module
- Already consumable by all nested packages
- No new packages, no structural changes
- `swift-test-primitives` is Layer 1; html-rendering is Layer 3 — dependency direction is valid

**Disadvantages:**
- `swift-test-primitives` appears in production package's `dependencies` array
- Violates principle: "no test deps in production manifests"
- Sets precedent: other production packages would add test-primitives too

**Verdict:** Pragmatic but violates stated principle. The dependency IS test-specific even though the target is a `.target()` (required by [TEST-010] for cross-package consumption).

---

### Option C: Restructure Nested Package Identity

Rename html-rendering's `Tests/` directory to enable unique SPM identity, then export the strategy as a product.

**Approach C1: Rename directory**
```
swift-html-rendering/
  TestPackage/           # was Tests/
    Package.swift        # name: "swift-html-rendering-testing"
```

**Approach C2: Symlink**
```
swift-foundations/
  swift-html-rendering-testing -> swift-html-rendering/Tests/
```

**Approach C3: Git submodule**
Treat the nested test package as a submodule with its own repo.

**Advantages (all C variants):**
- Strategy defined once
- Proper SPM identity

**Disadvantages:**
- C1: Breaks [INST-TEST-002] convention; parent's unit tests need to move or path adjustments
- C2: Symlinks in git are platform-dependent; confuses tooling
- C3: Massive overhead for test infrastructure

**Verdict:** All variants introduce more complexity than they solve.

---

### Option D: Host in swift-tests

Add `swift-html-rendering` as a dependency of `swift-tests` (the ecosystem's test framework). Create an `HTML Snapshot` module there.

```swift
// In swift-tests/Package.swift
.target(
    name: "Tests HTML Snapshot",
    dependencies: [
        "Tests Snapshot",
        .product(name: "HTML Renderable", package: "swift-html-rendering"),
    ]
),
```

**Advantages:**
- Strategy defined once
- `swift-tests` IS a test package — test deps belong there
- Natural home: snapshot strategies are testing infrastructure

**Disadvantages:**
- Lateral Layer 3 dependency (swift-tests → swift-html-rendering)
- Widens swift-tests' dependency graph: packages using swift-tests for non-HTML testing pull in html-rendering
- Would need similar modules for PDF, SVG — swift-tests becomes a dependency aggregator

**Verdict:** Violates layer architecture. Makes swift-tests too broad.

---

### Option E: Trait-Gated Module in swift-tests

Use SE-0450 package traits to conditionally include the HTML snapshot module.

```swift
// In swift-tests/Package.swift
let traits: [Trait] = [
    .trait(name: "HTML", enabledByDefault: false),
]

// Module only included when trait is enabled
.target(
    name: "Tests HTML Snapshot",
    dependencies: [...],
    condition: .when(traits: ["HTML"])
),
```

Consumer nested packages would enable the trait:
```swift
.package(path: "../../swift-tests", traits: ["HTML"]),
```

**Advantages:**
- Strategy defined once
- Opt-in: packages that don't need HTML don't pull it in
- No lateral dep for non-HTML consumers

**Disadvantages:**
- SE-0450 is experimental (Swift 6.2)
- Still requires swift-tests to declare html-rendering as a dependency
- Trait-gated targets are a new pattern — adds cognitive overhead
- Not yet validated in the ecosystem

**Verdict:** Most principled solution for the future, but depends on experimental Swift feature.

---

### Option F: Generic Strategy via Protocol Witness

Instead of format-specific strategy extensions, provide a generic `pullback`-based strategy constructor in `Test_Snapshot_Primitives` that any module with a `String.init(_:)` can use.

```swift
// In Test_Snapshot_Primitives (already exists)
extension Test.Snapshot.Strategy where Format == String {
    public static func rendered<V>(
        _ transform: @escaping (V) -> String
    ) -> Test.Snapshot.Strategy<V, String> {
        .lines.pullback(transform)
    }
}
```

Each nested package would then write:
```swift
// One line per package — NOT a strategy definition, just a convenience alias
extension Test.Snapshot.Strategy where Value: HTML.View, Format == String {
    static var html: Self { .rendered { (try? String($0)) ?? "" } }
}
```

**Advantages:**
- Infrastructure (`.rendered`) defined once in Layer 1
- Per-package convenience is 1 line, not 40 — arguably not "duplication" but "configuration"
- No cross-package sharing needed
- No test deps in production packages

**Disadvantages:**
- Still has 1-line extensions in each nested package
- The `.rendered` generic may already exist (`.pullback` IS the generic)
- Doesn't address future cases where shared test support grows beyond strategies

**Verdict:** Minimizes duplication to a trivial alias. Pragmatic. But doesn't solve the general problem.

---

### Option G: Merge Test Support Layers

Collapse the two-layer Test Support model into one. Parent Test Support becomes the nested Test Support — it lives in the nested `Tests/Package.swift` and can depend on swift-testing.

Parent packages no longer export Test Support as a product. Instead, each nested package declares its own Test Support target that re-exports everything the parent Test Support used to provide (literal conformances, factory methods) PLUS snapshot strategies.

```
Tests/
  Package.swift          # declares Test Support + test targets
  Support/               # Test Support with snapshot strategies
  {Module} Tests/        # unit tests (Apple Testing)
  {Module} Snapshot Tests/
  {Module} Performance Tests/
```

Parent `Package.swift` would have zero test-related targets or products.

**Advantages:**
- Clean separation: ALL test infrastructure in nested package
- No test deps in production manifests
- Test Support can depend on swift-testing, test-primitives, etc.

**Disadvantages:**
- Breaks [TEST-010] cross-package Test Support chain
- Literal conformances from parent Test Support (e.g., `ExpressibleByIntegerLiteral` for `Tagged`) would need to move to nested packages — but then they can't be consumed by OTHER packages' parent test targets
- Fundamental: parent test targets (Apple Testing) need literal conformances, but those are currently provided by parent Test Support. Moving Test Support to nested package makes it invisible to parent test targets.

**Verdict:** Breaks the re-export chain that [TEST-020]/[TEST-021] establish. The parent Test Support exists precisely because parent test targets need it. Cannot be fully merged.

---

### Option H: Split Test Support into Two Products

Parent Test Support stays as-is (literal conformances, factory methods — no swift-testing deps). Add a SECOND Test Support product that DOES depend on swift-testing, hosted in the nested package.

The nested Test Support re-exports the parent Test Support plus adds snapshot strategies.

```
Tests/
  Package.swift          # declares Nested Test Support + test targets
  Support/               # Parent Test Support (no swift-testing)
  Nested Support/        # Nested Test Support (with swift-testing)
  {Module} Tests/
  {Module} Snapshot Tests/
```

To share: the question returns to "how does another nested package import this?"

**Verdict:** Doesn't solve the cross-package sharing problem. Same SPM identity limitation.

## Comparison

| Criterion | A (Standalone) | B (Parent dep) | C (Restructure) | D (swift-tests) | E (Traits) | F (Generic) | G (Merge) | H (Split) |
|-----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Strategy defined once | Yes | Yes | Yes | Yes | Yes | ~1 line each | Yes | Yes |
| No test deps in prod | Yes | **No** | Yes | Yes | Yes | Yes | Yes | Yes |
| No new packages | **No** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Works with current SPM | Yes | Yes | Fragile | Yes | **No** | Yes | Yes | **No** |
| Layer arch compliant | Soft | Yes | Yes | **No** | Soft | Yes | **No** | **No** |
| Scales to PDF/SVG | **No** (proliferation) | Yes | **No** | **No** | Yes | Yes | N/A | N/A |
| Minimal complexity | **No** | Yes | **No** | **No** | **No** | Yes | **No** | **No** |

## Outcome

**Status**: DEFERRED

### Deferred

- **Blocker**: SE-0450 package traits stabilization
- **Resumption trigger**: Swift 6.2 release

### Preliminary Assessment

No option satisfies all constraints perfectly. The tension is fundamental:

1. Test Support must be a parent product (for cross-package literal conformances) → lives in parent Package.swift
2. Snapshot strategies need swift-testing deps → cannot be in parent Package.swift
3. Nested packages can't share with each other → strategies can't be defined once in a nested package

The most promising directions are:

- **Option F** (generic strategy) for the immediate term: reduce the "duplication" to a 1-line convenience alias per package. The infrastructure (`pullback`, `lines`) already exists in Layer 1. The alias is configuration, not logic.

- **Option E** (trait-gated) for the future: when SE-0450 stabilizes, swift-tests can host format-specific snapshot modules behind opt-in traits. This is the principally correct long-term answer.

- **Option B** (parent dep) if the principle is relaxed: `swift-test-primitives` is Layer 1 with zero transitive deps. Adding it to a parent manifest is a metadata change, not a production dependency. The Test Support target is already test-specific by purpose — the constraint is about the manifest, not the code.

### Open Questions

1. Does SE-0450 package traits support conditional dependencies (not just conditional targets)?
2. Could SPM be enhanced to support nested package product export (file issue)?
3. Is a 1-line alias (Option F) "duplication" or "configuration"?

## References

- [nested-testing-package-structure.md](nested-testing-package-structure.md) — DECISION, original nested package pattern
- [nested-testing-package-flattening.md](nested-testing-package-flattening.md) — DECISION, Tests/Testing/ → Tests/ migration
- [TEST-010] — Test Support as `.target()` in parent Package.swift
- [TEST-020]/[TEST-021] — Re-export chain architecture
- [INST-TEST-001] — Nested package requirement
- SE-0450 — Package Traits (experimental, Swift 6.2)
