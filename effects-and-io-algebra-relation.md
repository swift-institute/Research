# swift-effects ↔ IO Algebra: Relation and Modernization

<!--
---
version: 1.0.0
last_updated: 2026-04-17
status: RECOMMENDATION
tier: 2
related:
  - swift-foundations/swift-effects/
  - swift-primitives/swift-effect-primitives/
  - swift-foundations/swift-io/Experiments/io-algebra/
  - swift-foundations/swift-io/Research/io-witness-design-literature-study.md
  - swift-primitives/swift-effect-primitives/Research/Algebraic Effects in Swift.md
  - swift-primitives/Research/effect-primitives-and-io-algebra-relation.md (peer, simultaneous)
---
-->

## 1. Context

Two packages in the ecosystem occupy different spots along the same
"effectful-computation" design axis:

1. **`swift-effects`** (L3 foundation, since 2026-02) — an algebraic-
   effects runtime built on `swift-effect-primitives` (L1) and
   `swift-dependency-primitives` (L1). Operations are declared as
   first-class effect types (`Effect.Protocol`), performed via
   `Effect.perform(_:)`, and interpreted by handlers registered in a
   task-local `Effect.Context`. The theoretical claim (documented in
   `swift-effect-primitives/Research/Algebraic Effects in Swift.md`
   §2) is Plotkin–Pretnar style algebraic effects, implemented via
   one-shot (`Effect.Continuation.One`) and multi-shot
   (`Effect.Continuation.Multi`) resumable continuations.

2. **`io-algebra`** (experiment inside `swift-io/Experiments/`, committed
   2026-04-17) — a `~Copyable` linear computation type
   `IO<Environment, LeafError, Value>` that fuses Reader + Either +
   Task, with a full combinator set (`pure`, `fail`, `from`, `map`,
   `flatMap`, `andThen`, `mapError`, `catchAll`, `orElse`, `recover`,
   `provide`, `local`, free `ask`, `zip`). The stored closure carries
   no `@Sendable` function-type attribute; linearity makes aliasing
   impossible, so the closure's capture region is its owner's. Three
   Sendable constraints survive at the value-type level (`pure`, `fail`,
   free `ask`) because the region checker cannot prove that the returned
   `sending Value` is disconnected from a captured or borrowed source.

Both systems describe "a computation suspended from its environment,
interpreted by a handler." They differ in shape: `swift-effects` splits
operation from interpretation via a task-local dispatch table;
`io-algebra` bundles operation-plus-interpretation into a single linear
value and passes the environment explicitly.

This document answers seven questions:

| # | Question |
|---|----------|
| 1 | Current public surface of `swift-effects` and its theoretical basis |
| 2 | Modernization assessment against Swift 6.3 features (both directions) |
| 3 | Structural relation between `IO<R, E, A>` and `EffectWithHandler` + `perform` + `Context.with` |
| 4 | Whether `io-algebra` can be a specialization of `swift-effects` |
| 5 | Algebra-first: isomorphism check between Reader-Either monad transformer and algebraic-effects-plus-handlers |
| 6 | `~Copyable` and `~Escapable` leverage on either side |
| 7 | Recommendation |

The document intentionally treats the algebra-first perspective as
canonical: we do not let Swift's implementation convenience decide
whether the two packages are the same abstraction. The answer is
approached by concretizing both systems in their actual type-level
commitments.

## 2. Current state of swift-effects

### 2.1 Public surface

The L3 `swift-effects` package comprises three products:

| Product | Role | Files |
|---------|------|-------|
| `Effects` | Runtime: `EffectWithHandler`, `Effect.perform` | 3 source files |
| `Effects Built-in` | Supplied effects: `Effect.Exit`, `Effect.Yield` | 3 source files |
| `Effects Testing` | Test helpers: `Handler`, `Recorder`, `Spy` | 5 source files |

The `Effects` target re-exports `Effect_Primitives` and
`Dependency_Primitives` at `swift-effects/Sources/Effects/exports.swift:1–2`.
It adds exactly two new declarations:

1. `EffectWithHandler` —
   `swift-effects/Sources/Effects/EffectWithHandler.swift:8–12`.
   Links an effect type (`Self: __EffectProtocol`) to a context key
   (`HandlerKey: Dependency.Key`) whose `Value` is the handler for the
   effect:
   ```swift
   public protocol EffectWithHandler: __EffectProtocol {
       associatedtype HandlerKey: Dependency.Key
           where HandlerKey.Value: __EffectHandler,
                 HandlerKey.Value.Handled == Self
   }
   ```

2. `Effect.perform` —
   `swift-effects/Sources/Effects/Effect.perform.swift:13–41` (throwing)
   and `:54–77` (infallible `Never` specialization). Both variants:
   - Look up the handler from `Effect.Context.current[HandlerKey.self]`
     (line 17, 58).
   - Bridge via `withCheckedThrowingContinuation(isolation: nil)` or
     `withCheckedContinuation(isolation: nil)` (lines 20, 60).
   - Spawn an unstructured `Task { ... }` (lines 24, 64) to avoid the
     "move-only capture" diagnostic on `Effect.Continuation.One`.
   - Call the handler's `handle(effect, continuation:)` (lines 35, 73).

Three `typealias` aliases in
`swift-effects/Sources/Effects/exports.swift:11–19` present a clean API
surface over hoisted protocol names: `EffectProtocol`, `EffectHandler`,
`EffectContextKey`.

The `Effects Built-in` target adds two concrete effect types — both are
`struct`s conforming to `__EffectProtocol`, `EffectWithHandler`, and
`Sendable`:

- `Effect.Exit` at `Effects Built-in/Effect.Exit.swift:14–26` (carries
  `Int32` code; `Value = Never`, `Failure = Never`). The handler
  consumes the continuation without resuming at lines 44–48.
- `Effect.Yield` at `Effects Built-in/Effect.Yield.swift:11–18` (no
  arguments; `Value = Void`, `Failure = Never`).

The `Effects Testing` target exposes:

- `Effect.Test.Handler<E>` —
  `Effect.Test.Handler.swift:14–33`. A generic handler whose closure
  takes `E` and returns `Result<E.Value, E.Failure>`, then calls
  `continuation.resume(with:)`.
- `Effect.Test.Recorder` —
  `Effect.Test.Recorder.swift:16–88`. Type-erased invocation log; uses
  `Async.Mutex<[Invocation]>` for thread safety.
- `Effect.Test.Spy<E>` —
  `Effect.Test.Spy.swift:17–91`. Wraps a handler and logs each
  invocation's `Effect.Outcome`.

### 2.2 Theoretical foundation

`swift-effects` claims — and its source citations support — the
Plotkin–Pretnar handler calculus for algebraic effects. The mapping is
spelled out in `swift-effect-primitives/Research/Algebraic Effects in
Swift.md §2.1` and re-used in
`swift-io/Research/io-witness-design-literature-study.md §2.1`:

| Algebraic-effects concept | `swift-effects` realization |
|---------------------------|-----------------------------|
| Effect signature `{op : A → B}` | `__EffectProtocol` with `Arguments`, `Value`, `Failure` |
| Operation invocation `op(a)` | `Effect.perform(e)` |
| Handler interpreter | `__EffectHandler.handle(_:continuation:)` |
| One-shot continuation (k) | `Effect.Continuation.One` (`~Copyable`) |
| Multi-shot continuation (k\*) | `Effect.Continuation.Multi` (copyable) |
| Handler composition (stack) | Nested `Effect.Context.with { }` scopes |
| Handler lookup | `Dependency.Key` → `TaskLocal` → innermost |

The ecosystem's positioning is specifically **effect handlers + capability
passing** per Brachthäuser–Schuster–Ostermann "Effects as Capabilities"
(2020): the handler values are capabilities (unforgeable, scope-confined
by the `Effect.Context.with` frame). See
`swift-io/Research/io-witness-design-literature-study.md §Capabilities`
for the documented equivalence.

Row-polymorphic effect types (Leijen 2017) are **not** supported — Swift
cannot express `{op₁, op₂}`-style effect rows at the type level. This is
acknowledged in the prior-art survey in
`Algebraic Effects in Swift.md §9 Related Work`.

### 2.3 Composition with `swift-effect-primitives`

The L3 ↔ L1 split is narrow:

| Element | Layer | File |
|---------|-------|------|
| `__EffectProtocol` | L1 | `Effect.Protocol.swift:37–49` |
| `__EffectHandler` | L1 | `Effect.Handler.swift:40–53` |
| `__EffectContinuation` | L1 | `Effect.Continuation.swift:27–48` |
| `Effect.Continuation.One/Multi` | L1 | `Effect.Continuation.One.swift`, `Multi.swift` |
| `Effect.Context` | L1 | `Effect.Context.swift:46–49` |
| `Effect.Outcome` | L1 | `Effect.Outcome.swift:31–41` |
| `Effect.Handler.Sync` (typealias) | L1 | `Effect.Handler.Sync.swift:33` |
| `Effect.Perform` (marker enum) | L1 | `Effect.perform.swift:47` |
| `EffectWithHandler` | **L3** | `EffectWithHandler.swift:8–12` |
| Concrete `Effect.perform` | **L3** | `Effect.perform.swift:13–41` |

L1 owns the type vocabulary and the `Effect.Context` scope machinery. L3
introduces **exactly one new concept**: a compile-time link from an effect
type to its handler context key (the `EffectWithHandler` constraint),
and the concrete `perform` that uses the link to dispatch.

This is a thin L3 — `EffectWithHandler` could plausibly live at L1, but
it depends on the `Dependency_Primitives`/`Effect_Primitives` pair and
closes over both. The current placement is defensible.

## 3. Modernization needs (swift-effects side)

Assessment against Swift 6.3 language capabilities. References are to
files in `swift-effects/Sources/` unless noted.

### 3.1 Typed throws

**Current**: `Effect.perform` in
`Effects/Effect.perform.swift:13–15` is typed-throwing:
```swift
public static func perform<E: __EffectProtocol>(
    _ effect: E
) async throws(E.Failure) -> E.Value
```

However, the implementation at line 38 performs a force-cast:
```swift
} catch {
    throw error as! E.Failure
}
```
This is a side-effect of bridging through
`withCheckedThrowingContinuation` whose erased closure body only allows
`any Error`. The typed-throws API surface is correct; the
force-cast is a latent crasher if the continuation ever gets a foreign
error.

**Recommendation (HIGH)**: The force-cast should be removed. Two paths:

1. Replace the bridge with the `Result<Value, Failure>` pattern per the
   memory `feedback_throws_not_result.md` prescription — have the
   handler thunk produce `() throws(Failure) -> Value` instead of an
   erased `any Error`.
2. Change the bridge to `withCheckedContinuation` returning `Result<E.Value,
   E.Failure>` and then `try result.get()` on the typed-throw return
   path. This is the exact pattern `Dependency.Scope.with(...)` uses
   in `swift-dependency-primitives/.../Dependency.Scope.swift:103–110`
   to preserve typed-throw information across `TaskLocal.withValue`.

### 3.2 Hoisted internals still visible in public surface

**Current**: `Effects/exports.swift:11–19` provides `EffectProtocol`,
`EffectHandler`, `EffectContextKey` typealiases over the hoisted
`__EffectProtocol`, `__EffectHandler`, `Dependency.Key`. But several
public APIs still expose the double-underscore names:

- `Effects/Effect.perform.swift:13,54`: `<E: __EffectProtocol>` (should
  be `<E: EffectProtocol>`).
- `Effects/EffectWithHandler.swift:8,11`: `EffectWithHandler: __EffectProtocol`
  with `HandlerKey.Value: __EffectHandler` (should use the clean
  typealiases).
- `Effects Testing/Effect.Test.Recorder.swift:20,21,60,76,83,98,108,
  115`: multiple `__EffectProtocol` references.
- `Effects Built-in/Effect.Exit.swift:14`: `public struct Exit: __EffectProtocol,
  EffectWithHandler, Sendable`.
- `Effects Built-in/Effect.Yield.swift:11`: same.

This violates `feedback_no_hoisted_error_shortcut.md`:
> Use fully-qualified public API paths for error types, not __ hoisted
> internals.

The hoisted names are an implementation workaround for protocols-in-
generics. Consumers should only ever see the clean names.

**Recommendation (MEDIUM)**: Replace `__EffectProtocol` with
`EffectProtocol`, `__EffectHandler` with `EffectHandler`, and
`Dependency.Key` with `EffectContextKey` throughout the public API.
Keep hoisted names `internal` (or `@usableFromInline internal`).

### 3.3 `@Sendable` on stored handler closures

**Current**: Every built-in handler stores a `@escaping @Sendable`
closure — e.g., `Effect.Exit.Handler` at
`Effects Built-in/Effect.Exit.swift:34`:
```swift
private let _handle: @Sendable (Int32) async -> Never
```
This is currently required because `Effect.Test.Handler` and the spy
wrapper form escaping boundaries, and because the handler type itself is
`Sendable`. It is also propagated to the continuation constructors (e.g.,
`Effect.Continuation.One.init` at `Effect.Continuation.One.swift:36` takes
`@escaping @Sendable (sending Result<Value, Failure>) async -> Void`).

**Recommendation (LOW — language-limited)**: Under Swift 6.3, there is no
clean path away from `@Sendable` here because the handler value is
genuinely shared across task boundaries (task-local lookup can be hit
from any inheriting task). The io-algebra insight — that `~Copyable`
lets us drop `@Sendable` from closures — does not translate: handlers are
deliberately reusable. Investigate `Effect.Handler.Sync` (currently a
typealias to `__EffectHandler`) being reshaped as `~Copyable` for
handlers that don't need to be shared, but this is speculative and may
not pay off.

