# Effect Primitives and IO Algebra: Relation and Modernization

<!--
---
version: 1.0.0
created: 2026-04-16
last_updated: 2026-04-16
status: RECOMMENDATION
tier: 2
related:
  - swift-primitives/swift-effect-primitives/
  - swift-foundations/swift-effects/
  - swift-foundations/swift-io/Experiments/io-algebra/
  - swift-foundations/swift-io/Research/io-witness-design-literature-study.md
  - swift-foundations/Research/effects-and-io-algebra-relation.md (peer, simultaneous)
---
-->

## 1. Context

**Trigger.** A fresh experiment at
`/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/`
(committed 2026-04-17) proposes a monadic `IO<Environment, LeafError, Value>`
type built around linear (`~Copyable`) semantics, zero `@Sendable`
function-type attributes, and three load-bearing value-level `Sendable`
constraints (`pure`, `fail`, `ask`). At the same time, the ecosystem already
hosts `swift-effect-primitives` (L1) and `swift-effects` (L3), which
implement algebraic effects via continuation-based handlers and
`Dependency.Scope`-backed task-local handler lookup.

Two effect infrastructures in the same workspace demand a clear answer:
are they competing designs? Layered designs? Or are they doing different
jobs that happen to share vocabulary?

**Scope.** This document is Tier 2 — cross-package analysis spanning
`swift-primitives` (L1: `swift-effect-primitives`) and
`swift-foundations` (L3: `swift-effects`, plus the fresh io-algebra
experiment). Recommendation-setting, not binding. A peer document in
`swift-foundations/Research/` covers the same question from the L3
side.

**Constraints.**
- Swift 6.3 toolchain features: `~Copyable`, `~Escapable`, `sending`,
  `isolated`, `consuming`, `borrowing`, typed throws, region-based
  isolation.
- Five-layer architecture boundary: effect-primitives is L1; effects,
  io, io-algebra are L3.
- `PRIM-FOUND-001` — no Foundation in L1.

**Stakeholders.** Consumers of both packages: the IO stack
(swift-io), cache/pool/parser primitives that currently cite
effect-primitives in their `Research/Algebraic Effects in Swift.md`,
and any future L3 package considering effect-based side-effect
management.

---

## 2. Question

Five related questions, resolved together:

1. What is the current public surface and theoretical foundation of
   `swift-effect-primitives`?
2. Does each side fully leverage Swift 6.3 memory/concurrency features?
3. Does `IO<Environment, LeafError, Value>` map structurally onto
   `Effect.Protocol` + `Effect.Handler.Protocol` + `Effect.Continuation.One`
   + `Effect.Context`?
4. Could io-algebra be defined as a specialization of
   effect-primitives, and should it?
5. Given the algebraic framing (monad laws, handler laws, runners
   calculus), which package is at the "right" abstraction level, and
   how should they coexist?

---

## 3. Current state of `swift-effect-primitives`

### 3.1 Public surface

Ten Swift files, 826 lines total. Source locations cited `path:line`.

| Type | File | Lines | Shape |
|---|---|---|---|
| `enum Effect` | `Effect.swift` | 30-35 | Namespace with `typealias Protocol = __EffectProtocol` |
| `protocol __EffectProtocol` | `Effect.Protocol.swift` | 37-49 | `Sendable` protocol with `Arguments`, `Value`, `Failure` associated types |
| `protocol __EffectHandler` | `Effect.Handler.swift` | 40-53 | `Sendable` with `handle(_:continuation:) async` |
| `typealias Effect.Handler.Sync` | `Effect.Handler.Sync.swift` | 33 | Alias of `__EffectHandler` |
| `protocol __EffectContinuation` | `Effect.Continuation.swift` | 27-48 | `~Copyable, Sendable` with three `resume` consuming methods |
| `struct Effect.Continuation.One<Value, Failure>` | `Effect.Continuation.One.swift` | 28-70 | `~Copyable, Sendable`; wraps `@Sendable (sending Result<Value, Failure>) async -> Void` |
| `struct Effect.Continuation.Multi<Value, Failure>` | `Effect.Continuation.Multi.swift` | 34-75 | `Sendable`, copyable multi-shot |
| `struct Effect.Context` | `Effect.Context.swift` | 46-48 | Thin wrapper over `Dependency.Scope` |
| `enum Effect.Outcome<Value, Failure>` | `Effect.Outcome.swift` | 31-40 | `resumed(Value) | threw(Failure) | aborted` |
| `enum Effect.Perform` | `Effect.perform.swift` | 47 | Marker; real `perform` lives in L3 swift-effects |

**Hoisted protocol pattern.** Because Swift forbids protocol
declarations nested inside generic types, the package uses the
`__EffectProtocol` / `Effect.Protocol` typealias pattern
(`Effect.Protocol.swift:35-37`; `Effect.swift:34`). Callers see
`Effect.Protocol`; the compiler sees `__EffectProtocol`. Same for
`__EffectHandler` and `__EffectContinuation`.

**Handler signature**
(`Effect.Handler.swift:47-52`):

```swift
func handle(
    _ effect: Handled,
    continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>
) async
```

**Context** (`Effect.Context.swift:46-157`): thin wrapper over
`Dependency.Scope` (from `Dependency_Primitives`). `Effect.Context.Key`
is a typealias for `Dependency.Key`. Provides `with(_:operation:)` in
both sync (typed-throws) and async
(`nonisolated(nonsending)`) flavors.

**Continuation.One**
(`Effect.Continuation.One.swift:28-70`): `~Copyable, Sendable`; stores
one field `_resume: @Sendable (sending Result<Value, Failure>) async -> Void`
(line 30). Has `consuming func resume(returning:) async`,
`resume(throwing:) async`, `resume(with:) async`. Has
`onResume(_:) -> One<Value, Failure>` requiring `Value: Sendable`
(line 73-102).

### 3.2 Theoretical foundation (claimed)

`Research/Algebraic Effects in Swift.md` (dated 2026-01-18)
positions the package in the Plotkin-Pretnar tradition:

- Lines 14-19: cites Plotkin & Power 2003 on computational effects;
  Plotkin & Pretnar 2009 on effect handlers.
- Lines 26-30: effect signature `{ op₁ : A₁ → B₁, ..., opₙ : Aₙ → Bₙ }`
  maps to `associatedtype Arguments` → `Value` pair.
- Lines 47-58: handlers receive a `consuming Effect.Continuation.One`
  — one-shot by construction, move-only enforced.
- Lines 64-73: flat composition via task-local handler stack, not
  monadic transformers.
- Lines 354-358: comparison with Koka (row-polymorphic effects) and
  OCaml 5 (native effects) — Swift impl is library-based, lacks
  effect rows.

The claim is: **algebraic effects in the Plotkin-Pretnar sense,
implemented as a library using task-local handler dispatch and
`~Copyable` continuations for linearity.** Multi-shot is supported
(`Continuation.Multi`) for backtracking/probabilistic workloads but
marked as slower.

### 3.3 Current ownership and concurrency annotations

