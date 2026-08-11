# Wave-1 AI-harness Rule Encoding — Phase 4 Verification

**Date**: 2026-05-07
**Phase**: 4 (`HANDOFF-swift-linter-rules-wave-1-encoding.md`)
**Outcome**: GATE PASSED — 7 wave-1 rules encoded; R5 27-hit invariant
preserved end-to-end; integration smoke test fires exactly 7
diagnostics on the wave-1 violations fixture.

---

## Setup

Phase 3 sign-off granted 2026-05-07. Pre-flight check verified:

- 4 carry-forward rule targets present in
  `swift-linter-rules/Sources/`: `Linter Rule Unchecked`,
  `Linter Rule Cardinal`, `Linter Rule RawValue`,
  `Linter Rule ResultBuilder`.
- No collision with proposed wave-1 target names (`Linter Rule Try
  Optional`, `Linter Rule Untyped Throws`, `Linter Rule Existential
  Throws`, `Linter Rule Var Named Impl`, `Linter Rule Option Named
  Flags`, `Linter Rule Compound Identifier`, `Linter Rule Tag
  Suffix`).
- R5 baseline = **27** on `swift-tagged-primitives`.

## Encoded rules

| # | Target | Type | Rule ID | Citation |
|---|---|---|---|---|
| 1 | `Linter Rule Try Optional` | `Lint.Rule.TryOptional` | `try_optional` | `feedback_prefer_typed_throws_over_try_optional` |
| 2 | `Linter Rule Untyped Throws` | `Lint.Rule.UntypedThrows` | `untyped_throws` | `[API-ERR-001]` |
| 3 | `Linter Rule Existential Throws` | `Lint.Rule.ExistentialThrows` | `existential_throws` | `feedback_no_existential_throws` |
| 4 | `Linter Rule Var Named Impl` | `Lint.Rule.VarNamedImpl` | `var_named_impl` | `feedback_no_impl_abbreviation` |
| 5 | `Linter Rule Option Named Flags` | `Lint.Rule.OptionNamedFlags` | `option_named_flags` | `feedback_options_not_flags` |
| 6 | `Linter Rule Compound Identifier` | `Lint.Rule.CompoundIdentifier` | `compound_identifier` | `[API-NAME-002]` |
| 7 | `Linter Rule Tag Suffix` | `Lint.Rule.TagSuffix` | `tag_suffix` | `feedback_no_tag_suffix` |

Each rule:
- Conforms to `Lint.Rule.Protocol` from swift-linter-primitives (L1).
- Doc-comment header cites the skill ID or feedback memory.
- Diagnostic message text begins `[<rule_id>] <citation>: …` —
  every fired diagnostic surfaces both the rule ID and the citation,
  satisfying the wave-1 educational-citation mandate without
  depending on the P5 reporter format.
- Visitor pattern via `SyntaxVisitor` walking the parsed AST.
- `internal import SwiftSyntax` — SwiftSyntax types are used inside
  the internal `Visitor` class, never in public API. Cleaner than
  the carry-forward `public import SwiftSyntax` pattern (which
  surfaces `public import not used` warnings under
  `MemberImportVisibility`).

## Tests

- swift-linter-rules: **185 tests in 87 suites pass**
  (103 carry-forward + 82 new — ≥5 positive + ≥3 negative per
  wave-1 rule).
- swift-linter: 6 tests in 4 suites pass (Linter Core Tests
  unchanged from Phase 3).

| Rule | Positive | Negative | Total |
|---|---|---|---|
| try_optional | 6 | 6 | 12 |
| untyped_throws | 6 | 6 | 12 |
| existential_throws | 6 | 5 | 11 |
| var_named_impl | 6 | 5 | 11 |
| option_named_flags | 5 | 5 | 10 |
| compound_identifier | 6 | 9 | 15 |
| tag_suffix | 6 | 5 | 11 |

## Wiring

swift-linter changes (one combined commit per `feedback_combined_commit_overlapping_partial_reverts` since umbrella, BuiltIn registry, and Package.swift product deps are all part of the same logical "register wave-1 rules" change):

- `Sources/Linter/exports.swift` — 7 new
  `@_exported public import Linter_Rule_…` lines.
- `Sources/Linter Core/Lint.Rule.BuiltIn.swift` — 7 new
  `public import Linter_Rule_…` lines + 7 entries in
  `Lint.Rule.builtIn` array (Phase 4 Wave 1 docstring update).
- `Package.swift` — 7 new `.product(name: "Linter Rule …", package:
  "swift-linter-rules")` entries in Linter Core target deps + 7 in
  Linter umbrella target deps.

## Verification

| # | Acceptance Criterion | Verified | Evidence |
|---|---|---|---|
| 1 | R5 27-hit count preserved on swift-tagged-primitives | ✓ | `swift run --package-path /Users/coen/Developer/swift-foundations/swift-linter swift-linter /Users/coen/Developer/swift-primitives/swift-tagged-primitives 2>&1 \| grep -c "unchecked_call_site"` → **27**. |
| 2 | swift build GREEN in both packages | ✓ | swift-linter-rules: build complete, all 11 targets compile. swift-linter: build complete (61.14s), `swift-linter` executable produced. |
| 3 | Each wave-1 rule has ≥5 positive + ≥3 negative tests passing | ✓ | Counts table above; all suites green (`swift test --package-path /Users/coen/Developer/swift-foundations/swift-linter-rules` → 185 tests in 87 suites pass). |
| 4 | Integration smoke fires exactly 7 on the violations fixture | ✓ | `swift run --package-path /Users/coen/Developer/swift-foundations/swift-linter swift-linter "/Users/coen/Developer/swift-foundations/swift-linter-rules/Tests/Fixtures/wave-1-violations.swift" 2>&1 \| grep -c "warning: "` → **7**. One diagnostic per wave-1 rule, zero carry-forward fires on the fixture. |
| 5 | Each rule body cites its skill ID / memory verbatim | ✓ | Doc-comment headers grep-verified per rule (citation strings present in each `Sources/Linter Rule */Lint.Rule.*.swift`). |
| 6 | Each diagnostic message includes the citation | ✓ | Each rule's `static let message` constant begins `"[<rule_id>] <citation>: ..."`; integration smoke output shows the citation in every emitted diagnostic. |

