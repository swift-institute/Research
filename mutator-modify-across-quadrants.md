# `_modify` across the four Copyable × Escapable quadrants

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 2
scope: ecosystem-wide
relocated_from: swift-mutator-primitives/Research/modify-across-quadrants.md
relocation_date: 2026-04-25
---
-->

> Reframed from DECISION to REFERENCE on 2026-04-25. Empirical Swift
> findings (`mutating _modify` not valid in protocol property
> requirements; `@_lifetime(&self)` for inout-ownership dependence)
> remain authoritative for any future ecosystem package considering a
> full-capability mutation protocol. Companion experiment:
> `swift-institute/Experiments/mutator-modify-across-quadrants/`.

## Context

`Mutator.\`Protocol\`` (`Mutable`) declares a `value: Value` with a
`borrowing get + set` requirement, mirroring `Carrier`'s `borrowing get`
shape but adding mutation capability. The protocol must work across all
four Copyable × Escapable quadrants of (Self, Value), as Carrier does —
otherwise the package's reach is artificially narrower than its
sibling, and consumers that mutate `~Copyable` resources or `~Escapable`
scoped views fall off the protocol surface.

The relax-trivial-self-default experiment in
`swift-carrier-primitives/Experiments/relax-trivial-self-default/`
(CONFIRMED, 2026-04-25) established the **read-only** four-quadrant
default-extension pattern for Carrier. This document characterizes the
parallel **read+modify** pattern for Mutator, grounded in the
empirical results of `swift-institute/Experiments/mutator-modify-across-quadrants/`
(CONFIRMED, 2026-04-25).

The work also surfaced two corrective findings that update prior
ecosystem assumptions about `_modify` in protocol requirements and
about lifetime annotations on inout-yielding coroutines.

## Question

Five sub-questions:

1. **Can `mutating _modify` be a protocol requirement?** The natural
   spelling — *"the protocol requires a mutating modify accessor"* —
   needs empirical verification.
2. **What lifetime annotations apply to `_modify` for ~Escapable Self?**
   `Carrier`'s `borrowing get` uses `@_lifetime(borrow self)`; what's
   the parallel for inout-ownership accessors?
3. **Does the four-quadrant trivial-self-default pattern hold for
   `_modify`?** Carrier's read-only pattern was confirmed; the
   read+modify pattern is structurally similar but adds inout-yielding,
   which has different language semantics.
4. **Can ~Copyable Value participate?** The `set` requirement
   traditionally takes `Value` by-value; for ~Copyable Value, that's
   forbidden. Does coroutine-form `_modify { yield &storage }`
   satisfy the `set` requirement when Value is ~Copyable?
5. **What does generic dispatch over `inout some Mutable<T>` require?**
   How do conformers in each quadrant participate in generic
   algorithms?

## Analysis

### Methodology

Two experiments authored at:

- `swift-institute/Experiments/mutator-modify-across-quadrants/Sources/modify-across-quadrants/main.swift`
  — same-package probe (V1–V5) covering Q1/Q2/Q3/Q4 trivial-self
  defaults plus a distinct-Value `~Copyable` Value variant.
- `swift-institute/Experiments/mutator-modify-across-quadrants/Sources/MutableLib/MutableLib.swift`
  + `Sources/MutableConsumer/main.swift` — cross-module probe per
  [EXP-017]'s release+cross-module gate, exercising the same shapes
  through a module boundary.

Both were built in debug AND release mode; the cross-module consumer
exercises `inout some Mutable<T>` generic dispatch with explicit
`& ~Copyable` / `& ~Escapable` suppression.

### Finding 1 — `mutating _modify` is NOT a valid protocol requirement (REFUTED)

Initial draft of the protocol used `mutating _modify` directly in the
`var value: Value { ... }` requirement:

```swift
public protocol Mutable<Value>: ~Copyable, ~Escapable {
    var value: Value {
        @_lifetime(borrow self) borrowing get
        @_lifetime(borrow self) mutating _modify   // ❌
    }
}
```

Compiler diagnostic:

```
error: expected get or set in a protocol property
        mutating _modify
                 ^- error: expected get or set in a protocol property
```

**Verdict**: REFUTED. Swift 6.3.1 admits only `get` / `set` /
`borrowing get` / `consuming get` in protocol property requirements;
coroutine forms (`_read`, `_modify`) are not protocol-requirement
syntax. Implementations may satisfy `set` with either `set { ... }` or
a `_modify { yield &storage }` coroutine — the coroutine form is
required when Value is ~Copyable, since a by-value `set { newValue }`
body cannot be authored without copying.

The corrected protocol shape uses `set` as the requirement:

```swift
public protocol Mutator {
    public protocol `Protocol`<Value>: ~Copyable, ~Escapable {
        associatedtype Value: ~Copyable & ~Escapable

        var value: Value {
            @_lifetime(borrow self)
            borrowing get
            set
        }
    }
}
```

### Finding 2 — `@_lifetime(&self)`, not `@_lifetime(borrow self)`, on `_modify` (REFUTED with redirection)

Implementation extension's first draft used `@_lifetime(borrow self)`
on `_modify`:

```swift
extension Mutable where Value == Self, Self: ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(borrow self)        // ❌
        _modify { yield &self }
    }
}
```

Compiler diagnostic:

```
error: invalid use of borrow dependence with inout ownership
@_lifetime(borrow self)
                  |- error: invalid use of borrow dependence with inout ownership
                  `- note: use '@_lifetime(&self)' instead
_modify { yield &self }
```

**Verdict**: REFUTED. `_modify` yields by inout, not by borrow; the
correct lifetime annotation is `@_lifetime(&self)` (matching the inout
ownership semantics). The compiler's note explicitly directs to the
right form.

### Finding 3 — `@_lifetime` on `set` requirements is rejected (REFUTED)

Attempted to annotate `set` in the protocol:

```swift
var value: Value {
    @_lifetime(borrow self) borrowing get
    @_lifetime(&self) set                  // ❌
}
```

Compiler diagnostic:

```
error: invalid lifetime dependence on an Escapable result
@_lifetime(&self)
 `- error: invalid lifetime dependence on an Escapable result
set
```

**Verdict**: REFUTED. `set` does not have an Escapable result that
lifetime annotations can attach to (it accepts a parameter; it does
not return). The protocol's `set` requirement therefore carries no
`@_lifetime` annotation. Implementations using `_modify` to satisfy
`set` carry the lifetime annotation on the `_modify` accessor itself.

### Finding 4 — Four-quadrant trivial-self-default pattern holds (CONFIRMED)

With Findings 1–3 applied, the four sibling default extensions for
`Mutable where Value == Self` typecheck and execute. Variant table:

| Quadrant | Self | Value | Read accessor | Modify accessor | `@_lifetime` |
|----------|------|-------|--------------|-----------------|---------------|
| Q1 | Copyable, Escapable | Copyable, Escapable | `_read { yield self }` | `_modify { yield &self }` | none |
| Q2 | ~Copyable, Escapable | ~Copyable, Escapable | `_read { yield self }` | `_modify { yield &self }` | none |
| Q3 | Copyable, ~Escapable | Copyable, ~Escapable | `@_lifetime(borrow self) _read { yield self }` | `@_lifetime(&self) _modify { yield &self }` | required on both |
| Q4 | ~Copyable & ~Escapable | ~Copyable & ~Escapable | `@_lifetime(borrow self) _read { yield self }` | `@_lifetime(&self) _modify { yield &self }` | required on both |

Variant outputs from V1–V5:

```
V1 Q1: c.value.raw = 12               (Counter raw 7 + 5 via .value.raw mutation)
V2 Q2: c.value.raw = 17               (UniqueCounter raw 13 + 4)
V3 Q3: span.value.count = 3           (MutableSpan trivial-self, read path)
V4 Q4: h.value.raw = 28               (ScopedHandle raw 21 + 7)
V5 distinct-Value: box.value.raw = 123 (DescriptorBox.value: RawDescriptor; raw 100 + 23)
```