| Feature | Used? | Where |
|---|---|---|
| `~Copyable` | Yes | `__EffectContinuation` (line 27), `Continuation.One` (line 28) |
| `~Escapable` | No | Nowhere |
| `sending` | Yes | Return types of `resume(returning:)` value parameter (`Continuation.One.swift:46`), result parameter (`.swift:94`, `.swift:47` proto), `Context.with` operation parameter (`Context.swift:138`) |
| `isolated` | No | Nowhere. `Context.with(async)` uses `nonisolated(nonsending)` instead |
| `consuming` | Yes | All resume methods (`Continuation.One.swift:46, 56, 66, 109, 122, 132`); all `Continuation` protocol requirements (`.swift:37, 42, 47`); `handle(_:continuation:)` parameter (`Handler.swift:51`) |
| `borrowing` | No | Nowhere |
| Typed throws | Partial | `Effect.Context.with` has typed throws (line 103); Handler's `handle` returns async `-> Void` and passes failure through `resume(throwing:)` — the Failure type is typed, but the async method itself is non-throwing |
| `@Sendable` function-type attribute | Heavy use | Every stored closure (`Continuation.One.swift:30, 36`; `Continuation.Multi.swift:36, 42`); every public `one`/`multi` factory (`perform.swift:61, 74`) |
| Value-level `Sendable` | Heavy | `Arguments`, `Value` associated types require `Sendable` (Protocol.swift:39, 42); all effect operations treated as Sendable payloads |
| `@unchecked Sendable` | No | Not used anywhere — the package is clean |

### 3.4 Dependency structure

`Package.swift` shows one dependency: `swift-dependency-primitives`,
imported as `public import Dependency_Primitives` in
`Effect.Context.swift:1`. `.strictMemorySafety()` enabled (Package.swift:42).
Swift language mode v6, with experimental `Lifetimes`,
`LifetimeDependence`, `SuppressedAssociatedTypes` enabled, and upcoming
`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`
(Package.swift:41-51).

**Verified 2026-04-16**: All citations above re-read against the
current source files. The package has not changed since last
modification in March; the public surface, imports, and theoretical
commitments are accurate.

---

## 4. Modernization needs on the `swift-effect-primitives` side

This section flags concrete gaps against Swift 6.3 best practices and
memory-safety conventions. Each is cited against current source and
proposes a change.

### 4.1 `@Sendable` closures are over-propagated — should consider `~Copyable` handlers

**Finding.** `Continuation.One._resume` is stored as
`@Sendable (sending Result<Value, Failure>) async -> Void`
(`Continuation.One.swift:30`). Because `One` is itself `~Copyable`, the
same region-checker argument made by io-algebra applies here: a
non-aliasable, move-only container does not need its stored closure to
be `@Sendable` — `sending One` at transfer sites is enough.

**Current state cited**: `Continuation.One.swift:28` declares
`struct One<Value, Failure: Error>: ~Copyable, Sendable`. The
`~Copyable` contract means no copying; `Sendable` adds cross-isolation
transferability. The stored `_resume` closure is `@Sendable`
(line 30), which forces its captures to be `Sendable` — a strictly
stronger requirement than the move-only invariant justifies.

**Proposal.** Evaluate dropping `@Sendable` from the stored closure,
following the io-algebra experiment's hypothesis (io-algebra's
`IO.swift:87-91` documents exactly this argument: "the stored closure
does NOT need `@Sendable` because `~Copyable IO` cannot be aliased, so
the closure is never invoked from multiple regions concurrently").

**Caveat.** `Continuation.Multi` is copyable, so its closure must remain
`@Sendable`. The proposal applies only to `One`. This widens the type
of closures the user can pass to `Effect.Continuation.one(_:)` — some
existing call sites may rely on the `@Sendable` narrowing for their
own inference — so this is a breaking-change-in-intent that needs
experimental confirmation.

**Severity**: MEDIUM. Improves ergonomics on the effect side, aligns
with io-algebra's design, but needs empirical validation that the
region checker indeed accepts `sending One` as sufficient region
evidence.

### 4.2 Handler protocol uses `async` + `@Sendable`-capture semantics — could move to `sending` regions

**Finding.** `__EffectHandler.handle` is declared
`async` (`Handler.swift:49-52`). With
`NonisolatedNonsendingByDefault` enabled (which the package does —
Package.swift:45), async methods on non-isolated types are
nonisolated-nonsending by default. But the handler is `Sendable`
(line 40), so the implicit isolation is lost. The package has not
adopted any `isolated Actor` parameter pattern to let handlers borrow
`~Copyable` state across isolation boundaries.

**Proposal.** When the runner calls into a handler, it may wish to do
so while borrowing actor-owned state (a connection pool, a file
descriptor, etc.). Current shape forces the handler to pull dependencies
from `Effect.Context.current` (which only supports `Sendable` values —
see the Context wrapping in `Effect.Context.swift:70-72`, which
typealises `Dependency.Values`).

A modern handler protocol could offer an overload with an
`isolated (any Actor)?` parameter, letting the runner pass its
own isolation down, enabling borrowed access to non-Sendable resources.
This is
a pattern already in use across swift-foundations (see feedback
`feedback_isolated_param_for_borrowing_noncopyable.md`).

**Severity**: MEDIUM. Not a bug — works today — but a missed
modernization opportunity that would let handlers access non-Sendable
state held by the calling actor.

### 4.3 `Effect.Outcome` requires `Value: Sendable` without clear justification

**Finding.** `Effect.Outcome<Value: Sendable, Failure: Error>`
(`Effect.Outcome.swift:31`). The outcome is a pure enum — `resumed`,
`threw`, `aborted`. Nothing about the three cases inherently requires
`Value: Sendable`. The type is Copyable (line 104 conditionally
Equatable/Hashable).

**Proposal.** Drop the `Sendable` constraint on `Value`. The
`Equatable`/`Hashable` conditional conformances (lines 103-104) should
remain. The `init(_:Result)` (line 49) and `result` computed property
(line 61) do not require Sendable.

**Severity**: LOW. Cosmetic constraint tightening that blocks
reasonable use in non-Sendable contexts.

### 4.4 `~Copyable` leverage does not extend to `Effect` instances, `Handler`s, or `Context`

**Finding.** `Effect.Protocol` requires `Sendable` (Protocol.swift:37)
but says nothing about `~Copyable`. `__EffectHandler` similarly
(Handler.swift:40). Users cannot define a handler whose internal state
is a `~Copyable` resource (e.g., an owning file descriptor).

**Proposal.** Suppress `Copyable` on the effect protocol's
`Arguments` and `Value` associated types using
`~Copyable` (now that `SuppressedAssociatedTypes` is enabled in
Package.swift:49). This mirrors the language-evolution direction that
`Research/Algebraic Effects in Swift.md:186-198` explicitly cites as
future work:

```swift
public protocol __EffectProtocol: ~Copyable {
    associatedtype Arguments: ~Copyable & Sendable = Void
    associatedtype Value: ~Copyable & Sendable
    associatedtype Failure: Error = Never
    var arguments: Arguments { borrowing get }
}
```

And allow a handler to be `~Copyable`:

```swift
public protocol __EffectHandler: ~Copyable, Sendable { ... }
```

**Caveat.** Pool and resource primitives currently work around this
limitation with `Reference.Box` (see the research document
at `Research/Algebraic Effects in Swift.md:201-220`). Relaxing the
constraint would let those packages drop the wrapper. But existing
call sites would need a migration pass.

**Severity**: HIGH. This is the primary expressiveness gap.
`swift-effect-primitives` is L1, so any future L3 package using it
inherits these constraints. The package's own research note cites
this as a known limitation (line 184-198) and flags language
evolution; the language has since evolved (6.3 +
`SuppressedAssociatedTypes`), and the package has not caught up.

### 4.5 Typed throws are only partially adopted

