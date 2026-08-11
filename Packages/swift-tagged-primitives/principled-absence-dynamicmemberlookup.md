# Principled Absence — `@dynamicMemberLookup`

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: DECISION
tier: 1
---
-->

## Context

`pointfreeco/swift-tagged` annotates `Tagged` with `@dynamicMemberLookup` and provides:

```swift
@dynamicMemberLookup
public struct Tagged<Tag, Underlying> {
    public var underlying: Underlying
    public subscript<U>(dynamicMember keyPath: KeyPath<Underlying, U>) -> U {
        underlying[keyPath: keyPath]
    }
}
```

This makes `tagged.someProperty` compile and resolve to `tagged.underlying.someProperty` for any KeyPath member of `Underlying`. The wrapper becomes transparent to property access.

Swift Institute's `swift-tagged-primitives` deliberately omits this attribute. Unlike the other absences in this catalog, `@dynamicMemberLookup` is not a protocol — it's a Swift attribute that *changes member-lookup semantics on the type*. The argument is **type-boundary erosion**:

A `Tagged<User, User>` where `User` has a `name` property would let consumers write `tagged.name`. The wrapper boundary becomes invisible at the call site — there's no syntactic marker that the consumer crossed from "manipulating the wrapper" to "accessing the wrapped value." For a wrapper whose entire purpose is to *enforce* the type boundary, attribute-driven transparency is anti-purpose.

**Trigger**: Per-protocol absence work directed by user 2026-04-30. Per [RES-001].

**Scope**: Package-specific (swift-tagged-primitives). Per [RES-002a].

## Question

Should `Tagged<Tag, Underlying>` carry `@dynamicMemberLookup`? If absent, what is the consumer pattern for accessing `Underlying` members?

## Prior art

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §2 (Dynamic Member Lookup table) — original removal rationale (one paragraph).
- Swift Evolution [SE-0195](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0195-dynamic-member-lookup.md) (Introduce User-defined "Dynamic Member Lookup" Types) — the language-level proposal that introduced the attribute. Codifies the intent: dynamic-typed-bridge, not transparent-wrapper.

## Analysis

### Option A — Apply `@dynamicMemberLookup` (pointfreeco pattern)

```swift
@dynamicMemberLookup
public struct Tagged<Tag, Underlying> {
    public var underlying: Underlying
    public subscript<U>(dynamicMember keyPath: KeyPath<Underlying, U>) -> U {
        underlying[keyPath: keyPath]
    }
}
```

**Pros**:
- `tagged.name`, `tagged.age`, `tagged.address.city` etc. all work without explicit `.underlying`. Ergonomic for wrapper-as-passthrough use cases.

**Cons**:
1. **Type-boundary erosion**. The wrapper exists to mark a boundary; `@dynamicMemberLookup` makes the boundary invisible at every call site that uses dot-syntax member access. The consumer reading `tagged.name` cannot tell whether `name` is a property of Tagged or of the wrapped Underlying.
2. **Misleads about Tagged's properties**. Tagged has explicit properties (`underlying`); `@dynamicMemberLookup` adds *dynamic* members from Underlying's KeyPaths. Consumers reading Tagged's documentation see `underlying` but not `name` — yet `tagged.name` works. Documentation and surface diverge.
3. **Defeats the phantom-typing claim**. Consumers writing `tagged.id` or `tagged.name` are operating on the wrapped value's identity / fields. The phantom Tag is supposed to be the wrapper's discriminator; transparent member-access elevates the wrapped value's surface to the wrapper's, hiding the phantom Tag's role.
4. **Not what `@dynamicMemberLookup` was designed for** (per SE-0195's "Motivation" section): the attribute targets dynamic-language interop (Python, JavaScript, JSON) where member access is a runtime lookup. Using it as a transparent-wrapper-passthrough is structurally different from the language-design intent.

### Option B — Omit `@dynamicMemberLookup` + explicit `.underlying` access

```swift
let tagged: Tagged<User, User> = ...

let name = tagged.underlying.name      // explicit unwrap
let age  = tagged.underlying.age       // explicit unwrap
let city = tagged.underlying.address.city
```

**Pros**:
- Type-boundary visible at every member-access call site. Each `.underlying` marks the crossing.
- Tagged's documented properties match the actual member-access surface; no documentation/surface divergence.
- Phantom-typing claim preserved — consumers see `tagged.underlying.X` and know Tagged has the Tag, Underlying has the X.
- Aligns with the rest of the principled-absence catalog (Sequence/Collection's `.underlying.first` pattern is the same shape).

**Cons**:
- Slightly more verbose (`.underlying` per access path).
- Consumers writing wrapper-as-passthrough code feel friction; this is intentional.

## Empirical verification

[`Experiments/tagged-no-dynamicmemberlookup/`](../Experiments/tagged-no-dynamicmemberlookup/) demonstrates:

- (a) Without `@dynamicMemberLookup` on Tagged, `tagged.name` does not compile (the wrapper has no `name` property).
- (b) The explicit `tagged.underlying.name` pattern works.
- (c) A consumer-side opt-in (`@dynamicMemberLookup` extension on Tagged in a consumer's own codebase) is structurally not authorable — `@dynamicMemberLookup` must be on the type declaration, not added retroactively.

## Outcome

**[Updated post-experiment]**:

The experiment empirically verified that `@dynamicMemberLookup` cannot be added retroactively — the attribute must be on the *type declaration*, not on an extension. Therefore, **even SLI cannot opt in** to dynamic member lookup for Tagged. The absence is **structurally HARD**.

**Soft / Hard classification**: **HARD** absence — not authorable in any opt-in form.

This case differs from the protocol-absence cases: `@dynamicMemberLookup` is a type-level feature, not a protocol. Consumers who want passthrough-style ergonomics author a domain-specific wrapper struct that owns its own `@dynamicMemberLookup` annotation, forwarding to a Tagged-stored field.

The recommended consumer pattern is **explicit `.underlying` access** — preserves the type boundary and aligns with the rest of the principled-absence catalog (Sequence/Collection's explicit-unwrap pattern, etc.).

**Forward-compatibility note**: Empirical finding specific to Swift 6.3.1 attribute semantics. If a future Swift version permits retroactive `@dynamicMemberLookup` via extension, the classification SHOULD be revisited.

## References

- [`comparative-analysis-pointfree-swift-tagged.md`](./comparative-analysis-pointfree-swift-tagged.md) §2 (the seed paragraph).
- [SE-0195 — Dynamic Member Lookup](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0195-dynamic-member-lookup.md) — the attribute's design intent.
- Pointfreeco swift-tagged source — [`Tagged.swift`](https://github.com/pointfreeco/swift-tagged/blob/main/Sources/Tagged/Tagged.swift) `@dynamicMemberLookup public struct Tagged`.