## Supervisor ground-rules verification

| # | Rule | Verified |
|---|------|----------|
| 1 | fact: scope = encode 7 new rules inside swift-linter-rules; each conforms to existing L1 Linter Rule protocol; each cites skill/memory in body AND diagnostic; no L1 protocol change; no reporter/autofix work; no Tier 1/Tier 2 activation; no fixing of existing violations | ✓ — observed end-to-end. |
| 2 | MUST preserve R5's 27-hit count on swift-tagged-primitives | ✓ — final run = 27. |
| 3 | MUST NOT modify the Linter Rule protocol in swift-linter-primitives | ✓ — `git diff swift-primitives/swift-linter-primitives` since Phase 3 = empty (the L1 package was untouched in this dispatch). |
| 4 | MUST NOT auto-enable the new rules in either canonical Lint.swift | ✓ — `swift-institute/.github/Lint.swift` and `swift-primitives/.github/Lint.swift` untouched. The new rules are registered in `Lint.Rule.builtIn` (which is the metatype catalog, not an activation list); activation is per-consumer Lint.swift opt-in. swift-tagged-primitives's Lint.swift `enabledRuleIDs` list does not include any wave-1 rule ID, confirmed by R5-only 27-hit run output (zero wave-1 IDs appeared). |
| 5 | MUST NOT introduce new SwiftPM remote dependencies | ✓ — swift-linter-rules' remote deps remain exactly `swift-syntax`. swift-linter's remote deps remain unchanged. |
| 6 | ask: if a rule's predicate cannot be expressed without type information, STOP and escalate | n/a — no triggering condition arose. All 7 rules implemented as pure-syntactic predicates per the brief. |

## Implementation notes

- **Type naming convention**: Wave-1 rule types use flat
  PascalCase names (`Lint.Rule.TryOptional`, `Lint.Rule.UntypedThrows`,
  etc.), mirroring the existing `Lint.Rule.ResultBuilderForLoop`
  precedent. The brief's per-rule encoding spec template uses flat
  `{RuleName}` placeholder; supervisor expectation matches. The
  strict /code-surface user directive applied to Manifest domain
  extraction (Phase 3a) does not retroactively rebrand the existing
  rule-type naming.
- **Diagnostic message format**: `"[\(Self.id)] <citation>: …"` —
  every diagnostic carries the rule ID and the citation in its
  message text, separable from the reporter's prepended
  `<file>:<line>:<col>: warning: <id>:` envelope. AI agents reading
  text-format output get both the rule identity AND the skill
  citation regardless of reporter format choice.
- **rethrows discriminator**: `Lint.Rule.UntypedThrows` initial
  encoding flagged `rethrows` clauses too (since SwiftSyntax models
  `rethrows` as a `ThrowsClauseSyntax` with a different specifier
  token). Fixed during isolation testing by guarding on
  `throwsSpecifier.tokenKind == .keyword(.throws)`. The
  `rethrows`-is-not-flagged invariant is captured by a regression
  test in the rule's edge-case suite.
- **Compound-identifier scope**: The rule visits
  `FunctionDeclSyntax` and `VariableDeclSyntax` only. Function
  parameter labels are exempt (signature ergonomics often require
  `at`/`with` style). Type names (`StructDeclSyntax`,
  `EnumDeclSyntax`, etc.) are exempt — type-name compound is
  governed by [API-NAME-001] which has spec-mirroring exceptions
  that need type info to disambiguate; the rule targets the
  lower-risk method/property compound case.
- **Phantom-tag heuristic**: `Lint.Rule.TagSuffix` distinguishes
  phantom-type markers (zero stored properties / zero enum cases)
  from legitimate `*Tag` types (e.g., `XMLTag` with attributes,
  `HTMLTag` enum with cases). The heuristic is conservative — false
  negatives (a phantom marker with one accidental computed property
  is flagged; a legitimate `*Tag` with stored fields is not) are
  preferred to false positives.

## Pending (deferred per orchestrator)

- GitHub repo creation `swift-foundations/swift-linter-rules` —
  cohort-terminal authorization moment.
- Bundled push wave for the cohort's accumulated commits — single
  per-action authorization at cohort terminal.
- Wave-2 / Wave-3 rule encoding (rules requiring lightweight type
  info or full semantic analysis) — separate dispatch per the
  strategic-mission handoff.
- Tier 1 / Tier 2 activation of wave-1 rules — separate per-tier
  authorization moment per
  `feedback_no_public_or_tag_without_explicit_yes`.
- AI-targeted reporter format (P5) — separate dispatch.
- Autofix infrastructure (P6) — separate dispatch starting with
  highest-confidence rules.
