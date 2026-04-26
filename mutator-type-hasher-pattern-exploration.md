# What is a Mutator type? — Hasher-pattern design-space exploration

<!--
---
version: 1.1.0
last_updated: 2026-04-25
status: DEFERRED
tier: 2
scope: ecosystem-wide
relocated_from: swift-mutator-primitives/Research/mutator-type-hasher-pattern-exploration.md
relocation_date: 2026-04-25
---
-->

> **STATUS: DEFERRED 2026-04-25.** Investigation completed; no package
> shipped. The compositional machinery is already in `swift-optic-primitives`
> + `swift-algebra-*`; the genuine academic gap lacks a credible second
> consumer per [RES-018]. Two well-shaped follow-ups (`Optic.Setter`,
> `Algebra.Semilattice`) are extensions to existing primitives, not a
> separate package. Source package `swift-mutator-primitives/` retired;
> artifacts relocated here for cross-package reference. See
> `swift-carrier-primitives/Research/mutability-design-space.md` v1.1.0
> §Investigation outcome (2026-04-25).

## Context

`swift-mutator-primitives` originally landed as a parallel-to-Carrier
capability protocol (`Mutator.\`Protocol\`<Value>` with `var value:
Value { borrowing get; set }`). Two iterations of design feedback have
narrowed and reframed the question:

1. **First iteration** (parallel capability protocol). Tightly coupled
   to Carrier's shape. Empirically validated across four quadrants but
   structurally redundant with Carrier on the read side.

2. **Second iteration** (empty marker protocol). Decoupled from
   Carrier; downstream packages compose via `extension Carrier where
   Self: Mutable {}`. Simpler but vacuous — `Mutable` as a marker has
   no inherent capability beyond serving as an opt-in flag.

3. **This iteration** (Hasher-pattern witness type). Inspired by the
   `Hashable` / `Hasher` separation: the trait-protocol exposes a
   *witness type* (`Hasher`) that does the actual work; the conformer
   feeds salient bits to the witness via `func hash(into: inout
   Hasher)`. The question this investigation explores: **what would a
   `Mutator` witness type DO?** What capabilities — if any — would
   the abstraction unlock that justify its existence as a primitive?

The investigation is intentionally exploratory. The outcome may be a
concrete protocol+type pair worth shipping, or a DEFERRED with the
finding *"no compelling unlock; the abstraction does not pay rent."*

## Question

Five sub-questions:

1. **What's the Hasher pattern, precisely?** State the structural
   invariants of `Hashable` / `Hasher` so a parallel pattern can be
   constructed for mutation rather than retrieved-from-vibes.

2. **What jobs could a `Mutator` witness type do?** Enumerate the
   meaningful candidate roles (transactional, journaling, observation,
   validation, functional-update, structural-edit, etc.) and the
   semantic invariants each would impose on the conformer surface.

3. **What does each candidate role unlock?** For each role, what
   downstream APIs become writable / improvable that aren't writable
   now without per-type plumbing?

4. **Which role(s), if any, are worth shipping as primitives?** A role
   that produces compelling unlocks AND has at least one credible
   second consumer per [RES-018] passes the bar; a role that only
   improves the originating thought-experiment fails.

5. **What's the relationship to existing ecosystem primitives?** Does
   the Mutator witness compose with `Ownership.Inout`, `Carrier`, the
   Property protocols? Where does it duplicate? Where does it
   genuinely add?

## Methodology

**Tier**: 2 (Standard) — cross-package, characterizes a meta-pattern
that may inform multiple ecosystem primitives. Not Tier 3 because the
document does not establish a normative semantic contract; it
characterizes options and their unlocks.

**Trigger**: [RES-001] Investigation — design question raised by user
during the package's iterative scope refinement. The earlier shapes
(full capability protocol, empty marker) failed to land; the user
explicitly redirected to a Hasher-pattern exploration *"in isolation,
to see what it would unlock."*

**Apply [RES-018]**: any candidate Mutator type proposed as an
ecosystem primitive MUST clear (a) a *"why not compose existing
primitives?"* check and (b) a *"is there a second consumer?"* check.
Symmetric-completeness reasoning is disqualified.

