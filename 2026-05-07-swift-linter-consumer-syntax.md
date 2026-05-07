# swift-linter Consumer Syntax — Configuration and Rule Authoring

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
research_tier: 2
applies_to: [swift-foundations/swift-linter, swift-foundations/swift-linter-rules, swift-primitives/swift-linter-primitives]
normative: false
---
-->

## Context

### Trigger

The swift-linter ecosystem (engine `swift-foundations/swift-linter`, rule
packs `swift-foundations/swift-linter-rules`, primitives
`swift-primitives/swift-linter-primitives`) is **pre-publishable**. The
prior research `swiftsyntax-based-custom-linter-investigation.md` v1.0.0
(2026-05-06) closed the architectural question (Option C standalone
SwiftSyntax CLI, Option F symbol-graph extension) and the package shape
emerged via the architecture-cohort cleanup waves. Two consumer shapes
shipped operationally:

1. **Single-file `Lint.swift`** at consumer package root or `.github/`
   (Tier 2 example: `swift-primitives/.github/Lint.swift`). Evaluated by
   `swift-manifest`'s subprocess loader; declares
   `let manifest: Lint.Manifest = …` at file scope; the driver shim
   JSON-encodes the manifest, the parent linter decodes and reconstructs
   a runtime `Lint.Configuration`.
2. **Nested SwiftPM `Lint/Package.swift` + `Lint/Sources/Lint/main.swift`**
   (PoC at `swift-primitives/swift-tagged-primitives/Lint/`). The nested
   package executable IS the linter binary; links engine + rule packs +
   any consumer-authored custom rule. swift-linter (the central CLI)
   detects this layout and dispatches via
   `swift run --package-path <consumer>/Lint Lint <args>`.

The consumer-facing syntax across both shapes was authored under cohort
deadline pressure and is functional but not necessarily optimal. Once
adopters lock the shape into their `Lint.swift` and `Lint/` directories,
breaking changes incur adopter-side migration effort. This research asks
whether the current syntax is the cleanest possible, or whether
improvements should land before broad adoption.

### Premise correction (per [RES-023] empirical verification)

The dispatching handoff's "Current State" §Lint.Manifest declaration
shape describes the initializer
`Lint.Manifest(enabledRuleIDs:, disabledRuleIDs:, excludedPaths:)` with
String-typed rule IDs — a partial-state description. Empirical state
verified at HEAD of `/Users/coen/Developer/swift-foundations/swift-linter`
and `/Users/coen/Developer/swift-primitives/swift-linter-primitives` on
2026-05-07:

- `Lint.Manifest` (defined at
  `swift-linter/Sources/Linter Core/Lint.Manifest.swift:72-87`)
  uses **typed** `[Lint.Rule.ID]` (where
  `Lint.Rule.ID = Tagged<Lint.Rule, Swift.String>` per
  `swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift`)
  and `[File.Path]` for `excludedPaths`. Construction at consumer call
  sites uses `ExpressibleByStringLiteral` from
  `swift-tagged-primitives`'s standard-library-integration
  (`let id: Lint.Rule.ID = "unchecked_call_site"`). The wire format is
  bare strings; the in-Swift API is typed.
- A second consumer-facing type, **`Lint.Configuration`**, lives at
  `swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.swift`
  (L1, NOT in the engine package). It uses
  `@Array<Lint.Rule.Configuration>.Builder` from
  `Standard_Library_Extensions` for the rules block — declarative,
  control-flow-friendly, no bespoke result-builder. Per-rule entries
  carry the rule's TYPE (`.self` metatype, never a String name) plus
  optional severity override and `Path.Filter`. Recursive parent
  inheritance via `Ownership.Shared<Lint.Configuration>` (heap-indirect
  to break value-type recursion). Factories: `.enable(R.Type, severity:,
  paths:)`, `.disable(R.Type)`, `.override(R.Type, severity:)`.
- The two types **coexist by design**: `Lint.Manifest` is the
  cross-process JSON wire format (single-file path crosses
  swift-manifest's subprocess boundary; in-process recovery at the
  parent linter); `Lint.Configuration` is the in-memory typed runtime
  value the orchestrator's `Lint.Run.run(paths:configuration:)` consumes.

This research therefore asks two distinct questions per surface:

| Question | Single-file path | Nested-package path |
|---|---|---|
| What is the cleanest declaration shape? | Q1a (Manifest) | Q1b (Configuration) |
| Is the cross-shape composition coherent? | Q1c (Manifest ↔ Configuration mapping) | (same) |

The handoff's Q1–Q6 enumeration remains the organizing structure; the
analysis below treats each question with both surfaces in view.

### Why now

