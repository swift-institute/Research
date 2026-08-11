# IO Witness Design: Literature Study

<!--
---
version: 4.0.0
last_updated: 2026-04-14
status: IN_PROGRESS
tier: 2
related:
  - ../../../swift-foundations/swift-executors/Research/io-blocking-executor-binding.md (v4.0 — Shape B recommendation; relocated 2026-04-20)
  - ../../../swift-foundations/swift-io/Research/io-context-actor-analysis.md (v3.0 — reconciled with Shape B)
  - ../../../swift-foundations/swift-io/HANDOFF-actor-runner-investigation.md (Shape B experiments)
  - io-witness-borrowing-async-tension.md
  - ../../../swift-foundations/Research/io-driver-witness-composition.md
  - ../../../swift-foundations/Research/io-witness-experiment-results.md
  - swift-effects (algebraic effects infrastructure)
  - swift-effect-primitives (Effect.Protocol, Effect.Handler, Effect.Context)
---
-->

> **Cross-package note (2026-04-20)**: this document was moved from
> `swift-foundations/swift-io/Research/` to
> `swift-primitives/swift-io-primitives/Research/`. Frontmatter paths are
> now true relative paths. Body references in shorthand
> (e.g. "io-blocking-executor-binding.md v3.0") resolve at:
> - documents that *also moved here*: same directory (`io-witness-borrowing-async-tension.md` etc.)
> - `io-blocking-executor-binding.md`: relocated to `../../../swift-foundations/swift-executors/Research/`
> - other swift-io docs (`perfect-api.md`, `io-architecture.md`, `io-context-actor-analysis.md`, `io-phase-2-plan.md`, etc.): `../../../swift-foundations/swift-io/Research/`

<!--
---
changelog-history:
  - v4.0: Updated Q3 resolution and Final Shape to reflect **Shape B** (blocking-
    executor-binding v4.0). v3.0 made `IO` itself an actor (Shape A); v4.0 keeps
    `IO` as a `@Witness` struct of async closures with each strategy's runner as
    an internal actor impl. This separates capability (witness) from runner
    (actor) cleanly — upgrades Effects-as-Capabilities alignment from B to A-
    (value-type capability, not ref-type). Consumer API unchanged.
  - v3.0: Updated Q2/Q3 resolutions and Final Witness Shape to reflect Option F
    (io-blocking-executor-binding.md v3.0). The sync-closure-in-Context design is
    retained at the implementation layer (internal @Witness), but the public
    surface is now the `IO` actor wrapping Context. Consumer API shifts from
    `try await IO.run(io) { ctx in try ctx.read(...) }` (sync call inside closure)
    to `let io = IO.blocking(); try await io.read(...)` (async call per op).
    Theoretical grounding (Runners calculus, evidence passing, capability objects)
    is unchanged.
  - v2.0: Initial literature-study scoping.
---
-->

## Context

`IO` is now a `@Witness` struct with consumer-facing operation closures
(`_read`, `_write`, `_accept`, `_close`). The open problem: how should
`IO.run` work, and how do sync closures compose with async execution
contexts across blocking, reactor, and proactor strategies?

## Question

How do production I/O frameworks and academic theory inform the design
of `IO.run { ctx in }` for composing blocking, reactor, and proactor
strategies behind a single consumer API?

## Prior Art: Production Frameworks

### The Fundamental Split: Reactor vs Proactor

| | Reactor (readiness) | Proactor (completion) |
|-|---|---|
| Systems | epoll, kqueue, Go netpoller, tokio/mio | IOCP, io_uring |
| Notification | "fd is ready" | "operation completed with N bytes" |
| Who does I/O | Application (after readiness check) | Kernel (we submit, OS executes) |
| Buffer ownership | Caller owns always | Kernel owns during operation |
| Consumer API | poll → read | submit → drain |

No production framework has successfully unified these under identical
signatures WITHOUT either (a) copying buffers internally, or (b) changing
the consumer API.

### Framework Survey

**Go**: Hides everything. `Read([]byte)` blocks the goroutine, runtime
handles reactor internally. Consumer sees sync API. Not swappable.
Closest to our `IO.run { ctx in ctx.read(...) }` pattern.

