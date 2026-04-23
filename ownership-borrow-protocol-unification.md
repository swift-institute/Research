# Ownership.Borrow Protocol Unification

<!--
---
version: 1.0.0
last_updated: 2026-04-22
status: DECISION
tier: 2
scope: cross-package
---
-->

## Context

Three facts grounded this research:

1. **`swift-identity-primitives` violates [PKG-NAME-001]**: the package is named
   after the semantic concept "identity" but contains no `Identity` namespace.
   It houses `Tagged<Tag, RawValue>` (the canonical type) plus `Viewable`
   (an unrelated capability protocol). Every comparable primitives package
   names itself after its canonical type or namespace. The rename
   `swift-identity-primitives` → `swift-tagged-primitives` is scheduled
   (separate work).

2. **`Viewable` is an underpowered protocol in the wrong place.** Grep
   confirms exactly **three conformers** across the ecosystem (Tagged
   conditional forwarding, Path, String) and **zero generic-dispatch uses** —
   no `where T: Viewable`, no `some Viewable` function parameter, no
   protocol extensions, no downstream usage in swift-standards or
   swift-foundations. Its one load-bearing job is the parametric
   conditional conformance in `Tagged+Viewable.swift:14`.

3. **`Ownership.Borrow<Value>` is the generic counterparty.**
   `Ownership.Borrow<Value>` at `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift:35`
   is a generic pointer-based borrow (SE-0519-aligned). Viewable is the
   capability protocol for types that expose a **specialized** borrowed
   form richer than the generic. They sit in a specialization lattice:
   `Ownership.Borrow<T>` is the fallback; type-specific `.Borrowed` types
   are opt-in refinements.

This research formalizes the unified shape.

**Trigger**: [RES-012] Discovery — proactive consolidation driven by
[PKG-NAME-001] audit and the generic-counterparty observation.

**Scope**: Cross-package (swift-identity-primitives, swift-ownership-primitives,
swift-path-primitives, swift-string-primitives; ecosystem-wide adoption
path for future conformers).

**Tier**: 2 (Standard) — cross-package, establishes long-lived semantic
contract, influences future Borrow-capability design. [RES-020]

## Question

Can `Viewable` be unified with `Ownership.Borrow<Value>` under a shape
that:

1. Preserves `Ownership.Borrow<Value>` as the generic struct (no rename,
   keeps SE-0519 vocabulary alignment, honors the user's explicit
   `.Generic` prohibition),
2. Exposes the capability protocol via the spelling
   `Ownership.Borrow.\`Protocol\`` at conformance sites,
3. Admits a default associatedtype `Borrowed = Ownership.Borrow<Self>`
   so types without interior storage get conformance for free,
4. Preserves the existing parametric Tagged conditional conformance?

## Analysis

### Design constraints (collected from prior conversation)

| Constraint | Source |
|-----------|--------|
| No new `swift-borrow-primitives` standalone package | User directive |
| No `*.Generic` suffix for generic struct rename | User directive |
| `Ownership.Borrow<Value>` should not be renamed | User directive; preserves SE-0519 vocabulary |
| Language semantics (`borrowing T`) preferred over types where possible | User design principle |
| Types only when language can't reach (Optional, stored, collection element) | User design principle |
| [PKG-NAME-002] canonical capability protocol = `Namespace.\`Protocol\`` | Swift Institute skill |
| Gerund typealias for natural-English conformance sites | Swift Institute skill |
| -able typealiases forbidden (gerund-only) | [PKG-NAME-002] |
| Protocols cannot be nested in generic contexts | SE-0404 Swift language limitation |
| Ignore churn / downstream costs (theoretical perfectness) | User directive |

### Empirical findings

The experiment `swift-primitives/Experiments/ownership-borrow-protocol-unification`
(CONFIRMED, 2026-04-22, Apple Swift 6.3.1) verified the structural
feasibility across 10 variants. The decisive findings:

**V6 REFUTED — direct protocol nesting in a generic struct**:

```
error: protocol 'Protocol' cannot be nested in a generic context
```

SE-0404 opened non-generic nesting only. Neither `struct Borrow<V> { protocol Protocol { ... } }` nor
`extension Borrow { protocol Protocol { ... } }` compiles on Swift 6.3.1.

**V8 CONFIRMED — hoisting with a module-scope protocol + nested typealias in the struct body**:

```swift
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = Ownership.Borrow<Self>
}

extension Ownership {
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        // ... storage, init ...
        public typealias `Protocol` = __Ownership_Borrow_Protocol
    }
}
```

**V8_PathC CONFIRMED — the nested typealias is accessible without the generic parameter**:

