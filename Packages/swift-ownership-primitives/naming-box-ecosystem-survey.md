# `Box` in the Swift Ecosystem — Literature Study

<!--
---
version: 1.1.0
last_updated: 2026-04-24
status: RECOMMENDATION
tier: 2
scope: ecosystem-wide
---
-->

## Changelog

- **v1.3.0 (2026-04-24)** — Final A3 decision. Second experiment
  `Experiments/nested-type-generic-escape/` refuted the "bare Box<V> +
  nested Box.Unique" pattern (Swift requires outer generic; hoisted
  typealias crashes the compiler). Principal direction: flat namespace,
  no Box.* nesting, optimise ownership-primitives in isolation. Final
  implementation: **keep `Ownership.Unique` name** as the Institute
  Nest.Name rendering of SE-0517 `UniqueBox`. Tighten API to full
  SE-0517 parity — `.take()` (mutating, empty state) → `.consume()`
  (consuming, destroys self); `.duplicated()` → `.clone()`; drop
  `.hasValue`, `.leak()`, `description`, `debugDescription`; storage
  `UnsafeMutablePointer<Value>?` → non-optional; add
  `var value { _read _modify }`. `Ownership.Indirect<V>` (CoW sibling)
  deferred to 0.2.0. Implemented 2026-04-24; 85 tests / 35 suites pass.
- **v1.2.0 (2026-04-24)** — Added empirical validation of the two-type vs
  unified-conditional-Copyable decision via experiment
  `Experiments/unified-vs-two-type-box-design/`. **H5 finding is decisive:
  SE-0517's `consuming func consume() -> Value` for `Value: ~Copyable`
  CANNOT be implemented with class-backed storage** (Swift rejects with
  `'storage.value' is borrowed and cannot be consumed`). The two-type
  approach (raw-pointer `UniqueBox` + class-backed `Box`) is
  architecturally required by the Swift language, not merely Apple's
  stylistic choice. The array-primitives conditional-Copyable pattern
  does not transfer to Box because arrays' storage is indirected through
  ManagedBuffer; Box's storage IS the value and must support `.move()`.
  Revises A3 recommendation: `Ownership.Box.Unique<V: ~Copyable>: ~Copyable`
  with raw-pointer storage (SE-0517 fidelity), nested inside `Ownership.Box`
  namespace enum. CoW sibling deferred.
- **v1.1.0 (2026-04-24)** — Extended with SE-0527 (RigidArray and
  UniqueArray, in review through 2026-04-27) and the new stdlib
  `Containers` module finding. Documents Apple's **full `Unique*` /
  `Rigid*` family strategy**, not just the single UniqueBox case.
  Also captures the SE-0517 page-3/4 evidence of John McCall's naming
  matrix and the LSG's explicit reservation of bare `Box` for a future
  CoW variant. Refines A3 recommendation: rename to `Ownership.UniqueBox`
  with method rename `take()` → `consume()` for full SE-0517 API parity.
- **v1.0.0 (2026-04-24)** — Initial survey.

## Context

Prior `naming-transfer-box-to-erased.md` (A1) and `naming-unique-to-box.md`
(A3) research argued that our `Ownership.Unique` could rename to
`Ownership.Box` following Rust's `std::boxed::Box<T>`, and that our
`Ownership.Transfer.Box` should rename to `Ownership.Transfer.Erased`
to avoid the diametric collision.

Those documents cited Rust and C++ prior art but did **not** survey
the Swift ecosystem itself. The principal asked for that gap to be
closed: what does "Box" mean in swiftlang/swift, in Swift Evolution,
in Apple-stewardship packages, and in the Swift Forums?

This study answers that question.

## Question

For the 0.1.0 API surface of `swift-ownership-primitives`, how should
the findings of the Swift-ecosystem `Box` survey shape the A1 and A3
naming decisions?

## The Single Most Important Finding: SE-0517 UniqueBox

**SE-0517: UniqueBox** was accepted March 2026 (review period 3–13 March
2026). Apple is adding to the Swift stdlib:

```swift
public struct UniqueBox<Value: ~Copyable>: ~Copyable {
    public init(_ initialValue: consuming Value)
    public var value: Value { borrow mutate }
    public consuming func consume() -> Value
    public var span: Span<Value> { get }
    public var mutableSpan: MutableSpan<Value> { mutating get }
    public func clone() -> UniqueBox<Value> where Value: Copyable
}
extension UniqueBox: Sendable where Value: Sendable & ~Copyable {}
```

