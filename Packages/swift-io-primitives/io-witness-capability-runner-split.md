# IO Witness: Capability–Runner Split

<!--
---
version: 1.0.0
created: 2026-04-17
last_updated: 2026-04-17
status: RECOMMENDATION
tier: 2
related:
  - io-witness-design-literature-study.md (v4.0 — established Shape B; moved here 2026-04-20)
  - ../../../swift-foundations/swift-executors/Research/io-blocking-executor-binding.md (v4.0 — Shape B rationale; relocated 2026-04-20)
  - ../../../swift-foundations/swift-io/Research/io-context-actor-analysis.md (v3.0 — SUPERSEDED; actor-IO rejected in favor of Shape B)
  - io-witness-borrowing-async-tension.md (open language tension; moved here 2026-04-20)
  - ../../../swift-foundations/swift-io/Research/perfect-api.md (v3.0 — Tier 0 API recommendation; SEE INTENT BANNER)
  - ../../../swift-foundations/Research/io-driver-witness-composition.md (separate driver-level witness)
  - ../../../swift-foundations/Research/nio-inspired-capability-additions.md (P0 shutdown as consumer of any runner API)
  - ../../../swift-foundations/swift-witnesses/Sources/Witnesses/ (Witness.Values, Witness.Recording, Witness.Scope, Witness.Cycle, Witness.Sequence)
---
-->

> **Cross-package note (2026-04-20)**: this document was moved from
> `swift-foundations/swift-io/Research/` to
> `swift-primitives/swift-io-primitives/Research/`. Body markdown links
> below were originally written as `../swift-io/Research/<file>` from
> the old location (a path style that was already inconsistent); they
> are now updated where load-bearing. References to `swift-io/Research/`
> documents that *also moved here* are now bare filenames; references to
> swift-io documents that stayed are now full cross-package paths;
> references to `io-blocking-executor-binding.md` resolve at
> `../../../swift-foundations/swift-executors/Research/`.

## Context

Shape B, as established by [io-witness-design-literature-study.md](../swift-io/Research/io-witness-design-literature-study.md) v4.0 and [io-blocking-executor-binding.md](../swift-io/Research/io-blocking-executor-binding.md) v4.0, defines `IO` as a `@Witness public struct` of async closures with each strategy's runner as an **internal actor** that the witness captures by reference through closure capture. The literature study explicitly states (`io-witness-design-literature-study.md:394–396`):

> "Capability (IO witness) — value-type, Sendable, passed around freely. The witness's closures are the consumer's authority to perform I/O. **No executor state on the capability itself**; it forwards to the impl."

The current `IO` type contradicts that aspiration by carrying `_unownedExecutor` as a fifth closure alongside the four operation closures (`IO.swift:186–188`):

```swift
@Witness public struct IO: Sendable {
    let _read, _write, _close, _ready: ...      // capability surface
    let _unownedExecutor: @Sendable () -> UnownedSerialExecutor   // runner-ish surface
}
```

