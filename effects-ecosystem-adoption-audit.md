# Effects Ecosystem Adoption Audit

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: RECOMMENDATION
tier: 1
---
-->

## Context

The Swift Institute ecosystem has two packages for algebraic effects:

- **swift-effect-primitives** (Layer 1): Defines `Effect`, `Effect.Protocol`, `Effect.Handler`, `Effect.Continuation.One`/`.Multi`, `Effect.Context`, `Effect.Outcome`
- **swift-effects** (Layer 3): Provides `EffectWithHandler`, `Effect.perform(_:)`, built-in effects (`Effect.Exit`, `Effect.Yield`), and testing utilities (`Effect.Test.Spy`, `Effect.Test.Handler`, `Effect.Test.Recorder`)

Several packages already use `Effect.Protocol` (cache-primitives, pool-primitives, parser-primitives), but the ecosystem has not been systematically audited for adoption opportunities. Breaking changes are allowed. Dependencies can be freely added.

## Question

Where across the Swift Institute ecosystem are there opportunities to use the effects system instead of ad-hoc solutions?

## Current API Surface

### Effect Primitives (Layer 1)

| Type | Purpose |
|------|---------|
| `Effect` | Namespace enum |
| `Effect.Protocol` (`__EffectProtocol`) | Marker protocol: `Arguments`, `Value`, `Failure` |
| `Effect.Handler.Protocol` (`__EffectHandler`) | Handler protocol: `handle(_:continuation:)` |
| `Effect.Continuation.One<V,F>` | ~Copyable one-shot continuation (compile-time linear usage) |
| `Effect.Continuation.Multi<V,F>` | Copyable multi-shot continuation (backtracking, generators) |
| `Effect.Outcome<V,F>` | `.resumed(V)` / `.threw(F)` / `.aborted` |
| `Effect.Context` | Task-local scoped handler registration (wraps `Dependency.Scope`) |

### Effects (Layer 3)

| Type | Purpose |
|------|---------|
| `EffectWithHandler` | Links effect to `Dependency.Key` for automatic handler lookup |
| `Effect.perform(_:)` | Suspends, looks up handler from `Effect.Context.current`, resumes |
| `Effect.Exit` | Built-in: terminate process (testable) |
| `Effect.Yield` | Built-in: yield to scheduler (testable) |
| `Effect.Test.Handler<E>` | Configurable test handler returning predetermined results |
| `Effect.Test.Spy<E>` | Records invocations while delegating to inner handler |
| `Effect.Test.Recorder` | Type-erased recorder for multiple effect types |

### Already Using Effects

| Package | Types | Status |
|---------|-------|--------|
| swift-cache-primitives | `Cache.Compute<K,V,E>`, `Cache.Evict<K,V>` | Defines Effect.Protocol types |
| swift-pool-primitives | `Pool.Acquire<R>`, `Pool.Release<R>` | Defines Effect.Protocol types |
| swift-parser-primitives | `Parser.Backtrack<I,O,E>` | Defines Effect.Protocol for multi-shot backtracking |
| swift-effects | `Effect.Exit`, `Effect.Yield` | Full EffectWithHandler + perform |
| swift-testing | `Test.spy(for:returning:)` etc. | Integration layer for test effects |

## Findings

### Category 1: Ad-Hoc Effect Enum in Pool.Bounded (Already Aligned, Needs Bridging)

Pool.Bounded defines its own `Effect` enum internally for "compute under lock, execute outside lock":

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-pool-primitives | `Sources/Pool Bounded Primitives/Pool.Bounded.Effect.swift:32` | Internal `enum Effect { case none, gate(Gate), waiter(Waiter) }` with manual `perform(_:)` dispatch | This is a **synchronous state-machine effect** pattern distinct from the algebraic effect system. The `perform(_:)` method is a single-site funnel for lock-free execution of side-effects. **No change recommended** -- this is a different abstraction than `Effect.Protocol` which is async/continuation-based. The naming collision is unfortunate but the patterns are fundamentally different. | LOW |

**Rationale**: Pool.Bounded.Effect is a synchronous "deferred side-effect" pattern executed outside a mutex. It has no suspension, no continuation capture, no handler dispatch. Forcing it into the algebraic effect model would add async overhead to a performance-critical path and obscure the lock-safety invariant.

### Category 2: Environment Read/Write as Effects