```swift
extension Path: Ownership.Borrow.`Protocol` {}
//              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// No <Value> required — the typealias doesn't depend on Value.
```

This is the clinching finding. Conformance sites read exactly as the
user requested, without the generic-argument awkwardness of
`Ownership.Borrow<Path>.\`Protocol\``.

**V10 CONFIRMED — Tagged parametric conditional conformance via the hoisted typealias**:

```swift
extension Tagged: Ownership.Borrow.`Protocol`
where RawValue: Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable {
    public typealias Borrowed = RawValue.Borrowed
}
```

Both the conformance target and the where-clause constraint can use the
typealias form. The compile-time typealias probe `Tagged<Kernel, Path>.Borrowed`
resolves to `Path.Borrowed` through the parametric forwarding.

**Generic↔associatedtype interaction (V3 finding)**: when the protocol
admits `Self: ~Escapable`, the default `= Ownership.Borrow<Self>` only
type-checks if `Ownership.Borrow<Value>` accepts `Value: ~Escapable`.
The current declaration `Ownership.Borrow<Value: ~Copyable>: ~Escapable`
does not; it must widen to `Value: ~Copyable & ~Escapable`.

**Required compiler feature flags**: `Lifetimes` + `SuppressedAssociatedTypes`
must be enabled in `swiftSettings`. Both are already enabled in
swift-identity-primitives and swift-ownership-primitives.

### When a conformer needs a custom `.Borrowed` (case framing)

Given the default `associatedtype Borrowed = Ownership.Borrow<Self>`,
conformers fall into three cases:

| Case | Description | Examples | Custom `.Borrowed`? |
|------|-------------|----------|:-------------------:|
| **A** | Type IS its data (no interior storage) | `Ordinal`, `Cardinal`, `Radian<T>`, `Degree<T>`, `Hash.Value`, `Linear.Dx/Dy/Dz`, `Kernel.Completion.Token`, `Index<T>`, `Ordinal.Finite<N>`, most Tagged aliases | **No** — default suffices |
| **B** | Type owns interior storage + encodes a type-level invariant | `Path` (null-termination), `String` (null-termination), potentially `Buffer.Unbounded`, `Binary.Cursor` | **Yes** — invariant + direct-access specialization |
| **C** | Tagged wrapper | `Tagged<Tag, RawValue>` | **No** — conditional forwarding inherits RawValue's Borrowed |

**Significance**: under the current `Viewable` design, every conformer
MUST author a nested `View` struct because the protocol has no default.
Under the restructured design, **only Case B conformers declare a
nested `Borrowed`**. Cases A and C get conformance for free via the
default or via forwarding. This converts conformance from "authorship
event requiring per-type design" to "opt-in one-liner" for the majority
of domain types in the ecosystem.

The `view-vs-span-borrowed-access-types.md` DECISION (tier 2, 2026-02-28)
establishes why Case B's specialization is load-bearing: the
null-termination invariant is type-level information that the generic
`Ownership.Borrow<Path>` cannot encode. C-interop call sites require
the invariant; Path's specialized `Borrowed` carries it.

### Option A: Status quo (keep current Viewable in identity-primitives)

Defer the restructure. Accept that `Viewable` is a marker protocol with
minimal dispatch utility, that it lives in a mis-named package, and that
its naming violates the ecosystem convention.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Type-safety | Neutral |
| Convention compliance | **Violates** [PKG-NAME-001] (identity-primitives name), [PKG-NAME-002] (Viewable is -able, not gerund-typealias onto `.Protocol`) |
| Ecosystem coherence | Low — placement mismatch; no structural relationship to Ownership.Borrow<Value> |
| Conformer authorship cost | High — every conformer must author a nested View type |
| Migration cost | Zero |

**Verdict**: Rejected. Convention violations are real; conformer
authorship cost prevents broader adoption. The marker protocol is
pulling its weight but barely, and a better shape exists.

### Option B: Delete Viewable entirely, replace with per-RawValue extensions

For each type that currently exposes a View (Path, String, etc.),
declare an explicit `extension Tagged where RawValue == X { typealias Borrowed = X.Borrowed }`.
No protocol; no default; no parametric forwarding.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Type-safety | Neutral |
| Convention compliance | N/A (no protocol to comply) |
| Ecosystem coherence | Low — typealiases scattered per RawValue |
| Conformer authorship cost | Per-RawValue explicit extension required |
| Migration cost | Low |

**Verdict**: Rejected by user directive: "We wouldn't want to have
typealiases all over the place." The scattering cost outweighs the
simplification.

### Option C: Restructure as `Ownership.Borrow.\`Protocol\`` via hoisting

The shape experimentally confirmed in V8 + V8_PathC + V10.