`_unownedExecutor` is not an I/O operation. It is an accessor over the runner (the internal impl actor's executor). It lives on the capability witness for pragmatic reasons — the shared-executor pattern (TCA26 precedent, documented at `io-blocking-executor-binding.md:85–98`) requires consumer actors to forward `io.unownedExecutor` as their own `nonisolated var unownedExecutor`. Bundling the accessor on `IO` means one value is enough at the consumer side.

A second downstream concern has emerged since Shape B: the follow-up research [nio-inspired-capability-additions.md](../Research/nio-inspired-capability-additions.md) flagged **P0 — shared-singleton `shutdown()`** as an outstanding correctness gap. A `shutdown()` operation is plainly a runner concern (lifecycle), not a capability concern. Adding `_shutdown` to `IO` would further dilute the capability axiom. The alternative (`IO.Event.Actor.shared().shutdown()`) varies per strategy and has no uniform caller-side API.

**Trigger**: the user's hard constraints:
1. Zero existentials (per `/implementation` — [IMPL-*]).
2. Zero protocols at public API surface — witnesses only.
3. Separate capability from runner at the **type** level, not just the value level.
4. Witnesses should compose or map, leveraging existing `swift-witnesses` infrastructure (`Witness.Values`, `Witness.Recording`, `Witness.Scope`, `Witness.Cycle`, `Witness.Sequence`).

**Stakeholders**: swift-io maintainers, swift-sockets (direct consumer of `IO`), swift-file-system (direct consumer of `IO.Blocking.shared`), swift-witnesses (composition infrastructure).

## Question

How should swift-io separate the I/O capability surface (`read`, `write`, `close`, `ready`) from the runner surface (`unownedExecutor`, `shutdown`, potential future lifecycle/observation operations) — given the hard constraints that no protocols and no existentials are permitted, and that both sides must be witnesses so they compose under existing `swift-witnesses` operators?

## Methodology

Per [RES-004]. Three options enumerated, evaluated against six criteria. Options are contextualized (per [RES-021]) — concretized in swift-io's type system before judgment. Interactions with ongoing research ([io-driver-witness-composition.md](../Research/io-driver-witness-composition.md), [perfect-api.md](../swift-io/Research/perfect-api.md)) are considered.

### Evaluation criteria

| # | Criterion | Weight | Notes |
|---|-----------|--------|-------|
| C1 | Preserves Shape B axioms | High | Value-type, `Sendable`, typed throws, `~Copyable`-friendly, actor-isolation-backed |
| C2 | Capability axiom purity | High | Only I/O operations on the capability witness; no lifecycle/executor surface |
| C3 | Consumer API ergonomics | High | Shared-executor pattern (TCA26) must remain single-line. No viral generics |
| C4 | Compositionality with swift-witnesses | High | `Witness.Recording`, `Witness.Scope`, `Witness.Values` apply uniformly |
| C5 | Testability of both halves | Medium | `*.unimplemented()` generated for both witnesses |
| C6 | Migration cost | Medium | Number of call-site churns in swift-io, swift-sockets, swift-file-system |

## Options

Each option is presented in full Swift to make the capability/runner boundary concrete. All options honor the no-protocol / no-existential constraint.

### Option B — status quo (Shape B, with executor on capability)

```swift
@Witness public struct IO: Sendable {
    let _read:  @Sendable (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    let _write: @Sendable (borrowing Kernel.Descriptor, Memory.Buffer)          async throws(IO.Error) -> Int
    let _close: @Sendable (consuming Kernel.Descriptor) async -> Void
    let _ready: @Sendable (borrowing Kernel.Descriptor, Kernel.Event.Interest)  async throws(IO.Error) -> Void
    let _unownedExecutor: @Sendable () -> UnownedSerialExecutor
}
```

Runner concerns: handled per-strategy on the impl actor type (`IO.Blocking.Actor`, `IO.Event.Actor`, `IO.Completion.Actor`). Shutdown is `IO.Event.Actor.shared().shutdown()` etc. — non-uniform across strategies.

### Option F — runner-as-witness, bundled by a plain struct

Two `@Witness` structs, combined in a non-witness plain bundle:

```swift
// Capability — pure operations.
@Witness public struct IO: Sendable {
    let _read:  @Sendable (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    let _write: @Sendable (borrowing Kernel.Descriptor, Memory.Buffer)          async throws(IO.Error) -> Int
    let _close: @Sendable (consuming Kernel.Descriptor) async -> Void
    let _ready: @Sendable (borrowing Kernel.Descriptor, Kernel.Event.Interest)  async throws(IO.Error) -> Void
}

// Runner — lifecycle and scheduling evidence.
@Witness public struct IO.Runner: Sendable {
    let _executor: @Sendable () -> UnownedSerialExecutor
    let _shutdown: @Sendable () async -> Void
}

// Plain struct — value bundle, not a witness. No protocol, no existential.
public struct IO.Bound: Sendable {
    public let io: IO
    public let runner: IO.Runner
}

extension IO.Bound {
    public static func blocking(on executor: Kernel.Thread.Executor = .shared) -> IO.Bound
    public static func events(on actor: IO.Event.Actor = try .shared()) throws(IO.Event.Failure) -> IO.Bound
    public static func completions(on actor: IO.Completion.Actor = try .shared()) throws(Kernel.Completion.Error) -> IO.Bound
    public static func `default`() -> IO.Bound
}
```

Consumer:

```swift
actor Server {
    let bound: IO.Bound
    init() throws { self.bound = try IO.Bound.events() }
    nonisolated var unownedExecutor: UnownedSerialExecutor { bound.runner.executor() }
    func handle(fd: consuming Kernel.Descriptor) async throws(IO.Error) -> Int {
        try await bound.io.read(from: fd, into: buf)
    }
    deinit { Task { await bound.runner.shutdown() } }
}
```

### Option G — capability unbundled; executor is the runner

Remove `_unownedExecutor` from `IO` without introducing a runner witness. The concrete executor (already a witness-like concrete value) stands in as runner.

```swift
@Witness public struct IO: Sendable {
    let _read, _write, _close, _ready: ...       // same four operations
    // _unownedExecutor: removed.
}

extension IO {
    public static func blocking(on executor: Kernel.Thread.Executor = .shared)
        -> (IO, Kernel.Thread.Executor)
    public static func events(on actor: IO.Event.Actor = try .shared())
        throws(IO.Event.Failure) -> (IO, IO.Event.Actor)
    public static func completions(on actor: IO.Completion.Actor = try .shared())
        throws(Kernel.Completion.Error) -> (IO, IO.Completion.Actor)
}
```

Consumer:

```swift
actor Server {
    let io: IO
    let reactor: IO.Event.Actor
    init() throws {
        (self.io, self.reactor) = try IO.events()
    }
    nonisolated var unownedExecutor: UnownedSerialExecutor { reactor.unownedExecutor }
    func handle(fd: consuming Kernel.Descriptor) async throws(IO.Error) -> Int {
        try await io.read(from: fd, into: buf)
    }
    deinit { /* reactor's deinit or shared() caching */ }
}
```

## Analysis

### Option B — status quo

- **C1**: Fully satisfied — this *is* Shape B.
- **C2**: Violated. `_unownedExecutor` is runner concern on the capability witness. `io-witness-design-literature-study.md:394–396` acknowledges this aspirationally but the current code disagrees.
- **C3**: Best — one value (`IO`) carries everything, shared-executor pattern is one `nonisolated var`.
- **C4**: Partial. `Witness.Recording<(Kernel.Descriptor, Memory.Buffer.Mutable)>` attaches only to operations. Wrapping the executor accessor for observation is awkward (it isn't really an op).
- **C5**: `IO.unimplemented()` generated; `_unownedExecutor` traps if called (no-op otherwise).
- **C6**: Zero.

### Option F — runner-as-witness, plain-struct bundle

- **C1**: Fully satisfied. Both halves are `@Witness` structs; both remain `Sendable`; both honor typed throws, `~Copyable` parameters, actor-isolation backing. `IO.Bound` is a plain `Sendable` struct with no new isolation semantics.
- **C2**: Fully satisfied. Capability witness exposes only I/O. Runner witness exposes only lifecycle + scheduling evidence. The two concerns never mix at the type level.
- **C3**: Consumer writes `bound.io` and `bound.runner.executor()` — two dots instead of one. Measurable ergonomic cost, but the shared-executor pattern stays single-line on the consumer's `unownedExecutor` accessor.
- **C4**: Strongest of the three. Both witnesses compose with `Witness.Recording`, `Witness.Scope`, `Witness.Sequence`, `Witness.Values` uniformly. Instrumented-IO-with-instrumented-Runner is two independent wrappers, not one megawrapper.
- **C5**: `IO.unimplemented()` and `IO.Runner.unimplemented()` both generated by `@Witness`. Each can be faked independently.
- **C6**: Nontrivial. Every factory returns `IO.Bound`. Every `IO` parameter in swift-sockets / swift-file-system becomes either `IO.Bound` (if the consumer needs the runner) or stays `IO` (if the consumer only needs operations). swift-file-system today uses `IO.Blocking.shared.run { … }`; that pattern re-shapes slightly.

### Option G — executor is the runner, unbundled

- **C1**: Satisfied. `IO` remains `@Witness struct`.
- **C2**: Satisfied. Capability witness is pure operations.
- **C3**: Two values in consumer hands by construction. No single-value alternative. The shared-executor pattern requires the consumer to store both and forward the executor from the actor/executor value, not from `IO`. Slightly worse than F, noticeably worse than B.
- **C4**: Partial. `IO` composes with `Witness.*` operators. The executor/actor is not a witness — no uniform wrapping for observation or recording of lifecycle events. Shutdown is per-concrete-type (already a concern flagged in nio-inspired doc).
- **C5**: `IO.unimplemented()` generated. Runner/executor fakes are hand-rolled per concrete type.
- **C6**: Medium. Factory return-tuple shape is invasive to call sites; pair destructuring is a readability regression.

### Comparison

| Criterion | B (status quo) | F (runner witness) | G (unbundled) |
|-----------|:-:|:-:|:-:|
| C1 Shape B axioms | 10/10 | 10/10 | 9/10 |
| C2 Capability purity | 5/10 | 10/10 | 10/10 |
| C3 Ergonomics | 10/10 | 7/10 | 6/10 |
| C4 swift-witnesses composition | 6/10 | 10/10 | 7/10 |
| C5 Testability symmetry | 7/10 | 10/10 | 6/10 |
| C6 Migration cost | 10/10 | 5/10 | 7/10 |
| **Weighted sum (C1–C4 ×2, C5–C6 ×1)** | **68** | **81** | **71** |

## Interactions with ongoing research

### With [io-driver-witness-composition.md](../Research/io-driver-witness-composition.md)

`IO.Driver` is a separate witness at a lower layer, unifying `Kernel.Event.Source` + `Kernel.Completion` into one poll-surface. It is orthogonal to this investigation: `IO.Driver` is consumed *inside* the impl actors (`IO.Event.Actor`, `IO.Completion.Actor`); it never appears on the capability witness.

However, once `IO.Driver` lands, the impl actors could become thinner — they hold `IO.Driver` instead of a raw `Kernel.Event.Source`. This **strengthens** Option F's argument: with `IO.Driver` bearing the cross-platform composition, the runner witness on top of it is uniformly shaped across strategies, which is exactly what a `shared-singleton` `IO.Runner.shutdown()` needs.

### With [perfect-api.md](../swift-io/Research/perfect-api.md) v3.0

The Tier 0 consumer API (`IO.run(socket) { reader, writer in … }`) is independent of the capability/runner split. `IO.run` is a public static member; its implementation can construct an `IO.Bound` internally without changing the Tier 0 surface. Option F is fully compatible.

The v3.0 note about `IO.Context` was **superseded** by Shape B (per `io-context-actor-analysis.md:7` → "SUPERSEDED_BY io-blocking-executor-binding.md v4.0"). The current `IO` witness IS what perfect-api refers to as `IO.Context`. Option F does not revive `Context`; it splits `IO` into `IO` + `IO.Runner`, bundled as `IO.Bound`.

### With [io-witness-borrowing-async-tension.md](../swift-io/Research/io-witness-borrowing-async-tension.md)

The `borrowing Kernel.Descriptor` + `async` tension is a **closure-shape** problem. All three options above keep the operation closures in the same shape as Shape B (`@Sendable (borrowing Kernel.Descriptor, …) async throws(IO.Error) -> …`). Splitting capability from runner does not change the tension one way or the other. The open tension (`sending` mechanism) remains an orthogonal language-level concern.

### With [nio-inspired-capability-additions.md](../Research/nio-inspired-capability-additions.md)

That document's P0 (shared-singleton `shutdown()`) maps onto `IO.Runner._shutdown` directly under Option F. It becomes:

```swift
extension IO.Bound {
    public static func events() throws(IO.Event.Failure) -> IO.Bound {
        let actor = try IO.Event.Actor.shared()
        return IO.Bound(
            io: IO.events(on: actor),   // existing factory
            runner: IO.Runner(
                executor: { actor.unownedExecutor },
                shutdown: { await actor.shutdown() }   // added
            )
        )
    }
}
```

The P0 fix becomes a method call on a uniform API surface rather than three disparate per-strategy entry points. Option F thus **subsumes P0**: implementing F solves the shutdown-uniformity problem structurally.

Similarly, P1 (thread naming — swift-executors concern) and P1 (test fakes — swift-io test support) gain a uniform home under `IO.Runner`:

```swift
@Witness public struct IO.Runner: Sendable {
    let _executor: @Sendable () -> UnownedSerialExecutor
    let _shutdown: @Sendable () async -> Void
    // Later (P1–P2):
    // let _name: @Sendable () -> String
    // let _statistics: @Sendable () -> IO.Runner.Statistics  // optional
}
```

## Compositionality — concrete patterns under Option F

### Observation / recording

```swift
let recording = Witness.Recording<(fd: Int32, count: Int)>()
let instrumentedIO = bound.io.observe(
    before: { _ in },
    after: { outcome in
        if let (fd, n) = outcome.readResult { recording.record((fd, n)) }
    }
)
```

The runner witness composes independently:

```swift
let runnerRecording = Witness.Recording<IO.Runner.LifecycleEvent>()
let instrumentedRunner = bound.runner.observe(
    before: { _ in },
    after: { lifecycleEvent in runnerRecording.record(lifecycleEvent) }
)

let instrumented = IO.Bound(io: instrumentedIO, runner: instrumentedRunner)
```

### Scope-bounded teardown

`Witness.Scope` binds a witness to a structured lifetime. With a runner witness, `shutdown` is the natural `exit` action:

```swift
try await Witness.Scope(runner: bound.runner).use { scopedRunner in
    // scopedRunner.shutdown() called automatically on scope exit
    try await bound.io.read(from: fd, into: buf)
}
```

Under Option B, this pattern has to be spelled per-strategy. Under Option G, the executor is not a witness — `Witness.Scope` does not apply.

### Values container

```swift
var values = Witness.Values()
values[IO.self] = .unimplemented()
values[IO.Runner.self] = .unimplemented()
// … later, under test …
values[IO.self] = testIO
values[IO.Runner.self] = testRunner
```

Uniform storage and lookup via `Witness.Values` — a capability made free by Option F, inaccessible under Option G.

### Error mapping (orthogonal, but enabled by split)

With capability isolated from runner concerns, `IO` could become generic over a `LeafError` — `IO<LeafError: Error>`. A downstream package (e.g., `Sockets`) would get `IO<Sockets.Error>` by `mapError`. Runner concerns are unaffected (no error type on the runner witness's public surface). This orthogonal improvement is **cleanly enabled** by the split — worth a separate investigation, not blocked on this one.

## Hard constraints check

| Constraint | B | F | G |
|------------|:-:|:-:|:-:|
| No protocols at public surface | ✓ | ✓ | ✓ |
| No existentials | ✓ | ✓ | ✓ |
| Witnesses compose/map under swift-witnesses operators | partial | **full** | partial |
| Actor isolation preserved as runtime backing | ✓ | ✓ | ✓ |
| `~Copyable` ownership-correct | ✓ | ✓ | ✓ |
| Typed throws end-to-end | ✓ | ✓ | ✓ |

## Outcome

**Status**: RECOMMENDATION

### Recommended option: **F — runner as witness, bundled by a plain struct**

Weighted score 81 vs 71 (G) and 68 (B). Decisive criteria:

1. **C2 (capability purity)** — F achieves the aspiration that Shape B stated but did not enforce.
2. **C4 (swift-witnesses composition)** — F extends the full composition/recording/scope/values machinery to the runner concept. Neither B nor G can.
3. **Subsumes open P0 from nio-inspired doc** — F gives `IO.Runner._shutdown` a uniform home across strategies. This is otherwise an ad-hoc patch on three disparate actor types.
4. **Runway for future runner operations** (naming, statistics, lifecycle events, pause/resume) without ever touching the capability witness.

### Cost accepted

- Migration: every factory returns `IO.Bound`. swift-sockets and swift-file-system call sites need `.io` / `.runner` accessors. Estimate < 50 line diffs across swift-foundations.
- Ergonomics: two-dot access at consumer sites (`bound.io.read`, `bound.runner.executor()`). Mitigated by documentation and a small number of ergonomic re-exports (below).

### Open decisions (required before implementation)

1. **Runner surface in v1**: just `_executor` + `_shutdown`, or also include `_name` (thread naming, P1)? Recommendation: ship v1 with `_executor` + `_shutdown` only. Add `_name` when swift-executors surfaces the capability.
2. **Should `IO.Bound` conditionally re-export the capability methods?** I.e., should `bound.read(...)` work as sugar for `bound.io.read(...)`? This is ergonomic only. Recommendation: **no** in v1 — keep the two-dot access explicit so readers can see which concern each call exercises. Revisit if surveys show ergonomics suffer.
3. **Naming**: `IO.Bound`, `IO.Instance`, `IO.Stack`, `IO.Pair`? Recommendation: `IO.Bound` — reads as "capability bound to runner". Alternative: just `IO` becomes the bundle, and the split-out capability gets a different name (`IO.Ops`?). Strong consensus needed before v1 ships.
4. **Shared-singleton lifecycle**: process-scoped singletons cache `Result<Actor, Error>`. Under F, should `IO.Bound.shared()` itself be cached, or should the singletons live at the actor level and `IO.Bound` construct on demand? Recommendation: actor-level cache (current state); `IO.Bound` is cheap to construct from a cached actor.

### Recommended next step

Spin up an experiment at `swift-io/Experiments/capability-runner-split/` that prototypes Option F:

- Two targets: `IO Core Split` (just the two witnesses + `IO.Bound`) and `IO Core Split Tests`.
- Port `IO.Blocking.shared` factory to the split shape.
- Demonstrate the shared-executor pattern from `io-blocking-executor-binding.md:373–386` under the new shape.
- Measure: (a) per-op overhead relative to Shape B (expected zero — same closure calls through one extra struct field), (b) witness generation verification (`IO.unimplemented()` + `IO.Runner.unimplemented()`).

Success criteria: ergonomics equivalent to Shape B within one struct access; per-op microbench within noise of Shape B; both witnesses compose with `Witness.Recording`.

On success, promote Option F to a Phase 3 migration plan analogous to [io-phase-2-plan.md](../swift-io/Research/io-phase-2-plan.md).

## Non-goals (preserved from Shape B)

- No existentials (`any Runner`, `any IOCapability`) — direct violation of [IMPL-*].
- No protocols at the public surface — direct violation of user constraint.
- No generics over `Runner` type on `IO` (would make consumer APIs viral).
- No revival of `IO.Context` as a separate public type — folded into `IO` per Shape B and retained.
- No executor storage on the capability witness (Option B's current state is explicitly moved away from).

## References

### Prior research (swift-io)

- [io-witness-design-literature-study.md](../swift-io/Research/io-witness-design-literature-study.md) v4.0 — establishes Shape B, capability/runner theoretical split
- [io-blocking-executor-binding.md](../swift-io/Research/io-blocking-executor-binding.md) v4.0 — Shape B rationale, TCA26 shared-executor pattern
- [io-context-actor-analysis.md](../swift-io/Research/io-context-actor-analysis.md) v3.0 — SUPERSEDED; why `IO` is not an actor
- [io-witness-borrowing-async-tension.md](../swift-io/Research/io-witness-borrowing-async-tension.md) — orthogonal language constraint
- [perfect-api.md](../swift-io/Research/perfect-api.md) v3.0 — Tier 0 consumer API, `IO.run` entry point
- [io-witness-experiment-results.md](../swift-io/Research/io-witness-experiment-results.md) — empirical results

### Prior research (cross-package, swift-foundations)

- [io-driver-witness-composition.md](../Research/io-driver-witness-composition.md) — driver-layer unified witness (lower than this concern)
- [io-vs-nio-comparative-analysis.md](../Research/io-vs-nio-comparative-analysis.md) — predecessor analysis
- [nio-inspired-capability-additions.md](../Research/nio-inspired-capability-additions.md) — P0 shutdown subsumed by Option F

### Ecosystem infrastructure

- `swift-witnesses/Sources/Witnesses/Witness.Values.swift` — typed witness storage
- `swift-witnesses/Sources/Witnesses/Witness.Recording.swift` — call recording wrapper
- `swift-witnesses/Sources/Witnesses/Witness.Scope.swift` — scope-bounded lifetime
- `swift-witnesses/Sources/Witnesses/Witness.Sequence.swift` — sequential composition
- `swift-witnesses/Sources/Witnesses/Witness.Cycle.swift` — cyclic composition

### Academic

- Brachthäuser, Schuster, Ostermann, "Effects as Capabilities", OOPSLA 2020 — value-type capability
- Ahman & Bauer, "Runners in Action", ESOP 2020 — runner model
- Schuster et al., "Compiling Effect Handlers in Capability-Passing Style", ICFP 2020 — 150× speedup of evidence vectors
- Xie & Leijen, "Generalized Evidence Passing for Effect Handlers", ICFP 2021 — witness struct = evidence vector

### Process

- [RES-004] Investigation Methodology
- [RES-020] Research Tiers (Tier 2)
- [RES-021] Prior Art Survey with contextualization step
- [RES-013a] Synthesis verification — every carried-forward claim verified against current source
