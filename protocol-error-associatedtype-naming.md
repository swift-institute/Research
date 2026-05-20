# Protocol Error Associatedtype Naming and Nested-Error Collision

<!--
---
version: 1.0.0
last_updated: 2026-05-21
status: RECOMMENDATION
---
-->

## Context

The byte-discipline arc (`byte-protocol-capability-marker.md` v1.1.0,
`broader-l2-l3-byte-typing-gap-plan.md`) shipped `Byte.\`Protocol\`` with
an `associatedtype Error: Swift.Error = Never` and a typed-throws init:

```swift
extension Byte {
    public protocol `Protocol` {
        associatedtype Domain: ~Copyable = Never
        associatedtype Error: Swift.Error = Never
        var byte: Byte { get }
        init(_ byte: Byte) throws(Self.Error)
    }
}
```

The pattern's load-bearing property: universal-domain conformers (`Byte`
itself, `Tagged<Tag, Byte>`) inherit `Error == Never` and Swift 6 treats
`throws(Never)` as non-throwing at call sites. Refined conformers
(`ASCII.Code`) declare a concrete `Error` and the throws surfaces.

The deep-dive in `ecosystem-associatedtype-error-inventory.md` v1.1.0
classified `Ordinal.\`Protocol\`` and `Color.\`Protocol\`` as FITS-cleanly
candidates and recommended Arc 1 / Arc 2 execution. Execution of Arc 1
on 2026-05-21 hit a structural collision the deep-dive did not anticipate:
**the universal conformers for both protocols have a pre-existing nested
`.Error` enum that Swift resolves as the protocol's associated-type
witness**, NOT the default `Never`. The `Error == Never` gates that the
byte-discipline pattern relies on (`zero` / `max` defaults, ecosystem
extensions like `Atomic+Ordinal`, `Swift.Range+Ordinal.init(start:count:)`)
become unsatisfiable for `Ordinal` itself.

This research closes the AT-naming question for the family of
typed-throws-bearing protocols (Byte / Ordinal / Color / future
Cardinal-bounded / future Char / Codepoint / Word / Line / etc.) and
documents the structural constraint Swift's name-lookup imposes on the
choice.

## Question

**Q**: When adopting the `associatedtype Error: Swift.Error = Never`
typed-throws pattern on a capability-marker protocol whose
universal-domain conformer has a pre-existing nested `Error` enum
(carrying operation-domain failures, not construction failures), which
of the following is the ecosystem-canonical resolution?

- **A**: Name the AT `Failure` (Parser/Serializer/Coder/Command precedent)
- **B**: Rename the pre-existing nested `Error` enum to free the
  `Error` name for the AT (byte-discipline precedent)
- **C**: Keep the AT name as `Error` and accept the existing nested enum
  as the AT witness, then audit downstream consequences (changes call-site
  semantics)
- **D**: Bifurcate the convention by capability (Byte family uses Error;
  Ordinal/Color families use Failure) — explicit per-protocol choice

The decision must satisfy three structural constraints simultaneously:

1. Universal-domain conformers must be reachable as `Error == Never`
   (or whatever the AT's "no-failure" sentinel is) so the gated defaults
   (`zero`, `max`, ecosystem `+` operators, `Atomic` extensions, etc.)
   apply.
2. Refined-domain conformers must be able to declare a concrete typed
   error.
3. Pre-existing nested enums (`Ordinal.Error`, `Color.Error`, future
   instances) must not be silently re-purposed as AT witnesses if their
   semantics don't match (Ordinal.Error carries `.overflow` /
   `.notForward` operation failures, not construction failures).

## Analysis

### Structural fact: Swift's name-lookup precedence

When a conforming type has a nested type at the same name as a protocol
associatedtype, Swift's name resolution binds the associatedtype witness
to the nested type — the AT's default is overridden. Verified empirically
during the 2026-05-21 build:

```swift
// Ordinal.Error.swift — pre-existing, predates the migration:
extension Ordinal {
    public enum Error: Swift.Error, Hashable, Sendable {
        case overflow, underflow, negativeSource(Int), notForward
    }
}

// Ordinal.Protocol.swift — proposed migration:
extension Ordinal {
    public protocol `Protocol` {
        associatedtype Error: Swift.Error = Never  // default ignored
        init(_ ordinal: Ordinal) throws(Self.Error)
    }
}

extension Ordinal: Ordinal.`Protocol` { ... }
// `Ordinal.Error` resolves to the nested enum (above), NOT to Never.
// `Self.Error` in the init's throws clause = Ordinal.Error.
```

Confirmation comes from the ASCII.Code precedent doc-comment, which
explicitly enumerates the structural rule (`ASCII.Code+Byte.Protocol.swift:44-47`):

> *"... no explicit `typealias Error = ...` is declared here because
> that would conflict with the nested-enum name in `ASCII.Code`'s scope
> (Swift rejects member duplication across typealias and nested type)."*

The compiler enforces this in both directions:
- A nested `Error` enum prevents adding an explicit `typealias Error = Never`
- A nested `Error` enum overrides the AT's default value when the
  conformance is declared

The byte-discipline arc avoided the collision **only because Byte did not
have a pre-existing nested `Byte.Error` enum**. The pattern's portability
depends on that contingent fact.

### Affected protocols across the ecosystem (verified)

| Protocol | Universal-conformer nested .Error exists? | Semantics of nested .Error |
|---|---|---|
| `Byte.\`Protocol\`` | NO (Byte has no nested Error) | n/a |
| `Ordinal.\`Protocol\`` | YES (`Ordinal.Error.swift:8`) | Operation failures: `.overflow`, `.underflow`, `.negativeSource`, `.notForward` |
| `Color.\`Protocol\`` | YES (`Color.Error.swift:8`) | Construction failures: `.outOfGamut`, `.unsupportedColorSpace`, `.invalidComponent` |
| `Cardinal.\`Protocol\`` (if hoisted as sibling) | YES (`Cardinal.Error.swift`) | Construction failures: `.negativeSource(Int)` |
| Future `Char.\`Protocol\`` / `Codepoint.\`Protocol\`` / etc. | Unknown — depends on future package shape | n/a |

For Color the existing nested Error happens to align semantically with
construction failures, so re-purposing it as the AT witness is
*semantically* plausible — but doing so would force every consumer of
`Color: Color.\`Protocol\`` (the universal-domain self-conformer) to write
`try Color(canonicalColor)` even though that path is identity-total. The
collision corrupts the self-conformer's call-site ergonomics.

For Ordinal the existing nested Error is for operation failures
(`.overflow` on `advance.exact`, `.notForward` on `distance.forward`).
Re-purposing it as the construction-error AT witness is *semantically
wrong* — these are different concept families.

### Prior art across the ecosystem