**Apply [RES-021]**: prior-art survey for parallel ecosystems —
specifically Rust's mutation/observation patterns, Haskell's Lens /
Optic libraries, Go's struct-tag-based mutation, and any Swift
proposals for typed mutation interfaces (Observation framework,
property-wrapper-based mutation control).

## Analysis

### The Hasher pattern, precisely

Stdlib's `Hashable` ↔ `Hasher` separation:

```swift
// Trait protocol — names the capability and exposes the witness.
public protocol Hashable: Equatable {
    func hash(into hasher: inout Hasher)
    var hashValue: Int { get }   // legacy; derivable from hash(into:)
}

// Witness type — opaque; carries algorithm + state.
@frozen
public struct Hasher {
    public init()                                                       // start
    public mutating func combine<H: Hashable>(_ value: H)              // feed
    public mutating func combine<S: Sequence>(_ sequence: S)
        where S.Element: Hashable                                       // (overloads)
    public __consuming func finalize() -> Int                          // commit
}
```

**Three load-bearing properties**:

1. **Asymmetry of authorship.** The conformer authors `hash(into:)`
   and is responsible for *what salient bits* identify the value. The
   `Hasher` authors *how to combine bits into a hash*. This separates
   identity-data from hashing-algorithm concerns.

2. **Universal witness reuse.** A single `Hasher` instance is reused
   by `Set`, `Dictionary`, custom collections, and consumer code.
   Hashable conformers don't pick a hash algorithm; the framework
   does.

3. **Linear write-only surface.** The conformer feeds bits *into*
   `Hasher`; it cannot extract or inspect the Hasher's intermediate
   state. The Hasher is a one-way pipe: `init() → combine* →
   finalize()`. The conformer is structurally prevented from depending
   on any specific algorithm or state machine.

**What the pattern is NOT**:

- **Not a getter/setter pair** — the conformer doesn't expose data
  via accessors; it feeds it via a method call.
- **Not a key-path projection** — the bits the conformer feeds in are
  arbitrary, computed, possibly multi-source.
- **Not a refinement protocol** — Hashable doesn't refine a "data
  exposure" supertype. It's a single-method protocol with a witness
  type as the parameter.

### Projecting the pattern onto mutation

A faithful translation:

```swift
// Trait protocol — names the capability and exposes the Mutator witness.
public protocol Mutable: ~Copyable {
    mutating func mutate(via mutator: inout Mutator<Self>)
}

// Witness type — opaque; carries algorithm + state.
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    // What goes here? This IS the research question.
}
```

The asymmetry would be:
- The conformer authors `mutate(via:)` and is responsible for *what
  state can change* and *what invariants must hold*.
- The Mutator authors *how mutation is processed* — recorded,
  validated, replayed, observed, transactionally bound, etc.

The remaining question is what the Mutator's "processing" is. That's
the design space.

### Candidate roles for the Mutator witness type

Six candidate roles, enumerated for analysis. Each could be the basis
of a single Mutator type, or the family could split into siblings.

#### Role A: Transactional Mutator

The Mutator wraps a mutation in a commit/abort lifecycle. The
conformer authors mutations through the Mutator; the Mutator decides
whether the changes flush.

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public mutating func update(_ apply: (inout Subject) -> Void)
    public consuming func commit() -> Subject
    public consuming func abort() -> Subject  // returns original unchanged
}

extension Counter: Mutable {
    mutating func mutate(via mutator: inout Mutator<Self>) {
        mutator.update { $0.raw += 1 }
        if invariantsHold {
            // (committed by caller via mutator.commit())
        } else {
            // (aborted by caller via mutator.abort())
        }
    }
}
```

**Unlocks**: Generic transactional mutation. Any caller can wrap a
mutation in `commit/abort` semantics without per-type save/restore
plumbing.

**Tension**: For value types, transactional semantics are already
free (just don't write back the variable). The unlock is meaningful
only for reference types or cases where the mutation has side-effects
beyond the value itself.

#### Role B: Journaling Mutator

The Mutator records every mutation as a typed event for later replay,
audit, or undo.

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public mutating func record<Change>(
        _ kind: Mutator.ChangeKind<Change>,
        applying transform: (inout Subject) -> Change
    )
    public consuming func journal() -> [Mutator.Entry<Subject>]
}
```

