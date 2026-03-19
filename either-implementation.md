# Either Implementation for Swift Institute Ecosystem

<!--
---
version: 1.0.0
last_updated: 2026-03-19
status: RECOMMENDATION
tier: 2
---
-->

## Context

`Either<Left, Right>` was added to `swift-algebra-primitives` as the binary coproduct type -- the categorical dual of `Pair`. The current implementation lives at `/Users/coen/Developer/swift-primitives/swift-algebra-primitives/Sources/Algebra Primitives/Either.swift`.

The primary motivating use case is typed error composition for closure-accepting APIs. Today, APIs like `File.Directory.Walk.iterate(body:)` fall back to bare `throws` because they cannot express "Walk.Error or whatever the user's closure throws" in a typed way. `Either<Walk.Error, E>` solves this.

`Parser.Error.Either` already exists in `swift-parser-primitives` as a domain-specific binary sum for composing parser failures. `IO.Failure.Work<Domain, Operation>` in `swift-io` is structurally identical to `Either` with semantic case names (`domain`/`operation`). Both validate the pattern.

**Trigger**: [RES-001] New ecosystem-wide type needs design validation before broad adoption.
**Scope**: Ecosystem-wide -- affects primitives, standards, and foundations layers.

## Question

1. Is `Either<Left, Right>` sufficient, or should we pursue N-ary `OneOf<each T>` using Swift parameter packs?
2. How should nesting ergonomics work for 3+ cases?
3. What is the optimal API surface for typed error composition specifically?
4. What should the consolidation path be for `Parser.Error.Either` and `IO.Failure.Work`?
5. Is `Either` the right name?

## Analysis

### Q1: Binary vs N-ary -- Is `Either` Sufficient?

#### Option A: Binary `Either<Left, Right>` (current)

```swift
public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}
```

Composes via nesting: `Either<A, Either<B, C>>` for 3 cases.

**Strengths**: Simple, fully operational today, well-understood algebraically (bifunctor, coproduct object in **Set**), no compiler limitations.

**Weaknesses**: Nested types get verbose for 3+ cases. Type signatures like `Either<A, Either<B, Either<C, D>>>` are visually heavy.

#### Option B: N-ary `OneOf<each Case>` via Parameter Packs

The ideal type would be:

```swift
// HYPOTHETICAL -- does not compile
enum OneOf<each Case> {
    case value(repeat each Case)  // One case per pack element
}
```

**Compiler status (Swift 6.2, March 2026)**: SE-0398 (Allow Generic Types to Abstract Over Packs) explicitly states that variadic enums are deferred to a future proposal. The current implementation supports variadic structs, classes, actors, and type aliases, but NOT enums. The SE-0398 text reads: "A future proposal will address variadic generic enums."

No proposal for variadic enums has been published or pitched as of this writing. No experimental feature flag exists. The compiler rejects `enum OneOf<each Case>` outright.

**What does work today**: `Parser.OneOf.Errors<each E>` demonstrates the struct-based workaround:

```swift
// From swift-parser-primitives -- COMPILES
public struct Errors<each E: Swift.Error & Sendable>: Swift.Error, Sendable {
    public let failures: (repeat each E)

    public init(_ failures: repeat each E) {
        self.failures = (repeat each failures)
    }
}
```

This stores all errors in a tuple. It works for the "all alternatives failed" case (product of errors), but it does NOT model a coproduct (exactly one of N). The parser `Errors` type means "every parser failed, here are all the failures." `Either` means "exactly one of two things happened."

**Fundamental mismatch**: Even if variadic enums compiled, `OneOf<each Case>` (coproduct -- exactly one value) is categorically different from `Errors<each E>` (product of errors -- all values). The parser-primitives `Errors` type is correct for its use case; `Either` is correct for a different use case. They are not competing designs.

#### Option C: Macro-generated N-ary Enum

A `@OneOf` macro could generate:

```swift
@OneOf enum Error {
    case network(NetworkError)
    case parse(ParseError)
    case validation(ValidationError)
}
```

This is exactly what hand-written error enums already provide (see Option A in `typed-throws-mixed-error-domains.md`). The macro adds no value here -- the pattern is already idiomatic Swift. For the specific use case of composing two error domains in a generic API signature (`throws(Either<Infrastructure.Error, E>)`), an explicit enum cannot be used because `E` is a generic parameter.

**Verdict**: Option A (binary `Either`) is the only viable choice today. Option B is blocked by the compiler with no timeline. Option C is solved by existing language features. The binary form is sufficient because the primary use case is composing exactly two error domains: "the operation's own error" and "the caller's error."

