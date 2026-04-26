# Naming: `Mutator.\`Protocol\`` namespace + `Mutable` adjective typealias

<!--
---
version: 1.0.0
last_updated: 2026-04-25
status: REFERENCE
tier: 1
scope: ecosystem-wide
relocated_from: swift-mutator-primitives/Research/naming-mutator-protocol-and-mutable-typealias.md
relocation_date: 2026-04-25
---
-->

> Reframed from DECISION to REFERENCE on 2026-04-25. The naming spine
> remains valid for any future ecosystem package occupying mutation-
> capability territory: `swift-mutator-primitives` package + `Mutator`
> namespace + `Mutable` adjective typealias. The original
> `swift-mutator-primitives` package was retired after the design-space
> investigation completed DEFERRED (see
> `swift-carrier-primitives/Research/mutability-design-space.md` v1.1.0
> §Investigation outcome).

## Context

`swift-carrier-primitives/Research/mutability-design-space.md` (DECISION,
2026-04-25) recorded option C — *"separate `swift-mutable-primitives`
package with `Mutatable` protocol"* — as the principled future shape for
ecosystem mutation dispatch. The deferred name `Mutatable` was a
strawman; the deferral document explicitly asked the eventual
implementer to *"confirm or propose alternative."*

This note resolves the naming question for the new package, which lands
the deferred direction.

## Question

Three sub-questions:

1. **Protocol name** — Is `Mutatable` the right name for the capability
   protocol, or does the ecosystem's noun/capability-protocol convention
   suggest a better shape?
2. **Package name** — Does the package name match the protocol name, the
   namespace, or some other axis?
3. **Library/target name** — How does the SwiftPM target spell follow
   from the answers above?

## Analysis

### Convention sources

- **[PKG-NAME-001]** — Package names and the top-level Swift namespace
  declared by a package MUST use the noun form. Gerund forms are
  forbidden.
- **[PKG-NAME-002]** — The canonical capability protocol of a namespace
  MUST be declared as `Namespace.\`Protocol\``; a top-level typealias
  MUST export the gerund (or, equivalently, the natural English
  conformance reading) so conformance sites read as English.
- **[PKG-NAME-005]** — When multiple noun forms of a domain are available,
  the SHORTEST natural noun wins.

### The strawman: top-level `Mutatable`

The mutability-design-space.md strawman was a top-level protocol named
`Mutatable`, parallel to the parent's top-level `Carrier` protocol.

**Three problems with the strawman**:

1. **`Mutatable` is etymologically improper formation.** The `-able`
   suffix attaches to a verb stem to form an adjective; the verb is
   `mutate`; the proper `-able` adjective is therefore `mutable`, not
   `mutatable`. *Mutatable* is a double-suffix neologism — the implicit
   `mutate + able` reading is already covered by the existing English
   `mutable`. Stdlib's `MutableCollection`, `MutableSpan`, and
   `MutableRawSpan` all use `Mutable`, never `Mutatable`. Adopting
   `Mutatable` would put the package out of step with stdlib's
   adjective-forming convention without a compensating gain.

2. **A top-level protocol misses the namespace pattern.** The parent's
   top-level `Carrier` was a deliberate compromise: forcing `Carrier`
   into a `Carrier.\`Protocol\`` shape would have created an empty
   namespace shell, since Carrier had no concrete value type or
   sibling helpers to host. The new package starts fresh and CAN host
   a real noun namespace from day one — `Mutator` is a genuine agent
   noun (one that mutates / a site of mutation), with room for future
   helpers (`Mutator.Witness`, `Mutator.Identity`, etc.). The
   asymmetry argument from mutability-design-space.md applied
   specifically to *forcing* a namespace shell on Carrier; it does not
   argue against a fresh package starting with one.

3. **`Mutatable` reads less naturally at conformance sites than
   `Mutable`.** `extension Foo: Mutable {}` reads as plain English;
   `extension Foo: Mutatable {}` reads as a slightly clunky
   neologism. Stdlib's adjective-protocol convention (`Hashable`,
   `Equatable`, `Comparable`, `Sendable`) anchors the natural reading
   on the `Verb-able` adjective form.

### The proposal: `Mutator.\`Protocol\`` + `Mutable` typealias

This package adopts the [PKG-NAME-002] convention:

```swift
// 1. The noun namespace.
public enum Mutator {
    // 2. The canonical capability protocol, nested.
    public protocol `Protocol`<Value>: ~Copyable, ~Escapable {
        associatedtype Value: ~Copyable & ~Escapable

        var value: Value {
            @_lifetime(borrow self)
            borrowing get
            set
        }
    }
}

// 3. The top-level adjective typealias for natural conformance reading.
public typealias Mutable = Mutator.`Protocol`
```

Three names exist for the same concept:

| Name | Use | Reads as |
|------|-----|----------|
| `Mutator.\`Protocol\`` | Library-internal, namespace-anchored | "the canonical capability protocol of the Mutator namespace" |
| `Mutable` | Conformance sites, generic constraints | "Foo is Mutable" / "process anything Mutable" |
| (parameterized) `some Mutator.\`Protocol\`<Int>` or `some Mutable<Int>` | API site type-bounds | Either spelling |

Both `Mutable` and `Mutator.\`Protocol\`` resolve to the same hoisted
declaration; the typealias is purely cosmetic.

### Why `Mutator` (not `Mutation`, `Mutate`, `Mutand`, `Mutability`)

Five candidate noun-domain names:

