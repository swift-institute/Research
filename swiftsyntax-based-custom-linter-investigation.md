# SwiftSyntax-Based Custom Linter Investigation

<!--
---
version: 1.0.0
last_updated: 2026-05-06
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-primitives]
normative: false
---
-->

## Context

### Trigger

Over the R1–R4 cardinal/ordinal/vector enforcement cohort cleanup
(`cardinal-ordinal-vector-enforcement-design.md` v1.0.0), waves
1 + 2a + 2b + 2a-rerun across 50 sites in 21 packages, the regex-based
SwiftLint custom rules in the Tier 2 canonical
(`swift-primitives/.github/.swiftlint.yml`) demonstrated **five
structural evasion vectors** that pure regex cannot catch without
high false-positive risk:

| # | Class | Example | Status |
|---|---|---|---|
| 1 | Paren-wrap | `(x.rawValue).foo()` for `x.rawValue.foo()` | Caught by companion regex `\.rawValue\s*\)\.\w+` (Tier 2 commit `7622a8b`) |
| 2 | Typename-swap | `self.init(bitPattern: …)` for `Int(bitPattern: …)` | Caught by broadened R4 regex `\b\w+\(bitPattern:` (`7622a8b`) |
| 3 | Cast-outside | `(Double(count) - 1)` for `Double(count - 1)` | Caught by companion regex `\bcount\s*\)\s*-\s*1\b` (`c252a39`) |
| 4 | Algebraic-flip | `i + 1 < count` for `i < count - 1` | Caught by companion regex `\+\s*1\s*[<=]+\s*(?:\w+\.)*count\b` (`c252a39`) |
| 5 | **Operand-reorder** | `(count - i - 1)` for `(count - 1 - i)` | **NOT caught** — pattern class too broad for clean regex; supervisor diff-review is the current gate |
| (6) | Comments-as-code | `count - 1` literal in `// reason:` prose retriggers the rule | Workaround only: Unicode minus `−` discipline; not a structural fix |

