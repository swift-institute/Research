# Foundation-Up Dogfeed Triage — swift-linter-primitives + swift-linter

<!--
---
version: 1.0.0
last_updated: 2026-05-12
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

Per the foundation-up dogfeed dispatch (`HANDOFF.md` 2026-05-12), the
two foundation packages of the linter ecosystem received their first
end-to-end Lint.swift and were dogfed against the institute-tier
bundle (swift-linter) and primitives-tier bundle
(swift-linter-primitives) respectively.

**Lint.swift shapes**:

```swift
// swift-linter-primitives/Lint.swift  → loads Lint.Rule.Bundle.primitives
// swift-linter/Lint.swift              → loads Lint.Rule.Bundle.institute
```

Both materialize and dispatch against `swift-linter .` (debug build,
per the carried release-mode crash constraint).

**Aggregate finding counts**:

| Package | Total | Top rule | Second | Third |
|---------|------:|----------|--------|-------|
| swift-linter-primitives | 27 | minimal type body (16) | compound identifier (7) | raw value access (4) |
| swift-linter | 148 | compound identifier (43) | untyped throws (20) | minimal type body (19) |

Followed (in swift-linter) by: `do throws for typed catch` (13),
`try optional` (11), `usable from inline internal import` (9),
`compound type name` (9), `raw value access` (6),
`compound suite name` (4), `int public parameter` (3),
`counter loop iteration` (3), `unchecked call site` (2),
`result wrapper for rethrows shim` (2), `count minus one` (2),
`pointer advanced by` (1), `inlinable internal access` (1).

---

## Triage Taxonomy

Carried verbatim from
`swift-foundations/swift-linter-rules/Research/numerics-secondary-rule-defects-2026-05-12.md`
v1.1.0:

- **SOURCE-WRONG** — the source genuinely violates the rule's
  principled scope; mechanical fix lands inline.
- **RULE-WRONG** — the rule's recognizer or message-frame fires
  outside its principled scope; rule amendment is the cure.

A finding may be SOURCE-WRONG-by-rule but DEFER-FOR-CONSISTENCY (e.g.,
a compound-name property that is load-bearing across the public API
surface where renaming would cascade across consumers) — these are
called out explicitly per finding.

---

## Disposition — swift-linter-primitives (27 findings)

### RULE-WRONG (11 findings → 2 amendment threads)

#### A1. API-IMPL-008 vs `@Suite` carve-out gap (7 findings)

**Sites**:
- `Tests/Linter Primitives Tests/Lint.Configuration Tests.swift:18, 64`
- `Tests/Linter Primitives Tests/Lint.Finding Tests.swift:18`
- `Tests/Linter Primitives Tests/Lint.Rule.Witness Tests.swift:20`
- `Tests/Linter Primitives Tests/Lint.Visibility Tests.swift:20, 21`
- `Tests/Support/Lint.Rule.Sketch.swift:36`

**Defect**: `Lint.Rule.Structure.MinimalTypeBody`
(`hasResultBuilderAttribute(_:)`) carves out
`@resultBuilder`-marked types but not `@Suite`-marked types. The
swift-testing `@Suite` extension-pattern from [SWIFT-TEST-002] is:

```swift
extension Foo {
    @Suite struct Test {
        @Suite struct Unit {}        // ← nested-type-in-body fires
        @Suite struct Effective {}   // ← nested-type-in-body fires
    }
}
```

The outer `@Suite struct Test {}` legitimately holds nested `@Suite`
substructures as its only members, mirroring the `@resultBuilder`
informal-protocol pattern (the attribute IS the spec). Forcing
extraction yields empty-body + extension-with-only-witnesses for zero
semantic gain — the same justification documented for the existing
`@resultBuilder` carve-out at `MinimalTypeBody.swift:170-191`.

**Recommended amendment**: extend `hasResultBuilderAttribute(_:)` (and
its sibling in `Lint.Rule.Naming.Shared.swift`) to recognize `@Suite`
in addition to `@resultBuilder`. Rename the predicate to
`hasExtensionPatternAttribute(_:)` (or similar) to capture the
broader semantic: types whose member shape is dictated by an external
informal-protocol contract.