**Tokio (Rust)**: `AsyncRead`/`AsyncWrite` traits, reactor-only.
io_uring runtimes (monoio, glommio) have INCOMPATIBLE traits —
monoio uses "rental" pattern (`rent_mut(buf) → (buf, result)`)
because the kernel needs buffer ownership. No unified trait exists
across reactor and proactor in Rust.

**Boost.Asio (C++)**: Proactor API on all platforms. On UNIX, simulates
proactor over reactor (poll for readiness, then do I/O, invoke handler
as if async). The "Proactor in terms of Reactor" bridge. Template-based
backend swapping.

**Netty (Java)**: `Channel` abstraction, same API across NIO/epoll/
kqueue/io_uring. Swappable at boot via `ChannelFactory`. Handler
pipeline processes events uniformly. io_uring support is incubating.

**SwiftNIO**: `Channel` + `ChannelPipeline` + `EventLoop`. Not runtime-
swappable. Reactor only (epoll/kqueue). io_uring experimental.

**libuv**: Handles + Requests + Callbacks. Reactor internally. Thread
pool for file I/O. Not swappable. IOCP on Windows bridged to reactor API.

### Key Insights from Production

1. **Go's approach is closest to ours.** Sync API, runtime handles mechanism.
2. **Nobody unified reactor + proactor in one trait** — Rust gave up.
3. **Boost.Asio's bridge works**: proactor-in-terms-of-reactor (and vice versa).
4. **Buffer ownership is the crux** — Go solves it by hiding the proactor.

## Academic Foundations

### 1. Algebraic Effects and Handlers

**Key papers**:
- Plotkin & Pretnar, "Handlers of Algebraic Effects" (2009, ESOP)
- Kammar, Lindley, Oury, "Handlers in Action" (2013, ICFP)
- Leijen, "Type Directed Compilation of Row-Typed Algebraic Effects" (2017, POPL)
- Ahman & Pretnar, "Asynchronous Effects" (2021, POPL)
- **Ahman & Bauer, "Runners in Action" (2020, ESOP)** — primary theoretical model
- Xie & Leijen, "Generalized Evidence Passing for Effect Handlers" (2021, ICFP)

**Core insight**: `IO.run { io in io.read(...) }` IS an algebraic effect handler
in the precise theoretical sense. The handler (IO witness) provides the unique
homomorphism from abstract operations to concrete implementations.

**Runners (Ahman & Bauer 2020)** are the precise theoretical model — not handlers,
not monads, but *runners*. A runner manages external resources at the computation
boundary, provides operations to the computation, and guarantees linear resource
use and finalization. Lambda-coop mapping:

| lambda-coop | swift-io |
|---|---|
| Runner | `IO` witness |
| Runner's operations | `_read`, `_write`, `_accept`, `_close` |
| `using R run M` | `IO.run { io in ... }` |
| Finalization | cleanup on scope exit |
| Linear resource use | `consuming Kernel.Descriptor` |

**Asynchronous Effects (Ahman & Pretnar 2021)** directly resolves the reactor/
proactor split. Effect execution decomposes into *signalling* (operation requested)
and *interrupting* (result delivered). Reactor = signal readiness then perform
synchronously. Proactor = signal operation then interrupt with completion. Both
coexist under the same effect signature with different handlers.

**Evidence passing (Xie & Leijen 2021)** reveals the witness struct IS the known
optimal compilation strategy. An evidence vector is a record of handler function
implementations — structurally identical to `@Witness struct IO { let _read: ... }`.
Not analogy; same data structure.

### 2. Monadic I/O

**Key papers**:
- Peyton Jones & Wadler, "Imperative Functional Programming" (1993, POPL)
- Wadler, "The Essence of Functional Programming" (1992, POPL)

Haskell's `State# RealWorld` token and `borrowing Kernel.Descriptor` serve
analogous roles: both are linear tokens enforcing single-threaded access to
external resources. Swift's descriptor is stronger — it carries both the
sequencing guarantee AND the resource identity (not phantom).

The witness pattern avoids the IO monad's weakness: the monad is a single
fixed interpretation. The witness makes interpretation explicit as a value.

### 3. Linear Types and I/O

**Key papers**:
- Wadler, "Linear Types Can Change the World!" (1990)
- Bernardy et al., "Linear Haskell" (2018, POPL)
- withoutboats, "Notes on io-uring" (2020) — technically precise blog

