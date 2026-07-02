# Code Surface Skill Rationale Archive

<!--
version: 1.0.0
last_updated: 2026-07-02
status: REFERENCE
-->

> Non-normative companion to `Skills/code-surface/SKILL.md` (per Research/ecosystem-meta-setup-target-state.md §D1).
> This document holds evicted rationale prose, provenance, extended worked examples, incident narratives,
> lint-enforcement scope detail, second/third example variants, and the dated amendment changelog. The skill
> file remains the CANONICAL source for all `[API-*]` requirement statements; nothing in this archive is
> normative. Organized by rule ID in skill order; the dated frontmatter changelog entries are collected
> in the final section.

---

## §[API-NAME-001] Nest.Name Pattern

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.CompoundType` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) walks `StructDeclSyntax`/`ClassDeclSyntax`/`EnumDeclSyntax`/`ActorDeclSyntax`/`ProtocolDeclSyntax` declarations and flags compound identifiers via word-boundary detection (lowercase→uppercase OR uppercase→uppercase→lowercase). Acronym-only names (`URL`, `UUID`, `IO`), spec-namespace forms with underscores (`RFC_4122`, `ISO_9945`), `package`-scope declarations, and `MacroDeclSyntax` are exempt. Methods/properties (compound METHOD identifiers) are governed by `Lint.Rule.Naming.Compound` per [API-NAME-002]. Added Wave 1 mechanization 2026-05-10.

---

## §[API-NAME-001a] Single-Type-No-Namespace Rule

**Additional correct-table rows** (evicted; representative rows remain in-skill):

| Wrong shape | Correct shape | Why |
|-------------|---------------|-----|
| `Main` (top-level, one type) | `Executor.Main` | Same reasoning — `Main` is one variant of `Executor` |
| `Scheduled<Base>` (top-level generic) | `Executor.Scheduled<Base>` | The `Scheduled` label describes an `Executor` variant, not a standalone domain |

| Shape | Siblings | Why it IS a namespace |
|-------|---------|------------------------|
| `File.Directory` | `Walk`, `Walk.Options`, `Listing`, … | Multiple concepts under one subdomain |

**Why this rule exists**: [API-NAME-001] (`Nest.Name`) gives the shape of nested namespaces. It does NOT prevent the author from creating an empty or single-inhabitant namespace that is really just a variant label. Without [API-NAME-001a], sessions discover this case-by-case and bikeshed each instance; the rule collapses the class into one decision.

**Rationale (full text)**: A namespace containing one type is vocabulary overhead without vocabulary payoff. `Executor.Cooperative` reads as "the Cooperative variant of Executor" — natural. `Cooperative.Executor` reads as "the Executor type in the Cooperative namespace" — suggesting there is more to the Cooperative domain than there is. Naming follows structure; structure follows what types actually exist.

**Provenance**: Reflection `2026-04-15-swift-executors-toolkit-taxonomy.md`.

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.SingleTypeNamespace` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags caseless-enum namespaces containing exactly one nested type declaration (with typealiases permitted as sibling labels). Conservative per-file detection — a namespace appearing single-typed here may have siblings in extensions across other files; the flag is a review prompt. Real enums (with cases), structs, and classes are out of scope. Added Wave 3 mechanization 2026-05-11.

---

## §[API-NAME-001b] LargerDomain.Subdomain — Subject-First When Domain Exceeds Role

**Additional correct-table rows** (evicted; representative rows remain in-skill):

| Wrong shape | Correct shape | Why |
|-------------|---------------|-----|
| `Parser.ASCII.Decimal` | `ASCII.Parser.Decimal` | ASCII is the larger domain; parser is the specialization. (Established by `ascii-parsing-domain-ownership.md` v4.2.0.) |
| `Serializer.Binary` | `Binary.Serializer` | Binary is the subject; serializer is the role. |

| Shape | Why |
|-------|-----|
| `Buffer.Ring` | `Ring` is a kind of `Buffer` — a buffer variant. |

**Why this rule exists**: prior to formalization, the subject-first ordering emerged ad-hoc — `ascii-parsing-domain-ownership.md` v4.2.0 RECOMMENDATION (2026-03-04) was the first instance, framed as "subject-first namespace ordering" specific to ASCII vs `Binary.ASCII`. The byte arc (2026-05-15) surfaced the same question on a different domain pair (`Byte` × `Parser`) and reached the same conclusion. Two instances of the same pattern across independent domain pairs justify promoting the ordering from a domain-specific recommendation to a code-surface rule applying uniformly across the institute.

**Worked example — the byte case**:

```
Wrong:                        Correct:
                              
Parser.Byte                   Byte.Parser
Parser.Byte.Literal           Byte.Literal.Parser
Parser.Input.Bytes            Byte.Input
                              
swift-parser-primitives       swift-byte-primitives       (Byte value type)
  Sources/Parser/Byte.swift   swift-byte-parser-primitives (Byte.Parser, Byte.Input)
                                Sources/Byte.Parser.swift
                                Sources/Byte.Input.swift
```

The wrong shape concentrates byte-specific parser logic inside the parser package, forcing every byte consumer to import parser machinery to get a byte concept. The correct shape splits the byte value type (zero parser deps) from the byte parser specialization (depends on parser + byte), so consumers needing only the byte concept don't transitively depend on the parser stack.

**Rationale (full text)**: a namespace ordered as `Role.Subject` implies the role owns the subject. When ten different subjects can take the role (parsers exist for bytes, ASCII, scalars, lines, …), the ordering misrepresents ownership: the role is being applied to the subjects, not the reverse. Reversing to `Subject.Role` makes the call site read naturally — `Byte.Parser` is "the parser for bytes," `Byte.Serializer` is "the serializer for bytes" — and lets the subject's package own its specializations, breaking the dependency cycle where every role package would need to know every subject.

**Provenance**: `swift-institute/Research/ascii-parsing-domain-ownership.md` v4.2.0 (prior single-domain instance, ASCII × Parser, 2026-03-04); `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.0 (formalization across domain pairs, Byte × Parser, 2026-05-15).

---

## §[API-NAME-001c] Per-Domain Capability-Marker Protocol

**Cohorts that follow the recipe (in production)**:

| Domain | Twin pair | X.Protocol shape | File |
|--------|-----------|------------------|------|
| Cardinal | `Cardinal` ↔ `UInt` | Trivial-self-carrier variant (`extension Carrier.Protocol where Underlying == Cardinal`) | `swift-cardinal-primitives` Cardinal+Carrier.swift + Cardinal.swift |
| Ordinal | `Ordinal` ↔ `UInt` | Sibling protocol (carries `associatedtype Count: Carrier.Protocol<Cardinal>`) | `swift-ordinal-primitives` Ordinal.Protocol.swift |
| Affine.Discrete.Vector | `Vector` ↔ `Int` | (Pattern instantiated by domain) | `swift-affine-primitives` |
| Byte | `Byte` ↔ `UInt8` | Sibling protocol (no extra associatedtype beyond Domain) | `swift-byte-primitives` Byte.Protocol.swift |

**Rationale (full text)**: the per-domain capability-marker recipe was discovered organically across Cardinal (2026-05-04 trivial-self-revert), Ordinal (operator-ergonomics arc 2026-04-26), Vector (Cycle 23 affine arc), and Byte (2026-05-15 byte-extraction arc + capability-marker Tier 3 session). Each adoption rediscovered the structural constraints — sibling-vs-refinement, parent-protocols-vs-separate-conformances, stdlib-raw-type-conformance — and converged on the same shape. The recipe IS the meta-pattern; promoting it to a rule eliminates the rediscovery cost for every future Group A capability marker. The constraint-principle clause (recursion-vs-refinement) is the structural anchor: it makes the sibling-vs-refinement decision mechanical rather than judgmental, and makes the recipe stable against future SPLIT operations of Tagged's Carrier conformance.

**Provenance**:
- `swift-institute/Research/byte-protocol-capability-marker.md` v1.1.0 (RECOMMENDATION 2026-05-15) — the Tier 3 research that names the recipe, the recursion-vs-refinement constraint principle, and the sibling-vs-refinement decision criterion. Discharges the predecessor handoff.
- `swift-institute/Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1 (DECISION 2026-05-15) — the predecessor arc landing `Byte.Protocol` in its initial refinement form; identified the recipe at decision-4 level.
- `swift-institute/Research/ascii-parsing-domain-ownership.md` v4.2.0 (RECOMMENDATION 2026-03-04) — earlier domain-ownership precedent on a different domain pair (ASCII × Parser); the subject-first naming side of the same family.
- `swift-institute/Research/cardinal-protocol-unification-memo.md` (SUPERSEDED 2026-05-04 by cardinal-trivial-self-revert-plan.md) — live-fire six-package precedent for the Cardinal variant of the recipe.
- `swift-institute/Research/Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` — provenance of [IMPL-102] (Swift overlapping-conformance constraint blocking meta-protocol variant).