Environment operations are side-effectful (process state mutation) and would benefit from effect modeling for testability:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-environment | `Sources/Environment/Environment.Read.swift:37` | Direct `Kernel.Environment.get()` call behind mutex | Define `Environment.Read.Effect: Effect.Protocol` with `Value = String?`, `Failure = Never`. Live handler calls kernel, test handler returns from dictionary | MEDIUM |
| swift-environment | `Sources/Environment/Environment.Write.swift` | Direct `Kernel.Environment.set()` call behind mutex | Define `Environment.Write.Effect: Effect.Protocol` with `Arguments = (name, value)`, `Value = Void`, typed `Failure`. Live handler calls kernel, test handler records | MEDIUM |
| swift-environment | `Sources/Environment/Environment.Task.swift:55` | TaskLocal overlay for read isolation | Already uses TaskLocal -- effects would be an alternative mechanism. The current TaskLocal approach is more efficient for this use case. | LOW |

**Rationale**: Environment read/write are classic side-effects. Currently, testing requires TaskLocal overlays or actual process mutation. Effect handlers would allow pure test isolation without TaskLocal machinery. However, Environment already has a reasonable testing story via `withOverlay`. Priority is MEDIUM because effects would improve composability but the current approach works.

### Category 3: Console I/O as Effects

Console input and output are textbook side-effects:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-console | `Sources/Console/Console.Input.swift:44` | `withEvents(stream:configuration:body:)` -- closure receives `next()` function | Define `Console.Input.Read: Effect.Protocol` with `Value = Terminal.Input.Event?`. Handler wraps the terminal reader. Tests can inject predetermined key sequences. | HIGH |
| swift-console | `Sources/Console/Console.Capability+Detect.swift` | Reads env vars (NO_COLOR, TERM, COLORTERM) directly | Define `Console.Capability.Detect: Effect.Protocol` returning capability set. Live handler probes terminal. Test handler returns predetermined capabilities. | MEDIUM |

**Rationale**: Console I/O is the canonical algebraic effect example. The current `withEvents` closure pattern is already effect-shaped but bespoke. Modeling as formal effects enables test spying (verify which events were processed), handler composition (log all input events), and deterministic testing without terminal access.

### Category 4: Clock/Sleep/Yield as Effects

The existing `Clock.Test` manually manages continuations for deterministic time. Effects provide a cleaner abstraction:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-effects (built-in) | `Sources/Effects Built-in/Effect.Yield.swift` | Already `Effect.Yield: EffectWithHandler` | **Already done** -- canonical example | N/A |
| swift-clock-primitives | `Sources/Clock Primitives/Clock.Test.swift:41` | Manual `CheckedContinuation` management in `sleep()`, manual `advance()/run()` | Define `Clock.Sleep: Effect.Protocol` with `Arguments = (deadline, tolerance)`, `Value = Void`, `Failure = CancellationError`. Test handler stores sleep request for manual advancement. | LOW |

**Rationale**: `Clock.Test` already works well and is deeply integrated with Swift's `_Concurrency.Clock` protocol. Replacing it with effects would require reimplementing the Clock protocol bridge. The existing Effect.Yield built-in is sufficient for yield control. Priority is LOW -- the benefit is marginal since Clock.Test already provides deterministic control.

### Category 5: File System Operations as Effects

File system operations are side-effectful and notoriously hard to test:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-file-system | `Sources/File System Primitives/File.System.Read.Full.swift:115` | Direct `Kernel.File.Open.open()` + `Kernel.IO.Read.pread()` | Define `File.System.Read.Full.Effect: Effect.Protocol` with `Value = [UInt8]`. Live handler does kernel I/O. Test handler returns from in-memory store. | HIGH |
| swift-file-system | `Sources/File System Primitives/File.System.Write.swift` | Direct kernel writes | Define `File.System.Write.Effect: Effect.Protocol`. Live handler writes to disk. Test handler captures to buffer. | HIGH |
| swift-file-system | `Sources/File System Primitives/File.System.Delete.swift` | Direct kernel unlink | Define `File.System.Delete.Effect: Effect.Protocol`. Test handler records deletions. | MEDIUM |
| swift-file-system | `Sources/File System Primitives/File.System.Stat.swift` | Direct kernel stat | Define `File.System.Stat.Effect: Effect.Protocol`. Test handler returns fake metadata. | MEDIUM |
| swift-file-system | `Sources/File System Primitives/File.Directory.Walk.swift` | Iterator over FTS | Define `File.Directory.Walk.Effect: Effect.Protocol`. Test handler yields fake directory entries. | LOW |
| swift-file-system | `Sources/File System Primitives/File.Directory.Walk.Undecodable.swift` | Callback `(Context) -> Policy` | Define `File.Directory.Walk.Undecodable.Decision: Effect.Protocol` with `Value = Policy`. Handler receives context, returns policy. Enables spy/recording of undecodable entries. | LOW |