**The proactor buffer ownership problem is a linear types problem.** Reactor
borrows buffers; proactor must consume them. The current `_read` signature
encodes reactor semantics. For proactor, the witness closure must internally
handle the ownership transfer — consuming the buffer, submitting to kernel,
waiting for completion, writing back. This is sound as long as the suspension
prevents user access during the kernel operation.

### 4. Reactor and Proactor Patterns (Formal)

**Key papers**:
- Schmidt, "Reactor" (1995, PLoPD) and "Proactor" (1997, PLoP)
- Schmidt et al., POSA2 (2000)

Schmidt noted the difficulty of creating unified interfaces for both patterns.
The witness pattern achieves what POSA2 said was difficult — by making the
strategy a value rather than a framework structure.

### 5. Delimited Continuations

**Key papers**:
- Filinski, "Representing Monads" (1994, POPL)
- Pirog et al., "Typed Equivalence of Effect Handlers and Delimited Control" (2019, FSCD)
- Sivaramakrishnan et al., "Retrofitting Effect Handlers onto OCaml" (2021, PLDI)

Equivalence chain: `Monads ≡ Delimited Continuations ≡ Algebraic Effect Handlers`.
The witness pattern is not "one approach among many" — it is a different surface
syntax for the same computational structure. OCaml 5's Eio library (effects-based
I/O) is the closest practical precedent.

### 6. Capabilities

**Key papers**:
- Miller, "Robust Composition" (2006, PhD thesis)
- **Brachthaeuser, Schuster, Ostermann, "Effects as Capabilities" (2020, OOPSLA)**
- Schuster et al., "Compiling Effect Handlers in Capability-Passing Style" (2020, ICFP)

**The IO witness IS a capability** in the formal sense. Brachthaeuser et al.
proved that effect handlers and capabilities are the same thing. Capabilities
are second-class: passed as arguments, cannot escape scope. This maps directly
to `IO.run { io in }` — `io` cannot escape the closure body.

**150x speedup** from capability-passing compilation (Schuster et al. 2020) —
passing a struct of handler functions dramatically outperforms dynamic lookup.
The witness-struct pattern is the fastest known compilation strategy.

### 7. Session Types

**Key papers**:
- Honda, Vasconcelos, Kubo, "Language Primitives for Structured Communication" (1998, ESOP)
- Caires & Pfenning, "Session Types as Intuitionistic Linear Propositions" (2010, CONCUR)

Reactor session: `?Readiness.!ReadRequest.?Data.end`.
Proactor session: `!ReadRequest.?Completion.end`.
The witness closure is a *protocol adapter* presenting a uniform session type
to the consumer while implementing a different one toward the kernel.

## Existing Infrastructure: swift-effects

The ecosystem already has algebraic effects infrastructure at L1 and L3:

**swift-effect-primitives** (L1):
- `Effect.Protocol` — effect type (the academic "effect signature")
- `Effect.Handler.Protocol` — handler with `consuming Effect.Continuation.One`
- `Effect.Context` — scoped handler registration via task-local storage
- `Effect.Continuation.One` — one-shot continuation (exactly the theory)

**swift-effects** (L3):
- `EffectWithHandler` — links effect types to handler keys
- `Effect.perform(_:)` — performs effect by looking up handler from context
- `Effect.Context.with { handlers in } operation: { }` — scoped execution

**Mapping to IO**:

| Effect concept | IO design |
|---|---|
| `Effect.Protocol` | `IO.Read`, `IO.Write`, `IO.Accept` as effect types |
| `Effect.Handler.Protocol` | IO strategy (blocking, reactor, proactor) |
| `Effect.Context.with { } operation: { }` | `IO.run { io in }` |
| `Effect.perform(Read(...))` | `io.read(from: fd, into: buf)` |
| Handler lookup via `Dependency.Key` | Strategy provided by `IO.run` |

**The tension**: Effect types store their arguments as struct fields.
`Read` would store `Kernel.Descriptor` — but `borrowing` can't be stored
in a struct (would consume). Same borrowing+async tension as the witness approach.

**Open question**: Should IO operations use the existing `swift-effects`
system, or is the `@Witness` struct the right level? Both are theoretically
equivalent (evidence-passing = capability-passing = effect handling). The
effects system adds continuation machinery and task-local lookup. The
witness is simpler — just closures.

## Synthesis

### The Three Equivalent Names

