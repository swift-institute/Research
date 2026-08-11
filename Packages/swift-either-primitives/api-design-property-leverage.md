# Either API Design — Property-Primitives Leverage

<!--
---
version: 1.0.0
last_updated: 2026-05-08
status: RECOMMENDATION
tier: 2
scope: per-package
---
-->

## Context

`Either<Left, Right>` was extracted from `swift-algebra-primitives` into the
standalone `swift-either-primitives` package. The current public API at
`/Users/coen/Developer/swift-primitives/swift-either-primitives/Sources/Either Primitives/Either.swift`
ships three compound-identifier methods that violate the
[API-NAME-002] "no compound identifiers" rule:

* `static/instance mapLeft(...)`
* `static/instance bimap(left:, right:)`
* instance `mapRight(...)` (alias of `map`)

A 2026-03-19 Tier 2 RECOMMENDATION at
`/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Research/either-implementation.md`
froze nine higher-level decisions (binary form, `Either` name,
left=infrastructure / right=caller convention, `fold` to be added,
`~Copyable` deferred, `Parser.Error.Either` typealias migration). That document
took API surface as out of scope. This research is the focused follow-up: how
should the surface be **shaped** at the call site, given:

1. [API-NAME-002] forbids `mapLeft` / `mapRight` / `bimap`.
2. [API-NAME-008] codifies the Property.View vs labeled-method decision rule.
3. `swift-property-primitives` v0.1.0 publishes `Property.Inout`,
   `Property.Borrow`, `Property.Typed`, `Property.Consume` variants
   (the on-disk variant names — the property-primitives skill text still uses
   the older `View` / `View.Read` / `Consuming` labels in places).
4. [IMPL-INTENT] requires every call site to read as intent.

The package has multiple in-flight typed-throws consumers
(`swift-parser-primitives`, `swift-pool-primitives`, `swift-binary-parser-primitives`,
`swift-foundations/swift-parsers`, `swift-foundations/swift-posix`,
`swift-foundations/swift-ascii`, `swift-foundations/swift-tests`). Picking the
final API shape now is cheaper than deferring; consumers that already use
`Either<L, R>` for `throws(Either<...>)` are using only constructors and
case-pattern destructuring, not the functor methods, so the migration cost of
renaming the functor methods is bounded.

**Trigger**: [RES-018] — convention-violation surfaced during ecosystem typed-
throws adoption; design must converge before consumers grow a dependency on
the violating shape.

**Scope**: per-package — the surface change is local to
`swift-either-primitives` and its test suite. `Pair` (in
`swift-pair-primitives`) shares the same anti-pattern and SHOULD be migrated
in the same wave; that work is out of scope for this document but the same
reasoning applies one-to-one and is referenced where useful.

## Question

The Tier 2 mandate decomposes into seven sub-questions:

1. **Property.View namespace shape** — Does `either.map.left { f }` work
   concretely with `Property<Tag, Base>`? What does the `Tag` look like (an
   `enum Map {}` nested in `Either`)? Is `.map` even the right namespace name,
   or should it be `.transform`, `.mapped`, etc.?
2. **Labeled-method shape** — `either.map(left: f)`,
   `either.map(right: g)`, `either.map(left: f, right: g)` as overloads on a
   single `map` identifier — what are the trade-offs? Do the labels
   `left:` / `right:` collide with the case names `.left(_)` / `.right(_)`?
3. **Hybrid** — Could `.map.left { f }` (a Property.View tag-getter) and
   `.map(left: f, right: g)` (overloaded labeled methods) co-exist on the same
   `map` identifier? Does the Swift compiler accept a property and a method
   with the same base name on the same type?
4. **Swap, fold, accessors** — How should `.swapped` (currently `var`),
   `fold(left:, right:)` (recommended addition per the prior research), and
   `var left` / `var right` (case-named accessors) fit the chosen design?
5. **Never-elimination accessor** — Is `var value: Right where Left == Never`
   still the right name? Could `Either<Never, T>` deserve its own accessor
   namespace that distinguishes "the impossible side has been eliminated" from
   "this is the ordinary right value"?
6. **Static-dispatch layer** — [IMPL-023] places core logic in static methods
   and lets compound names live there per [IMPL-024]. Does the static surface
   on `Either` need to change shape, or only the public instance surface?
7. **Existing call sites** — What do consumers actually call today? Which
   methods are load-bearing across the ecosystem, and which exist purely as a
   Haskell-tradition habit?

## Constraints

| ID | Statement | Where it bites Either |
|----|-----------|------------------------|
| [API-NAME-001] | Nest.Name pattern; no compound type names. | Tags must nest *under* `Either`, e.g. `Either.Map`, `Either.Swap`. |
| [API-NAME-002] | No compound method/property names. | Bans `mapLeft`, `mapRight`, `bimap`, `mapBoth`, `flatMapLeft`, etc. |
| [API-NAME-008] | Multi-form → Property.View; single-form → labeled method. | Decides between `either.map.left { }` and `either.map(left: )`. |
| [API-ERR-001] | Typed throws required. | Every transform closure must accept `(T) throws(E) -> U` and propagate `E`. |
| [API-IMPL-005] | One type per file. | Tag enums and Either itself must split across files. |
| [API-IMPL-008] | Minimal type body. | All methods in extensions; type body holds only cases. |
| [API-IMPL-012] | Closure parameters trail the signature. | `bimap(left: f, right: g)` already complies. |
| [IMPL-INTENT] | Code reads as intent, not mechanism. | The chosen shape must be a *what*, not a *how*. |
| [IMPL-020] | Verb-as-property + `callAsFunction` for tag types. | Available if Property.View is chosen. |
| [IMPL-021] | Use `Property.Inout` / `Property.Borrow` for `~Copyable` bases; `Property` / `Property.Typed` for `Copyable`. | Selects the right variant. |
| [IMPL-023] | Core logic in static methods; instance methods delegate. | Static layer can keep compound names per [IMPL-024]. |
| [IMPL-024] | Compound identifiers permitted at the static layer; banned in public instance API. | Lets `Either.mapLeft` (static) survive while `instance.mapLeft` cannot. |
| [PRP-002] | Tags are empty enums nested in the container. | `extension Either { enum Map {} }`. |
| [PRP-003] | `typealias Property<Tag>` scoped to the container. | `extension Either { typealias Property<Tag> = Property_Primitives.Property<Tag, Either<Left, Right>> }`. |
| [PRP-005] | Method extensions use `Property<Tag>`. | Closure-taking `func left { }` lives on `Property` where `Tag == Either<…>.Map`. |
| [PRP-006] | Property extensions needing `Element` use `Property<Tag>.Typed<Element>`. | Two element-like generics (`Left`, `Right`) — `.Typed` does not directly fit. |
| [PRP-013] | Accessor names follow [API-NAME-002] in consumer code too. | Cannot fall back to `.mapped.left { }` or `.transformed.left { }` if those are compounds in disguise. |