**Rationale**: File system effects are HIGH priority because they enable the most impactful testing improvement. Currently, testing file operations requires creating actual temp directories and real files. Effect handlers would allow pure in-memory file system tests. The `File.System.Read.Full` and `File.System.Write` operations are the highest-value targets because they are the most commonly used and most frequently need testing.

### Category 6: Kernel Syscall Layer as Effects

The lowest-level kernel operations could all be modeled as effects, but this has design implications:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-kernel | `Sources/Kernel/Kernel.File.Open.swift` | Delegates to platform-specific `ISO_9945.Kernel.File.Open` | Define `Kernel.File.Open.Effect: Effect.Protocol`. This is the syscall boundary -- effects here would virtualize ALL file operations above. | LOW |
| swift-kernel | `Sources/Kernel/Kernel.File.Copy.swift` | Direct platform syscalls | Could be an effect but adds async overhead to sync path | LOW |
| swift-kernel | `Sources/Kernel/Kernel.Thread.spawn.swift` | Platform thread creation | Thread spawning as effect enables test verification of thread creation patterns | LOW |
| swift-kernel | `Sources/Kernel/Kernel.Thread.trap.swift:51` | `fatalError(error.description)` | Should use `Effect.Exit` instead of direct `fatalError`. This is exactly what Effect.Exit was designed for. | HIGH |

**Rationale**: Virtualizing the entire kernel syscall layer via effects would be architecturally powerful but introduces async overhead at the synchronous syscall boundary. The one HIGH-priority item is `Kernel.Thread.trap` which uses `fatalError` directly -- this should use `Effect.Exit` to enable testing of failure paths.

### Category 7: Rendering Sinks as Effects

The async rendering pipeline writes bytes through sink protocols:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-rendering-primitives | `Sources/Rendering Async Primitives/Rendering.Async.Sink.Protocol.swift:8` | Protocol `func write(_ bytes:) async` | Define `Rendering.Async.Write: Effect.Protocol` with `Arguments = [UInt8]`, `Value = Void`. Handler dispatches to actual sink. | LOW |
| swift-rendering-primitives | `Sources/Rendering Async Primitives/Rendering.Async.Sink.Buffered.swift:32` | Actor-based buffered sink with channel backpressure | Could delegate to write effect instead of directly using channel | LOW |

**Rationale**: The rendering sink protocol already provides the right abstraction for writing bytes. Adding effects on top would add indirection without clear benefit since the sink protocol itself is already injectable and testable via protocol conformance. Priority is LOW.

### Category 8: Test Framework Event Reporting

The test framework uses a closure-based reporter factory:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-tests | `Sources/Tests Core/Test.Reporter.swift:41` | `struct Reporter` with closure `_makeSink: @Sendable () -> Sink` | Define `Test.Reporter.Create: Effect.Protocol` with `Value = Sink`. Enables spy/recording of reporter creation. | LOW |
| swift-tests | `Sources/Tests Core/Test.Reporter.Sink.swift` | Protocol for receiving test events | Events already flow through a protocol. Effects would add overhead. | LOW |
| swift-tests | `Sources/Tests Snapshot/Test.Snapshot.Strategy.swift:61` | Closure-based `snapshot: @Sendable (Value) -> Async.Callback<Format>` | Could model snapshot capture as effect for deterministic testing. But snapshot testing already has its own recording mechanism. | LOW |

**Rationale**: The test framework already has well-designed abstractions for reporting and snapshot capture. Adding effects would be circular (testing infrastructure using the very effects it is designed to test). Priority is LOW.

### Category 9: Direct `fatalError`/`preconditionFailure` Sites

Direct termination calls that should route through `Effect.Exit`:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-kernel | `Sources/Kernel/Kernel.Thread.trap.swift:51` | `fatalError(error.description)` | Use `Effect.Exit.perform(code:)` | HIGH |
| swift-kernel | `Sources/Kernel/Kernel.Thread.trap.swift:65` | `fatalError(error.description)` | Use `Effect.Exit.perform(code:)` | HIGH |
| swift-kernel | `Sources/Kernel/Kernel.System.Processor.Count.swift:26` | `fatalError("unsupported platform")` | Use `Effect.Exit.perform(code:)` | MEDIUM |
| swift-kernel | `Sources/Kernel/Kernel.System.Memory.Total.swift:32` | `fatalError("unsupported platform")` | Use `Effect.Exit.perform(code:)` | MEDIUM |
| swift-kernel | `Sources/Kernel/Kernel.System.Processor.Physical.Count.swift:36` | `fatalError("unsupported platform")` | Use `Effect.Exit.perform(code:)` | MEDIUM |
| swift-loader | `Sources/Loader/Loader.Symbol.swift:47` | `fatalError("Windows ... not yet implemented")` | Use `Effect.Exit.perform(code:)` | MEDIUM |