**Unlocks**: Generic undo/redo, generic audit logs, generic event
sourcing. Ad-hoc per-type undo systems collapse to one generic
implementation parameterized on Mutable.

**Tension**: The journal-entry encoding is non-trivial — what's the
type of a "change" to an arbitrary `Subject: ~Copyable`? Probably
requires the conformer to author entry-type witnesses for each
mutation it admits, which moves the burden BACK to the conformer.

#### Role C: Observation Mutator

The Mutator broadcasts mutation events to observers, separating "what
changed" from "who cares."

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public mutating func willChange()
    public mutating func didChange()
    public mutating func update(_ apply: (inout Subject) -> Void)
    // Observers wire up at instantiation time.
}
```

**Unlocks**: Generic observation. Currently Swift's Observation
framework handles this at the macro level (KVO-style); a Mutator
witness would do it at the protocol level, enabling generic
observation of any `Mutable` type.

**Tension**: Observation already exists in Swift via `@Observable`;
a Mutator-based competitor would need to demonstrate strictly better
ergonomics or capabilities (e.g., on `~Copyable` types where
`@Observable` cannot apply).

#### Role D: Validation Mutator

The Mutator interposes invariant checks on every mutation; the
conformer doesn't author the checks, the Mutator does.

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public mutating func update(
        _ apply: (inout Subject) -> Void
    ) throws(Mutator.InvariantViolation)
}
```

**Unlocks**: Generic invariant enforcement — types declare invariants
once, every mutation through the Mutator is automatically checked.

**Tension**: Property wrappers and `didSet` already do this at the
type level. The Mutator-based unlock would be generic-dispatch
invariant checking — useful only if there are generic algorithms that
mutate Mutable types and want invariants enforced uniformly.

#### Role E: Functional-Update Mutator

The Mutator builds new values by transformation rather than mutating
in place. The "mutate" is a functional update with referential
transparency at the API level.

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public consuming func map(_ transform: (Subject) -> Subject) -> Subject
    public consuming func flatMap(_ transform: (Subject) -> Subject) -> Subject
}
```

**Unlocks**: Generic functional-update API. `T.with(\.field, value)`
becomes universal across any Mutable type.

**Tension**: This is essentially what `inout` already does at the
language level, plus optional KeyPath dynamic-member-set affordance
that ecosystems already provide. The unlock is marginal unless the
Mutator carries significant additional capability (composition,
partial application, etc.).

#### Role F: Structural-Edit Mutator

The Mutator carries structural knowledge of the type's mutable
fields and exposes typed-key access paths. Like Codable for mutation:
the conformer declares its mutable structure once; consumers
generically navigate and mutate.

```swift
public struct Mutator<Subject: ~Copyable>: ~Copyable {
    public mutating func field<T>(
        named name: String,
        as type: T.Type,
        update: (inout T) -> Void
    )
    public mutating func subscript<T>(
        path: WritableKeyPath<Subject, T>,
        update: (inout T) -> Void
    )
}

