# Variant Decomposition Rationale

<!--
---
version: 1.0.0
last_updated: 2026-04-20
status: DECISION
---
-->

**Coen ten Thije Boonkkamp**
Swift Institute
April 2026

---

## Abstract

This note documents the design decision that shaped the 2026-04-20 first-public-release
shape of `swift-property-primitives`: the package ships five SwiftPM targets — four
variants plus an umbrella — rather than a single monolithic target. The axis of
decomposition is the ownership / access-model of each variant's type family. This note
records the split criteria, the inter-variant dependency graph, the deliberately
unusual `View.Read → View` structural dependency, and the rationale for keeping Core
as an internal (unpublished) target.

The motivation is not modularization for its own sake. The package's type family has
distinct ownership characters — owned vs borrowed-via-pointer, mutable vs read-only,
state-tracked vs stateless — and those characters correspond to different consumer
needs. Decomposition makes those characters load-bearing at the dependency graph
level: a consumer that only reads from `~Copyable` containers depends on `Property
View Read Primitives` alone and pays no compile cost for the mutable or state-tracked
paths.

---

## 1. Package Shape

| Target | Contents | Library product | Depends on |
|--------|----------|-----------------|------------|
| `Property Primitives Core` | `Property` — the owned `~Copyable`-preserving base type | — (internal) | none |
| `Property Typed Primitives` | `Property.Typed<Element>` — owned variant carrying `Element` for property-case extensions | Yes | Core |
| `Property Consuming Primitives` | `Property.Consuming`, `Property.Consuming.State` — state-tracked, Copyable-constrained | Yes | Core |
| `Property View Primitives` | `Property.View`, `.Typed`, `.Typed.Valued`, `.Typed.Valued.Valued` — mutable-pointer view family | Yes | Core |
| `Property View Read Primitives` | `Property.View.Read`, `.Typed`, `.Typed.Valued` — read-only-pointer view family | Yes | Core + View |
| `Property Primitives` | Umbrella — `@_exported public import` of all five variants | Yes | all five |

The dependency graph has maximum depth 3 (Core → View → View Read → Umbrella),
right at the `[MOD-007]` ceiling. The depth is justified by the structural namespace
nesting of `View.Read` inside `View` — see Section 3.

---

## 2. Axis of Decomposition: Ownership / Access Model

Each variant answers a different question about how a caller reaches the base value:

- **Core (`Property`)** — owned, method-case. The caller transfers a base value into
  the property via `init(_ base: consuming Base)`, mutates it through coroutine
  accessors (`_read` / `_modify`), and receives it back on scope exit via `defer`. The
  shape fits CoW-safe containers whose extensions are methods with their own generic
  parameters (`func back<E>(...)`) — no `Element` in scope is needed.

- **Typed (`Property.Typed<Element>`)** — owned, property-case. Same ownership model as
  Core's `Property`, but with an additional `Element` generic parameter so that `var`
  extensions can bind `Element` in their where-clauses. Swift methods can introduce
  their own generics; properties cannot. `Typed` closes that gap. Consumers that only
  need method-case accessors can depend on Core and skip Typed.

- **Consuming (`Property.Consuming`)** — state-tracked. The caller transfers a base
  into a `Property.Consuming`, and the _modify accessor's `defer` block consults a
  reference-type `State` to decide whether to restore. The borrow path and the
  consume path share a single accessor; the caller picks via which method they
  invoke (`container.forEach { }` vs `container.forEach.consuming { }`). Requires
  `Base: Copyable` because the State class must be able to restore the base value
  conditionally.

- **View (`Property.View` family)** — borrowed via mutable pointer. The caller
  yields the view from a `mutating _read` / `mutating _modify`; the view wraps an
  `UnsafeMutablePointer<Base>`. Extensions read through the pointer (`func`) or
  mutate/consume through it (`mutating func`). This is the only shape that supports
  `~Copyable` base types — ownership transfer is impossible through a borrowing
  property accessor, so pointer indirection becomes the only path.

- **View Read (`Property.View.Read` family)** — borrowed via read-only pointer. Same
  indirection model as View but with `UnsafePointer<Base>` and no mutation surface.
  The borrowing-init overload works from *non-mutating* `_read` accessors, enabling
  `let` bindings on `~Copyable` containers — a capability View cannot offer because
  `&self` is mandatory for `UnsafeMutablePointer` construction.

The four characters are not interchangeable. A consumer that needs mutation through
a pointer cannot use View Read; a consumer on `~Copyable` base cannot use Core. The
`[MOD-003]` split test — *does each variant have an independent consumer use case?* —
is satisfied cleanly: downstream consumers in the `swift-primitives` superrepo
partition along exactly these lines. `swift-storage-primitives` consumes only
`Property View Primitives`; `swift-memory-primitives`, `swift-dictionary-primitives`,
and `swift-list-primitives` consume only `Property View Read Primitives`.