(No lint enforcement — rule is structural; future candidate.)

---

## §[API-NAME-002] No Compound Identifiers

**Worked examples for the namespace-implicit-prefix sub-rule** (provenance: `feedback_namespace_implicit_prefix_removal.md`; struct-field row added 2026-05-08):

| Before | After | Containing namespace |
|--------|-------|----------------------|
| `Manifest.Configuration.packageRoot` | `Manifest.Configuration.root` | "package" implicit in `Configuration`'s domain |
| `Manifest.Dependency.packageName` | `Manifest.Dependency.name` | A `Dependency` IS a package; siblings are `path`, `product`, `imports` |
| `Manifest.Configuration.valueName` | `Manifest.Configuration.binding` | Special case — `value` carries no domain meaning; `binding` is more specific (Swift binding name) |
| `Lint.Manifest.{enabledRuleIDs, disabledRuleIDs, excludedPaths}` (struct fields) | `Lint.Manifest.{enabled, disabled, excluded}` paired with bare `ruleIDs` / `paths` on the value types | `Lint.Manifest` already supplies the discriminator; the three sibling fields share the bare-modifier shape (`enabled` + `disabled` are filter-set siblings on rule IDs; `excluded` is the filter-set sibling on paths) |

**Rationale (full text)**: Nested accessors mirror the nested type philosophy and enable progressive disclosure. Spec-mirroring identifiers are exempt because their names derive from external authority, not internal naming decisions. The keyword-adjective prohibition exists because the language keywords carry type-system semantics that cannot be recycled as identifier text without reader confusion. The namespace-implicit-prefix sub-rule closes a recurring drift point: borderline cases where a property name's first noun is "natural" in casual prose but redundant inside its containing namespace; the strict reading removes the redundancy.

**Provenance (boolean exception)**: 2026-04-01-async-primitives-audit-round-two.md
**Provenance (spec-mirroring exception)**: 2026-04-02 pre-publication audit decision
**Provenance (keyword-adjective prohibition)**: 2026-04-21-mod-017-batch-followups-silgen-workaround-shaping.md
**Provenance (namespace-implicit-prefix sub-rule)**: Reflection `2026-05-07-swift-linter-code-surface-cleanup-cohort-and-mirror-config-unblock.md` (Flag 2 supervisor adjudication on `Manifest.Configuration.packageRoot`); memory `feedback_namespace_implicit_prefix_removal.md`.
**Provenance (struct-field-application extension, 2026-05-08)**: swift-linter D5 release-readiness brief Phase 2 §Phase 2 Summary (post-X1 fresh-eyes audit identified `Lint.Manifest.{enabledRuleIDs, disabledRuleIDs, excludedPaths}` as the under-covered struct-field surface); `swift-institute/Research/swift-linter-launch-skill-incorporation-backlog.md` row 1.17.

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.Compound` (in `swift-foundations/swift-institute-linter-rules`, target `Linter Rule Naming`) flags compound method, property, and enum-case identifiers via word-boundary detection on `FunctionDeclSyntax` / `VariableDeclSyntax` / `EnumCaseElementSyntax` names. The structural-type-name counterpart `Lint.Rule.Naming.CompoundType` ([API-NAME-001]) covers compound type identifiers. The visibility-scope amendment (2026-05-11) is enforced via the shared helper `namingHasFileprivateOrPrivateEffectiveVisibility` (in `Lint.Rule.Naming.Shared.swift`), which checks the decl's own modifiers AND walks up the parent chain to detect enclosing fileprivate / private types — closing the case where a member of a fileprivate struct inherits restricted visibility without carrying the modifier itself. Added Wave 1 mechanization 2026-05-10; visibility-scope amendment Wave 3 Thread 4 2026-05-11.

---

## §[API-NAME-003] Specification-Mirroring Names

**Lint enforcement (DEFERRED — full reasoning)**: a pilot promotion attempt under `/promote-rule` (5th pilot, 2026-05-13) classified this rule as TEXT-ONLY rather than mechanizable. Reason: the ecosystem currently has zero top-level types matching the rule's "INCORRECT" examples (no bare `UUID`, `URI`, `URL`, `PDFPage` declarations) AND zero `RFC_NNNN.X` / `ISO_NNNN.X` spec-namespace declarations to validate against. The rule is aspirational guidance for future spec-implementations rather than enforcement against existing patterns. Mechanization would require ground-truth examples to calibrate the curated dictionary of spec-shaped names vs domain-prefix patterns (`Darwin.Identity.UUID`, `PostgreSQL.UUID` are legitimate non-spec-prefix forms the rule should NOT flag). Re-evaluate when the first spec package lands a type at `RFC_NNNN.X` shape. Outcome record: `swift-institute/Audits/PROMOTE-API-NAME-003-2026-05-13.md`.

---

## §[API-NAME-004] No Typealiases for Type Unification

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.UnificationTypealias` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags top-level `TypeAliasDeclSyntax` whose RHS is a `MemberTypeSyntax` AND whose LHS local name differs from the RHS leaf component, AND whose RHS does NOT carry a generic argument clause. Generic-instantiation typealiases (`typealias IntArray = Array<Int>`) are exempt — they localize a specialization decision, not a unification bridge. The companion [API-NAME-004a] rule flags same-leaf namespace-adoption shapes separately. Added Wave 4 mechanization 2026-05-11.

---

## §[API-NAME-004a] Namespace Adoption Typealiases

**Reference**: `swift-foundations/swift-io/Research/io-event-namespace-typealias-vs-enum.md`

**Provenance**: 2026-04-01-swift-io-code-surface-remediation.md

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.NamespaceAdoption` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags `TypeAliasDeclSyntax` whose name equals the RHS leaf component (`public typealias Event = Kernel.Event`). The flag is a REVIEW PROMPT: the writer SHOULD confirm the higher-layer namespace declares ≥ 5 sibling types / extensions / methods that justify adoption. Without those companions, the same shape is the rename-bridge anti-pattern caught by [API-NAME-004]. Mechanical confirmation of the "5+ companions" criterion is out of mechanical scope (cross-file). Added Wave 4 mechanization 2026-05-11.

---

## §[API-BRAND-001] Brand-Owner Exclusion Vocabulary

**Per-package examples** (cohort empirical data, 2026-05-17):

| Package | Brand | Form | Exclusions |
|---|---|---|---|
| `swift-carrier-primitives` | `Carrier.\`Protocol\`` | protocol | `int public parameter` (1) |
| `swift-cardinal-primitives` | `Cardinal` (wraps `UInt`) | value | `raw value access`, `chained rawvalue access`, `int public parameter`, `pointer advanced by`, `bitpattern rawvalue chain`, `unchecked call site`, `zero or one literal` (7) |
| `swift-ordinal-primitives` | `Ordinal` (wraps `UInt`) | value | `raw value access`, `chained rawvalue access`, `int public parameter`, `pointer advanced by`, `bitpattern rawvalue chain` (5) |
| `swift-cyclic-primitives` | `Cyclic.Group.Static<n>.Element` | value | `raw value access`, `unchecked call site`, `tagged extension public init` (3) |

**Provenance**: 2026-05-17 X1+X2 dispatch on swift-primitives data-structures cohort triage. The empirical pattern emerged from Wave 5A's per-package calibration (4 cohort Lint.swift files). Per-package exclusion vocabulary captured in `Audits/COHORT-TRIAGE-POST-ENGINE-FIX-2026-05-15.md` and the cohort Lint.swift files themselves. Codifies the runtime observation that "the per-package `excluding(rules:)` set IS the brand-form profile" surfaced in `HANDOFF-swift-linter-corpus-arc-2026-05-15.md` §Planned adjacent — skill promotions.