extension Counter: Mutable {
    mutating func mutate(via mutator: inout Mutator<Self>) {
        mutator.field(named: "raw", as: Int.self) { $0 += 1 }
    }
}
```

**Unlocks**: Generic structural editing. Any Mutable type exposes a
uniform "edit field N" interface; tooling (debuggers, inspectors,
scripting bridges, JSON-Patch-style edit pipelines) work generically.

**Tension**: Heavy compared to direct field access; `~Copyable` field
types add typed-key constraints; KeyPath has the documented Q1-only
constraint per `mutator-writable-keypath-interaction.md`. This role probably
needs reflection-level capabilities Swift doesn't have at the
primitives layer.

### Comparison table

| Role | Unlocks | Tension | Second-consumer evidence |
|------|---------|---------|-------------------------|
| A. Transactional | Generic commit/abort | Already free for value types | Concurrency primitives? Actor state machines? |
| B. Journaling | Generic undo/redo, event sourcing | Entry-type encoding heavy | UI state libraries, persistence layers |
| C. Observation | Generic observation on ~Copyable | Macro-based @Observable competes | Reactive frameworks beyond @Observable scope |
| D. Validation | Generic invariant enforcement | Property wrappers already do this | Generic constraint-checked containers |
| E. Functional-update | Universal `.with(\.field,)` | Marginal vs `inout` | (no clear second consumer) |
| F. Structural-edit | Generic field navigation | Reflection-level, KeyPath limits | Debuggers, scripting bridges, JSON-Patch |

### Prior art survey

A comprehensive academic prior-art survey has been authored as a
companion document at `mutator-academic-prior-art-survey.md`
(Tier 2, REFERENCE, 31 verified citations). The survey covers six
threads — lens/optics, algebraic effects + handlers, linear/affine
+ capabilities, CRDTs, FRP, type-class dictionary witnesses — and
explicitly grounds each thread against the existing ecosystem
primitives (`swift-optic-primitives`, `swift-algebra-*`, language-
level `~Copyable`/`~Escapable`).

The most load-bearing findings from that survey, summarized here:

1. **The lens/optics academic family is already shipped at the
   ecosystem layer.** `swift-optic-primitives` ships
   `Optic.Lens<Whole, Part>` (with GetSet/SetGet/SetSet laws),
   `Optic.Prism`, `Optic.Iso`, `Optic.Affine`, `Optic.Traversal`.
   The Mutator investigation MUST compose with these rather than
   duplicate them. The one optic kind missing from the ecosystem
   is **Setter** (write-only, the `Mapping`-profunctor optic per
   Pickering–Gibbons–Wu 2017). A `Mutator<Subject>` that exposes
   only mutation IS a Setter; the cleanest landing for that role
   may be to extend `swift-optic-primitives` with `Optic.Setter`
   rather than ship a separate package.

2. **The algebraic-effects + handlers literature gives the cleanest
   formal anchor.** Plotkin & Power 2002 frames Mutator's API as
   the signature of an algebraic theory; Plotkin & Pretnar 2009/2013
   makes Mutator literally a *handler* (a model of the theory) —
   restricted to single-shot in-place execution. The witness-struct
   shape Mutator needs is exactly the shape `Algebra.*` already
   ships; a Mutator's accumulator should be expressed in
   `Algebra.Monoid<Operation>` or similar terms, composing with
   the existing primitive.

3. **The substructural / lifetime story is language-level.** Wadler
   1990 / Walker 2005 / Linear Haskell 2018 / Mezzo 2016 / Cyclone
   2002 / Tofte–Talpin 1997 collectively formalize linear/affine +
   borrowing + lexical lifetimes, but Swift delivers all of this
   AT THE LANGUAGE LEVEL via `~Copyable`, `~Escapable`,
   `@_lifetime`. No package owns substructural typing in this
   sense. **`Algebra.Linear` (the existing package) is *linear
   algebra* — vectors and matrices — and is unrelated to Wadler-
   1990 substructural linear types; the naming overlap is a
   hazard.**

4. **The genuine academic gap exactly maps the package's design
   space.** No published paper directly studies "handlers for
   linear/borrowed state where the witness itself is lifetime-
   bounded." This sits between Tang–Hillerström–Lindley–Morris
   2024 ("Soundly Handling Linearity" — handlers + linear-typed
   resources for session channels) and Wagner et al. 2025 ("From
   Linearity to Borrowing" — BoCa: linear λ-calculus with
   immutable+mutable borrows + lexical lifetimes). The Mutator
   pattern is a publishable real-world API embodiment of an
   open theoretical problem.

5. **Categorically, Hasher itself is a Fold-shaped visitor, not
   a Lens.** The Mutator analogy to Hasher inherits Hasher's
   *engineering ergonomics* (algorithm controlled by witness;
   resilient ABI per SE-0206; stateful sink with finalization)
   without inheriting any specific categorical role from the
   optic family. The patterns are siblings, not specializations.

6. **The strongest second-consumer cases per [RES-018]** are
   Role C Observation on `~Copyable` (real gap in Apple's
   `@Observable`; academic frontier in linear-temporal-logic FRP,
   adjoint reactive GUI) and Role A Transactional (Wadler 1990's
   argument plus Linear Haskell's `freeze :: MArray a %1 ->
   Array a` precedent). Roles B/D/E/F have weaker second-consumer
   support per the academic literature.

See `mutator-academic-prior-art-survey.md` for full citations,
verification status per claim, and detailed analysis.

### Composition with existing primitives

| Primitive | Composes with Mutator? | Note |
|-----------|------------------------|------|
| `Carrier` | Yes — orthogonal | A Carrier conformer that's also Mutable would have a `mutate(via:)` that works on its `underlying` field. The two protocols are independent. |
| `Ownership.Inout` | Possibly redundant | `Inout<T>` IS already a typed mutable-reference witness with `value { _read; _modify }`. Role-A or Role-E Mutator would reinvent this. The unlock for a separate Mutator is unclear unless it adds something Inout doesn't (transaction lifecycle, journaling, etc.). |
| `Property.\`Protocol\`` | Yes if domain-aligned | Property's verb-namespaced protocols already encode declarative type roles; a Mutator witness on a Property conformer would expose mutation through that domain's vocabulary. |
| `Witnesses.Sendable` and similar | Orthogonal | Sendable-style witnesses describe trait-flags; Mutator describes operational machinery. No conflict. |

