# Wave 2 Rule Amendments — Dispatch Ledger

<!--
---
version: 1.1.0
last_updated: 2026-05-11
status: IMPLEMENTED
---
-->

## Context

Empirical input: 5 leaf-package triages run against the rule corpus on 2026-05-11
(swift-either, swift-product, swift-property, swift-carrier, swift-tagged primitives).
Per-leaf reports are sibling files `lint-pass-2026-05-11-swift-*-primitives.md`.

Across the 5 leaves, **89 findings** were dispositioned; **~73% RULE-WRONG** (rule
over-fires on a deliberate institute pattern), **~17% SOURCE-WRONG** (already
committed per-leaf), **rest AMBIGUOUS** (held pending [MEM-SAFE-025] reconciliation).

This ledger captures the 11 RULE-WRONG amendment threads queued for dispatch. The
dispatch is one commit per thread (so commit history per-rule stays clean), in
dependency order.

## Source Signal Per Leaf

| Leaf | Findings | SOURCE-WRONG | RULE-WRONG | AMBIGUOUS |
|---|---:|---:|---:|---:|
| swift-either-primitives | 6 | 0 | 6 (Compound `flatMap`) | 0 |
| swift-product-primitives | 13 | 0 | 13 (MEM-COPY pack × 11; Existential × 2) | 0 |
| swift-property-primitives | 15 | 2 (committed `7de1f5c`) | 12 (docc × 8; Compound local × 1; MEM-COPY-pos × 2 + indirect; minimal/Protocol × 1) | 1 ([MEM-SAFE-025]) |
| swift-carrier-primitives | 17 | 0 | 17 (docc × 13; MEM-COPY ` where ` × 2; unification gerund × 1; minimal Protocol × 1) | 0 |
| swift-tagged-primitives | 25 | 4 (Cluster G pending commit) | 21 (Tagged-init × 11; bridge × 3; Compound × 3; mock × 2; PoC × 2) | 0 |

## Dispatch Queue

Dispatch order respects dependencies. #1 must land first. After that, each
amendment is independent and lands in its own commit.

### #1 — Shared infra: extend `Lint.Rule.Naming.Shared.swift`