**Future AST candidates** (from the Lint-enforcement paragraph): (a) per-package metadata declaring brand-form, then validating the `excluding(rules:)` subset matches the form's vocabulary; (b) a manifest-shape lint rule that flags brand-owner packages with exclusion sets diverging from the documented vocabulary.

---

## §[API-ERR-004] Explicit Closure Annotation for Typed Throws

**Lint enforcement (full scope detail)**: `Lint.Rule.Throws.ClosureAnnotation` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Throws`) walks function and initializer declarations whose `throws(...)` clause has a typed-throws type. Inside the typed-throws context, any `ClosureExprSyntax` whose body contains a `try` AND whose signature lacks a typed `throws(...)` annotation is flagged. Closures without `try` and closures inside untyped `throws` outer functions are exempt. Added Wave 3 mechanization 2026-05-10.

---

## §[API-IMPL-005] One Type Per File

**Lint enforcement (full scope detail)**: `Lint.Rule.Structure.SingleTypePerFile` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Structure`) walks file-scope `StructDeclSyntax`/`ClassDeclSyntax`/`EnumDeclSyntax`/`ActorDeclSyntax`/`ProtocolDeclSyntax` nodes and flags the second-and-subsequent declaration. Extensions descend without flagging (extensions are not type declarations); nested types are skipped via depth tracking. Scope-excluded paths per Wave 2b finalization Decision 2: `Tests/`, `Experiments/`, `Examples/` (test fixtures legitimately declare multiple top-level types per [TEST-005]).

**Provenance**: 2026-03-31-async-primitives-code-surface-refactor.md; lint enforcement added 2026-05-10 (Wave 2b finalization Batch 3).

---

## §[API-IMPL-006] File Naming Convention

**Lint enforcement (full scope detail)**: Reusable workflow `validate-file-naming.yml` + companion `.github/scripts/validate-file-naming.py` walk every consumer's `Sources/` and flag `.swift` files whose basename contains NO dot AND matches the compound-name pattern (uppercase-first followed by an internal capital boundary). Exemptions: `Package.swift`, `exports.swift` / `Exports.swift` (build/re-export files); `+`-suffix extension forms per [API-IMPL-007]; where-clause shape per [API-IMPL-007]; underscore-bearing names (`RFC_4122.swift`, `ISO_9945.swift`) — spec-namespace forms per [API-NAME-003]; test/experiment/example/benchmark trees. Wave 1 mechanization 2026-05-10 added fixture-based regression tests at `swift-institute/.github/.github/scripts/tests/fixtures/api-impl-006/`.

---

## §[API-IMPL-007] Extension Files

**Extended where-clause file family** (evicted; two representatives remain in-skill):

```
Carrier where Underlying == Self.swift
Carrier where Underlying == Self, Self ~Copyable.swift
Carrier where Underlying == Self, Self ~Escapable.swift
Carrier where Underlying == Self, Self ~Copyable & ~Escapable.swift
```

**Rationale (full text)**: The where-clause filename is self-documenting — a reader sees the discriminator at the file level without opening the file. A `+` suffix mnemonic like `+Q1`/`+Q4` encodes the same information in a shorter but opaque form. For suppressed-protocol-constraint discrimination, where the constraints are part of the type system's stable vocabulary, the where-clause form is preferred. The `+` suffix remains canonical for conformance-adding extensions.

**Provenance**: `swift-carrier-primitives/Audits/audit.md` Code Surface #1 (2026-04-29 principal direction); `swift-institute/Research/carrier-launch-skill-incorporation-backlog.md` #1.7.

**Lint enforcement (full scope detail)**: Reusable workflow `validate-file-naming.yml` + companion `.github/scripts/validate-file-naming.py` flag pure-extension files (files whose top-level declarations are all `extension` blocks; no top-level `struct`/`class`/`enum`/`actor`/`protocol`/`typealias`/`func`/`var`/`let`) whose basename lacks BOTH a `+` segment AND a ` where ` discriminator. Files with a primary type declaration are out of scope (they're not extension files). Wave 4 mechanization 2026-05-11 added fixture-based regression tests at `swift-institute/.github/.github/scripts/tests/fixtures/api-impl-007/`.

---

## §[API-IMPL-008] Minimal Type Body

**Companion-note worked example** (the X2 pattern for iterator-like types):

```swift
// CORRECT (X2 pattern for iterator-like types)
extension Cyclic.Group.Static {
    public struct Iterator: Sendable {
        @usableFromInline
        var _buffer: InlineArray<1, Cyclic.Group.Static<modulus>.Element>  // ← fully-qualified

        @inlinable
        package init() { ... }
    }
}

extension Cyclic.Group.Static.Iterator: IteratorProtocol {
    @inlinable
    public mutating func next() -> Cyclic.Group.Static<modulus>.Element? { ... }  // ← fully-qualified
}

extension Cyclic.Group.Static.Iterator: Sequence.Iterator.`Protocol` {
    @_lifetime(&self)
    @inlinable
    public mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Cyclic.Group.Static<modulus>.Element> { ... }
}

// INCORRECT (typealias-binding attempt — trips [API-NAME-004a]/[PLAT-ARCH-018])
extension Cyclic.Group.Static.Iterator {
    public typealias Element = Cyclic.Group.Static<modulus>.Element  // ← namespace-adoption typealias
}
```

**Why full-qualification** (not a typealias): introducing `typealias Element = OuterType.Element` to bind the associatedtype trips `[API-NAME-004a]` (namespace adoption typealias) and `[PLAT-ARCH-018]` (typealiased namespace bridge) — those rules correctly flag same-leaf typealiases that silently bridge a foreign namespace into the local one. Full-qualification at the storage and witness sites breaks the inference cycle without introducing the bridge.

**Why conformance-on-extension**: the `[API-NAME-002]` protocol-witness exemption (via `namingCompoundProtocolWitnessMethodCitations`) gates on the enclosing extension's inheritance clause. When the witness lives in `extension X { ... }` (no inheritance clause), the conformance walk-up returns empty and the exemption does not fire. Declaring the conformance on each extension (`extension X: P { ... }`) restores the exemption.

**Provenance (companion note)**: 2026-05-17 X2 dispatch on `swift-primitives/swift-cyclic-primitives` — `Cyclic.Group.Static.Iterator` had `next()` + `nextSpan(maximumCount:)` in the struct body, firing [API-IMPL-008]. The straightforward extension move broke associatedtype inference because `_buffer: InlineArray<1, Element>` (storage) became a self-referential reference once `next()` was in extension scope. Full-qualification + conformance-on-extension was the resolution. Documented in `swift-institute/Audits/COHORT-TRIAGE-POST-ENGINE-FIX-2026-05-15.md` §Iterator protocol-witness Pattern Note. Generalizes to all iterator-like types with associatedtype-using storage as the deferred swift-sequence-primitives cohort and other ecosystem packages onboard [API-IMPL-008] enforcement.

**Lint enforcement (full scope detail)**: `Lint.Rule.Structure.MinimalTypeBody` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Structure`) walks `StructDeclSyntax`/`ClassDeclSyntax`/`EnumDeclSyntax`/`ActorDeclSyntax` member blocks and flags every `func`, computed `var`, `static let`/`var`, nested type declaration, `subscript`, and `typealias` directly in the type body. Stored properties (including `willSet`/`didSet`), canonical initializers, `deinit`, and enum cases are permitted. Protocol bodies are out of scope. Added Wave 3 mechanization 2026-05-11.

---

## §[API-IMPL-009] Hoisted Protocol with Nested Typealias

**Provenance**: Reflection `2026-03-20-pass4-compound-renames-and-generic-nesting.md`.

**Lint enforcement (full scope detail)**: `Lint.Rule.Structure.HoistedProtocolAlias` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Structure`) walks `ExtensionDeclSyntax` and flags conformance whose inherited type is `<ExtendedType>.Protocol` — i.e., the typealias path equal to the extended type. `MetatypeTypeSyntax` is handled (Swift parses `.Protocol` as metatype shorthand). Consumer-module conformance (different extended type) is not flagged; declaring-module conformance via the hoisted protocol name (`_FooProtocol`) is the correct form. Added Wave 3 mechanization 2026-05-11.

---

## §[API-IMPL-018] `@retroactive` Is Package-Scoped, Not Module-Scoped

