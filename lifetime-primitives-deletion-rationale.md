---
date: 2026-04-26
status: decided
decision: delete swift-lifetime-primitives from the workspace
---

# `swift-lifetime-primitives`: deletion rationale

## TL;DR

`swift-lifetime-primitives` was deleted on 2026-04-26 because all
three of its types fail the "should this primitive exist?" test:

- `Lifetime.Lease<Value>` is structurally identical to
  `Ownership.Unique<Value>` with weaker semantics (runtime trap vs
  compile-time linear enforcement).
- `Lifetime.Disposable` adds nothing beyond `consuming` methods +
  `~Copyable` deinit; the protocol is symbolic with no consumer
  needing generic-over-disposable dispatch.
- `Lifetime.Scoped<Value>` is `defer` in struct form; the language
  already provides this.

This note records the decision and the criteria applied so future
archaeology can recover the reasoning without consulting per-session
reflections.

## The three-criteria test (proposed `[MOD-RENT]`)

A primitive package's existence MUST satisfy all three criteria:

1. **Capability**: the primitive enables something the language +
   existing primitives don't already express.
2. **Consumer**: at least one real consumer in the ecosystem today.
   Not "may be useful later." Pre-emptive primitives waiting for
   hypothetical consumers don't pass.
3. **Theoretical content** (per `[MOD-DOMAIN]`): a coherent
   semantic *concept* with definition, law, spec reference, or
   structural invariant — not just code (a convenience wrapper,
   naming sugar, helper).

If a primitive fails any criterion, it shouldn't be added. If an
existing primitive fails all three, it's a candidate for deletion.

## Per-type analysis

### `Lifetime.Lease<Value>`

```swift
public struct Lease<Value: ~Copyable>: ~Copyable {
    internal var _storage: UnsafeMutablePointer<Value>
    internal var _released: Bool

    public init(_ value: consuming Value) { … }
    public mutating func release() -> Value { … }
    deinit { … }
}
```

| Criterion | Status | Reason |
|---|---|---|
| Capability | ✗ | `Ownership.Unique<Value>` provides the same shape with stronger guarantees: compile-time linear enforcement (consume-once) vs Lease's runtime `_released` flag and trap. |
| Consumer | ✗ | No production consumers found across `swift-primitives`, `swift-standards`, or `swift-foundations`. |
| Theoretical content | ✗ | "Borrowed value, must be returned" is genuinely an ownership concept, but the type is just a re-implementation of `Ownership.Unique` with a weaker contract. |

**Verdict**: redundant with `Ownership.Unique`. Migration: callers
use `Ownership.Unique`'s `consume()` instead of Lease's `release()`.

### `Lifetime.Disposable`

```swift
public protocol Disposable: ~Copyable, ~Escapable {
    consuming func dispose()
}
```

| Criterion | Status | Reason |
|---|---|---|
| Capability | ✗ | Swift's language `consuming` methods + `deinit` already provide explicit cleanup. The protocol adds *naming convention* but no new capability. |
| Consumer | ✗ | Zero conformers in the ecosystem at deletion time. The package's own `Lifetime.Scoped` had a convenience init for Disposable conformers, but no actual conformer existed. |
| Theoretical content | ~ | "Type with explicit cleanup contract" is a meaningful concept *if* generic dispatch over heterogeneous disposables is needed. None is needed today. |

**Verdict**: contentless contract waiting for a consumer that doesn't
exist. If a real generic-API consumer emerges later (e.g., a
"subscription set" type that holds many disposable handles), the
protocol can be re-introduced — domain-specific, where the consumer
lives, not as a free-standing primitive.

### `Lifetime.Scoped<Value>`

```swift
public struct Scoped<Value>: ~Copyable {
    public let value: Value
    internal let _cleanup: (Value) -> Void
    deinit { _cleanup(value) }
}
```

| Criterion | Status | Reason |
|---|---|---|
| Capability | ✗ | Equivalent to `defer { cleanup(value) }` for any local scope, or to a custom `~Copyable` struct with its own deinit when the cleanup belongs to the type. |
| Consumer | ✗ | No production consumers. |
| Theoretical content | ✗ | "Value with attached cleanup closure" is a *convenience wrapper*, not a concept. No definition, law, or spec to mirror. |

**Verdict**: defer in struct form. Language already provides this;
the wrapper is naming sugar.

## Why this isn't ownership absorption

An earlier draft of this analysis proposed *moving* Disposable +
Scoped into `swift-ownership-primitives` rather than deleting them —
on the grounds that lifetime/cleanup is conceptually distinct from
ownership/possession. That reasoning is correct on the conceptual
axis but addresses the wrong question. The primary test isn't "does
this concept fit the parent namespace?" — it's "does this primitive
earn its rent?" Disposable and Scoped fail the rent test regardless
of which namespace they'd live in. Moving them into ownership-
primitives would conflate two distinct concepts; *deleting* them
removes the rent-failure entirely.

## What survived

The session's swap audit identified four real swap candidates against
existing primitives. Three landed cleanly using `swift-ownership-primitives`:

| Hand-rolled (before) | Replaced by | Package |
|---|---|---|
| `Observation.Registrar.Extent` | `Ownership.Shared<Mutex<State>>` | `swift-ownership-primitives` |
| `Observation.Tracking._OneShot` | `Ownership.Latch<@Sendable () -> Void>` | `swift-ownership-primitives` |
| Test `Box<T>` | `LockedBox<T>` | `swift-kernel` Test Support |

The `swift-ownership-primitives` package passed the three-criteria
test in every type checked: each variant (`Shared`, `Mutable`,
`Unique`, `Indirect`, `Latch`, `Slot`, `Borrow`, `Inout`, transfer
family) corresponds to a distinct ownership shape with real consumers
and theoretical content (linearity, sharing semantics, etc.).

## Mechanical changes

**Deleted**:
- Local working tree of `swift-lifetime-primitives` (GitHub remote
  preserved; recoverable via clone if needed).

**Updated** (5 packages had commented-out lifetime deps; all stripped):
- `swift-continuation-primitives`
- `swift-handle-primitives`
- `swift-cache-primitives`
- `swift-state-primitives`
- `swift-loader-primitives`

**Workspace files**:
- `swift-primitives/Package.swift` — dep + product entries removed
- `swift-primitives/.gitmodules` — submodule entry removed
- `swift-primitives/Primitives.xctestplan` — test target entry removed
- `swift-primitives/Primitives.xcworkspace/contents.xcworkspacedata` —
  FileRef removed

**No code consumers** of `Lifetime.*` types existed in any
production source — only commented-out scaffolding deps. Deletion
caused zero source-edit churn at consumer sites.

## Future-work flag

If a real generic-cleanup consumer materializes (e.g., a
"subscription set" type that holds many disposable handles), the
Disposable protocol can be re-introduced — *domain-specific, where
the consumer lives*, not as a free-standing primitive package. The
test for re-introduction is the same three-criteria test that
caused the deletion.

## Cross-references

- Reflection: `Reflections/2026-04-26-ecosystem-audit-and-typed-tls-promotion.md`
  (full session arc including this decision)
- Skill rule (proposed): `[MOD-RENT]` codification of the three-criteria
  test in the modularization skill (action item from the session
  reflection)
- Ownership.Unique provenance: `swift-ownership-primitives/Sources/Ownership Unique Primitives/`
