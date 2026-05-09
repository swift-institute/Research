# @frozen on ~Copyable Types — The Deferred-Deinit Trade-off

<!--
---
version: 1.0.0
last_updated: 2026-05-09
status: DECISION
tier: 2
scope: cross-package
applies_to: [swift-pair-primitives, swift-either-primitives, swift-product-primitives]
trigger: forums-review of swift-pair-primitives flagged "@frozen on a ~Copyable struct precludes ever adding a deinit" (forums-review-objections-2026-05-09.md, ownership angle, score 40.62). The forums-review-simulation predicted reviewer pushback on the implicit lifecycle ambiguity of `Pair(readDescriptor, writeDescriptor)`. This note formalises the cohort's accepted disposition.
toolchains_verified:
  - Swift 6.3.1 (Xcode 26.4 default)
  - Swift 6.4-dev nightly snapshot 2026-05-07-a
preceded_by:
  - escapable-support-pair-either-product.md (DECISION, 2026-05-09) — the cohort's ~Escapable disposition; this note is its lifecycle-axis sibling
relates_to:
  - swift-pair-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md (item 3)
  - swift-either-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md
---
-->

## Context

`Pair` (struct) and `Either` (enum) in the cohort declare `@frozen`. Both are
declared `~Copyable, ~Escapable`. The combination is load-bearing for two
forward-compatibility properties, but it also forecloses one future evolution
path — adding a custom `deinit` — and the foreclosure deserves an explicit
disposition rather than emerging silently from the type declarations.

```
swift-pair-primitives/Sources/Pair Primitives/Pair.swift:27
    @frozen
    public struct Pair<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>:
        ~Copyable, ~Escapable { ... }

swift-either-primitives/Sources/Either Primitives/Either.swift:77
    @frozen
    public enum Either<Left: ~Copyable & ~Escapable, Right: ~Copyable & ~Escapable>:
        ~Copyable, ~Escapable { ... }

swift-product-primitives/Sources/Product Primitives/Product.swift  — NOT @frozen
```

The forums-review simulation of `swift-pair-primitives`
(`forums-review-objections-2026-05-09.md`, item 3, ownership angle,
score 40.62) flagged this in the form a reviewer is most likely to use:

> "`@frozen` on a `~Copyable` struct (`Pair.swift:27`) precludes ever adding a
> `deinit` — a `Pair(readDescriptor, writeDescriptor)` is a movement vehicle,
> not a join-deinit owner. The README's descriptor example reads as 'this
> manages descriptor lifetime' when it doesn't."

The cohort already accepts the trade-off implicitly by shipping `@frozen`. The
purpose of this note is to (a) record the trade-off explicitly so future
sessions don't try to rescind `@frozen` without remembering why, and (b) name
the lifecycle-framing clarification that DocC and README updates per Item C of
the 2026-05-09 punch list should reflect.

## Question

For `~Copyable` types `Pair` and `Either`, is the `@frozen` layout commitment
the correct trade-off given that it forecloses the addition of a custom
`deinit` in any post-1.0 minor version? What lifecycle framing does the
cohort's API surface require?

## Analysis

### What `@frozen` commits

`@frozen` (SE-0260) commits a type's layout and case set across library
boundaries. For a struct, the field set, field order, and field types become
part of the ABI; for an enum, the case set becomes ABI. After `@frozen` ships
in a tagged release with library evolution enabled, those properties are
fixed — adding fields, reordering fields, or adding cases is a breaking
change. Removing `@frozen` is itself an ABI break.

For pre-1.0 packages without library evolution, `@frozen` has no ABI effect at
the package boundary; it is, however, a *semantic* commitment that the type's
shape is intentional and that consumers may rely on the shape for layout
optimisations (e.g., `MemoryLayout.size`, raw-buffer decoding, FFI). Removing
`@frozen` later, even pre-1.0, signals that the layout was never meant to be
load-bearing.

### What `deinit` does on a `~Copyable` type

`~Copyable` types in Swift can declare a custom `deinit` (the *destructive*
finalizer) that runs when the type is destroyed at end-of-scope, end-of-function,
or via a `consume` operator. `deinit` is the *only* general mechanism by which
a `~Copyable` type can attach behavior to its destruction:

- file-descriptor close on drop
- mutex unlock on drop
- arena-region tear-down on drop
- transactional rollback on drop