| Protocol family | AT name | Pre-existing nested Error on conformer? | Notes |
|---|---|---|---|
| Byte.\`Protocol\` | `Error` (with `= Never` default) | NO (Byte has none) | Pattern works because of contingent absence |
| Parser.\`Protocol\` | `Failure` (with `= Never` default) | n/a — conformers vary | No collision because `Failure` is rare as a nested type name |
| Serializer.\`Protocol\` | `Failure` (with `= Never` default) | n/a | Same as Parser |
| Coder.\`Protocol\` | `Failure` (inherited; with `= Never` default) | n/a | Refines Parser + Serializer |
| Command.\`Protocol\` | `Failure` (with `= Command.Error` default) | n/a | Default differs (every command can fail) |
| Memory.Allocator.\`Protocol\` | `Error` (NO default) | n/a — concrete allocators rarely have a different nested type | Pre-existing |
| Lexer.Pull.Tokens | `Error` (NO default) | n/a | Pre-existing |
| Formatter.\`Protocol\` | `Failure` (NO default) | n/a | Pre-existing |

**Observation**: the ecosystem is already split. 4 protocols
(Parser/Serializer/Coder/Command + Command.Schema.Visitor + Formatter)
use `Failure`; 3 protocols (Byte + Memory.Allocator + Lexer.Pull.Tokens)
+ deprecated Binary.ASCII.Serializable use `Error`. The byte-discipline
arc made an explicit choice to use `Error` over `Failure`, but the
arc's rationale didn't anticipate the nested-Error collision on future
sibling protocols.

### Prior art outside the ecosystem (Tier 2 [RES-021] survey)

| System | Typed-throws AT name | Rationale |
|---|---|---|
| Swift stdlib `Result<Success, Failure>` | `Failure` | Established stdlib convention; SE-0235 |
| Swift stdlib `AsyncSequence` (modern) | `Failure` | SE-0421 typed throws extension to AsyncSequence; matches Result |
| Swift `_Concurrency.Clock` | (no error AT; uses untyped `throws`) | Pre-typed-throws design |
| SE-0413 typed throws | mixed; the proposal uses `Failure` for closures (`(Error) -> T` thunks) and `Error` for the existential-equivalent slot | The proposal's text uses both names depending on context |
| Rust `Result<T, E>` | `E` (generic param convention; no name) | n/a for Swift comparison |
| Rust `Try<Output, Residual>` / `FromResidual<R>` | residual-pattern name | n/a |
| Java `throws ExceptionType` | concrete exception types; no AT | n/a |

The Swift-side authoritative precedent — `Result<Success, Failure>` and
the modern `AsyncSequence` — uses `Failure`. The byte-discipline arc
diverged from this stdlib precedent.

### Option analysis

#### Option A — Name the AT `Failure` (align with Parser/Serializer + stdlib)

**Shape**:

```swift
extension Byte {
    public protocol `Protocol` {
        associatedtype Failure: Swift.Error = Never
        var byte: Byte { get }
        init(_ byte: Byte) throws(Self.Failure)
    }
}

extension ASCII.Code: Byte.`Protocol` {
    public typealias Failure = ASCII.Code.Error  // refined-conformer wires it
    public init(_ byte: Byte) throws(ASCII.Code.Error) { ... }
}
```

**Advantages**:
- Matches the Swift-side authoritative precedent (Result, AsyncSequence,
  Parser, Serializer, Coder, Command, Command.Schema.Visitor, Formatter).
  Aligns 7 institute protocols + 2 stdlib types.
- The name `Failure` is rare as a nested type name; conformers'
  pre-existing nested `Error` enums don't collide.
- Refined conformers can still wire `typealias Failure = Self.Error`
  where `Self.Error` is the existing nested enum (the standard
  refinement pattern — wire the concrete error type to the abstract AT).
- The default `= Never` is reachable for universal conformers regardless
  of nested Error type presence.

**Disadvantages**:
- Diverges from the byte-discipline arc's already-published `Error`
  naming. Either:
  - **A.1** — Rename Byte.`Protocol`.Error to Byte.`Protocol`.Failure
    (breaking change to the just-published arc; touches ASCII.Code
    conformer; touches every Tagged-wrapper conformer). Worth doing
    because byte-discipline is fresh and downstream consumer count is
    small.
  - **A.2** — Leave Byte.`Protocol`.Error as-is; new protocols use
    Failure. Bifurcates the convention permanently.

**Recommendation within A**: A.1 (unify on Failure across the family).
Byte.`Protocol` is new enough that the rename cost is bounded; the
long-term cost of a bifurcated convention is unbounded.

**Cost**:
- A.1: ~5 files in swift-byte-primitives (Byte.Protocol.swift, default
  impls), ~3 files in swift-ascii-primitives (ASCII.Code conformance),
  one find/replace across each. Verifiable via grep.
- A.2: zero immediate cost, but the bifurcation drifts forever — future
  agents have to remember which family a protocol belongs to.

#### Option B — Rename pre-existing nested `Error` enums

**Shape**: Each conformer's pre-existing nested `.Error` enum is renamed
to free the `Error` name for the AT.

```swift
// Was Ordinal.Error; rename to Ordinal.OperationError (or similar):
extension Ordinal {
    public enum OperationError: Swift.Error, Hashable, Sendable {
        case overflow, underflow, negativeSource(Int), notForward
    }
}

