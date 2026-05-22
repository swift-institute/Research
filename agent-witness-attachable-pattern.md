# The Agent-Witness-Attachable Pattern for Codec Primitives

**Status**: Proposed convention, awaiting pilot application
**Scope**: All codec-shaped primitive domains (Parser, Serializer, Coder, Formatter, Sequencer, and future analogues such as Validator, Decoder, Encoder, Transformer)
**Audience**: An agent dispatched to apply this pattern to a pilot package.

---

## 0. TL;DR

For each codec-shaped primitive domain, ship a uniform **triple** of types:

| Role | Shape | Example |
|---|---|---|
| **Agent** | `enum X {}` namespace + `X.\`Protocol\`` protocol | `Parser` + `Parser.\`Protocol\`` |
| **Witness** | top-level `struct Verb<…>` | `Parse<I, O, F>` |
| **Attachable** | top-level `protocol Verbable` | `Parseable` |

The agent enum stays empty as a namespace, hosting the protocol, combinators, errors, builders, and other domain types. The witness lives top-level so it can be referenced without a generic binding tax. The attachable lets domain types declare a canonical instance.

Composition combinators (sequential, alternation, etc.) reuse the institute's existing composition primitives — `Pair`, `Either`, `Product`, and the deferred `Coproduct` — via conditional conformances, rather than reinventing storage shapes per domain.

---

## 1. Motivation

Swift's type system forces a choice for any "namespace-like" identifier:

- **Option A**: make it a generic struct (`struct Parser<I, O>`). The type is instantiable; combinators and methods hang off it cleanly; *but* every nested member pays a binding tax (`Parser<Int, String>.Options` even when `Options` doesn't use `I, O`), and protocols cannot be nested in generic types at all.
- **Option B**: make it an empty enum (`enum Parser {}`). Nested members are accessible cleanly (`Parser.Options`); protocols can nest (`Parser.\`Protocol\``); *but* the namespace identifier is not itself instantiable as a generic type.

The institute has consistently chosen Option B for namespace identifiers under `[API-NAME-001]` / `[API-NAME-002]`. This document standardizes how to recover the "instantiable type" benefit of Option A *alongside* the cleanly-nested namespace of Option B — by giving the witness a distinct top-level name (the verb form).

The pattern also unifies how domain types declare canonical instances (the attachable), making generic dispatch (`func decode<T: Parseable>(...)`) work uniformly across the codec family.

### Reading prerequisites

The receiving agent should be familiar with:
- `swift-institute/Skills/code-surface/` — `[API-NAME-*]`, `[API-ERR-*]`, `[API-IMPL-*]`
- `swift-institute/Skills/swift-institute/` — five-layer architecture
- `swift-institute/Skills/primitives/` — primitives layer conventions
- `swift-institute/Skills/testing-swiftlang/` — swift-testing usage
- `swift-institute/Skills/modularization/` — per-target organization, cross-package conformances
- `swift-institute/Blog/Published/2026-05-11-introducing-pair-either-product-primitives.md` — Pair/Either/Product
- `swift-institute/Blog/Published/2026-05-12-the-missing-fourth-corner.md` — deferred Coproduct

---

## 2. The Triple

### 2.1 Agent — the namespace + the protocol

```
enum <Agent> {
    protocol `Protocol`<…> { … }
    // + all axis-blind domain types: combinators, errors, builders, helpers
}
```

The agent name is the **verb-er noun form**: Parser, Serializer, Coder, Formatter, Sequencer, Validator, Decoder, Encoder, Transformer.

The enum stays empty as a namespace. It is *never* instantiated; it exists solely to host:
- `<Agent>.\`Protocol\`` (the agent protocol)
- Concrete combinator types (`<Agent>.Map`, `<Agent>.OneOf`, `<Agent>.Take`, …)
- Error type(s) (`<Agent>.Error`, possibly nested error variants)
- Result builder (`<Agent>.Builder<Input>`)
- Domain-specific helpers

### 2.2 Witness — the instantiable type-erased value

```
public struct <Verb><…>: <Agent>.`Protocol` {
    public let <verb>: (inout Input) throws(Failure) -> Output
    public init(<verb>: @escaping (inout Input) throws(Failure) -> Output)
    // …
}
```

The witness name is the **bare verb form**, matching the agent protocol's method identifier:

| Agent protocol method | Witness type |
|---|---|
| `parse(_:)` | `Parse<I, O, F>` |
| `serialize(_:)` | `Serialize<O, B, F>` |
| `format(_:)` | `Format<I, O, F>` |
| `sequence(_:)` | `Sequence<E>` |
| `validate(_:)` | `Validate<T, F>` |
| `decode(_:)` | `Decode<I, O, F>` |

**Verb form is canonical.** The witness identifier echoes the protocol's method identifier so the type-method correspondence is predictable: `parse(_:)` ↔ `Parse<…>`. This is the principle to apply when extending to new domains.

**Exception**: when the bare verb is severely overloaded as a software-English word, use an established domain term instead. The known case is `Code` (overloaded with source code, error code, country code, ASCII code, etc.) — for that domain use `Codec<I, O, B, F>`. Document any new exception in the package README and in this document.

The witness lives **at the top level of the module**, not nested under the agent enum. This is the design's load-bearing concession: top-level placement lets `Parse<I, O>` be referenced without ever paying the generic-binding tax that would apply if it lived inside a generic outer type.

### 2.3 Attachable — the capability attachment

```
public protocol <Verb>able {
    associatedtype <Agent>: <Agent>.`Protocol`
    static var <agent>: <Agent> { get }   // type-level capability
    // or
    var <agent>: <Agent> { borrowing get } // instance-level capability
}
```

The attachable name is **verb-stem + `able`**: Parseable, Serializable, Codable, Formattable, Sequenceable.

A type T conforms to the attachable when it has a canonical instance of the agent. For example, `extension Date: Parseable { static var parser: Date.Parser { … } }` declares "the canonical parser for Date is the one you get from `Date.parser`."

**Static vs instance accessor** — this depends on whether the capability is *type-level* or *value-level*:

| Capability | Accessor | Examples |
|---|---|---|
| Parsing/Decoding from raw bytes — capability lives on the *type* | `static var parser: Parser` | Parseable, Decodable |
| Serializing/Encoding *a specific value* — capability lives on the *instance* | `var serializer: Serializer` (or `static var serializer: Serializer` if value-independent) | Serializable, Encodable |
| Iterating *a specific value* — capability lives on the *instance* | `var sequence: Sequence { borrowing get }` | Sequenceable |
| Formatting *a specific value* — capability lives on the *instance* | `var format: Format { borrowing get }` | Formattable |

When in doubt, ask: "is the canonical X dependent on a specific value of T, or is it the same for every value of T?" — instance accessor for value-dependent, static accessor for type-dependent.

---

## 3. Naming Conventions Summary

| Role | Form | Example |
|---|---|---|
| Agent namespace + enum | verb-er noun | `Parser`, `Sequencer` |
| Agent protocol | `<Agent>.\`Protocol\`` (backticked, primary associated types) | `Parser.\`Protocol\`<Input, Output, Failure>` |
| Witness | bare verb (or domain term if verb is overloaded) | `Parse`, `Serialize`, `Codec`, `Sequence` |
| Attachable | verb-stem + `able` | `Parseable`, `Serializable`, `Sequenceable` |
| Combinator types | verb-as-noun, under agent enum | `Parser.Map`, `Parser.OneOf`, `Parser.Take` |
| Error type | `<Agent>.Error` (nested variants OK) | `Parser.Error`, `Parser.Error.Located` |
| Result builder | `<Agent>.Builder<…>` | `Parser.Builder<Input>` |

### Witness identifier rule (the meta-rule)

> The witness's identifier echoes the protocol's method identifier. If the method is `verb(_:)`, the witness is `Verb<…>`. If the bare `Verb` is severely overloaded in software English, use an established domain term and document the exception.

This is the test to apply for any new domain. Do not relitigate per-domain.

---

## 4. Package Layout

A package implementing this pattern follows the institute's per-combinator-target convention:

```
swift-<agent>-primitives/
  Package.swift
  Sources/
    <Agent> Primitives Core/                  # core types
      <Agent>.swift                           # enum <Agent>
      <Agent>.Protocol.swift                  # protocol declaration + body defaults
      <Agent>.Builder.swift                   # result builder
      <Verb>.swift                            # top-level witness (e.g., Parse.swift)
      <Verbable>.swift                        # top-level attachable (e.g., Parseable.swift)
      exports.swift                           # @_exported re-exports
    <Agent> Error Primitives/                 # error types
      <Agent>.Error.swift
      <Agent>.Error.<variant>.swift           # nested error variants
      exports.swift
    <Agent> Map Primitives/                   # one target per combinator
      <Agent>.Map.swift
      <Agent>.Protocol+map.swift              # extension on protocol providing .map
      exports.swift
    <Agent> Take Primitives/
    <Agent> OneOf Primitives/
    <Agent> Optional Primitives/
    <Agent> Many Primitives/
    …
    <Agent> Pair Primitives/                  # shape-primitive integration target
      Pair+<Agent>.Protocol.swift
      Pair+<Agent>.Printer.swift              # if printer/round-trip applies
      exports.swift
    <Agent> Product Primitives/               # when ~Copyable packs land
    <Agent> Either Primitives/                # if Either is used as Output
    <Agent> Primitives                        # umbrella re-exporting all of the above
    <Agent> Primitives Test Support           # shared test fixtures
  Tests/
    <Agent> Primitives Core Tests/
    <Agent> Map Primitives Tests/
    <Agent> Take Primitives Tests/
    <Agent> Pair Primitives Tests/
    …
  Package.swift
```

**Per-target rule**: each combinator family is its own SwiftPM target with its own library product. Consumers can import just the combinators they need (`import Parser_Map_Primitives`) or the umbrella (`import Parser_Primitives`). The umbrella re-exports all combinator targets.

**One type per file** (`[API-IMPL-005]`). Extension-only files use `<Subject>+<Augmentation>.swift` naming (e.g., `Pair+Parser.Protocol.swift`, `Parser.Protocol+map.swift`).

**exports.swift per target**: each target has an `exports.swift` containing `@_exported public import` statements for that target's dependencies. This is the institute's idiom for making transitively-available types accessible without per-file explicit imports.

---

## 5. The Agent Protocol — Detailed Shape

```swift
// Sources/<Agent> Primitives Core/<Agent>.Protocol.swift

extension <Agent> {
    /// The agent protocol. Types conforming to this protocol *act as* an agent
    /// — they implement the canonical `verb(_:)` method.
    public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
        /// The input type this agent consumes / produces.
        associatedtype Input: ~Copyable & ~Escapable

        /// The output type.
        associatedtype Output

        /// The error type. Defaults to Never for infallible agents.
        associatedtype Failure: Swift.Error = Never

        /// The declarative body type. Use Never for leaf agents.
        associatedtype Body: ~Copyable

        /// The declarative composition. Marked with the result builder so
        /// `body { … }` works at conformance sites.
        @<Agent>.Builder<Input>
        var body: Body { borrowing get }

        /// The canonical action. The method identifier is the verb form
        /// (`parse`, `serialize`, `format`, …) — same as the witness type's name.
        borrowing func <verb>(_ input: inout Input) throws(Failure) -> Output
    }
}
```

### Two extension defaults

**Leaf agents** (Body == Never):

```swift
extension <Agent>.`Protocol` where Body == Never {
    public var body: Never {
        fatalError("\(Self.self) is a leaf agent; it has no body.")
    }
}
```

**Declarative agents** (Body is itself an agent):

```swift
extension <Agent>.`Protocol` where Body: <Agent>.`Protocol`,
                                   Body.Input == Input,
                                   Body.Output == Output,
                                   Body.Failure == Failure {
    @inlinable
    public borrowing func <verb>(_ input: inout Input) throws(Failure) -> Output {
        try body.<verb>(&input)
    }
}
```

This pair lets concrete combinators declare `typealias Body = Never` and implement `<verb>(_:)` directly, while declarative compositions declare a body and inherit the default `<verb>(_:)` implementation.

### Primary associated types

`<Agent>.\`Protocol\`<Input, Output, Failure>` declares Input, Output, Failure as primary associated types (SE-0346). This enables `some <Agent>.\`Protocol\`<Bytes, JSON.Value>` and `any <Agent>.\`Protocol\`<Bytes, JSON.Value>` at use sites.

### Typed throws

Every method that can fail uses typed throws per `[API-ERR-001]`: `throws(Failure)`, not `throws` (untyped). When composing combinators across two sub-agents, unify failures via `Either<First.Failure, Second.Failure>` for binary, `Product<each P.Failure>` or `Coproduct<each P.Failure>` for n-ary (Coproduct deferred — see Section 7).

---

## 6. The Witness Type — Detailed Shape

```swift
// Sources/<Agent> Primitives Core/<Verb>.swift

/// The type-erased agent value. Holds the canonical closure form.
/// Use this when you need a value of "an agent" without committing to a
/// specific conforming type.
public struct <Verb><Input: ~Copyable & ~Escapable,
                     Output,
                     Failure: Swift.Error>: <Agent>.`Protocol` {
    public typealias Body = Never

    public let <verb>: (inout Input) throws(Failure) -> Output

    @inlinable
    public init(<verb>: @escaping (inout Input) throws(Failure) -> Output) {
        self.<verb> = <verb>
    }

    @inlinable
    public borrowing func <verb>(_ input: inout Input) throws(Failure) -> Output {
        try self.<verb>(&input)
    }
}
```

### Constructing from any conforming agent

```swift
extension <Verb> {
    @inlinable
    public init<P: <Agent>.`Protocol`>(_ source: P)
    where P.Input == Input, P.Output == Output, P.Failure == Failure {
        self.init(<verb>: { input in try source.<verb>(&input) })
    }
}
```

This is the type-erasure constructor — wrap any specific agent into the witness.

### When to reach for the witness

- Storing heterogeneous agents in a collection (where each has different concrete type but same Input/Output/Failure).
- Erasing the structural type information for ABI stability or API surface management.
- Cases where `some <Agent>.\`Protocol\`<…>` doesn't suffice (e.g., needing a stored property with a fixed concrete type).

Specialization-friendly use sites should prefer `some <Agent>.\`Protocol\`<I, O>` instead of the witness; the witness is for cases where specialization isn't possible or wanted.

---

## 7. Composition via Shape Primitives

The institute's composition primitives — defined in `swift-pair-primitives`, `swift-either-primitives`, `swift-product-primitives`, and the deferred `swift-coproduct-primitives` — are the canonical structural building blocks. Combinators should reuse them rather than reinvent.

### 7.1 The 2×2 of composition

| | binary | n-ary |
|---|---|---|
| **product** (both arms) | `Pair<L, R>` | `Product<each E>` |
| **coproduct** (one arm) | `Either<L, R>` | `Coproduct<each E>` (deferred) |

See `swift-institute/Blog/Published/2026-05-11-introducing-pair-either-product-primitives.md` for the full primitives intro, and `2026-05-12-the-missing-fourth-corner.md` for the Coproduct deferral.

### 7.2 Sequential composition (binary)

Pair *is* the sequential combinator. Conform it to the agent protocol via conditional extension:

```swift
// Sources/<Agent> Pair Primitives/Pair+<Agent>.Protocol.swift

extension Pair: <Agent>.`Protocol`
where First: <Agent>.`Protocol`,
      Second: <Agent>.`Protocol`,
      First.Input == Second.Input
{
    public typealias Input = First.Input
    public typealias Output = (First.Output, Second.Output)
    public typealias Failure = Either<First.Failure, Second.Failure>

    @inlinable
    public borrowing func <verb>(_ input: inout Input) throws(Failure) -> Output {
        let o0: First.Output
        do { o0 = try first.<verb>(&input) } catch { throw .left(error) }
        let o1: Second.Output
        do { o1 = try second.<verb>(&input) } catch { throw .right(error) }
        return (o0, o1)
    }
}
```

This is the pattern. Validated for `Parser.\`Protocol\`` in `swift-parser-primitives` — see `Sources/Parser Pair Primitives/Pair+Parser.Protocol.swift`.

### 7.3 Alternation (binary)

Alternation uses Pair-shaped storage but Either-shaped output. Because Swift forbids multiple conformances of the same type to the same protocol, alternation requires a *distinct* combinator type that wraps Pair-shaped storage:

```swift
extension <Agent> {
    public struct OneOf<P0: <Agent>.`Protocol`, P1: <Agent>.`Protocol`>: <Agent>.`Protocol`
    where P0.Input == P1.Input {
        public let alternatives: Pair<P0, P1>
        public typealias Input = P0.Input
        public typealias Output = Either<P0.Output, P1.Output>
        public typealias Failure = …  // unified
        public typealias Body = Never

        public borrowing func <verb>(_ input: inout Input) throws(Failure) -> Output {
            // Try alternatives.first; on failure restore input and try alternatives.second
        }
    }
}
```

Note: the control flow ("try; restore; try fallback") is parser-specific in spirit but the storage shape is shared via `Pair`.

### 7.4 N-ary product and coproduct

- N-ary sequential composition will use `Product<each P>` when parameter packs admit `~Copyable` (currently blocked — see `swift-institute/Research/escapable-support-pair-either-product.md`).
- N-ary alternation will use `Coproduct<each P.Output>` when the language admits parameter-pack enum cases (currently blocked — see the Missing Fourth Corner blog post).

Until then, declare per-arity types (`<Agent>.OneOf.Three`, `<Agent>.OneOf.Four`, …) or accept nested-Either composition. The architecture accommodates the future shift without restructure.

### 7.5 Optionality, repetition, lazy, and other parser-specific control types

These have no clean shape-primitive analogue. Define them as concrete types nested under the agent enum:

```swift
extension <Agent> {
    public struct Optionally<Wrapped: <Agent>.`Protocol`>: <Agent>.`Protocol` { … }
    public struct Many<Element: <Agent>.`Protocol`>: <Agent>.`Protocol` { … }
    public struct Lazy<Wrapped: <Agent>.`Protocol`>: <Agent>.`Protocol` { … }
}
```

### 7.6 Variance-sensitive combinators (Map, FlatMap)

Map and FlatMap are *variance-sensitive*: they covariate in different positions across Parser, Serializer, Coder. They do **not** generalize across domains. Keep them as per-domain concrete types: `Parser.Map`, `Serializer.Map`, etc. Do not try to extract into shared primitives.

---

## 8. Combinator Decomposition Strategy

When deciding where each combinator lives, apply this decision tree:

1. **Does the combinator's storage match a shape primitive?**
   - Binary product / sequential → conform `Pair`. Combinator lives implicitly as `Pair<P0, P1>` (no new type needed).
   - Binary coproduct / alternation → distinct type wrapping `Pair` storage, with `Either` as Output. Combinator type lives under `<Agent>.OneOf`.
   - N-ary product → `Product` (when ~Copyable packs land).
   - N-ary coproduct / alternation → `Coproduct` (when language admits).
2. **Is the combinator variance-sensitive (Map/FlatMap/contramap)?**
   - Yes → concrete type under `<Agent>.<Combinator>`, do not extract.
3. **Is the combinator parser-specific control flow (Optional, Many, Lazy, Backtrack, Peek)?**
   - Yes → concrete type under `<Agent>.<Combinator>`, do not extract.
4. **Is it a cursor / input-manipulation type (Span, Consume, Discard, End)?**
   - Yes → concrete type under `<Agent>`, do not extract.

The result is: most combinators stay under the agent namespace as concrete types; sequential composition reuses Pair; alternation reuses Either as Output; N-ary forms await language features.

---

## 9. The Result Builder Pattern

```swift
@resultBuilder
public enum <Agent>.Builder<Input: ~Copyable & ~Escapable> {
    public static func buildPartialBlock<P>(first: P) -> P
    where P: <Agent>.`Protocol`, P.Input == Input {
        first
    }

    public static func buildPartialBlock<P0, P1>(
        accumulated: P0, next: P1
    ) -> Pair<P0, P1>
    where P0: <Agent>.`Protocol`,
          P1: <Agent>.`Protocol`,
          P0.Input == Input,
          P1.Input == Input {
        Pair(accumulated, next)
    }

    // optional / choice / etc. buildPartialBlock overloads
}
```

The builder produces shape-primitive values (`Pair`, possibly `Either`, future `Product`). The agent protocol's `Body` associated type is then `Pair<P0, P1>` (or similar), and the declarative-agent extension default routes `<verb>(_:)` to `body.<verb>(_:)`.

---

## 10. Tests

Use Apple Swift Testing per `swift-institute/Skills/testing-swiftlang/`:

```swift
import <Agent>_Primitives_Test_Support
import Testing

@Suite("<Type/Area>")
struct <Type>Tests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

extension <Type>Tests.Unit {
    @Test
    func `descriptive backticked name`() throws(any Swift.Error) {
        // setup, action, expectation
        #expect(…)
    }
}
```

One test target per combinator target. Test file naming: `<Type or Area> Tests.swift`. See `swift-institute/Skills/testing-institute/` for nested-package and snapshot patterns.

For shape-primitive integration targets (e.g., `<Agent> Pair Primitives Tests`), include **parity tests** that compare the shape-primitive conformance against any pre-existing per-domain combinator it replaces. Example:

```swift
@Test
func `Pair as Agent matches <Agent>.Take.Two on identical input`() throws(any Swift.Error) {
    var inputA = TestInput([…])
    let takeResult = try <Agent>.Take.Two(p0, p1).<verb>(&inputA)
    var inputB = TestInput([…])
    let pairResult = try Pair(p0, p1).<verb>(&inputB)
    #expect(takeResult.0 == pairResult.0)
    #expect(takeResult.1 == pairResult.1)
    #expect(inputA.first == inputB.first)
}
```

---

## 11. Migration Checklist

For migrating an existing package to this pattern:

### Phase A — establish the triple

- [ ] **Verify agent name** conforms to verb-er noun form (`Parser`, `Sequencer`, …). Rename package if needed.
- [ ] **Verify agent enum** exists as `enum <Agent> {}`. Empty namespace.
- [ ] **Verify agent protocol** exists at `<Agent>.\`Protocol\`<Input, Output, Failure>` with primary associated types, `Body: ~Copyable`, typed throws.
- [ ] **Promote witness to top level** if currently nested as `<Agent>.Witness`. New file: `Sources/<Agent> Primitives Core/<Verb>.swift`. Old nested name can stay as deprecated typealias for source compat during migration.
- [ ] **Verify attachable protocol** exists at top level as `<Verb>able` with the appropriate static/instance accessor.

### Phase B — apply shape primitives

- [ ] **Add `Pair: <Agent>.\`Protocol\`` conformance** in a new `<Agent> Pair Primitives` target. Mirror the pattern from `swift-parser-primitives/Sources/Parser Pair Primitives/`.
- [ ] **Write parity tests** in `<Agent> Pair Primitives Tests` comparing `Pair`-based composition against the pre-existing sequential combinator.
- [ ] **(Optional) Migrate callers** from the old per-domain sequential combinator to `Pair`-based form. Keep the old combinator as alias or deprecated.
- [ ] **(Optional) Add `Pair: <Agent>.Printer` conformance** if the domain has a printer/round-trip pair. The Printer extension's `where` clause must restate the agent protocol constraint: `where First: <Agent>.\`Protocol\` & <Agent>.Printer, …`. Reason: typealiases declared in the Protocol extension are only in scope where that conformance's constraints hold.

### Phase C — audit combinators

- [ ] **For each existing combinator**, classify per Section 8's decision tree.
- [ ] **Identify any combinator that's structurally a shape primitive** — sequential-with-tuple-output is `Pair`; alternation-with-Either-output uses Pair-storage. Migrate.
- [ ] **Leave variance-sensitive and parser-specific combinators in place.** Do not extract.

### Phase D — verify and ratify

- [ ] **`swift build`** passes clean.
- [ ] **`swift test`** passes all suites including the new parity tests.
- [ ] **Update package README** noting the witness type promotion and shape-primitive integration.
- [ ] **Document any domain exceptions** (e.g., `Codec` for the Coder domain).

---

## 12. Decision Criteria for Edge Cases

### 12.1 The verb is overloaded

**Diagnostic**: the bare verb has multiple unrelated meanings in software English (e.g., "Code" → source code, error code, country code, codec, ASCII code, …).

**Resolution**: use an established domain term. For Coder, the term is `Codec`. Document the exception in the package README and add a row to Section 3's table in this document.

### 12.2 Witness collides with another module's type

**Diagnostic**: the chosen witness name is already declared in a module that consumers commonly import (e.g., `Sequence` collides with `Swift.Sequence`).

**Resolution**: use module-qualified access at use sites (`Sequencer_Primitives.Sequence<E>` vs `Swift.Sequence`). Tolerable; the institute's witness is the canonical one within the institute ecosystem.

### 12.3 Body must propagate, not be Never

**Diagnostic**: a combinator's `Body` associated type can't be `Never` because the combinator carries a body that's itself an agent.

**Resolution**: set `Body == (First.Body, Second.Body)` or `Body == Pair<First.Body, Second.Body>` or similar shape-primitive composition. Verify that no existing usage depends on `Body == Never` for that specific combinator.

### 12.4 Failure unification across N agents

**Diagnostic**: a combinator composes N sub-agents and needs to unify their `Failure` types.

**Resolution**:
- N=2: `Either<First.Failure, Second.Failure>`.
- N>2 (until Coproduct ships): nested `Either` or per-domain wrapper. Document the awkwardness; revisit when Coproduct lands.

### 12.5 Cross-package conditional conformance

**Diagnostic**: an `extension Pair: <Agent>.\`Protocol\`` lives in package P but conforms a type from package Q (Pair) to a protocol from package R (the agent). SE-0450 trait-gated cross-package conformance.

**Resolution**: ratified pattern in `swift-institute/Skills/modularization/`. No special action needed; just place the conformance in the integration target (`<Agent> Pair Primitives`) and add a one-line note in the target's README about the trait gating.

### 12.6 ~Copyable and ~Escapable interactions

**Diagnostic**: Pair declares its generic parameters as `~Copyable & ~Escapable`, but the agent protocol may not suppress Escapable. Conformance requires Pair (in the extension's constraint scope) to be Escapable.

**Resolution**: the constraint `First: <Agent>.\`Protocol\`` implicitly requires `First: Escapable` (unless the agent protocol explicitly suppresses Escapable, which it usually doesn't). This propagates to Pair being Escapable in the extension's scope. No special action; the constraints align naturally.

### 12.7 Result builder receives a mix of leaf and declarative agents

**Diagnostic**: builder's `buildPartialBlock` is called with both leaf agents (Body == Never) and declarative agents (Body == something).

**Resolution**: both are `<Agent>.\`Protocol\``-conforming; the builder doesn't care about Body. The returned shape (e.g., `Pair<P0, P1>`) carries whatever Body the parent context wants — usually `Never` for the composition itself.

---

## 13. Worked Example: swift-parser-primitives

The pattern is partially implemented in `swift-parser-primitives` as of 2026-05-22:

| Pattern element | Location | Status |
|---|---|---|
| Agent enum | `Sources/Parser Primitives Core/Parser.swift` (or wherever `enum Parser {}` is declared) | ✅ |
| Agent protocol | `Sources/Parser Primitives Core/Parser.Parser.swift:90–156` | ✅ |
| Witness (nested) | `Parser.Witness<Input, Output, Failure>` | ⚠️ nested as `Parser.Witness`, not yet promoted to top-level `Parse<…>` |
| Attachable | `Sources/Parser Primitives Core/Parseable.swift:8–32` | ✅ |
| Result builder | `Sources/Parser Primitives Core/Parser.Builder.swift:19` | ✅ |
| Pair conformance | `Sources/Parser Pair Primitives/Pair+Parser.Protocol.swift` | ✅ (added 2026-05-22) |
| Pair printer conformance | `Sources/Parser Pair Primitives/Pair+Parser.Printer.swift` | ✅ (added 2026-05-22) |
| Parity test | `Tests/Parser Pair Primitives Tests/Pair as Parser Tests.swift` | ✅ (passing 2026-05-22) |
| Witness promotion to top-level `Parse` | — | ❌ not yet done |

The remaining migration for parser-primitives:
1. Add `Sources/Parser Primitives Core/Parse.swift` with the top-level witness.
2. Make `Parser.Witness` a deprecated typealias to `Parse` for source compat.
3. Update consumer call sites incrementally.
4. After soak period, delete `Parser.Witness` typealias.

For a new pilot package (e.g., `swift-sequencer-primitives`), apply the full pattern fresh per the Migration Checklist.

---

## 14. Pilot Application Notes

When applying this pattern to a pilot package:

### 14.1 Choose the pilot scope

Reasonable pilots:
- **`swift-sequencer-primitives`** (rename from `swift-sequence-primitives`) — biggest payoff because Sequence is the most central abstraction; replaces compound-name proliferation. Heaviest rename.
- **`swift-validator-primitives`** (new domain) — clean slate, no migration; good to test the pattern on a fresh domain.
- **`swift-formatter-primitives`** (existing) — moderate scope; good if Format/Formatter is more mature than Sequence.

### 14.2 Steps for the pilot

1. **Read this document end-to-end.** Internalize the triple, naming rule, and decision tree.
2. **Read the prerequisite skills** listed in Section 1.3.
3. **Survey the package's current state.** Match each element against the migration checklist (Section 11).
4. **Write a brief migration plan** (file + line-level changes) before editing. Get the principal to validate the plan.
5. **Apply changes per the checklist** in phases A → B → C → D. Commit + verify between phases.
6. **Document any new exceptions** you find (e.g., overloaded verbs you encounter). Update Section 3's table in this document.
7. **Report back** with a summary: what was renamed, what was added, what was removed, what's deferred. Link to the parity tests as proof of behavior preservation.

### 14.3 What the pilot should NOT do

- Do not extract Map/FlatMap or other variance-sensitive combinators into shared infrastructure.
- Do not invent new shape primitives (e.g., do not create `Combine.Pair` — `Pair` already exists).
- Do not rename combinators from verb-as-noun form (`Parser.Map`) to gerund (`Parser.Mapping`). The combinator naming is settled at verb-as-noun.
- Do not delete pre-existing combinators without migration. Keep them as deprecated aliases during soak.
- Do not change the agent protocol's method identifier mid-migration. If the existing method is `parse(_:)`, the witness is `Parse`; do not rename to `parsing(_:)` to fit a different witness name.

### 14.4 When to stop and ask

Stop and surface to the principal when:
- You find a combinator that doesn't fit Section 8's decision tree.
- You find an overloaded verb that doesn't have an obvious domain-term substitute.
- You find a `Body`-type interaction that can't be satisfied by Never or by the shape-primitive composition.
- You find existing usage that would break if the witness moved to top level.
- Any cross-package conformance you'd add would create an overlap with another conformance the package already has.

---

## 15. References

Skills:
- `swift-institute/Skills/code-surface/` — `[API-NAME-*]`, `[API-ERR-*]`, `[API-IMPL-*]`
- `swift-institute/Skills/swift-institute/` — layering
- `swift-institute/Skills/primitives/` — primitives layer
- `swift-institute/Skills/modularization/` — per-target, cross-package conformances
- `swift-institute/Skills/testing-swiftlang/` — swift-testing
- `swift-institute/Skills/testing-institute/` — institute test patterns
- `swift-institute/Skills/documentation/` — DocC, inline comments
- `swift-institute/Skills/readme/` — package READMEs

Blog posts:
- `swift-institute/Blog/Published/2026-05-11-introducing-pair-either-product-primitives.md`
- `swift-institute/Blog/Published/2026-05-12-the-missing-fourth-corner.md`

Research:
- `swift-institute/Research/escapable-support-pair-either-product.md`

Existing implementations:
- `swift-parser-primitives` — partial implementation, see Section 13.
- `swift-serializer-primitives` — analogous shape, less mature combinator surface.
- `swift-coder-primitives` — leaf refinement of Parser + Serializer; no combinators.

---

## 16. Changelog

- **2026-05-22**: Initial draft. Captures the agent-witness-attachable triple, naming rule (verb form with domain-term exception), shape-primitive composition (Pair/Either/Product/Coproduct), and parser-primitives partial-implementation reference.
