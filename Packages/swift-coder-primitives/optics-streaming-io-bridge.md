# Optics for Streaming I/O — Bridge Design

<!--
---
version: 1.1.0
last_updated: 2026-03-05
status: RECOMMENDATION
tier: 2
---
-->

## Context

`swift-optic-primitives` provides a complete optics hierarchy:

```
                    Iso
                   /   \
                Lens   Prism
                   \   /
                  Affine
                     |
                 Traversal
```

All optics are **pure**: closures are `@Sendable (A) -> B` with no effects.
`Coder.Protocol` is **effectful streaming**: `inout` consumption, typed throws,
`~Copyable & ~Escapable` inputs. They share algebraic structure but inhabit
different computational contexts.

| | `Optic.Prism<Whole, Part>` | `Coder.Protocol` |
|-|---------------------------|-------------------|
| **Inject** | `embed: (Part) → Whole` | `encode(_:into:) throws(E)` |
| **Extract** | `extract: (Whole) → Part?` | `decode(_:) throws(E) → Output` |
| **Failure** | `Optional` (absent = failed) | Typed throws |
| **State** | None (pure) | `inout` consumption/accumulation |
| **Types** | `~Copyable` not supported | `DecodeInput: ~Copyable & ~Escapable` |
| **Storage** | `@Sendable` closures | Protocol witnesses |

### Trigger

[RES-001] Architecture choice — the existence of `swift-optic-primitives` with
`Optic.Prism` structurally mirrors `Coder.Protocol`. Determining how optics can
serve the streaming I/O domain requires systematic analysis before implementing
any bridge or extension.

### Prior Art

- **Profunctor optics** (Pickering, Gibbons, Wu 2017): parameterize optics over
  profunctors to abstract over computational context (pure, effectful, linear)
- **Haskell `lens`** (Kmett): `Prism'` via `Choice` profunctor; effectful variants
  via `PrismM` in some libraries
- **Swift Composable Architecture** (Point-Free): `CasePath` = effectful prism with
  `embed`/`extract`, later made throwing
- **Rust `serde`**: trait-based, no optics connection

## Question

What design enables `swift-optic-primitives` to be useful for streaming I/O
(coding, parsing, serialization), and where should the integration surface live?

---

## Analysis

### Option A: Pure Bridge — Optics Unchanged, Integration Module Adapts

Keep `swift-optic-primitives` exactly as-is. Create bridge types in a satellite
module that use optics to transform coders.

**`Coder.Iso<Base, NewOutput>`** — Isomorphism adapter:

```swift
extension Coder {
    public struct Iso<Base: Coder.Protocol, NewOutput>: Coder.Protocol, Sendable
    where Base: Sendable {
        public let base: Base
        public let iso: Optic.Iso<Base.Output, NewOutput>

        public typealias DecodeInput = Base.DecodeInput
        public typealias EncodeBuffer = Base.EncodeBuffer
        public typealias Output = NewOutput
        public typealias DecodeFailure = Base.DecodeFailure
        public typealias EncodeFailure = Base.EncodeFailure

        public func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> NewOutput {
            iso.forward(try base.decode(&input))
        }

        public func encode(_ output: NewOutput, into buffer: inout EncodeBuffer) throws(EncodeFailure) {
            try base.encode(iso.backward(output), into: &buffer)
        }
    }
}
```

**`Coder.Prism<Base, NewOutput>`** — Prism adapter (adds extraction failure):