Forward-compatibility constraint: the chosen shape MUST survive a future
`Either: ~Copyable` migration without breaking call sites. A shape that uses
`var left: Left?` is fine (it can become `consuming` later); a shape that
returns a `Property.Borrow` requires no change because `Property.Borrow` is
already `~Copyable` and `~Escapable`.

## Existing Call Sites Inventory

I exhaustively grepped `swift-primitives`, `swift-foundations`, and
`swift-standards` for `Either<…>`, `.mapLeft`, `.mapRight`, `.bimap`,
`.swapped`, `\.left`, and `\.right` accessor uses. The result:

### Type usages — high

| Site | File | Form |
|------|------|------|
| `Parser.Map.Throwing.Failure` | `swift-parser-primitives/Sources/Parser Map Primitives/Parser.Map.Throwing.swift:36` | `typealias Failure = Either<Upstream.Failure, E>` |
| `Parser.Skip.First.Failure` | `swift-parser-primitives/Sources/Parser Skip Primitives/Parser.Skip.First.swift:31` | `typealias Failure = Either<P0.Failure, P1.Failure>` |
| `Parser.Skip.Second.Failure` | `swift-parser-primitives/Sources/Parser Skip Primitives/Parser.Skip.Second.swift:31` | same shape |
| `Parser.First.Where.Failure` | `swift-parser-primitives/Sources/Parser First Primitives/Parser.First.Where.swift:34` | `typealias Failure = Either<Parser.EndOfInput.Error, Parser.Match.Error>` |
| `Parser.Byte.Failure` | `swift-parser-primitives/Sources/Parser Byte Primitives/Parser.Byte.swift:29` | same |
| `Pool.Bounded.Acquire(asyncBody:)` | `swift-pool-primitives/Sources/Pool Bounded Primitives/Pool.Bounded.Acquire.swift:90` | `async throws(Either<Pool.Lifecycle.Error, E>)` |
| `Async.Semaphore.withPermit(_:)` | `swift-async-primitives/Sources/Async Semaphore Primitives/Async.Semaphore+WithPermit.swift:39` | `async throws(Either<Async.Semaphore.Error, E>)` |
| `POSIX.Kernel.File.Handle.writeAll(_:)` | `swift-foundations/swift-posix/Sources/POSIX Kernel File/POSIX.Kernel.File.Handle.writeAll.swift:52,99` | `throws(Either<Error, Interrupt>)` |
| `Binary.ASCII.Access(whole:)` | `swift-foundations/swift-ascii/Sources/ASCII/Binary.ASCII.Access+whole.swift:7,12,22` | `throws(Either<P.Failure, Binary.ASCII.Parsing.Error>)` |
| `Binary.Parse.Access(whole:)` | `swift-binary-parser-primitives/Sources/Binary Parse Primitives/Binary.Parse.Access+whole.swift:8,12` | `throws(Either<P.Failure, Binary.Parse.Error>)` |
| `Tests.History.Storage…` | `swift-foundations/swift-tests/Sources/Tests Performance/Tests.History.Storage.swift:180` | `async throws(Either<IO.Blocking.Error, Error>)` |
| `Tests.Complexity.Baseline+Storage` | `swift-foundations/swift-tests/Sources/Tests Performance/Tests.Complexity.Baseline+Storage.swift:165` | same |
| `Parsers.Separated.Failure` | `swift-foundations/swift-parsers/Sources/Parsers/Parsers.Separated.swift:94` | `typealias Failure = Either<…>` |
| `Parsers.Between.Failure` | `swift-foundations/swift-parsers/Sources/Parsers/Parsers.Between.swift:78,79,180,181` | nested `Either` |

### `.left(...)` / `.right(...)` constructor usages — high

Constructors are everywhere. Each parser-primitives parser that maps two error
domains throws `.left(error)` / `.right(error)` (`Parser.First.Where.swift:39,43`,
`Parser.Skip.First.swift:38,43,58,63`, `Parser.Skip.Second.swift:39,44,60,65`,
`Parser.Byte.swift:34,38`, `Parser.Take.Two.swift:40,46,75,80`,
`Parser.Conditional.swift:36,42,59,65`, `Parser.Map.Throwing.swift:44,49`,
`Parser.Literal.swift:48,52`, `Parser.Filter.swift:45,48`,
`Parser.Protocol+parse.swift:20,23`, `Binary.ASCII.Parsing.Whole+call.swift:14,19`).

### Functor-method usages — **zero in production code**

| Method | Production call sites | Test call sites | Doc/example mentions |
|--------|-----------------------|-----------------|----------------------|
| `Either.mapLeft` | 0 | 0 | 0 |
| `Either.mapRight` | 0 | 0 | 0 |
| `Either.bimap` | 0 | 0 | `swift-either-primitives/README.md:34` (illustrative example only) |
| `Either.map` | 0 in production; `Either Tests.swift:31,42` | 2 | README/example uses |
| `Either.swapped` | 0 | `Either Tests.swift:18-26` (one assertion site) | `swift-either-primitives/README.md:20`, `Either.swift:16` |
| `Either.value` (Never elim.) | 0 | `Either Tests.swift:51-54` | doc |

### Pair (companion type, same anti-pattern)

