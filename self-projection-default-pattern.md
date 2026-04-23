# Self-Projection Default Pattern

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

The frozen DECISION at
`swift-primitives/Research/ownership-borrow-protocol-unification.md`
(v1.0.0, 2026-04-22, tier 2, cross-package) restructures the `Viewable`
protocol as `Ownership.Borrow.\`Protocol\`` with an associatedtype
`Borrowed` that defaults to `Ownership.Borrow<Self>`. The decisive
finding (V8 + V8_PathC + V10 in the Borrow experiment) was that this
"the protocol's projection associatedtype defaults to the sibling
generic struct over Self" shape compiles, conformance sites read
naturally without the generic argument, and Tagged forwarding works
parametrically.

The Borrow application is the FIRST instance of this shape in the
ecosystem. Generalizing from one example is unsafe: there is no
empirical basis for predicting whether the shape applies to other
namespaces, what the failure modes look like, or where the
preconditions break. This document supplies that empirical basis by
testing the meta-pattern against five additional candidate shapes and
classifying each as FITS / DEGENERATE / DOES NOT FIT.

The empirical work lives in
`swift-primitives/Experiments/self-projection-default-pattern/`
(CONFIRMED on Apple Swift 6.3.1, 2026-04-22).

**Trigger**: [RES-012] Discovery — proactive characterization of a
meta-pattern derived from one production application, before further
applications proceed.

**Scope**: Cross-package (the candidates examined span ownership-
primitives, identity-primitives, property-primitives, hash-primitives,
and memory-primitives namespaces). [RES-002a]

**Tier**: 2 (Standard) — cross-package, characterizes a pattern that
will inform future API decisions across the primitives layer. Not tier
3 because the document does not establish a normative semantic
contract; it characterizes where an existing contract applies.
[RES-020]

## Question

Generalizing from the Ownership.Borrow application, the self-projection
default pattern is claimed as:

> Whenever a namespace `N` contains (a) a generic struct `N<Value: Cs_V>`
> and (b) a capability protocol `N.\`Protocol\`` expressing
> "conformers have an N-shaped projection of themselves," the protocol's
> associatedtype representing that projection can default to `N<Self>`.
> Constraint-compatibility: Self's suppressions on the protocol MUST
> be ⊆ Value's suppressions on the generic struct.

Three sub-questions:

1. **Where else does the shape FIT?** Are there candidate namespaces in
   the ecosystem (or natural mirrors of existing ones) where applying
   the pattern produces the same ergonomics as Borrow — opt-in
   one-liner conformance, free default, opt-in specialization?

2. **Where does the shape NOT FIT, and how does it fail?** What are the
   compile-time signatures of failure when preconditions are violated?

3. **Where does the shape DEGENERATE?** Are there namespaces that
   superficially fit the structural pattern (namespace + generic struct
   + protocol) but where the protocol's role differs enough that the
   "default = N<Self>" reading is nonsensical?

## Analysis

### Methodology

For each candidate shape, an experiment variant was authored at
`Experiments/self-projection-default-pattern/Sources/main.swift`. The
variant either compiles (CONFIRMED), fails to compile in a way that
isolates the precondition violation (REFUTED), or compiles partially
under structurally similar but semantically different shapes
(DEGENERATE / DOES NOT FIT).

Six variants were authored:

| Variant | Candidate shape | Verdict |
|---------|----------------|---------|
| V0 | Ownership.Borrow baseline | **FITS** (CONFIRMED) |
| V1 | Ownership.Mutate mirror (raw mutating pointer) | **FITS** (CONFIRMED, with narrower constraints) |
| V2 | Property<Tag, Base> two-param generic | **DOES NOT FIT** (REFUTED for the pure pattern; admits adjacent patterns) |
| V3 | Constraint-compatibility failure (deliberately mismatched suppressions) | **REFUTED** (diagnostic captured) |
| V4 | Hash-shape (namespace + protocol but no sibling generic) | **DEGENERATE** (CONFIRMED structurally; not the self-projection pattern) |
| V5 | Memory.Contiguous-shape structural lookalike (element-containment, not Self projection) | **DOES NOT FIT** (CONFIRMED structurally; protocol's associatedtype is not a projection of Self) |

### Candidate shape ↔ verdict ↔ rationale

#### V0 — Ownership.Borrow baseline (FITS)

The canonical instance, re-derived in this experiment for reference.
Single-parameter generic struct `V0_Ownership.Borrow<Value: ~Copyable & ~Escapable>`,
hoisted protocol `__V0_Borrow_Protocol` admitting `Self: ~Copyable, ~Escapable`,
nested typealias `Protocol = __V0_Borrow_Protocol` inside the struct
body, and associatedtype default `Borrowed = V0_Ownership.Borrow<Self>`.

A Case A conformer (`V0_Ordinal: ~Copyable, V0_Ownership.Borrow.\`Protocol\` {}`)
gets `Borrowed = V0_Ownership.Borrow<V0_Ordinal>` for free. A Case B
conformer (`V0_Path` with a custom `Path.Borrowed`) overrides the
default by declaring the nested type. Both compile-time probes resolve
correctly.

**Rationale for FITS**: this IS the pattern by definition. V0 establishes
the baseline against which other variants are compared.

#### V1 — Ownership.Mutate mirror (FITS, narrower constraints)

Exact structural mirror of V0 with `UnsafeMutableRawPointer` instead of
`UnsafeRawPointer`. Generic struct
`V1_Ownership.Mutate<Value: ~Copyable>: ~Copyable, ~Escapable`,
protocol admitting `Self: ~Copyable`, default
`Mutated = V1_Ownership.Mutate<Self>`.

**Discovery during implementation**: `UnsafeMutablePointer<Value>`
requires `Value: Escapable` on Swift 6.3.1, whereas
`UnsafePointer<Value>` admits `~Escapable` Value (with `@_lifetime`).
This is *not* a property of the meta-pattern — it is a property of the
specific pointer storage chosen — but it propagates through the
constraint-compatibility rule and forces the protocol's Self to also
admit only `~Copyable` (not `~Escapable`). Mirrors the ecosystem's
actual `Ownership.Inout<Value: ~Copyable>` declaration at
`swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Inout.swift:36`.

**Rationale for FITS**: the meta-pattern translates one-to-one across
the borrow / mutate / inout family. The narrowing of suppressions is a
storage-layer constraint that the pattern accommodates, not breaks.
The constraint-compatibility rule (Self ⊆ Value) acts as the
load-bearing mechanism that propagates storage-layer narrowness up into
the protocol's Self.

**Implication**: applying the pattern to a new sibling type
(`Mutate`, `Inout`, `Unique`, `Transfer.Storage`, etc.) requires
verifying that the storage layer's pointer family admits the same
suppressions the protocol intends to admit. This is mechanical to check
and predictable in advance.

#### V2 — Property<Tag, Base> two-param generic (DOES NOT FIT)

`swift-property-primitives/Property<Tag, Base: ~Copyable>` is a two-
parameter generic where neither Tag nor Base is uniquely "Self" in any
canonical sense. The pure self-projection default — *one* associatedtype
defaulting to `N<Self>` — has no resolution because the default
`= Property<???, Self>` leaves the missing parameter unresolved.

The experiment authors three sub-attempts, none of which is the pure
pattern:

- **V2a — fixed-Tag default**: `associatedtype Projection: ~Copyable = V2_Property<V2_TagA, Self>`.
  Compiles, but commits to a specific Tag value (`V2_TagA`) at the
  protocol level. This abandons the Tag parameter's purpose (per-tag
  namespacing) for the sake of a default — a categorically different
  trade-off from the pure pattern.

- **V2b — two associatedtypes**: `associatedtype Tag` AND
  `associatedtype Projection: ~Copyable = V2_Property<Tag, Self>`.
  Compiles. The conformer must declare Tag explicitly; in exchange, the
  default for Projection can adapt. This is a *richer* protocol than the
  self-projection default — two associatedtypes instead of one — and
  the conformer does more work at conformance sites. It is a valid
  pattern of its own (parametric self-projection over a per-conformer
  tag), but it is not the meta-pattern under study.

- **V2c — naive `Projection = Property<Self, Self>`** (not authored;
  documented for completeness): structurally compiles since neither Tag
  nor Base would reject Self, but semantically nonsense — Self
  occupying both Tag and Base has no design intent.

**Rationale for DOES NOT FIT**: the two-param structure is orthogonal to
the self-projection default's single-axis "projection of Self" reading.
None of V2a/V2b/V2c is the pure pattern. Property's two-param
namespace admits adjacent patterns (V2a's fixed-Tag, V2b's two-
associatedtype variant) but neither is interchangeable with the
self-projection default.

**Implication**: the self-projection default pattern does NOT generalize
to two-parameter generic structs. Any application of the pattern to
`Property` would require a categorical decision (e.g., commit to a
canonical Tag, accept the two-associatedtype shape) that goes beyond
the pattern's stated rules.