```swift
extension Coder {
    public struct Prism<Base: Coder.Protocol, NewOutput>: Coder.Protocol, Sendable
    where Base: Sendable, Base.Output: Sendable {
        public let base: Base
        public let prism: Optic.Prism<Base.Output, NewOutput>

        public typealias DecodeInput = Base.DecodeInput
        public typealias EncodeBuffer = Base.EncodeBuffer
        public typealias Output = NewOutput
        // Decode failure: base decode OR prism extraction
        public typealias DecodeFailure = ???
        public typealias EncodeFailure = Base.EncodeFailure

        public func decode(_ input: inout DecodeInput) throws(DecodeFailure) -> NewOutput {
            let raw = try base.decode(&input)         // throws Base.DecodeFailure
            guard let value = prism.extract(raw) else {
                throw ???                              // prism extraction failed
            }
            return value
        }

        public func encode(_ output: NewOutput, into buffer: inout EncodeBuffer) throws(EncodeFailure) {
            try base.encode(prism.embed(output), into: &buffer)
        }
    }
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Optic-primitives changes | None |
| Dependency direction | Bridge → Optic + Coder (both stay independent) |
| Iso adapter | Clean, single-expression, no error composition |
| Prism adapter | **Problem**: decode has two failure domains (base + extraction). Typed throws requires a single error type. Needs `Either<Base.DecodeFailure, Extraction.Error>` or similar |
| Lens adapter | Requires default `Whole` for encode — limited utility |
| Traversal adapter | Requires sequential decode of N elements — approaches Builder territory |
| Composability | Manual — no `>>>` between optics and coders |
| Practical value | **High** for Iso, **Medium** for Prism, **Low** for Lens/Traversal |

**Iso is the clear winner.** It's the most common transform: newtype wrappers,
`RawRepresentable`, unit conversions. No error composition needed.

The Prism adapter's error composition problem is real but solvable with
`Parser.Error.Either` from parser-primitives (which already exists for exactly
this purpose). However, that adds another dependency.

---

### Option B: Throwing Prism — New Optic Type

Add a prism variant with typed failure instead of `Optional`:

```swift
extension Optic {
    public struct Throwing {}
}

extension Optic.Throwing {
    public struct Prism<Whole, Part, Failure: Error & Sendable>: Sendable {
        public let embed: @Sendable (Part) -> Whole
        public let extract: @Sendable (Whole) throws(Failure) -> Part

