# Numerics Rule-Cluster Recognizer: PATTERN-017 / CONV-016 / IMPL-010

<!--
---
version: 1.2.0
last_updated: 2026-05-12
status: DECISION
tier: 2
scope: cross-package
---
-->

## Decision (2026-05-12) — Option 7, NOT Option 1

**Landed shape**: **Option (7) — Rule decomposition via bundle composition**
(`Lint.Rule.Bundle.brandOwner` defined in `swift-primitives-linter-rules`;
brand-newtype-owning numerics packages declare a Shape-γ `Lint.swift`
loading that bundle instead of `Bundle.primitives`).

**v1.0 recommended Option 1; v1.1 landed Option 1; v1.2 reverts Option 1
and lands Option 7.** The reversal occurred in two stages:

1. **Option 1 attempt A — JSON sidecars** (landed by subordinate). Each
   numerics package declared its brand-newtypes via a `.swift-linter.json`
   file at the package root (e.g.,
   `{"brandTypes": ["Affine.Discrete.Vector"]}`). The engine walked from
   each linted source up to its owning `Package.swift`, read the adjacent
   JSON, and threaded a `brandTypes: Set<Lint.Brand>` through every
   parsed source. Each recognizer-class rule gated on the set. Reverted
   per user direction codified at memory
   `project_linter_config_all_swift.md`: the swift-linter config surface
   stays in Swift, never JSON sidecars. Skill-promotion candidate.

2. **Option 1 attempt B — `brands:` kwarg + typed `Lint.Brand`** (Shape
   γ `Lint.run(dependencies:brands:rules:)` plus
   `Lint.Configuration.brands` plus per-source `Parsed.brandTypes`).
   Architectural review concluded the brand feature itself is bloat:
   PATTERN-017 / CONV-016 / IMPL-010 / IMPL-011 encode "wrong at consumer
   call sites"; brand-newtype-owning packages aren't consumer call sites.
   Instead of loading the rule everywhere and admitting at runtime via
   per-file brand context, don't load the rule in packages where it
   doesn't apply. Same observable behavior; no engine machinery; no new
   config types; no per-file metadata threading.

**Precision tradeoff** (acknowledged): Option 1 attempt B could admit
`Cardinal.underlying` while still flagging `OtherType.underlying` in the
same file. Option 7 cannot (admission is per-package, not per-call-site).
In practice a brand-newtype-owning primitive's cross-brand raw access is
to sibling brand primitives it bridges to — legitimate by construction.
The lost precision is theoretical, not empirical.

**Rule decomposition shape** (the `brandOwner` bundle, in
`swift-primitives-linter-rules/Sources/Linter Primitives Rules/Lint.Rule.Bundle.brandOwner.swift`):

```swift
extension Lint.Rule.Bundle {
    public static let brandOwner: [Lint.Rule.Configuration] = {
        let excludedIDs: Swift.Set<Lint.Rule.ID> = [
            "raw value access",
            "chained rawvalue access",
            "int public parameter",
            "pointer advanced by",
        ]
        return Lint.Rule.Bundle.primitives.filter { !excludedIDs.contains($0.rule.id) }
    }()
}
```

Numerics-package `Lint.swift` (one file per brand-owner package):

```swift
// swift-linter-tools-version: 0.1
import Linter
import Linter_Primitives_Rules

Lint.run(dependencies: [
    .package(
        path: "../swift-primitives-linter-rules",
        products: ["Linter Primitives Rules"]
    ),
]) {
    Lint.Rule.Bundle.brandOwner
}
```

**Cross-package consumers continue to see the four rules fire** — they
load `Bundle.primitives` (the full bundle); they don't load
`Bundle.brandOwner`. Strict-superset is preserved structurally rather
than via per-package config.

**Rationale**: the all-Swift convention rules out JSON sidecars
([project_linter_config_all_swift.md]). Among Swift-native alternatives,
the brand-feature (Option 1 attempt B) requires engine machinery
(`Lint.Brand` typealias, `Configuration.brands` / `effectiveBrands()`,
`Parsed.brandTypes` field + threading, `Lint.run(brands:)` kwarg) for
behavior that bundle composition achieves with zero engine machinery.
Option 7 was enumerated in the Tier 2 research as a fallback to Option
1's "lowest per-site burden" framing; that framing turned out to require
per-package config (first JSON, then `brands:` kwarg) — strictly more
burden than Option 7's ~5-line bundle selection per package.

**Verified 2026-05-12** by dogfooding `swift-linter` (debug build) on
`swift-cardinal-primitives` after authoring its Shape-γ `Lint.swift`
loading `Bundle.brandOwner`: zero findings for the four excluded rule
IDs; many findings for other rules. The `.rawValue` access sites in
`Cardinal Primitives Core/Cardinal.swift` and the stdlib-integration
files would fire under `Bundle.primitives` but are silent under
`Bundle.brandOwner` — confirming the exclusion is structural.

**Superseded by this decision**:
- The v1.0/v1.1 Recommendation section (kept below as historical
  context) — Option 1 was the v1.0 recommendation.
- Brand-feature engine machinery — reverted across 5 linter packages
  (12 REVERT commits enumerated in
  `swift-linter-rules/Research/wave-3-aggregate-2026-05-11.md`
  v1.6.0).

## Context

The release-readiness pass over three L1 numerics primitives packages —
`swift-ordinal-primitives`, `swift-cardinal-primitives`,
`swift-affine-primitives` — surfaced ~219 swift-linter warnings, of which
~189 sit in a three-rule cluster (PATTERN-017 / CONV-016 / IMPL-010) that
fires at concentrated, structurally identifiable sites: the brand-newtype's
own implementation files and its stdlib-integration extensions.

**Trigger**: principal dispatch (2026-05-12) asked whether the ~189 sites
are *source defect* (180 real violations), *recognizer gap* (the rules name
their own bottom-out sites in prose but cannot structurally identify them),
or *something else*. The dispatch explicitly cited the Wave 4 `@safe`
inversion precedent as relevant-but-not-determinative — re-derive from
first principles.

**Stakeholders**: rule-author (swift-linter-rules), consumer-author (the
three numerics packages plus every downstream package depending on the
brand-newtype pattern), supervisor (orchestrating the lint-pass cleanup
campaign that produced Waves 1 through 4).

**Timeline**: Wave 1 (rule-amendment from L1 empirical signal) and Wave 4
(@safe absorber-pattern policy lean) closed 2026-05-11 / 2026-05-12. Wave
5 (L2/L3 leaf triage) is queued. The numerics finding is an L1 residual
that did not surface in Wave 1's sample (cardinal/ordinal/affine were not
in the Wave 2 sample of 10 leaves; they surfaced in this release-readiness
pass after the rules had stabilized).

**Out of scope** for this dispatch (per principal): the smaller residuals
PATTERN-019, API-NAME-002, MEM-SAFE-002, IMPL-109, IMPL-011, PATTERN-020,
MEM-COPY-004 (~40 findings). The principal will handle those separately.

