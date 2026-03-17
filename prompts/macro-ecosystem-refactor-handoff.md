# Handoff: Macro Ecosystem Refactor

## Status as of 2026-03-17

### What was built this session

| Package | Location | Status |
|---------|----------|--------|
| `swift-dual` | `/Users/coen/Developer/swift-foundations/swift-dual/` | Done, pushed to `coenttb/swift-dual` (private). 30 tests. |
| `swift-defunctionalize` | `/Users/coen/Developer/swift-foundations/swift-defunctionalize/` | Done, pushed to `coenttb/swift-defunctionalize` (private). 18 tests. |
| `swift-witnesses` | `/Users/coen/Developer/swift-foundations/swift-witnesses/` | Refactored: `Action` → `Calls`, Result/Outcome moved to siblings of Calls. 132 tests. Pushed. |
| `burgerlijk-wetboek-boek-2` | `/Users/coen/Developer/swift-nl-wetgever/burgerlijk-wetboek-boek-2/` | `@Dual` added to all 203 Arguments structs. Pushed to `coenttb/burgerlijk-wetboek-boek-2` (private). |

### What @Dual does

- **Struct → enum**: `T.Dual` with one case per stored property (literal types preserved). Extraction properties, `Case` discriminant (`Finite.Enumerable`), Prisms, `is(_:)`, `subscript[prism:]`, `modify(_:_:)`. Homogeneous `subscript(case:)` when all properties share the same type. Empty structs produce uninhabited Dual enum.
- **Enum → struct**: `T.Dual<R>` (Scott encoding) with one handler closure per case + `match` function. Same enum infrastructure.
- Handles backtick-escaped identifiers (keywords, space-containing Dutch legal text). Key insight: `TokenSyntax.text` returns text WITH backticks — do NOT re-escape.

### What @Defunctionalize does

- **Struct with closures → enum**: `T.Calls` with one case per closure property, associated values = closure PARAMETERS (not the closure itself). Non-function fields excluded. Effects (async/throws) excluded. Same enum infrastructure as @Dual.
- Enum input = error diagnostic.
- Leading underscore stripping for case names.

### Converged architecture (from experiment + research)