**Finding.** `Effect.Context.with` correctly uses typed throws
(lines 100-104, 136-141). But `__EffectHandler.handle` is
`async` (non-throwing, line 52) — failures flow through
`continuation.resume(throwing:)` instead. This is a legitimate design
choice (handlers can choose to abort rather than rethrow), but it
means no typed-throws inference across the handler boundary.

**Proposal.** Consider a `handle` variant with typed throws:

```swift
func handle(
    _ effect: Handled,
    continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>
) async throws(Handled.Failure)
```

Where the continuation's `resume(throwing:)` becomes an alternative
path (handler may throw directly or route through the continuation).
This aligns with the memory `feedback_throws_not_result.md`
("Callback outcomes use `() throws(E) -> T` thunks, not `Result`").

**Severity**: LOW. The current design is internally consistent. Adding
typed throws to `handle` is additive flexibility, not a correctness
fix.

### 4.6 `Effect.perform` is a stub in the L1 package

**Finding.** `Effect.perform.swift:1-4` admits "The actual perform
implementation requires integration with a runtime layer ... This file
defines the shape and documents the intended semantics. The
swift-effects package builds on these primitives to provide the full
implementation." The `Perform` enum (line 47) has no members.

**Assessment.** This is correct L1/L3 layering: L1 provides
vocabulary, L3 provides runtime. Not a modernization gap, but worth
noting for completeness.

---

## 5. Current state of io-algebra (brief)

### 5.1 Public surface

Seven source files in `swift-io/Experiments/io-algebra/Sources/`,
totalling ~200 lines. Organized by algebraic role:

| File | Role | Key declarations |
|---|---|---|
| `IO.swift` | Core type | `struct IO<Environment, LeafError, Value>: ~Copyable` (line 85); stored `_run` closure (line 91); `init` and `consuming run` |
| `IO.Monad.swift` | Functor + Monad | `IO.pure` (line 24, static, `where Value: Sendable`); `consuming map` (line 48); `consuming flatMap` (line 63); `consuming andThen` (line 79) |
| `IO.Applicative.swift` | Applicative | `consuming zip` (line 16, `where Value, Other: Copyable`) |
| `IO.Reader.swift` | Reader monad | `consuming provide` (line 16); `consuming local` (line 31); module-scope `func ask` (line 52, `where Environment: Sendable`) |
| `IO.Error.swift` | Error algebra | `consuming mapError` (line 13); `consuming catchAll` (line 31); `consuming orElse` (line 49); `consuming recover` (line 69) |
| `IO.Factories.swift` | Factories | `IO.fail` (line 13, `where LeafError: Sendable`); `IO.from` (line 31) |
| `IO.Traversal.swift` | Traversal | Comment-only — no `sequence`/`traverse` because Swift stdlib `Array` doesn't hold `~Copyable` elements |
| `main.swift` | Demo | End-to-end example wiring `map`/`flatMap`/`mapError`/`provide`/`run`, `local`, `orElse`, `recover`, manual flatMap sequencing |

### 5.2 Ownership and concurrency annotations

Reading the type header (`IO.swift:85-105`) and `main.swift`:

| Feature | Used? | Where |
|---|---|---|
| `~Copyable` | Yes | `IO` declaration (`IO.swift:85`) |
| `~Escapable` | No | Not used — discussed in `IO.Traversal.swift` as a future direction |
| `sending` | Yes, heavily | Return position of `_run` (`IO.swift:91`), `run` (line 102); all combinators return `sending Value` or `sending New` (Monad.swift, Error.swift, Reader.swift, Factories.swift) |
| `isolated` | No | Not used |
| `consuming` | Yes, systematically | All combinators consume self: `map` (line 48), `flatMap` (63), `mapError`, `catchAll`, `orElse`, `recover`, `provide`, `local`, `zip`, `andThen`. Combinator parameters use `consuming sending Value` in transforms |
| `borrowing` | Yes | `_run` and `run` take `borrowing Environment` |
| Typed throws | Yes | `_run` and `run` use `throws(LeafError)`; `mapError` correctly rethrows with new typed error; `catchAll`/`recover` collapse to `throws(Never)` |
| `@Sendable` function-type attribute | **Zero occurrences** | This is the design's key property, documented `IO.swift:86-90` |
| Value-level `Sendable` | Three load-bearing sites | `pure` (Monad.swift:27), `fail` (Factories.swift:17), `ask` (Reader.swift:54) |
| `@unchecked Sendable` | No | Not used anywhere |

### 5.3 Theoretical positioning

The experiment header (`IO.swift:1-28`) cites:
- Wadler 1990 "Linear Types Can Change the World!" — linearity
- Bernardy et al. 2018 "Linear Haskell" — practical linear types
- Ahman & Bauer 2020 "Runners in Action" — one-shot resource runners
- OCaml Eio's `~once` effects — single-use effect handlers

This is a **linear** reading of the IO monad, explicitly not the
classical lazy-evaluated Haskell `IO` (which is copyable). It is
closer to `Eio.t` (OCaml) or the Runners calculus than to
GHC's `IO`.

**Laws.** The monad laws are stated as denotational equivalences on
fresh values (`IO.Monad.swift:5-13`). Because `~Copyable` precludes
aliasing, the usual `io.flatMap(pure) ≡ io` is re-interpreted: both
sides are fresh constructions producing equivalent observable behavior
when run, not identical values.

---

## 6. Modernization needs on the io-algebra side

io-algebra is a fresh experiment, so "modernization" means flagging
gaps before it ossifies.

### 6.1 `Value: Sendable` on `pure`, `fail`, `ask` — documented but worth scrutiny

**Finding.** Three value-level `Sendable` constraints are documented
as "load-bearing under Swift 6.3 region-checker rules":
- `pure` (`IO.Monad.swift:27-41`): captures the value into a closure
  that returns it as `sending Value`. Region checker demands proof the
  copy is safe.
- `fail` (`IO.Factories.swift:17`): same as pure, but for
  `LeafError`.
- `ask` (`IO.Reader.swift:54-65`): copies the borrowed environment
  parameter into a `sending` return, which requires `Sendable` to
  disconnect regions.

**Assessment.** These are not workarounds — they are semantic
requirements. Reader's `ask` fundamentally needs the environment to be
reproducible as a disconnected value; `pure` needs the stored value
to be emittable across isolation boundaries.

**Proposal.** Document in the experiment header that these are
genuine semantic constraints, not Swift limitations. Consider whether
a separate `IO.local` variant could relax them when the region is
statically known — probably not worth the complexity.

**Severity**: INFO. Not a gap; confirming the design is correct.

### 6.2 No `isolated` parameter for actor-bound runs

**Finding.** `IO.run(_:)` (`IO.swift:100-104`) has no isolation story.
An IO built in actor context, transferred to a task, then `run` from
a different isolation — the stored closure captures whatever was
in scope at construction. If those captures touch non-Sendable actor
state, the user has no way to express "run this IO back on my actor."

**Proposal.** Offer an `isolated` variant:

```swift
public consuming func run(
    _ env: borrowing Environment,
    isolation: isolated (any Actor)? = #isolation
) async throws(LeafError) -> sending Value {
    try await _run(env)
}
```

This would let the caller pin execution to their own isolation, which
matters when `Environment` or `Value` contain non-Sendable
actor-owned resources. Per
`feedback_isolated_param_for_borrowing_noncopyable.md`: "`isolated Actor`
parameter for borrowing ~Copyable across actor boundaries; no closure
needed."