```swift
// Hoisted protocol at module scope (swift-ownership-primitives):
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = Ownership.Borrow<Self>
}

extension Ownership {
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {
        @usableFromInline let _pointer: UnsafePointer<Value>
        // ... existing init, value accessor ...

        // Nested typealias exposes the hoisted protocol at the desired path:
        public typealias `Protocol` = __Ownership_Borrow_Protocol
    }
}

// Conformance sites (all packages):
extension Path: Ownership.Borrow.`Protocol` {}         // Case B: Path.Borrowed defined separately
extension String: Ownership.Borrow.`Protocol` {}       // Case B
extension Radian: Ownership.Borrow.`Protocol` {}       // Case A: default applies
extension Tagged: Ownership.Borrow.`Protocol`          // Case C: parametric forwarding
where RawValue: Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable {
    public typealias Borrowed = RawValue.Borrowed
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Type-safety | Improved — protocol DOES carry meaningful contract ("I expose a borrow-like projection") and default makes trivial conformance costless |
| Convention compliance | **[PKG-NAME-002] compliant** — `Namespace.\`Protocol\`` form; typealias omitted (skill permits this when no natural gerund reads correctly, as is the case here since `Borrowing` conflicts with the `borrowing` modifier) |
| Ecosystem coherence | **High** — protocol and generic struct colocated in Ownership.Borrow; specialization lattice visible structurally |
| Conformer authorship cost | **Near-zero** for Case A and C; Case B unchanged (Path/String still author Path.Borrowed, String.Borrowed per existing DECISION) |
| Migration cost | Moderate — rename Viewable → Ownership.Borrow.`Protocol`, View → Borrowed, update all conformers. Pre-release so no back-compat constraints. |
| SE-0519 alignment | **Preserved** — `Ownership.Borrow<Value>` unchanged; stdlib mapping intact |
| Generic↔associatedtype interaction | Resolved — Pointer's Value widens to `~Copyable & ~Escapable` to match the protocol's `~Copyable, ~Escapable` Self |

**Verdict**: Selected. This option alone satisfies all design constraints
simultaneously.

### Hoisting trade-offs (considered and accepted)

The hoisted `__Ownership_Borrow_Protocol` is visible at module scope under
swift-ownership-primitives. Two implications:

- **Discoverability**: readers of the ownership-primitives module see both
  `Ownership.Borrow.\`Protocol\`` (the canonical spelling) and
  `__Ownership_Borrow_Protocol` (the underlying implementation). The `__`
  prefix convention signals "implementation detail, use the canonical
  form."
- **Ecosystem precedent**: `swift-tree-primitives` already uses the same
  pattern for `__TreeNChildSlot<n>` (hoisted for value-generic nesting
  limitations, exposed as `Tree<E>.N<n>.ChildSlot`). The hoisting cost is
  accepted ecosystem-wide.

### Secondary finding: typealias naming convention reinforced

Per [PKG-NAME-002], the top-level gerund typealias (e.g., `Rendering = Render.\`Protocol\``)
is the canonical form, NOT an `-able` typealias. The experiment verified
that `Viewable`, `Borrowable`, and `Lending` all compile identically as
typealiases — the choice is a convention matter, not a compiler matter.

For this unification: **no top-level typealias**. The `borrowing` Swift
parameter modifier creates reader friction with any `Borrowing` type
identifier. Per [PKG-NAME-002] the typealias MAY be omitted when no
natural gerund reads correctly. Conformance sites use the explicit form
`Ownership.Borrow.\`Protocol\``.

## Outcome

**Status**: DECISION

**Decision**: Adopt Option C (restructure via hoisting).

### The unified shape

1. **Hoisted protocol** in swift-ownership-primitives at module scope,
   with `__` prefix signaling implementation detail.
2. **Nested typealias** `public typealias \`Protocol\` = __Ownership_Borrow_Protocol`
   inside `Ownership.Borrow<Value>` struct body (NOT in an extension, to
   avoid the suppression-repeat-requirement caveat observed in
   experiment V9).
3. **Associatedtype default** `Borrowed = Ownership.Borrow<Self>` — types
   without interior storage get conformance with zero custom types.
4. **Generic struct constraint widening**: `Ownership.Borrow<Value: ~Copyable & ~Escapable>: ~Escapable`
   to satisfy the generic↔associatedtype interaction.
5. **No top-level gerund typealias** — collision with `borrowing`
   modifier. Typealias omission permitted by [PKG-NAME-002].

### Ecosystem-wide rename cascade (pre-release; no back-compat)

