# Phase B.1 Verification Record — Decouple swift-linter from swift-linter-rules

**Date**: 2026-05-07
**Phase**: Phase B.1 of architecture cohort (`HANDOFF-swift-linter-architecture-cohort.md`).
**Outcome**: GATE PASSED — swift-linter no longer depends on
swift-linter-rules. The engine ships zero built-in rules; rule
registration is the consumer's responsibility (handled by the
consumer's `Lint/Sources/Lint/main.swift` for the nested-package
shape). End-to-end behavior preserved via CLI dispatch:
`swift run swift-linter <consumerRoot>` against
swift-tagged-primitives produces R5 = 27 hits and custom rule = 19
hits, matching the Phase A PoC baseline (`2026-05-07-poc-lint-nested-package.md`).

---

## Scope (per supervisor brief)

> PHASE B.1 — DECOUPLE swift-linter FROM swift-linter-rules
>
> 1. swift-foundations/swift-linter/Package.swift: drop swift-linter-rules
>    dep + product references in the Linter target's deps.
> 2. swift-foundations/swift-linter/Sources/Linter/exports.swift (umbrella):
>    drop @_exported imports of rule modules; keep engine module re-exports.
> 3. Update any swift-linter test that referenced rule modules via the umbrella.
> 4. Manifest.NestedPackage's existing single-file Lint.swift fallback
>    already delegates to a default rule set — verify that path still
>    works after decoupling (the default fallback might need an explicit
>    "default rule pack import" mechanism).

Round-the-clock pace per supervisor: don't pause between revert + B.1
once revert is verified clean.

---

## Edits

### swift-linter (engine — what it loses)

| File | Change |
|---|---|
| `Package.swift` | Removed `.package(path: "../swift-linter-rules")` from `dependencies`. Removed 11 `.product(name: "Linter Rule X", package: "swift-linter-rules")` entries from `Linter Core` target deps. Removed the same 11 entries from the `Linter` umbrella target deps. |
| `Sources/Linter/exports.swift` | Removed 11 `@_exported public import Linter_Rule_X` lines. Engine re-exports remain: `Linter_Core`, `Linter_Reporter_Text`, `Linter_Reporter_SARIF`. |
| `Sources/Linter Core/Lint.Rule.BuiltIn.swift` | **Deleted**. The `Lint.Rule.builtIn` static array (13 institute-canonical rule instances) and its 11 `public import Linter_Rule_X` lines no longer make sense in the engine. |
| `Sources/Linter Core/Lint.Driver.swift` | `defaultConfiguration()` returns `Lint.Configuration(rules: { })` (empty-rules) instead of iterating `Lint.Rule.builtIn`. `configuration(from:parent:)` no longer maps manifest `enabledRuleIDs` / `disabledRuleIDs` to rule TYPES; it threads `inheriting: parent` and `excluded: manifest.excludedPaths` only. Doc comments updated to document the post-decouple semantics. |
| `Tests/Linter Core Tests/Lint.Driver Tests.swift` | Two existing tests assumed engine-side rule registration:<br>• `Single enabled rule produces one effective entry` — assumed `"unchecked_call_site"` would resolve to `Lint.Rule.Unchecked.self` via `builtIn`. Rewritten to `Manifest enabledRuleIDs are silently ignored at engine layer` — asserts `effectiveRules().isEmpty` even with a populated enabledRuleIDs list.<br>• `Child empty enabled inherits parent's enabled set` — assumed parent's `["unchecked_call_site", "cardinal_count_minus_one"]` would resolve to two effective rules. Rewritten to `Child Configuration inherits from parent reference` — asserts the inheritance link is intact (Configuration-layer test responsibility) while both layers are empty post-decouple.<br>• Added `Manifest disabledRuleIDs are silently ignored at engine layer` for symmetry.<br>• Existing tests preserved: `Empty manifest with nil parent…`, `Excluded paths are carried through to Configuration`, `Unknown rule ID is silently ignored`. |

### swift-tagged-primitives (consumer — what it gains)

| File | Change |
|---|---|
| `Lint/Package.swift` | Added `.package(path: "../../../swift-foundations/swift-linter-rules")` to `dependencies`. Added 3 `.product(name: "Linter Rule X", package: "swift-linter-rules")` entries to the `Lint` executable target deps: `Linter Rule Unchecked`, `Linter Rule Cardinal`, `Linter Rule RawValue` (covers R1–R5). Narrow-product import discipline per `feedback_no_umbrella_imports.md`: only the rule packs the manifest's `enabledRuleIDs` actually references are linked. |
| `Lint/Sources/Lint/main.swift` | Added 3 `internal import Linter_Rule_X` lines (Cardinal, RawValue, Unchecked). Replaced the loop `for rule in Lint.Rule.builtIn where enabled.contains(type(of: rule).id) { … }` with explicit per-type `if enabled.contains(Lint.Rule.X.id) { Lint.Rule.Configuration.enable(Lint.Rule.X.self) }` blocks for the 5 institute rule TYPES (R1: `Cardinal.Count`, R2: `Cardinal.Constructor`, R3: `RawValue.Chain`, R4: `RawValue.BitPattern`, R5: `Unchecked`) plus the existing custom-rule activation for `Lint.Rule.TaggedDomainAudit`. |

---

## Acceptance Criteria