**Cross-references**: [API-IMPL-008], [SWIFT-TEST-002], [RULE-EXEMPT-4];
HANDOFF.md Open Question 1.

#### A2. PATTERN-017 raw-value-access fires on `Swift.enum.rawValue` (4 findings)

**Sites**:
- `Tests/Linter Primitives Tests/Lint.Visibility Tests.swift:42, 43, 44, 45`

**Defect**: `Lint.Rule.Structure.RawValueAccess` flags any
`MemberAccessExprSyntax` whose `declName.baseName.text` matches the
flagged-accessors set `["rawValue", "position"]`. The recognizer does
NOT inspect the receiver type. The principled scope (per the rule's
own message body) is Tagged-newtype `.rawValue` access at consumer
call sites.

`Lint.Visibility` is a Swift `enum Visibility: Swift.String`. The
test cases verify `Visibility.public.rawValue == "public"` etc. — this
is `Swift.RawRepresentable` `.rawValue`, not Tagged `.rawValue`. The
two share the property name only.

**Recommended amendment**: enrich the recognizer to disambiguate.
Options ordered by cost:

1. **Type-side disambiguation (cheap, high-precision)**: in same-package
   declarations where the receiver is provably a `Swift.enum` with
   `RawRepresentable` conformance, skip the firing. Requires
   single-file lookup of the declared type at the receiver position
   — not always available pre-resolution but plausible for single-package
   AST passes.
2. **Receiver-name disambiguation (cheap, less precise)**: skip the
   firing when the receiver expression's identifier resolves to an
   `enum` declaration in the same file. AST-only, no semantic
   analysis required.
3. **Configuration-driven exclude-list**: extend `Lint.Configuration`
   with a per-rule path-prefix exclude-list usable from the consumer
   `Lint.swift`. Heavier — touches engine surface.

(2) is structurally cheapest and matches the recognizer's existing
AST-only contract.

**Cross-references**: [PATTERN-017], [PATTERN-019] (parallel
recognizer-gap pattern from numerics dispatch).

### SOURCE-WRONG (16 findings → mechanical fix)

#### B1. Move-to-extension API-IMPL-008 (9 source findings)

**Sites + fix shape** (move member from type body to a sibling extension):

- `Sources/Linter Primitives/Lint.Configuration.swift:53` —
  `public var parent: Configuration?` (computed). Move into the
  existing `// MARK: - Effective rule resolution` extension or a new
  `extension Lint.Configuration { public var parent: ...}` block.
- `Sources/Linter Primitives/Lint.Configuration.swift:101` —
  `public static let empty: Self = Self { [] }`. Move to
  `extension Lint.Configuration { public static let empty: ... }`.
- `Sources/Linter Primitives/Lint.Filter.swift:65` —
  `public typealias Prefix = Tagged<Lint.Filter, Swift.String>`.
  Move to `extension Lint.Filter { public typealias Prefix = ... }`.
  (Note: not eligible for `[RULE-EXEMPT-5]` protocol-sentinel —
  the typealias name is `Prefix`, not `` `Protocol` ``.)
- `Sources/Linter Primitives/Lint.Filter.swift:77` —
  `public static let all: Filter = Filter()`.
- `Sources/Linter Primitives/Lint.Filter.swift:81` —
  `public static func including(_:) -> Filter`.
- `Sources/Linter Primitives/Lint.Filter.swift:87` —
  `public static func excluding(_:) -> Filter`.
- `Sources/Linter Primitives/Lint.Filter.swift:109` —
  `public func matches(sourcePath:) -> Swift.Bool`.
- `Sources/Linter Primitives/Lint.Visibility.swift:38` —
  `public static func < (lhs:rhs:) -> Bool`.
- `Sources/Linter Primitives/Lint.Visibility.swift:45` —
  `public var ordinal: Swift.Int` (computed).

#### B2. Compound identifier renames (7 findings — split disposition)