`swift-pair-primitives` ships `mapFirst`, `mapSecond`, `bimap` plus
`swapped()` and `apply` on the `~Copyable` static layer. Tests at
`swift-pair-primitives/Tests/Pair Primitives Tests/Pair Tests.swift:58-141,235-260`
exercise all three compound names (`mapFirst`, `mapSecond`, `bimap`) and the
README at `swift-pair-primitives/README.md:7,22,42,77` and DocC at
`swift-pair-primitives/Sources/Pair Primitives/Pair Primitives.docc/Pair Primitives.md:19`
advertise them. The Pair anti-pattern mirrors Either's exactly; the migration
work is parallel.

### Field summary

* **Type-level usage (`Either<L, R>` in `throws(...)` and `typealias Failure`) is heavy** — 14+ call sites across 7 packages.
* **Constructor usage (`.left(...)` / `.right(...)`) is heavy** — 24+ call sites.
* **Case-pattern destructuring (`case .left(let x)` / `case .right(let x)`) is heavy** — every parser test and every `do throws(Either<…>) … catch` block.
* **Functor-method usage is zero** outside Either's own tests and docs.

This is **the load-bearing fact** for the design recommendation. The functor
methods are decoration around a type that is used overwhelmingly via:

1. Constructors (case-name on the type).
2. Pattern matching (case-name in `switch` / `if case`).
3. Conditional `Error` conformance to feed `throws(Either<L, R>)`.

Migration cost of renaming `mapLeft` / `mapRight` / `bimap` is therefore
**zero outside the package**. Every consumer cited above continues to compile
without change. Only the test file
`swift-either-primitives/Tests/Either Primitives Tests/Either Tests.swift`,
the package README, and the doc comments need updating.

## Analysis

Five concrete API shape options for the four operations under question
(`map(right)`, `map(left)`, `bimap`, `fold` — plus the trivial `swapped`,
`left`, `right`, `value`).

### Option A: Property.Inout namespace `either.map.left { }` / `either.map.right { }`

Multi-form Property.Inout pattern matching the
`buffer.insert.front(_:)` / `array.forEach { }` ecosystem precedent.

#### Call sites

```swift
let success: Either<String, Int> = .right(42)

let doubled = success.map.right { $0 * 2 }                 // .right(84)
let labelled = success.map.left { ($0, lineNumber) }       // .left(("not found", 7))
let widened = success.map.both(left: { ($0, 7) },
                                right: { Double($0) })

let collapsed = success.fold(left: handleLeft,
                              right: handleRight)
let flipped = success.swap                                  // <— see Option D below
```

#### Implementation skeleton

```swift
// Either+Map.swift  (one file per API-IMPL-005)
extension Either {
    public enum Map {}

    public typealias Property<Tag> = Property_Primitives.Property<Tag, Either<Left, Right>>
}

extension Either {
    /// Map namespace — see `.map.left { }` / `.map.right { }` / `.map.both(...)`.
    public var map: Property<Map> {
        _read { yield Property<Map>(self) }
        _modify {
            var property: Property<Map> = .init(self)
            self = .right(_unreachable)        // ← problem: cannot fabricate a value
            defer { self = property.base }
            yield &property
        }
    }
}

extension Property where Tag == Either<Left, Right>.Map,
                         Base == Either<Left, Right> {
    @inlinable
    public mutating func left<NewLeft, E: Swift.Error>(
        _ transform: (Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> {
        try Either.mapLeft(base, transform: transform)   // static layer keeps compound name
    }

    @inlinable
    public mutating func right<NewRight, E: Swift.Error>(
        _ transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        try Either.map(base, transform: transform)
    }

    @inlinable
    public mutating func both<NewLeft, NewRight, E: Swift.Error>(
        left lf: (Left) throws(E) -> NewLeft,
        right rf: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> {
        try Either.bimap(base, left: lf, right: rf)
    }
}
```

#### Pros

* Mirrors `array.forEach { }`, `buffer.insert.front(_:)`,
  `container.remove.last()` — established multi-form precedent.
* `.map.left` / `.map.right` / `.map.both` reads as intent — the namespace
  groups three related sub-operations.
* The Property.Inout type carries `~Copyable` and `~Escapable` already;
  forward-compatible with a future `~Copyable` Either.
* Tag (`Either.Map`) is reusable — adding a hypothetical
  `.map.contramap { }` later is a one-line extension.

#### Cons

* **The CoW recipe ([PRP-007]) does not fit `Either`.** The recipe needs a
  cheap "empty self" sentinel (e.g., `Stack()`); `Either<Left, Right>` has no
  such value because `.left` and `.right` both demand a payload. Step 3
  ("self = ZeroValue") is unreachable. The same recipe is also unnecessary
  here — `Either` is not a CoW container, it is a tagged scalar — but the
  recipe's machinery is what makes `Property` ergonomic.
* The `_modify` accessor on a non-CoW value type is a coroutine yielding
  `&property`, which means callers can in principle re-assign the inner base
  through `property.base = .left(...)`. Tagged scalars do not benefit from
  yield-then-restore — there is no shared storage to preserve.
* The methods on `Property` end up `mutating` for the same reason `Buffer.Linear.insert.front(_:)`
  is mutating — `Property.Inout` over a `~Copyable` base requires `&self`.
  But Either is `Copyable` today, so a Copyable Property is technically
  enough; that pulls in `Property<Tag>` (the Copyable variant), which means
  the methods need not be `mutating` — the `_modify` recipe can degenerate
  to "construct, return". Still, this is two distinct shapes to maintain
  (Copyable today, `~Copyable` tomorrow).
* Property.Inout's `_modify` body must call `Property<Map>.Inout(&self)` —
  Either is a frozen enum, taking `&self` is fine, but the resulting accessor
  is a mutable reference on a non-mutable operation (mapping is pure).
  Reads like mechanism, not intent.
* `.map.both(left:, right:)` is morally `bimap` with a different shape; the
  qualifier `both` exists because `.map(left:, right:)` would clash with
  `.map.left` / `.map.right` (see Option C). On the Property-only design
  there is no other `.map(...)` shape, so `.map.both` is the only `.map`
  three-arg form available — it is just heavier syntax for the same call.
* Discoverability via autocomplete is *worse*, not better. The user types
  `either.map` and gets a `Property<Map>` value back; only by typing `.`
  again do they see `left`, `right`, `both`. The labeled-method form
  (`either.map(`) reveals all three signatures via Xcode argument labels
  immediately.