This is **structurally identical** to `Ownership.Unique`: heap-owned,
exclusive, `~Copyable`, generic over `~Copyable Value`, conditionally
Sendable, `~Copyable` struct with deinit.

### Why Apple chose `UniqueBox` over `Box`

From the [Pitch: Box](https://forums.swift.org/t/pitch-box/84014) thread
on Swift Forums:

- Alejandro Alonso (pitch author) originally proposed **`Box`** following
  Rust's lineage.
- **Joe Groff** (Apple stdlib engineer) objected: *thousands of existing
  Swift projects already use `Box` as a class-based reference-counted
  wrapper* — a genuine naming collision.
- **Rick van Voorden** proposed **`UniqueBox`** as the compromise: keeps
  the familiar "Box" vocabulary, disambiguates via "Unique" to signal
  exclusive ownership.
- **Tony Allevato** framed the choice as analogous to the `InlineArray`
  (formerly `Vector`) decision: Swift's maturity means it cannot override
  ten years of ecosystem usage with a new neologism.

The final proposal documents this explicitly:

> **Box** — rejected due to ecosystem collision with shared-pointer-like
> implementations.
> **UniquePtr** — considered but deprioritized despite C++ precedent, given
> Swift community conventions favoring "Box" terminology.

The review thread ([SE-0517](https://forums.swift.org/t/se-0517-uniquebox/85107))
further confirms "boxing" has been "a term of art for a heap allocated
value since at least the 1960s" (Lisp, Java, Obj-C) — but that common
heritage does *not* specialise to "exclusive ownership". The `Unique`
qualifier is carrying the ownership semantic.

**Result**: Apple's official vocabulary for "heap-owned exclusive
`~Copyable` cell" is `UniqueBox`, not `Box`, and not `Unique`.

### The LSG's acceptance rationale (explicit)

The [Accepted SE-0517 announcement](https://forums.swift.org/t/accepted-se-0517-uniquebox/86138)
states:

> The LSG thinks that "Box" is the right name, rather than "Pointer",
> as this is not a "safe replacement for `UnsafePointer`." [Box is]
> generally accepted as a term of art for what this type is, including
> in other languages.
>
> The `Unique` prefix denotes a noncopyable variant, with unprefixed
> `Box` reserved for potential future copy-on-write support. **This
> naming pattern is considered "appropriate to be adopted more widely,"**
> including in concurrent proposals like `UniqueArray`.

Two consequences relevant to our ecosystem:

1. **Bare `Box` is explicitly reserved** for a future Copyable CoW
   variant. Any ecosystem package that ships `Ownership.Box` today would
   be occupying the name Apple plans to use.
2. **`Unique*` is a deliberate family prefix**, not a one-off for
   `UniqueBox`. SE-0527 is already shipping `UniqueArray` under the
   same pattern.

## The bigger picture: SE-0527 and the `Containers` module

**SE-0527: RigidArray and UniqueArray** (review through 2026-04-27)
extends the `Unique*` family:

| | Noncopyable container | Copyable (CoW) container |
|---|---|---|
| **Fixed capacity** | `RigidArray<T: ~Copyable>` | — |
| **Dynamic / resizing** | `UniqueArray<T: ~Copyable>` | `Array<T>` |

And SE-0527 introduces a new stdlib module: **`Containers`** — described
as "a new module in the Swift toolchain," a home for noncopyable data
structure implementations. It parallels `swift-collections` but ships in
the toolchain itself.

### Declared future types in SE-0527

> RigidDeque, UniqueDeque, RigidSet, UniqueSet, RigidDictionary, and
> UniqueDictionary are all potential future additions to the Swift
> Standard Library.

The full combinatorial family Apple is building:

| Concept | Copyable (CoW) | Noncopyable dynamic | Noncopyable fixed |
|---------|----------------|---------------------|-------------------|
| Single value | `Box` *(future)* | `UniqueBox` ✓ SE-0517 | *(n/a)* |
| Array | `Array` (stdlib) | `UniqueArray` ✓ SE-0527 | `RigidArray` ✓ SE-0527 |
| Dictionary | `Dictionary` (stdlib) | `UniqueDictionary` (future) | `RigidDictionary` (future) |
| Set | `Set` (stdlib) | `UniqueSet` (future) | `RigidSet` (future) |
| Deque | (swift-collections) | `UniqueDeque` (future) | `RigidDeque` (future) |

### Strategic reading

Apple is **standardising** a cross-family vocabulary: `Unique*` means
"noncopyable, uniquely-owned" and `Rigid*` means "fixed-capacity".
Ecosystem packages that diverge from this vocabulary carry migration
cost as the stdlib family lands.

### John McCall's explicit matrix (from SE-0517 review page 3)

Before acceptance, John McCall posted the governing matrix:

| | Copy-on-Write | Noncopyable |
|---|---|---|
| Array | Array | UniqueArray |
| Dictionary | Dictionary | UniqueDictionary |
| Set | Set | UniqueSet |
| Box | Box | UniqueBox |

He affirmed: *"Box is a very common term of art...across basically
every object-oriented language"* — and confirmed the `Unique` prefix
is consistently satisfying across this family.

## SE-0517 API surface (the authoritative reference)

Final accepted shape of `UniqueBox`:

```swift
public struct UniqueBox<Value: ~Copyable>: ~Copyable {
    public init(_ initialValue: consuming Value)
    public var value: Value { borrow mutate }           // SE-0507 BorrowAndMutateAccessors
    public consuming func consume() -> Value             // NOT "take"
    public var span: Span<Value> { get }
    public var mutableSpan: MutableSpan<Value> { mutating get }
    public func clone() -> UniqueBox<Value> where Value: Copyable
}
extension UniqueBox: Sendable where Value: Sendable & ~Copyable {}
```

**API-level takeaways**:

- The consuming extractor is spelled **`consume()`**, not `take()`.
  Apple deliberately does not use the Rust-style `take()`.
- `value { borrow mutate }` uses SE-0507 BorrowAndMutateAccessors, not
  available on Swift 6.3.1 — our package's `withValue` / `withMutableValue`
  closure pattern is the pre-SE-0507 ecosystem equivalent.
- `clone()` is Copyable-conditional — Apple's way of saying "explicit
  opt-in to deep copy". Our `Ownership.Unique` lacks this entirely.
- Ben Cohen on review page 4: "Giving this type the ability to [unsafe
  pointer bridges] would move it from a guaranteed safe type ... to a
  potentially unsafe type." **Apple rejects a `fromRaw` / `intoRaw` API
  explicitly** — a design departure from Rust's `Box`.

Our `Ownership.Unique` also lacks such unsafe bridges — aligned by
coincidence, confirmed by principle.

## Alternative names considered in SE-0517 review

For completeness, the naming alternatives Apple rejected:

| Considered | Why rejected |
|------------|--------------|
| `Box` | Collides with existing ecosystem use (Joe Groff); reserved for future CoW variant |
| `UniquePtr` | C++ flavour; "Box" is more Swift-idiomatic per community convention |
| `Allocated<T>` | Considered; rejected as insufficiently specific (Jonathan Grynspan noted Swift Testing uses an internal `Allocated` type) |
| `UniqueReference` / `ExclusiveReference` | Ricky Sharp proposal; lost to shorter `UniqueBox` |
| `UniqueAllocation` | Prior pitch-thread alternative |
| `UniquePointer` | Same |
| `UniqueBoxed<T>` | Proposed to shift the noun-ness; lost to `UniqueBox` |
| `UniqueHeapRef` | Too specific-to-implementation |
| `Allocated` (bare) | Rauhul Varma: "burning the name without considering custom allocators" concern |
| `Unique` (bare) | Lost; Ben Cohen: "a managed heap-allocated slot for a single value" — "Box" more faithfully describes the shape |

The debate concluded: **`UniqueBox` is the right name**.

## Survey: "Box" across swiftlang/swift (compiler + stdlib + runtime)

Investigated by local grep on 1.6 GB tree. Full inventory in the
companion Explore report; summary here.

### Public stdlib API — zero public `Box` types

The stdlib exports **no** public type named `Box`, `*Box`, or `Box*`.

### Internal stdlib type-erasure pattern (`*Box` suffix, all internal)

Extensive use for existential dispatch indirection, all `internal`/`private`:

| Type | File | Role |
|------|------|------|
| `_ConcreteHashableBox<Base>` | AnyHashable.swift | Existential dispatch for `AnyHashable` |
| `_IteratorBox<Base>` | ExistentialCollection.swift | Erases iterator protocol conformance |
| `_KeyedEncodingContainerBox<Concrete>` | Codable.swift | Erases Encoder/Decoder containers |
| `CxxSequenceBox<T>` | C++ interop | Bridges C++ sequences |
| `_AnySequenceBox<Element>` | AnySequence.swift | Lazy-collection erasure |
| `_NewtypeWrapperAnyHashableBox<Base>` | AnyHashable.swift | Newtype erasure |

Pattern: `Box` suffix = *type-erased dispatch indirection* for existentials.
This is a meaning **adjacent to but distinct from ownership**.

### SIL compiler abstraction

Three SIL concepts carry "Box":

| Name | Role |
|------|------|
| `SILBoxType` | SIL type = heap cell capturing mutable locals for closures |
| `AllocBoxInst` | SIL instruction `%1 = alloc_box` — heap allocate |
| `ProjectBox` | SIL instruction — extract field from box |

In SIL, **"box" = heap-allocated cell with indirect storage**. No ownership
semantic encoded — a SIL box is a storage shape, not a contract.

### Runtime heap primitives (`*Box` naming)

In `stdlib/public/runtime/`, metadata/value-witness machinery uses
`*Box` CRTP templates:

- `ExistentialBoxBase<Impl>`, `OpaqueExistentialBox`, `ClassExistentialBox`
- `NativeBox<T>`, `RetainableBoxBase<Impl, T>`, `SwiftRetainableBox`
- `AggregateBox`, `ThickFunctionBox`, `DiffFunctionBox`

All internal runtime machinery. Purpose: **value-witness-table specialisation
over box layouts**. Again: structural meaning, not ownership.

### Nearest stdlib user-facing analog to heap-owned cell

`ManagedBuffer<Header, Element: ~Copyable>` — the only current user-facing
construct for exclusive user-managed heap allocation. Not called "Box".

### Explicit conclusion

**In swiftlang/swift, "Box" means "heap-allocated cell with indirect
storage" — a structural, not ownership-encoding, term.** No public
Swift-stdlib type is called `Box` today, and SE-0517 takes the name
`UniqueBox` specifically because "Box" alone would collide with existing
ecosystem patterns.

## Survey: "Box" across Apple-stewardship Swift packages

Investigated on 45 `swiftlang/swift-*` packages. Findings:

### Public `Box`-family types (all qualified)

| Package | Public type | Role |
|---------|-------------|------|
| swift-nio | `NIOLockedValueBox<Value>` | Lock-protected reference cell |
| swift-nio | `NIOLoopBoundBox<Value>` | EventLoop-bound reference for non-Sendable values |
| swift-nio | `AtomicBox<T>` (deprecated) | Atomic CAS on reference-typed value |
| swift-package-manager | `SendableBox<Value>` | Actor-based Sendable wrapper |
| swift-package-manager | `ThreadSafeBox<Value>` | NSLock-based thread-safe cell |
| swift-crypto | `SealedBox` | Sealed ciphertext + nonce + tag bundle (per AEAD) |
| swift-certificates | `LockedValueBox<Value>` (internal) | Locked reference storage |

**Every public `Box` type in the Apple-stewardship ecosystem is
qualified** — `*LockedValueBox`, `*LoopBoundBox`, `SealedBox`, `ThreadSafeBox`,
`SendableBox`, `AtomicBox`. There is **no** public type named exactly `Box`
anywhere in the surveyed ecosystem.

### Dominant semantic of the `Box` suffix

Across public Apple-stewardship types, `Box` = **synchronization /
reference-cell primitive**: lock-wrapped, actor-wrapped, atomic-wrapped,
event-loop-bound, or semantically sealed (crypto).

This is NOT the Rust meaning (exclusive heap-owned cell). In the Apple
ecosystem, "Box" drifts toward concurrency/reference-wrapping vocabulary.

### Internal `Box<T>` patterns

Across multiple packages (swift-collections tests, corelibs-foundation,
swift-nio utilities, swift-foundation tests), a generic `internal struct
Box<T> { var value: T }` appears as a testing/internal utility. Never
promoted to public API in any observed case.

## Synthesis: three coherent meanings of "Box" in Swift

| Meaning | Where it lives | Example |
|---------|----------------|---------|
| 1. **Heap cell / indirect storage** (structural) | SIL, runtime, SE-0517 | `SILBoxType`, `AllocBoxInst`, `UniqueBox` |
| 2. **Type-erased existential dispatch** | Stdlib internals | `_ConcreteHashableBox`, `_IteratorBox` |
| 3. **Synchronization / reference wrapper** | NIO, SwiftPM, Crypto | `NIOLockedValueBox`, `SendableBox`, `SealedBox` |

**None of these maps onto "unique ownership"** on its own. The ownership
semantic only appears when explicitly added via prefix (`UniqueBox`,
"exclusive" in the docstring, etc.).

## Implications for `Ownership.*` naming

### A3 revised: `Ownership.Unique` → `Ownership.UniqueBox` + `.consume()`

The original A3 (`naming-unique-to-box.md`) recommended rename to
`Ownership.Box` citing Rust precedent. **This finding invalidates
that recommendation.** Apple has rejected exactly that move — and
reserved the name for a future CoW variant.

Four coherent paths:

| Path | Type name | Method name | Pros | Cons |
|------|-----------|-------------|------|------|
| **A3a** (status quo) | `Ownership.Unique` | `take()` | No migration cost today | Divergence from SE-0517 grows; migration debt accumulates |
| **A3b** (type-only align) | `Ownership.UniqueBox` | `take()` | Matches stdlib type name | API-level divergence on the consuming accessor |
| **A3c** (full align) ⭐ | `Ownership.UniqueBox` | `consume()` | Full SE-0517 API parity; bridge with `typealias UniqueBox<T> = Swift.UniqueBox<T>` trivial once stdlib lands | Two renames |
| **A3d** (bare Box) | `Ownership.Box` | any | Rust-style | **Apple explicitly rejected** for ecosystem collision + reserves the name for future CoW |

**Recommendation: A3c.** Full alignment with SE-0517 — type renamed
to `Ownership.UniqueBox` AND `.take()` renamed to `.consume()`. This
is the only path that gives us a one-line stdlib bridge when SE-0517
ships:

```swift
@available(Swift 6.4, *)
public typealias UniqueBox<T: ~Copyable> = Swift.UniqueBox<T>
```

### Considerations for the rest of the family

Apple's `Rigid*` / `Unique*` pattern applies across **container types**.
Our ecosystem has no noncopyable array/set/dictionary — those would
belong in a future `swift-containers-primitives` or we could simply
defer to stdlib `Swift.UniqueArray` etc. when SE-0527 ships.

Our `Ownership.Slot` (reusable atomic single-value slot) is **not** in
Apple's container family — it is a concurrency primitive. No rename
pressure from the SE-0517/SE-0527 axis.

Our `Ownership.Transfer.*` family is likewise distinct (one-shot
transfer, not a container). A2 (direction rename) is unaffected by
this finding — `Outgoing`/`Incoming` is orthogonal to Apple's
`Unique*`/`Rigid*` axis.

### A1 revised: `Ownership.Transfer.Box` — still rename, but the argument shifts

The original A1 (`naming-transfer-box-to-erased.md`) argued rename
because of diametric collision with Rust's `Box<T>`. That argument is
now **reinforced** rather than weakened:

- Apple's chosen vocabulary is `UniqueBox` (not `Box`) for exclusive
  heap ownership.
- Apple's actual modal meaning of `*Box` suffix in public API is
  synchronization / reference-cell — close to our `Transfer.Cell`
  semantics, but **nothing** in the Apple ecosystem uses `Box` to mean
  "type-erased".
- So `Ownership.Transfer.Box` is misleading on *two* fronts: (1) not
  the ownership meaning anyone expects; (2) not the Apple-ecosystem
  meaning of the suffix either.

`Ownership.Transfer.Erased` remains the right name — matches Swift's
existing type-erasure vocabulary (`AnyHashable`, `any Error`, `*Erasure`
patterns) without colliding with any ecosystem `Box` meaning.

**Recommendation: A1 rename stands — `Ownership.Transfer.Box` → `Ownership.Transfer.Erased`.**

### Naming for other `*Box` concepts in this package

`Ownership.Transfer._Box` (the internal single-alloc header helper) is
fine as-is — it's internal, underscore-prefixed, and precisely captures
"the header+payload heap cell" — closest to the SIL `AllocBox` meaning.
No change.

## Outcome

**Status**: RECOMMENDATION.

**A1** — rename `Ownership.Transfer.Box` → `Ownership.Transfer.Erased`.
Recommendation from `naming-transfer-box-to-erased.md` stands; this
study reinforces it.

**A3 — revised**: the original "rename to `Ownership.Box`" recommendation
is **withdrawn**. Apple rejected that exact name in SE-0517 for
ecosystem-collision reasons that apply equally to our ecosystem.

Choose between:

- **A3a**: keep `Ownership.Unique` (status quo; migrate to stdlib
  `Swift.UniqueBox` when available)
- **A3b**: rename `Ownership.Unique` → `Ownership.UniqueBox` (align
  with SE-0517 now; adoption-optimised)

**This study recommends A3b** (`Ownership.UniqueBox`), on the grounds that:

1. Apple stdlib's chosen name IS the authoritative ecosystem name for
   this contract. Our job is to match it, not invent a competing name.
2. Adoption advantage: consumers learning our package recognise `UniqueBox`
   as "the stdlib heap-owned exclusive cell, pre-stdlib version", not a
   new concept to learn.
3. Migration simplicity: when SE-0517 lands, we can introduce
   `public typealias UniqueBox<T> = Swift.UniqueBox<T>` with zero
   consumer-facing name change.
4. Blast radius is low (1 consumer file per v2.1.0 inventory).

The trade-off: "UniqueBox" feels faintly compound. Per [API-NAME-001],
it is a single leaf identifier (like `ManagedBuffer`, `UnsafePointer`,
`UniquePtr` — compound-form leaf nouns are acceptable when the upstream
standard uses them). SE-0517 is effectively the spec we mirror per
[API-NAME-003].

**Recommendation order**: pick A3b (best), fall back to A3a (acceptable),
exclude A3c (prior-art-rejected).

## Additional neighbouring findings (from adjacent-concepts survey)

Not every neighbouring concept pressures a naming decision, but the
survey turned up these facts worth capturing:

| Name | Status in Swift stdlib | Relevance to our package |
|------|------------------------|--------------------------|
| `Pin` / `Pinned` | None. Not defined anywhere. | Name is free if Ownership ever needs a stabilisation primitive — but no Swift precedent to anchor to |
| `Cell` (bare) | None in stdlib. Rust `std::cell::Cell` is interior-mutability. | `Ownership.Transfer.Cell` is safe from stdlib collision — but Rust-adjacent readers may still misread (see A2) |
| `Slot` | None in stdlib. | `Ownership.Slot` is original; no collision |
| `Allocated<T>` | Not in stdlib. Swift Testing uses an internal type of this shape. | Rejected as SE-0517 alternative; do not attempt |
| `Owned` / `Owns` | Only in SIL/runtime docs as owned-parameter conventions. No public type. | Name is free but less descriptive than `Unique*` |
| `HeapObject` | Public in **Embedded Swift only**. | Not a name to adopt for general-purpose ownership |
| `Indirect` / `@Boxed` | `indirect` is the enum-case keyword; no module-level type. No `@Boxed` macro. | Do not name a type `Indirect<T>` — language keyword collision concern |
| `Existential*Box` | Internal stdlib plumbing (`OpaqueExistentialBox`, `ClassExistentialBox`). Not user-facing. | "Box" = existential container in stdlib internals — informs why Apple chose `UniqueBox` not bare `Box` |
| Bare `Box` | **Reserved** by LSG for future CoW-supporting variant. | Do NOT claim this name in any ecosystem package |

## Apple's `consume()` vs our `take()` — deeper context

SE-0517 names the consuming accessor **`consume()`**. This is not
incidental — it harmonises with:

1. **SE-0366 consume operator**: `let x = consume y` is the
   ownership-taking keyword-level operation.
2. **WWDC24 "Consume noncopyable types in Swift" session**
   (session 10170) — Apple normalises `consume` as *the* vocabulary
   for "take ownership" across the language.
3. **The broader `Unique*` family**: SE-0527 `UniqueArray` does NOT
   use `take()`; it follows the same `consume` / `clone` / accessor
   pattern.

Our `Ownership.Unique.take()` comes from the Rust `Option::take()`
lineage (which is also the inspiration for our `Optional+take.swift`
stdlib-integration extension). That Rust lineage is now divergent from
the Swift stdlib — Swift is resolving on `consume` as its ownership
verb.

**Recommendation**: rename `Ownership.Unique.take()` → `.consume()` as
part of A3c. Blast radius is the same as the type rename (1 backward-compat
doc site).

Note: this does NOT mean `Optional+take.swift` should rename. That file
extends `Optional`, where `.take()` mirrors Rust's `Option::take()`
exactly (and Apple has NOT added a competing Swift stdlib method).
Keep `Optional.take()`; rename `Ownership.Unique.take()` → `.consume()`.

## References

### Primary — Swift Evolution

- [SE-0517: UniqueBox](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0517-uniquebox.md) — accepted March 2026
- [Accepted SE-0517 announcement](https://forums.swift.org/t/accepted-se-0517-uniquebox/86138) — LSG rationale
- [SE-0527: RigidArray and UniqueArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0527-rigidarray-uniquearray.md) — in review through 2026-04-27
- [SE-0528: Noncopyable Continuation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0528-noncopyable-continuation.md) — noncopyable continuation infrastructure
- [SE-0427: Noncopyable Generics](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) — foundation: Copyable protocol
- [SE-0437: Noncopyable stdlib primitives](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0437-noncopyable-stdlib-primitives.md) — Optional<~Copyable>, Result<~Copyable, _>
- [SE-0366: consume operator](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0366-move-function.md) — language-level `consume` keyword
- [SE-0507: Borrow Accessors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0507-borrow-accessors.md) — `borrow` accessors

### Swift Forums — naming debates

- [Pitch: Box](https://forums.swift.org/t/pitch-box/84014) — original pitch + Joe Groff's ecosystem-collision objection
- [SE-0517 review](https://forums.swift.org/t/se-0517-uniquebox/85107) — six-page review thread
- [SE-0517 review page 3](https://forums.swift.org/t/se-0517-uniquebox/85107?page=3) — John McCall's naming matrix
- [SE-0517 review page 4](https://forums.swift.org/t/se-0517-uniquebox/85107?page=4) — alternatives (Allocated, UniqueReference, UniqueBoxed); Ben Cohen's design clarifications
- [Pitch: RigidArray and UniqueArray](https://forums.swift.org/t/pitch-rigidarray-and-uniquearray/85455) — SE-0527 pitch thread

### WWDC

- [WWDC24 — Consume noncopyable types in Swift (session 10170)](https://developer.apple.com/videos/play/wwdc2024/10170/) — `consume` keyword semantics

### Ecosystem surveys (companion Explore reports, 2026-04-24)

- swiftlang/swift — source-tree survey (1.6 GB): public `Box` = zero; internal `*Box` for existential erasure; SIL `SILBoxType` / `AllocBoxInst` / `ProjectBox`; runtime `ExistentialBoxBase`, `NativeBox`, `RetainableBoxBase`
- swiftlang/swift-nio — `NIOLockedValueBox<Value>`, `NIOLoopBoundBox<Value>`, `AtomicBox<T>` (deprecated)
- swiftlang/swift-package-manager — `SendableBox<Value>`, `ThreadSafeBox<Value>`
- swiftlang/swift-crypto — `SealedBox` (AEAD-specific)
- swiftlang/swift-certificates — `LockedValueBox<Value>` (internal)
- swiftlang/swift-collections — test-fixture `Box<T>` only
- swiftlang/swift-corelibs-foundation — test-fixture `Box<T>` + internal CF-ptr boxes

### Contrasting precedent (non-Swift)

- [Rust std::boxed::Box](https://doc.rust-lang.org/std/boxed/struct.Box.html)
- Rust `core::ptr::Unique` (unstable internal API; no stable doc URL)
- [C++ std::unique_ptr](https://en.cppreference.com/w/cpp/memory/unique_ptr)

### Internal cross-refs

- `naming-transfer-box-to-erased.md` — A1 per-module research (reinforced by this study)
- `naming-unique-to-box.md` — A3 per-module research (recommendation SUPERSEDED by this study)
- `ownership-types-usage-and-justification.md` (v2.1.0) — cross-type evaluation

## Provenance

Ecosystem-wide "Box" literature study commissioned 2026-04-24 to close
the gap in the Apple/swiftlang survey for the per-module A1 and A3
research docs. SE-0517 (UniqueBox accepted March 2026), SE-0527 (RigidArray /
UniqueArray in review, introducing new `Containers` stdlib module), and
the LSG's explicit reservation of bare `Box` for a future Copyable CoW
variant together shape the A3 recommendation. Version 1.1.0 (2026-04-24)
adds SE-0527 + McCall matrix + adjacent-concept findings to the v1.0.0
survey.