**Second correct example** (same-package conformance — no attribute; evicted as the second example variant):

```swift
// In swift-serializer-primitives itself, where Serializable is declared,
// conforming Swift.Optional to the package's own Serializable:
extension Swift.Optional: Serializable where Wrapped: Serializable { ... }
```

**Why (full text)**: `@retroactive` exists to acknowledge that a conformance is being added by a party that controls neither the protocol nor the conforming type. Same-package conformances do not need the acknowledgement because the package author is, by definition, the authority over the protocol — the conformance is local to the package, not retroactive. The diagnostic is scoped to the package boundary, not the module boundary, even when the conformance and the protocol live in different *targets* within the same package.

**Provenance**: W5b subordinate's class-(c) surface 2026-05-14 (Coder/Serializer modeling arc). The brief listed `@retroactive Serializable` on `Optional`'s conformance in `swift-serializer-primitives`' Standard-Library-Integration target; compile error surfaced as `error: 'retroactive' attribute does not apply; 'Serializable' is declared in the same package`. Resolution shape in `swift-serializer-primitives/Sources/Serializer Primitives Standard Library Integration/Optional+Serializable.swift` (commit `3f4f897`).

---

## §[API-IMPL-019] Qualified Names Inside Conforming Extensions

**Why (full text)**: The associatedtype acts as a name binding in the conformance scope; Swift's name resolution prefers the closer-scoped binding over a top-level namespace of the same name. The full module-qualification escapes the local binding by going through the module entry.

**Provenance**: Same W5b 2026-05-14 incident as [API-IMPL-018] (the `@retroactive` rule). The brief's draft of `Optional+Serializable.swift` used unqualified `Serializer.Optionally`; resolution required fully-qualified `Serializer_Primitives_Core.Serializer.Optionally`. Commit `3f4f897` on swift-serializer-primitives.

---

## §[API-IMPL-021] Coroutine Accessors and `borrowing get` Over `get`/`set`

**Provenance**: the W4 ADT-tier reshape (`98ed3fb`: the gated generic subscript); seat verdict (Group A, Q5) 2026-06-10; probe evidence in `/tmp/accessor-probe` (re-runnable).

---

## §[API-IMPL-023] Capability Seams Are Deletable Conveniences

**Rationale (full text)**: seams exist for generic algorithms, not identity. Keeping canonical spellings concrete preserves zero-cost dispatch and keeps the seam deletable (no consumer is welded to the abstraction); the triple keeps the algebra's vocabulary at a non-generic noun home with adoption aliases instead of relocations.

**Provenance**: principal-ratified 2026-06-11 at the W5-1 §A15 adoption (converged plan storage-generational-purity 2026-06-10 — discipline inherited verbatim from `Memory.Allocating`'s doc; naming ruling = the canonical triple; pool 9dd38e7).

---

## §[API-IMPL-003] Enum Over Boolean

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.BoolParameter` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags `Bool` (or `Swift.Bool`) parameters in `public` / `open` function or initializer signatures. Optional and implicitly-unwrapped Bool wrappers are detected; closure-typed parameters that internally take Bool are exempt. Non-public visibility (`internal`, `private`, `fileprivate`, `package`) is exempt — internal signatures are the implementer's choice. Return-type `Bool` is NOT flagged (rule scopes to parameters). Added Wave 1 mechanization 2026-05-10.

---

## §[API-IMPL-010] Visibility Change Triggers Naming Audit

**Rationale (full text)**: Private names accumulate naming debt invisible to convention enforcement. Widening access exposes this debt. The audit is a one-time cost at the boundary change that prevents convention violations from reaching wider scopes.

**Provenance**: 2026-03-29-channel-split-full-duplex-io.md

---

## §[API-IMPL-011] Wrapper Completeness

**Rationale (full text)**: Incomplete wrappers create worse impressions than no wrapper at all. If a type owns construction and invariants but forces consumers to reach through to the backing type for the primary operation, the wrapper's encapsulation is perceived as useless — even though it provides genuine value for construction and error handling.

**Provenance**: 2026-03-30-io-lane-boundary-collaborative-review.md

**Lint enforcement (full scope detail)**: `Lint.Rule.Structure.WrapperBackingExposed` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Structure`) flags `_backing` / `_wrapped` / `_underlying` properties inside `struct` / `class` / `actor` whose access modifier is wider than `private` / `fileprivate`. Such properties signal consumers reach through (`wrapper._backing.run { ... }`) for any operation the wrapper omits — the canonical incomplete-wrapper shape. `@usableFromInline` decls are exempt (explicit opt-in to a different visibility model). Full wrapper-completeness verification requires whole-module method-set comparison — out of mechanical scope; this narrow heuristic catches the canonical leak. Added Wave 3 mechanization 2026-05-11.

---

## §[API-IMPL-012] Closure Parameters Trail the Signature

**Lint enforcement (full scope detail)**: `Lint.Rule.Closure.ParameterPosition` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Closure`) walks `FunctionDeclSyntax`/`InitializerDeclSyntax` parameter lists. Once a closure-typed parameter is seen, every subsequent non-closure parameter is flagged. Optional, attributed (`@escaping`/`@Sendable`), and typed-throws closures (`() throws(E) -> T`) all count as closures per [IMPL-092]. Added 2026-05-10 (Wave 2b finalization Batch 3).

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16); lint enforcement added 2026-05-10.

---

## §[API-IMPL-013] Multiple Closures Follow Lifecycle Order

**Call-site example** (evicted second example variant):

```swift
driver.operation { event in
    handle(event)
} completion: { result in
    finish(result)
}
```

**Lint enforcement (full scope detail)**: `Lint.Rule.Closure.MultipleLifecycle` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Closure`) flags signatures with ≥ 2 closure parameters whose 2nd-and-onward closure has a wildcard `_` external label. Closure detection covers optional, attributed, and typed-throws shapes. Added 2026-05-10 (Wave 2b finalization Batch 3). Wave 3 companion `Lint.Rule.Closure.LifecycleOrder` enforces the ORDER aspect: a completion-tier label (`completion`, `onError`, `cleanup`, `teardown`, `finalize`, ...) appearing before a body-tier closure (unlabelled `_` OR `body`/`perform`/`operation` label) is flagged.

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16); lint enforcement added 2026-05-10, order-enforcement companion added 2026-05-11 (Wave 3).

---

## §[API-IMPL-014] Configuration Parameter Placement

**Third correct example** (configuration modifier before closures; evicted example variant):

```swift
public func perform(
    on target: Target,
    options: Options = [],
    body: @escaping () -> Void
)
```

**Rationale (full text)**: Middle placement is not compatible with SE-0286 forward-scan when a closure trails, and hides the configuration's relationship to the operation. The first/last dichotomy maps onto the semantic role — primary input vs. modifier — and matches every surveyed ecosystem signature.