| Name | Form | Verdict |
|------|------|---------|
| `Mutator` | Agent noun ("one who mutates") | **Chosen** — short, English-natural, parallels Cardinal/Ordinal/Carrier (each an agent or domain noun); leaves room for future helpers in the namespace |
| `Mutation` | Result noun ("the act/result of mutating") | Defensible but reads as event-domain (a mutation) rather than capability-domain (a mutator). Generic algorithms `func f<T: Mutation.\`Protocol\`>` read as "T is a Mutation" — semantically off |
| `Mutate` | Verb (not a noun) | Forbidden by [PKG-NAME-001] noun rule |
| `Mutand` | Latin neologism ("that which is mutated") | Pedantically accurate but unrecognizable in code review |
| `Mutability` | Abstract noun ("the state of being mutable") | Reads as a property-of-a-type, not a domain. `Mutability.\`Protocol\`` is awkward |

[PKG-NAME-005]'s shortest-natural-noun rule confirms `Mutator` (7 letters)
over `Mutation` (8 letters) and `Mutability` (10 letters); both `Mutator`
and `Mutation` are first-class English nouns, but `Mutator` parallels the
ecosystem's other agent-noun namespaces (Carrier, Encoder, Iterator) more
cleanly than `Mutation`.

### No clash with `Ownership.Mutable`

`swift-ownership-primitives` ships a concrete heap-allocated wrapper
type at path `Ownership.Mutable<Value>` (a noun, used as a type to box
values for shared mutable state). The proposed top-level `Mutable`
typealias for this package lives in module scope (Mutator_Primitives),
not under `Ownership`. Module-qualified, the two are unambiguous:

```swift
import Ownership_Primitives    // Ownership.Mutable<T> (the box type)
import Mutator_Primitives      // Mutable (the typealias for the protocol)

let box: Ownership.Mutable<Int> = .init(42)
extension Foo: Mutable {}
```

Module scope is the Swift-defined boundary that resolves the cosmetic
overlap. Consumers importing both modules use the qualified form for
the box and the unqualified form for the protocol; neither name shadows
the other in the source language.

### Package name

`swift-mutator-primitives`. Package name follows the namespace
([PKG-NAME-001]), in the noun form, with the `-primitives` suffix
([PRIM-NAME-001]).

### Library / target name

`Mutator Primitives` (with space, per the ecosystem's library-naming
convention; the import statement uses the underscore form,
`Mutator_Primitives`). Sub-targets follow the parent:

| Target | Purpose |
|--------|---------|
| `Mutator Primitives` | Protocol declaration + four-quadrant defaults |
| `Mutator Primitives Standard Library Integration` | Stdlib type conformances (e.g., `MutableSpan`) |
| `Mutator Primitives Test Support` | Shared fixtures for tests |
| `Mutator Primitives Tests` | Test target for the main module |
| `Mutator Primitives Standard Library Integration Tests` | Test target for SLI conformances |

## Outcome

**Status**: DECISION — `Mutator.\`Protocol\`` is the canonical
capability protocol; `Mutable` is the top-level adjective typealias;
`swift-mutator-primitives` is the package name; `Mutator Primitives` is
the library / main-target name.

**Rationale**:

1. **Etymological correctness**: `Mutable` is the proper `-able`
   adjective of `mutate`; `Mutatable` is double-suffixed neologism and
   out of step with stdlib's `MutableCollection`/`MutableSpan` precedent.
2. **Convention alignment**: `Mutator.\`Protocol\`` + adjective
   typealias is exactly the [PKG-NAME-002] pattern. Carrier did not
   adopt it (empty-shell argument); the new package starts fresh and
   does.
3. **Three usable names**: `Mutator.\`Protocol\``,
   `Mutator.\`Protocol\`<Value>`, and `Mutable` all resolve to the
   same protocol; consumers pick the spelling that reads best at each
   call site.
4. **No clash with `Ownership.Mutable`**: different module scopes;
   Swift's import system disambiguates without ceremony.

**Revisit triggers**: None active. The naming convention is foundational
and unlikely to drift; future ecosystem additions in the namespace
(witness types, helper protocols) extend the `Mutator.*` surface
without disturbing the typealias.

## References

### Primary sources

- `swift-carrier-primitives/Research/mutability-design-space.md` —
  DECISION 2026-04-25 recording option C and the deferred package
  shape.
- `Sources/Mutator Primitives/Mutator.swift` — the namespace + nested
  protocol declaration.
- `Sources/Mutator Primitives/Mutable.swift` — the top-level adjective
  typealias.

### Convention sources

- **[PKG-NAME-001]** — noun rule for packages and namespaces.
- **[PKG-NAME-002]** — canonical capability protocol = `Namespace.\`Protocol\``;
  gerund/adjective typealias.
- **[PKG-NAME-005]** — shortest natural noun rule.
- **[PRIM-NAME-001]** — `-primitives` suffix on Layer 1 packages.

### Ecosystem instances

- `Cardinal.\`Protocol\`` (swift-cardinal-primitives) — agent-noun
  namespace + protocol pattern.
- `Ordinal.\`Protocol\`` (swift-ordinal-primitives) — agent-noun
  namespace + protocol pattern.
- `Hash.\`Protocol\`` (swift-hash-primitives) — agent-noun namespace.
- `Carrier` (swift-carrier-primitives) — top-level capability protocol;
  the deliberate exception to [PKG-NAME-002] driven by the empty-shell
  argument.

### Stdlib precedent

- `MutableCollection`, `MutableSpan`, `MutableRawSpan` — adjective
  naming for mutation-capability protocols/types in stdlib.
- `Hashable`, `Equatable`, `Comparable`, `Sendable` — `Verb-able`
  adjective protocol naming.
