# Validation receipt: [TEST-001]

Date: 2026-05-14
Rule: xctest import
Placement tier: institute
Pack: Linter Rule Framework

Detection method: regex pre-scan (`grep -rln 'import[[:space:]]\+XCTest\b'` on each package's `Sources/` + `Tests/`). Expected count was 0 across the ladder — TEST-001 is a preventive rule for a pattern that has not been adopted in the rule-compliant subset.

| Level | Package | Source files (Sources/+Tests/) | `import XCTest` count | Notes |
|-------|---------|-------------------------------:|----------------------:|-------|
| Simple | swift-tagged-primitives | (audited) | 0 | clean |
| Simple | swift-carrier-primitives | (audited) | 0 | clean |
| Simple | swift-pair-primitives | (audited) | 0 | clean |
| Medium | swift-property-primitives | (audited) | 0 | clean |
| Medium | swift-cardinal-primitives | (audited) | 0 | clean |
| Hard | swift-affine-primitives | (audited) | 0 | clean |
| Hard | swift-ordinal-primitives | (audited) | 0 | clean |

Per [PROMOTE-004] hard-level diagnostic budget: well under (0 of 10). No iteration loop required.

The regex is strictly broader than the AST rule (catches `import XCTest`, `import XCTest.X`, ` import XCTest`, `public import XCTest`, etc.); when the regex returns 0 the AST also returns ≤ 0. Validation passes.

## Methodology note for next sweep

When running the regex pre-scan, grep MUST be invoked directly on the package's `Sources/` and `Tests/` paths rather than via `find . -name '*.swift' | xargs grep` — the latter walks `.build/` artifacts and produces wildly inflated counts (e.g., 320+ files per package). Same lesson applies if a future pilot uses the test-target validation harness path, except `FileManager.default.enumerator` rooted at `<package>/Sources/` does the right thing by construction.