The IO witness pattern has three equivalent theoretical formulations:

1. **Evidence vector** (Xie & Leijen) — record of handler implementations
2. **Capability object** (Brachthaeuser) — unforgeable, scoped authority
3. **Defunctionalized effect handler** (Plotkin & Pretnar) — interpretation of abstract operations

These are not three different ideas. They are three names for the same
mathematical structure, proven equivalent in the literature.

### What the Theory Resolves

1. **Reactor/proactor unification IS possible** — Asynchronous Effects
   (Ahman & Pretnar 2021) provides the formal framework where both modes
   coexist under one effect signature.

2. **The witness struct IS the optimal compilation** — evidence-passing
   is the fastest known strategy for effect handlers (150x over dynamic lookup).

3. **`IO.run { io in }` IS `using R run M`** — the Runners calculus
   (Ahman & Bauer 2020) formalizes exactly this pattern with resource
   safety guarantees.

4. **Scoping IS capability confinement** — the non-escaping closure
   body is simultaneously a resource safety, effect safety, and
   security property.

### What the Theory Does NOT Resolve

1. **Buffer ownership at the type level** — reactor borrows, proactor
   consumes. No unified signature exists without multiplicity polymorphism
   (Linear Haskell). The practical answer: the witness closure handles
   ownership transfer internally.

2. **`borrowing` + `async` in Swift** — the tension is a language constraint.
   The theory says sync closures with strategy-managed suspension is correct.
   The effects infrastructure uses `async` + `Sendable` which conflicts
   with `borrowing`.

3. **Effects vs Witness** — theoretically equivalent, but the engineering
   trade-offs differ. Effects provide continuation machinery and composition.
   Witnesses provide simplicity and direct closure calls.

## Converged Recommendation

### Q1 RESOLVED: @Witness for operations, Effect.Context deferred

`@Witness` for the IO operations — zero per-call overhead (direct closure call).
The `Effect.perform` path creates a `Task` + `CheckedContinuation` per call,
disqualifying for hot-path I/O. Effects are right for coarse-grained lifecycle;
IO operations are fine-grained.

`Effect.Context` integration deferred — can be layered on later as a distribution
mechanism (`IO` registered as `Dependency.Key`). Does not change the witness design.

### Q2 RESOLVED (v3.0): Sync closures internal, async methods public

The borrowing+async tension is resolved in two layers:

**Internal** — `IO.Context` is a `@Witness` struct with sync closures per strategy:

```swift
@Witness
struct Context {  // internal to swift-io
    let _read: (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) throws(Error) -> Int
    let _write: (_ to: borrowing Kernel.Descriptor, _ from: Memory.Buffer) throws(Error) -> Int
    let _accept: (_ on: borrowing Kernel.Descriptor) throws(Error) -> Kernel.Descriptor
    let _close: (_ descriptor: consuming Kernel.Descriptor) -> Void
}
```

No escaping, no async boundary, `borrowing` works. The closures are invoked from
inside the `IO` actor's isolated methods, so they run on the actor's executor.

**Public** — `IO` is an actor with isolated methods wrapping the Context closures.
`borrowing` survives across async actor-method boundaries (confirmed — see
HANDOFF-actor-runner-investigation.md Q3 and `Experiments/actor-borrowing-async`):

```swift
public actor IO {
    @inlinable public func read(from fd: borrowing Kernel.Descriptor,
                                into buf: Memory.Buffer.Mutable)
        throws(IO.Error) -> Int { try context._read(fd, buf) }
    // etc.
}
```

Proactor caveat: io_uring sync `_read` = submit + block-wait for specific
completion. Acceptable when the actor's executor is a dedicated completion thread.

Executor hop resolution: actor isolation forces each `await io.read(...)` onto
the `IO`'s executor. No advisory preference, no escape under `Task.sleep` or
`@MainActor` calls. See io-blocking-executor-binding.md v3.0.

### Q3 RESOLVED (v4.0): IO IS the capability; the impl actor IS the runner

Lambda-coop `using R run M` splits cleanly across two types under Shape B:

```swift
// The CAPABILITY — @Witness struct, value-type.
// Brachthaeuser: "unforgeable, communicable token of authority."
// Xie & Leijen: "evidence vector — record of handler function implementations."
@Witness
public struct IO: Sendable {
    let _read: @Sendable (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    let _write: @Sendable (...) async throws(IO.Error) -> Int
    let _accept: @Sendable (...) async throws(IO.Error) -> Kernel.Descriptor
    let _close: @Sendable (...) async -> Void
    let _unownedExecutor: @Sendable () -> UnownedSerialExecutor
}

// The RUNNER — internal actor, reference-type.
// Ahman & Bauer: "manages external resources, provides operations, guarantees
// linear resource use and finalization."
internal actor IO.Blocking.Actor {
    let executor: Kernel.Thread.Executor   // concrete — no existential

    func read(from fd: borrowing Kernel.Descriptor,
              into buf: Memory.Buffer.Mutable) throws(IO.Error) -> Int { ... }
    // etc.
}

// Factories per strategy — one pair each:
extension IO {
    public static func blocking(_ pool: Blocking = .shared) -> IO
    public static func blocking(on executor: Kernel.Thread.Executor) -> IO
    // Events / Completions / platformBest follow the same shape.
}

// Consumer:
let io = IO.blocking()
let n = try await io.read(from: fd, into: buf)
try await io.close(fd)
```

**Separating capability from runner**:

- **Capability** (IO witness) — value-type, Sendable, passed around freely. The
  witness's closures are the consumer's authority to perform I/O. No executor
  state on the capability itself; it forwards to the impl.
- **Runner** (impl actor) — reference-type, owns the concrete executor, enforces
  mandatory thread binding via actor isolation. One impl per strategy
  (`IO.Blocking.Actor`, `EventsImpl`, `CompletionsImpl`).
- **Exactly-once close**: `consuming Kernel.Descriptor` on `_close` and on
  `impl.close` — exactly-once close, linear resource use (Ahman & Bauer 2020).
- **Finalization**: the impl actor's deinit releases its hold on the executor.
  Witness dropping doesn't affect the impl (it's captured by the closures);
  when the witness is the last reference to the impl, the impl deinits.