### What would actually be NEW?

The honest reading of the comparison table: most candidate roles
already have non-Mutator solutions in Swift or its ecosystem. The
genuine gaps are:

1. **Observation on `~Copyable` types** (Role C) — `@Observable` is
   Copyable-only; a Mutator witness extending observation to
   `~Copyable` Self would be a real unlock.

2. **Generic journaling for ~Copyable** (Role B) — CRDT-style
   replicated mutation for `~Copyable` types is an open ecosystem
   problem; a Mutator-based primitive could be foundational.

3. **Cross-protocol generic algorithms over "anything mutable"**
   (Role A or composition of Roles) — once the witness exists,
   ecosystem code can be written against `Mutable & ~Copyable`
   without committing to a specific access pattern. This is the
   Hashable-ecosystem-effect: every collection that wants to be
   hash-keyed conforms; every algorithm that needs hashing dispatches
   on `Hashable`. The mutation-side equivalent doesn't exist today.

The three-pronged gap is the strongest case for the abstraction.
Whether it's worth shipping as a primitive depends on whether (a) at
least one credible second-consumer materializes for any of the three,
and (b) the protocol+type design cleanly resolves the open issues
(entry-type encoding for B, framework integration for C, generic
algorithm targets for cross-protocol).

## Outcome

**Status**: IN_PROGRESS — investigation establishes the design space
and candidate roles; no DECISION yet. Next steps below.

### Tentative findings

1. **The Hasher pattern is meaningful for mutation**, but the
   conformer-witness asymmetry only earns its keep if the witness
   does WORK the conformer can't reasonably do alone. For Hasher,
   that work is the hash algorithm. For Mutator, the analogous "real
   work" candidates are observation broadcast, journal recording, or
   transactional lifecycle — each non-trivial, each with second-
   consumer questions.

2. **The strongest unlock cases are extensions of existing patterns
   into the `~Copyable` / `~Escapable` quadrants** (e.g., Observation
   on `~Copyable`). Where the existing pattern handles Copyable
   already, the marginal value of a Mutator primitive is small.

3. **The empty-marker design (the prior iteration) is INSUFFICIENT
   for the Hasher pattern.** A marker has no method requirement for
   the conformer to feed bits into anything; the entire pattern
   assumes a `mutate(into:)` call surface. Reverting the marker
   pivot in favor of a Hasher-shaped protocol is the prerequisite
   for any of these roles.