| Site | Identifier | Disposition |
|------|------------|-------------|
| `Lint.Configuration.swift:85` | `disabledRuleIDs` (property) | **DEFER-FOR-CONSISTENCY** — load-bearing across the public DSL surface; rename cascades to consumers. Revisit when configuration surface stabilizes. |
| `Lint.Configuration.swift:123` | `effectiveRules()` | SOURCE-WRONG: rename to `rules` returning the resolved list, with the unresolved storage renamed to `_rules` or similar. Touches public surface. |
| `Lint.Configuration.swift:147` | `effectiveDisabledRuleIDs()` | SOURCE-WRONG: rename per the same scheme. |
| `Lint.Rule.Composition.swift:45` | `withDefaultSeverity(_:)` | **POTENTIAL RULE-WRONG**: `with` is a common stdlib idiom (`withCheckedContinuation`, `withUnsafeBufferPointer`) for transform-returning combinators. Consider amending `[API-NAME-002]` to add `with` to the boolean-prefix-style carve-out list. Otherwise SOURCE-WRONG: restructure as `Lint.Rule.Severity.withDefault(_:)`. |
| `Lint.Rule.Composition.swift:58` | `pinnedToSeverity(_:)` | SOURCE-WRONG: rename to `pinned(toSeverity:)` or restructure as `severity.pinned(_:)`. |
| `Lint.Rule.swift:63` | `defaultSeverity` (property) | **DEFER-FOR-CONSISTENCY** — semantically distinct from "current severity" (which the engine resolves at run time). Rename loses precision. Consider amendment to allow `default` as a prefix marker. |
| `Lint.Visibility+Effective.swift:69` | `ownModifiers(of:)` | SOURCE-WRONG: rename to `modifiers(of:)`. `@usableFromInline static` declared in extension. |

---

## Disposition — swift-linter (148 findings)

### RULE-WRONG (10 findings → carries A1, A2 from above + A3)

#### A1+A2 carry (10 findings)

- API-IMPL-008 @Suite carve-out gap fires on the four test
  files (`Lint.Driver Tests.swift:20`, `Lint.SingleFile.Extractor Tests.swift:18`,
  `Lint.SingleFile.Materializer Tests.swift:18`,
  `Lint.Suppression Tests.swift:24`, ...) — same shape as A1.
- PATTERN-017 raw-value-access fires on:
  - `Sources/Linter Reporter SARIF/Lint.Reporter.SARIF.swift:106` —
    `Diagnostic.Severity.RawValue` access (need to verify this is enum
    raw value vs Tagged).
  - `Sources/Linter Reporter Text/Lint.Reporter.Text.swift:84` — same.
  - `Sources/Linter Core/Lint.Suppression.swift:140` — needs site
    inspection.
  - `Sources/Linter Core/Lint.Source.Parsed+Visibility.swift:71` —
    `private` visibility, may be carved out by visibility-scope
    amendment if applied.
  - `Tests/Linter Core Tests/Lint.Reporter Tests.swift:70, 101` —
    test-side enum raw-value access.

#### A3. SWIFT-TEST-002 vs compound names *inside* extension-pattern @Suite (4 findings)

**Sites**:
- `Tests/Linter Core Tests/Lint.Driver Tests.swift:20` —
  `@Suite struct ConfigurationFromManifest {}`
- `Tests/Linter Core Tests/Lint.SingleFile.Extractor Tests.swift:18`
- `Tests/Linter Core Tests/Lint.SingleFile.Materializer Tests.swift:18`
- `Tests/Linter Core Tests/Lint.Suppression Tests.swift:24, 162`

**Defect or feature?** The rule message emphasizes the
*extension-pattern* — `extension Foo { @Suite struct Test {} }` — but
the recognizer fires on any `@Suite`-attributed type whose name is
compound (e.g., `ConfigurationFromManifest`). The author IS using
the extension-pattern; the *inner* nested suite name is compound.

Two readings:

1. **SOURCE-WRONG**: rule is correctly enforcing non-compound names
   even on inner @Suite types. Fix: rename
   `ConfigurationFromManifest` → extension-nest as
   `extension Lint.Driver.Test.Configuration { @Suite struct FromManifest {} }`.