### 3.4 `sending` on value returns

**Current**: The continuation signature at
`Effect.Continuation.One.swift:46`:
```swift
public consuming func resume(returning value: sending Value) async
```
Already uses `sending`. This is correct. Good.

**Current**: The type-erased recorder at
`Effect.Test.Recorder.swift:20–27`:
```swift
public let effectType: any __EffectProtocol.Type
public let effect: any __EffectProtocol
public let timestamp: Clock.Continuous.Instant
public let succeeded: Bool
```
Stores existential `any __EffectProtocol`. This is a legitimate use of
`any` for heterogeneous collection, but the effect value is boxed once
per invocation and passed through `Sendable` — cost is moderate. Not a
modernization issue per se, but worth documenting as "known allocation
per recorded invocation."

### 3.5 `consuming` on continuation types

**Current**: `Effect.Continuation.One.resume` is `consuming` throughout
(`Effect.Continuation.One.swift:46, 56, 66, 109, 122, 132`). Uses the
linear-type pattern per `[MEM-LINEAR-001]`.

**Good**. The one-shot continuation is `~Copyable`, its `resume`
variants all `consuming`, and the compile-time prevention of
double-resume matches the theoretical claim (see
`Effect.Continuation.One.swift:22–27`).

**Gap**: There is no `deinit` trap. `[MEM-LINEAR-001]` says:
> Linear types MUST be `~Copyable` with a `consuming func` for the use
> operation and a `deinit` that traps if not consumed.

A `One` continuation dropped without resume silently corresponds to
abortion semantics (`Effect.Outcome.aborted`). This is documented at
`Effect.Outcome.swift:10` but not enforced — dropping is a valid
handler choice. Conclusion: `One` is **affine**, not linear, so
`[MEM-LINEAR-002]` applies (silent `deinit`). Current implementation is
correct per that rule. Consider updating the doc comment at
`Effect.Continuation.One.swift:22–27` to say "at-most-once (affine)"
rather than "exactly-once (linear)" — the latter is what the comment
currently implies.

### 3.6 Isolation and `nonisolated(nonsending)`

**Current**: `Effect.Context.with` (L1,
`Effect.Context.swift:135, 149`) correctly uses
`nonisolated(nonsending)` per Swift 6.3 conventions. Good.

**Current**: `Effect.perform` (L3,
`Effect.perform.swift:13–41`) is *not* marked `nonisolated(nonsending)`
even though it is a plausible caller-inheriting boundary. The
implementation uses `withCheckedThrowingContinuation(isolation: nil)`
which makes the inner continuation body non-isolated — this is a
deliberate hop to allow the spawned `Task` to run on any executor.

**Recommendation (LOW)**: Evaluate whether `Effect.perform` should be
`nonisolated(nonsending)`. Probably yes for consistency with
`Effect.Context.with`, but it requires checking the spawned `Task`
inherits correctly.

### 3.7 Task spawn in `perform` — non-structured

**Current**: `Effect.perform.swift:24`:
```swift
Task {
    let effectContinuation = Effect.Continuation.one {
        ...
    }
    await handler.handle(effect, continuation: effectContinuation)
}
```
Spawns an unstructured `Task` every `perform` call. The inline comment
at line 23 explains: "Create effectContinuation inside Task to avoid
move-only capture issues." The `Effect.Continuation.One` is `~Copyable`
and cannot be captured by the outer continuation closure; spawning a
fresh `Task` gives the handler its own region.