| # | Gate | Status | Evidence |
|---|---|---|---|
| 1 | swift-linter builds standalone | ✓ | `cd swift-foundations/swift-linter && rm -rf .build && swift build` complete (234s); no `swift-linter-rules` resolution. Only pre-existing unused-public-import warnings (orthogonal). |
| 2 | swift-linter tests pass | ✓ | `swift test` → 6/6 in 4 suites pass (the two rewritten tests + symmetric disable test + 3 preserved tests). |
| 3 | swift-linter has zero `import Linter_Rule_*` in `Sources/` | ✓ | `grep -rn "import Linter_Rule_" Sources/` returns empty. |
| 4 | swift-tagged-primitives' `Lint/` executable links engine + swift-linter-rules + custom rule | ✓ | `cd swift-tagged-primitives/Lint && rm -rf .build && swift build` complete (308s). All 3 institute rule packs (Unchecked, Cardinal, RawValue) declared on the `Lint` executable target; custom rule (`Linter Rule Tagged Domain Audit`) declared as an in-package target. |
| 5 | tagged-primitives `Lint/` tests pass | ✓ | `cd swift-tagged-primitives/Lint && swift test` → 11/11 in 6 suites pass (5 positive + 6 negative cases for the custom rule). |
| 6 | R5 27-hit invariant preserved | ✓ | `cd swift-foundations/swift-linter && swift run swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives` (CLI dispatch path) → `grep -c "warning: unchecked_call_site:" /tmp/lint-stdout.txt` = **27** (exact match to PoC baseline & modularization cohort's 27 → 27 → 27 → 27 → 27 chain). |
| 7 | Custom rule still fires 19 times | ✓ | Same invocation → `grep -c "tagged_unchecked_with_typed_alternative" /tmp/lint-stdout.txt` = **19** (exact match to PoC baseline). |
| 8 | Other Tier 2 rules still fire | ✓ | R1 (`cardinal_count_minus_one`) = 1 hit, R3 (`chained_rawvalue_access`) = 7 hits; total 54 findings. R2 / R4 = 0 hits (no `Cardinal(0)` / `Cardinal(1)` constructors or `bitPattern:rawValue` chains in tagged-primitives source — consistent with PoC). |
| 9 | Single-file `Lint.swift` fallback path documented | ✓ | `Lint.Driver.swift` doc comment now explicitly states: post-Phase-B.1 the engine ships no rules; the fallback path is inert (zero findings) until a consumer-side rule registration mechanism lands; consumers SHOULD adopt the `Lint/Package.swift` shape per `Manifest.NestedPackage`. |
| 10 | swift-manifests still works | ✓ | `cd swift-foundations/swift-manifests && swift test` → 5/5 in 5 suites pass, including the 3 `Manifest.NestedPackage` tests from Phase A. |
| 11 | No `import Foundation` introduced | ✓ | All Phase B.1 edits verified Foundation-free. |
| 12 | Verification record committed | ✓ | This file. |

---

## Behavior Change Documented

The single-file `Lint.swift` fallback path (the legacy detection-only
flow before Phase A's `Lint/` nested package shape) is now functionally
inert post-Phase-B.1. Its semantics:

| Pre-Phase-B.1 | Post-Phase-B.1 |
|---|---|
| `defaultConfiguration()` enabled every rule in `Lint.Rule.builtIn` (13 rules) at default severity. | `defaultConfiguration()` enables nothing. The run produces zero findings. |
| `configuration(from:parent:)` resolved manifest `enabledRuleIDs` against `Lint.Rule.builtIn`. Known IDs activated their rule TYPE; unknown IDs silently ignored. | `configuration(from:parent:)` ignores manifest rule IDs entirely (engine has no catalog). Inheritance and excluded paths are still threaded. |
| Single-file `Lint.swift` consumers got Tier 2 enforcement automatically. | Single-file `Lint.swift` consumers get nothing at the engine layer. Migration path: adopt the `Lint/Package.swift` shape (architecture cohort Phase B.4 broadens this to Tier 1 / Tier 2 canonicals). |

This matches the architectural endpoint per supervisor's Option-1
refinement (PoC verification record, Constraint Refinement section):
swift-linter (CLI) is a coordinator; the consumer's `Lint/` executable
IS the linter binary for that consumer. The CLI's single-file fallback
remains as a structural placeholder so existing chain-resolution
machinery (`Manifest.Resolver.resolve(...)`) is not disturbed; whether
the fallback is restored to producing findings (e.g., via a
plugin-registration mechanism in a later phase) is a design question
deferred past Phase B.1's scope.

---

## Out of Scope (deferred per supervisor pace)

- Phase B.4 broadens the `Lint/Package.swift` shape to Tier 1
  (`swift-institute/.github/`) and Tier 2 (`<org>/.github/`) canonicals
  — that's the ecosystem-wide adoption phase.
- Phase B.2 (engine-side plugin-registration mechanism for restoring
  single-file fallback findings) is DEFERRED past the cohort's 3-day
  deadline per supervisor.
- Phase B.3 (parent-chain resolution from dispatched executables —
  evolving `// parent:` directive walking to `git-archive` of `Lint/`
  subdirs) is partially in scope for Day 3 cleanup; not addressed here.

---

## Status

**Phase B.1: COMPLETE**. swift-linter builds and tests independently
of swift-linter-rules; tagged-primitives' `Lint/` executable picks up
the rule packs directly; PoC baselines (R5=27, custom=19) preserved.
Awaiting supervisor sign-off before Phase B.4 brief authoring/firing.