- `swift-identity-primitives/Sources/Identity Primitives/Viewable.swift` → DELETED.
- `swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift` → renamed to `Tagged+Ownership.Borrow.Protocol.swift` or similar; conformance updated to `Ownership.Borrow.\`Protocol\``; associatedtype renamed `View` → `Borrowed`.
- `swift-path-primitives/Sources/Path Primitives/Path.View.swift` → renamed to `Path.Borrowed.swift`; nested type `Path.View` → `Path.Borrowed`; conformance updated.
- `swift-string-primitives/Sources/String Primitives/String.View.swift` → renamed to `String.Borrowed.swift`; nested type `String.View` → `String.Borrowed`; conformance updated.
- `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift` → widens Value constraint; adds hoisted protocol + nested typealias.
- **New file**: `swift-ownership-primitives/Sources/Ownership Primitives/__Ownership_Borrow_Protocol.swift` — module-scope hoisted protocol declaration.
- **Downstream**: any usage of `Path.View` / `String.View` / `Tagged.View` in other packages (foundations, standards) updates to `.Borrowed`.
- **Coordinated with**: `swift-identity-primitives` → `swift-tagged-primitives` package rename (separate but concurrent work).

### Requirement IDs (candidates for future codification)

The following are candidate requirement IDs that this decision establishes;
actual codification happens via skill updates in the appropriate skill files:

- **[OBP-001] Protocol placement**: The Ownership.Borrow.`Protocol` capability protocol is the canonical "provides a borrowed projection" marker for the ecosystem.
- **[OBP-002] Default associatedtype**: Conformers without interior storage or type-level invariants inherit `Borrowed = Ownership.Borrow<Self>` and declare no custom nested type.
- **[OBP-003] Specialization**: Conformers with interior storage OR type-level invariants declare a nested `Borrowed: ~Copyable, ~Escapable` struct encoding those invariants, overriding the default.
- **[OBP-004] Tagged forwarding**: `Tagged<Tag, RawValue>` conforms conditionally with `typealias Borrowed = RawValue.Borrowed`, inheriting specialization parametrically.

These are proto-rules; they enter the skill corpus via the skill-lifecycle
process after the production implementation lands.

## References

### Primary sources

- Experiment: `swift-primitives/Experiments/ownership-borrow-protocol-unification/` — CONFIRMED, 10 variants, Swift 6.3.1, 2026-04-22.
- Current protocol: `swift-identity-primitives/Sources/Identity Primitives/Viewable.swift`.
- Current Tagged conditional conformance: `swift-identity-primitives/Sources/Identity Primitives/Tagged+Viewable.swift`.
- Current Path View: `swift-path-primitives/Sources/Path Primitives/Path.View.swift`.
- Current String View: `swift-string-primitives/Sources/String Primitives/String.View.swift`.
- Current Ownership.Borrow<Value>: `swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift`.

### Prior ecosystem research

- `swift-primitives/Research/view-vs-span-borrowed-access-types.md` (DECISION, tier 2, 2026-02-28) — establishes that View is an irreducible concept distinct from Span; grounds the Case B specialization argument.
- `swift-identity-primitives/Research/comparative-analysis-pointfree-swift-tagged.md` (DECISION, tier 2, 2026-02-26) — documents Tagged's design including the Viewable forwarding.
- `swift-primitives/Research/implicit-member-init-resolution-hazard.md` (DECISION, tier 3) — init taxonomy referenced for constraint-compatibility reasoning.
- `swift-primitives/Research/tagged-unchecked-construction-inventory.md` (ANALYSIS, tier 2, 2026-04-22) — inventory informing the ecosystem's Tagged surface.

### Prior experiments

- `swift-identity-primitives/Experiments/tagged-view-protocol/` — CONFIRMED, 2026-02-28 — original Viewable-protocol feasibility experiment.
- `swift-identity-primitives/Experiments/tagged-view-struct/` — CONFIRMED, 2026-02-28 — alternative Tagged.View struct approach.

### Language references

- SE-0404 (Allow Protocols to be Nested in Non-Generic Contexts) — explains why direct nesting in generic contexts remains prohibited.
- SE-0446 (Nonescapable Types) — `~Escapable` introduction.
- SE-0447 (Span) — contiguous non-escapable view.
- SE-0519 (Borrow<T> / Mutate<T>) — stdlib borrow types; `Ownership.Borrow<Value>` mirrors.
- Swift language experimental features: `Lifetimes`, `SuppressedAssociatedTypes` — required in swiftSettings.

### Ecosystem precedent

- `swift-tree-primitives/Sources/Tree Primitives Core/Tree.N.ChildSlot.swift` — same `__` hoisting pattern for value-generic nesting limitations (ChildSlot hoisted as `__TreeNChildSlot<n>`).