Beyond evasion, two rule classes were DEFERRED entirely from the
regex cohort because they are inherently AST-shaped (per
`cardinal-ordinal-vector-enforcement-design.md` §"Rule-by-rule
design", rules R5 + R0):

- **R5** — `__unchecked:` at call-sites only (NOT at parameter
  declaration sites). 41 files contain mixed legitimate
  declaration-site uses + anti-pattern call-site uses; the regex
  `__unchecked:` matches both. Distinguishing requires
  call-site-vs-declaration-site context that NSRegularExpression
  cannot supply.
- **R0** — positive enforcement of the [CONV-016] preference
  hierarchy ("this site should use `.retag()` here"). Requires
  conversion-tier classification on the AST: which sites are
  conversions, what tier their current implementation occupies,
  whether a higher tier is achievable.

Two further AST-shaped rules from adjacent skills surfaced as
deferred during Phase 1 of the centralized linter rollout
(`rollout-phase-1-results.md` v1.1.0):

- **[API-IMPL-005] one_declaration_per_file with per-path scoping**
  — SwiftLint's built-in `one_declaration_per_file` does NOT support
  per-rule path scoping (only `severity:` is configurable). The
  [TEST-005] @Suite category pattern (multiple top-level
  `private enum TagN {}` fixtures alongside the @Suite struct in
  swift-tagged-primitives' Tests/) triggers 14 violations that are
  legitimate test infrastructure. The rule was dropped from Phase 1
  pending one of: (a) tests refactored to nest fixtures, (b) CI
  restructured for separate Sources/Tests invocations, (c) a
  sub-config fanout, OR (d) AST-aware enforcement that respects
  context.
- **[TEST-025] test_support_module_in_tests with file-context
  awareness** — SwiftLint's regex-based rule fires on `import
  *_Test_Support` but cannot distinguish "in a test file with
  literal index/offset/count usage" (legitimate, MUST import) from
  "in a test file with no such usage" (smell). Same class of gap
  as [API-IMPL-005].

### Investment hypothesis

A SwiftSyntax-based linter would:

1. Eliminate the entire regex-evasion class permanently. Semantic
   matching on AST nodes does not vary with surface text; the five
   classes above all collapse to single AST predicates.
2. Unblock **R5** — call-vs-decl distinction is a structural
   property the syntax tree exposes directly
   (`FunctionParameterSyntax` for declarations vs
   `LabeledExprSyntax` for arguments).
3. Unblock **R0** — positive enforcement via conversion-tier
   classification on the AST (recognize a conversion site, classify
   its current tier, check whether a higher tier is achievable).
4. Unblock the broader deferred-AST-rule cohort in
   `mechanical-rule-tool-classification-swift-primitives.md`: ~30
   "complex multi-decl AST shape" rules ([INFRA-200]
   operations-intentionally-missing, [CONV-003/004/005/006]
   API-table multi-pattern, [PKG-NAME-002/006] namespace+protocol+
   typealias triplet, [MEM-OWN-012] action-enum dispatch,
   [MEM-REF-002…005] reference-primitive site enforcement,
   [MEM-LIFE-002…007] lifetime-primitive site enforcement) plus
   per-path scoping for [API-IMPL-005] and file-context for
   [TEST-025].

### Prior research consulted ([RES-019] internal grep complete)

| Doc | Status | Relevance |
|---|---|---|
| `ai-context-reduction-via-type-system-tooling.md` | RECOMMENDATION (2026-04-01) | Option D Symbol-graph pipeline is the prior architectural recommendation. **Phase 1 executed 2026-03-15** (extraction + distillation: 9.8 MB JSON, 435 modules, 13,262 symbols, 19,022 relationships in `swift-primitives/.build/public-api-graph.json`; scripts at `swift-primitives/Scripts/{extract,distill,analyze}-symbol-graphs.*`). Phases 2–4 (Option A root Package.swift, Option C hybrid CCLSP, Option D meta-analysis scripts) NOT yet executed. |
| `primitives-public-api-graph-analysis.md` | RECOMMENDATION (2026-04-13) | Phase 1 results doc. Confirms symbol graph captures cross-module relationships via `@Module.symbols.json`. Confirms the JSON catalog is analyzable by scripts. |
| `cardinal-ordinal-vector-enforcement-design.md` | RECOMMENDATION (2026-05-05) | The cohort design baseline. Defers R5 and R0 to "SwiftSyntax-based tooling Phase per ai-context-reduction-via-type-system-tooling.md Option D Symbol-graph pipeline." |
| `mechanical-rule-tool-classification-swift-primitives.md` | RECOMMENDATION (2026-05-05) | Classifies 195 mechanical rules into 4 enforcement-tool buckets. Explicit finding: "**No 5th-bucket candidates surfaced**: no rule resisted all four buckets such that a `swiftsyntax-tool` (custom AST tool beyond SwiftLint) would be required." This investigation revisits that finding in light of empirical evasion data accumulated 2026-05-05 → 2026-05-06. |
| `rollout-phase-1-results.md` | RECOMMENDATION v1.1.0 (2026-05-05) | Surfaces SwiftLint's `one_declaration_per_file` per-rule-path-scoping limitation; documents the v1.1.0 drop of [API-IMPL-005] from Phase 1 with three workaround options (b/c) operationally awkward and (a) requires source refactor. AST tooling is option (d) — implicit but not in the listed remediations. |
| `developer-tool-package-architecture.md` | DECISION Tier 3 (2026-04-13) | Establishes the precedent: developer tools live as standalone Swift packages in `Developer/` (Option C now), with future promotion to a `swift-tools/` superrepo (Option D) when more tools emerge. Provides the architectural home for the proposed linter. |
| `enum-infrastructure-primitives.md` | (referenced; not re-read) | Establishes precedent for L3 SwiftSyntax-dependent codegen libraries (the `swift-enum-infrastructure-codegen` shared library consumed by swift-dual / swift-defunctionalize / swift-witnesses macros). |

### Parent supervisor context

The parent supervisor chat orchestrates the R1–R4 enforcement-cohort
cleanup waves and Tier 2 SwiftLint hardening. The cleanup waves and
Tier 2 hardening commits (`7622a8b`, `c252a39`) are landed; the
SwiftSyntax-linter pivot is being explored as the structural answer
to the recurring regex-evasion failure modes documented in this
research's §Trigger.

---

## Question

**Primary**: What architectural option delivers AST-based / semantic-
shape enforcement for the swift-primitives ecosystem with the lowest
total cost (initial + ongoing) and the highest evasion-class +
deferred-rule coverage, given the prior `parent_config:` Tier 1 / 2 /
3 SwiftLint chain that this enforcement must compose with?

### Sub-questions

The investigation answers six sub-questions enumerated by the
dispatch brief:

1. **What architectural options exist** for replacing regex-based
   SwiftLint custom rules with AST-based / semantic-shape-based
   enforcement? Enumerate at least 6.
2. **What evasion classes does each option close?** Map each option
   against the six demonstrated/deferred classes (paren-wrap,
   typename-swap, cast-outside, algebraic-flip, operand-reorder,
   comments-as-code).
3. **What deferred AST-shaped rules does each option unblock?**
   At minimum: R5, R0, [API-IMPL-005] per-path scoping, [TEST-025]
   file-context.
4. **What is the integration story?** How does each option compose
   with the existing 3-tier `parent_config:` SwiftLint chain
   (`rollout-phase-1-results.md`)? Does it replace SwiftLint
   entirely, run alongside, or augment specific rules?
5. **What is the development cost / payback?** Per [RES-022]
   theoretical grounding + [RES-025] empirical validation.
6. **What is the recommended path forward?** Single recommendation
   with phasing, prior-art survey per [RES-021].

---

## Analysis

### Empirical baseline (verified 2026-05-06)

The R1–R4 Tier 2 cohort (`cardinal-ordinal-vector-enforcement-
design.md`) currently deploys **9 custom rules** in
`swift-primitives/.github/.swiftlint.yml` (Tier 2 canonical):

| Rule | Pattern | Class | Evasion-companion |
|---|---|---|---|
| `no_foundation_import_error` | `import Foundation\b` (with attribute permutations) | gating ERROR (Sources/ + Tests/Support/) | none needed (~80% closed-form) |
| `no_foundation_import_warning` | same pattern | advisory WARNING (Tests/) | none needed |
| `l1_no_platform_conditionals` | `#(?:if\|elseif)\s+(?:!\s*)?(?:os\|canImport)\s*\(` | gating ERROR (Sources/) | none needed |
| `cardinal_count_minus_one_anti_pattern` | `\bcount\s*-\s*1\b` | warning | yes — `_evasion` companion catches cast-outside + algebraic-flip |
| `cardinal_count_minus_one_evasion` | `\bcount\s*\)\s*-\s*1\b\|\+\s*1\s*[<=]+\s*(?:\w+\.)*count\b` | warning | (the companion) |
| `cardinal_zero_one_constructor_anti_pattern` | `\bCardinal\(\s*[01]\s*\)` | warning | none needed |
| `chained_rawvalue_access_anti_pattern` | `\.rawValue\.\w+` | warning | yes — `_paren_evasion` companion catches paren-wrap |
| `chained_rawvalue_access_paren_evasion` | `\.rawValue\s*\)\.\w+` | warning | (the companion) |
| `bitpattern_rawvalue_chain_anti_pattern` | `\b\w+\(bitPattern:\s*[^)]*\.rawValue` | warning | embedded — broadened `\b\w+\(` catches typename-swap |

The hardening journey is observable in commit history:

- Original cohort (`cardinal-ordinal-vector-enforcement-design.md`
  v1.0.0): 4 base regex rules.
- Tier 2 commit `7622a8b` (~2026-05-05): paren-wrap evasion
  companion added; R4 broadened `Int\(...` → `\b\w+\(...` to catch
  typename-swap.
- Tier 2 commit `c252a39` (~2026-05-05): cast-outside +
  algebraic-flip evasion companion added.
- Operand-reorder NOT caught by any landed regex; supervisor
  diff-review is the current human-in-the-loop gate.

The pattern is regression-by-evasion: each new evasion class adds a
companion regex; companion regexes accumulate; each new companion
adds catalog noise without removing the underlying fragility (a
regex catches its specific surface, never the semantic
relationship). The fifth class (operand-reorder) defeats the
pattern entirely — no clean-regex companion exists, only a
permissive one with unacceptable false-positive risk on legitimate
n-ary subtraction.

### The regex/AST gap as theoretical grounding [RES-022]

The five demonstrated evasion classes (and the operand-reorder
that defies regex altogether) are not isolated bugs in specific
rules — they are operational-semantics consequences of a single
structural fact:

> A regex matches surface text; an AST rule matches grammar.

Formally, given a Swift source file `S`, the SwiftLint regex-rule
predicate `R(S)` is a function over the lexical sequence of
characters in `S`. The legitimate-vs-anti-pattern distinction the
rule encodes is a function over the **parsed grammar** `parse(S)` —
specifically, over a structural property `P` of nodes in
`parse(S)`. The relationship between `R` and `P` is approximate:

```
R(S) ≈ ∃ subsequence of S that "looks like" P-shaped node
```

Approximately because surface text under-determines structure:

- `(x.rawValue).foo()` and `x.rawValue.foo()` parse to the same
  `MemberAccessExprSyntax` subtree (with `TupleExprSyntax` wrapping
  the base in the first); `R(S) = .rawValue\.\w+` matches only the
  second.
- `Int(bitPattern: x)` and `self.init(bitPattern: x)` parse to
  semantically distinct `FunctionCallExprSyntax` nodes (the first
  with `DeclReferenceExprSyntax(Int)`, the second with
  `MemberAccessExprSyntax(self, init)`); `R(S) = Int\(bitPattern:`
  matches only the first.
- `count - 1` in source vs `count - 1` in a `// comment` parse
  differently (the second is a `Trivia` comment, not part of the
  expression grammar at all); `R(S)` matches both. SwiftLint's
  `match_kinds:` partially mitigates by exposing token kinds, but
  the "kind" is per-token, not per-grammatical-context.
- `count - 1` and `count - i - 1` and `count - 1 - i` are three
  distinct ASTs with the same semantic intent (compute `count -
  1 - i`); a regex that catches the first either misses the
  second-and-third or false-positives across legitimate n-ary
  subtraction.

The five evasion classes correspond exactly to the gap between
surface form and grammar:

| Class | Surface fact | Grammatical fact |
|---|---|---|
| Paren-wrap | extra `(…)` characters | `TupleExprSyntax` wrapper (semantically transparent) |
| Typename-swap | `Int` vs `self` vs `UInt` token differs | `FunctionCallExprSyntax` with `init(bitPattern:)` (semantically equivalent constructor call) |
| Cast-outside | `count - 1` vs `count) - 1` token order differs | The `1` is a `Subtract` operand on a `Cardinal` quantity (semantically the same) |
| Algebraic-flip | LHS-RHS algebra differs | `i + 1 ≤ count` ↔ `i ≤ count - 1` (semantically the same comparison on the typed quantity) |
| Operand-reorder | n-ary subtraction reorders | Result type / quantity-class is identical |
| Comments-as-code | trivia tokens (comment text) match | The text is a `Trivia` comment, not in the expression grammar |

Each class is a different **lossy projection** from grammar to
text. Adding a companion regex narrows the projection back; it does
not change the fundamental fact that the rule's intent is a
property of the grammar, not of the text.

An AST-based rule operates directly on `parse(S)`. It can be
written as `R'(node) = P(node)` for the specific structural
property `P`. The five classes collapse to single predicates each,
not because the rules are simpler, but because they are now
*correctly typed* — predicates over nodes instead of approximate
predicates over text.

This is the same operational-semantics fact that motivated the
SwiftSyntax migration of SwiftLint's own built-in rules (per
SwiftLint's GitHub README: "rules are predominantly based on
SwiftSyntax"). The fact that user-authored custom rules in
`.swiftlint.yml` remain regex-only is an accident of the public API
surface, not a property of the underlying problem.

### Empirical baseline of deferred AST-shaped rules

| Rule | Deferred from | Empirical surface | Why regex insufficient |
|---|---|---|---|
| R5 `__unchecked:` at call-sites only | `cardinal-ordinal-vector-enforcement-design.md` (DEFER) | 41 files contain `__unchecked:`, mixed legitimate (declaration-site `init(__unchecked _: ())`) and anti-pattern (call-site `Foo(__unchecked: (), bar.rawValue)`) | Both forms share the literal token `__unchecked:`. The legitimate-anti-pattern split is a structural property of the surrounding `FunctionParameterSyntax` vs `LabeledExprSyntax` parent — invisible to text |
| R0 positive enforcement of [CONV-016] | `cardinal-ordinal-vector-enforcement-design.md` (DEFER) | n/a (positive: detect MISSING `.retag()` / `.map()` at conversion sites) | Requires (a) classifying which sites are conversions, (b) classifying current implementation tier 1–5 of [CONV-016], (c) checking whether a higher tier is achievable. All three are AST queries on type-resolved expressions — text cannot distinguish "explicit init that should be retag" from "explicit init that must be init" |
| [API-IMPL-005] one_declaration_per_file with per-path scoping | `rollout-phase-1-results.md` v1.1.0 | 23 violations across 6 packages overall; 14 of them in swift-tagged-primitives' Tests/ files (legitimate [TEST-005] @Suite-category pattern: multiple top-level `private enum TagN {}` fixtures + the @Suite struct) | SwiftLint's `one_declaration_per_file` does not accept per-rule `included:`/`excluded:` (only `severity:` is configurable per its rule-doc page; per-rule path filters are a *custom-rule* feature only). The [TEST-005] pattern needs file-context exemption |
| [TEST-025] test_support_module_in_tests with file-context | (regex landed but partial) | n/a (positive: detect missing `import *_Test_Support` in test files that use literal index/offset/count) | Requires file-context: "is this a test file?" + "does it use literal Tagged-typed values?" Both AST/symbol-table queries |
| ~30 complex multi-decl rules in `mechanical-rule-tool-classification-swift-primitives.md` | (already classified as `swiftlint-custom`, but with "complex multi-decl AST query" annotation) | varies by rule | [INFRA-200] enumerates ≥10 forbidden patterns each requiring multi-token grammatical context; [CONV-003/004/005/006] are API-table multi-pattern; [PKG-NAME-002/006] is namespace + protocol + module-scope typealias triplet across files; [MEM-OWN-012], [MEM-REF-002…005], [MEM-LIFE-002…007] are site-context AST predicates |

The mechanical-rule classification's "no 5th bucket" finding from
2026-05-05 is empirically refuted by the 2026-05-06 evasion data:
multiple rules in scope DO resist all four buckets — they routed
to `swiftlint-custom` only by accepting the "complex multi-decl
AST query" annotation, which is precisely the annotation that
predicts the regex-evasion failure mode encountered.

### Q1 — Architectural options enumerated

Eight options surveyed; A/B/C/D/F constitute the viable shortlist;
E/G/H are eliminated on technical or scope grounds before
comparison.

#### Option A — SwiftLint native AST custom rules (`@SwiftSyntaxRule`)

SwiftLint exposes a `@SwiftSyntaxRule` protocol used by all its
built-in rules. The protocol is **technically extensible to user-
authored rules** (per SwiftLint maintainer jpsim's
`swiftlint-bazel-example` repository), but with two large caveats:

1. **Build mechanism**: requires building SwiftLint with Bazel; the
   standard Homebrew / SwiftPM-resolved SwiftLint binary cannot
   load user-authored AST rules. The Bazel build produces a custom
   SwiftLint binary that has the rules compiled in.
2. **Distribution**: the custom binary must be distributed to every
   consumer (132 swift-primitives sub-repo CI runs, plus local
   developer environments, plus IDE integrations). Docker images,
   GitHub Actions caching, or a custom Homebrew tap are the
   plausible mechanisms.
3. **Documentation**: SwiftLint's README explicitly notes "next to
   no documentation" on writing such rules; community wisdom is
   the primary reference.

This is the closest option to "extend SwiftLint" but is in
practice closer to "fork SwiftLint with extra rules" — the binary
artifact is no longer the upstream SwiftLint.

GitHub Issue #3516 ("Feature Request: Custom Rules written in
Swift") was the long-standing tracker; its eventual resolution
(closed as the Bazel mechanism became viable) closes the protocol-
level gap but does not address the distribution problem.

#### Option B — swift-format custom rules

Apple `swift-format` has a **closed catalog** of 43 rules (18
linter + 25 formatter) with no public extensibility API. Its
generation pipeline uses code generation to keep rule-list-
internals consistent (per swift-format `Documentation/Development
.md`). Adding custom rules would require modifying swift-format
source.

This option is eliminated for the same reason
`mechanical-rule-tool-classification-swift-primitives.md`'s gap
analysis section was marked informational: the catalog is not
extensible without an upstream contribution to apple/swift-format.

#### Option C — SwiftSyntax-based standalone CLI tool

A new Swift package (working name: `swift-primitives-lint`,
exact naming TBD per [API-NAME-001]) that links SwiftSyntax,
walks every `Sources/**/*.swift` and `Tests/**/*.swift`, and emits
diagnostics in either:

- A standard Swift-diagnostics format (file:line:col: severity:
  message), parseable by GitHub Actions' problem-matchers and
  IDEs.
- A SARIF report for CI artifacts.

The tool is invoked as a separate CI step alongside `swiftlint`
and `swift-format lint`. It does NOT replace SwiftLint; it
augments it by handling the rules SwiftLint's regex layer cannot.
SwiftLint continues to host:

- The base regex rules that ARE clean (Foundation imports, L1
  platform conditionals, etc.).
- The closed catalog of built-in canonical rules
  (`one_declaration_per_file` for the simple case,
  `unused_import`, etc.).
- The `parent_config:` 3-tier inheritance chain.

The new tool hosts:

- The 5+1 evasion-class rules that defeat regex.
- R5 (call-vs-decl).
- R0 (positive enforcement).
- [API-IMPL-005] with per-path scoping (since the AST tool has
  file-path context per file as natural input).
- [TEST-025] with file-context awareness.
- Future complex multi-decl rules from `mechanical-rule-tool-
  classification-swift-primitives.md` (~30 such).

Architectural placement (per `developer-tool-package-architecture
.md` DECISION): standalone Swift package in `Developer/`, with
future promotion to a `swift-tools/` superrepo when more tools
emerge. Sibling tools today: `swift-dependency-analysis` (in
the precedent doc).

Distribution: per-CI-run `swift run` invocation against the tool's
package, OR a pre-built binary artifact published as a GitHub
Release. Sandboxing: the tool runs as a normal CLI, not as a
SwiftPM build-tool plugin, so it has no sandbox restrictions.

#### Option D — SwiftSyntax-based SwiftPM build-tool plugin

The same engine as Option C, but packaged as a
`PackagePlugin.BuildToolPlugin`-conforming target that runs as
part of `swift build` (and `swift test`). Each consumer
(swift-primitives sub-package) declares the plugin in its
`Package.swift` `targets:` block.

**SE-0303 mature**: SwiftPM extensible build tools have shipped
since Swift 5.6 (2022). SwiftLint and swift-format both ship
build-tool plugins.

**Sandbox constraints** (per SE-0303 + SwiftPM docs):

- No network access from the plugin process.
- File system access restricted to the plugin's input/output
  directories. The plugin can read source files (declared as
  inputs) but cannot read arbitrary repo paths.
- Xcode 15 defaults `ENABLE_USER_SCRIPT_SANDBOXING = YES`; SwiftLint
  has documented missing-file-permission errors when the build
  graph requires reading outside the declared sandbox. Workaround:
  set `ENABLE_USER_SCRIPT_SANDBOXING = NO` at the consumer target,
  which weakens supply-chain security posture.

**Per-package fanout cost**: 132 sub-packages, each requiring a
`Package.swift` edit to add the plugin to its `swiftSettings`/
`plugins:` declarations. The fanout is mechanical (per the
existing `sync-swift-format.sh` / `sync-swift-settings.sh` family)
but is real ongoing maintenance friction.

**Build-time enforcement vs CI-step enforcement**: the plugin
makes failures `swift build` failures locally — the strongest
feedback loop. But also: every developer build pays the
SwiftSyntax parse cost, and every local edit-rebuild cycle may
re-trigger it.

#### Option E — SwiftSyntax-based SwiftPM command plugin

Same engine, but as `PackagePlugin.CommandPlugin` — a manually
invoked plugin via `swift package plugin run …`. Same sandboxing
as Option D but no automatic CI integration; consumers must wire
up an explicit invocation.

**Eliminated as primary**: the CI integration story is strictly
worse than Option C (which runs as an explicit CI step) without
the build-time-enforcement upside of Option D. Useful as a
secondary deliverable for local "fix everything" runs.

#### Option F — Symbol-graph harvesting + post-processing

The existing pipeline at `swift-primitives/Scripts/{extract,
distill,analyze}-symbol-graphs.*`, executed 2026-03-15 per
`primitives-public-api-graph-analysis.md`, produces a 9.8 MB JSON
catalog of all 132 packages' public API surface (435 modules,
13,262 symbols, 19,022 relationships). Phase 2 of `ai-context-
reduction-via-type-system-tooling.md` Option D would extend the
analysis scripts.

**What it covers**: signature-shape rules, conformance-shape
rules, naming-shape rules. Examples per the original
`ai-context-reduction-via-type-system-tooling.md` Option D table:

- Typed-throws compliance (find `throws` without `(ErrorType)` in
  declarationFragments).
- ~Copyable consistency (check `swiftGenerics` constraints).
- Method-shape consistency across sibling types (compare method
  sets).
- Naming compliance ([API-NAME-001] compound names).
- Convention completeness ([API-IMPL-008] minimal-type-body checks).

**What it cannot cover**: expression-level patterns. Symbol
graphs are produced by `swift package dump-symbol-graph`, which
extracts the **public API surface only**. They do NOT include:

- Implementation bodies (so `count - 1`, paren-wrap, operand-
  reorder all invisible).
- Private / internal declarations (so [API-IMPL-005] coverage is
  partial — public types only).
- Test code (Tests/ targets are typically not extracted).
- Comments / trivia.

This option closes a different cluster of rules than C/D/E.
Roughly: declaration-shape rules go to F; expression-shape rules
go to C/D/E.

#### Option G — Editor-integrated LSP plugin / SourceKit-LSP extension

A custom LSP server (or extension to SourceKit-LSP) that emits
diagnostics in real-time as the developer types. This is the
highest-UX option: in-editor squiggles for evasion patterns,
quick-fixes for retag/map suggestions, etc.

**Eliminated as initial scope**: implementation cost is roughly
two orders of magnitude higher than Option C (an LSP server is a
maintained service, not a single-shot CLI). It is also orthogonal
to CI enforcement (CI cannot consume LSP). A future migration of
Option C's diagnostics into an LSP front-end is plausible
(SwiftLint already exposes itself this way via VSCode extensions),
but the LSP itself does not solve the CI-enforcement problem; it
extends an existing CI-enforcement engine to the editor.

#### Option H — Compiler plugin (diagnostic-emitting macro)

A Swift macro that, when applied to a type, emits compile-time
diagnostics for forbidden patterns inside its body. E.g.:
`@HighTyped struct Buffer { … }` would compile-error on internal
`count - 1` uses.

**Eliminated as primary**: macros are opt-in per type — they
require source-level annotation. They do not give file-level or
target-level coverage. They cannot enforce "every site in
swift-primitives". Useful as a per-type strict-mode in specific
high-discipline modules but NOT a replacement for the linter
question.

### Q2 — Evasion-class coverage matrix

| Class | A: SwiftLint AST | B: swift-format | C: Standalone CLI | D: Build-tool plugin | F: Symbol graph | Current regex |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Paren-wrap | ✅ | ❌ | ✅ | ✅ | ❌ (impl bodies invisible) | ⚠ companion |
| Typename-swap | ✅ | ❌ | ✅ | ✅ | partial | ⚠ broadened |
| Cast-outside | ✅ | ❌ | ✅ | ✅ | ❌ | ⚠ companion |
| Algebraic-flip | ✅ | ❌ | ✅ | ✅ | ❌ | ⚠ companion |
| Operand-reorder | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Comments-as-code | ✅ (trivia awareness) | n/a | ✅ | ✅ | ❌ | workaround only |

✅ = AST-level closure; ⚠ = closed-by-companion-regex (fragile);
❌ = not covered.

A, C, D close all six classes (the trivia-vs-token distinction is
explicit in SwiftSyntax — `Trivia` is its own type). B and F do
not address expression-level rules at all — they answer different
questions.

### Q3 — Deferred AST-rule unblocking matrix

| Rule | A: SwiftLint AST | B: swift-format | C: Standalone CLI | D: Build-tool plugin | F: Symbol graph |
|---|:---:|:---:|:---:|:---:|:---:|
| R5 `__unchecked:` call-vs-decl | ✅ | ❌ | ✅ | ✅ | ✅ (in API surface) |
| R0 positive [CONV-016] enforcement | ✅ | ❌ | ✅ | ✅ | partial (signature-level only; expression bodies not in graph) |
| [API-IMPL-005] one_decl_per_file per-path scoping | ✅ | ❌ | ✅ | ✅ | partial (public types only) |
| [TEST-025] test_support file-context | ✅ | ❌ | ✅ | ✅ | partial |
| ~30 complex multi-decl AST rules | ✅ | ❌ | ✅ | ✅ | partial (public-surface subset) |

C and D (and A) cover all listed rules. F covers the public-API
subset of the deferred rules but cannot reach implementation
bodies — so R0 and the expression-level subset of the complex
multi-decl rules require C/D/A regardless.

This is the structural reason F is **complementary** to C/D, not
substitutive: the two closures (declaration-shape via F,
expression-shape via C/D) are disjoint and additive.

### Q4 — Integration story with the existing 3-tier `parent_config:` chain

The 3-tier SwiftLint chain is canonical infrastructure:

```
swift-institute/.github/.swiftlint.yml          (Tier 1)
    ↑ parent_config URL
swift-primitives/.github/.swiftlint.yml         (Tier 2)
    ↑ parent_config URL
swift-primitives/swift-*-primitives/.swiftlint.yml  (Tier 3, 132 files)
```

Plus: swift-format fanout via 134-copy `.swift-format` distribution
through `swift-institute/Scripts/sync-swift-format.sh`.

For each option:

| Option | Replaces SwiftLint? | Composes with parent_config: chain? | Adds new fanout surface? |
|---|---|---|---|
| A: SwiftLint AST | No (extends) | Yes — rules sit alongside regex `custom_rules:` in the same canonical .swiftlint.yml | No new fanout (chain re-used). New fanout = the **custom SwiftLint binary** itself (not the config). |
| B: swift-format | (eliminated — closed catalog) | n/a | n/a |
| C: Standalone CLI | No (augments) | Yes — runs as separate CI step. SwiftLint chain unchanged. | One new CI invocation per consumer (added to existing swift-ci.yml caller block, like the now-deleted γ-1a workflow). No per-package config fanout — the tool reads the SAME canonical config that SwiftLint reads, OR has its own canonical (TBD). |
| D: Build-tool plugin | No (augments) | Yes — but adds to each consumer's `Package.swift` plugin declaration | Yes — 132 Package.swift edits to declare the plugin. Sync-script fanout pattern absorbs it (`sync-swift-tools-plugin.sh` analog). |
| F: Symbol-graph extension | No (augments) | Orthogonal — runs in a separate CI step against built artifacts | Existing pipeline already in place; extension is in the analysis scripts only. |

Composability ordering: F < C ≤ A < D in terms of integration
friction. F is the cheapest (existing pipeline). C adds one CI
step. A requires custom SwiftLint binary distribution. D requires
132 Package.swift edits (mechanical but ongoing).

### Q5 — Development cost / payback

#### Initial implementation (rough order-of-magnitude)

| Option | Initial dev | Per-rule incremental | Distribution |
|---|---|---|---|
| A: SwiftLint AST | 1–2 weeks (Bazel build infrastructure for SwiftLint, custom binary distribution mechanism, first rule) + per-CI-runner Docker image / Homebrew tap | Days per simple rule, weeks per complex | Custom Homebrew tap or pre-built binary release. Every CI runner + every developer machine re-installs. Maintenance per SwiftLint upstream release: re-build the custom binary against new SwiftLint base. |
| C: Standalone CLI | 3–5 days (Swift package skeleton + first rule + CI integration) | Hours per simple rule (regex equivalent), days per moderate AST rule, weeks per complex multi-decl | `swift run` per CI invocation, OR pre-built binary as GitHub Release. Standard Swift package — no special distribution. |
| D: Build-tool plugin | 5–7 days (same engine as C + plugin packaging + 132 sync-script Package.swift fanout + sandbox testing) | Same as C per rule | 132-package Package.swift edits ongoing every consumer add/remove. Sandbox-permission troubleshooting on Xcode versions + CI runners. |
| F: Symbol-graph extension | 2–3 days per analysis script (existing pipeline as base) | 0.5–2 days per check | Scripts in `swift-primitives/Scripts/`. Existing CI pattern. |

**Per-rule comparison** for the 30 complex multi-decl AST rules
in `mechanical-rule-tool-classification-swift-primitives.md`:

| Bucket of rules | Option A | Option C | Option D | Option F |
|---|---|---|---|---|
| 5+1 expression-level evasion classes | days each | days each | days each | n/a (can't see bodies) |
| R5 + R0 + [API-IMPL-005] per-path + [TEST-025] | days each | days each | days each | partial (public-surface only) |
| ~30 complex multi-decl AST rules | weeks total | weeks total | weeks total | days total (signature-level subset) |

Aggregate scope: ~36 rules over 6–12 months of incremental
authoring per option A/C/D. Option F covers a different (mostly
disjoint) set of ~10 signature-level rules in 2–4 weeks.

#### Ongoing cost

| Option | Per-PR runtime | Maintenance touches per quarter |
|---|---|---|
| A: SwiftLint AST | ~1× SwiftLint (same engine, more rules) | High: SwiftLint upstream version bumps require rebuilding custom binary; Bazel build is non-trivial to keep working |
| C: Standalone CLI | One additional CI step (~5–30s for 132 packages of expected size) | Low: standard Swift package, evolves with SwiftSyntax (which has stable API surface for the relevant nodes) |
| D: Build-tool plugin | Adds to every developer build cycle; plugin invocation is fast but the parse/analyze itself is not free | Medium: 132 Package.swift fanout drift; sandbox failures on toolchain updates |
| F: Symbol-graph | Symbol-graph extraction is already cached per package; analysis scripts run in seconds | Low: scripts evolve with SwiftSyntax / symbol-graph schema; bug surface is small |

#### False-positive / false-negative rate vs current regex

| Option | False-positive risk | False-negative risk |
|---|---|---|
| Current regex (with companions) | Medium (paren-wrap companion can fire on legitimate `(x.rawValue, y.rawValue).reduce(…)` shapes; cast-outside companion can fire on legitimate `(matrix.rows.count) - 1.0` mixed types) | Medium (operand-reorder uncaught; comments-as-code workaround only) |
| Options A/C/D (AST-based) | **Near-zero** when the rule's predicate is correctly typed (semantic match on grammar nodes). The risk migrates from "is the regex too greedy?" to "is the AST predicate too narrow?" — but the latter is debuggable by inspecting the parse tree and is bounded by the grammar's discrete node types | **Near-zero** modulo bugs in the predicate. Operand-reorder collapses to "is the result a `Cardinal - {one of count, n, anyExpr}` chain?" which is decidable on the AST |
| Option F | False-positive: low (signature-shape rules are precise). False-negative: high for expression-level rules (cannot see them at all) | High for any rule that requires implementation-body context |

The transition from regex (false-positive medium / false-negative
medium) to AST (both near-zero) is the principal payback.

### Constraints

#### Swift toolchain compatibility

All four viable options (A, C, D, F) depend on SwiftSyntax. Per
ecosystem precedent (`enum-infrastructure-primitives.md` and the
existing macro packages swift-dual / swift-defunctionalize /
swift-witnesses), SwiftSyntax is already a first-class dependency:
the institute's macro implementations pin against it and track
upstream releases. The added cost of one more SwiftSyntax
consumer is low.

SwiftSyntax versioning is upstream-driven. The
`swift-syntax` repository's release cadence aligns with Swift
toolchain releases (one major per Swift release). The institute's
macro packages already track this; the proposed linter would
adopt the same version-pin discipline.

The toolchain rule (per CLAUDE.md memory
`feedback_toolchain_versions.md`): only Swift 6.3 and 6.4-dev
nightly are in scope. SwiftSyntax 6xx releases support both.

#### SwiftPM build-tool plugin maturity

SE-0303 shipped Swift 5.6 (2022). Mature in the sense that
SwiftLint and swift-format both ship plugins. Two known
constraints:

- **Sandbox restrictions** — no network egress; file system
  restricted to declared inputs/outputs. Per Apple SwiftPM docs.
- **Xcode `ENABLE_USER_SCRIPT_SANDBOXING = YES` default** since
  Xcode 15 — known to break SwiftLint plugin runs unless toggled
  off per target. Trade-off: weakening sandbox to enable plugin.

These constraints are real but specific to Option D. Options C
and F (CLI / scripts) have no sandbox layer.

#### swift-syntax version pinning

The proposed linter pins one specific swift-syntax version per its
own Package.swift. Consumer build graphs (132 sub-packages) do not
pin swift-syntax directly today — they pull it transitively only
when a macro is used. Adding an L4 dev-tool consumer of swift-
syntax does not affect L1 / L2 / L3 build graphs. Options A and D
DO affect the consumer graph: Option A bundles SwiftSyntax inside
the custom SwiftLint binary; Option D adds a `.product(name:
"SwiftSyntax", package: "swift-syntax")` to every consumer's
plugin declaration.

#### Tier-2-vs-ecosystem-wide placement

Per `mechanical-rule-tool-classification-swift-primitives.md` and
`rollout-phase-1-results.md`, the architectural posture is:

- **Tier 1 (ecosystem-wide canonical)**: rules that apply
  universally across all Swift Institute Swift code (e.g.,
  `[API-IMPL-005]` one_declaration_per_file, when fixed).
- **Tier 2 (org-specific)**: rules that apply only within an
  ecosystem (e.g., `[PRIM-FOUND-001]` Foundation ban only within
  swift-primitives; `[PLAT-ARCH-008c]` L1 platform-conditional ban
  only within L1).
- **Tier 3 (per-package)**: per-package overrides.

The proposed linter inherits this tiering: rules embedded in it
have the same Tier 1 / 2 / 3 classification logic. The linter
binary is the same across consumers; rule activation is config-
driven (likely by reading the same `.swiftlint.yml` cascade so
rule-enable state is centrally managed).

This is non-trivial: the linter MUST consume the existing 3-tier
canonical configuration mechanism (URL `parent_config:` chain) so
rule-enabling stays centralized. The simplest implementation: the
linter reads its own `.swift-primitives-lint.yml` file at
package root, with the same `parent_config:` chaining mechanic
(URL-based). One more sync surface, but it follows the same
proven pattern as the SwiftLint chain.

### Comparison matrix

| Criterion | A: SwiftLint AST | B: swift-format | C: Standalone CLI | D: Build-tool plugin | F: Symbol graph |
|---|---|---|---|---|---|
| Evasion-class coverage (5+1) | 6/6 ✅ | 0/6 ❌ | 6/6 ✅ | 6/6 ✅ | 0/6 ❌ |
| Deferred-rule unblocking (5 rules) | 5/5 ✅ | 0/5 ❌ | 5/5 ✅ | 5/5 ✅ | 1.5/5 partial |
| ~30 complex multi-decl rules (additional bandwidth) | full ✅ | n/a | full ✅ | full ✅ | ~10 (signature-level subset) |
| Integration with parent_config: chain | composes (rules in same .swiftlint.yml) | n/a | composes (separate CI step; can read same chain) | composes BUT requires Package.swift fanout | orthogonal (separate pipeline) |
| Initial dev cost | 1–2 weeks (Bazel infra + first rule) | n/a | 3–5 days (skeleton + first rule) | 5–7 days (skeleton + plugin + 132 fanout) | 2–3 days (extends existing scripts) |
| Per-rule incremental cost | days–weeks | n/a | days–weeks | days–weeks | hours–days (signature-level rules only) |
| Distribution mechanism | Custom Homebrew tap / pre-built binary; per-CI-runner install | n/a | `swift run` from package OR GitHub Release binary | 132 Package.swift edits | Existing `swift-primitives/Scripts/` |
| Per-PR CI cost | ~1× SwiftLint | n/a | ~1 additional ~5–30s step | absorbed into `swift build` | Existing artifact; minimal |
| Ongoing maintenance | High (track SwiftLint upstream + Bazel build) | n/a | Low (Swift package + SwiftSyntax pin) | Medium (132-Package.swift fanout drift + sandbox failures) | Low (script + symbol-graph schema) |
| False-positive rate vs regex | near-zero | n/a | near-zero | near-zero | near-zero (signature-level only) |
| Ecosystem precedent | jpsim's swiftlint-bazel-example (one author, niche) | n/a | swift-dependency-analysis (per `developer-tool-package-architecture.md`); swift-witnesses macros (SwiftSyntax consumption); macro-toolkit | usami-k/SwiftLintPlugin; stackotter/swift-lint-plugin | Phase 1 of `ai-context-reduction-via-type-system-tooling.md` (executed 2026-03-15) |

### Prior-art survey [RES-021]

#### Within the Swift ecosystem

| System | What it does | Lesson |
|---|---|---|
| SwiftLint built-in rules | Use `@SwiftSyntaxRule` internally for almost all rules | Confirms SwiftSyntax is the right primitive for Swift-source linting; the institute's investment is in expressing rule predicates, not in re-engineering the parser |
| SwiftLint user `custom_rules:` | Regex-only via `.swiftlint.yml` | The empirical surface this investigation is responding to. The regex/AST gap is the principal limitation |
| SwiftLint's `swiftlint-bazel-example` (jpsim) | Bazel-built custom SwiftLint with user-authored AST rules | Demonstrates Option A is technically viable; demonstrates the distribution-burden cost (every consumer needs the custom binary) |
| swift-format (apple/swift-format) | Closed catalog of 43 rules; codegen-driven internals | Eliminates Option B as a venue for our rules unless we upstream them |
| swift-syntax (swiftlang/swift-syntax) | The parser library; stable public API for `*Syntax` node types and visitor protocols | The substrate. All AST-based options consume it. Version-pinning discipline is well-understood (institute macro packages already pin) |
| swift-macro-toolkit (stackotter) | Generic SwiftSyntax utility library for macro authors | Closest precedent to a SwiftSyntax-dependent shared library outside compiler-plugin code. Confirms the "shared utility library imported by SwiftSyntax consumers" pattern is well-established |
| usami-k/SwiftLintPlugin and stackotter/swift-lint-plugin | SwiftPM build-tool plugins wrapping SwiftLint or doing custom linting | Confirms Option D's packaging shape works in practice; sandboxing constraints are the principal friction |
| Periphery (Periphery dead-code detector) | Standalone Swift CLI consuming SourceKit / SwiftSyntax | Option C precedent: a standalone Swift-source-analysis CLI distributed as Homebrew + binary releases + GitHub Action |
| swift-format custom rules in SE-0455-adjacent discussions (Swift Forums) | Active community ask for swift-format extensibility | Option B may eventually open; not actionable now |

#### In parallel ecosystems

| System | What it does | Lesson |
|---|---|---|
| Rust's `clippy` | Closed-catalog AST-based linter built into the compiler driver | Closest analog to "the linter and the compiler share the parser". Rust does not expose user-authored clippy rules. The institute's ecosystem is closer to Swift's "linter as separate tool" model |
| Rust's `dylint` | Out-of-tree user-authored clippy-style rules via dynamic loading | Distribution problem: `dylint` is widely cited as a maintenance burden; users typically use upstream clippy and propose new rules upstream. Lesson: the cost of "user-authored rules outside the upstream catalog" is real in any ecosystem |
| Go's `analysis` package | First-class library API for AST-based static analysis; `golangci-lint` aggregates community-authored analyzers | The closest "good outcome" for a multi-rule linting ecosystem. `golangci-lint` is widely adopted because the analysis API is stable, well-documented, and extensible. Swift's equivalent (a stable AST-analysis library + a CLI orchestrator) is the structural goal of Option C |
| ESLint (JavaScript) | Plugin ecosystem with user-authored AST rules in `.eslintrc.js` plugins | The "third-party rules in user-config" model. ESLint's success demonstrates the pattern works at scale; cost is in plugin-version coordination and rule-quality variance. The institute's controlled scope (one ecosystem, ~30–40 custom rules) sidesteps the plugin-quality problem |
| Roslyn analyzers (C#) | NuGet-distributed AST-based analyzers consumed via `csproj` | The "build-tool plugin" model done well. Microsoft owns both the build tool and the analyzer API. SwiftPM build-tool plugins (Option D) are the closest Swift analog but with lighter integration than Roslyn |
| Sorbet (Ruby) | Standalone Ruby type checker as separate tool | Option C analog: the value of a separate tool maintained by a focused team; CI integration but not editor integration in the initial release |
| Pylint / mypy / ruff (Python) | Multiple competing standalone CLIs with overlapping responsibilities | Cautionary: a fragmented landscape increases contributor and consumer cognitive load. The institute should NOT build a competing SwiftLint; the linter must augment, not replace |

#### Synthesis (per [RES-021] contextualization step)

The pattern across ecosystems is clear: **AST-based linting is the
universal answer to text-based linting's expression-level
limitations**. Swift is mid-stream in the migration — built-in
SwiftLint rules are AST-based; user-authored rules are not. The
gap this investigation identifies is the same gap clippy → dylint,
ESLint core → ESLint plugins, Roslyn analyzers — the last mile of
extensibility.

The contextualization-into-our-ecosystem check ([RES-021] second
paragraph): the institute already builds SwiftSyntax-dependent
infrastructure (3 macro packages + Tests Inline Snapshot + the
soon-to-be-extracted swift-enum-infrastructure-codegen). The
proposed linter is one more consumer in a well-trodden pattern,
NOT a novel architectural risk.

### Empirical validation [RES-025] — Cognitive Dimensions on the recommended option (C)

| Dimension | Assessment of Option C |
|---|---|
| Visibility | High. The linter is one CI step among several (swiftlint, swift-format, build, test). Rules are documented in the package's README with rule IDs matching the canonical skill-rule IDs ([CONV-016], [INFRA-200], etc.). Diagnostics carry file:line:col + rule ID, parseable by IDEs |
| Consistency | High. Rule names match canonical skill-rule IDs. Severity model matches SwiftLint (warning + --strict gates to error). Configuration mechanism (a YAML file with `parent_config:`-style chaining) mirrors the SwiftLint Tier 1/2/3 chain exactly |
| Viscosity | Low. Adding a new rule = one new Swift file in the linter package + one entry in the canonical YAML. Removing a rule is symmetric. Rules ship via the same release/tag mechanism as any Institute package |
| Role-expressiveness | High. AST predicates are written using SwiftSyntax's typed visitor pattern. A rule that flags "init(bitPattern:)-like calls whose argument chains through .rawValue" is written as a `SyntaxVisitor` over `FunctionCallExprSyntax` matching `init(bitPattern:)` and inspecting `arguments[0].expression` for `.rawValue` member access. The predicate IS the intent; no regex translation step |
| Error-proneness | Low. Predicates are typed against SwiftSyntax's grammar; predicate bugs surface as missed-or-spurious diagnostics, both observable. Rule unit tests use SwiftSyntax-parsed fixtures (the same testing pattern SwiftLint itself uses) |
| Abstraction | Appropriate. The linter is a thin orchestrator around SwiftSyntax + a config loader + a diagnostic emitter. No premature abstractions |

The principal Cognitive-Dimensions concern with the regex layer
(role-expressiveness: regex hides intent under text-pattern;
error-proneness: companion regexes accumulate) inverts to a
strength under Option C.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-06).

### Recommended path forward — Option C (standalone CLI), augmented by Option F (symbol-graph extension)

**Primary deliverable**: a new Swift package
`swift-primitives-lint` (working name; final name per
[API-NAME-001] and the package-naming skill, candidates include
`swift-institute-lint`, `swift-typed-system-lint`) at
`/Users/coen/Developer/swift-primitives-lint/` per the
`developer-tool-package-architecture.md` Option-C precedent
(standalone Swift package in `Developer/`, future-promotable to a
`swift-tools/` superrepo).

**Architectural shape**:

- **Engine**: SwiftSyntax-based AST visitor; loads each
  `.swift` file's `Trivia + Syntax` tree once; runs all rule
  predicates against the same tree.
- **Configuration**: `.swift-primitives-lint.yml` per-package
  config with `parent_config:` URL chaining mirroring the
  SwiftLint 3-tier chain. Three corresponding canonical files
  hosted at `swift-institute/.github/.swift-primitives-lint.yml`
  (Tier 1) and `swift-primitives/.github/.swift-primitives-lint
  .yml` (Tier 2). Tier 3 = per-sub-package overrides.
- **Diagnostics**: file:line:col:severity:message per match; SARIF
  output mode for CI artifacts.
- **CI integration**: one new step in
  `swift-institute/.github/workflows/swift-ci.yml` between
  `swiftlint` and `swift-format lint`. No per-package fanout
  (the tool reads the canonical config chain at runtime).
- **Distribution**: GitHub Release binary artifact, with
  `swift run` from the package as the canonical fall-back. CI
  runners pull the artifact; local developer install via `make
  install` or Homebrew tap.

**Composability**: Option C augments, does not replace:

- **Replaces**: zero existing rules. The 9 Tier 2 SwiftLint regex
  rules continue to fire; the AST tool's evasion-closure rules fire
  in addition. Over time, the AST equivalents of R1–R4 land,
  and the regex versions migrate to the AST tool with both fielded
  during a transition window per the dual-fire pattern (regex-
  warning + AST-error during transition; then regex retires).
- **Augments**: SwiftLint built-in regex rules, swift-format,
  symbol-graph pipeline — all continue. The new tool fills the
  "expression-level AST" niche.

**Secondary deliverable**: extend the existing symbol-graph
pipeline (`primitives-public-api-graph-analysis.md` Phase 1
already executed, scripts in `swift-primitives/Scripts/`) with
Phase 2 analysis scripts per `ai-context-reduction-via-type-system-
tooling.md` Option D. This handles the disjoint signature-shape
rule cluster (~10 rules: typed-throws compliance, ~Copyable
consistency, naming compliance, conformance shape).

### Phasing

**Phase 1 — Scaffolding** (1 week, cost-bounded):
- Create `swift-primitives-lint` Swift package per
  `developer-tool-package-architecture.md` shape.
- Implement the engine: file walker, config loader, diagnostic
  emitter, SARIF writer.
- Implement R5 (`__unchecked:` at call-sites only) as the first
  rule, validating end-to-end.
- Wire into `swift-ci.yml` as an advisory CI step (warning-only
  initially).
- Author per-canonical-Tier YAML at swift-institute/.github and
  swift-primitives/.github.
- Validate: 41-file `__unchecked:` surface, expect call-site flag
  count ≪ 41 (most are declaration-site).

**Phase 2 — Migrate the regex-evasion cluster** (2 weeks):
- Implement AST equivalents of R1 (count - 1 family),
  R2 (Cardinal(0)/(1)), R3 (.rawValue chain), R4 (init(bitPattern:)
  chain).
- Each AST rule subsumes its base + companion regex. Five surface
  patterns collapse to four AST predicates.
- Land the operand-reorder rule (no current regex equivalent;
  pure AST gain).
- Land the comments-as-code-distinction (Trivia vs Token).
- Dual-fire window: regex rules remain warning, AST rules add
  error. Once parity demonstrated, retire regex companions.

**Phase 3 — Positive enforcement (R0)** (3–4 weeks):
- Implement conversion-tier classification on the AST.
- Detect tier-5 sites (rawValue / __unchecked) where tier-1
  (`.retag()`) or tier-2 (`.map()`) is achievable.
- This is the most semantically rich rule; expect iteration on the
  predicate's precision based on diagnostic surface review.

**Phase 4 — `[API-IMPL-005]` per-path scoping + `[TEST-025]`
file-context** (1 week):
- Resurrect the dropped Phase 1 rule with per-file-path exemption
  for the [TEST-005] @Suite-category fixture pattern.
- File-context-aware [TEST-025].

**Phase 5 — Complex multi-decl rules from
`mechanical-rule-tool-classification-swift-primitives.md`** (3–6
months, incremental):
- Migrate the ~30 complex multi-decl rules per cohort.
- Examples: [INFRA-200] operations-intentionally-missing closed
  pattern list; [CONV-003/004/005/006] API-table multi-pattern;
  [PKG-NAME-002/006] namespace+protocol+typealias triplet;
  [MEM-OWN-012] action-enum dispatch; [MEM-REF-002…005]
  reference-primitive site enforcement; [MEM-LIFE-002…007]
  lifetime-primitive site enforcement.
- Each cohort delivered as a separate dispatch with its own
  pre/post violation count.

**Phase 6 (parallel) — Extend symbol-graph pipeline (Option F)**
(2–4 weeks):
- Phase 2 of `ai-context-reduction-via-type-system-tooling.md`
  Option D.
- Typed-throws compliance, ~Copyable consistency, naming
  compliance, conformance-shape rules.
- Run as a separate CI step against the existing
  `public-api-graph.json` artifact.
- Disjoint coverage from C (signature-level vs expression-level).

### Top risks

1. **Distribution friction**. Standalone-CLI distribution is
   simpler than custom-SwiftLint-binary distribution but still
   requires a release pipeline. Mitigation: model after Periphery
   / SwiftFormat (nicklockwood) which both ship via Homebrew +
   GitHub Releases + SPM. Risk class: low.
2. **Rule-predicate precision**. The first rules (especially R0
   positive enforcement) may produce surprising diagnostic
   surfaces; predicates need iteration. Mitigation: dual-fire
   window with warning-only severity; review diagnostic counts
   per rule before gating to error. Risk class: medium for R0,
   low for R1–R4 / R5 (these are well-understood in regex form).
3. **SwiftSyntax version drift**. SwiftSyntax 6xx → 7xx will
   require a coordinated update. Mitigation: existing institute
   convention (per swift-witnesses / swift-dual / swift-
   defunctionalize) of pinning swift-syntax with explicit version
   bumps tied to Swift toolchain releases. Risk class: low.
4. **Scope creep — "now everything is an AST rule"**. Once the
   AST tool exists, every regex rule looks like a candidate. But
   the simple regex rules (Foundation imports, L1 platform
   conditionals) are correctly served by SwiftLint regex; moving
   them gains nothing and adds a CI step's worth of latency.
   Mitigation: explicit retention of the SwiftLint regex layer
   for closed-form rules; the AST tool ONLY hosts rules whose
   predicate is genuinely AST-shaped. Risk class: medium (process
   discipline, not technical).

### Out-of-scope items (deliberately not addressed)

- **Replacement of SwiftLint**: not a goal; the AST tool augments.
- **Migration of swift-format rules**: closed catalog; orthogonal.
- **Editor / LSP integration (Option G)**: deferred indefinitely;
  reconsider after Phase 5 if developer demand surfaces.
- **Compiler-plugin / macro-attached enforcement (Option H)**:
  applicable only to specific high-discipline sites; not a
  replacement for ecosystem-wide linting.
- **Rule-name finalization** for the linter package and its
  `.swift-primitives-lint.yml` config schema: deferred to
  implementation dispatch (the package-naming skill governs).
- **Generalization to swift-foundations / swift-standards / other
  ecosystems**: deferred. The linter is initially scoped to
  swift-primitives per the `applies_to: [swift-primitives]`
  frontmatter, mirroring the Tier 2 placement of R1–R4.

### Why this overrides the prior "no 5th bucket" finding

`mechanical-rule-tool-classification-swift-primitives.md` v1.0.0
(2026-05-05) explicitly stated: "No 5th-bucket candidates
surfaced: no rule resisted all four buckets such that a
`swiftsyntax-tool` (custom AST tool beyond SwiftLint) would be
required." That finding stands as classification-time reasoning:
under the four-bucket framework, every rule routed to
`swiftlint-custom`.

The 24-hour-later empirical reality (R1–R4 enforcement-cohort
cleanup waves 2026-05-06) demonstrates that the
`swiftlint-custom` route, while categorically available, accumulates
companion regexes whose maintenance cost exceeds the AST-tool
alternative. The five demonstrated evasion classes — three of which
required broadened-base + companion regex pairs — are the empirical
basis for the 5th bucket.

This research **does not contradict** the v1.0.0 classification;
it **adds a sub-classification within `swiftlint-custom`**:

- **Tier 5a (regex-feasible)**: rules whose predicate is closed-
  form text — Foundation imports, L1 platform conditionals,
  filename conventions. Stay in SwiftLint regex.
- **Tier 5b (regex-fragile, AST-feasible)**: rules whose predicate
  has demonstrated regex evasion or has been deferred for AST
  reasons — R0–R5, [API-IMPL-005] per-path, [TEST-025] file-context,
  ~30 complex multi-decl from `mechanical-rule-tool-classification
  -swift-primitives.md`. Move to the new linter (Option C).

The classification change is one of routing, not of catalog
expansion. The bucket count goes from 4 to 5 only if one counts the
new `swiftsyntax-tool` route as a distinct bucket; equivalently,
the count remains 4 if one re-defines `swiftlint-custom` as `regex-
custom` and moves the AST-shaped rules into the new bucket.
Either way, the rule populations migrate.

---

## References

### Internal (prior research, all cited above)

- `swift-institute/Research/ai-context-reduction-via-type-system-tooling.md` (RECOMMENDATION 2026-04-01) — Option D Symbol-graph pipeline; Phase 1 executed 2026-03-15.
- `swift-institute/Research/primitives-public-api-graph-analysis.md` (RECOMMENDATION 2026-04-13) — Phase 1 results; symbol-graph artifacts.
- `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md` (RECOMMENDATION 2026-05-05) — R1–R4 cohort; R5 + R0 deferral.
- `swift-institute/Research/mechanical-rule-tool-classification-swift-primitives.md` (RECOMMENDATION 2026-05-05) — 195 mechanical rules, 4-bucket classification, "no 5th bucket" finding empirically refined here.
- `swift-institute/Research/rollout-phase-1-results.md` (RECOMMENDATION v1.1.0 2026-05-05) — Phase 1 of the centralized linter rollout; documents the per-path-scoping limitation that drops [API-IMPL-005].
- `swift-institute/Research/developer-tool-package-architecture.md` (DECISION Tier 3 2026-04-13) — establishes the architectural home for tool packages (Option C standalone in Developer/, future-promotable to `swift-tools/` superrepo).
- `swift-institute/Research/enum-infrastructure-primitives.md` (referenced) — establishes SwiftSyntax-dependent shared codegen library precedent.

### Internal (skill files)

- `swift-institute/Skills/conversions/SKILL.md` — [CONV-001], [CONV-002], [CONV-016] preference hierarchy that R0 enforces.
- `swift-institute/Skills/existing-infrastructure/SKILL.md` — [INFRA-002], [INFRA-025], [INFRA-101], [INFRA-103], [INFRA-200] cited by R1–R4.
- `swift-institute/Skills/code-surface/SKILL.md` — [API-IMPL-005] one_declaration_per_file; [API-NAME-001] linter-package naming.
- `swift-institute/Skills/testing/SKILL.md` — [TEST-005] @Suite category (the [API-IMPL-005] exemption pattern); [TEST-025] test_support_module_in_tests file-context rule.

### External

- [SwiftLint custom_rules documentation](https://realm.github.io/SwiftLint/custom_rules.html) — regex-only mechanism for user-authored rules.
- [SwiftSyntaxRule Protocol Reference (SwiftLint)](https://realm.github.io/SwiftLint/Protocols/SwiftSyntaxRule.html) — the protocol used by SwiftLint built-in rules.
- [jpsim/swiftlint-bazel-example](https://github.com/jpsim/swiftlint-bazel-example) — the Bazel-build mechanism for user-authored AST rules in SwiftLint (Option A).
- [GitHub Issue realm/SwiftLint#3516](https://github.com/realm/SwiftLint/issues/3516) — long-standing "Custom Rules written in Swift" feature request, eventually addressed via the Bazel mechanism.
- [SwiftLint README](https://github.com/realm/SwiftLint) — confirms most built-in rules are SwiftSyntax-based.
- [Apple swift-format Rule Documentation](https://github.com/swiftlang/swift-format/blob/main/Documentation/RuleDocumentation.md) — closed catalog of 43 rules.
- [Apple swift-format Documentation/Development.md](https://github.com/swiftlang/swift-format/blob/main/Documentation/Development.md) — codegen-driven internals; no public rule-extensibility API.
- [SE-0303 SwiftPM Extensible Build Tools](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0303-swiftpm-extensible-build-tools.md) — the build-tool plugin substrate for Option D; sandboxing semantics.
- [Swift Forums: Adding linting/formatting to SwiftPM build tools](https://forums.swift.org/t/adding-support-for-linting-and-formatting-to-swiftpms-extensible-build-tools/55671) — the partial-support note.
- [usami-k/SwiftLintPlugin](https://github.com/usami-k/SwiftLintPlugin) and [stackotter/swift-lint-plugin](https://github.com/stackotter/swift-lint-plugin) — community SwiftPM build-tool plugin precedents for Option D.
- [stackotter/swift-macro-toolkit](https://github.com/stackotter/swift-macro-toolkit) — the closest ecosystem precedent for a shared SwiftSyntax utility library (relevant to Option C's package shape).
- [Periphery](https://github.com/peripheryapp/periphery) — Option-C precedent: a standalone Swift-source-analysis CLI distributed via Homebrew + GitHub Releases.
- [SwiftFormat (nicklockwood)](https://github.com/nicklockwood/SwiftFormat) — alternative Option-C precedent.
- [Rust dylint](https://github.com/trailofbits/dylint) — out-of-tree clippy-like rules; cautionary case study on distribution burden in parallel ecosystem.
- [Go analysis package](https://pkg.go.dev/golang.org/x/tools/go/analysis) and [golangci-lint](https://github.com/golangci/golangci-lint) — the closest "good outcome" precedent for a multi-rule linting orchestrator over a stable AST library.
- [Roslyn analyzers](https://learn.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/) — Microsoft's NuGet-distributed AST-analyzer model; relevant to Option D's build-tool-plugin shape.
- [ESLint](https://eslint.org/) — JavaScript plugin-based AST-rule ecosystem; relevant to user-authored rule pattern at scale.

### Tier-2 SwiftLint canonical config (current state)

- `https://raw.githubusercontent.com/swift-primitives/.github/main/.swiftlint.yml` — the 9-rule Tier 2 canonical (Foundation imports + L1 platform conditionals + R1–R4 + 2 evasion companions). Local copy at `/Users/coen/Developer/swift-primitives/.github/.swiftlint.yml` HEAD `c252a39`.
- Tier 2 evasion-companion commits: `7622a8b` (paren-wrap + typename-swap broadening), `c252a39` (cast-outside + algebraic-flip companion).
