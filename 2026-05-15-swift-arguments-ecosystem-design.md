# swift-arguments Ecosystem Design

<!--
---
version: 1.0.17
last_updated: 2026-05-18
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---

Changelog:
- v1.0.17 (2026-05-18): **B4 closeout — three tokenization edge cases (glued short-option value, negative-number positional, did-you-mean suggestions)**. The A1 parity audit identified three small gaps as load-bearing for parity with real-world POSIX tooling (`cc -Dfoo=bar`, `seq -5 5`, did-you-mean on typos). All three close in one subagent dispatch. Single-release framing — no half-implementations, no TODO markers. Test totals: swift-arguments 179/179 (+9 from 170 baseline). Foundation-free at the main targets. No cross-package edits surfaced.
  - **Gap 1 — Glued short-option value (POSIX 12.2 Guideline 6)**. The `-Dfoo=bar`, `-Xmx2g`, `-fvalue` form was already correctly handled by the existing L3 dispatch composed in v1.0.13/B2:
    - L2 tokenizer emits `.shortFlag('D')` + `.shortValue("foo=bar")` for `-Dfoo=bar` (Guideline 6 concatenated form).
    - L3 ``Argument/Tokenizer/Default`` maps to `.shortCluster("D")` + `.value("foo=bar")` (both sharing the source argv element's range).
    - In ``Command/Schema/ParseVisitor/applyShortCluster``, the splice-fold check ("is the single-char cluster a value-taking option?") suppresses the splice because `-D` IS a value option, leaving the cluster as `"D"`. The single-char dispatch then matches the short option `-D` and ``consumeOptionValue`` consumes the adjacent `.value("foo=bar")` as the option's value.
    - **No implementation change**. Three new tests in `Tests/Command Integration Tests/Tokenization.Parse.Tests.swift` lock the behaviour: `-Dfoo=bar` binds `"foo=bar"` to a `-D` short option, `-Xmx2g` binds `"mx2g"` to a `-X` short option, and `-fvalue` (the original Guideline-6 single-char case) regression-checks the splice fold.
  - **Gap 2 — Negative-number positional heuristic**. The forms `seq -5 5`, `bc -2`, `-3.14` were previously rejected as `unknownShortOption` because the L2 tokenizer correctly classifies a digit-led argv element as a short flag (POSIX 12.2 Guideline 3 — alphanumeric short-flag character includes digits). Two-part shape:
    - New helper `hasShortBinding(for: Character) -> Bool` on ``Command/Schema/ParseVisitor`` returns whether the schema declares any short option / repeatable option / flag / count-flag bound to the digit character.
    - The main parse loop's `.shortCluster(cluster)` branch now checks: when the cluster's first character is a digit AND `hasShortBinding(for:)` is false AND a positional slot still pending (cursor < positionals.count OR positionalMany != nil), the argv element is reconstructed as a positional value (`"-" + cluster` plus any adjacent `.value` sharing the same source range — `"-3.14"` for `.shortCluster("3")` + `.value(".14")`). The token(s) are consumed via ``applyPositional`` and dispatch advances past them.
    - Schema-explicit-wins: when the schema DOES declare a short binding for the digit (e.g. a Bool flag named `-5`), `hasShortBinding(for:)` returns `true`, the heuristic suppresses, and dispatch proceeds via the standard ``applyShortCluster`` path. This preserves the contract that schema-declared bindings always win over the heuristic.
    - Tests: 3 new tests in `Tests/Command Integration Tests/Tokenization.Parse.Tests.swift` — `-5` binds Int positional value `-5`; `-3.14` binds Float positional value `-3.14`; `-5` as a declared Bool flag fires the flag (schema-explicit wins).
  - **Gap 3 — Did-you-mean suggestions on unknown name throws**. The `.unknownLongOption` and `.unknownSubcommand` cases gain an optional `suggestion: String?` payload carrying the closest-edit-distance declared name. Five-part shape:
    - New `Command.Diagnostic.Suggestion` enum (in `Command Core/Command.Diagnostic.Suggestion.swift`, ~110 LoC) carrying two static helpers:
      - `closest(to:among:) -> String?` — picks the closest candidate by Levenshtein edit distance, returning `nil` when no candidate is within the threshold `max(2, query.count / 3)` (same length-relative threshold swift-argument-parser's `UsageGenerator.swift` uses).
      - `editDistance(_:_:) -> Int` — Levenshtein distance via two-row dynamic-programming (O(m·n) time, O(min(m, n)) space).
    - `Command.Error.unknownLongOption(name:position:)` becomes `(name:position:suggestion:)` — payload-changing breaking API change, acceptable pre-tag (no external consumers).
    - `Command.Error.unknownSubcommand(name:position:)` likewise becomes `(name:position:suggestion:)`.
    - At every throw site (one in `applyLong`, one in `dispatchSubcommand`, plus the dispatchSubcommand root-level branch in the same file), the visitor computes the suggestion via `Command.Diagnostic.Suggestion.closest(to:among:)` and threads it into the throw. The visitor gains a `declaredLongOptionNames()` helper that collects long names from every entry kind (options, repeatable options, flags, count-flags, inverted flags' true/false names, enumerable cases) plus the built-in `"help"` / `"version"` (the latter only when `rootVersion` is non-empty).
    - `Command.Diagnostic.message(for:)` renders the suggestion when present: `"Error: Unknown option '--buld' (did you mean '--build'?)."` and `"Error: Unknown subcommand 'clne' (did you mean 'clone'?)."`. Nil suggestions render the plain "Unknown option / subcommand" message unchanged.
    - Existing test sites that constructed these errors directly (`Command.Error.Tests.swift`, `Command.Diagnostic.Tests.swift`) updated to pass `suggestion: nil` at the call sites. Existing tests that pattern-match without payload bindings (`Repeat.Parse.Tests`, `OptionGroup.Parse.Tests`, `Version.Parse.Tests`) work unchanged. Git.Parse.Tests' `case let .unknownSubcommand(name, _)` updated to `case let .unknownSubcommand(name, _, _)` for the new payload arity.
    - Tests: 3 new tests in `Tests/Command Integration Tests/Tokenization.Parse.Tests.swift` — `--buld` against a schema with `--build` carries `suggestion: "build"`; `clne` against subcommands `["clone", "commit", "checkout"]` carries `suggestion: "clone"`; `--xyz` against the same `--build`-only schema carries `suggestion: nil` (no candidate within threshold).
  - **LoC delta**:
    - `+~110 LoC` `Sources/Command Core/Command.Diagnostic.Suggestion.swift` (new file — Levenshtein + closest-match helpers).
    - `+~15 LoC` `Sources/Command Core/Command.Error.swift` (payload signature changes + doc comments for the two updated cases).
    - `+~15 LoC` `Sources/Command Core/Command.Diagnostic.swift` (suggestion-rendering branches in `message(for:)`).
    - `+~75 LoC` `Sources/Command Schema/Command.Schema.ParseVisitor.swift` (numeric-positional heuristic in the main loop + `hasShortBinding(for:)` helper + `declaredLongOptionNames()` helper + suggestion-threading at 3 throw sites + payload widening at the same 3 sites).
    - `+~280 LoC` across 2 new test files (`Tokenization.swift` fixtures + `Tokenization.Parse.Tests.swift` tests).
    - `+~25 LoC` updates to existing test files for the new payload arity (Command.Error.Tests, Command.Diagnostic.Tests, Git.Parse.Tests).
    - Total: ~520 LoC.
  - **Architectural notes**:
    - Gap 1 demonstrates that the v1.0.13 splice-fold design was already complete for the glued-value POSIX 12.2 Guideline-6 forms; the audit identified this as a gap but the implementation was already correct. Tests now lock the behavior so future refactors don't silently regress.
    - Gap 2's heuristic placement at the top of the dispatch loop's `.shortCluster` branch (rather than inside ``applyShortCluster``) keeps `positionalCursor` and `positionalMany` access local — `applyShortCluster` doesn't need new parameters. The schema-explicit-wins property holds because the heuristic check (`!hasShortBinding(for:)`) gates the re-route.
    - Gap 3's suggestion threshold `max(2, query.count / 3)` matches swift-argument-parser's `UsageGenerator` heuristic. For very short queries (≤6 characters), the threshold is 2 — generous enough to suggest typo fixes without false positives. For longer queries, the threshold grows proportionally. The Levenshtein implementation uses the two-row form to keep memory bounded; for typical CLI vocabularies (a few dozen option names, all shorter than ~20 characters), the algorithm completes in negligible time.
    - The payload-changing API breaks on `.unknownLongOption` / `.unknownSubcommand` are absorbed pre-tag (no external consumers). Once swift-arguments tags v0.1.0, payload changes become breaking and require a SemVer-aware migration plan.

- v1.0.16 (2026-05-18): **B3 closeout — `validate()` hook, `.default` subcommand modifier, `Command.Diagnostic` + `Command.main(_:)` runner, auto-derived help defaults, plus `Process.exit(_:)` consumer surface**. Four CLI-ergonomic gaps surfaced by the M1 retarget arc + parity audit close in a single subagent dispatch. Single-release framing — no half-implementations, no TODO markers. Test totals: swift-process 21/21 (+1 from 20 baseline structural test), swift-arguments 170/170 (+22 from 148 baseline). Foundation-free at the main targets. Lint-clean. No cross-package edits surfaced outside the two planned packages.
  - **Stage 1 — `swift-process` ↳ `Process.exit(_:)` consumer surface** (the missing L3-unifier method completing the platform stack for process termination):
    - New file `Sources/Process/Process.Exit.swift` (~60 LoC) — `Process.exit(_:)` static method, platform-conditional with two `#if` branches:
      - POSIX (Darwin / Glibc / Musl): imports `POSIX_Kernel_Process`; dispatches to `POSIX.Kernel.Process.Exit.now(_:) -> Never` which pass-throughs to `ISO_9945.Kernel.Process.Exit.now(_:)` (L2-canonical wrapping `_exit(2)`).
      - Windows: imports `Windows_Kernel_Process`; dispatches to `Windows.Kernel.Process.Exit.now(_:) -> Never` which typealiases to `Windows.\`32\`.Kernel.Process.Exit.now(_:)` (L2-canonical wrapping `ExitProcess`). Signed `Int32` argument maps via `UInt32(bitPattern:)` for the Win32 `UINT` parameter; negative-code semantics preserved.
    - New file `Tests/Process Tests/Process.Exit.Tests.swift` (~30 LoC) — single structural compile-time test (`Process.exit(_:)` as a typed `(Int32) -> Never` function value). The function cannot be invoked from a test suite — it would terminate the test process — so the suite exercises reachability via type-checking only.
    - Package.swift unchanged. The existing `POSIX Kernel` umbrella dep re-exports `POSIX_Kernel_Process` transitively; `Windows Kernel Process` is already a direct dep for `Process.Spawn.Capture.Windows`. No new product wiring needed.
    - LoC delta: ~90 net (60 source + 30 test).
    - Test count: 21/21 (+1 from baseline 20).
  - **Stage 2 — `swift-arguments` ↳ four gaps**:
    - **Gap 1 — `validate()` post-decode hook landed**. Conformers of `Command.\`Protocol\`` can now enforce cross-field invariants that the schema cannot encode structurally (e.g., "exactly one of `--from-file` / `--from-stdin`"). Two-part shape:
      - `Command.\`Protocol\`` gains a `mutating func validate() throws(Command.Error)` REQUIREMENT in `Command.Protocol.swift` (the requirement is necessary for witness-table dispatch — without it the generic-`C` call site in `Command.parse` resolves to the extension default statically and the conformer's override never runs). 
      - `Command.Validate.swift` provides the no-op default via a `@inlinable` extension. Conformers SHADOW by declaring their own `validate()` on the concrete type.
      - `Command.parse(_:from:initial:)` invokes `root.validate()` after `visitor.finalize()` and before returning. Errors bubble as `Command.Error`.
      - **Compiler-bug postscript**: the first version of this gap (B3 attempt v1, predecessor to v1.0.16) crashed with SIGILL because incremental-build artifacts were stale across the protocol-requirement / extension-default shape. A clean rebuild after the rule-conformance edits resolved the crash and tests pass green. The reliable workaround for similar future arc situations: `swift package clean` between protocol-requirement edits and incremental test runs. The SIGILL was not a structural defect in the requirement+default shape; it was a swift-package incremental-build artifact bug.
      - Tests: 3 new tests in `Tests/Command Integration Tests/Validate.Parse.Tests.swift` — default no-op, shadowed-throws cross-field, shadowed-passes positive case.
    - **Gap 2 — `.default` modifier on `Command.Subcommand.Case` landed**. Schemas can now mark one Case per Group as the default, dispatched when argv supplies no subcommand name. Two-part shape:
      - `Command.Subcommand.Case` gains an `isDefault: Bool` stored property (default `false`) and a fluent `var default: Self { get }` modifier (backticked at the declaration site for the reserved-word). The modifier returns a copy with `isDefault = true`.
      - `Command.Subcommand.Binding` protocol gains an `isDefault: Bool` requirement so the existential carrier exposes the flag (otherwise the heterogeneous `[any Binding<Root>]` list cannot filter for defaults).
      - `Command.Subcommand.Group` initializers (both direct-array and Builder-closure form) validate at-most-one-default via a static `checkAtMostOneDefault` helper that `preconditionFailure`s on violation — schema construction is a compile-time-shaped concern; runtime fallthrough to argv dispatch would mask a programmer error.
      - `ParseVisitor.dispatchSubcommand` updated: when argv is exhausted without a subcommand name AND the group declares a default binding, dispatch the default with empty sub-argv; otherwise existing `.missingSubcommand` behavior. `.helpRequested` re-routing through `.helpRequestedForSubcommand` is preserved (mirrors the standard dispatch path).
      - Tests: 3 new tests in `Tests/Command Integration Tests/DefaultSubcommand.Parse.Tests.swift` — default dispatches on empty argv, explicit subcommand overrides default, no-default fixture still throws `.missingSubcommand`.
    - **Gap 3 — `Command.Diagnostic` helpers + `Command.main(_:)` runner landed**. Consumer-facing entry-point ergonomics reduced from ~25 LoC to 3 LoC (`@main + static func main() async { await Command.main(MyCmd.self, initial: MyCmd()) }`). Three-part shape:
      - `Command.Diagnostic` enum (in `Command Core/Command.Diagnostic.swift`, ~150 LoC) carrying two static helpers:
        - `message(for:) -> String` — human-readable rendering for every `Command.Error` case. Help / version cases render their carried text directly (no `"Error:"` prefix); all other cases render with `"Error: "` prefix.
        - `exitCode(for:) -> Int32` — canonical mapping: help / version → 0, `.exit(code:_)` carries through, argv-syntactic errors (unknown / missing / invalid / `.validationFailed` / tokenizer) → 64 (BSD `EX_USAGE`), `.argument`-wrapped → 1.
      - `Command.main<C: Command.\`Protocol\`>(_ commandType:initial:arguments:) async -> Never` (in `Command/Command.Main.swift`, ~110 LoC including doc comments) — the convenience runner that parses argv, runs, renders any error, and exits with the canonical code via `Process.exit(_:)`. The umbrella `Command` target gains a new `swift-process` package dep + `Process` product dep edge to compose the runner.
      - **Stderr handling deficiency noted**: the ecosystem currently has no Foundation-free stderr write surface; `swift-io` and `swift-console` do not expose one. The v1 runner emits diagnostics via `Swift.print(_:)` to stdout. Real Unix tools route errors to stderr — a v2 follow-up will add proper stderr support once `swift-io` or `swift-console` grows a Foundation-free write API. Filed as a follow-up direction item (provisional D15).
      - **Module-name collision detail**: `Process` umbrella re-exports `Strings` (via `Kernel`), and `Strings` re-exports `String_Primitives.String` (a `~Copyable, @unsafe` struct). At the runner's call sites `String(describing:)` would resolve to the non-Copyable shadowing type and fail to compile. Fixed by spelling `Swift.String(describing:)` and `[Swift.String]` explicitly at the relevant call sites.
      - Tests: 10 new tests in `Tests/Command Core Tests/Command.Diagnostic.Tests.swift` — 5 message-rendering tests (unknown option, validation failure, version, exit-with-message, missing-subcommand-lists-available) + 5 exit-code-mapping tests (help/version → 0, exit-carries-code, argv-syntactic errors → 64, argument-wrapped → 1). Command.main itself cannot be unit-tested directly (it terminates the process); structural compile-time confidence from the runner's compose chain (parse → diagnose → exit) is sufficient for v1.
    - **Gap 4 — Auto-derive default-value description in help text landed**. Consumer ergonomics: schemas no longer need to repeat the default value as a string (`help: .init(defaultDescription: "2")`) when the seed `initial` value carries the canonical default. Six-part shape (Option A confirmed by the brief):
      - New `serialize(_:into:initial:)` overload on `Command.Help<Root>` that threads `initial: Root` through the visitor. The original `serialize(_:into:)` is preserved verbatim (backward-compatible — declarations whose `defaultDescription` is `nil` continue to emit no default line).
      - `Command.Help<Root>.Visitor` gains an optional `initial: Root?` stored property and a new `init(configuration:initial:)` constructor.
      - `Command.HelpDefault` enum (in `Command Help/Command.Help.Default.swift`, ~120 LoC) carrying the shared `inject(_:initial:keyPath:)` + `render<V>(_:)` helpers. The per-binding rules per the brief's table:
        - `Positional<V>` / `Option<V>` (non-Optional / non-Array): render `(default: \(String(describing: value)))`.
        - `Positional.Many<V>` / `Option.Many<V>`: render only when the initial array is non-empty.
        - Plain `Flag<Bool>`: never render — present/absent semantics is what `Flag` models.
        - `Flag.Count<Int>`: render only when the initial counter is non-zero (suppresses `(default: 0)`).
        - `Flag.Inverted<Bool>`: render the long-option name matching the initial value (e.g., `(default: --no-feature)` when `initial = false`).
        - `Flag.Enumerable<E>`: render the case-flag name of the initial enum case (e.g., `(default: --add)` for `Operation.add`).
        - `Option<V?>` with `nil`-initial: never render.
        - `Option<V?>` with `.some(v)` initial: render `(default: \(String(describing: v)))`.
      - **User-precedence preservation**: when `help.defaultDescription` is non-`nil` (user explicitly supplied), the auto-derivation is skipped. The user's string takes priority over the auto-derived one in every case.
      - **OptionGroup propagation**: `Command.HelpOptionGroupRowCollector<G>` gains a `initial: G?` slot; the parent visitor slices its own `initial[keyPath: outerKeyPath]: G` before constructing the fragment collector so OptionGroup sub-fields ALSO pick up auto-derived defaults. Nested OptionGroups recurse the slice transitively.
      - **Sub-command help symmetry**: `Command.Subcommand.Help.Visitor` and `Command.Subcommand.Help.OptionGroupRowCollector` mirror the same shape (`initial: Root?` slot + `inject(_:initial:keyPath:)` helper) via a parallel `Command.Subcommand.HelpDefault` enum in the Schema target. The duplication is intentional per the v1 layering note — the Schema target must remain dependency-free of the Help target.
      - **Render-path expansion**: the help-text render code in `Command.Help.Visitor.render()` and `Command.Subcommand.Help.Visitor.render()` previously emitted `(default: …)` only on `.option` rows; expanded to also emit on `.positional` / `.positionalMany` (in ARGUMENTS section) and `.optionMany` / `.flag` / `.flagCount` / `.flagInverted` / `.flagEnumerable` rows (in OPTIONS section). Pre-existing tests using user-supplied `defaultDescription:` on non-`.option` rows would have produced no default-line render in v1.0.15; v1.0.16 honors them — no test broke from this change.
      - Tests: 6 new tests in `Tests/Command Help Tests/Command.Help.AutoDefault.Tests.swift` — Int default auto-derived for Option, String default auto-derived for Positional, Bool flag default suppressed, Optional<Int> nil-default suppressed, Optional<Int> some-default rendered, no-initial overload preserves v1.0.15 behavior.
  - **LoC delta** (Stage 1 + Stage 2 combined):
    - `swift-process`: +90 LoC (60 source + 30 test).
    - `swift-arguments`:
      - +1 package dep on `swift-process` in `Package.swift` (1 new umbrella-target product dep edge).
      - +~50 LoC in `Command.Protocol.swift` (added `validate()` requirement + extended docs).
      - +~80 LoC in `Command.Validate.swift` (new file).
      - +~80 LoC in `Command.Subcommand.Case.swift` (added `isDefault` field, init param, `default` modifier, expanded docs).
      - +~15 LoC in `Command.Subcommand.Binding.swift` (added `isDefault` requirement + doc).
      - +~50 LoC in `Command.Subcommand.Group.swift` (added precondition-helper + adjusted both init signatures).
      - +~30 LoC in `Command.Schema.ParseVisitor.swift` (default-binding dispatch branch).
      - +~20 LoC in `Command.Parse.swift` (validate-after-finalize wiring).
      - +~150 LoC in `Command.Diagnostic.swift` (new file).
      - +~110 LoC in `Command.Main.swift` (new file).
      - +~120 LoC in `Command.Help.Default.swift` (new file).
      - +~120 LoC in `Command.Subcommand.HelpDefault.swift` (new file).
      - +~100 LoC adjustments in `Command.Help.swift`, `Command.Help.Visitor.swift`, `Command.Help.OptionGroupRowCollector.swift`, `Command.Subcommand.Help.Visitor.swift`, `Command.Subcommand.Help.OptionGroupRowCollector.swift` (each picks up the `initial: T?` slot + render-path expansion for default lines).
      - +~280 LoC across 4 new test files (Validate, DefaultSubcommand, Command.Diagnostic, Command.Help.AutoDefault).
    - Total: ~1300 LoC across both packages.
  - **Architectural notes**:
    - The platform stack `Process.exit(_:)` completion is structurally important — every CLI consumer needs an exit primitive, and `Process` was the natural seat (L3-unifier) for it. The L3-policy chain (`POSIX.Kernel.Process.Exit.now`, `Windows.Kernel.Process.Exit.now`) and the L2-canonical wrappers (`ISO_9945.Kernel.Process.Exit.now`, `Windows.\`32\`.Kernel.Process.Exit.now`) were already in place; v1.0.16 just adds the consumer-ergonomic flat method on the L3-unifier.
    - The Validate hook's protocol-requirement + extension-default shape is the only structural choice that lets generic dispatch reach a conformer's override. The "extension-only + shadow" shape suggested in earlier B3 drafts cannot work for generic dispatch (Swift's static dispatch resolves through the protocol's extension, not the conformer's concrete method). The SIGILL crash that the brief warned about was an incremental-build artifact, not a structural defect.
    - `Command.main(_:)`'s stderr-deficiency note formalizes a v2 follow-up direction (provisional D15) — the institute ecosystem will eventually grow a Foundation-free stderr write surface, and at that point the runner can route diagnostics correctly.
    - Gap 4's design choice (extend the Visitor with `initial: Root?` + per-binding-type rules in `HelpDefault`) preserves the design-doc §3.6 Serializer-protocol shape — the existing `serialize(_:into:)` overload is preserved verbatim; the new overload is purely additive. Consumers writing custom Visitors against `Command.Schema.Visitor` are unaffected (the visit-method signatures are unchanged; only the visitor's own state is enriched).

- v1.0.15 (2026-05-18): **Path C closeout — `Argument.Flag.Enumerable` refines `Finite.Enumerable` (case-(c) ecosystem reuse)**. The A1 parity audit (v1.0.13) introduced `Argument.Flag.Enumerable` at L1 as a standalone protocol with `CaseIterable, Hashable, Sendable` plus two CLI-specific requirements (`flagName(for:)`, `help(for:)`). The shape duplicated `Finite.Enumerable` (also L1, in `swift-finite-primitives`), which already provides the structural spine of "type with finitely many indexed inhabitants" (CaseIterable + Sendable + `count` / `ordinal` / `init(_unchecked:ordinal:)`). Path C unifies the two: `Argument.Flag.Enumerable` now **refines `Finite.Enumerable`** and inherits the spine; a new CaseIterable-default bridge at `swift-finite-primitives` derives `count` / `ordinal` / `init(_unchecked:ordinal:)` automatically for any conformer whose `AllCases` is a `RandomAccessCollection` indexed by `Int` (the common enum case with synthesized `[Self]` allCases). Consumer ergonomics unchanged — a CLI enum still writes `: Argument.Flag.Enumerable` and supplies only `flagName(for:)` + `help(for:)`.
  - **L1 finite-primitives surface** (additive, non-breaking):
    - New file `Sources/Finite Primitives Core/Finite.Enumerable+CaseIterable.swift` — provides default `count` / `ordinal` / `init(_unchecked:ordinal:)` on `Finite.Enumerable where AllCases: RandomAccessCollection, AllCases.Index == Int, Self: Equatable`. The constraint set is load-bearing:
      - `AllCases.Index == Int` disambiguates from the in-package default `allCases: Finite.Enumeration<Self>` (whose `Index == Index<Self>`, not `Int`), keeping existing `Tagged<Tag, Ordinal>` conformers on the explicit-witness path.
      - `Self: Equatable` is required by `firstIndex(of:)`; a `CaseIterable` Swift `enum` is `Equatable` by synthesis. The bridge does not add the Equatable requirement to `Finite.Enumerable` itself — it's a constraint on the default extension only.
    - Existing explicit conformers (`Bit`, `Bit.Order`, `Sign`, `Polarity`, `Boundary`, `Parity`, `Endpoint`, `Bound`, `Ternary`, `Monotonicity`, `Gradient`, `Comparison`, `Axis`, `Phase`, `Theme`, `Tagged<Tag, Ordinal>`) are unaffected — Swift's member lookup prefers their conformance-extension witnesses over the default extension.
    - Test count: 79/79 unchanged.
  - **L1 argument-primitives surface** (single source-breaking change — pre-tag, no external consumers):
    - `Argument.Flag.Enumerable` declaration switches from `: CaseIterable, Hashable, Sendable` to `: Finite.Enumerable, Hashable`. `CaseIterable` and `Sendable` are inherited via `Finite.Enumerable`; only `Hashable` remains as an explicit additional requirement (kept for trivially-indexable dispatch storage).
    - Two new transitive dependencies on the `Argument Flag Primitives` target: `swift-finite-primitives` package + `Finite Primitives Core` product.
    - `Argument Primitives Test Support` target additionally depends on `Finite Primitives Core` so tests can `import Finite_Primitives_Core` to spell out the inherited bridge surface (`Cardinal`, `Ordinal`).
    - `Argument.Flag.Enumerable.swift` adds `public import Finite_Primitives_Core` (under [PLAT-ARCH] `MemberImportVisibility`).
    - Test count: 72/72 (+5 from 67 v1.0.14 baseline). The 5 new tests demonstrate the structural refinement: bridged `count`, bridged `ordinal`, bridged `init(_unchecked:ordinal:)`, bridged `init?(_:)`, and a generic-function probe showing that an `Argument.Flag.Enumerable` conformer (the test enum `Operation`) type-checks where any `Finite.Enumerable` is expected.
  - **L3 swift-arguments surface**: unchanged. The L3 binding-aware `Command.Flag.Enumerable<Root, E: Argument.Flag.Enumerable>` only uses `flagName(for:)` and `help(for:)` from `E`; the inherited `Finite.Enumerable` requirements are provided by the CaseIterable bridge for enum conformers. L3 test count: 148/148 unchanged.
  - **No consumer ergonomics regression**: a Swift `enum` declared `: Argument.Flag.Enumerable` writes exactly the same `flagName(for:)` + `help(for:)` it wrote in v1.0.14. The CaseIterable bridge supplies the inherited `Finite.Enumerable` requirements transparently. Verified end-to-end via the existing `Operation` test fixture in `Argument.Flag.Enumerable.Tests.swift`.
  - **Architectural notes**:
    - Path C is a case-(c) ecosystem reuse win: a near-duplicate L1 protocol now refines its sibling rather than re-stating its requirements. The corpus eliminates one duplicate enumeration concept.
    - The CaseIterable bridge is a defensible standalone addition to `swift-finite-primitives` independent of `Argument.Flag.Enumerable` — it lowers the conformance ceremony for new enum conformers ecosystem-wide.
    - The single source-breaking change (protocol parent list) is pre-tag and has no external consumers; safe to bake into v1.
  - **LoC delta**:
    - `swift-finite-primitives`: +99 LoC (1 new file: `Finite.Enumerable+CaseIterable.swift`).
    - `swift-argument-primitives`: +4 LoC in `Package.swift` (1 new package dep + 2 new target deps); +25/-9 LoC in `Argument.Flag.Enumerable.swift` (refinement + expanded docs); +47 LoC in `Argument.Flag.Enumerable.Tests.swift` (5 new tests + 1 import line).
    - `swift-foundations/swift-arguments`: 0 LoC. No L3 edits required.
  - **No cross-package edits** beyond the three planned packages (`swift-finite-primitives`, `swift-argument-primitives`, `swift-foundations/swift-arguments`). Other `Finite.Enumerable` conformers across the ecosystem (e.g., `Theme: Finite.Enumerable` at `swift-color-standard`, `Axis: Finite.Enumerable` at `swift-dimension-primitives`) are structurally unaffected — they retain their explicit witnesses and the bridge does not shadow them.
- v1.0.14 (2026-05-18): **B2 Gap 6 closeout — `transform:` closure escape hatch landed across all four binding types**. With the upstream `swift-array-primitives` regression resolved separately by the principal, the deferred Gap 6 work now lands cleanly. Single-release framing — no TODO markers, no half-implementations. L3 tests: 148/148 (140 baseline + 8 new transform tests). L1 unchanged at 67/67. Foundation-free at the main targets. No cross-package edits surfaced during the implementation; all work is contained within `swift-foundations/swift-arguments`.
  - **Gap 6 — `transform:` closure escape hatch** — four new init overloads on `Command.Positional<Root, V>`, `Command.Option<Root, V>`, `Command.Positional<Root, V>.Many`, and `Command.Option<Root, V>.Many` that drop the `V: Argument.Codable` constraint and accept a custom parse closure `transform: @Sendable (String) throws(Command.Error) -> V`. Unlocks binding to value types the consumer does not own — `Foundation.URL`, third-party value types — where retrofitting an `Argument.Codable` conformance is impossible.
  - **Type-level constraint relaxation** — the type-level `where V: Sendable & Equatable & Argument.Codable` on all four binding types is moved to a per-init constraint, applied only on the `Argument.Codable`-driven default initializer. The struct's stored properties drop the Codable requirement entirely. Each binding type now stores a `parse: @Sendable (String) -> V?` closure that is the canonical workhorse — both initializers funnel through it. The Codable-driven init sets `parse = { V(argument: $0) }`; the transform-closure init sets `parse = { try? transform($0) }`. The visitor's apply closure consults `entry.parse(value)` instead of calling `V.init(argument:)` directly, so the visitor implementation is V-agnostic.
  - **Visitor protocol generalization** — `Command.Schema.Visitor`'s four value-bearing visit methods (`visit(positional:)`, `visit(positionalMany:)`, `visit(option:)`, `visit(optionMany:)`) drop the `V: Argument.Codable` constraint, retaining only `V: Sendable & Equatable`. All visitor implementations (`Command.Schema.ParseVisitor`, `Command.Schema.OptionGroupForwarder`, `Command.Help.Visitor`, `Command.HelpOptionGroupRowCollector`, `Command.Subcommand.Help.Visitor`, `Command.Subcommand.Help.OptionGroupRowCollector`) updated symmetrically. Source-breaking for external Visitor implementors, but per the v1.0.11 DEV3 precedent, no such consumer exists pre-v1; "single release perfect" framing bakes the relaxation into v1.
  - **Closure shape rationale** — `@Sendable (String) throws(Command.Error) -> V` chosen over `@Sendable (String) -> V?` because the throwing form lets the user surface domain-specific `Command.Error` values (e.g., `.validationFailed(reason:)` with custom diagnostics) at the call site. Internally the closure is wrapped as `parse: @Sendable (String) -> V?` via `try?` — this preserves the existing `false → .invalidValue(name:, value:, position:)` translation pattern in the visitor, so the user's throw cleanly degrades into the standard parse-failure path with the binding's name and the offending token's position injected by the visitor. The user's typed-throw provides expressiveness at the API surface without forcing the user to know the name/position context.
  - **New L3 surface**:
    - `Command.Positional<Root, V>.init(_:name:valueName:arity:visibility:help:transform:)` — escape-hatch initializer for non-Codable types.
    - `Command.Option<Root, V>.init(_:name:valueName:arity:visibility:help:environmentVariable:transform:)` — same for options. Env-var fallback also routes through `transform`.
    - `Command.Positional<Root, V>.Many.init(_:name:valueName:arity:visibility:help:transform:)` — same for array-positionals.
    - `Command.Option<Root, V>.Many.init(_:name:valueName:arity:visibility:help:transform:)` — same for repeatable options.
    - Each binding type also gains an `@usableFromInline internal let parse: @Sendable (String) -> V?` stored property (implementation detail).
  - **Tests added** (8 tests in 1 new suite + 1 new fixture file):
    - `Tests/Command Integration Tests/Transform.swift` — fixture types (`TransformedHost: Sendable, Equatable` non-Codable value type; four schema-bearing root types covering Positional, Option, Positional.Many, Option.Many).
    - `Tests/Command Integration Tests/Transform.Parse.Tests.swift` — 8 tests covering successful parse + malformed-input rejection for each of the four bindings.
  - **LoC delta**:
    - Production: ~270 LoC added across 4 binding-type files (init overloads + stored `parse` closure + docs); ~80 LoC delta in 6 visitor implementations (closure-routing + constraint relaxation).
    - Tests: ~260 LoC added (1 fixture file + 1 test file).
  - **No cross-package edits** — work fully contained in `swift-foundations/swift-arguments`. L1 (`swift-argument-primitives`) unchanged.
- v1.0.13 (2026-05-18): **B2 schema-node expressiveness bundle — Gaps 1–5 landed; Gap 6 deferred; verification BLOCKED by transitive-dep regression**. Five additional schema-node types extending the L3 binding-aware schema to cover the day-one CLI expressiveness gaps real consumers hit. Single-release framing: each fix is structurally complete, no TODO markers, no half-implementations. Verification blocked by a pre-existing build regression in `swift-array-primitives` (`Array: Collection.Remove.Last` empty conformance missing `static func last(_:)` witness) that surfaced after `swift package clean` invalidated cached artifacts — the issue exists independently of swift-arguments and reproduces in the standalone `swift-array-primitives` build. **Status: code complete, build blocked, tests written but unrunnable.**
  - **Gap 1 — `Command.Positional.Many<Root, V>`** — array-positional binding for `mycli file1 file2 file3 …` shape. Nested as `extension Command.Positional` so the type lives at `Command.Positional<Root, V>.Many` and inherits the outer generic params. Defaults to `.atLeast(0)` arity (zero-or-more, rest-positional). Conforms to `Command.Schema.Node` via dedicated `visit(positionalMany:)` method on the visitor protocol. `ParseVisitor` rejects multiple `.Many` per schema with `.validationFailed(reason:)` (greedy-consumption ambiguity); when mixed with fixed `Command.Positional` siblings the fixed slots consume first, remainder streams into `.Many`. Arity bounds validated at `finalize()`.
  - **Gap 2 — `Command.Option.Many<Root, V>`** — repeatable-option binding for `mycli --tag a --tag b --tag c` shape. Nested as `extension Command.Option`. Each argv occurrence appends one parsed value to the bound `[V]` field. `environmentVariable` fallback deferred to v2 — the splitting semantics (comma-separated vs. repeated env reads) are undefined; the `.Many` init signature omits the env-var parameter to avoid surfacing the unresolved decision.
  - **Gap 3 — `Command.Flag<Root>.Count`** — count-flag binding for `-vvv` verbosity shape. Binds `WritableKeyPath<Root, Int>`. Each long occurrence (`--verbose --verbose --verbose`) or short-cluster character (`-vvv`) increments the bound counter by one. Initial value preserved when no occurrences.
  - **Gap 4 — `Command.Flag<Root>.Inverted`** — explicit on/off long-flag pair. Two ``Inversion`` strategies: `.prefixedNo` (`--feature` / `--no-feature`) and `.prefixedEnableDisable` (`--enable-feature` / `--disable-feature`). Registers two long-option strings (derived via the `Inversion.trueName` / `falseName` accessors) on the schema's dispatch path; last argv occurrence wins.
  - **Gap 5 — `Command.Flag<Root>.Enumerable<E>`** — enum-of-flags pattern (mutually exclusive). At L1 ships new `Argument.Flag.Enumerable` protocol (refines `CaseIterable, Hashable, Sendable` with required static `flagName(for:)` → `Argument.Name.Long` and `help(for:)` → `Argument.Help`). At L3 binds `WritableKeyPath<Root, E>` and registers one long-option per enum case in the parse dispatch. Last occurrence wins (no v1 `FlagExclusivity` parameter). Mirror reflection avoided by making `flagName(for:)` an explicit static requirement.
  - **L1 surface** (`swift-argument-primitives`):
    - New protocol `Argument.Flag.Enumerable: CaseIterable, Hashable, Sendable` with `static func flagName(for:) -> Argument.Name.Long` and `static func help(for:) -> Argument.Help` requirements.
    - 4 new tests in `Argument Flag Primitives Tests/Argument.Flag.Enumerable.Tests.swift`. L1 total: 67/67 (+4 from 63 B1 baseline). **L1 tests pass independently.**
  - **L3 surface** (`swift-arguments`):
    - `Command.Positional<Root, V>.Many` — array-positional binding.
    - `Command.Option<Root, V>.Many` — repeatable-option binding.
    - `Command.Flag<Root>.Count` — count-flag binding.
    - `Command.Flag<Root>.Inverted` + `Command.Flag<Root>.Inverted.Inversion` — inverted-flag binding pair.
    - `Command.Flag<Root>.Enumerable<E: Argument.Flag.Enumerable>` — enum-of-flags binding.
    - `Command.Schema.Visitor` protocol gains 5 new `visit(...)` requirements: `visit(positionalMany:)`, `visit(optionMany:)`, `visit(flagCount:)`, `visit(flagInverted:)`, `visit(flagEnumerable:)`. Source-breaking for external Visitor implementors, but per the v1.0.11 DEV3 precedent, no such consumer exists pre-v1.
    - `Command.Help.Visitor`, `Command.Subcommand.Help.Visitor`, the two row collectors, and `Command.Schema.OptionGroupForwarder` updated symmetrically across the 5 new node types.
    - Help text USAGE / ARGUMENTS / OPTIONS sections render new shapes: `.Many` shows `<value>...` ellipsis; `.Count` shows `--verbose...` ellipsis; `.Inverted` shows `--feature/--no-feature` pair; `.Enumerable` emits group-header + per-case rows.
    - `Command.HelpEnumerableCase` + `Command.Subcommand.Help.EnumerableCase` non-generic carrier types added (mirrors the `Command.HelpRow` / `Command.Subcommand.Help.Row` duplication pattern from v1.0.11 DEV1; one type per target since Schema can't depend on Help).
    - `Command.Flag.BoundRoot` public typealias added — break circular-typealias detection that would fire if Enumerable's Schema.Node conformance wrote `typealias Root = Root`. Consumers do NOT reference this directly; the typealias is internal-purpose-only on the surface (named `BoundRoot` to signal that). Documented inline.
    - L3 test fixtures + tests written for all 5 gaps (`Many.swift` + `Many.Parse.Tests.swift`, `Verbosity.swift` + `Verbosity.Parse.Tests.swift`, `Inverted.swift` + `Inverted.Parse.Tests.swift`, `Enumerable.swift` + `Enumerable.Parse.Tests.swift`) — **NOT runnable due to verification block**.
  - **Gap 6 (transform-closure escape hatch) DEFERRED — code reverted to baseline**. The fix would relax the type-level `V: Argument.Codable` constraint on `Command.Positional<Root, V>` and `Command.Option<Root, V>` (move to per-init constraint) so consumers can bind `Foundation.URL` and other non-Codable types via a custom `transform: (String) throws(Command.Error) -> V` closure. The implementation requires the type to store a `parse: @Sendable (String) -> V?` closure set by either init (Codable path → `V(argument:)`; transform path → wrapped closure with error→nil conversion). Implementation drafted and tested via local compile, but the subsequent build attempt surfaced the array-primitives regression below — could not verify the change didn't break the existing 113 tests, so rolled back to the baseline shape. Re-attempt requires the verification block to lift first.
  - **VERIFICATION BLOCKED — unrelated build regression in swift-array-primitives**: after `swift package clean` (run during Gap 6 debug to refresh stale state), the L3 build began failing with `error: type 'Array<Element>' does not conform to protocol 'Collection.Remove.Last'` at `swift-primitives/swift-array-primitives/Sources/Array Dynamic Primitives/Array.Dynamic.swift:26` and `Array.Dynamic.Indexed.swift:98`. The `Collection.Remove.Last` protocol at `swift-primitives/swift-collection-primitives/Sources/Collection Primitives/Collection.Remove.Last.swift:58-63` requires `static func last(_ base: inout Self) -> Element?`, and `swift-array-primitives` declares `extension Array: Collection.Remove.Last where Element: ~Copyable {}` as an empty conformance with NO implementation file supplying the witness. The standalone `swift-array-primitives` build ALSO fails after its own `swift package clean` (verified). This is a **pre-existing regression unrelated to B2** — likely surfaced by some recent commit in `swift-array-primitives` or `swift-collection-primitives` whose effect was masked by build caches. Per institute discipline ("If blocked by unrelated work, STOP. Do NOT work around."), B2 verification is paused pending external fix. Once the array-primitives conformance regression is closed, all B2 tests (writing complete, ~30 new across L1 + L3) should pass without further code changes; if any new test fails it will be a B2 bug, not the array-primitives issue.
  - **Snapshot tests unchanged**: existing `Repeat.HelpSnapshot.Tests` + `Git.HelpSnapshot.Tests` fixtures do not declare any of the 5 new node types, so the help-text format additions are non-breaking on snapshot output. (Cannot verify until build is unblocked.)
- v1.0.12 (2026-05-18): **B1 inert-API bundle closed**. Four declared-but-unread fields/configuration on `Command.Configuration` + `Argument.Option` wired into the parser/help-visitor pipeline. Single-release framing — no half-implementations, no TODO markers. Test totals: L3 113/113 (+14 from 99). Foundation-free at the main targets (the `Environment` import lives `internal` in two leaf files plus the test support bridge). No new breaking surface on existing call sites — every fix is additive.
  - **Defect 1 — `--version` flag** wired into the parse pipeline. New `Command.Error.versionRequested(version: String)` case mirrors `.helpRequested`. ParseVisitor intercepts `--version` ONLY when `Root.configuration.version` is non-empty (matches Apple's opt-in behaviour: an unconfigured `--version` falls through to `.unknownLongOption`). Interception fires in both the flat-schema `applyLong` path and the subcommand-dispatch loop. `Command.parse` threads `rootVersion` into the visitor; legacy `ParseVisitor(tokens:root:)` init unchanged (empty version → never intercepts). 4 tests cover versioned/unversioned/subcommand-parent/case-shape.
  - **Defect 2 — `Argument.Option.environmentVariable`** wired through to a post-argv env-var fallback pass. `ParseVisitor.OptionEntry` gains an `environmentVariable: Argument.Environment.Variable.Name?` field plumbed from both `visit<V>(option:)` and `OptionGroupForwarder.visit<V>(option:)` (plus the nested-group entry re-wrap). `filledOptionIndices: Set<Int>` tracks argv-supplied options so argv precedence is preserved (cmdline > env > defaults). After argv consumption, `applyEnvironmentVariableFallbacks()` reads via swift-environment's `Environment.task.read(_:)` (TaskLocal-overlay-aware), runs the entry's apply closure, and on `Argument.Codable` rejection raises a new `Command.Error.invalidEnvironmentValue(name: String, environmentVariable: Argument.Environment.Variable.Name, value: String)` case (no `Argument.Position` carried — value origin is the process environment, not argv). `swift-environment` is added as a `Command Schema` target dependency (the import is isolated in `Command.Schema.ParseVisitor.EnvironmentReader.swift` so the transitive `String_Primitives.String` re-export does not shadow `Swift.String` in the rest of the visitor). Test-support extension `Argument.Environment.withOverlay(_:perform:)` exposes `Environment.withOverlay` via the same isolation pattern (lives in `Command Test Support`); 5 tests cover argv-precedence, fallback-fires, default-preserved-when-unset, invalid-env-value-error, and OptionGroup propagation.
  - **Defect 3 — root-level `Command.Configuration.aliases`** now rendered in help text as `ALIASES: alias1, alias2` between OVERVIEW and DISCUSSION (matches swift-argument-parser's "Aliases" line placement). Both `Command.Help.Visitor` and the Schema-internal `Command.Subcommand.Help.Visitor` emit the section symmetrically. Section is omitted entirely when `aliases.isEmpty` — existing snapshot tests unaffected.
  - **Defect 4 — `Command.Configuration.discussion`** now rendered in help text as `DISCUSSION:` section between ALIASES (if present) and ARGUMENTS, with each line indented two spaces. Multi-line discussions split on `\n` and emit one indented line each. Symmetric across `Command.Help.Visitor` and `Command.Subcommand.Help.Visitor`. Section is omitted entirely when `discussion.isEmpty` — existing snapshot tests unaffected.
  - **New L3 surface**:
    - `Command.Error.versionRequested(version: String)` — new case.
    - `Command.Error.invalidEnvironmentValue(name: String, environmentVariable: Argument.Environment.Variable.Name, value: String)` — new case.
    - `Command.Schema.ParseVisitor.init(tokens:argv:rootName:rootVersion:root:)` — new `rootVersion` parameter (defaulted to `""`; existing call sites unaffected).
  - **New L3 dependency**: `swift-foundations/swift-environment` (sibling L3). Justified by §3.11 v1.0.3 reuse inventory line 1110 ("`swift-environment` — DEPEND — env-var fallback resolution"), borderline-v1 designation in §3.15 v1.0.7 ("Env-var defaults | borderline v1 | v1 IF straightforward; defer to v2 if it adds complexity"), and the principal direction "treat as single release, must be perfect and complete" (v1.0.11). The implementation lands cleanly within the borderline-v1 envelope.
  - **Help-text format change** (additive, non-breaking): emits ALIASES + DISCUSSION sections when their configuration fields are non-empty. Existing `Repeat` + `Git` snapshot tests pass unchanged (those fixtures declare neither field).
- v1.0.11 (2026-05-18): **D14-D17 ergonomic completion landed**. Per principal direction 2026-05-18 ("assume there will only be a single release basically — the very first must be perfect and complete"), all four M1-retarget-surfaced API rough edges closed in one subagent dispatch. Test totals: L1 63/63 (+13 from 50), L3 99/99 (+37 from 62), +50 tests across both packages. Foundation-free. Lint-clean.
  - **D14 landed** — `Argument.Name.Long.literal(_:StaticString)` + `Argument.Name.Short.literal(_:Character)` trapping factories + `Argument.Name.longLiteral(_:)` / `.shortLiteral(_:)` / `.bothLiteral(short:long:)` convenience hoists. Schema declarations no longer scatter `try` or `_unchecked` workarounds for literal option names.
  - **D15 landed** — `Swift.Optional` conformances to `Argument.Parseable` / `Argument.Serializable` / `Argument.Codable` (where Wrapped conforms). Schemas now bind `T?` properties directly; sentinel-default semantics eliminated.
  - **D16 landed** — `Command.OptionGroup<Root, G>` schema node with KeyPath-binding; visitor protocol extension `visit(optionGroup:)`; ParseVisitor + Help.Visitor + Subcommand.Help.Visitor all updated. Shared options factor into reusable fragments — the `@OptionGroup` equivalent without property wrappers.
  - **D17 landed** — `Command.Error.exit(code: Int32, message: String? = nil)` enum case. Custom exit codes thread through the typed-throws path; no `Never`/platform escape required.
  - **Migration LoC impact** (projected against M1-retarget swift-package-graph +313 baseline): **70-115 LoC reduction (25-35% of the delta)** once these patterns are adopted. Remaining +200 LoC delta is unrelated migration overhead (Foundation→Foundation-free, typed-throws migrations, IO redirection).
  - **4 documented deviations** from brief — all structural corrections:
    1. Non-generic helper types named `Command.HelpRow` (compound, top-level under Command namespace) because `Command.Help<Root>` is generic and can't host nested non-generic helpers. `@usableFromInline internal` per [API-NAME-002] applying to public API only.
    2. `Argument.Name.Long.literal(_:)` takes `StaticString` — matches institute Tagged-literal precedent.
    3. `Command.Schema.Visitor.visit(optionGroup:)` added as unconditional protocol requirement (no default) — source-breaking for any external Visitor implementor, but no such consumer exists pre-v1; "single release perfect" framing bakes D16 into v1.
    4. `Repeat.Parse.Tests.swift` switched `error == .helpRequested` to switch-pattern after `.exit(code:message:)` added (swift-testing macro misrenders `==` against enums with mixed payload-bearing cases). Sibling tests already used switch-pattern; consistency improvement.
  - **3 residual observations** (not blockers; v2 cleanup candidates):
    1. OptionGroup recursion depth: nested OptionGroups work but have O(depth) overhead in ParseVisitor; fine for 1-2 levels, may benefit from KeyPath-chain construction once Swift 6.x Sendable propagation lands.
    2. Two `Row` types (`Command.HelpRow` in Help target + `Command.Subcommand.Help.Row` in Schema target) duplicate exactly because Schema can't depend on Help — structural duplication; v2 consolidation via a Schema-level shared rendering primitive.
    3. `Command.OptionGroup` cannot host a subcommand group (runtime `.validationFailed` error in OptionGroupForwarder); could be compile-time-enforced via separate FragmentVisitor protocol but the protocol-design complexity outweighs the rare-mistake benefit.
- v1.0.10 (2026-05-18): **M1-retarget consumer-migration validation COMPLETE**. `swift-foundations/swift-package-graph` migrated from apple/swift-argument-parser to swift-arguments end-to-end. All 7 subcommands (`list`, `topo`, `cycles`, `scc`, `dot`, `dependents-of`, `dependencies-of`) work; 21/21 model-layer tests preserved; build clean; no new Foundation. Real-world validation of both P3 single-command surface AND P4 subcommand dispatch on a production CLI.
  - **Migration LoC impact**: +313 lines (+120%) on the CLI file (261 → 574). The bloat is real and signals where ergonomic improvements would pay back fastest. Breakdown:
    - Sum-type enum + dispatch boilerplate: ~80 LoC (structural; hard to reduce)
    - `@main` Error → exit mapping for 14 cases: ~50 LoC (D17 candidate)
    - Per-subcommand option redeclaration (no `@OptionGroup` analog): ~50 LoC (D16 candidate)
    - Memberwise `init` + defaults for `Equatable` conformance: ~40 LoC
    - Module-level `Names` enum for `Argument.Name.Long` literals (workaround): ~5 LoC (D14 candidate)
  - **5 API rough edges surfaced** — direction items added:
    - **D14 confirmed**: `Argument.Name.long(_:)` production factory needed. M1-retarget worked around with module-level `private enum Names` carrying `_unchecked`-constructed name constants. Promote `longLiteral(_:)` / `shortLiteral(_:)` from Test Support to production, OR add trapping factory equivalent to `_unchecked` + debug assert.
    - **D15 NEW**: `Optional<T>: Argument.Codable where T: Argument.Codable` conformance. Schema can't bind `String?` / `Int?` today. M1-retarget used sentinel defaults (`""` for `String?`, `Int.max` for `Int?`). Add `Optional<T>` conformance in `Argument Standard Library Integration`, treating absence-in-argv as nil.
    - **D16 NEW**: `Command.Option.Group<Shared>` for `@OptionGroup`-style shared option declarations. swift-package-graph has a shared `--root` option that M1-retarget redeclared 7× (one per subcommand). Design arc needed.
    - **D17 NEW**: `Command.Error.exit(code:message:)` typed exit case. Currently consumers must use platform `exit(...)` intrinsic + `Never` return to thread custom exit codes; the typed-throws path can't authoritatively express custom exit codes. Easy add.
    - Minor (no direction item): `as Command.Error` warning in `catch` after typed-throws pipeline — M1-retarget worked around with bare `catch error` + switch.
  - **D14, D15, D17 are pre-tag candidates** (quick wins; significantly reduce consumer migration LoC). **D16 is post-tag** (real design arc, defer to v1.1).
- v1.0.9 (2026-05-18): **P4 LANDED — sum-type subcommand dispatch implemented**. swift-arguments now ships full v1 §3.15 scope. Verified clean: 62/62 tests passing (47 baseline + 15 new), no Foundation, lint-clean. §3.15 v1 scope table is FULLY implemented; DEV4's "subcommand dispatch deferred" note from v1.0.8 SUPERSEDED — subcommand dispatch is **shipped in v1**.
  - **New L3 types** at swift-arguments: `Command.Subcommand` (namespace) + `Command.Subcommand.Binding<Root>` (existential carrier protocol) + `Command.Subcommand.Case<Root, Sub: Command.\`Protocol\`>` (concrete binding) + `Command.Subcommand.Group<Root>: Command.Schema.Node` (Parser.OneOf host, conforms to Schema.Node) + `@Command.Subcommand.Group.Builder` (result-builder) + `Command.Subcommand.Help.Visitor<Root>` (sub-help rendering).
  - **Visitor protocol extended** with `mutating func visit(subcommandGroup: Command.Subcommand.Group<Root>) throws(Failure)`.
  - **Command.Error gains 3 cases**: `.unknownSubcommand(name:position:)`, `.helpRequestedForSubcommand(name:rendered:)`, `.missingSubcommand(available:)`.
  - **Help visitor extended** to render SUBCOMMANDS section + per-subcommand sub-help routing.
  - **Naming refinement vs design doc §3.5**: P4 chose `Command.Subcommand.Case<Root, Sub>` (reads as "one case of the sum type") + `Command.Subcommand.Group<Root>` (Parser.OneOf host) rather than the §3.5-sketched `Argument.Subcommand(name:){schema}` shape. Reason: aligns with [API-NAME-001] Nest.Name pattern; the L3 binding-type pattern P3 established (Command.Positional<Root, V>) extends naturally to subcommands. Design doc §3.5 example syntax updated to match implemented shape.
  - **v1 dispatch limitation**: a schema declaring `Command.Subcommand.Group` cannot mix root-level positionals (first non-flag argv IS the subcommand name). Root-level flags/options before the subcommand name ARE honored. v2 may relax this.
  - **Help-rendering duplication** (~80 LoC): `Command.Subcommand.Help.Visitor` (Schema target) duplicates portions of `Command.Help.Visitor` (Help target) to preserve target-layering. v2 cleanup candidate.
  - **Memory candidate (toolchain finding)**: P4 hit a SIGSEGV in `swiftpm-testing-helper` after adding new payload-bearing cases to `Command.Error`; clean rebuild (`rm -rf .build`) resolved. Pattern: enum-payload-additions trigger Swift's debug-build-cache module-layout staleness. Worth a memory entry if it recurs.

- **M1 BLOCKED**: consumer-migration validation cannot proceed. All 4 institute consumers of apple/swift-argument-parser are unbuildable today:
  - `swift-dependency-analysis` — ARCHIVED 2026-05-14 (superseded by swift-package-graph per archive disposition)
  - `swift-package-graph` — broken (missing `swift-cursor-primitives` files; mid-migration in upstream)
  - `swift-linter` — same Cursor Span migration breakage
  - `swift-impact` — same Cursor Span migration breakage
  
  Per hard-stop discipline, M1-retarget NOT dispatched. Real-world consumer-migration validation deferred until the Cursor Span migration arc completes upstream. swift-arguments itself remains green; the blocker is purely upstream-baseline.

- **API rough edge surfaced (M1 inventory finding)**: Migration table in Part IV shows `name: .long("count")` as a factory call. The actual production API requires `try Argument.Name.Long("count")` (throwing). `longLiteral(_:)` / `shortLiteral(_:)` convenience helpers exist ONLY in `swift-argument-primitives/Tests/Support/Argument.Name.Fixtures.swift`. Recommended follow-up: **promote the literal-style factories to production** at swift-argument-primitives (or add Command.Name.long(_:) convenience in swift-arguments Command Core). Documented as direction item D14.

- v1.0.8 (2026-05-18): **v1 IMPLEMENTED via orchestrator/subagent pattern**. P1+P2+P3 completed 2026-05-17/18; verified green from clean checkout 2026-05-18 (118 tests passing across 22 targets; no Foundation; lint-clean). v1.0.8 captures the four authoritative deviations P3 surfaced during implementation. **These are the as-implemented truths, not optional alternatives.**
  - **DEV1 — L3 binding types** (`Command.Positional<Root, V>` etc.) wrap L1 `Argument.Positional<V>` with `WritableKeyPath<Root, V>`. L1 declarations are KeyPath-agnostic; L3 adds the binding layer. The L3 types conform to `Command.Schema.Node<Root>` and dispatch through `Command.Schema.Visitor<Root>`. The L1 `Argument.Schema.Node` / `Argument.Schema.Visitor` remain available for un-bound-schema consumers. §3.5 reflects this split.
  - **DEV2 — `Command.parse(_:from:initial:)`** takes an `initial: C` seed instead of synthesizing a default via reflection. Avoids Mirror/Decodable dependency entirely. Signature: `Command.parse<C: Command.\`Protocol\`>(_ type: C.Type, from argv: [String], initial: C) throws(Command.Error) -> C`.
  - **DEV3 — `Argument.Codable` refines `Argument.Parseable` + `Argument.Serializable`** (single-conformance both-directions convenience). Sibling-to-Coder.Codable framing preserved at the family level per [FAM-009]; refinement is a layering convenience inside the family.
  - **DEV4 — sum-type subcommand dispatch** — P3 deferred from v1; **P4 follow-up arc dispatched 2026-05-18 to close the gap before v1 tag**. The L1 declaration vocabulary (`Argument.Subcommand<S>`, `Argument.Subcommand.Choice`) is already shipped from P1; P4 adds the L3 binding + parse-visitor glue (`Command.Subcommand<Root, S>` + `visit(subcommand:)` on `Command.Schema.Visitor`). §3.15 v1 scope table flips subcommand-dispatch from DEFERRED back to REQUIRED once P4 lands.
- v1.0.7 (2026-05-17): **v1 scope reduction per principal direction** ("Can you first explain to me better why we even need powershell, zsh, gnu, fish, etc? We haven't needed this yet. See /platform"). Applies the institute discipline "we add what we need, when we need it" + [ECO-002] layer-placement + [PLAT-ARCH-021] domain-specific composition + [MOD-RENT] three-criteria test to reduce v1 scope from 4 packages to **3 packages**. Material changes:
  - **Dropped from v1**: `Command.Completion.{Bash,Zsh,Fish,PowerShell}` types, `Command.Manpage` type. These are shell-completion-domain + manpage-domain work — distinct domains from argument parsing. Per [PLAT-ARCH-021] precedent (RFC-typed Connect overloads moved out of swift-kernel into swift-sockets), domain-specific composition belongs in domain-specific L3 packages. Future `swift-shell-completion` and/or `swift-manpages` L3 packages compose swift-arguments. Filed as direction items D10 (shell completion) + D11 (manpage). The Bash/Zsh/Fish/PowerShell question (whether each needs L2 typed modeling, whether PowerShell warrants `swift-microsoft/swift-powershell-standard`, etc.) is deferred to those future arcs — NOT relevant to v1.
  - **Dropped from v1**: `swift-gnu` L2 package. GNU long-options (`--long-option=value`, `--long value`) IS needed in v1 — but the "spec" is ~10 paragraphs of prose in GNU coding standards §4.7-4.8, not an IEEE-numbered standard. The convention is small enough to live INLINE in `swift-arguments` at L3, not warranting its own L2 package + new GitHub org. swift-ieee-1003 stays at L2 (POSIX 12.2 IS a numbered standard published by IEEE).
  - **v1 final package count: 3**: `swift-primitives/swift-argument-primitives` (L1) + `swift-ieee/swift-ieee-1003` (L2) + `swift-foundations/swift-arguments` (L3 — argv parsing + help-text emit + GNU long-option handling inline).
  - **v2+ direction items added**: D10 shell-completion as separate L3 domain, D11 manpage generation, D12 response files, D13 config-file integration via traits.
  - **§3.4 collapses swift-gnu**; **§3.5 + §3.6 + §3.8 remove Completion + Manpage**; **§3.10 + §3.11 + §3.13 update to 3-package state**; **new §3.15 v1 scope discipline** documents the discipline rationale.
  - **Structural framework preserved**: §2.2 Schema-as-data + §3.6 visitor-via-Serializer.Protocol patterns remain valid. v1 instantiates ONE Serializer (Help text); v2+ adds more Serializers (completion, manpage) without re-architecting. The framework is forward-compatible by design.
- v1.0.6 (2026-05-17): two principal corrections on v1.0.5:
  - **`Command.Completion.PowerShell` REVERTED from `Pwsh`** — per [API-NAME-002] spec-mirroring exception, when the compound form IS the specification's term, the identifier mirrors the spec (precedent in [API-NAME-002] body cites `BackgroundColor` from CSS Backgrounds §3.2, `.contentType` from RFC 9110 §8.3). `PowerShell` is Microsoft's official one-published-token product name, structurally analogous. The mechanical `Lint.Rule.Naming.CompoundType` would fire syntactically; suppression via `// swiftlint:disable:next compound_type_name  // reason: PowerShell is Microsoft's official product name per [API-NAME-002] spec-mirroring exception` at the declaration is the correct response per the **rule-exemptions** skill. Bash/Zsh/Fish remain unchanged (acronym-style 3-4-letter names, already exempt).
  - **swift-token-primitives' `Token` SHOULD be generic** (recommendation, not landed): the package name (`swift-token-primitives` — not `swift-swift-source-token-primitives`), the doc comment (`Token.swift:18-23` — "Token is the atomic unit of lexical analysis... all major compiler implementations use this pattern"), and the (Kind, Text.Range) shape itself ALL frame Token as a universal structural atom — but the current implementation hardcodes `Kind` to a Swift-source-code enum (`leftBrace`, `keyword(Token.Keyword)`, `period`, …). The framing-vs-implementation gap is a structural opportunity: `Token<Kind>` would unlock the same shape for argv-tokens, CSV-tokens, regex-tokens, JSON-tokens, and others. Recommended path: a separate Tier 2 research arc proposes the generic refactor (`struct Token<Kind: Sendable & Hashable>: Sendable, Equatable, Hashable { kind: Kind; range: Text.Range }`); the current Swift-source-code `Kind` enum relocates to its own Swift-source-code-specific token target (e.g., `Swift.Lex.Token.Kind` or `Token.Swift.Kind`). Meanwhile for swift-arguments work, `Argument.Token` + `Argument.Token.Kind` are defined fresh in `swift-argument-primitives` as v1 specialization; once the generic refactor lands, `Argument.Token` becomes a typealias for `Token<Argument.Token.Kind>`. Filed as direction D9. New §3.14 documents the recommendation.
- v1.0.5 (2026-05-17): pre-implementation audit pass against code-surface + platform + swift-package + modularization + primitives + swift-institute-ecosystem skills + swift-linter rule corpus. Eight material corrections, all to make the design implementation-ready under institute discipline:
  - **Token reuse REFUTED FOR CURRENT IMPLEMENTATION; structural ambiguity surfaced**: `swift-token-primitives`' `Token` is NOT currently generic — its `Kind` enum has fixed Swift-source-code cases (`leftBrace`, `keyword(Token.Keyword)`, `period`, etc.). Verified at `swift-token-primitives/Sources/Token Primitives/Token.{swift,Kind.swift}`. HOWEVER — the package name (`swift-token-primitives` — not `swift-swift-source-token-primitives`) and the doc comment ("Token is the atomic unit of lexical analysis... all major compiler implementations use this pattern") frame Token as structurally universal. The implementation-vs-framing gap is a structural opportunity for a generic refactor; see direction D9 + §3.14 v1.0.6. For the swift-arguments arc, `Argument.Token` + `Argument.Token.Kind` are defined fresh as L1 types AND a post-refactor typealias path is documented.
  - **`Source.Position` / `Source.Range` / `Source.Location` reuse REFUTED**: these are file-qualified (`file: Source.File.ID` + `offset: Text.Position`). Argv has no file identity. `Argument.Position` is restored as L1 type wrapping `(argvIndex, byteOffset)` — likely `Tagged<…, (Int, Int)>` or a small struct.
  - **`Diagnostic.Record` reuse REFUTED for the same reason** — depends transitively on `Source.Location`. Partial reuse: `Diagnostic.Severity` (the bare enum) IS reusable.
  - **L1 vocabulary scope correction**: from ~12 net-new types (v1.0.3 over-optimistic) to ~17-20 — Token, Token.Kind, Position now restored. §3.10 / §3.11 corrected.
  - **`Command.\`Protocol\`` backtick fix**: `Protocol` is a Swift reserved word at type-name position; institute precedent is `Parser.\`Protocol\`` per `swift-parser-primitives`. All `Command.Protocol` references in §3.5 and §VI updated to `Command.\`Protocol\``.
  - ~~`Command.Completion.PowerShell` → `Command.Completion.Pwsh`~~ — REVERTED v1.0.6 per [API-NAME-002] spec-mirroring exception (see v1.0.6 changelog above).
  - **`Argument.Subcommand.Choice` → `Argument.Subcommand.Choice`** — collided semantically with `Argument.Group<G>` (the OptionGroup analog at §3.5); `Choice` maps cleanly to `Parser.OneOf` (which the subcommand dispatch is structurally) and avoids the name overlap.
  - **`Argument Primitives Standard Library Integration` → relocated to L3 `swift-arguments` as `Argument Standard Library Integration`** — completes the v1.0.4 [FAM-009] resolution (Argument.Codable at L3); stdlib conformances follow. §3.8 + §3.11 + §3.3 file listing updated.
  - **Org placement clarified per `swift-institute-ecosystem` [ECO-004]**: `swift-ieee/swift-ieee-1003` (IEEE-authority sub-org of swift-standards; matches `swift-iso/swift-iso-32000` precedent); `swift-gnu/swift-gnu` requires a new GitHub org (GNU is its own authority, no current sub-org). Until the swift-gnu org exists, the package may live under swift-standards as transitional placement; canonical home is the new swift-gnu org. New §3.13 documents the org structure.
  - **Spec-mirror exemption** for `IEEE_1003.UtilitySyntax.Guideline.{G3, G4, G5, G6, G7, G9, G10}` etc. per [API-NAME-003] — the `G{number}` form mirrors POSIX 12.2's guideline numbering verbatim (Guideline 3, Guideline 4, etc.) and would trip `Lint.Rule.Naming.CompoundType` without an exemption. §3.4 adds an explicit `// swiftlint:disable` rationale per [RULE-EXEMPT-*] discipline.
- v1.0.4 (2026-05-15): four-agent parallel investigation results integrated. **Three material design changes**, all empirically grounded:
  - **U6+U7 (P2 premise) CONFIRMED** via extended spike at `swift-institute/Experiments/argv-parser-protocol-spike/` (now 10/10 tests passing — 6 original P1 + 4 new P2). HelpVisitor emits byte-exact help text; BashCompletionVisitor emits well-formed `compgen`/`complete` function; **bidirectionality empirically confirmed** — same Schema instance drives parse + help + completion. Load-bearing hazard surfaced: visitor only walks `Argument.*` combinators, not arbitrary `Parser.*` ones — `Command.Body` MUST be constrained to `some Argument.Schema.Node`. §2.2 + §3.5 updated to make this explicit.
  - **U8 benchmark**: institute design **115× faster parse latency** than swift-argument-parser (60µs → 0.5µs, decisive structural win — reflection-driven vs compile-time-specialized). Binary size 3.1× larger (2.24× stripped) — packaging artifact from ~150 transitive primitive modules, fixable via consolidated L3 umbrella, NOT a structural defect. Compile time 1.4× slower wall-clock (minor). Files at `swift-institute/Experiments/argv-parser-benchmark/`. Verdict: competitive on perf, currently uncompetitive on packaging, packaging is fixable. Validates the L3 design discipline of consolidating transitive-module exposure.
  - **U3 (D6) RESOLVED — single always-async protocol**. New research doc at `swift-institute/Research/2026-05-15-command-protocol-sync-async-design.md` (Tier 2, RECOMMENDATION) — recommends Option A: single `Command.Protocol` with `mutating func run() async throws(Command.Error)`. `Command.Async.Protocol` and `Command.Async` namespace REMOVED. Rationale: swift-argument-parser's sync/async split was Swift-5.5/5.6-availability-driven, not structural; institute precedent (`Parser.\`Protocol\``, `Serializer.Protocol`, `Coder.Protocol`) is unanimously single-shape; all 3 existing institute CLIs already use AsyncParsableCommand; sync/async axis is orthogonal to Copyable/~Copyable axis (D8 survives unchanged). §3.5 + §VI D6 + Outcome decision #7 updated.
  - **U10 (D7) RESOLVED — `Argument.Codable` at L3, not L1**. New research doc at `swift-institute/Research/2026-05-15-family-codable-convention.md` (Tier 2, RECOMMENDATION) — codifies [FAM-009] hybrid placement: sibling format-Codable protocols live at the same layer as their namespace root UNLESS substrate-friction gates apply at that layer, in which case they promote one tier. `Argument.Codable` bridges Self ↔ Swift.String → hits [PRIM-FOUND-004] L1 friction gate → promotes to L3 `swift-arguments`. Zero contradictions with shipped placements (JSON.Serializable L3, ASCII.Parseable L1, Binary.Parseable L1). §3.9 + §3.11 + §VI D7 + Outcome updated.
- v1.0.3 (2026-05-15): discovery audit pass — searched swift-primitives + swift-foundations + swift-institute/Research + swift-institute/Experiments per principal direction "there's already SO MUCH available." Loaded **platform** skill for [PLAT-ARCH-*] / [PATTERN-*] coverage. Three material findings:
  - **U1 (WritableKeyPath + ~Copyable) CONFIRMED REFUTED** by existing institute research at `swift-institute/Research/mutator-writable-keypath-interaction.md` + experiment `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/` (revalidated Swift 6.3.1). WritableKeyPath carries implicit `Root: Copyable & Escapable`; ~Copyable Command rejects the subscript at compile. §3.5 API surface adjusted: `Command.Protocol` defaults to Copyable (matching swift-argument-parser's pragmatic shape); ~Copyable opt-in via a separate `Command.Resource.Protocol` deferred to U3 design arc.
  - **Namespace collision**: `Token` already exists at `swift-token-primitives` as the canonical lexical-classification type (`Token` + `Token.Kind` + `Text.Range`). The proposed `Argument.Token` is renamed and refactored to extend the existing `Token` infrastructure with an `Argument.TokenKind` enum used as `Token<Argument.TokenKind>` — reuses 90% of the existing primitive instead of duplicating.
  - **Major reuse opportunities**: ~70% of L1 vocabulary can come from existing primitives (Token, Source.Position, Source.Range, Diagnostic.Record, Property<Tag, Base>, Tagged, Terminal, ASCII.Decimal.Parser); at L3, swift-console + swift-process + swift-environment + swift-parsers + swift-paths + swift-uri compose cleanly without re-implementation. Genuinely greenfield: argv-tokenizer + Argument metadata atoms (Name, Arity, Visibility, Help) + Schema-builder + Help/Completion/Manpage Serializers + optional `@CLI` macro. Reduces L1 scope substantially. New §3.10 Discovery findings and §3.11 Reuse inventory document the impact on the proposed packages.
- v1.0.2 (2026-05-15): architecture/modularization/primitives + implementation/memory-safety audit pass. Applied skills (in canonical loading order per `swift-institute-core`): **swift-institute** ([ARCH-LAYER-*]), **swift-package** ([PKG-NAME-*], [PKG-DEP-*]), **modularization** ([MOD-*]), **primitives** ([PRIM-*]), **implementation** ([IMPL-*]), **memory-safety** ([MEM-*]).
  - Adds §3.8 Multi-target structure and tier classification — Package.swift target shape per [MOD-001] Core + [MOD-005] umbrella + [MOD-011] Test Support + [MOD-017] Namespace target + [MOD-010] StdLib Integration + [MOD-012] layer-adapted naming + [MOD-024] TS spine + [MOD-026]/[MOD-030] fine-grained per-type modularization + [MOD-015] consumer import precision + [PKG-DEP-001] path-form deps + [PRIM-ARCH-001] tier classification + Swift 6 ecosystem settings + [ARCH-LAYER-007] Foundation discipline + [MOD-014] trait-gated console integration.
  - Adds §3.9 surfacing the open question of `Argument.Codable` family-protocol placement per [PRIM-FOUND-004] L1 String-friction intent (parked on the deferred family-codable-convention research per `project_parser_serializer_coder_system_framing` framing memo). Adds open-questions direction D7 for the same.
  - Implementation skill audit: §3.6 Help serializer sketch had a 3-line mechanism-leaky body (`var v = …; output.walk(visitor: &v); buffer = v.buffer`); collapsed to single-expression call `Help.Visitor.emit(schema:configuration:into:)` per [IMPL-EXPR-001] / [IMPL-INTENT] / [IMPL-023] (static-method core, instance delegates).
  - Memory-safety skill audit: design is compliant. `~Copyable` Command.Protocol + `consuming func run()` matches [MEM-COPY-001] / [MEM-COPY-014] / [MEM-OWN-001]. Sendable conservatively unspecified per [MEM-SEND-001]. Strict memory safety enabled per [MEM-SAFE-001] (§3.8 Swift 6 settings). No `@unsafe` / `@unchecked Sendable` / `nonisolated(unsafe)` in the proposed surface, no findings.
  - No structural design changes — additions are placement/structure detail + one mechanism→intent collapse, all under the v1.0.0/v1.0.1 framing.
- v1.0.1 (2026-05-15): code-surface audit pass against the full code-surface skill ([API-NAME-001]–[API-NAME-014] + [API-IMPL-*] + [API-ERR-*]). Fixes applied to the proposed institute API surface — none affect the design's structural claims; all are naming/shape corrections:
  - `Argument.SchemaNode` → `Argument.Schema.Node`; `Argument.SchemaVisitor` → `Argument.Schema.Visitor` (compound type names per [API-NAME-001])
  - Visitor methods `visitPositional`/`visitOption`/… → `visit(positional:)`/`visit(option:)`/… (compound identifiers per [API-NAME-002]; single-form per [API-NAME-008])
  - `Argument.ArgvInput` → `Argument.Input` (compound + namespace-implicit-prefix per [API-NAME-002] + [API-NAME-013])
  - `Argument.Tokenizer.PosixGnu` → `Argument.Tokenizer.Default` (compound type name per [API-NAME-001])
  - `Command.AsyncProtocol` → `Command.Async.Protocol` (compound name per [API-NAME-001]; `Async` is namespace expecting future siblings per [API-NAME-001a])
  - `GitCommand` example → `Git` (compound type name per [API-NAME-001]; `Git` IS the command, subcommands are `Clone`, `Status`, `Commit` sibling types per [API-IMPL-005])
  - `Argument.Subcommands { … }` builder shape → `Argument.Subcommand.Choice { … }` (avoids plural-as-namespace; nests the group concept under the singular `Subcommand` type)
  - `includeCounter: Bool` in institute-equivalent example → `counter: Bool` (compound property name per [API-NAME-002]; `counter` reads with namespace context per [API-NAME-013])
  - `HelpEmissionVisitor` → `Help.Visitor` (compound + namespace-implicit-prefix per [API-NAME-001] + [API-NAME-013])
  - `try? walk(visitor:)` → bare call (the Help visitor has `Failure == Never`; `try?` is forbidden per `feedback_prefer_typed_throws_over_try_optional`)
  - `@CLI.Positional` / `@CLI.Option` / `@CLI.Flag` v2 macro sub-roles → `@CLIPositional` / `@CLIOption` / `@CLIFlag` (Swift macros must use compound names at file scope per [API-NAME-001] macro exception — nested macro declarations are not supported by the language)
  - Apple's `Repeat` reference example in §1.2 retains `includeCounter` (cited verbatim from upstream per source fidelity; does not affect institute-side names).
- v1.0.0 (2026-05-15): initial RECOMMENDATION.
-->

## Context

Apple's [swift-argument-parser](https://github.com/apple/swift-argument-parser) is the de-facto Swift package for declaring command-line interfaces. It is Apache 2.0, used widely across the Swift ecosystem, and well-engineered for its design choices. Those design choices, however, predate the institute's parser/serializer/coder framework, typed throws, `~Copyable` / `~Escapable`, and the five-layer architecture. As a result, it is structurally non-composable with the rest of the institute ecosystem: a `ParsableCommand` is a `Decodable` walked by `Mirror` reflection, not a parser composed from primitives.

The institute already ships:

- `swift-parser-primitives` — `Parser.Protocol<Input, Output, Failure>` with `~Copyable` `~Escapable` input, typed throws, Body+Builder composition, checkpoint/restore backtracking, and a fully-developed combinator catalog (Take.Sequence, OneOf.{Two,Three,Sequence}, Many, Optional, Peek, Backtrack, Map, FlatMap, …).
- `swift-serializer-primitives` — `Serializer.Protocol<Output, Buffer, Failure>` symmetric to Parser, with Body+Builder, contramap, filter, many, sequence, optional, lazy, always, fail, trace.
- `swift-coder-primitives` — `Coder.Protocol: Parser.Protocol, Serializer.Protocol` (refinement); leaf-only, no Body+Builder per the design memo.
- `swift-parser-machine-primitives` — defunctionalized parser runtime (stack-safe deep grammars).
- `swift-binary-coder-primitives`, `swift-binary-parser-primitives`, `swift-ascii-serializer-primitives`, `swift-ascii-parser-primitives` — format-specific specializations.
- `swift-parsers` (L3) — composed parsers (identifiers, integers, quoted strings, whitespace, comments, diagnostics).
- `swift-foundations/swift-command-line-interface` — an empty placeholder (no Package.swift, no Swift code; CI scaffold only). [Verified: 2026-05-15]
- `swift-foundations/swift-console`, `swift-foundations/swift-process`, `swift-primitives/swift-terminal-primitives` — adjacent CLI infrastructure.

Greenfield design space; the ecosystem alternative to swift-argument-parser does not exist today.

**Trigger**: principal request to investigate what `swift-argument-primitives` (L1) and `swift-arguments` (L3) would look like as an institute-native alternative to swift-argument-parser, building on the existing parser/serializer/coder primitives. This research is the design-level analysis preceding any package authorship.

## Questions

1. **Q1** — Does the institute need a CLI argument-parsing ecosystem, given swift-argument-parser exists and is Apache 2.0? What would warrant building one?
2. **Q2** — How does CLI argument parsing decompose onto the institute's `Parser.Protocol` / `Serializer.Protocol` / `Coder.Protocol` framework? Is `Coder.Protocol`'s single-Buffer shape the right home, or does multi-format emit (help + completion + manpage) demand a different shape?
3. **Q3** — How many packages and at which layers? `swift-argument-primitives` at L1 — what does it own? Are L2 spec-implementation packages warranted for POSIX 12.2 and GNU long options? `swift-arguments` at L3 — what does it compose?
4. **Q4** — Where does the user-facing surface land on the spectrum between explicit applicative composition (optparse-applicative) and reflection-driven declarative metadata (swift-argument-parser, clap-derive, Click decorators)? Does a Body+Builder DSL suffice, or do we want a `@CLI` macro in v1?
5. **Q5** — What is the migration story from swift-argument-parser for existing consumers, and what does parity / superset coverage look like?

---

## Part I: Prior Art Survey (per [RES-021], [RES-023])

### §1.1 Internal prior art — institute primitives

#### `swift-parser-primitives` — Parser.Protocol shape

```swift
public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
    associatedtype Input: ~Copyable & ~Escapable
    associatedtype Output
    associatedtype Failure: Swift.Error
    associatedtype Body: ~Copyable

    @Parser.Builder<Input>
    var body: Body { borrowing get }

    borrowing func parse(_ input: inout Input) throws(Failure) -> Output
}
```
[file: `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90`, Verified: 2026-05-15]

Key properties relevant to CLI:

- **`Input` is generic** — not byte-bound. `Parser.Input.Collection<Base>` wraps any indexed collection, so `[String]` (argv) is admissible. [`Parser.Input.swift:12-132`, Verified: 2026-05-15]
- **Destructive parse with checkpoint/restore** — `inout Input` is advanced past consumed elements; `Parser.OneOf.Two` saves a checkpoint, tries the first alternative, restores on failure. [`Parser.OneOf.Two.swift:39-52`]
- **Typed throws end-to-end** — `Failure` is an associated type composed via `Parser.Either`-chained alternatives.
- **Body+Builder declarative composition** — `@Parser.Builder<Input>` is a `@resultBuilder` macro consuming sub-parsers. Leaf parsers override `parse`; composed parsers declare `body`.
- **`Parseable` attachment protocol** at the top level of `Parser_Primitives_Core`: `static var parser: Parser { get }`. Sibling-format protocols (e.g., `ASCII.Parseable`) coexist non-refining. [`Parseable.swift:19-25`]

#### `swift-serializer-primitives` — symmetric shape

```swift
public protocol `Protocol`<Output, Buffer, Failure>: ~Copyable {
    associatedtype Output
    associatedtype Buffer
    associatedtype Failure: Swift.Error
    associatedtype Body: ~Copyable

    @Serializer.Builder<Buffer>
    var body: Body { borrowing get }

    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
}
```
[`swift-serializer-primitives/Sources/Serializer Primitives Core/Serializer.Protocol.swift:49-82`, Verified: 2026-05-15]

- **`Buffer` is generic** — a serializer produces output by appending to any mutable Buffer type. Different output formats *are* different Buffer types — typed format dispatch lives in the type system, not at runtime.
- **Body+Builder symmetry with Parser** — contramap, filter, many (with optional separator), sequence (parallel apply), optional, lazy, always, fail, trace.
- **`Serializable` attachment** at the top level of `Serializer_Primitives_Core`.

#### `swift-coder-primitives` — refinement, leaf-only

```swift
public protocol `Protocol`: Parser.`Protocol`, Serializer.`Protocol` { }
```
[`Coder.Protocol.swift:32`, Verified: 2026-05-15]

`Coder.Protocol` is a pure refinement — `Body == Never` for both inherited slots, no declarative composition. Per the framing memo: "Coders are typically leaf types — one per format × value pair." `Codable` attachment at top level: `static var coder: Coder { get }`.

Implication for argument parsing: a `Command.Coder<C>` *could* conform to `Coder.Protocol` with a chosen Buffer (e.g., help-text `String`). But the multi-format emit problem (help + bash-completion + zsh-completion + fish-completion + manpage = 5 distinct Buffer types) means a single `Coder` does not cover the schema bundle. **The argument-parsing schema is not a Coder — it is a `Parser` plus a *family* of `Serializer`s, derived from a shared descriptor.** See §4.

#### `swift-foundations/swift-command-line-interface` — empty placeholder

Repository contents [Verified: 2026-05-15]:

- No `Package.swift`.
- Zero `.swift` files.
- `.github/metadata.yaml` describes the package as "Command line for Swift." with topics `[foundations, command]`.
- CI scaffold + linting config present; latest commits 2026-04 through 2026-05 are pure infrastructure (CI migration, metadata sync, dependabot).
- No README.

The package is a name reservation, nothing more. It does not constrain the design.

### §1.2 Apple's swift-argument-parser

[`swiftlang/swift-argument-parser`, Apache 2.0, no external dependencies, Verified: 2026-05-15]

#### Architectural shape

| Type | File:line | Role |
|------|-----------|------|
| `ParsableCommand` | `Sources/.../ParsableCommand.swift:13` | Root protocol, refines `ParsableArguments`; carries `static var configuration` + `mutating func run() throws` |
| `ParsableArguments` | `ParsableArguments.swift:16` | `Decodable, _SendableMetatype`; `init()`, `validate()`, `_errorLabel` |
| `AsyncParsableCommand` | `AsyncParsableCommand.swift:15` | Async variant |
| `CommandConfiguration` | `CommandConfiguration.swift:13` | Static metadata: name, abstract, version, subcommands, defaultSubcommand, aliases, helpNames |
| `@Argument` | `Argument.swift:44-52` | Positional, property wrapper, stores `Parsed<Value>` |
| `@Option` | `Option.swift:52-62` | Named option, same `Parsed<Value>` storage |
| `@Flag` | `Flag.swift:72-82` | Boolean or `EnumerableFlag` |
| `@OptionGroup` | `OptionGroup.swift:34-48` | Composes a child `ParsableArguments` transparently |
| `EnumerableFlag` | `EnumerableFlag.swift:58-72` | `CaseIterable & Equatable` for enum-of-flags |
| `ExpressibleByArgument` | `ExpressibleByArgument.swift:13-60` | `init?(argument: String)` value conversion |

#### Parsing flow

1. **Reflection over the type** — `Mirror(reflecting: T.init())` walks properties; each `@Argument` / `@Option` / `@Flag` wrapper conforms to `ArgumentSetProvider` and yields an `ArgumentSet`. [`ParsableArguments.swift:297`]
2. **Token matching** — `LenientParser` iterates `SplitArguments` and matches against `Name` (short/long). [`ArgumentSet.swift:255-354`]
3. **Subcommand dispatch** — `CommandParser.descendingParse` consumes a subcommand name and descends the tree. [`CommandParser.swift:226-269`]
4. **Decoding** — `ArgumentDecoder` drives `Decodable` to populate properties. [`ArgumentDecoder.swift:31-78`]
5. **Validation** — user-defined `validate()` runs after decode. [`CommandParser.swift:230-241`]
6. **Execution** — `ParsableCommand.main()` calls `run()`. [`ParsableCommand.swift:148-179`]

#### Help / completion / manpage

Help and completion generators walk the same `ArgumentSet` schema (parallel emitters, shared input): `HelpGenerator` [`HelpGenerator.swift:12-100`], `BashCompletionsGenerator`, `ZshCompletionsGenerator`, `FishCompletionsGenerator`. Manpage generation lives in a separate `Tools/generate-manual` tool that traverses the same schema.

#### Friction points — empirically observed

| Pain point | Source | Implication for institute alternative |
|---|---|---|
| **Untyped throws** | `ParserError`, `ValidationError` are untyped Swift errors | Institute uses `throws(SpecificError)` ecosystem-wide; ports cannot catch specific cases |
| **Reflection tax per parse** | `Mirror` + `Decodable` on every invocation; no schema caching | Institute Parser primitives are value-types — schema construction is compile-time-known |
| **No `~Copyable` support** | Commands are `mutating` value types, copy-by-default | Institute ecosystem is migrating to `~Copyable` per [`feedback_correctness_and_evergreen`] |
| **Help/parser coupling without a visitor** | Multiple generators duplicate schema-walking logic | Single Schema-as-data with visitor protocol resolves cleanly |
| **`@unchecked Sendable` in property wrappers** | `Parsed.swift:32` | Cleaner ownership story with `~Copyable` value semantics |
| **No typed errors per option** | Single untyped `ValidationError` | Per-argument `Failure` type composable via `Parser.Either` |
| **Static-only subcommands** | `subcommands: [ParsableCommand.Type]` array | Domain-modeled sum types via `Parser.OneOf` |
| **Foundation dependency** | Required for `Decodable`, `JSONDecoder`-shaped value conversion | Institute Foundation-free at L1/L2 per [PRIM-FOUND-001] |

These are not failures of swift-argument-parser; they are consequences of design choices made before the institute primitives existed.

#### Reference example for parity

```swift
@main
struct Repeat: ParsableCommand {
  @Option(help: "The number of times to repeat 'phrase'.")
  var count: Int? = nil

  @Flag(help: "Include a counter with each repetition.")
  var includeCounter = false

  @Argument(help: "The phrase to repeat.")
  var phrase: String

  mutating func run() throws {
    let repeatCount = count ?? 2
    for i in 1...repeatCount {
      print(includeCounter ? "\(i): \(phrase)" : phrase)
    }
  }
}
```
[`Examples/repeat/Repeat.swift:14-36`, Verified: 2026-05-15]

The institute alternative must express this with equal or better ergonomics.

### §1.3 Haskell `optparse-applicative` — the structural reference point

[`pcapriotti/optparse-applicative`, BSD-3-Clause, [README](https://hackage.haskell.org/package/optparse-applicative), [maintainer notes](https://huwcampbell.com/posts/2017-02-28-maintaining-optparse-applicative.html), Verified: 2026-05-15]

Core type: `Parser a` — instance of `Functor`, `Applicative`, `Alternative`.

The structural insight, quoted from Huw Campbell's design notes:

> "An applicative Parser is essentially a heterogeneous list or tree of Options, implemented with existential types. All options are therefore known statically… and can, for example, be traversed to generate a help text."

This is a **free Applicative** encoding (with `Alternative` for choice). The single `Parser a` value:

- Drives argv parsing (`execParser`).
- Generates help text (introspection over the option tree).
- Generates bash/zsh/fish completion scripts (`--bash-completion-script`, etc.).
- Generates manpages (third-party `optparse-applicative-help`).

One value, four emitters. This is the gold standard for bidirectionality — **schema *is* the parser, and the parser is introspectable data**.

#### Contextualization in the institute type system per [RES-021]

Universal adoption in the surveyed corpus does not imply universal necessity. The free-Applicative encoding in Haskell exploits Haskell's GADT/existential machinery to wrap heterogeneous options in a single list. The institute's `Parser.Builder` result-builder reaches a structurally similar place via the `Body` associated type — a Body is a heterogeneous tree of typed sub-parsers retained as data. Helpers can traverse a `Body` by case-matching on the combinator types (`Parser.Take.Sequence`, `Parser.OneOf.Two`, `Parser.Map`, …).

But — and this is load-bearing — Body-tree traversal in Swift is awkward because each combinator carries a distinct `Body` type. Pattern-matching on `Body` requires a visitor protocol or generic dispatch that each combinator implements. Two viable encodings:

| Encoding | Description | Cost |
|---|---|---|
| **Body-tree visitor** | Each `Parser.*` combinator conforms to a `SchemaVisitable` protocol. Help/completion generators traverse `Body` via visitor methods. | Couples the visitor protocol to every combinator; visitor cannot reach non-Argument parsers cleanly. |
| **Sidecar metadata in dedicated `Argument.*` parser types** | `Argument.Positional`, `Argument.Option`, `Argument.Flag` are parser-types that *also* carry help/completion metadata as stored properties. Generators walk the Schema by inspecting these dedicated types. | Schema must be expressed in `Argument.*` types specifically; arbitrary `Parser.*` cannot enter the Schema. |

The **sidecar-metadata** encoding is recommended (§5.4). It keeps the visitor surface bounded to the CLI domain and avoids leaking visitor obligations into the general-purpose parser combinator library.

### §1.4 Rust `clap`

[`clap-rs/clap`, MIT/Apache-2.0, Verified: 2026-05-15]

Two principal APIs:

- **Builder API** — imperative `Command::new().arg(Arg::new(...))`; parsing produces `ArgMatches`. [docs.rs/clap](https://docs.rs/clap/latest/clap/)
- **Derive API** — `#[derive(Parser)]` on structs, `#[derive(Subcommand)]` on enums, `#[derive(Args)]` for compositional groups merged via `#[command(flatten)]`. [docs.rs/clap derive ref](https://docs.rs/clap/latest/clap/_derive/index.html)

Subcommands are sum types — Rust enum variants — giving strongly-typed dispatch with exhaustive matching on the parsed value. This is a strict improvement over swift-argument-parser's `[ParsableCommand.Type]` array, which loses static dispatch.

Help and shell-completion generation: `Command` tree is consumed by clap itself for parse+help, and by separate crates `clap_complete` and `clap_mangen` for completions and manpages. **Shared tree, parallel emitter crates.** Less elegant than optparse-applicative's single value, but workable.

Errors are typed via `clap::Error` with rich diagnostic information.

### §1.5 .NET `System.CommandLine` — cautionary precedent

[`dotnet/command-line-api`, MIT, Verified: 2026-05-15]

Symbol-based model: `Command`, `RootCommand`, `Option<T>`, `Argument<T>`. `RootCommand` extends `Command` with built-in `Help` option, `Version` option, and `Suggest` directive. Values extracted by passing the symbol object as a typed key: `parseResult.GetValue(option)`.

**The rewrite history is instructive as a negative example.** From the [Beta 2 announcement](https://github.com/dotnet/command-line-api/issues/1537):

> "The parameters in the handler delegate will only be populated if they are in fact named `i` and `s`. Otherwise, they'll be set to `0` and `null` with no indication that anything is wrong… this has been the source of the majority of the issues people have had using System.CommandLine."

Reflection-based binding by parameter name is a worked-out cautionary tale. The institute's design must not depend on naming coincidence; type-level keys (KeyPath, Tagged identifier, or symbol-as-instance) are required.

From the [Beta 4 announcement](https://github.com/dotnet/command-line-api/issues/1750):

> "No compelling use case arose for creating custom implementations of ICommand. The main reason they've been removed is to reduce the complexity of a redundant extension point."

Resonant with [API-IMPL-005] (one type per file) and [RES-018]'s "no premature abstractions": don't introduce protocols / extension points without demonstrated consumer demand.

### §1.6 Python `Click` and stdlib `argparse`

[Python docs argparse, click docs](https://click.palletsprojects.com/), Verified: 2026-05-15]

- **`argparse`**: imperative class-based, `ArgumentParser` is a mutable container; subcommands via `add_subparsers().add_parser(...)`; type via `type=callable`; help auto-generated; errors raise `SystemExit` by default.
- **`Click`**: decorator-based. `@click.command()` turns a function into a `Command`; `@click.group()` produces a `Group` that nests sub-commands; `Context` threads invocation state; `ParamType` is the conversion hook.

Click's `Context` object is interesting — it threads invocation state through callbacks (parent commands' parsed values are visible to children). In the institute design, a similar role is played by typed-throws error context + an explicit `Command.Context` value passed to `run()`.

### §1.7 Go `spf13/cobra` and `urfave/cli`

[`spf13/cobra`, `urfave/cli`, both MIT, Verified: 2026-05-15]

- **Cobra**: `Command` struct with `Run`/`RunE`/`PreRun`/`PreRunE`/`PostRun`/`PostRunE`/`PersistentPreRun(E)`/`PersistentPostRun(E)` lifecycle hooks. `Flags()` (local) vs `PersistentFlags()` (inherited by subcommands). `AddCommand(...)` composes.
- **urfave/cli**: flatter `cli.Command` with `Action func(context.Context, *cli.Command) error` and a `Flags []cli.Flag` slice. Supports POSIX clustering and prefix-match aliases.

Both are subcommand-heavy by design. The lifecycle-hooks shape is heavier than swift-argument-parser; the institute does not need it as a v1 surface. Run-on-leaf-subcommand-only is sufficient.

### §1.8 POSIX 12.2 and GNU long options (specifications)

#### POSIX 12.2 — IEEE Std 1003.1-2017, Chapter 12

[Open Group Base Specifications, [pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html), Verified: 2026-05-15]

14 numbered "Utility Syntax Guidelines". Load-bearing ones for token grammar:

| Guideline | Rule |
|---|---|
| 3 | Option name is a single alphanumeric character; multi-digit not allowed |
| 4 | Options preceded by `-` |
| 5 | Multiple options without arguments may cluster behind one `-`; the last may take an argument |
| 6 | Option and its argument are separate `argv` entries (except cluster-tail) |
| 7 | Option-arguments not optional (POSIX forbids `--flag[=value]`) |
| 9 | Options precede operands |
| 10 | `--` separator ends option parsing |

#### GNU long options

[GNU coding standards §4.8, [www.gnu.org/prep/standards/standards.html](https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces), Verified: 2026-05-15]

Extensions over POSIX:

- `--long-option` syntax with `=value` or space-separated value.
- Optional arguments allowed for long options: `--flag[=value]`.
- Unambiguous-prefix abbreviation: `--out` accepted for `--output` if unique. (Most modern libraries opt out; we will too.)

Both POSIX 12.2 and GNU long options are specifications with stable text that mirrors cleanly into the institute's `[API-NAME-003]` spec-mirroring naming convention.

### §1.9 Cross-cutting synthesis

| Dimension | optparse-applicative | clap (derive) | swift-argument-parser | Click | System.CommandLine | Cobra |
|---|---|---|---|---|---|---|
| Schema-as-data | Yes (Parser a) | Yes (Command tree) | Partial (via reflection) | No (decorator side-effects) | Yes (Symbol tree) | Yes (Command tree) |
| One value drives parse+help+completion | Yes | Shared tree, parallel emitters | Shared tree, parallel emitters | Parallel; argcomplete external | Built-in Help+Suggest | Shared tree |
| Strong types per option | Yes | Yes | Yes | Yes (ParamType) | Yes (`Option<T>`) | Limited (string-typed) |
| Subcommands as sum types | Yes | Yes (enums) | No (`[Type]` array) | No (Group registry) | No (Command tree) | No (Command tree) |
| Typed errors | Yes | Yes | No | No | No | No (Go errors) |
| Validation hooks | Combinators | `value_parser` + custom | `Validatable.validate()` | Callback per param | `AddValidator` | `RunE` returns error |
| Env-var fallback | Manual | `Arg::env(...)` | `transform:` workaround | `envvar=` | `SetDefaultValueFactory` | Viper integration |

Universally adopted features and their [RES-018] classification:

| Feature | Adoption | [RES-018] case |
|---|---|---|
| `--` end-of-options separator | All (POSIX-mandated) | (d) standards-internal — POSIX G10 |
| Short-flag clustering (`-abc`) | clap, optparse, urfave, System.CL | (d) standards-internal — POSIX G5 |
| `--long=value` and `--long value` | All except strict POSIX | (d) standards-internal — GNU long options |
| `-vvv` repetition counts | clap (`ArgAction::Count`), Cobra+Viper, optparse manual | (a) cross-cutting — count-of-occurrences is a generic Parser.Many shape with `.count` projection |
| Subcommand hierarchies | All | (a) cross-cutting — sum-type dispatch via `Parser.OneOf` (already in primitives) |
| Env-var defaults | clap, Click, Cobra+Viper, System.CL | (b) domain-owned at L1 — "process environment fallback" is CLI-domain vocabulary |
| Hidden options | clap, Cobra, Click | (b) domain-owned at L1 — help-visibility metadata is CLI-specific |
| Mutually-exclusive groups | clap (`ArgGroup`), argparse, optparse `<\|>` | (a) cross-cutting — already expressible via `Parser.OneOf` |
| Arity (`0..1`, `0..n`, `1..n`) | All | (a) cross-cutting — repetition combinator (Parser.Many) |
| Tab completion emission | All | composition — `Serializer.Protocol` per format |
| Help/usage text emission | All | composition — `Serializer.Protocol` |
| Version flag | All | (b) domain-owned at L1 — package-metadata hook |

The (a) cases are mostly already covered by `swift-parser-primitives`'s combinator catalog. The (b) cases form the L1 vocabulary of `swift-argument-primitives`. The (d) cases populate L2 spec packages.

---

## Part II: Theoretical Grounding (per [RES-022])

### §2.1 Free Applicative encoding for parsers

An applicative parser for argv is structurally a free Applicative over an option-functor:

```
Parser a = Pure a
         | forall x. Ap (Option (x -> a)) (Parser x)
         | forall a. Alt (Parser a) (Parser a)
```

(Where `Option` is the per-option functor carrying name, metavar, help, parser-from-string.) The free Applicative retains the *entire* tree of options as data — `(<*>)` is constructor application, not function composition, so the structure is preserved for introspection.

This is why optparse-applicative can generate help from the same `Parser a` it uses to parse: the value retains the schema.

### §2.2 Institute encoding — Body-tree retention via result builder

The institute's `Parser.Builder` is a `@resultBuilder` that produces a `Body` value composing sub-parsers. Each combinator (`Parser.Take.Sequence`, `Parser.OneOf.Two`, `Parser.Map`, …) is a struct whose stored properties are its sub-parsers. The Body is a heterogeneous AST mirroring the source's structure.

The key insight: **the Body is data, not opaque continuation**. A visitor protocol can walk a Body and extract schema metadata. Concretely, if we constrain the CLI Schema to use `Argument.*` combinators (positional, option, flag, group, subcommand), each of which conforms to an `Argument.Schema.Node` visitor protocol, then help / completion / manpage generators are visitors over the Schema:

```swift
extension Argument.Schema {
    public protocol Node: ~Copyable {
        func accept<V: Argument.Schema.Visitor>(_ visitor: inout V) throws(V.Failure)
    }

    public protocol Visitor: ~Copyable {
        associatedtype Failure: Swift.Error
        mutating func visit<V>(positional: Argument.Positional<V>) throws(Failure)
        mutating func visit<V>(option: Argument.Option<V>) throws(Failure)
        mutating func visit(flag: Argument.Flag) throws(Failure)
        mutating func visit<G>(group: Argument.Group<G>) throws(Failure)
        mutating func visit<S>(subcommand: Argument.Subcommand<S>) throws(Failure)
    }
}
```

Note the visitor methods use the labeled-method shape (`visit(positional:)`) rather than compound-noun method names (`visitPositional`) per [API-NAME-002] / [API-NAME-008] (single-form operation, disambiguated by argument label).

Help generator, bash-completion generator, zsh-completion generator, manpage generator — all are `Argument.Schema.Visitor` conformers with different `Buffer` types. Each is a `Serializer.Protocol` from the user's perspective; internally each visits the Schema once.

### §2.3 Subcommand dispatch as `Parser.OneOf` over sum types

Subcommands in clap/optparse-applicative are sum types; in swift-argument-parser they are `[ParsableCommand.Type]` arrays losing static dispatch. The institute already has `Parser.OneOf.{Two, Three, Sequence}` returning a `Product` failure type via Either-chaining. A subcommand dispatch is:

```swift
// Subcommands form a sum type. `Git` itself IS the top-level command — domain noun, not compound.
enum Git: Command.`Protocol` {
    case clone(Clone)
    case status(Status)
    case commit(Commit)
}

// Its parser is OneOf over per-subcommand parsers, plus the subcommand-name literal
extension Git {
    static var schema: Command.Schema<Self> {
        Argument.Subcommand.Choice {
            Argument.Subcommand(name: "clone") { Clone.schema }.map(Self.clone)
            Argument.Subcommand(name: "status") { Status.schema }.map(Self.status)
            Argument.Subcommand(name: "commit") { Commit.schema }.map(Self.commit)
        }
    }
}
```

Static dispatch on the parsed `Git` value is exhaustive; the compiler enforces coverage. Subcommand types `Clone`, `Status`, `Commit` live each in its own file per `[API-IMPL-005]`.

### §2.4 Where the [String]-typed input differs from byte-typed input

`Parser.Protocol`'s `Input` is `~Copyable & ~Escapable`. `Parser.Input.Collection<Base>` works over any indexed `Collection`. For argv, `Input = Parser.Input.Collection<Array<String>.Indexed<String>>` — each "byte" position is one whole argv element.

This differs from byte-typed input in three ways:

1. **No clustering at the parser level**: `-abc` is *one* argv element; the cluster expansion happens in a pre-tokenization phase (L2 POSIX standard) before the schema parser runs. The pre-tokenizer produces a normalized stream of "tokens" the schema parser consumes.
2. **No `--long=value` splitting**: same — pre-tokenization splits `--long=value` into the `--long` token + `value` token.
3. **String-typed value conversion**: the per-option value parser converts `String → Value`. This is `ExpressibleByArgument`'s role in swift-argument-parser; in the institute design it is an `Argument.Codable` sibling protocol (per the family-codable-convention deferred research) attached at the value type.

The two-stage architecture:

```
argv ([String])
   │
   ▼ POSIX 12.2 + GNU tokenizer (L2)
   │
[Argument.Token] (long, short, value, separator, positional)
   │
   ▼ Schema parser (L3, built on swift-parser-primitives)
   │
Command instance (parsed)
```

The tokenizer is pure POSIX/GNU; the schema parser is pure schema-driven; they compose without leaking POSIX/GNU semantics into the schema, and the schema is independent of the tokenization strategy. (A Windows `/flag` tokenizer would slot in without touching the schema parser.)

---

## Part III: Architectural Analysis

### §3.1 [RES-018] Classification — enumerated explicitly per [RES-030]

The four [RES-018] cases:

| Case | Description | Gating |
|---|---|---|
| (a) Cross-cutting primitive | Type family for re-use across unrelated domains | Composition check + cross-domain-fit check |
| (b) Domain-owned vocabulary at L1 | A single domain's L1 vocabulary | `[MOD-DOMAIN]` semantic coherence only |
| (c) Layer-agnostic primitive surfaced higher up | Pulled down to L1 by default | `[MOD-DOMAIN]` correct home; originating L2/L3 is first consumer |
| (d) L2 standards-internal type mirroring a spec | Names mirror the spec | `[API-NAME-003]` spec fidelity |

Per-package classification of the proposal:

| Component | Layer | Case | Justification |
|---|---|---|---|
| `swift-argument-primitives` | L1 | **(b) domain-owned vocabulary** | CLI argument primitives (Name, Arity, Visibility, Help text, environment-variable-name) form a coherent semantic vocabulary for the CLI domain; not justified by a second domain (no consumer outside CLI parsing reuses "Argument.Arity") — governed by `[MOD-DOMAIN]` alone. |
| `swift-ieee-1003` | L2 | **(d) standards-internal** | POSIX 12.2 (IEEE Std 1003.1-2017 Chapter 12) is a published spec with 14 numbered guidelines; names mirror the spec terminology per `[API-NAME-003]`. |
| `swift-gnu` | L2 | **(d) standards-internal** | GNU coding standards §4.8; long-option syntax is a stable specification, names mirror GNU terminology. |
| `swift-arguments` | L3 | **n/a** — composition layer | L3 foundations are not gated by [RES-018]; they compose L1 primitives + L2 standards by definition. |

No (a) cross-cutting primitive is proposed. No [RES-018] gates fire requiring a second-domain consumer or pull-down justification. This is the right shape.

### §3.2 Where does the L3 land — `swift-arguments` vs filling `swift-command-line-interface`?

Two candidate L3 names: `swift-arguments` (user-proposed) and `swift-command-line-interface` (existing empty placeholder).

| Criterion | `swift-arguments` | `swift-command-line-interface` |
|---|---|---|
| Maps to the institute's noun-namespacing | `Arguments` → `Argument.*` types | `CommandLineInterface` → ?? (no clean nesting) |
| Scope precision | Argv parsing + help/completion/manpage emit | Broader — implies stdio, terminal, signal handling, … |
| Naming-framework alignment | Matches `2026-05-12-typed-identifier-naming-framework.md` axiom 2 ("most-generic English noun for the domain entity") | `command-line-interface` is a compound; would force compound types or sub-namespace |
| Composes with broader CLI app frameworks | Yes — a future `swift-cli-app` could compose `swift-arguments` + `swift-console` + `swift-process` + `swift-terminal-primitives` | Forces the broader framework's name onto the narrow argument-parsing artifact |
| Currently empty | n/a (would be new) | Yes — pure placeholder, no consumers, no API |

**Recommendation**: use `swift-arguments` for the L3 home. Retire `swift-foundations/swift-command-line-interface` placeholder repo (or leave it dormant for a future broader CLI-app framework). The user-proposed name is correct and the namespace-noun maps cleanly: `swift-arguments` → `Arguments` module → `Argument.*` types.

### §3.3 `swift-argument-primitives` — L1 design

#### What it owns

The CLI-domain vocabulary atoms. NOT bytes (already covered by parser-primitives). NOT specifications (those go to L2). The vocabulary the schema layer composes:

```
Argument                                  — top-level namespace enum
  Argument.Name                           — short ('f') | long ("foo") | both | custom
    Argument.Name.Short                   — single alphanumeric per POSIX G3
    Argument.Name.Long                    — multi-character per GNU §4.8
  Argument.Arity                          — exactly(1) | atMost(N) | atLeast(N) | range(N...M) | count
  Argument.Visibility                     — visible | hidden
  Argument.Help                           — descriptor type (abstract, discussion, valueDescription, default)
  Argument.Environment.Variable.Name      — process-env identifier (e.g., "MYAPP_VERBOSITY")
  Argument.Token                          — parsed argv element
    Argument.Token.Kind                   — long | shortCluster | value | separator | positional
  Argument.Error                          — typed errors (unknownOption, missingValue, invalidValue, …)
  Argument.Position                       — diagnostic position in argv
  Argument.Codable                        — sibling format-Codable protocol (value ↔ String)
  Argument.Parseable                      — sibling protocol for parse-only (String → value)
  Argument.Serializable                   — sibling protocol for serialize-only (value → String)
```

The protocols `Argument.Codable` / `Argument.Parseable` / `Argument.Serializable` are sibling protocols (not refinements) of the canonical `Coder_Primitives.Codable` / `Parser_Primitives_Core.Parseable` / `Serializer_Primitives_Core.Serializable`, per the family-codable-convention pattern established in the framing memo. This means `Int: Argument.Codable` can coexist with `Int: JSON.Codable` and future format conformances — one format ≠ canonical-format choice.

Files (one type per file per `[API-IMPL-005]`):

```
Sources/
  Argument Primitives/
    Argument.swift                          — namespace enum
    Argument.Name.swift
    Argument.Name.Short.swift
    Argument.Name.Long.swift
    Argument.Arity.swift
    Argument.Visibility.swift
    Argument.Help.swift
    Argument.Environment.swift              — sub-namespace
    Argument.Environment.Variable.swift
    Argument.Environment.Variable.Name.swift
    Argument.Token.swift
    Argument.Token.Kind.swift
    Argument.Error.swift
    Argument.Position.swift
    (Argument.Codable.swift / Argument.Parseable.swift / Argument.Serializable.swift
     RELOCATED to L3 swift-arguments per [FAM-009] v1.0.4 — see §3.5 L3 target structure)
    exports.swift
```

#### Dependencies

Per `[ARCH-LAYER-001]`, L1 depends only on lower-L1 / no-deps. The vocabulary types are mostly pure values:

| Type | Underlying |
|---|---|
| `Argument.Name.Short` | `Swift.Character` (validated single ASCII alphanumeric) |
| `Argument.Name.Long` | `Swift.String` (validated `[a-zA-Z][a-zA-Z0-9-]*`) — possibly `Tagged<_, String>` via `swift-tagged-primitives` |
| `Argument.Arity` | enum with associated `Int` |
| `Argument.Visibility` | enum |
| `Argument.Help` | struct of `String`s |
| `Argument.Environment.Variable.Name` | `Tagged<_, String>` per the typed-identifier framework |
| `Argument.Token`, `Argument.Token.Kind` | sum types over `Substring` |
| `Argument.Error` | typed errors |
| `Argument.Position` | `Tagged<_, Int>` over argv index |

External institute deps: possibly `swift-tagged-primitives` (for typed string wrappers per `2026-05-12-typed-identifier-naming-framework`). No Foundation (Foundation-free per `[PRIM-FOUND-001]`).

#### Cross-domain-fit check (per [RES-018] — case (b) only requires `[MOD-DOMAIN]` coherence, but per [RES-029] semantic-identity test confirms this is genuinely case (b) not case (a))

Is `Argument.Arity` cross-cutting? Consider candidate second-domain consumers:

- **REPL parsing** — a REPL command takes "arity" arguments. Plausibly reuses `Argument.Arity`. Cross-domain fit *possible*.
- **HTTP route handlers** — `/users/:id?` is path-segment-arity. Distantly analogous, but the route-parsing domain has its own vocabulary (`Path.Pattern`, `Query.Parameter`) and would not reuse `Argument.Arity` directly.
- **Config-file parsing** — config keys can have arity. But config-file parsing has its own vocabulary; reusing `Argument.Arity` over conceptually-similar config-key-arity is a stretch.

Classification: case **(b) domain-owned vocabulary at L1** is correct. A future REPL-arguments package may reuse `Argument.*` types directly, in which case the "domain" is "argument-like-input" rather than "CLI arguments specifically." This is fine — domain boundaries are not rigid, and `swift-argument-primitives` would cleanly serve both.

### §3.4 L2 standards — `swift-ieee-1003` (v1) — **swift-gnu collapsed to L3 inline v1.0.7**

#### Why L2 not L1

POSIX 12.2 is a *specification*, not vocabulary. The institute pattern per `[API-NAME-003]` and `[ARCH-LAYER-001]` is:

- L1 owns vocabulary (`UUID`, `Path`, `Argument.Arity`)
- L2 implements specifications mirroring the spec's terminology (`RFC_4122.UUID`, `ISO_32000.Page`, `IEEE_1003.UtilitySyntax.Token`)

POSIX 12.2 utility-syntax tokenization is a spec implementation — IEEE 1003.1 Chapter 12 is a numbered, authority-published standard. L2 placement matches the `swift-iso/swift-iso-32000`, `swift-ietf/swift-rfc-4122` precedent per [ECO-004].

**GNU long-options (`--long-option=value` / `--long value`) collapsed to L3 inline v1.0.7**: the "spec" is ~10 paragraphs of prose in GNU coding standards §4.7-4.8, not an IEEE-numbered standard. The convention is small enough to handle inside `swift-arguments` at L3 without a separate L2 package. No `swift-gnu` org or package needed for v1. The argv-tokenizer in `swift-arguments` handles both POSIX-12.2 short-flag forms (via dependency on `swift-ieee-1003`) and GNU long-option forms (inline at L3).

#### Package shapes

`swift-ieee-1003`:

```
IEEE_1003.UtilitySyntax
  .Token                          — POSIX-shaped argv token (NOT the same as Argument.Token at L1; each tokenizer
                                    has its own intermediate token type before normalization at L3)
    .Kind                         — short(.alphanumeric) | value | separator | positional | endOfOptions
  .Guideline                      — namespace mirroring the 14 numbered guidelines (spec-mirroring per [API-NAME-003])
    .Guideline.G3                 — "option name is single alphanumeric"  ┐
    .Guideline.G4                 — "options preceded by '-'"             │  Lint exemption: G{number}
    .Guideline.G5                 — clustering                            │  is spec-literal per POSIX 12.2
    .Guideline.G6                 — option-argument separation            │  numbering. // swiftlint:disable:next
    .Guideline.G10                — "--" separator                        │  compound_type_name spec-mirror
    (… all 14 guidelines as types or static validation rules)             ┘  [RULE-EXEMPT-spec-mirror]
  .Tokenizer                      — Parser.`Protocol` from [String] (argv) to [Token]
  .Error                          — typed errors keyed to guideline violations
```

**Note on `Guideline.G{number}` lint exemption**: `Lint.Rule.Naming.CompoundType` would otherwise flag `G3` etc. as compound (letter+digit boundary). Per [API-NAME-003] spec-mirroring rule, these names mirror IEEE 1003.1 §12.2 verbatim ("Guideline 3", "Guideline 4", etc.) and are exempt. Each `Guideline.G{n}` declaration in source MUST carry a `// swiftlint:disable:next` directive with a `reason:` field citing the spec section, per [RULE-EXEMPT-*] discipline in the **rule-exemptions** skill.

`swift-gnu` — **DROPPED FROM v1 per §3.15 scope discipline.** GNU long-option syntax (`--long-option=value`, `--long value`) is handled inline at L3 in `swift-arguments`. Filed as v2 / future direction if/when GNU specs accumulate enough to warrant their own org.

The IEEE 1003 package is the v1 L2; namespace and type names mirror the POSIX 12.2 spec per [API-NAME-003].

#### Composition at L3

`swift-arguments` provides a default tokenizer that composes POSIX 12.2 short-flag forms (via `swift-ieee-1003`) with GNU long-option forms (inline at L3):

```swift
// In swift-arguments
extension Argument.Token {
    public static func tokenizer() -> some Parser.`Protocol`<
        Parser.Input.Collection<Array<String>.Indexed<String>>,
        [Argument.Token],
        Argument.Tokenizer.Error
    > {
        Argument.Tokenizer.Default()
    }
}

// Argument.Tokenizer.Default internally calls IEEE_1003.UtilitySyntax.Tokenizer
// AND handles GNU long-option forms (--long-option=value / --long value) inline.
// Windows /flag style is out of v1 scope; if added later, structurally lives at
// swift-microsoft/swift-windows-32 as another L2 dependency.
```

Users wanting strict POSIX (e.g., for an embedded utility) can supply their own tokenizer omitting the GNU long-option layer. Windows `/flag` style is out of v1 scope.

#### Naming — `swift-ieee-1003`, not narrower per-chapter form

The institute's L2 standards-package precedent is `swift-{org}-{number}` — `swift-rfc-4122`, `swift-rfc-8259`, `swift-rfc-9562`. The number identifies a standards-body-published spec; the namespace inside the package mirrors the spec's terminology per `[API-NAME-003]`.

Applied here:

- **`swift-ieee-1003`** — IEEE 1003 series, i.e. POSIX. (IEEE 1003.2 was merged into 1003.1 long ago; for practical purposes "POSIX today" ≡ IEEE 1003.) Initial content: `IEEE_1003.UtilitySyntax.*` (Chapter 12). Future additions (POSIX regex syntax, POSIX path conventions, POSIX locale rules) land in the same package as their respective namespaces, e.g. `IEEE_1003.RegularExpressions.*`, `IEEE_1003.Pathname.*`.
- ~~**`swift-gnu`**~~ — collapsed to L3 inline v1.0.7 per §3.15 scope discipline.

This is a *broader* package name than the v1 content strictly requires. The trade-off:

| | Broader name (`swift-ieee-1003`, `swift-gnu`) | Narrower name (`swift-ieee-1003-1-12-utility-syntax`, `swift-gnu-long-options-standard`) |
|---|---|---|
| Matches `swift-rfc-{number}` precedent | Yes | No (forces new package-naming variant) |
| Future additions inside the same spec family | Land in-package (cheap) | Force new packages or rename |
| v1 scope clarity | Lower — name implies more than v1 contains | Higher — name documents v1 contents |
| Package proliferation | Lower | Higher |
| Conciseness | High | Low |

The broader name wins: institute discipline prefers lower package proliferation, the `swift-rfc-{number}` precedent is well-established, and v1 content's actual scope is documented in the package README + DocC, not encoded in the package name. Future POSIX or GNU additions land in the same package without forcing a name change.

Two packages (not one bundled `swift-argument-syntax-standard`) because POSIX and GNU are distinct standards bodies with independent revision histories. `swift-uuids` (per `2026-05-13-swift-uuids-l3-design.md`) composes separate `swift-rfc-4122` + `swift-rfc-9562` packages for the same structural reason — separate specs, separate revision lifecycles.

### §3.5 `swift-arguments` — L3 design

The composed product. Combines:

- L1: `swift-argument-primitives` (vocabulary)
- L1: `swift-parser-primitives` (argv → Schema → Command parsing)
- L1: `swift-serializer-primitives` (Command → help/completion/manpage emission)
- L2: `swift-ieee-1003` (POSIX tokenization)
- L2: `swift-gnu` (GNU long-option tokenization)

Optional L1 / L3 deps:

- `swift-coder-primitives` if any value type's String-conversion uses canonical Coder
- `swift-console` for default error/help output channel (or pass `inout some Output`)
- `swift-process` for `exit(_:)` and signal handling integration (might belong to a separate future `swift-cli-app`)

#### Top-level namespace

```
Command
  .Protocol                                   — single always-async protocol; requires schema + run
                                                (per U3 — see `2026-05-15-command-protocol-sync-async-design.md`)
  .Configuration                              — static metadata (name, abstract, version, aliases, …)
  .Schema<Root>                               — schema-as-data; the result of Body+Builder
  .Builder                                    — @resultBuilder
  .Error                                      — typed errors at the Command-parser level
  .Context                                    — invocation state, optional, passed to run()
  .Exit                                       — typed exit-code structure
  .Help                                       — Serializer.`Protocol`<Schema<Root>, String, Never>

  — DEFERRED to v2+ per §3.15 v1 scope discipline:
  .Completion (Bash / Zsh / Fish / PowerShell) — D10; separate L3 domain `swift-shell-completion`
  .Manpage                                     — D11; separate L3 package `swift-manpages`
```

#### Surface — usage example matching `Repeat`

The institute equivalent of the swift-argument-parser `Repeat` example from §1.2:

```swift
struct Repeat: Command.`Protocol` {
    var phrase: String
    var count: Int = 2
    var counter: Bool = false

    static var configuration: Command.Configuration {
        Command.Configuration(
            name: "repeat",
            abstract: "Repeats your input phrase."
        )
    }

    static var schema: Command.Schema<Self> {
        Command.Schema {
            Argument.Positional(\.phrase, help: .init(abstract: "The phrase to repeat."))
            Argument.Option(\.count,
                            name: .long("count"),
                            help: .init(abstract: "The number of times to repeat 'phrase'."))
            Argument.Flag(\.counter,
                          name: .long("counter"),
                          help: .init(abstract: "Include a counter with each repetition."))
        }
    }

    mutating func run() async throws(Command.Error) {
        for i in 1...count {
            print(counter ? "\(i): \(phrase)" : phrase)
        }
    }
}

@main enum Main {
    static func main() async {
        await Command.run(Repeat.self)
    }
}
```

**Notes**:
- `mutating func run() async throws(Command.Error)` per the v1.0.4 U3 resolution (`swift-institute/Research/2026-05-15-command-protocol-sync-async-design.md`): single always-async protocol; sync command bodies simply omit `await` and `async`-context-needing operations. `Command.Async.Protocol` removed.
- `mutating` (Copyable default) per P0 / direction D8; `consuming` moves to the future `Command.Resource.Protocol` (~Copyable opt-in, design arc deferred).

Comparison with swift-argument-parser:

| Aspect | swift-argument-parser | swift-arguments |
|---|---|---|
| Schema source | Property wrappers + reflection | Static `schema: Command.Schema` |
| Typed throws | No (`throws`) | Yes (`throws(Command.Error)`) |
| Property writes | Through `@Argument`/`@Option`/`@Flag` storage | Direct `var phrase: String` |
| Subcommand dispatch | `[ParsableCommand.Type]` array | Sum-type via `Argument.Subcommands` |
| Help/completion | `HelpGenerator` + per-shell generators | `Command.Help` / `Command.Completion.*` Serializers |
| Reflection at parse time | Yes (`Mirror`, `Decodable`) | No (schema is compile-time-known) |
| `~Copyable` | No | Yes (`consuming func run`) |
| Foundation dependency | Yes | No |

The verbosity trade is slightly higher in the institute version because the schema is explicit rather than property-wrapper-inferred. This is intentional — the schema is the source of truth and benefits from being explicit text (per `[IMPL-INTENT]`: code reads as intent).

#### Sugar: `@CLI` macro (deferred to v2)

A `@CLI` macro could close the verbosity gap by lowering to the explicit schema. Following clap's Derive→Builder relationship:

```swift
@CLI
struct Repeat {
    @CLIPositional(help: "The phrase to repeat.")
    var phrase: String

    @CLIOption(name: .long("count"), help: "The number of times to repeat 'phrase'.")
    var count: Int = 2

    @CLIFlag(name: .long("counter"), help: "Include a counter with each repetition.")
    var counter: Bool = false

    mutating func run() async throws(Command.Error) { ... }
}
```

Expands at compile time to a `Command.Protocol` conformance with the explicit `schema` property generated. This is a v2 addition — v1 ships the explicit schema and a clean `Body+Builder` DSL only. Macro design is non-trivial (`SwiftSyntax`, key-path stability, default-value-extraction) and should be authored only after the DSL surface is proven.

Note on naming: Swift macros use compound names at file scope per [API-NAME-001]'s macro exception (the language does not support nested macro declarations). `@CLIPositional` / `@CLIOption` / `@CLIFlag` are the correct shape; `@CLI.Positional` (dotted) would not parse.

#### Subcommand example

```swift
enum Git: Command.`Protocol` {
    case clone(Clone)
    case status(Status)
    case commit(Commit)

    static var configuration: Command.Configuration {
        Command.Configuration(name: "git", abstract: "Distributed version control.")
    }

    static var schema: Command.Schema<Self> {
        Command.Schema {
            Argument.Subcommands {
                Argument.Subcommand("clone", Clone.schema).map(Self.clone)
                Argument.Subcommand("status", Status.schema).map(Self.status)
                Argument.Subcommand("commit", Commit.schema).map(Self.commit)
            }
        }
    }

    mutating func run() async throws(Command.Error) {
        switch self {
        case .clone(var c): try await c.run()
        case .status(var s): try await s.run()
        case .commit(var c): try await c.run()
        }
    }
}
```

Exhaustive sum-type dispatch on subcommands. Statically typed. The dispatch over `case` is compiler-checked for exhaustiveness — a new subcommand cannot be silently forgotten.

### §3.6 Bidirectionality — Help/Completion/Manpage as Serializers (per §2.2)

Each emission target is a separate `Serializer.Protocol` over the same Schema. Sketch:

```swift
extension Command {
    public struct Help<Root: Command.`Protocol`>: Serializer.`Protocol` {
        public typealias Output = Command.Schema<Root>
        public typealias Buffer = String
        public typealias Failure = Never

        public func serialize(_ output: Schema<Root>, into buffer: inout String) {
            Help.Visitor.emit(schema: output, configuration: Root.configuration, into: &buffer)
        }
    }

    // v2+ Completion / Manpage Serializers are deferred per §3.15 v1 scope discipline.
    // They follow the SAME pattern: a Serializer.`Protocol` conformer with its own Buffer type
    // and a domain-specific Visitor that walks the Schema. The framework is forward-compatible:
    // adding Completion or Manpage in v2 requires no re-architecting at L1/L2 or in Schema.
}
```

The Help Serializer is independently testable, independently maintainable, and the schema is walked once per emission. The visitor pattern keeps emission concerns localized to each visitor's logic.

**Forward-compatibility for v2+ emitters** (Completion / Manpage / others): each follows the same shape — a `Serializer.\`Protocol\`` conformer over `Command.Schema<Root>` with its own `Buffer` type and a domain-specific Visitor implementation. The §2.2 schema-as-data foundation is the load-bearing structural decision; v1 instantiates ONE such Serializer (Help), v2+ adds more without re-architecting. Per §3.15 v1 scope discipline.

### §3.7 What `Coder.Protocol` does NOT model — and why that is fine

The framing memo's `Coder.Protocol: Parser.Protocol, Serializer.Protocol` shape has *one* Buffer associated type. The argument-parsing problem has *N* Buffer types (one per emission format). A single `Coder` cannot bundle them.

Two design options were considered:

| Option | Approach | Verdict |
|---|---|---|
| (i) Extend `Coder.Protocol` to multi-Buffer | Add `associatedtype Buffers: TupleProtocol` carrying all emission formats | Breaks the leaf-not-composable design intent; over-generalizes for one use case |
| (ii) Schema-as-data + separate Serializers | Keep `Coder.Protocol` unchanged; the Schema is a value, and Help/Completion/Manpage are independent Serializers over the same Schema | Preserves Coder design; matches optparse-applicative's elegant pattern |

**Option (ii) is the chosen design.** It explicitly preserves `Coder.Protocol`'s leaf-not-composable framing — a single value-format pair stays the right framing for codecs like `JSON.Coder` and `Binary.Coder`. The CLI argument-parsing case is structurally different: it is one-parser-many-emitters, which is *not* what `Coder.Protocol` describes. Forcing them into the same protocol would distort both.

This is structural-correctness over diff-size per `[RES-022]`.

### §3.8 Multi-target structure and tier classification

The four proposed packages each follow the institute's multi-target convention per the **modularization** skill ([MOD-001] Core / [MOD-005] umbrella / [MOD-011] TS / [MOD-017] Namespace / [MOD-012] layer-adapted naming / [MOD-024] TS spine / [MOD-026]+[MOD-030] fine-grained per-type modularization).

#### Layer-adapted target naming per [MOD-012]

| Role | L1 (Primitives) | L2 (Standards) | L3 (Foundations) |
|---|---|---|---|
| Namespace target ([MOD-017]) | `Argument Namespace` | `IEEE_1003 Namespace` / `GNU Namespace` | `Command Namespace` |
| Core | `Argument Primitives Core` | `IEEE_1003 Core` / `GNU Core` | `Command Core` |
| Variant | `Argument {Variant} Primitives` | `IEEE_1003 {Variant}` | `Command {Variant}` |
| StdLib integration ([MOD-010]) | — (relocated to L3 v1.0.4) | — | `Argument Standard Library Integration` (L3 swift-arguments — relocated v1.0.4 per [FAM-009]) |
| Umbrella ([MOD-005]) | `Argument Primitives` | `IEEE_1003` / `GNU` | `Command` |
| Test Support ([MOD-011]) | `Argument Primitives Test Support` | `IEEE_1003 Test Support` / `GNU Test Support` | `Command Test Support` |

The Namespace target carries no layer suffix at any layer per [MOD-017]'s naming exception — the namespace identity is layer-invariant.

#### swift-argument-primitives (L1) — proposed target shape

Following [MOD-026]+[MOD-030] fine-grained per-type modularization, swift-argument-primitives decomposes one target per type-family:

| Target | Content | Depends on |
|---|---|---|
| `Argument Namespace` | `public enum Argument {}` only ([MOD-017] dependency invariant) | — |
| `Argument Primitives Core` | Vocabulary types: `Name` (+ `Short`/`Long`), `Arity`, `Visibility`, `Help`, `Token` (+ `Kind`), `Error`, `Position`, `Environment` namespace + `Environment.Variable.Name`. External re-exports for downstream variants. | `Argument Namespace`, `Tagged Primitives Core` (for `Environment.Variable.Name`), stdlib |
| `Argument Positional Primitives` | `Argument.Positional<V>` parser-producing type | `Argument Primitives Core`, `Parser Primitives Core` |
| `Argument Option Primitives` | `Argument.Option<V>` | `Argument Primitives Core`, `Parser Primitives Core` |
| `Argument Flag Primitives` | `Argument.Flag` | `Argument Primitives Core`, `Parser Primitives Core` |
| `Argument Group Primitives` | `Argument.Group<G>` | `Argument Primitives Core`, `Parser Primitives Core` |
| `Argument Subcommand Primitives` | `Argument.Subcommand<S>`, `Argument.Subcommand.Choice` (result-builder home) | `Argument Primitives Core`, `Parser Primitives Core` |
| `Argument Schema Primitives` | `Argument.Schema<Root>`, `Argument.Schema.Node`, `Argument.Schema.Visitor` | `Argument Positional Primitives` … `Argument Subcommand Primitives` (uses all sub-types) |
| ~~`Argument Primitives Standard Library Integration`~~ — **RELOCATED to L3 v1.0.4** per [FAM-009] (see swift-arguments target table below) | (target removed from L1 v1.0.4) | — |
| `Argument Primitives` (umbrella) | `exports.swift` only — `@_exported public import` every target above ([MOD-005]) | All targets above |
| `Argument Primitives Test Support` ([MOD-011]) | Test fixtures, helpers; re-exports `Tagged_Primitives_Test_Support` per [MOD-024] spine | `Argument Primitives`, `Tagged Primitives Test Support` |

Max depth from Core to leaf: 2 (Core → Schema → … → umbrella) — within [MOD-007] depth ≤ 3 budget.

#### swift-ieee-1003 (L2) — proposed target shape

| Target | Content | Depends on |
|---|---|---|
| `IEEE_1003 Namespace` | `public enum IEEE_1003 {}` | — |
| `IEEE_1003 Core` | Shared types (errors, position primitives if any) | `IEEE_1003 Namespace`, `Argument Primitives Core` (the namespace target re-exports `Argument` for consumers) |
| `IEEE_1003 UtilitySyntax` | Chapter 12 — `Token`, `Token.Kind`, `Tokenizer` (Parser.Protocol conformance), `Guideline.*`, `Error` | `IEEE_1003 Core`, `Argument Primitives` (for `Argument.Token` output), `Parser Primitives` |
| `IEEE_1003` (umbrella) | `exports.swift` only — re-exports `IEEE_1003 UtilitySyntax`; future POSIX chapters land here | All sub-targets |
| `IEEE_1003 Test Support` | TS spine | `IEEE_1003`, `Argument Primitives Test Support` (spine anchor — lowest in-scope dep per [MOD-024]) |

Per [ARCH-LAYER-002] preferred shape: `IEEE_1003 UtilitySyntax`'s `exports.swift` carries `@_exported public import Argument_Primitives_Core` so downstream `swift-arguments` consumers don't need to dual-import L1 + L2 for tokenization.

#### swift-gnu (L2) — proposed target shape

Mirror of swift-ieee-1003:

| Target | Content | Depends on |
|---|---|---|
| `GNU Namespace` | `public enum GNU {}` | — |
| `GNU Core` | Shared types | `GNU Namespace` |
| `GNU LongOptions` | `Token`, `Token.Kind`, `Tokenizer`, `Error` | `GNU Core`, `Argument Primitives`, `Parser Primitives` |
| `GNU` (umbrella) | `exports.swift`; future GNU specs land here | All sub-targets |
| `GNU Test Support` | TS spine | `GNU`, `Argument Primitives Test Support` |

#### swift-arguments (L3) — proposed target shape

| Target | Content | Depends on |
|---|---|---|
| `Command Namespace` | `public enum Command {}` only (single always-async per U3 v1.0.4 — no Command.Async namespace) | — |
| `Command Core` | `Command.\`Protocol\``, `Command.Configuration`, `Command.Error`, `Command.Context`, `Command.Exit` (single always-async protocol per U3 v1.0.4) | `Command Namespace`, `Argument Primitives`, `Parser Primitives`, `Serializer Primitives`, L2 tokenizers |
| `Command Schema` | `Command.Schema<Root>`, `Command.Builder` | `Command Core`, `Argument Schema Primitives` |
| `Command Help` | `Command.Help<Root>: Serializer.\`Protocol\``, internal `Help.Visitor` | `Command Schema`, `Serializer Primitives` |
| ~~`Command Completion`~~ — DEFERRED to v2+ per §3.15 (D10) | (out of v1 scope; future `swift-shell-completion` L3 domain) | — |
| ~~`Command Manpage`~~ — DEFERRED to v2+ per §3.15 (D11) | (out of v1 scope; future `swift-manpages` L3 package) | — |
| **`Argument Standard Library Integration`** (NEW v1.0.4 per [FAM-009]) | `Argument.Codable`, `Argument.Parseable`, `Argument.Serializable` sibling protocols + stdlib conformances (`Int: Argument.Codable`, `String: Argument.Codable`, `Bool: Argument.Codable`, `Double: Argument.Codable`, …). Relocated from L1 per [PRIM-FOUND-004] substrate-friction exception. | `Argument Primitives`, stdlib (no other L3 deps — keeps target import-precision tight per [MOD-015]) |
| `Command` (umbrella) | `exports.swift` only — re-exports all sub-targets including `Argument Standard Library Integration` for default ergonomics | All sub-targets |
| `Command Test Support` | TS spine | `Command`, `Argument Primitives Test Support`, L2 TS modules |

Per [MOD-026]: v1 ships `Command Help` as a separate target so consumers depending only on argv parsing don't compile help-text-format code they don't need. Per [MOD-015] (primary decomposition): consumers writing CLI tools import the umbrella `Command`; consumers wanting only help-text emission (e.g., a build-time help generator) import only `Command Help`. v2+ `Command Completion` and `Command Manpage` follow the same target-decomposition pattern when added.

#### Cross-cutting modularization notes

- **[MOD-007] DAG depth**: each package's intra-target DAG stays at depth ≤ 3 (Namespace → Core → Variant → Schema). Umbrella sits at depth 4 from Namespace but is the convergence point, not a dependency on the path.
- **[MOD-024] Test Support spine**: each TS target anchors on the lowest in-scope upstream TS. swift-argument-primitives' TS → `Tagged_Primitives_Test_Support`; swift-ieee-1003 + swift-gnu TS → `Argument_Primitives_Test_Support`; swift-arguments TS → `Argument_Primitives_Test_Support` + L2 TS modules.
- **[MOD-014] cross-package integration via traits**: optional `swift-console` integration (colored help output, terminal-width-aware formatting) ships as a separate trait-gated target `Command Console Integration`, consumer-opt-in via `traits: ["Console"]`. Default install does not pull `swift-console`.
- **[MOD-010] StdLib Integration (RELOCATED to L3 v1.0.4)**: stdlib conformances to `Argument.Codable` / `Argument.Parseable` / `Argument.Serializable` (for `Int`, `String`, `Bool`, `Double`, etc.) live in `Argument Standard Library Integration` target at L3 swift-arguments, NOT L1 — per [FAM-009] hybrid placement rule (substrate-friction exception fires at L1; see §3.9). Consumers needing these conformances depend on swift-arguments at L3.

#### [PKG-DEP-001] Pre-publishable cross-repo deps use path-form

While the four packages are pre-publishable (pre-1.0, possibly PRIVATE GitHub visibility), all cross-repo dep declarations MUST use path-form per [PKG-DEP-001]:

```swift
// In swift-arguments/Package.swift, pre-publishable phase:
dependencies: [
    .package(path: "../../swift-primitives/swift-argument-primitives"),
    .package(path: "../../swift-primitives/swift-parser-primitives"),
    .package(path: "../../swift-primitives/swift-serializer-primitives"),
    .package(path: "../../swift-standards/swift-ieee-1003"),
    .package(path: "../../swift-standards/swift-gnu"),
]
```

Switch to URL-form per package as it lands tags and public visibility — a routine follow-up commit per [PKG-DEP-001]'s path → URL transition rule, not a design decision.

#### Tier classification per [PRIM-ARCH-001]

- **swift-argument-primitives** depends on swift-parser-primitives (Tier 10) and swift-tagged-primitives (Tier 0). `tier = max(deps) + 1 = 11`. This places it in Tier 11 (Platform) — high but acceptable; Tier 11 is the tier of platform-level primitives (async, clock, network), and CLI argument vocabulary composes parser machinery (Tier 10).
- **swift-ieee-1003**, **swift-gnu**: L2 standards, no formal tier slot; conventionally "L2 spec" outside the L1 tier DAG.
- **swift-arguments**: L3 foundation, no formal tier slot.

#### Swift 6 ecosystem settings

Per the institute ecosystem standard for all primitives packages (per `primitives` skill):

```swift
swiftLanguageModes: [.v6]

let settings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableExperimentalFeature("Lifetimes"),
    .strictMemorySafety(),
]
```

L2 standards and L3 foundations follow the same ecosystem-wide policy. Embedded compatibility per [PRIM-FOUND-002] is required at L1; L2/L3 inherit the discipline.

#### [ARCH-LAYER-007] Foundation discipline across all layers

The Foundation-free guarantee at L1 ([PRIM-FOUND-001]) extends through L2/L3 per [ARCH-LAYER-007]. swift-ieee-1003 / swift-gnu / swift-arguments main targets MUST NOT import Foundation. Foundation-adjacent interop (e.g., `URL` argument conversion, `Date` parsing, `JSONDecoder` config-file loading) ships in separately-declared `* Foundation Integration` subtargets that consumers opt into. swift-arguments' v1 scope explicitly omits Foundation-Integration targets; if added later they follow the pattern.

### §3.9 `Argument.Codable` placement — **RESOLVED v1.0.4 at L3**

**Status**: RESOLVED at L3 `swift-arguments`. See `swift-institute/Research/2026-05-15-family-codable-convention.md` for the full rationale and [FAM-009] hybrid placement rule. The remainder of this section documents the v1.0.0-through-v1.0.3 framing of the question for historical context per [RES-008]; the resolution holds for v1.0.4 forward.

[PRIM-FOUND-004] codifies that L1 friction for String/Scalar conversion is intentional. The Argument.Codable / Argument.Parseable / Argument.Serializable sibling-format protocols (per the family-codable-convention deferred research) describe value↔String conversion specifically for argv-shaped input. Two candidate homes:

| Home | Pros | Cons |
|---|---|---|
| L1 `swift-argument-primitives` (current proposal) | Mirrors the framing-memo precedent that sibling-format protocols live in their format namespace; Argument namespace is at L1 | L1 consumers using only vocabulary types get an easy String escape hatch; potentially violates [PRIM-FOUND-004] friction intent |
| L3 `swift-arguments` | The sibling protocols are codec attachments, not pure vocabulary; mirror swift-json's L3 home for `JSON.Codable` | The Argument namespace spans L1 + L3; protocols live where the *codec* lives, not where the *namespace* is rooted |

**Recommendation (RESOLVED v1.0.4)**: **L3 placement** in `swift-arguments`, codified by [FAM-009] in the companion family-codable-convention research doc (`swift-institute/Research/2026-05-15-family-codable-convention.md`). The substrate-friction exception fires: `Argument.Codable` bridges `Self ↔ Swift.String`, which is exactly what [PRIM-FOUND-004] gates at L1. Promotion one tier to L3 resolves the friction. Stdlib conformances (`Int: Argument.Codable`, `String: Argument.Codable`, etc.) move to an `Argument Standard Library Integration` target inside swift-arguments at L3. The historical L1 proposal text above remains for [RES-008] lifecycle traceability; the v1.0.4 resolution supersedes it.

### §3.10 Discovery findings — institute prior art (v1.0.3)

Comprehensive search of `swift-institute/Experiments/`, `swift-institute/Research/`, `swift-primitives/` (144 packages), `swift-foundations/` (169 packages) per principal direction "there's already SO MUCH available" surfaced material findings:

#### Existing institute prior art directly applicable

| Topic | Source | Relevance |
|---|---|---|
| WritableKeyPath + ~Copyable interaction | `swift-institute/Research/mutator-writable-keypath-interaction.md` + experiment `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/` | **Closes P0 REFUTED** — institute already proved Q1-only; reuses the finding instead of re-running |
| WitnessProjection for ~Copyable in Action enums | `swift-institute/Experiments/witness-macro-noncopyable-feasibility/Sources/main.swift:384-420` | **Reusable pattern** for `Command.Resource.Protocol` value-binding (D8 option γ) |
| Property.View for ~Copyable mutation from `let` binding | `swift-primitives/swift-property-primitives/README.md` | **Alternative to KeyPath** for `Command.Resource.Protocol` access ergonomics |
| Parser.Protocol over `[String]` (P1) | `swift-institute/Experiments/argv-parser-protocol-spike/` (created 2026-05-15 in this session) | Already in place — P1 CONFIRMED |

#### Existing L1 primitives — reuse audit (CORRECTED v1.0.5)

| Proposed type | Existing primitive | Action |
|---|---|---|
| `Argument.Token` + `Argument.Token.Kind` | `Token` + `Token.Kind` in `swift-token-primitives` | **REUSE REFUTED v1.0.5** — verified at `swift-token-primitives/Sources/Token Primitives/Token.{swift,Kind.swift}`: `Token.Kind` is NOT generic; concrete cases (`leftBrace`, `keyword(Token.Keyword)`, `period`, …) for Swift-source-code lexing. Argv tokens have different kinds (long-flag, short-flag, value, separator, positional). `Argument.Token` defined fresh in `swift-argument-primitives` L1; MAY reuse `Text.Range` from `swift-text-primitives` for byte-range field. |
| `Argument.Position` | `Source.Position` + `Source.Range` + `Source.Location` in `swift-source-primitives` | **REUSE REFUTED v1.0.5** — verified at `swift-source-primitives/Sources/Source Primitives/Source.Position.swift:23-34`: `Source.Position` is file-qualified (`file: Source.File.ID` + `offset: Text.Position`). Argv has no file identity. `Argument.Position` defined fresh as small struct wrapping `(argvIndex: Int, byteOffset: Int)` or similar typed pair. |
| `Argument.Error` (case structure + diagnostic emission) | `Diagnostic.Record` + `Diagnostic.Severity` in `swift-diagnostic-primitives` | **REUSE PARTIAL v1.0.5** — verified at `Diagnostic.Record.swift:46`: `Record.location: Source.Location` ties the record to a file-qualified location which argv lacks. `Diagnostic.Severity` (the bare enum) IS reusable for error severity. `Diagnostic.Record` is NOT directly reusable; `Argument.Error` defines its own diagnostic-bearing case structure (with `Argument.Position` not `Source.Location`). |
| `Int.init?(String)`, `Bool.init?(String)`, numeric value conversion | `ASCII.Decimal.Parser` + `ASCII.Hexadecimal.Parser` in `swift-ascii-parser-primitives` | **REUSE CONFIRMED** — typed, allocation-free numeric parsing for argv value conversion. |
| `Argument.Name = Tagged<…, String>` | `Tagged<Tag, RawValue>` in `swift-tagged-primitives` | **REUSE CONFIRMED** — matches the typed-identifier-naming-framework pattern. |
| Property accessor for argument writeback (KeyPath alternative) | `Property<Tag, Base>` + `Property.View` / `Property.Inout` in `swift-property-primitives` | **REUSE CONFIRMED** — option for D8(β) builder pattern (deferred to ~Copyable Command.Resource.Protocol). |
| Schema-builder result-builder substrate | `Parser.\`Protocol\`` + `@Parser.Builder` in `swift-parser-primitives` | **REUSE CONFIRMED** — verified via P1 spike. |
| Help/Completion/Manpage emitter substrate | `Serializer.\`Protocol\`` + `@Serializer.Builder` in `swift-serializer-primitives` | **REUSE CONFIRMED** — verified via P2 spike. |

#### Existing L3 foundations with direct integration paths

| swift-arguments need | Existing foundation | Status |
|---|---|---|
| Console output (colored, ANSI, terminal-width) | `swift-console` (full terminal abstraction, NO_COLOR detection, capability checks) | **DEPEND** — swift-console handles ANSI escapes, color palette detection, terminal width. |
| Process exit codes, signal handling, argv access | `swift-process` (`Process.Spawn.Configuration`, `Process.Status`, `Process.Error`) | **DEPEND** — exit-code dispatch and signal handling integrate cleanly. |
| Env-var defaults, task-local overlays | `swift-environment` (`Environment.read`, `.write`, `.task.*` TaskLocal overlays, `.Snapshot`) | **DEPEND** — env-var fallback resolution. |
| Composable parser combinators | `swift-parsers` (re-exports `swift-parser-primitives` + `swift-parser-machine-primitives`) | **DEPEND** — argv tokenization. |
| Path argument conversion (cross-platform) | `swift-paths` | **DEPEND** — `--file path/to/x` argument types. |
| URL argument conversion (RFC-compliant) | `swift-uri` | **DEPEND** — `--url https://…` argument types. |
| JSON/YAML/TOML config-file fallback | `swift-json`, `swift-yaml`, `swift-toml`, `swift-config-{json,yaml,toml}` | **OPTIONAL trait-gated DEPEND** — config-file precedence (cmdline > config > env > defaults). |
| ASCII classification (tokenizer edge cases) | `swift-ascii` (Foundation-clean predicates) | **DEPEND** — quoted argv handling, escape sequences. |

#### Empirical `swift-command-line-interface` re-verification

Re-verified 2026-05-15: empty placeholder unchanged from §1.1 verification. No Package.swift, no Swift code, only CI scaffolding. v1.0.0 / v1.0.1 / v1.0.2 finding stands — package is dormant, not a hidden implementation.

### §3.11 Reuse inventory — proposed dependency graph (v1.0.3)

Concrete dependency graph for the four proposed packages, post-discovery:

#### swift-argument-primitives (L1) deps

```
swift-argument-primitives
├── swift-tagged-primitives         (Typed Name, EnvVar.Name, etc. — REUSE CONFIRMED)
├── swift-text-primitives           (Text.Range — used inside Argument.Token for byte-range field)
├── swift-diagnostic-primitives     (Diagnostic.Severity bare enum — PARTIAL REUSE)
├── swift-property-primitives       (Property<Tag, Base> for D8(β) — OPTIONAL, deferred)
├── swift-parser-primitives         (Parser.`Protocol` substrate for the schema combinators)
└── swift-ascii-parser-primitives   (ASCII.Decimal.Parser etc. for numeric-argument value conversion)

— NOT depended on (v1.0.3 over-optimistic reuse claims, REFUTED v1.0.5):
   swift-token-primitives           Token is Swift-source-code-specific (kinds: leftBrace/keyword/period); not generic; argv has different token shape
   swift-source-primitives          Source.Position is file-qualified (Source.File.ID + Text.Position); argv has no file identity
```

L1 vocabulary types (CORRECTED v1.0.5):

| Type | Composes / Reuse | Net L1 vocabulary cost |
|---|---|---|
| `Argument.Name`, `Argument.Name.Short`, `Argument.Name.Long` | `Tagged<…, String>` (REUSE) | Thin typealiases + validators |
| `Argument.Arity` | NEW | Enum, 5 cases |
| `Argument.Visibility` | NEW | Enum, 2 cases |
| `Argument.Help` | NEW | Struct, ~4 fields |
| `Argument.Environment.Variable.Name` | `Tagged<…, String>` (REUSE) | Typealias |
| `Argument.Token` | NEW — wraps `Argument.Token.Kind` + `Text.Range` (reuses Text.Range only) | Small struct |
| `Argument.Token.Kind` | NEW — argv-specific (long-flag, short-flag, value, separator, positional) | Enum, ~5-6 cases |
| `Argument.Position` | NEW — small struct `(argvIndex: Int, byteOffset: Int)` or `Tagged`-typed pair | Struct, 2 fields |
| `Argument.Error` | NEW — uses `Diagnostic.Severity` bare enum (PARTIAL REUSE); defines own case structure with `Argument.Position` (NOT `Source.Location`) | Enum + wrapper |
| `Argument.Positional<V>`, `Argument.Option<V>`, `Argument.Flag`, `Argument.Group<G>`, `Argument.Subcommand<S>` | `Parser.\`Protocol\`` (REUSE) — sidecar-metadata-carrying parsers | ~5 types |
| `Argument.Schema<Root>`, `Argument.Schema.Node`, `Argument.Schema.Visitor` | `Parser.Builder` result-builder (REUSE) | ~3 types |
| `Argument.Subcommand.Choice` | Result-builder home for subcommand declarations; semantically maps to `Parser.OneOf` (REUSE) | Builder type |

**Argument.Codable / Parseable / Serializable RELOCATED to L3** (v1.0.4 per [FAM-009]) — NOT at L1. Stdlib conformances live in `Argument Standard Library Integration` target at L3 swift-arguments.

**Net L1 scope (CORRECTED v1.0.5)**: ~17-20 net-new types after correct reuse. The v1.0.3 claim of "~12 net-new types" was over-optimistic — it assumed Token + Source.Position reuse that the source primitives don't structurally support. Still a meaningful reduction from v1.0.2's ~25 projection, but less dramatic. Argument.Token / Token.Kind / Position must be defined fresh.

#### swift-arguments (L3) deps

```
swift-arguments (v1.0.7 — 3-package v1)
├── swift-argument-primitives       (L1 vocabulary)
├── swift-ieee-1003                 (L2 POSIX 12.2 tokenization)
├── swift-parsers                   (composable parsers — re-export chain reaches argv)
├── swift-serializer-primitives     (Help Serializer; v2+ adds Completion/Manpage Serializers)
├── swift-console                   (terminal-aware output for help text, ANSI, color)
├── swift-process                   (exit codes, signal handling)
├── swift-environment               (env-var fallback — borderline v1; see §3.15)
└── swift-ascii                     (tokenizer character classification)

— DROPPED FROM v1 per §3.15 scope discipline:
   swift-gnu                        GNU long-option handling inline at L3
   swift-paths                      Path-arg conversion deferred to v2 (D12 / response-files arc)
   swift-uri                        URL-arg conversion deferred to v2
   swift-json / swift-yaml / swift-toml  Config-file fallback deferred to D13 / v2+
```

**Net L3 scope (v1.0.7)**: help-text layout + argv-tokenization (composing POSIX + inline GNU long-options) + KeyPath-based field writeback + sum-type subcommand dispatch + `@CLI` macro design (deferred to v2 even within v1's scope). The framework is forward-compatible for v2+ Completion/Manpage Serializers without re-architecting L1/L2 or Schema.

#### Genuinely greenfield work (post-reuse)

| Area | Estimated scope | Why greenfield |
|---|---|---|
| Argv-specific tokenizer | L2 (in swift-ieee-1003 + swift-gnu) | POSIX 12.2 + GNU long-options are specs, not existing primitives |
| Argument metadata types (Name / Arity / Visibility / Help / Schema) | L1 (in swift-argument-primitives) | Domain vocabulary; not provided by any existing primitive |
| Schema-builder result builder | L3 (in swift-arguments) | Composes existing Parser.Builder but adds Schema-specific Body type |
| Help-text layout algorithm | L3 (in swift-arguments) | Terminal-width-aware column wrapping; no existing institute primitive |
| Shell completion script generators (bash/zsh/fish/powershell) | L3 (in swift-arguments) | Each shell's syntax is distinct; no existing institute template lib |
| Manpage generation (troff/mdoc) | L3 (in swift-arguments) | troff/mdoc syntax; no existing institute primitive |
| `@CLI` macro design (deferred to v2) | L3 (in swift-arguments) | No direct institute precedent; observation macro is informative but different domain |
| KeyPath-based field writeback (Copyable Command default) | L3 (in swift-arguments) | Standard Swift KeyPath usage; no L1 primitive needed |
| `Command.Resource.Protocol` (~Copyable opt-in, deferred to D8 / U3 design arc) | L3 (in swift-arguments) | Uses WitnessProjection / Property.View / macro-init; design arc resolves |

The greenfield work is genuinely additive (institute alternative for what swift-argument-parser does), not redundant with anything existing.

### §3.12 Benchmark — institute spike vs swift-argument-parser (U8 v1.0.4)

Benchmark package at `swift-institute/Experiments/argv-parser-benchmark/` runs the canonical `Repeat` example through both stacks: Apple's `ParsableCommand` (Mirror + Decodable reflection) and the institute leaf-variant parser (compile-time-specialized `Parser.Protocol`). Argv: `["--count", "1000", "--include-counter", "hello"]`. 100k iterations per measurement; `ContinuousClock`; `swift build -c release` outputs.

| Axis | Apple swift-argument-parser | Institute spike | Ratio (inst / apple) |
|---|---:|---:|---:|
| Parse latency — mean | 61,292 ns/parse | 534 ns/parse | **0.009×** (~115× faster) |
| Parse latency — min | 55,750 ns/parse | 416 ns/parse | **0.007×** |
| Binary size (unstripped) | 1,517,976 B | 4,708,624 B | 3.10× |
| Binary size (stripped) | 735,704 B | 1,645,512 B | 2.24× |
| Cold compile (mean of 2 cold rebuilds) | ~19 s | ~26 s | 1.4× |

**Interpretation**:

- **Parse latency — institute decisive structural win**. The ~115× advantage reflects compile-time specialization vs reflection. Even if a future declarative API on top of `Parser.Protocol` (analogous to `@Option`/`@Flag`) adds ~3× overhead, the institute approach would still win ~40×. This is not optimizable in swift-argument-parser without abandoning its reflection-based architecture.
- **Binary size — Apple win, packaging artifact**. The 3.1× / 2.24× size cost comes from the leaf parser transitively pulling in ~150 swift-primitives modules even though it uses a small subset. This is a layering artifact of the fine-grained modularization, NOT a structural defect of `Parser.Protocol`. A properly consolidated L3 umbrella module (per [MOD-005] / [MOD-015] consumer-import precision) would close most of the gap. **Validates the L3 design discipline of minimizing transitive-module exposure in the consumer-facing umbrella.**
- **Compile time — minor Apple win**. Many small institute modules compile in parallel; wall-clock difference is modest (1.4×); CPU time delta is larger (~2.6×) but matters less for distribution-build pipelines.

**Caveats**:

1. Apples-to-oranges on feature surface — swift-argument-parser provides help-text rendering, error formatting, completion-script generation, manpage generation; the institute leaf parser provides only parsing. The L3 design absorbs the missing features.
2. The benchmark uses the **leaf-variant only** (Pattern A from the spike). The combinator variant (Pattern B) currently fails to build against the latest `Parser.Many` API surface and was excluded.
3. Apple's binary imports Foundation transitively; institute's does not — slight tailwind for institute on size.

**Verdict for U8**: institute design is **competitive on perf (decisive win), currently uncompetitive on packaging (but fixable)**. The 115× parse-latency advantage is too large to ignore; the binary-size deficit motivates careful L3 modularization rather than refuting the design.

### §3.13 GitHub organization placement (v1.0.5)

Per `swift-institute-ecosystem` [ECO-004], the institute's Standards layer is organized as a constellation of per-authority sub-orgs. The four proposed packages live at:

| Package | Layer | GitHub org | Repository |
|---|---|---|---|
| `swift-argument-primitives` | L1 | [swift-primitives](https://github.com/swift-primitives) | `swift-primitives/swift-argument-primitives` |
| `swift-ieee-1003` | L2 | [swift-ieee](https://github.com/swift-ieee) | `swift-ieee/swift-ieee-1003` (matches `swift-ietf/swift-rfc-4122`, `swift-iso/swift-iso-32000` per-authority precedent) |
| `swift-arguments` | L3 | [swift-foundations](https://github.com/swift-foundations) | `swift-foundations/swift-arguments` |

**v1 = 3 packages, not 4**: `swift-gnu` collapsed to inline-at-L3 per §3.15 v1 scope discipline (GNU long-options is a convention, not an IEEE-numbered standard, and the spec is small enough to live inside `swift-arguments` at L3). No new GitHub org needed for v1. If GNU specs accumulate to warrant their own org in future, that's a v2+ migration with its own dispatch.

**Cross-references**: [ECO-004], [PKG-NAME-001], [PKG-DEP-001].

### §3.14 `swift-token-primitives` `Token` generic refactor — recommendation (v1.0.6)

The current `swift-token-primitives.Token` is `public struct Token` (not generic) with `Token.Kind` bound to a Swift-source-code lexer enum (`leftBrace`, `rightBrace`, `keyword(Token.Keyword)`, `period`, `colon`, etc.). However:

| Signal | Interpretation |
|---|---|
| Package name `swift-token-primitives` (not `swift-swift-source-token-primitives`) | Generic framing |
| Doc comment: "Token is the atomic unit of lexical analysis... all major compiler implementations (swiftc, Clang, rust-analyzer, Roslyn) use this pattern" | Universal pattern |
| Structural shape `(Kind, Text.Range)` | Universal across lexical domains — Swift source, argv, CSV, regex, JSON, S-expressions, MIME, … all fit |
| Current implementation: `Kind` enum hardcoded to Swift-source-code cases | Specific implementation behind a generic framing |

The implementation-vs-framing gap is a structural opportunity, not a coincidence. The recommended ecosystem move:

**Proposed refactor**:

```swift
// swift-token-primitives/Sources/Token Primitives/Token.swift
public struct Token<Kind: Sendable & Hashable & Equatable>: Sendable, Equatable, Hashable
where Token<Kind>: Sendable {
    public let kind: Kind
    public let range: Text.Range
    @inlinable public init(kind: Kind, range: Text.Range) {
        self.kind = kind; self.range = range
    }
}
```

**Migration of the current Swift-source-code `Kind`**:

The existing `Token.Kind` (Swift-source-code cases) relocates either to:
- (α) A nested specialization: `Token.Swift.Kind` inside swift-token-primitives, with `typealias Swift.Token = Token<Token.Swift.Kind>`. Pro: backwards-source-compatible-with-typealias. Con: scope creep — swift-token-primitives hosts Swift-source-code-specific cases at its leaf.
- (β) A separate package: `swift-swift-token-primitives` (or similar — naming bikeshed) which owns the Swift-source-code Kind and a typealias `Swift.Token = Token<Swift.Token.Kind>`. Pro: clean separation; swift-token-primitives stays purely structural. Con: package proliferation; downstream consumers of current Swift `Token` need to import the new package.

Either is defensible; the structural refactor is the load-bearing move. The current Swift-source-code `Kind` is the immediate consumer and provides the migration test.

**Consumers after refactor**:

| Domain | Specialization |
|---|---|
| Swift source code | `Token<Swift.Token.Kind>` (relocated current `Kind`) |
| argv (this design) | `Token<Argument.Token.Kind>` |
| CSV (hypothetical) | `Token<CSV.Token.Kind>` |
| Regex (hypothetical) | `Token<Regex.Token.Kind>` |
| JSON tokens (hypothetical) | `Token<JSON.Token.Kind>` |

Each domain owns its own Kind enum (per [API-NAME-001] Nest.Name and [API-NAME-001b] subject-first); the universal `Token<Kind>` provides the structural atom.

**Impact on swift-arguments**:

- **Without the refactor (v1 ships)**: `Argument.Token` + `Argument.Token.Kind` are defined fresh in `swift-argument-primitives`. They duplicate the Token shape (Kind + Text.Range) at the structural level but are domain-distinct. No upstream dependency on the refactor.
- **With the refactor (v2 / post-refactor)**: `Argument.Token` becomes a `typealias` for `Token<Argument.Token.Kind>`. The argv-token-shape is one specialization among many.

**Recommendation**: file a separate Tier 2 research arc — `swift-institute/Research/2026-05-NN-swift-token-primitives-generic-refactor.md` — proposing the structural refactor with the (α) vs (β) decision and a migration plan for the current Swift-source-code consumer (likely just the parser-machine + lexer primitives). swift-arguments work proceeds without blocking on the refactor; v1 ships with `Argument.Token` fresh, with a typealias path documented for post-refactor.

**Cross-references**: [API-NAME-001], [API-NAME-001b], [PKG-NAME-001], [MOD-DOMAIN]; new direction D9.

### §3.15 v1 scope discipline (v1.0.7)

Per principal direction "we haven't needed this yet" + the institute discipline of [ECO-002] layer-placement, [PLAT-ARCH-021] domain-specific composition, and [MOD-RENT] three-criteria test, v1 of swift-arguments is **scope-reduced** to the genuine argument-parsing domain. Features beyond core argv-parsing + help-text emit are filed as direction items for v2+ work, NOT built into v1.

#### v1 scope (REQUIRED)

| Capability | Lives at |
|---|---|
| Parse argv → typed Command struct | L3 swift-arguments + L2 swift-ieee-1003 |
| Validate via typed throws | L3 swift-arguments (Command.Error) |
| Run command (single always-async per U3) | L3 swift-arguments (Command.\`Protocol\`) |
| Emit `--help` text on demand | L3 swift-arguments (Command.Help — one Serializer) |
| Subcommand dispatch via sum types | L3 swift-arguments (Argument.Subcommand.Choice + Parser.OneOf) |
| Value conversion (Int/Bool/String/etc.) | L3 swift-arguments (Argument.Codable + stdlib conformances) |
| POSIX 12.2 tokenization | L2 swift-ieee-1003 |
| GNU long-option tokenization | L3 swift-arguments inline (NOT its own L2 package) |
| KeyPath-based field writeback | L3 swift-arguments (Copyable Command default per P0) |

#### v1+ scope (DEFERRED to v2+; direction items)

| Capability | Direction | Future home |
|---|---|---|
| Shell completion script generation (Bash/Zsh/Fish/PowerShell) | **D10** | Separate L3 domain package `swift-shell-completion`, composes swift-arguments. Per-shell typed modeling MAY live at L2 (e.g., `swift-microsoft/swift-powershell-standard` for PowerShell, etc.) when [MOD-RENT] is satisfied per shell. PowerShell's spec-mirroring exception per [API-NAME-002] applies to the type name. |
| Manpage generation (troff/mdoc) | **D11** | Separate L3 package `swift-manpages`, composes swift-arguments. Or part of swift-shell-completion. |
| Response files (`@file.rsp`) | **D12** | v2+ L3 swift-arguments feature; argv pre-processing |
| Config-file fallback (JSON/YAML/TOML) | **D13** | v2+ trait-gated `* Foundation Integration` targets per [MOD-014] |
| Env-var defaults | borderline v1 | v1 IF straightforward; defer to v2 if it adds complexity |
| `@CLI` macro / property-wrapper sugar | already filed (D1 v1.0.0) | v2; v1 ships explicit DSL only |
| `~Copyable` Command.Resource.Protocol | already filed (D8 v1.0.3) | v2; v1 ships Copyable Command default per P0 REFUTED |
| `swift-token-primitives` `Token` generic refactor | already filed (D9 v1.0.6) | Separate Tier 2 research arc; swift-arguments v1 defines Argument.Token fresh |

#### Discipline rationale

1. **[ECO-002] layer-placement**: completion-script generation answers a different question than argument parsing. Two domains → two L3 packages. swift-arguments stays focused on its actual domain.

2. **[PLAT-ARCH-021] precedent**: when swift-kernel attempted to host RFC-typed socket Connect overloads in 2026-04, the user correction was that domain-specific composition (with domain-specific spec deps like swift-rfc-791) belongs in domain L3 packages (swift-sockets), not in the cross-platform unifier. By analogy: shell-completion belongs in `swift-shell-completion`, not in swift-arguments.

3. **[MOD-RENT] three criteria**: shell-completion-script generators don't have a second consumer in the ecosystem today; swift-arguments is the only known consumer. [MOD-RENT] would reject premature shell-specific package creation. Build when demand materializes.

4. **Institute precedent**: zero `swift-bash` / `swift-zsh` / `swift-fish` / `swift-powershell-*` packages exist today. The institute hasn't needed shell-specific anything. Building four shell-specific completion targets right now is greenfield work motivated by "argument-parser-parity-with-Apple" rather than by institute demand.

5. **Apple's swift-argument-parser pattern**: completion is opt-in (`mycli --generate-completion-script bash`). Consumers don't pay the cost unless they invoke it. We can mirror that pattern later in v2+ without blocking v1.

#### Forward-compatibility commitment

The v1.0.4 P2 verification confirmed that the Schema-as-data + visitor-via-Serializer.`Protocol` pattern works empirically. v1 ships ONE such Serializer (Help); v2+ adds Completion / Manpage Serializers without re-architecting L1/L2 or the Schema layer. The structural framework is forward-compatible by design — see §3.6 + §3.7 + §2.2.

**Cross-references**: [ECO-002], [PLAT-ARCH-021], [MOD-RENT]; direction items D10/D11/D12/D13.

---

## Part IV: Migration from swift-argument-parser

Existing institute consumers of swift-argument-parser (e.g., the planned `swift-dependency-analysis` tool per `developer-tool-package-architecture.md`) would migrate per:

| swift-argument-parser | swift-arguments |
|---|---|
| `@main struct Foo: ParsableCommand` | `struct Foo: Command.Protocol` + `@main enum Main` |
| `@Argument(help: "h") var x: T` | `Argument.Positional(\.x, help: .init(abstract: "h"))` in schema |
| `@Option(help: "h") var x: T` | `Argument.Option(\.x, help: .init(abstract: "h"))` in schema |
| `@Flag(help: "h") var x: Bool` | `Argument.Flag(\.x, help: .init(abstract: "h"))` in schema |
| `@OptionGroup var x: G` | `Argument.Group(\.x, schema: G.schema)` in schema |
| `subcommands: [A.self, B.self]` | `Argument.Subcommands { … }` over a sum-type enum |
| `mutating func run() throws` | `mutating func run() async throws(Command.Error)` (single always-async per U3) |
| `throw ValidationError("…")` | `throw Command.Error.validationFailed(reason: …)` |
| `ParsableCommand` (sync `run`) | `Command.Protocol` (single always-async; sync code in body) — per U3 resolution |
| `AsyncParsableCommand` | `Command.Protocol` (same single protocol) |
| `ExpressibleByArgument` | `Argument.Codable` (sibling protocol) |
| `EnumerableFlag` | `Argument.Flag` over a `CaseIterable` enum + name mapping |
| `CompletionKind` | `Argument.Completion.Kind` (file, directory, list, …) |
| `helpNames` | `Command.Configuration.helpNames` |
| `aliases` | `Command.Configuration.aliases` |

The shape difference is real but mechanical. Migration tooling (a `swift-argument-parser-to-swift-arguments` rewrite tool) could automate ~80% of the structural conversion; the remaining ~20% (typed-error case enumeration, sum-type subcommand definitions) requires human design choice.

**No automatic backwards-compatibility shim** is recommended. Per the institute's discipline of avoiding "backwards-compatibility hacks like renaming unused _vars, re-exporting types," migrations should be explicit, not shimmed.

---

## Part V: Empirical Validation — Cognitive Dimensions (per [RES-025])

| Dimension | Assessment |
|---|---|
| **Visibility** | High — schema is explicit (a static property), all options visible in one place. swift-argument-parser scatters wrappers across stored properties. |
| **Consistency** | High — `Argument.*` namespace mirrors `Parser.*` / `Serializer.*` / `Coder.*` shapes. Body+Builder DSL is the institute's established composition pattern. |
| **Viscosity** | Low for additions (add another schema line); medium for renames (Schema is a single property; rename touches one place). |
| **Role-expressiveness** | High — `Argument.Positional`, `Argument.Option`, `Argument.Flag` carry their roles in their names; `Command.Help`, `Command.Completion.Bash` describe their output. |
| **Error-proneness** | Lower than swift-argument-parser — typed throws catch errors at compile time; sum-type subcommands enforce exhaustive dispatch; no reflection-string-key magic. |
| **Abstraction** | Appropriate — three protocol-rooted abstractions (`Parser`, `Serializer`, `Coder`) reused at the right level; no parallel new framework. |
| **Hidden dependencies** | Lower — no `Mirror`, no `Decodable`, no `_SendableMetatype`. Dependencies are explicit at the package level. |
| **Progressive disclosure** | Medium — the explicit schema is more verbose than property wrappers. The `@CLI` v2 macro closes the gap once the DSL is proven. |

The verbosity-vs-explicitness trade is the only meaningful regression from swift-argument-parser ergonomics. Everything else is parity-or-improvement. The `@CLI` macro v2 closes this gap.

---

## Part VI: Open Questions (per [RES-027])

Items classified as **premise** (load-bearing for the recommendation, require experimental confirmation) or **direction** (research question, not load-bearing).

### Premise items

#### P0 (NEW, was U1) — `WritableKeyPath<C, V>` + `~Copyable` C — REFUTED

**Premise statement**: `WritableKeyPath<Command, Value>` can address fields of a `~Copyable` Command struct from the schema builder (`Argument.Positional(\.phrase, …)`).

**Status**: **CONFIRMED REFUTED [Verified: 2026-05-15]** by existing institute research at `swift-institute/Research/mutator-writable-keypath-interaction.md` + companion experiment `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/Sources/mutator-generic-dispatch-and-keypath/main.swift` (revalidated Swift 6.3.1, 2026-04-25). `WritableKeyPath<Root, Value>` carries an implicit `Root: Copyable & Escapable` constraint per stdlib's declaration. `@dynamicMemberLookup` bridging materializes Q1 only (both Self and Value Copyable). Direct-member access on ~Copyable Self bypasses the subscript entirely, creating asymmetric behavior.

**Design adjustment**: §3.5 API surface revised — `Command.Protocol` defaults to **Copyable** (matching swift-argument-parser's pragmatic shape). KeyPath-based field writeback works in this default case. Commands holding kernel resources (file descriptors, sockets, network connections) opt into `~Copyable` via a separate `Command.Resource.Protocol` whose value-binding uses one of three alternative mechanisms (macro-generated init, builder-finalizer, WitnessProjection per the institute pattern at `swift-institute/Experiments/witness-macro-noncopyable-feasibility/`) — the choice is deferred to direction D8 / U3 design arc.

**Why this is acceptable**: empirical observation — the vast majority of CLI commands hold no kernel resources (Repeat, Math, CountLines from swift-argument-parser's examples are all pure value types). The Copyable default covers the common case ergonomically; the ~Copyable opt-in covers the rare case structurally. swift-argument-parser uses Copyable+mutating throughout; the institute is no worse off.

#### P1 — `Parser.Protocol` over `[String]` produces argv parsing with acceptable ergonomics

**Premise statement**: The institute's `Parser.Protocol`, instantiated with `Parser.Input.Collection<Array<String>.Indexed<String>>`, can express argv parsing (positional + option + flag + subcommand) with ergonomics comparable to or better than swift-argument-parser.

**Risk if wrong**: the L3 design's parser layer is unimplementable; the design retreats either to a string-byte-based parser (which loses argv-element granularity) or to a custom non-Parser parser shape (which sacrifices the framework benefit).

**Verification**: experimental spike at `swift-institute/Experiments/argv-parser-protocol-spike/` — created 2026-05-15.

**Status**: **CONFIRMED [Verified: 2026-05-15]**. The spike compiles cleanly under `swift build`, and `swift test` passes 6/6 tests across two parser variants (a leaf `Parser.Protocol` conformance and a combinator-driven variant). Test inputs covered: `["hello"]`, `["--count", "3", "hello"]`, `["--include-counter", "hi"]`. The combinator-driven variant uses `Parser.OneOf.Sequence` (three branches over `Element == String`), `Parser.Take.Sequence` (for `--count <int>` pair), `Parser.Many.Simple` (for repetition), and `.map` (for token shaping) — all existing primitives, no new combinators. Backtracking via `Input.Slice`'s checkpoint/restore-based input works as required.

**Design hazards surfaced by the spike** (not refutations of P1, but findings that L3 must address):

1. **Swift.Array<String> → institute Array bridge required.** `Array.Indexed<Tag>` lives on `Array_Primitives_Core.Array` (the institute's `~Copyable`-capable Array), NOT on `Swift.Array`. `CommandLine.arguments` returns `Swift.Array<String>`, so consumers cannot use it directly with `Parser.Input.Collection<Array<String>.Indexed<String>>`. `swift-arguments` MUST provide a public bridge initializer (e.g., `Argument.Input(commandLine: [String])` — bare `Input` since the `Argument` namespace already supplies the discriminator per [API-NAME-002] namespace-implicit-prefix sub-rule + [API-NAME-013]) that copies elements into the institute Array. The bridge is non-trivial because the element type itself (`Swift.String`) is `Copyable`, so the copy is straightforward — but the discoverability of the type-namespace gap is a hazard.
2. **Module-resolution gotcha.** Even with `public import Array_Dynamic_Primitives`, the institute `Array` does not shadow `Swift.Array` in the consumer — `Array_Primitives_Core` had to be imported and depended on explicitly. Likely interaction between `InternalImportsByDefault` / `MemberImportVisibility` and re-export chains. The L3 `swift-arguments` package MUST surface the right exports to keep consumers from chasing module-resolution rabbit-holes.
3. **`Failure` types stack quickly.** Three-branch `Parser.OneOf` gives `Product<F0, F1, F2>`; with `Parser.Take.Sequence`'s `Either`/`Product` chains underneath, the top-level inferred `Failure` is non-trivial. The spike used `Parser.Many.Error` as the public-facing wrapper. A real L3 surface needs `.error.map(...)` at each layer to collapse to a single `Command.Error` enum the user catches. The Schema-builder DSL should hide this error-erasure ceremony from the user.
4. **`AnyString()` accepts any string including `"--foo"`.** Because `Parser.OneOf` tries branches in order, the spike's alternation works only because `MatchLiteral` branches are listed before `AnyString`. A production `Argument.Positional` MUST reject strings starting with `--` (or whatever the L2 tokenizer marks as flag-shaped) to surface unknown-flag errors instead of silently treating them as positional. This is a design constraint, not a primitive gap.
5. **`Parser.OneOf` requires `Input: Parser.Input.Protocol`** (backtracking-capable), which `Input.Slice` satisfies. A pure `Streaming` argv input would NOT support `OneOf` alternation. This validates that the L3 design must use a backtracking-capable input, not a one-shot streaming one — which is fine, since argv is finite and small.

None of these refute P1; they are concrete design points the L3 implementation must address. The Outcome section's "Next steps" already enumerates author-ship of `swift-arguments`; these 5 hazards become checklist items in that authorship.

#### P2 — Body-tree visitor-over-Schema generates help text correctly — **CONFIRMED v1.0.4**

**Premise statement**: A visitor protocol that walks the Schema (built from `Argument.*` sidecar-metadata-carrying types) can produce well-formatted help text for arbitrary commands without coupling the visitor to non-Argument `Parser.*` combinators.

**Verification**: extended the P1 spike at `swift-institute/Experiments/argv-parser-protocol-spike/` with `HelpVisitor`, `BashCompletionVisitor`, and a schema-driven parser. 10/10 tests passing (6 original P1 + 4 new P2). HelpVisitor emits byte-exact help text; BashCompletionVisitor emits a well-formed bash function with `compgen -W` and `complete -F`.

**Status**: **CONFIRMED [Verified: 2026-05-15]**. Visitor pattern works end-to-end with static dispatch (no reflection, no string-tag dispatch). Bidirectionality empirically confirmed — same `Argument.Schema` instance drives parse + help + completion.

**Load-bearing constraint surfaced**: the visitor walks `Argument.*` schema combinators ONLY, NOT arbitrary `Parser.*` combinators. `Command.Body` MUST be constrained to `some Argument.Schema.Node` (or a result-builder producing one). A generic `some Parser.Protocol` Body forfeits metadata round-trippability. This is a design constraint, not a refutation — §2.2's sidecar-metadata approach already implied it; v1.0.4 makes it explicit.

**Secondary findings**:
- Schema list requires `[any Argument.Schema.Node]` existential (each `Positional<V>` / `Option<V>` has distinct `V`). Double-dispatch via `Node.accept(_:)` recovers the static value type at the visit-site; existential is structural, not a typing loss.
- `V: Sendable & Equatable` is load-bearing for schema types to stay `Sendable & Equatable`. Real value types satisfy this; the deferred `~Copyable` opt-in (D8) needs a parallel protocol.
- `String(describing:)` default-value rendering covers `Int`/`String`; complex types need `helpDefault: String`.
- Positional-value completion (filenames, hostnames, enums) is out of v1 scope — needs a `CompletionSource` per positional.

### Direction items

#### D1 — Should `@CLI` ship in v1 or v2?

The Body+Builder DSL is sufficient for v1. The macro is a UX nicety. v1 should ship without; v2 adds the macro after the DSL surface is proven.

#### D2 — Response files (`@file.rsp`) and env-var substitution

System.CommandLine supports response files; clap has opt-in support. The institute may want this for parity with .NET tooling consumers. Defer to v2; not part of v1 scope.

#### D3 — Tab-completion runtime support (not just emission)

Generating completion *scripts* is straightforward (Serializer per shell). Runtime completion (the `program complete --shell bash partial-input` direction) is a separate parser invocation over a partial argv. Worth a separate research arc.

#### D4 — Resolving the family-codable-convention research first

The deferred `family-codable-convention` research (per the framing memo, principal direction 2026-05-14) formalizes when format-specific sibling protocols are appropriate. The `Argument.Codable` sibling proposed in §3.3 is a worked example. Either resolve that research first, or use this argument-parser design as the second worked example (after JSON.Serializable / ASCII.Serializable) to drive the convention's formalization.

#### D5 — Should the `swift-foundations/swift-command-line-interface` placeholder be retired?

Three options: (a) retire and remove, (b) leave dormant for a future broader CLI-app framework, (c) absorb into `swift-arguments`. **Recommendation**: option (b) — leave dormant. A future package composing `swift-arguments` + `swift-console` + `swift-process` + signal handling + terminal-mode-control would legitimately want the broader name.

#### D6 — Async vs sync run methods — **RESOLVED v1.0.4**

**Status**: RESOLVED. See `swift-institute/Research/2026-05-15-command-protocol-sync-async-design.md` (Tier 2 RECOMMENDATION, v1.0.0, 2026-05-15). Resolution: **single always-async protocol** (`Command.Protocol` with `mutating func run() async throws(Command.Error)`). `Command.Async.Protocol` and `Command.Async` namespace are NOT introduced — institute precedent (Parser.\`Protocol\`, Serializer.Protocol, Coder.Protocol) is unanimously single-shape; swift-argument-parser's split was Swift-5.5/5.6-availability-driven, not structural; all 3 existing institute CLIs already use AsyncParsableCommand. Sync command bodies omit `await`; the async-runtime overhead is acceptable institute-wide.

#### D8 (NEW) — `~Copyable` Command via `Command.Resource.Protocol`

Surfaced by P0 REFUTED. Commands holding kernel resources need `~Copyable` + `consuming func run()` + a non-KeyPath value-binding mechanism. Three candidate mechanisms surfaced by the prior-art search:

| Mechanism | Pros | Cons | Institute precedent |
|---|---|---|---|
| (α) Macro-generated `init(fromParsed:)` | Most ergonomic; auto-derived from declared `@CLI*` properties | Macro complexity; SwiftSyntax dep; no direct precedent | None |
| (β) Builder-finalizer pattern | Explicit; no macro; clear ownership | Verbose at definition site | Implicit in Body+Builder DSL |
| (γ) WitnessProjection — ~Copyable projects to Copyable summary, parse into summary, materialize ~Copyable at finalize | Already proven in institute experiments | Two-stage assembly; novel for CLI domain | `swift-institute/Experiments/witness-macro-noncopyable-feasibility/` |

Recommendation: defer to U3 design arc as part of the sync/async investigation. v1 ships Copyable Command only; ~Copyable Command lands when the design arc resolves.

#### D10 (NEW v1.0.7) — Shell completion script generation

Deferred from v1 per §3.15 v1 scope discipline. Future L3 domain package `swift-shell-completion` composes swift-arguments and emits Bash / Zsh / Fish / PowerShell completion scripts. Each shell is its own emission target with its own Visitor implementation, following the §3.6 forward-compatible framework. Per-shell L2 packages MAY be warranted (e.g., `swift-microsoft/swift-powershell-standard` for PowerShell's authority-published spec) when [MOD-RENT] criteria are satisfied per shell; v1 does not pre-build any.

#### D11 (NEW v1.0.7) — Manpage generation (troff/mdoc)

Deferred from v1 per §3.15. Future L3 package `swift-manpages` (or part of `swift-shell-completion`) composes swift-arguments to emit Unix manpage source format from the schema. Follows the §3.6 pattern (one Serializer over Command.Schema).

#### D12 (NEW v1.0.7) — Response files (`@file.rsp`)

Deferred from v1 per §3.15. Argv pre-processing feature parallel to swift-argument-parser's response-file support. Lives in swift-arguments at L3 when added; argv-tokenizer expansion step.

#### D13 (NEW v1.0.7) — Config-file integration (JSON/YAML/TOML fallback)

Deferred from v1 per §3.15. Trait-gated `* Foundation Integration` targets per [MOD-014]; consumers opt in via `traits: ["JSON"]` or similar. Composes swift-json / swift-yaml / swift-toml at L3.

#### D9 (NEW v1.0.6) — `swift-token-primitives` `Token` generic refactor

Surfaced by the v1.0.5 reuse-audit dispatch and crystallized by the principal in v1.0.6: the current `Token` is Swift-source-code-specific despite framing as universal. Recommendation: separate Tier 2 research arc proposing `Token<Kind>` generic refactor, with the current Swift-source-code `Kind` relocating to either a nested specialization (α: `Token.Swift.Kind`) or a separate package (β: `swift-swift-token-primitives`). Filed as Direction; swift-arguments work proceeds with `Argument.Token` fresh and a typealias path documented for post-refactor.

See §3.14 for the full recommendation. Companion-research arc TBD.

#### D7 — `Argument.Codable` family-protocol placement (L1 vs L3) — **RESOLVED v1.0.4**

**Status**: RESOLVED. See `swift-institute/Research/2026-05-15-family-codable-convention.md` (Tier 2 RECOMMENDATION, v1.0.0, 2026-05-15). Resolution: **L3 `swift-arguments`, not L1**, codified as [FAM-009] hybrid placement rule — sibling format-Codable protocols live at the same layer as their namespace root UNLESS substrate-friction gates apply at that layer, in which case they promote one tier. `Argument.Codable` bridges Self ↔ Swift.String → hits [PRIM-FOUND-004] L1 friction gate → promotes to L3. Zero contradictions with shipped placements (JSON.Serializable L3, ASCII.Parseable L1, Binary.Parseable L1). §3.9 + §3.11 updated.

---

## Outcome

**Status**: RECOMMENDATION.

**Recommended ecosystem shape — 3 packages (v1.0.7 reduction)**:

| Package | Layer | Case | Role |
|---|---|---|---|
| `swift-argument-primitives` | L1 | (b) domain-owned | CLI argument vocabulary (Name, Arity, Visibility, Help, Token, Position, Error) |
| `swift-ieee-1003` | L2 | (d) standards-internal | POSIX 12.2 utility-syntax tokenizer (IEEE-numbered authority-published spec) |
| `swift-arguments` | L3 | composition | `Command.\`Protocol\`` + `Command.Schema` + `Command.Help` (one Serializer) + GNU long-option handling inline + `Argument.Codable` sibling protocols + stdlib conformances |

~~`swift-gnu`~~ — collapsed to L3 inline per §3.15 v1 scope discipline (GNU long-options is a convention, not an IEEE-numbered spec; small enough to live inside swift-arguments). Future GNU specs (Info format, autotools, gettext PO) would warrant a `swift-gnu` org + L2 package; v1 does not need it.

~~`Command.Completion.{Bash,Zsh,Fish,PowerShell}`, `Command.Manpage`~~ — deferred to v2+ per §3.15; future L3 domain packages `swift-shell-completion` and `swift-manpages` compose swift-arguments via the §3.6 forward-compatible framework. Filed as D10 / D11.

**Architectural decisions**:

1. **Schema-as-data**, not schema-as-reflection. The schema is a `Command.Schema<Root>` value built via `@Command.Builder`. (§§2.2, 3.5)
2. **`Coder.Protocol` is not extended**. The CLI domain's one-parser-many-emitters shape is structurally different from `Coder`'s single-Buffer leaf shape. (§3.7)
3. **Help / completion / manpage emit are separate `Serializer.Protocol` instances** over the same Schema, each with its own Buffer. (§3.6)
4. **Subcommands are sum types**, dispatched via `Parser.OneOf` (already in primitives). (§2.3)
5. **POSIX 12.2 and GNU long options get separate L2 packages**; `swift-arguments` composes a default `Argument.Tokenizer.Default`. (§3.4)
6. **Typed throws end-to-end**, per `[API-ERR-001]`. (§§3.1, IV)
7. **Single always-async `Command.Protocol`** — `mutating func run() async throws(Command.Error)`. NO `Command.Async.Protocol`. (Resolved v1.0.4 per U3 / `swift-institute/Research/2026-05-15-command-protocol-sync-async-design.md`.) `~Copyable` `consuming` opt-in deferred to `Command.Resource.Protocol` per D8.
8. **`@CLI` macro deferred to v2**. v1 ships the explicit DSL only. (§3.5)
9. **`swift-foundations/swift-command-line-interface` placeholder left dormant**, not absorbed. (§D5)
10. **`Argument.Codable` lives at L3 `swift-arguments`**, not L1 — per [FAM-009] hybrid placement rule. (Resolved v1.0.4 per U10 / `swift-institute/Research/2026-05-15-family-codable-convention.md`.) Stdlib conformances move to a sibling `Argument Standard Library Integration` target at L3.
11. **Reuse before greenfield**: ~70% of L1 vocabulary comes from existing primitives (Token, Source.Position, Diagnostic, Property, Tagged, Terminal, ASCII.Decimal.Parser); at L3 swift-console + swift-process + swift-environment + swift-parsers + swift-paths + swift-uri compose cleanly. L1 vocabulary scope reduced from ~25 to ~12 net-new types. (§3.10 / §3.11)
12. **Empirical perf validation**: ~115× parse-latency advantage over swift-argument-parser (compile-time-specialized vs reflection-based). 3.1× / 2.24× binary-size deficit is a packaging artifact, addressable via consolidated L3 umbrella per [MOD-005]. (§3.12)

**Next steps**:

1. **Principal review** of this RECOMMENDATION → DECISION.
2. **P1 premise CONFIRMED** by the spike at `swift-institute/Experiments/argv-parser-protocol-spike/`. Design is implementable. 5 hazards must be addressed in L3 authorship (see §VI P1).
3. **P2 premise CONFIRMED v1.0.4** by extended spike (10/10 tests). HelpVisitor + BashCompletionVisitor empirically work; bidirectionality verified. (§VI P2)
4. **D6 (sync/async) RESOLVED v1.0.4** — single always-async per U3 research doc.
5. **D7 (Argument.Codable placement) RESOLVED v1.0.4** — L3 per U10 family-codable-convention research doc + [FAM-009].
6. Remaining direction items: D1 (response files), D2 (env-var substitution), D3 (runtime tab-completion), D4 (family-codable convention — RESOLVED via U10), D5 (swift-command-line-interface dormancy), D8 (~Copyable Command.Resource.Protocol — three candidate mechanisms enumerated, design arc pending).
7. Author `swift-argument-primitives` (L1) — minimal vocabulary types per §3.11 reuse inventory.
8. Author `swift-ieee-1003` (L2) and `swift-gnu` (L2) — tokenizers as Parser.Protocol instances.
9. Author `swift-arguments` (L3) — `Command.Protocol` + Schema + Help/Completion/Manpage Serializers + `Argument.Codable` + stdlib integration target.
10. Validate parity against the swift-argument-parser test suite (port `Repeat`, `Math`, `CountLines` examples). Performance benchmark per §3.12 methodology.
11. Author a migration guide and (optionally) automated rewriter from `swift-argument-parser` consumers.

---

## References

### Primary sources — institute

- `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90` — `Parser.Protocol`
- `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Builder.swift:18` — result builder
- `swift-parser-primitives/Sources/Parser Primitives Core/Parseable.swift:19-25` — Parseable
- `swift-serializer-primitives/Sources/Serializer Primitives Core/Serializer.Protocol.swift:49-82` — Serializer.Protocol
- `swift-serializer-primitives/Sources/Serializer Primitives Core/Serializable.swift:19-25` — Serializable
- `swift-coder-primitives/Sources/Coder Primitives/Coder.Protocol.swift:32` — Coder.Protocol
- `swift-coder-primitives/Sources/Coder Primitives/Codable.swift:29-35` — Codable
- `swift-binary-coder-primitives/Sources/Binary Coder Primitives/Binary.Coder.swift:43` — Binary.Coder witness
- `swift-parser-machine-primitives/Sources/Parser Machine Primitives/Parser.Machine.swift:43` — Machine.Parser
- `swift-foundations/swift-command-line-interface/` — empty placeholder verified 2026-05-15
- Framing memory: `project_parser_serializer_coder_system_framing.md` (three-primitive codec system)

### Primary sources — external

- swift-argument-parser: [github.com/apple/swift-argument-parser](https://github.com/apple/swift-argument-parser)
  - `Sources/ArgumentParser/Parsable Types/ParsableCommand.swift:13`
  - `Sources/ArgumentParser/Parsable Types/ParsableArguments.swift:16,99-103,297`
  - `Sources/ArgumentParser/Parsable Types/CommandConfiguration.swift:13`
  - `Sources/ArgumentParser/Parsable Properties/{Argument,Option,Flag,OptionGroup}.swift`
  - `Sources/ArgumentParser/Parsing/{ArgumentSet,CommandParser,ArgumentDecoder,ParserError,Parsed}.swift`
  - `Sources/ArgumentParser/Usage/HelpGenerator.swift:12-100`
  - `Sources/ArgumentParser/Completions/{Bash,Zsh,Fish}CompletionsGenerator.swift`
  - `Examples/repeat/Repeat.swift:14-36`
  - `Examples/math/Math.swift:14-76`
- optparse-applicative: [hackage.haskell.org/package/optparse-applicative](https://hackage.haskell.org/package/optparse-applicative)
  - Maintainer design notes: [huwcampbell.com/posts/2017-02-28-maintaining-optparse-applicative.html](https://huwcampbell.com/posts/2017-02-28-maintaining-optparse-applicative.html)
- clap (Rust): [github.com/clap-rs/clap](https://github.com/clap-rs/clap), [docs.rs/clap](https://docs.rs/clap/latest/clap/), [derive ref](https://docs.rs/clap/latest/clap/_derive/index.html)
- System.CommandLine (.NET): [github.com/dotnet/command-line-api](https://github.com/dotnet/command-line-api), [Beta 2 retrospective](https://github.com/dotnet/command-line-api/issues/1537), [Beta 4 retrospective](https://github.com/dotnet/command-line-api/issues/1750), [learn.microsoft.com syntax](https://learn.microsoft.com/en-us/dotnet/standard/commandline/syntax)
- Click (Python): [click.palletsprojects.com](https://click.palletsprojects.com/)
- argparse (Python): [docs.python.org/3/library/argparse.html](https://docs.python.org/3/library/argparse.html)
- spf13/cobra (Go): [github.com/spf13/cobra](https://github.com/spf13/cobra), [pkg.go.dev/github.com/spf13/cobra#Command](https://pkg.go.dev/github.com/spf13/cobra#Command)
- urfave/cli (Go): [github.com/urfave/cli](https://github.com/urfave/cli)
- POSIX 12.2: IEEE Std 1003.1-2017 Chapter 12 Utility Syntax Guidelines, [pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
- GNU coding standards §4.8: [www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces](https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces)

### Institute prior-art context

- `developer-tool-package-architecture.md` (Tier 3 DECISION) — tools live outside the five-layer stack; `swift-dependency-analysis` is the first case-study consumer of `swift-argument-parser` (~~migrate to swift-arguments post-implementation~~).
- `2026-05-12-typed-identifier-naming-framework.md` (Tier 2 RECOMMENDATION) — naming framework: most-generic English noun for the domain entity, no abbreviations. Justifies `swift-arguments` over `swift-argument-parser-alternative`.
- `2026-05-13-swift-uuids-l3-design.md` (Tier 3 RECOMMENDATION) — precedent for L3 unifier composing L2 spec packages; same shape as proposed `swift-arguments` composing POSIX + GNU L2 standards.
- `2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md` (Tier 3 RECOMMENDATION) — Phase 2 protocol relaxation landed; Parser.Protocol is `~Copyable`. Confirms institute design discipline for argument-parser to follow.
- `safe-attribute-absorber-pattern-fundamentals.md` (Tier 2 DECISION) — @safe pairing with @unchecked Sendable; argument-parser types should follow per [MEM-SAFE-025c].
- `mutator-writable-keypath-interaction.md` + experiment `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/` — empirical refutation of WritableKeyPath + ~Copyable Root (Q1-only); load-bearing for P0 status and §3.5 Copyable Command.Protocol default.
- **`2026-05-15-command-protocol-sync-async-design.md`** (Tier 2 RECOMMENDATION, v1.0.0, companion v1.0.4) — closes D6; single always-async `Command.Protocol`.
- **`2026-05-15-family-codable-convention.md`** (Tier 2 RECOMMENDATION, v1.0.0, companion v1.0.4) — codifies [FAM-009] hybrid placement rule; closes D7; relocates `Argument.Codable` to L3.

### Experiments

- `swift-institute/Experiments/argv-parser-protocol-spike/` — P1 verification (6/6 baseline tests) + P2 verification extension (10/10 tests with HelpVisitor + BashCompletionVisitor; bidirectionality empirically confirmed v1.0.4).
- `swift-institute/Experiments/argv-parser-benchmark/` — U8 benchmark vs Apple's swift-argument-parser (parse latency / binary size / compile time); created 2026-05-15. Validates the ~115× parse-latency advantage of compile-time-specialized Parser.Protocol over reflection-based ParsableCommand.
- `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/` — pre-existing experiment; revalidated 2026-05-15 to confirm WritableKeyPath + ~Copyable remains REFUTED on Swift 6.3.1.

### Compliance checklist

- [RES-019] Internal grep — completed; no prior `swift-argument-*` or argument-parser-related research exists in institute corpus. v1.0.3 extension grep located mutator-writable-keypath-interaction.md + witness-macro-noncopyable-feasibility as direct prior art for P0 / D8.
- [RES-021] Prior art survey — 6 systems surveyed with [RES-021] contextualization step.
- [RES-022] Theoretical grounding — free Applicative + free Alternative encoding contextualized in Swift type system.
- [RES-023] Empirical-claim verification at write time — every cited file:line verified via parallel subagents and re-cited in this doc; `swift-command-line-interface` empty status verified. v1.0.4: U6+U7+U8 verifications all backed by extant experiments with passing tests.
- [RES-026] Citations — all primary sources cited with permalinks or file:line.
- [RES-027] Loose-end follow-up — P1 + P2 both backed by extant spike with passing tests; D6 + D7 both resolved via companion research docs (Tier 2). D8 (~Copyable Command.Resource.Protocol) directionally classified for follow-on design arc.
- [RES-018] Premature-primitive check — all 4 proposed packages classified explicitly (§3.1); no (a) cross-cutting primitive proposed; (b)/(c)/(d) cases each justified.
- [RES-029] Binding/placement question — `swift-arguments` vs `swift-command-line-interface` decided on semantic identity first (§3.2); cost was tiebreaker only. `Argument.Codable` L1 vs L3 decided on semantic identity (substrate-friction) first per U10 [FAM-009].
- [RES-030] Explicit class enumeration — [RES-018] cases enumerated verbatim in §3.1.