---

## 3. The View.Read → View Structural Dependency

The most unusual edge in the dependency graph is `Property View Read Primitives →
Property View Primitives`. This is the one place where a variant target depends on
another variant target rather than only on Core.

The dependency is structural, not delegation. `Property.View.Read` is declared via
`extension Property.View` in the View Read target:

```swift
// In Property View Read Primitives:
public import Property_Primitives_Core
public import Property_View_Primitives

extension Property.View where Base: ~Copyable {
    @safe
    public struct Read: ~Copyable, ~Escapable { … }
}
```

The type is `Property<Tag, Base>.View.Read` — nested inside `View`'s namespace. To
declare a nested type via extension, the extending module must import the namespace
owner's module. View Read therefore imports View, but it never *calls* into View —
the dependency exists to reach the namespace anchor.

This is distinct from a delegation dependency, where target A calls into target B's
functions. Delegation-style inter-variant dependencies would fail the `[MOD-003]`
independent-value test and should have been folded into a single target. The
namespace-anchor dependency does not: `Property.View.Read` is semantically a peer of
`Property.View`, sharing the same top-level type (`Property`) and the same access
pattern (pointer indirection on `~Copyable` base), but differing in mutation
capability. Nesting the read-only variant inside the mutable variant's namespace
communicates that peerhood at every call site.

The alternative shapes considered:

1. **Flatten `Read` to `Property.Read` at top level** — rejected. Loses the
   semantic connection to `View` (Read is a variant OF View, not a peer of Property
   itself). Creates a naming collision risk with future top-level peers.
2. **Merge `View` and `View.Read` into one target** — rejected. Independent consumer
   value is real: read-only consumers have no need for `UnsafeMutablePointer`'s
   mutation surface, and the `~Escapable` / lifetime-attribute surface differs
   enough that combining them would muddle the mental model.
3. **Accept the structural dependency** — chosen. The `[MOD-007]` depth ceiling
   accommodates it; the namespace semantic is preserved; downstream consumers that
   depend on View Read transitively resolve View without direct action.

The decision is documented inline in the `.docc` catalogue's Rationale sections and
in `Audits/audit.md` Modularization finding 3.

---

## 4. Core Is Internal

`Property Primitives Core` carries exactly two types — `Property` and `Property.Typed`
— that every variant depends on but no consumer should import directly. Per
`[MOD-001]` Core does NOT have a library product.

The rationale is alignment of import choice with API choice. A consumer that imports
Core alone gets the owned types but no view types, no consuming types, and none of the
`.Valued` value-generic machinery. That's a degenerate state — the consumer probably
meant to import either the umbrella (`Property Primitives`) or a specific variant.
Forcing the choice at import time avoids accidentally partial imports that compile
but don't reach the right API surface.

The two Core types are still reachable via the umbrella or via any variant product:
the umbrella `@_exported public import`s all four variants, and each variant
`@_exported public import`s Core. Core's types are therefore universally reachable
but never directly importable as a product.

---

## 5. Consumer Import Choice

Per `[PRP-007]`, the umbrella (`Property_Primitives`) is the default consumer import.
It chains all four variants and makes the full type family available.

The narrow-import variants exist for consumers that want to minimize compile-time
boundaries — a read-only consumer can depend on `Property_View_Read_Primitives` alone
and skip building the mutable View target. Per `[MOD-015]` this is classified as
*primary decomposition*: the variants are independently useful along a clear
ownership-model axis, so narrow imports are a valid optimization.

Downstream migration to narrow imports is explicitly deferred — no current consumer
depends on it for correctness, and umbrella imports remain supported indefinitely.
Future packages introduced to the primitives ecosystem may adopt narrow imports from
day one.

---

## 6. Status

**Status**: DECISION. Applied 2026-04-20 as part of the first public release
polish. The shape is locked per the `/modularization` pass that produced this
decomposition; reshaping requires a fresh `/modularization` analysis plus user
approval before action (see Supervisor Ground Rule #1 in the release handoff).

---

## References

- `[MOD-001]` Internal-only Core target.
- `[MOD-003]` Variant-decomposition split criteria.
- `[MOD-006]` Dependency minimization.
- `[MOD-007]` Maximum dependency depth.
- `[MOD-015]` Consumer import precision.
- `[PRP-002]`, `[PRP-003]`, `[PRP-004]`, `[PRP-007]` — the corresponding requirements in `Skills/SKILL.md`.
- `Audits/audit.md` — Modularization section (3 findings, all RESOLVED 2026-04-20).
- [`property-type-family.md`](property-type-family.md) — the foundational paper; its Appendix A preamble points forward here.