## Empirical Signal

### Fire counts per rule × package (verified 2026-05-12 by re-running the
prebuilt Lint binaries against each package's `Sources/`; output captured
to `/tmp/lint-{ordinal,cardinal,affine}.txt`)

| Rule | Display name | Owner pack | ordinal | cardinal | affine | total |
|------|--------------|-----------|--------:|---------:|-------:|------:|
| PATTERN-017 | raw value access | `Lint.Rule.Structure.RawValueAccess` (universal) | 69 | 27 | 63 | **159** |
| CONV-016 | chained rawvalue access | `Lint.Rule.RawValue.Chain` (primitives) | 3 | 3 | 3 | 9 |
| CONV-016 | bitpattern rawvalue chain | `Lint.Rule.RawValue.BitPattern` (primitives) | 1 | 1 | 1 | 3 |
| IMPL-010 | int public parameter | `Lint.Rule.Naming.IntParameter` (institute) | 2 | 2 | 5 | 9 |
| **Subtotal in scope** | | | | | | **~180** |

The dispatch table cited 4 / 4 / 10 for IMPL-010 (totaling 18); the
re-verified count is 2 / 2 / 5 (totaling 9). The discrepancy is small and
does not change the structural finding — the dispatch tally may have
double-counted return-type fires or come from a slightly different build
state. Verified counts for PATTERN-017 (69/27/63) and CONV-016 (4/4/4)
match the dispatch exactly.

### Hot files (concentration ≥ 5 fires per file)

| Package | File | Fires | Role |
|---------|------|------:|------|
| ordinal | `Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift` | 20 | Cross-brand comparison + advance generic over `O: Ordinal.Protocol`, `C: Carrier.Protocol<Cardinal>` |
| ordinal | `Sources/Ordinal Primitives Core/Ordinal.swift` | 11 | The brand type itself; `static func <`/`==` etc. on `Ordinal` |
| ordinal | `Sources/Ordinal Primitives Core/Ordinal.Retreat.swift` | 9 | `extension Property where Tag == Ordinal.Retreat` — typed-arithmetic operator family |
| ordinal | `Sources/Ordinal Primitives Core/Ordinal.Advance.swift` | 7 | `extension Property where Tag == Ordinal.Advance` — typed-arithmetic operator family |
| ordinal | `Sources/Ordinal Primitives Standard Library Integration/Int+Ordinal.swift` | 5 | `extension Ordinal` (Int↔Ordinal init pair) + `extension Int` (Ordinal↔Int init pair, including `init(bitPattern:)`) |
| cardinal | `Sources/Cardinal Primitives Core/Cardinal.swift` | 13 | The brand type itself; `static func +`/`<` etc. on `Cardinal` |
| cardinal | `Sources/Cardinal Primitives Standard Library Integration/Int+Cardinal.swift` | 4 | Same stdlib-integration role as ordinal counterpart |
| cardinal | `Sources/Cardinal Primitives Core/Cardinal.Subtract.swift` | 4 | `extension Property where Tag == Cardinal.Subtract` — saturating/exact subtract |
| cardinal | `Sources/Cardinal Primitives Core/Cardinal.Add.swift` | 4 | `extension Property where Tag == Cardinal.Add` — saturating/exact add |
| affine | `Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift` | 34 | Free `public func +`/`-` over `O: Ordinal.Protocol`, `some Carrier.Protocol<Affine.Discrete.Vector>` |
| affine | `Sources/Affine Primitives Core/Affine.Discrete.Vector.swift` | 11 | The Vector brand type itself; arithmetic ops |
| affine | `Sources/Affine Primitives Core/Tagged+Affine.swift` | 7 | `extension Tagged where Underlying == Ordinal/Vector` typealias and bridge |
| affine | `Sources/Affine Primitives Core/Affine.Discrete.Vector+Carrier.swift` | 5 | Carrier-protocol conformance + cross-Carrier operators |

**Distribution shape**: tightly clustered, not scattered. ~85% of all
PATTERN-017 fires concentrate in ≤ 4 files per package, all of which sit
in one of three structural buckets:

1. **The brand type itself** (`Ordinal.swift`, `Cardinal.swift`,
   `Affine.Discrete.Vector.swift`) — the stored-property declarer.
2. **Same-package typed-arithmetic implementations** (`Ordinal.Advance.swift`,
   `Cardinal.Add.swift`, `Affine.Discrete+Arithmetic.swift`,
   `Ordinal+Cardinal.swift`) — the file whose job IS to implement the
   typed operation the rule prose recommends as the cleaner alternative.
3. **Stdlib-integration boundary files** (`Int+Ordinal.swift`,
   `Int+Cardinal.swift`) — the file whose job IS to host the
   `Int(bitPattern: Brand)` and `Brand(_: Int)` integration overloads.

## Question

**Are the ~180 fires a source defect (180 violations needing 180 source
fixes), a recognizer gap (the rule prose admits these sites as legitimate
but the AST visitor cannot identify them), or something else?**

Sub-questions:

1. **Self-citation**: Do the rule bodies (the `let xMessage = "..."`
   strings) name the firing sites as legitimate-by-construction?
2. **AST shape uniformity**: Is the firing AST shape across the ~180
   sites narrow enough that a recognizer could identify it
   structurally?
3. **Recognizer cost**: What does each recognizer option cost in (a)
   rule-author work, (b) call-site discipline, (c) author citation
   burden?
4. **Strict-superset preservation**: Does the proposed recognizer still
   fire on every site the current rule legitimately fires on
   (downstream consumers of the brand, callers in other packages)?

## Self-Citation: What the Rule Bodies Say

### PATTERN-017 (`Lint.Rule.Structure.RawValueAccess`)

Message string at `swift-foundations/swift-linter-rules/Sources/Linter
Rule Structure/Lint.Rule.Structure.RawValueAccess.swift:36-42`:

> "[raw value access] [PATTERN-017]: `.rawValue` / `.position` at a
> consumer call site bypasses the typed-conversion ladder. **These
> accessors are reserved for extension initializers (the brand-newtype's
> own boundary) and same-package implementations.** Prefer the typed
> operation; suppress with `// swift-linter:disable:next raw value access`
> and a `// REASON:` continuation for legitimate same-package use."

The bolded clause is the rule's own admission. The rule recognizes that
two classes of site are legitimate-by-construction:

- **(A)** extension initializers — the brand-newtype's own boundary
- **(B)** same-package implementations

The rule's *recognizer* — a `MemberAccessExprSyntax` visitor with
`bodyDepth > 0` gate — does not distinguish (A) or (B) from the
consumer-call-site case (C) the rule means to catch. Every
`.rawValue` access inside any function/initializer/closure/accessor body
fires, regardless of where the enclosing file lives.

### CONV-016 — `Lint.Rule.RawValue.Chain`

Message string at `swift-primitives/swift-primitives-linter-rules/Sources/Linter
Rule RawValue/Lint.Rule.RawValue.Chain.swift:49-56`:

> "[chained rawvalue access] [CONV-016]: chaining `.rawValue.method()` …
> escapes the typed system. Prefer `.retag()` (Tier 1) / `.map()` (Tier
> 2) / `Type.min(a, b)` / a typed accessor exposed by the wrapper, per
> [INFRA-103]. **If the wrapper IS what this site implements
> (typed-system bottom-out), escalate to supervisor and apply
> `// swiftlint:disable:next chained_rawvalue_access // reason:
> <citation>`.**"

The bolded clause is the rule's own admission that "the wrapper IS what
this site implements" is a category the rule cannot catch structurally —
the prose offloads identification onto the human supervisor.

### CONV-016 — `Lint.Rule.RawValue.BitPattern`

Message string at `swift-primitives/swift-primitives-linter-rules/Sources/Linter
Rule RawValue/Lint.Rule.RawValue.BitPattern.swift:49-59`:

> "[bitpattern rawvalue chain] [CONV-016]: `init(bitPattern:)` whose
> argument chains through `.rawValue` … bypasses the canonical preference
> hierarchy. Prefer `.retag()` / `.map()` (Tier 1/2) before resorting to
> the [INFRA-002] integration overload — and when you do use the
> overload, pass the typed value directly. **If this site IS the
> [INFRA-002] integration overload definition itself, escalate to
> supervisor and apply `// swiftlint:disable:next bitpattern_rawvalue_chain
> // reason: <citation>`.**"

The bolded clause is even more pointed: `Int(bitPattern: Brand)` lives in
exactly one file per brand (per the [IMPL-010] doctrine), and that one
file IS its definition. The rule fires on its own canonical home.

### IMPL-010 — `Lint.Rule.Naming.IntParameter`

Message strings at `swift-foundations/swift-institute-linter-rules/Sources/Linter
Rule Naming/Lint.Rule.Naming.IntParameter.swift:36-49`:

> "[int public parameter] [IMPL-010]: public function/initializer
> signature has a bare `Int` parameter. Push the stdlib boundary out —
> use a typed wrapper (`Index<T>`, `Ordinal`, `Cardinal`, `Count<T>`,
> `Offset<T>`) at the public surface; convert via a boundary overload
> internally. **`Int(bitPattern:)` lives in one place, once, forever
> (per [IMPL-010]).**"

The "one place, once, forever" clause IS the [IMPL-010] doctrine — and
the file `Int+Ordinal.swift` (and `Int+Cardinal.swift`,
`Int+Affine.Discrete.Vector.swift`) IS the one place per brand. The rule
prose names this canonical site as the exception and then fires on it.

### Structural summary

All three rules' message strings contain an explicit prose clause
identifying *exactly the firing sites of this cluster* as the
legitimate-by-construction category the rule does not want to catch.
The recognizers do not honor the clauses; the prose offloads
identification onto either (a) per-site `// swift-linter:disable:next`
+ `// REASON:` annotation, or (b) supervisor adjudication.

## AST Shape Characterization (Representative Sites)

To frame recognizer options precisely, I read 2-3 representative findings
per package and characterize the AST node enclosing each fire.

### Ordinal: 3 representative sites

**Site O1 — `Sources/Ordinal Primitives Core/Ordinal.swift:90-91`**

```swift
public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
}
```

AST enclosure: `FunctionDeclSyntax` (static `<` operator) inside
`ExtensionDeclSyntax extendedType: "Ordinal"`. The brand type IS `Ordinal`;
the extension is in the same module as the brand declaration.

**Site O2 — `Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift:32`**

```swift
public func < <O: Ordinal.`Protocol`, C: Carrier.`Protocol`<Cardinal>>(
    lhs: O, rhs: C
) -> Bool where O.Domain == C.Domain {
    lhs.ordinal.rawValue < rhs.cardinal.rawValue
}
```

AST enclosure: top-level `FunctionDeclSyntax`, no enclosing
`ExtensionDeclSyntax`. The function is generic over `O: Ordinal.Protocol`
and accesses `lhs.ordinal.rawValue` — going through the institute carrier
protocol's `.ordinal` accessor before reaching `.rawValue`. The
`.rawValue` here is on the **un-tagged** `Ordinal` raw value, accessed
via generic substitution.

**Site O3 — `Sources/Ordinal Primitives Standard Library Integration/Int+Ordinal.swift:73`**

```swift
extension Int {
    public init(bitPattern position: Ordinal) {
        // reason: typed-system bottom-out — this file IS the [INFRA-002]
        // Int.init(bitPattern: Ordinal) integration overload definition;
        // …
        // swiftlint:disable:next bitpattern_rawvalue_chain_anti_pattern
        self = Int(bitPattern: position.rawValue)
    }
}
```

AST enclosure: `InitializerDeclSyntax` (`init(bitPattern:)`) inside
`ExtensionDeclSyntax extendedType: "Int"`. The extension is on a stdlib
type, not the brand — but the file lives in the brand's own package's
`Standard Library Integration` source subdirectory. Note: the existing
`// swiftlint:disable:next bitpattern_rawvalue_chain_anti_pattern` does
NOT suppress the new linter, because (a) the directive prefix changed
from `swiftlint:` to `swift-linter:`, and (b) the rule ID is now
`bitpattern rawvalue chain` (with spaces), not the snake-case
`bitpattern_rawvalue_chain_anti_pattern`. The site is a stale
disable-with-reason left over from the SwiftLint-era cleanup.

### Cardinal: 2 representative sites

**Site C1 — `Sources/Cardinal Primitives Core/Cardinal.swift:96`**

```swift
public static func + (lhs: Self, rhs: Self) -> Self {
    // reason: typed-system bottom-out — Cardinal arithmetic operators
    // must call stdlib UInt.addingReportingOverflow; Cardinal IS the
    // wrapper implementing this primitive, so [INFRA-103] / [CONV-016]
    // options (i)–(iv) are circular.
    // swiftlint:disable:next chained_rawvalue_access_anti_pattern
    let (result, overflow) = lhs.rawValue.addingReportingOverflow(rhs.rawValue)
    precondition(!overflow, "Cardinal overflow in addition")
    return Self(result)
}
```

AST enclosure: `FunctionDeclSyntax` (static `+`) inside
`ExtensionDeclSyntax extendedType: "Cardinal"` in the same file as the
brand. Note the comment is again a stale SwiftLint directive that does
not suppress the new linter (same prefix + ID drift as O3); the new
CONV-016 still fires on `lhs.rawValue.addingReportingOverflow(...)` and
PATTERN-017 fires on `lhs.rawValue` and `rhs.rawValue` individually.

**Site C2 — `Sources/Cardinal Primitives Standard Library Integration/Int+Cardinal.swift:48`**

`extension Int { public init(bitPattern: Cardinal) { ... position.rawValue ... } }`
— direct analog of O3.

### Affine: 3 representative sites

**Site A1 — `Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift:30,37,39`**