**Severity**: MEDIUM. The experiment is new, so this is
forward-looking. Without this, io-algebra forces the hot closure to
carry its own isolation, which is the `@Sendable` trap the design
explicitly avoids.

### 6.3 `zip` requires `Value, Other: Copyable` — can `~Copyable` tuples be simulated?

**Finding.** `IO.zip` (`IO.Applicative.swift:16-29`) returns
`IO<Environment, LeafError, (Value, Other)>` and constrains both to
`Copyable` because Swift 6.3 tuples cannot hold `~Copyable`
elements (line 18-20 comment).

**Proposal.** Add a parallel `zipInto<Pair>(other:, combine:)`
combinator that takes a pair constructor:

```swift
public consuming func zip<Other, Pair: ~Copyable>(
    _ other: consuming IO<Environment, LeafError, Other>,
    into combine: @escaping (consuming sending Value, consuming sending Other) -> sending Pair
) -> IO<Environment, LeafError, Pair>
```

This preserves `~Copyable` payloads through the applicative layer. The
current comment implies this should "compose via flatMap and a named
pair struct," but the combinator makes it one-liner.

**Severity**: LOW. Quality-of-life; real cost only when a consumer
hits `~Copyable` payloads.

### 6.4 No `Effect.Context`-style dependency injection

**Finding.** io-algebra has `Environment` as an explicit type
parameter. This is a principled choice (Reader monad), but it means a
tower of combinators (`provide`, `local`) to adapt environments. No
task-local lookup, no scoped dependency injection.

**Proposal.** Consider whether io-algebra should integrate with
`Dependency_Primitives` (the same crate effect-primitives uses). A
`IO.ask(_ key: Dependency.Key.Type)`-style combinator would bridge
the Reader algebra to the ambient dependency scope.

**Caveat.** This crosses layers: io-algebra is a foundation-layer
experiment; `Dependency_Primitives` is L1. The import is legal. But it
intermixes two abstraction philosophies (explicit Reader vs.
task-local ambient), which is a non-trivial design commitment.

**Severity**: INFO. Design question, not a gap. Defer until the
experiment either graduates or is superseded.

### 6.5 No documented handler/runner story for side effects

**Finding.** io-algebra has no handler concept. `run` executes the
stored closure. Side effects inside that closure are unmanaged.

**Assessment.** This is by design — io-algebra is a _pure_ algebraic
layer. Side effects happen via captures in the closure. There is no
"install a mock handler, run the IO, observe calls" path.

**Proposal.** If io-algebra wants to support testing-grade observation
without building a full effect-handler machinery, one option is to
expose the stored `_run` closure via a package-visible accessor so
test support can wrap it. Not a modernization issue per se.

**Severity**: INFO. Scope clarification only.

### 6.6 `~Escapable` for borrowed views into IO results?

**Finding.** No use of `~Escapable` anywhere. The `Value` type is
always fully owned.

**Proposal.** For read-heavy IOs (parse this byte range, return a
`Span<UInt8>` into it), `~Escapable` return types would enforce
lifetime-bounded borrows. But this requires:
- `IO` to be generic over a lifetime source, or
- `run` to take a closure receiving the `~Escapable` value
  (`with*` pattern).

Per `feedback_escapable_over_with_closures.md`: "Don't add with* APIs;
use ~Escapable — current infrastructure, not future." So the
preferred shape is `IO<Env, E, View<Element>>` where `View` is
`~Escapable` and lifetime-bound to the source.

**Severity**: MEDIUM for forward-looking design. Worth prototyping
before the experiment commits to a final `Value` shape.

---

## 7. Structural relation

Side-by-side, the two packages address **different axes** of effect
management.

| Axis | `swift-effect-primitives` | io-algebra |
|---|---|---|
| Central type | `Effect.Protocol` (first-order effect signatures) | `IO<Env, E, A>` (a composed computation) |
| Interpretation | Task-local handler lookup (`Effect.Context`) + continuation-based dispatch | Closure execution (`run`) |
| Composition | Effect operations are atomic; composition via handler stacking (nested `Context.with`) | Monadic combinators (`map`, `flatMap`, `andThen`, `zip`, `orElse`, `recover`) |
| Suspension | Handler captures continuation, may resume anywhere | `async` through the `_run` closure; no continuation capture |
| Linearity | `Continuation.One` is `~Copyable`, single-resume | `IO` is `~Copyable`, single-run |
| Reader/Writer/State | Not directly; an effect + handler can model Reader | Reader built-in (`Environment`), `local`, `provide`, `ask` |
| Error channel | Per-effect `Failure` associated type | Explicit `LeafError` type parameter; combinators transform/recover |
| Typed throws | `Context.with` yes; handler's `handle` no (uses continuation) | Fully, across every combinator |
| Runtime cost | Per-effect: a task + a `CheckedContinuation` (cited `io-witness-design-literature-study.md:302-305`) | Zero dispatch overhead — direct closure call |
| Multi-shot | `Continuation.Multi` supports backtracking | Single-shot only (intentionally) |
| Sendable stance | Protocol requires `Sendable`; closures are `@Sendable` | No `@Sendable`; three value-level `Sendable` constraints |

### 7.1 Isomorphism check

Can `IO<Env, E, A>` be expressed as an `Effect.Protocol`? Yes, but
trivially:

```swift
struct RunIO<Env, E: Error, A: Sendable>: Effect.Protocol {
    typealias Arguments = Env
    typealias Value = A
    typealias Failure = E
    let arguments: Env
}
```

And the handler is just "run the IO." But this collapses the entire
monad structure into a single effect — you lose the combinators. The
monadic structure is at the call-site level (how you chain `flatMap`),
whereas the effect-primitives structure is at the handler level (how
an effect is interpreted). They operate at different strata.

Can an `Effect.Protocol` operation be expressed as an `IO`? Also yes,
trivially:

```swift
extension IO {
    static func perform<E: Effect.Protocol>(
        _ effect: E
    ) -> IO<Void, E.Failure, E.Value> where E.Value: Sendable {
        IO { _ in
            try await Effect.perform(effect)  // L3 perform
        }
    }
}
```

This is the honest answer: **the two structures are orthogonal, not
subsumptive.** `Effect.Protocol` classifies _individual operations_
requiring external interpretation. `IO<Env, E, A>` classifies
_composed computations_ with an explicit environment and a closed
runtime.

### 7.2 What they share

Both have `~Copyable` linearity at the core. Both reject double-use at
the type level. Both target Swift 6.3+. Both have `sending` returns.
Both avoid `@unchecked Sendable`. Both have typed errors (just
positioned differently).

### 7.3 Where they diverge

- **Ambient vs. explicit context**: `Effect.Context` is task-local;
  `IO.Environment` is a type parameter. Both are principled; they
  impose different ergonomics.
- **Handler-driven vs. closure-driven**: handler indirection is an
  interpretation boundary useful for testing, mocking, retry
  strategies, etc. Direct closure execution has zero indirection
  cost but no swap-in-a-mock story.
- **`@Sendable` posture**: effect-primitives is Sendable-heavy
  (protocol requires `Sendable`; stored closures are `@Sendable`).
  io-algebra is `@Sendable`-free at function-type level — its key
  novelty.

---

## 8. Can io-algebra be a specialization of effect-primitives?

**Short answer.** Not usefully. "Specialization" here would mean: IO
defined as `Effect.Protocol` + a specific handler. But as shown in
§7.1, that collapses the monadic combinator structure.

**Long answer.** There are three senses in which one could be layered
on the other:

### 8.1 IO as a _meta-effect_