#### V3 — Constraint-compatibility failure (REFUTED with diagnostic)

The protocol admits `Self: ~Copyable, ~Escapable` while the generic
struct's `Value` is only `~Copyable`. The default `= Borrow<Self>`
fails to type-check at the substitution site:

```
error: type 'Self' does not conform to protocol 'Escapable'
       associatedtype Borrowed: ~Copyable, ~Escapable
                                           ^
       = V3_Ownership.Borrow<Self>
         ~~~~~~~~~~~~~~~~~~~~~~~~~
```

The experiment captures the diagnostic in a comment with the offending
default-line commented out (so the rest of the file compiles) and
demonstrates two recovery shapes:

1. **Drop the default**: the protocol compiles, but conformers must
   ALWAYS supply `Borrowed` explicitly. This loses the "opt-in
   one-liner" ergonomics — exactly the cost the pattern is designed to
   eliminate. The Viewable protocol's pre-restructure shape is a real-
   world instance.

2. **Widen Value's constraints** to match Self's: the default works
   again. This is the resolution the Borrow DECISION prescribes
   (widening `Ownership.Borrow<Value: ~Copyable>` to
   `Value: ~Copyable & ~Escapable`).

**Rationale for REFUTED**: the constraint-compatibility precondition is
not optional. Violating it produces a deterministic compile error at a
predictable location. The error's textual form is stable and identifies
both the offending Self and the conformance it cannot satisfy.

**Implication**: when adopting the self-projection default pattern in a
new namespace, the FIRST audit step is to verify that the generic
struct's Value parameter accepts every suppression the protocol's Self
admits. If not, choose between (a) widening the generic, (b) narrowing
the protocol, or (c) abandoning the default and accepting the per-
conformer authorship cost.

#### V4 — Hash-shape degenerate (DEGENERATE, partial fit)

`swift-hash-primitives/Hash` is an empty namespace enum;
`Hash.\`Protocol\`` is the capability protocol; `Hash.Value` is a
*concrete typealias* (`Tagged<Hash, Int>`) — there is no sibling
`Hash<Value>` generic struct. The experiment models this with
`V4_Hash` (empty enum), `V4_Hash.Value` (concrete struct),
`__V4_Hash_Protocol` (with `associatedtype HashResult = V4_Hash.Value`),
and a typealias `Protocol = __V4_Hash_Protocol`.

The shape compiles. A conformer (`V4_Token`) that accepts the default
gets `HashResult = V4_Hash.Value` for free. The compile-time probe
resolves correctly.

**Rationale for DEGENERATE**: the shape exists, but the default is NOT
a self-projection — it is a *capability-default* (the protocol declares
a default associated type that is a fixed concrete type in the
namespace, independent of Self). The structural match to the meta-
pattern is partial:

| Precondition | Borrow (FITS) | Hash (DEGENERATE) |
|--------------|:-------------:|:-----------------:|
| Namespace N | ✓ | ✓ |
| Capability protocol N.`Protocol` | ✓ | ✓ |
| Associatedtype default | ✓ | ✓ |
| Sibling generic struct N<Value> | ✓ | ✗ |
| Default form `= N<Self>` | ✓ | ✗ (default is fixed type) |

**Implication**: the pattern's letter (Self-parameterization) requires
the sibling generic struct. Without it, the spirit (reduce conformer
authorship cost via a default associatedtype) can still be honored, but
calling the result a "self-projection default" conflates two distinct
patterns. Future skill codification should name the patterns
distinctly:

- **Self-projection default** = sibling generic struct + protocol
  default `= N<Self>`
- **Capability default** = no sibling generic struct + protocol
  default `= ConcreteTypeInN`

The Borrow DECISION instantiates the former; Hash instantiates the
latter.

#### V5 — Memory.Contiguous structural lookalike (DOES NOT FIT)

`swift-memory-primitives/Memory.Contiguous<Element>` has all three
structural elements: namespace `Memory`, generic struct
`Memory.Contiguous<Element: BitwiseCopyable>`, capability protocol
`Memory.ContiguousProtocol` (exposed via
`typealias \`Protocol\` = Memory.ContiguousProtocol`). The experiment
mirrors this with `V5_Memory.Contiguous<Element: ~Copyable>` and
`__V5_ContiguousProtocol` carrying `associatedtype Element: ~Copyable`.