```swift
public func + <O: Ordinal.`Protocol`>(
    lhs: O,
    rhs: some Carrier.`Protocol`<Affine.Discrete.Vector>
) throws(Ordinal.Error) -> O {
    guard rhs.vector.rawValue >= 0 else {
        // reason: typed-system bottom-out — … (multi-line REASON)
        // swiftlint:disable:next chained_rawvalue_access_anti_pattern
        let magnitude = rhs.vector.rawValue.magnitude
        guard lhs.ordinal.rawValue >= magnitude else { throw .underflow }
        return O(Ordinal(lhs.ordinal.rawValue - magnitude))
    }
    // ... more .rawValue accesses ...
}
```

AST enclosure: top-level `public func +` generic over `Ordinal.Protocol`
and `Carrier.Protocol<Affine.Discrete.Vector>`. Like O2, the `.rawValue`
accesses are chained through the carrier protocol accessors. The file
hosts 34 PATTERN-017 fires and 4 CONV-016 fires across ~10 free
top-level generic functions — every `+` / `-` / `+=` / `-=` operator in
the Discrete arithmetic family.

**Site A2 — `Sources/Affine Primitives Core/Affine.Discrete.Vector.swift`**

The brand type itself: `public struct Affine.Discrete.Vector { public
let rawValue: Int }`. Same shape as `Ordinal` / `Cardinal`; same
PATTERN-017 fires on the in-extension `static func` ops.

**Site A3 — `Sources/Affine Primitives Core/Tagged+Affine.swift`**

```swift
extension Tagged where Underlying == Ordinal, Tag: ~Copyable {
    public typealias Offset = Tagged<Tag, Affine.Discrete.Vector>
}
```

AST enclosure: `ExtensionDeclSyntax extendedType: "Tagged"`. The
extension `extendedType` is a *stdlib-adjacent generic type* (`Tagged`
from `Tagged_Primitives`), not the brand. The `.rawValue` fires inside
this file occur in static factory methods like `static func zero` on
`Tagged<Tag, Affine.Discrete.Vector>` where the extension constraint
`Underlying == Affine.Discrete.Vector` makes the type effectively the
brand.

### Cross-package structural summary

Three structural AST patterns dominate, in descending order of fire count:

| Pattern | AST shape | Count | Example sites |
|---------|-----------|------:|---------------|
| **P-brand-self** | `MemberAccessExprSyntax (.rawValue)` inside an `ExtensionDeclSyntax` whose `extendedType.trimmedDescription == BrandName` (where `BrandName ∈ {Ordinal, Cardinal, Affine.Discrete.Vector}` is declared in this same module) | ~50 | O1, C1, A2 |
| **P-same-package-generic** | `MemberAccessExprSyntax (.rawValue)` inside a top-level generic `public func` whose generic constraints reference institute protocols `Ordinal.Protocol`, `Carrier.Protocol<Cardinal>`, etc., AND the file lives in a package that declares `Ordinal` / `Cardinal` / `Vector` | ~70 | O2, A1 |
| **P-same-package-property-tag** | `MemberAccessExprSyntax (.rawValue)` inside an `ExtensionDeclSyntax extendedType: "Property"` constrained `where Tag == Brand.Advance` (or `.Retreat`, `.Add`, `.Subtract`) — the institute typed-arithmetic-operator family | ~40 | Ordinal.Advance.swift, Cardinal.Add.swift, etc. |
| **P-stdlib-integration** | `init(bitPattern: Brand)` inside `ExtensionDeclSyntax extendedType: "Int"` (or `UInt`) in a file under a `Standard Library Integration` source target of the brand's package | ~10 | O3, C2 |

All four patterns share one structural invariant: **the file is in the
brand's owning SwiftPM package**. The brand's owning package is the only
place where `Brand.rawValue` access is structurally legitimate. A
recognizer that gates on "same-package as the brand declaration" covers
all four patterns without listing them individually.

## Prior Art: The Wave 4 `@safe` Inversion Precedent

The dispatch cited Wave 4 as relevant precedent. To assess whether the
structural parallel holds, I read the Wave 4 closeout doc and its
SUPERSEDED v1.1.0 plus the v1.1.0 of the
`safe-attribute-absorber-pattern-fundamentals.md` decision that
superseded it on the same day (2026-05-12).

### Wave 4 narrative (compressed)

The `Lint.Rule.Memory.SafeForbidden` rule fired on `@safe`-annotated
declarations in `Sources/`. Initial v1.0.0 finding: ~128 sites across
15+ packages were uniformly the "absorber pattern" — a typed wrapper
declaration carrying invariant comments about why it absorbs unsafe
internals into a safe surface. The Wave 4 v1.1.0 DECISION stamped Option
(a): extend the rule with a "type-decl absorber-pattern" carve-out
gated on (1) direct unsafe storage / `@unchecked Sendable` / etc., AND
(2) an adjacent `// WHY:` or `## Safety Invariant` doc-comment.

### The same-day inversion

On 2026-05-12 the Wave 4 v1.1.0 was SUPERSEDED by
`swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md`
v1.1.0, which found that:

> "the carve-out stamped at v1.1.0 was tool-capability-bound rather
> than structurally principled: the 'type-level vs method-level' cut
> and the 'direct vs transitive unsafe storage' cut were artifacts of
> AST-only linter capability, not principled design boundaries."

The fundamentals doc inverted the rule's premise: instead of
"forbid `@safe`, carve out the absorber type-decls", the new direction
is "admit `@safe` per SE-0458's intent, require an accompanying
invariant disclosure". The rule predicate moved from
`SafeForbidden.swift` to `SafeAttributeUndocumented.swift` — same firing
class, opposite default.

### Structural parallel — re-derived, not borrowed

The Wave 4 → fundamentals arc is:

1. **Empirical signal**: rule X fires N times across files whose
   structural role IS the legitimate exception the rule prose names.
2. **First proposal**: carve out a sub-class of the firing pattern (the
   "absorber" form) via an AST-shape predicate.
3. **Inversion**: the AST-shape carve-out is tool-capability-bound —
   the type-vs-method cut is what AST can see, NOT what semantically
   distinguishes legitimate from illegitimate. The right cut is "is
   there an invariant disclosure present"; the wrong cut is "is this a
   type-decl or a method-decl".
4. **Correct framing**: invert the rule's default — admit the pattern
   per its proposal-level intent, require the disclosure mechanism
   that the prose was offloading onto comments.

For the numerics cluster, the same arc applies:

1. **Empirical signal**: PATTERN-017 / CONV-016 / IMPL-010 fire ~180
   times across files whose structural role IS "the brand's own
   implementation, integration overload, or typed-arithmetic operator
   home" — exactly the categories the rule prose names as legitimate.