2. **RULE-WRONG (less likely)**: rule should only apply to top-level
   @Suite types where the test would have been named `FooTests`.
   The naming `ConfigurationFromManifest` inside a `Test` namespace
   is structurally fine.

Recommended: SOURCE-WRONG. The nested-extension restructure aligns
with the [API-NAME-002] convention applied uniformly. Inner test-suite
names benefit from the same nest-and-name discipline as production
code.

### SOURCE-WRONG (138 findings → multiple categories)

The swift-linter source surface has substantial real engineering
debt surfaced by the dogfeed. Categorized by rule family with
representative sites; see the raw findings log at
`/tmp/dogfeed-linter.stdout.log` for the complete enumeration.

#### B3. Untyped throws migration (20 findings) — [API-ERR-001]

- `Sources/Linter CLI/Linter CLI.swift:61` (and others)
- Multiple sites in `Lint.Driver.swift`, `Lint.Manifest.swift`,
  `Lint.SingleFile.swift`, `Lint.SingleFile.Materializer.swift`,
  `Lint.SingleFile.Extractor.swift`

Mechanical fix shape: convert `throws` → `throws(SpecificError)`. Each
site requires identifying the union of error types thrown by the
function body and (commonly) introducing a typed error enum at the
call site or upstream.

**Note**: typed-throws conversion is a documented in-flight cross-repo
arc (per `MEMORY.md typed-throws-conversion.md`); the swift-linter
sites should fold into that arc rather than open a parallel commit
chain.

#### B4. `do throws for typed catch` (13 findings) — [IMPL-075]

Companion to B3. Bare `do { try ... } catch { }` erases the
concrete error type. Fix shape:
`do throws(E) { try ... } catch let e { }`. Many sites are
`Lint.Driver.swift`, `Lint.Manifest.swift`, `Lint.SingleFile.swift`.

#### B5. `try optional` (11 findings) — feedback_prefer_typed_throws_over_try_optional

`try?` swallows the typed error. Fix shape: convert to typed
`do/catch` with explicit discard. Sites: `Linter CLI.swift:84, 107,
148`, `Lint.Driver.swift:128, 131`, etc.

**Note**: feedback memory cites past Linux hot-spin incident
(EAGAIN swallowed by `try?`). Real defensive fix.

#### B6. `usable from inline internal import` (9 findings) — [PATTERN-055]

Sites: `Lint.SingleFile.swift:12-18`, `Lint.SingleFile.Materializer.swift:12-13`.

These are file-headers pairing `@usableFromInline` decls with
`internal import` of referenced modules. Fix: either downgrade the
declarations' visibility or upgrade the imports to `public` /
`package`. Mechanical but requires per-file inspection to choose.

#### B7. Compound type name (9 findings) — [API-NAME-001]

Sites: `Linter CLI.swift:23` (`Linter CLI` type name itself),
`Lint.Run.ExitPolicy.swift:23` (`ExitPolicy`),
`Lint.SingleFile.PackageDependency.swift:27` (`PackageDependency`),
`Lint.SingleFile.swift:59` (one site), and 5 test sites.

Fix shape: nested form per `[API-NAME-001]`. E.g., `ExitPolicy`
→ `Lint.Run.Exit.Policy`. `PackageDependency` →
`Lint.SingleFile.Package.Dependency`. These are structural API
surface changes; cascade to consumers.

**DEFER-FOR-CONSISTENCY** for `Linter CLI` (the executableTarget name
is package-product-bound; renaming touches Package.swift).

#### B8. Compound identifier (43 findings) — [API-NAME-002]

The largest category. Sites concentrated in `Lint.Driver.swift`,
`Lint.SingleFile.Extractor.swift`, `Lint.SingleFile.Materializer.swift`,
`Lint.Manifest.swift`, `Lint.Run.swift`. Each requires per-site
judgment (rename vs nested-accessor restructure vs DEFER).

**Recommended approach**: defer the large compound-identifier sweep
to a dedicated dispatch — it touches API surface across the engine
and benefits from consolidated review. The numerics dispatch
processed ~189 findings; this is similar scale (43 findings × ~3
files = manageable single-dispatch).