### Q2: Nesting Ergonomics

When binary `Either` must represent 3+ cases (rare but possible), nesting is right-associative by convention: `Either<A, Either<B, C>>`.

#### Parser-primitives chain accessor pattern

`Parser.Error.Either` provides positional accessors via the `_EitherChain` protocol:

```swift
// From swift-parser-primitives
public protocol _EitherChain {
    associatedtype _Left
    associatedtype _Right
    var _left: _Left? { get }
    var _right: _Right? { get }
}

extension Parser.Error.Either {
    var first: Left? { left }
}

extension Parser.Error.Either where Right: _EitherChain {
    var second: Right._Left? { right?._left }
}

extension Parser.Error.Either where Right: _EitherChain, Right._Right: _EitherChain {
    var third: Right._Right._Left? { right?._right?._left }
}
// ... up to sixth
```

This enables: `error.first`, `error.second`, `error.third` instead of `error.left`, `error.right?.left`, `error.right?.right?.left`.

#### Should chain accessors be on `Either` itself?

**Against**:
- The chain pattern is parser-specific infrastructure. General `Either` has no natural reason to nest beyond 2 levels.
- Adding `_EitherChain` conformance to the algebra-primitives `Either` couples a Layer 1 algebraic type to a parser-specific protocol.
- For typed throws error composition, nesting beyond 2 levels indicates the API should use a dedicated error enum instead (per `typed-throws-mixed-error-domains.md` Option A).

**For**:
- If `Parser.Error.Either` becomes a typealias to `Either`, the chain protocol needs to work on `Either`.

**Recommendation**: Do NOT add chain accessors to the general `Either`. The parser's chain protocol is parser-domain infrastructure. If `Parser.Error.Either` becomes a typealias for `Either`, the chain extensions can be written as constrained extensions on `Either` within the parser-primitives package, without polluting the general type.

### Q3: Error Composition for Typed Throws

The primary use case. Three patterns exist in the ecosystem today:

#### Pattern 1: Bare `throws` (current workaround)

```swift
// File.Directory.Walk -- CURRENT
public func iterate(
    options: borrowing Options = Options(),
    body: (File.Directory.Entry) throws -> File.Directory.Contents.Control
) throws {
    // Must type-erase both Walk.Error and the body's error
}
```

**Problem**: Type erasure. Callers cannot distinguish walk failures from body failures in catch clauses.

#### Pattern 2: Dedicated envelope enum

```swift
// IO.Failure.Work -- EXISTING
public enum Work<Domain: Error & Sendable, Operation: Error & Sendable>: Error, Sendable {
    case domain(Domain)      // Infrastructure error
    case operation(Operation) // User's operation error
}

// Usage:
func run<E: Error>(_ op: () throws(E) -> T) async throws(IO.Failure.Work<IO.Lane.Error, E>) -> T
```

**Strength**: Semantic case names (`domain`/`operation`) communicate intent.
**Weakness**: Structurally identical to `Either`, creating conceptual duplication.

#### Pattern 3: `Either` directly in throws clause

```swift
// PROPOSED
public func iterate<E: Error>(
    options: borrowing Options = Options(),
    body: (File.Directory.Entry) throws(E) -> File.Directory.Contents.Control
) throws(Either<File.Directory.Walk.Error, E>) {
    // Walk.Error on left, user's E on right
}
```

**Strength**: Universal, no domain-specific envelope needed.
**Weakness**: `Either<A, B>` communicates no semantic distinction between left and right.

#### Cross-language comparison

| Language | Pattern | Mechanism |
|----------|---------|-----------|
| **Rust** | `From` trait + `?` operator | `impl From<SubError> for MyError` enables automatic conversion; `?` invokes it. No `Either` needed at the type level -- errors convert eagerly. |
| **Haskell** | `Either a b` + `ExceptT` | `ExceptT e m a` is the error monad transformer. `modifyError` adapts between error types. `Either` is the value-level representation. |
| **TypeScript** | Discriminated unions | `type Result = { kind: 'ok', value: T } \| { kind: 'error', error: E }` -- structural, no Either type needed. |

**Key insight from Rust**: Rust does not use `Either` for error composition. Instead, the `From` trait enables implicit conversion: `fn foo() -> Result<T, MyError>` works when sub-operations throw different errors, provided `impl From<SubError> for MyError` exists. The `?` operator performs the conversion automatically.

Swift lacks this mechanism. `Either` is the minimal way to compose two error types without writing a dedicated enum for every composition site. The typed throws system demands it.

