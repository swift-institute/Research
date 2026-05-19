# swift-linter Unified Consumer Manifest — Single-File Lint.swift Declaring Both Dependencies and Rule Activations

<!--
---
version: 1.1.0
last_updated: 2026-05-12
status: RECOMMENDATION
research_tier: 3
applies_to:
  - swift-foundations/swift-linter
  - swift-foundations/swift-linter-rules
  - swift-foundations/swift-manifests
  - swift-primitives/swift-linter-primitives
  - swift-primitives/swift-primitives-linter-rules
  - all consumer packages adopting swift-linter
extends: 2026-05-07-swift-linter-consumer-syntax.md
addresses: 2026-05-07-single-file-lint-swift-deprecation-decision.md (Option D)
normative: false
changelog:
  - "1.1.0 (2026-05-12): Role A / Role B clarification after implementation surfaced the conflation. Tier 1/Tier 2 canonical scaffolds (`.github/Lint.swift`) are NOT migrated to Shape γ — they are wire-format policy declarations (Role B) consumed by descendant Shape γ Lint.swift files (Role A) via the `// parent: <URL>` directive. The two forms are complementary, not competing. The v1.0.0 migration analysis's framing that scaffolds 'should update to Shape γ' is corrected; only consumer Lint.swift migrates. Adds parent-chain wiring as the real implementation follow-up."
  - "1.0.0 (2026-05-12): initial RECOMMENDATION."
---
-->

## Context

### Trigger

The swift-linter ecosystem ships two consumer shapes today:

1. **Nested-package `Lint/`**: 71-line `Lint/Package.swift` + 21-line `Lint/Sources/Lint/main.swift` (92 lines total) declaring dependencies (in Package.swift) AND rule activations (in main.swift). This is the **working consumer pattern** at 0.1.0 — every existing consumer uses it (14 packages across swift-primitives at HEAD 2026-05-12).
2. **Single-file `Lint.swift`**: `let manifest: Lint.Manifest = …` evaluated via swift-manifest's subprocess loader. **Inert post-Phase-B.1 decouple** — the engine ships zero rules, so the single-file path activates nothing.

The information content of the canary baseline (`swift-primitives/swift-carrier-primitives/Lint/`) is roughly two bits: "use the primitives tier bundle, plus default engine wiring." Producing those two bits requires 92 lines of ceremony — license headers, `PackageDescription` boilerplate, executable target declaration, two path deps, two product imports, an ecosystem `SwiftSetting` loop, plus the executable's main.swift with two `internal import` lines and a one-line `Lint.run(bundle:)` call. The ceremony-to-intent ratio is approximately 50:1.

This research asks whether a single `Lint.swift` modeled on `Package.swift` — declaring BOTH dependencies AND rule activations in one self-contained file — is feasible, what it would look like, and what its costs are.

### Predecessor research

`swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md` (v1.0.1, RECOMMENDATION) is the predecessor. That research:

- Treated the two shapes (single-file `Lint.Manifest` and nested-package `Lint.Configuration`) as **necessarily separate types** because the wire-format crosses a JSON boundary while the in-process value carries typed metatypes.
- Recommended keeping both surfaces, with the nested-package shape as the working consumer pattern and the single-file shape preserved for future evolution.
- Did NOT consider the unification possibility (single file declaring deps + activations).

This research **extends** that doc by adding Option D from `2026-05-07-single-file-lint-swift-deprecation-decision.md` — "unify dep-declaration AND rule-activation in single `Lint.swift`, making the file the moral equivalent of `Package.swift` for the linter" — and surveying prior art beyond the six adjacent systems the prior research covered.

**Supersession scope**: this research SUPERSEDES the predecessor's Q1c "cross-shape composition" section (the two-shape coexistence frame is replaced by a single-shape recommendation). It EXTENDS Q1a/Q1b by showing both can collapse into a single unified shape. The predecessor's Q2 (rule authoring), Q3 (per-rule parameters), Q4 (severity + exclusions), Q5 (parent-chain), Q6 (citation structure) remain valid — they describe how rules and their activations behave once unified.

**Empirical premise correction since the predecessor**: `Lint.Rule` shifted from protocol-conformance (with `R.Type` metatype refs) to **witness-value** with backtick-quoted natural-English identifiers per `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.swift`. Activations are now `Lint.Rule.Configuration.enable(.\`unchecked call site\`)` (static-member access on a witness value), not `.enable(Lint.Rule.Unchecked.self)`. This change strengthens the unified-single-file case: rule references are now ordinary Swift expressions evaluated against imported modules.

### The deprecation-decision context

`2026-05-07-single-file-lint-swift-deprecation-decision.md` enumerates three options for the single-file path: A (preserve as sugar), B (deprecate with migration), C (remove entirely). The Outcome remained "Pending investigation" as of 2026-05-07. User has now proposed **Option D — unify deps + activations in single `Lint.swift`**, which is the subject of this research. If Option D is the correct path, A/B/C all collapse — the single-file path doesn't deprecate, it evolves into the unified shape.

### Why now

Pre-publishable. swift-linter, swift-linter-rules, and swift-linter-primitives are private at HEAD with one tag-pilot launch (swift-linter 0.1.0) underway per `swift-institute/Research/swift-linter-launch-skill-incorporation-backlog.md`. Fourteen consumer `Lint/` packages exist across swift-primitives, all with the same 70–90-line ceremony. The window for a breaking-change refactor closes when these packages flip public; after that, every adopter's `Lint/` shape is a public-API contract.

### Research tier classification (per [RES-020])

| Criterion | Value |
|---|---|
| Scope | cross-package — affects swift-linter + swift-linter-primitives + swift-linter-rules + swift-manifests + every consumer that writes a `Lint.swift` or `Lint/` directory |
| Precedent-setting | **Yes** — the chosen shape becomes the public-API contract for adopters ecosystem-wide and lasts the lifetime of the linter |
| Semantic commitment | **Foundational** — file-format normative contract; impossible to revert silently once adopters depend on it |
| Cost of error | **Very high** — wrong shape forces adopter migration after publication; every external repo using swift-linter pays the cost |
| Expected lifetime | **Timeless infrastructure** — file-format decisions of this class typically outlive the toolchain that introduced them (cf. `Package.swift`, `.eslintrc.js`, `Cargo.toml`) |

→ **Tier 3**. Per [RES-021], comprehensive prior-art survey with contextualization step mandatory; per [RES-023], systematic literature review per Kitchenham methodology; per [RES-024], formal semantics with typing rules; per [RES-026], explicit citations to primary sources.

---

## Question

**Core question**: Can a single `Lint.swift` declare BOTH the rule-package dependencies it needs AND which rules from those packages to activate, mirroring `Package.swift`'s self-contained shape, while preserving compile-time safety on rule references and Swift's type system as the activation surface?

Sub-questions:

| # | Question |
|---|---|
| Q1 | What is the fundamental tension between declarative-dep-resolution and imperative-rule-activation? How is it resolved in adjacent ecosystems? |
| Q2 | What infrastructure already exists in the institute that could be leveraged? (Hint: `swift-foundations/swift-manifests`'s `Manifest.Load` already implements the SwiftPM-style bootstrap pattern.) |
| Q3 | What are the candidate shapes for a unified single-file `Lint.swift`? |
| Q4 | Which shape best satisfies the four user-specified optimization criteria: ease of use, few moving parts, clean code, alignment with `Package.swift`? |
| Q5 | What's the engine work required to ship the recommended shape? What's the migration path from the current two-file shape? |
| Q6 | What does the recommended shape sacrifice? What open questions remain? |

Evaluation criteria (consumer-facing):

| Criterion | Definition |
|---|---|
| Ease of use | Lines of intent vs lines of ceremony at a typical consumer site |
| Few moving parts | Number of files / generated artifacts / build steps the consumer must understand |
| Clean code | Boilerplate-to-meaningful-code ratio; idiom-alignment with Swift conventions |
| Alignment with `Package.swift` | Does the shape look and feel like a `Package.swift`? Same DSL bootstrap pattern? |
| Compile-time safety | Are rule references type-checked? Are dep references type-checked? |
| Composability | Parent-chain inheritance, third-party rule packs, custom rules |
| Adopter onboarding | Time-to-first-rule for a new consumer reading no docs |
| Migration cost | What breaks for existing nested-package consumers? |

---

## Prior Art Survey

Twelve systems, organized into three groups by ecosystem affinity. Each surveyed for: actual consumer syntax, what works, what doesn't, the lesson for swift-linter, and explicit verdict on whether the system unifies deps + activation in one file.

### Group 1 — Native Swift ecosystem

#### 1.1 SwiftPM `Package.swift` (gold standard)

**Consumer-facing syntax** (from `/Users/coen/Developer/swift-foundations/swift-linter/Package.swift`, abridged):

```swift
// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-linter",
    platforms: [ .macOS(.v26) ],
    products: [
        .library(name: "Linter", targets: ["Linter"]),
        .executable(name: "swift-linter", targets: ["Linter CLI"]),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-linter-primitives"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        .target(
            name: "Linter Core",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
    ]
)
```

**How evaluation works** (from `swiftlang/swift-package-manager` source — `Sources/PackageLoading/ManifestLoader.swift` and `ToolsVersionParser.swift`):

1. `ToolsVersionParser.parse(manifestPath:fileSystem:)` reads only the first non-whitespace line, scans for `//`, then case-insensitively for `swift-tools-version:`, then extracts the version specifier. **This happens before any Swift compilation.**
2. `ManifestLoader.evaluateManifest()` invokes the Swift compiler on the manifest, linking it against the on-disk `PackageDescription` library: `cmd += ["-L", runtimePath.pathString, "-lPackageDescription"]`. The version selected in step 1 chooses *which* `PackageDescription` library to link.
3. The resulting executable is run in a sandbox (`Sandbox.apply(command: runCmd, ...)`), with a temp file path passed as an argument. The manifest, via `PackageDescription` machinery, writes its `let package = Package(...)` value as JSON to that path.
4. SwiftPM reads `<packageIdentity>-output.json` and feeds it to `ManifestJSONParser.parse()`, producing the structured `ManifestJSONParser.Result`. **The DSL is just a JSON-emitter dressed as a Swift program.**

`swift package dump-package` exposes step 4's JSON directly. `swift package describe` adds the *resolved* graph (after dependency resolution).

**The role of the magic comment** (from [SE-0152 Package Manager Tools Version](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0152-package-manager-tools-version.md), Motivation): *"This cannot be determined by a property on the Package object in the manifest itself, as we must know what compatibility version to interpret the manifest with before we have access to data specified by Swift code in the manifest."*

The magic comment is a **bootstrap signal** — it must be readable without running the file, because reading the file requires knowing it.

**Right**:
- One file, one value, one mental model. Consumer sees a single `Package(...)` literal.
- Bootstrap signal cleanly separated as a magic comment with a documented non-Swift rationale.
- DSL-emits-JSON architecture means the evaluator is a sandboxed subprocess — the consumer's Swift code cannot crash SwiftPM, cannot do I/O, cannot reach into the dependency graph it is currently declaring.
- String-based cross-references (`.product(name:package:)`) sidestep the chicken-and-egg of "I cannot `import` a package I haven't declared yet."

**Wrong**:
- Cross-references are *strings*. Typos surface only after resolution.
- `dependencies: [...]` repeats the same package name as `.product(... package:)`, requiring consumers to keep two strings in sync.

**Institute lesson**: The pattern that makes `Package.swift` work is **(magic-comment bootstrap) + (single Swift literal that emits a serialized intent value) + (string-keyed cross-references resolved post-eval)**. A `Lint.swift` shaped the same way is structurally feasible — but in the naive form, rule activations would be encoded as data (string identifiers), not as `import`s of products that don't yet exist. The Swift module system, however, has a *second* pattern available (covered in §"Theoretical Analysis" below) that lets us escape the string-reference constraint while keeping the bootstrap mechanism.

**Unifies deps + activation?** **Yes** — `dependencies` and `targets` (the activation/use surface) sit in the same `Package(...)` literal. Linkage is *by string* because the dependency's products don't exist when the file evaluates. This is the precise constraint a `Lint.swift` would inherit unless it adopts a two-phase pattern (covered below).

#### 1.2 SwiftLint `.swiftlint.yml`

**Consumer-facing syntax** (from realm/SwiftLint README):

```yaml
disabled_rules:
  - colon
  - control_statement
opt_in_rules:
  - empty_count
included:
  - Source
excluded:
  - Carthage
  - Pods
custom_rules:
  no_foundation_import:
    name: "Foundation import"
    regex: 'import Foundation\b'
    message: "Foundation imports forbidden in primitives layer."
    severity: error
    excluded: ["Tests/**"]
```

Three rule cohorts — *default rules* (~100), *opt-in rules* (~200), *analyzer rules* (5) — all hard-coded into the SwiftLint binary. **No first-class plugin mechanism**: per the README, "Swift custom rules" (non-regex) require building SwiftLint from source with Bazel against a fork.

**Right**: Single-file activation surface; clear three-mode model (`disabled` / `opt_in` / `only`); colocates file-scope (`included`/`excluded`) with rule-scope.

**Wrong**: No dep declaration at all — there is no concept of "this rule lives in some external package." Snake_case YAML keys are not type-checked against the rule registry until runtime. To ship a custom Swift rule, you maintain your own SwiftLint fork.

**Institute lesson**: SwiftLint shows the *shape* of declarative rule activation (`.yml` with three list-keys + per-rule sub-objects) but explicitly avoids the deps half. The pain it offloads onto Bazel-built forks is exactly the pain swift-linter aims to eliminate. Adopt SwiftLint's clean activation lists; reject its closed-world rule registry. The lesson is what *not* to do.

**Unifies deps + activation?** **No** — `.swiftlint.yml` only handles activation. The "deps" half has no answer.

#### 1.3 swift-format `.swift-format`

**Consumer-facing syntax** (from `swiftlang/swift-format/Documentation/Configuration.md`):

```json
{
    "version": 1,
    "lineLength": 100,
    "rules": {
        "AllPublicDeclarationsHaveDocumentation": true,
        "DoNotUseSemicolons": true,
        "OrderedImports": true,
        "AlwaysUseLowerCamelCase": false
    }
}
```

Rules are activated by setting their **PascalCase Swift type name** as a JSON key with a boolean. ~43 built-in rules per `Documentation/RuleDocumentation.md`. **Third-party rules: none.** No plugin mechanism; `nicklockwood/SwiftFormat`'s issue #256 ("Plug-in/Extension architecture") remains open across both Swift-formatter ecosystems.

**Right**: PascalCase-rule-name-as-JSON-key is *superior to SwiftLint's snake_case* — keys mirror Swift type names exactly. `dump-configuration` gives a copy-pasteable starting point.

**Wrong**: Closed catalog. No dep half at all. JSON has no expression-level customization, no comments, no computed values.

**Institute lesson**: Borrow the *naming convention* (rule names mirror the Swift witness that implements them — the institute's spec-mirroring instinct). Reject the closed-catalog architecture wholesale.

**Unifies deps + activation?** **No** — only activation, only for built-in rules.

### Group 2 — JS + Python lint/format ecosystems

#### 2.1 ESLint flat config (`eslint.config.js`, v9+, post-2024)

**Consumer-facing syntax** (from [ESLint docs](https://eslint.org/docs/latest/use/configure/configuration-files)):

```javascript
import examplePlugin from "eslint-plugin-example";
import { defineConfig } from "eslint/config";

export default defineConfig([
  {
    files: ["**/*.js"],
    plugins: { example: examplePlugin },
    extends: ["example/recommended"],
    rules: {
      semi: ["error", "never"]
    }
  },
]);
```

**Plugin activation mechanism**: Native ES module `import` statement. The imported object is bound to a local namespace key (`example`); rules reference that namespace as a prefix (`example/some-rule`).

**Motivation, verbatim** ([Nicholas C. Zakas, ESLint blog, Aug 2022 / updated Aug 2024](https://eslint.org/blog/2022/08/new-config-system-part-2/)):

> "one of our biggest regrets about eslintrc was recreating the Node.js `require` resolution in a custom way. This was a significant source of complexity and, in hindsight, unnecessary"

ESLint v9.0.0 (released [April 5, 2024](https://eslint.org/blog/2024/04/eslint-v9.0.0-released/)) made flat config the default and deprecated `.eslintrc`. ESLint v10 will remove `.eslintrc` entirely.

**Right**: Imports + activations in one JS file. The mental model is "this is just JavaScript" — the plugin object you imported is the plugin object you reference. No string indirection.

**Wrong**: The dep itself still lives in `package.json` (the npm install step). So source-of-truth for "which version of the plugin" is split.

**Institute lesson**: This is the strongest validation of the unified-single-file pattern. A `Lint.swift` that uses real `import RulePackage` statements (not string names) collapses the "declare + activate" layers into ordinary Swift. The user reads one file, sees real symbols, gets compile-time errors if a package isn't available. Swift's module system gives compile-time errors for missing or misspelled rule packages — a strictly stronger guarantee than ESLint's `package.json`-then-import dance.

**Unifies deps + activation?** **Partially** — activation is unified into JS; `package.json` install remains separate. swift-linter can go further by declaring deps inline in `Lint.swift` (since SwiftPM evaluates the manifest before linking).

#### 2.2 ESLint legacy `.eslintrc.*` (pre-v9, contrast case)

**Consumer-facing syntax** ([archived ESLint v8 docs](https://eslint.org/docs/v8.x/use/configure/configuration-files)):

```json
{
    "plugins": ["react"],
    "extends": ["plugin:react/recommended"],
    "rules": {
        "react/no-set-state": "off",
        "indent": ["error", 4]
    }
}
```

Plugin referenced as **bare string** (`"react"`); ESLint's bespoke resolver maps to npm package `eslint-plugin-react`. User must independently `npm install`.

**Wrong**: String-name indirection is the entire defect. Users hit "ESLint couldn't find the plugin 'react'" errors despite installing it, because resolution semantics differed by working directory, monorepo layout, `--resolve-plugins-relative-to`.

**Institute lesson**: Avoid the "rule package referenced by string" trap. If `Lint.swift` says `lint.plugins = ["primitives-tier"]`, the linter has to invent a resolver. If `Lint.swift` instead writes `import Primitives_Tier_Rules`, the Swift module system does the work.

**Unifies deps + activation?** **No** — deps in `package.json`, activations in `.eslintrc.json`, custom resolver bridges by string.

#### 2.3 Stylelint (`stylelint.config.js`)

**Consumer-facing syntax** (from [Stylelint docs](https://stylelint.io/user-guide/configure)):

```javascript
/** @type {import('stylelint').Config} */
export default {
  extends: "stylelint-config-standard",
  plugins: ["stylelint-order"],
  rules: {
    "order/properties-alphabetical-order": true,
    "color-no-invalid-hex": true
  }
};
```

**Wrong**: Even in the JS form, plugins are still referenced as strings (`"plugins": ["stylelint-order"]`), not as imports. Stylelint never crossed the bridge ESLint v9 did.

**Institute lesson**: JS-format alone isn't the win — what matters is whether the config *executes* imports or treats them as opaque names. A `Lint.swift` that listed rule packages as strings would inherit Stylelint's drawback, not ESLint flat's win.

**Unifies deps + activation?** **No** — strings in config, install in `package.json`.

#### 2.4 Prettier (`prettier.config.js`)

**Consumer-facing syntax** (from [Prettier plugins docs](https://prettier.io/docs/plugins)):

```json
{ "plugins": ["@prettier/plugin-xml", "prettier-plugin-tailwindcss"] }
```

Plugins referenced by string module name. Prettier defers to native `import()`. **No per-rule activation** — Prettier's [philosophy](https://prettier.io/docs/option-philosophy) rejects rule-level toggles entirely.

**Institute lesson**: Prettier confirms that *if you have no per-rule toggles*, the dep/activation pain shrinks dramatically. swift-linter has per-rule toggles (the whole "primitives tier bundle" concept), so this escape hatch is unavailable.

**Unifies deps + activation?** **No** — but the surface is small enough that the friction is bounded.

#### 2.5 Ruff (`pyproject.toml`)

**Consumer-facing syntax** (from [Ruff configuration docs](https://docs.astral.sh/ruff/configuration/)):

```toml
[tool.ruff]
line-length = 88
target-version = "py310"

[tool.ruff.lint]
select = ["E4", "E7", "E9", "F", "B"]
ignore = []

[tool.ruff.format]
quote-style = "double"
```

Rule families identified by two-letter prefixes (`E` = pycodestyle, `F` = Pyflakes, `B` = flake8-bugbear). No `pip install` step per family — Ruff bundles ~800 rules ported from upstream Python linters.

**Closed catalog — verbatim** ([Ruff FAQ](https://docs.astral.sh/ruff/faq/)):

> "Ruff does not yet support third-party plugins, though a plugin system is within-scope for the project."

> "Like Flake8, Pylint supports plugins (called 'checkers'), while Ruff implements all rules natively and does not support custom or third-party rules."

GitHub issue [astral-sh/ruff#283](https://github.com/astral-sh/ruff/issues/283) requests a plugin API; remains open.

**Right**: One TOML file. Zero dep declarations needed. Onboarding is `pip install ruff` + four lines.

**Wrong**: Closed catalog. The Institute's "primitives tier bundle" concept of pluggable rule packages is unexpressable in Ruff's model.

**Institute lesson**: Ruff is the extreme of the tradeoff curve — radical simplicity at the cost of extensibility. The choice is incompatible with the institute's three-tier rule-pack model. But Ruff's TOML-only ergonomics ARE achievable inside the open-catalog model *if* the plugin reference is a real symbol (Swift `import`) rather than a string.

**Unifies deps + activation?** **Yes** — but only because there are no deps to declare.

### Group 3 — Rust + other ecosystems

#### 3.1 Rust Clippy (`Cargo.toml` `[lints.clippy]`)

**Consumer-facing syntax** (from [Cargo manifest docs](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section), Rust 1.74+):

```toml
[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
enum_glob_use = "deny"
style = { level = "warn", priority = 1 }
correctness = { level = "deny", priority = 5 }
pedantic = "warn"
```

`priority` is a first-class field — lower-priority entries (groups like `pedantic`) emit before higher-priority specific lints, so a single specific override actually wins.

**Wrong**: Clippy lints are *baked into the Clippy binary*. You cannot ship a new rule as a crate.

**Institute lesson**: The Cargo `[lints.<tool>]` design is elegant *because* Clippy is monolithic. The `priority` field is the single most transferable idea: when activating a bundle (e.g., `primitives-tier-bundle`) and overriding a specific rule, deterministic priority ordering is non-negotiable; declaration order alone is fragile.

**Unifies deps + activation?** **No** — because deps don't exist for Clippy lints.

#### 3.2 Rust dylint (closest analog to swift-linter's plugin model)

**Consumer-facing syntax** (from [trailofbits/dylint README](https://github.com/trailofbits/dylint)):

```toml
# Cargo.toml
[workspace.metadata.dylint]
libraries = [
    { git = "https://github.com/trailofbits/dylint", pattern = "examples/general" },
    { git = "https://github.com/trailofbits/dylint", pattern = "examples/restriction/try_io_result" },
]
```

```toml
# dylint.toml — separate file, lint-specific parameters
[non_local_effect_before_unhandled_error]
work_limit = 1_000_000
```

**Right**: Dylint solves the dep-on-rule-package problem honestly. The `libraries = [...]` array IS the dependency declaration — `git`/`path`/`pattern` are full Cargo dependency syntax. Loading is dynamic via `cdylib`; the host (`cargo-dylint`) discovers the lints at runtime.

**Wrong**: Activation is *implicit* — declaring a library means "run all its lints." There is no per-rule on/off in the dylint config itself; you fall back to `#[allow(...)]` in source. The parameter file (`dylint.toml`) only handles config values, not enable/disable.

**Institute lesson**: Dylint is the strongest precedent for what swift-linter wants, but its weakness is instructive — it lets the dep side dictate everything and then has no place for granular activation. **swift-linter must avoid this trap.** The single `Lint.swift` must let users say both "depend on `swift-witnesses-primitives-linter`" AND "activate `naming` but not `exhaustiveness` from it." Per-rule on/off must be expressible.

**Unifies deps + activation?** **Partially** — deps in `Cargo.toml`, parameters in `dylint.toml`, activation implicit-by-dependency. Two-file model with activation underspecified.

#### 3.3 Roslyn analyzers (.NET)

**Consumer-facing syntax** (from [Microsoft docs](https://learn.microsoft.com/en-us/visualstudio/code-quality/roslyn-analyzers-overview)):

```xml
<!-- MyProject.csproj -->
<ItemGroup>
  <PackageReference Include="StyleCop.Analyzers" Version="1.2.0-beta.556" />
  <PackageReference Include="SonarAnalyzer.CSharp" Version="9.32.0.97167" />
</ItemGroup>
```

```ini
# .editorconfig
[*.cs]
dotnet_diagnostic.CA1822.severity = error
dotnet_analyzer_diagnostic.category-performance.severity = warning
dotnet_diagnostic.SA1101.severity = none
```

**Right**: Precedence rules are explicit — per-rule beats per-category beats per-all. Severity vocabulary is fixed (`error`/`warning`/`suggestion`/`silent`/`none`/`default`).

**Wrong**: Two files, two languages, two release cadences. The dep (`PackageReference`) brings in the analyzer assembly; the `.editorconfig` references rule IDs (`CA1822`, `SA1101`) the consumer must look up out-of-band. No IDE auto-completion ties `dotnet_diagnostic.???` to the just-added NuGet package. Bulk-mode flags in MSBuild silently override `.editorconfig` bulk options — a documented gotcha.

**Institute lesson**: **This is the negative example.** The split exists for historical reasons (`.editorconfig` predates Roslyn). swift-linter has no such legacy. The Microsoft precedence rules are worth borrowing wholesale; the two-file split is the anti-pattern swift-linter should reject.

**Unifies deps + activation?** **No** — two files, by design.

#### 3.4 Gradle `build.gradle.kts` (Kotlin DSL)

**Consumer-facing syntax** (from [Gradle Kotlin DSL docs](https://docs.gradle.org/current/userguide/kotlin_dsl.html)):

```kotlin
plugins {
    java
    application
    id("com.diffplug.spotless") version "6.25.0"
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}

dependencies {
    implementation("com.google.guava:guava:30.0-jre")
    testImplementation("junit:junit:4.13.2")
}

spotless {
    kotlin { ktlint("1.0.1") }
}

detekt {
    config.setFrom("$projectDir/detekt-config.yml")
    buildUponDefaultConfig = true
}
```

**Right**: Single Kotlin file, type-safe. The `plugins {}` block is evaluated *first* — Gradle resolves each `id("...")` against the Gradle Plugin Portal, downloads the plugin, and *then* exposes its DSL extensions (`spotless { ... }`, `detekt { ... }`) for the rest of the file to configure. **This is exactly the chicken-and-egg pattern swift-linter faces — and Gradle's answer is "evaluate `plugins {}` in a special early phase, then re-evaluate the rest with the plugin's contributed model in scope."**

**Wrong**: The `plugins {}` block has severe restrictions (no conditionals, no variables, no method calls beyond `id()`/`version()`/`apply()`). This is required for the two-phase evaluation. The error message when violated is one of Gradle's most-asked Stack Overflow questions.

**Institute lesson**: Gradle's two-phase trick is the engineering blueprint. swift-linter would do:

1. Parse `Lint.swift` `dependencies:` array as data (URLs + versions only — no Swift expressions referencing dep types).
2. Resolve and compile those deps.
3. Re-process `Lint.swift` with the dep modules in scope, so `rules: { ... }` can reference imported witness values.

This is the same trick SwiftPM already plays. Reusing that machinery is the natural path.

**Unifies deps + activation?** **Yes, completely** — one Kotlin file with deps + plugins + rule-config + tasks all in scope of each other after the two-phase eval. **Strongest engineering precedent.**

#### 3.5 Bazel `BUILD` / Buck2 `BUCK` (Starlark)

**Consumer-facing syntax** (from [Bazel docs](https://bazel.build/concepts/build-files)):

```python
# BUILD.bazel
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load("@build_bazel_rules_swift//swift:swift_binary.bzl", "swift_binary")

swift_library(
    name = "MyLibrary",
    srcs = ["MyLibrary.swift"],
)

swift_binary(
    name = "MyApp",
    srcs = ["main.swift"],
    deps = [":MyLibrary"],
)
```

```python
# MODULE.bazel — deps live here
bazel_dep(name = "rules_swift", version = "1.18.0", repo_name = "build_bazel_rules_swift")
```

**Right**: `BUILD` files are pure Starlark (a Python subset that evaluates to data). The `load()` directive is literal: "from this `.bzl` file, import these symbols." Once loaded, `swift_library` is a callable rule.

**Institute lesson**: The `load("@dep//path:file.bzl", "symbol")` pattern is the most explicit "dep + activation in one statement." Bazel's wisdom: **let the import statement bridge the gap**. Once a package is declared a dep, its rule-witness types are importable, and references to those witnesses *are* the activation.

**Unifies deps + activation?** **Partially** — dep declaration in `MODULE.bazel`, but `load()` + rule invocation in `BUILD` is the closest thing to "import-as-activation" in the survey.

#### 3.6 Nix flakes (`flake.nix`)

**Consumer-facing syntax** (from [Nix flakes docs](https://nix.dev/concepts/flakes)):

```nix
{
  description = "Hello World";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages.default = pkgs.stdenv.mkDerivation { /* ... */ };
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.gcc pkgs.gnumake ];
        };
      }
    );
}
```

**Right**: A flake is a single attribute set with exactly two meaningful keys: `inputs` (deps as URLs) and `outputs` (a function that receives the resolved inputs and returns derivations). **The chicken-and-egg is solved at the language level**: `outputs` is a function, so it cannot run until `inputs` are resolved. By the time the function body executes, `nixpkgs` is a bound name referring to the resolved input flake's outputs. References to inputs in outputs *can never fail with "input not declared"* — that would be an unbound variable.

**Wrong**: Nix is a foreign language with steep learning curve, lazy-evaluation surprises, and notoriously bad error messages. Flakes are still experimental.

**Institute lesson**: Nix flakes are the *purest* expression of "one file = deps + everything-built-from-deps." **Make outputs a function of inputs.** swift-linter's `Lint.swift` could mirror this — the file declares `dependencies: [...]` at top level, and the rule-activation section is a *closure* that receives the resolved dep modules as parameters. The type checker enforces that you cannot reference a lint package you didn't declare. Swift can express this directly: `Lint(dependencies: [...]) { /* ... */ }`.

**Unifies deps + activation?** **Yes, perfectly** — and arguably *better* than Gradle, because the function-of-inputs pattern uses language-level binding rather than a magic early-evaluation phase. **Closest match to swift-linter's question.**

#### 3.7 Deno (`deno.json` + URL imports)

**Consumer-facing syntax** (from [Deno docs](https://docs.deno.com/runtime/manual/getting_started/configuration_file/)):

```json
{
  "imports": {
    "@std/assert": "jsr:@std/assert@^1.0.0",
    "chalk": "npm:chalk@5"
  },
  "lint": {
    "include": ["src/"]
  }
}
```

```typescript
// main.ts — imports are URLs
import { assertEquals } from "@std/assert";
import { foo } from "https://deno.land/x/foo@v1.0/mod.ts";
```

URL imports in source files *are* the dependency declaration. Lint rules are built into Deno itself; no plugin system stable as of late 2024.

**Institute lesson**: The Deno lesson is *philosophical*, not technical. **Question the premise**: must `Lint.swift` be SwiftPM-compatible at all? If swift-linter ships its own evaluator (which it must, for the closure-of-deps pattern), the `Lint(...)` initializer is a swift-linter-defined type, not a SwiftPM type. That decoupling unlocks the cleaner DSL.

**Unifies deps + activation?** Side-steps the question.

### Cross-system summary

| System | Deps in file? | Activation in file? | Unified? | Activation pattern | Plugin model |
|--------|---|---|---|---|---|
| **SwiftPM `Package.swift`** | Yes | Yes | **Yes** | String-keyed `.product(name:package:)` | Magic-comment + DSL-emits-JSON + sandboxed eval |
| SwiftLint `.swiftlint.yml` | No | Yes | No | snake_case YAML keys | Bazel fork required |
| swift-format `.swift-format` | No | Yes | No | PascalCase JSON keys | None (closed) |
| **ESLint flat (`eslint.config.js` v9+)** | Indirect (`package.json`) | Yes | **Partially** | Native ES `import` + reference imported symbol | npm packages |
| ESLint legacy `.eslintrc.*` | No | Yes | No | String name + custom resolver | npm + string |
| Stylelint `stylelint.config.js` | No | Yes | No | String locater | npm + string |
| Prettier `.prettierrc` | No | Yes (no rules) | No | String name → native `import()` | npm + string |
| Ruff `pyproject.toml` | n/a (closed) | Yes | n/a | TOML family prefixes | None (closed) |
| Clippy `Cargo.toml [lints.clippy]` | n/a (closed) | Yes | n/a | TOML `priority: Int` | None (closed) |
| **Rust dylint `Cargo.toml + dylint.toml`** | **Yes** | Partial | Two-file | Implicit-by-dependency | Real Cargo deps via `[workspace.metadata.dylint]` |
| Roslyn `.csproj + .editorconfig` | Yes | Yes | No (two-file split) | Rule-ID keys in editorconfig | NuGet packages |
| **Gradle `build.gradle.kts`** | Yes | Yes | **Yes** | Two-phase eval: `plugins {}` early, then DSL in scope | Gradle Plugin Portal |
| Bazel `BUILD + MODULE.bazel` | Yes (in MODULE) | Yes | Partially | `load("@dep//...:file.bzl", "rule")` | Bazel modules |
| **Nix flakes `flake.nix`** | Yes | Yes | **Yes** | `outputs = inputs: ...` (function of inputs) | Nix inputs |
| Deno `deno.json + URL imports` | n/a (URL imports) | Limited | n/a | URL `import` in source | None for lints |

**Five systems unify deps + activation in one file: SwiftPM, Gradle, Nix flakes, ESLint flat (partially), dylint (two-file by convention).**

**Of these, Nix flakes is the purest match for swift-linter's question, Gradle is the strongest engineering blueprint, and SwiftPM is the proven mechanism we can reuse.**

---

## Theoretical Analysis

### The bootstrap problem

A linter with a pluggable rule-pack ecosystem has two distinct concerns in every consumer:

1. **Resolution layer** (data; declarative): which packages are needed? Pure data: URLs, paths, versions, products.
2. **Activation layer** (code; imperative): which rule witnesses from resolved products are activated, with what severity, on what paths?

These layers have different temporal phases:
- Resolution must happen BEFORE activation (deps must be fetched before their witnesses are accessible).
- Activation references symbols that come INTO existence as a result of resolution.

This is the **bootstrap problem**: the activation layer references types/values defined inside the packages declared by the resolution layer, but the resolution layer must complete before those types/values exist.

Generalizing from the prior art, three resolution patterns are known:

**Pattern A — Two-file split**: declare resolution in a file using ONLY the resolver's blessed module (e.g., `PackageDescription`, no consumer deps). Declare activation in another file compiled AFTER resolution. Examples: SwiftPM's `Package.swift + targets`, swift-linter's current `Lint/Package.swift + main.swift`, Roslyn's `.csproj + .editorconfig`.

**Pattern B — Magic-comment header + body**: declare resolution in comments at the top of an otherwise-Swift file. The body is compiled normally (after resolution). Examples: `swift-tools-version` comment, `swift-sh` shebang scripts, Nix `nix-shell` shebang, Java JEP-330 single-file source launch.

**Pattern C — AST-extracted resolution + body**: declare resolution as a syntactic substructure within the file (e.g., a top-level `let lint = Lint(dependencies: [...], ...)`). The resolution-handler parses the file via syntax-aware parser and extracts the dep declarations WITHOUT semantic resolution. Then materializes a scaffold for full compilation. Examples: Gradle's `plugins {}` block, Buck2/Bazel's `load(...)` directives, SwiftPM's own `dependencies:` argument extraction.

Pattern A is what swift-linter does today. Pattern C is what `Package.swift` does. Pattern B is what build scripts do.

### SwiftPM as a worked example of Pattern C

SwiftPM solves the bootstrap problem in a way directly transferable to swift-linter:

1. `Package.swift` imports ONLY `PackageDescription`, a stdlib-of-the-package-manager module shipped with SwiftPM. It does NOT import any of its declared deps.
2. SwiftPM compiles `Package.swift` against `PackageDescription` (always available). Runs it. Captures the resulting `Package` value via JSON serialization.
3. From the `Package` value, SwiftPM extracts `dependencies` and resolves them.
4. THEN SwiftPM uses `targets` information to compile the consumer's actual sources (which CAN import resolved-dep products).

The constraint: `Package.swift` itself cannot reference symbols from its own deps. Cross-references between deps and targets are *by string* (`.product(name:package:)`). The string mismatch surfaces at resolution time, not at manifest-compile time.

**The same pattern can support swift-linter's `Lint.swift`** with one important refinement: because the linter's rule activations are *also* Swift code (we want type-checked rule references), the consumer's `Lint.swift` can do something `Package.swift` cannot — **import the rule packs directly AS PART of the activation body**, after the deps are resolved. The two-phase evaluation makes this possible:

- **Phase 1 (dep extraction)**: parse `Lint.swift` syntactically (SwiftSyntax AST). Find the top-level `let lint = Lint(...)` declaration. Extract the `dependencies: [...]` argument. Each `.package(path:)` / `.package(url:)` is a dep. No semantic analysis needed; no compilation.
- **Phase 2 (compile + execute)**: generate a Package.swift in an eval-root with the extracted deps + LinterDescription. Copy `Lint.swift` as `Sources/Lint/main.swift`. Run `swift build`. SwiftPM resolves deps, compiles `Lint.swift` WITH the resolved products available (so `import Linter_Primitives_Rules` works), and the executable runs the linter against the consumer's source tree.

The key insight: **phase 1 is purely syntactic; phase 2 is fully type-checked.** Rule references in `rules:` are type-checked because phase-2 compilation happens after deps are resolved. The user gets compile-time safety on rule references, AND deps + activations live in one file.

### Existing institute infrastructure

The institute already has Pattern C implemented for general manifest evaluation — `swift-foundations/swift-manifests`:

**`Manifest.Load`** (`Sources/Manifest Loader/Manifest.Load.swift`) is a generic Swift-DSL evaluator. Given a manifest file path, a typed `Output` type (constrained to `JSON.Serializable`), and a `[Manifest.Dependency]` list:

1. Materializes a temporary eval-project at `\(root)/.swift-manifest/\(filename)/` with a generated `Package.swift` (declaring the supplied deps + a `Driver` target) and a generated `Driver.swift` (with `@main` that JSON-serializes the manifest's bound value to a known output path).
2. Copies the consumer's manifest file into the eval-project's `Sources/Driver/` directory.
3. Spawns `swift run --package-path <eval>` via `Process.Spawn`.
4. Reads the captured JSON output.
5. Decodes to `Output` via `JSON.Serializable`.

This IS the SwiftPM bootstrap pattern, generalized — a DSL-emits-JSON evaluator with sandbox-via-subprocess. The only thing missing for swift-linter's unified Lint.swift case is: **extract the deps from the consumer's `Lint.swift` itself**, rather than from a caller-supplied `[Manifest.Dependency]` list.

Adding that extraction step is a small change: a SwiftSyntax-based AST walker that finds `Lint(dependencies: [...])` and extracts `.package(...)` calls from the array. SwiftSyntax can do this without semantic analysis (so without compiling the file).

### Formal semantics sketch (per [RES-024])

Let a consumer's `Lint.swift` source be a triple `M = (H, D, A)` where:
- `H` is the header (any magic comments — minimally the `swift-linter-tools-version` directive).
- `D` is the syntactic set of dep declarations (`.package(path:)`, `.package(url:)` AST nodes appearing inside `Lint(...)`'s `dependencies:` argument).
- `A` is the remainder of the Swift program (imports + the body of `Lint(...)`'s `rules:` closure + any custom helpers).

The linter's evaluation is:

```
parse-version:   H ⟶ v                   (lexical scan of magic comment)
parse-deps:      M ⟶ D                   (SwiftSyntax AST extraction, syntactic only)
render-package:  D ⟶ P                   (generate Package.swift with D + LinterDescription)
resolve-build:   P, M ⟶ E                (SwiftPM resolve + compile; E is the executable)
                                          
execute:         E, paths ⟶ F            (run executable against paths; produce findings)
```

**Soundness**: If `parse-deps` extracts `D` and SwiftPM `resolve-build` succeeds with `D`, then every `import X` in `M` (the body of `A`) typechecks against the products of `D`. If they don't typecheck, SwiftPM build fails with a normal Swift error, surfaced to the user.

**Contract preserved**: every `.package(...)` syntactically present in `Lint.swift`'s `dependencies:` argument IS a dep; the order is preserved; products listed in each `.package` are required-dep contributions.

**Termination**: parse-deps is structurally recursive over the AST; render-package is a fold; resolve-build is bounded by SwiftPM's own resolution semantics (cycle/depth limits handled by SwiftPM).

**Wire format compatibility (residual concern)**: Parent-chain inheritance via the `// parent: <URL>` directive currently uses `Lint.Manifest` (JSON) as the cross-process wire format. Under the unified shape, the parent's `Lint.swift` still evaluates to a serializable `Lint.Configuration` value, which can be lifted to `Lint.Manifest` for cross-process transport at the parent boundary. The wire format remains; the consumer-facing shape collapses. The lift function is `Lint.Configuration → Lint.Manifest` by projecting each `.enable(rule)` to `rule.id.underlying` strings — already implemented in essence at `Lint.Manifest.serialize`.

---

## Shape Proposals

Five candidate shapes for a unified single-file `Lint.swift`, scored against the four user-specified optimization criteria plus the engineering criteria. All shapes target the swift-carrier-primitives canary case ("use the primitives tier bundle") for comparability against the 92-line baseline.

### Shape α — Declarative-data manifest (Package.swift-mimic, activations as string IDs)

```swift
// swift-linter-tools-version: 0.1

import LinterDescription

let lint = Lint(
    dependencies: [
        .package(path: "../../swift-primitives-linter-rules", products: ["Linter Primitives Rules"]),
    ],
    rules: [
        .bundle(package: "swift-primitives-linter-rules", name: "primitives"),
    ]
)
```

**Mechanism**: Lint.swift imports ONLY `LinterDescription` (a stdlib-of-the-linter module shipped with swift-linter, mirroring `PackageDescription`). The `Lint` initializer is description-only — no actual rule witnesses are referenced. Rule activations are encoded as data: a `(packageName: String, ruleNameOrBundleName: String)` pair. The linter, after `Manifest.Load`-style evaluation, fetches deps, then materializes a Stage-2 driver that imports the rule packs and matches the string references to witnesses via a runtime registry.

**Mirrors `Package.swift` exactly**. Total: ~10 lines for the canary case (5 functional + magic comment + import + license header).

**Pros**:
- Pure Pattern C; no Pattern B magic-comments needed beyond `swift-linter-tools-version`.
- Engine surgery minimal — reuses `Manifest.Load` machinery.
- Wire-format-stable across single-file and parent-chain (string IDs everywhere).
- Aligns 1:1 with `Package.swift` shape; learning curve near zero.

**Cons**:
- **No compile-time safety on rule references.** Typos in `name: "primitives"` surface at runtime as "rule bundle not found." This is the same trade-off `Package.swift` makes (`.product(name:)` is also a string), but for rule activations it's a regression vs the current nested-package shape's `Lint.Rule.Bundle.primitives.self`-style typed access.
- Custom rules become awkward — the user must author them as a separate package and reference by name from `Lint.swift`. The current shape lets custom rules live in the same `Lint/Sources/` tree.

### Shape β — Magic-comment header + Swift body

```swift
// swift-linter-tools-version: 0.1
// linter-dependencies:
//   - path: ../../swift-primitives-linter-rules
//     products: [Linter Primitives Rules]

internal import Linter
internal import Linter_Primitives_Rules

Lint.run {
    Lint.Rule.Bundle.primitives
}
```

**Mechanism**: Magic-comment header (post `swift-linter-tools-version`) declares deps in a structured comment block (parsed line-by-line, like `swift-sh` or JEP-330). The body is real Swift — imports rule packs directly, uses typed witness values in `Lint.run { ... }`. swift-linter parses the comment header to materialize Package.swift with the declared deps, then copies `Lint.swift` (minus the magic-comment header, or with it left as ordinary comments) as `main.swift` and compiles.

Total: ~9 lines for the canary case.

**Pros**:
- Compile-time safety on rule references (the body is real Swift, type-checked against resolved deps).
- Total line count is the lowest of all shapes.
- Body reads as ordinary Swift — adopters with zero linter-specific knowledge can read the body.

**Cons**:
- **Magic-comment-as-data feels brittle.** Deps live OUTSIDE the type system; tooling that wants to inspect them has to parse comments, not Swift. SwiftPM's single `// swift-tools-version` comment is a bounded exception (just version metadata); structured comment-blocks of dep data feel more fragile.
- **Cannot inherit Swift code-completion** for `.package(...)`-shaped completions on dep declarations.
- Inconsistent with `Package.swift` model — `Package.swift` puts EVERYTHING in the Swift value, not in comments.
- Comment-based dep parsing has poor failure modes (invalid YAML in comment? Trailing whitespace? Indentation rules?).

### Shape γ — AST-extracted deps + typed activation closure (RECOMMENDED)

```swift
// swift-linter-tools-version: 0.1

import LinterDescription
import Linter_Primitives_Rules

let lint = Lint(
    dependencies: [
        .package(path: "../../swift-primitives-linter-rules", products: ["Linter Primitives Rules"]),
    ],
    rules: {
        Lint.Rule.Bundle.primitives
    }
)
```

**Mechanism**: swift-linter parses `Lint.swift` via SwiftSyntax to extract the `dependencies:` argument (no compilation; pure AST). Generates eval-root Package.swift with extracted deps + `LinterDescription` (always added). Copies `Lint.swift` into `Sources/Lint/main.swift`. `swift run --package-path eval-root` compiles `Lint.swift` with deps resolved — `import Linter_Primitives_Rules` works because Linter Primitives Rules is now a resolved product. The executable's main is the consumer's `Lint.swift`; the generated driver is a minimal `@main` shim that invokes `Lint.run(lint, paths: CommandLine.arguments)`.

**The `LinterDescription` module** is a tiny shipped-with-swift-linter module providing only:
- `Lint` (the initializer + value type).
- `Lint.Dependency` (`.package(path:products:)`, `.package(url:_:products:)`).
- A `@resultBuilder` for the `rules:` closure that accepts `Lint.Rule.Configuration` and `[Lint.Rule.Configuration]` (bundles).
- Nothing else. It carries zero rule witnesses; it's pure description machinery.

Total: ~8 lines for the canary case (1 magic-comment + 2 imports + 6 declaration lines).

**Pros**:
- **Compile-time safety on rule references** (phase 2 compilation type-checks `Lint.Rule.Bundle.primitives` against the resolved `Linter_Primitives_Rules` module).
- **Compile-time safety on dep references** (`import Linter_Primitives_Rules` fails fast if the package isn't declared as a dep).
- **Single coherent Swift value** — deps and rules in the same `Lint(...)` initializer call, fully type-checked.
- **Mirrors `Package.swift` shape closely** — `Package(name:dependencies:targets:)` parallels `Lint(dependencies:rules:)`.
- **Reuses existing institute infrastructure** — `Manifest.Load`'s materialize-and-spawn mechanism is directly applicable.
- **Closest to Nix flakes pattern** — `rules:` closure is a function of resolved inputs; references to undeclared deps are unbound-symbol errors at phase-2 compile.
- **Custom rules in the same file** — the consumer can declare a `let myRule = Lint.Rule(id:, ...)` adjacent to the `lint` declaration; the executable target builds it.

**Cons**:
- Phase 1's AST extraction places **structural constraints** on the `dependencies:` argument: it must be a literal array of `.package(...)` calls. No dynamic computation, no conditionals (or at least, AST extraction must handle them deterministically). This is the same constraint `Package.swift` already places.
- Two compile passes per lint run (phase 1 SwiftSyntax parse + phase 2 SwiftPM build). Phase 1 is cheap (microseconds). Phase 2 is the same as the current nested-package shape's build — no regression.
- Requires shipping `LinterDescription` as a new module within `swift-linter` (engine).

### Shape δ — Pure config (TOML/YAML), no Swift code

```toml
# Lint.toml — no Swift at all
linter-tools-version = "0.1"

[[dependencies]]
path = "../../swift-primitives-linter-rules"

[rules]
"unchecked call site" = "warning"
"cardinal count minus one" = "warning"
"chained rawvalue access" = "warning"
# ... one entry per rule
```

**Mechanism**: Same as Shape α but using TOML/YAML instead of Swift. swift-linter parses the TOML, fetches deps, materializes a driver that maps the string IDs to witnesses.

**Pros**:
- Simplest possible parsing (no Swift compile at all in phase 1).
- Editor support for TOML/YAML is broadly available.

**Cons**:
- **Loses Swift entirely as the activation surface.** Custom rules cannot live in `Lint.swift` (because there's no `.swift`). Per-rule parameters that need Swift values (closures, computed paths) become impossible.
- **Diverges sharply from `Package.swift`.** Users must learn a second config format.
- **Loses the entire institute pattern** of "config is Swift evaluated against a description module." This is a regression vs `Package.swift`'s shape.
- **No path to a v2 typed surface** — once consumers write TOML, the activation surface is locked to data forever.

**Eliminated.** This is Ruff's shape; it works for Ruff because Ruff is closed-catalog. The institute is open-catalog; the cost is too high.

### Shape ε — Macro-driven build plugin

A `@LintManifest` macro attached to a `let` declaration that synthesizes Package.swift + main.swift behind the scenes:

```swift
@LintManifest
import Linter_Primitives_Rules

let lint = Lint(
    dependencies: [.package(path: "../../swift-primitives-linter-rules")],
    rules: { Lint.Rule.Bundle.primitives }
)
```

**Eliminated for structural reasons.** Macros operate at compile time WITHIN a Swift target. They cannot:
- Generate sibling files (only expand within a target).
- Emit `Package.swift` (a build-system artifact, not a Swift declaration).
- Be applied at the right time (the consumer's `Package.swift` must already exist to compile the macro — circular).

A SwiftPM build plugin could in principle scan for `Lint.swift` and synthesize the package scaffold, but it requires the CONSUMER's `Package.swift` to include the swift-linter build plugin — which is the same chicken-and-egg the unified shape is trying to solve. The build-plugin path also forces SwiftPM into the dispatching loop in ways that complicate the centralized swift-linter binary's role.

Shape γ subsumes the macro intent by treating the file's content as data (AST) without requiring macro expansion.

### Comparison

| Criterion | α (data) | β (magic-comment) | **γ (AST-extracted)** | δ (TOML) | ε (macro) |
|---|---|---|---|---|---|
| Lines of intent | 8 | 9 | 8 | 9 | 10 |
| Ease of use | High | High | **High** | High | n/a |
| Few moving parts | Yes (1 file) | Yes (1 file) | **Yes (1 file)** | Yes (1 file) | No (macro target) |
| Clean code | Med (string-id activations) | Med (magic comments) | **High (typed Swift)** | n/a (no Swift) | n/a |
| `Package.swift` alignment | **Perfect** | Weak (comments leak data) | **Strong** | None | None |
| Compile-time rule safety | **No** | Yes | **Yes** | No | n/a |
| Compile-time dep safety | Yes (description-only) | Yes (post-resolution) | **Yes (post-resolution)** | Yes | n/a |
| Custom rules inline | Awkward (sep package) | **Yes** | **Yes** | No | n/a |
| Engine surgery | Low (extend `Manifest.Load`) | Medium (header parser) | Medium (SwiftSyntax extractor + `LinterDescription` module) | Low (TOML parser) | High (build plugin + macro infrastructure) |
| Reuses existing infra | **High (`Manifest.Load`)** | Low (new header parser) | **High (`Manifest.Load` + SwiftSyntax)** | Low | n/a |

### Recommendation

**Shape γ — AST-extracted deps + typed activation closure.**

Reasons:

1. **It's the only shape that gives compile-time safety on rule references AND fits in one file.** Shape α (string IDs) loses rule safety. Shape β (magic-comment header) keeps the body type-safe but moves deps outside the type system — a regression in tooling support and consistency.

2. **It mirrors `Package.swift` most closely** (per the user's explicit alignment criterion). `Lint(dependencies:rules:)` parallels `Package(name:dependencies:targets:)`. The pattern is "single Swift literal evaluating to a description value", which is the institute's broader Swift-DSL idiom.

3. **It reuses the institute's existing infrastructure.** `Manifest.Load` already implements materialize-and-spawn. SwiftSyntax can do AST extraction. The new module `LinterDescription` is small (~50 lines of description types).

4. **It maps cleanly to the prior-art best practices.** Nix flakes' function-of-inputs pattern is realized by Swift's module system — `import Linter_Primitives_Rules` after deps resolve makes rule witnesses available as typed values. Gradle's two-phase eval is mirrored exactly. ESLint flat's "native imports as plugin activation" is the same insight.

5. **Migration is bounded.** The current nested-package consumers have 92 lines; the recommended shape has ~8. The engine work is additive (the existing nested-package path can be deprecated gradually).

Shape γ is the "perfect" form per the user's optimization criteria.

---

## Role distinction (added v1.1.0)

Implementation surfaced a conflation in the v1.0.0 migration analysis. There are **two distinct roles** a `Lint.swift` file can play, and they call for **different shapes**:

### Role A — Consumer `Lint.swift` (executable linter manifest)

Lives at the package root next to `Package.swift`. Examples: `swift-carrier-primitives/Lint.swift`, `swift-tagged-primitives/Lint.swift`. Its job is to **run the linter against the consumer's source tree**:

- Resolve SwiftPM deps (rule packs, optionally SwiftSyntax for inline custom rules).
- Materialize an eval-project that imports the resolved products as Swift modules.
- Reference rule witnesses by typed Swift value (e.g., `Lint.Rule.Bundle.primitives`, or a local `let myRule = Lint.Rule(...)`).
- Produce findings.

**Shape γ is the correct answer for Role A.** Validated end-to-end with the swift-carrier-primitives canary (2026-05-12): 8-line `Lint.swift` replaces a 92-line `Lint/{Package.swift, main.swift}` pair, byte-perfect parity vs. the nested-package path's findings, plus inline custom-rule support (`Lint.Rule(id:defaultSeverity:findings:)` declared at file scope and activated alongside bundled rules).

### Role B — Parent scaffold `Lint.swift` (wire-format policy declaration)

Lives in a public `.github/` repo and is **fetched over HTTP** by descendant `Lint.swift` files via the `// parent: <URL>` directive. Examples: `swift-institute/.github/Lint.swift`, `swift-primitives/.github/Lint.swift`. Its job is to **declare ecosystem-wide rule-activation policy** that descendants inherit; it does NOT run the linter.

The parent has no rule packs of its own to resolve. Its content IS a JSON snapshot — a `Lint.Manifest` value with rule IDs as strings, evaluated by the existing `Manifest.Load` subprocess loader, serialized for cross-process transport. The descendant — which DOES have rule packs declared in its Shape γ dependencies — looks up each parent rule ID against its local rule registry (the rules visible in its eval-project's compiled binary). This is the **lift** step (`Lint.Manifest → Lint.Configuration` via local registry).

**The `let manifest: Lint.Manifest` form is the correct answer for Role B.** Migrating scaffolds to Shape γ would add deps for no rule packs and force eval-project materialization on every parent fetch — pure cost, no benefit. The "inertness" critique applies only to using a parent AS a standalone linter; when consumed as wire-format policy by a descendant, the `let manifest` form is exactly the right shape.

### What this means

| Role | File location | Recommended shape | Migration required |
|---|---|---|---|
| **A — Consumer Lint.swift** | `<pkg>/Lint.swift` | Shape γ (typed Swift DSL) | Yes — 14 consumers in `swift-primitives/` migrate from `Lint/` nested-package |
| **B — Parent scaffold Lint.swift** | `<org>/.github/Lint.swift` | `let manifest: Lint.Manifest` (wire-format) | **None** — already in correct form |

The v1.0.0 doc framed Shape γ as a unifying form that subsumed the scaffolds. That was wrong. Shape γ and `let manifest` are **complementary** shapes for **different roles**, not competing options for the same role.

The mental model:

```
swift-institute/.github/Lint.swift          ← let manifest: Lint.Manifest (Role B; wire format)
                ▲ // parent: <URL>
swift-primitives/.github/Lint.swift         ← let manifest: Lint.Manifest (Role B; wire format)
                ▲ // parent: <URL>
swift-carrier-primitives/Lint.swift         ← Shape γ (Role A; executable linter)
   ├─ resolves deps via SwiftPM
   ├─ fetches + folds parent chain (wire-format Manifests)
   └─ lifts parent IDs against local rule registry; runs
```

---

## Migration Analysis

### Engine surgery (Role A — Shape γ dispatch)

1. **New type: `Lint.Dependency`** (~80 LOC, public surface in the `Linter` product). Carries `.package(path:products:)`, `.package(url:from:products:)`, `.package(url:_:_:products:)` factories.

2. **New `Lint.run(dependencies:rules:)` overload** (~10 LOC, public). The `dependencies:` argument is consumed syntactically at phase 1 (AST extraction) and effectively no-op at phase 2 runtime; the trailing closure is `@Array<Lint.Rule.Configuration>.Builder`.

3. **SwiftSyntax dep-extractor** (~250 LOC, `Lint.SingleFile.Extractor` in `Linter Core`). Parses consumer's `Lint.swift`, finds top-level `Lint.run(dependencies: [...])` call, walks the array literal extracting `.package(...)` arguments syntactically. Returns `[Lint.SingleFile.PackageDependency]`.

4. **Eval-project materializer** (~170 LOC, `Lint.SingleFile.Materializer`). Materializes at `<consumerRoot>/.swift-lint/eval/`: generates `Package.swift` with `swift-linter` + consumer-declared deps; copies `Lint.swift` as `Sources/Lint/main.swift`; applies ecosystem `SwiftSetting`s.

5. **Detection + dispatch** (~80 LOC, `Lint.SingleFile.detect` + `Lint.SingleFile.dispatch`). Detect magic-comment header; full pipeline: read → extract → materialize → spawn `swift run --package-path <eval> Lint`.

6. **CLI integration** (~20 LOC change in `Linter CLI.swift`). Detect Shape γ first; fall through to existing nested-package and legacy single-file paths.

7. **Parent-chain wiring** (v1.1.0 follow-up; NOT in v1.0.0 implementation): extend `Lint.SingleFile.dispatch` to parse `// parent: <URL>` directives, resolve via `Manifest.Resolver<Lint.Manifest, Lint.Configuration>`, fold into a single `Lint.Manifest`, serialize to temp JSON, pass to dispatched executable via `SWIFT_LINTER_PARENT_MANIFEST` env var. The consumer's `Lint.run` builds a local registry from collected rule witnesses, reads the parent Manifest, lifts via `Lint.Configuration.lift(manifest:registry:)`, and threads as `inheriting:`. Estimated ~150 additional LOC.

Engine work actual (v1.0.0 implementation, excluding parent-chain): **~610 LOC across 7 new files + 3 edits.** Build clean; canary parity validated.

### Scaffold migration (Role B)

**None.** The Tier 1/Tier 2 scaffolds (`swift-institute/.github/Lint.swift`, `swift-primitives/.github/Lint.swift`) stay in the `let manifest: Lint.Manifest` wire-format. They are consumed by descendant Shape γ files via the `// parent: <URL>` directive once parent-chain wiring lands.

### Consumer cascade (Role A)

14 existing `Lint/` packages across swift-primitives at HEAD 2026-05-12. Each is currently 70–90 lines. Under Shape γ, each becomes ~8–18 lines (including license header + inline custom rules if any).

Migration is mechanical and grep-able: for each `Lint/Package.swift`, the consumer extracts the path/url deps array; for each `Lint/Sources/Lint/main.swift`, the consumer extracts the `Lint.run(...)` body; both merge into a single `Lint.swift` at the consumer root, the `Lint/` directory is removed.

### Backwards-compat strategy

The Shape γ path is **additive**. CLI detection priority order:

1. `Lint.swift` with `// swift-linter-tools-version:` magic-comment → Shape γ (new path).
2. `Lint/Package.swift` → nested-package (existing path; preserved during transition).
3. Legacy `Lint.swift` with `let manifest: Lint.Manifest` → wire-format Manifest path (inert when used as consumer; reactivated when used as parent via `// parent:` directive).

Cohort migration order: ship Shape γ engine (DONE 2026-05-12) → validate canary (DONE) → wire parent-chain (in progress) → migrate consumer cascade in waves → optionally deprecate nested-package path after cohort completes (no urgency; both paths can coexist indefinitely).

---

## Open Questions / Risks

### Q-OPEN-1: SwiftPM `Package.resolved` chain integrity

Each consumer's `Lint.swift` declares deps that SwiftPM resolves. The materialized eval-project gets its own `Package.resolved`. Is this a meaningful concern (separate `Package.resolved` per Lint.swift means non-deterministic dep versions across consumers)? Should the eval-project's `Package.resolved` be committed alongside `Lint.swift`?

**Tentative answer**: yes, commit `Lint.resolved` (or `.swift-linter/Package.resolved`) alongside `Lint.swift` for the same reason consumers commit `Package.resolved` alongside `Package.swift`. The eval-root is gitignored, but the resolved file specifically is checked in. Open for follow-up.

### Q-OPEN-2: IDE indexing of `Lint.swift`

When the user opens `Lint.swift` in Xcode/VS Code, the IDE will try to resolve `import Linter_Primitives_Rules`. Without the eval-project materialized, the import is unresolved → red squiggles.

**Tentative answer**: ship a Lint.swift companion mode for SourceKit-LSP that recognizes `swift-linter-tools-version` magic-comment and consults the materialized eval-project for symbol resolution. Until that ships, users see import-resolution errors in their editor, but the lint run itself works. Bounded annoyance.

### Q-OPEN-3: Build performance — re-compile on every lint?

Phase 2 compiles `Lint.swift` against resolved deps every lint run. SwiftPM caching helps (incremental builds), but a cold first run is slow.

**Tentative answer**: the same cost the current nested-package path already pays. SwiftPM's build cache makes warm runs fast. No regression vs status quo.

### Q-OPEN-4: Custom rules in `Lint.swift` itself

If a consumer wants to author a custom rule inline (rather than in a separate package), can they declare it in `Lint.swift`?

```swift
import LinterDescription
import SwiftSyntax  // for the visitor

let myRule = Lint.Rule(
    id: "no foo in bar",
    defaultSeverity: .warning,
    findings: { source, severity in /* visitor */ }
)

let lint = Lint(
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0", products: ["SwiftSyntax"]),
    ],
    rules: {
        Lint.Rule.Configuration.enable(myRule)
    }
)
```

**Tentative answer**: yes, this works under shape γ. The custom rule is just a top-level Swift declaration in the same file. SwiftSyntax is a declared dep. The visitor body lives inline. The trade-off: the rule is re-compiled on every lint run. For small custom rules (~50 lines) the cost is bounded; for large rules, the consumer can still extract them to a sibling package.

### Q-OPEN-5: Per-rule parameters at consumer call site

Some rules need parameters (e.g., `compound_identifier`'s allowlist). The predecessor research's Q3 recommended `.enable<R>(_ instance: R)` factory. Under shape γ, this works directly — the consumer instantiates the rule with kwargs before passing to `.enable`. No change.

### Q-OPEN-6: Wire format and parent-chain

Shape γ uses `Lint.Configuration` as the in-process value. Parent-chain inheritance via `// parent: <URL>` directive still needs a wire format — the parent's `Lint.swift` evaluates to a `Lint.Configuration`, which must be serialized for cross-process transport. The existing `Lint.Manifest` is the natural wire format (it's already JSON-serializable). The lift `Configuration → Manifest` projects each `.enable(rule)` to `rule.id.underlying` strings; reverse lift `Manifest → Configuration` happens at the child's process boundary via local rule registry — already implemented in essence at `Lint.Driver.configuration(from:parent:)`.

### Q-OPEN-7: What about `swift-linter` the central CLI?

If every consumer's `Lint.swift` is its own executable target via the eval-project pattern, what's the role of the centralized `swift-linter` binary?

**Tentative answer**: `swift-linter` becomes the orchestrator. It (1) detects consumer's `Lint.swift`, (2) parses it via SwiftSyntax, (3) materializes the eval-project, (4) invokes `swift run`, (5) collects findings. The orchestrator binary IS swift-linter; the per-consumer executable is the consumer's linter. This matches the current nested-package architecture, just with a single source file as input.

### Q-OPEN-8: Centralized CI integration

How does CI integrate? Currently the centralized swift-ci.yml runs `swift-linter` against each consumer. Under shape γ, the same flow works: `swift-linter <consumer>` → detects `Lint.swift` → materializes → runs. No CI change needed.

### Q-OPEN-9: Sandboxing

`Manifest.Load`'s current implementation uses `Process.Spawn.run` without explicit sandbox (only the SwiftPM sandbox during `swift run`). SwiftPM itself sandboxes manifest evaluation — does the eval-project's `swift run` inherit that sandbox? Concrete sandboxing semantics for the eval-root need verification.

### Q-OPEN-10: Tools-version evolution

`// swift-linter-tools-version: 0.1` is the bootstrap signal. Future versions of `LinterDescription` may add fields. Backwards compat is bounded by versioning — old `Lint.swift` files declare `0.1`, swift-linter ships the `0.1` `LinterDescription` library for them, new files declare `0.2` etc. Same model as SwiftPM. No new innovation needed.

---

## Outcome

**Status**: RECOMMENDATION.

This research recommends Shape γ — single-file `Lint.swift` with AST-extracted deps + typed activation closure — as the canonical consumer-facing manifest for swift-linter.

**Key claims**:

1. The unified-single-file shape is structurally feasible. The institute already has the materialize-and-spawn infrastructure (`Manifest.Load`).
2. Shape γ achieves all four user-specified optimization criteria: ease of use (8 lines vs 92), few moving parts (1 file), clean code (typed Swift, no string indirection), alignment with `Package.swift` (same DSL bootstrap pattern).
3. Compile-time safety on rule references is preserved (phase 2 compilation type-checks against resolved deps).
4. Engine surgery is bounded (1–2 weeks). Consumer migration is mechanical and grep-able.
5. The recommendation SUPERSEDES the predecessor research's two-shape coexistence frame and ADDRESSES the deprecation-decision doc's Option D as the correct path forward.

**Decision the principal still owns**:

- Authorize the engine work (1–2 weeks).
- Authorize the cohort migration (2–4 weeks calendar).
- Schedule the Tier 1/Tier 2 scaffold migration before flipping `swift-linter` public.

This research does NOT itself ship the change. It documents the recommended shape, the engineering plan, and the open questions. Implementation gates on principal authorization + the swift-linter 0.1.0 tag + the cohort migration handoff.

**Open questions for follow-up** (none block the recommendation; all are scoped to implementation):

- Q-OPEN-1: `Package.resolved` chain integrity (likely answer: commit `Lint.resolved`).
- Q-OPEN-2: SourceKit-LSP integration for IDE support (separate dispatch).
- Q-OPEN-9: Sandboxing semantics for the eval-root (verification spike).
- Q-OPEN-10: Tools-version evolution policy (mirror SwiftPM's model).

The remaining open questions (Q-OPEN-3, 4, 5, 6, 7, 8) are answered in the body above.

---

## Cross-References

**Predecessor**:
- `swift-institute/Research/2026-05-07-swift-linter-consumer-syntax.md` (v1.0.1) — this research EXTENDS it and SUPERSEDES its Q1c "cross-shape composition" section.

**Decision documents addressed**:
- `swift-institute/Research/2026-05-07-single-file-lint-swift-deprecation-decision.md` — Shape γ is the unified Option D; A/B/C collapse.

**Engineering infrastructure cited**:
- `swift-foundations/swift-manifests/Sources/Manifest Loader/Manifest.Load.swift` — the existing materialize-and-spawn evaluator that Shape γ reuses.
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.Driver.swift` — the current orchestrator that extends with the Shape γ dispatch.
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift` — the wire-format type that remains for parent-chain transport.
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.swift` — the in-process Configuration type that the Shape γ executable produces.
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.swift` — the witness-value rule type that activations reference.

**Consumer baselines**:
- `swift-primitives/swift-carrier-primitives/Lint/{Package.swift, Sources/Lint/main.swift}` — the 92-line canary baseline.
- `swift-primitives/swift-tagged-primitives/Lint/{Package.swift, Sources/Lint/main.swift}` — the PoC baseline with custom-rule wiring.
- `swift-institute/.github/Lint.swift`, `swift-primitives/.github/Lint.swift` — Tier 1/Tier 2 canonical scaffolds.

---

## References

### Swift ecosystem
- [SwiftPM source — ManifestLoader.swift](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageLoading/ManifestLoader.swift)
- [SwiftPM source — ToolsVersionParser.swift](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageLoading/ToolsVersionParser.swift)
- [SE-0152 Package Manager Tools Version](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0152-package-manager-tools-version.md)
- [SwiftPM Setting the Swift tools version](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/settingswifttoolsversion/)
- [realm/SwiftLint README](https://github.com/realm/SwiftLint)
- [SwiftLint Rule Directory](https://realm.github.io/SwiftLint/rule-directory.html)
- [swiftlang/swift-format](https://github.com/swiftlang/swift-format)
- [swiftlang/swift-format — Documentation/Configuration.md](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md)
- [swiftlang/swift-format — RuleDocumentation.md](https://github.com/swiftlang/swift-format/blob/main/Documentation/RuleDocumentation.md)
- [nicklockwood/SwiftFormat issue #256 — Plug-in/Extension architecture](https://github.com/nicklockwood/SwiftFormat/issues/256)

### JS + Python lint/format ecosystems
- [ESLint flat config docs](https://eslint.org/docs/latest/use/configure/configuration-files)
- [ESLint v9.0.0 release announcement (Zakas, 2024)](https://eslint.org/blog/2024/04/eslint-v9.0.0-released/)
- [ESLint blog — "The new ESLint config system Part 2" (Zakas, 2022)](https://eslint.org/blog/2022/08/new-config-system-part-2/)
- [ESLint v8 archived configuration docs](https://eslint.org/docs/v8.x/use/configure/configuration-files)
- [Stylelint configuration docs](https://stylelint.io/user-guide/configure)
- [Prettier configuration docs](https://prettier.io/docs/configuration)
- [Prettier plugins docs](https://prettier.io/docs/plugins)
- [Ruff configuration docs](https://docs.astral.sh/ruff/configuration/)
- [Ruff FAQ — closed-catalog quote](https://docs.astral.sh/ruff/faq/)
- [astral-sh/ruff#283 — plugin system feature request](https://github.com/astral-sh/ruff/issues/283)
- [LWN — "Ruff: a fast Python linter" (Vervloesem, 2023)](https://lwn.net/Articles/930487/)

### Rust + other ecosystems
- [Cargo `[lints]` reference](https://doc.rust-lang.org/cargo/reference/manifest.html#the-lints-section)
- [Clippy configuration](https://doc.rust-lang.org/clippy/configuration.html)
- [trailofbits/dylint](https://github.com/trailofbits/dylint)
- [Microsoft Roslyn analyzers overview](https://learn.microsoft.com/en-us/visualstudio/code-quality/roslyn-analyzers-overview)
- [Microsoft .NET analyzer configuration](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-options)
- [Gradle Kotlin DSL docs](https://docs.gradle.org/current/userguide/kotlin_dsl.html)
- [Gradle plugin basics](https://docs.gradle.org/current/userguide/plugin_basics.html)
- [Bazel BUILD file concepts](https://bazel.build/concepts/build-files)
- [bazelbuild/rules_swift](https://github.com/bazelbuild/rules_swift)
- [Nix flakes concept](https://nix.dev/concepts/flakes)
- [Nix flake command reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html)
- [Deno configuration file](https://docs.deno.com/runtime/manual/getting_started/configuration_file/)

### Local files
- `/Users/coen/Developer/swift-foundations/swift-linter/Package.swift`
- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter Core/Lint.Driver.swift`
- `/Users/coen/Developer/swift-foundations/swift-linter/Sources/Linter Core/Lint.Manifest.swift`
- `/Users/coen/Developer/swift-foundations/swift-manifests/Sources/Manifest Loader/Manifest.Load.swift`
- `/Users/coen/Developer/swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.swift`
- `/Users/coen/Developer/swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Configuration.swift`
- `/Users/coen/Developer/swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.Configuration.swift`
- `/Users/coen/Developer/swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.Bundle.swift`
- `/Users/coen/Developer/swift-primitives/swift-carrier-primitives/Lint/Package.swift`
- `/Users/coen/Developer/swift-primitives/swift-carrier-primitives/Lint/Sources/Lint/main.swift`
- `/Users/coen/Developer/swift-primitives/swift-tagged-primitives/Lint/Package.swift`
- `/Users/coen/Developer/swift-primitives/swift-tagged-primitives/Lint/Sources/Lint/main.swift`
- `/Users/coen/Developer/swift-institute/.github/Lint.swift`
- `/Users/coen/Developer/swift-primitives/.github/Lint.swift`