* Adds a non-trivial dependency: `swift-either-primitives` would need to
  depend on `swift-property-primitives` (a small package — single-file core
  plus four variants — but a new transitive dep for every consumer).

### Option B: Labeled-method overloads `either.map(left: )` / `either.map(right: )` / `either.map(left:, right:)`

Single-form pattern matching `swap(at:, with:)` from [API-NAME-008].

#### Call sites

```swift
let success: Either<String, Int> = .right(42)

let doubled = success.map(right: { $0 * 2 })                       // .right(84)
let labelled = success.map(left: { ($0, lineNumber) })             // .left(("not found", 7))
let widened = success.map(left: { ($0, 7) },
                           right: { Double($0) })

let collapsed = success.fold(left: handleLeft,
                              right: handleRight)
let flipped = success.swap                                          // <— see Option D below
```

#### Implementation skeleton

```swift
// Either+Map.swift
extension Either {
    @inlinable
    public func map<NewRight, E: Swift.Error>(
        right transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        try Self.map(self, right: transform)
    }

    @inlinable
    public func map<NewLeft, E: Swift.Error>(
        left transform: (Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> {
        try Self.map(self, left: transform)
    }

    @inlinable
    public func map<NewLeft, NewRight, E: Swift.Error>(
        left lf: (Left) throws(E) -> NewLeft,
        right rf: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> {
        try Self.map(self, left: lf, right: rf)
    }
}

// Static layer (the [IMPL-024]-permitted compound layer remains private/internal
// to the package; callers see only the labeled instance API):
extension Either {
    @inlinable
    public static func map<NewRight, E: Swift.Error>(
        _ either: Either,
        right transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> { /* switch on either */ }

    // Same for `left:` and `left:right:` — three statics, three instances.
}
```

#### Pros

* **Single identifier `map`** at the use site. The overloads share the verb;
  the labels disambiguate the operand. Reads as `map(left:)` ≡ "map the left
  side", `map(right:)` ≡ "map the right side", `map(left:, right:)` ≡ "map
  both sides" — the labels carry the intent.
* No new dependency on `swift-property-primitives`. Either remains a
  single-file primitive (one file per [API-IMPL-005] for the type body, plus
  extension files).
* Argument-label autocomplete in Xcode shows all three overloads as soon as
  the user types `either.map(`. Discovery is at the call site, not behind a
  property-getter wall.
* The labels `left:` / `right:` are spec-mirroring — they match the case
  names exactly. There is no name collision: a labeled-argument named
  `left` is parser-distinguishable from a case named `.left`. Swift permits
  identical names across the case / argument-label namespaces.
* Closure-last per [API-IMPL-012] — single-closure forms have one trailing
  closure; the two-closure form labels both per [API-IMPL-013] (`left: { }
  right: { }` lifecycle order is "left then right", matching the type
  parameter order).
* Forward-compatible with `~Copyable`: when Either becomes
  `~Copyable`, the methods become `consuming` and the closures take
  `consuming Left` / `consuming Right`. The labels and overload structure
  are unchanged.
* Migration cost: ten-line patch to the test file plus README/doc updates.
  Production consumers continue to compile.
* Static layer keeps `mapLeft` / `bimap` / `map` per [IMPL-024] — no
  recursive-overload risk because the instance methods delegate to statics
  on `Self`, not `self`.

#### Cons

* The labels duplicate type-parameter names (`Left` → `left:`, `Right` → 
  `right:`). For someone trained on Haskell `bimap` or Rust `map_left`, the
  shape `map(left:)` is mildly novel — they are used to seeing the verb-noun
  compound. (This is the *reason* the rule exists; it is not a real con.)
* `map(left:, right:)` and `map(right:, left:)` are *not* equivalent
  invocations under Swift's argument-label model; the order shown in the
  declaration is the order at the call site. The convention should be
  alphabetical `left` then `right` (which also matches the type parameter
  order `Either<Left, Right>` and the case order `.left` then `.right`).
* No clear extensibility for a hypothetical "transform left into right" or
  "transform right into left" cross-coupling — but those are not standard
  bifunctor operations; they would deserve their own verbs (`reduce`, `fold`)
  not a `.map` overload.

### Option C: Hybrid — Property.Inout `.map.left { }` AND labeled `.map(left:)`

Both shapes coexist on the same `map` identifier. Either user writes
`either.map.left { }` (property-then-method chain) or `either.map(left: { })`
(direct labeled method).

#### Compiler behavior

In Swift, a property and a method with the same base name on the same type
are permitted *only if* the method has at least one argument label that
disambiguates parsing. `var map: Property<Map>` and
`func map(left: ...) -> ...` syntactically resolve at the call site:

* `either.map` → property reference (yields `Property<Map>`).
* `either.map(left:` → method call with argument label.
* `either.map { }` → ambiguous — parses as the property reference followed
  by trailing-closure application, which fails because `Property<Map>` is not
  callable. So the bare-trailing-closure form is unavailable; the user must
  write `either.map(left: { … })` with the label.

This works on paper but is genuinely confusing. The same `either.map`
prefix can resolve to either a property or a method depending on what
follows. Swift's overload resolution is up to the task; readers are not.

#### Pros

* Both styles available; no need to pick.
* Migration deferral — early consumers can use whichever shape they prefer.

#### Cons

* **Two ways to do the same thing** — violates [IMPL-INTENT] indirectly (the
  surface ceases to be a single readable shape) and routinely produces
  inconsistent call sites across the codebase.
* The hybrid carries the worst of both: the Property.Inout dependency *and*
  the labeled-method API surface to maintain.
* Documentation has to teach both forms.
* Future deprecation of one form is harder than ever picking.

This option is included for completeness; it is not a serious contender.

### Option D: Labeled methods + bare property/method accessors for trivial ops

The labeled-method body of Option B, with the trivial operations
(`swapped`, `value`, `left`, `right`) reshaped from "var" or "compound name"
to bare verbs:

| Current | Option D |
|---------|----------|
| `var swapped: Either<R, L>` | `func swap() -> Either<R, L>` (or `.swap` as method) |
| `var value: Right where Left == Never` | `func unwrap() -> Right` or `.right!` (precondition) |
| `var left: Left?` | unchanged — case-named accessor |
| `var right: Right?` | unchanged — case-named accessor |

#### Rationale for the changes

* `var swapped` reads as a stored property of an immutable form; in fact it
  is a pure function returning a new value with a different generic type.
  Calling it `swap()` is closer to intent (action) than mechanism (lookup).
  However, `swap` as a verb at instance level is also easy to confuse with
  `Swift.swap(_:_:)`'s in-place exchange. Renaming to `swapped()` (verb-as-
  past-participle) preserves the immutable-function meaning and clears the
  in-place confusion.
* `var value: Right where Left == Never` is correct under [API-NAME-002]
  (single-word property). `unwrap()` would be a step backward (less explicit).
  `.value` stays.
* `var left: Left?` and `var right: Right?` are case-name accessors. They
  are NOT compound; `left` and `right` are the case names. The expansion
  `var left: Left?` reads as "if-this-is-the-left-case, the value". This is
  spec-mirroring per [API-NAME-003] (the cases are the spec terms).

The set of changes for trivial ops is small enough that Option D is not a
distinct shape from Option B — it is Option B with a polished trivial-ops
layer. We treat it as the *full* Option B in the recommendation.

### Option E: `Property.Borrow` (read-only) for the functor surface

A read-only namespace pattern. Methods on `Property.Borrow` produce *new*
`Either` values without yielding any mutable view of `self`:

```swift
extension Either {
    public enum Map {}
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Either<Left, Right>>

    public var map: Property<Map>.Borrow {
        _read { yield Property<Map>.Borrow(self) }
    }
}

extension Property.Borrow where Tag == Either<Left, Right>.Map,
                                 Base == Either<Left, Right> {
    @inlinable
    public func right<NewRight, E: Swift.Error>(
        _ transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> { /* … */ }

    @inlinable
    public func left<NewLeft, E: Swift.Error>(
        _ transform: (Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> { /* … */ }

    @inlinable
    public func both<NewLeft, NewRight, E: Swift.Error>(
        left lf: (Left) throws(E) -> NewLeft,
        right rf: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> { /* … */ }
}
```

#### Pros

* No mutation involved — pure read of `self`, then construct a new value.
* Compiles for `let`-bound Either values today and after a
  `~Copyable` migration tomorrow (per [PRP-009]).
* Avoids the CoW-recipe mismatch from Option A — `Property.Borrow` does not
  use the `_modify` recipe.

#### Cons

* Same dependency cost as Option A.
* Same discoverability cost as Option A — autocomplete user has to type
  `either.map.` to see the three forms.
* Adds a layer of indirection (Property.Borrow wrapping Either, then methods
  on the wrapper) for what is morally three labeled overloads on a single
  verb. The indirection pays no rent — there are no other accessors that
  would want the `.map` namespace, so the namespace contains exactly three
  inhabitants and the property wrapper exists only to hold them.
* Per [IMPL-084] / [API-NAME-001a], a single-inhabitant namespace is a
  variant label and SHOULD nest under its parent rather than exist as a
  standalone namespace. `Either.Map` exists exclusively to discriminate
  three closely-related operations under the same verb; nothing else will
  ever live under `Either.Map`. The single-inhabitant rule pushes against
  the namespace.

### Comparison

| Criterion | A: Property.Inout `.map.{left,right,both}` | B: Labeled overloads `.map(left:/right:/left:right:)` | C: Hybrid | D: B + polished trivial ops | E: Property.Borrow `.map.{...}` |
|-----------|---|---|---|---|---|
| [API-NAME-002] compliance | Y | Y | Y | Y | Y |
| [API-NAME-008] decision rule fit | Multi-form (3 sub-ops) — Property.Inout is the *book answer* but the sub-ops are not parameter-distinguished, they are unary closures of distinct types. | Single-form (one verb `map`, three label combinations) — labels disambiguate. The book answer for "one operation, disambiguated by labels". | Mixed — explicitly forbidden by the rule's spirit ("MUST use one or the other"). | Same as B. | Same as A. |
| [IMPL-INTENT] readability | "map.left { }" reads as intent. "map.both(left:, right:)" reads less cleanly than "map(left:, right:)". | `map(left:)`, `map(right:)`, `map(left:, right:)` all read as intent. Argument labels carry meaning. | Two readings — undermines single-source intent. | Same as B. | Same as A. |
| Argument-label discoverability (Xcode/SourceKit autocomplete) | After typing `.map`, IDE shows the property — user must dot again to see methods. Two-step disclosure. | Typing `.map(` reveals all three overloads as label sets. One-step. | Both modes; user picks. | Same as B. | Same as A. |
| `~Copyable` forward-compat | Already uses `~Copyable` `Property.Inout` — natively forward-compat. | `consuming func map(...)` works equally well; no shape change. | Both work. | Same as B. | Already uses `~Copyable` `Property.Borrow`. |
| Typed-throws preservation | Methods on `Property` are generic over `E`; works. | Direct overloads are generic over `E`; works (status quo). | Both work. | Same as B. | Methods on `Property.Borrow` are generic over `E`; works. |
| New dependency cost | +`swift-property-primitives` (small, but new transitive). | None. | +`swift-property-primitives`. | None. | +`swift-property-primitives`. |
| File count | +tag enum file, +Property extension file → 4 files. | 1 method file (`Either+Map.swift`). | 5+ files. | Same as B. | Same as A. |
| Migration cost from current API | Test rewrite; README/DocC rewrite; test of `_modify` recipe behavior; new dependency. | Test rewrite; README/DocC rewrite. **Smallest diff**. | Largest diff (both layers). | Same as B. | Same as A but without `_modify` recipe. |
| Pair migration parallelism | A on Pair would face the same CoW-recipe mismatch. | B on Pair is a clean rename (`mapFirst` → `map(first:)`, `mapSecond` → `map(second:)`, `bimap(first:, second:)` → `map(first:, second:)`). Identical structure. | — | — | E on Pair is feasible (Pair is `~Copyable`). |
| CoW-recipe fit | Mismatch — `Either` has no zero value. The recipe is unnecessary, but the Property variant most consumers see (`Property.Inout` for `~Copyable`, `Property` for Copyable) is built around it. | Recipe not used — irrelevant. | Mismatch in the Property branch. | Recipe not used. | No `_modify` recipe needed (`Property.Borrow` is read-only). |
| Single-inhabitant namespace risk ([API-NAME-001a]) | High — `Either.Map` has no other reason to exist. | None. | High. | None. | High. |
| Total weight | Heavy machinery, mixed fit | Lightweight, native fit | Avoided by all parties | Same as B | Heavy machinery, slightly better fit than A |