#### Recommended convention

Adopt a consistent **left = infrastructure, right = caller** convention:

```swift
// Convention: Left is the API's own error, Right is the user's error
throws(Either<Walk.Error, E>)         // Walk failed, or user's closure failed
throws(Either<IO.Lane.Error, E>)      // IO lane failed, or user's operation failed
throws(Either<Open.Error, E>)         // Open failed, or user's body failed
```

This mirrors `Result<Success, Failure>` (right is "good" -- here right is "user's domain") and Haskell's `Either` (left is conventionally the error side).

### Q4: Consolidation Path

Three `Either`-shaped types exist:

| Type | Location | Constraints | Features |
|------|----------|-------------|----------|
| `Either<Left, Right>` | algebra-primitives | None | map, mapLeft, bimap, swapped, left/right accessors, Never elimination |
| `Parser.Error.Either<Left, Right>` | parser-primitives | `Left: Error & Sendable, Right: Error & Sendable` | Chain accessors (first..sixth), LocatedError, Never elimination |
| `IO.Failure.Work<Domain, Operation>` | swift-io | `Domain: Error & Sendable, Operation: Error & Sendable` | Semantic case names (domain/operation) |

#### Recommendation

1. **`Either<Left, Right>`** remains the canonical binary coproduct in algebra-primitives. No constraints on `Left`/`Right` -- it is a pure algebraic type. Conditional `Error` conformance (already present: `extension Either: Error where Left: Error, Right: Error {}`) makes it usable in typed throws.

2. **`Parser.Error.Either`** becomes a typealias:

    ```swift
    extension Parser.Error {
        public typealias Either<Left: Swift.Error & Sendable, Right: Swift.Error & Sendable>
            = Algebra_Primitives.Either<Left, Right>
    }
    ```

    Chain accessors (`.first`, `.second`, etc.) move to constrained extensions on `Algebra_Primitives.Either` within parser-error-primitives. The `_EitherChain` protocol stays in parser-primitives. The `@frozen` attribute is lost (algebra-primitives `Either` is not `@frozen`), but this is acceptable -- `@frozen` on a Layer 1 primitive that will be used ecosystem-wide is premature optimization with high ABI coupling cost.

3. **`IO.Failure.Work`** does NOT become a typealias. Its semantic case names (`domain`/`operation`) are valuable -- they communicate the architectural distinction between infrastructure failure and operation failure. `IO.Failure.Work` should remain a separate type. If desired, convenience conversion to `Either` can be added:

    ```swift
    extension IO.Failure.Work {
        public var asEither: Either<Domain, Operation> {
            switch self {
            case .domain(let d): .left(d)
            case .operation(let o): .right(o)
            }
        }
    }
    ```

### Q5: Naming

| Name | Tradition | Pros | Cons |
|------|-----------|------|------|
| `Either` | Haskell, Scala, Rust (crate), Swift community (robrix, PointFree, RougeWare, bow-swift) | Universal recognition; categorical name (coproduct); mirrors `Pair` | Left/Right are positionally meaningless |
| `OneOf` | Swift community (informal) | Reads naturally in English | Implies N-ary; confusing alongside `Parser.OneOf` which is already N-ary |
| `Sum` | Category theory | Precise algebraic name | Unfamiliar to most Swift developers; collides with arithmetic `sum` |
| `Coproduct` | Category theory | Maximally precise | Too academic; verbose |
| `Choice` | Some FP libraries | Friendly | Vague; implies user selection |

**Recommendation**: `Either` is correct.

1. **Ecosystem alignment**: The Swift community has converged on `Either`. Four independent Swift packages use this name (robrix/Either, pointfreeco/swift-either, RougeWare/Swift-Either, bow-swift). The Swift Forums discussion "[Adding Either type to the Standard Library](https://forums.swift.org/t/adding-either-type-to-the-standard-library/36972)" used this name throughout.

2. **Dual naming with `Pair`**: In algebra-primitives, `Pair` (product) and `Either` (coproduct) form a dual pair. This is the standard naming in category theory: product and coproduct. `Pair`/`Either` is clearer than `Pair`/`OneOf` or `Pair`/`Sum`.

3. **`OneOf` collision**: `Parser.OneOf` is already an N-ary namespace in parser-primitives. Using `OneOf` for the binary type would create confusion.

4. **Specification-mirroring**: Per [API-NAME-003], types implementing specifications should mirror specification terminology. `Either` is the established term in programming language theory (Haskell 98 Report, 1998; ML `datatype ('a, 'b) either`, 1973).