#### B9. Counter loop iteration (3 findings) — [IMPL-033]

Sites: `Lint.Run.swift:216`, `Lint.SingleFile.Materializer.swift:264`,
`Lint.SingleFile.swift:123`.

Fix shape: replace `for i in 0..<n { ... }` with `array.forEach { ... }`
or `array.indices.forEach { ... }`. Mechanical.

#### B10. Int public parameter (3 findings) — [IMPL-010]

Sites: `Lint.Suppression.swift:75, 89, 99`. Public functions taking
bare `Int`. Fix shape: introduce typed wrapper (Index/Ordinal/Cardinal).

#### B11. Result wrapper for rethrows shim (2 findings) — [IMPL-109]

Sites: `Lint.run.swift:87`, `Linter CLI.swift:122`. Adapt
stdlib-rethrows higher-orders via `Result<T, E>` shim.

#### B12. Count minus one (2 findings) — [INFRA-200]

Sites: `Lint.Suppression.swift:207, 221`. Replace `seq.count - 1`
with typed alternative or named idiom.

#### B13. Pointer advanced by (1 finding) — [IMPL-011]

Site: `Lint.Suppression.swift:175`. Wrap `.advanced(by:)` in a typed
`pointer(at:)` primitive.

#### B14. Inlinable internal access (1 finding) — [PATTERN-052]

Site: `Lint.SingleFile.swift:104`. Pair `@inlinable` with
`@usableFromInline` or upgrade visibility.

#### B15. Unchecked call site (2 findings)

Sites need site inspection.

---

## Recommended Disposition Sequence

### This dispatch (Phase C.1 + C.2)

1. **Land B1** (move-to-extension API-IMPL-008 for swift-linter-primitives
   sources) — 9 findings, mechanical, well-scoped, full build/test
   verification per repo.
2. **Land B2 partial** (rename `ownModifiers` → `modifiers`) — single
   safe rename. Keep other compound-identifier renames for next
   dispatch (require API-surface judgment).
3. **Surface this triage doc** as the RULE-WRONG record (covers A1,
   A2, A3 as amendment threads).
4. **Halt at clean boundary**.

### Next dispatch shape (recommended)

- **Thread A**: amend `Lint.Rule.Structure.MinimalTypeBody`
  + `Lint.Rule.Naming.*` to add `@Suite` to the carve-out
  predicate. Closes A1 (11 findings across both packages).
- **Thread B**: amend `Lint.Rule.Structure.RawValueAccess` to skip
  Swift `enum.rawValue` per the receiver-name-disambiguation strategy
  (Option 2 above). Closes A2 (4 + ~6 findings).
- **Thread C**: typed-throws sweep on swift-linter
  (folds B3 + B4 + B5 — collectively ~44 findings — into the existing
  cross-repo typed-throws arc per `typed-throws-conversion.md` memory).
- **Thread D** (after C): compound-identifier sweep on swift-linter
  (43 findings, requires API-surface review — separate from the
  typed-throws arc).
- **Thread E** (parallel): rule-pack repos dogfeed (deferred per
  HANDOFF.md Open Question 1 until @Suite carve-out lands).

The rule-pack dogfeed thread is gated on Thread A; the API-IMPL-008
@Suite carve-out gap will dominate the rule-pack test footprints
otherwise.

---

## Cross-references

- `swift-foundations/swift-linter-rules/Research/numerics-secondary-rule-defects-2026-05-12.md`
  v1.1.0 — taxonomy precedent
- `swift-foundations/swift-linter/Research/2026-05-12-eval-path-self-reference-unfinished.md`
  v1.0.0 DEFERRED — companion deferred thread
- `swift-foundations/swift-linter-rules/Research/numerics-rule-recognizer-2026-05-12.md`
  — Bundle hierarchy / consumer-side recognizer architecture
- `swift-institute/Research/three-tier-linter-rules-partition.md`
  — bundle taxonomy
- HANDOFF.md (this dispatch) — Open Questions 1, 2, 3