**Lint enforcement (full scope detail)**: `Lint.Rule.Closure.ConfigurationPlacement` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Closure`) walks `FunctionDeclSyntax`/`InitializerDeclSyntax` parameter lists. Configuration-bearing parameters are identified by type-name suffix (`Options`, `Configuration`, `Context`). Among non-closure parameters, a configuration parameter sitting at neither index 0 (primary input) nor the last non-closure index (modifier) is flagged. Splitting-configuration-across-siblings detection requires semantic analysis beyond the mechanical rule. Added Wave 3 mechanization 2026-05-11.

**Provenance**: `swift-institute/Research/parameter-ordering-conventions.md` (2026-04-16)

---

## §[API-NAME-006] New-Code Self-Compliance During Enforcement Sweeps

**Rationale (full text)**: Enforcement sweeps routinely produce incidental new code (a test helper for a migrated type, a fixture for a renamed enum, a hand-written example in a research doc). If the rule being enforced is not applied to that incidental code, the sweep paradoxically enlarges the non-compliance surface. Applying self-compliance within the session is free at authoring time and expensive to apply later (the incidental code becomes a pinned reference that resists change).

**Example (defect)**: A session sweeps 15 files for [API-NAME-002] compliance, renaming compound identifiers to nested accessors. The same session introduces test helpers `shapeA_back` and `shapeB_back` (compound) and a handoff artifact naming `BufferLinked` (compound). User correction catches the incidental violations; the fix is a second pass over session-authored code.

**Provenance**: 2026-04-21-property-primitives-typealias-sweep-and-self-compliance-gap.md

---

## §[API-NAME-005] Pre-Rename Mechanical Check for New Type Identifiers

**Rationale (full text)**: Catching naming violations at the proposal step is strictly cheaper than catching them at the commit step, which is strictly cheaper than catching them in review. The mechanical check takes seconds per identifier; skipping it compounds because new types rarely appear in isolation (a new type comes with its Options, its Error, its Iterator, etc., all inheriting the violation).

**Provenance**: 2026-04-22-strict-modularization-and-case-relocation.md (CaseInsensitive violation caught by user review)

---

## §[API-NAME-007] Convention-Known-Convention-Unapplied Heuristic for Method/Property Names

**Worked example (the origin incident)**:

`Array.swapAt(_:_:)` shipped in `swift-array-primitives@f0cf7f2` despite [API-NAME-002] being pinned in CLAUDE.md, in auto-memory, and frequently invoked. The trigger fired both ways: (a) internal capital `swapAt`; (b) copied from `Swift.Array.swapAt(_:_:)` and SE-0527. Neither check fired at the moment of writing, at commit time, or in the test filename. User caught post-ship; renamed to `swap(at:with:)` in `@c9c1083`. The check is a mechanical pre-commit gate; the cost is seconds, the cost of the post-ship rename was a separate session.

**Rationale (full text)**: [API-NAME-002] is declarative knowledge that consumers of this skill consistently know. The failure mode is procedural — at the moment of naming a specific method, the check does not run. The two triggers (internal capital, external-API pedigree) are the sufficient signals to fire the check at code-writing time. Codifying the triggers converts the rule from ambient judgment (which fails under stdlib gravity) to a mechanical heuristic.

**Provenance**: Reflection `2026-04-24-post-hoc-api-name-compliance-swap-rename.md` (`Array.swapAt` post-ship rename to `swap(at:with:)`).

---

## §[API-NAME-008] Property.View vs Labeled Method Decision Rule

**Worked example (the origin incident)**:

The `swapAt` rename surfaced an Option A vs Option B analysis:

| Option | Shape | Decision |
|--------|-------|----------|
| A — `Array.swap(at:with:)` (labeled method) | Single-form | **Stamped (single-form)** |
| B — `Array.swap.at(_, with:)` (Property.View) | Multi-form ceremony | Rejected — `swap` has one form |

Option B would have added per-variant `Swap` types (one per Array variant: dynamic, Fixed, Static, Small, Bounded), a `swap` property getter on each, and a typealias for ergonomic use. All for zero call-site expressivity gain — `swap.at(i, with: j)` is no clearer than `swap(at: i, with: j)`. Option A also matched `Buffer.Linear.swap(at:with:)` one layer down, supporting the layer-consistency soft tie-breaker.

**Rationale (full text)**: [API-NAME-002] bans compound identifiers but is silent on when nested-accessor ceremony is warranted vs. when labeled methods suffice. The silence lets the wrong choice seem equally valid. Codifying the multi-form-vs-single-form decision rule prevents Property.View ceremony on single-form operations (which would compound across the ecosystem since most operations are single-form).

**Provenance**: Reflection `2026-04-24-post-hoc-api-name-compliance-swap-rename.md` (Option A vs Option B analysis on `swap`).

---

## §[API-NAME-009] Educational-Diagnostic Message Format

**First correct example** (evicted second example variant — feedback-memory citation form):

```
[try_optional] feedback_prefer_typed_throws_over_try_optional: `try?` swallows the
typed error and replaces it with nil; the IO Notification.wait() Linux hot-spin
incident traced to a swallowed EAGAIN. Use typed throws or `try!` if precondition
is provably guaranteed.
```

**Rationale (full text)**: AI agents reading text-format diagnostic output extract identity from the message text, not from reporter envelopes that vary across consumers. Human readers benefit from seeing the institutional source at the diagnostic site, not having to follow a link to discover why the rule exists. Educational-diagnostic discipline at the message layer is a minimal AI-targeted hook that survives format changes — the P5 reporter format may evolve, but `[<rule_id>] <citation>: <description>` in the message text is consumer-agnostic.

**Provenance**: Reflection `2026-05-07-swift-linter-modularization-cohort-completion.md` (wave-1 AI-harness rule encoding; format adopted across 7 rules with supervisor sign-off "Strong work" on the educational-diagnostic axis).

**Lint enforcement (full scope detail)**: Reusable workflow `validate-diagnostic-format.yml` + companion `.github/scripts/validate-diagnostic-format.py` walk `Sources/**/Lint.Rule.*.*.swift` files (dotted basenames with ≥ 4 segments, per [API-NAME-001]) and concatenate every string literal in each `static let message: ... = "..." + "..."` chain. The concatenated message is flagged if it does NOT begin with `[<rule_id>] <citation>: ` — rule_id is a snake-case or kebab-case identifier in brackets; citation is any non-empty token sequence terminated by `: `. Namespace placeholder files (`Lint.Rule.Foo.swift`, 3 dot segments) and non-rule sources are out of scope. The validator does not verify citation existence — that's a research / skill-corpus concern. Wave 4 mechanization 2026-05-11.

---

## §[API-ERR-006] No Existential Throws Ever

**Provenance**: User feedback ~2026-03-21 — "I considered typed throws a foundational architectural principle; a DESIGN comment is not a resolution."

**Lint enforcement (full scope detail)**: SwiftLint custom rule `no_existential_throws` catches `throws(any Error)`. Companion rule `no_any_protocol_existential` (Wave 2b decision 3) extends the discipline to `any <Protocol>` references generally in `Sources/`. The AST counterpart `Lint.Rule.Throws.Existential` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Throws`) flags `throws(any Error)` and `throws(any Swift.Error)` via `SomeOrAnyTypeSyntax` inspection in `ThrowsClauseSyntax`. Added Wave 2b 2026-05-10.

---

## §[API-ERR-007] Public API Path for Error Types, Not Hoisted Internals

**Lint enforcement (full scope detail)**: `Lint.Rule.Throws.HoistedError` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Throws`) walks `throws(T)` clauses on `public` / `open` functions and initializers. If `T`'s leaf identifier (after stripping optional and member-type wrappers) starts with `__`, the type is flagged as a hoisted internal leaking into the public surface. Single-underscore prefixes (different SPI convention), non-public visibility, and untyped `throws` are exempt. Added Wave 1 mechanization 2026-05-10.

---

## §[API-ERR-008] Lifecycle Typealias Only When ALL Cases Apply

**Why (full text)**: A typealias to a shared error type that has unreachable cases creates a phantom-case API surface. Consumers writing exhaustive `catch` blocks must handle cases the primitive will never produce; static analysis cannot tell the dead arms from the live ones. The shared type's promise is "any of these errors may occur" — when the actual surface is narrower, the typealias lies.

**Provenance**: memory `feedback_lifecycle_typealias_when_all_cases_apply.md` (per-primitive lifecycle-error typealias discipline).

**Lint enforcement (full scope detail)**: `Lint.Rule.Throws.LifecycleTypealiasReview` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Throws`) walks `TypeAliasDeclSyntax` whose name is `Error` and initialized type is a `MemberTypeSyntax` chain ending in `.Error` with the parent component `Lifecycle` (e.g., `Async.Lifecycle.Error`, `Pool.Lifecycle.Error`). The rule cannot verify case coverage mechanically; it surfaces the decision as a review prompt. Added Wave 3 mechanization 2026-05-11.

---

## §[API-NAME-010] No `*Tag` Suffix for Phantom Types

**Lint enforcement (full scope detail)**: SwiftLint custom rule `no_tag_suffix_phantom` (`swift-institute/.github/.swiftlint.yml`) catches `Tagged<\w+Tag,` literals. The AST counterpart `Lint.Rule.Naming.Tag` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags `StructDeclSyntax` / `EnumDeclSyntax` declarations whose name ends in `Tag` AND whose body has zero stored properties / zero cases — the empty-body heuristic isolates phantom-type markers from legitimate types that happen to end in `Tag`. Added Wave 2b 2026-05-10.

---

## §[API-NAME-010a] No Nested `.Tag` Sub-Name for Phantom Types

