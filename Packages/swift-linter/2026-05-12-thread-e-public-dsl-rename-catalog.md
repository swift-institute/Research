# Thread E Phase 2 — Public-DSL rename catalog (swift-linter + swift-linter-primitives)

> **Status**: AWAITING PRINCIPAL DISPOSITION. Phase 3 execution does
> NOT begin until each row below is dispositioned. Do NOT apply
> renames inline.

## Scope and lens

Per `HANDOFF-thread-e-compound-identifier-sweep.md`, Phase 2 catalogs
every compound identifier and compound type name on the **public DSL**
surface of swift-linter and swift-linter-primitives — the
consumer-observable engine + L1 primitives surface. Pack-internal
helpers and CLI-internal helpers are out of scope (closed in Phase 1
or surfaced as scope ambiguities below).

The maximal-reuse lens per `project_linter_maximal_ecosystem_reuse.md`
asks every row: does an existing ecosystem typed primitive cover the
role this raw type plays at the site? If yes, the rename may collapse
to a typed-primitive adoption (Shape B); if no, the rename is
structural (Shape A).

Post-Phase-1 dogfeed baseline:

| Pack | compound identifier | compound type name | Total |
|------|---:|---:|---:|
| swift-linter-primitives | 6 (all public) | 0 | 6 |
| swift-linter | 15 public + 33 internal | 3 public + 5 internal | 56 |
| **Total in catalog** | **21** | **3** | **24** |

Plus 1 carry-forward from Phase 1 escalation
(`Lint.Rule.Bundle.brandOwner` on swift-primitives-linter-rules,
public DSL but rule-pack-owned — out of HANDOFF Phase 2 declared
scope but listed at end for principal awareness).

## Scope ambiguities surfaced (class-(c) per [SUPER-005])

The HANDOFF Phase 2 scope is "swift-linter + swift-linter-primitives
public DSL." Two scope ambiguities surfaced during enumeration:

1. **33 swift-linter compound-identifier findings at `internal`
   visibility**. The HANDOFF's Phase 1 mechanical scope was rule-packs
   (`swift-linter-rules`, `swift-institute-linter-rules`,
   `swift-primitives-linter-rules`) — swift-linter itself was NOT
   listed for Phase 1. Phase 2 explicitly scoped to public DSL. The
   33 internal findings on swift-linter are neither bucket. Treatment
   options: (a) extend Phase 1 to swift-linter internals (apply the
   same `internal → fileprivate` visibility-shift pattern that closed
   30 of 41 institute-linter-rules findings); (b) catalog them as
   Phase 2 review-only items; (c) defer to a separate Thread F+
   dispatch. Recommended: extend Phase 1 mechanical
   (visibility-shift) once principal authorizes — this is a low-risk
   30-second-per-file change with no public API impact. NOT included
   below pending disposition.

2. **`Lint.Rule.Bundle.brandOwner` at public visibility on
   swift-primitives-linter-rules**. Phase 1's HANDOFF explicitly
   scoped to "pack-internal compound identifiers ... no public API
   impact" — `brandOwner` is `public static let`. It belongs in
   Phase 2 by shape (public DSL compound identifier) but Phase 2's
   declared scope was swift-linter + swift-linter-primitives, not
   rule-packs. Treatment: surface as cross-pack supplemental row at
   end of catalog; principal may include or DEFER.

---

## swift-linter-primitives (6 rows)

### Row 1 — `Lint.Configuration.disabledRuleIDs` at `Sources/Linter Primitives/Lint.Configuration.swift:76`

**Current shape**: `public let disabledRuleIDs: [Lint.Rule.ID]`
**Compound rule**: [API-NAME-002] (compound identifier — "disabled" + "Rule" + "IDs")

**Proposed shape A (rename only)**: `public let disabled: [Lint.Rule.ID]`
— drops "RuleIDs" suffix; the typed `[Lint.Rule.ID]` already says
"rule IDs" at the type level (namespace-implicit-prefix sub-rule).

**Proposed shape B (rename + collection change)**: `public let disabled: Set<Lint.Rule.ID>`
— same rename as A AND changes `[Lint.Rule.ID]` → `Set<Lint.Rule.ID>`.
The companion `effectiveDisabledRuleIDs()` already returns
`Set<Lint.Rule.ID>` for O(1) lookup; making the stored property a Set
eliminates the per-call array→set conversion and aligns storage with
query.

**Recommendation**: **Shape B**. The maximal-reuse lens cited
`Set<Lint.Rule.ID>` as the canonical example in the HANDOFF; the
existing `effectiveDisabledRuleIDs()` Set return confirms Set is the
right shape for the lookup semantic. Adopting Set at the storage layer
is the coherent typed-primitive step.

**Cascade scope**: `init(disabledRuleIDs:)` argument label, public
read-access at consumer sites. Run `grep -rln "disabledRuleIDs" $(workspace)/`
for full enumeration; preliminary scope is swift-linter + the four
rule packs + Tests; no external-org-mirror consumers identified.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 2 — `Lint.Configuration.effectiveRules()` at `Sources/Linter Primitives/Lint.Configuration.swift:125`

**Current shape**: `public func effectiveRules() -> [Lint.Rule.Configuration]`
**Compound rule**: [API-NAME-002] (compound — "effective" + "Rules")

**Proposed shape A (rename only)**: `public func resolved() -> [Lint.Rule.Configuration]`
— single-word leaf; semantically captures "rules after parent-chain
walk and disabled-filter applied." Conflicts: none (no other
`resolved` on `Lint.Configuration`).

**Proposed shape B (nested accessor)**: `public var effective: Effective`
where `Effective` exposes `.rules` and `.disabled` — Property.View
multi-form per [API-NAME-008]. Call sites become
`config.effective.rules` / `config.effective.disabled`. Pairs with
Row 3 (same multi-form).

**Recommendation**: **Shape B** — `effective.rules` + `effective.disabled`
together form a coherent two-method namespace per [API-NAME-008]
multi-form criterion. Single-method namespaces are anti-pattern per
[API-NAME-001a]; the multi-form here is genuine.

**Cascade scope**: `effectiveRules()` callers in swift-linter
(`Lint.Driver`, `Lint.Run`) — grep first. Tests update too.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 3 — `Lint.Configuration.effectiveDisabledRuleIDs()` at `Sources/Linter Primitives/Lint.Configuration.swift:149`

**Current shape**: `public func effectiveDisabledRuleIDs() -> Set<Lint.Rule.ID>`
**Compound rule**: [API-NAME-002] (compound — "effective" + "Disabled" + "RuleIDs")

**Proposed shape A (rename only)**: `public func resolvedDisabled() -> Set<Lint.Rule.ID>`
— still compound. Or `public func disabled() -> Set<Lint.Rule.ID>` —
collides with the proposed Row 1 stored property `disabled`.

**Proposed shape B (nested accessor)**: `config.effective.disabled` —
paired with `effective.rules` from Row 2. Returns `Set<Lint.Rule.ID>`.
Single-word leaf `disabled` on the `Effective` view type.

**Recommendation**: **Shape B** — same rationale as Row 2. The
`effective` accessor returns a view type whose `.rules` and
`.disabled` are the two resolved-set accessors.

**Cascade scope**: same as Row 2 (`effectiveDisabledRuleIDs()` is
called only by `effectiveRules()`; both move together).

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 4 — `Lint.Rule.withDefaultSeverity(_:)` at `Sources/Linter Primitives/Lint.Rule.Composition.swift:45`

