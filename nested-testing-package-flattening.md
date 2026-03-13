# Nested Testing Package Flattening

<!--
---
version: 1.0.0
last_updated: 2026-03-13
status: DECISION
---
-->

## Context

The ecosystem-wide nested testing pattern ([INST-TEST-001]–[INST-TEST-010]) places swift-testing-dependent tests in `Tests/Testing/Package.swift`. This was decided in [nested-testing-package-structure.md](nested-testing-package-structure.md) (DECISION, 2026-03-05). The pattern works but produces deeply nested paths:

```
Tests/Testing/Tests/PDF Snapshot Tests/__Snapshots__/Snapshot Tests/all-elements.txt
```

The nesting is `Tests/ > Testing/ > Tests/ > target/ > __Snapshots__/` — five levels deep, with a redundant `Tests/Testing/Tests/` stutter.

10 packages currently use this pattern. The user observes this is "quite ugly" and proposes flattening: place `Package.swift` directly in `Tests/` so that snapshot and performance test directories sit alongside the parent's unit test directories.

**Trigger**: Convention evolution — the pattern works but the ergonomics are poor.

## Question

Can the nested testing package be relocated from `Tests/Testing/Package.swift` to `Tests/Package.swift` while preserving both:
1. Parent's `swift test` running only Apple Testing unit tests
2. Nested `swift test` (from `Tests/`) running snapshot + performance tests

## Constraints

| Constraint | Impact |
|-----------|--------|
| SwiftPM ignores subdirectories with their own `Package.swift` during **automatic** target discovery | If `Tests/Package.swift` exists, parent auto-discovery of test targets in `Tests/` fails |
| Parent test targets currently use auto-discovery (no explicit `path:`) | All 10 packages would need `path:` added to test target declarations |
| SwiftPM behavior with explicit `path:` pointing INTO a nested package directory is **undocumented** | Core unknown — needs experiment |
| Nested package relative path to parent changes from `../..` to `..` | Simpler path calculation |
| Nested package relative path to swift-testing shortens by one `../` | Minor ergonomic improvement |
| 10 packages need migration if pattern changes | Non-trivial ecosystem-wide change |
| `__Snapshots__/` paths shorten significantly | Better DX for snapshot review |

## Analysis

### Option A: Status Quo — `Tests/Testing/Package.swift`

Current ecosystem pattern per [INST-TEST-002].

```
swift-{pkg}/
  Package.swift
  Tests/
    {Module} Tests/                    ← auto-discovered by parent
    Testing/
      Package.swift                    ← nested package
      Tests/
        {Module} Performance Tests/
        {Module} Snapshot Tests/
          __Snapshots__/
```

**Advantages:**
- Proven: 10 packages use this, no issues
- Parent auto-discovery works unchanged
- Clear separation: `Testing/` is visually distinct

**Disadvantages:**
- `Tests/Testing/Tests/` stutter (three levels before test sources)
- `__Snapshots__/` paths are 5 levels deep
- `cd Tests/Testing` to run extended tests is non-obvious
- Name `Testing/` inside `Tests/` is redundant

---

### Option B: Flatten to `Tests/Package.swift`

Move the nested package up one level. All test directories live as siblings in `Tests/`.

```
swift-{pkg}/
  Package.swift                        ← parent, explicit path for test targets
  Tests/
    Package.swift                      ← nested package
    {Module} Tests/                    ← parent's Apple Testing (explicit path)
    {Module} Snapshot Tests/           ← nested package's test target
      __Snapshots__/
    {Module} Performance Tests/        ← nested package's test target
```

**Parent Package.swift change:**
```swift
.testTarget(
    name: "PDF Tests",
    dependencies: [...],
    path: "Tests/PDF Tests"            // explicit path required
)
```

**Nested Package.swift:**
```swift
// Tests/Package.swift
let package = Package(
    name: "testing",
    dependencies: [
        .package(path: ".."),          // parent is one level up (was ../..)
        .package(path: "../../swift-testing"),  // one fewer ../
    ],
    targets: [
        .testTarget(
            name: "PDF Snapshot Tests",
            dependencies: [...],
            path: "PDF Snapshot Tests"  // explicit path, same directory
        ),
        .testTarget(
            name: "PDF Performance Tests",
            dependencies: [...],
            path: "PDF Performance Tests"
        ),
    ]
)
```

**Advantages:**
- Flat structure: all test directories are siblings
- `__Snapshots__/` paths are 3 levels deep (down from 5)
- `cd Tests && swift test` to run extended tests
- Relative paths to parent and swift-testing are simpler
- Eliminates `Tests/Testing/Tests/` stutter

**Disadvantages:**
- **CRITICAL UNKNOWN**: Can the parent's explicit `path: "Tests/PDF Tests"` reach into a directory that has its own `Package.swift`? SwiftPM may consider the entire `Tests/` tree as belonging to the nested package and refuse the parent's claim.
- All 10 packages need explicit `path:` added to parent test targets
- Mixed ownership: some directories in `Tests/` belong to parent, some to nested package
- Less obvious visual separation between parent tests and nested tests

**Requires experiment**: [EXP-B] Validate SwiftPM allows parent to claim sources inside nested package directory.

---

### Option C: Separate Parent Tests Directory

Avoid the conflict by giving the parent a non-`Tests/` directory.

