# R5 27-hit Verification — swift-linter-rules Package Extraction (Phase 3)

**Date**: 2026-05-07
**Phase**: 3 (`HANDOFF-swift-linter-rules-package-extraction.md`)
**Outcome**: GATE PASSED — 27 hits preserved end-to-end across the
package extraction. Pure-structural change; rule predicate logic
unchanged.

---

## Setup

Phase 2.5b sign-off granted 2026-05-07. Pre-flight check verified:

- 4 rule targets present in `swift-foundations/swift-linter/Sources/`:
  `Linter Rule Unchecked`, `Linter Rule Cardinal`,
  `Linter Rule RawValue`, `Linter Rule ResultBuilder`.
- No external consumer of rule products outside swift-linter
  (`grep -rln 'product.*Linter Rule'` excluding swift-linter's own
  Package.swift returned empty).
- swift-linter-rules destination directory absent (`ls` returned
  "No such file or directory").
- R5 baseline = **27** on `swift-tagged-primitives`.

## Structural changes

### NEW package: `swift-foundations/swift-linter-rules`

- `Package.swift` declares 4 library products, 4 target blocks,
  4 test target blocks. Dependencies:
  `../../swift-primitives/swift-linter-primitives` (L1 protocol surface)
  + `swift-syntax` (Apple, remote).
- LICENSE.md (Apache 2.0), .gitignore, .swift-format, README.md
  authored from cohort boilerplate.
- `Sources/Linter Rule {Unchecked,Cardinal,RawValue,ResultBuilder}/`
  moved verbatim from swift-linter (no edits to rule predicate
  logic — pure-structural per ground rule #4).
- `Tests/Linter Rule * Tests/` moved verbatim from swift-linter.
- 103 tests in 45 suites pass in isolation (`swift test` from
  swift-linter-rules root).

### REFACTORED: `swift-foundations/swift-linter`

- `Package.swift`:
  - 4 `.target(name: "Linter Rule *")` blocks removed.
  - 4 `.library(name: "Linter Rule *")` product blocks removed.
  - 4 `.testTarget(name: "Linter Rule * Tests")` blocks removed.
  - `.package(path: "../swift-linter-rules")` dependency added.
  - `Linter Core` target's rule deps re-routed:
    `"Linter Rule Unchecked"` → `.product(name: "Linter Rule Unchecked", package: "swift-linter-rules")` (same for the other three).
  - `Linter` umbrella target's rule deps re-routed identically.
- `Sources/` post-extraction: `Linter`, `Linter CLI`, `Linter Core`,
  `Linter Reporter SARIF`, `Linter Reporter Text` (5 targets — the
  consuming/composing surface; rule targets all moved out).
- `Tests/` post-extraction: `Linter Core Tests/` only (rule tests
  all moved out).

### Layer position

Both packages remain at L3-Foundations. swift-linter-rules consumes
swift-linter-primitives (L1) for the protocol surface; swift-linter
consumes both packages.

## Verification

| # | Acceptance Criterion | Verified | Evidence |
|---|---|---|---|
| 1 | R5 27-hit count preserved on swift-tagged-primitives | ✓ | `swift run --package-path . swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives 2>&1 \| grep -c "unchecked_call_site"` → **27**. |
| 2 | swift build GREEN in both packages | ✓ | swift-linter-rules: 27.70s clean, build complete. swift-linter: 45.20s, build complete. |
| 3 | swift test GREEN in both packages | ✓ | swift-linter-rules: 103 tests in 45 suites pass. swift-linter: 6 tests in 4 suites pass (Linter Core Tests; rule tests all moved). Cohort total preserved at 109. |
| 4 | No swift-linter `.target` / `.library` / `.testTarget` blocks named `Linter Rule *` remain | ✓ | `Package.swift` reading: zero matches; rule references re-routed via `.product(name:, package: "swift-linter-rules")`. |
| 5 | swift-linter-rules has 4 `.target` + 4 `.library` blocks named `Linter Rule *` | ✓ | `Package.swift` reading: confirmed. |

## Supervisor ground-rules verification

| # | Rule | Verified |
|---|------|----------|
| 1 | fact: scope = (a) create swift-linter-rules at swift-foundations layer; (b) lift 4 rule targets + tests; (c) patch swift-linter Package.swift to consume via local path; (d) preserve R5 27-hit | ✓ — observed end-to-end. |
| 2 | MUST preserve R5 27-hit count | ✓ — gate passed. |
| 3 | MUST NOT add new SwiftPM remote dependencies | ✓ — swift-linter-rules' remote deps are exactly `swift-syntax` (already present in swift-linter pre-extraction); swift-linter's remote deps unchanged (`swift-syntax`, `swift-argument-parser`). |
| 4 | MUST NOT modify rule predicate logic or test assertions | ✓ — rule files moved via plain `mv` (cross-repo); zero edits applied to source content. Pre-existing warnings about `public import SwiftOperators not used in public declarations` (in `Linter Rule Cardinal`) carry forward unchanged — out of Phase 3 scope. |
| 5 | MUST NOT initiate Phase 4 wave-1 rule encoding | ✓ — no new rules authored. The 4 lifted rules are exactly the pre-extraction R1/R3/R5 + ResultBuilder set; the 7 new rules are Phase 4's scope. |
| 6 | ask: rule tests reference private symbols from swift-linter | n/a — no triggering condition arose. Tests build cleanly against `Linter Rule *` + `SwiftParser` only; no `@testable import Linter_Core` or similar reaches into swift-linter internals. |

## Notes

- **Cross-repo `git mv`**: cross-repo move doesn't preserve git
  history natively (it's `mv` + `git add` in destination + `git rm`
  in source). The brief's "git mv" phrasing read as "move" rather
  than literal cross-repo history preservation. Rule predicate
  history remains queryable via `git log` on the original swift-linter
  repo's pre-extraction commits.
- **swift-linter test count**: 109 (Phase 2.5b post-state) → 6 (Phase 3
  post-state). The 103 missing tests live in swift-linter-rules now;
  cohort total preserved (6 + 103 = 109).
- **Pre-existing warnings**: 4 `public import * not used in public
  declarations` warnings in the rule files — pre-existing, out of
  Phase 3's pure-structural scope per ground rule #4. Future
  ecosystem-wide warning-cleanup pass can address.
- **Phase 4 entry condition**: the Wave-1 encoding dispatch
  (`HANDOFF-swift-linter-rules-wave-1-encoding.md`) lands new rule
  targets/tests inside swift-linter-rules. The package shape
  established here is the substrate.

## Pending (deferred per orchestrator)

- GitHub repo creation `swift-foundations/swift-linter-rules` —
  cohort-terminal authorization moment.
- Push wave for the cohort's accumulated commits — single bundled
  authorization at cohort terminal post-Phase-4.