extension Ordinal: Ordinal.`Protocol` {
    // Error defaults to Never; works correctly now.
}
```

**Advantages**:
- Preserves the byte-discipline arc's `Error` naming.
- Semantically cleaner: operation-domain failures and
  construction-domain failures get different names.
- Composes with [API-NAME-002] nested-accessor discipline — operation
  errors could live under their operation: `Ordinal.Advance.Error`,
  `Ordinal.Distance.Error` — even better.

**Disadvantages**:
- Cascade cost: ~42 sites in swift-ordinal-primitives Sources+Tests, ~38
  files workspace-wide reference `Ordinal.Error`. The Color side
  cascade is smaller but real (Color.Error is referenced from the
  conformer +sRGB.swift and from foundations consumers).
- Per-package per-conformer one-off; the discipline doesn't
  generalize — every future capability-marker protocol arc would need
  to first audit the conformer's existing nested types and rename them
  if there's a collision.
- Doesn't fix the underlying problem: future agents adding a
  capability-marker protocol will rediscover the issue at every new
  package boundary.

**Cost**:
- Per affected protocol: ~40-80 sites of mechanical rename. Color is
  manageable (1 conformer + handful of consumers). Ordinal is
  substantial (42 + 38 sites = significant scope expansion of the
  originally-recommended Arc 1).

#### Option C — Accept nested Error as the AT witness

**Shape**: No rename. `Ordinal.Error` IS the AT witness for `Ordinal:
Ordinal.\`Protocol\``. Every construction-call site of `Ordinal` now
needs `try` and a `do/catch` clause for the operation-domain error
cases.

**Advantages**: Zero structural rename cost.

**Disadvantages**:
- Semantically wrong: operation failures should not gate construction.
- Massive call-site cost: every `Ordinal(rawValue)` and `Ordinal(otherOrdinal)`
  in the ecosystem (hundreds of sites) needs `try`.
- The universal-conformer ergonomic property (`throws(Never)` ≡
  non-throwing) is lost — `Ordinal` becomes a throwing-construction
  type even though it's structurally total over its raw-integer domain.

**Verdict**: Rejected. The cost-benefit is upside-down.

#### Option D — Bifurcate per-protocol

**Shape**: Each protocol arc picks `Error` or `Failure` based on whether
the conformer has a nested collision; the convention drifts
case-by-case.

**Advantages**: Maximum local flexibility.

**Disadvantages**:
- Convention drift is a known pathology in the institute (per
  reflections on "domain-phrase isn't a carve-out", supervisor patterns,
  etc.). Two-name-for-one-concept is exactly the readability cost the
  institute's naming conventions exist to prevent.
- Every future agent has to remember per-protocol which name is in
  force, defeating the value of having a convention at all.

**Verdict**: Rejected.

### Comparison table

| Criterion | A (rename AT to Failure) | B (rename nested enums) | C (accept nested as AT) | D (bifurcate) |
|---|---|---|---|---|
| Aligns with Swift stdlib | YES (Result/AsyncSequence) | NO (diverges) | NO (diverges) | mixed |
| Aligns with institute Parser/Serializer family | YES (7 protocols already use Failure) | NO (would diverge) | NO | mixed |
| Compatible with byte-discipline arc's Error naming | NO (A.1 renames; A.2 bifurcates) | YES | YES | mixed |
| Cost on Ordinal arc | ~5 files (A.1) | ~80 sites | massive | varies |
| Cost on Color arc | ~3 files (A.1) | ~20 sites | substantial | varies |
| Sustainability for future capability-markers | excellent (no collision shape) | poor (rediscovered per package) | n/a | none |
| Preserves universal-conformer ergonomics | YES | YES | NO | depends |
| Single ecosystem-wide convention | YES (A.1) / NO (A.2) | YES | YES | NO |
| Reusable by future agents without case analysis | YES (A.1) | NO | NO | NO |

## Constraints

