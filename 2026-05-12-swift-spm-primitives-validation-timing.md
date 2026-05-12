# swift-spm-primitives Validation Timing

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

The parent design Research
(`2026-05-12-swift-spm-primitives-design.md` v1.0.0 RECOMMENDATION,
commit `14df127`) recommended `SwiftPM.Package.Name`,
`SwiftPM.Product.Name`, `SwiftPM.Target.Name` as **pure typealiases**
over `Tagged<_, Swift.String>` with no validation at construction.
The recommendation was structured as an outcome of Q5 in that doc,
but Q5's analysis is the briefest in the parent — the recommendation
is sound, but the open question deserves its own deep dive because
the choice has downstream consequences for every consumer that
constructs a `SwiftPM.*.Name` value.

This Research doc separates the validation-timing question from the
parent doc so it can be stamped DECISION independently — the parent
doc's other recommendations don't gate on this one and vice versa.

**Trigger**: open question #1 surfaced in the parent doc's Outcome
section ("confirm the typealias-without-validation shape is
acceptable, or specify a stricter validator").

**Internal research consulted per [HANDOFF-013] / [RES-019]**: same
corpus surveyed for the parent doc. Specifically:

- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28` — typealias-without-validation precedent
- `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern.swift` — validating-struct precedent
- `swift-primitives/swift-tagged-primitives/Research/sli-literal-vs-strideable-tradeoff.md` — SLI conformance gating

No prior research covers the SwiftPM-identifier validation-timing
question specifically — this is greenfield within the
swift-spm-primitives design space [Verified: 2026-05-12].

## Question

For the v1.0.0 types `SwiftPM.Package.Name`, `SwiftPM.Product.Name`,
`SwiftPM.Target.Name`, when should value validity be enforced?

The question is NOT "should we type-discriminate" (the parent doc
settled that — yes, via `Tagged<_, Swift.String>`). The question is
"at the moment a value of type `SwiftPM.Package.Name` is brought into
existence, what invariant does the type guarantee about the underlying
string?"

## Analysis

### Option A — Pure typealias (no validation at construction)

```swift
extension SwiftPM.Package {
    public typealias Name = Tagged<SwiftPM.Package, Swift.String>
}
```

**Description**: A plain typealias over `Tagged<Tag, U>`. Values
constructed via `Tagged(rawValue: "...")` (the unconditional Tagged
init) or via `let n: SwiftPM.Package.Name = "..."` (the SLI
`ExpressibleByStringLiteral` conformance). No validation runs at
construction; the type guarantees ONLY that the underlying string was
intended to refer to a SwiftPM package name.

**Advantages**:

- Matches `Lint.Rule.ID` precedent verbatim
  (`swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28`):
  the canonical institute pattern for typed string identifiers.
- Zero-cost construction; literal syntax via Tagged's SLI
  `ExpressibleByStringLiteral` conformance.
- Conformances inherited from `Tagged` without re-declaration
  (Sendable, Hashable, Equatable, Comparable, Codable,
  CustomStringConvertible).
- Compatible with the institute's space-bearing product-name
  convention (`"Manifest Primitives"`,
  `"Tagged Primitives Standard Library Integration"`) without
  forbidding them.
- Mirrors upstream SwiftPM's manifest-level rule (emptiness-only).

**Disadvantages**:

- Empty string is accepted at construction; the failure surfaces
  later (at SwiftPM build time, or wherever the value is consumed).
- Whitespace-only strings, control characters, and newlines are
  accepted; the type carries weaker guarantees than a "valid SwiftPM
  manifest-name" value should arguably carry.
- No `Error` type ships with the package; downstream consumers that
  WANT validation must layer their own validator.

**Constraints**: requires `swift-tagged-primitives` Tagged + SLI.

### Option B — Validating struct with throwing init

```swift
extension SwiftPM.Package {
    public struct Name: Sendable, Hashable, Equatable, Comparable, Codable, CustomStringConvertible {
        public let raw: Swift.String

        public init(_ name: Swift.String) throws(SwiftPM.Package.Name.Error) {
            // institute-defined validation rules
            guard !name.isEmpty else { throw .empty }
            guard !name.contains(where: \.isNewline) else { throw .containsNewline }
            // ... etc
            self.raw = name
        }

        public var description: Swift.String { raw }
    }
}

extension SwiftPM.Package.Name {
    public enum Error: Swift.Error {
        case empty
        case containsNewline
        // ...
    }
}
```

**Description**: A struct with a throwing init carrying typed throws.
Validation rules are institute-defined; failure produces a typed
error type per [API-ERR-001]. No `ExpressibleByStringLiteral` (or
optional, with `try!` semantics — see Option C variants).

**Advantages**:

- Fail-fast at construction; downstream code can rely on the type's
  invariants without re-validating.
- Typed errors per [API-ERR-001].
- Matches `Glob.Pattern` precedent shape
  (`swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern.swift`).
- Discoverable contract — readers see what makes a name valid by
  reading the init.

**Disadvantages**:

- Forbids the institute's own product-name convention if the rule
  rejects spaces. Without spaces forbidden, the only validator left
  that's meaningfully stricter than "non-empty" is rejecting control
  characters and newlines — which mostly catches programmer error
  rather than real-world malformed names.
- Loses literal construction (or requires `try!` shim — a footgun:
  `let n: SwiftPM.Package.Name = try! "..."` invites silent crashes
  on dynamic input).
- More code: struct + init + Error type + conformance declarations
  for each of the trio's types.
- Mismatches Lint.Rule.ID precedent (which is also a string
  identifier with no SwiftPM-specified validity rule).
- Mismatches upstream SwiftPM itself: upstream's manifest-level
  validators enforce only emptiness for `Package(name:)`, product
  name, and target name (see
  `2026-05-12-swift-spm-primitives-design.md` §Q4 for the upstream
  citations). Adding a stricter rule at the institute level over-
  applies validation where the spec itself doesn't.

**Constraints**: more code surface; loses literal ergonomics unless
combined with an `ExpressibleByStringLiteral` shim (which then needs
`try!` semantics, a known footgun).

### Option C — Hybrid (typealias + `.validate()` method)

```swift
extension SwiftPM.Package {
    public typealias Name = Tagged<SwiftPM.Package, Swift.String>
}

extension Tagged where Tag == SwiftPM.Package, Underlying == Swift.String {
    public func validate() throws(SwiftPM.Package.Name.ValidationError) {
        guard !rawValue.isEmpty else { throw .empty }
        // ...
    }
}

extension SwiftPM.Package.Name {
    public enum ValidationError: Swift.Error {
        case empty
        // ...
    }
}
```

**Description**: Typealias as Option A, plus an opt-in `.validate()`
method that throws if the value violates institute rules. Construction
is unvalidated; consumers explicitly call `.validate()` when they
want enforcement.

**Advantages**:

- Combines Option A's ergonomics with an explicit validation path
  for consumers that want it.
- Allows phased rollout: ship without `.validate()` in v1.0.0, add it
  in v1.1.0 if a consumer needs it.

**Disadvantages**:

- Dual-surface: two ways to "use" the type (validate vs not). New
  consumers must pick; downstream code reviewers must check which
  path was chosen.
- The institute's existing typed-string identifiers
  (`Lint.Rule.ID`, `Lint.Source.Path`) do NOT ship `.validate()`
  methods — adopting this pattern here without precedent creates a
  one-off shape.
- `.validate()` on a value that's already been constructed is
  conceptually awkward — validation usually happens BEFORE or AT
  construction, not after.
- Per [RES-022], dual-surface is a structural smell — the
  recommendation must justify why the dual surface is structurally
  correct rather than convenience-driven.

**Constraints**: requires either Option B style typed errors or a
new pattern; adds API surface without removing the Option A surface.

### Option D — Typealias at L1 + separate validating struct in v1.1.0+

```swift
// v1.0.0:
extension SwiftPM.Package {
    public typealias Name = Tagged<SwiftPM.Package, Swift.String>
}

// v1.1.0+ (only if a real consumer needs it):
extension SwiftPM.Package {
    public struct Name {
        public struct Strict: Sendable, Hashable, ... {
            public let underlying: SwiftPM.Package.Name
            public init(_ name: SwiftPM.Package.Name) throws(...) { ... }
            public init(_ raw: Swift.String) throws(...) { ... }
        }
    }
}
```

**Description**: Option A in v1.0.0; the package leaves space for a
companion `Strict` wrapping struct in a later version if a real
consumer needs enforcement. The Strict type wraps the unvalidated
typealias and adds the validation contract.

**Advantages**:

- v1.0.0 ships the minimum shape; the institute pays the validating-
  struct cost only when a real consumer requires it.
- Avoids over-design — per [RES-018]-style hurdle for new API
  surface (second-consumer demand).
- Preserves Option A's clean Lint.Rule.ID precedent fit.
- The eventual `Strict` type is a strictly additive extension; no
  breaking change.

**Disadvantages**:

- The institute publishes a typed primitive whose only contract is
  "this string is a SwiftPM package name" without enforcing that
  contract. Consumers might assume the typed wrapper validates; the
  doc must be clear that it does not.
- If a Strict variant lands later, two surfaces coexist — same
  dual-surface issue as Option C, but staged in time.

**Constraints**: same as Option A in v1.0.0; deferred design effort
for v1.1.0+.

### Comparison

**Criteria**:

1. Precedent fit (matches existing institute patterns)
2. Upstream-strictness alignment (what does SwiftPM itself enforce?)
3. Construction ergonomics (literal vs throwing init)
4. Type discrimination achieved
5. Compatibility with institute product-name convention (spaces)
6. Code surface volume at v1.0.0
7. Single-surface clarity (one way to use the type)
8. Future-proofing (can validate land later without breaking change?)
9. Audit-purpose fit (closes F-A2.11 / F-A3.4 / F-A3.5 in linter)

| Criterion | A (typealias) | B (validating struct) | C (hybrid) | D (typealias + later Strict) |
|-----------|:---:|:---:|:---:|:---:|
| Precedent fit (Lint.Rule.ID) | ✓ | ✗ | mixed | ✓ |
| Upstream-strictness alignment | ✓ (matches permissive tier) | ✗ (institute-stricter than upstream) | depends on rule choice | ✓ (v1.0.0) |
| Literal construction | ✓ | ✗ | ✓ | ✓ |
| Type discrimination | ✓ | ✓ | ✓ | ✓ |
| Compatible with institute spaces convention | ✓ | depends on rule choice | depends | ✓ |
| Code surface at v1.0.0 | minimal | moderate | moderate | minimal |
| Single-surface clarity | ✓ | ✓ | ✗ | ✓ at v1.0.0; mixed if Strict lands |
| Future-proofing (additive Strict) | ✓ | one-way (already structured) | ✗ (already dual-surface) | ✓ |
| Closes audit Defers | ✓ | ✓ | ✓ | ✓ |

**Theoretical grounding per [RES-022]**: the structural goal is type
discrimination at the manifest-identifier level. The closures the
audit identified (F-A2.11 / F-A3.4 / F-A3.5) need a typed
distinction between package names and product names, NOT validation
of the underlying string. All four options deliver type
discrimination; they differ on what additional contract the type
carries beyond discrimination.

**Empirical grounding per [RES-025] (cognitive dimensions)**:

| Dimension | A | B | C | D |
|-----------|:---:|:---:|:---:|:---:|
| Visibility (is the contract clear?) | weak (just discrimination) | strong (contract is the init) | mixed | weak at v1.0.0; clearer if Strict lands |
| Consistency (matches other institute IDs?) | ✓ | ✗ | ✗ | ✓ |
| Viscosity (cost to change later?) | low | high (struct → typealias is breaking) | high | low |
| Role-expressiveness (does the type say what it does?) | medium | high | medium | medium |
| Error-proneness (can construction silently produce a bad value?) | yes (e.g. empty string) | no | no (after .validate) | yes at v1.0.0 |
| Abstraction (over-abstracts vs under-abstracts?) | under | matches | over | under at v1.0.0 |

Option A under-abstracts in the error-proneness dimension; Option B
matches in error-proneness but over-applies relative to upstream's
own validation discipline. Option D is Option A at v1.0.0 with the
viscosity-low path to Option B preserved.

**The decisive observation**: the type discrimination Option A
delivers is independent of value validation. A bad value (empty,
whitespace-only) typed as `SwiftPM.Package.Name` is still
type-discriminated from a bad value typed as `SwiftPM.Product.Name`.
Type discrimination prevents API mix-ups (passing a package name
where a product name was expected); value validation prevents
malformed values from existing at all. The audit's deferred items
(F-A2.11 / F-A3.4 / F-A3.5) all describe API mix-up risk, not value
malformation risk.

**Where Option B would shine**: if the institute ever surfaced a
case where `SwiftPM.Package.Name = ""` was a real bug that the type
system should catch (and not SwiftPM's eventual build-time emptiness
check), Option B would close that gap at the cost of literal
ergonomics. No such case has been surfaced.

## Outcome

**Status**: v1.0.0 RECOMMENDATION per [RES-003a]. Principal flips to
DECISION on sign-off.

**Recommended**: **Option A** — pure typealias over
`Tagged<_, Swift.String>` with no validation at construction.

Specifically:

```swift
// SwiftPM.Package.Name.swift
extension SwiftPM.Package {
    public typealias Name = Tagged<SwiftPM.Package, Swift.String>
}

// SwiftPM.Product.Name.swift — same shape
// SwiftPM.Target.Name.swift — same shape
```

**Rationale (structural correctness per [RES-022])**:

1. Type discrimination is the structural goal; value validation is a
   separate concern that upstream SwiftPM itself doesn't enforce at
   the manifest-name layer.
2. Lint.Rule.ID precedent: matches an existing institute pattern
   for typed string identifiers without validation, applied to the
   only consumer that requires it (the linter rule-ID surface).
3. Future-proofing via Option D's spirit: if a v1.1.0+ consumer
   surfaces a real need for stricter validation, a companion
   `.Strict` wrapper struct can land additively without breaking
   v1.0.0 consumers. The path Option D describes is the upgrade
   path Option A naturally supports.

**Where Option B would be the right answer (and isn't, here)**: a
domain where the spec itself enforces validity rules and downstream
consumers rely on the typed wrapper to enforce them at construction
(e.g., `Glob.Pattern`'s grammar). SwiftPM manifest-level names are
NOT such a domain; the spec is permissive.

**Where Option C would be the right answer (and isn't, here)**: a
domain where validation is genuinely optional and consumers
differ on whether they want it. The institute's typed-identifier
ecosystem has not surfaced this need; Lint.Rule.ID's no-validate
shape is the consistent pattern.

**Implementation notes**:

- Each `.Name` typealias ships in its own file per [API-IMPL-005],
  matching `Lint.Rule.ID.swift`'s file:1-29 shape.
- DocC comment per type SHOULD document the permissive contract
  explicitly:
  ```swift
  /// Validation: none at construction time. Upstream SwiftPM enforces
  /// only emptiness for manifest-level names; institute consumers
  /// inherit the same permissive contract.
  ```
  This explicit framing prevents future readers from assuming the
  typed wrapper validates.

**Open questions surfaced for principal sign-off**:

1. Confirm Option A over Option D. Option D's promised v1.1.0+ Strict
   type is conceptually appealing but adds future-API debt. Option A
   alone — no promise — is cleaner.
2. Confirm the DocC permissive-contract note is mandatory (i.e.,
   ship as part of v1.0.0) versus optional.

## References

### Parent design Research

- `swift-institute/Research/2026-05-12-swift-spm-primitives-design.md`
  v1.0.0 RECOMMENDATION (commit `14df127`) — parent doc; §Q5 surfaces
  the open question this doc answers.

### Institute precedents

- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Rule.ID.swift:12-28`
  — canonical typealias-without-validation pattern.
- `swift-primitives/swift-linter-primitives/Sources/Linter Primitives/Lint.Source.swift`
  — `Lint.Source.Path` typealias (same shape).
- `swift-primitives/swift-glob-primitives/Sources/Glob Primitives/Glob.Pattern.swift`
  — Option B precedent (validating struct).
- `swift-primitives/swift-tagged-primitives/Research/sli-literal-vs-strideable-tradeoff.md`
  v1.0.0 DECISION — SLI literal conformance gating.

### Upstream sources (per [RES-026])

Verified against `swiftlang/swift-package-manager@main e1ced73eb`
(2026-05-12):

- `Sources/PackageModel/Manifest/Manifest.swift:31` — `displayName`
  unvalidated.
- `Sources/PackageLoading/PackageBuilder.swift:1576-1578` — product
  name emptiness-only check.
- `Sources/PackageLoading/PackageBuilder.swift:837-844` — target
  name emptiness-only check.
- `Sources/PackageModel/PackageIdentity.swift:213-294` — strict
  SE-0292 `Name` validator (registry tier, NOT manifest tier).

### Skills cited

- [API-ERR-001] typed throws
- [API-IMPL-005] one type per file
- [RES-003] document structure
- [RES-009] multi-option analysis
- [RES-022] structural correctness over diff size
- [RES-025] empirical validation (cognitive dimensions)
- [RES-026] citations
