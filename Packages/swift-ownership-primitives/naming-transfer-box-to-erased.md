# Naming: `Ownership.Transfer.Box` → `Ownership.Transfer.Erased`

<!--
---
version: 1.0.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

`Ownership.Transfer.Box` is the type-erased, one-shot outbound transfer slot
(for C-interop `void*` context-pointer scenarios where the consumer side
does not know the payload type `T` at the reception point). It is distinct
from `Ownership.Transfer.Cell` (typed outbound) and `Ownership.Transfer.Retained`
(AnyObject-specialised, zero-alloc outbound).

Ahead of the 0.1.0 tag, the name `Box` is under review because it is in
direct collision with the most widely-recognised use of "Box" in adjacent
systems programming languages.

## Question

Should `Ownership.Transfer.Box` be renamed before the 0.1.0 tag freezes
the API surface?

## Prior Art — What does "Box" mean elsewhere?

### Rust stdlib (the dominant reference for Swift-adjacent engineers)

`std::boxed::Box<T>` is defined as a pointer type that **uniquely owns a
heap allocation of type T**. This is the *exclusive-owner heap-cell*
contract — structurally identical to what this package names
`Ownership.Unique`, not to the type-erased transfer slot we currently
call `Transfer.Box`.

Source: [Rust std::boxed::Box](https://doc.rust-lang.org/std/boxed/struct.Box.html).
Confirmation: the Rust Book's "Using Box<T> to Point to Data on the Heap"
chapter treats `Box<T>` as the canonical single-owner heap primitive.

### C++ stdlib

`std::unique_ptr<T>` is the direct analogue of Rust's `Box<T>` —
exclusive ownership of a heap-allocated `T`. Cross-language literature
(Franklin Chen's Rust ownership vs `unique_ptr` essay, Tangram Vision's
interior-mutability comparison) consistently equates `Box` with
`unique_ptr`. Neither language associates "Box" with *type erasure* or
*one-shot transfer*.

### Swift stdlib

Swift has no type named `Box` at module scope. The closest vocabulary is:

- `ManagedBuffer<Header, Element>` — heap-allocated, header+trailing-elements,
  not called "Box" but reasonably analogous to a generic box.
- `Unmanaged<Instance>` — manual retain-balance wrapper over AnyObject.
- SE-0437 *noncopyable stdlib primitives* introduced `Cell` on the
  stdlib roadmap (it is not yet shipped in the surveyed toolchains, but
  the direction is set).

Swift stdlib has not staked a meaning for `Box`; the space is *open*
within Swift but *taken* in Rust/C++.

### Academia — "Box" as a term of art

"Box" does not have a settled meaning in the linear/affine/ownership
type-theory literature.

- In Wadler's *Linear types can change the world!* (1990), the
  linear-logic exponential `!` is the erasure of linearity — **not a
  "box" in the programming sense** but the term that gets translated to
  "box" in some informal write-ups.
- In modal logic and staging, `□` ("box") is a modality, not a data
  container.

Neither usage maps onto "type-erased transfer slot". The Swift engineer
who knows the literature will not expect `Box` to mean type-erasure.

## Analysis

### What contract does `Ownership.Transfer.Box` actually implement?

From `Sources/Ownership Transfer Box Primitives/Ownership.Transfer.Box.swift:41`:

```swift
public enum Box {}              // namespace
// Header: destroyPayload + payloadOffset
// Pointer: UnsafeMutableRawPointer capability wrapper
// make<T>, take<T>, destroy — type-erased boxing
```

The contract is:

1. **Type-erased** — the pointer leaves `T` and `E` at the call boundary.
2. **One-shot** — exactly-once `take` or `destroy` trap.
3. **Outbound** — producer allocates, consumer (often knowing only
   `void*`) consumes or destroys.
4. **Single allocation** — header + payload are co-located.

The defining trait is *type erasure*. The other Transfer.* members do
not erase types (`Cell` keeps `T`; `Retained` specialises to AnyObject).

### Name alternatives

| Option | Meaning of leaf word | Collides with | Reads as |
|--------|----------------------|---------------|----------|
| `Transfer.Box` (current) | Rust: unique heap cell (our `Unique`) | Rust `Box<T>` — diametric | Confusing in Rust-adjacent reader's head |
| `Transfer.Erased` | Type erasure (our contract) | — | "the erased variant of Transfer" |
| `Transfer.Opaque` | Opacity (C-interop lens) | — | "the opaque variant of Transfer" |
| `Transfer.Anonymous` | Type-anonymity | — | "the type-anonymous variant" |
| `Transfer.VoidPointer` | C `void*` | — | over-literal; naming for implementation not contract |

`Erased` is the term Swift engineers already know from "type-erasure"
patterns (`AnyCollection`, `AnySequence`, `AnyHashable`, `@_eagerMove`
discussions, and the SE-0335 `any` existential vocabulary). It is
Swift-native language for exactly this contract.

### Apple alignment

Apple stdlib idioms for type erasure:

- `AnyHashable`, `AnySequence`, `AnyCollection` — prefix `Any`.
- `any Error` — existential-type keyword (SE-0335).
- `Optional<T>` wraps presence; no erasure vocabulary.

Swift's `Any*` prefix is not ideal for a nested type (`Transfer.Any*`
would read oddly). The ecosystem's own conventions (spec-mirroring per
[API-NAME-003], expressive leaf nouns per [API-NAME-001]) prefer `Erased`
— a past-participle noun that describes the contract without leaning
on a naming pattern that Apple reserves for top-level existentials.