The protocol's associatedtype is `Element` — *what the conformer
contains*. A conformer says "I store these Elements contiguously."
Element is a property of the conformer, not a projection of the
conformer.

A "self-projection" default would have to read Element as "what Self
contains when projected through Memory.Contiguous." But Self IS the
container; Element is what it contains. There is no natural
resolution; "Self contains Self" makes sense only for self-referential
types like trees, not for general containers. The experiment's
conformer (`V5_Buffer`) MUST supply Element explicitly — no default
applies.

**Rationale for DOES NOT FIT**: the namespace shape `{N, N<T>, N.\`Protocol\`}`
is a STRUCTURAL lookalike but not a SEMANTIC fit when the protocol's
associatedtype is an *attribute of the conformer* (element-containment)
rather than a *projection of Self*. The meta-pattern is defined by the
*role* of the associatedtype, not by the *structural layout* of the
namespace.

**Implication**: the most common ecosystem shape — a generic struct
that parameterizes over what it CONTAINS, with a protocol parameterizing
over the same thing — is NOT a candidate for self-projection. Audits
of "where else can we apply Borrow's pattern?" should reject
Element-axis protocols on inspection, regardless of how similar the
namespace structure looks.

### Cross-cutting observations

**The pattern has both structural and semantic preconditions.** V5
shows the structural preconditions are not sufficient: a namespace can
have all three pieces (enum, generic struct, protocol) and still fail
the pattern when the protocol's role differs.

**The constraint-compatibility rule (V3) is the only mechanical
precondition.** All other preconditions are about *intent* — the role
the associatedtype plays in the protocol — and require human
judgment. Mechanical detection of candidate namespaces will produce
many false positives (e.g., V5 candidates from a "structural shape"
grep) that human inspection must filter.

**Storage choice (V1) constrains the protocol's admissible Self
suppressions.** This is a propagation, not a separate rule:
constraint-compatibility says Self ⊆ Value, so any narrowness in Value
(driven by storage primitives like UnsafeMutablePointer) propagates
upward. Future applications must check this propagation before
selecting Self's admissible suppressions.

**The pattern reduces conformer authorship cost — but only for the
"projection role."** Across V0/V1, conformers without interior storage
get conformance for free. This is the pattern's primary value
proposition. V4 (capability default) and V5 (element-containment) do
not deliver this benefit because they do not address the projection
role.

## Outcome

**Status**: RECOMMENDATION — characterizes the pattern's applicability;
does NOT prescribe ecosystem-wide adoption. Adoption decisions remain
with the principal, informed by this characterization.

### Summary classification table

| Candidate | Variant | Verdict | Reason |
|-----------|---------|---------|--------|
| Ownership.Borrow | V0 | **FITS** | Canonical instance; baseline |
| Ownership.Mutate / Ownership.Inout | V1 | **FITS** (narrower constraints) | One-to-one mirror; storage forces narrower Self admissions |
| Property<Tag, Base> | V2 | **DOES NOT FIT** | Two-param generic has no canonical Self-axis |
| Mismatched suppressions | V3 | **REFUTED** | Constraint-compatibility precondition violated; diagnostic captured |
| Hash (no sibling generic) | V4 | **DEGENERATE** | Capability-default pattern, not self-projection default |
| Memory.Contiguous (element-axis) | V5 | **DOES NOT FIT** | Element-containment role, not Self-projection role |

### Adoption checklist for future applications

When considering whether to apply the self-projection default pattern
to a new namespace, verify each of:

| # | Precondition | Verification |
|---|--------------|--------------|
| 1 | Namespace N exists (enum or extension-form) | Trivial; structural |
| 2 | A single-parameter generic struct `N<Value: Cs_V>` exists in N | Trivial; structural |
| 3 | A capability protocol N.`Protocol` exists OR is being introduced | Structural |
| 4 | The protocol's role is "conformers project themselves through N" — NOT "conformers contain Element X" | **Semantic — requires judgment.** V5 shows this is the precondition most easily violated |
| 5 | The protocol's Self suppressions ⊆ the generic struct's Value suppressions | **Mechanical — V3 confirms this is checkable at compile time.** If violated, widen Value or narrow Self |
| 6 | The pointer storage in N<Value> admits Value's suppressions (e.g., `UnsafeMutablePointer<Value>` requires Escapable) | **Mechanical, but easy to miss.** V1 illustrates the surprise |

If criteria 1–6 hold, the pattern can be applied with predictable
results matching the Borrow DECISION's outcome (Case A free conformance,
Case B specialization, Case C parametric forwarding via Tagged).