Define:

```swift
struct IOEffect<Env: Sendable, E: Error, A: Sendable>: Effect.Protocol {
    typealias Value = A
    typealias Failure = E
    typealias Arguments = Env
    let arguments: Env
}
```

And a handler that interprets an `IOEffect` by running a stored
`IO<Env, E, A>`. But the `IO` value has to live _somewhere_ for the
handler to reach. The handler wraps a captured IO. The combinators
still happen at the `IO` level, before the effect is performed.
Effect-primitives is not doing any work here — it's just the transport
layer for "here's an IO value, go run it." Unnecessary.

### 8.2 IO combinators implemented via Effect.Context

Define `IO` as a thin handle, and have every combinator push a
description into a task-local queue that a single handler interprets.
This would be the "free monad + interpreter" style. It does compose
cleanly with effect-primitives — effect operations become the leaves
of the free monad, and `flatMap` becomes node construction. But:

- You lose the `~Copyable` linearity — the free monad tree has to be
  traversable, which means copyable nodes.
- You gain an allocation per combinator call.
- You gain the ability to inspect / transform the IO before running —
  which is the reason to use free monads in the first place.

Engineering verdict: it's a different design, not a refactoring. Call
this "FreeIO over effect-primitives." It would be a _peer_ of
io-algebra, not a reimplementation.

### 8.3 Effect.Context providing IO's Environment

Use `Effect.Context` for dependency injection inside an IO's closure.
That is, `IO.Environment = Void`, and the "environment" is pulled
from the ambient task-local scope inside `_run`. This works, and is
already how swift-effects uses `Effect.Context` — but it throws away
the static type-level guarantees the Reader monad gives you.

### 8.4 Verdict

Neither direction of specialization is useful. **io-algebra and
effect-primitives are orthogonal designs at different abstraction
levels.** Unifying them would destroy what each does well.

---

## 9. Algebra-first synthesis

Step back from implementation. What does each package describe
mathematically?

### 9.1 `swift-effect-primitives` — operational semantics

Effect handlers, in the Plotkin-Pretnar tradition, are operationally
defined: an _effect_ is a request with a type signature; a _handler_
is a tuple of (interpretation function, continuation invocation
policy). The calculus is **contextual**: the meaning of a program is
determined by the handler stack at the point of performance.

The `~Copyable Continuation.One` is the compiler-level witness of the
Plotkin-Pretnar linearity requirement (a one-shot continuation can be
resumed at most once — Pretnar 2015, "Handling Algebraic Effects,"
Prop. 3.1). In this sense, effect-primitives is a _faithful_
Swift-native rendering of the theory. The hoisted-protocol pattern
(`__EffectProtocol`) is Swift-specific plumbing; the semantics are
textbook.

### 9.2 io-algebra — denotational semantics

io-algebra is the Reader-Error monad transformer stack in one
concrete type:

```
IO<R, E, A> ≅ R → Async (Either E A)
```

Each combinator corresponds to a known monad-transformer operation:

| Combinator | Categorical meaning |
|---|---|
| `pure(a)` | Monadic unit (η) |
| `map(f)` | Functor action |
| `flatMap(f)` | Kleisli composition (μ · T(f)) |
| `andThen(io2)` | `flatMap(_ => io2)` |
| `zip(io2)` | Applicative product (lax monoidal, sequential) |
| `ask()` | Reader ask (monadic projection of environment) |
| `provide(env)` | Reader run / elimination |
| `local(f)` | Reader contramap over Env |
| `mapError(f)` | Functor action on the error channel |
| `catchAll(f)` | Monadic bind on the error channel |
| `orElse(io2)` | Alternative structure (or-combinator) |
| `recover(f)` | Natural transformation `E → A` |

Linearity (`~Copyable`) adds a substructural layer: the monadic laws
are restated as denotational equivalences on fresh values. This is
the Linear Haskell reading — "Linear Types Can Change the World"
(Wadler 1990) plus "Linear Haskell" (Bernardy et al. 2018). The
experiment's header cites exactly these (`IO.swift:19-23`).

### 9.3 Both are correct at different levels

A runner is a handler that, in Ahman & Bauer's "Runners in Action"
(2020), denotes a specific _category_ of handlers: those that
allocate and release a resource exactly once. io-algebra's linear
semantics make every `IO` value a runner in this sense — a one-shot
resource-bound computation.

Effect-primitives generalizes: a handler can be a runner, a logger, a
retry strategy, a mock, or any contextual interpretation. It does not
commit to a specific shape. This is by design — effects are
_compositional_ across shapes; runners are specialized.

**The algebra-first reading**: effect-primitives is the _general_
framework for effectful operations. io-algebra is a _specific_ algebra
(ReaderT · ExceptT · Linear · Async) expressed as a single monolithic
type rather than built from transformer layers.

Neither subsumes the other. They are complementary:

- A program can be authored in io-algebra for its compositional
  ergonomics, and `run` that IO _inside_ an `Effect.Context.with`
  block so its leaf effects are mocked.
- A test can install effect handlers, construct IO values that
  perform effects, and run the whole thing.

The peer document in `swift-foundations/Research/` should confirm
this separation from the L3 perspective.

---

## 10. `~Copyable` and `~Escapable` leverage opportunities

Catalog of specific, targeted modernization items per package.

### 10.1 For `swift-effect-primitives`

| Item | Location | Proposal | Severity |
|---|---|---|---|
| 1 | `Effect.Protocol.swift:39-42` | Add `: ~Copyable` to `Arguments`, `Value` associated types. Enables handlers for non-copyable resources without `Reference.Box` wrapper. | HIGH |
| 2 | `Effect.Handler.swift:40` | Suppress `Copyable` on the handler protocol so handlers can own `~Copyable` resources directly. | HIGH |
| 3 | `Effect.Continuation.One.swift:30` | Evaluate dropping `@Sendable` on stored closure since `One` is `~Copyable`. Cross-reference io-algebra's argument. | MEDIUM |
| 4 | `Effect.Handler.swift:49-52` | Add an `isolated` variant of `handle` for borrowing non-Sendable actor state. | MEDIUM |
| 5 | `Effect.Outcome.swift:31` | Drop `Sendable` constraint on `Value`. | LOW |
| 6 | `Effect.Protocol.swift:48` | Use `borrowing get` on `arguments` when `Arguments: ~Copyable`. | MEDIUM (requires item 1) |
| 7 | Various | Add `~Escapable` support for borrowed-view effect results (Q: is there a valid use case? Needs exploration). | INFO |

### 10.2 For io-algebra

| Item | Location | Proposal | Severity |
|---|---|---|---|
| 1 | `IO.swift:100-104` | Add `isolation: isolated (any Actor)? = #isolation` parameter to `run`. | MEDIUM |
| 2 | `IO.Applicative.swift:16-29` | Add `zipInto` for `~Copyable` pair types. | LOW |
| 3 | `IO.swift:85` — generic `Value` | Explore `Value: ~Escapable` for lifetime-bounded return types (e.g., `Span<Byte>` views). | MEDIUM |
| 4 | `IO.swift:92` | `Environment: ~Copyable` — the `_run` closure already takes `borrowing Environment`; the type parameter should allow the wider class. | LOW |
| 5 | `IO.Reader.swift:33` | `WiderEnvironment: ~Copyable` in `local`. | LOW |
| 6 | `IO.Error.swift:13` | `LeafError: ~Copyable` for linear error resources (unusual but fits the linear reading). Probably not worth the complexity — errors are typically Copyable by convention. | INFO |