### Additional API Surface Considerations

#### Missing from current implementation

The current `Either` in algebra-primitives is well-designed. Two additions are worth considering:

**1. `flatMap` (monadic bind)**:

```swift
extension Either {
    @inlinable
    public func flatMap<NewRight, E: Swift.Error>(
        _ transform: (Right) throws(E) -> Either<Left, NewRight>
    ) throws(E) -> Either<Left, NewRight> {
        switch self {
        case .left(let left): .left(left)
        case .right(let right): try transform(right)
        }
    }
}
```

This is the standard monad instance for `Either`, biased to `Right`. It enables chaining operations that may fail with `Left`. However: this is the only monad instance in algebra-primitives today (neither `Pair` nor any other type has one). Adding it sets a precedent. **Defer until a concrete use case demands it.**

**2. `fold` / `either` (catamorphism)**:

```swift
extension Either {
    @inlinable
    public func fold<Result, E: Swift.Error>(
        left: (Left) throws(E) -> Result,
        right: (Right) throws(E) -> Result
    ) throws(E) -> Result {
        switch self {
        case .left(let l): try left(l)
        case .right(let r): try right(r)
        }
    }
}
```

This eliminates the `Either` by handling both cases, producing a single value. It is the universal property of the coproduct. The existing `bimap` transforms both sides while preserving the `Either` structure; `fold` collapses it. **This is high-value** -- it enables clean error handling:

```swift
try result.fold(
    left: { walkError in handleWalkError(walkError) },
    right: { userError in handleUserError(userError) }
)
```

**Recommendation**: Add `fold` now. Defer `flatMap`.

#### `~Copyable` support

The current `Either` does not suppress `Copyable`. Per [SE-0427], enum cases with associated values can hold `~Copyable` payloads when the enum itself is `~Copyable`. This would allow:

```swift
enum Either<Left: ~Copyable, Right: ~Copyable>: ~Copyable {
    case left(Left)
    case right(Right)
}
extension Either: Copyable where Left: Copyable, Right: Copyable {}
```

**Assessment**: The current `Pair` also does not suppress `Copyable`. Adding `~Copyable` support to both `Pair` and `Either` simultaneously is a natural enhancement but should be a separate effort -- it affects conditional conformances, functor methods (consuming vs borrowing), and downstream consumers. **Defer to a dedicated `~Copyable` algebra-primitives pass.**

## Outcome

**Status**: RECOMMENDATION

### Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Keep binary `Either<Left, Right>`** | N-ary variadic enum is compiler-blocked (SE-0398 deferred). Binary is sufficient for the primary use case (two-domain error composition). |
| 2 | **Name: `Either`** | Universal Swift community convention; categorical dual of `Pair`; avoids `OneOf` collision with parser-primitives. |
| 3 | **Do NOT add chain accessors to general `Either`** | Chain access (`.first`/`.second`/`.third`) is parser-domain infrastructure. Parser-primitives can add constrained extensions on `Either` after typealias migration. |
| 4 | **Adopt left=infrastructure, right=caller convention** | Mirrors Haskell left-as-error convention; consistent with `Result<Success, Failure>` right-positive bias. |
| 5 | **`Parser.Error.Either` becomes typealias to `Either`** | Eliminates structural duplication. Chain accessors stay in parser-primitives as constrained extensions. |
| 6 | **`IO.Failure.Work` stays separate** | Semantic case names (`domain`/`operation`) carry architectural meaning that generic `left`/`right` would lose. |
| 7 | **Add `fold` to `Either`** | The coproduct catamorphism -- eliminates the Either by handling both cases. High-value for error handling ergonomics. |
| 8 | **Defer `flatMap`** | No concrete use case yet. Adding it sets a monad precedent in algebra-primitives. |
| 9 | **Defer `~Copyable` support** | Natural enhancement but requires coordinated pass across `Pair` and `Either` with conditional conformance and ownership method changes. |

### Migration phases

**Phase 1** (immediate): Add `fold` to `Either` in algebra-primitives.

**Phase 2** (next session): Convert `Parser.Error.Either` to typealias. Move chain accessor extensions to constrained extensions on `Algebra_Primitives.Either`. Verify all 11 parser-primitives files that reference `Parser.Error.Either` compile.

**Phase 3** (adoption): Convert closure-accepting APIs that currently use bare `throws` to `throws(Either<Operation.Error, E>)`. Priority targets:
- `File.Directory.Walk.iterate(body:)` -- currently bare `throws`, should be `throws(Either<Walk.Error, E>)`
- Any other APIs identified in the typed-throws conversion inventory with "17 closure parameters in foundations (blocked by stdlib rethrows or mixed domains)"