Pre-publishable. swift-linter, swift-linter-rules, and
swift-linter-primitives are private at HEAD; one PoC consumer
(swift-tagged-primitives' nested `Lint/`) and one regulated consumer
(`swift-primitives/.github/Lint.swift` Tier 2 file) currently exist. The
window for breaking-change refactors closes when these packages flip
public and adopters write their own `Lint.swift` / `Lint/` shapes.

### Research tier classification (per [RES-020])

| Criterion | Value |
|---|---|
| Scope | cross-package — affects swift-linter + swift-linter-primitives + swift-linter-rules + every consumer that writes a Lint.swift or Lint/ |
| Precedent-setting | Yes — the chosen syntax becomes the public API for adopter ecosystem-wide |
| Semantic commitment | Informal-to-formal — public-API contract once published |
| Cost of error | Medium — wrong syntax forces adopter migration after publication |
| Expected lifetime | Several releases minimum (v1 surface, v2/v3 evolution) |

→ **Tier 2**. Prior Art Survey [RES-021] mandatory; theoretical grounding
[RES-022] light-formalism level; empirical validation [RES-025]
Cognitive Dimensions; citations [RES-026] required.

---

## Question

Six sub-questions enumerated by the dispatch brief, with the corrected
premise above:

| # | Question |
|---|---|
| Q1 | What is the cleanest `Lint.Manifest` / `Lint.Configuration` declaration shape, single-file and nested-package paths? |
| Q2 | What is the cleanest rule-authoring shape (third-party `Lint.Rule.X` types)? |
| Q3 | How should per-rule configuration / parameters (e.g., `compound_identifier`'s allowlist) be expressed? |
| Q4 | How should consumers selectively elevate / lower severity, or exclude specific files / patterns? |
| Q5 | How does the chosen syntax compose with `// parent: <URL>` inheritance across both single-file and nested-package shapes? |
| Q6 | How should diagnostic messages and skill-citation metadata be authored? |

Evaluation criteria common to every option (per [RES-005]):

| Criterion | Definition |
|---|---|
| Call-site cleanliness | How does the consumer's hand-written code READ? Visual density, named parameters, disambiguation cost |
| Compile-time safety | What classes of error are caught at type-check vs runtime? |
| Composability | Parent-chain inheritance, third-party rule packs, per-rule configuration |
| Diagnosability | When the consumer authors incorrectly, are errors localised and actionable? |
| Ecosystem alignment | Adheres to institute typed-system conventions ([API-NAME-*], [API-IMPL-*], [IMPL-INTENT]) and Swift idiom |
| Adopter onboarding | Time-to-first-rule for a new consumer reading no docs |
| Migration cost | Breaking change for the existing PoC + Tier 2 consumers |

---

## Prior Art Survey [RES-021]

Six adjacent systems surveyed concretely. For each: the actual consumer
syntax, what it gets right, what it gets wrong, and what the institute
should learn or avoid.

### SwiftLint custom rules (`.swiftlint.yml` regex form)

```yaml
custom_rules:
  no_foundation_import:
    name: "Foundation import"
    regex: 'import Foundation\b'
    message: "Foundation imports forbidden in primitives layer."
    severity: error
    excluded:
      - "Tests/**"
```

**Right**: declarative; one block per rule; severity inline; per-rule
path filter. Configuration is data, not code — easy to lint the linter.

**Wrong**: regex strings as the rule body. Invariably escapes incorrectly,
fragile against the evasion classes documented in
`swiftsyntax-based-custom-linter-investigation.md`. No type checking on
references between rules. No way to author rules in Swift.

**Institute lesson**: separating CONFIGURATION (yaml-shaped) from RULE
AUTHORING (Swift-shaped) is correct; SwiftLint conflates them at the
custom-rules surface (rules ARE their regex). The institute's typed
`Lint.Configuration` already separates them.

### swift-format `.swift-format` JSON

```json
{
  "version": 1,
  "lineLength": 100,
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": true,
    "AlwaysUseLowerCamelCase": false
  }
}
```

**Right**: rule activation is a flat map of `RuleName: Bool`. Trivial
to inherit (overlay the maps). Versioned via `version: 1`.

**Wrong**: closed catalog. No third-party rules. No per-rule parameters
beyond on/off (severity is global).

**Institute lesson**: a flat enable-map is a Pareto baseline for
inheritance composition; the institute's `Lint.Configuration` matches
this for the plain-enable case while supporting richer per-rule data.

### ESLint plugin packages (JavaScript)

```js
// .eslintrc.json
{
  "plugins": ["@typescript-eslint", "react"],
  "extends": ["plugin:@typescript-eslint/recommended"],
  "rules": {
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }]
  }
}
```

```js
// Custom rule (rule authoring)
module.exports = {
  meta: {
    type: "problem",
    docs: { description: "Disallow foo()", url: "https://..." },
    schema: [{ type: "object", properties: { ignoreList: { type: "array" } } }],
    messages: { fooCalled: "foo() is forbidden, use bar()." }
  },
  create(context) {
    return {
      CallExpression(node) {
        if (node.callee.name === "foo") {
          context.report({ node, messageId: "fooCalled" });
        }
      }
    };
  }
};
```

**Right**: rules ship as `npm` packages. Plugins activated by name.
Per-rule parameters as inline JSON objects. Rich `meta.docs.url` for
traceability. AST visitor pattern.

**Wrong**: stringly-typed rule references in `.eslintrc.json`. The
rule-id-string-collision class of bug ("did you mean
`@typescript-eslint/no-unused-vars` or just `no-unused-vars`?") is
endemic. JSON Schema for parameters is Out-Of-Band — runtime validation
only.

**Institute lesson**: per-rule parameters are an ordinary need, even at
launch (`compound_identifier`'s allowlist already emerged in the dispatch
brief's Q3). Inline-with-activation is the right ergonomic placement.
The string-ID collision cost is fully avoided by the institute's typed
`R.Type` factories — this is the single largest typed-DSL win over
ESLint.

### Rust Clippy + cargo attribute lints

```rust
// Rule activation via Cargo.toml or attributes
#![deny(clippy::pedantic)]
#![allow(clippy::needless_pass_by_value)]
#[allow(clippy::too_many_arguments)]
fn many_args(a: i32, b: i32, /* ... */) {}

// Custom rules: dylint (out-of-tree)
declare_lint! { pub MY_LINT, Warn, "description" }
declare_lint_pass!(MyLint => [MY_LINT]);
impl<'tcx> LateLintPass<'tcx> for MyLint {
    fn check_fn(&mut self, cx: &LateContext<'tcx>, /* ... */) { /* ... */ }
}
```

**Right**: configuration via attributes (per-scope inline) AND Cargo.toml
(global). Three-level severity: `allow` / `warn` / `deny`.

**Wrong**: third-party lint packages (`dylint`) are second-class — the
ecosystem's prior-art survey noted them as "cautionary." Compile-time
plugin loading depends on internal compiler APIs; lints rebuild on every
toolchain upgrade. Rule-namespace collisions ("which `pedantic` group
does this rule belong to?") are operationally painful.

**Institute lesson**: scope-local per-rule overrides (Rust's
`#[allow(clippy::X)]` in source) are something neither the institute's
`.swiftlint.yml` nor `Lint.swift` currently support. Worth considering
as v3 evolution but **out of scope here** — the question is the
manifest/configuration shape, not in-source escape hatches.

### SwiftSyntax test harness

```swift
import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacrosTestSupport
import XCTest

final class MyMacroTests: XCTestCase {
    func test_expansion() {
        assertMacroExpansion(
            """
            @MyMacro
            struct S {}
            """,
            expandedSource: """
            struct S {
                static let foo = 42
            }
            """,
            macros: ["MyMacro": MyMacro.self]
        )
    }
}
```

**Right**: `assertMacroExpansion(...)` registers the macro by name +
metatype as a String-keyed dictionary at the test boundary.

**Wrong**: stringly-keyed name lookup at the test site. Acceptable here
because tests are localised; would be unacceptable at consumer
configuration scale.

**Institute lesson**: the SwiftSyntax pattern of "Visitor walks parse
tree, emits diagnostics, return them" is the right rule shape; current
`Lint.Rule.Protocol` (`func findings(in: Lint.Source.Parsed) ->
[Lint.Finding]`) matches it exactly.

### Institute result-builder ecosystem

```swift
// Standard_Library_Extensions/Array+Builder
extension Array {
    @resultBuilder
    public enum Builder {
        public static func buildExpression(_ element: Element) -> [Element]
        public static func buildBlock(_ components: [Element]...) -> [Element]
        public static func buildOptional(_ component: [Element]?) -> [Element]
        public static func buildEither(first: [Element]) -> [Element]
        public static func buildEither(second: [Element]) -> [Element]
        public static func buildArray(_ components: [[Element]]) -> [Element]
        public static func buildLimitedAvailability(_ component: [Element]) -> [Element]
    }
}

// Consumer site
let xs = [Int].build {
    1
    2
    if condition { 3 }
}
```

**Right**: GENERIC over element type. One result-builder serves every
declarative-array call site. Supports `if`, `for`, `#available`. Already
used by `Lint.Configuration`.

**Wrong**: nothing significant — this is the institute baseline.

**Institute lesson**: `@Array<Element>.Builder` is the canonical
declarative-list shape across the institute. Bespoke result-builders
should not be introduced when this generic suffices.

---

## Analysis

### Q1 — Manifest / Configuration declaration shape

#### Q1a — Single-file `Lint.swift` (subprocess wire format)

The single-file path declares `let manifest: Lint.Manifest = …` at file
scope. The driver shim (generated by swift-manifest) JSON-encodes the
value to a known output path; the parent linter decodes via
`JSON.Serializable` conformance (`Lint.Manifest.serialize` /
`.deserialize`) and reconstructs a runtime `Lint.Configuration`.

JSON is the boundary. Metatypes (`R.Type`) cannot cross JSON; ergo the
manifest's rules are identified by `Lint.Rule.ID` (typed
`Tagged<Lint.Rule, Swift.String>`) which round-trips as bare strings.

##### Options for the single-file shape

| ID | Shape | Example |
|---|---|---|
| **A** (current) | Init-kwargs over typed string-ID arrays | `Lint.Manifest(enabledRuleIDs: ["unchecked_call_site"], disabledRuleIDs: [], excludedPaths: [])` |
| B | Result-builder over enable-entries | `Lint.Manifest { rule("unchecked_call_site"); excluding("Tests/Fixtures") }` |
| C | Type-safe metatype list | (impossible — metatypes don't cross JSON) |
| D | Typed metatype builder + JSON round-trip via ID extraction | (deferred — see Q1c) |

##### Comparison

| Criterion | A: init kwargs (current) | B: result-builder |
|---|---|---|
| Call-site cleanliness | Compact when N rules; deteriorates at >10 entries | Steady at any N; control-flow friendly |
| Compile-time safety | `Lint.Rule.ID` is typed; rule existence is NOT compile-checked (string can typo) | Same — rule existence still string |
| Composability with `// parent:` | Direct — child manifest's enabledRuleIDs / disabledRuleIDs layer atop parent's | Direct |
| Diagnosability | Bad JSON shape → `JSON.Error.typeMismatch`; bad rule ID → silent empty findings | Same |
| Ecosystem alignment | Mirrors `Package.swift`'s `Package(name:dependencies:targets:)` shape — known to every Swift author | Mirrors `Package.swift`'s `targets:` and `dependencies:` block forms — also known |
| Adopter onboarding | Trivial: keyword args over arrays | Slight learning curve over result-builder |
| Migration cost | Zero (already shipped) | Mechanical rewrite of `swift-primitives/.github/Lint.swift` and any other in-flight Lint.swift consumers |

##### Q1a recommendation

**Option A — keep the init-kwargs shape for the single-file path.**
Rationale:

1. The single-file path's purpose is "minimal declaration crossing JSON
   boundary". Init-kwargs with typed string-ID arrays are the minimal
   shape consistent with that purpose. A result-builder DSL adds runtime
   construction machinery and reads no better at the typical `N <= 15`
   rule count.
2. The shape mirrors `Package.swift`'s init-kwargs idiom — every Swift
   developer already knows how to read it.
3. The ID-string typo risk is real but bounded — the linter emits a
   warning when a manifest references an unknown rule ID at run time,
   and the typed `Lint.Rule.ID` (rather than raw `Swift.String`) at
   least segregates the namespace at the type level.

**Refinement**: add a `func validate() throws(Lint.Manifest.Error)`
method to `Lint.Manifest` that checks every `enabledRuleIDs` /
`disabledRuleIDs` entry against the parent linter's known rule registry,
producing a structured error before the run starts. This is a v1
addition with zero migration cost.

#### Q1b — Nested-package `Lint/Sources/Lint/main.swift`

The nested-package path declares the package manifest in
`Lint/Package.swift` (engine + rule-pack deps), and at
`Lint/Sources/Lint/main.swift` declares the configuration (which rule
TYPES to enable, with what severity, on what paths). The executable IS
the linter binary — there is **no JSON crossing** between the consumer
and the engine. Metatypes flow directly.

##### Options for the nested-package shape

| ID | Shape | Example |
|---|---|---|
| A | Init kwargs over string-ID arrays (mirroring single-file) | `Lint.Manifest(enabledRuleIDs: ["unchecked_call_site"])` |
| B | Result-builder over typed enable entries | `Lint.Configuration { .enable(Lint.Rule.Unchecked.self) }` |
| **C** (current at L1) | Result-builder over typed enable entries via `@Array<Lint.Rule.Configuration>.Builder` | `Lint.Configuration(rules: { .enable(Lint.Rule.Unchecked.self) })` |
| D | Hybrid (declare BOTH Manifest and Configuration; gate Configuration on Manifest's enabled set) | The current PoC main.swift's actual shape |

##### Comparison

| Criterion | A: string IDs | B: bespoke builder | C: Array.Builder (current) | D: hybrid (PoC) |
|---|---|---|---|---|
| Call-site cleanliness | Compact but loses the typed advantage | Same as C | Compact; metatype `Type.self` reads as a name | Visible redundancy: rule named twice |
| Compile-time safety | Low (string typos, no rule-existence check) | High (R.Type compile-checked) | High | Mixed — rule-type catches typo; ID still typeable |
| Composability with parent | Easy (string ID inheritance) | Needs ID extraction | Already present (`inheriting:`) | Two-step (parent contributes IDs; local contributes types) |
| Diagnosability | Worst (silent missing rule) | Compile error on missing rule type | Same as B | Strict-mode failures: enabled set has ID but no .enable(Type) wired → silently inert |
| Ecosystem alignment | Inconsistent with the institute's typed-DSL preference | Bespoke result-builders are an anti-pattern; institute prefers `Array<Element>.Builder` | Matches the institute baseline | Two parallel surfaces — anti-pattern |
| Adopter onboarding | Easy but typo-prone | Equivalent | Equivalent | Hardest — adopter must understand both surfaces |
| Migration cost | Mechanical rewrite | Mechanical rewrite | Already shipped | Already shipped (defect form) |

##### The redundancy in the PoC's hybrid shape

The current `swift-tagged-primitives/Lint/Sources/Lint/main.swift` (read
2026-05-07) declares:

```swift
let manifest = Lint.Manifest(
    enabledRuleIDs: [
        "unchecked_call_site",
        "cardinal_count_minus_one",
        // ... 14 entries
    ]
)

let enabled = Swift.Set(manifest.enabledRuleIDs)

let configuration = Lint.Configuration(
    rules: {
        if enabled.contains(Lint.Rule.Unchecked.id) {
            Lint.Rule.Configuration.enable(Lint.Rule.Unchecked.self)
        }
        // ... 14 if-blocks, one per rule, naming each rule TWICE
    }
)
```

Each rule is named twice — once as a string in the `enabledRuleIDs`
array, once as a metatype in the `if enabled.contains(R.id) {
.enable(R.self) }` block. The two MUST stay in sync. Failure modes:

| Defect | Symptom |
|---|---|
| ID added to `enabledRuleIDs`, no corresponding `if` block | Silent: the rule never runs |
| `if .enable(R.self)` block, no corresponding ID in `enabledRuleIDs` | Silent: the rule never runs (the gate fails) |
| Typo in `enabledRuleIDs` ID literal | Silent: same |
| Rule renamed → ID changes, .enable(R.self) doesn't, gate fails | Silent: same |

The redundancy contributes zero compile-time safety in the
nested-package path (no JSON boundary; metatypes are sufficient) and
adds maintenance cost proportional to the rule count.

##### Q1b recommendation

**Option C — `Lint.Configuration` with `@Array<Lint.Rule.Configuration>
.Builder`, eliminating the redundant `Lint.Manifest` declaration in the
nested-package path.**

The nested-package main.swift becomes:

```swift
let configuration = Lint.Configuration(
    rules: {
        .enable(Lint.Rule.Unchecked.self)
        .enable(Lint.Rule.Cardinal.Count.self)
        .enable(Lint.Rule.Cardinal.Constructor.self)
        .enable(Lint.Rule.RawValue.Chain.self)
        .enable(Lint.Rule.RawValue.BitPattern.self)
        .enable(Lint.Rule.ResultBuilderForLoop.self)
        .enable(Lint.Rule.TryOptional.self)
        .enable(Lint.Rule.UntypedThrows.self)
        .enable(Lint.Rule.ExistentialThrows.self)
        .enable(Lint.Rule.VarNamedImpl.self)
        .enable(Lint.Rule.OptionNamedFlags.self)
        .enable(Lint.Rule.CompoundIdentifier.self)
        .enable(Lint.Rule.TagSuffix.self)
        .enable(Lint.Rule.TaggedDomainAudit.self)
    }
)

let arguments = Swift.CommandLine.arguments
let consumerPaths: [Swift.String] = arguments.count >= 2
    ? [Swift.String](arguments.dropFirst())
    : ["."]

let findings = try Lint.Run.run(paths: consumerPaths, configuration: configuration)
Lint.Reporter.emit(findings: findings, to: Terminal.Stream.stdout.write)
```

Each rule is named once. The metatype gives compile-time existence
checking (typo `Lint.Rule.Uncheckd.self` is a compile error — and is the
NORMAL Swift compile error, not a custom diagnostic). Ecosystem
alignment via `Array.Builder`. No bespoke result-builder.

#### Q1c — Cross-shape composition

The two shapes coexist; consumers may use either. Composition rules:

1. **Parent-chain over the wire**: when a child Lint.swift / Lint/
   declares `// parent: <URL>`, the resolver fetches the parent's
   *Manifest* (single-file or extracted from nested-package). This is
   string-ID-shaped because nested-package binaries do not exchange
   metatypes across processes.
2. **Local in-process composition**: the child's nested-package
   Configuration's `inheriting: parent` parameter accepts a
   `Configuration?`. The driver, on parent resolution, lifts the
   parent's Manifest into a Configuration by matching parent's
   enabledRuleIDs against the local rule registry (the consumer
   binary's set of `Lint.Rule.X.Type` values registered for activation).
3. **Match-by-id**: a parent's `"unchecked_call_site"` matches the
   local `Lint.Rule.Unchecked.id` if and only if the local consumer has
   registered `Lint.Rule.Unchecked.self`. Unmatched parent IDs warn but
   do not error — the consumer might intentionally drop a rule the
   parent enables.

This is a v2 detail — Phase B sub-phase per the existing PoC docstring.

### Q2 — Rule authoring shape

#### Q2 — Options

| ID | Shape | Example |
|---|---|---|
| **A** (current) | Struct conforming to `Lint.Rule.Protocol` with static metadata + `findings(in:) -> [Lint.Finding]` body | (see below) |
| B | Macro-generated boilerplate via `@LintRule(id: …, severity: .warning) struct MyRule { … }` | (see below) |
| C | DSL builder for rule construction | `Lint.Rule.build { id("my_rule"); severity(.warning); detect { syntax in … } }` |
| D | Property-wrapper metadata | `@RuleID("my_rule") @Severity(.warning) struct MyRule: Lint.Rule.Protocol { … }` |

##### Option A — current shape

```swift
extension Lint.Rule {
    public struct CompoundIdentifier: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "compound_identifier"
        public static let defaultSeverity: Diagnostic.Severity = .warning

        public let severity: Diagnostic.Severity

        @inlinable
        public init(severity: Diagnostic.Severity = .warning) {
            self.severity = severity
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            let visitor = Visitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    }
}
```

**Properties**: 4 lines of static metadata + `init` ceremony. Visitor
class is hidden in an extension. Per-rule message lives in a separate
extension as `static let message: String`.

##### Option B — `@LintRule` macro

```swift
@LintRule(id: "compound_identifier", severity: .warning)
extension Lint.Rule {
    public struct CompoundIdentifier {
        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            // ... visitor body
        }
    }
}
```

The macro generates `static let id`, `static let defaultSeverity`,
`var severity`, `init(severity:)`, and conformance to
`Lint.Rule.Protocol`.

**Cost**: introduces a SwiftSyntax-macro dependency on every rule pack
(swift-linter-rules's 11 modules + every consumer's custom rules).
Macros require a separate target with `.macro` type; the rule-pack
Package.swift gains complexity. Macro errors during diagnostic
expansion ("expected expression in argument list") are notoriously
opaque — diagnosed at the macro-expansion site, not the consumer's
intent.

##### Option C — DSL builder

```swift
let myRule = Lint.Rule.build {
    id("my_rule")
    severity(.warning)
    detect { source in
        // ... visitor body returning [Finding]
    }
}
```

Rule becomes a runtime VALUE rather than a TYPE. No metatype to pass to
`.enable(R.Type)` — `.enable(R)` becomes value-typed. Loses static
dispatch. Cannot extend rule with other static metadata
(`Lint.Citation`, parameter schemas) without growing the builder.

##### Option D — property-wrapper metadata

```swift
@RuleID("my_rule")
@Severity(.warning)
public struct CompoundIdentifier: Lint.Rule.Protocol {
    public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] { … }
}
```

Property wrappers cannot decorate types (only properties). Would require
non-standard mechanism. Eliminated.

#### Q2 — Comparison

| Criterion | A: protocol struct (current) | B: `@LintRule` macro | C: DSL builder | D: property-wrapper |
|---|---|---|---|---|
| Call-site cleanliness | 4 ceremonial lines per rule | 1 attribute line | 0 ceremony but visitor body inside closure | n/a (eliminated) |
| Compile-time safety | High — protocol conformance enforces shape | High at expanded form; macro expansion can fail with opaque errors | Medium — runtime value; closure types must match | n/a |
| Composability | Trivial — protocol is the composition surface | Same after expansion; debugging at macro level | Each rule is a value → must be re-wrapped for `.enable(R.Type)` factory | n/a |
| Diagnosability | Standard Swift errors at decl site | Macro errors are pinned to macro-call site, not authoring intent | Closure typing errors at body site; metadata typos not caught | n/a |
| Ecosystem alignment | Standard Swift; matches the institute's protocol-conformance + nested-type pattern | Adds macro dependency to every rule pack | Adds bespoke builder | n/a |
| Adopter onboarding | Standard Swift, trivial | Macro-aware mental model | Builder-aware mental model | n/a |
| Migration cost | Already shipped | Substantial rewrite of every existing rule + macro target authoring | Substantial; runtime-value model invalidates Configuration's `R.Type` factories | n/a |

#### Q2 — Recommendation

**Option A — keep the current protocol-conforming-struct shape.**
Rationale:

1. The 4 ceremonial lines (`id`, `defaultSeverity`, `severity`, `init`)
   are minimal Swift idiom. SwiftSyntax-visitor authoring already
   requires the author to understand types and protocols; the protocol
   conformance fits exactly.
2. Macros (Option B) save 4 lines and add a macro target dependency for
   every rule pack. The institute's macro packages
   (swift-dual / swift-defunctionalize / swift-witnesses) demonstrate
   that macro tooling has a non-trivial maintenance burden; adding it to
   every rule pack would multiply that burden.
3. Type-rather-than-value (Option C) is the right abstraction for rules
   with static metadata. Rule registry, citation, parameter schemas,
   and SwiftSyntax-visitor classes all attach naturally to the type.
4. **Status quo is correct.** No refinement needed at this layer.

### Q3 — Per-rule configuration / parameters

Some rules need parameters beyond severity. The dispatch brief cites
`compound_identifier`'s allowlist (`["makeIterator"]`) and `line_length`'s
max-length integer. Currently no rule in `swift-linter-rules` accepts
parameters beyond severity (`compound_identifier`'s "allowlist" is
hard-coded as `static let stdlibIdiomNames: Swift.Set<Swift.String>`).

#### Q3 — Options

| ID | Shape | Example |
|---|---|---|
| A | Inline kwargs on `.enable` factory | `.enable(Lint.Rule.CompoundIdentifier.self, allowlist: ["makeIterator"])` |
| B | Per-rule `Configuration` struct, `.enable(rule:configuration:)` | `.enable(Lint.Rule.CompoundIdentifier.self, configuration: .init(allowlist: ["makeIterator"]))` |
| C | Closure-based config | `.enable(Lint.Rule.CompoundIdentifier.self) { $0.allowlist += ["makeIterator"] }` |
| D | Builder-chain | `.enable(Lint.Rule.CompoundIdentifier.self).allowlist(["makeIterator"])` |
| **E** (recommended) | Pre-construct rule INSTANCE; new factory `.enable<R>(_ instance: R)` | `.enable(Lint.Rule.CompoundIdentifier(severity: .warning, allowlist: ["makeIterator"]))` |

##### Option A — inline kwargs

Forces every per-rule kwarg to flow through `.enable`'s signature.
Heterogeneous: each rule needs different kwargs. Result: `.enable<R>`
factory grows variadic kwargs that don't apply to most rules; or one
overload per rule (no genericity). Eliminated as global shape; specific
rules MAY ship their own factory.

##### Option B — per-rule `Configuration` struct

Each rule defines a nested `struct Configuration { … }` carrying its
parameters. The factory becomes `.enable<R>(rule: R.Type, configuration:
R.Configuration)`. Requires `Configuration` associated type or
metatype-keyed dictionary lookup. Adds friction at the protocol surface.

##### Option C — closure-based config

Mutable inout config inside a closure. Loses static typing of the config.
Idiomatically rare in Swift APIs.

##### Option D — builder-chain

Fluent-method ergonomic. Each rule extends `Lint.Rule.Configuration`
with rule-specific fluent methods (`.allowlist(_:)`). Extension
proliferation; rule-specific methods leak onto a shared type.

##### Option E — pre-construct instance

Each rule's `init` is the natural place for parameters. Today:
`init(severity: Diagnostic.Severity = .warning)`. Tomorrow:
`init(severity: Diagnostic.Severity = .warning, allowlist: [String] =
defaultAllowlist)`. The Configuration factory gains an instance-taking
overload:

```swift
extension Lint.Rule.Configuration {
    @inlinable
    public static func enable<R: Lint.Rule.Protocol>(
        _ instance: R, paths: Path.Filter? = nil
    ) -> Self {
        Self(rule: R.self, instance: instance, mode: .enabled,
             severity: instance.severity, paths: paths)
    }
}
```

The Configuration struct grows an optional `instance: (any
Lint.Rule.Protocol)?` field; when non-nil, the orchestrator uses it
directly instead of `R.init(severity:)`.

Call-site reads as ordinary Swift initializer-with-kwargs:

```swift
.enable(Lint.Rule.CompoundIdentifier(allowlist: ["makeIterator"]))
.enable(Lint.Rule.LineLength(max: 100))
.enable(Lint.Rule.Unchecked())  // no parameters; uses defaults
```

#### Q3 — Comparison

| Criterion | A: inline kwargs | B: per-rule Config struct | C: closure | D: builder chain | E: instance |
|---|---|---|---|---|---|
| Call-site cleanliness | Per-kwarg friction grows | Two layers (rule type + config) | Closure overhead | Fluent but hides the rule-type | Standard `Type(args)` Swift idiom |
| Compile-time safety | Per-rule overloads only; no genericity | Strong | Medium (inout config) | Strong | Strong |
| Composability | Per-rule factories proliferate | Adds associated-type or dictionary lookup | Same | Extension chains per rule | Same factory works for every rule |
| Diagnosability | OK for known rules | OK | Closure errors are local | OK | OK |
| Ecosystem alignment | Inconsistent with Swift init pattern | New idiom | Non-standard | Non-standard | Matches `init(severity:)` already in the protocol |
| Adopter onboarding | Per-rule lookup ("how do I configure THIS rule?") | Same | Same | Same | Read the rule's `init`; standard Swift |
| Migration cost | Per-rule factories | Each rule grows nested type | Each rule grows closure-config | Each rule grows extension chain | Add one factory; rules add `init` overloads as needed |

#### Q3 — Recommendation

**Option E — pre-construct instance via additional `.enable<R>(_
instance: R)` factory.**

Rationale:

1. Aligns with Swift idiom: `Type(args)` is how Swift authors create
   configured values. No new mental model.
2. Composes with `init(severity:)` already in `Lint.Rule.Protocol` —
   each rule extends its `init` with rule-specific kwargs at the rule's
   own discretion.
3. Per-rule shape is decided by each rule, not by a shared
   Configuration struct or builder chain. Authors of new rules write a
   normal Swift init signature; consumers configure via that signature.
4. Adds **one** factory to `Lint.Rule.Configuration`; no per-rule
   extensions, no associated types.
5. **Defer concrete migration**: no current rule needs parameters
   beyond severity. The factory addition is a v2 expansion; the
   recommendation locks in the SHAPE so when the first parameterized
   rule lands the path is clear.

Locked-in shape:

```swift
// In swift-linter-primitives at L1
extension Lint.Rule.Configuration {
    @inlinable
    public static func enable<R: Lint.Rule.Protocol>(
        _ instance: R,
        paths: Path.Filter? = nil
    ) -> Self {
        Self(
            rule: R.self,
            mode: .enabled,
            severity: instance.severity,
            paths: paths,
            instance: instance
        )
    }
}

extension Lint.Rule.Configuration {
    public let instance: (any Lint.Rule.Protocol)?
    // ... grow init to accept optional instance
}

// In Lint.Run.run, when iterating effective rules:
let active: any Lint.Rule.Protocol = entry.instance
    ?? entry.rule.init(severity: entry.severity ?? entry.rule.defaultSeverity)
```

Migration cost: minor. Existing call sites continue to use `.enable(R
.Type)` factory; new sites use `.enable(R(args))` instance factory.

### Q4 — Severity overrides + exclusions

Already largely handled by the current shape:

- **Per-rule severity override**: `Lint.Rule.Configuration.override(R.Type,
  severity:)` factory. Adopter surface:
  `.override(Lint.Rule.CompoundIdentifier.self, severity: .error)`.
- **Per-rule disable**: `Lint.Rule.Configuration.disable(R.Type)`. Layered
  inheritance: a child's `.disable(R.Type)` shadows a parent's
  `.enable(R.Type)`.
- **Per-rule path filter**: `paths: Path.Filter?` parameter on `.enable`
  / `.override`. Filter declared as `Path.Filter(included:, excluded:)`
  with static factories `.all`, `.including(_:)`, `.excluding(_:)`.
- **Configuration-wide exclusions**: `excluded: [Swift.String]` (path
  strings) on `Lint.Configuration`. Walker also has its own structural
  exclusions (`.build/`, `Carthage/`) on top.

#### Q4 — Open issue (already documented at L1)

`Path.Filter.swift`'s docstring records this open question:

> `swift-path-primitives` Path is `~Copyable`, which prevents `[Path]`
> arrays without ~Copyable stdlib Array support. `Lint`'s configuration
> model needs Copyable path-shaped values for `included` / `excluded`
> arrays. Phase 1.5 Item 5 uses raw `Swift.String` at L1 (path-shaped
> string, semantically a path); the L3 evaluator and walker convert to
> typed `File.Path` / `Paths.Path` at the I/O boundary. A Copyable
> typed-path L1 primitive (or `~Copyable` array support in stdlib) closes
> this gap.

The `Lint.Manifest` boundary type already uses `[File.Path]` for
`excludedPaths` (since File.Path is Copyable); the typed
`Lint.Configuration` at L1 cannot import File_System without a layering
violation, so it falls back to `[Swift.String]`.

#### Q4 — Recommendation

**Status quo, with a v2 path-typing alignment.** Rationale:

1. The current shape (`.enable(_, paths: .excluding(["Tests/Fixtures"]))`,
   `.override(_, severity: .error)`, `.disable(_)`,
   `Lint.Configuration(_, excluded: ["Tests/Fixtures"])`) is consistent
   with the typed factories in Q1b and Q3. No new shape.
2. v2 alignment: when `swift-path-primitives` ships a Copyable
   typed-path companion (or `~Copyable` stdlib `Array` support lands),
   migrate `Path.Filter`'s `included`/`excluded` and Configuration's
   `excluded` to that typed shape. Until then, the L1-vs-L3 layering
   forces strings; this is a documented trade-off.
3. **Fix at L1 first when the typed path lands**, then L3
   (`Lint.Manifest.excludedPaths` already uses File.Path) follows.

### Q5 — Parent-chain inheritance interaction

Both shapes use the `// parent: <URL>` comment-directive at the top of
the consumer file (single-file: top of `Lint.swift`; nested-package: top
of `Lint/Sources/Lint/main.swift`).

#### Q5 — Resolution path

The Manifest_Resolver (`swift-foundations/swift-manifests`):

1. Reads the consumer file's leading-trivia comments.
2. Extracts `parent: <URL>` directives (per `Manifest_Resolver`'s
   per-process URL fetch + memoization).
3. Recursively resolves parents (with cycle / depth limits).
4. Folds parent manifests into a layered `Lint.Configuration` with
   `inheriting: parent`.

For the single-file path this is fully implemented (the working
mechanism at `swift-primitives/.github/Lint.swift` ←
`swift-institute/.github/Lint.swift`). For the nested-package path,
parent-chain resolution is "deferred to Phase B sub-phase" per
`Lint.Driver`'s docstring.

#### Q5 — Cross-shape composition

| Parent shape | Child shape | Composition mechanism |
|---|---|---|
| Single-file Manifest | Single-file Manifest | Layered `enabledRuleIDs`/`disabledRuleIDs`/`excludedPaths`, child wins per ID |
| Single-file Manifest | Nested-package Configuration | Parent's enabledRuleIDs lifted into child's local Configuration via rule-registry lookup; unmatched parent IDs warn |
| Nested-package main.swift | Single-file Manifest | (currently undefined; suggested: extract Manifest from nested-package's Configuration via id-projection) |
| Nested-package main.swift | Nested-package main.swift | Same id-projection path |

#### Q5 — Recommendation

**The wire format between processes is `Lint.Manifest` (string IDs).
The local in-process value is `Lint.Configuration` (typed metatypes).
Parent chains resolve via Manifest; local declaration uses
Configuration; the lift from Manifest to Configuration happens at the
child's process boundary via the local rule registry.**

Concrete v2 rules:

1. The parent resolver returns a `Lint.Manifest` per parent (the wire
   format). Folding produces a single composed Manifest representing
   the full ancestry's enable/disable/exclude state.
2. The child's `Lint.Configuration(inheriting: parentConfiguration,
   rules: { … })` lifts the composed Manifest into a Configuration. The
   lift function takes the local rule registry as a side-table:
   `Lint.Configuration.lift(manifest: Lint.Manifest, registry: [Lint.Rule.ID:
   any Lint.Rule.Protocol.Type]) -> Lint.Configuration`.
3. Unmatched parent IDs (parent enables a rule the child has not
   registered) emit a warning to the reporter; the rule is skipped.
   This is the documented intentional-drop case.
4. The single-file path's parent resolution remains unchanged — already
   working.

This is a v2 work item; the recommendation locks in the design.

### Q6 — Diagnostic message authoring (citation structure)

Current shape (per `Lint.Rule.CompoundIdentifier.swift:62-68`):

```swift
extension Lint.Rule.CompoundIdentifier {
    @usableFromInline
    static let message: Swift.String =
        "[compound_identifier] [API-NAME-002]: methods and properties MUST NOT use "
        + "compound names. Use nested accessors instead (e.g., `instance.open.write { }` "
        + "not `instance.openWrite { }`; `dir.walk.files()` not `dir.walkFiles()`). "
        + "Boolean prefixes (`is`, `has`, `should`, `will`, `did`, `can`, `must`) are "
        + "exempt; spec-mirroring identifiers are exempt; `package`-scope declarations "
        + "are exempt per `feedback_compound_package_scope`."
}
```

Free-form string, manually-prefixed `[rule_id]` and `[skill-citation]`.

#### Q6 — Options

| ID | Shape | Example |
|---|---|---|
| **A** (current) | Free-form string with manual citation prefix | `[compound_identifier] [API-NAME-002]: …` |
| B | Structured citation type + separate body | `static let citation: Lint.Citation = .skill("API-NAME-002"); static let messageBody: String = "…"` |
| C | Macro-generated citation+message | `@LintRule(id:, citation: .skill("API-NAME-002")) struct …` (depends on Q2 Option B) |

#### Q6 — Discussion

The current free-form shape works for human-readable terminal output but
is opaque for SARIF, AI-targeted JSON, or any diagnostic consumer that
needs to filter / route by citation. SARIF's `properties` field is the
natural home for structured citations; the free-form prefix is
unparseable without regex.

##### Option B — `Lint.Citation` enum

```swift
extension Lint {
    public enum Citation: Sendable, Hashable {
        case skill(SkillRule.ID)              // [API-NAME-002], [PLAT-ARCH-008c]
        case research(ResearchDoc.ID)         // .md filename in swift-institute/Research/
        case memory(Memory.ID)                // feedback_*.md filename
        case rfc(SpecificationID)             // RFC 4122
        case external(URL)                    // arbitrary external link
    }
}

extension Lint.Rule {
    public protocol `Protocol`: Sendable {
        // ... existing fields
        static var citation: Lint.Citation { get }
        static var messageBody: Swift.String { get }
    }
}
```

The terminal reporter composes the human-readable line:
`"[\(R.id)] \(R.citation.formatted): \(R.messageBody)"`. The SARIF
reporter emits `properties.citation` as structured JSON. The AI-harness
JSON reporter emits `citation: { kind: "skill", id: "API-NAME-002" }`.

##### Option C — macro-generated

Depends on Q2's Option B (macro for rule authoring). Rejected per Q2's
recommendation.

#### Q6 — Comparison

| Criterion | A: free-form | B: structured citation | C: macro-generated |
|---|---|---|---|
| Call-site cleanliness | One `static let message` | Two declarations (citation + body) | One `@LintRule` line |
| Compile-time safety | None on citation form | High — `Lint.Citation` enum constrains shape | High at expanded form |
| SARIF / AI-JSON output quality | Poor (text only) | High (structured properties) | High |
| Adopter onboarding | Easy for new rule authors | One additional concept to learn | Macro-aware mental model |
| Ecosystem alignment | Free strings are exception, not norm | Matches `Diagnostic.Record`'s typed-citation evolution | Bespoke |
| Migration cost | Already shipped | One mechanical edit per existing rule (split message into citation + body); ~15 rules × 5 minutes = ~1.5 hours | Substantial — every rule rewritten |

#### Q6 — Recommendation

**Option B — introduce `Lint.Citation` enum, split rule metadata into
`citation` + `messageBody`. v2 (post-publishable-v1, before significant
adoption).**

Rationale:

1. The free-form string forecloses on structured-output consumers
   (SARIF for CI integration; AI-targeted JSON for the AI-harness
   educational-diagnostic mission per
   `swiftsyntax-based-custom-linter-investigation.md`'s investment
   hypothesis).
2. The migration is mechanical: each existing rule splits one string
   into two declarations.
3. Compile-time enforcement of citation form: `Lint.Citation` is a
   typed enum, every case is a known kind, the SARIF reporter writes a
   well-formed JSON shape unconditionally.
4. Per [API-IMPL-008] minimal type body: citation and messageBody live
   in extensions (already the case for `static let message`).

v1 ships with the current free-form shape; v2 splits per the structured
shape before broad adoption.

---

## Constraints

The following constraints bound the recommendation set. Any deviation
requires explicit principal authorization.

| # | Constraint | Source |
|---|---|---|
| C1 | Foundation-clean throughout the consumer surface | `[PRIM-FOUND-001]`; primitives layer |
| C2 | Single-file path MUST cross JSON boundary; rule references MUST be string-IDs at the wire format | swift-manifest's subprocess loader architecture |
| C3 | Nested-package path links rule packs as binary deps; metatypes flow directly | Lint/ nested-package shape; PoC at swift-tagged-primitives |
| C4 | `// parent: <URL>` directive is the parent-chain mechanism; resolution via `Manifest_Resolver` | Existing single-file path; `Lint.Driver`'s docstring |
| C5 | Visibility patterns (PRIVATE / PUBLIC) MUST be supported; private dependency packages cannot use URL-based deps in CI without auth | swift-tagged-primitives `Lint/Package.swift` comment; `feedback_private_repos_no_ci_runs.md` |
| C6 | SwiftSyntax visitor body shape is fixed by the `SyntaxVisitor` API; cannot be result-builderized | SwiftSyntax framework |
| C7 | Result-builders MUST use `@Array<Element>.Builder` from Standard_Library_Extensions; no bespoke builders | Institute baseline; `Lint.Configuration` already uses this |
| C8 | Identifier conventions: no compound identifiers ([API-NAME-002]); types follow `Nest.Name` ([API-NAME-001]); typed throws ([API-ERR-001]) | code-surface |
| C9 | The L1 `Lint.Configuration` cannot import L3 types (File_System, JSON); paths-as-Swift.String is a documented trade-off | Five-layer architecture; `Path.Filter.swift` open question |

C6 deserves a callout per the dispatching handoff's `ask:` clause: **the
SwiftSyntax visitor body is constrained, but the body is INSIDE the rule
struct, not at the top-level consumer surface**. The result-builder
question (Q1b) governs the rule-activation surface; the visitor body
(Q2) is a separate authoring concern. No SwiftSyntax constraint forces
a non-result-builder activation surface.

---

## Comparison Summary (per question)

| Q | Recommended | Tier of change | Phasing |
|---|---|---|---|
| Q1a Single-file Manifest | A: init-kwargs (current) + add `validate()` method | v1 refinement | Now |
| Q1b Nested-package Configuration | C: `Array.Builder` typed metatype DSL (current at L1, drop redundant Manifest decl in PoC main.swift) | v1 refinement | Now |
| Q1c Cross-shape composition | Manifest as wire format; Configuration as in-process value; `Configuration.lift(manifest:registry:)` for parent-chain | v2 (Phase B sub-phase per existing PoC) | Soon |
| Q2 Rule authoring | A: protocol-conforming struct (current) | No change | — |
| Q3 Per-rule parameters | E: instance-taking factory `.enable<R>(_ instance: R)` | v2 (when first parameterized rule lands) | Defer to first need |
| Q4 Severity / exclusions | Status quo + v2 path-typing alignment when Copyable typed-path lands | v1 / v2 | Track upstream |
| Q5 Parent-chain | Manifest is wire format; lift via local rule registry | v2 (Phase B sub-phase) | Soon |
| Q6 Citations | B: `Lint.Citation` enum + split `citation` + `messageBody` | v2 (before broad adoption) | Pre-publication |

### v1 / v2 / v3 phasing summary

**v1 (now, before publication)**:

- Drop the redundant `let manifest: Lint.Manifest = …` declaration from
  the nested-package PoC's `main.swift`. Keep only
  `let configuration = Lint.Configuration(rules: { … })` with typed
  `.enable(R.self)` factories. (Q1b)
- Add `func validate() throws(Lint.Manifest.Error)` to `Lint.Manifest`
  that checks each ID against the parent linter's known rule registry.
  (Q1a refinement)

**v2 (post-publication, before broad adoption)**:

- Add `Lint.Configuration.lift(manifest:registry:)` for parent-chain
  resolution in the nested-package path (Phase B sub-phase). (Q5)
- Introduce `Lint.Citation` enum at L1; split `Lint.Rule.Protocol`'s
  `static let message` into `static let citation: Lint.Citation` +
  `static let messageBody: Swift.String`. Migrate each existing rule
  mechanically. (Q6)
- Add `.enable<R>(_ instance: R, paths: Path.Filter?)` factory to
  `Lint.Rule.Configuration` with an optional `instance` field on the
  Configuration struct. (Q3 pre-position)

**v3 (when triggers fire)**:

- When the first parameterized rule lands (e.g., `Lint.Rule.LineLength`
  with `max:`), use the v2-staged instance-taking factory. (Q3 trigger)
- When `swift-path-primitives` ships a Copyable typed-path companion,
  migrate `Path.Filter` and `Lint.Configuration.excluded` to the typed
  shape. (Q4 trigger)

---

## Outcome

**Status**: RECOMMENDATION

The current `Lint.Configuration` typed-DSL surface (L1) is the
correct nested-package consumer shape; the `Lint.Manifest` init-kwargs
surface (L3) is the correct single-file subprocess wire format. The
cleanest possible consumer-facing syntax is achieved by:

1. **Eliminating the redundant `Lint.Manifest` declaration in the
   nested-package shape** (one-line behaviour change in the PoC's
   `main.swift`; mechanical fix; Q1b).
2. **Locking in the four future-shape additions** (Manifest's
   `validate()` method; Configuration's `lift(manifest:registry:)`;
   instance-taking `.enable<R>(_ instance: R)` factory; structured
   `Lint.Citation` + split `messageBody`).
3. **No change to rule-authoring shape** (status quo of struct + Lint
   .Rule.Protocol is correct; Q2 status quo).
4. **No new bespoke result-builders** (the institute's `Array.Builder`
   already serves both surfaces).

### Rule-authoring template (locked-in v1+v2 shape)

```swift
public import Linter_Primitives
internal import SwiftSyntax

extension Lint.Rule {
    public struct CompoundIdentifier: Lint.Rule.`Protocol` {
        public static let id: Lint.Rule.ID = "compound_identifier"
        public static let defaultSeverity: Diagnostic.Severity = .warning
        public static let citation: Lint.Citation = .skill("API-NAME-002")    // v2

        public let severity: Diagnostic.Severity
        public let allowlist: [Swift.String]                                   // v2/v3 example

        @inlinable
        public init(
            severity: Diagnostic.Severity = .warning,
            allowlist: [Swift.String] = Self.defaultAllowlist                  // v2/v3 example
        ) {
            self.severity = severity
            self.allowlist = allowlist
        }

        public func findings(in source: Lint.Source.Parsed) -> [Lint.Finding] {
            // ... visitor body
        }
    }
}

extension Lint.Rule.CompoundIdentifier {
    @usableFromInline
    static let messageBody: Swift.String =                                     // v2: split from `message`
        "Methods and properties MUST NOT use compound names. Use nested "
        + "accessors instead (e.g., `instance.open.write { }` not "
        + "`instance.openWrite { }`)."
}
```

### Single-file consumer template (locked-in v1 shape)

```swift
// parent: https://raw.githubusercontent.com/swift-institute/.github/main/Lint.swift

import Linter

let manifest = Lint.Manifest(
    enabledRuleIDs: [
        "unchecked_call_site",
        "cardinal_count_minus_one",
        "cardinal_zero_one_constructor",
        "chained_rawvalue_access",
        "bitpattern_rawvalue_chain",
    ]
)
```

### Nested-package consumer template (locked-in v1 shape)

```swift
// parent: https://raw.githubusercontent.com/swift-primitives/.github/main/Lint.swift

internal import Linter
internal import Linter_Reporter_Text
internal import Linter_Rule_Cardinal
internal import Linter_Rule_Compound_Identifier
internal import Linter_Rule_Unchecked
internal import Terminal_Primitives

let configuration = Lint.Configuration(
    rules: {
        .enable(Lint.Rule.Unchecked.self)
        .enable(Lint.Rule.Cardinal.Count.self)
        .enable(Lint.Rule.Cardinal.Constructor.self)
        .enable(Lint.Rule.CompoundIdentifier.self)
        // (v3 example with parameterized rule)
        // .enable(Lint.Rule.LineLength(max: 100))
    }
)

let arguments = Swift.CommandLine.arguments
let consumerPaths: [Swift.String] = arguments.count >= 2
    ? [Swift.String](arguments.dropFirst())
    : ["."]

let findings = try Lint.Run.run(paths: consumerPaths, configuration: configuration)
Lint.Reporter.emit(findings: findings, to: Terminal.Stream.stdout.write)
```

### Rationale summary

The institute's typed-system discipline already produced the right
abstractions:

- `Lint.Rule.ID = Tagged<Lint.Rule, Swift.String>` — typed string IDs
  segregate the namespace.
- `Lint.Configuration` with `Array.Builder` and `.enable(R.Type)`
  factories — typed metatype DSL.
- `Lint.Manifest` with `JSON.Serializable` — explicit wire-format
  boundary.
- `Lint.Rule.Protocol` with static metadata + `findings(in:)` — minimal
  ceremony, Swift-idiomatic.

The PoC's hybrid main.swift is the only operational defect. The other
recommendations are forward-shape locks for v2/v3, not changes to v1.

### Cognitive Dimensions Framework empirical validation [RES-025]

| Dimension | Q1b recommendation (Configuration with Array.Builder + .enable(R.Type)) | Q2 recommendation (protocol struct) |
|---|---|---|
| Visibility | High — every enabled rule is one `.enable(R.self)` line | High — protocol fields are 4 lines per rule |
| Consistency | High — matches `Package.swift` init kwargs idiom and ecosystem `Array.Builder` baseline | High — protocol-conformance is the standard Swift abstraction |
| Viscosity | Low — adding/removing a rule is one line | Low — adding a new rule is one struct + extensions |
| Role-expressiveness | High — `.enable(_)` / `.disable(_)` / `.override(_, severity:)` are role-named | High — `id`/`defaultSeverity`/`severity`/`init`/`findings(in:)` are role-named |
| Error-proneness | Low — typo on `Lint.Rule.X.self` is a normal Swift compile error | Low — protocol conformance enforces shape |
| Abstraction | Appropriate — typed metatype factories don't over-generalize | Appropriate — protocol surface is minimal and necessary |

All six dimensions favour the recommended shape. No CDF dimension
suggests reverting to a flat keyword-args manifest at the nested-package
layer.

### Theoretical grounding [RES-022]

The single-file vs nested-package shape distinction is an instance of
the **wire-format vs object-graph** boundary recurrent in distributed
systems: the wire format must be string-shaped (or otherwise serializable)
to cross processes; the object graph carries typed identities. The
recommendation respects this boundary directly:

- Manifest = wire format (subprocess JSON crossing).
- Configuration = object graph (typed metatypes, in-process).
- The lift `Configuration.lift(manifest:registry:)` is the
  hydration step at the receiving end.

This mirrors the Codable `Encoder`/`Decoder` split, the Protobuf
descriptor / typed-message split, and the JSON Schema / typed-value
split. The institute's recommended shape lands on the same boundary
without introducing new abstractions.

The Q2 status-quo recommendation is grounded in the **algebraic shape
test**: rule authoring is a TYPE declaration with static metadata, not a
VALUE construction. Swift expresses type declarations via `struct` +
protocol conformance; reaching for macros, builders, or property-wrappers
to express "a type with static metadata" introduces accidental
complexity without algebraic gain.

---

## Implementation hooks (for the post-research dispatch)

The following concrete code changes implement the v1 portion of the
recommendation. Cited here for the implementer's convenience; not
authoritative until a separate dispatch is signed off.

### v1 change 1 — drop redundant Manifest from PoC's main.swift

`/Users/coen/Developer/swift-primitives/swift-tagged-primitives/Lint/Sources/Lint/main.swift`:

- Remove lines 49–79 (the `let manifest = Lint.Manifest(...)` declaration
  and the `let enabled = Swift.Set(manifest.enabledRuleIDs)` derivation).
- Remove the `if enabled.contains(R.id)` gates inside the
  `Lint.Configuration(rules: { ... })` body (lines 91–146).
- Replace each `if enabled.contains(R.id) { Lint.Rule.Configuration.enable(R.self) }`
  with a bare `.enable(R.self)`.

Total diff: ~50 lines deleted, ~14 lines simplified, net ~64 fewer lines.

### v1 change 2 — add Manifest.validate()

`/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift`:

- Add nested `enum Error: Swift.Error { case unknownRuleID(Lint.Rule.ID,
  available: [Lint.Rule.ID]); case duplicateID(Lint.Rule.ID); ... }`.
- Add `func validate(against registry: [Lint.Rule.ID: any
  Lint.Rule.Protocol.Type]) throws(Error) -> Self`.

### v2 / v3 changes

Documented inline above; each requires its own dispatch when the trigger
fires.

---

## Open questions for the implementing dispatch

1. The lift function's signature — does the registry come from the
   consumer binary's `Lint.Rule.Configuration.rule.id` reflection of the
   declared `.enable(_)` entries, or from a separate
   `Lint.Configuration.registerRule(_:)` API? The reflection approach is
   simpler but couples lift to local declaration order; the registration
   approach is more explicit but adds a lifecycle step.
2. The `Lint.Citation` enum's case set — is `case skill(SkillRule.ID)`
   typed against `Skill.Rule.ID` (a `Tagged<Skill.Rule, String>` like
   the existing `Lint.Rule.ID`), or is it a free string at v2? The typed
   form is cleaner but creates a SkillRule.ID L1 type that doesn't yet
   exist.
3. v3 trigger ordering — does the path-typing migration (Q4) precede or
   follow `Lint.Citation` (Q6)? They are independent, but if both land
   the rule shape changes substantially.

These are deferred to the v2/v3 implementing dispatches; the
recommendation status remains intact at v1.

---

## References

| Source | Use |
|---|---|
| `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md` v1.0.0 (RECOMMENDATION 2026-05-06) | Locks in Option C (standalone CLI) + Option F (symbol-graph). Establishes the architectural baseline. |
| `swift-institute/Research/developer-tool-package-architecture.md` (DECISION Tier 3 2026-04-13) | Architectural home for the linter (Developer/standalone, future swift-tools/ promotion). |
| `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift` (HEAD 2026-05-07) | Current Manifest shape — wire-format boundary type. |
| `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.swift` (HEAD 2026-05-07) | Current Configuration shape — typed metatype DSL with Array.Builder. |
| `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.Configuration.swift` (HEAD 2026-05-07) | Per-rule entry: enable / disable / override factories. |
| `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.Protocol.swift` (HEAD 2026-05-07) | Rule capability protocol — current shape (id, defaultSeverity, severity, init(severity:), findings(in:)). |
| `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Path.Filter.swift` (HEAD 2026-05-07) | Open question on Copyable typed-path L1. |
| `swift-primitives/swift-tagged-primitives/Lint/Sources/Lint/main.swift` (HEAD 2026-05-07) | PoC nested-package main.swift exhibiting the redundant-Manifest defect. |
| `swift-primitives/.github/Lint.swift` (HEAD 2026-05-07) | Tier 2 single-file canonical Lint.swift — exemplar for the single-file shape. |
| `swift-foundations/swift-linter/Sources/Linter Core/Lint.Driver.swift` (HEAD 2026-05-07) | Driver dispatching nested-package vs single-file paths. |
| SwiftLint custom_rules YAML reference | https://github.com/realm/SwiftLint/blob/main/Source/SwiftLintBuiltInRules/Rules/Style/CustomRulesRule.swift (prior-art survey baseline). |
| swift-format `.swift-format` JSON reference | https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md (prior-art survey baseline). |
| ESLint plugin authoring docs | https://eslint.org/docs/latest/extend/custom-rules (prior-art survey baseline). |
| Rust Clippy + Cargo attribute lints | https://doc.rust-lang.org/rustc/lints/index.html ; https://github.com/trailofbits/dylint (prior-art survey baseline). |
| `feedback_compound_package_scope.md` (memory) | Why `package`-scope declarations are exempt from compound_identifier — informs Citation kind. |
| `feedback_no_public_or_tag_without_explicit_yes.md` (memory) | Pre-publishable status — why this research must converge before publication. |