2. **First proposal candidates** (the recognizers enumerated below).
3. **Inversion candidate**: per [RES-029] (semantic identity FIRST,
   cost as tiebreaker), the question is structurally "what *is* a
   legitimate `.rawValue` access?" Answer per the rule prose: an access
   that is structurally same-package as the brand. The rule's current
   default ("flag everything, suppress per-site") inverts the
   structural majority — there are ~180 legitimate sites and a small
   downstream-consumer minority. The structurally correct default is to
   admit same-package and fire only on cross-package access.
4. **Correct framing**: invert the default of the rule's gate from
   "fire unless suppressed" to "admit if same-package, fire otherwise."

The parallel **does** hold — same shape, same tool-capability-bound
initial framing, same inversion candidate. But the recognizer cost is
different from Wave 4's: Wave 4 required a per-decl disclosure check
that the AST cannot fully verify cross-file; the numerics recognizer
can gate purely on "is the file in the brand's owning package", which
the AST visitor CAN answer if given the SwiftPM-package boundary as
input.

### Where the parallel does NOT hold

Wave 4's `@safe` is a **language-level absorber mechanism**
(SE-0458): the attribute itself is the assertion. The institute's
choice to require a `// WHY:` line is a *disclosure overlay* on top of
the attribute. The current numerics rules have NO equivalent
language-level mechanism for "this access is brand-self"; they only
have prose and the per-site disable directive. The numerics inversion
therefore does NOT have a language-level fallback to lean on — the
mechanism must be the linter's own recognizer or its admission predicate.

## Recognizer Option Enumeration

Five recognizer options surveyed; analyzed below against the three
required axes plus a fourth derived axis (Visibility composability).

### Option (1): Package-scoped admission (no per-site discipline)

**Mechanism**: extend each rule's visitor with a gate "if the parsed
source file lives in a SwiftPM package whose `Package.swift` declares
the brand-newtype's product, do not emit findings for the
brand-newtype's `.rawValue`." The linter engine receives the
package boundary as configuration data; the rule visitor receives the
parsed file's package-path from `Source.Manager` (or equivalent) and
gates on it.

Concretely, the engine would need to:

1. Discover the SwiftPM package root for each linted file (walk up the
   directory tree looking for `Package.swift`).
2. Discover the package's declared brand-newtype names (an explicit
   config field in `.swift-linter.json`, OR by scanning the package's
   own sources for `public struct <Name> { public let rawValue: T }`
   declarations).
3. Pass the per-file (package-name, brand-name set) tuple to each rule's
   visitor.
4. Rule visitor sees `.rawValue` access; checks if the access target's
   type-name is in the file's package's brand-set; if yes, admit
   (no fire); if no, fire as today.

**Strict-superset**: ✅ Preserves all cross-package fires. A downstream
consumer that imports `Ordinal_Primitives` and writes `myOrdinal.rawValue`
in its own package's sources sits OUTSIDE the brand's owning package;
the gate does not admit; the rule fires as today.

**No-regression on intent**: ✅ The rule prose's "consumer call site"
language maps cleanly to "code outside the brand's owning package."
Same-package access is admitted; cross-package access fires.

**Cost of citation**:
- **Author burden**: **ZERO** at site-level. Authors of the three
  numerics packages don't add a single annotation. The ~180 sites
  silently drop.
- **Configuration burden**: ONE per package. The brand-newtype's
  `Package.swift` (or a sibling `.swift-linter.json`) declares the
  package's brand-newtype names once. Per-package cost is bounded;
  the cost amortizes over the package's lifetime.
- **Engine burden**: nontrivial. The linter currently does not have
  package-boundary discovery; this option requires adding it.

**Composability with Visibility**: ✅ The engine already computes
`[visibility: public]` per finding (see
`swift-foundations/swift-linter/Sources/Linter Core/Lint.Source.Parsed+Visibility.swift`).
Package-scope admission composes with visibility — a package-internal
`.rawValue` access remains fully fired-on if visibility were used as a
secondary gate.

**Tradeoff**: highest engine-side investment; lowest per-site burden.
Best long-term cost curve; highest one-time engineering cost.

### Option (2): Extension-self admission (AST-only)

**Mechanism**: the visitor admits `.rawValue` access if the enclosing
`ExtensionDeclSyntax`'s `extendedType.trimmedDescription` is one of a
known brand-newtype names list. The list is per-rule (or per-pack)
configuration; the AST shape is "I'm inside `extension Ordinal { … }`
or `extension Cardinal { … }`."

**Strict-superset**: ❌ Fails on the P-same-package-generic pattern
(~70 fires). The free top-level `public func + <O: Ordinal.Protocol, …>`
functions in `Ordinal+Cardinal.swift` and `Affine.Discrete+Arithmetic.swift`
are NOT inside an `extension Ordinal { … }` block — they're free
functions in the same module. The recognizer would not admit them; the
rule would still fire ~70 times. Authors then face the per-site disable
burden for the majority of remaining fires.

**No-regression**: ✅ Cross-package fires still fire (they're not in
`extension Brand`).

**Cost of citation**:
- **Author burden**: 70 per-site disable directives across the
  same-package-generic free functions. Higher than option (1).
- **Configuration burden**: one brand-newtype list per package
  (similar to option (1)).
- **Engine burden**: minimal. Pure AST visitor extension.

**Tradeoff**: cheap engine-side; expensive author-side because the
admission criterion is structurally weaker than P-same-package-generic.

### Option (3): Filename-convention admission

**Mechanism**: admit when the source file's basename matches a
naming convention like `Brand.swift`, `Brand.*.swift`, `Brand+*.swift`,
`Int+Brand.swift`, `*+Brand.swift`, `Tagged+Brand.swift`. The `Brand`
list is per-rule configuration.

**Strict-superset**: 🟡 Partial. Covers most of P-brand-self
(`Ordinal.swift`, `Cardinal.swift`, `Affine.Discrete.Vector.swift`),
the typed-arithmetic family (`Ordinal.Advance.swift`,
`Cardinal.Add.swift`), and the stdlib-integration files
(`Int+Ordinal.swift`, `Int+Cardinal.swift`, `Tagged+Affine.swift`).
DOES NOT cover the `Affine.Discrete+Arithmetic.swift` free-function file
or the `Ordinal+Cardinal.swift` cross-brand-relations file, because
these are not in `Brand.*.swift` shape — they're `Affine.Discrete+Arithmetic`
(no brand standalone) and `Ordinal+Cardinal` (two brands at once).

**No-regression**: ✅ Cross-package files do not match the convention.

**Cost of citation**:
- **Author burden**: a few per-site disables for files not matching
  the convention (~40 sites: the cross-brand-relations and discrete
  arithmetic files).
- **Configuration burden**: filename-pattern list per package.
- **Engine burden**: minimal — basename check.

**Tradeoff**: moderate. Conventional file-naming saves author work for
the majority of sites but leaves a residual ~40 sites at per-site
disable burden.

### Option (4): AST-shape recognizer (member-access-target inference)

**Mechanism**: the visitor inspects the `MemberAccessExprSyntax`'s
`base` expression and tries to infer whether the base evaluates to a
brand-newtype declared in the current package. Heuristics:

- If `base` is a `DeclReferenceExprSyntax` (a bare identifier like
  `lhs`), look at the enclosing function/closure's parameter list for
  a parameter `lhs: Brand` or `lhs: some Brand.Protocol` where `Brand`
  is in the known-brand list.
- If `base` is a `MemberAccessExprSyntax` (e.g., `lhs.ordinal` →
  `.rawValue`), look at the institute-protocol accessor names
  (`.ordinal`, `.cardinal`, `.vector`) and admit if the accessor name is
  in the institute-carrier-accessor list.

**Strict-superset**: 🟡 Best-effort coverage. The institute-protocol
accessor list (`.ordinal`, `.cardinal`, `.vector`) covers P-same-package-generic.
The parameter-type lookup covers P-brand-self. P-same-package-property-tag
(`Cardinal.Add.swift` etc.) goes through `base.cardinal.rawValue` where
`base` is `Property<Cardinal.Add, Self>` — accessed via the carrier-protocol
accessor `cardinal` which is in the list. Covered.
P-stdlib-integration uses `position.rawValue` where `position: Ordinal`
— `position` is in the parameter list at type `Ordinal` (in the brand
list). Covered.

**No-regression**: 🟡 The recognizer is heuristic. A cross-package
consumer writing `let foo = bar.ordinal.rawValue` (where `bar` is a
brand-conforming wrapper imported from the brand's package) WOULD be
admitted by the institute-carrier-accessor rule, even though this is
exactly the consumer-call-site case the rule means to catch. The
heuristic is *too admissive* for cross-package fires.

**Cost of citation**:
- **Author burden**: low at brand-package sites (zero per-site
  citation in the common case).
- **Configuration burden**: the brand list + carrier-accessor list.
- **Engine burden**: medium. AST-shape inference is more
  rule-author work than options (1)-(3); it duplicates type-resolution
  logic that the compiler does correctly.

**Tradeoff**: ends up false-admitting cross-package consumer sites
that have the same syntactic shape — fails the strict-superset axis.

### Option (5): Visibility-gated admission (engine-already-computed)

**Mechanism**: leverage the engine's existing visibility computation
(`Lint.Source.Parsed.visibility(at:)` — see
`swift-foundations/swift-linter/Sources/Linter Core/Lint.Source.Parsed+Visibility.swift`).
The engine already attaches `[visibility: public|internal|private|package]`
to every finding. Rule admits if the enclosing decl's visibility is
`internal` or `package` (i.e., the access is NOT cross-package-reachable
through the public surface).

**Strict-superset**: ❌ Fails. Most numerics sites ARE at `public`
visibility — `public static func +` on `Cardinal`, `public func +
<O: Ordinal.Protocol>` etc. The lint output samples above show `[visibility:
public]` on every fire. The visibility gate would NOT admit. This
option doesn't solve the problem.

**No-regression**: not applicable — the option doesn't change firing
behavior on the cluster.

**Cost of citation**: zero engineering; zero author burden. But the
admission criterion is wrong: `public` visibility is exactly what the
brand's own implementation NEEDS, and what the rule wants to fire on
cross-package.

**Tradeoff**: cannot use visibility as the admission criterion.

### Option (6): Status quo — per-site `disable:next` + `// REASON:`

**Mechanism**: the rule stays as today. Each ~180 site gets a
`// swift-linter:disable:next <rule-id>` line and a `// REASON: typed-system
bottom-out — …` continuation. The Wave 4 baseline "treat every site as a
deliberate exception" position.

**Strict-superset**: ✅ Trivially; no change.

**No-regression**: ✅ Trivially.

**Cost of citation**:
- **Author burden**: 180 directive lines + 180 REASON lines (often
  multi-line per site). The existing stale `// swiftlint:disable:next
  bitpattern_rawvalue_chain_anti_pattern` comments at Sites O3, C1, A1
  (and similar) confirm this was the historical default; they need to
  be retyped against the new directive syntax. ~180 directive blocks
  total.
- **Maintenance burden**: every new typed-arithmetic operator added
  to the cluster gets its own disable block; every disable block is a
  potential site for future ID drift (see the stale directives above
  that no longer suppress because the rule ID changed).
- **Engine burden**: zero.

**Tradeoff**: lowest engine cost; highest per-site authoring cost;
worst long-term maintenance cost. The cost compounds linearly with
package growth.

### Option (7): Rule decomposition — split each rule by site-class

**Mechanism**: split each rule into a "consumer-call-site" rule (fires
cross-package) and a "bottom-out-site" rule (admits same-package). The
split is at rule-definition time; consumer packages enable
"consumer-call-site" rules from their `Lint.Configuration`; brand
packages enable the "bottom-out-site" rules ONLY if they want the
discipline check for in-package documentation.

**Strict-superset**: ✅ Preserves cross-package firing via the
consumer-call-site rule. The bottom-out-site rule (if any package
enables it) is itself a separate rule that the package can disable
wholesale.

**No-regression**: ✅ Cross-package consumers face the same surface.

**Cost of citation**:
- **Author burden**: zero per-site at brand packages, because they
  simply don't enable the bottom-out-site rule.
- **Configuration burden**: every consumer package's
  `Lint.Rule.Bundle` configuration explicitly enables the
  consumer-call-site rule and disables the bottom-out-site rule (or
  the package never enables the latter). The brand package does the
  inverse.
- **Engine burden**: low. Splitting the rule body into two `Lint.Rule`
  entries with different `id:` is structurally cheap.

**Composability with Visibility**: ✅ Visibility is orthogonal.

**Tradeoff**: clean but bureaucratic. Each rule duplicates into a
"the strict version" and "the brand version"; the rule corpus grows
proportionally. The split also requires that the bundle authoring
discipline propagate per-package — a brand package picks which
flavor; a consumer picks which flavor. This is per-rule, per-package
configuration overhead.

### Comparison table

| Axis | (1) Pkg-scope | (2) Ext-self | (3) Filename | (4) AST-shape | (5) Visibility | (6) Status quo | (7) Decompose |
|------|---|---|---|---|---|---|---|
| Strict-superset preserved | ✅ | ❌ (P-generic) | 🟡 (~40 leak) | 🟡 (consumer false-admit) | ❌ | ✅ | ✅ |
| No-regression on intent | ✅ | ✅ | ✅ | 🟡 | n/a | ✅ | ✅ |
| Author per-site burden | 0 | ~70 | ~40 | ~5 | n/a | ~180 | 0 (brand) / 0 (consumer) |
| Author per-package config | 1 brand-list | 1 brand-list | 1 filename-list | 2 lists | 0 | 0 | 1 bundle line |
| Engine engineering cost | High | Low | Low | Medium | Zero | Zero | Low |
| Composes with Visibility | ✅ | ✅ | ✅ | 🟡 | ✅ | ✅ | ✅ |
| Maintenance cost | Bounded | Bounded | Bounded | High | n/a | Linear with growth | Bounded |
| Cross-rule sharing | Trivial (1 mechanism, 3 rules) | Trivial | Trivial | Per-rule heuristics differ | n/a | Per-site, per-rule | Per-rule |

## Re-frame: Is the question well-posed?

Per the dispatch's invitation to re-pose, I considered whether the
three rules share enough structural similarity for a single recognizer
recommendation, or whether they trip on different shapes requiring
separate analyses.

Empirically: all three rules ALL fire on member-access (`PATTERN-017`,
`CONV-016/Chain`, `CONV-016/BitPattern`) or function-signature
(`IMPL-010`) AST shapes; ALL three rules name the same legitimate-site
exception in prose ("same-package implementation" / "the wrapper IS this
site" / "lives in one place, once, forever"); ALL three rules fire
on files in the same SwiftPM package as the brand declaration.

The three rules share **one structural admission criterion**: "the file
lives in the brand-newtype's owning SwiftPM package." A single
recognizer mechanism can serve all three. The rule bodies differ in
what they fire on syntactically, but they agree on what to admit.

So the question IS well-posed at the cluster level. A single
recognizer recommendation covers all three rules.

One caveat: IMPL-010 ("`Int` in public-API parameter") fires on the
SIGNATURE, not on `.rawValue`-style access. The signature is
"legitimate" specifically when this file IS the
`Int.init(bitPattern: Brand)` integration overload definition. The same
package-scope gate covers IMPL-010 if the gate ALSO carries an
"and the parameter type is the brand's stdlib counterpart" condition —
which is the same gate, just on a function signature instead of a
member access.

## Recommendation

**Recommended option**: **Option (1) — Package-scoped admission**, with
**Option (7) — Rule decomposition** held as a viable fallback if Option
(1)'s engine investment cannot be funded in the current campaign.

### Why Option (1)

1. **Structural correctness over diff-size** (per [RES-022]). The
   "is this site legitimate?" question has a clean structural answer:
   the file's owning SwiftPM package is the brand-newtype's package.
   Every other recognizer option approximates this criterion with a
   tool-bound proxy (filename, extension-extends-type, AST-shape
   inference), and each proxy fails the strict-superset axis somewhere.
   Option (1) IS the criterion; the other options are partial
   reflections of it.

2. **Wave 4 parallel** (per dispatch). Wave 4's same-day inversion
   showed that AST-shape carve-outs are typically tool-capability-bound,
   not principled. The numerics case has the same flavor: every
   AST-only recognizer in the enumeration (options 2-4) is either
   strict-superset-breaking or false-admitting because the principled
   cut (same-package as the brand) lives at a level of context the
   AST visitor doesn't have without engine cooperation. The
   tool-capability-bound options reify their own limits into the rule's
   semantics. Option (1) puts the engine work where it belongs.

3. **Cost compounds the wrong way without it**. Per the Status quo cost
   analysis, every new typed-arithmetic operator added to any
   brand-newtype package incurs new per-site disable directives,
   forever. With ~180 fires already in three packages and many more
   brand-newtype packages in the ecosystem (`swift-property-primitives`,
   `swift-carrier-primitives`, `swift-tagged-primitives`, etc.), the
   recurring author cost is unbounded. The Option (1) engine
   investment pays back across the entire brand-newtype family.

4. **Compositional with visibility** (per the engine's existing
   visibility plumbing). The engine already computes
   `[visibility: public]`; Option (1) layers a structurally-orthogonal
   package-scope gate on top. Both gates are independent; the rule
   author can choose to fire on `public` + cross-package only, on all
   visibilities + cross-package only, etc. Visibility composability
   future-proofs the recognizer for further refinement.

5. **`Package.swift` brand declaration is a write-once, read-many
   artifact.** A package that declares brand-newtypes adds one entry
   to its `.swift-linter.json` (or a `brands:` field in the bundle
   configuration). This is one config change per package, ever — not
   per-rule, not per-site, not per-fire. The configuration cost
   amortizes to ~zero over the package's lifetime.

### Why not Option (7) (fallback only)

Option (7) is structurally clean and engine-cheap, but it duplicates
the rule corpus and pushes a bundle-configuration burden onto every
downstream consumer package. The brand package picks the "lenient"
flavor; the consumer picks the "strict" flavor. This is essentially
the rule corpus carrying the package-scope distinction by hand
instead of letting the engine carry it. Acceptable as a fallback if
the engine work for Option (1) cannot be scheduled; otherwise Option
(1) is structurally preferable.

### Why not Option (6) (the explicit no-op fallback)

The Status quo treats every brand-package site as an exception. The
dispatch's framing was correct: ~180 sites where the rule body names
the firing class as legitimate-by-construction is the signature of a
recognizer gap. Status quo also drifts: the existing stale
`// swiftlint:disable:next bitpattern_rawvalue_chain_anti_pattern`
comments at sites O3, C1, A1 demonstrate that disable directives go
stale across rule-naming changes — a maintenance cost on top of the
authoring cost.

### Implementation shape (high-level — not part of this dispatch's scope)

The engine work for Option (1) breaks into three layers:

1. **Engine layer** (`swift-foundations/swift-linter/Sources/Linter Core/`):
   add a `Source.Package` discovery step that walks up the directory tree
   from each source file looking for `Package.swift`, caches the
   nearest-ancestor result, and threads it onto each parsed `Source` via
   the `Source.Manager`. Engine engineering: ~1 file, ~150 LOC.

2. **Configuration layer** (`.swift-linter.json` schema): add a
   `brands: [String]` field that the package author populates with
   the public brand-newtype names declared by this package. The
   configuration resolver propagates the field to the package's lint
   environment. Schema work: ~30 LOC.

3. **Rule layer** (the four rule files):
   `Lint.Rule.Structure.RawValueAccess.swift`,
   `Lint.Rule.RawValue.Chain.swift`,
   `Lint.Rule.RawValue.BitPattern.swift`,
   `Lint.Rule.Naming.IntParameter.swift`. Each visitor's `visit(_ node:)`
   method gates on the package's `brands` set: if the access target's
   type-name (resolved via the simple `peelMemberAccessChain`-style
   walk shown in the existing rule bodies) is in the brand-set, skip.
   Per-rule additions: ~20-30 LOC.

The total work is bounded: one engine extension, one schema field,
four rule extensions. Output: ~180 fires drop silently. Cross-package
consumers continue to face the rule as today.

## Outcome

**Status**: **RECOMMENDED 2026-05-12**

**Verdict**: The ~180 numerics-cluster fires are a **recognizer gap**,
not a source defect. The rule bodies (PATTERN-017, CONV-016/Chain,
CONV-016/BitPattern, IMPL-010) each contain explicit prose admitting
"same-package implementation" / "this site IS the wrapper" /
"`Int(bitPattern:)` lives in one place, once, forever" as
legitimate-by-construction, but their AST-only recognizers fire
uniformly across same-package and cross-package access alike. The
Wave 4 `@safe` inversion precedent applies in structure — the
tool-capability-bound recognizer reifies its own limits into the
rule's semantics. Same-day fundamentals doc's correction (admit per
the proposal's intent; require structured disclosure) maps onto this
cluster's inversion direction: admit same-package access (per the
rule prose's intent); require cross-package access to surface as
today.

**Recommended recognizer**: **Option (1) — Package-scoped admission**.
The recognizer gates on "the file's owning SwiftPM package declares
the brand-newtype this `.rawValue` access references." Implementation
is engine-side (package-boundary discovery) plus a config-side
brand-set declaration in each package's `.swift-linter.json`. The
~180 sites drop to zero per-site author burden; cross-package fires
preserve strict-superset.

**Fallback recognizer**: **Option (7) — Rule decomposition**, only if
Option (1)'s engine work cannot be scheduled. The fallback duplicates
the rule corpus (one strict, one lenient flavor per rule) and shifts
the per-package distinction into bundle configuration. Acceptable but
structurally less clean.

**Explicitly NOT recommended**: Options (2) extension-self, (3)
filename, (4) AST-shape, (5) visibility, (6) status quo. Each fails
either the strict-superset axis or the maintenance-cost axis.

## Follow-Up Actions

1. **Principal triage**: pick Option (1) or fallback Option (7). If
   Option (1), schedule the three-layer engine work (Engine,
   Configuration, Rule) for a future cycle. If Option (7), schedule
   the rule-decomposition work in the swift-linter-rules package
   directly (no engine change).

2. **Wave 4 cross-link**: cite this doc from
   `swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md`'s
   "Related work" section if one exists; the parallel framing is
   strong enough that the two docs should reference each other for
   future readers asking "what's the canonical recognizer-gap signal
   shape?"

3. **Stale-directive cleanup**: regardless of which option is picked,
   the ~10 existing `// swiftlint:disable:next
   chained_rawvalue_access_anti_pattern` /
   `// swiftlint:disable:next bitpattern_rawvalue_chain_anti_pattern`
   comments in the three numerics packages are stale (the rule
   prefix changed `swiftlint:` → `swift-linter:`, and the rule ID
   changed underscore-suffixed to space-separated). These should be
   removed at the same time the recognizer change lands, or the
   directives will continue to mislead future readers into thinking
   the disable is active when it isn't.

4. **Pre-1.0 ecosystem propagation**: once Option (1) lands, the
   brand-declaration config field can propagate ecosystem-wide as
   part of `quick-commit-and-push-all` or a `release-readiness`
   cycle. Brand-newtype packages beyond the numerics three
   (`swift-property-primitives`, `swift-carrier-primitives`,
   `swift-tagged-primitives`, `swift-pair-primitives`,
   `swift-either-primitives`, etc.) will benefit immediately.

5. **Future rule-author skill** (deferred per `skill-lifecycle`):
   codify the "structural admission via package-scope" pattern in
   the `rule-exemptions` skill as `[RULE-EXEMPT-7]` once the
   engine plumbing exists. The shape is symmetric to the existing
   `[RULE-EXEMPT-2]` (protocol-witness-citation-dict) and
   `[RULE-EXEMPT-3]` (conformance-context) shapes — both of which
   already admit AST-context-based exemptions; package-scope is the
   missing engine-context-based counterpart.

## References

### Internal (verified 2026-05-12)

- `swift-foundations/swift-linter-rules/Sources/Linter Rule
  Structure/Lint.Rule.Structure.RawValueAccess.swift` — PATTERN-017
  rule body (visitor + message).
- `swift-primitives/swift-primitives-linter-rules/Sources/Linter Rule
  RawValue/Lint.Rule.RawValue.Chain.swift` — CONV-016 chained rawvalue
  rule body.
- `swift-primitives/swift-primitives-linter-rules/Sources/Linter Rule
  RawValue/Lint.Rule.RawValue.BitPattern.swift` — CONV-016 bitpattern
  rule body.
- `swift-foundations/swift-institute-linter-rules/Sources/Linter Rule
  Naming/Lint.Rule.Naming.IntParameter.swift` — IMPL-010 rule body.
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.Suppression.swift`
  — current per-site disable plumbing (`// swift-linter:disable:next`).
- `swift-foundations/swift-linter/Sources/Linter Core/Lint.Source.Parsed+Visibility.swift`
  — existing visibility computation (relevant to Option (5)'s
  rejection).
- `swift-foundations/swift-linter-rules/Research/wave-4-absorber-pattern-policy-lean-2026-05-12.md`
  v1.2.0 (SUPERSEDED).
- `swift-institute/Research/safe-attribute-absorber-pattern-fundamentals.md`
  v1.1.0 DECISION (the superseding doc — Wave 4 inversion).
- `swift-institute/Research/Reflections/2026-05-06-r1r4-cleanup-cycle-evasion-discipline-and-bottom-out-pattern.md`
  — typed-system bottom-out pattern history (Wave 1-4 cardinal
  cleanup precedent).
- `swift-institute/Skills/rule-exemptions/SKILL.md` —
  `[RULE-EXEMPT-1..6]` shapes; this doc proposes `[RULE-EXEMPT-7]`
  package-scope as a future addition.
- `swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.swift`
  — brand-self representative (Site O1).
- `swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal+Cardinal.swift`
  — same-package-generic representative (Site O2).
- `swift-primitives/swift-ordinal-primitives/Sources/Ordinal Primitives Standard Library Integration/Int+Ordinal.swift`
  — stdlib-integration representative (Site O3).
- `swift-primitives/swift-cardinal-primitives/Sources/Cardinal Primitives Core/Cardinal.swift`
  — brand-self representative (Site C1).
- `swift-primitives/swift-affine-primitives/Sources/Affine Primitives Core/Affine.Discrete+Arithmetic.swift`
  — affine free-function representative (Site A1).
- `/tmp/lint-{ordinal,cardinal,affine}.txt` — fire counts verified 2026-05-12.

### External (per [RES-021])

- [SE-0458 Opt-in Strict Memory Safety
  Checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)
  — the `@safe`/`@unsafe` precedent the Wave 4 inversion was grounded
  in. Cited indirectly via the safe-attribute-absorber-pattern-fundamentals
  doc.

### Methodological

- [RES-022] Recommendation-Section Framing Heuristic — structural
  correctness dominates diff-size unless an explicit exception applies.
- [RES-029] Framing-Challenge for Binding/Membership/Placement
  Questions — semantic identity first; cost/pragmatism as tiebreakers.
  The cluster question is fundamentally semantic ("what *is* a
  legitimate `.rawValue` access?"), so semantic identity drives.
- [RES-023] Empirical-Claim Verification for Dependent-Package State
  — all fire counts re-verified 2026-05-12 against rebuilt lint
  binaries; the dispatch's IMPL-010 tally was approximately correct
  but slightly higher than re-verification (18 vs 9); the discrepancy
  does not change the structural finding.