1. The byte-discipline arc has already shipped at
   `swift-byte-primitives@3f3b44a` with the `Error` AT name. Changing
   it is a breaking change to that arc's public API.
2. The ASCII.Code conformer in swift-ascii-primitives wires `Error =
   ASCII.Code.Error`. Renaming the AT to `Failure` requires updating
   that conformance.
3. Tagged conformance in `Tagged+Byte.Protocol.swift` declares
   `typealias Error = Underlying.Error`. Same update.
4. The Parser/Serializer/Coder/Command family is established and
   would not change under any option.

## Outcome

**Status**: RECOMMENDATION (pending principal decision).

**Recommendation**: **Option A.1 — rename the AT to `Failure` across
the capability-marker family, including the existing byte-discipline arc's
Byte.`Protocol`.**

**Rationale**:

1. **Sustainability**: A.1 is the only option where future
   capability-marker protocols (Char, Codepoint, Word, Line, Cardinal-
   bounded, future others) work without per-protocol case analysis.
   Every other option pushes the cost onto every future agent.
2. **Alignment**: A.1 aligns the institute's capability-marker family
   with the Parser/Serializer/Coder/Command family (7 protocols) AND
   with the Swift stdlib (Result, AsyncSequence). The ecosystem
   converges to one name.
3. **Bounded cost on the published arc**: Byte.`Protocol`'s AT was
   shipped 2026-05-15 and has exactly one refined conformer
   (ASCII.Code) plus the Tagged-recursive extension. The rename cost
   is ~5-8 files, all in primitives packages, with a mechanical find/
   replace. Per [feedback_correctness_and_evergreen.md], pre-1.0
   correctness reshaping is appropriate here.
4. **Semantic clarity**: `Failure` names the construction-failure type
   distinctly from operation-domain errors. The nested `Ordinal.Error`
   /`Color.Error` enums can remain in their natural homes carrying
   operation-domain semantics; the protocol AT carries construction
   semantics under a different name. No collision; no ambiguity.

**Sub-decisions if A.1 is approved**:

- The default `Failure = Never` matches Parser/Serializer/Command.Schema
  .Visitor convention.
- The `throws(Self.Failure)` clause on the init is the load-bearing
  property; gated default impls use `where Failure == Never`.
- Tagged recursive conformance: `typealias Failure = Underlying.Failure`.
- Refined conformers wire `typealias Failure = Self.Error` (or
  `typealias Failure = SomeOtherErrorType`) per-conformer.

**Execution sequencing if A.1 is approved**:

1. **Wave 0 (skill update)**: Update `byte-discipline` skill rules
   `[API-BYTE-001…007]` to use `Failure` (currently say `Error`). Update
   the capability-marker recipe in `code-surface` skill `[API-NAME-001c]`.
   This is a documentation rename; no code.
2. **Wave 1 (byte-discipline rename)**: Rename `Error` → `Failure` in
   `swift-byte-primitives`: `Byte.Protocol.swift`, `Tagged+Byte.Protocol.swift`,
   and any default-impl gates. Rename `Error` → `Failure` in
   `swift-ascii-primitives`: `ASCII.Code+Byte.Protocol.swift` (the
   `typealias Error = ...` line becomes `typealias Failure = ...`).