### Academic alignment

The literature that matters — Wadler 1990, Walker 2005 (substructural
type systems), Rust ownership papers — does not stake a term for
"type-erased linear resource". The closest is "untyped linear value",
but "erased" is the canonical English term for "typed → untyped" in
the Swift ecosystem.

### Blast radius

From the v2.1.0 usage inventory (`ownership-types-usage-and-justification.md`):

| Type | File count (non-own-package) |
|------|------------------------------|
| `Transfer.Box` | **0** |

A grep across `swift-primitives/`, `swift-standards/`, `swift-foundations/`,
`swift-institute/Experiments/` on 2026-04-23 confirmed zero external
consumers. The rename is mechanical and entirely internal at this
moment.

## Outcome

**Status**: RECOMMENDATION.

**Decision basis**: the name `Box` is diametrically wrong against the
dominant prior art (Rust's `Box<T>` = exclusive heap owner, not type
erasure). The ecosystem-native alternative `Erased` matches the contract
precisely, aligns with Apple's existing type-erasure vocabulary (without
stealing the `Any*` prefix), and does not compete with any academic
term of art. Blast radius is zero.

**Action**: rename `Ownership.Transfer.Box` → `Ownership.Transfer.Erased`
in the 0.1.0 tag cycle. This frees `Box` for the potential
`Ownership.Unique → Ownership.Box` rename under the A3 cluster (see
`naming-unique-to-box.md`).

**Secondary clean-up**: the product target currently named
`Ownership Transfer Box Primitives` becomes
`Ownership Transfer Erased Primitives` under the primary-decomposition
narrow-import scheme per [MOD-015].

## References

- [Rust std::boxed::Box](https://doc.rust-lang.org/std/boxed/struct.Box.html) — exclusive heap ownership
- [Rust Book Ch. 15: Box<T>](https://doc.rust-lang.org/book/ch15-01-box.html)
- [C++ std::unique_ptr](https://en.cppreference.com/w/cpp/memory/unique_ptr)
- [SE-0437: Noncopyable stdlib primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md)
- [SE-0335: `any` existentials](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md) — Apple's type-erasure vocabulary
- Wadler, P. (1990). *Linear types can change the world!* — linear-logic foundations, no "box" term of art for erasure
- `Ownership.Transfer.Box.swift:41` — current declaration
- v2.1.0 `ownership-types-usage-and-justification.md` — Cluster A recommendation, usage inventory

## Provenance

Per-module naming research requested 2026-04-24 to align the 0.1.0 API
surface with academia and Apple. Augments the v2.1.0 cross-type
research with focused prior-art citations.