Two primary user-facing macros (mirrors PointFree's `@CasePathable` + `@DependencyClient`):

| Use case | Macro | What you get |
|----------|-------|-------------|
| Witness struct for DI | `@Witness` | `T.Calls` (defunctionalized) + observe + unimplemented + mock + methods + init |
| Enum with infrastructure | `@Dual` | `T.Dual<R>` (Scott encoding) + match + extraction + Case + Prisms |
| Statute questionnaire | `@Dual` | `T.Dual` enum + homogeneous subscript for Bool? access by case |
| Pure call algebra (no DI) | `@Defunctionalize` | `T.Calls` only (niche/academic) |

One macro per type. Never stack for common cases. @Defunctionalize exists as independent primitive but isn't primary.

---

## What remains to do

### 1. Eliminate shared codegen duplication

**Problem**: PrismCodegen, CaseDiscriminantCodegen, ExtractionCodegen, Utilities are duplicated across swift-dual, swift-defunctionalize, and swift-witnesses (3 copies).

**Agreed direction**: NOT a generic "codegen" package. Instead, two L3 packages aligned with the concepts they generate code for:

**swift-optics** (L3):
- PrismCodegen (`PrismCase`, `generatePrism`)
- `generatePrismsStruct` (assembles Prisms struct)
- `generatePrismAccessors` (`is(_:)`, `subscript[prism:]`, `modify(_:_:)`)
- `generateExtractionProperty` (the extract half of a prism)
- Depends on: SwiftSyntax (macro-only dependency)
- Generated code references: `Optic_Primitives.Optic.Prism`, `__OpticPrismAccessible`

**swift-finites** (L3):
- CaseDiscriminantCodegen (`generateCaseDiscriminant`)
- `generateCaseProperty` (`var case: Case`)
- Depends on: SwiftSyntax
- Generated code references: `Finite_Primitives.Finite.Enumerable`, `Ordinal_Primitives.Ordinal`, `Cardinal_Primitives.Cardinal`

**Inline in each consumer** (4 tiny helpers, not worth a package):
- `hasRestrictedAccess`, `canInline`, `isSendable`, `isPublicDecl`

**Open question**: These are macro implementation libraries (SwiftSyntax-dependent). They generate STRING-based source code that references the L1 primitives but don't import them. The naming needs care — `swift-optics` at L3 is a macro package that generates optic code, distinct from `swift-optic-primitives` at L1 which defines the runtime types. Consider: `swift-optic-macros`? `swift-optics`? Naming not settled.

### 2. Remove @Witness enum support

**Research**: `swift-institute/Research/witness-enum-direction-and-dual.md` — recommends Option A (remove entirely).

**Rationale**: @Dual now generates everything @Witness generated on enums, plus the Scott encoding. @Witness on enums is a strict subset, redundant.

**Implementation**: Delete `expandEnum` path from `WitnessMacro.swift`. Remove `noEnumCases` diagnostic. Update `WitnessDiagnostic` to have `requiresStruct` instead of `requiresStructOrEnum`. Update tests.

### 3. Unify Result and Outcome

**Research**: `swift-institute/Research/witness-result-outcome-unification.md` — recommends Option B (unified Outcome with arguments + result per case, eliminating Result).

**Current**:
```swift
enum Result: ~Copyable { case fetch(Result<String, Never>) }
struct Outcome: ~Copyable { let action: Calls; let result: Result }
```

**Proposed**:
```swift
enum Outcome: ~Copyable {
    case fetch(id: Int, Result<String, Never>)
    case save(data: String, Result<Bool, SaveError>)
}
```

One type instead of two. Result has no independent consumers.

### 4. Other BW boeken

Boeken 3–10 presumably have the same Arguments pattern and could get `@Dual`. Mechanical: add dependency + `@Dual` annotation to each Arguments struct. Same pattern as boek 2.

---

## Research documents produced

| Document | Location | Status |
|----------|----------|--------|
| Converged decomposition plan | `swift-institute/Research/dual-defunctionalize-decomposition.md` | CONVERGED (prior session) |
| Discussion transcript | `swift-institute/Research/dual-defunctionalize-discussion-transcript.md` | CONVERGED (prior session) |
| @Dual implementation handoff | `swift-institute/Research/prompts/swift-dual-implementation.md` | IMPLEMENTED |
| Literature survey | `swift-witnesses/Research/action-type-naming.md` | SUPERSEDED by decomposition |
| @Witness enum direction | `swift-institute/Research/witness-enum-direction-and-dual.md` | RECOMMENDATION: remove |
| Shared codegen primitives | `swift-institute/Research/enum-infrastructure-primitives.md` | RECOMMENDATION: L3 packages |
| Result/Outcome unification | `swift-institute/Research/witness-result-outcome-unification.md` | RECOMMENDATION: unify |
| Macro composition architecture | `swift-institute/Research/macro-composition-architecture.md` | RECOMMENDATION: Option F + D |
| Calls/Result sibling experiment | `swift-witnesses/Experiments/calls-result-sibling/` | CONFIRMED |
| Composition experiment | `swift-institute/Experiments/dual-defunctionalize-composition/` | CONFIRMED: Variant 5 |

---

## Key decisions and insights from this session

1. **`TokenSyntax.text` includes backticks** — the handoff said it doesn't. It does. Don't re-escape AST-derived identifiers.

2. **Empty structs are valid for @Dual** — the categorical dual of the unit type is the void type (uninhabited enum). CaseDiscriminant handles count=0 with `fatalError` in init.

3. **`(@Sendable (Int) -> String)?`** not `@Sendable (Int) -> String?` — extraction properties must wrap type in parens before making Optional.

4. **`count` as a property name conflicts with `Finite.Enumerable.count`** — test fixture renamed to `total`. This is an edge case users could hit.

5. **Result/Outcome as siblings, not nested in Calls** — makes T.Calls structurally identical to @Defunctionalize output. No Swift.Result naming collision because generated code uses fully-qualified `Standard_Library_Extensions.Result`.

6. **The defunctionalized form is more useful than the literal dual for witness structs** — but @Witness already generates it. @Dual serves the structural/questionnaire use cases.

---

## Suggested implementation order for next session

1. Create swift-optics and swift-finites (L3 macro codegen packages)
2. Migrate swift-dual, swift-defunctionalize, swift-witnesses to import them
3. Remove @Witness enum support
4. Unify Result/Outcome
5. Add @Dual to other BW boeken
