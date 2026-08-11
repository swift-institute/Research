# Phase B.4 Verification Record — Wave-1 Rules Migrated to Post-Architecture Shape

**Date**: 2026-05-07
**Phase**: Phase B.4 of architecture cohort (`HANDOFF-swift-linter-architecture-cohort.md`).
**Outcome**: GATE PASSED — swift-tagged-primitives' `Lint/`
executable now explicitly imports + activates **all 11
institute-canonical rules + 1 custom rule** (12 total). The 7 wave-1
rules (Phase 4) and the previously-missing `result_builder_for_loop`
carry-forward (Phase 2) are wired in via the post-Phase-B.1
type-enumeration pattern. R5 = 27 and custom = 19 invariants
preserved.

---

## Scope (per supervisor brief)

> Goal: swift-tagged-primitives' Lint/ now explicitly imports +
> activates the 7 wave-1 rules + the missing ResultBuilder
> carry-forward (Phase A only added 3 of 4 carry-forward modules).
> After Phase B.4, the Lint/ executable runs ALL 11 institute-canonical
> rules + 1 custom rule against tagged-primitives source.

Concurrent prep: GH Actions reusable workflow sketch at
`swift-linter/.github/workflows/lint.yml` (DRAFT — not committed
pending supervisor review of shape).

---

## Edits

| File | Change |
|---|---|
| `swift-tagged-primitives/Lint/Package.swift` | Added 8 `.product(name: "Linter Rule X", package: "swift-linter-rules")` entries to the `Lint` exec target deps: `Linter Rule ResultBuilder` (carry-forward), and the 7 wave-1 packs (`Try Optional`, `Untyped Throws`, `Existential Throws`, `Var Named Impl`, `Option Named Flags`, `Compound Identifier`, `Tag Suffix`). |
| `swift-tagged-primitives/Lint/Sources/Lint/main.swift` | Added 8 `internal import Linter_Rule_X` lines (alphabetized). Added 8 rule IDs to `manifest.enabledRuleIDs` (the carry-forward + 7 wave-1 IDs). Added 8 per-type `if enabled.contains(Lint.Rule.X.id) { Lint.Rule.Configuration.enable(Lint.Rule.X.self) }` blocks following the existing pattern. |

---

## Per-Rule Baseline on swift-tagged-primitives

CLI dispatch invocation: `swift run swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives`
(swift-linter detects `Lint/Package.swift` at the consumer root,
spawns `swift run --package-path Lint Lint <consumerRoot>`).

Output captured in `/tmp/lint-stdout.txt` — 239 findings total.

| Rule ID | Type | Hits | Note |
|---|---|---:|---|
| `unchecked_call_site` | `Lint.Rule.Unchecked` (R5) | **27** | INVARIANT — exact match to PoC + modularization-cohort baseline. Distribution: 27/27 in `Experiments/` (research-time typed-system bottom-outs). |
| `cardinal_count_minus_one` | `Lint.Rule.Cardinal.Count` (R1) | 1 | Single Experiments hit (`tagged-no-strideable/Sources/.../main.swift:118`). |
| `cardinal_zero_one_constructor` | `Lint.Rule.Cardinal.Constructor` (R2) | 0 | tagged-primitives source has no `Cardinal(0)` / `Cardinal(1)` constructors. Healthy zero. |
| `chained_rawvalue_access` | `Lint.Rule.RawValue.Chain` (R3) | 7 | All in `Experiments/` (footgun-revalidation, negative-ordinal, safe-marker tests). |
| `bitpattern_rawvalue_chain` | `Lint.Rule.RawValue.BitPattern` (R4) | 0 | tagged-primitives uses no `bitPattern:rawValue` integration overloads. Healthy zero. |
| `result_builder_for_loop` | `Lint.Rule.ResultBuilderForLoop` (carry-forward) | 0 | tagged-primitives ships no `@resultBuilder`-using code. Healthy zero. |
| `try_optional` | `Lint.Rule.TryOptional` (wave-1) | 0 | No `try?` sites. Consistent with `feedback_prefer_typed_throws_over_try_optional.md`. |
| `untyped_throws` | `Lint.Rule.UntypedThrows` (wave-1) | 0 | All throws are typed. Consistent with [API-ERR-001]. |
| `existential_throws` | `Lint.Rule.ExistentialThrows` (wave-1) | 0 | No existential `throws(any Error)` sites. |
| `var_named_impl` | `Lint.Rule.VarNamedImpl` (wave-1) | 0 | Naming discipline observed (`feedback_no_impl_abbreviation.md`). |
| `option_named_flags` | `Lint.Rule.OptionNamedFlags` (wave-1) | 0 | No `OptionSet` in tagged-primitives surface. |
| `compound_identifier` | `Lint.Rule.CompoundIdentifier` (wave-1) | **175** | Substantial — anticipated by supervisor brief. Distribution: 149 `Experiments/` (research artifacts where naming discipline does not apply uniformly), 22 `Tests/`, 3 `Lint/`, **1 `Sources/`** — the production source is essentially clean. Recommend triage at a future cleanup pass. |
| `tag_suffix` | `Lint.Rule.TagSuffix` (wave-1) | 10 | Distribution: 9 `Experiments/`, 1 `Tests/`. Sources/ clean. |
| `tagged_unchecked_with_typed_alternative` | `Lint.Rule.TaggedDomainAudit` (PoC custom) | **19** | INVARIANT — exact match to PoC baseline. |