### 10.3 Shared direction

Both packages should define their `Environment` / `Arguments`
extension points to be `~Copyable`-capable. This is the v6.3 Swift
baseline, and both packages should meet it.

---

## 11. Actor-storage consideration (the `~Copyable` blocker)

**The blocker** (identified in the parent conversation): because
io-algebra's `IO` is `~Copyable`, it cannot be stored on an actor
and invoked repeatedly. Each use consumes. Server-style patterns
("actor holds an IO-shaped request handler, processes many
requests") cannot directly express "my handler is this IO value."

### 11.1 Why this is a `~Copyable` trait, not an io-algebra bug

Any `~Copyable` type has this property: you can call a `consuming`
method on it exactly once. Storing one in a class/actor field and
calling `consuming` methods would consume the field; you'd need to
reinitialize it before the next call.

The fix is not to give up linearity — it's to give the _factory_, not
the _value_:

```swift
actor Server {
    let makeRequest: @Sendable () -> IO<Request, Error, Response>
    
    func handle(_ request: Request) async throws(Error) -> Response {
        try await makeRequest().provide(request).run(())
    }
}
```

This is exactly what io-algebra's docs suggest (`IO.swift:60-66`):

> Server-style usage where an actor holds an IO for its lifetime must
> reconstruct the IO per-request (or use a factory — see `IO.from`).

### 11.2 effect-primitives' parallel

`swift-effect-primitives` has no equivalent blocker because handlers
are stored as `Sendable` values (Context holds `Dependency.Values`,
which is backed by Sendable-typed storage). But this works _only_
because handlers are required to be `Sendable` and, practically,
Copyable — see item 2 in §10.1. As soon as we modernize
effect-primitives to allow `~Copyable` handlers, the same "consume on
invocation" constraint appears in the handler world, and the same
factory-pattern workaround applies.

### 11.3 Shared workaround

A `Reference.Box<IO<Env, E, A>>` would let an IO be stored in a
heap-allocated slot that can be `.take()`-then-`set(new)` across
invocations. But this re-introduces allocation and discards the
compile-time linearity check.

A better direction: a _factory type_ primitive that expresses
"constructor of a linear value":

```swift
struct Factory<T: ~Copyable>: Sendable {
    let make: @Sendable () -> T
}
```

This is arguably a primitive missing from the ecosystem. It would
serve both io-algebra and a modernized effect-primitives.

**Recommendation**: add `Factory<T: ~Copyable>` as a primitive in
`swift-reference-primitives` or similar. Both packages can then
express "stored constructor of a linear effect/IO value."

---

## 12. Recommendation

**Choice: (c) — Modernize both; revisit relationship after.**

The two packages are complementary, not redundant. They occupy
different abstraction strata: effect-primitives is an operational
framework for open-ended effect interpretation; io-algebra is a
closed-form monadic computation type. Merging them would destroy the
qualities that make each useful.

### 12.1 Order of operations

**Phase 1** (effect-primitives, immediate, 1-2 weeks):
- Adopt `~Copyable` on `Arguments`, `Value` associated types
  (Protocol.swift:39, 42).
- Adopt `~Copyable` on the handler protocol (Handler.swift:40).
- Drop `Sendable` on `Effect.Outcome.Value` (Outcome.swift:31).
- Evaluate dropping `@Sendable` from `Continuation.One._resume`
  (Continuation.One.swift:30) — needs experimental validation.

**Phase 2** (io-algebra, concurrent with Phase 1):
- Add `isolation` parameter to `IO.run` (IO.swift:100-104).
- Prototype `~Escapable` `Value` support (IO.swift:85 type
  parameter).
- Explore `Factory<T: ~Copyable>` for actor-storage pattern.
- Document the three load-bearing `Sendable` constraints (`pure`,
  `fail`, `ask`) more prominently as semantic — not workaround.

**Phase 3** (integration, after Phase 1+2 land, 2-4 weeks):
- Write the glue: `IO.perform(_: Effect.Protocol)` combinator letting
  an IO perform effects routed through `Effect.Context`.
- Write the test-harness: `Effect.Context.with { handlers in ... }
  .run(io)` pattern.

**Phase 4** (revisit, 6+ weeks out):
- Once both packages have had their modernization passes, reassess.
  Specifically: does `Effect.Context` remain orthogonal, or does
  cross-pollination justify a shared `Context` primitive?
- Consider promoting `Factory<T: ~Copyable>` to `swift-reference-primitives`.

### 12.2 What NOT to do

- **Do NOT** unify the two packages. They are orthogonal.
- **Do NOT** build io-algebra on top of `Effect.Context` — doing so
  would force io-algebra's `Environment` to be Sendable
  (`Dependency.Values` requires Sendable storage), eliminating
  io-algebra's key win.
- **Do NOT** deprecate either. Both have real consumers or real
  intended use cases.
- **Do NOT** block io-algebra's graduation on effect-primitives'
  modernization. The two can advance independently.

### 12.3 Why (c) and not (a), (b), (d)

- (a) Unify under one framework — destroys orthogonality; see §8
  analysis. Would require substantial migration for current
  effect-primitives consumers (cache, pool, parser primitives) and
  would force io-algebra to abandon its `@Sendable`-free design.
- (b) Keep separate — partial truth. They should stay separate, yes,
  but each needs modernization work before that stance is clean.
  "Keep separate" alone leaves both packages below Swift 6.3 standard.
- (d) Other — no cleaner option emerged.

(c) is correct because it respects both the algebra-first observation
(two different algebras) and the modernization diligence
(both packages lag Swift 6.3).

---

## 13. References

### Packages and source code

- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/`
  — the L1 package under analysis.
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Research/Algebraic Effects in Swift.md`
  — package's own theoretical positioning document (2026-01-18).
- `/Users/coen/Developer/swift-foundations/swift-effects/`
  — the L3 runtime built on effect-primitives; Effect.perform impl at
  `Sources/Effects/Effect.perform.swift:13-41`.
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/`
  — the fresh experiment (2026-04-17).
- `/Users/coen/Developer/swift-foundations/swift-io/Research/io-witness-design-literature-study.md`
  — prior L3 analysis of IO+witness+effects interplay.

### Peer document

- `/Users/coen/Developer/swift-foundations/Research/effects-and-io-algebra-relation.md`
  — the foundations-side counterpart (simultaneous).

### Academic prior art

- **Plotkin, G. & Power, J. (2003)**, "Algebraic Operations and Generic
  Effects."
- **Plotkin, G. & Pretnar, M. (2009)**, "Handlers of Algebraic
  Effects."
- **Pretnar, M. (2015)**, "An Introduction to Algebraic Effects and
  Handlers."
- **Wadler, P. (1990)**, "Linear Types Can Change the World!" — linearity
  foundations cited by io-algebra.
- **Bernardy, J.-P. et al. (2018)**, "Linear Haskell: practical
  linearity in a higher-order polymorphic language."
- **Ahman, D. & Bauer, A. (2020)**, "Runners in Action" — runners
  calculus underpinning IO's one-shot resource semantics.
- **Leijen, D. (2014)**, "Koka: Programming with Row Polymorphic
  Effect Types" — row-polymorphic effects contrast.
- **Xie, N. & Leijen, D. (2020-2021)**, evidence-passing for effect
  handlers — 150× speedup cited in io-witness-design-literature-study.

### Swift language features used

- SE-0390 Noncopyable Types; SE-0427 Noncopyable Generics;
  SE-0437 Noncopyable Standard Library Primitives.
- SE-0302 Sendable; SE-0430 `sending` parameters and return types.
- Typed throws (SE-0413).
- SE-0456 Span and lifetime dependencies.
- Swift 6.3 region-based isolation; `NonisolatedNonsendingByDefault`
  upcoming feature; `SuppressedAssociatedTypes` experimental feature.

### Ecosystem feedback referenced

- `feedback_isolated_param_for_borrowing_noncopyable.md` — `isolated`
  parameter pattern for non-Sendable borrow across actors.
- `feedback_throws_not_result.md` — typed throws over Result.
- `feedback_escapable_over_with_closures.md` — `~Escapable` over
  `with*` closure-scoped APIs.
- `feedback_language_features_over_custom_types.md` — `borrowing`,
  `consuming`, `~Copyable` for ownership, not custom wrapper types.
- `feedback_sending_over_sendable_return.md` — `sending R` over
  `R: Sendable` on returns.

### Conventions consulted

- `[MEM-COPY-001]`, `[MEM-COPY-004]`, `[MEM-COPY-006]` — `~Copyable`
  declaration and propagation.
- `[MEM-SEND-001]`, `[MEM-SEND-004]` — Sendable tiers, no
  `@unchecked Sendable` when not needed.
- `[MEM-LIFE-006]` — `~Escapable` parameters in async methods.
- `[MEM-OWN-001]`, `[MEM-OWN-002]` — `consuming` and `borrowing`
  semantics.
- `[RES-003]`, `[RES-020]` Tier 2, `[RES-021]` prior art
  contextualization — this document's structure.

---

## 14. Findings (Modernization) — 2026-04-17

Execution of the `swift-effect-primitives` modernization prescribed
in §4 and §10.1. Handoff:
`/Users/coen/Developer/swift-primitives/HANDOFF-effect-primitives-ncopyable-modernization.md`.

### 14.1 What landed

| Item | File | Change |
|------|------|--------|
| 1 | `Sources/Effect Primitives/Effect.Protocol.swift` | `__EffectProtocol: ~Copyable, Sendable`; `Arguments: ~Copyable & Sendable = Void`; `Value: ~Copyable & Sendable`; `var arguments: Arguments { borrowing get }`; default `arguments` gated `where Self: ~Copyable, Arguments == Void` per [COPY-FIX-003]. |
| 2 | `Sources/Effect Primitives/Effect.Handler.swift` | `__EffectHandler: ~Copyable, Sendable`; `Handled: ~Copyable & __EffectProtocol`; `handle(_ effect: borrowing Handled, continuation: consuming Effect.Continuation.One<Handled.Value, Handled.Failure>) async`. |
| 3 | `Sources/Effect Primitives/Effect.Continuation.swift` | `__EffectContinuation<Value, Failure>: ~Copyable, Sendable`; `Value: ~Copyable & Sendable`; `resume(returning value: consuming sending Value) async`; `resume(throwing error: Failure) async`; `resume(with:)` removed from the protocol and re-added as a `where Value: Copyable` extension. |
| 4 | `Sources/Effect Primitives/Effect.Continuation.One.swift` | `One<Value: ~Copyable & Sendable, Failure>: ~Copyable, Sendable`; storage reshaped to two callbacks (`_onValue: @Sendable (consuming sending Value) async -> Void`; `_onError: @Sendable (Failure) async -> Void`). `resume(with:)` and `onResume(_:)` kept as `Value: Copyable` extensions. |
| 5 | `Sources/Effect Primitives/Effect.Outcome.swift` | `Outcome<Value: ~Copyable, Failure: Error>: ~Copyable`; conditional `Copyable`, `Sendable` via extensions. Stdlib `Equatable` / `Hashable` kept for `Value: Copyable`. Additional `Equation.Protocol` / `Hash.Protocol` conformances added for `Value: ~Copyable` — net-new capability, see §14.3. |
| 6 | `Sources/Effect Primitives/Effect.perform.swift` | `Effect.Continuation.one(_:)` kept for `Value: Copyable` (`Result`-based closure). Added `@_disfavoredOverload Effect.Continuation.one(onValue:onError:)` for the `~Copyable & Sendable` Value path. |
| 7 | `Package.swift` | Added deps on `swift-equation-primitives`, `swift-hash-primitives`. Dependency graph acyclic (`swift package show-dependencies`). |

Diff stat (Sources, excluding Experiments and research notes):

```
Effect.Protocol.swift        | rewritten (55 lines → 65 lines)
Effect.Handler.swift         | rewritten (64 lines → 74 lines)
Effect.Continuation.swift    | rewritten (59 lines → 61 lines)
Effect.Continuation.One.swift| rewritten (136 lines → ~170 lines)
Effect.Outcome.swift         | rewritten (105 lines → ~165 lines)
Effect.perform.swift         | rewritten (79 lines → ~100 lines)
Package.swift                | +2 deps, +2 target product refs
```

Build: `swift build` — complete in 31s. Tests: all 38 existing tests
pass unchanged (`swift test` — 38 tests in 6 suites passed). Downstream
consumers `swift-pool-primitives`, `swift-cache-primitives`,
`swift-parser-primitives` all rebuild clean on the modernized L1.

### 14.2 What did not land, and why — two-callback storage over thunk (§4.1 revisit)

The original intent was the `() throws(Failure) -> sending Value` thunk
form (per [IMPL-092]): single stored closure receiving a typed-throws
thunk, the resume path synthesizing the thunk via `var slot: Value? =
consume value` + `slot.take()!` — the canonical "move a `~Copyable`
across a closure boundary" pattern cited in
`feedback_no_raw_descriptor_reconstruction.md` and used cleanly at
`Kernel.Event.Driver.swift:117`.

The in-package thunk variant compiled but **crashed at runtime** in
`One`'s "resume with value completes successfully" test with
`freed pointer was not the last allocation` (SIGABRT), at the first
`await` that invoked the thunk. Under the failing configuration three
ownership/concurrency primitives compose at once: the captured
Optional, the `sending` thunk closure, and the outer `@Sendable` async
closure in `_resume`. The reduced reproducer
(`swift-institute/Experiments/silgen-thunk-noncopyable-sending-capture/`)
trips the bug a step earlier — Swift 6.3.1 crashes in SILGen during reabstraction
thunk emission (SIGSEGV, stack frame
`emitApplyWithRethrow` → `buildThunkBody` → `createThunk`), confirming
this is a Swift compiler bug rather than a design defect on our side.

Workaround landed: **two-callback storage** (`_onValue`, `_onError`).
Denotationally equivalent to `sending Result<Value, Failure>` or the
thunk — it is the same tagged union delivered via two channels instead
of one — and avoids the failing configuration entirely. All 38 tests
pass.

Revisit trigger (mirrored in `Effect.Continuation.One.swift` doc
comment):

> Two-callback storage and `@Sendable` retention on `_onValue` /
> `_onError` are interim. Revisit the thunk form
> (`() throws(Failure) -> sending Value`) and `@Sendable` removal when
> `swift-institute/Experiments/silgen-thunk-noncopyable-sending-capture/`
> compiles and runs cleanly on a Swift 6.4-dev nightly (or the bug is
> otherwise fixed upstream).

### 14.3 Item 3 — dropping `@Sendable` on `_resume` (§4.1)

§4.1 flagged the `@Sendable` annotation on `Continuation.One`'s stored
closure as over-propagated — a `~Copyable` `One` cannot be aliased, so
the closure's captures do not need to be `Sendable`. The modernization
explicitly evaluated this.

Result: **`@Sendable` retained** on both `_onValue` and `_onError`.
Experimental removal surfaced the same Swift-compiler-bug surface as
§14.2; no clean rewrite was viable without falling into the reabstraction-thunk
crash path. Linked to the same revisit trigger.

### 14.4 Item 5 — `Effect.Outcome` conditional conformances (§10.1)

`Outcome` is now `~Copyable` with:

- `Copyable` where `Value: Copyable`
- `Sendable` where `Value: Sendable & ~Copyable`, `Failure: Sendable`
- Stdlib `Equatable` where `Value: Equatable`, `Failure: Equatable` (preserved)
- Stdlib `Hashable` where `Value: Hashable`, `Failure: Hashable` (preserved)
- **NEW**: `Equation.Protocol` where `Value: Equation.Protocol & ~Copyable`, `Failure: Equation.Protocol`
- **NEW**: `Hash.Protocol` where `Value: Hash.Protocol & ~Copyable`, `Failure: Hash.Protocol`

The two `Equation.Protocol` / `Hash.Protocol` conformances are
**net-new capability**. The pre-modernization `Effect.Outcome` had
only stdlib `Equatable` / `Hashable` (`Value: Copyable & ...`); there
was no `~Copyable`-compatible equality/hashing. Adding them is scope
expansion relative to the literal handoff text.

**OPEN** for reviewer confirmation: keep as landed, or revert and
re-file as a follow-up? The addition was made in direct response to
mid-investigation user direction ("Also see equation-primitives,
hash-primitives for replacements for ~Copyable"), uses existing
ecosystem primitives (no invention — algebra-first principle
respected), and the two new package deps form a clean acyclic subgraph
(`Equation_Primitives` → `Property_Primitives` + `Tagged_Primitives`;
`Hash_Primitives` → `Equation_Primitives` + `Comparison_Primitives` +
`Property_Primitives` + `Tagged_Primitives`). Default
recommendation: keep.

### 14.5 Downstream cascade inventory (for the L3 handoff)

The parallel L3 handoff
`/Users/coen/Developer/swift-foundations/HANDOFF-effects-modernization.md`
owns the `swift-effects` fixes. These are the specific cascade sites
the L1 modernization surfaces, in one place so the L3 agent doesn't
have to rediscover them:

| L3 file | Site | Cascade |
|---------|------|---------|
| `Sources/Effects/Effect.perform.swift:17` | `Effect.Context.current[E.HandlerKey.self]` | `Dependency.Values.subscript(_:)` requires `K.Value: Copyable`. Handlers can now be `~Copyable`; either keep handlers Copyable-only at L3, or extend `Dependency` to admit `~Copyable` handler values (separate upstream change). |
| `Sources/Effects/Effect.perform.swift:20, 60` | `withCheckedThrowingContinuation` / `withCheckedContinuation` | Stdlib requires `T: Copyable`. For `~Copyable` `E.Value`, `Effect.perform` needs an alternative suspension primitive; fallback is to constrain `perform` to `E.Value: Copyable` and file the wider one as deferred. |
| `Sources/Effects/Effect.perform.swift:26, 66` | `Effect.Continuation.one { (result: Result<E.Value, Never>) async in ... }` | Factory signature preserved for `Copyable` Value. For `~Copyable` Value, the new `Effect.Continuation.one(onValue:onError:)` factory is the direct replacement. |
| `Sources/Effects/Effect.perform.swift:26, 66` | `Result<E.Value, Never>` closure parameter | Requires ownership for `~Copyable` parameters; `(consuming result: Result<E.Value, Never>) async` when `E.Value: Copyable`, or the two-callback factory otherwise. |
| `Sources/Effects/Effect.perform.swift:38` | `throw error as! E.Failure` | Pre-existing latent crasher (primary item on the L3 handoff). Untouched here. |
| `Sources/Effects/EffectWithHandler.swift:8-12` | `HandlerKey.Value: __EffectHandler` | Refinement ok; if handlers go `~Copyable`, need `Self: ~Copyable` widening too (handoff item 2). |
| `Sources/Effects Testing/Effect.Test.Spy.swift:17-47, 95-110` | `Spy<E: __EffectProtocol>`, `Invocation.outcome: Effect.Outcome<E.Value, E.Failure>` | `Outcome` is now `~Copyable` when `Value` is. `Spy.Invocation` storage needs `E.Value: Copyable` or must become `~Copyable`. The simpler path: constrain `Spy` to `E.Value: Copyable`. |
| `Sources/Effects Testing/Effect.Test.Recorder.swift:21, 76, 83, 98, 108, 115` | `any __EffectProtocol`, `any __EffectProtocol.Type`, generic `<E: __EffectProtocol>` | Existential `any __EffectProtocol` cannot be formed over a `~Copyable` protocol. `Recorder` must either constrain to Copyable effects or be reimplemented non-existentially. |
| `Sources/Effects Testing/Effect.Test.Handler.swift:14-33` | `Handler<E: __EffectProtocol>`, stored `_handle: @Sendable (E) async -> Result<...>` | `E` may be `~Copyable`; parameter needs ownership. `Result<E.Value, E.Failure>` needs `E.Value: Copyable`. |
| `Sources/Effects Built-in/Effect.Yield.swift`, `Effect.Exit.swift` | Built-in effects implementing `__EffectProtocol` / `__EffectHandler` | Should continue to compile as written — their effect/handler types are Copyable, so the widened constraints are trivially satisfied. |
| `swift-testing/Sources/Testing Effects/Test.Effects.swift` | `Test.spy(for:…)`, `Test.handler(for:…)` generics over `__EffectProtocol` | Same mechanical cascade: tighten constraints to `E.Value: Copyable` (safe initial move) or rework through the new callback factory. |

### 14.6 Principled rejections

- **No new wrapper primitive**: neither `Factory`, `Box`, nor a hand-rolled Either was introduced. The widening used existing ecosystem primitives (`Equation.Protocol`, `Hash.Protocol`) and existing language features (`consuming`, `sending`, `borrowing`, `~Copyable`).
- **Public API stability**: `Effect.Protocol`, `Effect.Handler.Protocol`, `Effect.Continuation.Protocol`, `Effect.Continuation.One`, `Effect.Continuation.Multi`, `Effect.Outcome` all preserved their nesting paths. `Effect.Continuation.one(_:)` factory preserved for `Value: Copyable`. Breaking changes land only where a pre-modernization signature was structurally incompatible with `~Copyable` (e.g., `resume(with:)` removed from the `Continuation.Protocol` and kept as a `Value: Copyable` extension).
- **`Effect.Continuation.Multi`**: untouched. Multi-shot semantics require `Value: Copyable`; the protocol conformance (`__EffectContinuation`) still matches because `Copyable` is a valid specialization of the widened `Value: ~Copyable & Sendable` slot.

### 14.7 Status

- L1 widening: **DONE**. Build green, 38 tests pass.
- `@Sendable` removal on `_resume`: **DEFERRED** — blocked by the same Swift-compiler-bug class as §14.2. Same revisit trigger.
- Thunk-form storage: **DEFERRED** — see §14.2.
- `Equation.Protocol` / `Hash.Protocol` on `Outcome`: **OPEN** per §14.4 — reviewer confirmation requested.
- L3 cascade: **DELEGATED** to `swift-foundations/HANDOFF-effects-modernization.md` with §14.5 as a hand-off inventory.

