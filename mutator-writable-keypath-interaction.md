# `WritableKeyPath` and `@dynamicMemberLookup` interaction with `Mutable`

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 2
scope: ecosystem-wide
relocated_from: swift-mutator-primitives/Research/keypath-interaction.md
relocation_date: 2026-04-25
---
-->

> Reframed from DECISION to REFERENCE on 2026-04-25. The Q1-only
> constraint (`WritableKeyPath<Root, Value>` requires `Root: Copyable
> & Escapable`) propagates through any protocol-extension dynamic-member
> subscript and applies regardless of which Mutator-shape ecosystem
> package eventually emerges. Mirrors the prior Carrier finding
> (`swift-carrier-primitives/Research/dynamic-member-lookup-decision.md`).
> Companion experiment:
> `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/`.

## Context

`Mutator.\`Protocol\`` (`Mutable`) exposes a `value: Value` accessor with
read+modify semantics. A natural ergonomic question: should the protocol
ship a `@dynamicMemberLookup` extension with a
`subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>)` so
consumers can write `wrapper.foo = newValue` instead of
`wrapper.value.foo = newValue`?

This question has direct precedent in
`swift-carrier-primitives/Research/dynamic-member-lookup-decision.md`
(DECISION, 2026-04-25), which examined the read-only `KeyPath` case for
Carrier and concluded *do not add `@dynamicMemberLookup` to the Carrier
protocol*. The Carrier reasoning was: `KeyPath<Root, Value>` carries an
implicit `Root: Copyable & Escapable` constraint that propagates through
the protocol-extension subscript, restricting the affordance to Q1
conformers only and breaking the four-quadrant uniformity the rest of
the protocol provides.

The same question recurs for Mutator with `WritableKeyPath` instead of
`KeyPath`. This document examines the question empirically (per
`swift-institute/Experiments/mutator-generic-dispatch-and-keypath/`, CONFIRMED 2026-04-25) and
reaches the same DECISION the Carrier counterpart did.

## Question

Three sub-questions:

1. **Does `WritableKeyPath` carry the same `Root: Copyable & Escapable`
   constraint as `KeyPath`?** If yes, the affordance is structurally
   Q1-only.
2. **What is observable in Swift 6.3.1 when consumers attempt
   `wrapper.member = value` on Q2/Q3/Q4 conformers?** If the
   diagnostic is asymmetric or surprising, that's worse than uniform
   absence of the affordance.
3. **Is the consumer-side escape hatch sufficient?** A specific
   conformer that wants the affordance can apply
   `@dynamicMemberLookup` to itself; this scopes the choice locally.

## Analysis

### Methodology

The empirical work lives at
`swift-institute/Experiments/mutator-generic-dispatch-and-keypath/Sources/generic-dispatch-and-keypath/main.swift`
(CONFIRMED 2026-04-25), which:

1. Annotates `Mutable` with `@dynamicMemberLookup`.
2. Provides a default subscript on a protocol extension:

   ```swift
   extension Mutable {
       public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
           get { value[keyPath: keyPath] }
           set { value[keyPath: keyPath] = newValue }
       }
   }
   ```

3. Probes member access (`u.raw = 200`) on conformers in each quadrant
   (Q1: `Counter`, Q2: `UniqueCounter`, Q3: `ScopedView`, Q4: `ScopedHandle`)
   AND on a distinct-Value wrapper (`DescriptorBox` whose `Value` is
   `RawDescriptor`).

### Finding 1 — Trivial-self conformers bypass the dynamic-member subscript (CONFIRMED, scope-clarification)

Every trivial-self conformer (Value == Self) — across Q1, Q2, Q3, Q4 —
allowed `u.raw = 200` to compile and execute, regardless of whether the
conformer was Copyable/~Copyable/~Escapable.

This is **not** evidence that the dynamic-member subscript materializes
for non-Q1 quadrants. It's evidence that Swift prefers
direct-member-access resolution over `@dynamicMemberLookup`. For the
trivial-self case (`Counter.value` IS Counter; the field `raw` lives on
Counter directly), `c.raw` resolves as a normal property access on
Counter — no subscript is invoked.