This is the join-deinit pattern: the type *owns* a resource, and dropping the
type *closes* the resource. It is the structural difference between a
*movement vehicle* (a value that just transports data) and a *resource owner*
(a value whose lifetime IS the resource's lifetime).

### The combination: `@frozen` + `~Copyable` + no current `deinit`

The Swift language permits `deinit` on `@frozen ~Copyable` types as a forward
addition only if the deinit is part of the initial `@frozen` declaration.
Adding a `deinit` to a `@frozen` type that did not previously have one is an
ABI break under library evolution: the destruction sequence at consumer call
sites changes (a no-op drop becomes a non-trivial drop). This applies whether
the type is a struct or an enum.

So the cohort's current state — `@frozen` + `~Copyable` + no `deinit` —
permanently fixes the cohort as *movement vehicles*. The cohort cannot become
*resource owners* under any future minor version without rescinding `@frozen`,
which is itself an ABI break.

### Why the trade-off is accepted

`Pair` and `Either` are functor-shaped data containers. Their semantic role is
*structural* — pairing two values, alternating between two values — not
*lifecycle-managing*. The accepted trade-off rests on three observations:

1. **Layout stability is a feature.** Consumers who need to round-trip
   `Pair<UInt8, UInt8>` through a 2-byte buffer, or who need
   `Either<some_layout, some_layout>` to expose a discriminator at a known
   offset, benefit from the `@frozen` commitment. The cohort's primitive role
   makes layout optimisation a real consumer concern.

2. **Resource-bearing types belong in different packages.** A
   `Pair(readDescriptor, writeDescriptor)` that closes its descriptors on
   drop is a different concept than `Pair`. The institute already has join-
   deinit-bearing primitives in `swift-file-system`, `swift-process`, and
   similar packages (where `~Copyable` + `deinit` is the active pattern, and
   `@frozen` is correspondingly absent). Conflating "two values held
   together" with "two resources held together" is a category error; the
   right resolution is to keep `Pair` as a data container and let resource-
   owning containers live in resource-owning packages.

3. **The `apply` / `consume` paths give consumers explicit lifecycle.** The
   cohort's `Pair.apply(_:)` and `Either.swap(_:)` consume their argument and
   produce a derived value. Consumers who need lifecycle behavior on the
   contained values invoke `apply` with a closure that closes them; the
   cohort's API does not pretend to manage the lifecycle for them.

### The asymmetry: Product is not `@frozen`

`Product<each Element>` (parameter pack) does NOT carry `@frozen`. This is not
an oversight — parameter-pack types do not yet have a stable layout commitment
under the language; `@frozen` on a parameter-pack type would be premature.
Product's role in the cohort is the same (movement vehicle, not resource
owner), but its layout commitment is currently stronger than its language-level
support, so the annotation is deferred.

When parameter-pack `~Copyable` lands in Swift (which is ~Escapable's
gating-blocker per `escapable-support-pair-either-product.md` §`Product:
blocked by parameter-pack ~Copyable limitation`), Product's `@frozen`
disposition will need a separate decision. For now: not @frozen, deferred.

### Lifecycle implications for consumer documentation

The reviewer's framing — "the README's descriptor example reads as 'this
manages descriptor lifetime' when it doesn't" — is the load-bearing
correction. Consumers reach for `Pair` when they have two values to hold
together; some of those consumers will be holding resources. The DocC
discoverability surface needs to make explicit:

| Cohort framing | Promise to consumers |
|---|---|
| Movement vehicle | "I will transport these two values together; I do nothing to them on drop." |
| (NOT) Resource owner | "I will NOT close, unlock, or otherwise tear down the values on drop. You are responsible for `apply` or explicit close." |

A `Pair(readDescriptor, writeDescriptor)` example in the README that does
NOT make this explicit is a misleading example, exactly per the forums-review
flag.

## Outcome

**Status**: DECISION

**The trade-off is accepted.** `Pair` and `Either` ship `@frozen` and
permanently are movement vehicles, not resource owners. The cohort's API does
not commit to ever growing a custom `deinit`.

**Documentation actions (for Item C of the 2026-05-09 punch list)**:

1. `Pair Primitives.docc/Pair Primitives.md` and the package README MUST
   include a "Lifecycle: movement, not management" section stating the cohort
   does NOT close, unlock, or otherwise act on its contained values on drop.

2. The descriptor example in the Pair README MUST be reframed (or replaced
   with a non-resource example) so the lifecycle ambiguity does not arise.

3. `Either Primitives.docc/Either Primitives.md` MUST carry an analogous
   note. Either's case-discriminator framing makes the resource confusion
   less common, but the underlying reality is the same.

4. Product's deferral disposition (no `@frozen` while parameter-pack
   `~Copyable` is unsupported) MUST be cross-referenced; consumers expecting
   layout-stability commitments should be told the commitment is currently
   weaker for Product than for Pair / Either.

**Future direction**:

If a future Swift version makes `deinit` addition non-breaking on `@frozen`
`~Copyable` types (unlikely; it would change the destruction sequence at
every consumer), the cohort's disposition can be revisited. Until then: any
proposal to add a `deinit` to Pair / Either MUST come paired with rescinding
`@frozen`, which is itself a major-version-only change.

## References

- [SE-0260 — Library Evolution for Stable ABIs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0260-library-evolution.md) — `@frozen` semantics
- [SE-0390 — Noncopyable structs and enums](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) — `deinit` on `~Copyable` types
- `swift-pair-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md` (item 3, ownership angle, score 40.62) — origin of the flag
- `swift-either-primitives/Audits/forums-review/forums-review-objections-2026-05-09.md` — analogous Either flag
- Cohort current state:
  - `swift-pair-primitives/Sources/Pair Primitives/Pair.swift:27` — `@frozen public struct Pair`
  - `swift-either-primitives/Sources/Either Primitives/Either.swift:77` — `@frozen public enum Either`
  - `swift-product-primitives/Sources/Product Primitives/Product.swift` — no `@frozen` (deferred)
- `swift-institute/Research/escapable-support-pair-either-product.md` (DECISION, 2026-05-09) — sibling-axis decision for the same cohort