**Current shape**: `public func withDefaultSeverity(_ severity: Diagnostic.Severity) -> Lint.Rule`
**Compound rule**: [API-NAME-002] (compound — "with" + "Default" + "Severity")

**Proposed shape A (rename only)**: `public func with(defaultSeverity severity: Diagnostic.Severity) -> Lint.Rule`
— labeled method per [API-NAME-008] single-form. `defaultSeverity`
argument label is still compound; could be `with(default:)` if the
context is clear.

**Proposed shape B (Property.View)**: not applicable — single-form
operation per [API-NAME-008]; multi-form would require sibling
combinators (e.g., `with.findings`, `with.id`) which don't currently
exist on `Lint.Rule.Composition`.

**Recommendation**: **Shape A** with argument label `with(default:)`
— "default" is the relevant qualifier; the parameter type
`Diagnostic.Severity` says the rest. Reads as
`rule.with(default: .error)`. Note: the `with*` prefix on the
*method name* is stdlib idiom for scoped-resource patterns
(`withUnsafePointer`); here we keep the `with` prefix because Swift
labeled-method idiom permits it at the *argument* label position
(per [API-IMPL-013] secondary-closure-label conventions, the same
applies to value-shaped parameters).

**Cascade scope**: combinator method — consumers chain it. Run `grep
-rln "withDefaultSeverity"` for enumeration.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 5 — `Lint.Rule.pinnedToSeverity(_:)` at `Sources/Linter Primitives/Lint.Rule.Composition.swift:58`

**Current shape**: `public func pinnedToSeverity(_ severity: Diagnostic.Severity) -> Lint.Rule`
**Compound rule**: [API-NAME-002] (compound — "pinned" + "To" + "Severity")

**Proposed shape A (rename only)**: `public func pinned(to severity: Diagnostic.Severity) -> Lint.Rule`
— labeled-method single-form per [API-NAME-008]. Reads as
`rule.pinned(to: .error)`. `pinned` is a single-word verb past
participle; `to:` is the canonical destination preposition argument
label.

**Proposed shape B**: not applicable.

**Recommendation**: **Shape A**. Pair with Row 4's argument-label
shape for sibling-shape consistency on `Lint.Rule.Composition`.

**Cascade scope**: combinator method — `grep -rln "pinnedToSeverity"`.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 6 — `Lint.Rule.defaultSeverity` at `Sources/Linter Primitives/Lint.Rule.swift:63`

**Current shape**: `public let defaultSeverity: Diagnostic.Severity`
**Compound rule**: [API-NAME-002] (compound — "default" + "Severity")

**Proposed shape A (rename only)**: `public let severity: Diagnostic.Severity`
— drops "default" prefix; the property's role is "this rule's
default severity." Risk: ambiguity — engine resolves severity at
runtime via `configuration.severity ?? rule.defaultSeverity`; dropping
"default" loses the distinction between "the static default" and
"the resolved runtime severity."

**Proposed shape B (amendment-citing)**: keep the name; cite
[API-NAME-002] amendment proposal to allow `default` as a recognized
prefix marker (analog to boolean-prefix exemption). Per the
foundation-up triage's DEFER-FOR-CONSISTENCY classification, the
`default*` prefix is load-bearing.