Output trace:

```
V2 Q1 KeyPath set: c.raw = 200; c.value.raw = 200
Q2 KeyPath set RESOLVED: u.raw = 200            (direct-member, not subscript)
Q3 KeyPath set: s.raw = 999                     (direct-member)
Q4 KeyPath set: h.raw = 888                     (direct-member)
```

The "RESOLVED" annotation in the Q2 output reflects the experiment's
initial misreading of the result; the corrected interpretation is that
direct-member access bypassed the subscript path entirely.

### Finding 2 — Distinct-Value subscript REFUTES for ~Copyable (CONFIRMED)

When the experiment introduces a wrapper `DescriptorBox: Mutable` with
`typealias Value = RawDescriptor` (a distinct ~Copyable Value), the
genuine subscript path is forced (because `DescriptorBox` has no
direct member named `raw`; the dynamic-member lookup is the only way
to resolve `box.raw`).

Compiler diagnostic (REFUTED):

```
error: referencing subscript 'subscript(dynamicMember:)' on 'Mutable'
       requires that 'DescriptorBox' conform to 'Copyable'
note: 'where Self: Copyable' is implicit here
public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {

error: subscript 'subscript(dynamicMember:)' requires that
       'DescriptorBox.Value' (aka 'RawDescriptor') conform to 'Copyable'
note: where 'Self.Value' = 'DescriptorBox.Value' (aka 'RawDescriptor')
```

