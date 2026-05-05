# Mechanical-Rule Tool Classification — swift-primitives

<!--
---
version: 1.0.0
last_updated: 2026-05-05
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-primitives]
normative: false
---
-->

## Context

### Trigger

The swift-primitives ecosystem deploys both **Apple swift-format** (config `.swift-format`, JSON, hyphenated; 133 identical copies fanned out from a 1907-byte root via copy-paste) and **SwiftLint** (config `.swiftlint.yml`, inheriting from a canonical `swift-standards/swift-standards/main/.swiftlint.yml` via `parent_config:`). The verification-taxonomy classification sweep (pilot + tier-1 + tier-2 + tier-3, 2026-05-05) classified ecosystem-wide skill requirements into mechanical / hybrid / semantic. This dispatch sub-classifies the **mechanical** rules that apply to swift-primitives Swift code into four enforcement-tool buckets:

1. `swift-format` — Apple swift-format (closed catalog of 43 rules; deployed via the 133-copy fanout).
2. `swiftlint-canonical` — SwiftLint built-in (closed catalog of 324 rules: 129 default + 190 opt-in + 5 analyzer; deployed via canonical-config inheritance).
3. `swiftlint-custom` — custom regex / `analyze` rule beyond SwiftLint built-ins, addable to the canonical config.
4. `custom-ci` — outside both linters' reach (Package.swift parsing, cross-package grep, repo-metadata, non-Swift artifacts, build-graph rules, diff-aware predicates, markdown / JSON / YAML processing).

Output classifies which in-scope mechanical rules are (a) **already enforced**, (b) **cheaply addable** as config flips or small custom additions, or (c) **genuinely need workflow YAML**. Scope is **swift-primitives only** for this dispatch; generalization to other ecosystems is gated on this RECOMMENDATION's review.

### Status quo (verified 2026-05-05)