V5 is the explicit-witness case (Value ≠ Self, Value: ~Copyable) — the
default extensions don't apply, and the conformer authors
`_read`/`_modify` directly on the wrapped storage. This case is
load-bearing because the trivial-self defaults only cover Self == Value;
genuine wrappers with distinct Value (resource handles, boxes, projection
types) need explicit witnesses.

### Finding 5 — Cross-module + release passes (CONFIRMED, [EXP-017] gate)

Cross-module consumer (`Sources/MutableConsumer/main.swift`) imports
`MutableLib` (the sibling library declaring the protocol + defaults)
and exercises Q1/Q2/Q3/Q4 + distinct-Value through the module boundary.
Both debug and release builds pass; runtime output:

```
Q1 cross-module: c.value.raw = 8           (Counter 7 + 1)
Q2 cross-module: u.value.raw = 15          (UniqueCounter 13 + 2)
Q3 cross-module: span.value.count = 3      (MutableSpan)
Q4 cross-module: s.value.raw = 24          (ScopedHandle 21 + 3)
Distinct-Value cross-module: box.value.raw = 105 (DescriptorBox 100 + 5)
```

The four-quadrant pattern survives the module boundary, including for
generic dispatch through `inout some Mutable<T>`.

### Finding 6 — Generic dispatch defaults to Copyable & Escapable (CONFIRMED)

The cross-module consumer initially declared:

```swift
func bumpRawScoped(_ handle: inout some Mutable<ScopedHandle>) { ... }
```

Compiler error at the call site:

```
error: global function 'bumpRawScoped' requires that 'ScopedHandle' conform to 'Copyable'
note: 'some Mutable<ScopedHandle> & Copyable' is implicit here
```

**Verdict**: CONFIRMED — Swift's `some Protocol` constraint defaults to
`Copyable & Escapable`. To accept `~Copyable` or `~Escapable` conformers,
the constraint must explicitly suppress:

```swift
func bumpRawScoped<H: Mutable<ScopedHandle> & ~Copyable & ~Escapable>(_ handle: inout H) {
    handle.value.raw += 3
}
```

This is a general Swift behavior, not specific to `Mutable`. It applies
identically to `Carrier`. Documentation and DocC examples must include
the suppression form for ~Copyable / ~Escapable cases; otherwise
consumers will silently lose the generic-dispatch capability for those
quadrants.

### Conformance recipe summary

The recipes mirror Carrier's four-quadrant table with the additional
`_modify` row.

```swift
// Q1 — explicit witness (Value: Copyable, Escapable, distinct from Self)
extension Foo: Mutable {
    typealias Value = SomeValue
    var value: SomeValue {
        get { _storage }
        set { _storage = newValue }   // or: _modify { yield &_storage }
    }
}

// Q2 — explicit witness (Value: ~Copyable, Escapable)
extension Bar: Mutable {
    typealias Value = SomeNoncopyValue
    var value: SomeNoncopyValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}

// Q3 — explicit witness (Value: Copyable, ~Escapable)
extension Baz: Mutable {
    typealias Value = SomeView
    var value: SomeView {
        @_lifetime(borrow self) get { _storage }
        @_lifetime(&self) _modify { yield &_storage }
    }
}

// Q4 — explicit witness (Value: ~Copyable & ~Escapable)
extension Qux: Mutable {
    typealias Value = SomeNoncopyView
    var value: SomeNoncopyView {
        @_lifetime(borrow self) _read { yield _storage }
        @_lifetime(&self) _modify { yield &_storage }
    }
}

// Trivial-self (Value == Self) — pick up defaults
extension Counter: Mutable {
    typealias Value = Counter
    // value's _read and _modify provided by sibling default extensions.
}
```

## Outcome

**Status**: DECISION — the protocol shape and four-quadrant default
pattern are empirically validated and ship in v0.1.0.

**The protocol declaration**:

```swift
public enum Mutator {
    public protocol `Protocol`<Value>: ~Copyable, ~Escapable {
        associatedtype Value: ~Copyable & ~Escapable

        var value: Value {
            @_lifetime(borrow self)
            borrowing get
            set
        }
    }
}

public typealias Mutable = Mutator.`Protocol`
```

**Default extensions** for `Value == Self` cover Q1/Q2/Q3/Q4 with
quadrant-appropriate `@_lifetime` annotations.

**Generic dispatch** through `inout some Mutable<T>` defaults to
Copyable & Escapable; explicit `& ~Copyable` / `& ~Escapable`
suppression admits the other quadrants.

**Cross-module + release** validated per [EXP-017].

**Rationale**:

1. **Symmetry with Carrier**: Mutator's read+modify shape parallels
   Carrier's read-only shape; both use the same lifetime-annotation
   discipline (`borrow self` for reads; `&self` for modifies).
2. **`_modify` is the protocol-requirement workaround for ~Copyable
   Value**: the protocol declares `set`; conformers satisfy it with
   `_modify { yield &storage }` when Value cannot be passed by-value.
3. **The four-quadrant pattern is genuinely four-quadrant**: not
   approximated for some quadrants. Q3/Q4 conformers (e.g.,
   `MutableSpan` already; future ~Copyable spans, ~Escapable view
   wrappers) participate without ceremony beyond the type-alias line.

**Revisit triggers**:

- Swift evolves `_modify` into a protocol-requirement keyword (the
  current Swift Evolution thread on coroutine accessors). At that point,
  the protocol can declare `_modify` directly, eliminating the `set →
  _modify` indirection. The conformer-side experience is unchanged;
  this is purely a protocol-declaration cleanup.
- Swift relaxes the default Copyable & Escapable constraint on `some
  Protocol`. The generic-dispatch ergonomics improve; the four-quadrant
  pattern itself does not change.
- Toolchain bug: a future release-mode SIL pass mishandles
  `_modify { yield &self }` for ~Escapable Self. Mitigation would
  require switching the affected quadrant to a different shape (e.g.,
  per-conformer explicit witnesses); the protocol's API would not
  change.

## References

### Primary sources

- `swift-institute/Experiments/mutator-modify-across-quadrants/Sources/modify-across-quadrants/main.swift`
  (CONFIRMED, 2026-04-25) — V1–V5 same-package probe.
- `swift-institute/Experiments/mutator-modify-across-quadrants/Sources/MutableLib/MutableLib.swift`
  + `Sources/MutableConsumer/main.swift` (CONFIRMED, 2026-04-25) —
  cross-module + release gate per [EXP-017].

### Foundational research

- `swift-carrier-primitives/Experiments/relax-trivial-self-default/`
  (CONFIRMED, 2026-04-25) — the read-only four-quadrant pattern for
  Carrier; the structural template this document extends.
- `swift-carrier-primitives/Sources/Carrier Primitives/Carrier where Underlying == Self*.swift`
  — the four sibling default-extension files for Carrier; the
  production reference for the lifetime-annotation discipline.
- `swift-carrier-primitives/Research/round-trip-semantics-noncopyable-underlyings.md`
  (DECISION, 2026-04-24) — the `~Copyable` Underlying round-trip
  semantics from which the `_read { yield self }` pattern was derived.

### Convention sources

- **[EXP-017]** — release-mode + cross-module gate for adoption-
  admitting experiments.
- **[API-NAME-002]** — boolean-naming exception is irrelevant here;
  noted to clarify that `value` is not a boolean property and follows
  the noun-named-property convention.
- **[MEM-COPY-004]** — extension restating of `~Copyable` constraints
  on generic parameters; relevant to dual-conformance generic
  algorithms.

### Language references

- **SE-0427** — Noncopyable generics (the basis for `Self: ~Copyable`
  suppression).
- **SE-0506** — Noncopyable associated types (the basis for the
  `Value: ~Copyable & ~Escapable` associated-type bound).
- Swift 6.3.1 release notes — the `Lifetimes` and
  `SuppressedAssociatedTypes` experimental features used by the
  package's swiftSettings.