**Tier**: institute (swift-institute-linter-rules — Naming pack moved here in 3-tier split)
**File**: `Sources/Linter Rule Naming/Lint.Rule.Naming.Shared.swift`
**Depends on**: nothing
**Blocks**: #2 only (within the same Naming target)
**Status**: LANDED 2026-05-11 (UNCOMMITTED — package not yet git-init'd; HANDOFF.md Open Q2)

Add helper `namingConformanceProtocolNames(_:)` returning the inheritance-clause
protocol names of the nearest enclosing `ExtensionDeclSyntax` / type decl.
Used by #2c (Compound rule's protocol-required-method allowlist) which lives
in the same Naming target.

**Cross-target note**: #4 (Throws), #8 (Tagged in RawValue pack), #9 (Platform)
live in different rule packs / different packages. They each need their own
inline conformance-context walker because Naming.Shared.swift is internal to
the Naming target. Future refactor: extract a shared `Linter Rule Helpers`
target visible to all rule packs across tiers. Out of scope for Wave 2.

Existing helper `namingIsInsideConformingContext` stays unchanged; the new helper
is the lookup-form companion.

### #2 — Compound rule — three sub-amendments

**Tier**: institute (Naming pack lives in swift-institute-linter-rules)
**File**: `Sources/Linter Rule Naming/Lint.Rule.Naming.Compound.swift`
**Depends on**: #1 (for sub-amendment c)
**Status**: LANDED 2026-05-11 (UNCOMMITTED — same package as #1)

**Empirical drop**: swift-either-primitives 6 → 0 (all 6 were `flatMap`).

a. **Swift-native vocabulary citation dict** (Option B): rename
   `namingCompoundStdlibIdiomNames: Set<String>` → `namingCompoundSwiftNativeIdiomCitations: [String: String]`,
   seed with `"flatMap": "Swift.Optional.flatMap"` etc. Citation key required at write time.

b. **Local-var scope gate**: skip `VariableDeclSyntax` whose ancestor is
   `{FunctionDeclSyntax, InitializerDeclSyntax, AccessorDeclSyntax, ClosureExprSyntax,
   DeinitializerDeclSyntax, SubscriptDeclSyntax}` before any
   `{TypeDeclSyntax-shaped, ExtensionDeclSyntax}`. Local lets/vars are
   implementation detail, not public surface.

c. **Protocol-required-method allowlist**: new dict
   `namingCompoundProtocolWitnessMethodCitations: [String: String]` seeded with:
   - `"encodeAtomicRepresentation": "Swift.AtomicRepresentable.encodeAtomicRepresentation(_:)"`
   - `"decodeAtomicRepresentation": "Swift.AtomicRepresentable.decodeAtomicRepresentation(_:)"`
   - `"makeIterator": "Swift.Sequence.makeIterator()"`

   Exempt if name in dict AND `namingIsInsideConformingContext` returns true.

**Source signal**: either + property + tagged.

### #3 — MEM-COPY-004 — three sub-amendments

**Tier**: universal
**File**: `Sources/Linter Rule Memory/Lint.Rule.Memory.ExtensionNoncopyableConstraint.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 — commit `3baa419`. Pack walk widened from
`memberBlock` to entire `node` after first run missed pack types in
where clauses; refinement landed in same commit.

a. **Pack-expansion exemption**: add `MemoryExtensionPackExpansionFinder` parallel
   to `MemoryExtensionNoncopyableOwnershipFinder` (lines 50-79). Walk the
   extension memberBlock for `PackExpansionTypeSyntax` / `PackElementTypeSyntax`.
   If found, skip the warning. Parameter-pack types can't express `~Copyable each T`
   in Swift 6.x.

   *Known corner case (document but don't block on)*: body-wide gate exempts an
   extension on a non-pack generic type whose inner method declares its own pack
   (e.g., `extension Container<T> { consuming func zip<each U>(...) }`). Future
   tightening: scope pack detection to the same function carrying the
   consuming/borrowing modifier.

   *Sunset condition*: when Swift adopts `~Copyable each T`, re-examine.

b. **Positive-Copyable exemption**: add `whereClauseHasPositiveCopyable(_:)`
   parallel to existing `whereClauseHasNoncopyable(_:)` (lines 94-102). Walk
   `ConformanceRequirementSyntax`; right side trims to `Copyable` (no tilde) signals
   deliberate Copyable scoping. In visitor: exempt if either returns true.

c. **`* where *.swift` filename pattern**: before emitting, check
   `source.filePath.lastPathComponent.contains(" where ")`. If true, exempt — the
   author has named the file with its where-clause discriminator per [API-IMPL-007],
   making the constraint absence deliberate.

**Source signal**: product + property + carrier.

### #4 — Existential-throws — stdlib-witness citation dict

**Tier**: universal
**File**: `Sources/Linter Rule Throws/Lint.Rule.Throws.Existential.swift`
**Depends on**: nothing (but parallels #1's conformance-context check)
**Status**: LANDED 2026-05-11 — commit `8f49c35`. Inline conformance walker
(Naming Shared helper is internal to institute tier).

Add `throwsExistentialStdlibProtocolWitnessCitations: [String: String]`:
- `"init(from:)": "Swift.Decodable.init(from:) throws — protocol requirement is untyped"`
- `"encode(to:)": "Swift.Encodable.encode(to:) throws — protocol requirement is untyped"`

In `ThrowsExistentialVisitor.visit(ThrowsClauseSyntax)`: walk up to enclosing
`FunctionDeclSyntax`/`InitializerDeclSyntax`; build witness-key string; check
dict AND verify enclosing extension's `inheritanceClause` names the corresponding
stdlib protocol (Decodable/Encodable). Exempt if both match.

**Source signal**: product.

### #5 — Engine: `**/*.docc/**` default exclusion

**Tier**: engine (swift-linter, NOT swift-linter-rules)
**File**: `Sources/Linter Core/Lint.Source.Walker.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 — commit `86856c1` on swift-linter `lint-pass-audit-2026-05-11`

**Empirical drop**: swift-property-primitives 13→4; swift-carrier-primitives 17→4
(8 + 13 = 21 docc findings eliminated). Also surfaced glob bug: `**/*.docc/**`
exclusion doesn't fire correctly when directory names contain spaces; added
defensive path-substring post-filter as safety net. **TODO**: file separate
issue against swift-glob-primitives / swift-file-system for the space-handling
bug.

Engine's file-discovery pass excludes `**/*.docc/**` (entire DocC catalog tree,
not just Resources/) by default. DocC content is documentation rendered by DocC,
not compiled API surface.

Likely largest noise reduction in the queue (76% of carrier's findings; 53% of
property's). When dispatched, aggregate count drops sharply on its own.

**Source signal**: property (8 findings) + carrier (13 findings).

### #6 — Unification-typealias — gerund-as-capability exemption

**Tier**: institute (Naming pack)
**File**: `Sources/Linter Rule Naming/Lint.Rule.Naming.UnificationTypealias.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 (UNCOMMITTED — institute-linter-rules not git-init'd).
Inline check for `rhsLeaf == "Protocol" || rhsLeaf == "\`Protocol\`"`.

Exempt typealiases whose RHS targets a member named `Protocol` (raw or
backtick-escaped). Mechanical detection: `MemberTypeSyntax` whose final
component is identifier `Protocol`. This is the [PKG-NAME-001]
gerund-as-capability typealias pattern.

Suggested shared helper `isProtocolSentinelAlias(_:)` lives in
`Lint.Rule.Naming.Shared.swift` (alongside #1's helper), keyed on the
`Protocol` sentinel name.

**Source signal**: carrier.

### #7 — Minimal-type-body — Protocol-sentinel exemption

**Tier**: universal (Structure pack)
**File**: `Sources/Linter Rule Structure/Lint.Rule.Structure.MinimalTypeBody.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 — commit `a7bcd7a`. Inline check on both
`"Protocol"` and `"\`Protocol\`"` token text forms.

Exempt `TypealiasDeclSyntax` whose name token is `Protocol` (raw or backtick-escaped)
from the body-vs-extension check. The [API-IMPL-009] hoisted-protocol-with-typealias
pattern explicitly intends the typealias in the type body; forcing extraction yields
empty-body `enum X {}` + extension-with-one-typealias awkwardness for zero
semantic gain.

**Source signal**: carrier.

### #8 — Tagged-extension-public-init — protocol-witness citation dict

**Tier**: primitives (RawValue pack in swift-primitives-linter-rules)
**File**: `Sources/Linter Rule RawValue/Lint.Rule.RawValue.TaggedExtensionPublicInit.swift`
**Depends on**: nothing (inline inheritance walker)
**Status**: LANDED 2026-05-11 (UNCOMMITTED — primitives-linter-rules not git-init'd).
Dict includes 14 entries (9 ExpressibleByXLiteral + LosslessStringConvertible +
RawRepresentable + Decodable + Codable + Institute Protocol-sentinel).

Add `taggedExtensionPublicInitProtocolWitnessCitations: [String: String]` seeded:
- `"ExpressibleByIntegerLiteral": "Swift.ExpressibleByIntegerLiteral — init(integerLiteral:) protocol witness"`
- `"ExpressibleByFloatLiteral": "..."`
- 9 ExpressibleByXLiteral entries total
- `"LosslessStringConvertible": "Swift.LosslessStringConvertible — init?(_:) protocol witness"`
- `"Protocol": "Institute protocol witness (e.g., Carrier.Protocol)"`

Walk up `InitializerDeclSyntax` → `ExtensionDeclSyntax`; if `inheritanceClause`
names a protocol in the dict, exempt.

**Source signal**: tagged.

### #9 — Typealiased-namespace-bridge — associatedtype-satisfaction exemption

**Tier**: universal (Platform pack)
**File**: `Sources/Linter Rule Platform/Lint.Rule.Platform.TypealiasedNamespace.swift`
**Depends on**: nothing (inline conformance walker)
**Status**: LANDED 2026-05-11 — commit `fe010b9`.

Parallel to Wave 1 TIGHTEN on `unification_typealias` / `namespace_adoption_typealias`.
Typealias inside an `ExtensionDeclSyntax` with non-empty `inheritanceClause` → exempt;
the typealias satisfies an associatedtype requirement, not a foreign-namespace bridge.

Reuse existing `namingIsInsideConformingContext`.

**Source signal**: tagged.

### #10 — Mock-factory-zero-collision — scope + pattern tighten

**Tier**: universal (Testing pack)
**File**: `Sources/Linter Rule Testing/Lint.Rule.Testing.MockFactoryZeroCollision.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 — commit `dd7d56a`. Both fixes shipped:
per-rule `/Tests/` scope-limit + function-reference reshape rejection
(AsExprSyntax / MemberAccessExprSyntax).

Two complementary fixes:

a. **Per-rule scope-limit to `**/Tests/**`**: [TEST-028]'s intent is test-code
   hygiene; firing in `Sources/` is rule-scope leakage. Per-rule path-scope, NOT
   engine-level.

b. **Pattern tightening**: require integer-typed source AND pointer-wrapping
   `BitwiseCopyable` destination. The current detection misfires on
   `unsafeBitCast` of function references (variadic→non-variadic init function
   pointers).

**Source signal**: tagged.

### #11 — Tagged-unchecked PoC — preserve-shape exemption

**Tier**: PoC custom rule (in swift-tagged-primitives/Lint/)
**File**: `swift-primitives/swift-tagged-primitives/Lint/Sources/Linter Rule Tagged Domain Audit/Lint.Rule.TaggedDomainAudit.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 (UNCOMMITTED — Lint/ scaffold is gitignored
per HANDOFF Open Q1). Allowlist with `map` + `retag` keys; inline walker
to enclosing FunctionDeclSyntax.

### #14 — Minimal-type-body — @resultBuilder exemption

**Tier**: universal (Structure pack)
**File**: `Sources/Linter Rule Structure/Lint.Rule.Structure.MinimalTypeBody.swift`
**Status**: LANDED 2026-05-11 — commit `1f6ee78`. Two-layer check: visited type's
own attributes + nested-type's attributes during parent's checkMembers walk.
Empirical: swift-standard-library-extensions 234 findings cleared.

### #16 — ClosureTypedAnnotation — Result-materialization exemption

**Tier**: universal (Throws pack)
**File**: `Sources/Linter Rule Throws/Lint.Rule.Throws.ClosureAnnotation.swift`
**Status**: LANDED 2026-05-11 — commit `f295588`. A `try` inside an enclosing
`do { ... } catch { ... }` whose catch body contains no `ThrowStmt` is
non-propagating (materialization via return-form or side-effect-form).
Empirical: swift-standard-library-extensions 20 findings cleared.

### #17 (extension) — MEM-COPY-004 allowlist additions

**Status**: LANDED 2026-05-11 — commit `aa4f097`. Added Dictionary, Set,
String, Substring, Result to `memoryExtensionConstraintInexpressibleTypes`.

### #18 — BoolPublicParameter — conversion-init exemption

**Tier**: institute (Naming pack)
**File**: `Sources/Linter Rule Naming/Lint.Rule.Naming.BoolParameter.swift`
**Status**: LANDED 2026-05-11 (UNCOMMITTED — institute-linter-rules not git-init'd).
`init(_ x: Bool)` with single Bool parameter and wildcard first name = conversion
init. Exempt.

### #19 — SwiftQualification — stdlib-shadow extension exemption

**Tier**: universal (Platform pack)
**File**: `Sources/Linter Rule Platform/Lint.Rule.Platform.SwiftQualification.swift`
**Status**: LANDED 2026-05-11 — commit `6ab1541`. Inside `extension <X> { ... }`
where X is a stdlib type (Set, Array, Dictionary, etc.), `Swift.<Protocol>` is
structurally inexpressible due to Swift name resolution. Exempt.
Empirical: 1 finding cleared.

### #2 (extension) — Compound citation dict

**Status**: LANDED 2026-05-11 (UNCOMMITTED — institute-linter-rules). Added 18
stdlib with-helper / Result / Dictionary / uniqued entries to
`namingCompoundSwiftNativeIdiomCitations`.

### #15 — IMPL-010 Tier-0 stdlib-boundary opt-out

**Status**: LANDED 2026-05-11 (UNCOMMITTED — Lint/ scaffold gitignored per
HANDOFF Open Q1). No Linter Primitives change needed — `Lint.Rule.Configuration.disable(_:)`
already existed. swift-standard-library-extensions's `Lint/Sources/Lint/main.swift`
switched from `Lint.run(bundle: ...)` to `Lint.run(configuration: ...)` with
`Lint.Rule.Configuration.disable(.\`int public parameter\`)`.

**Empirical**: swift-standard-library-extensions 17 → 0. Wave 2 complete:
every leaf in the original triage order is either at 0 findings or holding
the 1 AMBIGUOUS finding pending [MEM-SAFE-025] reconciliation.

### #12 — Borrowing-self-short-circuit — operand-identifier root tracing

**Tier**: universal (Memory pack)
**File**: `Sources/Linter Rule Memory/Lint.Rule.Memory.BorrowingSelfShortCircuit.swift`
**Depends on**: nothing
**Status**: LANDED 2026-05-11 — commit `c7d5035`.

Surfaced by swift-equation-primitives (3 findings on operator bodies
that comply with the rule's own recommendation). Detection now collects
`borrowing Self` parameter names and traces each `&&` / `||` operand's
root identifier; only fires if the root is a borrowing-Self param,
exempting local lets and iteration variables.

**Source signal**: equation.

Add `taggedUncheckedExemptOperations: [String: String]`:
- `"map": "preserve-shape transform; closure output is opaque-by-construction"`
- `"retag": "phantom-tag swap; underlying validated upstream by Tagged construction invariant"`

Walk up to enclosing `FunctionDeclSyntax`; if name matches, exempt the
`_unchecked:` use site.

**Source signal**: tagged.

## Acceptance Criteria (Post-Dispatch)

**ALL 19 AMENDMENTS LANDED 2026-05-11.** Empirical verification across 10 leaves:

| Leaf | Pre-amendment | Expected | Actual | Status |
|---|---:|---:|---:|---|
| swift-either-primitives | 6 | 0 | **0** | ✓ |
| swift-product-primitives | 13 | 0 | **0** | ✓ |
| swift-property-primitives | 13 | 1 AMBIGUOUS | **1** | ✓ (Cluster E held for [MEM-SAFE-025]) |
| swift-carrier-primitives | 17 | 0 | **0** | ✓ |
| swift-tagged-primitives | 21 | 0 | **0** | ✓ |
| swift-comparison-primitives | 44 | 0 | **0** | ✓ (surfaced composition-Copyable + constraint-inexpressible refinements) |
| swift-hash-primitives | 46 | 0 | **0** | ✓ (zero new amendments — full coverage by queued threads) |
| swift-equation-primitives | 55 | 0 | **0** | ✓ (surfaced #12 borrowing-self-short-circuit) |
| swift-ownership-primitives | 39 | (SOURCE pending) | (subordinate queue) | partial — 19 SOURCE-WRONG in subordinate's queue |
| swift-standard-library-extensions | 620 → 321 → 22 | 0 | **0** | ✓ (#14 / #16 / #17-ext / #18 / #19 / #2-ext / #15 + 5 SOURCE-WRONG committed by subordinate) |

**Aggregate**: ~878 findings across 10 leaves → **0** (excluding the 1 [MEM-SAFE-025]
AMBIGUOUS held finding + the 19 SOURCE-WRONG in the subordinate's ownership queue).
**~99.9% reduction across the rule-amendable surface.**

**Held**: swift-property-primitives Property.Consume.State.swift:54
unchecked sendable categorization — entangled with [MEM-SAFE-025] policy
reconciliation. Three-tier partition doc § Out-of-scope follow-ups
already tracks the policy collision; this single finding is its concrete
instance. Resolution follows from [MEM-SAFE-025], not this Wave.

## Open Questions

1. **Shared helper file location** for #6/#7's `isProtocolSentinelAlias`. Default:
   add to `Lint.Rule.Naming.Shared.swift` (same file as #1's helper). Alternative:
   new sibling `Lint.Rule.Shared.swift` if scope crosses naming-rule boundaries.

2. **Rule file paths for #7/#8/#9/#10/#11** — need verification before edit;
   the per-rule file paths in this ledger are educated guesses based on the
   institute's per-rule one-file convention.

3. **Engine docc-exclusion CLI override** — `--include-docc` flag for leaves
   that genuinely want to scan docc content. Defer to follow-up unless a
   real use case surfaces.

## References

- HANDOFF.md (workspace root): Wave 2 per-leaf-package triage dispatch
- Per-leaf reports: `lint-pass-2026-05-11-swift-*-primitives.md`
- Aggregate: `lint-pass-2026-05-11-aggregate.md`
- Wave 1 TIGHTEN precedent: `namingIsInsideConformingContext` in
  `Sources/Linter Rule Naming/Lint.Rule.Naming.Shared.swift`
- Tier partition: `swift-institute/Research/three-tier-linter-rules-partition.md` v0.1.0