The v2.0 `IO.run(_:body:)` scope form is retired. A scope wrapper would require
exposing either `@Sendable` on the body or the `Actor.run` pattern — both of
which impose capture restrictions that the user constraint ("single API, no
modes") disallows.

**Shape A (v3.0) alternative — superseded**: v3.0 proposed `public actor IO`
with isolated methods. Issue 1: required `any SerialExecutor` on the public type
for Events/Completions (different concrete executors). Issue 2: `@Witness` macro
is designed for structs, not actors — testing helpers needed manual wrapper
factories. Shape B resolves both.

### Q4 RESOLVED: Two layers, separate purposes

- `Effect.Context.with` → dependency injection of IO strategy (configuration)
- `IO` witness instance → execution capability (value-type, forwards to impl)
- `*Impl` actor → execution runtime (executor binding, per-op dispatch)

These serve different purposes. The `IO` witness does NOT use `Effect.Context`
internally. The consumer can compose both when needed, but `let io = IO.blocking();
try await io.read(...)` is the primary API. Effects integration is additive,
deferred.

### Final Shape (v4.0)

```swift
// Public witness — value-type capability. @Witness generates test helpers.
@Witness
public struct IO: Sendable {
    let _read:  @Sendable (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    let _write: @Sendable (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)         async throws(IO.Error) -> Int
    let _accept:@Sendable (_ on:   borrowing Kernel.Descriptor)                                 async throws(IO.Error) -> Kernel.Descriptor
    let _close: @Sendable (_ descriptor: consuming Kernel.Descriptor) async -> Void
    let _unownedExecutor: @Sendable () -> UnownedSerialExecutor
}

extension IO {
    @inlinable public func read(from fd: borrowing Kernel.Descriptor,
                                into buf: Memory.Buffer.Mutable)
        async throws(IO.Error) -> Int { try await _read(fd, buf) }
    @inlinable public func write(to fd: borrowing Kernel.Descriptor,
                                 from buf: Memory.Buffer)
        async throws(IO.Error) -> Int { try await _write(fd, buf) }
    @inlinable public func accept(on fd: borrowing Kernel.Descriptor)
        async throws(IO.Error) -> Kernel.Descriptor { try await _accept(fd) }
    @inlinable public func close(_ fd: consuming Kernel.Descriptor) async {
        await _close(consume fd)
    }
    @inlinable public var unownedExecutor: UnownedSerialExecutor {
        _unownedExecutor()
    }
}

// Internal per-strategy impl actors — each owns a concrete executor type.
internal actor IO.Blocking.Actor {
    let executor: Kernel.Thread.Executor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    func read(from fd: borrowing Kernel.Descriptor,
              into buf: Memory.Buffer.Mutable) throws(IO.Error) -> Int { ... }
    // write / accept / close ...
}

// Phase 2:
internal actor EventsImpl      { let loop: Kernel.Event.Loop /* ... */ }
internal actor CompletionsImpl { let ring: Kernel.Completion.Ring /* ... */ }

// Factories — identical shape per strategy.
extension IO {
    public static func blocking(_ pool: Blocking = .shared) -> IO { /* wire impl */ }
    public static func blocking(on executor: Kernel.Thread.Executor) -> IO { /* wire impl */ }
    // events(_:) / events(on:) / completions(_:) / completions(on:) / platformBest(_:)
}
```

Public witness (value-type, Sendable, passed around freely); internal impl
actors (each with a concrete executor type); public async methods forwarding
through the witness closures to the impl's isolated methods.

Theoretically grounded:

- **Runners calculus (Ahman & Bauer 2020)** — the impl actor IS the runner:
  manages the external resource (executor), provides operations, guarantees
  linear resource use (`consuming` on close) and finalization (deinit).
- **Effects-as-Capabilities (Brachthaeuser 2020)** — the IO witness IS the
  capability: value-type, unforgeable, communicable. No ref-type weakening.
- **Evidence Passing (Xie & Leijen 2021)** — the `@Witness` struct IS the
  evidence vector: record of handler function implementations.
- **Ahman & Pretnar 2021** — async signalling/interrupting decomposition
  maps to per-op `await`: each method call is its own signal+interrupt unit.

## Phased Implementation

1. **Phase 1** (now): `IO` witness with sync closures + `IO.run` + `IO.blocking()` factory
2. **Phase 2**: `IO.bestAvailable()` composing Kernel.Event.Source + Kernel.Completion
3. **Phase 3**: `IO` as `Dependency.Key` for `Effect.Context` injection
4. **Phase 4**: Evaluate fine-grained effects for individual IO operations (if warranted)

## References

### Academic
- Plotkin & Pretnar, "Handlers of Algebraic Effects" (2009, ESOP)
- Ahman & Bauer, "Runners in Action" (2020, ESOP)
- Ahman & Pretnar, "Asynchronous Effects" (2021, POPL)
- Xie & Leijen, "Generalized Evidence Passing for Effect Handlers" (2021, ICFP)
- Brachthaeuser et al., "Effects as Capabilities" (2020, OOPSLA)
- Schuster et al., "Compiling Effect Handlers in Capability-Passing Style" (2020, ICFP)
- Peyton Jones & Wadler, "Imperative Functional Programming" (1993, POPL)
- Wadler, "Linear Types Can Change the World!" (1990)
- Bernardy et al., "Linear Haskell" (2018, POPL)
- Miller, "Robust Composition" (2006, PhD thesis)
- Filinski, "Representing Monads" (1994, POPL)
- Pirog et al., "Typed Equivalence..." (2019, FSCD)
- Sivaramakrishnan et al., "Retrofitting Effect Handlers onto OCaml" (2021, PLDI)
- Honda et al., "Language Primitives for Structured Communication" (1998, ESOP)
- Schmidt, "Reactor" (1995) / "Proactor" (1997)
- withoutboats, "Notes on io-uring" (2020)

### Ecosystem
- `swift-effect-primitives` — `/Users/coen/Developer/swift-primitives/swift-effect-primitives/`
- `swift-effects` — `/Users/coen/Developer/swift-foundations/swift-effects/`
- `swift-witnesses` — `/Users/coen/Developer/swift-foundations/swift-witnesses/`
- `io-witness-borrowing-async-tension.md` (same dir, post-2026-04-20 migration)
- `../../../swift-institute/Research/io-prior-art-per-system-reference.md` (relocated 2026-04-20)
- `../../../swift-institute/Research/io-prior-art-and-swift-io-design-audit.md`
- `../../../swift-foundations/Research/io-driver-witness-composition.md`
- `../../../swift-foundations/Research/io-witness-experiment-results.md`