        @inlinable
        public init(
            embed: @escaping @Sendable (Part) -> Whole,
            extract: @escaping @Sendable (Whole) throws(Failure) -> Part
        )
    }
}
```

This preserves the pure, value-level nature of optics while adding typed failure.
The `extract` is still a pure function (no `inout`, no state) — it just fails
with a typed error instead of returning `nil`.

**Conversion**:
```swift
extension Optic.Throwing.Prism where Failure == Optic.Extraction.Error {
    init(_ prism: Optic.Prism<Whole, Part>) {
        self.init(
            embed: prism.embed,
            extract: { whole in
                guard let part = prism.extract(whole) else {
                    throw .extractionFailed
                }
                return part
            }
        )
    }
}
```

**Coder bridge with Throwing.Prism**:
```swift
extension Coder {
    public struct PrismAdapted<Base: Coder.Protocol, NewOutput, E: Error & Sendable>:
        Coder.Protocol, Sendable where Base: Sendable
    {
        public let base: Base
        public let prism: Optic.Throwing.Prism<Base.Output, NewOutput, E>

        // DecodeFailure = Either<Base.DecodeFailure, E>
        // Clean composition: both sides have typed errors
    }
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Optic-primitives changes | Additive (new type, no breaking changes) |
| Theoretical soundness | ✓ Throwing.Prism is well-founded — same laws, typed failure channel |
| Composition | Throwing.Prism ∘ Throwing.Prism = Throwing.Prism (with composed error) |
| Iso relationship | `Optic.Iso` = `Optic.Throwing.Prism where Failure == Never` |
| `Optic.Prism` bridge | Trivial conversion via guard-let |
| Streaming applicability | Helps with error typing but NOT with `inout` streaming |
| Naming | `Optic.Throwing.Prism` follows [API-NAME-001] Nest.Name |

**This type is independently useful beyond coder-primitives.** It models any
partial extraction with typed failure — enum case extraction, validation, parsing
of complete values. It's the typed-error analog of the existing `Optional`-based
prism.

**Gap**: Still doesn't address the `inout` streaming aspect. A
`Optic.Throwing.Prism` operates on complete values, not streaming input. The
bridge still needs a `Coder` wrapper to thread `inout`.

---

### Option C: Effectful Optic — Streaming Prism

Add an optic that directly models streaming bidirectional I/O:

```swift
extension Optic {
    public struct Streaming {}
}

extension Optic.Streaming {
    public struct Prism<
        DecodeInput: ~Copyable & ~Escapable,
        EncodeBuffer,
        Value,
        DecodeFailure: Error & Sendable,
        EncodeFailure: Error & Sendable
    >: Sendable {
        public let decode: @Sendable (inout DecodeInput) throws(DecodeFailure) -> Value
        public let encode: @Sendable (Value, inout EncodeBuffer) throws(EncodeFailure) -> Void
    }
}
```

**Problem**: `@Sendable` closures cannot capture `~Escapable` types. And
`@escaping` closures with `inout` parameters to `~Copyable & ~Escapable` types
face severe compiler restrictions. The closure `(inout DecodeInput) -> Value`
where `DecodeInput: ~Copyable & ~Escapable` may not be storable.

**Experiment needed**: Can Swift 6.2 store `@Sendable (inout T) -> U` where
`T: ~Copyable & ~Escapable`?

Even if it compiles, this type is structurally **identical to `Coder.Protocol`
as a struct**. It doesn't compose with the pure optics hierarchy in any
meaningful way — you can't do `Optic.Iso >>> Optic.Streaming.Prism` because
they operate on different computational levels.

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Optic-primitives changes | New type family |
| Compiler feasibility | **Uncertain** — `~Copyable & ~Escapable` in stored closures |
| Composition with pure optics | **Broken** — different arrow types can't compose via `>>>` |
| Redundancy | **High** — isomorphic to `Coder.Protocol` witness struct |
| Value-add over Coder.Protocol | None — same structure, different name |

**Rejected**: This duplicates `Coder.Protocol` without adding composability.
The streaming context is fundamentally different from the pure optics context;
forcing them into one hierarchy creates confusion without benefit.

---

### Option D: Profunctor Parameterization

Generalize ALL optics over a computational context:

```swift
protocol OpticContext {
    associatedtype Arrow<A, B>
    static func identity<A>() -> Arrow<A, A>
    static func compose<A, B, C>(_ f: Arrow<A, B>, _ g: Arrow<B, C>) -> Arrow<A, C>
}

struct PureContext: OpticContext {
    typealias Arrow<A, B> = @Sendable (A) -> B
}

struct ThrowingContext<E: Error>: OpticContext {
    typealias Arrow<A, B> = @Sendable (A) throws(E) -> B
}

extension Optic {
    struct GenericPrism<Whole, Part, Ctx: OpticContext> {
        let embed: Ctx.Arrow<Part, Whole>
        let extract: Ctx.Arrow<Whole, Part>  // partiality encoded in Ctx
    }
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Theoretical elegance | **Maximum** — subsumes all variants |
| Swift expressivity | **Insufficient** — higher-kinded types (`Arrow<A, B>`) require workarounds. No native HKT in Swift |
| Ergonomics | **Poor** — users must specify context at every use site |
| Breaking change | **Yes** — existing `Optic.Prism<Whole, Part>` gains a parameter |
| Practical value | Low — complexity cost exceeds benefit in a Swift context |

**Rejected**: Swift doesn't have the type system features (HKT, associated type
families with multiple parameters) to make this ergonomic. The complexity is not
justified at the primitives layer.

---

### Synthesis: Two Viable Paths

**Path 1: Option A + B (conservative)** — additive, no breaking changes

1. `Optic.Throwing.Prism<W, P, F>` added to `swift-optic-primitives`
2. Bridge module in `swift-coder-primitives` adapts coders via optics
3. Two prism types coexist with conversion bridges

**Path 2: Option A + E (unified)** — breaking but cleaner

1. `Optic.Prism<W, P, F>` replaces current `Optic.Prism<W, P>` in `swift-optic-primitives`
2. `Optic.PrismOf<W, P>` typealias recovers ergonomics
3. Bridge module uses the unified prism directly — no conversion needed
4. Migration: 3 downstream consumers (finite, algebra-group, algebra-field)

**Both paths share the bridge module**:

```swift
// Given a UInt32 coder and an Iso between UInt32 and MyID:
let myIDCoder = uint32Coder.map(via: Optic.Iso(
    forward: MyID.init(rawValue:),
    backward: \.rawValue
))

// Given a coder for a broad enum and a prism to one case:
let specificCoder = broadCoder.narrow(via: Result<Int, MyError>.prisms.success)
```

| | Path 1 (A+B) | Path 2 (A+E) |
|-|-------------|-------------|
| Breaking change | No | Yes (3 consumers) |
| Types in optic-primitives | 2 prism types | 1 prism type + typealias |
| Composition `>>>` | Separate overloads per type | One set of overloads |
| Conversion bridges | Required | None |
| Long-term complexity | Higher (two parallel hierarchies) | Lower (unified) |

---

### Option E: Unified Prism with `PrismOf` Typealias

Instead of a separate `Optic.Throwing.Prism`, unify typed failure into the
existing `Optic.Prism` by adding a `Failure` generic parameter, and introduce
a `PrismOf` typealias to recover two-parameter ergonomics:

```swift
extension Optic {
    public struct Prism<Whole, Part, Failure: Error & Sendable>: Sendable {
        public let embed: @Sendable (Part) -> Whole
        public let extract: @Sendable (Whole) throws(Failure) -> Part
    }