### What the document does NOT do

This document does NOT:

- Propose adopting the pattern in any specific production namespace.
- Replace, supersede, or modify the Ownership.Borrow DECISION.
- Establish a normative requirement for future protocols to use this
  shape — the pattern is one option, not a default.
- Survey adoption candidates beyond the five tested in the experiment.
  The grep targets in the originating handoff surfaced 11 hoisted-
  protocol typealias sites; only the candidates structurally relevant
  to the self-projection question were probed.

### Queued escalations

None at this time. The investigation surfaced no shape that violates
the pattern's preconditions while resembling self-projection closely
enough to warrant principal escalation per the originating handoff's
ground-rule #6.

## References

### Primary sources

- **Borrow DECISION (origin)**: `swift-primitives/Research/ownership-borrow-protocol-unification.md` (v1.0.0, 2026-04-22, tier 2, cross-package, DECISION).
- **Borrow execution plan**: `swift-primitives/Research/ownership-borrow-protocol-unification-implementation-plan.md` (v1.0.0, 2026-04-22, tier 2, cross-package, RECOMMENDATION).
- **Borrow experiment (CONFIRMED)**: `swift-primitives/Experiments/ownership-borrow-protocol-unification/Sources/main.swift` (Apple Swift 6.3.1, 2026-04-22) — the experiment from which this meta-pattern was extracted.
- **This investigation's experiment (CONFIRMED)**: `swift-primitives/Experiments/self-projection-default-pattern/Sources/main.swift` (Apple Swift 6.3.1, 2026-04-22) — six variants probing the meta-pattern's applicability.
- **Originating handoff**: `/Users/coen/Developer/HANDOFF-self-projection-default-pattern.md` — the investigation brief that scoped this work.

### Ecosystem candidates examined

- **Ownership.Borrow<Value>**: `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift:35` — the V0 baseline.
- **Ownership.Inout<Value>**: `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Inout.swift:36` — the V1 mirror's real-world counterpart (named Inout in the ecosystem; Mutate in SE-0519).
- **Property<Tag, Base>**: `swift-property-primitives/Sources/Property Primitives Core/Property.swift:41` — V2 source.
- **Hash + Hash.Value + Hash.`Protocol`**: `swift-hash-primitives/Sources/Hash Primitives Core/{Hash.swift, Hash.Value.swift, Hash.Protocol.swift}` — V4 source.
- **Memory.Contiguous<Element> + Memory.Contiguous.`Protocol`**: `swift-memory-primitives/Sources/Memory Primitives Core/{Memory.Contiguous.swift, Memory.ContiguousProtocol.swift}` — V5 source.

### Ecosystem precedent (other hoisted-protocol sites surveyed)

The grep `public typealias \`Protocol\` =` against `swift-primitives/`
returned 11 sites across 9 files (excluding Experiments/). The
investigation focused on the candidates whose structural shape made
self-projection plausible; the remaining sites (Array.`Protocol`,
Set.`Protocol`, Effect.`Protocol`, Effect.Continuation.`Protocol`,
Effect.Handler.`Protocol`, Numeric.`Protocol`,
Parser.Error.Located.`Protocol`, Parser.Input.`Protocol`) are
container/effect/iterator capability protocols — element-containment
and effect-decomposition roles, structurally similar to V5.

### Convention sources

- **[PKG-NAME-001]**: package name = noun form of canonical type
- **[PKG-NAME-002]**: canonical capability protocol = `Namespace.\`Protocol\``; gerund typealias rules
- **[MEM-COPY-004]**: extension constraints on ~Copyable/~Escapable generic types MUST repeat suppressions
- **[API-IMPL-009]**: hoisted protocol with nested typealias pattern (declaring-module conformance uses hoisted name; consumers use typealias path)
- **[RES-020]**: research tier rules
- **[EXP-006b]**: confirmation evidence requirements

### Language references

- **SE-0404 (Allow Protocols to be Nested in Non-Generic Contexts)** — explains why direct nesting in generic contexts (V6 in the Borrow experiment, REFUTED) remains prohibited.
- **SE-0446 (Nonescapable Types)** — `~Escapable` introduction; relevant to V3's constraint-compatibility analysis.
- **SE-0519 (Borrow<T> / Mutate<T>)** — stdlib borrow types; `Ownership.Borrow<Value>` and `Ownership.Inout<Value>` mirror.
- **Swift 6.3.1 experimental features required**: `Lifetimes`, `SuppressedAssociatedTypes`.