**Phase 4** (future): `~Copyable` algebra-primitives pass. Coordinate with `Pair`.

## Prior Art Survey

### Swift Community

| Package | Author | API | Notes |
|---------|--------|-----|-------|
| [robrix/Either](https://github.com/robrix/Either) | Rob Rix | `Either<Left, Right>`, `EitherProtocol` | Microframework; `EitherProtocol` for generic extensions |
| [pointfreeco/swift-either](https://github.com/pointfreeco/swift-either) | Point-Free | `Either<A, B>` | Part of swift-prelude ecosystem |
| [RougeWare/Swift-Either](https://github.com/RougeWare/Swift-Either) | RougeWare | `Either<First, Second>` | Auto-conformance to Equatable, Hashable, Codable |
| [bow-swift/bow](https://github.com/bow-swift/bow) | bow-swift | `Either<A, B>` | Full FP library; monad, applicative, traverse |
| [sloik/EitherSwift](https://github.com/sloik/EitherSwift) | sloik | `Either` + `partitionEithers` | Utility-focused |
| [Swift Forums discussion](https://forums.swift.org/t/adding-either-type-to-the-standard-library/36972) | Community | `enum Either { case first(First), case second(Second) }` | 2020 discussion; no formal proposal resulted |

All five independent implementations use the name `Either` with `Left`/`Right` or `First`/`Second` case names. None use `OneOf`.

### Rust

Rust's [`either` crate](https://docs.rs/either/latest/either/) (maintained by rayon-rs) provides `Either<L, R>` with:
- `is_left()`, `is_right()`, `left()`, `right()` -- optional accessors
- `map_left()`, `map_right()` -- functor operations
- `either()` -- fold/catamorphism (called `either` not `fold`)
- `try_left!()`, `try_right!()` -- macros for short-circuiting (analogous to `?` operator)
- Conversion to `Result` (Right=Ok, Left=Err) and from `Result`

Rust does NOT use `Either` for error composition in practice. The `From` trait + `?` operator provides implicit error conversion: `impl From<IoError> for MyError` lets `?` convert automatically. Swift has no equivalent mechanism, making `Either` more important in our ecosystem.

### Haskell

`Either a b` is in the Haskell Prelude (standard library). Key features:
- `data Either a b = Left a | Right b`
- `Functor` (Right-biased), `Monad` (Right-biased), `Bifunctor`
- `either :: (a -> c) -> (b -> c) -> Either a b -> c` -- the catamorphism (our `fold`)
- `partitionEithers :: [Either a b] -> ([a], [b])` -- separates a list

`ExceptT e m a` is the error monad transformer, structurally `m (Either e a)`. `modifyError` adapts between error types -- the Haskell equivalent of our typed throws error domain composition. `MonadError` abstracts over the error mechanism.

[`These a b`](https://hackage.haskell.org/package/these) from the `these` package represents "inclusive or": `This a | That b | These a b`. Algebraically `A + B + A*B`. This is relevant if we ever need "both errors occurred" semantics (not needed for typed throws, but potentially useful for validation that accumulates errors).

### TypeScript

TypeScript uses structural [discriminated unions](https://www.typescriptlang.org/docs/handbook/2/narrowing.html) instead of a named `Either` type:

```typescript
type Result<T, E> = { kind: 'ok'; value: T } | { kind: 'error'; error: E };
```

The compiler narrows types via the discriminant property (`kind`). No library type needed -- the language's structural type system handles it natively. Swift's nominal type system requires an explicit `Either` enum.

### Swift Evolution

| Proposal | Status | Relevance |
|----------|--------|-----------|
| [SE-0393](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md) | Implemented (Swift 5.9) | Type/value parameter packs -- foundation for variadic generics |
| [SE-0398](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md) | Implemented (Swift 5.9) | Variadic structs/classes/actors. **Enums explicitly deferred.** |
| [SE-0399](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0399-tuple-of-value-packs.md) | Implemented (Swift 5.9) | Tuple of value packs |
| [SE-0408](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0408-pack-iteration.md) | Implemented (Swift 6.0) | Pack iteration via for-in |
| [SE-0427](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) | Implemented (Swift 6.0) | Noncopyable generics -- enables future `Either: ~Copyable` |

No proposal or pitch for variadic enums has been published. The variadic generics vision document mentions it as future work but provides no timeline.