**Rationale (full text)**: Namespace enums declared as `public enum X: Sendable {}` are already empty — substituting `X` directly for the phantom-tag slot is cost-free at the value layer (no runtime change) and avoids the duplicate-name reading `Property<X.Tag, T>` produces. The rule generalizes [API-NAME-010]'s intent — "the tag IS the concept; the wrapper adds nothing" — from the suffix axis to the sub-name axis.

**Provenance**: 2026-05-13 swift-order-primitives 0.1.0 readiness arc. The dispatch's locked E3 decision specified `Order.Order` → `Order.Tag` per an institute Tag-Name convention; mid-dispatch the principal corrected: "we dont ever do *.Tag. Ideally it's just Property<Order, Self>". Commit `733da36` on `swift-primitives/swift-order-primitives` superseded the intermediate `Order.Tag` state with the namespace-as-phantom shape. Memory pointer at `feedback_no_dot_tag_convention.md` records the runtime principal directive; this rule promotes the convention from per-session feedback to ecosystem invariant.

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.NestedTag` (in `swift-foundations/swift-institute-linter-rules`, target `Linter Rule Naming`) walks `StructDeclSyntax` / `EnumDeclSyntax` declarations literally named `Tag`, checks that the body has zero stored properties (struct) or zero cases (enum), and walks the parent chain to confirm an enclosing type-decl or extension context. Domain `.Tag` types with stored properties / cases (`HTML.Tag` with cases, `XML.Tag` with `name: String`) pass through; phantom-marker `.Tag` sub-types do not. Top-level `Tag` declarations are skipped — they have no enclosing namespace whose role would duplicate. Sibling of `Lint.Rule.Naming.Tag` per [API-NAME-010]; together they cover the suffix and nested-sub-name forms of the same defect. Added 2026-05-13 via pilot `/promote-rule` invocation.

---

## §[API-NAME-010b] Maximal Suppression on Phantom Parameters

**Provenance**: `swift-institute/Research/phantom-parameter-suppressed-protocol-bound.md` (RECOMMENDATION v1.0.0); `swift-institute/Research/phantom-parameter-bound-cascade-implementation-plan.md` (v1.2.0, EXECUTED 2026-06-01 — relax sites across 21 committed packages in swift-primitives + swift-foundations).

---

## §[API-NAME-011] `Options` Not `Flags` for OptionSet Types

**Lint enforcement (full scope detail)**: SwiftLint custom rule `options_not_flags` catches `struct *Flags` / `enum *Flags` declarations. Spec-mirroring exception per [API-NAME-003] opts out via `// swiftlint:disable:next options_not_flags  // reason: spec literal`. The AST counterpart `Lint.Rule.Naming.Options` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags `StructDeclSyntax` whose name ends in `Flags` AND whose inheritance clause names `OptionSet` (or `Swift.OptionSet`). Added Wave 2b 2026-05-10.

---

## §[API-NAME-012] No `impl` / `obj` / `inst` Local-Binding Abbreviations

**Lint enforcement (full scope detail)**: SwiftLint custom rule `no_impl_obj_inst_bindings` catches `let|var (impl|obj|inst|instance) =`. The AST counterpart `Lint.Rule.Naming.Impl` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags `VariableDeclSyntax` with an `IdentifierPatternSyntax` binding named `impl` or `_impl`. Added Wave 2b 2026-05-10.

---

## §[API-NAME-013] Drop Redundant Prefix When Namespace Supplies Context

**Worked examples**:

| Before | After | Containing namespace |
|---|---|---|
| `Manifest.Configuration.packageRoot` | `Manifest.Configuration.root` | "package" implicit in Configuration's domain |
| `Manifest.Dependency.packageName` | `Manifest.Dependency.name` | A Dependency IS a package |
| `Manifest.Configuration.valueName` | `Manifest.Configuration.binding` | `value` carries no domain meaning; `binding` is the Swift binding name |

**Provenance**: 2026-05-07 cleanup-cohort dispatch — Flag 2 supervisor adjudication on `Manifest.Configuration.packageRoot`. Subordinate recommended keep; supervisor pushed back: "domain phrase isn't an [API-NAME-002] carve-out; sibling-shape consistency with `Manifest.Dependency.path` is the load-bearing argument."

**Lint enforcement (full scope detail)**: `Lint.Rule.Naming.RedundantPrefix` (in `swift-foundations/swift-linter-rules`, target `Linter Rule Naming`) flags nested type declarations whose name begins with the enclosing namespace's name followed by an uppercase-led suffix (e.g., `enum Walk { struct WalkOptions {} }` — `WalkOptions` redundant because parent already says "Walk"). Stack-tracked enclosing-name visitor walks `StructDeclSyntax`/`ClassDeclSyntax`/`EnumDeclSyntax`/`ActorDeclSyntax`/`ProtocolDeclSyntax`/`ExtensionDeclSyntax`; for extensions on member types (`extension A.B.C { ... }`), the LAST component (`C`) is the enclosing name. Top-level decls and exact-match nested decls (`Foo` inside `Foo`) are exempt; the property-naming variant of the rule (e.g., `Manifest.Configuration.packageRoot` → `root`) is currently human-enforced — only the type-prefix variant is mechanized in Wave 1. Added Wave 1 mechanization 2026-05-10.

---

## §[API-NAME-014] Module Disambiguation Over Shadow-Avoidance Renames

**Rationale (full text)**: Choosing alternative names like `Text` to dodge a shadow is naming-by-avoidance, not naming-by-intent. The type IS a string representation in the Base62 domain — `String` is the correct name. `Text` is a compromise that obscures the domain model. Module-qualified access is verbose at the few ambiguous call sites; alternative naming is wrong at every call site.

---

## §[API-IMPL-016] Typealiases Allow Nested Type Extensions

**Rationale (full text)**: Asserting a non-existent compiler limitation as architectural justification leads to bad rename proposals (`Kernel.TimeSpec` instead of `Kernel.Time.Specification`) or wholesale relocation. The type system is more permissive than intuition suggests; verify the actual behavior before designing around an imagined constraint.

---

## §[API-IMPL-017] Preserve Labeled Call-Site Syntax When Migrating Protocols to Witness Structs

**Provenance**: memory `feedback_preserve_labeled_api.md` (witness-struct migration of Rendering.Context).

---

## §Changelog-Provenance

> The dated amendment changelog previously carried as `#` comment lines in the skill frontmatter,
> reproduced verbatim (newest-first order as originally recorded). Each entry documents when and why a
> rule was added, amended, mechanized, or removed; the normative content of every entry lives in the
> owning rule body in `Skills/code-surface/SKILL.md` (or, for [API-IMPL-015], records its removal).

