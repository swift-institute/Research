# Machine.Value API Surface: Intent Over Mechanism

<!--
---
version: 1.0.0
last_updated: 2026-02-23
status: RECOMMENDATION
tier: 2
scope: machine-primitives
workflow: investigation
---
-->

## Context

`Machine.Value<Mode>` is a type-erased value container used during machine execution. It stores any typed value in an opaque `UnsafeMutableRawPointer` + `ObjectIdentifier` pair, with a `_Table` for type-specialized destruction. This is an Embedded-safe replacement for Swift's `Any` existential — existentials are unavailable in Swift Embedded, which is a design requirement for the primitives layer.

The type has two extraction methods:

- `take<T>(_:) -> T?` — safe, returns Optional
- `unsafeTake<T>(_:) -> T` — precondition-checked, traps on mismatch

An [IMPL-INTENT] audit identified `unsafeTake` as mechanism leaking into carrier call sites. This document investigates the value flow, identifies the intent/mechanism boundary, and recommends API changes.

## Question

Two questions:

1. Does `unsafeTake` violate [IMPL-INTENT], and if so, what should the intent-expressing API look like?
2. Should `unsafeTake` be public?

---

## Analysis

### Part 1: Value Flow Through the Machine

Values flow through three phases:

**Phase 1 — Construction** (typed → erased):
```
User function produces typed result
    → Machine.Value<Mode>.make(result)
        → allocate UnsafeMutablePointer<T>, store ObjectIdentifier(T.self)
            → arena.allocate(value) → Handle
```

**Phase 2 — Transport** (erased, handle-based):
```
Handle stored in Frame (map, sequence, many, fold, optional)
    → arena.release(handle) when needed
        → Machine.Value<Mode> passed to carrier's apply/combine/next/finalize
```

**Phase 3 — Extraction** (erased → typed):
```
Inside carrier closure:
    value.unsafeTake(In.self)  → typed input
    transform(input)           → typed output
    Machine.Value<Mode>.make(output)  → erased for next phase
```