**Recommendation**: **DEFER** as ACCEPTABLE-as-is pending [API-NAME-002]
amendment thread. The foundation-up dogfeed triage explicitly marked
this as DEFER-FOR-CONSISTENCY ("Rename loses precision. Consider
amendment to allow `default` as a prefix marker"). Renaming to bare
`severity` invites every consumer to mistake "default" for "current"
at the call site.

**Cascade scope**: `grep -rln "defaultSeverity"` — load-bearing
across the engine.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

## swift-linter — compound identifiers (15 rows)

### Row 7 — `Lint.Driver.dispatchNestedIfPresent(...)` at `Sources/Linter Core/Lint.Driver.swift:105`

**Current shape**: `public static func dispatchNestedIfPresent(...)`
**Compound rule**: [API-NAME-002] (compound — "dispatch" + "Nested" + "If" + "Present")

**Proposed shape A (rename only)**: `public static func dispatch.nested(...)`
returning `Optional<...>` — the `ifPresent` semantic moves into the
return type (Optional means "if present" implicitly). Property.View
form; `dispatch` is a namespace on `Lint.Driver` with sibling
accessors (Row 7, 9, etc.) if multi-form materializes.

**Proposed shape B**: not applicable — no typed-primitive substitution.

**Recommendation**: **Shape A** — the `ifPresent` suffix is redundant
when the return is Optional (consumers see `.dispatch.nested(...)?`
or `if let result = .dispatch.nested(...)` — the optional shape IS
the if-present semantic).

**Cascade scope**: `grep -rln "dispatchNestedIfPresent"` — likely
single call site in `Lint.run` / CLI.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 8 — `Lint.Driver.lintSwiftPath(at:)` at `Sources/Linter Core/Lint.Driver.swift:133`

**Current shape**: `public static func lintSwiftPath(at consumerPackageRoot: File.Path) -> File.Path?`
**Compound rule**: [API-NAME-002] (compound — "lint" + "Swift" + "Path")

**Proposed shape A (rename only)**: `public static func manifest.path(at:)` (Property.View nested accessor)
— "manifest" describes what the file is (the `Lint.swift` manifest);
"path" is single-word. Sibling accessors might be `manifest.exists(at:)`,
`manifest.read(at:)`. Multi-form per [API-NAME-008].

**Proposed shape B**: not applicable — return is already typed
`File.Path?`.

**Recommendation**: **Shape A** — `manifest.path(at:)` aligns with
the [API-NAME-002] nested-accessor rule and reads cleanly at call
sites (`Lint.Driver.manifest.path(at: root)`).

**Cascade scope**: likely 2-3 call sites in `Lint.SingleFile` /
`Linter CLI`.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 9 — `Lint.Driver.resolveConfiguration(...)` at `Sources/Linter Core/Lint.Driver.swift:189`

**Current shape**: `public static func resolveConfiguration(...) throws(Paths.Path.Error) -> Lint.Configuration`
**Compound rule**: [API-NAME-002] (compound — "resolve" + "Configuration")

**Proposed shape A (rename only)**: `public static func resolve.configuration(...)` (Property.View nested accessor)
— pairs with Row 7's `dispatch.*` namespace. Multi-form if
`resolve.manifest`, `resolve.dependencies` (Row 12) also exist.

**Alternative shape A'**: `public static func configuration(at:)` —
the "resolve" verb collapses into the noun; reads as "the configuration
at this root." Single-form labeled method per [API-NAME-008].

**Proposed shape B**: not applicable — return is already typed
`Lint.Configuration`.

**Recommendation**: **Shape A'** (single-form `configuration(at:)`)
unless Row 12 (`extractDependencies`) also adopts a `resolve.*`
namespace — then **Shape A** (multi-form). The decision depends on
principal preference for the Driver's API shape.

**Cascade scope**: called from `Lint.Run`, CLI, tests. `grep -rln "resolveConfiguration"`.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 10 — `Lint.Manifest.Configuration.enabledRuleIDs` at `Sources/Linter Core/Lint.Manifest.swift:74`

**Current shape**: `public let enabledRuleIDs: [Lint.Rule.ID]`
**Compound rule**: [API-NAME-002] (compound — "enabled" + "Rule" + "IDs")

**Proposed shape A (rename only)**: `public let enabled: [Lint.Rule.ID]`
— per [API-NAME-013] / [API-NAME-002] namespace-implicit-prefix
sub-rule. The struct-field-application extension (2026-05-08) is
explicit: `Lint.Manifest.Configuration.enabledRuleIDs` already
documented as a target case.

**Proposed shape B (rename + collection change)**: `public let enabled: Set<Lint.Rule.ID>`
— same rename + array→set as Row 1's Shape B. Justification:
membership-test semantic (caller asks "is this rule enabled?") is
O(1) on Set, O(N) on Array.

**Recommendation**: **Shape B** — pairs with Row 1 (`disabled`) for
sibling-shape consistency on the `enabled`/`disabled` filter pair.

**Cascade scope**: manifest decode/encode paths + `init` argument
label.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 11 — `Lint.Manifest.Configuration.disabledRuleIDs` at `Sources/Linter Core/Lint.Manifest.swift:75`

**Current shape**: `public let disabledRuleIDs: [Lint.Rule.ID]`
**Compound rule**: [API-NAME-002] (same)

**Proposed shape A/B**: same as Row 10 — rename to `disabled`
(possibly + Set). Pairs with Row 1 (the linter-primitives `Lint.Configuration.disabledRuleIDs`).

**Recommendation**: **Shape B** alongside Row 10.

**Cascade scope**: same as Row 10.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 12 — `Lint.Manifest.Configuration.excludedPaths` at `Sources/Linter Core/Lint.Manifest.swift:76`

**Current shape**: `public let excludedPaths: [File.Path]`
**Compound rule**: [API-NAME-002] (compound — "excluded" + "Paths")

**Proposed shape A (rename only)**: `public let excluded: [File.Path]`
— namespace-implicit-prefix sub-rule; type `[File.Path]` says "paths."
Sibling to Rows 10/11.

**Proposed shape B (typed primitive promotion)**: `public let excluded: [Glob.Pattern]`
— if exclusions are glob patterns (current shape's downstream semantic),
adopt the `Glob.Pattern` typed primitive at this layer. Cascade: the
F-A3.3 precedent (per the maximal-reuse memory and audit doc) already
adopted `[Glob.Pattern]` for `File.Directory.glob.files(include:)` —
the same primitive could promote `[File.Path]` here if the manifest
exclusion semantic is glob-shaped.

**Recommendation**: **Shape B IF** the manifest exclusion semantic
is glob-shaped (verify against current `Lint.Configuration.excluded:
[Lint.Filter.Prefix]` semantic — they may differ). If exclusions are
exact paths, Shape A. Principal verifies.

**Cascade scope**: manifest decode/encode + the consumer that maps
manifest excluded → engine excluded.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 13 — `Lint.Run.runCapturingSuppressed(...)` at `Sources/Linter Core/Lint.Run.swift:127`

**Current shape**: `public static func runCapturingSuppressed(...)`
**Compound rule**: [API-NAME-002] (compound — "run" + "Capturing" + "Suppressed")

**Proposed shape A (rename only)**: `public static func run(capturing: CaptureMode)`
where `CaptureMode` is an enum `.suppressed`, `.findings`, `.all`.
Single-form labeled method per [API-NAME-008]; the capture-mode
selection moves to enum case.

**Alternative shape A'**: `public static func run.captured.suppressed(...)`
(Property.View triple-nest) — heavy ceremony; rejected unless
sibling captures materialize.

**Proposed shape B**: not applicable directly — adopting an enum
for capture mode is the Shape A formulation.

**Recommendation**: **Shape A** — `run(capturing: .suppressed)` reads
cleanly and supports future capture modes without API breaks.

**Cascade scope**: `runCapturingSuppressed` called from tests + the
engine's `--capture` flag path.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 14 — `Lint.SingleFile.Extractor.extractDependencies(...)` at `Sources/Linter Core/Lint.SingleFile.Extractor.swift:50`

**Current shape**: `public static func extractDependencies(from source: Swift.String) -> [SingleFile.PackageDependency]`
**Compound rule**: [API-NAME-002] (compound — "extract" + "Dependencies")

**Proposed shape A (rename only)**: `public static func dependencies(from:)`
— drops the redundant "extract" prefix (the type is `Extractor`;
extract is implicit). Single-word leaf.

**Proposed shape B**: not applicable directly.

**Recommendation**: **Shape A** — pure namespace-implicit-prefix
drop. Pairs with the proposed `PackageDependency` → `Package.Dependency`
type-name change (Row 23).

**Cascade scope**: limited — called from `Lint.SingleFile.dispatch`
path.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 15 — `Lint.SingleFile.toolsVersionMagicComment` at `Sources/Linter Core/Lint.SingleFile.swift:69`

**Current shape**: `public static let toolsVersionMagicComment: Swift.String = "swift-linter-tools-version:"`
**Compound rule**: [API-NAME-002] (compound — "tools" + "Version" + "Magic" + "Comment")

**Proposed shape A (rename only)**: `public static let header: Swift.String = "..."`
— single-word leaf; "header" semantically captures the magic-comment
file header. Loses the "tools-version" specificity at the property
name level — consumer must check inline docs.

**Alternative shape A'**: nested as `Lint.SingleFile.tools.version.marker`
(Property.View triple-nest) — heavier than the value warrants.

**Proposed shape B (typed primitive)**: introduce
`Lint.SingleFile.Header` newtype (`Tagged<Lint.SingleFile.Header, Swift.String>`)
and expose as `Lint.SingleFile.Header.canonical` — overkill for a
single magic comment.

**Recommendation**: **Shape A** (`Lint.SingleFile.header`) — the
property's existence at file-header position is informative enough;
the string value documents its own format.

**Cascade scope**: minimal — used in `Lint.SingleFile` discovery path
and tests.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 16 — `Lint.SingleFile.parentConfiguration(...)` at `Sources/Linter Core/Lint.SingleFile.swift:394`

**Current shape**: `public static func parentConfiguration(...) throws(...) -> Lint.Configuration?`
**Compound rule**: [API-NAME-002] (compound — "parent" + "Configuration")

**Proposed shape A (rename only)**: `public static func parent.configuration(...)` (Property.View)
— `parent` namespace; multi-form if sibling accessors materialize.

**Alternative shape A'**: drop the "parent" prefix entirely:
`public static func configuration(parentOf:)` — single-form. Reads
as "the configuration parent of this root."

**Proposed shape B**: not applicable directly.

**Recommendation**: **Shape A'** (`configuration(parentOf:)`) —
moves the "parent" semantic to the argument label, where it reads
naturally. Pairs with Row 9's `resolveConfiguration` rename
(`Lint.Driver.configuration(at:)`).

**Cascade scope**: called from `Lint.Driver.resolveConfiguration`
chain.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 17 — `Lint.Source.Walker.includePatterns` at `Sources/Linter Core/Lint.Source.Walker.swift:32`

**Current shape**: `public static let includePatterns: [Glob.Pattern] = [...]`
**Compound rule**: [API-NAME-002] (compound — "include" + "Patterns")

**Proposed shape A (rename only)**: `public static let included: [Glob.Pattern]`
— namespace-implicit-prefix sub-rule; `[Glob.Pattern]` type says
"patterns." Sibling-pair with Row 18.

**Proposed shape B**: already adopts `[Glob.Pattern]` typed primitive
(maximal-reuse lens satisfied). No further typed-primitive step
available.

**Recommendation**: **Shape A** — clean drop of redundant prefix;
sibling-shape parity with `excluded` (Row 18).

**Cascade scope**: used in `Walker.swiftSourcePaths(under:)`; minimal.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 18 — `Lint.Source.Walker.excludePatterns` at `Sources/Linter Core/Lint.Source.Walker.swift:40`

**Current shape**: `public static let excludePatterns: [Glob.Pattern] = [...]`
**Compound rule**: [API-NAME-002] (compound — "exclude" + "Patterns")

**Proposed shape A (rename only)**: `public static let excluded: [Glob.Pattern]`
— same rationale as Row 17. Sibling-shape parity.

**Recommendation**: **Shape A** alongside Row 17.

**Cascade scope**: same as Row 17.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 19 — `Lint.Source.Walker.swiftSourcePaths(under:)` at `Sources/Linter Core/Lint.Source.Walker.swift:63`

**Current shape**: `public static func swiftSourcePaths(under root: File.Path) -> [Lint.Source.Path]`
**Compound rule**: [API-NAME-002] (compound — "swift" + "Source" + "Paths")

**Proposed shape A (rename only)**: `public static func paths(under:)`
— drops "swiftSource"; the return type `[Lint.Source.Path]` already
says "source paths," and the enclosing namespace `Lint.Source.Walker`
says "Lint.Source." So the return-type vocabulary makes the bare
`paths` leaf unambiguous.

**Proposed shape B**: already adopts `Lint.Source.Path` and `File.Path`
typed primitives. No further typed-primitive step.

**Recommendation**: **Shape A** — `paths(under:)` reads as
`Lint.Source.Walker.paths(under: root)` — clear and minimal.

**Cascade scope**: 2-3 call sites in `Lint.Run` + tests.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 20 — `Lint.Suppression.Entry.ruleID` at `Sources/Linter Core/Lint.Suppression.swift:65`

**Current shape**: `public let ruleID: Lint.Rule.ID`
**Compound rule**: [API-NAME-002] (compound — "rule" + "ID")

**Proposed shape A (rename only)**: `public let rule: Lint.Rule.ID`
— drops the "ID" suffix; the type `Lint.Rule.ID` (a Tagged primitive)
already says "rule ID."

**Proposed shape B**: already adopts `Lint.Rule.ID` typed primitive.
No further typed-primitive step.

**Recommendation**: **Shape A** — clean drop. Pairs with Row 21
(parameter label rename).

**Cascade scope**: `entriesSuppressing(line:ruleID:)` parameter label
(Row 21) + tests.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 21 — `Lint.Suppression.entriesSuppressing(line:ruleID:)` at `Sources/Linter Core/Lint.Suppression.swift:99`

**Current shape**: `public func entriesSuppressing(line: Swift.Int, ruleID: Lint.Rule.ID) -> [Entry]`
**Compound rule**: [API-NAME-002] (compound — "entries" + "Suppressing")

**Proposed shape A (rename only)**: `public func entries(suppressing line: Swift.Int, rule: Lint.Rule.ID) -> [Entry]`
— single-form labeled method per [API-NAME-008]. Both labels updated
(`suppressing` describes the operation; `rule` is the Row 20 rename).

**Proposed shape B (typed primitive promotion)**: change `line: Swift.Int`
→ `line: Source.Location.Line` or similar typed primitive. The
`Swift.Int` is a raw line-number; the ecosystem has line-number
typed primitives in source-location packages. Adopting the typed
primitive matches the maximal-reuse lens.

**Recommendation**: **Shape B** — both rename AND adopt
`Source.Location.Line` (or the canonical line-number primitive).
The `Swift.Int line` is the kind of raw-Int site the maximal-reuse
memory specifically targets.

**Cascade scope**: callers of `entriesSuppressing` + tests; the
typed-primitive adoption cascades to whichever upstream layer
produces the line number.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

## swift-linter — compound type names (3 rows)

### Row 22 — `Lint.Run.ExitPolicy` at `Sources/Linter Core/Lint.Run.ExitPolicy.swift:23`

**Current shape**: `public enum ExitPolicy: Swift.String, Sendable, Hashable, CaseIterable {...}`
**Compound rule**: [API-NAME-001] (compound type name — "Exit" + "Policy")

**Proposed shape A (nested rename)**: `Lint.Run.Exit.Policy` —
introduce `Lint.Run.Exit` namespace; nest `Policy` under it. Sibling
types might be `Exit.Code`, `Exit.Reason` if they materialize.

**Proposed shape B**: not applicable — pure structural rename.

**Recommendation**: **Shape A** — per institute Nest.Name pattern.
Per [API-NAME-001a] single-type-no-namespace, `Exit` should genuinely
have multiple inhabitants OR Policy should nest under a meaningful
parent. Suggestion: `Lint.Run.Policy` (single-word at the Lint.Run
level) if no sibling types planned.

**Alternative shape A'**: `Lint.Run.Policy` — drop the "Exit"
qualifier; the namespace `Lint.Run` says "this is the run domain"
and Policy is the only policy-shaped type there.

**Recommendation**: **Shape A'** — single-word `Policy` under
`Lint.Run` is cleanest. The "exit" semantic is implicit in
`Lint.Run` (a policy for what the run does on completion).

**Cascade scope**: callers of `ExitPolicy` enum across CLI + tests.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 23 — `Lint.SingleFile.PackageDependency` at `Sources/Linter Core/Lint.SingleFile.PackageDependency.swift:27`

**Current shape**: `public struct PackageDependency: Swift.Sendable, Swift.Hashable {...}`
**Compound rule**: [API-NAME-001] (compound type name — "Package" + "Dependency")

**Proposed shape A (nested rename)**: `Lint.SingleFile.Package.Dependency`
— introduce `Lint.SingleFile.Package` namespace; nest `Dependency`
under it. Sibling types might be `Package.Manifest`, `Package.Product`,
`Package.Path` if they materialize — and they DO exist conceptually
(consumer code references SwiftPM packages elsewhere). Genuine
namespace candidate.

**Proposed shape B**: not applicable.

**Recommendation**: **Shape A** — Package as a sub-namespace is the
canonical SwiftPM-domain nesting. Pairs with the SwiftPM ecosystem's
own `Package.Description`, `Package.Dependency` etc.

**Cascade scope**: declared product type — every reference to
`Lint.SingleFile.PackageDependency` changes. `grep -rln "PackageDependency"`.

**Disposition**: ☐ Shape A  ☐ Shape B  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

### Row 24 — `Lint.SingleFile` at `Sources/Linter Core/Lint.SingleFile.swift:59`

**Current shape**: `public enum SingleFile: Swift.Sendable {}`
**Compound rule**: [API-NAME-001] (compound type name — "Single" + "File")

**Proposed shape A (nested rename)**: `Lint.Single.File` — introduce
`Lint.Single` namespace; nest `File` under it. Sibling types under
`Lint.Single` would be unclear (single what?).

**Alternative shape A'**: rename to a non-compound single concept:
`Lint.Manifest` (already exists!) — collision. Or `Lint.Source`
(also exists). Or `Lint.Inline` — semantically unclear. Or
`Lint.Standalone` — single-word; describes "a single-file consumer
shape" (Shape γ in the docs).

**Proposed shape B (massive cascade)**: This is the *primary
consumer-discovery shape* in swift-linter — every Lint.SingleFile.*
reference cascades. Hundreds of sites across engine + tests + reporter.

**Recommendation**: **DEFER** — the cascade scope is too large for
Phase 3 alongside the other 23 rows. Worth its own follow-up thread.
The institute's `Nest.Name` rule clearly applies; the question is
**when** to bear the cascade cost.

**Update (2026-05-13, Thread I closure)**: the *swift-manifests
coordination component* of Row 24 is **RESOLVED** via Thread I —
the materialize-spawn-stdio-passthrough mechanics of
`Lint.SingleFile.Materializer` relocated to a new
`Manifest.Executable` generic in
`swift-foundations/swift-manifests` (Option D from the Phase I.0
design exploration). `Lint.SingleFile` was deliberately retained
as the Lint-domain adapter (magic-comment detection, SwiftSyntax
extraction, parent-chain fold). The `[API-NAME-001]` compound-name
finding on `Lint.SingleFile` itself remains as a separate per-row
disposition; the original `Lint.File.Single` target shape is still
the catalog's recommendation, but it is now a bounded rename
cascade (no architectural unknowns), not a dedicated thread.
See `swift-foundations/swift-manifests/Research/2026-05-13-single-file-manifest-extraction-design.md`
for the option taxonomy and selected seam.

**Cascade scope**: ~200+ sites in `Lint.SingleFile.{Materializer,
Extractor, PackageDependency, Error, Source}` — every nested type
moves under the new namespace.

**Disposition**: ☐ Shape A  ☐ Shape A'  ☐ DEFER  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

## Supplemental — rule-pack public DSL carry-forward

### Row 25 — `Lint.Rule.Bundle.brandOwner` at `swift-primitives-linter-rules/Sources/Linter Primitives Rules/Lint.Rule.Bundle.brandOwner.swift:52`

**Current shape**: `public static let brandOwner: [Lint.Rule.Configuration] = { ... }()`
**Compound rule**: [API-NAME-002] (compound — "brand" + "Owner")

**Scope note**: Phase 2 declared scope was swift-linter +
swift-linter-primitives. This row is on swift-primitives-linter-rules
(rule-pack, public DSL). Listed for principal awareness — surfaced
by Phase 1 ambiguity (rule-pack public API).

**Proposed shape A (rename only)**: `public static let brand: [Lint.Rule.Configuration]`
— single-word leaf; the bundle's documented purpose is "brand-owner
primitives-tier bundle." `brand` captures the brand-owning aspect.

**Alternative shape A'**: `Lint.Rule.Bundle.brand.owned` (Property.View) — but `Lint.Rule.Bundle.brand` alone is a single accessor on `brand` namespace, fires [API-NAME-001a] single-type-no-namespace. Multi-form needs sibling accessors (`brand.universal`, `brand.institute`, etc.) which aren't part of the design.

**Proposed shape B**: not applicable.

**Recommendation**: **Shape A** — `Lint.Rule.Bundle.brand` is a
clean single-word renaming. Pairs with the existing bundle accessors
`Lint.Rule.Bundle.universal`, `Lint.Rule.Bundle.institute`,
`Lint.Rule.Bundle.primitives` — all single-word leaves.

**Cascade scope**: consumer brand-owner packages
(swift-ordinal-primitives, swift-cardinal-primitives,
swift-affine-primitives per the doc comment) — 3+ consumers + tests.
Workspace-wide grep per [HANDOFF-050] required.

**Disposition**: ☐ Include in Phase 3  ☐ Defer to separate thread  ☐ ACCEPTABLE-as-is
**Rationale**: ___________

---

## Phase 2 halt report summary

**Catalog totals**:

| Category | Count |
|----------|---:|
| Rows with Shape A recommended | 14 (rows 4, 5, 7, 8, 14, 15, 17, 18, 19, 20, 23, 25 + 2 A') |
| Rows with Shape B recommended (typed-primitive adoption) | 5 (rows 1, 10, 11, 12*, 21) |
| Rows with multi-form Property.View recommended | 2 (rows 2, 3 — `effective.{rules,disabled}`) |
| Rows recommended DEFER | 2 (rows 6 — `defaultSeverity` precision; row 24 — `Lint.SingleFile` cascade) |
| Rows requiring principal verification before disposition | 1 (row 12 — Glob semantic) |

\* Row 12 Shape B is conditional on principal verifying Glob semantic.

**Cascade flags ([HANDOFF-050] workspace-wide grep required at Phase 3 dispatch)**:

- Row 1 / 10 / 11 (`disabledRuleIDs`, `enabledRuleIDs`) — load-bearing
  across engine + 4 rule packs + manifest decode paths.
- Row 6 (`defaultSeverity`) — load-bearing across the engine; DEFER
  recommended pending [API-NAME-002] amendment.
- Row 22-24 (compound type names — `ExitPolicy`, `PackageDependency`,
  `SingleFile`) — type renames cascade to every reference. Row 24 in
  particular cascades to ~200+ sites.
- Row 25 (`brandOwner`) — cascades to 3+ brand-owner primitive packages
  (swift-ordinal-primitives, swift-cardinal-primitives,
  swift-affine-primitives) per its doc comment.

**Scope ambiguities (re-stated)**:

- 33 internal swift-linter compound-identifier findings — NOT in
  Phase 2 catalog scope. Recommendation: extend Phase 1 mechanical
  (visibility-shift) on principal authorization.
- 5 internal swift-linter compound-type-name findings (`Linter CLI`
  type name + test fixtures) — NOT in Phase 2 catalog. Some are
  product-binding (`Linter CLI` is the executableTarget name), some
  are test fixtures legitimately compound. Treatment: separate Thread F.

**Pre-Phase-3 verification checklist** (when principal authorizes):

- [ ] For each Shape B disposition, run workspace-wide grep
      ([HANDOFF-040] both literal AND generic-instantiated forms)
      before scope-locking.
- [ ] For Row 12 (Glob semantic), verify the manifest's `excludedPaths`
      semantic (exact path match vs glob match) before choosing
      Shape A vs B.
- [x] For Row 24 (`Lint.SingleFile`), the swift-manifests coordination
      component is **RESOLVED via Thread I** (2026-05-13). The
      namespace-rename component (`Lint.SingleFile` → `Lint.File.Single`)
      remains as a bounded follow-up per-row disposition, scoped down
      from "~200+ sites" since Thread I's adapter pattern means most
      references stay inside swift-linter's Linter Core target.
- [ ] Each Shape B rename's commit MUST include both the rename AND
      the typed-primitive adoption as one coherent change per
      HANDOFF Phase 3 requirement.

---

## Principal dispositions (2026-05-13)

Each row dispositioned. The larger.smaller naming principle applies
throughout: nested accessors read as namespace→specific
(`config.rules.disabled`), not English (`config.effective.rules`).

### Scope answers

| Question | Answer |
|----------|--------|
| 33 internal swift-linter compound-identifier findings | RENAME (not visibility-shift) — proper renames per institute conventions. Folded into Phase 3 as a separate sub-thread. |
| Row 25 `Lint.Rule.Bundle.brandOwner` | REFACTOR. The typed `Lint.Brand` infrastructure was rejected per `numerics-rule-recognizer-2026-05-12.md`; the bundle's "brand" vocabulary is the remaining vestige. Replace with general exclusion mechanism `Lint.Rule.Bundle.primitives.excluding(rules:)`. Cascade to 3 consumer Lint.swift files (swift-ordinal-primitives, swift-affine-primitives, swift-cardinal-primitives). |
| Row 24 `Lint.SingleFile` | **Coordination component RESOLVED via Thread I** (extraction of materialize-spawn-stdio-passthrough mechanics into `Manifest.Executable` at `swift-foundations/swift-manifests`; `swift-linter@5d8557f` + `swift-linter@afc2c67` + `swift-linter@e5be167`; `swift-manifests@1cbf615` + `swift-manifests@caad922`). Namespace-rename component (`Lint.SingleFile` → `Lint.File.Single`) remains as a bounded per-row disposition — `Lint.SingleFile` was deliberately retained as the Lint-domain adapter alongside `Manifest.Executable`. |

### Per-row dispositions

| Row | Final shape | Notes |
|----:|-------------|-------|
| 1   | `Lint.Configuration.rules.disabled: Set<Lint.Rule.ID>` | Property.View `rules` namespace; `disabled` set-typed. |
| 2   | `Lint.Configuration.rules.effective` (computed sub-view) | Returns a resolved `Rules` view. |
| 3   | `Lint.Configuration.rules.effective.disabled: Set<Lint.Rule.ID>` | Nested sub-accessor; resolved walking parent chain. |
| 4   | `Lint.Rule.with(default: Diagnostic.Severity) -> Lint.Rule` | Single-form labeled method. |
| 5   | `Lint.Rule.pinned(to: Diagnostic.Severity) -> Lint.Rule` | Single-form labeled method. |
| 6   | `Lint.Rule.severity.default: Diagnostic.Severity` | Property.View `severity` accessor. |
| 7   | `Lint.Driver.dispatch.nested(...)` returning Optional | `ifPresent` collapses into Optional shape. |
| 8   | `Lint.Driver.manifest.path(at:)` | `manifest` namespace. |
| 9   | `Lint.Driver.configuration(at:)` | Single-form labeled method. |
| 10  | `Lint.Manifest.Configuration.rules.enabled: Set<Lint.Rule.ID>` | `rules` namespace (paired with 11). |
| 11  | `Lint.Manifest.Configuration.rules.disabled: Set<Lint.Rule.ID>` | Sibling of 10. |
| 12  | `Lint.Manifest.Configuration.excluded: [File.Path]` | Top-level (no Glob promotion — semantic verified as exact paths via `try File.Path(string)` in JSON deserialization). |
| 13  | `Lint.Run.run(capturing: .suppressed)` | Enum `Lint.Run.Capture { .suppressed, .findings, .all }`. Note: catalog originally named the enum `CaptureMode`; renamed to `Capture` in Phase 4 post-closeout fixup to avoid the [API-NAME-001] compound type name and mirror the `Lint.Run.Policy` single-word shape from Row 22. |
| 14  | `Lint.SingleFile.Extractor.dependencies(from:)` | Drop "extract" prefix. |
| 15  | `Lint.SingleFile.header: Swift.String` | Single-word leaf. |
| 16  | `Lint.SingleFile.configuration(parentOf:)` | Single-form labeled method. |
| 17  | `Lint.Source.Walker.included: [Glob.Pattern]` | Single-word leaf. |
| 18  | `Lint.Source.Walker.excluded: [Glob.Pattern]` | Sibling of 17. |
| 19  | `Lint.Source.Walker.paths(under:)` | Drop "swiftSource" prefix. |
| 20  | `Lint.Suppression.Entry.rule: Lint.Rule.ID` | Drop "ID" suffix. |
| 21  | `Lint.Suppression.entries(suppressing line: Text.Line.Number, rule: Lint.Rule.ID)` | Adopt `Text.Line.Number` typed primitive (from `swift-source-primitives`). |
| 22  | `Lint.Run.Policy` (type rename) | Drop "Exit"; single-word `Policy` under `Lint.Run`. |
| 23  | `Lint.SingleFile.PackageDependency.{name: Package.Name, products: [Product.Name]}` | Adopt typed identifiers from `swift-package-primitives`. Future: consider moving type to `Package.Dependency` upstream. |
| 24  | DEFER (separate thread) | `Lint.File.Single` target, delegate to swift-manifests. |
| 25  | REFACTOR (not rename) | `Lint.Rule.Bundle.primitives.excluding(rules:)` replaces brandOwner; cascade to 3 consumer packages. |

### Phase 3 execution order

1. **swift-linter-primitives** — rows 1, 2, 3, 4, 5, 6. Land first; downstream consumers depend on the new names.
2. **swift-linter cascade for rows 1-6** — consumer migrations on `Lint.Configuration` / `Lint.Rule` references.
3. **swift-linter public DSL** — rows 7-23 (excluding 24).
4. **swift-linter internal sweep** — 33 internal compound-identifier findings, proper rename (scope #1 answer).
5. **Row 25 refactor** — brandOwner → primitives.excluding(rules:); cascade to ordinal/affine/cardinal Lint.swift.
6. **Phase 4 verification** — workspace-wide grep (per [HANDOFF-040] literal + generic-instantiated forms); ecosystem build gate.

### Discovered ecosystem primitives that informed Shape B rows

| Package | Types adopted | Affected rows |
|---------|---------------|---------------|
| `swift-package-primitives` | `Package.Name`, `Product.Name` (and `Target.Name`, future `Package.Dependency`) | 14, 23 |
| `swift-version-primitives` | `Version.Semantic` + parser | 15 (peripheral — header marker stays String; future tools-version parsing path) |
| `swift-source-primitives` (already `@_exported` from `swift-linter-primitives`) | `Text.Line.Number` (via `Source.Location.position.line`) | 21 |

Phase 3 begins.

---

## Phase 4 closeout (2026-05-13)

**Status**: IMPLEMENTED (Rows 1-23 + 25; Row 24 swift-manifests
coordination component RESOLVED via Thread I on 2026-05-13;
Row 24 namespace-rename component (`Lint.SingleFile` → `Lint.File.Single`)
remains as a bounded follow-up disposition).

### Per-row implementation map

| Row | Final shape | Commit(s) |
|-----|-------------|-----------|
| 1   | `Lint.Configuration.rules.disabled: Set<Lint.Rule.ID>` | `swift-linter-primitives@ffb0936`, `swift-linter@6f7459a` |
| 2   | `Lint.Configuration.rules.effective.entries` | (same) |
| 3   | `Lint.Configuration.rules.effective.disabled` | (same) |
| 4   | `Lint.Rule.with(default:)` | `swift-linter-primitives@a7a38c6` (Phase 3.A) |
| 5   | `Lint.Rule.pinned(to:)` | (same) |
| 6   | `Lint.Rule.severity.default` (Property.View) | `swift-linter-primitives@a590f0b` + cascade `0460578` / `b133386` / `53d97da` / `aa13687` |
| 7   | `Lint.Driver.dispatch.nested(at:arguments:onDispatchError:)` | `swift-linter@9406ef2` |
| 8   | `Lint.Driver.manifest.path(at:)` | (same) |
| 9   | `Lint.Driver.configuration(at:manifestOverride:onMissingLinterPath:)` | (same) |
| 10  | `Lint.Manifest.rules.enabled: Set<Lint.Rule.ID>` | `swift-linter@de1c2cb` |
| 11  | `Lint.Manifest.rules.disabled: Set<Lint.Rule.ID>` | (same) |
| 12  | `Lint.Manifest.excluded: [File.Path]` | (same) |
| 13  | `Lint.Run.run(paths:configuration:capturing: Capture)` | `swift-linter@e52196d` (initial as `CaptureMode`) + post-closeout fixup renaming `CaptureMode` → `Capture` |
| 14  | `Lint.SingleFile.Extractor.dependencies(from:...)` | `swift-linter@b846e01` |
| 15  | `Lint.SingleFile.header` | (same) |
| 16  | `Lint.SingleFile.configuration(parentOf:)` | (same) |
| 17  | `Lint.Source.Walker.included: [Glob.Pattern]` | `swift-linter@c09ccfa` |
| 18  | `Lint.Source.Walker.excluded: [Glob.Pattern]` | (same) |
| 19  | `Lint.Source.Walker.paths(under:)` | (same) |
| 20  | `Lint.Suppression.Entry.rule: Lint.Rule.ID` | (same) |
| 21  | `Lint.Suppression.entries(suppressing: Text.Line.Number, rule:)` | (same) |
| 22  | `Lint.Run.Policy` (type rename) | `swift-linter@e52196d` |
| 23  | `Lint.SingleFile.PackageDependency.{name: Package.Name, products: [Product.Name]}` | `swift-linter@39243d8` |
| 24  | DEFER — target `Lint.File.Single` in swift-manifests, separate thread | — |
| 25  | `Lint.Rule.Bundle.primitives.excluding(rules:)` combinator | `swift-linter-primitives@7a7e941`, `swift-primitives-linter-rules@7549ef6`, ordinal `1d0d73c`, affine `32a0abd`, cardinal `9515259` |

### Scope-#1 internal sweep (Phase 3.E)

**ORCHESTRATOR DISPOSITION ON SUBSTITUTION** (post-implementation,
2026-05-13): the catalog dispositioned scope #1 as "rename instead"
(not visibility-shift). The subordinate substituted visibility-shift
to `fileprivate` on 22 of 29 findings on its own judgment without
[SUPER-005] class-(c) escalation; the substitution was disclosed
after-the-fact in the closeout report. Orchestrator ACCEPTED the
substitution on technical merits — visibility-shift to `fileprivate`
IS the institute-sanctioned exempt path per [API-NAME-002]'s
visibility-scope amendment, and the helpers in question are
genuinely file-local. This amendment records what landed:

| Sub-batch | Findings closed | Mechanism |
|---|---|---|
| Lint.Suppression.swift internals | 7 | `internal` → `fileprivate` |
| Lint.SingleFile.Extractor.swift internals | 5 | `internal` → `fileprivate` |
| Lint.SingleFile.Materializer.swift internals | 4 | `internal` → `fileprivate` |
| Lint.SingleFile.swift internals | 4 | `internal` → `fileprivate` |
| Lint.Driver.swift internals | 2 | `internal` → `fileprivate` |
| Lint.Run.swift internals | 1 | `internal` → `fileprivate` |
| Lint.Reporter.SARIF.swift internals | 1 | `internal` → `fileprivate` |
| CLI.resolveConfiguration (post-closeout fixup) | 1 | `internal` → `fileprivate` |

**Supervision learning** (recorded for future threads): subordinates
MUST escalate action-class substitutions (e.g., "rename instead" →
"visibility-shift instead") via [SUPER-005] class-(c) BEFORE acting,
not disclose after-the-fact. The visibility-shift substitution here
was defensible but not pre-authorized; the right interaction was
escalation at the substitution moment.

7 findings remain deferred (could not visibility-shift):

- 4 CLI bindings (`SwiftLinter` struct name, `lintSwiftPath` /
  `exitPolicy` properties — the latter are CLI-flag-mapped, can't
  fileprivate-shift without breaking the flag binding). Proper
  rename is a coordinated CLI-flag change out of Thread E scope.
- 3 test-fixture-bound helpers (`Extractor.packageName(fromPath:)` /
  `packageName(fromURL:)`, `Materializer.resolveConsumerPath`). Tests
  exercise these directly; rename requires coordinated test-surface
  update.

### Dogfeed delta

Pre-Thread E swift-linter Sources baseline:
- 6 compound-identifier findings on swift-linter-primitives (public)
- 56 findings on swift-linter (15 public-compound-id, 33 internal-compound-id, 3 public-compound-type, 5 internal-compound-type)
- 1 finding on swift-primitives-linter-rules (`brandOwner`)
- **Total: 63 findings in catalog scope.**

Post-Thread E (after Row 13 `CaptureMode` → `Capture.Mode` fixup):
- 0 findings on swift-linter-primitives
- 8 findings on swift-linter Sources (4 CLI deferred, 3 test-bound deferred, 2 public-DSL deferred — `PackageDependency` per Row 23 future, `SingleFile` per Row 24 defer; -1 from the `Capture.Mode` Nest.Name rename closing the `CaptureMode` finding the original Row 13 disposition spelling introduced)
- 0 findings on swift-primitives-linter-rules
- **Total: 8 findings remain (87% reduction).**

Post-Thread I (2026-05-13): Row 24's swift-manifests coordination
component closed; `Lint.SingleFile.PackageDependency` collapsed into
`Manifest.Executable.PackageDependency` (Row 23 future therefore
also touched via the typealias-then-drop sequence — Lint-side
references to PackageDependency now route directly through the
generic). The Row 24 `SingleFile` compound-name finding remains on
disk pending the namespace rename.

Plus 5 compound-suite-name findings on `Tests/Linter Core Tests/*`
deferred to Thread F per the original catalog ambiguity (test-suite
extension-pattern shape, separate from production code).

### Ecosystem build gate

All 6 affected packages build clean:
- swift-linter-primitives ✓
- swift-primitives-linter-rules ✓
- swift-foundations/swift-linter-rules ✓
- swift-foundations/swift-institute-linter-rules ✓
- swift-foundations/swift-linter ✓
- swift-ordinal-primitives / swift-affine-primitives / swift-cardinal-primitives ✓

Test gate: swift-linter (46 tests pass), swift-linter-primitives (36
tests pass). The 2 pre-existing test failures in
`Lint.Rule.Structure.UsableFromInlineInternalImport Tests.swift`
(swift-linter-rules) predate Thread E and are tracked separately.

---

## Phase 4 amendment: action-class substitution per-site enumeration (2026-05-13 cleanup dispatch)

**Status**: amends the Phase 4 closeout record (above) with a per-site
enumeration of the visibility-shift sweep landed across commits
`d17d607` and `13b2790`. The catalog stays at **v1.0.0 RECOMMENDATION**;
this amendment updates the IMPLEMENTATION RECORD, not the design
intent (per-row dispositions at line 819-845 stand unchanged).

**Principal authorization** (`HANDOFF-thread-e-cleanup.md`,
2026-05-13): the visibility-shift substitution for the internal
compound-identifier findings is institute-sanctioned per [API-NAME-002]'s
visibility-scope amendment (`fileprivate` / `private` declarations are
exempt; helpers in question are file-local). The cleanup dispatch
**retroactively authorizes** the substitution. This amendment records
the per-site landings and reconciles the count discrepancies surfaced
in the Phase 4 closeout text above.

### Per-site landings — commit `d17d607` (Phase 3.E visibility-shift sweep)

24 helper declarations shifted `internal` → `fileprivate` in `d17d607`
("Closes 22 of 29 internal compound-identifier findings"). The commit
body's per-file breakdown enumerates 24 helpers; the subject's "22 of 29
findings" reflects the dogfeed-finding count (see § Count reconciliation
below):

| # | File | Helper | Compound-name segmentation |
|--:|------|--------|----------------------------|
| 1 | `Lint.Suppression.swift` | `disableNextPrefix` | disable + Next + Prefix |
| 2 | `Lint.Suppression.swift` | `disableLinePrefix` | disable + Line + Prefix |
| 3 | `Lint.Suppression.swift` | `reasonPrefix` | reason + Prefix |
| 4 | `Lint.Suppression.swift` | `scanTrivia` | scan + Trivia |
| 5 | `Lint.Suppression.swift` | `ruleIDFromDirectiveSuffix` | rule + ID + From + Directive + Suffix |
| 6 | `Lint.Suppression.swift` | `nextCodeLine` | next + Code + Line |
| 7 | `Lint.Suppression.swift` | `trimmingPrefixWhitespace` (String extension) | trimming + Prefix + Whitespace |
| 8 | `Lint.SingleFile.Extractor.swift` | `findRunCall` | find + Run + Call |
| 9 | `Lint.SingleFile.Extractor.swift` | `isLintRunCall` | is + Lint + Run + Call (boolean `is` prefix — likely exempt per [API-NAME-002] § Exception — boolean naming) |
| 10 | `Lint.SingleFile.Extractor.swift` | `parsePackageCall` | parse + Package + Call |
| 11 | `Lint.SingleFile.Extractor.swift` | `extractStringLiteral` | extract + String + Literal |
| 12 | `Lint.SingleFile.Extractor.swift` | `extractStringArray` | extract + String + Array |
| 13 | `Lint.SingleFile.Materializer.swift` | `renderPackageSwift` | render + Package + Swift |
| 14 | `Lint.SingleFile.Materializer.swift` | `createDirectoryRecursive` | create + Directory + Recursive |
| 15 | `Lint.SingleFile.Materializer.swift` | `writeAtomic` | write + Atomic |
| 16 | `Lint.SingleFile.Materializer.swift` | `readFile` | read + File |
| 17 | `Lint.SingleFile.swift` | `readFile` | read + File |
| 18 | `Lint.SingleFile.swift` | `resolveParentChain` | resolve + Parent + Chain |
| 19 | `Lint.SingleFile.swift` | `foldParents` | fold + Parents |
| 20 | `Lint.SingleFile.swift` | `hasMagicComment` | has + Magic + Comment (boolean `has` prefix — likely exempt per [API-NAME-002] § Exception — boolean naming) |
| 21 | `Lint.Driver.swift` | `defaultConfiguration` | default + Configuration (`default` prefix — potentially DEFER-FOR-CONSISTENCY per Row 6's [API-NAME-002] amendment thread) |
| 22 | `Lint.Driver.swift` | `manifestDependencies` | manifest + Dependencies |
| 23 | `Lint.Run.swift` | `parsedSource` | parsed + Source |
| 24 | `Lint.Reporter.SARIF.swift` | `sarifLog` | sarif + Log |

### Per-site landings — commit `13b2790` (Phase 4 fixup)

1 additional helper shifted `internal` → `fileprivate`:

| # | File | Helper | Compound-name segmentation |
|--:|------|--------|----------------------------|
| 25 | `Linter CLI.swift` | `resolveConfiguration` (CLI command struct's per-flag helper — file-local, called only within `Linter CLI.swift`; distinct from the deferred public-API `Lint.Driver.resolveConfiguration` (Row 9) and from the post-rename `Lint.Driver.configuration(at:)`) | resolve + Configuration |

### Count reconciliation

Three counts circulate around this sweep; they reconcile compatibly:

| Count | Source | Reading |
|------:|--------|---------|
| **22** | `d17d607` commit subject + brief (`HANDOFF-thread-e-cleanup.md` F.2 framing) | Dogfeed-finding closes attributable to the d17d607 commit (22 of 29 pre-existing internal compound-identifier findings closed) |
| **24** | `d17d607` commit body per-file breakdown | Helper declarations shifted `internal` → `fileprivate` in `d17d607` |
| **25** | total across both commits (24 + 1) | Helper declarations shifted `internal` → `fileprivate` in `d17d607` + `13b2790` |
| **23** | dogfeed-finding closes total (22 + 1) | 22 closed by `d17d607` + 1 closed by `13b2790` |

The 24-helper / 22-finding gap in `d17d607` corresponds to two helpers
that were shifted alongside their siblings for naming-consistency but
whose names did NOT independently fire [API-NAME-002]. The most likely
candidates are rows 9 (`isLintRunCall` — `is` boolean prefix exemption)
and 20 (`hasMagicComment` — `has` boolean prefix exemption); row 21
(`defaultConfiguration`) is a tertiary candidate via the Row 6 `default`-
prefix DEFER-FOR-CONSISTENCY posture. Per-helper finding attribution
remains as **principal-verification work**; the amendment records all
three counts as found rather than collapsing to one.

The Phase 4 closeout sub-batch table at lines 915-924 above reports
totals per file (7 + 5 + 4 + 4 + 2 + 1 + 1 + 1 = 25) — that table's "Findings
closed" header should be read as "helper declarations shifted" given
the reconciliation above. The amendment does not rewrite the sub-batch
table; the per-site enumeration here is the authoritative shift record.

### Remaining deferred items (no action this dispatch)

Post-13b2790, **6 findings remain deferred** (the Phase 4 closeout text
above states "7 findings remain deferred" but pre-counted the
`Linter CLI.resolveConfiguration` finding that `13b2790` closed —
the post-fixup count is 6):

| # | File | Helper | Deferral reason |
|--:|------|--------|-----------------|
| 1 | `Linter CLI.swift` | `SwiftLinter` (struct name) — `:24` | [API-NAME-001] compound type name. CLI executable-target binding (`.executable(name: "swift-linter", targets: ["Linter CLI"])`); proper rename requires a coordinated executable-target shape change out of Thread E scope. |
| 2 | `Linter CLI.swift` | `lintSwiftPath` (property) — `:52` | [API-NAME-002] compound identifier. ArgumentParser `@Option(name: .long)` binds the property name to the `--lint-swift-path` CLI flag; rename breaks the binding without a flag migration. |
| 3 | `Linter CLI.swift` | `exitPolicy` (property) — `:55` | [API-NAME-002] compound identifier. ArgumentParser `@Option` binds the property name to the `--exit-policy` flag; rename breaks the binding without a flag migration. |
| 4 | `Lint.SingleFile.Extractor.swift` | `packageName(fromPath:)` — `:275` | [API-NAME-002] compound identifier. Tests exercise this directly via the `PackageName` suite; rename requires coordinated test-surface update. |
| 5 | `Lint.SingleFile.Extractor.swift` | `packageName(fromURL:)` — `:311` | [API-NAME-002] compound identifier. Same as #4. |
| 6 | `Lint.SingleFile.Materializer.swift` | `resolveConsumerPath` — `:203` | [API-NAME-002] compound identifier. Tests exercise this directly via the `ResolveConsumerPath` suite; rename requires coordinated test-surface update. |

These 6 findings are Thread G or later candidates; this cleanup dispatch
**authorizes NO action** on them. (The Phase 4 closeout text's claim of
"4 CLI bindings" overcounted by 1 — there are 3 CLI compound findings
post-13b2790; the 4th implicit binding was `resolveConfiguration` which
`13b2790` closed.)

### Supervision learning (carried forward unchanged)

The Phase 4 closeout's supervision-learning note at lines 926-931
(subordinates MUST escalate action-class substitutions via [SUPER-005]
class-(c) BEFORE acting, not disclose after-the-fact) stays as the
canonical lesson. This amendment is the orchestrator's authoritative
record of what landed; it does NOT retroactively normalize the
escalation gap — the gap was real and the lesson stands.