3. **Wave 2 (Ordinal migration per inventory's Arc 1)**: Now executes
   cleanly. The Ordinal.Error nested enum (operation errors) remains
   untouched. The protocol gets a Failure AT.
4. **Wave 3 (Color migration per inventory's Arc 2)**: Same pattern.
   Color.Error nested enum stays as-is (its cases work fine as
   construction failures, so the sRGB conformer would wire
   `typealias Failure = Color.Error`). The protocol gets a Failure AT;
   the self-conformer's default `Never` kicks in cleanly.

**Estimated total wave count**: 4 waves across 3 packages
(swift-byte-primitives, swift-ascii-primitives, swift-ordinal-primitives,
swift-color-standard) + skill updates. The byte-discipline rename
(Wave 1) is the only non-trivial-but-clean piece — the rest follow the
Parser/Serializer/Coder pattern that's already established.

**Alternative path if A.1 is rejected**: B is the next-best option.
Bifurcation (A.2 / D) and accepting-nested-as-AT (C) are rejected.

## Open questions

### OQ1 — Does the byte-discipline arc's `Error` naming have load-bearing skill content beyond the AT name?

The byte-discipline skill rules `[API-BYTE-001…007]` reference `Error`
in the pattern shape. If the principal selects A.1, the skill update
(Wave 0) needs to rename across all 7 rules + the capability-marker
recipe in `code-surface`. Mechanical but worth flagging — does anything
break if the rules say `Failure` instead?

Spot check: the rules describe the *pattern shape*, not a specific
field name. The rename is purely cosmetic across the rule corpus.

### OQ2 — Should refined-conformer wiring be `typealias Failure = Self.Error` (re-use the conformer's own nested Error enum name) or `typealias Failure = SomethingDistinct`?

For Color's sRGB conformer, the existing `Color.Error` enum has
construction-failure cases that fit. Two options:

- **a**: Wire `typealias Failure = Color.Error` on sRGB — sharing the
  Color.Error vocabulary across the family.
- **b**: Give sRGB its own `IEC_61966.\`2\`.\`1\`.sRGB.Error` enum and
  wire `typealias Failure = IEC_61966.\`2\`.\`1\`.sRGB.Error`.

The first is what the byte-discipline pattern does (ASCII.Code wires to
ASCII.Code.Error which is the conformer's own nested enum). The second
gives each conformer per-conformer error vocabulary. The current
codebase has the former shape for Color (the existing Color.Error works
for sRGB out of the box) — recommend keeping it.

### OQ3 — Does this finding mean the byte-discipline skill rules need a fact-check on the contingent-absence reasoning?

The byte-discipline arc's pattern was published assuming the `Error` AT
name would generalize. This finding shows it doesn't generalize without
the contingent absence of a nested Error on the universal conformer.
The skill rule `[API-NAME-001c]` (capability-marker recipe) should
include a note about the AT name choice, regardless of which option is
selected.

## References

- Originating arc commits: `swift-byte-primitives@3f3b44a`,
  `swift-ascii-primitives@68605eb`
- Prior research:
  - `byte-protocol-capability-marker.md` v1.1.0 (Q1 sibling-form
    anchor; doesn't address AT name choice)
  - `byte-arithmetic-conformance.md` v1.0.0 (Q3 Byte ≢ arithmetic;
    parallel)
  - `ecosystem-associatedtype-error-inventory.md` v1.1.0 (the inventory
    + triage; this doc opens after Arc 1 execution hit the collision)
  - `typed-throws-standards-inventory.md` v1.0.0 (orthogonal —
    untyped-throws on Codable/Clock; doesn't address AT naming)
  - `codable-untyped-throws-disposition.md` (related; canonical-attachment
    pattern delegates Error)
- Skill rules:
  - `byte-discipline` skill `[API-BYTE-001…007]` (currently references `Error`)
  - `code-surface` skill `[API-NAME-001c]` capability-marker recipe
    (currently references `Error`)
  - `code-surface` skill `[API-ERR-001]` typed throws required
- Pre-existing nested .Error enums verified:
  - `swift-ordinal-primitives/Sources/Ordinal Primitives Core/Ordinal.Error.swift:8`
  - `swift-color-standard/Sources/Color Standard/Color.Error.swift:8`
  - `swift-cardinal-primitives/.../Cardinal.Error.swift` (referenced by
    `init(_:Int)` negative-source path)
- ASCII.Code precedent on Swift's typealias-vs-nested-type rejection:
  `swift-ascii-primitives/Sources/ASCII Primitives/ASCII.Code+Byte.Protocol.swift:44-47`
- Swift stdlib references (Tier 2 [RES-021] survey):
  - Swift Evolution SE-0235 (Result, Failure naming)
  - Swift Evolution SE-0421 (AsyncSequence with typed throws, Failure)
  - Swift Evolution SE-0413 (typed throws — uses both Error and Failure
    in different contexts)