## Recommendation

**Adopt Option D — labeled-method overloads with polished trivial-ops layer**.

### Why

The decision pivots on three load-bearing facts.

1. **The functor surface is single-form, not multi-form.** [API-NAME-008]'s
   decision rule asks: are there 2+ related sub-operations under one root
   noun? On Either, the answer is "no" in the structural sense the rule
   intends. The "sub-operations" are not three different verbs grouped under
   `map` — they are three *parameterizations* of the same verb. The rule's
   own worked examples are
   `swap(at:, with:)` (single-form) and `remove.{first, last, all}`
   (multi-form). `map(left: f)` / `map(right: g)` / `map(left: f, right: g)`
   reads as the former (one operation, disambiguated by which side(s) get
   transformed), not the latter (three different actions sharing a root).
   The rule's procedure step 2 is "one operation, disambiguated by argument
   labels → Direct labeled method". That fits exactly.

2. **Production-side migration cost is zero.** The exhaustive grep above
   found zero call sites for `mapLeft`, `mapRight`, or `bimap` in production
   code across `swift-primitives`, `swift-foundations`, and
   `swift-standards`. Every consumer uses Either as a *type* in
   `throws(...)` clauses and constructs / pattern-matches values via
   `.left(...)` / `.right(...)`. The functor methods are tested but not
   used. Renaming them in this package costs three test rewrites, a README
   patch, and a doc-comment refresh.

3. **Property.Inout's CoW recipe ([PRP-007]) does not fit `Either`.** The
   recipe needs a sentinel "empty" value (e.g. `Stack()`) to assign to `self`
   between transfer and yield. `Either<Left, Right>` has no inhabitable
   default — both cases require a payload. The recipe is also unnecessary
   for a non-CoW value type, but the absence is a smell: the `Property`
   pattern was designed for CoW containers and `~Copyable` resource types
   where shared backing storage benefits from yield-then-restore. Either is
   a tagged scalar; mapping it produces a brand-new value with possibly-
   different generic parameters. Forcing it through `Property.Inout` adds
   ceremony around an operation that is morally a pure function of `(Either, transform) -> Either'`.

   Per [RES-022] (structural correctness over diff-size), Option B is *also*
   the structurally-correct choice — the diff size happens to align with
   the structural argument, not against it.

### Full public API sketch