**Cost**: Every `perform` allocates a `Task` heap object plus the
`CheckedContinuation`'s internal allocation plus the closure capture.
For hot-path IO, this is unacceptable — documented at
`io-witness-design-literature-study.md:303–308` ("The `Effect.perform`
path creates a `Task` + `CheckedContinuation` per call, disqualifying
for hot-path I/O").

**Recommendation (MEDIUM — architectural)**: An alternative
implementation using `withCheckedContinuation(isolation: nil) {
swiftContinuation in ... }` and the
`feedback_continuation_dispatch_pattern.md` technique — wrap the
swiftContinuation's resumption in a Sendable thunk
`() throws(E.Failure) -> E.Value`, pass that *into* the handler via a
different continuation type. This avoids the `Task` spawn but requires
a new continuation variant:

```swift
public struct Effect.Continuation.Inline<Value, Failure: Error>: ~Copyable, Sendable {
    @usableFromInline
    let _resume: (sending Result<Value, Failure>) -> Void
    ...
}
```

A non-async inline resume that flows back through the caller's
continuation. This is worth a targeted experiment (reference
io-algebra's no-Task design as precedent).

### 3.8 `~Copyable` handler values

**Current**: All handler types are **Copyable** structs — e.g.,
`Effect.Exit.Handler` at
`Effects Built-in/Effect.Exit.swift:32`:
```swift
public struct Handler: __EffectHandler, Sendable, Witness.Protocol {
    ...
    private let _handle: @Sendable (Int32) async -> Never
    ...
}
```

Copyable because they register in a `Dependency.Values` dictionary that
needs to retrieve them repeatedly. But some handlers genuinely should
be one-shot — consider a handler that owns a descriptor. Currently the
ecosystem has no concept of a `~Copyable` effect handler.

**Recommendation (MEDIUM)**: Consider a `Effect.Handler.Linear`
protocol variant that is `~Copyable`, paired with a linear context
registration API (`Dependency.Scope.withLinear(...)`). Non-trivial —
requires a parallel `Dependency.Values` variant that stores move-only
values. Probably defer until a concrete use case arises.

### 3.9 Test helpers use `Async.Mutex` unnecessarily

**Current**: `Effect.Test.Recorder` at
`Effects Testing/Effect.Test.Recorder.swift:44`:
```swift
private let _invocations: Async.Mutex<[Invocation]> = Async.Mutex([])
```
Uses the `Async.Mutex` from `swift-async-primitives`. For a test
recorder that only appends and reads, this is reasonable. But the
`Invocation` type at line 19 requires `any __EffectProtocol` storage,
and the lock is acquired on every `.invocations`, `.count`,
`.reset()`, and `.record(...)` call (see lines 47–68). A simpler
`Mutex<[Invocation]>` from stdlib would suffice and drop the
`Async_Primitives` dependency from `Effects Testing`. See Package.swift
line 54 — `Async Primitives` is listed as a dependency exclusively for
this.

**Recommendation (LOW)**: Replace `Async.Mutex` with stdlib `Mutex` in
`Effect.Test.Recorder` and `Effect.Test.Spy`, drop `Async_Primitives`
from `Effects Testing` deps.

### 3.10 Modularization audit findings

Per `swift-effects/Audits/audit.md §F-EFFECTS-001`, there is a known
borderline `MOD-002` violation: `Effects Built-in` independently depends
on `Witness Primitives`; `Effects Testing` independently depends on
`Async Primitives` and `Clocks`. This is acceptable by
`feedback_fine_grained_modularization.md` — variant-specific deps are
allowed. No action needed beyond §3.9 above.

## 4. Current state of io-algebra (brief)

The experiment at `swift-foundations/swift-io/Experiments/io-algebra/`
is a self-contained executable target (Package.swift:7–8). It is not
currently a product — it is proving out a shape.

### 4.1 Public surface

| Symbol | File | Lines |
|--------|------|-------|
| `IO<Environment, LeafError, Value>` | `Sources/IO.swift` | 85–105 |
| `IO.pure` | `Sources/IO.Monad.swift` | 24–41 |
| `IO.fail` | `Sources/IO.Factories.swift` | 13–23 |
| `IO.from` | `Sources/IO.Factories.swift` | 31–35 |
| `IO.map` | `Sources/IO.Monad.swift` | 48–56 |
| `IO.flatMap` | `Sources/IO.Monad.swift` | 63–72 |
| `IO.andThen` | `Sources/IO.Monad.swift` | 79–88 |
| `IO.mapError` | `Sources/IO.Error.swift` | 13–24 |
| `IO.catchAll` | `Sources/IO.Error.swift` | 31–42 |
| `IO.orElse` | `Sources/IO.Error.swift` | 49–61 |
| `IO.recover` | `Sources/IO.Error.swift` | 69–80 |
| `IO.provide` | `Sources/IO.Reader.swift` | 16–23 |
| `IO.local` | `Sources/IO.Reader.swift` | 31–39 |
| `ask<E, F>() -> IO<E, F, E>` | `Sources/IO.Reader.swift` | 52–65 |
| `IO.zip` | `Sources/IO.Applicative.swift` | 16–28 |
| `IO.run` (consuming) | `Sources/IO.swift` | 100–104 |

### 4.2 Design commitments

1. **`IO` is `~Copyable`** (`IO.swift:85`). Each value is single-use.
   `run`, `map`, `flatMap`, `mapError`, etc., all `consuming` self.
2. **No `@Sendable` on stored closure** (`IO.swift:91`): the stored
   `_run` closure has no `@Sendable` attribute. The documentation
   rationale at lines 49–59 is:
   > If `IO` were Copyable, Swift's region checker would need to
   > prove EVERY `IO` value is in a well-defined region across copy
   > lines — which requires `@Sendable` on the stored closure (and
   > thus `Sendable` captures). Marking `IO` as `~Copyable` eliminates
   > aliasing: each IO value has a single owner. Its region is its
   > owner's.
3. **Three load-bearing Sendable constraints at the value-type
   level**:
   - `IO.pure` requires `Value: Sendable` (`IO.Monad.swift:28`).
   - `IO.fail` requires `LeafError: Sendable` (`IO.Factories.swift:16`).
   - `ask()` requires `Environment: Sendable`
     (`IO.Reader.swift:54`).
   The rationale at each site is identical: Swift 6.3's region checker
   requires Sendable to prove that a `sending Value` returned from a
   closure is disconnected from a captured or borrowed source.
4. **`provide` consumes the environment** (`IO.Reader.swift:16–17`):
   ```swift
   public consuming func provide(
       _ env: consuming Environment
   ) -> IO<Void, LeafError, Value>
   ```
5. **`zip` requires `Copyable` values** (`IO.Applicative.swift:19`): a
   Swift-6.3 limitation — tuples of `~Copyable` elements are not yet
   supported, so `zip` currently promises `Value: Copyable, Other:
   Copyable`.
6. **Traversal is not provided** (see `IO.Traversal.swift:1–25`). `Array`
   cannot carry `~Copyable` elements, so no `sequence` / `traverse`.

### 4.3 Theoretical foundation

The header of `IO.swift` at lines 18–28 cites four pedigree sources:

- Wadler 1990 "Linear Types Can Change the World!"
- Bernardy et al. 2018 "Linear Haskell"
- Ahman & Bauer 2020 "Runners in Action" — one-shot resource runners
- OCaml Eio's `~once` effects

Structurally, `IO<R, E, A>` is the ZIO three-parameter encoding
(Wiemann, Scala ZIO, 2017) — a fused Reader–Either–Task monad
transformer stack, not algebraic-effects-with-handlers. The
combinator set is the standard ZIO surface (see `main.swift:43–146`
for the demo exercising each combinator).

The **linearity** claim in the header comment (lines 44–53) is a
departure from classical ZIO: classical ZIO effects are copyable and
may be run many times. `io-algebra` fuses ZIO semantics with
Wadler-style linear tokens. The resulting type is closer to lambda-
coop's "one-shot runner" than to ZIO.

## 5. Modernization needs (io-algebra side, if any)

### 5.1 Missing `deinit` / no trap on dropped `IO`

**Current**: `IO` has no `deinit` (see full `IO.swift`). Dropping an
`IO` without running it is silent — equivalent to affine semantics.

**Check against `[MEM-LINEAR-*]`**: An `IO` is a *description* of a
computation. Dropping it merely means "this computation is never run."
There is no resource to release. This is affine, not linear. Current
design is correct.

**Recommendation**: No action. The doc comment at `IO.swift:44–53`
should be updated to say "affine" (at-most-once) rather than "linear"
(exactly-once) — the `consuming` API is linear-use at the call site,
but the value itself is affine because dropping is permitted.

### 5.2 `~Escapable` opportunity

**Current**: `IO` is `~Copyable` but `Escapable`. Nothing stops a
caller from storing an `IO` in a long-lived heap location. The
single-owner property is preserved (no copy), but the value can escape
the construction scope.

**Check**: Is there a reason to add `~Escapable`? The algebra header
comment at `IO.swift:62–65` says:
> IO values cannot be stored in actor state and invoked repeatedly.
> Each IO is one-shot. Server-style usage where an actor holds an IO
> for its lifetime must reconstruct the IO per-request (or use a
> factory — see `IO.from`).

The desired invariant is: *IO cannot be stored in actor state for
repeated use.* But `~Escapable` would prevent **any** storage — even
within a single task's local variable. This is too strong. The current
`~Copyable` is the right tool: it prevents aliasing (so "repeated
use" is statically impossible because each run consumes the value),
while still allowing assignment, passing, and local storage for a
single use.

**Recommendation**: No action. `~Escapable` is the wrong tool here.

### 5.3 The actor-storage blocker

**Current**: The prompt identifies:
> The `~Copyable` IO blocker identified in the parent conversation is
> "cannot be stored on actors for repeated use."

This is documented at `IO.swift:62–65`. An actor that wants to hold
an IO for its lifetime and invoke it many times per request cannot do
so: each invocation would need to `consume` the IO, and `~Copyable`
prevents the needed copy.

**Three resolutions**:

1. **Factory pattern** — store `() -> sending IO<R, E, A>` on the
   actor, not an `IO` itself. The stored closure is `@Sendable`,
   constructs a fresh `IO` per call. This works today; see the prompt
   quote above. Drawback: loses the combinator chain — you'd store
   `makeIO: () -> IO` and build combinators per invocation.
2. **Copyable wrapper** — declare `public struct IO.Factory<R, E, A>`
   as a `Sendable` copyable type wrapping
   `@Sendable (sending R) async throws(E) -> sending A`. This brings
   back `@Sendable` on the closure but restores actor storability.
   Users opt in explicitly.
3. **`Reference.Box<IO<R, E, A>>`** — heap-box the IO. Store the Box
   on the actor, `.take()` on each invocation. Requires per-invocation
   reinitialization after take. This is the
   `feedback_no_raw_descriptor_reconstruction.md` pattern.

Options (1) and (2) coexist: `io-algebra` can ship both. `IO` for
single-use computations; `IO.Factory` (or a free
`func asFactory() -> @Sendable () -> sending IO<R, E, A>`) for actor
storage.

**Recommendation (MEDIUM)**: Add `IO.Factory<R, E, A>` — a
`Sendable` copyable wrapper producing fresh `IO` values on demand.
This adds one opt-in type, keeps the linear `IO` as the primary
surface, and solves the actor-storage use case without compromising
`io-algebra`'s "no `@Sendable`" invariant at the linear layer.

### 5.4 Typed throws: already good

**Current**: Every signature uses `throws(LeafError)` or
`throws(NewError)`:
- `IO.swift:91` — `async throws(LeafError)`.
- `IO.Error.swift:15,32,50,71` — `throws(NewError)`, `throws(Never)`, etc.
- `IO.Monad.swift:50,64,80` — all typed.

Matches `[API-ERR-001]`. No action.

### 5.5 Sendable constraint minimization

**Current**: Three load-bearing `Sendable` constraints, each
documented with the compiler-level reason. `IO.Monad.swift:28–38`:
> Value-type Sendable constraints are distinct from `@Sendable`
> function-type attributes (which we are avoiding). They describe
> properties of the value, not of the closure.

This is the correct framing. These three constraints are required by
the 6.3 region checker; they are not workarounds and should not be
removed.

**Recommendation**: No action.

### 5.6 `zip` for `~Copyable` values

**Current**: `IO.Applicative.swift:19` requires `Value: Copyable, Other:
Copyable`. Swift 6.3 does not support tuples of `~Copyable` elements.

**Resolution path**: A named 2-element pair struct:
```swift
public struct IO.Pair<First: ~Copyable, Second: ~Copyable>: ~Copyable {
    public let first: consuming First
    public let second: consuming Second
}
```
Then `zip` returns `IO<R, E, IO.Pair<Value, Other>>`. More verbose than
a tuple but works for `~Copyable` payloads.

**Recommendation (LOW)**: Ship the tuple-only version now. Add
`zipPair` or a nested `.Pair` later when actually needed.

### 5.7 Traversal

**Current**: `IO.Traversal.swift:1–25` documents that `sequence` and
`traverse` over `Array<IO>` are impossible because `Array` cannot hold
`~Copyable`. No action available until Swift evolves.

**Alternative**: `~Copyable` list primitives from `swift-primitives`
(e.g., the ~Copyable deque per
`memory_index.project_noncopyable_deque_api.md`) may suffice when
available. Defer.

## 6. Structural relation — how IO's Reader-Either maps to effects + handlers

### 6.1 Direct type-level mapping

Align `io-algebra`'s type constructors with `swift-effects`' type
constructors:

| `io-algebra` | `swift-effects` |
|--------------|-----------------|
| `IO<R, E, A>` | (no direct type; a computation that `perform`s effects, with an `R` drawn from `Context` and an `E` thrown) |
| `IO.pure(a)` | `Task { return a }` wrapped as an infallible effect; *not a perform* |
| `IO.fail(e)` | `Task { throw e }` wrapped; not a perform |
| `IO<R, E, A>.flatMap(f)` | sequential composition — no direct analog; handlers deliver a single value |
| `IO.mapError(f)` | re-throw translation in a wrapping handler |
| `IO.provide(env)` | `Effect.Context.with { handlers[RKey.self] = env } operation: { ... }` — partially |
| `IO.local(narrow)` | `Effect.Context.with { handlers[RKey.self] = narrow(currentR) }` |
| `ask() -> IO<R, E, R>` | `let r = Effect.Context.current[RKey.self]` — immediate |
| `IO.run(env)` | `Effect.Context.with { handlers[...] = env } operation: { try await effectBody() }` |

The correspondence is **partial**. The key gap is: `swift-effects` has
no type-level notion of "a computation parameterized over an
environment that produces a value of type A or fails with type E."
Effects are *operations*, not *computations*. A computation is plain
Swift async code with side effects of invoking `Effect.perform(_:)`.

### 6.2 What happens in each surface when you try to express the other

**`io-algebra` → `swift-effects`**: An `IO<R, E, A>` is "a computation
that reads `R`, may throw `E`, and yields `A`". To translate to
effects: make `R` a `Dependency.Key` whose `Value` is the environment;
the computation body does `let env = Effect.Context.current[RKey.self]`
and proceeds. Errors thrown from the async body are typed-thrown
naturally. No effect *operation* is needed if you treat the
environment as dependency, not as effect. So `IO<R, E, A>` becomes
plain `async throws(E) -> A` under effects, with `R` in Context.

**`swift-effects` → `io-algebra`**: An
`Effect.perform(someEffect)` call is "suspend the current computation,
ask the handler registered for `someEffect`'s `HandlerKey` to produce
a value." `io-algebra` has no handler registry — the
computation body receives `R` directly and calls methods on it. To
express a handler-like structure: make `R` a struct of capability
closures (i.e., a `@Witness` struct), then `ask()` retrieves it and
the computation invokes closures off it.

### 6.3 The critical non-equivalence

The mapping in §6.1 is lossy in one direction:

**`IO.flatMap` is sequential composition of two computations.** Given
`io1: IO<R, E, A>` and `f: (A) -> IO<R, E, B>`, `io1.flatMap(f)` runs
`io1`, threads its result through `f`, runs the resulting `IO<R, E, B>`,
and yields `B`.

**`Effect.perform` is a single synchronous point** — it suspends,
calls the handler, resumes with the value. There is no notion of
"perform and then compose with another perform using the value of the
first" at the **effect type** level — you write that composition in
ordinary Swift:
```swift
let a = try await Effect.perform(Op1())   // point 1
let b = try await Effect.perform(Op2(a))  // point 2
```
The composition happens in the ambient async context; the effect
types don't compose.

`io-algebra` **reifies the composition** as a value — `flatMap` produces
a new `IO`. `swift-effects` **erases the composition into the host
language** — there is no `Effect<R, E, A>` type; there is just Swift's
async context and a stream of `perform` points.

This is the classical Scott-Strachey distinction between a
**shallow embedding** (effects = sugar over host-language async;
composition via host-language control flow) and a **deep embedding**
(computations as reified values; composition via combinators on
values). `swift-effects` is shallow; `io-algebra` is deep.

## 7. Can io-algebra be a specialization of swift-effects?

### 7.1 The naive attempt

Could `IO<R, E, A>` be defined as an effect that carries its own
handler registry? Imagine:

```swift
public struct IO<R, E: Error, A>: EffectProtocol, EffectWithHandler {
    public typealias Value = A
    public typealias Failure = E
    public typealias HandlerKey = Key

    public struct Key: EffectContextKey {
        public typealias Value = IO.Handler
        public static var liveValue: IO.Handler { .live }
    }

    public let body: (R) async throws(E) -> A
}
```

This doesn't compile for three reasons:

1. **`EffectProtocol.Value: Sendable` required.** Our `A` must be
   `Sendable`. `io-algebra`'s `Value` can be `~Copyable`. Effects
   cannot carry `~Copyable` return values.
2. **`EffectProtocol: Sendable` required.** The effect *value itself*
   must be Sendable, which propagates through its stored closure —
   hence `@Sendable` on `body`. `io-algebra` specifically avoids
   this.
3. **Stored closures in effect types.** `Fetch` stores a `URL`
   (example from `Effect.Protocol.swift:25–27`). The pattern is
   "effect carries its arguments, handler does the work." Our `IO`
   carries **the entire computation** as its body — that's not an
   effect, that's a program.

### 7.2 Going the other way — IO as a handler composer

Alternative: define `IO<R, E, A>` as a *result of handler
composition*. Every `IO<R, E, A>` compiles down to:

```swift
try await Effect.Context.with { handlers in
    handlers[RKey.self] = environment
} operation: {
    // the body of the IO, written as ordinary Swift async code
    // that may `perform` effects
}
```

This works — `io-algebra`'s `IO` is a *reification* of the `Context.with
+ operation` pattern. Each `flatMap` is just sequential async code
inside the `operation` closure. Each `provide` is a nested
`Context.with`.

But this reification is exactly what `io-algebra` *is*. Treating
`io-algebra` as a specialization of `swift-effects` means: `io-algebra`
is "`swift-effects` with environment captured in `Dependency.Scope` and
computations reified as `~Copyable` closures." That is a correct but
unhelpful reduction — it obscures rather than clarifies the
specialization.

### 7.3 The deeper incompatibility

The three-parameter shape `IO<R, E, A>` encodes:
- **R** in a *type-level* position: you cannot construct an `IO<R, E, A>`
  without committing to an `R`, and you can only `run` it with an `R`.
- **E** in a *type-level* position: errors thrown are statically typed.
- **A** in a *type-level* position: the success type is statically typed.

Effects in `swift-effects` encode:
- **R** in a *runtime* position: `Dependency.Scope.current[RKey.self]`
  is a dictionary lookup, not a type-level commitment.
- **E** via `Failure` on each effect type — but errors flowing through
  the ambient async context can accumulate from many different
  effects' Failures.
- **A** on each effect type — but **the computation as a whole** has
  whatever return type the programmer wrote on the outer `async`
  function.

`io-algebra`'s three parameters are **type-level properties of a
computation**. `swift-effects`' triple
`(Arguments, Value, Failure)` are **type-level properties of an effect
operation**. Not the same concept.

### 7.4 Verdict

`io-algebra` is not a specialization of `swift-effects` in any useful
sense. It is a peer abstraction that overlaps on some concerns.

## 8. Algebra-first synthesis — isomorphism check

### 8.1 The categorical statement

The monadic formulation:
```
ReaderT r (ExceptT e Task) a
  ≅  r -> Task (Either e a)
```
is the Reader-Either monad transformer stack. `io-algebra`'s `IO<R, E, A>`
is a Swift encoding of this (with `sending`, `~Copyable`, and
async semantics).

Algebraic effects with handlers, per Plotkin–Pretnar, model effectful
computations as:
```
Comp A  ≅  free-monad over the effect signature Σ
```
where `Σ` is a set of operation signatures. A handler is a fold /
catamorphism from `Comp A` to some other carrier (often `Task A` or
`Reader r Task A`).

### 8.2 The equivalence

Kammar-Lindley-Oury 2013 "Handlers in Action" §2.4 and Pirog et al.
2019 "Typed Equivalence of Effect Handlers and Delimited Control" both
establish:

> For every monad transformer `T` expressible as a free monad over a
> signature `Σ_T`, there is an equivalence:
>
>     (a : T r a)  ≅  (a : Comp_{Σ_T} a, handled by the canonical T-handler)
>
> where the handler reifies `T`'s operations as effects.

For `ReaderT r (ExceptT e Task)`, the signature `Σ` contains:
- `ask : R` — get the environment
- `local : (R → R) → Comp A → Comp A` — adapt the environment (local binding)
- `throw : E → Comp A` — signal failure
- `catch : Comp A → (E → Comp A) → Comp A` — handle failure

These are **exactly** the operations `io-algebra` exposes:

| `io-algebra` | `Σ_{ReaderT/ExceptT}` operation |
|--------------|--------------------------------|
| `ask()` | `ask : R` |
| `local(narrow)` | `local : (R → R) → Comp A → Comp A` |
| `provide(env)` | specialized `local` to constant |
| `fail(e)` | `throw : E → Comp A` |
| `catchAll(recover)` | `catch : Comp A → (E → Comp A) → Comp A` |
| `mapError(f)` | `catch . (throw ∘ f)` |
| `orElse(fallback)` | `catch _ → fallback` |

And the monad structure:

| `io-algebra` | Monad |
|--------------|-------|
| `pure` | `η : A → Comp A` |
| `flatMap` | `(>>=) : Comp A → (A → Comp B) → Comp B` |
| `map` | derived from `pure` + `flatMap` |
| `andThen` | `*>` — sequence and discard |

So the equivalence **holds mathematically**: Reader-Either monad
transformer and the corresponding algebraic-effects-plus-canonical-
handler are denotationally identical.

### 8.3 What the equivalence says about the ecosystem

Two surfaces, same computation:

1. **`io-algebra` surface**: `IO` values carrying a bundled closure.
   Combinators `map`/`flatMap`/`provide`/`local`/`ask`/`fail`/`catchAll`
   implement the monad-transformer operations directly.
2. **`swift-effects` surface**: effect types (`Ask`, `Local`, `Fail`,
   `Catch`) declared as `EffectProtocol`, performed with
   `Effect.perform(_:)`, interpreted by a handler that delegates to
   `Dependency.Scope`.

The differences are **surface**:

| Aspect | `io-algebra` | `swift-effects` |
|--------|--------------|-----------------|
| Reification | Yes — `IO` is a value | No — computations are async functions |
| Combinators | First-class (chain on the value) | External (ambient async code) |
| Static effect tracking | Yes (R, E, A in type) | No (R in dictionary, E in throws, A in return) |
| Handler composition | Baked in (closure composition) | Dynamic (nested `Context.with`) |
| Runtime overhead | Closure-call per combinator | Task spawn per `perform` |
| Ergonomics | Point-free / combinator style | Imperative-async style |

### 8.4 Which surface fits the ecosystem?

Both are legitimate. The ecosystem's other packages align more with
**imperative-async style**:
- `swift-io`'s IO witness (final shape in
  `io-witness-design-literature-study.md §Final Shape v4.0`) is a
  capability used from imperative async code: `let n = try await
  io.read(...)`.
- `swift-kernel`'s descriptor APIs return values directly from `async
  throws(...) -> T`.
- `swift-async-primitives`' `Task`, `Mutex`, `Channel` are all used
  from imperative async code.

The combinator style of `io-algebra` is an outlier. It is correct and
useful for certain domains (orchestration, retry composition,
dependency-injected pipelines), but it is not the ecosystem's default
idiom.

`swift-effects` fits the ecosystem idiom. `io-algebra` is a specialist
tool for a specific style of programming (ZIO-style orchestration).

## 9. `~Copyable` and `~Escapable` leverage opportunities

### 9.1 `swift-effects` opportunities

1. **`~Copyable` linear handlers** — §3.8. Some handlers (e.g., one
   that owns a descriptor) would benefit from single-use semantics.
   The current `Dependency.Values` dictionary requires Copyable values
   because it is a **copyable** type. A parallel `Dependency.LinearScope`
   with move-only registration would enable this, but is a substantial
   L1 addition.
2. **`~Copyable` effect values** — `Effect.Exit` at
   `Effects Built-in/Effect.Exit.swift:14` carries an `Int32`. Trivially
   Copyable. But consider an effect that transfers a `Kernel.Descriptor`
   — that's `~Copyable`. Currently impossible because `EffectProtocol`
   requires `Sendable` (thus Copyable at the associated-type level for
   `Arguments` and `Value`). Widening this requires moving
   `EffectProtocol` off the Sendable-Copyable assumption; see the
   existing `Effect.Protocol.swift:37,39` associated-type
   constraints: `associatedtype Arguments: Sendable = Void`,
   `associatedtype Value: Sendable`. These need to become `: ~Copyable
   & Sendable` — per
   `feedback_no_degrade_noncopyable.md`. This is the right
   modernization target.
3. **`sending` on continuation resume** — already done at
   `Effect.Continuation.One.swift:46,56,66`. Good.

### 9.2 `io-algebra` opportunities

1. **Keep `~Copyable` IO** — the foundation is correct.
2. **Add `IO.Factory` copyable companion** — §5.3. Unblocks actor
   storage without compromising the linear layer.
3. **`zip` over `~Copyable`** — requires a `Pair` struct (§5.6). Low
   priority.
4. **`~Escapable` — do not add** — §5.2. Prevents legitimate uses.

### 9.3 Cross-package consolidation

The deepest leverage is **making `EffectProtocol` accept `~Copyable
Value`**. This would allow `swift-effects` to express effects that
transfer move-only resources. It also eliminates the
`Reference.Box<Value>` workaround documented in `swift-effect-primitives/
Research/Algebraic Effects in Swift.md §5.3` — currently the pool's
`Acquire` effect returns `Reference.Box<Resource>` because
`associatedtype Value: Sendable` (i.e., Copyable-by-default) cannot
express `Resource: ~Copyable`.

**Recommendation (HIGH)**: Update `__EffectProtocol` associated-type
constraints to
`associatedtype Value: ~Copyable & Sendable` and
`associatedtype Arguments: ~Copyable & Sendable = Void`. Propagate
`~Copyable` through `Effect.Continuation.One.Value`,
`Effect.Handler.Handled.Value`, and related paths. Verify
`Effect.Outcome<Value, Failure>` can hold move-only values (likely
requires making Outcome `~Copyable` when Value is — via
`[MEM-COPY-004]` extension constraints).

## 10. Actor-storage consideration (the `~Copyable` blocker)

### 10.1 Problem restatement

An actor wants to hold something that represents "a pre-built
computation" and invoke it per request. Under `io-algebra`'s linear
model, this is impossible: each `IO` is single-use.

### 10.2 Mapping against `swift-effects`

Does `swift-effects` suffer the same blocker? Consider: an actor holds
an effect handler (which implements the operations). This works
today — handlers are Copyable Sendable structs, they can be stored on
actor state and invoked repeatedly. But the actor does **not** hold an
"IO" — it holds a handler. The "computation" is whatever async code
the actor runs, which may `perform` effects against the handler.

This is exactly the §6.3 shallow-vs-deep distinction. `swift-effects`
doesn't have the blocker because it never reifies the computation —
there is nothing to store. `io-algebra` has the blocker because it
reifies the computation as `IO`.

### 10.3 Resolution (both surfaces)

| Need | Surface | API |
|------|---------|-----|
| "Actor runs a computation per request" | imperative-async | `actor { func handle() async throws(E) -> A { ... perform/invoke ... } }` |
| "Actor holds a recipe for a computation, runs each time" | `io-algebra` | `IO.Factory<R, E, A>` — copyable, produces fresh `IO` |
| "Actor holds a handler, runs arbitrary effect code" | `swift-effects` | stored handler; `Effect.Context.with` per request |
| "Actor builds a DAG of computations" | `io-algebra` | store `IO`s in `Reference.Box`, `.take()` per request |

The **design question** is: does an ecosystem consumer ever genuinely
want "a reified computation stored on an actor"? If yes, ship
`IO.Factory`. If not, the blocker is a non-blocker and the linear
design is fine as-is.

**Recommendation**: Add `IO.Factory` **conditionally** — gate on a
real use case. The experiment should be tested against the actual
downstream workload (e.g., an HTTP server that caches request-
handling pipelines) before committing the companion type.

## 11. Recommendation

**Verdict: (c) Modernize both; revisit relationship after.**

The §6 and §7 analysis establishes that `io-algebra` and
`swift-effects` are **not the same abstraction**. `io-algebra` is a
deep embedding (reified Reader-Either monad transformer); `swift-
effects` is a shallow embedding (handler-dispatched effects over
async). The §8 equivalence is denotational — they model the same
computations — but the surfaces serve different programming styles.

Collapsing them into one framework is neither feasible nor desirable:

1. `io-algebra` cannot be a specialization of `swift-effects` (§7.4).
2. `swift-effects` cannot be a specialization of `io-algebra` (the
   other direction requires reifying all effects as `IO` values,
   losing handler dispatch).
3. The ecosystem's other packages are idiomatically aligned with
   `swift-effects`' imperative-async style (§8.4). `io-algebra` is an
   outlier specialist tool.

However, both need modernization before the question of unification
can be re-examined:

**`swift-effects` — Top 3**:

1. **[HIGH] Widen `EffectProtocol` to `~Copyable` associated types** (§9.3). Enables move-only effects, eliminates the `Reference.Box<Resource>` workaround in pool effects, and aligns with the ecosystem's ownership-first design.
2. **[MEDIUM] Eliminate force-cast in `Effect.perform`** (§3.1). The `throw error as! E.Failure` at `Effect.perform.swift:38` is a latent crasher; replace with the `Result<Value, Failure>`-wrapping pattern used by `Dependency.Scope.with`.
3. **[MEDIUM] Drop hoisted internals from public surface** (§3.2). Replace `__EffectProtocol` with `EffectProtocol` and `__EffectHandler` with `EffectHandler` across public signatures per `feedback_no_hoisted_error_shortcut.md`.

**`io-algebra` — Top 3**:

1. **[MEDIUM] Update "linear" wording to "affine"** (§5.1). The `IO.swift:44–53` comment implies linear (exactly-once); actual semantics are affine (at-most-once). Minor but important for doc correctness.
2. **[MEDIUM] Decide on `IO.Factory` and implement if justified** (§5.3). The actor-storage blocker needs a concrete use case before adding the companion type; once justified, ship a copyable `Sendable` factory producing fresh `IO`s.
3. **[LOW] Promote from Experiments to a proper package when stable** (§4). Currently an executable target at `Experiments/io-algebra/`; if the linearity-without-`@Sendable` claim validates under test, promote to L3 (`swift-foundations/swift-io-algebra` or similar).

After both modernizations land, the relationship question can be
revisited. Expected outcome: they remain peer abstractions serving
different programming styles. Expected contribution from one to the
other:

- `swift-effects` should adopt `io-algebra`'s "no `@Sendable` on
  closures" insight for handlers that are genuinely single-use —
  probably via the Linear Handler variant (§3.8) if a use case
  materializes.
- `io-algebra`, if promoted, should integrate with
  `swift-effects` for **operation-level effects** performed inside an
  `IO` body. An `IO<R, E, A>` whose body uses
  `try await Effect.perform(SomeOp())` is a legitimate composition —
  `R` handles the environment, `SomeOp` handles the side effect,
  `IO` handles the orchestration.

## 12. References

### Academic

- Plotkin, G., & Pretnar, M. (2009). *Handlers of Algebraic Effects*. ESOP.
- Kammar, O., Lindley, S., Oury, N. (2013). *Handlers in Action*. ICFP.
- Leijen, D. (2017). *Type Directed Compilation of Row-Typed Algebraic Effects*. POPL.
- Ahman, D., & Bauer, A. (2020). *Runners in Action*. ESOP.
- Ahman, D., & Pretnar, M. (2021). *Asynchronous Effects*. POPL.
- Xie, N., & Leijen, D. (2021). *Generalized Evidence Passing for Effect Handlers*. ICFP.
- Brachthäuser, J., Schuster, P., Ostermann, K. (2020). *Effects as Capabilities*. OOPSLA.
- Pirog, M., Schuster, P., Brachthäuser, J., Ostermann, K. (2019). *Typed Equivalence of Effect Handlers and Delimited Control*. FSCD.
- Wadler, P. (1990). *Linear Types Can Change the World!*.
- Bernardy, J.-P., Boespflug, M., Newton, R. R., Peyton Jones, S., Spiwack, A. (2018). *Linear Haskell: Practical linearity in a higher-order polymorphic language*. POPL.
- Peyton Jones, S. L., & Wadler, P. (1993). *Imperative Functional Programming*. POPL.
- Filinski, A. (1994). *Representing Monads*. POPL.

### Ecosystem — Sources examined

- `/Users/coen/Developer/swift-foundations/swift-effects/Package.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects/exports.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects/EffectWithHandler.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects/Effect.perform.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects Built-in/Effect.Exit.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects Built-in/Effect.Yield.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects Testing/Effect.Test.Handler.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects Testing/Effect.Test.Recorder.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Sources/Effects Testing/Effect.Test.Spy.swift`
- `/Users/coen/Developer/swift-foundations/swift-effects/Audits/audit.md`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Protocol.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Handler.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Context.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.One.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Continuation.Multi.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.Outcome.swift`
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Sources/Effect Primitives/Effect.perform.swift`
- `/Users/coen/Developer/swift-primitives/swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Key.swift`
- `/Users/coen/Developer/swift-primitives/swift-dependency-primitives/Sources/Dependency Primitives/Dependency.Scope.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Package.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Monad.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Error.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Factories.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Reader.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Applicative.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/IO.Traversal.swift`
- `/Users/coen/Developer/swift-foundations/swift-io/Experiments/io-algebra/Sources/main.swift`

### Ecosystem — Related research

- `/Users/coen/Developer/swift-foundations/swift-io/Research/io-witness-design-literature-study.md` (v4.0) — witness vs effects equivalence; runners calculus; evidence passing
- `/Users/coen/Developer/swift-primitives/swift-effect-primitives/Research/Algebraic Effects in Swift.md` (v1.0) — implementation-level rationale for hoisted protocol pattern, `Reference.Box` workaround
- `/Users/coen/Developer/swift-foundations/Research/io-driver-witness-composition.md`
- `/Users/coen/Developer/swift-foundations/Research/io-witness-experiment-results.md`

### Governance and constraints

- `[API-ERR-001]` — Typed throws (`/Users/coen/Developer/CLAUDE.md`)
- `[API-IMPL-005]` — One type per file
- `[MEM-COPY-001]` — Noncopyable type declaration
- `[MEM-COPY-004]` — Extension constraints for `~Copyable`
- `[MEM-LINEAR-001]` — Exactly-once (linear) types
- `[MEM-LINEAR-002]` — At-most-once (affine) types
- `[MEM-SEND-002]` — Sendability tiers
- `feedback_throws_not_result.md` — Typed throws over Result
- `feedback_no_hoisted_error_shortcut.md` — No hoisted internals in public API
- `feedback_no_degrade_noncopyable.md` — Preserve `~Copyable` through conversion
- `feedback_fine_grained_modularization.md` — Variant-specific deps allowed
- `feedback_continuation_dispatch_pattern.md` — `withCheckedContinuation` + `Task<Void, Never>` to avoid T: Sendable