    /// Ergonomic alias — recovers current two-parameter usage.
    public typealias PrismOf<Whole, Part> = Prism<Whole, Part, Extraction.Error>
}
```

The full spectrum collapses into one type:

| `Failure` | Behavior | Call-site recovery |
|-----------|----------|-------------------|
| `Never` | Infallible extraction | No `try` needed |
| `Optic.Extraction.Error` | Simple "not present" | `try?` → `Optional` |
| Domain-specific error | Typed failure context | `try` with typed `catch` |

**Since `Prism` remains the struct**, all existing patterns survive:

| Pattern | Status |
|---------|--------|
| `Prism.Accessible` (nested on struct) | ✓ Works |
| `Witness.Protocol` conformance | ✓ Works |
| `@dynamicMemberLookup` | ✓ Works |
| Pattern matching `~=` | ✓ `(try? extract(value)) != nil` |
| Extensions | ✓ Target the struct directly |

**`Accessible` return types** use the typealias:
```swift
extension Optional: Optic.Prism.Accessible {
    public struct Prisms: Sendable {
        public var some: Optic.PrismOf<Optional, Wrapped> { ... }
        public var none: Optic.PrismOf<Optional, Void> { ... }
    }
}
```

**Evaluation**:

| Criterion | Assessment |
|-----------|------------|
| Ergonomics | ✓ `PrismOf<W, P>` recovers two-parameter usage |
| One type, not two | ✓ No `Optic.Throwing.Prism` / `Optic.Prism` split |
| `Optic.Iso` relationship | `Optic.Prism<W, P, Never>` = infallible = Iso-like |
| Existing patterns | ✓ All survive (Accessible, Witness, dynamicMemberLookup, `~=`) |
| Breaking change | **Yes** — `Optic.Prism<W, P>` → `Optic.PrismOf<W, P>` or `Optic.Prism<W, P, E>` |
| Composition `>>>` | Needs error composition: `Prism<A,B,E1> >>> Prism<B,C,E2>` → `Prism<A,C,Either<E1,E2>>` |
| Coder bridge | Cleaner — prisms already carry typed error, no wrapping needed |

**Remaining blockers**:

1. **Error composition for `>>>`** — composing `Prism<A,B,E1> >>> Prism<B,C,E2>`
   requires a result error type. Options:
   - `Either<E1, E2>` — preserves both (needs `Optic.Error.Either` or similar)
   - Constrain `E1 == E2` — works for homogeneous chains
   - Provide both: unconstrained via Either, constrained via same-type overload

2. **Migration** — every `Optic.Prism<W, P>` site becomes `Optic.PrismOf<W, P>`
   or gains an explicit error. Mechanical but touches every consumer.

**Compared to Option B** (separate `Optic.Throwing.Prism`):

| | Option B (Two types) | Option E (Unified) |
|-|---------------------|-------------------|
| API surface | Two prism types | One prism type + typealias |
| Conversion between them | `init(_ prism:)` bridge | N/A — same type |
| Composition | Separate `>>>` overloads per type | One set of `>>>` overloads |
| Cognitive load | "Which prism do I use?" | One type, always |
| Breaking change | None (additive) | Yes (migration) |

**Assessment**: Option E is the **theoretically superior** design — one type
instead of two, unified composition, no conversion bridges. The cost is a
breaking migration of existing `Optic.Prism<W, P>` to `Optic.PrismOf<W, P>`.
Since `swift-optic-primitives` has only 3 downstream consumers (finite,
algebra-group, algebra-field), the migration is tractable.

---

### Open Questions

1. ~~**`Optic.Throwing` namespace**~~ — **Resolved by Option E**: No separate
   `Optic.Throwing` namespace needed. The unified `Optic.Prism<W, P, F>` absorbs
   the throwing variant directly.

2. ~~**Composition operator**~~ — **Resolved by experiment**: Four `>>>`
   overloads cover all cases:
   - Same-type: `Prism<A,B,E> >>> Prism<B,C,E> → Prism<A,C,E>`
   - Heterogeneous: `Prism<A,B,E1> >>> Prism<B,C,E2> → Prism<A,C,Either<E1,E2>>`
   - Never lhs: `Prism<A,B,Never> >>> Prism<B,C,E> → Prism<A,C,E>`
   - Never rhs: `Prism<A,B,E> >>> Prism<B,C,Never> → Prism<A,C,E>`

3. ~~**Error composition**~~ — **Resolved**: `Either<E1, E2>` for heterogeneous
   composition + same-type overload for homogeneous chains. Both compile and
   produce correct error routing. Requires explicit typed-throws closure
   annotations in the `mapThrow` helper (known Swift 6.2 limitation).

4. **Compiler validation for Option C**: Does `@Sendable (inout T) throws(E) -> U`
   where `T: ~Copyable & ~Escapable` compile as a stored property? (Academic
   interest only — Option C rejected regardless.)

5. **Throwing.Iso**: Should there be a `Optic.Iso<W, P, ForwardError, BackwardError>`?
   This would model bidirectional transforms where both directions can fail —
   exactly the shape of `Coder.Protocol` when both `DecodeFailure` and
   `EncodeFailure` are non-Never. Separate research if needed.

---

### Experiment Validation

**Experiment**: `swift-optic-primitives/Experiments/unified-throwing-prism/`
**Result**: CONFIRMED — all 32 checks pass (10 variants, 0 failures)
**Toolchain**: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4), macOS 26.2 (arm64)

Validated capabilities:

| Variant | What was tested | Result |
|---------|-----------------|--------|
| V1 | `Prism<W, P, F>` struct with typed throws closures | CONFIRMED |
| V2 | `PrismOf<W, P>` typealias (2-parameter ergonomics) | CONFIRMED |
| V3 | `Accessible` protocol nested on struct, aliased | CONFIRMED |
| V4 | Pattern matching `~=` via `try?` | CONFIRMED |
| V5 | `>>>` composition: same-type, heterogeneous Either, Never lhs/rhs | CONFIRMED |
| V6 | `Accessible` conformance for Optional + Result | CONFIRMED |
| V7 | `Prism<W, P, Never>` needs no `try` at call sites | CONFIRMED |
| V8 | Extensions on `PrismOf` target the underlying struct | CONFIRMED |
| V9 | `modify` methods with `inout` and `try?` | CONFIRMED |
| V10 | Identity prism with `Never` failure | CONFIRMED |

**Notable finding**: Typed throws closure inference in Swift 6.2 consistently
requires explicit annotation. The `mapThrow` helper's body closure needs
`{ () throws(E1) -> M in try lhs.extract(whole) }` — bare `{ try lhs.extract(whole) }`
infers `any Error`. This is a consumer ergonomics cost, not a blocker.

---

## Outcome

**Status**: RECOMMENDATION

**Recommended**: Path 2 (A+E) — unified `Optic.Prism<W, P, F>` with `PrismOf`
typealias. Empirically validated via experiment.

The unified design is confirmed to be compiler-feasible, preserve all existing
patterns, and provide clean composition with typed error routing. The one type
replaces two, eliminates conversion bridges, and unifies composition operators.

**Implementation roadmap**:

1. Add `Failure: Error & Sendable` parameter to `Optic.Prism` in swift-optic-primitives
2. Add `Optic.PrismOf<W, P>` typealias (= `Prism<W, P, Extraction.Error>`)
3. Add `Either<E1, E2>` for heterogeneous error composition
4. Add `>>>` overloads (same-type, heterogeneous, Never lhs/rhs)
5. Migrate 3 downstream consumers (finite, algebra-group, algebra-field) to `PrismOf`
6. Implement `Coder.Iso` bridge type in coder-primitives

## References

- `swift-primitives/swift-optic-primitives/` — Pure optics (Iso, Lens, Prism, Affine, Traversal)
- `swift-primitives/swift-coder-primitives/` — Streaming bidirectional coding
- `swift-institute/Research/transformation-domain-architecture.md` (v3.2.0, DECISION)
- `swift-primitives/swift-coder-primitives/Research/coder-primitives-core-api-surface.md` (v1.0.0)
- Pickering, Gibbons, Wu (2017). *Profunctor Optics: Modular Data Accessors*. arXiv:1703.10857
- `swift-parser-primitives/.../Parser.Either.swift` — `Parser.Error.Either` for error composition