**Note**: Most other `fatalError`/`preconditionFailure` calls in the ecosystem are legitimate programming-error traps (e.g., double-take on Ownership.Unique, out-of-bounds on Index.Bounded). These should NOT be converted to effects because they represent invariant violations, not handleable effects. Only the "unsupported platform" and "could not create thread" cases are candidates.

### Category 10: Witness System Overlap

The witness system (`Witness.Protocol`, `Witness.Key`, `Witness.Context`) and the effects system (`Effect.Protocol`, `Effect.Context`) share structural similarity -- both use `Dependency.Key`/`Dependency.Scope` for scoped value resolution:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-witness-primitives | `Sources/Witness Primitives/Witness.Protocol.swift:59` | `Witness.Protocol` -- structs with closure properties | Witnesses are struct-with-closures for capability interfaces. Effects are request types with handler dispatch. **These are complementary, not overlapping.** | N/A |
| swift-witnesses | `Sources/Witnesses/Witness.Context.swift:50` | `Witness.Context` with TaskLocal `@TaskLocal var _current` | Both Witness.Context and Effect.Context wrap Dependency.Scope for scoped injection. **No change needed** -- they serve different purposes (capability injection vs operation interception). | N/A |

**Rationale**: Witnesses model *capabilities* (what you can do). Effects model *operations* (what you request). A witness might *perform* an effect. Example: A `FileSystem: Witness.Protocol` witness struct could have a `read` closure that internally performs `File.System.Read.Full.Effect`. The two systems compose naturally. No unification needed.

### Category 11: Incomplete `EffectWithHandler` Adoption

Some packages define `Effect.Protocol` types but do not provide `EffectWithHandler` conformance with `Dependency.Key` integration:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-cache-primitives | `Sources/Cache Primitives/Cache.Compute.swift:66` | `__CacheCompute: Effect.Protocol` only | Add `EffectWithHandler` conformance + handler key + live/test handlers | HIGH |
| swift-cache-primitives | `Sources/Cache Primitives/Cache.Evict.swift:37` | `__CacheEvict: Effect.Protocol` only | Add `EffectWithHandler` conformance + handler key | HIGH |
| swift-pool-primitives | `Sources/Pool Primitives Core/Pool.Acquire.swift:54` | `Pool.Acquire: Effect.Protocol` only | Add `EffectWithHandler` conformance + handler key | HIGH |
| swift-pool-primitives | `Sources/Pool Primitives Core/Pool.Release.swift:38` | `Pool.Release: Effect.Protocol` only | Add `EffectWithHandler` conformance + handler key | HIGH |
| swift-parser-primitives | `Sources/Parser Backtrack Primitives/Parser.Backtrack.swift:79` | `Parser.Backtrack: Effect.Protocol` only | Add `EffectWithHandler` conformance + handler key | MEDIUM |

**Rationale**: These types already conform to `Effect.Protocol` but cannot be used with `Effect.perform(_:)` because they lack `EffectWithHandler` conformance. Adding this conformance is straightforward and enables the full effect lifecycle: define, perform, handle, test. This is the highest-leverage change in the audit.

**Layer concern**: `EffectWithHandler` lives in Layer 3 (swift-effects). The primitives packages are Layer 1. To add `EffectWithHandler` conformance, either:
1. Move `EffectWithHandler` to `Effect Primitives` (Layer 1) -- **recommended**, since it only depends on `Effect.Protocol` + `Dependency.Key`
2. Add conformance in a Layer 3 extension module -- more complex but preserves current layering

### Category 12: Random Number Generation as Effect

Random byte generation is a pure side-effect:

| Package | File | Current Pattern | Proposed Change | Priority |
|---------|------|----------------|-----------------|----------|
| swift-random | `Sources/Random/Random.Convenience.swift:23` | Direct platform `Random.fill()` call | Define `Random.Generate: Effect.Protocol` with `Arguments = Int` (byte count), `Value = [UInt8]`. Live handler calls OS CSPRNG. Test handler returns deterministic bytes. | MEDIUM |