The execution loop (parser-machine's `Run.swift`, ~392 lines) **never calls `unsafeTake` or `take` directly**. All value extraction happens inside the 5 erased carrier types. The only `take` call in the entire execution engine is at the final output boundary:

```swift
guard let result = value.take(Output.self) else {
    fatalError("Type mismatch in Machine output")
}
```

### Part 2: Where `unsafeTake` Appears

Every production call site follows one of three patterns:

**Pattern A — Unary application** (Transform.Erased, Transform.Throwing, Next.Erased):
```swift
let input = value.unsafeTake(In.self)
return Machine.Value<Mode>.make(transform(input))
```

**Pattern B — Binary application** (Combine.Erased):
```swift
let aVal = a.unsafeTake(A.self)
let bVal = b.unsafeTake(B.self)
return Machine.Value<Mode>.make(combineFn(aVal, bVal))
```

**Pattern C — Array extraction** (Finalize.Array):
```swift
values.map { $0.unsafeTake(T.self) }
```

Complete inventory:

| Carrier | Sites | Pattern |
|---------|-------|---------|
| Transform.Erased (Reference) | 1 | A |
| Transform.Erased (Unchecked) | 1 | A |
| Transform.Throwing (Reference) | 1 | A |
| Transform.Throwing (Unchecked) | 1 | A |
| Next.Erased (Reference) | 1 | A |
| Next.Erased (Unchecked) | 1 | A |
| Combine.Erased (Reference) | 1 | B |
| Combine.Erased (Unchecked) | 1 | B |
| Finalize.Array (Reference) | 1 | C |
| Finalize.Array (Unchecked) | 1 | C |
| **Total** | **10** | |

No other production code calls `unsafeTake`. Tests use it once (for the `unsafeTake` test itself).

### Part 3: Intent vs Mechanism Analysis

Per [IMPL-INTENT], each call site should read as what it accomplishes, not how.

**Current (mechanism)**:
```swift
// Transform — "extract the input by raw pointer projection, apply the function,
//              then box the output into a new heap allocation"
let input = value.unsafeTake(In.self)
return Machine.Value<Mode>.make(transform(input))
```

The call site describes three mechanical steps: unbox, apply, rebox. The developer reading this must understand `Machine.Value` internals to know what's happening.

**Ideal (intent)**:
```swift
// Transform — "apply the transform to the value"
value.apply(transform)
```

The call site states the intent: apply a typed function to an erased value, producing a new erased value. The unbox/rebox mechanism lives inside `Value.apply`.

### Part 4: Proposed Value-Level Operations

Three operations cover all 10 call sites:

**Operation 1 — `apply`** (covers Pattern A, 6 sites):
```swift
extension Machine.Value {
    /// Applies a typed function to this erased value, returning an erased result.
    ///
    /// The input type `In` must match the type used at construction.
    /// - Precondition: `self` was created with `make(_:)` where the value was of type `In`.
    @usableFromInline
    func apply<In, Out>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        precondition(
            type == ObjectIdentifier(In.self),
            "Machine.Value type mismatch: expected \(In.self), got type with id \(type)"
        )
        return .init(
            type: ObjectIdentifier(Out.self),
            storage: _Storage(
                payload: /* allocate and initialize Out */,
                table: _Table(Out.self)
            )
        )
    }
}
```

Wait — this has a problem. `apply` needs to be generic over the `Sendable` constraint for Reference mode. And it allocates a new `_Storage`, which requires the same `UnsafeMutablePointer` dance. The mechanism doesn't disappear — it just moves inside `apply`.

But that's exactly the point. Per [IMPL-000]: mechanism belongs inside infrastructure, intent belongs at call sites. Moving the mechanism inside `Value.apply` is the correct refactor.

However, the Sendable constraint introduces a complication. In Reference mode, `Out: Sendable` is required for `make`. In Unchecked mode, it's not. The `apply` method would need mode-specific overloads or a way to dispatch:

```swift
// Reference mode:
extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    @usableFromInline
    func apply<In, Out: Sendable>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(unsafeTake(In.self)))
    }
}

// Unchecked mode:
extension Machine.Value where Mode == Machine.Capture.Mode.Unchecked {
    @usableFromInline
    func apply<In, Out>(_ transform: (In) -> Out) -> Machine.Value<Mode> {
        .make(transform(unsafeTake(In.self)))
    }
}
```

This is clean. `unsafeTake` moves from the carrier call site into `Value.apply`, which is infrastructure.

**Operation 2 — `combine`** (covers Pattern B, 2 sites):
```swift
// Reference mode:
extension Machine.Value where Mode == Machine.Capture.Mode.Reference {
    @usableFromInline
    func combine<A, B, Out: Sendable>(
        _ other: Machine.Value<Mode>,
        using combineFn: (A, B) -> Out
    ) -> Machine.Value<Mode> {
        .make(combineFn(unsafeTake(A.self), other.unsafeTake(B.self)))
    }
}
```

**Operation 3 — `mapElements`** (covers Pattern C, 2 sites):
```swift
// Reference mode:
extension [Machine.Value<Machine.Capture.Mode.Reference>] {
    @usableFromInline
    func mapElements<T: Sendable>(_: T.Type) -> [T] {
        map { $0.unsafeTake(T.self) }
    }
}
```

Actually, Pattern C is used inside a `Finalize.Array` convenience init that stores a closure:
```swift
let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { values in
    values.map { $0.unsafeTake(T.self) }
}
```

This closure is stored in captures and called later. A helper on `[Value]` would clean this up:
```swift
let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { $0.take(T.self) }
```

Where `take` on `[Value]` extracts each element. But this name conflicts with the existing `take` on `Value` itself. Better:
```swift
let finalizeFn: @Sendable ([Machine.Value<Mode>]) -> [T] = { $0.extract(T.self) }
```

### Part 5: Carrier Call Sites After Refactor

**Transform.Erased — before**:
```swift
self._apply = { captures, value in
    captures.withRaw(raw, as: (@Sendable (In) -> Out).self) { transform in
        let input = value.unsafeTake(In.self)
        return Machine.Value<Mode>.make(transform(input))
    }
}
```

**Transform.Erased — after**:
```swift
self._apply = { captures, value in
    captures.withRaw(raw, as: (@Sendable (In) -> Out).self) { transform in
        value.apply(transform)
    }
}
```

**Combine.Erased — before**:
```swift
self._combine = { captures, a, b in
    captures.withRaw(raw, as: (@Sendable (A, B) -> Out).self) { combineFn in
        let aVal = a.unsafeTake(A.self)
        let bVal = b.unsafeTake(B.self)
        return Machine.Value<Mode>.make(combineFn(aVal, bVal))
    }
}
```

**Combine.Erased — after**:
```swift
self._combine = { captures, a, b in
    captures.withRaw(raw, as: (@Sendable (A, B) -> Out).self) { combineFn in
        a.combine(b, using: combineFn)
    }
}
```

**Transform.Throwing — before**:
```swift
self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
    let slot = captures.slots[raw.rawValue]
    let transform = slot.read((@Sendable (In) throws(Failure) -> Out).self)
    let input = value.unsafeTake(In.self)
    return Machine.Value<Mode>.make(try transform(input))
}
```

**Transform.Throwing — after**:
```swift
self._apply = { captures, value throws(Failure) -> Machine.Value<Mode> in
    let slot = captures.slots[raw.rawValue]
    let transform = slot.read((@Sendable (In) throws(Failure) -> Out).self)
    try value.applyThrowing(transform)
}
```

This requires a throwing variant of `apply`. The nested typed throws compiler crash (documented as WORKAROUND per [PATTERN-016]) means `withRawThrowing` cannot be used, so the slot access remains direct. But the `unsafeTake` + `make` can still be moved into `applyThrowing`.

### Part 6: Access Control

`unsafeTake` is currently `public`. Its consumers:

| Consumer | Package | Access needed |
|----------|---------|---------------|
| Carrier closures (10 sites) | machine-primitives | `@usableFromInline` (inside `@inlinable` inits) |
| Test (1 site) | machine-primitives tests | Test can use `take` instead |
| **External consumers** | **none** | — |

Parser-machine-primitives never calls `unsafeTake`. No external package uses it. The only public extraction API needed is `take` (Optional).

After adding `apply`, `combine`, and `applyThrowing`:
- `unsafeTake` becomes `@usableFromInline` internal — used only inside the new `apply`/`combine`/`applyThrowing` methods
- `take` remains `public` — the safe Optional extraction for external consumers
- The new operations are `@usableFromInline` — they serve carrier construction, not external API

### Part 7: Naming

The name `unsafeTake` is misleading on two counts:

1. **Not `unsafe` in Swift's sense.** Swift's `unsafe` keyword marks operations with undefined behavior. `unsafeTake` has a precondition — it traps deterministically on type mismatch. There is no undefined behavior.

2. **Not a "take" (consuming).** The value is read via `.pointee` on a pointer — the original storage remains. The `_Storage` class is reference-counted; reading `.pointee` copies the value. A true "take" would invalidate the source.

If `unsafeTake` remains (as internal infrastructure), it should be renamed to reflect what it does: precondition-checked projection. Options:

| Name | Reads as |
|------|----------|
| `project<T>(_:)` | "Project to type T" — matches `_project` |
| `require<T>(_:)` | "Require this value to be T" |
| `expect<T>(_:)` | "Expect this value to be T" |
| `read<T>(_:)` | "Read as T" — matches `Capture.Slot.read` |

`read` aligns with `Capture.Slot.read(_:)` which performs the identical operation (ObjectIdentifier check + pointer projection). Both are precondition-checked type-aware reads from opaque storage. Using the same name creates consistency across the two type-erased containers.

However, if `unsafeTake` moves internal and is only called from `apply`/`combine`/`applyThrowing`, the rename is less critical — the name never appears at carrier call sites anymore.

---

## Outcome

**Status**: RECOMMENDATION

### Recommended Changes (Prioritized)

| Priority | Change | Effect |
|----------|--------|--------|
| 1 | Add `apply<In, Out>(_:) -> Value` | Eliminates Pattern A mechanism at 6 carrier sites |
| 2 | Add `combine<A, B, Out>(_:using:) -> Value` | Eliminates Pattern B mechanism at 2 carrier sites |
| 3 | Add `applyThrowing<In, Out, E>(_:) throws(E) -> Value` | Eliminates mechanism at 2 Transform.Throwing sites |
| 4 | Make `unsafeTake` `@usableFromInline` internal | Removes mechanism from public API |
| 5 | Rename `unsafeTake` → `read` | Aligns with `Capture.Slot.read` naming |

Each operation requires mode-specific overloads (Reference: `Out: Sendable`, Unchecked: no constraint). This is the same pattern already used by `make`.

### What Does Not Change

- `take<T>(_:) -> T?` remains the sole public extraction API
- `Machine.Value` remains a hand-rolled type erasure (Embedded-safe `Any`)
- `_Storage`, `_Table`, `_project` internal structure unchanged
- Carrier public API unchanged (`apply`/`combine`/`next`/`finalize` methods)

### Implementation Notes

The `applyThrowing` method may encounter the same nested typed throws compiler crash documented in `Machine.Transform.Throwing.swift`. If so, the WORKAROUND approach (direct implementation without delegating through `withRawThrowing`) applies here too — the method body can use `unsafeTake` + `make` directly since it IS the infrastructure.

The `Finalize.Array` convenience inits (Pattern C) are a special case: the `unsafeTake` appears inside a stored closure, not at the init call site. Options:
- Add a `Value` array extension (e.g., `extractAll<T>(_:) -> [T]`)
- Leave as-is (the closure IS the infrastructure; `unsafeTake` inside it is acceptable)

The second option is acceptable per [IMPL-INTENT] — the finalize closure is infrastructure that composes the array extraction. The `unsafeTake` inside it is at the same level as `unsafeTake` inside `apply`.

## References

- [IMPL-INTENT] — Code reads as intent, not mechanism
- [IMPL-EXPR-001] — Prefer single expressions over separate declarations
- [IMPL-000] — Call-site-first design
- [PATTERN-016] — Conscious technical debt (Transform.Throwing compiler crash)
- [PATTERN-017] — rawValue and property access location (analogous: mechanism confinement)
- `Machine.Capture.Slot.read(_:)` — Identical pattern (ObjectIdentifier check + pointer projection)
- `implementation-quality-audit-graph-machine-parser.md` — M-1 finding (Transform.Throwing workaround)