The diagnostics state the constraints explicitly: `WritableKeyPath<Root,
Value>` requires both `Self: Copyable` (the wrapper) AND `Value: Copyable`
(the keypath's Root). Either failure prevents the subscript from
materializing.

This **confirms the prior Carrier finding** — the `KeyPath` /
`WritableKeyPath` ecosystem-wide constraint on `Root: Copyable &
Escapable` is unchanged in Swift 6.3.1, and propagates through the
protocol-extension subscript path on Mutator just as it did on Carrier.

The contradiction-suspicion that `WritableKeyPath` might admit
~Copyable Root in Swift 6.3.1 is REFUTED. The genuine subscript path
is Q1-only on the (Self, Value) grid.

### Finding 3 — Asymmetric diagnostic across quadrants

The empirical observation has a subtle asymmetry that's load-bearing
for the DECISION:

| Conformer | Member access | Resolves through |
|-----------|---------------|------------------|
| Q1 trivial-self (Counter) | `c.raw` | Direct member access OR dynamic-member subscript (both available; Swift picks direct) |
| Q2 trivial-self (UniqueCounter) | `u.raw` | Direct member access (subscript would fail; doesn't fire) |
| Q3 trivial-self (ScopedView) | `s.raw` | Direct member access |
| Q4 trivial-self (ScopedHandle) | `h.raw` | Direct member access |
| Q1 distinct-Value wrapper | `box.foo` | Dynamic-member subscript (fires; succeeds) |
| Q2/Q3/Q4 distinct-Value wrapper | `box.foo` | Dynamic-member subscript (fires; FAILS to compile) |

The user's mental model — *"this protocol gives me dynamic member access
for free"* — is broken in two non-obvious ways:

- For trivial-self Q2/Q3/Q4, the affordance "appears to work" but is
  actually direct-member access. Adding a non-trivial Value to those
  conformers later silently breaks the appearance.
- For distinct-Value Q2/Q3/Q4, the affordance fails at compile time
  with a constraint diagnostic that mentions `Copyable` requirements
  the consumer didn't write at the conformer.

Both failure modes are worse than uniform absence of the affordance.

### Finding 4 — Consumer-side escape hatch is unaffected

A specific conformer that wants `@dynamicMemberLookup` for its own use
case applies it to itself:

```swift
@dynamicMemberLookup
struct CounterBox: Mutable {
    typealias Value = SomeCopyableValue
    var _storage: SomeCopyableValue
    var value: SomeCopyableValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<SomeCopyableValue, T>) -> T {
        get { _storage[keyPath: keyPath] }
        set { _storage[keyPath: keyPath] = newValue }
    }
}
```

This scopes the affordance locally to types where the consumer accepts
the Q1-only constraint. The Mutator protocol does not impose it on all
conformers.

### Reversibility

| Action | Reversibility |
|--------|---------------|
| Add `@dynamicMemberLookup` to Mutable later | Non-breaking (new lookup paths become available) |
| Remove `@dynamicMemberLookup` from Mutable later | Breaking (existing `wrapper.foo` call sites stop compiling) |

Same one-way-door analysis as Carrier.

## Outcome

**Status**: DECISION — do NOT add `@dynamicMemberLookup` to the
`Mutator.\`Protocol\`` (`Mutable`) protocol or its default extensions.
The constraint asymmetry across quadrants is identical to Carrier's
read-only KeyPath case; the same arguments resolve the same way.

**Rationale**:

1. **Asymmetry across quadrants** (Finding 1+2): The genuine subscript
   path is Q1-only because `WritableKeyPath<Root, Value>` requires
   both `Root: Copyable` and the wrapper conformer's `Self: Copyable`.
   Q2/Q3/Q4 distinct-Value cases fail at compile time. The
   trivial-self "successes" at Q2/Q3/Q4 are direct-member-access
   bypasses that don't reflect the protocol-level affordance.

2. **Conceptual fit** — Carrier's same argument applies: Mutator
   exists to keep mutation explicit and dispatched through the
   `value` accessor. Forwarding member access partially undoes the
   explicitness that `wrapper.value.foo = newValue` makes visible.
   The dot signals *"I am modifying through the protocol's
   modification surface."*

3. **One-way door**: adding the affordance later is non-breaking;
   removing it is breaking. Conservative default is don't add unless
   concrete demand surfaces.

4. **Consumer escape hatch** (Finding 4): specific Q1 consumers can
   apply `@dynamicMemberLookup` to their own type — scoping the choice
   locally without imposing it ecosystem-wide.

5. **Symmetry with Carrier**: the parent's read-only counterpart
   reached the same DECISION with the same evidence; consistency
   across sibling protocols matters for ecosystem coherence.

**Revisit triggers**:

- Swift relaxes `WritableKeyPath`'s `Root: Copyable & Escapable`
  constraint such that `WritableKeyPath<~Copyable Root, T>` and
  `WritableKeyPath<~Escapable Root, T>` typecheck. If the asymmetry
  is removed, the conceptual-fit argument becomes the sole remaining
  one against and is worth revisiting under concrete consumer demand.
- A pattern emerges where multiple ecosystem packages all apply
  `@dynamicMemberLookup` to their Q1 Mutable conformers — at that
  point the consumer-side escape hatch has become repetitive
  boilerplate and centralization may be worth the conceptual-fit
  cost.

Neither trigger is active as of 2026-04-25.

## References

### Primary sources

- `swift-institute/Experiments/mutator-generic-dispatch-and-keypath/Sources/generic-dispatch-and-keypath/main.swift`
  (CONFIRMED 2026-04-25) — V1–V8 probing trivial-self direct-member
  bypass and distinct-Value subscript REFUTED.

### Foundational research

- `swift-carrier-primitives/Research/dynamic-member-lookup-decision.md`
  (DECISION 2026-04-25) — the parent's read-only counterpart;
  identical structural reasoning, same DECISION outcome.
- `swift-carrier-primitives/Experiments/dynamic-member-lookup-quadrants/`
  (CONFIRMED 2026-04-25) — Carrier's empirical four-quadrant probe.
  This document's Finding 2 confirms the same constraint applies to
  `WritableKeyPath` in Swift 6.3.1.

### Convention sources

- **[EXP-006b]** — confirmation evidence requirements; this document
  cites observed compiler diagnostics verbatim.

### Language references

- **SE-0252** — Key Path Member Lookup (the language feature under
  evaluation).
- Swift stdlib's `WritableKeyPath` declaration — `Root: Copyable`
  constraint is implicit and not relaxed in Swift 6.3.1.