```
swift-{pkg}/
  Package.swift                        ← parent, path: "Test/{Module} Tests"
  Test/                                ← parent tests (singular)
    {Module} Tests/
  Tests/                               ← nested package
    Package.swift
    {Module} Snapshot Tests/
      __Snapshots__/
    {Module} Performance Tests/
```

**Advantages:**
- No ownership ambiguity — `Test/` is parent's, `Tests/` is nested's
- Nested package auto-discovery could work (test targets in `Tests/` relative to `Tests/Package.swift` — but this would be `Tests/Tests/`, which doesn't exist, so still needs explicit paths)

**Disadvantages:**
- Breaks universal `Tests/` convention
- `Test/` vs `Tests/` is confusing and error-prone
- Requires parent `path:` override

---

### Option D: Nested Package at `Tests/Package.swift` with Subdirectory

Hybrid: Package.swift in `Tests/`, but nested test sources in a subdirectory.

```
swift-{pkg}/
  Package.swift
  Tests/
    Package.swift                      ← nested package
    {Module} Tests/                    ← parent (explicit path)
    Extended/                          ← subdirectory for nested test targets
      {Module} Snapshot Tests/
        __Snapshots__/
      {Module} Performance Tests/
```

**Advantages:**
- Visual separation (Extended/ vs unit test dirs)
- Still flatter than status quo

**Disadvantages:**
- Same critical unknown as Option B (parent path into nested package dir)
- Still has a grouping directory, just named differently
- `Extended/` is not self-documenting about swift-testing dependency

---

## Comparison

| Criterion | A: Status Quo | B: Flatten | C: Split Dirs | D: Subdirectory |
|-----------|--------------|-----------|---------------|-----------------|
| Path depth to `__Snapshots__/` | 5 levels | 3 levels | 3 levels | 4 levels |
| Parent needs explicit `path:` | No | Yes | Yes | Yes |
| SwiftPM behavior validated | Yes | **Yes (EXP-B)** | **Unknown** | **Unknown** |
| Convention compliance | Standard | Non-standard | Non-standard | Non-standard |
| Visual separation | Excellent | Poor | Excellent | Good |
| Migration effort (10 pkgs) | None | Medium | High | Medium |
| `Tests/` stutter eliminated | No | Yes | Yes | Partial |

## Experiment Results

### [EXP-B] Parent Package Claims Sources Inside Nested Package Directory — CONFIRMED

**Experiment**: `swift-institute/Experiments/nested-package-source-ownership/`

**Setup**:
```
experiment/
  Package.swift          ← parent, products: [Lib], testTarget path: "Tests/Unit Tests"
  Sources/Lib/Lib.swift
  Tests/
    Package.swift        ← nested, depends on parent's Lib, testTarget path: "Extended Tests"
    Unit Tests/
      UnitTest.swift     ← @Test func libGreets()
    Extended Tests/
      ExtendedTest.swift ← @Test func libGreetsExtended()
```

**Results**:

| Command | Working Dir | Tests Discovered | Result |
|---------|------------|-----------------|--------|
| `swift test` | `experiment/` | `libGreets()` only | PASS |
| `swift test` | `experiment/Tests/` | `libGreetsExtended()` only | PASS |

**Findings**:
1. Explicit `path:` overrides automatic discovery — parent's test target compiles correctly
2. Complete isolation — each `swift test` discovers only its own package's tests
3. No source ownership conflict — SwiftPM does NOT consider `Tests/` "owned" by the nested package
4. Nested package depends on parent via `path: ".."` (simpler than `../..`)
5. Parent must export products (already the case for all ecosystem packages)

## Outcome

**Status**: DECISION

**Decision**: **Option B — Flatten to `Tests/Package.swift`**

**Rationale**:
1. [EXP-B] confirmed the critical unknown — explicit `path:` works alongside nested `Package.swift`
2. Eliminates `Tests/Testing/Tests/` stutter (3 levels → 1 level of nesting)
3. `__Snapshots__/` paths shrink from 5 levels to 3
4. Relative paths simplify: parent is `..` (was `../..`), swift-testing loses one `../`
5. The cost (adding explicit `path:` to parent test targets) is mechanical and one-time

**Migration**:
1. Move `Tests/Testing/Package.swift` → `Tests/Package.swift`
2. Move `Tests/Testing/Tests/{Module} * Tests/` → `Tests/{Module} * Tests/` (siblings to unit tests)
3. Update nested `Package.swift`: parent dependency `../..` → `..`, swift-testing path adjusts
4. Update nested `Package.swift`: test target paths become relative to `Tests/`
5. Add explicit `path:` to parent `Package.swift` test targets
6. Update [INST-TEST-002] in testing-institute skill

**New canonical structure**:
```
swift-{pkg}/
  Package.swift                    ← parent, test targets with explicit path:
  Sources/{Module}/
  Tests/
    Package.swift                  ← nested package (depends on parent + swift-testing)
    {Module} Tests/                ← Apple Testing (unit + edge case)
    {Module} Snapshot Tests/       ← swift-testing snapshot tests
      __Snapshots__/
    {Module} Performance Tests/    ← swift-testing performance tests
```

## References

- Prior research: [nested-testing-package-structure.md](nested-testing-package-structure.md) (DECISION, 2026-03-05)
- testing-institute skill: [INST-TEST-001]–[INST-TEST-010]
- Affected packages: swift-pdf, swift-html, swift-css, swift-svg, swift-html-rendering, swift-pdf-html-rendering, swift-pdf-rendering, swift-svg-rendering, swift-svg-rendering-worktree, swift-tests