4. **The full-capability protocol design (the original iteration)
   is ALSO INSUFFICIENT** — exposing `var value: Value` directly
   defeats the witness-type indirection. The conformer should NOT
   project its mutable state as a property; it should feed it
   through the witness.

5. **The right starting point is probably Role A (Transactional)
   OR Role C (Observation, ~Copyable extended)**, because they have
   both (a) a credible first consumer (Swift's actor / concurrency
   primitives for A; the gap in @Observable for C) and (b) a clear
   structural shape. Roles B/D/E/F are interesting but secondary.

### Next steps

1. **Run an isolation experiment** — author a minimal Mutator type
   in Role A (Transactional) and Role C (Observation) shapes; verify
   the conformer-witness asymmetry compiles for `~Copyable` Self;
   probe what generic algorithms become writable.

2. **Survey concrete ecosystem second-consumer candidates**. Is
   there a real package today that would adopt a Mutator-based
   transactional primitive? An observation primitive for `~Copyable`?
   If two credible second consumers can be named, the case for
   shipping at least one role passes [RES-018].

3. **Refine the protocol shape**. Specifically:
   - `Mutable: ~Copyable, ~Escapable` — quadrant coverage from day one.
   - `Mutator<Subject: ~Copyable>` — `~Copyable` itself, since the
     witness holds a transient mutable reference to Subject.
   - `mutating func mutate(via mutator: inout Mutator<Self>)` — the
     single requirement.
   - The Mutator's API surface — to be determined per role.

4. **DECISION** — based on (1)–(3), produce a DECISION on whether
   to ship: (a) Role-A only, (b) Role-C only, (c) a composed
   multi-role Mutator, (d) DEFERRED until concrete consumer demand
   materializes.

### Queued escalations

None at this stage. Investigation continues; principal review
welcomed on the candidate-role enumeration before isolation
experiments are authored.

## References

### Primary sources

- `Sources/Mutator Primitives/Mutator.swift` — research-phase
  placeholder enum; final shape to be informed by this investigation.

### Stdlib references

- Swift stdlib `Hashable` protocol declaration —
  https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Hashable.swift
- Swift stdlib `Hasher` struct declaration —
  https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Hasher.swift
- Apple's Observation framework (`@Observable`) — the closest
  existing Swift-language analog to Role C.

### Ecosystem alternative-shape research

- `mutator-orthogonal-vs-refinement-stance.md` (alternative-shape
  evidence: full-capability protocol, sibling-of-Carrier framing).
- `mutator-modify-across-quadrants.md` (alternative-shape evidence:
  empirical findings on `_modify`-as-protocol-requirement and
  `@_lifetime` annotations for the full-capability shape).
- `mutator-writable-keypath-interaction.md` (alternative-shape evidence:
  WritableKeyPath dynamic-member subscript REFUTED for ~Copyable —
  applies regardless of which Mutator role is chosen, since
  Role F (Structural-edit) would face the same constraint).
- `mutator-naming-protocol-and-typealias.md`
  (still applies: `Mutator` namespace + `Mutable` typealias is the
  package's naming spine; the namespace will host both the trait
  protocol AND the witness type per the Hasher pattern).

### Convention sources

- **[RES-018]** — premature primitive anti-pattern; second-consumer
  hurdle.
- **[RES-021]** — prior-art survey requirements for Tier 2+.
- **[PKG-NAME-002]** — `Namespace.\`Protocol\`` canonical capability
  protocol pattern; the package retains this naming spine.
- **[ARCH-LAYER-001]** — Tier 0 placement (no primitive deps).

### Related ecosystem patterns

- `swift-carrier-primitives/Research/capability-lift-pattern.md`
  (RECOMMENDATION) — the Tagged-forwarding-via-Carrier pattern;
  orthogonal to Mutator, but the "abstract interface, canonical
  generic implementation" framing is informative.
- `swift-ownership-primitives/Research/self-projection-default-pattern.md`
  (RECOMMENDATION) — the `associatedtype = N<Self>` default pattern;
  Mutator's `Mutator<Self>` shape is structurally similar but the
  witness's role differs.