```swift
// File: Sources/Either Primitives/Either.swift
// Type body — minimal per [API-IMPL-008].

@frozen
public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

// File: Sources/Either Primitives/Either+Conformances.swift

extension Either: Sendable where Left: Sendable, Right: Sendable {}
extension Either: Equatable where Left: Equatable, Right: Equatable {}
extension Either: Hashable where Left: Hashable, Right: Hashable {}
#if !hasFeature(Embedded)
extension Either: Codable where Left: Codable, Right: Codable {}
#endif
extension Either: Swift.Error where Left: Swift.Error, Right: Swift.Error {}

// File: Sources/Either Primitives/Either+Map.swift
// Functor surface — three overloads on `map`.

extension Either {

    /// Transforms the right component while preserving the left.
    ///
    /// ```swift
    /// let success: Either<String, Int> = .right(42)
    /// let doubled = success.map(right: { $0 * 2 })   // .right(84)
    /// ```
    @inlinable
    public func map<NewRight, E: Swift.Error>(
        right transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        try Self.map(self, right: transform)
    }

    /// Transforms the left component while preserving the right.
    ///
    /// ```swift
    /// let failure: Either<String, Int> = .left("not found")
    /// let labelled = failure.map(left: { ($0, 7) })  // .left(("not found", 7))
    /// ```
    @inlinable
    public func map<NewLeft, E: Swift.Error>(
        left transform: (Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> {
        try Self.map(self, left: transform)
    }

    /// Transforms both components.
    ///
    /// ```swift
    /// let widened = either.map(
    ///     left:  { ($0, lineNumber) },
    ///     right: { Double($0) }
    /// )
    /// ```
    @inlinable
    public func map<NewLeft, NewRight, E: Swift.Error>(
        left  leftTransform:  (Left)  throws(E) -> NewLeft,
        right rightTransform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> {
        try Self.map(self, left: leftTransform, right: rightTransform)
    }
}

// File: Sources/Either Primitives/Either+Map+Static.swift
// Static layer — compound names permitted per [IMPL-024].
// Internal-to-package; consumers see only the labeled instance API.

extension Either {

    @inlinable
    public static func map<NewRight, E: Swift.Error>(
        _ either: Either,
        right transform: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<Left, NewRight> {
        switch either {
        case .left(let l):  .left(l)
        case .right(let r): try .right(transform(r))
        }
    }

    @inlinable
    public static func map<NewLeft, E: Swift.Error>(
        _ either: Either,
        left transform: (Left) throws(E) -> NewLeft
    ) throws(E) -> Either<NewLeft, Right> {
        switch either {
        case .left(let l):  try .left(transform(l))
        case .right(let r): .right(r)
        }
    }

    @inlinable
    public static func map<NewLeft, NewRight, E: Swift.Error>(
        _ either: Either,
        left  lf: (Left)  throws(E) -> NewLeft,
        right rf: (Right) throws(E) -> NewRight
    ) throws(E) -> Either<NewLeft, NewRight> {
        switch either {
        case .left(let l):  try .left(lf(l))
        case .right(let r): try .right(rf(r))
        }
    }
}

// File: Sources/Either Primitives/Either+Fold.swift
// Per the prior research, fold is added now.

extension Either {

    /// Eliminates the `Either` by handling both cases, producing a single value.
    ///
    /// `fold` is the universal property of the coproduct: given handlers for
    /// each case, it produces a `Result` independent of which case held.
    ///
    /// ```swift
    /// let message = result.fold(
    ///     left:  { walkError in describe(walkError) },
    ///     right: { userError in describe(userError) }
    /// )
    /// ```
    @inlinable
    public func fold<Result, E: Swift.Error>(
        left  leftHandler:  (Left)  throws(E) -> Result,
        right rightHandler: (Right) throws(E) -> Result
    ) throws(E) -> Result {
        try Self.fold(self, left: leftHandler, right: rightHandler)
    }

    @inlinable
    public static func fold<Result, E: Swift.Error>(
        _ either: Either,
        left  lh: (Left)  throws(E) -> Result,
        right rh: (Right) throws(E) -> Result
    ) throws(E) -> Result {
        switch either {
        case .left(let l):  try lh(l)
        case .right(let r): try rh(r)
        }
    }
}

// File: Sources/Either Primitives/Either+Swap.swift

extension Either {

    /// Returns the either with components swapped.
    ///
    /// ```swift
    /// let original: Either<String, Int> = .right(42)
    /// let flipped:  Either<Int, String> = original.swapped()  // .left(42)
    /// ```
    @inlinable
    public func swapped() -> Either<Right, Left> {
        Self.swapped(self)
    }

    @inlinable
    public static func swapped(_ either: Either) -> Either<Right, Left> {
        switch either {
        case .left(let l):  .right(l)
        case .right(let r): .left(r)
        }
    }
}

// File: Sources/Either Primitives/Either+Accessors.swift
// Case-name accessors — NOT compound (they mirror the case names directly).

extension Either {

    /// The left value, or `nil` if this is a right.
    @inlinable
    public var left: Left? {
        switch self {
        case .left(let l):  l
        case .right:        nil
        }
    }

    /// The right value, or `nil` if this is a left.
    @inlinable
    public var right: Right? {
        switch self {
        case .left:          nil
        case .right(let r):  r
        }
    }
}

// File: Sources/Either Primitives/Either+Never.swift
// Never elimination — unconditional extraction when one side is uninhabited.

extension Either where Left == Never {

    /// The right value, extractable unconditionally because the left is uninhabited.
    @inlinable
    public var value: Right {
        switch self {
        case .right(let r): r
        }
    }
}

extension Either where Right == Never {

    /// The left value, extractable unconditionally because the right is uninhabited.
    @inlinable
    public var value: Left {
        switch self {
        case .left(let l): l
        }
    }
}
```

### Decisions catalogue

The seven sub-questions resolve as:

| # | Question | Resolution |
|---|----------|------------|
| 1 | Property.View namespace shape (`.map.left { }`)? | **Rejected.** Property.View is the multi-form choice; Either's functor surface is single-form (one verb, label-disambiguated). Adds dependency on `swift-property-primitives` for zero call-site benefit. CoW recipe does not fit. |
| 2 | Labeled-method shape (`.map(left:, right:)`)? | **Adopted** as the public functor surface. Labels mirror case names; argument-label autocomplete reveals all three overloads on `.map(`. |
| 3 | Hybrid (Property.View + labeled)? | **Rejected.** Two ways to do the same thing; sleights with property-vs-method ambiguity that confuse readers. |
| 4 | Swap, fold, accessors? | `func swapped()` (method, not property — pure transformation reads as action). `func fold(left:, right:)` added per the prior research. `var left: Left?` / `var right: Right?` retained — they mirror case names, not compounds. |
| 5 | Never-elimination accessor? | `var value` retained on both `where Left == Never` and `where Right == Never`. Single-word property; no [API-NAME-002] issue. A separate accessor namespace (`either.unwrap.value` or similar) would be Property.View ceremony for a single inhabitant — rejected by [API-NAME-001a]. |
| 6 | Static-dispatch layer? | Static layer keeps the same labeled overloads as the instance layer. Compound static names (e.g., `mapLeft`) are PERMITTED per [IMPL-024] but not REQUIRED; using the same labeled shape at both layers makes the delegation invisible and avoids dual vocabulary. |
| 7 | Existing call sites? | No production code calls `mapLeft` / `mapRight` / `bimap`. Migration touches only tests, README, and doc comments inside `swift-either-primitives`. |

## Migration

### Files affected

| File | Change | LOC delta |
|------|--------|-----------|
| `Sources/Either Primitives/Either.swift` | Split into multiple files per [API-IMPL-005]; remove `mapLeft` / `mapRight` / `bimap`; add labeled `map` overloads, `func swapped()`, `func fold(...)`. | ~+50 / ~-90 net |
| `Tests/Either Primitives Tests/Either Tests.swift` | Update test for `swapped` to `swapped()`; tests for `map` already test labeled form (right-side default). Add tests for `map(left:)`, `map(left:, right:)`, `fold(left:, right:)`. | +60 / -2 |
| `README.md` | Update three example blocks. | +3 / -3 |
| Doc comments inside Either source | Update to use new shape. | small |
| Production consumers (any package importing Either) | **No changes.** All current usage is type-level (`Either<L, R>` in `throws(...)`) and constructor-level (`.left(...)` / `.right(...)`). | 0 |

### Deprecation shims

A single-package, pre-1.0 primitive can break its API freely. There is no
need for `@available(*, deprecated, renamed: "map(left:)")` annotations on
`mapLeft`, `mapRight`, `bimap`, `swapped` (the var). The package is
unreleased outside the institute monorepo; the rename is safe.

If, at the time of public release, ecosystem callers exist that rely on the
old shape, deprecation shims can be added at that point with a 1-cycle
removal window. None exist today.

### Pair parallel work (out of scope, noted for coordination)

`swift-pair-primitives` ships the same anti-pattern (`mapFirst`,
`mapSecond`, `bimap`) and SHOULD migrate in lockstep. The migration is
mechanical:

| Pair (current) | Pair (after) |
|----------------|---------------|
| `pair.mapFirst { }` | `pair.map(first: { })` |
| `pair.mapSecond { }` | `pair.map(second: { })` |
| `pair.bimap(first:, second:)` | `pair.map(first:, second:)` |
| `pair.swapped()` | `pair.swapped()` (already a method — unchanged) |
| `pair.apply { }` | `pair.apply { }` (unchanged — single-form already) |

Pair has 16 test sites that exercise the compound names plus README and DocC
mentions. None are production call sites either; the cost mirrors Either's.

## Loose Ends / Open Questions

Per [RES-027], distinguishing premises (need follow-up) from directions
(informational).

### Premises

1. **The single-form-vs-multi-form classification of `map` over Either.** The
   recommendation hinges on classifying `.map(left:)` / `.map(right:)` /
   `.map(left:, right:)` as a single-form set under one verb. A dissenting
   reading is: "left", "right", "both" *are* three sub-operations under the
   `map` root, parametrized by which side gets transformed; therefore
   multi-form. Both readings are coherent in isolation; the structural
   argument tips toward single-form because the underlying transform is the
   *same* operation (apply the closure to whichever case held; pass through
   the other) — only the *parameter list* changes, not the verb. If the
   reading flips, Option A or E is the answer.
   *Empirical test for follow-up*: at the next adoption site that calls a
   functor method on `Either`, observe which form reads cleaner in
   production code. If consumers consistently bind a label
   (`map(right: handle)`) that reads as parameterization, single-form is
   confirmed.

2. **`swapped` as method (`func swapped()`) vs property (`var swapped`).**
   The current shape is `var swapped: Either<R, L>`. Recommended is
   `func swapped()`. The argument is "swap is a transformation, not a
   stored attribute". The counter-argument is "a non-throwing pure read of
   `self` reads as a property; methods imply effects". Pair already uses
   `func swapped()` for its `~Copyable` static plus instance methods (under
   `where First: ~Copyable, Second: ~Copyable`); the Copyable instance
   convenience there does NOT have `swapped` as a property — it is a method
   too. So the cross-package convention already leans method. Recommend
   method; revisit if a strong principal counter-argument lands.

### Directions

3. **`flatMap` (monadic bind).** The 2026-03-19 research deferred `flatMap`
   "until a concrete use case demands it". If a use case lands, the same
   labeled-method shape applies: `either.flatMap(right: { … }) -> Either<Left, Other>`
   and dual `flatMap(left: { … })`. No new shape to design.

4. **`~Copyable` Either.** Phase 4 of the prior research. The labeled
   methods become `consuming` and the closures take `consuming Left` /
   `consuming Right`. The labeled-overload structure survives without
   rework. (Property-based shapes would also survive but for the
   wrong-recipe reasons in Option A.)

5. **`Parser.Error.Either` typealias migration.** Phase 2 of the prior
   research. The typealias migration is independent of this design — the
   new labeled shape is what `Parser.Error.Either` would inherit. The
   parser-primitives chain accessors (`.first`, `.second`, …, `.sixth`) live
   on a separate constrained extension and do not interact with this
   surface.

6. **API-mirror for tagged scalars beyond Either / Pair.** If the
   ecosystem grows other binary tagged types (e.g., `Validation<Error, Value>`
   or a future `These<This, That>`), the labeled-method-on-shared-verb
   pattern (`.map(this:, that:)`, `.fold(this:, that:)`) will generalize.
   Codifying the pattern in the implementation skill ([IMPL-024]
   adjacent) is a candidate for skill-lifecycle.

7. **Pair migration timing.** Recommend coordinating Pair with Either
   in a single mass-rollout PR per the workspace cohort discipline; both
   packages ship the same anti-pattern, both have the same cost profile.
   This is a coordination question, not a design question.

## References

### Internal

* Prior Tier 2 research:
  `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Research/either-implementation.md`
  (2026-03-19, status RECOMMENDATION).
* Skill `code-surface`: `/Users/coen/Developer/.claude/skills/code-surface/SKILL.md`
  — [API-NAME-001], [API-NAME-001a], [API-NAME-002], [API-NAME-008], [API-IMPL-005],
  [API-IMPL-008], [API-IMPL-012], [API-IMPL-013], [API-ERR-001].
* Skill `implementation`: `/Users/coen/Developer/.claude/skills/implementation/SKILL.md`
  + sibling `accessors.md` — [IMPL-INTENT], [IMPL-COMPILE], [IMPL-020], [IMPL-021],
  [IMPL-022], [IMPL-023], [IMPL-024], [IMPL-025], [IMPL-084], [IMPL-087].
* Skill `property-primitives`:
  `/Users/coen/Developer/swift-primitives/swift-property-primitives/.claude/skills/property-primitives/SKILL.md`
  — [PRP-001] through [PRP-013].

### Existing patterns in the ecosystem

* `swift-pair-primitives/Sources/Pair Primitives/Pair.swift` — same
  anti-pattern (`mapFirst`, `mapSecond`, `bimap`) targeted for parallel
  migration.
* `swift-array-primitives/Sources/Array Dynamic Primitives/Array.Dynamic ~Copyable.swift:223`
  — Property.Inout multi-form precedent for `forEach`.
* `swift-collection-primitives/Sources/Collection Primitives/Collection.Remove.swift`
  — multi-form `remove.{first, last, all}` precedent.
* `swift-property-primitives/Sources/Property Primitives Core/Property.swift`
  — canonical Property type definition.
* `swift-property-primitives/Sources/Property Inout Primitives/Property.Inout.swift`
  — `~Copyable` mutable Property variant.
* `swift-property-primitives/Sources/Property Borrow Primitives/Property.Borrow.swift`
  — `~Copyable` read-only Property variant.

### External

* Haskell Prelude `Either a b` / `either :: (a -> c) -> (b -> c) -> Either a b -> c`
  (Haskell 98 Report, 1998) — the catamorphism (`fold`).
* Rust `either` crate — `Either<L, R>` with `map_left`, `map_right`,
  `either(...)`. Compound names are idiomatic in Rust; the institute's
  [API-NAME-002] explicitly diverges.
* Swift Forums "Adding Either type to the Standard Library"
  (https://forums.swift.org/t/adding-either-type-to-the-standard-library/36972)
  — community discussion; no formal proposal landed.