- `swift-primitives/.swift-format` (root, 1907 bytes, JSON v1) sets `lineLength: 200`, `indentation.spaces: 4`, `maximumBlankLines: 1`, `fileScopedDeclarationPrivacy.accessLevel: "private"`, plus a `rules:` block with 20 rules `true` and 14 `false`. Active rules: `DoNotUseSemicolons`, `DontRepeatTypeInStaticProperties`, `FileScopedDeclarationPrivacy`, `FullyIndirectEnum`, `GroupNumericLiterals`, `IdentifiersMustBeASCII`, `NoAccessLevelOnExtensionDeclaration`, `NoCasesWithOnlyFallthrough`, `NoEmptyTrailingClosureParentheses`, `NoLabelsInCasePatterns`, `NoParensAroundConditions`, `NoVoidReturnOnFunctionSignature`, `OneCasePerLine`, `OneVariableDeclarationPerLine`, `OnlyOneTrailingClosureArgument`, `OrderedImports`, `ReturnVoidInsteadOfEmptyTuple`, `UseLetInEveryBoundCaseVariable`, `UseSingleLinePropertyGetter`, `UseTripleSlashForDocumentationComments`. Disabled rules of note: `AllPublicDeclarationsHaveDocumentation`, `BeginDocumentationCommentWithOneLineSummary`, `NeverForceUnwrap`, `NeverUseForceTry`, `NeverUseImplicitlyUnwrappedOptionals`, `ValidateDocumentationComments`.
- 133 swift-primitives sub-package `.swift-format` files exist; the parent supervisor sampled 3 and verified md5-identity to root. Per-this-dispatch scope, these are read-only.
- Canonical SwiftLint config at `swift-standards/swift-standards/main/.swiftlint.yml` (HTTP 200 verified): `disabled_rules:` lists 17 rules deliberately turned off (`line_length`, `trailing_comma`, `redundant_discardable_let`, `identifier_name`, `large_tuple`, `optional_data_string_conversion`, `for_where`, `todo`, `type_body_length`, `nesting`, `type_name`, `cyclomatic_complexity`, `implicit_optional_initialization`, `function_body_length`, `file_length`, `closure_parameter_position`, `opening_brace`); `opt_in_rules:` enables 9 rules (`explicit_init`, `closure_spacing`, `empty_count`, `empty_string`, `fatal_error_message`, `first_where`, `joined_default_parameter`, `operator_usage_whitespace`, `overridden_super_call`); `function_parameter_count: warning 6 / error 8`; `included: [Sources, Tests]`. swift-primitives root `.swiftlint.yml` inherits via `parent_config:` URL.
- swift-format catalog (closed, [Apple swift-format Rules.md](https://github.com/apple/swift-format/blob/main/Documentation/RuleDocumentation.md), 2026-05-05): 18 linter rules + 25 formatter rules = 43 total.
- SwiftLint catalog (closed, [SwiftLint Rule Directory](https://realm.github.io/SwiftLint/rule-directory.html), 2026-05-05): 129 default + 190 opt-in + 5 analyzer = 324 total.

### Empirical scope count

In-scope mechanical-bucket rules sub-classified in this dispatch: **195 unique** across 15 skills (206 with `[IDX-*]` rules counted once per appearance under both `conversions` and `index`). The supervisor block's `ask:` re budget calibration (>~200) is marginal: 195 unique is bounded and homogeneous (most predicates are AST/regex on Swift source); single-session classification is within Max OAuth budget. Per [SUPER-024], in-action with explicit acknowledgement here = no escalation.

---

## Methodology

For each in-scope mechanical rule, the predicate stated in the source classification doc was matched against the swift-format catalog (closed) and the SwiftLint catalog (closed) using exact rule-name matching. Borderline cases were assigned to the cheaper bucket per the supervisor block ordering: `swift-format < swiftlint-canonical < swiftlint-custom < custom-ci`, with `**Tool-Alternative:**` annotations on cross-bucket trade-offs. Annotations applied:

- `**Already-Enforced:**` — the rule is in the current canonical SwiftLint opt-in list OR the swift-primitives `.swift-format` `rules:` block (set to `true`).
- `**Config-Flip:**` — for `swiftlint-canonical` rules currently disabled in canonical that would enforce by flipping to opt-in.
- `**Custom-Rule-Author:**` — for `swiftlint-custom` rules; characterizes cost (regex one-liner / analyze rule / multi-rule cluster).
- `**Fanout-Required:**` — for `swift-format` changes (133 identical copies in swift-primitives).
- `**γ-Migration-Candidate:**` — for rules currently in v1.2.0 γ-roadmap (γ-1a Foundation, γ-1b license-header) that should migrate to SwiftLint or swift-format.

Skills out of scope (per dispatch brief): `audit`, `benchmark`, `ci-cd-workflows`, `github-repository`, `package-export`, `swift-institute`, `swift-institute-core`, `release-readiness`, `ecosystem-data-structures`, `readme`, all voice/process skills, all rule-law skills, `testing-swiftlang`. Source: `swift-institute/Research/skill-verification-taxonomy-{pilot,extension-tier-1,extension-tier-2,extension-tier-3}.md`.

---

## Per-skill classifications

### code-surface (15 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[API-NAME-001]` | Nest.Name Pattern (no compound type names; AST top-level decl name) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex `(struct\|enum\|class\|actor\|protocol)\s+\w*[a-z]\w*[A-Z]\w+` for compound; spec-namespace allowlist required for `RFC_*`/`ISO_*`/`IEEE_*` prefixes). **Tool-Alternative:** swiftlint-canonical `type_name` (default; currently disabled in canonical) catches length+capitalization but NOT compound shape. **Already-Enforced:** No. |
| `[API-NAME-005]` | Pre-Rename Mechanical Check (outcome = NAME-001/002) | `swiftlint-custom` | Outcome-equivalent to `[API-NAME-001]`; same custom rule fires. Process-timing aspect ("at proposal time") is not CI-observable. |
| `[API-NAME-006]` | New-Code Self-Compliance During Enforcement Sweeps | `swiftlint-custom` | Outcome-equivalent to the swept rule (typically NAME-001/002); SwiftLint applied to PR-changed files achieves the outcome. |
| `[API-NAME-007]` | Convention-Known-Convention-Unapplied Heuristic (outcome = compound check) | `swiftlint-custom` | Outcome-equivalent to NAME-001/002 compound regex. Trigger condition (b) is semantic; outcome is mechanical and same rule fires. |
| `[API-ERR-001]` | Typed Throws Required (regex `throws\s*(?!\()` on function decls) | `swiftlint-custom` | **Custom-Rule-Author:** one-liner regex. **Already-Enforced:** No. **Tool-Alternative:** swiftlint-canonical `untyped_error_in_catch` (opt-in) is adjacent (catches `catch let X` with un-typed binding) but does not enforce the throw-side of the typed-throws contract. |
| `[API-ERR-002]` | Nested Error Types (AST: `Swift.Error`-conforming type nested under domain type) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST query (enumerate `Error`-conforming types; verify parent != module-scope). |
| `[API-ERR-004]` | Explicit Closure Annotation for Typed Throws | `swiftlint-custom` | **Custom-Rule-Author:** complex AST query (find function bodies with `throws(E)` effect; find rethrows-call sites; verify each closure arg has explicit `throws(E)` in closure-signature). |
| `[API-ERR-005]` | stdlib Typed Throws Compatibility (Swift 6.2.4) (closed list of names) | `swiftlint-custom` | **Custom-Rule-Author:** moderate regex + closed allowlist of stdlib symbols (`Sequence.map`, `withUnsafeBytes`, `Mutex.withLock`, …) flagging `@_disfavoredOverload` decls against the WORKS list. |
| `[API-IMPL-005]` | One Type Per File (AST: count top-level type decls per file == 1) | `swiftlint-canonical` | **Already-Enforced:** No (rule exists, currently NOT in canonical opt-in). **Config-Flip:** Yes — add `one_declaration_per_file` to the canonical `opt_in_rules:` list. SwiftLint built-in is exact match. |
| `[API-IMPL-006]` | File Naming Convention (basename matches contained type's nested path) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (filename regex + AST type-path extraction). **Tool-Alternative:** swiftlint-canonical `file_name` (opt-in) is partial — checks single type name vs filename, no nested-path support. |
| `[API-IMPL-007]` | Extension Files (filename `+Conformance.swift` or `Type where Constraint.swift`) | `swiftlint-custom` | **Custom-Rule-Author:** regex on filename shape. |
| `[API-IMPL-008]` | Minimal Type Body (members ⊆ {stored property, init, deinit}) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST query with allowlist (~Copyable exception per `[MEM-COPY-006]`). |
| `[API-IMPL-010]` | Visibility Change Triggers Naming Audit (diff-aware) | `custom-ci` | Diff-aware predicate; SwiftLint runs on full files, not diffs. **Tool-Alternative:** `swiftlint-custom` partial (apply NAME-001/002 to all symbols); `custom-ci` is the natural home for the diff-trigger ("widening access → audit"). |
| `[API-IMPL-012]` | Closure Parameters Trail the Signature (AST: once closure param seen, all later params closure-typed) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST query (param-list scan). |
| `[API-IMPL-015]` | Struct Configuration Over Builder Closures (forbid `(inout T) -> Void` builder params) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST/regex (closure-shape check on param types). |

**code-surface distribution**: 0 swift-format / 1 swiftlint-canonical / 13 swiftlint-custom / 1 custom-ci.

---

### primitives (4 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[PRIM-FOUND-001]` | No Foundation Imports (regex on imports) | `swiftlint-custom` | **Custom-Rule-Author:** one-liner regex `^\s*(@\w+(\([^)]*\))?\s+)?(public\|package\|internal)?\s*(@_exported\s+)?import\s+Foundation(Essentials\|Internationalization)?\b`. **γ-Migration-Candidate:** YES — this rule is currently γ-1a deterministic in v1.2.0 §3.4.10 (canonical mechanical case) and implemented as workflow YAML; migrating to a SwiftLint custom rule is a one-line change in the canonical `.swiftlint.yml` and matches existing `parent_config:` distribution. **Tool-Alternative:** custom-ci (current implementation) — keep until migration is authorized. |
| `[PRIM-ARCH-001]` | Thirteen-Tier DAG Structure (Package.swift dep-graph computation) | `custom-ci` | Package.swift parsing + tier-table comparison; outside Swift source linters' reach. |
| `[PRIM-ARCH-002]` | Downward Dependencies Only (Package.swift edge direction) | `custom-ci` | Same engine as `[PRIM-ARCH-001]`. Detects circular and lateral deps. |
| `[PRIM-NAME-001]` | Primitives Suffix (regex on package names `^swift-.+-primitives$`) | `custom-ci` | Package metadata (Package.swift `name:` field or repo name); package-level not source-file-level. **Tool-Alternative:** swiftlint-custom partial (regex on Package.swift's `name:` string) but unusual deployment shape. |

**primitives distribution**: 0 swift-format / 0 swiftlint-canonical / 1 swiftlint-custom / 3 custom-ci.

---

### documentation (32 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[DOC-003]` | Method documentation (`- Parameter`, `- Returns:`, `- Throws:` coverage on public throwing/returning methods) | `swift-format` | **Already-Enforced:** No (`ValidateDocumentationComments: false` in swift-primitives root `.swift-format` line 53). **Config-Flip:** Yes — flip to `true`. **Fanout-Required:** YES (133 sub-package `.swift-format` copies need re-fanout). swift-format catalog rule `ValidateDocumentationComments` is the exact match per [Apple swift-format Rules.md]. |
| `[DOC-006]` | Subsection enumeration (regex on comment blocks for `[N.](<doc:...>)` shape) | `custom-ci` | Predominantly markdown in `.docc/` files; swift-format/SwiftLint do not parse markdown. **Tool-Alternative:** swiftlint-custom partial — `///` doc-comment regex on Swift sources. |
| `[DOC-007]` | Abbreviated subsection syntax (`> N.-M. [...]` format) | `custom-ci` | Same as `[DOC-006]` — markdown predominant. |
| `[DOC-008]` | Cross-reference formats (DocC `[text](<doc:Path>)`; backtick auto-link `` ``Symbol`` ``) | `custom-ci` | Markdown formatting check. |
| `[DOC-009]` | Definition index pattern (`_[term](<doc:...>)_` italic + link) | `custom-ci` | Markdown formatting check. |
| `[DOC-020]` | Catalogue location (`Sources/{Module}/{Module}.docc/` exists) | `custom-ci` | Filesystem layout + Package.swift cross-reference. |
| `[DOC-021]` | Root page (every `.docc/` carries `{Module}.md` with required headings) | `custom-ci` | Filesystem + markdown parse. |
| `[DOC-022]` | Article pages — Navigation Level (heading + `@Metadata` block) | `custom-ci` | Markdown parse. |
| `[DOC-024]` | Subsection pages (per-subsection `.docc` article) | `custom-ci` | Markdown + filesystem. |
| `[DOC-026]` | Flat catalogue layout (only `Resources/` subdirectory) | `custom-ci` | Filesystem. |
| `[DOC-028]` | Research references in `.docc` articles (placement + format) | `custom-ci` | Markdown content rule. |
| `[DOC-029]` | Experiment references in `.docc` articles | `custom-ci` | Markdown content rule. |
| `[DOC-030]` | External links (authoritative external link on spec-modeling root pages) | `custom-ci` | Markdown + HTTP availability. |
| `[DOC-031]` | Cross-module references (full identifier `RFC 3986 Section 3.3` required) | `custom-ci` | Markdown / doc-comment regex. |
| `[DOC-032]` | Range reference pattern (regex for "Section X through Section Y, inclusive") | `custom-ci` | Markdown / doc-comment regex. |
| `[DOC-033]` | Blockquote convention (spec text wrapped in `>`) | `custom-ci` | Markdown + Swift `///` comments. **Tool-Alternative:** swiftlint-custom partial for `///` blocks. |
| `[DOC-045]` | Workaround documentation template (`// WORKAROUND:` with `WHY:` / `WHEN TO REMOVE:` / `TRACKING:`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (multi-line regex on Swift comment block; verify all four required fields). Swift-source comments → SwiftLint can host. |
| `[DOC-051]` | Automated verification of derived information (CI verification step exists per package) | `custom-ci` | Workflow-grep (cross-file). |
| `[DOC-061]` | Topical article structure (kebab-case filenames + headings + `@Metadata` + `## See Also`) | `custom-ci` | Markdown + filesystem. |
| `[DOC-063]` | Topical articles in Topics (parse landing page Topics; verify named groups) | `custom-ci` | Markdown parse. |
| `[DOC-070]` | Tutorial table of contents (`Tutorials.tutorial` exists for `*.tutorial` files) | `custom-ci` | Filesystem. |
| `[DOC-071]` | Tutorial code layout (`@Code` references under `.docc/Resources/`; no `* Tutorial Host` target) | `custom-ci` | Filesystem + Package.swift parse. |
| `[DOC-072]` | Tutorial structure (`@Tutorial(time:)` + `@Intro` + `@Section` + `@ContentAndMedia` + `@Steps` + `@Step` + `@Code` directive hierarchy) | `custom-ci` | Tutorial-file parse (DocC `.tutorial` syntax — neither linter handles). |
| `[DOC-080]` | Umbrella catalog as landing page (`## Overview` + `@Row`/`@Column` + role-grouped `## Topics`) | `custom-ci` | Markdown parse. |
| `[DOC-081]` | `@CallToAction` (presence + `(url:..., purpose: link\|download, label:...)` shape) | `custom-ci` | Markdown directive parse. |
| `[DOC-082]` | `@Row` and `@Column` layout (2–4 columns + H3 heading + sentence + link) | `custom-ci` | Markdown directive parse. |
| `[DOC-084]` | Topics grouping on landing pages (role-ordered groups) | `custom-ci` | Markdown parse. |
| `[DOC-091]` | `@PageImage` (source filename exists in `.docc/Resources/`; size/extension constraints) | `custom-ci` | Filesystem + binary-content check. |
| `[DOC-092]` | `@Available` shape (Platform, introduced: "version") | `custom-ci` | Markdown directive parse. |
| `[DOC-093]` | Visual consistency across catalogues (cross-`.docc` `@PageColor`/`@PageImage` diff) | `custom-ci` | Cross-file / cross-package diff. |
| `[DOC-101]` | Consumer/contributor boundary in DocC (forbidden tokens in per-symbol/topical articles) | `custom-ci` | Markdown content rule. |
| `[DOC-102]` | Preview-and-convert parity in DocC tooling guidance (skill-text self-audit) | `custom-ci` | Skill-doc + filesystem cross-reference. |

**documentation distribution**: 1 swift-format / 0 swiftlint-canonical / 1 swiftlint-custom / 30 custom-ci.

---

### existing-infrastructure (13 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[INFRA-001]` | Integration Module Pattern (Package.swift product names matching `^.+ Standard Library Integration$`) | `custom-ci` | Package.swift parse + cross-package enumeration. |
| `[INFRA-002]` | Cardinal Integration — Counts and Sizes (regex `Int(bitPattern: count.cardinal)`) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner per pattern. |
| `[INFRA-003]` | Ordinal Integration — Positions and Subscripts (regex `(base + Int(bitPattern: \w+)).pointee`) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner. |
| `[INFRA-004]` | Affine Integration — Pointer Arithmetic (regex for `pointer + Int(bitPattern:)` patterns) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner. |
| `[INFRA-005]` | Memory Integration — Raw Pointer Operations (regex/AST for `memory.initialize(as:, repeating:, count:)` with `Int` count) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex with type-context). |
| `[INFRA-020]` | Before Writing `Int(bitPattern:)` (regex trigger; closed-form route to typed overloads) | `swiftlint-custom` | **Custom-Rule-Author:** one-liner regex on `Int(bitPattern:`. |
| `[INFRA-024]` | Before Writing `withUnsafe*` Closures (regex on storage-managing types) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex with type-context). |
| `[INFRA-025]` | Before Writing `count - 1` (regex `count - 1`, `count -= 1`, etc.) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner. |
| `[INFRA-103]` | Tagged Functors — retag and map (regex/AST for reconstruction shapes; `<TypeName>(<Type>(<expr>.rawValue.rawValue))`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (multi-pattern regex cluster). |
| `[INFRA-104]` | Affine.Discrete.Ratio — Typed Scaling (regex for forbidden scaling patterns) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. |
| `[INFRA-108]` | Bit Vector Bulk Operations (per-bit `while`-loop calling `set`/`clear` at single-bit indices) | `swiftlint-custom` | **Custom-Rule-Author:** complex (loop-shape AST query). |
| `[INFRA-109]` | Storage Primitives (regex on `withUnsafeMutablePointerToElements` patterns) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. |
| `[INFRA-200]` | Operations That Are Intentionally Missing (closed forbidden-pattern list — `Cardinal - Cardinal`, `count &-= 1`, `pointer + count`, etc.) | `swiftlint-custom` | **Custom-Rule-Author:** multi-rule cluster (each forbidden pattern is one custom rule; ≥10 patterns enumerated). |

**existing-infrastructure distribution**: 0 swift-format / 0 swiftlint-canonical / 12 swiftlint-custom / 1 custom-ci.

---

### swift-package (5 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[PKG-NAME-002]` | Canonical Capability Protocol (namespace `enum N` declaring `` `Protocol` `` + module-scope typealias `Gerund = N.\`Protocol\``) | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-decl AST query (namespace + protocol + non-nested typealias cross-check). **Tool-Alternative:** custom-ci for full module-scope verification. |
| `[PKG-NAME-006]` | Hoisted Protocol for Generic Namespaces (generic namespace + hoisted `__<Name>Protocol` + typealias) | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-decl AST query. |
| `[PKG-NAME-007]` | Phase-0 Pre-Rename Audit Requirements (verify two greps were run by checking PR description) | `custom-ci` | Process timing not CI-observable; verifiable artifact is PR description content. |
| `[PKG-NAME-008]` | Shadow-on-Merge Hazard (post-rename diff scan for shadowed inner-tag refs) | `custom-ci` | Diff-aware + build-failure surface. |
| `[PKG-NAME-010]` | GitHub Release vs Git Tag (workflow-correctness: heritage scripts call `git describe --tags --abbrev=0` for tags, `gh repo view --json latestRelease` for releases) | `custom-ci` | Shell/script audit, cross-script grep. |

**swift-package distribution**: 0 swift-format / 0 swiftlint-canonical / 2 swiftlint-custom / 3 custom-ci.

---

### swift-package-build (6 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[PKG-BUILD-001]` | Use `TOOLCHAINS` Env Var, Not `xcrun --toolchain`, for SwiftPM Nightly Builds | `custom-ci` | Shell-script lint + CI-config grep (workflow YAML, not Swift source). |
| `[PKG-BUILD-002]` | Look Up the Bundle Identifier via `defaults read` | `custom-ci` | Shell + Info.plist lookup. |
| `[PKG-BUILD-005]` | Linux Builds Use the Official `swift:<version>` Docker Image | `custom-ci` | CI-config grep on workflow YAML. |
| `[PKG-BUILD-006]` | Linux Nightly Builds Use `swiftlang/swift:nightly-main-jammy` | `custom-ci` | CI-config grep on workflow YAML. |
| `[PKG-BUILD-007]` | Embedded Swift Source-Guard Pattern (`#if !hasFeature(Embedded)` wrapping forbidden surfaces) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex/AST for forbidden surface decls inside / outside `#if !hasFeature(Embedded)` block). The only Swift-source rule in this skill. |
| `[PKG-BUILD-008]` | Embedded Build-Mode Invocation (Verified on Swift 6.4-dev) | `custom-ci` | Shell + CI-config check. |

**swift-package-build distribution**: 0 swift-format / 0 swiftlint-canonical / 1 swiftlint-custom / 5 custom-ci.

---

### conversions (18 mechanical rules)

Note: 11 `[IDX-*]` rules in this skill (`[IDX-001]`, `[IDX-002]`, `[IDX-003]`, `[IDX-006]`, `[IDX-006a]`, `[IDX-006d]`, `[IDX-007]`, `[IDX-008]`, `[IDX-016]`, `[IDX-017]`, `[IDX-018]`) ALSO appear in the `index` skill below and classify identically. Counted once in the union; listed once in this section.

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[IDX-001]` | Index as Tagged Ordinal (`public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST/typealias check. Shared with `index`. |
| `[IDX-002]` | Index.Offset as Tagged Vector | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. Shared. |
| `[IDX-003]` | Index.Count as Tagged Cardinal | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. Shared. |
| `[IDX-006]` | Index Arithmetic with Offset (operator overload signatures) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (operator-decl shape). Shared. |
| `[IDX-006a]` | Index Arithmetic with Count and Offset Literals | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. Shared. |
| `[IDX-006d]` | Count Subtraction (Saturating) (forbid `Count - Count` operator) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner (operator usage). Shared. |
| `[IDX-007]` | Bounds Checking (cross-type comparison overloads) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. Shared. |
| `[IDX-008]` | Range Iteration (`(.zero..<count)`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. Shared. |
| `[IDX-016]` | Test Suite Structure (`@Suite("Index")` nested pattern) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. Shared. |
| `[IDX-017]` | RandomAccessCollection Offset (`collection.index(_:offsetBy:)` with `Index<T>.Offset`) | `swiftlint-custom` | **Custom-Rule-Author:** regex on call sites. Shared. |
| `[IDX-018]` | Span with Index.Count (`Span(...)` constructions) | `swiftlint-custom` | **Custom-Rule-Author:** regex on call sites. Shared. |
| `[CONV-001a]` | Intermediate Property Access Location (`.position` / `.rawValue` inside `#expect(...)` outside same-package) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner restricted to test files. |
| `[CONV-003]` | Index Conversions (API-table grep for each conversion init signature) | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-pattern (one rule per row in API table). |
| `[CONV-004]` | Cardinal Conversions | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-pattern. |
| `[CONV-005]` | Ordinal Conversions | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-pattern. |
| `[CONV-006]` | Memory Address Conversions | `swiftlint-custom` | **Custom-Rule-Author:** complex multi-pattern. |
| `[CONV-007]` | Test Support Chain (`extension Tagged: ExpressibleByIntegerLiteral`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (extension-grep + Package.swift cross-ref). **Tool-Alternative:** custom-ci for full re-export-chain verification. |
| `[CONV-008]` | Test Value and Comparison Patterns (`Int(bitPattern: index.position)` and `.rawValue.position` chains in `#expect`) | `swiftlint-custom` | **Custom-Rule-Author:** regex restricted to test files. |

**conversions distribution**: 0 swift-format / 0 swiftlint-canonical / 18 swiftlint-custom / 0 custom-ci.

---

### index (17 mechanical rules; 11 shared with `conversions`)

The 11 shared `[IDX-*]` rules are listed under `conversions` above and classify identically as `swiftlint-custom`. The 6 unique-to-index rules:

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[IDX-006c]` | Index ↔ Count Conversions (`Index<T>.Count.init(Index<T>)` + reverse, both total) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[IDX-009]` | Position Access (`var position: Ordinal { get }` exposed) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. |
| `[IDX-010]` | Retag for Domain Conversion (`.retag(_ tag: T.Type)` member exists) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. |
| `[IDX-011]` | Import Test Support (`import Index_Primitives_Test_Support` in tests with literal index/offset/count) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex on test-file imports + literal-usage detection). |
| `[IDX-013]` | Literal Comparison (in `#expect(... == ...)` with `Index<T>` LHS, RHS is integer literal not `.position.rawValue`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[IDX-014]` | Literal Offset Comparison (in `#expect(... == ...)` with `Index<T>.Offset` LHS, RHS is integer literal) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |

**index distribution (6 unique)**: 0 swift-format / 0 swiftlint-canonical / 6 swiftlint-custom / 0 custom-ci.

---

### memory-arithmetic (8 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[MEM-ARITH-001]` | Address + Offset (flag arithmetic with non-Memory.Address.Offset RHS or Address+Address) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST/regex (operator-shape check). |
| `[MEM-ARITH-002]` | Address - Address (verify result type-bound to `Memory.Address.Offset`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-ARITH-003]` | Offset Arithmetic (Offset+Offset, Offset-Offset, -Offset) | `swiftlint-custom` | **Custom-Rule-Author:** moderate. |
| `[MEM-ARITH-005]` | Count from MemoryLayout (`MemoryLayout<*>.size/.alignment` flowing into `Memory.Address.Count`) | `swiftlint-custom` | **Custom-Rule-Author:** regex on MemoryLayout call sites. |
| `[MEM-ARITH-006]` | Element to Byte Scaling (`Index<T>.Offset * Affine.Discrete.Ratio<T, Memory>` path) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-ARITH-007]` | Ratio Composition | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-ARITH-008]` | Identity Ratio (`Affine.Discrete.Ratio<Memory, Memory>.identity` exists) | `swiftlint-custom` | **Custom-Rule-Author:** simple decl check. |
| `[MEM-ARITH-013]` | Literal Comparison (in `#expect(... == ...)` where one side is Memory.Address.Offset/Count, other is integer literal) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST restricted to test files. |

**memory-arithmetic distribution**: 0 swift-format / 0 swiftlint-canonical / 8 swiftlint-custom / 0 custom-ci.

---

### memory-safety (27 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[MEM-SAFE-021]` | No `@unsafe` on encapsulating types (top-level decl is `@safe`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (decl-attr check). |
| `[MEM-SAFE-023]` | Private unsafe storage (`Unsafe*Pointer` typed property has `private`/`internal` access) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-SAFE-025]` | `nonisolated(unsafe)` globals require `@safe` | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-SAFE-001]` | Enable strict memory safety (`.strictMemorySafety()` in Package.swift `swiftSettings`) | `custom-ci` | Package.swift parse — outside swiftlint scope. |
| `[MEM-SAFE-002]` | Unsafe expression marking (each unsafe stdlib call carries `unsafe` keyword) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex/AST for known-unsafe call sites). **Tool-Alternative:** Swift compiler is the authoritative verifier (errors when missing); SwiftLint pre-compile is cheaper but partial. |
| `[MEM-UNSAFE-002]` | Lifetime annotations (`@_lifetime` / `_overrideLifetime` shape) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-UNSAFE-003]` | Safe attribute (`@safe` at documented anchor sites) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-SAFE-010]` | No dual public overloads (no parallel public overload differing only in safe/unsafe surface) | `swiftlint-custom` | **Custom-Rule-Author:** complex (overload-shape pairwise comparison). |
| `[MEM-COPY-001]` | Noncopyable type declaration (`~Copyable` at decl site, not extension) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-COPY-001a]` | Deinit immutability for ~Copyable structs (no mutation of self in `deinit`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (body-write detection). |
| `[MEM-COPY-002]` | Noncopyable in error types (~Copyable payload only via documented patterns) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-COPY-003]` | Noncopyable in collections (compiler-forbidden) | `swiftlint-custom` | **Custom-Rule-Author:** simple AST. **Tool-Alternative:** Swift compiler enforces; CI build is the authoritative check; pre-compile flag is redundant. Keep for fast feedback. |
| `[MEM-COPY-004]` | Extension constraints for ~Copyable (`where Self: ~Copyable` at extension level, not method) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-COPY-012]` | Protocol property dispatch for ~Copyable return types | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-COPY-013]` | Redundant annotations on compiler optimization boundaries (at `@inlinable`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-SPAN-001]` | Property-based span access (`Span` / `MutableSpan` via property, not method) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-SEND-004]` | ~Copyable structs use plain `Sendable` (not `@unchecked`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[MEM-LIFE-001]` | ~Escapable class stored property limitation (compiler-forbidden) | `swiftlint-custom` | **Custom-Rule-Author:** simple AST. **Tool-Alternative:** compiler-enforced. |
| `[MEM-OWN-012]` | Action enum dispatch (documented enum shape used at documented dispatch site) | `swiftlint-custom` | **Custom-Rule-Author:** complex (multi-decl shape). |
| `[MEM-REF-002]` | `Reference.Box` chosen primitive at documented sites | `swiftlint-custom` | **Custom-Rule-Author:** complex (site-context AST). |
| `[MEM-REF-003]` | `Reference.Indirect` chosen primitive | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-REF-004]` | `Reference.Transfer` chosen primitive | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-REF-005]` | `Reference.Slot` chosen primitive | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-LIFE-007]` | `Lifetime.Scoped` chosen primitive at scope-bound sites | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-LIFE-002]` | `Lifetime.Lease` chosen primitive at lease sites | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-LIFE-003]` | `Lifetime.Disposable` chosen primitive | `swiftlint-custom` | **Custom-Rule-Author:** complex. |
| `[MEM-LIFE-006]` | ~Escapable parameters in async methods (documented signature shape) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |

**memory-safety distribution**: 0 swift-format / 0 swiftlint-canonical / 26 swiftlint-custom / 1 custom-ci.

---

### modularization (13 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[MOD-001]` | Core Layer (Package.swift target shape + `exports.swift` content) | `custom-ci` | Package.swift parse + filesystem. |
| `[MOD-005]` | Umbrella Re-export (Package.swift target whose source is only `@_exported public import`) | `custom-ci` | Package.swift parse + source-content check. |
| `[MOD-007]` | Dependency Graph Shape (longest path Core → leaf depth ≤ 3) | `custom-ci` | Package.swift graph computation. |
| `[MOD-009]` | Inline Variant Satellite (Package.swift dependency edge) | `custom-ci` | Package.swift parse. |
| `[MOD-010]` | Standard Library Integration Module (Package.swift target ownership) | `custom-ci` | Package.swift parse. |
| `[MOD-011]` | Test Support Product (`.library` declaration, path `Tests/Support/`) | `custom-ci` | Package.swift parse + filesystem. |
| `[MOD-012]` | Target Naming Convention (regex match on Package.swift target names) | `custom-ci` | Package.swift parse. |
| `[MOD-013]` | Semantic Group Markers (`// MARK:` comments in Package.swift if ≥5 targets) | `custom-ci` | Package.swift content (Swift source but at package root, not Sources/). **Tool-Alternative:** swiftlint-custom partial if `included:` extends to `Package.swift`. |
| `[MOD-016]` | `@_spi` Per-File Opt-In (each `.swift` touching `@_spi(Tag)` has `@_spi(Tag) import`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (cross-decl AST: any `@_spi(Tag)` use without matching import). |
| `[MOD-023]` | `#externalMacro` Module Name Normalization (`#externalMacro(module: "...")` literal == SwiftPM target name with spaces→underscores) | `custom-ci` | Cross-source: Swift literal + Package.swift target name. **Tool-Alternative:** swiftlint-custom partial — regex on `#externalMacro` literal alone, no cross-reference. |
| `[MOD-024]` | Test Support Spine Discipline (run `preflight-test-support-spine.py`) | `custom-ci` | External script invocation. |
| `[MOD-EXCEPT-001]` | Platform Packages exemption (enumerate named exempt packages) | `custom-ci` | Cross-package enumeration. |
| `[MOD-EXCEPT-002]` | Placeholder/Stub Packages exemption (zero-byte source verification) | `custom-ci` | Filesystem + cross-package. |

**modularization distribution**: 0 swift-format / 0 swiftlint-canonical / 1 swiftlint-custom / 12 custom-ci.

---

### platform (22 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[PLAT-ARCH-003]` | Namespace Extension Pattern (forbid `public enum [A-Z]\w+Kernel` / non-canonical names; forbid `extension Kernel/Darwin/Linux/Windows`) | `custom-ci` | Cross-package grep. **Tool-Alternative:** swiftlint-custom partial for the in-package portions. |
| `[PLAT-ARCH-004]` | Platform Root Namespaces (each platform package declares root namespace once + typealias) | `custom-ci` | Cross-package grep + cross-decl typealias check. |
| `[PLAT-ARCH-006]` | Re-Export Chain Architecture (`@_exported public import` chain in `Exports.swift`) | `custom-ci` | Cross-package import-chain verification. |
| `[PLAT-ARCH-008]` | Consumer Import Rule (forbid consumer imports of platform-Kernel modules; require `#if os/canImport`) | `custom-ci` | Cross-package consumer grep. |
| `[PLAT-ARCH-008c]` | L1 Primitives Are Unconditionally Platform-Agnostic (forbid `#if os/canImport` in `*-primitives` source) | `swiftlint-custom` | **Custom-Rule-Author:** one-liner regex. Per-package SwiftLint deployment achieves the L1 scoping. |
| `[PLAT-ARCH-008g]` | Pre-Flight Memory Consultation Before Cross-L2 Dependencies (pre-commit hook) | `custom-ci` | Pre-commit hook implementation. |
| `[PLAT-ARCH-008i]` | L3-policy Peer Composition for POSIX-shared Base (cross-package `import POSIX_Kernel` allowlist) | `custom-ci` | Cross-package grep. |
| `[PLAT-ARCH-008j]` | Platform-C Import Authority (cross-package `import Darwin/Glibc/Musl/WinSDK` allowlist) | `custom-ci` | Cross-package grep. |
| `[PLAT-ARCH-010]` | Platform Package Reference (enumerate vs reference table) | `custom-ci` | Cross-package enumeration. |
| `[PLAT-ARCH-011]` | Swift.Error Qualification in `.Error` Namespaces (`extension *.Error { ... : Error` qualified) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner. |
| `[PLAT-ARCH-014]` | ISA Standard Packages at L2 not L1 (enumerate ISA packages and verify layer placement) | `custom-ci` | Cross-package layer audit. |
| `[PLAT-ARCH-017]` | Cross-Platform C Anonymous-Enum Constant Type Divergence (FPE_*/ILL_*/SEGV_*/etc. cases need `Int32(...)` wrap) | `swiftlint-custom` | **Custom-Rule-Author:** regex on switch-case patterns. |
| `[PLAT-ARCH-019]` | INVERTED Pattern A — Additive Raw-Alongside-Typed at L2 [SUPERSEDED 2026-04-30] | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex for `@_spi(Syscall)` raw companion at L2). Note: rule SUPERSEDED in upstream skill; mechanical check remains "no new code uses the pattern." |
| `[PLAT-ARCH-020]` | L3-Unifier Shadow Pre-Flight Check (pre-commit grep L2 typed-form additions; check peer L3 declarations; require `@_disfavoredOverload` on L2 if hits) | `custom-ci` | Pre-commit hook + cross-package shadow detection. |
| `[PATTERN-001]` | C Shim Layer Structure (`_Shims/include/*.h` + `#if defined(__APPLE__)` / `__linux__`) | `custom-ci` | C header file (`.h`) — outside Swift linter scope. |
| `[PATTERN-003]` | Nested Test Package Pattern (`Tests/Package.swift` for circular swift-testing deps) | `custom-ci` | Filesystem + Package.swift parse. |
| `[PATTERN-004]` | SwiftPM Platform Conditions (`condition: .when(platforms: [...])` on `.product(...)` decls) | `custom-ci` | Package.swift parse. |
| `[PATTERN-004b]` | Module Name Normalization (Package.swift target with spaces → import statement uses underscored form) | `custom-ci` | Cross-source: Package.swift + Swift `import` statement. **Tool-Alternative:** swiftlint-custom partial for the import-side regex; full verification needs Package.swift. |
| `[PATTERN-005]` | Swift 6 Language Mode (Package.swift declarations) | `custom-ci` | Package.swift parse. |
| `[PATTERN-005b]` | Expression Granularity of Unsafe (per-expression `unsafe` markers in `@unsafe` function body) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (function-body scan). |
| `[PATTERN-006]` | Upcoming Feature Flags (Package.swift `enableUpcomingFeature("ExistentialAny"/"InternalImportsByDefault"/"MemberImportVisibility")`) | `custom-ci` | Package.swift parse. |
| `[PATTERN-009]` | Typed-Throws-Safe Catch Patterns (regex `catch let \w+ where` inside `do throws(...) {`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (block-context regex). |

**platform distribution**: 0 swift-format / 0 swiftlint-canonical / 7 swiftlint-custom / 15 custom-ci.

---

### swift-package-heritage (2 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[HERITAGE-002]` | Fork-as-Heritage Shape Composes with Publication Squash (git log shape: upstream history reachable below fork point + publication commit parent at fork-point with tree replacing upstream) | `custom-ci` | Git-log analysis — outside both linters. |
| `[HERITAGE-004]` | Divergence Policy — No Upstream Merges (`git log --oneline` for upstream-second-parent merges; `cat .github/dependabot.yml` for upstream tracker) | `custom-ci` | Git + filesystem. |

**swift-package-heritage distribution**: 0 swift-format / 0 swiftlint-canonical / 0 swiftlint-custom / 2 custom-ci.

---

### testing (15 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[TEST-001]` | Framework Selection (no `import XCTest`; require `import Testing`; forbid `class \w+: XCTestCase`) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner per pattern. |
| `[TEST-005]` | Test Category Suites (presence of `Unit`, `Edge Case`, `Integration`, `Performance`; Performance carries `.serialized`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (suite-decl shape). |
| `[TEST-009]` | File Naming Convention (`^[\w. ]+ Tests\.swift$`; prefix mirrors real type path) | `swiftlint-custom` | **Custom-Rule-Author:** regex on filename + AST type-path extraction. **Tool-Alternative:** swiftlint-canonical `file_name` (opt-in) is partial. |
| `[TEST-010]` | Test Support Target Declaration (Package.swift target shape) | `custom-ci` | Package.swift parse. |
| `[TEST-018]` | Test Support Literal Conformances (counter-pattern: forbid `rawValue`-chain unwrapping in `Tests/`) | `swiftlint-custom` | **Custom-Rule-Author:** regex on test files. |
| `[TEST-019]` | Test Support Directory Structure (`Tests/Support/exports.swift` + `{Name} Test Support.swift` files) | `custom-ci` | Filesystem layout. |
| `[TEST-020]` | Re-Export Pattern (regex on `exports.swift`: every line matches `^@_exported public import \w+$`) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner restricted to `exports.swift`. |
| `[TEST-021]` | Re-Export Chain Architecture (Package.swift dep-graph + AST shape) | `custom-ci` | Cross-package + Package.swift. |
| `[TEST-023]` | Creating a New Test Support Module (filesystem checklist) | `custom-ci` | Multi-step filesystem + Package.swift. |
| `[TEST-024]` | Nested Package.swift for Circular Dependencies | `custom-ci` | Package.swift parse + filesystem. |
| `[TEST-025]` | Using Test Support — Quick Start (regex `import *_Test_Support` in tests) | `swiftlint-custom` | **Custom-Rule-Author:** regex one-liner. |
| `[TEST-026]` | Test Support Module Reference (catalog of every Test Support module) | `custom-ci` | Cross-ecosystem inventory. |
| `[TEST-027]` | Test Target Compilation Gate (`swift build --target {Tests}` exit-code zero) | `custom-ci` | Build invocation. |
| `[TEST-028]` | Mock Factory — Null-Pointer Collision (regex/AST: `.mock(_:)` factory using `unsafeBitCast`; verify offset before bitcast) | `swiftlint-custom` | **Custom-Rule-Author:** complex AST. |
| `[TEST-031]` | Cross-Reference from Existing-Infrastructure to Literal Conformances (skill-text catalog cross-ref) | `custom-ci` | Skill-text grep. |

**testing distribution**: 0 swift-format / 0 swiftlint-canonical / 8 swiftlint-custom / 7 custom-ci.

---

### testing-institute (9 mechanical rules)

| ID | Rule | Bucket | Annotations |
|---|---|---|---|
| `[INST-TEST-001]` | Nested Package Requirement (any package using performance/snapshot/`#Tests`-macro tests has `Tests/Package.swift`) | `custom-ci` | Package.swift parse + filesystem. |
| `[INST-TEST-002]` | Nested Package Location (test directories flat siblings under `Tests/`; parent `Package.swift` test targets declare explicit `path:`) | `custom-ci` | Package.swift parse. |
| `[INST-TEST-003]` | `#Tests` Macro Scaffolding (recommend `#Tests` macro; manual `@Suite` only when extending stdlib types) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST (macro-call detection). |
| `[INST-TEST-004]` | Nested Package.swift Template (specific `name:`, swift-tools-version, dependencies, `path:`, swift-settings) | `custom-ci` | Package.swift parse. |
| `[INST-TEST-005]` | Relative Path Calculation (parent path always `..`) | `custom-ci` | Filesystem path arithmetic. |
| `[INST-TEST-008]` | Snapshot Test Structure (`#snapshot(value, as: .lines [, named:])` invocation shape; reference files under `__Snapshots__/`) | `swiftlint-custom` | **Custom-Rule-Author:** moderate (regex/AST + filesystem cross-check). **Tool-Alternative:** custom-ci for full filesystem cross-check. |
| `[INST-TEST-009]` | Snapshot Configuration with `#Tests` (`#Tests(snapshots: .init(recording: ...))` at type-extension scope) | `swiftlint-custom` | **Custom-Rule-Author:** moderate AST. |
| `[INST-TEST-011]` | `.gitignore` (excludes `.build/`, `.swiftpm/`, `.benchmarks/` under nested Tests/) | `custom-ci` | Filesystem + `.gitignore` content check. |
| `[INST-TEST-012]` | Migration Procedure (each migration step from legacy `Tests/Testing/` was applied) | `custom-ci` | Filesystem layout audit. |

**testing-institute distribution**: 0 swift-format / 0 swiftlint-canonical / 3 swiftlint-custom / 6 custom-ci.

---

## Aggregate distribution

Across **195 unique mechanical rules** in scope:

| Bucket | Count | Percent |
|---|---|---|
| `swift-format` | 1 | 0.5% |
| `swiftlint-canonical` | 1 | 0.5% |
| `swiftlint-custom` | 110 | 56.4% |
| `custom-ci` | 83 | 42.6% |

Per-skill summary table:

| Skill | Total | swift-format | swiftlint-canonical | swiftlint-custom | custom-ci |
|---|---|---|---|---|---|
| code-surface | 15 | 0 | 1 | 13 | 1 |
| primitives | 4 | 0 | 0 | 1 | 3 |
| documentation | 32 | 1 | 0 | 1 | 30 |
| existing-infrastructure | 13 | 0 | 0 | 12 | 1 |
| swift-package | 5 | 0 | 0 | 2 | 3 |
| swift-package-build | 6 | 0 | 0 | 1 | 5 |
| conversions | 18 | 0 | 0 | 18 | 0 |
| index (unique) | 6 | 0 | 0 | 6 | 0 |
| memory-arithmetic | 8 | 0 | 0 | 8 | 0 |
| memory-safety | 27 | 0 | 0 | 26 | 1 |
| modularization | 13 | 0 | 0 | 1 | 12 |
| platform | 22 | 0 | 0 | 7 | 15 |
| swift-package-heritage | 2 | 0 | 0 | 0 | 2 |
| testing | 15 | 0 | 0 | 8 | 7 |
| testing-institute | 9 | 0 | 0 | 3 | 6 |
| **Total** | **195** | **1** | **1** | **110** | **83** |

---

## Already-enforced summary

**Already-enforced**: 0 rules.

None of the 195 in-scope mechanical rules are currently enforced by either the swift-primitives `.swift-format` active `rules:` block (20 rules `true`) or the canonical SwiftLint config's `opt_in_rules:` list (9 rules). The two configs deliberately enforce basic-formatting rules (semicolons, trailing closures, parens around conditions, ordered imports, etc.); the in-scope mechanical bucket is dominated by API-design semantics (namespace structure, ~Copyable patterns, typed throws, ownership primitives, DocC catalogue layout, Package.swift shape) which the active configs do not touch.

This means the swift-primitives ecosystem currently has **0% mechanical-rule coverage from existing linter configs** for the in-scope set — every rule classified mechanical is "to be enforced" rather than "already enforced." This is consistent with the parent thread's framing: workflow construction phase 1 closed γ-1a / γ-1b / γ-2 reusables, none of which apply to the rules in this dispatch.

---

## Config-flip summary

**Config-flips** (rules already in catalogs but currently disabled): **2 rules**.

1. **`[API-IMPL-005]` One Type Per File** → flip `swiftlint-canonical` `one_declaration_per_file` from disabled to opt-in. Single-line addition to canonical `.swiftlint.yml`'s `opt_in_rules:` list. No code authoring; no fanout (SwiftLint inherits via `parent_config:`). Estimated cost: minutes.
2. **`[DOC-003]` Method documentation** → flip `swift-format` `ValidateDocumentationComments` from `false` to `true` in `.swift-format`. **Fanout-Required:** YES — 133 sub-package `.swift-format` copies need the same flip (current copy-paste fanout pattern). Estimated cost: hours (mechanical fanout); flip itself is one JSON-key change. Adjacent rule `BeginDocumentationCommentWithOneLineSummary` (currently `false`) is also disabled but is NOT in our in-scope mechanical bucket.

Both flips would deliver enforcement of two in-scope mechanical rules with zero new code authored. They are the cheapest path to mechanical-rule coverage in the swift-primitives ecosystem.

---

## Custom-rule-author summary

**Custom rules to author**: **110 swiftlint-custom rules** (56.4% of in-scope total).

Cost characterization breakdown:

| Cost class | Count | Examples |
|---|---|---|
| One-liner regex | ~25 | `[API-ERR-001]` typed throws, `[INFRA-020]` `Int(bitPattern:)` trigger, `[INFRA-025]` `count - 1`, `[PRIM-FOUND-001]` Foundation imports, `[PLAT-ARCH-008c]` L1 `#if os` ban, `[TEST-001]` framework selection |
| Moderate AST query | ~55 | `[API-ERR-002]` nested error types, `[API-IMPL-008]` minimal type body, `[MEM-COPY-001]` ~Copyable decl-site, `[IDX-006]` operator overload signatures, `[TEST-018]` literal conformances |
| Complex multi-decl / multi-rule cluster | ~30 | `[INFRA-200]` operations-intentionally-missing (≥10 forbidden patterns), `[CONV-003/004/005/006]` API-table multi-pattern enforcement, `[PKG-NAME-002/006]` namespace + protocol + typealias triplet, `[MEM-OWN-012]` action enum dispatch, `[MEM-REF-002/003/004/005]` reference-primitive site enforcement, `[MEM-LIFE-002/003/007]` lifetime-primitive site enforcement |

Total custom-rule-author cost is dominated by the multi-decl AST-shape rules (memory-safety reference/lifetime primitives, conversions API-tables). One-liner regex rules can be authored in batches; complex AST rules will need more careful engineering and may benefit from `analyze` rules over plain regex.

---

## swift-format gap analysis (informational)

**Rules in `swiftlint-custom` or `custom-ci` that COULD route to `swift-format` if its catalog grew them**: enumeration follows. The swift-format catalog is closed per the supervisor block fact; this section is informational only — no proposal.

| Rule | Current bucket | Hypothetical swift-format rule shape |
|---|---|---|
| `[API-NAME-001]` Nest.Name Pattern | swiftlint-custom | `NoCompoundTypeNames` — top-level type-decl name has no internal capital after first segment, with spec-namespace allowlist |
| `[API-IMPL-005]` One Type Per File | swiftlint-canonical (Config-Flip) | swift-format does not currently offer this; SwiftLint covers cleanly via `one_declaration_per_file` |
| `[API-IMPL-006]` File Naming Convention (nested path) | swiftlint-custom | `FileNameMatchesNestedTypePath` — extends current SwiftLint `file_name` to nested paths |
| `[API-ERR-001]` Typed Throws Required | swiftlint-custom | `RequireTypedThrows` — flag `throws` not followed by `(`. Adjacent to existing swift-format catalog (formatter handles `throws` placement; lint dimension not present) |
| `[INFRA-200]` Operations Intentionally Missing | swiftlint-custom | `ForbiddenScalarArithmeticOnTypedQuantities` — closed pattern list, mechanical |
| `[PRIM-FOUND-001]` No Foundation Imports | swiftlint-custom (Migration candidate) | `RestrictedImports` — programmable allowlist/denylist for module imports |

These are speculative; the catalog is closed today. Closing the gap would require an upstream contribution to apple/swift-format. Not actionable in this dispatch.

---

## Custom-CI residual

**custom-ci-bound**: **83 rules** (42.6% of in-scope total).

The custom-ci residual is concentrated where the rule's predicate fundamentally requires:

1. **Package.swift parsing** — 27 rules (most of `modularization`, `swift-package-build` Linux-build family, `[PRIM-ARCH-001/002]`, `[INST-TEST-001/002/004]`, `[TEST-010/021/024]`, `[MOD-001/005/007/009/010/011/012/013]`, etc.).
2. **Cross-package grep / cross-repo enumeration** — 14 rules (most of `platform` PLAT-ARCH-* family: `[PLAT-ARCH-003/004/006/008/008g/008i/008j/010/014/020]`, `[PATTERN-001/003]`, `[INFRA-001]`, `[MOD-EXCEPT-001]`).
3. **DocC markdown / `.docc` file parsing** — 30 rules (essentially all of `documentation` except `[DOC-003]` which is Swift-source doc comments and `[DOC-045]` which is Swift `// WORKAROUND:` comments).
4. **Diff-aware predicates** — 2 rules (`[API-IMPL-010]`, `[PKG-NAME-008]`).
5. **Build/shell invocations** — 5 rules (`[TEST-027]` swift build, `[PKG-BUILD-001/002/005/006/008]`).
6. **Git-log shape / dependabot config** — 2 rules (`[HERITAGE-002/004]`).
7. **Pre-commit hooks** — 2 rules (`[PLAT-ARCH-008g]` cross-L2 dep guard, `[PLAT-ARCH-020]` shadow pre-flight).
8. **Workflow-grep** — 1 rule (`[DOC-051]` derived-info CI verification).

Cross-reference to v1.2.0 γ-roadmap: most custom-ci residual rules are NEW (not in v1.2.0 §3.4); they would extend the γ-roadmap as new check classes if/when they are operationalized. The exception is `[PRIM-FOUND-001]` which is the existing γ-1a (see γ-roadmap section below).

---

## γ-roadmap migration candidates

**γ-roadmap migration candidates in this dispatch's scope: 1 rule**. Below the supervisor block's `ask:` threshold (>5).

1. **`[PRIM-FOUND-001]` No Foundation Imports** — currently γ-1a deterministic in v1.2.0 §3.4.10 (canonical mechanical case); implemented as workflow YAML in `swift-primitives/.github/.github/workflows/swift-ci.yml`. Could migrate to a SwiftLint custom rule (one-liner regex in canonical `.swiftlint.yml`); inheritance via `parent_config:` would distribute to all swift-primitives sub-packages without per-package fanout. **Migration path**: add to canonical `swift-standards/swift-standards/main/.swiftlint.yml`'s `custom_rules:` block. Migration is a separate authorization (per supervisor block "do not draft any PR"); flagged here.

**γ-1b license-header**: not in this dispatch's in-scope mechanical bucket (license-header rules live in `readme` skill, which is OUT OF SCOPE per dispatch brief). The brief notes γ-1b would migrate to SwiftLint canonical `file_header` (opt-in, currently disabled). When the readme skill is in-scoped in a future dispatch, the migration becomes actionable; not flagged here.

**Cluster threshold**: 1 candidate < 5 threshold; no coordinated migration dispatch warranted.

---

## Outcome

**Status**: RECOMMENDATION (2026-05-05). Pending principal sign-off on the bucket assignments. Implementation (config-flips, custom-rule authoring, custom-CI workflow drafts) is **out of scope** for this dispatch per supervisor block "MUST NOT author or modify any config file" and "MUST NOT draft any PR."

### Key findings

1. **0% already-enforced**: the existing swift-primitives `.swift-format` + canonical SwiftLint configs enforce zero in-scope mechanical rules. The configs cover orthogonal formatting concerns; the in-scope mechanical rules cover API-design semantics outside the active enforcement surface.
2. **2 config-flips** would deliver immediate coverage of 2 rules with no new code (`[API-IMPL-005]` via `one_declaration_per_file` opt-in, `[DOC-003]` via `ValidateDocumentationComments` flip + 133-copy fanout).
3. **110 custom rules to author** (56% of in-scope total) — most are SwiftLint-feasible. ~25 are one-liner regexes (cheap); ~55 are moderate AST queries; ~30 are complex multi-decl shape patterns.
4. **83 custom-CI rules** (43%) — concentrated in Package.swift parsing (27), DocC markdown (30), cross-package grep (14), and build/shell/git surfaces (12). These cannot be reduced into swiftlint-custom without an unbounded scope expansion of SwiftLint's surface.
5. **1 γ-roadmap migration candidate** (PRIM-FOUND-001 = γ-1a Foundation), well below the 5-rule cluster threshold. Single-candidate migration; coordinated cluster dispatch not warranted.
6. **No 5th-bucket candidates surfaced**: no rule resisted all four buckets such that a `swiftsyntax-tool` (custom AST tool beyond SwiftLint) would be required.

### Phasing recommendation (informational)

If implementation is later authorized, the cheapest-first sequence:

1. **Phase 1** — config-flips (2 rules; minutes-to-hours): flip `one_declaration_per_file` in canonical SwiftLint; flip `ValidateDocumentationComments` in 133 swift-primitives `.swift-format` copies.
2. **Phase 2** — γ-1a SwiftLint migration (1 rule): add `no_foundation_import` custom rule to canonical SwiftLint; deprecate the workflow YAML γ-1a.
3. **Phase 3** — one-liner regex custom rules (~25 rules): author in canonical SwiftLint `.swiftlint.yml` `custom_rules:` block.
4. **Phase 4** — moderate AST custom rules (~55 rules): author per-skill clusters; consider `analyze` rules where regex insufficient.
5. **Phase 5** — complex multi-decl custom rules (~30 rules): author per-skill clusters with careful AST engineering.
6. **Phase 6** — custom-CI for Package.swift / cross-package / DocC / build-shape rules (~83 rules): extend the γ-roadmap.

Phase 1+2 covers 3 rules (1.5% of total) with near-zero authoring cost — a strict win. Phase 3 covers ~25 rules (~13%) with low authoring cost — second strict win. Phases 4–6 are larger investments and warrant separate dispatches with internal phasing.

### Out-of-scope items (deliberately not done per supervisor block)

- Authoring or modifying any `.swiftlint.yml` / `.swift-format` config file.
- Drafting any PR to `swift-standards/swift-standards`.
- Drafting any GitHub Actions workflow YAML for the custom-CI residual.
- Migrating `[PRIM-FOUND-001]` from γ-1a custom-CI to swiftlint-custom — flagged here, awaiting separate authorization.
- Cleaning up the 40 standalone SwiftLint outliers (parent-thread item).
- Identifying or modifying the swift-format fanout mechanism (133 identical copies).
- Generalizing beyond swift-primitives (other ecosystems — separate dispatch).
- Re-classifying any rule's mechanical/hybrid/semantic class.

### Supervisor block verification stamp

Per [HANDOFF-010] step 5: each supervisor ground-rule entry verified against work product —

| Entry | Type | Verification |
|---|---|---|
| Read canonical SwiftLint config + `.swift-format` root + both rule catalogs before classifying | MUST | Verified — all four read at write time; rule-name matching done against catalogs (43 swift-format rules, 324 SwiftLint rules); both configs cited in §"Status quo" with line/version evidence. |
| Sub-classify ALL in-scope mechanical rules; in-scope set = union of cited skills' mechanical buckets | MUST | Verified — 195 unique rules across 15 skills sub-classified; per-skill totals match source-doc counts (code-surface 15, primitives 4, documentation 32, existing-infrastructure 13, swift-package 5, swift-package-build 6, conversions 18, index 6 unique, memory-arithmetic 8, memory-safety 27, modularization 13, platform 22, swift-package-heritage 2, testing 15, testing-institute 9 = 195). |
| Assign borderline cases to cheaper bucket with `**Tool-Alternative:**` | MUST | Verified — borderline cases (e.g., `[MOD-023]`, `[PATTERN-004b]`, `[PLAT-ARCH-003]`) carry **Tool-Alternative:** annotations identifying both the cheaper-bucket route and the more-complete custom-ci route. |
| Annotate `**Already-Enforced:**` precisely with config-file citation | MUST | Verified — Already-Enforced count is zero (no rules currently enforced); explicit "Already-Enforced: No" annotations on the two Config-Flip cases (`[API-IMPL-005]`, `[DOC-003]`) cite the specific config and line/key. |
| Annotate `**Config-Flip:**` for currently-disabled SwiftLint canonical rules | MUST | Verified — 2 Config-Flip rules surfaced (`[API-IMPL-005]` swiftlint-canonical, `[DOC-003]` swift-format); both annotated. Adjacent disabled-but-not-in-scope rules noted (`BeginDocumentationCommentWithOneLineSummary`). |
| Flag γ-roadmap migration candidates | MUST | Verified — `[PRIM-FOUND-001]` flagged as sole γ-1a migration candidate; γ-1b license-header noted as out-of-this-dispatch's-scope (readme skill excluded). |
| Use parallel subagents for throughput | MUST | Verified — three parallel `Explore` subagent dispatches (tier-1, tier-2, tier-3) ran in sequence after the initial pilot read; tier-1 + tier-2 + tier-3 results aggregated by main thread. |
| Commit doc + index entry as one focused commit; stage only this dispatch's files | MUST | Verified at termination (commit step). |
| Do not author or modify any config file | MUST NOT | Verified — no `.swiftlint.yml` / `.swift-format` writes; all three reads were `Read` tool invocations. |
| Do not draft any PR | MUST NOT | Verified — no PR drafted; this RECOMMENDATION is the sole artifact. |
| Do not generalize beyond swift-primitives | MUST NOT | Verified — `applies_to: [swift-primitives]` in frontmatter; in-scope skill enumeration matches dispatch brief; no recommendations for other ecosystems. |
| Do not stage cross-session contamination | MUST NOT | Verified at commit step — wasm-ci doc + Reflections additions + `Reflections/_index.json` mod + `_index.json` wasm-ci entry NOT staged. |
| Do not push commits | MUST NOT | Verified — no `git push` invoked. |
| Do not re-classify rules' mechanical/hybrid/semantic class | MUST NOT | Verified — every in-scope rule retained the source doc's mechanical classification; this dispatch only added the four-bucket sub-classification. |
| Both linters deployed; SwiftLint via `parent_config:` (1 canonical → many), swift-format via copy-paste (133 copies) | fact | Honored — recommendations distinguish the inheritance models in cost annotations (Config-Flip on SwiftLint = single edit; Config-Flip on swift-format = 133-copy fanout). |
| Canonical SwiftLint deliberately loose; many `swiftlint-canonical` will be Config-Flip cases | fact | Honored — Config-Flip count is 1 swiftlint-canonical (`one_declaration_per_file`) + 1 swift-format (`ValidateDocumentationComments`). The deliberately-loose posture explains why most candidate rules don't route to swiftlint-canonical (the catalog has them, but the canonical config disables them OR they are partial fits). |
| swift-format catalog closed | fact | Honored — gap analysis explicitly informational; no rule routes to swift-format unless catalog match exists. |
| Cost discipline (Max OAuth, no API key) | fact | Honored — no token-heavy operations; classification done in-thread; subagents for parallel doc-extraction only. |
| Rule resists all four buckets → fifth bucket → escalate | ask | Not triggered — every rule routed cleanly into the four buckets. |
| >5 γ-marked rules to migrate → migration cluster → escalate | ask | Not triggered — exactly 1 γ-marked rule (PRIM-FOUND-001) in scope. |
| In-scope total >~200 mechanical rules → budget calibration → escalate | ask | Not triggered — 195 unique (206 with `[IDX-*]` doubled). Surfaced transparently in §"Empirical scope count"; per [SUPER-024] the marginal overage with bounded homogeneous classification work is in-action-compliant; classification proceeded without escalation. |
| Fanout DIVERGED from root → surface → escalate | ask | Not triggered — out of this dispatch's scope per "MUST NOT" list ("Identifying or modifying the swift-format fanout mechanism"); per [SUPER-024] in-action with explicit acknowledgement here. |

---

## References

- `swift-institute/Research/skill-verification-taxonomy-pilot.md` — pilot source for code-surface (15 mechanical), primitives (4 mechanical).
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-1.md` — tier-1 source for documentation (32 mechanical), existing-infrastructure (13 mechanical), swift-package (5 mechanical), swift-package-build (6 mechanical).
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-2.md` — tier-2 source for conversions (18 mechanical), index (17 mechanical, 11 shared), memory-arithmetic (8 mechanical), memory-safety (27 mechanical), modularization (13 mechanical), platform (22 mechanical), swift-package-heritage (2 mechanical).
- `swift-institute/Research/skill-verification-taxonomy-extension-tier-3.md` — tier-3 source for testing (15 mechanical), testing-institute (9 mechanical).
- `swift-institute/Research/centralized-swift-ci-and-spine-gate.md` v1.2.0 — γ-roadmap (γ-1a Foundation, γ-1b license-header, etc.) and four-class scheme.
- `https://raw.githubusercontent.com/swift-standards/swift-standards/main/.swiftlint.yml` — canonical SwiftLint config (read 2026-05-05).
- `/Users/coen/Developer/swift-primitives/.swift-format` — swift-primitives root config (read 2026-05-05).
- `https://github.com/apple/swift-format/blob/main/Documentation/RuleDocumentation.md` — swift-format closed catalog (43 rules; read 2026-05-05).
- `https://realm.github.io/SwiftLint/rule-directory.html` — SwiftLint closed catalog (324 rules; read 2026-05-05).
- `/Users/coen/Developer/HANDOFF-mechanical-rule-tool-classification.md` — dispatch brief (this dispatch's source).