**Rationale**: Random number generation is a classic effect in the algebraic effects literature. Making it an effect enables deterministic testing without seed management. Priority is MEDIUM because the current approach is simple and the testing benefit is moderate (most randomness testing uses seeded generators anyway).

## Summary Statistics

| Priority | Count |
|----------|-------|
| HIGH | 9 |
| MEDIUM | 10 |
| LOW | 13 |
| N/A (already done or not applicable) | 5 |

### HIGH Priority Items (Direct Replacement Possible)

1. **Complete `EffectWithHandler` for Cache.Compute** -- Cache already defines the effect type
2. **Complete `EffectWithHandler` for Cache.Evict** -- Cache already defines the effect type
3. **Complete `EffectWithHandler` for Pool.Acquire** -- Pool already defines the effect type
4. **Complete `EffectWithHandler` for Pool.Release** -- Pool already defines the effect type
5. **File.System.Read.Full as effect** -- Most impactful testability improvement
6. **File.System.Write as effect** -- Second most impactful testability improvement
7. **Console.Input.Read as effect** -- Canonical effect example, enables deterministic terminal tests
8. **Kernel.Thread.trap to Effect.Exit** (2 sites) -- Direct replacement, exact use case for Effect.Exit

### MEDIUM Priority Items (Refactoring Needed)

1. Parser.Backtrack `EffectWithHandler` conformance
2. Environment.Read as effect
3. Environment.Write as effect
4. Console.Capability.Detect as effect
5. File.System.Delete as effect
6. File.System.Stat as effect
7. Random.Generate as effect
8. Kernel.System.Processor.Count fatalError to Effect.Exit
9. Kernel.System.Memory.Total fatalError to Effect.Exit
10. Loader.Symbol fatalError to Effect.Exit

## Outcome

**Status**: RECOMMENDATION

### Recommended Execution Order

**Phase 1 -- Complete existing effect types (1-2 days)**:
Move `EffectWithHandler` protocol down to `Effect Primitives` (or create a thin integration module). Add `EffectWithHandler` + `Dependency.Key` + live/test handlers to `Cache.Compute`, `Cache.Evict`, `Pool.Acquire`, `Pool.Release`. These types already conform to `Effect.Protocol` -- this is pure additive work.

**Phase 2 -- Replace fatalError with Effect.Exit (0.5 day)**:
Convert `Kernel.Thread.trap` fatalError calls to `Effect.Exit.perform(code:)`. This requires making the trap functions async (design discussion needed for the synchronous `Kernel.Thread.trap` callsite).

**Phase 3 -- File system effects (2-3 days)**:
Define `File.System.Read.Full.Effect` and `File.System.Write.Effect` with live kernel handlers and in-memory test handlers. This enables pure file system testing across the ecosystem.

**Phase 4 -- Console and environment effects (1-2 days)**:
Model console input reading and environment access as effects for testability.

**Phase 5 -- Evaluate remaining MEDIUM/LOW items**:
Based on experience from phases 1-4, decide which remaining items justify the effort.

### Key Design Decision: `EffectWithHandler` Layer Placement

The most impactful architectural question is whether `EffectWithHandler` should move from Layer 3 (swift-effects) to Layer 1 (swift-effect-primitives). Arguments:

**For moving down**: `EffectWithHandler` only requires `Effect.Protocol` + `Dependency.Key`, both of which are Layer 1. Moving it down lets Layer 1 packages (cache, pool, parser) define complete effect types without Layer 3 dependency. This is the natural home.

**Against moving down**: Keeps primitives minimal. The `perform()` implementation uses `withCheckedThrowingContinuation` which is a runtime integration concern.

**Recommendation**: Move `EffectWithHandler` protocol and its `HandlerKey` associated type to `Effect Primitives`. Keep the actual `Effect.perform(_:)` implementation in `Effects` (Layer 3) since it uses `withCheckedThrowingContinuation`. Layer 1 packages can then declare `EffectWithHandler` conformance, and the perform machinery activates when Layer 3 is imported.

### What NOT to Change

1. **Pool.Bounded.Effect** -- Different pattern (synchronous deferred effects, not algebraic)
2. **Witness system** -- Complementary to effects, not overlapping
3. **Test framework internals** -- Would be circular
4. **Rendering.Async.Sink** -- Protocol-based injection already works well
5. **invariant-violation fatalError/preconditionFailure** -- These are programming errors, not handleable effects
6. **IO.Event infrastructure** -- Deep async state machines that do not benefit from effect abstraction