- 2026-06-22: [API-IMPL-009] req 2 refined (Clarifying per [SKILL-LIFE-003]) — SELF-conformance must use the hoisted name (canonical X.`Protocol` self-references → circular reference); SIBLING conformers + constraint sites PREFER the canonical X.`Protocol` (the hoisted __-name is an impl detail; minimize raw use). Aligns the prose with the already-shipped Lint.Rule.Structure.HoistedProtocolAlias (flags only self-conformance). Verified swiftc 6.3.2. Provenance: operation-domain-naming-and-organization.md v1.1.2 §6.1; principal direction 2026-06-22.
- 2026-06-22: [API-IMPL-023] BREAKING amendment per [SKILL-LIFE-003] — generic agent-noun nests (Memory.Allocator<Resource>) carry the canonical triple ON the AGENT NOUN via the [API-IMPL-009] hoist (Memory.Allocator.`Protocol` resolves unbound under non-generic root Memory; the witness is the generic struct itself). The "directly-nested gerund with no noun home" workaround (Memory.Allocating homed on deverbal Memory.Allocation) is DISALLOWED — its "generics can't host a protocol" premise is disproven (verified swiftc 6.3.2). Reverses the 2026-06-12 R-1 "RESOLVED" note below; reopens R-1. Memory.Allocating + Store.`Protocol`-class seams flagged for triple-retrofit at release-readiness. Provenance: operation-domain-naming-and-organization.md v1.1.0 §6.1.
- 2026-06-12: [API-IMPL-022] MECHANIZED + compressed per [PROMOTE-006] (ζ pilot, Round M): rule landed as Lint.Rule.Tower.FrozenTowerType (primitives tier, NEW pack Primitives Linter Rule Tower — the recorded Structure-pack candidate name collided with the universal tier); the seat-ruled views/iterators/snapshots exemption folded into the compressed Statement (resolving the queued wording amendment, Examples-as-authoritative carve-out); full prior body migrated to the outcome record's Discipline reference. Validation: ladder 0/7 (5 docc-snippet harness artifacts excluded), tower probe 44 real findings = the Q4 sweep's unfinished tail (worklist in the outcome record; trees' Sequence-wrapper classification = seat ask). Clarifying per [SKILL-LIFE-003].
- 2026-06-12: [API-IMPL-023] note — the recorded "Allocating = workaround shape" RESOLVED: Round M A1 completed the canonical triple on the existing noun nest (`Memory.Allocation.\`Protocol\`` + `Memory.Allocating` gerund alias; memory-allocation 701725e, seat ruling R-1 on REPORT-round-m-W0.md). Same commit dissolves `Memory.AllocatorPool` into `Memory.Pool` as the vocabulary's REAL home (R-2); `Memory.AllocatorArena` remains the documented §A13 carrier pending the R-3 principal ruling. Rule Statement and example set unchanged. Clarifying per [SKILL-LIFE-003].
- 2026-05-26: [API-NAME-001b] extended — subject-vs-manner discriminator + concept-before-word ordering step (manner → role-owns: Iterator.Borrow, Iterator.Chunk, Parser.Many; subject → subject-first: Byte.Parser, Memory.Contiguous). Corrected same day: the bulk tier is Iterator.Chunk (manner), NOT Iterator.Contiguous — "Contiguous" is the memory subject's word (Memory.Contiguous), so reusing it as a manner is the collision the rule forbids. [API-NAME-004a] extended — gated witness result-noun-alias exemption per [PKG-NAME-015]. Provenance: swift-institute/Research/operation-domain-naming-and-organization.md (definitive Tier-3 convention).
- 2026-05-18: [API-BRAND-001] Lint enforcement paragraph updated to cross-reference the new **swift-linter** skill's `[LINT-EXCLUDE-001]`–`[LINT-EXCLUDE-004]` rules — the linter-side application of this rule's brand-owner vocabulary. Cross-references row gains the swift-linter skill pointer. Statement unchanged; mechanization status still TBD (AST candidates documented). Clarifying per [SKILL-LIFE-003].
- 2026-05-18: [API-IMPL-006] Statement amended to explicitly cross-reference [API-NAME-001] (`Nest.Name`) — file-naming structurally mirrors type-naming; the implicit linkage left readers inferring the connection (in particular, swift-linter setup discussions surfaced the gap). Statement adds "the same `Nest.Name` pattern as [API-NAME-001], expressed at the file system level"; Cross-references row gains [API-NAME-001] as the first entry. Statement scope unchanged (still "type's full nested path with dots"); the amendment is terminology + cross-reference linkage, not a widening. Provenance: principal direction 2026-05-18 during swift-linter setup-skill scoping. Clarifying per [SKILL-LIFE-003].
- 2026-05-17: [API-BRAND-001] Brand-Owner Exclusion Vocabulary — additive per [SKILL-LIFE-003]. Codifies the per-package Lint.swift `excluding(rules:)` pattern that emerged from Wave 5A cohort calibration: rule corpus is brand-form-agnostic by design; each brand-owner declares which subset of rules targeting brand-boundary vocabulary applies to external consumers but NOT to the brand-owner's own surface. Distinguishes protocol-form (1-rule vocabulary, e.g. carrier) from value-form (8-rule vocabulary; each brand-owner excludes the empirical minimum, e.g. cardinal 7, ordinal 5, cyclic 3). Per-package examples (carrier / cardinal / ordinal / cyclic) anchored to cohort empirical data. Closes the "skill promotion: protocol-form vs value-form brand-owner distinction" open arc from `HANDOFF-swift-linter-corpus-arc-2026-05-15.md` §Planned adjacent. Composes with [API-NAME-001c] (capability-marker protocol). Lint enforcement TBD (promotion candidate via lint-rule-promotion).
- 2026-06-11: [API-IMPL-023] Capability Seams Are Deletable Conveniences — additive per [SKILL-LIFE-003]. The W5-1 §A15-adoption discipline (concrete canonical spellings, never `any`, the canonical triple when a non-generic noun nest exists; Allocating = workaround shape). Principal-ratified 2026-06-11; pool 9dd38e7.
- 2026-06-10: [API-IMPL-022] Tower Value Types Are `@frozen` — additive per [SKILL-LIFE-003]. Principal Q4 ruling (sweep ratified): tower value types layout-lock now; new types @frozen from birth; enables cross-module partial consumption (take()-style workarounds retired). Sweep commits f54ccbe/3f7165b/3460016/de2487f/78834c2/38a6373. Lint candidate Lint.Rule.Structure.FrozenTowerType.
- 2026-06-10: [API-IMPL-021] Coroutine Accessors and `borrowing get` Over `get`/`set` — additive per [SKILL-LIFE-003]. Element-vending/forwarding surfaces use `_read`/`_modify` (plain get/set only where copy semantics are the point); ~Escapable returns use `borrowing get` + `@_lifetime`. 6.3.2 constraints probed: requirement-position `modify` unavailable even under CoroutineAccessors (requirements stay `{ get set }`, witnessed by coroutines); SE-0474 `yielding borrow/mutate` absent — adopt at gate bump; do NOT adopt experimental unprefixed read/modify (guaranteed rename). Provenance: W4 ADT reshape 98ed3fb; seat Group-A Q5 verdict 2026-06-10; probes /tmp/accessor-probe.
- 2026-05-17: [API-IMPL-008] companion note — protocol-witness methods on types with associatedtype-using storage. Documents the conformance-on-extension + full-qualification pattern surfaced during X2 dispatch on `swift-primitives/swift-cyclic-primitives` (`Cyclic.Group.Static.Iterator` refactor). Codifies why introducing `typealias Element = OuterType.Element` to bind the associatedtype trips [API-NAME-004a]/[PLAT-ARCH-018] and why declaring conformance per-extension restores the [API-NAME-002] protocol-witness exemption (which gates on enclosing extension's inheritance clause). Generalizes to all iterator-like types as deferred packages (swift-sequence-primitives etc.) onboard [API-IMPL-008] enforcement. Provenance: cohort triage doc §Iterator protocol-witness Pattern Note + this skill update. Clarifying per [SKILL-LIFE-003].
- 2026-05-15: [API-NAME-001c] Per-Domain Capability-Marker Protocol — additive per [SKILL-LIFE-003]. Codifies the canonical recipe for Group A capability-marker types (`Cardinal`/UInt, `Ordinal`/UInt, `Byte`/UInt8, future Char/Codepoint/Word/Line/…): SIBLING-to-`Carrier.Protocol` X.Protocol (NOT refinement); `var x: X { get }` + `init(_ x: X)` accessor; `associatedtype Domain: ~Copyable = Never` for tag-enforcement; recursive `extension Tagged: X.Protocol where Underlying: X.Protocol, Tag: ~Copyable`; stdlib-protocol conformances declared separately (default impls on `extension X.Protocol` provide witnesses); stdlib raw type MUST NOT conform. Includes the recursion-vs-refinement constraint principle: refinement-of-Carrier blocks recursive Tagged conformance because `Tagged<Tag, X>.Underlying == X`, not the bottom-most carrier type — use sibling form when recursive Tagged participation is needed or anticipated (always true for Group A). Provenance: `Research/byte-protocol-capability-marker.md` v1.1.0 (RECOMMENDATION), `Research/byte-primitive-extraction-and-domain-naming.md` v1.0.1 (DECISION), `Research/ascii-parsing-domain-ownership.md` v4.2.0 (RECOMMENDATION), `Research/cardinal-protocol-unification-memo.md` (SUPERSEDED — live-fire six-package precedent), `Reflections/2026-04-23-carrier-walkback-and-capability-lift-taxonomy.md` ([IMPL-102] provenance). Composes with [IMPL-102] (meta-protocol variant blocked by Swift overlapping-conformance rules). No lint enforcement (rule is structural; future candidate).
- 2026-05-15: [API-IMPL-020] mechanization — `Lint.Rule.Conformance.LeafBodyTypealias` landed in `swift-foundations/swift-institute-linter-rules` (NEW pack `Linter Rule Conformance`). Bundle entry added to `Lint.Rule.Bundle.institute` after `suite categories`. First AST-domain pivot promotion of `/promote-rule` per `swift-institute/Audits/PROMOTE-API-IMPL-020-2026-05-15.md`; validation receipt at `swift-foundations/swift-linter-rules/Research/promote-API-IMPL-020-validation-2026-05-15.md` (0 diagnostics across 7 ladder packages; 50 ground-truth findings on 5 conformer packages, deferred batch-fix per Phase 6 branch 1). Skill body compressed atomically per [PROMOTE-006]; displaced Forbidden patterns / Rationale / Provenance migrated to outcome record's `## Discipline reference` section. Clarifying per [SKILL-LIFE-003].
- 2026-05-14: [API-IMPL-020] Explicit `Body = Never` Typealias on Generic Parser/Serializer Leaf Conformers — additive per [SKILL-LIFE-003]. Generic leaf conformers to `Parser.Protocol` / `Serializer.Protocol` MUST declare `public typealias Body = Never` explicitly; the protocol-level `associatedtype Body: ~Copyable = Never` default is insufficient for witness-table emission on generic conformers (link-time undefined-symbols for body.getter). Provenance: W4c-fix on swift-binary-parser-primitives commit `601c559f`; failed protocol-level workarounds on swift-parser-primitives (`ce9b271`+revert `b09d30c`) and swift-serializer-primitives (`c61ac01`+revert `56063c3`). Compiler-behavior note: explicit-typealias requirement reflects current witness-emission semantics for generic conformers; rule remains correct shape even after a hypothetical compiler fix.
- 2026-05-14: [API-IMPL-019] Qualified Names Inside Conforming Extensions — additive per [SKILL-LIFE-003]. Inside `extension T: Protocol` where Protocol declares `associatedtype X`, the unqualified identifier `X` resolves to the conformer's associatedtype-binding, NOT to any same-named type in the broader namespace. Same W5b 2026-05-14 incident as [API-IMPL-018]; sibling rule. Provenance: commit `3f4f897` on swift-serializer-primitives.
- 2026-05-14: [API-IMPL-018] @retroactive Is Package-Scoped, Not Module-Scoped — additive per [SKILL-LIFE-003]. Promotes the W5b 2026-05-14 subordinate's empirical catch from the Coder/Serializer modeling arc: Swift's `@retroactive` attribute applies only to cross-package conformances; same-package conformance with `@retroactive` rejects with `error: 'retroactive' attribute does not apply; 'X' is declared in the same package`. Provenance: commit `3f4f897` on swift-serializer-primitives.
- 2026-05-13: [API-IMPL-015] REMOVED — Pattern 2 (universal-from-zero-counterexamples). The rule's rationale was "the ecosystem survey found zero builder-closure configurations — this rule codifies the existing practice" — that is post-hoc rationalization of an observation, not a principle. Builder closures (`(inout T) -> Void`) have legitimate uses (DSL ergonomics, ResultBuilder integration, conditional config) and the rule blocked them on the basis of a snapshot, not a constraint. Cross-references in [API-IMPL-014] and the Post-Implementation Checklist scrubbed. Provenance: user direction 2026-05-13. Breaking per [SKILL-LIFE-003] (rule removal); pre-1.0 phase makes this safe. No replacement rule.
- 2026-05-13: [API-NAME-010a] mechanization — `Lint.Rule.Naming.NestedTag` landed in `swift-foundations/swift-institute-linter-rules` (target `Linter Rule Naming`). Bundle entry added to `Lint.Rule.Bundle.institute` at the row after `tag suffix`. Pilot run of `/promote-rule` per `swift-institute/Audits/PROMOTE-API-NAME-010a-2026-05-13.md`; validation receipt at `swift-foundations/swift-linter-rules/Research/promote-API-NAME-010a-validation-2026-05-13.md` (0 diagnostics across 7 validation packages, as predicted). [VERIFICATION NEEDED] tag at the rule body RESOLVED. Clarifying per [SKILL-LIFE-003].
- 2026-05-13: [API-NAME-010a] No Nested `.Tag` Sub-Name for Phantom Types — additive per [SKILL-LIFE-003]. Promotes the runtime principal directive from the swift-order-primitives 2026-05-13 0.1.0 readiness arc ("we dont ever do *.Tag. Ideally it's just Property<Order, Self>") from per-session memory feedback into a code-surface invariant. Complements [API-NAME-010] (suffix-Tag) by closing the nested-sub-name axis. Provenance: commit `733da36` on swift-primitives/swift-order-primitives; memory pointer `feedback_no_dot_tag_convention.md`. Lint enforcement candidate (Lint.Rule.Naming.NestedTag) queued for the next swift-linter-rules wave.
- 2026-05-11: Wave 3 Thread 4 (rule-corpus iteration) — amended [API-NAME-002] with a Visibility-scope sub-section codifying the 2026-05-11 DECISION (Option B): the compound-identifier rule applies to internal/package/public/open decls and exempts fileprivate/private — including members whose effective visibility is reduced by an enclosing fileprivate/private type. Closes the 2 Ownership.Transfer.Erased.Outgoing.Header residuals from the Wave 2 leaf triage. Full alternatives analysis at `swift-institute/Research/api-name-002-private-surface-applicability.md`. Statement is widened (carve-out added) per [SKILL-LIFE-001]; lint enforcement note updated.
- 2026-05-11: Wave 4 Bucket 1 doc-gap pass (HANDOFF-mechanization-wave-4.md) — added Lint enforcement + [VERIFICATION] tags for [API-NAME-002] (Lint.Rule.Naming.Compound), [API-ERR-001] (SwiftLint typed_throws_required + Lint.Rule.Throws.Untyped), [API-ERR-002] (SwiftLint swift_error_qualification), [API-IMPL-005] (Lint.Rule.Structure.SingleTypePerFile), [API-ERR-006] (SwiftLint no_existential_throws + Lint.Rule.Throws.Existential), [API-NAME-010] (SwiftLint no_tag_suffix_phantom + Lint.Rule.Naming.Tag), [API-NAME-011] (SwiftLint options_not_flags + Lint.Rule.Naming.Options), [API-NAME-012] (SwiftLint no_impl_obj_inst_bindings + Lint.Rule.Naming.Impl). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
- 2026-05-10: Phase 3b TRIM-PROSE — compressed Rationale/clarification prose on [API-IMPL-005], [API-IMPL-012], [API-NAME-010], [API-NAME-011], [API-NAME-012], [API-ERR-002], [API-ERR-006] now that lint mechanically enforces. Added [VERIFICATION NEEDED] tag to [API-ERR-005] per Phase 3b Q5. Repaired broken [API-EXC-001] cite in [API-ERR-007] body to point at [PATTERN-016] WORKAROUND template. Statements unchanged per [SKILL-LIFE-001].
- 2026-05-10: Wave 2b lint extraction (HANDOFF-skill-to-ci-cd-extraction-inventory.md) — added Lint enforcement lines for [API-ERR-006], [API-NAME-010], [API-NAME-011], [API-NAME-012] mapping each rule to its new SwiftLint custom rule in `.swiftlint.yml`. Prose unchanged per [SKILL-LIFE-001] minimal revision; these are clarifying additions per [SKILL-LIFE-003].
- 2026-05-10: Wave 2b finalization Batch 3 (HANDOFF-wave-2b-finalization.md) — added Lint enforcement lines for [API-IMPL-005] (Lint.Rule.Structure.SingleTypePerFile), [API-IMPL-012] (Lint.Rule.Closure.ParameterPosition), [API-IMPL-013] (Lint.Rule.Closure.MultipleLifecycle). [API-NAME-002] confirmed as already-shipped Lint.Rule.Naming.Compound (Wave 1).
- 2026-05-10: Wave 1 mechanization (HANDOFF-mechanization-wave-1-high-leverage.md) — added Lint enforcement lines for [API-NAME-001] (Lint.Rule.Naming.CompoundType), [API-NAME-013] (Lint.Rule.Naming.RedundantPrefix — type-prefix variant), [API-IMPL-003] (Lint.Rule.Naming.BoolParameter), [API-ERR-007] (Lint.Rule.Throws.HoistedError), [API-IMPL-006] (validate-file-naming.py + workflow). Statements unchanged per [SKILL-LIFE-001]; clarifying per [SKILL-LIFE-003].