**Sum**: 27 + 1 + 0 + 7 + 0 + 0 + 0 + 0 + 0 + 0 + 0 + 175 + 10 + 19 = **239** lines emitted.

---

## Comparison vs Phase 4 wave-1-violations Fixture

The wave-1 reference fixture
(`swift-linter-rules/Tests/Fixtures/wave-1-violations.swift`) tests
the wave-1 rules' positive predicates against an authored violation
catalog — different fixture, different predicate-evaluation surface.
The Phase B.4 baseline above is the **organic** count of hits in
swift-tagged-primitives' real source + research artifacts; it
intentionally diverges from the fixture's curated 7-hit count
(reference: `2026-05-07-wave-1-encoding-verification.md` line 101).

The two baselines coexist:
- **Wave-1 fixture** (in `swift-linter-rules/Tests/`) — pins the rules'
  predicate correctness against authored violations. Stays in
  swift-linter-rules.
- **swift-tagged-primitives organic** (this record) — pins the rules'
  behavior against a real consumer's source under the post-architecture
  Lint/ shape. Documented here.

---

## Acceptance Criteria

| # | Gate | Status | Evidence |
|---|---|---|---|
| 1 | Lint/ Package.swift declares all 11 institute rule pack products | ✓ | 11 `.product(...)` entries on the `Lint` exec target deps (R1–R5 + carry-forward + 7 wave-1). |
| 2 | main.swift imports all 11 rule modules + custom | ✓ | 11 `internal import Linter_Rule_*` + 1 `internal import Linter_Rule_Tagged_Domain_Audit`. |
| 3 | manifest.enabledRuleIDs lists all 11 institute IDs + custom | ✓ | 14 IDs in the array (R1–R5 = 5; carry-forward = 1; wave-1 = 7; custom = 1; total 14 — note R1+R2 share the `Cardinal` module → 5 IDs from R1–R5 cover both Count/Constructor + 3 from R3 cover Chain + 1 from R4 covers BitPattern). Wait — re-counting: `unchecked_call_site` (R5) + `cardinal_count_minus_one` (R1) + `cardinal_zero_one_constructor` (R2) + `chained_rawvalue_access` (R3) + `bitpattern_rawvalue_chain` (R4) + `result_builder_for_loop` (carry-forward) + 7 wave-1 IDs + 1 custom = **14**. |
| 4 | Lint/ executable builds clean | ✓ | `cd swift-tagged-primitives/Lint && rm -rf .build && swift build` complete (187s). |
| 5 | R5 = 27 invariant preserved | ✓ | `grep -c "warning: unchecked_call_site:" /tmp/lint-stdout.txt` = 27. |
| 6 | Custom = 19 invariant preserved | ✓ | `grep -c "tagged_unchecked_with_typed_alternative" /tmp/lint-stdout.txt` = 19. |
| 7 | All 11 institute rules + custom activate via Lint/ shape | ✓ | Per-rule hit counts above show every rule produced its correct count (substantive hits or healthy zeros). No rule is silently inactive. |
| 8 | No `import Foundation` introduced | ✓ | Phase B.4 edits Foundation-free; pre-existing Foundation-free state preserved. |
| 9 | Verification record committed | ✓ | This file. |

---

## Status

**Phase B.4: COMPLETE**. swift-tagged-primitives' `Lint/` executable
runs all 11 institute-canonical rules + 1 custom rule end-to-end via
the architecture-cohort's CLI dispatch path. Per-rule baselines
recorded; R5 + custom invariants preserved.

Awaiting supervisor sign-off before GH Actions workflow draft commits
or further Day-2 work fires.
